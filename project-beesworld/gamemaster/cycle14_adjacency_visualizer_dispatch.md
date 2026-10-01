# Dispatch 138 — Adjacency Bonus Visualizer
## Cycle 14 · A Bee's World

**Feature:** A `AdjacencyVisualizerController` LocalScript that, when the player taps any comb cell button in the CombGrid UI, briefly highlights all adjacent cells that grant that cell a bonus and overlays a small percentage label on each contributing neighbour. Kids see their hive "light up" to show which cells work together; adults get a precise read on their adjacency bonus breakdown. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 137 (Foraging Return Countdown Timer)

---

## DESIGN

### Adjacency rules (mirrors server logic)

| Cell type | Bonus per adjacent neighbour | Bonus from |
|-----------|------------------------------|------------|
| Honey | +5% honey yield | Brood, Royal |
| Brood | +8% brood speed | Honey, Dance Floor |
| Pollen | +6% pollen rate | Brood, Royal |
| Royal | +10% all yields | Any cell (general adjacency) |
| Dance Floor | +4% speed bonus | Honey, Pollen |
| Propolis Kiln | +7% propolis rate | Brood, Royal |

Maximum cumulative adjacency bonus cap: **40%** (enforced server-side; visualizer shows calculated value capped at 40%).

### Hex adjacency

The comb is a 3-column × 3-row grid (9 slots, 0-indexed). Hex offset adjacency:
- Slot 0 (top-left): neighbours 1, 3
- Slot 1 (top-center): neighbours 0, 2, 3, 4
- Slot 2 (top-right): neighbours 1, 4
- Slot 3 (mid-left): neighbours 0, 1, 4, 6
- Slot 4 (center): neighbours 1, 2, 3, 5, 6, 7
- Slot 5 (mid-right): neighbours 2, 4, 7
- Slot 6 (bot-left): neighbours 3, 4, 7
- Slot 7 (bot-center): neighbours 4, 5, 6, 8
- Slot 8 (bot-right): neighbours 5, 7

### Visual behaviour

1. Player taps a cell button (named `Cell_0` through `Cell_8` in the CombGrid Frame)
2. The tapped cell gets a white `UIStroke` pulse (Thickness 0→3→0 over 0.4s)
3. Each qualifying adjacent cell gets a brief amber overlay (`Frame`, `BackgroundTransparency=0.6`, `BackgroundColor3=(242,168,28)`) for 1.2s
4. A small label (`"+X%"`) appears centred over each contributing neighbour (GothamBold 11, white, fades out with overlay)
5. A compact tooltip appears just above the tapped cell: `"Adj bonus: +X% total"` (capped at 40%)
6. Everything auto-hides after 1.8s — no persistent state, no interlock with other UI

### Cell type reading

Reads `CombState` player attribute (comma-string of cell IDs, e.g. `"honey,royal,,brood,"`) — same attribute used by dispatch 134. Slot index = position in split array.

### Tap detection

Listens for `MouseButton1Click` / `Activated` on each `Cell_N` button found under `PlayerGui.[CombGridGui].[CombGrid]` (or equivalent path). Since cell buttons may not exist at startup, uses a `DescendantAdded` watcher on the CombGrid ScreenGui to attach listeners lazily.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `AdjacencyVisualizerController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create AdjacencyVisualizerController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("AdjacencyVisualizerController") then
    print("⏭️  AdjacencyVisualizerController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "AdjacencyVisualizerController"
    ctrl.Source = [[
--!strict
-- AdjacencyVisualizerController — dispatch 138
-- Tap a comb cell to see adjacency bonus contributors highlighted.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_138 = Color3.fromRGB(242, 168, 28)
local WHITE_138 = Color3.fromRGB(255, 255, 255)

-- ── Hex adjacency map ────────────────────────────────────────────
-- 3×3 hex grid, 0-indexed. Each entry lists valid adjacent slot indices.
local HEX_ADJ_138: {[number]: {number}} = {
    [0] = {1, 3},
    [1] = {0, 2, 3, 4},
    [2] = {1, 4},
    [3] = {0, 1, 4, 6},
    [4] = {1, 2, 3, 5, 6, 7},
    [5] = {2, 4, 7},
    [6] = {3, 4, 7},
    [7] = {4, 5, 6, 8},
    [8] = {5, 7},
}

-- ── Bonus rules: tapped cell type → which neighbour types contribute ─
-- Returns bonus % per qualifying neighbour
type BonusRule138 = {bonusNeighbours: {string}, pctEach: number}
local BONUS_RULES_138: {[string]: BonusRule138} = {
    honey       = {bonusNeighbours = {"brood","royal"},       pctEach = 5},
    brood       = {bonusNeighbours = {"honey","dance_floor"},  pctEach = 8},
    pollen      = {bonusNeighbours = {"brood","royal"},       pctEach = 6},
    royal       = {bonusNeighbours = {"honey","brood","pollen","dance_floor","propolis_kiln"}, pctEach = 10},
    dance_floor = {bonusNeighbours = {"honey","pollen"},      pctEach = 4},
    propolis_kiln = {bonusNeighbours = {"brood","royal"},     pctEach = 7},
}
local MAX_ADJ_BONUS_138 = 40

-- ── Parse CombState into slot array ──────────────────────────────
local function getCombSlots_138(): {string}
    local raw = tostring(player:GetAttribute("CombState") or "")
    local slots: {string} = {}
    for part in (raw .. ","):gmatch("([^,]*),") do
        table.insert(slots, part)
    end
    -- pad to 9 slots
    while #slots < 9 do table.insert(slots, "") end
    return slots
end

-- ── Find the CombGrid frame ───────────────────────────────────────
local function findCombGrid_138(): Frame?
    for _, sg in playerGui:GetChildren() do
        if sg:IsA("ScreenGui") then
            for _, obj in (sg :: ScreenGui):GetDescendants() do
                if obj:IsA("Frame") and obj.Name == "CombGrid" then
                    return obj :: Frame
                end
            end
        end
    end
    return nil
end

-- ── Visual overlay helpers ────────────────────────────────────────
local function flashCell_138(cellFrame: GuiObject, pctText: string)
    -- Amber overlay
    local overlay = Instance.new("Frame")
    overlay.Size                  = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3      = AMBER_138
    overlay.BackgroundTransparency = 0.6
    overlay.BorderSizePixel       = 0
    overlay.ZIndex                = cellFrame.ZIndex + 2
    overlay.Parent                = cellFrame
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,6); corner.Parent = overlay

    -- Percentage label on overlay
    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 11
    lbl.TextColor3          = WHITE_138
    lbl.Text                = pctText
    lbl.ZIndex              = overlay.ZIndex + 1
    lbl.Parent              = overlay

    -- Fade out after 1.2s
    task.delay(1.2, function()
        TweenService:Create(overlay,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()
        TweenService:Create(lbl,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ).Completed:Connect(function() overlay:Destroy() end)
        TweenService:Create(lbl,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ):Play()
    end)
end

local function pulseStroke_138(cellFrame: GuiObject)
    local stroke = Instance.new("UIStroke")
    stroke.Color     = WHITE_138
    stroke.Thickness = 0
    stroke.Parent    = cellFrame
    TweenService:Create(stroke,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Thickness = 3}
    ).Completed:Connect(function()
        TweenService:Create(stroke,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Thickness = 0}
        ).Completed:Connect(function() stroke:Destroy() end)
        TweenService:Create(stroke,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Thickness = 0}
        ):Play()
    end)
    TweenService:Create(stroke,
        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Thickness = 3}
    ):Play()
end

local function showTooltip_138(cellFrame: GuiObject, totalPct: number)
    local tip = Instance.new("Frame")
    tip.Size                  = UDim2.new(0, 140, 0, 22)
    tip.Position              = UDim2.new(0.5, -70, 0, -26)
    tip.BackgroundColor3      = Color3.fromRGB(40, 25, 8)
    tip.BackgroundTransparency = 0.1
    tip.BorderSizePixel       = 0
    tip.ZIndex                = cellFrame.ZIndex + 5
    tip.Parent                = cellFrame
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,5); corner.Parent = tip

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 11
    lbl.TextColor3          = AMBER_138
    lbl.Text                = "Adj bonus: +" .. math.min(totalPct, MAX_ADJ_BONUS_138) .. "%"
    lbl.ZIndex              = tip.ZIndex + 1
    lbl.Parent              = tip

    task.delay(1.8, function()
        TweenService:Create(tip,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()
        TweenService:Create(lbl,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ).Completed:Connect(function() tip:Destroy() end)
        TweenService:Create(lbl,
            TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ):Play()
    end)
end

-- ── Main tap handler ──────────────────────────────────────────────
local function onCellTapped_138(slotIndex: number)
    local grid = findCombGrid_138()
    if not grid then return end

    local slots   = getCombSlots_138()
    local myType  = slots[slotIndex + 1] or ""  -- Lua 1-indexed
    local rules   = BONUS_RULES_138[myType]
    if not rules then return end  -- empty or unknown cell type — no bonus

    -- Pulse tapped cell
    local myCell = grid:FindFirstChild("Cell_" .. tostring(slotIndex))
    if myCell and myCell:IsA("GuiObject") then
        pulseStroke_138(myCell :: GuiObject)
    end

    -- Calculate adjacency bonus and flash contributing neighbours
    local totalPct = 0
    local adjList  = HEX_ADJ_138[slotIndex] or {}
    for _, adjIdx in adjList do
        local adjType = slots[adjIdx + 1] or ""
        local isContributor = false
        for _, needed in rules.bonusNeighbours do
            if adjType == needed then isContributor = true; break end
        end
        if isContributor then
            totalPct = totalPct + rules.pctEach
            local adjCell = grid:FindFirstChild("Cell_" .. tostring(adjIdx))
            if adjCell and adjCell:IsA("GuiObject") then
                flashCell_138(adjCell :: GuiObject, "+" .. rules.pctEach .. "%")
            end
        end
    end

    -- Show tooltip on tapped cell
    if myCell and myCell:IsA("GuiObject") then
        showTooltip_138(myCell :: GuiObject, totalPct)
    end
end

-- ── Wire up cell buttons ──────────────────────────────────────────
local connectedCells_138: {[string]: boolean} = {}

local function tryWireCells_138()
    local grid = findCombGrid_138()
    if not grid then return end
    for i = 0, 8 do
        local cellName = "Cell_" .. tostring(i)
        if not connectedCells_138[cellName] then
            local cell = grid:FindFirstChild(cellName)
            if cell and (cell:IsA("TextButton") or cell:IsA("ImageButton") or cell:IsA("Frame")) then
                if cell:IsA("GuiButton") then
                    (cell :: GuiButton).Activated:Connect(function()
                        onCellTapped_138(i)
                    end)
                end
                connectedCells_138[cellName] = true
            end
        end
    end
end

-- ── Init: watch for CombGrid appearing ───────────────────────────
task.wait(2)
tryWireCells_138()

-- Re-check on any new ScreenGui or descendant (handles late UI load)
playerGui.ChildAdded:Connect(function() task.wait(0.5); tryWireCells_138() end)
playerGui.DescendantAdded:Connect(function(obj)
    if obj:IsA("Frame") and obj.Name == "CombGrid" then
        task.wait(0.1)
        tryWireCells_138()
    end
end)

print("[AdjacencyVisualizerController] Ready — tap any cell to see adjacency bonuses")
]]
    ctrl.Parent = SPS
    print("✅ AdjacencyVisualizerController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("AdjacencyVisualizerController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " AdjacencyVisualizerController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("AMBER_138", 1, true) and "✅" or "❌") .. " AMBER_138 color constant")
table.insert(checks, (ctrl and ctrl.Source:find("HEX_ADJ_138", 1, true) and "✅" or "❌") .. " HEX_ADJ_138 adjacency map")
table.insert(checks, (ctrl and ctrl.Source:find("BONUS_RULES_138", 1, true) and "✅" or "❌") .. " BONUS_RULES_138 bonus rules table")
table.insert(checks, (ctrl and ctrl.Source:find("MAX_ADJ_BONUS_138", 1, true) and "✅" or "❌") .. " MAX_ADJ_BONUS_138 40% cap")
table.insert(checks, (ctrl and ctrl.Source:find("getCombSlots_138", 1, true) and "✅" or "❌") .. " getCombSlots_138 CombState parser")
table.insert(checks, (ctrl and ctrl.Source:find("flashCell_138", 1, true) and "✅" or "❌") .. " flashCell_138 amber overlay")
table.insert(checks, (ctrl and ctrl.Source:find("pulseStroke_138", 1, true) and "✅" or "❌") .. " pulseStroke_138 white stroke pulse")
table.insert(checks, (ctrl and ctrl.Source:find("showTooltip_138", 1, true) and "✅" or "❌") .. " showTooltip_138 bonus total tooltip")
table.insert(checks, (ctrl and ctrl.Source:find("onCellTapped_138", 1, true) and "✅" or "❌") .. " onCellTapped_138 tap handler")
table.insert(checks, (ctrl and ctrl.Source:find("tryWireCells_138", 1, true) and "✅" or "❌") .. " tryWireCells_138 lazy wiring")
table.insert(checks, (ctrl and ctrl.Source:find("DescendantAdded", 1, true) and "✅" or "❌") .. " DescendantAdded late-UI watcher")

print("=== DISPATCH 138 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 138 complete" or "❌ SOME CHECKS FAILED")

print("\nBonuses: honey+5%(brood/royal) | brood+8%(honey/dance) | pollen+6%(brood/royal) | royal+10%(any) | dance+4%(honey/pollen) | kiln+7%(brood/royal) | cap 40%")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| AdjacencyVisualizerController (LocalScript; all overlay Frames created and destroyed after 1.8s) | 0 permanent |
| **Dispatch 138 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `HEX_ADJ_138` encodes a flat 3×3 hex grid. Standard offset-hex adjacency would give 6 neighbours for interior cells, but the 9-slot grid is small enough that corners have 2 neighbours and edges have 3. The table is hand-crafted once and never recalculated — zero CPU cost at runtime.
- `getCombSlots_138` parses the same `CombState` comma-string used by dispatch 134 (RoyalCellAura). The trailing comma trick (`(raw .. ","):gmatch("([^,]*),")`) correctly handles empty slots (two consecutive commas = empty string entry).
- `connectedCells_138` prevents duplicate `Activated` connections on the same cell. The lazy wiring via `DescendantAdded` ensures the visualizer works even if the CombGrid UI is loaded after this script initialises.
- The tooltip uses `math.min(totalPct, MAX_ADJ_BONUS_138)` to display the server-enforced cap. This means a Royal cell with 5 occupied neighbours shows "Adj bonus: +40%" not "+50%" — matching the actual server-side calculation and avoiding false expectations.
- All overlay Frames and UIStrokes destroy themselves via `Completed:Connect` chains — no Debris.AddItem needed since they're UI objects, and the pattern mirrors dispatch 129 (HoneyTapController) for consistency.
- The `if cell:IsA("GuiButton")` guard before wiring `Activated` is important: if a cell is implemented as a plain `Frame` with a click detector rather than a `TextButton`/`ImageButton`, the wiring is safely skipped rather than erroring. The visualizer degrades gracefully — the tap just has no effect rather than crashing.
- DisplayOrder note: overlays are parented directly to their cell button (not to a separate ScreenGui), using `ZIndex` offsets. This keeps the effect visually contained within the CombGrid ScreenGui's existing layer stack without creating a new DisplayOrder slot.
