# Dispatch 60 — HoneyStorageUpgradeService
## Cycle 11 · A Bee's World

**Feature:** Max honey storage capacity upgrades — 5 tiers raising the cap from a base 2,000 to 50,000. Creates urgency: players who hit the cap waste yield until they buy storage. Drives the upgrade economy deeper into mid-game.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 59 (NotificationBadge patches)

---

## DESIGN

| Tier | Max Honey | Cost (Honey) | Label |
|------|-----------|-------------|-------|
| 0 (base) | 2,000 | — | Starter Comb |
| 1 | 5,000 | 500 | Expanded Comb |
| 2 | 12,000 | 2,500 | Deep Storage |
| 3 | 25,000 | 8,000 | Vault Comb |
| 4 | 50,000 | 20,000 | Royal Vault |
| 5 | 100,000 | 50,000 | Infinite Hive |

Storage upgrades cost the honey already banked — they are a mid-game commitment.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` (ModuleScript) | `STORAGE_UPGRADES` table + constants |
| `DataService` (ModuleScript) | `storageTier = 0` migration |
| `HoneyStorageUpgradeService` (new Script in SSS) | GetMaxHoney, BuyStorageTier, StorageSync |
| `ResourceService` / `ForagingService` | enforce cap before crediting honey |
| `GameManager` (Script) | Init call |
| `HoneyStorageController` (new LocalScript) | 🏺 tab, upgrade panel |

---

## STEP A — Config additions

Open **Config** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local clone = cfg:Clone()
clone.Name = "Config_WORKING"

-- Anchor: after PRESTIGE constants block (or any known constant)
local anchor = 'PRESTIGE_MAX_TIER'
local found = clone.Source:find(anchor, 1, true)
assert(found, "PRESTIGE_MAX_TIER anchor not found in Config")

-- Find end of that line
local lineEnd = clone.Source:find("\n", found, true)

local INJECT = [[

-- Honey Storage Upgrades
Config.STORAGE_UPGRADES = {
	{tier=1, maxHoney=5000,   cost=500,   label="Expanded Comb"},
	{tier=2, maxHoney=12000,  cost=2500,  label="Deep Storage"},
	{tier=3, maxHoney=25000,  cost=8000,  label="Vault Comb"},
	{tier=4, maxHoney=50000,  cost=20000, label="Royal Vault"},
	{tier=5, maxHoney=100000, cost=50000, label="Infinite Hive"},
}
Config.STORAGE_BASE_MAX  = 2000
Config.STORAGE_MAX_TIER  = 5
]]

clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config storage additions applied")
```

**Verify:**
```lua
local cfg = game:GetService("ServerScriptService"):FindFirstChild("Config")
local ok = cfg and cfg.Source:find("STORAGE_UPGRADES") and cfg.Source:find("STORAGE_BASE_MAX")
print(ok and "Config OK" or "MISSING")
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

-- Anchor: after prestigeTier in defaults block
local anchor = 'prestigeTier = 0'
local found = clone.Source:find(anchor, 1, true)
assert(found, "prestigeTier anchor not found in DataService")

local lineEnd = clone.Source:find("\n", found, true)
local INJECT = "\n\t\tstorageTier = 0,         -- honey storage upgrade tier"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService storageTier migration applied")
```

**Verify:**
```lua
local ds = game:GetService("ServerScriptService"):FindFirstChild("DataService")
print(ds and ds.Source:find("storageTier") and "OK" or "MISSING")
```

---

## STEP C — HoneyStorageUpgradeService (new Script)

Command Bar — create the service:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- RemoteEvent
local StorageSync = Instance.new("RemoteEvent")
StorageSync.Name = "StorageSync"
StorageSync.Parent = RS

-- RemoteFunction
local BuyStorageTier = Instance.new("RemoteFunction")
BuyStorageTier.Name = "BuyStorageTier"
BuyStorageTier.Parent = RS

-- Service Script
local svc = Instance.new("Script")
svc.Name = "HoneyStorageUpgradeService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- HoneyStorageUpgradeService
-- Manages honey storage capacity upgrades.

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local PS  = game:GetService("Players")

local Config      = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local StorageSync    = RS:WaitForChild("StorageSync")
local BuyStorageTier = RS:WaitForChild("BuyStorageTier")

local HoneyStorageUpgradeService = {}

local function getMaxHoney(tier: number): number
	if tier <= 0 then return Config.STORAGE_BASE_MAX end
	for _, entry in Config.STORAGE_UPGRADES do
		if entry.tier == tier then return entry.maxHoney end
	end
	return Config.STORAGE_BASE_MAX
end

local function getNextCost(tier: number): number?
	if tier >= Config.STORAGE_MAX_TIER then return nil end
	for _, entry in Config.STORAGE_UPGRADES do
		if entry.tier == tier + 1 then return entry.cost end
	end
	return nil
end

local function syncPlayer(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local tier = profile.storageTier or 0
	StorageSync:FireClient(player, {
		tier     = tier,
		maxTier  = Config.STORAGE_MAX_TIER,
		maxHoney = getMaxHoney(tier),
		nextCost = getNextCost(tier),
	})
end

BuyStorageTier.OnServerInvoke = function(player: Player): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "profile unavailable" end
	local tier = profile.storageTier or 0
	if tier >= Config.STORAGE_MAX_TIER then
		return false, "already max storage tier"
	end
	local cost = getNextCost(tier)
	if not cost then return false, "no next tier" end
	if (profile.honey or 0) < cost then
		return false, "not enough honey"
	end
	profile.honey -= cost
	profile.storageTier = tier + 1
	syncPlayer(player)
	-- Also fire HoneySync so HUD updates
	local HoneySync = RS:FindFirstChild("HoneySync")
	if HoneySync then HoneySync:FireClient(player, profile.honey) end
	return true, "ok"
end

function HoneyStorageUpgradeService.GetMaxHoney(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return Config.STORAGE_BASE_MAX end
	return getMaxHoney(profile.storageTier or 0)
end

function HoneyStorageUpgradeService.Init()
	PS.PlayerAdded:Connect(syncPlayer)
	for _, player in PS:GetPlayers() do
		task.spawn(syncPlayer, player)
	end
	print("[HoneyStorageUpgradeService] ready")
end

return HoneyStorageUpgradeService
]]

print("HoneyStorageUpgradeService created")
```

**Verify:**
```lua
local svc = game:GetService("ServerScriptService"):FindFirstChild("HoneyStorageUpgradeService")
local synce = game:GetService("ReplicatedStorage"):FindFirstChild("StorageSync")
local rf    = game:GetService("ReplicatedStorage"):FindFirstChild("BuyStorageTier")
print(svc and synce and rf and "ALL OK" or "MISSING: " .. tostring(not svc and "Service" or not synce and "StorageSync" or "BuyStorageTier"))
```

---

## STEP D — Enforce cap in ForagingService

Honey yield must be capped before crediting. Open **ForagingService** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- 1. Add require near top (after existing requires)
local reqAnchor = 'local DataService'
local found = clone.Source:find(reqAnchor, 1, true)
assert(found, "DataService require anchor not found")
local lineEnd = clone.Source:find("\n", found, true)

local INJECT_REQ = "\nlocal HoneyStorageUpgradeService = require(SSS:WaitForChild(\"HoneyStorageUpgradeService\"))"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_REQ .. clone.Source:sub(lineEnd + 1)

-- 2. Cap honey before credit
-- Find where profile.honey is incremented (pattern: profile.honey += or profile.honey = profile.honey +)
local capAnchor = 'profile.honey +='
local found2 = clone.Source:find(capAnchor, 1, true)
if not found2 then
	capAnchor = 'profile.honey = profile.honey +'
	found2 = clone.Source:find(capAnchor, 1, true)
end
if found2 then
	local lineEnd2 = clone.Source:find("\n", found2, true)
	-- Inject cap AFTER the increment line
	local INJECT_CAP = [[

	-- Enforce storage cap
	local maxHoney = HoneyStorageUpgradeService.GetMaxHoney(player)
	if profile.honey > maxHoney then profile.honey = maxHoney end]]
	clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT_CAP .. clone.Source:sub(lineEnd2 + 1)
	print("Honey cap injected after honey credit")
else
	print("WARNING: honey credit line not found — add cap manually:")
	print("  local maxHoney = HoneyStorageUpgradeService.GetMaxHoney(player)")
	print("  if profile.honey > maxHoney then profile.honey = maxHoney end")
end

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService honey cap patch applied")
```

**Verify:**
```lua
local fs = game:GetService("ServerScriptService"):FindFirstChild("ForagingService")
print(fs and fs.Source:find("GetMaxHoney") and "OK" or "MISSING cap in ForagingService")
```

---

## STEP E — GameManager Init

Open **GameManager** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

-- Add require after PrestigeService require
local anchor = 'local PrestigeService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "PrestigeService require anchor not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
local INJECT_REQ = "\nlocal HoneyStorageUpgradeService = require(SSS:WaitForChild(\"HoneyStorageUpgradeService\"))"
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_REQ .. clone.Source:sub(lineEnd + 1)

-- Add Init call after PrestigeService.Init()
local initAnchor = 'PrestigeService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "PrestigeService.Init() anchor not found in GameManager")
local lineEnd2 = clone.Source:find("\n", found2, true)
local INJECT_INIT = "\nHoneyStorageUpgradeService.Init()"
clone.Source = clone.Source:sub(1, lineEnd2) .. INJECT_INIT .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager HoneyStorageUpgradeService.Init() injected")
```

---

## STEP F — HoneyStorageController (new LocalScript)

Command Bar — create the controller:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name = "HoneyStorageController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- HoneyStorageController — 🏺 honey storage upgrade tab

local PS   = game:GetService("Players")
local RS   = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local beesGui   = playerGui:WaitForChild("BeesWorldGui")
local mainFrame = beesGui:WaitForChild("MainFrame")

local StorageSync    = RS:WaitForChild("StorageSync")
local BuyStorageTier = RS:WaitForChild("BuyStorageTier")

-- ── palette ──────────────────────────────────────────────
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(122, 74, 34)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local STORE_CLR   = Color3.fromRGB(80, 180, 220)    -- sky blue (storage/capacity)
local TEXT_DARK   = Color3.fromRGB(40, 25, 10)
local PANEL_W     = 0.38
local PANEL_OPEN_X  = 0.60
local PANEL_CLOSE_X = 1.02
local panelOpen   = false
local busy        = false

-- ── build tab button ─────────────────────────────────────
local tabBtn = Instance.new("TextButton")
tabBtn.Name            = "StorageTabBtn"
tabBtn.Size            = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position        = UDim2.new(0.01, 0, 0.70, 0)   -- left column, above pollen tab
tabBtn.BackgroundColor3 = PROP_BROWN
tabBtn.BorderSizePixel  = 0
tabBtn.Text            = "🏺"
tabBtn.TextScaled      = true
tabBtn.ZIndex          = 24
tabBtn.Parent          = mainFrame
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.15, 0)
	c.Parent = tabBtn
end

-- Notification badge (red dot — for future use / storage full warning)
local storageBadge = Instance.new("Frame")
storageBadge.Name             = "NotifBadge"
storageBadge.Size             = UDim2.new(0.28, 0, 0.28, 0)
storageBadge.Position         = UDim2.new(0.72, 0, -0.06, 0)
storageBadge.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
storageBadge.BorderSizePixel  = 0
storageBadge.ZIndex           = 26
storageBadge.Visible          = false
storageBadge.Parent           = tabBtn
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = storageBadge end

-- ── build panel ──────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name              = "StoragePanel"
panel.Size              = UDim2.new(PANEL_W, 0, 0.55, 0)
panel.Position          = UDim2.new(PANEL_CLOSE_X, 0, 0.22, 0)
panel.BackgroundColor3  = PROP_BROWN
panel.BorderSizePixel   = 0
panel.ZIndex            = 20
panel.ClipsDescendants  = true
panel.Parent            = mainFrame
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.04, 0)
	c.Parent = panel
end

-- title
local title = Instance.new("TextLabel")
title.Name              = "Title"
title.Size              = UDim2.new(1, 0, 0.12, 0)
title.Position          = UDim2.new(0, 0, 0.01, 0)
title.BackgroundTransparency = 1
title.Text              = "🏺 Honey Storage"
title.TextColor3        = HONEY_GOLD
title.TextScaled        = true
title.Font              = Enum.Font.GothamBold
title.ZIndex            = 21
title.Parent            = panel

-- current / max label
local capacityLabel = Instance.new("TextLabel")
capacityLabel.Name              = "CapacityLabel"
capacityLabel.Size              = UDim2.new(0.9, 0, 0.09, 0)
capacityLabel.Position          = UDim2.new(0.05, 0, 0.14, 0)
capacityLabel.BackgroundTransparency = 1
capacityLabel.Text              = "Max: 2,000 🍯"
capacityLabel.TextColor3        = WAX_CREAM
capacityLabel.TextScaled        = true
capacityLabel.Font              = Enum.Font.Gotham
capacityLabel.ZIndex            = 21
capacityLabel.Parent            = panel

-- tier label
local tierLabel = Instance.new("TextLabel")
tierLabel.Name              = "TierLabel"
tierLabel.Size              = UDim2.new(0.9, 0, 0.08, 0)
tierLabel.Position          = UDim2.new(0.05, 0, 0.23, 0)
tierLabel.BackgroundTransparency = 1
tierLabel.Text              = "Tier 0 / 5"
tierLabel.TextColor3        = WAX_CREAM
tierLabel.TextScaled        = true
tierLabel.Font              = Enum.Font.Gotham
tierLabel.ZIndex            = 21
tierLabel.Parent            = panel

-- upgrade button
local upgradeBtn = Instance.new("TextButton")
upgradeBtn.Name              = "UpgradeBtn"
upgradeBtn.Size              = UDim2.new(0.88, 0, 0.14, 0)
upgradeBtn.Position          = UDim2.new(0.06, 0, 0.34, 0)
upgradeBtn.BackgroundColor3  = STORE_CLR
upgradeBtn.BorderSizePixel   = 0
upgradeBtn.Text              = "Upgrade  500 🍯"
upgradeBtn.TextColor3        = Color3.fromRGB(255, 255, 255)
upgradeBtn.TextScaled        = true
upgradeBtn.Font              = Enum.Font.GothamBold
upgradeBtn.ZIndex            = 22
upgradeBtn.Parent            = panel
do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.2, 0)
	c.Parent = upgradeBtn
end

-- next tier preview
local nextLabel = Instance.new("TextLabel")
nextLabel.Name              = "NextLabel"
nextLabel.Size              = UDim2.new(0.9, 0, 0.08, 0)
nextLabel.Position          = UDim2.new(0.05, 0, 0.50, 0)
nextLabel.BackgroundTransparency = 1
nextLabel.Text              = "Next: 5,000 max honey"
nextLabel.TextColor3        = WAX_CREAM
nextLabel.TextScaled        = true
nextLabel.Font              = Enum.Font.Gotham
nextLabel.ZIndex            = 21
nextLabel.Parent            = panel

-- max tier label (hidden until tier 5)
local maxLabel = Instance.new("TextLabel")
maxLabel.Name              = "MaxLabel"
maxLabel.Size              = UDim2.new(0.9, 0, 0.10, 0)
maxLabel.Position          = UDim2.new(0.05, 0, 0.34, 0)
maxLabel.BackgroundTransparency = 1
maxLabel.Text              = "✨ INFINITE HIVE"
maxLabel.TextColor3        = HONEY_GOLD
maxLabel.TextScaled        = true
maxLabel.Font              = Enum.Font.GothamBold
maxLabel.ZIndex            = 22
maxLabel.Visible           = false
maxLabel.Parent            = panel

-- toast
local toast = Instance.new("Frame")
toast.Name              = "Toast"
toast.Size              = UDim2.new(0.88, 0, 0.12, 0)
toast.Position          = UDim2.new(0.06, 0, -0.15, 0)
toast.BackgroundColor3  = HONEY_GOLD
toast.BorderSizePixel   = 0
toast.ZIndex            = 25
toast.Visible           = false
toast.Parent            = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = toast end

local toastLbl = Instance.new("TextLabel")
toastLbl.Size              = UDim2.new(1, 0, 1, 0)
toastLbl.BackgroundTransparency = 1
toastLbl.Text              = "Storage Upgraded!"
toastLbl.TextColor3        = TEXT_DARK
toastLbl.TextScaled        = true
toastLbl.Font              = Enum.Font.GothamBold
toastLbl.ZIndex            = 26
toastLbl.Parent            = toast

-- ── helpers ──────────────────────────────────────────────
local function fmt(n: number): string
	if n >= 1000000 then return string.format("%.1fM", n/1000000)
	elseif n >= 1000 then return string.format("%.1fK", n/1000)
	else return tostring(n) end
end

local function openPanel()
	if panelOpen then return end
	panelOpen = true
	TweenService:Create(panel,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(PANEL_OPEN_X, 0, 0.22, 0)}
	):Play()
end

local function closePanel()
	if not panelOpen then return end
	panelOpen = false
	TweenService:Create(panel,
		TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(PANEL_CLOSE_X, 0, 0.22, 0)}
	):Play()
end

local function showToast(msg: string)
	toastLbl.Text = msg
	toast.Visible = true
	toast.Position = UDim2.new(0.06, 0, -0.15, 0)
	TweenService:Create(toast,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.06, 0, 0.60, 0)}
	):Play()
	task.delay(2.2, function()
		TweenService:Create(toast,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{Position = UDim2.new(0.06, 0, -0.15, 0)}
		):Play()
		task.wait(0.2)
		toast.Visible = false
	end)
end

local function refreshUI(data: {tier: number, maxTier: number, maxHoney: number, nextCost: number?})
	capacityLabel.Text = "Max: " .. fmt(data.maxHoney) .. " 🍯"
	tierLabel.Text     = "Tier " .. data.tier .. " / " .. data.maxTier

	if data.tier >= data.maxTier then
		upgradeBtn.Visible = false
		nextLabel.Visible  = false
		maxLabel.Visible   = true
	else
		upgradeBtn.Visible = true
		nextLabel.Visible  = true
		maxLabel.Visible   = false
		local cost = data.nextCost
		if cost then
			upgradeBtn.Text = "Upgrade  " .. fmt(cost) .. " 🍯"
			-- Find next tier max honey for preview
			nextLabel.Text = "Next: " .. fmt(data.maxHoney) .. "→more max honey"
		end
	end
	busy = false
end

-- ── events ───────────────────────────────────────────────
StorageSync.OnClientEvent:Connect(function(data)
	refreshUI(data)
end)

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)

upgradeBtn.MouseButton1Click:Connect(function()
	if busy then return end
	busy = true
	upgradeBtn.Text = "..."
	local ok, msg = BuyStorageTier:InvokeServer()
	if ok then
		showToast("Storage Upgraded! 🏺")
	else
		showToast("Need more honey 🍯")
		busy = false
	end
end)
]]

print("HoneyStorageController created")
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
table.insert(checks, (cfg and cfg.Source:find("STORAGE_UPGRADES") and "✅" or "❌") .. " Config STORAGE_UPGRADES")

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("storageTier") and "✅" or "❌") .. " DataService storageTier")

local svc = SSS:FindFirstChild("HoneyStorageUpgradeService")
table.insert(checks, (svc and "✅" or "❌") .. " HoneyStorageUpgradeService script")

local ss = RS:FindFirstChild("StorageSync")
table.insert(checks, (ss and "✅" or "❌") .. " StorageSync RemoteEvent")

local rf = RS:FindFirstChild("BuyStorageTier")
table.insert(checks, (rf and "✅" or "❌") .. " BuyStorageTier RemoteFunction")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetMaxHoney") and "✅" or "❌") .. " ForagingService honey cap")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("HoneyStorageUpgradeService") and "✅" or "❌") .. " GameManager Init")

local ctrl = SPS and SPS:FindFirstChild("HoneyStorageController")
table.insert(checks, (ctrl and "✅" or "❌") .. " HoneyStorageController")

print("=== DISPATCH 60 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 60 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 60 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## GAMEPLAY IMPACT

- **Storage cap creates urgency:** base 2,000 fills within ~10 minutes at mid-game foraging rates. Players see their honey stop growing → motivation to buy storage.
- **Storage is a honey sink:** costs 500 → 2,500 → 8,000 → 20,000 → 50,000 honey (81,000 total) — comparable to queen upgrade tree (161K) but unlocks sooner.
- **Combined sinks to max everything:** Speed 110K + Queen 161K + Storage 81K + Propolis 370K honey = ~722K total honey required across full mid-to-late game. Prestige resets honey → loop driver.
- **🏺 tab sits above 🌿 pollen tab** in the left column (Y=0.70 → shifts existing pollen tab down to Y=0.775, propolis to 0.85, daily to 0.935 if layout needs reflow — see tab reflow note below).

> **Tab layout reflow note:** With 6 tabs in the left column (expansion Y=0.50, speed Y=0.60, storage Y=0.70, pollen Y=0.775, queen Y=0.80, propolis Y=0.85, daily Y=0.935), the column is dense. Consider using Y step of 0.08 instead of mixed steps for visual consistency. This is a polish concern — dispatch 60 places the storage tab at Y=0.70 (above existing pollen tab); the exact final layout reflow is addressed in a dedicated UI-pass dispatch if needed.
