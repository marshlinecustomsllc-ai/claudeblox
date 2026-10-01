# Dispatch 94 — Prestige Leaderboard Stars
## Cycle 13 · A Bee's World

**Feature:** The top-10 honey leaderboard (dispatch 80) and prestige leaderboard show raw player names. This dispatch updates `LeaderboardController` (client) to append star badges to player names based on their prestige level. A player at prestige 3 appears as "PlayerName ⭐⭐⭐". Stars are shown for prestige 1-5; players at prestige 6-9 show "⭐×N"; prestige 10 shows the gold crown "👑" instead of stars. This gives veteran players visible recognition and makes the leaderboard a social signal for progression depth.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 93 (HiveStats Upgrade Count Integration)

---

## DESIGN

### Badge format

| Prestige level | Display |
|----------------|---------|
| 0 | `PlayerName` (no badge) |
| 1 | `PlayerName ⭐` |
| 2 | `PlayerName ⭐⭐` |
| 3 | `PlayerName ⭐⭐⭐` |
| 4 | `PlayerName ⭐⭐⭐⭐` |
| 5 | `PlayerName ⭐⭐⭐⭐⭐` |
| 6–9 | `PlayerName ⭐×6` … `⭐×9` |
| 10 | `PlayerName 👑` |

### Data source

`LeaderboardController` receives leaderboard data via a `RemoteEvent` (likely `LeaderboardSync` or `LeaderboardUpdate`). The payload currently includes a list of `{name, score}` entries. Prestige data is available from two places:
- The leaderboard row already received from `OrderedDataStore` for the prestige leaderboard tab contains the prestige score directly.
- For the honey leaderboard tab, prestige level is not in the row — the controller must request it from `HiveStatsSync` or derive it from the prestige leaderboard data received alongside the honey data.

**Simplest approach:** The prestige leaderboard (`prestigeODS`) already sends entries sorted by prestige score. Cache that as a `{[playerName] = prestigeLevel}` map when the prestige tab data arrives, then reference it when rendering honey leaderboard rows.

### UI change

In the row-building loop (wherever TextLabel for player name is set), replace:
```lua
label.Text = entry.name
```
with:
```lua
label.Text = entry.name .. prestigeBadge(prestigeMap[entry.name] or 0)
```

where `prestigeBadge(n)` returns the formatted string.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `LeaderboardController` | Add `prestigeBadge()` helper + prestige map cache + apply badge to name labels |

---

## STEP A — Diagnose LeaderboardController structure

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local lc = SPS and SPS:FindFirstChild("LeaderboardController")
if not lc then
    -- Also check StarterGui
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj.Name == "LeaderboardController" then
            lc = obj
            break
        end
    end
end
if not lc then print("❌ LeaderboardController NOT FOUND") return end

print("Found: " .. lc:GetFullName())
print("Lines: " .. select(2, lc.Source:gsub("\n", "\n")) + 1)

-- Find name label assignment patterns
local patterns = {"%.Text%s*=", "entry%.name", "playerName", "name.*Text", "\.Name"}
for _, p in patterns do
    local found = lc.Source:find(p)
    if found then
        local lineStart = found
        while lineStart > 1 and lc.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
        local lineEnd = lc.Source:find("\n", found, true) or #lc.Source
        print("Pattern '" .. p .. "' at char " .. found .. ": " .. lc.Source:sub(lineStart, lineEnd))
    end
end

-- Show first 80 chars of lines containing 'name' (case-insensitive)
local lines = {}
for line in lc.Source:gmatch("[^\n]+") do
    if line:lower():find("name") then
        table.insert(lines, line)
    end
end
print("Lines with 'name': " .. #lines)
for i = 1, math.min(10, #lines) do print("  " .. lines[i]) end
```

---

## STEP B — LeaderboardController: inject prestige badge

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local lc = SPS and SPS:FindFirstChild("LeaderboardController")
if not lc then
    -- Fallback: check StarterGui descendants
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "LeaderboardController" then
            lc = obj
            break
        end
    end
end
assert(lc, "LeaderboardController not found in StarterPlayerScripts or StarterGui")

if lc.Source:find("prestigeBadge", 1, true) then
    print("⏭️  LeaderboardController already has prestigeBadge — skip")
else
    local clone = lc:Clone()
    clone.Name = "LeaderboardController_WORKING"

    -- Inject prestigeBadge helper and prestigeMap cache at end of source
    clone.Source = clone.Source .. [[

-- ── Prestige Star Badges (dispatch 94) ─────────────────────────
local _prestigeMap: {[string]: number} = {}

local function prestigeBadge(level: number): string
    if level <= 0 then return "" end
    if level == 10 then return " 👑" end
    if level <= 5 then return " " .. string.rep("⭐", level) end
    return " ⭐×" .. level
end

-- Cache prestige scores when prestige leaderboard data arrives
-- Assumes leaderboard sync fires a table like:
-- { honey = {{name,score},...}, prestige = {{name,score},...} }
-- OR two separate events HoneyLeaderboardSync / PrestigeLeaderboardSync
-- Try both patterns:

local RS = game:GetService("ReplicatedStorage")
local function tryBindPrestigeSync()
    local prestigeSync = RS:FindFirstChild("PrestigeLeaderboardSync")
        or RS:FindFirstChild("LeaderboardSync")
    if not prestigeSync then return false end

    prestigeSync.OnClientEvent:Connect(function(data)
        -- If data is a table with a 'prestige' key, use that sub-table
        -- If data is a flat array of {name, score} from prestige ODS, use it directly
        local rows = (type(data) == "table" and data.prestige) and data.prestige or data
        if type(rows) ~= "table" then return end
        for _, row in rows do
            if type(row) == "table" and row.name and row.score then
                _prestigeMap[row.name] = row.score
            end
        end
    end)
    return true
end

-- Try binding immediately; retry once after 3 seconds if event not yet created
if not tryBindPrestigeSync() then
    task.delay(3, function()
        if not tryBindPrestigeSync() then
            warn("[LeaderboardStars] Could not find prestige sync RemoteEvent")
        end
    end)
end

-- Patch leaderboard row name labels to show badges
-- LeaderboardController builds rows dynamically; we wrap the name-setting step
-- by hooking into the DescendantAdded event on the leaderboard GUI frame
-- to apply badge to TextLabels that contain player names.
--
-- This approach is non-invasive: it post-processes rows as they are added,
-- without needing to find the exact row-building loop.

task.spawn(function()
    local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local leaderboardGui = playerGui:WaitForChild("LeaderboardGui", 10)
    if not leaderboardGui then
        warn("[LeaderboardStars] LeaderboardGui not found after 10s")
        return
    end

    local function applyBadgeToLabel(label: TextLabel)
        if not label:IsA("TextLabel") then return end
        -- Name labels typically contain a player name — heuristic: text is 3-20 chars,
        -- no spaces or a Roblox username pattern, and does NOT already have a badge
        local text = label.Text
        if text:find("⭐") or text:find("👑") then return end  -- already badged
        if #text < 3 or #text > 24 then return end            -- not a name label
        if text:find("^%d+$") then return end                 -- pure number = score label
        -- Check if this name is in our prestige map
        local level = _prestigeMap[text]
        if level and level > 0 then
            label.Text = text .. prestigeBadge(level)
        end
    end

    local function scanAllLabels(container: Instance)
        for _, obj in container:GetDescendants() do
            if obj:IsA("TextLabel") then
                applyBadgeToLabel(obj)
            end
        end
    end

    -- Scan existing labels
    scanAllLabels(leaderboardGui)

    -- Watch for new rows added
    leaderboardGui.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") then
            task.wait()  -- let Text be set first
            applyBadgeToLabel(obj)
        end
    end)

    -- Re-scan after prestige map updates (new sync data may arrive after rows are rendered)
    local RS2 = game:GetService("ReplicatedStorage")
    local prestigeSync2 = RS2:FindFirstChild("PrestigeLeaderboardSync")
        or RS2:FindFirstChild("LeaderboardSync")
    if prestigeSync2 then
        prestigeSync2.OnClientEvent:Connect(function()
            task.wait(0.1)  -- give render loop time to rebuild rows
            scanAllLabels(leaderboardGui)
        end)
    end

    print("[LeaderboardStars] Prestige badge system active")
end)
]]

    lc.Parent:FindFirstChild(lc.Name).Name = lc.Name .. "_OLD_NX"
    lc.Parent:FindFirstChild(lc.Name .. "_OLD_NX").Parent = nil
    clone.Name = "LeaderboardController"
    clone.Parent = SPS
    print("✅ LeaderboardController: prestige star badges injected")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local lc = SPS and SPS:FindFirstChild("LeaderboardController")

local checks = {}
table.insert(checks, (lc and "✅" or "❌") .. " LeaderboardController exists")
table.insert(checks, (lc and lc.Source:find("prestigeBadge", 1, true) and "✅" or "❌") .. " LeaderboardController: prestigeBadge function")
table.insert(checks, (lc and lc.Source:find("_prestigeMap", 1, true) and "✅" or "❌") .. " LeaderboardController: _prestigeMap cache")
table.insert(checks, (lc and lc.Source:find("PrestigeLeaderboardSync", 1, true) and "✅" or "❌") .. " LeaderboardController: listens to prestige sync event")
table.insert(checks, (lc and lc.Source:find("DescendantAdded", 1, true) and "✅" or "❌") .. " LeaderboardController: DescendantAdded row watcher")
table.insert(checks, (lc and lc.Source:find("%👑", 1, true) and "✅" or "❌") .. " LeaderboardController: crown emoji for prestige 10")

print("=== DISPATCH 94 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 94 complete" or "❌ SOME CHECKS FAILED")

-- Preview badge output
print("\nBadge preview:")
local function badge(n)
    if n <= 0 then return "(none)" end
    if n == 10 then return "👑" end
    if n <= 5 then return string.rep("⭐", n) end
    return "⭐×" .. n
end
for _, n in {0,1,2,3,4,5,6,9,10} do
    print("  prestige " .. n .. ": PlayerName " .. badge(n))
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI injection only (no BaseParts) | 0 new parts |
| **Dispatch 94 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The `DescendantAdded` hook approach is more robust than finding the exact row-building loop in `LeaderboardController`, because it works regardless of how the controller is structured. The heuristic (text 3-20 chars, not a pure number) may occasionally miss or over-tag a label — the `_prestigeMap` check limits false positives to labels whose text exactly matches a top-10 player's username.
- `task.wait()` inside `DescendantAdded` gives the controller one frame to set the TextLabel's `Text` before the badge function reads it. Without this, `label.Text` may still be "" when the callback fires.
- If `LeaderboardController` uses a separate `HoneyLeaderboardSync` and `PrestigeLeaderboardSync` (two events), STEP B binds to whichever exists first. If only one event carries both data sets as `{honey=..., prestige=...}`, the branch `data.prestige and data.prestige or data` handles both patterns.
- The re-scan on prestige sync arrival ensures that if the prestige map arrives after rows are already rendered (race condition on first load), badges are still applied retroactively.
- `string.rep("⭐", level)` for levels 1-5 produces clean inline stars. Levels 6-9 use `⭐×N` to avoid a long string that overflows the name label.
- Prestige 10 `👑` is the endgame recognition signal — visible on both tabs. This doubles as a retention hook: players who see a 👑 in the leaderboard understand there's a prestige 10 to reach.
