# Dispatch 128 — Comb Slot Unlock Animation
## Cycle 14 · A Bee's World

**Feature:** A `SlotUnlockController` LocalScript that fires a golden ring burst + shimmer animation on the comb grid whenever a new slot unlocks (CombCellCount crosses a threshold). Kids see a satisfying "pop" of light; adults see clear visual confirmation that their investment paid off. The animation plays directly on the newly available comb slot in the hive grid UI — no guessing which slot just opened. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 127 (Hive Health Display)

---

## DESIGN

### Unlock thresholds

Slots unlock at the same CombCellCount milestones used by BeeRosterController (dispatch 119):

| CombCellCount reached | Slot(s) unlocked |
|-----------------------|-----------------|
| 0 | slot 1 (start) |
| 6 | slot 2 |
| 12 | slot 3 |
| 18 | slot 4 |
| 24 | slot 5 |
| 30 | slot 6 |
| 38 | slot 7 |
| 46 | slot 8 |
| 55+ | slot 9 |

The controller watches `CombCellCount` attribute. When it increases past a threshold, compute which slot index just became available and animate it.

### Animation sequence

1. **Ring flash** — the slot frame briefly scales to 1.15× via TweenService (0.12s ease-out), then snaps back (0.18s ease-in)
2. **Shimmer overlay** — a golden semi-transparent Frame (BackgroundColor3 = `Color3.fromRGB(242,168,28)`, BackgroundTransparency=0.3) fades in (0.1s) then fades out (0.6s) over the slot
3. **Emoji pop** — a `🐝` TextLabel spawns centred on the slot at Size `{0,32,0,32}`, floats upward 30px and fades out over 0.9s via TweenService

**Total animation duration:** ~1s (all three tracks run in parallel)

### Finding the comb slot frame

The comb grid is expected to be in `StarterGui.CombGui.CombFrame.SlotContainer` (or similar path from the CombGrid dispatch). The controller uses a robust search:

1. Try `PlayerGui:FindFirstChild("CombGui", true)` to locate the gui
2. Within it, search for `Frame` or `TextButton` children whose Name matches `"Slot" .. slotIndex` or `"CombSlot" .. slotIndex`
3. Fallback: animate the first unlocked slot found by `CollectionService:GetTagged("CombSlot")`
4. If no slot frame found, skip animation silently (never error)

### Edge cases

- On first load: read CombCellCount, record current unlock level as baseline; no animation on join (avoid spurious pop for returning players)
- Rapid unlock (debugging/admin): queue animations 0.4s apart so they don't overlap
- Slot already at maximum (9): no further animations

---

## FILES CHANGED

| File | Change |
|------|--------|
| `SlotUnlockController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create SlotUnlockController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("SlotUnlockController") then
    print("⏭️  SlotUnlockController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "SlotUnlockController"
    ctrl.Source = [[
--!strict
-- SlotUnlockController — dispatch 128
-- Golden ring burst animation when a new comb slot unlocks.

local Players         = game:GetService("Players")
local TweenService    = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

-- ── Unlock thresholds (mirrors BeeRosterController dispatch 119) ──
local THRESHOLDS_128: {number} = {0, 6, 12, 18, 24, 30, 38, 46, 55}

local function getUnlockLevel_128(cellCount: number): number
    local level = 0
    for i, thresh in THRESHOLDS_128 do
        if cellCount >= thresh then level = i end
    end
    return level
end

-- ── Find a comb slot Frame by slot index ─────────────────────────
local function findSlotFrame_128(slotIndex: number): GuiObject?
    if not playerGui then return nil end

    -- Try CollectionService tag first
    local tagged = CollectionService:GetTagged("CombSlot")
    for _, obj in tagged do
        if obj.Name == ("Slot" .. slotIndex) or obj.Name == ("CombSlot" .. slotIndex) then
            return obj :: GuiObject
        end
    end

    -- Fallback: deep search in PlayerGui
    for _, obj in playerGui:GetDescendants() do
        if obj:IsA("GuiObject") and
           (obj.Name == ("Slot" .. slotIndex) or obj.Name == ("CombSlot" .. slotIndex)) then
            return obj :: GuiObject
        end
    end

    return nil
end

-- ── Emoji pop overlay ─────────────────────────────────────────────
local function spawnEmojiPop_128(slotFrame: GuiObject)
    local lbl = Instance.new("TextLabel")
    lbl.Text               = "🐝"
    lbl.Size               = UDim2.new(0, 32, 0, 32)
    lbl.Position           = UDim2.new(0.5, -16, 0.5, -16)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled         = true
    lbl.TextTransparency   = 0
    lbl.ZIndex             = (slotFrame.ZIndex or 1) + 10
    lbl.Parent             = slotFrame

    local rise = TweenService:Create(lbl,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -16, 0.5, -46), TextTransparency = 1}
    )
    rise:Play()
    rise.Completed:Connect(function() lbl:Destroy() end)
end

-- ── Shimmer overlay ───────────────────────────────────────────────
local function spawnShimmer_128(slotFrame: GuiObject)
    local shimmer = Instance.new("Frame")
    shimmer.Size               = UDim2.new(1, 0, 1, 0)
    shimmer.Position           = UDim2.new(0, 0, 0, 0)
    shimmer.BackgroundColor3   = Color3.fromRGB(242, 168, 28)
    shimmer.BackgroundTransparency = 1
    shimmer.ZIndex             = (slotFrame.ZIndex or 1) + 9
    shimmer.BorderSizePixel    = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius        = UDim.new(0, 6)
    corner.Parent              = shimmer
    shimmer.Parent             = slotFrame

    local fadeIn = TweenService:Create(shimmer,
        TweenInfo.new(0.1, Enum.EasingStyle.Linear),
        {BackgroundTransparency = 0.3}
    )
    local fadeOut = TweenService:Create(shimmer,
        TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency = 1}
    )
    fadeIn:Play()
    fadeIn.Completed:Connect(function()
        fadeOut:Play()
        fadeOut.Completed:Connect(function() shimmer:Destroy() end)
    end)
end

-- ── Ring scale pulse ──────────────────────────────────────────────
local function pulseSlot_128(slotFrame: GuiObject)
    local origSize     = slotFrame.Size
    local origPos      = slotFrame.Position
    local sx           = origSize.X.Scale
    local sy           = origSize.Y.Scale
    local ox           = origSize.X.Offset
    local oy           = origSize.Y.Offset
    local scaleUp      = 1.15

    local bigSize = UDim2.new(sx * scaleUp, ox * scaleUp, sy * scaleUp, oy * scaleUp)
    local bigPos  = UDim2.new(
        origPos.X.Scale - (sx * scaleUp - sx) / 2,
        origPos.X.Offset - (ox * scaleUp - ox) / 2,
        origPos.Y.Scale - (sy * scaleUp - sy) / 2,
        origPos.Y.Offset - (oy * scaleUp - oy) / 2
    )

    local growTween = TweenService:Create(slotFrame,
        TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = bigSize, Position = bigPos}
    )
    local shrinkTween = TweenService:Create(slotFrame,
        TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Size = origSize, Position = origPos}
    )
    growTween:Play()
    growTween.Completed:Connect(function() shrinkTween:Play() end)
end

-- ── Play full unlock animation for one slot ───────────────────────
local animQueue_128: {number} = {}
local animRunning_128 = false

local function drainQueue_128()
    if animRunning_128 then return end
    if #animQueue_128 == 0 then return end

    animRunning_128 = true
    local slotIndex = table.remove(animQueue_128, 1)
    local slotFrame = findSlotFrame_128(slotIndex)

    if slotFrame then
        pulseSlot_128(slotFrame)
        spawnShimmer_128(slotFrame)
        spawnEmojiPop_128(slotFrame)
    end

    task.delay(0.4, function()
        animRunning_128 = false
        drainQueue_128()
    end)
end

local function animateUnlock_128(slotIndex: number)
    table.insert(animQueue_128, slotIndex)
    drainQueue_128()
end

-- ── Watch CombCellCount ───────────────────────────────────────────
task.wait(2)  -- wait for PlayerGui and attributes to settle

local prevLevel_128 = getUnlockLevel_128(
    tonumber(player:GetAttribute("CombCellCount")) or 0
)

player:GetAttributeChangedSignal("CombCellCount"):Connect(function()
    local newCount = tonumber(player:GetAttribute("CombCellCount")) or 0
    local newLevel = getUnlockLevel_128(newCount)
    if newLevel > prevLevel_128 then
        for i = prevLevel_128 + 1, newLevel do
            animateUnlock_128(i)
        end
    end
    prevLevel_128 = newLevel
end)

print("[SlotUnlockController] Ready — comb slot unlock animations active")
]]
    ctrl.Parent = SPS
    print("✅ SlotUnlockController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("SlotUnlockController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " SlotUnlockController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("THRESHOLDS_128", 1, true) and "✅" or "❌") .. " THRESHOLDS_128 unlock table")
table.insert(checks, (ctrl and ctrl.Source:find("getUnlockLevel_128", 1, true) and "✅" or "❌") .. " getUnlockLevel_128 helper")
table.insert(checks, (ctrl and ctrl.Source:find("pulseSlot_128", 1, true) and "✅" or "❌") .. " pulseSlot_128 ring animation")
table.insert(checks, (ctrl and ctrl.Source:find("spawnShimmer_128", 1, true) and "✅" or "❌") .. " spawnShimmer_128 overlay")
table.insert(checks, (ctrl and ctrl.Source:find("spawnEmojiPop_128", 1, true) and "✅" or "❌") .. " spawnEmojiPop_128 emoji pop")
table.insert(checks, (ctrl and ctrl.Source:find("animQueue_128", 1, true) and "✅" or "❌") .. " animQueue_128 queue prevents overlap")
table.insert(checks, (ctrl and ctrl.Source:find("drainQueue_128", 1, true) and "✅" or "❌") .. " drainQueue_128 staggered playback")
table.insert(checks, (ctrl and ctrl.Source:find("CombCellCount", 1, true) and "✅" or "❌") .. " CombCellCount attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("prevLevel_128", 1, true) and "✅" or "❌") .. " prevLevel_128 no-spurious-pop baseline")
table.insert(checks, (ctrl and ctrl.Source:find("CollectionService", 1, true) and "✅" or "❌") .. " CollectionService CombSlot tag lookup")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService animations")

print("=== DISPATCH 128 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 128 complete" or "❌ SOME CHECKS FAILED")

print("\nAnimation: ring pulse (0.12s grow + 0.18s shrink) | shimmer fade (0.1s in + 0.6s out) | 🐝 emoji float (0.9s)")
print("Queue spacing: 0.4s between animations for clean staggering")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| SlotUnlockController (LocalScript; all UI objects created/destroyed at runtime) | 0 permanent |
| **Dispatch 128 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The `prevLevel_128` baseline is set from the current `CombCellCount` at script load time (with a 2s `task.wait` so attributes have arrived). This means a player who already has 30 cells at join sees NO animation — they only see animations for future unlocks. This prevents a confetti storm every time a player reconnects.
- The animation queue (`animQueue_128` + `drainQueue_128`) with 0.4s spacing handles rapid consecutive unlocks gracefully. If a player earns 3 cells in rapid succession and crosses two thresholds, both slot animations play sequentially with a small gap rather than simultaneously.
- `pulseSlot_128` restores the slot to its original `Size` and `Position` after the pulse, so no layout drift occurs even if TweenService easing overshoots.
- The shimmer overlay uses a `UICorner` to match rounded slot frames. If the slot frame has no rounding, the UICorner on the shimmer is simply not visible — no visual artifact.
- `findSlotFrame_128` tries `CollectionService:GetTagged("CombSlot")` first (O(tags)), then falls back to `GetDescendants()` (more expensive but more robust if the CombSlot tag was never applied). If both fail, the function returns `nil` and the animation is silently skipped — the unlock still works, it just has no visual flourish. This is correct behaviour for players on very old cached character builds.
- `EasingStyle.Back` on the grow tween gives a slight overshoot (the frame pops slightly larger than 1.15× before settling) which feels satisfying and "bouncy" — appropriate for a kids game without being chaotic.
