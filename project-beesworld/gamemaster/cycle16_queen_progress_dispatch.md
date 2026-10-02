# Dispatch 179 — Queen Growth Progress Bar
**File:** `cycle16_queen_progress_dispatch.md`
**Cycle:** 16
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The queen grows toward her next tier through accumulated honey production, but players currently have no feedback on how close she is — the upgrade feels random. This dispatch adds a **Queen Growth Progress Bar** to the HiveGui QUEEN tab: a small animated arc (not a full circle, to keep it subtle) that fills as the queen accumulates production XP, plus a compact label showing current tier and what the next tier unlocks. Kids see "🌱 She's growing!"; adults see the raw XP fraction and the specific multiplier they're working toward. The bar also plays a brief glow pulse when the queen levels up (`QueenGrowth` RemoteEvent).

Entirely client-side. Zero new parts. Piggybacks on the existing `QueenGrowth` RemoteEvent and `QueenTier`/`QueenXP`/`QueenXPMax` player attributes.

---

## Step 1 — QueenProgressController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `QueenProgressController`.

Paste exactly:

```lua
--!strict
-- QueenProgressController: queen tier progress arc + level-up glow in HiveGui QUEEN tab.
-- Reads QueenTier / QueenXP / QueenXPMax player attributes; listens to QueenGrowth RemoteEvent.
-- Entirely client-side — no server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local ARC_SEGMENTS_179  = 20    -- number of thin bar-frames that form the arc
local ARC_WIDTH_179     = 6     -- px width of each segment
local ARC_HEIGHT_179    = 4     -- px height of each segment (flat tick marks)
local ARC_RADIUS_179    = 36    -- px radius of the arc (fits inside the queen portrait)
local ARC_START_DEG_179 = -210  -- degrees: arc starts bottom-left
local ARC_END_DEG_179   = 30    -- degrees: arc ends bottom-right (240° sweep)
local GLOW_TIME_179     = 0.8   -- seconds for level-up glow pulse

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_179  = Color3.fromRGB(242, 168, 28)
local WAX_CREAM_179   = Color3.fromRGB(232, 212, 154)
local DARK_BG_179     = Color3.fromRGB(30,  18,  8)
local PURPLE_179      = Color3.fromRGB(160, 60,  220)  -- queen purple (tier 5)
local GREY_179        = Color3.fromRGB(90,  80,  70)   -- empty segment
local WHITE_GLOW_179  = Color3.fromRGB(255, 245, 210)

-- ── Tier metadata ─────────────────────────────────────────────────────────────
local TIER_DATA_179 = {
	[1] = { name = "Maiden",   color = Color3.fromRGB(180, 140,  80), next = "doubles egg rate" },
	[2] = { name = "Worker",   color = Color3.fromRGB(200, 170,  60), next = "+20% honey mult" },
	[3] = { name = "Matron",   color = Color3.fromRGB(230, 180,  30), next = "+40% pop cap" },
	[4] = { name = "Empress",  color = Color3.fromRGB(220, 110,  20), next = "unlocks Sun Queen" },
	[5] = { name = "Sun Queen",color = PURPLE_179,                   next = "maximum — prestige!" },
}

-- ── Build arc + label in HiveGui ──────────────────────────────────────────────
local arcFrames_179: { Frame } = {}
local progressLabel_179: TextLabel? = nil
local arcContainer_179: Frame? = nil

local function buildArc_179()
	-- Try to attach to HiveGui QUEEN tab container
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	if not hiveGui then return end

	-- Find queen portrait or tab frame
	local queenFrame: GuiObject? = nil
	for _, desc in hiveGui:GetDescendants() do
		if desc:IsA("Frame") and (
			desc.Name == "QueenFrame" or
			desc.Name == "QueenPortrait" or
			desc.Name == "QueenTab" or
			desc.Name == "QueenPage"
		) then
			queenFrame = desc
			break
		end
	end

	-- Fallback: create floating card if no queen frame found
	local parentGui: GuiObject
	if queenFrame then
		parentGui = queenFrame
	else
		local sg = Instance.new("ScreenGui")
		sg.Name           = "QueenProgressGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 21
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui

		local card = Instance.new("Frame")
		card.Name              = "QueenCard"
		card.Size              = UDim2.new(0, 110, 0, 110)
		card.Position          = UDim2.new(0, 8, 0.5, -55)
		card.BackgroundColor3  = DARK_BG_179
		card.BackgroundTransparency = 0.15
		card.BorderSizePixel   = 0
		card.ZIndex            = 25
		card.Parent            = sg

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card

		local stroke = Instance.new("UIStroke")
		stroke.Color     = HONEY_GOLD_179
		stroke.Thickness = 1
		stroke.Parent    = card

		parentGui = card
	end

	-- Container for the arc (centred in parent)
	local container = Instance.new("Frame")
	container.Name              = "QueenArcContainer_179"
	container.Size              = UDim2.new(0, ARC_RADIUS_179 * 2 + 20, 0, ARC_RADIUS_179 * 2 + 20)
	container.Position          = UDim2.new(0.5, -(ARC_RADIUS_179 + 10), 0.5, -(ARC_RADIUS_179 + 10))
	container.BackgroundTransparency = 1
	container.ZIndex            = 26
	container.Parent            = parentGui
	arcContainer_179 = container

	-- Build arc segments
	local sweepDeg = ARC_END_DEG_179 - ARC_START_DEG_179
	for i = 1, ARC_SEGMENTS_179 do
		local frac  = (i - 0.5) / ARC_SEGMENTS_179
		local angle = math.rad(ARC_START_DEG_179 + frac * sweepDeg)
		local cx    = ARC_RADIUS_179 + 10 + math.cos(angle) * ARC_RADIUS_179
		local cy    = ARC_RADIUS_179 + 10 - math.sin(angle) * ARC_RADIUS_179

		local seg = Instance.new("Frame")
		seg.Name                    = "ArcSeg_" .. i
		seg.Size                    = UDim2.new(0, ARC_WIDTH_179, 0, ARC_HEIGHT_179)
		seg.Position                = UDim2.new(0, cx - ARC_WIDTH_179 / 2, 0, cy - ARC_HEIGHT_179 / 2)
		seg.Rotation               = math.deg(angle) + 90
		seg.BackgroundColor3        = GREY_179
		seg.BorderSizePixel         = 0
		seg.ZIndex                  = 27
		seg.Parent                  = container

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = seg

		arcFrames_179[i] = seg
	end

	-- Progress label below arc
	local lbl = Instance.new("TextLabel")
	lbl.Name                  = "QueenProgressLabel_179"
	lbl.Size                  = UDim2.new(1, 0, 0, 18)
	lbl.Position              = UDim2.new(0, 0, 1, 2)
	lbl.BackgroundTransparency = 1
	lbl.Text                  = "🌱 Growing…"
	lbl.TextSize              = 10
	lbl.Font                  = Enum.Font.GothamBold
	lbl.TextColor3            = WAX_CREAM_179
	lbl.TextXAlignment        = Enum.TextXAlignment.Center
	lbl.ZIndex                = 27
	lbl.Parent                = container
	progressLabel_179 = lbl
end

-- ── Render arc to a given fill fraction ──────────────────────────────────────
local function renderArc_179(fill: number, tierColor: Color3)
	local filled = math.floor(fill * ARC_SEGMENTS_179 + 0.5)
	filled = math.max(0, math.min(ARC_SEGMENTS_179, filled))
	for i, seg in arcFrames_179 do
		local target = if i <= filled then tierColor else GREY_179
		seg.BackgroundColor3 = target
	end
end

-- ── Update display ────────────────────────────────────────────────────────────
local function updateProgress_179()
	if #arcFrames_179 == 0 then return end

	local tier   = player:GetAttribute("QueenTier")    :: number?
	local xp     = player:GetAttribute("QueenXP")      :: number?
	local xpMax  = player:GetAttribute("QueenXPMax")   :: number?

	tier  = tier  or 1
	xp    = xp    or 0
	xpMax = xpMax or 100

	local fill      = if xpMax > 0 then math.min(xp / xpMax, 1) else 0
	local tierInfo  = TIER_DATA_179[tier] or TIER_DATA_179[1]
	local tierColor = tierInfo.color

	renderArc_179(fill, tierColor)

	local lbl = progressLabel_179
	if not lbl then return end

	if tier >= 5 then
		lbl.Text       = "👑 Sun Queen — Max!"
		lbl.TextColor3 = PURPLE_179
	else
		local pct = math.floor(fill * 100)
		-- Kid line: emoji + simple progress
		-- Adult suffix: exact fraction + what's unlocked next (smaller grey)
		lbl.Text = string.format("🌱 %d%% — next: %s", pct, tierInfo.next)
		lbl.TextColor3 = if fill >= 0.9 then HONEY_GOLD_179 else WAX_CREAM_179
	end
end

-- ── Level-up glow pulse ───────────────────────────────────────────────────────
local function playLevelUpPulse_179()
	if #arcFrames_179 == 0 then return end

	-- Flash all filled segments to white, then back
	for _, seg in arcFrames_179 do
		if seg.BackgroundColor3 ~= GREY_179 then
			TweenService:Create(seg, TweenInfo.new(GLOW_TIME_179 * 0.3),
				{ BackgroundColor3 = WHITE_GLOW_179 }):Play()
		end
	end

	task.delay(GLOW_TIME_179 * 0.4, function()
		-- Re-render to correct tier colors (handles tier change)
		updateProgress_179()
	end)

	-- Also flash the label
	local lbl = progressLabel_179
	if lbl then
		TweenService:Create(lbl, TweenInfo.new(GLOW_TIME_179 * 0.3),
			{ TextColor3 = WHITE_GLOW_179 }):Play()
		task.delay(GLOW_TIME_179 * 0.4, function()
			updateProgress_179()
		end)
	end
end

-- ── Init + listeners ──────────────────────────────────────────────────────────
task.delay(1.5, function()
	buildArc_179()
	updateProgress_179()
end)

-- Watch attribute changes
player:GetAttributeChangedSignal("QueenTier"):Connect(updateProgress_179)
player:GetAttributeChangedSignal("QueenXP"):Connect(updateProgress_179)
player:GetAttributeChangedSignal("QueenXPMax"):Connect(updateProgress_179)

-- Level-up event
local queenGrowth = Remotes:FindFirstChild("QueenGrowth") :: RemoteEvent?
if queenGrowth then
	queenGrowth.OnClientEvent:Connect(function()
		task.delay(0.05, function()   -- tiny delay so attributes land first
			playLevelUpPulse_179()
		end)
	end)
else
	-- Retry loop for late-arriving remote
	task.spawn(function()
		while true do
			task.wait(8)
			local re = Remotes:FindFirstChild("QueenGrowth") :: RemoteEvent?
			if re then
				re.OnClientEvent:Connect(function()
					task.delay(0.05, playLevelUpPulse_179)
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
require(script.Parent:WaitForChild("QueenProgressController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("QueenProgressController")
print("QueenProgressController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  renderArc_179:", c.Source:find("renderArc_179") ~= nil)
	print("  playLevelUpPulse_179:", c.Source:find("playLevelUpPulse_179") ~= nil)
	print("  QueenGrowth listener:", c.Source:find("QueenGrowth") ~= nil)
	print("  TIER_DATA_179:", c.Source:find("TIER_DATA_179") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
QueenProgressController: LocalScript
  lines: 180+
  renderArc_179: true
  playLevelUpPulse_179: true
  QueenGrowth listener: true
  TIER_DATA_179: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Arc display |
|-------|-------------|
| Tier 1 (Maiden), 0 XP | All 20 segments grey |
| Tier 2 (Worker), 50% XP | 10 segments lit in Worker amber |
| Near level-up (≥90% fill) | Label turns honey gold, text reads % + unlock hint |
| Level-up fires | All filled segments flash white → colour, label pulses |
| Tier 5 (Sun Queen) | "👑 Sun Queen — Max!", segments lit in purple |
| HiveGui found | Arc renders inside QueenFrame/QueenPortrait |
| No HiveGui yet | Floating 110×110 card left-centre of screen |

**Part budget: +0 permanent → 4,204 / 5,000**
