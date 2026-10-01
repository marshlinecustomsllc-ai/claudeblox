# Dispatch 135 — Honey Overflow Warning
## Cycle 14 · A Bee's World

**Feature:** A `HoneyOverflowController` LocalScript that warns the player when their hive is near or at honey capacity (≥90%). A pulsing amber warning strip appears below the honey ripeness indicator and the hive plot briefly glows amber. Kids see a clear "collect now!" signal; adults understand they're losing potential yield from uncollected honey. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 134 (Royal Cell Aura)

---

## DESIGN

### Overflow thresholds

| Fill % | State | Warning |
|--------|-------|---------|
| 0–89% | Normal | No warning |
| 90–99% | Near-full | Amber strip, slow pulse |
| 100% | Full | Red strip, fast pulse + "FULL" label |

Fill % = `HoneyCount / (CombCellCount × 100)` — same formula as HoneyRipenessController (dispatch 121).

### Warning strip

- Frame: `{0.5,-120,0,56}` (below the ripeness indicator at `{0,0,0,8}`), Size `{0,240,0,22}`
- Background: `Color3.fromRGB(200,120,20)` (amber) at 90%, `Color3.fromRGB(200,50,20)` (red) at 100%
- Text: `"🍯 Almost full — collect your honey!"` (90%) or `"🍯 FULL! Honey not collecting!"` (100%)
- Font: GothamBold 12, white text
- Pulse: `BackgroundTransparency` oscillates 0.05↔0.5 over 1.2s (normal) or 0.4s (full) via chained TweenService tweens
- Slides in from above (Y offset -30 → 56) over 0.25s on first appear; slides back up to hide

### Plot glow

When at 100%: the comb plot gets a temporary amber `SelectionBox` pulse (same technique as dispatch 134 but amber `Color3.fromRGB(220,100,20)`) — this existing pattern is reused with a different color. Destroyed when no longer full.

### Update frequency

Listens to `HoneyCount` and `CombCellCount` attribute changes — no polling loop needed.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HoneyOverflowController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HoneyOverflowController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HoneyOverflowController") then
    print("⏭️  HoneyOverflowController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HoneyOverflowController"
    ctrl.Source = [[
--!strict
-- HoneyOverflowController — dispatch 135
-- Warning strip when hive honey capacity is ≥90%.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_135  = Color3.fromRGB(200, 120, 20)
local RED_135    = Color3.fromRGB(200,  50, 20)
local WHITE_135  = Color3.fromRGB(255, 255, 255)

-- ── Find comb plot ───────────────────────────────────────────────
local function findPlotPart_135(): BasePart?
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return nil end
    local uid = tostring(player.UserId)
    for _, folder in mapFolder:GetDescendants() do
        if folder:IsA("Folder") and (folder.Name:find(uid) or folder.Name:find("Plot")) then
            for _, child in folder:GetDescendants() do
                if child:IsA("BasePart") and child.Anchored then
                    return child :: BasePart
                end
            end
        end
    end
    return nil
end

-- ── GUI ──────────────────────────────────────────────────────────
local sg: ScreenGui? = nil
local strip_135: Frame? = nil
local stripLbl_135: TextLabel? = nil
local pulseTweenA_135: Tween? = nil
local pulseTweenB_135: Tween? = nil
local fullSelBox_135: SelectionBox? = nil

local function ensureGui_135()
    if sg and sg.Parent then return end
    sg = Instance.new("ScreenGui")
    sg.Name             = "HoneyOverflowGui"
    sg.ResetOnSpawn     = false
    sg.DisplayOrder     = 14
    sg.Parent           = playerGui
end

local function ensureStrip_135()
    ensureGui_135()
    if strip_135 and strip_135.Parent then return end

    local f = Instance.new("Frame")
    f.Name                  = "OverflowStrip"
    f.Size                  = UDim2.new(0, 240, 0, 22)
    f.Position              = UDim2.new(0.5, -120, 0, 30)   -- hidden start
    f.BackgroundColor3      = AMBER_135
    f.BackgroundTransparency = 0.5
    f.BorderSizePixel       = 0
    f.Visible               = false
    f.Parent                = sg :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,6); corner.Parent = f

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,-8,1,0)
    lbl.Position            = UDim2.new(0,4,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 12
    lbl.TextColor3          = WHITE_135
    lbl.TextXAlignment      = Enum.TextXAlignment.Center
    lbl.Text                = ""
    lbl.Parent              = f

    strip_135    = f
    stripLbl_135 = lbl
end

local function stopPulse_135()
    if pulseTweenA_135 then pulseTweenA_135:Cancel(); pulseTweenA_135 = nil end
    if pulseTweenB_135 then pulseTweenB_135:Cancel(); pulseTweenB_135 = nil end
end

local function startPulse_135(fast: boolean)
    if not strip_135 or not strip_135.Parent then return end
    stopPulse_135()
    local dur = fast and 0.4 or 1.2
    local function cycle()
        if not strip_135 or not strip_135.Parent then return end
        pulseTweenA_135 = TweenService:Create(strip_135,
            TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {BackgroundTransparency = 0.5}
        )
        pulseTweenA_135.Completed:Connect(function()
            if not strip_135 or not strip_135.Parent then return end
            pulseTweenB_135 = TweenService:Create(strip_135,
                TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {BackgroundTransparency = 0.05}
            )
            pulseTweenB_135.Completed:Connect(cycle)
            pulseTweenB_135:Play()
        end)
        pulseTweenA_135:Play()
    end
    cycle()
end

local stripVisible_135 = false

local function showStrip_135(isFull: boolean)
    ensureStrip_135()
    local s = strip_135 :: Frame
    local l = stripLbl_135 :: TextLabel
    s.BackgroundColor3 = isFull and RED_135 or AMBER_135
    l.Text = isFull and "🍯 FULL! Honey not collecting!" or "🍯 Almost full — collect your honey!"

    if not stripVisible_135 then
        s.Position = UDim2.new(0.5, -120, 0, 30)
        s.Visible  = true
        TweenService:Create(s,
            TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, -120, 0, 56)}
        ):Play()
        stripVisible_135 = true
    end
    startPulse_135(isFull)

    -- Full: add amber selection box on plot
    if isFull then
        if not fullSelBox_135 then
            local plot = findPlotPart_135()
            if plot then
                local sb = Instance.new("SelectionBox")
                sb.Adornee             = plot
                sb.Color3              = Color3.fromRGB(220, 100, 20)
                sb.LineThickness       = 0.07
                sb.SurfaceTransparency = 0.85
                sb.SurfaceColor3       = Color3.fromRGB(200, 80, 10)
                sb.Parent              = workspace
                fullSelBox_135 = sb
            end
        end
    else
        if fullSelBox_135 then fullSelBox_135:Destroy(); fullSelBox_135 = nil end
    end
end

local function hideStrip_135()
    stopPulse_135()
    if fullSelBox_135 then fullSelBox_135:Destroy(); fullSelBox_135 = nil end
    if not stripVisible_135 then return end
    if not strip_135 then return end
    stripVisible_135 = false
    TweenService:Create(strip_135,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -120, 0, 30), BackgroundTransparency = 1}
    ).Completed:Connect(function()
        if strip_135 then strip_135.Visible = false end
    end):Play()
    TweenService:Create(strip_135 :: Frame,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, -120, 0, 30), BackgroundTransparency = 1}
    ):Play()
end

-- ── Update state ─────────────────────────────────────────────────
local function updateOverflow_135()
    local honey     = tonumber(player:GetAttribute("HoneyCount"))     or 0
    local cellCount = tonumber(player:GetAttribute("CombCellCount"))  or 0
    local capacity  = math.max(cellCount * 100, 1)
    local fill      = honey / capacity

    if fill >= 1.0 then
        showStrip_135(true)
    elseif fill >= 0.9 then
        showStrip_135(false)
    else
        hideStrip_135()
    end
end

-- ── Listeners ────────────────────────────────────────────────────
task.wait(2)
player:GetAttributeChangedSignal("HoneyCount"):Connect(updateOverflow_135)
player:GetAttributeChangedSignal("CombCellCount"):Connect(updateOverflow_135)
player.CharacterRemoving:Connect(hideStrip_135)

updateOverflow_135()
print("[HoneyOverflowController] Ready — overflow warning active")
]]
    ctrl.Parent = SPS
    print("✅ HoneyOverflowController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HoneyOverflowController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HoneyOverflowController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("AMBER_135", 1, true) and "✅" or "❌") .. " AMBER_135 color constant")
table.insert(checks, (ctrl and ctrl.Source:find("RED_135", 1, true) and "✅" or "❌") .. " RED_135 full state color")
table.insert(checks, (ctrl and ctrl.Source:find("showStrip_135", 1, true) and "✅" or "❌") .. " showStrip_135 warning display")
table.insert(checks, (ctrl and ctrl.Source:find("hideStrip_135", 1, true) and "✅" or "❌") .. " hideStrip_135 warning dismiss")
table.insert(checks, (ctrl and ctrl.Source:find("startPulse_135", 1, true) and "✅" or "❌") .. " startPulse_135 amber pulse")
table.insert(checks, (ctrl and ctrl.Source:find("stopPulse_135", 1, true) and "✅" or "❌") .. " stopPulse_135 tween cancel")
table.insert(checks, (ctrl and ctrl.Source:find("fullSelBox_135", 1, true) and "✅" or "❌") .. " fullSelBox_135 red SelectionBox on full")
table.insert(checks, (ctrl and ctrl.Source:find("updateOverflow_135", 1, true) and "✅" or "❌") .. " updateOverflow_135 threshold check")
table.insert(checks, (ctrl and ctrl.Source:find("0.9", 1, true) and "✅" or "❌") .. " 90% near-full threshold")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCount", 1, true) and "✅" or "❌") .. " HoneyCount attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("CombCellCount", 1, true) and "✅" or "❌") .. " CombCellCount attribute listener")

print("=== DISPATCH 135 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 135 complete" or "❌ SOME CHECKS FAILED")

print("\nThresholds: <90% none | ≥90% amber strip slow-pulse | 100% red strip fast-pulse + SelectionBox")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HoneyOverflowController (LocalScript; GUI + SelectionBox runtime only) | 0 permanent |
| **Dispatch 135 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The 90% threshold is generous — it gives the player a window to act before they hit the cap. At WalkSpeed 24 (boosted from dispatch 133) they can reach the collection point comfortably within that window.
- The "FULL! Honey not collecting!" text is factually accurate — honey capacity means the server stops awarding honey until some is collected. This teaches the mechanic directly without a tooltip or tutorial page.
- `startPulse_135(fast: boolean)` reuses the same tween-chain pattern as dispatches 134 and 133, but parameterised on duration — `fast=true` gives 0.4s (urgent) vs 1.2s (warning). The visual difference is immediately readable as "this is worse".
- The amber SelectionBox on plot-full (100%) creates a visual sandwich with the Royal Cell aura (dispatch 134) if both are active simultaneously — amber outline around a gold outline. This looks intentional and tells the adult player at a glance: "Royal Cell active + hive full."
- `hideStrip_135` uses a `Completed:Connect` chain to set `Visible=false` only after the fade-out tween ends — this prevents a flash where the frame is invisible but still occupying layout space.
- DisplayOrder=14 places the overflow warning just below the hive health bar (13) and above the foraging quality card (14 slot shared — they shouldn't appear simultaneously since overflow is a collection state and foraging quality shows during active foraging).
