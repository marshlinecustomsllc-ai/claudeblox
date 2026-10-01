# Dispatch 145 — Daily Login Reward System
## Cycle 14 · A Bee's World

**Feature:** Daily login rewards — players who return each day collect an escalating bonus (honey + propolis) with a streak counter. Day 1: 50 honey. Day 7: 300 honey + 20 propolis + a special "Busy Bee" badge title on their row in the leaderboard. Streak resets if a day is missed. Kids see the streak stars and want to come back; adults recognise the compounding value. Part budget: +2 permanent (one server Script + one LocalScript).
**Part budget impact:** +2 permanent → **4,152 / 5,000**
**Execution order:** After dispatch 144 (HoneyEarned Tracking Service)

---

## DESIGN

### Reward table

| Day | Honey | Propolis | Extra |
|-----|-------|----------|-------|
| 1 | 50 | 0 | — |
| 2 | 80 | 0 | — |
| 3 | 120 | 5 | — |
| 4 | 160 | 8 | — |
| 5 | 200 | 12 | — |
| 6 | 250 | 16 | — |
| 7 | 300 | 20 | ⭐ Streak bonus |
| 8+ | repeats from Day 1 | | |

Day 7 is the weekly goal. The streak resets on Day 8 back to Day 1 — encouraging repeat weekly engagement rather than an infinite ramp that loses meaning.

### Streak tracking

Two player attributes:
- `LoginStreak` (number) — current consecutive-day count, 1–7
- `LastLoginDay` (number) — `os.time()` divided by 86400, floored — the "day number" (consistent across time zones since it's server time)

On player join: compare today's day number to `LastLoginDay`.
- Same day → already claimed, skip
- Yesterday → streak continues, increment
- Older than yesterday → streak broken, reset to 1
- Never played → streak = 1

### Client notification

`DailyLoginController` LocalScript — shows a compact animated panel on join with the day number, reward amount, and streak stars. Auto-dismisses after 4 seconds. Uses the Warm Wax house style.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DailyLoginService` | New Script in ServerScriptService |
| `DailyLoginController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create DailyLoginService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("DailyLoginService") then
    print("⏭️  DailyLoginService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "DailyLoginService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- DailyLoginService — dispatch 145
-- Daily login streak + escalating honey/propolis reward.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvent to notify client of reward
local RE_145: RemoteEvent = (function()
    local existing = ReplicatedStorage:FindFirstChild("DailyLoginGranted")
    if existing and existing:IsA("RemoteEvent") then return existing :: RemoteEvent end
    local re = Instance.new("RemoteEvent")
    re.Name   = "DailyLoginGranted"
    re.Parent = ReplicatedStorage
    return re
end)()

type RewardRow_145 = {honey: number, propolis: number, star: boolean}
local REWARDS_145: {RewardRow_145} = {
    {honey = 50,  propolis = 0,  star = false},
    {honey = 80,  propolis = 0,  star = false},
    {honey = 120, propolis = 5,  star = false},
    {honey = 160, propolis = 8,  star = false},
    {honey = 200, propolis = 12, star = false},
    {honey = 250, propolis = 16, star = false},
    {honey = 300, propolis = 20, star = true },
}

local function dayNumber_145(): number
    return math.floor(os.time() / 86400)
end

local function onPlayerAdded_145(player: Player)
    task.wait(2)  -- DataService replication
    if not player.Parent then return end

    local today     = dayNumber_145()
    local lastDay   = tonumber(player:GetAttribute("LastLoginDay")) or 0
    local streak    = tonumber(player:GetAttribute("LoginStreak"))  or 0

    if lastDay == today then
        -- Already claimed today — notify client with current streak only (no reward)
        RE_145:FireClient(player, {
            day      = streak,
            honey    = 0,
            propolis = 0,
            star     = false,
            already  = true,
        })
        return
    end

    -- Determine new streak
    local newStreak: number
    if today - lastDay == 1 then
        -- Consecutive day
        newStreak = streak + 1
    else
        -- Missed a day or first login
        newStreak = 1
    end
    -- Cap at 7 (day 8 resets to 1)
    if newStreak > 7 then newStreak = 1 end

    local row = REWARDS_145[newStreak]

    -- Apply rewards (server-authoritative)
    local honey     = tonumber(player:GetAttribute("HoneyCount"))    or 0
    local propolis  = tonumber(player:GetAttribute("PropolisCount")) or 0
    player:SetAttribute("HoneyCount",    honey    + row.honey)
    player:SetAttribute("PropolisCount", propolis + row.propolis)

    -- Update streak attributes
    player:SetAttribute("LoginStreak",   newStreak)
    player:SetAttribute("LastLoginDay",  today)

    -- Fire client notification
    RE_145:FireClient(player, {
        day      = newStreak,
        honey    = row.honey,
        propolis = row.propolis,
        star     = row.star,
        already  = false,
    })

    print(string.format("[DailyLoginService] %s: day %d streak, +%d honey, +%d propolis%s",
        player.Name, newStreak, row.honey, row.propolis, row.star and " ⭐" or ""))
end

Players.PlayerAdded:Connect(onPlayerAdded_145)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayerAdded_145, p)
end

print("[DailyLoginService] Ready — daily login rewards active")
]]
    svc.Parent = SSS
    print("✅ DailyLoginService created")
end
```

---

## STEP B — Create DailyLoginController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("DailyLoginController") then
    print("⏭️  DailyLoginController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "DailyLoginController"
    ctrl.Source = [[
--!strict
-- DailyLoginController — dispatch 145
-- Shows daily login reward panel on join (auto-dismisses after 4s).

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local DARK_145  = Color3.fromRGB(40,  25,   8)
local AMBER_145 = Color3.fromRGB(242, 168,  28)
local WHITE_145 = Color3.fromRGB(255, 255, 255)
local GREEN_145 = Color3.fromRGB(80,  200,  80)

local DAY_LABELS_145 = {"Day 1","Day 2","Day 3","Day 4","Day 5","Day 6","Day 7 ⭐"}

-- Build panel (created on-demand)
local sg_145: ScreenGui? = nil

local function buildPanel_145(): Frame
    if not sg_145 or not sg_145.Parent then
        sg_145 = Instance.new("ScreenGui")
        sg_145.Name         = "DailyLoginGui"
        sg_145.ResetOnSpawn = false
        sg_145.DisplayOrder = 30
        sg_145.Parent       = playerGui
    end
    -- Remove old panel if any
    local old = (sg_145 :: ScreenGui):FindFirstChild("LoginPanel")
    if old then old:Destroy() end

    local panel = Instance.new("Frame")
    panel.Name                   = "LoginPanel"
    panel.Size                   = UDim2.new(0, 260, 0, 140)
    panel.Position               = UDim2.new(0.5, -130, 0, -160)
    panel.BackgroundColor3       = DARK_145
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel        = 0
    panel.Parent                 = sg_145 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = panel
    local stroke = Instance.new("UIStroke"); stroke.Color = AMBER_145; stroke.Thickness = 1.5; stroke.Parent = panel

    return panel
end

local function showReward_145(data: {day: number, honey: number, propolis: number, star: boolean, already: boolean})
    local panel = buildPanel_145()

    -- Title
    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, -16, 0, 26)
    title.Position               = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.Font                   = Enum.Font.GothamBold
    title.TextSize               = 14
    title.TextColor3             = AMBER_145
    title.TextXAlignment         = Enum.TextXAlignment.Center
    title.Text                   = data.already and "🐝 Welcome back!" or ("🍯 " .. (DAY_LABELS_145[data.day] or "Daily Reward") .. " Bonus!")
    title.Parent                 = panel

    -- Streak stars
    local stars = Instance.new("TextLabel")
    stars.Size                   = UDim2.new(1, -16, 0, 20)
    stars.Position               = UDim2.new(0, 8, 0, 36)
    stars.BackgroundTransparency = 1
    stars.Font                   = Enum.Font.Gotham
    stars.TextSize               = 14
    stars.TextColor3             = AMBER_145
    stars.TextXAlignment         = Enum.TextXAlignment.Center
    stars.Text                   = string.rep("⭐", data.day) .. string.rep("☆", 7 - data.day)
    stars.Parent                 = panel

    if not data.already then
        -- Honey reward
        local honeyLbl = Instance.new("TextLabel")
        honeyLbl.Size                   = UDim2.new(1, -16, 0, 24)
        honeyLbl.Position               = UDim2.new(0, 8, 0, 62)
        honeyLbl.BackgroundTransparency = 1
        honeyLbl.Font                   = Enum.Font.GothamBold
        honeyLbl.TextSize               = 16
        honeyLbl.TextColor3             = AMBER_145
        honeyLbl.TextXAlignment         = Enum.TextXAlignment.Center
        honeyLbl.Text                   = "+" .. data.honey .. " 🍯 honey"
        honeyLbl.Parent                 = panel

        -- Propolis reward (only if > 0)
        if data.propolis > 0 then
            local propLbl = Instance.new("TextLabel")
            propLbl.Size                   = UDim2.new(1, -16, 0, 20)
            propLbl.Position               = UDim2.new(0, 8, 0, 88)
            propLbl.BackgroundTransparency = 1
            propLbl.Font                   = Enum.Font.Gotham
            propLbl.TextSize               = 13
            propLbl.TextColor3             = GREEN_145
            propLbl.TextXAlignment         = Enum.TextXAlignment.Center
            propLbl.Text                   = "+" .. data.propolis .. " 🟤 propolis"
            propLbl.Parent                 = panel
        end

        -- Streak note
        local note = Instance.new("TextLabel")
        note.Size                   = UDim2.new(1, -16, 0, 16)
        note.Position               = UDim2.new(0, 8, 0, 116)
        note.BackgroundTransparency = 1
        note.Font                   = Enum.Font.Gotham
        note.TextSize               = 11
        note.TextColor3             = WHITE_145
        note.TextXAlignment         = Enum.TextXAlignment.Center
        note.TextTransparency       = 0.3
        note.Text                   = data.day < 7 and ("Come back tomorrow for Day " .. (data.day + 1) .. "!") or "Full week streak! 🎉"
        note.Parent                 = panel
    else
        local sub = Instance.new("TextLabel")
        sub.Size                   = UDim2.new(1, -16, 0, 20)
        sub.Position               = UDim2.new(0, 8, 0, 62)
        sub.BackgroundTransparency = 1
        sub.Font                   = Enum.Font.Gotham
        sub.TextSize               = 12
        sub.TextColor3             = WHITE_145
        sub.TextXAlignment         = Enum.TextXAlignment.Center
        sub.TextTransparency       = 0.3
        sub.Text                   = "Streak: " .. data.day .. " day" .. (data.day == 1 and "" or "s")
        sub.Parent                 = panel
    end

    -- Slide in from top
    local tweenIn = TweenService:Create(panel,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -130, 0, 20)})
    tweenIn:Play()

    -- Auto-dismiss after 4s
    task.delay(4, function()
        if not panel.Parent then return end
        local tweenOut = TweenService:Create(panel,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -130, 0, -160)})
        tweenOut:Play()
        tweenOut.Completed:Connect(function() panel:Destroy() end)
    end)
end

-- Listen for server grant
local RE = ReplicatedStorage:WaitForChild("DailyLoginGranted", 15) :: RemoteEvent?
if RE then
    RE.OnClientEvent:Connect(function(data)
        showReward_145(data :: any)
    end)
end

print("[DailyLoginController] Ready")
]]
    ctrl.Parent = SPS
    print("✅ DailyLoginController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc  = SSS:FindFirstChild("DailyLoginService")
local ctrl = SPS and SPS:FindFirstChild("DailyLoginController")
local re   = RS:FindFirstChild("DailyLoginGranted")

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " DailyLoginService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("REWARDS_145", 1, true) and "✅" or "❌") .. " REWARDS_145 table")
table.insert(checks, (svc and svc.Source:find("LoginStreak", 1, true) and "✅" or "❌") .. " LoginStreak attribute write")
table.insert(checks, (svc and svc.Source:find("LastLoginDay", 1, true) and "✅" or "❌") .. " LastLoginDay attribute write")
table.insert(checks, (re and "✅" or "❌") .. " DailyLoginGranted RemoteEvent in ReplicatedStorage")
table.insert(checks, (ctrl and "✅" or "❌") .. " DailyLoginController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("DAY_LABELS_145", 1, true) and "✅" or "❌") .. " DAY_LABELS_145 display strings")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService slide animation")
table.insert(checks, (ctrl and ctrl.Source:find("task.delay(4", 1, true) and "✅" or "❌") .. " 4s auto-dismiss")

print("=== DISPATCH 145 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 145 complete" or "❌ SOME CHECKS FAILED")

print("\nDaily rewards: Day 1-7 escalating honey+propolis | Day 7 = ⭐ streak bonus")
print("Streak resets after Day 7 (back to Day 1 for ongoing weekly cycle)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| DailyLoginService (Script in ServerScriptService) | +1 |
| DailyLoginController (LocalScript in StarterPlayerScripts) | +1 |
| **Dispatch 145 total** | **+2** |
| **Running total** | **4,152 / 5,000** |

---

## NOTES

- `math.floor(os.time() / 86400)` gives a "day number" that's consistent server-wide and timezone-agnostic. Two players on opposite sides of the world see the same day boundary (midnight UTC). For a kids' game with no region-specific requirements, this is simpler and more reliable than per-timezone logic.
- The streak resets to Day 1 on Day 8 rather than continuing indefinitely. An infinite streak counter loses motivational punch — "Day 47" is less meaningful than "I've done Week 3 twice." A clean 7-day cycle keeps the goal visible and achievable. Adult players will recognise this as a classic MMO mechanic; kids just see the stars refilling.
- `LoginStreak` and `LastLoginDay` are player attributes, so they're automatically saved by `DataService` if it persists all attributes generically. If DataService uses an explicit field list, add both to it (same note as `HoneyEarned` in dispatch 144).
- The panel uses `DisplayOrder=30` — above the leaderboard (16), below achievement toasts (48) and the bear warning (45). It slides in from above the top edge and auto-dismisses after 4 seconds, so it doesn't interrupt any active gameplay.
- `data.already = true` path is shown when the player rejoins the same day (e.g., server hop, crash). They see their streak count but no reward animation — honest UX, no double-reward exploit.
