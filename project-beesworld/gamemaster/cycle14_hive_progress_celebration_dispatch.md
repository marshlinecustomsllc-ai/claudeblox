# Dispatch 116 — Hive Progress Celebration
## Cycle 14 · A Bee's World

**Feature:** Every time a player's hive reaches a significant milestone (5, 10, 15, 20, 25, 30, 40, 50 cells built; prestige 1, 2, 3; 100/500/1000 honey collected lifetime), a full-screen celebration overlay fires for 3 seconds. For kids: large emoji, confetti particles, a punchy headline ("Your hive is BUZZING! 🐝🐝🐝"), and an animated star burst. For adults: the secondary text shows exactly what changed ("Hive capacity +50%, new Propolis Kiln slot unlocked"). The overlay then slides away and the player is back in the game. Each milestone fires once per account (tracked via DataStore-safe `HiveMilestones` attribute on the player).
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 115 (Placement Bonus Preview)

---

## DESIGN

### Milestones

| ID | Trigger | Kid Headline | Adult Detail |
|----|---------|-------------|--------------|
| `cells_5` | 5 cells built | "Your hive is growing! 🌱" | "5 cells — forage speed +10%" |
| `cells_10` | 10 cells built | "Look at that hive! 🏠" | "10 cells — new slot unlocked" |
| `cells_15` | 15 cells built | "Halfway to a full hive! 🐝" | "15 cells — hive capacity +30%" |
| `cells_20` | 20 cells built | "Super hive! 🌟" | "20 cells — propolis bonus active" |
| `cells_25` | 25 cells built | "Almost full! Keep building! 🔥" | "25 cells — efficiency +20%" |
| `cells_30` | 30 cells built | "30 cells! You're a pro! 🏆" | "30 cells — Royal cell unlocked" |
| `cells_40` | 40 cells built | "Massive hive! Incredible! 💥" | "40 cells — prestige cost −10%" |
| `cells_50` | 50 cells built | "FULL HIVE! You did it! 🎉🎉🎉" | "50 cells — Full Hive Bonus active!" |
| `prestige_1` | First prestige | "You PRESTIGED! So awesome! 👑" | "Prestige 1 — golden aura + 1.5× earnings" |
| `prestige_2` | Prestige 2 | "Double prestige! Legendary! 🌟" | "Prestige 2 — enhanced aura + 2× earnings" |
| `prestige_3` | Prestige 3+ | "Prestige Master! 🔮" | "Prestige 3+ — maximum aura unlocked" |
| `honey_100` | 100 honey lifetime | "100 jars of honey! Sweet! 🍯" | "100 honey collected lifetime" |
| `honey_500` | 500 honey lifetime | "500 honey! Honey tycoon! 🐝" | "Top 10% of beekeepers!" |
| `honey_1000` | 1000 honey lifetime | "1000 HONEY! LEGENDARY! 🏆" | "You're a master beekeeper!" |

### Visual design

Full-screen overlay (invisible to other players — `ScreenGui`, not Workspace):

```
╔══════════════════════════════════════╗
║                                      ║  ← dark semi-transparent BG
║        🎉  MILESTONE  🎉            ║
║                                      ║
║   ┌────────────────────────────┐    ║
║   │                            │    ║
║   │  🐝🐝🐝                   │    ║  ← animated confetti
║   │                            │    ║
║   │  Your hive is growing! 🌱  │    ║  ← kid headline (large)
║   │                            │    ║
║   │  5 cells — forage +10%    │    ║  ← adult detail (small)
║   │                            │    ║
║   └────────────────────────────┘    ║
║                                      ║
╚══════════════════════════════════════╝
```

- Centre card: 360×220 (Scale-based)
- BG overlay: full screen, DARK_BG at 0.5 transparency → fades in
- Card: slides up from Y+0.1 with Back easing, then slides away and fades after 3s
- Confetti: 2-second `ParticleEmitter` burst on a BillboardGui anchor (disabled after burst)
- Headline: GothamBold 28px, HONEY_GOLD
- Detail: Gotham 14px, WAX_CREAM

### Milestone tracking

Server sets `HiveMilestones` attribute on player as a comma-separated string of fired milestone IDs:  
`"cells_5,cells_10,honey_100"` — client checks before showing to avoid repeats.

Client listens for a `HiveMilestoneSync` RemoteEvent: `{milestoneId: string}` — server fires this whenever a new milestone is reached for a player. The client then shows the celebration if the milestone hasn't been shown this session.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HiveMilestoneCelebration` | New LocalScript in StarterPlayerScripts |
| `HiveMilestoneSync` | New RemoteEvent in ReplicatedStorage |
| `HiveMilestoneService` | New Script in ServerScriptService |

---

## STEP A — Create HiveMilestoneSync RemoteEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
if RS:FindFirstChild("HiveMilestoneSync") then
    print("⏭️  HiveMilestoneSync already exists — skip")
else
    local re = Instance.new("RemoteEvent")
    re.Name   = "HiveMilestoneSync"
    re.Parent = RS
    print("✅ HiveMilestoneSync RemoteEvent created in ReplicatedStorage")
end
```

---

## STEP B — Create HiveMilestoneService (server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("HiveMilestoneService") then
    print("⏭️  HiveMilestoneService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "HiveMilestoneService"
    svc.Source = [[
--!strict
-- HiveMilestoneService — dispatch 116
-- Watches player stats and fires HiveMilestoneSync when milestones are reached.

local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")

local HiveMilestoneSync = RS:WaitForChild("HiveMilestoneSync") :: RemoteEvent

-- Milestone definitions: {id, stat, threshold}
type MilestoneDef = {id: string, stat: string, threshold: number}
local MILESTONES_116: {MilestoneDef} = {
    {id="cells_5",    stat="CombCellCount",    threshold=5   },
    {id="cells_10",   stat="CombCellCount",    threshold=10  },
    {id="cells_15",   stat="CombCellCount",    threshold=15  },
    {id="cells_20",   stat="CombCellCount",    threshold=20  },
    {id="cells_25",   stat="CombCellCount",    threshold=25  },
    {id="cells_30",   stat="CombCellCount",    threshold=30  },
    {id="cells_40",   stat="CombCellCount",    threshold=40  },
    {id="cells_50",   stat="CombCellCount",    threshold=50  },
    {id="prestige_1", stat="PrestigeLevel",    threshold=1   },
    {id="prestige_2", stat="PrestigeLevel",    threshold=2   },
    {id="prestige_3", stat="PrestigeLevel",    threshold=3   },
    {id="honey_100",  stat="HoneyLifetime",    threshold=100 },
    {id="honey_500",  stat="HoneyLifetime",    threshold=500 },
    {id="honey_1000", stat="HoneyLifetime",    threshold=1000},
}

local function getFiredSet_116(player: Player): {[string]: boolean}
    local raw = player:GetAttribute("HiveMilestones") or ""
    local set: {[string]: boolean} = {}
    for id in tostring(raw):gmatch("[^,]+") do
        set[id] = true
    end
    return set
end

local function markFired_116(player: Player, milestoneId: string)
    local raw = tostring(player:GetAttribute("HiveMilestones") or "")
    if raw == "" then
        player:SetAttribute("HiveMilestones", milestoneId)
    else
        player:SetAttribute("HiveMilestones", raw .. "," .. milestoneId)
    end
end

local function checkMilestones_116(player: Player, statName: string)
    local value = tonumber(player:GetAttribute(statName)) or 0
    local fired = getFiredSet_116(player)
    for _, def in MILESTONES_116 do
        if def.stat == statName and value >= def.threshold and not fired[def.id] then
            markFired_116(player, def.id)
            HiveMilestoneSync:FireClient(player, {milestoneId = def.id})
        end
    end
end

-- Watch all milestone-related attributes on each player
local WATCH_ATTRS_116 = {"CombCellCount", "PrestigeLevel", "HoneyLifetime"}

Players.PlayerAdded:Connect(function(player)
    for _, attr in WATCH_ATTRS_116 do
        player:GetAttributeChangedSignal(attr):Connect(function()
            checkMilestones_116(player, attr)
        end)
    end
    -- Check on join in case they already passed a threshold before this script ran
    task.wait(3)
    for _, attr in WATCH_ATTRS_116 do
        checkMilestones_116(player, attr)
    end
end)

-- Handle players already in server
for _, player in Players:GetPlayers() do
    task.spawn(function()
        for _, attr in WATCH_ATTRS_116 do
            player:GetAttributeChangedSignal(attr):Connect(function()
                checkMilestones_116(player, attr)
            end)
        end
    end)
end

print("[HiveMilestoneService] Ready — watching CombCellCount, PrestigeLevel, HoneyLifetime")
]]
    svc.Parent = SSS
    print("✅ HiveMilestoneService created in ServerScriptService")
end
```

---

## STEP C — Create HiveMilestoneCelebration LocalScript

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HiveMilestoneCelebration") then
    print("⏭️  HiveMilestoneCelebration already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HiveMilestoneCelebration"
    ctrl.Source = [[
--!strict
-- HiveMilestoneCelebration — dispatch 116
-- Shows a full-screen celebration overlay when a hive milestone is reached.
-- Kid-friendly headline + optional adult detail. Fires and forgets.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HiveMilestoneSync = RS:WaitForChild("HiveMilestoneSync", 10) :: RemoteEvent?
if not HiveMilestoneSync then
    warn("[HiveMilestoneCelebration] HiveMilestoneSync not found — aborting")
    return
end

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(80,  50,  20)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local DARK_BG     = Color3.fromRGB(20,  12,   4)

-- ── Milestone data ─────────────────────────────────────────────────
type MilestoneDisplay = {headline: string, detail: string, emoji: string}
local DISPLAY_116: {[string]: MilestoneDisplay} = {
    cells_5    = { headline="Your hive is growing! 🌱",      detail="5 cells — forage speed +10%",       emoji="🌱" },
    cells_10   = { headline="Look at that hive! 🏠",          detail="10 cells — new slot unlocked",       emoji="🏠" },
    cells_15   = { headline="Halfway to a full hive! 🐝",    detail="15 cells — hive capacity +30%",      emoji="🐝" },
    cells_20   = { headline="Super hive! 🌟",                 detail="20 cells — propolis bonus active",   emoji="🌟" },
    cells_25   = { headline="Almost full! Keep building! 🔥", detail="25 cells — efficiency +20%",        emoji="🔥" },
    cells_30   = { headline="30 cells! You're a pro! 🏆",    detail="30 cells — Royal cell unlocked",     emoji="🏆" },
    cells_40   = { headline="Massive hive! Incredible! 💥",   detail="40 cells — prestige cost −10%",     emoji="💥" },
    cells_50   = { headline="FULL HIVE! You did it! 🎉",      detail="50 cells — Full Hive Bonus active!", emoji="🎉" },
    prestige_1 = { headline="You PRESTIGED! So awesome! 👑", detail="Prestige 1 — 1.5× earnings",         emoji="👑" },
    prestige_2 = { headline="Double prestige! Legendary! 🌟", detail="Prestige 2 — 2× earnings",          emoji="🌟" },
    prestige_3 = { headline="Prestige Master! 🔮",            detail="Prestige 3+ — max aura unlocked",   emoji="🔮" },
    honey_100  = { headline="100 jars of honey! Sweet! 🍯",   detail="100 honey collected lifetime",      emoji="🍯" },
    honey_500  = { headline="500 honey! Honey tycoon! 🐝",    detail="Top 10% of beekeepers!",            emoji="🐝" },
    honey_1000 = { headline="1000 HONEY! LEGENDARY! 🏆",      detail="You're a master beekeeper!",        emoji="🏆" },
}

-- ── Queue (handle rapid-fire milestones gracefully) ────────────────
local queue_116: {string} = {}
local showing_116 = false

local function showCelebration_116(milestoneId: string)
    local data = DISPLAY_116[milestoneId]
    if not data then return end

    -- ── Build overlay ────────────────────────────────────────────
    local overlay = Instance.new("ScreenGui")
    overlay.Name           = "MilestoneOverlay_116"
    overlay.DisplayOrder   = 50
    overlay.ResetOnSpawn   = false
    overlay.IgnoreGuiInset = true
    overlay.Parent         = playerGui

    -- Dark background
    local bg = Instance.new("Frame")
    bg.BackgroundColor3       = DARK_BG
    bg.BackgroundTransparency = 0.5
    bg.Size                   = UDim2.new(1, 0, 1, 0)
    bg.BorderSizePixel        = 0
    bg.ZIndex                 = 1
    bg.Parent                 = overlay

    -- Centre card
    local card = Instance.new("Frame")
    card.BackgroundColor3       = Color3.fromRGB(40, 24, 8)
    card.BackgroundTransparency = 0.08
    card.Size                   = UDim2.new(0, 360, 0, 220)
    card.Position               = UDim2.new(0.5, -180, 0.6, -110)  -- start below
    card.AnchorPoint            = Vector2.new(0, 0)
    card.ZIndex                 = 2
    card.Parent                 = overlay

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 16)
    cardCorner.Parent       = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color     = HONEY_GOLD
    cardStroke.Thickness = 2.5
    cardStroke.Parent    = card

    -- Big emoji
    local emojiLabel = Instance.new("TextLabel")
    emojiLabel.Text                  = data.emoji
    emojiLabel.Font                  = Enum.Font.GothamBold
    emojiLabel.TextSize              = 40
    emojiLabel.BackgroundTransparency = 1
    emojiLabel.Size                  = UDim2.new(1, 0, 0, 50)
    emojiLabel.Position              = UDim2.new(0, 0, 0, 18)
    emojiLabel.TextXAlignment        = Enum.TextXAlignment.Center
    emojiLabel.ZIndex                = 3
    emojiLabel.Parent                = card

    -- MILESTONE header
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Text                  = "— MILESTONE! —"
    headerLabel.Font                  = Enum.Font.GothamBold
    headerLabel.TextSize              = 13
    headerLabel.TextColor3            = HONEY_GOLD
    headerLabel.BackgroundTransparency = 1
    headerLabel.Size                  = UDim2.new(1, 0, 0, 18)
    headerLabel.Position              = UDim2.new(0, 0, 0, 68)
    headerLabel.TextXAlignment        = Enum.TextXAlignment.Center
    headerLabel.ZIndex                = 3
    headerLabel.Parent                = card

    -- Kid headline
    local headlineLabel = Instance.new("TextLabel")
    headlineLabel.Text                  = data.headline
    headlineLabel.Font                  = Enum.Font.GothamBold
    headlineLabel.TextSize              = 22
    headlineLabel.TextColor3            = Color3.fromRGB(255, 230, 100)
    headlineLabel.BackgroundTransparency = 1
    headlineLabel.Size                  = UDim2.new(1, -24, 0, 52)
    headlineLabel.Position              = UDim2.new(0, 12, 0, 90)
    headlineLabel.TextXAlignment        = Enum.TextXAlignment.Center
    headlineLabel.TextWrapped           = true
    headlineLabel.ZIndex                = 3
    headlineLabel.Parent                = card

    -- Adult detail
    local detailLabel = Instance.new("TextLabel")
    detailLabel.Text                  = data.detail
    detailLabel.Font                  = Enum.Font.Gotham
    detailLabel.TextSize              = 13
    detailLabel.TextColor3            = WAX_CREAM
    detailLabel.BackgroundTransparency = 1
    detailLabel.Size                  = UDim2.new(1, -24, 0, 30)
    detailLabel.Position              = UDim2.new(0, 12, 0, 148)
    detailLabel.TextXAlignment        = Enum.TextXAlignment.Center
    detailLabel.TextWrapped           = true
    detailLabel.ZIndex                = 3
    detailLabel.Parent                = card

    -- ── Animate in ───────────────────────────────────────────────
    bg.BackgroundTransparency = 1
    TweenService:Create(bg, TweenInfo.new(0.25), { BackgroundTransparency = 0.5 }):Play()
    TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -180, 0.5, -110)
    }):Play()

    -- ── Hold then slide away ──────────────────────────────────────
    task.wait(3.2)
    local tOut = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position               = UDim2.new(0.5, -180, 0.35, -110),
        BackgroundTransparency = 0.95,
    })
    TweenService:Create(bg, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
    tOut:Play()
    tOut.Completed:Connect(function()
        overlay:Destroy()
        showing_116 = false
        -- Process next queued milestone
        if #queue_116 > 0 then
            local next = table.remove(queue_116, 1)
            showing_116 = true
            task.wait(0.3)
            showCelebration_116(next)
        end
    end)
end

-- ── Remote listener ───────────────────────────────────────────────
(HiveMilestoneSync :: RemoteEvent).OnClientEvent:Connect(function(data: {milestoneId: string})
    local mid = data and data.milestoneId
    if not mid then return end
    if showing_116 then
        table.insert(queue_116, mid)
    else
        showing_116 = true
        showCelebration_116(mid)
    end
end)

print("[HiveMilestoneCelebration] Ready — celebrating " .. #DISPLAY_116 .. " milestone tiers")
]]
    ctrl.Parent = SPS
    print("✅ HiveMilestoneCelebration created in StarterPlayerScripts")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local re   = RS:FindFirstChild("HiveMilestoneSync")
local svc  = SSS:FindFirstChild("HiveMilestoneService")
local ctrl = SPS and SPS:FindFirstChild("HiveMilestoneCelebration")

local checks = {}
table.insert(checks, (re and "✅" or "❌") .. " HiveMilestoneSync RemoteEvent in ReplicatedStorage")
table.insert(checks, (re and re:IsA("RemoteEvent") and "✅" or "❌") .. " is a RemoteEvent")
table.insert(checks, (svc and "✅" or "❌") .. " HiveMilestoneService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script (server-side)")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (server)")
table.insert(checks, (svc and svc.Source:find("MILESTONES_116", 1, true) and "✅" or "❌") .. " MILESTONES_116 table")
table.insert(checks, (svc and svc.Source:find("HiveMilestones", 1, true) and "✅" or "❌") .. " HiveMilestones attribute tracking")
table.insert(checks, (svc and svc.Source:find("HoneyLifetime", 1, true) and "✅" or "❌") .. " HoneyLifetime stat watched")
table.insert(checks, (svc and svc.Source:find("CombCellCount", 1, true) and "✅" or "❌") .. " CombCellCount stat watched")
table.insert(checks, (svc and svc.Source:find("PrestigeLevel", 1, true) and "✅" or "❌") .. " PrestigeLevel stat watched")
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveMilestoneCelebration in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (client)")
table.insert(checks, (ctrl and ctrl.Source:find("DISPLAY_116", 1, true) and "✅" or "❌") .. " DISPLAY_116 milestone display data")
table.insert(checks, (ctrl and ctrl.Source:find("showCelebration_116", 1, true) and "✅" or "❌") .. " showCelebration_116 function")
table.insert(checks, (ctrl and ctrl.Source:find("queue_116", 1, true) and "✅" or "❌") .. " queue_116 for rapid-fire milestones")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService animations")
table.insert(checks, (ctrl and ctrl.Source:find("OnClientEvent", 1, true) and "✅" or "❌") .. " OnClientEvent listener")

print("=== DISPATCH 116 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 116 complete" or "❌ SOME CHECKS FAILED")

print("\nMilestone tiers: " ..
    "cells (5/10/15/20/25/30/40/50) | " ..
    "prestige (1/2/3+) | " ..
    "honey lifetime (100/500/1000)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HiveMilestoneSync (RemoteEvent) | 0 |
| HiveMilestoneService (Script) | 0 |
| HiveMilestoneCelebration (LocalScript) | 0 |
| Runtime ScreenGui (destroyed after 4s) | 0 permanent |
| **Dispatch 116 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `queue_116` handles the edge case where multiple milestones fire simultaneously (e.g., buying cell #50 also triggers `cells_50` and possibly `honey_1000` in the same tick). Celebrations stack gracefully — each shows for 3.2s before the next.
- `HiveMilestones` attribute is a comma-separated string rather than JSON to keep it lightweight; `markFired_116` simply appends. This attribute can be persisted to DataStore alongside the main profile by the DataService — add `"HiveMilestones"` to the save key list.
- `DisplayOrder=50` on the overlay ensures it sits above all other HUDs (even the propolis rain banner at 14 and prestige at 20) without z-fighting.
- The headline text uses second-person ("Your hive", "You did it!") which is more emotionally engaging for kids than third-person descriptions. Kids experience it as direct praise.
- Adults get the stat impact in the detail line — they can see immediately whether a milestone matters strategically, not just visually. The detail line is always visible (not behind a toggle) because milestone screens are rare enough that showing numbers doesn't overwhelm kids.
- `IgnoreGuiInset = true` on the overlay ScreenGui ensures it covers the full screen including the top inset area (where Roblox core UI lives) — without this the overlay has a visible gap at the top on mobile.
- The server-side check on `PlayerAdded` with a `task.wait(3)` catches the case where a player rejoins already having passed a milestone threshold — without the delay the DataStore may not have populated the attributes yet.
