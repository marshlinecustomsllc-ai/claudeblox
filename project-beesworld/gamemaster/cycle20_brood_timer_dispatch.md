# Dispatch 206 — Brood Cell Incubation Timer
**File:** `cycle20_brood_timer_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

BroodCell parts currently give no feedback during incubation. A player who just placed a Brood cell has no idea when the next bee will hatch — they can only watch the population count tick up eventually. This dispatch adds a **Brood Cell Incubation Timer**: a small BillboardGui above each BroodCell-tagged BasePart that displays a countdown (e.g. "🐝 12s") until the next hatch, plus a progress bar that fills from empty to full. When the hatch fires the bar briefly flashes white before resetting. Entirely client-side — reads the `HatchIn` attribute (seconds remaining) that ResourceService writes each incubation tick.

For kids: a friendly "🐝 12s" shows the bee is almost ready. For adults: the precise countdown + per-cell progress bars let experienced players optimise comb layout timing.

---

## Step 1 — BroodTimerController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BroodTimerController`.

Paste exactly:

```lua
--!strict
-- BroodTimerController: countdown BillboardGui above BroodCell parts.
-- Reads HatchIn attribute (seconds remaining until next hatch) from BroodCell BaseParts.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local LABEL_OFFSET_206    = Vector3.new(0, 3.2, 0)   -- studs above BroodCell top
local SCAN_INTERVAL_206   = 5.0                       -- seconds between full re-scans
local FLASH_DURATION_206  = 0.5                       -- seconds for hatch flash

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_206    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_206  = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD_206 = Color3.fromRGB(242, 168,  28)
local AMBER_206      = Color3.fromRGB(220, 130,  20)
local BAR_FILL_206   = Color3.fromRGB(180, 240, 100)   -- green-gold progress bar
local FLASH_206      = Color3.fromRGB(255, 255, 220)   -- warm white hatch flash

-- ── Per-cell state ────────────────────────────────────────────────────────────
type CellEntry = {
	gui:       BillboardGui,
	label:     TextLabel,
	bar:       Frame,
	lastHatch: number,    -- last seen HatchIn value (to detect hatch events)
	flashConn: RBXScriptConnection?,
}

local cells_206: { [BasePart]: CellEntry } = {}

-- ── Build per-cell BillboardGui ───────────────────────────────────────────────
local function buildGui_206(part: BasePart): CellEntry
	local bg = Instance.new("BillboardGui")
	bg.Name           = "BroodTimer_206"
	bg.Size           = UDim2.new(0, 80, 0, 36)
	bg.StudsOffset    = LABEL_OFFSET_206
	bg.AlwaysOnTop    = false
	bg.ResetOnSpawn   = false
	bg.Parent         = part

	local frame = Instance.new("Frame")
	frame.Name                   = "TimerFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_206
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = AMBER_206
	stroke.Thickness = 1
	stroke.Parent    = frame

	-- Countdown label
	local label = Instance.new("TextLabel")
	label.Name               = "CountLabel"
	label.Size               = UDim2.new(1, 0, 0.58, 0)
	label.Position           = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text               = "🐝 --"
	label.TextSize           = 12
	label.Font               = Enum.Font.GothamBold
	label.TextColor3         = WAX_CREAM_206
	label.TextXAlignment     = Enum.TextXAlignment.Center
	label.ZIndex             = 2
	label.Parent             = frame

	-- Progress bar track
	local track = Instance.new("Frame")
	track.Name                   = "BarTrack"
	track.Size                   = UDim2.new(0.88, 0, 0.22, 0)
	track.Position               = UDim2.new(0.06, 0, 0.72, 0)
	track.BackgroundColor3       = Color3.fromRGB(20, 10, 4)
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel        = 0
	track.ZIndex                 = 2
	track.Parent                 = frame

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 3)
	trackCorner.Parent       = track

	-- Progress bar fill
	local bar = Instance.new("Frame")
	bar.Name                   = "BarFill"
	bar.Size                   = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3       = BAR_FILL_206
	bar.BackgroundTransparency = 0.1
	bar.BorderSizePixel        = 0
	bar.ZIndex                 = 3
	bar.Parent                 = track

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 3)
	barCorner.Parent       = bar

	return {
		gui       = bg,
		label     = label,
		bar       = bar,
		lastHatch = 0,
		flashConn = nil,
	}
end

-- ── Flash bar on hatch ────────────────────────────────────────────────────────
local function flashHatch_206(entry: CellEntry)
	if entry.flashConn then
		entry.flashConn:Disconnect()
		entry.flashConn = nil
	end
	entry.bar.BackgroundColor3 = FLASH_206
	entry.bar.Size = UDim2.new(1, 0, 1, 0)

	entry.flashConn = task.delay(FLASH_DURATION_206, function()
		if entry.bar and entry.bar.Parent then
			TweenService:Create(entry.bar, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {
				BackgroundColor3 = BAR_FILL_206,
			}):Play()
		end
		entry.flashConn = nil
	end)
end

-- ── Update a single cell's GUI ────────────────────────────────────────────────
local function updateCell_206(part: BasePart, entry: CellEntry)
	if not part.Parent then return end

	local hatchIn = (part:GetAttribute("HatchIn") :: number?) or 0
	local maxTime = (part:GetAttribute("HatchMax") :: number?) or 30   -- fallback 30s

	-- Detect hatch event: timer reset from near-zero back to ~maxTime
	if entry.lastHatch > 0 and entry.lastHatch < 3 and hatchIn > entry.lastHatch + 5 then
		flashHatch_206(entry)
	end
	entry.lastHatch = hatchIn

	-- Update countdown label
	local secs = math.max(0, math.round(hatchIn))
	entry.label.Text = "🐝 " .. secs .. "s"

	-- Colour: gold when almost done, cream otherwise
	local frac = if maxTime > 0 then math.clamp(1 - hatchIn / maxTime, 0, 1) else 0
	entry.label.TextColor3 = WAX_CREAM_206:Lerp(HONEY_GOLD_206, math.max(0, frac - 0.7) / 0.3)

	-- Progress bar width
	if not entry.bar.Parent then return end
	entry.bar.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
end

-- ── Register a new BroodCell part ────────────────────────────────────────────
local function registerCell_206(part: BasePart)
	if cells_206[part] then return end

	local entry = buildGui_206(part)
	cells_206[part] = entry

	-- Reactive: fire immediately on attribute change
	part:GetAttributeChangedSignal("HatchIn"):Connect(function()
		if part.Parent and cells_206[part] then
			updateCell_206(part, cells_206[part])
		end
	end)

	updateCell_206(part, entry)
end

-- ── Unregister a removed BroodCell part ──────────────────────────────────────
local function unregisterCell_206(part: BasePart)
	local entry = cells_206[part]
	if not entry then return end
	if entry.flashConn then
		if typeof(entry.flashConn) == "RBXScriptConnection" then
			entry.flashConn:Disconnect()
		else
			(entry.flashConn :: any):Cancel()
		end
		entry.flashConn = nil
	end
	if entry.gui and entry.gui.Parent then
		entry.gui:Destroy()
	end
	cells_206[part] = nil
end

-- ── Full scan ─────────────────────────────────────────────────────────────────
local function scan_206()
	-- Clean stale refs
	for part, _ in cells_206 do
		if not part.Parent then
			unregisterCell_206(part)
		end
	end
	-- Register any new ones
	for _, obj in CollectionService:GetTagged("BroodCell") do
		if obj:IsA("BasePart") then
			registerCell_206(obj)
		end
	end
end

-- ── Heartbeat: scan timer + per-cell update ────────────────────────────────────
local scanAcc_206 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_206 += dt
	if scanAcc_206 >= SCAN_INTERVAL_206 then
		scanAcc_206 = 0
		scan_206()
	end
end)

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("BroodCell"):Connect(function(obj)
	if obj:IsA("BasePart") then
		task.wait(0.3)
		registerCell_206(obj)
	end
end)

CollectionService:GetInstanceRemovedSignal("BroodCell"):Connect(function(obj)
	if obj:IsA("BasePart") then
		unregisterCell_206(obj)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	scan_206()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BroodTimerController"))
```

---

## Step 3 — Attribute source (ResourceService)

`BroodTimerController` reads two attributes from `BroodCell` BaseParts:

| Attribute | Type | Set by | When |
|---|---|---|---|
| `HatchIn` | number | ResourceService | Updated each incubation tick; seconds remaining until next hatch |
| `HatchMax` | number | ResourceService | Written once when a hatch cycle starts; total seconds for a full cycle |

Add to ResourceService's incubation tick (after computing `timeUntilHatch`):

```lua
-- In ResourceService, inside the brood incubation loop:
local broodPart = -- (the BroodCell BasePart for this cell)
if broodPart then
    broodPart:SetAttribute("HatchIn",  math.max(0, timeUntilHatch))
    broodPart:SetAttribute("HatchMax", Config.HATCH_INTERVAL)  -- total cycle length
end
```

`HatchIn` counts down each tick; at hatch it resets to `HatchMax` for the next cycle. The controller detects the reset (old value near zero, new value large) and fires the flash animation.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BroodTimerController")
print("BroodTimerController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildGui_206:", c.Source:find("buildGui_206") ~= nil)
	print("  updateCell_206:", c.Source:find("updateCell_206") ~= nil)
	print("  flashHatch_206:", c.Source:find("flashHatch_206") ~= nil)
	print("  HatchIn attr:", c.Source:find("HatchIn") ~= nil)
	print("  BroodCell tag:", c.Source:find("BroodCell") ~= nil)
end

local CS = game:GetService("CollectionService")
local brood = CS:GetTagged("BroodCell")
print("BroodCell tagged parts:", #brood, "(0 in Edit mode — placed during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Find a BroodCell and simulate a countdown
local CS = game:GetService("CollectionService")
local cells = CS:GetTagged("BroodCell")
if cells[1] then
	cells[1]:SetAttribute("HatchMax", 30)
	-- Simulate mid-cycle (15s remaining → bar should be 50%)
	cells[1]:SetAttribute("HatchIn", 15)
	task.wait(1)
	-- Simulate almost done (2s remaining → bar ~93%, label gold)
	cells[1]:SetAttribute("HatchIn", 2)
	task.wait(1)
	-- Simulate hatch reset (back to full cycle)
	cells[1]:SetAttribute("HatchIn", 30)
	print("Flash should have triggered on BroodCell:", cells[1]:GetFullName())
end
```

**Expected output:**
```
BroodTimerController: LocalScript
  lines: 160+
  buildGui_206: true
  updateCell_206: true
  flashHatch_206: true
  HatchIn attr: true
  BroodCell tag: true
BroodCell tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| HatchIn / HatchMax | Label | Bar | Notes |
|---|---|---|---|
| 30 / 30 (fresh cycle start) | 🐝 30s | Empty | New cycle just began |
| 15 / 30 (mid cycle) | 🐝 15s | 50% filled | Steady countdown |
| 3 / 30 (almost done) | 🐝 3s (gold text) | 90% filled | Text turns honey-gold |
| 0 / 30 → reset to 30 | Flash white | Full → resets | Hatch fire detected |

- BillboardGui sits 3.2 studs above the BroodCell — visible across the plot without blocking the comb grid view
- Progress bar fills left-to-right (empty = just started, full = about to hatch)
- Text colour shifts from WAX_CREAM to HONEY_GOLD in the final 30% of the cycle — a warmth signal the bee is ready
- Flash: bar turns warm-white for 0.5s then tweens back to green-gold — a tactile "pop" when a hatch fires
- `HatchIn` is written by ResourceService each tick so the countdown is live, not estimated client-side
- Works for any number of BroodCells simultaneously — each gets its own BillboardGui

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BroodTimer_206 BillboardGui is a client-only GuiObject parented to BroodCell — not a BasePart)*
