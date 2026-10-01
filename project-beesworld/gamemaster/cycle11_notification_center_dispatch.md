# Dispatch 39 — NotificationCenterGui: Toast History Panel
**Cycle 11 | A Bee's World | Bee-scale tycoon**
**Execution order: after dispatch 38**

---

## OVERVIEW

Adds a persistent notification history panel accessible via a bell icon (🔔) in the HiveGui top bar.
All `Notify` RemoteEvent toasts are silently appended to a scrollable history log (max 20 entries).
The bell badge shows unread count (up to 99+). Tapping the bell toggles the panel open/closed.

Entirely client-side — no server scripts, no new RemoteEvents.
Hooks into the existing `Notify` RemoteEvent that all services already fire.

**Part budget**: 0 permanent parts → **~4,142 / 5,000**

---

## STEP A — Add bell button to HiveGui top bar

```lua
-- In Studio Command Bar:
local StarterGui = game:GetService("StarterGui")

local hiveGui = StarterGui:FindFirstChild("HiveGui")
if not hiveGui then error("HiveGui not found in StarterGui") end

local mainFrame = hiveGui:FindFirstChild("MainFrame")
if not mainFrame then error("MainFrame not found in HiveGui") end

-- Top bar container (find existing or create)
local topBar = mainFrame:FindFirstChild("TopBar")
if not topBar then
    topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0.08, 0)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundTransparency = 1
    topBar.BorderSizePixel = 0
    topBar.ZIndex = 5
    topBar.Parent = mainFrame
    print("ℹ️  TopBar created (did not exist)")
end

-- Bell button (top-right of MainFrame, outside TopBar for flexibility)
local bellBtn = Instance.new("TextButton")
bellBtn.Name              = "BellButton"
bellBtn.Size              = UDim2.new(0.10, 0, 0.08, 0)
bellBtn.Position          = UDim2.new(0.88, 0, 0.01, 0)
bellBtn.BackgroundColor3  = Color3.fromRGB(122, 74, 34)   -- Propolis Brown
bellBtn.BackgroundTransparency = 0.2
bellBtn.BorderSizePixel   = 0
bellBtn.Text              = "🔔"
bellBtn.Font              = Enum.Font.FredokaOne
bellBtn.TextScaled        = true
bellBtn.TextColor3        = Color3.fromRGB(232, 212, 154)  -- Wax Cream
bellBtn.ZIndex            = 20
bellBtn.Parent            = mainFrame

local bellCorner = Instance.new("UICorner")
bellCorner.CornerRadius = UDim.new(0, 8)
bellCorner.Parent = bellBtn

local bellStroke = Instance.new("UIStroke")
bellStroke.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold
bellStroke.Thickness = 1.5
bellStroke.Parent    = bellBtn

-- Unread badge (top-right corner of bell button, hidden initially)
local badge = Instance.new("TextLabel")
badge.Name              = "UnreadBadge"
badge.Size              = UDim2.new(0.5, 0, 0.5, 0)
badge.Position          = UDim2.new(0.55, 0, -0.2, 0)
badge.BackgroundColor3  = Color3.fromRGB(200, 50, 50)   -- red
badge.BackgroundTransparency = 0
badge.Text              = "0"
badge.Font              = Enum.Font.FredokaOne
badge.TextScaled        = true
badge.TextColor3        = Color3.fromRGB(255, 255, 255)
badge.ZIndex            = 21
badge.Visible           = false
badge.Parent            = bellBtn

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(1, 0)
badgeCorner.Parent = badge

print("✅ BellButton + UnreadBadge created in HiveGui.MainFrame")
```

---

## STEP B — NotificationCenterPanel (scrollable history)

```lua
-- In Studio Command Bar (run after Step A):
local StarterGui = game:GetService("StarterGui")

local hiveGui   = StarterGui:FindFirstChild("HiveGui")
if not hiveGui then error("HiveGui not found") end
local mainFrame = hiveGui:FindFirstChild("MainFrame")
if not mainFrame then error("MainFrame not found") end

-- Remove old panel if re-running
local oldPanel = mainFrame:FindFirstChild("NotificationPanel")
if oldPanel then oldPanel:Destroy() end

-- Panel (slides in from right, hidden off-screen)
local panel = Instance.new("Frame")
panel.Name              = "NotificationPanel"
panel.Size              = UDim2.new(0.55, 0, 0.75, 0)
panel.Position          = UDim2.new(1.05, 0, 0.12, 0)   -- off-screen right
panel.BackgroundColor3  = Color3.fromRGB(40, 20, 5)      -- deep dark brown
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel   = 0
panel.ZIndex            = 18
panel.Parent            = mainFrame

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold
panelStroke.Thickness = 2
panelStroke.Parent    = panel

-- Header bar
local header = Instance.new("Frame")
header.Name             = "Header"
header.Size             = UDim2.new(1, 0, 0.09, 0)
header.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
header.BackgroundTransparency = 0
header.BorderSizePixel  = 0
header.ZIndex           = 19
header.Parent           = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 14)
headerCorner.Parent = header

local headerLbl = Instance.new("TextLabel")
headerLbl.Name             = "HeaderLabel"
headerLbl.Size             = UDim2.new(0.75, 0, 1, 0)
headerLbl.BackgroundTransparency = 1
headerLbl.Text             = "🔔 Notifications"
headerLbl.Font             = Enum.Font.FredokaOne
headerLbl.TextScaled       = true
headerLbl.TextColor3       = Color3.fromRGB(242, 168, 28)
headerLbl.ZIndex           = 20
headerLbl.Parent           = header

local clearBtn = Instance.new("TextButton")
clearBtn.Name              = "ClearBtn"
clearBtn.Size              = UDim2.new(0.22, 0, 0.75, 0)
clearBtn.Position          = UDim2.new(0.76, 0, 0.125, 0)
clearBtn.BackgroundColor3  = Color3.fromRGB(80, 40, 10)
clearBtn.Text              = "Clear"
clearBtn.Font              = Enum.Font.FredokaOne
clearBtn.TextScaled        = true
clearBtn.TextColor3        = Color3.fromRGB(232, 212, 154)
clearBtn.ZIndex            = 20
clearBtn.Parent            = header

local clearCorner = Instance.new("UICorner")
clearCorner.CornerRadius = UDim.new(0, 6)
clearCorner.Parent = clearBtn

-- Scroll frame for entries
local scroll = Instance.new("ScrollingFrame")
scroll.Name             = "ScrollFrame"
scroll.Size             = UDim2.new(1, 0, 0.91, 0)
scroll.Position         = UDim2.new(0, 0, 0.09, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel  = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(242, 168, 28)
scroll.CanvasSize       = UDim2.new(0, 0, 0, 0)  -- managed by UIListLayout
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex           = 19
scroll.Parent           = panel

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection   = Enum.FillDirection.Vertical
listLayout.SortOrder       = Enum.SortOrder.LayoutOrder
listLayout.Padding         = UDim.new(0, 4)
listLayout.Parent          = scroll

local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingLeft   = UDim.new(0, 6)
scrollPad.PaddingRight  = UDim.new(0, 6)
scrollPad.PaddingTop    = UDim.new(0, 6)
scrollPad.PaddingBottom = UDim.new(0, 6)
scrollPad.Parent        = scroll

-- Empty state label
local emptyLbl = Instance.new("TextLabel")
emptyLbl.Name              = "EmptyLabel"
emptyLbl.Size              = UDim2.new(1, 0, 0, 50)
emptyLbl.BackgroundTransparency = 1
emptyLbl.Text              = "No notifications yet."
emptyLbl.Font              = Enum.Font.FredokaOne
emptyLbl.TextScaled        = true
emptyLbl.TextColor3        = Color3.fromRGB(150, 120, 80)
emptyLbl.ZIndex            = 19
emptyLbl.LayoutOrder       = 99999
emptyLbl.Parent            = scroll

print("✅ NotificationPanel created in HiveGui.MainFrame (off-screen, slides in on bell tap)")
```

---

## STEP C — NotificationCenterController LocalScript

```lua
-- In Studio Command Bar (run after Step B):
local StarterPlayer = game:GetService("StarterPlayer")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not SPS then error("StarterPlayerScripts not found") end

local old = SPS:FindFirstChild("NotificationCenterController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name = "NotificationCenterController"
ctrl.Source = [[
--!strict
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")

local player    = Players.LocalPlayer
local pgui      = player:WaitForChild("PlayerGui")

-- RemoteEvent
local Notify: RemoteEvent = RS:WaitForChild("Remotes"):WaitForChild("Notify") :: RemoteEvent

-- UI references (wait for HiveGui in PlayerGui)
local hiveGui: ScreenGui   = pgui:WaitForChild("HiveGui") :: ScreenGui
local mainFrame: Frame     = hiveGui:WaitForChild("MainFrame") :: Frame
local bellBtn: TextButton  = mainFrame:WaitForChild("BellButton") :: TextButton
local badge: TextLabel     = bellBtn:WaitForChild("UnreadBadge") :: TextLabel
local panel: Frame         = mainFrame:WaitForChild("NotificationPanel") :: Frame
local scroll: ScrollingFrame = panel:WaitForChild("ScrollFrame") :: ScrollingFrame
local clearBtn: TextButton  = panel:WaitForChild("Header"):WaitForChild("ClearBtn") :: TextButton
local emptyLbl: TextLabel   = scroll:WaitForChild("EmptyLabel") :: TextLabel

-- State
local MAX_ENTRIES = 20
local _unreadCount = 0
local _isOpen      = false
local _entries: { { title: string, message: string, timestamp: number } } = {}

-- Tween constants
local SLIDE_IN  = TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local PROPOLIS    = Color3.fromRGB(122,  74, 34)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local ENTRY_BG    = Color3.fromRGB(60, 30, 8)

local function fmtTime(ts: number): string
    local delta = os.time() - ts
    if delta < 60 then return "just now"
    elseif delta < 3600 then return math.floor(delta / 60) .. "m ago"
    else return math.floor(delta / 3600) .. "h ago"
    end
end

local function updateBadge()
    if _unreadCount <= 0 then
        badge.Visible = false
        badge.Text = "0"
    else
        badge.Visible = true
        badge.Text = _unreadCount > 99 and "99+" or tostring(_unreadCount)
    end
end

local function buildEntryFrame(entry: { title: string, message: string, timestamp: number }, order: number): Frame
    local f = Instance.new("Frame")
    f.Name              = "Entry_" .. order
    f.Size              = UDim2.new(1, 0, 0, 56)
    f.BackgroundColor3  = ENTRY_BG
    f.BackgroundTransparency = 0.1
    f.BorderSizePixel   = 0
    f.LayoutOrder       = order
    f.ZIndex            = 20

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 8)
    fc.Parent = f

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name              = "Title"
    titleLbl.Size              = UDim2.new(0.80, 0, 0.50, 0)
    titleLbl.Position          = UDim2.new(0.02, 0, 0.04, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text              = entry.title
    titleLbl.Font              = Enum.Font.FredokaOne
    titleLbl.TextScaled        = true
    titleLbl.TextColor3        = HONEY_GOLD
    titleLbl.TextXAlignment    = Enum.TextXAlignment.Left
    titleLbl.ZIndex            = 21
    titleLbl.Parent            = f

    local msgLbl = Instance.new("TextLabel")
    msgLbl.Name              = "Message"
    msgLbl.Size              = UDim2.new(0.96, 0, 0.44, 0)
    msgLbl.Position          = UDim2.new(0.02, 0, 0.52, 0)
    msgLbl.BackgroundTransparency = 1
    msgLbl.Text              = entry.message
    msgLbl.Font              = Enum.Font.FredokaOne
    msgLbl.TextScaled        = true
    msgLbl.TextColor3        = WAX_CREAM
    msgLbl.TextXAlignment    = Enum.TextXAlignment.Left
    msgLbl.TextWrapped       = true
    msgLbl.ZIndex            = 21
    msgLbl.Parent            = f

    local timeLbl = Instance.new("TextLabel")
    timeLbl.Name              = "Timestamp"
    timeLbl.Size              = UDim2.new(0.18, 0, 0.40, 0)
    timeLbl.Position          = UDim2.new(0.80, 0, 0.06, 0)
    timeLbl.BackgroundTransparency = 1
    timeLbl.Text              = fmtTime(entry.timestamp)
    timeLbl.Font              = Enum.Font.FredokaOne
    timeLbl.TextScaled        = true
    timeLbl.TextColor3        = Color3.fromRGB(180, 140, 80)
    timeLbl.TextXAlignment    = Enum.TextXAlignment.Right
    timeLbl.ZIndex            = 21
    timeLbl.Parent            = f

    return f
end

local function rebuildScrollList()
    -- Clear existing entry frames (keep emptyLbl)
    for _, child in scroll:GetChildren() do
        if child:IsA("Frame") and child.Name:find("^Entry_") then
            child:Destroy()
        end
    end
    -- Newest first (reverse order)
    local n = #_entries
    for i = n, 1, -1 do
        local frame = buildEntryFrame(_entries[i], n - i + 1)
        frame.Parent = scroll
    end
    emptyLbl.Visible = n == 0
end

local function addEntry(title: string, message: string)
    table.insert(_entries, { title = title, message = message, timestamp = os.time() })
    -- Trim to max
    while #_entries > MAX_ENTRIES do
        table.remove(_entries, 1)
    end
    if not _isOpen then
        _unreadCount = _unreadCount + 1
        updateBadge()
    end
    if _isOpen then
        rebuildScrollList()
    end
end

local function openPanel()
    _isOpen = true
    _unreadCount = 0
    updateBadge()
    rebuildScrollList()
    TweenService:Create(panel, SLIDE_IN, { Position = UDim2.new(0.44, 0, 0.12, 0) }):Play()
end

local function closePanel()
    _isOpen = false
    TweenService:Create(panel, SLIDE_OUT, { Position = UDim2.new(1.05, 0, 0.12, 0) }):Play()
end

-- Bell button toggle
bellBtn.Activated:Connect(function()
    if _isOpen then closePanel() else openPanel() end
end)

-- Clear button
clearBtn.Activated:Connect(function()
    _entries = {}
    _unreadCount = 0
    updateBadge()
    rebuildScrollList()
end)

-- Close when clicking outside (tap bell again or any other tab button)
for _, child in mainFrame:GetChildren() do
    if child:IsA("TextButton") and child.Name:find("^Tab") then
        child.Activated:Connect(function()
            if _isOpen then closePanel() end
        end)
    end
end

-- Listen to all Notify events
Notify.OnClientEvent:Connect(function(data: { title: string?, message: string?, duration: number? })
    local title   = data.title   or "Notification"
    local message = data.message or ""
    addEntry(title, message)
end)

print("[NotificationCenterController] ready")
]]
ctrl.Parent = SPS
print("✅ NotificationCenterController LocalScript created in StarterPlayerScripts")
```

---

## STEP D — Verification

```lua
-- In Studio Command Bar:
local StarterGui    = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local results = {}
local issues  = {}

-- 1. BellButton in HiveGui.MainFrame
local hiveGui   = StarterGui:FindFirstChild("HiveGui")
local mainFrame = hiveGui and hiveGui:FindFirstChild("MainFrame")
local bellBtn   = mainFrame and mainFrame:FindFirstChild("BellButton")
table.insert(bellBtn and results or issues,
    (bellBtn and "✅" or "❌") .. " BellButton: " .. (bellBtn and "exists in HiveGui.MainFrame" or "MISSING"))

-- 2. UnreadBadge
local badge = bellBtn and bellBtn:FindFirstChild("UnreadBadge")
table.insert(badge and results or issues,
    (badge and "✅" or "❌") .. " UnreadBadge: " .. (badge and "exists" or "MISSING"))

-- 3. NotificationPanel
local panel = mainFrame and mainFrame:FindFirstChild("NotificationPanel")
if panel then
    local scroll = panel:FindFirstChild("ScrollFrame")
    local ll     = scroll and scroll:FindFirstChildOfClass("UIListLayout")
    local clearB = panel:FindFirstChild("Header") and panel.Header:FindFirstChild("ClearBtn")
    table.insert(results, "✅ NotificationPanel: exists | ScrollFrame=" .. tostring(scroll ~= nil) .. " UIListLayout=" .. tostring(ll ~= nil) .. " ClearBtn=" .. tostring(clearB ~= nil))
else
    table.insert(issues, "❌ NotificationPanel: MISSING from HiveGui.MainFrame")
end

-- 4. NotificationCenterController
local sps = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local ctrl = sps and sps:FindFirstChild("NotificationCenterController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n", "\n")) + 1
    local hasNotify   = ctrl.Source:find("Notify") ~= nil
    local hasAddEntry = ctrl.Source:find("addEntry") ~= nil
    local hasTween    = ctrl.Source:find("TweenService") ~= nil
    local hasMaxEntries = ctrl.Source:find("MAX_ENTRIES") ~= nil
    table.insert(results, string.format(
        "✅ NotificationCenterController: %d lines | Notify=%s addEntry=%s Tween=%s MaxEntries=%s",
        lines, tostring(hasNotify), tostring(hasAddEntry), tostring(hasTween), tostring(hasMaxEntries)
    ))
else
    table.insert(issues, "❌ NotificationCenterController: MISSING from StarterPlayerScripts")
end

-- 5. Notify RemoteEvent exists (pre-existing, sanity check)
local RS      = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
local notifyRE = remotes and remotes:FindFirstChild("Notify")
table.insert(notifyRE and results or issues,
    (notifyRE and "✅" or "⚠️") .. " Notify RemoteEvent: " .. (notifyRE and "exists (pre-existing)" or "NOT FOUND — check earlier dispatches"))

local out = "=== DISPATCH 39 VERIFICATION ===\n" .. table.concat(results, "\n")
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — Dispatch 39 complete" end
return out
```

---

## EXECUTION SUMMARY

| Step | What | Parts |
|------|------|-------|
| A | BellButton + UnreadBadge added to HiveGui.MainFrame | 0 |
| B | NotificationPanel Frame + ScrollingFrame + UIListLayout | 0 |
| C | NotificationCenterController LocalScript | 0 |
| D | Verification | — |

**Running part total: ~4,142 / 5,000** (no change)

---

## BEHAVIOURAL NOTES

- **Zero server-side code** — reads existing `Notify` RemoteEvent; no new server scripts or RemoteEvents
- **Max 20 entries** — oldest auto-trimmed; never grows unbounded
- **Unread badge** resets to 0 when panel is opened; shows 99+ cap for high counts
- **Newest-first** ordering in scroll list — most recent notification always at top
- **fmtTime** human-readable relative timestamps ("just now", "5m ago", "2h ago")
- **Tween Back/Out** slide-in gives playful bounce consistent with other panels (ReadyCheck, PrestigeRush)
- **Clear button** wipes all entries and resets badge (no confirmation — entries are ephemeral)
- **Tab button auto-close**: any tab button click dismisses the panel so it doesn't obstruct gameplay
- **Connecting to Notify**: all existing services (AchievementService, PrestigeRewardService, WaspService, SeasonalEventService, ForagingService) already fire `Notify:FireClient(player, {title, message, duration})` — zero wiring needed

---

*Dispatch 39 complete — proceed to dispatch 40 (BeeColourCustomizer expanded palette)*
