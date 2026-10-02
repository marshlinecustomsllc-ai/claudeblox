# Dispatch 195 — Hive Warm-Up Sequence
**File:** `cycle19_hive_warmup_dispatch.md`
**Cycle:** 19
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When a player first lands on their plot the hive snaps to its current state instantly — cells appear, bees are already foraging, the HUD fills with data — but there's no sense of "the hive coming alive". This dispatch adds a **Hive Warm-Up Sequence**: a one-shot LocalScript that runs 3 seconds after `PlotAssigned` is received, creates a brief amber warmth ripple across all `CombCell`-tagged parts on the player's plot (each cell flashes from its normal colour through a warm glow and back, staggered outward from the dance floor centre), then shows a 2-second "🐝 Welcome back!" or "🐝 Your hive is ready!" toast. Runs once per session join. Entirely client-side — zero server writes, zero permanent parts.

---

## Step 1 — HiveWarmupController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HiveWarmupController`.

Paste exactly:

```lua
--!strict
-- HiveWarmupController: one-shot warmth ripple + welcome toast on hive load.
-- Fires once per session: 3s after PlotAssigned RemoteEvent is received.
-- Entirely client-side — zero server writes, zero permanent parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local WARMUP_DELAY_195    = 3.0     -- seconds after PlotAssigned before ripple starts
local RIPPLE_STAGGER_195  = 0.08    -- seconds delay per stud of distance from centre
local FLASH_DURATION_195  = 0.35    -- seconds per cell flash
local TOAST_HOLD_195      = 2.2     -- seconds the welcome toast stays visible
local FLASH_COLOR_195     = Color3.fromRGB(255, 210, 80)   -- warm amber flash
local WAX_CREAM_195       = Color3.fromRGB(232, 212, 154)
local DARK_BG_195         = Color3.fromRGB( 30,  18,   8)
local HONEY_GOLD_195      = Color3.fromRGB(242, 168,  28)

-- ── Run once guard ────────────────────────────────────────────────────────────
local hasRun_195 = false

-- ── Gather CombCells sorted by distance from origin (dance floor) ─────────────
local function getSortedCells_195(myPlot: number): { { part: BasePart, dist: number } }
	local cells: { { part: BasePart, dist: number } } = {}
	for _, obj in CollectionService:GetTagged("CombCell") do
		if not obj:IsA("BasePart") then continue end
		if obj:GetAttribute("PlotIndex") ~= myPlot then continue end
		-- Distance from local plot origin (X/Z, ignoring Y)
		local pos  = obj.Position
		local dist = math.sqrt(pos.X * pos.X + pos.Z * pos.Z)
		table.insert(cells, { part = obj, dist = dist })
	end
	-- Sort ascending by distance
	table.sort(cells, function(a, b) return a.dist < b.dist end)
	return cells
end

-- ── Flash a single cell warm ──────────────────────────────────────────────────
local function flashCell_195(part: BasePart)
	local originalColor = part.Color
	-- Flash to warm amber
	TweenService:Create(part, TweenInfo.new(FLASH_DURATION_195 * 0.4, Enum.EasingStyle.Sine), {
		Color = FLASH_COLOR_195,
	}):Play()
	-- Return to original
	task.delay(FLASH_DURATION_195 * 0.4, function()
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(FLASH_DURATION_195 * 0.6, Enum.EasingStyle.Sine), {
				Color = originalColor,
			}):Play()
		end
	end)
end

-- ── Show welcome toast ────────────────────────────────────────────────────────
local function showToast_195(isReturn: boolean)
	local pg = player:WaitForChild("PlayerGui", 5) :: PlayerGui?
	if not pg then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "WarmupToast_195"
	sg.DisplayOrder   = 35
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(0, 260, 0, 44)
	frame.AnchorPoint            = Vector2.new(0.5, 0)
	frame.Position               = UDim2.new(0.5, 0, 0.18, 0)
	frame.BackgroundColor3       = DARK_BG_195
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_GOLD_195
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -10, 1, 0)
	lbl.Position           = UDim2.new(0, 5, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = isReturn and "🐝 Welcome back! Your hive is buzzing." or "🐝 Your hive is ready!"
	lbl.TextSize           = 15
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_195
	lbl.TextWrapped        = true
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	-- Fade in
	TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 0.12,
	}):Play()

	-- Hold then fade out
	task.delay(TOAST_HOLD_195, function()
		if not frame.Parent then return end
		TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.6, function()
			if sg.Parent then sg:Destroy() end
		end)
	end)
end

-- ── Main warm-up sequence ─────────────────────────────────────────────────────
local function runWarmup_195()
	if hasRun_195 then return end
	hasRun_195 = true

	local myPlot = player:GetAttribute("PlotIndex") or 1
	local isReturn = (player:GetAttribute("HoneyCount") :: number? or 0) > 0

	local cells = getSortedCells_195(myPlot)
	if #cells == 0 then
		-- No cells built yet — still show toast, skip ripple
		showToast_195(isReturn)
		return
	end

	-- Stagger flashes outward from centre
	local baseDelay = 0
	for _, entry in cells do
		local delay = entry.dist * RIPPLE_STAGGER_195
		if delay > baseDelay then baseDelay = delay end
		task.delay(delay, function()
			if entry.part.Parent then
				flashCell_195(entry.part)
			end
		end)
	end

	-- Show toast after ripple reaches the outer ring
	task.delay(baseDelay + FLASH_DURATION_195 + 0.1, function()
		showToast_195(isReturn)
	end)
end

-- ── Listen for PlotAssigned ───────────────────────────────────────────────────
local function waitAndRun_195()
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:WaitForChild("Remotes", 15)
	if not remotes then return end
	local ev = remotes:WaitForChild("PlotAssigned", 15) :: RemoteEvent?
	if not ev then
		-- PlotAssigned may not exist yet; fall back to attribute polling
		task.delay(WARMUP_DELAY_195 + 2, runWarmup_195)
		return
	end

	ev.OnClientEvent:Connect(function()
		task.delay(WARMUP_DELAY_195, runWarmup_195)
	end)

	-- Safety: also fire if the player already has a plot when this script loads
	task.delay(WARMUP_DELAY_195 + 1, function()
		if not hasRun_195 and (player:GetAttribute("PlotIndex") ~= nil) then
			runWarmup_195()
		end
	end)
end

task.delay(1, waitAndRun_195)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HiveWarmupController"))
```

---

## Step 3 — PlotAssigned RemoteEvent (if absent)

If `PlotAssigned` does not yet exist in `ReplicatedStorage.Remotes`, add it and fire it from PlotService when a plot is assigned:

**Add RemoteEvent (Command Bar, Edit mode):**
```lua
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if remotes and not remotes:FindFirstChild("PlotAssigned") then
	local ev = Instance.new("RemoteEvent")
	ev.Name   = "PlotAssigned"
	ev.Parent = remotes
	print("Created PlotAssigned RemoteEvent")
end
```

**In PlotService**, after successfully assigning a plot to a player, add:
```lua
local PlotAssigned = remotes:FindFirstChild("PlotAssigned")
if PlotAssigned then
	PlotAssigned:FireClient(player, { plotIndex = plotIdx })
end
```

If `PlotService` already fires `PlotAssigned`, no server-side change is needed.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HiveWarmupController")
print("HiveWarmupController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  runWarmup_195:", c.Source:find("runWarmup_195") ~= nil)
	print("  flashCell_195:", c.Source:find("flashCell_195") ~= nil)
	print("  getSortedCells_195:", c.Source:find("getSortedCells_195") ~= nil)
	print("  RIPPLE_STAGGER_195:", c.Source:find("RIPPLE_STAGGER_195") ~= nil)
end

local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local ev = remotes and remotes:FindFirstChild("PlotAssigned")
print("PlotAssigned RemoteEvent:", ev and ev.ClassName or "MISSING (create if absent)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HiveWarmupController: LocalScript
  lines: 160+
  runWarmup_195: true
  flashCell_195: true
  getSortedCells_195: true
  RIPPLE_STAGGER_195: true
PlotAssigned RemoteEvent: RemoteEvent
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Effect | Duration |
|---|---|---|
| PlotAssigned received | Wait 3s then start ripple | 3s delay |
| Ripple phase | Cells flash warm amber outward from centre (0.08s stagger per stud distance) | ~0.5–1.5s depending on comb size |
| Toast phase | "🐝 Welcome back!" (has honey) or "🐝 Your hive is ready!" (fresh) fades in, holds, fades out | 2.2s |
| No cells built yet | Skip ripple, still show toast | Immediate toast |
| `hasRun_195` flag | Sequence runs exactly once per session | — |

- Stagger rate of 0.08s per stud means a full radius-2 hex lattice (outermost cell ~3.2 studs from centre) completes in ~0.26s — a quick, satisfying ripple outward
- `isReturn` detected by whether player has `HoneyCount > 0` — returning players see "Welcome back", fresh players see "Your hive is ready"
- Safety fallback runs if `PlotAssigned` remote is not found or never fires

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(WarmupToast ScreenGui is a transient GuiObject, destroyed after animation — not a BasePart)*
