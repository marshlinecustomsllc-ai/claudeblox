# Dispatch 235 — Landing Board Activity Pulse
**File:** `cycle25_landing_board_pulse_dispatch.md`
**Cycle:** 25
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

Each of the 6 plots has a **Landing Board** — the small horizontal platform at the hive entrance where bees come and go (from the Honey Harvesting system). The landing boards currently sit static. This dispatch adds a **Landing Board Activity Pulse**: a client-side LocalScript that drives a gentle colour oscillation on `LandingBoard`-tagged Parts, pulsing between resting amber and active golden-white at a rate that scales with the forager population. A plot with 0 foragers is dim and still; a busy foraging plot glows and throbs.

For kids: the hive entrance looks alive — you can tell which plots are busy and which are sleeping. For adults: landing board pulse rate is a quick visual indicator of foraging activity without opening any UI.

---

## Step 1 — LandingBoardPulseController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `LandingBoardPulseController`.

Paste exactly:

```lua
--!strict
-- LandingBoardPulseController: colour pulse on LandingBoard-tagged parts.
-- Pulse rate scales with ForagerCount player attribute.
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
-- Pulse speed range (oscillations per second)
local PULSE_IDLE_235    = 0.10   -- 0 foragers — very slow, barely noticeable
local PULSE_ACTIVE_235  = 0.70   -- max foragers — vivid rhythmic pulse

-- Colour range
local COLOR_REST_235    = Color3.fromRGB(160, 100,  30)   -- dim amber
local COLOR_ACTIVE_235  = Color3.fromRGB(255, 220,  90)   -- bright honey gold

-- Forager cap used for normalisation (should match Config.MAX_FORAGERS or similar)
local FORAGER_CAP_235   = 12

local SCAN_INTERVAL_235 = 8.0   -- seconds between scans for new boards

-- ── Per-board registry ────────────────────────────────────────────────────────
local boardData_235: { [BasePart]: {
	phase: number,
	originalColor: Color3,
} } = {}

local phaseCounter_235 = 0

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function getForagerFill_235(): number
	local f = (localPlayer:GetAttribute("ForagerCount") :: number?) or 0
	return math.clamp(f / FORAGER_CAP_235, 0, 1)
end

-- ── Register a board ──────────────────────────────────────────────────────────
local function registerBoard_235(board: BasePart)
	if boardData_235[board] then return end
	local phase = phaseCounter_235 * 1.05   -- ~1 radian offset per board
	phaseCounter_235 += 1
	boardData_235[board] = {
		phase         = phase,
		originalColor = board.Color,
	}
end

-- ── Heartbeat update ──────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(_dt: number)
	local t    = os.clock()
	local fill = getForagerFill_235()
	local speed = PULSE_IDLE_235 + fill * (PULSE_ACTIVE_235 - PULSE_IDLE_235)

	for board, entry in boardData_235 do
		if not board.Parent then
			boardData_235[board] = nil
			continue
		end

		local wave  = (math.sin(t * speed * math.pi * 2 + entry.phase) + 1) * 0.5
		board.Color = COLOR_REST_235:Lerp(COLOR_ACTIVE_235, wave * fill)
	end
end)

-- ── Scan ─────────────────────────────────────────────────────────────────────
local scanAcc_235 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_235 += dt
	if scanAcc_235 < SCAN_INTERVAL_235 then return end
	scanAcc_235 = 0
	for _, board in CollectionService:GetTagged("LandingBoard") do
		if board:IsA("BasePart") then registerBoard_235(board) end
	end
	for board in boardData_235 do
		if not board.Parent then boardData_235[board] = nil end
	end
end)

CollectionService:GetInstanceAddedSignal("LandingBoard"):Connect(function(inst)
	if inst:IsA("BasePart") then
		task.delay(0.3, function() registerBoard_235(inst) end)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	for _, board in CollectionService:GetTagged("LandingBoard") do
		if board:IsA("BasePart") then registerBoard_235(board) end
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("LandingBoardPulseController"))
```

---

## Step 3 — Tag the Landing Board parts

The 6 Landing Board parts (one per plot, parented inside each plot's hive model) need the `LandingBoard` CollectionService tag. Open the **Tag Editor** in Studio and tag each part, or run in the Studio Command Bar:

```lua
-- Find and tag Landing Board parts in all plots
local CS = game:GetService("CollectionService")
local tagged = 0
for _, obj in game:GetService("Workspace"):GetDescendants() do
	if obj:IsA("BasePart") and (obj.Name == "LandingBoard" or obj.Name:find("Landing")) then
		if not CS:HasTag(obj, "LandingBoard") then
			CS:AddTag(obj, "LandingBoard")
			tagged += 1
			print("Tagged:", obj:GetFullName())
		end
	end
end
print("Total tagged:", tagged)
```

Confirm 6 parts are tagged (one per plot).

---

## Step 4 — PopulationService confirmation

The controller reads `ForagerCount` from the local player. Dispatch 222 adds this attribute write to PopulationService. No additional change needed if D222 is already executed.

---

## Step 5 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("LandingBoardPulseController")
print("LandingBoardPulseController:", c and c.ClassName or "MISSING")

local CS = game:GetService("CollectionService")
local boards = CS:GetTagged("LandingBoard")
print("LandingBoard tagged:", #boards, "(expect 6)")

-- Simulate forager activity
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("ForagerCount", 0)
task.wait(2)
print("At 0 foragers — boards should be dim amber, barely moving")
lp:SetAttribute("ForagerCount", 12)
task.wait(2)
print("At 12 foragers — boards should be pulsing bright gold rapidly")
lp:SetAttribute("ForagerCount", 6)

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| ForagerCount | Pulse speed | Colour range | Effect |
|---|---|---|---|
| 0 | 0.10 /s (10s cycle) | Pinned to dim amber | Hive sleeping, no movement |
| 6 (half) | 0.40 /s (2.5s cycle) | Amber → moderate gold | Moderate activity |
| 12 (full) | 0.70 /s (1.4s cycle) | Amber → bright honey gold | Busy hive, vivid pulse |

- `wave * fill` coupling: at 0 foragers the colour is clamped to COLOR_REST_235 regardless of wave — no flicker on an idle hive
- Phase 1.05 rad (~60°) between boards means all 6 boards pulse out of sync
- Color property write per frame — cheap for 6 parts
- Reads ForagerCount, not total CurrentBees — foragers are the ones physically using the landing board, so it's semantically accurate
- Pairs with CombShimmerController (D228) and HiveSoundPulseController (D229) to give hive a fully reactive feel: the cells shimmer, the sound throbs, the landing board pulses

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(LocalScript only — no new instances)*
