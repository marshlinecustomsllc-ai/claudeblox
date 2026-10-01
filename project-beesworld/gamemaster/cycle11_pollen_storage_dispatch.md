# Dispatch 66 — PollenStorageUpgradeService
## Cycle 11 · A Bee's World

**Feature:** Pollen storage capacity upgrades — 3 tiers raising the cap from a base 300 to 5,000. Pollen is the rarest resource (foraging only, not sold, feeds into PollenYield upgrades). Cap upgrades cost propolis (cross-sink: propolis → more pollen capacity → more pollen → more PollenYield upgrades).
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 65 (TutorialService)

---

## DESIGN

| Tier | Max Pollen | Cost (Propolis) | Label |
|------|-----------|----------------|-------|
| 0 (base) | 300 | — | Pollen Bag |
| 1 | 800 | 50 | Large Bag |
| 2 | 2,000 | 200 | Pollen Vault |
| 3 | 5,000 | 600 | Infinite Bloom |

Pollen storage costs propolis — creates a loop: propolis → pollen cap → more pollen → higher PollenYield tier → more pollen → repeat.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | `POLLEN_STORAGE_UPGRADES` table + constants |
| `DataService` | `pollenStorageTier = 0` migration |
| `PollenStorageUpgradeService` (new Script in SSS) | GetMaxPollen, BuyPollenStorage RF (costs propolis), PollenStorageSync RE |
| `ForagingService` | enforce pollen cap |
| `GameManager` | Init call |
| `PollenStorageController` (new LocalScript) | 🌼 tab, upgrade panel |

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
if not found then
	anchor = 'STORAGE_MAX_TIER'
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "storage tier anchor not found in Config")
local lineEnd = clone.Source:find("\n", found, true)

local INJECT = [[

-- Pollen Storage Upgrades (costs propolis)
Config.POLLEN_STORAGE_UPGRADES = {
	{tier=1, maxPollen=800,  cost=50,  label="Large Bag"},
	{tier=2, maxPollen=2000, cost=200, label="Pollen Vault"},
	{tier=3, maxPollen=5000, cost=600, label="Infinite Bloom"},
}
Config.POLLEN_STORAGE_BASE_MAX = 300
Config.POLLEN_STORAGE_MAX_TIER = 3
]]

clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config POLLEN_STORAGE_UPGRADES added")
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

local anchor = 'tutorialSeen = false'
local found = clone.Source:find(anchor, 1, true)
assert(found, "tutorialSeen anchor not found")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\n\t\tpollenStorageTier = 0,      -- pollen storage upgrade tier" .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService pollenStorageTier migration applied")
```

---

## STEP C — PollenStorageUpgradeService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local PollenStorageSync = Instance.new("RemoteEvent")
PollenStorageSync.Name = "PollenStorageSync"
PollenStorageSync.Parent = RS

local BuyPollenStorage = Instance.new("RemoteFunction")
BuyPollenStorage.Name = "BuyPollenStorage"
BuyPollenStorage.Parent = RS

local svc = Instance.new("Script")
svc.Name = "PollenStorageUpgradeService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- PollenStorageUpgradeService
-- Manages pollen storage capacity upgrades. Costs PROPOLIS (not honey).

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local PS  = game:GetService("Players")

local Config      = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local PollenStorageSync = RS:WaitForChild("PollenStorageSync")
local BuyPollenStorage  = RS:WaitForChild("BuyPollenStorage")

local PollenStorageUpgradeService = {}

local function getMaxPollen(tier: number): number
	if tier <= 0 then return Config.POLLEN_STORAGE_BASE_MAX end
	for _, entry in Config.POLLEN_STORAGE_UPGRADES do
		if entry.tier == tier then return entry.maxPollen end
	end
	return Config.POLLEN_STORAGE_BASE_MAX
end

local function getNextCost(tier: number): number?
	if tier >= Config.POLLEN_STORAGE_MAX_TIER then return nil end
	for _, entry in Config.POLLEN_STORAGE_UPGRADES do
		if entry.tier == tier + 1 then return entry.cost end
	end
	return nil
end

local function syncPlayer(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local tier = profile.pollenStorageTier or 0
	PollenStorageSync:FireClient(player, {
		tier      = tier,
		maxTier   = Config.POLLEN_STORAGE_MAX_TIER,
		maxPollen = getMaxPollen(tier),
		nextCost  = getNextCost(tier),
	})
end

BuyPollenStorage.OnServerInvoke = function(player: Player): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "profile unavailable" end
	local tier = profile.pollenStorageTier or 0
	if tier >= Config.POLLEN_STORAGE_MAX_TIER then
		return false, "already max pollen storage tier"
	end
	local cost = getNextCost(tier)
	if not cost then return false, "no next tier" end
	if (profile.propolis or 0) < cost then
		return false, "not enough propolis"
	end
	profile.propolis -= cost
	profile.pollenStorageTier = tier + 1
	syncPlayer(player)
	-- Sync propolis HUD
	local PropolisSync = RS:FindFirstChild("PropolisSync")
	if PropolisSync then PropolisSync:FireClient(player, profile.propolis) end
	return true, "ok"
end

function PollenStorageUpgradeService.GetMaxPollen(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return Config.POLLEN_STORAGE_BASE_MAX end
	return getMaxPollen(profile.pollenStorageTier or 0)
end

function PollenStorageUpgradeService.Init()
	PS.PlayerAdded:Connect(syncPlayer)
	for _, player in PS:GetPlayers() do
		task.spawn(syncPlayer, player)
	end
	print("[PollenStorageUpgradeService] ready")
end

return PollenStorageUpgradeService
]]

print("PollenStorageUpgradeService created")
```

---

## STEP D — ForagingService: enforce pollen cap

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- Add require after LeaderboardService require
local reqAnchor = 'local LeaderboardService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "LeaderboardService require not found in ForagingService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal PollenStorageUpgradeService = require(SSS:WaitForChild(\"PollenStorageUpgradeService\"))" .. clone.Source:sub(lineEnd + 1)

-- Cap pollen after pollen credit
local pollenAnchor = 'profile.pollen +='
local found2 = clone.Source:find(pollenAnchor, 1, true)
if not found2 then
	pollenAnchor = 'profile.pollen = profile.pollen +'
	found2 = clone.Source:find(pollenAnchor, 1, true)
end
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	local INJECT_CAP = [[

	local maxPollen = PollenStorageUpgradeService.GetMaxPollen(player)
	if profile.pollen > maxPollen then profile.pollen = maxPollen end]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT_CAP .. clone.Source:sub(lineEnd2 + 1)
	print("Pollen cap injected")
else
	print("WARNING: pollen credit line not found — add cap manually")
end

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService pollen cap patch applied")
```

---

## STEP E — GameManager Init

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local TutorialService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "TutorialService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal PollenStorageUpgradeService = require(SSS:WaitForChild(\"PollenStorageUpgradeService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'TutorialService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "TutorialService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nPollenStorageUpgradeService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager PollenStorageUpgradeService.Init() injected")
```

---

## STEP F — PollenStorageController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name = "PollenStorageController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- PollenStorageController — 🌼 pollen storage upgrade tab

local PS   = game:GetService("Players")
local RS   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local beesGui   = playerGui:WaitForChild("BeesWorldGui")
local mainFrame = beesGui:WaitForChild("MainFrame")

local PollenStorageSync = RS:WaitForChild("PollenStorageSync")
local BuyPollenStorage  = RS:WaitForChild("BuyPollenStorage")

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(122, 74, 34)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local POLLEN_CLR  = Color3.fromRGB(200, 220, 60)   -- yellow-green for pollen
local PANEL_OPEN_X  = 0.10
local PANEL_CLOSE_X = -0.42
local panelOpen = false
local busy      = false

local tabBtn = Instance.new("TextButton")
tabBtn.Name             = "PollenStorageTabBtn"
tabBtn.Size             = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position         = UDim2.new(0.085, 0, 0.45, 0)   -- just right of left column pollen tab
tabBtn.BackgroundColor3 = PROP_BROWN
tabBtn.BorderSizePixel  = 0
tabBtn.Text             = "🌼"
tabBtn.TextScaled       = true
tabBtn.ZIndex           = 24
tabBtn.Parent           = mainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15, 0); c.Parent = tabBtn end

local badge = Instance.new("Frame")
badge.Name             = "NotifBadge"
badge.Size             = UDim2.new(0.28, 0, 0.28, 0)
badge.Position         = UDim2.new(0.72, 0, -0.06, 0)
badge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
badge.BorderSizePixel  = 0
badge.ZIndex           = 26
badge.Visible          = false
badge.Parent           = tabBtn
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = badge end

local panel = Instance.new("Frame")
panel.Name              = "PollenStoragePanel"
panel.Size              = UDim2.new(0.35, 0, 0.45, 0)
panel.Position          = UDim2.new(PANEL_CLOSE_X, 0, 0.28, 0)
panel.BackgroundColor3  = PROP_BROWN
panel.BorderSizePixel   = 0
panel.ZIndex            = 20
panel.ClipsDescendants  = true
panel.Parent            = mainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.04, 0); c.Parent = panel end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.14, 0); title.Position = UDim2.new(0, 0, 0.00, 0)
title.BackgroundTransparency = 1; title.Text = "🌼 Pollen Storage"
title.TextColor3 = HONEY_GOLD; title.TextScaled = true; title.Font = Enum.Font.GothamBold
title.ZIndex = 21; title.Parent = panel

local capLbl = Instance.new("TextLabel")
capLbl.Name = "CapLabel"; capLbl.Size = UDim2.new(0.9, 0, 0.10, 0)
capLbl.Position = UDim2.new(0.05, 0, 0.16, 0); capLbl.BackgroundTransparency = 1
capLbl.Text = "Max: 300 pollen"; capLbl.TextColor3 = WAX_CREAM
capLbl.TextScaled = true; capLbl.Font = Enum.Font.Gotham; capLbl.ZIndex = 21; capLbl.Parent = panel

local tierLbl = Instance.new("TextLabel")
tierLbl.Name = "TierLabel"; tierLbl.Size = UDim2.new(0.9, 0, 0.09, 0)
tierLbl.Position = UDim2.new(0.05, 0, 0.27, 0); tierLbl.BackgroundTransparency = 1
tierLbl.Text = "Tier 0 / 3"; tierLbl.TextColor3 = WAX_CREAM
tierLbl.TextScaled = true; tierLbl.Font = Enum.Font.Gotham; tierLbl.ZIndex = 21; tierLbl.Parent = panel

local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Name = "UpgradeBtn"; upgradeBtn.Size = UDim2.new(0.88, 0, 0.15, 0)
upgradeBtn.Position = UDim2.new(0.06, 0, 0.38, 0); upgradeBtn.BackgroundColor3 = POLLEN_CLR
upgradeBtn.BorderSizePixel = 0; upgradeBtn.Text = "Upgrade  50 propolis"
upgradeBtn.TextColor3 = Color3.fromRGB(40, 30, 0); upgradeBtn.TextScaled = true
upgradeBtn.Font = Enum.Font.GothamBold; upgradeBtn.ZIndex = 22; upgradeBtn.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = upgradeBtn end

local noteLbl = Instance.new("TextLabel")
noteLbl.Size = UDim2.new(0.9, 0, 0.08, 0); noteLbl.Position = UDim2.new(0.05, 0, 0.55, 0)
noteLbl.BackgroundTransparency = 1; noteLbl.Text = "Costs Propolis 🍬"
noteLbl.TextColor3 = Color3.fromRGB(180, 220, 80); noteLbl.TextScaled = true
noteLbl.Font = Enum.Font.Gotham; noteLbl.ZIndex = 21; noteLbl.Parent = panel

local maxLbl = Instance.new("TextLabel")
maxLbl.Size = UDim2.new(0.9, 0, 0.12, 0); maxLbl.Position = UDim2.new(0.05, 0, 0.38, 0)
maxLbl.BackgroundTransparency = 1; maxLbl.Text = "✨ INFINITE BLOOM"
maxLbl.TextColor3 = POLLEN_CLR; maxLbl.TextScaled = true; maxLbl.Font = Enum.Font.GothamBold
maxLbl.ZIndex = 22; maxLbl.Visible = false; maxLbl.Parent = panel

local toast = Instance.new("Frame")
toast.Size = UDim2.new(0.88, 0, 0.14, 0); toast.Position = UDim2.new(0.06, 0, -0.18, 0)
toast.BackgroundColor3 = POLLEN_CLR; toast.BorderSizePixel = 0; toast.ZIndex = 25
toast.Visible = false; toast.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = toast end
local toastLbl = Instance.new("TextLabel")
toastLbl.Size = UDim2.new(1,0,1,0); toastLbl.BackgroundTransparency=1
toastLbl.Text = "Storage Upgraded!"; toastLbl.TextColor3 = Color3.fromRGB(40,30,0)
toastLbl.TextScaled = true; toastLbl.Font = Enum.Font.GothamBold; toastLbl.ZIndex=26; toastLbl.Parent=toast

local function fmt(n: number): string
	if n >= 1000000 then return string.format("%.1fM", n/1000000)
	elseif n >= 1000 then return string.format("%.1fK", n/1000)
	else return tostring(n) end
end

local function openPanel()
	if panelOpen then return end; panelOpen = true
	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(PANEL_OPEN_X, 0, 0.28, 0)}):Play()
end
local function closePanel()
	if not panelOpen then return end; panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(PANEL_CLOSE_X, 0, 0.28, 0)}):Play()
end
local function showToast(msg: string)
	toastLbl.Text = msg; toast.Visible = true
	toast.Position = UDim2.new(0.06, 0, -0.18, 0)
	TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.06, 0, 0.65, 0)}):Play()
	task.delay(2.2, function()
		TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.06, 0, -0.18, 0)}):Play()
		task.wait(0.2); toast.Visible = false
	end)
end

local function refreshUI(data: {tier:number, maxTier:number, maxPollen:number, nextCost:number?})
	capLbl.Text = "Max: " .. fmt(data.maxPollen) .. " pollen"
	tierLbl.Text = "Tier " .. data.tier .. " / " .. data.maxTier
	if data.tier >= data.maxTier then
		upgradeBtn.Visible=false; noteLbl.Visible=false; maxLbl.Visible=true
	else
		upgradeBtn.Visible=true; noteLbl.Visible=true; maxLbl.Visible=false
		if data.nextCost then upgradeBtn.Text = "Upgrade  " .. fmt(data.nextCost) .. " propolis" end
	end
	busy = false
end

PollenStorageSync.OnClientEvent:Connect(refreshUI)

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)

upgradeBtn.MouseButton1Click:Connect(function()
	if busy then return end; busy = true
	upgradeBtn.Text = "..."
	local ok, _ = BuyPollenStorage:InvokeServer()
	if ok then showToast("Pollen Storage Upgraded! 🌼")
	else showToast("Need more propolis 🍬"); busy = false end
end)
]]

print("PollenStorageController created")
```

---

## STEP G — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}
local cfg = SSS:FindFirstChild("Config")
table.insert(checks, (cfg and cfg.Source:find("POLLEN_STORAGE_UPGRADES") and "✅" or "❌") .. " Config POLLEN_STORAGE_UPGRADES")
local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("pollenStorageTier") and "✅" or "❌") .. " DataService pollenStorageTier")
local svc = SSS:FindFirstChild("PollenStorageUpgradeService")
table.insert(checks, (svc and "✅" or "❌") .. " PollenStorageUpgradeService script")
local ss = RS:FindFirstChild("PollenStorageSync")
table.insert(checks, (ss and "✅" or "❌") .. " PollenStorageSync RE")
local rf = RS:FindFirstChild("BuyPollenStorage")
table.insert(checks, (rf and "✅" or "❌") .. " BuyPollenStorage RF")
local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetMaxPollen") and "✅" or "❌") .. " ForagingService pollen cap")
local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("PollenStorageUpgradeService") and "✅" or "❌") .. " GameManager Init")
local ctrl = SPS and SPS:FindFirstChild("PollenStorageController")
table.insert(checks, (ctrl and "✅" or "❌") .. " PollenStorageController")

print("=== DISPATCH 66 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 66 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements only | 0 |
| **Dispatch 66 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## RESOURCE ECONOMY SUMMARY (post dispatch 66)

| Resource | Base cap | Max cap | Upgrade cost |
|----------|----------|---------|-------------|
| Honey | 2,000 | 100,000 | 81,000 honey |
| Propolis | 500 | 15,000 | 47,000 honey |
| Pollen | 300 | 5,000 | 850 propolis |

Complete symmetric storage system across all 3 resources.
