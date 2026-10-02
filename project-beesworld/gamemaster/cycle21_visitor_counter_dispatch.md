# Dispatch 215 — Plot Visitor Counter
**File:** `cycle21_visitor_counter_dispatch.md`
**Cycle:** 21
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

All 6 plots in the Apiary Yard are visible from one another. Currently there is no social signal telling players which plots have been visited or how popular a neighbour's hive is. This dispatch adds a **Plot Visitor Counter**: a BillboardGui above each `PlotSign`-tagged BasePart that shows how many unique players have visited that plot this session. The count increments on the server when a player enters a plot's proximity zone and is replicated to all clients via a `VisitorCount` attribute on the PlotSign part. Entirely reactive — no polling on clients.

For kids: "👥 3 visitors!" is a simple social signal ("other people like this hive!"). For adults: it adds subtle competitive motivation to build an impressive, frequently-visited plot.

---

## Step 1 — PlotVisitorService (ServerScriptService)

Open **ServerScriptService → Systems** and create a new **Script** named `PlotVisitorService`.

Paste exactly:

```lua
--!strict
-- PlotVisitorService: tracks unique player visits to each plot this session.
-- Writes VisitorCount attribute to PlotSign-tagged parts (replicated to all clients).

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local PROXIMITY_STUDS_215 = 28    -- radius to count as "visiting" a plot
local CHECK_INTERVAL_215  = 4.0   -- seconds between proximity checks

-- ── State ─────────────────────────────────────────────────────────────────────
-- plotVisitors[plotIndex] = { [userId]: true }
local plotVisitors_215: { [number]: { [number]: boolean } } = {}

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function getPlotSigns_215(): { BasePart }
	local signs: { BasePart } = {}
	for _, obj in CollectionService:GetTagged("PlotSign") do
		if obj:IsA("BasePart") then
			table.insert(signs, obj)
		end
	end
	return signs
end

local function getVisitorCount_215(plotIndex: number): number
	local set = plotVisitors_215[plotIndex]
	if not set then return 0 end
	local count = 0
	for _ in set do count += 1 end
	return count
end

local function recordVisit_215(plotIndex: number, userId: number)
	if not plotVisitors_215[plotIndex] then
		plotVisitors_215[plotIndex] = {}
	end
	plotVisitors_215[plotIndex][userId] = true
end

local function broadcastCount_215(sign: BasePart, plotIndex: number)
	sign:SetAttribute("VisitorCount", getVisitorCount_215(plotIndex))
end

-- ── Proximity check ───────────────────────────────────────────────────────────
local acc_215 = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc_215 += dt
	if acc_215 < CHECK_INTERVAL_215 then return end
	acc_215 = 0

	local signs = getPlotSigns_215()
	for _, sign in signs do
		local plotIndex = sign:GetAttribute("PlotIndex") :: number?
		if not plotIndex then continue end

		local signPos = sign.Position
		local changed = false

		for _, player in Players:GetPlayers() do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then continue end
			local dist = (hrp.Position - signPos).Magnitude
			if dist <= PROXIMITY_STUDS_215 then
				local before = (plotVisitors_215[plotIndex] and plotVisitors_215[plotIndex][player.UserId]) == true
				recordVisit_215(plotIndex, player.UserId)
				if not before then changed = true end
			end
		end

		if changed then
			broadcastCount_215(sign, plotIndex)
		end
	end
end)

-- ── Init: write 0 for all existing signs ─────────────────────────────────────
task.delay(5, function()
	for _, sign in getPlotSigns_215() do
		local plotIndex = sign:GetAttribute("PlotIndex") :: number?
		if plotIndex then
			if not plotVisitors_215[plotIndex] then
				plotVisitors_215[plotIndex] = {}
			end
			broadcastCount_215(sign, plotIndex)
		end
	end
end)

-- Catch signs added after init
CollectionService:GetInstanceAddedSignal("PlotSign"):Connect(function(obj)
	if not obj:IsA("BasePart") then return end
	task.wait(0.5)
	local plotIndex = obj:GetAttribute("PlotIndex") :: number?
	if plotIndex then
		if not plotVisitors_215[plotIndex] then
			plotVisitors_215[plotIndex] = {}
		end
		obj:SetAttribute("VisitorCount", getVisitorCount_215(plotIndex))
	end
end)
```

---

## Step 2 — VisitorCountController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `VisitorCountController`.

Paste exactly:

```lua
--!strict
-- VisitorCountController: BillboardGui above each PlotSign showing visitor count.
-- Reads VisitorCount attribute from PlotSign-tagged BaseParts (written by PlotVisitorService).
-- Entirely client-side display — zero server writes.

local CollectionService = game:GetService("CollectionService")
local Players           = game:GetService("Players")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local LABEL_OFFSET_215 = Vector3.new(0, 5.5, 0)

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_215   = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_215 = Color3.fromRGB(232, 212, 154)
local HONEY_215     = Color3.fromRGB(242, 168,  28)
local MINE_GOLD_215 = Color3.fromRGB(255, 220,  80)   -- brighter for own plot

-- ── Build gui ─────────────────────────────────────────────────────────────────
local function buildGui_215(sign: BasePart): BillboardGui
	local bg = Instance.new("BillboardGui")
	bg.Name         = "VisitorGui_215"
	bg.Size         = UDim2.new(0, 100, 0, 26)
	bg.StudsOffset  = LABEL_OFFSET_215
	bg.AlwaysOnTop  = false
	bg.ResetOnSpawn = false
	bg.Parent       = sign

	local frame = Instance.new("Frame")
	frame.Name                   = "VisitorFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_215
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_215
	stroke.Thickness = 1
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "VisitorLabel"
	lbl.Size               = UDim2.new(1, -4, 1, 0)
	lbl.Position           = UDim2.new(0, 2, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "👥 0 visitors"
	lbl.TextSize           = 10
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_215
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	return bg
end

-- ── Update gui ────────────────────────────────────────────────────────────────
local function updateGui_215(sign: BasePart)
	local bg = sign:FindFirstChild("VisitorGui_215") :: BillboardGui?
	if not bg then return end
	local frame = bg:FindFirstChild("VisitorFrame")
	local lbl = frame and frame:FindFirstChild("VisitorLabel") :: TextLabel?
	if not lbl then return end

	local count = (sign:GetAttribute("VisitorCount") :: number?) or 0
	local myPlot = (player:GetAttribute("PlotIndex") :: number?) or -1
	local signPlot = (sign:GetAttribute("PlotIndex") :: number?) or -1
	local isMine = (myPlot == signPlot)

	lbl.Text       = "👥 " .. tostring(count) .. (count == 1 and " visitor" or " visitors")
	lbl.TextColor3 = isMine and MINE_GOLD_215 or WAX_CREAM_215

	local stroke = frame and frame:FindFirstChild("UIStroke") :: UIStroke?
	if stroke then stroke.Color = isMine and MINE_GOLD_215 or HONEY_215 end
end

-- ── Setup sign ────────────────────────────────────────────────────────────────
local function setupSign_215(sign: BasePart)
	if sign:FindFirstChild("VisitorGui_215") then return end
	buildGui_215(sign)
	updateGui_215(sign)

	sign:GetAttributeChangedSignal("VisitorCount"):Connect(function()
		updateGui_215(sign)
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	for _, obj in CollectionService:GetTagged("PlotSign") do
		if obj:IsA("BasePart") then
			setupSign_215(obj)
		end
	end

	CollectionService:GetInstanceAddedSignal("PlotSign"):Connect(function(obj)
		if obj:IsA("BasePart") then
			task.wait(0.5)
			setupSign_215(obj)
		end
	end)
end)
```

---

## Step 3 — Wire VisitorCountController into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("VisitorCountController"))
```

PlotVisitorService is a Script in `ServerScriptService.Systems` — it loads automatically, no wiring needed.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Edit mode):

```lua
local SPS = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local svc = SPS and SPS:FindFirstChild("PlotVisitorService")
print("PlotVisitorService:", svc and svc.ClassName or "MISSING")
if svc then
	print("  VisitorCount write:", svc.Source:find("VisitorCount") ~= nil)
	print("  PlotSign tag:", svc.Source:find("PlotSign") ~= nil)
	print("  PROXIMITY_STUDS_215:", svc.Source:find("PROXIMITY_STUDS_215") ~= nil)
end

local SPLS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPLS and SPLS:FindFirstChild("VisitorCountController")
print("VisitorCountController:", ctrl and ctrl.ClassName or "MISSING")
if ctrl then
	print("  buildGui_215:", ctrl.Source:find("buildGui_215") ~= nil)
	print("  updateGui_215:", ctrl.Source:find("updateGui_215") ~= nil)
end

local CS = game:GetService("CollectionService")
local signs = CS:GetTagged("PlotSign")
print("PlotSign tagged parts:", #signs, "(expect 6)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Manually set visitor count on a sign to test the controller
local CS = game:GetService("CollectionService")
local signs = CS:GetTagged("PlotSign")
if signs[1] then
	signs[1]:SetAttribute("VisitorCount", 3)
	task.wait(0.5)
	print("GUI updated:", signs[1]:FindFirstChild("VisitorGui_215") ~= nil)
	signs[1]:SetAttribute("VisitorCount", 7)
end
```

**Expected output:**
```
PlotVisitorService: Script
  VisitorCount write: true
  PlotSign tag: true
  PROXIMITY_STUDS_215: true
VisitorCountController: LocalScript
  buildGui_215: true
  updateGui_215: true
PlotSign tagged parts: 6
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Condition | Display | Colour |
|---|---|---|
| Nobody has visited | "👥 0 visitors" | Wax cream text |
| 1 visitor | "👥 1 visitor" | Wax cream text |
| 3+ visitors | "👥 3 visitors" | Wax cream text |
| Viewing own plot | Same count | Brighter MINE_GOLD (255,220,80) |

- Billboard sits 5.5 studs above each PlotSign — visible across the Apiary Yard
- Own plot shown in brighter gold — "your sign" vs "their sign" at a glance
- Count increments only once per player per session (unique visitors, not total visits)
- Reactive on `VisitorCount` attribute change — no client polling
- Server writes at 4s check interval — low overhead, sufficient for social display
- Count persists for the session; resets when server restarts

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BillboardGui only — no BaseParts)*
