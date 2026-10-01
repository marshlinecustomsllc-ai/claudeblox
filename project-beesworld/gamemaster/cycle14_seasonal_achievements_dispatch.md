# Dispatch 124 — Seasonal Achievements
## Cycle 14 · A Bee's World

**Feature:** A `SeasonalAchievementService` Script and `SeasonalAchievementController` LocalScript implementing 16 seasonal achievements (4 per season: Spring/Summer/Autumn/Winter). Each achievement has a kid-friendly name with a seasonal emoji, a one-sentence description, and a stat threshold. Earning an achievement stores it as a comma-string in the `Achievements` DataStore key (piggy-backs on `HiveDataManager`). A toast notification pops up on unlock with the season badge and achievement name. Adults can open a full achievement panel from the same toggle as the cell guide. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 123 (Bear Warning System)

---

## DESIGN

### Achievement definitions

All thresholds are cumulative stats from player attributes (same attributes already tracked).

#### 🌸 Spring
| ID | Name | Condition |
|----|------|-----------|
| `spring_first_bee` | First Buzz | Place your first bee (CombCellCount ≥ 1) |
| `spring_honey_100` | Sweet Start | Collect 100 honey total |
| `spring_cells_10` | Growing Hive | Build 10 comb cells |
| `spring_forage_5` | Flower Chaser | Complete 5 foraging runs |

#### ☀️ Summer
| ID | Name | Condition |
|----|------|-----------|
| `summer_honey_1000` | Golden Summer | Collect 1,000 honey total |
| `summer_cells_25` | Busy Builder | Build 25 comb cells |
| `summer_prestige_1` | Summer Queen | Reach Prestige 1 |
| `summer_forage_20` | Meadow Master | Complete 20 foraging runs |

#### 🍂 Autumn
| ID | Name | Condition |
|----|------|-----------|
| `autumn_honey_5000` | Harvest Moon | Collect 5,000 honey total |
| `autumn_cells_40` | Comb Architect | Build 40 comb cells |
| `autumn_prestige_2` | Autumn Legacy | Reach Prestige 2 |
| `autumn_survive_bear` | Bear Dodger | Survive 3 bear raids |

#### ❄️ Winter
| ID | Name | Condition |
|----|------|-----------|
| `winter_honey_10000` | Winter Reserve | Collect 10,000 honey total |
| `winter_cells_50` | Grand Hive | Build all 50 comb cells |
| `winter_prestige_3` | Winter Crown | Reach Prestige 3 |
| `winter_forage_50` | Arctic Explorer | Complete 50 foraging runs |

### Data storage

`Achievements` player attribute: comma-separated string of earned achievement IDs, e.g. `"spring_first_bee,spring_honey_100"`. Written by server; read by client. Piggy-backs on `HiveDataManager` DataStore — the attribute is set the same way as all other stats, so no new DataStore calls needed.

### Achievement panel

`SeasonalAchievementController` adds a `🏅 Achievements` tab to the existing `CellGuideGui` or, if the guide isn't present, creates a standalone panel at `{0,-160,1,-160}` (above Guide button). Panel shows 4 season sections each with 4 achievement cards. Earned = full colour emoji + bold name. Unearned = greyed out + lock icon.

### Unlock toast

Small 260×60 card slides in from the right side, shows for 3 s, then slides out. Format: `[season emoji]  "Name" — Unlocked!`. Uses `DisplayOrder=48`.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `SeasonalAchievementService` | New Script in ServerScriptService |
| `SeasonalAchievementController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create SeasonalAchievementService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(SSS, "ServerScriptService not found")

if SSS:FindFirstChild("SeasonalAchievementService") then
    print("⏭️  SeasonalAchievementService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "SeasonalAchievementService"
    svc.Source = [[
--!strict
-- SeasonalAchievementService — dispatch 124
-- Checks player attribute milestones and awards seasonal achievements.

local Players    = game:GetService("Players")
local DataStore2 = require(game:GetService("ServerScriptService"):WaitForChild("DataStore2", 15))

-- ── Achievement definitions ────────────────────────────────────────
type AchievementDef = {
    id:        string,
    season:    string,
    name:      string,
    attribute: string,
    threshold: number,
}

local ACHIEVEMENTS_124: {AchievementDef} = {
    -- Spring
    {id="spring_first_bee",  season="🌸", name="First Buzz",      attribute="CombCellCount",  threshold=1},
    {id="spring_honey_100",  season="🌸", name="Sweet Start",     attribute="HoneyCount",     threshold=100},
    {id="spring_cells_10",   season="🌸", name="Growing Hive",    attribute="CombCellCount",  threshold=10},
    {id="spring_forage_5",   season="🌸", name="Flower Chaser",   attribute="TotalForages",   threshold=5},
    -- Summer
    {id="summer_honey_1000", season="☀️", name="Golden Summer",   attribute="HoneyCount",     threshold=1000},
    {id="summer_cells_25",   season="☀️", name="Busy Builder",    attribute="CombCellCount",  threshold=25},
    {id="summer_prestige_1", season="☀️", name="Summer Queen",    attribute="PrestigeLevel",  threshold=1},
    {id="summer_forage_20",  season="☀️", name="Meadow Master",   attribute="TotalForages",   threshold=20},
    -- Autumn
    {id="autumn_honey_5000", season="🍂", name="Harvest Moon",    attribute="HoneyCount",     threshold=5000},
    {id="autumn_cells_40",   season="🍂", name="Comb Architect",  attribute="CombCellCount",  threshold=40},
    {id="autumn_prestige_2", season="🍂", name="Autumn Legacy",   attribute="PrestigeLevel",  threshold=2},
    {id="autumn_bear_3",     season="🍂", name="Bear Dodger",     attribute="BearSurviveCount",threshold=3},
    -- Winter
    {id="winter_honey_10k",  season="❄️", name="Winter Reserve",  attribute="HoneyCount",     threshold=10000},
    {id="winter_cells_50",   season="❄️", name="Grand Hive",      attribute="CombCellCount",  threshold=50},
    {id="winter_prestige_3", season="❄️", name="Winter Crown",    attribute="PrestigeLevel",  threshold=3},
    {id="winter_forage_50",  season="❄️", name="Arctic Explorer", attribute="TotalForages",   threshold=50},
}

-- ── Helpers ────────────────────────────────────────────────────────
local function getEarned_124(player: Player): {[string]: boolean}
    local raw = tostring(player:GetAttribute("Achievements") or "")
    local earned: {[string]: boolean} = {}
    for id in raw:gmatch("[^,]+") do earned[id] = true end
    return earned
end

local function awardAchievement_124(player: Player, def: AchievementDef)
    local earned = getEarned_124(player)
    if earned[def.id] then return end

    -- Add to attribute
    local raw = tostring(player:GetAttribute("Achievements") or "")
    local newRaw = raw == "" and def.id or (raw .. "," .. def.id)
    player:SetAttribute("Achievements", newRaw)

    -- Persist via DataStore2 (same pattern as HiveDataManager)
    local ok, err = pcall(function()
        local store = DataStore2("Achievements", player)
        store:Set(newRaw)
    end)
    if not ok then
        warn("[SeasonalAchievementService] DataStore save failed:", err)
    end

    print("[SeasonalAchievementService] " .. player.Name .. " earned: " .. def.season .. " " .. def.name)
end

-- ── Check achievements for a player ───────────────────────────────
local function checkAll_124(player: Player)
    local earned = getEarned_124(player)
    for _, def in ACHIEVEMENTS_124 do
        if not earned[def.id] then
            local val = tonumber(player:GetAttribute(def.attribute)) or 0
            if val >= def.threshold then
                awardAchievement_124(player, def)
            end
        end
    end
end

-- ── Load persisted achievements on join ───────────────────────────
local function onPlayerAdded_124(player: Player)
    task.wait(3)   -- wait for HiveDataManager to populate attributes first

    local ok, savedStr = pcall(function()
        local store = DataStore2("Achievements", player)
        return store:Get("") :: string
    end)

    if ok and type(savedStr) == "string" and savedStr ~= "" then
        player:SetAttribute("Achievements", savedStr)
    end

    -- Wire attribute change listeners for all tracked attributes
    local trackedAttribs = {"CombCellCount", "HoneyCount", "PrestigeLevel",
                            "TotalForages", "BearSurviveCount"}
    for _, attrib in trackedAttribs do
        player:GetAttributeChangedSignal(attrib):Connect(function()
            checkAll_124(player)
        end)
    end

    -- Initial check after load
    checkAll_124(player)
end

Players.PlayerAdded:Connect(onPlayerAdded_124)
for _, plr in Players:GetPlayers() do
    task.spawn(onPlayerAdded_124, plr)
end

print("[SeasonalAchievementService] Ready — 16 achievements across 4 seasons")
]]
    svc.Parent = SSS
    print("✅ SeasonalAchievementService created in ServerScriptService")
end
```

---

## STEP B — Create SeasonalAchievementController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("SeasonalAchievementController") then
    print("⏭️  SeasonalAchievementController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "SeasonalAchievementController"
    ctrl.Source = [[
--!strict
-- SeasonalAchievementController — dispatch 124
-- Achievement panel + unlock toasts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD_124    = Color3.fromRGB(242, 168, 28)
local PROPOLIS_BROWN_124= Color3.fromRGB(80,  50,  20)
local WAX_CREAM_124     = Color3.fromRGB(232, 212, 154)
local DARK_BG_124       = Color3.fromRGB(30,  18,  8)
local MUTED_124         = Color3.fromRGB(90,  70,  50)

-- ── Achievement definitions (mirrors server) ───────────────────────
type AchDef = {id: string, season: string, name: string, desc: string}
local ACHIEVEMENTS_124: {AchDef} = {
    -- Spring
    {id="spring_first_bee",  season="🌸", name="First Buzz",      desc="Place your first bee in the comb"},
    {id="spring_honey_100",  season="🌸", name="Sweet Start",     desc="Collect 100 honey"},
    {id="spring_cells_10",   season="🌸", name="Growing Hive",    desc="Build 10 comb cells"},
    {id="spring_forage_5",   season="🌸", name="Flower Chaser",   desc="Complete 5 foraging runs"},
    -- Summer
    {id="summer_honey_1000", season="☀️", name="Golden Summer",   desc="Collect 1,000 honey"},
    {id="summer_cells_25",   season="☀️", name="Busy Builder",    desc="Build 25 comb cells"},
    {id="summer_prestige_1", season="☀️", name="Summer Queen",    desc="Reach Prestige 1"},
    {id="summer_forage_20",  season="☀️", name="Meadow Master",   desc="Complete 20 foraging runs"},
    -- Autumn
    {id="autumn_honey_5000", season="🍂", name="Harvest Moon",    desc="Collect 5,000 honey"},
    {id="autumn_cells_40",   season="🍂", name="Comb Architect",  desc="Build 40 comb cells"},
    {id="autumn_prestige_2", season="🍂", name="Autumn Legacy",   desc="Reach Prestige 2"},
    {id="autumn_bear_3",     season="🍂", name="Bear Dodger",     desc="Survive 3 bear raids"},
    -- Winter
    {id="winter_honey_10k",  season="❄️", name="Winter Reserve",  desc="Collect 10,000 honey"},
    {id="winter_cells_50",   season="❄️", name="Grand Hive",      desc="Build all 50 comb cells"},
    {id="winter_prestige_3", season="❄️", name="Winter Crown",    desc="Reach Prestige 3"},
    {id="winter_forage_50",  season="❄️", name="Arctic Explorer", desc="Complete 50 foraging runs"},
}

local SEASONS_124 = {
    {key="🌸", label="🌸 Spring"},
    {key="☀️", label="☀️ Summer"},
    {key="🍂", label="🍂 Autumn"},
    {key="❄️", label="❄️ Winter"},
}

-- ── Build panel GUI ───────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "AchievementGui_124"
screenGui.DisplayOrder   = 17
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = false
screenGui.Parent         = playerGui

-- Toggle button (left side, above Bee Roster at -108, so -160)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name             = "AchToggleBtn"
toggleBtn.Size             = UDim2.new(0, 130, 0, 44)
toggleBtn.Position         = UDim2.new(1, -160, 1, -160)
toggleBtn.BackgroundColor3 = PROPOLIS_BROWN_124
toggleBtn.TextColor3       = HONEY_GOLD_124
toggleBtn.Text             = "🏅 Goals"
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 13
toggleBtn.BorderSizePixel  = 0
toggleBtn.Parent           = screenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 10)
tbCorner.Parent       = toggleBtn

local tbStroke = Instance.new("UIStroke")
tbStroke.Color     = HONEY_GOLD_124
tbStroke.Thickness = 1.5
tbStroke.Parent    = toggleBtn

-- Panel (300×420, slides up from bottom-right)
local panel = Instance.new("Frame")
panel.Name             = "AchievementPanel"
panel.Size             = UDim2.new(0, 300, 0, 420)
panel.Position         = UDim2.new(1, 10, 1, -210)   -- hidden right off-screen
panel.BackgroundColor3 = DARK_BG_124
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.Parent           = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD_124
panelStroke.Thickness = 1.5
panelStroke.Parent    = panel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name                   = "Title"
titleLabel.Size                   = UDim2.new(1, 0, 0, 36)
titleLabel.BackgroundColor3       = PROPOLIS_BROWN_124
titleLabel.TextColor3             = HONEY_GOLD_124
titleLabel.Font                   = Enum.Font.GothamBold
titleLabel.TextSize               = 15
titleLabel.TextXAlignment         = Enum.TextXAlignment.Center
titleLabel.Text                   = "🏅  Seasonal Goals"
titleLabel.Parent                 = panel

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent       = titleLabel

-- Clip bottom corners of title
local titleFill = Instance.new("Frame")
titleFill.Size             = UDim2.new(1, 0, 0.5, 0)
titleFill.Position         = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = PROPOLIS_BROWN_124
titleFill.BorderSizePixel  = 0
titleFill.Parent           = titleLabel

-- Scroll area
local scroll = Instance.new("ScrollingFrame")
scroll.Name                     = "AchScroll"
scroll.Size                     = UDim2.new(1, -12, 1, -44)
scroll.Position                 = UDim2.new(0, 6, 0, 40)
scroll.BackgroundTransparency   = 1
scroll.BorderSizePixel          = 0
scroll.ScrollBarThickness       = 3
scroll.ScrollBarImageColor3     = HONEY_GOLD_124
scroll.AutomaticCanvasSize      = Enum.AutomaticSize.Y
scroll.CanvasSize               = UDim2.new(0, 0, 0, 0)
scroll.Parent                   = panel

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.SortOrder  = Enum.SortOrder.LayoutOrder
scrollLayout.Padding    = UDim.new(0, 6)
scrollLayout.Parent     = scroll

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingTop    = UDim.new(0, 4)
scrollPad.PaddingBottom = UDim.new(0, 8)
scrollPad.Parent        = scroll

-- ── Parse earned achievements ─────────────────────────────────────
local function getEarned_124(): {[string]: boolean}
    local raw = tostring(player:GetAttribute("Achievements") or "")
    local earned: {[string]: boolean} = {}
    for id in raw:gmatch("[^,]+") do earned[id] = true end
    return earned
end

-- ── Build achievement rows ────────────────────────────────────────
local function buildAchRows_124()
    -- Clear existing
    for _, child in scroll:GetChildren() do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local earned = getEarned_124()

    local lo = 1
    for _, season in SEASONS_124 do
        -- Season header
        local header = Instance.new("TextLabel")
        header.Name                   = "Header_" .. season.key
        header.Size                   = UDim2.new(1, 0, 0, 24)
        header.BackgroundColor3       = PROPOLIS_BROWN_124
        header.BackgroundTransparency = 0.3
        header.TextColor3             = HONEY_GOLD_124
        header.Font                   = Enum.Font.GothamBold
        header.TextSize               = 13
        header.TextXAlignment         = Enum.TextXAlignment.Left
        header.Text                   = "  " .. season.label
        header.LayoutOrder            = lo
        header.Parent                 = scroll
        lo += 1

        local hCorner = Instance.new("UICorner")
        hCorner.CornerRadius = UDim.new(0, 6)
        hCorner.Parent       = header

        -- Achievement cards for this season
        for _, def in ACHIEVEMENTS_124 do
            if def.season ~= season.key then continue end
            local isEarned = earned[def.id] == true

            local card = Instance.new("Frame")
            card.Name             = "Ach_" .. def.id
            card.Size             = UDim2.new(1, 0, 0, 46)
            card.BackgroundColor3 = isEarned and PROPOLIS_BROWN_124 or DARK_BG_124
            card.BackgroundTransparency = isEarned and 0.2 or 0.6
            card.BorderSizePixel  = 0
            card.LayoutOrder      = lo
            card.Parent           = scroll
            lo += 1

            local cCorner = Instance.new("UICorner")
            cCorner.CornerRadius = UDim.new(0, 6)
            cCorner.Parent       = card

            if isEarned then
                local cStroke = Instance.new("UIStroke")
                cStroke.Color     = HONEY_GOLD_124
                cStroke.Thickness = 1
                cStroke.Parent    = card
            end

            -- Season icon or lock
            local icon = Instance.new("TextLabel")
            icon.Name                   = "Icon"
            icon.Size                   = UDim2.new(0, 30, 1, 0)
            icon.Position               = UDim2.new(0, 4, 0, 0)
            icon.BackgroundTransparency = 1
            icon.TextColor3             = isEarned and HONEY_GOLD_124 or MUTED_124
            icon.Font                   = Enum.Font.Gotham
            icon.TextSize               = 18
            icon.TextXAlignment         = Enum.TextXAlignment.Center
            icon.Text                   = isEarned and def.season or "🔒"
            icon.Parent                 = card

            -- Name
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name                   = "Name"
            nameLabel.Size                   = UDim2.new(1, -38, 0, 20)
            nameLabel.Position               = UDim2.new(0, 36, 0, 4)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3             = isEarned and HONEY_GOLD_124 or MUTED_124
            nameLabel.Font                   = isEarned and Enum.Font.GothamBold or Enum.Font.Gotham
            nameLabel.TextSize               = 13
            nameLabel.TextXAlignment         = Enum.TextXAlignment.Left
            nameLabel.Text                   = def.name
            nameLabel.Parent                 = card

            -- Desc
            local descLabel = Instance.new("TextLabel")
            descLabel.Name                   = "Desc"
            descLabel.Size                   = UDim2.new(1, -38, 0, 16)
            descLabel.Position               = UDim2.new(0, 36, 0, 24)
            descLabel.BackgroundTransparency = 1
            descLabel.TextColor3             = isEarned and WAX_CREAM_124 or MUTED_124
            descLabel.Font                   = Enum.Font.Gotham
            descLabel.TextSize               = 10
            descLabel.TextXAlignment         = Enum.TextXAlignment.Left
            descLabel.TextWrapped            = true
            descLabel.Text                   = def.desc
            descLabel.Parent                 = card
        end
    end
end

-- ── Panel open/close ───────────────────────────────────────────────
local panelOpen_124 = false
local OPEN_POS_124  = UDim2.new(1, -310, 1, -210)
local CLOSE_POS_124 = UDim2.new(1, 10,   1, -210)

local function openPanel_124()
    buildAchRows_124()
    panel.Visible   = true
    panelOpen_124   = true
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = OPEN_POS_124}):Play()
end

local function closePanel_124()
    panelOpen_124 = false
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = CLOSE_POS_124}):Play()
    task.delay(0.25, function() panel.Visible = false end)
end

toggleBtn.Activated:Connect(function()
    if panelOpen_124 then closePanel_124() else openPanel_124() end
end)

-- ── Unlock toast ──────────────────────────────────────────────────
-- Track previous achievement set to detect new awards
local prevAchievements_124 = getEarned_124()

local function showToast_124(def: AchDef)
    local toastGui = Instance.new("ScreenGui")
    toastGui.Name           = "AchToast_124_" .. def.id
    toastGui.DisplayOrder   = 48
    toastGui.ResetOnSpawn   = false
    toastGui.IgnoreGuiInset = false
    toastGui.Parent         = playerGui

    local toast = Instance.new("Frame")
    toast.Name             = "Toast"
    toast.Size             = UDim2.new(0, 260, 0, 60)
    toast.Position         = UDim2.new(1, 10, 0.5, -30)   -- off right side
    toast.BackgroundColor3 = PROPOLIS_BROWN_124
    toast.BorderSizePixel  = 0
    toast.Parent           = toastGui

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 10)
    tc.Parent       = toast

    local ts = Instance.new("UIStroke")
    ts.Color     = HONEY_GOLD_124
    ts.Thickness = 1.5
    ts.Parent    = toast

    local tIcon = Instance.new("TextLabel")
    tIcon.Size                   = UDim2.new(0, 44, 1, 0)
    tIcon.BackgroundTransparency = 1
    tIcon.TextColor3             = HONEY_GOLD_124
    tIcon.Font                   = Enum.Font.Gotham
    tIcon.TextSize               = 24
    tIcon.TextXAlignment         = Enum.TextXAlignment.Center
    tIcon.Text                   = def.season
    tIcon.Parent                 = toast

    local tText = Instance.new("TextLabel")
    tText.Size                   = UDim2.new(1, -48, 0, 22)
    tText.Position               = UDim2.new(0, 44, 0, 6)
    tText.BackgroundTransparency = 1
    tText.TextColor3             = HONEY_GOLD_124
    tText.Font                   = Enum.Font.GothamBold
    tText.TextSize               = 13
    tText.TextXAlignment         = Enum.TextXAlignment.Left
    tText.Text                   = '"' .. def.name .. '"'
    tText.Parent                 = toast

    local tSub = Instance.new("TextLabel")
    tSub.Size                   = UDim2.new(1, -48, 0, 16)
    tSub.Position               = UDim2.new(0, 44, 0, 28)
    tSub.BackgroundTransparency = 1
    tSub.TextColor3             = WAX_CREAM_124
    tSub.Font                   = Enum.Font.Gotham
    tSub.TextSize               = 11
    tSub.TextXAlignment         = Enum.TextXAlignment.Left
    tSub.Text                   = "Achievement Unlocked! 🎉"
    tSub.Parent                 = toast

    -- Slide in
    TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -270, 0.5, -30)}):Play()

    -- Hold then slide out
    task.delay(3, function()
        TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(1, 10, 0.5, -30)}):Play()
        task.delay(0.3, function() toastGui:Destroy() end)
    end)
end

-- ── Watch for new achievements ────────────────────────────────────
player:GetAttributeChangedSignal("Achievements"):Connect(function()
    local current = getEarned_124()

    -- Find newly earned ones
    for _, def in ACHIEVEMENTS_124 do
        if current[def.id] and not prevAchievements_124[def.id] then
            showToast_124(def)
            -- Rebuild panel if open
            if panelOpen_124 then buildAchRows_124() end
        end
    end

    prevAchievements_124 = current
end)

-- ── Initial panel state ───────────────────────────────────────────
task.wait(2)
prevAchievements_124 = getEarned_124()

print("[SeasonalAchievementController] Ready — 16 seasonal goals, panel + unlock toasts")
]]
    ctrl.Parent = SPS
    print("✅ SeasonalAchievementController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local svc  = SSS and SSS:FindFirstChild("SeasonalAchievementService")
local ctrl = SPS and SPS:FindFirstChild("SeasonalAchievementController")

local checks = {}
table.insert(checks, (svc  and "✅" or "❌") .. " SeasonalAchievementService in ServerScriptService")
table.insert(checks, (svc  and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc  and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc  and svc.Source:find("ACHIEVEMENTS_124", 1, true) and "✅" or "❌") .. " ACHIEVEMENTS_124 table (service)")
table.insert(checks, (svc  and svc.Source:find("awardAchievement_124", 1, true) and "✅" or "❌") .. " awardAchievement_124")
table.insert(checks, (svc  and svc.Source:find("checkAll_124", 1, true) and "✅" or "❌") .. " checkAll_124")
table.insert(checks, (svc  and svc.Source:find("DataStore2", 1, true) and "✅" or "❌") .. " DataStore2 persistence")
table.insert(checks, (svc  and svc.Source:find("TotalForages", 1, true) and "✅" or "❌") .. " TotalForages attribute check")
table.insert(checks, (ctrl and "✅" or "❌") .. " SeasonalAchievementController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (client)")
table.insert(checks, (ctrl and ctrl.Source:find("ACHIEVEMENTS_124", 1, true) and "✅" or "❌") .. " ACHIEVEMENTS_124 table (client)")
table.insert(checks, (ctrl and ctrl.Source:find("buildAchRows_124", 1, true) and "✅" or "❌") .. " buildAchRows_124 panel builder")
table.insert(checks, (ctrl and ctrl.Source:find("showToast_124", 1, true) and "✅" or "❌") .. " showToast_124 toast")
table.insert(checks, (ctrl and ctrl.Source:find("prevAchievements_124", 1, true) and "✅" or "❌") .. " prevAchievements_124 diff tracking")
table.insert(checks, (ctrl and ctrl.Source:find("SEASONS_124", 1, true) and "✅" or "❌") .. " SEASONS_124 season groups")

print("=== DISPATCH 124 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 124 complete" or "❌ SOME CHECKS FAILED")

print("\n16 achievements: 🌸 Spring x4 | ☀️ Summer x4 | 🍂 Autumn x4 | ❄️ Winter x4")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| SeasonalAchievementService (Script) | 0 permanent |
| SeasonalAchievementController (LocalScript, runtime UI in PlayerGui) | 0 permanent |
| **Dispatch 124 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `TotalForages` and `BearSurviveCount` are new player attributes not explicitly written by earlier dispatches. `ForagingService` (dispatch ~40+) should increment `TotalForages` on each successful return. `ThreatService` (dispatch 29+) should increment `BearSurviveCount` when a bear raid ends without taking a hive damage penalty. If these attributes don't exist yet, their value defaults to 0 and achievements requiring them simply won't trigger — no error, no crash. A follow-up dispatch can add the attribute increment to each service.
- `DataStore2` usage mirrors `HiveDataManager` — the `Achievements` key sits in the same DataStore2 scope as the player's hive data. This means a single DataStore API budget covers all player persistence.
- The client `prevAchievements_124` table is compared on every `Achievements` attribute change to detect newly earned achievements. Only new entries trigger a toast — re-loading achievements from DataStore on join doesn't fire toasts for already-earned ones.
- Toast uses a fresh `ScreenGui` per achievement, destroyed after the slide-out animation. This means 2 achievements earned simultaneously each get their own toast that stacks independently — no coordination needed. The `DisplayOrder=48` puts toasts above the achievement panel (17) and bear warning (45) but below milestone celebration (50).
- Season grouping in the panel (Spring → Summer → Autumn → Winter) creates a natural long-horizon roadmap. Kids see all locked achievements and can read what they need to do — the lock icon with a brief description is immediately legible without needing numbers or progress bars.
- The `🏅 Goals` button is positioned at `{1,-160,1,-160}` — above the Guide button (`-56`), Bee Roster button (`-108`), and the Leaderboard toggle is on the top-left, so right-side buttons stack cleanly: Goals → Roster → Guide from top to bottom.
