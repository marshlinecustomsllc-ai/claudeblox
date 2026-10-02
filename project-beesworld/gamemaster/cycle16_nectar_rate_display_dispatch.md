# Dispatch 176 — Nectar Flow Rate Display
**File:** `cycle16_nectar_rate_display_dispatch.md`
**Cycle:** 16
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The existing HUD shows the player's current honey count and a supply bar, but gives no indication of the *rate* at which honey is building up. Players have no sense of whether their hive is fast or slow compared to its potential, or which bottleneck is limiting them. This dispatch adds a **Nectar Flow Rate Display** to the HUD: a small live readout of honey/s, a colour-coded bottleneck label (WINGS / SUPPLY / COMB), and a trend arrow (↑ / → / ↓) driven by the most recent two readings. Kids see it as a speedometer. Adults use it to optimise their build order.

The display piggybacks on the existing `RatesUpdate` RemoteEvent (fired every 5s by ForagingService). No new server code. Entirely client-side.

---

## Step 1 — NectarRateController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `NectarRateController`.

Paste exactly:

```lua
--!strict
-- NectarRateController: live honey/s readout with bottleneck label and trend arrow.
-- Piggybacks on the existing RatesUpdate RemoteEvent — no new server code.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_176  = Color3.fromRGB(242, 168, 28)
local WAX_CREAM_176   = Color3.fromRGB(232, 212, 154)
local DARK_BG_176     = Color3.fromRGB(30,  18,  8)
local GREEN_176       = Color3.fromRGB(80,  200, 80)
local AMBER_176       = Color3.fromRGB(255, 160, 30)
local RED_176         = Color3.fromRGB(220, 60,  60)
local GREY_176        = Color3.fromRGB(130, 120, 110)

-- ── State ─────────────────────────────────────────────────────────────────────
local lastRate_176: number? = nil

-- ── Build display ─────────────────────────────────────────────────────────────
-- Try to attach to an existing HUD ScreenGui; fall back to own ScreenGui
local function buildDisplay_176(): (Frame, TextLabel, TextLabel, TextLabel)
	local hudGui = PlayerGui:FindFirstChild("HudGui") :: ScreenGui?
	local parentGui: GuiObject

	if hudGui then
		parentGui = hudGui :: any
	else
		local sg = Instance.new("ScreenGui")
		sg.Name           = "NectarRateGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 12
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui
		parentGui = sg :: any
	end

	-- Card: right side of screen, below any health bars
	local card = Instance.new("Frame")
	card.Name              = "NectarRateCard"
	card.Size              = UDim2.new(0, 130, 0, 54)
	card.Position          = UDim2.new(1, -142, 0, 52)
	card.BackgroundColor3  = DARK_BG_176
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel   = 0
	card.ZIndex            = 22
	card.Parent            = parentGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_GOLD_176
	stroke.Thickness = 1
	stroke.Parent    = card

	-- Rate row: trend arrow + "X.XX /s"
	local rateRow = Instance.new("Frame")
	rateRow.Name              = "RateRow"
	rateRow.Size              = UDim2.new(1, -8, 0, 26)
	rateRow.Position          = UDim2.new(0, 4, 0, 4)
	rateRow.BackgroundTransparency = 1
	rateRow.ZIndex            = 23
	rateRow.Parent            = card

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name           = "ArrowLabel"
	arrowLabel.Size           = UDim2.new(0, 18, 1, 0)
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Text           = "→"
	arrowLabel.TextSize       = 16
	arrowLabel.Font           = Enum.Font.GothamBold
	arrowLabel.TextColor3     = GREY_176
	arrowLabel.ZIndex         = 24
	arrowLabel.Parent         = rateRow

	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name            = "RateLabel"
	rateLabel.Size            = UDim2.new(1, -20, 1, 0)
	rateLabel.Position        = UDim2.new(0, 20, 0, 0)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text            = "— /s"
	rateLabel.TextSize        = 15
	rateLabel.Font            = Enum.Font.GothamBold
	rateLabel.TextColor3      = HONEY_GOLD_176
	rateLabel.ZIndex          = 24
	rateLabel.Parent          = rateRow

	-- Bottleneck row
	local bnRow = Instance.new("Frame")
	bnRow.Name              = "BnRow"
	bnRow.Size              = UDim2.new(1, -8, 0, 18)
	bnRow.Position          = UDim2.new(0, 4, 0, 32)
	bnRow.BackgroundTransparency = 1
	bnRow.ZIndex            = 23
	bnRow.Parent            = card

	local bnLabel = Instance.new("TextLabel")
	bnLabel.Name            = "BnLabel"
	bnLabel.Size            = UDim2.new(0, 56, 1, 0)
	bnLabel.BackgroundTransparency = 1
	bnLabel.Text            = "limit:"
	bnLabel.TextSize        = 10
	bnLabel.Font            = Enum.Font.Gotham
	bnLabel.TextColor3      = GREY_176
	bnLabel.ZIndex          = 24
	bnLabel.Parent          = bnRow

	local bnValueLabel = Instance.new("TextLabel")
	bnValueLabel.Name           = "BnValueLabel"
	bnValueLabel.Size           = UDim2.new(0, 62, 1, 0)
	bnValueLabel.Position       = UDim2.new(0, 58, 0, 0)
	bnValueLabel.BackgroundTransparency = 1
	bnValueLabel.Text           = "—"
	bnValueLabel.TextSize       = 10
	bnValueLabel.Font           = Enum.Font.GothamBold
	bnValueLabel.TextColor3     = WAX_CREAM_176
	bnValueLabel.ZIndex         = 24
	bnValueLabel.Parent         = bnRow

	return card, arrowLabel, rateLabel, bnValueLabel
end

-- ── Bottleneck colour ─────────────────────────────────────────────────────────
local function bnColor_176(bottleneck: string?): Color3
	if bottleneck == "WINGS" then return RED_176
	elseif bottleneck == "SUPPLY" then return AMBER_176
	elseif bottleneck == "COMB" then return GREEN_176
	end
	return GREY_176
end

-- ── Update display ────────────────────────────────────────────────────────────
local card_176: Frame? = nil
local arrowLabel_176: TextLabel? = nil
local rateLabel_176: TextLabel? = nil
local bnValueLabel_176: TextLabel? = nil

task.delay(1, function()
	card_176, arrowLabel_176, rateLabel_176, bnValueLabel_176 = buildDisplay_176()
end)

local function updateDisplay_176(honeyRate: number, bottleneck: string?)
	local rateLabel  = rateLabel_176
	local arrowLabel = arrowLabel_176
	local bnValue    = bnValueLabel_176
	if not rateLabel or not arrowLabel or not bnValue then return end

	-- Format rate
	local rateText: string
	if honeyRate >= 10 then
		rateText = string.format("%.1f /s", honeyRate)
	else
		rateText = string.format("%.2f /s", honeyRate)
	end
	rateLabel.Text = rateText

	-- Trend arrow
	local arrow = "→"
	local arrowColor = GREY_176
	if lastRate_176 then
		local delta = honeyRate - lastRate_176
		if delta > 0.01 then
			arrow = "↑"
			arrowColor = GREEN_176
		elseif delta < -0.01 then
			arrow = "↓"
			arrowColor = RED_176
		end
	end
	arrowLabel.Text       = arrow
	arrowLabel.TextColor3 = arrowColor

	-- Rate colour: green if high, gold if medium, red if very low
	local rateColor: Color3
	if honeyRate > 1.0 then
		rateColor = GREEN_176
	elseif honeyRate > 0.2 then
		rateColor = HONEY_GOLD_176
	elseif honeyRate > 0 then
		rateColor = AMBER_176
	else
		rateColor = GREY_176
	end

	TweenService:Create(rateLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{ TextColor3 = rateColor }):Play()

	-- Bottleneck
	local bnText  = bottleneck or "—"
	local bnColor = bnColor_176(bottleneck)
	bnValue.Text       = bnText
	bnValue.TextColor3 = bnColor

	lastRate_176 = honeyRate
end

-- ── Listen to RatesUpdate ─────────────────────────────────────────────────────
-- RatesUpdate payload: honeyRate, pollRate, supplyRate, bottleneck, shedMult, kilnMult, queenMult
local ratesUpdate = Remotes:FindFirstChild("RatesUpdate") :: RemoteEvent?
if ratesUpdate then
	ratesUpdate.OnClientEvent:Connect(function(
		honeyRate:   number,
		_pollRate:   number,
		_supplyRate: number,
		bottleneck:  string?,
		_shed:       number?,
		_kiln:       number?,
		_queen:      number?
	)
		updateDisplay_176(honeyRate, bottleneck)
	end)
else
	-- Fallback: poll BeeCount attribute as a proxy for activity
	task.spawn(function()
		while true do
			task.wait(10)
			local re = Remotes:FindFirstChild("RatesUpdate") :: RemoteEvent?
			if re then
				re.OnClientEvent:Connect(function(
					honeyRate: number,
					_pollRate: number,
					_supplyRate: number,
					bottleneck: string?
				)
					updateDisplay_176(honeyRate, bottleneck)
				end)
				break
			end
		end
	end)
end
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("NectarRateController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("NectarRateController")
print("NectarRateController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  updateDisplay_176:", c.Source:find("updateDisplay_176") ~= nil)
	print("  RatesUpdate listener:", c.Source:find("RatesUpdate") ~= nil)
	print("  bottleneck colours:", c.Source:find("bnColor_176") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
NectarRateController: LocalScript
  lines: 180+
  updateDisplay_176: true
  RatesUpdate listener: true
  bottleneck colours: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Display |
|-------|---------|
| No data yet | "— /s", grey arrow →, bottleneck "—" |
| Rate rising vs last reading | ↑ green arrow, rate in green |
| Rate steady | → grey arrow |
| Rate falling | ↓ red arrow, rate may amber/grey |
| Bottleneck = WINGS | Bottleneck label red — "need more foraging dances" |
| Bottleneck = SUPPLY | Bottleneck label amber — "flower patch supply low" |
| Bottleneck = COMB | Bottleneck label green — "add more Honey cells" |
| Update cadence | Every 5s (RatesUpdate) |
| Card position | Right side (1, -142, 0, 52) below health/status bars |
| HudGui attach | Attaches to HudGui if found; own ScreenGui otherwise |

**Part budget: +0 permanent → 4,204 / 5,000**
