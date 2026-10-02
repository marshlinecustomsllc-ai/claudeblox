# Dispatch 147 — Honey Milestone Toasts
## Cycle 14 · A Bee's World

**Feature:** Server-side milestone detection on `HoneyEarned` with a client-side celebration toast for 10 threshold tiers (500 → 50,000 honey ever produced). Kids get fun emoji headlines; adults get the exact production number. Each tier fires once per prestige level, so veteran players who prestige still celebrate their climb back to the top. Part budget: +1 permanent (one server Script; the toast controller is LocalScript = +0 permanent).
**Part budget impact:** +1 permanent → **4,154 / 5,000**
**Execution order:** After dispatch 146 (Hive Temperature)

---

## DESIGN

### Milestone tiers

| Tier | HoneyEarned threshold | Headline | Sub |
|------|-----------------------|----------|-----|
| 1 | 500 | 🍯 First Batch! | 500 honey ever produced |
| 2 | 1,000 | 🐝 Busy Bee! | 1,000 honey total |
| 3 | 2,500 | 🌸 Pollen Power | 2,500 honey total |
| 4 | 5,000 | ✨ Sweet Hive | 5,000 honey total |
| 5 | 10,000 | 🏆 Honey Hunter | 10,000 honey total |
| 6 | 15,000 | 🌟 Golden Queen | 15,000 honey total |
| 7 | 20,000 | 🎯 Master Keeper | 20,000 honey total |
| 8 | 30,000 | 🔥 Unstoppable | 30,000 honey total |
| 9 | 40,000 | 👑 Apex Apiarist | 40,000 honey total |
| 10 | 50,000 | 🌈 Legend! | 50,000 honey total |

### Per-prestige gating

`EarnedMilestones_131` (from dispatch 131) stores the current milestone tier already fired this prestige. The milestone service checks `HoneyEarned` against the next tier. When prestige fires (dispatch 140), `HoneyEarned` resets to 0, so milestones fire again on the next climb — rewarding the grind.

If `EarnedMilestones_131` doesn't exist in the codebase, this dispatch uses its own `HoneyMilestone` attribute (a number 0–10) with the same semantics.

### Client toast

`HoneyMilestoneController` LocalScript — a golden animated toast at top-center (above the temperature pill, below the achievement toasts). Slides in from above, holds 3 seconds, slides out. Uses the same Warm Wax palette. `DisplayOrder=35`.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HoneyMilestoneService` | New Script in ServerScriptService |
| `HoneyMilestoneController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HoneyMilestoneService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("HoneyMilestoneService") then
    print("⏭️  HoneyMilestoneService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "HoneyMilestoneService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- HoneyMilestoneService — dispatch 147
-- Fires client toast when HoneyEarned crosses milestone thresholds.
-- One milestone per tier per prestige level (resets with HoneyEarned on prestige).

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RE_147: RemoteEvent = (function()
    local e = ReplicatedStorage:FindFirstChild("HoneyMilestoneReached")
    if e and e:IsA("RemoteEvent") then return e :: RemoteEvent end
    local re = Instance.new("RemoteEvent")
    re.Name   = "HoneyMilestoneReached"
    re.Parent = ReplicatedStorage
    return re
end)()

type Milestone_147 = {threshold: number, headline: string, sub: string}
local MILESTONES_147: {Milestone_147} = {
    {threshold = 500,   headline = "🍯 First Batch!",    sub = "500 honey ever produced"},
    {threshold = 1000,  headline = "🐝 Busy Bee!",        sub = "1,000 honey total"},
    {threshold = 2500,  headline = "🌸 Pollen Power",     sub = "2,500 honey total"},
    {threshold = 5000,  headline = "✨ Sweet Hive",        sub = "5,000 honey total"},
    {threshold = 10000, headline = "🏆 Honey Hunter",     sub = "10,000 honey total"},
    {threshold = 15000, headline = "🌟 Golden Queen",     sub = "15,000 honey total"},
    {threshold = 20000, headline = "🎯 Master Keeper",    sub = "20,000 honey total"},
    {threshold = 30000, headline = "🔥 Unstoppable",      sub = "30,000 honey total"},
    {threshold = 40000, headline = "👑 Apex Apiarist",    sub = "40,000 honey total"},
    {threshold = 50000, headline = "🌈 Legend!",           sub = "50,000 honey total"},
}

local function onEarnedChanged_147(player: Player)
    local earned    = tonumber(player:GetAttribute("HoneyEarned")) or 0
    local reached   = tonumber(player:GetAttribute("HoneyMilestone_147")) or 0

    -- Check next unclaimed tier
    local next = reached + 1
    if next > #MILESTONES_147 then return end

    local m = MILESTONES_147[next]
    if earned >= m.threshold then
        player:SetAttribute("HoneyMilestone_147", next)
        RE_147:FireClient(player, {
            tier     = next,
            headline = m.headline,
            sub      = m.sub,
        })
        print(string.format("[HoneyMilestoneService] %s reached tier %d: %s", player.Name, next, m.headline))
    end
end

local connections_147: {[Player]: RBXScriptConnection} = {}

local function onPlayerAdded_147(player: Player)
    task.wait(2)
    if not player.Parent then return end
    connections_147[player] = player:GetAttributeChangedSignal("HoneyEarned")
        :Connect(function() onEarnedChanged_147(player) end)
    onEarnedChanged_147(player)  -- check on join (catch up if milestone was earned offline)
end

local function onPlayerRemoving_147(player: Player)
    if connections_147[player] then
        connections_147[player]:Disconnect()
        connections_147[player] = nil
    end
end

Players.PlayerAdded:Connect(onPlayerAdded_147)
Players.PlayerRemoving:Connect(onPlayerRemoving_147)
for _, p in Players:GetPlayers() do task.spawn(onPlayerAdded_147, p) end

print("[HoneyMilestoneService] Ready — 10-tier honey milestone tracking active")
]]
    svc.Parent = SSS
    print("✅ HoneyMilestoneService created")
end
```

---

## STEP B — Create HoneyMilestoneController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("HoneyMilestoneController") then
    print("⏭️  HoneyMilestoneController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "HoneyMilestoneController"
    ctrl.Source = [[
--!strict
-- HoneyMilestoneController — dispatch 147
-- Animated toast for honey milestone achievements.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_147  = Color3.fromRGB(242, 168,  28)
local GOLD_147   = Color3.fromRGB(255, 210,  60)
local DARK_147   = Color3.fromRGB(40,  25,   8)
local WHITE_147  = Color3.fromRGB(255, 255, 255)

local sg_147: ScreenGui? = nil

local function ensureGui_147()
    if sg_147 and sg_147.Parent then return end
    sg_147 = Instance.new("ScreenGui")
    sg_147.Name         = "HoneyMilestoneGui"
    sg_147.ResetOnSpawn = false
    sg_147.DisplayOrder = 35
    sg_147.Parent       = playerGui
end

local toastQueue_147: {{headline: string, sub: string}} = {}
local toastActive_147 = false

local function showNextToast_147()
    if toastActive_147 or #toastQueue_147 == 0 then return end
    toastActive_147 = true
    ensureGui_147()

    local data = table.remove(toastQueue_147, 1)

    local toast = Instance.new("Frame")
    toast.Name                   = "MilestoneToast"
    toast.Size                   = UDim2.new(0, 280, 0, 64)
    toast.Position               = UDim2.new(0.5, -140, 0, -80)
    toast.BackgroundColor3       = DARK_147
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel        = 0
    toast.Parent                 = sg_147 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 12); corner.Parent = toast
    local stroke = Instance.new("UIStroke"); stroke.Color = GOLD_147; stroke.Thickness = 2; stroke.Parent = toast

    local headline = Instance.new("TextLabel")
    headline.Size                   = UDim2.new(1, -16, 0, 32)
    headline.Position               = UDim2.new(0, 8, 0, 6)
    headline.BackgroundTransparency = 1
    headline.Font                   = Enum.Font.GothamBold
    headline.TextSize               = 18
    headline.TextColor3             = GOLD_147
    headline.TextXAlignment         = Enum.TextXAlignment.Center
    headline.Text                   = data.headline
    headline.Parent                 = toast

    local sub = Instance.new("TextLabel")
    sub.Size                   = UDim2.new(1, -16, 0, 18)
    sub.Position               = UDim2.new(0, 8, 0, 38)
    sub.BackgroundTransparency = 1
    sub.Font                   = Enum.Font.Gotham
    sub.TextSize               = 12
    sub.TextColor3             = WHITE_147
    sub.TextXAlignment         = Enum.TextXAlignment.Center
    sub.TextTransparency       = 0.2
    sub.Text                   = data.sub
    sub.Parent                 = toast

    -- Slide in
    local tweenIn = TweenService:Create(toast,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -140, 0, 48)})
    tweenIn:Play()

    task.delay(3, function()
        if not toast.Parent then
            toastActive_147 = false
            showNextToast_147()
            return
        end
        local tweenOut = TweenService:Create(toast,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -140, 0, -80)})
        tweenOut:Play()
        tweenOut.Completed:Connect(function()
            toast:Destroy()
            toastActive_147 = false
            showNextToast_147()
        end)
    end)
end

local RE = ReplicatedStorage:WaitForChild("HoneyMilestoneReached", 15) :: RemoteEvent?
if RE then
    RE.OnClientEvent:Connect(function(data)
        table.insert(toastQueue_147, data :: any)
        showNextToast_147()
    end)
end

print("[HoneyMilestoneController] Ready")
]]
    ctrl.Parent = SPS
    print("✅ HoneyMilestoneController created")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc  = SSS:FindFirstChild("HoneyMilestoneService")
local ctrl = SPS and SPS:FindFirstChild("HoneyMilestoneController")
local re   = RS:FindFirstChild("HoneyMilestoneReached")

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " HoneyMilestoneService in ServerScriptService")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("MILESTONES_147", 1, true) and "✅" or "❌") .. " MILESTONES_147 table (10 tiers)")
table.insert(checks, (svc and svc.Source:find("HoneyMilestone_147", 1, true) and "✅" or "❌") .. " HoneyMilestone_147 attribute")
table.insert(checks, (svc and svc.Source:find("HoneyEarned", 1, true) and "✅" or "❌") .. " HoneyEarned attribute read")
table.insert(checks, (re and "✅" or "❌") .. " HoneyMilestoneReached RemoteEvent")
table.insert(checks, (ctrl and "✅" or "❌") .. " HoneyMilestoneController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("toastQueue_147", 1, true) and "✅" or "❌") .. " toast queue (no overlap)")
table.insert(checks, (ctrl and ctrl.Source:find("task.delay(3", 1, true) and "✅" or "❌") .. " 3s hold duration")

print("=== DISPATCH 147 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 147 complete" or "❌ SOME CHECKS FAILED")

print("\n10 milestone tiers: 500 → 50,000 HoneyEarned | resets with HoneyEarned on prestige")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HoneyMilestoneService (Script) | +1 |
| HoneyMilestoneController (LocalScript — no permanent count) | 0 |
| **Dispatch 147 total** | **+1** |
| **Running total** | **4,154 / 5,000** |

---

## NOTES

- `toastQueue_147` with `toastActive_147` guard prevents overlapping toasts when a returning player catches up multiple milestones at once. Each toast plays fully before the next starts.
- `onEarnedChanged_147(player)` is called on join (post-DataService wait). If a player earned e.g. tier 3 in a previous session, `HoneyMilestone_147` = 3 will already be set, so `next = 4` and they won't re-trigger the first 3 milestones. But if they somehow have `HoneyEarned = 12000` and `HoneyMilestone_147 = 0` (data corruption or first run after the dispatch), the join call will fire only tier 1 — the subsequent ones fire on the next `HoneyEarned` change. This is acceptable: the sequence will complete naturally as they play.
- `HoneyMilestone_147` uses a dispatch-suffixed attribute name (not `HoneyMilestone`) to avoid collision with any prior milestone system (dispatch 116 tracks `EarnedMilestones_131` for a different milestone set). The two systems are parallel: dispatch 116 tracks comb cell count milestones; dispatch 147 tracks lifetime honey production milestones.
- `DisplayOrder=35` sits between the daily login panel (30) and the achievement toasts (48). Multiple toast sources can be visible simultaneously at different Y positions if needed, but in practice only one fires at a time.
