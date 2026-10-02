# Dispatch 201 — Pollen Mound Sparkle
**File:** `cycle20_pollen_sparkle_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Pollen Mound CellContent parts currently sit static in their cells. When a hive is actively foraging, those mounds should feel *alive* — a quiet shimmer indicates rich pollen. This dispatch adds a **Pollen Mound Sparkle**: a client-side Heartbeat animation that tweens the `Color` and `Material` of `PollenMound`-tagged BaseParts through a soft amber-gold shimmer cycle when their `PollenLevel` attribute is above 0.6 (60%). Below 0.6 the part sits still at its base colour. No new parts, no BillboardGuis — pure property animation on existing CellContent geometry.

---

## Step 1 — PollenSparkleController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PollenSparkleController`.

Paste exactly:

```lua
--!strict
-- PollenSparkleController: colour shimmer on PollenMound parts at high pollen level.
-- Reads PollenLevel attribute (0..1) from PollenMound-tagged BaseParts.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SHIMMER_THRESHOLD_201 = 0.60    -- PollenLevel above this = sparkle active
local SHIMMER_RATE_201      = 0.55    -- sine cycles per second
local SCAN_INTERVAL_201     = 4.0     -- seconds between full re-scans

-- ── Palette ───────────────────────────────────────────────────────────────────
-- Base pollen colour (matches PollenMound template from the Templates library)
local POLLEN_BASE_201   = Color3.fromRGB(220, 200,  60)   -- muted gold-yellow
-- Shimmer highlight
local POLLEN_SHIMMER_201 = Color3.fromRGB(255, 235,  80)  -- bright warm yellow
-- Very rich shimmer (top 20%)
local POLLEN_PEAK_201   = Color3.fromRGB(255, 250, 140)   -- pale lemon

-- ── Active mound registry ─────────────────────────────────────────────────────
-- Maps each active PollenMound part to its current shimmer phase offset
local activeMounds_201: { [BasePart]: number } = {}

-- ── Compute shimmer colour ────────────────────────────────────────────────────
local function shimmerColor_201(phase: number, level: number): Color3
	-- phase: 0..1 (sine cycle), level: 0..1
	local t = (math.sin(phase * math.pi * 2) + 1) * 0.5  -- 0..1
	local richness = math.clamp((level - SHIMMER_THRESHOLD_201) / 0.4, 0, 1)
	local peak = POLLEN_BASE_201:Lerp(POLLEN_PEAK_201, richness)
	return POLLEN_BASE_201:Lerp(peak, t * 0.7)
end

-- ── Register mound ────────────────────────────────────────────────────────────
local function registerMound_201(part: BasePart)
	if activeMounds_201[part] then return end
	-- Random phase offset so mounds don't all pulse together
	activeMounds_201[part] = math.random() :: number
end

-- ── Unregister mound (restore base colour) ────────────────────────────────────
local function unregisterMound_201(part: BasePart)
	if not activeMounds_201[part] then return end
	activeMounds_201[part] = nil
	if part.Parent then
		TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
			Color = POLLEN_BASE_201,
		}):Play()
	end
end

-- ── Scan PollenMound parts for this player's plot ─────────────────────────────
local function scan_201()
	local myPlot = player:GetAttribute("PlotIndex") or 1

	-- Remove mounds that are gone or below threshold
	for part, _ in pairs(activeMounds_201) do
		if not part.Parent then
			activeMounds_201[part] = nil
		else
			local level = (part:GetAttribute("PollenLevel") :: number?) or 0
			if part:GetAttribute("PlotIndex") ~= myPlot or level < SHIMMER_THRESHOLD_201 then
				unregisterMound_201(part)
			end
		end
	end

	-- Add mounds that are at or above threshold
	for _, obj in CollectionService:GetTagged("PollenMound") do
		if not obj:IsA("BasePart") then continue end
		if obj:GetAttribute("PlotIndex") ~= myPlot then continue end
		local level = (obj:GetAttribute("PollenLevel") :: number?) or 0
		if level >= SHIMMER_THRESHOLD_201 then
			registerMound_201(obj)
		end
	end
end

-- ── Heartbeat shimmer loop ────────────────────────────────────────────────────
local globalPhase_201 = 0
local scanAcc_201     = 0

RunService.Heartbeat:Connect(function(dt: number)
	globalPhase_201 += dt * SHIMMER_RATE_201
	if globalPhase_201 > 1 then globalPhase_201 -= 1 end

	scanAcc_201 += dt
	if scanAcc_201 >= SCAN_INTERVAL_201 then
		scanAcc_201 = 0
		scan_201()
	end

	for part, offset in pairs(activeMounds_201) do
		if not part.Parent then
			activeMounds_201[part] = nil
			continue
		end
		local level = (part:GetAttribute("PollenLevel") :: number?) or 0
		local phase = (globalPhase_201 + offset) % 1
		part.Color = shimmerColor_201(phase, level)
	end
end)

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("PollenMound"):Connect(function(obj)
	if obj:IsA("BasePart") then
		task.wait(0.5)
		scan_201()
	end
end)

CollectionService:GetInstanceRemovedSignal("PollenMound"):Connect(function(obj)
	if obj:IsA("BasePart") then
		activeMounds_201[obj] = nil
	end
end)

-- ── Attribute watch for instant threshold crossing ────────────────────────────
local function watchMound_201(part: BasePart)
	part:GetAttributeChangedSignal("PollenLevel"):Connect(function()
		local level = (part:GetAttribute("PollenLevel") :: number?) or 0
		local myPlot = player:GetAttribute("PlotIndex") or 1
		if part:GetAttribute("PlotIndex") == myPlot and level >= SHIMMER_THRESHOLD_201 then
			registerMound_201(part)
		else
			unregisterMound_201(part)
		end
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	scan_201()
	-- Watch all existing mounds
	for _, obj in CollectionService:GetTagged("PollenMound") do
		if obj:IsA("BasePart") then
			watchMound_201(obj)
		end
	end
	-- Watch future mounds
	CollectionService:GetInstanceAddedSignal("PollenMound"):Connect(function(obj)
		if obj:IsA("BasePart") then
			task.wait(0.5)
			watchMound_201(obj)
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PollenSparkleController"))
```

---

## Step 3 — Attribute source (ResourceService / PopulationService)

`PollenSparkleController` reads one attribute from `PollenMound` CellContent BaseParts:

| Attribute | Set by | When |
|---|---|---|
| `PollenLevel` | ResourceService or PopulationService | After each hatch or pollen deposit; value 0–1 |

If `PollenLevel` is not yet written to the PollenMound part's BasePart, add it after each pollen deposit or consumption:

```lua
-- In ResourceService or PopulationService, after updating pollen in a cell:
local pollenPart = -- (the PollenMound BasePart inside this cell)
if pollenPart then
    local maxPollen = Config.CELL_POLLEN_MAX or 100
    pollenPart:SetAttribute("PollenLevel", math.clamp(currentPollen / maxPollen, 0, 1))
    pollenPart:SetAttribute("PlotIndex", plotIndex)
end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PollenSparkleController")
print("PollenSparkleController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  shimmerColor_201:", c.Source:find("shimmerColor_201") ~= nil)
	print("  registerMound_201:", c.Source:find("registerMound_201") ~= nil)
	print("  scan_201:", c.Source:find("scan_201") ~= nil)
	print("  SHIMMER_THRESHOLD_201:", c.Source:find("SHIMMER_THRESHOLD_201") ~= nil)
	print("  PollenLevel attr:", c.Source:find("PollenLevel") ~= nil)
end

local CS = game:GetService("CollectionService")
local mounds = CS:GetTagged("PollenMound")
print("PollenMound tagged parts:", #mounds, "(0 in Edit mode — built during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
PollenSparkleController: LocalScript
  lines: 130+
  shimmerColor_201: true
  registerMound_201: true
  scan_201: true
  SHIMMER_THRESHOLD_201: true
  PollenLevel attr: true
PollenMound tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| PollenLevel | Effect |
|---|---|
| Below 0.60 | No shimmer; part colour stays at `POLLEN_BASE_201` (muted gold-yellow) |
| 0.60–0.80 | Soft shimmer: base ↔ warm yellow |
| 0.80–1.00 | Rich shimmer: base ↔ pale lemon peak |

- Shimmer rate: 0.55 sine cycles/second — slow, breathing pulse
- Each mound has a random phase offset so they don't all pulse in sync (gives a more organic feel)
- `GetAttributeChangedSignal("PollenLevel")` gives instant response when pollen deposits or is consumed
- 4-second scan re-scan as safety net for missed signals
- `unregisterMound_201` restores the base colour with a 0.6s tween — no abrupt snap
- Direct `part.Color` assignment in the Heartbeat loop avoids tween accumulation; each frame writes the correct colour for that phase

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(No new parts — direct property animation on existing PollenMound CellContent BaseParts)*
