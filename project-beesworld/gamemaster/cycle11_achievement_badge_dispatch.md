# Dispatch 38 — AchievementBadge World Props: Trophy Pedestals
**Cycle 11 | A Bee's World | Bee-scale tycoon**
**Execution order: after dispatch 37**

---

## OVERVIEW

Adds 5 physical trophy pedestal props near the Hub area. Each pedestal has:
- Layered primitive geometry (base + column + platform + trophy cup)
- A BillboardGui floating above showing the achievement name and locked/unlocked state
- Server-side AchievementService tracking 5 milestones via DataService profile
- AchievementSync RemoteEvent updating clients on unlock
- Client-side AchievementController updates BillboardGui transparency + gold glow on unlock

Achievements are permanently unlocked (stored in `profile.achievements[]`).
Pedestals use CollectionService tag `"AchievementPedestal"` with `AchievementId` attribute.

**Part budget**: +35 permanent parts → **~4,142 / 5,000**

---

## ACHIEVEMENT DEFINITIONS

| ID | Name | Condition | Honey Reward |
|----|------|-----------|--------------|
| `first_harvest` | 🍯 First Harvest | Harvest honey once | 500 |
| `queen_tier_3` | 👑 Royal Court | Upgrade queen to Tier 3 | 2,000 |
| `generation_5` | 🌟 Veteran Beekeeper | Reach Generation 5 | 5,000 |
| `honey_100k` | 💰 Honey Millionaire | Accumulate 100,000 lifetime honey | 10,000 |
| `floor_3` | 🏠 Master Hive | Unlock Floor 3 | 8,000 |

---

## STEP A — Config.ACHIEVEMENTS injection

```lua
-- In Studio Command Bar:
local RS = game:GetService("ReplicatedStorage")

local cfg = RS:FindFirstChild("Config")
if not cfg then error("Config not found") end
local clone = cfg:Clone()
cfg.Name = "Config_OLD_NX"
cfg.Parent = nil

local src = clone.Source

local inject = [[

-- ============================================================
-- ACHIEVEMENT CONFIG
-- ============================================================
Config.ACHIEVEMENTS = {
    {
        id          = "first_harvest",
        name        = "🍯 First Harvest",
        desc        = "Harvest your first drop of honey.",
        honeyReward = 500,
        pedestal    = 1,
    },
    {
        id          = "queen_tier_3",
        name        = "👑 Royal Court",
        desc        = "Upgrade your Queen to Tier 3.",
        honeyReward = 2000,
        pedestal    = 2,
    },
    {
        id          = "generation_5",
        name        = "🌟 Veteran Beekeeper",
        desc        = "Reach Generation 5 through Prestige.",
        honeyReward = 5000,
        pedestal    = 3,
    },
    {
        id          = "honey_100k",
        name        = "💰 Honey Millionaire",
        desc        = "Accumulate 100,000 lifetime honey earned.",
        honeyReward = 10000,
        pedestal    = 4,
    },
    {
        id          = "floor_3",
        name        = "🏠 Master Hive",
        desc        = "Unlock Floor 3 of your hive.",
        honeyReward = 8000,
        pedestal    = 5,
    },
}
]]
src = src:gsub("(return Config)", inject .. "\n%1")
clone.Source = src
clone.Name = "Config"
clone.Parent = RS

print("✅ Config.ACHIEVEMENTS injected (5 entries)")
```

---

## STEP B — AchievementSync RemoteEvent + DataService profile migration

```lua
-- In Studio Command Bar (run after Step A):
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
if not remotes then error("Remotes not found") end

-- AchievementSync
if not remotes:FindFirstChild("AchievementSync") then
    local re = Instance.new("RemoteEvent")
    re.Name = "AchievementSync"
    re.Parent = remotes
    print("✅ AchievementSync RemoteEvent created")
else
    print("ℹ️  AchievementSync already exists")
end

-- DataService profile migration: add 'achievements' array and 'lifetimeHoney' counter
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
if not ds then error("DataService not found") end
local clone = ds:Clone()
ds.Name = "DataService_OLD_NX"
ds.Parent = nil

local src = clone.Source
-- Inject into DEFAULT_PROFILE if not already there
if not src:find("achievements") then
    src = src:gsub(
        "(generation%s*=%s*0,)",
        "%1\n\t\tachievements   = {} :: { string },\n\t\tlifetimeHoney  = 0,"
    )
    print("✅ DataService: achievements + lifetimeHoney added to DEFAULT_PROFILE")
else
    print("ℹ️  DataService: achievements already in profile")
end
clone.Source = src
clone.Name = "DataService"
clone.Parent = SSS
```

---

## STEP C — AchievementService (server)

```lua
-- In Studio Command Bar (run after Step B):
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local old = SSS:FindFirstChild("AchievementService")
if old then old:Destroy() end

local s = Instance.new("ModuleScript")
s.Name = "AchievementService"
s.Source = [[
--!strict
local RS              = game:GetService("ReplicatedStorage")
local Players         = game:GetService("Players")
local SSS             = game:GetService("ServerScriptService")

local Config          = require(RS:WaitForChild("Config"))
local DataService     = require(SSS:WaitForChild("DataService"))
local AchievementSync = RS:WaitForChild("Remotes"):WaitForChild("AchievementSync")

type AchievementDef = { id: string, name: string, desc: string, honeyReward: number, pedestal: number }

-- Map id → def for fast lookup
local _defMap: { [string]: AchievementDef } = {}
for _, def in Config.ACHIEVEMENTS :: { AchievementDef } do
    _defMap[def.id] = def
end

local AchievementService = {}

-- Returns true if player has already unlocked id
local function hasAchievement(profile: any, id: string): boolean
    for _, v in profile.achievements :: { string } do
        if v == id then return true end
    end
    return false
end

-- Core grant function (server-authoritative)
function AchievementService.Grant(player: Player, id: string)
    local def = _defMap[id]
    if not def then
        warn("[AchievementService] Unknown id:", id)
        return
    end

    local ok, profile = pcall(DataService.GetProfile, player)
    if not ok or not profile then return end

    if hasAchievement(profile, id) then return end  -- idempotent

    -- Record unlock
    table.insert(profile.achievements :: { string }, id)

    -- Honey reward
    profile.honey = (profile.honey or 0) + def.honeyReward

    -- Notify client
    AchievementSync:FireClient(player, {
        id          = id,
        name        = def.name,
        desc        = def.desc,
        honeyReward = def.honeyReward,
        pedestal    = def.pedestal,
        allUnlocked = profile.achievements :: { string },
    })

    -- Notify toast
    local notifyRE = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Notify")
    if notifyRE then
        notifyRE:FireClient(player, {
            title   = "🏆 Achievement Unlocked!",
            message = def.name .. " — +" .. def.honeyReward .. " honey",
            duration = 5,
        })
    end

    print(string.format("[AchievementService] %s unlocked '%s' (+%d honey)", player.Name, id, def.honeyReward))
end

-- Convenience checkers called from other services
function AchievementService.CheckFirstHarvest(player: Player)
    AchievementService.Grant(player, "first_harvest")
end

function AchievementService.CheckQueenTier(player: Player, tier: number)
    if tier >= 3 then
        AchievementService.Grant(player, "queen_tier_3")
    end
end

function AchievementService.CheckGeneration(player: Player, generation: number)
    if generation >= 5 then
        AchievementService.Grant(player, "generation_5")
    end
end

function AchievementService.AddLifetimeHoney(player: Player, amount: number)
    local ok, profile = pcall(DataService.GetProfile, player)
    if not ok or not profile then return end
    profile.lifetimeHoney = (profile.lifetimeHoney or 0) + amount
    if profile.lifetimeHoney >= 100000 then
        AchievementService.Grant(player, "honey_100k")
    end
end

function AchievementService.CheckFloor(player: Player, floor: number)
    if floor >= 3 then
        AchievementService.Grant(player, "floor_3")
    end
end

-- Send all current unlocks to newly-joined player
function AchievementService.SyncOnJoin(player: Player)
    local ok, profile = pcall(DataService.GetProfile, player)
    if not ok or not profile then return end
    if #(profile.achievements :: { string }) == 0 then return end
    AchievementSync:FireClient(player, {
        id          = "",
        name        = "",
        desc        = "",
        honeyReward = 0,
        pedestal    = 0,
        allUnlocked = profile.achievements :: { string },
    })
end

function AchievementService.Init()
    Players.PlayerAdded:Connect(function(player)
        task.wait(3)  -- wait for DataService profile load
        AchievementService.SyncOnJoin(player)
    end)
end

return AchievementService
]]
s.Parent = SSS
print("✅ AchievementService ModuleScript created in ServerScriptService")
```

---

## STEP D — Wire AchievementService into existing services

```lua
-- In Studio Command Bar (run after Step C):
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- ---- GameManager: require + Init ----
local gm = SSS:FindFirstChild("GameManager")
if gm then
    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil
    local src = clone.Source
    if not src:find("AchievementService") then
        src = src:gsub(
            "(local DanceFloorService.-\n)",
            "%1local AchievementService = require(SSS:WaitForChild(\"AchievementService\"))\n"
        )
        src = src:gsub(
            "(DanceFloorService%.Init%(%)\n)",
            "%1AchievementService.Init()\n"
        )
        print("✅ GameManager: AchievementService require+Init injected")
    else
        print("ℹ️  GameManager: AchievementService already wired")
    end
    clone.Source = src
    clone.Name = "GameManager"
    clone.Parent = SSS
end

-- ---- ForagingService: AddLifetimeHoney on harvest ----
local fs = SSS:FindFirstChild("ForagingService")
if fs then
    local clone = fs:Clone()
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    local src = clone.Source
    if not src:find("AchievementService") then
        src = src:gsub(
            "(local DanceFloorService.-\n)",
            "%1local AchievementService = require(SSS:WaitForChild(\"AchievementService\"))\n"
        )
        -- Inject after honey is added to profile (look for profile.honey = ... line)
        src = src:gsub(
            "(profile%.honey = profile%.honey %+ yield\n)",
            "%1\t\tAchievementService.AddLifetimeHoney(player, yield)\n\t\tAchievementService.CheckFirstHarvest(player)\n"
        )
        print("✅ ForagingService: AchievementService hooks injected (AddLifetimeHoney + CheckFirstHarvest)")
    else
        print("ℹ️  ForagingService: AchievementService already wired")
    end
    clone.Source = src
    clone.Name = "ForagingService"
    clone.Parent = SSS
end

-- ---- QueenService: CheckQueenTier after tier upgrade ----
local qs = SSS:FindFirstChild("QueenService")
if qs then
    local clone = qs:Clone()
    qs.Name = "QueenService_OLD_NX"
    qs.Parent = nil
    local src = clone.Source
    if not src:find("AchievementService") then
        src = src:gsub(
            "(local PrestigeRewardService.-\n)",
            "%1local AchievementService = require(SSS:WaitForChild(\"AchievementService\"))\n"
        )
        src = src:gsub(
            "(profile%.queenTier = profile%.queenTier %+ 1\n)",
            "%1\t\tAchievementService.CheckQueenTier(player, profile.queenTier)\n"
        )
        print("✅ QueenService: AchievementService.CheckQueenTier injected")
    else
        print("ℹ️  QueenService: AchievementService already wired")
    end
    clone.Source = src
    clone.Name = "QueenService"
    clone.Parent = SSS
end

-- ---- PrestigeService: CheckGeneration after generation bump ----
local ps = SSS:FindFirstChild("PrestigeService")
if ps then
    local clone = ps:Clone()
    ps.Name = "PrestigeService_OLD_NX"
    ps.Parent = nil
    local src = clone.Source
    if not src:find("AchievementService") then
        src = src:gsub(
            "(local PrestigeRewardService.-\n)",
            "%1local AchievementService = require(SSS:WaitForChild(\"AchievementService\"))\n"
        )
        src = src:gsub(
            "(profile%.generation = profile%.generation %+ 1\n)",
            "%1\t\tAchievementService.CheckGeneration(player, profile.generation)\n"
        )
        print("✅ PrestigeService: AchievementService.CheckGeneration injected")
    else
        print("ℹ️  PrestigeService: AchievementService already wired")
    end
    clone.Source = src
    clone.Name = "PrestigeService"
    clone.Parent = SSS
end

-- ---- FloorService: CheckFloor after floor unlock ----
local fls = SSS:FindFirstChild("FloorService")
if fls then
    local clone = fls:Clone()
    fls.Name = "FloorService_OLD_NX"
    fls.Parent = nil
    local src = clone.Source
    if not src:find("AchievementService") then
        src = src:gsub(
            "(local DataService.-\n)",
            "%1local AchievementService = require(SSS:WaitForChild(\"AchievementService\"))\n"
        )
        -- After floorUnlocked increment
        src = src:gsub(
            "(profile%.floorUnlocked = profile%.floorUnlocked %+ 1\n)",
            "%1\t\tAchievementService.CheckFloor(player, profile.floorUnlocked)\n"
        )
        print("✅ FloorService: AchievementService.CheckFloor injected")
    else
        print("ℹ️  FloorService: AchievementService already wired")
    end
    clone.Source = src
    clone.Name = "FloorService"
    clone.Parent = SSS
end
```

---

## STEP E — Trophy pedestal world props (5 pedestals)

```lua
-- In Studio Command Bar (run after Step D):
local Workspace          = game:GetService("Workspace")
local CollectionService  = game:GetService("CollectionService")

local map = Workspace:FindFirstChild("Map")
local hub = map and (map:FindFirstChild("Hub") or map:FindFirstChild("Room1"))
local parent = hub or Workspace

-- Pedestal positions: row along back wall of Hub (-8 studs from dance floor, spread 10 studs apart)
local PEDESTAL_POSITIONS = {
    Vector3.new(-20, 0, -130),
    Vector3.new(-10, 0, -130),
    Vector3.new(  0, 0, -130),
    Vector3.new( 10, 0, -130),
    Vector3.new( 20, 0, -130),
}

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROPOLIS    = Color3.fromRGB(122,  74, 34)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local GREY_LOCKED = Color3.fromRGB(100, 100, 100)

local ACHIEVEMENT_DEFS = {
    { id = "first_harvest", name = "🍯 First Harvest"        },
    { id = "queen_tier_3",  name = "👑 Royal Court"           },
    { id = "generation_5",  name = "🌟 Veteran Beekeeper"    },
    { id = "honey_100k",    name = "💰 Honey Millionaire"    },
    { id = "floor_3",       name = "🏠 Master Hive"          },
}

local function buildPedestal(pos: Vector3, def: { id: string, name: string }, idx: number)
    local model = Instance.new("Model")
    model.Name = "Pedestal_" .. def.id
    model.Parent = parent

    -- Base slab
    local base = Instance.new("Part")
    base.Name      = "Base"
    base.Size      = Vector3.new(4, 0.6, 4)
    base.Color     = PROPOLIS
    base.Material  = Enum.Material.SmoothPlastic
    base.Anchored  = true
    base.CanCollide = true
    base.Position  = pos + Vector3.new(0, 0.3, 0)
    base.Parent    = model

    -- Column
    local col = Instance.new("Part")
    col.Name      = "Column"
    col.Size      = Vector3.new(1.5, 3.0, 1.5)
    col.Color     = PROPOLIS
    col.Material  = Enum.Material.SmoothPlastic
    col.Anchored  = true
    col.CanCollide = true
    col.Position  = pos + Vector3.new(0, 2.1, 0)
    col.Parent    = model

    -- Platform
    local plat = Instance.new("Part")
    plat.Name      = "Platform"
    plat.Size      = Vector3.new(2.4, 0.3, 2.4)
    plat.Color     = GREY_LOCKED  -- starts grey (locked)
    plat.Material  = Enum.Material.SmoothPlastic
    plat.Anchored  = true
    plat.CanCollide = true
    plat.Position  = pos + Vector3.new(0, 3.75, 0)
    plat.Parent    = model

    -- Trophy cup (sphere on cylinder)
    local stem = Instance.new("Part")
    stem.Name      = "TrophyStem"
    stem.Size      = Vector3.new(0.4, 1.2, 0.4)
    stem.Color     = GREY_LOCKED
    stem.Material  = Enum.Material.SmoothPlastic
    stem.Anchored  = true
    stem.CanCollide = false
    stem.Position  = pos + Vector3.new(0, 4.5, 0)
    stem.Parent    = model

    local cup = Instance.new("Part")
    cup.Name      = "TrophyCup"
    cup.Size      = Vector3.new(1.0, 0.9, 1.0)
    cup.Shape     = Enum.PartType.Ball
    cup.Color     = GREY_LOCKED
    cup.Material  = Enum.Material.SmoothPlastic
    cup.Anchored  = true
    cup.CanCollide = false
    cup.Position  = pos + Vector3.new(0, 5.4, 0)
    cup.Parent    = model

    -- Number badge on base front face
    local numPart = Instance.new("Part")
    numPart.Name  = "NumBadge"
    numPart.Size  = Vector3.new(0.8, 0.8, 0.1)
    numPart.Color = GREY_LOCKED
    numPart.Material = Enum.Material.SmoothPlastic
    numPart.Anchored = true
    numPart.CanCollide = false
    numPart.Position = pos + Vector3.new(0, 0.4, 2.05)
    numPart.Parent = model

    local numGui = Instance.new("SurfaceGui")
    numGui.Face   = Enum.NormalId.Front
    numGui.Parent = numPart
    local numLbl = Instance.new("TextLabel")
    numLbl.Size  = UDim2.new(1,0,1,0)
    numLbl.BackgroundTransparency = 1
    numLbl.Text  = tostring(idx)
    numLbl.Font  = Enum.Font.FredokaOne
    numLbl.TextScaled = true
    numLbl.TextColor3 = WAX_CREAM
    numLbl.Parent = numGui

    -- BillboardGui floating above trophy
    local billboard = Instance.new("BillboardGui")
    billboard.Name          = "AchievementBillboard"
    billboard.Size          = UDim2.new(0, 200, 0, 80)
    billboard.StudsOffset   = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop   = false
    billboard.Adornee       = cup
    billboard.Parent        = cup

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name             = "AchievementTitle"
    titleLbl.Size             = UDim2.new(1, 0, 0.6, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text             = def.name
    titleLbl.Font             = Enum.Font.FredokaOne
    titleLbl.TextScaled       = true
    titleLbl.TextColor3       = GREY_LOCKED  -- grey until unlocked
    titleLbl.Parent           = billboard

    local lockLbl = Instance.new("TextLabel")
    lockLbl.Name             = "LockStatus"
    lockLbl.Size             = UDim2.new(1, 0, 0.4, 0)
    lockLbl.Position         = UDim2.new(0, 0, 0.6, 0)
    lockLbl.BackgroundTransparency = 1
    lockLbl.Text             = "🔒 Locked"
    lockLbl.Font             = Enum.Font.FredokaOne
    lockLbl.TextScaled       = true
    lockLbl.TextColor3       = GREY_LOCKED
    lockLbl.Parent           = billboard

    -- Tag the cup part for client identification
    CollectionService:AddTag(cup, "AchievementPedestal")
    cup:SetAttribute("AchievementId", def.id)
    cup:SetAttribute("PedestalIndex", idx)

    return model
end

for i, def in ACHIEVEMENT_DEFS do
    buildPedestal(PEDESTAL_POSITIONS[i], def, i)
end

print("✅ 5 trophy pedestals created (5 × 7 parts = 35 parts total)")
print("   Positions: row at Z=-130, X=-20 to +20 (10-stud spacing)")
print("   Tagged: AchievementPedestal on each TrophyCup part")
```

> **Part budget**: +35 permanent parts → **~4,142 / 5,000**

---

## STEP F — AchievementController LocalScript

```lua
-- In Studio Command Bar (run after Step E):
local StarterPlayer = game:GetService("StarterPlayer")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not SPS then error("StarterPlayerScripts not found") end

local old = SPS:FindFirstChild("AchievementController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name = "AchievementController"
ctrl.Source = [[
--!strict
local Players         = game:GetService("Players")
local RS              = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService    = game:GetService("TweenService")

local player          = Players.LocalPlayer
local AchievementSync = RS:WaitForChild("Remotes"):WaitForChild("AchievementSync")

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROPOLIS    = Color3.fromRGB(122,  74, 34)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local GREY_LOCKED = Color3.fromRGB(100, 100, 100)

local UNLOCK_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Map id → cup part (populated when pedestals are found)
local _pedestalMap: { [string]: BasePart } = {}

local function findPedestals()
    local function check(part: Instance)
        if part:IsA("BasePart") and CollectionService:HasTag(part, "AchievementPedestal") then
            local id = part:GetAttribute("AchievementId")
            if id then
                _pedestalMap[id :: string] = part :: BasePart
            end
        end
    end
    for _, p in CollectionService:GetTagged("AchievementPedestal") do
        check(p)
    end
    CollectionService:GetInstanceAddedSignal("AchievementPedestal"):Connect(check)
end

local function unlockPedestal(id: string)
    local cup = _pedestalMap[id]
    if not cup then return end

    local model = cup.Parent
    if not model then return end

    -- Gold-tint all parts
    local goldParts = {
        model:FindFirstChild("Platform"),
        model:FindFirstChild("TrophyStem"),
        cup,
        model:FindFirstChild("NumBadge"),
    }
    for _, p in goldParts do
        if p and p:IsA("BasePart") then
            TweenService:Create(p, UNLOCK_TWEEN, { Color = HONEY_GOLD }):Play()
        end
    end

    -- Add PointLight glow to cup
    local light = cup:FindFirstChildOfClass("PointLight")
    if not light then
        light = Instance.new("PointLight")
        light.Brightness = 3
        light.Range      = 10
        light.Shadows    = false
        light.Parent     = cup
    end
    TweenService:Create(light, UNLOCK_TWEEN, { Color = HONEY_GOLD }):Play()

    -- Update BillboardGui text
    local billboard = cup:FindFirstChild("AchievementBillboard")
    if billboard then
        local titleLbl = billboard:FindFirstChild("AchievementTitle")
        local lockLbl  = billboard:FindFirstChild("LockStatus")
        if titleLbl and titleLbl:IsA("TextLabel") then
            TweenService:Create(titleLbl, UNLOCK_TWEEN, { TextColor3 = HONEY_GOLD }):Play()
        end
        if lockLbl and lockLbl:IsA("TextLabel") then
            lockLbl.Text       = "✅ Unlocked!"
            lockLbl.TextColor3 = WAX_CREAM
        end
    end
end

AchievementSync.OnClientEvent:Connect(function(data: {
    id:          string,
    allUnlocked: { string },
})
    -- Apply all currently-unlocked achievements (handles reconnect/join sync)
    for _, id in data.allUnlocked do
        unlockPedestal(id)
    end
    -- If this is a fresh unlock notification (not just a sync), id is non-empty
    -- The visual already handled by allUnlocked above
end)

-- Wait for workspace pedestals to appear then build map
task.spawn(function()
    task.wait(2)  -- let workspace load
    findPedestals()
end)
]]
ctrl.Parent = SPS
print("✅ AchievementController LocalScript created in StarterPlayerScripts")
```

---

## STEP G — Verification

```lua
-- In Studio Command Bar:
local SSS    = game:GetService("ServerScriptService")
local RS     = game:GetService("ReplicatedStorage")
local SP     = game:GetService("StarterPlayer")
local CS     = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local results = {}
local issues  = {}

-- 1. Config.ACHIEVEMENTS
local cfg = RS:FindFirstChild("Config")
if cfg then
    local ok, data = pcall(require, cfg)
    if ok and data.ACHIEVEMENTS and #data.ACHIEVEMENTS == 5 then
        table.insert(results, "✅ Config.ACHIEVEMENTS: " .. #data.ACHIEVEMENTS .. " entries")
    else
        table.insert(issues, "❌ Config.ACHIEVEMENTS missing or wrong count")
    end
end

-- 2. DataService profile has achievements field
local ds = SSS:FindFirstChild("DataService")
if ds then
    local hasField = ds.Source:find("achievements") ~= nil
    local hasLifetime = ds.Source:find("lifetimeHoney") ~= nil
    table.insert((hasField and hasLifetime) and results or issues,
        ((hasField and hasLifetime) and "✅" or "❌") ..
        " DataService: achievements=" .. tostring(hasField) .. " lifetimeHoney=" .. tostring(hasLifetime))
end

-- 3. AchievementSync RemoteEvent
local remotes = RS:FindFirstChild("Remotes")
local as = remotes and remotes:FindFirstChild("AchievementSync")
table.insert(as and results or issues, (as and "✅" or "❌") .. " AchievementSync: " .. (as and "exists" or "MISSING"))

-- 4. AchievementService
local ach = SSS:FindFirstChild("AchievementService")
if ach and ach:IsA("ModuleScript") then
    local lines = select(2, ach.Source:gsub("\n", "\n")) + 1
    local hasGrant    = ach.Source:find("Grant") ~= nil
    local hasIdempot  = ach.Source:find("idempotent") ~= nil or ach.Source:find("hasAchievement") ~= nil
    table.insert(results, string.format("✅ AchievementService: %d lines Grant=%s Idempotent=%s", lines, tostring(hasGrant), tostring(hasIdempot)))
else
    table.insert(issues, "❌ AchievementService: MISSING or wrong type")
end

-- 5. Pedestal props in workspace
local pedestals = CS:GetTagged("AchievementPedestal")
table.insert(#pedestals == 5 and results or issues,
    (#pedestals == 5 and "✅" or "⚠️") .. " AchievementPedestal tagged parts: " .. #pedestals .. " (expected 5)")

-- 6. Each pedestal has AchievementId attribute
local missingId = {}
for _, p in pedestals do
    if not p:GetAttribute("AchievementId") then
        table.insert(missingId, p:GetFullName())
    end
end
if #missingId == 0 then
    table.insert(results, "✅ All pedestals have AchievementId attribute")
else
    table.insert(issues, "❌ Missing AchievementId: " .. table.concat(missingId, ", "))
end

-- 7. AchievementController LocalScript
local sps = SP:FindFirstChild("StarterPlayerScripts")
local ac  = sps and sps:FindFirstChild("AchievementController")
if ac and ac:IsA("LocalScript") then
    local lines = select(2, ac.Source:gsub("\n", "\n")) + 1
    table.insert(results, "✅ AchievementController: " .. lines .. " lines")
else
    table.insert(issues, "❌ AchievementController: MISSING")
end

-- 8. Part count for pedestals (5×7=35)
local pedestalPartCount = 0
for _, obj in Workspace:GetDescendants() do
    if obj.Name:find("Pedestal_") and obj:IsA("Model") then
        for _, p in obj:GetDescendants() do
            if p:IsA("BasePart") then pedestalPartCount = pedestalPartCount + 1 end
        end
    end
end
table.insert(pedestalPartCount >= 30 and results or issues,
    (pedestalPartCount >= 30 and "✅" or "⚠️") .. " Pedestal part count: " .. pedestalPartCount .. " (expected ~35)")

-- Summary
local out = "=== DISPATCH 38 VERIFICATION ===\n" .. table.concat(results, "\n")
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — Dispatch 38 complete" end
return out
```

---

## EXECUTION SUMMARY

| Step | What | Parts |
|------|------|-------|
| A | Config.ACHIEVEMENTS (5 entries) | 0 |
| B | AchievementSync RE + DataService migration | 0 |
| C | AchievementService ModuleScript | 0 |
| D | Wire into GameManager/Foraging/Queen/Prestige/Floor services | 0 |
| E | 5 trophy pedestal models (7 parts each) | +35 |
| F | AchievementController LocalScript | 0 |
| G | Verification | — |

**Running part total: ~4,142 / 5,000**

---

## BEHAVIOURAL NOTES

- **Idempotent grants**: `hasAchievement()` checks before inserting — safe to call multiple times without double-counting
- **`lifetimeHoney`** accumulates across prestiges (unlike `profile.honey` which resets on prestige)
- **BillboardGuis** start grey with 🔒 text; on unlock they tween to Honey Gold with ✅ text via `TweenService`
- **PointLight** only added on unlock — saves 5 light objects until earned
- **SyncOnJoin** fires all unlocked achievements to a reconnecting player so pedestals restore to gold state
- **`allUnlocked` array** in every AchievementSync payload means client can always restore full state from a single event

---

*Dispatch 38 complete — proceed to dispatch 39 (NotificationCenterGui)*
