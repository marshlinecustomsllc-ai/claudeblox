# A Bee's World — Cycle 11 Dispatch: SwarmService (Prestige)

> **Dispatch 21 — supersedes cycle6_swarm_dispatch.md**
>
> cycle6_swarm_dispatch.md was written when DataService was at v4. By execution time it
> will be at v12. This dispatch carries the identical SwarmService / SwarmController /
> CombService.WipeAllCells logic from cycle6, but patches **DataService v12→v13**
> (generation field + perk snapshot), adds a **3-tier perk tree** rewarded on each
> swarm, and wires the **Sun Queen genGate bypass** so T5 unlocks after generation ≥ 1.
> **Do NOT also execute cycle6_swarm_dispatch.md — skip it entirely.**

---

## Overview

Signature Moment 5: **The Swarm** — the prestige mechanic at the 45–60 minute mark.

When a player's hive meets prerequisites and they hold the SwarmPerch:
1. A golden departure beam rises from the Landing Board through the treeline
2. An 8-second silence sequence plays — camera pulls wide, screen fades to black
3. The hive resets: **20% honey carry-over**, structures preserved, generation increments
4. A perk is awarded based on generation count (see perk tree below)
5. Server-wide Notify fires: `"eXemptAttempt's hive has swarmed! Generation 2"`
6. Sun Queen (T5) becomes available once generation ≥ 1

---

## Prerequisites

- All dispatches 1–20 executed in order (especially dispatch 18 — cycle10_queen, which
  sets DataService v12 with `royalJellyProgress` and `Config.QUEEN_TIERS`)
- fix_bug9_duplicate_dataservice.lua already run
- `ReplicatedStorage.Remotes` folder exists
- `ReplicatedStorage.Remotes.Notify` RemoteEvent exists

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| SwarmPerch × 6 (one per plot, small pedestal) | 12 (2/each) |
| **Total new** | **12** |
| **Running total** | **~4,040 / 5,000** |

---

## Design Constants

```
SWARM_PREREQUISITES = {
    queenTier  = 3,       -- T3+ queen required
    minCells   = 15,      -- 15/19 Floor-1 cells built
    minHoney   = 5000,    -- meaningful honey banked
}

SWARM_CARRY_OVER    = 0.20   -- 20% honey survives
SWARM_SEQUENCE_SECS = 8      -- seconds of departure sequence

-- Perk tree (awarded cumulatively; gen1 gets perk1, gen2 adds perk2, etc.)
SWARM_PERKS = {
    [1] = "foragingBoost",      -- +15% foraging speed, permanent
    [2] = "extraRouteSlot",     -- +1 simultaneous waggle-dance route
    [3] = "bearCalm",           -- Old Molasses patience +25%
}
```

---

## STEP A — New RemoteEvents

Run in Studio Command Bar:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local needed = {"SwarmBegin", "SwarmComplete", "RequestSwarm"}
for _, name in needed do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name   = name
        re.Parent = Remotes
        print("Created: " .. name)
    else
        print("Exists: " .. name)
    end
end
-- SwarmBegin:    server → client (starts VFX/camera sequence, arg = plotIndex)
-- SwarmComplete: server → client (generation, carryHoney, perksActive)
-- RequestSwarm:  client → server (no args, player is implicit)
return "Remotes done"
```

---

## STEP B — DataService v12→v13

**Edit `ServerScriptService.Systems.DataService`** using clone-and-replace.

### B1 — Profile template additions

In PROFILE_TEMPLATE, add after `royalJellyProgress` (which was added in cycle10_queen):

```lua
generation    = 0,        -- swarm count; 0 = first generation
swarmPerks    = {},       -- e.g. {foragingBoost=true, extraRouteSlot=true}
```

### B2 — Migration index 8 (v12→v13)

In MIGRATIONS table add:

```lua
[8] = function(profile)
    if profile.generation == nil then
        profile.generation = 0
    end
    if profile.swarmPerks == nil then
        profile.swarmPerks = {}
    end
    return profile
end,
```

### B3 — Version bump

Find the `CURRENT_VERSION` constant and change it from `12` to `13`:

```lua
-- Before:
local CURRENT_VERSION = 12
-- After:
local CURRENT_VERSION = 13
```

### B4 — Verification

Run in Command Bar after the clone-and-replace:

```lua
local ds = game:GetService("ServerScriptService").Systems:FindFirstChild("DataService")
if not ds then return "NOT FOUND" end
local src = ds.Source
local v13      = src:find("CURRENT_VERSION%s*=%s*13") ~= nil or src:find("=%s*13") ~= nil
local hasGen   = src:find('"generation"') ~= nil or src:find("generation%s*=") ~= nil
local hasPerks = src:find("swarmPerks") ~= nil
local hasMig8  = src:find("%[8%]") ~= nil
return "v13=" .. tostring(v13) .. " generation=" .. tostring(hasGen)
    .. " swarmPerks=" .. tostring(hasPerks) .. " mig[8]=" .. tostring(hasMig8)
-- Expected: v13=true generation=true swarmPerks=true mig[8]=true
```

---

## STEP C — Config perk constants

**Edit `ReplicatedStorage.Modules.Config`** using clone-and-replace.

Add this block anywhere after `QUEEN_TIERS`:

```lua
Config.SWARM_PERKS = {
    foragingBoost   = {gen = 1, foragingSpeedMult = 1.15},
    extraRouteSlot  = {gen = 2, bonusRouteSlots   = 1},
    bearCalm        = {gen = 3, bearPatienceMult   = 1.25},
}

-- Swarm prerequisites (mirrors SwarmService constants; kept in Config for client reads)
Config.SWARM_REQ = {
    queenTier = 3,
    minCells  = 15,
    minHoney  = 5000,
}
```

Also find `Config.QUEEN_TIERS` and locate the Sun Queen (T5) entry. It currently has
`genGate = 1` meaning "requires generation ≥ 1". This is already correct — the SwarmService
will clear this gate automatically by incrementing `profile.generation`. No change needed to
QUEEN_TIERS itself; the QueenService's `CanUpgradeQueen` check (from cycle10_queen_dispatch)
already reads `profile.generation >= tier.genGate`. Confirm with:

```lua
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local sunQ = cfg.QUEEN_TIERS and cfg.QUEEN_TIERS[5]
return sunQ and ("T5 genGate=" .. tostring(sunQ.genGate)) or "QUEEN_TIERS[5] not found"
-- Expected: T5 genGate=1
```

---

## STEP D — SwarmService ModuleScript

**Location:** `ServerScriptService.Systems.SwarmService` (new ModuleScript)

```lua
--!strict
-- SwarmService: prestige reset — "The Swarm."
-- Player holds SwarmPerch → departure sequence → reset → perk award.

local SwarmService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local Notify        = Remotes:WaitForChild("Notify")        :: RemoteEvent
local SwarmBegin    = Remotes:WaitForChild("SwarmBegin")    :: RemoteEvent
local SwarmComplete = Remotes:WaitForChild("SwarmComplete") :: RemoteEvent
local RequestSwarm  = Remotes:WaitForChild("RequestSwarm")  :: RemoteEvent

local Systems    = game:GetService("ServerScriptService"):WaitForChild("Systems")
local DataService = require(Systems:WaitForChild("DataService"))
local PlotService = require(Systems:WaitForChild("PlotService"))
local CombService = require(Systems:WaitForChild("CombService"))

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local CARRY_OVER   = 0.20
local SEQ_DURATION = 8

local MIN_QUEEN_TIER = Config.SWARM_REQ and Config.SWARM_REQ.queenTier or 3
local MIN_CELLS      = Config.SWARM_REQ and Config.SWARM_REQ.minCells  or 15
local MIN_HONEY      = Config.SWARM_REQ and Config.SWARM_REQ.minHoney  or 5000

-- Guard against double-trigger
local _swarmLocked: {[number]: boolean} = {}

local function canSwarm(profile: {[string]: any}): (boolean, string)
    local queenTier = (profile.queenTier :: number?) or 0
    if queenTier < MIN_QUEEN_TIER then
        return false, "Queen must be tier " .. MIN_QUEEN_TIER .. "+ (yours is " .. queenTier .. ")"
    end
    local cellCount = 0
    for _ in (profile.cells :: {[string]: any}?) or {} do cellCount += 1 end
    if cellCount < MIN_CELLS then
        return false, "Build " .. MIN_CELLS .. " cells first (" .. cellCount .. "/" .. MIN_CELLS .. ")"
    end
    local honey = (profile.honey :: number?) or 0
    if honey < MIN_HONEY then
        return false, "Bank " .. MIN_HONEY .. " honey first (you have " .. honey .. ")"
    end
    return true, ""
end

-- Determine which perks the player should have after swarming to `newGen`
local function buildPerks(newGen: number): {[string]: boolean}
    local perks: {[string]: boolean} = {}
    if not Config.SWARM_PERKS then return perks end
    for perkKey, data in Config.SWARM_PERKS :: {[string]: {gen: number}} do
        if newGen >= data.gen then
            perks[perkKey] = true
        end
    end
    return perks
end

local function performSwarm(player: Player, plotIndex: number)
    if _swarmLocked[plotIndex] then return end
    _swarmLocked[plotIndex] = true

    local profile = DataService.GetProfile(player)
    if not profile then _swarmLocked[plotIndex] = nil; return end

    local ok, reason = canSwarm(profile)
    if not ok then
        Notify:FireClient(player, "Can't swarm yet: " .. reason)
        _swarmLocked[plotIndex] = nil
        return
    end

    -- Start client sequence
    SwarmBegin:FireClient(player, plotIndex)
    task.wait(SEQ_DURATION)

    -- Carry-over and generation increment
    local currentHoney = (profile.honey :: number?) or 0
    local carryHoney   = math.floor(currentHoney * CARRY_OVER)
    local newGen       = ((profile.generation :: number?) or 0) + 1
    local newPerks     = buildPerks(newGen)

    -- Reset profile — structures (danceFloor/apiarySheds etc.) persist
    profile.honey          = carryHoney
    profile.propolis       = 0
    profile.pollen         = 0
    profile.royalJelly     = 0
    profile.royalJellyProgress = 0
    profile.cells          = {}
    profile.unlockedFloors = {["1"] = true}
    profile.queenTier      = 1
    profile.castes         = {forager = 85, nurse = 0, guard = 10, drone = 5}
    profile.generation     = newGen
    profile.swarmPerks     = newPerks

    -- Save
    pcall(DataService.Save, player)

    -- Wipe comb visuals
    if CombService.WipeAllCells then
        CombService.WipeAllCells(plotIndex)
    end

    -- Social notification
    Notify:FireAllClients(player.Name .. "'s hive has swarmed! Generation " .. newGen .. " begins.")

    -- Personal confirmation with new perk list
    local perkNames: {string} = {}
    for k in newPerks do table.insert(perkNames, k) end
    SwarmComplete:FireClient(player, newGen, carryHoney, perkNames)

    _swarmLocked[plotIndex] = nil
end

RequestSwarm.OnServerEvent:Connect(function(player: Player)
    local plotIndex = PlotService.GetPlotIndex(player)
    if not plotIndex then return end
    task.spawn(performSwarm, player, plotIndex)
end)

function SwarmService.CanSwarm(player: Player): (boolean, string)
    local profile = DataService.GetProfile(player)
    if not profile then return false, "Profile not loaded" end
    return canSwarm(profile)
end

-- Returns the active perk table for a player (safe to call from ForagingService / ThreatService)
function SwarmService.GetPerks(player: Player): {[string]: boolean}
    local profile = DataService.GetProfile(player)
    if not profile then return {} end
    return (profile.swarmPerks :: {[string]: boolean}?) or {}
end

return SwarmService
```

---

## STEP E — CombService.WipeAllCells

**Edit `ServerScriptService.Systems.CombService`** using clone-and-replace.

If `WipeAllCells` is not already present, add before `return CombService`:

```lua
-- Called by SwarmService on prestige reset. Destroys all physical cell parts
-- for a given plot and resets the CombFloors attribute.
function CombService.WipeAllCells(plotIndex: number)
    local plotRoot = PlotService.GetPlotRoot and PlotService.GetPlotRoot(plotIndex)
    if not plotRoot then
        -- Fallback: scan by attribute
        for _, obj in game:GetService("CollectionService"):GetTagged("HexCell") do
            if obj:GetAttribute("PlotIndex") == plotIndex and obj:IsA("BasePart") then
                obj:Destroy()
            end
        end
        return
    end

    -- Preferred: destroy all tagged cells under this plot root
    local CS = game:GetService("CollectionService")
    local toDestroy: {BasePart} = {}
    for _, part in CS:GetTagged("HexCell") do
        if part:GetAttribute("PlotIndex") == plotIndex then
            table.insert(toDestroy, part)
        end
    end
    for _, part in toDestroy do part:Destroy() end

    plotRoot:SetAttribute("CombFloors", 1)

    -- Notify clients so BuildGui floor tabs reset
    local FloorUnlocked = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("FloorUnlocked") :: RemoteEvent?
    if FloorUnlocked then
        FloorUnlocked:FireAllClients(plotIndex, 1)
    end
end
```

**Before editing CombService**, read its source to confirm the cell ownership pattern:

```lua
local src = game:GetService("ServerScriptService").Systems:FindFirstChild("CombService").Source
-- Look for how cells are stored: PlotIndex attribute on HexCell-tagged parts,
-- or children of a per-plot folder (workspace.Plots.Plot1, etc.)
-- Adjust WipeAllCells to match the actual pattern.
return src:sub(1, 800)
```

---

## STEP F — SwarmRunner Script

**Location:** `ServerScriptService.SwarmRunner` (new Script)

```lua
--!strict
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
require(Systems:WaitForChild("SwarmService"))
```

---

## STEP G — SwarmPerchWirer Script

**Location:** `ServerScriptService.SwarmPerchWirer` (new Script)

Wires ProximityPrompts on all SwarmPerch-tagged objects, both existing and future.

```lua
--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RequestSwarm = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestSwarm") :: RemoteEvent

local function wirePerch(perch: Instance)
    local prompt = perch:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.ActionText            = "Swarm"
        prompt.ObjectText            = "SwarmPerch"
        prompt.HoldDuration          = 2.0   -- intentional: irreversible action
        prompt.MaxActivationDistance = 8
        prompt.Parent                = perch
    end
    -- Server-side trigger: player is first argument
    prompt.Triggered:Connect(function(player: Player)
        RequestSwarm:FireServer()
    end)
end

for _, perch in CollectionService:GetTagged("SwarmPerch") do
    wirePerch(perch)
end
CollectionService:GetInstanceAddedSignal("SwarmPerch"):Connect(wirePerch)
```

---

## STEP H — SwarmController LocalScript

**Location:** `StarterPlayer.StarterPlayerScripts.SwarmController` (new LocalScript)

Full departure sequence: beam, camera pull, silence beat, generation + perk reveal.

```lua
--!strict
-- SwarmController: client-side Signature Moment 5 departure sequence.

local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local SwarmBegin    = Remotes:WaitForChild("SwarmBegin")    :: RemoteEvent
local SwarmComplete = Remotes:WaitForChild("SwarmComplete") :: RemoteEvent

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")
local camera      = workspace.CurrentCamera

-- Human-readable perk names shown in the overlay
local PERK_LABELS: {[string]: string} = {
    foragingBoost  = "+15% foraging speed (permanent)",
    extraRouteSlot = "+1 waggle-dance route slot",
    bearCalm       = "Old Molasses is 25% more patient",
}

-- Full-screen overlay for silence beat + reveal text
local function buildOverlay(): Frame
    local sg = Instance.new("ScreenGui")
    sg.Name           = "SwarmOverlay"
    sg.DisplayOrder   = 999
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn   = false
    sg.Parent         = playerGui

    local frame = Instance.new("Frame")
    frame.Name                   = "Blackout"
    frame.Size                   = UDim2.fromScale(1, 1)
    frame.Position               = UDim2.fromScale(0, 0)
    frame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel        = 0
    frame.Parent                 = sg

    local mainLabel = Instance.new("TextLabel")
    mainLabel.Name                   = "MainLabel"
    mainLabel.Size                   = UDim2.fromScale(1, 0.12)
    mainLabel.Position               = UDim2.fromScale(0, 0.44)
    mainLabel.BackgroundTransparency = 1
    mainLabel.TextColor3             = Color3.fromRGB(255, 220, 100)
    mainLabel.TextTransparency       = 1
    mainLabel.Font                   = Enum.Font.GothamBold
    mainLabel.TextScaled             = true
    mainLabel.Text                   = ""
    mainLabel.Parent                 = frame

    local subLabel = Instance.new("TextLabel")
    subLabel.Name                   = "SubLabel"
    subLabel.Size                   = UDim2.fromScale(0.8, 0.08)
    subLabel.Position               = UDim2.fromScale(0.1, 0.57)
    subLabel.BackgroundTransparency = 1
    subLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
    subLabel.TextTransparency       = 1
    subLabel.Font                   = Enum.Font.Gotham
    subLabel.TextScaled             = true
    subLabel.Text                   = ""
    subLabel.Parent                 = frame

    return frame
end

local overlay: Frame? = nil

local function spawnDepartureBeam(plotIndex: number)
    local CS = game:GetService("CollectionService")
    local board: BasePart? = nil
    for _, obj in CS:GetTagged("LandingBoard") do
        if obj:GetAttribute("PlotIndex") == plotIndex and obj:IsA("BasePart") then
            board = obj; break
        end
    end
    if not board then return end

    local boardPos = board.Position

    local skyAnchor = Instance.new("Part")
    skyAnchor.Anchored      = true
    skyAnchor.CanCollide    = false
    skyAnchor.Transparency  = 1
    skyAnchor.CastShadow    = false
    skyAnchor.Size          = Vector3.new(1, 1, 1)
    skyAnchor.Position      = Vector3.new(boardPos.X, 200, boardPos.Z)
    skyAnchor.Parent        = workspace

    local att0 = Instance.new("Attachment"); att0.WorldPosition = boardPos; att0.Parent = board
    local att1 = Instance.new("Attachment"); att1.Parent = skyAnchor

    local beam = Instance.new("Beam")
    beam.Attachment0   = att0
    beam.Attachment1   = att1
    beam.Color         = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 200, 50)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 130)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 160, 255)),
    })
    beam.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.6, 0.2),
        NumberSequenceKeypoint.new(1,   1),
    })
    beam.Width0        = 2.5
    beam.Width1        = 0.5
    beam.LightEmission = 0.8
    beam.LightInfluence= 0.3
    beam.FaceCamera    = true
    beam.Segments      = 20
    beam.Parent        = board

    local pe = Instance.new("ParticleEmitter")
    pe.Parent        = board
    pe.Color         = ColorSequence.new(Color3.fromRGB(255, 210, 60))
    pe.LightEmission = 0.6
    pe.Lifetime      = NumberRange.new(1.5, 3)
    pe.Rate          = 40
    pe.Speed         = NumberRange.new(8, 20)
    pe.SpreadAngle   = Vector2.new(25, 25)
    pe.Size          = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0),
    })
    pe.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1),
    })

    -- Camera pull-back
    local originalCF = camera.CFrame
    local wideCF = CFrame.new(boardPos + Vector3.new(0, 30, -60)) * CFrame.Angles(math.rad(20), 0, 0)
    TweenService:Create(camera, TweenInfo.new(2.5, Enum.EasingStyle.Sine), {CFrame = wideCF}):Play()

    task.delay(7, function()
        pcall(function()
            beam:Destroy(); pe:Destroy(); att0:Destroy(); att1:Destroy(); skyAnchor:Destroy()
            TweenService:Create(camera, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {CFrame = originalCF}):Play()
        end)
    end)
end

local function playSilenceBeat(frame: Frame)
    local main = frame:FindFirstChild("MainLabel") :: TextLabel?
    -- Fade to black
    TweenService:Create(frame, TweenInfo.new(2.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()
    task.delay(3.0, function()
        if main then
            main.Text = "..."
            TweenService:Create(main, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
        end
    end)
    task.delay(5.5, function()
        if main then
            TweenService:Create(main, TweenInfo.new(1.0, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
        end
        TweenService:Create(frame, TweenInfo.new(2.0, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    end)
end

SwarmBegin.OnClientEvent:Connect(function(plotIndex: number)
    if not overlay then overlay = buildOverlay() end
    spawnDepartureBeam(plotIndex)
    task.delay(2, function()
        if overlay then playSilenceBeat(overlay) end
    end)
end)

SwarmComplete.OnClientEvent:Connect(function(generation: number, carryHoney: number, perkKeys: {string})
    task.delay(0.5, function()
        local sg    = playerGui:FindFirstChild("SwarmOverlay")
        local frame = sg and sg:FindFirstChild("Blackout")
        local main  = frame and frame:FindFirstChild("MainLabel") :: TextLabel?
        local sub   = frame and frame:FindFirstChild("SubLabel")  :: TextLabel?

        if main then
            main.Text = "Generation " .. generation
            main.TextTransparency = 1
            TweenService:Create(main, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
        end

        -- Build perk lines
        local perkLines: {string} = {carryHoney .. " honey carried forward"}
        for _, key in perkKeys do
            local label = PERK_LABELS[key] or key
            table.insert(perkLines, "✦ " .. label)
        end

        if sub then
            sub.Text = table.concat(perkLines, "  |  ")
            task.delay(0.5, function()
                sub.TextTransparency = 1
                TweenService:Create(sub, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
            end)
        end

        task.delay(6, function()
            if main then
                TweenService:Create(main, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
            end
            if sub then
                TweenService:Create(sub, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
            end
        end)
    end)
end)
```

---

## STEP I — Perk hooks in ForagingService and ThreatService

These are **lightweight hooks** — single-line changes that apply generation perks at runtime.

### I1 — ForagingService: foragingBoost perk

**Edit `ServerScriptService.Systems.ForagingService`** using clone-and-replace.

Find the section that calculates foraging speed (likely a `tripTime` calculation that already
has weather hooks from cycle10_weather_dispatch). Add a SwarmService lookup:

```lua
-- Find the line that computes tripTime (or foragingSpeed multiplier).
-- It will already have a WeatherService multiplier from cycle10_weather_dispatch.
-- Wrap or extend it:

local Systems      = game:GetService("ServerScriptService").Systems
local SwarmService = require(Systems:WaitForChild("SwarmService"))

-- ... (existing tripTime calculation) ...
-- After applying weather hook, also apply swarm perk:
local perks = SwarmService.GetPerks(player)
if perks.foragingBoost then
    tripTime = tripTime * (1 / 1.15)   -- 15% faster = divide trip time by 1.15
end
```

**Read ForagingService source first** to find the exact variable name for trip duration
before making this edit.

### I2 — ForagingService: extraRouteSlot perk

Find where the maximum simultaneous dance route count is enforced (likely a guard in
DanceService or ForagingService that compares active routes to a constant). Add:

```lua
local maxRoutes = Config.MAX_DANCE_ROUTES or 3
local perks = SwarmService.GetPerks(player)
if perks.extraRouteSlot then maxRoutes = maxRoutes + 1 end
-- (existing guard: if activeRoutes >= maxRoutes then reject end)
```

### I3 — ThreatService: bearCalm perk

**Edit `ServerScriptService.Systems.ThreatService`** using clone-and-replace.

In the patience loop (the `task.wait(BASE_PATIENCE_INTERVAL / ...)` line added by
cycle9_threats_dispatch and modified by cycle10_weather_dispatch), add:

```lua
local SwarmService = require(Systems:WaitForChild("SwarmService"))

-- When checking whether to advance Molasses stage, reduce effective patience
-- only for players WITHOUT the bearCalm perk. Since Molasses is server-global,
-- use the plot owner's perk state:
local plotOwner = PlotService.GetPlotOwner(affectedPlotIndex)
local bearPatienceMult = 1.0
if plotOwner then
    local perks = SwarmService.GetPerks(plotOwner)
    if perks.bearCalm then bearPatienceMult = 1.25 end
end
-- Modify the patience interval:
task.wait(BASE_PATIENCE_INTERVAL * bearPatienceMult / WeatherService.GetMolassesRaidPref())
```

**Note:** Read ThreatService source before editing to confirm the exact variable names
and whether patience is per-plot or global.

---

## STEP J — SwarmPerch world placement

Run in Command Bar to place 6 SwarmPerch objects, one per plot:

```lua
--!strict
local CS = game:GetService("CollectionService")

-- Each SwarmPerch: 2-part pedestal (base + glowing top disc)
-- Positioned at Z=+50 behind the hex lattice back row, slightly elevated
local PLOT_X = {-250, -150, -50, 50, 150, 250}
local BASE_Y = 11.5   -- deck Y (6.5) + offset (5)
local BASE_Z = 50

-- Warm Wax palette
local PROPOLIS_BROWN = Color3.fromRGB(122, 74, 34)
local HONEY_GOLD     = Color3.fromRGB(242, 168, 28)

-- Get or create world folder
local plotsFolder = workspace:FindFirstChild("Plots")
-- If Plots folder doesn't exist, parent to workspace root
local function getParentFolder(i: number): Instance
    if plotsFolder then
        local pf = plotsFolder:FindFirstChild("Plot" .. i)
        return pf or plotsFolder
    end
    return workspace
end

for i, xPos in PLOT_X do
    -- Skip if already placed
    local exists = false
    for _, tagged in CS:GetTagged("SwarmPerch") do
        if tagged:GetAttribute("PlotIndex") == i then exists = true; break end
    end
    if exists then
        print("SwarmPerch PlotIndex=" .. i .. " already exists, skipping")
        continue
    end

    local model = Instance.new("Model")
    model.Name = "SwarmPerch_Plot" .. i

    -- Base cylinder: Propolis Brown pillar
    local base = Instance.new("Part")
    base.Name          = "Base"
    base.Shape         = Enum.PartType.Cylinder
    -- Roblox Cylinder extends along Y-axis; rotate to be vertical (already Y-axis = up for cylinder = height along Y)
    -- Default cylinder Y = height, so Size = Vector3(height, radius*2, radius*2)
    base.Size          = Vector3.new(4, 1.4, 1.4)   -- 4 studs tall, 0.7 radius
    base.CFrame        = CFrame.new(xPos, BASE_Y - 2, BASE_Z) * CFrame.Angles(0, 0, math.rad(90))
    -- ^ rotate 90° so cylinder Y (height axis) aligns with world Y (vertical)
    -- Actually for a vertical cylinder, no rotation is needed if Y is the height axis
    -- Re-check: Roblox Part cylinder: Y-axis = cylinder's long axis
    -- So for a vertical pillar we want Y to point up → no rotation needed
    base.CFrame        = CFrame.new(xPos, BASE_Y - 2, BASE_Z)
    base.Material      = Enum.Material.SmoothPlastic
    base.Color         = PROPOLIS_BROWN
    base.Anchored      = true
    base.CanCollide    = true
    base.Parent        = model

    -- Top disc: Honey Gold glowing plate
    local topDisc = Instance.new("Part")
    topDisc.Name       = "TopDisc"
    topDisc.Shape      = Enum.PartType.Cylinder
    topDisc.Size       = Vector3.new(0.4, 2.0, 2.0)   -- thin disc, 1.0 radius
    topDisc.CFrame     = CFrame.new(xPos, BASE_Y, BASE_Z)
    topDisc.Material   = Enum.Material.Neon
    topDisc.Color      = HONEY_GOLD
    topDisc.Anchored   = true
    topDisc.CanCollide = false
    topDisc.Parent     = model

    model.PrimaryPart = base
    model.Parent      = getParentFolder(i)

    CS:AddTag(model, "SwarmPerch")
    model:SetAttribute("PlotIndex", i)

    print("Placed SwarmPerch PlotIndex=" .. i .. " at (" .. xPos .. ", " .. BASE_Y .. ", " .. BASE_Z .. ")")
end
return "SwarmPerch placement done"
```

---

## STEP K — Verification

Run this full verification script after all steps complete:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local CS  = game:GetService("CollectionService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks: {string} = {}
local issues: {string} = {}

local function pass(msg: string) table.insert(checks, "PASS: " .. msg) end
local function fail(msg: string) table.insert(issues, "FAIL: " .. msg) end

-- A: RemoteEvents
for _, name in {"SwarmBegin", "SwarmComplete", "RequestSwarm"} do
    local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then pass("Remote " .. name)
    else fail("Remote " .. name .. " missing") end
end

-- B: DataService v13
local ds = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("DataService")
if ds then
    local src = ds.Source
    local hasGen   = src:find("generation") ~= nil
    local hasPerks = src:find("swarmPerks") ~= nil
    local hasMig8  = src:find("%[8%]") ~= nil
    if hasGen   then pass("DataService generation field") else fail("DataService missing generation") end
    if hasPerks then pass("DataService swarmPerks field") else fail("DataService missing swarmPerks") end
    if hasMig8  then pass("DataService migration[8]")    else fail("DataService missing migration[8]") end
else
    fail("DataService not found")
end

-- C: Config.SWARM_PERKS
local ok, cfg = pcall(require, RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Config"))
if ok and cfg then
    if cfg.SWARM_PERKS then pass("Config.SWARM_PERKS exists") else fail("Config.SWARM_PERKS missing") end
    if cfg.SWARM_REQ   then pass("Config.SWARM_REQ exists")   else fail("Config.SWARM_REQ missing") end
    local t5 = cfg.QUEEN_TIERS and cfg.QUEEN_TIERS[5]
    if t5 then pass("QUEEN_TIERS[5] (Sun Queen) genGate=" .. tostring(t5.genGate))
    else       fail("QUEEN_TIERS[5] not found") end
else
    fail("Config require failed: " .. tostring(cfg))
end

-- D: SwarmService
local ws = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("SwarmService")
if ws and ws:IsA("ModuleScript") then
    local src = ws.Source
    if src:find("--!strict")  then pass("SwarmService --!strict") else fail("SwarmService missing --!strict") end
    if src:find("canSwarm")   then pass("SwarmService canSwarm")  else fail("SwarmService missing canSwarm") end
    if src:find("buildPerks") then pass("SwarmService buildPerks") else fail("SwarmService missing buildPerks") end
    if src:find("GetPerks")   then pass("SwarmService.GetPerks")  else fail("SwarmService missing GetPerks") end
    if src:find("WipeAllCells") then pass("SwarmService calls WipeAllCells") else fail("SwarmService missing WipeAllCells call") end
else
    fail("SwarmService ModuleScript missing from Systems")
end

-- E: CombService.WipeAllCells
local combS = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService")
if combS and combS.Source:find("WipeAllCells") then pass("CombService.WipeAllCells")
else fail("CombService.WipeAllCells missing") end

-- F: SwarmRunner
local wr = SSS:FindFirstChild("SwarmRunner")
if wr and wr:IsA("Script") then pass("SwarmRunner Script") else fail("SwarmRunner missing") end

-- G: SwarmPerchWirer
local pw = SSS:FindFirstChild("SwarmPerchWirer")
if pw and pw:IsA("Script") then pass("SwarmPerchWirer Script") else fail("SwarmPerchWirer missing") end

-- H: SwarmController
local sc = SPS and SPS:FindFirstChild("SwarmController")
if sc and sc:IsA("LocalScript") then
    local src = sc.Source
    if src:find("TweenService") and src:find("SwarmBegin") and src:find("PERK_LABELS") then
        pass("SwarmController LocalScript (TweenService + SwarmBegin + PERK_LABELS)")
    else
        fail("SwarmController missing symbols")
    end
else
    fail("SwarmController LocalScript missing")
end

-- J: SwarmPerch world objects
local perches = CS:GetTagged("SwarmPerch")
if #perches == 6 then pass("6 SwarmPerch tagged")
else fail("SwarmPerch count=" .. #perches .. " (expected 6)") end
local seen: {[number]: boolean} = {}
for _, p in perches do
    local idx = p:GetAttribute("PlotIndex") :: number?
    if idx then
        if seen[idx] then fail("Duplicate SwarmPerch PlotIndex=" .. idx)
        else seen[idx] = true end
    else
        fail("SwarmPerch missing PlotIndex attribute: " .. p.Name)
    end
end
for i = 1, 6 do
    if not seen[i] then fail("No SwarmPerch for PlotIndex=" .. i) end
end

-- Summary
local out = "=== SWARM SYSTEM — FULL VERIFICATION ===\n"
out = out .. "PASSED: " .. #checks .. " / ISSUES: " .. #issues .. "\n\n"
out = out .. table.concat(checks, "\n") .. "\n"
if #issues > 0 then
    out = out .. "\n--- ISSUES ---\n" .. table.concat(issues, "\n") .. "\n"
else
    out = out .. "\nALL CHECKS PASSED.\n"
end
return out
```

---

## Smoke test (Play mode)

After verification passes, enter Play mode and test with a debug player that meets
the prerequisites. Use the Command Bar injection below to force a player to swarm-ready
state:

```lua
-- Run in Play mode only (server-side Command Bar)
local Players = game:GetService("Players")
local SSS     = game:GetService("ServerScriptService")
local DS      = require(SSS.Systems.DataService)

local player  = Players:GetPlayers()[1]   -- adjust for the correct test player
local profile = DS.GetProfile(player)
if not profile then return "No profile" end

profile.queenTier = 3
profile.honey     = 6000
profile.cells     = {}
for i = 1, 16 do profile.cells[tostring(i)] = {type = "Honey"} end

return "Profile patched for swarm test — approach SwarmPerch and hold 2s"
```

Expected sequence:
- Departure beam column rises from Landing Board (2.5s camera pull)
- Screen fades to black at ~t=2.5s
- "..." appears at ~t=3s
- After 8s: "Generation 1" appears, subtitle shows honey carry + perk
- Server-wide Notify fires in chat
- Profile resets: honey=1200 (20% of 6000), cells={}, queenTier=1, generation=1, swarmPerks={foragingBoost=true}
- Sun Queen (T5) now available in QUEEN tab (genGate satisfied)

---

## Executor notes

1. **HoldDuration = 2.0 on SwarmPerch is intentional.** The swarm is irreversible; a 2-second
   hold prevents accidental triggers. Players will learn this is a "major action" button.

2. **Structures persist through swarm** (danceFloorTier, apiaryShedTier, propolisKilnTier).
   This is the prestige loop's reward: infrastructure stays, comb and queen reset. The player
   rebuilds faster on every generation because their buildings never revert.

3. **generation field is v12→v13, not v4→v5.** cycle6_swarm_dispatch.md was written before
   cycles 8–10 added four more DataService versions. Never run cycle6_swarm_dispatch.md —
   this dispatch supersedes it entirely.

4. **Perk hooks (Step I) require reading source first.** ForagingService and ThreatService
   have been modified by multiple prior dispatches. The exact variable names for tripTime,
   maxRoutes, and the patience interval will differ from the template code above. Read the
   actual source before editing.

5. **SwarmComplete perk list**: The server sends `perkKeys` as a plain string array
   (`{string}`). The client looks up human-readable strings from `PERK_LABELS`. Adding new
   perks to Config.SWARM_PERKS and PERK_LABELS keeps both tiers in sync without server
   restarts.

6. **Sun Queen genGate**: T5 genGate is already set to 1 in cycle10_queen_dispatch. No
   change is needed to Config.QUEEN_TIERS — the QueenService.CanUpgradeQueen check already
   reads `profile.generation >= tier.genGate`. Once a player's generation reaches 1 after
   their first swarm, T5 automatically unlocks in the QUEEN tab.
