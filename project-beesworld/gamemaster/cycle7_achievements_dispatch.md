# CYCLE 7 — ACHIEVEMENTS DISPATCH
## AchievementService + Badge Notification Widget

**Agent:** luau-scripter  
**Prerequisites:** DataService live, QuestService metric hooks wired (cycle6_dailyquests adds the increment infrastructure this reuses), WeatherService live  
**Part budget impact:** 0 new parts (UI only)  
**Profile fields added:** `achievementsUnlocked` (array of string IDs), appended to DataService v7→v8 migration

---

## OVERVIEW

20 achievements tied to the emotional journey. They use the **same metric increment system as daily quests** — `AchievementService.CheckAll(player)` is called from the existing `QuestService.IncrementMetric` hook, so no new hook plumbing is needed. A badge toast appears at the top-right corner when an achievement is earned, then slides off. Achievements are permanent (never reset, survive swarms).

---

## ACHIEVEMENT CATALOGUE

```lua
Config.ACHIEVEMENTS = {
	-- First steps
	{id="first_cell",       label="First Cell",          desc="Build your first comb cell.",                   metric="cellsBuilt",       threshold=1,    icon="🐝"},
	{id="first_dance",      label="Follow the Waggle",   desc="Complete your first waggle dance.",             metric="danceTrips",        threshold=1,    icon="💃"},
	{id="first_harvest",    label="Golden Haul",          desc="Harvest honey for the first time.",             metric="honeyHarvested",    threshold=1,    icon="🍯"},
	{id="first_repel",      label="Stand Your Ground",   desc="Repel a wasp raid.",                            metric="waspsRepelled",     threshold=1,    icon="🛡️"},

	-- Progress milestones
	{id="cells_25",         label="Hex Architect",        desc="Build 25 comb cells.",                          metric="cellsBuilt",        threshold=25,   icon="🔷"},
	{id="cells_100",        label="Master Builder",       desc="Build 100 comb cells.",                         metric="cellsBuilt",        threshold=100,  icon="🏗️"},
	{id="honey_10k",        label="Honey Hoard",          desc="Harvest 10,000 honey in total.",                metric="honeyHarvested",    threshold=10000,icon="✨"},
	{id="honey_100k",       label="The Golden River",     desc="Harvest 100,000 honey in total.",               metric="honeyHarvested",    threshold=100000,icon="🌊"},
	{id="dances_50",        label="Dance Master",         desc="Complete 50 waggle dances.",                    metric="danceTrips",        threshold=50,   icon="🎭"},
	{id="wasps_10",         label="Guardian of the Hive", desc="Repel 10 wasp raids.",                          metric="waspsRepelled",     threshold=10,   icon="⚔️"},

	-- System unlocks
	{id="floor_2",          label="Going Up",             desc="Unlock Floor 2.",                               metric="floorsUnlocked",    threshold=2,    icon="🏢"},
	{id="floor_3",          label="Sky Hive",             desc="Unlock Floor 3.",                               metric="floorsUnlocked",    threshold=3,    icon="🌤️"},
	{id="queen_tier3",      label="Queen Crowned",        desc="Reach Queen Tier 3.",                           metric="queenTierReached",  threshold=3,    icon="👑"},
	{id="bloom_rush_3",     label="Storm Chaser",         desc="Witness 3 Bloom Rush events.",                  metric="bloomRushSeen",     threshold=3,    icon="🌸"},
	{id="structure_all",    label="Full Apiary",          desc="Purchase every structure upgrade.",             metric="structuresBought",  threshold=8,    icon="🏛️"},

	-- Prestige / late game
	{id="first_swarm",      label="Born Again",           desc="Perform your first Swarm.",                     metric="swarmsPerformed",   threshold=1,    icon="🌀"},
	{id="gen_3",            label="Dynasty",              desc="Reach Generation 3.",                           metric="generationReached", threshold=3,    icon="📜"},
	{id="molasses_end",     label="Bear Proof",           desc="Complete the Molasses storyline.",              metric="molassesEnded",     threshold=1,    icon="🐻"},
	{id="all_skins",        label="Wardrobe Complete",    desc="Unlock all 7 bee skins.",                       metric="skinsOwned",        threshold=7,    icon="🎨"},

	-- Daily quest milestone
	{id="quests_25",        label="Diligent Beekeeper",  desc="Complete 25 daily quests.",                     metric="questsCompleted",   threshold=25,   icon="📋"},
}
```

---

## LUAU-SCRIPTER TASK

### 1. Config addition

Append to Config:

```lua
Config.ACHIEVEMENTS = {
	-- (paste full catalogue above)
}
```

---

### 2. DataService migration v7 → v8

Add to MIGRATIONS:

```lua
[8] = function(profile)
	profile.achievementsUnlocked = {}   -- array of achievement id strings
	-- Additional per-achievement metrics not already in questMetrics:
	profile.questMetrics = profile.questMetrics or {}
	-- floorsUnlocked, queenTierReached, generationReached, molassesEnded, skinsOwned, questsCompleted
	-- are maintained by existing systems; AchievementService reads them from questMetrics
end,
```

Set `CURRENT_VERSION = 8`.

---

### 3. Metric additions to existing services

These metrics are new to the achievement system (not in the daily quest catalogue). Add `QuestService.IncrementMetric` calls (which also routes to `AchievementService.CheckAll`):

| Service | Event | Metric | Amount |
|---------|-------|--------|--------|
| CombService / UnlockFloor | Floor 2 unlocked | `floorsUnlocked` | set to 2 |
| CombService / UnlockFloor | Floor 3 unlocked | `floorsUnlocked` | set to 3 |
| QueenService | queen tier advances | `queenTierReached` | new tier value (overwrite, not add) |
| SwarmService | swarm complete | `generationReached` | new generation value |
| ThreatService | Molasses storyline ends | `molassesEnded` | 1 |
| CosmeticService | skin granted | `skinsOwned` | 1 (cumulative count) |
| QuestService | quest claim succeeds | `questsCompleted` | 1 |

> **Note:** `floorsUnlocked`, `queenTierReached`, `generationReached` are not cumulative additive — they represent the current maximum. AchievementService compares `questMetrics[metric] >= threshold`. So for floors, call `IncrementMetric(player, "floorsUnlocked", 0)` and then directly set `profile.questMetrics["floorsUnlocked"] = floorNumber` before calling `AchievementService.CheckAll`. Or simply use a dedicated setter in QuestService:

```lua
function QuestService.SetMetric(player: Player, metric: string, value: number): ()
	local profile = DataService.GetProfile(player)
	if not profile then return end
	profile.questMetrics = profile.questMetrics or {}
	profile.questMetrics[metric] = value
	AchievementService.CheckAll(player)
end
```

Use `SetMetric` for floor/queen/generation metrics; `IncrementMetric` for everything else.

---

### 4. AchievementService ModuleScript

**Location:** `ServerScriptService.Systems.AchievementService`  
**Type:** ModuleScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config      = require(ReplicatedStorage.Modules.Config)
local DataService = require(ServerScriptService.Systems.DataService)

local AchievementService = {}

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local AchievementUnlocked: RemoteEvent = Remotes:WaitForChild("AchievementUnlocked")

-- Check all achievements for a player; fire newly earned ones
function AchievementService.CheckAll(player: Player): ()
	local profile = DataService.GetProfile(player)
	if not profile then return end

	local unlocked = profile.achievementsUnlocked or {}
	local metrics  = profile.questMetrics or {}

	-- Build fast lookup set
	local unlockedSet: {[string]: boolean} = {}
	for _, id in unlocked do unlockedSet[id] = true end

	local newlyEarned: {string} = {}
	for _, ach in Config.ACHIEVEMENTS do
		if not unlockedSet[ach.id] then
			local current = metrics[ach.metric] or 0
			if current >= ach.threshold then
				table.insert(unlocked, ach.id)
				unlockedSet[ach.id] = true
				table.insert(newlyEarned, ach.id)
			end
		end
	end

	if #newlyEarned > 0 then
		profile.achievementsUnlocked = unlocked
		DataService.Save(player)

		for _, id in newlyEarned do
			-- Find achievement data
			for _, ach in Config.ACHIEVEMENTS do
				if ach.id == id then
					AchievementUnlocked:FireClient(player, {
						id    = ach.id,
						label = ach.label,
						desc  = ach.desc,
						icon  = ach.icon,
					})
					break
				end
			end
		end
	end
end

-- Send current unlocked state to client on join
function AchievementService.SyncClient(player: Player): ()
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local Remotes2 = ReplicatedStorage.Remotes
	local sync: RemoteEvent? = Remotes2:FindFirstChild("AchievementSync") :: RemoteEvent?
	if sync then
		sync:FireClient(player, profile.achievementsUnlocked or {})
	end
end

Players.PlayerAdded:Connect(function(player)
	task.wait(4)
	AchievementService.SyncClient(player)
end)

return AchievementService
```

---

### 5. AchievementsRunner Script

**Location:** `ServerScriptService.AchievementsRunner`  
**Type:** Script

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
require(ServerScriptService.Systems.AchievementService)
-- Module self-connects on require; no Start() needed
```

---

### 6. New RemoteEvents

Add to `ReplicatedStorage.Remotes`:

| Name | Direction | Payload |
|------|-----------|---------|
| AchievementUnlocked | Server → Client | `{id, label, desc, icon}` |
| AchievementSync | Server → Client | `unlockedIds: {string}` |

---

### 7. AchievementController LocalScript

**Location:** `StarterPlayerScripts.AchievementController`  
**Type:** LocalScript  
**Strict:** `--!strict`

Shows a badge toast at the top-right when an achievement is earned. Also maintains a local unlocked set (used by WardrobeGui to show "earn this skin" tooltips — future use).

```lua
--!strict
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local AchievementUnlocked = Remotes:WaitForChild("AchievementUnlocked") :: RemoteEvent
local AchievementSync     = Remotes:WaitForChild("AchievementSync")     :: RemoteEvent

local player = Players.LocalPlayer

-- Warm Wax palette
local C_BROWN  = Color3.fromRGB(122, 74, 34)
local C_GOLD   = Color3.fromRGB(242, 168, 28)
local C_CREAM  = Color3.fromRGB(232, 212, 154)
local C_AMBER  = Color3.fromRGB(90, 53, 16)

-- Local unlocked set (populated by AchievementSync)
local _unlockedIds: {[string]: boolean} = {}

AchievementSync.OnClientEvent:Connect(function(ids: {string})
	for _, id in ids do _unlockedIds[id] = true end
end)

-- Toast queue
local _toastActive  = false
local _toastQueue: {{label:string, desc:string, icon:string}} = {}

local function showToast(data: {label:string, desc:string, icon:string}): ()
	_toastActive = true

	local gui = Instance.new("ScreenGui")
	gui.Name           = "AchievementToast_" .. data.label
	gui.ResetOnSpawn   = false
	gui.DisplayOrder   = 25
	gui.IgnoreGuiInset = true
	gui.Parent         = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name             = "ToastFrame"
	frame.Size             = UDim2.new(0, 300, 0, 72)
	frame.Position         = UDim2.new(1, 10, 0, 80)  -- starts off-screen right
	frame.AnchorPoint      = Vector2.new(1, 0)
	frame.BackgroundColor3 = C_AMBER
	frame.BackgroundTransparency = 0.08
	Instance.new("UICorner").CornerRadius = UDim.new(0, 8)
	Instance.new("UICorner").Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color     = C_GOLD
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	-- Icon
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
	Instance.new("UICorner").CornerRadius = UDim.new(0, 6)
	Instance.new("UICorner").Parent = iconLabel
	iconLabel.Parent = frame

	-- Label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name             = "Title"
	titleLabel.Size             = UDim2.new(1, -66, 0.45, 0)
	titleLabel.Position         = UDim2.new(0, 62, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font             = Enum.Font.GothamBold
	titleLabel.TextScaled       = true
	titleLabel.TextColor3       = C_GOLD
	titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
	titleLabel.Text             = "Achievement: " .. data.label
	titleLabel.Parent           = frame

	local descLabel = Instance.new("TextLabel")
	descLabel.Name              = "Desc"
	descLabel.Size              = UDim2.new(1, -66, 0.45, 0)
	descLabel.Position          = UDim2.new(0, 62, 0.52, 0)
	descLabel.BackgroundTransparency = 1
	descLabel.Font              = Enum.Font.Gotham
	descLabel.TextScaled        = true
	descLabel.TextColor3        = C_CREAM
	descLabel.TextXAlignment    = Enum.TextXAlignment.Left
	descLabel.Text              = data.desc
	descLabel.Parent            = frame

	frame.Parent = gui

	-- Slide in
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

	-- Process queue
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

---

### 8. Call AchievementService.CheckAll from QuestService

In `QuestService.IncrementMetric`, after the `changed` block, add:

```lua
-- Check achievements (re-require to avoid circular dependency if needed)
local AchievementService = require(ServerScriptService.Systems.AchievementService)
AchievementService.CheckAll(player)
```

Also add the same call inside `QuestService.SetMetric` (which is called for floor/queen/generation metrics).

> **Circular dependency note:** If QuestService and AchievementService form a cycle, require AchievementService lazily inside the function body rather than at module top.

---

## VERIFICATION SCRIPT

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local results = {}
local issues  = {}

-- 1. AchievementService
local mod = SSS.Systems:FindFirstChild("AchievementService")
if mod and mod:IsA("ModuleScript") then
	local lines = select(2, mod.Source:gsub("\n","\n")) + 1
	table.insert(results, "PASS: AchievementService ModuleScript (" .. lines .. " lines)")
else
	table.insert(issues, "FAIL: AchievementService missing from SSS.Systems")
end

-- 2. AchievementsRunner
local runner = SSS:FindFirstChild("AchievementsRunner")
if runner and runner:IsA("Script") then
	table.insert(results, "PASS: AchievementsRunner Script exists")
else
	table.insert(issues, "FAIL: AchievementsRunner missing from SSS")
end

-- 3. RemoteEvents
for _, name in {"AchievementUnlocked", "AchievementSync"} do
	local r = RS.Remotes:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		table.insert(results, "PASS: " .. name .. " RemoteEvent")
	else
		table.insert(issues, "FAIL: " .. name .. " RemoteEvent missing")
	end
end

-- 4. AchievementController LocalScript
local ctrl = SPS and SPS:FindFirstChild("AchievementController")
if ctrl and ctrl:IsA("LocalScript") then
	local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
	table.insert(results, "PASS: AchievementController LocalScript (" .. lines .. " lines)")
else
	table.insert(issues, "FAIL: AchievementController missing from StarterPlayerScripts")
end

-- 5. Config.ACHIEVEMENTS
local ok, Config = pcall(require, RS.Modules.Config)
if ok and Config.ACHIEVEMENTS then
	table.insert(results, "PASS: Config.ACHIEVEMENTS (" .. #Config.ACHIEVEMENTS .. " achievements)")
	if #Config.ACHIEVEMENTS < 20 then
		table.insert(issues, "WARN: ACHIEVEMENTS has fewer than 20 entries")
	end
else
	table.insert(issues, "FAIL: Config.ACHIEVEMENTS missing")
end

-- 6. DataService v8
if ok and Config.CURRENT_VERSION then
	if Config.CURRENT_VERSION >= 8 then
		table.insert(results, "PASS: DataService CURRENT_VERSION=" .. Config.CURRENT_VERSION)
	else
		table.insert(issues, "FAIL: CURRENT_VERSION=" .. Config.CURRENT_VERSION .. " (expected ≥8)")
	end
end

-- 7. QuestService calls CheckAll (spot check)
local qsMod = SSS.Systems:FindFirstChild("QuestService")
if qsMod and qsMod:IsA("ModuleScript") then
	if qsMod.Source:find("AchievementService") then
		table.insert(results, "PASS: QuestService references AchievementService")
	else
		table.insert(issues, "WARN: QuestService may not call AchievementService.CheckAll")
	end
end

-- Summary
print("=== ACHIEVEMENTS VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
	print("\n--- ISSUES ---")
	for _, iss in issues do print(iss) end
	print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
	print("\nSTATUS: ALL CHECKS PASS — achievements system ready")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| Config.ACHIEVEMENTS (20 entries) | Config addition | ReplicatedStorage.Modules.Config |
| DataService v7→v8 migration | Edit | SSS.Systems.DataService |
| AchievementService | ModuleScript | SSS.Systems.AchievementService |
| AchievementsRunner | Script | SSS.AchievementsRunner |
| AchievementUnlocked | RemoteEvent | ReplicatedStorage.Remotes |
| AchievementSync | RemoteEvent | ReplicatedStorage.Remotes |
| QuestService.SetMetric | New function | SSS.Systems.QuestService |
| AchievementService.CheckAll calls | Edits | QuestService IncrementMetric + SetMetric |
| AchievementController | LocalScript | StarterPlayerScripts |
| Metric additions (7 new call sites) | Edits | CombService/QueenService/SwarmService/ThreatService/CosmeticService/QuestService |

**Part budget delta:** 0 new parts → ~3,786 / 5,000 total unchanged.

**Achievement persistence:** Unlocks survive swarms (stored in `achievementsUnlocked` which is not touched by SwarmService.performSwarm reset). Permanently tied to the player account via DataService.
