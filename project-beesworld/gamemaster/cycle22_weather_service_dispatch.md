# Dispatch 216 — WeatherService
**File:** `cycle22_weather_service_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture specifies a seasonal weather system that modifies foraging yield multipliers. The `WeatherBadgeController` (dispatch 213) is already wired to display `CurrentSeason` and `CurrentWeather` player attributes, but no server service writes those attributes yet. This dispatch adds **WeatherService**: a server Script that cycles through seasons (Spring → Summer → Autumn → Winter) on a configurable tick, picks a weighted-random weather state per tick, broadcasts `CurrentSeason` and `CurrentWeather` to all players, and adjusts Roblox `Lighting` and `Atmosphere` properties to visually match the current season/weather. ForagingService multiplier integration is included as a hook stub.

Zero new parts — Script only.

---

## Step 1 — WeatherService (ServerScriptService)

Open **ServerScriptService → Systems** and create a new **Script** named `WeatherService`.

Paste exactly:

```lua
--!strict
-- WeatherService: seasons + weather cycle. Broadcasts CurrentSeason/CurrentWeather
-- to all players. Adjusts Lighting and Atmosphere for visual variety.

local Players    = game:GetService("Players")
local Lighting   = game:GetService("Lighting")
local RunService = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local SEASON_DURATION_216 = 300     -- seconds per season (5 real minutes)
local WEATHER_TICK_216    = 60      -- seconds between weather re-rolls

-- ── Season definitions ───────────────────────────────────────────────────────
type SeasonDef216 = {
	name: string,
	clockTime: number,
	ambient: Color3,
	brightness: number,
	weatherWeights: { [string]: number },   -- relative weights for this season
}

local SEASONS_216: { SeasonDef216 } = {
	{
		name       = "Spring",
		clockTime  = 13.0,
		ambient    = Color3.fromRGB(180, 200, 220),
		brightness = 2.2,
		weatherWeights = { Sunny = 50, Overcast = 20, Drizzle = 20, Rain = 10 },
	},
	{
		name       = "Summer",
		clockTime  = 14.5,
		ambient    = Color3.fromRGB(220, 210, 180),
		brightness = 2.8,
		weatherWeights = { Sunny = 60, Overcast = 15, Drizzle = 10, Storm = 15 },
	},
	{
		name       = "Autumn",
		clockTime  = 12.0,
		ambient    = Color3.fromRGB(180, 160, 130),
		brightness = 1.8,
		weatherWeights = { Overcast = 40, Sunny = 25, Rain = 25, Fog = 10 },
	},
	{
		name       = "Winter",
		clockTime  = 10.5,
		ambient    = Color3.fromRGB(140, 160, 190),
		brightness = 1.4,
		weatherWeights = { Overcast = 45, Fog = 30, Sunny = 15, Rain = 10 },
	},
}

-- ── Weather definitions ───────────────────────────────────────────────────────
type WeatherDef216 = {
	forageMultiplier: number,
	atmosphereDensity: number,
	atmosphereColor: Color3,
}

local WEATHER_216: { [string]: WeatherDef216 } = {
	Sunny   = { forageMultiplier = 1.00, atmosphereDensity = 0.08, atmosphereColor = Color3.fromRGB(200, 220, 255) },
	Overcast = { forageMultiplier = 0.90, atmosphereDensity = 0.18, atmosphereColor = Color3.fromRGB(160, 170, 180) },
	Drizzle = { forageMultiplier = 0.90, atmosphereDensity = 0.22, atmosphereColor = Color3.fromRGB(140, 160, 190) },
	Rain    = { forageMultiplier = 0.80, atmosphereDensity = 0.28, atmosphereColor = Color3.fromRGB(120, 140, 170) },
	Storm   = { forageMultiplier = 0.60, atmosphereDensity = 0.35, atmosphereColor = Color3.fromRGB(100, 110, 150) },
	Fog     = { forageMultiplier = 0.85, atmosphereDensity = 0.30, atmosphereColor = Color3.fromRGB(180, 180, 175) },
}

-- ── State ─────────────────────────────────────────────────────────────────────
local currentSeasonIndex_216 = 1
local currentWeather_216     = "Sunny"
local seasonAcc_216          = 0
local weatherAcc_216         = 0

-- ── Weighted random pick ──────────────────────────────────────────────────────
local function weightedPick_216(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do total += w end
	local roll = math.random() * total
	local cum = 0
	for key, w in weights do
		cum += w
		if roll <= cum then return key end
	end
	-- fallback
	for key in weights do return key end
	return "Sunny"
end

-- ── Broadcast to players ──────────────────────────────────────────────────────
local function broadcast_216(season: string, weather: string)
	for _, p in Players:GetPlayers() do
		p:SetAttribute("CurrentSeason", season)
		p:SetAttribute("CurrentWeather", weather)
	end
end

-- Broadcast to newly joining players
Players.PlayerAdded:Connect(function(player)
	local season = SEASONS_216[currentSeasonIndex_216].name
	player:SetAttribute("CurrentSeason", season)
	player:SetAttribute("CurrentWeather", currentWeather_216)
end)

-- ── Apply Lighting + Atmosphere ───────────────────────────────────────────────
local function applyLighting_216(season: SeasonDef216, weatherName: string)
	local weather = WEATHER_216[weatherName] or WEATHER_216["Sunny"]

	-- Tween ClockTime over 30 seconds for smooth transition
	local targetClock = season.clockTime
	local startClock  = Lighting.ClockTime
	local elapsed = 0
	local TWEEN_DURATION = 30

	-- Use a simple RunService connection for smooth tween (avoid task.wait loops)
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local alpha = math.clamp(elapsed / TWEEN_DURATION, 0, 1)
		Lighting.ClockTime    = startClock + (targetClock - startClock) * alpha
		Lighting.Ambient      = season.ambient:Lerp(Lighting.Ambient, 1 - alpha) -- blend toward target
		Lighting.Brightness   = Lighting.Brightness + (season.brightness - Lighting.Brightness) * alpha * 0.1
		if alpha >= 1 then
			Lighting.ClockTime  = targetClock
			Lighting.Ambient    = season.ambient
			Lighting.Brightness = season.brightness
			conn:Disconnect()
		end
	end)

	-- Atmosphere
	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmos then
		atmos.Density = weather.atmosphereDensity
		atmos.Color   = weather.atmosphereColor
	end
end

-- ── ForagingService hook ──────────────────────────────────────────────────────
-- ForagingService can read this ModuleScript-style via a BindableEvent or
-- shared attribute. Here we write a global attribute to the workspace:
local function updateForageMultiplier_216(weatherName: string)
	local weather = WEATHER_216[weatherName] or WEATHER_216["Sunny"]
	game:GetService("Workspace"):SetAttribute("WeatherForageMultiplier", weather.forageMultiplier)
end

-- ── Main tick ─────────────────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt: number)
	seasonAcc_216  += dt
	weatherAcc_216 += dt

	-- Weather re-roll
	if weatherAcc_216 >= WEATHER_TICK_216 then
		weatherAcc_216 = 0
		local season = SEASONS_216[currentSeasonIndex_216]
		currentWeather_216 = weightedPick_216(season.weatherWeights)
		broadcast_216(season.name, currentWeather_216)
		applyLighting_216(season, currentWeather_216)
		updateForageMultiplier_216(currentWeather_216)
	end

	-- Season advance
	if seasonAcc_216 >= SEASON_DURATION_216 then
		seasonAcc_216 = 0
		currentSeasonIndex_216 = (currentSeasonIndex_216 % #SEASONS_216) + 1
		local season = SEASONS_216[currentSeasonIndex_216]
		-- Force a weather re-roll on season change
		weatherAcc_216 = WEATHER_TICK_216
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	local season = SEASONS_216[currentSeasonIndex_216]
	currentWeather_216 = weightedPick_216(season.weatherWeights)
	broadcast_216(season.name, currentWeather_216)
	applyLighting_216(season, currentWeather_216)
	updateForageMultiplier_216(currentWeather_216)
end)
```

---

## Step 2 — ForagingService multiplier integration

Open **ServerScriptService → Systems → ForagingService** and add a read of the workspace attribute when calculating foraging yield:

```lua
-- In ForagingService, when computing nectar per return trip:
local weatherMult = (workspace:GetAttribute("WeatherForageMultiplier") :: number?) or 1.0
local nectarYield = baseYield * weatherMult * otherMultipliers
```

This is non-breaking — if `WeatherForageMultiplier` is not set yet (WeatherService hasn't ticked), it defaults to 1.0 (no penalty).

---

## Step 3 — Verification sweep

Run in **Studio Command Bar** (Edit mode):

```lua
local SPS = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local svc = SPS and SPS:FindFirstChild("WeatherService")
print("WeatherService:", svc and svc.ClassName or "MISSING")
if svc then
	local lines = select(2, svc.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  SEASONS_216:", svc.Source:find("SEASONS_216") ~= nil)
	print("  WEATHER_216:", svc.Source:find("WEATHER_216") ~= nil)
	print("  broadcast_216:", svc.Source:find("broadcast_216") ~= nil)
	print("  applyLighting_216:", svc.Source:find("applyLighting_216") ~= nil)
	print("  WeatherForageMultiplier:", svc.Source:find("WeatherForageMultiplier") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode (after 5+ seconds):**

```lua
local lp = game:GetService("Players").LocalPlayer
print("CurrentSeason:", lp:GetAttribute("CurrentSeason"))
print("CurrentWeather:", lp:GetAttribute("CurrentWeather"))
print("WeatherForageMultiplier:", workspace:GetAttribute("WeatherForageMultiplier"))
```

**Expected output:**
```
WeatherService: Script
  lines: 140+
  SEASONS_216: true
  WEATHER_216: true
  broadcast_216: true
  applyLighting_216: true
  WeatherForageMultiplier: true
Total parts: 4204  (expect 4204)

-- After 5+ seconds in Play mode:
CurrentSeason: Spring      (or whichever season starts)
CurrentWeather: Sunny      (or weighted random pick)
WeatherForageMultiplier: 1  (Sunny = 1.0 multiplier)
```

---

## Season / Weather cycle summary

| Season | Clock | Brightness | Dominant weather |
|---|---|---|---|
| Spring | 13:00 | 2.2 | 50% Sunny, 20% Overcast, 20% Drizzle |
| Summer | 14:30 | 2.8 | 60% Sunny, risk of Storm |
| Autumn | 12:00 | 1.8 | 40% Overcast, rain likely |
| Winter | 10:30 | 1.4 | 45% Overcast, 30% Fog |

| Weather | Foraging yield | Atmosphere density |
|---|---|---|
| Sunny | 100% | 0.08 (clear) |
| Overcast | 90% | 0.18 |
| Drizzle | 90% | 0.22 |
| Fog | 85% | 0.30 |
| Rain | 80% | 0.28 |
| Storm | 60% | 0.35 |

- Season duration: 5 minutes real-time (300s) — full cycle every 20 minutes
- Weather re-rolls every 60s within each season, weighted by season
- ClockTime tweens over 30s for a smooth day arc (not a snap)
- Atmosphere Density and Color update instantly on weather change
- ForageMultiplier broadcast via `Workspace:SetAttribute` so ForagingService can read it without a RemoteEvent

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Script only — no new parts or instances)*
