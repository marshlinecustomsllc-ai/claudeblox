# Dispatch 189 — Seasonal Weather Cycle
**File:** `cycle18_weather_cycle_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The game currently has a static environment — the same flower yields and hatch rates all the time. This dispatch adds a **Seasonal Weather Cycle**: a server-side clock (`WeatherService`) that advances through four seasons on a 20-minute real-time cycle (5 minutes each: Spring → Summer → Autumn → Winter), broadcasting the current season and weather type to all clients via the existing `Notify` RemoteEvent. Each season modifies:

- **Flower yield multiplier** (per species — some thrive in summer, others in spring rain)
- **Bee hatch rate multiplier** (cold weather slows the colony)
- **Hive temperature drift** (summer pushes HiveTemperature up, winter pulls it down)

A client-side `WeatherController` LocalScript reads the `SeasonWeather` player attribute (set by WeatherService via SetAttribute) and renders a subtle ambient sky-tint overlay (a transparent Frame over the screen that shifts colour with season) plus a status pill in the HUD showing the current season icon and weather type. The architecture already has weather mechanics referenced (Rain-to-BloomRush Signature Moment) — this dispatch builds the underlying cycle that drives them.

**DataService migration:** v16 → v17 adds `season` and `weatherType` to the player profile for session persistence.

Zero new permanent parts.

---

## Step 1 — DataService v16 → v17 migration

Open **ServerScriptService → Systems → DataService** and find the `MIGRATIONS` table. Add at the end:

```lua
[17] = function(data)
    data.season      = data.season      or "Spring"
    data.weatherType = data.weatherType or "Clear"
    return data
end,
```

Also update the version constant at the top of DataService:
```lua
local DATA_VERSION = 17
```

---

## Step 2 — WeatherService (ServerScriptService)

Open **ServerScriptService → Systems** and create a new **ModuleScript** named `WeatherService`.

Paste exactly:

```lua
--!strict
-- WeatherService: seasonal weather cycle + per-season yield/hatch/temp modifiers.
-- Advances Spring→Summer→Autumn→Winter every SEASON_DURATION_189 seconds.
-- Broadcasts via Notify RemoteEvent; writes SeasonWeather attribute to each player.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify  = Remotes:WaitForChild("Notify") :: RemoteEvent

-- ── Config ────────────────────────────────────────────────────────────────────
local SEASON_DURATION_189 = 300   -- 5 minutes per season in real seconds
local SEASONS_189 = { "Spring", "Summer", "Autumn", "Winter" }

-- ── Season data ───────────────────────────────────────────────────────────────
type SeasonData = {
	yieldMult:    number,   -- multiplier on all flower NectarRate
	hatchMult:    number,   -- multiplier on PopulationService hatch rate
	tempDrift:    number,   -- °C/s added to HiveTemperature (positive=warm, negative=cool)
	weatherTypes: { string },  -- possible weather states for this season
	icon:         string,
}

local SEASON_DATA_189: { [string]: SeasonData } = {
	Spring = {
		yieldMult    = 1.15,
		hatchMult    = 1.10,
		tempDrift    = 0.0,
		weatherTypes = { "Clear", "Rain", "BloomRush" },
		icon         = "🌸",
	},
	Summer = {
		yieldMult    = 1.30,
		hatchMult    = 1.25,
		tempDrift    = 0.004,   -- slowly warms hive each second
		weatherTypes = { "Clear", "Heatwave", "Thunderstorm" },
		icon         = "☀️",
	},
	Autumn = {
		yieldMult    = 0.85,
		hatchMult    = 0.90,
		tempDrift    = -0.002,
		weatherTypes = { "Clear", "Overcast", "FoggyMorning" },
		icon         = "🍂",
	},
	Winter = {
		yieldMult    = 0.55,
		hatchMult    = 0.65,
		tempDrift    = -0.008,  -- significant temperature drop
		weatherTypes = { "Clear", "FrostWarning", "Snowfall" },
		icon         = "❄️",
	},
}

-- ── State ─────────────────────────────────────────────────────────────────────
local currentSeasonIdx_189  = 1
local currentWeatherType_189 = "Clear"
local seasonTimer_189       = 0

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function pickWeather_189(season: string): string
	local data = SEASON_DATA_189[season]
	if not data then return "Clear" end
	local types = data.weatherTypes
	return types[math.random(1, #types)]
end

local function broadcastWeather_189(season: string, weather: string)
	local data = SEASON_DATA_189[season]
	local icon = data and data.icon or "🌤️"

	for _, p in Players:GetPlayers() do
		pcall(function()
			p:SetAttribute("SeasonWeather",
				season .. "|" .. weather .. "|"
				.. (data and tostring(data.yieldMult) or "1")
				.. "|" .. (data and tostring(data.hatchMult) or "1"))
			Notify:FireClient(p,
				icon .. " Season: " .. season .. " — " .. weather)
		end)
	end
end

-- ── Temperature drift (applied each Heartbeat) ────────────────────────────────
local hbConn_189: RBXScriptConnection? = nil

local function startTempDrift_189()
	if hbConn_189 then hbConn_189:Disconnect() end
	hbConn_189 = RunService.Heartbeat:Connect(function(dt)
		local season = SEASONS_189[currentSeasonIdx_189]
		local data   = SEASON_DATA_189[season]
		if not data or data.tempDrift == 0 then return end

		for _, p in Players:GetPlayers() do
			pcall(function()
				local t = p:GetAttribute("HiveTemperature") :: number?
				if not t then return end
				local newT = math.max(0, math.min(60, t + data.tempDrift * dt))
				p:SetAttribute("HiveTemperature", newT)
			end)
		end
	end)
end

-- ── Season advancement ────────────────────────────────────────────────────────
local function advanceSeason_189()
	currentSeasonIdx_189  = (currentSeasonIdx_189 % #SEASONS_189) + 1
	local season          = SEASONS_189[currentSeasonIdx_189]
	currentWeatherType_189 = pickWeather_189(season)
	broadcastWeather_189(season, currentWeatherType_189)
	startTempDrift_189()
end

-- ── Main clock ────────────────────────────────────────────────────────────────
local clockConn_189: RBXScriptConnection? = nil

local function startClock_189()
	-- Broadcast initial season immediately
	local initialSeason = SEASONS_189[currentSeasonIdx_189]
	currentWeatherType_189 = pickWeather_189(initialSeason)
	broadcastWeather_189(initialSeason, currentWeatherType_189)
	startTempDrift_189()

	clockConn_189 = RunService.Heartbeat:Connect(function(dt)
		seasonTimer_189 = seasonTimer_189 + dt
		if seasonTimer_189 >= SEASON_DURATION_189 then
			seasonTimer_189 = 0
			advanceSeason_189()
		end
	end)
end

-- ── New player: send current season immediately ───────────────────────────────
Players.PlayerAdded:Connect(function(p)
	task.wait(2)   -- wait for DataService load
	local season = SEASONS_189[currentSeasonIdx_189]
	local data   = SEASON_DATA_189[season]
	pcall(function()
		p:SetAttribute("SeasonWeather",
			season .. "|" .. currentWeatherType_189 .. "|"
			.. (data and tostring(data.yieldMult) or "1")
			.. "|" .. (data and tostring(data.hatchMult) or "1"))
	end)
end)

-- ── Public API ────────────────────────────────────────────────────────────────
local WeatherService_189 = {}

function WeatherService_189.GetCurrentSeason(): string
	return SEASONS_189[currentSeasonIdx_189]
end

function WeatherService_189.GetYieldMult(): number
	local data = SEASON_DATA_189[SEASONS_189[currentSeasonIdx_189]]
	return data and data.yieldMult or 1.0
end

function WeatherService_189.GetHatchMult(): number
	local data = SEASON_DATA_189[SEASONS_189[currentSeasonIdx_189]]
	return data and data.hatchMult or 1.0
end

function WeatherService_189.Start()
	startClock_189()
end

return WeatherService_189
```

---

## Step 3 — Wire WeatherService into ServerMain

Open **ServerScriptService → Main** (the server bootstrap Script) and add near the top with the other service requires:

```lua
local WeatherService = require(Systems:WaitForChild("WeatherService"))
WeatherService.Start()
```

---

## Step 4 — WeatherController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `WeatherController`.

Paste exactly:

```lua
--!strict
-- WeatherController: reads SeasonWeather attribute and shows sky-tint overlay + season pill.
-- SeasonWeather format: "Season|WeatherType|yieldMult|hatchMult"
-- Entirely client-side — zero server writes.

local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Season palette ────────────────────────────────────────────────────────────
local SEASON_COLORS_189: { [string]: Color3 } = {
	Spring = Color3.fromRGB(190, 230, 180),   -- soft green-pink
	Summer = Color3.fromRGB(240, 200, 100),   -- warm gold
	Autumn = Color3.fromRGB(200, 120,  50),   -- burnt orange
	Winter = Color3.fromRGB(160, 190, 220),   -- cold blue-grey
}

local SEASON_ICONS_189: { [string]: string } = {
	Spring = "🌸", Summer = "☀️", Autumn = "🍂", Winter = "❄️",
}

local WAX_CREAM_189 = Color3.fromRGB(232, 212, 154)
local DARK_BG_189   = Color3.fromRGB( 30,  18,   8)
local HONEY_GOLD_189 = Color3.fromRGB(242, 168,  28)

-- ── Build sky-tint overlay + pill ─────────────────────────────────────────────
local skyTintFrame_189: Frame? = nil
local pillLabel_189: TextLabel? = nil

local function buildWeatherGui_189()
	local sg = Instance.new("ScreenGui")
	sg.Name           = "WeatherGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 5     -- behind everything else
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	-- Full-screen tint (very faint colour wash)
	local tint = Instance.new("Frame")
	tint.Name                   = "SkyTint"
	tint.Size                   = UDim2.new(1, 0, 1, 0)
	tint.BackgroundColor3       = SEASON_COLORS_189["Spring"]
	tint.BackgroundTransparency = 0.92   -- nearly invisible, just a hint
	tint.BorderSizePixel        = 0
	tint.ZIndex                 = 1
	tint.Parent                 = sg
	skyTintFrame_189 = tint

	-- Season pill (bottom-left, near wallet)
	local pill = Instance.new("Frame")
	pill.Name                   = "SeasonPill"
	pill.Size                   = UDim2.new(0, 110, 0, 22)
	pill.Position               = UDim2.new(0, 8, 1, -68)
	pill.BackgroundColor3       = DARK_BG_189
	pill.BackgroundTransparency = 0.15
	pill.BorderSizePixel        = 0
	pill.ZIndex                 = 5
	pill.Parent                 = sg

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 8)
	pillCorner.Parent       = pill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color     = HONEY_GOLD_189
	pillStroke.Thickness = 1
	pillStroke.Parent    = pill

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "SeasonText"
	lbl.Size               = UDim2.new(1, -4, 1, 0)
	lbl.Position           = UDim2.new(0, 2, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "🌸 Spring · Clear"
	lbl.TextSize           = 11
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_189
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 6
	lbl.Parent             = pill
	pillLabel_189 = lbl
end

-- ── Parse SeasonWeather attribute ─────────────────────────────────────────────
local function parseSW_189(raw: string): (string, string, number, number)
	local parts: { string } = raw:split("|")
	local season  = parts[1] or "Spring"
	local weather = parts[2] or "Clear"
	local ymult   = tonumber(parts[3]) or 1.0
	local hmult   = tonumber(parts[4]) or 1.0
	return season, weather, ymult, hmult
end

-- ── Apply season visuals ──────────────────────────────────────────────────────
local function applyWeather_189(raw: string)
	local season, weather, ymult, hmult = parseSW_189(raw)
	local color = SEASON_COLORS_189[season] or SEASON_COLORS_189["Spring"]
	local icon  = SEASON_ICONS_189[season] or "🌤️"

	if skyTintFrame_189 then
		TweenService:Create(skyTintFrame_189,
			TweenInfo.new(2.0, Enum.EasingStyle.Sine),
			{ BackgroundColor3 = color }):Play()
	end

	if pillLabel_189 then
		pillLabel_189.Text = icon .. " " .. season .. " · " .. weather
		-- Adult tooltip: yield and hatch mults
		-- (shown in TextLabel title since there's no tooltip system yet)
		if ymult ~= 1.0 or hmult ~= 1.0 then
			pillLabel_189.Text = icon .. " " .. season
				.. " ×" .. string.format("%.2f", ymult)
		end
	end
end

-- ── Init ──────────────────────────────────────────────────────────────────────
task.delay(1.5, function()
	buildWeatherGui_189()

	-- Apply current attribute if already set
	local raw = player:GetAttribute("SeasonWeather") :: string?
	if raw then applyWeather_189(raw) end

	-- Watch for changes
	player:GetAttributeChangedSignal("SeasonWeather"):Connect(function()
		local v = player:GetAttribute("SeasonWeather") :: string?
		if v then applyWeather_189(v) end
	end)
end)
```

---

## Step 5 — Wire WeatherController into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("WeatherController"))
```

---

## Step 6 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check DataService version
local DS = game:GetService("ServerScriptService").Systems:FindFirstChild("DataService")
if DS then
	local v = DS.Source:match("DATA_VERSION%s*=%s*(%d+)")
	print("DataService version:", v, "(expect 17)")
	print("  migration[17]:", DS.Source:find("%[17%]") ~= nil)
end

-- Check WeatherService
local WS = game:GetService("ServerScriptService").Systems:FindFirstChild("WeatherService")
print("WeatherService:", WS and WS.ClassName or "MISSING")
if WS then
	print("  SEASON_DATA_189:", WS.Source:find("SEASON_DATA_189") ~= nil)
	print("  broadcastWeather_189:", WS.Source:find("broadcastWeather_189") ~= nil)
	print("  GetYieldMult:", WS.Source:find("GetYieldMult") ~= nil)
end

-- Check WeatherController client script
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local wc = SPS and SPS:FindFirstChild("WeatherController")
print("WeatherController:", wc and wc.ClassName or "MISSING")
if wc then
	print("  applyWeather_189:", wc.Source:find("applyWeather_189") ~= nil)
	print("  SeasonWeather listener:", wc.Source:find("SeasonWeather") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
DataService version: 17  (expect 17)
  migration[17]: true
WeatherService: ModuleScript
  SEASON_DATA_189: true
  broadcastWeather_189: true
  GetYieldMult: true
WeatherController: LocalScript
  applyWeather_189: true
  SeasonWeather listener: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Season | Duration | Yield mult | Hatch mult | Temp drift | Sky tint | Pill |
|--------|----------|-----------|-----------|------------|----------|------|
| 🌸 Spring | 5 min | ×1.15 | ×1.10 | 0 | Soft green-pink | "🌸 Spring ×1.15" |
| ☀️ Summer | 5 min | ×1.30 | ×1.25 | +0.004°C/s | Warm gold | "☀️ Summer ×1.30" |
| 🍂 Autumn | 5 min | ×0.85 | ×0.90 | -0.002°C/s | Burnt orange | "🍂 Autumn ×0.85" |
| ❄️ Winter | 5 min | ×0.55 | ×0.65 | -0.008°C/s | Cold blue-grey | "❄️ Winter ×0.55" |
| Weather sub-types | — | — | — | — | Tint unchanged | Shown in pill text |
| Season change | Notify toast fires | Attribute updated | Attribute updated | Drift changes | 2s Sine tween | Text swaps |

**Part budget: +0 permanent → 4,204 / 5,000**

> **Integration notes for ForagingService / PopulationService:**
> Both services should call `WeatherService.GetYieldMult()` and `WeatherService.GetHatchMult()` when computing foraging output and hatch intervals respectively. This is a one-line multiply in each service — add it in a future integration pass once WeatherService is live.
