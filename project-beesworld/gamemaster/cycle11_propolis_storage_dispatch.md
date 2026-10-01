# Dispatch 61 — PropolisStorageUpgradeService
## Cycle 11 · A Bee's World

**Feature:** Max propolis storage capacity upgrades — 4 tiers raising the cap from a base 500 to 10,000. Propolis is rarer than honey; its cap is lower and its upgrades cost honey (not propolis), mirroring the PropolisYieldUpgrade cost direction. Creates a secondary urgency loop alongside the honey storage loop.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 60 (HoneyStorageUpgradeService)

---

## DESIGN

| Tier | Max Propolis | Cost (Honey) | Label |
|------|-------------|-------------|-------|
| 0 (base) | 500 | — | Propolis Pot |
| 1 | 1,200 | 1,000 | Large Pot |
| 2 | 3,000 | 4,000 | Resin Cache |
| 3 | 7,000 | 12,000 | Sealed Vault |
| 4 | 15,000 | 30,000 | Infinite Resin |

Propolis storage costs honey (honey sink) — consistent with PropolisYieldUpgrade cost direction.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | `PROPOLIS_STORAGE_UPGRADES` table + constants |
| `DataService` | `propolisStorageTier = 0` migration |
| `PropolisStorageUpgradeService` (new Script in SSS) | GetMaxPropolis, BuyPropolisStorage, PropolisStorageSync |
| `ForagingService` | enforce propolis cap before crediting propolis yield |
| `GameManager` | Init call |
| `PropolisStorageController` (new LocalScript) | 🧫 tab, upgrade panel |

---

## STEP A — Config additions

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local clone = cfg:Clone()
clone.Name = "Config_WORKING"

local anchor = 'STORAGE_MAX_TIER'
local found = clone.Source:find(anchor, 1, true)
assert(found, "STORAGE_MAX_TIER anchor not found")

local lineEnd = clone.Source:find("\n", found, true)
local INJECT = [[

-- Propolis Storage Upgrades
Config.PROPOLIS_STORAGE_UPGRADES = {
	{tier=1, maxPropolis=1200,  cost=1000,  label="Large Pot"},
	{tier=2, maxPropolis=3000,  cost=4000,  label="Resin Cache"},
	{tier=3, maxPropolis=7000,  cost=12000, label="Sealed Vault"},
	{tier=4, maxPropolis=15000, cost=30000, label="Infinite Resin"},
}
Config.PROPOLIS_STORAGE_BASE_MAX = 500
Config.PROPOLIS_STORAGE_MAX_TIER = 4
]]

clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config propolis storage additions applied")
```

**Verify:**
```lua
local cfg = game:GetService("ServerScriptService"):FindFirstChild("Config")
print(cfg and cfg.Source:find("PROPOLIS_STORAGE_UPGRADES") and "OK" or "MISSING")
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

local anchor = 'storageTier = 0'
local found = clone.Source:find(anchor, 1, true)
assert(found, "storageTier anchor not found in DataService")

local lineEnd = clone.Source:find("\n", found, true)
local INJECT = "\n\t\tpropolisStorageTier = 0, -- propolis storage upgrade tier"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService propolisStorageTier migration applied")
```

---

## STEP C — PropolisStorageUpgradeService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local PropolisStorageSync = Instance.new("RemoteEvent")
PropolisStorageSync.Name = "PropolisStorageSync"
PropolisStorageSync.Parent = RS

local BuyPropolisStorage = Instance.new("RemoteFunction")
BuyPropolisStorage.Name = "BuyPropolisStorage"
BuyPropolisStorage.Parent = RS

local svc = Instance.new("Script")
svc.Name = "PropolisStorageUpgradeService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- PropolisStorageUpgradeService
-- Manages propolis storage capacity upgrades. Costs honey (not propolis).

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local PS  = game:GetService("Players")

local Config      = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local PropolisStorageSync = RS:WaitForChild("PropolisStorageSync")
local BuyPropolisStorage  = RS:WaitForChild("BuyPropolisStorage")

local PropolisStorageUpgradeService = {}

local function getMaxPropolis(tier: number): number
	if tier <= 0 then return Config.PROPOLIS_STORAGE_BASE_MAX end
	for _, entry in Config.PROPOLIS_STORAGE_UPGRADES do
		if entry.tier == tier then return entry.maxPropolis end
	end
	return Config.PROPOLIS_STORAGE_BASE_MAX
end

local function getNextCost(tier: number): number?
	if tier >= Config.PROPOLIS_STORAGE_MAX_TIER then return nil end
	for _, entry in Config.PROPOLIS_STORAGE_UPGRADES do
		if entry.tier == tier + 1 then return entry.cost end
	end
	return nil
end

local function syncPlayer(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local tier = profile.propolisStorageTier or 0
	PropolisStorageSync:FireClient(player, {
		tier        = tier,
		maxTier     = Config.PROPOLIS_STORAGE_MAX_TIER,
		maxPropolis = getMaxPropolis(tier),
		nextCost    = getNextCost(tier),
	})
end

BuyPropolisStorage.OnServerInvoke = function(player: Player): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "profile unavailable" end
	local tier = profile.propolisStorageTier or 0
	if tier >= Config.PROPOLIS_STORAGE_MAX_TIER then
		return false, "already max propolis storage tier"
	end
	local cost = getNextCost(tier)
	if not cost then return false, "no next tier" end
	if (profile.honey or 0) < cost then
		return false, "not enough honey"
	end
	profile.honey -= cost
	profile.propolisStorageTier = tier + 1
	syncPlayer(player)
	local HoneySync = RS:FindFirstChild("HoneySync")
	if HoneySync then HoneySync:FireClient(player, profile.honey) end
	return true, "ok"
end

function PropolisStorageUpgradeService.GetMaxPropolis(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return Config.PROPOLIS_STORAGE_BASE_MAX end
	return getMaxPropolis(profile.propolisStorageTier or 0)
end

function PropolisStorageUpgradeService.Init()
	PS.PlayerAdded:Connect(syncPlayer)
	for _, player in PS:GetPlayers() do
		task.spawn(syncPlayer, player)
	end
	print("[PropolisStorageUpgradeService] ready")
end

return PropolisStorageUpgradeService
]]

print("PropolisStorageUpgradeService created")
```

---

## STEP D — Enforce propolis cap in ForagingService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- 1. Add require after HoneyStorageUpgradeService require
local reqAnchor = 'local HoneyStorageUpgradeService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "HoneyStorageUpgradeService require not found in ForagingService")
local lineEnd = clone.Source:find("\n", found, true)
local INJECT_REQ = "\nlocal PropolisStorageUpgradeService = require(SSS:WaitForChild(\"PropolisStorageUpgradeService\"))"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_REQ .. clone.Source:sub(lineEnd + 1)

-- 2. Cap propolis credit
-- Find propolis honey credit line (pattern: profile.propolis +=)
local capAnchor = 'profile.propolis +='
local found2 = clone.Source:find(capAnchor, 1, true)
if not found2 then
	capAnchor = 'profile.propolis = profile.propolis +'
	found2 = clone.Source:find(capAnchor, 1, true)
end
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	local INJECT_CAP = [[

	-- Enforce propolis storage cap
	local maxPropolis = PropolisStorageUpgradeService.GetMaxPropolis(player)
	if profile.propolis > maxPropolis then profile.propolis = maxPropolis end]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT_CAP .. clone.Source:sub(lineEnd2 + 1)
	print("Propolis cap injected after propolis credit")
else
	print("WARNING: propolis credit line not found — add cap manually:")
	print("  local maxPropolis = PropolisStorageUpgradeService.GetMaxPropolis(player)")
	print("  if profile.propolis > maxPropolis then profile.propolis = maxPropolis end")
end

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService propolis cap patch applied")
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

local anchor = 'local HoneyStorageUpgradeService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "HoneyStorageUpgradeService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal PropolisStorageUpgradeService = require(SSS:WaitForChild(\"PropolisStorageUpgradeService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'HoneyStorageUpgradeService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "HoneyStorageUpgradeService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nPropolisStorageUpgradeService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager PropolisStorageUpgradeService.Init() injected")
```

---

## STEP F — PropolisStorageController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name = "PropolisStorageController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- PropolisStorageController — 🧫 propolis storage upgrade tab

local PS   = game:GetService("Players")
local RS   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local beesGui   = playerGui:WaitForChild("BeesWorldGui")
local mainFrame = beesGui:WaitForChild("MainFrame")

local PropolisStorageSync = RS:WaitForChild("PropolisStorageSync")
local BuyPropolisStorage  = RS:WaitForChild("BuyPropolisStorage")

local HONEY_GOLD   = Color3.fromRGB(242, 168, 28)
local PROP_BROWN   = Color3.fromRGB(122, 74, 34)
local WAX_CREAM    = Color3.fromRGB(232, 212, 154)
local RESIN_CLR    = Color3.fromRGB(160, 90, 200)   -- purple-violet for propolis
local TEXT_DARK    = Color3.fromRGB(40, 25, 10)
local PANEL_OPEN_X  = 0.60
local PANEL_CLOSE_X = 1.02
local panelOpen    = false
local busy         = false

-- tab button (right column, below prestige tab)
local tabBtn = Instance.new("TextButton")
tabBtn.Name             = "PropolisStorageTabBtn"
tabBtn.Size             = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position         = UDim2.new(0.925, 0, 0.50, 0)   -- right col below prestige
tabBtn.BackgroundColor3 = PROP_BROWN
tabBtn.BorderSizePixel  = 0
tabBtn.Text             = "🧫"
tabBtn.TextScaled       = true
tabBtn.ZIndex           = 24
tabBtn.Parent           = mainFrame
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.15, 0)
	c.Parent = tabBtn
end

-- badge
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

-- panel
local panel = Instance.new("Frame")
panel.Name              = "PropolisStoragePanel"
panel.Size              = UDim2.new(0.38, 0, 0.50, 0)
panel.Position          = UDim2.new(PANEL_CLOSE_X, 0, 0.25, 0)
panel.BackgroundColor3  = PROP_BROWN
panel.BorderSizePixel   = 0
panel.ZIndex            = 20
panel.ClipsDescendants  = true
panel.Parent            = mainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.04, 0); c.Parent = panel end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0.13, 0)
title.Position = UDim2.new(0, 0, 0.01, 0)
title.BackgroundTransparency = 1
title.Text = "🧫 Propolis Storage"
title.TextColor3 = HONEY_GOLD
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.ZIndex = 21
title.Parent = panel

local capLabel = Instance.new("TextLabel")
capLabel.Name = "CapLabel"
capLabel.Size = UDim2.new(0.9, 0, 0.09, 0)
capLabel.Position = UDim2.new(0.05, 0, 0.15, 0)
capLabel.BackgroundTransparency = 1
capLabel.Text = "Max: 500 🍯"
capLabel.TextColor3 = WAX_CREAM
capLabel.TextScaled = true
capLabel.Font = Enum.Font.Gotham
capLabel.ZIndex = 21
capLabel.Parent = panel

local tierLbl = Instance.new("TextLabel")
tierLbl.Name = "TierLabel"
tierLbl.Size = UDim2.new(0.9, 0, 0.08, 0)
tierLbl.Position = UDim2.new(0.05, 0, 0.25, 0)
tierLbl.BackgroundTransparency = 1
tierLbl.Text = "Tier 0 / 4"
tierLbl.TextColor3 = WAX_CREAM
tierLbl.TextScaled = true
tierLbl.Font = Enum.Font.Gotham
tierLbl.ZIndex = 21
tierLbl.Parent = panel

local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Name = "UpgradeBtn"
upgradeBtn.Size = UDim2.new(0.88, 0, 0.14, 0)
upgradeBtn.Position = UDim2.new(0.06, 0, 0.36, 0)
upgradeBtn.BackgroundColor3 = RESIN_CLR
upgradeBtn.BorderSizePixel = 0
upgradeBtn.Text = "Upgrade  1,000 🍯"
upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upgradeBtn.TextScaled = true
upgradeBtn.Font = Enum.Font.GothamBold
upgradeBtn.ZIndex = 22
upgradeBtn.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = upgradeBtn end

local noteLbl = Instance.new("TextLabel")
noteLbl.Size = UDim2.new(0.9, 0, 0.07, 0)
noteLbl.Position = UDim2.new(0.05, 0, 0.52, 0)
noteLbl.BackgroundTransparency = 1
noteLbl.Text = "Costs Honey 🍯"
noteLbl.TextColor3 = HONEY_GOLD
noteLbl.TextScaled = true
noteLbl.Font = Enum.Font.Gotham
noteLbl.ZIndex = 21
noteLbl.Parent = panel

local maxLbl = Instance.new("TextLabel")
maxLbl.Size = UDim2.new(0.9, 0, 0.10, 0)
maxLbl.Position = UDim2.new(0.05, 0, 0.36, 0)
maxLbl.BackgroundTransparency = 1
maxLbl.Text = "✨ INFINITE RESIN"
maxLbl.TextColor3 = RESIN_CLR
maxLbl.TextScaled = true
maxLbl.Font = Enum.Font.GothamBold
maxLbl.ZIndex = 22
maxLbl.Visible = false
maxLbl.Parent = panel

local toast = Instance.new("Frame")
toast.Size = UDim2.new(0.88, 0, 0.12, 0)
toast.Position = UDim2.new(0.06, 0, -0.15, 0)
toast.BackgroundColor3 = RESIN_CLR
toast.BorderSizePixel = 0
toast.ZIndex = 25
toast.Visible = false
toast.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = toast end
local toastLbl = Instance.new("TextLabel")
toastLbl.Size = UDim2.new(1, 0, 1, 0)
toastLbl.BackgroundTransparency = 1
toastLbl.Text = "Storage Upgraded!"
toastLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
toastLbl.TextScaled = true
toastLbl.Font = Enum.Font.GothamBold
toastLbl.ZIndex = 26
toastLbl.Parent = toast

local function fmt(n: number): string
	if n >= 1000000 then return string.format("%.1fM", n/1000000)
	elseif n >= 1000 then return string.format("%.1fK", n/1000)
	else return tostring(n) end
end

local function openPanel()
	if panelOpen then return end; panelOpen = true
	TweenService:Create(panel, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(PANEL_OPEN_X, 0, 0.25, 0)}):Play()
end
local function closePanel()
	if not panelOpen then return end; panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(PANEL_CLOSE_X, 0, 0.25, 0)}):Play()
end
local function showToast(msg: string)
	toastLbl.Text = msg; toast.Visible = true
	toast.Position = UDim2.new(0.06, 0, -0.15, 0)
	TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.06, 0, 0.62, 0)}):Play()
	task.delay(2.2, function()
		TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.06, 0, -0.15, 0)}):Play()
		task.wait(0.2); toast.Visible = false
	end)
end

local function refreshUI(data: {tier: number, maxTier: number, maxPropolis: number, nextCost: number?})
	capLabel.Text = "Max: " .. fmt(data.maxPropolis) .. " propolis"
	tierLbl.Text  = "Tier " .. data.tier .. " / " .. data.maxTier
	if data.tier >= data.maxTier then
		upgradeBtn.Visible = false; noteLbl.Visible = false; maxLbl.Visible = true
	else
		upgradeBtn.Visible = true; noteLbl.Visible = true; maxLbl.Visible = false
		if data.nextCost then upgradeBtn.Text = "Upgrade  " .. fmt(data.nextCost) .. " 🍯" end
	end
	busy = false
end

PropolisStorageSync.OnClientEvent:Connect(refreshUI)

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)

upgradeBtn.MouseButton1Click:Connect(function()
	if busy then return end; busy = true
	upgradeBtn.Text = "..."
	local ok, _ = BuyPropolisStorage:InvokeServer()
	if ok then showToast("Propolis Storage Upgraded! 🧫")
	else showToast("Need more honey 🍯"); busy = false end
end)
]]

print("PropolisStorageController created")
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
table.insert(checks, (cfg and cfg.Source:find("PROPOLIS_STORAGE_UPGRADES") and "✅" or "❌") .. " Config PROPOLIS_STORAGE_UPGRADES")

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("propolisStorageTier") and "✅" or "❌") .. " DataService propolisStorageTier")

local svc = SSS:FindFirstChild("PropolisStorageUpgradeService")
table.insert(checks, (svc and "✅" or "❌") .. " PropolisStorageUpgradeService script")

local ss = RS:FindFirstChild("PropolisStorageSync")
table.insert(checks, (ss and "✅" or "❌") .. " PropolisStorageSync RemoteEvent")

local rf = RS:FindFirstChild("BuyPropolisStorage")
table.insert(checks, (rf and "✅" or "❌") .. " BuyPropolisStorage RemoteFunction")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetMaxPropolis") and "✅" or "❌") .. " ForagingService propolis cap")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("PropolisStorageUpgradeService") and "✅" or "❌") .. " GameManager Init")

local ctrl = SPS and SPS:FindFirstChild("PropolisStorageController")
table.insert(checks, (ctrl and "✅" or "❌") .. " PropolisStorageController")

print("=== DISPATCH 61 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 61 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 61 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## RESOURCE ECONOMY SUMMARY (post dispatch 61)

| Resource | Base cap | Max cap | Upgrade cost |
|----------|----------|---------|-------------|
| Honey | 2,000 | 100,000 | 81,000 honey (5 tiers) |
| Propolis | 500 | 15,000 | 47,000 honey (4 tiers) |

Both caps enforced server-side before crediting yield. Total new honey sinks: 128,000 honey for maxing both storage tracks. Combined with upgrades: ~850,000 honey total to max the full game.
