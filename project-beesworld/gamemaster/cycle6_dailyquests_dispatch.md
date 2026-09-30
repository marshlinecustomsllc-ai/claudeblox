# CYCLE 6 — DAILY QUESTS DISPATCH
## QuestService + QuestController + Daily Quest Widget

**Agents:** luau-scripter, ui-designer  
**Prerequisites:** DataService live, ForagingService/CombService/ResourceService all live  
**Part budget impact:** 0 new parts (UI only — all ScreenGui)  
**Profile fields added:** `questSeed` (integer, daily seed), `questProgress` (table, 3 slots), `questsLastReset` (os.time() unix timestamp)

---

## OVERVIEW

Three daily quests that rotate every 24 hours (server-clock based, not per-player session time). Quests are seeded from the calendar date so all players on the same day get the same 3 quests. Progress is tracked server-side and survives disconnects. Completing a quest awards honey/propolis/pollen. A compact corner widget (bottom-right) shows live progress with claim buttons.

---

## QUEST CATALOGUE

20 quest templates. Each daily rotation picks 3 using a deterministic seed from `os.date("%Y%m%d")`.

```lua
Config.QUEST_CATALOGUE = {
	-- Foraging
	{id="dance_trips_5",   label="Dance 5 Foraging Trips",       metric="danceTrips",      target=5,   reward={honey=200}},
	{id="dance_trips_10",  label="Dance 10 Foraging Trips",      metric="danceTrips",      target=10,  reward={honey=350}},
	{id="harvest_honey",   label="Harvest 500 Honey",            metric="honeyHarvested",   target=500, reward={propolis=8}},
	{id="harvest_big",     label="Harvest 2000 Honey",           metric="honeyHarvested",   target=2000,reward={propolis=20}},
	{id="bloom_rush",      label="Trigger a Bloom Rush",         metric="bloomRushSeen",    target=1,   reward={honey=500,pollen=15}},
	-- Building
	{id="build_cells_3",   label="Build 3 Comb Cells",           metric="cellsBuilt",       target=3,   reward={honey=150}},
	{id="build_cells_8",   label="Build 8 Comb Cells",           metric="cellsBuilt",       target=8,   reward={honey=300,propolis=5}},
	{id="upgrade_cell",    label="Upgrade a Cell to Tier 2",     metric="cellsUpgraded",    target=1,   reward={honey=250}},
	{id="upgrade_cells_3", label="Upgrade 3 Cells to Tier 2+",  metric="cellsUpgraded",    target=3,   reward={honey=500}},
	{id="build_structure", label="Purchase a Structure Upgrade", metric="structuresBought", target=1,   reward={honey=400,pollen=10}},
	-- Economy
	{id="earn_propolis_20",label="Earn 20 Propolis",             metric="propolisEarned",   target=20,  reward={honey=300}},
	{id="earn_pollen_50",  label="Gather 50 Pollen",             metric="pollenGathered",   target=50,  reward={honey=200}},
	{id="spend_honey_1k",  label="Spend 1000 Honey",             metric="honeySpent",       target=1000,reward={pollen=25}},
	-- Defense
	{id="repel_wasp",      label="Repel a Wasp Raid",            metric="waspsRepelled",    target=1,   reward={honey=300,propolis=10}},
	{id="repel_wasps_3",   label="Repel 3 Wasp Raids",          metric="waspsRepelled",    target=3,   reward={honey=600,propolis=20}},
	{id="use_smoker",      label="Use the Smoker",               metric="smokerUses",       target=1,   reward={honey=150}},
	-- Population
	{id="hatch_bees_20",   label="Hatch 20 Bees",               metric="beesHatched",      target=20,  reward={honey=200,pollen=10}},
	{id="hatch_bees_50",   label="Hatch 50 Bees",               metric="beesHatched",      target=50,  reward={honey=400,pollen=20}},
	-- Prestige
	{id="swarm_once",      label="Perform a Swarm",             metric="swarmsPerformed",  target=1,   reward={honey=1000,propolis=50,pollen=50}},
	-- Cosmetics
	{id="change_skin",     label="Equip a Bee Skin",            metric="skinsEquipped",    target=1,   reward={honey=100}},
}
```

---

## LUAU-SCRIPTER TASK

### 1. Config additions

Append to Config:

```lua
Config.QUEST_CATALOGUE = {
	-- (paste full table from catalogue above)
}

Config.DAILY_QUEST = {
	NUM_QUESTS   = 3,           -- quests per rotation
	RESET_HOUR   = 0,           -- UTC hour for daily reset (midnight UTC)
}
```

### 2. DataService migration v6 → v7

Add to MIGRATIONS table:

```lua
[7] = function(profile)
	profile.questSeed        = 0
	profile.questProgress    = {}   -- {[slotIndex] = {id, progress, claimed}}
	profile.questsLastReset  = 0
	-- daily metric counters (reset with quests)
	profile.questMetrics     = {}   -- {[metricName] = number}
end,
```

Set `CURRENT_VERSION = 7`.

---

### 3. QuestService ModuleScript

**Location:** `ServerScriptService.Systems.QuestService`  
**Type:** ModuleScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config      = require(ReplicatedStorage.Modules.Config)
local DataService = require(ServerScriptService.Systems.DataService)

local QuestService = {}

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local QuestSync:    RemoteEvent = Remotes:WaitForChild("QuestSync")
local ClaimQuest:   RemoteEvent = Remotes:WaitForChild("ClaimQuest")

-- Returns midnight UTC timestamp for today
local function todayMidnight(): number
	local t = os.time()
	local d = os.date("!*t", t) :: {year:number,month:number,day:number,hour:number,min:number,sec:number}
	return os.time({year=d.year, month=d.month, day=d.day, hour=0, min=0, sec=0}) - os.time(os.date("*t",0)) + os.time(os.date("!*t",0))
	-- simplified: just use the numeric date as seed
end

-- Deterministic seed from YYYYMMDD
local function dateSeed(): number
	local d = os.date("!%Y%m%d")
	return tonumber(d :: string) :: number
end

-- Pick 3 quests from catalogue using seed (LCG shuffle)
local function pickDailyQuests(seed: number): {{id:string, label:string, metric:string, target:number, reward:{honey:number?,propolis:number?,pollen:number?}}}
	local catalogue = Config.QUEST_CATALOGUE
	local n = #catalogue
	-- Fisher-Yates with LCG
	local indices: {number} = {}
	for i = 1, n do indices[i] = i end
	local rng = seed
	for i = n, 2, -1 do
		rng = (rng * 1664525 + 1013904223) % (2^32)
		local j = (rng % i) + 1
		indices[i], indices[j] = indices[j], indices[i]
	end
	local picked = {}
	for i = 1, Config.DAILY_QUEST.NUM_QUESTS do
		table.insert(picked, catalogue[indices[i]])
	end
	return picked
end

-- Reset a player's quests to today's rotation
local function resetQuests(player: Player): ()
	local profile = DataService.GetProfile(player)
	if not profile then return end

	local seed  = dateSeed()
	local quests = pickDailyQuests(seed)

	profile.questSeed       = seed
	profile.questsLastReset = os.time()
	profile.questProgress   = {}
	profile.questMetrics    = {}

	for i, q in quests do
		profile.questProgress[i] = {id=q.id, progress=0, claimed=false}
	end

	QuestSync:FireClient(player, buildSyncPayload(player))
end

function buildSyncPayload(player: Player): {quests: {any}, metrics: {[string]: number}}
	local profile = DataService.GetProfile(player)
	if not profile then return {quests={}, metrics={}} end

	local seed   = dateSeed()
	local quests = pickDailyQuests(seed)

	local payload = {}
	for i, q in quests do
		local prog = profile.questProgress[i] or {id=q.id, progress=0, claimed=false}
		table.insert(payload, {
			slot    = i,
			id      = q.id,
			label   = q.label,
			target  = q.target,
			reward  = q.reward,
			progress= prog.progress or 0,
			claimed = prog.claimed or false,
		})
	end
	return {quests=payload, metrics=profile.questMetrics or {}}
end

-- Called by game systems to increment a metric for a player
function QuestService.IncrementMetric(player: Player, metric: string, amount: number): ()
	local profile = DataService.GetProfile(player)
	if not profile then return end

	-- Check if today's quests are loaded; reset if stale
	local seed = dateSeed()
	if profile.questSeed ~= seed then
		resetQuests(player)
		return  -- resetQuests fires QuestSync; return to avoid double sync
	end

	-- Update metric counter
	local metrics = profile.questMetrics or {}
	metrics[metric] = (metrics[metric] or 0) + amount
	profile.questMetrics = metrics

	-- Check all quest slots for progress
	local quests = pickDailyQuests(seed)
	local changed = false
	for i, q in quests do
		if q.metric == metric then
			local prog = profile.questProgress[i] or {id=q.id, progress=0, claimed=false}
			if not prog.claimed and prog.progress < q.target then
				prog.progress = math.min(metrics[metric] or 0, q.target)
				profile.questProgress[i] = prog
				changed = true
			end
		end
	end

	if changed then
		QuestSync:FireClient(player, buildSyncPayload(player))
	end
end

-- Claim reward for a completed quest slot
local function handleClaim(player: Player, slot: number): ()
	local profile = DataService.GetProfile(player)
	if not profile then return end

	local seed   = dateSeed()
	local quests = pickDailyQuests(seed)
	local q      = quests[slot]
	if not q then return end

	local prog = profile.questProgress[slot]
	if not prog or prog.claimed then return end
	if prog.progress < q.target then return end

	-- Award reward
	local reward = q.reward
	profile.honey    = (profile.honey    or 0) + (reward.honey    or 0)
	profile.propolis = (profile.propolis or 0) + (reward.propolis or 0)
	profile.pollen   = (profile.pollen   or 0) + (reward.pollen   or 0)

	prog.claimed = true
	profile.questProgress[slot] = prog

	DataService.Save(player)
	QuestSync:FireClient(player, buildSyncPayload(player))
end

ClaimQuest.OnServerEvent:Connect(handleClaim)

-- On player join: reset quests if stale seed
Players.PlayerAdded:Connect(function(player)
	task.wait(3)  -- let DataService load profile
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local seed = dateSeed()
	if profile.questSeed ~= seed then
		resetQuests(player)
	else
		QuestSync:FireClient(player, buildSyncPayload(player))
	end
end)

function QuestService.Start(): ()
	-- No ticker needed: quests reset lazily on first IncrementMetric or join
end

return QuestService
```

---

### 4. QuestRunner Script

**Location:** `ServerScriptService.QuestRunner`  
**Type:** Script

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local QuestService = require(ServerScriptService.Systems.QuestService)
QuestService.Start()
```

---

### 5. New RemoteEvents

Add to `ReplicatedStorage.Remotes`:

| Name | Type | Direction | Payload |
|------|------|-----------|---------|
| QuestSync | RemoteEvent | Server → Client | `{quests: array, metrics: table}` |
| ClaimQuest | RemoteEvent | Client → Server | `slot: number (1–3)` |

---

### 6. Metric hooks in existing services

Add `QuestService.IncrementMetric` calls at the right points. `QuestService` must be required at the top of each modified script.

| Service | Event | Metric | Amount |
|---------|-------|--------|--------|
| DanceService | successful dance trip completes (nectar returned) | `danceTrips` | 1 |
| ResourceService | honey credited to profile | `honeyHarvested` | amount |
| ResourceService | honey debited from profile (spend) | `honeySpent` | amount |
| ResourceService | propolis credited | `propolisEarned` | amount |
| ResourceService | pollen credited | `pollenGathered` | amount |
| CombService | cell built (Build success) | `cellsBuilt` | 1 |
| CombService | cell upgraded (tier ≥ 2) | `cellsUpgraded` | 1 |
| StructureService | structure tier purchased | `structuresBought` | 1 |
| ThreatService | wasp successfully repelled | `waspsRepelled` | 1 |
| ThreatService | smoker used | `smokerUses` | 1 |
| PopulationService | bee hatched | `beesHatched` | 1 |
| SwarmService | swarm performed | `swarmsPerformed` | 1 |
| CosmeticService | skin equipped | `skinsEquipped` | 1 |
| WeatherService | BloomRush state entered | `bloomRushSeen` | 1 (fire for all players) |

**WeatherService note:** BloomRush is server-global. When WeatherService transitions into BloomRush, call `QuestService.IncrementMetric(player, "bloomRushSeen", 1)` for every currently connected player in a loop.

---

### 7. QuestController LocalScript

**Location:** `StarterPlayerScripts.QuestController`  
**Type:** LocalScript  
**Strict:** `--!strict`

Builds and updates the quest widget (bottom-right corner ScreenGui).

```lua
--!strict
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local QuestSync: RemoteEvent  = Remotes:WaitForChild("QuestSync")
local ClaimQuest: RemoteEvent = Remotes:WaitForChild("ClaimQuest")

-- Warm Wax palette
local C_BROWN  = Color3.fromRGB(122, 74, 34)   -- Propolis Brown
local C_GOLD   = Color3.fromRGB(242, 168, 28)  -- Honey Gold
local C_CREAM  = Color3.fromRGB(232, 212, 154) -- Wax Cream
local C_AMBER  = Color3.fromRGB(90, 53, 16)    -- Warm Amber
local C_GREEN  = Color3.fromRGB(88, 164, 72)   -- completion green
local C_GREY   = Color3.fromRGB(80, 60, 40)    -- locked/claimed grey

-- Build the widget lazily on first QuestSync
local widget: ScreenGui?  = nil
local questRows: {Frame} = {}

local function buildWidget(): ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name             = "QuestGui"
	sg.ResetOnSpawn     = false
	sg.DisplayOrder     = 5
	sg.IgnoreGuiInset   = true

	-- Toggle button (bottom-right corner, always visible)
	local toggle = Instance.new("TextButton")
	toggle.Name             = "ToggleBtn"
	toggle.Size             = UDim2.new(0, 44, 0, 44)
	toggle.Position         = UDim2.new(1, -54, 1, -54)
	toggle.AnchorPoint      = Vector2.new(1, 1)
	toggle.BackgroundColor3 = C_BROWN
	toggle.Text             = "📋"
	toggle.TextScaled       = true
	toggle.Font             = Enum.Font.GothamBold
	toggle.TextColor3       = C_CREAM
	toggle.ZIndex           = 10
	Instance.new("UICorner").CornerRadius = UDim.new(0.5,0)
	Instance.new("UICorner").Parent = toggle

	-- Panel (slides up from bottom-right)
	local panel = Instance.new("Frame")
	panel.Name              = "Panel"
	panel.Size              = UDim2.new(0, 280, 0, 0)   -- height grows to 220 when open
	panel.Position          = UDim2.new(1, -54, 1, -110)
	panel.AnchorPoint       = Vector2.new(1, 1)
	panel.BackgroundColor3  = C_AMBER
	panel.BackgroundTransparency = 0.1
	panel.ClipsDescendants  = true
	panel.Visible           = false
	Instance.new("UICorner").CornerRadius = UDim.new(0, 8)
	Instance.new("UICorner").Parent = panel
	Instance.new("UIStroke").Color  = C_GOLD
	Instance.new("UIStroke").Thickness = 1.5
	(Instance.new("UIStroke") :: UIStroke).Parent = panel

	-- Header
	local header = Instance.new("TextLabel")
	header.Name             = "Header"
	header.Size             = UDim2.new(1, 0, 0, 28)
	header.Position         = UDim2.new(0,0,0,0)
	header.BackgroundColor3 = C_BROWN
	header.Text             = "🐝  Daily Quests"
	header.Font             = Enum.Font.GothamBold
	header.TextScaled       = true
	header.TextColor3       = C_GOLD
	header.Parent           = panel
	Instance.new("UICorner").CornerRadius = UDim.new(0,8)
	Instance.new("UICorner").Parent = header

	-- Quest row container
	local list = Instance.new("Frame")
	list.Name               = "QuestList"
	list.Size               = UDim2.new(1, -8, 0, 180)
	list.Position           = UDim2.new(0, 4, 0, 32)
	list.BackgroundTransparency = 1
	list.Parent             = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding          = UDim.new(0, 4)
	layout.Parent           = list

	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Name               = "QuestRow" .. i
		row.Size               = UDim2.new(1, 0, 0, 54)
		row.BackgroundColor3   = C_BROWN
		row.BackgroundTransparency = 0.3
		Instance.new("UICorner").CornerRadius = UDim.new(0,6)
		Instance.new("UICorner").Parent = row

		local label = Instance.new("TextLabel")
		label.Name           = "Label"
		label.Size           = UDim2.new(0.72, 0, 0.5, 0)
		label.Position       = UDim2.new(0, 6, 0, 2)
		label.BackgroundTransparency = 1
		label.Font           = Enum.Font.Gotham
		label.TextScaled     = true
		label.TextColor3     = C_CREAM
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text           = "Loading..."
		label.Parent         = row

		local progressBg = Instance.new("Frame")
		progressBg.Name             = "ProgressBg"
		progressBg.Size             = UDim2.new(0.72, 0, 0.28, 0)
		progressBg.Position         = UDim2.new(0, 6, 0.56, 0)
		progressBg.BackgroundColor3 = C_AMBER
		progressBg.BackgroundTransparency = 0.5
		Instance.new("UICorner").CornerRadius = UDim.new(0.5,0)
		Instance.new("UICorner").Parent = progressBg
		progressBg.Parent = row

		local progressFill = Instance.new("Frame")
		progressFill.Name             = "Fill"
		progressFill.Size             = UDim2.new(0, 0, 1, 0)
		progressFill.BackgroundColor3 = C_GOLD
		progressFill.BorderSizePixel  = 0
		Instance.new("UICorner").CornerRadius = UDim.new(0.5,0)
		Instance.new("UICorner").Parent = progressFill
		progressFill.Parent = progressBg

		local claimBtn = Instance.new("TextButton")
		claimBtn.Name             = "ClaimBtn"
		claimBtn.Size             = UDim2.new(0.24, 0, 0.7, 0)
		claimBtn.Position         = UDim2.new(0.75, 0, 0.15, 0)
		claimBtn.BackgroundColor3 = C_GREEN
		claimBtn.Text             = "Claim"
		claimBtn.Font             = Enum.Font.GothamBold
		claimBtn.TextScaled       = true
		claimBtn.TextColor3       = Color3.new(1,1,1)
		claimBtn.Visible          = false
		Instance.new("UICorner").CornerRadius = UDim.new(0,4)
		Instance.new("UICorner").Parent = claimBtn
		claimBtn.Parent = row

		claimBtn.MouseButton1Click:Connect(function()
			ClaimQuest:FireServer(i)
		end)

		row.Parent = list
		table.insert(questRows, row)
	end

	-- Toggle logic
	local panelOpen = false
	toggle.MouseButton1Click:Connect(function()
		panelOpen = not panelOpen
		panel.Visible = panelOpen
		if panelOpen then
			panel.Size = UDim2.new(0, 280, 0, 0)
			TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size=UDim2.new(0,280,0,220)}):Play()
		else
			TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size=UDim2.new(0,280,0,0)}):Play()
			task.delay(0.2, function() panel.Visible = false end)
		end
	end)

	toggle.Parent = sg
	panel.Parent  = sg
	sg.Parent     = Players.LocalPlayer.PlayerGui
	return sg
end

local function updateRow(row: Frame, data: {label:string, progress:number, target:number, claimed:boolean, reward:{honey:number?,propolis:number?,pollen:number?}}): ()
	local label    = row:FindFirstChild("Label")     :: TextLabel?
	local fill     = row:FindFirstChildWhichIsA("Frame", true) -- ProgressBg > Fill
	local progBg   = row:FindFirstChild("ProgressBg") :: Frame?
	local claimBtn = row:FindFirstChild("ClaimBtn")  :: TextButton?

	if label then
		label.Text = data.label
		if data.claimed then
			label.TextColor3 = C_GREY
		else
			label.TextColor3 = C_CREAM
		end
	end

	if progBg then
		local fillPart = progBg:FindFirstChild("Fill") :: Frame?
		if fillPart then
			local pct = math.clamp(data.progress / math.max(data.target, 1), 0, 1)
			TweenService:Create(fillPart, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
				Size = UDim2.new(pct, 0, 1, 0)
			}):Play()
			fillPart.BackgroundColor3 = data.claimed and C_GREY or C_GOLD
		end
		-- Overlay progress text
		local txt = progBg:FindFirstChild("ProgText") :: TextLabel?
		if not txt then
			txt = Instance.new("TextLabel")
			txt.Name            = "ProgText"
			txt.Size            = UDim2.new(1, 0, 1, 0)
			txt.BackgroundTransparency = 1
			txt.Font            = Enum.Font.GothamBold
			txt.TextScaled      = true
			txt.TextColor3      = C_CREAM
			txt.Parent          = progBg
		end
		txt.Text = data.progress .. " / " .. data.target
	end

	if claimBtn then
		local ready = data.progress >= data.target and not data.claimed
		claimBtn.Visible          = ready
		claimBtn.BackgroundColor3 = ready and C_GREEN or C_GREY

		if data.claimed then
			-- Show claimed state on label area
			if label then label.Text = "✓ " .. data.label end
		end
	end
end

QuestSync.OnClientEvent:Connect(function(payload: {quests: {any}})
	if not widget then widget = buildWidget() end
	for _, qData in payload.quests do
		local row = questRows[qData.slot]
		if row then
			updateRow(row, {
				label    = qData.label,
				progress = qData.progress,
				target   = qData.target,
				claimed  = qData.claimed,
				reward   = qData.reward,
			})
		end
	end
end)
```

---

### 8. Notification toast for quest completion

When a quest's progress reaches its target (detected in `QuestService.IncrementMetric` before the claim), fire the existing `Notify` RemoteEvent to the player with a message like:

```
"Quest complete: Dance 5 Foraging Trips — tap 📋 to claim your reward!"
```

Add this inside `QuestService.IncrementMetric` after `changed = true` is set, checking if any slot just reached its target:

```lua
-- inside the changed block, after setting progress:
if prog.progress >= q.target and not prog.claimed then
	local notifyRemote = ReplicatedStorage.Remotes:FindFirstChild("Notify") :: RemoteEvent?
	if notifyRemote then
		notifyRemote:FireClient(player, "Quest complete: " .. q.label .. " — tap 📋 to claim!")
	end
end
```

---

## VERIFICATION SCRIPT

Run in Studio Command Bar after both tasks complete:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local results = {}
local issues  = {}

-- 1. QuestService
local qsMod = SSS.Systems:FindFirstChild("QuestService")
if qsMod and qsMod:IsA("ModuleScript") then
	local lines = select(2, qsMod.Source:gsub("\n","\n")) + 1
	table.insert(results, "PASS: QuestService ModuleScript (" .. lines .. " lines)")
else
	table.insert(issues, "FAIL: QuestService missing from SSS.Systems")
end

-- 2. QuestRunner
local runner = SSS:FindFirstChild("QuestRunner")
if runner and runner:IsA("Script") then
	table.insert(results, "PASS: QuestRunner Script exists")
else
	table.insert(issues, "FAIL: QuestRunner missing from SSS")
end

-- 3. RemoteEvents
for _, name in {"QuestSync", "ClaimQuest"} do
	local r = RS.Remotes:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		table.insert(results, "PASS: " .. name .. " RemoteEvent")
	else
		table.insert(issues, "FAIL: " .. name .. " RemoteEvent missing")
	end
end

-- 4. QuestController
local ctrl = SPS and SPS:FindFirstChild("QuestController")
if ctrl and ctrl:IsA("LocalScript") then
	local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
	table.insert(results, "PASS: QuestController LocalScript (" .. lines .. " lines)")
else
	table.insert(issues, "FAIL: QuestController missing from StarterPlayerScripts")
end

-- 5. Config.QUEST_CATALOGUE
local ok, Config = pcall(require, RS.Modules.Config)
if ok and Config.QUEST_CATALOGUE then
	table.insert(results, "PASS: Config.QUEST_CATALOGUE (" .. #Config.QUEST_CATALOGUE .. " quests)")
	if #Config.QUEST_CATALOGUE < 15 then
		table.insert(issues, "WARN: QUEST_CATALOGUE has fewer than 15 entries (expected 20)")
	end
else
	table.insert(issues, "FAIL: Config.QUEST_CATALOGUE missing")
end

-- 6. DataService v7 migration check
if ok and Config.CURRENT_VERSION then
	if Config.CURRENT_VERSION >= 7 then
		table.insert(results, "PASS: DataService CURRENT_VERSION=" .. Config.CURRENT_VERSION)
	else
		table.insert(issues, "FAIL: CURRENT_VERSION=" .. Config.CURRENT_VERSION .. " (expected ≥7)")
	end
end

-- 7. Metric hooks spot check (look for QuestService.IncrementMetric in ResourceService)
local resSvc = SSS.Systems:FindFirstChild("ResourceService")
if resSvc and resSvc:IsA("ModuleScript") then
	if resSvc.Source:find("QuestService") then
		table.insert(results, "PASS: ResourceService references QuestService")
	else
		table.insert(issues, "WARN: ResourceService may not have QuestService metric hooks")
	end
end

-- Summary
print("=== DAILY QUESTS VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
	print("\n--- ISSUES ---")
	for _, iss in issues do print(iss) end
	print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
	print("\nSTATUS: ALL CHECKS PASS — daily quests system ready")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| Config.QUEST_CATALOGUE + Config.DAILY_QUEST | Config addition | ReplicatedStorage.Modules.Config |
| DataService v6→v7 migration | Edit | SSS.Systems.DataService |
| QuestService | ModuleScript | SSS.Systems.QuestService |
| QuestRunner | Script | SSS.QuestRunner |
| QuestSync | RemoteEvent | ReplicatedStorage.Remotes |
| ClaimQuest | RemoteEvent | ReplicatedStorage.Remotes |
| Metric hooks (14 call sites) | Edits | 9 existing services |
| QuestController | LocalScript | StarterPlayerScripts |

**Part budget delta:** 0 new parts (ScreenGui only) → ~3,768 / 5,000 total unchanged.

**Daily reset behaviour:** Quests reset lazily — on next `IncrementMetric` call or reconnect after midnight UTC. No background timer needed server-side. The seed is the numeric date (`20261001`) so all players on the same server day get identical quests regardless of when they joined.
