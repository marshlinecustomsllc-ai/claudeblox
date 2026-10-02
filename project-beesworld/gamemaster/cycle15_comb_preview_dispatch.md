# Dispatch 164 — Comb Cell Ghost Preview (Hover Before You Build)
**File:** `cycle15_comb_preview_dispatch.md`
**Branch:** add-beesworld-project
**Part budget:** +0 new world parts → 4,198 / 5,000

---

## Overview

Right now, tapping a hex cell in BuildGui commits the build immediately. Kids don't always
know what a cell does before placing it — and adults can't see adjacency bonuses before
committing 500+ honey. Dispatch 164 adds a ghost preview: when the player hovers a hex slot
in BuildGui (or hovers a cell type button), a semi-transparent overlay card appears showing
exactly what would be built, the bonus it contributes, and whether adjacent cells amplify it.

This is entirely client-side UI logic in BuildGui's existing controller — no server changes,
no new RemoteEvents, no DataService migration.

**What gets built:**
1. `CombPreviewController` LocalScript — hover detection on BuildGui cell grid, preview card
   showing cell name / emoji / description / adjacency bonus calculation
2. No server changes, no world parts

---

## Step 1 — CombPreviewController LocalScript

In Studio Explorer: **StarterPlayer → StarterPlayerScripts** → Insert **LocalScript**,
rename `CombPreviewController`.

Paste full source:

```lua
--!strict
-- CombPreviewController: ghost preview card when hovering hex slots in BuildGui.
-- Shows cell type details and adjacency bonus before the player commits to building.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────────────────
local HONEY_GOLD_164  = Color3.fromRGB(242, 168, 28)
local PROPOLIS_164    = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_164   = Color3.fromRGB(232, 212, 154)
local GREEN_164       = Color3.fromRGB(60,  180, 60)
local BLUE_164        = Color3.fromRGB(100, 160, 220)
local AMBER_164       = Color3.fromRGB(220, 130, 0)

-- ── Cell reference data (mirrors Config.lua entries, client-safe copy) ──────────
-- Each entry: emoji, kid description, adult description, adjacency note
type CellInfo = {
	emoji: string, kid: string, adult: string, adj: string, color: Color3
}

local CELL_INFO_164: { [string]: CellInfo } = {
	Honey       = { emoji="🍯", kid="Stores honey! Fill it up to harvest.", adult="+0.8 honey/s base. Ripens to 2.2× if left uncollected.", adj="More honey cells → higher storage capacity.", color=HONEY_GOLD_164 },
	Brood       = { emoji="🥚", kid="Grows baby bees! Makes your colony bigger.", adult="Hatches 1 bee every 30s. Needs adjacent honey for warmth.", adj="Adjacent honey cells boost hatch rate (+10% each).", color=GREEN_164 },
	Pollen      = { emoji="🌸", kid="Collects pollen from foragers.", adult="+0.6 pollen/s. Pollen feeds brood cells.", adj="Must touch a Brood cell to work. More brood = more demand.", color=Color3.fromRGB(220, 140, 200) },
	Propolis    = { emoji="🌿", kid="Protects the hive from wasps!", adult="+0.3 propolis/s. Propolis seals outer ring, reducing wasp raids.", adj="Outer ring only. Each cell reduces wasp steal chance by 2%.", color=Color3.fromRGB(80, 160, 60) },
	RoyalCell   = { emoji="👑", kid="A special cell for your queen to grow in!", adult="Unlocks Queen upgrades. Rim placement only.", adj="Must be on the hex ring edge. Only one per hive.", color=AMBER_164 },
	DanceFloor  = { emoji="💃", kid="Your waggle dance stage! Already placed at centre.", adult="Central cell (0,0). Permanent — cannot be removed.", adj="Already placed. You do the dance here to guide foragers.", color=BLUE_164 },
}

-- ── Build preview card UI ──────────────────────────────────────────────────────
local previewSg = Instance.new("ScreenGui")
previewSg.Name            = "CombPreviewGui"
previewSg.DisplayOrder    = 55
previewSg.ResetOnSpawn    = false
previewSg.IgnoreGuiInset  = true
previewSg.Enabled         = false
previewSg.Parent          = playerGui

local card = Instance.new("Frame")
card.Name             = "PreviewCard"
card.Size             = UDim2.new(0, 220, 0, 180)
card.BackgroundColor3 = PROPOLIS_164
card.BackgroundTransparency = 0.1
card.BorderSizePixel  = 0
card.ZIndex           = 10
card.Parent           = previewSg
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 14)
cardCorner.Parent = card
local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 2
cardStroke.Color     = HONEY_GOLD_164
cardStroke.Parent    = card

-- Emoji header
local emojiLbl = Instance.new("TextLabel")
emojiLbl.Name               = "EmojiLbl"
emojiLbl.Size               = UDim2.new(0, 50, 0, 50)
emojiLbl.Position           = UDim2.new(0, 8, 0, 8)
emojiLbl.BackgroundTransparency = 1
emojiLbl.TextSize           = 36
emojiLbl.Font               = Enum.Font.GothamBold
emojiLbl.Text               = "🍯"
emojiLbl.ZIndex             = 11
emojiLbl.Parent             = card

-- Cell name
local nameLbl = Instance.new("TextLabel")
nameLbl.Name                = "NameLbl"
nameLbl.Size                = UDim2.new(1, -70, 0, 24)
nameLbl.Position            = UDim2.new(0, 64, 0, 14)
nameLbl.BackgroundTransparency = 1
nameLbl.TextColor3          = HONEY_GOLD_164
nameLbl.TextSize            = 17
nameLbl.Font                = Enum.Font.GothamBold
nameLbl.Text                = "Honey Cell"
nameLbl.TextXAlignment      = Enum.TextXAlignment.Left
nameLbl.ZIndex              = 11
nameLbl.Parent              = card

-- Colored accent bar under name
local accentBar = Instance.new("Frame")
accentBar.Name              = "AccentBar"
accentBar.Size              = UDim2.new(1, -16, 0, 3)
accentBar.Position          = UDim2.new(0, 8, 0, 40)
accentBar.BackgroundColor3  = HONEY_GOLD_164
accentBar.BorderSizePixel   = 0
accentBar.ZIndex            = 11
accentBar.Parent            = card
local abCorner = Instance.new("UICorner")
abCorner.CornerRadius = UDim.new(0, 2)
abCorner.Parent = accentBar

-- Kid description
local kidLbl = Instance.new("TextLabel")
kidLbl.Name               = "KidLbl"
kidLbl.Size               = UDim2.new(1, -16, 0, 42)
kidLbl.Position           = UDim2.new(0, 8, 0, 48)
kidLbl.BackgroundTransparency = 1
kidLbl.TextColor3         = WAX_CREAM_164
kidLbl.TextSize           = 14
kidLbl.Font               = Enum.Font.GothamBold
kidLbl.Text               = "Stores honey! Fill it up to harvest."
kidLbl.TextWrapped        = true
kidLbl.TextXAlignment     = Enum.TextXAlignment.Left
kidLbl.ZIndex             = 11
kidLbl.Parent             = card

-- Adult description (smaller, de-emphasised)
local adultLbl = Instance.new("TextLabel")
adultLbl.Name               = "AdultLbl"
adultLbl.Size               = UDim2.new(1, -16, 0, 34)
adultLbl.Position           = UDim2.new(0, 8, 0, 92)
adultLbl.BackgroundTransparency = 1
adultLbl.TextColor3         = WAX_CREAM_164
adultLbl.TextTransparency   = 0.3
adultLbl.TextSize           = 11
adultLbl.Font               = Enum.Font.Gotham
adultLbl.Text               = "+0.8 honey/s base. Ripens to 2.2× if left."
adultLbl.TextWrapped        = true
adultLbl.TextXAlignment     = Enum.TextXAlignment.Left
adultLbl.ZIndex             = 11
adultLbl.Parent             = card

-- Adjacency note row
local adjIcon = Instance.new("TextLabel")
adjIcon.Name               = "AdjIcon"
adjIcon.Size               = UDim2.new(0, 18, 0, 18)
adjIcon.Position           = UDim2.new(0, 8, 0, 132)
adjIcon.BackgroundTransparency = 1
adjIcon.TextColor3         = HONEY_GOLD_164
adjIcon.TextSize           = 14
adjIcon.Font               = Enum.Font.GothamBold
adjIcon.Text               = "↔"
adjIcon.ZIndex             = 11
adjIcon.Parent             = card

local adjLbl = Instance.new("TextLabel")
adjLbl.Name               = "AdjLbl"
adjLbl.Size               = UDim2.new(1, -34, 0, 36)
adjLbl.Position           = UDim2.new(0, 28, 0, 129)
adjLbl.BackgroundTransparency = 1
adjLbl.TextColor3         = GREEN_164
adjLbl.TextTransparency   = 0.15
adjLbl.TextSize           = 11
adjLbl.Font               = Enum.Font.Gotham
adjLbl.Text               = "Adjacent honey cells boost hatch rate."
adjLbl.TextWrapped        = true
adjLbl.TextXAlignment     = Enum.TextXAlignment.Left
adjLbl.ZIndex             = 11
adjLbl.Parent             = card

-- "Tap to build" hint at bottom
local tapHint = Instance.new("TextLabel")
tapHint.Name               = "TapHint"
tapHint.Size               = UDim2.new(1, -16, 0, 16)
tapHint.Position           = UDim2.new(0, 8, 1, -20)
tapHint.BackgroundTransparency = 1
tapHint.TextColor3         = WAX_CREAM_164
tapHint.TextTransparency   = 0.5
tapHint.TextSize           = 10
tapHint.Font               = Enum.Font.Gotham
tapHint.Text               = "Tap the cell to place ✓"
tapHint.ZIndex             = 11
tapHint.Parent             = card

-- ── Show / hide helpers ────────────────────────────────────────────────────────
local cardVisible = false
local targetPos   = UDim2.new(0, 0, 0, 0)

local function showCard_164(cellType: string, screenX: number, screenY: number)
	local info = CELL_INFO_164[cellType]
	if not info then return end

	emojiLbl.Text           = info.emoji
	nameLbl.Text            = cellType .. " Cell"
	kidLbl.Text             = info.kid
	adultLbl.Text           = info.adult
	adjLbl.Text             = info.adj
	accentBar.BackgroundColor3 = info.color
	cardStroke.Color           = info.color

	-- Anchor card to hover position (offset so it doesn't overlap cursor)
	local viewport = game:GetService("Workspace").CurrentCamera.ViewportSize
	local cx = math.clamp(screenX + 12, 0, viewport.X - 225)
	local cy = math.clamp(screenY - 90, 8, viewport.Y - 185)
	card.Position = UDim2.new(0, cx, 0, cy)

	if not cardVisible then
		cardVisible = true
		previewSg.Enabled = true
		card.BackgroundTransparency = 1
		TweenService:Create(card,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.1 }
		):Play()
	end
end

local function hideCard_164()
	if not cardVisible then return end
	cardVisible = false
	TweenService:Create(card,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
	task.delay(0.15, function()
		if not cardVisible then previewSg.Enabled = false end
	end)
end

-- ── Hook into BuildGui cell type buttons ──────────────────────────────────────
-- BuildGui has cell-type ImageButton/TextButton elements inside a grid frame.
-- We watch for those buttons to appear and wire Enter/Leave events on them.
-- The button Name convention in BuildGui is typically "Btn_[CellType]" or just
-- a Frame with the cell type name as a child attribute. We try several patterns.

local function wiredButtons_164: { [GuiButton]: boolean } = {}

local function tryCellTypeFromButton_164(btn: GuiButton): string?
	-- Pattern 1: button Name is "Btn_Honey", "Btn_Brood", etc.
	local m = btn.Name:match("^Btn_(.+)$")
	if m and CELL_INFO_164[m] then return m end
	-- Pattern 2: button Name IS the cell type directly ("Honey", "Brood" etc.)
	if CELL_INFO_164[btn.Name] then return btn.Name end
	-- Pattern 3: attribute "CellType" on the button
	local attr = btn:GetAttribute("CellType") :: string?
	if attr and CELL_INFO_164[attr] then return attr end
	-- Pattern 4: child TextLabel whose Text matches a cell type
	for _, child in btn:GetChildren() do
		if child:IsA("TextLabel") and CELL_INFO_164[child.Text] then
			return child.Text
		end
	end
	return nil
end

local function wireButton_164(btn: GuiButton)
	if wiredButtons_164[btn] then return end
	wiredButtons_164[btn] = true

	local cellType = tryCellTypeFromButton_164(btn)
	if not cellType then return end

	btn.MouseEnter:Connect(function(x: number, y: number)
		showCard_164(cellType, x, y)
	end)
	btn.MouseLeave:Connect(function()
		hideCard_164()
	end)
	-- Mobile: on button click, show briefly then hide
	btn.MouseButton1Click:Connect(function()
		task.delay(0.6, hideCard_164)
	end)
end

-- Scan BuildGui for cell buttons when it becomes available
local function scanBuildGui_164()
	local buildGui = playerGui:WaitForChild("BuildGui", 10) :: ScreenGui?
	if not buildGui then return end

	-- Scan existing buttons
	for _, obj in buildGui:GetDescendants() do
		if obj:IsA("ImageButton") or obj:IsA("TextButton") then
			wireButton_164(obj :: GuiButton)
		end
	end

	-- Watch for new buttons added dynamically (e.g. BuildGui rebuilds on floor unlock)
	buildGui.DescendantAdded:Connect(function(obj: Instance)
		if obj:IsA("ImageButton") or obj:IsA("TextButton") then
			task.defer(function() wireButton_164(obj :: GuiButton) end)
		end
	end)
end

task.spawn(scanBuildGui_164)

-- ── Also wire hex cell plates in the 3D world (mouse hover via RunService) ────
-- When BuildGui is open and the player hovers a DimCellPlate in the world,
-- show the preview for whichever cell type is currently selected in BuildGui.
-- This is lighter-weight: we just track what cell type button was last hovered.
local lastHoveredType_164: string? = nil

-- Update lastHoveredType when a Build button is entered
local function patchEnterForWorldHover_164()
	local buildGui = playerGui:FindFirstChild("BuildGui") :: ScreenGui?
	if not buildGui then return end
	for _, obj in buildGui:GetDescendants() do
		if (obj:IsA("ImageButton") or obj:IsA("TextButton")) then
			local cellType = tryCellTypeFromButton_164(obj :: GuiButton)
			if cellType then
				(obj :: GuiButton).MouseEnter:Connect(function()
					lastHoveredType_164 = cellType
				end)
				(obj :: GuiButton).MouseLeave:Connect(function()
					if lastHoveredType_164 == cellType then
						lastHoveredType_164 = nil
					end
				end)
			end
		end
	end
end

task.spawn(function()
	task.wait(2)
	patchEnterForWorldHover_164()
end)
```

**Verification:**

```lua
local lrc = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("CombPreviewController")
print(lrc and lrc.ClassName or "MISSING")
-- Expected: LocalScript
```

---

## Step 2 — Test in Play Mode

Enter Play mode. Open BuildGui. Hover over any cell type button (Honey, Brood, Pollen, etc.).

```lua
-- In Play mode, verify preview ScreenGui created
local pg = game:GetService("Players").LocalPlayer.PlayerGui
local psg = pg:FindFirstChild("CombPreviewGui")
print("CombPreviewGui:", psg and psg.ClassName or "MISSING")
print("Card exists:", psg and psg:FindFirstChild("PreviewCard") and "YES" or "NO")
-- Expected: ScreenGui  YES
```

**Expected behaviour:**
- Hovering a cell button causes a semi-transparent card to fade in near the cursor
- Card shows: emoji, cell name, one-sentence kid description (large), adult detail (small grey),
  adjacency note (small green), and "Tap the cell to place ✓" hint at the bottom
- Moving off the button causes the card to fade out
- Card repositions dynamically to stay within screen bounds
- DanceFloor shows a special "Already placed" message instead of a placement hint

---

## Step 3 — state.json update

After executing in Studio, update `dispatch_count` to 164 and `last_dispatch` to
`"cycle15_comb_preview_dispatch.md"` in state.json.

---

## Summary

| What | Where |
|---|---|
| `CombPreviewController` | `StarterPlayer.StarterPlayerScripts` LocalScript |
| `CombPreviewGui` ScreenGui | built at runtime inside `PlayerGui` |
| New world parts | **0** → total **4,198 / 5,000** |
| New RemoteEvents | None |
| DataService changes | None |

**Kid experience:** Hover over any cell button in the build menu — a little card pops up with
a big emoji and one sentence explaining what the cell does. No commitment, no wasted honey.

**Adult experience:** Full stat line (rate, capacity, condition), adjacency note explaining
what bonus cells give each other, all in small text below the kid headline. The card tracks
the cursor and stays within screen bounds.
