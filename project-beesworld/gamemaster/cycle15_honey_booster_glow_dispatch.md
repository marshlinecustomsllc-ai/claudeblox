# Dispatch 172 — Honey Booster Glow Effect
**File:** `cycle15_honey_booster_glow_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When the `honey_booster` consumable is active, honey is produced faster — but currently there is no visual indicator that the boost is running. Players can't see whether it's working without opening the HiveGui. This dispatch adds a **honey glow pulse** on all of the player's Honey-type comb cells while the booster is active: the cells' existing PointLights pulse brighter in a warm amber rhythm (every 2s), and a small `⚡ Boost active` pill appears on the HiveGui. When the boost expires, the pulse fades out smoothly. Entirely client-side.

---

## Step 1 — HoneyBoosterController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HoneyBoosterController`.

Paste exactly:

```lua
--!strict
-- HoneyBoosterController: pulsing glow on Honey cells while honey_booster is active
-- Reads HoneyBoosterActive and HoneyBoosterExpiry player attributes.
-- Modifies PointLight Brightness on CombCell parts tagged HoneyCell.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
local PULSE_PERIOD_172    = 2.0    -- seconds per glow cycle
local BOOST_BRIGHTNESS_172 = 4.0  -- boosted PointLight brightness multiplier
local BASE_BRIGHTNESS_172  = 1.0  -- returned to on boost end
local AMBER_BOOST_172      = Color3.fromRGB(255, 180, 40)  -- boosted colour
local POLL_INTERVAL_172    = 3    -- seconds between attribute checks

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_172  = Color3.fromRGB(242, 168, 28)
local WAX_CREAM_172   = Color3.fromRGB(232, 212, 154)
local DARK_BG_172     = Color3.fromRGB(30,  18,  8)
local GREEN_172       = Color3.fromRGB(80,  200, 80)

-- ── Build status pill ─────────────────────────────────────────────────────────
local function buildPill_172(): (ScreenGui, Frame, TextLabel)
	-- Try to attach to HiveGui first; fall back to own ScreenGui
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	local parentGui: ScreenGui

	if hiveGui then
		parentGui = hiveGui
	else
		local sg = Instance.new("ScreenGui")
		sg.Name           = "HoneyBoosterGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 17
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui
		parentGui = sg
	end

	local pill = Instance.new("Frame")
	pill.Name              = "BoosterPill"
	pill.Size              = UDim2.new(0, 130, 0, 26)
	-- Bottom-right corner above mobile buttons area
	pill.Position          = UDim2.new(1, -142, 1, -120)
	pill.BackgroundColor3  = DARK_BG_172
	pill.BorderSizePixel   = 0
	pill.Visible           = false
	pill.ZIndex            = 35
	pill.Parent            = parentGui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = pill

	local s = Instance.new("UIStroke")
	s.Color     = HONEY_GOLD_172
	s.Thickness = 1.5
	s.Parent    = pill

	local label = Instance.new("TextLabel")
	label.Name            = "BoosterLabel"
	label.Size            = UDim2.new(1, -8, 1, 0)
	label.Position        = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text            = "⚡ Boost active!"
	label.TextSize        = 12
	label.Font            = Enum.Font.GothamBold
	label.TextColor3      = HONEY_GOLD_172
	label.ZIndex          = 36
	label.Parent          = pill

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name          = "TimerLabel"
	timerLabel.Size          = UDim2.new(0, 40, 1, 0)
	timerLabel.Position      = UDim2.new(1, -44, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text          = ""
	timerLabel.TextSize      = 10
	timerLabel.Font          = Enum.Font.Gotham
	timerLabel.TextColor3    = WAX_CREAM_172
	timerLabel.ZIndex        = 36
	timerLabel.Parent        = pill

	return parentGui, pill, timerLabel
end

-- ── Find player's own Honey cells ─────────────────────────────────────────────
-- HoneyCell tag or CombCell tag with CellType="Honey" attribute
local function getHoneyCells_172(): { BasePart }
	local myPlot = player:GetAttribute("PlotIndex") or 1
	local cells = {}
	-- Tagged HoneyCell (preferred)
	for _, part in CollectionService:GetTagged("HoneyCell") do
		if part:IsA("BasePart") and part:GetAttribute("PlotIndex") == myPlot then
			table.insert(cells, part)
		end
	end
	-- Fallback: CombCell with CellType attribute
	if #cells == 0 then
		for _, part in CollectionService:GetTagged("CombCell") do
			if part:IsA("BasePart") and part:GetAttribute("PlotIndex") == myPlot
				and part:GetAttribute("CellType") == "Honey" then
				table.insert(cells, part)
			end
		end
	end
	return cells
end

-- ── Pulse loop ────────────────────────────────────────────────────────────────
local pulseActive_172 = false
local pulseConn_172: RBXScriptConnection? = nil

local function startPulse_172()
	if pulseActive_172 then return end
	pulseActive_172 = true

	local t = 0
	pulseConn_172 = RunService.Heartbeat:Connect(function(dt)
		if not pulseActive_172 then
			if pulseConn_172 then pulseConn_172:Disconnect() end
			return
		end
		t = t + dt
		-- Sine wave 0..1 over PULSE_PERIOD_172
		local phase = math.sin(t * (2 * math.pi / PULSE_PERIOD_172)) * 0.5 + 0.5
		local brightness = BASE_BRIGHTNESS_172 + phase * (BOOST_BRIGHTNESS_172 - BASE_BRIGHTNESS_172)

		for _, cell in getHoneyCells_172() do
			local light = cell:FindFirstChildOfClass("PointLight") :: PointLight?
			if light then
				light.Brightness = brightness
				light.Color = AMBER_BOOST_172
			end
		end
	end)
end

local function stopPulse_172()
	pulseActive_172 = false
	if pulseConn_172 then
		pulseConn_172:Disconnect()
		pulseConn_172 = nil
	end
	-- Restore all lights to base
	TweenService:Create(Instance.new("NumberValue"), TweenInfo.new(0), {}):Play()  -- dummy, actual restore below
	for _, cell in getHoneyCells_172() do
		local light = cell:FindFirstChildOfClass("PointLight") :: PointLight?
		if light then
			TweenService:Create(light, TweenInfo.new(1.5, Enum.EasingStyle.Sine),
				{ Brightness = BASE_BRIGHTNESS_172 }):Play()
		end
	end
end

-- ── State ─────────────────────────────────────────────────────────────────────
local _, pill_172, timerLabel_172 = buildPill_172()
local wasActive_172 = false

-- ── Poll attribute ────────────────────────────────────────────────────────────
local function checkBooster_172()
	local isActive = player:GetAttribute("HoneyBoosterActive") == true
	local expiry   = player:GetAttribute("HoneyBoosterExpiry") or 0
	local remaining = math.max(0, expiry - os.time())

	if isActive and remaining > 0 then
		if not wasActive_172 then
			wasActive_172 = true
			pill_172.Visible = true
			startPulse_172()
		end
		-- Update timer label
		local mins = math.floor(remaining / 60)
		local secs = remaining % 60
		timerLabel_172.Text = string.format("%d:%02d", mins, secs)
	else
		if wasActive_172 then
			wasActive_172 = false
			pill_172.Visible = false
			stopPulse_172()
		end
	end
end

-- Poll every POLL_INTERVAL_172 seconds
task.spawn(function()
	while true do
		checkBooster_172()
		task.wait(POLL_INTERVAL_172)
	end
end)

-- Also react immediately to attribute change
player:GetAttributeChangedSignal("HoneyBoosterActive"):Connect(checkBooster_172)
```

---

## Step 2 — ConsumableService attribute patch

Open **ConsumableService** (ServerScriptService.Systems) and inside the `honey_booster` use case, after applying the boost effect, add:

```lua
-- Set attributes so HoneyBoosterController can poll them
local duration_171 = 120  -- seconds (or whatever ConsumableService.BOOST_DURATION is)
player:SetAttribute("HoneyBoosterActive", true)
player:SetAttribute("HoneyBoosterExpiry", os.time() + duration_171)

-- Schedule attribute clear when boost expires
task.delay(duration_171, function()
	if player and player.Parent then
		player:SetAttribute("HoneyBoosterActive", false)
	end
end)
```

If ConsumableService already sets these attributes, skip this step.

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HoneyBoosterController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HoneyBoosterController")
print("HoneyBoosterController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  PULSE_PERIOD_172:", c.Source:find("PULSE_PERIOD_172") ~= nil)
	print("  startPulse:", c.Source:find("startPulse_172") ~= nil)
	print("  HoneyBoosterActive:", c.Source:find("HoneyBoosterActive") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HoneyBoosterController: LocalScript
  lines: 170+
  PULSE_PERIOD_172: true
  startPulse: true
  HoneyBoosterActive: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Visual |
|-------|--------|
| Boost active | Honey cell PointLights pulse 1×→4× brightness, amber colour, 2s sine cycle |
| Status pill | "⚡ Boost active! M:SS" — bottom-right, 130×26px |
| Boost expires | 1.5s smooth fade back to base brightness; pill hides |
| No Honey cells built | Pulse loop runs silently; pill still shows timer |
| Attribute poll | Every 3s + immediate on `HoneyBoosterActive` change |

**Part budget: +0 permanent → 4,204 / 5,000**
