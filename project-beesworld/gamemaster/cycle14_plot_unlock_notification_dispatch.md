# Dispatch 98 — Plot Unlock Notification
## Cycle 14 · A Bee's World

**Feature:** When a player successfully claims a new plot (slots 1-8), there is no visual confirmation beyond the plot colour change. New players especially miss this feedback. This dispatch adds a claim notification: a brief toast-style popup ("🏡 Plot 3 unlocked! 🍯 −200 honey") that appears for 2.5 seconds at the bottom-centre of the screen, then fades out. The notification text includes the plot number and the cost paid (using the correct emoji for honey or propolis).
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 97 (Seasonal Bonus Event System)

---

## DESIGN

### PlotSync payload

`PlotSync` (dispatch 20-era) currently fires `{plotId, status, owner}` to the client on ownership change. The `PlotController` shows the claimed state visually. This dispatch patches `PlotController` to also show a toast when `status == "claimed"` and `owner == player.Name`.

For the cost display, `PlotController` already has the Config table from the architecture (or fetches plot costs from a `ConfigSync` event). If the controller doesn't have cost data client-side, we derive it from the plot slot number: slots 1-6 cost honey (previously configured per-slot); slots 7-8 cost propolis (dispatch 86).

### Simplified cost display

Rather than fetching exact costs (which requires Config access), use a hardcoded display table on the client matching the Config values:

```lua
local PLOT_COSTS = {
    [1] = {honey=0},       -- first plot is free
    [2] = {honey=50},
    [3] = {honey=100},
    [4] = {honey=200},
    [5] = {honey=400},
    [6] = {honey=800},
    [7] = {propolis=150},
    [8] = {propolis=300},
}
```

### Toast UI

A `Frame` added to the existing `HiveGui` (or a new `ToastGui` if HiveGui doesn't exist) using Honey Gold border and animated via TweenService:

1. Frame slides up from bottom (Position Y from 0.95 → 0.88)
2. Holds for 2 seconds
3. Fades out (BackgroundTransparency to 1, TextTransparency to 1)
4. Destroyed after fade

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PlotController` | Add PLOT_COSTS table + toast function + bind to PlotSync |

---

## STEP A — PlotController: inject plot claim toast

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local pc = SPS and SPS:FindFirstChild("PlotController")
if not pc then
    -- Check StarterGui descendants
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "PlotController" then
            pc = obj; break
        end
    end
end
assert(pc, "PlotController not found")

if pc.Source:find("PlotToast", 1, true) then
    print("⏭️  PlotController already has PlotToast — skip")
else
    local clone = pc:Clone()
    clone.Name = "PlotController_WORKING"

    clone.Source = clone.Source .. [[

-- ── Plot Claim Toast (dispatch 98) ──────────────────────────────
local TweenService_98 = game:GetService("TweenService")
local Players_98      = game:GetService("Players")

local PLOT_COSTS_98 = {
    [1] = nil,               -- free / already owned at start
    [2] = {honey    = 50},
    [3] = {honey    = 100},
    [4] = {honey    = 200},
    [5] = {honey    = 400},
    [6] = {honey    = 800},
    [7] = {propolis = 150},
    [8] = {propolis = 300},
}

local function showPlotToast(plotId: number)
    local pg = Players_98.LocalPlayer:WaitForChild("PlayerGui")
    -- Build toast GUI
    local gui = Instance.new("ScreenGui")
    gui.Name            = "PlotToast"
    gui.ResetOnSpawn    = false
    gui.DisplayOrder    = 20
    gui.Parent          = pg

    local frame = Instance.new("Frame")
    frame.Name                  = "ToastFrame"
    frame.Size                  = UDim2.new(0, 260, 0, 44)
    frame.Position              = UDim2.new(0.5, -130, 0.93, 0)
    frame.BackgroundColor3      = Color3.fromRGB(30, 20, 10)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel       = 0
    frame.Parent                = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(242, 168, 28)
    stroke.Thickness = 1.5
    stroke.Parent    = frame

    -- Build text
    local cost = PLOT_COSTS_98[plotId]
    local costText = ""
    if cost then
        if cost.honey then
            costText = "  🍯 −" .. cost.honey .. " honey"
        elseif cost.propolis then
            costText = "  🔮 −" .. cost.propolis .. " propolis"
        end
    end

    local label = Instance.new("TextLabel")
    label.Name                  = "ToastLabel"
    label.Size                  = UDim2.new(1, -12, 1, 0)
    label.Position              = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.Font                  = Enum.Font.GothamBold
    label.TextSize              = 14
    label.TextColor3            = Color3.fromRGB(232, 212, 154)
    label.Text                  = "🏡 Plot " .. plotId .. " unlocked!" .. costText
    label.TextXAlignment        = Enum.TextXAlignment.Center
    label.Parent                = frame

    -- Slide in
    TweenService_98:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -130, 0.88, 0)
    }):Play()

    -- Hold then fade out
    task.delay(2.3, function()
        TweenService_98:Create(frame, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService_98:Create(label, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        task.delay(0.45, function() gui:Destroy() end)
    end)
end

-- Bind to PlotSync
task.spawn(function()
    local RS98 = game:GetService("ReplicatedStorage")
    local plotSync = RS98:WaitForChild("PlotSync", 10) :: RemoteEvent?
    if not plotSync then
        warn("[PlotToast] PlotSync not found after 10s")
        return
    end
    local localName = Players_98.LocalPlayer.Name
    plotSync.OnClientEvent:Connect(function(data: {plotId: number?, status: string?, owner: string?})
        if data.status == "claimed" and data.owner == localName and data.plotId then
            showPlotToast(data.plotId)
        end
    end)
    print("[PlotToast] Plot claim toast active")
end)
]]

    local parent = pc.Parent
    pc.Name = "PlotController_OLD_NX"
    pc.Parent = nil
    clone.Name = "PlotController"
    clone.Parent = parent
    print("✅ PlotController: plot claim toast injected")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local pc = SPS and SPS:FindFirstChild("PlotController")
if not pc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "PlotController" then
            pc = obj; break
        end
    end
end

local checks = {}
table.insert(checks, (pc and "✅" or "❌") .. " PlotController exists")
table.insert(checks, (pc and pc.Source:find("PlotToast", 1, true) and "✅" or "❌") .. " PlotController: PlotToast GUI builder")
table.insert(checks, (pc and pc.Source:find("PLOT_COSTS_98", 1, true) and "✅" or "❌") .. " PlotController: PLOT_COSTS_98 table")
table.insert(checks, (pc and pc.Source:find("showPlotToast", 1, true) and "✅" or "❌") .. " PlotController: showPlotToast function")
table.insert(checks, (pc and pc.Source:find("status.*claimed", 1, true) and "✅" or "❌") .. " PlotController: fires on claimed status")
table.insert(checks, (pc and pc.Source:find("PlotSync", 1, true) and "✅" or "❌") .. " PlotController: bound to PlotSync")
table.insert(checks, (pc and pc.Source:find("propolis", 1, true) and "✅" or "❌") .. " PlotController: shows propolis cost for slots 7-8")

print("=== DISPATCH 98 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 98 complete" or "❌ SOME CHECKS FAILED")

print("\nPlot toast messages:")
local costs = {
    {2,"🍯 −50 honey"},{3,"🍯 −100 honey"},{4,"🍯 −200 honey"},
    {5,"🍯 −400 honey"},{6,"🍯 −800 honey"},
    {7,"🔮 −150 propolis"},{8,"🔮 −300 propolis"}
}
for _, r in costs do
    print("  Plot " .. r[1] .. ": 🏡 Plot " .. r[1] .. " unlocked!  " .. r[2])
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI injection only (no BaseParts) | 0 new parts |
| **Dispatch 98 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The PLOT_COSTS_98 client-side table is a duplicate of Config.PLOT_UNLOCK_COSTS (dispatch 86). This is an accepted duplication — the toast is cosmetic and a mismatch (e.g., if Config is updated) only affects the displayed deduction number, not the actual deduction. A future polish dispatch could source costs from a `ConfigSync` payload to eliminate the duplication.
- `plotId = nil` guard in the PlotSync handler (`data.plotId and showPlotToast(data.plotId)`) prevents errors if the event fires with an unexpected payload shape.
- The `DisplayOrder = 20` places the toast above most HUD elements but below the prestige overlay and achievement popup (assumed 25-30). The toast auto-destroys after 2.75 seconds total (0.3s slide + 2s hold + 0.45s fade) — no memory leak.
- `_98` suffix on all injected local variables (`TweenService_98`, `Players_98`, `PLOT_COSTS_98`) prevents name collisions with any variables already at the top of `PlotController`. Since the injection appends to the end of the existing source, these suffixes are defensive rather than necessary if the existing code doesn't define those names — but defensive is safer in an append context.
- Plot 1 has `nil` cost (it's the starter plot, always free) — the nil check `if cost then` cleanly handles this case with no cost text appended.
