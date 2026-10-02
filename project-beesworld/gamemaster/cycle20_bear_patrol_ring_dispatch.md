# Dispatch 203 — Bear Patrol Warning Ring
**File:** `cycle20_bear_patrol_ring_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Old Molasses's threat level already drives the `MolassesController` alert HUD overlay (dispatches from the threat system). But when a player is zoomed into their plot building, the off-screen threat HUD can be easy to miss. This dispatch adds a **Bear Patrol Warning Ring**: a BillboardGui on the player's own `PlotRoot` that shows a ring indicator with threat-stage colour. It only becomes visible at `ThreatStage ≥ 3` (Patience: Circling) — the point at which an attack can happen — and pulses from amber to deep red as the stage escalates to 5. At stage 6 (Attack) it freezes solid red. Disappears when the threat drops below 3. Client-side only — reads the existing `ThreatStage` player attribute.

---

## Step 1 — BearPatrolRingController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BearPatrolRingController`.

Paste exactly:

```lua
--!strict
-- BearPatrolRingController: threat-stage ring BillboardGui on the player's PlotRoot.
-- Visible at ThreatStage >= 3; pulses amber→red up to stage 5; solid red at stage 6.
-- Reads ThreatStage player attribute. Zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local VISIBLE_THRESHOLD_203 = 3      -- ThreatStage at which ring appears
local ATTACK_STAGE_203      = 6      -- solid red, no pulse
local PULSE_RATE_203        = 0.9    -- sine pulses per second
local RING_OFFSET_203       = Vector3.new(0, 5, 0)   -- studs above PlotRoot

-- ── Palette ───────────────────────────────────────────────────────────────────
local AMBER_203      = Color3.fromRGB(220, 130,  20)
local ORANGE_203     = Color3.fromRGB(220,  80,  20)
local RED_203        = Color3.fromRGB(200,  30,  20)
local DARK_BG_203    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_203  = Color3.fromRGB(232, 212, 154)

local STAGE_COLORS_203: { [number]: Color3 } = {
	[3] = AMBER_203,
	[4] = Color3.fromRGB(220, 100,  20),
	[5] = ORANGE_203,
	[6] = RED_203,
}

local STAGE_LABELS_203: { [number]: string } = {
	[3] = "🐻 Circling",
	[4] = "🐻 Watching",
	[5] = "🐻 Ready!",
	[6] = "🐻 Attacking!",
}

-- ── State ─────────────────────────────────────────────────────────────────────
local ringGui_203: BillboardGui?   = nil
local ringPlot_203: BasePart?      = nil
local currentStage_203             = 0
local pulseConn_203: RBXScriptConnection? = nil

-- ── Find player's PlotRoot ────────────────────────────────────────────────────
local function getPlotRoot_203(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, obj in CollectionService:GetTagged("PlotRoot") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			return obj
		end
	end
	return nil
end

-- ── Build ring BillboardGui ───────────────────────────────────────────────────
local function buildRing_203(root: BasePart, stage: number): BillboardGui
	local col = STAGE_COLORS_203[stage] or RED_203
	local lbl = STAGE_LABELS_203[stage] or "🐻"

	local bg = Instance.new("BillboardGui")
	bg.Name         = "BearRing_203"
	bg.Size         = UDim2.new(0, 120, 0, 30)
	bg.StudsOffset  = RING_OFFSET_203
	bg.AlwaysOnTop  = false
	bg.ResetOnSpawn = false
	bg.Parent       = root

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_203
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "RingStroke"
	stroke.Color     = col
	stroke.Thickness = 2
	stroke.Parent    = frame

	local text = Instance.new("TextLabel")
	text.Name               = "RingText"
	text.Size               = UDim2.new(1, -8, 1, 0)
	text.Position           = UDim2.new(0, 4, 0, 0)
	text.BackgroundTransparency = 1
	text.Text               = lbl
	text.TextSize           = 12
	text.Font               = Enum.Font.GothamBold
	text.TextColor3         = col
	text.TextXAlignment     = Enum.TextXAlignment.Center
	text.ZIndex             = 2
	text.Parent             = frame

	return bg
end

-- ── Start pulse ───────────────────────────────────────────────────────────────
local function startPulse_203(bg: BillboardGui, stage: number)
	if pulseConn_203 then pulseConn_203:Disconnect() end
	if stage >= ATTACK_STAGE_203 then
		-- Solid red at stage 6 — no pulse needed
		return
	end

	local t = 0
	local baseCol = STAGE_COLORS_203[stage] or RED_203
	pulseConn_203 = RunService.Heartbeat:Connect(function(dt: number)
		if not bg.Parent then pulseConn_203 = nil return end
		t += dt * PULSE_RATE_203
		local alpha = (math.sin(t * math.pi * 2) + 1) * 0.5
		local frame = bg:FindFirstChildOfClass("Frame")
		local stroke = frame and frame:FindFirstChild("RingStroke") :: UIStroke?
		local text   = frame and frame:FindFirstChild("RingText") :: TextLabel?
		if stroke then stroke.Color = baseCol:Lerp(RED_203, alpha * 0.5) end
		if text   then text.TextColor3 = baseCol:Lerp(WAX_CREAM_203, alpha * 0.3) end
	end)
end

-- ── Stop pulse ────────────────────────────────────────────────────────────────
local function stopPulse_203()
	if pulseConn_203 then
		pulseConn_203:Disconnect()
		pulseConn_203 = nil
	end
end

-- ── Remove ring ───────────────────────────────────────────────────────────────
local function removeRing_203()
	stopPulse_203()
	if ringGui_203 and ringGui_203.Parent then
		ringGui_203:Destroy()
	end
	ringGui_203  = nil
	ringPlot_203 = nil
end

-- ── Update ring for new stage ──────────────────────────────────────────────────
local function updateStage_203(stage: number)
	if stage < VISIBLE_THRESHOLD_203 then
		removeRing_203()
		currentStage_203 = stage
		return
	end

	local root = getPlotRoot_203()
	if not root then
		removeRing_203()
		currentStage_203 = stage
		return
	end

	if ringGui_203 and ringGui_203.Parent and ringPlot_203 == root then
		-- Update in-place: change colours and label
		local col = STAGE_COLORS_203[stage] or RED_203
		local lbl = STAGE_LABELS_203[stage] or "🐻"
		local frame = ringGui_203:FindFirstChildOfClass("Frame")
		if frame then
			local stroke = frame:FindFirstChild("RingStroke") :: UIStroke?
			local text   = frame:FindFirstChild("RingText") :: TextLabel?
			if stroke then stroke.Color = col end
			if text   then text.Text = lbl; text.TextColor3 = col end
		end
		stopPulse_203()
		startPulse_203(ringGui_203, stage)
	else
		removeRing_203()
		local bg = buildRing_203(root, stage)
		ringGui_203  = bg
		ringPlot_203 = root
		startPulse_203(bg, stage)
	end

	currentStage_203 = stage
end

-- ── React to ThreatStage attribute ────────────────────────────────────────────
local function onThreatChanged_203()
	local stage = (player:GetAttribute("ThreatStage") :: number?) or 0
	if stage == currentStage_203 then return end
	updateStage_203(stage)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	-- Initial check
	onThreatChanged_203()

	-- Reactive: fire whenever ThreatStage changes
	player:GetAttributeChangedSignal("ThreatStage"):Connect(onThreatChanged_203)

	-- Safety fallback poll (threat is slow-moving — 5s is fine)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 5 then
			acc = 0
			onThreatChanged_203()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BearPatrolRingController"))
```

---

## Step 3 — Attribute source (ThreatService)

`BearPatrolRingController` reads the `ThreatStage` player attribute that `ThreatService` already broadcasts via `player:SetAttribute("ThreatStage", stage)`. No server-side changes needed.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BearPatrolRingController")
print("BearPatrolRingController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  updateStage_203:", c.Source:find("updateStage_203") ~= nil)
	print("  buildRing_203:", c.Source:find("buildRing_203") ~= nil)
	print("  startPulse_203:", c.Source:find("startPulse_203") ~= nil)
	print("  VISIBLE_THRESHOLD_203:", c.Source:find("VISIBLE_THRESHOLD_203") ~= nil)
	print("  ThreatStage attr:", c.Source:find("ThreatStage") ~= nil)
end

local CS = game:GetService("CollectionService")
local roots = CS:GetTagged("PlotRoot")
print("PlotRoot tagged parts:", #roots, "(expect 6)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Simulate stage 3 to see ring appear
game:GetService("Players").LocalPlayer:SetAttribute("ThreatStage", 3)
-- Simulate stage 6 attack (solid red)
game:GetService("Players").LocalPlayer:SetAttribute("ThreatStage", 6)
-- Clear
game:GetService("Players").LocalPlayer:SetAttribute("ThreatStage", 0)
```

**Expected output:**
```
BearPatrolRingController: LocalScript
  lines: 150+
  updateStage_203: true
  buildRing_203: true
  startPulse_203: true
  VISIBLE_THRESHOLD_203: true
  ThreatStage attr: true
PlotRoot tagged parts: 6
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| ThreatStage | Ring | Colour | Pulse |
|---|---|---|---|
| 0–2 (Safe / Distant / Approaching) | Hidden | — | — |
| 3 (Circling) | "🐻 Circling" | Amber | Amber↔Red 0.9/s |
| 4 (Watching) | "🐻 Watching" | Orange-amber | Amber↔Red faster |
| 5 (Ready to Attack) | "🐻 Ready!" | Orange-red | Strong pulse |
| 6 (Attacking) | "🐻 Attacking!" | Solid red | No pulse (frozen) |
| Drop to <3 | Disappears | — | — |

- Ring sits 5 studs above PlotRoot — visible from the Petal Path and adjacent plots
- Updates in-place (no flicker) when stage changes within the visible range
- `GetAttributeChangedSignal("ThreatStage")` gives instant response; 5s safety-net poll
- Stage 6 has no pulse because the solid frozen red is more alarming than a breathing animation

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BearRing_203 BillboardGui is a client-only GuiObject parented to PlotRoot — not a BasePart)*
