# Dispatch 185 — Bear Offering Altar Glow
**File:** `cycle17_bear_altar_glow_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The BearAltar world object is the most dramatic decision point in the game (appease Old Molasses for a permanent passive ally vs. banish him for a harder-raids/Royal Jelly income path), but it currently sits dark and silent. Players don't notice it building toward a decision moment. This dispatch adds a **Bear Offering Altar Glow**: two phases driven by the player's `ThreatStage` attribute (set by ThreatService):

- **Stage 4–5 (warming):** The altar PointLight pulses amber, slow and ominous. A "🐻 Something stirs near the altar…" whisper label fades in near the altar's screen position.
- **Stage 6 (decision imminent):** The altar brightens to full gold, the label reads "🐻 The moment is here!", and the proximity prompt glows.

On `BearOfferingMade` RemoteEvent (the player's permanent choice), a brief golden/purple burst fires (gold = appease, purple = banish) and the altar returns to neutral.

This is the only dispatch that uses a server attribute change (`ThreatStage`) — the client already receives this via `ThreatService:FireClient(player, stage)` through `BearStageUpdate` RemoteEvent.

Entirely client-side. Zero new permanent parts.

---

## Step 1 — BearAltarController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BearAltarController`.

Paste exactly:

```lua
--!strict
-- BearAltarController: pulsing glow + whisper label on BearAltar as ThreatStage rises.
-- Listens to BearStageUpdate RemoteEvent (stage: number) and BearOfferingMade (choice: string).
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local WARM_STAGE_185   = 4     -- stage at which altar starts glowing
local CRIT_STAGE_185   = 6     -- stage at which altar reaches full brightness
local PULSE_SLOW_185   = 2.5   -- seconds per pulse at stage 4-5
local PULSE_FAST_185   = 0.9   -- seconds per pulse at stage 6
local BURST_TIME_185   = 1.2   -- seconds for the offering burst effect

-- ── Palette ───────────────────────────────────────────────────────────────────
local ALTAR_WARM_185   = Color3.fromRGB(200, 110,  20)   -- stage 4-5 amber glow
local ALTAR_CRIT_185   = Color3.fromRGB(255, 180,  20)   -- stage 6 bright gold
local APPEASE_COLOR_185 = Color3.fromRGB(255, 200,  40)  -- golden burst (appease)
local BANISH_COLOR_185  = Color3.fromRGB(140,  40, 200)  -- purple burst (banish)
local NEUTRAL_185      = Color3.fromRGB(255, 200, 100)   -- resting altar light
local WAX_CREAM_185    = Color3.fromRGB(232, 212, 154)
local DARK_BG_185      = Color3.fromRGB( 30,  18,   8)

-- ── Find the BearAltar part ───────────────────────────────────────────────────
local function findAltar_185(): BasePart?
	for _, obj in CollectionService:GetTagged("BearAltar") do
		if obj:IsA("BasePart") then return obj end
	end
	-- Fallback: search by name
	for _, obj in workspace:GetDescendants() do
		if obj.Name == "BearAltar" and obj:IsA("BasePart") then return obj end
	end
	return nil
end

-- ── Ensure altar has a PointLight ────────────────────────────────────────────
local function getAltarLight_185(altar: BasePart): PointLight
	local existing = altar:FindFirstChildOfClass("PointLight")
	if existing then return existing end

	local light = Instance.new("PointLight")
	light.Name       = "AltarGlow_185"
	light.Color      = NEUTRAL_185
	light.Brightness = 0.4
	light.Range      = 8
	light.Shadows    = false
	light.Parent     = altar
	return light
end

-- ── Whisper label ─────────────────────────────────────────────────────────────
local whisperLabel_185: TextLabel? = nil

local function buildWhisper_185(): TextLabel
	local sg = Instance.new("ScreenGui")
	sg.Name           = "BearAltarGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 28
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "WhisperLabel"
	lbl.Size               = UDim2.new(0, 280, 0, 24)
	lbl.Position           = UDim2.new(0.5, -140, 0.75, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = ""
	lbl.TextSize           = 13
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_185
	lbl.TextTransparency   = 1
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 42
	lbl.Parent             = sg
	return lbl
end

local function showWhisper_185(text: string)
	if not whisperLabel_185 then whisperLabel_185 = buildWhisper_185() end
	whisperLabel_185.Text = text
	TweenService:Create(whisperLabel_185, TweenInfo.new(0.6, Enum.EasingStyle.Sine),
		{ TextTransparency = 0 }):Play()
end

local function hideWhisper_185()
	if not whisperLabel_185 then return end
	TweenService:Create(whisperLabel_185, TweenInfo.new(0.4, Enum.EasingStyle.Sine),
		{ TextTransparency = 1 }):Play()
end

-- ── Pulse state ───────────────────────────────────────────────────────────────
local pulseConn_185: RBXScriptConnection? = nil
local pulseT_185   = 0
local currentStage_185 = 0

local function stopPulse_185()
	if pulseConn_185 then pulseConn_185:Disconnect(); pulseConn_185 = nil end
end

local function startPulse_185(altar: BasePart, stage: number)
	stopPulse_185()
	local light = getAltarLight_185(altar)

	local color  = if stage >= CRIT_STAGE_185 then ALTAR_CRIT_185 else ALTAR_WARM_185
	local period = if stage >= CRIT_STAGE_185 then PULSE_FAST_185 else PULSE_SLOW_185
	local maxBright = if stage >= CRIT_STAGE_185 then 2.8 else 1.6
	local minBright = 0.3

	pulseT_185 = 0
	pulseConn_185 = RunService.Heartbeat:Connect(function(dt)
		pulseT_185 = pulseT_185 + dt
		local phase = math.sin(pulseT_185 / period * math.pi) * 0.5 + 0.5
		light.Brightness = minBright + (maxBright - minBright) * phase
		light.Color      = color
	end)
end

local function resetAltar_185(altar: BasePart)
	stopPulse_185()
	local light = getAltarLight_185(altar)
	TweenService:Create(light, TweenInfo.new(1.0, Enum.EasingStyle.Sine),
		{ Brightness = 0.4, Color = NEUTRAL_185 }):Play()
	hideWhisper_185()
end

-- ── Offering burst ────────────────────────────────────────────────────────────
local function playOfferingBurst_185(altar: BasePart, choice: string)
	stopPulse_185()
	hideWhisper_185()

	local burstColor = if choice == "appease" then APPEASE_COLOR_185 else BANISH_COLOR_185
	local light = getAltarLight_185(altar)

	-- Flash bright then fade
	light.Brightness = 6
	light.Color      = burstColor
	TweenService:Create(light, TweenInfo.new(BURST_TIME_185, Enum.EasingStyle.Sine),
		{ Brightness = 0.4, Color = NEUTRAL_185 }):Play()

	-- Fullscreen flash (brief)
	local sg = Instance.new("ScreenGui")
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 50
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	local flash = Instance.new("Frame")
	flash.Size                    = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3        = burstColor
	flash.BackgroundTransparency  = 0.5
	flash.BorderSizePixel         = 0
	flash.ZIndex                  = 60
	flash.Parent                  = sg

	TweenService:Create(flash, TweenInfo.new(BURST_TIME_185, Enum.EasingStyle.Sine),
		{ BackgroundTransparency = 1 }):Play()
	task.delay(BURST_TIME_185 + 0.1, function() sg:Destroy() end)
end

-- ── Apply stage ───────────────────────────────────────────────────────────────
local function applyStage_185(stage: number)
	currentStage_185 = stage
	local altar = findAltar_185()
	if not altar then return end

	if stage < WARM_STAGE_185 then
		resetAltar_185(altar)
	elseif stage < CRIT_STAGE_185 then
		startPulse_185(altar, stage)
		showWhisper_185("🐻 Something stirs near the altar…")
	else
		startPulse_185(altar, stage)
		showWhisper_185("🐻 The moment is here!")
	end
end

-- ── Listen to RemoteEvents ────────────────────────────────────────────────────
local function connectAltarRemotes_185()
	local stageUpdate = Remotes:FindFirstChild("BearStageUpdate") :: RemoteEvent?
	if stageUpdate then
		stageUpdate.OnClientEvent:Connect(function(stage: number?)
			applyStage_185(stage or 0)
		end)
	end

	local offeringMade = Remotes:FindFirstChild("BearOfferingMade") :: RemoteEvent?
	if offeringMade then
		offeringMade.OnClientEvent:Connect(function(choice: string?)
			local altar = findAltar_185()
			if altar then
				playOfferingBurst_185(altar, choice or "appease")
			end
		end)
	end
end

-- Also read current ThreatStage attribute on init in case client joined mid-threat
task.delay(1.5, function()
	connectAltarRemotes_185()
	local stage = player:GetAttribute("ThreatStage") :: number?
	if stage then applyStage_185(stage) end
end)

-- Attribute watcher fallback
player:GetAttributeChangedSignal("ThreatStage"):Connect(function()
	local stage = player:GetAttribute("ThreatStage") :: number?
	applyStage_185(stage or 0)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BearAltarController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BearAltarController")
print("BearAltarController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  applyStage_185:", c.Source:find("applyStage_185") ~= nil)
	print("  playOfferingBurst_185:", c.Source:find("playOfferingBurst_185") ~= nil)
	print("  BearStageUpdate listener:", c.Source:find("BearStageUpdate") ~= nil)
	print("  BearOfferingMade listener:", c.Source:find("BearOfferingMade") ~= nil)
end

-- Check BearAltar tagged part
local CS = game:GetService("CollectionService")
local altars = CS:GetTagged("BearAltar")
print("BearAltar tagged parts:", #altars, "(expect 1 — if 0, altar needs BearAltar tag)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
BearAltarController: LocalScript
  lines: 190+
  applyStage_185: true
  playOfferingBurst_185: true
  BearStageUpdate listener: true
  BearOfferingMade listener: true
BearAltar tagged parts: 1  (expect 1)
Total parts: 4204  (expect 4204)
```

---

## Step 4 — Tag the BearAltar part (if not already tagged)

If the BearAltar world object doesn't yet have the `BearAltar` CollectionService tag, run in **Studio Command Bar**:

```lua
-- Find the altar by name and tag it
for _, obj in game:GetService("Workspace"):GetDescendants() do
	if obj.Name == "BearAltar" and obj:IsA("BasePart") then
		game:GetService("CollectionService"):AddTag(obj, "BearAltar")
		print("Tagged:", obj:GetFullName())
	end
end
```

---

## Behaviour summary

| ThreatStage | Altar glow | Whisper label |
|-------------|-----------|---------------|
| 0–3 | Dim neutral amber (0.4 brightness) | Hidden |
| 4–5 | Amber pulse (0.3–1.6 brightness, 2.5s period) | "🐻 Something stirs near the altar…" fades in |
| 6 | Bright gold pulse (0.3–2.8, 0.9s period) | "🐻 The moment is here!" |
| BearOfferingMade (appease) | Flash brightness 6 → gold burst → fade | Hidden |
| BearOfferingMade (banish) | Flash brightness 6 → purple burst → fade | Hidden |
| Player joins mid-threat | ThreatStage attribute read on init; correct state applied immediately |

**Part budget: +0 permanent → 4,204 / 5,000**
*(AltarGlow_185 PointLight is a child of the existing BearAltar BasePart — no new parts)*
