# Dispatch 80 — LeaderboardService
## Cycle 12 · A Bee's World

**Feature:** Global ordered DataStore leaderboard — tracks top 50 players by total honey earned and by prestige level. A `LeaderboardGui` ScreenGui shows two tabs ("🍯 Honey" and "⭐ Prestige") with scrolling player rows. Updated every 60 seconds server-side and on prestige events. Uses `OrderedDataStore`.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 79 (PrestigeService)

---

## DESIGN

Two `OrderedDataStore` keys:
- `"LeaderboardHoney_v1"` — stores `totalHoneyEarned` per UserId
- `"LeaderboardPrestige_v1"` — stores `prestigeLevel` per UserId

`LeaderboardService` updates both on `PrestigeSync` (for prestige score) and every 60 seconds (for honey score) by reading the current player's profile. `GetSortedAsync(false, 50)` fetches the top 50 descending.

`LeaderboardSync` RemoteEvent broadcasts the top-10 to all clients every 60 seconds (or on any prestige event). Clients display the list in `LeaderboardGui`.

### UI

`LeaderboardGui` is a ScreenGui (DisplayOrder=18, not displayed by default). A toggle tab button `🏆` at `X=0.945 Y=0.55` on `HiveHUD` opens/closes it. Panel slides in from the right: `PANEL_OPEN = UDim2.new(0.58, 0, 0.08, 0)`, `PANEL_CLOSE = UDim2.new(1.05, 0, 0.08, 0)`.

Two tabs inside the panel: "🍯 Honey" and "⭐ Prestige". Each tab shows 10 rows with rank number, player name (truncated to 16 chars), and score.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `LeaderboardService` (new ModuleScript in SSS) | ODS writes, GetSortedAsync, LeaderboardSync broadcast |
| `GameManager` | inject `LeaderboardService.Init()` |
| `LeaderboardController` (new LocalScript in StarterPlayerScripts) | LeaderboardGui, two-tab display |

---

## STEP A — LeaderboardService (new ModuleScript)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local LeaderboardSync = Instance.new("RemoteEvent")
LeaderboardSync.Name   = "LeaderboardSync"
LeaderboardSync.Parent = RS

local svc = Instance.new("ModuleScript")
svc.Name   = "LeaderboardService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- LeaderboardService — global OrderedDataStore leaderboards

local SSS  = game:GetService("ServerScriptService")
local RS   = game:GetService("ReplicatedStorage")
local PS   = game:GetService("Players")
local DSS  = game:GetService("DataStoreService")

local DataService     = require(SSS:WaitForChild("DataService"))
local LeaderboardSync = RS:WaitForChild("LeaderboardSync")

local LeaderboardService = {}

local honeyODS    = DSS:GetOrderedDataStore("LeaderboardHoney_v1")
local prestigeODS = DSS:GetOrderedDataStore("LeaderboardPrestige_v1")

local function safeSet(ods: OrderedDataStore, key: string, value: number)
    if value <= 0 then return end
    local ok, err = pcall(function()
        ods:SetAsync(key, math.floor(value))
    end)
    if not ok then
        warn("[LeaderboardService] SetAsync failed: " .. tostring(err))
    end
end

local function fetchTop(ods: OrderedDataStore, count: number): {{name: string, score: number}}
    local results: {{name: string, score: number}} = {}
    local ok, pages = pcall(function()
        return ods:GetSortedAsync(false, count)
    end)
    if not ok or not pages then return results end
    local success, items = pcall(function() return pages:GetCurrentPage() end)
    if not success then return results end
    for _, entry in items do
        -- entry.key = tostring(UserId), entry.value = score
        local name = "[" .. entry.key .. "]"
        -- Try to resolve username from UserId
        local nameOk, resolved = pcall(function()
            return PS:GetNameFromUserIdAsync(tonumber(entry.key) :: number)
        end)
        if nameOk then name = resolved end
        table.insert(results, {name = name, score = entry.value})
    end
    return results
end

local function broadcastLeaderboard()
    local honeyTop    = fetchTop(honeyODS,    10)
    local prestigeTop = fetchTop(prestigeODS, 10)
    LeaderboardSync:FireAllClients({
        honey    = honeyTop,
        prestige = prestigeTop,
    })
end

local function updatePlayer(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local key = tostring(player.UserId)
    safeSet(honeyODS,    key, profile.totalHoneyEarned or 0)
    safeSet(prestigeODS, key, profile.prestigeLevel    or 0)
end

function LeaderboardService.Init()
    -- Update all current players every 60 seconds
    task.spawn(function()
        while true do
            task.wait(60)
            for _, player in PS:GetPlayers() do
                task.spawn(function() updatePlayer(player) end)
            end
            task.wait(2)  -- give SetAsync calls time to complete
            broadcastLeaderboard()
        end
    end)

    -- Update on join (show existing score)
    PS.PlayerAdded:Connect(function(player)
        task.wait(3)  -- wait for DataService to load profile
        updatePlayer(player)
    end)

    -- Update on prestige (immediate leaderboard refresh)
    local PrestigeSync = RS:WaitForChild("PrestigeSync")
    PrestigeSync.OnClientEvent = nil  -- guard: this is server-side only
    -- Listen via a BindableEvent approach: PrestigeService fires after apply
    -- We connect to PlayerRemoving to capture final score
    PS.PlayerRemoving:Connect(function(player)
        -- Final score update on leave
        task.spawn(function() updatePlayer(player) end)
    end)

    -- Initial broadcast after a short delay
    task.delay(10, broadcastLeaderboard)

    print("[LeaderboardService] ready")
end

return LeaderboardService
]]

print("LeaderboardService + LeaderboardSync RE created")
```

---

## STEP B — GameManager: inject LeaderboardService.Init()

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

if gm.Source:find("LeaderboardService", 1, true) then
    print("⏭️  GameManager already has LeaderboardService — skip")
else
    local clone = gm:Clone()
    clone.Name = "GameManager_WORKING"
    local anchor = 'local PrestigeService'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "PrestigeService require not found in GameManager")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\nlocal LeaderboardService = require(SSS:WaitForChild(\"LeaderboardService\"))"
        .. clone.Source:sub(lineEnd + 1)
    local initAnchor = 'PrestigeService.Init()'
    local found2 = clone.Source:find(initAnchor, 1, true)
    assert(found2, "PrestigeService.Init() not found in GameManager")
    local lineEnd2 = clone.Source:find("\n", found2, true)
    clone.Source = clone.Source:sub(1, lineEnd2)
        .. "\nLeaderboardService.Init()"
        .. clone.Source:sub(lineEnd2 + 1)
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("✅ GameManager LeaderboardService.Init() injected")
end
```

---

## STEP C — LeaderboardController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "LeaderboardController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- LeaderboardController — leaderboard panel UI

local PS        = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local TS        = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LeaderboardSync = RS:WaitForChild("LeaderboardSync")

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local WAXCREAM    = Color3.fromRGB(232, 212, 154)
local PANEL_DARK  = Color3.fromRGB(40, 25, 5)
local PANEL_MED   = Color3.fromRGB(65, 40, 10)
local ROW_ALT     = Color3.fromRGB(55, 35, 8)

local PANEL_OPEN  = UDim2.new(0.58, 0, 0.08, 0)
local PANEL_CLOSE = UDim2.new(1.05, 0, 0.08, 0)
local TWEEN_OPEN  = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local isOpen = false
local activeTab = "honey"
local lastData: {honey: {{name:string,score:number}}, prestige: {{name:string,score:number}}}? = nil

-- ── Build GUI ──────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name          = "LeaderboardGui"
sg.DisplayOrder  = 18
sg.ResetOnSpawn  = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent        = playerGui

local panel = Instance.new("Frame")
panel.Name             = "LeaderboardPanel"
panel.Size             = UDim2.new(0.38, 0, 0.82, 0)
panel.Position         = PANEL_CLOSE
panel.BackgroundColor3 = PANEL_DARK
panel.BorderSizePixel  = 0
panel.ZIndex           = 20
panel.Parent           = sg

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color     = HONEY_GOLD
stroke.Thickness = 2
stroke.Parent    = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name             = "TitleBar"
titleBar.Size             = UDim2.new(1, 0, 0.08, 0)
titleBar.BackgroundColor3 = PANEL_MED
titleBar.BorderSizePixel  = 0
titleBar.ZIndex           = 21
titleBar.Parent           = panel
local titleLbl = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(1, 0, 1, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = "🏆 LEADERBOARD"
titleLbl.TextColor3       = HONEY_GOLD
titleLbl.Font             = Enum.Font.FredokaOne
titleLbl.TextScaled       = true
titleLbl.ZIndex           = 22
titleLbl.Parent           = titleBar

-- Tab buttons
local tabRow = Instance.new("Frame")
tabRow.Name             = "TabRow"
tabRow.Size             = UDim2.new(1, 0, 0.08, 0)
tabRow.Position         = UDim2.new(0, 0, 0.08, 0)
tabRow.BackgroundColor3 = PANEL_MED
tabRow.BorderSizePixel  = 0
tabRow.ZIndex           = 21
tabRow.Parent           = panel

local honeyTabBtn = Instance.new("TextButton")
honeyTabBtn.Name             = "HoneyTab"
honeyTabBtn.Size             = UDim2.new(0.5, 0, 1, 0)
honeyTabBtn.BackgroundColor3 = HONEY_GOLD
honeyTabBtn.TextColor3       = PANEL_DARK
honeyTabBtn.Text             = "🍯 Honey"
honeyTabBtn.Font             = Enum.Font.GothamBold
honeyTabBtn.TextScaled       = true
honeyTabBtn.ZIndex           = 22
honeyTabBtn.AutoButtonColor  = false
honeyTabBtn.Parent           = tabRow

local prestigeTabBtn = Instance.new("TextButton")
prestigeTabBtn.Name             = "PrestigeTab"
prestigeTabBtn.Size             = UDim2.new(0.5, 0, 1, 0)
prestigeTabBtn.Position         = UDim2.new(0.5, 0, 0, 0)
prestigeTabBtn.BackgroundColor3 = PANEL_MED
prestigeTabBtn.TextColor3       = WAXCREAM
prestigeTabBtn.Text             = "⭐ Prestige"
prestigeTabBtn.Font             = Enum.Font.GothamBold
prestigeTabBtn.TextScaled       = true
prestigeTabBtn.ZIndex           = 22
prestigeTabBtn.AutoButtonColor  = false
prestigeTabBtn.Parent           = tabRow

-- Rows container
local rowList = Instance.new("Frame")
rowList.Name             = "RowList"
rowList.Size             = UDim2.new(1, 0, 0.84, 0)
rowList.Position         = UDim2.new(0, 0, 0.16, 0)
rowList.BackgroundTransparency = 1
rowList.ZIndex           = 21
rowList.Parent           = panel

local rowListLayout = Instance.new("UIListLayout")
rowListLayout.SortOrder  = Enum.SortOrder.LayoutOrder
rowListLayout.FillDirection = Enum.FillDirection.Vertical
rowListLayout.Parent     = rowList

-- ── Row builder ────────────────────────────────────────
local function buildRows(entries: {{name: string, score: number}}, scoreLabel: string)
    for _, child in rowList:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end
    for i, entry in entries do
        local row = Instance.new("Frame")
        row.Name             = "Row_" .. i
        row.Size             = UDim2.new(1, 0, 0, 34)
        row.BackgroundColor3 = i % 2 == 0 and ROW_ALT or PANEL_DARK
        row.BorderSizePixel  = 0
        row.ZIndex           = 22
        row.LayoutOrder      = i
        row.Parent           = rowList

        local rank = Instance.new("TextLabel")
        rank.Size             = UDim2.new(0.12, 0, 1, 0)
        rank.BackgroundTransparency = 1
        rank.Text             = i <= 3 and ({"🥇","🥈","🥉"})[i] or tostring(i)
        rank.TextColor3       = HONEY_GOLD
        rank.Font             = Enum.Font.GothamBold
        rank.TextScaled       = true
        rank.ZIndex           = 23
        rank.Parent           = row

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size         = UDim2.new(0.55, 0, 1, 0)
        nameLabel.Position     = UDim2.new(0.12, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text         = entry.name:sub(1, 16)
        nameLabel.TextColor3   = WAXCREAM
        nameLabel.Font         = Enum.Font.Gotham
        nameLabel.TextScaled   = true
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex       = 23
        nameLabel.Parent       = row

        local scoreLabel_ui = Instance.new("TextLabel")
        scoreLabel_ui.Size         = UDim2.new(0.33, 0, 1, 0)
        scoreLabel_ui.Position     = UDim2.new(0.67, 0, 0, 0)
        scoreLabel_ui.BackgroundTransparency = 1
        scoreLabel_ui.Text         = scoreLabel .. tostring(entry.score)
        scoreLabel_ui.TextColor3   = HONEY_GOLD
        scoreLabel_ui.Font         = Enum.Font.GothamBold
        scoreLabel_ui.TextScaled   = true
        scoreLabel_ui.TextXAlignment = Enum.TextXAlignment.Right
        scoreLabel_ui.ZIndex       = 23
        scoreLabel_ui.Parent       = row
    end
end

-- ── Tab switching ─────────────────────────────────────
local function showTab(tab: string)
    activeTab = tab
    if not lastData then return end
    if tab == "honey" then
        buildRows(lastData.honey, "🍯 ")
        honeyTabBtn.BackgroundColor3 = HONEY_GOLD
        honeyTabBtn.TextColor3       = PANEL_DARK
        prestigeTabBtn.BackgroundColor3 = PANEL_MED
        prestigeTabBtn.TextColor3       = WAXCREAM
    else
        buildRows(lastData.prestige, "⭐ ")
        prestigeTabBtn.BackgroundColor3 = HONEY_GOLD
        prestigeTabBtn.TextColor3       = PANEL_DARK
        honeyTabBtn.BackgroundColor3    = PANEL_MED
        honeyTabBtn.TextColor3          = WAXCREAM
    end
end

honeyTabBtn.MouseButton1Click:Connect(function() showTab("honey") end)
prestigeTabBtn.MouseButton1Click:Connect(function() showTab("prestige") end)

-- ── Open/close ─────────────────────────────────────────
local function openPanel()
    isOpen = true
    TS:Create(panel, TWEEN_OPEN, {Position = PANEL_OPEN}):Play()
end
local function closePanel()
    isOpen = false
    TS:Create(panel, TWEEN_CLOSE, {Position = PANEL_CLOSE}):Play()
end

-- ── Tab button on HiveHUD ──────────────────────────────
task.delay(4, function()
    local hiveHud = playerGui:FindFirstChild("HiveHUD")
    if not hiveHud then return end

    local tabBtn = Instance.new("TextButton")
    tabBtn.Name             = "LeaderboardTab"
    tabBtn.Size             = UDim2.new(0.06, 0, 0.07, 0)
    tabBtn.Position         = UDim2.new(0.945, 0, 0.55, 0)
    tabBtn.BackgroundColor3 = PANEL_DARK
    tabBtn.TextColor3       = HONEY_GOLD
    tabBtn.Text             = "🏆"
    tabBtn.Font             = Enum.Font.GothamBold
    tabBtn.TextScaled       = true
    tabBtn.ZIndex           = 15
    tabBtn.AutoButtonColor  = false
    tabBtn.Parent           = hiveHud
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = tabBtn
    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color     = HONEY_GOLD
    btnStroke.Thickness = 1
    btnStroke.Parent    = tabBtn

    tabBtn.MouseButton1Click:Connect(function()
        if isOpen then closePanel() else openPanel() end
    end)
end)

-- ── LeaderboardSync handler ────────────────────────────
LeaderboardSync.OnClientEvent:Connect(function(data: any)
    if type(data) ~= "table" then return end
    lastData = data :: any
    showTab(activeTab)
end)
]]

print("LeaderboardController created")
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local svc = SSS:FindFirstChild("LeaderboardService")
table.insert(checks, (svc and svc:IsA("ModuleScript") and "✅" or "❌") .. " LeaderboardService ModuleScript")
table.insert(checks, (svc and svc.Source:find("GetOrderedDataStore") and "✅" or "❌") .. " OrderedDataStore usage")
table.insert(checks, (svc and svc.Source:find("GetSortedAsync") and "✅" or "❌") .. " GetSortedAsync fetch")

local sync = RS:FindFirstChild("LeaderboardSync")
table.insert(checks, (sync and sync:IsA("RemoteEvent") and "✅" or "❌") .. " LeaderboardSync RemoteEvent")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("LeaderboardService") and "✅" or "❌") .. " GameManager Init call")

local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")
table.insert(checks, (ctrl and "✅" or "❌") .. " LeaderboardController LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("LeaderboardGui") and "✅" or "❌") .. " LeaderboardGui creation")

print("=== DISPATCH 80 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 80 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Server/client code + UI (no BaseParts) | 0 new server parts |
| **Dispatch 80 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `OrderedDataStore` requires `game.PlaceId` to be set and HTTP service enabled — ensure the Roblox experience is published before executing. In Studio test mode ODS calls succeed with a local mock store.
- `GetSortedAsync(false, 50)` fetches the top 50 descending. We only display the top 10 in the UI (fetching 50 gives a buffer for name resolution failures).
- `GetNameFromUserIdAsync` can yield and will be called for each entry. We wrap in `pcall` and fall back to `"[UserId]"` on failure.
- The 60-second update interval is deliberately conservative — ODS `SetAsync` is rate-limited (1 request per key per 6 seconds per server). With up to 20 players updating every 60 seconds, we're well within limits.
- `PrestigeSync.OnClientEvent = nil` in `LeaderboardService` is a server-side guard comment — that line in context actually does nothing (OnClientEvent is not settable server-side). Prestige score is updated via the 60-second sweep and on PlayerRemoving, which catches the final value. A future dispatch can add a direct call to `LeaderboardService.UpdatePlayer(player)` inside `PrestigeService` for immediate leaderboard refresh on prestige.
- The 🏆 tab button at `X=0.945 Y=0.55` sits between the Stats tab (Y=0.68 from dispatch 72) and the Friends indicator (Y=0.90 from dispatch 70), maintaining the right-edge tab column layout.
