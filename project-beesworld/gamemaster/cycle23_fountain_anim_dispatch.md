# Dispatch 226 — Honey Drip Fountain Animation
**File:** `cycle23_fountain_anim_dispatch.md`
**Cycle:** 23
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The Honey Drip Fountain was built in the Hub v3 expansion (hub dispatch, changelog entry) but is static — it emits particles at a fixed rate regardless of game state. This dispatch makes the fountain **react to server-side honey production**: the `HubHoneyFlow` workspace attribute (0.0–1.0, written by ResourceService) drives the fountain's particle rate, glow intensity, and colour warmth. At low production the fountain drips slowly; at high production it flows richly and glows golden.

For kids: a glowing, flowing fountain at the centre of the hub is a satisfying visual reward for successful beekeeping. For adults: the fountain intensity is a live production meter — you can glance at it from anywhere in the hub and know how your hive is performing.

---

## Step 1 — ResourceService: write HubHoneyFlow

Open **ServerScriptService → Systems → ResourceService**.

`HubHoneyFlow` is a 0.0–1.0 value representing total honey production rate across all active plots. Add the write near the production tick:

```lua
-- ── HubHoneyFlow calculation (add near production tick) ───────────────────────
local FLOW_MAX_RATE_226 = 8.0   -- honey/s across all plots at "full flow"

local function updateHubHoneyFlow_226()
	-- Sum current production rates across all CombCell-tagged parts
	local totalRate = 0
	local CS = game:GetService("CollectionService")
	for _, cell in CS:GetTagged("CombCell") do
		if cell:IsA("BasePart") then
			local rate = (cell:GetAttribute("OutputRate") :: number?) or 0
			totalRate += rate
		end
	end
	local flow = math.clamp(totalRate / FLOW_MAX_RATE_226, 0, 1)
	workspace:SetAttribute("HubHoneyFlow", flow)
end

-- Call inside the existing production Heartbeat accumulator, alongside the ripeness tick:
-- (every 5–10 seconds is fine, same interval as ripeness)
```

Wire into the production accumulator:

```lua
-- In ResourceService Heartbeat loop (alongside tickRipeness_218):
flowAcc_226 = (flowAcc_226 or 0) + dt
if flowAcc_226 >= 6.0 then
	flowAcc_226 = 0
	updateHubHoneyFlow_226()
end
```

---

## Step 2 — FountainAnimController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `FountainAnimController`.

Paste exactly:

```lua
--!strict
-- FountainAnimController: animates the HoneyDripFountain based on HubHoneyFlow workspace attribute.
-- Entirely client-side — reads workspace attribute set by ResourceService.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local TWEEN_TIME_226  = 2.0    -- seconds to transition between flow states
local SCAN_INTERVAL_226 = 6.5  -- seconds between fountain re-discovery

-- ── Flow states ───────────────────────────────────────────────────────────────
-- flow: 0=idle, 0.5=moderate, 1.0=full
local function getFlowConfig_226(flow: number): {
	rate: number, lightBrightness: number,
	lightRange: number, lightColor: Color3
}
	local t = math.clamp(flow, 0, 1)
	return {
		rate            = math.floor(2 + t * 14),   -- 2→16 p/s
		lightBrightness = 0.3 + t * 1.4,            -- 0.3→1.7
		lightRange      = 8  + t * 14,              -- 8→22 studs
		lightColor      = Color3.fromRGB(
			math.floor(220 + t * 35),               -- 220→255
			math.floor(100 + t * 68),               -- 100→168
			math.floor(10  + t * 18)                -- 10→28
		),
	}
end

-- ── Find fountain objects ──────────────────────────────────────────────────────
local function findFountain_226(): (BasePart?, PointLight?, ParticleEmitter?)
	local map = workspace:FindFirstChild("Map") :: Folder?
	local hub = map and map:FindFirstChild("ApiaryYardHub") :: Folder?
	local search = hub or workspace

	-- Look for the fountain model or part
	local fountain = (search :: Instance):FindFirstChild("HoneyDripFountain", true)
		or (search :: Instance):FindFirstChild("HoneyFountain", true)

	if not fountain then return nil, nil, nil end

	-- Find the basin/bowl BasePart (the main emitting surface)
	local basin: BasePart? = nil
	if fountain:IsA("BasePart") then
		basin = fountain
	else
		for _, child in (fountain :: Model):GetDescendants() do
			if child:IsA("BasePart") and (child.Name:lower():find("basin") or child.Name:lower():find("bowl") or child.Name:lower():find("base")) then
				basin = child
				break
			end
		end
		if not basin then
			for _, child in (fountain :: Model):GetDescendants() do
				if child:IsA("BasePart") then basin = child break end
			end
		end
	end

	if not basin then return nil, nil, nil end

	local light    = basin:FindFirstChildOfClass("PointLight")
	local emitter  = basin:FindFirstChildOfClass("ParticleEmitter")

	-- Create emitter if missing
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name            = "FountainDrip_226"
		emitter.Rate            = 5
		emitter.Lifetime        = NumberRange.new(0.8, 1.4)
		emitter.Speed           = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle     = Vector2.new(25, 25)
		emitter.LightEmission   = 0.3
		emitter.Color           = ColorSequence.new(Color3.fromRGB(220, 120, 20))
		emitter.Size            = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.22),
			NumberSequenceKeypoint.new(0.5, 0.14),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency    = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.7, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent          = basin
	end

	-- Create light if missing
	if not light then
		light = Instance.new("PointLight")
		light.Name       = "FountainGlow_226"
		light.Brightness = 0.5
		light.Range      = 10
		light.Color      = Color3.fromRGB(242, 130, 20)
		light.Shadows    = true
		light.Parent     = basin
	end

	return basin, light, emitter
end

-- ── Current state ─────────────────────────────────────────────────────────────
local currentFlow_226  = -1   -- -1 forces first update
local basin_226: BasePart?          = nil
local light_226: PointLight?        = nil
local emitter_226: ParticleEmitter? = nil

local function applyFlow_226(flow: number)
	if not basin_226 or not light_226 or not emitter_226 then return end
	if math.abs(flow - currentFlow_226) < 0.05 then return end
	currentFlow_226 = flow

	local cfg = getFlowConfig_226(flow)
	emitter_226.Rate = cfg.rate

	TweenService:Create(light_226, TweenInfo.new(TWEEN_TIME_226, Enum.EasingStyle.Sine), {
		Brightness = cfg.lightBrightness,
		Range      = cfg.lightRange,
		Color      = cfg.lightColor,
	}):Play()
end

-- ── Workspace attribute signal ────────────────────────────────────────────────
workspace:GetAttributeChangedSignal("HubHoneyFlow"):Connect(function()
	local flow = (workspace:GetAttribute("HubHoneyFlow") :: number?) or 0
	applyFlow_226(flow)
end)

-- ── Heartbeat scan: re-find fountain + apply ─────────────────────────────────
local scanAcc_226 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_226 += dt
	if scanAcc_226 < SCAN_INTERVAL_226 then return end
	scanAcc_226 = 0

	if not basin_226 then
		basin_226, light_226, emitter_226 = findFountain_226()
	end
	local flow = (workspace:GetAttribute("HubHoneyFlow") :: number?) or 0
	applyFlow_226(flow)
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	basin_226, light_226, emitter_226 = findFountain_226()
	local flow = (workspace:GetAttribute("HubHoneyFlow") :: number?) or 0
	currentFlow_226 = -1   -- force first apply
	applyFlow_226(flow)
end)
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("FountainAnimController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
print("HubHoneyFlow:", workspace:GetAttribute("HubHoneyFlow"))

-- Find fountain basin
local basin = workspace:FindFirstChild("HoneyDripFountain", true)
	or workspace:FindFirstChild("HoneyFountain", true)
if basin then
	print("Fountain found:", basin:GetFullName())
	local emitter = basin:IsA("BasePart") and basin:FindFirstChildOfClass("ParticleEmitter")
		or (basin:IsA("Model") and basin:FindFirstChildWhichIsA("ParticleEmitter", true))
	print("  emitter:", emitter and emitter.Name or "MISSING")
	local light = basin:IsA("BasePart") and basin:FindFirstChildOfClass("PointLight")
		or (basin:IsA("Model") and basin:FindFirstChildWhichIsA("PointLight", true))
	print("  light:", light and ("Brightness=" .. light.Brightness) or "MISSING")
else
	print("Fountain: NOT FOUND (check HoneyDripFountain name in hub)")
end

local count = 0
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

**Quick-test (in Play mode Command Bar):**

```lua
-- Simulate low flow
workspace:SetAttribute("HubHoneyFlow", 0.1)
task.wait(3)
-- Fountain should be slow, dim

-- Simulate full flow
workspace:SetAttribute("HubHoneyFlow", 1.0)
task.wait(3)
-- Fountain should be fast, bright amber-gold

-- Return to idle
workspace:SetAttribute("HubHoneyFlow", 0.0)
```

---

## Behaviour summary

| HubHoneyFlow | Particle rate | PointLight brightness | PointLight range | Glow colour |
|---|---|---|---|---|
| 0.0 (idle) | 2 p/s | 0.3 | 8 studs | Dark amber |
| 0.3 (low) | 6 p/s | 0.72 | 12 studs | Warm amber |
| 0.6 (moderate) | 10 p/s | 1.14 | 17 studs | Golden amber |
| 1.0 (full flow) | 16 p/s | 1.7 | 22 studs | Bright honey gold |

- PointLight transitions use TweenService Sine 2s — smooth, not jarring
- Emitter Rate updates instantly (particles are already in motion)
- Controller self-heals: re-discovers fountain every 6.5s if basin ref becomes nil
- Creates FountainDrip_226 ParticleEmitter and FountainGlow_226 PointLight if the fountain doesn't already have them
- Workspace attribute signal fires immediate response on any production change
- Together with HoneyGlowController (D204) and the leaderboard board (D223), the hub now reads as a live production environment — the fountain pulses as the hive thrives

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(FountainAnimController LocalScript — no BaseParts; emitter/light created inside existing fountain part)*
