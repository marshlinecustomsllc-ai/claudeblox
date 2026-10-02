# Dispatch 150 — Hive Population Display
## Cycle 14 · A Bee's World

**Feature:** Live "Bee Count" HUD element — a small panel in the bottom-left corner showing how many bees are in the player's colony. Bee count is calculated from `CombCellCount × (10 + PrestigeLevel × 5)` — so a Day 1 player with 3 cells has 30 bees, while a Prestige 2 player with 9 cells has 180 bees. The number rises smoothly with a tween counter animation when it changes. No new server attributes; entirely client-side cosmetic. Part budget: +0 permanent (LocalScript only).
**Part budget impact:** +0 permanent → **4,157 / 5,000**
**Execution order:** After dispatch 149 (Cell Upgrade System)

---

## DESIGN

### Why display a "bee count"?

Kids playing tycoon games love to see big numbers grow. A bee count ties the abstract `CombCellCount` number to something tangible — a colony of workers. It also communicates prestige value visually: a Prestige 2 player's 9-cell hive has 180 bees vs. a fresh player's 90 bees. Adults immediately understand the prestige multiplier; kids just see more bees and want to get more.

### Formula

```
beeCount = CombCellCount × (10 + PrestigeLevel × 5)
```

| Cells | Prestige 0 | Prestige 1 | Prestige 2 | Prestige 3 |
|-------|-----------|-----------|-----------|-----------|
| 3 | 30 | 45 | 60 | 75 |
| 6 | 60 | 90 | 120 | 150 |
| 9 | 90 | 135 | 180 | 225 |

### Display format

```
🐝 Colony: 90 bees
```

Counter tweens from old value to new value over 0.8 seconds (integer steps via `math.floor` every frame) when `CombCellCount` or `PrestigeLevel` changes.

### Position

Bottom-left: `{0, 8, 1, -72}`, size `{0, 160, 0, 28}`. This is below the left-side Propolis Shop toggle `{0,8,0.5,-80}` and Prestige button `{0,8,0.5,32}` — it sits in the very bottom-left corner, separate from the button column. `DisplayOrder=10`.

---

## SCRIPT SOURCE — BeePopulationController

```lua
--!strict
-- BeePopulationController — dispatch 150
-- Live bee colony count display (bottom-left HUD, cosmetic).

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_150 = Color3.fromRGB(242, 168,  28)
local DARK_150  = Color3.fromRGB(40,  25,   8)

-- ── GUI ──────────────────────────────────────────────────────────────
local sg_150: ScreenGui? = nil
local pill_150: Frame?   = nil
local label_150: TextLabel? = nil

local function ensureGui_150()
    if sg_150 and sg_150.Parent then return end
    sg_150 = Instance.new("ScreenGui")
    sg_150.Name         = "BeePopulationGui"
    sg_150.ResetOnSpawn = false
    sg_150.DisplayOrder = 10
    sg_150.Parent       = playerGui

    local pill = Instance.new("Frame")
    pill.Name                   = "BeePopPill"
    pill.Size                   = UDim2.new(0, 160, 0, 28)
    pill.Position               = UDim2.new(0, 8, 1, -72)
    pill.BackgroundColor3       = DARK_150
    pill.BackgroundTransparency = 0.15
    pill.BorderSizePixel        = 0
    pill.Parent                 = sg_150 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1,0); corner.Parent = pill
    local stroke = Instance.new("UIStroke"); stroke.Color = AMBER_150; stroke.Thickness = 0.8; stroke.Parent = pill

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 1, 0)
    lbl.Position               = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 12
    lbl.TextColor3             = AMBER_150
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Text                   = "🐝 Colony: …"
    lbl.Parent                 = pill

    pill_150  = pill
    label_150 = lbl
end

-- ── Counter animation ─────────────────────────────────────────────
local displayCount_150: number = 0  -- current displayed value (animated)
local targetCount_150:  number = 0  -- target value

local function calcBeeCount_150(): number
    local cells    = tonumber(player:GetAttribute("CombCellCount")) or 3
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    return cells * (10 + prestige * 5)
end

local animConn_150: RBXScriptConnection? = nil

local function animateTo_150(target: number)
    targetCount_150 = target
    if animConn_150 then
        animConn_150:Disconnect()
        animConn_150 = nil
    end
    local start    = displayCount_150
    local elapsed  = 0
    local duration = 0.8

    animConn_150 = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local t  = math.min(1, elapsed / duration)
        -- Ease out cubic
        local eased = 1 - (1 - t) ^ 3
        displayCount_150 = math.floor(start + (target - start) * eased)
        if label_150 then
            (label_150 :: TextLabel).Text = "🐝 Colony: " .. displayCount_150
        end
        if t >= 1 then
            displayCount_150 = target
            if label_150 then
                (label_150 :: TextLabel).Text = "🐝 Colony: " .. target
            end
            if animConn_150 then animConn_150:Disconnect(); animConn_150 = nil end
        end
    end)
end

local function onStatsChanged_150()
    local newCount = calcBeeCount_150()
    if newCount ~= targetCount_150 then
        animateTo_150(newCount)
    end
end

-- ── Init ─────────────────────────────────────────────────────────
ensureGui_150()
displayCount_150 = calcBeeCount_150()
targetCount_150  = displayCount_150
if label_150 then
    (label_150 :: TextLabel).Text = "🐝 Colony: " .. displayCount_150
end

player:GetAttributeChangedSignal("CombCellCount"):Connect(onStatsChanged_150)
player:GetAttributeChangedSignal("PrestigeLevel"):Connect(onStatsChanged_150)

print("[BeePopulationController] Ready — colony: " .. displayCount_150 .. " bees")
```

---

## STEP A — Create BeePopulationController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("BeePopulationController") then
    print("⏭️  BeePopulationController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "BeePopulationController"
    ctrl.Source = [[
--!strict
-- BeePopulationController — dispatch 150
-- Live bee colony count display (bottom-left HUD, cosmetic).

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_150 = Color3.fromRGB(242, 168,  28)
local DARK_150  = Color3.fromRGB(40,  25,   8)

local sg_150: ScreenGui? = nil
local label_150: TextLabel? = nil

local function ensureGui_150()
    if sg_150 and sg_150.Parent then return end
    sg_150 = Instance.new("ScreenGui")
    sg_150.Name         = "BeePopulationGui"
    sg_150.ResetOnSpawn = false
    sg_150.DisplayOrder = 10
    sg_150.Parent       = playerGui

    local pill = Instance.new("Frame")
    pill.Name                   = "BeePopPill"
    pill.Size                   = UDim2.new(0, 160, 0, 28)
    pill.Position               = UDim2.new(0, 8, 1, -72)
    pill.BackgroundColor3       = DARK_150
    pill.BackgroundTransparency = 0.15
    pill.BorderSizePixel        = 0
    pill.Parent                 = sg_150 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1,0); corner.Parent = pill
    local stroke = Instance.new("UIStroke"); stroke.Color = AMBER_150; stroke.Thickness = 0.8; stroke.Parent = pill

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 1, 0)
    lbl.Position               = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 12
    lbl.TextColor3             = AMBER_150
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Text                   = "🐝 Colony: …"
    lbl.Parent                 = pill

    label_150 = lbl
end

local displayCount_150: number = 0
local targetCount_150:  number = 0
local animConn_150: RBXScriptConnection? = nil

local function calcBeeCount_150(): number
    local cells    = tonumber(player:GetAttribute("CombCellCount")) or 3
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    return cells * (10 + prestige * 5)
end

local function animateTo_150(target: number)
    targetCount_150 = target
    if animConn_150 then animConn_150:Disconnect(); animConn_150 = nil end
    local start   = displayCount_150
    local elapsed = 0

    animConn_150 = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local t     = math.min(1, elapsed / 0.8)
        local eased = 1 - (1 - t) ^ 3
        displayCount_150 = math.floor(start + (target - start) * eased)
        if label_150 then
            (label_150 :: TextLabel).Text = "🐝 Colony: " .. displayCount_150
        end
        if t >= 1 then
            displayCount_150 = target
            if label_150 then (label_150 :: TextLabel).Text = "🐝 Colony: " .. target end
            if animConn_150 then animConn_150:Disconnect(); animConn_150 = nil end
        end
    end)
end

local function onStatsChanged_150()
    local n = calcBeeCount_150()
    if n ~= targetCount_150 then animateTo_150(n) end
end

ensureGui_150()
displayCount_150 = calcBeeCount_150()
targetCount_150  = displayCount_150
if label_150 then (label_150 :: TextLabel).Text = "🐝 Colony: " .. displayCount_150 end

player:GetAttributeChangedSignal("CombCellCount"):Connect(onStatsChanged_150)
player:GetAttributeChangedSignal("PrestigeLevel"):Connect(onStatsChanged_150)

print("[BeePopulationController] Ready — colony: " .. displayCount_150 .. " bees")
]]
    ctrl.Parent = SPS
    print("✅ BeePopulationController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("BeePopulationController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " BeePopulationController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("CombCellCount", 1, true) and "✅" or "❌") .. " CombCellCount attribute read")
table.insert(checks, (ctrl and ctrl.Source:find("PrestigeLevel", 1, true) and "✅" or "❌") .. " PrestigeLevel attribute read")
table.insert(checks, (ctrl and ctrl.Source:find("BeePopPill", 1, true) and "✅" or "❌") .. " BeePopPill UI element")
table.insert(checks, (ctrl and ctrl.Source:find("RunService.Heartbeat", 1, true) and "✅" or "❌") .. " Heartbeat counter animation")
table.insert(checks, (ctrl and ctrl.Source:find("animConn_150", 1, true) and "✅" or "❌") .. " animConn_150 cleanup")
table.insert(checks, (ctrl and ctrl.Source:find("DisplayOrder = 10", 1, true) and "✅" or "❌") .. " DisplayOrder=10")

print("=== DISPATCH 150 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 150 complete" or "❌ SOME CHECKS FAILED")

print("\nFormula: CombCellCount × (10 + PrestigeLevel × 5)")
print("Examples: 3 cells P0=30 | 9 cells P0=90 | 9 cells P2=180 | 9 cells P3=225")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BeePopulationController (LocalScript — no permanent count) | 0 |
| **Dispatch 150 total** | **+0** |
| **Running total** | **4,157 / 5,000** |

---

## NOTES

- `RunService.Heartbeat` for the counter animation (rather than a tween on a number value) is the standard pattern for animating integer labels in Roblox. TweenService doesn't natively tween `TextLabel.Text` with integer snapping. The Heartbeat loop is cleaned up immediately when animation finishes (`animConn_150:Disconnect()`), so it has zero overhead while idle.
- The formula `cells × (10 + prestige × 5)` is designed to make prestige visually meaningful without changing gameplay balance. The "bee count" is purely cosmetic — it doesn't affect resource generation. But a Prestige 3 player seeing "🐝 Colony: 225 bees" vs. a new player's 30 is a powerful social signal.
- `DisplayOrder=10` is below the foraging timer (11), temperature pill (12), and all other UI, but above Roblox's default UI (0). This keeps the bee count always visible as a persistent HUD element.
- The bottom-left position `{0,8,1,-72}` avoids the right-side column buttons and the left-side prestige/propolis buttons (those are anchored to the middle-left at `0.5` Y). Negative Y offset puts it 72px from the bottom edge, well above the mobile home bar safe zone.
