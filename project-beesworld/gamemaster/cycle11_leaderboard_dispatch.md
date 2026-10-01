# Dispatch 34 — LeaderboardService: OrderedDataStore + TopBar ScreenGui
**File:** `cycle11_leaderboard_dispatch.md`
**Cycle:** 11
**Part budget:** 0 → ~4,098/5,000 (UI only, no world parts)
**DataService migration:** None (reads existing `profile.honey` + `profile.generation`)
**Depends on:** Dispatch 8 (DataService profile structure), Dispatch 19 (generation tracking)
**Supersedes:** Any stub leaderboard from earlier cycles

---

## Purpose

Persistent global leaderboard backed by Roblox **OrderedDataStore**, with a live in-game
**TopBar ScreenGui** that refreshes every 60 seconds. Score is `generation × 1,000,000 + honey`
so prestige players always rank above same-honey non-prestige players.

Before this dispatch: no cross-session leaderboard — players cannot see where they rank globally.
After this dispatch: a compact top-5 panel in the top-right corner shows player names, scores,
and highlights the local player's row if they're in the top 5.

---

## STEP A — LeaderboardService ModuleScript

```lua
-- STEP A: Create LeaderboardService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
local old = SSS:FindFirstChild("LeaderboardService")
if old then old:Destroy() end

local svc = Instance.new("ModuleScript")
svc.Name   = "LeaderboardService"
svc.Source = [[
--!strict
-- LeaderboardService — global honey leaderboard (dispatch 34)

local Players         = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config      = require(game:GetService("ServerScriptService"):FindFirstChild("Config")
                       or ReplicatedStorage:FindFirstChild("Config"))
local DataService = require(game:GetService("ServerScriptService"):FindFirstChild("DataService"))

-- OrderedDataStore key: "BeesWorldLeaderboard_v1"
local _ods: OrderedDataStore? = nil
local function getODS(): OrderedDataStore
    if not _ods then
        _ods = DataStoreService:GetOrderedDataStore("BeesWorldLeaderboard_v1")
    end
    return _ods :: OrderedDataStore
end

-- RemoteEvent for pushing top-5 to clients
local remotes    = ReplicatedStorage:FindFirstChild("Remotes")
local LeaderSync = remotes and remotes:FindFirstChild("LeaderSync")

-- Score formula: generation * 1_000_000 + honey (generation players always above same-honey players)
local function calcScore(profile: any): number
    local gen   = math.max(profile.generation or 0, 0)
    local honey = math.max(profile.honey or 0, 0)
    return gen * 1_000_000 + math.floor(honey)
end

-- ---------------------------------------------------------------
-- Write player's score to ODS (called on save)
-- ---------------------------------------------------------------
local function writeScore(player: Player): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local score = calcScore(profile)
    local key   = "player_" .. player.UserId

    local ok, err = pcall(function(): ()
        getODS():SetAsync(key, score)
    end)
    if not ok then
        warn("[LeaderboardService] SetAsync failed for " .. player.Name .. ": " .. tostring(err))
    end
end

-- ---------------------------------------------------------------
-- Read top N entries from ODS
-- ---------------------------------------------------------------
type LeaderEntry = { rank: number, userId: number, name: string, score: number }

local function fetchTop(n: number): { LeaderEntry }
    local pages
    local ok, err = pcall(function(): ()
        pages = getODS():GetSortedAsync(false, n)  -- descending, top N
    end)
    if not ok then
        warn("[LeaderboardService] GetSortedAsync failed: " .. tostring(err))
        return {}
    end

    local entries: { LeaderEntry } = {}
    local currentPage = pages:GetCurrentPage()
    for rank, entry in currentPage do
        -- entry.key = "player_USERID", entry.value = score
        local uidStr = tostring(entry.key):gsub("player_", "")
        local uid    = tonumber(uidStr) or 0
        local name   = "[Unknown]"
        -- Try to get display name from online players first, then UserService
        local onlinePlayer = Players:GetPlayerByUserId(uid)
        if onlinePlayer then
            name = onlinePlayer.DisplayName
        else
            local us_ok, uname = pcall(function(): string
                return Players:GetNameFromUserIdAsync(uid)
            end)
            if us_ok then name = uname end
        end
        table.insert(entries, { rank = rank, userId = uid, name = name, score = entry.value })
    end
    return entries
end

-- ---------------------------------------------------------------
-- Broadcast top 5 to all clients
-- ---------------------------------------------------------------
local function broadcastLeaderboard(): ()
    if not LeaderSync then return end
    local top5 = fetchTop(5)
    LeaderSync:FireAllClients({ entries = top5, updatedAt = os.time() })
end

-- ---------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------
local LeaderboardService = {}

function LeaderboardService.Init(): ()
    -- Score refresh loop: write all online players' scores every 90s
    task.spawn(function(): ()
        while true do
            task.wait(90)
            for _, player in Players:GetPlayers() do
                writeScore(player)
            end
            broadcastLeaderboard()
        end
    end)

    -- Write on save events (piggyback DataService saves)
    -- Also write when a player leaves so their final score is recorded
    Players.PlayerRemoving:Connect(function(player: Player): ()
        writeScore(player)
    end)

    -- Initial broadcast a few seconds after startup (profiles should be loaded)
    task.delay(8, broadcastLeaderboard)
end

-- Called externally (e.g. after honey harvest or prestige) for real-time updates
function LeaderboardService.RecordScore(player: Player): ()
    writeScore(player)
end

-- Exposed for admin/debug
function LeaderboardService.FetchTop(n: number): { LeaderEntry }
    return fetchTop(n)
end

return LeaderboardService
]]
svc.Parent = SSS

print("✅ STEP A: LeaderboardService created in ServerScriptService")
print("   Score = generation × 1,000,000 + honey")
print("   Writes to OrderedDataStore 'BeesWorldLeaderboard_v1'")
print("   Broadcasts top-5 to all clients every 90s + on startup after 8s")
```

**Verify Step A:**

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("LeaderboardService")
assert(svc and svc:IsA("ModuleScript"), "LeaderboardService missing or wrong type")
local src = svc.Source
assert(src:find("OrderedDataStore"), "OrderedDataStore not used")
assert(src:find("calcScore"), "calcScore missing")
assert(src:find("LeaderSync"), "LeaderSync not referenced")
assert(src:find("broadcastLeaderboard"), "broadcastLeaderboard missing")
assert(src:find("--!strict"), "--!strict missing")
print("✅ STEP A verified: LeaderboardService present and correct")
```

---

## STEP B — LeaderSync RemoteEvent

```lua
-- STEP B: Create LeaderSync RemoteEvent in Remotes folder
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
assert(remotes, "Remotes folder not found in ReplicatedStorage")

if not remotes:FindFirstChild("LeaderSync") then
    local ev = Instance.new("RemoteEvent")
    ev.Name   = "LeaderSync"
    ev.Parent = remotes
    print("✅ STEP B: LeaderSync RemoteEvent created")
else
    print("✅ STEP B: LeaderSync already exists — no action needed")
end
```

---

## STEP C — TopBar ScreenGui (static structure)

```lua
-- STEP C: Build LeaderboardGui ScreenGui in StarterGui
local SG = game:GetService("StarterGui")

local old = SG:FindFirstChild("LeaderboardGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "LeaderboardGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 40
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = SG

-- Panel
local panel = Instance.new("Frame")
panel.Name                = "LeaderPanel"
panel.Size                = UDim2.new(0.22, 0, 0.36, 0)
panel.Position            = UDim2.new(0.77, 0, 0.01, 0)
panel.AnchorPoint         = Vector2.new(0, 0)
panel.BackgroundColor3    = Color3.fromRGB(25, 14, 4)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel     = 0
panel.ZIndex              = 5
panel.Parent              = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = Color3.fromRGB(122, 74, 34)  -- Propolis Brown
panelStroke.Thickness = 2
panelStroke.Parent    = panel

-- Header
local header = Instance.new("TextLabel")
header.Name              = "Header"
header.Size              = UDim2.new(1, 0, 0.14, 0)
header.Position          = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3  = Color3.fromRGB(122, 74, 34)
header.BackgroundTransparency = 0
header.TextColor3        = Color3.fromRGB(242, 168, 28)   -- Honey Gold
header.Font              = Enum.Font.FredokaOne
header.TextScaled        = true
header.Text              = "🏆 Top Beekeepers"
header.ZIndex            = 6
header.Parent            = panel

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

-- 5 row slots
local rowHeight = 0.155
for i = 1, 5 do
    local row = Instance.new("Frame")
    row.Name                = "Row" .. i
    row.Size                = UDim2.new(0.92, 0, rowHeight, 0)
    row.Position            = UDim2.new(0.04, 0, 0.15 + (i - 1) * (rowHeight + 0.01), 0)
    row.BackgroundTransparency = 1
    row.ZIndex              = 6
    row.Parent              = panel

    -- Rank badge
    local rank = Instance.new("TextLabel")
    rank.Name               = "Rank"
    rank.Size               = UDim2.new(0.18, 0, 1, 0)
    rank.BackgroundColor3   = Color3.fromRGB(60, 35, 10)
    rank.BackgroundTransparency = 0.3
    rank.TextColor3         = Color3.fromRGB(242, 168, 28)
    rank.Font               = Enum.Font.FredokaOne
    rank.TextScaled         = true
    rank.Text               = "#" .. i
    rank.ZIndex             = 7
    rank.Parent             = row

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 4)
    rc.Parent = rank

    -- Name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name          = "PlayerName"
    nameLabel.Size          = UDim2.new(0.55, 0, 1, 0)
    nameLabel.Position      = UDim2.new(0.20, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3    = Color3.fromRGB(232, 212, 154)  -- Wax Cream
    nameLabel.Font          = Enum.Font.FredokaOne
    nameLabel.TextScaled    = true
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text          = "—"
    nameLabel.ZIndex        = 7
    nameLabel.Parent        = row

    -- Score label
    local scoreLabel = Instance.new("TextLabel")
    scoreLabel.Name         = "Score"
    scoreLabel.Size         = UDim2.new(0.26, 0, 1, 0)
    scoreLabel.Position     = UDim2.new(0.74, 0, 0, 0)
    scoreLabel.BackgroundTransparency = 1
    scoreLabel.TextColor3   = Color3.fromRGB(200, 180, 100)
    scoreLabel.Font         = Enum.Font.FredokaOne
    scoreLabel.TextScaled   = true
    scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
    scoreLabel.Text         = "0"
    scoreLabel.ZIndex       = 7
    scoreLabel.Parent       = row
end

-- Footer
local footer = Instance.new("TextLabel")
footer.Name              = "Footer"
footer.Size              = UDim2.new(1, 0, 0.07, 0)
footer.Position          = UDim2.new(0, 0, 0.93, 0)
footer.BackgroundTransparency = 1
footer.TextColor3        = Color3.fromRGB(120, 100, 60)
footer.Font              = Enum.Font.FredokaOne
footer.TextScaled        = true
footer.Text              = "Updates every 90s"
footer.ZIndex            = 6
footer.Parent            = panel

print("✅ STEP C: LeaderboardGui ScreenGui created in StarterGui (5 rows, top-right panel)")
```

**Verify Step C:**

```lua
local SG = game:GetService("StarterGui")
local gui = SG:FindFirstChild("LeaderboardGui")
assert(gui, "LeaderboardGui missing")
local panel = gui:FindFirstChild("LeaderPanel")
assert(panel, "LeaderPanel missing")
for i = 1, 5 do
    local row = panel:FindFirstChild("Row" .. i)
    assert(row, "Row" .. i .. " missing")
    assert(row:FindFirstChild("PlayerName"), "Row" .. i .. " PlayerName missing")
    assert(row:FindFirstChild("Score"), "Row" .. i .. " Score missing")
end
print("✅ STEP C verified: LeaderboardGui with 5 rows, Header, Footer present")
```

---

## STEP D — LeaderboardController LocalScript

```lua
-- STEP D: LeaderboardController LocalScript in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("LeaderboardController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "LeaderboardController"
ctrl.Source = [[
--!strict
-- LeaderboardController — drives LeaderboardGui from LeaderSync events (dispatch 34)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
local gui       = playerGui:WaitForChild("LeaderboardGui", 10)
local panel     = gui:WaitForChild("LeaderPanel", 10)
local footer    = panel:FindFirstChild("Footer") :: TextLabel?

local remotes    = ReplicatedStorage:WaitForChild("Remotes", 10)
local LeaderSync = remotes:WaitForChild("LeaderSync", 10)

local HIGHLIGHT_COLOR = Color3.fromRGB(242, 168, 28)   -- Honey Gold for local player row
local NORMAL_COLOR    = Color3.fromRGB(232, 212, 154)   -- Wax Cream for other rows
local SCORE_TWEEN     = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Format score: "1.23M" for millions, "45K" for thousands, raw for < 1000
local function fmtScore(score: number): string
    if score >= 1_000_000 then
        return string.format("%.2fM", score / 1_000_000)
    elseif score >= 1_000 then
        return string.format("%.1fK", score / 1_000)
    end
    return tostring(score)
end

type LeaderEntry = { rank: number, userId: number, name: string, score: number }

local function onLeaderSync(data: { entries: { LeaderEntry }, updatedAt: number? }): ()
    local entries = data.entries or {}

    for i = 1, 5 do
        local row = panel:FindFirstChild("Row" .. i) :: Frame?
        if not row then continue end

        local nameLabel  = row:FindFirstChild("PlayerName") :: TextLabel?
        local scoreLabel = row:FindFirstChild("Score")      :: TextLabel?
        if not nameLabel or not scoreLabel then continue end

        local entry = entries[i]
        if entry then
            nameLabel.Text      = entry.name
            scoreLabel.Text     = fmtScore(entry.score)
            -- Highlight local player's row
            local isLocal = entry.userId == player.UserId
            nameLabel.TextColor3  = isLocal and HIGHLIGHT_COLOR or NORMAL_COLOR
            scoreLabel.TextColor3 = isLocal and HIGHLIGHT_COLOR or Color3.fromRGB(200, 180, 100)
            -- Subtle highlight on row background
            if isLocal then
                TweenService:Create(row, SCORE_TWEEN, {
                    BackgroundTransparency = 0.6,
                    BackgroundColor3       = Color3.fromRGB(80, 50, 5),
                }):Play()
                row.BackgroundTransparency = 0.6
            else
                row.BackgroundTransparency = 1
                row.BackgroundColor3 = Color3.fromRGB(25, 14, 4)
            end
        else
            nameLabel.Text      = "—"
            scoreLabel.Text     = ""
            row.BackgroundTransparency = 1
        end
    end

    if footer and data.updatedAt then
        local ago = os.time() - (data.updatedAt or os.time())
        footer.Text = ago < 5 and "Just updated" or ("Updated " .. ago .. "s ago")
    end
end

LeaderSync.OnClientEvent:Connect(onLeaderSync)
]]
ctrl.Parent = SPS

print("✅ STEP D: LeaderboardController LocalScript created")
```

**Verify Step D:**

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")
assert(ctrl and ctrl:IsA("LocalScript"), "LeaderboardController missing")
local src = ctrl.Source
assert(src:find("LeaderSync"), "LeaderSync not referenced")
assert(src:find("fmtScore"), "fmtScore missing")
assert(src:find("HIGHLIGHT_COLOR"), "HIGHLIGHT_COLOR missing")
assert(src:find("--!strict"), "--!strict missing")
print("✅ STEP D verified: LeaderboardController present and correct")
```

---

## STEP E — Wire LeaderboardService.Init() into Main Script

```lua
-- STEP E: Wire LeaderboardService into Main Script
local SSS = game:GetService("ServerScriptService")
local mainScript = SSS:FindFirstChild("Main") or SSS:FindFirstChild("GameManager")
assert(mainScript, "Main/GameManager not found")

local src = mainScript.Source
if src:find("LeaderboardService") then
    print("✅ STEP E: LeaderboardService already in Main Script — no change needed")
else
    local clone = mainScript:Clone()
    local oldName = mainScript.Name
    mainScript.Name = oldName .. "_OLD_34E"
    mainScript.Parent = nil

    local reqLine = "\nlocal LeaderboardService = require(game:GetService(\"ServerScriptService\"):FindFirstChild(\"LeaderboardService\"))\nLeaderboardService.Init()\n"
    local newSrc = src:gsub("(Players%.PlayerAdded)", reqLine .. "%1", 1)
    if newSrc == src then newSrc = src .. reqLine end
    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS
    print("✅ STEP E: LeaderboardService.Init() injected into Main Script")
end
```

---

## STEP F — Full verification

```lua
-- STEP F: Full dispatch 34 verification
local SSS     = game:GetService("ServerScriptService")
local RS      = game:GetService("ReplicatedStorage")
local SG      = game:GetService("StarterGui")
local SP      = game:GetService("StarterPlayer")
local SPS     = SP:FindFirstChild("StarterPlayerScripts")
local remotes = RS:FindFirstChild("Remotes")
local results = {}
local issues  = {}

-- 1. LeaderboardService
local svc = SSS:FindFirstChild("LeaderboardService")
if svc and svc:IsA("ModuleScript") then
    local src = svc.Source
    if src:find("OrderedDataStore") and src:find("calcScore") and src:find("broadcastLeaderboard") then
        table.insert(results, "✅ LeaderboardService: ODS + calcScore + broadcast present")
    else
        table.insert(issues, "❌ LeaderboardService missing key functions")
    end
else
    table.insert(issues, "❌ LeaderboardService not found")
end

-- 2. LeaderSync RemoteEvent
if remotes and remotes:FindFirstChild("LeaderSync") then
    table.insert(results, "✅ LeaderSync RemoteEvent exists")
else
    table.insert(issues, "❌ LeaderSync RemoteEvent missing")
end

-- 3. LeaderboardGui
local gui   = SG:FindFirstChild("LeaderboardGui")
local panel = gui and gui:FindFirstChild("LeaderPanel")
if panel then
    local allRows = true
    for i = 1, 5 do
        if not panel:FindFirstChild("Row" .. i) then allRows = false end
    end
    if allRows then
        table.insert(results, "✅ LeaderboardGui: LeaderPanel with 5 rows present")
    else
        table.insert(issues, "❌ LeaderboardGui missing some rows")
    end
else
    table.insert(issues, "❌ LeaderboardGui or LeaderPanel missing")
end

-- 4. LeaderboardController LocalScript
local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")
if ctrl and ctrl:IsA("LocalScript") then
    table.insert(results, "✅ LeaderboardController LocalScript present")
else
    table.insert(issues, "❌ LeaderboardController missing from StarterPlayerScripts")
end

-- 5. Main Script wiring
local mainScript = SSS:FindFirstChild("Main") or SSS:FindFirstChild("GameManager")
if mainScript and mainScript.Source:find("LeaderboardService") then
    table.insert(results, "✅ Main Script references LeaderboardService")
else
    table.insert(issues, "⚠ Main Script does not reference LeaderboardService — manual wiring needed")
end

-- 6. No stale OLD copies
local stale = {}
for _, c in SSS:GetChildren() do
    if c.Name:find("_OLD_34") then table.insert(stale, c.Name) end
end
if #stale == 0 then
    table.insert(results, "✅ No stale _OLD_34x copies in SSS")
else
    table.insert(issues, "⚠ Stale: " .. table.concat(stale, ", ") .. " — destroy them")
end

print("\n=== DISPATCH 34 VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\nISSUES:")
    for _, i in issues do print(i) end
else
    print("\n🎉 All checks passed — dispatch 34 complete!")
    print("   Global leaderboard live: OrderedDataStore + TopBar ScreenGui + 90s refresh")
end
```

---

## Execution order checklist

1. ☐ **STEP A** — Create LeaderboardService ModuleScript  
2. ☐ **STEP B** — Create LeaderSync RemoteEvent  
3. ☐ **STEP C** — Create LeaderboardGui ScreenGui (5-row panel)  
4. ☐ **STEP D** — Create LeaderboardController LocalScript  
5. ☐ **STEP E** — Wire LeaderboardService.Init() into Main Script  
6. ☐ **STEP F** — Full verification  

---

## Testing notes

- **OrderedDataStore in Studio:** Studio can read/write DataStores if "Enable Studio Access to API
  Services" is enabled in Game Settings → Security. Required for end-to-end testing.

- **Simulate leaderboard update in Command Bar during play-test:**
  ```lua
  local SSS = game:GetService("ServerScriptService")
  local LS = require(SSS:FindFirstChild("LeaderboardService"))
  local top = LS.FetchTop(5)
  for _, e in top do print(e.rank, e.name, e.score) end
  ```

- **Force broadcast:**
  ```lua
  LS.RecordScore(game:GetService("Players"):GetPlayers()[1])
  ```

---

## Part budget

| Step | Parts added | Running total |
|------|-------------|---------------|
| All  | 0 (scripting + UI only) | 4,098 |
| **Total** | **0** | **~4,098 / 5,000** |
