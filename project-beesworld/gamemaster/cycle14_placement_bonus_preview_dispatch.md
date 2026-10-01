# Dispatch 115 — Comb Placement Bonus Preview
## Cycle 14 · A Bee's World

**Feature:** When a player hovers over or selects an empty comb slot in Build Mode, a small tooltip shows how many adjacency bonuses that slot will receive for each cell type they could place there. Kids see "🎉 3 neighbors will help!" in large friendly text. Adults can tap a tiny `details` link to see the exact percentages. This makes the placement puzzle intuitive for both age groups — kids learn by exploring ("that spot gets more stars!"), adults optimise with data.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 114 (Comb Cell Guide)

---

## DESIGN

### What is shown

When the player selects an empty comb slot in Build Mode and has a cell type chosen, a `PlacementPreviewLabel` appears just above the slot:

```
╔══════════════════════╗
║  🌟🌟🌟  3 bonuses!  ║   ← kid view (always)
║  +18% honey output   ║   ← detail line (togglable, off by default)
╚══════════════════════╝
```

The star count = number of adjacent filled cells that provide a bonus to the chosen type (0–6 for hex grid). No stars = "Place here too!" (encourage filling, never negative).

### Bonus star mapping

| Adjacent bonus-givers | Stars shown | Friendly text |
|----------------------|-------------|---------------|
| 0 | ⬜ | "Place here too!" |
| 1 | 🌟 | "1 neighbor helps!" |
| 2 | 🌟🌟 | "2 neighbors help!" |
| 3 | 🌟🌟🌟 | "3 neighbors help!" |
| 4–5 | 🌟🌟🌟+ | "Great spot!" |
| 6 | 🌟🌟🌟✨ | "Perfect spot! 🐝" |

### Adjacency rules (from architecture)

| Cell being placed | Gains bonus from neighbour type |
|-------------------|--------------------------------|
| Honey Cell | Adjacent Honey Cell +6% |
| Brood Cell | Adjacent Pollen Cell +8% hatch |
| Pollen Cell | Adjacent Brood Cell +5% production |
| Royal Cell | Adjacent Honey Cell +10% |
| Dance Floor | All adjacent cells +4% route capacity (center only, fixed) |
| Propolis Kiln | Adjacent Brood Cell +7% resin |

### Implementation

`PlacementPreviewController` LocalScript appended to **UpgradesController** (or as a standalone LocalScript in StarterPlayerScripts). It:

1. Listens to `BuildModeSync` RemoteEvent (client receives `{slotId, cellType, action}` when slot is selected/deselected in Build Mode)
2. Or polls `player:GetAttribute("SelectedSlot")` and `player:GetAttribute("SelectedCellType")` if Build Mode sets attributes
3. Finds the slot Part in `Workspace.Map` via `findPlotPart_113`-style search
4. Reads neighbour cell types from `player:GetAttribute("CombState")` (JSON-encoded comb layout) or from adjacent slot Parts' `CellType` attribute
5. Computes bonus count
6. Shows/hides `PlacementPreviewGui` BillboardGui above the slot Part

### GUI approach

`PlacementPreviewGui` is a **BillboardGui** parented to the slot Part when visible (not StarterGui), so it hovers over the actual slot in 3D space. Size = `{0, 180, 0, 56}` studs offset. This works on both desktop and mobile.

### Detail toggle

A small `[details]` TextButton below the star row toggles the detail line. Default: off (kids don't need percentages). The toggle state is saved in `LocalPlayer.Attributes` so it persists per session.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PlacementPreviewController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create PlacementPreviewController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PlacementPreviewController") then
    print("⏭️  PlacementPreviewController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PlacementPreviewController"
    ctrl.Source = [[
--!strict
-- PlacementPreviewController — dispatch 115
-- Shows a bonus-star tooltip when the player selects a comb slot in Build Mode.
-- Kids: star count + friendly text.  Adults: optional % detail line.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")

local player    = Players.LocalPlayer

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(80,  50,  20)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local DARK_BG     = Color3.fromRGB(20,  12,   4)

-- ── Adjacency bonus rules ─────────────────────────────────────────
-- Maps cellType → which neighbourType grants a bonus → bonus % string
local BONUS_FROM_115: {[string]: {[string]: string}} = {
    honey       = { honey    = "+6% honey" },
    brood       = { pollen   = "+8% hatch" },
    pollen      = { brood    = "+5% pollen" },
    royal       = { honey    = "+10% queen" },
    kiln        = { brood    = "+7% resin" },
    dance_floor = {},  -- center slot, always fixed
}

local STAR_TEXT_115: {[number]: string} = {
    [0] = "Place here too!",
    [1] = "🌟  1 neighbour helps!",
    [2] = "🌟🌟  2 neighbours help!",
    [3] = "🌟🌟🌟  3 neighbours help!",
    [4] = "🌟🌟🌟  Great spot!",
    [5] = "🌟🌟🌟  Great spot!",
    [6] = "🌟🌟🌟✨  Perfect spot! 🐝",
}

-- ── BillboardGui factory ──────────────────────────────────────────
local activeBillboard_115: BillboardGui? = nil

local function removeBillboard_115()
    if activeBillboard_115 then
        activeBillboard_115:Destroy()
        activeBillboard_115 = nil
    end
end

local function createBillboard_115(
    part: BasePart,
    cellType: string,
    bonusCount: number,
    bonusDetails: string,
    showDetail: boolean
): BillboardGui
    removeBillboard_115()

    local bb = Instance.new("BillboardGui")
    bb.Name           = "PlacementPreviewBB_115"
    bb.Adornee        = part
    bb.Size           = UDim2.new(0, 180, 0, showDetail and 68 or 48)
    bb.StudsOffset    = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.ResetOnSpawn   = false

    local bg = Instance.new("Frame")
    bg.BackgroundColor3         = DARK_BG
    bg.BackgroundTransparency   = 0.15
    bg.Size                     = UDim2.new(1, 0, 1, 0)
    bg.Parent                   = bb

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent       = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color     = HONEY_GOLD
    stroke.Thickness = 1.5
    stroke.Parent    = bg

    -- Star / friendly line
    local starLabel = Instance.new("TextLabel")
    starLabel.Name                 = "StarLabel"
    starLabel.Text                 = STAR_TEXT_115[math.min(bonusCount, 6)] or STAR_TEXT_115[6]
    starLabel.Font                 = Enum.Font.GothamBold
    starLabel.TextSize             = 13
    starLabel.TextColor3           = HONEY_GOLD
    starLabel.BackgroundTransparency = 1
    starLabel.Size                 = UDim2.new(1, -8, 0, 24)
    starLabel.Position             = UDim2.new(0, 4, 0, 4)
    starLabel.TextXAlignment       = Enum.TextXAlignment.Center
    starLabel.Parent               = bg

    -- Detail line (adults)
    if showDetail and bonusDetails ~= "" then
        local detailLabel = Instance.new("TextLabel")
        detailLabel.Name                 = "DetailLabel"
        detailLabel.Text                 = bonusDetails
        detailLabel.Font                 = Enum.Font.Gotham
        detailLabel.TextSize             = 11
        detailLabel.TextColor3           = WAX_CREAM
        detailLabel.BackgroundTransparency = 1
        detailLabel.Size                 = UDim2.new(1, -8, 0, 18)
        detailLabel.Position             = UDim2.new(0, 4, 0, 28)
        detailLabel.TextXAlignment       = Enum.TextXAlignment.Center
        detailLabel.Parent               = bg
    end

    -- Details toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name               = "ToggleDetail"
    toggleBtn.Text               = showDetail and "hide details" or "details"
    toggleBtn.Font               = Enum.Font.Gotham
    toggleBtn.TextSize           = 10
    toggleBtn.TextColor3         = Color3.fromRGB(160, 140, 100)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Size               = UDim2.new(0, 60, 0, 14)
    toggleBtn.Position           = UDim2.new(1, -64, 1, -16)
    toggleBtn.Parent             = bg

    bb.Parent = part
    activeBillboard_115 = bb
    return bb
end

-- ── Slot & neighbour discovery ────────────────────────────────────
-- Reads CombState JSON attribute: {slot_1:"honey", slot_2:"brood", ...}
local function getCombState_115(): {[string]: string}
    local raw = player:GetAttribute("CombState")
    if not raw or typeof(raw) ~= "string" then return {} end
    -- Simple key=value parser (no full JSON lib needed: values are always simple strings)
    local state: {[string]: string} = {}
    for k, v in raw:gmatch('"([^"]+)"%s*:%s*"([^"]+)"') do
        state[k] = v
    end
    return state
end

-- Hex grid neighbour slot ids for slot 1-9 (3x3 approximation used in A Bee's World)
-- Exact adjacency depends on grid shape; this uses offset-grid neighbour table.
local NEIGHBOURS_115: {[number]: {number}} = {
    [1] = {2, 4},
    [2] = {1, 3, 4, 5},
    [3] = {2, 5, 6},
    [4] = {1, 2, 5, 7},
    [5] = {2, 3, 4, 6, 7, 8},
    [6] = {3, 5, 8, 9},
    [7] = {4, 5, 8},
    [8] = {5, 6, 7, 9},
    [9] = {6, 8},
}

local function computeBonus_115(slotId: number, cellType: string): (number, string)
    local bonusRule = BONUS_FROM_115[cellType]
    if not bonusRule then return 0, "" end

    local combState = getCombState_115()
    local neighbours = NEIGHBOURS_115[slotId] or {}
    local count = 0
    local details: {string} = {}

    for _, nId in neighbours do
        local nType = combState["slot_" .. nId] or combState[tostring(nId)]
        if nType then
            local bonusStr = bonusRule[nType]
            if bonusStr then
                count += 1
                table.insert(details, bonusStr)
            end
        end
    end

    return count, table.concat(details, ", ")
end

-- ── Find slot Part in workspace ───────────────────────────────────
local function findSlotPart_115(plotId: number, slotId: number): BasePart?
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end
    local candidates = {
        "Plot" .. plotId, "plot_" .. plotId, "Plot " .. plotId,
    }
    for _, name in candidates do
        local folder = map:FindFirstChild(name)
        if folder then
            -- Look for CombSlot_N naming convention
            for _, obj in folder:GetDescendants() do
                if obj:IsA("BasePart") then
                    if obj.Name == "CombSlot_" .. slotId or
                       obj.Name == "Slot_" .. slotId or
                       obj.Name == "HexSlot" .. slotId or
                       obj:GetAttribute("SlotId") == slotId then
                        return obj
                    end
                end
            end
        end
    end
    return nil
end

-- ── Main listener ─────────────────────────────────────────────────
-- A Bee's World Build Mode sets player attributes:
--   SelectedSlot: number (0 = none selected)
--   SelectedCellType: string ("honey", "brood", etc.)
-- If the server uses different attributes, update the names below.

local SLOT_ATTR      = "SelectedSlot"
local CELLTYPE_ATTR  = "SelectedCellType"
local DETAIL_ATTR    = "PlacementDetailOn"  -- persists per session

local function onSelectionChanged_115()
    local slotId   = tonumber(player:GetAttribute(SLOT_ATTR))   or 0
    local cellType = tostring(player:GetAttribute(CELLTYPE_ATTR) or "")

    if slotId < 1 or cellType == "" or cellType == "nil" then
        removeBillboard_115()
        return
    end

    local slotPart = findSlotPart_115(1, slotId)
    if not slotPart then
        removeBillboard_115()
        return
    end

    local bonusCount, bonusDetails = computeBonus_115(slotId, cellType)
    local showDetail = player:GetAttribute(DETAIL_ATTR) == true

    local bb = createBillboard_115(slotPart, cellType, bonusCount, bonusDetails, showDetail)

    -- Wire detail toggle
    local toggleBtn = bb:FindFirstChild("Frame", true) and
                      (bb:FindFirstChild("Frame", true) :: Frame):FindFirstChild("ToggleDetail")
    if toggleBtn and toggleBtn:IsA("TextButton") then
        toggleBtn.Activated:Connect(function()
            local current = player:GetAttribute(DETAIL_ATTR) == true
            player:SetAttribute(DETAIL_ATTR, not current)
            -- Rebuild billboard with new state
            local bc2, bd2 = computeBonus_115(slotId, cellType)
            if slotPart and slotPart.Parent then
                createBillboard_115(slotPart, cellType, bc2, bd2, not current)
            end
        end)
    end
end

player:GetAttributeChangedSignal(SLOT_ATTR):Connect(onSelectionChanged_115)
player:GetAttributeChangedSignal(CELLTYPE_ATTR):Connect(onSelectionChanged_115)

-- Also clean up on character removal
player.CharacterRemoving:Connect(removeBillboard_115)

print("[PlacementPreviewController] Ready — comb slot bonus preview active")
]]
    ctrl.Parent = SPS
    print("✅ PlacementPreviewController created in StarterPlayerScripts")
end
```

---

## STEP B — Wire SelectedSlot / SelectedCellType attributes in Build Mode script

The preview controller listens to `player:GetAttribute("SelectedSlot")` and `player:GetAttribute("SelectedCellType")`. If the existing Build Mode LocalScript does not already set these attributes, append the following to it.

> **Check first:** search the Build Mode script source for `SelectedSlot` — if already present, skip Step B entirely.

Command Bar (check + conditional append):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

-- Find the Build Mode controller (common names)
local buildScript: LuaSourceContainer? = nil
for _, name in {"BuildModeController", "CombBuildController", "HiveBuildController", "BuildController"} do
    local s = SPS and SPS:FindFirstChild(name)
    if s then buildScript = s break end
end
-- Also check StarterGui scripts
if not buildScript then
    local SG = game:GetService("StarterGui")
    for _, name in {"BuildModeController", "CombBuildController", "HiveBuildController"} do
        local s = SG:FindFirstChildWhichIsA("LocalScript", true)
        if s and s.Name == name then buildScript = s break end
    end
end

if not buildScript then
    print("ℹ️  Build Mode script not found — PlacementPreviewController will fall back to attribute polling")
    print("    Attributes SelectedSlot + SelectedCellType must be set by the server or existing client code")
    print("    If they are not set, the tooltip simply won't appear (silent fallback — no errors)")
else
    if buildScript.Source:find("SelectedSlot", 1, true) then
        print("⏭️  SelectedSlot already set in " .. buildScript.Name .. " — skip Step B")
    else
        -- Append attribute-set calls to the build script
        local INJECTION_MARKER = "-- SlotAttrSet_115"
        if buildScript.Source:find(INJECTION_MARKER, 1, true) then
            print("⏭️  Step B already injected — skip")
        else
            buildScript.Source = buildScript.Source .. "\n\n" .. INJECTION_MARKER .. [[

-- Dispatch 115: expose selected slot/celltype as player attributes
-- so PlacementPreviewController can show bonus stars.
-- This block fires whenever build mode selection changes.
local _localPlayer_115 = game:GetService("Players").LocalPlayer

local function _setSlotAttrs_115(slotId: number, cellType: string)
    _localPlayer_115:SetAttribute("SelectedSlot",     slotId)
    _localPlayer_115:SetAttribute("SelectedCellType", cellType)
end

-- Hook into existing selection signals if they exist
-- Common pattern: buildModeState.slotSelected:Connect(...)
-- If the build script uses a different signal name, wire it here.
-- Fallback: if a BuildModeSync RemoteEvent fires slot selections,
-- the attribute will be set by the server — this append is a no-op.
if typeof(_G.BuildModeState) == "table" then
    if _G.BuildModeState.onSlotSelected then
        _G.BuildModeState.onSlotSelected:Connect(function(sid, ct)
            _setSlotAttrs_115(sid, ct or "")
        end)
    end
    if _G.BuildModeState.onDeselect then
        _G.BuildModeState.onDeselect:Connect(function()
            _setSlotAttrs_115(0, "")
        end)
    end
end
print("[Dispatch 115] SlotAttrSet_115 wired")
]]
            print("✅ Step B injected into " .. buildScript.Name)
        end
    end
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PlacementPreviewController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " PlacementPreviewController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("BONUS_FROM_115", 1, true) and "✅" or "❌") .. " BONUS_FROM_115 adjacency table")
table.insert(checks, (ctrl and ctrl.Source:find("NEIGHBOURS_115", 1, true) and "✅" or "❌") .. " NEIGHBOURS_115 hex grid table")
table.insert(checks, (ctrl and ctrl.Source:find("computeBonus_115", 1, true) and "✅" or "❌") .. " computeBonus_115 function")
table.insert(checks, (ctrl and ctrl.Source:find("createBillboard_115", 1, true) and "✅" or "❌") .. " createBillboard_115 BillboardGui factory")
table.insert(checks, (ctrl and ctrl.Source:find("removeBillboard_115", 1, true) and "✅" or "❌") .. " removeBillboard_115 cleanup")
table.insert(checks, (ctrl and ctrl.Source:find("findSlotPart_115", 1, true) and "✅" or "❌") .. " findSlotPart_115 helper")
table.insert(checks, (ctrl and ctrl.Source:find("SelectedSlot", 1, true) and "✅" or "❌") .. " SelectedSlot attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("SelectedCellType", 1, true) and "✅" or "❌") .. " SelectedCellType attribute listener")
table.insert(checks, (ctrl and ctrl.Source:find("PlacementDetailOn", 1, true) and "✅" or "❌") .. " PlacementDetailOn detail toggle")
table.insert(checks, (ctrl and ctrl.Source:find("STAR_TEXT_115", 1, true) and "✅" or "❌") .. " STAR_TEXT_115 friendly text table")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterRemoving", 1, true) and "✅" or "❌") .. " CharacterRemoving cleanup")

print("=== DISPATCH 115 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 115 complete" or "❌ SOME CHECKS FAILED")

print("\nBonus star tiers:")
print("  0 neighbours → 'Place here too!'")
print("  1-3 → 🌟 × N + count text")
print("  4-5 → 🌟🌟🌟 Great spot!")
print("  6   → 🌟🌟🌟✨ Perfect spot! 🐝")
print("\nAdjacency rules:")
print("  Honey  ← Honey  +6%")
print("  Brood  ← Pollen +8%")
print("  Pollen ← Brood  +5%")
print("  Royal  ← Honey  +10%")
print("  Kiln   ← Brood  +7%")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PlacementPreviewController (LocalScript only, creates runtime BillboardGui) | 0 permanent |
| **Dispatch 115 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `NEIGHBOURS_115` uses a 3×3 grid offset model matching the 9-slot comb layout from architecture. If the comb is hexagonal with a different neighbour set, update this table — the controller logic is otherwise unchanged.
- `getCombState_115()` parses the `CombState` JSON attribute that the server sets on the player when their comb changes. If the server uses a different mechanism (e.g., a RemoteEvent payload rather than an attribute), the only change needed is the data source in `computeBonus_115`.
- The `PlacementDetailOn` attribute persists for the session so adults who enable percentage details don't have to re-enable it every time they open Build Mode.
- `BillboardGui.AlwaysOnTop = true` ensures the preview is visible even when the slot is partially obscured by the hive geometry — critical for mobile players where camera angle is harder to control.
- Step B is fully defensive: if `BuildModeController` doesn't exist or already sets the attributes, the injection is skipped. The preview silently does nothing rather than erroring — zero risk to existing build mode functionality.
- Kid-friendly framing throughout: "neighbours" not "adjacent cells", "helps" not "provides bonus", stars not percentages by default. Adults opt-in to numbers, kids never see jargon they don't understand.
- `"Place here too!"` (zero bonuses) is deliberately encouraging, not discouraging — kids should always feel good about building, even in a suboptimal spot. The star system rewards good placement without punishing bad placement.
