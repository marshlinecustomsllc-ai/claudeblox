# Dispatch 207 — Comb Cell Hover Tooltip
**File:** `cycle20_cell_hover_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Built comb cells sit on the grid but show no information unless the player opens HiveGui. Adults who want to optimise their layout need to quickly check individual cell types, tiers, and output rates without navigating menus. This dispatch adds a **Comb Cell Hover Tooltip**: a BillboardGui that fades in when the player's character moves within 7 studs of any `CombCell`-tagged BasePart, shows cell type icon, tier badge, and the cell's current output rate, then fades out when the player moves away. Only one tooltip is visible at a time — the closest cell wins. Entirely client-side, zero server writes.

---

## Step 1 — CellHoverController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `CellHoverController`.

Paste exactly:

```lua
--!strict
-- CellHoverController: proximity fade-in tooltip on CombCell parts.
-- Shows cell type, tier, and output rate when player walks within HOVER_RADIUS_207 studs.
-- Only the closest cell shows at any time. Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player     = Players.LocalPlayer
local character  = player.Character or player.CharacterAdded:Wait()
local humanoidRP = character:WaitForChild("HumanoidRootPart") :: BasePart

player.CharacterAdded:Connect(function(char)
	character  = char
	humanoidRP = char:WaitForChild("HumanoidRootPart") :: BasePart
end)

-- ── Config ────────────────────────────────────────────────────────────────────
local HOVER_RADIUS_207    = 7.0    -- studs — tooltip appears within this range
local LABEL_OFFSET_207    = Vector3.new(0, 2.8, 0)
local FADE_IN_TIME_207    = 0.18
local FADE_OUT_TIME_207   = 0.22
local POLL_INTERVAL_207   = 0.12   -- seconds between proximity checks

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_207    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_207  = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD_207 = Color3.fromRGB(242, 168,  28)
local AMBER_207      = Color3.fromRGB(220, 130,  20)
local DIM_207        = Color3.fromRGB(160, 140, 100)

-- ── Cell type display data ────────────────────────────────────────────────────
local CELL_ICONS_207: { [string]: string } = {
	Honey       = "🍯",
	Brood       = "🐛",
	Pollen      = "🌼",
	Royal       = "👑",
	Propolis    = "🔶",
	DanceFloor  = "💃",
	Reinforced  = "🛡",
	Golden      = "✨",
	Wax         = "🔷",
}

local CELL_LABELS_207: { [string]: string } = {
	Honey       = "Honey Cell",
	Brood       = "Brood Cell",
	Pollen      = "Pollen Cell",
	Royal       = "Royal Cell",
	Propolis    = "Propolis Cell",
	DanceFloor  = "Dance Floor",
	Reinforced  = "Reinforced Cell",
	Golden      = "Golden Cell",
	Wax         = "Wax Cell",
}

-- ── State ─────────────────────────────────────────────────────────────────────
local shownPart_207: BasePart? = nil
local tooltip_207:  BillboardGui? = nil
local fadeConn_207: Tween? = nil

-- ── Build tooltip gui ─────────────────────────────────────────────────────────
local function buildTooltip_207(part: BasePart): BillboardGui
	local cellType = (part:GetAttribute("CellType") :: string?) or "Wax"
	local tier     = (part:GetAttribute("Tier") :: number?) or 1
	local rate     = (part:GetAttribute("OutputRate") :: number?)

	local icon  = CELL_ICONS_207[cellType] or "⬡"
	local label = CELL_LABELS_207[cellType] or cellType
	local tierStr = "T" .. tostring(tier)

	local rateStr: string
	if rate and rate > 0 then
		rateStr = string.format("%.1f/s", rate)
	else
		rateStr = ""
	end

	local bg = Instance.new("BillboardGui")
	bg.Name           = "CellTooltip_207"
	bg.Size           = UDim2.new(0, 110, 0, 42)
	bg.StudsOffset    = LABEL_OFFSET_207
	bg.AlwaysOnTop    = false
	bg.ResetOnSpawn   = false
	bg.Parent         = part

	local frame = Instance.new("Frame")
	frame.Name                   = "TipFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_207
	frame.BackgroundTransparency = 0.0   -- starts visible, parent BG transparency drives fade
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = AMBER_207
	stroke.Thickness = 1
	stroke.Parent    = frame

	-- Top row: icon + cell name
	local topRow = Instance.new("TextLabel")
	topRow.Name               = "TopRow"
	topRow.Size               = UDim2.new(1, -6, 0.52, 0)
	topRow.Position           = UDim2.new(0, 3, 0, 0)
	topRow.BackgroundTransparency = 1
	topRow.Text               = icon .. "  " .. label
	topRow.TextSize           = 11
	topRow.Font               = Enum.Font.GothamBold
	topRow.TextColor3         = WAX_CREAM_207
	topRow.TextXAlignment     = Enum.TextXAlignment.Left
	topRow.ZIndex             = 2
	topRow.Parent             = frame

	-- Bottom row: tier badge + rate
	local botRow = Instance.new("TextLabel")
	botRow.Name               = "BotRow"
	botRow.Size               = UDim2.new(1, -6, 0.40, 0)
	botRow.Position           = UDim2.new(0, 3, 0.55, 0)
	botRow.BackgroundTransparency = 1
	botRow.Text               = tierStr .. (rateStr ~= "" and ("   " .. rateStr) or "")
	botRow.TextSize           = 10
	botRow.Font               = Enum.Font.Gotham
	botRow.TextColor3         = rateStr ~= "" and HONEY_GOLD_207 or DIM_207
	botRow.TextXAlignment     = Enum.TextXAlignment.Left
	botRow.ZIndex             = 2
	botRow.Parent             = frame

	-- Start fully transparent; fade-in will open it
	bg.MaxDistance = HOVER_RADIUS_207 + 4

	return bg
end

-- ── Fade helpers ─────────────────────────────────────────────────────────────
local function fadeIn_207(bg: BillboardGui)
	if fadeConn_207 then fadeConn_207:Cancel() end
	local frame = bg:FindFirstChildOfClass("Frame")
	if not frame then return end
	frame.BackgroundTransparency = 1.0
	for _, label in frame:GetDescendants() do
		if label:IsA("TextLabel") then
			label.TextTransparency = 1.0
		end
	end
	local stroke = frame:FindFirstChildOfClass("UIStroke")

	local tweens: { Tween } = {}
	table.insert(tweens, TweenService:Create(frame, TweenInfo.new(FADE_IN_TIME_207, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 0.15,
	}))
	for _, label in frame:GetDescendants() do
		if label:IsA("TextLabel") then
			table.insert(tweens, TweenService:Create(label, TweenInfo.new(FADE_IN_TIME_207, Enum.EasingStyle.Sine), {
				TextTransparency = 0,
			}))
		end
	end
	for _, t in tweens do t:Play() end
end

local function fadeOut_207(bg: BillboardGui, onDone: () -> ())
	if fadeConn_207 then fadeConn_207:Cancel() end
	local frame = bg:FindFirstChildOfClass("Frame")
	if not frame then onDone() return end

	local tweens: { Tween } = {}
	table.insert(tweens, TweenService:Create(frame, TweenInfo.new(FADE_OUT_TIME_207, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 1.0,
	}))
	for _, label in frame:GetDescendants() do
		if label:IsA("TextLabel") then
			table.insert(tweens, TweenService:Create(label, TweenInfo.new(FADE_OUT_TIME_207, Enum.EasingStyle.Sine), {
				TextTransparency = 1,
			}))
		end
	end
	local last: Tween? = tweens[1]
	for _, t in tweens do t:Play() end
	if last then
		fadeConn_207 = last
		last.Completed:Connect(onDone)
	else
		onDone()
	end
end

-- ── Show tooltip on a part ────────────────────────────────────────────────────
local function showTooltip_207(part: BasePart)
	if shownPart_207 == part then return end

	-- Dismiss current tooltip first
	if tooltip_207 and tooltip_207.Parent then
		local old = tooltip_207
		tooltip_207  = nil
		shownPart_207 = nil
		fadeOut_207(old, function()
			if old.Parent then old:Destroy() end
		end)
	end

	shownPart_207 = part
	local bg = buildTooltip_207(part)
	tooltip_207 = bg
	fadeIn_207(bg)
end

-- ── Hide tooltip ──────────────────────────────────────────────────────────────
local function hideTooltip_207()
	if not tooltip_207 then shownPart_207 = nil return end
	local old = tooltip_207
	tooltip_207  = nil
	shownPart_207 = nil
	fadeOut_207(old, function()
		if old.Parent then old:Destroy() end
	end)
end

-- ── Proximity poll ────────────────────────────────────────────────────────────
local pollAcc_207 = 0
RunService.Heartbeat:Connect(function(dt: number)
	pollAcc_207 += dt
	if pollAcc_207 < POLL_INTERVAL_207 then return end
	pollAcc_207 = 0

	if not humanoidRP or not humanoidRP.Parent then return end
	local myPos = humanoidRP.Position

	local closest: BasePart? = nil
	local closestDist = HOVER_RADIUS_207

	for _, obj in CollectionService:GetTagged("CombCell") do
		if obj:IsA("BasePart") and obj.Parent then
			local d = (obj.Position - myPos).Magnitude
			if d < closestDist then
				closestDist = d
				closest = obj
			end
		end
	end

	if closest then
		showTooltip_207(closest)
	else
		if shownPart_207 then
			hideTooltip_207()
		end
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("CellHoverController"))
```

---

## Step 3 — Attribute source (CombService)

`CellHoverController` reads three attributes from `CombCell` BaseParts:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `CellType` | string | CombService | e.g. "Honey", "Brood", "Pollen", "Royal" |
| `Tier` | number | CombService | 1-5 |
| `OutputRate` | number | ResourceService | Optional; live output per second; 0 if idle |

`CellType` and `Tier` are already written by CombService when a cell is placed (dispatch 10 / cycle10). `OutputRate` is optional — if ResourceService doesn't write it yet the tooltip shows the tier badge without a rate number, which is still useful.

To add OutputRate in ResourceService:

```lua
-- In ResourceService, after each production tick for a cell:
local cellPart = -- (the CombCell BasePart for this cell)
if cellPart then
    cellPart:SetAttribute("OutputRate", currentOutputPerSecond)
end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("CellHoverController")
print("CellHoverController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildTooltip_207:", c.Source:find("buildTooltip_207") ~= nil)
	print("  showTooltip_207:", c.Source:find("showTooltip_207") ~= nil)
	print("  hideTooltip_207:", c.Source:find("hideTooltip_207") ~= nil)
	print("  HOVER_RADIUS_207:", c.Source:find("HOVER_RADIUS_207") ~= nil)
	print("  CombCell tag:", c.Source:find("CombCell") ~= nil)
end

local CS = game:GetService("CollectionService")
local cells = CS:GetTagged("CombCell")
print("CombCell tagged parts:", #cells, "(0 in Edit mode — placed during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Manually tag a DimCellPlate to simulate a built CombCell
local CS = game:GetService("CollectionService")
local plates = CS:GetTagged("DimCellPlate")
if plates[1] then
	plates[1]:SetAttribute("CellType", "Honey")
	plates[1]:SetAttribute("Tier", 2)
	plates[1]:SetAttribute("OutputRate", 3.4)
	CS:AddTag(plates[1], "CombCell")
	print("Tagged as CombCell:", plates[1]:GetFullName())
	-- Walk within 7 studs to see tooltip
end
```

**Expected output:**
```
CellHoverController: LocalScript
  lines: 180+
  buildTooltip_207: true
  showTooltip_207: true
  hideTooltip_207: true
  HOVER_RADIUS_207: true
  CombCell tag: true
CombCell tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Situation | Effect |
|---|---|
| Player moves within 7 studs of any CombCell | Tooltip fades in (0.18s) above the closest cell |
| Multiple cells in range | Closest wins — only one tooltip visible at a time |
| Player moves away | Tooltip fades out (0.22s), destroyed |
| Different cell enters range | Old tooltip fades out, new one fades in |
| `OutputRate` attribute not set | Tooltip shows icon + name + tier badge only (no rate line) |

Tooltip layout (110×42px):
```
🍯  Honey Cell
T2    3.4/s
```

- Top row: cell type icon + name (WAX_CREAM text, GothamBold 11pt)
- Bottom row: tier badge + output rate (HONEY_GOLD if rate > 0, DIM otherwise)
- DARK_BG background with AMBER UIStroke, UICorner r=7
- No click target — purely informational, no interference with ProximityPrompts
- 0.12s poll interval (8 FPS proximity check) — fast enough to feel responsive, cheap enough on mobile

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(CellTooltip_207 BillboardGui is a client-only GuiObject parented to the cell — not a BasePart; destroyed on fade-out)*
