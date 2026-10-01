# Dispatch 134 — Royal Cell Aura
## Cycle 14 · A Bee's World

**Feature:** A `RoyalCellAuraController` LocalScript that renders a subtle golden shimmer aura around the player's comb plot whenever at least one Royal Cell is active. A slow-pulsing `SelectionBox` + a soft `PointLight` at the plot give the hive a regal glow. Kids see their hive look special and important; adults get a clear visual cue that their Royal Cell adjacency bonuses are active. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 133 (Bee Speed Boost)

---

## DESIGN

### Trigger

- `CombState` attribute contains `"royal"` substring → Royal Cell is active → show aura
- Aura removed when no `"royal"` in CombState

### Visual elements

| Element | Details |
|---------|---------|
| `SelectionBox` | Parented to workspace, `Adornee` = player's comb plot BasePart (same search as HoneyRipenessController). `Color3 = Color3.fromRGB(255, 200, 30)` (bright gold), `LineThickness = 0.06`, `SurfaceTransparency = 0.85`, `SurfaceColor3 = Color3.fromRGB(242, 168, 28)` |
| `PointLight` | Parented to the comb plot BasePart. `Color = Color3.fromRGB(255, 210, 80)`, `Range = 16`, `Brightness = 0.6`, `Shadows = false` |
| Pulse tween | SelectionBox `LineThickness` oscillates 0.04↔0.08 over 2s with `TweenService` (Sine easing, ping-pong via two tweens chained) |

### Plot search

Same robust search pattern as `HoneyRipenessController` (dispatch 121):
1. `workspace:FindFirstChild("Map")` → search descendants for a `Folder` whose name contains `player.UserId` or `"Plot"`
2. First `Anchored BasePart` found in that folder = the anchor
3. Fallback: skip aura silently if plot not found (never error)

### Cleanup

On `CharacterRemoving` or when aura is disabled: `SelectionBox:Destroy()`, `PointLight:Destroy()`, stop pulse tweens. Re-created on next `CharacterAdded` + Royal Cell present.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `RoyalCellAuraController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create RoyalCellAuraController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("RoyalCellAuraController") then
    print("⏭️  RoyalCellAuraController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "RoyalCellAuraController"
    ctrl.Source = [[
--!strict
-- RoyalCellAuraController — dispatch 134
-- Golden aura around comb plot when Royal Cell is active.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── Find comb plot anchor ────────────────────────────────────────
local function findPlotPart_134(): BasePart?
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

-- ── Aura state ───────────────────────────────────────────────────
local selBox_134: SelectionBox? = nil
local plotLight_134: PointLight? = nil
local pulseTweenA_134: Tween? = nil
local pulseTweenB_134: Tween? = nil
local auraActive_134 = false

local function stopPulse_134()
    if pulseTweenA_134 then pulseTweenA_134:Cancel(); pulseTweenA_134 = nil end
    if pulseTweenB_134 then pulseTweenB_134:Cancel(); pulseTweenB_134 = nil end
end

local function startPulse_134()
    if not selBox_134 or not selBox_134.Parent then return end
    stopPulse_134()

    local function makeCycle()
        if not selBox_134 or not selBox_134.Parent then return end
        pulseTweenA_134 = TweenService:Create(selBox_134,
            TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
            {LineThickness = 0.04}
        )
        pulseTweenA_134.Completed:Connect(function()
            if not selBox_134 or not selBox_134.Parent then return end
            pulseTweenB_134 = TweenService:Create(selBox_134,
                TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {LineThickness = 0.08}
            )
            pulseTweenB_134.Completed:Connect(makeCycle)
            pulseTweenB_134:Play()
        end)
        pulseTweenA_134:Play()
    end
    makeCycle()
end

local function removeAura_134()
    stopPulse_134()
    if selBox_134 then selBox_134:Destroy(); selBox_134 = nil end
    if plotLight_134 then plotLight_134:Destroy(); plotLight_134 = nil end
    auraActive_134 = false
end

local function showAura_134()
    if auraActive_134 then return end
    local plot = findPlotPart_134()
    if not plot then return end

    -- SelectionBox
    local sb = Instance.new("SelectionBox")
    sb.Adornee           = plot
    sb.Color3            = Color3.fromRGB(255, 200, 30)
    sb.LineThickness     = 0.06
    sb.SurfaceTransparency = 0.85
    sb.SurfaceColor3     = Color3.fromRGB(242, 168, 28)
    sb.Parent            = workspace
    selBox_134 = sb

    -- PointLight on the plot
    local pl = Instance.new("PointLight")
    pl.Color      = Color3.fromRGB(255, 210, 80)
    pl.Range      = 16
    pl.Brightness = 0.6
    pl.Shadows    = false
    pl.Parent     = plot
    plotLight_134 = pl

    auraActive_134 = true
    startPulse_134()
end

-- ── Update aura based on CombState ───────────────────────────────
local function updateAura_134()
    local combState = tostring(player:GetAttribute("CombState") or "")
    local hasRoyal  = combState:find("royal") ~= nil
    if hasRoyal then
        showAura_134()
    else
        removeAura_134()
    end
end

-- ── Lifecycle ────────────────────────────────────────────────────
player.CharacterRemoving:Connect(removeAura_134)
player.CharacterAdded:Connect(function()
    task.wait(1)
    updateAura_134()
end)

player:GetAttributeChangedSignal("CombState"):Connect(updateAura_134)

task.wait(2)
updateAura_134()

print("[RoyalCellAuraController] Ready — Royal Cell aura active")
]]
    ctrl.Parent = SPS
    print("✅ RoyalCellAuraController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("RoyalCellAuraController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " RoyalCellAuraController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("findPlotPart_134", 1, true) and "✅" or "❌") .. " findPlotPart_134 plot locator")
table.insert(checks, (ctrl and ctrl.Source:find("showAura_134", 1, true) and "✅" or "❌") .. " showAura_134 aura creation")
table.insert(checks, (ctrl and ctrl.Source:find("removeAura_134", 1, true) and "✅" or "❌") .. " removeAura_134 aura cleanup")
table.insert(checks, (ctrl and ctrl.Source:find("startPulse_134", 1, true) and "✅" or "❌") .. " startPulse_134 pulse tween loop")
table.insert(checks, (ctrl and ctrl.Source:find("stopPulse_134", 1, true) and "✅" or "❌") .. " stopPulse_134 tween cancel")
table.insert(checks, (ctrl and ctrl.Source:find("SelectionBox", 1, true) and "✅" or "❌") .. " SelectionBox aura box")
table.insert(checks, (ctrl and ctrl.Source:find("PointLight", 1, true) and "✅" or "❌") .. " PointLight on plot")
table.insert(checks, (ctrl and ctrl.Source:find("SurfaceTransparency", 1, true) and "✅" or "❌") .. " SurfaceTransparency=0.85")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterRemoving", 1, true) and "✅" or "❌") .. " CharacterRemoving cleanup")
table.insert(checks, (ctrl and ctrl.Source:find("CombState", 1, true) and "✅" or "❌") .. " CombState attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("royal", 1, true) and "✅" or "❌") .. " royal substring check")

print("=== DISPATCH 134 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 134 complete" or "❌ SOME CHECKS FAILED")

print("\nAura: SelectionBox (gold, LineThickness 0.04↔0.08 pulse 2s) + PointLight (Range 16, Brightness 0.6)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| RoyalCellAuraController (LocalScript; SelectionBox + PointLight destroyed with aura) | 0 permanent |
| **Dispatch 134 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `SelectionBox` is a Roblox built-in highlight object that draws a wireframe outline around any `BasePart` adornee — it uses zero parts and renders natively with minimal performance cost. The `SurfaceTransparency=0.85` fills the box with a very faint golden tint without obscuring the comb geometry underneath.
- The pulse loop (`makeCycle` recursive pattern) avoids `RunService.Heartbeat` polling for the animation — two chained Tweens produce a smooth sine oscillation at essentially zero CPU cost.
- `stopPulse_134` cancels both tweens before creating new ones. Without this, calling `showAura_134` twice (e.g. on `CharacterAdded` while the aura is already active) would spawn a second pulse loop and the two loops would fight, causing LineThickness to flicker.
- `auraActive_134` guard in `showAura_134` prevents double-creating SelectionBox when `CombState` fires multiple times in rapid succession (e.g. equipping multiple cells quickly).
- The `PointLight` is parented directly to the comb plot BasePart so it moves with the plot if the plot ever repositions. It is destroyed in `removeAura_134` along with the SelectionBox — no light leaks when the Royal Cell is removed.
