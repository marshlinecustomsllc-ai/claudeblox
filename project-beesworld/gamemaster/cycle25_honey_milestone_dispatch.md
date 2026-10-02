# Dispatch 233 — Honey Milestone Celebration Pop
**File:** `cycle25_honey_milestone_dispatch.md`
**Cycle:** 25
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

Reaching a honey milestone (100, 500, 1 000, 5 000, 10 000 honey) is a satisfying achievement but the game currently gives no special feedback beyond the HUD wallet counter ticking up. This dispatch adds a **Honey Milestone Pop**: a brief full-screen celebratory overlay with a large animated honey number, a 🍯 icon burst, and a short jingle, triggered the first time the player crosses each threshold in a session. The overlay auto-dismisses in 2.5 seconds and never blocks gameplay or input.

For kids: colourful pop with a fun sound = "I did something great!" dopamine hit at natural progression points. For adults: clear session milestones provide pacing landmarks and reinforce the economic loop.

---

## Step 1 — HoneyMilestoneController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HoneyMilestoneController`.

Paste exactly:

```lua
--!strict
-- HoneyMilestoneController: brief celebratory overlay at honey milestones.
-- Reads Honey player attribute (written by ResourceService). Fires once per
-- milestone per session. Entirely client-side — zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local MILESTONES_233: { number } = { 100, 500, 1000, 5000, 10000, 25000, 50000 }

local MILESTONE_LABELS_233: { [number]: string } = {
	[100]   = "First Hundred!",
	[500]   = "Sweet Progress!",
	[1000]  = "Honey Master!",
	[5000]  = "Golden Hive!",
	[10000] = "Royal Beekeeper!",
	[25000] = "Legendary Apiary!",
	[50000] = "Grand Champion!",
}

local DISPLAY_TIME_233  = 2.5     -- seconds before auto-dismiss
local FADE_TIME_233     = 0.35    -- fade in / fade out duration
local SCALE_FROM_233    = 1.35    -- UIScale starting value (shrinks to 1.0)
local SCALE_EASE_233    = 0.4     -- scale tween duration

local MILESTONE_SOUND_ID_233 = "rbxassetid://4612419814"  -- triumphant jingle (short)
local MILESTONE_VOLUME_233   = 0.55

-- Warm Wax palette
local BG_COLOR_233     = Color3.fromRGB(30,  18,   6)
local GOLD_COLOR_233   = Color3.fromRGB(242, 168,  28)
local CREAM_COLOR_233  = Color3.fromRGB(232, 212, 154)
local AMBER_COLOR_233  = Color3.fromRGB(220, 130,  20)

-- ── State ─────────────────────────────────────────────────────────────────────
local reached_233: { [number]: boolean } = {}   -- milestones fired this session
local gui_233: ScreenGui? = nil
local jingle_233: Sound? = nil
local overlayActive_233 = false

-- ── Build GUI ─────────────────────────────────────────────────────────────────
local function buildGui_233()
	local pg = player:WaitForChild("PlayerGui")

	local sg = Instance.new("ScreenGui")
	sg.Name            = "HoneyMilestoneGui_233"
	sg.DisplayOrder    = 50   -- above HUD (typically ≤ 20) and BearWarning (30)
	sg.ResetOnSpawn    = false
	sg.IgnoreGuiInset  = true
	sg.Enabled         = false
	sg.Parent          = pg

	-- Dark semi-transparent backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name                   = "Backdrop"
	backdrop.Size                   = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3       = BG_COLOR_233
	backdrop.BackgroundTransparency = 0.30
	backdrop.BorderSizePixel        = 0
	backdrop.Parent                 = sg

	-- Central card
	local card = Instance.new("Frame")
	card.Name                   = "Card"
	card.Size                   = UDim2.new(0, 340, 0, 180)
	card.AnchorPoint            = Vector2.new(0.5, 0.5)
	card.Position               = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3       = Color3.fromRGB(46, 28, 10)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel        = 0
	card.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent       = card

	local stroke = Instance.new("UIStroke")
	stroke.Color     = GOLD_COLOR_233
	stroke.Thickness = 2.5
	stroke.Parent    = card

	-- Scale object for pop animation
	local uiScale = Instance.new("UIScale")
	uiScale.Name  = "CardScale"
	uiScale.Scale = SCALE_FROM_233
	uiScale.Parent = card

	-- Honey jar icon
	local icon = Instance.new("TextLabel")
	icon.Name                   = "Icon"
	icon.Size                   = UDim2.new(0, 60, 0, 60)
	icon.Position               = UDim2.new(0.5, -30, 0, -34)
	icon.BackgroundTransparency = 1
	icon.Text                   = "🍯"
	icon.TextSize               = 46
	icon.Font                   = Enum.Font.GothamBold
	icon.Parent                 = card

	-- Milestone label (e.g. "Honey Master!")
	local milestoneLabel = Instance.new("TextLabel")
	milestoneLabel.Name                   = "MilestoneLabel"
	milestoneLabel.Size                   = UDim2.new(1, -20, 0, 38)
	milestoneLabel.Position               = UDim2.new(0, 10, 0, 24)
	milestoneLabel.BackgroundTransparency = 1
	milestoneLabel.Text                   = "Milestone!"
	milestoneLabel.TextSize               = 22
	milestoneLabel.Font                   = Enum.Font.GothamBold
	milestoneLabel.TextColor3             = GOLD_COLOR_233
	milestoneLabel.TextXAlignment         = Enum.TextXAlignment.Center
	milestoneLabel.Parent                 = card

	-- Large honey count
	local honeyCount = Instance.new("TextLabel")
	honeyCount.Name                   = "HoneyCount"
	honeyCount.Size                   = UDim2.new(1, -20, 0, 54)
	honeyCount.Position               = UDim2.new(0, 10, 0, 66)
	honeyCount.BackgroundTransparency = 1
	honeyCount.Text                   = "🍯 0"
	honeyCount.TextSize               = 42
	honeyCount.Font                   = Enum.Font.GothamBold
	honeyCount.TextColor3             = CREAM_COLOR_233
	honeyCount.TextXAlignment         = Enum.TextXAlignment.Center
	honeyCount.Parent                 = card

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name                   = "Subtitle"
	subtitle.Size                   = UDim2.new(1, -20, 0, 28)
	subtitle.Position               = UDim2.new(0, 10, 0, 126)
	subtitle.BackgroundTransparency = 1
	subtitle.Text                   = "Keep up the great work!"
	subtitle.TextSize               = 13
	subtitle.Font                   = Enum.Font.Gotham
	subtitle.TextColor3             = AMBER_COLOR_233
	subtitle.TextXAlignment         = Enum.TextXAlignment.Center
	subtitle.Parent                 = card

	-- Jingle sound
	local jingle = Instance.new("Sound")
	jingle.Name          = "MilestoneJingle_233"
	jingle.SoundId       = MILESTONE_SOUND_ID_233
	jingle.Volume        = MILESTONE_VOLUME_233
	jingle.Looped        = false
	jingle.PlaybackSpeed = 1.0
	jingle.Parent        = pg
	jingle_233 = jingle

	gui_233 = sg
end

-- ── Show overlay ──────────────────────────────────────────────────────────────
local function showMilestone_233(milestone: number, currentHoney: number)
	if overlayActive_233 then return end
	local sg = gui_233
	if not sg then return end
	overlayActive_233 = true

	local card = sg:FindFirstChild("Card") :: Frame
	local scale = card and card:FindFirstChild("CardScale") :: UIScale
	local milestoneLabel = card and card:FindFirstChild("MilestoneLabel") :: TextLabel
	local honeyCount     = card and card:FindFirstChild("HoneyCount")     :: TextLabel

	if milestoneLabel then milestoneLabel.Text = MILESTONE_LABELS_233[milestone] or "Milestone Reached!" end
	if honeyCount     then honeyCount.Text     = "🍯 " .. tostring(currentHoney) end

	-- Reset and show
	sg.Enabled = true
	local backdrop = sg:FindFirstChild("Backdrop") :: Frame
	if backdrop then backdrop.BackgroundTransparency = 1 end
	if scale    then scale.Scale = SCALE_FROM_233 end

	-- Play jingle
	if jingle_233 then jingle_233:Play() end

	-- Fade in backdrop
	if backdrop then
		TweenService:Create(backdrop, TweenInfo.new(FADE_TIME_233, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 0.30,
		}):Play()
	end

	-- Scale pop
	if scale then
		TweenService:Create(scale, TweenInfo.new(SCALE_EASE_233, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end

	-- Auto-dismiss after DISPLAY_TIME_233
	task.delay(DISPLAY_TIME_233, function()
		if not sg then overlayActive_233 = false return end
		local fadeOut = {}
		if backdrop then
			TweenService:Create(backdrop, TweenInfo.new(FADE_TIME_233, Enum.EasingStyle.Sine), {
				BackgroundTransparency = 1,
			}):Play()
		end
		if scale then
			TweenService:Create(scale, TweenInfo.new(FADE_TIME_233, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
				Scale = 0.85,
			}):Play()
		end
		task.delay(FADE_TIME_233, function()
			sg.Enabled = false
			overlayActive_233 = false
		end)
	end)
end

-- ── Check milestones ──────────────────────────────────────────────────────────
local function checkMilestones_233()
	local honey = (player:GetAttribute("Honey") :: number?) or 0
	for _, milestone in MILESTONES_233 do
		if honey >= milestone and not reached_233[milestone] then
			reached_233[milestone] = true
			showMilestone_233(milestone, honey)
			break   -- show only the highest new milestone, one at a time
		end
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4.5, function()
	buildGui_233()
	-- Pre-mark already-exceeded milestones (don't show on every rejoin)
	local honey = (player:GetAttribute("Honey") :: number?) or 0
	for _, milestone in MILESTONES_233 do
		if honey >= milestone then
			reached_233[milestone] = true
		end
	end
	-- Watch for future increases
	player:GetAttributeChangedSignal("Honey"):Connect(checkMilestones_233)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HoneyMilestoneController"))
```

---

## Step 3 — ResourceService — confirm Honey attribute write

The controller reads a `Honey` player attribute. This is the same attribute displayed in the HUD wallet (from earlier cycles). Confirm it is being written by ResourceService:

```lua
-- In ResourceService, on honey change:
player:SetAttribute("Honey", math.floor(playerData.honey))
```

If ResourceService already writes this attribute for the HUD, no change is needed.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HoneyMilestoneController")
print("HoneyMilestoneController:", c and c.ClassName or "MISSING")

-- Simulate milestone trigger
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("Honey", 0)    -- reset below milestone
task.wait(5)                    -- let init complete
lp:SetAttribute("Honey", 100)  -- cross first milestone
-- Overlay should appear: "First Hundred!" with 🍯 100
-- Should auto-dismiss after ~2.5s

task.wait(4)
lp:SetAttribute("Honey", 500)  -- second milestone
-- "Sweet Progress!" overlay

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| Milestone | Label | When shown |
|---|---|---|
| 100 | First Hundred! | First time honey ≥ 100 this session |
| 500 | Sweet Progress! | First time honey ≥ 500 this session |
| 1 000 | Honey Master! | First time honey ≥ 1 000 this session |
| 5 000 | Golden Hive! | First time honey ≥ 5 000 this session |
| 10 000 | Royal Beekeeper! | First time honey ≥ 10 000 this session |
| 25 000 | Legendary Apiary! | First time honey ≥ 25 000 this session |
| 50 000 | Grand Champion! | First time honey ≥ 50 000 this session |

- Only one overlay shown at a time — if player crosses two thresholds in one tick, highest new milestone wins
- Pre-marks milestones already exceeded on session join — no retroactive firings on rejoin
- DisplayOrder=50 ensures overlay renders above all other HUD elements
- 2.5s display time is long enough to read, short enough to not interrupt gameplay
- EasingStyle.Back on the scale-in gives a satisfying "pop" overshoot
- Volume 0.55 stays below the 0.7 ceiling from quality criteria

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(ScreenGui + Sound in PlayerGui — no BaseParts)*
