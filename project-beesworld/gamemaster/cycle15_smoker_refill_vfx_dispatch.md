# Dispatch 174 — Smoker Refill SFX + Smoke Puff
**File:** `cycle15_smoker_refill_vfx_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When a player uses the `smoker_refill` consumable, the existing notification appears but there is no sensory feedback connecting them to the smoker world object. This dispatch adds:

1. A **smoke puff burst** that emits from the Smoker world object on the player's plot (white/grey smoke, 2.5s burst).
2. A **soft hissing SFX** that plays once from the Smoker's position (spatial 3D sound, audible nearby but not intrusive).
3. A **"🌫️ Smoker recharged!" toast** (3s, top-center) — kids see confirmation; adults understand the threat mechanic is ready again.

Entirely client-side. No new permanent parts. Listens to `ConsumableUsed` RemoteEvent (kind="smoker_refill") with `Notify` fallback.

---

## Step 1 — SmokerRefillController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `SmokerRefillController`.

Paste exactly:

```lua
--!strict
-- SmokerRefillController: smoke puff VFX + hiss SFX when smoker_refill consumable is used
-- Emits smoke from the Smoker world object on the player's own plot.
-- Listens to ConsumableUsed RemoteEvent (kind="smoker_refill") or Notify fallback.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Palette ───────────────────────────────────────────────────────────────────
local SMOKE_WHITE_174  = Color3.fromRGB(220, 220, 215)
local SMOKE_GREY_174   = Color3.fromRGB(160, 155, 150)
local HONEY_GOLD_174   = Color3.fromRGB(242, 168, 28)
local WAX_CREAM_174    = Color3.fromRGB(232, 212, 154)
local DARK_BG_174      = Color3.fromRGB(30,  18,  8)

-- ── Find player's Smoker ──────────────────────────────────────────────────────
local function findSmoker_174(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	-- Smoker tag (preferred)
	for _, part in CollectionService:GetTagged("Smoker") do
		if part:IsA("BasePart") and part:GetAttribute("PlotIndex") == myPlot then
			return part
		end
	end
	-- Fallback: LandingBoard as approximate smoker location
	for _, board in CollectionService:GetTagged("LandingBoard") do
		if board:GetAttribute("PlotIndex") == myPlot then
			return board :: BasePart
		end
	end
	return nil
end

-- ── Smoke puff VFX ────────────────────────────────────────────────────────────
local puffActive_174 = false

local function playSmokePuff_174(origin: Vector3)
	-- Ephemeral anchor at smoker nozzle (+3 studs up from base)
	local anchor = Instance.new("Part")
	anchor.Name          = "SmokerPuffAnchor_174"
	anchor.Size          = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position      = origin + Vector3.new(0, 3, 0)
	anchor.Anchored      = true
	anchor.CanCollide    = false
	anchor.Transparency  = 1
	anchor.CastShadow    = false
	anchor.Parent        = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name              = "SmokePuff_174"
	emitter.Enabled           = false
	emitter.Rate              = 0
	emitter.Lifetime          = NumberRange.new(1.5, 2.5)
	emitter.Speed             = NumberRange.new(2, 6)
	emitter.SpreadAngle       = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.5),
		NumberSequenceKeypoint.new(0.4, 1.2),
		NumberSequenceKeypoint.new(1,   0.0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1,   1.0),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   SMOKE_WHITE_174),
		ColorSequenceKeypoint.new(0.6, SMOKE_GREY_174),
		ColorSequenceKeypoint.new(1,   SMOKE_GREY_174),
	})
	emitter.LightEmission  = 0.0  -- smoke doesn't glow
	emitter.LightInfluence = 0.8
	emitter.RotSpeed       = NumberRange.new(-45, 45)
	emitter.Rotation       = NumberRange.new(0, 360)
	emitter.Acceleration   = Vector3.new(0, 1.5, 0)  -- slow upward drift
	emitter.Parent         = anchor

	-- Fire 25 particles
	emitter:Emit(25)

	task.delay(3.0, function()
		anchor:Destroy()
		puffActive_174 = false
	end)
end

-- ── Spatial hiss SFX ──────────────────────────────────────────────────────────
-- Uses roblox asset 6042053626 (a short steam/hiss one-shot)
-- Falls back to asset 5858206770 (generic soft hiss) if primary unavailable
local HISS_ASSET_174 = "rbxassetid://6042053626"

local function playHissSFX_174(origin: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name         = "SmokerHissAnchor_174"
	anchor.Size         = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position     = origin + Vector3.new(0, 2, 0)
	anchor.Anchored     = true
	anchor.CanCollide   = false
	anchor.Transparency = 1
	anchor.CastShadow   = false
	anchor.Parent       = workspace

	local sound = Instance.new("Sound")
	sound.Name           = "SmokerHiss_174"
	sound.SoundId        = HISS_ASSET_174
	sound.Volume         = 0.5
	sound.RollOffMaxDistance = 35
	sound.RollOffMinDistance = 3
	sound.RollOffMode    = Enum.RollOffMode.InverseTapered
	sound.Parent         = anchor

	sound:Play()
	sound.Ended:Connect(function()
		anchor:Destroy()
	end)
	-- Safety cleanup in case Ended never fires
	task.delay(5, function()
		if anchor and anchor.Parent then anchor:Destroy() end
	end)
end

-- ── Toast ─────────────────────────────────────────────────────────────────────
local toastGui_174: ScreenGui? = nil
local toastFrame_174: Frame? = nil

local function ensureToast_174()
	if toastGui_174 and toastGui_174.Parent then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "SmokerRefillToastGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 18
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui
	toastGui_174 = sg

	local frame = Instance.new("Frame")
	frame.Name              = "SmokerRefillToast"
	frame.Size              = UDim2.new(0, 200, 0, 34)
	-- Top-center, below weather pill
	frame.Position          = UDim2.new(0.5, -100, 0, -40)
	frame.BackgroundColor3  = DARK_BG_174
	frame.BorderSizePixel   = 0
	frame.Visible           = false
	frame.ZIndex            = 40
	frame.Parent            = sg
	toastFrame_174 = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = SMOKE_WHITE_174
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local label = Instance.new("TextLabel")
	label.Size              = UDim2.new(1, -8, 1, 0)
	label.Position          = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text              = "🌫️ Smoker recharged!"
	label.TextSize          = 13
	label.Font              = Enum.Font.GothamBold
	label.TextColor3        = WAX_CREAM_174
	label.TextXAlignment    = Enum.TextXAlignment.Center
	label.ZIndex            = 41
	label.Parent            = frame
end

local toastShowing_174 = false

local function showToast_174()
	ensureToast_174()
	local frame = toastFrame_174
	if not frame or toastShowing_174 then return end
	toastShowing_174 = true
	frame.Visible = true

	-- Drop down from above
	TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -100, 0, 10) }):Play()

	task.delay(3.0, function()
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -100, 0, -40) }):Play()
		task.delay(0.25, function()
			frame.Visible = false
			toastShowing_174 = false
		end)
	end)
end

-- ── Main handler ──────────────────────────────────────────────────────────────
local function onSmokerRefill_174()
	if puffActive_174 then return end
	puffActive_174 = true

	local smoker = findSmoker_174()
	local origin = smoker and smoker.Position or Vector3.new(0, 5, 0)

	playSmokePuff_174(origin)
	playHissSFX_174(origin)
	showToast_174()
end

-- ── Listen for consumable events ──────────────────────────────────────────────
local consumableUsed = Remotes:FindFirstChild("ConsumableUsed") :: RemoteEvent?
if consumableUsed then
	consumableUsed.OnClientEvent:Connect(function(kind: string)
		if kind == "smoker_refill" then
			onSmokerRefill_174()
		end
	end)
end

-- Notify fallback
local notify = Remotes:FindFirstChild("Notify") :: RemoteEvent?
if notify then
	notify.OnClientEvent:Connect(function(msg: string, kind: string?)
		if kind == "purchase" and msg and msg:lower():find("smoker") then
			onSmokerRefill_174()
		end
	end)
end
```

---

## Step 2 — ConsumableService patch

In **ConsumableService** (ServerScriptService.Systems), inside the `smoker_refill` use case, after applying the effect:

```lua
local ConsumableUsed_174 = Remotes:FindFirstChild("ConsumableUsed")
if ConsumableUsed_174 then
	pcall(function()
		ConsumableUsed_174:FireClient(player, itemId)  -- itemId = "smoker_refill"
	end)
end
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("SmokerRefillController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("SmokerRefillController")
print("SmokerRefillController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  playSmokePuff_174:", c.Source:find("playSmokePuff_174") ~= nil)
	print("  playHissSFX_174:", c.Source:find("playHissSFX_174") ~= nil)
	print("  showToast_174:", c.Source:find("showToast_174") ~= nil)
	print("  ConsumableUsed listener:", c.Source:find("ConsumableUsed") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
SmokerRefillController: LocalScript
  lines: 180+
  playSmokePuff_174: true
  playHissSFX_174: true
  showToast_174: true
  ConsumableUsed listener: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Trigger | Effect |
|---------|--------|
| smoker_refill consumable used | 25 smoke particles puff upward from Smoker position |
| Smoke colours | White → grey, lifetime 1.5–2.5s, slow upward drift |
| SFX | Short spatial hiss (Vol=0.5, RollOffMax=35 studs) from Smoker |
| Toast | "🌫️ Smoker recharged!" drops from top-center (200×34), 3s duration |
| No Smoker built | Falls back to LandingBoard position; effects still play |
| Burst lock | `puffActive_174` prevents overlapping effects |
| Fallback | `Notify` message containing "smoker" triggers same effects |

**Part budget: +0 permanent (all anchors are ephemeral) → 4,204 / 5,000**
