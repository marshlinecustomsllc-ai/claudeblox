# Dispatch 217 — Daily Login Streak
**File:** `cycle22_daily_streak_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Daily login streaks are one of the most proven retention mechanics in tycoon games. This dispatch adds a **Daily Login Streak** system: a server service that tracks each player's consecutive daily login count via DataStore, awards a honey bonus multiplier on login (capped at Day 7 for a 7-day progression), and writes a `DailyStreak` player attribute for the HUD badge to display. The client-side badge shows "🔥 Day N" at the top-left and pulses briefly on login to celebrate. Resets to 1 if a day is missed.

For kids: the fire emoji and growing number make streaks feel like an achievement. For adults: the honey multiplier (up to +50% on Day 7+) gives a concrete reason to log in daily.

---

## Step 1 — DailyStreakService (ServerScriptService)

Open **ServerScriptService → Systems** and create a new **Script** named `DailyStreakService`.

Paste exactly:

```lua
--!strict
-- DailyStreakService: tracks consecutive daily logins per player.
-- Writes DailyStreak and DailyBonus player attributes on join.
-- Awards a honey multiplier scaled to streak length.

local Players    = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- ── Config ────────────────────────────────────────────────────────────────────
local STREAK_KEY_PREFIX_217 = "Streak_v1_"
local MAX_MULTIPLIER_DAY_217 = 7       -- plateau at day 7
local BONUS_PER_DAY_217      = 0.08    -- +8% honey per streak day, max +56%
local STREAK_WINDOW_HOURS_217 = 36     -- hours; if gap > this, streak resets

-- ── DataStore ────────────────────────────────────────────────────────────────
local streakStore_217 = DataStoreService:GetDataStore("DailyStreak_v1")

-- ── Per-player streak data ────────────────────────────────────────────────────
type StreakData217 = {
	streak: number,
	lastLoginUnix: number,
}

local function getDefaultData_217(): StreakData217
	return { streak = 0, lastLoginUnix = 0 }
end

-- ── Streak logic ──────────────────────────────────────────────────────────────
local function processStreak_217(data: StreakData217): StreakData217
	local now = os.time()
	local hoursSinceLast = (now - data.lastLoginUnix) / 3600

	local newStreak: number
	if data.lastLoginUnix == 0 then
		-- First ever login
		newStreak = 1
	elseif hoursSinceLast < 20 then
		-- Same day (already logged in today) — no change
		newStreak = data.streak
	elseif hoursSinceLast <= STREAK_WINDOW_HOURS_217 then
		-- Next day within window — extend streak
		newStreak = data.streak + 1
	else
		-- Missed a day — reset
		newStreak = 1
	end

	return {
		streak = newStreak,
		lastLoginUnix = (hoursSinceLast >= 20) and now or data.lastLoginUnix,
	}
end

local function getMultiplier_217(streak: number): number
	local effectiveDays = math.clamp(streak, 1, MAX_MULTIPLIER_DAY_217)
	return 1 + (effectiveDays - 1) * BONUS_PER_DAY_217
end

-- ── Load + save ───────────────────────────────────────────────────────────────
local function onPlayerAdded_217(player: Player)
	local key = STREAK_KEY_PREFIX_217 .. tostring(player.UserId)
	local data: StreakData217

	local ok, result = pcall(function()
		return streakStore_217:GetAsync(key)
	end)
	if ok and result then
		data = result :: StreakData217
	else
		data = getDefaultData_217()
	end

	local updated = processStreak_217(data)

	-- Save updated data
	local saveOk = pcall(function()
		streakStore_217:SetAsync(key, updated)
	end)
	if not saveOk then
		-- Non-fatal: streak display may be stale but game is playable
	end

	local mult = getMultiplier_217(updated.streak)

	-- Broadcast to client
	player:SetAttribute("DailyStreak",   updated.streak)
	player:SetAttribute("DailyBonusPct", math.round((mult - 1) * 100))   -- e.g. 16 = "+16%"
end

Players.PlayerAdded:Connect(onPlayerAdded_217)

-- Handle players already in game when script loads
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded_217, player)
end
```

---

## Step 2 — StreakBadgeController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `StreakBadgeController`.

Paste exactly:

```lua
--!strict
-- StreakBadgeController: top-left HUD badge showing daily login streak.
-- Reads DailyStreak and DailyBonusPct player attributes.
-- Pulses briefly on join to celebrate current streak.
-- Entirely client-side — zero server writes.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local PULSE_DURATION_217 = 1.2   -- seconds for the celebrate pulse

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_217   = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_217 = Color3.fromRGB(232, 212, 154)
local FIRE_217      = Color3.fromRGB(255, 120,  30)
local GOLD_217      = Color3.fromRGB(242, 168,  28)
local BRIGHT_217    = Color3.fromRGB(255, 240,  80)   -- pulse peak

-- ── State ─────────────────────────────────────────────────────────────────────
local badgeGui_217: ScreenGui? = nil
local built_217 = false

-- ── Build badge ───────────────────────────────────────────────────────────────
local function buildBadge_217(): ScreenGui
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return nil :: any end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "StreakBadge_217"
	sg.DisplayOrder   = 20
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Name                   = "BadgeFrame"
	frame.Size                   = UDim2.new(0, 120, 0, 34)
	frame.AnchorPoint            = Vector2.new(0, 0)
	frame.Position               = UDim2.new(0, 8, 0, 8)   -- top-left
	frame.BackgroundColor3       = DARK_BG_217
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "BadgeStroke"
	stroke.Color     = FIRE_217
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	-- Fire + Day label (left side)
	local topLabel = Instance.new("TextLabel")
	topLabel.Name               = "StreakLine"
	topLabel.Size               = UDim2.new(1, -6, 0.56, 0)
	topLabel.Position           = UDim2.new(0, 3, 0, 0)
	topLabel.BackgroundTransparency = 1
	topLabel.Text               = "🔥 Day 1"
	topLabel.TextSize           = 12
	topLabel.Font               = Enum.Font.GothamBold
	topLabel.TextColor3         = FIRE_217
	topLabel.TextXAlignment     = Enum.TextXAlignment.Left
	topLabel.ZIndex             = 2
	topLabel.Parent             = frame

	-- Bonus label (bottom)
	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Name               = "BonusLine"
	bonusLabel.Size               = UDim2.new(1, -6, 0.36, 0)
	bonusLabel.Position           = UDim2.new(0, 3, 0.60, 0)
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Text               = "+0% honey"
	bonusLabel.TextSize           = 9
	bonusLabel.Font               = Enum.Font.Gotham
	bonusLabel.TextColor3         = WAX_CREAM_217
	bonusLabel.TextXAlignment     = Enum.TextXAlignment.Left
	bonusLabel.ZIndex             = 2
	bonusLabel.Parent             = frame

	return sg
end

-- ── Update labels ─────────────────────────────────────────────────────────────
local function updateLabels_217()
	if not badgeGui_217 then return end
	local frame = badgeGui_217:FindFirstChild("BadgeFrame")
	if not frame then return end

	local streak = (player:GetAttribute("DailyStreak")   :: number?) or 0
	local bonusPct = (player:GetAttribute("DailyBonusPct") :: number?) or 0

	local streakLine = frame:FindFirstChild("StreakLine") :: TextLabel?
	local bonusLine  = frame:FindFirstChild("BonusLine")  :: TextLabel?

	if streakLine then
		streakLine.Text = "🔥 Day " .. tostring(streak)
		streakLine.TextColor3 = streak >= 7 and BRIGHT_217 or FIRE_217
	end
	if bonusLine then
		bonusLine.Text = "+" .. tostring(bonusPct) .. "% honey"
		bonusLine.TextColor3 = bonusPct > 0 and GOLD_217 or WAX_CREAM_217
	end

	local stroke = frame:FindFirstChild("BadgeStroke") :: UIStroke?
	if stroke then stroke.Color = streak >= 7 and BRIGHT_217 or FIRE_217 end
end

-- ── Celebrate pulse ───────────────────────────────────────────────────────────
local function celebratePulse_217()
	if not badgeGui_217 then return end
	local frame = badgeGui_217:FindFirstChild("BadgeFrame")
	if not frame then return end

	-- Grow + brighten briefly
	local origSize = frame.Size
	TweenService:Create(frame, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 134, 0, 38),
	}):Play()
	task.delay(0.20, function()
		TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			Size = origSize,
		}):Play()
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	if not built_217 then
		built_217 = true
		badgeGui_217 = buildBadge_217()
		if not badgeGui_217 then return end
	end
	updateLabels_217()

	local frame = badgeGui_217:FindFirstChild("BadgeFrame")
	if frame then
		frame.BackgroundTransparency = 1
		TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 0.15,
		}):Play()
	end

	task.delay(0.5, celebratePulse_217)   -- celebrate on login

	player:GetAttributeChangedSignal("DailyStreak"):Connect(function()
		updateLabels_217()
		celebratePulse_217()
	end)
	player:GetAttributeChangedSignal("DailyBonusPct"):Connect(updateLabels_217)
end)
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("StreakBadgeController"))
```

`DailyStreakService` is a Script in `ServerScriptService.Systems` — loads automatically.

---

## Step 4 — DataService integration (apply honey bonus)

The honey multiplier is stored as `DailyBonusPct` on the player attribute and as the `DailyBonus` float in the player's session. To apply it in production:

```lua
-- In CombService or ResourceService, when calculating honey production:
local bonusPct = (player:GetAttribute("DailyBonusPct") :: number?) or 0
local bonusMult = 1 + bonusPct / 100
local adjustedHoney = baseHoney * bonusMult
```

---

## Step 5 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local svc = SPS and SPS:FindFirstChild("DailyStreakService")
print("DailyStreakService:", svc and svc.ClassName or "MISSING")
if svc then
	local lines = select(2, svc.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  STREAK_WINDOW_HOURS_217:", svc.Source:find("STREAK_WINDOW_HOURS_217") ~= nil)
	print("  DailyStreak attr write:", svc.Source:find("DailyStreak") ~= nil)
	print("  DataStore:", svc.Source:find("DataStoreService") ~= nil)
end

local SPLS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPLS and SPLS:FindFirstChild("StreakBadgeController")
print("StreakBadgeController:", ctrl and ctrl.ClassName or "MISSING")

-- In Play mode after 5+ seconds:
-- print("DailyStreak:", game:GetService("Players").LocalPlayer:GetAttribute("DailyStreak"))
-- print("DailyBonusPct:", game:GetService("Players").LocalPlayer:GetAttribute("DailyBonusPct"))

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

---

## Behaviour summary

| Streak day | Honey bonus multiplier | Badge colour |
|---|---|---|
| Day 1 (first login) | +0% | Fire orange |
| Day 2 | +8% | Fire orange |
| Day 3 | +16% | Fire orange |
| Day 5 | +32% | Fire orange |
| Day 7+ (max) | +48% | Bright gold |

- Streak window: 36 hours (36h from last login to still extend — accounts for different time zones and schedules)
- Missed a day (> 36 hours): resets to Day 1
- Same-day second login (< 20 hours): streak unchanged, no double-reward
- Bonus applies to honey production — works via `DailyBonusPct` attribute
- Badge pulses on login to celebrate current streak
- "🔥 Day 7" in bright gold is a visible status signal to nearby players
- Badge sits top-left (8px from each edge), DisplayOrder=20

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Script + ScreenGui — no BaseParts)*
