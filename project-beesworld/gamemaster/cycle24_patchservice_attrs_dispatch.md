# Dispatch 231 — PatchService Attribute Writes
**File:** `cycle24_patchservice_attrs_dispatch.md`
**Cycle:** 24
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

FlowerBloomController (Dispatch 230) reads `PatchNectarLevel` (0–1) and `PatchRegenSecondsLeft` (number) from `FlowerPatch`-tagged Parts. Without server-side writes those attributes are never set, so all 18 patches stay at default colour. This dispatch adds the **PatchService attribute writes** — small additions to the existing regeneration loop that broadcast each patch's state to every client in real time. No new services, no new parts, no new RemoteEvents needed.

For kids: patches now visually communicate "I'm empty" or "I'm almost ready" automatically. For adults: route planning uses precise countdown data from the server's regen clock.

---

## Step 1 — Locate PatchService (or ForagingService)

Open **ServerScriptService → Systems** and find the script that:
- manages the 18 `FlowerPatch`-tagged parts
- tracks how much nectar each patch has
- runs the regen timer that refills depleted patches

The script is most likely named one of: `PatchService`, `ForagingService`, `NectarService`, or it may be a section inside a combined `WorldService`. Check with the Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local systems = SSS:FindFirstChild("Systems")
print("Systems children:")
for _, child in systems:GetChildren() do
  print(" ", child.ClassName, child.Name)
end
```

Identify the script that contains `FlowerPatch` tag usage or nectar/regen variables.

---

## Step 2 — Add the attribute write helpers

Inside the identified script, add the following helper function near the top of the module (after the `local` declarations, before the main loop):

```lua
-- ── Attribute broadcast to FlowerBloomController (D231) ──────────────────────
local function broadcastPatchState_231(patchPart: BasePart, currentNectar: number, maxNectar: number, regenSecsLeft: number)
	local level = if maxNectar > 0 then math.clamp(currentNectar / maxNectar, 0, 1) else 1
	patchPart:SetAttribute("PatchNectarLevel",      level)
	patchPart:SetAttribute("PatchRegenSecondsLeft", math.max(regenSecsLeft, 0))
end
```

---

## Step 3 — Wire the writes into the regen loop

Locate the regen loop — it likely looks like one of these patterns:

**Pattern A — accumulator-based regen (most common):**

```lua
-- Existing code (example — your variable names may differ):
patchData.regenAcc += dt
if patchData.regenAcc >= Config.PATCH_REGEN_TIME then
    patchData.regenAcc = 0
    patchData.nectar = patchData.maxNectar
end
```

Add the broadcast call immediately **after** updating `regenAcc` and **after** any nectar change:

```lua
patchData.regenAcc += dt
if patchData.regenAcc >= Config.PATCH_REGEN_TIME then
    patchData.regenAcc = 0
    patchData.nectar = patchData.maxNectar
end
-- ── D231: broadcast state to FlowerBloomController ───────────────────────────
local regenLeft = math.max(Config.PATCH_REGEN_TIME - patchData.regenAcc, 0)
broadcastPatchState_231(patchData.part, patchData.nectar, patchData.maxNectar, regenLeft)
```

**Pattern B — timestamp-based regen:**

```lua
-- Existing code (example):
if os.time() >= patchData.regenAt then
    patchData.nectar = patchData.maxNectar
    patchData.regenAt = 0
end
```

Add:

```lua
-- ── D231: broadcast state to FlowerBloomController ───────────────────────────
local regenLeft = patchData.regenAt > 0 and math.max(patchData.regenAt - os.time(), 0) or 0
broadcastPatchState_231(patchData.part, patchData.nectar, patchData.maxNectar, regenLeft)
```

---

## Step 4 — Wire the writes at depletion time

When a forager successfully collects nectar from a patch (nectar decreases), also call the broadcast immediately — this gives an instant colour change on the client without waiting for the regen loop tick:

```lua
-- Existing code: nectar collection / depletion
patchData.nectar = math.max(patchData.nectar - amountTaken, 0)
-- ── D231: instant broadcast on depletion ─────────────────────────────────────
local regenLeft = patchData.nectar < patchData.maxNectar and Config.PATCH_REGEN_TIME or 0
broadcastPatchState_231(patchData.part, patchData.nectar, patchData.maxNectar, regenLeft)
```

---

## Step 5 — Initial write on server start

At the bottom of the PatchService `init` or setup section (after all 18 patches are registered), write the initial state for each patch so clients that join mid-session get correct colours immediately:

```lua
-- ── D231: initial state broadcast on server start ────────────────────────────
task.delay(2, function()
	for _, patchData in patchTable do   -- iterate your patch registry
		local regenLeft = 0
		if patchData.nectar < patchData.maxNectar and Config.PATCH_REGEN_TIME then
			regenLeft = math.max(Config.PATCH_REGEN_TIME - (patchData.regenAcc or 0), 0)
		end
		broadcastPatchState_231(patchData.part, patchData.nectar, patchData.maxNectar, regenLeft)
	end
end)
```

---

## Step 6 — Update frequency note

The regen loop in most games runs on a `RunService.Heartbeat` or a `task.wait(1)` loop. The attribute write is cheap (one per patch per tick), so calling it every loop iteration is fine.

If the regen loop runs on a slow timer (e.g. every 5s), add a faster dedicated broadcast for the countdown label accuracy:

```lua
-- Optional: dedicated 3-second broadcast tick for countdown accuracy
task.spawn(function()
	while true do
		task.wait(3)
		for _, patchData in patchTable do
			local regenLeft = patchData.nectar < patchData.maxNectar
				and math.max(Config.PATCH_REGEN_TIME - (patchData.regenAcc or 0), 0)
				or 0
			patchData.part:SetAttribute("PatchRegenSecondsLeft", regenLeft)
		end
	end
end)
```

---

## Step 7 — Verification sweep

Run in **Studio Command Bar** (Edit mode):

```lua
-- Verify FlowerPatch tags exist
local CS = game:GetService("CollectionService")
local patches = CS:GetTagged("FlowerPatch")
print("FlowerPatch count:", #patches, "(expect 18)")

-- Check attributes on first patch (after Play mode + a few seconds)
-- Run this in Play mode after starting:
if patches[1] then
	local p = patches[1]
	print("PatchNectarLevel:", p:GetAttribute("PatchNectarLevel"))
	print("PatchRegenSecondsLeft:", p:GetAttribute("PatchRegenSecondsLeft"))
end
```

**Quick-test (in Play mode) — simulate depletion and watch colour change:**

```lua
-- Force a patch depleted to see FlowerBloomController respond:
local CS = game:GetService("CollectionService")
local patches = CS:GetTagged("FlowerPatch")
if patches[1] then
	local p = patches[1]
	p:SetAttribute("PatchNectarLevel", 0.05)
	p:SetAttribute("PatchRegenSecondsLeft", 60)
	-- Wait 2s — patch should turn grey-green with ⏱ 60s label
	task.wait(2)
	p:SetAttribute("PatchNectarLevel", 0.40)
	p:SetAttribute("PatchRegenSecondsLeft", 0)
	-- Wait 2s — patch should shift to mid-green, timer hidden
	task.wait(2)
	p:SetAttribute("PatchNectarLevel", 1.0)
	-- Patch should be vivid lavender-pink
end
```

---

## Behaviour summary

| Event | Attribute written | Client effect (D230) |
|---|---|---|
| Forager collects nectar | PatchNectarLevel decreases | Patch colour begins shifting grey-green |
| Regen running | PatchRegenSecondsLeft counts down | ⏱ countdown visible above patch |
| Regen completes | PatchNectarLevel = 1, SecsLeft = 0 | Patch tweens to lavender-pink, timer hides |
| Server start | Both attributes initialised | Late-joining clients get correct colours |

- broadcastPatchState_231 is a single 2-line function — minimal footprint in the service
- Attribute writes are replicated automatically by Roblox — no RemoteEvents needed
- Works whether PatchService uses accumulator or timestamp regen pattern
- Completes the FlowerPatch visual loop: D230 (client colours + timer) + D231 (server data feed)

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(Script edits only — no new instances)*
