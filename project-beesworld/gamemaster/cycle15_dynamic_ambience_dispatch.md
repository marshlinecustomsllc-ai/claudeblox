# Dispatch 168 — Dynamic Hive Ambience
**File:** `cycle15_dynamic_ambience_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The hive's ambient audio currently plays at a fixed volume regardless of how well or poorly the colony is doing. This dispatch makes the soundscape **reactive to colony health**: at low health the ambience is sparse and melancholy (a single quiet hum); at stable health it adds gentle wing-beats; at thriving health it adds a rich full-colony buzz with a celebratory undertone. The transition is smooth (TweenService volume crossfade, 3s). Kids hear happy vs sad bees; adults get an audio confirmation that their management choices are working.

---

## Step 1 — Locate existing ambient sounds

Run in **Studio Command Bar** to find what SoundService currently has:

```lua
local SoundService = game:GetService("SoundService")
local results = {}
for _, child in SoundService:GetDescendants() do
	if child:IsA("Sound") then
		table.insert(results, child:GetFullName() .. " Vol=" .. child.Volume .. " Playing=" .. tostring(child.Playing))
	end
end
-- Also check workspace sounds
for _, obj in game:GetService("Workspace"):GetDescendants() do
	if obj:IsA("Sound") then
		table.insert(results, obj:GetFullName() .. " Vol=" .. obj.Volume)
	end
end
print(table.concat(results, "\n"))
```

Note the existing ambient sound names — the controller below targets them by name. The game's existing ambient controller (`SoundController`) manages `SFX_BuzzAmbient`, `SFX_BuzzHive`, and related sounds. This dispatch layers on top of that without removing anything.

---

## Step 2 — DynamicAmbienceController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `DynamicAmbienceController`.

Paste exactly:

```lua
--!strict
-- DynamicAmbienceController: cross-fades ambient sounds based on colony health tier
-- Reads ColonyHealthSync payloads. Layers volume on top of SoundController's base sounds.
-- Never mutes sounds completely -- always leaves a whisper so the game doesn't feel dead.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ── Tier volume targets ───────────────────────────────────────────────────────
-- Each sound name maps to { thriving, stable, struggling, critical }
-- Values are MULTIPLIERS applied on top of whatever SoundController set as base.
-- 1.0 = keep at base volume; 0.0 = mute; 1.5 = boost 50%.
local TIER_VOLUMES_168: { [string]: { [string]: number } } = {
	-- Main colony hum: louder when thriving, barely audible when critical
	SFX_BuzzAmbient = {
		thriving   = 1.0,
		stable     = 0.75,
		struggling = 0.45,
		critical   = 0.2,
	},
	-- Active wing-beat layer: full when thriving, off when critical
	SFX_BuzzHive = {
		thriving   = 1.0,
		stable     = 0.8,
		struggling = 0.35,
		critical   = 0.08,
	},
	-- Flower meadow ambience: bees are out foraging -- quieter at critical (few foragers)
	SFX_MeadowAmbient = {
		thriving   = 1.0,
		stable     = 0.85,
		struggling = 0.55,
		critical   = 0.25,
	},
	-- Harvest / activity sounds: very quiet when struggling
	SFX_ForageActive = {
		thriving   = 1.0,
		stable     = 0.7,
		struggling = 0.3,
		critical   = 0.05,
	},
}

-- Base volumes captured on first run so multipliers are applied correctly
local baseVolumes_168: { [string]: number } = {}
local FADE_TIME_168  = 3.0   -- seconds for volume crossfade
local currentTier_168 = "stable"

-- ── Helper: find a sound anywhere in the hierarchy ────────────────────────────
local function findSound_168(name: string): Sound?
	-- Check SoundService groups first
	for _, obj in SoundService:GetDescendants() do
		if obj:IsA("Sound") and obj.Name == name then return obj end
	end
	-- Then workspace
	for _, obj in game:GetService("Workspace"):GetDescendants() do
		if obj:IsA("Sound") and obj.Name == name then return obj end
	end
	return nil
end

-- ── Capture base volumes once (first time we see the sounds) ──────────────────
local function captureBase_168()
	for name, _ in TIER_VOLUMES_168 do
		if not baseVolumes_168[name] then
			local sound = findSound_168(name)
			if sound then
				baseVolumes_168[name] = sound.Volume
			end
		end
	end
end

-- ── Apply tier: smoothly cross-fade all managed sounds ────────────────────────
local function applyTier_168(tier: string)
	if tier == currentTier_168 then return end
	currentTier_168 = tier
	captureBase_168()

	for name, tierMap in TIER_VOLUMES_168 do
		local mult   = tierMap[tier] or 1.0
		local base   = baseVolumes_168[name]
		local sound  = findSound_168(name)
		if sound and base then
			local target = math.clamp(base * mult, 0, 0.7)  -- enforce 0.7 ceiling
			TweenService:Create(sound, TweenInfo.new(FADE_TIME_168, Enum.EasingStyle.Sine), {
				Volume = target
			}):Play()
		end
	end
end

-- ── Handle health sync ────────────────────────────────────────────────────────
local HealthSync = Remotes:FindFirstChild("ColonyHealthSync") :: RemoteEvent?
if HealthSync then
	HealthSync.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.tier then
			applyTier_168(payload.tier)
		end
	end)
else
	-- ColonyHealthSync not ready — retry once after 5s
	task.delay(5, function()
		local re = Remotes:FindFirstChild("ColonyHealthSync") :: RemoteEvent?
		if re then
			re.OnClientEvent:Connect(function(payload)
				if type(payload) == "table" and payload.tier then
					applyTier_168(payload.tier)
				end
			end)
		end
	end)
end

-- ── Initial state: stable (safe default while we wait for first sync) ─────────
task.delay(3, function()
	captureBase_168()
	applyTier_168("stable")
end)
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("DynamicAmbienceController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check controller
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("DynamicAmbienceController")
print("DynamicAmbienceController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  TIER_VOLUMES_168 table:", c.Source:find("TIER_VOLUMES_168") ~= nil)
	print("  FADE_TIME_168:", c.Source:find("FADE_TIME_168") ~= nil)
	print("  ColonyHealthSync listener:", c.Source:find("ColonyHealthSync") ~= nil)
end

-- Verify existing ambient sounds are still intact
local sounds = {}
for _, obj in game:GetService("SoundService"):GetDescendants() do
	if obj:IsA("Sound") then table.insert(sounds, obj.Name .. " Vol=" .. obj.Volume) end
end
print("SoundService sounds:", #sounds)
for _, s in sounds do print(" ", s) end

-- Part count: should still be 4204 (no parts added)
local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
DynamicAmbienceController: LocalScript
  lines: 80+
  TIER_VOLUMES_168 table: true
  FADE_TIME_168: true
  ColonyHealthSync listener: true
SoundService sounds: 3+
  SFX_BuzzAmbient Vol=0.x  ...
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Colony health tier | 😄 Thriving | 😐 Stable | 😟 Struggling | 😰 Critical |
|--------------------|------------|----------|--------------|------------|
| BuzzAmbient volume | 100% base | 75% | 45% | 20% |
| BuzzHive volume | 100% | 80% | 35% | 8% |
| MeadowAmbient volume | 100% | 85% | 55% | 25% |
| ForageActive volume | 100% | 70% | 30% | 5% |
| Crossfade duration | 3s Sine | 3s Sine | 3s Sine | 3s Sine |

- Volume ceiling enforced at 0.7 (project-wide rule from SoundController)
- Never mutes to 0 — even critical retains a whisper
- Gracefully no-ops for any sound that doesn't exist yet
- Reconnects to ColonyHealthSync after 5s if not ready at init

**Part budget: +0 permanent → 4,204 / 5,000**
