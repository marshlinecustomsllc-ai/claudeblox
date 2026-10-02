# Dispatch 230 — Flower Patch Bloom State
**File:** `cycle24_flower_bloom_dispatch.md`
**Cycle:** 24
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The Wild Meadow has 18 flower patches that regenerate nectar over time, but currently all patches look the same whether they are rich with nectar or freshly depleted. This dispatch adds a **Flower Patch Bloom State Controller**: client-side logic that reads `PatchNectarLevel` (0–1) and `PatchRegenSecondsLeft` attributes on `FlowerPatch`-tagged Parts, applies a colour shift (full-bloom vivid → depleted grey-green), and shows a small BillboardGui "⏱ Ns" countdown label above depleted patches so players know when to return.

For kids: grey patches = empty, colourful patches = go collect there. The countdown makes returning feel rewarding. For adults: precise timing information for route planning.

---

## Step 1 — FlowerBloomController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `FlowerBloomController`.

Paste exactly:

```lua
--!strict
-- FlowerBloomController: visual bloom state on FlowerPatch-tagged parts.
-- Reads PatchNectarLevel (0–1) and PatchRegenSecondsLeft (number) attributes.
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local TWEEN_TIME_230    = 1.8    -- colour transition duration
local SCAN_INTERVAL_230 = 5.0   -- seconds between scan for new patches

-- Bloom colours (lerp from depleted to full)
local COLOR_DEPLETED_230 = Color3.fromRGB(100, 115,  70)   -- grey-green, wilted
local COLOR_FULL_230     = Color3.fromRGB(220, 180, 240)   -- lavender-pink, in bloom
local COLOR_PARTIAL_230  = Color3.fromRGB(180, 200, 120)   -- mid-green, recovering

-- GUI colours
local TIMER_BG_230    = Color3.fromRGB(28, 16, 6)
local TIMER_TEXT_230  = Color3.fromRGB(232, 212, 154)

-- ── Per-patch registry ────────────────────────────────────────────────────────
local patches_230: { [BasePart]: {
	gui: BillboardGui,
	timerLabel: TextLabel,
	lastLevel: number,
} } = {}

-- ── Build bloom GUI ───────────────────────────────────────────────────────────
local function buildGui_230(patch: BasePart): (BillboardGui, TextLabel)
	local existing = patch:FindFirstChild("BloomGui_230") :: BillboardGui?
	if existing then
		local lbl = existing:FindFirstChild("BloomFrame") and
			(existing:FindFirstChild("BloomFrame") :: Frame):FindFirstChild("TimerLabel") :: TextLabel?
		return existing, lbl or (existing:FindFirstChild("TimerLabel") :: TextLabel)
	end

	local bg = Instance.new("BillboardGui")
	bg.Name          = "BloomGui_230"
	bg.Size          = UDim2.new(0, 80, 0, 24)
	bg.StudsOffset   = Vector3.new(0, 3.5, 0)
	bg.AlwaysOnTop   = false
	bg.ResetOnSpawn  = false
	bg.Enabled       = false   -- hidden when patch is full
	bg.Parent        = patch

	local frame = Instance.new("Frame")
	frame.Name                   = "BloomFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = TIMER_BG_230
	frame.BackgroundTransparency = 0.20
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(90, 130, 60)
	stroke.Thickness = 1
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name                   = "TimerLabel"
	lbl.Size                   = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text                   = "⏱ —"
	lbl.TextSize               = 10
	lbl.Font                   = Enum.Font.Gotham
	lbl.TextColor3             = TIMER_TEXT_230
	lbl.TextXAlignment         = Enum.TextXAlignment.Center
	lbl.Parent                 = frame

	return bg, lbl
end

-- ── Update patch visuals ──────────────────────────────────────────────────────
local function updatePatch_230(patch: BasePart, entry: { gui: BillboardGui, timerLabel: TextLabel, lastLevel: number })
	local level   = math.clamp((patch:GetAttribute("PatchNectarLevel") :: number?) or 1, 0, 1)
	local secsLeft = (patch:GetAttribute("PatchRegenSecondsLeft") :: number?) or 0

	-- Colour: lerp depleted → full
	local targetColor: Color3
	if level < 0.1 then
		targetColor = COLOR_DEPLETED_230
	elseif level < 0.5 then
		targetColor = COLOR_DEPLETED_230:Lerp(COLOR_PARTIAL_230, (level - 0.1) / 0.4)
	else
		targetColor = COLOR_PARTIAL_230:Lerp(COLOR_FULL_230, (level - 0.5) / 0.5)
	end

	if math.abs(level - entry.lastLevel) > 0.05 then
		entry.lastLevel = level
		TweenService:Create(patch, TweenInfo.new(TWEEN_TIME_230, Enum.EasingStyle.Sine), {
			Color = targetColor,
		}):Play()
	end

	-- Timer GUI: show only when depleted
	local showTimer = level < 0.15 and secsLeft > 0
	entry.gui.Enabled = showTimer
	if showTimer then
		local secs = math.ceil(secsLeft)
		entry.timerLabel.Text = "⏱ " .. tostring(secs) .. "s"
	end
end

-- ── Register a patch ──────────────────────────────────────────────────────────
local function registerPatch_230(patch: BasePart)
	if patches_230[patch] then return end
	local gui, lbl = buildGui_230(patch)
	local entry = { gui = gui, timerLabel = lbl, lastLevel = -1 }
	patches_230[patch] = entry
	updatePatch_230(patch, entry)

	patch:GetAttributeChangedSignal("PatchNectarLevel"):Connect(function()
		updatePatch_230(patch, entry)
	end)
	patch:GetAttributeChangedSignal("PatchRegenSecondsLeft"):Connect(function()
		updatePatch_230(patch, entry)
	end)
end

-- ── Scan ─────────────────────────────────────────────────────────────────────
local scanAcc_230 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_230 += dt
	if scanAcc_230 < SCAN_INTERVAL_230 then return end
	scanAcc_230 = 0
	for _, patch in CollectionService:GetTagged("FlowerPatch") do
		if patch:IsA("BasePart") then registerPatch_230(patch) end
	end
	for patch in patches_230 do
		if not patch.Parent then patches_230[patch] = nil end
	end
end)

CollectionService:GetInstanceAddedSignal("FlowerPatch"):Connect(function(inst)
	if inst:IsA("BasePart") then task.delay(0.4, function() registerPatch_230(inst) end) end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	for _, patch in CollectionService:GetTagged("FlowerPatch") do
		if patch:IsA("BasePart") then registerPatch_230(patch) end
	end
end)
```

---

## Step 2 — PatchService attribute writes

Open **ServerScriptService → Systems → PatchService** (or ForagingService / wherever patch nectar is tracked).

Add attribute writes to each `FlowerPatch`-tagged Part:

```lua
-- When nectar level changes on a patch:
patchPart:SetAttribute("PatchNectarLevel", math.clamp(currentNectar / maxNectar, 0, 1))

-- When regeneration timer is running (update every ~5s or on change):
patchPart:SetAttribute("PatchRegenSecondsLeft", math.max(regenSecondsRemaining, 0))

-- When patch is fully regenerated:
patchPart:SetAttribute("PatchNectarLevel", 1)
patchPart:SetAttribute("PatchRegenSecondsLeft", 0)
```

If the regen timer is not currently tracked as a countdown (only as an accumulator), compute it:

```lua
-- regenSecondsLeft = REGEN_TIME - accumulatedRegenSeconds
local regenLeft = math.max(Config.PATCH_REGEN_TIME - patchData.regenAcc, 0)
patchPart:SetAttribute("PatchRegenSecondsLeft", regenLeft)
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("FlowerBloomController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (Edit mode):

```lua
local CS = game:GetService("CollectionService")
local patches = CS:GetTagged("FlowerPatch")
print("FlowerPatch tagged:", #patches, "(expect 18)")
for i, p in patches do
	if i > 4 then print("  ...") break end
	print(" ", p.Name, p:GetFullName())
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

**Quick-test (in Play mode):**

```lua
local CS = game:GetService("CollectionService")
local patches = CS:GetTagged("FlowerPatch")
if patches[1] then
	local p = patches[1] :: BasePart
	-- Simulate depleted
	p:SetAttribute("PatchNectarLevel", 0.05)
	p:SetAttribute("PatchRegenSecondsLeft", 45)
	task.wait(2)
	-- Patch should turn grey-green with ⏱ 45s timer visible

	-- Simulate recovering
	p:SetAttribute("PatchNectarLevel", 0.40)
	p:SetAttribute("PatchRegenSecondsLeft", 0)
	task.wait(2)
	-- Patch should shift to mid-green, timer hidden

	-- Simulate full bloom
	p:SetAttribute("PatchNectarLevel", 1.0)
	task.wait(2)
	-- Patch should be vivid lavender-pink
end
```

---

## Behaviour summary

| PatchNectarLevel | Colour | Timer GUI |
|---|---|---|
| 0.0–0.1 (depleted) | Grey-green (100,115,70) | Visible "⏱ Ns" |
| 0.1–0.5 (recovering) | Lerp grey-green → mid-green | Hidden |
| 0.5–1.0 (blooming) | Lerp mid-green → lavender-pink | Hidden |

- Colour tween uses TweenService Sine 1.8s — smooth, not jarring
- Timer label hidden when level ≥ 0.15 or SecondsLeft = 0
- Colour change threshold 0.05 prevents continuous tweening on tiny changes
- All 18 Wild Meadow patches registered on init; GetInstanceAdded catches late-loaded patches
- 5s scan prunes stale refs and registers any missed patches
- Together with PollenTrailController (D126) and ForagerTrailController (D225), the patch+forager system is now fully visually readable

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(BillboardGui inside each FlowerPatch Part — no new BaseParts)*
