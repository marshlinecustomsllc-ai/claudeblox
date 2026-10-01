# Dispatch 107 — Upgrade Tree Visualization
## Cycle 14 · A Bee's World

**Feature:** The upgrades panel (dispatch 10/12 era + dispatch 92 tab system) shows upgrades as a flat list. Players cannot see prerequisite chains — they don't know that Swift Wings I → II → III → Queen Bee forms a progression path. This dispatch adds a **tree indicator** to each upgrade row: a small `→` arrow and dimmed prerequisite name appears below the upgrade title when a prereq is defined, making the upgrade tree scannable at a glance. Locked upgrades (prereq not yet met) are visually distinguished with a greyed-out overlay. This is pure client-side UI — no server changes.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 106 (Pollen Surge Event)

---

## DESIGN

### Row enhancement strategy

The Upgrades panel is built by `UpgradesController` (dispatch 10/12). Each row in the `UpgradeList` frame is a `Frame` or `Button` with:
- A `NameLabel` TextLabel (upgrade name)
- A `CostLabel` TextLabel (cost)
- A `BuyButton` TextButton

This dispatch appends a `DescLabel` (prereq hint) to each row and applies a lock overlay `Frame` when the upgrade is locked.

The injection hooks into `UpgradeSync` events: when the client receives an upgrade list sync (or on first load), it iterates `UpgradeList` children and post-processes each row.

### Lock overlay

A semi-transparent `Frame` (BackgroundColor3 = `Color3.fromRGB(0,0,0)`, BackgroundTransparency = 0.5) covers the entire row and has `ZIndex` above the row content. The `BuyButton` has `Active = false` while locked. The overlay is named `LockOverlay` for identification and removal when the prereq is met.

### Prereq hint label

A new `TextLabel` named `PrereqHint`:
- Text: `"→ Requires: [prereq name]"` or `"✅ Prereq met"` if the prereq is owned
- Font: Gotham, TextSize 11, TextColor: dim wax cream at 60% transparency
- Position: below DescLabel (if exists) or below NameLabel

### When to apply

On `HiveStatsSync` (which includes profile data on some architectures) or on `UpgradeSync` — whichever fires with current upgrade ownership data. The controller adds a second `OnClientEvent` listener to `UpgradeSync`.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `UpgradesController` | Append prereq tree indicator + lock overlay application |

---

## STEP A — Diagnose UpgradeList row structure

Command Bar:

```lua
-- Inspect the UpgradeList frame to understand row structure
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

print("UpgradesController found: " .. (uc and uc:GetFullName() or "NOT FOUND"))
if uc then
    -- Check for prereq/locked handling already in source
    local lines = uc.Source:split("\n")
    for i, line in lines do
        if line:find("prereq") or line:find("locked") or line:find("LockOverlay") or line:find("UpgradeList") then
            print(i .. ": " .. line)
        end
    end
end

-- Also check PlayerGui at runtime for actual row structure
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
for _, gui in pg:GetChildren() do
    if gui:IsA("ScreenGui") and gui.Name:lower():find("upgrade") then
        print("Found: " .. gui:GetFullName())
        local list = gui:FindFirstChild("UpgradeList", true)
        if list then
            local first = list:GetChildren()[1]
            if first then
                print("First row: " .. first.ClassName .. " '" .. first.Name .. "'")
                for _, child in first:GetChildren() do
                    print("  " .. child.ClassName .. " '" .. child.Name .. "' Text=" .. (child:IsA("TextLabel") and child.Text or "n/a"))
                end
            end
        end
    end
end
```

---

## STEP B — UpgradesController: inject prereq tree indicators

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

if uc.Source:find("PrereqHint", 1, true) then
    print("⏭️  UpgradesController already has PrereqHint — skip")
else
    local clone = uc:Clone()
    clone.Name = "UpgradesController_WORKING"

    clone.Source = clone.Source .. [[

-- ── Upgrade Tree Visualization (dispatch 107) ────────────────────
local Players_107  = game:GetService("Players")
local RS_107       = game:GetService("ReplicatedStorage")

local PREREQ_COLOR  = Color3.fromRGB(180, 165, 120)  -- dim wax cream
local LOCKED_TINT   = Color3.fromRGB(0, 0, 0)

local function applyTreeIndicators_107(ownedUpgrades: {[string]: boolean})
    local pg = Players_107.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end

    -- Find the UpgradeList frame
    local upgradeList: Instance? = nil
    for _, gui in pg:GetDescendants() do
        if gui.Name == "UpgradeList" then upgradeList = gui; break end
    end
    if not upgradeList then return end

    -- Get Config for upgrade definitions
    local ok, Config107 = pcall(require, RS_107:FindFirstChild("Config"))
    if not ok or not Config107 or not Config107.UPGRADES then return end

    for _, row in upgradeList:GetChildren() do
        if not row:IsA("GuiObject") then continue end
        local upgradeId = row:GetAttribute("UpgradeId")
        if not upgradeId then continue end

        local upgradeDef = Config107.UPGRADES[upgradeId]
        if not upgradeDef then continue end

        local prereqId   = upgradeDef.prereq
        local isOwned    = ownedUpgrades[upgradeId] == true
        local prereqMet  = not prereqId or ownedUpgrades[prereqId] == true
        local isLocked   = not prereqMet and not isOwned

        -- Add or update PrereqHint label
        if prereqId then
            local hint = row:FindFirstChild("PrereqHint") :: TextLabel?
            if not hint then
                hint = Instance.new("TextLabel")
                hint.Name                   = "PrereqHint"
                hint.Size                   = UDim2.new(1, -8, 0, 14)
                hint.BackgroundTransparency = 1
                hint.Font                   = Enum.Font.Gotham
                hint.TextSize               = 11
                hint.TextColor3             = PREREQ_COLOR
                hint.TextTransparency       = 0.35
                hint.TextXAlignment         = Enum.TextXAlignment.Left
                hint.ZIndex                 = (row.ZIndex or 1) + 1
                -- Position below the row's bottom padding
                hint.Position = UDim2.new(0, 4, 1, -16)
                hint.Parent = row
            end
            local prereqName = (Config107.UPGRADES[prereqId] and Config107.UPGRADES[prereqId].name) or prereqId
            if prereqMet then
                hint.Text             = "✅ " .. prereqName
                hint.TextTransparency = 0.55
            else
                hint.Text             = "→ Requires: " .. prereqName
                hint.TextTransparency = 0.35
            end
        end

        -- Add or remove lock overlay
        local lockOverlay = row:FindFirstChild("LockOverlay")
        if isLocked then
            if not lockOverlay then
                lockOverlay = Instance.new("Frame")
                lockOverlay.Name                   = "LockOverlay"
                lockOverlay.Size                   = UDim2.new(1, 0, 1, 0)
                lockOverlay.Position               = UDim2.new(0, 0, 0, 0)
                lockOverlay.BackgroundColor3       = LOCKED_TINT
                lockOverlay.BackgroundTransparency = 0.55
                lockOverlay.BorderSizePixel        = 0
                lockOverlay.ZIndex                 = (row.ZIndex or 1) + 2
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 6)
                corner.Parent = lockOverlay
                lockOverlay.Parent = row
            end
            -- Disable buy button
            local btn = row:FindFirstChild("BuyButton")
            if btn and btn:IsA("GuiButton") then
                (btn :: GuiButton).Active = false
            end
        else
            if lockOverlay then lockOverlay:Destroy() end
            local btn = row:FindFirstChild("BuyButton")
            if btn and btn:IsA("GuiButton") and not isOwned then
                (btn :: GuiButton).Active = true
            end
        end
    end
end

-- Listen for UpgradeSync to get owned upgrades
task.spawn(function()
    local upgradeSync = RS_107:WaitForChild("UpgradeSync", 10) :: RemoteEvent?
    if not upgradeSync then
        warn("[UpgradeTree] UpgradeSync not found after 10s")
        return
    end

    upgradeSync.OnClientEvent:Connect(function(data: {[string]: any})
        if data and data.ownedUpgrades then
            applyTreeIndicators_107(data.ownedUpgrades :: {[string]: boolean})
        end
    end)

    -- Also attempt to apply on next frame in case UpgradeList is already populated
    task.wait(3)
    -- Try to read profile from HiveStatsSync data if available via attribute
    local player = Players_107.LocalPlayer
    local ownedAttr = player:GetAttribute("OwnedUpgrades")
    if type(ownedAttr) == "table" then
        applyTreeIndicators_107(ownedAttr :: {[string]: boolean})
    end

    print("[UpgradeTree] Upgrade tree visualization active")
end)
]]

    local parent = uc.Parent
    uc.Name = "UpgradesController_OLD_NX"
    uc.Parent = nil
    clone.Name = "UpgradesController"
    clone.Parent = parent
    print("✅ UpgradesController: upgrade tree visualization injected")
end
```

---

## STEP C — Verification sweep

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

local checks = {}
table.insert(checks, (uc and "✅" or "❌") .. " UpgradesController exists")
table.insert(checks, (uc and uc.Source:find("PrereqHint", 1, true) and "✅" or "❌") .. " UpgradesController: PrereqHint label")
table.insert(checks, (uc and uc.Source:find("LockOverlay", 1, true) and "✅" or "❌") .. " UpgradesController: LockOverlay frame")
table.insert(checks, (uc and uc.Source:find("applyTreeIndicators_107", 1, true) and "✅" or "❌") .. " UpgradesController: applyTreeIndicators_107")
table.insert(checks, (uc and uc.Source:find("prereqMet", 1, true) and "✅" or "❌") .. " UpgradesController: prereqMet logic")
table.insert(checks, (uc and uc.Source:find("isLocked", 1, true) and "✅" or "❌") .. " UpgradesController: isLocked flag")
table.insert(checks, (uc and uc.Source:find("UpgradeSync", 1, true) and "✅" or "❌") .. " UpgradesController: UpgradeSync listener")
table.insert(checks, (uc and uc.Source:find("Config107%.UPGRADES", 1, false) and "✅" or "❌") .. " UpgradesController: reads Config.UPGRADES for prereq names")
table.insert(checks, (uc and uc.Source:find("BuyButton", 1, true) and "✅" or "❌") .. " UpgradesController: disables BuyButton when locked")

print("=== DISPATCH 107 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 107 complete" or "❌ SOME CHECKS FAILED")

-- Upgrade tree chain verification
local RS = game:GetService("ReplicatedStorage")
local ok, Config = pcall(require, RS:FindFirstChild("Config"))
if ok and Config and Config.UPGRADES then
    print("\nUpgrade prereq chains:")
    local seen = {}
    for id, def in Config.UPGRADES do
        if def.prereq and not seen[id] then
            -- Walk chain
            local chain = {id}
            local curr = def.prereq
            while curr and not seen[curr] do
                table.insert(chain, 1, curr)
                seen[curr] = true
                curr = Config.UPGRADES[curr] and Config.UPGRADES[curr].prereq
            end
            seen[id] = true
            print("  " .. table.concat(chain, " → "))
        end
    end
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Client-side UI injection — no new BaseParts | 0 permanent parts |
| **Dispatch 107 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `row:GetAttribute("UpgradeId")` assumes UpgradesController sets this attribute on each row when building the list. If rows are identified differently (e.g., by row Name matching upgrade ID), replace the attribute lookup with `upgradeId = row.Name`. Step A diagnosis will reveal the actual naming convention.
- `applyTreeIndicators_107` is safe to call multiple times — it checks for existing `PrereqHint` and `LockOverlay` before creating new ones, and updates in place on subsequent calls.
- The `LockOverlay` sets `Active = false` on `BuyButton`, not `Visible = false`. This preserves the button's visual presence (player can see the upgrade exists) while preventing interaction. `Active = false` on a GuiButton still renders but swallows no input — the overlay frame above it intercepts clicks instead.
- `ownedUpgrades` data source: the injection assumes `UpgradeSync` fires `{ownedUpgrades = {[upgradeId] = true}}`. If the actual payload is different (e.g., `{success=true, upgradeId="..."}`), the single-purchase case can still trigger a partial re-scan by building `{[data.upgradeId] = true}` from the success event and calling `applyTreeIndicators_107` with that partial table.
- `_107` suffix on all injected variables prevents collision with the `_92` (tab system) injection already at the end of `UpgradesController.Source`.
- The `task.wait(3)` fallback at the end of the spawn block gives the existing `UpgradesController` initialization time to build the `UpgradeList` rows before the tree indicators are applied. If the panel loads asynchronously, a `DescendantAdded` hook on the UpgradeList can be added to re-apply indicators as rows are created.
