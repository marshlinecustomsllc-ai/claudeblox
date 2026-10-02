# Dispatch 205 — Queen Tier Crown Aura
**File:** `cycle20_queen_aura_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The queen's tier drives the entire production chain but has no persistent world-space presence. Once the `QueenCoronationController` animation finishes (dispatch 191), the queen's tier is only readable from the HiveGui tab. This dispatch adds a **Queen Tier Crown Aura**: a flat Neon ring hovering 1.2 studs above the `QueenCell`-tagged BasePart, sized and coloured by queen tier. T1 = small silver ring (humble start), T2 = small gold, T3 = medium purple, T4 = medium ember-orange, T5 = large sun-yellow. The ring is created client-side, parented to the QueenCell part, and rebuilt whenever `QueenTier` player attribute changes. Zero server writes.

---

## Step 1 — QueenAuraController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `QueenAuraController`.

Paste exactly:

```lua
--!strict
-- QueenAuraController: Neon ring above QueenCell part sized/coloured by QueenTier.
-- Reads QueenTier player attribute. Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local RING_HEIGHT_205     = 1.2    -- studs above QueenCell top face
local RING_THICKNESS_205  = 0.15   -- studs (ring wall thickness)
local SPIN_RATE_205       = 0.25   -- rotations per second
local SCAN_INTERVAL_205   = 8.0    -- seconds between safety re-scans

-- ── Tier visual spec ──────────────────────────────────────────────────────────
local TIER_SPEC_205: { [number]: { radius: number, color: Color3, label: string } } = {
	[1] = { radius = 0.55, color = Color3.fromRGB(200, 200, 220), label = "T1" },   -- silver
	[2] = { radius = 0.65, color = Color3.fromRGB(242, 168,  28), label = "T2" },   -- gold
	[3] = { radius = 0.80, color = Color3.fromRGB(180, 120, 255), label = "T3" },   -- purple
	[4] = { radius = 0.95, color = Color3.fromRGB(255, 100,  30), label = "T4" },   -- ember
	[5] = { radius = 1.20, color = Color3.fromRGB(255, 240,  60), label = "T5" },   -- sun
}

-- ── State ─────────────────────────────────────────────────────────────────────
local ringPart_205: Part?          = nil
local currentTier_205              = 0
local spinConn_205: RBXScriptConnection? = nil

-- ── Find player's QueenCell ───────────────────────────────────────────────────
local function getQueenCell_205(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, obj in CollectionService:GetTagged("QueenCell") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			return obj
		end
	end
	return nil
end

-- ── Remove ring ───────────────────────────────────────────────────────────────
local function removeRing_205()
	if spinConn_205 then spinConn_205:Disconnect(); spinConn_205 = nil end
	if ringPart_205 and ringPart_205.Parent then
		ringPart_205:Destroy()
	end
	ringPart_205  = nil
	currentTier_205 = 0
end

-- ── Build ring Part ───────────────────────────────────────────────────────────
local function buildRing_205(cell: BasePart, tier: number): Part?
	local spec = TIER_SPEC_205[tier]
	if not spec then return nil end

	-- Ring as a thin flat cylinder (diameter = 2*radius, height = thickness)
	local diameter = spec.radius * 2
	local ring = Instance.new("Part")
	ring.Name          = "QueenAuraRing_205"
	ring.Shape         = Enum.PartType.Cylinder
	ring.Size          = Vector3.new(RING_THICKNESS_205, diameter, diameter)
	ring.Anchored      = true
	ring.CanCollide    = false
	ring.CastShadow    = false
	ring.Material      = Enum.Material.Neon
	ring.Color         = spec.color
	-- Position: above cell, rotated so cylinder axis = Y (vertical ring)
	local cellTop = cell.Position + Vector3.new(0, cell.Size.Y / 2, 0)
	ring.CFrame    = CFrame.new(cellTop + Vector3.new(0, RING_HEIGHT_205, 0))
	              * CFrame.Angles(0, 0, math.pi / 2)   -- spin cylinder to face up
	ring.Parent    = cell
	return ring
end

-- ── Start spin ────────────────────────────────────────────────────────────────
local function startSpin_205(ring: Part)
	if spinConn_205 then spinConn_205:Disconnect() end
	local angle = 0
	local spec  = TIER_SPEC_205[currentTier_205]
	if not spec then return end
	local radius = spec.radius
	local cellQueenCell = ring.Parent :: BasePart?
	if not cellQueenCell then return end

	spinConn_205 = RunService.Heartbeat:Connect(function(dt: number)
		if not ring.Parent then spinConn_205 = nil return end
		angle += dt * SPIN_RATE_205 * math.pi * 2
		local cell = ring.Parent :: BasePart?
		if not cell then spinConn_205 = nil return end
		local cellTop = cell.Position + Vector3.new(0, cell.Size.Y / 2, 0)
		ring.CFrame = CFrame.new(cellTop + Vector3.new(0, RING_HEIGHT_205, 0))
		           * CFrame.Angles(0, angle, math.pi / 2)
	end)
end

-- ── Update ring for tier ──────────────────────────────────────────────────────
local function updateTier_205(tier: number)
	if tier <= 0 then
		removeRing_205()
		return
	end

	local cell = getQueenCell_205()
	if not cell then
		removeRing_205()
		currentTier_205 = tier
		return
	end

	-- If tier changed or ring is gone, rebuild
	if tier ~= currentTier_205 or not ringPart_205 or not ringPart_205.Parent then
		removeRing_205()
		currentTier_205 = tier
		local ring = buildRing_205(cell, tier)
		if ring then
			ringPart_205 = ring
			startSpin_205(ring)
		end
	end
end

-- ── React to QueenTier attribute ──────────────────────────────────────────────
local function onQueenTierChanged_205()
	local tier = (player:GetAttribute("QueenTier") :: number?) or 0
	if tier == currentTier_205 and ringPart_205 and ringPart_205.Parent then return end
	updateTier_205(tier)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	onQueenTierChanged_205()

	player:GetAttributeChangedSignal("QueenTier"):Connect(onQueenTierChanged_205)

	-- Safety re-scan (QueenCell may be placed after this script loads)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= SCAN_INTERVAL_205 then
			acc = 0
			onQueenTierChanged_205()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("QueenAuraController"))
```

---

## Step 3 — Attribute source (QueenService)

`QueenAuraController` reads the `QueenTier` player attribute that `QueenService` sets via `player:SetAttribute("QueenTier", tier)`. No server changes needed — attribute is already broadcast by the queen system (dispatch 10 / cycle10_queen_dispatch.md).

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("QueenAuraController")
print("QueenAuraController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildRing_205:", c.Source:find("buildRing_205") ~= nil)
	print("  updateTier_205:", c.Source:find("updateTier_205") ~= nil)
	print("  startSpin_205:", c.Source:find("startSpin_205") ~= nil)
	print("  TIER_SPEC_205:", c.Source:find("TIER_SPEC_205") ~= nil)
	print("  QueenTier attr:", c.Source:find("QueenTier") ~= nil)
end

local CS = game:GetService("CollectionService")
local cells = CS:GetTagged("QueenCell")
print("QueenCell tagged parts:", #cells, "(0 or 6 depending on build state)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Simulate T1 → T5 tier progression
for i = 1, 5 do
	game:GetService("Players").LocalPlayer:SetAttribute("QueenTier", i)
	task.wait(1.5)
end
```

**Expected output:**
```
QueenAuraController: LocalScript
  lines: 130+
  buildRing_205: true
  updateTier_205: true
  startSpin_205: true
  TIER_SPEC_205: true
  QueenTier attr: true
QueenCell tagged parts: 0 or 6
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| QueenTier | Ring radius | Colour | Style |
|---|---|---|---|
| 0 / no queen | None | — | — |
| T1 | 0.55 studs | Silver `(200,200,220)` | Small, humble |
| T2 | 0.65 studs | Honey Gold `(242,168,28)` | Getting warm |
| T3 | 0.80 studs | Violet `(180,120,255)` | Prestige glow |
| T4 | 0.95 studs | Ember `(255,100,30)` | Power surge |
| T5 | 1.20 studs | Sun Yellow `(255,240,60)` | Maximum presence |

- Ring is a thin Neon cylinder (0.15 studs thick) oriented horizontally above the QueenCell
- Slow rotation at 0.25 rev/sec via Heartbeat CFrame — subtle, dignified
- Parented to the QueenCell BasePart so it moves with the cell automatically
- Rebuilds instantly on tier upgrade (ring Part is a client-only child of the cell)
- The Neon material means the ring emits light — visible across the plot and from adjacent plots at T4-T5

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(QueenAuraRing_205 Part is a client-only child of QueenCell — created and owned by this LocalScript; NOT a permanent server-side part)*
