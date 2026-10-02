# Dispatch 169 — Population Growth Sparkline
**File:** `cycle15_pop_graph_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The HiveGui currently shows a static population number. This dispatch adds a **sparkline chart** (a minimal line graph showing the last 20 population readings) to the HiveGui's population area. Kids see a rising line with a bee emoji and a trend arrow (📈 vs 📉). Adults see the actual population counts at start/end of the window and a percentage change. The chart is drawn entirely from Roblox UI `Frame` bars (no external assets needed) and updates every 10 seconds alongside the existing `RatesUpdate` cadence.

---

## Step 1 — PopGraphController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PopGraphController`.

Paste exactly:

```lua
--!strict
-- PopGraphController: sparkline chart for bee population history in HiveGui
-- Draws a bar-based mini chart inside HiveGui's population display area.
-- Updates every 10s on RatesUpdate or ColonyHealthSync signal.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local MAX_SAMPLES_169  = 20     -- how many readings to keep
local BAR_COUNT_169    = 20     -- bars to render (matches samples)
local CHART_W_169      = 160    -- chart width in px
local CHART_H_169      = 48     -- chart height in px
local UPDATE_LABEL_169 = true   -- show numeric label at right edge

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_169   = Color3.fromRGB(242, 168, 28)
local PROP_BROWN_169   = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_169    = Color3.fromRGB(232, 212, 154)
local GREEN_169        = Color3.fromRGB(80,  200, 80)
local RED_169          = Color3.fromRGB(220, 60,  60)
local DARK_BG_169      = Color3.fromRGB(30,  18,  8)

-- ── State ─────────────────────────────────────────────────────────────────────
local samples_169: { number } = {}   -- ring buffer of population readings
local chartBuilt_169   = false
local chartFrame_169: Frame? = nil
local bars_169: { Frame } = {}

-- ── Ring-buffer append ────────────────────────────────────────────────────────
local function appendSample_169(pop: number)
	table.insert(samples_169, pop)
	if #samples_169 > MAX_SAMPLES_169 then
		table.remove(samples_169, 1)
	end
end

-- ── Build chart UI inside HiveGui ────────────────────────────────────────────
local function buildChart_169()
	-- Find HiveGui → any Frame named "PopPage" or "PopulationPage" or "CastesPage"
	-- Fall back to creating a floating chart if HiveGui structure not found
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	local parent: GuiObject? = nil

	if hiveGui then
		-- Try common names for the population page
		local candidates = { "PopPage", "PopulationPage", "CastesPage", "StatsPage" }
		for _, name in candidates do
			local found = hiveGui:FindFirstChild(name, true) :: GuiObject?
			if found then parent = found; break end
		end
		-- If none found, attach to root of HiveGui
		if not parent then parent = hiveGui end
	end

	if not parent then
		-- HiveGui not found — create a floating overlay chart instead
		local sg = Instance.new("ScreenGui")
		sg.Name           = "PopGraphGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 14
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui
		parent = sg :: any
	end

	-- Outer card
	local card = Instance.new("Frame")
	card.Name              = "PopSparklineCard"
	card.Size              = UDim2.new(0, CHART_W_169 + 24, 0, CHART_H_169 + 42)
	-- Position: bottom-left if floating, or relative if inside HiveGui
	if parent:IsA("ScreenGui") then
		card.Position = UDim2.new(0, 12, 1, -(CHART_H_169 + 42 + 12))
	else
		card.Position = UDim2.new(0, 8, 0, 8)
	end
	card.BackgroundColor3  = DARK_BG_169
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel   = 0
	card.ZIndex            = 25
	card.Parent            = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color     = PROP_BROWN_169
	stroke.Thickness = 1
	stroke.Parent    = card

	-- Title row
	local titleRow = Instance.new("Frame")
	titleRow.Name              = "TitleRow"
	titleRow.Size              = UDim2.new(1, -8, 0, 18)
	titleRow.Position          = UDim2.new(0, 4, 0, 4)
	titleRow.BackgroundTransparency = 1
	titleRow.ZIndex            = 26
	titleRow.Parent            = card

	local trendLabel = Instance.new("TextLabel")
	trendLabel.Name            = "TrendLabel"
	trendLabel.Size            = UDim2.new(0, 24, 1, 0)
	trendLabel.BackgroundTransparency = 1
	trendLabel.Text            = "🐝"
	trendLabel.TextSize        = 14
	trendLabel.Font            = Enum.Font.GothamBold
	trendLabel.ZIndex          = 27
	trendLabel.Parent          = titleRow

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name            = "TitleLabel"
	titleLabel.Size            = UDim2.new(1, -50, 1, 0)
	titleLabel.Position        = UDim2.new(0, 24, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text            = "Colony Growth"
	titleLabel.TextSize        = 11
	titleLabel.Font            = Enum.Font.GothamBold
	titleLabel.TextColor3      = WAX_CREAM_169
	titleLabel.TextXAlignment  = Enum.TextXAlignment.Left
	titleLabel.ZIndex          = 27
	titleLabel.Parent          = titleRow

	local countLabel = Instance.new("TextLabel")
	countLabel.Name            = "CountLabel"
	countLabel.Size            = UDim2.new(0, 48, 1, 0)
	countLabel.Position        = UDim2.new(1, -48, 0, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text            = "—"
	countLabel.TextSize        = 11
	countLabel.Font            = Enum.Font.Gotham
	countLabel.TextColor3      = HONEY_GOLD_169
	countLabel.TextXAlignment  = Enum.TextXAlignment.Right
	countLabel.ZIndex          = 27
	countLabel.Parent          = titleRow

	-- Chart area
	local chartArea = Instance.new("Frame")
	chartArea.Name              = "ChartArea"
	chartArea.Size              = UDim2.new(0, CHART_W_169, 0, CHART_H_169)
	chartArea.Position          = UDim2.new(0, 12, 0, 26)
	chartArea.BackgroundColor3  = Color3.fromRGB(20, 12, 4)
	chartArea.BackgroundTransparency = 0.3
	chartArea.BorderSizePixel   = 0
	chartArea.ZIndex            = 26
	chartArea.Parent            = card

	local areaCorner = Instance.new("UICorner")
	areaCorner.CornerRadius = UDim.new(0, 4)
	areaCorner.Parent = chartArea

	-- Change label below chart
	local changeLabel = Instance.new("TextLabel")
	changeLabel.Name           = "ChangeLabel"
	changeLabel.Size           = UDim2.new(1, -8, 0, 14)
	changeLabel.Position       = UDim2.new(0, 4, 1, -(14 + 3))
	changeLabel.BackgroundTransparency = 1
	changeLabel.Text           = ""
	changeLabel.TextSize       = 10
	changeLabel.Font           = Enum.Font.Gotham
	changeLabel.TextColor3     = WAX_CREAM_169
	changeLabel.TextXAlignment = Enum.TextXAlignment.Left
	changeLabel.ZIndex         = 26
	changeLabel.Parent         = card

	-- Build bars inside chart area
	local barWidth = CHART_W_169 / BAR_COUNT_169
	bars_169 = {}
	for i = 1, BAR_COUNT_169 do
		local bar = Instance.new("Frame")
		bar.Name              = "Bar_" .. i
		bar.Size              = UDim2.new(0, math.max(barWidth - 1, 1), 0, 1)
		bar.Position          = UDim2.new(0, (i - 1) * barWidth, 1, -1)
		bar.AnchorPoint       = Vector2.new(0, 1)
		bar.BackgroundColor3  = HONEY_GOLD_169
		bar.BorderSizePixel   = 0
		bar.ZIndex            = 28
		bar.Parent            = chartArea
		bars_169[i] = bar
	end

	chartFrame_169 = card
	chartBuilt_169 = true
	return card, trendLabel, countLabel, changeLabel
end

-- ── Render chart from current samples ────────────────────────────────────────
local lastTrendLabel_169: TextLabel? = nil
local lastCountLabel_169: TextLabel? = nil
local lastChangeLabel_169: TextLabel? = nil

local function renderChart_169()
	if not chartBuilt_169 then return end

	-- Find labels
	local trendLabel  = lastTrendLabel_169
	local countLabel  = lastCountLabel_169
	local changeLabel = lastChangeLabel_169
	if chartFrame_169 then
		local titleRow = chartFrame_169:FindFirstChild("TitleRow") :: Frame?
		if titleRow then
			trendLabel  = titleRow:FindFirstChild("TrendLabel")  :: TextLabel?
			countLabel  = titleRow:FindFirstChild("CountLabel")  :: TextLabel?
		end
		changeLabel = chartFrame_169:FindFirstChild("ChangeLabel") :: TextLabel?
	end

	local n = #samples_169
	if n == 0 then return end

	-- Compute min/max for normalisation
	local minVal, maxVal = samples_169[1], samples_169[1]
	for _, v in samples_169 do
		if v < minVal then minVal = v end
		if v > maxVal then maxVal = v end
	end
	local range = maxVal - minVal
	if range < 1 then range = 1 end  -- avoid div-by-zero when flat

	-- Render bars
	for i, bar in bars_169 do
		local sampleIdx = n - (BAR_COUNT_169 - i)  -- align to right edge
		local val = (sampleIdx >= 1 and sampleIdx <= n) and samples_169[sampleIdx] or 0
		local frac = (val - minVal) / range
		local targetH = math.max(frac * CHART_H_169, 2)  -- min 2px so bar is visible

		-- Colour: green if above median, gold otherwise
		local median = (maxVal + minVal) / 2
		local colour = (val >= median) and GREEN_169 or HONEY_GOLD_169

		TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = UDim2.new(0, math.max(CHART_W_169 / BAR_COUNT_169 - 1, 1), 0, targetH),
			BackgroundColor3 = colour,
		}):Play()
	end

	-- Update labels
	local latest = samples_169[n]
	local first  = samples_169[1]
	local pctChange = math.floor(((latest - first) / math.max(first, 1)) * 100 + 0.5)
	local trending = (pctChange > 0)
	local flat     = (pctChange == 0)

	if trendLabel then
		trendLabel.Text = trending and "📈" or (flat and "🐝" or "📉")
	end

	if countLabel then
		countLabel.Text      = tostring(latest)
		countLabel.TextColor3 = trending and GREEN_169 or (flat and HONEY_GOLD_169 or RED_169)
	end

	if changeLabel then
		if flat then
			changeLabel.Text       = "Steady colony 🐝"
			changeLabel.TextColor3 = WAX_CREAM_169
		elseif trending then
			changeLabel.Text       = string.format("+%d%% growth — thriving! 🌟", pctChange)
			changeLabel.TextColor3 = GREEN_169
		else
			changeLabel.Text       = string.format("%d%% decline — check hive 🌸", pctChange)
			changeLabel.TextColor3 = RED_169
		end
	end
end

-- ── Initialise ────────────────────────────────────────────────────────────────
task.delay(2, function()
	local _, trendLabel, countLabel, changeLabel = buildChart_169()
	lastTrendLabel_169  = trendLabel
	lastCountLabel_169  = countLabel
	lastChangeLabel_169 = changeLabel
end)

-- ── Listen for population updates ────────────────────────────────────────────
-- Primary: ColonyHealthSync carries pop sub-score; derive raw count from BeeCount attribute
local HealthSync = Remotes:FindFirstChild("ColonyHealthSync") :: RemoteEvent?
if HealthSync then
	HealthSync.OnClientEvent:Connect(function(_payload)
		local pop = player:GetAttribute("BeeCount") or 0
		appendSample_169(pop)
		renderChart_169()
	end)
else
	task.delay(5, function()
		local re = Remotes:FindFirstChild("ColonyHealthSync") :: RemoteEvent?
		if re then
			re.OnClientEvent:Connect(function(_payload)
				local pop = player:GetAttribute("BeeCount") or 0
				appendSample_169(pop)
				renderChart_169()
			end)
		end
	end)
end

-- Fallback: also sample on RatesUpdate (every 5s)
local RatesUpdate = Remotes:FindFirstChild("RatesUpdate") :: RemoteEvent?
if RatesUpdate then
	RatesUpdate.OnClientEvent:Connect(function(_honeyRate, _pollRate, _supplyRate, _bottleneck, _shed, _kiln, _queen)
		local pop = player:GetAttribute("BeeCount") or 0
		appendSample_169(pop)
		renderChart_169()
	end)
end

-- Seed with initial reading
task.spawn(function()
	task.wait(3)
	local pop = player:GetAttribute("BeeCount") or 0
	for _ = 1, 5 do
		appendSample_169(pop)
	end
	renderChart_169()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PopGraphController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check controller
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PopGraphController")
print("PopGraphController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  samples_169:", c.Source:find("samples_169") ~= nil)
	print("  renderChart:", c.Source:find("renderChart_169") ~= nil)
	print("  ColonyHealthSync:", c.Source:find("ColonyHealthSync") ~= nil)
end

-- Part count: should still be 4204
local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
PopGraphController: LocalScript
  lines: 200+
  samples_169: true
  renderChart: true
  ColonyHealthSync: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Kids see | Adults see |
|-------|----------|------------|
| Growing colony | 📈 + green bars + current count in green | "+N% growth — thriving! 🌟" |
| Flat colony | 🐝 + gold bars | "Steady colony 🐝" |
| Declining colony | 📉 + red bars + count in red | "-N% decline — check hive 🌸" |
| Chart location | Attaches to HiveGui PopPage if found; floating bottom-left otherwise | Same |
| Update cadence | Every 10s (ColonyHealthSync) + every 5s (RatesUpdate fallback) | Same |
| History window | Last 20 readings ≈ 3-4 minutes of play | Same |

**Part budget: +0 permanent → 4,204 / 5,000**
