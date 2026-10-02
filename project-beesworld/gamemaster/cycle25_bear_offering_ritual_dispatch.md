# Dispatch 238 — Bear Offering Ritual Light
**File:** `cycle25_bear_offering_ritual_dispatch.md`
**Cycle:** 25
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The BearAltar is the most dramatic moment in the game — the point where the player decides to appease Old Molasses (permanent sacrifice) or banish them forever (permanent fork). The altar has a glow from Dispatch 227 (Bear Altar Glow Controller), but when the player actually walks up to the altar to make the choice, there is no additional atmospheric shift to mark the gravity of the moment. This dispatch adds a **Bear Offering Ritual Light**: a proximity-triggered particle burst and camera-space colour shift when the player enters a 10-stud radius of the BearAltar, creating a brief "the ritual begins" atmosphere that makes the decision feel weighty and ceremonial.

For kids: the altar sparkles and the world goes slightly darker when you approach — spooky and exciting, it signals "this is important." For adults: the atmospheric shift communicates narrative weight; the permanent fork feels like a real decision rather than a UI button press.

---

## Step 1 — BearRitualController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BearRitualController`.

Paste exactly:

```lua
--!strict
-- BearRitualController: proximity-triggered ritual atmosphere at BearAltar.
-- Particle burst + ColorCorrection shift when player within RITUAL_RADIUS_238.
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService  = game:GetService("CollectionService")
local TweenService       = game:GetService("TweenService")
local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")
local Lighting           = game:GetService("Lighting")

local localPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local RITUAL_RADIUS_238     = 10.0   -- studs to BearAltar centre to trigger
local CHECK_INTERVAL_238    = 0.5    -- seconds between proximity checks
local ENTER_FADE_238        = 0.80   -- seconds to transition into ritual state
local EXIT_FADE_238         = 1.20   -- seconds to transition out of ritual state
local SCAN_INTERVAL_238     = 10.0   -- seconds between altar discovery scans

-- ColorCorrection deltas applied on ritual entry (added to existing lighting)
-- These create a slight desaturation + red-amber tint
local CC_SATURATION_238  = -0.25
local CC_BRIGHTNESS_238  = -0.08
local CC_CONTRAST_238    =  0.15
local CC_TINT_238        = Color3.fromRGB(230, 180, 130)   -- warm ominous amber

-- Ritual spark emitter config
local SPARK_RATE_238    = 18     -- particles per second during ritual
local SPARK_COLOR_238   = Color3.fromRGB(200, 100, 40)   -- deep ember
local SPARK_SPEED_238   = 3.5
local SPARK_LIFETIME_238 = 1.2

-- Sound (low ominous drone, brief)
local RITUAL_SOUND_ID_238 = "rbxassetid://6333823393"   -- low ceremonial tone
local RITUAL_SOUND_VOL_238 = 0.40

-- ── State ─────────────────────────────────────────────────────────────────────
local altarPart_238: BasePart? = nil
local ritualActive_238 = false
local colorCorrection_238: ColorCorrectionEffect? = nil
local sparkEmitter_238: ParticleEmitter? = nil
local ritualSound_238: Sound? = nil

-- ── Build effects (created lazily when altar found) ───────────────────────────
local function buildEffects_238(altar: BasePart)
	-- ColorCorrectionEffect parented to Lighting (global effect)
	local existing = Lighting:FindFirstChild("RitualCC_238") :: ColorCorrectionEffect?
	if existing then
		colorCorrection_238 = existing
	else
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name       = "RitualCC_238"
		cc.Enabled    = true
		cc.Saturation = 0       -- start neutral (not shifted)
		cc.Brightness = 0
		cc.Contrast   = 0
		cc.TintColor  = Color3.new(1, 1, 1)
		cc.Parent     = Lighting
		colorCorrection_238 = cc
	end

	-- ParticleEmitter on the altar part
	local existingE = altar:FindFirstChild("RitualSpark_238") :: ParticleEmitter?
	if existingE then
		sparkEmitter_238 = existingE
	else
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name          = "RitualSpark_238"
		emitter.Rate          = 0   -- off by default, enabled on ritual entry
		emitter.Color         = ColorSequence.new(SPARK_COLOR_238)
		emitter.Size          = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.10),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency  = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Speed         = NumberRange.new(SPARK_SPEED_238 * 0.7, SPARK_SPEED_238 * 1.3)
		emitter.Lifetime      = NumberRange.new(SPARK_LIFETIME_238 * 0.8, SPARK_LIFETIME_238 * 1.2)
		emitter.SpreadAngle   = Vector2.new(30, 30)
		emitter.LightEmission = 0.6
		emitter.LightInfluence = 0.4
		emitter.Parent        = altar
		sparkEmitter_238 = emitter
	end

	-- Sound in PlayerGui
	local pg = localPlayer:WaitForChild("PlayerGui")
	local existingS = pg:FindFirstChild("RitualSound_238") :: Sound?
	if existingS then
		ritualSound_238 = existingS
	else
		local snd = Instance.new("Sound")
		snd.Name          = "RitualSound_238"
		snd.SoundId       = RITUAL_SOUND_ID_238
		snd.Volume        = 0
		snd.Looped        = false
		snd.PlaybackSpeed = 0.85
		snd.Parent        = pg
		ritualSound_238 = snd
	end
end

-- ── Enter / exit ritual atmosphere ───────────────────────────────────────────
local function enterRitual_238()
	if ritualActive_238 then return end
	ritualActive_238 = true

	-- Colour correction shift
	if colorCorrection_238 then
		TweenService:Create(colorCorrection_238, TweenInfo.new(ENTER_FADE_238, Enum.EasingStyle.Sine), {
			Saturation = CC_SATURATION_238,
			Brightness = CC_BRIGHTNESS_238,
			Contrast   = CC_CONTRAST_238,
			TintColor  = CC_TINT_238,
		}):Play()
	end

	-- Spark burst
	if sparkEmitter_238 then sparkEmitter_238.Rate = SPARK_RATE_238 end

	-- Sound
	if ritualSound_238 then
		ritualSound_238.Volume = 0
		ritualSound_238:Play()
		TweenService:Create(ritualSound_238, TweenInfo.new(ENTER_FADE_238, Enum.EasingStyle.Sine), {
			Volume = RITUAL_SOUND_VOL_238,
		}):Play()
	end
end

local function exitRitual_238()
	if not ritualActive_238 then return end
	ritualActive_238 = false

	-- Colour correction reset
	if colorCorrection_238 then
		TweenService:Create(colorCorrection_238, TweenInfo.new(EXIT_FADE_238, Enum.EasingStyle.Sine), {
			Saturation = 0,
			Brightness = 0,
			Contrast   = 0,
			TintColor  = Color3.new(1, 1, 1),
		}):Play()
	end

	-- Stop sparks
	if sparkEmitter_238 then sparkEmitter_238.Rate = 0 end

	-- Fade out sound
	if ritualSound_238 then
		TweenService:Create(ritualSound_238, TweenInfo.new(EXIT_FADE_238, Enum.EasingStyle.Sine), {
			Volume = 0,
		}):Play()
		task.delay(EXIT_FADE_238, function()
			if ritualSound_238 then ritualSound_238:Stop() end
		end)
	end
end

-- ── Proximity check ───────────────────────────────────────────────────────────
local checkAcc_238 = 0
RunService.Heartbeat:Connect(function(dt: number)
	checkAcc_238 += dt
	if checkAcc_238 < CHECK_INTERVAL_238 then return end
	checkAcc_238 = 0

	if not altarPart_238 then return end
	local char = localPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return end

	local dist = (hrp.Position - altarPart_238.Position).Magnitude
	if dist <= RITUAL_RADIUS_238 and not ritualActive_238 then
		enterRitual_238()
	elseif dist > RITUAL_RADIUS_238 and ritualActive_238 then
		exitRitual_238()
	end
end)

-- ── Altar discovery ───────────────────────────────────────────────────────────
local scanAcc_238 = 0
RunService.Heartbeat:Connect(function(dt: number)
	if altarPart_238 then return end
	scanAcc_238 += dt
	if scanAcc_238 < SCAN_INTERVAL_238 then return end
	scanAcc_238 = 0
	for _, inst in CollectionService:GetTagged("BearAltar") do
		if inst:IsA("BasePart") then
			altarPart_238 = inst
			buildEffects_238(inst)
			break
		end
	end
end)

CollectionService:GetInstanceAddedSignal("BearAltar"):Connect(function(inst)
	if inst:IsA("BasePart") and not altarPart_238 then
		task.delay(0.5, function()
			altarPart_238 = inst
			buildEffects_238(inst)
		end)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(5, function()
	for _, inst in CollectionService:GetTagged("BearAltar") do
		if inst:IsA("BasePart") then
			altarPart_238 = inst
			buildEffects_238(inst)
			break
		end
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BearRitualController"))
```

---

## Step 3 — Verify BearAltar tag

The BearAltar Part must be tagged `BearAltar` in CollectionService. This tag was specified in the ThreatZone build from the Old Molasses system. Confirm with the Studio Command Bar:

```lua
local CS = game:GetService("CollectionService")
local altars = CS:GetTagged("BearAltar")
print("BearAltar tagged:", #altars, "(expect 1)")
if altars[1] then print("Altar:", altars[1]:GetFullName()) end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode, walk your character to within 10 studs of the BearAltar):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BearRitualController")
print("BearRitualController:", c and c.ClassName or "MISSING")

local L = game:GetService("Lighting")
local cc = L:FindFirstChild("RitualCC_238")
print("RitualCC_238:", cc ~= nil, cc and "Saturation=" .. cc.Saturation or "")

-- Check spark emitter on altar
local CS = game:GetService("CollectionService")
local altars = CS:GetTagged("BearAltar")
if altars[1] then
	local e = altars[1]:FindFirstChild("RitualSpark_238")
	print("RitualSpark_238:", e ~= nil, e and "Rate=" .. e.Rate or "")
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| Distance to BearAltar | State | Effect |
|---|---|---|
| > 10 studs | Inactive | Normal lighting, no sparks, no sound |
| ≤ 10 studs | Ritual active | -0.25 saturation, -0.08 brightness, +0.15 contrast, amber tint, ember sparks, ceremonial tone |
| Walk away | Exiting (1.2s) | Smooth return to normal — CC resets to neutral, sparks stop, sound fades |

- ColorCorrectionEffect applied globally (to Lighting) — entire scene shifts, not just altar area
- CC values are subtle: desaturation makes the world feel muted, amber tint adds ominous warmth
- `RitualCC_238` created neutrally — if player never approaches the altar it has zero visual impact
- Spark emitter Rate=0 between visits — no particle cost during normal play
- 0.5s proximity poll on a Heartbeat accumulator keeps CPU cost minimal (not every frame)
- BearAltarGlowController (D227) continues to pulse independently — both effects layer

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(ColorCorrectionEffect in Lighting, ParticleEmitter inside BearAltar part, Sound in PlayerGui — no BaseParts)*
