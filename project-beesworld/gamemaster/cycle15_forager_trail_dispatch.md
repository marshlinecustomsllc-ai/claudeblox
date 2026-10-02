# Dispatch 167 — Forager Return Trail VFX
**File:** `cycle15_forager_trail_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,198 / 5,000
**Part budget after:** 4,198 / 5,000 (+0)

---

## Overview

When a forager bee completes a trip and returns to the hive, there is currently no visual event — the player's Honey resource just ticks up silently. This dispatch adds a **golden pollen-trail arc** that plays on each forager return: a short particle burst that sweeps from the flower patch direction toward the player's Landing Board, giving a satisfying "bee coming home" moment. Entirely client-side. Reuses the existing `ForagingService → ForagerReturn` RemoteEvent (or `RatesUpdate` as a fallback signal).

---

## Step 1 — ForagingReturnTrail anchor part (one per plot)

This dispatch needs one invisible anchor part per Landing Board so the trail emitter knows where to fire from. Run in **Studio Command Bar**:

```lua
-- Create a TrailAnchor part on each plot's LandingBoard
local CS = game:GetService("CollectionService")
local boards = CS:GetTagged("LandingBoard")
print("LandingBoard count:", #boards)
local created = 0
for _, board in boards do
	if not board:FindFirstChild("TrailAnchor_167") then
		local anchor = Instance.new("Part")
		anchor.Name          = "TrailAnchor_167"
		anchor.Size          = Vector3.new(0.2, 0.2, 0.2)
		anchor.Anchored      = true
		anchor.CanCollide    = false
		anchor.Transparency  = 1
		anchor.CastShadow    = false
		-- Position 2 studs above the board center
		anchor.CFrame        = board.CFrame * CFrame.new(0, 2, 0)
		anchor.Parent        = board
		-- Tag it so ForagerTrailController can find it
		CS:AddTag(anchor, "ForagerTrailAnchor")
		created += 1
	end
end
print("TrailAnchor_167 created on", created, "boards")
```

**Expected output:** `TrailAnchor_167 created on 6 boards`

---

## Step 2 — ForagerTrailController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `ForagerTrailController`.

Paste exactly:

```lua
--!strict
-- ForagerTrailController: golden pollen-trail burst on forager return
-- Fires a short arc of particles from the trail anchor on each return event.
-- Entirely client-side; uses existing ForagerReturn remote or RatesUpdate as fallback.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local character  = player.Character or player.CharacterAdded:Wait()
local plotIndex  = player:GetAttribute("PlotIndex") or 1

-- ── Palette ──────────────────────────────────────────────────────────────────
local HONEY_GOLD_167 = Color3.fromRGB(242, 168, 28)
local POLLEN_167     = Color3.fromRGB(255, 220, 80)
local AMBER_167      = Color3.fromRGB(200, 120, 20)

-- ── Find this player's TrailAnchor ────────────────────────────────────────────
local function findAnchor_167(): BasePart?
	-- PlotIndex attribute is set by PlotService when a plot is assigned
	local currentPlot = player:GetAttribute("PlotIndex") or plotIndex
	for _, anchor in CollectionService:GetTagged("ForagerTrailAnchor") do
		-- Walk up to find the LandingBoard, then check its PlotIndex attribute
		local lb = anchor.Parent
		if lb and lb:GetAttribute("PlotIndex") == currentPlot then
			return anchor :: BasePart
		end
	end
	-- Fallback: return any anchor (shouldn't happen in practice)
	local all = CollectionService:GetTagged("ForagerTrailAnchor")
	return (#all > 0) and (all[1] :: BasePart) or nil
end

-- ── Build emitter on an anchor part ──────────────────────────────────────────
local function ensureEmitter_167(anchor: BasePart): ParticleEmitter
	local existing = anchor:FindFirstChild("ForagerTrail_167") :: ParticleEmitter?
	if existing then return existing end

	local emitter       = Instance.new("ParticleEmitter")
	emitter.Name        = "ForagerTrail_167"
	emitter.Enabled     = false               -- only fires on-demand via Emit()
	emitter.Rate        = 0
	emitter.Lifetime    = NumberRange.new(1.0, 1.8)
	emitter.Speed       = NumberRange.new(8, 14)
	-- Direction: mostly upward with outward spread — simulates bees fanning out
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size        = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.15),
		NumberSequenceKeypoint.new(0.3, 0.28),
		NumberSequenceKeypoint.new(1,   0.0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.2),
		NumberSequenceKeypoint.new(0.6, 0.3),
		NumberSequenceKeypoint.new(1,   1.0),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   POLLEN_167),
		ColorSequenceKeypoint.new(0.5, HONEY_GOLD_167),
		ColorSequenceKeypoint.new(1,   AMBER_167),
	})
	emitter.LightEmission  = 0.15   -- subtle warm glow
	emitter.LightInfluence = 0.6
	emitter.RotSpeed       = NumberRange.new(-90, 90)
	emitter.Rotation       = NumberRange.new(0, 360)
	emitter.Parent         = anchor
	return emitter
end

-- ── Play the return burst ─────────────────────────────────────────────────────
-- count: number of foragers returning this tick (clamped 1–6 for visual budget)
local lastBurst_167 = 0
local BURST_COOLDOWN_167 = 1.5   -- minimum seconds between visible bursts

local function playReturnBurst_167(count: number?)
	local now = tick()
	if now - lastBurst_167 < BURST_COOLDOWN_167 then return end
	lastBurst_167 = now

	local anchor = findAnchor_167()
	if not anchor then return end

	local emitter = ensureEmitter_167(anchor)
	local particleCount = math.clamp(math.floor((count or 1) * 3), 4, 18)
	emitter:Emit(particleCount)

	-- Brief glow pulse on the anchor's parent Landing Board
	local lb = anchor.Parent
	local light = lb and lb:FindFirstChildOfClass("PointLight") :: PointLight?
	if light then
		local origBright = light.Brightness
		TweenService:Create(light, TweenInfo.new(0.25), { Brightness = origBright * 2.5 }):Play()
		task.delay(0.4, function()
			TweenService:Create(light, TweenInfo.new(0.6), { Brightness = origBright }):Play()
		end)
	end
end

-- ── Listen for return events ──────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Primary: ForagerReturn event fired by ForagingService on each return
local foragerReturn = Remotes:FindFirstChild("ForagerReturn") :: RemoteEvent?
if foragerReturn then
	foragerReturn.OnClientEvent:Connect(function(data)
		-- data may be { count, qualMult } or just a bare number; handle both
		local count = (type(data) == "table" and data.count) or (type(data) == "number" and data) or 1
		playReturnBurst_167(count)
	end)
else
	-- Fallback: poll RatesUpdate for honeyRate increases between ticks
	-- This fires every ~5s and gives a weaker signal, but still works without ForagerReturn
	local ratesUpdate = Remotes:FindFirstChild("RatesUpdate") :: RemoteEvent?
	if ratesUpdate then
		local lastHoneyRate_167 = 0
		ratesUpdate.OnClientEvent:Connect(function(honeyRate, _pollinationRate, _supplyRate, _bottleneck)
			if type(honeyRate) == "number" and honeyRate > lastHoneyRate_167 + 0.1 then
				playReturnBurst_167(1)
			end
			lastHoneyRate_167 = honeyRate or lastHoneyRate_167
		end)
	end
end

-- ── Update anchor on plot reassignment ───────────────────────────────────────
player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
	plotIndex = player:GetAttribute("PlotIndex") or 1
	-- Re-cache anchor on next burst (findAnchor_167 reads PlotIndex live)
end)
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("ForagerTrailController"))
```

---

## Step 4 — Optional: ForagerReturn RemoteEvent (if not already present)

Run in **Studio Command Bar** to check:

```lua
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
print("ForagerReturn:", R:FindFirstChild("ForagerReturn") and "EXISTS" or "MISSING — fallback to RatesUpdate will be used")
```

If `MISSING`, the controller automatically falls back to `RatesUpdate` polling (shallower signal, 5s cadence, but still fires). To add the proper event, run:

```lua
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not R:FindFirstChild("ForagerReturn") then
	local re = Instance.new("RemoteEvent")
	re.Name   = "ForagerReturn"
	re.Parent = R
	print("ForagerReturn created")
end
```

Then in **ForagingService** (ServerScriptService.Systems), inside the per-tick loop where nectar is deposited into cells, add after a successful deposit:

```lua
-- Fire return trail VFX (client-side only, no trusted data)
local ForagerReturn_167 = Remotes:FindFirstChild("ForagerReturn")
if ForagerReturn_167 then
	local ok2 = pcall(function()
		ForagerReturn_167:FireClient(player, { count = depositedCount or 1 })
	end)
end
```

---

## Step 5 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check anchor parts
local CS = game:GetService("CollectionService")
local anchors = CS:GetTagged("ForagerTrailAnchor")
print("ForagerTrailAnchor parts:", #anchors, "(expect 6)")
for _, a in anchors do
	print(" ", a:GetFullName(), "| PlotIndex:", a.Parent and a.Parent:GetAttribute("PlotIndex") or "none")
end

-- Check controller
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("ForagerTrailController")
print("ForagerTrailController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines, "| ensureEmitter:", c.Source:find("ensureEmitter_167") ~= nil)
end

-- Check remotes
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
print("ForagerReturn remote:", R:FindFirstChild("ForagerReturn") and "EXISTS" or "MISSING (fallback active)")

-- Part count: should be 4198 + 6 anchor parts = 4204
local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204 — 6 anchor parts added)")
```

**Expected output:**
```
ForagerTrailAnchor parts: 6  (expect 6)
  Workspace.Map.Plot1.LandingBoard.TrailAnchor_167  | PlotIndex: 1
  ...
ForagerTrailController: LocalScript
  lines: 100+  |  ensureEmitter: true
ForagerReturn remote: EXISTS  (or MISSING fallback active)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Event | Visual |
|-------|--------|
| Forager returns (ForagerReturn event) | 4–18 golden pollen particles burst upward from Landing Board, lifetime 1–1.8s, fade to amber |
| Burst cooldown | 1.5s minimum between bursts — prevents particle storm during rapid multi-forager returns |
| Landing Board light | Brief 2.5× brightness glow pulse (0.25s rise, 0.6s settle) |
| No ForagerReturn event | Falls back to RatesUpdate polling — fires on honeyRate increase, same burst but ~5s latency |
| Plot reassignment | PlotIndex change signal re-targets anchor automatically |

**Part budget: +6 permanent (TrailAnchor_167 on each Landing Board) → 4,204 / 5,000**
