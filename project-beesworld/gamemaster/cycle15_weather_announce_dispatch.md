# Dispatch 165 — Weather Event Announcements & Weather HUD
**File:** `cycle15_weather_announce_dispatch.md`
**Branch:** add-beesworld-project
**Part budget:** +0 new world parts → 4,198 / 5,000

---

## Overview

The game already has a `WeatherService` that cycles through weather states (sunny, cloudy,
rainy, flower_bloom, etc.), but players have no idea when it changes — they just notice
foraging results got worse or better without knowing why. This dispatch adds a weather
transition announcement toast (server-fires on every weather change) and a persistent
weather HUD pill that shows the current weather with its effect on foraging quality.

Kids see: "☀️ Sunny! Bees fly faster!" Adults see: "+15% foraging quality bonus."

**What gets built:**
1. `WeatherAnnounceService` Script — hooks into WeatherService's weather change event or
   polls every cycle and fires `WeatherChanged` RemoteEvent to all clients
2. `WeatherHudController` LocalScript — persistent weather pill (top-centre HUD, below
   any existing banners) + slide-in transition toast on weather change
3. `WeatherChanged` RemoteEvent
4. +0 world parts

---

## Step 1 — WeatherChanged RemoteEvent

Run in Command Bar:

```lua
local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name   = "Remotes"
    Remotes.Parent = game:GetService("ReplicatedStorage")
end
if not Remotes:FindFirstChild("WeatherChanged") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "WeatherChanged"
    re.Parent = Remotes
    print("Created: WeatherChanged")
else
    print("WeatherChanged already exists")
end
```

---

## Step 2 — WeatherAnnounceService Script

In Studio Explorer: **ServerScriptService** → Insert **Script**, rename
`WeatherAnnounceService`.

Paste full source:

```lua
--!strict
-- WeatherAnnounceService: fires WeatherChanged RemoteEvent when weather transitions.
-- Polls WeatherService every 5s and detects state changes.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Remote ─────────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local WeatherChanged_165 = Remotes:WaitForChild("WeatherChanged", 10) :: RemoteEvent

-- ── Weather display data (client-safe copy) ─────────────────────────────────────
-- Must match WeatherService's internal state names
type WeatherDef = { emoji: string, name: string, kid: string, adult: string, qualMod: number }

local WEATHER_DEF_165: { [string]: WeatherDef } = {
	sunny        = { emoji="☀️",  name="Sunny",       kid="Bees love sunny days! Great foraging!",        adult="+15% foraging quality",       qualMod=15  },
	cloudy       = { emoji="⛅",  name="Cloudy",       kid="A little cloudy — still okay to forage.",      adult="No foraging bonus or penalty", qualMod=0   },
	rainy        = { emoji="🌧️",  name="Rainy",        kid="Rainy day — bees stay closer to home.",        adult="-10% foraging quality",       qualMod=-10 },
	windy        = { emoji="💨",  name="Windy",        kid="Windy! Bees have to work harder today.",       adult="-5% foraging quality",        qualMod=-5  },
	flower_bloom = { emoji="🌸",  name="Flower Bloom", kid="Flowers are blooming everywhere! Best day!",   adult="+25% foraging quality + pollen bonus",  qualMod=25  },
	foggy        = { emoji="🌫️",  name="Foggy",        kid="Foggy morning — bees navigate carefully.",     adult="-8% foraging quality",        qualMod=-8  },
	thunderstorm = { emoji="⛈️",  name="Storm",        kid="Thunderstorm! Bees stay inside the hive.",     adult="-20% foraging quality",       qualMod=-20 },
}

local DEFAULT_WEATHER_165: WeatherDef = {
	emoji="🌤️", name="Clear", kid="Clear skies — good day to forage!", adult="No modifier", qualMod=0
}

-- ── Poll for weather changes ────────────────────────────────────────────────────
local lastWeatherState_165 = ""

local function getWeatherState_165(): string
	-- Try to read from WeatherService if it exposes a GetCurrentWeather() API
	local ws = game:GetService("ServerScriptService"):FindFirstChild("WeatherService", true)
	if ws and ws:IsA("ModuleScript") then
		local ok, wsMod = pcall(require, ws)
		if ok and type(wsMod) == "table" and type(wsMod.GetCurrentWeather) == "function" then
			local state = wsMod.GetCurrentWeather()
			if type(state) == "string" then return state end
		end
		if ok and type(wsMod) == "table" and type(wsMod.currentWeather) == "string" then
			return wsMod.currentWeather
		end
	end
	-- Fallback: read from a shared Attribute on Workspace set by WeatherService
	local attr = workspace:GetAttribute("CurrentWeather") :: string?
	return attr or "cloudy"
end

local function broadcastWeather_165(state: string)
	local def = WEATHER_DEF_165[state] or DEFAULT_WEATHER_165
	pcall(function()
		WeatherChanged_165:FireAllClients({
			state   = state,
			emoji   = def.emoji,
			name    = def.name,
			kid     = def.kid,
			adult   = def.adult,
			qualMod = def.qualMod,
		})
	end)
end

-- On startup, broadcast current weather after a short delay
task.delay(5, function()
	local state = getWeatherState_165()
	lastWeatherState_165 = state
	broadcastWeather_165(state)
end)

-- Poll loop
task.spawn(function()
	while true do
		task.wait(5)
		local state = getWeatherState_165()
		if state ~= lastWeatherState_165 then
			lastWeatherState_165 = state
			broadcastWeather_165(state)
		end
	end
end)

-- Also: patch WeatherService to set workspace attribute on each change,
-- so the fallback read in getWeatherState_165 works if GetCurrentWeather() isn't exposed.
-- This fires from a separate polling loop inside WeatherService itself.
-- To add this patch: in WeatherService, wherever weather state changes, add:
--   workspace:SetAttribute("CurrentWeather", newWeatherState)
-- This dispatch's polling loop will detect it within 5 seconds.

print("[WeatherAnnounceService] started")
```

**Verification:**

```lua
local s = game:GetService("ServerScriptService"):FindFirstChild("WeatherAnnounceService")
print(s and s.ClassName or "MISSING")
local re = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("WeatherChanged")
print(re and re.ClassName or "MISSING")
-- Expected: Script  RemoteEvent
```

---

## Step 3 — WeatherService workspace attribute patch

In **WeatherService** (wherever weather state changes), add ONE line:

```lua
-- After setting the new weather state (wherever _currentWeather or equivalent is assigned):
workspace:SetAttribute("CurrentWeather", newWeatherStateName)
```

This makes `WeatherAnnounceService`'s fallback path work even if WeatherService doesn't
expose a public API. Find the line that assigns the weather state and add the attribute
set immediately after. If WeatherService uses a different internal variable name, look for
the string `"sunny"`, `"rainy"`, `"cloudy"` etc. in the source to find the state names.

---

## Step 4 — WeatherHudController LocalScript

In Studio Explorer: **StarterPlayer → StarterPlayerScripts** → Insert **LocalScript**,
rename `WeatherHudController`.

Paste full source:

```lua
--!strict
-- WeatherHudController: persistent weather pill HUD + transition toast on weather change.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────────────────
local HONEY_GOLD_165  = Color3.fromRGB(242, 168, 28)
local PROPOLIS_165    = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_165   = Color3.fromRGB(232, 212, 154)
local GREEN_165       = Color3.fromRGB(60,  180, 60)
local RED_165         = Color3.fromRGB(210, 60,  40)

-- Weather state → accent color
local WEATHER_COLORS_165: { [string]: Color3 } = {
	sunny        = Color3.fromRGB(255, 200, 40),
	cloudy       = Color3.fromRGB(160, 160, 180),
	rainy        = Color3.fromRGB(80,  120, 200),
	windy        = Color3.fromRGB(140, 180, 140),
	flower_bloom = Color3.fromRGB(220, 120, 200),
	foggy        = Color3.fromRGB(130, 130, 150),
	thunderstorm = Color3.fromRGB(80,  60,  160),
}
local DEFAULT_WEATHER_COLOR_165 = Color3.fromRGB(140, 140, 160)

-- ── Build persistent weather pill ─────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name            = "WeatherHudGui"
sg.DisplayOrder    = 15
sg.ResetOnSpawn    = false
sg.IgnoreGuiInset  = true
sg.Parent          = playerGui

-- Pill: top-centre below notification area
local pill = Instance.new("Frame")
pill.Name              = "WeatherPill"
pill.AnchorPoint       = Vector2.new(0.5, 0)
pill.Position          = UDim2.new(0.5, 0, 0, 48)
pill.Size              = UDim2.new(0, 180, 0, 30)
pill.BackgroundColor3  = PROPOLIS_165
pill.BackgroundTransparency = 0.2
pill.BorderSizePixel   = 0
pill.Parent            = sg
local pc = Instance.new("UICorner")
pc.CornerRadius = UDim.new(0, 12)
pc.Parent = pill
local ps = Instance.new("UIStroke")
ps.Color     = HONEY_GOLD_165
ps.Thickness = 1.5
ps.Parent    = pill

local pillLabel = Instance.new("TextLabel")
pillLabel.Name               = "PillLabel"
pillLabel.Size               = UDim2.fromScale(1, 1)
pillLabel.BackgroundTransparency = 1
pillLabel.TextColor3         = WAX_CREAM_165
pillLabel.TextSize           = 14
pillLabel.Font               = Enum.Font.GothamBold
pillLabel.Text               = "🌤️ Clear"
pillLabel.Parent             = pill

-- ── Build transition toast ─────────────────────────────────────────────────────
local toastActive_165 = false

local function showWeatherToast_165(data: {
	state: string, emoji: string, name: string, kid: string, adult: string, qualMod: number
})
	local accentColor = WEATHER_COLORS_165[data.state] or DEFAULT_WEATHER_COLOR_165

	-- Update persistent pill first
	pillLabel.Text      = data.emoji .. " " .. data.name
	ps.Color            = accentColor
	-- Pulse stroke briefly
	local tw = TweenService:Create(ps,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Thickness = 3 }
	)
	tw:Play()
	tw.Completed:Connect(function()
		TweenService:Create(ps,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Thickness = 1.5 }
		):Play()
	end)

	if toastActive_165 then return end
	toastActive_165 = true

	-- Toast card
	local toast = Instance.new("Frame")
	toast.Name              = "WeatherToast"
	toast.AnchorPoint       = Vector2.new(0.5, 0)
	toast.Position          = UDim2.new(0.5, 0, -0.12, 0)
	toast.Size              = UDim2.new(0, 300, 0, 70)
	toast.BackgroundColor3  = PROPOLIS_165
	toast.BorderSizePixel   = 0
	toast.ZIndex            = 20
	toast.Parent            = sg
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 14)
	tc.Parent = toast
	local ts = Instance.new("UIStroke")
	ts.Color     = accentColor
	ts.Thickness = 2.5
	ts.Parent    = toast

	-- Big emoji
	local bigEmoji = Instance.new("TextLabel")
	bigEmoji.Size               = UDim2.new(0, 48, 1, 0)
	bigEmoji.BackgroundTransparency = 1
	bigEmoji.TextColor3         = Color3.fromRGB(255,255,255)
	bigEmoji.TextSize           = 36
	bigEmoji.Font               = Enum.Font.GothamBold
	bigEmoji.Text               = data.emoji
	bigEmoji.ZIndex             = 21
	bigEmoji.Parent             = toast

	-- Kid text
	local kidLbl = Instance.new("TextLabel")
	kidLbl.Size               = UDim2.new(1, -58, 0, 28)
	kidLbl.Position           = UDim2.new(0, 52, 0, 6)
	kidLbl.BackgroundTransparency = 1
	kidLbl.TextColor3         = WAX_CREAM_165
	kidLbl.TextSize           = 15
	kidLbl.Font               = Enum.Font.GothamBold
	kidLbl.Text               = data.name .. "! " .. data.emoji
	kidLbl.TextXAlignment     = Enum.TextXAlignment.Left
	kidLbl.TextWrapped        = true
	kidLbl.ZIndex             = 21
	kidLbl.Parent             = toast

	-- Kid sub-text
	local kidSub = Instance.new("TextLabel")
	kidSub.Size               = UDim2.new(1, -58, 0, 20)
	kidSub.Position           = UDim2.new(0, 52, 0, 30)
	kidSub.BackgroundTransparency = 1
	kidSub.TextColor3         = WAX_CREAM_165
	kidSub.TextSize           = 12
	kidSub.Font               = Enum.Font.GothamBold
	kidSub.Text               = data.kid
	kidSub.TextXAlignment     = Enum.TextXAlignment.Left
	kidSub.TextWrapped        = true
	kidSub.ZIndex             = 21
	kidSub.Parent             = toast

	-- Adult detail
	local adultLbl = Instance.new("TextLabel")
	adultLbl.Size               = UDim2.new(1, -58, 0, 16)
	adultLbl.Position           = UDim2.new(0, 52, 0, 50)
	adultLbl.BackgroundTransparency = 1
	local modColor: Color3
	if data.qualMod > 0 then
		modColor = GREEN_165
	elseif data.qualMod < 0 then
		modColor = RED_165
	else
		modColor = WAX_CREAM_165
	end
	adultLbl.TextColor3         = modColor
	adultLbl.TextTransparency   = 0.2
	adultLbl.TextSize           = 11
	adultLbl.Font               = Enum.Font.Gotham
	adultLbl.Text               = data.adult
	adultLbl.TextXAlignment     = Enum.TextXAlignment.Left
	adultLbl.ZIndex             = 21
	adultLbl.Parent             = toast

	-- Slide in from top
	TweenService:Create(toast,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 8) }
	):Play()

	-- Auto-dismiss after 5s
	task.delay(5, function()
		TweenService:Create(toast,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, -0.12, 0) }
		):Play()
		task.delay(0.35, function()
			toast:Destroy()
			toastActive_165 = false
		end)
	end)
end

-- ── Listen for weather changes ─────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if Remotes then
	local weatherChanged = Remotes:WaitForChild("WeatherChanged", 10) :: RemoteEvent?
	if weatherChanged then
		weatherChanged.OnClientEvent:Connect(function(data: any)
			showWeatherToast_165(data)
		end)
	end
end
```

**Verification:**

```lua
local lrc = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("WeatherHudController")
print(lrc and lrc.ClassName or "MISSING")
-- Expected: LocalScript
```

---

## Step 5 — Test in Play Mode

```lua
-- Force a weather change broadcast to test the UI
local re = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("WeatherChanged")
local player = game:GetService("Players"):GetPlayers()[1]
if re and player then
    re:FireClient(player, {
        state   = "flower_bloom",
        emoji   = "🌸",
        name    = "Flower Bloom",
        kid     = "Flowers are blooming everywhere! Best day!",
        adult   = "+25% foraging quality + pollen bonus",
        qualMod = 25,
    })
    print("Fired test flower_bloom weather event")
end
```

**Expected behaviour:**
- Top-centre weather pill updates to "🌸 Flower Bloom" with pink stroke
- A toast card slides in from the top: big 🌸 emoji, "Flower Bloom!" headline,
  kid description, adult "+25% foraging quality" in green (positive modifier)
- After 5 seconds the toast slides back up and disappears
- Pill persists and keeps showing current weather with coloured stroke border
- For negative weather (storm, rain): adult line appears in red; for neutral: white

---

## Step 6 — state.json update

After executing in Studio, update `dispatch_count` to 165 and `last_dispatch` to
`"cycle15_weather_announce_dispatch.md"` in state.json.

---

## Summary

| What | Where |
|---|---|
| `WeatherAnnounceService` | `ServerScriptService` Script |
| `WeatherHudController` | `StarterPlayer.StarterPlayerScripts` LocalScript |
| `WeatherChanged` RemoteEvent | `ReplicatedStorage.Remotes` |
| WeatherService patch | add `workspace:SetAttribute("CurrentWeather", state)` on each change |
| New world parts | **0** → total **4,198 / 5,000** |

**Kid experience:** When the weather changes, a toast pops in from the top: big emoji,
one-word weather name, one sentence. The little pill at the top always shows what weather
it is right now — kids can glance at it before deciding to forage.

**Adult experience:** Adult detail line shows exact modifier (e.g., "+15% foraging quality"
in green, "-20% foraging quality" in red) so adults can time foraging runs around weather.
