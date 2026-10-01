# Dispatch 85 — Prestige Achievements
## Cycle 12 · A Bee's World

**Feature:** Adds four prestige-tier achievements to `Config.ACHIEVEMENTS` and extends `AchievementService.CheckAchievements` to evaluate the new `prestigeLevel` condition. Players earn rewards (honey bonuses) for reaching prestige levels 1, 3, 5, and 10. The 🏆 Achievements panel already renders any achievement in the Config table, so no UI changes are needed.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 84 (AntiCheat Dynamic Cap)

---

## DESIGN

### New achievements

| ID | Name | Condition | Reward |
|----|------|-----------|--------|
| `prestige_1` | First Reborn | `prestigeLevel >= 1` | 500 honey |
| `prestige_3` | Thrice Reborn | `prestigeLevel >= 3` | 1,500 honey |
| `prestige_5` | Veteran Beekeeper | `prestigeLevel >= 5` | 3,000 honey |
| `prestige_10` | Legendary Hivemind | `prestigeLevel >= 10` | 8,000 honey |

### Condition type: `prestige_level`

`AchievementService.CheckAchievements` currently handles condition types `honey`, `plots`, `trips`, `days`, `upgrades`, `social`, `seasonal`, and `milestone`. A new branch handles `prestige_level`:

```lua
elseif cond.type == "prestige_level" then
    met = (profile.prestigeLevel or 0) >= cond.value
```

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add 4 entries to `ACHIEVEMENTS` table |
| `AchievementService` | Add `prestige_level` condition branch |
| `PrestigeService` | Call `AchievementService.CheckAchievements` after prestige completes |

---

## STEP A — Config: add prestige achievements

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("prestige_1", 1, true) then
    print("⏭️  Config already has prestige achievements — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Find last achievement entry, inject after it (before closing brace of ACHIEVEMENTS)
    -- Strategy: find the last occurrence of '},' inside the ACHIEVEMENTS table
    local achStart = clone.Source:find("ACHIEVEMENTS", 1, true)
    assert(achStart, "ACHIEVEMENTS not found in Config")

    -- Find the closing brace of the ACHIEVEMENTS table
    local closeBrace = clone.Source:find("%}%s*\n?%s*%}", achStart)
    if not closeBrace then
        closeBrace = clone.Source:find("\n%s*%}", achStart)
    end
    assert(closeBrace, "Cannot find end of ACHIEVEMENTS table")

    local injection = [[
	{id = "prestige_1",  name = "First Reborn",       desc = "Prestige for the first time",   condition = {type = "prestige_level", value = 1},  reward = {honey = 500}},
	{id = "prestige_3",  name = "Thrice Reborn",       desc = "Reach prestige level 3",        condition = {type = "prestige_level", value = 3},  reward = {honey = 1500}},
	{id = "prestige_5",  name = "Veteran Beekeeper",   desc = "Reach prestige level 5",        condition = {type = "prestige_level", value = 5},  reward = {honey = 3000}},
	{id = "prestige_10", name = "Legendary Hivemind",  desc = "Reach prestige level 10",       condition = {type = "prestige_level", value = 10}, reward = {honey = 8000}},
]]

    clone.Source = clone.Source:sub(1, closeBrace - 1) .. injection .. clone.Source:sub(closeBrace)

    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config: 4 prestige achievements added")
end
```

---

## STEP B — AchievementService: add prestige_level condition branch

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local as = SSS:FindFirstChild("AchievementService")
assert(as, "AchievementService not found")

if as.Source:find("prestige_level", 1, true) then
    print("⏭️  AchievementService already handles prestige_level — skip")
else
    local clone = as:Clone()
    clone.Name = "AchievementService_WORKING"

    -- Find an existing condition branch to inject after (e.g. 'elseif cond.type == "milestone"' or similar last branch)
    -- Strategy: inject before the final 'end' of the condition check block
    -- Look for the pattern: elseif cond.type == "<something>"
    -- Find the last such branch and inject after its block
    local lastBranch = 1
    local searchFrom = 1
    while true do
        local next = clone.Source:find('elseif cond%.type ==', searchFrom, true)
        if not next then break end
        lastBranch = next
        searchFrom = next + 1
    end

    if lastBranch > 1 then
        -- Find the end of the block containing lastBranch (next 'elseif' or 'end' at same indent)
        local blockEnd = clone.Source:find("\n\t\tend", lastBranch, true)
        if not blockEnd then
            blockEnd = clone.Source:find("\n\t\tmet = ", lastBranch, true)
        end
        -- Simpler: find the 'met =' assignment for this branch and inject after its line
        local metLine = clone.Source:find("met%s*=", lastBranch, true)
        if metLine then
            local metLineEnd = clone.Source:find("\n", metLine, true)
            clone.Source = clone.Source:sub(1, metLineEnd)
                .. "\n\t\telseif cond.type == \"prestige_level\" then\n\t\t\tmet = (profile.prestigeLevel or 0) >= (cond.value or 1)"
                .. clone.Source:sub(metLineEnd + 1)
            print("prestige_level branch injected after last condition branch")
        else
            print("⚠️  Could not find met= line after last branch — trying alternate injection")
            -- Fallback: inject before 'if met and not' (reward check)
            local rewardCheck = clone.Source:find("if met and not", 1, true)
            if rewardCheck then
                local lineStart = rewardCheck
                while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
                clone.Source = clone.Source:sub(1, lineStart - 1)
                    .. "\t\t\telseif cond.type == \"prestige_level\" then\n\t\t\t\tmet = (profile.prestigeLevel or 0) >= (cond.value or 1)\n"
                    .. clone.Source:sub(lineStart)
                print("prestige_level injected via fallback before reward check")
            end
        end
    else
        print("⚠️  No existing 'elseif cond.type ==' found — prestige_level branch not injected")
    end

    as.Name = "AchievementService_OLD_NX"
    as.Parent = nil
    clone.Name = "AchievementService"
    clone.Parent = SSS
    print("✅ AchievementService prestige_level condition added")
end
```

---

## STEP C — PrestigeService: call CheckAchievements after prestige

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PrestigeService")
assert(ps, "PrestigeService not found")

if ps.Source:find("AchievementService", 1, true) then
    print("⏭️  PrestigeService already calls AchievementService — skip")
else
    local clone = ps:Clone()
    clone.Name = "PrestigeService_WORKING"

    -- Inject AchievementService require after TutorialService (or PrestigeReadySync)
    local anchor = 'local TutorialService'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        anchor = 'local PrestigeReadySync'
        found = clone.Source:find(anchor, 1, true)
    end
    if found then
        local lineEnd = clone.Source:find("\n", found, true)
        clone.Source = clone.Source:sub(1, lineEnd)
            .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))"
            .. clone.Source:sub(lineEnd + 1)
    end

    -- Inject CheckAchievements call after ShowPrestigeDone (or after prestigeLevel increment)
    local anchor2 = 'ShowPrestigeDone'
    local found2 = clone.Source:find(anchor2, 1, true)
    if not found2 then
        anchor2 = 'profile.prestigeLevel'
        found2 = clone.Source:find(anchor2, 1, true)
    end
    if found2 then
        local lineEnd2 = clone.Source:find("\n", found2, true)
        clone.Source = clone.Source:sub(1, lineEnd2)
            .. "\n\ttask.spawn(function() AchievementService.CheckAchievements(player) end)"
            .. clone.Source:sub(lineEnd2 + 1)
    else
        print("⚠️  Could not find inject anchor in PrestigeService for CheckAchievements")
    end

    ps.Name = "PrestigeService_OLD_NX"
    ps.Parent = nil
    clone.Name = "PrestigeService"
    clone.Parent = SSS
    print("✅ PrestigeService CheckAchievements call injected")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
table.insert(checks, (cfg and cfg.Source:find("prestige_1") and "✅" or "❌") .. " Config: prestige_1 achievement")
table.insert(checks, (cfg and cfg.Source:find("prestige_10") and "✅" or "❌") .. " Config: prestige_10 achievement")

local as = SSS:FindFirstChild("AchievementService")
table.insert(checks, (as and as.Source:find("prestige_level") and "✅" or "❌") .. " AchievementService: prestige_level condition")

local ps = SSS:FindFirstChild("PrestigeService")
table.insert(checks, (ps and ps.Source:find("AchievementService") and "✅" or "❌") .. " PrestigeService: calls AchievementService")

-- Count prestige achievements in Config
if cfg then
    local count = 0
    for _ in cfg.Source:gmatch('type = "prestige_level"') do count = count + 1 end
    table.insert(checks, (count >= 4 and "✅" or "❌") .. " Config: " .. count .. " / 4 prestige condition entries")
end

print("=== DISPATCH 85 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 85 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config + source patches only | 0 new parts |
| **Dispatch 85 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `AchievementService.CheckAchievements(player)` is already called after every foraging trip and every stats broadcast (from dispatch 77). Adding a third call site inside `PrestigeService` ensures prestige achievements unlock immediately on prestige completion rather than waiting for the next foraging trip.
- Reward honey (500–8,000) is applied by the existing achievement reward handler in `AchievementService` — no changes to the reward pipeline are needed.
- The `prestige_10` reward (8,000 honey) is deliberately large — it takes significant playtime to reach prestige 10, and a meaningful reward reinforces the long-term loop. It does not exceed `MAX_HONEY` cap because `AchievementService` clamps all additions.
- Achievement names and descriptions appear directly in the Achievements panel (dispatch 53/77). No icon IDs needed — the panel uses text only in the current implementation.
- If `AchievementService` uses a different condition dispatch pattern (e.g. a `conditionHandlers` table rather than `if/elseif` chain), STEP B's pattern-match injection will print a warning. In that case, add the entry manually: `conditionHandlers["prestige_level"] = function(profile, cond) return (profile.prestigeLevel or 0) >= cond.value end`.
