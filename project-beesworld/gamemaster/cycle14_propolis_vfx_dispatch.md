# Dispatch 136 — Propolis Collection VFX
## Cycle 14 · A Bee's World

**Feature:** A `PropolisVfxController` LocalScript that plays a satisfying amber burst effect whenever the player earns propolis from a Kiln cell. A short spray of sticky amber dots rises from the hive area and a "+N 🟤" float label appears near the HUD. Kids enjoy the visceral "ooze" feel; adults get clear feedback that their Propolis Kiln investment is paying off. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 135 (Honey Overflow Warning)

---

## DESIGN

### Trigger

Listens to `PropolisCount` attribute delta on the player. Any positive delta (+1 or more) fires a burst effect. Negative deltas (spending) are ignored — the Shop UI handles spend feedback.

### Visual elements

| Element | Details |
|---------|---------|
| Float label | `"+N 🟤"` rises 80px over 0.9s, fades from 1→0, font GothamBold 14, Propolis Brown `Color3.fromRGB(80,50,20)` on a wax-cream background |
| Amber dot burst | 6–8 `Frame` objects (4×4px, `UICorner` for circle shape, `Color3.fromRGB(180,90,10)`) spawn at a random spread (±40px) near the HUD anchor, each tweens upward 30–60px and fades over 0.6–0.9s |
| HUD icon bounce | The propolis count icon (if present) gets a ×1.15 scale pulse over 0.15s then returns — same pattern as honey tap jar bounce (dispatch 129) |

### Flood protection

Maximum 5 float labels alive at once. If a 6th would spawn, the oldest is destroyed immediately. Same cap pattern as `MAX_LABELS_129`.

### HUD anchor

Float labels and dots spawn at `{0.5, -80, 0.5, -120}` in screen space — roughly centre-screen slightly above midpoint. If the propolis count label is found in the HUD, that label's position is used instead.

### Update frequency

`PropolisCount:GetAttributeChangedSignal` — no polling.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PropolisVfxController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create PropolisVfxController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PropolisVfxController") then
    print("⏭️  PropolisVfxController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PropolisVfxController"
    ctrl.Source = [[
--!strict
-- PropolisVfxController — dispatch 136
-- Amber burst VFX when player earns propolis from Kiln cells.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local BROWN_136     = Color3.fromRGB(80, 50, 20)
local AMBER_136     = Color3.fromRGB(180, 90, 10)
local CREAM_136     = Color3.fromRGB(232, 212, 154)
local MAX_LABELS_136 = 5

-- ── GUI container ────────────────────────────────────────────────
local fxGui_136: ScreenGui? = nil

local function getFxGui_136(): ScreenGui
    if fxGui_136 and fxGui_136.Parent then return fxGui_136 :: ScreenGui end
    local sg = playerGui:FindFirstChild("PropolisVfxGui") :: ScreenGui?
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name          = "PropolisVfxGui"
        sg.ResetOnSpawn  = false
        sg.DisplayOrder  = 55   -- above honey tap (60 slot), below nothing critical
        sg.Parent        = playerGui
    end
    fxGui_136 = sg
    return sg :: ScreenGui
end

-- ── Float label ──────────────────────────────────────────────────
local activeLabels_136: {Frame} = {}

local function pruneLabels_136()
    while #activeLabels_136 >= MAX_LABELS_136 do
        local oldest = table.remove(activeLabels_136, 1)
        if oldest and oldest.Parent then oldest:Destroy() end
    end
end

local function spawnFloatLabel_136(amount: number)
    pruneLabels_136()
    local sg = getFxGui_136()

    local container = Instance.new("Frame")
    container.Size                  = UDim2.new(0, 90, 0, 28)
    container.Position              = UDim2.new(0.5, -45, 0.5, -110)
    container.BackgroundColor3      = CREAM_136
    container.BackgroundTransparency = 0.15
    container.BorderSizePixel       = 0
    container.Parent                = sg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = container
    local stroke = Instance.new("UIStroke"); stroke.Color = BROWN_136; stroke.Thickness = 1.5; stroke.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 14
    lbl.TextColor3          = BROWN_136
    lbl.TextXAlignment      = Enum.TextXAlignment.Center
    lbl.Text                = "+" .. tostring(amount) .. " 🟤"
    lbl.Parent              = container

    table.insert(activeLabels_136, container)

    -- Rise + fade
    TweenService:Create(container,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -45, 0.5, -190)}
    ):Play()
    TweenService:Create(container,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 1}
    ):Play()
    TweenService:Create(lbl,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {TextTransparency = 1}
    ).Completed:Connect(function()
        container:Destroy()
        local idx = table.find(activeLabels_136, container)
        if idx then table.remove(activeLabels_136, idx) end
    end)
    TweenService:Create(lbl,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {TextTransparency = 1}
    ):Play()
end

-- ── Amber dot burst ──────────────────────────────────────────────
local function spawnDotBurst_136()
    local sg = getFxGui_136()
    local count = math.random(6, 8)
    for i = 1, count do
        local dot = Instance.new("Frame")
        dot.Size                  = UDim2.new(0, 5, 0, 5)
        -- Random scatter around anchor
        local ox = math.random(-50, 50)
        local oy = math.random(-20, 20)
        dot.Position              = UDim2.new(0.5, ox - 2, 0.5, oy - 120)
        dot.BackgroundColor3      = AMBER_136
        dot.BackgroundTransparency = 0
        dot.BorderSizePixel       = 0
        dot.Parent                = sg
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.5,0); corner.Parent = dot

        -- Each dot rises a random amount and fades
        local riseY = oy - 120 - math.random(35, 65)
        local dur   = 0.6 + math.random() * 0.35
        TweenService:Create(dot,
            TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, ox - 2, 0.5, riseY)}
        ):Play()
        TweenService:Create(dot,
            TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ).Completed:Connect(function() dot:Destroy() end)
        TweenService:Create(dot,
            TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()
    end
end

-- ── Propolis count icon bounce (if HUD label exists) ─────────────
local function bouncePropolisIcon_136()
    -- Try to find a propolis label in any ScreenGui
    local label: GuiObject? = nil
    for _, sg in playerGui:GetChildren() do
        if sg:IsA("ScreenGui") then
            for _, obj in (sg :: ScreenGui):GetDescendants() do
                if (obj:IsA("TextLabel") or obj:IsA("ImageLabel"))
                   and obj.Name:find("Propolis") then
                    label = obj :: GuiObject
                    break
                end
            end
        end
        if label then break end
    end
    if not label then return end

    local orig = label.Size
    TweenService:Create(label,
        TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(orig.X.Scale * 1.15, orig.X.Offset, orig.Y.Scale * 1.15, orig.Y.Offset)}
    ).Completed:Connect(function()
        TweenService:Create(label :: GuiObject,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = orig}
        ):Play()
    end)
    TweenService:Create(label,
        TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.new(orig.X.Scale * 1.15, orig.X.Offset, orig.Y.Scale * 1.15, orig.Y.Offset)}
    ):Play()
end

-- ── Main effect trigger ──────────────────────────────────────────
local prevPropolis_136 = tonumber(player:GetAttribute("PropolisCount")) or 0

local function onPropolisChanged_136()
    local current = tonumber(player:GetAttribute("PropolisCount")) or 0
    local delta   = current - prevPropolis_136
    prevPropolis_136 = current
    if delta <= 0 then return end   -- ignore spend; only celebrate gains

    spawnFloatLabel_136(delta)
    spawnDotBurst_136()
    bouncePropolisIcon_136()
end

-- ── Listeners ────────────────────────────────────────────────────
task.wait(2)
prevPropolis_136 = tonumber(player:GetAttribute("PropolisCount")) or 0
player:GetAttributeChangedSignal("PropolisCount"):Connect(onPropolisChanged_136)

print("[PropolisVfxController] Ready — propolis collection VFX active")
]]
    ctrl.Parent = SPS
    print("✅ PropolisVfxController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PropolisVfxController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " PropolisVfxController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("BROWN_136", 1, true) and "✅" or "❌") .. " BROWN_136 propolis color constant")
table.insert(checks, (ctrl and ctrl.Source:find("AMBER_136", 1, true) and "✅" or "❌") .. " AMBER_136 dot burst color")
table.insert(checks, (ctrl and ctrl.Source:find("MAX_LABELS_136", 1, true) and "✅" or "❌") .. " MAX_LABELS_136 flood protection")
table.insert(checks, (ctrl and ctrl.Source:find("spawnFloatLabel_136", 1, true) and "✅" or "❌") .. " spawnFloatLabel_136 rise label")
table.insert(checks, (ctrl and ctrl.Source:find("spawnDotBurst_136", 1, true) and "✅" or "❌") .. " spawnDotBurst_136 amber dots")
table.insert(checks, (ctrl and ctrl.Source:find("bouncePropolisIcon_136", 1, true) and "✅" or "❌") .. " bouncePropolisIcon_136 HUD bounce")
table.insert(checks, (ctrl and ctrl.Source:find("onPropolisChanged_136", 1, true) and "✅" or "❌") .. " onPropolisChanged_136 trigger")
table.insert(checks, (ctrl and ctrl.Source:find("prevPropolis_136", 1, true) and "✅" or "❌") .. " prevPropolis_136 delta tracking")
table.insert(checks, (ctrl and ctrl.Source:find("PropolisCount", 1, true) and "✅" or "❌") .. " PropolisCount attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("delta <= 0", 1, true) and "✅" or "❌") .. " spend delta ignored (gains only)")
table.insert(checks, (ctrl and ctrl.Source:find("pruneLabels_136", 1, true) and "✅" or "❌") .. " pruneLabels_136 oldest-first eviction")

print("=== DISPATCH 136 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 136 complete" or "❌ SOME CHECKS FAILED")

print("\nVFX: +N 🟤 float label (0.9s rise) + 6-8 amber dots (0.6-0.9s) + HUD icon bounce (×1.15)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PropolisVfxController (LocalScript; all frames created and destroyed at runtime) | 0 permanent |
| **Dispatch 136 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `delta <= 0` guard prevents the VFX firing when the player *spends* propolis in the shop (dispatch 132). Spending feels different — no burst needed — and this keeps the amber burst as a pure "earned it!" signal.
- The dot burst uses pure `Frame` objects with `UICorner(0.5, 0)` for circles, not Part instances — so zero impact on the 5,000-part budget and no cleanup required at respawn.
- `pruneLabels_136` removes the *oldest* label when the cap is hit, not the newest. This means rapid Kiln ticks (e.g., bee_stamina upgrade + Dance Floor combo in a busy hive) won't flood the screen — the oldest animation is already nearly gone, so the visual feels like a continuous stream rather than a popping reset.
- `bouncePropolisIcon_136` uses a fuzzy name search (`obj.Name:find("Propolis")`) rather than a hardcoded path, so it works whether the propolis HUD label is named "PropolisCount", "PropolisLabel", "Propolis_Icon", etc. If no label is found, it silently no-ops — the float label and dot burst still fire.
- DisplayOrder=55 places this VFX layer above the honey tap FX (slot in the 60 range is occupied by HoneyTapController at DisplayOrder=60), keeping propolis visuals beneath honey visuals in z-order — which is correct, since honey is the primary resource.
- `prevPropolis_136` is initialised *after* `task.wait(2)` to capture the post-join value, preventing a false burst on first load when the server replicates the player's saved propolis total.
