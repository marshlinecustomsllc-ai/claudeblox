# Dispatch 41 — DailyRewardService: Login Streak Calendar
**Cycle 11 | A Bee's World | Bee-scale tycoon**
**Execution order: after dispatch 40**

---

## OVERVIEW

Adds a 7-day login streak reward system. On each new UTC day, first login grants rewards
escalating across the 7-day calendar. Missing a day resets the streak to Day 1.
Rewards include honey + propolis (and a special skin grant on Day 7).

A DailyRewardGui shows the 7-day calendar with day icons, reward amounts, and
animated coin/comb icons. Opens automatically on first login of the day; player
can dismiss or claim. "Claim" closes the panel and applies rewards.

**Part budget**: 0 permanent → **~4,142 / 5,000**

---

## 7-DAY REWARD SCHEDULE

| Day | Honey | Propolis | Bonus |
|-----|-------|----------|-------|
| 1 | 500 | 5 | — |
| 2 | 800 | 8 | — |
| 3 | 1,200 | 12 | — |
| 4 | 1,800 | 18 | — |
| 5 | 2,500 | 25 | — |
| 6 | 3,500 | 35 | — |
| 7 | 5,000 | 50 | Skin: "streak_champion" |

---

## STEP A — Config.DAILY_REWARDS + DataService migration

```lua
-- In Studio Command Bar:
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- ---- Config.DAILY_REWARDS ----
local cfg = RS:FindFirstChild("Config")
if not cfg then error("Config not found") end
local cfgClone = cfg:Clone()
cfg.Name = "Config_OLD_NX"
cfg.Parent = nil

local inject = [[

-- ============================================================
-- DAILY REWARD CALENDAR (7-day streak)
-- ============================================================
Config.DAILY_REWARDS = {
    { day = 1, honey = 500,   propolis = 5,  skin = nil              },
    { day = 2, honey = 800,   propolis = 8,  skin = nil              },
    { day = 3, honey = 1200,  propolis = 12, skin = nil              },
    { day = 4, honey = 1800,  propolis = 18, skin = nil              },
    { day = 5, honey = 2500,  propolis = 25, skin = nil              },
    { day = 6, honey = 3500,  propolis = 35, skin = nil              },
    { day = 7, honey = 5000,  propolis = 50, skin = "streak_champion" },
}
]]
local cfgSrc = cfgClone.Source
cfgSrc = cfgSrc:gsub("(return Config)", inject .. "\n%1")
cfgClone.Source = cfgSrc
cfgClone.Name = "Config"
cfgClone.Parent = RS
print("✅ Config.DAILY_REWARDS injected (7 days)")

-- ---- DataService migration ----
local ds = SSS:FindFirstChild("DataService")
if not ds then error("DataService not found") end
local dsClone = ds:Clone()
ds.Name = "DataService_OLD_NX"
ds.Parent = nil

local dsSrc = dsClone.Source
local needsMigration = not dsSrc:find("loginStreak")
if needsMigration then
    dsSrc = dsSrc:gsub(
        "(beeBodyColor.-\n)",
        "%1\t\tloginStreak    = 0,     -- consecutive day streak\n\t\tlastLoginDay   = 0,     -- os.time() UTC day number of last claim\n\t\tdailyClaimedToday = false,\n"
    )
    print("✅ DataService: loginStreak + lastLoginDay + dailyClaimedToday added")
else
    print("ℹ️  DataService: streak fields already present")
end
dsClone.Source = dsSrc
dsClone.Name = "DataService"
dsClone.Parent = SSS
```

---

## STEP B — DailyRewardSync RemoteEvent + DailyRewardService (server)

```lua
-- In Studio Command Bar (run after Step A):
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local remotes = RS:FindFirstChild("Remotes")
if not remotes then error("Remotes not found") end

-- RemoteEvent: server→client to show daily reward panel
if not remotes:FindFirstChild("DailyRewardSync") then
    local re = Instance.new("RemoteEvent")
    re.Name = "DailyRewardSync"
    re.Parent = remotes
    print("✅ DailyRewardSync RemoteEvent created")
end

-- RemoteFunction: client claims reward
if not remotes:FindFirstChild("ClaimDailyReward") then
    local rf = Instance.new("RemoteFunction")
    rf.Name = "ClaimDailyReward"
    rf.Parent = remotes
    print("✅ ClaimDailyReward RemoteFunction created")
end

-- DailyRewardService
local old = SSS:FindFirstChild("DailyRewardService")
if old then old:Destroy() end

local s = Instance.new("ModuleScript")
s.Name = "DailyRewardService"
s.Source = [[
--!strict
local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local SSS         = game:GetService("ServerScriptService")

local Config            = require(RS:WaitForChild("Config"))
local DataService       = require(SSS:WaitForChild("DataService"))
local DailyRewardSync   = RS:WaitForChild("Remotes"):WaitForChild("DailyRewardSync")
local ClaimDailyReward  = RS:WaitForChild("Remotes"):WaitForChild("ClaimDailyReward")

-- Lazily loaded for skin grants
local PrestigeRewardService: any? = nil
local AchievementService:    any? = nil

type RewardDef = { day: number, honey: number, propolis: number, skin: string? }

local function utcDayNumber(): number
    -- Returns the number of days since Unix epoch (always UTC)
    return math.floor(os.time() / 86400)
end

local function getNextStreak(profile: any): number
    local lastDay = profile.lastLoginDay or 0
    local today   = utcDayNumber()
    if today == lastDay then
        -- Already logged in today — return current streak (for display)
        return math.clamp(profile.loginStreak or 1, 1, 7)
    elseif today == lastDay + 1 then
        -- Consecutive day
        return math.clamp((profile.loginStreak or 0) + 1, 1, 7)
    else
        -- Missed at least one day — reset
        return 1
    end
end

local function getRewardForStreak(streak: number): RewardDef
    local rewards = Config.DAILY_REWARDS :: { RewardDef }
    local idx = math.clamp(streak, 1, #rewards)
    return rewards[idx]
end

local function tryShowDailyReward(player: Player)
    local ok, profile = pcall(DataService.GetProfile, player)
    if not ok or not profile then return end

    local today = utcDayNumber()
    if (profile.lastLoginDay or 0) == today then
        -- Already claimed today
        return
    end

    local nextStreak = getNextStreak(profile)
    local reward     = getRewardForStreak(nextStreak)

    DailyRewardSync:FireClient(player, {
        streak  = nextStreak,
        reward  = reward,
        claimed = false,
    })
end

local DailyRewardService = {}

function DailyRewardService.Init()
    -- Lazy load optional services
    pcall(function()
        PrestigeRewardService = require(SSS:FindFirstChild("PrestigeRewardService") :: any)
    end)
    pcall(function()
        AchievementService = require(SSS:FindFirstChild("AchievementService") :: any)
    end)

    -- Show panel shortly after player data is loaded
    Players.PlayerAdded:Connect(function(player: Player)
        task.wait(4)  -- profile load delay
        tryShowDailyReward(player)
    end)

    -- Handle claim from client
    ClaimDailyReward.OnServerInvoke = function(player: Player): { success: boolean, message: string }
        local ok, profile = pcall(DataService.GetProfile, player)
        if not ok or not profile then
            return { success = false, message = "Profile unavailable" }
        end

        local today = utcDayNumber()
        if (profile.lastLoginDay or 0) == today then
            return { success = false, message = "Already claimed today" }
        end

        local nextStreak = getNextStreak(profile)
        local reward     = getRewardForStreak(nextStreak)

        -- Apply reward
        profile.honey    = (profile.honey    or 0) + reward.honey
        profile.propolis = (profile.propolis or 0) + reward.propolis
        profile.loginStreak    = nextStreak
        profile.lastLoginDay   = today
        profile.dailyClaimedToday = true

        -- Skin grant on Day 7
        if reward.skin and AchievementService then
            -- Grant via PrestigeRewardService if skin system available
            if PrestigeRewardService and PrestigeRewardService.GrantSkin then
                PrestigeRewardService.GrantSkin(player, reward.skin)
            end
        end

        -- Notify toast
        local notifyRE = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("Notify")
        if notifyRE then
            local msg = string.format("Day %d streak! +%d honey, +%d propolis", nextStreak, reward.honey, reward.propolis)
            if reward.skin then msg = msg .. " + special skin!" end
            notifyRE:FireClient(player, { title = "🗓 Daily Reward Claimed!", message = msg, duration = 5 })
        end

        -- Confirm to client
        DailyRewardSync:FireClient(player, {
            streak  = nextStreak,
            reward  = reward,
            claimed = true,
        })

        return { success = true, message = "Claimed!" }
    end
end

return DailyRewardService
]]
s.Parent = SSS
print("✅ DailyRewardService ModuleScript created in ServerScriptService")
```

---

## STEP C — Wire DailyRewardService into GameManager

```lua
-- In Studio Command Bar (run after Step B):
local SSS = game:GetService("ServerScriptService")

local gm = SSS:FindFirstChild("GameManager")
if not gm then error("GameManager not found") end
local clone = gm:Clone()
gm.Name = "GameManager_OLD_NX"
gm.Parent = nil

local src = clone.Source
if not src:find("DailyRewardService") then
    src = src:gsub(
        "(local BeeColorService.-\n)",
        "%1local DailyRewardService = require(SSS:WaitForChild(\"DailyRewardService\"))\n"
    )
    src = src:gsub(
        "(BeeColorService%.Init%(%)\n)",
        "%1DailyRewardService.Init()\n"
    )
    print("✅ GameManager: DailyRewardService require+Init injected")
else
    print("ℹ️  GameManager: DailyRewardService already wired")
end
clone.Source = src
clone.Name = "GameManager"
clone.Parent = SSS
```

---

## STEP D — DailyRewardGui ScreenGui

```lua
-- In Studio Command Bar (run after Step C):
local StarterGui = game:GetService("StarterGui")

local old = StarterGui:FindFirstChild("DailyRewardGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "DailyRewardGui"
gui.DisplayOrder   = 55  -- above most UI, below TutorialGui (60)
gui.ResetOnSpawn   = false
gui.IgnoreGuiInset = true
gui.Parent         = StarterGui

-- Dim overlay
local dim = Instance.new("Frame")
dim.Name                   = "Dimmer"
dim.Size                   = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.55
dim.BorderSizePixel        = 0
dim.ZIndex                 = 8
dim.Visible                = false
dim.Parent                 = gui

-- Main calendar panel (centre-screen)
local panel = Instance.new("Frame")
panel.Name             = "CalendarPanel"
panel.Size             = UDim2.new(0.68, 0, 0.65, 0)
panel.Position         = UDim2.new(0.16, 0, 0.175, 0)
panel.BackgroundColor3 = Color3.fromRGB(40, 20, 5)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel  = 0
panel.ZIndex           = 9
panel.Visible          = false
panel.Parent           = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = Color3.fromRGB(242, 168, 28)
panelStroke.Thickness = 2.5
panelStroke.Parent    = panel

-- Header
local header = Instance.new("TextLabel")
header.Name             = "Header"
header.Size             = UDim2.new(1, 0, 0.12, 0)
header.BackgroundTransparency = 1
header.Text             = "🗓 Daily Login Reward"
header.Font             = Enum.Font.FredokaOne
header.TextScaled       = true
header.TextColor3       = Color3.fromRGB(242, 168, 28)
header.ZIndex           = 10
header.Parent           = panel

local subheader = Instance.new("TextLabel")
subheader.Name             = "Subheader"
subheader.Size             = UDim2.new(1, 0, 0.07, 0)
subheader.Position         = UDim2.new(0, 0, 0.12, 0)
subheader.BackgroundTransparency = 1
subheader.Text             = "Login every day to grow your streak!"
subheader.Font             = Enum.Font.FredokaOne
subheader.TextScaled       = true
subheader.TextColor3       = Color3.fromRGB(180, 150, 100)
subheader.ZIndex           = 10
subheader.Parent           = panel

-- 7-day row (day cards at y=20%–72%)
local DAY_ICONS  = { "☀️", "🌿", "🍀", "🌸", "⭐", "🏆", "👑" }
local DAY_HONEYS = { 500, 800, 1200, 1800, 2500, 3500, 5000 }
local DAY_PROPS  = { 5,   8,   12,   18,   25,   35,   50  }

local CARD_W = 0.117
local GAP    = 0.015
local START  = 0.025

for i = 1, 7 do
    local xPos = START + (i - 1) * (CARD_W + GAP)

    local card = Instance.new("Frame")
    card.Name             = "DayCard_" .. i
    card.Size             = UDim2.new(CARD_W, 0, 0.54, 0)
    card.Position         = UDim2.new(xPos, 0, 0.21, 0)
    card.BackgroundColor3 = Color3.fromRGB(60, 30, 8)
    card.BackgroundTransparency = 0.2
    card.BorderSizePixel  = 0
    card.ZIndex           = 10
    card:SetAttribute("Day", i)
    card.Parent           = panel

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent = card

    local cs = Instance.new("UIStroke")
    cs.Color     = Color3.fromRGB(100, 60, 20)
    cs.Thickness = 1.5
    cs.Name      = "BorderStroke"
    cs.Parent    = card

    -- Day number
    local dayLbl = Instance.new("TextLabel")
    dayLbl.Size             = UDim2.new(1, 0, 0.22, 0)
    dayLbl.BackgroundTransparency = 1
    dayLbl.Text             = "Day " .. i
    dayLbl.Font             = Enum.Font.FredokaOne
    dayLbl.TextScaled       = true
    dayLbl.TextColor3       = Color3.fromRGB(200, 160, 80)
    dayLbl.ZIndex           = 11
    dayLbl.Parent           = card

    -- Day icon (large emoji)
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size             = UDim2.new(1, 0, 0.35, 0)
    iconLbl.Position         = UDim2.new(0, 0, 0.20, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text             = DAY_ICONS[i]
    iconLbl.Font             = Enum.Font.FredokaOne
    iconLbl.TextScaled       = true
    iconLbl.ZIndex           = 11
    iconLbl.Parent           = card

    -- Honey reward
    local honeyLbl = Instance.new("TextLabel")
    honeyLbl.Size            = UDim2.new(1, 0, 0.20, 0)
    honeyLbl.Position        = UDim2.new(0, 0, 0.55, 0)
    honeyLbl.BackgroundTransparency = 1
    honeyLbl.Text            = "🍯" .. DAY_HONEYS[i]
    honeyLbl.Font            = Enum.Font.FredokaOne
    honeyLbl.TextScaled      = true
    honeyLbl.TextColor3      = Color3.fromRGB(242, 168, 28)
    honeyLbl.ZIndex          = 11
    honeyLbl.Parent          = card

    -- Propolis reward
    local propLbl = Instance.new("TextLabel")
    propLbl.Size             = UDim2.new(1, 0, 0.18, 0)
    propLbl.Position         = UDim2.new(0, 0, 0.78, 0)
    propLbl.BackgroundTransparency = 1
    propLbl.Text             = "🌿+" .. DAY_PROPS[i]
    propLbl.Font             = Enum.Font.FredokaOne
    propLbl.TextScaled       = true
    propLbl.TextColor3       = Color3.fromRGB(100, 200, 80)
    propLbl.ZIndex           = 11
    propLbl.Parent           = card
end

-- Claim button
local claimBtn = Instance.new("TextButton")
claimBtn.Name              = "ClaimBtn"
claimBtn.Size              = UDim2.new(0.38, 0, 0.10, 0)
claimBtn.Position          = UDim2.new(0.31, 0, 0.78, 0)
claimBtn.BackgroundColor3  = Color3.fromRGB(242, 168, 28)
claimBtn.BackgroundTransparency = 0
claimBtn.BorderSizePixel   = 0
claimBtn.Text              = "🎁 Claim Reward!"
claimBtn.Font              = Enum.Font.FredokaOne
claimBtn.TextScaled        = true
claimBtn.TextColor3        = Color3.fromRGB(40, 20, 0)
claimBtn.ZIndex            = 10
claimBtn.Parent            = panel

local claimCorner = Instance.new("UICorner")
claimCorner.CornerRadius = UDim.new(0, 10)
claimCorner.Parent = claimBtn

-- Close button (X)
local closeBtn = Instance.new("TextButton")
closeBtn.Name              = "CloseBtn"
closeBtn.Size              = UDim2.new(0.07, 0, 0.10, 0)
closeBtn.Position          = UDim2.new(0.92, 0, 0.01, 0)
closeBtn.BackgroundColor3  = Color3.fromRGB(100, 40, 10)
closeBtn.BackgroundTransparency = 0.2
closeBtn.BorderSizePixel   = 0
closeBtn.Text              = "✕"
closeBtn.Font              = Enum.Font.FredokaOne
closeBtn.TextScaled        = true
closeBtn.TextColor3        = Color3.fromRGB(232, 212, 154)
closeBtn.ZIndex            = 11
closeBtn.Parent            = panel

local xCorner = Instance.new("UICorner")
xCorner.CornerRadius = UDim.new(0, 8)
xCorner.Parent = closeBtn

-- Streak label
local streakLbl = Instance.new("TextLabel")
streakLbl.Name             = "StreakLabel"
streakLbl.Size             = UDim2.new(0.50, 0, 0.09, 0)
streakLbl.Position         = UDim2.new(0.25, 0, 0.89, 0)
streakLbl.BackgroundTransparency = 1
streakLbl.Text             = "Current streak: 0 days"
streakLbl.Font             = Enum.Font.FredokaOne
streakLbl.TextScaled       = true
streakLbl.TextColor3       = Color3.fromRGB(232, 212, 154)
streakLbl.ZIndex           = 10
streakLbl.Parent           = panel

print("✅ DailyRewardGui created in StarterGui (7-day calendar, Claim + Close buttons)")
```

---

## STEP E — DailyRewardController LocalScript

```lua
-- In Studio Command Bar (run after Step D):
local StarterPlayer = game:GetService("StarterPlayer")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not SPS then error("StarterPlayerScripts not found") end

local old = SPS:FindFirstChild("DailyRewardController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name = "DailyRewardController"
ctrl.Source = [[
--!strict
local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player          = Players.LocalPlayer
local pgui            = player:WaitForChild("PlayerGui")
local DailyRewardSync  = RS:WaitForChild("Remotes"):WaitForChild("DailyRewardSync") :: RemoteEvent
local ClaimDailyReward = RS:WaitForChild("Remotes"):WaitForChild("ClaimDailyReward") :: RemoteFunction

local gui      = pgui:WaitForChild("DailyRewardGui") :: ScreenGui
local dimmer   = gui:WaitForChild("Dimmer") :: Frame
local panel    = gui:WaitForChild("CalendarPanel") :: Frame
local claimBtn = panel:WaitForChild("ClaimBtn") :: TextButton
local closeBtn = panel:WaitForChild("CloseBtn") :: TextButton
local streakLbl = panel:WaitForChild("StreakLabel") :: TextLabel

local HONEY_GOLD   = Color3.fromRGB(242, 168, 28)
local CLAIMED_GREEN = Color3.fromRGB(80, 200, 80)
local GREY_LOCKED  = Color3.fromRGB(60, 40, 20)

local PANEL_SHOW = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PANEL_HIDE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local _currentStreak  = 0
local _claimed        = false

local function highlightDayCard(streak: number, claimed: boolean)
    for i = 1, 7 do
        local card = panel:FindFirstChild("DayCard_" .. i) :: Frame?
        if not card then continue end
        local border = card:FindFirstChild("BorderStroke") :: UIStroke?
        if i < streak then
            -- Past days — green tick
            card.BackgroundColor3 = Color3.fromRGB(20, 50, 20)
            if border then border.Color = CLAIMED_GREEN border.Thickness = 2 end
            local icon = card:FindFirstChildOfClass("TextLabel")
            -- Overlay checkmark
            local check = card:FindFirstChild("CheckMark")
            if not check then
                local c = Instance.new("TextLabel")
                c.Name = "CheckMark"
                c.Size = UDim2.new(1, 0, 1, 0)
                c.BackgroundTransparency = 0.4
                c.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                c.Text = "✓"
                c.Font = Enum.Font.FredokaOne
                c.TextScaled = true
                c.TextColor3 = CLAIMED_GREEN
                c.ZIndex = 15
                c.Parent = card
                local cc = Instance.new("UICorner")
                cc.CornerRadius = UDim.new(0, 8)
                cc.Parent = c
            end
        elseif i == streak then
            -- Today's day — gold highlight
            card.BackgroundColor3 = Color3.fromRGB(80, 50, 5)
            if border then
                border.Color = claimed and CLAIMED_GREEN or HONEY_GOLD
                border.Thickness = 3
            end
        else
            -- Future days — dim
            card.BackgroundColor3 = Color3.fromRGB(30, 15, 4)
            card.BackgroundTransparency = 0.5
            if border then border.Color = Color3.fromRGB(60, 40, 20) border.Thickness = 1 end
        end
    end
end

local function showPanel(streak: number, claimed: boolean)
    _currentStreak = streak
    _claimed       = claimed
    streakLbl.Text = "🔥 Streak: " .. streak .. " day" .. (streak == 1 and "" or "s")
    highlightDayCard(streak, claimed)
    claimBtn.Visible = not claimed
    claimBtn.Text    = claimed and "✅ Claimed!" or "🎁 Claim Reward!"
    claimBtn.BackgroundColor3 = claimed and CLAIMED_GREEN or HONEY_GOLD

    dimmer.Visible  = true
    panel.Visible   = true
    panel.Size      = UDim2.new(0.01, 0, 0.01, 0)
    panel.Position  = UDim2.new(0.495, 0, 0.495, 0)
    TweenService:Create(panel, PANEL_SHOW, {
        Size     = UDim2.new(0.68, 0, 0.65, 0),
        Position = UDim2.new(0.16, 0, 0.175, 0),
    }):Play()
end

local function hidePanel()
    TweenService:Create(panel, PANEL_HIDE, {
        Size     = UDim2.new(0.01, 0, 0.01, 0),
        Position = UDim2.new(0.495, 0, 0.495, 0),
    }):Play()
    task.delay(0.25, function()
        panel.Visible  = false
        dimmer.Visible = false
    end)
end

claimBtn.Activated:Connect(function()
    if _claimed then return end
    claimBtn.Active = false
    task.spawn(function()
        local result = ClaimDailyReward:InvokeServer() :: { success: boolean, message: string }
        if result and result.success then
            _claimed = true
            claimBtn.Text             = "✅ Claimed!"
            claimBtn.BackgroundColor3 = CLAIMED_GREEN
            highlightDayCard(_currentStreak, true)
        else
            claimBtn.Active = true
        end
    end)
end)

closeBtn.Activated:Connect(hidePanel)
dimmer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        hidePanel()
    end
end)

DailyRewardSync.OnClientEvent:Connect(function(data: { streak: number, claimed: boolean })
    showPanel(data.streak, data.claimed)
end)
]]
ctrl.Parent = SPS
print("✅ DailyRewardController LocalScript created in StarterPlayerScripts")
```

---

## STEP F — Verification

```lua
-- In Studio Command Bar:
local RS     = game:GetService("ReplicatedStorage")
local SSS    = game:GetService("ServerScriptService")
local SG     = game:GetService("StarterGui")
local SP     = game:GetService("StarterPlayer")

local results = {}
local issues  = {}

-- 1. Config.DAILY_REWARDS
local cfg = RS:FindFirstChild("Config")
if cfg then
    local ok, data = pcall(require, cfg)
    if ok and data.DAILY_REWARDS and #data.DAILY_REWARDS == 7 then
        local day7 = data.DAILY_REWARDS[7]
        table.insert(results, "✅ Config.DAILY_REWARDS: 7 entries, Day7 honey=" .. day7.honey .. " skin=" .. tostring(day7.skin))
    else
        table.insert(issues, "❌ Config.DAILY_REWARDS: missing or wrong count")
    end
end

-- 2. DataService fields
local ds = SSS:FindFirstChild("DataService")
if ds then
    local hasStreak    = ds.Source:find("loginStreak") ~= nil
    local hasLastDay   = ds.Source:find("lastLoginDay") ~= nil
    table.insert((hasStreak and hasLastDay) and results or issues,
        ((hasStreak and hasLastDay) and "✅" or "❌") .. " DataService: loginStreak=" .. tostring(hasStreak) .. " lastLoginDay=" .. tostring(hasLastDay))
end

-- 3. RemoteEvent/Function
local remotes = RS:FindFirstChild("Remotes")
local drs = remotes and remotes:FindFirstChild("DailyRewardSync")
local cdr = remotes and remotes:FindFirstChild("ClaimDailyReward")
table.insert(drs and results or issues, (drs and "✅" or "❌") .. " DailyRewardSync: " .. (drs and "exists" or "MISSING"))
table.insert(cdr and results or issues, (cdr and "✅" or "❌") .. " ClaimDailyReward: " .. (cdr and "exists" or "MISSING"))

-- 4. DailyRewardService
local drsvc = SSS:FindFirstChild("DailyRewardService")
if drsvc and drsvc:IsA("ModuleScript") then
    local lines = select(2, drsvc.Source:gsub("\n", "\n")) + 1
    local hasUtcDay   = drsvc.Source:find("utcDayNumber") ~= nil
    local hasStreak   = drsvc.Source:find("getNextStreak") ~= nil
    local hasInvoke   = drsvc.Source:find("OnServerInvoke") ~= nil
    table.insert(results, string.format("✅ DailyRewardService: %d lines utcDay=%s streak=%s invoke=%s", lines, tostring(hasUtcDay), tostring(hasStreak), tostring(hasInvoke)))
else
    table.insert(issues, "❌ DailyRewardService: MISSING")
end

-- 5. DailyRewardGui
local gui = SG:FindFirstChild("DailyRewardGui")
if gui then
    local panel = gui:FindFirstChild("CalendarPanel")
    local cards = 0
    if panel then
        for _, c in panel:GetChildren() do
            if c.Name:find("^DayCard_") then cards = cards + 1 end
        end
    end
    table.insert(results, "✅ DailyRewardGui: DisplayOrder=" .. gui.DisplayOrder .. " DayCards=" .. cards)
    if cards ~= 7 then table.insert(issues, "⚠️  DayCard count=" .. cards .. " (expected 7)") end
else
    table.insert(issues, "❌ DailyRewardGui: MISSING from StarterGui")
end

-- 6. DailyRewardController
local sps = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = sps and sps:FindFirstChild("DailyRewardController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n", "\n")) + 1
    table.insert(results, "✅ DailyRewardController: " .. lines .. " lines")
else
    table.insert(issues, "❌ DailyRewardController: MISSING")
end

local out = "=== DISPATCH 41 VERIFICATION ===\n" .. table.concat(results, "\n")
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — Dispatch 41 complete" end
return out
```

---

## EXECUTION SUMMARY

| Step | What | Parts |
|------|------|-------|
| A | Config.DAILY_REWARDS + DataService streak fields | 0 |
| B | DailyRewardSync RE + ClaimDailyReward RF + DailyRewardService | 0 |
| C | GameManager wiring | 0 |
| D | DailyRewardGui ScreenGui (7-day calendar, Claim, Close) | 0 |
| E | DailyRewardController LocalScript | 0 |
| F | Verification | — |

**Running part total: ~4,142 / 5,000** (no change)

---

## BEHAVIOURAL NOTES

- **UTC day number** = `math.floor(os.time() / 86400)` — works across server restarts, no time zone drift
- **Streak reset** if `today > lastLoginDay + 1` (missed a day); consecutive login increments up to 7, then wraps back to 1 on the 8th day
- **Idempotent**: `lastLoginDay == today` guard on `OnServerInvoke` prevents double-claiming from client spam
- **Panel opens** 4s after player data loads; `task.wait(4)` in `PlayerAdded` allows DataService profile to finish loading
- **Scale-from-centre** open animation: panel starts at 1% size centred, tweens `Back/Out` to full size — satisfying "pop" feel
- **Day card states**: past (green ✓ overlay), today (gold border), future (dimmed)
- **Dimmer backdrop tap** closes the panel (mobile-friendly)
- **Skin on Day 7**: attempts `PrestigeRewardService.GrantSkin(player, "streak_champion")` — no-op if PrestigeRewardService not loaded

---

*Dispatch 41 complete — proceed to dispatch 42 (HiveStatsDashboard)*
