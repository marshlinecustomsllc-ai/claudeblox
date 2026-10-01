# CYCLE 11 — ACHIEVEMENTS DISPATCH (DISPATCH 25)
## AchievementService + Badge Toast Widget

> **SUPERSEDES cycle7_achievements_dispatch.md** — that dispatch targets stale
> DataService v7→v8 (migration[8]). By execution time DataService is at v15 and
> migration[8] is already taken by dispatch 21 (SwarmService, v12→v13).
> Do NOT also execute cycle7_achievements_dispatch.md.

**Prerequisites:** Dispatches 1–24 executed in order. DataService at v15.
`profile.questMetrics` already exists (dispatch 23, v14→v15).
`QuestService.IncrementMetric` fully wired with 14 metric hooks (dispatch 23).  
**Profile fields added:** `achievementsUnlocked` (array of string IDs)  
**DataService:** v15 → v16 (migration[11], CURRENT_VERSION = 16)  
**Part budget impact:** 0 new world parts (UI toast only)

---

## OVERVIEW

20 achievements tied to the emotional journey of the game. They piggyback on the same
`profile.questMetrics` table that daily quests use — no separate metric storage needed.
`AchievementService.CheckAll(player)` is called lazily from inside `QuestService.IncrementMetric`
and the new `QuestService.SetMetric` (for non-cumulative metrics like tier and floor numbers).
A badge toast slides in from the top-right when an achievement is earned, then auto-dismisses.
Achievements are permanent — they survive Swarms and never reset.

---

## EXECUTION ORDER

```
STEP A  Config.ACHIEVEMENTS
STEP B  DataService v15→v16 (migration[11])
STEP C  2 new RemoteEvents (AchievementUnlocked, AchievementSync)
STEP D  AchievementService ModuleScript
STEP E  AchievementsRunner Script
STEP F  QuestService.SetMetric + AchievementService.CheckAll hook in QuestService
STEP G  Additional metric hooks in CombService/QueenService/SwarmService/ThreatService/CosmeticService/QuestService
STEP H  AchievementController LocalScript
STEP I  Verification
```

---

## STEP A — Config.ACHIEVEMENTS

Add to Config ModuleScript (clone-replace pattern):

```lua
Config.ACHIEVEMENTS = {
    -- First steps
    {id="first_cell",    label="First Cell",           desc="Build your first comb cell.",              metric="cellsBuilt",       threshold=1,     icon="[cell]"},
    {id="first_dance",   label="Follow the Waggle",    desc="Complete your first waggle dance.",        metric="danceTrips",        threshold=1,     icon="[dance]"},
    {id="first_harvest", label="Golden Haul",           desc="Harvest honey for the first time.",        metric="honeyHarvested",    threshold=1,     icon="[honey]"},
    {id="first_repel",   label="Stand Your Ground",    desc="Repel a wasp raid.",                       metric="waspsRepelled",     threshold=1,     icon="[shield]"},
    -- Progress milestones
    {id="cells_25",      label="Hex Architect",         desc="Build 25 comb cells.",                     metric="cellsBuilt",        threshold=25,    icon="[hex]"},
    {id="cells_100",     label="Master Builder",        desc="Build 100 comb cells.",                    metric="cellsBuilt",        threshold=100,   icon="[build]"},
    {id="honey_10k",     label="Honey Hoard",           desc="Harvest 10,000 honey in total.",           metric="honeyHarvested",    threshold=10000, icon="[star]"},
    {id="honey_100k",    label="The Golden River",      desc="Harvest 100,000 honey in total.",          metric="honeyHarvested",    threshold=100000,icon="[wave]"},
    {id="dances_50",     label="Dance Master",          desc="Complete 50 waggle dances.",               metric="danceTrips",        threshold=50,    icon="[music]"},
    {id="wasps_10",      label="Guardian of the Hive",  desc="Repel 10 wasp raids.",                     metric="waspsRepelled",     threshold=10,    icon="[sword]"},
    -- System unlocks
    {id="floor_2",       label="Going Up",              desc="Unlock Floor 2.",                          metric="floorsUnlocked",    threshold=2,     icon="[up]"},
    {id="floor_3",       label="Sky Hive",              desc="Unlock Floor 3.",                          metric="floorsUnlocked",    threshold=3,     icon="[sky]"},
    {id="queen_tier3",   label="Queen Crowned",         desc="Reach Queen Tier 3.",                      metric="queenTierReached",  threshold=3,     icon="[crown]"},
    {id="bloom_rush_3",  label="Storm Chaser",          desc="Witness 3 Bloom Rush events.",             metric="bloomRushSeen",     threshold=3,     icon="[bloom]"},
    {id="structure_all", label="Full Apiary",           desc="Purchase every structure upgrade.",        metric="structuresBought",  threshold=8,     icon="[apiary]"},
    -- Prestige / late game
    {id="first_swarm",   label="Born Again",            desc="Perform your first Swarm.",                metric="swarmsPerformed",   threshold=1,     icon="[swarm]"},
    {id="gen_3",         label="Dynasty",               desc="Reach Generation 3.",                      metric="generationReached", threshold=3,     icon="[scroll]"},
    {id="molasses_end",  label="Bear Proof",            desc="Complete the Molasses storyline.",         metric="molassesEnded",     threshold=1,     icon="[bear]"},
    {id="all_skins",     label="Wardrobe Complete",     desc="Unlock all 7 bee skins.",                  metric="skinsOwned",        threshold=7,     icon="[wardrobe]"},
    -- Daily quest milestone
    {id="quests_25",     label="Diligent Beekeeper",   desc="Complete 25 daily quests.",                metric="questsCompleted",   threshold=25,    icon="[quest]"},
}
```

> **Note on icons:** The icon strings shown above are placeholders in square brackets.
> Replace with actual Unicode emoji in the live Source if desired (the original cycle7
> dispatch used emoji; use those or simple text). The AchievementController displays
> the icon field in the toast.

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local oldCfg = RS.Modules.Config
local newCfg = oldCfg:Clone()
newCfg.Name = "Config_new"
newCfg.Parent = RS.Modules

local src = oldCfg.Source
local insertPoint = src:find("\nreturn Config")
if insertPoint then
    local addition = [[

Config.ACHIEVEMENTS = {
    {id="first_cell",    label="First Cell",           desc="Build your first comb cell.",              metric="cellsBuilt",       threshold=1,     icon="🐝"},
    {id="first_dance",   label="Follow the Waggle",    desc="Complete your first waggle dance.",        metric="danceTrips",        threshold=1,     icon="💃"},
    {id="first_harvest", label="Golden Haul",           desc="Harvest honey for the first time.",        metric="honeyHarvested",    threshold=1,     icon="🍯"},
    {id="first_repel",   label="Stand Your Ground",    desc="Repel a wasp raid.",                       metric="waspsRepelled",     threshold=1,     icon="🛡️"},
    {id="cells_25",      label="Hex Architect",         desc="Build 25 comb cells.",                     metric="cellsBuilt",        threshold=25,    icon="🔷"},
    {id="cells_100",     label="Master Builder",        desc="Build 100 comb cells.",                    metric="cellsBuilt",        threshold=100,   icon="🏗️"},
    {id="honey_10k",     label="Honey Hoard",           desc="Harvest 10,000 honey in total.",           metric="honeyHarvested",    threshold=10000, icon="✨"},
    {id="honey_100k",    label="The Golden River",      desc="Harvest 100,000 honey in total.",          metric="honeyHarvested",    threshold=100000,icon="🌊"},
    {id="dances_50",     label="Dance Master",          desc="Complete 50 waggle dances.",               metric="danceTrips",        threshold=50,    icon="🎭"},
    {id="wasps_10",      label="Guardian of the Hive",  desc="Repel 10 wasp raids.",                     metric="waspsRepelled",     threshold=10,    icon="⚔️"},
    {id="floor_2",       label="Going Up",              desc="Unlock Floor 2.",                          metric="floorsUnlocked",    threshold=2,     icon="🏢"},
    {id="floor_3",       label="Sky Hive",              desc="Unlock Floor 3.",                          metric="floorsUnlocked",    threshold=3,     icon="🌤️"},
    {id="queen_tier3",   label="Queen Crowned",         desc="Reach Queen Tier 3.",                      metric="queenTierReached",  threshold=3,     icon="👑"},
    {id="bloom_rush_3",  label="Storm Chaser",          desc="Witness 3 Bloom Rush events.",             metric="bloomRushSeen",     threshold=3,     icon="🌸"},
    {id="structure_all", label="Full Apiary",           desc="Purchase every structure upgrade.",        metric="structuresBought",  threshold=8,     icon="🏛️"},
    {id="first_swarm",   label="Born Again",            desc="Perform your first Swarm.",                metric="swarmsPerformed",   threshold=1,     icon="🌀"},
    {id="gen_3",         label="Dynasty",               desc="Reach Generation 3.",                      metric="generationReached", threshold=3,     icon="📜"},
    {id="molasses_end",  label="Bear Proof",            desc="Complete the Molasses storyline.",         metric="molassesEnded",     threshold=1,     icon="🐻"},
    {id="all_skins",     label="Wardrobe Complete",     desc="Unlock all 7 bee skins.",                  metric="skinsOwned",        threshold=7,     icon="🎨"},
    {id="quests_25",     label="Diligent Beekeeper",   desc="Complete 25 daily quests.",                metric="questsCompleted",   threshold=25,    icon="📋"},
}
]]
    newCfg.Source = src:sub(1, insertPoint - 1) .. addition .. "\nreturn Config"
else
    warn("Config: could not find 'return Config'")
end
newCfg.Name = "Config"
oldCfg.Name = "Config_old"
oldCfg.Parent = nil
print("Config.ACHIEVEMENTS added, count:", #require(RS.Modules.Config).ACHIEVEMENTS)
```

---

## STEP B — DataService v15 → v16

Clone-replace DataService. Add migration[11] and bump CURRENT_VERSION to 16.

```lua
local SSS = game:GetService("ServerScriptService")
local oldDS = SSS.Systems.DataService
local newDS = oldDS:Clone()
newDS.Name = "DataService_new"
newDS.Parent = SSS.Systems

local src = oldDS.Source

-- Bump version
src = src:gsub("CURRENT_VERSION%s*=%s*15", "CURRENT_VERSION = 16")

-- Add migration[11] (achievementsUnlocked field; questMetrics already exists from migration[10])
local mig11 = [[
    [11] = function(profile: Profile)
        profile.achievementsUnlocked = {}
    end,
]]
-- Anchor: end of migration[10] body — find "questMetrics    = {}" then closing "end," then "}"
-- Safe fallback: insert before 'return DataService'
if src:find("questSeed") then
    -- migration[10] exists; add after its closing end,
    -- The migration[10] function ends with: profile.questMetrics    = {}\n    end,
    local anchor = "profile.questMetrics    = {}\n\t\tend,"
    local replacement = "profile.questMetrics    = {}\n\t\tend,\n" .. mig11
    local patched = src:gsub(anchor, replacement, 1)
    if patched ~= src then
        src = patched
    else
        -- Try simpler anchor
        local anchor2 = "profile.questMetrics = {}\n\t\tend,"
        local patched2 = src:gsub(anchor2, "profile.questMetrics = {}\n\t\tend,\n" .. mig11, 1)
        if patched2 ~= src then
            src = patched2
        else
            warn("Could not find migration[10] anchor — add migration[11] manually")
        end
    end
end

newDS.Source = src
newDS.Name = "DataService"
oldDS.Name = "DataService_old"
oldDS.Parent = nil
print("DataService v15→v16, migration[11] achievementsUnlocked")
```

**Verify:**
```lua
local src = game:GetService("ServerScriptService").Systems.DataService.Source
print("Version:", src:match("CURRENT_VERSION%s*=%s*(%d+)"))
print("Has migration[11]:", tostring(src:find("achievementsUnlocked") ~= nil))
```
→ Version: 16, Has migration[11]: true

---

## STEP C — New RemoteEvents

```lua
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
for _, name in {"AchievementUnlocked", "AchievementSync"} do
    if not remotes:FindFirstChild(name) then
        local e = Instance.new("RemoteEvent")
        e.Name = name
        e.Parent = remotes
        print("Created:", name)
    else
        print("Already exists:", name)
    end
end
```

---

## STEP D — AchievementService ModuleScript

**Location:** `ServerScriptService.Systems.AchievementService`  
**Type:** ModuleScript  
**Strict:** `--!strict`

```lua
--!strict
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config      = require(ReplicatedStorage.Modules.Config)
local DataService = require(ServerScriptService.Systems.DataService)

local AchievementService = {}

local Remotes               = ReplicatedStorage:WaitForChild("Remotes")
local AchievementUnlocked: RemoteEvent = Remotes:WaitForChild("AchievementUnlocked")
local AchievementSync:     RemoteEvent = Remotes:WaitForChild("AchievementSync")

type Achievement = {id: string, label: string, desc: string, metric: string, threshold: number, icon: string}

-- Called from QuestService.IncrementMetric and QuestService.SetMetric after any metric update
function AchievementService.CheckAll(player: Player): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local unlocked = (profile.achievementsUnlocked or {}) :: {string}
    local metrics  = (profile.questMetrics or {}) :: {[string]: number}

    -- Fast lookup set
    local unlockedSet: {[string]: boolean} = {}
    for _, id in unlocked do unlockedSet[id] = true end

    local newlyEarned: {Achievement} = {}
    for _, ach in Config.ACHIEVEMENTS :: {Achievement} do
        if not unlockedSet[ach.id] then
            local current = metrics[ach.metric] or 0
            if current >= ach.threshold then
                table.insert(unlocked, ach.id)
                unlockedSet[ach.id] = true
                table.insert(newlyEarned, ach)
            end
        end
    end

    if #newlyEarned > 0 then
        profile.achievementsUnlocked = unlocked
        DataService.Save(player)
        for _, ach in newlyEarned do
            AchievementUnlocked:FireClient(player, {
                id    = ach.id,
                label = ach.label,
                desc  = ach.desc,
                icon  = ach.icon,
            })
        end
    end
end

-- Broadcast current unlocked list to client (called on join)
function AchievementService.SyncClient(player: Player): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end
    AchievementSync:FireClient(player, profile.achievementsUnlocked or {})
end

Players.PlayerAdded:Connect(function(player: Player)
    task.wait(4)
    AchievementService.SyncClient(player)
end)

return AchievementService
```

Create:

```lua
local SSS = game:GetService("ServerScriptService")
local achMod = Instance.new("ModuleScript")
achMod.Name = "AchievementService"
achMod.Parent = SSS.Systems
achMod.Source = [[ ... paste full source above ... ]]
print("AchievementService created at", achMod:GetFullName())
```

---

## STEP E — AchievementsRunner Script

```lua
local SSS = game:GetService("ServerScriptService")
local runner = Instance.new("Script")
runner.Name = "AchievementsRunner"
runner.Parent = SSS
runner.Source = [[--!strict
local ServerScriptService = game:GetService("ServerScriptService")
require(ServerScriptService.Systems.AchievementService)
-- Module self-connects Players.PlayerAdded on require; no Start() needed
]]
print("AchievementsRunner created")
```

---

## STEP F — QuestService: add SetMetric + AchievementService.CheckAll hook

Clone-replace QuestService to add two things:

### F1 — Add QuestService.SetMetric function

Add this function to QuestService ModuleScript after `QuestService.IncrementMetric`:

```lua
-- For non-cumulative metrics (floors, queen tier, generation) — sets value directly
function QuestService.SetMetric(player: Player, metric: string, value: number): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local metrics = (profile.questMetrics or {}) :: {[string]: number}
    metrics[metric] = value
    profile.questMetrics = metrics
    -- Lazy require to avoid circular dependency
    local AchievementService = require(game:GetService("ServerScriptService").Systems.AchievementService)
    AchievementService.CheckAll(player)
end
```

### F2 — Add AchievementService.CheckAll call inside IncrementMetric

At the end of `QuestService.IncrementMetric`, after the `if changed then QuestSync:FireClient` block,
add a lazy-require CheckAll call:

```lua
-- Check achievements on every metric update
local AchievementService = require(game:GetService("ServerScriptService").Systems.AchievementService)
AchievementService.CheckAll(player)
```

> **Circular dependency note:** Both calls use a local `require()` inside the function body
> (not at module top). Luau's module cache means the second require() call is instantaneous;
> the lazy pattern avoids the circular-require error that would occur if either module tried
> to require the other at load time.

Command Bar to patch QuestService:

```lua
local SSS = game:GetService("ServerScriptService")
local oldQS = SSS.Systems.QuestService
local newQS = oldQS:Clone()
newQS.Name = "QuestService_new"
newQS.Parent = SSS.Systems

local src = oldQS.Source

-- Add SetMetric after IncrementMetric function (find 'end\n\nClaimQuest' pattern)
local setMetricCode = [[

function QuestService.SetMetric(player: Player, metric: string, value: number): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local metrics = (profile.questMetrics or {}) :: {[string]: number}
    metrics[metric] = value
    profile.questMetrics = metrics
    local AchievementService = require(game:GetService("ServerScriptService").Systems.AchievementService)
    AchievementService.CheckAll(player)
end

]]

-- Add CheckAll at end of IncrementMetric (find 'if changed then' block end)
local checkAllCode = [[
    -- Achievements check (lazy require avoids circular dependency)
    local AchievementService = require(game:GetService("ServerScriptService").Systems.AchievementService)
    AchievementService.CheckAll(player)
]]

-- Insert SetMetric before 'ClaimQuest.OnServerEvent'
src = src:gsub("(ClaimQuest%.OnServerEvent)", setMetricCode .. "%1", 1)

-- Insert CheckAll at end of IncrementMetric body (before final 'end' of that function)
-- Find the unique 'if changed then' → 'end\nend\n\nlocal function handleClaim' pattern
src = src:gsub("(if changed then\n%s+QuestSync:FireClient%(player, buildSyncPayload%(player%)%)\n%s+end\nend)", "%1\n" .. checkAllCode, 1)

newQS.Source = src
newQS.Name = "QuestService"
oldQS.Name = "QuestService_old"
oldQS.Parent = nil
print("QuestService patched with SetMetric + AchievementService.CheckAll")
```

**Verify:**
```lua
local src = game:GetService("ServerScriptService").Systems.QuestService.Source
print("SetMetric:", tostring(src:find("SetMetric") ~= nil))
print("CheckAll:", tostring(src:find("AchievementService.CheckAll") ~= nil))
```

---

## STEP G — Additional metric hooks (new metrics not in daily quest catalogue)

These 6 metrics are used by achievements but not by daily quests. Add
`QuestService.SetMetric` or `QuestService.IncrementMetric` calls at the
indicated points. `QuestService` must be required (lazy inside function or at top
of each modified script).

| Service | Event | Function | Metric | Value |
|---------|-------|----------|--------|-------|
| CombService | floor N unlocked (UnlockFloor success) | `SetMetric` | `"floorsUnlocked"` | floor number (2 or 3) |
| QueenService | queen tier advances | `SetMetric` | `"queenTierReached"` | new tier (1–5) |
| SwarmService | performSwarm, after generation increment | `SetMetric` | `"generationReached"` | new generation number |
| ThreatService | Molasses storyline ends (appease or banish) | `IncrementMetric` | `"molassesEnded"` | 1 |
| CosmeticService | skin granted (CheckAndGrantUnlocks success, non-GP) | `IncrementMetric` | `"skinsOwned"` | 1 |
| QuestService | handleClaim: after prog.claimed = true | `IncrementMetric` | `"questsCompleted"` | 1 |

**Example patch for QuestService.handleClaim** (add after `prog.claimed = true`):

```lua
-- Already inside QuestService, so call directly (no require needed)
local metricsTable = (profile.questMetrics or {}) :: {[string]: number}
metricsTable["questsCompleted"] = (metricsTable["questsCompleted"] or 0) + 1
profile.questMetrics = metricsTable
```

(No need to call QuestService.IncrementMetric from inside itself — update the table directly
and let the existing AchievementService.CheckAll call at the end of IncrementMetric handle it
on the next triggered metric.)

---

## STEP H — AchievementController LocalScript

**Location:** `StarterPlayerScripts.AchievementController`  
**Type:** LocalScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local AchievementUnlocked = Remotes:WaitForChild("AchievementUnlocked") :: RemoteEvent
local AchievementSync     = Remotes:WaitForChild("AchievementSync")     :: RemoteEvent

-- Warm Wax palette
local C_BROWN = Color3.fromRGB(122, 74, 34)
local C_GOLD  = Color3.fromRGB(242, 168, 28)
local C_CREAM = Color3.fromRGB(232, 212, 154)
local C_AMBER = Color3.fromRGB(90, 53, 16)

local _unlockedIds: {[string]: boolean} = {}
local _toastActive = false
local _toastQueue: {{label:string, desc:string, icon:string}} = {}

AchievementSync.OnClientEvent:Connect(function(ids: {string})
    for _, id in ids do _unlockedIds[id] = true end
end)

local function showToast(data: {label:string, desc:string, icon:string}): ()
    _toastActive = true

    local gui = Instance.new("ScreenGui")
    gui.Name           = "AchievementToast"
    gui.ResetOnSpawn   = false
    gui.DisplayOrder   = 25
    gui.IgnoreGuiInset = true
    gui.Parent         = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Name                   = "ToastFrame"
    frame.Size                   = UDim2.new(0, 300, 0, 72)
    frame.Position               = UDim2.new(1, 10, 0, 80)  -- starts off-screen right
    frame.AnchorPoint            = Vector2.new(1, 0)
    frame.BackgroundColor3       = C_AMBER
    frame.BackgroundTransparency = 0.08
    frame.Parent                 = gui
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 8)
    fc.Parent = frame
    local fs = Instance.new("UIStroke")
    fs.Color     = C_GOLD
    fs.Thickness = 1.5
    fs.Parent    = frame

    -- Icon box (left side)
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name              = "Icon"
    iconLabel.Size              = UDim2.new(0, 52, 1, -8)
    iconLabel.Position          = UDim2.new(0, 4, 0, 4)
    iconLabel.BackgroundColor3  = C_BROWN
    iconLabel.Text              = data.icon
    iconLabel.Font              = Enum.Font.GothamBold
    iconLabel.TextScaled        = true
    iconLabel.TextColor3        = C_GOLD
    iconLabel.TextXAlignment    = Enum.TextXAlignment.Center
    iconLabel.Parent            = frame
    local ic = Instance.new("UICorner")
    ic.CornerRadius = UDim.new(0, 6)
    ic.Parent = iconLabel

    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name                   = "Title"
    titleLabel.Size                   = UDim2.new(1, -66, 0.45, 0)
    titleLabel.Position               = UDim2.new(0, 62, 0, 4)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font                   = Enum.Font.GothamBold
    titleLabel.TextScaled             = true
    titleLabel.TextColor3             = C_GOLD
    titleLabel.TextXAlignment         = Enum.TextXAlignment.Left
    titleLabel.Text                   = "Achievement: " .. data.label
    titleLabel.Parent                 = frame

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name                   = "Desc"
    descLabel.Size                   = UDim2.new(1, -66, 0.45, 0)
    descLabel.Position               = UDim2.new(0, 62, 0.52, 0)
    descLabel.BackgroundTransparency = 1
    descLabel.Font                   = Enum.Font.Gotham
    descLabel.TextScaled             = true
    descLabel.TextColor3             = C_CREAM
    descLabel.TextXAlignment         = Enum.TextXAlignment.Left
    descLabel.Text                   = data.desc
    descLabel.Parent                 = frame

    -- Slide in from right
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -12, 0, 80)
    }):Play()

    task.wait(4)

    -- Slide out
    TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 10, 0, 80)
    }):Play()
    task.wait(0.35)
    gui:Destroy()

    _toastActive = false

    -- Drain queue
    if #_toastQueue > 0 then
        local next = table.remove(_toastQueue, 1)
        task.spawn(showToast, next)
    end
end

AchievementUnlocked.OnClientEvent:Connect(function(data: {id:string, label:string, desc:string, icon:string})
    _unlockedIds[data.id] = true
    if _toastActive then
        table.insert(_toastQueue, data)
    else
        task.spawn(showToast, data)
    end
end)
```

Create:

```lua
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local ac = Instance.new("LocalScript")
ac.Name = "AchievementController"
ac.Parent = SPS
ac.Source = [[ ... paste full source above ... ]]
print("AchievementController created")
```

---

## STEP I — Verification

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
if ver ~= "16" then table.insert(issues, "WRONG version: expected 16, got " .. tostring(ver)) end
table.insert(results, "migration[11] achievementsUnlocked: " .. tostring(dsSrc:find("achievementsUnlocked") ~= nil))

-- Config
local ok, cfg = pcall(require, RS.Modules.Config)
if ok and cfg.ACHIEVEMENTS then
    local n = #cfg.ACHIEVEMENTS
    table.insert(results, "Config.ACHIEVEMENTS: " .. n .. " entries (expected 20)")
    if n ~= 20 then table.insert(issues, "WRONG count: Config.ACHIEVEMENTS has " .. n .. " entries, expected 20") end
else
    table.insert(issues, "MISSING Config.ACHIEVEMENTS")
end

-- RemoteEvents
local remotes = RS:FindFirstChild("Remotes")
for _, name in {"AchievementUnlocked", "AchievementSync"} do
    local e = remotes and remotes:FindFirstChild(name)
    table.insert(results, name .. ": " .. (e and e.ClassName or "MISSING"))
    if not e then table.insert(issues, "MISSING RemoteEvent: " .. name) end
end

-- Server scripts
local achMod = SSS.Systems and SSS.Systems:FindFirstChild("AchievementService")
table.insert(results, "AchievementService: " .. (achMod and achMod.ClassName or "MISSING"))
if not achMod then table.insert(issues, "MISSING AchievementService ModuleScript") end
if achMod then
    local src = achMod.Source
    for _, pair in {{"--!strict","--!strict"},{"CheckAll","CheckAll function"},{"SyncClient","SyncClient"},{"PlayerAdded","PlayerAdded"}} do
        if not src:find(pair[1]) then table.insert(issues, "MISSING in AchievementService: " .. pair[2]) end
    end
end

local runner = SSS:FindFirstChild("AchievementsRunner")
table.insert(results, "AchievementsRunner: " .. (runner and runner.ClassName or "MISSING"))
if not runner then table.insert(issues, "MISSING AchievementsRunner Script") end

-- QuestService patches
local qsMod = SSS.Systems and SSS.Systems:FindFirstChild("QuestService")
if qsMod then
    local src = qsMod.Source
    table.insert(results, "QuestService.SetMetric: " .. tostring(src:find("SetMetric") ~= nil))
    table.insert(results, "QuestService CheckAll hook: " .. tostring(src:find("AchievementService.CheckAll") ~= nil))
    if not src:find("SetMetric") then table.insert(issues, "MISSING QuestService.SetMetric") end
    if not src:find("AchievementService.CheckAll") then table.insert(issues, "MISSING AchievementService.CheckAll call in QuestService") end
end

-- AchievementController
local ac = SPS:FindFirstChild("AchievementController")
table.insert(results, "AchievementController: " .. (ac and ac.ClassName or "MISSING"))
if not ac then table.insert(issues, "MISSING AchievementController LocalScript") end

local out = table.concat(results, "\n")
if #issues > 0 then
    out = out .. "\n\nISSUES (" .. #issues .. "):\n" .. table.concat(issues, "\n")
else
    out = out .. "\n\nALL CHECKS PASSED"
end
print(out)
```

Expected:

```
DataService version: 16
migration[11] achievementsUnlocked: true
Config.ACHIEVEMENTS: 20 entries
AchievementUnlocked: RemoteEvent
AchievementSync: RemoteEvent
AchievementService: ModuleScript
AchievementsRunner: Script
QuestService.SetMetric: true
QuestService CheckAll hook: true
AchievementController: LocalScript

ALL CHECKS PASSED
```

---

## PART BUDGET NOTE

No new world parts. Running total unchanged at **~4,076/5,000**.
