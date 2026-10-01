# Dispatch 62 — AchievementService
## Cycle 11 · A Bee's World

**Feature:** Achievement system — 12 milestone achievements with honey/propolis rewards. Server-side unlock tracking in DataStore profile. Client-side toast pop with gold border. Achievements fire from existing services at their natural unlock moments.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 61 (PropolisStorageUpgradeService)

---

## ACHIEVEMENTS TABLE

| ID | Name | Condition | Reward |
|----|------|-----------|--------|
| `first_honey` | First Drop | Earn any honey | 50 honey |
| `honey_100` | Century | Accumulate 100 honey lifetime | 100 honey |
| `honey_1000` | Hoarder | 1,000 honey lifetime | 500 honey |
| `honey_10000` | Nectar Baron | 10,000 honey lifetime | 2,000 honey |
| `first_upgrade` | Improver | Buy first upgrade (any track) | 200 honey |
| `all_plots` | Full Apiary | Unlock all 8 plots | 3,000 honey |
| `first_gen` | New Generation | Reach Prestige tier 1 | 1,000 honey + 50 propolis |
| `gen_5` | Dynasty | Reach Prestige tier 5 | 5,000 honey + 200 propolis |
| `daily_streak_3` | Dedicated | 3-day login streak | 300 honey |
| `daily_streak_7` | Committed | 7-day login streak (full cycle) | 1,500 honey + 30 propolis |
| `first_skin` | Decorator | Buy first non-default skin | 500 honey |
| `max_bees` | Queen's Army | Reach max queen upgrade (tier 5) | 2,500 honey |

Achievements are one-shot — each fires only once per player per lifetime.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | `ACHIEVEMENTS` table |
| `DataService` | `unlockedAchievements = {}` migration |
| `AchievementService` (new Script in SSS) | Check(), Init(), AchievementUnlocked RE |
| `ForagingService` | fire honey milestones |
| `DailyRewardService` | fire streak achievements |
| `HiveSkinService` | fire first_skin |
| `QueenUpgradeService` | fire max_bees |
| `PrestigeService` | fire first_gen, gen_5 (already has lazy require stub) |
| `PlotService` | fire all_plots |
| `GameManager` | Init call |
| `AchievementController` (new LocalScript) | toast display |

---

## STEP A — Config

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local clone = cfg:Clone()
clone.Name = "Config_WORKING"

local anchor = 'PROPOLIS_STORAGE_MAX_TIER'
local found = clone.Source:find(anchor, 1, true)
assert(found, "PROPOLIS_STORAGE_MAX_TIER anchor not found")
local lineEnd = clone.Source:find("\n", found, true)

local INJECT = [[

-- Achievements
Config.ACHIEVEMENTS = {
	{id="first_honey",    name="First Drop",      desc="Earn your first honey",                  honeyReward=50,   propolisReward=0  },
	{id="honey_100",      name="Century",          desc="Accumulate 100 honey lifetime",           honeyReward=100,  propolisReward=0  },
	{id="honey_1000",     name="Hoarder",          desc="Accumulate 1,000 honey lifetime",         honeyReward=500,  propolisReward=0  },
	{id="honey_10000",    name="Nectar Baron",     desc="Accumulate 10,000 honey lifetime",        honeyReward=2000, propolisReward=0  },
	{id="first_upgrade",  name="Improver",         desc="Purchase your first upgrade",             honeyReward=200,  propolisReward=0  },
	{id="all_plots",      name="Full Apiary",      desc="Unlock all 8 plots",                      honeyReward=3000, propolisReward=0  },
	{id="first_gen",      name="New Generation",   desc="Reach Prestige tier 1",                   honeyReward=1000, propolisReward=50 },
	{id="gen_5",          name="Dynasty",          desc="Reach Prestige tier 5",                   honeyReward=5000, propolisReward=200},
	{id="daily_streak_3", name="Dedicated",        desc="Reach a 3-day login streak",              honeyReward=300,  propolisReward=0  },
	{id="daily_streak_7", name="Committed",        desc="Complete a full 7-day login streak",      honeyReward=1500, propolisReward=30 },
	{id="first_skin",     name="Decorator",        desc="Purchase a hive skin",                    honeyReward=500,  propolisReward=0  },
	{id="max_bees",       name="Queen's Army",     desc="Reach max Queen upgrade (tier 5)",        honeyReward=2500, propolisReward=0  },
}
]]

clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config ACHIEVEMENTS added")
```

---

## STEP B — DataService migration

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

local anchor = 'propolisStorageTier = 0'
local found = clone.Source:find(anchor, 1, true)
assert(found, "propolisStorageTier anchor not found")

local lineEnd = clone.Source:find("\n", found, true)
local INJECT = "\n\t\tunlockedAchievements = {},   -- array of achievement id strings\n\t\tlifetimeHoney = 0,           -- cumulative honey ever earned (for milestones)"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService achievement fields added")
```

---

## STEP C — AchievementService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local AchievementUnlocked = Instance.new("RemoteEvent")
AchievementUnlocked.Name = "AchievementUnlocked"
AchievementUnlocked.Parent = RS

local svc = Instance.new("Script")
svc.Name = "AchievementService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- AchievementService
-- One-shot achievement unlocks with honey/propolis rewards.
-- Other services call AchievementService.Check(player, id) at natural trigger moments.

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local PS  = game:GetService("Players")

local Config      = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local AchievementUnlocked = RS:WaitForChild("AchievementUnlocked")

local AchievementService = {}

local function findDef(id: string): {id: string, name: string, desc: string, honeyReward: number, propolisReward: number}?
	for _, a in Config.ACHIEVEMENTS do
		if a.id == id then return a end
	end
	return nil
end

local function hasUnlocked(profile: any, id: string): boolean
	local list = profile.unlockedAchievements
	if type(list) ~= "table" then return false end
	for _, v in list do
		if v == id then return true end
	end
	return false
end

-- Grant achievement and reward. Thread-safe (single server).
local function grant(player: Player, id: string)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	if hasUnlocked(profile, id) then return end

	local def = findDef(id)
	if not def then return end

	-- Record unlock
	if type(profile.unlockedAchievements) ~= "table" then
		profile.unlockedAchievements = {}
	end
	table.insert(profile.unlockedAchievements, id)

	-- Apply rewards
	profile.honey = (profile.honey or 0) + def.honeyReward
	if def.propolisReward > 0 then
		local maxP = Config.PROPOLIS_STORAGE_BASE_MAX  -- safe default; real cap via service when available
		local ok2, psvc = pcall(function()
			return require(SSS:WaitForChild("PropolisStorageUpgradeService", 5))
		end)
		if ok2 and psvc then maxP = psvc.GetMaxPropolis(player) end
		profile.propolis = math.min((profile.propolis or 0) + def.propolisReward, maxP)
	end

	-- Sync HUD
	local HoneySync = RS:FindFirstChild("HoneySync")
	if HoneySync then HoneySync:FireClient(player, profile.honey) end

	-- Notify client
	AchievementUnlocked:FireClient(player, {
		id       = def.id,
		name     = def.name,
		desc     = def.desc,
		honeyReward    = def.honeyReward,
		propolisReward = def.propolisReward,
	})

	print(string.format("[AchievementService] %s unlocked '%s' (+%d honey, +%d propolis)",
		player.Name, def.name, def.honeyReward, def.propolisReward))
end

-- Public API: called by other services
function AchievementService.Check(player: Player, id: string)
	task.spawn(grant, player, id)
end

-- Check honey milestone achievements (called by ForagingService after yield)
function AchievementService.CheckHoneyMilestones(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local lt = profile.lifetimeHoney or 0
	if lt > 0   then AchievementService.Check(player, "first_honey") end
	if lt >= 100  then AchievementService.Check(player, "honey_100") end
	if lt >= 1000 then AchievementService.Check(player, "honey_1000") end
	if lt >= 10000 then AchievementService.Check(player, "honey_10000") end
end

function AchievementService.Init()
	print("[AchievementService] ready")
end

return AchievementService
]]

print("AchievementService created")
```

---

## STEP D — ForagingService: lifetime honey tracking + milestone check

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- 1. Add require after PropolisStorageUpgradeService require
local reqAnchor = 'local PropolisStorageUpgradeService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "PropolisStorageUpgradeService require not found")
local lineEnd = clone.Source:find("\n", found, true)
local INJECT_REQ = "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_REQ .. clone.Source:sub(lineEnd + 1)

-- 2. After honey cap enforcement, add lifetime tracking + milestone check
local capAnchor = 'if profile.honey > maxHoney then profile.honey = maxHoney end'
local found2 = clone.Source:find(capAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	local INJECT_TRACK = [[

	-- Track lifetime honey for achievements
	profile.lifetimeHoney = (profile.lifetimeHoney or 0) + honeyYield
	AchievementService.CheckHoneyMilestones(player)]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT_TRACK .. clone.Source:sub(lineEnd2 + 1)
	print("Lifetime honey tracking injected")
else
	print("WARNING: honey cap anchor not found — add lifetime tracking manually")
end

-- 3. Check first_upgrade on any upgrade purchase
-- ForagingService may not handle upgrades directly; this fires from upgrade services instead.
-- Nothing to inject here for that — handled in Step E.

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService achievement hooks applied")
```

---

## STEP E — Inject achievement checks into upgrade/service scripts

Each service fires AchievementService.Check at its natural moment.

### E1 — DailyRewardService: streak achievements

```lua
local SSS = game:GetService("ServerScriptService")
local dr = SSS:FindFirstChild("DailyRewardService")
assert(dr, "DailyRewardService not found")

local clone = dr:Clone()
clone.Name = "DailyRewardService_WORKING"

-- Add require after DataService require
local reqAnchor = 'local DataService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "DataService require not found in DailyRewardService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))" .. clone.Source:sub(lineEnd + 1)

-- After streak increment, check streak achievements
local streakAnchor = 'profile.dailyStreak'
local found2 = clone.Source:find(streakAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	local INJECT = [[

	-- Achievement checks
	if profile.dailyStreak >= 3 then AchievementService.Check(player, "daily_streak_3") end
	if profile.dailyStreak >= 7 then AchievementService.Check(player, "daily_streak_7") end]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT .. clone.Source:sub(lineEnd2 + 1)
	print("DailyRewardService streak achievement hooks injected")
else
	print("WARNING: dailyStreak anchor not found — add manually")
end

dr.Name = "DailyRewardService_OLD_NX"
dr.Parent = nil
clone.Name = "DailyRewardService"
clone.Parent = SSS

print("DailyRewardService patch applied")
```

### E2 — HiveSkinService: first_skin

```lua
local SSS = game:GetService("ServerScriptService")
local hs = SSS:FindFirstChild("HiveSkinService")
assert(hs, "HiveSkinService not found")

local clone = hs:Clone()
clone.Name = "HiveSkinService_WORKING"

local reqAnchor = 'local DataService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "DataService require not found in HiveSkinService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))" .. clone.Source:sub(lineEnd + 1)

-- After skin purchase success (after table.insert to unlockedSkins)
local buyAnchor = 'table.insert(profile.unlockedSkins'
local found2 = clone.Source:find(buyAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	clone.Source = clone.Source:sub(1, lineEnd2) .. "\n\tAchievementService.Check(player, \"first_skin\")" .. clone.Source:sub(lineEnd2 + 1)
	print("HiveSkinService first_skin hook injected")
else
	print("WARNING: unlockedSkins insert not found — add first_skin check manually")
end

hs.Name = "HiveSkinService_OLD_NX"
hs.Parent = nil
clone.Name = "HiveSkinService"
clone.Parent = SSS

print("HiveSkinService patch applied")
```

### E3 — QueenUpgradeService: max_bees + first_upgrade

```lua
local SSS = game:GetService("ServerScriptService")
local qu = SSS:FindFirstChild("QueenUpgradeService")
assert(qu, "QueenUpgradeService not found")

local clone = qu:Clone()
clone.Name = "QueenUpgradeService_WORKING"

local reqAnchor = 'local DataService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "DataService require not found in QueenUpgradeService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))" .. clone.Source:sub(lineEnd + 1)

-- After tier increment in BuyQueenTier
local tierAnchor = 'profile.queenTier'
local found2 = clone.Source:find(tierAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	local INJECT = [[

	AchievementService.Check(player, "first_upgrade")
	if profile.queenTier >= Config.QUEEN_UPGRADE_MAX_TIER then
		AchievementService.Check(player, "max_bees")
	end]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT .. clone.Source:sub(lineEnd2 + 1)
	print("QueenUpgradeService achievement hooks injected")
else
	print("WARNING: queenTier anchor not found — add manually")
end

qu.Name = "QueenUpgradeService_OLD_NX"
qu.Parent = nil
clone.Name = "QueenUpgradeService"
clone.Parent = SSS

print("QueenUpgradeService patch applied")
```

### E4 — SpeedUpgradeService: first_upgrade (belt-and-suspenders — any track)

```lua
local SSS = game:GetService("ServerScriptService")
local su = SSS:FindFirstChild("SpeedUpgradeService")
assert(su, "SpeedUpgradeService not found")

local clone = su:Clone()
clone.Name = "SpeedUpgradeService_WORKING"

local reqAnchor = 'local DataService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "DataService require not found in SpeedUpgradeService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))" .. clone.Source:sub(lineEnd + 1)

-- After speedTier increment
local tierAnchor = 'profile.speedTier'
local found2 = clone.Source:find(tierAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	clone.Source = clone.Source:sub(1, lineEnd2) .. "\n\tAchievementService.Check(player, \"first_upgrade\")" .. clone.Source:sub(lineEnd2 + 1)
	print("SpeedUpgradeService first_upgrade hook injected")
else
	print("WARNING: speedTier anchor not found")
end

su.Name = "SpeedUpgradeService_OLD_NX"
su.Parent = nil
clone.Name = "SpeedUpgradeService"
clone.Parent = SSS

print("SpeedUpgradeService patch applied")
```

### E5 — PlotService: all_plots

```lua
local SSS = game:GetService("ServerScriptService")
local ps2 = SSS:FindFirstChild("PlotService")
assert(ps2, "PlotService not found")

local clone = ps2:Clone()
clone.Name = "PlotService_WORKING"

local reqAnchor = 'local DataService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "DataService require not found in PlotService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))" .. clone.Source:sub(lineEnd + 1)

-- After plot unlock — look for profile.unlockedPlots insert or increment
local plotAnchor = 'profile.unlockedPlots'
local found2 = clone.Source:find(plotAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	local INJECT = [[

	-- Check if all 8 plots are now unlocked
	local unlockedCount = 0
	if type(profile.unlockedPlots) == "table" then
		unlockedCount = #profile.unlockedPlots
	elseif type(profile.unlockedPlots) == "number" then
		unlockedCount = profile.unlockedPlots
	end
	if unlockedCount >= 8 then AchievementService.Check(player, "all_plots") end]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT .. clone.Source:sub(lineEnd2 + 1)
	print("PlotService all_plots hook injected")
else
	print("WARNING: unlockedPlots anchor not found — add all_plots check manually")
end

ps2.Name = "PlotService_OLD_NX"
ps2.Parent = nil
clone.Name = "PlotService"
clone.Parent = SSS

print("PlotService patch applied")
```

---

## STEP F — GameManager Init

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local PropolisStorageUpgradeService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "PropolisStorageUpgradeService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))" .. clone.Source:sub(lineEnd + 1)

-- Init BEFORE other services so they can call Check() safely
local initAnchor = 'PropolisStorageUpgradeService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "PropolisStorageUpgradeService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nAchievementService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager AchievementService.Init() injected")
```

---

## STEP G — AchievementController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name = "AchievementController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- AchievementController — listens for AchievementUnlocked, shows gold toast

local PS   = game:GetService("Players")
local RS   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local beesGui   = playerGui:WaitForChild("BeesWorldGui")
local mainFrame = beesGui:WaitForChild("MainFrame")

local AchievementUnlocked = RS:WaitForChild("AchievementUnlocked")

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(80, 50, 20)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)

-- Achievement toast — appears at top-center
local toastFrame = Instance.new("Frame")
toastFrame.Name              = "AchievementToast"
toastFrame.Size              = UDim2.new(0.55, 0, 0.12, 0)
toastFrame.Position          = UDim2.new(0.225, 0, -0.15, 0)
toastFrame.BackgroundColor3  = PROP_BROWN
toastFrame.BorderSizePixel   = 0
toastFrame.ZIndex            = 30
toastFrame.Visible           = false
toastFrame.Parent            = mainFrame
do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.12, 0); c.Parent = toastFrame
	local s = Instance.new("UIStroke")
	s.Color = HONEY_GOLD
	s.Thickness = 3
	s.Parent = toastFrame
end

local titleLbl = Instance.new("TextLabel")
titleLbl.Name              = "TitleLabel"
titleLbl.Size              = UDim2.new(1, 0, 0.45, 0)
titleLbl.Position          = UDim2.new(0, 0, 0.02, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text              = "🏆 Achievement Unlocked!"
titleLbl.TextColor3        = HONEY_GOLD
titleLbl.TextScaled        = true
titleLbl.Font              = Enum.Font.GothamBold
titleLbl.ZIndex            = 31
titleLbl.Parent            = toastFrame

local nameLbl = Instance.new("TextLabel")
nameLbl.Name              = "NameLabel"
nameLbl.Size              = UDim2.new(0.9, 0, 0.32, 0)
nameLbl.Position          = UDim2.new(0.05, 0, 0.48, 0)
nameLbl.BackgroundTransparency = 1
nameLbl.Text              = "First Drop — +50 🍯"
nameLbl.TextColor3        = WAX_CREAM
nameLbl.TextScaled        = true
nameLbl.Font              = Enum.Font.Gotham
nameLbl.ZIndex            = 31
nameLbl.Parent            = toastFrame

-- Queue so multiple achievements don't stack visually
local queue: {{name: string, honeyReward: number, propolisReward: number}} = {}
local showing = false

local function showNext()
	if showing or #queue == 0 then return end
	showing = true
	local data = table.remove(queue, 1)

	local rewardStr = "+" .. data.honeyReward .. " 🍯"
	if data.propolisReward > 0 then rewardStr = rewardStr .. " +" .. data.propolisReward .. " propolis" end
	nameLbl.Text = data.name .. " — " .. rewardStr

	toastFrame.Visible = true
	toastFrame.Position = UDim2.new(0.225, 0, -0.15, 0)
	TweenService:Create(toastFrame,
		TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.225, 0, 0.03, 0)}
	):Play()
	task.wait(3.0)
	TweenService:Create(toastFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(0.225, 0, -0.15, 0)}
	):Play()
	task.wait(0.25)
	toastFrame.Visible = false
	showing = false
	showNext()   -- process next in queue
end

AchievementUnlocked.OnClientEvent:Connect(function(data)
	table.insert(queue, data)
	if not showing then
		task.spawn(showNext)
	end
end)
]]

print("AchievementController created")
```

---

## STEP H — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
table.insert(checks, (cfg and cfg.Source:find("ACHIEVEMENTS") and "✅" or "❌") .. " Config ACHIEVEMENTS")

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("unlockedAchievements") and "✅" or "❌") .. " DataService unlockedAchievements")

local svc = SSS:FindFirstChild("AchievementService")
table.insert(checks, (svc and "✅" or "❌") .. " AchievementService script")

local re = RS:FindFirstChild("AchievementUnlocked")
table.insert(checks, (re and "✅" or "❌") .. " AchievementUnlocked RemoteEvent")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("lifetimeHoney") and "✅" or "❌") .. " ForagingService lifetimeHoney tracking")

local ctrl = SPS and SPS:FindFirstChild("AchievementController")
table.insert(checks, (ctrl and "✅" or "❌") .. " AchievementController")

print("=== DISPATCH 62 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 62 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 62 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- **PrestigeService** already has lazy-require stubs for AchievementService.Check("first_gen") and Check("gen_5") from dispatch 58 — no additional patch needed there.
- **first_upgrade** fires from both SpeedUpgradeService and QueenUpgradeService — achievement is idempotent (one-shot), so whichever fires first wins.
- **lifetimeHoney** tracks raw yield before prestige reset — prestige resets `honey` but `lifetimeHoney` is cumulative forever.
- **Queue system** in AchievementController prevents toast pile-up when multiple achievements unlock simultaneously (e.g. first honey + century fire together on first yield).
