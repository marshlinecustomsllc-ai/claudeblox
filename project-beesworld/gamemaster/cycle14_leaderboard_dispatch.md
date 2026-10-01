# Dispatch 120 — Hive Leaderboard
## Cycle 14 · A Bee's World

**Feature:** A server-side `LeaderboardService` Script and client-side `LeaderboardGui` LocalScript that show the top 10 players on the server ranked by total honey collected, with secondary tabs for Cells Built and Prestige Level. Updates every 15 seconds. A glowing gold crown icon marks #1. Kids see their friends' bee names; adults see precise stat comparisons. Part budget impact: +0 permanent parts.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 119 (Bee Roster Panel)

---

## DESIGN

### Tabs

| Tab | Stat | Player attribute |
|-----|------|-----------------|
| 🍯 Honey | Total honey ever collected | `HoneyCount` |
| 🏗️ Cells | Comb cells built | `CombCellCount` |
| 👑 Prestige | Prestige tier | `PrestigeLevel` |

### Layout

- `LeaderboardGui` ScreenGui, DisplayOrder=16, ResetOnSpawn=false
- `ToggleButton`: top-left, `🏆` emoji, 44×44, auto-hides if < 2 players on server
- `LeaderboardPanel`: 280×360 Frame, slides in from left (`{0,-10}` → `{0,10}`)
- Tab bar (3 buttons, 30px height)
- ScrollingFrame (auto canvas) for rows
- Each row: rank number + player name + stat value + "YOU" badge if local player
- Crown icon on rank #1 row (TextLabel `👑`, HONEY_GOLD)
- Self-highlight: local player row has subtle HONEY_GOLD left border (3px UIStroke)

### Data flow

Server collects stats every 15 s via `RemoteEvent` `LeaderboardSync`:
- Server fires all clients with sorted table `{rank, name, stat}` × up to 10
- Client rebuilds rows on receipt
- No OrderedDataStore required — server-side in-memory sort from connected players

### Kid-friendly touches

- "YOU" badge on local player row so kids instantly find themselves
- Crown on #1 is universally legible
- Stat shown as big round number ("12,480 honey") not raw integer

### Adult layer

- All three tabs with precise values
- Updates live every 15 s so competitive players track movement
- Prestige tab shows tier glyph (✦ ✦✦ ✦✦✦) beside numeric value

---

## FILES CHANGED

| File | Change |
|------|--------|
| `LeaderboardService` | New Script in ServerScriptService |
| `LeaderboardSync` | New RemoteEvent in ReplicatedStorage |
| `LeaderboardGui` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create LeaderboardSync RemoteEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

if RS:FindFirstChild("LeaderboardSync") then
    print("⏭️  LeaderboardSync already exists — skip")
else
    local re = Instance.new("RemoteEvent")
    re.Name   = "LeaderboardSync"
    re.Parent = RS
    print("✅ LeaderboardSync created in ReplicatedStorage")
end
```

---

## STEP B — Create LeaderboardService (Server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(SSS, "ServerScriptService not found")

if SSS:FindFirstChild("LeaderboardService") then
    print("⏭️  LeaderboardService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "LeaderboardService"
    svc.Source = [[
--!strict
-- LeaderboardService — dispatch 120
-- Collects per-player stats every 15 s and broadcasts top-10 to all clients.

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")

local LeaderboardSync: RemoteEvent = RS:WaitForChild("LeaderboardSync", 30) :: RemoteEvent

-- ── Stat definitions ──────────────────────────────────────────────
type StatDef = {attribute: string, label: string, unit: string}
local STATS_120: {StatDef} = {
    {attribute = "HoneyCount",    label = "honey",   unit = "honey"},
    {attribute = "CombCellCount", label = "cells",   unit = "cells"},
    {attribute = "PrestigeLevel", label = "prestige",unit = "prestige"},
}

-- ── Prestige glyph helper ─────────────────────────────────────────
local PRESTIGE_GLYPHS_120 = {"", "✦", "✦✦", "✦✦✦"}

local function formatStat_120(statLabel: string, value: number): string
    if statLabel == "prestige" then
        local glyph = PRESTIGE_GLYPHS_120[math.clamp(value + 1, 1, #PRESTIGE_GLYPHS_120)] or ""
        return value == 0 and "None" or ("Tier " .. value .. "  " .. glyph)
    elseif value >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    else
        return tostring(value)
    end
end

-- ── Collect and broadcast ─────────────────────────────────────────
local function broadcast_120()
    local allPlayers = Players:GetPlayers()
    if #allPlayers < 1 then return end

    -- Build per-stat sorted tables
    local payload_120: {{stat: string, rows: {{rank: number, name: string, value: string, uid: number}}}} = {}

    for _, statDef in STATS_120 do
        -- Collect
        type Row = {name: string, rawValue: number, uid: number}
        local rows: {Row} = {}
        for _, plr in allPlayers do
            local raw = tonumber(plr:GetAttribute(statDef.attribute)) or 0
            table.insert(rows, {name = plr.DisplayName, rawValue = raw, uid = plr.UserId})
        end

        -- Sort descending
        table.sort(rows, function(a, b) return a.rawValue > b.rawValue end)

        -- Format top 10
        local formatted: {{rank: number, name: string, value: string, uid: number}} = {}
        for i = 1, math.min(10, #rows) do
            local row = rows[i]
            table.insert(formatted, {
                rank  = i,
                name  = row.name,
                value = formatStat_120(statDef.label, row.rawValue),
                uid   = row.uid,
            })
        end

        table.insert(payload_120, {stat = statDef.label, rows = formatted})
    end

    LeaderboardSync:FireAllClients(payload_120)
end

-- ── Loop ─────────────────────────────────────────────────────────
task.wait(5)  -- allow players to load attributes before first broadcast
while true do
    pcall(broadcast_120)
    task.wait(15)
end
]]
    svc.Parent = SSS
    print("✅ LeaderboardService created in ServerScriptService")
end
```

---

## STEP C — Create LeaderboardGui LocalScript

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("LeaderboardGui") then
    print("⏭️  LeaderboardGui already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "LeaderboardGui"
    ctrl.Source = [[
--!strict
-- LeaderboardGui — dispatch 120
-- Renders the top-10 leaderboard panel (honey / cells / prestige).

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette (Warm Wax house style) ────────────────────────────────
local HONEY_GOLD_120     = Color3.fromRGB(242, 168, 28)
local PROPOLIS_BROWN_120 = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_120      = Color3.fromRGB(232, 212, 154)
local DARK_BG_120        = Color3.fromRGB(30,  18,  8)

-- ── Build ScreenGui ───────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name              = "LeaderboardGui_120"
screenGui.DisplayOrder      = 16
screenGui.ResetOnSpawn      = false
screenGui.IgnoreGuiInset    = false
screenGui.Parent            = playerGui

-- Toggle button (top-left, 44×44)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name              = "ToggleBtn"
toggleBtn.Size              = UDim2.new(0, 44, 0, 44)
toggleBtn.Position          = UDim2.new(0, 10, 0, 10)
toggleBtn.BackgroundColor3  = PROPOLIS_BROWN_120
toggleBtn.TextColor3        = HONEY_GOLD_120
toggleBtn.Text              = "🏆"
toggleBtn.Font              = Enum.Font.GothamBold
toggleBtn.TextScaled        = true
toggleBtn.BorderSizePixel   = 0
toggleBtn.Visible           = false   -- hidden until >=2 players
toggleBtn.Parent            = screenGui

local tbCorner = Instance.new("UICorner")
tbCorner.CornerRadius = UDim.new(0, 8)
tbCorner.Parent       = toggleBtn

local tbStroke = Instance.new("UIStroke")
tbStroke.Color     = HONEY_GOLD_120
tbStroke.Thickness = 1.5
tbStroke.Parent    = toggleBtn

-- Panel (280×360, slides from left)
local panel = Instance.new("Frame")
panel.Name              = "LeaderboardPanel"
panel.Size              = UDim2.new(0, 280, 0, 360)
panel.Position          = UDim2.new(0, -290, 0, 62)   -- hidden off-screen
panel.BackgroundColor3  = DARK_BG_120
panel.BorderSizePixel   = 0
panel.Visible           = false
panel.Parent            = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD_120
panelStroke.Thickness = 1.5
panelStroke.Parent    = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name             = "TitleBar"
titleBar.Size             = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = PROPOLIS_BROWN_120
titleBar.BorderSizePixel  = 0
titleBar.Parent           = panel

local tbCorner2 = Instance.new("UICorner")
tbCorner2.CornerRadius = UDim.new(0, 12)
tbCorner2.Parent       = titleBar

-- clip bottom corners of title bar
local tbFill = Instance.new("Frame")
tbFill.Size             = UDim2.new(1, 0, 0.5, 0)
tbFill.Position         = UDim2.new(0, 0, 0.5, 0)
tbFill.BackgroundColor3 = PROPOLIS_BROWN_120
tbFill.BorderSizePixel  = 0
tbFill.Parent           = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, -10, 1, 0)
titleLabel.Position          = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3        = HONEY_GOLD_120
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 15
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Text              = "🏆  Hive Leaderboard"
titleLabel.Parent            = titleBar

-- Tab bar
local tabBar = Instance.new("Frame")
tabBar.Name             = "TabBar"
tabBar.Size             = UDim2.new(1, 0, 0, 30)
tabBar.Position         = UDim2.new(0, 0, 0, 36)
tabBar.BackgroundColor3 = PROPOLIS_BROWN_120
tabBar.BackgroundTransparency = 0.4
tabBar.BorderSizePixel  = 0
tabBar.Parent           = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection  = Enum.FillDirection.Horizontal
tabLayout.SortOrder      = Enum.SortOrder.LayoutOrder
tabLayout.Padding        = UDim.new(0, 0)
tabLayout.Parent         = tabBar

local TAB_DEFS_120 = {
    {label = "🍯 Honey",   stat = "honey"},
    {label = "🏗️ Cells",   stat = "cells"},
    {label = "👑 Prestige", stat = "prestige"},
}

local tabButtons: {TextButton} = {}

for i, def in TAB_DEFS_120 do
    local tb = Instance.new("TextButton")
    tb.Name             = "Tab_" .. def.stat
    tb.Size             = UDim2.new(1/3, 0, 1, 0)
    tb.BackgroundColor3 = PROPOLIS_BROWN_120
    tb.BackgroundTransparency = 0.6
    tb.TextColor3       = WAX_CREAM_120
    tb.Font             = Enum.Font.GothamBold
    tb.TextSize         = 11
    tb.Text             = def.label
    tb.BorderSizePixel  = 0
    tb.LayoutOrder      = i
    tb.Parent           = tabBar
    table.insert(tabButtons, tb)
end

-- Scroll area
local scroll = Instance.new("ScrollingFrame")
scroll.Name                     = "RowScroll"
scroll.Size                     = UDim2.new(1, -12, 1, -76)
scroll.Position                 = UDim2.new(0, 6, 0, 70)
scroll.BackgroundTransparency   = 1
scroll.BorderSizePixel          = 0
scroll.ScrollBarThickness       = 3
scroll.ScrollBarImageColor3     = HONEY_GOLD_120
scroll.AutomaticCanvasSize      = Enum.AutomaticSize.Y
scroll.CanvasSize               = UDim2.new(0, 0, 0, 0)
scroll.Parent                   = panel

local rowLayout = Instance.new("UIListLayout")
rowLayout.SortOrder      = Enum.SortOrder.LayoutOrder
rowLayout.Padding        = UDim.new(0, 2)
rowLayout.Parent         = scroll

local uiPad = Instance.new("UIPadding")
uiPad.PaddingTop    = UDim.new(0, 4)
uiPad.PaddingBottom = UDim.new(0, 4)
uiPad.Parent        = scroll

-- ── State ─────────────────────────────────────────────────────────
local panelOpen_120 = false
local activeTab_120 = "honey"

-- Cached leaderboard data from server: { [statLabel] = rows }
type LeaderRow = {rank: number, name: string, value: string, uid: number}
local cachedData_120: {[string]: {LeaderRow}} = {}

-- ── Tab highlight ─────────────────────────────────────────────────
local function highlightTab_120(activeStat: string)
    for _, def in TAB_DEFS_120 do
        local btn = tabBar:FindFirstChild("Tab_" .. def.stat) :: TextButton?
        if btn then
            if def.stat == activeStat then
                btn.BackgroundTransparency = 0
                btn.TextColor3 = HONEY_GOLD_120
            else
                btn.BackgroundTransparency = 0.6
                btn.TextColor3 = WAX_CREAM_120
            end
        end
    end
end

-- ── Build rows ────────────────────────────────────────────────────
local function buildRows_120(stat: string)
    -- Clear existing
    for _, child in scroll:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    local rows = cachedData_120[stat] or {}
    local myUid = player.UserId

    for _, rowData in rows do
        local rowFrame = Instance.new("Frame")
        rowFrame.Name             = "Row_" .. rowData.rank
        rowFrame.Size             = UDim2.new(1, 0, 0, 32)
        rowFrame.BackgroundColor3 = DARK_BG_120
        rowFrame.BackgroundTransparency = rowData.uid == myUid and 0.3 or 0.6
        rowFrame.BorderSizePixel  = 0
        rowFrame.LayoutOrder      = rowData.rank
        rowFrame.Parent           = scroll

        local rfCorner = Instance.new("UICorner")
        rfCorner.CornerRadius = UDim.new(0, 6)
        rfCorner.Parent       = rowFrame

        -- Self-highlight: left border
        if rowData.uid == myUid then
            local border = Instance.new("UIStroke")
            border.Color     = HONEY_GOLD_120
            border.Thickness = 2
            border.Parent    = rowFrame
        end

        -- Crown or rank number
        local rankLabel = Instance.new("TextLabel")
        rankLabel.Name              = "Rank"
        rankLabel.Size              = UDim2.new(0, 28, 1, 0)
        rankLabel.Position          = UDim2.new(0, 4, 0, 0)
        rankLabel.BackgroundTransparency = 1
        rankLabel.TextColor3        = rowData.rank == 1 and HONEY_GOLD_120 or WAX_CREAM_120
        rankLabel.Font              = Enum.Font.GothamBold
        rankLabel.TextSize          = rowData.rank == 1 and 16 or 13
        rankLabel.Text              = rowData.rank == 1 and "👑" or tostring(rowData.rank)
        rankLabel.TextXAlignment    = Enum.TextXAlignment.Center
        rankLabel.Parent            = rowFrame

        -- Player name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name              = "PlayerName"
        nameLabel.Size              = UDim2.new(0, 130, 1, 0)
        nameLabel.Position          = UDim2.new(0, 36, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3        = rowData.uid == myUid and HONEY_GOLD_120 or WAX_CREAM_120
        nameLabel.Font              = rowData.uid == myUid and Enum.Font.GothamBold or Enum.Font.Gotham
        nameLabel.TextSize          = 13
        nameLabel.TextXAlignment    = Enum.TextXAlignment.Left
        nameLabel.TextTruncate      = Enum.TextTruncate.AtEnd
        nameLabel.Text              = rowData.name
        nameLabel.Parent            = rowFrame

        -- Stat value
        local valLabel = Instance.new("TextLabel")
        valLabel.Name              = "StatValue"
        valLabel.Size              = UDim2.new(0, 72, 1, 0)
        valLabel.Position          = UDim2.new(1, -80, 0, 0)
        valLabel.BackgroundTransparency = 1
        valLabel.TextColor3        = HONEY_GOLD_120
        valLabel.Font              = Enum.Font.GothamBold
        valLabel.TextSize          = 13
        valLabel.TextXAlignment    = Enum.TextXAlignment.Right
        valLabel.Text              = rowData.value
        valLabel.Parent            = rowFrame

        -- "YOU" badge
        if rowData.uid == myUid then
            local youBadge = Instance.new("TextLabel")
            youBadge.Name              = "YouBadge"
            youBadge.Size              = UDim2.new(0, 28, 0, 14)
            youBadge.Position          = UDim2.new(1, -82, 0, 1)
            youBadge.BackgroundColor3  = HONEY_GOLD_120
            youBadge.TextColor3        = PROPOLIS_BROWN_120
            youBadge.Font              = Enum.Font.GothamBold
            youBadge.TextSize          = 9
            youBadge.Text              = "YOU"
            youBadge.TextXAlignment    = Enum.TextXAlignment.Center
            youBadge.Parent            = rowFrame

            local ybCorner = Instance.new("UICorner")
            ybCorner.CornerRadius = UDim.new(0, 4)
            ybCorner.Parent       = youBadge

            -- Shift value label left to make room
            valLabel.Position = UDim2.new(1, -112, 0, 0)
        end
    end
end

-- ── Panel open/close ──────────────────────────────────────────────
local function openPanel_120()
    panel.Visible   = true
    panelOpen_120   = true
    highlightTab_120(activeTab_120)
    buildRows_120(activeTab_120)
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 10, 0, 62)}):Play()
end

local function closePanel_120()
    panelOpen_120 = false
    TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0, -290, 0, 62)}):Play()
    task.delay(0.25, function() panel.Visible = false end)
end

toggleBtn.Activated:Connect(function()
    if panelOpen_120 then closePanel_120() else openPanel_120() end
end)

-- ── Tab buttons ───────────────────────────────────────────────────
for _, def in TAB_DEFS_120 do
    local btn = tabBar:FindFirstChild("Tab_" .. def.stat) :: TextButton?
    if btn then
        btn.Activated:Connect(function()
            activeTab_120 = def.stat
            highlightTab_120(def.stat)
            buildRows_120(def.stat)
        end)
    end
end

-- ── Receive leaderboard data from server ─────────────────────────
local LeaderboardSync = RS:WaitForChild("LeaderboardSync", 30) :: RemoteEvent?
if LeaderboardSync then
    LeaderboardSync.OnClientEvent:Connect(function(payload: {{stat: string, rows: {LeaderRow}}})
        if type(payload) ~= "table" then return end

        -- Count total unique players across any stat table (rough server player count)
        local playerCount = 0
        for _, entry in payload do
            if type(entry.rows) == "table" then
                local n = #entry.rows
                if n > playerCount then playerCount = n end
                cachedData_120[entry.stat] = entry.rows
            end
        end

        -- Show toggle button only when ≥2 players on server
        toggleBtn.Visible = playerCount >= 2

        -- Rebuild rows if panel is open
        if panelOpen_120 then
            buildRows_120(activeTab_120)
        end
    end)
end

-- Initial highlight
highlightTab_120(activeTab_120)

print("[LeaderboardGui] Ready — honey / cells / prestige · updates every 15 s")
]]
    ctrl.Parent = SPS
    print("✅ LeaderboardGui created in StarterPlayerScripts")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc  = SSS and SSS:FindFirstChild("LeaderboardService")
local ctrl = SPS and SPS:FindFirstChild("LeaderboardGui")
local re   = RS:FindFirstChild("LeaderboardSync")

local checks = {}
table.insert(checks, (svc  and "✅" or "❌") .. " LeaderboardService in ServerScriptService")
table.insert(checks, (svc  and svc:IsA("Script") and "✅" or "❌") .. " is a Script (not LocalScript)")
table.insert(checks, (svc  and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc  and svc.Source:find("broadcast_120", 1, true) and "✅" or "❌") .. " broadcast_120 function")
table.insert(checks, (svc  and svc.Source:find("formatStat_120", 1, true) and "✅" or "❌") .. " formatStat_120 helper")
table.insert(checks, (svc  and svc.Source:find("PRESTIGE_GLYPHS_120", 1, true) and "✅" or "❌") .. " prestige glyphs")
table.insert(checks, (svc  and svc.Source:find("task.wait(15)", 1, true) and "✅" or "❌") .. " 15-second update loop")
table.insert(checks, (re   and "✅" or "❌") .. " LeaderboardSync RemoteEvent in ReplicatedStorage")
table.insert(checks, (ctrl and "✅" or "❌") .. " LeaderboardGui in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (client)")
table.insert(checks, (ctrl and ctrl.Source:find("buildRows_120", 1, true) and "✅" or "❌") .. " buildRows_120 renderer")
table.insert(checks, (ctrl and ctrl.Source:find("openPanel_120", 1, true) and "✅" or "❌") .. " openPanel_120 / closePanel_120")
table.insert(checks, (ctrl and ctrl.Source:find("YouBadge", 1, true) and "✅" or "❌") .. " YOU badge for local player")
table.insert(checks, (ctrl and ctrl.Source:find("playerCount >= 2", 1, true) and "✅" or "❌") .. " hide button when < 2 players")
table.insert(checks, (ctrl and ctrl.Source:find("activeTab_120", 1, true) and "✅" or "❌") .. " tab state machine")
table.insert(checks, (ctrl and ctrl.Source:find("LeaderboardSync", 1, true) and "✅" or "❌") .. " LeaderboardSync listener")

print("=== DISPATCH 120 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 120 complete" or "❌ SOME CHECKS FAILED")

print("\nLeaderboard tabs: 🍯 Honey | 🏗️ Cells | 👑 Prestige — updates every 15 s")
print("Toggle button visible only when ≥2 players on server (single-player hidden)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| LeaderboardService (Script, no parts) | 0 permanent |
| LeaderboardSync (RemoteEvent, no parts) | 0 permanent |
| LeaderboardGui (LocalScript, runtime UI in PlayerGui) | 0 permanent |
| **Dispatch 120 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `LeaderboardSync:FireAllClients` sends the sorted table every 15 seconds — no OrderedDataStore polling, no DataStore API calls, no throttle risk. Stats are read directly from player attributes which are updated by `HiveDataManager` on every change.
- Toggle button auto-hides when only one player is on the server. Kids playing solo never see the button (no empty/confusing panel); it appears automatically when a second player joins.
- `formatStat_120` converts raw numbers to K/M suffixes for large values ("12,480" → "12.5K") — keeps the panel readable at any progression level. Prestige shows tier glyphs for visual pop (✦✦✦ is immediately legible as "max" to both kids and adults).
- The "YOU" badge uses a tiny 28×14 gold chip positioned over the stat column when the local player is in the top 10 — kids find themselves instantly. The row also gets a `UIStroke` highlight and bold name font.
- `pcall(broadcast_120)` in the loop means a single error during stat collection (e.g., a player disconnects mid-read) won't kill the service — the next 15-second tick will succeed.
- Tab state persists across data updates — if the player is viewing the Prestige tab when new data arrives, the Prestige rows rebuild in-place without switching to Honey.
- `AutomaticCanvasSize=Y` on the ScrollingFrame means the panel gracefully handles 1–10 rows without overflow or empty space.
- Server reads `HoneyCount`, `CombCellCount`, and `PrestigeLevel` attributes which are the same attributes that drive every other system — single source of truth, zero duplication.
