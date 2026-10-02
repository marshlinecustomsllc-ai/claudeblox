# Dispatch 196 — Bee Population Census Panel
**File:** `cycle19_bee_census_dispatch.md`
**Cycle:** 19
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

`PopulationService` tracks bee counts by caste internally but no UI surface exposes the breakdown to players. This dispatch adds a **Bee Population Census Panel**: a server-side 60-second ticker that packages caste counts into a `CensusData` JSON attribute on each `PlotRoot` part, plus a client-side `BeeCensusController` that reads it and shows a compact 3-row panel — Foragers / Nurses / Guards — with emoji bee icons, kid-friendly labels, and adult numbers. The panel slides in from the right edge when census data arrives and folds away when idle. Zero DataService changes — census is a live operational metric, not a persisted profile field.

---

## Step 1 — CensusService (ServerScriptService → Systems)

Open **ServerScriptService → Systems** and create a new **ModuleScript** named `CensusService`.

Paste exactly:

```lua
--!strict
-- CensusService: 60s population snapshot per plot, written to PlotRoot.CensusData attribute.
-- Reads PopulationService's live bee tables. Zero DataStore writes.

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService        = game:GetService("HttpService")

-- ── Config ────────────────────────────────────────────────────────────────────
local CENSUS_INTERVAL_196 = 60     -- seconds between snapshots

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function getPlotRoot_196(plotIdx: number): BasePart?
	for _, obj in CollectionService:GetTagged("PlotRoot") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == plotIdx then
			return obj
		end
	end
	return nil
end

-- ── Count bees by caste from live Brood/Worker cell attributes ─────────────────
-- PopulationService stores live bee data as attributes on BroodCell and WaxCell parts:
--   BeeCount (total per cell), CasteBreakdown (JSON string e.g. {"Forager":3,"Nurse":2})
-- If those attributes aren't available, fall back to reading PlayerBeeData from PlotRoot.
local function countCastes_196(plotIdx: number): { [string]: number }
	local counts: { [string]: number } = {
		Forager = 0,
		Nurse   = 0,
		Guard   = 0,
		Drone   = 0,
		Other   = 0,
	}

	-- Method A: read CasteBreakdown attribute from individual cells
	local foundCellData = false
	for _, obj in CollectionService:GetTagged("CombCell") do
		if not obj:IsA("BasePart") then continue end
		if obj:GetAttribute("PlotIndex") ~= plotIdx then continue end
		local raw = obj:GetAttribute("CasteBreakdown") :: string?
		if raw then
			foundCellData = true
			local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and typeof(data) == "table" then
				for caste, n in data do
					if type(n) == "number" then
						counts[caste] = (counts[caste] or 0) + n
					end
				end
			end
		end
	end

	-- Method B: fall back to PlotRoot.PlayerBeeData attribute
	if not foundCellData then
		local root = getPlotRoot_196(plotIdx)
		if root then
			local raw = root:GetAttribute("PlayerBeeData") :: string?
			if raw then
				local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
				if ok and typeof(data) == "table" then
					for caste, n in data do
						if type(n) == "number" then
							counts[caste] = (counts[caste] or 0) + n
						end
					end
				end
			end
		end
	end

	return counts
end

-- ── Write census to PlotRoot ──────────────────────────────────────────────────
local function runCensus_196()
	for plotIdx = 1, 6 do
		local root = getPlotRoot_196(plotIdx)
		if not root then continue end

		local counts = countCastes_196(plotIdx)
		local total  = 0
		for _, n in counts do total += n end
		counts["Total"] = total

		local ok, json = pcall(HttpService.JSONEncode, HttpService, counts)
		if ok then
			root:SetAttribute("CensusData", json)
			root:SetAttribute("CensusTimestamp", os.clock())
		end
	end
end

-- ── Module API ────────────────────────────────────────────────────────────────
local CensusService = {}

function CensusService.Start()
	-- Initial census after 5s startup delay
	task.delay(5, runCensus_196)

	-- Periodic census
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc = acc + dt
		if acc >= CENSUS_INTERVAL_196 then
			acc = 0
			task.spawn(runCensus_196)
		end
	end)
end

return CensusService
```

---

## Step 2 — Wire CensusService into Main bootstrap

Open **ServerScriptService → Main** and add:

```lua
local CensusService = require(Systems.CensusService)
-- ... (after other service requires)
CensusService.Start()
```

---

## Step 3 — BeeCensusController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BeeCensusController`.

Paste exactly:

```lua
--!strict
-- BeeCensusController: compact 3-row caste breakdown panel for player's plot.
-- Reads CensusData JSON attribute from PlotRoot part (set by CensusService every 60s).

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local POLL_INTERVAL_196 = 5.0    -- seconds between attribute polls
local SLIDE_TIME_196    = 0.35   -- panel slide-in/out duration

-- ── Palette ───────────────────────────────────────────────────────────────────
local WAX_CREAM_196  = Color3.fromRGB(232, 212, 154)
local DARK_BG_196    = Color3.fromRGB( 30,  18,   8)
local HONEY_196      = Color3.fromRGB(242, 168,  28)
local FORAGE_196     = Color3.fromRGB(100, 190,  80)   -- Forager green
local NURSE_196      = Color3.fromRGB(200, 120, 220)   -- Nurse lavender
local GUARD_196      = Color3.fromRGB(220,  80,  50)   -- Guard red-orange

-- ── Caste display config ──────────────────────────────────────────────────────
type CasteRow = { key: string, icon: string, kidLabel: string, color: Color3 }
local CASTE_ROWS_196: { CasteRow } = {
	{ key = "Forager", icon = "🌸", kidLabel = "Collectors",  color = FORAGE_196 },
	{ key = "Nurse",   icon = "🥚", kidLabel = "Baby carers", color = NURSE_196  },
	{ key = "Guard",   icon = "⚔️", kidLabel = "Defenders",   color = GUARD_196  },
}

-- ── Build panel ───────────────────────────────────────────────────────────────
local censusGui_196: ScreenGui?
local panelFrame_196: Frame?
local rowLabels_196: { [string]: TextLabel } = {}
local rowBars_196: { [string]: Frame } = {}

local function buildPanel_196()
	local pg = player:WaitForChild("PlayerGui", 5) :: PlayerGui?
	if not pg then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "BeeCensusGui_196"
	sg.DisplayOrder   = 22
	sg.ResetOnSpawn   = false
	sg.Parent         = pg
	censusGui_196 = sg

	-- Panel sits right edge, 3 rows × 18px + header + padding = 100px tall, 110px wide
	local panel = Instance.new("Frame")
	panel.Name                   = "CensusPanel"
	panel.Size                   = UDim2.new(0, 110, 0, 104)
	panel.AnchorPoint            = Vector2.new(1, 0.5)
	-- Start off-screen right
	panel.Position               = UDim2.new(1, 120, 0.5, -30)
	panel.BackgroundColor3       = DARK_BG_196
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel        = 0
	panel.Parent                 = sg
	panelFrame_196 = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_196
	stroke.Thickness = 1
	stroke.Parent    = panel

	-- Header
	local header = Instance.new("TextLabel")
	header.Size               = UDim2.new(1, 0, 0, 18)
	header.Position           = UDim2.new(0, 0, 0, 4)
	header.BackgroundTransparency = 1
	header.Text               = "🐝 Your bees"
	header.TextSize           = 11
	header.Font               = Enum.Font.GothamBold
	header.TextColor3         = HONEY_196
	header.TextXAlignment     = Enum.TextXAlignment.Center
	header.ZIndex             = 2
	header.Parent             = panel

	-- 3 caste rows
	for i, row in CASTE_ROWS_196 do
		local yBase = 26 + (i - 1) * 24

		-- Bar background
		local barBg = Instance.new("Frame")
		barBg.Size                   = UDim2.new(1, -12, 0, 8)
		barBg.Position               = UDim2.new(0, 6, 0, yBase + 12)
		barBg.BackgroundColor3       = Color3.fromRGB(50, 30, 10)
		barBg.BackgroundTransparency = 0.3
		barBg.BorderSizePixel        = 0
		barBg.Parent                 = panel

		local barBgCorner = Instance.new("UICorner")
		barBgCorner.CornerRadius = UDim.new(1, 0)
		barBgCorner.Parent       = barBg

		-- Fill bar
		local fill = Instance.new("Frame")
		fill.Name                   = "Fill_" .. row.key
		fill.Size                   = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3       = row.color
		fill.BorderSizePixel        = 0
		fill.Parent                 = barBg
		rowBars_196[row.key] = fill

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent       = fill

		-- Label "🌸 Collectors  0"
		local lbl = Instance.new("TextLabel")
		lbl.Name               = "Lbl_" .. row.key
		lbl.Size               = UDim2.new(1, -10, 0, 12)
		lbl.Position           = UDim2.new(0, 5, 0, yBase)
		lbl.BackgroundTransparency = 1
		lbl.Text               = row.icon .. " " .. row.kidLabel .. "  0"
		lbl.TextSize           = 10
		lbl.Font               = Enum.Font.GothamBold
		lbl.TextColor3         = WAX_CREAM_196
		lbl.TextXAlignment     = Enum.TextXAlignment.Left
		lbl.ZIndex             = 2
		lbl.Parent             = panel
		rowLabels_196[row.key] = lbl
	end

	-- Total row at bottom
	local totalLbl = Instance.new("TextLabel")
	totalLbl.Name               = "TotalLabel"
	totalLbl.Size               = UDim2.new(1, -10, 0, 14)
	totalLbl.Position           = UDim2.new(0, 5, 0, 82)
	totalLbl.BackgroundTransparency = 1
	totalLbl.Text               = "Total: 0 bees"
	totalLbl.TextSize           = 10
	totalLbl.Font               = Enum.Font.Gotham
	totalLbl.TextColor3         = Color3.fromRGB(180, 160, 100)
	totalLbl.TextXAlignment     = Enum.TextXAlignment.Center
	totalLbl.ZIndex             = 2
	totalLbl.Parent             = panel
end

-- ── Slide panel in/out ────────────────────────────────────────────────────────
local panelVisible_196 = false

local function showPanel_196()
	if panelVisible_196 or not panelFrame_196 then return end
	panelVisible_196 = true
	TweenService:Create(panelFrame_196, TweenInfo.new(SLIDE_TIME_196, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -6, 0.5, -30),
	}):Play()
end

local function hidePanel_196()
	if not panelVisible_196 or not panelFrame_196 then return end
	panelVisible_196 = false
	TweenService:Create(panelFrame_196, TweenInfo.new(SLIDE_TIME_196, Enum.EasingStyle.Sine), {
		Position = UDim2.new(1, 120, 0.5, -30),
	}):Play()
end

-- ── Update panel with census data ─────────────────────────────────────────────
local lastCensusTime_196 = 0

local function updateFromCensus_196(json: string)
	local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or typeof(data) ~= "table" then return end

	local total: number = data["Total"] :: number? or 0
	local maxCount = 1

	-- Find max for bar scaling
	for _, row in CASTE_ROWS_196 do
		local n = (data[row.key] :: number?) or 0
		if n > maxCount then maxCount = n end
	end

	for _, row in CASTE_ROWS_196 do
		local n = (data[row.key] :: number?) or 0
		local pct = n / maxCount

		local lbl = rowLabels_196[row.key]
		local bar = rowBars_196[row.key]

		if lbl then
			lbl.Text = row.icon .. " " .. row.kidLabel .. "  " .. n
		end
		if bar then
			TweenService:Create(bar, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
				Size = UDim2.new(pct, 0, 1, 0),
			}):Play()
		end
	end

	-- Update total label
	local panelFrame = panelFrame_196
	if panelFrame then
		local tl = panelFrame:FindFirstChild("TotalLabel") :: TextLabel?
		if tl then
			tl.Text = "Total: " .. total .. " bee" .. (total == 1 and "" or "s")
		end
	end
end

-- ── Find player's PlotRoot ────────────────────────────────────────────────────
local function getMyPlotRoot_196(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, obj in CollectionService:GetTagged("PlotRoot") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			return obj
		end
	end
	return nil
end

-- ── Poll loop ─────────────────────────────────────────────────────────────────
task.delay(3, function()
	buildPanel_196()

	local lastScan = os.clock()
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastScan < POLL_INTERVAL_196 then return end
		lastScan = os.clock()

		local root = getMyPlotRoot_196()
		if not root then hidePanel_196(); return end

		local json = root:GetAttribute("CensusData") :: string?
		if not json then hidePanel_196(); return end

		local ts = root:GetAttribute("CensusTimestamp") :: number?
		if ts and ts ~= lastCensusTime_196 then
			lastCensusTime_196 = ts
			updateFromCensus_196(json)
			showPanel_196()
		end
	end)
end)
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BeeCensusController")
print("BeeCensusController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  updateFromCensus_196:", c.Source:find("updateFromCensus_196") ~= nil)
	print("  CASTE_ROWS_196:", c.Source:find("CASTE_ROWS_196") ~= nil)
	print("  showPanel_196:", c.Source:find("showPanel_196") ~= nil)
end

local Systems = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local cs = Systems and Systems:FindFirstChild("CensusService")
print("CensusService:", cs and cs.ClassName or "MISSING")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
BeeCensusController: LocalScript
  lines: 220+
  updateFromCensus_196: true
  CASTE_ROWS_196: true
  showPanel_196: true
CensusService: ModuleScript
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Panel state | Trigger | What shows |
|---|---|---|
| Slides in from right | `CensusTimestamp` attribute changes | 3 caste rows with bar + count + emoji |
| Hidden | No census data yet | Panel off-screen right |
| Each row | `🌸 Collectors N` / `🥚 Baby carers N` / `⚔️ Defenders N` | Fill bar scales relative to highest caste |
| Footer | "Total: N bees" | Sum of all castes |

- Server writes census every 60s to `PlotRoot.CensusData` (JSON) + `CensusTimestamp`
- Client polls every 5s — only refreshes when `CensusTimestamp` changes
- If `CombCell` parts don't have `CasteBreakdown` attributes yet, falls back to `PlotRoot.PlayerBeeData`
- Zero DataStore writes — census is a live operational metric

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BeeCensusGui ScreenGui is a GuiObject — not a BasePart; CensusService writes only attributes)*
