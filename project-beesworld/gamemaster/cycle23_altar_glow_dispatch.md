# Dispatch 227 — Bear Altar Glow Controller
**File:** `cycle23_altar_glow_dispatch.md`
**Cycle:** 23
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The BearAltar is the focal point of the Old Molasses threat system — players bring offerings here to appease the bear. Currently it sits as a static world object. This dispatch adds a **BearAltarGlowController**: a client-side LocalScript that finds the BearAltar-tagged part and pulses its PointLight (creating one if absent) based on `ThreatStage`. At low stages the altar glows amber-warm. As the stage rises the glow shifts cold-red and pulses faster. At Stage 6 (charge) it flares to solid bright red. Mirrors the BearWarningController (D220) vignette rhythm for visual coherence.

For kids: a glowing, pulsing altar feels magical and ominous — a clear "something important here" signal. For adults: the red glow intensity mirrors the threat stage, adding spatial information to the screen-edge vignette.

---

## Step 1 — BearAltarGlowController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BearAltarGlowController`.

Paste exactly:

```lua
--!strict
-- BearAltarGlowController: pulses BearAltar PointLight based on ThreatStage player attribute.
-- Entirely client-side — reads ThreatStage attribute. Zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local CS           = game:GetService("CollectionService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_227 = 8.0

-- Stage → glow configuration
-- pulse: true = oscillate brightness; false = hold steady
local STAGE_CONFIG_227: { [number]: {
	color:       Color3,
	minBright:   number,
	maxBright:   number,
	pulseRate:   number,   -- oscillations per second (0 = no pulse)
	range:       number,
} } = {
	[0] = { color = Color3.fromRGB(220, 140,  30), minBright = 0.4, maxBright = 0.55, pulseRate = 0.15, range = 12 },
	[1] = { color = Color3.fromRGB(220, 140,  30), minBright = 0.4, maxBright = 0.55, pulseRate = 0.15, range = 12 },
	[2] = { color = Color3.fromRGB(230, 110,  20), minBright = 0.5, maxBright = 0.70, pulseRate = 0.25, range = 14 },
	[3] = { color = Color3.fromRGB(240,  80,  10), minBright = 0.6, maxBright = 0.90, pulseRate = 0.40, range = 16 },
	[4] = { color = Color3.fromRGB(220,  40,  10), minBright = 0.7, maxBright = 1.20, pulseRate = 0.70, range = 18 },
	[5] = { color = Color3.fromRGB(200,  20,   5), minBright = 0.9, maxBright = 1.80, pulseRate = 1.30, range = 22 },
	[6] = { color = Color3.fromRGB(255,   0,   0), minBright = 2.5, maxBright = 2.5,  pulseRate = 0,    range = 28 },
}

-- ── State ─────────────────────────────────────────────────────────────────────
local altarPart_227: BasePart?   = nil
local altarLight_227: PointLight? = nil
local currentStage_227 = 0
local pulseTime_227    = 0

-- ── Find altar ────────────────────────────────────────────────────────────────
local function findAltar_227(): (BasePart?, PointLight?)
	local tagged = CS:GetTagged("BearAltar")
	for _, obj in tagged do
		if obj:IsA("BasePart") then
			local light = obj:FindFirstChildOfClass("PointLight")
			if not light then
				light = Instance.new("PointLight")
				light.Name       = "AltarGlow_227"
				light.Brightness = 0.5
				light.Range      = 12
				light.Color      = Color3.fromRGB(220, 140, 30)
				light.Shadows    = true
				light.Parent     = obj
			end
			return obj, light
		end
	end
	return nil, nil
end

-- ── Apply stage (color + range, not brightness — Heartbeat handles brightness) ─
local function applyStageConfig_227(stage: number)
	if not altarLight_227 then return end
	local cfg = STAGE_CONFIG_227[stage] or STAGE_CONFIG_227[0]

	TweenService:Create(altarLight_227, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
		Color = cfg.color,
		Range = cfg.range,
	}):Play()

	-- Snap to solid at stage 6
	if stage >= 6 then
		altarLight_227.Brightness = cfg.maxBright
	end
end

-- ── Heartbeat: pulse brightness ───────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt: number)
	if not altarLight_227 then return end
	local stage = currentStage_227
	local cfg = STAGE_CONFIG_227[stage] or STAGE_CONFIG_227[0]

	if cfg.pulseRate > 0 and stage < 6 then
		pulseTime_227 += dt * cfg.pulseRate * math.pi * 2
		local t = (math.sin(pulseTime_227) + 1) * 0.5   -- 0→1
		altarLight_227.Brightness = cfg.minBright + t * (cfg.maxBright - cfg.minBright)
	end
end)

-- ── Rescan heartbeat ──────────────────────────────────────────────────────────
local scanAcc_227 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_227 += dt
	if scanAcc_227 < SCAN_INTERVAL_227 then return end
	scanAcc_227 = 0
	if not altarPart_227 then
		altarPart_227, altarLight_227 = findAltar_227()
		if altarPart_227 then
			applyStageConfig_227(currentStage_227)
		end
	end
end)

-- ── Stage change ──────────────────────────────────────────────────────────────
local function onThreatStageChanged_227()
	local stage = math.clamp(
		math.floor((player:GetAttribute("ThreatStage") :: number?) or 0),
		0, 6
	)
	currentStage_227 = stage
	pulseTime_227    = 0
	applyStageConfig_227(stage)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	altarPart_227, altarLight_227 = findAltar_227()
	player:GetAttributeChangedSignal("ThreatStage"):Connect(onThreatStageChanged_227)
	onThreatStageChanged_227()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BearAltarGlowController"))
```

---

## Step 3 — Confirm BearAltar CollectionService tag

The controller searches for `BearAltar` CollectionService tag. Confirm the altar part in the ThreatZone world folder has this tag. Run in **Studio Command Bar**:

```lua
local CS = game:GetService("CollectionService")
local altars = CS:GetTagged("BearAltar")
print("BearAltar tagged:", #altars, "(expect 1)")
for _, a in altars do
	print("  ", a:GetFullName())
end
```

If the altar part is missing the tag, add it:

```lua
-- Replace "YourAltarPartPath" with the actual path from the inspection above
local altarPart = workspace.Map.ThreatZone:FindFirstChild("BearAltar", true)
if altarPart then
	game:GetService("CollectionService"):AddTag(altarPart, "BearAltar")
	print("Tag added:", altarPart:GetFullName())
end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BearAltarGlowController")
print("BearAltarGlowController:", c and c.ClassName or "MISSING")

-- Quick stage test
local lp = game:GetService("Players").LocalPlayer
for _, stage in {0, 2, 4, 5, 6} do
	lp:SetAttribute("ThreatStage", stage)
	task.wait(1.5)
	print("Stage", stage, "— altar should pulse in", stage <= 2 and "amber" or stage <= 4 and "orange-red" or "deep red")
end
lp:SetAttribute("ThreatStage", 0)

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| ThreatStage | Glow colour | Brightness range | Pulse rate | Range |
|---|---|---|---|---|
| 0–1 | Warm amber | 0.40→0.55 | 0.15/s (very slow) | 12 studs |
| 2 | Orange amber | 0.50→0.70 | 0.25/s slow | 14 studs |
| 3 | Orange-red | 0.60→0.90 | 0.40/s moderate | 16 studs |
| 4 | Red-orange | 0.70→1.20 | 0.70/s urgent | 18 studs |
| 5 | Deep red | 0.90→1.80 | 1.30/s frantic | 22 studs |
| 6 (charge!) | Pure red | 2.50 solid | No pulse | 28 studs |

- Pulse rhythm intentionally matches BearWarningController vignette rates (D220) — the altar and the screen edge breathe together
- TweenService Sine 0.6s for colour/range transitions — never harsh
- Creates AltarGlow_227 PointLight if the altar part doesn't already have one
- Self-heals: 8s rescan re-discovers altar if it was added late (streaming)
- Pairs with BearAltarProximityPrompt (existing) — players approaching the altar see it glowing brighter as urgency rises, reinforcing that THIS is where to go to appease the bear

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(PointLight created inside existing BearAltar Part — no new BaseParts)*
