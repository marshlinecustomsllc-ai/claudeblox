# Dispatch 171 — Pollen Packet VFX Burst
**File:** `cycle15_pollen_packet_vfx_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When a player uses the `pollen_packet` consumable, a notification fires but there is no world-space visual. This dispatch adds a **pollen shower burst** that plays on the player's comb deck when the consumable activates: a shower of yellow-green pollen particles rains down from above, lasting ~2 seconds. Kids see "it's raining pollen!" Adults know their foraging quality boost just kicked in. Uses the existing `ConsumableUsed` RemoteEvent (or `Notify` as fallback). No new parts — emitter is temporary, created and destroyed each use.

---

## Step 1 — PollenPacketController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PollenPacketController`.

Paste exactly:

```lua
--!strict
-- PollenPacketController: pollen shower burst VFX when pollen_packet consumable is used
-- Creates a temporary emitter on the player's comb deck, fires a burst, then destroys it.
-- Listens to ConsumableUsed RemoteEvent (kind="pollen_packet") or Notify as fallback.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Palette ───────────────────────────────────────────────────────────────────
local POLLEN_YELLOW_171 = Color3.fromRGB(220, 240, 60)
local POLLEN_GREEN_171  = Color3.fromRGB(140, 210, 60)
local HONEY_GOLD_171    = Color3.fromRGB(242, 168, 28)

-- ── Find player's comb deck center ───────────────────────────────────────────
local function findDeckCenter_171(): Vector3?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	-- DanceFloorCentrePlate is at (0,0) on every plot — the deck's geometric center
	local CS = CollectionService
	for _, part in CS:GetTagged("DimCellPlate") do
		if part:GetAttribute("PlotIndex") == myPlot then
			local q = part:GetAttribute("Q") or 0
			local r = part:GetAttribute("R") or 0
			if q == 0 and r == 0 then
				return part.Position + Vector3.new(0, 8, 0)  -- 8 studs above deck
			end
		end
	end
	-- Fallback: LandingBoard position
	for _, board in CS:GetTagged("LandingBoard") do
		if board:GetAttribute("PlotIndex") == myPlot then
			return (board :: BasePart).Position + Vector3.new(0, 10, 0)
		end
	end
	return nil
end

-- ── Burst VFX ─────────────────────────────────────────────────────────────────
local burstInProgress_171 = false

local function playPollenBurst_171()
	if burstInProgress_171 then return end
	burstInProgress_171 = true

	local center = findDeckCenter_171()
	if not center then
		burstInProgress_171 = false
		return
	end

	-- Create a temporary anchor part high above the deck
	local anchor = Instance.new("Part")
	anchor.Name          = "PollenBurstAnchor_171"
	anchor.Size          = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position      = center
	anchor.Anchored      = true
	anchor.CanCollide    = false
	anchor.Transparency  = 1
	anchor.CastShadow    = false
	anchor.Parent        = workspace

	-- Create emitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name        = "PollenShower_171"
	emitter.Enabled     = false
	emitter.Rate        = 0
	emitter.Lifetime    = NumberRange.new(1.2, 2.0)
	emitter.Speed       = NumberRange.new(3, 8)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Bottom  -- shower DOWN from anchor
	emitter.Size        = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.25),
		NumberSequenceKeypoint.new(0.4, 0.35),
		NumberSequenceKeypoint.new(1,   0.0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1,   1.0),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   POLLEN_YELLOW_171),
		ColorSequenceKeypoint.new(0.5, POLLEN_GREEN_171),
		ColorSequenceKeypoint.new(1,   HONEY_GOLD_171),
	})
	emitter.LightEmission  = 0.2
	emitter.LightInfluence = 0.5
	emitter.RotSpeed       = NumberRange.new(-120, 120)
	emitter.Rotation       = NumberRange.new(0, 360)
	emitter.Acceleration   = Vector3.new(0, -5, 0)  -- gentle gravity pull
	emitter.Parent         = anchor

	-- Fire the burst: 40 particles in one shot
	emitter:Emit(40)

	-- Screen flash: brief golden tint on a fullscreen frame
	local sg = player.PlayerGui
	local flash = Instance.new("Frame")
	flash.Name              = "PollenFlash_171"
	flash.Size              = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3  = POLLEN_YELLOW_171
	flash.BackgroundTransparency = 0.85
	flash.BorderSizePixel   = 0
	flash.ZIndex            = 50
	local flashGui = Instance.new("ScreenGui")
	flashGui.Name           = "PollenFlashGui"
	flashGui.DisplayOrder   = 50
	flashGui.ResetOnSpawn   = false
	flashGui.IgnoreGuiInset = true
	flashGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	flash.Parent            = flashGui
	flashGui.Parent         = sg

	-- Fade flash out
	TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1.0 }):Play()

	-- Clean up after particles expire (2.2s covers max lifetime)
	task.delay(2.5, function()
		anchor:Destroy()
		flashGui:Destroy()
		burstInProgress_171 = false
	end)
end

-- ── Listen for consumable events ──────────────────────────────────────────────
-- Primary: ConsumableUsed RemoteEvent (if ConsumableService fires it)
local consumableUsed = Remotes:FindFirstChild("ConsumableUsed") :: RemoteEvent?
if consumableUsed then
	consumableUsed.OnClientEvent:Connect(function(kind: string)
		if kind == "pollen_packet" then
			playPollenBurst_171()
		end
	end)
end

-- Secondary: Notify remote — parse kind field from payload
local notify = Remotes:FindFirstChild("Notify") :: RemoteEvent?
if notify then
	notify.OnClientEvent:Connect(function(msg: string, kind: string?)
		-- ConsumableService fires Notify with messages containing "pollen" on use
		if kind == "purchase" and msg and msg:lower():find("pollen") then
			playPollenBurst_171()
		end
	end)
end
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PollenPacketController"))
```

---

## Step 3 — Optional: ConsumableUsed RemoteEvent

Run in **Studio Command Bar**:

```lua
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
print("ConsumableUsed:", R:FindFirstChild("ConsumableUsed") and "EXISTS" or "MISSING — Notify fallback active")
```

If `MISSING`, the controller uses the Notify fallback. To add the proper event:

```lua
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not R:FindFirstChild("ConsumableUsed") then
	local re = Instance.new("RemoteEvent")
	re.Name   = "ConsumableUsed"
	re.Parent = R
	print("ConsumableUsed created")
end
```

Then in **ConsumableService** (ServerScriptService.Systems), inside the `UseConsumable` handler, after applying the pollen_packet effect, add:

```lua
local ConsumableUsed_171 = Remotes:FindFirstChild("ConsumableUsed")
if ConsumableUsed_171 then
	local ok = pcall(function()
		ConsumableUsed_171:FireClient(player, itemId)  -- itemId = "pollen_packet"
	end)
end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PollenPacketController")
print("PollenPacketController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  playPollenBurst_171:", c.Source:find("playPollenBurst_171") ~= nil)
	print("  ConsumableUsed listener:", c.Source:find("ConsumableUsed") ~= nil)
	print("  Notify fallback:", c.Source:find("pollen_packet") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204 — burst anchor is ephemeral)")
```

**Expected output:**
```
PollenPacketController: LocalScript
  lines: 120+
  playPollenBurst_171: true
  ConsumableUsed listener: true
  Notify fallback: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Trigger | Effect |
|---------|--------|
| pollen_packet consumable used | 40 pollen particles shower DOWN from 8 studs above deck center |
| Particle colours | Yellow-green → green → gold gradient, 1.2–2.0s lifetime |
| Gravity | Vector3(0, -5, 0) acceleration — falls naturally |
| Screen flash | Brief golden fullscreen tint (0.85 transp → 1.0 over 0.8s) |
| Cleanup | Anchor + emitter destroyed 2.5s after burst; burst lock prevents stacking |
| Fallback | Notify message containing "pollen" triggers same burst |

**Part budget: +0 permanent (burst anchor is ephemeral) → 4,204 / 5,000**
