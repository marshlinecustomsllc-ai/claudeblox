# Dispatch 129 — Honey Collection Tap Feedback
## Cycle 14 · A Bee's World

**Feature:** A `HoneyTapController` LocalScript that fires a satisfying visual and haptic-style feedback whenever the player taps/clicks to collect honey. A golden `+N 🍯` number floats up from the tap point and fades; the honey jar icon briefly bounces; a soft golden ripple ring expands from the tap. Kids see immediate cause-and-effect; adults see a tactile reward loop that makes collecting feel meaningful. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 128 (Comb Slot Unlock Animation)

---

## DESIGN

### Trigger

Listens to the `HoneyCollect` RemoteEvent fired by the server when a collection succeeds. The event fires with one argument: `amount: number` (honey gained this tick).

If `HoneyCollect` RemoteEvent does not exist (service not yet deployed), fall back to watching `HoneyCount` attribute changes: when HoneyCount increases, the delta is treated as the collection amount.

### Visual effects (all GUI, zero parts)

| Effect | Description |
|--------|-------------|
| Float label | `+N 🍯` TextLabel, GothamBold 16pt, honey gold `Color3.fromRGB(242,168,28)`, spawns near the collection point, rises 40px and fades out over 0.75s |
| Honey jar bounce | The honey jar icon in the HUD (if found by name `"HoneyIcon"` or `"HoneyJarLabel"`) scales to 1.2× for 0.08s then snaps back over 0.15s |
| Ripple ring | A circular `Frame` with `UICorner(1,0)` and `UIStroke`, spawns at 24px, expands to 60px diameter, fades out over 0.4s |

### Anchor point

- If a `HoneyJar` or `HoneyDisplay` Frame is found in PlayerGui, spawn effects relative to it (Position near centre-bottom of that frame)
- Fallback: spawn at screen position `{0.5, -30, 0.75, 0}` (bottom-centre area)
- All effect Frames are parented to a dedicated `HoneyTapFX` Frame inside the nearest ScreenGui (created once on demand)

### Flood protection

Maximum 8 float labels visible simultaneously. If more than 8 are alive, oldest is immediately destroyed before creating the new one.

### Amount formatting

| Amount | Display |
|--------|---------|
| < 10 | `+5 🍯` |
| 10–999 | `+42 🍯` |
| 1,000–999,999 | `+1.4K 🍯` |
| ≥ 1,000,000 | `+2.1M 🍯` |

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HoneyTapController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HoneyTapController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HoneyTapController") then
    print("⏭️  HoneyTapController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HoneyTapController"
    ctrl.Source = [[
--!strict
-- HoneyTapController — dispatch 129
-- Satisfying tap feedback when honey is collected.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RS            = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

-- ── Format amount ────────────────────────────────────────────────
local function fmtAmt_129(n: number): string
    if n >= 1000000 then return "+" .. string.format("%.1fM", n / 1000000) .. " 🍯"
    elseif n >= 1000 then return "+" .. string.format("%.1fK", n / 1000) .. " 🍯"
    else return "+" .. tostring(math.floor(n)) .. " 🍯" end
end

-- ── Find or create FX container ──────────────────────────────────
local fxContainer_129: Frame? = nil

local function getFxContainer_129(): Frame
    if fxContainer_129 and fxContainer_129.Parent then
        return fxContainer_129
    end
    -- Find best ScreenGui to parent into
    local target: ScreenGui? = nil
    for _, gui in playerGui:GetChildren() do
        if gui:IsA("ScreenGui") and gui.Name ~= "HoneyTapFXGui" then
            target = gui :: ScreenGui
            break
        end
    end
    if not target then
        target = Instance.new("ScreenGui")
        target.Name          = "HoneyTapFXGui"
        target.ResetOnSpawn  = false
        target.DisplayOrder  = 60
        target.Parent        = playerGui
    end
    local container = Instance.new("Frame")
    container.Name               = "HoneyTapFX"
    container.Size               = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent             = target
    fxContainer_129 = container
    return container
end

-- ── Find anchor position ─────────────────────────────────────────
local function getAnchorPos_129(): UDim2
    for _, obj in playerGui:GetDescendants() do
        if obj:IsA("GuiObject") and
           (obj.Name == "HoneyJar" or obj.Name == "HoneyDisplay" or
            obj.Name == "HoneyIcon" or obj.Name == "HoneyJarLabel") then
            return UDim2.new(obj.AbsolutePosition.X / workspace.CurrentCamera.ViewportSize.X,
                             0,
                             obj.AbsolutePosition.Y / workspace.CurrentCamera.ViewportSize.Y,
                             0)
        end
    end
    return UDim2.new(0.5, -30, 0.75, 0)
end

-- ── Float label ──────────────────────────────────────────────────
local activeLabels_129: {TextLabel} = {}
local MAX_LABELS_129 = 8

local function spawnFloatLabel_129(text: string)
    -- Flood protection
    if #activeLabels_129 >= MAX_LABELS_129 then
        local oldest = table.remove(activeLabels_129, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end

    local container = getFxContainer_129()
    local anchor    = getAnchorPos_129()

    local lbl = Instance.new("TextLabel")
    lbl.Text                 = text
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextSize             = 16
    lbl.TextColor3           = Color3.fromRGB(242, 168, 28)
    lbl.TextStrokeColor3     = Color3.fromRGB(80, 50, 20)
    lbl.TextStrokeTransparency = 0.4
    lbl.BackgroundTransparency = 1
    lbl.Size                 = UDim2.new(0, 80, 0, 24)
    lbl.Position             = UDim2.new(anchor.X.Scale, anchor.X.Offset - 40, anchor.Y.Scale, anchor.Y.Offset - 10)
    lbl.TextTransparency     = 0
    lbl.ZIndex               = 60
    lbl.Parent               = container

    table.insert(activeLabels_129, lbl)

    local rise = TweenService:Create(lbl,
        TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Position         = UDim2.new(anchor.X.Scale, anchor.X.Offset - 40, anchor.Y.Scale, anchor.Y.Offset - 50),
            TextTransparency = 1,
        }
    )
    rise:Play()
    rise.Completed:Connect(function()
        local idx = table.find(activeLabels_129, lbl)
        if idx then table.remove(activeLabels_129, idx) end
        lbl:Destroy()
    end)
end

-- ── Ripple ring ──────────────────────────────────────────────────
local function spawnRipple_129()
    local container = getFxContainer_129()
    local anchor    = getAnchorPos_129()

    local ring = Instance.new("Frame")
    ring.Size                = UDim2.new(0, 24, 0, 24)
    ring.Position            = UDim2.new(anchor.X.Scale, anchor.X.Offset - 12, anchor.Y.Scale, anchor.Y.Offset - 12)
    ring.BackgroundTransparency = 1
    ring.ZIndex              = 59
    local corner = Instance.new("UICorner")
    corner.CornerRadius      = UDim.new(1, 0)
    corner.Parent            = ring
    local stroke = Instance.new("UIStroke")
    stroke.Color             = Color3.fromRGB(242, 168, 28)
    stroke.Thickness         = 2
    stroke.Transparency      = 0
    stroke.Parent            = ring
    ring.Parent              = container

    local expand = TweenService:Create(ring,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {
            Size     = UDim2.new(0, 60, 0, 60),
            Position = UDim2.new(anchor.X.Scale, anchor.X.Offset - 30, anchor.Y.Scale, anchor.Y.Offset - 30),
        }
    )
    local fade = TweenService:Create(stroke,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Transparency = 1}
    )
    expand:Play()
    fade:Play()
    expand.Completed:Connect(function() ring:Destroy() end)
end

-- ── Honey jar icon bounce ─────────────────────────────────────────
local function bounceHoneyIcon_129()
    local icon: GuiObject? = nil
    for _, obj in playerGui:GetDescendants() do
        if obj:IsA("GuiObject") and
           (obj.Name == "HoneyJar" or obj.Name == "HoneyIcon" or obj.Name == "HoneyJarLabel") then
            icon = obj :: GuiObject
            break
        end
    end
    if not icon then return end

    local origSize = icon.Size
    local scaleX = origSize.X.Scale * 1.2
    local scaleY = origSize.Y.Scale * 1.2
    local offX   = origSize.X.Offset * 1.2
    local offY   = origSize.Y.Offset * 1.2
    local bigSize = UDim2.new(scaleX, offX, scaleY, offY)

    local grow = TweenService:Create(icon,
        TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = bigSize}
    )
    local shrink = TweenService:Create(icon,
        TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        {Size = origSize}
    )
    grow:Play()
    grow.Completed:Connect(function() shrink:Play() end)
end

-- ── Fire all effects ──────────────────────────────────────────────
local function onCollect_129(amount: number)
    if amount <= 0 then return end
    spawnFloatLabel_129(fmtAmt_129(amount))
    spawnRipple_129()
    bounceHoneyIcon_129()
end

-- ── Connect to HoneyCollect RemoteEvent (primary) ────────────────
task.wait(2)

local honeyCollect_129 = RS:FindFirstChild("HoneyCollect") :: RemoteEvent?
if honeyCollect_129 then
    honeyCollect_129.OnClientEvent:Connect(function(amount: number)
        onCollect_129(tonumber(amount) or 0)
    end)
    print("[HoneyTapController] Listening to HoneyCollect RemoteEvent")
else
    -- Fallback: watch HoneyCount attribute delta
    local prevHoney_129 = tonumber(player:GetAttribute("HoneyCount")) or 0
    player:GetAttributeChangedSignal("HoneyCount"):Connect(function()
        local now = tonumber(player:GetAttribute("HoneyCount")) or 0
        local delta = now - prevHoney_129
        if delta > 0 then onCollect_129(delta) end
        prevHoney_129 = now
    end)
    print("[HoneyTapController] HoneyCollect not found — using HoneyCount attribute fallback")
end

print("[HoneyTapController] Ready — tap feedback active")
]]
    ctrl.Parent = SPS
    print("✅ HoneyTapController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HoneyTapController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HoneyTapController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("fmtAmt_129", 1, true) and "✅" or "❌") .. " fmtAmt_129 amount formatter")
table.insert(checks, (ctrl and ctrl.Source:find("getFxContainer_129", 1, true) and "✅" or "❌") .. " getFxContainer_129 lazy container")
table.insert(checks, (ctrl and ctrl.Source:find("spawnFloatLabel_129", 1, true) and "✅" or "❌") .. " spawnFloatLabel_129 float text")
table.insert(checks, (ctrl and ctrl.Source:find("spawnRipple_129", 1, true) and "✅" or "❌") .. " spawnRipple_129 ring expand")
table.insert(checks, (ctrl and ctrl.Source:find("bounceHoneyIcon_129", 1, true) and "✅" or "❌") .. " bounceHoneyIcon_129 jar bounce")
table.insert(checks, (ctrl and ctrl.Source:find("MAX_LABELS_129", 1, true) and "✅" or "❌") .. " MAX_LABELS_129 flood protection")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCollect", 1, true) and "✅" or "❌") .. " HoneyCollect RemoteEvent listener")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCount", 1, true) and "✅" or "❌") .. " HoneyCount attribute fallback")
table.insert(checks, (ctrl and ctrl.Source:find("UICorner", 1, true) and "✅" or "❌") .. " UICorner ripple ring")
table.insert(checks, (ctrl and ctrl.Source:find("UIStroke", 1, true) and "✅" or "❌") .. " UIStroke ripple ring outline")
table.insert(checks, (ctrl and ctrl.Source:find("GothamBold", 1, true) and "✅" or "❌") .. " GothamBold house font")

print("=== DISPATCH 129 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 129 complete" or "❌ SOME CHECKS FAILED")

print("\nEffects: float label (+N 🍯, 0.75s rise) | ripple ring (24→60px, 0.4s) | jar bounce (×1.2, 0.08s+0.15s)")
print("Flood limit: max 8 simultaneous float labels | RemoteEvent primary, attribute fallback")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HoneyTapController (LocalScript; all UI objects created/destroyed at runtime) | 0 permanent |
| **Dispatch 129 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The `HoneyCollect` RemoteEvent primary path fires immediately when the server grants honey (exact amount known). The `HoneyCount` attribute fallback fires slightly later (attribute replication lag) and shows the delta — both work correctly, but the RemoteEvent gives a snappier feel.
- `getFxContainer_129` is lazy: it creates the `HoneyTapFXGui` ScreenGui and `HoneyTapFX` Frame only on the first collection, not at script startup. This avoids polluting the DOM for players who never collect manually.
- The ripple ring uses `UIStroke` (not a visible background) so it's a pure outline ring — this reads clearly at any zoom level and doesn't obscure the honey count display beneath it.
- `bounceHoneyIcon_129` uses a name search (`HoneyJar`, `HoneyIcon`, `HoneyJarLabel`) rather than a hardcoded path, so it works even if the CombGui or HoneyGui was renamed in a later dispatch. If no matching element is found, it silently skips — the float label and ripple still fire.
- The flood protection cap (8 labels) prevents visual noise during rapid automated collection (if a server script fires HoneyCollect multiple times per second). Eight labels floating simultaneously is already busy; older ones are destroyed to keep the screen legible.
- `EasingStyle.Back` on the jar icon shrink gives a subtle overshoot (settles slightly smaller before snapping to original size) — a micro-bounciness that feels alive without being distracting.
- TextStroke on the float label (`Color3.fromRGB(80,50,20)` at 0.4 transparency) ensures the gold text is readable against both light (honey comb) and dark (night background) hive environments.
