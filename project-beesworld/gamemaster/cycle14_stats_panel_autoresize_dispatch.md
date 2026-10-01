# Dispatch 108 — HiveStats Panel Auto-Resize
## Cycle 14 · A Bee's World

**Feature:** The HiveStats panel (built in dispatch 10/12 era) uses a fixed-height Frame. As upgrades accumulate (dispatch 104–105 added Swift Wings I/II/III + Queen Bee, totalling 4 upgrade tiers), the upgrade list overflows the panel boundary — rows are clipped or invisible. This dispatch converts the upgrades sub-section of HiveStats to a `ScrollingFrame` with auto-adjusted `CanvasSize`, so any number of upgrade rows are accessible via scroll. No row layout or source data changes — this is pure container surgery.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 107 (Upgrade Tree Visualization)

---

## DESIGN

### Target structure

Before this dispatch the UpgradesController (dispatch 10/12) places each upgrade row into a `Frame` named `UpgradeList` (or similar) that sits inside the HiveStats `ScreenGui`. The frame height is static.

After this dispatch:
- `UpgradeList` becomes a `ScrollingFrame`
  - `ScrollBarThickness = 4`
  - `ScrollBarImageColor3 = Color3.fromRGB(242, 168, 28)` — Honey Gold
  - `CanvasSize` computed dynamically after every render tick: `UDim2.new(0, 0, 0, totalRowHeight)`
- `UIListLayout` with `SortOrder = Enum.SortOrder.LayoutOrder`, `Padding = UDim.new(0, 4)` is added if one is not already present — this makes `AbsoluteContentSize` reliable

### CanvasSize update

A small `RunService.RenderStepped` (one-shot via disconnect) recalculates `CanvasSize` after one frame, giving the layout engine time to position all rows:

```lua
local rs = game:GetService("RunService")
local conn; conn = rs.RenderStepped:Connect(function()
    conn:Disconnect()
    local layout = upgradeList:FindFirstChildOfClass("UIListLayout")
    if layout then
        upgradeList.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end
end)
```

This same recalculation fires whenever `UpgradeSync` delivers new data (rows added/removed) and when the panel is reopened.

### Conversion strategy

The conversion mutates the existing `UpgradeList` Instance in place through MCP — no clone-and-replace of the full controller needed. The Command Bar script:

1. Finds `UpgradeList` in the live PlayerGui hierarchy
2. Changes `ClassName` is read-only, so instead: creates a new `ScrollingFrame` named `UpgradeList_SF`, reparents all children into it, copies position/size/zindex, reparents `UpgradeList_SF` to `UpgradeList.Parent`, destroys old `UpgradeList`, renames `_SF` to `UpgradeList`
3. Also injects a `RenderStepped` recalculate into UpgradesController source via append-injection (so the fix persists after Studio reloads)

The append injection is the durable fix; the live swap is for immediate verification without F5.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `UpgradesController` | Append canvas-size recalculator on UpgradeSync + RenderStepped one-shot |

---

## STEP A — Diagnose current UpgradeList frame

Command Bar:

```lua
-- Find UpgradeList and report its type and dimensions
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local found = {}
for _, obj in pg:GetDescendants() do
    if obj.Name == "UpgradeList" then
        table.insert(found, obj:GetFullName() .. " | " .. obj.ClassName
            .. " | Size=" .. tostring(obj.Size)
            .. " | AbsSize=" .. tostring(obj.AbsoluteSize))
        local layout = obj:FindFirstChildOfClass("UIListLayout")
        if layout then
            table.insert(found, "  UIListLayout AbsoluteContentSize=" .. tostring(layout.AbsoluteContentSize))
        end
        for _, child in obj:GetChildren() do
            if child:IsA("GuiObject") then
                table.insert(found, "  child: " .. child.ClassName .. " '" .. child.Name .. "' Size=" .. tostring(child.Size))
            end
        end
        break
    end
end

if #found == 0 then
    print("UpgradeList NOT FOUND in PlayerGui")
    -- Also check StarterGui for static reference
    local sg = game:GetService("StarterGui")
    for _, obj in sg:GetDescendants() do
        if obj.Name == "UpgradeList" then
            print("Found in StarterGui: " .. obj:GetFullName() .. " | " .. obj.ClassName)
        end
    end
else
    for _, line in found do print(line) end
end
```

---

## STEP B — Live conversion of UpgradeList → ScrollingFrame

Command Bar:

```lua
-- Convert UpgradeList Frame → ScrollingFrame in StarterGui (durable)
-- The live PlayerGui version is read-only for ClassName; this patches StarterGui

local SG = game:GetService("StarterGui")
local upgradeGui: ScreenGui? = nil
local upgradeListOld: Frame? = nil

-- Find the UpgradeList in StarterGui
for _, gui in SG:GetChildren() do
    if gui:IsA("ScreenGui") then
        local ul = gui:FindFirstChild("UpgradeList", true)
        if ul and ul:IsA("Frame") then
            upgradeListOld = ul :: Frame
            upgradeGui = gui :: ScreenGui
            break
        end
    end
end

if not upgradeListOld then
    print("⏭️  UpgradeList not a Frame in StarterGui (already ScrollingFrame or not found)")
else
    -- Create ScrollingFrame replacement
    local sf = Instance.new("ScrollingFrame")
    sf.Name                 = "UpgradeList"
    sf.Size                 = upgradeListOld.Size
    sf.Position             = upgradeListOld.Position
    sf.BackgroundColor3     = upgradeListOld.BackgroundColor3
    sf.BackgroundTransparency = upgradeListOld.BackgroundTransparency
    sf.BorderSizePixel      = 0
    sf.ZIndex               = upgradeListOld.ZIndex
    sf.ScrollBarThickness   = 4
    sf.ScrollBarImageColor3 = Color3.fromRGB(242, 168, 28)
    sf.CanvasSize           = UDim2.new(0, 0, 0, 0)  -- will be set by layout
    sf.AutomaticCanvasSize  = Enum.AutomaticSize.Y    -- auto-grow vertically
    sf.ScrollingDirection   = Enum.ScrollingDirection.Y
    sf.ElasticBehavior      = Enum.ElasticBehavior.WhenScrollable

    -- Add UIListLayout if not present
    local existingLayout = upgradeListOld:FindFirstChildOfClass("UIListLayout")
    if existingLayout then
        existingLayout:Clone().Parent = sf
    else
        local layout = Instance.new("UIListLayout")
        layout.SortOrder        = Enum.SortOrder.LayoutOrder
        layout.Padding          = UDim.new(0, 4)
        layout.FillDirection    = Enum.FillDirection.Vertical
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.Parent = sf
    end

    -- Move all children
    for _, child in upgradeListOld:GetChildren() do
        if not child:IsA("UIListLayout") then  -- already added above
            child.Parent = sf
        end
    end

    sf.Parent = upgradeListOld.Parent
    upgradeListOld:Destroy()
    print("✅ UpgradeList converted to ScrollingFrame (AutomaticCanvasSize=Y, ScrollBarThickness=4, Honey Gold bar)")
end
```

---

## STEP C — UpgradesController: inject canvas-size updater

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local uc = SPS and SPS:FindFirstChild("UpgradesController")
if not uc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "UpgradesController" then
            uc = obj; break
        end
    end
end
assert(uc, "UpgradesController not found")

if uc.Source:find("CanvasResize_108", 1, true) then
    print("⏭️  UpgradesController already has CanvasResize_108 — skip")
else
    local clone = uc:Clone()
    clone.Name = "UpgradesController_WORKING"

    clone.Source = clone.Source .. [[

-- ── UpgradeList Canvas Auto-Resize (dispatch 108) ────────────────────
local RS_108       = game:GetService("RunService")
local Players_108  = game:GetService("Players")

local function refreshCanvasSize_108()
    local pg = Players_108.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, obj in pg:GetDescendants() do
        if obj.Name == "UpgradeList" and obj:IsA("ScrollingFrame") then
            local layout = obj:FindFirstChildOfClass("UIListLayout")
            if layout then
                -- one-frame defer so layout engine has settled
                local conn; conn = RS_108.RenderStepped:Connect(function()
                    conn:Disconnect()
                    obj.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
                end)
            end
            break
        end
    end
end

-- CanvasResize_108: hook into existing UpgradeSync listener
task.spawn(function()
    local RS2_108      = game:GetService("ReplicatedStorage")
    local upgradeSync2 = RS2_108:WaitForChild("UpgradeSync", 10) :: RemoteEvent?
    if not upgradeSync2 then
        warn("[CanvasResize] UpgradeSync not found")
        return
    end

    upgradeSync2.OnClientEvent:Connect(function(_data: {[string]: any})
        task.wait(0.1)  -- rows update first
        refreshCanvasSize_108()
    end)

    -- Also refresh once on first load
    task.wait(2)
    refreshCanvasSize_108()
    print("[CanvasResize_108] Canvas auto-resize active")
end)
]]

    local parent = uc.Parent
    uc.Name = "UpgradesController_OLD_NX"
    uc.Parent = nil
    clone.Name = "UpgradesController"
    clone.Parent = parent
    print("✅ UpgradesController: canvas auto-resize injected")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
-- Verify StarterGui UpgradeList is now a ScrollingFrame
local SG = game:GetService("StarterGui")
local ulFound = false
local ulIsScrolling = false
local hasLayout = false
local hasHoneyBar = false

for _, obj in SG:GetDescendants() do
    if obj.Name == "UpgradeList" then
        ulFound = true
        ulIsScrolling = obj:IsA("ScrollingFrame")
        local layout = obj:FindFirstChildOfClass("UIListLayout")
        hasLayout = layout ~= nil
        if ulIsScrolling then
            local sf = obj :: ScrollingFrame
            hasHoneyBar = math.abs(sf.ScrollBarImageColor3.R - (242/255)) < 0.05
        end
        break
    end
end

local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local uc = SPS and SPS:FindFirstChild("UpgradesController")
if not uc then
    local SG2 = game:GetService("StarterGui")
    for _, obj in SG2:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "UpgradesController" then
            uc = obj; break
        end
    end
end

local checks = {}
table.insert(checks, (ulFound and "✅" or "❌") .. " UpgradeList exists in StarterGui")
table.insert(checks, (ulIsScrolling and "✅" or "❌") .. " UpgradeList is ScrollingFrame")
table.insert(checks, (hasLayout and "✅" or "❌") .. " UIListLayout present in UpgradeList")
table.insert(checks, (hasHoneyBar and "✅" or "❌") .. " ScrollBarImageColor3 = Honey Gold")
table.insert(checks, (uc and uc.Source:find("CanvasResize_108", 1, true) and "✅" or "❌") .. " UpgradesController: CanvasResize_108 injected")
table.insert(checks, (uc and uc.Source:find("refreshCanvasSize_108", 1, true) and "✅" or "❌") .. " UpgradesController: refreshCanvasSize_108 function")
table.insert(checks, (uc and uc.Source:find("AbsoluteContentSize", 1, true) and "✅" or "❌") .. " UpgradesController: AbsoluteContentSize used")
table.insert(checks, (uc and uc.Source:find("AutomaticCanvasSize", 1, false) and "✅" or "❌") .. " UpgradeList: AutomaticCanvasSize=Y (check StarterGui)")

print("=== DISPATCH 108 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 108 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| GUI container swap only — no new BaseParts | 0 permanent parts |
| **Dispatch 108 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `AutomaticCanvasSize = Enum.AutomaticSize.Y` (set in Step B) handles the common case: Roblox auto-grows `CanvasSize.Y` to match `UIListLayout.AbsoluteContentSize`. The `RenderStepped` recalculate in the controller append is a belt-and-suspenders fallback for edge cases where `AutomaticCanvasSize` doesn't fire (e.g., rows added mid-frame, platform parity issues on mobile).
- `ScrollBarThickness = 4` is visually subtle. A thicker bar (6–8) can be used if playtesters find it hard to grab on mobile.
- `ElasticBehavior = WhenScrollable` prevents the rubber-band effect when the list fits within the panel height — the scroll container behaves as a normal Frame until overflow occurs.
- The `PrereqHint` labels added by dispatch 107 increase row height by ~16px. With 8 upgrades (dispatch 104–105: 4 Swift Wings + Queen Bee + 3 from prior tiers), `AbsoluteContentSize.Y` grows by ~128px. The ScrollingFrame handles this transparently.
- If `UpgradeList` is already a `ScrollingFrame` (Step B will print `⏭️ skip`), Steps B and C are still valid — Step C's inject will add the `CanvasResize_108` marker and the `AutomaticCanvasSize` assignment remains a no-op if already set.
- The `_108` suffix on `RS_108`, `Players_108`, `RS2_108`, `refreshCanvasSize_108` prevents collision with the existing `_107`, `_92` injections.
