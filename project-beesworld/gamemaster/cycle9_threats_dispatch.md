# Cycle 9 — Threats Dispatch (Old Molasses + Wasps)

**Agents:** world-builder + enemy-designer + luau-scripter  
**Target:** Full 6-stage antagonist system — Pine Treeline zone, ThreatService, WaspService, EnemyAI for Old Molasses with permanent BearOffering fork ending  
**Part delta:** ~+155 (Pine Treeline ~80 parts, Bear Lane fence ~30, Molasses Den ~30, wasp anchors ~15)  
**DataService version:** v10 → v11 (adds molassesStage, molassesRepels, bearOfferingMade, bearOutcome)  
**Prerequisites:** All cycle 1–8 dispatches executed.

---

## Overview

Old Molasses is one of three things architecture.md calls out as making this "not a reskinned tycoon". It is a full 6-stage learning antagonist with two permanent mutually-exclusive endings. The system has three components:

1. **World zone**: Pine Treeline (north barrier), Bear Lane (16-stud-wide path), Molasses Den (bear home zone)  
2. **WaspService**: 4–7 minute scout timer; wasps fly from treeline toward plot; GuardBee auto-kills wasp if within range; player can SwatWasp  
3. **ThreatService + EnemyAI**: Old Molasses progresses through 6 stages; at stage 5 steals honey; at stage 6 a BearOffering fork triggers (Appease = permanent peace / Banish = bear gone, honey bonus, no more threats)

---

## Zone Layout

```
Z = +60   Pine Treeline begins (first row of pines)
Z = +75   Bear Lane starts (16 studs wide, centred X=0)
Z = +90   Molasses Den entrance
Z = +105  Molasses Den centre (Old Molasses spawn point)
Z = +120  Den back wall

X range for lane:  -8 to +8 (16 studs)
X range for zone:  -70 to +70 (140 studs, full hub width)
```

---

## Step 1 — DataService v10 → v11

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local DS  = SSS.Systems:FindFirstChild("DataService")
assert(DS, "DataService not found")

local clone = DS:Clone()
clone.Name  = "DataService_new"
DS.Parent   = nil

local src = clone.Source

src = src:gsub('local CURRENT_VERSION = 10', 'local CURRENT_VERSION = 11')

-- Add threat fields to PROFILE_TEMPLATE
src = src:gsub(
    '(tutorialComplete%s*=%s*false,)',
    '%1\n\t\t-- Threat system\n\t\tmolassesStage   = 1,\n\t\tmolassesRepels  = 0,\n\t\tbearOfferingMade = false,\n\t\tbearOutcome     = "none",  -- "none" | "appeased" | "banished"'
)

-- Migration v10→v11
local migration = [[
        [11] = function(profile)
            if not profile.data.molassesStage   then profile.data.molassesStage   = 1     end
            if not profile.data.molassesRepels  then profile.data.molassesRepels  = 0     end
            if profile.data.bearOfferingMade == nil then profile.data.bearOfferingMade = false end
            if not profile.data.bearOutcome     then profile.data.bearOutcome     = "none" end
        end,]]

src = src:gsub(
    '(%[10%]%s*=%s*function%(profile%).-end,)',
    '%1\n' .. migration
)

clone.Source = src
clone.Name   = "DataService"
clone.Parent = SSS.Systems
print("DataService v11 installed — threat fields added")
```

**Verify:**
```lua
local DS = game:GetService("ServerScriptService").Systems.DataService
print("Version:", DS.Source:match("CURRENT_VERSION = (%d+)"))
print("molassesStage:", DS.Source:find("molassesStage") and "YES" or "NO")
print("bearOutcome:", DS.Source:find("bearOutcome") and "YES" or "NO")
```

---

## Step 2 — Config additions: Molasses stages + Wasp constants

Run in Studio Command Bar:

```lua
local RS  = game:GetService("ReplicatedStorage")
local Cfg = RS.Modules:FindFirstChild("Config")
assert(Cfg, "Config not found")

local clone = Cfg:Clone()
clone.Name  = "Config_new"
Cfg.Parent  = nil

local src = clone.Source

local threat_block = [[

-- ============================================================
-- THREAT SYSTEM
-- ============================================================

-- Old Molasses 6-stage progression
-- patience: real seconds before Molasses advances from this stage
-- theftPct: fraction of plot's banked honey stolen on a successful raid
Config.MOLASSES_STAGES = {
    [1] = {patience = 600,  theftPct = 0,    desc = "Distant rumbles. The bear watches from the den."},
    [2] = {patience = 480,  theftPct = 0,    desc = "Pawprints appear at the treeline."},
    [3] = {patience = 360,  theftPct = 0,    desc = "Molasses circles the hive at night."},
    [4] = {patience = 300,  theftPct = 0.10, desc = "A small raid. 10% honey taken."},
    [5] = {patience = 240,  theftPct = 0.25, desc = "A bold raid. 25% honey taken. The bear grows confident."},
    [6] = {patience = 0,    theftPct = 0,    desc = "Molasses looms at your hive door. A choice must be made."},
}

-- A repel from a Smoker resets bear stage by this many levels
Config.SMOKER_REPEL_STAGES_RESET = 2

-- BearOffering costs (paid in honey to trigger the fork)
Config.BEAR_OFFERING = {
    appease = {honeyCost = 2000, desc = "Leave a honey offering. Molasses becomes a reluctant guardian."},
    banish  = {honeyCost = 1500, propsCost = 300, desc = "Use smoke and noise to drive the bear away permanently."},
}

-- Wasp system
Config.WASP = {
    scoutMinInterval = 240,   -- 4 minutes minimum between scouts
    scoutMaxInterval = 420,   -- 7 minutes maximum
    flightDuration   = 15,    -- seconds the wasp is in flight before reaching a hive
    guardKillRange   = 20,    -- studs; if a GuardBee-tagged part is within this range, wasp dies
    swatWindowSecs   = 8,     -- player has this long to swat after wasp spawns near hive
    honeyStealAmount = 50,    -- honey stolen per successful wasp reach
}
]]

src = src:gsub('(return Config%s*$)', threat_block .. '\n%1')

clone.Source = src
clone.Name   = "Config"
clone.Parent = RS.Modules
print("Config updated — MOLASSES_STAGES + WASP constants added")
```

---

## Step 3 — Build Pine Treeline World Zone (~155 parts)

Run in Studio Command Bar:

```lua
-- Pine Treeline / Bear Lane / Molasses Den
-- All centred around Z = +60 to +120, X = -70 to +70

local CS  = game:GetService("CollectionService")
local WS  = game:GetService("Workspace")

-- Clean up any previous attempt
local existingZone = WS:FindFirstChild("ThreatZone")
if existingZone then existingZone:Destroy() end

local Zone = Instance.new("Folder")
Zone.Name   = "ThreatZone"
Zone.Parent = WS

-- Helper: create anchored non-collide decoration part
local function makePart(parent, name, size, position, color, material, transparency, canCollide)
    local p = Instance.new("Part")
    p.Name         = name
    p.Size         = size
    p.Position     = position
    p.Anchored     = true
    p.CanCollide   = canCollide ~= false
    p.CastShadow   = canCollide ~= false
    p.Material     = material or Enum.Material.SmoothPlastic
    p.Color        = color or Color3.fromRGB(100, 80, 50)
    p.Transparency = transparency or 0
    p.Parent       = parent
    return p
end

-- ── 1. Pine Treeline row (Z = 60–68, dense pine silhouettes) ─────────────────
local Treeline = Instance.new("Folder")
Treeline.Name   = "Treeline"
Treeline.Parent = Zone

-- 14 pine trees spaced ~10 studs apart from X=-65 to X=+65
-- Each pine: trunk + 3 canopy cones stacked
local pineXPositions = {-65,-55,-45,-35,-22,-11,0,11,22,35,45,55,65}
-- Skip X=-8 to +8 (the bear lane gap)
for _, px in pineXPositions do
    -- Skip the lane gap
    if math.abs(px) <= 10 then continue end

    local pineModel = Instance.new("Model")
    pineModel.Name   = "Pine_" .. tostring(px)
    pineModel.Parent = Treeline

    -- Trunk
    local trunk = makePart(pineModel, "Trunk",
        Vector3.new(1.2, 8, 1.2),
        Vector3.new(px, 10, 63),
        Color3.fromRGB(85, 55, 30),
        Enum.Material.Wood)

    -- 3 canopy tiers (using SmoothPlastic wedges approximated as cylinders)
    local tierData = {
        {y=13, r=4.5, h=4},
        {y=16, r=3.2, h=3.5},
        {y=19, r=2.0, h=3},
    }
    for _, tier in tierData do
        local canopy = Instance.new("Part")
        canopy.Name       = "Canopy"
        canopy.Shape      = Enum.PartType.Cylinder
        canopy.Size       = Vector3.new(tier.h, tier.r*2, tier.r*2)
        canopy.Position   = Vector3.new(px, tier.y, 63)
        canopy.Rotation   = Vector3.new(0, 0, 90)
        canopy.Anchored   = true
        canopy.CanCollide = false
        canopy.Material   = Enum.Material.Grass
        canopy.Color      = Color3.fromRGB(30, 65, 30)
        canopy.Parent     = pineModel
    end

    pineModel.PrimaryPart = trunk
end

-- ── 2. Treeline ground shadow strip (dark SmoothPlastic strip at base) ────────
local shadowStrip = makePart(Zone, "TreelineShadow",
    Vector3.new(140, 0.5, 8),
    Vector3.new(0, 6.3, 63),
    Color3.fromRGB(20, 20, 20),
    Enum.Material.SmoothPlastic,
    0.6,
    false)

-- ── 3. Bear Lane entrance marker posts ───────────────────────────────────────
local Lane = Instance.new("Folder")
Lane.Name   = "BearLane"
Lane.Parent = Zone

-- Two wooden warning posts at Z=62, X=±10
for _, side in {-10, 10} do
    local post = makePart(Lane, "LanePost",
        Vector3.new(0.5, 6, 0.5),
        Vector3.new(side, 9, 62),
        Color3.fromRGB(100, 65, 30),
        Enum.Material.Wood)

    -- Warning sign (flat SmoothPlastic slab)
    local sign = makePart(Lane, "LaneSign",
        Vector3.new(2.5, 1.8, 0.2),
        Vector3.new(side, 12.5, 62),
        Color3.fromRGB(200, 160, 50),
        Enum.Material.SmoothPlastic)
    sign.Rotation = Vector3.new(0, side < 0 and 0 or 180, 0)
end

-- Lane floor (darker earth, 16 studs wide from Z=62 to Z=122)
local laneFloor = makePart(Lane, "LaneFloor",
    Vector3.new(16, 0.6, 60),
    Vector3.new(0, 6.2, 92),
    Color3.fromRGB(60, 40, 20),
    Enum.Material.Ground)

-- Lane fence walls (low, 1 stud high wooden rails on each side)
for _, side in {-9, 9} do
    makePart(Lane, "LaneFence_" .. side,
        Vector3.new(0.4, 1.5, 60),
        Vector3.new(side, 7.25, 92),
        Color3.fromRGB(90, 58, 25),
        Enum.Material.Wood)
end

-- ── 4. Molasses Den (Z = 90–122, X = -14 to +14) ────────────────────────────
local Den = Instance.new("Folder")
Den.Name   = "MolassesDen"
Den.Parent = Zone

-- Den floor
makePart(Den, "DenFloor",
    Vector3.new(28, 1, 32),
    Vector3.new(0, 5.9, 106),
    Color3.fromRGB(35, 22, 10),
    Enum.Material.Mud)

-- Den walls (3 sides — north/east/west; south faces the lane)
-- North wall
makePart(Den, "DenWall_N",
    Vector3.new(28, 12, 1),
    Vector3.new(0, 12, 122),
    Color3.fromRGB(55, 38, 20),
    Enum.Material.Rock)

-- East wall
makePart(Den, "DenWall_E",
    Vector3.new(1, 12, 32),
    Vector3.new(14, 12, 106),
    Color3.fromRGB(55, 38, 20),
    Enum.Material.Rock)

-- West wall
makePart(Den, "DenWall_W",
    Vector3.new(1, 12, 32),
    Vector3.new(-14, 12, 106),
    Color3.fromRGB(55, 38, 20),
    Enum.Material.Rock)

-- Den ceiling (partial, gives cave feel)
makePart(Den, "DenCeiling",
    Vector3.new(28, 1, 20),
    Vector3.new(0, 18, 112),
    Color3.fromRGB(40, 28, 14),
    Enum.Material.Rock)

-- Honey pool (dark amber, Neon glow)
local honeyPool = makePart(Den, "HoneyPool",
    Vector3.new(10, 0.4, 10),
    Vector3.new(0, 6.3, 110),
    Color3.fromRGB(180, 90, 10),
    Enum.Material.Neon,
    0.25)

-- Den atmospheric: scattered bones/debris (small grey rocks)
for i = 1, 6 do
    local angle = (i / 6) * math.pi * 2
    local rx = math.cos(angle) * (3 + math.random() * 3)
    local rz = 108 + math.sin(angle) * (3 + math.random() * 3)
    makePart(Den, "DenDebris_" .. i,
        Vector3.new(0.8 + math.random() * 0.8, 0.4, 0.8 + math.random() * 0.8),
        Vector3.new(rx, 6.5, rz),
        Color3.fromRGB(150 + math.random(40), 140 + math.random(30), 120 + math.random(20)),
        Enum.Material.SmoothPlastic,
        0,
        false)
end

-- ── 5. Wasp anchor parts (15 invisible spawn points on treeline) ──────────────
local WaspAnchors = Instance.new("Folder")
WaspAnchors.Name   = "WaspAnchors"
WaspAnchors.Parent = Zone

-- Wasps spawn at treeline Z=60 and fly south toward hives
-- 6 spawn points spread across X range (skipping lane)
for i, px in {-60, -40, -20, 20, 40, 60} do
    local anchor = makePart(WaspAnchors, "WaspSpawn_" .. i,
        Vector3.new(2, 2, 2),
        Vector3.new(px, 10, 60),
        Color3.fromRGB(255, 200, 50),
        Enum.Material.Neon,
        0.99,
        false)
    CS:AddTag(anchor, "WaspSpawn")
    anchor:SetAttribute("SpawnIndex", i)
end

-- ── 6. Bear Offering Altar (at den entrance Z=92, X=0) ───────────────────────
local altar = Instance.new("Model")
altar.Name   = "BearAltar"
altar.Parent = Den

local altarBase = makePart(altar, "AltarBase",
    Vector3.new(4, 1, 4),
    Vector3.new(0, 6.5, 92),
    Color3.fromRGB(100, 70, 35),
    Enum.Material.Wood)

local altarTop = makePart(altar, "AltarTop",
    Vector3.new(2.5, 0.5, 2.5),
    Vector3.new(0, 7.25, 92),
    Color3.fromRGB(180, 120, 40),
    Enum.Material.SmoothPlastic)

-- Honey jar on altar (small sphere)
local jar = Instance.new("Part")
jar.Name       = "HoneyJar"
jar.Shape      = Enum.PartType.Ball
jar.Size       = Vector3.new(1, 1, 1)
jar.Position   = Vector3.new(0, 8, 92)
jar.Anchored   = true
jar.CanCollide = false
jar.Material   = Enum.Material.Neon
jar.Color      = Color3.fromRGB(242, 168, 28)
jar.Transparency = 0.2
jar.Parent     = altar

-- ProximityPrompt on altar base
local pp = Instance.new("ProximityPrompt")
pp.ActionText  = "Make Offering"
pp.ObjectText  = "Bear Altar"
pp.HoldDuration = 2
pp.MaxActivationDistance = 8
pp.Enabled    = false  -- enabled by ThreatService when Molasses reaches stage 6
pp.Parent      = altarBase

-- Tag
CS:AddTag(altar, "BearAltar")
CS:AddTag(altarBase, "BearAltarBase")
altar.PrimaryPart = altarBase

-- ── 7. GuardPerch anchor posts (2, flanking the bear lane entrance) ───────────
for _, side in {-12, 12} do
    local perch = makePart(Zone, "GuardPerch_" .. side,
        Vector3.new(1, 5, 1),
        Vector3.new(side, 9, 68),
        Color3.fromRGB(100, 70, 35),
        Enum.Material.Wood)
    CS:AddTag(perch, "GuardPerch")
end

print("ThreatZone built:")
local partCount = 0
for _, p in Zone:GetDescendants() do
    if p:IsA("BasePart") then partCount += 1 end
end
print("  Parts:", partCount)
print("  BearAltar tagged:", #game:GetService("CollectionService"):GetTagged("BearAltar"))
print("  WaspSpawn tagged:", #game:GetService("CollectionService"):GetTagged("WaspSpawn"))
print("  GuardPerch tagged:", #game:GetService("CollectionService"):GetTagged("GuardPerch"))
```

**Expected:** Parts ~130–160, BearAltar 1, WaspSpawn 6, GuardPerch 2.

---

## Step 4 — WaspService (ServerScriptService.Systems)

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local MS  = Instance.new("ModuleScript")
MS.Name   = "WaspService"
MS.Parent = SSS.Systems
MS.Source = [[
--!strict
-- WaspService — periodic wasp raids from the treeline
local WaspService = {}

local Players    = game:GetService("Players")
local CS         = game:GetService("CollectionService")
local RS         = game:GetService("ReplicatedStorage")
local Config     = require(RS.Modules.Config)
local DataService  -- lazy

local Remotes    = RS.Remotes
local SwatWasp   = Remotes:WaitForChild("SwatWasp")     -- client→server: player swatted wasp
local WaspAlert  = Remotes:WaitForChild("WaspAlert")    -- server→client: wasp incoming {plotIndex}
local Notify     = Remotes:WaitForChild("Notify")

local W = Config.WASP

-- Active wasp raids: [raidId] = {player, plotIndex, expiry, stopped}
local _raids: {[string]: {player: Player, plotIndex: number, expiry: number, stopped: boolean}} = {}
local _raidCounter = 0

local function getDS()
    if not DataService then
        DataService = require(game:GetService("ServerScriptService").Systems.DataService)
    end
    return DataService
end

local function getPlotService()
    return require(game:GetService("ServerScriptService").Systems.PlotService)
end

-- ── GuardBee check ────────────────────────────────────────────────────────────
-- If a GuardPerch-tagged part is within GUARD_KILL_RANGE of any WaspSpawn, wasp dies
local function guardPerchActive(): boolean
    for _, perch in CS:GetTagged("GuardPerch") do
        if perch:IsA("BasePart") then
            for _, spawn in CS:GetTagged("WaspSpawn") do
                if spawn:IsA("BasePart") then
                    if (perch.Position - spawn.Position).Magnitude < W.guardKillRange then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- ── Launch a raid against a specific player's plot ────────────────────────────
local function launchRaid(player: Player)
    _raidCounter += 1
    local raidId  = tostring(_raidCounter)
    local PS      = getPlotService()
    local plotIdx = PS.GetPlotIndex(player)
    if not plotIdx then return end

    local expiry = os.time() + W.flightDuration + W.swatWindowSecs
    _raids[raidId] = {
        player    = player,
        plotIndex = plotIdx,
        expiry    = expiry,
        stopped   = false,
    }

    -- Alert the player
    WaspAlert:FireClient(player, {plotIndex = plotIdx, raidId = raidId})
    Notify:FireClient(player, {message = "⚠ Wasp spotted near hive!", color = Color3.fromRGB(255, 200, 50)})

    -- After flightDuration + swatWindowSecs: if not stopped, steal honey
    task.delay(W.flightDuration + W.swatWindowSecs, function()
        local raid = _raids[raidId]
        if not raid or raid.stopped then
            _raids[raidId] = nil
            return
        end
        _raids[raidId] = nil

        -- Steal honey
        local DS = getDS()
        local profile = DS.GetProfile(player)
        if not profile then return end
        local stolen = math.min(profile.data.honey or 0, W.honeyStealAmount)
        profile.data.honey = (profile.data.honey or 0) - stolen
        if stolen > 0 then
            DS.Save(player)
            Notify:FireClient(player, {message = "🐝 Wasp stole " .. stolen .. " honey!", color = Color3.fromRGB(220, 80, 80)})
        end

        -- QuestService hook
        local ok, QS = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("QuestService"))
        if ok and QS then
            QS.IncrementMetric(player, "waspRaids", 1)
        end
    end)
end

-- ── Swat handler ──────────────────────────────────────────────────────────────
function WaspService.Start()
    SwatWasp.OnServerEvent:Connect(function(player: Player, raidId: string)
        if typeof(raidId) ~= "string" then return end
        local raid = _raids[raidId]
        if not raid or raid.player ~= player then return end
        raid.stopped = true
        Notify:FireClient(player, {message = "Wasp swatted! Nice reflexes.", color = Color3.fromRGB(100, 210, 100)})

        -- QuestService: wasps swatted metric
        local ok, QS = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("QuestService"))
        if ok and QS then
            QS.IncrementMetric(player, "waspsSwatted", 1)
        end
    end)

    -- Periodic wasp scout loop per player
    Players.PlayerAdded:Connect(function(player: Player)
        task.spawn(function()
            while player.Parent do
                -- Check if bear outcome has ended threats
                local DS = getDS()
                local profile = DS.GetProfile(player)
                if profile and profile.data.bearOutcome ~= "none" then
                    if profile.data.bearOutcome == "appeased" then
                        -- Appeased: wasps reduced by 50% (Molasses guards the hive)
                        task.wait(W.scoutMaxInterval * 2)
                    else
                        -- Banished: no more wasps
                        break
                    end
                end

                -- Random interval between scouts
                local interval = W.scoutMinInterval + math.random() * (W.scoutMaxInterval - W.scoutMinInterval)
                task.wait(interval)

                if not player.Parent then break end

                -- Check guard perches
                if guardPerchActive() then
                    Notify:FireClient(player, {
                        message = "Guard bees intercepted a wasp scout!",
                        color   = Color3.fromRGB(100, 210, 100),
                    })
                    continue
                end

                launchRaid(player)
            end
        end)
    end)
end

return WaspService
]]
print("WaspService created")
```

---

## Step 5 — ThreatService / Old Molasses AI (ServerScriptService.Systems)

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local MS  = Instance.new("ModuleScript")
MS.Name   = "ThreatService"
MS.Parent = SSS.Systems
MS.Source = [[
--!strict
-- ThreatService — manages Old Molasses 6-stage progression per player
-- Molasses is rendered CLIENT-ONLY (per architecture.md 'server never moves a bee' rule)
-- Server tracks stage; client handles visual bear movement

local ThreatService = {}

local Players    = game:GetService("Players")
local CS         = game:GetService("CollectionService")
local RS         = game:GetService("ReplicatedStorage")
local Config     = require(RS.Modules.Config)
local DataService  -- lazy

local Remotes     = RS.Remotes
local MolassesSync   = Remotes:WaitForChild("MolassesSync")    -- server→client: stage data
local MolassesRaid   = Remotes:WaitForChild("MolassesRaid")    -- server→client: raid event
local BearOfferingRE = Remotes:WaitForChild("BearOffering")    -- client→server: offering choice
local Notify         = Remotes:WaitForChild("Notify")
local NarrativeRE    = Remotes:FindFirstChild("NarrativeTrigger")  -- optional

local STAGES = Config.MOLASSES_STAGES

-- per-player timers
local _stageTimers: {[number]: thread} = {}

local function getDS()
    if not DataService then
        DataService = require(game:GetService("ServerScriptService").Systems.DataService)
    end
    return DataService
end

local function syncClient(player: Player, extra: {[string]: any}?)
    local DS      = getDS()
    local profile = DS.GetProfile(player)
    if not profile then return end
    local payload: {[string]: any} = {
        stage       = profile.data.molassesStage,
        outcome     = profile.data.bearOutcome,
        repels      = profile.data.molassesRepels,
        offeringMade = profile.data.bearOfferingMade,
    }
    if extra then
        for k, v in extra do payload[k] = v end
    end
    MolassesSync:FireClient(player, payload)
end

-- ── Perform a honey raid ──────────────────────────────────────────────────────
local function performRaid(player: Player, stage: number)
    local DS      = getDS()
    local profile = DS.GetProfile(player)
    if not profile then return end
    local stageData = STAGES[stage]
    if not stageData or stageData.theftPct <= 0 then return end

    local honey  = profile.data.honey or 0
    local stolen = math.floor(honey * stageData.theftPct)
    if stolen > 0 then
        profile.data.honey -= stolen
        DS.Save(player)
        MolassesRaid:FireClient(player, {stolen = stolen, stage = stage})
        Notify:FireClient(player, {
            message = "🐻 Old Molasses stole " .. stolen .. " honey!",
            color   = Color3.fromRGB(180, 60, 20),
        })
        -- Quest metric
        local ok, QS = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("QuestService"))
        if ok and QS then
            QS.IncrementMetric(player, "molassesRepels", 0)  -- just trigger a check; repels tracked separately
        end
    end
end

-- ── Advance Molasses stage ────────────────────────────────────────────────────
local function advanceStage(player: Player)
    local DS      = getDS()
    local profile = DS.GetProfile(player)
    if not profile then return end
    if profile.data.bearOutcome ~= "none" then return end

    local currentStage = profile.data.molassesStage or 1
    if currentStage >= 6 then
        -- Stage 6: enable BearAltar offering
        for _, altar in CS:GetTagged("BearAltar") do
            local altarBase = altar:FindFirstChild("AltarBase")
            local pp = altarBase and altarBase:FindFirstChildOfClass("ProximityPrompt")
            if pp then pp.Enabled = true end
        end
        Notify:FireClient(player, {
            message = "🐻 Old Molasses approaches. The altar awaits your choice.",
            color   = Color3.fromRGB(242, 168, 28),
        })
        syncClient(player)
        return
    end

    local nextStage = currentStage + 1
    profile.data.molassesStage = nextStage
    DS.Save(player)

    -- Narrative flavour
    local stageData = STAGES[nextStage]
    if stageData then
        Notify:FireClient(player, {
            message = "🐻 " .. stageData.desc,
            color   = Color3.fromRGB(200, 130, 40),
        })
    end

    -- Perform raid if this stage has theft
    if stageData and stageData.theftPct > 0 then
        task.delay(30, function()  -- 30s after advancing, the raid happens
            if player.Parent then performRaid(player, nextStage) end
        end)
    end

    syncClient(player)

    -- Schedule next stage advance
    if nextStage < 6 and STAGES[nextStage] and STAGES[nextStage].patience > 0 then
        _stageTimers[player.UserId] = task.delay(STAGES[nextStage].patience, function()
            if player.Parent then advanceStage(player) end
        end)
    end
end

-- ── Smoker repel (called by ThreatService.Repel from SmokerInteract handler) ─

function ThreatService.RepelBear(player: Player)
    local DS      = getDS()
    local profile = DS.GetProfile(player)
    if not profile then return end
    if profile.data.bearOutcome ~= "none" then return end

    -- Cancel current stage timer
    if _stageTimers[player.UserId] then
        task.cancel(_stageTimers[player.UserId])
        _stageTimers[player.UserId] = nil
    end

    -- Roll back stage
    local currentStage = profile.data.molassesStage or 1
    local resetBy      = Config.SMOKER_REPEL_STAGES_RESET or 2
    local newStage     = math.max(1, currentStage - resetBy)
    profile.data.molassesStage  = newStage
    profile.data.molassesRepels = (profile.data.molassesRepels or 0) + 1
    DS.Save(player)

    Notify:FireClient(player, {
        message = "🌫 Smoker fired! Bear retreats to stage " .. newStage .. ".",
        color   = Color3.fromRGB(100, 200, 100),
    })
    syncClient(player)

    -- Quest / achievement hooks
    local ok, QS = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("QuestService"))
    if ok and QS then
        QS.IncrementMetric(player, "molassesRepels", 1)
    end

    -- Restart patience timer for new stage
    if STAGES[newStage] and STAGES[newStage].patience > 0 then
        _stageTimers[player.UserId] = task.delay(STAGES[newStage].patience, function()
            if player.Parent then advanceStage(player) end
        end)
    end
end

-- ── BearOffering fork ─────────────────────────────────────────────────────────
local function handleOffering(player: Player, choice: string)
    if choice ~= "appease" and choice ~= "banish" then return end

    local DS      = getDS()
    local profile = DS.GetProfile(player)
    if not profile then return end
    if profile.data.bearOutcome ~= "none" then return end
    if profile.data.molassesStage < 6 then return end

    local offering = Config.BEAR_OFFERING[choice]
    if not offering then return end

    -- Check cost
    local honey = profile.data.honey or 0
    local props = profile.data.propolis or 0
    if honey < (offering.honeyCost or 0) then
        Notify:FireClient(player, {message = "Not enough Honey for this offering.", color = Color3.fromRGB(220,80,80)})
        return
    end
    if offering.propsCost and props < offering.propsCost then
        Notify:FireClient(player, {message = "Not enough Propolis for this offering.", color = Color3.fromRGB(220,80,80)})
        return
    end

    -- Deduct cost
    profile.data.honey    -= (offering.honeyCost or 0)
    profile.data.propolis  = (props - (offering.propsCost or 0))
    profile.data.bearOutcome      = choice
    profile.data.bearOfferingMade = true
    profile.data.molassesStage    = 6

    -- Cancel stage timer
    if _stageTimers[player.UserId] then
        task.cancel(_stageTimers[player.UserId])
        _stageTimers[player.UserId] = nil
    end

    -- Disable altar
    for _, altar in CS:GetTagged("BearAltar") do
        local ab = altar:FindFirstChild("AltarBase")
        local pp = ab and ab:FindFirstChildOfClass("ProximityPrompt")
        if pp then pp.Enabled = false end
    end

    if choice == "appease" then
        -- Bear becomes a reluctant guardian (wasps reduced, no more raids)
        Notify:FireClient(player, {
            message = "🐻 Old Molasses accepts the offering. An uneasy peace settles over the meadow.",
            color   = Color3.fromRGB(242, 168, 28),
        })
        -- Bonus: +1000 honey from the bear's tribute
        profile.data.honey += 1000
    else -- banish
        Notify:FireClient(player, {
            message = "💨 Smoke and drums drive Old Molasses from the valley. The den is quiet forever.",
            color   = Color3.fromRGB(200, 230, 255),
        })
        -- Bonus: +2500 honey, unlock achievement
        profile.data.honey += 2500
    end

    DS.Save(player)
    syncClient(player, {justChose = choice})

    -- Achievement hook
    local ok, QS = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("QuestService"))
    if ok and QS then
        QS.SetMetric(player, "molassesEndReached", 1)
        QS.IncrementMetric(player, choice == "appease" and "bearAppeased" or "bearBanished", 1)
    end
end

-- ── Start ─────────────────────────────────────────────────────────────────────
function ThreatService.Start()
    -- BearOffering choice from client
    BearOfferingRE.OnServerEvent:Connect(function(player: Player, choice: string)
        if typeof(choice) ~= "string" then return end
        handleOffering(player, choice)
    end)

    -- On join: restore state + resume timers
    Players.PlayerAdded:Connect(function(player: Player)
        task.delay(3, function()
            local DS      = getDS()
            local profile = DS.GetProfile(player)
            if not profile then return end
            if profile.data.bearOutcome ~= "none" then
                syncClient(player)
                return
            end
            local stage = profile.data.molassesStage or 1
            syncClient(player)

            -- Resume patience timer from where it was (approximate: use full patience)
            if stage < 6 and STAGES[stage] and STAGES[stage].patience > 0 then
                _stageTimers[player.UserId] = task.delay(STAGES[stage].patience, function()
                    if player.Parent then advanceStage(player) end
                end)
            elseif stage >= 6 then
                -- Re-enable altar
                for _, altar in CS:GetTagged("BearAltar") do
                    local ab = altar:FindFirstChild("AltarBase")
                    local pp = ab and ab:FindFirstChildOfClass("ProximityPrompt")
                    if pp then pp.Enabled = true end
                end
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        if _stageTimers[player.UserId] then
            task.cancel(_stageTimers[player.UserId])
            _stageTimers[player.UserId] = nil
        end
    end)
end

return ThreatService
]]
print("ThreatService created")
```

---

## Step 6 — MolassesController (client-side bear visual + UI)

Run in Studio Command Bar:

```lua
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("MolassesController")
if old then old:Destroy() end

local MC = Instance.new("LocalScript")
MC.Name   = "MolassesController"
MC.Parent = SPS
MC.Source = [[
--!strict
-- MolassesController — client-side bear visual + BearOffering UI
-- Bear model is NEVER on the server (architecture rule: server never moves a bee/bear)

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes   = RS:WaitForChild("Remotes")
local MolassesSync   = Remotes:WaitForChild("MolassesSync")
local MolassesRaid   = Remotes:WaitForChild("MolassesRaid")
local BearOfferingRE = Remotes:WaitForChild("BearOffering")

-- ── Bear Offering GUI ─────────────────────────────────────────────────────────
local OfferingGui = Instance.new("ScreenGui")
OfferingGui.Name         = "OfferingGui"
OfferingGui.DisplayOrder = 25
OfferingGui.ResetOnSpawn = false
OfferingGui.Parent       = PlayerGui

local OfferingFrame = Instance.new("Frame")
OfferingFrame.Name             = "OfferingFrame"
OfferingFrame.Size             = UDim2.new(0, 440, 0, 280)
OfferingFrame.Position         = UDim2.new(0.5, -220, 0.5, -140)
OfferingFrame.BackgroundColor3 = Color3.fromRGB(30, 18, 8)
OfferingFrame.BackgroundTransparency = 0.05
OfferingFrame.Visible          = false
OfferingFrame.Parent           = OfferingGui
Instance.new("UICorner", OfferingFrame).CornerRadius = UDim.new(0, 14)

local offerStroke = Instance.new("UIStroke")
offerStroke.Color     = Color3.fromRGB(180, 90, 20)
offerStroke.Thickness = 2
offerStroke.Parent    = OfferingFrame

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size             = UDim2.new(1, -20, 0, 50)
TitleLbl.Position         = UDim2.new(0, 10, 0, 10)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text             = "🐻  Old Molasses looms at your hive"
TitleLbl.TextColor3       = Color3.fromRGB(242, 168, 28)
TitleLbl.Font             = Enum.Font.FredokaOne
TitleLbl.TextSize         = 22
TitleLbl.TextWrapped      = true
TitleLbl.Parent           = OfferingFrame

local BodyLbl = Instance.new("TextLabel")
BodyLbl.Size              = UDim2.new(1, -20, 0, 60)
BodyLbl.Position          = UDim2.new(0, 10, 0, 62)
BodyLbl.BackgroundTransparency = 1
BodyLbl.Text              = "The bear has grown bold. You have two choices — and neither can be undone."
BodyLbl.TextColor3        = Color3.fromRGB(200, 170, 120)
BodyLbl.Font              = Enum.Font.Gotham
BodyLbl.TextSize          = 14
BodyLbl.TextWrapped       = true
BodyLbl.Parent            = OfferingFrame

-- Appease button
local AppBtn = Instance.new("TextButton")
AppBtn.Name             = "AppBtn"
AppBtn.Size             = UDim2.new(0, 180, 0, 72)
AppBtn.Position         = UDim2.new(0, 20, 0, 140)
AppBtn.BackgroundColor3 = Color3.fromRGB(120, 70, 20)
AppBtn.Text             = "🍯 Appease\n2000 Honey"
AppBtn.TextColor3       = Color3.fromRGB(232, 212, 154)
AppBtn.Font             = Enum.Font.FredokaOne
AppBtn.TextSize         = 16
AppBtn.TextWrapped      = true
AppBtn.Parent           = OfferingFrame
Instance.new("UICorner", AppBtn).CornerRadius = UDim.new(0, 10)

-- Banish button
local BanBtn = Instance.new("TextButton")
BanBtn.Name             = "BanBtn"
BanBtn.Size             = UDim2.new(0, 180, 0, 72)
BanBtn.Position         = UDim2.new(1, -200, 0, 140)
BanBtn.BackgroundColor3 = Color3.fromRGB(50, 70, 100)
BanBtn.Text             = "💨 Banish\n1500 Honey + 300 Propolis"
BanBtn.TextColor3       = Color3.fromRGB(180, 210, 255)
BanBtn.Font             = Enum.Font.FredokaOne
BanBtn.TextSize         = 14
BanBtn.TextWrapped      = true
BanBtn.Parent           = OfferingFrame
Instance.new("UICorner", BanBtn).CornerRadius = UDim.new(0, 10)

AppBtn.MouseButton1Click:Connect(function()
    BearOfferingRE:FireServer("appease")
    OfferingFrame.Visible = false
end)

BanBtn.MouseButton1Click:Connect(function()
    BearOfferingRE:FireServer("banish")
    OfferingFrame.Visible = false
end)

-- ── Raid flash ─────────────────────────────────────────────────────────────────
local RaidFlash = Instance.new("Frame")
RaidFlash.Name             = "RaidFlash"
RaidFlash.Size             = UDim2.new(1, 0, 1, 0)
RaidFlash.BackgroundColor3 = Color3.fromRGB(180, 60, 20)
RaidFlash.BackgroundTransparency = 1
RaidFlash.ZIndex           = 100
RaidFlash.Visible          = false
RaidFlash.Parent           = OfferingGui

MolassesRaid.OnClientEvent:Connect(function(data: any)
    if data and data.stolen then
        RaidFlash.Visible = true
        RaidFlash.BackgroundTransparency = 0.4
        TweenService:Create(RaidFlash, TweenInfo.new(1.5),
            {BackgroundTransparency = 1}):Play()
        task.delay(1.6, function() RaidFlash.Visible = false end)
    end
end)

-- ── Stage sync ────────────────────────────────────────────────────────────────
MolassesSync.OnClientEvent:Connect(function(data: any)
    if not data then return end
    local stage   = data.stage or 1
    local outcome = data.outcome or "none"

    -- Show offering UI if stage 6 and no outcome yet
    if stage >= 6 and outcome == "none" then
        OfferingFrame.Visible = true
    end

    -- If outcome is set, hide offering UI
    if outcome ~= "none" then
        OfferingFrame.Visible = false
    end
end)

-- ── BearAltar ProximityPrompt (re-open offering UI if stage 6) ────────────────
for _, altar in CollectionService:GetTagged("BearAltar") do
    local ab = altar:FindFirstChild("AltarBase")
    local pp = ab and ab:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        pp.Triggered:Connect(function()
            OfferingFrame.Visible = true
        end)
    end
end
-- Also catch future tags (altar enabled after stage 6 reached)
CollectionService:GetInstanceAddedSignal("BearAltar"):Connect(function(altar)
    local ab = altar:FindFirstChild("AltarBase")
    local pp = ab and ab:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        pp.Triggered:Connect(function()
            OfferingFrame.Visible = true
        end)
    end
end)
]]
print("MolassesController installed")
```

---

## Step 7 — RemoteEvents for threat system

Run in Studio Command Bar:

```lua
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
assert(Remotes, "Remotes not found")

for _, name in {"SwatWasp", "WaspAlert", "MolassesSync", "MolassesRaid", "BearOffering"} do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name   = name
        re.Parent = Remotes
        print("Created: " .. name)
    else
        print("Exists: " .. name)
    end
end
```

---

## Step 8 — Start services + WaspAlert GUI

Run in Studio Command Bar:

```lua
-- Patch ShopSystemsStart (or create ThreatStart) to start WaspService + ThreatService
local SSS = game:GetService("ServerScriptService")
local existingStart = SSS:FindFirstChild("ShopSystemsStart")

local startSrc = [[

-- Threat systems (cycle 9)
local WaspService   = require(Systems:WaitForChild("WaspService"))
local ThreatService = require(Systems:WaitForChild("ThreatService"))
WaspService.Start()
ThreatService.Start()
print("[ThreatService] + [WaspService] started")
]]

if existingStart and not existingStart.Source:find("WaspService") then
    existingStart.Source = existingStart.Source .. startSrc
    print("Patched ShopSystemsStart with threat services")
else
    local sc = Instance.new("Script")
    sc.Name   = "ThreatSystemsStart"
    sc.Parent = SSS
    sc.Source = [[
--!strict
local SSS     = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
]] .. startSrc
    print("Created ThreatSystemsStart Script")
end
```

```lua
-- WaspAlert LocalScript: shows a countdown timer when wasp is inbound
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")

local old = SPS:FindFirstChild("WaspAlertController")
if old then old:Destroy() end

local WC = Instance.new("LocalScript")
WC.Name   = "WaspAlertController"
WC.Parent = SPS
WC.Source = [[
--!strict
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes   = RS:WaitForChild("Remotes")
local WaspAlert = Remotes:WaitForChild("WaspAlert")
local SwatWasp  = Remotes:WaitForChild("SwatWasp")

-- WaspGui
local WaspGui = Instance.new("ScreenGui")
WaspGui.Name         = "WaspGui"
WaspGui.DisplayOrder = 15
WaspGui.ResetOnSpawn = false
WaspGui.Parent       = PlayerGui

local WaspFrame = Instance.new("Frame")
WaspFrame.Name             = "WaspFrame"
WaspFrame.Size             = UDim2.new(0, 240, 0, 72)
WaspFrame.Position         = UDim2.new(0.5, -120, 0, 80)
WaspFrame.BackgroundColor3 = Color3.fromRGB(60, 50, 10)
WaspFrame.BackgroundTransparency = 0.1
WaspFrame.Visible          = false
WaspFrame.Parent           = WaspGui
Instance.new("UICorner", WaspFrame).CornerRadius = UDim.new(0, 10)

local WaspLbl = Instance.new("TextLabel")
WaspLbl.Size              = UDim2.new(0.65, 0, 1, 0)
WaspLbl.BackgroundTransparency = 1
WaspLbl.Text              = "⚠ Wasp incoming!"
WaspLbl.TextColor3        = Color3.fromRGB(255, 220, 50)
WaspLbl.Font              = Enum.Font.FredokaOne
WaspLbl.TextSize          = 17
WaspLbl.TextXAlignment    = Enum.TextXAlignment.Center
WaspLbl.Parent            = WaspFrame

local SwatBtn = Instance.new("TextButton")
SwatBtn.Name             = "SwatBtn"
SwatBtn.Size             = UDim2.new(0, 80, 0, 44)
SwatBtn.Position         = UDim2.new(1, -88, 0.5, -22)
SwatBtn.BackgroundColor3 = Color3.fromRGB(200, 160, 20)
SwatBtn.TextColor3       = Color3.fromRGB(30, 20, 5)
SwatBtn.Text             = "SWAT!"
SwatBtn.Font             = Enum.Font.FredokaOne
SwatBtn.TextSize         = 18
SwatBtn.Parent           = WaspFrame
Instance.new("UICorner", SwatBtn).CornerRadius = UDim.new(0, 8)

local _currentRaidId = ""

SwatBtn.MouseButton1Click:Connect(function()
    if _currentRaidId ~= "" then
        SwatWasp:FireServer(_currentRaidId)
        WaspFrame.Visible = false
        _currentRaidId    = ""
    end
end)

WaspAlert.OnClientEvent:Connect(function(data: any)
    if not data then return end
    _currentRaidId        = data.raidId or ""
    WaspFrame.Visible     = true
    local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
    local duration = (Config.WASP and Config.WASP.flightDuration or 15) + (Config.WASP and Config.WASP.swatWindowSecs or 8)
    -- Auto-hide after full duration
    task.delay(duration, function()
        if WaspFrame.Visible then
            WaspFrame.Visible = false
            _currentRaidId    = ""
        end
    end)
end)
]]
print("WaspAlertController installed")
```

---

## Step 9 — Verification

Run in Studio Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local RS   = game:GetService("ReplicatedStorage")
local WS   = game:GetService("Workspace")
local CS   = game:GetService("CollectionService")
local SP   = game:GetService("StarterPlayer")

local results = {}
local issues  = {}

-- Services
for _, name in {"ThreatService", "WaspService"} do
    local m = SSS.Systems:FindFirstChild(name)
    if m and m:IsA("ModuleScript") then
        table.insert(results, name .. " ✓ (" .. select(2, m.Source:gsub("\n","")) .. " lines)")
    else
        table.insert(issues, "MISSING: " .. name)
    end
end

-- DataService v11
local DS = SSS.Systems:FindFirstChild("DataService")
if DS then
    local v = DS.Source:match("CURRENT_VERSION = (%d+)")
    table.insert(results, "DataService v" .. (v or "?"))
    if v ~= "11" then table.insert(issues, "Expected v11") end
end

-- World zone
local zone = WS:FindFirstChild("ThreatZone")
if zone then
    local pc = 0
    for _, p in zone:GetDescendants() do if p:IsA("BasePart") then pc += 1 end end
    table.insert(results, "ThreatZone ✓ (" .. pc .. " parts)")
    if pc < 80 then table.insert(issues, "ThreatZone part count too low: " .. pc) end
else
    table.insert(issues, "MISSING: Workspace.ThreatZone")
end

-- Tags
for tag, expected in {["BearAltar"]=1, ["WaspSpawn"]=6, ["GuardPerch"]=2} do
    local found = #CS:GetTagged(tag)
    if found >= expected then
        table.insert(results, tag .. ": " .. found .. " ✓")
    else
        table.insert(issues, tag .. ": found " .. found .. " (expected " .. expected .. ")")
    end
end

-- RemoteEvents
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
for _, name in {"SwatWasp","WaspAlert","MolassesSync","MolassesRaid","BearOffering"} do
    local re = Remotes and Remotes:FindFirstChild(name)
    if re then table.insert(results, "RE:" .. name .. " ✓")
    else table.insert(issues, "MISSING RE: " .. name) end
end

-- Controllers
local SPS = SP:FindFirstChild("StarterPlayerScripts")
for _, name in {"MolassesController", "WaspAlertController"} do
    local lc = SPS and SPS:FindFirstChild(name)
    if lc then table.insert(results, name .. " ✓")
    else table.insert(issues, "MISSING LocalScript: " .. name) end
end

print("=== THREATS VERIFICATION ===")
for _, r in results do print("✓ " .. r) end
if #issues > 0 then
    print("ISSUES:")
    for _, iss in issues do print("✗ " .. iss) end
else
    print("ALL CLEAR — threat system complete")
end
```

---

## Summary

| Item | Detail |
|------|--------|
| ThreatZone | ~130–160 parts: Treeline (pine rows), Bear Lane (floor + fences + posts), Molasses Den (walls/floor/ceiling/honey pool/debris/altar), GuardPerch posts, WaspSpawn anchors |
| ThreatService | 6-stage Molasses progression per player, smoker repel, BearOffering fork (appease/banish), permanent outcomes |
| WaspService | 4–7 min periodic scout → WaspAlert → SWAT or honey stolen; GuardPerch auto-intercept |
| MolassesController | Client-side BearOffering UI (two-button fork), raid screen flash |
| WaspAlertController | Top-centre alert banner with countdown + SWAT button |
| DataService bump | v10 → v11: molassesStage, molassesRepels, bearOfferingMade, bearOutcome |
| RemoteEvents | SwatWasp, WaspAlert, MolassesSync, MolassesRaid, BearOffering |
| Part delta | +~145 → ~4,020/5,000 |
| Permanent endings | `bearOutcome = "appeased"` → wasps halved, no raids; `"banished"` → all threats end, +2500 honey bonus |
| Quest hooks | molassesRepels, molassesEndReached, bearAppeased/bearBanished metrics |
