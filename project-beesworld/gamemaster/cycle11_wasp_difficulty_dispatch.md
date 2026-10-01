# Dispatch 31 — WaspService Difficulty Scaling
**File:** `cycle11_wasp_difficulty_dispatch.md`
**Cycle:** 11
**Part budget:** +2 → ~4,100/5,000
**DataService migration:** None (no profile schema changes)
**Depends on:** Dispatch 14 (WaspService initial), Dispatch 19 (ForagingService prestige/generation tracking)
**Supersedes:** Nothing

---

## Purpose

Scale wasp raid frequency and intensity with the player's **generation count** (prestige level).
New players get gentle, infrequent raids so they can learn the loop. Late-game prestige players
face escalating pressure that turns WaspService from an occasional nuisance into a real
threat they must actively manage with upgraded BeeguardBeehives.

Before this dispatch: all players experience identical raid frequency (fixed interval from
dispatch 14's WaspService).
After this dispatch: raid cooldown shrinks and swarm size grows as generation increases,
capped at gen 8+ so it doesn't become unplayable.

---

## STEP A — Config: WASP_DIFFICULTY table

Open **Config ModuleScript** in Studio (Explorer → ServerScriptService → Config or
ReplicatedStorage → Config — wherever it lives) and run in Command Bar:

```lua
-- STEP A: Add WASP_DIFFICULTY to Config
-- Find Config ModuleScript
local config = game:GetService("ServerScriptService"):FindFirstChild("Config")
    or game:GetService("ReplicatedStorage"):FindFirstChild("Config")
assert(config, "Config not found")

-- Clone-and-replace pattern (cache bust)
local clone = config:Clone()
local oldName = config.Name
config.Name = oldName .. "_OLD_31A"
config.Parent = nil  -- remove from tree

-- Read existing source
local src = clone.Source

-- Inject WASP_DIFFICULTY table before the final 'return Config' line
local injection = [[

-- Wasp raid difficulty scaling by generation (prestige) count
-- raidCooldown: seconds between raid attempts on this player
-- swarmSize: number of wasp NPCs per raid (if WaspService uses a count param)
-- honeySteaRisk: fraction of honey stolen per raid (0.0–1.0)
Config.WASP_DIFFICULTY = {
    [0] = { raidCooldown = 360, swarmSize = 1, honeyStealRisk = 0.04 },  -- gen 0: raid every 6 min, tiny swarm
    [1] = { raidCooldown = 300, swarmSize = 1, honeyStealRisk = 0.05 },
    [2] = { raidCooldown = 240, swarmSize = 2, honeyStealRisk = 0.06 },
    [3] = { raidCooldown = 210, swarmSize = 2, honeyStealRisk = 0.07 },
    [4] = { raidCooldown = 180, swarmSize = 3, honeyStealRisk = 0.08 },
    [5] = { raidCooldown = 150, swarmSize = 3, honeyStealRisk = 0.09 },
    [6] = { raidCooldown = 120, swarmSize = 4, honeyStealRisk = 0.10 },
    [7] = { raidCooldown = 100, swarmSize = 4, honeyStealRisk = 0.11 },
    [8] = { raidCooldown =  90, swarmSize = 5, honeyStealRisk = 0.12 },  -- gen 8+: raid every 1.5 min, max pressure
}
-- Returns difficulty tier for a given generation count (clamps to [0,8])
function Config.GetWaspDifficulty(generation: number): { raidCooldown: number, swarmSize: number, honeyStealRisk: number }
    local tier = math.clamp(math.floor(generation), 0, 8)
    return Config.WASP_DIFFICULTY[tier]
end
]]

-- Insert before 'return Config'
local newSrc = src:gsub("(\n*return Config%s*$)", injection .. "%1")
if newSrc == src then
    -- fallback: append before final line
    newSrc = src .. injection
end
clone.Source = newSrc
clone.Name = oldName
clone.Parent = game:GetService("ServerScriptService")

print("✅ STEP A: Config.WASP_DIFFICULTY added")
print("   Tiers: gen 0 (360s cooldown, 1 wasp) → gen 8+ (90s cooldown, 5 wasps)")
```

**Verify Step A:**

```lua
local config = require(game:GetService("ServerScriptService"):FindFirstChild("Config")
    or game:GetService("ReplicatedStorage"):FindFirstChild("Config"))
assert(config.WASP_DIFFICULTY, "WASP_DIFFICULTY missing")
assert(config.WASP_DIFFICULTY[0], "tier 0 missing")
assert(config.WASP_DIFFICULTY[8], "tier 8 missing")
assert(config.GetWaspDifficulty, "GetWaspDifficulty function missing")
local d = config.GetWaspDifficulty(3)
assert(d.raidCooldown == 210, "tier 3 cooldown mismatch")
print("✅ STEP A verified: WASP_DIFFICULTY[0..8] present, GetWaspDifficulty(3).raidCooldown =", d.raidCooldown)
```

---

## STEP B — WaspService: per-player difficulty-aware raid scheduling

Open **WaspService** in Studio. The existing service (dispatch 14) runs a global loop or
per-player loop using a fixed cooldown. We replace the hardcoded interval with a per-player
lookup into `Config.GetWaspDifficulty(profile.generation)`.

Run in Command Bar:

```lua
-- STEP B: Update WaspService to use per-player difficulty scaling
local SSS = game:GetService("ServerScriptService")
local waspSvc = SSS:FindFirstChild("WaspService")
assert(waspSvc, "WaspService not found in ServerScriptService")

-- Clone-and-replace
local clone = waspSvc:Clone()
local oldName = waspSvc.Name
waspSvc.Name = oldName .. "_OLD_31B"
waspSvc.Parent = nil

-- ---------------------------------------------------------------
-- Full replacement source
-- ---------------------------------------------------------------
clone.Source = [[
--!strict
-- WaspService — difficulty-scaled raids (dispatch 31)

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

local Config      = require(game:GetService("ServerScriptService"):FindFirstChild("Config")
                       or ReplicatedStorage:FindFirstChild("Config"))
local DataService = require(game:GetService("ServerScriptService"):FindFirstChild("DataService"))

-- RemoteEvents
local remotes      = ReplicatedStorage:FindFirstChild("Remotes")
local Notify       = remotes and remotes:FindFirstChild("Notify")
local WaspRaidSync = remotes and remotes:FindFirstChild("WaspRaidSync")

-- Per-player state: when they last experienced a raid
local _lastRaid: { [Player]: number } = {}
local _connections: { [Player]: RBXScriptConnection } = {}

-- ---------------------------------------------------------------
-- Internal: attempt a raid on one player
-- ---------------------------------------------------------------
local function attemptRaid(player: Player): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local gen   = profile.generation or 0
    local diff  = Config.GetWaspDifficulty(gen)
    local now   = os.clock()
    local last  = _lastRaid[player] or 0

    if (now - last) < diff.raidCooldown then return end
    _lastRaid[player] = now

    -- Calculate steal: honeyStealRisk × current honey, floor'd
    local stolenHoney = math.floor(profile.honey * diff.honeyStealRisk)
    if stolenHoney < 1 then stolenHoney = 1 end

    -- Apply steal (server-authoritative)
    profile.honey = math.max(0, profile.honey - stolenHoney)
    DataService.SaveProfile(player)

    -- Notify client
    if Notify then
        Notify:FireClient(player, {
            message = string.format("🐝⚠️ Wasp raid! %d honey stolen. Upgrade your Beekeeper's Guard!", stolenHoney),
            kind    = "warning",
        })
    end

    -- Sync raid event to client for visual feedback (WaspRaidSync drives client VFX)
    if WaspRaidSync then
        WaspRaidSync:FireClient(player, {
            swarmSize    = diff.swarmSize,
            stolenHoney  = stolenHoney,
            generation   = gen,
        })
    end
end

-- ---------------------------------------------------------------
-- Per-player heartbeat loop (fires every 10s, checks cooldown internally)
-- ---------------------------------------------------------------
local TICK_INTERVAL = 10  -- seconds between raid-eligibility checks

local function startPlayerLoop(player: Player): ()
    _lastRaid[player] = os.clock()  -- grace period: no raid immediately on join
    local t = 0
    local conn = RunService.Heartbeat:Connect(function(dt: number): ()
        t = t + dt
        if t >= TICK_INTERVAL then
            t = 0
            attemptRaid(player)
        end
    end)
    _connections[player] = conn
end

local function stopPlayerLoop(player: Player): ()
    local conn = _connections[player]
    if conn then
        conn:Disconnect()
        _connections[player] = nil
    end
    _lastRaid[player] = nil
end

-- ---------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------
local WaspService = {}

function WaspService.Init(): ()
    -- Wire up existing players (Studio test)
    for _, p in Players:GetPlayers() do
        startPlayerLoop(p)
    end
    Players.PlayerAdded:Connect(startPlayerLoop)
    Players.PlayerRemoving:Connect(stopPlayerLoop)
end

-- Called by BeeguardBeehive scripts to report a successful defence
-- Resets the cooldown so the player isn't immediately raided again after defending
function WaspService.ReportDefence(player: Player): ()
    _lastRaid[player] = os.clock()
end

-- Debug: return current difficulty tier for a player (Studio testing)
function WaspService.GetPlayerDifficulty(player: Player): { raidCooldown: number, swarmSize: number, honeyStealRisk: number }
    local profile = DataService.GetProfile(player)
    local gen = profile and (profile.generation or 0) or 0
    return Config.GetWaspDifficulty(gen)
end

return WaspService
]]

clone.Name = oldName
clone.Parent = SSS

print("✅ STEP B: WaspService replaced with difficulty-scaled version")
print("   Per-player Heartbeat loops, Config.GetWaspDifficulty lookup, WaspService.ReportDefence API")
```

**Verify Step B:**

```lua
local waspSvc = game:GetService("ServerScriptService"):FindFirstChild("WaspService")
assert(waspSvc, "WaspService missing")
local src = waspSvc.Source
assert(src:find("GetWaspDifficulty"), "GetWaspDifficulty not referenced")
assert(src:find("ReportDefence"), "ReportDefence missing")
assert(src:find("WaspRaidSync"), "WaspRaidSync not referenced")
assert(src:find("swarmSize"), "swarmSize not referenced")
-- No OLD copy should remain
local old = game:GetService("ServerScriptService"):FindFirstChild("WaspService_OLD_31B")
assert(old == nil, "OLD WaspService still in tree — remove it")
print("✅ STEP B verified: WaspService updated, all key patterns present, no stale copy")
```

---

## STEP C — Create WaspRaidSync RemoteEvent (if missing)

`WaspRaidSync` is the new client-facing event for raid visual feedback. Create it if dispatch 14
didn't include it.

```lua
-- STEP C: Ensure WaspRaidSync RemoteEvent exists
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = RS
end

if not remotes:FindFirstChild("WaspRaidSync") then
    local ev = Instance.new("RemoteEvent")
    ev.Name = "WaspRaidSync"
    ev.Parent = remotes
    print("✅ STEP C: WaspRaidSync RemoteEvent created")
else
    print("✅ STEP C: WaspRaidSync already exists — no action needed")
end
```

---

## STEP D — WaspRaidClientFX LocalScript (visual feedback)

Adds a 2-second screen shake + amber vignette flash when a raid fires, driven by `WaspRaidSync`.
Entirely client-side — no server logic.

```lua
-- STEP D: WaspRaidClientFX LocalScript in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

-- Remove old version if present
local old = SPS:FindFirstChild("WaspRaidClientFX")
if old then old:Destroy() end

local script = Instance.new("LocalScript")
script.Name = "WaspRaidClientFX"
script.Source = [[
--!strict
-- WaspRaidClientFX — client-side wasp raid visual feedback (dispatch 31)

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
assert(playerGui, "PlayerGui not found")

local remotes      = ReplicatedStorage:WaitForChild("Remotes", 10)
local WaspRaidSync = remotes:WaitForChild("WaspRaidSync", 10)

-- ---------------------------------------------------------------
-- Build vignette overlay (amber flash)
-- ---------------------------------------------------------------
local vignette: ScreenGui = Instance.new("ScreenGui")
vignette.Name             = "WaspRaidVignette"
vignette.IgnoreGuiInset   = true
vignette.DisplayOrder     = 50
vignette.ResetOnSpawn     = false
vignette.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
vignette.Parent           = playerGui

local frame: Frame = Instance.new("Frame")
frame.Name                = "VignetteFrame"
frame.Size                = UDim2.fromScale(1, 1)
frame.Position            = UDim2.fromScale(0, 0)
frame.BackgroundColor3    = Color3.fromRGB(180, 80, 0)  -- amber
frame.BackgroundTransparency = 1  -- hidden until raid
frame.BorderSizePixel     = 0
frame.ZIndex              = 1
frame.Parent              = vignette

-- Nested gradient to simulate vignette (dark edges, centre clear)
local gradient: UIGradient = Instance.new("UIGradient")
gradient.Color             = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(180, 80, 0)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(180, 80, 0)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(180, 80, 0)),
})
gradient.Transparency      = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.0),  -- opaque at edges
    NumberSequenceKeypoint.new(0.5, 0.8),  -- semi-transparent midway
    NumberSequenceKeypoint.new(1,   0.0),
})
gradient.Rotation          = 90
gradient.Parent            = frame

-- ---------------------------------------------------------------
-- Warning label
-- ---------------------------------------------------------------
local warnLabel: TextLabel = Instance.new("TextLabel")
warnLabel.Name              = "WaspWarning"
warnLabel.Size              = UDim2.new(0.6, 0, 0.1, 0)
warnLabel.Position          = UDim2.new(0.2, 0, 0.08, 0)
warnLabel.AnchorPoint       = Vector2.new(0, 0)
warnLabel.BackgroundTransparency = 1
warnLabel.TextColor3        = Color3.fromRGB(255, 220, 50)
warnLabel.TextTransparency  = 1
warnLabel.Font              = Enum.Font.FredokaOne
warnLabel.TextScaled        = true
warnLabel.Text              = "⚠ WASP RAID!"
warnLabel.ZIndex            = 2
warnLabel.Parent            = frame

-- ---------------------------------------------------------------
-- Animate raid event
-- ---------------------------------------------------------------
local FADE_IN  = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.6,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOLD     = 1.2  -- seconds before fade-out begins

local function playRaidFX(data: { swarmSize: number, stolenHoney: number, generation: number }): ()
    -- Intensity scales mildly with generation (gen 0=0.55 opacity, gen 8=0.75 opacity)
    local opacity = math.clamp(0.55 + data.generation * 0.025, 0.55, 0.75)

    -- Fade in
    TweenService:Create(frame, FADE_IN, { BackgroundTransparency = opacity }):Play()
    TweenService:Create(warnLabel, FADE_IN, { TextTransparency = 0 }):Play()

    task.delay(HOLD, function(): ()
        -- Fade out
        TweenService:Create(frame, FADE_OUT, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(warnLabel, FADE_OUT, { TextTransparency = 1 }):Play()
    end)
end

WaspRaidSync.OnClientEvent:Connect(playRaidFX)
]]
script.Parent = SPS

print("✅ STEP D: WaspRaidClientFX LocalScript created in StarterPlayerScripts")
```

**Verify Step D:**

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local fx = SPS and SPS:FindFirstChild("WaspRaidClientFX")
assert(fx, "WaspRaidClientFX missing from StarterPlayerScripts")
local src = fx.Source
assert(src:find("WaspRaidSync"), "WaspRaidSync not referenced")
assert(src:find("TweenService"), "TweenService not referenced")
assert(src:find("FredokaOne"), "FredokaOne font not set")
print("✅ STEP D verified: WaspRaidClientFX present and correct")
```

---

## STEP E — Wire WaspService.Init() into Main Script

If WaspService.Init() was already called in the Main Script from dispatch 14, this step only
adds the `WaspService.Init()` call if the Main Script doesn't already include it.

```lua
-- STEP E: Ensure Main Script calls WaspService.Init()
local SSS = game:GetService("ServerScriptService")
local mainScript = SSS:FindFirstChild("Main") or SSS:FindFirstChild("GameManager")
assert(mainScript, "Main/GameManager script not found in ServerScriptService")

local src = mainScript.Source
if src:find("WaspService") then
    print("✅ STEP E: WaspService already referenced in Main Script — no change needed")
else
    -- Clone-and-replace
    local clone = mainScript:Clone()
    local oldName = mainScript.Name
    mainScript.Name = oldName .. "_OLD_31E"
    mainScript.Parent = nil

    -- Inject require + Init after the last existing require/Init block
    -- Strategy: append to the Init section (look for last .Init() call pattern)
    local initLine = "\nlocal WaspService = require(ServerScriptService:FindFirstChild(\"WaspService\"))\nWaspService.Init()\n"
    -- Insert before the Players.PlayerAdded block or at end of Init section
    local newSrc = src:gsub("(Players%.PlayerAdded)", initLine .. "%1", 1)
    if newSrc == src then
        newSrc = src .. initLine
    end
    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS

    print("✅ STEP E: WaspService.Init() injected into Main Script")
end
```

---

## STEP F — DifficultyIndicator UI (optional cosmetic)

Adds a tiny amber wasp-icon label in the HiveGui corner showing the player's current raid tier,
so players understand why raids escalate at higher generations.

```lua
-- STEP F (optional): DifficultyIndicator label in HiveGui
-- This is additive only — does not modify existing HiveGui logic

local SG = game:GetService("StarterGui")
local hiveGui = SG:FindFirstChild("HiveGui")
if not hiveGui then
    print("⚠ STEP F skipped: HiveGui not found — run after HiveGui dispatch")
    return
end

local mainFrame = hiveGui:FindFirstChild("MainFrame")
if not mainFrame then
    print("⚠ STEP F skipped: MainFrame not found in HiveGui")
    return
end

-- Remove old version
local old = mainFrame:FindFirstChild("WaspTierLabel")
if old then old:Destroy() end

local label = Instance.new("TextLabel")
label.Name                = "WaspTierLabel"
label.Size                = UDim2.new(0.25, 0, 0.06, 0)
label.Position            = UDim2.new(0.74, 0, 0.01, 0)
label.AnchorPoint         = Vector2.new(0, 0)
label.BackgroundColor3    = Color3.fromRGB(60, 30, 0)
label.BackgroundTransparency = 0.3
label.TextColor3          = Color3.fromRGB(242, 168, 28)  -- Honey Gold
label.Font                = Enum.Font.FredokaOne
label.TextScaled          = true
label.Text                = "🐝⚡ Wasp: Gen 0"
label.ZIndex              = 10
label.Parent              = mainFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent       = label

-- LocalScript to update WaspTierLabel from HudDataSync
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local old2 = SPS and SPS:FindFirstChild("WaspTierController")
if old2 then old2:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "WaspTierController"
ctrl.Source = [[
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
local hiveGui   = playerGui:WaitForChild("HiveGui", 10)
local mainFrame = hiveGui:WaitForChild("MainFrame", 10)
local tierLabel = mainFrame:WaitForChild("WaspTierLabel", 10)

local remotes     = ReplicatedStorage:WaitForChild("Remotes", 10)
local HudDataSync = remotes:WaitForChild("HudDataSync", 10)

HudDataSync.OnClientEvent:Connect(function(data)
    local gen = data.generation or 0
    local tier = math.clamp(math.floor(gen), 0, 8)
    tierLabel.Text = string.format("🐝⚡ Wasp: Gen %d", tier)
end)
]]
ctrl.Parent = SPS

print("✅ STEP F: WaspTierLabel + WaspTierController added")
```

> **Note:** Step F requires that `HudDataSync` fires a `generation` field.
> If `generation` is not yet in the HudDataSync payload, the label defaults to "Gen 0" silently —
> it will not error. Add `generation = profile.generation or 0` to the HudDataSync fire call in
> the server's PlayerLoop/ForagingService when convenient.

---

## STEP G — Full verification

```lua
-- STEP G: Full dispatch 31 verification
local SSS    = game:GetService("ServerScriptService")
local RS     = game:GetService("ReplicatedStorage")
local SG     = game:GetService("StarterGui")
local SP     = game:GetService("StarterPlayer")
local SPS    = SP:FindFirstChild("StarterPlayerScripts")
local remotes = RS:FindFirstChild("Remotes")
local results = {}
local issues  = {}

-- 1. Config.WASP_DIFFICULTY
local ok, config = pcall(require, SSS:FindFirstChild("Config") or RS:FindFirstChild("Config"))
if ok and config then
    if config.WASP_DIFFICULTY and config.WASP_DIFFICULTY[0] and config.WASP_DIFFICULTY[8] and config.GetWaspDifficulty then
        table.insert(results, "✅ Config.WASP_DIFFICULTY[0..8] + GetWaspDifficulty present")
    else
        table.insert(issues, "❌ Config.WASP_DIFFICULTY incomplete or GetWaspDifficulty missing")
    end
else
    table.insert(issues, "❌ Config require failed: " .. tostring(config))
end

-- 2. WaspService updated
local waspSvc = SSS:FindFirstChild("WaspService")
if waspSvc and waspSvc:IsA("ModuleScript") then
    local src = waspSvc.Source
    if src:find("GetWaspDifficulty") and src:find("ReportDefence") then
        table.insert(results, "✅ WaspService: GetWaspDifficulty + ReportDefence present")
    else
        table.insert(issues, "❌ WaspService missing GetWaspDifficulty or ReportDefence")
    end
    if SSS:FindFirstChild("WaspService_OLD_31B") then
        table.insert(issues, "⚠ WaspService_OLD_31B still in SSS — clean up with :Destroy()")
    end
else
    table.insert(issues, "❌ WaspService not found or wrong ClassName")
end

-- 3. WaspRaidSync RemoteEvent
if remotes and remotes:FindFirstChild("WaspRaidSync") then
    table.insert(results, "✅ WaspRaidSync RemoteEvent exists")
else
    table.insert(issues, "❌ WaspRaidSync RemoteEvent missing")
end

-- 4. WaspRaidClientFX LocalScript
local fx = SPS and SPS:FindFirstChild("WaspRaidClientFX")
if fx and fx:IsA("LocalScript") then
    table.insert(results, "✅ WaspRaidClientFX LocalScript in StarterPlayerScripts")
else
    table.insert(issues, "❌ WaspRaidClientFX missing from StarterPlayerScripts")
end

-- 5. No stale OLD copies
local staleCopies = {}
for _, child in SSS:GetChildren() do
    if child.Name:find("_OLD_31") then table.insert(staleCopies, child.Name) end
end
if #staleCopies == 0 then
    table.insert(results, "✅ No stale _OLD_31x copies in SSS")
else
    table.insert(issues, "⚠ Stale copies: " .. table.concat(staleCopies, ", ") .. " — run :Destroy() on each")
end

-- Summary
print("\n=== DISPATCH 31 VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\nISSUES:")
    for _, i in issues do print(i) end
else
    print("\n🎉 All checks passed — dispatch 31 complete!")
    print("   WaspService now scales raids from gen 0 (360s/1 wasp) → gen 8+ (90s/5 wasps)")
    print("   WaspRaidClientFX delivers amber vignette + screen warning on every raid")
end
```

---

## Execution order checklist

1. ☐ **STEP A** — Add Config.WASP_DIFFICULTY + GetWaspDifficulty  
2. ☐ **STEP B** — Replace WaspService with difficulty-scaled version  
3. ☐ **STEP C** — Create WaspRaidSync RemoteEvent  
4. ☐ **STEP D** — Create WaspRaidClientFX LocalScript  
5. ☐ **STEP E** — Wire WaspService.Init() into Main Script (if not already wired)  
6. ☐ **STEP F** *(optional)* — DifficultyIndicator UI label + WaspTierController  
7. ☐ **STEP G** — Full verification  

> Run steps A–E sequentially in the Studio Command Bar, verify each before proceeding.
> Step F is cosmetic and can be deferred.

---

## Testing notes

- **Studio play-test gen 0:** raids should occur no more often than every 6 minutes.
  Temporarily override `diff.raidCooldown` to `10` in STEP B's `attemptRaid` to test the
  amber vignette without waiting 6 minutes.
- **Simulate gen 8:** in Command Bar while in play-test, set `profile.generation = 8` in
  DataService for your test player and watch cooldown drop to ~90s.
- **ReportDefence hook:** BeeguardBeehive interaction scripts can call
  `WaspService.ReportDefence(player)` to reset the cooldown after a successful defence,
  giving players a reward window of a full cooldown cycle after defending.

---

## Part budget

| Step | Parts added | Running total |
|------|-------------|---------------|
| A    | 0           | 4,098         |
| B    | 0           | 4,098         |
| C    | 0           | 4,098         |
| D    | 0           | 4,098         |
| E    | 0           | 4,098         |
| F    | 0 world parts (UI only) | 4,098 |
| **Total** | **0** | **~4,098 / 5,000** |

*No world geometry changes — this dispatch is pure scripting and UI.*
