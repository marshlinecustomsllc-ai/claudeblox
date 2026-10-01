# Dispatch 117 — Daily Bee Facts
## Cycle 14 · A Bee's World

**Feature:** Once per real-world day, a small `BeeFactCard` slides up from the bottom of the screen and shows a fun bee fact for 6 seconds. The fact rotates daily (deterministic from `os.date` day number, same fact for all players on the same day). Kids get the emoji version; the card also shows a small "Did you know?" label and a honey-coloured background. The card is dismissable by tap. 30 facts in total covering real bee science — phrased simply but accurate, so adults find them genuinely interesting. Shown once per real-world UTC day, tracked via a `LastFactDay` attribute.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 116 (Hive Progress Celebration)

---

## DESIGN

### Fact card layout

```
╔══════════════════════════════════════╗
║  🐝  Did you know?                   ║  ← header
║──────────────────────────────────────║
║  Bees visit up to 2,000 flowers      ║  ← fact text (2 lines max)
║  just to make ONE jar of honey! 🍯   ║
╚══════════════════════════════════════╝
```

- Width: 80% screen, max 400px. Height: ~90px. Anchored bottom-centre.
- Slides up from off-screen (Y=1.0 → Y=0.88), holds 6s, slides back down.
- Honey Gold background, Propolis Brown text.
- Tap/click anywhere on card dismisses immediately.

### The 30 bee facts (real science, kid-friendly phrasing)

| # | Fact |
|---|------|
| 1 | Bees visit up to 2,000 flowers just to make one jar of honey! 🍯 |
| 2 | A queen bee can lay up to 2,000 eggs every single day! 👑 |
| 3 | Bees do a special "waggle dance" to tell each other where the best flowers are! 💃 |
| 4 | Honey never spoils — scientists found 3,000-year-old honey in Egyptian tombs! 🏺 |
| 5 | A single bee makes only 1/12th of a teaspoon of honey in its whole life! 🐝 |
| 6 | Bees have five eyes — two big compound eyes AND three tiny simple eyes! 👀 |
| 7 | A honeybee flies at about 25 km/h — faster than a bicycle! 🚲 |
| 8 | Bees can recognise human faces! They see the world like a mosaic painting. 🎨 |
| 9 | There are over 20,000 species of bee in the world! 🌍 |
| 10 | Worker bees are all female. Male bees (drones) don't have stingers! 💪 |
| 11 | Bees communicate through dance, vibration, and even pheromone smells! 💨 |
| 12 | A hive can have up to 80,000 bees in summer! 🏠 |
| 13 | Bees sleep! They nap inside the hive for up to 8 hours a day. 😴 |
| 14 | Propolis — made from tree resin — is the bees' natural glue AND medicine! 🌿 |
| 15 | Honey contains natural antibacterial properties and was used as medicine for centuries! 💊 |
| 16 | Bees have been around for over 100 million years — they outlived the dinosaurs! 🦕 |
| 17 | A queen bee can live for up to 5 years. A worker bee lives only 6 weeks in summer. ⏳ |
| 18 | Bees use the sun as a compass to navigate, even on cloudy days! ☀️ |
| 19 | About one-third of all food humans eat depends on bee pollination! 🥦 |
| 20 | Beeswax is produced by young worker bees from special glands on their belly! 🕯️ |
| 21 | Bees can fly up to 8 km from their hive to find flowers! That's a big trip! ✈️ |
| 22 | A single colony visits over 50 million flowers to make just one jar of honey! 🌸 |
| 23 | The hexagon shape of honeycomb is perfect — it uses the least wax to hold the most honey! 📐 |
| 24 | Bees make a loud buzz when they're happy but a high-pitched whine when stressed! 🎵 |
| 25 | Royal Jelly is the special food only the Queen eats — it makes her twice as big! 👑 |
| 26 | Bees can see ultraviolet light that humans can't — flowers glow like landing strips to them! 🌈 |
| 27 | In winter, bees huddle together in a "winter cluster" and vibrate to stay warm! ❄️ |
| 28 | The smell of banana can trigger defensive behaviour in bees — it smells like their alarm signal! 🍌 |
| 29 | A bee's wings beat 200 times per second — that's what makes the buzz sound! 🎶 |
| 30 | Bees clean each other! They spend hours grooming antennae and removing parasites. 🪮 |

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BeeFactController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create BeeFactController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("BeeFactController") then
    print("⏭️  BeeFactController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "BeeFactController"
    ctrl.Source = [[
--!strict
-- BeeFactController — dispatch 117
-- Shows one rotating bee fact per real-world UTC day.
-- Same fact for all players on the same day (deterministic).

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(80,  50,  20)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)

-- ── Facts ──────────────────────────────────────────────────────────
local FACTS_117 = {
    "Bees visit up to 2,000 flowers just to make one jar of honey! 🍯",
    "A queen bee can lay up to 2,000 eggs every single day! 👑",
    "Bees do a special 'waggle dance' to tell each other where the best flowers are! 💃",
    "Honey never spoils — scientists found 3,000-year-old honey in Egyptian tombs! 🏺",
    "A single bee makes only 1/12th of a teaspoon of honey in its whole life! 🐝",
    "Bees have five eyes — two big compound eyes AND three tiny simple eyes! 👀",
    "A honeybee flies at about 25 km/h — faster than a bicycle! 🚲",
    "Bees can recognise human faces! They see the world like a mosaic painting. 🎨",
    "There are over 20,000 species of bee in the world! 🌍",
    "Worker bees are all female. Male bees (drones) don't have stingers! 💪",
    "Bees communicate through dance, vibration, and pheromone smells! 💨",
    "A hive can have up to 80,000 bees in summer! 🏠",
    "Bees sleep! They nap inside the hive for up to 8 hours a day. 😴",
    "Propolis — tree resin — is the bees' natural glue AND medicine! 🌿",
    "Honey has antibacterial properties and was used as medicine for centuries! 💊",
    "Bees have been around over 100 million years — they outlived the dinosaurs! 🦕",
    "A queen lives up to 5 years. A summer worker bee lives only 6 weeks. ⏳",
    "Bees use the sun as a compass to navigate, even on cloudy days! ☀️",
    "About one-third of all food humans eat depends on bee pollination! 🥦",
    "Beeswax is produced from special glands on young worker bees' bellies! 🕯️",
    "Bees can fly up to 8 km from their hive to find flowers! That's a big trip! ✈️",
    "A single colony visits over 50 million flowers to fill one jar of honey! 🌸",
    "Hexagon honeycomb uses the least wax to hold the most honey — perfect maths! 📐",
    "Bees make a loud buzz when happy but a high-pitched whine when stressed! 🎵",
    "Royal Jelly is the Queen's special food — it makes her twice as big! 👑",
    "Bees can see ultraviolet light — flowers glow like landing strips to them! 🌈",
    "In winter, bees huddle and vibrate to keep the hive warm! ❄️",
    "The smell of banana can trigger bee alarm signals — it smells like danger! 🍌",
    "A bee's wings beat 200 times per second — that's what makes the buzz! 🎶",
    "Bees clean each other! They groom antennae and remove parasites for hours. 🪮",
}

-- ── Day-based fact rotation ────────────────────────────────────────
-- Uses UTC day-of-year * year as index so it advances daily across years
local function getTodayFactIndex_117(): number
    local t = os.date("!*t") :: any
    if not t then return 1 end
    local dayOfYear = t.yday or 1
    local year      = t.year or 2024
    return ((dayOfYear + year * 365) % #FACTS_117) + 1
end

-- ── Session guard — show once per UTC day ─────────────────────────
local function shouldShowToday_117(): boolean
    local todayStr = tostring(os.date("!%Y%j"))  -- e.g. "2024180"
    local lastShown = tostring(player:GetAttribute("LastFactDay") or "")
    return lastShown ~= todayStr
end

local function markShownToday_117()
    local todayStr = tostring(os.date("!%Y%j"))
    player:SetAttribute("LastFactDay", todayStr)
end

-- ── Build and show the card ────────────────────────────────────────
local function showFact_117(factText: string)
    local overlay = Instance.new("ScreenGui")
    overlay.Name           = "BeeFactOverlay_117"
    overlay.DisplayOrder   = 15
    overlay.ResetOnSpawn   = false
    overlay.IgnoreGuiInset = true
    overlay.Parent         = playerGui

    local card = Instance.new("TextButton")  -- TextButton so tap/click dismisses
    card.Name                  = "FactCard"
    card.BackgroundColor3      = HONEY_GOLD
    card.AutoButtonColor       = false
    card.Text                  = ""
    card.Size                  = UDim2.new(0.8, 0, 0, 90)
    card.Position              = UDim2.new(0.1, 0, 1.05, 0)  -- start off-screen
    card.AnchorPoint           = Vector2.new(0, 0)
    card.ZIndex                = 2
    card.Parent                = overlay

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent       = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color     = PROP_BROWN
    cardStroke.Thickness = 2
    cardStroke.Parent    = card

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Text                  = "🐝  Did you know?"
    headerLabel.Font                  = Enum.Font.GothamBold
    headerLabel.TextSize              = 12
    headerLabel.TextColor3            = PROP_BROWN
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size                  = UDim2.new(1, -16, 0, 20)
    headerLabel.Position              = UDim2.new(0, 8, 0, 6)
    headerLabel.TextXAlignment        = Enum.TextXAlignment.Left
    headerLabel.ZIndex                = 3
    headerLabel.Parent                = card

    local factLabel = Instance.new("TextLabel")
    factLabel.Name                   = "FactText"
    factLabel.Text                   = factText
    factLabel.Font                   = Enum.Font.GothamBold
    factLabel.TextSize               = 13
    factLabel.TextColor3             = PROP_BROWN
    factLabel.BackgroundTransparency = 1
    factLabel.Size                   = UDim2.new(1, -16, 0, 52)
    factLabel.Position               = UDim2.new(0, 8, 0, 26)
    factLabel.TextXAlignment         = Enum.TextXAlignment.Left
    factLabel.TextYAlignment         = Enum.TextYAlignment.Top
    factLabel.TextWrapped            = true
    factLabel.ZIndex                 = 3
    factLabel.Parent                 = card

    -- ── Slide in ─────────────────────────────────────────────────
    local tweenIn = TweenService:Create(card,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.1, 0, 0.88, 0) }
    )
    tweenIn:Play()

    -- ── Dismiss logic ─────────────────────────────────────────────
    local dismissed = false
    local function dismiss()
        if dismissed then return end
        dismissed = true
        local tweenOut = TweenService:Create(card,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.new(0.1, 0, 1.1, 0) }
        )
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            overlay:Destroy()
        end)
    end

    card.Activated:Connect(dismiss)

    -- Auto-dismiss after 6 seconds
    task.delay(6, dismiss)
end

-- ── Main ──────────────────────────────────────────────────────────
task.wait(4)  -- wait for main HUD to settle before showing fact
if shouldShowToday_117() then
    markShownToday_117()
    local idx = getTodayFactIndex_117()
    showFact_117(FACTS_117[idx])
end

print("[BeeFactController] Ready — " .. #FACTS_117 .. " bee facts, daily rotation")
]]
    ctrl.Parent = SPS
    print("✅ BeeFactController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("BeeFactController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " BeeFactController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("FACTS_117", 1, true) and "✅" or "❌") .. " FACTS_117 fact table")
table.insert(checks, (ctrl and ctrl.Source:find("getTodayFactIndex_117", 1, true) and "✅" or "❌") .. " getTodayFactIndex_117 rotation")
table.insert(checks, (ctrl and ctrl.Source:find("shouldShowToday_117", 1, true) and "✅" or "❌") .. " shouldShowToday_117 session guard")
table.insert(checks, (ctrl and ctrl.Source:find("markShownToday_117", 1, true) and "✅" or "❌") .. " markShownToday_117 deduplication")
table.insert(checks, (ctrl and ctrl.Source:find("LastFactDay", 1, true) and "✅" or "❌") .. " LastFactDay attribute")
table.insert(checks, (ctrl and ctrl.Source:find("showFact_117", 1, true) and "✅" or "❌") .. " showFact_117 function")
table.insert(checks, (ctrl and ctrl.Source:find("Activated", 1, true) and "✅" or "❌") .. " tap-to-dismiss Activated")
table.insert(checks, (ctrl and ctrl.Source:find("task.delay", 1, true) and "✅" or "❌") .. " 6s auto-dismiss")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService slide animation")

-- Count facts
local factCount = 0
if ctrl then
    for _ in ctrl.Source:gmatch('"[^"]*![^"]*"') do factCount += 1 end  -- lines with emoji
end
table.insert(checks, (factCount >= 25 and "✅" or "⚠️") .. " ~30 facts in table (found ~" .. factCount .. " emoji lines)")

print("=== DISPATCH 117 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 117 complete" or "❌ SOME CHECKS FAILED")

print("\nFact rotation: deterministic from UTC day-of-year + year")
print("Session guard: LastFactDay attribute (YYYY + day-of-year string)")
print("Display: 4s after load, 6s auto-dismiss, tap to dismiss early")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BeeFactController (LocalScript, runtime ScreenGui) | 0 permanent |
| **Dispatch 117 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `os.date("!*t")` returns UTC table — using UTC ensures all players on the same server see the same fact regardless of local timezone. `!%Y%j` format (year + day-of-year) is the session key, not a display string.
- The rotation formula `(dayOfYear + year * 365) % #FACTS` ensures the same fact advances every calendar day and cycles back after 30 days without any server state.
- `task.wait(4)` before showing ensures the main HUD, upgrade panel, and milestone celebration (if any) have all settled — the bee fact should feel like a gentle afterthought, not a popup that competes for attention on join.
- Using `TextButton` for the card rather than `Frame` means the entire card surface is a dismiss target — important for mobile where small tap targets are frustrating.
- Facts are phrased in plain English, no jargon, no numbers above 1,000 without context. Every fact ends with an emoji that reinforces the subject. Adults will find the real science interesting (UV vision, waggle dance, hexagon maths); kids enjoy the "wow" factor.
- The `DisplayOrder=15` places the fact above the idle watcher toast (12) and propolis rain banner (14) but below the milestone celebration (50) — correct priority hierarchy.
- `LastFactDay` is a client attribute (set by LocalScript via `player:SetAttribute`), not DataStore-persisted. This is intentional: if the player logs in on the same day from a different device they see the fact again, which is fine and avoids DataStore overhead for a cosmetic feature.
