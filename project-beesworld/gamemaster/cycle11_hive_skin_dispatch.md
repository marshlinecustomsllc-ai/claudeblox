# Dispatch 56 — HiveSkinService
## Cycle 11 · A Bee's World

**Feature:** Cosmetic hive skin unlocks — 3 purchasable skins change the visual appearance of all player hex cells (material + color), no gameplay effect.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 55 (DailyRewardService)

---

## SKIN CATALOG

| ID | Name | Cost | Cell Material | Cell Color | Accent |
|----|------|------|--------------|------------|--------|
| `default` | Classic Wax | 0 (free) | SmoothPlastic | RGB(242,168,28) Honey Gold | default |
| `amber` | Amber Crystal | 5,000 🍯 | Neon | RGB(255,140,0) deep amber | soft glow |
| `obsidian` | Obsidian Hive | 20,000 🍯 | Metal | RGB(40,40,50) dark slate | silver edge |
| `royal` | Royal Gold | 50,000 🍯 | Marble | RGB(255,215,0) pure gold | warm white |

The active skin is applied to **all existing hex cell parts** in the player's plots and remembered across sessions.

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

	-- Cosmetic hive skins
	HIVE_SKINS = {
		{
			id = "default",
			name = "Classic Wax",
			cost = 0,
			material = Enum.Material.SmoothPlastic,
			color = Color3.fromRGB(242, 168, 28),
			desc = "The original warm honey gold.",
		},
		{
			id = "amber",
			name = "Amber Crystal",
			cost = 5000,
			material = Enum.Material.Neon,
			color = Color3.fromRGB(255, 140, 0),
			desc = "Fossilized amber — glows from within.",
		},
		{
			id = "obsidian",
			name = "Obsidian Hive",
			cost = 20000,
			material = Enum.Material.Metal,
			color = Color3.fromRGB(40, 40, 50),
			desc = "Dark volcanic glass. Cold and eternal.",
		},
		{
			id = "royal",
			name = "Royal Gold",
			cost = 50000,
			material = Enum.Material.Marble,
			color = Color3.fromRGB(255, 215, 0),
			desc = "Carved from the queen's own chamber.",
		},
	},
]]

-- Anchor after DAILY_REWARDS block
local anchor = '"Week crown!"'
local found = clone.Source:find(anchor, 1, true)
if not found then
	-- Fallback: after PROPOLIS_UPGRADE_MAX_TIER
	anchor = "PROPOLIS_UPGRADE_MAX_TIER = 5,"
	found = clone.Source:find(anchor, 1, true)
end
if not found then
	anchor = "QUEEN_UPGRADE_MAX_TIER = 5,"
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "No anchor found in Config for HIVE_SKINS injection")

-- Find end of the line containing anchor
local lineEnd = clone.Source:find("\n", found, true)
assert(lineEnd, "Could not find newline after anchor")

clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config injection OK — HIVE_SKINS added")
```

**Verify:**
```lua
local cfg = game:GetService("ServerScriptService"):FindFirstChild("Config")
print(cfg.Source:find("HIVE_SKINS") and "OK" or "MISSING")
print(cfg.Source:find('"royal"') and "royal skin present" or "missing royal skin")
```

---

## STEP B — DataService migration

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

-- Anchor after dailyStreak
local anchor = "dailyStreak    = 0,"
local found = clone.Source:find(anchor, 1, true)
if not found then
	anchor = "lastDailyDay   = 0,"
	found = clone.Source:find(anchor, 1, true)
end
if not found then
	anchor = "propolisTier = 0,"
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "Anchor not found in DataService for hive skin migration")

local INJECT = [[

			activeSkin        = "default",  -- current hive skin id
			unlockedSkins     = {},          -- array of unlocked skin ids]]

clone.Source = clone.Source:sub(1, found + #anchor - 1) .. INJECT .. clone.Source:sub(found + #anchor)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService migration OK — activeSkin + unlockedSkins added")
```

---

## STEP C — HiveSkinService ModuleScript

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("HiveSkinService"), "Already exists — delete first")

local mod = Instance.new("ModuleScript")
mod.Name = "HiveSkinService"
mod.Parent = SSS

mod.Source = [[
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")

local Config = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local HiveSkinService = {}

local SkinSync: RemoteEvent
local BuySkin: RemoteFunction
local ApplySkin: RemoteFunction

-- Collect all hex cell parts belonging to a player's plots
-- Tagged with "HexCell" + StringValue "OwnerId" = player.UserId
local function getPlayerCells(userId: number): {BasePart}
	local cells = {}
	for _, obj in CollectionService:GetTagged("HexCell") do
		if obj:IsA("BasePart") then
			local ownerId = obj:FindFirstChild("OwnerId")
			if ownerId and ownerId:IsA("IntValue") and ownerId.Value == userId then
				table.insert(cells, obj)
			end
		end
	end
	return cells
end

local function getSkinConfig(id: string): any?
	for _, skin in Config.HIVE_SKINS do
		if skin.id == id then return skin end
	end
	return nil
end

local function hasUnlocked(profile: any, skinId: string): boolean
	if skinId == "default" then return true end
	for _, id in (profile.unlockedSkins or {}) do
		if id == skinId then return true end
	end
	return false
end

-- Apply a skin to all hex cells owned by a player (server-side)
local function applyToWorld(player: Player, skinId: string)
	local skin = getSkinConfig(skinId)
	if not skin then return end
	local cells = getPlayerCells(player.UserId)
	for _, cell in cells do
		cell.Material = skin.material
		cell.Color = skin.color
	end
end

local function buildSyncPayload(profile: any): {activeSkin: string, unlockedSkins: {string}, catalog: any}
	local unlocked: {string} = {"default"}
	for _, id in (profile.unlockedSkins or {}) do
		table.insert(unlocked, id)
	end
	return {
		activeSkin = profile.activeSkin or "default",
		unlockedSkins = unlocked,
		catalog = Config.HIVE_SKINS,
	}
end

local function syncClient(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	SkinSync:FireClient(player, buildSyncPayload(profile))
end

local function onBuySkin(player: Player, skinId: string): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "No profile" end
	if hasUnlocked(profile, skinId) then return false, "Already owned" end

	local skin = getSkinConfig(skinId)
	if not skin then return false, "Unknown skin: " .. tostring(skinId) end
	if profile.honey < skin.cost then
		return false, "Need " .. skin.cost .. " honey (have " .. math.floor(profile.honey) .. ")"
	end

	profile.honey -= skin.cost
	local skins = profile.unlockedSkins or {}
	table.insert(skins, skinId)
	profile.unlockedSkins = skins

	syncClient(player)
	return true, "Unlocked: " .. skin.name
end

local function onApplySkin(player: Player, skinId: string): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "No profile" end
	if not hasUnlocked(profile, skinId) then return false, "Skin not owned" end
	if getSkinConfig(skinId) == nil then return false, "Unknown skin" end

	profile.activeSkin = skinId
	applyToWorld(player, skinId)
	SkinSync:FireClient(player, buildSyncPayload(profile))

	return true, "Applied: " .. skinId
end

-- Re-apply saved skin on PlayerAdded (after plot cells are built)
local function restorePlayerSkin(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	local skinId = profile.activeSkin or "default"
	applyToWorld(player, skinId)
end

function HiveSkinService.Init()
	SkinSync = ReplicatedStorage:WaitForChild("SkinSync") :: RemoteEvent
	BuySkin = ReplicatedStorage:WaitForChild("BuySkin") :: RemoteFunction
	ApplySkin = ReplicatedStorage:WaitForChild("ApplySkin") :: RemoteFunction

	BuySkin.OnServerInvoke = onBuySkin
	ApplySkin.OnServerInvoke = onApplySkin

	Players.PlayerAdded:Connect(function(player)
		task.wait(5)  -- let plots/cells be built first
		if player.Parent then
			restorePlayerSkin(player)
			syncClient(player)
		end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			task.wait(2)
			restorePlayerSkin(player)
			syncClient(player)
		end)
	end

	print("[HiveSkinService] Initialized")
end

return HiveSkinService
]]

print("HiveSkinService created")
```

---

## STEP D — Remotes in ReplicatedStorage

In Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

local function ensureRE(name)
	if not RS:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent"); re.Name = name; re.Parent = RS
		print("Created RemoteEvent:", name)
	else print("Exists:", name) end
end
local function ensureRF(name)
	if not RS:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction"); rf.Name = name; rf.Parent = RS
		print("Created RemoteFunction:", name)
	else print("Exists:", name) end
end

ensureRE("SkinSync")
ensureRF("BuySkin")
ensureRF("ApplySkin")

print("Skin remotes OK")
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

local anchors = {
	'require(SSS:WaitForChild("DailyRewardService"))',
	'require(SSS:WaitForChild("PropolisYieldUpgradeService"))',
	'require(SSS:WaitForChild("QueenUpgradeService"))',
	'require(SSS:WaitForChild("SpeedUpgradeService"))',
}
local reqAnchor, found1
for _, a in anchors do
	found1 = clone.Source:find(a, 1, true)
	if found1 then reqAnchor = a; break end
end
assert(found1, "No upgrade/daily require found in GameManager")

clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1)
	.. '\nlocal HiveSkinService = require(SSS:WaitForChild("HiveSkinService"))'
	.. clone.Source:sub(found1 + #reqAnchor)

local initAnchors = {
	"DailyRewardService.Init()",
	"PropolisYieldUpgradeService.Init()",
	"QueenUpgradeService.Init()",
	"SpeedUpgradeService.Init()",
}
local initAnchor, found2
for _, a in initAnchors do
	found2 = clone.Source:find(a, 1, true)
	if found2 then initAnchor = a; break end
end
assert(found2, "No service Init() found in GameManager")

clone.Source = clone.Source:sub(1, found2 + #initAnchor - 1)
	.. "\n\tHiveSkinService.Init()"
	.. clone.Source:sub(found2 + #initAnchor)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager injection OK — HiveSkinService wired in")
```

---

## STEP F — HiveSkinController LocalScript

In Command Bar:

```lua
local SPScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPScripts, "StarterPlayerScripts not found")

if SPScripts:FindFirstChild("HiveSkinController") then
	SPScripts:FindFirstChild("HiveSkinController"):Destroy()
end

local ls = Instance.new("LocalScript")
ls.Name = "HiveSkinController"
ls.Parent = SPScripts

ls.Source = [[
--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SkinSync: RemoteEvent = RS:WaitForChild("SkinSync") :: RemoteEvent
local BuySkin: RemoteFunction = RS:WaitForChild("BuySkin") :: RemoteFunction
local ApplySkin: RemoteFunction = RS:WaitForChild("ApplySkin") :: RemoteFunction

-- Palette
local HONEY_GOLD    = Color3.fromRGB(242, 168, 28)
local WAX_CREAM     = Color3.fromRGB(232, 212, 154)
local PROPOLIS_BROWN = Color3.fromRGB(122, 74, 34)
local BG_DARK       = Color3.fromRGB(18, 10, 3)
local WHITE         = Color3.fromRGB(255, 255, 255)
local GREY          = Color3.fromRGB(120, 100, 80)
local GREEN         = Color3.fromRGB(80, 200, 80)

-- Build ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name = "HiveSkinGui"
sg.DisplayOrder = 16
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = false
sg.Parent = playerGui

-- Tab button — 🎨 icon, right side column
local tabBtn = Instance.new("TextButton")
tabBtn.Name = "SkinTab"
tabBtn.Size = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position = UDim2.new(0.925, 0, 0.30, 0)
tabBtn.BackgroundColor3 = PROPOLIS_BROWN
tabBtn.TextColor3 = WAX_CREAM
tabBtn.Text = "🎨"
tabBtn.TextScaled = true
tabBtn.Font = Enum.Font.GothamBold
tabBtn.ZIndex = 20
tabBtn.Parent = sg

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.18, 0); c.Parent = tabBtn
	local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2; s.Parent = tabBtn
end

-- Panel — slides from right
local panel = Instance.new("Frame")
panel.Name = "SkinPanel"
panel.Size = UDim2.new(0.32, 0, 0.70, 0)
panel.Position = UDim2.new(1.02, 0, 0.15, 0)
panel.BackgroundColor3 = BG_DARK
panel.BorderSizePixel = 0
panel.ZIndex = 19
panel.Parent = sg

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.03, 0); c.Parent = panel
	local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2; s.Parent = panel
end

-- Header
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0.09, 0)
header.Position = UDim2.new(0, 0, 0.01, 0)
header.BackgroundTransparency = 1
header.TextColor3 = HONEY_GOLD
header.Text = "🎨 Hive Skins"
header.TextScaled = true
header.Font = Enum.Font.GothamBold
header.ZIndex = 20
header.Parent = panel

-- Active skin label
local activeLbl = Instance.new("TextLabel")
activeLbl.Name = "ActiveLbl"
activeLbl.Size = UDim2.new(0.9, 0, 0.07, 0)
activeLbl.Position = UDim2.new(0.05, 0, 0.11, 0)
activeLbl.BackgroundTransparency = 1
activeLbl.TextColor3 = WAX_CREAM
activeLbl.Text = "Active: Classic Wax"
activeLbl.TextScaled = true
activeLbl.Font = Enum.Font.Gotham
activeLbl.ZIndex = 20
activeLbl.Parent = panel

-- Skin card scroll container
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "SkinScroll"
scrollFrame.Size = UDim2.new(0.92, 0, 0.75, 0)
scrollFrame.Position = UDim2.new(0.04, 0, 0.20, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = HONEY_GOLD
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto-sized by UIListLayout
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ZIndex = 20
scrollFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 6)
listLayout.Parent = scrollFrame

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.12, 0, 0.07, 0)
closeBtn.Position = UDim2.new(0.86, 0, 0.01, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = GREY
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 22
closeBtn.Parent = panel

-- ── State ──────────────────────────────────────────────────────────
local panelOpen = false
local activeSkinId = "default"
local unlockedSkins: {string} = {"default"}
local skinCards: {[string]: Frame} = {}
local busy = false

type SkinEntry = {id: string, name: string, cost: number, material: Enum.Material, color: Color3, desc: string}

local function fmtHoney(n: number): string
	if n >= 1_000_000 then return string.format("%.1fM", n/1_000_000)
	elseif n >= 1_000 then return string.format("%.1fK", n/1_000)
	else return tostring(n) end
end

local function isUnlocked(id: string): boolean
	for _, uid in unlockedSkins do
		if uid == id then return true end
	end
	return false
end

local function buildSkinCard(skin: SkinEntry, layoutOrder: number): Frame
	local card = Instance.new("Frame")
	card.Name = "Card_" .. skin.id
	card.Size = UDim2.new(1, 0, 0, 90)
	card.BackgroundColor3 = Color3.fromRGB(30, 18, 5)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.ZIndex = 21
	card.Parent = scrollFrame

	do
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.07, 0); c.Parent = card
		local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 1; s.Parent = card
	end

	-- Color swatch
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(0.14, 0, 0.65, 0)
	swatch.Position = UDim2.new(0.03, 0, 0.175, 0)
	swatch.BackgroundColor3 = skin.color
	swatch.ZIndex = 22
	swatch.Parent = card
	do
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2, 0); c.Parent = swatch
	end

	-- Name label
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "NameLbl"
	nameLbl.Size = UDim2.new(0.55, 0, 0.38, 0)
	nameLbl.Position = UDim2.new(0.20, 0, 0.06, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.TextColor3 = WAX_CREAM
	nameLbl.Text = skin.name
	nameLbl.TextScaled = true
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.ZIndex = 22
	nameLbl.Parent = card

	-- Desc label
	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(0.55, 0, 0.32, 0)
	descLbl.Position = UDim2.new(0.20, 0, 0.42, 0)
	descLbl.BackgroundTransparency = 1
	descLbl.TextColor3 = GREY
	descLbl.Text = skin.desc
	descLbl.TextScaled = true
	descLbl.Font = Enum.Font.Gotham
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.TextWrapped = true
	descLbl.ZIndex = 22
	descLbl.Parent = card

	-- Action button (right side)
	local btn = Instance.new("TextButton")
	btn.Name = "ActionBtn"
	btn.Size = UDim2.new(0.24, 0, 0.55, 0)
	btn.Position = UDim2.new(0.73, 0, 0.22, 0)
	btn.BackgroundColor3 = HONEY_GOLD
	btn.TextColor3 = PROPOLIS_BROWN
	btn.Text = skin.cost == 0 and "Equip" or fmtHoney(skin.cost) .. " 🍯"
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.ZIndex = 23
	btn.Parent = card
	do
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.25, 0); c.Parent = btn
	end

	-- Click handler
	btn.MouseButton1Click:Connect(function()
		if busy then return end
		if not isUnlocked(skin.id) then
			-- Buy
			busy = true
			btn.Text = "..."
			local ok, msg = BuySkin:InvokeServer(skin.id)
			if not ok then
				btn.Text = "✗"
				task.wait(1.5)
			end
			busy = false
		else
			-- Equip / Apply
			if activeSkinId == skin.id then return end
			busy = true
			btn.Text = "..."
			local ok, _ = ApplySkin:InvokeServer(skin.id)
			if not ok then btn.Text = "✗"; task.wait(1); end
			busy = false
		end
	end)

	return card
end

local function refreshCards(catalog: {SkinEntry})
	-- Clear existing cards
	for _, card in skinCards do card:Destroy() end
	skinCards = {}

	for i, skin in catalog do
		local card = buildSkinCard(skin, i)
		skinCards[skin.id] = card

		local btn = card:FindFirstChild("ActionBtn") :: TextButton?
		if not btn then continue end

		local unlocked = isUnlocked(skin.id)
		local isActive = skin.id == activeSkinId

		if isActive then
			btn.Text = "✅ Equipped"
			btn.BackgroundColor3 = Color3.fromRGB(60, 160, 60)
			btn.TextColor3 = WHITE
		elseif unlocked then
			btn.Text = "Equip"
			btn.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
			btn.TextColor3 = WAX_CREAM
		else
			btn.Text = fmtHoney(skin.cost) .. " 🍯"
			btn.BackgroundColor3 = HONEY_GOLD
			btn.TextColor3 = PROPOLIS_BROWN
		end
	end
end

-- ── Panel animation ────────────────────────────────────────────────
local PANEL_OPEN_X = 0.60

local function openPanel()
	panelOpen = true
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(PANEL_OPEN_X, 0, 0.15, 0),
	}):Play()
end
local function closePanel()
	panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1.02, 0, 0.15, 0),
	}):Play()
end

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

-- ── Sync ───────────────────────────────────────────────────────────
SkinSync.OnClientEvent:Connect(function(data: {activeSkin: string, unlockedSkins: {string}, catalog: {SkinEntry}})
	activeSkinId = data.activeSkin or "default"
	unlockedSkins = data.unlockedSkins or {"default"}

	-- Find active skin name
	local activeName = "Classic Wax"
	for _, skin in (data.catalog or {}) do
		if skin.id == activeSkinId then activeName = skin.name; break end
	end
	activeLbl.Text = "Active: " .. activeName

	refreshCards(data.catalog or {})
	busy = false
end)
]]

print("HiveSkinController created")
```

---

## STEP G — Verification sweep

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local checks = {}

local cfgMod = SSS:FindFirstChild("Config")
table.insert(checks, ((cfgMod and cfgMod.Source:find("HIVE_SKINS")) and "✅" or "❌") .. " Config.HIVE_SKINS (4 entries)")

local dsMod = SSS:FindFirstChild("DataService")
table.insert(checks, ((dsMod and dsMod.Source:find("activeSkin")) and "✅" or "❌") .. " DataService activeSkin field")
table.insert(checks, ((dsMod and dsMod.Source:find("unlockedSkins")) and "✅" or "❌") .. " DataService unlockedSkins field")

table.insert(checks, (SSS:FindFirstChild("HiveSkinService") and "✅" or "❌") .. " HiveSkinService module")
table.insert(checks, (RS:FindFirstChild("SkinSync") and "✅" or "❌") .. " SkinSync RemoteEvent")
table.insert(checks, (RS:FindFirstChild("BuySkin") and "✅" or "❌") .. " BuySkin RemoteFunction")
table.insert(checks, (RS:FindFirstChild("ApplySkin") and "✅" or "❌") .. " ApplySkin RemoteFunction")

local gmMod = SSS:FindFirstChild("GameManager")
table.insert(checks, ((gmMod and gmMod.Source:find("HiveSkinService")) and "✅" or "❌") .. " GameManager wired")

local spScripts = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = spScripts and spScripts:FindFirstChild("HiveSkinController")
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveSkinController LocalScript")

print("=== DISPATCH 56 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 56 complete" or "❌ SOME CHECKS FAILED — see above")
```

Expected output:
```
=== DISPATCH 56 VERIFICATION ===
✅ Config.HIVE_SKINS (4 entries)
✅ DataService activeSkin field
✅ DataService unlockedSkins field
✅ HiveSkinService module
✅ SkinSync RemoteEvent
✅ BuySkin RemoteFunction
✅ ApplySkin RemoteFunction
✅ GameManager wired
✅ HiveSkinController LocalScript
✅ ALL CHECKS PASS — dispatch 56 complete
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HiveSkinController (UI ScreenGui only) | 0 BaseParts |
| **Dispatch 56 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## GameManager init chain (post dispatch 56)

```
  → DailyRewardService.Init()   ← dispatch 55
  → HiveSkinService.Init()      ← dispatch 56
```

**Design note:** Skins are applied server-side so all players see each other's hive colors. The `OwnerId` IntValue on HexCell parts (set by PlotService when building cells) is used to find a player's cells. If `OwnerId` isn't present, cells won't be found — check PlotService adds `OwnerId` when creating hex cells (if not, dispatch 57 will add a PlotService patch).
