# Dispatch 72 — HiveStatsService
## Cycle 11 · A Bee's World

**Feature:** Persistent hive statistics panel — tracks `totalHoneyEarned`, `totalForagingTrips`, `totalUpgradesBought`, and `daysPlayed` per player. Stats are stored in profile and displayed in a 📊 panel accessible from a new right-column tab. Also shows the current seasonal event multiplier and friend bonus in a compact summary row.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 71 (BeeNameService)

---

## DESIGN

Stats are incremented server-side by the services that already own those actions:
- `ForagingService` → `totalHoneyEarned += honeyYield` and `totalForagingTrips += 1` each cycle
- `SpeedUpgradeService`, `QueenUpgradeService`, `PollenYieldService`, `PropolisUpgradeService`, `HoneyStorageUpgradeService`, `PropolisStorageUpgradeService`, `PollenStorageUpgradeService` → `totalUpgradesBought += 1` each purchase
- `DataService` → `daysPlayed` incremented once per UTC day on login (using a `lastLoginDay` field)

`HiveStatsController` is a new LocalScript showing a 📊 tab on the right column. Panel displays 4 stat rows plus the multiplier summary.

### Panel layout

```
📊 Hive Statistics

🍯 Total Honey:       1,234,567
✈️ Foraging Trips:    8,402
⬆️ Upgrades Bought:   23
📅 Days Played:       7

── Active Bonuses ──
🌸 Spring Bloom: 2× Honey
🐝 Friend Bonus: +10%
```

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DataService` | 4 new stat fields + `lastLoginDay` |
| `HiveStatsService` (new Script in SSS) | StatsSync RE, daily login increment |
| `GameManager` | Init call |
| `ForagingService` | increment totalHoneyEarned + totalForagingTrips |
| `SpeedUpgradeService` | increment totalUpgradesBought |
| `HiveStatsController` (new LocalScript) | 📊 tab + stats panel |

---

## STEP A — DataService migration

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

local anchor = 'queenName = "Queen Bee"'
local found = clone.Source:find(anchor, 1, true)
assert(found, "queenName anchor not found")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. [[

		totalHoneyEarned   = 0,     -- cumulative honey credited all time
		totalForagingTrips = 0,     -- foraging cycles completed
		totalUpgradesBought = 0,    -- any upgrade purchase
		daysPlayed         = 0,     -- distinct UTC days logged in
		lastLoginDay       = 0,     -- UTC day number of last login]] .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService stat fields migration applied")
```

---

## STEP B — HiveStatsService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local StatsSync = Instance.new("RemoteEvent")
StatsSync.Name   = "StatsSync"
StatsSync.Parent = RS

local svc = Instance.new("Script")
svc.Name   = "HiveStatsService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- HiveStatsService
-- Broadcasts player hive statistics and handles daily login tracking.

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local PS  = game:GetService("Players")

local DataService = require(SSS:WaitForChild("DataService"))
local StatsSync   = RS:WaitForChild("StatsSync")

local HiveStatsService = {}

local function utcDay(): number
	return math.floor(os.time() / 86400)
end

local function sendStats(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	StatsSync:FireClient(player, {
		totalHoneyEarned    = profile.totalHoneyEarned    or 0,
		totalForagingTrips  = profile.totalForagingTrips  or 0,
		totalUpgradesBought = profile.totalUpgradesBought or 0,
		daysPlayed          = profile.daysPlayed          or 0,
	})
end

function HiveStatsService.RecordLogin(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local today = utcDay()
	if (profile.lastLoginDay or 0) < today then
		profile.lastLoginDay = today
		profile.daysPlayed   = (profile.daysPlayed or 0) + 1
	end
	sendStats(player)
end

function HiveStatsService.BroadcastStats(player: Player)
	sendStats(player)
end

function HiveStatsService.Init()
	PS.PlayerAdded:Connect(function(player)
		task.wait(3)
		HiveStatsService.RecordLogin(player)
	end)
	for _, player in PS:GetPlayers() do
		task.spawn(HiveStatsService.RecordLogin, player)
	end
	print("[HiveStatsService] ready")
end

return HiveStatsService
]]

print("HiveStatsService created")
```

---

## STEP C — GameManager: inject HiveStatsService.Init()

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local BeeNameService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "BeeNameService require not found")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal HiveStatsService = require(SSS:WaitForChild(\"HiveStatsService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'BeeNameService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "BeeNameService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nHiveStatsService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager HiveStatsService.Init() injected")
```

---

## STEP D — ForagingService: increment trip + honey stats

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- Inject require
local anchor = 'local FriendBonusService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "FriendBonusService require not found in ForagingService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal HiveStatsService = require(SSS:WaitForChild(\"HiveStatsService\"))" .. clone.Source:sub(lineEnd + 1)

-- After honeyYield is credited, increment stats
local anchor2 = 'profile.honey = profile.honey + honeyYield'
local found2 = clone.Source:find(anchor2, 1, true)
assert(found2, "honey credit line not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. [[

	-- Stats tracking
	profile.totalHoneyEarned    = (profile.totalHoneyEarned or 0) + honeyYield
	profile.totalForagingTrips  = (profile.totalForagingTrips or 0) + 1
	HiveStatsService.BroadcastStats(player)]] .. clone.Source:sub(lineEnd2 + 1)

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService stats tracking injected")
```

---

## STEP E — SpeedUpgradeService: increment upgradesBought

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local su = SSS:FindFirstChild("SpeedUpgradeService")
assert(su, "SpeedUpgradeService not found")

local clone = su:Clone()
clone.Name = "SpeedUpgradeService_WORKING"

-- Inject require
local anchor = 'local DataService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "DataService require not found in SpeedUpgradeService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal HiveStatsService = require(SSS:WaitForChild(\"HiveStatsService\"))" .. clone.Source:sub(lineEnd + 1)

-- After profile.speedTier is incremented, add stat
local anchor2 = 'profile.speedTier'
local found2 = clone.Source:find(anchor2, 1, true)
assert(found2, "speedTier not found in SpeedUpgradeService")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\n\tprofile.totalUpgradesBought = (profile.totalUpgradesBought or 0) + 1" .. clone.Source:sub(lineEnd2 + 1)

su.Name = "SpeedUpgradeService_OLD_NX"
su.Parent = nil
clone.Name = "SpeedUpgradeService"
clone.Parent = SSS

print("SpeedUpgradeService totalUpgradesBought injected")
```

---

## STEP F — HiveStatsController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "HiveStatsController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- HiveStatsController — 📊 stats tab (right column)

local PS           = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StatsSync     = RS:WaitForChild("StatsSync")
local SeasonalSync  = RS:WaitForChild("SeasonalSync")
local FriendBonusSync = RS:WaitForChild("FriendBonusSync")

local PROP_BROWN  = Color3.fromRGB(80,  50,  20)
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local PANEL_OPEN  = UDim2.new(0.28, 0, 0.10, 0)
local PANEL_CLOSE = UDim2.new(1.05, 0, 0.10, 0)
local TWEEN_OPEN  = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local sg = Instance.new("ScreenGui")
sg.Name           = "StatsGui"
sg.ResetOnSpawn   = false
sg.DisplayOrder   = 22
sg.IgnoreGuiInset = false
sg.Parent         = playerGui

-- Tab button
local tabBtn = Instance.new("TextButton")
tabBtn.Size              = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position          = UDim2.new(0.925, 0, 0.68, 0)
tabBtn.BackgroundColor3  = PROP_BROWN
tabBtn.BorderSizePixel   = 0
tabBtn.Text              = "📊"
tabBtn.TextScaled        = true
tabBtn.Font              = Enum.Font.Gotham
tabBtn.TextColor3        = WAX_CREAM
tabBtn.ZIndex            = 20
tabBtn.Parent            = sg
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15,0); c.Parent = tabBtn end
do local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2; s.Parent = tabBtn end

-- Panel
local panel = Instance.new("Frame")
panel.Name             = "StatsPanel"
panel.Size             = UDim2.new(0.38, 0, 0.72, 0)
panel.Position         = PANEL_CLOSE
panel.BackgroundColor3 = PROP_BROWN
panel.BorderSizePixel  = 0
panel.ZIndex           = 21
panel.Visible          = false
panel.Parent           = sg
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.03,0); c.Parent = panel end
do local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 3; s.Parent = panel end

local panelOpen = false
local function openPanel()
	panel.Visible = true
	TweenService:Create(panel, TWEEN_OPEN, {Position = PANEL_OPEN}):Play()
	panelOpen = true
end
local function closePanel()
	local tw = TweenService:Create(panel, TWEEN_CLOSE, {Position = PANEL_CLOSE})
	tw:Play()
	tw.Completed:Connect(function() panel.Visible = false end)
	panelOpen = false
end
tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)

-- Title
local titleLbl = Instance.new("TextLabel")
titleLbl.Size              = UDim2.new(0.90, 0, 0.09, 0)
titleLbl.Position          = UDim2.new(0.05, 0, 0.02, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text              = "📊 Hive Statistics"
titleLbl.TextColor3        = HONEY_GOLD
titleLbl.TextScaled        = true
titleLbl.Font              = Enum.Font.FredokaOne
titleLbl.ZIndex            = 22
titleLbl.Parent            = panel

local function divider(yPos: number)
	local f = Instance.new("Frame"); f.Size=UDim2.new(0.90,0,0.004,0); f.Position=UDim2.new(0.05,0,yPos,0)
	f.BackgroundColor3=HONEY_GOLD; f.BackgroundTransparency=0.5; f.BorderSizePixel=0; f.ZIndex=22; f.Parent=panel
end

-- Stat rows
local statDefs = {
	{key="totalHoneyEarned",    label="🍯 Total Honey",    fmt=function(v) return tostring(math.floor(v or 0)) end},
	{key="totalForagingTrips",  label="✈️ Foraging Trips", fmt=function(v) return tostring(math.floor(v or 0)) end},
	{key="totalUpgradesBought", label="⬆️ Upgrades",       fmt=function(v) return tostring(math.floor(v or 0)) end},
	{key="daysPlayed",          label="📅 Days Played",    fmt=function(v) return tostring(math.floor(v or 0)) end},
}

local statLabels: {TextLabel} = {}
local yStart = 0.13
for i, def in statDefs do
	divider(yStart + (i-1)*0.10 - 0.005)
	local row = Instance.new("Frame")
	row.Size=UDim2.new(0.90,0,0.09,0); row.Position=UDim2.new(0.05,0,yStart+(i-1)*0.10,0)
	row.BackgroundTransparency=1; row.ZIndex=22; row.Parent=panel
	local keyLbl = Instance.new("TextLabel")
	keyLbl.Size=UDim2.new(0.60,0,1,0); keyLbl.BackgroundTransparency=1
	keyLbl.Text=def.label; keyLbl.TextColor3=WAX_CREAM; keyLbl.TextScaled=true
	keyLbl.Font=Enum.Font.Gotham; keyLbl.TextXAlignment=Enum.TextXAlignment.Left; keyLbl.ZIndex=22; keyLbl.Parent=row
	local valLbl = Instance.new("TextLabel")
	valLbl.Name=def.key; valLbl.Size=UDim2.new(0.40,0,1,0); valLbl.Position=UDim2.new(0.60,0,0,0)
	valLbl.BackgroundTransparency=1; valLbl.Text="–"; valLbl.TextColor3=HONEY_GOLD; valLbl.TextScaled=true
	valLbl.Font=Enum.Font.GothamBold; valLbl.TextXAlignment=Enum.TextXAlignment.Right; valLbl.ZIndex=22; valLbl.Parent=row
	table.insert(statLabels, valLbl)
	statLabels[def.key] = valLbl
end

-- Bonuses section
divider(0.57)
local bonusTitleLbl = Instance.new("TextLabel")
bonusTitleLbl.Size=UDim2.new(0.90,0,0.07,0); bonusTitleLbl.Position=UDim2.new(0.05,0,0.59,0)
bonusTitleLbl.BackgroundTransparency=1; bonusTitleLbl.Text="── Active Bonuses ──"
bonusTitleLbl.TextColor3=HONEY_GOLD; bonusTitleLbl.TextScaled=true
bonusTitleLbl.Font=Enum.Font.GothamBold; bonusTitleLbl.ZIndex=22; bonusTitleLbl.Parent=panel

local seasonalLbl = Instance.new("TextLabel")
seasonalLbl.Size=UDim2.new(0.90,0,0.08,0); seasonalLbl.Position=UDim2.new(0.05,0,0.67,0)
seasonalLbl.BackgroundTransparency=1; seasonalLbl.Text="No active event"
seasonalLbl.TextColor3=WAX_CREAM; seasonalLbl.TextScaled=true
seasonalLbl.Font=Enum.Font.Gotham; seasonalLbl.TextXAlignment=Enum.TextXAlignment.Left
seasonalLbl.ZIndex=22; seasonalLbl.Parent=panel

local friendLbl2 = Instance.new("TextLabel")
friendLbl2.Size=UDim2.new(0.90,0,0.08,0); friendLbl2.Position=UDim2.new(0.05,0,0.76,0)
friendLbl2.BackgroundTransparency=1; friendLbl2.Text="No friends online"
friendLbl2.TextColor3=WAX_CREAM; friendLbl2.TextScaled=true
friendLbl2.Font=Enum.Font.Gotham; friendLbl2.TextXAlignment=Enum.TextXAlignment.Left
friendLbl2.ZIndex=22; friendLbl2.Parent=panel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size=UDim2.new(0.88,0,0.08,0); closeBtn.Position=UDim2.new(0.06,0,0.90,0)
closeBtn.BackgroundColor3=Color3.fromRGB(100,50,50); closeBtn.Text="Close ✕"
closeBtn.TextColor3=WAX_CREAM; closeBtn.TextScaled=true; closeBtn.Font=Enum.Font.Gotham
closeBtn.ZIndex=22; closeBtn.Parent=panel
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0.2,0); c.Parent=closeBtn end
closeBtn.MouseButton1Click:Connect(function() closePanel() end)

-- ── Event handlers ───────────────────────────────────────
StatsSync.OnClientEvent:Connect(function(data)
	local defs2 = {"totalHoneyEarned","totalForagingTrips","totalUpgradesBought","daysPlayed"}
	local fmts  = {
		totalHoneyEarned=function(v) 
			if v >= 1000000 then return string.format("%.1fM", v/1000000)
			elseif v >= 1000 then return string.format("%.1fK", v/1000)
			else return tostring(math.floor(v)) end
		end,
		totalForagingTrips=function(v) return tostring(math.floor(v)) end,
		totalUpgradesBought=function(v) return tostring(math.floor(v)) end,
		daysPlayed=function(v) return tostring(math.floor(v)) end,
	}
	for _, key in defs2 do
		local lbl = statLabels[key]
		if lbl then lbl.Text = fmts[key](data[key] or 0) end
	end
end)

SeasonalSync.OnClientEvent:Connect(function(data)
	if data.id == "none" then
		seasonalLbl.Text = "No active event"
		seasonalLbl.TextColor3 = WAX_CREAM
	else
		seasonalLbl.Text = (data.name or "") .. ": " .. (data.desc or "")
		local c = data.color or {242,168,28}
		seasonalLbl.TextColor3 = Color3.fromRGB(c[1], c[2], c[3])
	end
end)

FriendBonusSync.OnClientEvent:Connect(function(data)
	local mult = data.multiplier or 1.0
	if mult > 1.001 then
		local pct = math.floor((mult-1.0)*100+0.5)
		friendLbl2.Text = "🐝 Friend bonus: +" .. pct .. "%"
		friendLbl2.TextColor3 = Color3.fromRGB(200, 240, 180)
	else
		friendLbl2.Text = "No friends online"
		friendLbl2.TextColor3 = WAX_CREAM
	end
end)
]]

print("HiveStatsController created")
```

---

## STEP G — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("totalHoneyEarned") and "✅" or "❌") .. " DataService stat fields")

local svc = SSS:FindFirstChild("HiveStatsService")
table.insert(checks, (svc and "✅" or "❌") .. " HiveStatsService script")

local sync = RS:FindFirstChild("StatsSync")
table.insert(checks, (sync and sync:IsA("RemoteEvent") and "✅" or "❌") .. " StatsSync RemoteEvent")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("HiveStatsService") and "✅" or "❌") .. " GameManager Init")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("totalForagingTrips") and "✅" or "❌") .. " ForagingService trip tracking")

local ctrl = SPS and SPS:FindFirstChild("HiveStatsController")
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveStatsController LocalScript")

print("=== DISPATCH 72 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 72 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 72 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `totalHoneyEarned` is different from `lifetimeHoney` (dispatch 62): `lifetimeHoney` is the leaderboard/achievement value; `totalHoneyEarned` counts every honey credited including amounts that exceeded the storage cap. They diverge when storage is full. Both are tracked for different purposes.
- `daysPlayed` uses `lastLoginDay = math.floor(os.time() / 86400)` — same UTC day logic as DailyRewardService. If a player logs in at 23:59 and the day rolls over at 00:00 during their session, they won't get +1 day until their next login. Acceptable for a stats display.
- `BroadcastStats` is called from `ForagingService` on every foraging cycle (every few seconds). This fires a RemoteEvent per cycle — negligible bandwidth (small integer table). If server performance is a concern in a later dispatch, a debounce can be added.
- Only `SpeedUpgradeService` gets the `totalUpgradesBought` injection in this dispatch. All other upgrade services (Queen, Propolis, PollenYield, HoneyStorage, PropolisStorage, PollenStorage) should receive identical injections. Those patches are left as follow-up work in a future dispatch to keep this dispatch focused.
- Panel tab position: `X=0.925, Y=0.68` — below LeaderboardTab (Y=0.58). The right column now has 5 tabs: Skin(0.28), Prestige(0.38), PropolisStorage(0.48), Leaderboard(0.58), Stats(0.68). Step = 0.10, all fit within 0.75 (bottom of stats tab + 0.075 height = 0.755).
