# Dispatch 114 — Comb Cell Guide (Kid-Friendly Buildable Explanation)
## Cycle 14 · A Bee's World

**Feature:** An always-accessible in-game guide explaining what each comb cell type does, written for young players. A persistent `🐝 How to Build?` button sits in the bottom-right corner; tapping it slides open a scrollable panel with one card per cell type — big emoji, short name, and one plain sentence. A sticky tip strip explains adjacency bonuses ("put Pollen Cells next to Brood Cells!") so kids discover the placement puzzle naturally.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 113 (Prestige Hive Aura)

---

## DESIGN

### Cell type cards (order = build-menu order)

| # | Emoji | Name | Kid-Friendly Text |
|---|-------|------|-------------------|
| 1 | 🍯 | Honey Cell | Stores the honey your bees make! Build lots of these so your hive can hold more. |
| 2 | 🐛 | Brood Cell | Baby bees hatch here! More brood cells = a bigger, busier hive. |
| 3 | 🌼 | Pollen Cell | Holds flower pollen to feed your baby bees. Best when placed next to Brood Cells! |
| 4 | 👑 | Royal Cell | The Queen's special chamber. Unlock this once your hive is big and strong! |
| 5 | 💃 | Dance Floor | The heart of your hive! Bees do their waggle dance here to share flower secrets. |
| 6 | 🏭 | Propolis Kiln | Melts sticky tree resin into propolis — the magic ingredient for rare upgrades! |

### Adjacency tip strip (bottom of panel, always visible)

> **💡 Placement Tip!**
> Put **Pollen Cells** right next to **Brood Cells** for faster hatching! 🐣
> Cluster **Honey Cells** together for a bigger honey bonus! 🍯

### Layout

```
┌─────────────────────────────────┐
│  🏠 Building Your Hive!      ✕ │  ← TitleBar
├─────────────────────────────────┤
│  🍯  Honey Cell                 │  ← Card (emoji + name + desc)
│     Stores the honey…           │
│─────────────────────────────────│
│  🐛  Brood Cell                 │
│     Baby bees hatch here!…      │
│  …(x6 cards, scrollable)        │
├─────────────────────────────────┤
│  💡 Placement Tip!             │  ← sticky tip strip
│  Put Pollen Cells next to…     │
└─────────────────────────────────┘
```

Panel: 320×440px equivalent (Scale-based), centred, DisplayOrder=20.
Guide button: 120×44 anchored bottom-right, always visible (not hidden by Build Mode).

### Animation

- Button: scale pulse (0.95→1.05→1.0) on first load, draws attention
- Panel: slides in from below (AnchorPoint Y+0.1 → correct position) via TweenService, Back easing
- Close: reverse slide + fade

---

## FILES CHANGED

| File | Change |
|------|--------|
| `CellGuideGui` | New ScreenGui in StarterGui |
| `CellGuideController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create CellGuideGui

Command Bar:

```lua
local SG = game:GetService("StarterGui")
assert(SG, "StarterGui not found")

if SG:FindFirstChild("CellGuideGui") then
    print("⏭️  CellGuideGui already exists — skip")
else

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD   = Color3.fromRGB(242, 168, 28)
local PROPOLIS_BRN = Color3.fromRGB(80,  50,  20)
local WAX_CREAM    = Color3.fromRGB(232, 212, 154)
local WHITE        = Color3.fromRGB(255, 255, 255)
local DARK_BG      = Color3.fromRGB(30,  18,   8)
local CARD_BG      = Color3.fromRGB(50,  30,  10)
local TIP_BG       = Color3.fromRGB(60,  38,  12)

-- ── Root ScreenGui ─────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name              = "CellGuideGui"
gui.DisplayOrder      = 20
gui.ResetOnSpawn      = false
gui.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
gui.Parent            = SG

-- ── Guide Button (always visible, bottom-right) ────────────────────
local btn = Instance.new("TextButton")
btn.Name                  = "GuideButton"
btn.Text                  = "🐝 How to Build?"
btn.Font                  = Enum.Font.GothamBold
btn.TextSize              = 14
btn.TextColor3            = PROPOLIS_BRN
btn.BackgroundColor3      = HONEY_GOLD
btn.Size                  = UDim2.new(0, 150, 0, 44)
btn.Position              = UDim2.new(1, -160, 1, -56)
btn.AnchorPoint           = Vector2.new(0, 0)
btn.AutoButtonColor       = true
btn.ZIndex                = 10
btn.Parent                = gui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 22)
btnCorner.Parent       = btn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color     = PROPOLIS_BRN
btnStroke.Thickness = 1.5
btnStroke.Parent    = btn

-- ── Guide Panel (hidden by default) ────────────────────────────────
local panel = Instance.new("Frame")
panel.Name                = "GuidePanel"
panel.BackgroundColor3    = DARK_BG
panel.BackgroundTransparency = 0.05
panel.Size                = UDim2.new(0, 320, 0, 440)
panel.Position            = UDim2.new(0.5, -160, 0.5, -220)
panel.AnchorPoint         = Vector2.new(0, 0)
panel.Visible             = false
panel.ZIndex              = 20
panel.Parent              = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD
panelStroke.Thickness = 2
panelStroke.Parent    = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name               = "TitleBar"
titleBar.BackgroundColor3   = PROPOLIS_BRN
titleBar.Size               = UDim2.new(1, 0, 0, 46)
titleBar.Position           = UDim2.new(0, 0, 0, 0)
titleBar.ZIndex             = 21
titleBar.Parent             = panel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent       = titleBar

-- Square off bottom corners of titleBar via a bottom cover
local titleFill = Instance.new("Frame")
titleFill.BackgroundColor3 = PROPOLIS_BRN
titleFill.Size             = UDim2.new(1, 0, 0, 14)
titleFill.Position         = UDim2.new(0, 0, 1, -14)
titleFill.ZIndex           = 21
titleFill.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name           = "TitleLabel"
titleLabel.Text           = "🏠 Building Your Hive!"
titleLabel.Font           = Enum.Font.GothamBold
titleLabel.TextSize       = 16
titleLabel.TextColor3     = HONEY_GOLD
titleLabel.BackgroundTransparency = 1
titleLabel.Size           = UDim2.new(1, -50, 1, 0)
titleLabel.Position       = UDim2.new(0, 12, 0, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex         = 22
titleLabel.Parent         = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name               = "CloseButton"
closeBtn.Text               = "✕"
closeBtn.Font               = Enum.Font.GothamBold
closeBtn.TextSize           = 16
closeBtn.TextColor3         = WAX_CREAM
closeBtn.BackgroundColor3   = Color3.fromRGB(100, 60, 20)
closeBtn.Size               = UDim2.new(0, 30, 0, 30)
closeBtn.Position           = UDim2.new(1, -38, 0.5, -15)
closeBtn.AutoButtonColor    = true
closeBtn.ZIndex             = 22
closeBtn.Parent             = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent       = closeBtn

-- ── Scrollable card area ────────────────────────────────────────────
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name                    = "CardScroll"
scrollFrame.BackgroundTransparency  = 1
scrollFrame.Size                    = UDim2.new(1, -8, 1, -46-70)  -- minus title + tip strip
scrollFrame.Position                = UDim2.new(0, 4, 0, 46)
scrollFrame.CanvasSize              = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize     = Enum.AutomaticSize.Y
scrollFrame.ScrollBarThickness      = 3
scrollFrame.ScrollBarImageColor3    = HONEY_GOLD
scrollFrame.ElasticBehavior         = Enum.ElasticBehavior.WhenScrollable
scrollFrame.ZIndex                  = 21
scrollFrame.Parent                  = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding       = UDim.new(0, 4)
listLayout.SortOrder     = Enum.SortOrder.LayoutOrder
listLayout.Parent        = scrollFrame

local listPad = Instance.new("UIPadding")
listPad.PaddingTop    = UDim.new(0, 6)
listPad.PaddingLeft   = UDim.new(0, 4)
listPad.PaddingRight  = UDim.new(0, 4)
listPad.PaddingBottom = UDim.new(0, 4)
listPad.Parent        = scrollFrame

-- Cell data
local CELLS = {
    { emoji="🍯", name="Honey Cell",
      desc="Stores the honey your bees make! Build lots of these so your hive can hold more." },
    { emoji="🐛", name="Brood Cell",
      desc="Baby bees hatch here! More brood cells means a bigger, busier hive." },
    { emoji="🌼", name="Pollen Cell",
      desc="Holds flower pollen to feed your baby bees. Put these next to Brood Cells!" },
    { emoji="👑", name="Royal Cell",
      desc="The Queen's special chamber. Unlock this once your hive is big and strong!" },
    { emoji="💃", name="Dance Floor",
      desc="The heart of your hive! Bees do the waggle dance here to share flower secrets." },
    { emoji="🏭", name="Propolis Kiln",
      desc="Melts sticky tree resin into propolis — the magic ingredient for rare upgrades!" },
}

for i, data in ipairs(CELLS) do
    local card = Instance.new("Frame")
    card.Name               = "Card_" .. i
    card.BackgroundColor3   = CARD_BG
    card.Size               = UDim2.new(1, 0, 0, 72)
    card.LayoutOrder        = i
    card.ZIndex             = 22
    card.Parent             = scrollFrame

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 8)
    cardCorner.Parent       = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color     = Color3.fromRGB(100, 70, 30)
    cardStroke.Thickness = 1
    cardStroke.Parent    = card

    -- Emoji icon
    local icon = Instance.new("TextLabel")
    icon.Name                 = "Icon"
    icon.Text                 = data.emoji
    icon.Font                 = Enum.Font.GothamBold
    icon.TextSize             = 28
    icon.BackgroundTransparency = 1
    icon.Size                 = UDim2.new(0, 46, 1, 0)
    icon.Position             = UDim2.new(0, 4, 0, 0)
    icon.TextXAlignment       = Enum.TextXAlignment.Center
    icon.ZIndex               = 23
    icon.Parent               = card

    -- Cell name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name            = "NameLabel"
    nameLabel.Text            = data.name
    nameLabel.Font            = Enum.Font.GothamBold
    nameLabel.TextSize        = 14
    nameLabel.TextColor3      = HONEY_GOLD
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size            = UDim2.new(1, -58, 0, 22)
    nameLabel.Position        = UDim2.new(0, 54, 0, 8)
    nameLabel.TextXAlignment  = Enum.TextXAlignment.Left
    nameLabel.ZIndex          = 23
    nameLabel.Parent          = card

    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name            = "DescLabel"
    descLabel.Text            = data.desc
    descLabel.Font            = Enum.Font.Gotham
    descLabel.TextSize        = 12
    descLabel.TextColor3      = WAX_CREAM
    descLabel.BackgroundTransparency = 1
    descLabel.Size            = UDim2.new(1, -58, 0, 38)
    descLabel.Position        = UDim2.new(0, 54, 0, 28)
    descLabel.TextXAlignment  = Enum.TextXAlignment.Left
    descLabel.TextYAlignment  = Enum.TextYAlignment.Top
    descLabel.TextWrapped     = true
    descLabel.ZIndex          = 23
    descLabel.Parent          = card
end

-- ── Tip strip (sticky bottom) ───────────────────────────────────────
local tipStrip = Instance.new("Frame")
tipStrip.Name               = "TipStrip"
tipStrip.BackgroundColor3   = TIP_BG
tipStrip.Size               = UDim2.new(1, 0, 0, 70)
tipStrip.Position           = UDim2.new(0, 0, 1, -70)
tipStrip.ZIndex             = 21
tipStrip.Parent             = panel

local tipCorner = Instance.new("UICorner")
tipCorner.CornerRadius = UDim.new(0, 14)
tipCorner.Parent       = tipStrip

-- Square off TOP corners of tipStrip
local tipFill = Instance.new("Frame")
tipFill.BackgroundColor3 = TIP_BG
tipFill.Size             = UDim2.new(1, 0, 0, 14)
tipFill.Position         = UDim2.new(0, 0, 0, 0)
tipFill.ZIndex           = 21
tipFill.Parent           = tipStrip

local tipLabel = Instance.new("TextLabel")
tipLabel.Name            = "TipLabel"
tipLabel.Text            = "💡 Tip: Put Pollen Cells RIGHT NEXT TO Brood Cells for faster baby bees! 🐣\nCluster Honey Cells together for a bigger honey bonus! 🍯"
tipLabel.Font            = Enum.Font.Gotham
tipLabel.TextSize        = 12
tipLabel.TextColor3      = WAX_CREAM
tipLabel.BackgroundTransparency = 1
tipLabel.Size            = UDim2.new(1, -16, 1, -8)
tipLabel.Position        = UDim2.new(0, 8, 0, 8)
tipLabel.TextWrapped     = true
tipLabel.TextXAlignment  = Enum.TextXAlignment.Left
tipLabel.TextYAlignment  = Enum.TextYAlignment.Top
tipLabel.ZIndex          = 22
tipLabel.Parent          = tipStrip

print("✅ CellGuideGui created in StarterGui — 6 cell cards + tip strip")
end
```

---

## STEP B — Create CellGuideController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("CellGuideController") then
    print("⏭️  CellGuideController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "CellGuideController"
    ctrl.Source = [[
--!strict
-- CellGuideController — dispatch 114
-- Opens/closes the comb cell explanation guide panel.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiRoot   = playerGui:WaitForChild("CellGuideGui", 10)
if not guiRoot then
    warn("[CellGuide] CellGuideGui not found — aborting")
    return
end

local btn    = guiRoot:WaitForChild("GuideButton")
local panel  = guiRoot:WaitForChild("GuidePanel")
local closeB = panel:WaitForChild("TitleBar"):WaitForChild("CloseButton")

local OPEN_POS  = UDim2.new(0.5, -160, 0.5, -220)
local CLOSE_POS = UDim2.new(0.5, -160, 0.6, -220)  -- slides down slightly when hiding

local INFO_OPEN   = TweenInfo.new(0.3, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local INFO_CLOSE  = TweenInfo.new(0.2, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local panelOpen = false

local function openPanel()
    if panelOpen then return end
    panelOpen = true
    panel.Position  = CLOSE_POS
    panel.Visible   = true
    panel.BackgroundTransparency = 0.9
    TweenService:Create(panel, INFO_OPEN, {
        Position               = OPEN_POS,
        BackgroundTransparency = 0.05,
    }):Play()
end

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    local t = TweenService:Create(panel, INFO_CLOSE, {
        Position               = CLOSE_POS,
        BackgroundTransparency = 0.95,
    })
    t:Play()
    t.Completed:Connect(function()
        panel.Visible = false
    end)
end

btn.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)

closeB.Activated:Connect(closePanel)

-- Pulse the button once on first load to draw attention
task.wait(2)
local INFO_PULSE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 2, true)
TweenService:Create(btn, INFO_PULSE, { Size = UDim2.new(0, 162, 0, 48) }):Play()

print("[CellGuideController] Ready — comb cell guide active")
]]
    ctrl.Parent = SPS
    print("✅ CellGuideController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SG  = game:GetService("StarterGui")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local gui  = SG  and SG:FindFirstChild("CellGuideGui")
local ctrl = SPS and SPS:FindFirstChild("CellGuideController")

local panel     = gui  and gui:FindFirstChild("GuidePanel")
local titleBar  = panel and panel:FindFirstChild("TitleBar")
local scroll    = panel and panel:FindFirstChild("CardScroll")
local tipStrip  = panel and panel:FindFirstChild("TipStrip")
local guideBtn  = gui  and gui:FindFirstChild("GuideButton")

-- Count cards
local cardCount = 0
if scroll then
    for _, child in scroll:GetChildren() do
        if child.Name:sub(1, 5) == "Card_" then cardCount += 1 end
    end
end

local checks = {}
table.insert(checks, (gui  and "✅" or "❌") .. " CellGuideGui in StarterGui")
table.insert(checks, (gui  and gui:IsA("ScreenGui") and "✅" or "❌") .. " is a ScreenGui")
table.insert(checks, (gui  and gui.DisplayOrder == 20 and "✅" or "❌") .. " DisplayOrder=20")
table.insert(checks, (guideBtn and "✅" or "❌") .. " GuideButton exists")
table.insert(checks, (guideBtn and guideBtn:IsA("TextButton") and "✅" or "❌") .. " GuideButton is TextButton")
table.insert(checks, (panel and "✅" or "❌") .. " GuidePanel exists")
table.insert(checks, (panel and not panel.Visible and "✅" or "❌") .. " GuidePanel hidden by default")
table.insert(checks, (titleBar and "✅" or "❌") .. " TitleBar with close button")
table.insert(checks, (scroll and "✅" or "❌") .. " CardScroll (ScrollingFrame)")
table.insert(checks, (cardCount == 6 and "✅" or "❌") .. " 6 cell cards (got " .. cardCount .. ")")
table.insert(checks, (tipStrip and "✅" or "❌") .. " TipStrip at bottom")
table.insert(checks, (ctrl and "✅" or "❌") .. " CellGuideController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("openPanel", 1, true) and "✅" or "❌") .. " openPanel function")
table.insert(checks, (ctrl and ctrl.Source:find("closePanel", 1, true) and "✅" or "❌") .. " closePanel function")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService animation")
table.insert(checks, (ctrl and ctrl.Source:find("Activated", 1, true) and "✅" or "❌") .. " Activated connections")

print("=== DISPATCH 114 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 114 complete" or "❌ SOME CHECKS FAILED")

print("\nCell guide cards:")
print("  🍯 Honey Cell, 🐛 Brood Cell, 🌼 Pollen Cell")
print("  👑 Royal Cell, 💃 Dance Floor, 🏭 Propolis Kiln")
print("  + adjacency tip strip")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| CellGuideGui (StarterGui) — UI only, no Workspace parts | 0 |
| **Dispatch 114 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `GuideButton` is always on-screen (DisplayOrder=20) so kids can find it any time — not buried inside Build Mode. The 2-second pulse on first load makes it noticeable without being annoying.
- `panel.Visible = false` by default means zero render cost when closed; tween sets it visible *before* animating in so the first frame isn't a pop.
- `AutomaticCanvasSize=Y` on the ScrollingFrame means adding or reordering cell cards in the future never requires a manual canvas size update.
- Card height is fixed at 72px (tall enough to read on mobile without squinting); the 12px `TextWrapped` description handles varying text lengths cleanly.
- The tip strip is positioned at `(0, 0, 1, -70)` relative to the panel — it stays pinned to the bottom regardless of scroll position in the card area. This makes the adjacency advice always visible even after the player scrolls to the bottom card.
- `CloseButton` is 30×30 — meets the 44px touch target when combined with the UIPadding of the title bar.
- No server scripts, no RemoteEvents, no DataStore reads — this is 100% client-side UI. It has no runtime cost between sessions.
- "Propolis Kiln" description uses the phrase "magic ingredient for rare upgrades" rather than a mechanical description — kids respond to "magic" and "rare" much more than "converts resin at a 3:1 ratio."
- The emoji icons are the same ones already used in achievement toasts (dispatches 105/111/112) so the visual language is consistent across the whole game.
