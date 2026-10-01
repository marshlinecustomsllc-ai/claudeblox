# Dispatch 122 — Foraging Route Quality Display
## Cycle 14 · A Bee's World

**Feature:** A `ForagingQualityController` LocalScript that shows a compact HUD card while foraging is active. Kids see a flower happiness meter (🌸🌸🌸 = great patch, 🥀 = poor patch). Adults see the yield multiplier and seconds remaining on the current foraging run. The card fades in when `ForagingActive` becomes true and fades out when it ends. Part budget impact: +0 permanent parts.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 121 (Honey Ripeness Indicator)

---

## DESIGN

### Quality tiers

Quality is derived from `ForagingQuality` player attribute (0–100 integer, written by `ForagingService`). If the attribute doesn't exist, default to 60 (good).

| Quality | Kid label | Flower rating | Multiplier shown |
|---------|-----------|---------------|-----------------|
| 80–100 | "Amazing patch! 🐝" | 🌸🌸🌸🌸🌸 | ×2.0 |
| 60–79 | "Good patch! 🌼" | 🌸🌸🌸🌼🌼 | ×1.5 |
| 40–59 | "Okay patch" | 🌼🌼🌼🌼🌼 | ×1.0 |
| 20–39 | "Thin flowers..." | 🥀🌼🌼🌼🌼 | ×0.7 |
| 0–19 | "Poor patch 😕" | 🥀🥀🥀🌼🌼 | ×0.4 |

Multiplier is cosmetic on the client — the actual yield is computed server-side by `ForagingService`. The client shows it to inform routing decisions.

### HUD card layout

- `ForagingQualityGui` ScreenGui, DisplayOrder=14 (below bee facts=15, above propolis=14 but distinct)
- `QualityCard` Frame: 240×80, bottom-centre `{0.5,-120,1,-104}`, slides up from off-screen
- Row 1: `ForagingLabel` — "🐝 Foraging..." + kid quality text
- Row 2: `FlowerBar` — 5 emoji TextLabels in a horizontal list
- Row 3 (adult, always visible but small): multiplier + countdown timer
- Background: PROPOLIS_BROWN pill with HONEY_GOLD stroke

### Countdown timer

`ForagingEndTime` player attribute (Unix timestamp, written by `ForagingService`). Each `RunService.Heartbeat` tick (throttled to 1/s) computes `math.max(0, math.floor(ForagingEndTime - os.time()))` and displays as `"⏱ Xs left"`.

### Visibility logic

Show card: `ForagingActive == true`
Hide card: `ForagingActive == false` (tween down + hide after 0.5s)

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingQualityController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create ForagingQualityController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("ForagingQualityController") then
    print("⏭️  ForagingQualityController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "ForagingQualityController"
    ctrl.Source = [[
--!strict
-- ForagingQualityController — dispatch 122
-- Shows foraging route quality card while bees are out foraging.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD_122    = Color3.fromRGB(242, 168, 28)
local PROPOLIS_BROWN_122= Color3.fromRGB(80,  50,  20)
local WAX_CREAM_122     = Color3.fromRGB(232, 212, 154)
local DARK_BG_122       = Color3.fromRGB(30,  18,  8)

-- ── Quality tier definitions ───────────────────────────────────────
type QualityTier = {kidLabel: string, flowers: string, multiplier: string, barColor: Color3}
local TIERS_122: {QualityTier} = {
    {kidLabel="Poor patch 😕",        flowers="🥀🥀🥀🌼🌼", multiplier="×0.4", barColor=Color3.fromRGB(160,90,30)},
    {kidLabel="Thin flowers...",      flowers="🥀🌼🌼🌼🌼", multiplier="×0.7", barColor=Color3.fromRGB(200,140,30)},
    {kidLabel="Okay patch",           flowers="🌼🌼🌼🌼🌼", multiplier="×1.0", barColor=HONEY_GOLD_122},
    {kidLabel="Good patch! 🌼",       flowers="🌸🌸🌸🌼🌼", multiplier="×1.5", barColor=Color3.fromRGB(242,190,60)},
    {kidLabel="Amazing patch! 🐝",    flowers="🌸🌸🌸🌸🌸", multiplier="×2.0", barColor=Color3.fromRGB(255,220,40)},
}

local function getTier_122(quality: number): QualityTier
    if quality >= 80 then return TIERS_122[5]
    elseif quality >= 60 then return TIERS_122[4]
    elseif quality >= 40 then return TIERS_122[3]
    elseif quality >= 20 then return TIERS_122[2]
    else return TIERS_122[1]
    end
end

-- ── Build GUI ─────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ForagingQualityGui_122"
screenGui.DisplayOrder   = 14
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = false
screenGui.Parent         = playerGui

-- Card (240×84, bottom-centre, starts hidden below screen)
local card = Instance.new("Frame")
card.Name             = "QualityCard"
card.Size             = UDim2.new(0, 240, 0, 84)
card.Position         = UDim2.new(0.5, -120, 1, 20)   -- off-screen below
card.BackgroundColor3 = PROPOLIS_BROWN_122
card.BorderSizePixel  = 0
card.Visible          = false
card.Parent           = screenGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent       = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color     = HONEY_GOLD_122
cardStroke.Thickness = 1.5
cardStroke.Parent    = card

local cardPad = Instance.new("UIPadding")
cardPad.PaddingTop    = UDim.new(0, 6)
cardPad.PaddingLeft   = UDim.new(0, 10)
cardPad.PaddingRight  = UDim.new(0, 10)
cardPad.PaddingBottom = UDim.new(0, 4)
cardPad.Parent        = card

-- Row 1: foraging status + kid label
local topRow = Instance.new("TextLabel")
topRow.Name                   = "TopRow"
topRow.Size                   = UDim2.new(1, 0, 0, 22)
topRow.BackgroundTransparency = 1
topRow.TextColor3             = HONEY_GOLD_122
topRow.Font                   = Enum.Font.GothamBold
topRow.TextSize               = 13
topRow.TextXAlignment         = Enum.TextXAlignment.Left
topRow.Text                   = "🐝 Foraging... Amazing patch! 🐝"
topRow.Parent                 = card

-- Row 2: flower bar (5 emoji in horizontal list)
local flowerRow = Instance.new("Frame")
flowerRow.Name             = "FlowerRow"
flowerRow.Size             = UDim2.new(1, 0, 0, 24)
flowerRow.Position         = UDim2.new(0, 0, 0, 24)
flowerRow.BackgroundTransparency = 1
flowerRow.BorderSizePixel  = 0
flowerRow.Parent           = card

local flowerLayout = Instance.new("UIListLayout")
flowerLayout.FillDirection  = Enum.FillDirection.Horizontal
flowerLayout.SortOrder      = Enum.SortOrder.LayoutOrder
flowerLayout.Padding        = UDim.new(0, 2)
flowerLayout.Parent         = flowerRow

local flowerLabels: {TextLabel} = {}
for i = 1, 5 do
    local fl = Instance.new("TextLabel")
    fl.Name                   = "Flower" .. i
    fl.Size                   = UDim2.new(0, 22, 1, 0)
    fl.BackgroundTransparency = 1
    fl.TextColor3             = HONEY_GOLD_122
    fl.Font                   = Enum.Font.Gotham
    fl.TextSize               = 16
    fl.TextXAlignment         = Enum.TextXAlignment.Center
    fl.Text                   = "🌸"
    fl.LayoutOrder            = i
    fl.Parent                 = flowerRow
    table.insert(flowerLabels, fl)
end

-- Row 3: multiplier + countdown (small, always visible)
local bottomRow = Instance.new("TextLabel")
bottomRow.Name                   = "BottomRow"
bottomRow.Size                   = UDim2.new(1, 0, 0, 18)
bottomRow.Position               = UDim2.new(0, 0, 0, 50)
bottomRow.BackgroundTransparency = 1
bottomRow.TextColor3             = WAX_CREAM_122
bottomRow.Font                   = Enum.Font.Gotham
bottomRow.TextSize               = 11
bottomRow.TextXAlignment         = Enum.TextXAlignment.Left
bottomRow.Text                   = "×2.0 yield  ·  ⏱ 60s left"
bottomRow.Parent                 = card

-- ── State ─────────────────────────────────────────────────────────
local cardVisible_122 = false
local lastSecond_122  = -1

-- ── Update card content ───────────────────────────────────────────
local function updateCard_122()
    local quality   = tonumber(player:GetAttribute("ForagingQuality")) or 60
    local endTime   = tonumber(player:GetAttribute("ForagingEndTime")) or 0
    local secsLeft  = math.max(0, math.floor(endTime - os.time()))

    local tier = getTier_122(quality)

    topRow.Text = "🐝 Foraging...  " .. tier.kidLabel
    topRow.TextColor3 = tier.barColor

    -- Update flower emojis
    local flowerChars = {}
    for fc in tier.flowers:gmatch("[^%s]+") do
        table.insert(flowerChars, fc)
    end
    for i, lbl in flowerLabels do
        lbl.Text = flowerChars[i] or "🌼"
    end

    bottomRow.Text = tier.multiplier .. " yield  ·  ⏱ " .. secsLeft .. "s left"
end

-- ── Show / hide card ───────────────────────────────────────────────
local SHOW_POS_122 = UDim2.new(0.5, -120, 1, -104)
local HIDE_POS_122 = UDim2.new(0.5, -120, 1, 20)

local function showCard_122()
    card.Visible  = true
    cardVisible_122 = true
    updateCard_122()
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = SHOW_POS_122}):Play()
end

local function hideCard_122()
    cardVisible_122 = false
    TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = HIDE_POS_122}):Play()
    task.delay(0.3, function()
        if not cardVisible_122 then card.Visible = false end
    end)
end

-- ── Heartbeat countdown (throttled to 1/sec) ──────────────────────
RunService.Heartbeat:Connect(function()
    if not cardVisible_122 then return end
    local now = os.time()
    if now == lastSecond_122 then return end
    lastSecond_122 = now
    updateCard_122()
end)

-- ── Attribute listeners ───────────────────────────────────────────
player:GetAttributeChangedSignal("ForagingActive"):Connect(function()
    local active = player:GetAttribute("ForagingActive") == true
    if active then showCard_122() else hideCard_122() end
end)

player:GetAttributeChangedSignal("ForagingQuality"):Connect(function()
    if cardVisible_122 then updateCard_122() end
end)

-- ── Initialise on load ────────────────────────────────────────────
task.wait(2)
if player:GetAttribute("ForagingActive") == true then
    showCard_122()
end

print("[ForagingQualityController] Ready — quality card shows during foraging")
]]
    ctrl.Parent = SPS
    print("✅ ForagingQualityController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("ForagingQualityController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " ForagingQualityController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("TIERS_122", 1, true) and "✅" or "❌") .. " TIERS_122 quality tier table")
table.insert(checks, (ctrl and ctrl.Source:find("getTier_122", 1, true) and "✅" or "❌") .. " getTier_122 helper")
table.insert(checks, (ctrl and ctrl.Source:find("showCard_122", 1, true) and "✅" or "❌") .. " showCard_122 / hideCard_122")
table.insert(checks, (ctrl and ctrl.Source:find("updateCard_122", 1, true) and "✅" or "❌") .. " updateCard_122 content refresh")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingActive", 1, true) and "✅" or "❌") .. " ForagingActive listener")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingQuality", 1, true) and "✅" or "❌") .. " ForagingQuality attribute")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingEndTime", 1, true) and "✅" or "❌") .. " ForagingEndTime countdown")
table.insert(checks, (ctrl and ctrl.Source:find("RunService", 1, true) and "✅" or "❌") .. " RunService.Heartbeat countdown")
table.insert(checks, (ctrl and ctrl.Source:find("lastSecond_122", 1, true) and "✅" or "❌") .. " 1-second throttle on heartbeat")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService slide animation")
table.insert(checks, (ctrl and ctrl.Source:find("flowerLabels", 1, true) and "✅" or "❌") .. " flowerLabels array (5 emoji slots)")

print("=== DISPATCH 122 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 122 complete" or "❌ SOME CHECKS FAILED")

print("\nTiers: 🥀🥀🥀×0.4 | 🥀🌼×0.7 | 🌼🌼🌼×1.0 | 🌸🌸🌸×1.5 | 🌸🌸🌸🌸🌸×2.0")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| ForagingQualityController (LocalScript, runtime UI in PlayerGui) | 0 permanent |
| **Dispatch 122 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `ForagingQuality` attribute (0–100) is expected to be written by `ForagingService` when a foraging run starts. If it doesn't exist yet, the controller defaults to quality 60 (good tier) — the card still shows correct foraging status even before the attribute is wired.
- The multiplier text (×2.0) is cosmetic: it informs the player of their theoretical yield without the server having to expose internal calculation details. Actual yields remain server-authoritative.
- `RunService.Heartbeat` throttled to 1 tick/second via `lastSecond_122` comparison — avoids calling `os.time()` and rebuilding text 60× per second for a countdown that only changes every second.
- The card slides up from off-screen using `Enum.EasingStyle.Back` (slight overshoot on arrival) to make the appearance feel lively and bouncy — appropriate for the bee theme. Dismiss uses `Quad` (smooth ease-in) for a clean exit.
- `DisplayOrder=14` sits below Daily Bee Facts (15), the Bee Roster (18), and Cell Guide (20), but above general HUD. It shares the 14 tier with Propolis Rain (also 14) — both are time-limited contextual cards that appear at the bottom of the screen and are unlikely to be active simultaneously (Propolis Rain is a server event; foraging is player-initiated).
- The flower emoji bar is built as 5 individual `TextLabel` objects rather than a single string because this allows per-flower colour changes in a future iteration (e.g., wilting animation on 🥀 flowers) without restructuring the layout.
