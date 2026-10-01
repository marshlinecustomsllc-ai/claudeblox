# Dispatch 46 — SeasonService (Spring/Summer/Autumn/Winter) (Cycle 11)

**Feature:** A rotating seasonal system that cycles Spring → Summer → Autumn → Winter
every real-world day (UTC-based). Each season applies multipliers to honey, pollen, and
propolis yield, adjusts Lighting atmosphere, and fires a SeasonSync RemoteEvent so
clients can display the current season in HiveGui.

**Execution order:** After dispatch 45 (BeeNaming).  
**Part budget impact:** 0 (lighting adjustments only — no new parts).  
**Running total:** ~4,142 / 5,000.

---

## STEP A — Config: SEASONS table

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")
local clone = cfg:Clone()
cfg.Name = "Config_OLD_46A"
cfg.Parent = nil

local inject = [[

-- ── Seasons (dispatch 46) ────────────────────────────────────
-- Cycles once per real UTC day (day number mod 4 = season index)
Config.SEASONS = {
    [0] = {   -- Spring  (day mod 4 == 0)
        name        = "Spring",
        emoji       = "🌸",
        label       = "🌸 Spring",
        honeyMult   = 1.10,    -- +10%
        pollenMult  = 1.30,    -- +30%
        propMult    = 1.00,
        lighting    = {
            ClockTime     = 10,
            Brightness    = 2.2,
            OutdoorAmbient = Color3.fromRGB(160, 200, 160),
            Ambient        = Color3.fromRGB(120, 160, 120),
            FogColor       = Color3.fromRGB(200, 230, 200),
            FogEnd         = 600,
            FogStart       = 300,
        },
    },
    [1] = {   -- Summer  (day mod 4 == 1)
        name        = "Summer",
        emoji       = "☀️",
        label       = "☀️ Summer",
        honeyMult   = 1.25,    -- +25%
        pollenMult  = 1.10,
        propMult    = 0.90,
        lighting    = {
            ClockTime     = 14,
            Brightness    = 3.0,
            OutdoorAmbient = Color3.fromRGB(220, 210, 160),
            Ambient        = Color3.fromRGB(180, 170, 120),
            FogColor       = Color3.fromRGB(240, 240, 210),
            FogEnd         = 900,
            FogStart       = 500,
        },
    },
    [2] = {   -- Autumn  (day mod 4 == 2)
        name        = "Autumn",
        emoji       = "🍂",
        label       = "🍂 Autumn",
        honeyMult   = 0.90,    -- -10%
        pollenMult  = 0.80,    -- -20%
        propMult    = 1.20,    -- +20% (propolis — bees prepare for winter)
        lighting    = {
            ClockTime     = 12,
            Brightness    = 1.8,
            OutdoorAmbient = Color3.fromRGB(200, 150, 80),
            Ambient        = Color3.fromRGB(160, 110, 60),
            FogColor       = Color3.fromRGB(220, 180, 130),
            FogEnd         = 500,
            FogStart       = 200,
        },
    },
    [3] = {   -- Winter  (day mod 4 == 3)
        name        = "Winter",
        emoji       = "❄️",
        label       = "❄️ Winter",
        honeyMult   = 0.70,    -- -30%
        pollenMult  = 0.50,    -- -50%
        propMult    = 0.80,
        lighting    = {
            ClockTime     = 9,
            Brightness    = 1.2,
            OutdoorAmbient = Color3.fromRGB(160, 180, 220),
            Ambient        = Color3.fromRGB(120, 140, 180),
            FogColor       = Color3.fromRGB(200, 210, 240),
            FogEnd         = 350,
            FogStart       = 100,
        },
    },
}
]]
clone.Source = clone.Source .. inject
clone.Name = "Config"
clone.Parent = SSS
print("Config.SEASONS added")
```

---

## STEP B — SeasonService ModuleScript

```lua
local SSS = game:GetService("ServerScriptService")

local svc = Instance.new("ModuleScript")
svc.Name   = "SeasonService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- SeasonService — manages the rotating seasonal system
-- Season changes once per UTC day (os.time() / 86400 mod 4)

local SeasonService = {}

local Lighting  = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Config    = require(script.Parent.Config)

local SeasonSync: RemoteEvent?
local _currentSeason: number = 0   -- index into Config.SEASONS

-- ── UTC day → season index ───────────────────────────────────────
local function getSeasonIndex(): number
    return math.floor(os.time() / 86400) % 4
end

-- ── Apply lighting for current season ───────────────────────────
local function applyLighting(seasonIdx: number)
    local def = Config.SEASONS[seasonIdx]
    if not def then return end
    local L = Lighting
    local li = def.lighting
    local tw = TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(L, tw, {
        ClockTime      = li.ClockTime,
        Brightness     = li.Brightness,
        OutdoorAmbient = li.OutdoorAmbient,
        Ambient        = li.Ambient,
        FogColor       = li.FogColor,
        FogEnd         = li.FogEnd,
        FogStart       = li.FogStart,
    }):Play()
end

-- ── Sync to all clients ──────────────────────────────────────────
local function syncAll()
    if not SeasonSync then return end
    local def = Config.SEASONS[_currentSeason]
    SeasonSync:FireAllClients({
        index     = _currentSeason,
        name      = def.name,
        emoji     = def.emoji,
        label     = def.label,
        honeyMult = def.honeyMult,
        pollenMult = def.pollenMult,
        propMult  = def.propMult,
    })
end

-- ── Public API ───────────────────────────────────────────────────
function SeasonService.GetHoneyMult(): number
    return Config.SEASONS[_currentSeason].honeyMult
end

function SeasonService.GetPollenMult(): number
    return Config.SEASONS[_currentSeason].pollenMult
end

function SeasonService.GetPropMult(): number
    return Config.SEASONS[_currentSeason].propMult
end

function SeasonService.GetCurrentSeason(): {name: string, emoji: string, label: string}
    local def = Config.SEASONS[_currentSeason]
    return { name = def.name, emoji = def.emoji, label = def.label }
end

function SeasonService.Init()
    local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "Remotes"
        Remotes.Parent = game:GetService("ReplicatedStorage")
    end

    SeasonSync = Remotes:FindFirstChild("SeasonSync")
    if not SeasonSync then
        SeasonSync = Instance.new("RemoteEvent")
        SeasonSync.Name = "SeasonSync"
        SeasonSync.Parent = Remotes
    end

    _currentSeason = getSeasonIndex()
    applyLighting(_currentSeason)

    -- Sync joining players
    game:GetService("Players").PlayerAdded:Connect(function(player)
        task.delay(2, function()
            if not (player and player.Parent) then return end
            if SeasonSync then
                local def = Config.SEASONS[_currentSeason]
                SeasonSync:FireClient(player, {
                    index      = _currentSeason,
                    name       = def.name,
                    emoji      = def.emoji,
                    label      = def.label,
                    honeyMult  = def.honeyMult,
                    pollenMult = def.pollenMult,
                    propMult   = def.propMult,
                })
            end
        end)
    end)

    -- Poll for day change (check every 5 minutes)
    task.spawn(function()
        while true do
            task.wait(300)
            local newIdx = getSeasonIndex()
            if newIdx ~= _currentSeason then
                _currentSeason = newIdx
                applyLighting(newIdx)
                syncAll()
            end
        end
    end)
end

return SeasonService
]]

print("SeasonService created")
```

---

## STEP C — SeasonSync RemoteEvent

```lua
local RE = game:GetService("ReplicatedStorage")
local Remotes = RE:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = RE
end
local ss = Remotes:FindFirstChild("SeasonSync")
if not ss then
    ss = Instance.new("RemoteEvent")
    ss.Name = "SeasonSync"
    ss.Parent = Remotes
end
print("SeasonSync RemoteEvent ready")
```

---

## STEP D — Wire SeasonService into GameManager

```lua
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")
local clone = gm:Clone()
gm.Name = "GameManager_OLD_46D"
gm.Parent = nil

local src = clone.Source
src = src:gsub(
    "(local BeeNameService = require%(script%.Parent%.BeeNameService%))",
    [[%1
local SeasonService = require(script.Parent.SeasonService)]]
)
src = src:gsub(
    "(BeeNameService%.Init%(%%))",
    [[%1
    SeasonService.Init()]]
)
clone.Source = src
clone.Name = "GameManager"
clone.Parent = SSS
print("GameManager wired for SeasonService")
```

---

## STEP E — Inject season multipliers into ForagingService

```lua
local SSS = game:GetService("ServerScriptService")
local fs  = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")
local clone = fs:Clone()
fs.Name = "ForagingService_OLD_46E"
fs.Parent = nil

local src = clone.Source

-- Inject require near top
src = src:gsub(
    "(local ForagingService = %{%})",
    [[%1
local _SeasonService]]
)
src = src:gsub(
    "(ForagingService%.Init%s*=%s*function%(%s*%))",
    [[pcall(function() _SeasonService = require(script.Parent.SeasonService) end)
%1]]
)

-- After danceMult and stormPollenMult, inject season mults
src = src:gsub(
    "(local stormPollenMult = 1%.0)",
    [[%1
        local seasonHoneyMult  = _SeasonService and _SeasonService.GetHoneyMult()  or 1.0
        local seasonPollenMult = _SeasonService and _SeasonService.GetPollenMult() or 1.0
        local seasonPropMult   = _SeasonService and _SeasonService.GetPropMult()   or 1.0]]
)

-- Apply seasonHoneyMult to honey yield (multiply into existing danceMult line)
src = src:gsub(
    "(local danceMult%s*=%s*DanceFloorService%.GetHoneyMult%(%%))",
    [[%1
        local totalHoneyMult = danceMult * (seasonHoneyMult or 1.0)]]
)
-- Replace danceMult references in yield calculation with totalHoneyMult
src = src:gsub("danceMult", "totalHoneyMult")

-- Apply seasonPollenMult alongside stormPollenMult
src = src:gsub(
    "(profile%.pollen%s*=%s*profile%.pollen%s*%+%s*math%.floor%(pollenYield%s*%*%s*stormPollenMult%))",
    [[profile.pollen = profile.pollen + math.floor(pollenYield * stormPollenMult * (seasonPollenMult or 1.0))]]
)

-- Apply seasonPropMult to propolis yield if it exists
src = src:gsub(
    "(profile%.propolis%s*=%s*profile%.propolis%s*%+%s*propolisYield)",
    [[profile.propolis = profile.propolis + math.floor(propolisYield * (seasonPropMult or 1.0))]]
)

clone.Source = src
clone.Name = "ForagingService"
clone.Parent = SSS
print("ForagingService wired for season multipliers")
```

---

## STEP F — SeasonController LocalScript (HiveGui season badge)

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "SeasonController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- SeasonController — receives SeasonSync and updates season badge in HiveGui

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer       = Players.LocalPlayer
local PlayerGui         = localPlayer:WaitForChild("PlayerGui")
local HiveGui           = PlayerGui:WaitForChild("HiveGui", 15)
local MainFrame         = HiveGui and HiveGui:WaitForChild("MainFrame", 5)

-- ── Season badge in MainFrame ────────────────────────────────────
local seasonBadge: TextLabel?
if MainFrame then
    local badge           = Instance.new("TextLabel")
    badge.Name            = "SeasonBadge"
    badge.Parent          = MainFrame
    badge.Size            = UDim2.new(0.16, 0, 0.07, 0)
    badge.Position        = UDim2.new(0.01, 0, 0.10, 0)
    badge.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
    badge.BackgroundTransparency = 0.15
    badge.Text            = "🌸 Spring"
    badge.TextColor3      = Color3.fromRGB(232, 212, 154)
    badge.Font            = Enum.Font.FredokaOne
    badge.TextScaled      = true
    badge.ZIndex          = 10
    local bc              = Instance.new("UICorner")
    bc.CornerRadius       = UDim.new(0.2, 0)
    bc.Parent             = badge
    local bs              = Instance.new("UIStroke")
    bs.Color              = Color3.fromRGB(242, 168, 28)
    bs.Thickness          = 1.5
    bs.Parent             = badge
    seasonBadge           = badge
end

-- Season → badge background colour
local SEASON_COLORS: {[string]: Color3} = {
    Spring = Color3.fromRGB( 40,  60,  40),
    Summer = Color3.fromRGB( 70,  55,  10),
    Autumn = Color3.fromRGB( 70,  35,  10),
    Winter = Color3.fromRGB( 20,  30,  60),
}

local function updateBadge(name: string, label: string)
    if not seasonBadge then return end
    seasonBadge.Text = label
    local col = SEASON_COLORS[name] or Color3.fromRGB(40, 25, 10)
    TweenService:Create(seasonBadge, TweenInfo.new(0.4), {
        BackgroundColor3 = col,
    }):Play()
end

-- ── SeasonSync ───────────────────────────────────────────────────
local Remotes    = ReplicatedStorage:WaitForChild("Remotes", 10)
local SeasonSync : RemoteEvent? = Remotes and Remotes:WaitForChild("SeasonSync", 10) :: RemoteEvent?

if SeasonSync then
    SeasonSync.OnClientEvent:Connect(function(data: {name: string, label: string})
        updateBadge(data.name, data.label)
    end)
end
]]

print("SeasonController LocalScript created")
```

---

## STEP G — Verification

```lua
local SSS    = game:GetService("ServerScriptService")
local SP     = game:GetService("StarterPlayer")
local RE     = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. SeasonService
local svc = SSS:FindFirstChild("SeasonService")
if svc and svc:IsA("ModuleScript") then
    local lines = select(2, svc.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ SeasonService: " .. lines .. " lines")
    if not svc.Source:find("--!strict")      then table.insert(issues, "MISSING --!strict") end
    if not svc.Source:find("GetHoneyMult")   then table.insert(issues, "MISSING GetHoneyMult") end
    if not svc.Source:find("getSeasonIndex") then table.insert(issues, "MISSING getSeasonIndex") end
    if not svc.Source:find("applyLighting")  then table.insert(issues, "MISSING applyLighting") end
else
    table.insert(issues, "❌ SeasonService NOT FOUND")
end

-- 2. SeasonSync RemoteEvent
local Remotes = RE:FindFirstChild("Remotes")
local ss = Remotes and Remotes:FindFirstChild("SeasonSync")
table.insert(results, ss and "✅ SeasonSync RemoteEvent" or "❌ SeasonSync MISSING")
if not ss then table.insert(issues, "SeasonSync missing") end

-- 3. Config
local cfg = SSS:FindFirstChild("Config")
if cfg and cfg.Source:find("SEASONS") then
    -- Count seasons defined
    local count = select(2, cfg.Source:gsub("%[%d%]%s*=%s*%{", ""))
    table.insert(results, "✅ Config.SEASONS defined (" .. count .. " entries)")
else
    table.insert(issues, "⚠️ Config.SEASONS missing")
end

-- 4. SeasonController
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("SeasonController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ SeasonController: " .. lines .. " lines")
    if not ctrl.Source:find("--!strict")  then table.insert(issues, "MISSING --!strict in SeasonController") end
    if not ctrl.Source:find("SeasonBadge") then table.insert(issues, "MISSING SeasonBadge in SeasonController") end
else
    table.insert(issues, "❌ SeasonController NOT FOUND")
end

-- 5. ForagingService injected
local fs = SSS:FindFirstChild("ForagingService")
if fs and fs.Source:find("seasonHoneyMult") then
    table.insert(results, "✅ ForagingService has season multipliers")
else
    table.insert(issues, "⚠️ ForagingService missing season multipliers")
end

-- 6. Test current season index
local idx = math.floor(os.time() / 86400) % 4
local names = {"Spring", "Summer", "Autumn", "Winter"}
table.insert(results, "ℹ️  Current season index: " .. idx .. " (" .. (names[idx+1] or "?") .. ")")

local out = "=== DISPATCH 46 VERIFICATION ===\n" .. table.concat(results, "\n") .. "\n"
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — dispatch 46 complete" end
print(out)
return out
```

---

## Summary

| Item | Created/Modified |
|---|---|
| Config.SEASONS | 4 seasons (Spring/Summer/Autumn/Winter) with honeyMult, pollenMult, propMult, lighting presets |
| SeasonService | getSeasonIndex (os.time()/86400%4), applyLighting (8s TweenService transition), GetHoneyMult/GetPollenMult/GetPropMult, 5-min day-change poll, PlayerAdded sync |
| SeasonSync RemoteEvent | server → all clients |
| GameManager wiring | SeasonService.Init() |
| ForagingService injection | seasonHoneyMult × danceMult, seasonPollenMult × stormPollenMult, seasonPropMult × propolisYield |
| SeasonController | SeasonBadge TextLabel in MainFrame, season-colour TweenService background tint |

**Season schedule (UTC day mod 4):**  
`0=Spring 🌸` → `1=Summer ☀️` → `2=Autumn 🍂` → `3=Winter ❄️` → repeat

**Execution order:** A → B → C → D → E → F → G (verify)  
**Part budget:** 0 → **~4,142 / 5,000**
