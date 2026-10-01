# Dispatch 95 — Daily Reward Expansion
## Cycle 13 · A Bee's World

**Feature:** The daily reward system (dispatch 63) currently grants only honey. With propolis and pollen now being full progression resources with their own upgrade trees, the daily reward pool should include all three. This dispatch updates `DailyRewardService` to grant a mix of honey, propolis, and pollen based on day streak, and updates `DailyRewardController` (client) to display the new resource icons in the claim notification.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 94 (Prestige Leaderboard Stars)

---

## DESIGN

### Reward schedule

| Day (cycle mod 7) | Honey | Propolis | Pollen |
|-------------------|-------|----------|--------|
| 1 | 50 | 0 | 0 |
| 2 | 75 | 10 | 0 |
| 3 | 100 | 0 | 15 |
| 4 | 125 | 20 | 20 |
| 5 | 150 | 30 | 30 |
| 6 | 200 | 40 | 40 |
| 7 (streak bonus) | 300 | 60 | 60 |

Days 1-7 then repeat. The `streakDay` field in profile tracks position (already exists from dispatch 63, clamped to 1-7).

### DailyRewardService patch

Replace the fixed `honeyAmount` constant with a lookup table:

```lua
local DAILY_REWARDS = {
    [1] = {honey = 50,  propolis = 0,  pollen = 0},
    [2] = {honey = 75,  propolis = 10, pollen = 0},
    [3] = {honey = 100, propolis = 0,  pollen = 15},
    [4] = {honey = 125, propolis = 20, pollen = 20},
    [5] = {honey = 150, propolis = 30, pollen = 30},
    [6] = {honey = 200, propolis = 40, pollen = 40},
    [7] = {honey = 300, propolis = 60, pollen = 60},
}
```

Grant all three resources, clamping to max:
```lua
local day = (profile.streakDay or 1)
local reward = DAILY_REWARDS[day] or DAILY_REWARDS[1]
profile.honey    = math.min(profile.honey    + reward.honey,    Config.MAX_HONEY)
profile.propolis = math.min(profile.propolis + reward.propolis, Config.MAX_PROPOLIS)
profile.pollen   = math.min(profile.pollen   + reward.pollen,   Config.MAX_POLLEN)
```

Fire the updated reward payload to the client: `DailyRewardSync:FireClient(player, {honey=reward.honey, propolis=reward.propolis, pollen=reward.pollen, day=day})`

### DailyRewardController patch

Update the claim notification display to show all three resources received, using their emoji icons. Currently the controller likely shows "🍯 +X honey" — extend it to show propolis and pollen lines when non-zero.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DailyRewardService` | Replace fixed honey grant with DAILY_REWARDS table; grant all three resources; update FireClient payload |
| `DailyRewardController` | Update notification display to show propolis and pollen when granted |

---

## STEP A — Diagnose DailyRewardService current structure

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DailyRewardService")
if not ds then print("❌ DailyRewardService NOT FOUND") return end

print("Lines: " .. select(2, ds.Source:gsub("\n", "\n")) + 1)

-- Find honey grant line
local honeyLine = ds.Source:find("profile%.honey%s*=", 1, true)
if honeyLine then
    local ls = honeyLine
    while ls > 1 and ds.Source:sub(ls-1,ls-1) ~= "\n" do ls = ls - 1 end
    local le = ds.Source:find("\n", honeyLine, true) or #ds.Source
    print("Honey grant: " .. ds.Source:sub(ls, le))
end

-- Find FireClient call
local fireClient = ds.Source:find("FireClient", 1, true)
if fireClient then
    local ls = fireClient
    while ls > 1 and ds.Source:sub(ls-1,ls-1) ~= "\n" do ls = ls - 1 end
    local le = ds.Source:find("\n", fireClient, true) or #ds.Source
    print("FireClient: " .. ds.Source:sub(ls, le))
end

-- Check if streakDay exists
print("streakDay: " .. (ds.Source:find("streakDay", 1, true) and "found" or "NOT FOUND"))
print("DailyRewardSync: " .. (ds.Source:find("DailyRewardSync", 1, true) and "found" or "NOT FOUND"))
```

---

## STEP B — DailyRewardService: inject DAILY_REWARDS table + multi-resource grant

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DailyRewardService")
assert(ds, "DailyRewardService not found")

if ds.Source:find("DAILY_REWARDS", 1, true) then
    print("⏭️  DailyRewardService already has DAILY_REWARDS table — skip")
else
    local clone = ds:Clone()
    clone.Name = "DailyRewardService_WORKING"

    -- 1. Inject DAILY_REWARDS table near the top (after requires/Config)
    local anchor = 'local Config'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        anchor = 'require'
        found = clone.Source:find(anchor, 1, true)
    end
    assert(found, "Could not find inject point in DailyRewardService")

    local lastRequire = found
    local searchFrom = found
    while true do
        local next = clone.Source:find("require", searchFrom, true)
        if not next then break end
        lastRequire = next
        searchFrom = next + 1
    end
    local insertAfter = clone.Source:find("\n", lastRequire, true) or #clone.Source

    local tableInjection = [[

local DAILY_REWARDS = {
	[1] = {honey = 50,  propolis = 0,  pollen = 0},
	[2] = {honey = 75,  propolis = 10, pollen = 0},
	[3] = {honey = 100, propolis = 0,  pollen = 15},
	[4] = {honey = 125, propolis = 20, pollen = 20},
	[5] = {honey = 150, propolis = 30, pollen = 30},
	[6] = {honey = 200, propolis = 40, pollen = 40},
	[7] = {honey = 300, propolis = 60, pollen = 60},
}

]]
    clone.Source = clone.Source:sub(1, insertAfter) .. tableInjection .. clone.Source:sub(insertAfter + 1)

    -- 2. Replace honey grant line(s) with multi-resource grant
    -- Find the profile.honey = ... grant line
    local honeyGrant = 'profile%.honey%s*=%s*.*honey'
    local grantFound = clone.Source:find(honeyGrant)
    if not grantFound then
        -- Try simpler pattern
        honeyGrant = 'profile%.honey%s*='
        grantFound = clone.Source:find(honeyGrant, 1, true)
    end
    assert(grantFound, "profile.honey = grant line not found")

    -- Find the full line
    local lineStart = grantFound
    while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
    local lineEnd = clone.Source:find("\n", grantFound, true) or #clone.Source
    local indent = clone.Source:sub(lineStart, grantFound):match("^(%s*)") or "\t"

    -- Replace with multi-resource block
    local multiGrant = indent .. "local _day = math.max(1, math.min(7, profile.streakDay or 1))\n"
        .. indent .. "local _reward = DAILY_REWARDS[_day] or DAILY_REWARDS[1]\n"
        .. indent .. "profile.honey    = math.min((profile.honey or 0) + _reward.honey, Config.MAX_HONEY or 5000)\n"
        .. indent .. "profile.propolis = math.min((profile.propolis or 0) + _reward.propolis, Config.MAX_PROPOLIS or 500)\n"
        .. indent .. "profile.pollen   = math.min((profile.pollen or 0) + _reward.pollen, Config.MAX_POLLEN or 300)"

    clone.Source = clone.Source:sub(1, lineStart - 1) .. multiGrant .. clone.Source:sub(lineEnd + 1)

    -- 3. Update FireClient to include all three resources
    local fireAnchor = 'DailyRewardSync:FireClient'
    local fireFound = clone.Source:find(fireAnchor, 1, true)
    if fireFound then
        local fireLineEnd = clone.Source:find(")", fireFound, true)
        if fireLineEnd then
            -- Replace the FireClient call entirely
            local fireLineStart = fireFound
            while fireLineStart > 1 and clone.Source:sub(fireLineStart-1,fireLineStart-1) ~= "\n" do
                fireLineStart = fireLineStart - 1
            end
            local fullFireLine = clone.Source:sub(fireLineStart, fireLineEnd)
            local newFireLine = clone.Source:sub(fireLineStart, fireFound + #fireAnchor - 1)
                .. "(player, {honey = _reward.honey, propolis = _reward.propolis, pollen = _reward.pollen, day = _day})"
            clone.Source = clone.Source:sub(1, fireLineStart - 1)
                .. newFireLine .. clone.Source:sub(fireLineEnd + 1)
            print("FireClient updated to multi-resource payload")
        end
    else
        print("⚠️  DailyRewardSync:FireClient not found — payload not updated")
    end

    ds.Name = "DailyRewardService_OLD_NX"
    ds.Parent = nil
    clone.Name = "DailyRewardService"
    clone.Parent = SSS
    print("✅ DailyRewardService: DAILY_REWARDS table + multi-resource grant injected")
end
```

---

## STEP C — DailyRewardController: update notification display

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local dc = SPS and SPS:FindFirstChild("DailyRewardController")
if not dc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "DailyRewardController" then
            dc = obj; break
        end
    end
end
assert(dc, "DailyRewardController not found")

if dc.Source:find("propolis.*reward", 1, true) or dc.Source:find("_reward%.propolis", 1, true) then
    print("⏭️  DailyRewardController already shows multi-resource — skip")
else
    local clone = dc:Clone()
    clone.Name = "DailyRewardController_WORKING"

    -- Find where the notification text is built — look for "+X honey" or "🍯"
    local anchor = '%+.*honey'
    local found = clone.Source:find(anchor)
    if not found then
        anchor = '🍯'
        found = clone.Source:find(anchor, 1, true)
    end
    if not found then
        anchor = 'notif.*Text'
        found = clone.Source:find(anchor)
    end

    if found then
        -- Find the text-assignment line
        local lineStart = found
        while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
        local lineEnd = clone.Source:find("\n", found, true) or #clone.Source
        local oldLine = clone.Source:sub(lineStart, lineEnd)
        local indent = oldLine:match("^(%s*)") or "\t"

        -- Replace with multi-line display
        local newLines = indent .. "-- Build reward display (dispatch 95)\n"
            .. indent .. "local _lines = {}\n"
            .. indent .. "if (data.honey or 0) > 0 then table.insert(_lines, '🍯 +' .. data.honey .. ' honey') end\n"
            .. indent .. "if (data.propolis or 0) > 0 then table.insert(_lines, '🔮 +' .. data.propolis .. ' propolis') end\n"
            .. indent .. "if (data.pollen or 0) > 0 then table.insert(_lines, '🌼 +' .. data.pollen .. ' pollen') end\n"
            .. indent .. "local _displayText = table.concat(_lines, '  |  ')\n"
            .. indent .. "if notifLabel then notifLabel.Text = _displayText end"

        clone.Source = clone.Source:sub(1, lineStart - 1) .. newLines .. clone.Source:sub(lineEnd + 1)
        print("Notification display updated")
    else
        print("⚠️  Could not find notification text line in DailyRewardController — appending fallback")
        -- Append a DescendantAdded watcher as fallback (same pattern as dispatch 94)
        clone.Source = clone.Source .. [[

-- Dispatch 95: patch DailyRewardSync handler to show multi-resource
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local sync = RS:WaitForChild("DailyRewardSync", 10)
    if not sync then return end
    sync.OnClientEvent:Connect(function(data)
        local lines = {}
        if (data.honey or 0) > 0 then table.insert(lines, "🍯 +" .. data.honey .. " honey") end
        if (data.propolis or 0) > 0 then table.insert(lines, "🔮 +" .. data.propolis .. " propolis") end
        if (data.pollen or 0) > 0 then table.insert(lines, "🌼 +" .. data.pollen .. " pollen") end
        local displayText = table.concat(lines, "  |  ")
        -- Find the notif label in PlayerGui
        local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local label = pg:FindFirstChild("DailyRewardLabel", true)
            or pg:FindFirstChild("NotifLabel", true)
            or pg:FindFirstChild("RewardText", true)
        if label and label:IsA("TextLabel") then
            label.Text = displayText
        end
    end)
end)
]]
    end

    clone.Name = "DailyRewardController"
    local parent = dc.Parent
    dc.Name = "DailyRewardController_OLD_NX"
    dc.Parent = nil
    clone.Parent = parent
    print("✅ DailyRewardController: multi-resource notification display injected")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local ds = SSS:FindFirstChild("DailyRewardService")
table.insert(checks, (ds and ds.Source:find("DAILY_REWARDS", 1, true) and "✅" or "❌") .. " DailyRewardService: DAILY_REWARDS table")
table.insert(checks, (ds and ds.Source:find("profile%.propolis", 1, true) and "✅" or "❌") .. " DailyRewardService: grants propolis")
table.insert(checks, (ds and ds.Source:find("profile%.pollen", 1, true) and "✅" or "❌") .. " DailyRewardService: grants pollen")
table.insert(checks, (ds and ds.Source:find("_reward%.honey", 1, true) and "✅" or "❌") .. " DailyRewardService: _reward lookup used")

local dc = SPS and SPS:FindFirstChild("DailyRewardController")
table.insert(checks, (dc and "✅" or "❌") .. " DailyRewardController exists in StarterPlayerScripts")
table.insert(checks, (dc and (dc.Source:find("propolis", 1, true) ~= nil) and "✅" or "❌") .. " DailyRewardController: shows propolis in notification")
table.insert(checks, (dc and (dc.Source:find("pollen", 1, true) ~= nil) and "✅" or "❌") .. " DailyRewardController: shows pollen in notification")

print("=== DISPATCH 95 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 95 complete" or "❌ SOME CHECKS FAILED")

print("\nDaily reward schedule:")
local rewards = {
    {1, 50, 0, 0}, {2, 75, 10, 0}, {3, 100, 0, 15},
    {4, 125, 20, 20}, {5, 150, 30, 30}, {6, 200, 40, 40}, {7, 300, 60, 60}
}
for _, r in rewards do
    local d, h, pr, po = r[1], r[2], r[3], r[4]
    local parts = {"🍯 " .. h}
    if pr > 0 then table.insert(parts, "🔮 " .. pr) end
    if po > 0 then table.insert(parts, "🌼 " .. po) end
    print("  Day " .. d .. ": " .. table.concat(parts, " + "))
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patches only (no BaseParts) | 0 new parts |
| **Dispatch 95 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The 7-day cycle design mirrors common idle/tycoon games. Day 7 "streak bonus" (300 honey + 60 propolis + 60 pollen) is significantly more valuable to incentivise consecutive logins. If `profile.streakDay` resets on a missed day (existing logic from dispatch 63), this schedule maintains that tension.
- Propolis and pollen amounts are intentionally smaller than honey: a day-7 reward of 60 propolis is ~6× the starting `Resin Collector I` cost (40 propolis) — meaningful but not game-breaking. Similarly 60 pollen ≈ 2× `Pollen Sacks I` cost (30 pollen).
- The notification format `🍯 +50  |  🔮 +10  |  🌼 +15` is compact enough for a single text line. If the daily reward UI has separate resource rows, the controller can split `_lines` across multiple labels.
- `math.min(... + reward.propolis, Config.MAX_PROPOLIS or 500)` — the fallback 500 ensures the cap applies even if `MAX_PROPOLIS` is not yet in Config (it was added in Cycle 11). The same applies to MAX_POLLEN (fallback 300).
- If `DailyRewardController` is inside a `StarterGui` ScreenGui rather than in `StarterPlayerScripts`, STEP C's fallback search covers that case via the `SG:GetDescendants()` loop. The Script parent re-assignment sets `clone.Parent = parent` using the original parent, so the script lands in the correct container.
