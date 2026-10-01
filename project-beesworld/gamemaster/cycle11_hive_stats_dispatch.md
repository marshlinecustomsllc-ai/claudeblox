# Dispatch 42 — HiveStatsDashboard (Cycle 11)

**Feature:** Lifetime stats tab inside HiveGui showing honey earned, cells built,
generations completed, and estimated play time.

**Execution order:** After dispatch 41 (DailyRewardService).  
**Part budget impact:** 0 (pure UI — no world parts).  
**Running total:** ~4,142 / 5,000.

---

## STEP A — Config additions (clone-and-replace Config)

Open Roblox Studio **Command Bar** and run:

```lua
-- Clone-and-replace Config
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found in SSS")
local clone = cfg:Clone()
cfg.Name = "Config_OLD_42A"
cfg.Parent = nil

-- Inject STATS_DISPLAY section into clone source
local inject = [[

-- ── Stats Dashboard ──────────────────────────────────────────
Config.STATS_DISPLAY = {
    -- Approximate play-time estimate: seconds per session tracked server-side
    sessionTrackingEnabled = true,
}
]]
clone.Source = clone.Source .. inject
clone.Name = "Config"
clone.Parent = SSS
print("Config updated for dispatch 42")
```

---

## STEP B — DataService migration (clone-and-replace DataService)

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")
local clone = ds:Clone()
ds.Name = "DataService_OLD_42B"
ds.Parent = nil

-- Inject new profile fields into DEFAULT_PROFILE
-- Find the closing brace of DEFAULT_PROFILE and insert before it
local src = clone.Source
-- Add lifetimePlaySeconds and totalCellsBuilt to existing profile fields
-- These track across sessions
local injection = [[

    -- Stats tracking (dispatch 42)
    lifetimePlaySeconds = 0,    -- accumulated play time in seconds
    totalCellsBuilt     = 0,    -- cumulative hex cells ever placed
    totalGenerations    = 0,    -- mirror of prestige count for stats display
    sessionStartTime    = 0,    -- os.time() at session join (transient, not persisted)
]]
-- Inject after "dailyClaimedToday = false," line
src = src:gsub(
    "(dailyClaimedToday%s*=%s*false,)",
    "%1" .. injection
)
clone.Source = src
clone.Name = "DataService"
clone.Parent = SSS
print("DataService migrated for dispatch 42")
```

---

## STEP C — HiveStatsService ModuleScript

```lua
local SSS = game:GetService("ServerScriptService")

-- Create HiveStatsService
local svc = Instance.new("ModuleScript")
svc.Name = "HiveStatsService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- HiveStatsService — tracks lifetime stats, session time, and fires StatsSync
local HiveStatsService = {}

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local DataService  = require(script.Parent.DataService)
local Config       = require(script.Parent.Config)

local StatsSync: RemoteEvent
local _sessionStarts: {[number]: number} = {}   -- userId → os.time() on join

-- ── Init ────────────────────────────────────────────────────────
function HiveStatsService.Init()
    local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "Remotes"
        Remotes.Parent = game:GetService("ReplicatedStorage")
    end

    StatsSync = Remotes:FindFirstChild("StatsSync")
    if not StatsSync then
        StatsSync = Instance.new("RemoteEvent")
        StatsSync.Name = "StatsSync"
        StatsSync.Parent = Remotes
    end

    -- Track session start time per player
    Players.PlayerAdded:Connect(function(player)
        _sessionStarts[player.UserId] = os.time()
        -- Send initial stats once profile loads (small delay)
        task.delay(3, function()
            if player and player.Parent then
                HiveStatsService.SyncStats(player)
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        -- Flush session seconds to profile before save
        HiveStatsService.FlushSessionTime(player)
        _sessionStarts[player.UserId] = nil
    end)

    -- Periodic sync every 60 seconds (keeps client display fresh)
    task.spawn(function()
        while true do
            task.wait(60)
            for _, player in Players:GetPlayers() do
                pcall(HiveStatsService.SyncStats, player)
            end
        end
    end)
end

-- ── Session time helpers ────────────────────────────────────────
function HiveStatsService.FlushSessionTime(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local start = _sessionStarts[player.UserId]
    if start then
        local elapsed = os.time() - start
        profile.lifetimePlaySeconds = (profile.lifetimePlaySeconds or 0) + elapsed
        _sessionStarts[player.UserId] = os.time()  -- reset for continued session
    end
end

-- ── Increment helpers (called by other services) ────────────────
function HiveStatsService.AddCellBuilt(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    profile.totalCellsBuilt = (profile.totalCellsBuilt or 0) + 1
end

function HiveStatsService.SetGenerations(player: Player, count: number)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    profile.totalGenerations = count
end

-- ── Sync to client ──────────────────────────────────────────────
function HiveStatsService.SyncStats(player: Player)
    if not StatsSync then return end
    local profile = DataService.GetProfile(player)
    if not profile then return end

    -- Compute live session seconds without saving
    local liveSeconds = (profile.lifetimePlaySeconds or 0)
    local start = _sessionStarts[player.UserId]
    if start then
        liveSeconds = liveSeconds + (os.time() - start)
    end

    StatsSync:FireClient(player, {
        lifetimeHoney       = profile.lifetimeHoney       or 0,
        totalCellsBuilt     = profile.totalCellsBuilt     or 0,
        totalGenerations    = profile.totalGenerations     or 0,
        lifetimePlaySeconds = liveSeconds,
        currentHoney        = profile.honey                or 0,
        currentPropolis     = profile.propolis             or 0,
        currentPollen       = profile.pollen               or 0,
        loginStreak         = profile.loginStreak          or 0,
    })
end

return HiveStatsService
]]

print("HiveStatsService created")
```

---

## STEP D — Wire HiveStatsService into GameManager and PrestigeService

```lua
-- ── GameManager injection ──────────────────────────────────────
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")
local gmClone = gm:Clone()
gm.Name = "GameManager_OLD_42D"
gm.Parent = nil

local gmSrc = gmClone.Source

-- Inject require after existing service requires (after DailyRewardService line)
gmSrc = gmSrc:gsub(
    "(require%(script%.Parent%.DailyRewardService%))",
    [[%1
local HiveStatsService = require(script.Parent.HiveStatsService)]]
)
-- Inject Init call after DailyRewardService.Init()
gmSrc = gmSrc:gsub(
    "(DailyRewardService%.Init%(%%))",
    [[%1
    HiveStatsService.Init()]]
)
gmClone.Source = gmSrc
gmClone.Name = "GameManager"
gmClone.Parent = SSS
print("GameManager wired for HiveStatsService")

-- ── PrestigeService injection — update totalGenerations on prestige ──
local ps = SSS:FindFirstChild("PrestigeService")
assert(ps, "PrestigeService not found")
local psClone = ps:Clone()
ps.Name = "PrestigeService_OLD_42D"
ps.Parent = nil

local psSrc = psClone.Source
-- Inject require
psSrc = psSrc:gsub(
    "(local PrestigeService = %{%})",
    [[%1
local HiveStatsService]]
)
psSrc = psSrc:gsub(
    "(PrestigeService%.Init%s*=%s*function%(%s*%))",
    [[local _HSS = pcall(function() HiveStatsService = require(script.Parent.HiveStatsService) end)
%1]]
)
-- After profile.generation incremented, call SetGenerations
psSrc = psSrc:gsub(
    "(profile%.generation%s*=%s*profile%.generation%s*%+%s*1)",
    [[%1
            pcall(function()
                if HiveStatsService then
                    HiveStatsService.SetGenerations(player, profile.generation)
                end
            end)]]
)
psClone.Source = psSrc
psClone.Name = "PrestigeService"
psClone.Parent = SSS
print("PrestigeService wired for generation tracking")
```

---

## STEP E — Wire AddCellBuilt into PlotService (hex cell placement)

```lua
local SSS = game:GetService("ServerScriptService")
local plt = SSS:FindFirstChild("PlotService")
assert(plt, "PlotService not found")
local pltClone = plt:Clone()
plt.Name = "PlotService_OLD_42E"
plt.Parent = nil

local pltSrc = pltClone.Source
-- Inject require near top
pltSrc = pltSrc:gsub(
    "(local PlotService = %{%})",
    [[%1
local _HiveStatsService]]
)
pltSrc = pltSrc:gsub(
    "(PlotService%.Init%s*=%s*function%(%s*%))",
    [[pcall(function() _HiveStatsService = require(script.Parent.HiveStatsService) end)
%1]]
)
-- After a cell is successfully placed (look for "profile.cells" or the placement success path)
-- Inject AddCellBuilt after any successful hex cell placement
pltSrc = pltSrc:gsub(
    "(profile%.honey%s*=%s*profile%.honey%s*%-%s*cost)",
    [[%1
            pcall(function()
                if _HiveStatsService then _HiveStatsService.AddCellBuilt(player) end
            end)]]
)
pltClone.Source = pltSrc
pltClone.Name = "PlotService"
pltClone.Parent = SSS
print("PlotService wired for cell tracking")
```

---

## STEP F — HiveStatsDashboard ScreenGui

```lua
local StarterGui = game:GetService("StarterGui")
local HiveGui    = StarterGui:FindFirstChild("HiveGui")
assert(HiveGui, "HiveGui not found in StarterGui")

local MainFrame = HiveGui:FindFirstChild("MainFrame")
assert(MainFrame, "MainFrame not found in HiveGui")

-- ── Stats Tab Button (📊) in MainFrame ────────────────────────
local statsBtn       = Instance.new("TextButton")
statsBtn.Name        = "StatsTabBtn"
statsBtn.Parent      = MainFrame
statsBtn.Size        = UDim2.new(0.10, 0, 0.08, 0)
statsBtn.Position    = UDim2.new(0.89, 0, 0.01, 0)
statsBtn.BackgroundColor3 = Color3.fromRGB(122, 74, 34)    -- Propolis Brown
statsBtn.Text        = "📊"
statsBtn.TextScaled  = true
statsBtn.Font        = Enum.Font.FredokaOne
statsBtn.TextColor3  = Color3.fromRGB(232, 212, 154)       -- Wax Cream
statsBtn.ZIndex      = 10
local btnCorner      = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0.2, 0)
btnCorner.Parent     = statsBtn
local btnStroke      = Instance.new("UIStroke")
btnStroke.Color      = Color3.fromRGB(242, 168, 28)        -- Honey Gold
btnStroke.Thickness  = 2
btnStroke.Parent     = statsBtn

-- ── StatsPanel ────────────────────────────────────────────────
local statsPanel          = Instance.new("Frame")
statsPanel.Name           = "StatsPanel"
statsPanel.Parent         = HiveGui
statsPanel.Size           = UDim2.new(0.38, 0, 0.62, 0)
statsPanel.Position       = UDim2.new(0.61, 0, 0.19, 0)
statsPanel.BackgroundColor3 = Color3.fromRGB(25, 15, 8)   -- deep dark brown
statsPanel.BorderSizePixel = 0
statsPanel.Visible        = false
statsPanel.ZIndex         = 20
local panelCorner         = Instance.new("UICorner")
panelCorner.CornerRadius  = UDim.new(0.04, 0)
panelCorner.Parent        = statsPanel
local panelStroke         = Instance.new("UIStroke")
panelStroke.Color         = Color3.fromRGB(242, 168, 28)
panelStroke.Thickness     = 2
panelStroke.Parent        = statsPanel

-- Header
local header              = Instance.new("TextLabel")
header.Name               = "Header"
header.Parent             = statsPanel
header.Size               = UDim2.new(1, 0, 0.12, 0)
header.Position           = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3   = Color3.fromRGB(122, 74, 34)
header.Text               = "📊  Hive Stats"
header.TextColor3         = Color3.fromRGB(242, 168, 28)
header.Font               = Enum.Font.FredokaOne
header.TextScaled         = true
header.ZIndex             = 21
local hdrCorner           = Instance.new("UICorner")
hdrCorner.CornerRadius    = UDim.new(0.04, 0)
hdrCorner.Parent          = header

-- Close button
local closeBtn            = Instance.new("TextButton")
closeBtn.Name             = "CloseBtn"
closeBtn.Parent           = statsPanel
closeBtn.Size             = UDim2.new(0.12, 0, 0.10, 0)
closeBtn.Position         = UDim2.new(0.87, 0, 0.01, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text             = "✕"
closeBtn.TextScaled       = true
closeBtn.Font             = Enum.Font.FredokaOne
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.ZIndex           = 22
local closeBtnCorner      = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0.3, 0)
closeBtnCorner.Parent     = closeBtn

-- Stat rows container
local rowList             = Instance.new("Frame")
rowList.Name              = "RowList"
rowList.Parent            = statsPanel
rowList.Size              = UDim2.new(0.92, 0, 0.82, 0)
rowList.Position          = UDim2.new(0.04, 0, 0.14, 0)
rowList.BackgroundTransparency = 1
rowList.ZIndex            = 21
local listLayout          = Instance.new("UIListLayout")
listLayout.SortOrder      = Enum.SortOrder.LayoutOrder
listLayout.Padding        = UDim.new(0.01, 0)
listLayout.Parent         = rowList

-- Helper: build one stat row
local function makeStatRow(parent, icon, labelKey, layoutOrder)
    local row = Instance.new("Frame")
    row.Name  = "Row_" .. labelKey
    row.Parent = parent
    row.Size   = UDim2.new(1, 0, 0.115, 0)
    row.BackgroundColor3 = Color3.fromRGB(40, 25, 12)
    row.LayoutOrder = layoutOrder
    row.ZIndex = 22
    local rCorner = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0.15, 0)
    rCorner.Parent = row
    local rPad = Instance.new("UIPadding")
    rPad.PaddingLeft = UDim.new(0.04, 0)
    rPad.PaddingRight = UDim.new(0.04, 0)
    rPad.Parent = row

    -- Icon label
    local ico = Instance.new("TextLabel")
    ico.Name = "Icon"
    ico.Parent = row
    ico.Size = UDim2.new(0.12, 0, 1, 0)
    ico.Position = UDim2.new(0, 0, 0, 0)
    ico.BackgroundTransparency = 1
    ico.Text = icon
    ico.TextScaled = true
    ico.Font = Enum.Font.FredokaOne
    ico.TextColor3 = Color3.fromRGB(242, 168, 28)
    ico.ZIndex = 23

    -- Stat name label
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Label"
    lbl.Parent = row
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.new(0.13, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelKey
    lbl.TextScaled = true
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextColor3 = Color3.fromRGB(232, 212, 154)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 23

    -- Value label (right-aligned, updated by controller)
    local val = Instance.new("TextLabel")
    val.Name = "Value"
    val.Parent = row
    val.Size = UDim2.new(0.30, 0, 1, 0)
    val.Position = UDim2.new(0.69, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "—"
    val.TextScaled = true
    val.Font = Enum.Font.FredokaOne
    val.TextColor3 = Color3.fromRGB(242, 168, 28)
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.ZIndex = 23

    return row
end

-- Build 7 stat rows
makeStatRow(rowList, "🍯", "Honey Earned",    1)
makeStatRow(rowList, "🏗️",  "Cells Built",     2)
makeStatRow(rowList, "🔄", "Generations",     3)
makeStatRow(rowList, "⏱️",  "Play Time",       4)
makeStatRow(rowList, "📅", "Login Streak",    5)
makeStatRow(rowList, "💰", "Honey Now",       6)
makeStatRow(rowList, "🧪", "Propolis Now",    7)

print("StatsPanel UI built — " .. #rowList:GetChildren() - 1 .. " rows")
-- (subtract 1 for UIListLayout)
```

---

## STEP G — HiveStatsController LocalScript

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "HiveStatsController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- HiveStatsController — drives StatsPanel in HiveGui

local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer    = Players.LocalPlayer
local PlayerGui      = localPlayer:WaitForChild("PlayerGui")

-- Wait for UI to replicate
local HiveGui        = PlayerGui:WaitForChild("HiveGui", 15)
if not HiveGui then return end
local MainFrame      = HiveGui:WaitForChild("MainFrame", 10)
local StatsPanel     = HiveGui:WaitForChild("StatsPanel", 10)
local StatsTabBtn    = MainFrame:WaitForChild("StatsTabBtn", 10)

if not (StatsPanel and StatsTabBtn) then return end

local RowList        = StatsPanel:WaitForChild("RowList", 5)
local CloseBtn       = StatsPanel:WaitForChild("CloseBtn", 5)

-- Panel open/close state
local isOpen         = false

-- ── Format helpers ──────────────────────────────────────────────
local function fmtNumber(n: number): string
    -- Thousand-separates and abbreviates large numbers
    if n >= 1_000_000 then
        return string.format("%.1fM", n / 1_000_000)
    elseif n >= 1_000 then
        return string.format("%.1fK", n / 1_000)
    end
    return tostring(math.floor(n))
end

local function fmtTime(seconds: number): string
    local totalMin = math.floor(seconds / 60)
    local hrs      = math.floor(totalMin / 60)
    local mins     = totalMin % 60
    if hrs > 0 then
        return string.format("%dh %dm", hrs, mins)
    else
        return string.format("%dm", mins)
    end
end

-- ── Row value helpers ───────────────────────────────────────────
local ROW_KEYS = {
    "Honey Earned",
    "Cells Built",
    "Generations",
    "Play Time",
    "Login Streak",
    "Honey Now",
    "Propolis Now",
}

local function getRowValue(frame: Frame): TextLabel?
    return frame:FindFirstChild("Value") :: TextLabel?
end

local function updateRow(rowName: string, text: string)
    local row = RowList:FindFirstChild("Row_" .. rowName)
    if not row then return end
    local val = getRowValue(row :: Frame)
    if val then val.Text = text end
end

-- ── Receive StatsSync ───────────────────────────────────────────
local Remotes  = ReplicatedStorage:WaitForChild("Remotes", 10)
local StatsSync: RemoteEvent = Remotes and Remotes:WaitForChild("StatsSync", 10)

if StatsSync then
    StatsSync.OnClientEvent:Connect(function(data: {[string]: number})
        updateRow("Honey Earned",  fmtNumber(data.lifetimeHoney       or 0) .. " 🍯")
        updateRow("Cells Built",   fmtNumber(data.totalCellsBuilt     or 0))
        updateRow("Generations",   fmtNumber(data.totalGenerations    or 0))
        updateRow("Play Time",     fmtTime  (data.lifetimePlaySeconds or 0))
        updateRow("Login Streak",  fmtNumber(data.loginStreak         or 0) .. " days")
        updateRow("Honey Now",     fmtNumber(data.currentHoney        or 0))
        updateRow("Propolis Now",  fmtNumber(data.currentPropolis     or 0))
    end)
end

-- ── Panel animations ────────────────────────────────────────────
local PANEL_SHOW = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local PANEL_HIDE = TweenInfo.new(0.20, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local PANEL_OPEN_POS  = UDim2.new(0.61, 0, 0.19, 0)
local PANEL_OPEN_SIZE = UDim2.new(0.38, 0, 0.62, 0)
local PANEL_HIDE_POS  = UDim2.new(0.99, 0, 0.19, 0)
local PANEL_HIDE_SIZE = UDim2.new(0.01, 0, 0.62, 0)

local function openPanel()
    if isOpen then return end
    isOpen = true
    StatsPanel.Position = PANEL_HIDE_POS
    StatsPanel.Size     = PANEL_HIDE_SIZE
    StatsPanel.Visible  = true
    TweenService:Create(StatsPanel, PANEL_SHOW, {
        Position = PANEL_OPEN_POS,
        Size     = PANEL_OPEN_SIZE,
    }):Play()
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    local tw = TweenService:Create(StatsPanel, PANEL_HIDE, {
        Position = PANEL_HIDE_POS,
        Size     = PANEL_HIDE_SIZE,
    })
    tw:Play()
    tw.Completed:Connect(function()
        if not isOpen then
            StatsPanel.Visible = false
        end
    end)
end

-- ── Button wiring ───────────────────────────────────────────────
StatsTabBtn.Activated:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)

CloseBtn.Activated:Connect(closePanel)

-- ── Tab-button pulse on Stats update ───────────────────────────
if StatsSync then
    StatsSync.OnClientEvent:Connect(function(_)
        if isOpen then return end
        -- Brief glow to indicate fresh data
        TweenService:Create(StatsTabBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(180, 110, 40),
        }):Play()
        task.delay(0.3, function()
            TweenService:Create(StatsTabBtn, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(122, 74, 34),
            }):Play()
        end)
    end)
end
]]

print("HiveStatsController LocalScript created")
```

---

## STEP H — Verification

```lua
-- Run this to verify dispatch 42 is complete
local SSS    = game:GetService("ServerScriptService")
local SG     = game:GetService("StarterGui")
local SP     = game:GetService("StarterPlayer")
local RE     = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. HiveStatsService
local svc = SSS:FindFirstChild("HiveStatsService")
if svc and svc:IsA("ModuleScript") then
    local lines = select(2, svc.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ HiveStatsService: " .. lines .. " lines")
    if not svc.Source:find("--!strict") then table.insert(issues, "MISSING --!strict in HiveStatsService") end
    if not svc.Source:find("SyncStats") then table.insert(issues, "MISSING SyncStats in HiveStatsService") end
else
    table.insert(issues, "❌ HiveStatsService NOT FOUND in SSS")
end

-- 2. StatsSync RemoteEvent
local Remotes = RE:FindFirstChild("Remotes")
local ss = Remotes and Remotes:FindFirstChild("StatsSync")
if ss and ss:IsA("RemoteEvent") then
    table.insert(results, "✅ StatsSync RemoteEvent exists")
else
    table.insert(issues, "❌ StatsSync RemoteEvent NOT FOUND")
end

-- 3. StatsPanel in HiveGui
local HiveGui = SG:FindFirstChild("HiveGui")
local panel   = HiveGui and HiveGui:FindFirstChild("StatsPanel")
if panel and panel:IsA("Frame") then
    local rowList = panel:FindFirstChild("RowList")
    local rowCount = 0
    if rowList then
        for _, c in rowList:GetChildren() do
            if c:IsA("Frame") then rowCount = rowCount + 1 end
        end
    end
    table.insert(results, "✅ StatsPanel exists — " .. rowCount .. " stat rows")
    if rowCount < 7 then table.insert(issues, "⚠️ Expected 7 stat rows, got " .. rowCount) end
else
    table.insert(issues, "❌ StatsPanel NOT FOUND in HiveGui")
end

-- 4. StatsTabBtn in MainFrame
local MainFrame = HiveGui and HiveGui:FindFirstChild("MainFrame")
local btn = MainFrame and MainFrame:FindFirstChild("StatsTabBtn")
if btn and btn:IsA("TextButton") then
    table.insert(results, "✅ StatsTabBtn (📊) in MainFrame")
else
    table.insert(issues, "❌ StatsTabBtn NOT FOUND in MainFrame")
end

-- 5. HiveStatsController LocalScript
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HiveStatsController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ HiveStatsController: " .. lines .. " lines")
    if not ctrl.Source:find("--!strict") then table.insert(issues, "MISSING --!strict in HiveStatsController") end
    if not ctrl.Source:find("fmtTime") then table.insert(issues, "MISSING fmtTime in HiveStatsController") end
    if not ctrl.Source:find("fmtNumber") then table.insert(issues, "MISSING fmtNumber in HiveStatsController") end
else
    table.insert(issues, "❌ HiveStatsController NOT FOUND in StarterPlayerScripts")
end

-- 6. DataService has new fields
local ds = SSS:FindFirstChild("DataService")
if ds then
    local hasFields = ds.Source:find("lifetimePlaySeconds") and ds.Source:find("totalCellsBuilt")
    table.insert(results, hasFields and "✅ DataService has stats fields" or "⚠️ DataService missing stats fields")
    if not hasFields then table.insert(issues, "DataService migration incomplete") end
end

-- Summary
local out = "=== DISPATCH 42 VERIFICATION ===\n"
out = out .. table.concat(results, "\n") .. "\n"
if #issues > 0 then
    out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else
    out = out .. "\n✅ ALL CHECKS PASSED — dispatch 42 complete"
end
print(out)
return out
```

---

## Summary

| Item | Created |
|---|---|
| Config.STATS_DISPLAY | sessionTrackingEnabled flag |
| DataService migration | lifetimePlaySeconds, totalCellsBuilt, totalGenerations, sessionStartTime |
| HiveStatsService | Init, FlushSessionTime, AddCellBuilt, SetGenerations, SyncStats (60s periodic) |
| StatsSync RemoteEvent | server → client stats payload |
| GameManager wiring | require + HiveStatsService.Init() |
| PrestigeService wiring | SetGenerations on prestige |
| PlotService wiring | AddCellBuilt on hex cell placement |
| StatsTabBtn (📊) | 10%×8% in MainFrame top-right |
| StatsPanel | 38%×62% slide-in from right, 7 stat rows |
| HiveStatsController | slide animation (Back/Out), fmtNumber, fmtTime, tab-button glow pulse |

**Execution order:** A → B → C → D → E → F → G → H (verify)  
**Part budget:** 0 permanent → **~4,142 / 5,000**
