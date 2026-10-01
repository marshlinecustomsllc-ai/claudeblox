# Dispatch 47 — LeaderboardGui Top-10 Server Honey Leaderboard (Cycle 11)

**Feature:** A real-time server leaderboard showing the top 10 players by lifetime honey
earned this session. Updates every 15 seconds. Displayed as a compact panel on the
right edge of the screen, collapsible via a 🏆 button.

**Execution order:** After dispatch 46 (SeasonService).  
**Part budget impact:** 0 (pure UI).  
**Running total:** ~4,142 / 5,000.

---

## STEP A — LeaderboardService ModuleScript

```lua
local SSS = game:GetService("ServerScriptService")

local svc = Instance.new("ModuleScript")
svc.Name   = "LeaderboardService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- LeaderboardService — collects lifetime honey from all connected player profiles
-- and broadcasts top-10 rankings to all clients every 15 seconds.

local LeaderboardService = {}

local Players      = game:GetService("Players")
local DataService  = require(script.Parent.DataService)

local LeaderboardSync: RemoteEvent?
local BROADCAST_INTERVAL = 15   -- seconds

-- ── Build snapshot ───────────────────────────────────────────────
local function buildSnapshot(): {{userId: number, name: string, honey: number}}
    local rows: {{userId: number, name: string, honey: number}} = {}
    for _, player in Players:GetPlayers() do
        local profile = DataService.GetProfile(player)
        if profile then
            table.insert(rows, {
                userId = player.UserId,
                name   = player.Name,
                honey  = profile.lifetimeHoney or 0,
            })
        end
    end
    -- Sort descending by honey
    table.sort(rows, function(a, b) return a.honey > b.honey end)
    -- Top 10 only
    if #rows > 10 then
        local top: {{userId: number, name: string, honey: number}} = {}
        for i = 1, 10 do top[i] = rows[i] end
        return top
    end
    return rows
end

local function broadcast()
    if not LeaderboardSync then return end
    local snap = buildSnapshot()
    -- Add rank number to each row
    local payload: {{rank: number, userId: number, name: string, honey: number}} = {}
    for i, row in snap do
        table.insert(payload, { rank = i, userId = row.userId, name = row.name, honey = row.honey })
    end
    LeaderboardSync:FireAllClients(payload)
end

function LeaderboardService.Init()
    local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not Remotes then
        Remotes = Instance.new("Folder")
        Remotes.Name = "Remotes"
        Remotes.Parent = game:GetService("ReplicatedStorage")
    end
    LeaderboardSync = Remotes:FindFirstChild("LeaderboardSync")
    if not LeaderboardSync then
        LeaderboardSync = Instance.new("RemoteEvent")
        LeaderboardSync.Name = "LeaderboardSync"
        LeaderboardSync.Parent = Remotes
    end

    -- Sync joining player immediately
    Players.PlayerAdded:Connect(function(player)
        task.delay(4, function()
            if not (player and player.Parent) then return end
            if LeaderboardSync then
                local snap = buildSnapshot()
                local payload: {{rank: number, userId: number, name: string, honey: number}} = {}
                for i, row in snap do
                    table.insert(payload, {rank=i, userId=row.userId, name=row.name, honey=row.honey})
                end
                LeaderboardSync:FireClient(player, payload)
            end
        end)
    end)

    -- Periodic broadcast
    task.spawn(function()
        while true do
            task.wait(BROADCAST_INTERVAL)
            broadcast()
        end
    end)
end

return LeaderboardService
]]

print("LeaderboardService created")
```

---

## STEP B — LeaderboardSync RemoteEvent + GameManager wiring

```lua
-- RemoteEvent
local RE = game:GetService("ReplicatedStorage")
local Remotes = RE:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = RE
end
local ls = Remotes:FindFirstChild("LeaderboardSync")
if not ls then
    ls = Instance.new("RemoteEvent")
    ls.Name = "LeaderboardSync"
    ls.Parent = Remotes
end
print("LeaderboardSync RemoteEvent ready")

-- GameManager injection
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")
local clone = gm:Clone()
gm.Name = "GameManager_OLD_47B"
gm.Parent = nil

local src = clone.Source
src = src:gsub(
    "(local SeasonService = require%(script%.Parent%.SeasonService%))",
    [[%1
local LeaderboardService = require(script.Parent.LeaderboardService)]]
)
src = src:gsub(
    "(SeasonService%.Init%(%%))",
    [[%1
    LeaderboardService.Init()]]
)
clone.Source = src
clone.Name = "GameManager"
clone.Parent = SSS
print("GameManager wired for LeaderboardService")
```

---

## STEP C — LeaderboardGui ScreenGui

```lua
local StarterGui = game:GetService("StarterGui")

local lbGui              = Instance.new("ScreenGui")
lbGui.Name               = "LeaderboardGui"
lbGui.DisplayOrder       = 11
lbGui.IgnoreGuiInset     = false
lbGui.ResetOnSpawn       = false
lbGui.Parent             = StarterGui

-- Toggle button (🏆) — right edge
local toggleBtn          = Instance.new("TextButton")
toggleBtn.Name           = "ToggleBtn"
toggleBtn.Parent         = lbGui
toggleBtn.Size           = UDim2.new(0.055, 0, 0.075, 0)
toggleBtn.Position       = UDim2.new(0.945, 0, 0.30, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
toggleBtn.Text           = "🏆"
toggleBtn.TextScaled     = true
toggleBtn.Font           = Enum.Font.FredokaOne
toggleBtn.TextColor3     = Color3.fromRGB(242, 168, 28)
toggleBtn.ZIndex         = 10
local tbCorner           = Instance.new("UICorner")
tbCorner.CornerRadius    = UDim.new(0.2, 0)
tbCorner.Parent          = toggleBtn
local tbStroke           = Instance.new("UIStroke")
tbStroke.Color           = Color3.fromRGB(242, 168, 28)
tbStroke.Thickness       = 2
tbStroke.Parent          = toggleBtn

-- Panel (slides in from right)
local panel              = Instance.new("Frame")
panel.Name               = "LeaderboardPanel"
panel.Parent             = lbGui
panel.Size               = UDim2.new(0.22, 0, 0.55, 0)
panel.Position           = UDim2.new(1.01, 0, 0.23, 0)   -- starts off-screen
panel.BackgroundColor3   = Color3.fromRGB(20, 12, 5)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel    = 0
panel.Visible            = true   -- visibility controlled by Position
panel.ZIndex             = 10
local pCorner            = Instance.new("UICorner")
pCorner.CornerRadius     = UDim.new(0.03, 0)
pCorner.Parent           = panel
local pStroke            = Instance.new("UIStroke")
pStroke.Color            = Color3.fromRGB(242, 168, 28)
pStroke.Thickness        = 2
pStroke.Parent           = panel

-- Header
local header             = Instance.new("TextLabel")
header.Name              = "Header"
header.Parent            = panel
header.Size              = UDim2.new(1, 0, 0.11, 0)
header.Position          = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3  = Color3.fromRGB(122, 74, 34)
header.Text              = "🏆  Top Beekeepers"
header.TextColor3        = Color3.fromRGB(242, 168, 28)
header.Font              = Enum.Font.FredokaOne
header.TextScaled        = true
header.ZIndex            = 11
local hCorner            = Instance.new("UICorner")
hCorner.CornerRadius     = UDim.new(0.03, 0)
hCorner.Parent           = header

-- Row list container
local rowList            = Instance.new("Frame")
rowList.Name             = "RowList"
rowList.Parent           = panel
rowList.Size             = UDim2.new(0.94, 0, 0.86, 0)
rowList.Position         = UDim2.new(0.03, 0, 0.12, 0)
rowList.BackgroundTransparency = 1
rowList.ZIndex           = 11
local listLayout         = Instance.new("UIListLayout")
listLayout.SortOrder     = Enum.SortOrder.LayoutOrder
listLayout.Padding       = UDim.new(0.006, 0)
listLayout.Parent        = rowList

-- Pre-create 10 row frames (updated by controller)
for i = 1, 10 do
    local row            = Instance.new("Frame")
    row.Name             = "Row_" .. i
    row.Parent           = rowList
    row.Size             = UDim2.new(1, 0, 0.088, 0)
    row.BackgroundColor3 = i == 1 and Color3.fromRGB(80, 55, 10)
                        or i == 2 and Color3.fromRGB(55, 55, 55)
                        or i == 3 and Color3.fromRGB(60, 35, 15)
                        or Color3.fromRGB(30, 18, 8)
    row.BackgroundTransparency = 0.25
    row.LayoutOrder      = i
    row.ZIndex           = 12
    local rCorner        = Instance.new("UICorner")
    rCorner.CornerRadius = UDim.new(0.12, 0)
    rCorner.Parent       = row

    -- Rank
    local rankLbl        = Instance.new("TextLabel")
    rankLbl.Name         = "Rank"
    rankLbl.Parent       = row
    rankLbl.Size         = UDim2.new(0.13, 0, 1, 0)
    rankLbl.Position     = UDim2.new(0.01, 0, 0, 0)
    rankLbl.BackgroundTransparency = 1
    rankLbl.Text         = i == 1 and "🥇" or i == 2 and "🥈" or i == 3 and "🥉" or "#" .. i
    rankLbl.TextColor3   = Color3.fromRGB(242, 168, 28)
    rankLbl.Font         = Enum.Font.FredokaOne
    rankLbl.TextScaled   = true
    rankLbl.ZIndex       = 13

    -- Name
    local nameLbl        = Instance.new("TextLabel")
    nameLbl.Name         = "PlayerName"
    nameLbl.Parent       = row
    nameLbl.Size         = UDim2.new(0.53, 0, 1, 0)
    nameLbl.Position     = UDim2.new(0.15, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text         = "—"
    nameLbl.TextColor3   = Color3.fromRGB(232, 212, 154)
    nameLbl.Font         = Enum.Font.FredokaOne
    nameLbl.TextScaled   = true
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex       = 13

    -- Honey
    local honeyLbl       = Instance.new("TextLabel")
    honeyLbl.Name        = "HoneyAmt"
    honeyLbl.Parent      = row
    honeyLbl.Size        = UDim2.new(0.30, 0, 1, 0)
    honeyLbl.Position    = UDim2.new(0.69, 0, 0, 0)
    honeyLbl.BackgroundTransparency = 1
    honeyLbl.Text        = "0"
    honeyLbl.TextColor3  = Color3.fromRGB(242, 168, 28)
    honeyLbl.Font        = Enum.Font.FredokaOne
    honeyLbl.TextScaled  = true
    honeyLbl.TextXAlignment = Enum.TextXAlignment.Right
    honeyLbl.ZIndex      = 13
end

print("LeaderboardGui built — 10 rows ready")
```

---

## STEP D — LeaderboardController LocalScript

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "LeaderboardController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- LeaderboardController — receives LeaderboardSync and updates the panel.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer       = Players.LocalPlayer
local PlayerGui         = localPlayer:WaitForChild("PlayerGui")
local LbGui             = PlayerGui:WaitForChild("LeaderboardGui", 15)
if not LbGui then return end

local panel    = LbGui:WaitForChild("LeaderboardPanel", 5)
local toggleBtn = LbGui:WaitForChild("ToggleBtn", 5)
local rowList  = panel:WaitForChild("RowList", 5)

-- ── Format helper ────────────────────────────────────────────────
local function fmtHoney(n: number): string
    if n >= 1_000_000 then return string.format("%.1fM", n/1_000_000)
    elseif n >= 1_000  then return string.format("%.1fK", n/1_000)
    end
    return tostring(math.floor(n))
end

-- ── Row update ───────────────────────────────────────────────────
local MEDAL = {"🥇","🥈","🥉"}

local function updateRows(data: {{rank: number, userId: number, name: string, honey: number}})
    for i = 1, 10 do
        local row     = rowList:FindFirstChild("Row_" .. i) :: Frame?
        if not row then continue end
        local entry   = data[i]
        local rankLbl = row:FindFirstChild("Rank")     :: TextLabel?
        local nameLbl = row:FindFirstChild("PlayerName") :: TextLabel?
        local honeyLbl = row:FindFirstChild("HoneyAmt") :: TextLabel?

        if entry then
            if rankLbl  then rankLbl.Text  = MEDAL[i] or ("#" .. i) end
            if nameLbl  then
                -- Highlight local player's row
                if entry.userId == localPlayer.UserId then
                    nameLbl.TextColor3 = Color3.fromRGB(255, 220, 80)
                    nameLbl.Text = "► " .. entry.name
                else
                    nameLbl.TextColor3 = Color3.fromRGB(232, 212, 154)
                    nameLbl.Text = entry.name
                end
            end
            if honeyLbl then honeyLbl.Text = fmtHoney(entry.honey) .. " 🍯" end
        else
            if rankLbl  then rankLbl.Text  = "-" end
            if nameLbl  then nameLbl.Text  = "—" end
            if honeyLbl then honeyLbl.Text = "" end
        end
    end
end

-- ── Panel slide animation ────────────────────────────────────────
local PANEL_OPEN  = UDim2.new(0.77, 0, 0.23, 0)
local PANEL_CLOSE = UDim2.new(1.01, 0, 0.23, 0)
local SHOW = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local HIDE = TweenInfo.new(0.20, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

local isOpen = false

local function openPanel()
    if isOpen then return end
    isOpen = true
    TweenService:Create(panel, SHOW, {Position = PANEL_OPEN}):Play()
end

local function closePanel()
    if not isOpen then return end
    isOpen = false
    TweenService:Create(panel, HIDE, {Position = PANEL_CLOSE}):Play()
end

toggleBtn.Activated:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)

-- ── LeaderboardSync ──────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local LbSync : RemoteEvent? = Remotes and Remotes:WaitForChild("LeaderboardSync", 10) :: RemoteEvent?

if LbSync then
    LbSync.OnClientEvent:Connect(function(data)
        updateRows(data)
        -- Brief glow on toggle button to indicate refresh
        TweenService:Create(toggleBtn, TweenInfo.new(0.1), {
            BackgroundColor3 = Color3.fromRGB(180, 120, 40),
        }):Play()
        task.delay(0.4, function()
            TweenService:Create(toggleBtn, TweenInfo.new(0.3), {
                BackgroundColor3 = Color3.fromRGB(122, 74, 34),
            }):Play()
        end)
    end)
end
]]

print("LeaderboardController LocalScript created")
```

---

## STEP E — Verification

```lua
local SSS    = game:GetService("ServerScriptService")
local SP     = game:GetService("StarterPlayer")
local SG     = game:GetService("StarterGui")
local RE     = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. LeaderboardService
local svc = SSS:FindFirstChild("LeaderboardService")
if svc and svc:IsA("ModuleScript") then
    local lines = select(2, svc.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ LeaderboardService: " .. lines .. " lines")
    if not svc.Source:find("--!strict")   then table.insert(issues, "MISSING --!strict") end
    if not svc.Source:find("buildSnapshot") then table.insert(issues, "MISSING buildSnapshot") end
else
    table.insert(issues, "❌ LeaderboardService NOT FOUND")
end

-- 2. LeaderboardSync RemoteEvent
local Remotes = RE:FindFirstChild("Remotes")
local ls = Remotes and Remotes:FindFirstChild("LeaderboardSync")
table.insert(results, ls and "✅ LeaderboardSync RemoteEvent" or "❌ LeaderboardSync MISSING")
if not ls then table.insert(issues, "LeaderboardSync missing") end

-- 3. LeaderboardGui
local lb = SG:FindFirstChild("LeaderboardGui")
if lb then
    local panel = lb:FindFirstChild("LeaderboardPanel")
    local rows  = panel and panel:FindFirstChild("RowList")
    local rowCount = 0
    if rows then
        for _, c in rows:GetChildren() do
            if c:IsA("Frame") then rowCount = rowCount + 1 end
        end
    end
    table.insert(results, "✅ LeaderboardGui (DisplayOrder=" .. lb.DisplayOrder .. ") — " .. rowCount .. " rows")
    if rowCount < 10 then table.insert(issues, "Expected 10 rows, got " .. rowCount) end
else
    table.insert(issues, "❌ LeaderboardGui NOT FOUND")
end

-- 4. LeaderboardController
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ LeaderboardController: " .. lines .. " lines")
    if not ctrl.Source:find("--!strict") then table.insert(issues, "MISSING --!strict") end
    if not ctrl.Source:find("fmtHoney")  then table.insert(issues, "MISSING fmtHoney") end
else
    table.insert(issues, "❌ LeaderboardController NOT FOUND")
end

local out = "=== DISPATCH 47 VERIFICATION ===\n" .. table.concat(results, "\n") .. "\n"
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — dispatch 47 complete" end
print(out)
return out
```

---

## Summary

| Item | Created/Modified |
|---|---|
| LeaderboardService | buildSnapshot (sort by lifetimeHoney, top 10), 15s broadcast, PlayerAdded sync, LeaderboardSync:FireAllClients |
| LeaderboardSync RemoteEvent | server → all clients |
| GameManager wiring | LeaderboardService.Init() |
| LeaderboardGui (DisplayOrder=11) | 🏆 ToggleBtn (right edge), LeaderboardPanel (22%×55%), 10 pre-built Row frames |
| Row design | 🥇🥈🥉 medals, name (local player highlighted ►), honey amount (K/M format) |
| LeaderboardController | slide-from-right (Back/Out), fmtHoney, local player highlight, toggle button glow pulse |

**Execution order:** A → B → C → D → E (verify)  
**Part budget:** 0 → **~4,142 / 5,000**
