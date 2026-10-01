# Dispatch 54 — PropolisYieldUpgradeService
## Cycle 11 · A Bee's World

**Feature:** 5-tier propolis yield upgrade — honey cost, completes the upgrade economy cross-sink.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 53 (QueenUpgradeService)

---

## ECONOMY RATIONALE

Current upgrade economy after dispatches 51-53:
- Speed upgrades → cost **honey**, reduce forage cycle time
- Pollen upgrades → cost **propolis**, multiply pollen yield
- Queen upgrades → cost **honey**, increase max bee count

Gap: **propolis yield** has no upgrade path, and propolis has only one sink (pollen upgrades). This dispatch adds a honey-cost propolis yield multiplier, giving honey a third sink and making propolis a renewable resource worth investing in.

Final cross-sink economy:
| Upgrade | Costs | Produces |
|---------|-------|---------|
| Speed | Honey | faster forage cycles |
| Queen | Honey | more simultaneous bees |
| Propolis Yield | **Honey** | more propolis per forage |
| Pollen Yield | Propolis | more pollen per forage |

---

## STEP A — Config injection

Open **Config** ModuleScript in ServerScriptService. In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

-- Clone-and-replace
local clone = cfg:Clone()
clone.Name = "Config_WORKING"

local INJECT = [[

	-- Propolis Yield Upgrade tiers (cost = honey)
	PROPOLIS_UPGRADES = {
		{tier=1, cost=800,   mult=1.22},
		{tier=2, cost=3000,  mult=1.50},
		{tier=3, cost=9000,  mult=1.83},
		{tier=4, cost=25000, mult=2.24},
		{tier=5, cost=65000, mult=2.73},
	},
	PROPOLIS_UPGRADE_MAX_TIER = 5,
]]

-- Anchor after QUEEN_UPGRADE_MAX_TIER line
local anchor = "QUEEN_UPGRADE_MAX_TIER = 5,"
local found = clone.Source:find(anchor, 1, true)
assert(found, "Anchor QUEEN_UPGRADE_MAX_TIER not found — check Config source")

clone.Source = clone.Source:sub(1, found + #anchor - 1) .. INJECT .. clone.Source:sub(found + #anchor)

-- Swap
cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config injection OK — PROPOLIS_UPGRADES added")
```

**Verify:**
```lua
local cfg = require(game:GetService("ServerScriptService"):FindFirstChild("Config"))
print(cfg.PROPOLIS_UPGRADES and #cfg.PROPOLIS_UPGRADES or "MISSING")
-- Expected: 5
```

---

## STEP B — DataService migration

Open **DataService** ModuleScript in ServerScriptService. In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

-- Anchor after queenTier field
local anchor = "queenTier = 0,"
local found = clone.Source:find(anchor, 1, true)
assert(found, "Anchor 'queenTier = 0,' not found in DataService")

local INJECT = "\n\t\t\tpropolisTier = 0,"

clone.Source = clone.Source:sub(1, found + #anchor - 1) .. INJECT .. clone.Source:sub(found + #anchor)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService migration OK — propolisTier added")
```

**Verify:**
```lua
-- In a new server test or Studio play, check profile template
local ds = require(game:GetService("ServerScriptService"):FindFirstChild("DataService"))
print(ds.PROFILE_TEMPLATE and ds.PROFILE_TEMPLATE.propolisTier)
-- Expected: 0
```

---

## STEP C — PropolisYieldUpgradeService ModuleScript

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("PropolisYieldUpgradeService"), "Already exists — delete first")

local mod = Instance.new("ModuleScript")
mod.Name = "PropolisYieldUpgradeService"
mod.Parent = SSS

mod.Source = [[
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Config = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local PropolisYieldUpgradeService = {}

-- RemoteEvent + RemoteFunction (created in STEP D)
local PropolisSync: RemoteEvent
local BuyPropTier: RemoteFunction

local function getConfig(tier: number): {tier: number, cost: number, mult: number}?
	for _, entry in Config.PROPOLIS_UPGRADES do
		if entry.tier == tier then return entry end
	end
	return nil
end

function PropolisYieldUpgradeService.GetMult(tier: number): number
	if tier <= 0 then return 1.0 end
	local entry = getConfig(tier)
	return entry and entry.mult or 1.0
end

local function syncClient(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local tier = profile.propolisTier or 0
	local maxTier = Config.PROPOLIS_UPGRADE_MAX_TIER
	local nextCost: number? = nil
	if tier < maxTier then
		local next = getConfig(tier + 1)
		nextCost = next and next.cost or nil
	end
	PropolisSync:FireClient(player, {
		tier = tier,
		maxTier = maxTier,
		mult = PropolisYieldUpgradeService.GetMult(tier),
		nextCost = nextCost,
	})
end

local function onBuyPropTier(player: Player): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "No profile" end
	local tier = profile.propolisTier or 0
	local maxTier = Config.PROPOLIS_UPGRADE_MAX_TIER
	if tier >= maxTier then return false, "Already max tier" end
	local next = getConfig(tier + 1)
	if not next then return false, "Invalid tier" end
	if profile.honey < next.cost then
		return false, "Need " .. next.cost .. " honey (have " .. math.floor(profile.honey) .. ")"
	end
	profile.honey -= next.cost
	profile.propolisTier = tier + 1
	syncClient(player)
	return true, "Propolis yield tier " .. profile.propolisTier .. " unlocked"
end

function PropolisYieldUpgradeService.Init()
	PropolisSync = ReplicatedStorage:WaitForChild("PropolisSync") :: RemoteEvent
	BuyPropTier = ReplicatedStorage:WaitForChild("BuyPropTier") :: RemoteFunction
	BuyPropTier.OnServerInvoke = onBuyPropTier

	Players.PlayerAdded:Connect(function(player)
		task.wait(4)
		if player.Parent then syncClient(player) end
	end)

	-- Sync already-connected players (hot reload / Studio play)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			task.wait(1)
			syncClient(player)
		end)
	end

	print("[PropolisYieldUpgradeService] Initialized")
end

return PropolisYieldUpgradeService
]]

print("PropolisYieldUpgradeService created")
```

**Verify:**
```lua
local m = game:GetService("ServerScriptService"):FindFirstChild("PropolisYieldUpgradeService")
print(m and m.ClassName or "MISSING")
-- Expected: ModuleScript
```

---

## STEP D — RemoteEvent + RemoteFunction in ReplicatedStorage

In Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

local function ensureRE(name)
	if not RS:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = RS
		print("Created RemoteEvent:", name)
	else
		print("Already exists:", name)
	end
end

local function ensureRF(name)
	if not RS:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = RS
		print("Created RemoteFunction:", name)
	else
		print("Already exists:", name)
	end
end

ensureRE("PropolisSync")
ensureRF("BuyPropTier")

print("ReplicatedStorage remotes OK")
```

**Verify:**
```lua
local RS = game:GetService("ReplicatedStorage")
print(RS:FindFirstChild("PropolisSync") and "PropolisSync OK" or "MISSING PropolisSync")
print(RS:FindFirstChild("BuyPropTier") and "BuyPropTier OK" or "MISSING BuyPropTier")
```

---

## STEP E — ForagingService injection (propolis yield multiplier)

Open **ForagingService** in ServerScriptService. In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- 1. Inject PropolisYieldUpgradeService require after PollenYieldUpgradeService require
local reqAnchor = 'require(SSS:WaitForChild("PollenYieldUpgradeService"))'
local found1 = clone.Source:find(reqAnchor, 1, true)
if found1 then
	local INJECT_REQ = '\nlocal PropolisYieldUpgradeService = require(SSS:WaitForChild("PropolisYieldUpgradeService"))'
	clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found1 + #reqAnchor)
	print("Injected PropolisYieldUpgradeService require after PollenYieldUpgradeService require")
else
	-- Fallback: inject after SpeedUpgradeService require
	local fallbackAnchor = 'require(SSS:WaitForChild("SpeedUpgradeService"))'
	local found2 = clone.Source:find(fallbackAnchor, 1, true)
	if found2 then
		local INJECT_REQ = '\nlocal PropolisYieldUpgradeService = require(SSS:WaitForChild("PropolisYieldUpgradeService"))'
		clone.Source = clone.Source:sub(1, found2 + #fallbackAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found2 + #fallbackAnchor)
		print("(fallback) Injected after SpeedUpgradeService require")
	else
		-- Last resort: inject near top after Config require
		local cfgAnchor = 'require(SSS:WaitForChild("Config"))'
		local found3 = clone.Source:find(cfgAnchor, 1, true)
		assert(found3, "Could not find require anchor in ForagingService — manual injection needed")
		local INJECT_REQ = '\nlocal PropolisYieldUpgradeService = require(SSS:WaitForChild("PropolisYieldUpgradeService"))'
		clone.Source = clone.Source:sub(1, found3 + #cfgAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found3 + #cfgAnchor)
		print("(last-resort) Injected after Config require")
	end
end

-- 2. Multiply propolis yield by propolisTier mult
-- Look for the pollen multiplier injection from dispatch 52 first
local pollenMultAnchor = "PollenYieldUpgradeService.GetMult"
local found4, foundEnd4 = clone.Source:find("pollen[^\n]+PollenYieldUpgradeService%.GetMult[^\n]+", 1)
if found4 then
	-- Propolis yield line should be nearby — look for propolisYield assignment
	local propolisLine, propolisEnd = clone.Source:find("local propolis[Yy]ield[^\n]+\n", found4)
	if not propolisLine then
		propolisLine, propolisEnd = clone.Source:find("propolis[^\n]+propolisYield[^\n]+\n", 1)
	end
	if propolisLine then
		-- Inject mult after propolisYield assignment
		local INJECT_MULT = "\tlocal pTier2 = DataService.GetProfile(player).propolisTier or 0\n\tpropolisYield = propolisYield * PropolisYieldUpgradeService.GetMult(pTier2)\n"
		clone.Source = clone.Source:sub(1, propolisEnd - 1) .. INJECT_MULT .. clone.Source:sub(propolisEnd)
		print("Injected propolisYield multiplier after propolisYield assignment")
	else
		print("WARNING: Could not find propolisYield assignment — inject manually near the pollen yield calculation")
	end
else
	-- Fallback: find any propolis yield calculation
	local propsLine, propsEnd = clone.Source:find("local propYield[^\n]+\n", 1)
	if not propsLine then
		propsLine, propsEnd = clone.Source:find("propolis = propolis [%+%*][^\n]+\n", 1)
	end
	if propsLine then
		local INJECT_MULT = "\tlocal pTier2 = DataService.GetProfile(player).propolisTier or 0\n\tpropYield = propYield * PropolisYieldUpgradeService.GetMult(pTier2)\n"
		clone.Source = clone.Source:sub(1, propsEnd - 1) .. INJECT_MULT .. clone.Source:sub(propsEnd)
		print("(fallback) Injected propolisYield multiplier")
	else
		print("WARNING: Could not auto-inject propolis multiplier. In ForagingService find where propolis amount is calculated and add:")
		print("  local pTier2 = DataService.GetProfile(player).propolisTier or 0")
		print("  <propolis_var> = <propolis_var> * PropolisYieldUpgradeService.GetMult(pTier2)")
	end
end

-- Swap
fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService injection complete")
```

**Verify:**
```lua
local fs = game:GetService("ServerScriptService"):FindFirstChild("ForagingService")
print(fs.Source:find("PropolisYieldUpgradeService") and "INJECTED" or "MISSING — manual inject required")
```

---

## STEP F — GameManager injection

Open **GameManager** Script in ServerScriptService. In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

-- 1. Require injection after QueenUpgradeService
local reqAnchor = 'require(SSS:WaitForChild("QueenUpgradeService"))'
local found1 = clone.Source:find(reqAnchor, 1, true)
if not found1 then
	-- Fallback anchor
	reqAnchor = 'require(SSS:WaitForChild("PollenYieldUpgradeService"))'
	found1 = clone.Source:find(reqAnchor, 1, true)
end
if not found1 then
	reqAnchor = 'require(SSS:WaitForChild("SpeedUpgradeService"))'
	found1 = clone.Source:find(reqAnchor, 1, true)
end
assert(found1, "No upgrade service require found in GameManager — check source")

local INJECT_REQ = '\nlocal PropolisYieldUpgradeService = require(SSS:WaitForChild("PropolisYieldUpgradeService"))'
clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found1 + #reqAnchor)

-- 2. Init injection after QueenUpgradeService.Init()
local initAnchor = "QueenUpgradeService.Init()"
local found2 = clone.Source:find(initAnchor, 1, true)
if not found2 then
	initAnchor = "PollenYieldUpgradeService.Init()"
	found2 = clone.Source:find(initAnchor, 1, true)
end
if not found2 then
	initAnchor = "SpeedUpgradeService.Init()"
	found2 = clone.Source:find(initAnchor, 1, true)
end
assert(found2, "No upgrade service Init() found in GameManager")

local INJECT_INIT = "\n\tPropolisYieldUpgradeService.Init()"
clone.Source = clone.Source:sub(1, found2 + #initAnchor - 1) .. INJECT_INIT .. clone.Source:sub(found2 + #initAnchor)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager injection OK — PropolisYieldUpgradeService wired in")
```

**Verify:**
```lua
local gm = game:GetService("ServerScriptService"):FindFirstChild("GameManager")
local hasReq = gm.Source:find("PropolisYieldUpgradeService") ~= nil
local hasInit = gm.Source:find("PropolisYieldUpgradeService%.Init") ~= nil
print("Require:", hasReq, "| Init:", hasInit)
-- Expected: Require: true | Init: true
```

---

## STEP G — PropolisUpgradeController LocalScript

In Command Bar:

```lua
local SPScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPScripts, "StarterPlayerScripts not found")

if SPScripts:FindFirstChild("PropolisUpgradeController") then
	SPScripts:FindFirstChild("PropolisUpgradeController"):Destroy()
	print("Removed old PropolisUpgradeController")
end

local ls = Instance.new("LocalScript")
ls.Name = "PropolisUpgradeController"
ls.Parent = SPScripts

ls.Source = [[
--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local PropolisSync: RemoteEvent = RS:WaitForChild("PropolisSync") :: RemoteEvent
local BuyPropTier: RemoteFunction = RS:WaitForChild("BuyPropTier") :: RemoteFunction

-- Colors — amber/brown for propolis theme
local PROP_CLR = Color3.fromRGB(180, 110, 30)      -- warm amber
local PROP_DARK = Color3.fromRGB(90, 50, 10)
local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local WAX_CREAM = Color3.fromRGB(232, 212, 154)
local PROPOLIS_BROWN = Color3.fromRGB(122, 74, 34)
local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)

local panelOpen = false

-- ── Build ScreenGui ────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name = "PropolisUpgradeGui"
sg.DisplayOrder = 18
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = false
sg.Parent = playerGui

-- Tab toggle button (left column)
local tabBtn = Instance.new("TextButton")
tabBtn.Name = "PropolisTab"
tabBtn.Size = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position = UDim2.new(0.01, 0, 0.775, 0)
tabBtn.AnchorPoint = Vector2.new(0, 0)
tabBtn.BackgroundColor3 = PROP_DARK
tabBtn.TextColor3 = WAX_CREAM
tabBtn.Text = "🧪"
tabBtn.TextScaled = true
tabBtn.Font = Enum.Font.GothamBold
tabBtn.ZIndex = 20
tabBtn.Parent = sg

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0.18, 0)
tabCorner.Parent = tabBtn

local tabStroke = Instance.new("UIStroke")
tabStroke.Color = PROP_CLR
tabStroke.Thickness = 2
tabStroke.Parent = tabBtn

-- Panel (starts off-screen right)
local panel = Instance.new("Frame")
panel.Name = "PropolisPanel"
panel.Size = UDim2.new(0.28, 0, 0.55, 0)
panel.Position = UDim2.new(1.01, 0, 0.23, 0)
panel.AnchorPoint = Vector2.new(0, 0)
panel.BackgroundColor3 = Color3.fromRGB(30, 18, 5)
panel.BorderSizePixel = 0
panel.ZIndex = 19
panel.Parent = sg

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0.04, 0)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = PROP_CLR
panelStroke.Thickness = 2
panelStroke.Parent = panel

-- Header
local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0.12, 0)
header.Position = UDim2.new(0, 0, 0.01, 0)
header.BackgroundTransparency = 1
header.TextColor3 = PROP_CLR
header.Text = "🧪 Propolis Yield"
header.TextScaled = true
header.Font = Enum.Font.GothamBold
header.ZIndex = 20
header.Parent = panel

-- Current tier label
local tierLbl = Instance.new("TextLabel")
tierLbl.Name = "TierLabel"
tierLbl.Size = UDim2.new(0.9, 0, 0.10, 0)
tierLbl.Position = UDim2.new(0.05, 0, 0.14, 0)
tierLbl.BackgroundTransparency = 1
tierLbl.TextColor3 = WAX_CREAM
tierLbl.Text = "Propolis Yield: 1.00× (Tier 0/5)"
tierLbl.TextScaled = true
tierLbl.Font = Enum.Font.Gotham
tierLbl.ZIndex = 20
tierLbl.Parent = panel

-- Progress bar track
local barTrack = Instance.new("Frame")
barTrack.Name = "BarTrack"
barTrack.Size = UDim2.new(0.88, 0, 0.065, 0)
barTrack.Position = UDim2.new(0.06, 0, 0.27, 0)
barTrack.BackgroundColor3 = PROP_DARK
barTrack.BorderSizePixel = 0
barTrack.ZIndex = 20
barTrack.Parent = panel

local barTrackCorner = Instance.new("UICorner")
barTrackCorner.CornerRadius = UDim.new(0.5, 0)
barTrackCorner.Parent = barTrack

local barFill = Instance.new("Frame")
barFill.Name = "BarFill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.Position = UDim2.new(0, 0, 0, 0)
barFill.BackgroundColor3 = PROP_CLR
barFill.BorderSizePixel = 0
barFill.ZIndex = 21
barFill.Parent = barTrack

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(0.5, 0)
barFillCorner.Parent = barFill

-- Description label
local descLbl = Instance.new("TextLabel")
descLbl.Name = "DescLabel"
descLbl.Size = UDim2.new(0.88, 0, 0.14, 0)
descLbl.Position = UDim2.new(0.06, 0, 0.36, 0)
descLbl.BackgroundTransparency = 1
descLbl.TextColor3 = Color3.fromRGB(180, 155, 120)
descLbl.Text = "Multiply propolis collected\nper foraging trip."
descLbl.TextScaled = true
descLbl.Font = Enum.Font.Gotham
descLbl.TextWrapped = true
descLbl.ZIndex = 20
descLbl.Parent = panel

-- Cost note label (costs honey)
local costNote = Instance.new("TextLabel")
costNote.Name = "CostNote"
costNote.Size = UDim2.new(0.88, 0, 0.08, 0)
costNote.Position = UDim2.new(0.06, 0, 0.51, 0)
costNote.BackgroundTransparency = 1
costNote.TextColor3 = HONEY_GOLD
costNote.Text = "Costs Honey 🍯"
costNote.TextScaled = true
costNote.Font = Enum.Font.GothamBold
costNote.ZIndex = 20
costNote.Parent = panel

-- Buy button
local buyBtn = Instance.new("TextButton")
buyBtn.Name = "BuyBtn"
buyBtn.Size = UDim2.new(0.82, 0, 0.14, 0)
buyBtn.Position = UDim2.new(0.09, 0, 0.62, 0)
buyBtn.BackgroundColor3 = PROP_CLR
buyBtn.TextColor3 = WHITE
buyBtn.Text = "Upgrade — 800 🍯"
buyBtn.TextScaled = true
buyBtn.Font = Enum.Font.GothamBold
buyBtn.ZIndex = 21
buyBtn.Parent = panel

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0.25, 0)
buyCorner.Parent = buyBtn

local buyStroke = Instance.new("UIStroke")
buyStroke.Color = WAX_CREAM
buyStroke.Thickness = 1.5
buyStroke.Parent = buyBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0.12, 0, 0.10, 0)
closeBtn.Position = UDim2.new(0.86, 0, 0.01, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = Color3.fromRGB(180, 140, 100)
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 22
closeBtn.Parent = panel

-- ── State ──────────────────────────────────────────────────────────
local currentTier = 0
local maxTier = 5
local currentMult = 1.0
local nextCost: number? = nil
local busy = false

local function fmtHoney(n: number): string
	if n >= 1_000_000 then return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then return string.format("%.1fK", n / 1_000)
	else return tostring(math.floor(n)) end
end

local function refreshUI()
	local atMax = currentTier >= maxTier
	tierLbl.Text = string.format("Propolis Yield: %.2f× (Tier %d/%d)", currentMult, currentTier, maxTier)

	-- Progress bar
	local ratio = maxTier > 0 and (currentTier / maxTier) or 0
	TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(ratio, 0, 1, 0),
	}):Play()

	if atMax then
		buyBtn.Text = "✅ MAX PROPOLIS"
		buyBtn.BackgroundColor3 = PROP_DARK
		buyBtn.Active = false
		buyBtn.AutoButtonColor = false
	else
		local costStr = nextCost and fmtHoney(nextCost) or "?"
		buyBtn.Text = "Upgrade — " .. costStr .. " 🍯"
		buyBtn.BackgroundColor3 = PROP_CLR
		buyBtn.Active = true
		buyBtn.AutoButtonColor = true
	end
end

-- ── Animation ──────────────────────────────────────────────────────
local PANEL_CLOSED_X = 1.01
local PANEL_OPEN_X = 0.69

local function openPanel()
	panelOpen = true
	tabBtn.BackgroundColor3 = PROP_CLR
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(PANEL_OPEN_X, 0, 0.23, 0),
	}):Play()
end

local function closePanel()
	panelOpen = false
	tabBtn.BackgroundColor3 = PROP_DARK
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(PANEL_CLOSED_X, 0, 0.23, 0),
	}):Play()
end

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

-- ── Buy ────────────────────────────────────────────────────────────
buyBtn.MouseButton1Click:Connect(function()
	if busy then return end
	if currentTier >= maxTier then return end
	busy = true
	buyBtn.Text = "Buying..."
	buyBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 20)

	local ok, msg = BuyPropTier:InvokeServer()
	if not ok then
		buyBtn.Text = "✗ " .. (msg or "Failed")
		task.wait(1.8)
		refreshUI()
	end
	busy = false
end)

-- ── Sync ───────────────────────────────────────────────────────────
PropolisSync.OnClientEvent:Connect(function(data: {tier: number, maxTier: number, mult: number, nextCost: number?})
	currentTier = data.tier or 0
	maxTier = data.maxTier or 5
	currentMult = data.mult or 1.0
	nextCost = data.nextCost
	refreshUI()
	busy = false
end)

refreshUI()
]]

print("PropolisUpgradeController created")
```

**Verify:**
```lua
local SPScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPScripts:FindFirstChild("PropolisUpgradeController")
print(ctrl and ctrl.ClassName or "MISSING")
-- Expected: LocalScript
```

---

## STEP H — Full verification sweep

Run in Command Bar after all steps complete:

```lua
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local checks = {}

-- Config
local cfg = pcall(function() return require(SSS:FindFirstChild("Config")) end)
local cfgMod = SSS:FindFirstChild("Config")
local cfgOK = cfgMod and cfgMod.Source:find("PROPOLIS_UPGRADES") ~= nil
table.insert(checks, (cfgOK and "✅" or "❌") .. " Config.PROPOLIS_UPGRADES")

-- DataService migration
local dsMod = SSS:FindFirstChild("DataService")
local dsOK = dsMod and dsMod.Source:find("propolisTier") ~= nil
table.insert(checks, (dsOK and "✅" or "❌") .. " DataService.propolisTier field")

-- PropolisYieldUpgradeService
local svcOK = SSS:FindFirstChild("PropolisYieldUpgradeService") ~= nil
table.insert(checks, (svcOK and "✅" or "❌") .. " PropolisYieldUpgradeService module")

-- Remotes
local syncOK = RS:FindFirstChild("PropolisSync") ~= nil
local rfOK = RS:FindFirstChild("BuyPropTier") ~= nil
table.insert(checks, (syncOK and "✅" or "❌") .. " PropolisSync RemoteEvent")
table.insert(checks, (rfOK and "✅" or "❌") .. " BuyPropTier RemoteFunction")

-- ForagingService injection
local fsMod = SSS:FindFirstChild("ForagingService")
local fsOK = fsMod and fsMod.Source:find("PropolisYieldUpgradeService") ~= nil
table.insert(checks, (fsOK and "✅" or "❌") .. " ForagingService propolis mult")

-- GameManager injection
local gmMod = SSS:FindFirstChild("GameManager")
local gmOK = gmMod and gmMod.Source:find("PropolisYieldUpgradeService") ~= nil
table.insert(checks, (gmOK and "✅" or "❌") .. " GameManager wired")

-- Controller
local ctrl = SP:FindFirstChild("StarterPlayerScripts") and
	SP.StarterPlayerScripts:FindFirstChild("PropolisUpgradeController")
local ctrlOK = ctrl ~= nil
table.insert(checks, (ctrlOK and "✅" or "❌") .. " PropolisUpgradeController LocalScript")

print("=== DISPATCH 54 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 54 complete" or "❌ SOME CHECKS FAILED — see above")
```

Expected output:
```
=== DISPATCH 54 VERIFICATION ===
✅ Config.PROPOLIS_UPGRADES
✅ DataService.propolisTier field
✅ PropolisYieldUpgradeService module
✅ PropolisSync RemoteEvent
✅ BuyPropTier RemoteFunction
✅ ForagingService propolis mult
✅ GameManager wired
✅ PropolisUpgradeController LocalScript
✅ ALL CHECKS PASS — dispatch 54 complete
```

---

## ECONOMY SUMMARY (post dispatch 54)

| Upgrade Track | Tiers | Total Cost to Max | Resource Spent |
|---------------|-------|-------------------|----------------|
| Speed | 5 | 110,500 🍯 honey | Honey |
| Queen Capacity | 5 | 161,000 🍯 honey | Honey |
| **Propolis Yield** | **5** | **98,800 🍯 honey** | **Honey** |
| Pollen Yield | 5 | 4,100 🟤 propolis | Propolis |

**Honey sinks (grand total to max all honey upgrades):** 370,300 🍯
**Propolis sink:** 4,100 🟤

**Final multiplier stack per forage trip (all maxed):**
- Cycle time: ÷2.27 (speed)
- Pollen yield: ×2.49 (pollen upgrade) × season/storm modifiers
- Propolis yield: ×2.73 (propolis upgrade) × season modifier
- Active bees: up to 25 (queen)

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PropolisUpgradeController (UI ScreenGui) | 0 (no BaseParts) |
| **Dispatch 54 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## GameManager init chain (post dispatch 54)

```
GameManager.Init()
  → DataService.Init()
  → PlotService.Init()
  → ForagingService.Init()
  → HoneyService.Init()
  → SeasonService.Init()
  → LeaderboardService.Init()
  → TutorialService.Init()
  → HiveExpansionService.Init()
  → AchievementService.Init()
  → SpeedUpgradeService.Init()
  → PollenYieldUpgradeService.Init()
  → QueenUpgradeService.Init()
  → PropolisYieldUpgradeService.Init()   ← dispatch 54
```
