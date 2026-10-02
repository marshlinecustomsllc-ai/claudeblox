# Dispatch 234 — Plot Flag Wind Animation
**File:** `cycle25_plot_flag_wind_dispatch.md`
**Cycle:** 25
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The 6 PlotFlag parts (added in the Shop expansion, each flagging a claimed plot) stand perfectly still. A garden flag that never moves in an outdoor meadow looks inert and artificial. This dispatch adds a **Plot Flag Wind Animation Controller**: a client-side LocalScript that drives a slow sinusoidal rotation oscillation on each `PlotFlag`-tagged Part's Y-axis, giving each flag a gentle, randomised rippling-in-the-breeze effect. Flags on claimed plots get a slightly livelier flutter than unclaimed ones.

For kids: the flags wave like real flags in the meadow — it feels alive and cheerful. For adults: the differentiated flutter speed subtly signals claim status without adding any new UI text.

---

## Step 1 — PlotFlagWindController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PlotFlagWindController`.

Paste exactly:

```lua
--!strict
-- PlotFlagWindController: gentle sinusoidal wind oscillation on PlotFlag-tagged parts.
-- Reads PlotOwner attribute to modulate flutter intensity by claim status.
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local CLAIMED_SPEED_234   = 0.55   -- oscillations per second (claimed plot, livelier)
local UNCLAIMED_SPEED_234 = 0.28   -- oscillations per second (unclaimed plot, gentle)
local MAX_ANGLE_234       = 14     -- degrees maximum rotation from base
local PHASE_STEP_234      = 0.72   -- radians phase offset per successive flag (staggered)
local SCAN_INTERVAL_234   = 8.0    -- seconds between scans for new flags
local BASE_OFFSET_RANGE_234 = 3.2  -- random base tilt range in degrees (natural variation)

-- ── Per-flag registry ─────────────────────────────────────────────────────────
local flagData_234: { [BasePart]: {
	baseRotation: CFrame,
	phase: number,
	baseTilt: number,   -- small random constant tilt
} } = {}

local phaseCounter_234 = 0

-- ── Register a flag ───────────────────────────────────────────────────────────
local function registerFlag_234(flag: BasePart)
	if flagData_234[flag] then return end
	local phase    = phaseCounter_234 * PHASE_STEP_234
	phaseCounter_234 += 1
	local baseTilt = (math.random() * BASE_OFFSET_RANGE_234) - (BASE_OFFSET_RANGE_234 / 2)
	flagData_234[flag] = {
		baseRotation = flag.CFrame,
		phase        = phase,
		baseTilt     = baseTilt,
	}
end

-- ── Heartbeat update ──────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(_dt: number)
	local t = os.clock()
	for flag, entry in flagData_234 do
		if not flag.Parent then
			flagData_234[flag] = nil
			continue
		end

		-- Determine claim state for flutter speed
		local owner = (flag:GetAttribute("PlotOwner") :: string?) or ""
		local speed = owner ~= "" and CLAIMED_SPEED_234 or UNCLAIMED_SPEED_234

		-- Sine wave oscillation on Y-axis (yaw / flag ripple)
		local wave   = math.sin(t * speed * math.pi * 2 + entry.phase)
		local angleY = wave * MAX_ANGLE_234 + entry.baseTilt

		-- Rotation relative to original CFrame to preserve world position
		flag.CFrame = entry.baseRotation * CFrame.Angles(0, math.rad(angleY), 0)
	end
end)

-- ── Scan ──────────────────────────────────────────────────────────────────────
local scanAcc_234 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_234 += dt
	if scanAcc_234 < SCAN_INTERVAL_234 then return end
	scanAcc_234 = 0
	for _, flag in CollectionService:GetTagged("PlotFlag") do
		if flag:IsA("BasePart") then registerFlag_234(flag) end
	end
	-- Prune removed flags
	for flag in flagData_234 do
		if not flag.Parent then flagData_234[flag] = nil end
	end
end)

CollectionService:GetInstanceAddedSignal("PlotFlag"):Connect(function(inst)
	if inst:IsA("BasePart") then
		task.delay(0.3, function() registerFlag_234(inst) end)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	for _, flag in CollectionService:GetTagged("PlotFlag") do
		if flag:IsA("BasePart") then registerFlag_234(flag) end
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PlotFlagWindController"))
```

---

## Step 3 — PlotService confirmation

The controller reads the `PlotOwner` attribute from each `PlotFlag` Part. Confirm that PlotService writes this attribute when a plot is claimed or released (this was specified in Dispatch 224):

```lua
-- In PlotService, on claim:
flagPart:SetAttribute("PlotOwner", player.Name)

-- In PlotService, on release:
flagPart:SetAttribute("PlotOwner", "")
```

If this is already done by the D224 integration, no change is needed.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PlotFlagWindController")
print("PlotFlagWindController:", c and c.ClassName or "MISSING")

-- Check flags exist
local CS = game:GetService("CollectionService")
local flags = CS:GetTagged("PlotFlag")
print("PlotFlag tagged:", #flags, "(expect 6)")

-- Check a flag is moving (CFrame should change between reads):
if flags[1] then
	local f = flags[1]
	local cf1 = f.CFrame
	task.wait(0.5)
	local cf2 = f.CFrame
	print("Flag moved:", cf1 ~= cf2)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| Flag state | Flutter speed | Effect |
|---|---|---|
| Unclaimed | 0.28 /s (~3.6s full cycle) | Gentle, lazy drift |
| Claimed | 0.55 /s (~1.8s full cycle) | Livelier ripple — plot feels active |
| My plot (owner = LocalPlayer) | 0.55 /s | Same as any claimed flag (visual parity) |

- PHASE_STEP_234 = 0.72 rad (≈ 41°) staggers all 6 flags so they never oscillate in sync
- BASE_OFFSET_RANGE_234 = ±1.6° random tilt on registration gives each flag a slightly different rest position
- Heartbeat CFrame write: cheap — one CFrame multiply per flag per frame, 6 total
- Preserves original world position — only rotation changes
- GetAttributeChangedSignal NOT needed here — speed difference is subtle; PlotOwner changes are infrequent and the Heartbeat reads it every frame already
- Works with any flag shape — the rotation is Y-axis only (yaw), so tall flags ripple, flat banners tilt

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(LocalScript only — no new instances)*
