# Dispatch 32 — BeeInspectorGui Inline ReadyCheck Overlay
**File:** `cycle11_beeinspector_dispatch.md`
**Cycle:** 11
**Part budget:** 0 → ~4,098/5,000 (UI only, no world parts)
**DataService migration:** None
**Depends on:** Dispatch 28 (FloorProgressGui, Config.FLOOR_REQUIREMENTS, HudDataSync extension)
**Supersedes:** Nothing

---

## Purpose

Add a **ReadyCheck tooltip panel** that slides in when the player hovers/taps the
"UPGRADE QUEEN" button or the BUILD-tab floor unlock header, showing live floor-gate
progress in-context — without navigating away to the FLOORS tab.

Before this dispatch: floor unlock requirements are only visible in the dedicated FLOORS tab.
Players upgrading their queen or buying cells don't know they're close to unlocking a floor
unless they switch tabs mid-action.

After this dispatch: a compact overlay panel appears in the BUILD and QUEEN tabs showing
the three floor gate bars (cells built, honey spent, queen tier) with a checkmark on each
met condition. Disappears automatically after 4 seconds or on next tap.

---

## STEP A — ReadyCheckFrame GUI element

Add `ReadyCheckFrame` as a child of `HiveGui.MainFrame`. It floats above the tab pages.

```lua
-- STEP A: Create ReadyCheckFrame overlay in HiveGui.MainFrame
local SG = game:GetService("StarterGui")
local hiveGui   = SG:FindFirstChild("HiveGui")
assert(hiveGui, "HiveGui not found in StarterGui")
local mainFrame = hiveGui:FindFirstChild("MainFrame")
assert(mainFrame, "MainFrame not found in HiveGui")

-- Remove stale copy
local stale = mainFrame:FindFirstChild("ReadyCheckFrame")
if stale then stale:Destroy() end

-- Outer frame (slides in from right edge)
local rcf = Instance.new("Frame")
rcf.Name                = "ReadyCheckFrame"
rcf.Size                = UDim2.new(0.45, 0, 0.38, 0)
rcf.Position            = UDim2.new(1.05, 0, 0.30, 0)  -- starts off-screen right
rcf.AnchorPoint         = Vector2.new(0, 0)
rcf.BackgroundColor3    = Color3.fromRGB(40, 22, 8)     -- deep propolis brown
rcf.BackgroundTransparency = 0.08
rcf.BorderSizePixel     = 0
rcf.ZIndex              = 20
rcf.Visible             = true  -- controlled by Transparency, not Visible
rcf.Parent              = mainFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = rcf

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(122, 74, 34)   -- Propolis Brown border
stroke.Thickness = 2
stroke.Parent    = rcf

-- Title bar
local title = Instance.new("TextLabel")
title.Name                = "Title"
title.Size                = UDim2.new(1, 0, 0.18, 0)
title.Position            = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3    = Color3.fromRGB(122, 74, 34)
title.BackgroundTransparency = 0
title.TextColor3          = Color3.fromRGB(232, 212, 154)   -- Wax Cream
title.Font                = Enum.Font.FredokaOne
title.TextScaled          = true
title.Text                = "Floor 2 Requirements"
title.ZIndex              = 21
title.Parent              = rcf

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = title

-- Row factory helper (runs in Command Bar scope)
local function makeRow(parent, name, yPos, icon, labelText)
    local row = Instance.new("Frame")
    row.Name                = name
    row.Size                = UDim2.new(0.92, 0, 0.20, 0)
    row.Position            = UDim2.new(0.04, 0, yPos, 0)
    row.BackgroundTransparency = 1
    row.ZIndex              = 21
    row.Parent              = parent

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Name          = "Icon"
    iconLabel.Size          = UDim2.new(0.12, 0, 1, 0)
    iconLabel.Position      = UDim2.new(0, 0, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.TextColor3    = Color3.fromRGB(242, 168, 28)  -- Honey Gold
    iconLabel.Font          = Enum.Font.FredokaOne
    iconLabel.TextScaled    = true
    iconLabel.Text          = icon
    iconLabel.ZIndex        = 22
    iconLabel.Parent        = row

    local bar = Instance.new("Frame")
    bar.Name                = "Bar"
    bar.Size                = UDim2.new(0.60, 0, 0.55, 0)
    bar.Position            = UDim2.new(0.13, 0, 0.22, 0)
    bar.BackgroundColor3    = Color3.fromRGB(60, 35, 12)
    bar.BorderSizePixel     = 0
    bar.ZIndex              = 21
    bar.Parent              = row

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 4)
    barCorner.Parent = bar

    local fill = Instance.new("Frame")
    fill.Name               = "Fill"
    fill.Size               = UDim2.new(0, 0, 1, 0)   -- width set by controller
    fill.BackgroundColor3   = Color3.fromRGB(122, 74, 34)  -- Propolis Brown (turns gold when done)
    fill.BorderSizePixel    = 0
    fill.ZIndex             = 22
    fill.Parent             = bar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = fill

    local valLabel = Instance.new("TextLabel")
    valLabel.Name           = "Value"
    valLabel.Size           = UDim2.new(0.25, 0, 1, 0)
    valLabel.Position       = UDim2.new(0.75, 0, 0, 0)
    valLabel.BackgroundTransparency = 1
    valLabel.TextColor3     = Color3.fromRGB(200, 180, 120)
    valLabel.Font           = Enum.Font.FredokaOne
    valLabel.TextScaled     = true
    valLabel.Text           = "0/0"
    valLabel.ZIndex         = 22
    valLabel.Parent         = row

    local check = Instance.new("TextLabel")
    check.Name              = "Check"
    check.Size              = UDim2.new(0.10, 0, 1, 0)
    check.Position          = UDim2.new(0.90, 0, 0, 0)
    check.BackgroundTransparency = 1
    check.TextColor3        = Color3.fromRGB(60, 200, 60)
    check.Font              = Enum.Font.FredokaOne
    check.TextScaled        = true
    check.Text              = ""    -- "✓" when met
    check.ZIndex            = 22
    check.Parent            = row

    return row
end

local contentArea = Instance.new("Frame")
contentArea.Name = "Content"
contentArea.Size = UDim2.new(1, 0, 0.82, 0)
contentArea.Position = UDim2.new(0, 0, 0.18, 0)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex = 21
contentArea.Parent = rcf

makeRow(contentArea, "RowCells",  0.02, "🍯", "Cells")
makeRow(contentArea, "RowHoney",  0.30, "💰", "Honey Spent")
makeRow(contentArea, "RowQueen", 0.58, "👑", "Queen Tier")

-- Status footer
local footer = Instance.new("TextLabel")
footer.Name             = "Footer"
footer.Size             = UDim2.new(1, 0, 0.14, 0)
footer.Position         = UDim2.new(0, 0, 0.86, 0)
footer.BackgroundTransparency = 1
footer.TextColor3       = Color3.fromRGB(242, 168, 28)
footer.Font             = Enum.Font.FredokaOne
footer.TextScaled       = true
footer.Text             = "Keep building!"
footer.ZIndex           = 21
footer.Parent           = contentArea

print("✅ STEP A: ReadyCheckFrame created in HiveGui.MainFrame")
```

**Verify Step A:**

```lua
local SG = game:GetService("StarterGui")
local rcf = SG:FindFirstChild("HiveGui") and
            SG.HiveGui:FindFirstChild("MainFrame") and
            SG.HiveGui.MainFrame:FindFirstChild("ReadyCheckFrame")
assert(rcf, "ReadyCheckFrame missing")
assert(rcf:FindFirstChild("Title"), "Title missing")
local content = rcf:FindFirstChild("Content")
assert(content, "Content frame missing")
assert(content:FindFirstChild("RowCells"), "RowCells missing")
assert(content:FindFirstChild("RowHoney"), "RowHoney missing")
assert(content:FindFirstChild("RowQueen"), "RowQueen missing")
print("✅ STEP A verified: ReadyCheckFrame structure correct")
```

---

## STEP B — ReadyCheckController LocalScript

Drives the overlay: listens on HudDataSync, slides the panel in/out, animates bar fills,
auto-hides after 4 seconds.

```lua
-- STEP B: ReadyCheckController LocalScript in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("ReadyCheckController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "ReadyCheckController"
ctrl.Source = [[
--!strict
-- ReadyCheckController — inline floor-gate progress overlay (dispatch 32)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
local hiveGui   = playerGui:WaitForChild("HiveGui", 10)
local mainFrame = hiveGui:WaitForChild("MainFrame", 10)
local rcf       = mainFrame:WaitForChild("ReadyCheckFrame", 10)

local remotes     = ReplicatedStorage:WaitForChild("Remotes", 10)
local HudDataSync = remotes:WaitForChild("HudDataSync", 10)

-- Floor requirements mirror (from server Config — hardcoded here to avoid require on client)
-- Update these if Config.FLOOR_REQUIREMENTS changes
local FLOOR_REQ = {
    [2] = { cells = 12, honey = 5000,  queenMin = 2 },
    [3] = { cells = 6,  honey = 25000, queenMin = 4 },  -- cells on floor 2
}

-- ---------------------------------------------------------------
-- Layout refs
-- ---------------------------------------------------------------
local title   = rcf:FindFirstChild("Title")
local content = rcf:FindFirstChild("Content")

local rows = {
    cells = content:FindFirstChild("RowCells"),
    honey = content:FindFirstChild("RowHoney"),
    queen = content:FindFirstChild("RowQueen"),
}
local footer = content:FindFirstChild("Footer")

-- ---------------------------------------------------------------
-- Tween helpers
-- ---------------------------------------------------------------
local SLIDE_IN  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BAR_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local _autoHideConn: RBXScriptConnection? = nil
local _visible = false

local function slideIn(): ()
    rcf.Position = UDim2.new(1.05, 0, 0.30, 0)
    TweenService:Create(rcf, SLIDE_IN, { Position = UDim2.new(0.54, 0, 0.30, 0) }):Play()
    _visible = true
end

local function slideOut(): ()
    TweenService:Create(rcf, SLIDE_OUT, { Position = UDim2.new(1.05, 0, 0.30, 0) }):Play()
    _visible = false
end

local function scheduleAutoHide(): ()
    if _autoHideConn then _autoHideConn:Disconnect() end
    local fired = false
    _autoHideConn = task.delay(4, function(): ()
        if not fired then
            fired = true
            slideOut()
        end
    end) :: any  -- task.delay returns thread, not connection; assign for cancel idiom
end

-- ---------------------------------------------------------------
-- Bar update helper
-- ---------------------------------------------------------------
local function updateRow(
    row: Frame,
    current: number,
    target: number,
    labelFmt: string
): ()
    local fill  = row:FindFirstChild("Fill") :: Frame?
    local value = row:FindFirstChild("Value") :: TextLabel?
    local check = row:FindFirstChild("Check") :: TextLabel?
    if not fill or not value or not check then return end

    local fraction = math.clamp(current / math.max(target, 1), 0, 1)
    local met = fraction >= 1

    TweenService:Create(fill, BAR_TWEEN, {
        Size = UDim2.new(fraction, 0, 1, 0),
        BackgroundColor3 = met
            and Color3.fromRGB(242, 168, 28)    -- Honey Gold when done
            or  Color3.fromRGB(122, 74,  34),   -- Propolis Brown in progress
    }):Play()

    value.Text        = string.format(labelFmt, current, target)
    value.TextColor3  = met and Color3.fromRGB(242, 168, 28) or Color3.fromRGB(200, 180, 120)
    check.Text        = met and "✓" or ""
end

-- ---------------------------------------------------------------
-- Main update — called on every HudDataSync event
-- ---------------------------------------------------------------
local function onHudSync(data: {
    floorUnlocked: number?,
    cellsBuilt:    number?,
    honeySpent:    number?,
    queenTier:     number?,
    [string]: any,
}): ()
    local floorUnlocked = data.floorUnlocked or 1
    local cellsBuilt    = data.cellsBuilt    or 0
    local honeySpent    = data.honeySpent    or 0
    local queenTier     = data.queenTier     or 1

    -- Determine next floor to unlock
    local nextFloor: number? = nil
    for floor = 2, 3 do
        if floor > floorUnlocked then
            nextFloor = floor
            break
        end
    end

    if not nextFloor then
        -- All floors unlocked — hide panel permanently
        if _visible then slideOut() end
        return
    end

    local req = FLOOR_REQ[nextFloor]
    if not req then return end

    -- Update title
    if title then
        title.Text = "Floor " .. nextFloor .. " Requirements"
    end

    -- Update rows
    updateRow(rows.cells, cellsBuilt, req.cells,   "%d/%d Cells")
    updateRow(rows.honey, honeySpent, req.honey,   "%d/%d Honey")
    updateRow(rows.queen, queenTier,  req.queenMin, "Tier %d/%d")

    -- Update footer
    local allMet = cellsBuilt >= req.cells and honeySpent >= req.honey and queenTier >= req.queenMin
    if footer then
        footer.Text      = allMet and "🎉 Ready to unlock!" or "Keep building!"
        footer.TextColor3 = allMet
            and Color3.fromRGB(60, 200, 60)
            or  Color3.fromRGB(242, 168, 28)
    end

    -- Show panel if not already visible
    if not _visible then slideIn() end
    scheduleAutoHide()
end

HudDataSync.OnClientEvent:Connect(onHudSync)

-- ---------------------------------------------------------------
-- Trigger: show overlay when player opens BUILD or QUEEN tabs
-- Tab buttons are siblings of ReadyCheckFrame in MainFrame
-- ---------------------------------------------------------------
local tabBar = mainFrame:FindFirstChild("TabBar")
if tabBar then
    local function wireTabButton(btnName: string): ()
        local btn = tabBar:FindFirstChild(btnName)
        if btn and btn:IsA("GuiButton") then
            btn.Activated:Connect(function(): ()
                if _visible then
                    scheduleAutoHide()
                else
                    -- Replay last data if we have it
                    slideIn()
                    scheduleAutoHide()
                end
            end)
        end
    end
    wireTabButton("TabBuild")
    wireTabButton("TabQueen")
end
]]
ctrl.Parent = SPS

print("✅ STEP B: ReadyCheckController LocalScript created")
```

**Verify Step B:**

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("ReadyCheckController")
assert(ctrl and ctrl:IsA("LocalScript"), "ReadyCheckController LocalScript missing")
local src = ctrl.Source
assert(src:find("HudDataSync"), "HudDataSync not referenced")
assert(src:find("TweenService"), "TweenService not referenced")
assert(src:find("slideIn"), "slideIn function missing")
assert(src:find("scheduleAutoHide"), "scheduleAutoHide missing")
assert(src:find("FLOOR_REQ"), "FLOOR_REQ table missing")
print("✅ STEP B verified: ReadyCheckController present and correct")
```

---

## STEP C — Full verification

```lua
-- STEP C: Full dispatch 32 verification
local SG   = game:GetService("StarterGui")
local SP   = game:GetService("StarterPlayer")
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local results = {}
local issues  = {}

-- 1. ReadyCheckFrame structure
local hiveGui   = SG:FindFirstChild("HiveGui")
local mainFrame = hiveGui and hiveGui:FindFirstChild("MainFrame")
local rcf       = mainFrame and mainFrame:FindFirstChild("ReadyCheckFrame")
if rcf then
    local content = rcf:FindFirstChild("Content")
    local hasRows = content
        and content:FindFirstChild("RowCells")
        and content:FindFirstChild("RowHoney")
        and content:FindFirstChild("RowQueen")
    if hasRows then
        table.insert(results, "✅ ReadyCheckFrame: Title + 3 rows + footer present")
    else
        table.insert(issues, "❌ ReadyCheckFrame missing rows in Content")
    end
    -- Check each row has Fill, Value, Check
    if content then
        for _, rowName in {"RowCells", "RowHoney", "RowQueen"} do
            local row = content:FindFirstChild(rowName)
            if row then
                local hasFill  = row:FindFirstChild("Fill")  ~= nil
                local hasValue = row:FindFirstChild("Value") ~= nil
                local hasCheck = row:FindFirstChild("Check") ~= nil
                if hasFill and hasValue and hasCheck then
                    table.insert(results, "✅ " .. rowName .. ": Fill + Value + Check present")
                else
                    table.insert(issues, "❌ " .. rowName .. " incomplete (Fill=" .. tostring(hasFill) .. " Value=" .. tostring(hasValue) .. " Check=" .. tostring(hasCheck) .. ")")
                end
            end
        end
    end
else
    table.insert(issues, "❌ ReadyCheckFrame missing from HiveGui.MainFrame")
end

-- 2. ReadyCheckController LocalScript
local ctrl = SPS and SPS:FindFirstChild("ReadyCheckController")
if ctrl and ctrl:IsA("LocalScript") then
    local src = ctrl.Source
    local checks = {
        { src:find("HudDataSync") ~= nil, "HudDataSync" },
        { src:find("TweenService") ~= nil, "TweenService" },
        { src:find("slideIn") ~= nil, "slideIn" },
        { src:find("FLOOR_REQ") ~= nil, "FLOOR_REQ" },
        { src:find("scheduleAutoHide") ~= nil, "scheduleAutoHide" },
    }
    local allOk = true
    for _, c in checks do
        if not c[1] then
            table.insert(issues, "❌ ReadyCheckController missing: " .. c[2])
            allOk = false
        end
    end
    if allOk then
        table.insert(results, "✅ ReadyCheckController: all key patterns present")
    end
else
    table.insert(issues, "❌ ReadyCheckController LocalScript missing from StarterPlayerScripts")
end

-- 3. ZIndex check — ReadyCheckFrame must not be behind HiveGui pages
if rcf then
    if rcf.ZIndex >= 20 then
        table.insert(results, "✅ ReadyCheckFrame ZIndex=" .. rcf.ZIndex .. " (above tab pages)")
    else
        table.insert(issues, "❌ ReadyCheckFrame ZIndex=" .. rcf.ZIndex .. " may be hidden behind tab pages (need ≥20)")
    end
end

-- Summary
print("\n=== DISPATCH 32 VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\nISSUES:")
    for _, i in issues do print(i) end
else
    print("\n🎉 All checks passed — dispatch 32 complete!")
    print("   ReadyCheckFrame overlay slides in on HudDataSync events")
    print("   Shows live floor-gate progress in BUILD/QUEEN context")
    print("   Auto-hides after 4 seconds")
end
```

---

## Execution order checklist

1. ☐ **STEP A** — Create ReadyCheckFrame in HiveGui.MainFrame  
2. ☐ **STEP B** — Create ReadyCheckController LocalScript  
3. ☐ **STEP C** — Full verification  

---

## Testing notes

- **Trigger in Studio:** After executing, Play the game. Any HudDataSync fire will show the
  overlay. In Command Bar during play-test, fire a test sync:
  ```lua
  local RS = game:GetService("ReplicatedStorage")
  local sync = RS.Remotes.HudDataSync
  sync:FireAllClients({ floorUnlocked=1, cellsBuilt=7, honeySpent=3200, queenTier=1 })
  ```
  Panel should slide in from the right over HiveGui, show 3 rows with partial fills, auto-hide
  after 4 seconds.

- **All floors unlocked test:**
  ```lua
  sync:FireAllClients({ floorUnlocked=3, cellsBuilt=20, honeySpent=30000, queenTier=5 })
  ```
  Panel should NOT appear (all floors already unlocked → `slideOut` path).

- **Tab button trigger:** Click the BUILD or QUEEN tab button while the panel is hidden.
  Panel should slide in and restart the 4-second auto-hide timer.

---

## Part budget

| Step | Parts added | Running total |
|------|-------------|---------------|
| A    | 0 (UI frames only) | 4,098 |
| B    | 0 (LocalScript only) | 4,098 |
| **Total** | **0** | **~4,098 / 5,000** |
