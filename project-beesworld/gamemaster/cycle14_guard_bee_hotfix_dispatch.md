# Dispatch 142 — Guard Bee Integration Hotfix + Leaderboard
## Cycle 14 · A Bee's World

**Feature (Part A):** Update `BearAttackService` to also check `SpecialistBees` for `"guard_bee"` when calculating bear drain — stacking with `hive_insulation` for full mitigation math. **Feature (Part B):** A `LeaderboardController` LocalScript that shows a live top-5 honey leaderboard in the right-side HUD column. Kids see their ranking and want to climb it; adults optimize for the top spot. Part budget: +0 permanent (both are edits/new LocalScript only).
**Part budget impact:** +0 permanent → **4,149 / 5,000**
**Execution order:** After dispatch 141 (Bee Roster Expansion)

---

## DESIGN

### Part A — Guard Bee drain stacking

Current BearAttackService drain formula (dispatch 139):
```lua
local drainPct = upgrades:find("hive_insulation") and 0.10 or 0.15
```

Updated formula:
```lua
local hasInsulation = upgrades:find("hive_insulation") ~= nil
local hasGuard      = tostring(player:GetAttribute("SpecialistBees") or ""):find("guard_bee") ~= nil
local drainPct = 0.15
if hasInsulation then drainPct = drainPct - 0.05 end  -- 0.15 → 0.10
if hasGuard      then drainPct = drainPct - 0.05 end  -- 0.10 → 0.05 (or 0.15 → 0.10)
drainPct = math.max(0.05, drainPct)                    -- floor: minimum 5% drain always
```

This is a 3-line source edit to `BearAttackService` via Command Bar.

### Part B — Honey Leaderboard

A compact leaderboard in the right-side column (below the existing Goals / Bee Roster / Guide buttons) showing top-5 players by `HoneyCount`:

- Position: `{1,-160,1,-4}` (below the Guide button at `{1,-160,1,-56}`), anchored bottom-right
- Size: `{0,152,0,148}` — 5 rows of 24px + header 20px + 8px padding
- Background: `Color3.fromRGB(40,25,8)` at `BackgroundTransparency=0.1`, UICorner 8px
- Header: `"🍯 Top Honey"` GothamBold 12, amber
- Rows: rank emoji (🥇🥈🥉4️⃣5️⃣) + player name (truncated at 10 chars) + honey count (K-formatted)
- Updates every 10s via `Players:GetPlayers()` client-side sort — no server call needed for a small server (max ~20 players in a tycoon)
- Current player's row highlighted with amber background

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BearAttackService` | Edit drain formula (+Guard Bee check) |
| `LeaderboardController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Patch BearAttackService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("BearAttackService")
assert(svc, "BearAttackService not found — run dispatch 139 first")

-- Replace the drain calculation line
local old = [[local drainPct = upgrades:find("hive_insulation") and 0.10 or 0.15]]
local new = [[
            local hasInsulation_142 = upgrades:find("hive_insulation") ~= nil
            local hasGuard_142      = tostring(player:GetAttribute("SpecialistBees") or ""):find("guard_bee") ~= nil
            local drainPct = 0.15
            if hasInsulation_142 then drainPct = drainPct - 0.05 end
            if hasGuard_142      then drainPct = drainPct - 0.05 end
            drainPct = math.max(0.05, drainPct)]]

if svc.Source:find(old, 1, true) then
    svc.Source = svc.Source:gsub(old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), new:gsub("%%","%%%%"), 1)
    print("✅ BearAttackService patched — Guard Bee drain stacking active")
elseif svc.Source:find("hasInsulation_142", 1, true) then
    print("⏭️  BearAttackService already has Guard Bee patch — skip")
else
    print("⚠️  Old drain line not found — BearAttackService may have different source; patch manually")
end
```

---

## STEP B — Create LeaderboardController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("LeaderboardController") then
    print("⏭️  LeaderboardController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "LeaderboardController"
    ctrl.Source = [[
--!strict
-- LeaderboardController — dispatch 142
-- Live top-5 honey leaderboard in the right-side HUD column.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local DARK_142  = Color3.fromRGB(40,  25,   8)
local AMBER_142 = Color3.fromRGB(242, 168, 28)
local WHITE_142 = Color3.fromRGB(255, 255, 255)
local HILI_142  = Color3.fromRGB(80,  50,  15)

local RANK_EMOJIS_142 = {"🥇","🥈","🥉","4️⃣","5️⃣"}

-- ── GUI ──────────────────────────────────────────────────────────
local sg_142: ScreenGui? = nil
local boardFrame_142: Frame? = nil
local rowFrames_142: {Frame} = {}

local function ensureGui_142()
    if sg_142 and sg_142.Parent then return end
    sg_142 = Instance.new("ScreenGui")
    sg_142.Name         = "LeaderboardGui"
    sg_142.ResetOnSpawn = false
    sg_142.DisplayOrder = 16
    sg_142.Parent       = playerGui
end

local function ensureBoard_142()
    ensureGui_142()
    if boardFrame_142 and boardFrame_142.Parent then return end

    local board = Instance.new("Frame")
    board.Name                  = "HoneyLeaderboard"
    board.Size                  = UDim2.new(0, 152, 0, 148)
    board.Position              = UDim2.new(1, -160, 1, -152)
    board.AnchorPoint           = Vector2.new(0, 1)
    board.BackgroundColor3      = DARK_142
    board.BackgroundTransparency = 0.1
    board.BorderSizePixel       = 0
    board.Parent                = sg_142 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = board
    local stroke = Instance.new("UIStroke"); stroke.Color = AMBER_142; stroke.Thickness = 1.2; stroke.Parent = board

    -- Header
    local header = Instance.new("TextLabel")
    header.Size                = UDim2.new(1,-8,0,20)
    header.Position            = UDim2.new(0,4,0,4)
    header.BackgroundTransparency = 1
    header.Font                = Enum.Font.GothamBold
    header.TextSize            = 12
    header.TextColor3          = AMBER_142
    header.TextXAlignment      = Enum.TextXAlignment.Center
    header.Text                = "🍯 Top Honey"
    header.Parent              = board

    -- 5 row frames
    for i = 1, 5 do
        local row = Instance.new("Frame")
        row.Name                  = "Row_" .. i
        row.Size                  = UDim2.new(1,-8,0,22)
        row.Position              = UDim2.new(0,4,0, 26 + (i-1)*24)
        row.BackgroundTransparency = 1
        row.BorderSizePixel       = 0
        row.Parent                = board

        local rankLbl = Instance.new("TextLabel")
        rankLbl.Name                = "Rank"
        rankLbl.Size                = UDim2.new(0,24,1,0)
        rankLbl.BackgroundTransparency = 1
        rankLbl.Font                = Enum.Font.GothamBold
        rankLbl.TextSize            = 12
        rankLbl.TextColor3          = WHITE_142
        rankLbl.Text                = RANK_EMOJIS_142[i]
        rankLbl.Parent              = row

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Name                = "Name"
        nameLbl.Size                = UDim2.new(1,-60,1,0)
        nameLbl.Position            = UDim2.new(0,26,0,0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font                = Enum.Font.GothamBold
        nameLbl.TextSize            = 11
        nameLbl.TextColor3          = WHITE_142
        nameLbl.TextXAlignment      = Enum.TextXAlignment.Left
        nameLbl.Text                = "—"
        nameLbl.Parent              = row

        local honeyLbl = Instance.new("TextLabel")
        honeyLbl.Name                = "Honey"
        honeyLbl.Size                = UDim2.new(0,52,1,0)
        honeyLbl.Position            = UDim2.new(1,-52,0,0)
        honeyLbl.BackgroundTransparency = 1
        honeyLbl.Font                = Enum.Font.GothamBold
        honeyLbl.TextSize            = 11
        honeyLbl.TextColor3          = AMBER_142
        honeyLbl.TextXAlignment      = Enum.TextXAlignment.Right
        honeyLbl.Text                = ""
        honeyLbl.Parent              = row

        table.insert(rowFrames_142, row)
    end

    boardFrame_142 = board
end

-- ── K-formatter ───────────────────────────────────────────────────
local function fmt_142(n: number): string
    if n >= 1000000 then return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then return string.format("%.1fK", n / 1000)
    else return tostring(n) end
end

-- ── Leaderboard refresh ───────────────────────────────────────────
local function refreshBoard_142()
    ensureBoard_142()
    -- Collect all players and their honey
    type Entry142 = {name: string, honey: number, isMe: boolean}
    local entries: {Entry142} = {}
    for _, p in Players:GetPlayers() do
        local honey = tonumber(p:GetAttribute("HoneyCount")) or 0
        table.insert(entries, {name = p.Name, honey = honey, isMe = p == player})
    end
    -- Sort descending
    table.sort(entries, function(a, b) return a.honey > b.honey end)

    for i = 1, 5 do
        local row = rowFrames_142[i]
        if not row then break end
        local entry = entries[i]
        local nameLbl  = row:FindFirstChild("Name") :: TextLabel?
        local honeyLbl = row:FindFirstChild("Honey") :: TextLabel?
        if entry then
            local shortName = entry.name:sub(1, 10) .. (entry.name:len() > 10 and "…" or "")
            if nameLbl then (nameLbl :: TextLabel).Text = shortName end
            if honeyLbl then (honeyLbl :: TextLabel).Text = fmt_142(entry.honey) end
            row.BackgroundTransparency = entry.isMe and 0.5 or 1
            row.BackgroundColor3       = HILI_142
        else
            if nameLbl then (nameLbl :: TextLabel).Text = "—" end
            if honeyLbl then (honeyLbl :: TextLabel).Text = "" end
            row.BackgroundTransparency = 1
        end
    end
end

-- ── Polling loop (every 10s) ──────────────────────────────────────
task.wait(2)
ensureBoard_142()
refreshBoard_142()

task.spawn(function()
    while true do
        task.wait(10)
        refreshBoard_142()
    end
end)

-- Also refresh when our own honey changes
player:GetAttributeChangedSignal("HoneyCount"):Connect(refreshBoard_142)
Players.PlayerAdded:Connect(function() task.wait(1); refreshBoard_142() end)
Players.PlayerRemoving:Connect(function() task.wait(0.5); refreshBoard_142() end)

print("[LeaderboardController] Ready — honey leaderboard active")
]]
    ctrl.Parent = SPS
    print("✅ LeaderboardController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local svc  = SSS:FindFirstChild("BearAttackService")
local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")

local checks = {}
-- Part A: patch check
table.insert(checks, (svc and svc.Source:find("hasGuard_142", 1, true) and "✅" or "❌") .. " BearAttackService has Guard Bee patch")
table.insert(checks, (svc and svc.Source:find("math.max(0.05", 1, true) and "✅" or "❌") .. " minimum 5% drain floor")
-- Part B: leaderboard
table.insert(checks, (ctrl and "✅" or "❌") .. " LeaderboardController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("RANK_EMOJIS_142", 1, true) and "✅" or "❌") .. " RANK_EMOJIS_142 rank emojis")
table.insert(checks, (ctrl and ctrl.Source:find("refreshBoard_142", 1, true) and "✅" or "❌") .. " refreshBoard_142 leaderboard update")
table.insert(checks, (ctrl and ctrl.Source:find("fmt_142", 1, true) and "✅" or "❌") .. " fmt_142 K/M formatter")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyLeaderboard", 1, true) and "✅" or "❌") .. " HoneyLeaderboard frame name")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCount", 1, true) and "✅" or "❌") .. " HoneyCount attribute read")
table.insert(checks, (ctrl and ctrl.Source:find("task.wait(10)", 1, true) and "✅" or "❌") .. " 10s polling loop")

print("=== DISPATCH 142 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 142 complete" or "❌ SOME CHECKS FAILED")

print("\nBear drain: base 15% | –5% hive_insulation | –5% guard_bee | floor 5%")
print("Leaderboard: top-5 by HoneyCount, 10s refresh, current player row highlighted")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BearAttackService patch (Script edit — no new instances) | 0 |
| LeaderboardController (LocalScript; GUI runtime only) | 0 permanent |
| **Dispatch 142 total** | **+0** |
| **Running total** | **4,149 / 5,000** |

---

## NOTES

- `math.max(0.05, drainPct)` imposes a 5% minimum drain floor. Even a player with both `hive_insulation` AND `guard_bee` still loses some honey to a bear attack — a bear always costs *something*. This preserves game tension and prevents the mechanic from becoming a non-event for min-maxers.
- The leaderboard uses `Players:GetPlayers()` purely client-side — no server script, no `OrderedDataStore`. For a tycoon game with max ~20 concurrent players per server, client-side sorting over `HoneyCount` attribute is cheap and accurate. The 10s polling interval keeps the display fresh without hammering the attribute system. A competitive player watching the top spot doesn't need sub-second accuracy.
- `entry.name:sub(1, 10) .. "…"` truncates long display names to fit the 152px wide panel without overflow. The ellipsis signals that the name is cut, which is more honest than silent truncation.
- `row.BackgroundTransparency = entry.isMe and 0.5 or 1` highlights the current player's row with the amber-tinted `HILI_142` background. When the player is outside the top 5, no row is highlighted — the leaderboard still shows correctly, just without emphasis. This is intentional: players outside top 5 should be motivated to improve, not given a false "you're still here" comfort row.
- DisplayOrder=16 was already allocated for the leaderboard in the DisplayOrder hierarchy. This dispatch fills that slot.
