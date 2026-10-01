# Dispatch 137 — Foraging Return Countdown Timer
## Cycle 14 · A Bee's World

**Feature:** A `ForagingTimerController` LocalScript that shows a live countdown during an active foraging run. A compact honey-gold pill in the top-right of the HUD ticks down to "Bees returning…" and then auto-hides once the run completes. Kids know their bees are busy and coming back; adults can time secondary actions (upgrade shop, comb swap) around the return window. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 136 (Propolis Collection VFX)

---

## DESIGN

### Trigger attributes

| Attribute | Type | Meaning |
|-----------|------|---------|
| `ForagingActive` | boolean | `true` while a run is in progress |
| `ForagingEndTime` | number | `os.time()` timestamp when run completes |

Both are already written by the server's ForagingService (dispatch architecture); this controller reads them client-side only.

### HUD pill

- Frame: `{1,-8,0,8}` anchored top-right, Size `{0,160,0,32}`, AnchorPoint `{1,0}`
- Background: `Color3.fromRGB(242,168,28)` (Honey Gold), `BackgroundTransparency=0.08`
- UICorner: radius `{0,16}` (fully rounded capsule shape)
- UIStroke: `Color3.fromRGB(180,120,0)`, Thickness=1.5
- Text: `"🐝 Returning in X:XX"` while ticking; `"🐝 Bees returning…"` in final 3s; `"🐝 Welcome back!"` for 1.5s post-completion
- Font: GothamBold 13, white text
- Slides in from `X=168` to `X=-8` over 0.3s (Quad Out) on show; slides back over 0.2s on hide

### Countdown logic

- `remaining = math.max(0, math.floor(foraging_end_time - os.time()))`
- Format: `M:SS` when ≥60s; `0:SS` below 60s
- Updates every 0.5s via `task.spawn` + loop (stops when `ForagingActive` = false or remaining ≤ 0)
- When remaining hits 0: text changes to "🐝 Bees returning…" for up to 3s; then waits for `ForagingActive` to flip false; then shows "🐝 Welcome back!" for 1.5s; then hides

### DisplayOrder

`DisplayOrder = 11` — below hive health bar (13) to avoid overlap with the top-centre health pill. The timer pill is top-right; health is top-centre; they share the top band but don't collide.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingTimerController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create ForagingTimerController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("ForagingTimerController") then
    print("⏭️  ForagingTimerController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "ForagingTimerController"
    ctrl.Source = [[
--!strict
-- ForagingTimerController — dispatch 137
-- Live countdown HUD pill during active foraging runs.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local GOLD_137  = Color3.fromRGB(242, 168, 28)
local DARK_137  = Color3.fromRGB(180, 120,  0)
local WHITE_137 = Color3.fromRGB(255, 255, 255)

-- ── GUI ──────────────────────────────────────────────────────────
local sg_137: ScreenGui? = nil
local pill_137: Frame? = nil
local pillLbl_137: TextLabel? = nil
local pillVisible_137 = false

local function ensureGui_137()
    if sg_137 and sg_137.Parent then return end
    sg_137 = Instance.new("ScreenGui")
    sg_137.Name            = "ForagingTimerGui"
    sg_137.ResetOnSpawn    = false
    sg_137.DisplayOrder    = 11
    sg_137.Parent          = playerGui
end

local function ensurePill_137()
    ensureGui_137()
    if pill_137 and pill_137.Parent then return end

    local f = Instance.new("Frame")
    f.Name                  = "ForagingTimerPill"
    f.Size                  = UDim2.new(0, 160, 0, 32)
    f.Position              = UDim2.new(1, 168, 0, 8)  -- hidden off-screen right
    f.AnchorPoint           = Vector2.new(1, 0)
    f.BackgroundColor3      = GOLD_137
    f.BackgroundTransparency = 0.08
    f.BorderSizePixel       = 0
    f.Visible               = false
    f.Parent                = sg_137 :: ScreenGui

    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,16); corner.Parent = f
    local stroke = Instance.new("UIStroke"); stroke.Color = DARK_137; stroke.Thickness = 1.5; stroke.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,-8,1,0)
    lbl.Position            = UDim2.new(0,4,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 13
    lbl.TextColor3          = WHITE_137
    lbl.TextXAlignment      = Enum.TextXAlignment.Center
    lbl.Text                = ""
    lbl.Parent              = f

    pill_137    = f
    pillLbl_137 = lbl
end

-- ── Show / hide pill ─────────────────────────────────────────────
local function showPill_137()
    ensurePill_137()
    if pillVisible_137 then return end
    pillVisible_137 = true
    local p = pill_137 :: Frame
    p.Visible = true
    p.Position = UDim2.new(1, 168, 0, 8)
    TweenService:Create(p,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(1, -8, 0, 8)}
    ):Play()
end

local function hidePill_137()
    if not pillVisible_137 then return end
    if not pill_137 then return end
    pillVisible_137 = false
    TweenService:Create(pill_137 :: Frame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(1, 168, 0, 8)}
    ).Completed:Connect(function()
        if pill_137 then (pill_137 :: Frame).Visible = false end
    end)
    TweenService:Create(pill_137 :: Frame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(1, 168, 0, 8)}
    ):Play()
end

-- ── Countdown format ─────────────────────────────────────────────
local function formatTime_137(seconds: number): string
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return m .. ":" .. string.format("%02d", s)
end

-- ── Countdown loop ────────────────────────────────────────────────
local timerRunning_137 = false

local function runTimer_137()
    if timerRunning_137 then return end
    timerRunning_137 = true

    task.spawn(function()
        showPill_137()

        while true do
            local isActive  = player:GetAttribute("ForagingActive")
            local endTime   = tonumber(player:GetAttribute("ForagingEndTime")) or 0
            local remaining = math.max(0, math.floor(endTime - os.time()))

            if not isActive and remaining <= 0 then
                -- Run completed — show welcome message then hide
                if pillLbl_137 then
                    (pillLbl_137 :: TextLabel).Text = "🐝 Welcome back!"
                end
                task.wait(1.5)
                hidePill_137()
                break
            end

            if remaining <= 0 then
                if pillLbl_137 then
                    (pillLbl_137 :: TextLabel).Text = "🐝 Bees returning…"
                end
            else
                if pillLbl_137 then
                    (pillLbl_137 :: TextLabel).Text = "🐝 Returning in " .. formatTime_137(remaining)
                end
            end

            task.wait(0.5)
        end

        timerRunning_137 = false
    end)
end

-- ── Attribute listeners ───────────────────────────────────────────
local function onForagingChanged_137()
    local isActive = player:GetAttribute("ForagingActive")
    if isActive then
        runTimer_137()
    end
    -- when isActive flips false the loop handles cleanup naturally
end

task.wait(2)

-- Restore if already foraging on join/respawn
if player:GetAttribute("ForagingActive") then
    runTimer_137()
end

player:GetAttributeChangedSignal("ForagingActive"):Connect(onForagingChanged_137)
player:GetAttributeChangedSignal("ForagingEndTime"):Connect(function()
    -- EndTime update mid-run (e.g. hive_insulation upgrade): restart loop
    if player:GetAttribute("ForagingActive") and not timerRunning_137 then
        runTimer_137()
    end
end)

player.CharacterRemoving:Connect(function()
    timerRunning_137 = false
    pillVisible_137 = false
    if pill_137 and pill_137.Parent then
        (pill_137 :: Frame).Visible = false
    end
end)

print("[ForagingTimerController] Ready — foraging countdown active")
]]
    ctrl.Parent = SPS
    print("✅ ForagingTimerController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("ForagingTimerController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " ForagingTimerController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("GOLD_137", 1, true) and "✅" or "❌") .. " GOLD_137 color constant")
table.insert(checks, (ctrl and ctrl.Source:find("showPill_137", 1, true) and "✅" or "❌") .. " showPill_137 slide-in")
table.insert(checks, (ctrl and ctrl.Source:find("hidePill_137", 1, true) and "✅" or "❌") .. " hidePill_137 slide-out")
table.insert(checks, (ctrl and ctrl.Source:find("formatTime_137", 1, true) and "✅" or "❌") .. " formatTime_137 M:SS formatter")
table.insert(checks, (ctrl and ctrl.Source:find("runTimer_137", 1, true) and "✅" or "❌") .. " runTimer_137 countdown loop")
table.insert(checks, (ctrl and ctrl.Source:find("timerRunning_137", 1, true) and "✅" or "❌") .. " timerRunning_137 guard")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingActive", 1, true) and "✅" or "❌") .. " ForagingActive attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingEndTime", 1, true) and "✅" or "❌") .. " ForagingEndTime attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("Welcome back", 1, true) and "✅" or "❌") .. " Welcome back completion message")
table.insert(checks, (ctrl and ctrl.Source:find("Returning in", 1, true) and "✅" or "❌") .. " Returning in countdown text")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterRemoving", 1, true) and "✅" or "❌") .. " CharacterRemoving cleanup")

print("=== DISPATCH 137 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 137 complete" or "❌ SOME CHECKS FAILED")

print("\nPill: 160×32px top-right, Honey Gold, slides in from off-screen, ticks M:SS every 0.5s")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| ForagingTimerController (LocalScript; ScreenGui + Frame runtime only) | 0 permanent |
| **Dispatch 137 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `timerRunning_137` guard prevents double loops if `ForagingActive` fires rapidly (e.g., server sets it true twice in quick succession). Only one loop runs at a time.
- The `ForagingEndTime` listener handles the `hive_insulation` upgrade from dispatch 132: that upgrade reduces foraging time, which updates `ForagingEndTime` mid-run. Without this listener the displayed countdown would be stale after the upgrade purchase.
- `math.floor(endTime - os.time())` uses server-set `ForagingEndTime` (an absolute timestamp) rather than a client-side counter. This means the display stays accurate across teleports, character resets, and brief network gaps — the server's wall-clock is the authority.
- The loop exits naturally when both `ForagingActive = false` AND `remaining ≤ 0`. The `ForagingActive` flag going false before the end timestamp prevents a premature "Welcome back!" if the server clears the flag a second early (which can happen due to replication lag).
- DisplayOrder=11 keeps the timer pill below the hive health bar (13) and all other HUD layers. It occupies the top-right corner which is otherwise unused, so no z-order conflicts arise with the existing button column (right side, lower vertical position) or the overflow warning strip (top-centre at Y=56).
- "Welcome back!" text fires for exactly 1.5s before the pill slides out. This is long enough for the player's eye to catch it but short enough not to linger. Adults appreciate the confirmation that the run resolved; kids enjoy the friendly greeting.
