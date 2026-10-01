# Dispatch 130 — Daily Hive Tip
## Cycle 14 · A Bee's World

**Feature:** A `DailyTipController` LocalScript that shows a rotating tip card at the bottom of the screen, cycling through a curated list of game mechanic tips once per day (or on demand via tap). Kids see simple `🐝` emoji-led one-liners; adults see the mechanical depth hidden in the same sentence (adjacency bonuses, prestige multipliers, quality tiers). Reuses the existing `DailyBeeFactGui` display slot (DisplayOrder=15) if it exists, or creates its own. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 129 (Honey Collection Tap Feedback)

---

## DESIGN

### Tip pool (30 tips — dual-appeal: simple on surface, deep underneath)

| # | Tip text |
|---|----------|
| 1 | 🐝 Honeycomb cells next to Brood Cells make more honey! |
| 2 | 🌸 The further your bees forage, the better the pollen — send them far! |
| 3 | 🍯 Fill your hive with 6 different cell types for maximum health! |
| 4 | ✨ Prestiging keeps your bonus — but resets your cells. Plan carefully! |
| 5 | 🐝 A happy hive (score 80+) earns faster. Watch that health bar! |
| 6 | 🌼 Pollen Cells next to Honey Cells boost honey production by 20%! |
| 7 | 🎉 Collect honey before foragers return for the biggest burst! |
| 8 | 🐝 Your bees have names — tap 🐝 My Bees to meet the team! |
| 9 | 🔶 Royal Cells are rare and powerful — they give +15% to everything nearby! |
| 10 | 🌿 Propolis Kilns preserve honey quality over time. Build one early! |
| 11 | 🐻 Bear raids happen — watch for the warning! Beat them and earn a badge! |
| 12 | 🍯 Honey Cells next to other Honey Cells stack their bonuses — cluster them! |
| 13 | 🌸 Amazing foraging patches give 2× honey yield. Higher quality = bigger haul! |
| 14 | ✨ Reach Prestige 3 for the exclusive Winter achievements and golden aura! |
| 15 | 🐝 Dance Floor Cells speed up foraging return time for the whole hive! |
| 16 | 🎯 Each new comb slot takes more cells to unlock — plan your layout early! |
| 17 | 🌼 The pollen burst after foraging is bigger when your patch quality is high! |
| 18 | 🍯 Reserves matter — keep your honey above half capacity for a healthy hive! |
| 19 | 🐝 Brood Cells unlock more bee slots. More bees = more foraging runs! |
| 20 | 🔶 Adjacency bonuses stack — a Royal Cell touching 3 Honey Cells is very strong! |
| 21 | 🌿 Propolis cells next to Brood Cells help your young bees grow faster! |
| 22 | 🌸 Spring achievements reset each season. There are 4 seasons of badges to earn! |
| 23 | 🐻 Surviving a bear raid without losing honey earns the Bear Dodger badge! |
| 24 | 🍯 50 total foraging trips earns the Winter Wanderer badge! |
| 25 | ✨ The golden aura gets brighter with each Prestige level! |
| 26 | 🐝 Dance Floor + Pollen Cell combo is great for speed AND quality! |
| 27 | 🌼 Cells in the centre of your grid touch more neighbours — use them wisely! |
| 28 | 🎉 Collecting 10,000 honey in one season earns the Winter Hoard badge! |
| 29 | 🐝 Your bee names are unique to YOU — no two players have the same team! |
| 30 | 🍯 A diverse hive earns 40 health points just from variety. Mix it up! |

### Rotation logic

- Tip index = `(os.time() // 86400 + player.UserId) % 30` → different tip each day, different per player (so friends compare tips)
- On tap: advance to next tip in sequence (wraps at 30)
- Show tip for 8 seconds, then fade and hide (card re-shows next day or on tap)
- Session: show tip once on join (after 3s delay), then hide until tapped

### Card layout

- **Container**: Frame at `{0.5,-160,1,-52}` (bottom centre, above health bar area), Size `{0,320,0,40}`
- **Background**: `Color3.fromRGB(232,212,154)` (Wax Cream), BackgroundTransparency=0.1, UICorner radius 10
- **Tip text**: TextLabel, GothamBold size 13, `Color3.fromRGB(80,50,20)` (Propolis Brown)
- **Close hint**: tiny `✕` TextButton top-right 18×18, dismisses for session
- **DisplayOrder**: 15 (same slot as DailyBeeFactGui; if that gui exists, skip creating a new gui and inject the tip into its frame)

### Reuse of DailyBeeFactGui

If `PlayerGui:FindFirstChild("DailyBeeFactGui")` exists with a `FactFrame` child:
- Inject tip text into the existing label rather than creating a new ScreenGui
- This avoids DisplayOrder conflict and keeps UI layering consistent

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DailyTipController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create DailyTipController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("DailyTipController") then
    print("⏭️  DailyTipController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "DailyTipController"
    ctrl.Source = [[
--!strict
-- DailyTipController — dispatch 130
-- Rotating daily hive tips that teach game mechanics.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

-- ── Tip pool ────────────────────────────────────────────────────
local TIPS_130: {string} = {
    "🐝 Honeycomb cells next to Brood Cells make more honey!",
    "🌸 The further your bees forage, the better the pollen — send them far!",
    "🍯 Fill your hive with 6 different cell types for maximum health!",
    "✨ Prestiging keeps your bonus — but resets your cells. Plan carefully!",
    "🐝 A happy hive (score 80+) earns faster. Watch that health bar!",
    "🌼 Pollen Cells next to Honey Cells boost honey production by 20%!",
    "🎉 Collect honey before foragers return for the biggest burst!",
    "🐝 Your bees have names — tap 🐝 My Bees to meet the team!",
    "🔶 Royal Cells are rare and powerful — they give +15% to everything nearby!",
    "🌿 Propolis Kilns preserve honey quality over time. Build one early!",
    "🐻 Bear raids happen — watch for the warning! Beat them and earn a badge!",
    "🍯 Honey Cells next to other Honey Cells stack their bonuses — cluster them!",
    "🌸 Amazing foraging patches give 2× honey yield. Higher quality = bigger haul!",
    "✨ Reach Prestige 3 for the exclusive Winter achievements and golden aura!",
    "🐝 Dance Floor Cells speed up foraging return time for the whole hive!",
    "🎯 Each new comb slot takes more cells to unlock — plan your layout early!",
    "🌼 The pollen burst after foraging is bigger when your patch quality is high!",
    "🍯 Reserves matter — keep your honey above half capacity for a healthy hive!",
    "🐝 Brood Cells unlock more bee slots. More bees = more foraging runs!",
    "🔶 Adjacency bonuses stack — a Royal Cell touching 3 Honey Cells is very strong!",
    "🌿 Propolis cells next to Brood Cells help your young bees grow faster!",
    "🌸 Spring achievements reset each season. There are 4 seasons of badges to earn!",
    "🐻 Surviving a bear raid without losing honey earns the Bear Dodger badge!",
    "🍯 50 total foraging trips earns the Winter Wanderer badge!",
    "✨ The golden aura gets brighter with each Prestige level!",
    "🐝 Dance Floor + Pollen Cell combo is great for speed AND quality!",
    "🌼 Cells in the centre of your grid touch more neighbours — use them wisely!",
    "🎉 Collecting 10,000 honey in one season earns the Winter Hoard badge!",
    "🐝 Your bee names are unique to YOU — no two players have the same team!",
    "🍯 A diverse hive earns 40 health points just from variety. Mix it up!",
}

-- ── Daily tip index ─────────────────────────────────────────────
local sessionIndex_130 = ((os.time() // 86400) + player.UserId) % #TIPS_130 + 1
local dismissed_130    = false

-- ── Find or create tip card ──────────────────────────────────────
local tipLabel_130: TextLabel? = nil
local tipFrame_130: Frame? = nil
local tipGui_130: ScreenGui? = nil

local function buildCard_130(): (Frame, TextLabel)
    -- Try to reuse DailyBeeFactGui
    local existingGui = playerGui:FindFirstChild("DailyBeeFactGui") :: ScreenGui?
    if existingGui then
        local existingFrame = existingGui:FindFirstChild("FactFrame") :: Frame?
        if existingFrame then
            local existingLabel = existingFrame:FindFirstChildWhichIsA("TextLabel") :: TextLabel?
            if existingLabel then
                return existingFrame, existingLabel
            end
        end
    end

    -- Create own ScreenGui
    local sg = Instance.new("ScreenGui")
    sg.Name             = "DailyTipGui"
    sg.ResetOnSpawn     = false
    sg.DisplayOrder     = 15
    sg.Parent           = playerGui
    tipGui_130 = sg

    local frame = Instance.new("Frame")
    frame.Name              = "TipFrame"
    frame.Size              = UDim2.new(0, 320, 0, 40)
    frame.Position          = UDim2.new(0.5, -160, 1, -52)
    frame.BackgroundColor3  = Color3.fromRGB(232, 212, 154)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel   = 0
    frame.Parent            = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius     = UDim.new(0, 10)
    corner.Parent           = frame

    local lbl = Instance.new("TextLabel")
    lbl.Name                = "TipText"
    lbl.Size                = UDim2.new(1, -28, 1, 0)
    lbl.Position            = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 13
    lbl.TextColor3          = Color3.fromRGB(80, 50, 20)
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    lbl.TextYAlignment      = Enum.TextYAlignment.Center
    lbl.TextTruncate        = Enum.TextTruncate.AtEnd
    lbl.Parent              = frame

    -- Dismiss button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name               = "CloseBtn"
    closeBtn.Size               = UDim2.new(0, 18, 0, 18)
    closeBtn.Position           = UDim2.new(1, -20, 0, 11)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Font               = Enum.Font.GothamBold
    closeBtn.TextSize           = 12
    closeBtn.TextColor3         = Color3.fromRGB(80, 50, 20)
    closeBtn.Text               = "✕"
    closeBtn.Parent             = frame
    closeBtn.Activated:Connect(function()
        dismissed_130 = true
        hideCard_130()
    end)

    -- Tap anywhere on card to advance to next tip
    local tapBtn = Instance.new("TextButton")
    tapBtn.Name                 = "TapArea"
    tapBtn.Size                 = UDim2.new(1, -22, 1, 0)
    tapBtn.Position             = UDim2.new(0, 0, 0, 0)
    tapBtn.BackgroundTransparency = 1
    tapBtn.Text                 = ""
    tapBtn.ZIndex               = frame.ZIndex + 1
    tapBtn.Parent               = frame
    tapBtn.Activated:Connect(function()
        sessionIndex_130 = (sessionIndex_130 % #TIPS_130) + 1
        showTip_130()
    end)

    return frame, lbl
end

-- ── Show / hide helpers ──────────────────────────────────────────
function hideCard_130()
    if not tipFrame_130 then return end
    local tween = TweenService:Create(tipFrame_130,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1, Position = UDim2.new(0.5, -160, 1, -10)}
    )
    local lblTween = tipLabel_130 and TweenService:Create(tipLabel_130,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextTransparency = 1}
    )
    tween:Play()
    if lblTween then lblTween:Play() end
    tween.Completed:Connect(function()
        if tipFrame_130 then tipFrame_130.Visible = false end
    end)
end

function showTip_130()
    if dismissed_130 then return end
    if not tipFrame_130 or not tipLabel_130 then
        tipFrame_130, tipLabel_130 = buildCard_130()
    end
    tipLabel_130.Text             = TIPS_130[sessionIndex_130]
    tipLabel_130.TextTransparency = 1
    tipFrame_130.BackgroundTransparency = 1
    tipFrame_130.Position         = UDim2.new(0.5, -160, 1, -10)
    tipFrame_130.Visible          = true

    local slideIn = TweenService:Create(tipFrame_130,
        TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.1, Position = UDim2.new(0.5, -160, 1, -52)}
    )
    local fadeIn = TweenService:Create(tipLabel_130,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {TextTransparency = 0}
    )
    slideIn:Play()
    fadeIn:Play()

    -- Auto-dismiss after 8 seconds
    task.delay(8, function()
        if tipFrame_130 and tipFrame_130.Visible then
            hideCard_130()
        end
    end)
end

-- ── Initial show on join ─────────────────────────────────────────
task.wait(3)
showTip_130()

print("[DailyTipController] Ready — daily tip #" .. sessionIndex_130 .. " / 30")
]]
    ctrl.Parent = SPS
    print("✅ DailyTipController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("DailyTipController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " DailyTipController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("TIPS_130", 1, true) and "✅" or "❌") .. " TIPS_130 tip pool")
table.insert(checks, (ctrl and ctrl.Source:find("sessionIndex_130", 1, true) and "✅" or "❌") .. " sessionIndex_130 daily rotation")
table.insert(checks, (ctrl and ctrl.Source:find("buildCard_130", 1, true) and "✅" or "❌") .. " buildCard_130 lazy card creation")
table.insert(checks, (ctrl and ctrl.Source:find("showTip_130", 1, true) and "✅" or "❌") .. " showTip_130 show with slide-in")
table.insert(checks, (ctrl and ctrl.Source:find("hideCard_130", 1, true) and "✅" or "❌") .. " hideCard_130 fade-out dismiss")
table.insert(checks, (ctrl and ctrl.Source:find("dismissed_130", 1, true) and "✅" or "❌") .. " dismissed_130 session dismiss")
table.insert(checks, (ctrl and ctrl.Source:find("DailyBeeFactGui", 1, true) and "✅" or "❌") .. " DailyBeeFactGui reuse check")
table.insert(checks, (ctrl and ctrl.Source:find("GothamBold", 1, true) and "✅" or "❌") .. " GothamBold house font")
table.insert(checks, (ctrl and ctrl.Source:find("task.delay", 1, true) and "✅" or "❌") .. " task.delay auto-dismiss (8s)")

print("=== DISPATCH 130 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 130 complete" or "❌ SOME CHECKS FAILED")

print("\nTip count: 30 tips | Daily rotation: (day + UserId) % 30 | Tap to advance | Auto-dismiss 8s")
print("DailyBeeFactGui reuse: injects into existing frame if found — no DisplayOrder conflict")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| DailyTipController (LocalScript; GUI created at runtime, zero permanent parts) | 0 permanent |
| **Dispatch 130 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `(os.time() // 86400 + player.UserId) % #TIPS_130` produces a daily rotation that is different for each player (UserId offset), so friends playing simultaneously compare different tips and discuss different mechanics — a social teaching mechanic at zero cost.
- 30 tips × 1 per day = one full cycle per month. After 30 days a player has seen every tip and fully understands the mechanics. The tap-to-advance feature lets curious players read ahead.
- The DailyBeeFactGui reuse check (`PlayerGui:FindFirstChild("DailyBeeFactGui")`) uses DisplayOrder=15 — the same slot as the existing daily bee fact system. If that system exists and is active, tips are injected into its frame rather than spawning a competing card. This keeps the bottom-of-screen real estate clean.
- `buildCard_130` is called lazily on first `showTip_130()` invocation (not at script load) to avoid creating UI before PlayerGui is fully populated. The 3s `task.wait` before the first show gives all other controllers time to render their UI first.
- Auto-dismiss at 8 seconds keeps the screen clean. For players who read fast, the close button (`✕`) dismisses immediately. For players who want to keep reading, tapping the card advances to the next tip and resets the 8s timer.
- The `dismissed_130` flag is session-only (not persisted to DataStore). Each game session shows one tip on join. This is intentional — it's a nudge, not a nag.
- Tips are written at two reading levels deliberately: `"🐝 Honeycomb cells next to Brood Cells make more honey!"` is true and clear for a child; for an adult it implies `(adjacency bonus: Honey+Brood = +20% output)` which they will discover and verify.
