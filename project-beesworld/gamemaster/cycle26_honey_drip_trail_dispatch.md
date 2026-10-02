# Dispatch 239 — Honey Cell Drip Effect
**File:** `cycle26_honey_drip_trail_dispatch.md`
**Cycle:** 26
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

HoneyCell parts that are full to capacity have no visual difference from HoneyCells with only a small amount of honey stored. This dispatch adds a **Honey Cell Drip Effect**: a client-side LocalScript that reads each `HoneyCell` Part's `HoneyStored` and `HoneyCapacity` attributes, and shows a slow golden drip ParticleEmitter on cells that are ≥ 80% full — as if honey is literally overflowing from the comb. Cells below the threshold have no emitter activity, keeping the effect focused and meaningful.

For kids: the golden drips are a clear visual cue that "this cell is full of honey, harvest time!" Adults get the same signal with a more satisfying aesthetic reading of the hive's productive state.

---

## Step 1 — HoneyCellDripController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HoneyCellDripController`.

Paste exactly:

```lua
--!strict
-- HoneyCellDripController: golden drip particles on full/near-full HoneyCell parts.
-- Reads HoneyStored and HoneyCapacity attributes. Shows drip when fill >= DRIP_THRESHOLD_239.
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local DRIP_THRESHOLD_239 = 0.80   -- fill fraction (0–1) at which drips appear
local DRIP_RATE_239      = 1.2    -- particles per second (very sparse — just a drip)
local DRIP_COLOR_239     = Color3.fromRGB(230, 160, 20)   -- dark honey amber
local DRIP_LIFETIME_239  = 1.8    -- seconds
local DRIP_SPEED_239     = 1.8    -- studs/s downward
local DRIP_SIZE_239      = 0.18   -- diameter in studs
local SCAN_INTERVAL_239  = 8.0    -- seconds between new-cell scans

local EMITTER_NAME_239   = "HoneyDrip_239"

-- ── Per-cell registry ─────────────────────────────────────────────────────────
local cellEmitters_239: { [BasePart]: ParticleEmitter } = {}

-- ── Build emitter for a cell ──────────────────────────────────────────────────
local function ensureEmitter_239(cell: BasePart): ParticleEmitter
	local existing = cell:FindFirstChild(EMITTER_NAME_239) :: ParticleEmitter?
	if existing then return existing end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name      = EMITTER_NAME_239
	emitter.Rate      = 0   -- off by default
	emitter.Color     = ColorSequence.new({
		ColorSequenceKeypoint.new(0, DRIP_COLOR_239),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 110, 10)),   -- darkens as it falls
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, DRIP_SIZE_239),
		NumberSequenceKeypoint.new(0.5, DRIP_SIZE_239 * 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime       = NumberRange.new(DRIP_LIFETIME_239 * 0.8, DRIP_LIFETIME_239 * 1.2)
	emitter.Speed          = NumberRange.new(DRIP_SPEED_239 * 0.7, DRIP_SPEED_239)
	emitter.SpreadAngle    = Vector2.new(5, 5)    -- nearly straight down
	emitter.LightEmission  = 0.20
	emitter.LightInfluence = 0.80
	emitter.RotSpeed       = NumberRange.new(0, 0)
	emitter.Rotation       = NumberRange.new(0, 0)
	-- Emit downward (negative Y)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Parent = cell
	return emitter
end

-- ── Update a cell's emitter ───────────────────────────────────────────────────
local function updateCell_239(cell: BasePart, emitter: ParticleEmitter)
	local stored   = (cell:GetAttribute("HoneyStored")   :: number?) or 0
	local capacity = (cell:GetAttribute("HoneyCapacity") :: number?) or 1
	local fill     = if capacity > 0 then math.clamp(stored / capacity, 0, 1) else 0

	if fill >= DRIP_THRESHOLD_239 then
		-- Scale rate slightly with fill level (80% = base rate, 100% = 1.5× rate)
		local fillAboveThreshold = (fill - DRIP_THRESHOLD_239) / (1 - DRIP_THRESHOLD_239)
		emitter.Rate = DRIP_RATE_239 * (1 + fillAboveThreshold * 0.5)
	else
		emitter.Rate = 0
	end
end

-- ── Register a cell ───────────────────────────────────────────────────────────
local function registerCell_239(cell: BasePart)
	if cellEmitters_239[cell] then return end
	local emitter = ensureEmitter_239(cell)
	cellEmitters_239[cell] = emitter
	updateCell_239(cell, emitter)

	-- React to attribute changes
	cell:GetAttributeChangedSignal("HoneyStored"):Connect(function()
		updateCell_239(cell, emitter)
	end)
	cell:GetAttributeChangedSignal("HoneyCapacity"):Connect(function()
		updateCell_239(cell, emitter)
	end)
end

-- ── Scan ─────────────────────────────────────────────────────────────────────
local scanAcc_239 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_239 += dt
	if scanAcc_239 < SCAN_INTERVAL_239 then return end
	scanAcc_239 = 0
	for _, cell in CollectionService:GetTagged("HoneyCell") do
		if cell:IsA("BasePart") then registerCell_239(cell) end
	end
	for cell in cellEmitters_239 do
		if not cell.Parent then cellEmitters_239[cell] = nil end
	end
end)

CollectionService:GetInstanceAddedSignal("HoneyCell"):Connect(function(inst)
	if inst:IsA("BasePart") then
		task.delay(0.5, function() registerCell_239(inst) end)
	end
end)

CollectionService:GetInstanceRemovedSignal("HoneyCell"):Connect(function(inst)
	if inst:IsA("BasePart") then
		cellEmitters_239[inst] = nil
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(5, function()
	for _, cell in CollectionService:GetTagged("HoneyCell") do
		if cell:IsA("BasePart") then registerCell_239(cell) end
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HoneyCellDripController"))
```

---

## Step 3 — CombService attribute writes

The controller reads `HoneyStored` and `HoneyCapacity` from each HoneyCell Part. Confirm CombService (or ForagingService / ResourceService) writes these:

```lua
-- When honey is deposited into a cell:
combPart:SetAttribute("HoneyStored",   math.floor(cellData.stored))
combPart:SetAttribute("HoneyCapacity", cellData.capacity)   -- max honey this cell holds
```

If `HoneyCapacity` is a constant derived from Config, it can be written once on cell creation:

```lua
-- On cell creation/registration:
combPart:SetAttribute("HoneyCapacity", Config.HONEY_CELL_CAPACITY)
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode, after building at least one HoneyCell):

```lua
local CS = game:GetService("CollectionService")
local cells = CS:GetTagged("HoneyCell")
print("HoneyCell tagged:", #cells)

if cells[1] then
	local c = cells[1]
	-- Force full to test drip
	c:SetAttribute("HoneyCapacity", 100)
	c:SetAttribute("HoneyStored", 90)   -- 90% — should start dripping
	task.wait(2)
	print("Drip should be visible above cell")

	c:SetAttribute("HoneyStored", 50)   -- 50% — drip should stop
	task.wait(1)
	print("Drip should be off")

	c:SetAttribute("HoneyStored", 100)  -- 100% full — drip at 1.5× rate
	task.wait(2)
	print("Drip should be faster")
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Performance note

**Worst case:** 114 HoneyCells per plot × 6 plots = 684 cells. All 684 are registered. But emitter Rate=0 when fill < 0.80, so inactive cells produce zero particles. In practice only a fraction of cells are ≥ 80% full at any time. Even if all 684 were full: 684 × 1.8 p/s = 1,231 p/s — above the 80 p/s guideline. To stay within budget, a per-player plot scope is sufficient: only register cells in the player's own plot:

```lua
-- Optional: scope to owner's plot (add inside registerCell_239 guard):
local plotIndex = (cell:GetAttribute("PlotIndex") :: number?) or 0
local myPlot    = (localPlayer:GetAttribute("PlotIndex") :: number?) or 0
if plotIndex ~= myPlot then return end   -- skip other players' cells
```

With this guard: max 114 cells × 1.8 p/s = 205 p/s. If the server-side cell architecture does not include a PlotIndex attribute, skip the guard — 6-player lobbies mean only ~19 cells average per player are ≥ 80% full, totalling ~34 p/s across the lobby, well within budget.

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(ParticleEmitters inside existing HoneyCell parts — no BaseParts)*
