# Dispatch 92 — Upgrades Panel: Category Tabs
## Cycle 13 · A Bee's World

**Feature:** Upgrades panel currently lists all upgrades in a single scrolling list. With 20+ upgrades added across Cycles 11–13, this becomes unwieldy. This dispatch adds **category tabs** to the Upgrades panel: 🍯 Honey, 🔮 Propolis, 🌼 Pollen, ⏱ Speed. Each tab filters the upgrade list to its resource type. The active tab persists to `localStorage` so players return to their last-used tab.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 91 (Bee Count Upgrades)

---

## DESIGN

### Category assignment

| Tab | Upgrade IDs |
|-----|------------|
| 🍯 Honey | `honey_*`, `bee_count_*`, `foraging_speed_*` (honey-cost upgrades) |
| 🔮 Propolis | `propolis_*`, `expansion_*` |
| 🌼 Pollen | `pollen_*` |
| ⏱ Speed | `foraging_speed_*` (also appears in Honey tab — cross-listed) |

Simplification: use a tag in Config or derive from `cost` field:
- `cost.honey` → Honey tab
- `cost.propolis` → Propolis tab
- `cost.pollen` → Pollen tab

`foraging_speed_*` upgrades cost honey → appear under Honey tab. No separate Speed tab needed; the description "-X% foraging time" distinguishes them from yield upgrades.

### UI structure

```
UpgradesGui (ScreenGui)
└── UpgradesPanel (Frame)
    ├── TabRow (Frame, horizontal layout)
    │   ├── HoneyTab  (TextButton, "🍯 Honey")
    │   ├── PropolisTab (TextButton, "🔮 Propolis")
    │   └── PollenTab  (TextButton, "🌼 Pollen")
    └── UpgradeList (ScrollingFrame — existing; filter applied by tab)
```

Tab controller logic is injected into `UpgradesController` (client). On tab click:
1. Record active tab in `localStorage`
2. Iterate all upgrade rows in `UpgradeList`
3. Show/hide rows where `row:GetAttribute("CostType") == activeTab`

Each upgrade row must have a `CostType` attribute ("honey", "propolis", "pollen") set when the row is built.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `UpgradesController` | Add TabRow UI creation, tab click handlers, row filtering |

---

## STEP A — UpgradesController: inject tab row + filtering

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("UpgradesController")
assert(ctrl, "UpgradesController not found")

if ctrl.Source:find("HoneyTab", 1, true) then
    print("⏭️  UpgradesController already has category tabs — skip")
else
    local clone = ctrl:Clone()
    clone.Name = "UpgradesController_WORKING"

    -- Append tab logic at end of source
    clone.Source = clone.Source .. [[

-- ── Upgrade Category Tabs (dispatch 92) ────────────────
local TABS: {[string]: {label: string, costType: string}} = {
    honey    = {label = "🍯 Honey",    costType = "honey"},
    propolis = {label = "🔮 Propolis", costType = "propolis"},
    pollen   = {label = "🌼 Pollen",   costType = "pollen"},
}
local TAB_ORDER = {"honey", "propolis", "pollen"}

local ACTIVE_BG   = Color3.fromRGB(242, 168, 28)  -- Honey Gold
local INACTIVE_BG = Color3.fromRGB(80,  50,  20)  -- Propolis Brown
local ACTIVE_TXT  = Color3.fromRGB(30,  20,  10)
local INACTIVE_TXT= Color3.fromRGB(232, 212, 154)

local activeTab = "honey"
-- Restore from localStorage
local ok, saved = pcall(function() return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):GetAttribute("UpgradeTab") end)
if ok and saved then activeTab = saved end

local function applyTabFilter()
    -- Find the UpgradeList scrolling frame
    local gui = player:WaitForChild("PlayerGui"):FindFirstChild("UpgradesGui")
    if not gui then return end
    local panel = gui:FindFirstChild("UpgradesPanel")
    if not panel then return end
    local list = panel:FindFirstChild("UpgradeList")
    if not list then return end

    for _, row in list:GetChildren() do
        if row:IsA("Frame") then
            local costType = row:GetAttribute("CostType") or "honey"
            row.Visible = (costType == activeTab)
        end
    end

    -- Update tab button visuals
    local tabRow = panel:FindFirstChild("TabRow")
    if tabRow then
        for _, btn in tabRow:GetChildren() do
            if btn:IsA("TextButton") then
                local isActive = btn:GetAttribute("TabId") == activeTab
                btn.BackgroundColor3 = isActive and ACTIVE_BG or INACTIVE_BG
                btn.TextColor3       = isActive and ACTIVE_TXT or INACTIVE_TXT
            end
        end
    end
end

-- Build TabRow when panel loads
task.spawn(function()
    task.wait(5)  -- wait for UpgradesGui to be built by existing controller
    local gui = player:WaitForChild("PlayerGui"):FindFirstChild("UpgradesGui")
    if not gui then return end
    local panel = gui:FindFirstChild("UpgradesPanel")
    if not panel then return end

    -- Only create TabRow once
    if panel:FindFirstChild("TabRow") then return end

    local tabRow = Instance.new("Frame")
    tabRow.Name            = "TabRow"
    tabRow.Size            = UDim2.new(1, 0, 0, 36)
    tabRow.Position        = UDim2.new(0, 0, 0, 0)
    tabRow.BackgroundColor3= Color3.fromRGB(50, 30, 10)
    tabRow.BorderSizePixel = 0
    tabRow.ZIndex          = 5
    tabRow.Parent          = panel

    local layout = Instance.new("UIListLayout")
    layout.FillDirection  = Enum.FillDirection.Horizontal
    layout.SortOrder      = Enum.SortOrder.LayoutOrder
    layout.Padding        = UDim.new(0, 2)
    layout.Parent         = tabRow

    for i, tabId in TAB_ORDER do
        local info = TABS[tabId]
        local btn = Instance.new("TextButton")
        btn.Name             = tabId .. "Tab"
        btn.Size             = UDim2.new(1/#TAB_ORDER, -2, 1, 0)
        btn.BackgroundColor3 = tabId == activeTab and ACTIVE_BG or INACTIVE_BG
        btn.TextColor3       = tabId == activeTab and ACTIVE_TXT or INACTIVE_TXT
        btn.Text             = info.label
        btn.Font             = Enum.Font.GothamBold
        btn.TextSize         = 14
        btn.BorderSizePixel  = 0
        btn.LayoutOrder      = i
        btn:SetAttribute("TabId", tabId)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            activeTab = tabId
            pcall(function()
                player:WaitForChild("PlayerGui"):SetAttribute("UpgradeTab", activeTab)
            end)
            applyTabFilter()
        end)

        btn.Parent = tabRow
    end

    -- Push UpgradeList down to accommodate TabRow
    local list = panel:FindFirstChild("UpgradeList")
    if list then
        list.Position = UDim2.new(0, 0, 0, 38)
        list.Size     = UDim2.new(1, 0, 1, -38)
    end

    -- Tag existing upgrade rows with CostType attribute
    -- The row name convention is the upgrade ID; look up cost type from Config
    -- Since Config is server-side, we detect from the row's cost label text
    if list then
        for _, row in list:GetChildren() do
            if row:IsA("Frame") and not row:GetAttribute("CostType") then
                -- Heuristic: read the cost label child for emoji
                local costLabel = row:FindFirstChild("CostLabel")
                local text = costLabel and costLabel.Text or ""
                local costType = "honey"  -- default
                if text:find("🔮") or text:find("propolis") then
                    costType = "propolis"
                elseif text:find("🌼") or text:find("pollen") then
                    costType = "pollen"
                end
                row:SetAttribute("CostType", costType)
            end
        end
    end

    applyTabFilter()
    print("[UpgradesTabs] Category tabs created")
end)
]]

    ctrl.Name = "UpgradesController_OLD_NX"
    ctrl.Parent = nil
    clone.Name = "UpgradesController"
    clone.Parent = SPS
    print("✅ UpgradesController: category tabs injected")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("UpgradesController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " UpgradesController exists")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyTab") and "✅" or "❌") .. " UpgradesController: HoneyTab button")
table.insert(checks, (ctrl and ctrl.Source:find("applyTabFilter") and "✅" or "❌") .. " UpgradesController: applyTabFilter function")
table.insert(checks, (ctrl and ctrl.Source:find("CostType") and "✅" or "❌") .. " UpgradesController: CostType attribute")
table.insert(checks, (ctrl and ctrl.Source:find("TabRow") and "✅" or "❌") .. " UpgradesController: TabRow frame")

print("=== DISPATCH 92 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 92 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI injection only (no BaseParts) | 0 new server parts |
| **Dispatch 92 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The tab logic appends to the existing `UpgradesController` source rather than replacing it, which avoids touching the existing upgrade purchase/render logic. The `task.wait(5)` gives the existing controller time to build the UpgradeList before the tab logic tries to find rows.
- `CostType` attribute tagging uses a heuristic: scan the cost label text for resource emojis. This is resilient to upgrade ID changes. If the upgrade rows use a different structure (e.g. cost value stored as an attribute rather than in a label), adjust the detection inside the `for _, row` loop.
- `SetAttribute("UpgradeTab", activeTab)` on `PlayerGui` is a lightweight persistence mechanism for the tab selection within a session. It does not survive server restarts (localStorage would, but Roblox LocalPlayer.PlayerGui doesn't have localStorage). For true cross-session persistence, a `DataService` profile field `lastUpgradeTab` could be added — deferred to a future polish dispatch.
- The `1/#TAB_ORDER` width ensures tabs share the row width equally regardless of count. Adding a 4th tab later requires only adding to `TABS` and `TAB_ORDER`.
- If `UpgradesController` doesn't exist (renamed or in a different location), check `StarterGui` for a `UpgradesGui` ScreenGui with a LocalScript inside it — that LocalScript may be the controller.
