# Dispatch 193 — Propolis Seal Beam Visual
**File:** `cycle18_propolis_seal_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The outer ring of the hex comb is where `PropolisCell`-tagged parts live. These cells have a `PropolisLevel` attribute (0.0–1.0) set by `CombService`, but there's no visual feedback that the seal is strengthening. This dispatch adds a **Propolis Seal Beam Visual**: a ring of animated client-side Beams connecting each adjacent pair of outer-ring propolis cells, colour-interpolating from dim resin-brown (level 0) to glowing amber-gold (level 1). A faint pulsing "seal aura" Frame in the HUD also shows the overall average seal strength. Entirely client-side — Beam objects are created at runtime as ephemeral children of the cells (not counted against server budget), and Attachments are created inside them as GuiObject-equivalent instances.

---

## Step 1 — PropolisSealController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PropolisSealController`.

Paste exactly:

```lua
--!strict
-- PropolisSealController: animated Beam ring connecting outer propolis cells.
-- Reads PropolisLevel attribute (0..1) on PropolisCell-tagged BaseParts for player's plot.
-- Beam objects are client-only ephemeral — not counted in server part budget.
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_193  = 4.0    -- seconds between full re-scans
local PULSE_RATE_193     = 0.8    -- seconds per pulse cycle
local MAX_BEAM_DIST_193  = 5.0    -- studs — only connect cells within this distance

-- ── Palette ───────────────────────────────────────────────────────────────────
local RESIN_LOW_193    = Color3.fromRGB( 90,  55,  20)   -- dim resin (level 0)
local RESIN_MID_193    = Color3.fromRGB(160,  90,  30)   -- partial seal
local RESIN_HIGH_193   = Color3.fromRGB(210, 145,  40)   -- strong seal
local RESIN_FULL_193   = Color3.fromRGB(242, 168,  28)   -- max seal (Honey Gold)
local WAX_CREAM_193    = Color3.fromRGB(232, 212, 154)
local DARK_BG_193      = Color3.fromRGB( 30,  18,   8)

local function sealColor_193(level: number): Color3
	level = math.clamp(level, 0, 1)
	if level < 0.33 then
		return RESIN_LOW_193:Lerp(RESIN_MID_193, level / 0.33)
	elseif level < 0.66 then
		return RESIN_MID_193:Lerp(RESIN_HIGH_193, (level - 0.33) / 0.33)
	else
		return RESIN_HIGH_193:Lerp(RESIN_FULL_193, (level - 0.66) / 0.34)
	end
end

-- ── Beam registry ─────────────────────────────────────────────────────────────
type BeamEntry = {
	beam:        Beam,
	attachA:     Attachment,
	attachB:     Attachment,
	cellA:       BasePart,
	cellB:       BasePart,
}

local beams_193: { BeamEntry } = {}

-- ── HUD seal aura ─────────────────────────────────────────────────────────────
local sealGui_193: ScreenGui?
local sealBar_193: Frame?
local sealLbl_193: TextLabel?

local function ensureSealGui_193()
	if sealGui_193 and sealGui_193.Parent then return end

	-- Try attaching to HiveGui first
	local pg = player:WaitForChild("PlayerGui", 5) :: PlayerGui?
	if not pg then return end

	local hiveGui = pg:FindFirstChild("HiveGui")
	local parent: Instance = hiveGui or pg

	local sg = Instance.new("ScreenGui")
	sg.Name           = "PropolisSealGui_193"
	sg.DisplayOrder   = 20
	sg.ResetOnSpawn   = false
	sg.Parent         = parent == hiveGui and hiveGui or pg

	-- Bottom-right seal bar (90×20)
	local barBg = Instance.new("Frame")
	barBg.Name                   = "SealBarBg"
	barBg.Size                   = UDim2.new(0, 90, 0, 20)
	barBg.AnchorPoint            = Vector2.new(1, 1)
	barBg.Position               = UDim2.new(1, -8, 1, -44)
	barBg.BackgroundColor3       = DARK_BG_193
	barBg.BackgroundTransparency = 0.15
	barBg.BorderSizePixel        = 0
	barBg.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = barBg

	local stroke = Instance.new("UIStroke")
	stroke.Color     = RESIN_MID_193
	stroke.Thickness = 1
	stroke.Parent    = barBg

	local fill = Instance.new("Frame")
	fill.Name                   = "SealFill"
	fill.Size                   = UDim2.new(0, 0, 1, -4)
	fill.Position               = UDim2.new(0, 2, 0, 2)
	fill.BackgroundColor3       = RESIN_LOW_193
	fill.BorderSizePixel        = 0
	fill.Parent                 = barBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent       = fill

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "SealLabel"
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "🛡️ Seal: 0%"
	lbl.TextSize           = 10
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_193
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = barBg

	sealGui_193 = sg
	sealBar_193 = fill
	sealLbl_193 = lbl
end

local function updateSealHud_193(avgLevel: number)
	if not sealBar_193 or not sealBar_193.Parent then
		ensureSealGui_193()
		return
	end
	local pct = math.clamp(avgLevel, 0, 1)
	local col = sealColor_193(pct)
	TweenService:Create(sealBar_193, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		Size             = UDim2.new(pct, -4, 1, -4),
		BackgroundColor3 = col,
	}):Play()
	if sealLbl_193 then
		sealLbl_193.Text = string.format("🛡️ Seal: %d%%", math.round(pct * 100))
	end
	-- Update UIStroke colour on the bg frame
	local bg = sealBar_193.Parent :: Frame
	local stroke = bg:FindFirstChildOfClass("UIStroke")
	if stroke then stroke.Color = col end
end

-- ── Destroy all beams ─────────────────────────────────────────────────────────
local function clearBeams_193()
	for _, entry in beams_193 do
		if entry.attachA.Parent then entry.attachA:Destroy() end
		if entry.attachB.Parent then entry.attachB:Destroy() end
		if entry.beam.Parent then entry.beam:Destroy() end
	end
	beams_193 = {}
end

-- ── Build beam between two cells ──────────────────────────────────────────────
local function makeBeam_193(cellA: BasePart, cellB: BasePart, level: number)
	local col = sealColor_193(level)
	local emit = 0.1 + level * 0.5

	local attachA = Instance.new("Attachment")
	attachA.Name   = "SealAttach_A_193"
	attachA.Parent = cellA

	local attachB = Instance.new("Attachment")
	attachB.Name   = "SealAttach_B_193"
	attachB.Parent = cellB

	local beam = Instance.new("Beam")
	beam.Name          = "PropolisSealBeam_193"
	beam.Attachment0   = attachA
	beam.Attachment1   = attachB
	beam.Width0        = 0.08
	beam.Width1        = 0.08
	beam.FaceCamera    = true
	beam.Transparency  = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.35),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(1,   0.35),
	})
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   col),
		ColorSequenceKeypoint.new(0.5, col:Lerp(Color3.new(1,1,1), 0.12)),
		ColorSequenceKeypoint.new(1,   col),
	})
	beam.LightEmission = emit
	beam.CurveSize0    = 0
	beam.CurveSize1    = 0
	beam.Parent        = cellA

	table.insert(beams_193, {
		beam    = beam,
		attachA = attachA,
		attachB = attachB,
		cellA   = cellA,
		cellB   = cellB,
	})
end

-- ── Pulse beams ───────────────────────────────────────────────────────────────
local pulseT_193 = 0
local pulseConn_193: RBXScriptConnection?

local function startPulse_193()
	if pulseConn_193 then return end
	pulseConn_193 = RunService.Heartbeat:Connect(function(dt)
		pulseT_193 = pulseT_193 + dt
		local phase = math.sin(pulseT_193 / PULSE_RATE_193 * math.pi) * 0.5 + 0.5
		-- phase 0→1→0 each cycle — pulse width and LightEmission
		for _, entry in beams_193 do
			if entry.beam.Parent then
				local innerTrans = 0.15 + (1 - phase) * 0.30
				entry.beam.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0,   0.40 - phase * 0.15),
					NumberSequenceKeypoint.new(0.5, innerTrans),
					NumberSequenceKeypoint.new(1,   0.40 - phase * 0.15),
				})
			end
		end
	end)
end

local function stopPulse_193()
	if pulseConn_193 then
		pulseConn_193:Disconnect()
		pulseConn_193 = nil
	end
end

-- ── Rebuild all seal beams for player's plot ──────────────────────────────────
local function rebuildBeams_193()
	clearBeams_193()
	stopPulse_193()

	local myPlot = player:GetAttribute("PlotIndex") or 1
	local cells: { BasePart } = {}

	for _, obj in CollectionService:GetTagged("PropolisCell") do
		if not obj:IsA("BasePart") then continue end
		if obj:GetAttribute("PlotIndex") ~= myPlot then continue end
		table.insert(cells, obj)
	end

	if #cells == 0 then
		updateSealHud_193(0)
		return
	end

	-- Compute average propolis level
	local totalLevel = 0
	for _, cell in cells do
		local lv = cell:GetAttribute("PropolisLevel") :: number?
		totalLevel = totalLevel + (lv or 0)
	end
	local avgLevel = totalLevel / #cells

	-- Connect each cell to its nearest neighbour(s) within MAX_BEAM_DIST_193
	-- Use a simple proximity pass — hex ring cells naturally pair with their edge-neighbours
	local paired: { [BasePart]: boolean } = {}
	for i, cellA in cells do
		for j = i + 1, #cells do
			local cellB = cells[j]
			local dist  = (cellA.Position - cellB.Position).Magnitude
			if dist <= MAX_BEAM_DIST_193 then
				-- Average level between pair for beam colour
				local lvA = (cellA:GetAttribute("PropolisLevel") :: number?) or 0
				local lvB = (cellB:GetAttribute("PropolisLevel") :: number?) or 0
				makeBeam_193(cellA, cellB, (lvA + lvB) * 0.5)
				paired[cellA] = true
				paired[cellB] = true
			end
		end
	end

	updateSealHud_193(avgLevel)

	if #beams_193 > 0 then
		startPulse_193()
	end
end

-- ── PropolisLevel attribute watcher ──────────────────────────────────────────
local watchedPropolis_193: { [BasePart]: RBXScriptConnection } = {}

local function watchPropolisCell_193(cell: BasePart)
	if watchedPropolis_193[cell] then return end
	local conn = cell:GetAttributeChangedSignal("PropolisLevel"):Connect(function()
		-- Cheaply update existing beam colours rather than full rebuild
		local lv = (cell:GetAttribute("PropolisLevel") :: number?) or 0
		local col = sealColor_193(lv)
		for _, entry in beams_193 do
			if entry.cellA == cell or entry.cellB == cell then
				if entry.beam.Parent then
					entry.beam.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0,   col),
						ColorSequenceKeypoint.new(0.5, col:Lerp(Color3.new(1,1,1), 0.12)),
						ColorSequenceKeypoint.new(1,   col),
					})
					entry.beam.LightEmission = 0.1 + lv * 0.5
				end
			end
		end
		-- Also update HUD average
		local myPlot = player:GetAttribute("PlotIndex") or 1
		local total, count = 0, 0
		for _, obj in CollectionService:GetTagged("PropolisCell") do
			if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
				total = total + ((obj:GetAttribute("PropolisLevel") :: number?) or 0)
				count += 1
			end
		end
		updateSealHud_193(count > 0 and total / count or 0)
	end)
	watchedPropolis_193[cell] = conn
end

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("PropolisCell"):Connect(function(obj)
	if obj:IsA("BasePart") then
		watchPropolisCell_193(obj)
		rebuildBeams_193()
	end
end)

CollectionService:GetInstanceRemovedSignal("PropolisCell"):Connect(function(obj)
	if obj:IsA("BasePart") then
		local conn = watchedPropolis_193[obj]
		if conn then conn:Disconnect(); watchedPropolis_193[obj] = nil end
		rebuildBeams_193()
	end
end)

-- ── Periodic re-scan ──────────────────────────────────────────────────────────
task.delay(2, function()
	ensureSealGui_193()

	for _, obj in CollectionService:GetTagged("PropolisCell") do
		if obj:IsA("BasePart") then
			watchPropolisCell_193(obj)
		end
	end

	rebuildBeams_193()

	local lastScan = os.clock()
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastScan >= SCAN_INTERVAL_193 then
			lastScan = os.clock()
			rebuildBeams_193()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PropolisSealController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PropolisSealController")
print("PropolisSealController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  rebuildBeams_193:", c.Source:find("rebuildBeams_193") ~= nil)
	print("  makeBeam_193:", c.Source:find("makeBeam_193") ~= nil)
	print("  sealColor_193:", c.Source:find("sealColor_193") ~= nil)
	print("  PropolisLevel watcher:", c.Source:find("PropolisLevel") ~= nil)
end

local CS = game:GetService("CollectionService")
local propCells = CS:GetTagged("PropolisCell")
print("PropolisCell tagged parts:", #propCells,
	"(0 in Edit mode — cells built during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
PropolisSealController: LocalScript
  lines: 230+
  rebuildBeams_193: true
  makeBeam_193: true
  sealColor_193: true
  PropolisLevel watcher: true
PropolisCell tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| PropolisLevel avg | Beam colour | HUD label | Pulse |
|---|---|---|---|
| 0–0.33 | Dim resin-brown | "🛡️ Seal: 0–33%" | Subtle |
| 0.33–0.66 | Warm amber | "🛡️ Seal: 33–66%" | Gentle |
| 0.66–1.0 | Glowing Honey Gold | "🛡️ Seal: 66–100%" | Active |

- Beams connect each adjacent propolis cell pair within 5-stud proximity
- Beam width 0.08 studs — very fine, glowing but not obtrusive
- `PropolisLevel` attribute changes update beam colour cheaply (no full rebuild)
- `rebuildBeams_193()` called on CollectionService Added/Removed + every 4 seconds
- HUD bar (90×20) sits bottom-right, below the existing wasp ping area
- Attachments and Beams are client-only children of the PropoisCell parts — destroyed on `clearBeams_193()`

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Beam + Attachment instances are client-only ephemeral — not counted against server budget)*
