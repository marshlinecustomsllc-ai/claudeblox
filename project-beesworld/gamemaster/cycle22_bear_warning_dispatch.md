# Dispatch 220 — Bear Approach Warning
**File:** `cycle22_bear_warning_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture's Old Molasses bear antagonist has 6 patience stages. Players already see the threat meter in HudController, but there is no visceral "danger escalation" signal when the bear reaches Stages 4 and 5 (charge imminent). This dispatch adds a **Bear Approach Warning**: a red screen-edge vignette that pulses faster as `ThreatStage` rises above 3, plus a brief screen-shake rumble at Stage 4 and a sustained low-frequency rumble effect at Stage 5. The vignette fades at Stage 1–3 and disappears at Stage 0. Entirely client-side — reads the `ThreatStage` player attribute.

For kids: the red flashing frame is a universal "danger!" signal that doesn't require reading. For adults: the escalating pulse rate communicates stage level precisely.

---

## Step 1 — BearWarningController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BearWarningController`.

Paste exactly:

```lua
--!strict
-- BearWarningController: screen-edge vignette + rumble when ThreatStage >= 4.
-- Reads ThreatStage player attribute (set by ThreatService).
-- Entirely client-side — zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
-- Vignette pulse rates per stage (pulses per second)
local PULSE_RATES_220: { [number]: number } = {
	[0] = 0,    -- no pulse
	[1] = 0,    -- no pulse
	[2] = 0,    -- no pulse
	[3] = 0.30, -- very slow (first warning)
	[4] = 0.80, -- urgent
	[5] = 1.60, -- frantic — charge imminent
	[6] = 0,    -- bear is acting — vignette held solid
}

local VIGNETTE_ALPHA_220: { [number]: number } = {
	[0] = 0,    [1] = 0,    [2] = 0,
	[3] = 0.20, [4] = 0.45, [5] = 0.70, [6] = 0.85,
}

local RUMBLE_MAGNITUDE_220 = 3.5   -- studs of camera offset for shake

-- ── Palette ───────────────────────────────────────────────────────────────────
local BEAR_RED_220    = Color3.fromRGB(200,  30,  10)
local BEAR_AMBER_220  = Color3.fromRGB(220,  80,  10)

-- ── State ─────────────────────────────────────────────────────────────────────
local vigGui_220: ScreenGui? = nil
local built_220 = false
local currentStage_220 = 0
local pulseTime_220    = 0
local rumbleConn_220: RBXScriptConnection? = nil
local rumbleAcc_220   = 0
local RUMBLE_INTERVAL_220 = 1.8   -- seconds between rumbles at stage 5

-- ── Build vignette ────────────────────────────────────────────────────────────
local function buildVig_220(): ScreenGui
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return nil :: any end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "BearWarning_220"
	sg.DisplayOrder   = 30   -- above all HUD elements
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	-- Four edge frames (top, bottom, left, right)
	local edges: { { size: UDim2, pos: UDim2 } } = {
		{ size = UDim2.new(1, 0, 0, 40), pos = UDim2.new(0, 0, 0, 0) },      -- top
		{ size = UDim2.new(1, 0, 0, 40), pos = UDim2.new(0, 0, 1, -40) },    -- bottom
		{ size = UDim2.new(0, 30, 1, 0), pos = UDim2.new(0, 0, 0, 0) },      -- left
		{ size = UDim2.new(0, 30, 1, 0), pos = UDim2.new(1, -30, 0, 0) },    -- right
	}

	for i, e in ipairs(edges) do
		local frame = Instance.new("Frame")
		frame.Name                   = "Edge" .. tostring(i)
		frame.Size                   = e.size
		frame.Position               = e.pos
		frame.BackgroundColor3       = BEAR_RED_220
		frame.BackgroundTransparency = 1   -- starts invisible
		frame.BorderSizePixel        = 0
		frame.ZIndex                 = 2
		frame.Parent                 = sg
	end

	return sg
end

-- ── Set vignette alpha ────────────────────────────────────────────────────────
local function setVigAlpha_220(alpha: number)
	if not vigGui_220 then return end
	for _, child in vigGui_220:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 1 - alpha
		end
	end
end

-- ── Camera rumble ──────────────────────────────────────────────────────────────
local camera = workspace.CurrentCamera
local baseOffset_220 = CFrame.new(0, 0, 0)

local function doRumble_220()
	local mag = RUMBLE_MAGNITUDE_220
	local elapsed = 0
	local dur = 0.35
	local shakeConn: RBXScriptConnection
	shakeConn = RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed >= dur then
			camera.CFrame = camera.CFrame * CFrame.new(0, 0, 0)
			shakeConn:Disconnect()
			return
		end
		local decay = 1 - (elapsed / dur)
		local ox = (math.random() * 2 - 1) * mag * decay
		local oy = (math.random() * 2 - 1) * mag * 0.5 * decay
		camera.CFrame = camera.CFrame * CFrame.new(ox, oy, 0)
	end)
end

-- ── Main heartbeat ────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt: number)
	if not vigGui_220 then return end
	local stage = currentStage_220

	-- Vignette pulse
	local rate = PULSE_RATES_220[stage] or 0
	if rate > 0 then
		pulseTime_220 += dt * rate * math.pi * 2
		local alpha = VIGNETTE_ALPHA_220[stage] or 0
		local pulse = ((math.sin(pulseTime_220) + 1) * 0.5) * alpha
		setVigAlpha_220(pulse)
	elseif stage >= 6 then
		setVigAlpha_220(VIGNETTE_ALPHA_220[6] or 0.85)   -- solid red at stage 6
	else
		-- Fade to 0
		setVigAlpha_220(0)
		pulseTime_220 = 0
	end

	-- Stage 5 rumble
	if stage >= 5 then
		rumbleAcc_220 += dt
		if rumbleAcc_220 >= RUMBLE_INTERVAL_220 then
			rumbleAcc_220 = 0
			doRumble_220()
		end
	else
		rumbleAcc_220 = 0
	end
end)

-- ── Stage change ──────────────────────────────────────────────────────────────
local function onThreatStageChanged_220()
	local stage = math.clamp(
		math.floor((player:GetAttribute("ThreatStage") :: number?) or 0),
		0, 6
	)

	local prev = currentStage_220
	currentStage_220 = stage

	-- Immediate rumble on stage 4 entry
	if stage == 4 and prev < 4 then
		doRumble_220()
	end

	-- Stage 6 (bear charges): brief red flash then hold
	if stage == 6 and prev < 6 then
		setVigAlpha_220(1.0)
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	if not built_220 then
		built_220 = true
		vigGui_220 = buildVig_220()
	end

	player:GetAttributeChangedSignal("ThreatStage"):Connect(onThreatStageChanged_220)
	onThreatStageChanged_220()   -- read initial state
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BearWarningController"))
```

---

## Step 3 — Attribute source (ThreatService)

`BearWarningController` reads one player attribute:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `ThreatStage` | number (0–6) | ThreatService | Old Molasses patience stage |

ThreatService (dispatch from the Molasses build cycle) already tracks patience stages. Confirm it writes `ThreatStage` to the player attribute:

```lua
-- In ThreatService, when patience stage changes:
for _, p in game:GetService("Players"):GetPlayers() do
	p:SetAttribute("ThreatStage", currentStage)
end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BearWarningController")
print("BearWarningController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildVig_220:", c.Source:find("buildVig_220") ~= nil)
	print("  PULSE_RATES_220:", c.Source:find("PULSE_RATES_220") ~= nil)
	print("  doRumble_220:", c.Source:find("doRumble_220") ~= nil)
	print("  ThreatStage attr:", c.Source:find("ThreatStage") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
local lp = game:GetService("Players").LocalPlayer
-- Stage 3 — faint slow pulse
lp:SetAttribute("ThreatStage", 3)
task.wait(3)
-- Stage 4 — urgent pulse + rumble
lp:SetAttribute("ThreatStage", 4)
task.wait(4)
-- Stage 5 — frantic + periodic rumble
lp:SetAttribute("ThreatStage", 5)
task.wait(6)
-- Stage 6 — solid red (bear charges!)
lp:SetAttribute("ThreatStage", 6)
task.wait(3)
-- Clear
lp:SetAttribute("ThreatStage", 0)
```

---

## Behaviour summary

| ThreatStage | Vignette | Pulse rate | Rumble |
|---|---|---|---|
| 0–2 | Hidden | — | — |
| 3 | Faint (20%) | 0.30/s slow | — |
| 4 | Medium (45%) | 0.80/s urgent | Single rumble on entry |
| 5 | Strong (70%) | 1.60/s frantic | Every 1.8s |
| 6 (charge!) | Solid (85%) | No pulse — held | — |

- Four edge frames form a vignette (not a single overlay) — visible on ultrawide, no centre obstruction
- DisplayOrder=30 — sits above all other HUD elements including popups
- Camera shake is RenderStepped (client-only), decays over 0.35s, magnitude 3.5 studs — unmistakeable but not nauseating
- Pairs with HudController's threat meter bar — the bar tracks stage, the vignette adds visceral urgency
- Stage 3 introduces first warning to give kids time to react
- Instantly reversible — resets to 0 when ThreatStage drops (smoker used, OldMolasses appeased)

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(ScreenGui only — no BaseParts)*
