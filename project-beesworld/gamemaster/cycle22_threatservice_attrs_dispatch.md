# Dispatch 221 — ThreatService Attribute Broadcast
**File:** `cycle22_threatservice_attrs_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

`BearWarningController` (D220), `MolassesController`, and `WaspAlertController` all read player attributes to drive their client visuals — but ThreatService currently calls `player:SetAttribute` only in some paths and may be missing writes in others. This dispatch is a **server-side integration pass** for ThreatService: confirm and, where absent, add the three attribute writes that the client controllers depend on.

| Attribute | Type | Written by | Read by |
|---|---|---|---|
| `ThreatStage` | number (0–6) | ThreatService | BearWarningController (D220), MolassesController |
| `WaspAlert` | boolean | WaspService | WaspAlertController |
| `SmokesRemaining` | number | ConsumableService / ThreatService | HudController (smoke charge display) |

Zero new parts — ThreatService + WaspService + ConsumableService Script edits only.

---

## Step 1 — ThreatStage broadcast in ThreatService

Open **ServerScriptService → Systems → ThreatService**.

Find every location where `currentStage` is updated (patience increases, decreases, or resets). After each change, add or confirm:

```lua
-- ── ThreatStage broadcast (add after every stage change) ──────────────────────
local function broadcastThreatStage_221(stage: number)
	for _, p in game:GetService("Players"):GetPlayers() do
		p:SetAttribute("ThreatStage", stage)
	end
end
```

Call `broadcastThreatStage_221(currentStage)` at:

1. **Patience increase** (bear grows angrier — player near ThreatZone, honey left ripe too long, etc.)
2. **Patience decrease** (smoker used, offering made — bear appeased)
3. **Stage 6 trigger** (bear charges — permanent fork begins)
4. **Reset** (bear banished or offering accepted — stage returns to 0)
5. **`Players.PlayerAdded`** — send current stage to any player who joins mid-session:

```lua
game:GetService("Players").PlayerAdded:Connect(function(p: Player)
	p:SetAttribute("ThreatStage", currentStage)
end)
```

**Locate the existing stage variable.** In the original ThreatService it is likely called `currentStage`, `patience`, or `molassesStage`. Replace `currentStage` in the snippet above with whatever name ThreatService uses.

---

## Step 2 — WaspAlert broadcast in WaspService

Open **ServerScriptService → Systems → WaspService**.

WaspAlertController reads `WaspAlert` (boolean). Add the broadcast function:

```lua
-- ── WaspAlert broadcast ───────────────────────────────────────────────────────
local function broadcastWaspAlert_221(active: boolean)
	for _, p in game:GetService("Players"):GetPlayers() do
		p:SetAttribute("WaspAlert", active)
	end
end
```

Call `broadcastWaspAlert_221(true)` when a wasp scout is spawned / swarm becomes active, and `broadcastWaspAlert_221(false)` when the swarm is repelled, guard bees win, or the scout despawns naturally.

Also wire `PlayerAdded` for WaspService so late-joining players get the current state:

```lua
game:GetService("Players").PlayerAdded:Connect(function(p: Player)
	p:SetAttribute("WaspAlert", waspActive)   -- replace waspActive with actual variable name
end)
```

---

## Step 3 — SmokesRemaining broadcast in ConsumableService / ThreatService

The smoker item (`smoker_refill` consumable) reduces ThreatStage and consumes a charge. `SmokesRemaining` should be written to the player attribute whenever charges change so the HUD can display it.

Open **ServerScriptService → Systems → ConsumableService** (or wherever smoker charges are tracked). Add:

```lua
-- ── SmokesRemaining broadcast ─────────────────────────────────────────────────
local function setSmokesRemaining_221(player: Player, count: number)
	player:SetAttribute("SmokesRemaining", math.max(count, 0))
end
```

Call `setSmokesRemaining_221(player, newCount)`:
- After a smoker is used (charge consumed)
- After `smoker_refill` consumable is purchased (charge added)
- On `PlayerAdded` — set initial value (0 if no smoker purchased yet)

```lua
game:GetService("Players").PlayerAdded:Connect(function(p: Player)
	-- Retrieve stored smoke count from DataService if available, else 0
	local storedSmokes = 0   -- replace with DataService load if smokes are persisted
	setSmokesRemaining_221(p, storedSmokes)
end)
```

---

## Step 4 — HudController: display SmokesRemaining

Open **StarterPlayerScripts → HudController**. In the section that renders the HUD, add a read of `SmokesRemaining` so the smoke charge count is visible:

```lua
-- In HudController, inside the attribute poll or update loop:
local smokes = (player:GetAttribute("SmokesRemaining") :: number?) or 0
-- Display as part of an existing HUD element, e.g. append to threat meter label:
-- threatLabel.Text = "Bear Stage " .. stage .. "  🫧 " .. smokes
```

If HudController has a dedicated smoke charge display area already, wire `GetAttributeChangedSignal("SmokesRemaining")` to update it reactively.

---

## Step 5 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
-- Simulate a stage change
local TS = game:GetService("ServerScriptService"):FindFirstChild("ThreatService", true)
print("ThreatService found:", TS ~= nil)

-- Check player attributes exist
local lp = game:GetService("Players").LocalPlayer
print("ThreatStage:", lp:GetAttribute("ThreatStage"))
print("WaspAlert:", lp:GetAttribute("WaspAlert"))
print("SmokesRemaining:", lp:GetAttribute("SmokesRemaining"))
```

**Quick simulation test (in Play mode Command Bar):**
```lua
-- Test BearWarningController by directly setting ThreatStage
local lp = game:GetService("Players").LocalPlayer
for i = 0, 6 do
	lp:SetAttribute("ThreatStage", i)
	task.wait(2)
	print("Stage", i, "— vignette should be", i >= 3 and "visible" or "hidden")
end
```

**Expected output:**
```
ThreatService found: true
ThreatStage: 0          (or current bear stage)
WaspAlert: false        (or true if wasps active)
SmokesRemaining: 0      (or N if player has smoker)
```

**Verify ThreatService broadcast:**
```lua
-- In Studio Command Bar, after changing stage manually:
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("ThreatStage", 4)
task.wait(0.1)
-- BearWarningController should now show medium pulse + trigger one rumble
print("ThreatStage confirmed:", lp:GetAttribute("ThreatStage"))
```

---

## Behaviour summary

| Attribute | When written | Client consumer |
|---|---|---|
| `ThreatStage` | Every patience change + PlayerAdded | BearWarningController (D220) — vignette + rumble |
| `WaspAlert` | Wasp scout spawn/despawn + PlayerAdded | WaspAlertController — wasp warning UI |
| `SmokesRemaining` | Smoker use/purchase + PlayerAdded | HudController — smoke charge display |

- Mirrors the pattern of D214 (ResourceService attribute writes) and D216 (WeatherService broadcasts)
- PlayerAdded handlers ensure late-joining players start with correct attribute values
- All broadcasts are server-authoritative — clients only read, never write these attributes
- Combining with D220 (BearWarningController) completes the full bear threat signal chain: ThreatService stage → player attribute → vignette pulse + rumble → visceral danger signal for kids and adults

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(ThreatService + WaspService + ConsumableService Script edits — no new parts)*
