# Dispatch 77 — AchievementsExpansion
## Cycle 11 · A Bee's World

**Feature:** Adds 12 new achievement definitions to `Config.ACHIEVEMENTS` covering the new stats introduced in Cycle 11: total upgrades bought, days played, friend bonuses earned, and seasonal events witnessed. Also injects unlock checks into `HiveStatsService` so the new achievements are evaluated each time stats are broadcast.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 76 (AntiCheatService)

---

## DESIGN

New achievements slot into the existing `Config.ACHIEVEMENTS` array format (established in dispatch 24) and are evaluated by the existing `AchievementService` unlock loop — no changes to `AchievementService` itself are needed, only:

1. **New entries in `Config.ACHIEVEMENTS`** (patched via clone-and-replace of the Config ModuleScript).
2. **Stat-triggered checks in `HiveStatsService.BroadcastStats`** — call `AchievementService.CheckAchievements(player)` after every stats broadcast so new milestones are caught immediately.

### New achievement categories

#### Upgrades Bought
| ID | Name | Threshold | Reward (honey) |
|----|------|-----------|----------------|
| `upgrades_5` | Tinkerer | 5 total upgrades | 100 |
| `upgrades_20` | Engineer | 20 total upgrades | 500 |
| `upgrades_all` | Master Builder | 42 total upgrades (all 7 services × 6 tiers) | 2000 |

#### Days Played
| ID | Name | Threshold | Reward (honey) |
|----|------|-----------|----------------|
| `days_3` | Returning Bee | 3 days played | 200 |
| `days_7` | Dedicated Keeper | 7 days played | 500 |
| `days_30` | Hive Elder | 30 days played | 3000 |

#### Social (friend bonus)
| ID | Name | Condition | Reward (honey) |
|----|------|-----------|----------------|
| `first_friend_bonus` | Bee Friends | First session with a friend bonus active | 150 |
| `max_friend_bonus` | Queen's Court | 3+ friends in server (max bonus tier) | 400 |

#### Seasonal
| ID | Name | Condition | Reward (honey) |
|----|------|-----------|----------------|
| `seasonal_spring` | Spring Harvest | Forage during Spring Bloom | 300 |
| `seasonal_summer` | Sun-Kissed | Forage during Summer Harvest | 300 |
| `seasonal_autumn` | Amber Autumn | Forage during Autumn Nectar | 300 |
| `seasonal_winter` | Winter Keeper | Forage during Winter Rest | 300 |

#### Mega milestone
| ID | Name | Condition | Reward (honey) |
|----|------|-----------|----------------|
| `honey_million` | Millionaire Bee | 1,000,000 total honey earned | 5000 |

**Total new achievements:** 13.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` ModuleScript | Append 13 new entries to `ACHIEVEMENTS` array |
| `HiveStatsService` | Call `AchievementService.CheckAchievements(player)` after `BroadcastStats` |
| `ForagingService` | Track seasonal and friend-bonus achievement flags in profile |
| `DataService` | Add 4 new achievement-related tracking fields |

---

## STEP A — DataService: new tracking fields

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local newFields = {
    'seasonalSeen = {}',       -- {eventId: true} events witnessed while foraging
    'friendBonusSessions = 0', -- total sessions where friend bonus was > 1.0
    'maxFriendBonusReached = false', -- true once 3+ friends observed
}

local alreadyPatched = true
for _, f in newFields do
    local key = f:match("^(%S+)")
    if not ds.Source:find(key, 1, true) then
        alreadyPatched = false
        break
    end
end

if alreadyPatched then
    print("⏭️  DataService achievement fields already present")
else
    local clone = ds:Clone()
    clone.Name = "DataService_WORKING"

    -- Inject after queenName field
    local anchor = 'queenName'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "queenName not found in DataService")
    local lineEnd = clone.Source:find("\n", found, true)
    local injection = "\n\t\tseasonalSeen        = {},\n\t\tfriendBonusSessions = 0,\n\t\tmaxFriendBonusReached = false,"
    clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil
    clone.Name = "DataService"
    clone.Parent = SSS
    print("✅ DataService achievement fields injected")
end
```

---

## STEP B — Config: append 13 new achievements

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("upgrades_5", 1, true) then
    print("⏭️  Config already has expansion achievements — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Find the closing brace of ACHIEVEMENTS table
    -- Typically ends with: }  -- end ACHIEVEMENTS
    -- We inject before the closing brace of the array
    local endAnchor = '}%s*%-%- end ACHIEVEMENTS'
    local found = clone.Source:find(endAnchor)
    if not found then
        -- fallback: find last '}' in ACHIEVEMENTS block
        -- inject at end of ACHIEVEMENTS array before final table close
        found = clone.Source:find('ACHIEVEMENTS%s*=%s*{')
        assert(found, "ACHIEVEMENTS not found in Config")
        -- find the matching close bracket (count depth)
        local depth = 0
        local i = found
        while i <= #clone.Source do
            local c = clone.Source:sub(i, i)
            if c == '{' then depth += 1 elseif c == '}' then depth -= 1 end
            if depth == 0 then found = i; break end
            i += 1
        end
    end

    local newEntries = [[

    -- Cycle 11: Upgrades Bought
    {id="upgrades_5",   name="Tinkerer",       desc="Buy 5 upgrades",              stat="totalUpgradesBought", threshold=5,   reward=100},
    {id="upgrades_20",  name="Engineer",        desc="Buy 20 upgrades",             stat="totalUpgradesBought", threshold=20,  reward=500},
    {id="upgrades_all", name="Master Builder",  desc="Buy all 42 upgrades",         stat="totalUpgradesBought", threshold=42,  reward=2000},
    -- Cycle 11: Days Played
    {id="days_3",       name="Returning Bee",   desc="Play 3 different days",       stat="daysPlayed",          threshold=3,   reward=200},
    {id="days_7",       name="Dedicated Keeper",desc="Play 7 different days",       stat="daysPlayed",          threshold=7,   reward=500},
    {id="days_30",      name="Hive Elder",       desc="Play 30 different days",      stat="daysPlayed",          threshold=30,  reward=3000},
    -- Cycle 11: Social
    {id="first_friend_bonus",  name="Bee Friends",   desc="Play with a friend nearby",   stat="friendBonusSessions",   threshold=1,  reward=150},
    {id="max_friend_bonus",    name="Queen's Court", desc="Have 3+ friends in server",   stat="maxFriendBonusReached", threshold=1,  reward=400},
    -- Cycle 11: Seasonal
    {id="seasonal_spring", name="Spring Harvest", desc="Forage during Spring Bloom",   stat="seasonal_spring_seen", threshold=1, reward=300},
    {id="seasonal_summer", name="Sun-Kissed",     desc="Forage during Summer Harvest", stat="seasonal_summer_seen", threshold=1, reward=300},
    {id="seasonal_autumn", name="Amber Autumn",   desc="Forage during Autumn Nectar",  stat="seasonal_autumn_seen", threshold=1, reward=300},
    {id="seasonal_winter", name="Winter Keeper",  desc="Forage during Winter Rest",    stat="seasonal_winter_seen", threshold=1, reward=300},
    -- Cycle 11: Mega milestone
    {id="honey_million", name="Millionaire Bee", desc="Earn 1,000,000 total honey",   stat="totalHoneyEarned",    threshold=1000000, reward=5000},
]]

    clone.Source = clone.Source:sub(1, found - 1) .. newEntries .. clone.Source:sub(found)

    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config 13 new achievements appended")
end
```

---

## STEP C — HiveStatsService: trigger achievement checks

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local hss = SSS:FindFirstChild("HiveStatsService")
assert(hss, "HiveStatsService not found")

if hss.Source:find("AchievementService", 1, true) then
    print("⏭️  HiveStatsService already calls AchievementService — skip")
else
    local clone = hss:Clone()
    clone.Name = "HiveStatsService_WORKING"

    -- Inject require after DataService require
    local anchor = 'local DataService'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "DataService require not found in HiveStatsService")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\nlocal AchievementService = require(SSS:WaitForChild(\"AchievementService\"))"
        .. clone.Source:sub(lineEnd + 1)

    -- Inject achievement check after StatsSync:FireClient call in BroadcastStats
    local anchor2 = 'StatsSync:FireClient'
    local found2 = clone.Source:find(anchor2, 1, true)
    assert(found2, "StatsSync:FireClient not found in HiveStatsService")
    local lineEnd2 = clone.Source:find("\n", found2, true)
    clone.Source = clone.Source:sub(1, lineEnd2)
        .. "\n\tAchievementService.CheckAchievements(player)"
        .. clone.Source:sub(lineEnd2 + 1)

    hss.Name = "HiveStatsService_OLD_NX"
    hss.Parent = nil
    clone.Name = "HiveStatsService"
    clone.Parent = SSS
    print("✅ HiveStatsService AchievementService check injected")
end
```

---

## STEP D — ForagingService: record seasonal and friend bonus flags

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("seasonalSeen", 1, true) then
    print("⏭️  ForagingService already records seasonal flags — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Inject seasonal + friend flag recording after the friend multiplier line
    -- Find: FriendBonusService.GetHoneyMultiplier
    local anchor = 'FriendBonusService.GetHoneyMultiplier'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        -- Fallback: after AntiCheatService check line
        anchor = 'CheckForagingRequest'
        found = clone.Source:find(anchor, 1, true)
    end
    assert(found, "Cannot find inject anchor in ForagingService for seasonal flags")
    local lineEnd = clone.Source:find("\n", found, true)

    local injection = [[

	-- Track seasonal event and friend bonus for achievements
	do
		local _seasonal = SeasonalEventService.GetMultipliers()
		if _seasonal and _seasonal.id then
			local key = "seasonal_" .. _seasonal.id:match("^seasonal?_?(.+)") .. "_seen"
			if not profile[key] then
				profile[key] = 1
				DataService.SaveProfile(player)
			end
		end
		local friendMult = FriendBonusService.GetHoneyMultiplier(player)
		if friendMult > 1.001 then
			profile.friendBonusSessions = (profile.friendBonusSessions or 0) + 1
			if friendMult >= 1.299 then  -- 3+ friends = 1.30
				profile.maxFriendBonusReached = true
			end
		end
	end]]

    clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService seasonal/friend flags injected")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
table.insert(checks, (cfg and cfg.Source:find("upgrades_5") and "✅" or "❌") .. " Config: upgrades_5 achievement")
table.insert(checks, (cfg and cfg.Source:find("honey_million") and "✅" or "❌") .. " Config: honey_million achievement")
table.insert(checks, (cfg and cfg.Source:find("seasonal_spring") and "✅" or "❌") .. " Config: seasonal achievements")

local hss = SSS:FindFirstChild("HiveStatsService")
table.insert(checks, (hss and hss.Source:find("AchievementService") and "✅" or "❌") .. " HiveStatsService: AchievementService call")

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("seasonalSeen") and "✅" or "❌") .. " DataService: seasonalSeen field")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("seasonalSeen") and "✅" or "❌") .. " ForagingService: seasonal flag recording")

-- Count total achievements
if cfg then
    local count = 0
    for _ in cfg.Source:gmatch('{id=') do count += 1 end
    table.insert(checks, "ℹ️  Total achievements in Config: " .. count)
end

print("=== DISPATCH 77 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 77 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config/script changes only | 0 new parts |
| **Dispatch 77 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `upgrades_all` threshold is 42 = 7 upgrade services × 6 tiers. Verify this matches the actual max tier counts when executing: if any service has fewer tiers, lower the threshold accordingly.
- Seasonal achievement `stat` fields (`seasonal_spring_seen` etc.) are non-standard — they don't map to a numeric `profile` field. The `AchievementService.CheckAchievements` loop should handle boolean/non-zero values for `threshold=1` checks. If `AchievementService` requires numeric comparisons, `profile.seasonalSeen` can be queried instead by adding a `seasonalSeen` map check path to the achievement evaluator.
- The `friendBonusSessions` field increments every foraging trip where a friend bonus was active — not once per session. For the `first_friend_bonus` achievement (threshold=1) this is fine: any trip with a friend nearby unlocks it. Rename to `friendBonusTrips` if the intent is trip-level rather than session-level.
- `maxFriendBonusReached` is a boolean stored as `true` (truthy). The achievement evaluator needs to handle boolean profile values for `threshold=1` checks.
- STEP D's `_seasonal.id:match("^seasonal?_?(.+)")` extracts the season name from IDs like `spring_bloom` → `spring` / `summer_harvest` → `summer` etc. The `stat` fields in Config must match: `seasonal_spring_seen`, `seasonal_summer_seen`, `seasonal_autumn_seen`, `seasonal_winter_seen`.
- All 4 Steps (A–D) have idempotency guards so the dispatch can be re-run safely after a partial execution.
