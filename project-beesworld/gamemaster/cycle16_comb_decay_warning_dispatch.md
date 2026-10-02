# Dispatch 177 — Comb Stagnation Warning
**File:** `cycle16_comb_decay_warning_dispatch.md`
**Cycle:** 16
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Honey cells that have been full but unharvested for a long time create a real tycoon tension — the ripeness system rewards waiting, but waiting too long risks Old Molasses raiding. Currently, players have no visible signal that their cells are "very ripe" versus just "full." This dispatch adds a **Comb Stagnation Warning**: when a player has had honey cells filled above 80% capacity for 5+ minutes without harvesting, a gentle amber warning appears on the HiveGui — "🍯 Your cells are very ripe — harvest soon!" Kids see urgency; adults understand Old Molasses risk and the ripeness curve.

This is a **pure client-side polish** dispatch. No server code needed — the client already has `HoneyCount`, `HoneyCapacity`, and the `HarvestComplete` RemoteEvent to reset the timer.

---

## Step 1 — CombStagnationController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `CombStagnationController`.

Paste exactly:

```lua
--!strict
-- CombStagnationController: warns when honey cells have been very ripe for 5+ minutes.
-- Tracks fill level via HoneyCount/HoneyCapacity player attributes.
-- Resets timer on HarvestComplete or when fill drops below threshold.
-- Entirely client-side — no RemoteEvents sent.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local RIPE_THRESHOLD_177  = 0.80   -- fill fraction above which cells count as "very ripe"
local STAGNATION_TIME_177 = 300    -- seconds (5 min) at >threshold before warning
local POLL_INTERVAL_177   = 10     -- seconds between fill checks
local WARNING_PULSE_177   = 3.0    -- seconds per glow cycle on warning pill

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_177  = Color3.fromRGB(242, 168, 28)
local AMBER_177       = Color3.fromRGB(255, 150, 20)
local WAX_CREAM_177   = Color3.fromRGB(232, 212, 154)
local DARK_BG_177     = Color3.fromRGB(30,  18,  8)
local RED_WARN_177    = Color3.fromRGB(230, 100, 30)

-- ── Build warning pill ────────────────────────────────────────────────────────
local function buildWarningPill_177(): (ScreenGui, Frame, TextLabel)
	-- Attach to HiveGui if available; own ScreenGui otherwise
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	local parentGui: ScreenGui
	if hiveGui then
		parentGui = hiveGui
	else
		local sg = Instance.new("ScreenGui")
		sg.Name           = "CombStagnationGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 19
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui
		parentGui = sg
	end

	local pill = Instance.new("Frame")
	pill.Name              = "StagnationPill"
	pill.Size              = UDim2.new(0, 220, 0, 30)
	-- Centre-top, just below weather pill
	pill.Position          = UDim2.new(0.5, -110, 0, 48)
	pill.BackgroundColor3  = DARK_BG_177
	pill.BorderSizePixel   = 0
	pill.Visible           = false
	pill.ZIndex            = 35
	pill.Parent            = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color     = AMBER_177
	stroke.Thickness = 1.5
	stroke.Parent    = pill

	local label = Instance.new("TextLabel")
	label.Name               = "PillLabel"
	label.Size               = UDim2.new(1, -8, 1, 0)
	label.Position           = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text               = "🍯 Cells very ripe — harvest soon!"
	label.TextSize           = 12
	label.Font               = Enum.Font.GothamBold
	label.TextColor3         = HONEY_GOLD_177
	label.TextXAlignment     = Enum.TextXAlignment.Center
	label.ZIndex             = 36
	label.Parent             = pill

	return parentGui, pill, label
end

-- ── State ─────────────────────────────────────────────────────────────────────
local _, warningPill_177, pillLabel_177 = buildWarningPill_177()
local warnShowing_177    = false
local ripeStartTime_177: number? = nil   -- tick() when cells first went > threshold
local pulseConn_177: RBXScriptConnection? = nil
local pulseT_177 = 0

-- ── Pulse glow on warning pill ────────────────────────────────────────────────
local function startPillPulse_177()
	if pulseConn_177 then return end
	pulseConn_177 = RunService.Heartbeat:Connect(function(dt)
		pulseT_177 = pulseT_177 + dt
		local phase = math.sin(pulseT_177 * (2 * math.pi / WARNING_PULSE_177)) * 0.5 + 0.5
		-- Pulse between AMBER and RED_WARN
		local r = AMBER_177.R + (RED_WARN_177.R - AMBER_177.R) * phase
		local g = AMBER_177.G + (RED_WARN_177.G - AMBER_177.G) * phase
		local b = AMBER_177.B + (RED_WARN_177.B - AMBER_177.B) * phase
		local stroke = warningPill_177:FindFirstChildOfClass("UIStroke") :: UIStroke?
		if stroke then stroke.Color = Color3.new(r, g, b) end
	end)
end

local function stopPillPulse_177()
	if pulseConn_177 then
		pulseConn_177:Disconnect()
		pulseConn_177 = nil
	end
	-- Restore stroke
	local stroke = warningPill_177:FindFirstChildOfClass("UIStroke") :: UIStroke?
	if stroke then stroke.Color = AMBER_177 end
end

-- ── Show / hide warning ───────────────────────────────────────────────────────
local function showWarning_177()
	if warnShowing_177 then return end
	warnShowing_177 = true

	warningPill_177.Visible = true
	warningPill_177.Size = UDim2.new(0, 0, 0, 30)
	TweenService:Create(warningPill_177,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 220, 0, 30) }):Play()

	startPillPulse_177()
end

local function hideWarning_177()
	if not warnShowing_177 then return end
	warnShowing_177 = false
	stopPillPulse_177()
	ripeStartTime_177 = nil

	TweenService:Create(warningPill_177,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.new(0, 0, 0, 30) }):Play()
	task.delay(0.25, function()
		warningPill_177.Visible = false
	end)
end

-- ── Poll fill level ───────────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(POLL_INTERVAL_177)

		local honey   = player:GetAttribute("HoneyCount")    :: number?
		local cap     = player:GetAttribute("HoneyCapacity") :: number?
		if not honey or not cap or cap <= 0 then continue end

		local fill = honey / cap

		if fill >= RIPE_THRESHOLD_177 then
			-- Cells are very ripe
			if not ripeStartTime_177 then
				ripeStartTime_177 = tick()
			elseif tick() - ripeStartTime_177 >= STAGNATION_TIME_177 then
				showWarning_177()
			end
		else
			-- Fill dropped below threshold — reset
			if ripeStartTime_177 then
				ripeStartTime_177 = nil
				hideWarning_177()
			end
		end
	end
end)

-- ── Reset on harvest ──────────────────────────────────────────────────────────
local harvestComplete = Remotes:FindFirstChild("HarvestComplete") :: RemoteEvent?
if harvestComplete then
	harvestComplete.OnClientEvent:Connect(function()
		ripeStartTime_177 = nil
		hideWarning_177()
	end)
end

-- Also reset when HoneyCount attribute drops (covers partial harvest / consumption)
player:GetAttributeChangedSignal("HoneyCount"):Connect(function()
	local honey = player:GetAttribute("HoneyCount") :: number?
	local cap   = player:GetAttribute("HoneyCapacity") :: number?
	if not honey or not cap or cap <= 0 then return end
	if honey / cap < RIPE_THRESHOLD_177 then
		ripeStartTime_177 = nil
		hideWarning_177()
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("CombStagnationController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("CombStagnationController")
print("CombStagnationController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  RIPE_THRESHOLD_177:", c.Source:find("RIPE_THRESHOLD_177") ~= nil)
	print("  showWarning_177:", c.Source:find("showWarning_177") ~= nil)
	print("  HarvestComplete listener:", c.Source:find("HarvestComplete") ~= nil)
	print("  pulse loop:", c.Source:find("startPillPulse_177") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
CombStagnationController: LocalScript
  lines: 170+
  RIPE_THRESHOLD_177: true
  showWarning_177: true
  HarvestComplete listener: true
  pulse loop: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Warning pill |
|-------|-------------|
| Fill < 80% | Hidden |
| Fill ≥ 80%, < 5 min | Hidden (timer running silently) |
| Fill ≥ 80%, ≥ 5 min | Pill appears — "🍯 Cells very ripe — harvest soon!" |
| Pill pulse | UIStroke pulses AMBER→RED_WARN on 3s sine cycle |
| Harvest event fires | Pill hides immediately, timer resets |
| HoneyCount drops below 80% cap | Pill hides, timer resets |
| Poll cadence | Every 10s (light overhead) |
| Old Molasses synergy | Warning means player is also at peak Molasses raid risk |

**Part budget: +0 permanent → 4,204 / 5,000**
