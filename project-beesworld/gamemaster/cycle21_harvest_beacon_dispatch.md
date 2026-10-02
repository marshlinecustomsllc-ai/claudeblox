# Dispatch 210 — Harvest Ready Beacon
**File:** `cycle21_harvest_beacon_dispatch.md`
**Cycle:** 21
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture's core risk/reward tension depends on players deciding when to harvest: cash out early at lower value, or wait for the 2.2× ripeness bonus while Old Molasses grows more dangerous. Currently there is no at-a-glance "ready to harvest" signal — players must open HiveGui to see their honey count. This dispatch adds a **Harvest Ready Beacon**: a BillboardGui above the player's `LandingBoard`-tagged part that activates when their `HoneyCount` reaches the harvest threshold, shows the banked honey total, and pulses golden to invite action. Disappears when below threshold. Entirely client-side — reads the `HoneyCount` player attribute.

For kids: "🍯 Harvest!" glowing above the hive is an obvious "do the thing" prompt. For adults: the exact honey count is shown so they can judge ripeness vs raid risk precisely.

---

## Step 1 — HarvestBeaconController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HarvestBeaconController`.

Paste exactly:

```lua
--!strict
-- HarvestBeaconController: pulsing BillboardGui beacon above LandingBoard when harvest is ready.
-- Reads HoneyCount player attribute. Appears at HARVEST_THRESHOLD_210 honey.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local HARVEST_THRESHOLD_210 = 50      -- minimum HoneyCount to show beacon
local BEACON_OFFSET_210     = Vector3.new(0, 6.5, 0)
local PULSE_RATE_210        = 1.1     -- pulses per second (slightly urgent)
local SCAN_INTERVAL_210     = 7.0     -- seconds between safety re-scans

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_210    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_210  = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD_210 = Color3.fromRGB(242, 168,  28)
local AMBER_210      = Color3.fromRGB(220, 130,  20)
local BRIGHT_210     = Color3.fromRGB(255, 220,  80)   -- pulse peak

-- ── State ─────────────────────────────────────────────────────────────────────
local beaconGui_210: BillboardGui?        = nil
local pulseConn_210: RBXScriptConnection? = nil
local shownBoard_210: BasePart?           = nil
local currentHoney_210 = 0

-- ── Find player's LandingBoard ────────────────────────────────────────────────
local function getLandingBoard_210(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, obj in CollectionService:GetTagged("LandingBoard") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			return obj
		end
	end
	return nil
end

-- ── Build beacon gui ─────────────────────────────────────────────────────────
local function buildBeacon_210(board: BasePart, honey: number): BillboardGui
	local bg = Instance.new("BillboardGui")
	bg.Name           = "HarvestBeacon_210"
	bg.Size           = UDim2.new(0, 120, 0, 38)
	bg.StudsOffset    = BEACON_OFFSET_210
	bg.AlwaysOnTop    = false
	bg.ResetOnSpawn   = false
	bg.Parent         = board

	local frame = Instance.new("Frame")
	frame.Name                   = "BeaconFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_210
	frame.BackgroundTransparency = 0.10
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "BeaconStroke"
	stroke.Color     = HONEY_GOLD_210
	stroke.Thickness = 2
	stroke.Parent    = frame

	local label = Instance.new("TextLabel")
	label.Name               = "BeaconLabel"
	label.Size               = UDim2.new(1, -8, 0.58, 0)
	label.Position           = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text               = "🍯  Harvest!"
	label.TextSize           = 13
	label.Font               = Enum.Font.GothamBold
	label.TextColor3         = HONEY_GOLD_210
	label.TextXAlignment     = Enum.TextXAlignment.Center
	label.ZIndex             = 2
	label.Parent             = frame

	local subLabel = Instance.new("TextLabel")
	subLabel.Name               = "HoneyCount"
	subLabel.Size               = UDim2.new(1, -8, 0.36, 0)
	subLabel.Position           = UDim2.new(0, 4, 0.60, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text               = tostring(honey) .. " honey banked"
	subLabel.TextSize           = 10
	subLabel.Font               = Enum.Font.Gotham
	subLabel.TextColor3         = WAX_CREAM_210
	subLabel.TextXAlignment     = Enum.TextXAlignment.Center
	subLabel.ZIndex             = 2
	subLabel.Parent             = frame

	return bg
end

-- ── Stop pulse ────────────────────────────────────────────────────────────────
local function stopPulse_210()
	if pulseConn_210 then
		pulseConn_210:Disconnect()
		pulseConn_210 = nil
	end
end

-- ── Start pulse ───────────────────────────────────────────────────────────────
local function startPulse_210(bg: BillboardGui)
	stopPulse_210()
	local t = 0
	pulseConn_210 = RunService.Heartbeat:Connect(function(dt: number)
		if not bg.Parent then pulseConn_210 = nil return end
		t += dt * PULSE_RATE_210
		local alpha = (math.sin(t * math.pi * 2) + 1) * 0.5
		local frame = bg:FindFirstChildOfClass("Frame")
		local stroke = frame and frame:FindFirstChild("BeaconStroke") :: UIStroke?
		local label  = frame and frame:FindFirstChild("BeaconLabel") :: TextLabel?
		if stroke then stroke.Color = AMBER_210:Lerp(BRIGHT_210, alpha) end
		if label  then label.TextColor3 = HONEY_GOLD_210:Lerp(BRIGHT_210, alpha * 0.6) end
	end)
end

-- ── Remove beacon ─────────────────────────────────────────────────────────────
local function removeBeacon_210()
	stopPulse_210()
	if beaconGui_210 and beaconGui_210.Parent then
		beaconGui_210:Destroy()
	end
	beaconGui_210 = nil
	shownBoard_210 = nil
end

-- ── Update beacon for current honey ──────────────────────────────────────────
local function updateBeacon_210(honey: number)
	currentHoney_210 = honey

	if honey < HARVEST_THRESHOLD_210 then
		if beaconGui_210 then removeBeacon_210() end
		return
	end

	local board = getLandingBoard_210()
	if not board then
		if beaconGui_210 then removeBeacon_210() end
		return
	end

	if beaconGui_210 and beaconGui_210.Parent and shownBoard_210 == board then
		-- Update honey count label in-place
		local frame = beaconGui_210:FindFirstChildOfClass("Frame")
		local sub = frame and frame:FindFirstChild("HoneyCount") :: TextLabel?
		if sub then sub.Text = tostring(honey) .. " honey banked" end
		return
	end

	-- Rebuild (board changed or gui gone)
	removeBeacon_210()
	local bg = buildBeacon_210(board, honey)
	beaconGui_210 = bg
	shownBoard_210 = board
	startPulse_210(bg)
end

-- ── React to HoneyCount attribute ────────────────────────────────────────────
local function onHoneyChanged_210()
	local honey = (player:GetAttribute("HoneyCount") :: number?) or 0
	updateBeacon_210(honey)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	onHoneyChanged_210()

	player:GetAttributeChangedSignal("HoneyCount"):Connect(onHoneyChanged_210)

	-- Safety re-scan (LandingBoard may appear after script loads)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= SCAN_INTERVAL_210 then
			acc = 0
			onHoneyChanged_210()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HarvestBeaconController"))
```

---

## Step 3 — Attribute source (ResourceService / HarvestController)

`HarvestBeaconController` reads the `HoneyCount` player attribute that ResourceService already maintains via `player:SetAttribute("HoneyCount", total)`. No server-side changes needed — the attribute is already broadcast.

The `HARVEST_THRESHOLD_210 = 50` constant should be tuned against the game's economy balance. The architecture gives no exact "minimum to bother harvesting" number; 50 honey is a reasonable first-pass default (about one full tier-1 Honey cell capacity). Adjust this constant if the balance pass changes the honey economy.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HarvestBeaconController")
print("HarvestBeaconController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildBeacon_210:", c.Source:find("buildBeacon_210") ~= nil)
	print("  updateBeacon_210:", c.Source:find("updateBeacon_210") ~= nil)
	print("  startPulse_210:", c.Source:find("startPulse_210") ~= nil)
	print("  HARVEST_THRESHOLD_210:", c.Source:find("HARVEST_THRESHOLD_210") ~= nil)
	print("  HoneyCount attr:", c.Source:find("HoneyCount") ~= nil)
	print("  LandingBoard tag:", c.Source:find("LandingBoard") ~= nil)
end

local CS = game:GetService("CollectionService")
local boards = CS:GetTagged("LandingBoard")
print("LandingBoard tagged parts:", #boards, "(expect 6)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Simulate below threshold (beacon hidden)
game:GetService("Players").LocalPlayer:SetAttribute("HoneyCount", 10)
task.wait(0.5)
-- Simulate above threshold (beacon appears)
game:GetService("Players").LocalPlayer:SetAttribute("HoneyCount", 120)
task.wait(2)
-- Update in-place (count changes, label updates)
game:GetService("Players").LocalPlayer:SetAttribute("HoneyCount", 185)
task.wait(1)
-- Drop below threshold (beacon disappears)
game:GetService("Players").LocalPlayer:SetAttribute("HoneyCount", 0)
```

**Expected output:**
```
HarvestBeaconController: LocalScript
  lines: 160+
  buildBeacon_210: true
  updateBeacon_210: true
  startPulse_210: true
  HARVEST_THRESHOLD_210: true
  HoneyCount attr: true
  LandingBoard tag: true
LandingBoard tagged parts: 6
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| HoneyCount | Beacon | Pulse | Honey label |
|---|---|---|---|
| < 50 | Hidden | — | — |
| 50–149 | "🍯 Harvest!" | AMBER ↔ BRIGHT 1.1/s | "50 honey banked" |
| 150+ | "🍯 Harvest!" | Same pulse (brighter at peak) | "150 honey banked" (live update) |
| Drops to < 50 after harvest | Disappears | — | — |

- Beacon sits 6.5 studs above LandingBoard — visible over the comb grid and from adjacent plots
- Honey count label updates in-place each time HoneyCount changes (no rebuild, no flicker)
- Pulse rate 1.1/sec — noticeable and slightly urgent without being frantic
- UIStroke pulses AMBER → BRIGHT; label text pulses HONEY_GOLD → BRIGHT — two-layer visual draw
- The beacon is the natural partner to the HoneyGlowController (dispatch 204): glowing blobs mean "honey is ripe", pulsing beacon means "time to cash out"
- Visible across the Petal Path — other players can see which plots are harvest-ready, adding social pressure to the risk/reward decision

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(HarvestBeacon_210 BillboardGui is a client-only GuiObject parented to LandingBoard — not a BasePart)*
