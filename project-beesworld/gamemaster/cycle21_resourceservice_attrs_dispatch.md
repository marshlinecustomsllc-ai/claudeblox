# Dispatch 214 — ResourceService Attribute Writes
**File:** `cycle21_resourceservice_attrs_dispatch.md`
**Cycle:** 21
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Several client-side controllers written in dispatches 204–213 read part and player attributes that ResourceService and ForagingService must actively write. Currently those attributes may be absent, causing the visual controllers to display nothing. This dispatch adds the missing server-side attribute writes to **ResourceService** and **ForagingService**:

| Attribute | Part/Player | Controller | Dispatch |
|---|---|---|---|
| `RipenessLevel` (0–1) | HoneyBlob BasePart | HoneyGlowController | 204 |
| `NectarLevel` (0–1) | RouteBeam BasePart | NectarFlowController | 208 |
| `OutputRate` | CombCell BasePart | CellHoverController | 207 |
| `HoneyCount` | Player | HarvestBeaconController | 210 |

`CurrentBees`, `MaxBees`, `ForagerCount`, `NurseCount`, `GuardCount` are already covered in the PopulationService notes (dispatches 211–212). `CurrentSeason`/`CurrentWeather` are covered in the WeatherService note (dispatch 213). This dispatch focuses on ResourceService and ForagingService only.

Zero new parts — pure server Script edits.

---

## Step 1 — ResourceService additions

Open **ServerScriptService → Systems → ResourceService** and add the following attribute writes at the marked locations.

### 1a — RipenessLevel on HoneyBlob parts

Find the section where honey accumulates in a Honey cell (typically after a `StoredHoney` increment). Add:

```lua
-- After updating stored honey in a Honey cell:
-- honeyBlob is the HoneyBlob-tagged BasePart child of the Honey cell Model
local ripenessLevel = math.clamp(storedHoney / cell.capacity, 0, 1)
if honeyBlob then
	honeyBlob:SetAttribute("RipenessLevel", ripenessLevel)
end
```

If ResourceService tracks honey per-cell in a table, iterate after each update:

```lua
-- Full pass after any honey change on a plot:
local CS = game:GetService("CollectionService")
for _, blob in CS:GetTagged("HoneyBlob") do
	if blob:IsA("BasePart") and blob:GetAttribute("PlotIndex") == plotIndex then
		local stored = blob:GetAttribute("StoredHoney") or 0
		local capacity = blob:GetAttribute("Capacity") or 1
		blob:SetAttribute("RipenessLevel", math.clamp(stored / capacity, 0, 1))
	end
end
```

### 1b — HoneyCount on Player attribute

Find where `player:SetAttribute("HoneyCount", ...)` is written (should already exist from DataService v8+). Confirm it is written:
- After each honey harvest (HarvestController → ResourceService.Harvest)
- After each honey sale / spend
- On player join (from loaded data)

If missing, add after any honey total change:

```lua
player:SetAttribute("HoneyCount", playerData.honey or 0)
```

### 1c — OutputRate on CombCell parts

Find where CombService or ResourceService calculates per-cell production rate. After computing the rate, write it to the BasePart:

```lua
-- After calculating outputRate for a CombCell (honey/pollen per second):
combCellPart:SetAttribute("OutputRate", outputRate)
```

If the rate is only computed on demand (not stored), add a periodic broadcast — once per production tick is sufficient:

```lua
-- In the production loop (every ~5 seconds):
for _, cell in activeCells do
	if cell.part then
		cell.part:SetAttribute("OutputRate", cell.ratePerSecond)
	end
end
```

---

## Step 2 — ForagingService additions

Open **ServerScriptService → Systems → ForagingService** and add the following attribute writes.

### 2a — NectarLevel on RouteBeam parts

Find where nectar accumulates on a foraging route (after a forager returns, or during the flow tick). Add:

```lua
-- After updating nectar in transit on a route:
-- routeBeamPart is the RouteBeam-tagged BasePart for this route
local nectarLevel = math.clamp(inTransitNectar / route.maxCapacity, 0, 1)
if routeBeamPart then
	routeBeamPart:SetAttribute("NectarLevel", nectarLevel)
end
```

If ForagingService uses a separate route tracking table:

```lua
-- Periodic write (every 2–3 seconds, aligned with the foraging tick):
local CS = game:GetService("CollectionService")
for _, beam in CS:GetTagged("RouteBeam") do
	if beam:IsA("BasePart") then
		local routeId = beam:GetAttribute("RouteId")
		if routeId and activeRoutes[routeId] then
			local r = activeRoutes[routeId]
			beam:SetAttribute("NectarLevel", math.clamp(r.inTransit / r.maxCapacity, 0, 1))
		end
	end
end
```

When a route is deactivated (dance cancelled or forager dies), set NectarLevel to 0:

```lua
routeBeamPart:SetAttribute("NectarLevel", 0)
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar** (in Play mode, after at least one foraging cycle):

```lua
local CS = game:GetService("CollectionService")

-- Check HoneyBlob RipenessLevel
local blobs = CS:GetTagged("HoneyBlob")
print("HoneyBlob parts:", #blobs)
for i, blob in blobs do
	if i > 3 then print("  ...") break end
	local r = blob:GetAttribute("RipenessLevel")
	print("  " .. blob.Name .. " RipenessLevel=" .. tostring(r))
end

-- Check RouteBeam NectarLevel
local beams = CS:GetTagged("RouteBeam")
print("RouteBeam parts:", #beams)
for i, beam in beams do
	if i > 3 then print("  ...") break end
	local n = beam:GetAttribute("NectarLevel")
	print("  " .. beam.Name .. " NectarLevel=" .. tostring(n))
end

-- Check CombCell OutputRate
local cells = CS:GetTagged("CombCell")
print("CombCell parts:", #cells)
for i, cell in cells do
	if i > 3 then print("  ...") break end
	local r = cell:GetAttribute("OutputRate")
	print("  " .. cell.Name .. " OutputRate=" .. tostring(r))
end

-- Check Player HoneyCount
local lp = game:GetService("Players").LocalPlayer
print("Player HoneyCount:", lp:GetAttribute("HoneyCount"))
```

**Expected output (after at least one foraging cycle):**
```
HoneyBlob parts: 6+
  HoneyBlob_1 RipenessLevel=0.4   (or any 0–1 float)
RouteBeam parts: 6+
  RouteBeam_1 NectarLevel=0.2     (or any 0–1 float, 0 when no active route)
CombCell parts: 6+
  CombCell_1 OutputRate=0.05      (or similar small float)
Player HoneyCount: 0              (or banked honey total)
```

---

## Notes on integration order

These server-side writes power the following client-side controllers. The client controllers already handle the case where attributes are missing (they default gracefully), so there is no strict "must execute first" dependency — but the visual feedback improves immediately once these writes are live:

| Server write | Client controller | Visual effect |
|---|---|---|
| `RipenessLevel` on HoneyBlob | HoneyGlowController (D204) | Glowing amber blobs when cells are full |
| `NectarLevel` on RouteBeam | NectarFlowController (D208) | Scrolling nectar flow beam on active routes |
| `OutputRate` on CombCell | CellHoverController (D207) | Rate/s shown in cell hover tooltip |
| `HoneyCount` on Player | HarvestBeaconController (D210) | Pulsing harvest beacon above LandingBoard |

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Server Script edits only — no new parts, no new instances)*
