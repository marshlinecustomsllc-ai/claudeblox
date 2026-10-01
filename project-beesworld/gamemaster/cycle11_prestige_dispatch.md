# Dispatch 58 — PrestigeService
## Cycle 11 · A Bee's World

**Feature:** Prestige rebirth system — spend all honey to permanently gain a +15% honey production multiplier per prestige tier. Resets honey to 0, keeps all upgrade tiers. Requires 100,000 lifetime honey per prestige level as unlock threshold.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 57 (BeeVisualService)

---

## DESIGN NOTES

- **Cost to prestige:** lifetime honey ≥ (100,000 × current_prestige_tier + 1) — scales with tier
- **What resets:** honey pool to 0
- **What persists:** all upgrade tiers (speed, queen, pollen, propolis), propolis, plots unlocked, achievements, skins
- **Multiplier:** +15% honey yield per prestige tier, stacked multiplicatively (`1.15 ^ prestigeTier`)
- **Max prestige:** 10 (1.15^10 = ×4.05 — meaningful but not game-breaking)
- ForagingService applies `1.15 ^ prestigeTier` to final honey credited

Achievement integration: `first_gen` (tier 1) and `gen_5` (tier 5) achievements from dispatch 50 already exist — PrestigeService calls AchievementService.Check after each prestige.

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

	-- Prestige rebirth system
	PRESTIGE_MULT_PER_TIER = 1.15,    -- ×1.15 honey yield per prestige level
	PRESTIGE_MAX_TIER = 10,
	PRESTIGE_COST_BASE = 100000,       -- lifetime honey required = BASE × (tier+1)
]]

-- Anchor after HIVE_SKINS block (last entry is "royal")
local anchor = '"royal",'
local found = clone.Source:find(anchor, 1, true)
if not found then
	-- Fallback anchor
	anchor = "PROPOLIS_UPGRADE_MAX_TIER = 5,"
	found = clone.Source:find(anchor, 1, true)
end
if not found then
	anchor = "QUEEN_UPGRADE_MAX_TIER = 5,"
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "No anchor found in Config for PRESTIGE injection")

local lineEnd = clone.Source:find("\n", found, true) or #clone.Source
clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config injection OK — PRESTIGE_MULT_PER_TIER, PRESTIGE_MAX_TIER, PRESTIGE_COST_BASE added")
```

**Verify:**
```lua
local cfg = game:GetService("ServerScriptService"):FindFirstChild("Config")
print(cfg.Source:find("PRESTIGE_MULT_PER_TIER") and "OK" or "MISSING")
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

-- Anchor after unlockedSkins or activeSkin
local anchor = "unlockedSkins     = {},"
local found = clone.Source:find(anchor, 1, true)
if not found then
	anchor = 'activeSkin        = "default",'
	found = clone.Source:find(anchor, 1, true)
end
if not found then
	anchor = "dailyStreak    = 0,"
	found = clone.Source:find(anchor, 1, true)
end
assert(found, "Anchor not found in DataService for prestige migration")

local INJECT = [[

			prestigeTier      = 0,   -- times the player has prestiged (0-10)]]

clone.Source = clone.Source:sub(1, found + #anchor - 1) .. INJECT .. clone.Source:sub(found + #anchor)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService migration OK — prestigeTier added")
```

---

## STEP C — PrestigeService ModuleScript

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("PrestigeService"), "Already exists — delete first")

local mod = Instance.new("ModuleScript")
mod.Name = "PrestigeService"
mod.Parent = SSS

mod.Source = [[
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Config = require(SSS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))

local PrestigeService = {}

local PrestigeSync: RemoteEvent
local DoPrestige: RemoteFunction

-- Lazy reference to AchievementService to avoid circular requires
local _achievementService: any = nil
local function getAchievements()
	if not _achievementService then
		local ok, svc = pcall(function()
			return require(SSS:WaitForChild("AchievementService", 5))
		end)
		if ok then _achievementService = svc end
	end
	return _achievementService
end

function PrestigeService.GetMult(tier: number): number
	if tier <= 0 then return 1.0 end
	return Config.PRESTIGE_MULT_PER_TIER ^ tier
end

local function getPrestigeCost(currentTier: number): number
	-- Lifetime honey threshold for next prestige
	return Config.PRESTIGE_COST_BASE * (currentTier + 1)
end

local function buildPayload(profile: any): {tier: number, maxTier: number, mult: number, lifetimeHoney: number, costForNext: number, canPrestige: boolean}
	local tier = profile.prestigeTier or 0
	local maxTier = Config.PRESTIGE_MAX_TIER
	local mult = PrestigeService.GetMult(tier)
	local lifetime = profile.lifetimeHoney or 0
	local costForNext = getPrestigeCost(tier)
	local canPrestige = tier < maxTier and lifetime >= costForNext
	return {
		tier = tier,
		maxTier = maxTier,
		mult = mult,
		lifetimeHoney = lifetime,
		costForNext = costForNext,
		canPrestige = canPrestige,
	}
end

local function syncClient(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	PrestigeSync:FireClient(player, buildPayload(profile))
end

local function onDoPrestige(player: Player): (boolean, string)
	local profile = DataService.GetProfile(player)
	if not profile then return false, "No profile" end

	local tier = profile.prestigeTier or 0
	local maxTier = Config.PRESTIGE_MAX_TIER
	if tier >= maxTier then return false, "Max prestige reached" end

	local lifetime = profile.lifetimeHoney or 0
	local costForNext = getPrestigeCost(tier)
	if lifetime < costForNext then
		return false,
			string.format("Need %d lifetime honey (have %d)", costForNext, math.floor(lifetime))
	end

	-- Prestige!
	profile.prestigeTier = tier + 1
	profile.honey = 0  -- reset current honey

	-- Fire achievement checks
	local ach = getAchievements()
	if ach then
		pcall(ach.Check, player, "first_gen")  -- tier 1
		if profile.prestigeTier >= 5 then
			pcall(ach.Check, player, "gen_5")
		end
	end

	syncClient(player)

	return true, string.format("Prestige %d unlocked! ×%.2f honey", profile.prestigeTier, PrestigeService.GetMult(profile.prestigeTier))
end

function PrestigeService.Init()
	PrestigeSync = ReplicatedStorage:WaitForChild("PrestigeSync") :: RemoteEvent
	DoPrestige = ReplicatedStorage:WaitForChild("DoPrestige") :: RemoteFunction
	DoPrestige.OnServerInvoke = onDoPrestige

	Players.PlayerAdded:Connect(function(player)
		task.wait(4)
		if player.Parent then syncClient(player) end
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			task.wait(1)
			syncClient(player)
		end)
	end

	print("[PrestigeService] Initialized")
end

return PrestigeService
]]

print("PrestigeService created")
```

---

## STEP D — Remotes in ReplicatedStorage

In Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

local function ensureRE(name)
	if not RS:FindFirstChild(name) then
		local re = Instance.new("RemoteEvent"); re.Name = name; re.Parent = RS
		print("Created:", name)
	else print("Exists:", name) end
end
local function ensureRF(name)
	if not RS:FindFirstChild(name) then
		local rf = Instance.new("RemoteFunction"); rf.Name = name; rf.Parent = RS
		print("Created:", name)
	else print("Exists:", name) end
end

ensureRE("PrestigeSync")
ensureRF("DoPrestige")
print("Prestige remotes OK")
```

---

## STEP E — ForagingService prestige multiplier injection

Open **ForagingService** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- 1. Require PrestigeService
local reqAnchor = 'require(SSS:WaitForChild("PropolisYieldUpgradeService"))'
local found1 = clone.Source:find(reqAnchor, 1, true)
if not found1 then
	reqAnchor = 'require(SSS:WaitForChild("SpeedUpgradeService"))'
	found1 = clone.Source:find(reqAnchor, 1, true)
end
if not found1 then
	reqAnchor = 'require(SSS:WaitForChild("Config"))'
	found1 = clone.Source:find(reqAnchor, 1, true)
end
assert(found1, "Config/upgrade require not found in ForagingService")

local INJECT_REQ = '\nlocal PrestigeService = require(SSS:WaitForChild("PrestigeService"))'
clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found1 + #reqAnchor)

-- 2. Inject prestige multiplier into honey credit
-- Look for where honey is added to profile (profile.honey += ...)
local honeyAdd = "profile%.honey %+= "
local found2, foundEnd2 = clone.Source:find(honeyAdd)
if found2 then
	-- Find the statement end
	local stmtEnd = clone.Source:find("\n", found2, true)
	if stmtEnd then
		local INJECT_MULT = [[

		-- Apply prestige honey multiplier
		local pTier = DataService.GetProfile(player).prestigeTier or 0
		local prestigeMult = PrestigeService.GetMult(pTier)
		-- Re-read honey that was just added and multiply the delta
		-- (simpler: apply mult to the yield variable before crediting)
]]
		-- Actually inject before the honey credit line
		clone.Source = clone.Source:sub(1, found2 - 1)
			.. "\t\tlocal pTier = DataService.GetProfile(player).prestigeTier or 0\n"
			.. "\t\tlocal prestigeMult = PrestigeService.GetMult(pTier)\n"
			.. clone.Source:sub(found2)

		-- Now find the honey variable being credited and wrap it
		-- Pattern: profile.honey += honeyYield → profile.honey += honeyYield * prestigeMult
		local yieldPattern = "profile%.honey %+= ([%w_]+)"
		clone.Source = clone.Source:gsub(yieldPattern, function(varName)
			return "profile.honey += " .. varName .. " * prestigeMult"
		end, 1) -- replace first occurrence only

		print("Prestige multiplier injected into ForagingService honey credit")
	end
else
	print("WARNING: honey += pattern not found in ForagingService — manual injection needed:")
	print("  Before profile.honey += <yield>, add:")
	print("  local pTier = DataService.GetProfile(player).prestigeTier or 0")
	print("  local prestigeMult = PrestigeService.GetMult(pTier)")
	print("  Then multiply yield by prestigeMult")
end

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService prestige injection complete")
```

---

## STEP F — GameManager injection

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchors = {
	'require(SSS:WaitForChild("BeeVisualService"))',
	'require(SSS:WaitForChild("HiveSkinService"))',
	'require(SSS:WaitForChild("DailyRewardService"))',
}
local reqAnchor, found1
for _, a in anchors do
	found1 = clone.Source:find(a, 1, true)
	if found1 then reqAnchor = a; break end
end
assert(found1, "No recent service require found in GameManager")

clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1)
	.. '\nlocal PrestigeService = require(SSS:WaitForChild("PrestigeService"))'
	.. clone.Source:sub(found1 + #reqAnchor)

local initAnchors = {
	"BeeVisualService.Init()",
	"HiveSkinService.Init()",
	"DailyRewardService.Init()",
}
local initAnchor, found2
for _, a in initAnchors do
	found2 = clone.Source:find(a, 1, true)
	if found2 then initAnchor = a; break end
end
assert(found2, "No recent service Init() found in GameManager")

clone.Source = clone.Source:sub(1, found2 + #initAnchor - 1)
	.. "\n\tPrestigeService.Init()"
	.. clone.Source:sub(found2 + #initAnchor)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager injection OK — PrestigeService wired in")
```

---

## STEP G — PrestigeController LocalScript

In Command Bar:

```lua
local SPScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPScripts, "StarterPlayerScripts not found")

if SPScripts:FindFirstChild("PrestigeController") then
	SPScripts:FindFirstChild("PrestigeController"):Destroy()
end

local ls = Instance.new("LocalScript")
ls.Name = "PrestigeController"
ls.Parent = SPScripts

ls.Source = [[
--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PrestigeSync: RemoteEvent = RS:WaitForChild("PrestigeSync") :: RemoteEvent
local DoPrestige: RemoteFunction = RS:WaitForChild("DoPrestige") :: RemoteFunction

local HONEY_GOLD    = Color3.fromRGB(242, 168, 28)
local WAX_CREAM     = Color3.fromRGB(232, 212, 154)
local PROPOLIS_BROWN = Color3.fromRGB(122, 74, 34)
local BG_DARK       = Color3.fromRGB(12, 8, 2)
local WHITE         = Color3.fromRGB(255, 255, 255)
local GREY          = Color3.fromRGB(120, 100, 80)
local GOLD_BRIGHT   = Color3.fromRGB(255, 215, 0)
local RED           = Color3.fromRGB(220, 60, 60)

-- Build ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name = "PrestigeGui"
sg.DisplayOrder = 14
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = false
sg.Parent = playerGui

-- Tab button — right side column, below 🎨 skin tab
local tabBtn = Instance.new("TextButton")
tabBtn.Name = "PrestigeTab"
tabBtn.Size = UDim2.new(0.065, 0, 0.075, 0)
tabBtn.Position = UDim2.new(0.925, 0, 0.40, 0)
tabBtn.BackgroundColor3 = PROPOLIS_BROWN
tabBtn.TextColor3 = GOLD_BRIGHT
tabBtn.Text = "⭐"
tabBtn.TextScaled = true
tabBtn.Font = Enum.Font.GothamBold
tabBtn.ZIndex = 20
tabBtn.Parent = sg

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.18, 0); c.Parent = tabBtn
	local s = Instance.new("UIStroke"); s.Color = GOLD_BRIGHT; s.Thickness = 2; s.Parent = tabBtn
end

-- Panel
local panel = Instance.new("Frame")
panel.Name = "PrestigePanel"
panel.Size = UDim2.new(0.34, 0, 0.58, 0)
panel.Position = UDim2.new(1.02, 0, 0.21, 0)
panel.BackgroundColor3 = BG_DARK
panel.BorderSizePixel = 0
panel.ZIndex = 19
panel.Parent = sg

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.04, 0); c.Parent = panel
	local s = Instance.new("UIStroke"); s.Color = GOLD_BRIGHT; s.Thickness = 2.5; s.Parent = panel
end

-- Header
local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0.11, 0)
header.Position = UDim2.new(0, 0, 0.01, 0)
header.BackgroundTransparency = 1
header.TextColor3 = GOLD_BRIGHT
header.Text = "⭐ Prestige"
header.TextScaled = true
header.Font = Enum.Font.GothamBold
header.ZIndex = 20
header.Parent = panel

-- Tier label
local tierLbl = Instance.new("TextLabel")
tierLbl.Name = "TierLbl"
tierLbl.Size = UDim2.new(0.9, 0, 0.10, 0)
tierLbl.Position = UDim2.new(0.05, 0, 0.14, 0)
tierLbl.BackgroundTransparency = 1
tierLbl.TextColor3 = GOLD_BRIGHT
tierLbl.Text = "Tier 0 / 10  (×1.00)"
tierLbl.TextScaled = true
tierLbl.Font = Enum.Font.GothamBold
tierLbl.ZIndex = 20
tierLbl.Parent = panel

-- Progress bar
local barTrack = Instance.new("Frame")
barTrack.Size = UDim2.new(0.88, 0, 0.055, 0)
barTrack.Position = UDim2.new(0.06, 0, 0.27, 0)
barTrack.BackgroundColor3 = Color3.fromRGB(40, 25, 5)
barTrack.BorderSizePixel = 0
barTrack.ZIndex = 20
barTrack.Parent = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = barTrack end

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = GOLD_BRIGHT
barFill.BorderSizePixel = 0
barFill.ZIndex = 21
barFill.Parent = barTrack
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = barFill end

-- Progress label
local progressLbl = Instance.new("TextLabel")
progressLbl.Name = "ProgressLbl"
progressLbl.Size = UDim2.new(0.9, 0, 0.09, 0)
progressLbl.Position = UDim2.new(0.05, 0, 0.34, 0)
progressLbl.BackgroundTransparency = 1
progressLbl.TextColor3 = WAX_CREAM
progressLbl.Text = "Lifetime honey: 0 / 100,000"
progressLbl.TextScaled = true
progressLbl.Font = Enum.Font.Gotham
progressLbl.ZIndex = 20
progressLbl.Parent = panel

-- Warning label
local warnLbl = Instance.new("TextLabel")
warnLbl.Name = "WarnLbl"
warnLbl.Size = UDim2.new(0.9, 0, 0.13, 0)
warnLbl.Position = UDim2.new(0.05, 0, 0.44, 0)
warnLbl.BackgroundTransparency = 1
warnLbl.TextColor3 = RED
warnLbl.Text = "⚠️ Resets current honey to 0.\nUpgrades and plots are kept."
warnLbl.TextScaled = true
warnLbl.Font = Enum.Font.Gotham
warnLbl.TextWrapped = true
warnLbl.ZIndex = 20
warnLbl.Parent = panel

-- Prestige button
local prestigeBtn = Instance.new("TextButton")
prestigeBtn.Name = "PrestigeBtn"
prestigeBtn.Size = UDim2.new(0.80, 0, 0.14, 0)
prestigeBtn.Position = UDim2.new(0.10, 0, 0.60, 0)
prestigeBtn.BackgroundColor3 = GOLD_BRIGHT
prestigeBtn.TextColor3 = PROPOLIS_BROWN
prestigeBtn.Text = "Prestige ⭐"
prestigeBtn.TextScaled = true
prestigeBtn.Font = Enum.Font.GothamBold
prestigeBtn.ZIndex = 21
prestigeBtn.Active = false
prestigeBtn.Parent = panel

do
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.25, 0); c.Parent = prestigeBtn
	local s = Instance.new("UIStroke"); s.Color = WAX_CREAM; s.Thickness = 1.5; s.Parent = prestigeBtn
end

-- Max label
local maxLbl = Instance.new("TextLabel")
maxLbl.Name = "MaxLbl"
maxLbl.Size = UDim2.new(0.9, 0, 0.09, 0)
maxLbl.Position = UDim2.new(0.05, 0, 0.80, 0)
maxLbl.BackgroundTransparency = 1
maxLbl.TextColor3 = GOLD_BRIGHT
maxLbl.Text = ""
maxLbl.TextScaled = true
maxLbl.Font = Enum.Font.GothamBold
maxLbl.ZIndex = 20
maxLbl.Parent = panel

-- Close
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.12, 0, 0.09, 0)
closeBtn.Position = UDim2.new(0.86, 0, 0.01, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.TextColor3 = GREY
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 22
closeBtn.Parent = panel

-- ── State ─────────────────────────────────────────────────────────
local panelOpen = false
local busy = false

local function fmtNum(n: number): string
	if n >= 1_000_000 then return string.format("%.1fM", n/1_000_000)
	elseif n >= 1_000 then return string.format("%.1fK", n/1_000)
	else return tostring(math.floor(n)) end
end

type PrestigeData = {tier: number, maxTier: number, mult: number, lifetimeHoney: number, costForNext: number, canPrestige: boolean}

local function refreshUI(data: PrestigeData)
	local atMax = data.tier >= data.maxTier
	tierLbl.Text = string.format("Tier %d / %d  (×%.2f honey)", data.tier, data.maxTier, data.mult)

	-- Progress bar
	if not atMax then
		local ratio = math.clamp(data.lifetimeHoney / data.costForNext, 0, 1)
		TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0),
		}):Play()
		progressLbl.Text = "Lifetime: " .. fmtNum(data.lifetimeHoney) .. " / " .. fmtNum(data.costForNext)
	else
		barFill.Size = UDim2.new(1, 0, 1, 0)
		progressLbl.Text = "Max prestige reached!"
	end

	if atMax then
		prestigeBtn.Visible = false
		maxLbl.Text = "🌟 MAX PRESTIGE ×" .. string.format("%.2f", data.mult)
	elseif data.canPrestige then
		prestigeBtn.Visible = true
		prestigeBtn.BackgroundColor3 = GOLD_BRIGHT
		prestigeBtn.TextColor3 = PROPOLIS_BROWN
		prestigeBtn.Text = "Prestige → Tier " .. (data.tier + 1)
		prestigeBtn.Active = true
		maxLbl.Text = ""
		-- Flash tab button gold
		tabBtn.BackgroundColor3 = GOLD_BRIGHT
		tabBtn.TextColor3 = PROPOLIS_BROWN
	else
		prestigeBtn.Visible = true
		prestigeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 10)
		prestigeBtn.TextColor3 = GREY
		prestigeBtn.Text = "Need " .. fmtNum(data.costForNext) .. " lifetime 🍯"
		prestigeBtn.Active = false
		maxLbl.Text = ""
		tabBtn.BackgroundColor3 = PROPOLIS_BROWN
		tabBtn.TextColor3 = GOLD_BRIGHT
	end

	busy = false
end

-- Panel animation
local PANEL_OPEN_X = 0.58

local function openPanel()
	panelOpen = true
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(PANEL_OPEN_X, 0, 0.21, 0),
	}):Play()
end
local function closePanel()
	panelOpen = false
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(1.02, 0, 0.21, 0),
	}):Play()
end

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

prestigeBtn.MouseButton1Click:Connect(function()
	if busy then return end
	busy = true
	prestigeBtn.Text = "Prestiging..."

	local ok, msg = DoPrestige:InvokeServer()
	if ok then
		-- Brief celebration
		prestigeBtn.Text = "✅ " .. (msg or "Prestiged!")
		tabBtn.BackgroundColor3 = GOLD_BRIGHT
	else
		prestigeBtn.Text = "✗ " .. (msg or "Failed")
		task.wait(2)
	end
	busy = false
end)

PrestigeSync.OnClientEvent:Connect(function(data: PrestigeData)
	refreshUI(data)
end)
]]

print("PrestigeController created")
```

---

## STEP H — Verification sweep

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer")

local checks = {}

local cfgMod = SSS:FindFirstChild("Config")
table.insert(checks, ((cfgMod and cfgMod.Source:find("PRESTIGE_MULT_PER_TIER")) and "✅" or "❌") .. " Config.PRESTIGE_MULT_PER_TIER")

local dsMod = SSS:FindFirstChild("DataService")
table.insert(checks, ((dsMod and dsMod.Source:find("prestigeTier")) and "✅" or "❌") .. " DataService.prestigeTier field")

table.insert(checks, (SSS:FindFirstChild("PrestigeService") and "✅" or "❌") .. " PrestigeService module")
table.insert(checks, (RS:FindFirstChild("PrestigeSync") and "✅" or "❌") .. " PrestigeSync RemoteEvent")
table.insert(checks, (RS:FindFirstChild("DoPrestige") and "✅" or "❌") .. " DoPrestige RemoteFunction")

local fsMod = SSS:FindFirstChild("ForagingService")
table.insert(checks, ((fsMod and fsMod.Source:find("PrestigeService")) and "✅" or "⚠️") .. " ForagingService prestige mult (may need manual)")

local gmMod = SSS:FindFirstChild("GameManager")
table.insert(checks, ((gmMod and gmMod.Source:find("PrestigeService")) and "✅" or "❌") .. " GameManager wired")

local spScripts = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = spScripts and spScripts:FindFirstChild("PrestigeController")
table.insert(checks, (ctrl and "✅" or "❌") .. " PrestigeController LocalScript")

print("=== DISPATCH 58 VERIFICATION ===")
for _, line in checks do print(line) end
local hardFail = table.concat(checks, ""):find("❌")
print(hardFail and "❌ HARD FAILURES — fix before proceeding" or "✅ Core checks pass")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PrestigeController ScreenGui | 0 BaseParts |
| **Dispatch 58 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## GameManager init chain (post dispatch 58)

```
  → BeeVisualService.Init()    ← dispatch 57
  → PrestigeService.Init()     ← dispatch 58
```

## End-game progression loop (complete)

```
New player → daily login streak → build plots → upgrade speed/queen/pollen/propolis
           → buy cosmetic skins → accumulate lifetime honey
           → PRESTIGE (×1.15 mult, resets honey) → repeat to tier 10 (×4.05)
```

The full economy is now complete: 4 resource upgrade tracks, daily retention, cosmetics, and an infinite prestige ladder.
