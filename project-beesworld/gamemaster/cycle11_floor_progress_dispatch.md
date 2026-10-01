# CYCLE 11 — FLOOR PROGRESS UI DISPATCH (dispatch 28)
## FloorProgressGui — Visual floor unlock requirements in HiveGui

**Agent:** luau-scripter  
**Prerequisites:** dispatch 14 (ShopGui/HiveGui 4-tab baseline), dispatch 18 (QueenService — queenTier in HudDataSync)  
**Part budget impact:** 0 new world parts → **~4,094 / 5,000** total (unchanged)

---

## OVERVIEW

Adds a **FLOORS** fifth tab to HiveGui (joining BUILD / SHOP / QUEEN / WARDROBE). Shows players exactly what they need to unlock Floor 2 and Floor 3 — cells built on current floor, honey spent total, and queen tier reached — with a visual progress bar per requirement. Requirements come from `Config.FLOOR_REQUIREMENTS` (new config block). Data is delivered via an extended `HudDataSync` remote (adds `floorUnlocked`, `cellsBuilt`, `honeySpent`). Entirely UI-side; no new server scripts.

---

## STEP A — Config.FLOOR_REQUIREMENTS

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP A: Add Config.FLOOR_REQUIREMENTS table
local RS = game:GetService("ReplicatedStorage")
local Modules = RS:FindFirstChild("Modules")
assert(Modules, "Modules folder not found")

local configOld = Modules:FindFirstChild("Config")
assert(configOld and configOld:IsA("ModuleScript"), "Config ModuleScript not found")

local configClone = configOld:Clone()
local src = configOld.Source

-- Add FLOOR_REQUIREMENTS table before the closing return statement
local floorReqs = [[
Config.FLOOR_REQUIREMENTS = {
    [2] = {
        label         = "Floor 2",
        cellsOnFloor1 = 12,   -- must have built at least 12 cells on floor 1
        totalHoneySpent = 5000,
        queenTierMin  = 2,    -- Crowned Queen (tier 2)
    },
    [3] = {
        label         = "Floor 3",
        cellsOnFloor2 = 6,    -- at least 6 cells on floor 2
        totalHoneySpent = 25000,
        queenTierMin  = 4,    -- Elder Queen (tier 4)
    },
}

]]

-- Insert before "return Config"
src = src:gsub("(return Config)", floorReqs .. "%1")

assert(src:find("FLOOR_REQUIREMENTS"), "FLOOR_REQUIREMENTS not inserted")

configOld.Name   = "Config_OLD_pre_floor_reqs"
configClone.Source = src
configClone.Name   = "Config"
configClone.Parent = Modules
configOld.Parent   = nil

print("STEP A DONE: Config.FLOOR_REQUIREMENTS added (floor 2: 12 cells + 5k honey + tier2; floor 3: 6 cells + 25k honey + tier4)")
```

---

## STEP B — Extend HudDataSync payload

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP B: Extend HudDataSync to carry floorUnlocked + cellsBuilt + honeySpent
-- These are computed from profile and CombService state in the server's HiveController
-- or Main script that fires HudDataSync.

local SSS = game:GetService("ServerScriptService")

-- Find wherever HudDataSync is fired (Main.lua or HiveController server Script)
local function findScriptWithPattern(parent, pattern)
    for _, child in parent:GetDescendants() do
        if child:IsA("LuaSourceContainer") and child.Source:find(pattern) then
            return child
        end
    end
    return nil
end

local hubScript = findScriptWithPattern(SSS, "HudDataSync")
if not hubScript then
    print("STEP B SKIP: No script found that fires HudDataSync")
    print("  Manual step: find the script that fires HudDataSync:FireClient and add:")
    print("  floorUnlocked = profile.floorUnlocked or 1,")
    print("  cellsBuilt    = profile.cellsBuilt or 0,")
    print("  honeySpent    = profile.lifetimeHoneySpent or 0")
    return
end

print("Found HudDataSync in: " .. hubScript:GetFullName())

local src = hubScript.Source

-- Add the three new fields to the HudDataSync:FireClient payload table
-- Anchor: find existing fields already in the payload (shedTier is always present)
src = src:gsub(
    "(shedTier%s*=%s*[^,\n]+,)",
    "%1\n\t\tfloorUnlocked = profile.floorUnlocked or 1,\n\t\tcellsBuilt    = profile.cellsBuilt or 0,\n\t\thoneySpent    = profile.lifetimeHoneySpent or 0,"
)

if src:find("floorUnlocked") then
    local oldName = hubScript.Name
    local clone   = hubScript:Clone()
    hubScript.Name = oldName .. "_OLD_pre_floor_data"
    clone.Source   = src
    clone.Name     = oldName
    clone.Parent   = hubScript.Parent
    hubScript.Parent = nil
    print("STEP B DONE: HudDataSync payload extended with floorUnlocked + cellsBuilt + honeySpent")
else
    print("STEP B FAIL: Anchor 'shedTier' not matched — add fields manually")
end
```

---

## STEP C — FloorProgressGui tab in HiveGui

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP C: Add FLOORS tab to HiveGui
local SG     = game:GetService("StarterGui")
local hgui   = SG:FindFirstChild("HiveGui")
assert(hgui, "HiveGui not found in StarterGui")

local mainFrame = hgui:FindFirstChild("MainFrame")
assert(mainFrame, "HiveGui.MainFrame not found")

local tabBar = mainFrame:FindFirstChild("TabBar")
assert(tabBar, "HiveGui.MainFrame.TabBar not found")

local pageContainer = mainFrame:FindFirstChild("PageContainer")
assert(pageContainer, "HiveGui.MainFrame.PageContainer not found")

-- Remove old FLOORS tab if exists
local oldTab  = tabBar:FindFirstChild("TabFloors")
local oldPage = pageContainer:FindFirstChild("FloorsPage")
if oldTab  then oldTab:Destroy() end
if oldPage then oldPage:Destroy() end

-- Count existing tabs to position the new one
local tabCount = #tabBar:GetChildren()

-- ── Tab Button ──────────────────────────────────────────────────────────────
local tabBtn = Instance.new("TextButton")
tabBtn.Name            = "TabFloors"
tabBtn.Size            = UDim2.new(0.2, 0, 1, 0)
tabBtn.Position        = UDim2.new(tabCount * 0.2, 0, 0, 0)
tabBtn.BackgroundColor3= Color3.fromRGB(62, 37, 17)
tabBtn.TextColor3      = Color3.fromRGB(232, 212, 154)
tabBtn.Font            = Enum.Font.FredokaOne
tabBtn.TextScaled      = true
tabBtn.Text            = "FLOORS"
tabBtn.ZIndex          = 4
tabBtn.Parent          = tabBar

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0.15, 0)
corner1.Parent       = tabBtn

-- ── Floors Page ──────────────────────────────────────────────────────────────
local floorsPage = Instance.new("Frame")
floorsPage.Name                   = "FloorsPage"
floorsPage.Size                   = UDim2.new(1, 0, 1, 0)
floorsPage.BackgroundColor3       = Color3.fromRGB(44, 26, 10)
floorsPage.BackgroundTransparency = 0
floorsPage.Visible                = false
floorsPage.ZIndex                 = 3
floorsPage.Parent                 = pageContainer

local corner2 = Instance.new("UICorner")
corner2.CornerRadius = UDim.new(0.04, 0)
corner2.Parent       = floorsPage

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder        = Enum.SortOrder.LayoutOrder
listLayout.Padding          = UDim.new(0.02, 0)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Parent            = floorsPage

local padding = Instance.new("UIPadding")
padding.PaddingTop    = UDim.new(0.03, 0)
padding.PaddingBottom = UDim.new(0.03, 0)
padding.PaddingLeft   = UDim.new(0.04, 0)
padding.PaddingRight  = UDim.new(0.04, 0)
padding.Parent        = floorsPage

-- ── Helper: create a floor unlock card ──────────────────────────────────────
local function makeFloorCard(floorNum, labelText)
    local card = Instance.new("Frame")
    card.Name                   = "FloorCard_" .. floorNum
    card.Size                   = UDim2.new(1, 0, 0.42, 0)
    card.BackgroundColor3       = Color3.fromRGB(62, 37, 17)
    card.BackgroundTransparency = 0
    card.LayoutOrder             = floorNum
    card.ZIndex                  = 4
    card.Parent                  = floorsPage

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0.06, 0)
    cardCorner.Parent       = card

    local title = Instance.new("TextLabel")
    title.Name               = "Title"
    title.Size               = UDim2.new(1, 0, 0.22, 0)
    title.Position           = UDim2.new(0, 0, 0.02, 0)
    title.BackgroundTransparency= 1
    title.Font               = Enum.Font.FredokaOne
    title.TextScaled         = true
    title.TextColor3         = Color3.fromRGB(242, 168, 28)
    title.Text               = labelText
    title.ZIndex             = 5
    title.Parent             = card

    -- Three requirement rows (cells / honey / queen)
    local rowNames = {"RowCells", "RowHoney", "RowQueen"}
    local rowY     = {0.27, 0.52, 0.77}

    for i, rowName in rowNames do
        local row = Instance.new("Frame")
        row.Name                   = rowName
        row.Size                   = UDim2.new(0.92, 0, 0.18, 0)
        row.Position               = UDim2.new(0.04, 0, rowY[i], 0)
        row.BackgroundColor3       = Color3.fromRGB(30, 18, 7)
        row.BackgroundTransparency = 0
        row.ZIndex                 = 5
        row.Parent                 = card

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0.4, 0)
        rowCorner.Parent       = row

        local bar = Instance.new("Frame")
        bar.Name                   = "Bar"
        bar.Size                   = UDim2.new(0, 0, 1, 0)
        bar.BackgroundColor3       = Color3.fromRGB(122, 74, 34)
        bar.BackgroundTransparency = 0
        bar.ZIndex                 = 6
        bar.Parent                 = row

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(0.4, 0)
        barCorner.Parent       = bar

        local rowLabel = Instance.new("TextLabel")
        rowLabel.Name               = "Label"
        rowLabel.Size               = UDim2.new(1, 0, 1, 0)
        rowLabel.BackgroundTransparency= 1
        rowLabel.Font               = Enum.Font.Gotham
        rowLabel.TextScaled         = true
        rowLabel.TextColor3         = Color3.fromRGB(232, 212, 154)
        rowLabel.TextXAlignment     = Enum.TextXAlignment.Center
        rowLabel.ZIndex             = 7
        rowLabel.Text               = "..."
        rowLabel.Parent             = row
    end

    -- Unlocked badge (hidden until floor is unlocked)
    local badge = Instance.new("TextLabel")
    badge.Name               = "UnlockedBadge"
    badge.Size               = UDim2.new(0.45, 0, 0.2, 0)
    badge.Position           = UDim2.new(0.275, 0, 0.38, 0)
    badge.BackgroundColor3   = Color3.fromRGB(60, 120, 40)
    badge.BackgroundTransparency= 0
    badge.Visible            = false
    badge.Font               = Enum.Font.FredokaOne
    badge.TextScaled         = true
    badge.TextColor3         = Color3.fromRGB(232, 212, 154)
    badge.Text               = "UNLOCKED"
    badge.ZIndex             = 8
    badge.Parent             = card

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0.3, 0)
    badgeCorner.Parent       = badge

    return card
end

makeFloorCard(2, "FLOOR 2 REQUIREMENTS")
makeFloorCard(3, "FLOOR 3 REQUIREMENTS")

print("STEP C DONE: FLOORS tab and FloorCards created in HiveGui.MainFrame")
```

---

## STEP D — FloorProgressController LocalScript

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP D: Create FloorProgressController LocalScript
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("FloorProgressController")
if old then old:Destroy() end

local lc  = Instance.new("LocalScript")
lc.Name   = "FloorProgressController"
lc.Parent = SPS

lc.Source = [[
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui    = player.PlayerGui:WaitForChild("HiveGui") :: ScreenGui
local main   = gui:WaitForChild("MainFrame")            :: Frame
local tabBar = main:WaitForChild("TabBar")              :: Frame
local pages  = main:WaitForChild("PageContainer")       :: Frame

-- Tab switching (mirrors existing HiveController pattern — adds FLOORS to the tab list)
local TAB_NAMES = { "TabBuild", "TabShop", "TabQueen", "TabWardrobe", "TabFloors" }
local PAGE_NAMES= { "BuildPage","ShopPage","QueenPage","WardrobePage","FloorsPage" }

local function switchTab(targetIdx: number)
    for i, pageName in PAGE_NAMES do
        local page = pages:FindFirstChild(pageName)
        if page then page.Visible = (i == targetIdx) end
    end
    for i, tabName in TAB_NAMES do
        local tab = tabBar:FindFirstChild(tabName)
        if tab and tab:IsA("TextButton") then
            tab.BackgroundColor3 = (i == targetIdx)
                and Color3.fromRGB(122, 74, 34)
                or  Color3.fromRGB(62, 37, 17)
        end
    end
end

local tabFloors = tabBar:FindFirstChild("TabFloors") :: TextButton?
if tabFloors then
    tabFloors.Activated:Connect(function()
        switchTab(5)
    end)
end

-- Requirement definitions (mirrors Config.FLOOR_REQUIREMENTS — hardcoded here to avoid
-- a shared module dependency in a LocalScript; keep in sync with Config if values change)
local REQS = {
    [2] = {
        { key = "RowCells", label = "Cells on Floor 1: %d / 12",  value = 0, goal = 12  },
        { key = "RowHoney", label = "Honey spent: %dk / 5k",       value = 0, goal = 5000, isK = true },
        { key = "RowQueen", label = "Queen Tier: %d / 2",          value = 0, goal = 2   },
    },
    [3] = {
        { key = "RowCells", label = "Cells on Floor 2: %d / 6",   value = 0, goal = 6   },
        { key = "RowHoney", label = "Honey spent: %dk / 25k",      value = 0, goal = 25000, isK = true },
        { key = "RowQueen", label = "Queen Tier: %d / 4",          value = 0, goal = 4   },
    },
}

local floorsPage = pages:FindFirstChild("FloorsPage") :: Frame?

local function formatK(v: number): string
    return v >= 1000 and (math.floor(v / 100) / 10) .. "k" or tostring(v)
end

local function updateFloorCard(
    floorNum:     number,
    floorUnlocked:number,
    cellsBuilt:   number,
    honeySpent:   number,
    queenTier:    number
): ()
    if not floorsPage then return end
    local card = floorsPage:FindFirstChild("FloorCard_" .. floorNum) :: Frame?
    if not card then return end

    local isUnlocked = floorUnlocked >= floorNum
    local badge = card:FindFirstChild("UnlockedBadge") :: TextLabel?
    if badge then badge.Visible = isUnlocked end

    -- Values keyed by row
    local values = {
        RowCells = cellsBuilt,
        RowHoney = honeySpent,
        RowQueen = queenTier,
    }

    for _, req in REQS[floorNum] do
        local row = card:FindFirstChild(req.key) :: Frame?
        if not row then continue end
        local bar   = row:FindFirstChild("Bar")   :: Frame?
        local label = row:FindFirstChild("Label") :: TextLabel?
        local val   = values[req.key] or 0
        local frac  = math.clamp(val / req.goal, 0, 1)

        if bar then
            TweenService:Create(bar, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
                Size = UDim2.new(frac, 0, 1, 0)
            }):Play()
            bar.BackgroundColor3 = frac >= 1
                and Color3.fromRGB(60, 120, 40)
                or  Color3.fromRGB(122, 74, 34)
        end

        if label then
            if req.isK then
                label.Text = string.format(req.label, formatK(val))
            else
                label.Text = string.format(req.label, val)
            end
        end
    end
end

-- Listen on HudDataSync
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local hudSync = remotes:WaitForChild("HudDataSync") :: RemoteEvent

hudSync.OnClientEvent:Connect(function(data: {[string]: any})
    local floorUnlocked = (data.floorUnlocked or 1) :: number
    local cellsBuilt    = (data.cellsBuilt    or 0) :: number
    local honeySpent    = (data.honeySpent    or 0) :: number
    local queenTier     = (data.queenTier     or 1) :: number

    updateFloorCard(2, floorUnlocked, cellsBuilt, honeySpent, queenTier)
    updateFloorCard(3, floorUnlocked, cellsBuilt, honeySpent, queenTier)
end)
]]

print("STEP D DONE: FloorProgressController LocalScript created in StarterPlayerScripts")
```

---

## STEP E — Verification

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP E: Verify FloorProgressGui
local SG  = game:GetService("StarterGui")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. Config.FLOOR_REQUIREMENTS
local Config = require(RS.Modules.Config)
if Config.FLOOR_REQUIREMENTS then
    local f2 = Config.FLOOR_REQUIREMENTS[2]
    local f3 = Config.FLOOR_REQUIREMENTS[3]
    if f2 and f3 then
        table.insert(results, "PASS: Config.FLOOR_REQUIREMENTS[2] and [3] present")
        table.insert(results, "  Floor2: cellsOnFloor1=" .. tostring(f2.cellsOnFloor1) ..
                               " honeySpent=" .. tostring(f2.totalHoneySpent) ..
                               " queenTierMin=" .. tostring(f2.queenTierMin))
        table.insert(results, "  Floor3: cellsOnFloor2=" .. tostring(f3.cellsOnFloor2) ..
                               " honeySpent=" .. tostring(f3.totalHoneySpent) ..
                               " queenTierMin=" .. tostring(f3.queenTierMin))
    else
        table.insert(issues, "FAIL: Config.FLOOR_REQUIREMENTS[2] or [3] nil")
    end
else
    table.insert(issues, "FAIL: Config.FLOOR_REQUIREMENTS missing")
end

-- 2. HiveGui FLOORS tab
local hgui    = SG:FindFirstChild("HiveGui")
local main    = hgui and hgui:FindFirstChild("MainFrame")
local tabBar  = main  and main:FindFirstChild("TabBar")
local pages   = main  and main:FindFirstChild("PageContainer")
local tabBtn  = tabBar and tabBar:FindFirstChild("TabFloors")
local floPage = pages and pages:FindFirstChild("FloorsPage")

if tabBtn  then table.insert(results, "PASS: TabFloors button in TabBar") else table.insert(issues, "FAIL: TabFloors missing") end
if floPage then table.insert(results, "PASS: FloorsPage in PageContainer") else table.insert(issues, "FAIL: FloorsPage missing") end

if floPage then
    for _, floorNum in {2, 3} do
        local card = floPage:FindFirstChild("FloorCard_" .. floorNum)
        if card then
            local hasRows = card:FindFirstChild("RowCells") and
                            card:FindFirstChild("RowHoney") and
                            card:FindFirstChild("RowQueen")
            if hasRows then
                table.insert(results, "PASS: FloorCard_" .. floorNum .. " has all 3 requirement rows")
            else
                table.insert(issues, "FAIL: FloorCard_" .. floorNum .. " missing requirement rows")
            end
        else
            table.insert(issues, "FAIL: FloorCard_" .. floorNum .. " missing from FloorsPage")
        end
    end
end

-- 3. FloorProgressController
local ctrl = SPS and SPS:FindFirstChild("FloorProgressController")
if ctrl and ctrl:IsA("LocalScript") then
    local src   = ctrl.Source
    local lines = select(2, src:gsub("\n","\n")) + 1
    local hasStrict  = src:find("--!strict") ~= nil
    local hasSync    = src:find("HudDataSync") ~= nil
    local hasUpdate  = src:find("updateFloorCard") ~= nil
    local hasTween   = src:find("TweenService") ~= nil
    if hasStrict and hasSync and hasUpdate and hasTween then
        table.insert(results, "PASS: FloorProgressController LocalScript (" .. lines .. " lines)")
    else
        table.insert(issues, "FAIL: FloorProgressController missing features")
    end
else
    table.insert(issues, "FAIL: FloorProgressController LocalScript missing")
end

-- Summary
print("=== FLOOR PROGRESS VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\n--- ISSUES ---")
    for _, iss in issues do print(iss) end
    print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
    print("\nSTATUS: ALL CHECKS PASS — floor progress UI ready")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| Config.FLOOR_REQUIREMENTS | Config edit | ReplicatedStorage.Modules.Config |
| HudDataSync payload extension | Script edit | server script that fires HudDataSync |
| FloorsPage + FloorCard_2 + FloorCard_3 | UI frames | StarterGui.HiveGui.MainFrame |
| TabFloors button | TextButton | StarterGui.HiveGui.MainFrame.TabBar |
| FloorProgressController | LocalScript | StarterPlayerScripts |

**UX:** Each floor card shows three progress bars (cells built / honey spent / queen tier), animating smoothly on each HudDataSync update. Bars turn green when a requirement is met. An "UNLOCKED" badge appears on the card once the floor is actually unlocked. All sizing is Scale-based (mobile-safe).

**Part budget:** 0 new world parts → **~4,094 / 5,000** total (unchanged)
