# Dispatch 224 — Plot Name Plaques
**File:** `cycle23_plot_plaques_dispatch.md`
**Cycle:** 23
**Date:** 2026-10-02
**Part budget before:** 4,212 / 5,000
**Part budget after:** 4,218 / 5,000 (+6)

---

## Overview

With 6 plots in the Apiary Yard and up to 6 players, it's hard to tell whose hive is whose without walking up to the Plot Flag. This dispatch adds a **Plot Name Plaque**: a styled BillboardGui mounted on a small physical plaque Part above each plot's Landing Board, showing the plot owner's username and a bee-tier indicator (Starter / Apprentice / Expert / Master based on cell count). Updates reactively when a player claims or releases a plot.

For kids: seeing your own name above your hive makes it feel like YOUR home base. For adults: the tier indicator shows progress at a glance when visiting other plots.

---

## Step 1 — Plaque world parts (one per plot, 6 total)

Run in **Studio Command Bar** (Edit mode) to build the 6 plaque Parts above each plot's Landing Board:

```lua
-- Plaque positions: 2 studs above each Landing Board, slightly forward
-- Landing Boards are at ~Y=1.5 on each plot. Adjust coordinates to match actual plot positions.
-- Plots are at X offsets: Plot1=0, Plot2=40, Plot3=80, Plot4=120, Plot5=160, Plot6=200
-- (adjust based on actual plot layout from architecture)

local map = workspace:FindFirstChild("Map") or workspace

local PLOT_POSITIONS_224 = {
	{ plot = 1, x =   0, y = 3.5, z = -310 },
	{ plot = 2, x =  40, y = 3.5, z = -310 },
	{ plot = 3, x =  80, y = 3.5, z = -310 },
	{ plot = 4, x = 120, y = 3.5, z = -310 },
	{ plot = 5, x = 160, y = 3.5, z = -310 },
	{ plot = 6, x = 200, y = 3.5, z = -310 },
}

for _, info in PLOT_POSITIONS_224 do
	-- Find the plot folder and put the plaque there
	local plotFolder = map:FindFirstChild("Plot" .. info.plot) or map

	local plaque = Instance.new("Part")
	plaque.Name         = "PlotPlaque_" .. info.plot
	plaque.Size         = Vector3.new(0.15, 0.5, 1.6)
	plaque.Position     = Vector3.new(info.x, info.y, info.z)
	plaque.Anchored     = true
	plaque.CanCollide   = false
	plaque.Material     = Enum.Material.SmoothPlastic
	plaque.Color        = Color3.fromRGB(60, 35, 15)   -- dark wood
	plaque.CastShadow   = false
	plaque.Parent       = plotFolder

	-- CollectionService tag for client to find
	game:GetService("CollectionService"):AddTag(plaque, "PlotPlaque")
	plaque:SetAttribute("PlotIndex", info.plot)

	local bg = Instance.new("BillboardGui")
	bg.Name          = "PlaqueGui"
	bg.Size          = UDim2.new(0, 200, 0, 48)
	bg.StudsOffset   = Vector3.new(0.1, 0, 0)
	bg.AlwaysOnTop   = false
	bg.ResetOnSpawn  = false
	bg.Parent        = plaque

	local frame = Instance.new("Frame")
	frame.Name                   = "PlaqueFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = Color3.fromRGB(30, 18, 8)
	frame.BackgroundTransparency = 0.10
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "PlaqueStroke"
	stroke.Color     = Color3.fromRGB(120, 80, 30)
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name                   = "OwnerLabel"
	nameLbl.Size                   = UDim2.new(1, -6, 0.58, 0)
	nameLbl.Position               = UDim2.new(0, 3, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text                   = "🐝 Empty Plot"
	nameLbl.TextSize               = 12
	nameLbl.Font                   = Enum.Font.GothamBold
	nameLbl.TextColor3             = Color3.fromRGB(150, 120, 80)
	nameLbl.TextXAlignment         = Enum.TextXAlignment.Center
	nameLbl.TextTruncate           = Enum.TextTruncate.AtEnd
	nameLbl.ZIndex                 = 2
	nameLbl.Parent                 = frame

	local tierLbl = Instance.new("TextLabel")
	tierLbl.Name                   = "TierLabel"
	tierLbl.Size                   = UDim2.new(1, -6, 0.38, 0)
	tierLbl.Position               = UDim2.new(0, 3, 0.60, 0)
	tierLbl.BackgroundTransparency = 1
	tierLbl.Text                   = "Plot " .. info.plot
	tierLbl.TextSize               = 9
	tierLbl.Font                   = Enum.Font.Gotham
	tierLbl.TextColor3             = Color3.fromRGB(120, 90, 50)
	tierLbl.TextXAlignment         = Enum.TextXAlignment.Center
	tierLbl.ZIndex                 = 2
	tierLbl.Parent                 = frame
end

print("Plot plaques built: 6")
local count = 0
for _, p in workspace:GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count)
```

**Part count:** 6 plaque BaseParts (one per plot), all Anchored=true, CanCollide=false, tagged `PlotPlaque`.

---

## Step 2 — PlotPlaqueController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PlotPlaqueController`.

Paste exactly:

```lua
--!strict
-- PlotPlaqueController: updates plot name plaques with owner name + tier badge.
-- Reads PlotOwner + PlotCellCount attributes from PlotPlaque-tagged parts.
-- Set by PlotService (server) when a player claims / releases a plot.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_224 = 8.0

-- ── Palette ───────────────────────────────────────────────────────────────────
local OCCUPIED_224  = Color3.fromRGB(232, 212, 154)   -- wax cream for other players
local SELF_224      = Color3.fromRGB(255, 220,  80)   -- bright gold for own plot
local EMPTY_224     = Color3.fromRGB(150, 120,  80)   -- muted for unclaimed
local HONEY_224     = Color3.fromRGB(242, 168,  28)
local STROKE_MINE_224  = Color3.fromRGB(242, 168,  28)
local STROKE_OTHER_224 = Color3.fromRGB(120,  80,  30)

-- ── Tier labels ───────────────────────────────────────────────────────────────
local function getTierLabel_224(cellCount: number): string
	if cellCount >= 60 then return "⭐ Master Beekeeper"
	elseif cellCount >= 36 then return "⭐ Expert Beekeeper"
	elseif cellCount >= 18 then return "🌟 Apprentice Beekeeper"
	elseif cellCount >= 1  then return "🐣 Starter Beekeeper"
	else                        return "Plot " .. "?" end
end

-- ── Update single plaque ──────────────────────────────────────────────────────
local function updatePlaque_224(plaque: BasePart)
	local plotIndex = (plaque:GetAttribute("PlotIndex") :: number?) or 0
	local ownerName = (plaque:GetAttribute("PlotOwner") :: string?) or ""
	local cellCount = (plaque:GetAttribute("PlotCellCount") :: number?) or 0

	local bg = plaque:FindFirstChild("PlaqueGui") :: BillboardGui?
	local frame = bg and bg:FindFirstChild("PlaqueFrame") :: Frame?
	local nameLbl  = frame and frame:FindFirstChild("OwnerLabel")  :: TextLabel?
	local tierLbl  = frame and frame:FindFirstChild("TierLabel")   :: TextLabel?
	local stroke   = frame and frame:FindFirstChild("PlaqueStroke") :: UIStroke?

	if not nameLbl or not tierLbl then return end

	local isMine = (ownerName == localPlayer.Name)

	if ownerName == "" then
		-- Unclaimed
		nameLbl.Text       = "🐝 Empty Plot"
		nameLbl.TextColor3 = EMPTY_224
		tierLbl.Text       = "Plot " .. tostring(plotIndex)
		tierLbl.TextColor3 = EMPTY_224
		if stroke then stroke.Color = STROKE_OTHER_224 end
	elseif isMine then
		nameLbl.Text       = "🐝 " .. ownerName .. " (You)"
		nameLbl.TextColor3 = SELF_224
		tierLbl.Text       = getTierLabel_224(cellCount)
		tierLbl.TextColor3 = HONEY_224
		if stroke then stroke.Color = STROKE_MINE_224 end
	else
		nameLbl.Text       = "🐝 " .. ownerName
		nameLbl.TextColor3 = OCCUPIED_224
		tierLbl.Text       = getTierLabel_224(cellCount)
		tierLbl.TextColor3 = OCCUPIED_224
		if stroke then stroke.Color = STROKE_OTHER_224 end
	end
end

-- ── Setup plaque ──────────────────────────────────────────────────────────────
local function setupPlaque_224(plaque: BasePart)
	updatePlaque_224(plaque)
	plaque:GetAttributeChangedSignal("PlotOwner"):Connect(function()
		updatePlaque_224(plaque)
	end)
	plaque:GetAttributeChangedSignal("PlotCellCount"):Connect(function()
		updatePlaque_224(plaque)
	end)
end

-- ── Safety scan ───────────────────────────────────────────────────────────────
local scanAcc_224 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_224 += dt
	if scanAcc_224 < SCAN_INTERVAL_224 then return end
	scanAcc_224 = 0
	for _, plaque in CollectionService:GetTagged("PlotPlaque") do
		if plaque:IsA("BasePart") then
			updatePlaque_224(plaque)
		end
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	for _, plaque in CollectionService:GetTagged("PlotPlaque") do
		if plaque:IsA("BasePart") then
			setupPlaque_224(plaque)
		end
	end
	CollectionService:GetInstanceAddedSignal("PlotPlaque"):Connect(function(inst)
		if inst:IsA("BasePart") then
			task.delay(0.2, function()
				setupPlaque_224(inst)
			end)
		end
	end)
end)
```

---

## Step 3 — PlotService attribute writes

Open **ServerScriptService → Systems → PlotService**. When a player claims a plot, write attributes to the `PlotPlaque_N` part so PlotPlaqueController can display the owner:

```lua
-- In PlotService, when a player is assigned to a plot:
local function updatePlaqueAttrs_224(plotIndex: number, ownerName: string, cellCount: number)
	local CS = game:GetService("CollectionService")
	for _, plaque in CS:GetTagged("PlotPlaque") do
		if plaque:IsA("BasePart") and plaque:GetAttribute("PlotIndex") == plotIndex then
			plaque:SetAttribute("PlotOwner",     ownerName)
			plaque:SetAttribute("PlotCellCount", cellCount)
		end
	end
end

-- Call on plot claim:
updatePlaqueAttrs_224(plotIndex, player.Name, currentCellCount)

-- Call on plot release (player leaves / disconnects):
updatePlaqueAttrs_224(plotIndex, "", 0)
```

Also write `PlotCellCount` whenever a cell is built or destroyed on this plot:

```lua
-- After building/destroying a cell, update the plaque cell count:
local cellCount = 0
for _, cell in plotModel:GetDescendants() do
	if game:GetService("CollectionService"):HasTag(cell, "HiveCell") then
		cellCount += 1
	end
end
updatePlaqueAttrs_224(plotIndex, player.Name, cellCount)
```

---

## Step 4 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PlotPlaqueController"))
```

---

## Step 5 — Verification sweep

Run in **Studio Command Bar** (Edit mode):

```lua
local CS = game:GetService("CollectionService")
local plaques = CS:GetTagged("PlotPlaque")
print("PlotPlaque tagged:", #plaques, "(expect 6)")
for _, p in plaques do
	print(" ", p.Name, "PlotIndex=", p:GetAttribute("PlotIndex"))
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

**Quick-test in Play mode:**

```lua
-- Set a plaque to show an owner
local CS = game:GetService("CollectionService")
local plaques = CS:GetTagged("PlotPlaque")
if plaques[1] then
	plaques[1]:SetAttribute("PlotOwner", "TestBeekeeper")
	plaques[1]:SetAttribute("PlotCellCount", 25)
	-- Plaque 1 should now show "🐝 TestBeekeeper" + "🌟 Apprentice Beekeeper"
	task.wait(1)
	plaques[1]:SetAttribute("PlotOwner", "")
	-- Plaque should revert to "🐝 Empty Plot"
end
```

---

## Behaviour summary

| State | Name line | Tier line | Stroke |
|---|---|---|---|
| Unclaimed | 🐝 Empty Plot (muted) | Plot N (muted) | Dark brown |
| Owned by you | 🐝 [You] (You) — bright gold | ⭐ Master Beekeeper | Honey gold |
| Owned by other | 🐝 [Name] — wax cream | [tier] — wax cream | Dark brown |

- Tier thresholds: Starter (≥1 cell), Apprentice (≥18), Expert (≥36), Master (≥60)
- BillboardGui on 0.15-stud dark wood plaque Part — visible above Landing Board
- Reacts instantly to `PlotOwner` and `PlotCellCount` attribute changes
- 8s scan as safety net for missed signals
- No performance cost at 0 bees: `CollectionService:GetTagged("PlotPlaque")` returns 6 parts, trivial

**Part budget: +6 server-side permanent → 4,218 / 5,000**
*(6 PlotPlaque BaseParts, one per plot)*
