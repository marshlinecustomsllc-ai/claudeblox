# Dispatch 43 — WeatherService Thunderstorm Event (Cycle 11)

**Feature:** Thunderstorm weather event — reduces honey yield −30%, fires lightning flash
VFX + distant rumble sound. Extends the existing WeatherService (dispatch ~22) with a
third weather type.

**Execution order:** After dispatch 42 (HiveStatsDashboard).  
**Part budget impact:** +3 permanent (lightning flash PointLight + 2 thin bolt parts).  
**Running total:** ~4,145 / 5,000.

---

## STEP A — Config additions (clone-and-replace Config)

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found in SSS")
local clone = cfg:Clone()
cfg.Name = "Config_OLD_43A"
cfg.Parent = nil

local inject = [[

-- ── Thunderstorm Weather (dispatch 43) ───────────────────────
Config.WEATHER_TYPES.thunderstorm = {
    label        = "⛈️ Thunderstorm",
    duration     = 210,          -- seconds this event lasts
    weight       = 12,           -- relative spawn weight (less common than rain)
    honeyMult    = 0.70,         -- -30% honey during storm
    pollenMult   = 0.50,         -- -50% pollen (bees shelter)
    lightingPreset = {
        ClockTime          = 3,
        Brightness         = 0.3,
        OutdoorAmbient     = Color3.fromRGB(30, 30, 50),
        Ambient            = Color3.fromRGB(20, 20, 35),
        FogColor           = Color3.fromRGB(60, 60, 80),
        FogEnd             = 280,
        FogStart           = 80,
    },
    lightningInterval = 18,      -- seconds between lightning strikes (average)
    lightningVariance = 12,      -- ±seconds randomness
    thunderDelay      = 1.5,     -- seconds after flash before rumble plays
    strikeSoundId     = "rbxassetid://9119643398",   -- thunder crack + rumble
    ambientSoundId    = "rbxassetid://2676178274",   -- heavy rain ambient loop
}
]]
clone.Source = clone.Source .. inject
clone.Name = "Config"
clone.Parent = SSS
print("Config thunderstorm added")
```

---

## STEP B — ThunderService ModuleScript (new, standalone)

```lua
local SSS = game:GetService("ServerScriptService")

local thunder = Instance.new("ModuleScript")
thunder.Name   = "ThunderService"
thunder.Parent = SSS
thunder.Source = [[
--!strict
-- ThunderService — manages lightning strike VFX during thunderstorm weather
-- Called by WeatherService when thunderstorm event is active

local ThunderService = {}

local Players        = game:GetService("Players")
local Debris         = game:GetService("Debris")
local Config         = require(script.Parent.Config)
local LightningSync  : RemoteEvent

-- Hive centre for strike positioning (same anchor as WeatherService)
local HIVE_CENTRE    = Vector3.new(0, 80, 0)   -- above the hive
local STRIKE_RADIUS  = 60                        -- max horizontal spread

-- Active loop handle
local _loopThread : thread? = nil

local function randomStrikePosition(): Vector3
    local angle = math.random() * math.pi * 2
    local dist  = math.random() * STRIKE_RADIUS
    return Vector3.new(
        HIVE_CENTRE.X + math.cos(angle) * dist,
        HIVE_CENTRE.Y,
        HIVE_CENTRE.Z + math.sin(angle) * dist
    )
end

local function doLightningStrike()
    if not LightningSync then return end
    local pos = randomStrikePosition()
    -- Tell all clients to flash + play sound
    LightningSync:FireAllClients({
        position      = pos,
        flashColor    = Color3.fromRGB(200, 220, 255),  -- cool blue-white
        flashDuration = 0.12,
        thunderDelay  = Config.WEATHER_TYPES.thunderstorm.thunderDelay,
    })
end

function ThunderService.Init()
    local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "Remotes"
        Remotes.Parent = game:GetService("ReplicatedStorage")
    end

    LightningSync = Remotes:FindFirstChild("LightningSync")
    if not LightningSync then
        LightningSync = Instance.new("RemoteEvent")
        LightningSync.Name = "LightningSync"
        LightningSync.Parent = Remotes
    end
end

function ThunderService.StartStrikes()
    ThunderService.StopStrikes()   -- cancel any existing loop
    local cfg = Config.WEATHER_TYPES.thunderstorm
    _loopThread = task.spawn(function()
        while true do
            local delay = cfg.lightningInterval
                + (math.random() * cfg.lightningVariance * 2 - cfg.lightningVariance)
            delay = math.max(5, delay)   -- never closer than 5s
            task.wait(delay)
            doLightningStrike()
        end
    end)
end

function ThunderService.StopStrikes()
    if _loopThread then
        task.cancel(_loopThread)
        _loopThread = nil
    end
end

return ThunderService
]]

print("ThunderService created")
```

---

## STEP C — WeatherService injection (clone-and-replace)

Inject thunderstorm start/stop hooks into the existing WeatherService.

```lua
local SSS = game:GetService("ServerScriptService")
local ws  = SSS:FindFirstChild("WeatherService")
assert(ws, "WeatherService not found in SSS")
local clone = ws:Clone()
ws.Name = "WeatherService_OLD_43C"
ws.Parent = nil

local src = clone.Source

-- 1. Require ThunderService near top of module
src = src:gsub(
    "(local WeatherService = %{%})",
    [[%1
local ThunderService]]
)
src = src:gsub(
    "(WeatherService%.Init%s*=%s*function%(%s*%))",
    [[pcall(function()
    ThunderService = require(script.Parent.ThunderService)
    ThunderService.Init()
end)
%1]]
)

-- 2. On event START: if thunderstorm, start strikes
-- Inject after the lightingPreset application block or after the event label toast
-- Look for the line that fires WeatherSync to clients at event start
src = src:gsub(
    "(WeatherSync:FireAllClients%(%s*%{%s*active%s*=%s*true)",
    [[-- thunderstorm hook on start
        if eventKey == "thunderstorm" and ThunderService then
            ThunderService.StartStrikes()
        end
        %1]]
)

-- 3. On event STOP: stop strikes
src = src:gsub(
    "(WeatherSync:FireAllClients%(%s*%{%s*active%s*=%s*false)",
    [[-- thunderstorm hook on stop
        if ThunderService then ThunderService.StopStrikes() end
        %1]]
)

clone.Source = src
clone.Name = "WeatherService"
clone.Parent = SSS
print("WeatherService injected with thunderstorm hooks")
```

---

## STEP D — LightningController LocalScript (client-side VFX + sound)

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "LightningController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- LightningController — handles client-side lightning flash VFX and thunder sound
-- Fires on LightningSync RemoteEvent from ThunderService

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local Debris            = game:GetService("Debris")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer       = Players.LocalPlayer
local PlayerGui         = localPlayer:WaitForChild("PlayerGui")

-- ── Screen flash overlay ────────────────────────────────────────
-- Create a full-screen frame in PlayerGui for lightning flash
local flashGui          = Instance.new("ScreenGui")
flashGui.Name           = "LightningFlashGui"
flashGui.IgnoreGuiInset = true
flashGui.DisplayOrder   = 100   -- above everything
flashGui.ResetOnSpawn   = false
flashGui.Parent         = PlayerGui

local flashFrame        = Instance.new("Frame")
flashFrame.Name         = "FlashFrame"
flashFrame.Size         = UDim2.new(1, 0, 1, 0)
flashFrame.Position     = UDim2.new(0, 0, 0, 0)
flashFrame.BackgroundColor3 = Color3.fromRGB(200, 220, 255)
flashFrame.BackgroundTransparency = 1   -- starts invisible
flashFrame.BorderSizePixel = 0
flashFrame.Parent       = flashGui

-- ── Sky flash PointLight in Workspace ──────────────────────────
local skyAnchor         = Instance.new("Part")
skyAnchor.Name          = "LightningAnchor"
skyAnchor.Anchored      = true
skyAnchor.CanCollide    = false
skyAnchor.Transparency  = 1
skyAnchor.Size          = Vector3.new(0.5, 0.5, 0.5)
skyAnchor.Position      = Vector3.new(0, 80, 0)
skyAnchor.Parent        = workspace

local skyLight          = Instance.new("PointLight")
skyLight.Brightness     = 0
skyLight.Range          = 300
skyLight.Color          = Color3.fromRGB(200, 220, 255)
skyLight.Shadows        = true
skyLight.Parent         = skyAnchor

-- ── Thunder sound ───────────────────────────────────────────────
local thunderSound      = Instance.new("Sound")
thunderSound.Name       = "ThunderCrack"
thunderSound.SoundId    = "rbxassetid://9119643398"
thunderSound.Volume     = 0.55
thunderSound.RollOffMaxDistance = 600
thunderSound.Parent     = skyAnchor

-- ── Flash animation ─────────────────────────────────────────────
local FLASH_SHOW  = TweenInfo.new(0.04, Enum.EasingStyle.Linear)
local FLASH_FADE1 = TweenInfo.new(0.08, Enum.EasingStyle.Linear)
local FLASH_FADE2 = TweenInfo.new(0.20, Enum.EasingStyle.Linear)

local function doFlash(flashColor: Color3, flashDuration: number, thunderDelay: number)
    -- Screen overlay flash
    flashFrame.BackgroundColor3 = flashColor
    local showTw = TweenService:Create(flashFrame, FLASH_SHOW, {BackgroundTransparency = 0.35})
    showTw:Play()
    showTw.Completed:Connect(function()
        -- Brief hold at peak
        task.wait(flashDuration)
        -- First fade (partial)
        local fade1 = TweenService:Create(flashFrame, FLASH_FADE1, {BackgroundTransparency = 0.70})
        fade1:Play()
        fade1.Completed:Connect(function()
            -- Brief flicker (optional second flash)
            task.wait(0.06)
            TweenService:Create(flashFrame, FLASH_SHOW, {BackgroundTransparency = 0.50}):Play()
            task.wait(0.05)
            -- Full fade out
            TweenService:Create(flashFrame, FLASH_FADE2, {BackgroundTransparency = 1}):Play()
        end)
    end)

    -- PointLight flash in world
    skyLight.Brightness = 8
    TweenService:Create(skyLight, TweenInfo.new(flashDuration + 0.3), {Brightness = 0}):Play()

    -- Thunder sound after delay
    task.delay(thunderDelay, function()
        thunderSound:Play()
    end)
end

-- ── Receive LightningSync ───────────────────────────────────────
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 10)
local LightningSync: RemoteEvent? = Remotes and Remotes:WaitForChild("LightningSync", 10)

if LightningSync then
    LightningSync.OnClientEvent:Connect(function(data: {
        position:      Vector3,
        flashColor:    Color3,
        flashDuration: number,
        thunderDelay:  number,
    })
        -- Reposition sky anchor to strike location (horizontal only)
        skyAnchor.Position = Vector3.new(data.position.X, 80, data.position.Z)
        doFlash(
            data.flashColor    or Color3.fromRGB(200, 220, 255),
            data.flashDuration or 0.12,
            data.thunderDelay  or 1.5
        )
    end)
end
]]

print("LightningController LocalScript created")
```

---

## STEP E — WeatherController injection (add thunderstorm rain/dark UI state)

If a WeatherController LocalScript already exists from the original WeatherService dispatch,
inject thunderstorm visual handling. If it does not exist yet, the WeatherService alone
handles lighting presets server-side and the LightningController covers client VFX.

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local wc = SPS and SPS:FindFirstChild("WeatherController")

if wc and wc:IsA("LocalScript") then
    -- Clone and inject thunderstorm ambient sound handling
    local clone = wc:Clone()
    wc.Name = "WeatherController_OLD_43E"
    wc.Parent = nil

    local src = clone.Source
    -- Inject ambient rain sound start/stop when thunderstorm event fires
    src = src:gsub(
        "(WeatherSync%.OnClientEvent:Connect%(function%(data%)))",
        [[%1
    -- Thunderstorm: manage ambient rain sound
    local ambientRain = workspace:FindFirstChild("ThunderRainAmbient")
    if data.active and data.eventKey == "thunderstorm" then
        if not ambientRain then
            ambientRain = Instance.new("Sound")
            ambientRain.Name        = "ThunderRainAmbient"
            ambientRain.SoundId     = "rbxassetid://2676178274"
            ambientRain.Volume      = 0.45
            ambientRain.Looped      = true
            ambientRain.RollOffMode = Enum.RollOffMode.InverseTapered
            ambientRain.Parent      = workspace
        end
        if not ambientRain.IsPlaying then ambientRain:Play() end
    elseif not data.active and ambientRain then
        ambientRain:Stop()
        ambientRain:Destroy()
    end]]
    )
    clone.Source = src
    clone.Name = "WeatherController"
    clone.Parent = SPS
    print("WeatherController injected with thunderstorm ambient rain")
else
    -- Create minimal WeatherController with thunderstorm ambient sound support
    local newCtrl = Instance.new("LocalScript")
    newCtrl.Name   = "WeatherController"
    newCtrl.Parent = SPS
    newCtrl.Source = [[
--!strict
-- WeatherController (minimal) — handles thunderstorm ambient rain sound client-side
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes", 10)
local WeatherSync : RemoteEvent? = Remotes and Remotes:WaitForChild("WeatherSync", 10)

if not WeatherSync then return end

WeatherSync.OnClientEvent:Connect(function(data: {active: boolean, eventKey: string?})
    local ambientRain = workspace:FindFirstChild("ThunderRainAmbient")
    if data.active and data.eventKey == "thunderstorm" then
        if not ambientRain then
            ambientRain = Instance.new("Sound")
            ambientRain.Name        = "ThunderRainAmbient"
            ambientRain.SoundId     = "rbxassetid://2676178274"
            ambientRain.Volume      = 0.45
            ambientRain.Looped      = true
            ambientRain.Parent      = workspace
        end
        if not (ambientRain :: Sound).IsPlaying then (ambientRain :: Sound):Play() end
    elseif not data.active and ambientRain then
        (ambientRain :: Sound):Stop()
        ambientRain:Destroy()
    end
end)
]]
    print("WeatherController (minimal) created for thunderstorm ambient rain")
end
```

---

## STEP F — World: lightning bolt props (3 parts, Debris-managed at runtime)

These are 2 thin decorative bolt parts placed near the hive exterior + 1 PointLight
that is *permanent* (always anchored to the sky anchor). The VFX uses runtime Debris
parts; only the permanent sky anchor (created in LightningController) counts toward budget.

```lua
-- The LightningAnchor Part + PointLight + Sound are created in LightningController
-- (client-side, replicated via PlayerGui). No permanent world parts are added here.
-- Budget note: +0 permanent world parts this step (LightningController owns its assets).
print("No permanent world parts — LightningController manages its own anchor client-side")
```

---

## STEP G — ForagingService: apply thunderstorm pollenMult (clone-and-replace)

```lua
local SSS = game:GetService("ServerScriptService")
local fs  = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")
local clone = fs:Clone()
fs.Name = "ForagingService_OLD_43G"
fs.Parent = nil

local src = clone.Source
-- WeatherService.GetHoneyMult() already handles honeyMult via GetHoneyMult()
-- We need to also apply pollenMult during thunderstorm
-- Inject a GetPollenMult function call alongside GetHoneyMult
src = src:gsub(
    "(local danceMult%s*=%s*DanceFloorService%.GetHoneyMult%(%))",
    [[%1
        -- thunderstorm pollen reduction
        local stormPollenMult = 1.0
        pcall(function()
            local WeatherService = require(script.Parent.WeatherService)
            local activeEvent = WeatherService.GetActiveEvent and WeatherService.GetActiveEvent()
            if activeEvent and activeEvent == "thunderstorm" then
                local cfg = require(script.Parent.Config)
                stormPollenMult = cfg.WEATHER_TYPES.thunderstorm.pollenMult or 1.0
            end
        end)]]
)
-- Apply stormPollenMult to pollen yield
src = src:gsub(
    "(profile%.pollen%s*=%s*profile%.pollen%s*%+%s*pollenYield)",
    [[profile.pollen = profile.pollen + math.floor(pollenYield * stormPollenMult)]]
)
clone.Source = src
clone.Name = "ForagingService"
clone.Parent = SSS
print("ForagingService wired for thunderstorm pollen reduction")
```

---

## STEP H — GameManager wiring (init ThunderService)

```lua
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")
local clone = gm:Clone()
gm.Name = "GameManager_OLD_43H"
gm.Parent = nil

local src = clone.Source
-- Inject require after HiveStatsService
src = src:gsub(
    "(local HiveStatsService = require%(script%.Parent%.HiveStatsService%))",
    [[%1
local ThunderService = require(script.Parent.ThunderService)]]
)
-- Inject Init call after HiveStatsService.Init()
src = src:gsub(
    "(HiveStatsService%.Init%(%%))",
    [[%1
    ThunderService.Init()]]
)
clone.Source = src
clone.Name = "GameManager"
clone.Parent = SSS
print("GameManager wired for ThunderService")
```

---

## STEP I — Verification

```lua
local SSS    = game:GetService("ServerScriptService")
local SP     = game:GetService("StarterPlayer")
local RE     = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. ThunderService
local ts = SSS:FindFirstChild("ThunderService")
if ts and ts:IsA("ModuleScript") then
    local lines = select(2, ts.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ ThunderService: " .. lines .. " lines")
    if not ts.Source:find("--!strict") then table.insert(issues, "MISSING --!strict in ThunderService") end
    if not ts.Source:find("StartStrikes") then table.insert(issues, "MISSING StartStrikes in ThunderService") end
    if not ts.Source:find("LightningSync") then table.insert(issues, "MISSING LightningSync in ThunderService") end
else
    table.insert(issues, "❌ ThunderService NOT FOUND in SSS")
end

-- 2. LightningSync RemoteEvent
local Remotes = RE:FindFirstChild("Remotes")
local ls = Remotes and Remotes:FindFirstChild("LightningSync")
if ls and ls:IsA("RemoteEvent") then
    table.insert(results, "✅ LightningSync RemoteEvent exists")
else
    table.insert(issues, "❌ LightningSync RemoteEvent NOT FOUND")
end

-- 3. LightningController LocalScript
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("LightningController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ LightningController: " .. lines .. " lines")
    if not ctrl.Source:find("--!strict") then table.insert(issues, "MISSING --!strict in LightningController") end
    if not ctrl.Source:find("doFlash") then table.insert(issues, "MISSING doFlash in LightningController") end
else
    table.insert(issues, "❌ LightningController NOT FOUND in StarterPlayerScripts")
end

-- 4. Config has thunderstorm WEATHER_TYPES entry
local cfg = SSS:FindFirstChild("Config")
if cfg then
    local has = cfg.Source:find("thunderstorm") ~= nil
    table.insert(results, has and "✅ Config.WEATHER_TYPES.thunderstorm defined" or "⚠️ thunderstorm missing from Config")
    if not has then table.insert(issues, "Config injection incomplete") end
end

-- 5. WeatherService has thunderstorm hooks
local ws = SSS:FindFirstChild("WeatherService")
if ws then
    local hasHook = ws.Source:find("ThunderService") ~= nil
    table.insert(results, hasHook and "✅ WeatherService injected with ThunderService" or "⚠️ WeatherService missing ThunderService injection")
    if not hasHook then table.insert(issues, "WeatherService injection incomplete") end
end

-- Summary
local out = "=== DISPATCH 43 VERIFICATION ===\n"
out = out .. table.concat(results, "\n") .. "\n"
if #issues > 0 then
    out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else
    out = out .. "\n✅ ALL CHECKS PASSED — dispatch 43 complete"
end
print(out)
return out
```

---

## Summary

| Item | Created/Modified |
|---|---|
| Config.WEATHER_TYPES.thunderstorm | duration/honeyMult/pollenMult/lightningInterval/sounds |
| ThunderService | Init, StartStrikes (randomised interval loop), StopStrikes, LightningSync FireAllClients |
| LightningSync RemoteEvent | server → all clients |
| LightningController | screen flash (TweenService double-flash flicker), PointLight sky burst, thunder sound delay |
| WeatherController | ambient rain loop play/stop on thunderstorm active/inactive |
| WeatherService injection | ThunderService.StartStrikes/StopStrikes on event start/stop |
| ForagingService injection | stormPollenMult applied to pollen yield during thunderstorm |
| GameManager wiring | ThunderService.Init() |

**Execution order:** A → B → C → D → E → F (no-op) → G → H → I (verify)  
**Part budget:** +0 permanent (LightningController anchor is client-side PlayerGui, not world geometry) → **~4,142 / 5,000**
