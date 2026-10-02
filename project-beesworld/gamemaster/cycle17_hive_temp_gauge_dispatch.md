# Dispatch 183 — Hive Temperature Gauge
**File:** `cycle17_hive_temp_gauge_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The `HiveTemperature` player attribute drives a production multiplier (dispatch 146 TempController) but gives players zero visual feedback. On a cold day the hive runs slower — players have no way to know whether to add more Brood cells or buy a Smoker use. This dispatch adds a **Hive Temperature Gauge** to the HiveGui: a compact vertical fill bar styled as a thermometer (colour: cool blue at low temps → honey gold at optimal → hot orange at high). A kid label reads "🌡️ Perfect warmth!" or "🌡️ A bit chilly"; the adult line shows the exact temperature and the current production multiplier. The gauge updates every time `HiveTemperature` changes.

Entirely client-side. Zero new permanent parts.

---

## Step 1 — HiveTempGaugeController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HiveTempGaugeController`.

Paste exactly:

```lua
--!strict
-- HiveTempGaugeController: vertical thermometer gauge in HiveGui driven by HiveTemperature attribute.
-- Shows kid-friendly label + adult exact °C and production multiplier.
-- Entirely client-side — zero server writes.

local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
-- Temperature range (°C) — must match Config.TEMP_OPTIMAL / TEMP_RANGE in Config module
local TEMP_MIN_183    = 0     -- coldest (0 °C = bad)
local TEMP_OPT_183    = 35    -- sweet spot (maps to 1.0× mult)
local TEMP_MAX_183    = 60    -- hottest (above = bad again)

-- Multiplier calculation mirrors Config formula: 1 - abs(T - Topt) / Topt * 0.5 (clamped 0.5..1.5)
local function tempMult_183(temp: number): number
	local delta = math.abs(temp - TEMP_OPT_183)
	return math.max(0.5, math.min(1.5, 1 - delta / TEMP_OPT_183 * 0.5))
end

-- ── Palette ───────────────────────────────────────────────────────────────────
local COLD_COLOR_183  = Color3.fromRGB( 80, 160, 220)  -- icy blue (cold)
local OPT_COLOR_183   = Color3.fromRGB(242, 168,  28)  -- honey gold (optimal)
local HOT_COLOR_183   = Color3.fromRGB(230,  80,  20)  -- hot orange (too hot)
local WAX_CREAM_183   = Color3.fromRGB(232, 212, 154)
local DARK_BG_183     = Color3.fromRGB( 30,  18,   8)
local GREY_183        = Color3.fromRGB( 90,  80,  70)

-- Kid labels by temperature zone
local function kidLabel_183(temp: number): string
	if temp < 15 then return "🌡️ Brrr — too cold!" end
	if temp < 25 then return "🌡️ A bit chilly" end
	if temp < 40 then return "🌡️ Perfect warmth!" end
	if temp < 50 then return "🌡️ Getting warm" end
	return "🌡️ Too hot in here!"
end

-- ── Build gauge ───────────────────────────────────────────────────────────────
local fillBar_183: Frame? = nil
local tempLabel_183: TextLabel? = nil
local adultLabel_183: TextLabel? = nil

local function buildGauge_183()
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	local parentGui: GuiObject

	if hiveGui then
		parentGui = hiveGui :: any
	else
		local sg = Instance.new("ScreenGui")
		sg.Name           = "HiveTempGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 20
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui

		local card = Instance.new("Frame")
		card.Name              = "TempCard"
		card.Size              = UDim2.new(0, 52, 0, 140)
		card.Position          = UDim2.new(0, 8, 0.5, 40)
		card.BackgroundColor3  = DARK_BG_183
		card.BackgroundTransparency = 0.1
		card.BorderSizePixel   = 0
		card.ZIndex            = 24
		card.Parent            = sg

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card

		local stroke = Instance.new("UIStroke")
		stroke.Color     = OPT_COLOR_183
		stroke.Thickness = 1
		stroke.Parent    = card

		parentGui = card
	end

	-- Thermometer tube (outer track)
	local tube = Instance.new("Frame")
	tube.Name              = "TempTube"
	tube.Size              = UDim2.new(0, 12, 0, 80)
	tube.Position          = UDim2.new(0.5, -6, 0, 10)
	tube.BackgroundColor3  = GREY_183
	tube.BorderSizePixel   = 0
	tube.ZIndex            = 25
	tube.Parent            = parentGui

	local tubeCorner = Instance.new("UICorner")
	tubeCorner.CornerRadius = UDim.new(0, 5)
	tubeCorner.Parent = tube

	-- Fill bar (inside tube, grows from bottom)
	local fill = Instance.new("Frame")
	fill.Name              = "TempFill"
	fill.Size              = UDim2.new(1, 0, 0.5, 0)   -- start at 50% height
	fill.Position          = UDim2.new(0, 0, 0.5, 0)   -- anchored to bottom
	fill.BackgroundColor3  = OPT_COLOR_183
	fill.BorderSizePixel   = 0
	fill.ZIndex            = 26
	fill.Parent            = tube

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 5)
	fillCorner.Parent = fill
	fillBar_183 = fill

	-- Bulb at bottom of tube
	local bulb = Instance.new("Frame")
	bulb.Name              = "TempBulb"
	bulb.Size              = UDim2.new(0, 18, 0, 18)
	bulb.Position          = UDim2.new(0.5, -9, 0, 86)
	bulb.BackgroundColor3  = OPT_COLOR_183
	bulb.BorderSizePixel   = 0
	bulb.ZIndex            = 25
	bulb.Parent            = parentGui

	local bulbCorner = Instance.new("UICorner")
	bulbCorner.CornerRadius = UDim.new(0.5, 0)
	bulbCorner.Parent = bulb

	-- Kid label
	local kidLbl = Instance.new("TextLabel")
	kidLbl.Name               = "KidTempLabel"
	kidLbl.Size               = UDim2.new(1, -4, 0, 24)
	kidLbl.Position           = UDim2.new(0, 2, 0, 108)
	kidLbl.BackgroundTransparency = 1
	kidLbl.Text               = "🌡️ —"
	kidLbl.TextSize           = 10
	kidLbl.Font               = Enum.Font.GothamBold
	kidLbl.TextColor3         = WAX_CREAM_183
	kidLbl.TextXAlignment     = Enum.TextXAlignment.Center
	kidLbl.TextWrapped        = true
	kidLbl.ZIndex             = 26
	kidLbl.Parent             = parentGui
	tempLabel_183 = kidLbl

	-- Adult detail label
	local adultLbl = Instance.new("TextLabel")
	adultLbl.Name               = "AdultTempLabel"
	adultLbl.Size               = UDim2.new(1, -4, 0, 18)
	adultLbl.Position           = UDim2.new(0, 2, 0, 130)
	adultLbl.BackgroundTransparency = 1
	adultLbl.Text               = ""
	adultLbl.TextSize           = 9
	adultLbl.Font               = Enum.Font.Gotham
	adultLbl.TextColor3         = GREY_183
	adultLbl.TextXAlignment     = Enum.TextXAlignment.Center
	adultLbl.TextWrapped        = true
	adultLbl.ZIndex             = 26
	adultLbl.Parent             = parentGui
	adultLabel_183 = adultLbl
end

-- ── Update gauge ──────────────────────────────────────────────────────────────
local function tempToColor_183(temp: number): Color3
	if temp <= TEMP_OPT_183 then
		local t = math.max(0, temp / TEMP_OPT_183)
		return COLD_COLOR_183:Lerp(OPT_COLOR_183, t)
	else
		local t = math.min((temp - TEMP_OPT_183) / (TEMP_MAX_183 - TEMP_OPT_183), 1)
		return OPT_COLOR_183:Lerp(HOT_COLOR_183, t)
	end
end

local function updateGauge_183()
	local fill  = fillBar_183
	local kidLb = tempLabel_183
	local adLb  = adultLabel_183
	if not fill or not kidLb or not adLb then return end

	local temp = player:GetAttribute("HiveTemperature") :: number?
	if not temp then return end
	temp = math.max(TEMP_MIN_183, math.min(TEMP_MAX_183, temp))

	-- Fill height fraction: map temp to 0..1 (cold=bottom, hot=top, opt=50%)
	local fillFrac: number
	if temp <= TEMP_OPT_183 then
		fillFrac = 0.1 + (temp / TEMP_OPT_183) * 0.4   -- 10%..50%
	else
		fillFrac = 0.5 + ((temp - TEMP_OPT_183) / (TEMP_MAX_183 - TEMP_OPT_183)) * 0.4   -- 50%..90%
	end

	local color = tempToColor_183(temp)
	local mult  = tempMult_183(temp)

	TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		Size     = UDim2.new(1, 0, fillFrac, 0),
		Position = UDim2.new(0, 0, 1 - fillFrac, 0),
		BackgroundColor3 = color,
	}):Play()

	kidLb.Text       = kidLabel_183(temp)
	kidLb.TextColor3 = color

	adLb.Text       = string.format("%d°C  ×%.2f", math.floor(temp + 0.5), mult)
	adLb.TextColor3 = if math.abs(temp - TEMP_OPT_183) < 5 then OPT_COLOR_183 else GREY_183
end

-- ── Init ──────────────────────────────────────────────────────────────────────
task.delay(1.5, function()
	buildGauge_183()
	updateGauge_183()
end)

player:GetAttributeChangedSignal("HiveTemperature"):Connect(updateGauge_183)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HiveTempGaugeController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HiveTempGaugeController")
print("HiveTempGaugeController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildGauge_183:", c.Source:find("buildGauge_183") ~= nil)
	print("  updateGauge_183:", c.Source:find("updateGauge_183") ~= nil)
	print("  HiveTemperature listener:", c.Source:find("HiveTemperature") ~= nil)
	print("  tempToColor_183:", c.Source:find("tempToColor_183") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HiveTempGaugeController: LocalScript
  lines: 180+
  buildGauge_183: true
  updateGauge_183: true
  HiveTemperature listener: true
  tempToColor_183: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Temperature | Fill height | Colour | Kid label | Adult label |
|-------------|-------------|--------|-----------|-------------|
| 0–15 °C | 10–21% | Icy blue | "🌡️ Brrr — too cold!" | e.g. "8°C  ×0.61" |
| 15–25 °C | 21–37% | Blue→gold lerp | "🌡️ A bit chilly" | e.g. "20°C  ×0.79" |
| 25–40 °C | 37–53% | Honey gold | "🌡️ Perfect warmth!" | e.g. "35°C  ×1.00" |
| 40–50 °C | 53–67% | Gold→orange lerp | "🌡️ Getting warm" | e.g. "45°C  ×0.86" |
| 50–60 °C | 67–90% | Hot orange | "🌡️ Too hot in here!" | e.g. "58°C  ×0.67" |
| Attribute changes | 0.5s Sine tween | colour transitions | updates immediately | updates immediately |

**Part budget: +0 permanent → 4,204 / 5,000**
