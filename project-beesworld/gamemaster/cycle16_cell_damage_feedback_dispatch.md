# Dispatch 180 — Comb Cell Damage Feedback
**File:** `cycle16_cell_damage_feedback_dispatch.md`
**Cycle:** 16
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When Old Molasses raids and destroys honey cells, the loss is sudden and confusing — the cell simply vanishes. Players (especially kids) don't understand what happened or what to do next. This dispatch adds **Comb Cell Damage Feedback**: when the `CellDamaged` RemoteEvent fires, the affected cell flashes red then fades to a charred-looking transparency, a "😱 Molasses hit a cell!" toast appears, and a small repair-cost badge floats up from the damaged cell's last known screen position. Kids get an emotional cue; adults get the rebuild cost immediately so they can plan their response.

Entirely client-side. Zero new permanent parts. Uses the existing `CellDamaged` RemoteEvent (or falls back to a Notify message pattern).

---

## Step 1 — CellDamageController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `CellDamageController`.

Paste exactly:

```lua
--!strict
-- CellDamageController: flash + repair-cost badge when a comb cell takes Molasses damage.
-- Listens to CellDamaged RemoteEvent (payload: cellPart: BasePart, rebuildCost: number).
-- Fallback: Notify message containing "molasses" + "cell".
-- Entirely client-side — zero server code.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local FLASH_COUNT_180   = 3      -- how many times the cell flashes red
local FLASH_PERIOD_180  = 0.18   -- seconds per flash half-cycle
local BADGE_FLOAT_180   = 1.8    -- seconds the repair badge floats
local TOAST_DURATION_180 = 3.5  -- seconds the toast stays on screen

-- ── Palette ───────────────────────────────────────────────────────────────────
local RED_FLASH_180   = Color3.fromRGB(220,  40,  40)
local CHAR_COLOR_180  = Color3.fromRGB( 60,  35,  15)   -- charred dark brown
local HONEY_GOLD_180  = Color3.fromRGB(242, 168,  28)
local WAX_CREAM_180   = Color3.fromRGB(232, 212, 154)
local DARK_BG_180     = Color3.fromRGB( 30,  18,   8)
local ORANGE_180      = Color3.fromRGB(230, 110,  20)

-- ── Build toast (reused) ──────────────────────────────────────────────────────
local toast_180: Frame? = nil

local function buildToast_180(): Frame
	local sg = Instance.new("ScreenGui")
	sg.Name           = "CellDamageToastGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 30
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	local frame = Instance.new("Frame")
	frame.Name              = "DamageToast"
	frame.Size              = UDim2.new(0, 260, 0, 36)
	frame.Position          = UDim2.new(0.5, -130, 0, -50)
	frame.BackgroundColor3  = DARK_BG_180
	frame.BorderSizePixel   = 0
	frame.ZIndex            = 40
	frame.Parent            = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = RED_FLASH_180
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local label = Instance.new("TextLabel")
	label.Name               = "ToastLabel"
	label.Size               = UDim2.new(1, -10, 1, 0)
	label.Position           = UDim2.new(0, 5, 0, 0)
	label.BackgroundTransparency = 1
	label.Text               = "😱 Molasses hit a cell!"
	label.TextSize           = 13
	label.Font               = Enum.Font.GothamBold
	label.TextColor3         = WAX_CREAM_180
	label.TextXAlignment     = Enum.TextXAlignment.Center
	label.ZIndex             = 41
	label.Parent             = frame

	return frame
end

-- ── Show toast ────────────────────────────────────────────────────────────────
local toastActive_180 = false

local function showDamageToast_180(rebuildCost: number)
	if toastActive_180 then return end
	toastActive_180 = true

	if not toast_180 then
		toast_180 = buildToast_180()
	end
	local frame = toast_180
	local lbl   = frame:FindFirstChild("ToastLabel") :: TextLabel?

	if lbl then
		if rebuildCost > 0 then
			lbl.Text = string.format("😱 Molasses hit a cell!  rebuild: %d 🪨", rebuildCost)
		else
			lbl.Text = "😱 Molasses hit a cell!"
		end
	end

	frame.Position = UDim2.new(0.5, -130, 0, -50)
	frame.BackgroundTransparency = 0

	TweenService:Create(frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -130, 0, 10) }):Play()

	task.delay(TOAST_DURATION_180, function()
		TweenService:Create(frame,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -130, 0, -50),
			  BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function()
			toastActive_180 = false
		end)
	end)
end

-- ── Flash a cell part red, then leave it charred ─────────────────────────────
local function flashCellDamage_180(cellPart: BasePart)
	local origColor = cellPart.Color
	local origTrans = cellPart.Transparency

	-- Flash loop
	for i = 1, FLASH_COUNT_180 do
		TweenService:Create(cellPart, TweenInfo.new(FLASH_PERIOD_180),
			{ Color = RED_FLASH_180, Transparency = 0.0 }):Play()
		task.wait(FLASH_PERIOD_180)
		TweenService:Create(cellPart, TweenInfo.new(FLASH_PERIOD_180),
			{ Color = origColor, Transparency = origTrans }):Play()
		task.wait(FLASH_PERIOD_180)
	end

	-- Leave charred (server will destroy the instance shortly; this is cosmetic)
	TweenService:Create(cellPart, TweenInfo.new(0.5, Enum.EasingStyle.Sine),
		{ Color = CHAR_COLOR_180, Transparency = 0.55 }):Play()
end

-- ── Float repair-cost badge from cell's screen position ──────────────────────
local function showRepairBadge_180(cellPart: BasePart, rebuildCost: number)
	if rebuildCost <= 0 then return end

	local camera = workspace.CurrentCamera
	local screenPos, onScreen = camera:WorldToScreenPoint(cellPart.Position)
	if not onScreen then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "RepairBadge_180"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 31
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	local badge = Instance.new("TextLabel")
	badge.Name               = "BadgeLabel"
	badge.Size               = UDim2.new(0, 110, 0, 22)
	badge.Position           = UDim2.new(0, screenPos.X - 55, 0, screenPos.Y - 11)
	badge.BackgroundColor3   = DARK_BG_180
	badge.BackgroundTransparency = 0.1
	badge.BorderSizePixel    = 0
	badge.Text               = string.format("🪨 rebuild %d wax", rebuildCost)
	badge.TextSize           = 11
	badge.Font               = Enum.Font.GothamBold
	badge.TextColor3         = ORANGE_180
	badge.TextXAlignment     = Enum.TextXAlignment.Center
	badge.ZIndex             = 42
	badge.Parent             = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge

	-- Float upward and fade
	local targetY = badge.Position.Y.Offset - 50
	TweenService:Create(badge,
		TweenInfo.new(BADGE_FLOAT_180, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position  = UDim2.new(0, screenPos.X - 55, 0, targetY),
		  TextTransparency = 1,
		  BackgroundTransparency = 1 }):Play()

	task.delay(BADGE_FLOAT_180 + 0.1, function()
		sg:Destroy()
	end)
end

-- ── Handle damage event ───────────────────────────────────────────────────────
local function onCellDamaged_180(cellPart: BasePart?, rebuildCost: number?)
	local cost = rebuildCost or 0
	showDamageToast_180(cost)

	if cellPart and cellPart:IsA("BasePart") then
		-- Run flash in background so we don't block
		task.spawn(flashCellDamage_180, cellPart)
		showRepairBadge_180(cellPart, cost)
	end
end

-- ── Listen to CellDamaged RemoteEvent ─────────────────────────────────────────
local function connectCellDamaged_180()
	local re = Remotes:FindFirstChild("CellDamaged") :: RemoteEvent?
	if re then
		re.OnClientEvent:Connect(function(cellPart: BasePart?, rebuildCost: number?)
			onCellDamaged_180(cellPart, rebuildCost)
		end)
		return true
	end
	return false
end

if not connectCellDamaged_180() then
	task.spawn(function()
		while true do
			task.wait(8)
			if connectCellDamaged_180() then break end
		end
	end)
end

-- ── Notify fallback (ThreatService fires Notify if CellDamaged not yet wired) ──
local notify = Remotes:FindFirstChild("Notify") :: RemoteEvent?
if notify then
	notify.OnClientEvent:Connect(function(msg: string?, _kind: string?)
		if not msg then return end
		local lower = msg:lower()
		if lower:find("molasses") and lower:find("cell") then
			onCellDamaged_180(nil, 0)
		end
	end)
end
```

---

## Step 2 — ThreatService patch (server-side, CellDamaged event)

Open **ServerScriptService → Systems → ThreatService** and add the following where a cell is destroyed during a Molasses raid:

```lua
-- After destroying a cell, fire CellDamaged with the part reference and rebuild cost
-- Add this just before or just after the cell:Destroy() call in your raid handler:

local cellDamagedRE = Remotes:FindFirstChild("CellDamaged") :: RemoteEvent?
if cellDamagedRE and cell and cell:IsA("BasePart") then
	-- Calculate rebuild cost from Config (same formula as BuildController)
	local cellType = cell:GetAttribute("CellType") or "Honey"
	local tier     = cell:GetAttribute("CellTier") or 1
	local cost     = Config.CELL_COSTS and Config.CELL_COSTS[cellType]
		and Config.CELL_COSTS[cellType][tier] or 0
	cellDamagedRE:FireClient(raidTarget, cell, cost)
end
```

Also create the RemoteEvent if it doesn't exist (add to ThreatService init block):

```lua
if not Remotes:FindFirstChild("CellDamaged") then
	local re = Instance.new("RemoteEvent")
	re.Name   = "CellDamaged"
	re.Parent = Remotes
end
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("CellDamageController")
print("CellDamageController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  flashCellDamage_180:", c.Source:find("flashCellDamage_180") ~= nil)
	print("  showRepairBadge_180:", c.Source:find("showRepairBadge_180") ~= nil)
	print("  CellDamaged listener:", c.Source:find("CellDamaged") ~= nil)
	print("  Notify fallback:", c.Source:find("Notify") ~= nil)
end

-- Check CellDamaged RemoteEvent (only after ThreatService patch is applied)
local re = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CellDamaged")
print("CellDamaged RemoteEvent:", re and re.ClassName or "MISSING (add in ThreatService)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
CellDamageController: LocalScript
  lines: 190+
  flashCellDamage_180: true
  showRepairBadge_180: true
  CellDamaged listener: true
  Notify fallback: true
CellDamaged RemoteEvent: RemoteEvent
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Event | Visual feedback |
|-------|-----------------|
| `CellDamaged` fires with cell part | Cell flashes red 3× then goes charred (dark brown, 55% transparency) |
| `CellDamaged` fires with rebuild cost > 0 | Floating badge: "🪨 rebuild N wax" floats up from cell position and fades |
| Any damage (cost or no cost) | Toast slides down from top: "😱 Molasses hit a cell!  rebuild: N 🪨" |
| Multiple hits (toast already showing) | Second hit ignored until first toast clears (3.5s cooldown) |
| Cell off-screen when hit | Toast still fires; repair badge skipped (not on screen) |
| Notify fallback fires | Toast only (no cell flash — cell reference unavailable) |

**Part budget: +0 permanent → 4,204 / 5,000**
