# Dispatch 236 — Daily Quest HUD Badge
**File:** `cycle25_quest_hud_badge_dispatch.md`
**Cycle:** 25
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

QuestService (Dispatch 23 — Daily Quests) assigns a daily quest and tracks progress in player attributes (`QuestId`, `QuestProgress`, `QuestGoal`, `QuestComplete`). Currently there is no persistent HUD display of the active quest — players must open a separate UI to check progress. This dispatch adds a **Daily Quest HUD Badge**: a compact bottom-right widget showing the current quest name, a fill-bar progress indicator, and a ✓ complete state. It dismisses automatically on completion after 3 seconds and reappears at the start of the next session's quest.

For kids: "collect 5 honey" with a filling bar is instantly understandable — they know exactly what to do next. For adults: the badge provides at-a-glance mission tracking without opening any menus.

---

## Step 1 — QuestHudBadge (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `QuestHudBadge`.

Paste exactly:

```lua
--!strict
-- QuestHudBadge: compact HUD badge showing active daily quest + fill-bar progress.
-- Reads QuestId, QuestProgress, QuestGoal, QuestComplete player attributes.
-- Entirely client-side — zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local BADGE_W_236          = 240
local BADGE_H_236          = 56
local BADGE_PADDING_236    = 8    -- pixels from right and bottom edges

local COMPLETE_HOLD_236    = 3.0   -- seconds to show "✓ Complete" before hiding
local FADE_TIME_236        = 0.30

-- Quest ID → human-readable label (must match QuestService quest IDs)
local QUEST_LABELS_236: { [string]: string } = {
	collect_honey          = "🍯 Collect honey",
	build_cells            = "🔶 Build comb cells",
	harvest_honey          = "🪣 Harvest from hive",
	complete_dances        = "💃 Complete waggle dances",
	forage_flowers         = "🌸 Visit flower patches",
	repel_wasps            = "🐝 Repel wasp scouts",
	upgrade_queen          = "👑 Upgrade your queen",
	buy_consumable         = "🛒 Use the shop",
	earn_population        = "🐝 Grow bee population",
	place_structure        = "🏗 Place a structure",
}

-- Warm Wax palette
local BG_COLOR_236       = Color3.fromRGB(30,  18,   6)
local BORDER_COLOR_236   = Color3.fromRGB(120,  80,  30)
local TEXT_COLOR_236     = Color3.fromRGB(232, 212, 154)
local BAR_FILL_236       = Color3.fromRGB(242, 168,  28)
local BAR_EMPTY_236      = Color3.fromRGB(60,  36,  12)
local COMPLETE_COLOR_236 = Color3.fromRGB(120, 210,  80)

-- ── State ─────────────────────────────────────────────────────────────────────
local badgeFrame_236: Frame? = nil
local barFill_236: Frame?    = nil
local questLabel_236: TextLabel? = nil
local progLabel_236: TextLabel?  = nil
local completeDismissTask_236: thread? = nil

-- ── Build GUI ─────────────────────────────────────────────────────────────────
local function buildBadge_236()
	local pg = player:WaitForChild("PlayerGui")

	local sg = Instance.new("ScreenGui")
	sg.Name           = "QuestHudBadge_236"
	sg.DisplayOrder   = 18
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = false
	sg.Enabled        = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Name                   = "BadgeFrame"
	frame.Size                   = UDim2.new(0, BADGE_W_236, 0, BADGE_H_236)
	frame.AnchorPoint            = Vector2.new(1, 1)
	frame.Position               = UDim2.new(1, -BADGE_PADDING_236, 1, -BADGE_PADDING_236)
	frame.BackgroundColor3       = BG_COLOR_236
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg
	badgeFrame_236 = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = BORDER_COLOR_236
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	-- Quest name label
	local qlbl = Instance.new("TextLabel")
	qlbl.Name                   = "QuestLabel"
	qlbl.Size                   = UDim2.new(1, -10, 0, 22)
	qlbl.Position               = UDim2.new(0, 6, 0, 4)
	qlbl.BackgroundTransparency = 1
	qlbl.Text                   = "📋 Loading quest..."
	qlbl.TextSize               = 12
	qlbl.Font                   = Enum.Font.GothamBold
	qlbl.TextColor3             = TEXT_COLOR_236
	qlbl.TextXAlignment         = Enum.TextXAlignment.Left
	qlbl.TextTruncate           = Enum.TextTruncate.AtEnd
	qlbl.Parent                 = frame
	questLabel_236 = qlbl

	-- Progress text (right-aligned)
	local plbl = Instance.new("TextLabel")
	plbl.Name                   = "ProgLabel"
	plbl.Size                   = UDim2.new(1, -10, 0, 16)
	plbl.Position               = UDim2.new(0, 6, 0, 24)
	plbl.BackgroundTransparency = 1
	plbl.Text                   = "0 / 0"
	plbl.TextSize               = 10
	plbl.Font                   = Enum.Font.Gotham
	plbl.TextColor3             = TEXT_COLOR_236
	plbl.TextXAlignment         = Enum.TextXAlignment.Right
	plbl.Parent                 = frame
	progLabel_236 = plbl

	-- Progress bar background
	local barBg = Instance.new("Frame")
	barBg.Name                   = "BarBg"
	barBg.Size                   = UDim2.new(1, -10, 0, 7)
	barBg.Position               = UDim2.new(0, 5, 0, 43)
	barBg.BackgroundColor3       = BAR_EMPTY_236
	barBg.BackgroundTransparency = 0
	barBg.BorderSizePixel        = 0
	barBg.Parent                 = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent       = barBg

	-- Fill bar
	local fill = Instance.new("Frame")
	fill.Name                   = "BarFill"
	fill.Size                   = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3       = BAR_FILL_236
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel        = 0
	fill.Parent                 = barBg
	barFill_236 = fill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent       = fill
end

-- ── Update badge ─────────────────────────────────────────────────────────────
local function updateBadge_236()
	local questId  = (player:GetAttribute("QuestId")       :: string?) or ""
	local progress = (player:GetAttribute("QuestProgress") :: number?) or 0
	local goal     = (player:GetAttribute("QuestGoal")     :: number?) or 1
	local complete = (player:GetAttribute("QuestComplete") :: boolean?) == true

	if questId == "" then
		-- No quest active — hide badge
		if badgeFrame_236 then badgeFrame_236.Visible = false end
		return
	end

	if badgeFrame_236 then badgeFrame_236.Visible = true end

	local label = QUEST_LABELS_236[questId] or ("📋 " .. questId)
	local fill  = if goal > 0 then math.clamp(progress / goal, 0, 1) else 0

	if complete then
		-- Complete state
		if questLabel_236 then
			questLabel_236.Text   = "✓ Quest Complete!"
			questLabel_236.TextColor3 = COMPLETE_COLOR_236
		end
		if progLabel_236 then
			progLabel_236.Text = goal .. " / " .. goal
		end
		if barFill_236 then
			TweenService:Create(barFill_236, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = COMPLETE_COLOR_236,
			}):Play()
		end
		-- Auto-dismiss after hold time
		if completeDismissTask_236 then
			task.cancel(completeDismissTask_236)
		end
		completeDismissTask_236 = task.delay(COMPLETE_HOLD_236, function()
			if badgeFrame_236 then badgeFrame_236.Visible = false end
		end)
	else
		-- In-progress state
		if questLabel_236 then
			questLabel_236.Text       = label
			questLabel_236.TextColor3 = TEXT_COLOR_236
		end
		if progLabel_236 then
			progLabel_236.Text = tostring(math.floor(progress)) .. " / " .. tostring(math.floor(goal))
		end
		if barFill_236 then
			TweenService:Create(barFill_236, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
				Size = UDim2.new(fill, 0, 1, 0),
				BackgroundColor3 = BAR_FILL_236,
			}):Play()
		end
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	buildBadge_236()
	updateBadge_236()

	player:GetAttributeChangedSignal("QuestId"):Connect(updateBadge_236)
	player:GetAttributeChangedSignal("QuestProgress"):Connect(updateBadge_236)
	player:GetAttributeChangedSignal("QuestGoal"):Connect(updateBadge_236)
	player:GetAttributeChangedSignal("QuestComplete"):Connect(updateBadge_236)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("QuestHudBadge"))
```

---

## Step 3 — QuestService confirmation

The badge reads four player attributes: `QuestId` (string), `QuestProgress` (number), `QuestGoal` (number), `QuestComplete` (boolean). These are written by QuestService (Dispatch 23). No changes needed if QuestService already writes all four.

If QuestService only writes `QuestId` and `QuestProgress`, add:

```lua
-- In QuestService, alongside existing writes:
player:SetAttribute("QuestGoal", questDef.goal)        -- total needed
player:SetAttribute("QuestComplete", progress >= questDef.goal)
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("QuestHudBadge")
print("QuestHudBadge:", c and c.ClassName or "MISSING")

-- Simulate a quest in progress
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("QuestId", "collect_honey")
lp:SetAttribute("QuestGoal", 50)
lp:SetAttribute("QuestProgress", 0)
lp:SetAttribute("QuestComplete", false)
task.wait(1)
print("Badge should show: 🍯 Collect honey  0/50, empty bar")

lp:SetAttribute("QuestProgress", 30)
task.wait(0.5)
print("Badge should show: 0/50→30/50, bar 60% full")

lp:SetAttribute("QuestProgress", 50)
lp:SetAttribute("QuestComplete", true)
task.wait(0.5)
print("Badge should show: ✓ Quest Complete!, green full bar, then dismiss after 3s")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| Quest state | Badge display | Bar |
|---|---|---|
| No quest active | Hidden | — |
| In progress | Quest label + N/Goal text | Amber fill proportional to progress |
| Complete | ✓ Quest Complete! (green) | Full green bar → auto-hides after 3s |
| New quest begins | Label + bar reset | Empty → fills as progress increases |

- Bottom-right positioning (DisplayOrder=18) fits below Leaderboard board view and beside wallet HUD without overlapping
- Bar tween 0.4s Sine gives visible fill animation on each progress update
- `task.cancel(completeDismissTask_236)` prevents double-dismiss if complete fires twice
- 10 quest label definitions cover all QuestService quest types from D23
- Badge hidden when QuestId="" (server hasn't assigned quest yet, or between daily resets)

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(ScreenGui in PlayerGui — no BaseParts)*
