# Dispatch 166 — Colony Health Meter
**File:** `cycle15_colony_health_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,198 / 5,000
**Part budget after:** 4,198 / 5,000 (+0)

---

## Overview

Players currently have no at-a-glance signal for "is my hive thriving or struggling?" — they must read four separate bars and tabs to piece it together. This dispatch adds a **Colony Health Meter**: a persistent HUD pill showing a 0–100 health score, a matching emoji face (😄 → 😐 → 😟 → 😰), and a 5s toast when health changes tier. Adults can tap the pill to see the exact breakdown (population balance, comb fill, queen presence, foraging activity). Kids just see the face and a single-sentence vibe.

---

## Step 1 — ColonyHealthService (ServerScriptService.Systems)

Open **ServerScriptService → Systems** and create a new **Script** named `ColonyHealthService`.

Paste exactly:

```lua
--!strict
-- ColonyHealthService: computes a 0-100 colony health score per player every 10s
-- Score = weighted average of 4 sub-scores (population, comb, queen, foraging)

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config  = require(Modules:WaitForChild("Config"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HealthSync_166: RemoteEvent = Remotes:WaitForChild("ColonyHealthSync")

local POLL_INTERVAL_166 = 10  -- seconds between full recalculation

-- Weight of each sub-score (must sum to 1.0)
local WEIGHTS_166 = {
	population = 0.30,
	comb       = 0.30,
	queen      = 0.20,
	foraging   = 0.20,
}

-- Thresholds for health tier (used server-side for change detection)
local TIERS_166 = {
	{ min = 80, label = "thriving"   },
	{ min = 55, label = "stable"     },
	{ min = 30, label = "struggling" },
	{ min = 0,  label = "critical"   },
}

local function getTier_166(score: number): string
	for _, t in TIERS_166 do
		if score >= t.min then return t.label end
	end
	return "critical"
end

-- Population sub-score: ratio of actual bees to ideal pop cap
-- Ideal cap comes from ForagingService attribute or defaults to 20
local function scorePopulation_166(player: Player): number
	local pop   = player:GetAttribute("BeeCount")   or 0
	local ideal = player:GetAttribute("BeeCapacity") or 20
	if ideal <= 0 then return 50 end
	local ratio = math.min(pop / ideal, 1.0)
	-- 100 at full cap, 0 at 0 bees — linear but floored at 0
	return math.floor(ratio * 100 + 0.5)
end

-- Comb sub-score: fraction of built Honey cells that have any content
-- Reads HoneyCount attribute as a proxy (honeystored / honeyCapacity)
local function scoreComb_166(player: Player): number
	local stored   = player:GetAttribute("HoneyCount")    or 0
	local capacity = player:GetAttribute("HoneyCapacity") or 1
	if capacity <= 0 then return 50 end
	local frac = math.min(stored / capacity, 1.0)
	-- 100 at full, 30 at empty (empty comb isn't a crisis, just not ideal)
	return math.floor(30 + frac * 70 + 0.5)
end

-- Queen sub-score: 100 if queen present (QueenTier > 0), 40 otherwise
local function scoreQueen_166(player: Player): number
	local tier = player:GetAttribute("QueenTier") or 0
	if tier >= 1 then
		-- Extra points for higher-tier queens
		return math.min(100, 70 + tier * 6)
	end
	return 40  -- hive without a queen is functional but not thriving
end

-- Foraging sub-score: based on last-known foraging quality multiplier
-- GhostBeeQualMult attribute is set by ForagingService; 1.0 = baseline
local function scoreForaging_166(player: Player): number
	local qualMult = player:GetAttribute("GhostBeeQualMult") or 1.0
	-- Also factor in weather modifier stored on player (qualMod from WeatherService)
	local weatherMod = player:GetAttribute("WeatherQualMod") or 0  -- percent, e.g. 15 or -10
	local effective = qualMult * (1 + weatherMod / 100)
	-- Map 0..2 range to 0..100
	local score = math.min(effective / 2, 1.0) * 100
	return math.floor(score + 0.5)
end

local function computeHealth_166(player: Player): (number, number, number, number, number)
	local pop      = scorePopulation_166(player)
	local comb     = scoreComb_166(player)
	local queen    = scoreQueen_166(player)
	local foraging = scoreForaging_166(player)
	local total = math.floor(
		pop      * WEIGHTS_166.population +
		comb     * WEIGHTS_166.comb +
		queen    * WEIGHTS_166.queen +
		foraging * WEIGHTS_166.foraging
		+ 0.5
	)
	return total, pop, comb, queen, foraging
end

-- Track last-sent tier per player to fire tier-change toasts
local lastTier_166: { [number]: string } = {}

local function pollPlayer_166(player: Player)
	local total, pop, comb, queen, foraging = computeHealth_166(player)
	local tier = getTier_166(total)
	local prevTier = lastTier_166[player.UserId]
	local tierChanged = (prevTier ~= nil) and (prevTier ~= tier)
	lastTier_166[player.UserId] = tier

	local payload = {
		total     = total,
		tier      = tier,
		tierChanged = tierChanged,
		pop       = pop,
		comb      = comb,
		queen     = queen,
		foraging  = foraging,
	}

	local ok, err = pcall(function()
		HealthSync_166:FireClient(player, payload)
	end)
	if not ok then
		warn("[ColonyHealthService] FireClient failed:", err)
	end
end

-- Initial sync on join
Players.PlayerAdded:Connect(function(player: Player)
	player.CharacterAdded:Wait()
	task.wait(2)  -- let other services set attributes first
	lastTier_166[player.UserId] = nil  -- force tierChanged=false on first send
	pollPlayer_166(player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastTier_166[player.UserId] = nil
end)

-- Periodic poll loop
task.spawn(function()
	while true do
		task.wait(POLL_INTERVAL_166)
		for _, player in Players:GetPlayers() do
			pollPlayer_166(player)
		end
	end
end)
```

---

## Step 2 — ColonyHealthSync RemoteEvent

In **Studio Command Bar**, run:

```lua
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not R:FindFirstChild("ColonyHealthSync") then
	local re = Instance.new("RemoteEvent")
	re.Name = "ColonyHealthSync"
	re.Parent = R
	print("ColonyHealthSync created")
else
	print("ColonyHealthSync already exists")
end
```

---

## Step 3 — WeatherQualMod attribute wire-up (WeatherAnnounceService patch)

Open **WeatherAnnounceService** and add one line inside the state-change branch so the health meter can read the weather modifier. Find the block that fires `WeatherChanged`:

```lua
-- existing line (approximately):
HealthSync_166 -- NOT this, find the WeatherChanged FireAllClients call
```

Locate the section that does `WeatherChanged:FireAllClients(...)` and add BEFORE it:

```lua
-- Broadcast weather qualMod as player attribute so ColonyHealthService can read it
for _, plr in Players:GetPlayers() do
	plr:SetAttribute("WeatherQualMod", currentDef.qualMod or 0)
end
```

If WeatherAnnounceService is not yet executed (Studio hasn't run it), add this loop directly inside the `onWeatherChange_165` (or equivalent) function so it fires whenever weather changes.

---

## Step 4 — ColonyHealthController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `ColonyHealthController`.

Paste exactly:

```lua
--!strict
-- ColonyHealthController: persistent colony health pill + tier-change toasts

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player        = Players.LocalPlayer
local PlayerGui     = player:WaitForChild("PlayerGui")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local HealthSync_166: RemoteEvent = Remotes:WaitForChild("ColonyHealthSync")

-- ── Palette ──────────────────────────────────────────────────────────────────
local HONEY_GOLD_166  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN_166  = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_166   = Color3.fromRGB(232, 212, 154)
local GREEN_166       = Color3.fromRGB(80,  200, 80)
local AMBER_166       = Color3.fromRGB(242, 168, 28)
local RED_166         = Color3.fromRGB(220, 60,  60)
local DARK_BG_166     = Color3.fromRGB(30,  18,  8)

-- ── Health tier metadata ──────────────────────────────────────────────────────
local TIER_META_166 = {
	thriving   = { emoji = "😄", color = GREEN_166,      kid = "Your hive is thriving! 🌟",       adult = "All systems healthy." },
	stable     = { emoji = "😐", color = HONEY_GOLD_166, kid = "Your hive is doing okay. 🐝",      adult = "Minor issues to watch." },
	struggling = { emoji = "😟", color = AMBER_166,      kid = "Your hive needs attention! 🌸",    adult = "Check population & comb." },
	critical   = { emoji = "😰", color = RED_166,        kid = "Your hive is in trouble! 🆘",      adult = "Immediate action needed!" },
}

-- ── Build HealthGui ───────────────────────────────────────────────────────────
local function buildGui_166(): (ScreenGui, Frame, TextLabel, TextLabel, Frame)
	local sg = Instance.new("ScreenGui")
	sg.Name            = "ColonyHealthGui"
	sg.ResetOnSpawn    = false
	sg.DisplayOrder    = 13
	sg.IgnoreGuiInset  = true
	sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling

	-- ── Persistent Pill ──────────────────────────────────────────────────────
	local pill = Instance.new("Frame")
	pill.Name            = "HealthPill"
	pill.Size            = UDim2.new(0, 160, 0, 32)
	-- Position: top-left below streak pill area; use right side to avoid weather pill (top-centre)
	pill.Position        = UDim2.new(1, -172, 0, 48)
	pill.BackgroundColor3 = DARK_BG_166
	pill.BorderSizePixel = 0
	pill.ZIndex          = 5
	pill.Parent          = sg

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 14)
	pillCorner.Parent = pill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color     = HONEY_GOLD_166
	pillStroke.Thickness = 1.5
	pillStroke.Parent    = pill

	local faceLabel = Instance.new("TextLabel")
	faceLabel.Name            = "FaceLabel"
	faceLabel.Size            = UDim2.new(0, 30, 1, 0)
	faceLabel.Position        = UDim2.new(0, 4, 0, 0)
	faceLabel.BackgroundTransparency = 1
	faceLabel.Text            = "😐"
	faceLabel.TextSize        = 18
	faceLabel.Font            = Enum.Font.GothamBold
	faceLabel.TextXAlignment  = Enum.TextXAlignment.Center
	faceLabel.ZIndex          = 6
	faceLabel.Parent          = pill

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name           = "ScoreLabel"
	scoreLabel.Size           = UDim2.new(0, 40, 1, 0)
	scoreLabel.Position       = UDim2.new(0, 34, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text           = "—"
	scoreLabel.TextSize       = 14
	scoreLabel.Font           = Enum.Font.GothamBold
	scoreLabel.TextColor3     = WAX_CREAM_166
	scoreLabel.ZIndex         = 6
	scoreLabel.Parent         = pill

	local kidLabel = Instance.new("TextLabel")
	kidLabel.Name             = "KidLabel"
	kidLabel.Size             = UDim2.new(0, 84, 1, 0)
	kidLabel.Position         = UDim2.new(0, 74, 0, 0)
	kidLabel.BackgroundTransparency = 1
	kidLabel.Text             = "Hive Health"
	kidLabel.TextSize         = 11
	kidLabel.Font             = Enum.Font.Gotham
	kidLabel.TextColor3       = WAX_CREAM_166
	kidLabel.TextXAlignment   = Enum.TextXAlignment.Left
	kidLabel.TextTruncate     = Enum.TextTruncate.AtEnd
	kidLabel.ZIndex           = 6
	kidLabel.Parent           = pill

	-- ── Detail Panel (tap to expand) ─────────────────────────────────────────
	local detail = Instance.new("Frame")
	detail.Name              = "DetailPanel"
	detail.Size              = UDim2.new(0, 200, 0, 140)
	detail.Position          = UDim2.new(1, -212, 0, 84)
	detail.BackgroundColor3  = DARK_BG_166
	detail.BackgroundTransparency = 1  -- starts hidden
	detail.BorderSizePixel   = 0
	detail.ZIndex            = 20
	detail.Visible           = false
	detail.Parent            = sg

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 10)
	detailCorner.Parent = detail

	local detailStroke = Instance.new("UIStroke")
	detailStroke.Color     = PROP_BROWN_166
	detailStroke.Thickness = 1.5
	detailStroke.Parent    = detail

	local detailText = Instance.new("TextLabel")
	detailText.Name           = "DetailText"
	detailText.Size           = UDim2.new(1, -16, 1, -12)
	detailText.Position       = UDim2.new(0, 8, 0, 8)
	detailText.BackgroundTransparency = 1
	detailText.Text           = ""
	detailText.TextSize       = 12
	detailText.Font           = Enum.Font.Gotham
	detailText.TextColor3     = WAX_CREAM_166
	detailText.TextXAlignment = Enum.TextXAlignment.Left
	detailText.TextYAlignment = Enum.TextYAlignment.Top
	detailText.TextWrapped    = true
	detailText.RichText       = true
	detailText.ZIndex         = 21
	detailText.Parent         = detail

	sg.Parent = PlayerGui
	return sg, pill, faceLabel, scoreLabel, detail
end

-- ── Build Toast ───────────────────────────────────────────────────────────────
local function buildToast_166(sg: ScreenGui): Frame
	local toast = Instance.new("Frame")
	toast.Name              = "HealthToast"
	toast.Size              = UDim2.new(0, 280, 0, 80)
	toast.Position          = UDim2.new(0.5, -140, 0, -90)
	toast.BackgroundColor3  = DARK_BG_166
	toast.BorderSizePixel   = 0
	toast.ZIndex            = 30
	toast.Parent            = sg

	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 12)
	tc.Parent = toast

	local ts = Instance.new("UIStroke")
	ts.Color     = HONEY_GOLD_166
	ts.Thickness = 2
	ts.Parent    = toast

	local bigEmoji = Instance.new("TextLabel")
	bigEmoji.Name            = "BigEmoji"
	bigEmoji.Size            = UDim2.new(0, 50, 1, 0)
	bigEmoji.Position        = UDim2.new(0, 8, 0, 0)
	bigEmoji.BackgroundTransparency = 1
	bigEmoji.Text            = "😐"
	bigEmoji.TextSize        = 36
	bigEmoji.Font            = Enum.Font.GothamBold
	bigEmoji.TextXAlignment  = Enum.TextXAlignment.Center
	bigEmoji.ZIndex          = 31
	bigEmoji.Parent          = toast

	local toastKid = Instance.new("TextLabel")
	toastKid.Name           = "KidLine"
	toastKid.Size           = UDim2.new(0, 206, 0, 30)
	toastKid.Position       = UDim2.new(0, 62, 0, 8)
	toastKid.BackgroundTransparency = 1
	toastKid.Text           = ""
	toastKid.TextSize       = 15
	toastKid.Font           = Enum.Font.GothamBold
	toastKid.TextColor3     = WAX_CREAM_166
	toastKid.TextWrapped    = true
	toastKid.ZIndex         = 31
	toastKid.Parent         = toast

	local toastAdult = Instance.new("TextLabel")
	toastAdult.Name         = "AdultLine"
	toastAdult.Size         = UDim2.new(0, 206, 0, 28)
	toastAdult.Position     = UDim2.new(0, 62, 0, 42)
	toastAdult.BackgroundTransparency = 1
	toastAdult.Text         = ""
	toastAdult.TextSize     = 11
	toastAdult.Font         = Enum.Font.Gotham
	toastAdult.TextColor3   = Color3.fromRGB(180, 160, 120)
	toastAdult.TextWrapped  = true
	toastAdult.ZIndex       = 31
	toastAdult.Parent       = toast

	return toast
end

-- ── State ─────────────────────────────────────────────────────────────────────
local sg, pill, faceLabel, scoreLabel, detail = buildGui_166()
local toast = buildToast_166(sg)
local detailText = detail:FindFirstChild("DetailText") :: TextLabel
local toastShowing_166 = false
local detailOpen_166   = false

local lastPayload_166: { total: number, tier: string, tierChanged: boolean, pop: number, comb: number, queen: number, foraging: number }? = nil

-- ── Update pill ───────────────────────────────────────────────────────────────
local function updatePill_166(payload: typeof(lastPayload_166))
	if not payload then return end
	local meta = TIER_META_166[payload.tier] or TIER_META_166.stable

	faceLabel.Text  = meta.emoji
	scoreLabel.Text = tostring(payload.total)
	scoreLabel.TextColor3 = meta.color

	-- Pulse the stroke
	local stroke = pill:FindFirstChildOfClass("UIStroke") :: UIStroke
	if stroke then
		stroke.Color = meta.color
		TweenService:Create(stroke, TweenInfo.new(0.3), { Thickness = 3 }):Play()
		task.delay(0.4, function()
			TweenService:Create(stroke, TweenInfo.new(0.5), { Thickness = 1.5 }):Play()
		end)
	end
end

-- ── Update detail panel ───────────────────────────────────────────────────────
local function updateDetail_166(payload: typeof(lastPayload_166))
	if not payload then return end
	local meta = TIER_META_166[payload.tier] or TIER_META_166.stable

	detailText.Text = table.concat({
		string.format('<font color="rgb(232,212,154)"><b>Colony Health: %d/100</b></font>', payload.total),
		"",
		string.format('<font color="rgb(180,160,120)">🐝 Population  </font><b>%d</b>', payload.pop),
		string.format('<font color="rgb(180,160,120)">🍯 Comb fill    </font><b>%d</b>', payload.comb),
		string.format('<font color="rgb(180,160,120)">👑 Queen        </font><b>%d</b>', payload.queen),
		string.format('<font color="rgb(180,160,120)">🌸 Foraging     </font><b>%d</b>', payload.foraging),
		"",
		string.format('<font color="rgb(180,160,120)">%s</font>', meta.adult),
	}, "\n")
end

-- ── Show tier-change toast ────────────────────────────────────────────────────
local function showTierToast_166(payload: typeof(lastPayload_166))
	if not payload then return end
	if toastShowing_166 then return end
	toastShowing_166 = true

	local meta = TIER_META_166[payload.tier] or TIER_META_166.stable

	local bigEmoji_el  = toast:FindFirstChild("BigEmoji")  :: TextLabel
	local kidLine_el   = toast:FindFirstChild("KidLine")   :: TextLabel
	local adultLine_el = toast:FindFirstChild("AdultLine") :: TextLabel
	local stroke_el    = toast:FindFirstChildOfClass("UIStroke") :: UIStroke

	if bigEmoji_el  then bigEmoji_el.Text  = meta.emoji end
	if kidLine_el   then
		kidLine_el.Text       = meta.kid
		kidLine_el.TextColor3 = meta.color
	end
	if adultLine_el then adultLine_el.Text = meta.adult end
	if stroke_el    then stroke_el.Color   = meta.color end

	-- Slide in
	TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -140, 0, 12) }):Play()

	task.delay(5, function()
		TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -140, 0, -90) }):Play()
		task.delay(0.3, function()
			toastShowing_166 = false
		end)
	end)
end

-- ── Detail panel toggle ───────────────────────────────────────────────────────
local pillBtn = Instance.new("TextButton")
pillBtn.Name              = "PillTapTarget"
pillBtn.Size              = UDim2.new(1, 0, 1, 0)
pillBtn.BackgroundTransparency = 1
pillBtn.Text              = ""
pillBtn.ZIndex            = 7
pillBtn.Parent            = pill

pillBtn.MouseButton1Click:Connect(function()
	detailOpen_166 = not detailOpen_166
	if detailOpen_166 then
		detail.Visible = true
		detail.BackgroundTransparency = 1
		updateDetail_166(lastPayload_166)
		TweenService:Create(detail, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
	else
		TweenService:Create(detail, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
		task.delay(0.2, function()
			detail.Visible = false
		end)
	end
end)

-- Close detail panel on click outside (simple: close after 8s anyway)
task.spawn(function()
	while true do
		task.wait(8)
		if detailOpen_166 then
			detailOpen_166 = false
			TweenService:Create(detail, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
			task.delay(0.2, function()
				detail.Visible = false
			end)
		end
	end
end)

-- ── Main listener ─────────────────────────────────────────────────────────────
HealthSync_166.OnClientEvent:Connect(function(payload)
	lastPayload_166 = payload
	updatePill_166(payload)
	if payload.tierChanged then
		showTierToast_166(payload)
	end
	if detailOpen_166 then
		updateDetail_166(payload)
	end
end)
```

---

## Step 5 — Wire ColonyHealthController into ClientMain

Open **StarterPlayerScripts → ClientMain** and add inside the Init block:

```lua
local ColonyHealthController = require(script.Parent:WaitForChild("ColonyHealthController"))
ColonyHealthController:Init()  -- if Init() pattern used, otherwise just require() activates it
```

If ClientMain uses a simple `require()` list rather than `:Init()` calls, just add:

```lua
require(script.Parent:WaitForChild("ColonyHealthController"))
```

The LocalScript auto-runs via its connection setup, so the require is sufficient.

---

## Step 6 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check RemoteEvent
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local re = R:FindFirstChild("ColonyHealthSync")
print("ColonyHealthSync:", re and re.ClassName or "MISSING")

-- Check server script
local s = game:GetService("ServerScriptService"):FindFirstChild("ColonyHealthService")
    or game:GetService("ServerScriptService").Systems:FindFirstChild("ColonyHealthService")
print("ColonyHealthService:", s and s.ClassName or "MISSING")
if s then
	local lines = select(2, s.Source:gsub("\n","")) + 1
	print("  lines:", lines, "| WEIGHTS:", s.Source:find("WEIGHTS_166") ~= nil)
end

-- Check client script
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("ColonyHealthController")
print("ColonyHealthController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines, "| TIER_META:", c.Source:find("TIER_META_166") ~= nil)
end

print("Part count unchanged (should still be 4198):")
local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("  Parts:", count)
```

**Expected output:**
```
ColonyHealthSync: RemoteEvent
ColonyHealthService: Script
  lines: 90+  |  WEIGHTS: true
ColonyHealthController: LocalScript
  lines: 200+  |  TIER_META: true
Part count unchanged (should still be 4198):
  Parts: 4198
```

---

## Behaviour summary

| Signal | Kids see | Adults see |
|--------|----------|------------|
| Pill (always visible, top-right) | 😄/😐/😟/😰 + score number | Same + strokecolour coded to tier |
| Tier-change toast (5s slide-in) | Emoji headline + single-sentence vibe | + Adult detail line |
| Tap/click pill | — | Expands detail panel: pop/comb/queen/foraging breakdown |
| Detail panel | — | 4 sub-scores + adult verdict, auto-closes 8s |

Health tiers:
- **😄 Thriving** (80–100): all systems healthy
- **😐 Stable** (55–79): minor issues to watch
- **😟 Struggling** (30–54): check population & comb
- **😰 Critical** (0–29): immediate action needed

**Part budget: +0 permanent → 4,198 / 5,000**
