# Dispatch 209 — Propolis Seal Pulse
**File:** `cycle20_propolis_pulse_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

PropolisSeam CellContent parts sit at the outer ring of the comb grid and currently display as static dark-resin spheres. The architecture describes propolis as a living defensive material — the hive's "immune system" — that strengthens the outer ring and raises the cost of Wasp/Bear raids. This dispatch adds a **Propolis Seal Pulse**: a slow Heartbeat colour pulse on each `PropolisSeam`-tagged BasePart that cycles between dark resin and a warm amber glow, making the outer ring look alive and defended. When the plot's `PropCount` attribute is high (≥ 4 seals) the pulse brightens and speeds up slightly — the hive looks increasingly fortified. Entirely client-side — zero server writes.

---

## Step 1 — PropolisPulseController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PropolisPulseController`.

Paste exactly:

```lua
--!strict
-- PropolisPulseController: slow colour pulse on PropolisSeam CellContent parts.
-- Higher PropCount on the player's PlotRoot = brighter, faster pulse.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_209   = 6.0    -- seconds between full re-scans
local BASE_RATE_209       = 0.30   -- pulses per second at PropCount 0-3
local BOOST_RATE_209      = 0.48   -- pulses per second at PropCount >= FORTIFIED threshold

local FORTIFIED_COUNT_209 = 4      -- PropCount at which the fortified pulse kicks in

-- ── Palette ───────────────────────────────────────────────────────────────────
local PROP_DARK_209    = Color3.fromRGB( 60,  30,  10)    -- dark resin base
local PROP_GLOW_209    = Color3.fromRGB(160,  80,  20)    -- amber warmth (standard)
local PROP_BRIGHT_209  = Color3.fromRGB(200, 110,  30)    -- brighter glow when fortified

-- ── State ─────────────────────────────────────────────────────────────────────
-- Maps each PropolisSeam part → per-part phase offset (so seals don't all pulse in sync)
local seals_209: { [BasePart]: number } = {}

-- ── Fortified check ───────────────────────────────────────────────────────────
local function isFortified_209(): boolean
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, obj in CollectionService:GetTagged("PlotRoot") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			local count = (obj:GetAttribute("PropCount") :: number?) or 0
			return count >= FORTIFIED_COUNT_209
		end
	end
	return false
end

-- ── Full scan ─────────────────────────────────────────────────────────────────
local function scan_209()
	-- Clean stale refs
	for part, _ in seals_209 do
		if not part.Parent then
			seals_209[part] = nil
		end
	end
	-- Register new PropolisSeam parts
	for _, obj in CollectionService:GetTagged("PropolisSeam") do
		if obj:IsA("BasePart") and not seals_209[obj] then
			seals_209[obj] = math.random() * math.pi * 2   -- random phase offset
		end
	end
end

-- ── Heartbeat ─────────────────────────────────────────────────────────────────
local scanAcc_209      = 0
local globalTime_209   = 0
local fortifiedCache_209 = false
local fortifiedTick_209  = 0   -- time of last fortified re-check

RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_209    += dt
	globalTime_209 += dt
	fortifiedTick_209 += dt

	if scanAcc_209 >= SCAN_INTERVAL_209 then
		scanAcc_209 = 0
		scan_209()
	end

	-- Re-check fortified state every 2 seconds
	if fortifiedTick_209 >= 2 then
		fortifiedTick_209 = 0
		fortifiedCache_209 = isFortified_209()
	end

	local rate = fortifiedCache_209 and BOOST_RATE_209 or BASE_RATE_209
	local peakColor = fortifiedCache_209 and PROP_BRIGHT_209 or PROP_GLOW_209

	for part, phase in seals_209 do
		if not part.Parent then
			seals_209[part] = nil
			continue
		end
		local t = globalTime_209 * rate * math.pi * 2 + phase
		local alpha = (math.sin(t) + 1) * 0.5   -- 0..1
		part.Color = PROP_DARK_209:Lerp(peakColor, alpha)
	end
end)

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("PropolisSeam"):Connect(function(obj)
	if obj:IsA("BasePart") then
		task.wait(0.3)
		if not seals_209[obj] then
			seals_209[obj] = math.random() * math.pi * 2
		end
	end
end)

CollectionService:GetInstanceRemovedSignal("PropolisSeam"):Connect(function(obj)
	if obj:IsA("BasePart") then
		seals_209[obj] = nil
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	fortifiedCache_209 = isFortified_209()
	scan_209()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PropolisPulseController"))
```

---

## Step 3 — Attribute source (CombService / StructureService)

`PropolisPulseController` reads one attribute from `PlotRoot` BaseParts:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `PropCount` | number | CombService | Count of PropolisCell-type cells on this plot; updated each time a cell is built/removed |

If CombService doesn't yet write `PropCount`, add it to the post-build callback:

```lua
-- In CombService, after placing or removing a cell:
local propCount = 0
for _, c in plotCells do
	if c.cellType == "Propolis" then propCount += 1 end
end
plotRoot:SetAttribute("PropCount", propCount)
```

The controller reads this once every 2 seconds, so no signal connection needed — a periodic re-check is sufficient given propolis cells are placed slowly.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PropolisPulseController")
print("PropolisPulseController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  isFortified_209:", c.Source:find("isFortified_209") ~= nil)
	print("  FORTIFIED_COUNT_209:", c.Source:find("FORTIFIED_COUNT_209") ~= nil)
	print("  PropolisSeam tag:", c.Source:find("PropolisSeam") ~= nil)
	print("  PropCount attr:", c.Source:find("PropCount") ~= nil)
	print("  phase offset:", c.Source:find("math.random") ~= nil)
end

local CS = game:GetService("CollectionService")
local seals = CS:GetTagged("PropolisSeam")
print("PropolisSeam tagged parts:", #seals, "(0 in Edit mode — placed during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Tag a part as PropolisSeam and watch it pulse
local CS = game:GetService("CollectionService")
local plates = CS:GetTagged("DimCellPlate")
if plates[1] then
	CS:AddTag(plates[1], "PropolisSeam")
	task.wait(0.5)
	print("Tagged as PropolisSeam — should now pulse between dark resin and amber")
	-- Simulate fortified plot (4+ propolis seals)
	local roots = CS:GetTagged("PlotRoot")
	if roots[1] then
		roots[1]:SetAttribute("PropCount", 5)
		task.wait(2)
		print("PropCount=5 set — pulse should be brighter and faster")
	end
end
```

**Expected output:**
```
PropolisPulseController: LocalScript
  lines: 110+
  isFortified_209: true
  FORTIFIED_COUNT_209: true
  PropolisSeam tag: true
  PropCount attr: true
  phase offset: true
PropolisSeam tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| PropCount | Pulse rate | Peak colour | Feel |
|---|---|---|---|
| 0–3 (basic defence) | 0.30 pulses/sec | Amber `(160,80,20)` | Slow, subtle warmth |
| 4+ (fortified) | 0.48 pulses/sec | Bright amber `(200,110,30)` | Noticeably active, defended |

- All PropolisSeam parts pulse independently with random phase offsets — the outer ring looks organically alive, not robotically synchronised
- Dark base colour `(60,30,10)` matches the architecture's "dark resin" description for propolis
- Fortified threshold (PropCount ≥ 4) provides visible feedback that the hive's outer ring is meaningfully upgraded
- Visible from adjacent plots at peak brightness — other players can see a fortified hive at a glance
- Direct `part.Color` write each Heartbeat (no tween accumulation; same pattern as PollenSparkleController)

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Direct Color property writes on existing PropolisSeam CellContent BaseParts — no new parts)*
