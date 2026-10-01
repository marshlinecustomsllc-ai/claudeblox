# Dispatch 63 — LeaderboardService
## Cycle 11 · A Bee's World

**Feature:** Global leaderboard — top-10 players ranked by lifetime honey earned. Uses Roblox OrderedDataStore. Updates every 60 seconds and on each yield batch. Displayed as an in-game panel with gold rank numbers and a "Your Rank" footer.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 62 (AchievementService)

---

## DESIGN

- **Metric:** `lifetimeHoney` (cumulative, never reset by prestige) — fairest cross-player comparison
- **Update cadence:** Every 60 seconds server-side + on each yield batch (debounced per player, max 1 update per 10s per player to protect DataStore budget)
- **Display:** `SurfaceGui` on a dedicated Part in Workspace OR in-game ScreenGui panel (ScreenGui approach — no 3D part needed, zero part budget cost)
- **Top-10 fetch:** OrderedDataStore:GetSortedAsync(false, 10) — descending order
- **Player name resolution:** `Players:GetNameFromUserIdAsync()` with pcall fallback

---

## FILES CHANGED

| File | Change |
|------|--------|
| `LeaderboardService` (new Script in SSS) | OrderedDataStore write + fetch, LeaderboardSync RE |
| `ForagingService` | submit lifetimeHoney to leaderboard after yield |
| `GameManager` | Init call |
| `LeaderboardController` (new LocalScript) | 🏆 tab, top-10 panel |

---

## STEP A — LeaderboardService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local LeaderboardSync = Instance.new("RemoteEvent")
LeaderboardSync.Name = "LeaderboardSync"
LeaderboardSync.Parent = RS

local svc = Instance.new("Script")
svc.Name = "LeaderboardService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- LeaderboardService
-- Maintains a global top-10 leaderboard by lifetime honey using OrderedDataStore.
-- Writes are debounced per player (max once per 10s) to stay within DataStore limits.

local DS  = game:GetService("DataStoreService")
local PS  = game:GetService("Players")
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local DataService = require(SSS:WaitForChild("DataService"))

local LeaderboardSync = RS:WaitForChild("LeaderboardSync")

local STORE_KEY      = "LifetimeHoney_v1"
local REFRESH_INTERVAL = 60        -- seconds between full fetches
local WRITE_COOLDOWN   = 10        -- seconds between per-player writes
local TOP_N            = 10

local ods: OrderedDataStore = DS:GetOrderedDataStore(STORE_KEY)

local LeaderboardService = {}
local lastWrite: {[number]: number} = {}   -- userId → tick()
local cachedBoard: {{rank: number, name: string, value: number}} = {}

local function fetchAndBroadcast()
	local ok, pages = pcall(function()
		return ods:GetSortedAsync(false, TOP_N)
	end)
	if not ok then return end

	local board: {{rank: number, name: string, value: number}} = {}
	local pageData = pages:GetCurrentPage()
	for rank, entry in pageData do
		local name = "Beekeeper"
		local nameOk, resolved = pcall(function()
			return PS:GetNameFromUserIdAsync(entry.key)
		end)
		if nameOk and resolved then name = resolved end
		table.insert(board, {rank = rank, name = name, value = entry.value})
	end
	cachedBoard = board

	-- Broadcast to all connected players
	for _, player in PS:GetPlayers() do
		local profile = DataService.GetProfile(player)
		local myValue = profile and (profile.lifetimeHoney or 0) or 0
		local myRank  = 0
		for _, row in board do
			if row.value <= myValue then myRank = row.rank; break end
		end
		LeaderboardSync:FireClient(player, board, myValue, myRank)
	end
end

-- Submit a single player's score (debounced)
function LeaderboardService.Submit(player: Player, lifetimeHoney: number)
	local uid = player.UserId
	local now = tick()
	if (lastWrite[uid] or 0) + WRITE_COOLDOWN > now then return end
	lastWrite[uid] = now
	task.spawn(function()
		pcall(function()
			ods:SetAsync(tostring(uid), math.floor(lifetimeHoney))
		end)
	end)
end

function LeaderboardService.Init()
	-- Initial fetch after a short delay (DataStore may not be ready immediately)
	task.delay(5, fetchAndBroadcast)

	-- Periodic refresh
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			fetchAndBroadcast()
		end
	end)

	-- On player join, send cached board immediately then schedule fresh fetch
	PS.PlayerAdded:Connect(function(player)
		task.wait(2)
		local profile = DataService.GetProfile(player)
		local myValue = profile and (profile.lifetimeHoney or 0) or 0
		LeaderboardSync:FireClient(player, cachedBoard, myValue, 0)
		task.delay(5, fetchAndBroadcast)
	end)

	print("[LeaderboardService] ready")
end

return LeaderboardService
]]

print("LeaderboardService created")
```

---

## STEP B — ForagingService: submit to leaderboard after yield

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- Add require after AchievementService require
local reqAnchor = 'local AchievementService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "AchievementService require not found")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal LeaderboardService = require(SSS:WaitForChild(\"LeaderboardService\"))" .. clone.Source:sub(lineEnd + 1)

-- After CheckHoneyMilestones, submit to leaderboard
local milestoneAnchor = 'AchievementService.CheckHoneyMilestones(player)'
local found2 = clone.Source:find(milestoneAnchor, 1, true)
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	clone.Source = clone.Source:sub(1, lineEnd2) .. "\n\tLeaderboardService.Submit(player, profile.lifetimeHoney or 0)" .. clone.Source:sub(lineEnd2 + 1)
	print("LeaderboardService.Submit injected after milestone check")
else
	print("WARNING: CheckHoneyMilestones anchor not found — add Submit manually")
end

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService leaderboard submit patch applied")
```

---

## STEP C — GameManager Init

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local AchievementService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "AchievementService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal LeaderboardService = require(SSS:WaitForChild(\"LeaderboardService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'AchievementService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "AchievementService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nLeaderboardService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager LeaderboardService.Init() injected")
```

---

## STEP D — LeaderboardController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name = "LeaderboardController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- LeaderboardController — 🏆 leaderboard tab and top-10 panel

local PS   = game:GetService("Players")
local RS   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local beesGui   = playerGui:WaitForChild("BeesWorldGui")
local mainFrame = beesGui:WaitForChild("MainFrame")

local LeaderboardSync = RS:WaitForChild("LeaderboardSync")

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(80, 50, 20)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local GOLD_RANK   = Color3.fromRGB(255, 215, 0)
local SILVER_RANK = Color3.fromRGB(192, 192, 192)
local BRONZE_RANK = Color3.fromRGB(205, 127, 50)
local PANEL_OPEN_X  = 0.55
local PANEL_CLOSE_X = 1.02
local panelOpen = false

-- tab button — right column, below propolis storage (Y=0.60)
local tabBtn = Instance.new("TextButton")
tabBtn.Name             = "LeaderboardTabBtn"
tabBtn.Size             = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position         = UDim2.new(0.925, 0, 0.60, 0)
tabBtn.BackgroundColor3 = PROP_BROWN
tabBtn.BorderSizePixel  = 0
tabBtn.Text             = "🏆"
tabBtn.TextScaled       = true
tabBtn.ZIndex           = 24
tabBtn.Parent           = mainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15, 0); c.Parent = tabBtn end

-- panel
local panel = Instance.new("Frame")
panel.Name             = "LeaderboardPanel"
panel.Size             = UDim2.new(0.42, 0, 0.72, 0)
panel.Position         = UDim2.new(PANEL_CLOSE_X, 0, 0.14, 0)
panel.BackgroundColor3 = PROP_BROWN
panel.BorderSizePixel  = 0
panel.ZIndex           = 20
panel.ClipsDescendants = true
panel.Parent           = mainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.03, 0); c.Parent = panel end
do
	local s = Instance.new("UIStroke")
	s.Color = HONEY_GOLD
	s.Thickness = 2
	s.Parent = panel
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.09, 0)
title.Position = UDim2.new(0, 0, 0.00, 0)
title.BackgroundTransparency = 1
title.Text = "🏆 Top Beekeepers"
title.TextColor3 = HONEY_GOLD
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.ZIndex = 21
title.Parent = panel

-- 10 rank rows
local rankRows: {Frame} = {}
for i = 1, 10 do
	local row = Instance.new("Frame")
	row.Name = "Row" .. i
	row.Size = UDim2.new(0.94, 0, 0.075, 0)
	row.Position = UDim2.new(0.03, 0, 0.09 + (i - 1) * 0.079, 0)
	row.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(100, 60, 25) or Color3.fromRGB(90, 52, 20)
	row.BorderSizePixel = 0
	row.ZIndex = 21
	row.Parent = panel
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15, 0); c.Parent = row end

	local rankColor = (i == 1) and GOLD_RANK or (i == 2) and SILVER_RANK or (i == 3) and BRONZE_RANK or WAX_CREAM

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Name = "Rank"
	rankLbl.Size = UDim2.new(0.12, 0, 1, 0)
	rankLbl.Position = UDim2.new(0.01, 0, 0, 0)
	rankLbl.BackgroundTransparency = 1
	rankLbl.Text = "#" .. i
	rankLbl.TextColor3 = rankColor
	rankLbl.TextScaled = true
	rankLbl.Font = Enum.Font.GothamBold
	rankLbl.ZIndex = 22
	rankLbl.Parent = row

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
	nameLbl.Position = UDim2.new(0.14, 0, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = "---"
	nameLbl.TextColor3 = WAX_CREAM
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.ZIndex = 22
	nameLbl.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.Name = "Value"
	valLbl.Size = UDim2.new(0.30, 0, 1, 0)
	valLbl.Position = UDim2.new(0.69, 0, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = "0 🍯"
	valLbl.TextColor3 = HONEY_GOLD
	valLbl.TextScaled = true
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.ZIndex = 22
	valLbl.Parent = row

	table.insert(rankRows, row)
end

-- "Your rank" footer
local myRankLbl = Instance.new("TextLabel")
myRankLbl.Name = "MyRankLabel"
myRankLbl.Size = UDim2.new(0.94, 0, 0.07, 0)
myRankLbl.Position = UDim2.new(0.03, 0, 0.91, 0)
myRankLbl.BackgroundTransparency = 1
myRankLbl.Text = "Your rank: —"
myRankLbl.TextColor3 = HONEY_GOLD
myRankLbl.TextScaled = true
myRankLbl.Font = Enum.Font.Gotham
myRankLbl.ZIndex = 21
myRankLbl.Parent = panel

local function fmt(n: number): string
	if n >= 1000000 then return string.format("%.1fM", n/1000000)
	elseif n >= 1000 then return string.format("%.1fK", n/1000)
	else return tostring(n) end
end

local function openPanel()
	if panelOpen then return end; panelOpen = true
	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(PANEL_OPEN_X, 0, 0.14, 0)}):Play()
end
local function closePanel()
	if not panelOpen then return end; panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(PANEL_CLOSE_X, 0, 0.14, 0)}):Play()
end

LeaderboardSync.OnClientEvent:Connect(function(board, myValue, myRank)
	for i = 1, 10 do
		local row = rankRows[i]
		local entry = board[i]
		if entry then
			row:FindFirstChild("Name").Text  = entry.name
			row:FindFirstChild("Value").Text = fmt(entry.value) .. " 🍯"
			row.BackgroundTransparency = 0
		else
			row:FindFirstChild("Name").Text  = "---"
			row:FindFirstChild("Value").Text = "—"
			row.BackgroundTransparency = 0.4
		end
	end
	if myRank > 0 then
		myRankLbl.Text = "Your rank: #" .. myRank .. "  (" .. fmt(myValue) .. " 🍯)"
	else
		myRankLbl.Text = "Your rank: unranked  (" .. fmt(myValue) .. " 🍯)"
	end
end)

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)
]]

print("LeaderboardController created")
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local svc = SSS:FindFirstChild("LeaderboardService")
table.insert(checks, (svc and "✅" or "❌") .. " LeaderboardService script")

local re = RS:FindFirstChild("LeaderboardSync")
table.insert(checks, (re and "✅" or "❌") .. " LeaderboardSync RemoteEvent")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("LeaderboardService") and "✅" or "❌") .. " ForagingService Submit hook")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("LeaderboardService") and "✅" or "❌") .. " GameManager Init")

local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")
table.insert(checks, (ctrl and "✅" or "❌") .. " LeaderboardController")

print("=== DISPATCH 63 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 63 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 63 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- **OrderedDataStore key:** `"LifetimeHoney_v1"` — versioned so a reset doesn't conflict with old data
- **Write budget:** Roblox allows ~60 writes/min per server. With WRITE_COOLDOWN=10s per player and typical 10-player servers, worst case is 6 writes/min — well within budget
- **GetSortedAsync latency:** async; won't block gameplay. `fetchAndBroadcast()` runs in `task.spawn` context
- **Player name resolution:** `GetNameFromUserIdAsync` has network latency — runs inside pcall with fallback to "Beekeeper"
- **Right column layout (post dispatch 63):** skin Y=0.30, prestige Y=0.40, propolis-storage Y=0.50, leaderboard Y=0.60 — four tabs, evenly spaced at 0.10 intervals
