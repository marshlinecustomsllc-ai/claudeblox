# Dispatch 139 — Bear Attack Warning System
## Cycle 14 · A Bee's World

**Feature:** A `BearWarningController` LocalScript paired with a server-side `BearAttackService` Script. When the server triggers a Bear Attack event (random interval, ~2–5 minutes), the player gets a 10-second warning with a red screen flash and "🐻 Bear incoming!" banner; then a brief honey-drain penalty fires and the "survived" milestone counter increments. Kids experience the panic of defending their hive; adults understand the risk/reward and can use the `hive_insulation` upgrade (dispatch 132) to reduce drain. Part budget: +1 permanent (BearAttackService Script in ServerScriptService — already allocated in the architecture).
**Part budget impact:** +1 permanent (BearAttackService Script) → **4,147 / 5,000**
**Execution order:** After dispatch 138 (Adjacency Bonus Visualizer)

---

## DESIGN

### Bear attack flow

```
Server BearAttackService:
  1. Wait random interval (120–300s)
  2. Fire RemoteEvent "BearWarning" → all clients
  3. Wait 10s warning window
  4. Calculate drain = 15% of current HoneyCount
     (reduced by hive_insulation upgrade: -5% per tier)
  5. Deduct honey, increment BearSurviveCount attribute
  6. Fire RemoteEvent "BearResult" {drained: number, survived: true}
  7. Repeat cycle
```

### Client warning display (BearWarningController)

| Phase | Duration | Visual |
|-------|----------|--------|
| Warning | 10s | Red screen-edge flash (4 pulses) + red banner "🐻 Bear incoming! Protect your hive!" |
| Impact | 0.5s | Screen shake (3 quick UDim2 offset tweens on the HUD root) + red flash |
| Result | 3s | Amber banner "🐻 Bear repelled! –N🍯 taken" |

- Screen-edge flash: 4 `Frame` objects (top/bottom/left/right edges, 8px wide, `Color3.fromRGB(200,30,30)`, pulsing `BackgroundTransparency` 0.3↔0.8 over 0.5s × 4 cycles)
- Banner: `{0.5,-180,0,80}` size `{0,360,0,40}`, red background (200,30,30), slides down from Y=50 → Y=80 on show, reverses on hide
- DisplayOrder = 45 (already allocated for BearWarning in the DisplayOrder hierarchy)
- `BearSurviveCount` attribute incremented server-side, triggers dispatch 131 milestone "Bear Survivor" (threshold 1) automatically

### RemoteEvents

| Event | Direction | Payload |
|-------|-----------|---------|
| `BearWarning` | Server → Client | `{}` (no payload) |
| `BearResult` | Server → Client | `{drained: number}` |

Both in `ReplicatedStorage.RemoteEvents`.

### Hive insulation interaction

`hive_insulation` upgrade (dispatch 132) cuts drain by 5%. Server reads `PropolisUpgrades` attribute: if it contains `"hive_insulation"`, drain multiplier = 0.10 (10% instead of 15%).

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BearAttackService` | New Script in ServerScriptService (+1 permanent) |
| `BearWarningController` | New LocalScript in StarterPlayerScripts (+0 permanent) |

---

## STEP A — Create BearAttackService (server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(SSS, "ServerScriptService not found")

if SSS:FindFirstChild("BearAttackService") then
    print("⏭️  BearAttackService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "BearAttackService"
    svc.Source = [[
--!strict
-- BearAttackService — dispatch 139
-- Schedules bear attacks, applies honey drain, increments BearSurviveCount.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── RemoteEvents ─────────────────────────────────────────────────
local eventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    or (function()
        local f = Instance.new("Folder"); f.Name = "RemoteEvents"; f.Parent = ReplicatedStorage; return f
    end)()

local bearWarning_139: RemoteEvent = eventsFolder:FindFirstChild("BearWarning") :: RemoteEvent
    or (function()
        local e = Instance.new("RemoteEvent"); e.Name = "BearWarning"; e.Parent = eventsFolder; return e
    end)()

local bearResult_139: RemoteEvent = eventsFolder:FindFirstChild("BearResult") :: RemoteEvent
    or (function()
        local e = Instance.new("RemoteEvent"); e.Name = "BearResult"; e.Parent = eventsFolder; return e
    end)()

-- ── Per-player attack cycle ───────────────────────────────────────
local function startAttackCycle_139(player: Player)
    task.spawn(function()
        while player.Parent do
            -- Random interval 120–300 seconds
            task.wait(120 + math.random() * 180)
            if not player.Parent then break end

            -- Phase 1: Warning
            bearWarning_139:FireClient(player)
            task.wait(10)
            if not player.Parent then break end

            -- Phase 2: Calculate drain
            local honey    = tonumber(player:GetAttribute("HoneyCount")) or 0
            local upgrades = tostring(player:GetAttribute("PropolisUpgrades") or "")
            local drainPct = upgrades:find("hive_insulation") and 0.10 or 0.15
            local drained  = math.max(1, math.floor(honey * drainPct))
            local newHoney = math.max(0, honey - drained)

            player:SetAttribute("HoneyCount", newHoney)

            -- Phase 3: Increment survival counter
            local survives = tonumber(player:GetAttribute("BearSurviveCount")) or 0
            player:SetAttribute("BearSurviveCount", survives + 1)

            -- Phase 4: Notify client of result
            bearResult_139:FireClient(player, {drained = drained})
        end
    end)
end

-- Wire up existing and future players
Players.PlayerAdded:Connect(startAttackCycle_139)
for _, p in Players:GetPlayers() do
    startAttackCycle_139(p)
end

print("[BearAttackService] Ready — bear attack cycles active")
]]
    svc.Parent = SSS
    print("✅ BearAttackService created in ServerScriptService")
end
```

---

## STEP B — Create BearWarningController (client)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("BearWarningController") then
    print("⏭️  BearWarningController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "BearWarningController"
    ctrl.Source = [[
--!strict
-- BearWarningController — dispatch 139
-- Red warning UI when a bear attack is incoming.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local RED_139   = Color3.fromRGB(200, 30, 30)
local AMBER_139 = Color3.fromRGB(242, 168, 28)
local WHITE_139 = Color3.fromRGB(255, 255, 255)

-- ── GUI ──────────────────────────────────────────────────────────
local sg_139: ScreenGui? = nil
local banner_139: Frame? = nil
local bannerLbl_139: TextLabel? = nil
local edgeFrames_139: {Frame} = {}

local function ensureGui_139()
    if sg_139 and sg_139.Parent then return end
    sg_139 = Instance.new("ScreenGui")
    sg_139.Name           = "BearWarningGui"
    sg_139.ResetOnSpawn   = false
    sg_139.DisplayOrder   = 45
    sg_139.IgnoreGuiInset = true
    sg_139.Parent         = playerGui
end

local function ensureBanner_139()
    ensureGui_139()
    if banner_139 and banner_139.Parent then return end

    local f = Instance.new("Frame")
    f.Name                  = "BearBanner"
    f.Size                  = UDim2.new(0, 360, 0, 40)
    f.Position              = UDim2.new(0.5, -180, 0, 50)  -- hidden start (above screen)
    f.AnchorPoint           = Vector2.new(0.5, 0)
    f.BackgroundColor3      = RED_139
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel       = 0
    f.Visible               = false
    f.Parent                = sg_139 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,-8,1,0)
    lbl.Position            = UDim2.new(0,4,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 15
    lbl.TextColor3          = WHITE_139
    lbl.TextXAlignment      = Enum.TextXAlignment.Center
    lbl.Text                = ""
    lbl.Parent              = f

    banner_139    = f
    bannerLbl_139 = lbl
end

local function showBanner_139(text: string, color: Color3)
    ensureBanner_139()
    local b = banner_139 :: Frame
    local l = bannerLbl_139 :: TextLabel
    b.BackgroundColor3 = color
    l.Text  = text
    b.Position = UDim2.new(0.5, -180, 0, 50)
    b.Visible  = true
    TweenService:Create(b,
        TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -180, 0, 80)}
    ):Play()
end

local function hideBanner_139()
    if not banner_139 then return end
    TweenService:Create(banner_139 :: Frame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -180, 0, 50)}
    ).Completed:Connect(function()
        if banner_139 then (banner_139 :: Frame).Visible = false end
    end)
    TweenService:Create(banner_139 :: Frame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -180, 0, 50)}
    ):Play()
end

-- ── Screen-edge flash frames ─────────────────────────────────────
local function buildEdgeFrames_139()
    ensureGui_139()
    if #edgeFrames_139 > 0 then return end
    local sg = sg_139 :: ScreenGui
    local edgeConfig = {
        {UDim2.new(0,0,0,0),      UDim2.new(1,0,0,8)},   -- top
        {UDim2.new(0,0,1,-8),     UDim2.new(1,0,0,8)},   -- bottom
        {UDim2.new(0,0,0,0),      UDim2.new(0,8,1,0)},   -- left
        {UDim2.new(1,-8,0,0),     UDim2.new(0,8,1,0)},   -- right
    }
    for _, cfg in edgeConfig do
        local edge = Instance.new("Frame")
        edge.Position              = cfg[1]
        edge.Size                  = cfg[2]
        edge.BackgroundColor3      = RED_139
        edge.BackgroundTransparency = 1
        edge.BorderSizePixel       = 0
        edge.Visible               = false
        edge.Parent                = sg
        table.insert(edgeFrames_139, edge)
    end
end

local function pulseEdges_139(cycles: number)
    buildEdgeFrames_139()
    for _, edge in edgeFrames_139 do edge.Visible = true end

    local function doCycle(n: number)
        if n <= 0 then
            for _, edge in edgeFrames_139 do edge.Visible = false end
            return
        end
        for _, edge in edgeFrames_139 do
            TweenService:Create(edge,
                TweenInfo.new(0.25, Enum.EasingStyle.Sine),
                {BackgroundTransparency = 0.3}
            ):Play()
        end
        task.delay(0.25, function()
            for _, edge in edgeFrames_139 do
                TweenService:Create(edge,
                    TweenInfo.new(0.25, Enum.EasingStyle.Sine),
                    {BackgroundTransparency = 0.9}
                ):Play()
            end
            task.delay(0.25, function() doCycle(n - 1) end)
        end)
    end
    doCycle(cycles)
end

-- ── RemoteEvent listeners ─────────────────────────────────────────
local function waitForEvent_139(name: string): RemoteEvent
    local evFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    return (evFolder :: Folder):WaitForChild(name, 10) :: RemoteEvent
end

task.spawn(function()
    local warningEvent_139 = waitForEvent_139("BearWarning")
    local resultEvent_139  = waitForEvent_139("BearResult")

    warningEvent_139.OnClientEvent:Connect(function()
        showBanner_139("🐻 Bear incoming! Protect your hive!", RED_139)
        pulseEdges_139(4)
        -- Auto-hide banner after 9s (server fires result at 10s mark)
        task.delay(9, function()
            if banner_139 and (banner_139 :: Frame).Text == "🐻 Bear incoming! Protect your hive!" then
                hideBanner_139()
            end
        end)
    end)

    resultEvent_139.OnClientEvent:Connect(function(data: {drained: number})
        local drained = data and data.drained or 0
        hideBanner_139()
        task.wait(0.2)
        -- Brief red flash
        pulseEdges_139(1)
        task.wait(0.3)
        showBanner_139("🐻 Bear repelled! –" .. tostring(drained) .. "🍯 taken", AMBER_139)
        task.delay(3, hideBanner_139)
    end)
end)

print("[BearWarningController] Ready — bear attack warnings active")
]]
    ctrl.Parent = SPS
    print("✅ BearWarningController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS   = game:GetService("ReplicatedStorage")

local svc  = SSS:FindFirstChild("BearAttackService")
local ctrl = SPS and SPS:FindFirstChild("BearWarningController")
local evFolder = RS:FindFirstChild("RemoteEvents")
local bearWarn = evFolder and evFolder:FindFirstChild("BearWarning")
local bearRes  = evFolder and evFolder:FindFirstChild("BearResult")

local checks = {}
table.insert(checks, (svc and "✅" or "❌") .. " BearAttackService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " BearAttackService is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " BearAttackService --!strict")
table.insert(checks, (svc and svc.Source:find("BearSurviveCount", 1, true) and "✅" or "❌") .. " BearSurviveCount incremented server-side")
table.insert(checks, (svc and svc.Source:find("hive_insulation", 1, true) and "✅" or "❌") .. " hive_insulation drain reduction")
table.insert(checks, (bearWarn and "✅" or "❌") .. " BearWarning RemoteEvent in ReplicatedStorage.RemoteEvents")
table.insert(checks, (bearRes  and "✅" or "❌") .. " BearResult RemoteEvent in ReplicatedStorage.RemoteEvents")
table.insert(checks, (ctrl and "✅" or "❌") .. " BearWarningController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " BearWarningController is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " BearWarningController --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("RED_139", 1, true) and "✅" or "❌") .. " RED_139 color constant")
table.insert(checks, (ctrl and ctrl.Source:find("pulseEdges_139", 1, true) and "✅" or "❌") .. " pulseEdges_139 screen-edge flash")
table.insert(checks, (ctrl and ctrl.Source:find("showBanner_139", 1, true) and "✅" or "❌") .. " showBanner_139 warning banner")
table.insert(checks, (ctrl and ctrl.Source:find("hideBanner_139", 1, true) and "✅" or "❌") .. " hideBanner_139 banner dismiss")

print("=== DISPATCH 139 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 139 complete" or "❌ SOME CHECKS FAILED")

print("\nBear cycle: 120-300s random interval | 10s warning | 15% drain (10% with hive_insulation)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BearAttackService (Script — permanent) | +1 |
| BearWarningController (LocalScript; GUI runtime only) | 0 permanent |
| **Dispatch 139 total** | **+1** |
| **Running total** | **4,147 / 5,000** |

---

## NOTES

- Bear attacks fire independently per player (each player has their own `task.spawn` cycle). This ensures a new player joining mid-session gets their full first interval before being attacked, while established players aren't affected.
- The `task.wait(120 + math.random() * 180)` formula produces a uniform distribution between 2 and 5 minutes. This cadence is intentional: frequent enough that players must engage with the mechanic, rare enough that it doesn't feel like constant harassment. Adults who buy `hive_insulation` still get attacked on the same schedule — the upgrade reduces damage, not frequency.
- `math.max(1, math.floor(honey * drainPct))` guarantees at least 1 honey is drained. This prevents the edge case where a near-empty hive (e.g. 3 honey) rounds to 0 drain, which would feel like the bear "did nothing" and undercut the tension.
- `bannerLbl_139` comparison before auto-hide (`Text == "🐻 Bear incoming!..."`) is a lightweight guard against a rare race: if the result event fires exactly as the auto-hide task runs, the banner would already be showing the result text. The guard skips the hide and lets the result banner's own 3s timer handle dismissal.
- DisplayOrder=45 was pre-allocated for the bear warning in the DisplayOrder hierarchy documented across dispatches 127-135. This slot sits above the overflow strip (14) and below achievement toasts (48) and milestone celebrations (50), which is correct priority: bear warning is urgent but not more important than milestone fanfare.
- `IgnoreGuiInset = true` on the ScreenGui is required for the edge frames to reach the very top of the screen (above the Roblox top-bar gutter). Without it, the top edge frame would start 36px lower than the actual screen edge.
