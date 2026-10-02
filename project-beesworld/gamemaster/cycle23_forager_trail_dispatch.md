# Dispatch 225 — Forager Bee Trail VFX
**File:** `cycle23_forager_trail_dispatch.md`
**Cycle:** 23
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The forager bees fly routes between the hive and flower patches but currently leave no visual trace of their journey. This dispatch adds a **Forager Bee Trail**: a subtle amber-gold particle trail that follows each forager bee Part as it moves. The trail has two states — outbound (light yellow-white, sparse) and laden/return (amber-gold, denser) — signalling whether the bee is empty-handed or carrying nectar. Entirely client-side; reads the `NectarLoad` attribute on ForagerBee-tagged parts.

For kids: golden sparkles trailing the bees make the hive feel magical and alive. For adults: the loaded vs unloaded visual distinction communicates foraging state at a glance.

---

## Step 1 — ForagerTrailController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `ForagerTrailController`.

Paste exactly:

```lua
--!strict
-- ForagerTrailController: particle trails on ForagerBee-tagged parts.
-- Trail colour/density changes based on NectarLoad attribute (0=empty, 1=full).
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_225  = 5.0   -- seconds between new-bee scan
local TRAIL_LIFETIME_225 = 0.8   -- seconds particle lives
local TRAIL_SIZE_225     = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.18),
	NumberSequenceKeypoint.new(0.5, 0.12),
	NumberSequenceKeypoint.new(1, 0),
})
local TRAIL_TRANS_225 = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(0.6, 0.6),
	NumberSequenceKeypoint.new(1, 1),
})

-- ── Colour sequences ──────────────────────────────────────────────────────────
-- Outbound (empty): light yellow-white, low rate
local COLOR_EMPTY_225 = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 220)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(240, 200, 100)),
})
local RATE_EMPTY_225 = 4

-- Laden / return: amber-gold, higher rate
local COLOR_LADEN_225 = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200,  50)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100,  10)),
})
local RATE_LADEN_225 = 9

-- ── Per-bee emitter registry ──────────────────────────────────────────────────
local emitters_225: { [BasePart]: ParticleEmitter } = {}

-- ── Build emitter for a forager bee part ─────────────────────────────────────
local function buildEmitter_225(bee: BasePart): ParticleEmitter
	local existing = bee:FindFirstChild("ForagerTrail_225") :: ParticleEmitter?
	if existing then return existing end

	local e = Instance.new("ParticleEmitter")
	e.Name            = "ForagerTrail_225"
	e.Lifetime        = NumberRange.new(TRAIL_LIFETIME_225 * 0.8, TRAIL_LIFETIME_225)
	e.Rate            = RATE_EMPTY_225
	e.Speed           = NumberRange.new(0, 0.05)   -- barely drifts; bee moves the emitter
	e.SpreadAngle     = Vector2.new(15, 15)
	e.Size            = TRAIL_SIZE_225
	e.Transparency    = TRAIL_TRANS_225
	e.Color           = COLOR_EMPTY_225
	e.LightEmission   = 0.15
	e.LightInfluence  = 0.85
	e.Rotation        = NumberRange.new(-20, 20)
	e.RotSpeed        = NumberRange.new(-30, 30)
	e.Enabled         = true
	e.Parent          = bee

	return e
end

-- ── Update emitter state based on NectarLoad ─────────────────────────────────
local function updateEmitter_225(bee: BasePart, emitter: ParticleEmitter)
	local load = (bee:GetAttribute("NectarLoad") :: number?) or 0
	local laden = load > 0.1

	emitter.Color = laden and COLOR_LADEN_225 or COLOR_EMPTY_225
	emitter.Rate  = laden and RATE_LADEN_225  or RATE_EMPTY_225
end

-- ── Setup a forager bee ───────────────────────────────────────────────────────
local function setupBee_225(bee: BasePart)
	if emitters_225[bee] then return end
	local emitter = buildEmitter_225(bee)
	emitters_225[bee] = emitter
	updateEmitter_225(bee, emitter)

	bee:GetAttributeChangedSignal("NectarLoad"):Connect(function()
		if emitter and emitter.Parent then
			updateEmitter_225(bee, emitter)
		end
	end)
end

-- ── Cleanup removed bees ──────────────────────────────────────────────────────
CollectionService:GetInstanceRemovedSignal("ForagerBee"):Connect(function(inst)
	if inst:IsA("BasePart") then
		emitters_225[inst] = nil
	end
end)

-- ── Scan for new bees ─────────────────────────────────────────────────────────
local scanAcc_225 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_225 += dt
	if scanAcc_225 < SCAN_INTERVAL_225 then return end
	scanAcc_225 = 0
	for _, bee in CollectionService:GetTagged("ForagerBee") do
		if bee:IsA("BasePart") then
			setupBee_225(bee)
		end
	end
	-- Prune stale refs
	for bee in emitters_225 do
		if not bee.Parent then
			emitters_225[bee] = nil
		end
	end
end)

-- ── Live signal for new bees spawned during play ─────────────────────────────
CollectionService:GetInstanceAddedSignal("ForagerBee"):Connect(function(inst)
	if inst:IsA("BasePart") then
		task.delay(0.3, function()
			setupBee_225(inst)
		end)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	for _, bee in CollectionService:GetTagged("ForagerBee") do
		if bee:IsA("BasePart") then
			setupBee_225(bee)
		end
	end
end)
```

---

## Step 2 — ForagingService: tag and attribute

Open **ServerScriptService → Systems → ForagingService**.

Confirm that each forager bee part is tagged `ForagerBee` and has a `NectarLoad` attribute (0.0–1.0) written as nectar is collected. If not yet present:

```lua
-- When spawning a forager bee part:
local CS = game:GetService("CollectionService")
CS:AddTag(beePart, "ForagerBee")
beePart:SetAttribute("NectarLoad", 0)

-- When the forager loads nectar at the patch:
beePart:SetAttribute("NectarLoad", math.clamp(nectarCarried / maxCarry, 0, 1))

-- When the forager deposits nectar at the hive:
beePart:SetAttribute("NectarLoad", 0)
```

`maxCarry` should come from `Config.NECTAR_PER_FORAGER` or similar. If the forager is binary (empty vs full) rather than a continuous load, use 0 for empty and 1 for full.

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("ForagerTrailController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode, after foragers have spawned):

```lua
local CS = game:GetService("CollectionService")
local bees = CS:GetTagged("ForagerBee")
print("ForagerBee tagged:", #bees)
for i, bee in bees do
	if i > 4 then print("  ...") break end
	local e = bee:FindFirstChild("ForagerTrail_225")
	local load = bee:GetAttribute("NectarLoad") or 0
	print(string.format("  %s  NectarLoad=%.2f  emitter=%s  Rate=%s",
		bee.Name, load,
		e and "YES" or "NO",
		e and tostring(e.Rate) or "—"))
end
```

**Quick-test (in Play mode):**

```lua
-- Force-add trail to a test part to verify visuals
local test = Instance.new("Part")
test.Size = Vector3.new(0.4, 0.4, 0.4)
test.Position = Vector3.new(0, 5, -280)
test.Anchored = false
test.CanCollide = false
test.Parent = workspace

game:GetService("CollectionService"):AddTag(test, "ForagerBee")
test:SetAttribute("NectarLoad", 0)

task.wait(5)   -- controller should pick it up on scan or GetInstanceAdded
print("trail emitter:", test:FindFirstChild("ForagerTrail_225") ~= nil)

task.wait(1)
test:SetAttribute("NectarLoad", 1)   -- should switch to amber-gold trail
task.wait(3)
test:Destroy()
```

---

## Behaviour summary

| State | Trail colour | Rate | When |
|---|---|---|---|
| Outbound (empty) | Light yellow-white → amber | 4 p/s | NectarLoad ≤ 0.1 |
| Laden (return) | Bright amber-gold → dark amber | 9 p/s | NectarLoad > 0.1 |

- Trail lifetime 0.8s — fades fast, marks recent path but doesn't accumulate
- Speed near-zero — bee's own movement drags the trail naturally
- LightEmission=0.15 — subtle glow, readable in bright meadow light
- Cleanup on ForagerBee tag removed and on 5s stale-ref prune
- GetInstanceAdded wires up newly spawned bees with 0.3s delay
- Performance: at 6 plots × 3 foragers each = max 18 bees × 4–9 p/s = ~72–162 p/s total. Well within the project's 80+ p/s budget at typical occupancy (2–3 active players, 6–9 foragers = 24–81 p/s).

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(ParticleEmitter instances inside ForagerBee parts — no BaseParts)*
