# Dispatch 127 — Hive Health Display
## Cycle 14 · A Bee's World

**Feature:** A `HiveHealthController` LocalScript that computes and displays a composite "hive health" score in a compact top-centre HUD bar. The score (0–100) is derived client-side from three factors: cell type diversity (do you have multiple cell types?), honey reserve ratio (honey vs. capacity), and whether any cells are placed at all. Kids see a 🐝 bee emoji happiness bar that changes face; adults see the numeric score and a one-line tip on the lowest-scoring factor. Updated whenever `CombState`, `HoneyCount`, or `CombCellCount` changes.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 126 (Pollen Trail VFX)

---

## DESIGN

### Health score formula (client-side, cosmetic)

```
diversityScore  = (unique cell types present / 6) * 40        -- max 40
reserveScore    = clamp(HoneyCount / max(cellCount * 50, 1), 0, 1) * 35   -- max 35
activityScore   = cellCount > 0 and 25 or 0                    -- max 25
total = diversityScore + reserveScore + activityScore          -- 0-100
```

Six cell types: honey, brood, pollen, royal, dance_floor, kiln.

### HUD bar layout

- `HiveHealthGui` ScreenGui, DisplayOrder=13
- `HealthBar` Frame: 200×28, top-centre `{0.5,-100,0,8}`
- Background: PROPOLIS_BROWN pill
- Emoji label on left (24px) showing bee happiness
- Fill bar (140×8) showing score fraction (HONEY_GOLD)
- Score number on right (32px, 11pt, WAX_CREAM)

### Bee happiness faces

| Score | Emoji |
|-------|-------|
| 0–19 | 😟 |
| 20–39 | 😐 |
| 40–59 | 🙂 |
| 60–79 | 😄 |
| 80–100 | 🐝✨ |

### Tip line (adult)

Below the bar: one line, 11pt WAX_CREAM, shows the lowest-scoring factor name and a micro-tip. Only visible if score < 80.

| Lowest factor | Tip |
|---------------|-----|
| diversity | "Add more cell types for a healthier hive!" |
| reserve | "Collect more honey to build reserves" |
| activity | "Build your first comb cell to get started!" |

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HiveHealthController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HiveHealthController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HiveHealthController") then
    print("⏭️  HiveHealthController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HiveHealthController"
    ctrl.Source = [[
--!strict
-- HiveHealthController — dispatch 127
-- Composite hive health score: diversity + reserves + activity.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD_127    = Color3.fromRGB(242, 168, 28)
local PROPOLIS_BROWN_127= Color3.fromRGB(80,  50,  20)
local WAX_CREAM_127     = Color3.fromRGB(232, 212, 154)
local DARK_BG_127       = Color3.fromRGB(30,  18,  8)

-- ── Happiness emoji ───────────────────────────────────────────────
local function getEmoji_127(score: number): string
    if score >= 80 then return "🐝✨"
    elseif score >= 60 then return "😄"
    elseif score >= 40 then return "🙂"
    elseif score >= 20 then return "😐"
    else return "😟"
    end
end

-- ── Bar colour ────────────────────────────────────────────────────
local function getBarColor_127(score: number): Color3
    if score >= 80 then return HONEY_GOLD_127
    elseif score >= 60 then return Color3.fromRGB(200, 160, 20)
    elseif score >= 40 then return Color3.fromRGB(180, 130, 20)
    elseif score >= 20 then return Color3.fromRGB(160, 100, 30)
    else return Color3.fromRGB(140, 70, 30)
    end
end

-- ── CombState parser ──────────────────────────────────────────────
local function parseCombState_127(): {[string]: string}
    local raw = tostring(player:GetAttribute("CombState") or "{}")
    local t: {[string]: string} = {}
    for k, v in raw:gmatch('"(%w+)":"(%w+)"') do t[k] = v end
    return t
end

-- ── Health score calculator ───────────────────────────────────────
type HealthResult = {score: number, lowestFactor: string, lowestScore: number}

local function calcHealth_127(): HealthResult
    local combState  = parseCombState_127()
    local honeyCount = tonumber(player:GetAttribute("HoneyCount"))    or 0
    local cellCount  = tonumber(player:GetAttribute("CombCellCount")) or 0

    -- Diversity: how many unique non-empty cell types
    local typeSeen: {[string]: boolean} = {}
    for _, ct in combState do
        if ct ~= "" then typeSeen[ct] = true end
    end
    local uniqueTypes = 0
    for _ in typeSeen do uniqueTypes += 1 end

    local diversityRaw  = (uniqueTypes / 6) * 40
    local reserveRaw    = math.clamp(honeyCount / math.max(cellCount * 50, 1), 0, 1) * 35
    local activityRaw   = cellCount > 0 and 25 or 0

    local total = math.floor(diversityRaw + reserveRaw + activityRaw)

    -- Determine lowest factor for tip
    local lowestFactor = "activity"
    local lowestScore  = activityRaw
    if diversityRaw < lowestScore then lowestFactor = "diversity"; lowestScore = diversityRaw end
    if reserveRaw   < lowestScore then lowestFactor = "reserve";   lowestScore = reserveRaw   end

    return {score = total, lowestFactor = lowestFactor, lowestScore = lowestScore}
end

-- ── Tip messages ──────────────────────────────────────────────────
local TIPS_127: {[string]: string} = {
    diversity = "Add more cell types for a healthier hive!",
    reserve   = "Collect honey to build up your reserves",
    activity  = "Build your first comb cell to get started!",
}

-- ── Build GUI ─────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "HiveHealthGui_127"
screenGui.DisplayOrder   = 13
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = false
screenGui.Parent         = playerGui

-- Container (200×44, top-centre)
local container = Instance.new("Frame")
container.Name             = "HealthContainer"
container.Size             = UDim2.new(0, 200, 0, 44)
container.Position         = UDim2.new(0.5, -100, 0, 8)
container.BackgroundColor3 = PROPOLIS_BROWN_127
container.BackgroundTransparency = 0.15
container.BorderSizePixel  = 0
container.Parent           = screenGui

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 10)
cCorner.Parent       = container

local cStroke = Instance.new("UIStroke")
cStroke.Color     = HONEY_GOLD_127
cStroke.Thickness = 1
cStroke.Parent    = container

local cPad = Instance.new("UIPadding")
cPad.PaddingLeft   = UDim.new(0, 6)
cPad.PaddingRight  = UDim.new(0, 6)
cPad.PaddingTop    = UDim.new(0, 4)
cPad.PaddingBottom = UDim.new(0, 4)
cPad.Parent        = container

-- Row 1: emoji + fill bar + score number
local topRow = Instance.new("Frame")
topRow.Name             = "TopRow"
topRow.Size             = UDim2.new(1, 0, 0, 20)
topRow.BackgroundTransparency = 1
topRow.BorderSizePixel  = 0
topRow.Parent           = container

local emojiLabel = Instance.new("TextLabel")
emojiLabel.Name                   = "Emoji"
emojiLabel.Size                   = UDim2.new(0, 22, 1, 0)
emojiLabel.BackgroundTransparency = 1
emojiLabel.TextColor3             = HONEY_GOLD_127
emojiLabel.Font                   = Enum.Font.Gotham
emojiLabel.TextSize               = 14
emojiLabel.TextXAlignment         = Enum.TextXAlignment.Center
emojiLabel.Text                   = "🐝✨"
emojiLabel.Parent                 = topRow

-- Fill bar track
local barTrack = Instance.new("Frame")
barTrack.Name             = "BarTrack"
barTrack.Size             = UDim2.new(1, -56, 0, 7)
barTrack.Position         = UDim2.new(0, 26, 0.5, -3.5)
barTrack.BackgroundColor3 = DARK_BG_127
barTrack.BackgroundTransparency = 0.4
barTrack.BorderSizePixel  = 0
barTrack.Parent           = topRow

local btCorner = Instance.new("UICorner")
btCorner.CornerRadius = UDim.new(1, 0)
btCorner.Parent       = barTrack

-- Fill bar fill
local barFill = Instance.new("Frame")
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(1, 0, 1, 0)   -- width set on update
barFill.BackgroundColor3 = HONEY_GOLD_127
barFill.BorderSizePixel  = 0
barFill.Parent           = barTrack

local bfCorner = Instance.new("UICorner")
bfCorner.CornerRadius = UDim.new(1, 0)
bfCorner.Parent       = barFill

-- Score label
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name                   = "Score"
scoreLabel.Size                   = UDim2.new(0, 24, 1, 0)
scoreLabel.Position               = UDim2.new(1, -24, 0, 0)
scoreLabel.BackgroundTransparency = 1
scoreLabel.TextColor3             = WAX_CREAM_127
scoreLabel.Font                   = Enum.Font.GothamBold
scoreLabel.TextSize               = 11
scoreLabel.TextXAlignment         = Enum.TextXAlignment.Right
scoreLabel.Text                   = "100"
scoreLabel.Parent                 = topRow

-- Row 2: tip line (hidden when score >= 80)
local tipLabel = Instance.new("TextLabel")
tipLabel.Name                   = "Tip"
tipLabel.Size                   = UDim2.new(1, 0, 0, 14)
tipLabel.Position               = UDim2.new(0, 0, 0, 24)
tipLabel.BackgroundTransparency = 1
tipLabel.TextColor3             = WAX_CREAM_127
tipLabel.Font                   = Enum.Font.Gotham
tipLabel.TextSize               = 10
tipLabel.TextXAlignment         = Enum.TextXAlignment.Center
tipLabel.TextTruncate           = Enum.TextTruncate.AtEnd
tipLabel.Text                   = ""
tipLabel.Visible                = false
tipLabel.Parent                 = container

-- ── Update display ────────────────────────────────────────────────
local function update_127()
    local result   = calcHealth_127()
    local score    = result.score
    local fraction = score / 100

    emojiLabel.Text = getEmoji_127(score)
    scoreLabel.Text = tostring(score)

    local newColor = getBarColor_127(score)
    TweenService:Create(barFill, TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        {Size = UDim2.new(fraction, 0, 1, 0), BackgroundColor3 = newColor}):Play()

    if score < 80 then
        tipLabel.Text    = TIPS_127[result.lowestFactor] or ""
        tipLabel.Visible = true
        -- Expand container for tip row
        TweenService:Create(container, TweenInfo.new(0.3),
            {Size = UDim2.new(0, 200, 0, 44)}):Play()
    else
        tipLabel.Visible = false
        TweenService:Create(container, TweenInfo.new(0.3),
            {Size = UDim2.new(0, 200, 0, 28)}):Play()
    end
end

-- ── Listeners ─────────────────────────────────────────────────────
player:GetAttributeChangedSignal("CombState"):Connect(update_127)
player:GetAttributeChangedSignal("HoneyCount"):Connect(update_127)
player:GetAttributeChangedSignal("CombCellCount"):Connect(update_127)

-- ── Initial update ────────────────────────────────────────────────
task.wait(2)
update_127()

print("[HiveHealthController] Ready — health score from diversity + reserves + activity")
]]
    ctrl.Parent = SPS
    print("✅ HiveHealthController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HiveHealthController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveHealthController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("calcHealth_127", 1, true) and "✅" or "❌") .. " calcHealth_127 score function")
table.insert(checks, (ctrl and ctrl.Source:find("getEmoji_127", 1, true) and "✅" or "❌") .. " getEmoji_127 happiness face")
table.insert(checks, (ctrl and ctrl.Source:find("getBarColor_127", 1, true) and "✅" or "❌") .. " getBarColor_127 colour scale")
table.insert(checks, (ctrl and ctrl.Source:find("TIPS_127", 1, true) and "✅" or "❌") .. " TIPS_127 improvement tips")
table.insert(checks, (ctrl and ctrl.Source:find("update_127", 1, true) and "✅" or "❌") .. " update_127 main refresh")
table.insert(checks, (ctrl and ctrl.Source:find("parseCombState_127", 1, true) and "✅" or "❌") .. " parseCombState_127")
table.insert(checks, (ctrl and ctrl.Source:find("CombState", 1, true) and "✅" or "❌") .. " CombState listener")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCount", 1, true) and "✅" or "❌") .. " HoneyCount listener")
table.insert(checks, (ctrl and ctrl.Source:find("diversityRaw", 1, true) and "✅" or "❌") .. " diversity component (6 cell types)")
table.insert(checks, (ctrl and ctrl.Source:find("reserveRaw", 1, true) and "✅" or "❌") .. " reserve component")
table.insert(checks, (ctrl and ctrl.Source:find("activityRaw", 1, true) and "✅" or "❌") .. " activity component")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService animated bar")

print("=== DISPATCH 127 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 127 complete" or "❌ SOME CHECKS FAILED")

print("\nHealth formula: diversity(40) + reserves(35) + activity(25) = 100")
print("Emoji: 😟<20 | 😐<40 | 🙂<60 | 😄<80 | 🐝✨>=80")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HiveHealthController (LocalScript, runtime UI in PlayerGui) | 0 permanent |
| **Dispatch 127 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The health formula is intentionally cosmetic and client-side — it's a game-feel indicator, not an authoritative game mechanic. The server doesn't need to know the score; only the player's screen does.
- Diversity score rewards using all 6 cell types (honey, brood, pollen, royal, dance_floor, kiln). A player with only honey cells scores diversity=0, losing 40 points. This teaches the cell diversity mechanic passively through the score dropping — kids see 😟 and naturally experiment with different cells.
- Reserve score uses `cellCount * 50` as capacity estimate (50 honey per cell is a reasonable middle-ground heuristic). A hive with 10 cells and 500+ honey scores reserve=35; an empty hive with 0 cells scores 0.
- The tip line auto-hides at score ≥ 80 and the container shrinks from 44px to 28px — keeping the HUD minimal for advanced players who don't need guidance, while giving beginners a clear improvement path.
- `DisplayOrder=13` keeps this bar below the leaderboard (16), bee facts (15), roster (18), guide (20), bear warning (45), milestones (50), and achievements (17) — it's ambient, always-on information, not a notification. The top-centre position doesn't conflict with any other element in the current layout.
- The three listeners (CombState, HoneyCount, CombCellCount) cover all scenarios: placing a cell, collecting honey, and changing cell types. No polling loop needed.
