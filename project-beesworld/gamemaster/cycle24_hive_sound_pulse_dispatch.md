# Dispatch 229 — Hive Sound Pulse
**File:** `cycle24_hive_sound_pulse_dispatch.md`
**Cycle:** 24
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The ambient hive buzz (from Dispatch 118 — Hive Sound Ambience) plays at a fixed volume regardless of how many bees are in the hive. This dispatch adds a **Hive Sound Pulse Controller**: a client-side LocalScript that modulates the `HiveAmbience` Sound's Volume and PlaybackSpeed based on the `CurrentBees` player attribute. A hive with 5 bees hums quietly; a hive at cap buzzes loudly with a slightly higher pitch. The transition is smooth via TweenService.

For kids: the hive *sounds* alive — quiet when empty, loud and buzzy when full. For adults: audio reinforces the population state without any UI.

---

## Step 1 — HiveSoundPulseController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HiveSoundPulseController`.

Paste exactly:

```lua
--!strict
-- HiveSoundPulseController: modulates hive ambient buzz volume + pitch with bee population.
-- Reads CurrentBees + MaxBees player attributes. Adjusts HiveAmbience Sound in workspace.
-- Entirely client-side — zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local TWEEN_TIME_229  = 2.5    -- seconds for volume/pitch transition
local MIN_VOLUME_229  = 0.08   -- volume at 0 bees
local MAX_VOLUME_229  = 0.55   -- volume at max bees
local MIN_PITCH_229   = 0.90   -- PlaybackSpeed at 0 bees
local MAX_PITCH_229   = 1.12   -- PlaybackSpeed at max bees
local SCAN_INTERVAL_229 = 8.0  -- seconds between sound re-discovery

-- Sound names to modulate (from Dispatch 118)
local SOUND_NAMES_229 = { "HiveAmbience", "HiveBuzz", "BeeAmbience" }

-- ── State ─────────────────────────────────────────────────────────────────────
local hiveSound_229: Sound? = nil
local lastFill_229 = -1   -- -1 forces first update

-- ── Find hive sound ───────────────────────────────────────────────────────────
local function findHiveSound_229(): Sound?
	-- Search workspace descendants for a looped sound matching SOUND_NAMES_229
	for _, name in SOUND_NAMES_229 do
		local found = workspace:FindFirstChild(name, true) :: Sound?
		if found and found:IsA("Sound") then return found end
	end
	-- Fallback: find any looped Sound in workspace with SoundGroup "Ambient"
	for _, obj in workspace:GetDescendants() do
		if obj:IsA("Sound") and obj.Looped and obj.Volume > 0 then
			local sg = obj:FindFirstAncestorOfClass("SoundGroup")
			if sg and sg.Name:lower():find("ambient") then return obj end
		end
	end
	return nil
end

-- ── Apply fill level (0–1) ────────────────────────────────────────────────────
local function applyFill_229(fill: number)
	if not hiveSound_229 then return end
	if math.abs(fill - lastFill_229) < 0.04 then return end
	lastFill_229 = fill

	local targetVol   = MIN_VOLUME_229   + fill * (MAX_VOLUME_229   - MIN_VOLUME_229)
	local targetPitch = MIN_PITCH_229    + fill * (MAX_PITCH_229    - MIN_PITCH_229)

	TweenService:Create(hiveSound_229, TweenInfo.new(TWEEN_TIME_229, Enum.EasingStyle.Sine), {
		Volume        = targetVol,
		PlaybackSpeed = targetPitch,
	}):Play()
end

-- ── Read attributes ───────────────────────────────────────────────────────────
local function readAndApply_229()
	local current = (player:GetAttribute("CurrentBees") :: number?) or 0
	local maxBees = (player:GetAttribute("MaxBees")     :: number?) or 0
	if maxBees <= 0 then
		applyFill_229(0)
		return
	end
	applyFill_229(math.clamp(current / maxBees, 0, 1))
end

-- ── Attribute signals ─────────────────────────────────────────────────────────
player:GetAttributeChangedSignal("CurrentBees"):Connect(readAndApply_229)
player:GetAttributeChangedSignal("MaxBees"):Connect(readAndApply_229)

-- ── Rescan heartbeat ──────────────────────────────────────────────────────────
local scanAcc_229 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_229 += dt
	if scanAcc_229 < SCAN_INTERVAL_229 then return end
	scanAcc_229 = 0
	if not hiveSound_229 then
		hiveSound_229 = findHiveSound_229()
		if hiveSound_229 then
			lastFill_229 = -1   -- force reapply
			readAndApply_229()
		end
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	hiveSound_229 = findHiveSound_229()
	readAndApply_229()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HiveSoundPulseController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HiveSoundPulseController")
print("HiveSoundPulseController:", c and c.ClassName or "MISSING")

-- Find the hive sound
for _, name in {"HiveAmbience", "HiveBuzz", "BeeAmbience"} do
	local s = workspace:FindFirstChild(name, true)
	if s and s:IsA("Sound") then
		print("Found:", s:GetFullName(), "Vol=" .. s.Volume, "Speed=" .. s.PlaybackSpeed)
	end
end

-- Simulate fill level change
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("CurrentBees", 0)
lp:SetAttribute("MaxBees", 24)
task.wait(3)
print("At 0 bees — buzz should be quiet")
lp:SetAttribute("CurrentBees", 24)
task.wait(3)
print("At max bees — buzz should be loud, higher pitch")
lp:SetAttribute("CurrentBees", 12)

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| CurrentBees / MaxBees | Volume | Pitch (PlaybackSpeed) |
|---|---|---|
| 0% (empty) | 0.08 (whisper) | 0.90 (low drone) |
| 25% (quarter) | 0.20 | 0.96 |
| 50% (half) | 0.32 | 1.01 |
| 75% (three-quarter) | 0.43 | 1.07 |
| 100% (at cap) | 0.55 (loud) | 1.12 (higher pitch) |

- TweenService Sine 2.5s — pitch/volume change is perceptible but not jarring
- 4% fill-change threshold prevents constant tiny tweens
- Searches workspace for HiveAmbience / HiveBuzz / BeeAmbience (D118 names) + fallback to any looped Ambient group sound
- 8s rescan self-heals if sound not loaded at init time
- Pairs with CombShimmerController (D228) — the hive both *looks* and *sounds* more alive as population grows
- Volume cap 0.55 keeps it below environmental audio dominance guideline (0.7 max from quality criteria)

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(LocalScript only — no new Sound objects, no BaseParts)*
