# Dispatch 190 — Comb Cell Repair Overlay
**File:** `cycle18_cell_repair_overlay_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

After a Molasses raid, damaged `CombCell` parts have a `DamageLevel` attribute (1–3) set by ThreatService, but players can't tell at a glance which cells are damaged or how much they'll cost to repair. The dispatch-180 `CellDamageController` shows a toast when damage happens, but doesn't show ongoing status for cells that were damaged in a previous session or before the player loaded in. This dispatch adds a **Comb Cell Repair Overlay**: a persistent BillboardGui on each damaged cell in the player's plot showing a "🔧 N 🪨" repair cost label, and a pulsing SelectionBox-style red rim outline (built from 12 thin Neon Parts forming a hex border). The overlay is built/removed dynamically as `DamageLevel` changes, and batch-scanned every 5 seconds to catch cells damaged before login.

Entirely client-side. The 12 rim outline parts are temporary objects parented to the damaged cell and destroyed when the cell is repaired — they do NOT count against the server-side 5,000 part budget.

---

## Step 1 — CellRepairOverlayController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `CellRepairOverlayController`.

Paste exactly:

```lua
--!strict
-- CellRepairOverlayController: repair overlay (BillboardGui + rim glow) on damaged CombCells.
-- Reads DamageLevel attribute on CombCell-tagged BaseParts for player's plot.
-- Rim outline parts are client-side ephemeral objects — not counted in server part budget.
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_190  = 5.0    -- seconds between batch scans
local RIM_PULSE_190      = 1.2    -- seconds per pulse cycle
local RIM_SEGMENTS_190   = 6      -- number of rim edge segments (hex has 6)
local RIM_THICKNESS_190  = 0.12   -- studs thickness of rim part
local RIM_OFFSET_190     = 0.08   -- studs above cell surface for rim

-- Repair costs per damage level (mirrors Config)
local REPAIR_COSTS_190: { [number]: number } = {
	[1] = 50,
	[2] = 120,
	[3] = 250,
}

-- ── Palette ───────────────────────────────────────────────────────────────────
local RED_190      = Color3.fromRGB(220,  50,  30)
local AMBER_190    = Color3.fromRGB(230, 110,  20)
local WAX_CREAM_190 = Color3.fromRGB(232, 212, 154)
local DARK_BG_190   = Color3.fromRGB( 30,  18,   8)

local function damageColor_190(level: number): Color3
	if level >= 3 then return RED_190 end
	if level >= 2 then return AMBER_190 end
	return Color3.fromRGB(230, 170, 40)
end

-- ── Overlay registry ──────────────────────────────────────────────────────────
type Overlay = {
	billboard: BillboardGui,
	rimParts:  { BasePart },
	pulseConn: RBXScriptConnection?,
	pulseT:    number,
}

local overlays_190: { [BasePart]: Overlay } = {}

-- ── Build hex rim ─────────────────────────────────────────────────────────────
-- CombCell hex plates are cylinders rotated π/2 — radius ~1.6 studs based on architecture
local HEX_CELL_RADIUS_190 = 1.60   -- studs from center to vertex

local function buildRim_190(cell: BasePart, color: Color3): { BasePart }
	local parts: { BasePart } = {}
	local cf = cell.CFrame

	for i = 0, RIM_SEGMENTS_190 - 1 do
		local angle0 = math.pi / 6 + (i / RIM_SEGMENTS_190) * math.pi * 2
		local angle1 = math.pi / 6 + ((i + 1) / RIM_SEGMENTS_190) * math.pi * 2

		local p0 = Vector3.new(
			math.cos(angle0) * HEX_CELL_RADIUS_190,
			RIM_OFFSET_190,
			math.sin(angle0) * HEX_CELL_RADIUS_190
		)
		local p1 = Vector3.new(
			math.cos(angle1) * HEX_CELL_RADIUS_190,
			RIM_OFFSET_190,
			math.sin(angle1) * HEX_CELL_RADIUS_190
		)

		local midLocal = (p0 + p1) * 0.5
		local length   = (p1 - p0).Magnitude
		local segDir   = (p1 - p0).Unit

		local seg = Instance.new("Part")
		seg.Name         = "CellRimSeg_190"
		seg.Size         = Vector3.new(RIM_THICKNESS_190, RIM_THICKNESS_190, length)
		seg.CFrame       = cf * CFrame.new(midLocal)
			* CFrame.fromMatrix(Vector3.new(), segDir, Vector3.new(0, 1, 0))
		seg.Anchored     = true
		seg.CanCollide   = false
		seg.CastShadow   = false
		seg.Material     = Enum.Material.Neon
		seg.Color        = color
		seg.Transparency = 0.2
		seg.Parent       = cell

		table.insert(parts, seg)
	end

	return parts
end

-- ── Build billboard ───────────────────────────────────────────────────────────
local function buildBillboard_190(cell: BasePart, level: number): BillboardGui
	local cost = REPAIR_COSTS_190[level] or 50
	local color = damageColor_190(level)

	local bg = Instance.new("BillboardGui")
	bg.Name                      = "RepairOverlay_190"
	bg.Size                      = UDim2.new(0, 80, 0, 22)
	bg.StudsOffset               = Vector3.new(0, 2.5, 0)
	bg.AlwaysOnTop               = false
	bg.ResetOnSpawn              = false
	bg.Parent                    = cell

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_190
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = color
	stroke.Thickness = 1
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "RepairText"
	lbl.Size               = UDim2.new(1, -4, 1, 0)
	lbl.Position           = UDim2.new(0, 2, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = string.format("🔧 %d 🪨", cost)
	lbl.TextSize           = 11
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_190
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	return bg
end

-- ── Add overlay to a cell ─────────────────────────────────────────────────────
local function addOverlay_190(cell: BasePart, level: number)
	if overlays_190[cell] then return end   -- already overlaid

	local color   = damageColor_190(level)
	local rim     = buildRim_190(cell, color)
	local bill    = buildBillboard_190(cell, level)

	local pulseT   = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		pulseT = pulseT + dt
		local phase = math.sin(pulseT / RIM_PULSE_190 * math.pi) * 0.5 + 0.5
		-- Pulse rim between 0.0 and 0.6 transparency
		for _, seg in rim do
			if seg.Parent then
				seg.Transparency = phase * 0.6
			end
		end
	end)

	overlays_190[cell] = {
		billboard = bill,
		rimParts  = rim,
		pulseConn = conn,
		pulseT    = 0,
	}
end

-- ── Remove overlay from a cell ────────────────────────────────────────────────
local function removeOverlay_190(cell: BasePart)
	local ov = overlays_190[cell]
	if not ov then return end
	if ov.pulseConn then ov.pulseConn:Disconnect() end
	ov.billboard:Destroy()
	for _, seg in ov.rimParts do
		if seg.Parent then seg:Destroy() end
	end
	overlays_190[cell] = nil
end

-- ── Scan player's plot cells ──────────────────────────────────────────────────
local function scanCells_190()
	local myPlot = player:GetAttribute("PlotIndex") or 1

	-- Check all currently-overlaid cells — remove if healed
	for cell, _ in pairs(overlays_190) do
		if not cell.Parent then
			removeOverlay_190(cell)
		else
			local level = cell:GetAttribute("DamageLevel") :: number?
			if not level or level <= 0 then
				removeOverlay_190(cell)
			end
		end
	end

	-- Add overlays to newly-damaged cells
	for _, cell in CollectionService:GetTagged("CombCell") do
		if not cell:IsA("BasePart") then continue end
		if cell:GetAttribute("PlotIndex") ~= myPlot then continue end
		local level = cell:GetAttribute("DamageLevel") :: number?
		if level and level > 0 then
			addOverlay_190(cell, level)
		end
	end
end

-- ── Watch for attribute changes on all tagged cells ───────────────────────────
local watchedCells_190: { [BasePart]: RBXScriptConnection } = {}

local function watchCell_190(cell: BasePart)
	if watchedCells_190[cell] then return end
	local conn = cell:GetAttributeChangedSignal("DamageLevel"):Connect(function()
		local level = cell:GetAttribute("DamageLevel") :: number?
		if level and level > 0 then
			removeOverlay_190(cell)   -- rebuild with new cost
			addOverlay_190(cell, level)
		else
			removeOverlay_190(cell)
		end
	end)
	watchedCells_190[cell] = conn
end

local function unwatchCell_190(cell: BasePart)
	local conn = watchedCells_190[cell]
	if conn then conn:Disconnect(); watchedCells_190[cell] = nil end
end

-- ── CollectionService hooks for new/removed CombCells ────────────────────────
CollectionService:GetInstanceAddedSignal("CombCell"):Connect(function(obj)
	if obj:IsA("BasePart") then
		watchCell_190(obj)
	end
end)

CollectionService:GetInstanceRemovedSignal("CombCell"):Connect(function(obj)
	if obj:IsA("BasePart") then
		removeOverlay_190(obj)
		unwatchCell_190(obj)
	end
end)

-- ── Init ──────────────────────────────────────────────────────────────────────
task.delay(2, function()
	-- Watch all existing cells
	for _, cell in CollectionService:GetTagged("CombCell") do
		if cell:IsA("BasePart") then
			watchCell_190(cell)
		end
	end

	-- Initial scan
	scanCells_190()

	-- Periodic re-scan
	local lastScan = os.clock()
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastScan >= SCAN_INTERVAL_190 then
			lastScan = os.clock()
			scanCells_190()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("CellRepairOverlayController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("CellRepairOverlayController")
print("CellRepairOverlayController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  addOverlay_190:", c.Source:find("addOverlay_190") ~= nil)
	print("  buildRim_190:", c.Source:find("buildRim_190") ~= nil)
	print("  DamageLevel watcher:", c.Source:find("DamageLevel") ~= nil)
	print("  scanCells_190:", c.Source:find("scanCells_190") ~= nil)
end

-- Spot-test: manually set DamageLevel on a CombCell if one exists
local CS = game:GetService("CollectionService")
local cells = CS:GetTagged("CombCell")
print("CombCell tagged parts:", #cells,
	"(0 in fresh Edit mode — cells exist only after build phase in Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204 in Edit mode)")
```

**Expected output:**
```
CellRepairOverlayController: LocalScript
  lines: 210+
  addOverlay_190: true
  buildRim_190: true
  DamageLevel watcher: true
  scanCells_190: true
CombCell tagged parts: 0  (0 in Edit mode — cells built during Play)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| DamageLevel | Rim colour | Repair cost label | Pulse |
|-------------|-----------|-------------------|-------|
| 1 (light)   | Amber-gold | "🔧 50 🪨" | Slow pulse 0→60% transparency |
| 2 (medium)  | Orange | "🔧 120 🪨" | Slow pulse |
| 3 (heavy)   | Red | "🔧 250 🪨" | Slow pulse |
| 0 or repaired | No overlay | — | — |
| Cell destroyed | Overlay removed immediately | — | — |
| Player joins mid-damage | 2s init scan catches existing damage | Shown immediately | Active |

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(6 rim segments per damaged cell are client-side-only ephemeral Parts, children of the CombCell — not counted against server budget)*
