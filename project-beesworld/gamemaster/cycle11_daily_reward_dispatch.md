# Dispatch 55 — DailyRewardService
## Cycle 11 · A Bee's World

**Feature:** Daily login streak rewards — 7-day rotating schedule, honey + propolis rewards, streak reset on miss, toast notification on first login.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 54 (PropolisYieldUpgradeService)

---

## REWARD SCHEDULE

| Day | Reward | Flavor |
|-----|--------|--------|
| 1 | 150 🍯 honey | "Morning nectar" |
| 2 | 300 🍯 honey | "Worker's share" |
| 3 | 150 🍯 + 8 🟤 propolis | "Hive dividend" |
| 4 | 600 🍯 honey | "Queen's bounty" |
| 5 | 400 🍯 + 15 🟤 propolis | "Forager's hoard" |
| 6 | 1,000 🍯 honey | "Comb overflow" |
| 7 | 800 🍯 + 30 🟤 propolis | "🌟 Week crown!" |

Streak resets to Day 1 if the player misses a day. Repeats after Day 7.

---

## STEP A — Config injection

Open **Config** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local clone = cfg:Clone()
clone.Name = "Config_WORKING"

local INJECT = [[

	-- Daily reward schedule (7-day rotating streak)
	DAILY_REWARDS = {
		{day=1, honey=150,  propolis=0,  label="Morning nectar"},
		{day=2, honey=300,  propolis=0,  label="Worker's share"},
		{day=3, honey=150,  propolis=8,  label="Hive dividend"},
		{day=4, honey=600,  propolis=0,  label="Queen's bounty"},
		{day=5, honey=400,  propolis=15, label="Forager's hoard"},
		{day=6, honey=1000, propolis=0,  label="Comb overflow"},
		{day=7, honey=800,  propolis=30, label="Week crown!"},
	},
]]

-- Anchor after PROPOLIS_UPGRADE_MAX_TIER
local anchor = "PROPOLIS_UPGRADE_MAX_TIER = 5,"
local found = clone.Source:find(anchor, 1, true)
if not found then
	-- Fallback anchor
	anchor = "QUEEN_UPGRADE_MAX_TIER = 5,"
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "No upgrade max-tier anchor found in Config")

clone.Source = clone.Source:sub(1, found + #anchor - 1) .. INJECT .. clone.Source:sub(found + #anchor)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config injection OK — DAILY_REWARDS added")
```

**Verify:**
```lua
local cfg = SSS:FindFirstChild("Config")
print(cfg.Source:find("DAILY_REWARDS") and "OK" or "MISSING")
```

---

## STEP B — DataService migration

Open **DataService** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

-- Anchor after propolisTier
local anchor = "propolisTier = 0,"
local found = clone.Source:find(anchor, 1, true)
if not found then
	anchor = "queenTier = 0,"
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "Anchor not found in DataService")

local INJECT = [[

			lastDailyDay   = 0,   -- UTC day number of last claimed reward
			dailyStreak    = 0,   -- consecutive days claimed (1-7, resets on miss)]]

clone.Source = clone.Source:sub(1, found + #anchor - 1) .. INJECT .. clone.Source:sub(found + #anchor)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService migration OK — lastDailyDay + dailyStreak added")
```

**Verify:**
```lua
local ds = game:GetService("ServerScriptService"):FindFirstChild("DataService")
print(ds.Source:find("lastDailyDay") and "OK" or "MISSING")
```

---

## STEP C — DailyRewardService ModuleScript

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("DailyRewardService"), "Already exists — delete first")

local mod = Instance.new("ModuleScript")
mod.Name = "DailyRewardService"
mod.Parent = SSS

mod.Source = [[
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Config = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local DailyRewardService = {}

local DailySync: RemoteEvent
local ClaimDaily: RemoteFunction

-- UTC day number: changes at midnight UTC
local function utcDayNumber(): number
	return math.floor(os.time() / 86400)
end

-- Which streak day (1-7) to show for a given streak count
local function streakDay(streak: number): number
	return ((streak - 1) % 7) + 1
end

-- Build sync payload for a player
local function buildPayload(profile: any): {canClaim: boolean, streak: number, day: number, honey: number, propolis: number, label: string}
	local today = utcDayNumber()
	local lastDay = profile.lastDailyDay or 0
	local streak = profile.dailyStreak or 0

	-- Determine if streak is still alive
	if streak > 0 and today > lastDay + 1 then
		-- Missed a day — streak resets
		streak = 0
	end

	local nextStreak = streak + 1
	local day = streakDay(nextStreak)
	local entry = Config.DAILY_REWARDS[day] or Config.DAILY_REWARDS[1]
	local canClaim = today > lastDay

	return {
		canClaim = canClaim,
		streak = streak,
		day = day,
		honey = entry.honey,
		propolis = entry.propolis,
		label = entry.label,
	}
end

local function syncClient(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	DailySync:FireClient(player, buildPayload(profile))
end

local function onClaimDaily(player: Player): (boolean, string, number, number)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "No profile", 0, 0 end

	local today = utcDayNumber()
	local lastDay = profile.lastDailyDay or 0
	if today <= lastDay then
		return false, "Already claimed today", 0, 0
	end

	-- Calculate streak (reset if missed)
	local streak = profile.dailyStreak or 0
	if streak > 0 and today > lastDay + 1 then
		streak = 0  -- missed a day
	end
	streak += 1

	local day = streakDay(streak)
	local entry = Config.DAILY_REWARDS[day] or Config.DAILY_REWARDS[1]

	-- Credit rewards
	profile.honey += entry.honey
	profile.lifetimeHoney += entry.honey
	profile.propolis = (profile.propolis or 0) + entry.propolis
	profile.lastDailyDay = today
	profile.dailyStreak = streak

	-- Sync updated state back to client
	syncClient(player)

	return true, entry.label, entry.honey, entry.propolis
end

function DailyRewardService.Init()
	DailySync = ReplicatedStorage:WaitForChild("DailySync") :: RemoteEvent
	ClaimDaily = ReplicatedStorage:WaitForChild("ClaimDaily") :: RemoteFunction
	ClaimDaily.OnServerInvoke = onClaimDaily

	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		if player.Parent then syncClient(player) end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			task.wait(1)
			syncClient(player)
		end)
	end

	print("[DailyRewardService] Initialized")
end

return DailyRewardService
]]

print("DailyRewardService created")
```

**Verify:**
```lua
local m = game:GetService("ServerScriptService"):FindFirstChild("DailyRewardService")
print(m and m.ClassName or "MISSING")
```

---

## STEP D — Remotes in ReplicatedStorage

In Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

local function ensureRE(name)
	if not RS:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name; re.Parent = RS
		print("Created:", name)
	else print("Exists:", name) end
end
local function ensureRF(name)
	if not RS:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name; rf.Parent = RS
		print("Created:", name)
	else print("Exists:", name) end
end

ensureRE("DailySync")
ensureRF("ClaimDaily")
print("Remotes OK")
```

---

## STEP E — GameManager injection

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

-- Require anchor
local anchors = {
	'require(SSS:WaitForChild("PropolisYieldUpgradeService"))',
	'require(SSS:WaitForChild("QueenUpgradeService"))',
	'require(SSS:WaitForChild("PollenYieldUpgradeService"))',
	'require(SSS:WaitForChild("SpeedUpgradeService"))',
}
local reqAnchor, found1
for _, a in anchors do
	found1 = clone.Source:find(a, 1, true)
	if found1 then reqAnchor = a; break end
end
assert(found1, "No upgrade service require found in GameManager")

clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1)
	.. '\nlocal DailyRewardService = require(SSS:WaitForChild("DailyRewardService"))'
	.. clone.Source:sub(found1 + #reqAnchor)

-- Init anchor
local initAnchors = {
	"PropolisYieldUpgradeService.Init()",
	"QueenUpgradeService.Init()",
	"PollenYieldUpgradeService.Init()",
	"SpeedUpgradeService.Init()",
}
local initAnchor, found2
for _, a in initAnchors do
	found2 = clone.Source:find(a, 1, true)
	if found2 then initAnchor = a; break end
end
assert(found2, "No upgrade Init() found in GameManager")

clone.Source = clone.Source:sub(1, found2 + #initAnchor - 1)
	.. "\n\tDailyRewardService.Init()"
	.. clone.Source:sub(found2 + #initAnchor)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager injection OK — DailyRewardService wired in")
```

---

## STEP F — DailyRewardController LocalScript

In Command Bar:

```lua
local SPScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPScripts, "StarterPlayerScripts not found")

if SPScripts:FindFirstChild("DailyRewardController") then
	SPScripts:FindFirstChild("DailyRewardController"):Destroy()
end

local ls = Instance.new("LocalScript")
ls.Name = "DailyRewardController"
ls.Parent = SPScripts

ls.Source = [[
--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DailySync: RemoteEvent = RS:WaitForChild("DailySync") :: RemoteEvent
local ClaimDaily: RemoteFunction = RS:WaitForChild("ClaimDaily") :: RemoteFunction

-- Warm Wax palette
local HONEY_GOLD    = Color3.fromRGB(242, 168, 28)
local WAX_CREAM     = Color3.fromRGB(232, 212, 154)
local PROPOLIS_BROWN = Color3.fromRGB(122, 74, 34)
local BG_DARK       = Color3.fromRGB(22, 14, 4)
local WHITE         = Color3.fromRGB(255, 255, 255)
local GREEN         = Color3.fromRGB(80, 200, 80)
local GREY          = Color3.fromRGB(120, 100, 80)

-- Build ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name = "DailyRewardGui"
sg.DisplayOrder = 22
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = false
sg.Parent = playerGui

-- Tab button (left column, below PropolisTab at 0.775)
local tabBtn = Instance.new("TextButton")
tabBtn.Name = "DailyTab"
tabBtn.Size = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position = UDim2.new(0.01, 0, 0.865, 0)
tabBtn.BackgroundColor3 = PROPOLIS_BROWN
tabBtn.TextColor3 = WAX_CREAM
tabBtn.Text = "📅"
tabBtn.TextScaled = true
tabBtn.Font = Enum.Font.GothamBold
tabBtn.ZIndex = 24
tabBtn.Parent = sg

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.18, 0); c.Parent = tabBtn
	local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2; s.Parent = tabBtn
end

-- Reward panel
local panel = Instance.new("Frame")
panel.Name = "DailyPanel"
panel.Size = UDim2.new(0.30, 0, 0.60, 0)
panel.Position = UDim2.new(1.02, 0, 0.20, 0)
panel.BackgroundColor3 = BG_DARK
panel.BorderSizePixel = 0
panel.ZIndex = 23
panel.Parent = sg

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.04, 0); c.Parent = panel
	local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2; s.Parent = panel
end

-- Header
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0.11, 0)
header.Position = UDim2.new(0, 0, 0.01, 0)
header.BackgroundTransparency = 1
header.TextColor3 = HONEY_GOLD
header.Text = "📅 Daily Reward"
header.TextScaled = true
header.Font = Enum.Font.GothamBold
header.ZIndex = 24
header.Parent = panel

-- Streak label
local streakLbl = Instance.new("TextLabel")
streakLbl.Name = "StreakLbl"
streakLbl.Size = UDim2.new(0.9, 0, 0.09, 0)
streakLbl.Position = UDim2.new(0.05, 0, 0.13, 0)
streakLbl.BackgroundTransparency = 1
streakLbl.TextColor3 = WAX_CREAM
streakLbl.Text = "Streak: Day 1/7"
streakLbl.TextScaled = true
streakLbl.Font = Enum.Font.Gotham
streakLbl.ZIndex = 24
streakLbl.Parent = panel

-- 7-day pip row
local pipRow = Instance.new("Frame")
pipRow.Name = "PipRow"
pipRow.Size = UDim2.new(0.88, 0, 0.09, 0)
pipRow.Position = UDim2.new(0.06, 0, 0.24, 0)
pipRow.BackgroundTransparency = 1
pipRow.ZIndex = 24
pipRow.Parent = panel

local pipLayout = Instance.new("UIListLayout")
pipLayout.FillDirection = Enum.FillDirection.Horizontal
pipLayout.SortOrder = Enum.SortOrder.LayoutOrder
pipLayout.Padding = UDim.new(0.02, 0)
pipLayout.Parent = pipRow

local pips: {Frame} = {}
for i = 1, 7 do
	local pip = Instance.new("Frame")
	pip.Name = "Pip" .. i
	pip.Size = UDim2.new(1/7 - 0.02, 0, 1, 0)
	pip.BackgroundColor3 = PROPOLIS_BROWN
	pip.BorderSizePixel = 0
	pip.LayoutOrder = i
	pip.ZIndex = 25
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.4, 0); pc.Parent = pip
	pip.Parent = pipRow
	pips[i] = pip
end

-- Reward preview
local rewardLbl = Instance.new("TextLabel")
rewardLbl.Name = "RewardLbl"
rewardLbl.Size = UDim2.new(0.9, 0, 0.16, 0)
rewardLbl.Position = UDim2.new(0.05, 0, 0.35, 0)
rewardLbl.BackgroundTransparency = 1
rewardLbl.TextColor3 = HONEY_GOLD
rewardLbl.Text = "Today: 150 🍯"
rewardLbl.TextScaled = true
rewardLbl.Font = Enum.Font.GothamBold
rewardLbl.TextWrapped = true
rewardLbl.ZIndex = 24
rewardLbl.Parent = panel

-- Flavor label
local flavorLbl = Instance.new("TextLabel")
flavorLbl.Name = "FlavorLbl"
flavorLbl.Size = UDim2.new(0.9, 0, 0.09, 0)
flavorLbl.Position = UDim2.new(0.05, 0, 0.52, 0)
flavorLbl.BackgroundTransparency = 1
flavorLbl.TextColor3 = Color3.fromRGB(180, 155, 120)
flavorLbl.Text = "Morning nectar"
flavorLbl.TextScaled = true
flavorLbl.Font = Enum.Font.Gotham
flavorLbl.ZIndex = 24
flavorLbl.Parent = panel

-- Claim button
local claimBtn = Instance.new("TextButton")
claimBtn.Name = "ClaimBtn"
claimBtn.Size = UDim2.new(0.80, 0, 0.14, 0)
claimBtn.Position = UDim2.new(0.10, 0, 0.64, 0)
claimBtn.BackgroundColor3 = HONEY_GOLD
claimBtn.TextColor3 = PROPOLIS_BROWN
claimBtn.Text = "Claim Reward!"
claimBtn.TextScaled = true
claimBtn.Font = Enum.Font.GothamBold
claimBtn.ZIndex = 25
claimBtn.Parent = panel

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.25, 0); c.Parent = claimBtn
	local s = Instance.new("UIStroke"); s.Color = WAX_CREAM; s.Thickness = 1.5; s.Parent = claimBtn
end

-- Claimed-today label (hidden by default)
local claimedLbl = Instance.new("TextLabel")
claimedLbl.Name = "ClaimedLbl"
claimedLbl.Size = UDim2.new(0.9, 0, 0.10, 0)
claimedLbl.Position = UDim2.new(0.05, 0, 0.80, 0)
claimedLbl.BackgroundTransparency = 1
claimedLbl.TextColor3 = GREEN
claimedLbl.Text = "✅ Come back tomorrow!"
claimedLbl.TextScaled = true
claimedLbl.Font = Enum.Font.Gotham
claimedLbl.Visible = false
claimedLbl.ZIndex = 24
claimedLbl.Parent = panel

-- Close
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.12, 0, 0.09, 0)
closeBtn.Position = UDim2.new(0.86, 0, 0.01, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = GREY
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 26
closeBtn.Parent = panel

-- ── State ─────────────────────────────────────────────────────────
local panelOpen = false
local canClaim = false
local busy = false

local function updatePips(streak: number, day: number)
	for i, pip in pips do
		if i < day then
			pip.BackgroundColor3 = GREEN -- completed
		elseif i == day then
			pip.BackgroundColor3 = HONEY_GOLD -- today
		else
			pip.BackgroundColor3 = PROPOLIS_BROWN -- future
		end
	end
	-- Day 7 gets a star marker
	if day == 7 then
		pips[7].BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- gold
	end
end

local function refreshUI(data: {canClaim: boolean, streak: number, day: number, honey: number, propolis: number, label: string})
	canClaim = data.canClaim
	streakLbl.Text = string.format("Streak: Day %d/7  (×%d days)", data.day, data.streak + (data.canClaim and 0 or 0))
	updatePips(data.streak, data.day)

	local rewardStr = data.honey .. " 🍯"
	if data.propolis > 0 then rewardStr = rewardStr .. "  +" .. data.propolis .. " 🟤" end
	rewardLbl.Text = "Today: " .. rewardStr
	flavorLbl.Text = '"' .. data.label .. '"'

	if data.canClaim then
		claimBtn.Visible = true
		claimBtn.BackgroundColor3 = HONEY_GOLD
		claimBtn.Text = "Claim Reward!"
		claimBtn.Active = true
		claimedLbl.Visible = false
		-- Pulse tab badge when reward available
		tabBtn.BackgroundColor3 = HONEY_GOLD
		tabBtn.TextColor3 = PROPOLIS_BROWN
	else
		claimBtn.Visible = false
		claimedLbl.Visible = true
		tabBtn.BackgroundColor3 = PROPOLIS_BROWN
		tabBtn.TextColor3 = WAX_CREAM
	end
end

-- Claim toast
local function showClaimToast(honey: number, propolis: number, label: string)
	local toastSg = Instance.new("ScreenGui")
	toastSg.Name = "DailyToast"
	toastSg.DisplayOrder = 30
	toastSg.ResetOnSpawn = false
	toastSg.IgnoreGuiInset = false
	toastSg.Parent = playerGui

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0.36, 0, 0.12, 0)
	card.Position = UDim2.new(0.32, 0, -0.15, 0)
	card.AnchorPoint = Vector2.new(0, 0)
	card.BackgroundColor3 = PROPOLIS_BROWN
	card.BorderSizePixel = 0
	card.ZIndex = 31
	card.Parent = toastSg

	do
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.18, 0); c.Parent = card
		local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2.5; s.Parent = card
	end

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0.55, 0)
	lbl.Position = UDim2.new(0, 0, 0.05, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = HONEY_GOLD
	local rewardStr = honey .. " 🍯"
	if propolis > 0 then rewardStr = rewardStr .. " + " .. propolis .. " 🟤" end
	lbl.Text = "📅 Daily Reward!  +" .. rewardStr
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.ZIndex = 32
	lbl.Parent = card

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0.38, 0)
	sub.Position = UDim2.new(0, 0, 0.58, 0)
	sub.BackgroundTransparency = 1
	sub.TextColor3 = WAX_CREAM
	sub.Text = '"' .. label .. '"'
	sub.TextScaled = true
	sub.Font = Enum.Font.Gotham
	sub.ZIndex = 32
	sub.Parent = card

	-- Animate: slide down from above
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.32, 0, 0.04, 0),
	}):Play()

	task.wait(3.2)

	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.32, 0, -0.15, 0),
	}):Play()
	task.wait(0.3)
	toastSg:Destroy()
end

-- ── Panel animation ────────────────────────────────────────────────
local function openPanel()
	panelOpen = true
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.68, 0, 0.20, 0),
	}):Play()
end
local function closePanel()
	panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1.02, 0, 0.20, 0),
	}):Play()
end

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

-- ── Claim ─────────────────────────────────────────────────────────
claimBtn.MouseButton1Click:Connect(function()
	if busy or not canClaim then return end
	busy = true
	claimBtn.Text = "Claiming..."
	claimBtn.BackgroundColor3 = Color3.fromRGB(160, 110, 10)

	local ok, label, honey, propolis = ClaimDaily:InvokeServer()
	if ok then
		task.spawn(showClaimToast, honey, propolis, label)
	else
		claimBtn.Text = "✗ " .. (label or "Error")
		task.wait(1.5)
		claimBtn.Text = "Claim Reward!"
		claimBtn.BackgroundColor3 = HONEY_GOLD
	end
	busy = false
end)

-- ── Sync ──────────────────────────────────────────────────────────
DailySync.OnClientEvent:Connect(function(data)
	refreshUI(data)
	-- Auto-open panel on first login if reward is available
	if data.canClaim and not panelOpen then
		task.wait(5)  -- let tutorial / other panels settle first
		openPanel()
	end
end)
]]

print("DailyRewardController created")
```

---

## STEP G — Full verification sweep

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local checks = {}

local cfgMod = SSS:FindFirstChild("Config")
table.insert(checks, ((cfgMod and cfgMod.Source:find("DAILY_REWARDS")) and "✅" or "❌") .. " Config.DAILY_REWARDS")

local dsMod = SSS:FindFirstChild("DataService")
table.insert(checks, ((dsMod and dsMod.Source:find("lastDailyDay")) and "✅" or "❌") .. " DataService lastDailyDay field")
table.insert(checks, ((dsMod and dsMod.Source:find("dailyStreak")) and "✅" or "❌") .. " DataService dailyStreak field")

table.insert(checks, (SSS:FindFirstChild("DailyRewardService") and "✅" or "❌") .. " DailyRewardService module")
table.insert(checks, (RS:FindFirstChild("DailySync") and "✅" or "❌") .. " DailySync RemoteEvent")
table.insert(checks, (RS:FindFirstChild("ClaimDaily") and "✅" or "❌") .. " ClaimDaily RemoteFunction")

local gmMod = SSS:FindFirstChild("GameManager")
table.insert(checks, ((gmMod and gmMod.Source:find("DailyRewardService")) and "✅" or "❌") .. " GameManager wired")

local spScripts = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = spScripts and spScripts:FindFirstChild("DailyRewardController")
table.insert(checks, (ctrl and "✅" or "❌") .. " DailyRewardController LocalScript")

print("=== DISPATCH 55 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 55 complete" or "❌ SOME CHECKS FAILED — see above")
```

Expected output:
```
=== DISPATCH 55 VERIFICATION ===
✅ Config.DAILY_REWARDS
✅ DataService lastDailyDay field
✅ DataService dailyStreak field
✅ DailyRewardService module
✅ DailySync RemoteEvent
✅ ClaimDaily RemoteFunction
✅ GameManager wired
✅ DailyRewardController LocalScript
✅ ALL CHECKS PASS — dispatch 55 complete
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| DailyRewardController ScreenGui | 0 BaseParts |
| **Dispatch 55 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## GameManager init chain (post dispatch 55)

```
  → PropolisYieldUpgradeService.Init()   ← dispatch 54
  → DailyRewardService.Init()            ← dispatch 55
```

**Retention note:** Panel auto-opens 5 seconds after login when a reward is available, surfacing the feature naturally without being intrusive. The 📅 tab button pulses gold when unclaimed, giving a persistent visual reminder.
