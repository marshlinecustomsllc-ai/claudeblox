# Dispatch 228 — Comb Cell Shimmer
**File:** `cycle23_comb_shimmer_dispatch.md`
**Cycle:** 23
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The hex comb grid is the visual centrepiece of each plot, but the cells sit static between harvests. This dispatch adds a **subtle comb shimmer**: a slow oscillation of each cell's `PointLight` brightness (creating a tiny embedded light if absent on HoneyCell / WaxCell / NurtureCell parts) that gives the comb a gentle golden breathing effect, like sunlight caught in real beeswax. The effect is extremely subtle — a 0.3s phase offset per cell so the grid shimmers in a slow wave rather than all flickering together.

For kids: the comb grid feels alive, like a real buzzing hive. For adults: the wave pattern is satisfying and communicates "healthy, active hive" without any UI text.

---

## Step 1 — CombShimmerController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `CombShimmerController`.

Paste exactly:

```lua
--!strict
-- CombShimmerController: slow PointLight brightness oscillation on comb cell parts.
-- Creates a gentle golden shimmer wave across the hex grid.
-- Entirely client-side — reads CollectionService tags. Zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local SHIMMER_TAGS_228   = { "HoneyCell", "WaxCell", "NurtureCell", "BroodCell" }
local MIN_BRIGHTNESS_228 = 0.08   -- near-off
local MAX_BRIGHTNESS_228 = 0.32   -- gentle warm glow
local SHIMMER_SPEED_228  = 0.18   -- oscillations per second (very slow)
local PHASE_STEP_228     = 0.30   -- seconds offset per successive cell (wave effect)
local LIGHT_RANGE_228    = 2.5    -- studs
local LIGHT_COLOR_228    = Color3.fromRGB(255, 200, 80)   -- warm honey gold
local SCAN_INTERVAL_228  = 10.0   -- seconds between new-cell scan

-- ── Per-cell registry ─────────────────────────────────────────────────────────
-- Each entry: { light: PointLight, phase: number }
local cellLights_228: { [BasePart]: { light: PointLight, phase: number } } = {}
local phaseCounter_228 = 0   -- increments for each registered cell

-- ── Build/find light for a cell ───────────────────────────────────────────────
local function ensureLight_228(cell: BasePart): PointLight?
	local existing = cell:FindFirstChild("CombShimmer_228") :: PointLight?
	if existing then return existing end
	-- Only create if cell has no PointLight at all (don't stack)
	if cell:FindFirstChildOfClass("PointLight") then
		return cell:FindFirstChildOfClass("PointLight")
	end
	local light = Instance.new("PointLight")
	light.Name       = "CombShimmer_228"
	light.Brightness = MIN_BRIGHTNESS_228
	light.Range      = LIGHT_RANGE_228
	light.Color      = LIGHT_COLOR_228
	light.Shadows    = false   -- no shadow cost at this range/brightness
	light.Parent     = cell
	return light
end

-- ── Register a cell ───────────────────────────────────────────────────────────
local function registerCell_228(cell: BasePart)
	if cellLights_228[cell] then return end
	local light = ensureLight_228(cell)
	if not light then return end
	local phase = phaseCounter_228 * PHASE_STEP_228
	phaseCounter_228 += 1
	cellLights_228[cell] = { light = light, phase = phase }
end

-- ── Heartbeat: update all lights ──────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt: number)
	local t = os.clock()   -- monotonic, smooth
	for cell, entry in cellLights_228 do
		if not cell.Parent then
			cellLights_228[cell] = nil
			continue
		end
		local wave = (math.sin((t + entry.phase) * SHIMMER_SPEED_228 * math.pi * 2) + 1) * 0.5
		entry.light.Brightness = MIN_BRIGHTNESS_228 + wave * (MAX_BRIGHTNESS_228 - MIN_BRIGHTNESS_228)
	end
end)

-- ── Scan for new/removed cells ────────────────────────────────────────────────
local scanAcc_228 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_228 += dt
	if scanAcc_228 < SCAN_INTERVAL_228 then return end
	scanAcc_228 = 0
	for _, tag in SHIMMER_TAGS_228 do
		for _, cell in CollectionService:GetTagged(tag) do
			if cell:IsA("BasePart") then
				registerCell_228(cell)
			end
		end
	end
end)

-- ── Live signals for cells added/removed during play ─────────────────────────
for _, tag in SHIMMER_TAGS_228 do
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		if inst:IsA("BasePart") then
			task.delay(0.5, function()
				registerCell_228(inst)
			end)
		end
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		if inst:IsA("BasePart") then
			cellLights_228[inst] = nil
		end
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4.5, function()
	for _, tag in SHIMMER_TAGS_228 do
		for _, cell in CollectionService:GetTagged(tag) do
			if cell:IsA("BasePart") then
				registerCell_228(cell)
			end
		end
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("CombShimmerController"))
```

---

## Step 3 — Performance note

**Expected cell count:** A full plot has up to 114 DimCellPlate cells; across 6 plots that's up to 684 cells. However:
- The Heartbeat loop only writes one property (`Brightness`) on each cell
- PointLight Brightness writes are inexpensive — no geometry or physics
- The wave is driven by `os.clock()`, not per-cell accumulator math
- Cells with no owner (empty plots) produce near-zero writes (cellLights_228 is empty)

In practice 2–3 active players mean 200–350 registered cells. This is safe for a 60fps heartbeat. If performance is a concern, add a `BATCH_LIMIT_228 = 200` check and only process cells[1..200] per frame.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode after building some cells):

```lua
local CS = game:GetService("CollectionService")
local total = 0
for _, tag in {"HoneyCell", "WaxCell", "NurtureCell", "BroodCell"} do
	local tagged = CS:GetTagged(tag)
	total += #tagged
	print(tag .. ":", #tagged)
end
print("Total shimmer-eligible cells:", total)

-- Check a cell has the light
local honeyCells = CS:GetTagged("HoneyCell")
if honeyCells[1] then
	local hc = honeyCells[1] :: BasePart
	local light = hc:FindFirstChild("CombShimmer_228")
	print("CombShimmer_228 on first HoneyCell:", light ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| Property | Value | Effect |
|---|---|---|
| Brightness oscillation | 0.08 → 0.32 | Barely noticeable dim, gentle at peak |
| Oscillation speed | 0.18/s | 5.5s full cycle — extremely slow, calming |
| Phase offset | 0.3s per cell | Wave travels across the grid ~3–4 cells/second |
| Light range | 2.5 studs | Only illuminates adjacent cells, no light bleed |
| Colour | Warm honey gold (255,200,80) | Matches hive house style |
| Shadows | false | No shadow cost on mobile |

- Cells with an existing PointLight reuse it rather than stacking a second
- GetInstanceAdded / GetInstanceRemovedSignal keep registration current as cells are built/destroyed
- 10s scan fills in any cells missed by the signal (streaming, late load)
- 0.5s delay on GetInstanceAdded ensures the cell is fully parented before registering
- The shimmer is deliberately subtle — it should be *noticed on reflection* rather than *immediately obvious*, like real beeswax catching light

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(PointLights created inside existing cell parts — no new BaseParts)*
