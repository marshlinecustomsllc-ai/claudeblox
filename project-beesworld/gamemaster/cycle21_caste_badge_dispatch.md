# Dispatch 212 — Bee Caste Badge
**File:** `cycle21_caste_badge_dispatch.md`
**Cycle:** 21
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture's three-caste bee workforce (Forager / Nurse / Guard) drives resource output, brood production, and raid defence. Players currently have no way to see their caste split at a glance without opening HiveGui. This dispatch adds a **Bee Caste Badge**: a compact persistent ScreenGui panel at the bottom-left of the screen that shows the live `F / N / G` count for each caste. Updates reactively on caste attribute changes. Sits above the PopCapController pill (dispatch 211) in the HUD stack. Entirely client-side — reads `ForagerCount`, `NurseCount`, and `GuardCount` player attributes.

For kids: three coloured dots with simple letters tell them what their bees are doing. For adults: the exact split lets them make strategic build decisions (more Brood Cells → more Nurses, more Guard Posts → more Guards).

---

## Step 1 — CasteBadgeController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `CasteBadgeController`.

Paste exactly:

```lua
--!strict
-- CasteBadgeController: compact HUD badge showing live Forager/Nurse/Guard caste split.
-- Reads ForagerCount, NurseCount, GuardCount player attributes.
-- Entirely client-side — zero server writes, zero new parts.

local Players     = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local FADE_TIME_212   = 0.20
local SCAN_INTERVAL_212 = 6.0

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_212     = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_212   = Color3.fromRGB(232, 212, 154)
local FORAGER_COL_212 = Color3.fromRGB(100, 200, 100)   -- green — out in the field
local NURSE_COL_212   = Color3.fromRGB(200, 160, 255)   -- soft purple — tending brood
local GUARD_COL_212   = Color3.fromRGB(255, 130,  50)   -- amber-orange — defensive

-- ── State ─────────────────────────────────────────────────────────────────────
local badgeGui_212: ScreenGui? = nil
local built_212 = false

-- ── Build badge ───────────────────────────────────────────────────────────────
local function buildBadge_212(): ScreenGui
	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return nil :: any end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "CasteBadge_212"
	sg.DisplayOrder   = 18
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Name                   = "BadgeFrame"
	frame.Size                   = UDim2.new(0, 144, 0, 30)
	frame.AnchorPoint            = Vector2.new(0, 1)
	frame.Position               = UDim2.new(0, 8, 1, -126)   -- above PopCap pill (-90) + spacing
	frame.BackgroundColor3       = DARK_BG_212
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = Color3.fromRGB(80, 60, 30)
	stroke.Thickness = 1
	stroke.Parent    = frame

	-- Three caste slots laid out horizontally
	local slots: { { color: Color3, letter: string, attr: string } } = {
		{ color = FORAGER_COL_212, letter = "F", attr = "ForagerCount" },
		{ color = NURSE_COL_212,   letter = "N", attr = "NurseCount"   },
		{ color = GUARD_COL_212,   letter = "G", attr = "GuardCount"   },
	}

	local slotW = 144 / 3
	for i, slot in ipairs(slots) do
		local col = Instance.new("Frame")
		col.Name                   = slot.attr   -- reuse attr name for lookup
		col.Size                   = UDim2.new(0, slotW - 2, 1, -4)
		col.Position               = UDim2.new(0, (i - 1) * slotW + 1, 0, 2)
		col.BackgroundTransparency = 1
		col.BorderSizePixel        = 0
		col.Parent                 = frame

		local dot = Instance.new("Frame")
		dot.Name                   = "Dot"
		dot.Size                   = UDim2.new(0, 7, 0, 7)
		dot.Position               = UDim2.new(0, 2, 0.5, -3)
		dot.BackgroundColor3       = slot.color
		dot.BackgroundTransparency = 0
		dot.BorderSizePixel        = 0
		dot.Parent                 = col

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent       = dot

		local lbl = Instance.new("TextLabel")
		lbl.Name               = "Count"
		lbl.Size               = UDim2.new(1, -12, 1, 0)
		lbl.Position           = UDim2.new(0, 12, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.Text               = slot.letter .. ": 0"
		lbl.TextSize           = 10
		lbl.Font               = Enum.Font.GothamBold
		lbl.TextColor3         = slot.color
		lbl.TextXAlignment     = Enum.TextXAlignment.Left
		lbl.ZIndex             = 2
		lbl.Parent             = col
	end

	return sg
end

-- ── Update counts ─────────────────────────────────────────────────────────────
local function updateCounts_212()
	if not badgeGui_212 then return end
	local frame = badgeGui_212:FindFirstChild("BadgeFrame")
	if not frame then return end

	local foragers = (player:GetAttribute("ForagerCount") :: number?) or 0
	local nurses   = (player:GetAttribute("NurseCount")   :: number?) or 0
	local guards   = (player:GetAttribute("GuardCount")   :: number?) or 0

	local values: { [string]: { count: number, letter: string } } = {
		ForagerCount = { count = foragers, letter = "F" },
		NurseCount   = { count = nurses,   letter = "N" },
		GuardCount   = { count = guards,   letter = "G" },
	}

	for attrName, data in values do
		local col = frame:FindFirstChild(attrName)
		if col then
			local lbl = col:FindFirstChild("Count") :: TextLabel?
			if lbl then
				lbl.Text = data.letter .. ": " .. tostring(data.count)
			end
		end
	end
end

-- ── Show badge ────────────────────────────────────────────────────────────────
local function showBadge_212()
	if built_212 then return end
	built_212 = true
	badgeGui_212 = buildBadge_212()
	if not badgeGui_212 then return end
	updateCounts_212()

	local frame = badgeGui_212:FindFirstChild("BadgeFrame")
	if frame then
		frame.BackgroundTransparency = 1
		TweenService:Create(frame, TweenInfo.new(FADE_TIME_212, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 0.18,
		}):Play()
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3.5, function()
	showBadge_212()

	player:GetAttributeChangedSignal("ForagerCount"):Connect(updateCounts_212)
	player:GetAttributeChangedSignal("NurseCount"):Connect(updateCounts_212)
	player:GetAttributeChangedSignal("GuardCount"):Connect(updateCounts_212)

	local acc = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= SCAN_INTERVAL_212 then
			acc = 0
			updateCounts_212()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("CasteBadgeController"))
```

---

## Step 3 — Attribute source (PopulationService)

`CasteBadgeController` reads three player attributes:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `ForagerCount` | number | PopulationService | Live count of Forager-caste bees |
| `NurseCount` | number | PopulationService | Live count of Nurse-caste bees |
| `GuardCount` | number | PopulationService | Live count of Guard-caste bees |

These should be set alongside `CurrentBees` and `MaxBees` after each hatch/death event in PopulationService:

```lua
-- In PopulationService, after population changes:
player:SetAttribute("ForagerCount", foragerTotal)
player:SetAttribute("NurseCount",   nurseTotal)
player:SetAttribute("GuardCount",   guardTotal)
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("CasteBadgeController")
print("CasteBadgeController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildBadge_212:", c.Source:find("buildBadge_212") ~= nil)
	print("  updateCounts_212:", c.Source:find("updateCounts_212") ~= nil)
	print("  ForagerCount attr:", c.Source:find("ForagerCount") ~= nil)
	print("  NurseCount attr:", c.Source:find("NurseCount") ~= nil)
	print("  GuardCount attr:", c.Source:find("GuardCount") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
local lp = game:GetService("Players").LocalPlayer
-- Set initial caste counts
lp:SetAttribute("ForagerCount", 12)
lp:SetAttribute("NurseCount", 5)
lp:SetAttribute("GuardCount", 3)
task.wait(1)
-- Update mid-game
lp:SetAttribute("ForagerCount", 18)
task.wait(1)
-- Nurse surge after Brood Cell built
lp:SetAttribute("NurseCount", 9)
```

**Expected output:**
```
CasteBadgeController: LocalScript
  lines: 120+
  buildBadge_212: true
  updateCounts_212: true
  ForagerCount attr: true
  NurseCount attr: true
  GuardCount attr: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Element | Colour | Meaning |
|---|---|---|
| F dot + label | Green (100,200,100) | Foragers — out gathering pollen/nectar |
| N dot + label | Soft purple (200,160,255) | Nurses — tending brood cells |
| G dot + label | Amber-orange (255,130,50) | Guards — defending hive from wasps/bear |

- Badge sits 126px from bottom (above PopCap pill at 90px, with 36px spacing)
- DisplayOrder=18 — below PopCap pill (19) and below main HUD
- Always visible once shown — no hide condition (caste info is always relevant)
- Updates in-place on every attribute change — no rebuild, no flicker
- Fade-in 0.20s on first appearance — smooth entry
- Coloured dots are immediately legible at a glance without reading text
- The count "F: 12" gives adults the precision; the green dot gives kids the signal

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(ScreenGui only — no BaseParts)*
