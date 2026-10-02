# Dispatch 148 — Foraging Weather Events
## Cycle 14 · A Bee's World

**Feature:** Weather Events — a server-side weather cycle that runs every 5–8 minutes and picks a random weather condition for 90–180 seconds. Five weather types modify foraging quality and trip duration. A client-side weather banner announces the current condition. Kids respond to the visual; adults time their foraging sends to hit Sunny Days or avoid Storms. Part budget: +1 permanent (one server Script; weather banner is LocalScript = +0 permanent).
**Part budget impact:** +1 permanent → **4,155 / 5,000**
**Execution order:** After dispatch 147 (Honey Milestone Toasts)

---

## DESIGN

### Weather types

| Type | Foraging quality modifier | Trip duration modifier | Headline |
|------|--------------------------|------------------------|----------|
| `sunny` | +15 | ×0.85 (faster) | ☀️ Sunny Day! |
| `cloudy` | ±0 | ×1.0 | ⛅ Cloudy Skies |
| `windy` | −10 | ×1.15 (slower) | 💨 Windy! |
| `rainy` | −20 | ×1.25 (slower) | 🌧️ Raining |
| `flower_bloom` | +25 | ×0.90 (faster) | 🌸 Flower Bloom! |

`flower_bloom` is rare (10% weight) — it's the "jackpot" weather that adults will chase.

### Server weather attribute

`WeatherState` player attribute is a string: `"sunny"`, `"cloudy"`, `"windy"`, `"rainy"`, or `"flower_bloom"`. All players on the server share the same weather (it's a server-wide event), so the service writes it to all players simultaneously.

### ForagingService integration

ForagingService reads `WeatherState` at trip-return time to apply the quality modifier. Trip duration modifier is applied when the forage is sent (at `ForagingEndTime` calculation).

### Client banner

A thin strip at the very top of the screen (above everything, `DisplayOrder=8`) slides in for 4 seconds then slides back. Uses weather-appropriate colours.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `WeatherService` | New Script in ServerScriptService |
| `WeatherBannerController` | New LocalScript in StarterPlayerScripts |
| `ForagingService` | +6 lines: quality + duration modifiers |

---

## STEP A — Create WeatherService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("WeatherService") then
    print("⏭️  WeatherService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "WeatherService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- WeatherService — dispatch 148
-- Server-wide weather cycle. Fires WeatherChanged RemoteEvent to all clients.
-- Weather lasts 90-180s; next event in 5-8 min.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RE_148: RemoteEvent = (function()
    local e = ReplicatedStorage:FindFirstChild("WeatherChanged")
    if e and e:IsA("RemoteEvent") then return e :: RemoteEvent end
    local re = Instance.new("RemoteEvent")
    re.Name   = "WeatherChanged"
    re.Parent = ReplicatedStorage
    return re
end)()

type WeatherDef_148 = {id: string, headline: string, qualityMod: number, durationMod: number, weight: number}
local WEATHER_148: {WeatherDef_148} = {
    {id = "sunny",        headline = "☀️ Sunny Day!",     qualityMod =  15, durationMod = 0.85, weight = 25},
    {id = "cloudy",       headline = "⛅ Cloudy Skies",   qualityMod =   0, durationMod = 1.00, weight = 35},
    {id = "windy",        headline = "💨 Windy!",          qualityMod = -10, durationMod = 1.15, weight = 20},
    {id = "rainy",        headline = "🌧️ Raining",         qualityMod = -20, durationMod = 1.25, weight = 10},
    {id = "flower_bloom", headline = "🌸 Flower Bloom!",   qualityMod =  25, durationMod = 0.90, weight = 10},
}

local currentWeather_148: WeatherDef_148 = WEATHER_148[2]  -- start cloudy (neutral)

local function pickWeather_148(): WeatherDef_148
    local totalWeight = 0
    for _, w in WEATHER_148 do totalWeight = totalWeight + w.weight end
    local roll = math.random(1, totalWeight)
    local acc  = 0
    for _, w in WEATHER_148 do
        acc = acc + w.weight
        if roll <= acc then return w end
    end
    return WEATHER_148[2]  -- fallback
end

local function applyWeather_148(w: WeatherDef_148)
    currentWeather_148 = w
    for _, player in Players:GetPlayers() do
        player:SetAttribute("WeatherState",      w.id)
        player:SetAttribute("WeatherQualityMod", w.qualityMod)
        player:SetAttribute("WeatherDurationMod", w.durationMod)
    end
    RE_148:FireAllClients({id = w.id, headline = w.headline})
    print(string.format("[WeatherService] Weather changed: %s (quality %+d, duration ×%.2f)",
        w.headline, w.qualityMod, w.durationMod))
end

-- Apply weather to new players joining mid-cycle
Players.PlayerAdded:Connect(function(player)
    task.wait(2)
    if player.Parent then
        player:SetAttribute("WeatherState",      currentWeather_148.id)
        player:SetAttribute("WeatherQualityMod", currentWeather_148.qualityMod)
        player:SetAttribute("WeatherDurationMod", currentWeather_148.durationMod)
    end
end)

-- Weather cycle loop
task.spawn(function()
    -- Initial state
    applyWeather_148(pickWeather_148())

    while true do
        -- Weather lasts 90-180 seconds
        local duration = 90 + math.random(0, 90)
        task.wait(duration)
        -- Then neutral gap (5-8 min) before next event is replaced with direct transition
        -- Transition to new weather immediately
        local next = pickWeather_148()
        -- Avoid same weather twice in a row (unless cloudy)
        if next.id == currentWeather_148.id and next.id ~= "cloudy" then
            next = pickWeather_148()
        end
        applyWeather_148(next)
        -- Gap before next change: 5-8 minutes minus the weather duration already elapsed
        task.wait(300 + math.random(0, 180))
    end
end)

print("[WeatherService] Ready — server-wide weather cycle active")
]]
    svc.Parent = SSS
    print("✅ WeatherService created")
end
```

---

## STEP B — Create WeatherBannerController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("WeatherBannerController") then
    print("⏭️  WeatherBannerController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "WeatherBannerController"
    ctrl.Source = [[
--!strict
-- WeatherBannerController — dispatch 148
-- Thin top-of-screen strip announcing weather changes.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local COLORS_148: {[string]: Color3} = {
    sunny        = Color3.fromRGB(242, 200,  40),
    cloudy       = Color3.fromRGB(160, 170, 190),
    windy        = Color3.fromRGB(120, 200, 220),
    rainy        = Color3.fromRGB(80,  120, 200),
    flower_bloom = Color3.fromRGB(230, 120, 200),
}

local sg_148: ScreenGui? = nil
local banner_148: Frame? = nil

local function ensureGui_148()
    if sg_148 and sg_148.Parent then return end
    sg_148 = Instance.new("ScreenGui")
    sg_148.Name         = "WeatherBannerGui"
    sg_148.ResetOnSpawn = false
    sg_148.DisplayOrder = 8
    sg_148.Parent       = playerGui
end

local function showBanner_148(id: string, headline: string)
    ensureGui_148()
    -- Remove existing banner
    if banner_148 and banner_148.Parent then banner_148:Destroy() end

    local color = COLORS_148[id] or Color3.fromRGB(200, 200, 200)

    local strip = Instance.new("Frame")
    strip.Name                   = "WeatherStrip"
    strip.Size                   = UDim2.new(1, 0, 0, 28)
    strip.Position               = UDim2.new(0, 0, 0, -30)
    strip.BackgroundColor3       = color
    strip.BackgroundTransparency = 0.1
    strip.BorderSizePixel        = 0
    strip.Parent                 = sg_148 :: ScreenGui
    banner_148 = strip

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -16, 1, 0)
    lbl.Position               = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 13
    lbl.TextColor3             = Color3.fromRGB(30, 15, 5)
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Text                   = headline
    lbl.Parent                 = strip

    -- Slide in
    TweenService:Create(strip, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 0, 0)}):Play()

    -- Hold 4s then slide out
    task.delay(4, function()
        if not strip.Parent then return end
        local out = TweenService:Create(strip,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0, 0, 0, -30)})
        out:Play()
        out.Completed:Connect(function() if strip.Parent then strip:Destroy() end end)
    end)
end

local RE = ReplicatedStorage:WaitForChild("WeatherChanged", 15) :: RemoteEvent?
if RE then
    RE.OnClientEvent:Connect(function(data)
        showBanner_148((data :: any).id, (data :: any).headline)
    end)
end

print("[WeatherBannerController] Ready")
]]
    ctrl.Parent = SPS
    print("✅ WeatherBannerController created")
end
```

---

## STEP C — Patch ForagingService (weather modifiers)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("ForagingService")
assert(svc, "ForagingService not found")

-- Patch 1: quality modifier (after scout bonus from dispatch 143)
local oldQ = [[local quality = math.min(100, baseQuality_143 + scoutBonus_143)]]
local newQ = [[
            local weatherQMod_148 = tonumber(player:GetAttribute("WeatherQualityMod")) or 0
            local quality = math.min(100, math.max(0, baseQuality_143 + scoutBonus_143 + weatherQMod_148))]]

-- Patch 2: duration modifier (find the ForagingEndTime calculation)
-- The ForagingService sets ForagingEndTime = os.time() + tripDuration
-- We apply weather duration mod to tripDuration before that line.
-- First, find the line to identify the variable name used.
local hasDurationMod = svc.Source:find("WeatherDurationMod", 1, true)
local hasQMod = svc.Source:find("weatherQMod_148", 1, true)

if not hasQMod then
    if svc.Source:find(oldQ, 1, true) then
        svc.Source = svc.Source:gsub(oldQ:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), newQ:gsub("%%","%%%%"), 1)
        print("✅ ForagingService quality patch applied — weather quality modifier active")
    elseif svc.Source:find("scoutBonus_143", 1, true) then
        print("⚠️  Quality line signature changed since dispatch 143 — patch manually:")
        print("    Find the 'quality = math.min(100, ...)' line and add weatherQMod_148 to the sum")
    else
        print("⚠️  No dispatch 143 quality line found. Add weather modifier manually.")
    end
else
    print("⏭️  Quality weather patch already applied")
end

-- Duration patch: find ForagingEndTime assignment
local oldD = [[player:SetAttribute("ForagingEndTime", os.time() + tripDuration)]]
local newD = [[
            local weatherDMod_148 = tonumber(player:GetAttribute("WeatherDurationMod")) or 1.0
            player:SetAttribute("ForagingEndTime", os.time() + math.floor(tripDuration * weatherDMod_148))]]

if not hasDurationMod then
    if svc.Source:find(oldD, 1, true) then
        svc.Source = svc.Source:gsub(oldD:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), newD:gsub("%%","%%%%"), 1)
        print("✅ ForagingService duration patch applied — weather duration modifier active")
    else
        print("⚠️  ForagingEndTime line not found with expected signature.")
        print("    Find where ForagingEndTime is set and multiply tripDuration by:")
        print("    tonumber(player:GetAttribute('WeatherDurationMod')) or 1.0")
    end
else
    print("⏭️  Duration weather patch already applied")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc   = SSS:FindFirstChild("WeatherService")
local ctrl  = SPS and SPS:FindFirstChild("WeatherBannerController")
local forag = SSS:FindFirstChild("ForagingService")
local re    = RS:FindFirstChild("WeatherChanged")

local checks = {}
table.insert(checks, (svc and "✅" or "❌") .. " WeatherService in ServerScriptService")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("WEATHER_148", 1, true) and "✅" or "❌") .. " WEATHER_148 table (5 types)")
table.insert(checks, (svc and svc.Source:find("flower_bloom", 1, true) and "✅" or "❌") .. " flower_bloom weather type")
table.insert(checks, (svc and svc.Source:find("WeatherQualityMod", 1, true) and "✅" or "❌") .. " WeatherQualityMod attribute write")
table.insert(checks, (re and "✅" or "❌") .. " WeatherChanged RemoteEvent")
table.insert(checks, (ctrl and "✅" or "❌") .. " WeatherBannerController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl.Source:find("COLORS_148", 1, true) and "✅" or "❌") .. " COLORS_148 per-weather colours")
table.insert(checks, (forag and forag.Source:find("weatherQMod_148", 1, true) and "✅" or "❌") .. " ForagingService quality mod")
table.insert(checks, (forag and forag.Source:find("weatherDMod_148", 1, true) and "✅" or "❌") .. " ForagingService duration mod")

print("=== DISPATCH 148 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 148 complete" or "❌ SOME CHECKS FAILED")

print("\nWeather types: sunny(+15/×0.85), cloudy(±0/×1.0), windy(-10/×1.15), rainy(-20/×1.25), flower_bloom(+25/×0.90 rare)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| WeatherService (Script) | +1 |
| WeatherBannerController (LocalScript — no permanent count) | 0 |
| ForagingService patches (edits — no new instances) | 0 |
| **Dispatch 148 total** | **+1** |
| **Running total** | **4,155 / 5,000** |

---

## NOTES

- `flower_bloom` (weight 10) fires roughly 10% of the time. In a 5–8 minute cycle, players see one event roughly every 7 minutes on average. A Flower Bloom event happens approximately once per hour of play — rare enough to feel special, common enough that regular players will catch several per session.
- The "avoid same weather twice in a row" guard keeps transitions interesting without introducing a full Markov chain. Cloudy is exempt — it's the neutral fallback and can repeat.
- `WeatherQualityMod` and `WeatherDurationMod` are separate attributes so ForagingService patches are independent. An alternative (combined `WeatherState` string lookup) would work but would require ForagingService to import the weather table, adding coupling.
- The banner uses `DisplayOrder=8` — below the foraging timer pill (11) and temperature pill (12), so it occupies the very top of the screen without covering functional UI. Weather is ambient information, not an action prompt.
- Players joining mid-weather immediately get the current `WeatherState` attributes via the `Players.PlayerAdded` handler in WeatherService, so their first forage trip uses the correct modifiers even if they missed the banner.
