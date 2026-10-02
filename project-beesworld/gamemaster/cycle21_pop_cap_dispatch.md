# Dispatch 211 — Population Cap Warning
**File:** `cycle21_pop_cap_dispatch.md`
**Cycle:** 21
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture's three-way production bottleneck (SUPPLY / WINGS / COMB) is only useful if players can identify which one is currently limiting them. Population (WINGS) caps out based on the number of Brood cells, but there is currently no feedback when a player is near or at that cap. This dispatch adds a **Population Cap Warning**: a persistent HUD pill at the bottom-left of the screen that appears when `CurrentBees` is within 3 of `MaxBees`, displays the current vs max count, and shows a short "Add a Brood Cell to grow!" hint. Updates reactively on `CurrentBees` and `MaxBees` attribute changes. Disappears when comfortably below cap. Entirely client-side.

---

## Step 1 — PopCapController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PopCapController`.

Paste exactly:

```lua
--!strict
-- PopCapController: HUD warning when bee population is near or at the current cap.
-- Reads CurrentBees and MaxBees player attributes.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local WARN_MARGIN_211     = 3       -- show warning when MaxBees - CurrentBees <= this
local SCAN_INTERVAL_211   = 5.0
local FADE_TIME_211       = 0.25

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_211    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_211  = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD_211 = Color3.fromRGB(242, 168,  28)
local WARN_AMBER_211 = Color3.fromRGB(220, 100,  20)   -- amber for "at cap"
local AT_CAP_RED_211 = Color3.fromRGB(200,  40,  20)   -- red for "exactly at cap"
local DIM_211        = Color3.fromRGB(160, 140, 100)

-- ── State ─────────────────────────────────────────────────────────────────────
local pillGui_211: ScreenGui? = nil
local shown_211               = false

-- ── Build pill ────────────────────────────────────────────────────────────────
local function buildPill_211(): ScreenGui
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return nil :: any end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "PopCapPill_211"
	sg.DisplayOrder   = 19
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Name                   = "PillFrame"
	frame.Size                   = UDim2.new(0, 180, 0, 42)
	frame.AnchorPoint            = Vector2.new(0, 1)
	frame.Position               = UDim2.new(0, 8, 1, -90)   -- bottom-left, above route limit pill
	frame.BackgroundColor3       = DARK_BG_211
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "PillStroke"
	stroke.Color     = WARN_AMBER_211
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local topLabel = Instance.new("TextLabel")
	topLabel.Name               = "PopLine"
	topLabel.Size               = UDim2.new(1, -8, 0.52, 0)
	topLabel.Position           = UDim2.new(0, 4, 0, 0)
	topLabel.BackgroundTransparency = 1
	topLabel.Text               = "🐝 0 / 0 bees"
	topLabel.TextSize           = 12
	topLabel.Font               = Enum.Font.GothamBold
	topLabel.TextColor3         = WARN_AMBER_211
	topLabel.TextXAlignment     = Enum.TextXAlignment.Left
	topLabel.ZIndex             = 2
	topLabel.Parent             = frame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name               = "HintLine"
	hintLabel.Size               = UDim2.new(1, -8, 0.40, 0)
	hintLabel.Position           = UDim2.new(0, 4, 0.55, 0)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text               = "Add a Brood Cell to grow!"
	hintLabel.TextSize           = 10
	hintLabel.Font               = Enum.Font.Gotham
	hintLabel.TextColor3         = DIM_211
	hintLabel.TextXAlignment     = Enum.TextXAlignment.Left
	hintLabel.ZIndex             = 2
	hintLabel.Parent             = frame

	return sg
end

-- ── Update pill labels ─────────────────────────────────────────────────────────
local function updateLabels_211(current: number, max: number)
	if not pillGui_211 then return end
	local frame = pillGui_211:FindFirstChildOfClass("Frame")
	if not frame then return end

	local popLine  = frame:FindFirstChild("PopLine") :: TextLabel?
	local hintLine = frame:FindFirstChild("HintLine") :: TextLabel?
	local stroke   = frame:FindFirstChild("PillStroke") :: UIStroke?

	local atCap = (current >= max)
	local col = atCap and AT_CAP_RED_211 or WARN_AMBER_211

	if popLine  then
		popLine.Text       = "🐝 " .. tostring(current) .. " / " .. tostring(max) .. " bees"
		popLine.TextColor3 = col
	end
	if hintLine then
		hintLine.Text = atCap and "At capacity — add Brood Cells!" or "Nearly full — add a Brood Cell"
	end
	if stroke then stroke.Color = col end
end

-- ── Show pill ─────────────────────────────────────────────────────────────────
local function showPill_211(current: number, max: number)
	if not pillGui_211 then
		pillGui_211 = buildPill_211()
		if not pillGui_211 then return end
	end
	if not shown_211 then
		shown_211 = true
		local frame = pillGui_211:FindFirstChildOfClass("Frame")
		if frame then
			frame.BackgroundTransparency = 1
			TweenService:Create(frame, TweenInfo.new(FADE_TIME_211, Enum.EasingStyle.Sine), {
				BackgroundTransparency = 0.12,
			}):Play()
		end
	end
	updateLabels_211(current, max)
end

-- ── Hide pill ─────────────────────────────────────────────────────────────────
local function hidePill_211()
	if not shown_211 or not pillGui_211 then return end
	shown_211 = false
	local frame = pillGui_211 and pillGui_211:FindFirstChildOfClass("Frame")
	if frame then
		TweenService:Create(frame, TweenInfo.new(FADE_TIME_211, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 1,
		}):Play()
	end
end

-- ── Check and update ─────────────────────────────────────────────────────────
local function check_211()
	local current = (player:GetAttribute("CurrentBees") :: number?) or 0
	local max     = (player:GetAttribute("MaxBees") :: number?) or 0

	if max <= 0 then hidePill_211() return end
	if (max - current) <= WARN_MARGIN_211 then
		showPill_211(current, max)
	else
		hidePill_211()
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	check_211()

	player:GetAttributeChangedSignal("CurrentBees"):Connect(check_211)
	player:GetAttributeChangedSignal("MaxBees"):Connect(check_211)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= SCAN_INTERVAL_211 then
			acc = 0
			check_211()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PopCapController"))
```

---

## Step 3 — Attribute source (PopulationService)

`PopCapController` reads two player attributes:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `CurrentBees` | number | PopulationService | Total live bees across all castes |
| `MaxBees` | number | PopulationService | Current population cap (scales with Brood cell count) |

Both should already be written by PopulationService (dispatch 10 / the economy dispatch). If not yet added, set them after each hatch/death event:

```lua
-- In PopulationService, after population changes:
player:SetAttribute("CurrentBees", totalBees)
player:SetAttribute("MaxBees", maxCapacity)
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PopCapController")
print("PopCapController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildPill_211:", c.Source:find("buildPill_211") ~= nil)
	print("  check_211:", c.Source:find("check_211") ~= nil)
	print("  WARN_MARGIN_211:", c.Source:find("WARN_MARGIN_211") ~= nil)
	print("  CurrentBees attr:", c.Source:find("CurrentBees") ~= nil)
	print("  MaxBees attr:", c.Source:find("MaxBees") ~= nil)
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
-- Comfortably below cap — no pill
lp:SetAttribute("CurrentBees", 5)
lp:SetAttribute("MaxBees", 20)
task.wait(1)
-- Near cap — pill appears
lp:SetAttribute("CurrentBees", 18)
lp:SetAttribute("MaxBees", 20)
task.wait(2)
-- At cap — pill turns red
lp:SetAttribute("CurrentBees", 20)
task.wait(2)
-- Drop below margin — pill fades out
lp:SetAttribute("MaxBees", 30)
```

**Expected output:**
```
PopCapController: LocalScript
  lines: 140+
  buildPill_211: true
  check_211: true
  WARN_MARGIN_211: true
  CurrentBees attr: true
  MaxBees attr: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Condition | Pill | Colour | Hint text |
|---|---|---|---|
| MaxBees - CurrentBees > 3 | Hidden | — | — |
| MaxBees - CurrentBees ≤ 3 | Visible | Amber stroke | "Nearly full — add a Brood Cell" |
| CurrentBees = MaxBees (at cap) | Visible | Red stroke | "At capacity — add Brood Cells!" |
| New Brood Cell built (MaxBees increases) | Fades out | — | — |

- Pill sits at bottom-left (8px from edge, 90px from bottom) — above the RouteLimitController pill (dispatch 198) at 56px, below the main HUD at 120px
- Updates in-place on every attribute change — no rebuild, no flicker
- Fade in/out 0.25s — smooth, not disruptive
- The hint text is deliberately kid-friendly ("Add a Brood Cell to grow!") — both audiences understand it, but a child gets the clear action

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(ScreenGui only — no BaseParts)*
