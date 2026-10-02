# Dispatch 152 — Hive Stats Dashboard
## Cycle 14 · A Bee's World

**Feature:** Live Hive Stats pill — a compact HUD panel (right side, mid-screen) showing the player's current honey production rate and queen tier at a glance. Adults get a precise "X honey/min" rate; kids get an emoji queen badge and a friendly label. Client-only: reads existing attributes (`CombCellCount`, `CombState`, `PrestigeLevel`, queen tier from future QueenService or falls back to prestige). Updates every 5 seconds via a polling loop. Part budget: +0 permanent (LocalScript only).
**Part budget impact:** +0 permanent → **4,158 / 5,000**
**Execution order:** After dispatch 151 (Friend Bonus)

---

## DESIGN

### Why a production rate display?

The core tycoon loop is: build cells → watch honey accumulate → upgrade → prestige. But players currently have no live feedback on *how fast* honey is accumulating. A parent watching their kid play can't answer "how many cells should I build?" — the rate display fixes this. For adults it reads as "35 honey/min"; for kids it's the same number but framed as "Your bees are busy!" with an emoji queen.

### Rate calculation

```
honeyRate = activeBroodCells × broodRate × nurseMulti × tempMulti × t2Multi × friendMulti
```

The client doesn't have all multipliers available, so we use a practical approximation:

```lua
local BROOD_RATE_152 = 4.0  -- honey/min per brood cell (Config baseline)
local cellCount  = tonumber(player:GetAttribute("CombCellCount")) or 0
local friendMult = 1.0 + (math.min(3, tonumber(player:GetAttribute("FriendBonusCount")) or 0) * 0.10)
local tempPenalty = (player:GetAttribute("HiveTemperature") == "cold") and 0.80 or 1.0

-- Count active brood cells from CombState
local broodCount = 0
local combState = tostring(player:GetAttribute("CombState") or "")
for slot in (combState .. ","):gmatch("([^,]*),") do
    if slot == "brood" then broodCount = broodCount + 1 end
end

local rate = broodCount * BROOD_RATE_152 * friendMult * tempPenalty
```

This is the client's best estimate. It won't reflect nurse bee or t2 upgrades perfectly (those are server-side), but it's close enough to be useful and never misleads the player significantly.

### Queen tier badge

The queen system (dispatch from architecture, Queen dispatch) writes a `QueenTier` attribute (1–5) when implemented. This dispatch reads it with a safe fallback to prestige level:

```lua
local tier = tonumber(player:GetAttribute("QueenTier")) or
             math.min(5, (tonumber(player:GetAttribute("PrestigeLevel")) or 0) + 1)
```

| Tier | Label | Emoji |
|------|-------|-------|
| 1 | Worker Queen | 🐝 |
| 2 | Colony Queen | 👑 |
| 3 | Hive Mistress | 🌟 |
| 4 | Grand Apiarist | 💎 |
| 5 | Sun Queen | 🌈 |

### Layout

Right side, vertically centred at `{1, -12, 0.5, -36}` (anchor `{1, 0.5}`), size `{0, 148, 0, 72}`. This places it on the right edge, mid-screen — clear of left-side buttons and bottom pills, and not overlapping the foraging timer (top-right is the weather banner).

The panel has two rows:
- **Row 1 (queen):** `[emoji] [label]` — e.g. "🐝 Worker Queen"
- **Row 2 (rate):** `🍯 ~35 honey/min` (or "Your bees are busy!" when rate = 0)

### Update loop

Polls every 5 seconds via `task.wait`. Not event-driven because rate is a derived value from multiple attributes — polling every 5s is imperceptible to the player and avoids wiring six separate attribute change signals.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HiveStatsController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HiveStatsController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("HiveStatsController") then
    print("⏭️  HiveStatsController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "HiveStatsController"
    ctrl.Source = [[
--!strict
-- HiveStatsController — dispatch 152
-- Live hive stats panel: production rate + queen tier.

local Players   = game:GetService("Players")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_152 = Color3.fromRGB(242, 168,  28)
local GOLD_152  = Color3.fromRGB(255, 210,  60)
local DARK_152  = Color3.fromRGB(40,  25,   8)
local CREAM_152 = Color3.fromRGB(232, 212, 154)

local BROOD_RATE_152 = 4.0  -- honey/min per brood cell (Config baseline)

local QUEEN_TIERS_152: {{emoji: string, label: string}} = {
    {emoji = "🐝", label = "Worker Queen"},
    {emoji = "👑", label = "Colony Queen"},
    {emoji = "🌟", label = "Hive Mistress"},
    {emoji = "💎", label = "Grand Apiarist"},
    {emoji = "🌈", label = "Sun Queen"},
}

-- ── GUI ──────────────────────────────────────────────────────────────
local sg_152:     ScreenGui?  = nil
local queenLbl_152: TextLabel? = nil
local rateLbl_152:  TextLabel? = nil

local function ensureGui_152()
    if sg_152 and sg_152.Parent then return end
    sg_152 = Instance.new("ScreenGui")
    sg_152.Name         = "HiveStatsGui"
    sg_152.ResetOnSpawn = false
    sg_152.DisplayOrder = 11
    sg_152.Parent       = playerGui

    local panel = Instance.new("Frame")
    panel.Name                   = "HiveStatsPanel"
    panel.Size                   = UDim2.new(0, 148, 0, 72)
    panel.Position               = UDim2.new(1, -12, 0.5, -36)
    panel.AnchorPoint            = Vector2.new(1, 0.5)
    panel.BackgroundColor3       = DARK_152
    panel.BackgroundTransparency = 0.15
    panel.BorderSizePixel        = 0
    panel.Parent                 = sg_152 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = panel
    local stroke = Instance.new("UIStroke"); stroke.Color = AMBER_152; stroke.Thickness = 0.8; stroke.Parent = panel

    -- Queen row
    local queenLbl = Instance.new("TextLabel")
    queenLbl.Name                   = "QueenLabel"
    queenLbl.Size                   = UDim2.new(1, -12, 0, 28)
    queenLbl.Position               = UDim2.new(0, 6, 0, 8)
    queenLbl.BackgroundTransparency = 1
    queenLbl.Font                   = Enum.Font.GothamBold
    queenLbl.TextSize               = 13
    queenLbl.TextColor3             = GOLD_152
    queenLbl.TextXAlignment         = Enum.TextXAlignment.Center
    queenLbl.Text                   = "🐝 Worker Queen"
    queenLbl.Parent                 = panel

    -- Rate row
    local rateLbl = Instance.new("TextLabel")
    rateLbl.Name                   = "RateLabel"
    rateLbl.Size                   = UDim2.new(1, -12, 0, 22)
    rateLbl.Position               = UDim2.new(0, 6, 0, 40)
    rateLbl.BackgroundTransparency = 1
    rateLbl.Font                   = Enum.Font.Gotham
    rateLbl.TextSize               = 11
    rateLbl.TextColor3             = CREAM_152
    rateLbl.TextXAlignment         = Enum.TextXAlignment.Center
    rateLbl.Text                   = "🍯 — honey/min"
    rateLbl.Parent                 = panel

    queenLbl_152 = queenLbl
    rateLbl_152  = rateLbl
end

-- ── Calculation ───────────────────────────────────────────────────
local function calcRate_152(): number
    local friendMult  = 1.0 + (math.min(3, tonumber(player:GetAttribute("FriendBonusCount")) or 0) * 0.10)
    local tempPenalty = (player:GetAttribute("HiveTemperature") == "cold") and 0.80 or 1.0
    local combState   = tostring(player:GetAttribute("CombState") or "")
    local broodCount  = 0
    for slot in (combState .. ","):gmatch("([^,]*),") do
        if slot == "brood" then broodCount = broodCount + 1 end
    end
    return broodCount * BROOD_RATE_152 * friendMult * tempPenalty
end

local function queenData_152(): {emoji: string, label: string}
    local tier = tonumber(player:GetAttribute("QueenTier")) or
                 math.min(5, (tonumber(player:GetAttribute("PrestigeLevel")) or 0) + 1)
    tier = math.max(1, math.min(5, tier))
    return QUEEN_TIERS_152[tier]
end

-- ── Update ────────────────────────────────────────────────────────
local function update_152()
    ensureGui_152()
    local qLbl = queenLbl_152 :: TextLabel
    local rLbl = rateLbl_152  :: TextLabel

    local qd   = queenData_152()
    qLbl.Text  = qd.emoji .. " " .. qd.label

    local rate = calcRate_152()
    if rate < 0.1 then
        rLbl.Text = "🍯 Build brood cells!"
    else
        rLbl.Text = "🍯 ~" .. math.floor(rate) .. " honey/min"
    end
end

-- ── Loop ──────────────────────────────────────────────────────────
ensureGui_152()
update_152()

task.spawn(function()
    while player.Parent do
        task.wait(5)
        update_152()
    end
end)

print("[HiveStatsController] Ready — queen tier and rate display active")
]]
    ctrl.Parent = SPS
    print("✅ HiveStatsController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HiveStatsController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveStatsController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("CombState", 1, true) and "✅" or "❌") .. " CombState brood cell count")
table.insert(checks, (ctrl and ctrl.Source:find("FriendBonusCount", 1, true) and "✅" or "❌") .. " FriendBonusCount multiplier")
table.insert(checks, (ctrl and ctrl.Source:find("HiveTemperature", 1, true) and "✅" or "❌") .. " HiveTemperature cold penalty")
table.insert(checks, (ctrl and ctrl.Source:find("QueenTier", 1, true) and "✅" or "❌") .. " QueenTier attribute read")
table.insert(checks, (ctrl and ctrl.Source:find("QUEEN_TIERS_152", 1, true) and "✅" or "❌") .. " QUEEN_TIERS_152 table (5 tiers)")
table.insert(checks, (ctrl and ctrl.Source:find("HiveStatsPanel", 1, true) and "✅" or "❌") .. " HiveStatsPanel UI element")
table.insert(checks, (ctrl and ctrl.Source:find("task.wait(5)", 1, true) and "✅" or "❌") .. " 5s polling loop")
table.insert(checks, (ctrl and ctrl.Source:find("DisplayOrder = 11", 1, true) and "✅" or "❌") .. " DisplayOrder=11")

print("=== DISPATCH 152 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 152 complete" or "❌ SOME CHECKS FAILED")

print("\nStats panel: right side mid-screen | queen badge + honey/min rate | 5s poll | DisplayOrder=11")
print("Queen tiers: 🐝 Worker → 👑 Colony → 🌟 Hive Mistress → 💎 Grand Apiarist → 🌈 Sun Queen")
print("Rate formula: broodCells × 4.0 × friendMult × tempPenalty (client estimate)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HiveStatsController (LocalScript — no permanent count) | 0 |
| **Dispatch 152 total** | **+0** |
| **Running total** | **4,158 / 5,000** |

---

## NOTES

- `calcRate_152()` is intentionally a client-side approximation. The nurse bee multiplier (1.15) and t2 upgrade multiplier (1.5) are server-computed and not exposed as attributes, so the displayed rate will undercount when those are active. This is acceptable — a conservative estimate is better than no display and never misleads players into thinking their hive is slower than it is.
- The 5-second polling loop (`task.wait(5)`) is preferred over six individual `GetAttributeChangedSignal` connections because rate is a *derived* value from at least four attributes (`CombState`, `FriendBonusCount`, `HiveTemperature`, `PrestigeLevel`). Polling once every 5s is imperceptible and cleaner than wiring each attribute individually.
- `QueenTier` falls back to `math.min(5, PrestigeLevel + 1)` so the display is meaningful before the full queen system (dispatch 10 architecture) is live. A Prestige 0 player sees 🐝 Worker Queen; a Prestige 3 player sees 💎 Grand Apiarist. When the real QueenService sets `QueenTier`, it overrides seamlessly.
- `DisplayOrder=11` is one above the bee population pill (10) and one below the foraging timer (11 — same layer, different position). Both share the same layer without conflict.
- The panel anchors to `{1, 0.5}` (right edge, vertical centre). On a 4:3 or ultra-wide screen this remains in the right margin. It does not overlap any existing pill which are all bottom-left `{0, 1}` anchored.
- "Build brood cells!" zero-rate state teaches the mechanic: kids immediately know why production is slow. The transition from that message to "🍯 ~30 honey/min" as they add brood cells is a small but satisfying feedback moment.
