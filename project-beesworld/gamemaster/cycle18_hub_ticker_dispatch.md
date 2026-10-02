# Dispatch 188 — Hub Honey Ticker
**File:** `cycle18_hub_ticker_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The Apiary Yard hub has a `WeatherNoticeBoard` world object but it currently shows nothing. Players from different plots pass through the hub on their way to the Wild Meadow, but they have no sense of how other plots are doing — who's ahead on honey, who's under Molasses threat, who just hit a milestone. This dispatch adds a **Hub Honey Ticker**: a scrolling BillboardGui on the WeatherNoticeBoard that cycles through 6 snapshot lines (one per plot) every 4 seconds. Each line shows the plot owner's display name (or "Empty" if unoccupied), their honey total with emoji tier icon, and an at-a-glance status badge.

The ticker reads public plot stats from the `PlotStatsUpdate` RemoteEvent (already fired by PlotService) and falls back to reading `HoneyCount`/`BeeCount` attributes on `PlotRoot`-tagged parts. Entirely client-side — no server writes. The BillboardGui is parented to the WeatherNoticeBoard BasePart, so it lives in the world at exactly the right position without any layout work.

Zero new permanent parts.

---

## Step 1 — HubTickerController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HubTickerController`.

Paste exactly:

```lua
--!strict
-- HubTickerController: scrolling honey snapshot ticker on the WeatherNoticeBoard.
-- Reads PlotStatsUpdate RemoteEvent for live per-plot data; falls back to PlotRoot attributes.
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local TICK_INTERVAL_188   = 4.0    -- seconds per ticker line
local FADE_TIME_188       = 0.3    -- seconds to fade between lines
local BOARD_STUDS_188     = 5.5    -- BillboardGui size in studs

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_188  = Color3.fromRGB(242, 168,  28)
local WAX_CREAM_188   = Color3.fromRGB(232, 212, 154)
local DARK_BG_188     = Color3.fromRGB( 30,  18,   8)
local ORANGE_188      = Color3.fromRGB(230, 110,  20)
local GREEN_188       = Color3.fromRGB( 80, 200,  80)
local GREY_188        = Color3.fromRGB(120, 100,  80)
local MY_PLOT_188     = Color3.fromRGB(255, 220,  80)   -- highlight player's own plot

-- ── Honey tier emoji ──────────────────────────────────────────────────────────
local function honeyIcon_188(honey: number): string
	if honey >= 50000 then return "👑" end
	if honey >= 20000 then return "🔥" end
	if honey >= 10000 then return "✨" end
	if honey >= 5000  then return "🍯" end
	if honey >= 1000  then return "🐝" end
	return "🌱"
end

local function formatHoney_188(honey: number): string
	if honey >= 1000000 then return string.format("%.1fM", honey / 1000000) end
	if honey >= 1000    then return string.format("%.1fk", honey / 1000) end
	return tostring(math.floor(honey))
end

-- ── Status badge ──────────────────────────────────────────────────────────────
local function statusBadge_188(data: { [string]: any }): (string, Color3)
	local threat = data.threatStage :: number?
	if threat and threat >= 6 then return "⚠️ MOLASSES!", ORANGE_188 end
	if threat and threat >= 4 then return "🐻 Stirring", ORANGE_188 end
	local ripeness = data.maxRipeness :: number?
	if ripeness and ripeness >= 2.0 then return "🔥 MAX RIPE", ORANGE_188 end
	if ripeness and ripeness >= 1.8 then return "⚠️ Very ripe", ORANGE_188 end
	local bees = data.beeCount :: number?
	if bees and bees >= 50 then return "🐝 Buzzing!", GREEN_188 end
	return "", GREY_188
end

-- ── Plot snapshot store ────────────────────────────────────────────────────────
-- keyed by plotIndex (1-6)
local plotData_188: { [number]: {
	name:       string,
	honey:      number,
	beeCount:   number,
	maxRipeness:number,
	threatStage:number,
	isMine:     boolean,
} } = {}

local function initPlotData_188()
	for i = 1, 6 do
		plotData_188[i] = {
			name        = "Empty",
			honey       = 0,
			beeCount    = 0,
			maxRipeness = 1.0,
			threatStage = 0,
			isMine      = false,
		}
	end
end
initPlotData_188()

-- ── Scan PlotRoot attributes as fallback ──────────────────────────────────────
local function refreshFromAttributes_188()
	local myPlotIdx = player:GetAttribute("PlotIndex") :: number?
	for _, root in CollectionService:GetTagged("PlotRoot") do
		if not root:IsA("BasePart") then continue end
		local idx = root:GetAttribute("PlotIndex") :: number?
		if not idx then continue end
		local ownerName = root:GetAttribute("OwnerName") :: string?
		local honey     = root:GetAttribute("HoneyCount")  :: number?
		local bees      = root:GetAttribute("BeeCount")    :: number?
		local ripeness  = root:GetAttribute("MaxRipeness") :: number?
		local threat    = root:GetAttribute("ThreatStage") :: number?
		plotData_188[idx] = {
			name        = ownerName or "Empty",
			honey       = honey or 0,
			beeCount    = bees or 0,
			maxRipeness = ripeness or 1.0,
			threatStage = threat or 0,
			isMine      = (idx == myPlotIdx),
		}
	end
end

-- ── Listen to PlotStatsUpdate RemoteEvent ─────────────────────────────────────
-- Payload: plotIndex, ownerName, honey, beeCount, maxRipeness, threatStage
local function connectStats_188(): boolean
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local re = remotes and remotes:FindFirstChild("PlotStatsUpdate") :: RemoteEvent?
	if re then
		re.OnClientEvent:Connect(function(
			idx: number?,
			ownerName: string?,
			honey: number?,
			beeCount: number?,
			maxRipeness: number?,
			threatStage: number?
		)
			if not idx or idx < 1 or idx > 6 then return end
			local myPlotIdx = player:GetAttribute("PlotIndex") :: number?
			plotData_188[idx] = {
				name        = ownerName or "Empty",
				honey       = honey or 0,
				beeCount    = beeCount or 0,
				maxRipeness = maxRipeness or 1.0,
				threatStage = threatStage or 0,
				isMine      = (idx == myPlotIdx),
			}
		end)
		return true
	end
	return false
end

-- ── Find WeatherNoticeBoard part ──────────────────────────────────────────────
local function findBoard_188(): BasePart?
	for _, obj in CollectionService:GetTagged("WeatherNoticeBoard") do
		if obj:IsA("BasePart") then return obj end
	end
	for _, obj in workspace:GetDescendants() do
		if obj.Name == "WeatherNoticeBoard" and obj:IsA("BasePart") then return obj end
	end
	return nil
end

-- ── Build BillboardGui on the board ──────────────────────────────────────────
local titleLabel_188: TextLabel? = nil
local lineLabel_188: TextLabel?  = nil
local subLabel_188: TextLabel?   = nil

local function buildBillboard_188(board: BasePart): BillboardGui
	-- Remove existing one if any
	local existing = board:FindFirstChild("HubTicker_188")
	if existing then existing:Destroy() end

	local bg = Instance.new("BillboardGui")
	bg.Name           = "HubTicker_188"
	bg.Size           = UDim2.new(0, 220, 0, 70)
	bg.StudsOffsetWorldSpace = Vector3.new(0, BOARD_STUDS_188, 0)
	bg.AlwaysOnTop    = false
	bg.ResetOnSpawn   = false
	bg.Adornee        = board
	bg.Parent         = board

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_188
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_GOLD_188
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local title = Instance.new("TextLabel")
	title.Name               = "TickerTitle"
	title.Size               = UDim2.new(1, -8, 0, 14)
	title.Position           = UDim2.new(0, 4, 0, 4)
	title.BackgroundTransparency = 1
	title.Text               = "🐝  Apiary Updates"
	title.TextSize           = 11
	title.Font               = Enum.Font.GothamBold
	title.TextColor3         = HONEY_GOLD_188
	title.TextXAlignment     = Enum.TextXAlignment.Center
	title.ZIndex             = 2
	title.Parent             = frame
	titleLabel_188 = title

	local line = Instance.new("TextLabel")
	line.Name               = "TickerLine"
	line.Size               = UDim2.new(1, -8, 0, 22)
	line.Position           = UDim2.new(0, 4, 0, 20)
	line.BackgroundTransparency = 1
	line.Text               = "—"
	line.TextSize           = 14
	line.Font               = Enum.Font.GothamBold
	line.TextColor3         = WAX_CREAM_188
	line.TextTransparency   = 1
	line.TextXAlignment     = Enum.TextXAlignment.Center
	line.TextWrapped        = true
	line.ZIndex             = 2
	line.Parent             = frame
	lineLabel_188 = line

	local sub = Instance.new("TextLabel")
	sub.Name               = "TickerSub"
	sub.Size               = UDim2.new(1, -8, 0, 16)
	sub.Position           = UDim2.new(0, 4, 0, 46)
	sub.BackgroundTransparency = 1
	sub.Text               = ""
	sub.TextSize           = 10
	sub.Font               = Enum.Font.Gotham
	sub.TextColor3         = GREY_188
	sub.TextTransparency   = 1
	sub.TextXAlignment     = Enum.TextXAlignment.Center
	sub.ZIndex             = 2
	sub.Parent             = frame
	subLabel_188 = sub

	return bg
end

-- ── Tick cycle ────────────────────────────────────────────────────────────────
local currentPlot_188 = 1

local function showPlotTick_188(idx: number)
	local line = lineLabel_188
	local sub  = subLabel_188
	if not line or not sub then return end

	local data = plotData_188[idx]
	if not data then return end

	local icon   = honeyIcon_188(data.honey)
	local amount = formatHoney_188(data.honey)
	local badge, badgeColor = statusBadge_188(data :: any)

	local nameColor = if data.isMine then MY_PLOT_188 else WAX_CREAM_188
	local mainText  = string.format("Plot %d: %s  %s %s",
		idx, data.name, icon, amount)
	local subText   = badge ~= "" and badge or
		string.format("🐝 %d bees", data.beeCount)

	-- Fade out
	TweenService:Create(line, TweenInfo.new(FADE_TIME_188, Enum.EasingStyle.Sine),
		{ TextTransparency = 1 }):Play()
	TweenService:Create(sub, TweenInfo.new(FADE_TIME_188, Enum.EasingStyle.Sine),
		{ TextTransparency = 1 }):Play()

	task.delay(FADE_TIME_188 + 0.05, function()
		line.Text       = mainText
		line.TextColor3 = nameColor
		sub.Text        = subText
		sub.TextColor3  = badgeColor

		TweenService:Create(line, TweenInfo.new(FADE_TIME_188, Enum.EasingStyle.Sine),
			{ TextTransparency = 0 }):Play()
		TweenService:Create(sub, TweenInfo.new(FADE_TIME_188, Enum.EasingStyle.Sine),
			{ TextTransparency = 0 }):Play()
	end)
end

-- ── Main ticker loop ──────────────────────────────────────────────────────────
local function startTicker_188(board: BasePart)
	buildBillboard_188(board)
	refreshFromAttributes_188()
	showPlotTick_188(currentPlot_188)

	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL_188)
			refreshFromAttributes_188()
			currentPlot_188 = (currentPlot_188 % 6) + 1
			showPlotTick_188(currentPlot_188)
		end
	end)
end

-- ── Init ──────────────────────────────────────────────────────────────────────
task.delay(2, function()
	if not connectStats_188() then
		task.spawn(function()
			while true do
				task.wait(10)
				if connectStats_188() then break end
			end
		end)
	end

	local board = findBoard_188()
	if board then
		startTicker_188(board)
	else
		-- Retry loop for late-loading world
		task.spawn(function()
			while true do
				task.wait(5)
				local b = findBoard_188()
				if b then startTicker_188(b); break end
			end
		end)
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HubTickerController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HubTickerController")
print("HubTickerController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  showPlotTick_188:", c.Source:find("showPlotTick_188") ~= nil)
	print("  honeyIcon_188:", c.Source:find("honeyIcon_188") ~= nil)
	print("  PlotStatsUpdate listener:", c.Source:find("PlotStatsUpdate") ~= nil)
	print("  findBoard_188:", c.Source:find("findBoard_188") ~= nil)
end

-- Check WeatherNoticeBoard exists
local CS = game:GetService("CollectionService")
local boards = CS:GetTagged("WeatherNoticeBoard")
print("WeatherNoticeBoard tagged:", #boards,
	"(if 0, add WeatherNoticeBoard tag to the hub notice board part)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HubTickerController: LocalScript
  lines: 240+
  showPlotTick_188: true
  honeyIcon_188: true
  PlotStatsUpdate listener: true
  findBoard_188: true
WeatherNoticeBoard tagged: 1  (if 0, tag the hub notice board part)
Total parts: 4204  (expect 4204)
```

---

## Step 4 — Tag the WeatherNoticeBoard (if not already tagged)

If the notice board world object doesn't have the `WeatherNoticeBoard` CollectionService tag, run in **Studio Command Bar**:

```lua
for _, obj in game:GetService("Workspace"):GetDescendants() do
	if obj.Name == "WeatherNoticeBoard" and obj:IsA("BasePart") then
		game:GetService("CollectionService"):AddTag(obj, "WeatherNoticeBoard")
		print("Tagged:", obj:GetFullName())
	end
end
```

---

## Behaviour summary

| State | Ticker line |
|-------|-------------|
| Plot occupied, safe | "Plot 2: BeeKeeper99  🍯 3.4k" + "🐝 42 bees" |
| Plot occupied, high ripeness | "Plot 4: QueenBee  🔥 55.2k" + "⚠️ Very ripe" |
| ThreatStage ≥ 4 | "Plot 1: HexMaster  ✨ 12.1k" + "🐻 Stirring" |
| ThreatStage = 6 | "Plot 3: Buzzlina  👑 88k" + "⚠️ MOLASSES!" |
| Player's own plot | Line text rendered in bright MY_PLOT gold |
| Plot empty / unoccupied | "Plot 5: Empty  🌱 0" |
| Tick interval | 4 seconds per plot, crossfade 0.3s |
| WeatherNoticeBoard not found | Ticker disabled silently; retries every 5s |

**Part budget: +0 permanent → 4,204 / 5,000**
*(BillboardGui is a GuiObject child of the existing WeatherNoticeBoard BasePart — not a new part)*
