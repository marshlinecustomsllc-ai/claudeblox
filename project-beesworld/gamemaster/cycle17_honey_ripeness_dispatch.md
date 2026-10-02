# Dispatch 187 — Honey Ripeness Countdown
**File:** `cycle17_honey_ripeness_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The honey ripening system already runs server-side (via ResourceService), and each `HoneyCell` part has a `RipenessValue` attribute (0.0–2.2) updated by the server. Players currently see the honey cells glow brighter as they ripen, but there's no readable number — they can't tell if they're two minutes away from 2× or already there. This dispatch adds a **Honey Ripeness Countdown**: a compact live-updating panel that displays the top-3 ripest honey cells on the player's plot, showing their ripeness value, a colour-fill bar, and a human-readable time estimate to the next tier. A "⚠️ Old Molasses is watching!" warning banner pulses amber whenever any cell is above 1.8× (the architecture's stated Molasses-aggro threshold). Kids read the emoji and banner; adults read the values and eta.

Entirely client-side. Zero new permanent parts. Polls `HoneyCell`-tagged BasePart `RipenessValue` attributes every 3 seconds.

---

## Step 1 — HoneyRipenessController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HoneyRipenessController`.

Paste exactly:

```lua
--!strict
-- HoneyRipenessController: live ripeness panel for top-3 honey cells + Molasses warning.
-- Polls HoneyCell-tagged parts for RipenessValue attribute every 3 seconds.
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
local POLL_INTERVAL_187   = 3.0    -- seconds between ripeness polls
local MAX_ROWS_187        = 3      -- show top-3 ripest cells
local MOLASSES_THRESH_187 = 1.8    -- ripeness at which Old Molasses takes interest
local RIPEN_RATE_187      = 0.002  -- approx ripeness gain per second (matches Config)
local MAX_RIPENESS_187    = 2.2    -- full ripeness cap

-- ── Palette ───────────────────────────────────────────────────────────────────
local GREEN_187   = Color3.fromRGB( 80, 200,  80)   -- low ripeness (safe)
local AMBER_187   = Color3.fromRGB(242, 168,  28)   -- honey gold (prime)
local ORANGE_187  = Color3.fromRGB(230, 110,  20)   -- high (Molasses watching)
local RED_187     = Color3.fromRGB(210,  50,  30)   -- max ripeness
local WAX_CREAM_187 = Color3.fromRGB(232, 212, 154)
local DARK_BG_187   = Color3.fromRGB( 30,  18,   8)
local GREY_187      = Color3.fromRGB( 90,  80,  70)

-- ── Ripeness → colour ─────────────────────────────────────────────────────────
local function ripenessColor_187(r: number): Color3
	if r < 1.0 then return GREEN_187:Lerp(AMBER_187, r) end
	if r < 1.8 then return AMBER_187:Lerp(ORANGE_187, (r - 1.0) / 0.8) end
	return ORANGE_187:Lerp(RED_187, (r - 1.8) / 0.4)
end

-- ── ETA string ────────────────────────────────────────────────────────────────
local TIERS_187 = { 1.0, 1.4, 1.8, 2.0, MAX_RIPENESS_187 }

local function etaString_187(r: number): string
	for _, tier in TIERS_187 do
		if r < tier then
			local remaining = (tier - r) / RIPEN_RATE_187
			if remaining < 60 then
				return string.format("~%ds", math.ceil(remaining))
			elseif remaining < 3600 then
				return string.format("~%dm", math.ceil(remaining / 60))
			else
				return string.format("~%dh", math.ceil(remaining / 3600))
			end
		end
	end
	return "MAX"
end

-- ── Kid-friendly tier label ───────────────────────────────────────────────────
local function tierLabel_187(r: number): string
	if r < 1.0 then return "🍯 Ripening" end
	if r < 1.4 then return "🍯 Ready!" end
	if r < 1.8 then return "✨ Prime!" end
	if r < 2.0 then return "⚠️ Very ripe" end
	return "🔥 MAX — sell now!"
end

-- ── Build panel ───────────────────────────────────────────────────────────────
local panelFrame_187: Frame? = nil
local rowFrames_187: { Frame } = {}
local warnBanner_187: Frame? = nil
local molassesLabel_187: TextLabel? = nil
local pulseConn_187: RBXScriptConnection? = nil
local pulseT_187 = 0

local function buildPanel_187(): Frame
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	local parent: GuiObject

	if hiveGui then
		parent = hiveGui :: any
	else
		local sg = Instance.new("ScreenGui")
		sg.Name           = "HoneyRipenessGui"
		sg.ResetOnSpawn   = false
		sg.DisplayOrder   = 25
		sg.IgnoreGuiInset = true
		sg.Parent         = PlayerGui
		parent = sg
	end

	local panel = Instance.new("Frame")
	panel.Name                   = "RipenessPanel"
	panel.Size                   = UDim2.new(0, 140, 0, 110)
	panel.Position               = UDim2.new(1, -148, 0.5, -55)
	panel.BackgroundColor3       = DARK_BG_187
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel        = 0
	panel.ZIndex                 = 20
	panel.Parent                 = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local stroke = Instance.new("UIStroke")
	stroke.Color     = AMBER_187
	stroke.Thickness = 1
	stroke.Parent    = panel

	-- Title row
	local title = Instance.new("TextLabel")
	title.Name               = "PanelTitle"
	title.Size               = UDim2.new(1, -8, 0, 16)
	title.Position           = UDim2.new(0, 4, 0, 4)
	title.BackgroundTransparency = 1
	title.Text               = "🍯 Honey Ripeness"
	title.TextSize           = 10
	title.Font               = Enum.Font.GothamBold
	title.TextColor3         = AMBER_187
	title.TextXAlignment     = Enum.TextXAlignment.Center
	title.ZIndex             = 21
	title.Parent             = panel

	-- Molasses warning banner (initially hidden)
	local warn = Instance.new("Frame")
	warn.Name                   = "MolassesBanner"
	warn.Size                   = UDim2.new(1, -4, 0, 14)
	warn.Position               = UDim2.new(0, 2, 0, 22)
	warn.BackgroundColor3       = ORANGE_187
	warn.BackgroundTransparency = 0.15
	warn.BorderSizePixel        = 0
	warn.Visible                = false
	warn.ZIndex                 = 22
	warn.Parent                 = panel

	local warnCorner = Instance.new("UICorner")
	warnCorner.CornerRadius = UDim.new(0, 4)
	warnCorner.Parent = warn

	local warnLbl = Instance.new("TextLabel")
	warnLbl.Name               = "WarnText"
	warnLbl.Size               = UDim2.new(1, 0, 1, 0)
	warnLbl.BackgroundTransparency = 1
	warnLbl.Text               = "⚠️ Old Molasses is watching!"
	warnLbl.TextSize           = 8
	warnLbl.Font               = Enum.Font.GothamBold
	warnLbl.TextColor3         = WAX_CREAM_187
	warnLbl.TextXAlignment     = Enum.TextXAlignment.Center
	warnLbl.ZIndex             = 23
	warnLbl.Parent             = warn

	warnBanner_187    = warn
	molassesLabel_187 = warnLbl

	-- 3 cell rows
	rowFrames_187 = {}
	for i = 1, MAX_ROWS_187 do
		local row = Instance.new("Frame")
		row.Name                   = "Row" .. i
		row.Size                   = UDim2.new(1, -8, 0, 20)
		row.Position               = UDim2.new(0, 4, 0, 20 + (i - 1) * 26 + (i > 1 and 16 or 0))
		row.BackgroundColor3       = DARK_BG_187
		row.BackgroundTransparency = 0.4
		row.BorderSizePixel        = 0
		row.Visible                = false
		row.ZIndex                 = 21
		row.Parent                 = panel

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 4)
		rowCorner.Parent = row

		-- Fill bar background
		local barBg = Instance.new("Frame")
		barBg.Name                   = "BarBg"
		barBg.Size                   = UDim2.new(1, -4, 0, 6)
		barBg.Position               = UDim2.new(0, 2, 1, -8)
		barBg.BackgroundColor3       = GREY_187
		barBg.BackgroundTransparency = 0.3
		barBg.BorderSizePixel        = 0
		barBg.ZIndex                 = 22
		barBg.Parent                 = row

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(0.5, 0)
		barCorner.Parent = barBg

		-- Fill bar fill
		local fill = Instance.new("Frame")
		fill.Name                   = "BarFill"
		fill.Size                   = UDim2.new(0.5, 0, 1, 0)
		fill.Position               = UDim2.new(0, 0, 0, 0)
		fill.BackgroundColor3       = AMBER_187
		fill.BorderSizePixel        = 0
		fill.ZIndex                 = 23
		fill.Parent                 = barBg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(0.5, 0)
		fillCorner.Parent = fill

		-- Cell label (kid tier)
		local lbl = Instance.new("TextLabel")
		lbl.Name               = "CellLabel"
		lbl.Size               = UDim2.new(0.65, 0, 0, 14)
		lbl.Position           = UDim2.new(0, 2, 0, 2)
		lbl.BackgroundTransparency = 1
		lbl.Text               = "—"
		lbl.TextSize           = 9
		lbl.Font               = Enum.Font.GothamBold
		lbl.TextColor3         = WAX_CREAM_187
		lbl.TextXAlignment     = Enum.TextXAlignment.Left
		lbl.ZIndex             = 22
		lbl.Parent             = row

		-- ETA label (adult detail)
		local eta = Instance.new("TextLabel")
		eta.Name               = "EtaLabel"
		eta.Size               = UDim2.new(0.35, -2, 0, 14)
		eta.Position           = UDim2.new(0.65, 0, 0, 2)
		eta.BackgroundTransparency = 1
		eta.Text               = "—"
		eta.TextSize           = 9
		eta.Font               = Enum.Font.Gotham
		eta.TextColor3         = GREY_187
		eta.TextXAlignment     = Enum.TextXAlignment.Right
		eta.ZIndex             = 22
		eta.Parent             = row

		table.insert(rowFrames_187, row)
	end

	panelFrame_187 = panel
	return panel
end

-- ── Molasses pulse ────────────────────────────────────────────────────────────
local function startMolassesPulse_187()
	if pulseConn_187 then return end
	pulseT_187 = 0
	pulseConn_187 = RunService.Heartbeat:Connect(function(dt)
		pulseT_187 = pulseT_187 + dt
		local phase = math.sin(pulseT_187 * math.pi * 1.5) * 0.5 + 0.5
		if warnBanner_187 then
			warnBanner_187.BackgroundColor3 = AMBER_187:Lerp(ORANGE_187, phase)
		end
	end)
end

local function stopMolassesPulse_187()
	if pulseConn_187 then pulseConn_187:Disconnect(); pulseConn_187 = nil end
end

-- ── Poll and update ───────────────────────────────────────────────────────────
local function updatePanel_187()
	local myPlot = player:GetAttribute("PlotIndex") or 1

	-- Gather all honey cells on this plot with ripeness values
	local cells: { { part: BasePart, r: number } } = {}
	for _, obj in CollectionService:GetTagged("HoneyCell") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			local r = obj:GetAttribute("RipenessValue") :: number?
			table.insert(cells, { part = obj, r = r or 1.0 })
		end
	end

	-- Sort descending by ripeness
	table.sort(cells, function(a, b) return a.r > b.r end)

	local molassesAlert = false

	-- Fill rows
	for i = 1, MAX_ROWS_187 do
		local row = rowFrames_187[i]
		if not row then continue end

		local data = cells[i]
		if not data then
			row.Visible = false
			continue
		end

		row.Visible = true
		local r = data.r
		local color = ripenessColor_187(r)

		local fillFrac = math.min(r / MAX_RIPENESS_187, 1)
		local fill = row:FindFirstChild("BarBg")
			and row.BarBg:FindFirstChild("BarFill") :: Frame?
		if fill then
			TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Sine),
				{ Size = UDim2.new(fillFrac, 0, 1, 0), BackgroundColor3 = color }):Play()
		end

		local cellLbl = row:FindFirstChild("CellLabel") :: TextLabel?
		if cellLbl then
			cellLbl.Text       = tierLabel_187(r)
			cellLbl.TextColor3 = color
		end

		local etaLbl = row:FindFirstChild("EtaLabel") :: TextLabel?
		if etaLbl then
			etaLbl.Text       = etaString_187(r)
			etaLbl.TextColor3 = if r >= MOLASSES_THRESH_187 then ORANGE_187 else GREY_187
		end

		if r >= MOLASSES_THRESH_187 then molassesAlert = true end
	end

	-- Molasses banner
	if warnBanner_187 then
		warnBanner_187.Visible = molassesAlert
		if molassesAlert then startMolassesPulse_187() else stopMolassesPulse_187() end
	end

	-- No cells → hide panel
	if panelFrame_187 then
		panelFrame_187.Visible = #cells > 0
	end
end

-- ── Heartbeat poll ────────────────────────────────────────────────────────────
local lastPoll_187 = 0

task.delay(2, function()
	buildPanel_187()
	updatePanel_187()

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastPoll_187 < POLL_INTERVAL_187 then return end
		lastPoll_187 = now
		updatePanel_187()
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HoneyRipenessController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HoneyRipenessController")
print("HoneyRipenessController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  ripenessColor_187:", c.Source:find("ripenessColor_187") ~= nil)
	print("  updatePanel_187:", c.Source:find("updatePanel_187") ~= nil)
	print("  MOLASSES_THRESH_187:", c.Source:find("MOLASSES_THRESH_187") ~= nil)
	print("  etaString_187:", c.Source:find("etaString_187") ~= nil)
end

-- Count HoneyCell-tagged parts (expect > 0 if player has honey cells built)
local CS = game:GetService("CollectionService")
local honeys = CS:GetTagged("HoneyCell")
print("HoneyCell tagged parts:", #honeys)

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HoneyRipenessController: LocalScript
  lines: 220+
  ripenessColor_187: true
  updatePanel_187: true
  MOLASSES_THRESH_187: true
  etaString_187: true
HoneyCell tagged parts: 0  (0 in fresh Edit mode — cells built during Play)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Ripeness | Bar colour | Kid label | Adult ETA | Molasses banner |
|----------|-----------|-----------|-----------|-----------------|
| 0.0–1.0 | Green → gold | "🍯 Ripening" | "~Xm" to 1.0 | Hidden |
| 1.0–1.4 | Honey gold | "🍯 Ready!" | "~Xm" to 1.4 | Hidden |
| 1.4–1.8 | Gold → orange | "✨ Prime!" | "~Xm" to 1.8 | Hidden |
| 1.8–2.0 | Orange | "⚠️ Very ripe" | "~Xs" to 2.0 | **Pulsing amber** |
| 2.0–2.2 | Orange → red | "🔥 MAX — sell now!" | "MAX" | **Pulsing amber** |
| No honey cells | Panel hidden | — | — | Hidden |
| 0 active cells on plot | Panel hidden entirely | — | — | Hidden |

**Part budget: +0 permanent → 4,204 / 5,000**
*(Panel Frame and rows are GuiObjects inside PlayerGui — not BaseParts)*
