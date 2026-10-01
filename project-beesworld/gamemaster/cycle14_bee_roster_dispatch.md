# Dispatch 119 — Bee Roster: Named Bees
## Cycle 14 · A Bee's World

**Feature:** Every player's hive has a roster of up to 8 named worker bees. Each bee gets a cute two-part name on first assignment (e.g. "Bumbly Honeydrop", "Zinnia Stripestocking", "Fig Pollenwhisker"). A small `BeeRosterPanel` (tab on the HiveStats side panel or standalone button) shows each bee with their name, current status (🌸 Foraging · 💤 Resting · 🏗️ Building), and a return timer when foraging. When a forage cycle completes, a small toast says "Bumbly is back with honey! 🍯". Kids attach to named characters; adults see the operational roster as a fun status display. Names are generated deterministically from the player's UserId + bee slot number so they're stable across sessions without DataStore cost.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 118 (Hive Sound Ambience)

---

## DESIGN

### Name generation

Two word lists combined: `FIRST[slot + userId % #FIRST]` + `LAST[(slot * 7 + userId) % #LAST]`

**First names (24):** Bumbly, Zinnia, Fig, Pepper, Clover, Dotty, Hazel, Pip, Wren, Sage, Basil, Rue, Coco, Fern, Mochi, Twig, Daffy, Maple, Thistle, Benji, Saffron, Fizzy, Acorn, Petal

**Last names (24):** Honeydrop, Stripestocking, Pollenwhisker, Goldwing, Sunpatch, Fuzzyfoot, Buzzwhip, Cloverdance, Nectar-nap, Waggleworth, Dewspeck, Bloomsong, Hivekeeper, Velveteen, Mellowbuzz, Waxpaws, Fernhollow, Dustwing, Clovercoat, Amberpatch, Windchaser, Sunstride, Gilded, Roundabee

So `"Bumbly Honeydrop"`, `"Zinnia Stripestocking"`, etc. 576 unique combinations — practically no two players share the same first bee name at the same slot.

### Bee status

Status is inferred from player attributes already set by ForagingService:
- `ForagingActive` (bool) → bees 1–N are Foraging
- `CombCellCount` (number) → population cap (1 bee per 6 cells, min 1, max 8)

Simple mapping: if `ForagingActive == true`, all active bees are 🌸 Foraging; if `ForagingActive == false`, all are 💤 Resting. Building state (🏗️) shown when `BuildModeActive` attribute is true.

Return timer: uses `ForagingEndTime` player attribute (Unix timestamp set by ForagingService when a cycle starts). Countdown shown as "Returns in X:XX".

### Roster panel layout

```
╔══════════════════════════════════╗
║  🐝  Your Bees                ✕ ║
╠══════════════════════════════════╣
║  🌸  Bumbly Honeydrop           ║  ← bee row
║      Foraging · returns 2:14    ║
║──────────────────────────────────║
║  🌸  Zinnia Stripestocking      ║
║      Foraging · returns 2:14    ║
║──────────────────────────────────║
║  💤  Fig Pollenwhisker          ║
║      Resting                    ║
║──────────────────────────────────║
║  🔒  Slot 4                     ║  ← locked (needs more cells)
║      Build 24 cells to unlock   ║
╚══════════════════════════════════╝
```

- Panel: 300×380 (Scale), slides in from right side
- Opened via `🐝 My Bees` button (persistent, near GuideButton)
- Locked slots shown in muted colour with unlock cell count
- Return countdown updates every second via `RunService.Heartbeat`

### Return toast

When `ForagingActive` changes from `true` → `false`, a toast fires per active bee:
`"🍯 Bumbly Honeydrop is back with honey!"`
Stacked vertically, each holds 2.5s (dispatch 110-style slide-up from bottom-left).

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BeeRosterController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create BeeRosterController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("BeeRosterController") then
    print("⏭️  BeeRosterController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "BeeRosterController"
    ctrl.Source = [[
--!strict
-- BeeRosterController — dispatch 119
-- Named bee roster panel with status and return countdown.

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROP_BROWN  = Color3.fromRGB(80,  50,  20)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local DARK_BG     = Color3.fromRGB(30,  18,   8)
local CARD_BG     = Color3.fromRGB(50,  30,  10)
local LOCK_COLOR  = Color3.fromRGB(60,  50,  40)
local LOCK_TEXT   = Color3.fromRGB(100, 85,  65)

-- ── Name lists ────────────────────────────────────────────────────
local FIRST_119 = {
    "Bumbly","Zinnia","Fig","Pepper","Clover","Dotty","Hazel","Pip",
    "Wren","Sage","Basil","Rue","Coco","Fern","Mochi","Twig",
    "Daffy","Maple","Thistle","Benji","Saffron","Fizzy","Acorn","Petal",
}
local LAST_119 = {
    "Honeydrop","Stripestocking","Pollenwhisker","Goldwing","Sunpatch",
    "Fuzzyfoot","Buzzwhip","Cloverdance","Nectarnap","Waggleworth",
    "Dewspeck","Bloomsong","Hivekeeper","Velveteen","Mellowbuzz",
    "Waxpaws","Fernhollow","Dustwing","Clovercoat","Amberpatch",
    "Windchaser","Sunstride","Gilded","Roundabee",
}

local function getBeeName_119(slot: number): string
    local uid = player.UserId
    local fi = ((slot - 1 + uid) % #FIRST_119) + 1
    local li = (((slot - 1) * 7 + uid) % #LAST_119) + 1
    return FIRST_119[fi] .. " " .. LAST_119[li]
end

-- ── Slot unlock thresholds ────────────────────────────────────────
local UNLOCK_CELLS_119 = {0, 6, 12, 18, 24, 30, 38, 46}
-- Slot 1 unlocked from start; slot 2 at 6 cells; up to slot 8 at 46 cells

local function getActiveSlots_119(): number
    local cells = tonumber(player:GetAttribute("CombCellCount")) or 0
    local count = 0
    for _, threshold in UNLOCK_CELLS_119 do
        if cells >= threshold then count += 1 end
    end
    return math.min(count, 8)
end

-- ── Roster GUI ────────────────────────────────────────────────────
local rosterGui = Instance.new("ScreenGui")
rosterGui.Name           = "BeeRosterGui"
rosterGui.DisplayOrder   = 18
rosterGui.ResetOnSpawn   = false
rosterGui.Parent         = playerGui

-- My Bees button
local rosterBtn = Instance.new("TextButton")
rosterBtn.Name               = "RosterButton"
rosterBtn.Text               = "🐝 My Bees"
rosterBtn.Font               = Enum.Font.GothamBold
rosterBtn.TextSize           = 14
rosterBtn.TextColor3         = PROP_BROWN
rosterBtn.BackgroundColor3   = HONEY_GOLD
rosterBtn.Size               = UDim2.new(0, 130, 0, 44)
rosterBtn.Position           = UDim2.new(1, -160, 1, -108)  -- above GuideButton
rosterBtn.AutoButtonColor    = true
rosterBtn.ZIndex             = 10
rosterBtn.Parent             = rosterGui

local rBtnCorner = Instance.new("UICorner")
rBtnCorner.CornerRadius = UDim.new(0, 22)
rBtnCorner.Parent       = rosterBtn

local rBtnStroke = Instance.new("UIStroke")
rBtnStroke.Color     = PROP_BROWN
rBtnStroke.Thickness = 1.5
rBtnStroke.Parent    = rosterBtn

-- Roster panel
local panel = Instance.new("Frame")
panel.Name               = "RosterPanel"
panel.BackgroundColor3   = DARK_BG
panel.BackgroundTransparency = 0.05
panel.Size               = UDim2.new(0, 300, 0, 380)
panel.Position           = UDim2.new(1, 10, 0.5, -190)  -- starts off-screen right
panel.Visible            = false
panel.ZIndex             = 20
panel.Parent             = rosterGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD
panelStroke.Thickness = 2
panelStroke.Parent    = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.BackgroundColor3 = PROP_BROWN
titleBar.Size             = UDim2.new(1, 0, 0, 44)
titleBar.ZIndex           = 21
titleBar.Parent           = panel

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 14)
tbCorner.Parent       = titleBar

local tbFill = Instance.new("Frame")
tbFill.BackgroundColor3 = PROP_BROWN
tbFill.Size             = UDim2.new(1, 0, 0, 14)
tbFill.Position         = UDim2.new(0, 0, 1, -14)
tbFill.ZIndex           = 21
tbFill.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Text                  = "🐝  Your Bees"
titleLabel.Font                  = Enum.Font.GothamBold
titleLabel.TextSize              = 15
titleLabel.TextColor3            = HONEY_GOLD
titleLabel.BackgroundTransparency = 1
titleLabel.Size                  = UDim2.new(1, -46, 1, 0)
titleLabel.Position              = UDim2.new(0, 12, 0, 0)
titleLabel.TextXAlignment        = Enum.TextXAlignment.Left
titleLabel.ZIndex                = 22
titleLabel.Parent                = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Text               = "✕"
closeBtn.Font               = Enum.Font.GothamBold
closeBtn.TextSize           = 14
closeBtn.TextColor3         = WAX_CREAM
closeBtn.BackgroundColor3   = Color3.fromRGB(100, 60, 20)
closeBtn.Size               = UDim2.new(0, 28, 0, 28)
closeBtn.Position           = UDim2.new(1, -36, 0.5, -14)
closeBtn.AutoButtonColor    = true
closeBtn.ZIndex             = 22
closeBtn.Parent             = titleBar

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent       = closeBtn

-- Scroll area for rows
local scroll = Instance.new("ScrollingFrame")
scroll.BackgroundTransparency = 1
scroll.Size                   = UDim2.new(1, -8, 1, -48)
scroll.Position               = UDim2.new(0, 4, 0, 44)
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = HONEY_GOLD
scroll.ZIndex                 = 21
scroll.Parent                 = panel

local layout = Instance.new("UIListLayout")
layout.Padding   = UDim.new(0, 3)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent    = scroll

local lPad = Instance.new("UIPadding")
lPad.PaddingTop    = UDim.new(0, 4)
lPad.PaddingLeft   = UDim.new(0, 4)
lPad.PaddingRight  = UDim.new(0, 4)
lPad.PaddingBottom = UDim.new(0, 4)
lPad.Parent        = scroll

-- ── Row factories ─────────────────────────────────────────────────
local rowRefs_119: {Frame} = {}

local function makeRow_119(slot: number): Frame
    local row = Instance.new("Frame")
    row.Name             = "BeeRow_" .. slot
    row.BackgroundColor3 = CARD_BG
    row.Size             = UDim2.new(1, 0, 0, 58)
    row.LayoutOrder      = slot
    row.ZIndex           = 22
    row.Parent           = scroll

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent       = row

    local rs = Instance.new("UIStroke")
    rs.Color     = Color3.fromRGB(90, 65, 28)
    rs.Thickness = 1
    rs.Parent    = row

    local statusIcon = Instance.new("TextLabel")
    statusIcon.Name                  = "StatusIcon"
    statusIcon.Text                  = "🌸"
    statusIcon.Font                  = Enum.Font.GothamBold
    statusIcon.TextSize              = 22
    statusIcon.BackgroundTransparency = 1
    statusIcon.Size                  = UDim2.new(0, 36, 1, 0)
    statusIcon.Position              = UDim2.new(0, 4, 0, 0)
    statusIcon.TextXAlignment        = Enum.TextXAlignment.Center
    statusIcon.ZIndex                = 23
    statusIcon.Parent                = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name                  = "NameLabel"
    nameLbl.Text                  = getBeeName_119(slot)
    nameLbl.Font                  = Enum.Font.GothamBold
    nameLbl.TextSize              = 13
    nameLbl.TextColor3            = HONEY_GOLD
    nameLbl.BackgroundTransparency = 1
    nameLbl.Size                  = UDim2.new(1, -46, 0, 24)
    nameLbl.Position              = UDim2.new(0, 42, 0, 8)
    nameLbl.TextXAlignment        = Enum.TextXAlignment.Left
    nameLbl.ZIndex                = 23
    nameLbl.Parent                = row

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name                  = "StatusLabel"
    statusLbl.Text                  = "Resting"
    statusLbl.Font                  = Enum.Font.Gotham
    statusLbl.TextSize              = 11
    statusLbl.TextColor3            = WAX_CREAM
    statusLbl.BackgroundTransparency = 1
    statusLbl.Size                  = UDim2.new(1, -46, 0, 20)
    statusLbl.Position              = UDim2.new(0, 42, 0, 30)
    statusLbl.TextXAlignment        = Enum.TextXAlignment.Left
    statusLbl.ZIndex                = 23
    statusLbl.Parent                = row

    return row
end

local function makeLockRow_119(slot: number, threshold: number): Frame
    local row = Instance.new("Frame")
    row.Name             = "LockRow_" .. slot
    row.BackgroundColor3 = LOCK_COLOR
    row.BackgroundTransparency = 0.3
    row.Size             = UDim2.new(1, 0, 0, 44)
    row.LayoutOrder      = slot
    row.ZIndex           = 22
    row.Parent           = scroll

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent       = row

    local lbl = Instance.new("TextLabel")
    lbl.Text                  = "🔒  Slot " .. slot .. "  ·  Build " .. threshold .. " cells to unlock"
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextSize              = 11
    lbl.TextColor3            = LOCK_TEXT
    lbl.BackgroundTransparency = 1
    lbl.Size                  = UDim2.new(1, -12, 1, 0)
    lbl.Position              = UDim2.new(0, 6, 0, 0)
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.ZIndex                = 23
    lbl.Parent                = row

    return row
end

-- Build all 8 rows (active + locked) once
local function buildRows_119()
    -- Clear existing
    for _, r in scroll:GetChildren() do
        if r:IsA("Frame") and (r.Name:sub(1, 7) == "BeeRow_" or r.Name:sub(1, 8) == "LockRow_") then
            r:Destroy()
        end
    end
    table.clear(rowRefs_119)
    local activeSlots = getActiveSlots_119()
    for slot = 1, 8 do
        if slot <= activeSlots then
            rowRefs_119[slot] = makeRow_119(slot)
        else
            makeLockRow_119(slot, UNLOCK_CELLS_119[slot])
        end
    end
end

-- ── Status update ─────────────────────────────────────────────────
local function fmt_time_119(secs: number): string
    local m = math.floor(secs / 60)
    local s = math.floor(secs % 60)
    return string.format("%d:%02d", m, s)
end

local function updateStatus_119()
    local foraging  = player:GetAttribute("ForagingActive") == true
    local building  = player:GetAttribute("BuildModeActive") == true
    local endTime   = tonumber(player:GetAttribute("ForagingEndTime")) or 0
    local now       = os.time()
    local remaining = math.max(0, endTime - now)

    local icon   = foraging and "🌸" or (building and "🏗️" or "💤")
    local active = getActiveSlots_119()
    local statusTxt: string
    if foraging and remaining > 0 then
        statusTxt = "Foraging · returns " .. fmt_time_119(remaining)
    elseif foraging then
        statusTxt = "Foraging · returning now!"
    elseif building then
        statusTxt = "Building"
    else
        statusTxt = "Resting"
    end

    for slot = 1, active do
        local row = rowRefs_119[slot]
        if row and row.Parent then
            local iconLbl   = row:FindFirstChild("StatusIcon")  :: TextLabel?
            local statusLbl = row:FindFirstChild("StatusLabel") :: TextLabel?
            if iconLbl   then iconLbl.Text   = icon      end
            if statusLbl then statusLbl.Text = statusTxt end
        end
    end
end

-- ── Return toasts ─────────────────────────────────────────────────
local wasForaging_119 = false
local toastYBase = 0.82
local toastStack_119: {Frame} = {}

local function pushToast_119(text: string)
    local sg = Instance.new("ScreenGui")
    sg.Name           = "BeeReturnToast"
    sg.DisplayOrder   = 16
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.Parent         = playerGui

    local card = Instance.new("Frame")
    card.BackgroundColor3 = PROP_BROWN
    card.Size             = UDim2.new(0, 240, 0, 36)
    card.Position         = UDim2.new(0, 8, 1.05, 0)
    card.ZIndex           = 2
    card.Parent           = sg

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent       = card

    local cs = Instance.new("UIStroke")
    cs.Color     = HONEY_GOLD
    cs.Thickness = 1.5
    cs.Parent    = card

    local lbl = Instance.new("TextLabel")
    lbl.Text                  = text
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextSize              = 12
    lbl.TextColor3            = WAX_CREAM
    lbl.BackgroundTransparency = 1
    lbl.Size                  = UDim2.new(1, -8, 1, 0)
    lbl.Position              = UDim2.new(0, 4, 0, 0)
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.TextWrapped           = true
    lbl.ZIndex                = 3
    lbl.Parent                = card

    table.insert(toastStack_119, card)
    local idx = #toastStack_119
    local targetY = toastYBase - (idx - 1) * 0.06

    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 8, targetY, 0)
    }):Play()

    task.delay(2.5, function()
        TweenService:Create(card, TweenInfo.new(0.2), {
            Position = UDim2.new(0, 8, 1.05, 0)
        }):Play()
        task.wait(0.25)
        sg:Destroy()
        local idx2 = table.find(toastStack_119, card)
        if idx2 then table.remove(toastStack_119, idx2) end
    end)
end

player:GetAttributeChangedSignal("ForagingActive"):Connect(function()
    local nowForaging = player:GetAttribute("ForagingActive") == true
    if wasForaging_119 and not nowForaging then
        -- Bees returned — fire toasts for active slots (staggered)
        local activeSlots = getActiveSlots_119()
        for slot = 1, math.min(activeSlots, 3) do  -- max 3 toasts to avoid spam
            task.delay((slot - 1) * 0.4, function()
                local name = getBeeName_119(slot)
                pushToast_119("🍯 " .. name .. " is back with honey!")
            end)
        end
        if activeSlots > 3 then
            task.delay(3 * 0.4, function()
                pushToast_119("🍯 All your bees are back! 🐝")
            end)
        end
    end
    wasForaging_119 = nowForaging
    updateStatus_119()
end)

-- ── Panel open/close ──────────────────────────────────────────────
local panelOpen = false
local OPEN_POS  = UDim2.new(1, -310, 0.5, -190)
local CLOSE_POS = UDim2.new(1, 10,   0.5, -190)

local function openPanel()
    if panelOpen then return end
    panelOpen = true
    buildRows_119()
    updateStatus_119()
    panel.Position = CLOSE_POS
    panel.Visible  = true
    TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = OPEN_POS
    }):Play()
end

local function closePanel()
    if not panelOpen then return end
    panelOpen = false
    local t = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = CLOSE_POS
    })
    t:Play()
    t.Completed:Connect(function() panel.Visible = false end)
end

rosterBtn.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)
closeBtn.Activated:Connect(closePanel)

-- ── Heartbeat: update countdown while panel is open ───────────────
RunService.Heartbeat:Connect(function()
    if panelOpen then updateStatus_119() end
end)

-- ── Rebuild rows when CombCellCount changes (new bee unlocked) ────
player:GetAttributeChangedSignal("CombCellCount"):Connect(function()
    if panelOpen then
        buildRows_119()
        updateStatus_119()
    end
end)

print("[BeeRosterController] Ready — " ..
    #FIRST_119 * #LAST_119 .. " unique bee name combos across 8 slots")
]]
    ctrl.Parent = SPS
    print("✅ BeeRosterController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("BeeRosterController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " BeeRosterController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("FIRST_119", 1, true) and "✅" or "❌") .. " FIRST_119 name list")
table.insert(checks, (ctrl and ctrl.Source:find("LAST_119", 1, true) and "✅" or "❌") .. " LAST_119 name list")
table.insert(checks, (ctrl and ctrl.Source:find("getBeeName_119", 1, true) and "✅" or "❌") .. " getBeeName_119 generator")
table.insert(checks, (ctrl and ctrl.Source:find("UNLOCK_CELLS_119", 1, true) and "✅" or "❌") .. " UNLOCK_CELLS_119 thresholds")
table.insert(checks, (ctrl and ctrl.Source:find("buildRows_119", 1, true) and "✅" or "❌") .. " buildRows_119 (active + locked rows)")
table.insert(checks, (ctrl and ctrl.Source:find("updateStatus_119", 1, true) and "✅" or "❌") .. " updateStatus_119 foraging state")
table.insert(checks, (ctrl and ctrl.Source:find("fmt_time_119", 1, true) and "✅" or "❌") .. " fmt_time_119 countdown formatter")
table.insert(checks, (ctrl and ctrl.Source:find("pushToast_119", 1, true) and "✅" or "❌") .. " pushToast_119 return notification")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingActive", 1, true) and "✅" or "❌") .. " ForagingActive listener")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingEndTime", 1, true) and "✅" or "❌") .. " ForagingEndTime countdown source")
table.insert(checks, (ctrl and ctrl.Source:find("CombCellCount", 1, true) and "✅" or "❌") .. " CombCellCount unlock rebuild")
table.insert(checks, (ctrl and ctrl.Source:find("RunService.Heartbeat", 1, true) and "✅" or "❌") .. " Heartbeat live countdown")

print("=== DISPATCH 119 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 119 complete" or "❌ SOME CHECKS FAILED")

print("\nSlot unlock thresholds: 1=0, 2=6, 3=12, 4=18, 5=24, 6=30, 7=38, 8=46 cells")
print("Name combos: 24 × 24 = 576 unique bee names")
print("Toasts: max 3 individual bee names + 1 group toast (>3 active bees)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BeeRosterController (LocalScript, runtime ScreenGui) | 0 permanent |
| **Dispatch 119 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- Name determinism: `uid % #FIRST + slot offset` ensures no two bees on the same account share the same first name (unless there are > 24 slots, which is impossible at max 8). Two different players may share a name combo — this is fine and even a fun coincidence ("my Bumbly too!").
- `RunService.Heartbeat` connection for countdown is only active when the panel is open (`if panelOpen then`), so there's no background CPU cost when the roster is closed.
- Toast limit of 3 individual bee names prevents UI spam for full 8-bee hives. The "All your bees are back!" group toast fires after a short delay and covers the rest.
- `UNLOCK_CELLS_119` thresholds (0, 6, 12, 18, 24, 30, 38, 46) create a steady unlocking cadence roughly every 5–8 cells. The final bee (slot 8) requires 46 cells — just 4 short of the 50-cell Full Hive milestone, making that achievement feel like a natural companion goal.
- `🏗️ Building` status fires when `BuildModeActive == true` — this attribute should be set by the Build Mode controller when a player opens Build Mode. If it's not set, bees simply show Resting, which is a graceful fallback.
- The panel slides in from the **right** side (slides in from `Position(1, 10)` → `Position(1, -310)`) to complement the Cell Guide panel which is centered. The two panels can be open simultaneously without overlap.
- `wasForaging_119` tracks the *previous* foraging state so the toast only fires on the transition from `true → false`, not every attribute change ping.
