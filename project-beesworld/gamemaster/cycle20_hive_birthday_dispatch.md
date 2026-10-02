# Dispatch 200 — Hive Birthday Toast
**File:** `cycle20_hive_birthday_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Players who return to the game multiple times deserve a small celebration moment. This dispatch fires a **Hive Birthday Toast** on the player's 7th session join — a warm full-screen overlay with a confetti burst of honey-gold dots, the message "🎂 Your hive is one week old!", and a subtitle showing their total lifetime honey harvested. The milestone check uses the existing `TotalSessions` player attribute (incremented by DataService on each join). The confetti is a 2-second Heartbeat particle animation of Frame dots — no ParticleEmitter, no server writes. Runs once per session and guards against re-showing with a `hasShown_200` flag.

---

## Step 1 — HiveBirthdayController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HiveBirthdayController`.

Paste exactly:

```lua
--!strict
-- HiveBirthdayController: 7th-session "Hive Birthday" celebration toast.
-- Reads TotalSessions and TotalHoneyHarvested player attributes from DataService.
-- Entirely client-side — zero server writes.

local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local BIRTHDAY_SESSION_200  = 7       -- session count that triggers the toast
local CONFETTI_COUNT_200    = 28      -- number of confetti dots
local CONFETTI_DURATION_200 = 2.4    -- seconds confetti animates
local OVERLAY_HOLD_200      = 4.0    -- seconds the full overlay stays before fading
local CHECK_DELAY_200       = 5.0    -- seconds after join to check (let attrs load)

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_200    = Color3.fromRGB( 30,  18,   8)
local HONEY_GOLD_200 = Color3.fromRGB(242, 168,  28)
local WAX_CREAM_200  = Color3.fromRGB(232, 212, 154)
local AMBER_200      = Color3.fromRGB(220, 130,  20)
local SOFT_GOLD_200  = Color3.fromRGB(255, 220, 100)

local CONFETTI_COLORS_200 = {
	Color3.fromRGB(242, 168,  28),   -- honey gold
	Color3.fromRGB(232, 212, 154),   -- wax cream
	Color3.fromRGB(220, 130,  20),   -- amber
	Color3.fromRGB(255, 200,  80),   -- light gold
	Color3.fromRGB(255, 240, 160),   -- pale yellow
}

-- ── Run-once guard ────────────────────────────────────────────────────────────
local hasShown_200 = false

-- ── Spawn confetti dot ────────────────────────────────────────────────────────
local function spawnConfetti_200(parent: Frame)
	local dot = Instance.new("Frame")
	dot.Size             = UDim2.new(0, math.random(6, 14), 0, math.random(6, 14))
	dot.BackgroundColor3 = CONFETTI_COLORS_200[math.random(1, #CONFETTI_COLORS_200)]
	dot.BorderSizePixel  = 0
	-- Random start position along the top 10% of the overlay
	dot.AnchorPoint      = Vector2.new(0.5, 0.5)
	dot.Position         = UDim2.new(math.random() :: number, 0, -0.05, 0)
	dot.Parent           = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent       = dot

	-- Each dot falls at a random speed, slight horizontal drift
	local fallSpeed  = math.random(25, 70) / 100      -- 0.25..0.70 of screen height per second
	local driftSpeed = (math.random() - 0.5) * 0.15   -- ±0.075 of screen width per second
	local rotSpeed   = math.random(-180, 180)          -- degrees/second
	local startTime  = os.clock()
	local startX     = math.random()
	local startY     = -0.05

	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not dot.Parent then conn:Disconnect() return end
		local elapsed = os.clock() - startTime
		local pct     = elapsed / CONFETTI_DURATION_200
		if pct >= 1 then
			dot:Destroy()
			conn:Disconnect()
			return
		end
		local newX = startX + driftSpeed * elapsed
		local newY = startY + fallSpeed * elapsed
		dot.Position     = UDim2.new(newX, 0, newY, 0)
		dot.Rotation     = rotSpeed * elapsed
		-- Fade out in the last 30%
		dot.BackgroundTransparency = math.clamp((pct - 0.7) / 0.3, 0, 1)
	end)
end

-- ── Show the birthday overlay ─────────────────────────────────────────────────
local function showBirthday_200(totalHoney: number)
	local pg = player:WaitForChild("PlayerGui", 10) :: PlayerGui?
	if not pg then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "HiveBirthday_200"
	sg.DisplayOrder   = 60
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.ClipDescendantsToGui = false
	sg.Parent         = pg

	-- Semi-transparent backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name                   = "Backdrop"
	backdrop.Size                   = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3       = DARK_BG_200
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel        = 0
	backdrop.ZIndex                 = 1
	backdrop.Parent                 = sg

	-- Card
	local card = Instance.new("Frame")
	card.Name                   = "BirthdayCard"
	card.Size                   = UDim2.new(0, 320, 0, 130)
	card.AnchorPoint            = Vector2.new(0.5, 0.5)
	card.Position               = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3       = DARK_BG_200
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel        = 0
	card.ZIndex                 = 2
	card.Parent                 = sg

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 14)
	cardCorner.Parent       = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color     = HONEY_GOLD_200
	cardStroke.Thickness = 2
	cardStroke.Parent    = card

	-- Headline
	local headline = Instance.new("TextLabel")
	headline.Name               = "Headline"
	headline.Size               = UDim2.new(1, -20, 0, 50)
	headline.Position           = UDim2.new(0, 10, 0, 8)
	headline.BackgroundTransparency = 1
	headline.Text               = "🎂 Your hive is one week old!"
	headline.TextSize           = 22
	headline.Font               = Enum.Font.GothamBold
	headline.TextColor3         = HONEY_GOLD_200
	headline.TextWrapped        = true
	headline.TextXAlignment     = Enum.TextXAlignment.Center
	headline.ZIndex             = 3
	headline.Parent             = card

	-- Subtitle
	local sub = Instance.new("TextLabel")
	sub.Name               = "Subtitle"
	sub.Size               = UDim2.new(1, -20, 0, 28)
	sub.Position           = UDim2.new(0, 10, 0, 56)
	sub.BackgroundTransparency = 1
	sub.Text               = "You've harvested " .. totalHoney .. " 🍯 honey so far!"
	sub.TextSize           = 15
	sub.Font               = Enum.Font.Gotham
	sub.TextColor3         = WAX_CREAM_200
	sub.TextWrapped        = true
	sub.TextXAlignment     = Enum.TextXAlignment.Center
	sub.ZIndex             = 3
	sub.Parent             = card

	-- Tip
	local tip = Instance.new("TextLabel")
	tip.Name               = "Tip"
	tip.Size               = UDim2.new(1, -20, 0, 28)
	tip.Position           = UDim2.new(0, 10, 0, 88)
	tip.BackgroundTransparency = 1
	tip.Text               = "Keep dancing — your colony is thriving! 🐝"
	tip.TextSize           = 12
	tip.Font               = Enum.Font.Gotham
	tip.TextColor3         = AMBER_200
	tip.TextWrapped        = true
	tip.TextXAlignment     = Enum.TextXAlignment.Center
	tip.ZIndex             = 3
	tip.Parent             = card

	-- Confetti layer (behind card visually but still in sg)
	local confettiLayer = Instance.new("Frame")
	confettiLayer.Name                   = "ConfettiLayer"
	confettiLayer.Size                   = UDim2.new(1, 0, 1, 0)
	confettiLayer.BackgroundTransparency = 1
	confettiLayer.BorderSizePixel        = 0
	confettiLayer.ZIndex                 = 0
	confettiLayer.ClipsDescendants       = false
	confettiLayer.Parent                 = sg

	-- Fade in backdrop
	TweenService:Create(backdrop, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 0.55,
	}):Play()

	-- Card scale-in (starts small, bounces to full)
	card.Size = UDim2.new(0, 220, 0, 90)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 320, 0, 130),
	}):Play()

	-- Launch confetti staggered over the first 0.8s
	for i = 1, CONFETTI_COUNT_200 do
		task.delay(math.random() * 0.8, function()
			spawnConfetti_200(confettiLayer)
		end)
	end

	-- Hold then fade out everything
	task.delay(OVERLAY_HOLD_200, function()
		if not sg.Parent then return end
		TweenService:Create(backdrop, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(card, TweenInfo.new(0.7, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 1,
		}):Play()
		for _, lbl in card:GetDescendants() do
			if lbl:IsA("TextLabel") then
				TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
					TextTransparency = 1,
				}):Play()
			end
		end
		task.delay(0.8, function()
			if sg.Parent then sg:Destroy() end
		end)
	end)
end

-- ── Check and maybe show ──────────────────────────────────────────────────────
local function checkBirthday_200()
	if hasShown_200 then return end

	local sessions     = (player:GetAttribute("TotalSessions") :: number?) or 0
	local totalHoney   = (player:GetAttribute("TotalHoneyHarvested") :: number?) or 0

	if sessions == BIRTHDAY_SESSION_200 then
		hasShown_200 = true
		showBirthday_200(totalHoney)
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(CHECK_DELAY_200, function()
	checkBirthday_200()

	-- Also react if TotalSessions attribute arrives late
	player:GetAttributeChangedSignal("TotalSessions"):Connect(function()
		checkBirthday_200()
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HiveBirthdayController"))
```

---

## Step 3 — Attribute source (DataService)

`HiveBirthdayController` reads two player attributes:

| Attribute | Set by | When |
|---|---|---|
| `TotalSessions` | DataService | Incremented by 1 each join, saved to profile |
| `TotalHoneyHarvested` | DataService / ResourceService | Cumulative lifetime honey harvested, saved to profile |

If `TotalSessions` does not yet exist in the DataService profile schema, add it:

**In DataService `PROFILE_TEMPLATE`:**
```lua
TotalSessions        = 0,
TotalHoneyHarvested  = 0,
```

**In DataService `OnPlayerJoin` (after profile load):**
```lua
-- Increment session counter
profile.Data.TotalSessions = (profile.Data.TotalSessions or 0) + 1
player:SetAttribute("TotalSessions", profile.Data.TotalSessions)
```

**In ResourceService (or wherever CombService.Harvest is called), after honey is credited:**
```lua
local current = (player:GetAttribute("TotalHoneyHarvested") or 0) + harvested
player:SetAttribute("TotalHoneyHarvested", current)
-- Also persist to profile:
profile.Data.TotalHoneyHarvested = current
```

If `TotalSessions` and `TotalHoneyHarvested` are already tracked in the profile, only the `SetAttribute` broadcast lines are needed if they aren't already replicated.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HiveBirthdayController")
print("HiveBirthdayController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  checkBirthday_200:", c.Source:find("checkBirthday_200") ~= nil)
	print("  showBirthday_200:", c.Source:find("showBirthday_200") ~= nil)
	print("  spawnConfetti_200:", c.Source:find("spawnConfetti_200") ~= nil)
	print("  BIRTHDAY_SESSION_200:", c.Source:find("BIRTHDAY_SESSION_200") ~= nil)
	print("  TotalSessions attr:", c.Source:find("TotalSessions") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HiveBirthdayController: LocalScript
  lines: 170+
  checkBirthday_200: true
  showBirthday_200: true
  spawnConfetti_200: true
  BIRTHDAY_SESSION_200: true
  TotalSessions attr: true
Total parts: 4204  (expect 4204)
```

---

## Quick-test in Studio Play mode

To verify the overlay without waiting for 7 real sessions, open the **Command Bar** during Play mode and run:

```lua
game:GetService("Players").LocalPlayer:SetAttribute("TotalSessions", 7)
game:GetService("Players").LocalPlayer:SetAttribute("TotalHoneyHarvested", 1840)
```

The `GetAttributeChangedSignal("TotalSessions")` hook will fire and show the overlay.

---

## Behaviour summary

| Trigger | Condition | Effect |
|---|---|---|
| Session 7 join (TotalSessions == 7) | `hasShown_200 = false` | Full overlay: backdrop + card + 28 confetti dots |
| Any other session count | — | No effect |
| Second call with `hasShown_200 = true` | — | No effect (guard) |

- Backdrop fades to 55% dark overlay; card scale-bounces in (EasingStyle.Back)
- 28 confetti dots launch staggered over 0.8s, fall and drift for 2.4s, fade out in final 30% of their animation
- Card holds for 4 seconds then entire overlay fades and is destroyed
- Confetti dots are plain Frame elements — no ParticleEmitter, no BaseParts, zero part budget impact
- Works for both returning players (who already have session 7 when they join) and active sessions (attribute arrives via DataService after join)

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(HiveBirthday_200 ScreenGui + transient Frame confetti dots — all GuiObjects, not BaseParts; destroyed after animation)*
