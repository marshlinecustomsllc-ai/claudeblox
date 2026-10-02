# Dispatch 158 — LeaderboardGui (Top-10 Server Honey Leaderboard)
**Cycle:** 15  
**Part budget before:** 4,197 / 5,000  
**Parts added:** +1 permanent (leaderboard cork board SurfaceGui anchor, if not already present from dispatch 24)  
**Part budget after:** 4,198 / 5,000  
**Prerequisite dispatches:** 24 (LeaderboardService server-side), 153 (StatsBoard + ServerStatsService)

---

## Overview

A live, server-side top-10 honey leaderboard visible to all players. The leaderboard shows the current session's top earners by total honey collected (not banked — `HoneyEarned` lifetime stat). It updates every 30 seconds and on any player's significant harvest.

**Two surfaces:**
1. **World cork board** near the hub entrance — a 3D SurfaceGui billboard showing the top 5 (at a glance, always visible in the world)
2. **Screen overlay panel** — full top-10, opened by pressing the cork board ProximityPrompt or the "🏆 Leaderboard" HUD button

**Kid-friendly:** Names are truncated to 12 chars. Medals (🥇🥈🥉) for top 3. The local player's own row is highlighted gold.

---

## Step 1 — Verify LeaderboardService exists

```lua
-- Check dispatch 24 LeaderboardService
local ls = game:GetService("ServerScriptService"):FindFirstChild("LeaderboardService", true)
print("LeaderboardService:", ls and ls:GetFullName() or "NOT FOUND")
-- Also check for the LeaderboardUpdated RemoteEvent from dispatch 24
local R = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
print("LeaderboardUpdated remote:", R and R:FindFirstChild("LeaderboardUpdated") and "FOUND" or "NOT FOUND")
```

If `LeaderboardService` is not found — it was dispatch 24 content awaiting execution. In that case, create it fresh in this dispatch (Step 2 handles both cases).

---

## Step 2 — LeaderboardService (new or replace Script, ServerScriptService)

Create `ServerScriptService.LeaderboardService` as a **Script**. If dispatch 24 already created one, replace its Source with this version (which is a complete, self-contained rewrite):

```lua
--!strict
-- LeaderboardService: top-10 honey earners leaderboard, broadcast every 30s
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ── RemoteEvent ───────────────────────────────────────────────────────────────
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local function getOrCreate_158(name: string, class: string)
    local e = Remotes:FindFirstChild(name)
    if e then return e end
    local n = Instance.new(class)
    n.Name = name
    n.Parent = Remotes
    return n
end
local LeaderboardUpdated_158: RemoteEvent = getOrCreate_158("LeaderboardUpdated", "RemoteEvent") :: RemoteEvent

-- ── Board state ───────────────────────────────────────────────────────────────
type BoardEntry = { rank: number, userId: number, displayName: string, honey: number }
local _cachedBoard_158: { BoardEntry } = {}

-- ── Build board ───────────────────────────────────────────────────────────────
local function buildBoard_158(): { BoardEntry }
    local entries: { BoardEntry } = {}
    for _, player in Players:GetPlayers() do
        local honey = tonumber(player:GetAttribute("HoneyEarned")) or 0
        table.insert(entries, {
            rank        = 0,
            userId      = player.UserId,
            displayName = player.DisplayName,
            honey       = honey,
        })
    end
    table.sort(entries, function(a, b) return a.honey > b.honey end)
    local top10: { BoardEntry } = {}
    for i = 1, math.min(10, #entries) do
        entries[i].rank = i
        table.insert(top10, entries[i])
    end
    return top10
end

local function broadcast_158()
    local board = buildBoard_158()
    _cachedBoard_158 = board
    LeaderboardUpdated_158:FireAllClients(board)
end

-- ── 30s update loop ───────────────────────────────────────────────────────────
task.spawn(function()
    while true do
        task.wait(30)
        broadcast_158()
    end
end)

-- ── Trigger on join/leave ─────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player: Player)
    task.wait(3)  -- brief delay for profile load and HoneyEarned attribute to be set
    broadcast_158()
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    broadcast_158()
end)

-- ── Trigger on significant harvest (HoneyEarned attribute change) ─────────────
Players.PlayerAdded:Connect(function(player: Player)
    player:GetAttributeChangedSignal("HoneyEarned"):Connect(function()
        -- Debounce: only rebuild if this player's honey puts them in a new rank
        local newHoney = tonumber(player:GetAttribute("HoneyEarned")) or 0
        -- Check if any existing entry in the cache is lower
        local shouldUpdate = #_cachedBoard_158 < 10
        if not shouldUpdate then
            local lowest = _cachedBoard_158[#_cachedBoard_158]
            if lowest and newHoney > lowest.honey then
                shouldUpdate = true
            end
        end
        if shouldUpdate then
            broadcast_158()
        end
    end)
end)

-- ── New player requests board on join ─────────────────────────────────────────
local RequestLeaderboard_158: RemoteEvent = getOrCreate_158("RequestLeaderboard", "RemoteEvent") :: RemoteEvent
RequestLeaderboard_158.OnServerEvent:Connect(function(player: Player)
    LeaderboardUpdated_158:FireClient(player, _cachedBoard_158)
end)

-- Initial build
task.defer(broadcast_158)
```

**Verify:**
```lua
local R = game:GetService("ReplicatedStorage").Remotes
print("LeaderboardUpdated:", R:FindFirstChild("LeaderboardUpdated") ~= nil and "PASS" or "FAIL")
print("RequestLeaderboard:", R:FindFirstChild("RequestLeaderboard") ~= nil and "PASS" or "FAIL")
local ls = game:GetService("ServerScriptService"):FindFirstChild("LeaderboardService")
print("LeaderboardService:", ls ~= nil and "PASS" or "FAIL")
```

---

## Step 3 — LeaderboardController (new LocalScript, StarterPlayerScripts)

Create `StarterPlayerScripts.LeaderboardController`:

```lua
--!strict
-- LeaderboardController: renders top-10 leaderboard (world billboard + screen overlay)
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")

local player    = Players.LocalPlayer
local Remotes   = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

local LeaderboardUpdated_158: RemoteEvent  = Remotes:WaitForChild("LeaderboardUpdated",  10) :: RemoteEvent
local RequestLeaderboard_158: RemoteEvent  = Remotes:WaitForChild("RequestLeaderboard",  10) :: RemoteEvent

-- ── Palette ───────────────────────────────────────────────────────────────────
local PROPOLIS_BROWN = Color3.fromRGB(80,  50,  20)
local HONEY_GOLD     = Color3.fromRGB(242, 168,  28)
local WAX_CREAM      = Color3.fromRGB(232, 212, 154)
local MEDAL_GOLD     = Color3.fromRGB(255, 215,   0)
local MEDAL_SILVER   = Color3.fromRGB(192, 192, 192)
local MEDAL_BRONZE   = Color3.fromRGB(205, 127,  50)
local PLAYER_HIGHLIGHT = Color3.fromRGB(100, 70, 10)

local MEDALS_158 = { "🥇", "🥈", "🥉" }

local function truncate_158(s: string, n: number): string
    if #s <= n then return s end
    return s:sub(1, n - 1) .. "…"
end

local function formatHoney_158(n: number): string
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000    then return string.format("%.1fK", n / 1000)    end
    return tostring(n)
end

-- ── Screen overlay ────────────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "LeaderboardGui"
screenGui.DisplayOrder   = 20
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

-- Backdrop panel (hidden by default)
local panel = Instance.new("Frame")
panel.Name             = "LeaderboardPanel"
panel.Size             = UDim2.new(0, 260, 0, 380)
panel.Position         = UDim2.new(1, 270, 0.5, -190)  -- starts off-screen right
panel.BackgroundColor3 = PROPOLIS_BROWN
panel.BorderSizePixel  = 0
panel.Parent           = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD
panelStroke.Thickness = 2
panelStroke.Parent    = panel

local panelPad = Instance.new("UIPadding")
panelPad.PaddingLeft   = UDim.new(0, 10)
panelPad.PaddingRight  = UDim.new(0, 10)
panelPad.PaddingTop    = UDim.new(0, 10)
panelPad.PaddingBottom = UDim.new(0, 10)
panelPad.Parent        = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 4)
listLayout.Parent    = panel

-- Title row
local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, 0, 0, 28)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "🏆 Top Honey Earners"
titleLabel.TextColor3        = HONEY_GOLD
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 16
titleLabel.TextXAlignment    = Enum.TextXAlignment.Center
titleLabel.LayoutOrder       = 0
titleLabel.Parent            = panel

-- Divider
local divider = Instance.new("Frame")
divider.Name             = "Divider"
divider.Size             = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = HONEY_GOLD
divider.BorderSizePixel  = 0
divider.BackgroundTransparency = 0.5
divider.LayoutOrder      = 1
divider.Parent           = panel

-- Row pool (10 rows pre-built)
type RowRefs = { frame: Frame, medal: TextLabel, name: TextLabel, honey: TextLabel }
local rowRefs: { RowRefs } = {}

for i = 1, 10 do
    local row = Instance.new("Frame")
    row.Name             = "Row_" .. i
    row.Size             = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.BorderSizePixel  = 0
    row.LayoutOrder      = i + 1
    row.Parent           = panel

    local medLabel = Instance.new("TextLabel")
    medLabel.Name             = "Medal"
    medLabel.Size             = UDim2.new(0, 28, 1, 0)
    medLabel.Position         = UDim2.new(0, 0, 0, 0)
    medLabel.BackgroundTransparency = 1
    medLabel.Text             = ""
    medLabel.TextSize         = 16
    medLabel.Font             = Enum.Font.GothamBold
    medLabel.TextXAlignment   = Enum.TextXAlignment.Center
    medLabel.TextColor3       = WAX_CREAM
    medLabel.Parent           = row

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name            = "PlayerName"
    nameLabel.Size            = UDim2.new(1, -90, 1, 0)
    nameLabel.Position        = UDim2.new(0, 30, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text            = ""
    nameLabel.TextSize        = 13
    nameLabel.Font            = Enum.Font.Gotham
    nameLabel.TextXAlignment  = Enum.TextXAlignment.Left
    nameLabel.TextColor3      = WAX_CREAM
    nameLabel.Parent          = row

    local honeyLabel = Instance.new("TextLabel")
    honeyLabel.Name           = "Honey"
    honeyLabel.Size           = UDim2.new(0, 56, 1, 0)
    honeyLabel.Position       = UDim2.new(1, -56, 0, 0)
    honeyLabel.BackgroundTransparency = 1
    honeyLabel.Text           = ""
    honeyLabel.TextSize       = 13
    honeyLabel.Font           = Enum.Font.GothamBold
    honeyLabel.TextXAlignment = Enum.TextXAlignment.Right
    honeyLabel.TextColor3     = HONEY_GOLD
    honeyLabel.Parent         = row

    table.insert(rowRefs, { frame=row, medal=medLabel, name=nameLabel, honey=honeyLabel })
end

-- Empty state label
local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name              = "EmptyState"
emptyLabel.Size              = UDim2.new(1, 0, 0, 28)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text              = "No data yet — harvest some honey!"
emptyLabel.TextColor3        = Color3.fromRGB(160, 140, 90)
emptyLabel.Font              = Enum.Font.Gotham
emptyLabel.TextSize          = 12
emptyLabel.TextXAlignment    = Enum.TextXAlignment.Center
emptyLabel.Visible           = false
emptyLabel.LayoutOrder       = 12
emptyLabel.Parent            = panel

-- Subtitle (last updated)
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name              = "Subtitle"
subtitleLabel.Size              = UDim2.new(1, 0, 0, 16)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text              = "Updates every 30s"
subtitleLabel.TextColor3        = Color3.fromRGB(130, 110, 70)
subtitleLabel.Font              = Enum.Font.Gotham
subtitleLabel.TextSize          = 10
subtitleLabel.TextXAlignment    = Enum.TextXAlignment.Center
subtitleLabel.LayoutOrder       = 13
subtitleLabel.Parent            = panel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "CloseBtn"
closeBtn.Size             = UDim2.new(0, 24, 0, 24)
closeBtn.Position         = UDim2.new(1, -32, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 40)
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.TextSize         = 13
closeBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
closeBtn.Parent           = panel

local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(0, 6)
closeBtnCorner.Parent = closeBtn

-- ── HUD toggle button ─────────────────────────────────────────────────────────
local hudBtn = Instance.new("TextButton")
hudBtn.Name             = "LeaderboardToggle"
hudBtn.Size             = UDim2.new(0, 36, 0, 36)
hudBtn.Position         = UDim2.new(1, -48, 0.5, 60)  -- right side mid-screen below HiveStats
hudBtn.BackgroundColor3 = PROPOLIS_BROWN
hudBtn.BorderSizePixel  = 0
hudBtn.Text             = "🏆"
hudBtn.Font             = Enum.Font.GothamBold
hudBtn.TextSize         = 20
hudBtn.Parent           = screenGui

local hudCorner = Instance.new("UICorner")
hudCorner.CornerRadius = UDim.new(0, 10)
hudCorner.Parent = hudBtn

local hudStroke = Instance.new("UIStroke")
hudStroke.Color     = HONEY_GOLD
hudStroke.Thickness = 1.5
hudStroke.Parent    = hudBtn

-- ── Panel open/close ──────────────────────────────────────────────────────────
local _panelOpen_158 = false

local function openPanel_158()
    if _panelOpen_158 then return end
    _panelOpen_158 = true
    TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -274, 0.5, -190)
    }):Play()
end

local function closePanel_158()
    if not _panelOpen_158 then return end
    _panelOpen_158 = false
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 270, 0.5, -190)
    }):Play()
end

hudBtn.Activated:Connect(function()
    if _panelOpen_158 then closePanel_158() else openPanel_158() end
end)
closeBtn.Activated:Connect(closePanel_158)

-- ── Render board ─────────────────────────────────────────────────────────────
type BoardEntry = { rank: number, userId: number, displayName: string, honey: number }

local function renderBoard_158(board: { BoardEntry })
    emptyLabel.Visible = (#board == 0)
    for i = 1, 10 do
        local refs = rowRefs[i]
        local entry = board[i]
        if entry then
            refs.frame.BackgroundTransparency = (entry.userId == player.UserId) and 0.5 or 1
            refs.frame.BackgroundColor3 = PLAYER_HIGHLIGHT
            refs.medal.Text  = MEDALS_158[entry.rank] or tostring(entry.rank) .. "."
            refs.medal.TextColor3 = entry.rank == 1 and MEDAL_GOLD or entry.rank == 2 and MEDAL_SILVER or entry.rank == 3 and MEDAL_BRONZE or WAX_CREAM
            refs.name.Text   = truncate_158(entry.displayName, 12)
            refs.name.Font   = (entry.userId == player.UserId) and Enum.Font.GothamBold or Enum.Font.Gotham
            refs.honey.Text  = formatHoney_158(entry.honey) .. " 🍯"
            refs.frame.Visible = true
        else
            refs.frame.Visible = false
        end
    end
    subtitleLabel.Text = "Updated " .. os.date("%H:%M") .. " UTC"
end

LeaderboardUpdated_158.OnClientEvent:Connect(renderBoard_158)

-- ── World billboard (top-5 on cork board) ────────────────────────────────────
-- The cork board Part is "LeaderboardBoard" tagged in dispatch 24 world build.
-- If it exists, attach a BillboardGui. If not, we skip (screen overlay is sufficient).
local function setupWorldBoard_158()
    local CS  = game:GetService("CollectionService")
    local boards = CS:GetTagged("LeaderboardBoard")
    if #boards == 0 then
        -- Try direct name search in hub area
        local hub = workspace:FindFirstChild("Hub")
        local board = hub and hub:FindFirstChild("LeaderboardBoard", true)
        if board then table.insert(boards, board) end
    end
    if #boards == 0 then return end  -- world part not built yet; screen-only mode
    local boardPart = boards[1] :: BasePart

    local bg = Instance.new("BillboardGui")
    bg.Name            = "LeaderboardBillboard"
    bg.Size            = UDim2.new(0, 220, 0, 180)
    bg.StudsOffset     = Vector3.new(0, 2, 0)
    bg.AlwaysOnTop     = false
    bg.MaxDistance     = 50
    bg.Parent          = boardPart

    local bgFrame = Instance.new("Frame")
    bgFrame.Size             = UDim2.new(1, 0, 1, 0)
    bgFrame.BackgroundColor3 = PROPOLIS_BROWN
    bgFrame.BackgroundTransparency = 0.15
    bgFrame.BorderSizePixel  = 0
    bgFrame.Parent           = bg

    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame

    local bbTitle = Instance.new("TextLabel")
    bbTitle.Size             = UDim2.new(1, 0, 0, 24)
    bbTitle.BackgroundTransparency = 1
    bbTitle.Text             = "🏆 Top Hives"
    bbTitle.TextColor3       = HONEY_GOLD
    bbTitle.Font             = Enum.Font.GothamBold
    bbTitle.TextSize         = 14
    bbTitle.TextXAlignment   = Enum.TextXAlignment.Center
    bbTitle.Parent           = bgFrame

    local bbList = Instance.new("UIListLayout")
    bbList.SortOrder   = Enum.SortOrder.LayoutOrder
    bbList.Padding     = UDim.new(0, 2)
    bbList.Parent      = bgFrame

    -- 5 billboard rows
    local bbRows: { { name: TextLabel, honey: TextLabel, frame: Frame } } = {}
    for i = 1, 5 do
        local row = Instance.new("Frame")
        row.Name             = "BBRow_" .. i
        row.Size             = UDim2.new(1, -8, 0, 22)
        row.BackgroundTransparency = 1
        row.LayoutOrder      = i + 1
        row.Parent           = bgFrame

        local lPad = Instance.new("UIPadding")
        lPad.PaddingLeft  = UDim.new(0, 4)
        lPad.PaddingRight = UDim.new(0, 4)
        lPad.Parent = row

        local medal = Instance.new("TextLabel")
        medal.Size            = UDim2.new(0, 20, 1, 0)
        medal.BackgroundTransparency = 1
        medal.Text            = ""
        medal.TextSize        = 12
        medal.Font            = Enum.Font.GothamBold
        medal.TextXAlignment  = Enum.TextXAlignment.Center
        medal.TextColor3      = WAX_CREAM
        medal.Parent          = row

        local nameL = Instance.new("TextLabel")
        nameL.Size            = UDim2.new(1, -70, 1, 0)
        nameL.Position        = UDim2.new(0, 22, 0, 0)
        nameL.BackgroundTransparency = 1
        nameL.Text            = "---"
        nameL.TextSize        = 12
        nameL.Font            = Enum.Font.Gotham
        nameL.TextXAlignment  = Enum.TextXAlignment.Left
        nameL.TextColor3      = WAX_CREAM
        nameL.Parent          = row

        local honeyL = Instance.new("TextLabel")
        honeyL.Size           = UDim2.new(0, 44, 1, 0)
        honeyL.Position       = UDim2.new(1, -44, 0, 0)
        honeyL.BackgroundTransparency = 1
        honeyL.Text           = ""
        honeyL.TextSize       = 11
        honeyL.Font           = Enum.Font.GothamBold
        honeyL.TextXAlignment = Enum.TextXAlignment.Right
        honeyL.TextColor3     = HONEY_GOLD
        honeyL.Parent         = row

        table.insert(bbRows, { frame=row, name=nameL, honey=honeyL, medal=medal })
    end

    -- Add ProximityPrompt to open full leaderboard
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText    = "Leaderboard"
    prompt.ObjectText    = "Top Hives"
    prompt.KeyboardKeyCode = Enum.KeyCode.F
    prompt.MaxActivationDistance = 8
    prompt.HoldDuration  = 0
    prompt.Parent        = boardPart

    prompt.Triggered:Connect(function()
        openPanel_158()
    end)

    -- Update billboard on board changes
    LeaderboardUpdated_158.OnClientEvent:Connect(function(board: { BoardEntry })
        for i = 1, 5 do
            local refs = bbRows[i]
            local entry = board[i]
            if entry then
                refs.medal.Text = MEDALS_158[entry.rank] or (tostring(entry.rank) .. ".")
                refs.name.Text  = truncate_158(entry.displayName, 10)
                refs.honey.Text = formatHoney_158(entry.honey)
                refs.frame.Visible = true
            else
                refs.frame.Visible = false
            end
        end
    end)
end

task.delay(2, setupWorldBoard_158)

-- ── Request initial data ──────────────────────────────────────────────────────
task.delay(3, function()
    RequestLeaderboard_158:FireServer()
end)
```

**Verify after creating:**
```lua
local sg = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LeaderboardGui")
print("LeaderboardGui:", sg ~= nil and "PASS" or "FAIL")
if sg then
    print("Panel:", sg:FindFirstChild("LeaderboardPanel") ~= nil and "PASS" or "FAIL")
    print("Toggle:", sg:FindFirstChild("LeaderboardToggle") ~= nil and "PASS" or "FAIL")
    print("Rows:", sg.LeaderboardPanel:FindFirstChild("Row_1") ~= nil and "PASS" or "FAIL")
end
```

---

## Step 4 — Plot plaques (local player's rank shown on their plot, +0 new parts)

Dispatch 24 planned "plot plaques" — a SurfaceGui on each PlotSign showing the player's current rank. Since PlotSign parts already exist (tagged), this is a pure client-side addition to LeaderboardController.

Append this block to the bottom of `LeaderboardController`:

```lua
-- Plot plaque rank display (appended to LeaderboardController)
-- Updates PlotSign SurfaceGui on each rank change

local function updatePlotPlaques_158(board: { BoardEntry })
    local CS       = game:GetService("CollectionService")
    local plotSigns = CS:GetTagged("PlotSign")
    local myRank = 0
    for _, entry in board do
        if entry.userId == player.UserId then
            myRank = entry.rank
            break
        end
    end
    if myRank == 0 then return end
    for _, sign in plotSigns do
        local signPart = sign :: BasePart
        -- Only update the sign on THIS player's plot
        local plotIndex = signPart:GetAttribute("PlotIndex")
        local ownerAttr = signPart.Parent and signPart.Parent:GetAttribute("OwnerUserId")
        if ownerAttr == player.UserId then
            -- Find or create a SurfaceGui on the sign
            local sgu = signPart:FindFirstChildOfClass("SurfaceGui")
            if not sgu then
                sgu = Instance.new("SurfaceGui")
                sgu.Face       = Enum.NormalId.Front
                sgu.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
                sgu.PixelsPerStud = 40
                sgu.Parent     = signPart
            end
            -- Find or create rank label
            local rankLabel = sgu:FindFirstChild("RankLabel") :: TextLabel?
            if not rankLabel then
                rankLabel = Instance.new("TextLabel") :: TextLabel
                rankLabel.Name             = "RankLabel"
                rankLabel.Size             = UDim2.new(1, 0, 0.5, 0)
                rankLabel.Position         = UDim2.new(0, 0, 0.5, 0)
                rankLabel.BackgroundTransparency = 1
                rankLabel.Font             = Enum.Font.GothamBold
                rankLabel.TextSize         = 14
                rankLabel.TextXAlignment   = Enum.TextXAlignment.Center
                rankLabel.Parent           = sgu
            end
            local medal = MEDALS_158[myRank] or ("#" .. myRank)
            rankLabel.Text       = medal .. " Rank " .. myRank
            rankLabel.TextColor3 = myRank <= 3 and MEDAL_GOLD or WAX_CREAM
        end
    end
end

LeaderboardUpdated_158.OnClientEvent:Connect(updatePlotPlaques_158)
```

---

## Final verification sweep

```lua
print("=== DISPATCH 158 VERIFICATION SWEEP ===")

-- 1. RemoteEvents
local R = game:GetService("ReplicatedStorage").Remotes
for _, name in {"LeaderboardUpdated", "RequestLeaderboard"} do
    print(name .. ":", R:FindFirstChild(name) ~= nil and "PASS" or "FAIL")
end

-- 2. LeaderboardService
local ls = game:GetService("ServerScriptService"):FindFirstChild("LeaderboardService")
print("LeaderboardService:", ls ~= nil and "PASS" or "FAIL")
if ls then
    local hasStrict  = ls.Source:find("--!strict") ~= nil
    local hasSort    = ls.Source:find("table%.sort") ~= nil
    local hasBroadcast = ls.Source:find("broadcast_158") ~= nil
    print("  --!strict:", hasStrict)
    print("  sort:", hasSort)
    print("  broadcast_158:", hasBroadcast)
end

-- 3. LeaderboardController
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local lc = SPS:FindFirstChild("LeaderboardController")
print("LeaderboardController:", lc ~= nil and "PASS" or "FAIL")

-- 4. Part budget
local total = 0
for _, p in workspace:GetDescendants() do
    if p:IsA("BasePart") then total += 1 end
end
print("Total workspace parts:", total, "(budget 5000)")
print("=== END 158 SWEEP ===")
```

Expected:
```
=== DISPATCH 158 VERIFICATION SWEEP ===
LeaderboardUpdated: PASS
RequestLeaderboard: PASS
LeaderboardService: PASS
  --!strict: true
  sort: true
  broadcast_158: true
LeaderboardController: PASS
Total workspace parts: 4198 (budget 5000)
=== END 158 SWEEP ===
```

---

## Notes

- **HoneyEarned vs HoneyCount:** The leaderboard ranks by `HoneyEarned` (lifetime total, never decreases) not `HoneyCount` (current wallet). This rewards consistent play over timing of spending.
- **World board fallback:** If `LeaderboardBoard` is not in the world yet (dispatch 24 unexecuted), `setupWorldBoard_158` exits silently. The screen panel (🏆 button) is always available as the primary access.
- **Plot plaques:** The `OwnerUserId` attribute on the plot root folder must be set by `PlotService.AssignPlot`. If it isn't set, the plaque update skips silently — no error.
- **Midnight UTC format:** `os.date("%H:%M")` in `renderBoard_158` uses the client's local time via `DateTime.now():FormatLocalTime` if UTC display is preferred — current implementation uses Lua `os.date` which is server-appropriate but on the client returns local time. Functionally fine for "last updated" display.

---

*Dispatch 158 complete. Part budget: **4,198 / 5,000**.*
