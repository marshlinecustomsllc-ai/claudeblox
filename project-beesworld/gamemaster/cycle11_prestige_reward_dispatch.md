# Dispatch 33 — PrestigeRewardService: Generation Reset Rewards
**File:** `cycle11_prestige_reward_dispatch.md`
**Cycle:** 11
**Part budget:** 0 → ~4,098/5,000 (no world parts)
**DataService migration:** None (uses existing `profile.generation`, `profile.cosmeticsUnlocked`)
**Depends on:** Dispatch 19 (PrestigeService generation reset), Dispatch 22 (cosmetics system)
**Supersedes:** Nothing

---

## Purpose

Give players a **tangible reward when they prestige (reset generation)**:

1. A **+50% honey multiplier** active for the first 5 minutes after reset ("Prestige Rush")
2. A **cosmetic skin unlock** — one generation-gated skin per prestige tier, granting players
   a visual trophy that shows their prestige level in the wardrobe

Before this dispatch: generation reset in PrestigeService resets honey/cells/queen but gives
no immediate reward beyond the gen counter ticking up.
After this dispatch: resetting feels *rewarding* — a rush window + a skin grant each gen.

---

## STEP A — Config: PRESTIGE_REWARDS table

```lua
-- STEP A: Add PRESTIGE_REWARDS to Config
local config = game:GetService("ServerScriptService"):FindFirstChild("Config")
    or game:GetService("ReplicatedStorage"):FindFirstChild("Config")
assert(config, "Config not found")

local clone = config:Clone()
local oldName = config.Name
config.Name = oldName .. "_OLD_33A"
config.Parent = nil

local src = clone.Source

local injection = [[

-- Prestige (generation reset) rewards
-- rushDuration: seconds of +50% honey multiplier after reset
-- skinUnlock: cosmetics key unlocked at this generation (nil = no skin this gen)
-- bannerMsg: Notify toast fired on reset
Config.PRESTIGE_REWARDS = {
    rushDuration = 300,  -- 5 minutes of Prestige Rush on every reset
    skins = {
        [1] = "golden_bee",         -- Gen 1: Golden Bee skin
        [2] = "obsidian_bee",       -- Gen 2: Obsidian Bee skin
        [3] = "crystal_bee",        -- Gen 3: Crystal Bee skin
        [4] = "prism_bee",          -- Gen 4: Prism Bee skin (rainbow)
        [5] = "void_bee",           -- Gen 5+: Void Bee skin (max prestige cosmetic)
    },
    rushLabel    = "🏆 Prestige Rush",
    rushDesc     = "+50% honey for 5 minutes!",
    -- gen 5+ always grants void_bee (final skin, keeps generating rush)
    maxSkinGen   = 5,
}
-- Add prestige-gated entries to COSMETICS (these are granted by PrestigeRewardService, not purchase)
-- skin_id, display_name, color, bodyColor — minimal entries so WardrobeGui can render them
Config.PRESTIGE_COSMETICS = {
    golden_bee  = { name = "Golden Bee",   color = Color3.fromRGB(242,168,28),  bodyColor = Color3.fromRGB(200,140,10),  genRequired = 1 },
    obsidian_bee = { name = "Obsidian Bee", color = Color3.fromRGB(30,30,50),    bodyColor = Color3.fromRGB(20,20,40),    genRequired = 2 },
    crystal_bee = { name = "Crystal Bee",  color = Color3.fromRGB(180,230,255),  bodyColor = Color3.fromRGB(150,200,240), genRequired = 3 },
    prism_bee   = { name = "Prism Bee",    color = Color3.fromRGB(255,100,200),  bodyColor = Color3.fromRGB(220,80,180),  genRequired = 4 },
    void_bee    = { name = "Void Bee",     color = Color3.fromRGB(60,0,100),     bodyColor = Color3.fromRGB(40,0,80),     genRequired = 5 },
}
]]

local newSrc = src:gsub("(\n*return Config%s*$)", injection .. "%1")
if newSrc == src then newSrc = src .. injection end
clone.Source = newSrc
clone.Name = oldName
clone.Parent = game:GetService("ServerScriptService")

print("✅ STEP A: Config.PRESTIGE_REWARDS + Config.PRESTIGE_COSMETICS added")
print("   Rush: 300s +50% multiplier on every reset")
print("   Skins: gen 1 → golden_bee, gen 2 → obsidian_bee, ..., gen 5+ → void_bee")
```

**Verify Step A:**

```lua
local ok, config = pcall(require, game:GetService("ServerScriptService"):FindFirstChild("Config")
    or game:GetService("ReplicatedStorage"):FindFirstChild("Config"))
assert(ok and config, "Config require failed")
assert(config.PRESTIGE_REWARDS, "PRESTIGE_REWARDS missing")
assert(config.PRESTIGE_REWARDS.rushDuration == 300, "rushDuration mismatch")
assert(config.PRESTIGE_REWARDS.skins[1] == "golden_bee", "skins[1] mismatch")
assert(config.PRESTIGE_COSMETICS, "PRESTIGE_COSMETICS missing")
assert(config.PRESTIGE_COSMETICS.golden_bee, "golden_bee entry missing")
assert(config.PRESTIGE_COSMETICS.void_bee, "void_bee entry missing")
print("✅ STEP A verified: PRESTIGE_REWARDS + PRESTIGE_COSMETICS present and correct")
```

---

## STEP B — PrestigeRewardService ModuleScript

```lua
-- STEP B: Create PrestigeRewardService ModuleScript in ServerScriptService
local SSS = game:GetService("ServerScriptService")
local old = SSS:FindFirstChild("PrestigeRewardService")
if old then old:Destroy() end

local svc = Instance.new("ModuleScript")
svc.Name   = "PrestigeRewardService"
svc.Source = [[
--!strict
-- PrestigeRewardService — generation reset rewards (dispatch 33)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config      = require(game:GetService("ServerScriptService"):FindFirstChild("Config")
                       or ReplicatedStorage:FindFirstChild("Config"))
local DataService = require(game:GetService("ServerScriptService"):FindFirstChild("DataService"))

local remotes  = ReplicatedStorage:FindFirstChild("Remotes")
local Notify   = remotes and remotes:FindFirstChild("Notify")
local WardrobeDataSync = remotes and remotes:FindFirstChild("WardrobeDataSync")
local HudDataSync      = remotes and remotes:FindFirstChild("HudDataSync")

-- Per-player prestige rush state: { endTime: number, multiplier: number }
local _rushState: { [Player]: { endTime: number, multiplier: number } } = {}

-- ---------------------------------------------------------------
-- Internal: grant prestige cosmetic skin for a given generation
-- ---------------------------------------------------------------
local function grantPrestigeSkin(player: Player, profile: any, generation: number): ()
    local rewards  = Config.PRESTIGE_REWARDS
    if not rewards then return end
    local tier     = math.clamp(generation, 1, rewards.maxSkinGen or 5)
    local skinKey  = rewards.skins[tier]
    if not skinKey then return end

    -- Idempotent: only grant if not already owned
    if not profile.cosmeticsUnlocked then profile.cosmeticsUnlocked = {} end
    for _, owned in profile.cosmeticsUnlocked do
        if owned == skinKey then return end  -- already has it
    end

    table.insert(profile.cosmeticsUnlocked, skinKey)

    local cosmInfo = Config.PRESTIGE_COSMETICS and Config.PRESTIGE_COSMETICS[skinKey]
    local skinName = cosmInfo and cosmInfo.name or skinKey

    if Notify then
        Notify:FireClient(player, {
            message = "✨ Prestige skin unlocked: " .. skinName .. "! Check your Wardrobe.",
            kind    = "success",
        })
    end
    if WardrobeDataSync then
        WardrobeDataSync:FireClient(player, { cosmeticsUnlocked = profile.cosmeticsUnlocked })
    end
end

-- ---------------------------------------------------------------
-- Internal: start prestige rush multiplier window
-- ---------------------------------------------------------------
local function startRush(player: Player, profile: any): ()
    local dur = (Config.PRESTIGE_REWARDS and Config.PRESTIGE_REWARDS.rushDuration) or 300
    _rushState[player] = {
        endTime    = os.clock() + dur,
        multiplier = 1.5,
    }

    if Notify then
        local label = Config.PRESTIGE_REWARDS and Config.PRESTIGE_REWARDS.rushLabel or "🏆 Prestige Rush"
        local desc  = Config.PRESTIGE_REWARDS and Config.PRESTIGE_REWARDS.rushDesc  or "+50% honey for 5 minutes!"
        Notify:FireClient(player, { message = label .. " — " .. desc, kind = "success" })
    end

    -- Auto-expire
    task.delay(dur + 1, function(): ()
        if _rushState[player] then
            _rushState[player] = nil
            -- Notify expiry
            if Notify and player.Parent then
                Notify:FireClient(player, { message = "⏱ Prestige Rush ended.", kind = "info" })
            end
        end
    end)
end

-- ---------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------
local PrestigeRewardService = {}

-- Called by PrestigeService (or Main) immediately after a generation reset
-- profile.generation should already be incremented before this call
function PrestigeRewardService.OnPrestige(player: Player): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local gen = profile.generation or 1

    -- 1. Grant skin for this generation
    grantPrestigeSkin(player, profile, gen)

    -- 2. Start rush window
    startRush(player, profile)

    -- 3. Save profile (skin added to cosmeticsUnlocked)
    DataService.SaveProfile(player)
end

-- Returns the active honey multiplier for this player (1.0 if no rush, 1.5 during rush)
function PrestigeRewardService.GetHoneyMultiplier(player: Player): number
    local state = _rushState[player]
    if not state then return 1.0 end
    if os.clock() > state.endTime then
        _rushState[player] = nil
        return 1.0
    end
    return state.multiplier
end

-- Returns seconds remaining in the rush window (0 if not active)
function PrestigeRewardService.GetRushTimeRemaining(player: Player): number
    local state = _rushState[player]
    if not state then return 0 end
    local remaining = state.endTime - os.clock()
    if remaining <= 0 then
        _rushState[player] = nil
        return 0
    end
    return remaining
end

-- Cleanup on player leave
function PrestigeRewardService.OnPlayerRemoving(player: Player): ()
    _rushState[player] = nil
end

function PrestigeRewardService.Init(): ()
    Players.PlayerRemoving:Connect(PrestigeRewardService.OnPlayerRemoving)
end

return PrestigeRewardService
]]
svc.Parent = SSS

print("✅ STEP B: PrestigeRewardService ModuleScript created in ServerScriptService")
print("   API: OnPrestige(player), GetHoneyMultiplier(player), GetRushTimeRemaining(player), Init()")
```

**Verify Step B:**

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("PrestigeRewardService")
assert(svc and svc:IsA("ModuleScript"), "PrestigeRewardService missing or wrong type")
local src = svc.Source
assert(src:find("OnPrestige"), "OnPrestige missing")
assert(src:find("GetHoneyMultiplier"), "GetHoneyMultiplier missing")
assert(src:find("GetRushTimeRemaining"), "GetRushTimeRemaining missing")
assert(src:find("grantPrestigeSkin"), "grantPrestigeSkin missing")
assert(src:find("startRush"), "startRush missing")
assert(src:find("--!strict"), "--!strict missing")
print("✅ STEP B verified: PrestigeRewardService all key functions present")
```

---

## STEP C — Wire into PrestigeService

PrestigeService (dispatch 19) handles the generation reset. Find the moment it increments
`profile.generation` and call `PrestigeRewardService.OnPrestige(player)` immediately after.

```lua
-- STEP C: Inject PrestigeRewardService.OnPrestige call into PrestigeService
local SSS = game:GetService("ServerScriptService")
local prestigeSvc = SSS:FindFirstChild("PrestigeService")
assert(prestigeSvc, "PrestigeService not found — check it's in ServerScriptService")

local src = prestigeSvc.Source
if src:find("PrestigeRewardService") then
    print("✅ STEP C: PrestigeService already references PrestigeRewardService — no change needed")
else
    local clone = prestigeSvc:Clone()
    local oldName = prestigeSvc.Name
    prestigeSvc.Name = oldName .. "_OLD_33C"
    prestigeSvc.Parent = nil

    -- Inject require at top of file (after existing requires, before any function definitions)
    local requireLine = "\nlocal PrestigeRewardService = require(game:GetService(\"ServerScriptService\"):FindFirstChild(\"PrestigeRewardService\"))\n"

    -- Inject OnPrestige call after profile.generation increment
    -- Strategy: match 'profile.generation = profile.generation + 1' pattern or 'gen + 1'
    local callLine = "\n\t-- Dispatch 33: fire prestige rewards (skin unlock + rush window)\n\tPrestigeRewardService.OnPrestige(player)\n"

    local newSrc = src

    -- Add require at top (after first require statement)
    newSrc = newSrc:gsub("(local%s+%w+%s*=%s*require%b().-\n)", "%1" .. requireLine, 1)
    if newSrc == src then
        -- fallback: prepend to file
        newSrc = requireLine .. src
    end

    -- Inject OnPrestige after generation increment
    newSrc = newSrc:gsub(
        "(profile%.generation%s*=%s*profile%.generation%s*%+%s*1)",
        "%1" .. callLine
    )
    if newSrc == src then
        -- fallback: search for 'gen' increment pattern
        newSrc = newSrc:gsub(
            "(generation%s*=%s*generation%s*%+%s*1)",
            "%1" .. callLine
        )
    end

    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS

    if clone.Source:find("PrestigeRewardService") then
        print("✅ STEP C: PrestigeRewardService.OnPrestige injected into PrestigeService")
    else
        warn("⚠ STEP C: Could not find generation increment pattern in PrestigeService.")
        warn("   Manual fix: add 'PrestigeRewardService.OnPrestige(player)' after the generation increment line")
        warn("   and 'local PrestigeRewardService = require(ServerScriptService.PrestigeRewardService)' at top")
    end
end
```

---

## STEP D — Wire GetHoneyMultiplier into ForagingService

ForagingService already multiplies yield by `weatherMult * seasonalMult` (dispatch 30).
Add `prestigeMult` from `PrestigeRewardService.GetHoneyMultiplier(player)`.

```lua
-- STEP D: Inject prestigeMult into ForagingService yield calculation
local SSS = game:GetService("ServerScriptService")
local foragingSvc = SSS:FindFirstChild("ForagingService")
assert(foragingSvc, "ForagingService not found")

local src = foragingSvc.Source
if src:find("PrestigeRewardService") then
    print("✅ STEP D: ForagingService already references PrestigeRewardService — no change needed")
else
    local clone = foragingSvc:Clone()
    local oldName = foragingSvc.Name
    foragingSvc.Name = oldName .. "_OLD_33D"
    foragingSvc.Parent = nil

    local newSrc = clone.Source

    -- Inject require (after first require)
    local reqLine = "\nlocal PrestigeRewardService = require(game:GetService(\"ServerScriptService\"):FindFirstChild(\"PrestigeRewardService\"))\n"
    newSrc = newSrc:gsub("(local%s+%w+%s*=%s*require%b().-\n)", "%1" .. reqLine, 1)
    if newSrc == clone.Source then newSrc = reqLine .. newSrc end

    -- Inject prestigeMult variable and multiply into yield
    -- Match: local seasonalMult = SeasonalEventService.GetYieldMult()
    local multLine = "\n\tlocal prestigeMult = PrestigeRewardService.GetHoneyMultiplier(player)\n"
    newSrc = newSrc:gsub(
        "(local%s+seasonalMult%s*=%s*SeasonalEventService%.GetYieldMult%s*%(%s*%))",
        "%1" .. multLine
    )
    -- Now replace the yield multiplication chain
    newSrc = newSrc:gsub(
        "(%*%s*weatherMult%s*%*%s*seasonalMult)",
        "%1 * prestigeMult"
    )

    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS

    if clone.Source:find("prestigeMult") then
        print("✅ STEP D: prestigeMult injected into ForagingService yield calculation")
    else
        warn("⚠ STEP D: Could not find seasonal/weather mult pattern in ForagingService.")
        warn("   Manual fix: add 'local prestigeMult = PrestigeRewardService.GetHoneyMultiplier(player)'")
        warn("   and multiply it into the yield formula alongside weatherMult * seasonalMult")
    end
end
```

---

## STEP E — PrestigeRushGui client indicator

Shows a countdown timer in the HUD corner while the Prestige Rush is active.
Uses a new `PrestigeRushSync` RemoteEvent fired from the server on rush start/end.

```lua
-- STEP E: PrestigeRushSync RemoteEvent + PrestigeRushGui LocalScript
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
assert(remotes, "Remotes folder not found")

-- Create RemoteEvent
if not remotes:FindFirstChild("PrestigeRushSync") then
    local ev = Instance.new("RemoteEvent")
    ev.Name   = "PrestigeRushSync"
    ev.Parent = remotes
    print("PrestigeRushSync RemoteEvent created")
else
    print("PrestigeRushSync already exists")
end

-- LocalScript
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local old = SPS and SPS:FindFirstChild("PrestigeRushGui")
if old then old:Destroy() end

local ls = Instance.new("LocalScript")
ls.Name   = "PrestigeRushGui"
ls.Source = [[
--!strict
-- PrestigeRushGui — countdown timer for prestige rush window (dispatch 33)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local remotes        = ReplicatedStorage:WaitForChild("Remotes", 10)
local PrestigeRushSync = remotes:WaitForChild("PrestigeRushSync", 10)

-- Build GUI
local sGui = Instance.new("ScreenGui")
sGui.Name             = "PrestigeRushGui"
sGui.IgnoreGuiInset   = true
sGui.DisplayOrder     = 45
sGui.ResetOnSpawn     = false
sGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
sGui.Parent           = playerGui

local frame = Instance.new("Frame")
frame.Name                  = "RushBanner"
frame.Size                  = UDim2.new(0.28, 0, 0.07, 0)
frame.Position              = UDim2.new(0.36, 0, 0.01, 0)
frame.AnchorPoint           = Vector2.new(0, 0)
frame.BackgroundColor3      = Color3.fromRGB(100, 40, 0)
frame.BackgroundTransparency = 1  -- hidden until rush
frame.BorderSizePixel       = 0
frame.ZIndex                = 2
frame.Parent                = sGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold
stroke.Thickness = 2
stroke.Parent    = frame

local label = Instance.new("TextLabel")
label.Name              = "Label"
label.Size              = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.TextColor3        = Color3.fromRGB(242, 168, 28)
label.Font              = Enum.Font.FredokaOne
label.TextScaled        = true
label.Text              = "🏆 Rush: 5:00"
label.ZIndex            = 3
label.Parent            = frame

-- State
local _rushEndTime: number? = nil
local _tickConn: RBXScriptConnection? = nil

local FADE_IN  = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function showBanner(): ()
    TweenService:Create(frame, FADE_IN, { BackgroundTransparency = 0.15 }):Play()
end

local function hideBanner(): ()
    TweenService:Create(frame, FADE_OUT, { BackgroundTransparency = 1 }):Play()
end

local function formatTime(secs: number): string
    local m = math.floor(secs / 60)
    local s = math.floor(secs % 60)
    return string.format("%d:%02d", m, s)
end

local function startCountdown(endTime: number): ()
    _rushEndTime = endTime
    showBanner()
    if _tickConn then _tickConn:Disconnect() end
    _tickConn = game:GetService("RunService").Heartbeat:Connect(function(): ()
        if not _rushEndTime then return end
        local remaining = _rushEndTime - os.clock()
        if remaining <= 0 then
            label.Text = "🏆 Rush: 0:00"
            hideBanner()
            _rushEndTime = nil
            if _tickConn then _tickConn:Disconnect() _tickConn = nil end
            return
        end
        label.Text = "🏆 Rush: " .. formatTime(remaining)
    end)
end

PrestigeRushSync.OnClientEvent:Connect(function(data: { endTime: number?, active: boolean? }): ()
    if data.active and data.endTime then
        startCountdown(data.endTime)
    else
        hideBanner()
        _rushEndTime = nil
        if _tickConn then _tickConn:Disconnect() _tickConn = nil end
    end
end)
]]
ls.Parent = SPS

print("✅ STEP E: PrestigeRushSync RemoteEvent + PrestigeRushGui LocalScript created")
```

### Step E wiring note

For the `PrestigeRushSync` event to actually fire, add this inside `startRush()` in
`PrestigeRewardService` (after Step B is in place):

```lua
-- Add to startRush() in PrestigeRewardService after _rushState assignment:
local PrestigeRushSync = remotes and remotes:FindFirstChild("PrestigeRushSync")
if PrestigeRushSync then
    PrestigeRushSync:FireClient(player, { active = true, endTime = os.clock() + dur })
end
```

You can inject this via another clone-and-replace or add it manually.
The GUI degrades gracefully without the sync event (banner simply never shows) — Step E is
fully additive.

---

## STEP F — Full verification

```lua
-- STEP F: Full dispatch 33 verification
local SSS     = game:GetService("ServerScriptService")
local RS      = game:GetService("ReplicatedStorage")
local SP      = game:GetService("StarterPlayer")
local SPS     = SP:FindFirstChild("StarterPlayerScripts")
local remotes = RS:FindFirstChild("Remotes")
local results = {}
local issues  = {}

-- 1. Config.PRESTIGE_REWARDS
local ok, config = pcall(require, SSS:FindFirstChild("Config") or RS:FindFirstChild("Config"))
if ok and config then
    if config.PRESTIGE_REWARDS and config.PRESTIGE_REWARDS.rushDuration and config.PRESTIGE_REWARDS.skins then
        table.insert(results, "✅ Config.PRESTIGE_REWARDS present (rush=" .. config.PRESTIGE_REWARDS.rushDuration .. "s, skins=" .. #config.PRESTIGE_REWARDS.skins .. ")")
    else
        table.insert(issues, "❌ Config.PRESTIGE_REWARDS incomplete")
    end
    if config.PRESTIGE_COSMETICS and config.PRESTIGE_COSMETICS.golden_bee and config.PRESTIGE_COSMETICS.void_bee then
        table.insert(results, "✅ Config.PRESTIGE_COSMETICS: golden_bee + void_bee present")
    else
        table.insert(issues, "❌ Config.PRESTIGE_COSMETICS missing or incomplete")
    end
else
    table.insert(issues, "❌ Config require failed")
end

-- 2. PrestigeRewardService
local svc = SSS:FindFirstChild("PrestigeRewardService")
if svc and svc:IsA("ModuleScript") then
    local src = svc.Source
    local allOk = src:find("OnPrestige") and src:find("GetHoneyMultiplier") and src:find("GetRushTimeRemaining") and src:find("grantPrestigeSkin") and src:find("--!strict")
    if allOk then
        table.insert(results, "✅ PrestigeRewardService: all API methods present")
    else
        table.insert(issues, "❌ PrestigeRewardService missing some API methods")
    end
else
    table.insert(issues, "❌ PrestigeRewardService not found")
end

-- 3. PrestigeService wired
local prestigeSvc = SSS:FindFirstChild("PrestigeService")
if prestigeSvc and prestigeSvc.Source:find("PrestigeRewardService") then
    table.insert(results, "✅ PrestigeService references PrestigeRewardService")
else
    table.insert(issues, "⚠ PrestigeService does not reference PrestigeRewardService — manual wiring may be needed")
end

-- 4. ForagingService wired
local foragingSvc = SSS:FindFirstChild("ForagingService")
if foragingSvc and foragingSvc.Source:find("prestigeMult") then
    table.insert(results, "✅ ForagingService: prestigeMult injected into yield formula")
else
    table.insert(issues, "⚠ ForagingService does not reference prestigeMult — manual wiring may be needed")
end

-- 5. PrestigeRushSync RemoteEvent
if remotes and remotes:FindFirstChild("PrestigeRushSync") then
    table.insert(results, "✅ PrestigeRushSync RemoteEvent exists")
else
    table.insert(issues, "❌ PrestigeRushSync RemoteEvent missing")
end

-- 6. PrestigeRushGui LocalScript
local rushGui = SPS and SPS:FindFirstChild("PrestigeRushGui")
if rushGui and rushGui:IsA("LocalScript") then
    table.insert(results, "✅ PrestigeRushGui LocalScript in StarterPlayerScripts")
else
    table.insert(issues, "❌ PrestigeRushGui LocalScript missing")
end

-- Summary
print("\n=== DISPATCH 33 VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\nISSUES:")
    for _, i in issues do print(i) end
else
    print("\n🎉 All checks passed — dispatch 33 complete!")
    print("   Prestige now grants: skin unlock (gen 1-5) + 5-min +50% rush window")
    print("   ForagingService yield = baseRate × weatherMult × seasonalMult × prestigeMult")
end
```

---

## Execution order checklist

1. ☐ **STEP A** — Add Config.PRESTIGE_REWARDS + Config.PRESTIGE_COSMETICS  
2. ☐ **STEP B** — Create PrestigeRewardService ModuleScript  
3. ☐ **STEP C** — Wire OnPrestige call into PrestigeService  
4. ☐ **STEP D** — Wire GetHoneyMultiplier into ForagingService  
5. ☐ **STEP E** — PrestigeRushSync RemoteEvent + PrestigeRushGui LocalScript  
6. ☐ **STEP F** — Full verification  

---

## Testing notes

- **Simulate prestige in Studio:**
  ```lua
  local SSS = game:GetService("ServerScriptService")
  local PRS = require(SSS:FindFirstChild("PrestigeRewardService"))
  local player = game:GetService("Players"):GetPlayers()[1]
  -- Manually set gen to test skin tiers
  local DataService = require(SSS:FindFirstChild("DataService"))
  DataService.GetProfile(player).generation = 1
  PRS.OnPrestige(player)
  -- Should fire Notify toast + grant golden_bee + start rush
  ```

- **Verify multiplier:**
  ```lua
  print(PRS.GetHoneyMultiplier(player))  -- should print 1.5 during rush
  print(PRS.GetRushTimeRemaining(player))  -- should print ~300
  ```

- **After 5 minutes** (or set `rushDuration = 10` temporarily): multiplier returns to 1.0.

---

## Part budget

| Step | Parts added | Running total |
|------|-------------|---------------|
| All  | 0 (scripting only) | 4,098 |
| **Total** | **0** | **~4,098 / 5,000** |
