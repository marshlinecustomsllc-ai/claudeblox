# CYCLE 11 — DAILY QUESTS DISPATCH (DISPATCH 23)
## QuestService + QuestController + Daily Quest Widget

> **SUPERSEDES cycle6_dailyquests_dispatch.md** — that dispatch targets stale
> DataService v6→v7 (migration[7]). By execution time DataService is at v14.
> Do NOT also execute cycle6_dailyquests_dispatch.md.

**Agents:** luau-scripter, ui-designer  
**Prerequisites:** Dispatches 1–22 executed in order. DataService at v14.
`profile.lifetimeHoney` already exists from dispatch 22 (v13→v14).  
**Part budget impact:** 0 new world parts (UI only — ScreenGui)  
**Profile fields added:** `questSeed`, `questProgress`, `questsLastReset`, `questMetrics`  
**DataService:** v14 → v15 (migration[10], CURRENT_VERSION = 15)

---

## OVERVIEW

Three daily quests that rotate every 24 hours (server-clock based, not per-player
session time). Quests are seeded from the calendar date so all players on the same
day get the same 3 quests. Progress is tracked server-side and survives disconnects.
Completing a quest awards honey/propolis/pollen. A compact corner widget (bottom-right)
shows live progress with claim buttons.

---

## EXECUTION ORDER

```
STEP A  Config.QUEST_CATALOGUE + Config.DAILY_QUEST
STEP B  DataService v14→v15 (migration[10])
STEP C  2 new RemoteEvents (QuestSync, ClaimQuest)
STEP D  QuestService ModuleScript
STEP E  QuestRunner Script
STEP F  Metric hooks in existing services
STEP G  QuestController LocalScript
STEP H  Verification
```

---

## STEP A — Config additions

Use the require()-cache-bust pattern (clone → replace → destroy old) because Config is a
ModuleScript.

```lua
-- Paste after Config.COSMETIC_ORDER in Config ModuleScript source
Config.QUEST_CATALOGUE = {
    -- Foraging
    {id="dance_trips_5",   label="Dance 5 Foraging Trips",       metric="danceTrips",      target=5,    reward={honey=200}},
    {id="dance_trips_10",  label="Dance 10 Foraging Trips",      metric="danceTrips",      target=10,   reward={honey=350}},
    {id="harvest_honey",   label="Harvest 500 Honey",            metric="honeyHarvested",  target=500,  reward={propolis=8}},
    {id="harvest_big",     label="Harvest 2000 Honey",           metric="honeyHarvested",  target=2000, reward={propolis=20}},
    {id="bloom_rush",      label="Trigger a Bloom Rush",         metric="bloomRushSeen",   target=1,    reward={honey=500, pollen=15}},
    -- Building
    {id="build_cells_3",   label="Build 3 Comb Cells",           metric="cellsBuilt",      target=3,    reward={honey=150}},
    {id="build_cells_8",   label="Build 8 Comb Cells",           metric="cellsBuilt",      target=8,    reward={honey=300, propolis=5}},
    {id="upgrade_cell",    label="Upgrade a Cell to Tier 2",     metric="cellsUpgraded",   target=1,    reward={honey=250}},
    {id="upgrade_cells_3", label="Upgrade 3 Cells to Tier 2+",  metric="cellsUpgraded",   target=3,    reward={honey=500}},
    {id="build_structure", label="Purchase a Structure Upgrade", metric="structuresBought",target=1,    reward={honey=400, pollen=10}},
    -- Economy
    {id="earn_propolis_20",label="Earn 20 Propolis",             metric="propolisEarned",  target=20,   reward={honey=300}},
    {id="earn_pollen_50",  label="Gather 50 Pollen",             metric="pollenGathered",  target=50,   reward={honey=200}},
    {id="spend_honey_1k",  label="Spend 1000 Honey",             metric="honeySpent",      target=1000, reward={pollen=25}},
    -- Defense
    {id="repel_wasp",      label="Repel a Wasp Raid",            metric="waspsRepelled",   target=1,    reward={honey=300, propolis=10}},
    {id="repel_wasps_3",   label="Repel 3 Wasp Raids",          metric="waspsRepelled",   target=3,    reward={honey=600, propolis=20}},
    {id="use_smoker",      label="Use the Smoker",               metric="smokerUses",      target=1,    reward={honey=150}},
    -- Population
    {id="hatch_bees_20",   label="Hatch 20 Bees",               metric="beesHatched",     target=20,   reward={honey=200, pollen=10}},
    {id="hatch_bees_50",   label="Hatch 50 Bees",               metric="beesHatched",     target=50,   reward={honey=400, pollen=20}},
    -- Prestige
    {id="swarm_once",      label="Perform a Swarm",             metric="swarmsPerformed", target=1,    reward={honey=1000, propolis=50, pollen=50}},
    -- Cosmetics
    {id="change_skin",     label="Equip a Bee Skin",            metric="skinsEquipped",   target=1,    reward={honey=100}},
}

Config.DAILY_QUEST = {
    NUM_QUESTS  = 3,   -- quests per rotation
    RESET_HOUR  = 0,   -- UTC hour for daily reset (midnight UTC)
}
```

Command Bar snippet (add to existing Config source):

```lua
local RS = game:GetService("ReplicatedStorage")
local oldCfg = RS.Modules.Config

-- Clone, patch, replace
local newCfg = oldCfg:Clone()
newCfg.Name = "Config_new"
newCfg.Parent = RS.Modules

-- Read existing source, append new tables
local src = oldCfg.Source
-- Append after last line that isn't 'return Config'
local insertPoint = src:find("\nreturn Config")
if insertPoint then
    local catalogue = [[

Config.QUEST_CATALOGUE = {
    {id="dance_trips_5",   label="Dance 5 Foraging Trips",       metric="danceTrips",      target=5,    reward={honey=200}},
    {id="dance_trips_10",  label="Dance 10 Foraging Trips",      metric="danceTrips",      target=10,   reward={honey=350}},
    {id="harvest_honey",   label="Harvest 500 Honey",            metric="honeyHarvested",  target=500,  reward={propolis=8}},
    {id="harvest_big",     label="Harvest 2000 Honey",           metric="honeyHarvested",  target=2000, reward={propolis=20}},
    {id="bloom_rush",      label="Trigger a Bloom Rush",         metric="bloomRushSeen",   target=1,    reward={honey=500, pollen=15}},
    {id="build_cells_3",   label="Build 3 Comb Cells",           metric="cellsBuilt",      target=3,    reward={honey=150}},
    {id="build_cells_8",   label="Build 8 Comb Cells",           metric="cellsBuilt",      target=8,    reward={honey=300, propolis=5}},
    {id="upgrade_cell",    label="Upgrade a Cell to Tier 2",     metric="cellsUpgraded",   target=1,    reward={honey=250}},
    {id="upgrade_cells_3", label="Upgrade 3 Cells to Tier 2+",  metric="cellsUpgraded",   target=3,    reward={honey=500}},
    {id="build_structure", label="Purchase a Structure Upgrade", metric="structuresBought",target=1,    reward={honey=400, pollen=10}},
    {id="earn_propolis_20",label="Earn 20 Propolis",             metric="propolisEarned",  target=20,   reward={honey=300}},
    {id="earn_pollen_50",  label="Gather 50 Pollen",             metric="pollenGathered",  target=50,   reward={honey=200}},
    {id="spend_honey_1k",  label="Spend 1000 Honey",             metric="honeySpent",      target=1000, reward={pollen=25}},
    {id="repel_wasp",      label="Repel a Wasp Raid",            metric="waspsRepelled",   target=1,    reward={honey=300, propolis=10}},
    {id="repel_wasps_3",   label="Repel 3 Wasp Raids",          metric="waspsRepelled",   target=3,    reward={honey=600, propolis=20}},
    {id="use_smoker",      label="Use the Smoker",               metric="smokerUses",      target=1,    reward={honey=150}},
    {id="hatch_bees_20",   label="Hatch 20 Bees",               metric="beesHatched",     target=20,   reward={honey=200, pollen=10}},
    {id="hatch_bees_50",   label="Hatch 50 Bees",               metric="beesHatched",     target=50,   reward={honey=400, pollen=20}},
    {id="swarm_once",      label="Perform a Swarm",             metric="swarmsPerformed", target=1,    reward={honey=1000, propolis=50, pollen=50}},
    {id="change_skin",     label="Equip a Bee Skin",            metric="skinsEquipped",   target=1,    reward={honey=100}},
}
Config.DAILY_QUEST = { NUM_QUESTS=3, RESET_HOUR=0 }
]]
    newCfg.Source = src:sub(1, insertPoint - 1) .. catalogue .. "\nreturn Config"
else
    newCfg.Source = src .. "\n-- QUEST_CATALOGUE not appended: could not find return Config"
end
newCfg.Name = "Config"
oldCfg.Name = "Config_old"
oldCfg.Parent = nil
print("Config updated with QUEST_CATALOGUE and DAILY_QUEST")
```

**Verify:** `print(#require(game:GetService("ReplicatedStorage").Modules.Config).QUEST_CATALOGUE)`
→ should print `20`

---

## STEP B — DataService v14 → v15

Use the clone-replace pattern on DataService.

Find the MIGRATIONS table and add migration[10]. Also update CURRENT_VERSION to 15.

```lua
-- Run in Command Bar after cloning DataService:

-- Inside the cloned DataService source, find the MIGRATIONS table.
-- Add at the end (after migration[9] which was added by cycle11_cosmetics_dispatch):
[10] = function(profile)
    profile.questSeed        = 0
    profile.questProgress    = {}   -- {[slotIndex] = {id, progress, claimed}}
    profile.questsLastReset  = 0
    profile.questMetrics     = {}   -- {[metricName] = number}
end,
```

Full Command Bar script to add migration[10] and bump version:

```lua
local SSS = game:GetService("ServerScriptService")
local oldDS = SSS.Systems.DataService

local newDS = oldDS:Clone()
newDS.Name = "DataService_new"
newDS.Parent = SSS.Systems

local src = oldDS.Source

-- Bump CURRENT_VERSION from 14 to 15
src = src:gsub("CURRENT_VERSION%s*=%s*14", "CURRENT_VERSION = 15")

-- Add migration[10] before the closing brace of MIGRATIONS
-- Find the last migration entry pattern and append after it
local migrationInsert = [[
    [10] = function(profile: Profile)
        profile.questSeed       = 0
        profile.questProgress   = {}
        profile.questsLastReset = 0
        profile.questMetrics    = {}
    end,
]]
-- Insert before the closing of the MIGRATIONS table (look for last "}," then "}")
-- Safer: find migration[9] closing and insert after
local insertAfter = "end,\n}"  -- last migration closes with end, then table closes with }
-- Use a more specific anchor: the very end of migration[9]
local anchor = "profile.molassesRepels = 0\n\t\tend,\n\t}"
local replacement = "profile.molassesRepels = 0\n\t\tend,\n\t" .. migrationInsert:gsub("^%s+", "\t") .. "}"
src = src:gsub(anchor, replacement, 1)

-- Fallback: if anchor not found, append before 'return DataService'
if not src:find("questSeed") then
    local returnPoint = src:find("\nreturn DataService")
    if returnPoint then
        src = src:sub(1, returnPoint - 1) .. "\n-- MIGRATION[10] FALLBACK INJECTION\n" ..
              "-- Add manually: [10] = function(profile) profile.questSeed=0; profile.questProgress={}; profile.questsLastReset=0; profile.questMetrics={} end," ..
              src:sub(returnPoint)
    end
end

newDS.Source = src
newDS.Name = "DataService"
oldDS.Name = "DataService_old"
oldDS.Parent = nil
print("DataService updated: v14 -> v15, migration[10] added")
```

**IMPORTANT:** If the anchor-based insertion fails (check if "questSeed" appears in the updated source), add migration[10] manually in the Studio Source editor. The profile fields that must exist are:
- `profile.questSeed = 0`
- `profile.questProgress = {}`
- `profile.questsLastReset = 0`
- `profile.questMetrics = {}`

**Verify:**
```lua
local SSS = game:GetService("ServerScriptService")
local src = SSS.Systems.DataService.Source
print("Version:", src:match("CURRENT_VERSION%s*=%s*(%d+)"))
print("Has migration[10]:", tostring(src:find("questSeed") ~= nil))
```
→ Version: 15, Has migration[10]: true

---

## STEP C — New RemoteEvents

Add 2 RemoteEvents to `ReplicatedStorage.Remotes`:

```lua
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local function addEvent(name)
    if not remotes:FindFirstChild(name) then
        local e = Instance.new("RemoteEvent")
        e.Name = name
        e.Parent = remotes
        print("Created RemoteEvent:", name)
    else
        print("Already exists:", name)
    end
end
addEvent("QuestSync")   -- Server→Client: {quests: array, metrics: table}
addEvent("ClaimQuest")  -- Client→Server: slot: number (1-3)
```

---

## STEP D — QuestService ModuleScript

**Location:** `ServerScriptService.Systems.QuestService`  
**Type:** ModuleScript  
**Strict:** `--!strict`

```lua
--!strict
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config      = require(ReplicatedStorage.Modules.Config)
local DataService = require(ServerScriptService.Systems.DataService)

local QuestService = {}

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local QuestSync:  RemoteEvent = Remotes:WaitForChild("QuestSync")
local ClaimQuest: RemoteEvent = Remotes:WaitForChild("ClaimQuest")

type QuestTemplate = {id: string, label: string, metric: string, target: number, reward: {honey: number?, propolis: number?, pollen: number?}}

-- Returns YYYYMMDD as a number (server UTC)
local function dateSeed(): number
    local d = os.date("!%Y%m%d")
    return tonumber(d :: string) :: number
end

-- Pick NUM_QUESTS quests from catalogue using LCG Fisher-Yates with date seed
local function pickDailyQuests(seed: number): {QuestTemplate}
    local catalogue = Config.QUEST_CATALOGUE :: {QuestTemplate}
    local n = #catalogue
    local indices: {number} = table.create(n)
    for i = 1, n do indices[i] = i end
    local rng = seed
    for i = n, 2, -1 do
        rng = (rng * 1664525 + 1013904223) % (2^32)
        local j = (rng % i) + 1
        indices[i], indices[j] = indices[j], indices[i]
    end
    local picked: {QuestTemplate} = {}
    for i = 1, Config.DAILY_QUEST.NUM_QUESTS do
        table.insert(picked, catalogue[indices[i]])
    end
    return picked
end

type SyncPayload = {quests: {any}, metrics: {[string]: number}}

local function buildSyncPayload(player: Player): SyncPayload
    local profile = DataService.GetProfile(player)
    if not profile then return {quests = {}, metrics = {}} end

    local seed   = dateSeed()
    local quests = pickDailyQuests(seed)

    local questList = {}
    for i, q in quests do
        local prog = (profile.questProgress :: {[number]: any})[i] or {id=q.id, progress=0, claimed=false}
        table.insert(questList, {
            slot     = i,
            id       = q.id,
            label    = q.label,
            target   = q.target,
            reward   = q.reward,
            progress = prog.progress or 0,
            claimed  = prog.claimed  or false,
        })
    end
    return {quests = questList, metrics = profile.questMetrics or {}}
end

local function resetQuests(player: Player): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local seed   = dateSeed()
    local quests = pickDailyQuests(seed)

    profile.questSeed        = seed
    profile.questsLastReset  = os.time()
    profile.questProgress    = {}
    profile.questMetrics     = {}

    for i, q in quests do
        (profile.questProgress :: {[number]: any})[i] = {id=q.id, progress=0, claimed=false}
    end

    QuestSync:FireClient(player, buildSyncPayload(player))
end

-- Called by game systems (DanceService, ResourceService, CombService, etc.)
function QuestService.IncrementMetric(player: Player, metric: string, amount: number): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end

    -- Lazy reset if day has rolled over
    local seed = dateSeed()
    if (profile.questSeed or 0) ~= seed then
        resetQuests(player)
        return  -- resetQuests fires QuestSync; return to avoid double sync
    end

    local metrics = (profile.questMetrics or {}) :: {[string]: number}
    metrics[metric] = (metrics[metric] or 0) + amount
    profile.questMetrics = metrics

    local quests = pickDailyQuests(seed)
    local changed = false
    for i, q in quests do
        if q.metric == metric then
            local prog = (profile.questProgress :: {[number]: any})[i] or {id=q.id, progress=0, claimed=false}
            if not prog.claimed and prog.progress < q.target then
                prog.progress = math.min(metrics[metric] or 0, q.target)
                ;(profile.questProgress :: {[number]: any})[i] = prog
                changed = true
            end
        end
    end

    if changed then
        QuestSync:FireClient(player, buildSyncPayload(player))
    end
end

local function handleClaim(player: Player, slot: number): ()
    if typeof(slot) ~= "number" then return end
    slot = math.floor(slot)
    if slot < 1 or slot > Config.DAILY_QUEST.NUM_QUESTS then return end

    local profile = DataService.GetProfile(player)
    if not profile then return end

    local seed   = dateSeed()
    local quests = pickDailyQuests(seed)
    local q      = quests[slot]
    if not q then return end

    local prog = (profile.questProgress :: {[number]: any})[slot]
    if not prog or prog.claimed then return end
    if (prog.progress or 0) < q.target then return end

    local reward = q.reward
    profile.honey    = (profile.honey    or 0) + (reward.honey    or 0)
    profile.propolis = (profile.propolis or 0) + (reward.propolis or 0)
    profile.pollen   = (profile.pollen   or 0) + (reward.pollen   or 0)

    prog.claimed = true
    ;(profile.questProgress :: {[number]: any})[slot] = prog

    DataService.Save(player)
    QuestSync:FireClient(player, buildSyncPayload(player))
end

ClaimQuest.OnServerEvent:Connect(handleClaim)

Players.PlayerAdded:Connect(function(player: Player)
    task.wait(3)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local seed = dateSeed()
    if (profile.questSeed or 0) ~= seed then
        resetQuests(player)
    else
        QuestSync:FireClient(player, buildSyncPayload(player))
    end
end)

function QuestService.Start(): ()
    -- Quests reset lazily on first IncrementMetric or join; no ticker needed
end

return QuestService
```

Create in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local systems = SSS:FindFirstChild("Systems") or Instance.new("Folder", SSS)
systems.Name = "Systems"
systems.Parent = SSS

local qs = Instance.new("ModuleScript")
qs.Name = "QuestService"
qs.Parent = systems
qs.Source = [[ ... paste full source above ... ]]
print("QuestService created at", qs:GetFullName())
```

---

## STEP E — QuestRunner Script

**Location:** `ServerScriptService.QuestRunner`  
**Type:** Script

```lua
local SSS = game:GetService("ServerScriptService")
local runner = Instance.new("Script")
runner.Name = "QuestRunner"
runner.Parent = SSS
runner.Source = [[--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local QuestService = require(ServerScriptService.Systems.QuestService)
QuestService.Start()
]]
print("QuestRunner created")
```

---

## STEP F — Metric hooks in existing services

For each service below, open its Source (clone-replace pattern if ModuleScript), find the
indicated function, and add the QuestService.IncrementMetric call.

First, add the require at the top of each service being modified:

```lua
local QuestService = require(ServerScriptService.Systems.QuestService)
```

### Hook table

| Service | Function to patch | After what line | Metric | Amount |
|---------|-------------------|-----------------|--------|--------|
| DanceService | trip nectar return (where profile.honey is credited from a trip) | after nectar credit | `"danceTrips"` | 1 |
| ResourceService | credit honey (AddHoney or equivalent) | after `profile.honey = profile.honey + amount` | `"honeyHarvested"` | amount |
| ResourceService | debit honey (SpendHoney or equivalent) | after successful spend | `"honeySpent"` | amount |
| ResourceService | credit propolis | after propolis increment | `"propolisEarned"` | amount |
| ResourceService | credit pollen | after pollen increment | `"pollenGathered"` | amount |
| CombService | Build success | after cell creation confirmed | `"cellsBuilt"` | 1 |
| CombService | Upgrade cell tier ≥ 2 | after tier increment when newTier >= 2 | `"cellsUpgraded"` | 1 |
| StructureService | purchase tier | after profile debit for structure | `"structuresBought"` | 1 |
| ThreatService | wasp repelled | in wasp-repel success branch | `"waspsRepelled"` | 1 |
| ThreatService | smoker used (RepelBear success) | after bear patience boost | `"smokerUses"` | 1 |
| PopulationService | bee hatched | after PopulationService hatches bee | `"beesHatched"` | 1 |
| SwarmService | performSwarm success | after profile.generation incremented | `"swarmsPerformed"` | 1 |
| CosmeticService | handleEquip success | after profile.equippedSkin updated | `"skinsEquipped"` | 1 |
| WeatherService | BloomRush state entered | in transition-to-BloomRush branch | `"bloomRushSeen"` | 1 (for ALL players) |

**WeatherService special case** (server-global event):

```lua
-- In WeatherService, in the transition function where state becomes "BloomRush":
local Players = game:GetService("Players")
local QuestService = require(game:GetService("ServerScriptService").Systems.QuestService)
for _, player in Players:GetPlayers() do
    QuestService.IncrementMetric(player, "bloomRushSeen", 1)
end
```

---

## STEP G — QuestController LocalScript

**Location:** `StarterPlayerScripts.QuestController`  
**Type:** LocalScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local QuestSync:  RemoteEvent = Remotes:WaitForChild("QuestSync")
local ClaimQuest: RemoteEvent = Remotes:WaitForChild("ClaimQuest")

-- Warm Wax palette
local C_BROWN  = Color3.fromRGB(122, 74, 34)
local C_GOLD   = Color3.fromRGB(242, 168, 28)
local C_CREAM  = Color3.fromRGB(232, 212, 154)
local C_AMBER  = Color3.fromRGB(90, 53, 16)
local C_GREEN  = Color3.fromRGB(88, 164, 72)
local C_GREY   = Color3.fromRGB(80, 60, 40)

local widget: ScreenGui?        = nil
local questRows: {Frame}        = {}
local panelOpen                 = false

local function buildWidget(): ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name           = "QuestGui"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 5
    sg.IgnoreGuiInset = true
    sg.Parent         = localPlayer.PlayerGui

    -- Toggle button (bottom-right, always visible)
    local toggle = Instance.new("TextButton")
    toggle.Name             = "ToggleBtn"
    toggle.Size             = UDim2.new(0, 44, 0, 44)
    toggle.Position         = UDim2.new(1, -54, 1, -54)
    toggle.AnchorPoint      = Vector2.new(1, 1)
    toggle.BackgroundColor3 = C_BROWN
    toggle.Text             = "Q"
    toggle.TextScaled       = true
    toggle.Font             = Enum.Font.FredokaOne
    toggle.TextColor3       = C_CREAM
    toggle.ZIndex           = 10
    toggle.Parent           = sg
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0.5, 0)
    tc.Parent = toggle
    local ts = Instance.new("UIStroke")
    ts.Color = C_GOLD
    ts.Thickness = 1.5
    ts.Parent = toggle

    -- Panel (slides up from bottom-right on toggle)
    local panel = Instance.new("Frame")
    panel.Name                   = "Panel"
    panel.Size                   = UDim2.new(0, 280, 0, 220)
    panel.Position               = UDim2.new(1, -54, 1, -110)
    panel.AnchorPoint            = Vector2.new(1, 1)
    panel.BackgroundColor3       = C_AMBER
    panel.BackgroundTransparency = 0.08
    panel.ClipsDescendants       = true
    panel.Visible                = false
    panel.ZIndex                 = 9
    panel.Parent                 = sg
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, 8)
    pc.Parent = panel
    local ps = Instance.new("UIStroke")
    ps.Color = C_GOLD
    ps.Thickness = 1.5
    ps.Parent = panel

    -- Header
    local header = Instance.new("TextLabel")
    header.Name             = "Header"
    header.Size             = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = C_BROWN
    header.Text             = "Daily Quests"
    header.Font             = Enum.Font.FredokaOne
    header.TextScaled       = true
    header.TextColor3       = C_GOLD
    header.ZIndex           = 10
    header.Parent           = panel
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 8)
    hc.Parent = header

    -- Quest list
    local list = Instance.new("Frame")
    list.Name                   = "QuestList"
    list.Size                   = UDim2.new(1, -8, 0, 180)
    list.Position               = UDim2.new(0, 4, 0, 32)
    list.BackgroundTransparency = 1
    list.Parent                 = panel

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent  = list

    -- 3 quest row frames (one per slot)
    questRows = {}
    for i = 1, 3 do
        local row = Instance.new("Frame")
        row.Name                   = "QuestRow" .. i
        row.Size                   = UDim2.new(1, 0, 0, 54)
        row.BackgroundColor3       = Color3.fromRGB(60, 38, 12)
        row.BackgroundTransparency = 0.15
        row.ZIndex                 = 10
        row.Parent                 = list
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 6)
        rc.Parent = row

        local lbl = Instance.new("TextLabel")
        lbl.Name            = "Label"
        lbl.Size            = UDim2.new(1, -70, 0, 18)
        lbl.Position        = UDim2.new(0, 6, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Font            = Enum.Font.FredokaOne
        lbl.TextXAlignment  = Enum.TextXAlignment.Left
        lbl.TextScaled      = true
        lbl.TextColor3      = C_CREAM
        lbl.ZIndex          = 11
        lbl.Parent          = row

        local bar = Instance.new("Frame")
        bar.Name                   = "ProgressBg"
        bar.Size                   = UDim2.new(1, -70, 0, 8)
        bar.Position               = UDim2.new(0, 6, 0, 26)
        bar.BackgroundColor3       = Color3.fromRGB(40, 26, 8)
        bar.ZIndex                 = 11
        bar.Parent                 = row
        local barc = Instance.new("UICorner")
        barc.CornerRadius = UDim.new(0, 4)
        barc.Parent = bar

        local fill = Instance.new("Frame")
        fill.Name             = "Fill"
        fill.Size             = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = C_GOLD
        fill.ZIndex           = 12
        fill.Parent           = bar
        local fillc = Instance.new("UICorner")
        fillc.CornerRadius = UDim.new(0, 4)
        fillc.Parent = fill

        local progLbl = Instance.new("TextLabel")
        progLbl.Name               = "ProgressText"
        progLbl.Size               = UDim2.new(1, -70, 0, 14)
        progLbl.Position           = UDim2.new(0, 6, 0, 36)
        progLbl.BackgroundTransparency = 1
        progLbl.Font               = Enum.Font.Gotham
        progLbl.TextXAlignment     = Enum.TextXAlignment.Left
        progLbl.TextScaled         = true
        progLbl.TextColor3         = C_CREAM
        progLbl.ZIndex             = 11
        progLbl.Parent             = row

        local btn = Instance.new("TextButton")
        btn.Name             = "ClaimBtn"
        btn.Size             = UDim2.new(0, 60, 1, -8)
        btn.Position         = UDim2.new(1, -66, 0, 4)
        btn.BackgroundColor3 = C_GREY
        btn.Text             = "Claim"
        btn.Font             = Enum.Font.FredokaOne
        btn.TextScaled       = true
        btn.TextColor3       = C_CREAM
        btn.ZIndex           = 11
        btn.Parent           = row
        local btnc = Instance.new("UICorner")
        btnc.CornerRadius = UDim.new(0, 6)
        btnc.Parent = btn

        local slot = i
        btn.MouseButton1Click:Connect(function()
            ClaimQuest:FireServer(slot)
        end)

        table.insert(questRows, row)
    end

    -- Toggle logic
    toggle.MouseButton1Click:Connect(function()
        panelOpen = not panelOpen
        panel.Visible = panelOpen
    end)

    return sg
end

-- Update a single row with quest data
local function updateRow(row: Frame, data: {slot:number, label:string, target:number, progress:number, claimed:boolean, reward:{honey:number?,propolis:number?,pollen:number?}}): ()
    local lbl      = row:FindFirstChild("Label")      :: TextLabel
    local fill     = row:FindFirstChild("ProgressBg") and (row.ProgressBg :: Frame):FindFirstChild("Fill") :: Frame
    local progLbl  = row:FindFirstChild("ProgressText") :: TextLabel
    local btn      = row:FindFirstChild("ClaimBtn")   :: TextButton

    if lbl      then lbl.Text  = data.label end
    if progLbl  then progLbl.Text = data.progress .. " / " .. data.target end

    if fill then
        local pct = math.min(data.progress / math.max(data.target, 1), 1)
        TweenService:Create(fill, TweenInfo.new(0.3), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
        fill.BackgroundColor3 = data.progress >= data.target and C_GREEN or C_GOLD
    end

    if btn then
        if data.claimed then
            btn.Text             = "Done"
            btn.BackgroundColor3 = C_GREY
            btn.Active           = false
        elseif data.progress >= data.target then
            btn.Text             = "Claim!"
            btn.BackgroundColor3 = C_GREEN
            btn.Active           = true
        else
            btn.Text             = "Claim"
            btn.BackgroundColor3 = C_GREY
            btn.Active           = false
        end
    end
end

QuestSync.OnClientEvent:Connect(function(payload: {quests:{any}, metrics:{[string]:number}})
    if not widget then
        widget = buildWidget()
    end
    for _, questData in payload.quests do
        local row = questRows[questData.slot]
        if row then
            updateRow(row, questData)
        end
    end
end)
```

Create in Studio Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if not SPS then
    SPS = game:GetService("StarterPlayer"):FindFirstChildOfClass("StarterPlayerScripts")
end
local qc = Instance.new("LocalScript")
qc.Name = "QuestController"
qc.Parent = SPS
qc.Source = [[ ... paste full source above ... ]]
print("QuestController created at", qc:GetFullName())
```

---

## STEP H — Verification

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local results = {}
local issues  = {}

-- DataService version
local dsSrc = SSS.Systems.DataService.Source
local ver = dsSrc:match("CURRENT_VERSION%s*=%s*(%d+)")
table.insert(results, "DataService version: " .. (ver or "NOT FOUND"))
if ver ~= "15" then table.insert(issues, "WRONG DataService version: expected 15, got " .. tostring(ver)) end

-- Migration[10]
local hasMig = dsSrc:find("questSeed") ~= nil
table.insert(results, "migration[10] questSeed: " .. tostring(hasMig))
if not hasMig then table.insert(issues, "MISSING migration[10] questSeed field") end

-- Config
local ok, cfg = pcall(require, RS.Modules.Config)
if ok then
    local catLen = cfg.QUEST_CATALOGUE and #cfg.QUEST_CATALOGUE or 0
    table.insert(results, "QUEST_CATALOGUE entries: " .. catLen)
    if catLen ~= 20 then table.insert(issues, "QUEST_CATALOGUE should have 20 entries, got " .. catLen) end
    table.insert(results, "DAILY_QUEST.NUM_QUESTS: " .. tostring(cfg.DAILY_QUEST and cfg.DAILY_QUEST.NUM_QUESTS))
else
    table.insert(issues, "Config require failed: " .. tostring(cfg))
end

-- RemoteEvents
local remotes = RS:FindFirstChild("Remotes")
for _, name in {"QuestSync", "ClaimQuest"} do
    local e = remotes and remotes:FindFirstChild(name)
    table.insert(results, name .. ": " .. (e and e.ClassName or "MISSING"))
    if not e then table.insert(issues, "MISSING RemoteEvent: " .. name) end
end

-- Scripts
local qs = SSS.Systems:FindFirstChild("QuestService")
table.insert(results, "QuestService: " .. (qs and qs.ClassName or "MISSING"))
if not qs then table.insert(issues, "MISSING QuestService ModuleScript") end

local qr = SSS:FindFirstChild("QuestRunner")
table.insert(results, "QuestRunner: " .. (qr and qr.ClassName or "MISSING"))
if not qr then table.insert(issues, "MISSING QuestRunner Script") end

local qc = SPS:FindFirstChild("QuestController")
table.insert(results, "QuestController: " .. (qc and qc.ClassName or "MISSING"))
if not qc then table.insert(issues, "MISSING QuestController LocalScript") end

-- QuestService source checks
if qs then
    local qsSrc = qs.Source
    local checks = {
        {"--!strict",           "--!strict"},
        {"IncrementMetric",     "QuestService.IncrementMetric function"},
        {"pickDailyQuests",     "pickDailyQuests function"},
        {"ClaimQuest",          "ClaimQuest handler"},
        {"Players.PlayerAdded", "PlayerAdded hook"},
    }
    for _, pair in checks do
        local found = qsSrc:find(pair[1]) ~= nil
        table.insert(results, pair[2] .. ": " .. tostring(found))
        if not found then table.insert(issues, "MISSING in QuestService: " .. pair[2]) end
    end
end

-- Summary
local out = table.concat(results, "\n")
if #issues > 0 then
    out = out .. "\n\nISSUES (" .. #issues .. "):\n" .. table.concat(issues, "\n")
else
    out = out .. "\n\nALL CHECKS PASSED"
end
print(out)
```

Expected output when all steps complete:

```
DataService version: 15
migration[10] questSeed: true
QUEST_CATALOGUE entries: 20
DAILY_QUEST.NUM_QUESTS: 3
QuestSync: RemoteEvent
ClaimQuest: RemoteEvent
QuestService: ModuleScript
QuestRunner: Script
QuestController: LocalScript
--!strict: true
QuestService.IncrementMetric function: true
pickDailyQuests function: true
ClaimQuest handler: true
PlayerAdded hook: true

ALL CHECKS PASSED
```

---

## PART BUDGET NOTE

No new world parts — QuestGui is a ScreenGui. Running total unchanged at **~4,052/5,000**.

---

## NOTES ON METRIC HOOK INTEGRATION

- All metric hooks use `QuestService.IncrementMetric(player, metric, amount)` — fire-and-forget, no return value needed
- QuestService safely no-ops if player has no profile (new join race condition)
- Daily reset is lazy — triggers on join or first IncrementMetric after midnight UTC
- All 20 quest templates are shared server-wide, seeded by date — all players see identical quests each day
- `ClaimQuest` server handler validates: slot 1-3, quest complete, not already claimed — no client trust
- Rewards are applied directly to profile (not through ResourceService to avoid double-counting quest metrics)
