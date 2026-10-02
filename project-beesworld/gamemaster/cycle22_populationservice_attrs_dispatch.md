# Dispatch 222 — PopulationService Attribute Broadcast
**File:** `cycle22_populationservice_attrs_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

`PopCapController` (D211) reads `CurrentBees` and `MaxBees` to show the population cap warning pill. `CasteBadgeController` (D212) reads `ForagerCount`, `NurseCount`, and `GuardCount` to show the caste breakdown badge. Both are entirely client-side and depend on PopulationService writing these five player attributes. This dispatch is the server-side integration pass: add or confirm the attribute writes in PopulationService.

| Attribute | Type | Written by | Read by |
|---|---|---|---|
| `CurrentBees` | number | PopulationService | PopCapController (D211) |
| `MaxBees` | number | PopulationService | PopCapController (D211) |
| `ForagerCount` | number | PopulationService | CasteBadgeController (D212) |
| `NurseCount` | number | PopulationService | CasteBadgeController (D212) |
| `GuardCount` | number | PopulationService | CasteBadgeController (D212) |

Zero new parts — PopulationService Script edits only.

---

## Step 1 — Locate the population update function in PopulationService

Open **ServerScriptService → Systems → PopulationService**.

PopulationService manages the per-plot bee population. Find the function or loop that recalculates bee counts — it likely runs on a Heartbeat accumulator or fires when a cell is built/destroyed. It probably already computes `totalBees`, `maxBees`, and caste breakdown numbers internally. The goal is to write those computed values to player attributes so clients can display them reactively.

---

## Step 2 — Add the broadcast function

At the top of PopulationService (after services are declared), add:

```lua
-- ── Population attribute broadcast ───────────────────────────────────────────
local function broadcastPopulation_222(
	player: Player,
	currentBees: number,
	maxBees: number,
	foragers: number,
	nurses: number,
	guards: number
)
	player:SetAttribute("CurrentBees",  math.floor(currentBees))
	player:SetAttribute("MaxBees",      math.floor(maxBees))
	player:SetAttribute("ForagerCount", math.floor(foragers))
	player:SetAttribute("NurseCount",   math.floor(nurses))
	player:SetAttribute("GuardCount",   math.floor(guards))
end
```

---

## Step 3 — Wire broadcast into the population recalculation loop

Find the section of PopulationService that recomputes bee counts for a player's plot. After computing the final values, call:

```lua
-- After recalculating totals for a player's plot:
broadcastPopulation_222(
	player,
	totalBees,    -- replace with actual variable
	maxBees,      -- replace with actual variable
	foragerCount, -- replace with actual variable
	nurseCount,   -- replace with actual variable
	guardCount    -- replace with actual variable
)
```

If PopulationService uses a per-plot data table rather than direct variables, extract the values before calling:

```lua
local data = plotData[plotIndex]
if data then
	broadcastPopulation_222(
		player,
		data.currentBees or 0,
		data.maxBees or 0,
		data.foragers or 0,
		data.nurses or 0,
		data.guards or 0
	)
end
```

---

## Step 4 — Wire PlayerAdded for late joiners

Add a `PlayerAdded` handler so any player who joins while the game is running receives an initial zero-state immediately (PopulationService will overwrite it on the next recalculation):

```lua
game:GetService("Players").PlayerAdded:Connect(function(p: Player)
	broadcastPopulation_222(p, 0, 0, 0, 0, 0)
end)

-- Also broadcast to any players already in the server at script start:
for _, p in game:GetService("Players"):GetPlayers() do
	broadcastPopulation_222(p, 0, 0, 0, 0, 0)
end
```

---

## Step 5 — Caste cap hint (MaxBees derivation)

`MaxBees` is the cell-capacity ceiling for a plot. If it is not already computed, derive it as the total number of HiveCell-tagged cells in the player's plot multiplied by the per-cell bee capacity constant from Config:

```lua
-- If MaxBees is not yet tracked, compute it during the recalculation loop:
local cellCount = 0
for _, cell in plot:GetDescendants() do
	if game:GetService("CollectionService"):HasTag(cell, "HiveCell") then
		cellCount = cellCount + 1
	end
end
local maxBees = cellCount * (require(Config).BEES_PER_CELL or 3)
```

Replace `require(Config).BEES_PER_CELL` with the actual Config key if it has a different name in Config.lua.

---

## Step 6 — Verification sweep

Run in **Studio Command Bar** (in Play mode after building a few cells):

```lua
local lp = game:GetService("Players").LocalPlayer
print("CurrentBees:",  lp:GetAttribute("CurrentBees"))
print("MaxBees:",      lp:GetAttribute("MaxBees"))
print("ForagerCount:", lp:GetAttribute("ForagerCount"))
print("NurseCount:",   lp:GetAttribute("NurseCount"))
print("GuardCount:",   lp:GetAttribute("GuardCount"))
```

**Expected output (after building some Brood + Forager cells):**
```
CurrentBees:  9
MaxBees:      24
ForagerCount: 4
NurseCount:   3
GuardCount:   2
```

**Quick visual test:** After running the Command Bar check above, watch the HUD bottom-left. PopCapController pill should appear if `MaxBees - CurrentBees <= 3`. CasteBadgeController badge should update immediately showing caste counts.

**Simulate near-cap condition:**
```lua
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("CurrentBees", 22)
lp:SetAttribute("MaxBees", 24)
-- PopCapController pill should now appear (24-22=2 → within WARN_MARGIN 3)
task.wait(2)
lp:SetAttribute("CurrentBees", 24)
-- Pill should turn red (AT CAP)
task.wait(2)
lp:SetAttribute("CurrentBees", 18)
-- Pill should hide (24-18=6 → outside WARN_MARGIN)
```

---

## Behaviour summary

| Attribute | Default on join | Update trigger | Client display |
|---|---|---|---|
| `CurrentBees` | 0 | PopulationService recalc tick | PopCapController pill ("9 / 24 bees") |
| `MaxBees` | 0 | PopulationService recalc tick | PopCapController pill + percent bar |
| `ForagerCount` | 0 | PopulationService recalc tick | CasteBadgeController "F: 4" column |
| `NurseCount` | 0 | PopulationService recalc tick | CasteBadgeController "N: 3" column |
| `GuardCount` | 0 | PopulationService recalc tick | CasteBadgeController "G: 2" column |

- All five attributes initialise to 0 on PlayerAdded and are overwritten on first recalculation
- Server-authoritative: clients read only, never write
- Completes the attribute bus for D211 (PopCapController) and D212 (CasteBadgeController)
- Together with D214 (ResourceService), D216 (WeatherService), D221 (ThreatService), this finishes all server→client attribute bridges for the HUD cluster

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(PopulationService Script edits — no new parts)*
