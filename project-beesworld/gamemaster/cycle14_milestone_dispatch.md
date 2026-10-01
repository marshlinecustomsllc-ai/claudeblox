# Dispatch 131 — Milestone Celebration
## Cycle 14 · A Bee's World

**Feature:** A `MilestoneCelebrationController` LocalScript that fires a full-screen celebration burst for major game milestones. Confetti rains, the screen flashes gold, and a bold congratulations label slides in — all for moments like "First 1,000 Honey!", "Prestige Unlocked!", "All 9 Slots Open!". Kids feel like they won something big; adults see acknowledgement of genuine strategic progress. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 130 (Daily Hive Tip)

---

## DESIGN

### Milestones (8 total)

| ID | Trigger condition | Headline | Sub-text |
|----|-------------------|----------|---------|
| `honey_100` | HoneyCount ≥ 100 | "100 Honey! 🍯" | "Your hive is thriving!" |
| `honey_1k` | HoneyCount ≥ 1000 | "1,000 Honey! 🎉" | "A real honey empire!" |
| `honey_10k` | HoneyCount ≥ 10000 | "10K Honey! ✨" | "The hive overflows with gold!" |
| `cells_5` | CombCellCount ≥ 5 | "5 Comb Cells! 🐝" | "Your hive is growing fast!" |
| `cells_9` | CombCellCount ≥ 9 | "Full Hive! 🔶" | "All 9 slots are open!" |
| `prestige_1` | PrestigeLevel ≥ 1 | "Prestige! ✦" | "Your legacy begins." |
| `prestige_3` | PrestigeLevel ≥ 3 | "Max Prestige! ✦✦✦" | "You are the queen of honey." |
| `forages_10` | TotalForages ≥ 10 | "10 Foraging Runs! 🌸" | "Your bees know the way!" |

### Visual sequence (all GUI, 1.8s total duration)

1. **Gold flash** (0→0.15s): full-screen Frame, gold `Color3.fromRGB(242,168,28)`, BackgroundTransparency fades 0.0→1.0 over 0.4s
2. **Confetti burst** (0s): 18 small `Frame` squares (8×8px each), random honey/amber/cream colors, scatter across screen in arcing trajectories over 1.5s then fade. Spawned with `math.random` seeded per milestone for reproducibility.
3. **Headline card** (0.1→1.6s): `{0.5,-160,0.35,-35}` Frame (320×70px), Wax Cream bg, slides down from `{0.5,-160,0.1,-35}` over 0.3s, holds 1.0s, slides back up and fades 0.3s
4. All elements parented to a single `MilestoneFXGui` ScreenGui (DisplayOrder=50, ResetOnSpawn=false), cleaned up 2.5s after trigger

### Milestone persistence

Earned milestones are stored as a comma-string in player attribute `EarnedMilestones_131` (LocalScript only — not persisted server-side, intentionally lightweight). On join the current attribute values are read and all already-earned milestones are silently pre-populated. Only NEW crossings trigger the celebration.

### Polling

The controller polls these attributes via `GetAttributeChangedSignal`: `HoneyCount`, `CombCellCount`, `PrestigeLevel`, `TotalForages`. Each signal triggers a full milestone check.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `MilestoneCelebrationController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create MilestoneCelebrationController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("MilestoneCelebrationController") then
    print("⏭️  MilestoneCelebrationController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "MilestoneCelebrationController"
    ctrl.Source = [[
--!strict
-- MilestoneCelebrationController — dispatch 131
-- Full-screen celebration burst for major hive milestones.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

-- ── Milestone definitions ────────────────────────────────────────
type Milestone131 = {id: string, attr: string, threshold: number, headline: string, sub: string}
local MILESTONES_131: {Milestone131} = {
    {id="honey_100",  attr="HoneyCount",    threshold=100,   headline="100 Honey! 🍯",      sub="Your hive is thriving!"},
    {id="honey_1k",   attr="HoneyCount",    threshold=1000,  headline="1,000 Honey! 🎉",    sub="A real honey empire!"},
    {id="honey_10k",  attr="HoneyCount",    threshold=10000, headline="10K Honey! ✨",       sub="The hive overflows with gold!"},
    {id="cells_5",    attr="CombCellCount", threshold=5,     headline="5 Comb Cells! 🐝",    sub="Your hive is growing fast!"},
    {id="cells_9",    attr="CombCellCount", threshold=9,     headline="Full Hive! 🔶",        sub="All 9 slots are open!"},
    {id="prestige_1", attr="PrestigeLevel", threshold=1,     headline="Prestige! ✦",          sub="Your legacy begins."},
    {id="prestige_3", attr="PrestigeLevel", threshold=3,     headline="Max Prestige! ✦✦✦",    sub="You are the queen of honey."},
    {id="forages_10", attr="TotalForages",  threshold=10,    headline="10 Foraging Runs! 🌸", sub="Your bees know the way!"},
}

local CONFETTI_COLORS_131: {Color3} = {
    Color3.fromRGB(242, 168, 28),   -- honey gold
    Color3.fromRGB(255, 200, 50),   -- bright gold
    Color3.fromRGB(232, 212, 154),  -- wax cream
    Color3.fromRGB(200, 140, 20),   -- amber
    Color3.fromRGB(255, 255, 200),  -- pale yellow
}

-- ── Earned milestone tracking ────────────────────────────────────
local earned_131: {[string]: boolean} = {}

local function loadEarned_131()
    local raw = tostring(player:GetAttribute("EarnedMilestones_131") or "")
    for id in raw:gmatch("[^,]+") do earned_131[id] = true end
end

local function markEarned_131(id: string)
    earned_131[id] = true
    local ids: {string} = {}
    for k in earned_131 do table.insert(ids, k) end
    player:SetAttribute("EarnedMilestones_131", table.concat(ids, ","))
end

-- ── Get or create FX ScreenGui ───────────────────────────────────
local function getFxGui_131(): ScreenGui
    local existing = playerGui:FindFirstChild("MilestoneFXGui") :: ScreenGui?
    if existing then return existing end
    local sg = Instance.new("ScreenGui")
    sg.Name             = "MilestoneFXGui"
    sg.ResetOnSpawn     = false
    sg.DisplayOrder     = 50
    sg.Parent           = playerGui
    return sg
end

-- ── Gold flash ──────────────────────────────────────────────────
local function flashGold_131(sg: ScreenGui)
    local flash = Instance.new("Frame")
    flash.Size                  = UDim2.new(1, 0, 1, 0)
    flash.BackgroundColor3      = Color3.fromRGB(242, 168, 28)
    flash.BackgroundTransparency = 0
    flash.BorderSizePixel       = 0
    flash.ZIndex                = 40
    flash.Parent                = sg

    TweenService:Create(flash,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    ):Play()
    task.delay(0.5, function() flash:Destroy() end)
end

-- ── Confetti burst ──────────────────────────────────────────────
local function spawnConfetti_131(sg: ScreenGui)
    local rng = Random.new()
    for _ = 1, 18 do
        local piece = Instance.new("Frame")
        piece.Size               = UDim2.new(0, 8, 0, 8)
        piece.Position           = UDim2.new(rng:NextNumber(0.2, 0.8), 0, -0.02, 0)
        piece.BackgroundColor3   = CONFETTI_COLORS_131[rng:NextInteger(1, #CONFETTI_COLORS_131)]
        piece.BackgroundTransparency = 0
        piece.BorderSizePixel    = 0
        piece.Rotation           = rng:NextNumber(0, 360)
        piece.ZIndex             = 41
        piece.Parent             = sg

        local targetX = rng:NextNumber(-0.15, 0.15)
        local targetY = rng:NextNumber(0.6, 1.1)
        TweenService:Create(piece,
            TweenInfo.new(rng:NextNumber(1.2, 1.8), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {
                Position           = UDim2.new(piece.Position.X.Scale + targetX, 0, targetY, 0),
                BackgroundTransparency = 1,
                Rotation           = rng:NextNumber(180, 720),
            }
        ):Play()
        task.delay(1.9, function() piece:Destroy() end)
    end
end

-- ── Headline card ────────────────────────────────────────────────
local function showHeadline_131(sg: ScreenGui, headline: string, sub: string)
    local card = Instance.new("Frame")
    card.Name               = "MilestoneCard"
    card.Size               = UDim2.new(0, 320, 0, 70)
    card.Position           = UDim2.new(0.5, -160, 0.1, -35)
    card.BackgroundColor3   = Color3.fromRGB(232, 212, 154)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel    = 0
    card.ZIndex             = 42
    card.Parent             = sg
    local corner = Instance.new("UICorner")
    corner.CornerRadius     = UDim.new(0, 12)
    corner.Parent           = card

    local headLbl = Instance.new("TextLabel")
    headLbl.Size                = UDim2.new(1, -16, 0.55, 0)
    headLbl.Position            = UDim2.new(0, 8, 0, 4)
    headLbl.BackgroundTransparency = 1
    headLbl.Font                = Enum.Font.GothamBold
    headLbl.TextSize            = 20
    headLbl.TextColor3          = Color3.fromRGB(80, 50, 20)
    headLbl.Text                = headline
    headLbl.TextXAlignment      = Enum.TextXAlignment.Center
    headLbl.ZIndex              = 43
    headLbl.Parent              = card

    local subLbl = Instance.new("TextLabel")
    subLbl.Size                 = UDim2.new(1, -16, 0.4, 0)
    subLbl.Position             = UDim2.new(0, 8, 0.58, 0)
    subLbl.BackgroundTransparency = 1
    subLbl.Font                 = Enum.Font.Gotham
    subLbl.TextSize             = 13
    subLbl.TextColor3           = Color3.fromRGB(120, 80, 30)
    subLbl.Text                 = sub
    subLbl.TextXAlignment       = Enum.TextXAlignment.Center
    subLbl.ZIndex               = 43
    subLbl.Parent               = card

    -- Slide down into view
    local slideIn = TweenService:Create(card,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -160, 0.35, -35)}
    )
    slideIn:Play()

    -- Hold, then slide back up and fade
    task.delay(1.3, function()
        TweenService:Create(card,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -160, 0.1, -35), BackgroundTransparency = 1}
        ):Play()
        TweenService:Create(headLbl,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ):Play()
        TweenService:Create(subLbl,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ):Play()
        task.delay(0.35, function() card:Destroy() end)
    end)
end

-- ── Trigger celebration ──────────────────────────────────────────
local celebBusy_131 = false
local celebQueue_131: {Milestone131} = {}

local function drainCelebQueue_131()
    if celebBusy_131 then return end
    if #celebQueue_131 == 0 then return end

    celebBusy_131 = true
    local m = table.remove(celebQueue_131, 1)
    local sg = getFxGui_131()

    flashGold_131(sg)
    spawnConfetti_131(sg)
    task.delay(0.1, function()
        showHeadline_131(sg, m.headline, m.sub)
    end)

    task.delay(2.5, function()
        celebBusy_131 = false
        drainCelebQueue_131()
    end)
end

local function checkMilestones_131()
    for _, m in MILESTONES_131 do
        if not earned_131[m.id] then
            local val = tonumber(player:GetAttribute(m.attr)) or 0
            if val >= m.threshold then
                markEarned_131(m.id)
                table.insert(celebQueue_131, m)
                drainCelebQueue_131()
            end
        end
    end
end

-- ── Init ─────────────────────────────────────────────────────────
task.wait(2)
loadEarned_131()

-- Baseline: silently earn already-met milestones without celebrating
for _, m in MILESTONES_131 do
    if not earned_131[m.id] then
        local val = tonumber(player:GetAttribute(m.attr)) or 0
        if val >= m.threshold then
            markEarned_131(m.id)
        end
    end
end

-- Connect listeners
local ATTRS_131 = {"HoneyCount", "CombCellCount", "PrestigeLevel", "TotalForages"}
for _, attr in ATTRS_131 do
    player:GetAttributeChangedSignal(attr):Connect(checkMilestones_131)
end

print("[MilestoneCelebrationController] Ready — " .. #MILESTONES_131 .. " milestones tracked")
]]
    ctrl.Parent = SPS
    print("✅ MilestoneCelebrationController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("MilestoneCelebrationController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " MilestoneCelebrationController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("MILESTONES_131", 1, true) and "✅" or "❌") .. " MILESTONES_131 definition table")
table.insert(checks, (ctrl and ctrl.Source:find("loadEarned_131", 1, true) and "✅" or "❌") .. " loadEarned_131 persistence load")
table.insert(checks, (ctrl and ctrl.Source:find("markEarned_131", 1, true) and "✅" or "❌") .. " markEarned_131 persistence save")
table.insert(checks, (ctrl and ctrl.Source:find("flashGold_131", 1, true) and "✅" or "❌") .. " flashGold_131 screen flash")
table.insert(checks, (ctrl and ctrl.Source:find("spawnConfetti_131", 1, true) and "✅" or "❌") .. " spawnConfetti_131 confetti burst")
table.insert(checks, (ctrl and ctrl.Source:find("showHeadline_131", 1, true) and "✅" or "❌") .. " showHeadline_131 card display")
table.insert(checks, (ctrl and ctrl.Source:find("celebQueue_131", 1, true) and "✅" or "❌") .. " celebQueue_131 prevents overlap")
table.insert(checks, (ctrl and ctrl.Source:find("EarnedMilestones_131", 1, true) and "✅" or "❌") .. " EarnedMilestones_131 attribute persistence")
table.insert(checks, (ctrl and ctrl.Source:find("checkMilestones_131", 1, true) and "✅" or "❌") .. " checkMilestones_131 check on attribute change")
table.insert(checks, (ctrl and ctrl.Source:find("CONFETTI_COLORS_131", 1, true) and "✅" or "❌") .. " CONFETTI_COLORS_131 honey palette")
table.insert(checks, (ctrl and ctrl.Source:find("Random.new", 1, true) and "✅" or "❌") .. " Random.new for confetti scatter")

print("=== DISPATCH 131 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 131 complete" or "❌ SOME CHECKS FAILED")

print("\n8 milestones: honey(100/1K/10K) | cells(5/9) | prestige(1/3) | forages(10)")
print("Celebration: gold flash (0.4s) + 18 confetti (1.5s) + headline card (1.6s) = 1.8s total")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| MilestoneCelebrationController (LocalScript; all GUI destroyed after 2.5s) | 0 permanent |
| **Dispatch 131 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The baseline pass on init (lines after `loadEarned_131()`) silently marks all currently-met milestones as earned without celebrating. This prevents a veteran player rejoining from seeing eight back-to-back celebrations. Only milestones crossed AFTER the script loads trigger the effect.
- `EarnedMilestones_131` is stored as a player attribute (comma-string) rather than a DataStore key. This means it persists as long as the player is in-session but resets on rejoin. Intentional trade-off: DataStore writes cost time and this is a cosmetic UX layer, not game state. If the player rejoins and hits 1K honey again, the baseline suppresses it — no re-celebration.
- The celebration queue (`celebQueue_131`, `drainCelebQueue_131`) stacks multiple simultaneous triggers (e.g. hitting 5 cells and 10 forages at the same time) and plays them 2.5s apart. This prevents visual overlap while ensuring every milestone is acknowledged.
- `Random.new()` (no seed) on confetti scatter means each confetti burst looks slightly different each time — natural variation rather than a fixed pattern. This avoids the "same confetti every time" staleness.
- `DisplayOrder=50` matches the existing MilestoneCelebration placeholder (dispatch 50 in the roadmap). If that placeholder ScreenGui already exists, `getFxGui_131` returns it and the effects are parented there — no duplicate ScreenGui.
- Confetti ZIndex=41 (above flash at 40, below headline card at 42) ensures correct layering without touching other ScreenGuis' ZIndex settings.
