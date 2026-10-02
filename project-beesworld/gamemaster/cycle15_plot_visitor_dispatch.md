# Dispatch 170 — Plot Visitor Toast
**File:** `cycle15_plot_visitor_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

In a 6-player shared server, other players can walk right up to your hive — but currently there is no feedback when that happens. This dispatch adds a **plot visitor toast**: when another player enters a 30-stud proximity radius around your own Landing Board, a small 3s toast fires: "👀 [PlayerName] is watching your hive!" This reinforces the shared-server social tension (especially the ripeness mechanic — someone watching = maybe they're waiting for you to leave so Old Molasses gets a clear shot), makes the world feel populated, and is genuinely fun for kids. Entirely client-side proximity scanning, zero server load.

---

## Step 1 — PlotVisitorController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PlotVisitorController`.

Paste exactly:

```lua
--!strict
-- PlotVisitorController: toast when another player enters proximity of your Landing Board
-- Entirely client-side magnitude polling. No server scripts, no RemoteEvents.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
local VISIT_RADIUS_170    = 30    -- studs — how close counts as "visiting"
local TOAST_COOLDOWN_170  = 20   -- seconds before the same visitor triggers again
local POLL_INTERVAL_170   = 2    -- seconds between proximity checks
local TOAST_DURATION_170  = 4    -- seconds the toast stays visible

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_170  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN_170  = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_170   = Color3.fromRGB(232, 212, 154)
local DARK_BG_170     = Color3.fromRGB(30,  18,  8)

-- ── Build toast UI ────────────────────────────────────────────────────────────
local function buildToast_170(): (Frame, TextLabel, TextLabel)
	local sg = Instance.new("ScreenGui")
	sg.Name           = "PlotVisitorGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 16
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	local toast = Instance.new("Frame")
	toast.Name              = "VisitorToast"
	toast.Size              = UDim2.new(0, 240, 0, 56)
	-- Start off-screen right
	toast.Position          = UDim2.new(1, 10, 0.5, -28)
	toast.BackgroundColor3  = DARK_BG_170
	toast.BorderSizePixel   = 0
	toast.ZIndex            = 30
	toast.Parent            = sg

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = toast

	local s = Instance.new("UIStroke")
	s.Color     = HONEY_GOLD_170
	s.Thickness = 1.5
	s.Parent    = toast

	local eyeLabel = Instance.new("TextLabel")
	eyeLabel.Name            = "EyeLabel"
	eyeLabel.Size            = UDim2.new(0, 40, 1, 0)
	eyeLabel.Position        = UDim2.new(0, 4, 0, 0)
	eyeLabel.BackgroundTransparency = 1
	eyeLabel.Text            = "👀"
	eyeLabel.TextSize        = 26
	eyeLabel.Font            = Enum.Font.GothamBold
	eyeLabel.TextXAlignment  = Enum.TextXAlignment.Center
	eyeLabel.ZIndex          = 31
	eyeLabel.Parent          = toast

	local kidLabel = Instance.new("TextLabel")
	kidLabel.Name            = "KidLabel"
	kidLabel.Size            = UDim2.new(0, 188, 0, 28)
	kidLabel.Position        = UDim2.new(0, 46, 0, 4)
	kidLabel.BackgroundTransparency = 1
	kidLabel.Text            = ""
	kidLabel.TextSize        = 13
	kidLabel.Font            = Enum.Font.GothamBold
	kidLabel.TextColor3      = WAX_CREAM_170
	kidLabel.TextWrapped     = true
	kidLabel.ZIndex          = 31
	kidLabel.Parent          = toast

	local adultLabel = Instance.new("TextLabel")
	adultLabel.Name          = "AdultLabel"
	adultLabel.Size          = UDim2.new(0, 188, 0, 20)
	adultLabel.Position      = UDim2.new(0, 46, 0, 32)
	adultLabel.BackgroundTransparency = 1
	adultLabel.Text          = ""
	adultLabel.TextSize      = 10
	adultLabel.Font          = Enum.Font.Gotham
	adultLabel.TextColor3    = Color3.fromRGB(180, 160, 120)
	adultLabel.ZIndex        = 31
	adultLabel.Parent        = toast

	return toast, kidLabel, adultLabel
end

-- ── State ─────────────────────────────────────────────────────────────────────
local toast_170, kidLabel_170, adultLabel_170 = buildToast_170()
local toastShowing_170   = false
local lastSeen_170: { [number]: number } = {}   -- userId → last toast timestamp

-- ── Find own Landing Board ────────────────────────────────────────────────────
local function findMyBoard_170(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, board in CollectionService:GetTagged("LandingBoard") do
		if board:GetAttribute("PlotIndex") == myPlot then
			return board :: BasePart
		end
	end
	return nil
end

-- ── Show toast ────────────────────────────────────────────────────────────────
local function showVisitorToast_170(visitor: Player)
	if toastShowing_170 then return end

	local now = tick()
	local lastTime = lastSeen_170[visitor.UserId] or 0
	if now - lastTime < TOAST_COOLDOWN_170 then return end
	lastSeen_170[visitor.UserId] = now

	toastShowing_170 = true

	local displayName = visitor.DisplayName or visitor.Name
	kidLabel_170.Text  = displayName .. " is watching your hive!"
	adultLabel_170.Text = "Maybe harvest soon… 🍯"

	-- Slide in from right
	TweenService:Create(toast_170, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -250, 0.5, -28) }):Play()

	task.delay(TOAST_DURATION_170, function()
		TweenService:Create(toast_170, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 10, 0.5, -28) }):Play()
		task.delay(0.25, function()
			toastShowing_170 = false
		end)
	end)
end

-- ── Proximity polling loop ────────────────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(POLL_INTERVAL_170)

		local myBoard = findMyBoard_170()
		if not myBoard then continue end

		local boardPos = myBoard.Position

		for _, otherPlayer in Players:GetPlayers() do
			if otherPlayer == player then continue end

			local char = otherPlayer.Character
			if not char then continue end

			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then continue end

			local dist = (root.Position - boardPos).Magnitude
			if dist <= VISIT_RADIUS_170 then
				showVisitorToast_170(otherPlayer)
				break  -- one toast per poll tick
			end
		end
	end
end)

-- Update board target on plot reassignment
player:GetAttributeChangedSignal("PlotIndex"):Connect(function()
	-- findMyBoard_170 reads PlotIndex live; no explicit cache to clear
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PlotVisitorController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check controller
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PlotVisitorController")
print("PlotVisitorController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  VISIT_RADIUS_170:", c.Source:find("VISIT_RADIUS_170") ~= nil)
	print("  lastSeen_170:", c.Source:find("lastSeen_170") ~= nil)
	print("  LandingBoard tag lookup:", c.Source:find("LandingBoard") ~= nil)
end

-- Part count: should still be 4204
local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
PlotVisitorController: LocalScript
  lines: 140+
  VISIT_RADIUS_170: true
  lastSeen_170: true
  LandingBoard tag lookup: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Trigger | Toast content |
|---------|--------------|
| Other player enters 30-stud radius of your Landing Board | 👀 "[Name] is watching your hive!" |
| Adult sub-text | "Maybe harvest soon… 🍯" |
| Toast duration | 4s, slides in from right, slides out |
| Per-visitor cooldown | 20s — same visitor won't retrigger for 20s |
| Poll cadence | Every 2s — light client overhead |
| Solo server | Never fires (no other players) |

**Part budget: +0 permanent → 4,204 / 5,000**
