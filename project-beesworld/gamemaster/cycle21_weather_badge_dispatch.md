# Dispatch 213 — Season & Weather Badge
**File:** `cycle21_weather_badge_dispatch.md`
**Cycle:** 21
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture's WeatherService cycles through seasons (Spring / Summer / Autumn / Winter) and weather states (Sunny / Overcast / Rain / Storm) that modify foraging yield multipliers. Players currently cannot tell what season or weather they are in without monitoring the weather notice board in the hub. This dispatch adds a **Season & Weather Badge**: a small persistent ScreenGui panel at the top-right corner of the screen showing a season emoji, a weather emoji, and the current weather label. Updates reactively on `CurrentSeason` and `CurrentWeather` player attributes. Entirely client-side — zero server writes.

For kids: two friendly emoji make the weather immediately readable. For adults: the exact weather label ("Heavy Rain −30%") tells them the precise foraging penalty they're working against.

---

## Step 1 — WeatherBadgeController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `WeatherBadgeController`.

Paste exactly:

```lua
--!strict
-- WeatherBadgeController: top-right HUD badge showing current season and weather.
-- Reads CurrentSeason and CurrentWeather player attributes from WeatherService.
-- Entirely client-side — zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local FADE_TIME_213   = 0.22
local SCAN_INTERVAL_213 = 8.0

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_213   = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_213 = Color3.fromRGB(232, 212, 154)
local DIM_213       = Color3.fromRGB(160, 140, 100)

-- ── Season data ───────────────────────────────────────────────────────────────
local SEASON_ICON_213: { [string]: string } = {
	Spring = "🌸",
	Summer = "☀️",
	Autumn = "🍂",
	Winter = "❄️",
}

-- ── Weather data ──────────────────────────────────────────────────────────────
type WeatherSpec213 = { icon: string, label: string, col: Color3 }

local WEATHER_SPEC_213: { [string]: WeatherSpec213 } = {
	Sunny    = { icon = "🌤",  label = "Sunny",       col = Color3.fromRGB(242, 200,  60) },
	Overcast = { icon = "☁️",  label = "Overcast",    col = Color3.fromRGB(180, 170, 150) },
	Rain     = { icon = "🌧",  label = "Rain −20%",   col = Color3.fromRGB(120, 160, 220) },
	Storm    = { icon = "⛈",  label = "Storm −40%",  col = Color3.fromRGB(100, 100, 200) },
	Drizzle  = { icon = "🌦",  label = "Drizzle −10%",col = Color3.fromRGB(150, 180, 210) },
	Fog      = { icon = "🌫",  label = "Fog −15%",    col = Color3.fromRGB(190, 190, 180) },
}

local DEFAULT_WEATHER_213: WeatherSpec213 = { icon = "🌤", label = "Clear", col = Color3.fromRGB(242, 200, 60) }

-- ── State ─────────────────────────────────────────────────────────────────────
local badgeGui_213: ScreenGui? = nil
local built_213 = false

-- ── Build badge ───────────────────────────────────────────────────────────────
local function buildBadge_213(): ScreenGui
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return nil :: any end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "WeatherBadge_213"
	sg.DisplayOrder   = 17
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Name                   = "BadgeFrame"
	frame.Size                   = UDim2.new(0, 130, 0, 34)
	frame.AnchorPoint            = Vector2.new(1, 0)
	frame.Position               = UDim2.new(1, -8, 0, 8)   -- top-right
	frame.BackgroundColor3       = DARK_BG_213
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "BadgeStroke"
	stroke.Color     = Color3.fromRGB(80, 60, 30)
	stroke.Thickness = 1
	stroke.Parent    = frame

	-- Season emoji (left)
	local seasonLabel = Instance.new("TextLabel")
	seasonLabel.Name               = "SeasonIcon"
	seasonLabel.Size               = UDim2.new(0, 28, 1, 0)
	seasonLabel.Position           = UDim2.new(0, 2, 0, 0)
	seasonLabel.BackgroundTransparency = 1
	seasonLabel.Text               = "🌸"
	seasonLabel.TextSize           = 16
	seasonLabel.Font               = Enum.Font.GothamBold
	seasonLabel.TextXAlignment     = Enum.TextXAlignment.Center
	seasonLabel.ZIndex             = 2
	seasonLabel.Parent             = frame

	-- Weather emoji (centre-left)
	local weatherIcon = Instance.new("TextLabel")
	weatherIcon.Name               = "WeatherIcon"
	weatherIcon.Size               = UDim2.new(0, 24, 1, 0)
	weatherIcon.Position           = UDim2.new(0, 30, 0, 0)
	weatherIcon.BackgroundTransparency = 1
	weatherIcon.Text               = "🌤"
	weatherIcon.TextSize           = 15
	weatherIcon.Font               = Enum.Font.GothamBold
	weatherIcon.TextXAlignment     = Enum.TextXAlignment.Center
	weatherIcon.ZIndex             = 2
	weatherIcon.Parent             = frame

	-- Weather label text (right)
	local weatherLabel = Instance.new("TextLabel")
	weatherLabel.Name               = "WeatherLabel"
	weatherLabel.Size               = UDim2.new(1, -58, 1, 0)
	weatherLabel.Position           = UDim2.new(0, 56, 0, 0)
	weatherLabel.BackgroundTransparency = 1
	weatherLabel.Text               = "Sunny"
	weatherLabel.TextSize           = 10
	weatherLabel.Font               = Enum.Font.Gotham
	weatherLabel.TextColor3         = WAX_CREAM_213
	weatherLabel.TextXAlignment     = Enum.TextXAlignment.Left
	weatherLabel.ZIndex             = 2
	weatherLabel.Parent             = frame

	return sg
end

-- ── Update badge ──────────────────────────────────────────────────────────────
local function updateBadge_213()
	if not badgeGui_213 then return end
	local frame = badgeGui_213:FindFirstChild("BadgeFrame")
	if not frame then return end

	local season  = (player:GetAttribute("CurrentSeason")  :: string?) or "Spring"
	local weather = (player:GetAttribute("CurrentWeather") :: string?) or "Sunny"

	local seasonIcon  = frame:FindFirstChild("SeasonIcon")  :: TextLabel?
	local wIcon       = frame:FindFirstChild("WeatherIcon") :: TextLabel?
	local wLabel      = frame:FindFirstChild("WeatherLabel") :: TextLabel?
	local stroke      = frame:FindFirstChild("BadgeStroke") :: UIStroke?

	local spec = WEATHER_SPEC_213[weather] or DEFAULT_WEATHER_213

	if seasonIcon then seasonIcon.Text = SEASON_ICON_213[season] or "🌸" end
	if wIcon      then wIcon.Text      = spec.icon end
	if wLabel     then
		wLabel.Text       = spec.label
		wLabel.TextColor3 = spec.col
	end
	if stroke then stroke.Color = spec.col end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	if not built_213 then
		built_213 = true
		badgeGui_213 = buildBadge_213()
		if badgeGui_213 then
			updateBadge_213()
			local frame = badgeGui_213:FindFirstChild("BadgeFrame")
			if frame then
				frame.BackgroundTransparency = 1
				TweenService:Create(frame, TweenInfo.new(FADE_TIME_213, Enum.EasingStyle.Sine), {
					BackgroundTransparency = 0.18,
				}):Play()
			end
		end
	end

	player:GetAttributeChangedSignal("CurrentSeason"):Connect(updateBadge_213)
	player:GetAttributeChangedSignal("CurrentWeather"):Connect(updateBadge_213)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= SCAN_INTERVAL_213 then
			acc = 0
			updateBadge_213()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("WeatherBadgeController"))
```

---

## Step 3 — Attribute source (WeatherService)

`WeatherBadgeController` reads two player attributes:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `CurrentSeason` | string | WeatherService | "Spring" / "Summer" / "Autumn" / "Winter" |
| `CurrentWeather` | string | WeatherService | "Sunny" / "Overcast" / "Rain" / "Storm" / "Drizzle" / "Fog" |

WeatherService should broadcast these to all players on each weather tick:

```lua
-- In WeatherService, after weather changes:
for _, p in game:GetService("Players"):GetPlayers() do
	p:SetAttribute("CurrentSeason", currentSeason)
	p:SetAttribute("CurrentWeather", currentWeather)
end
```

If WeatherService does not yet exist, the badge defaults gracefully to 🌸 Sunny and waits for the attributes to appear.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("WeatherBadgeController")
print("WeatherBadgeController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildBadge_213:", c.Source:find("buildBadge_213") ~= nil)
	print("  updateBadge_213:", c.Source:find("updateBadge_213") ~= nil)
	print("  CurrentSeason attr:", c.Source:find("CurrentSeason") ~= nil)
	print("  CurrentWeather attr:", c.Source:find("CurrentWeather") ~= nil)
	print("  SEASON_ICON_213:", c.Source:find("SEASON_ICON_213") ~= nil)
	print("  WEATHER_SPEC_213:", c.Source:find("WEATHER_SPEC_213") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
local lp = game:GetService("Players").LocalPlayer
-- Spring Sunny (default)
lp:SetAttribute("CurrentSeason", "Spring")
lp:SetAttribute("CurrentWeather", "Sunny")
task.wait(1)
-- Summer Storm (debuff)
lp:SetAttribute("CurrentSeason", "Summer")
lp:SetAttribute("CurrentWeather", "Storm")
task.wait(2)
-- Autumn Overcast
lp:SetAttribute("CurrentSeason", "Autumn")
lp:SetAttribute("CurrentWeather", "Overcast")
```

**Expected output:**
```
WeatherBadgeController: LocalScript
  lines: 140+
  buildBadge_213: true
  updateBadge_213: true
  CurrentSeason attr: true
  CurrentWeather attr: true
  SEASON_ICON_213: true
  WEATHER_SPEC_213: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Season | Season icon | Notes |
|---|---|---|
| Spring | 🌸 | Default season |
| Summer | ☀️ | Peak foraging |
| Autumn | 🍂 | Slower pollen |
| Winter | ❄️ | Heavily reduced yield |

| Weather | Icon | Label | Stroke colour |
|---|---|---|---|
| Sunny | 🌤 | "Sunny" | Honey gold (242,200,60) |
| Overcast | ☁️ | "Overcast" | Warm grey (180,170,150) |
| Drizzle | 🌦 | "Drizzle −10%" | Light blue (150,180,210) |
| Rain | 🌧 | "Rain −20%" | Blue (120,160,220) |
| Fog | 🌫 | "Fog −15%" | Pale grey (190,190,180) |
| Storm | ⛈ | "Storm −40%" | Deep blue (100,100,200) |

- Badge sits top-right (8px from each edge) — opposite corner from caste badge and pop cap pill
- DisplayOrder=17 — below all other HUD elements, unobtrusive reference display
- Stroke colour updates with weather — subtle visual tinting matches the sky
- Adults see the exact yield penalty; kids see two friendly emoji
- Graceful degradation: badge shows Sunny defaults if WeatherService attributes are absent

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(ScreenGui only — no BaseParts)*
