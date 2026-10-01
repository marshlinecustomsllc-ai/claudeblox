# Dispatch 93 — HiveStats Upgrade Count Integration
## Cycle 13 · A Bee's World

**Feature:** `HiveStatsService` currently broadcasts hive stats (honey, propolis, pollen, plots, prestige) but does NOT include the total number of purchased upgrades. The achievement system (dispatch 77) has three upgrade-count achievements (`upgrades_5`, `upgrades_20`, `upgrades_all`) whose condition `{type="upgrades_bought", value=N}` requires `profile.totalUpgradesBought` to be counted correctly. This dispatch adds the upgrade count to HiveStatsSync broadcasts AND fires `AchievementService.CheckAchievements` after every upgrade purchase so these achievements trigger at the right moments.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 92 (Upgrades Panel Category Tabs)

---

## DESIGN

### Problem

`UpgradeService.PurchaseUpgrade` increments `profile.upgrades[id] = true` but:
1. Never calls `AchievementService.CheckAchievements(player)` — upgrade-count achievements never fire
2. `HiveStatsService.BroadcastStats` does not include upgrade count — client HUD and any future upgrade-count display have no data source
3. `profile.totalUpgradesBought` field is either absent (never initialised) or not incremented

### Fix

Three small patches:

**A. DataService** — ensure `totalUpgradesBought = 0` is in the default profile schema so new players start with 0.

**B. UpgradeService.PurchaseUpgrade** — after setting `profile.upgrades[id] = true`, increment `profile.totalUpgradesBought` and call `AchievementService.CheckAchievements(player)` inside a `task.spawn`.

**C. HiveStatsService.BroadcastStats** — add `totalUpgrades = profile.totalUpgradesBought or 0` to the stats payload fired to the client.

### Achievement trigger chain (after patch B)

```
player buys upgrade
  → profile.upgrades[id] = true
  → profile.totalUpgradesBought += 1
  → task.spawn → AchievementService.CheckAchievements(player)
      → checks upgrades_5  (value=5)  → fires if totalUpgradesBought >= 5
      → checks upgrades_20 (value=20) → fires if totalUpgradesBought >= 20
      → checks upgrades_all (value=?) → fires if totalUpgradesBought >= #Config.UPGRADES
```

### upgrades_bought condition in AchievementService

The condition type `upgrades_bought` must already branch in `AchievementService` from dispatch 77. If it doesn't yet count from `profile.totalUpgradesBought`, STEP B patches the branch to use the new field.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DataService` | Add `totalUpgradesBought = 0` to default profile schema |
| `UpgradeService` | Increment `totalUpgradesBought` + call `AchievementService.CheckAchievements` after purchase |
| `HiveStatsService` | Add `totalUpgrades` field to BroadcastStats payload |

---

## STEP A — DataService: add totalUpgradesBought to default profile

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

if ds.Source:find("totalUpgradesBought", 1, true) then
    print("⏭️  DataService already has totalUpgradesBought — skip")
else
    local clone = ds:Clone()
    clone.Name = "DataService_WORKING"

    -- Find where default profile fields are defined
    -- Common patterns: prestigeLevel = 0, or pollen = 0, or propolis = 0
    local anchor = 'prestigeLevel%s*=%s*0'
    local found = clone.Source:find(anchor)
    if not found then
        anchor = 'pollen%s*=%s*0'
        found = clone.Source:find(anchor)
    end
    if not found then
        anchor = 'propolis%s*=%s*0'
        found = clone.Source:find(anchor)
    end
    assert(found, "Could not find default profile field in DataService")

    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\t\ttotalUpgradesBought = 0,\n"
        .. clone.Source:sub(lineEnd + 1)

    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil
    clone.Name = "DataService"
    clone.Parent = SSS
    print("✅ DataService: totalUpgradesBought = 0 added to default profile")
end
```

---

## STEP B — UpgradeService: increment counter + trigger achievements

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local us = SSS:FindFirstChild("UpgradeService")
assert(us, "UpgradeService not found")

if us.Source:find("totalUpgradesBought", 1, true) then
    print("⏭️  UpgradeService already increments totalUpgradesBought — skip")
else
    local clone = us:Clone()
    clone.Name = "UpgradeService_WORKING"

    -- Find the line that sets profile.upgrades[id] = true
    local anchor = 'profile%.upgrades%[.*%]%s*=%s*true'
    local found = clone.Source:find(anchor)
    assert(found, "profile.upgrades[id] = true not found in UpgradeService")

    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\n\t\tprofile.totalUpgradesBought = (profile.totalUpgradesBought or 0) + 1"
        .. "\n\t\ttask.spawn(function()"
        .. "\n\t\t\tlocal ok, err = pcall(AchievementService.CheckAchievements, player)"
        .. "\n\t\t\tif not ok then warn('[UpgradeService] CheckAchievements failed:', err) end"
        .. "\n\t\tend)"
        .. clone.Source:sub(lineEnd + 1)

    -- Ensure AchievementService is required at the top
    if not clone.Source:find("AchievementService", 1, true) then
        -- Inject require after last require line near the top
        local lastRequire = 1
        local searchFrom = 1
        while true do
            local next = clone.Source:find("require(", searchFrom, true)
            if not next then break end
            lastRequire = next
            searchFrom = next + 1
        end
        local reqLineEnd = clone.Source:find("\n", lastRequire, true)
        clone.Source = clone.Source:sub(1, reqLineEnd)
            .. "\nlocal AchievementService = require(game:GetService('ServerScriptService'):WaitForChild('AchievementService'))\n"
            .. clone.Source:sub(reqLineEnd + 1)
        print("AchievementService require injected")
    else
        print("AchievementService already required")
    end

    us.Name = "UpgradeService_OLD_NX"
    us.Parent = nil
    clone.Name = "UpgradeService"
    clone.Parent = SSS
    print("✅ UpgradeService: totalUpgradesBought increment + achievement check added")
end
```

---

## STEP C — HiveStatsService: add totalUpgrades to broadcast payload

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local hs = SSS:FindFirstChild("HiveStatsService")
assert(hs, "HiveStatsService not found")

if hs.Source:find("totalUpgrades", 1, true) then
    print("⏭️  HiveStatsService already broadcasts totalUpgrades — skip")
else
    local clone = hs:Clone()
    clone.Name = "HiveStatsService_WORKING"

    -- Find the stats payload table — look for a line like 'honey = profile.honey'
    -- or 'prestige = profile.prestigeLevel'
    local anchor = 'prestige%s*=%s*profile%.prestigeLevel'
    local found = clone.Source:find(anchor)
    if not found then
        anchor = 'honey%s*=%s*profile%.honey'
        found = clone.Source:find(anchor)
    end
    assert(found, "stats payload not found in HiveStatsService")

    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\n\t\t\ttotalUpgrades = profile.totalUpgradesBought or 0,"
        .. clone.Source:sub(lineEnd + 1)

    hs.Name = "HiveStatsService_OLD_NX"
    hs.Parent = nil
    clone.Name = "HiveStatsService"
    clone.Parent = SSS
    print("✅ HiveStatsService: totalUpgrades added to BroadcastStats payload")
end
```

---

## STEP D — AchievementService: ensure upgrades_bought condition reads totalUpgradesBought

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local as = SSS:FindFirstChild("AchievementService")
assert(as, "AchievementService not found")

-- Check if upgrades_bought condition already uses totalUpgradesBought
if as.Source:find("totalUpgradesBought", 1, true) then
    print("✅ AchievementService already reads totalUpgradesBought — no patch needed")
else
    local clone = as:Clone()
    clone.Name = "AchievementService_WORKING"

    -- Find upgrades_bought condition branch
    local anchor = 'upgrades_bought'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        -- Inject new branch before elseif or end that closes the condition block
        -- Find the last known condition type (e.g. prestige_level from dispatch 85)
        local lastCond = clone.Source:find('prestige_level', 1, true)
        if not lastCond then
            -- fallback: find the closing 'end' after condition block
            lastCond = clone.Source:find('met%s*=', 1, true)
        end
        assert(lastCond, "Cannot find condition branch in AchievementService")
        local lineEnd = clone.Source:find("\n", lastCond, true)
        -- Walk to end of that elseif block (find next 'elseif' or standalone 'end')
        local blockEnd = clone.Source:find("\n\t\tend\n", lineEnd, true)
        if not blockEnd then blockEnd = lineEnd end
        local blockLineEnd = clone.Source:find("\n", blockEnd + 4, true) or #clone.Source
        clone.Source = clone.Source:sub(1, blockLineEnd)
            .. "\n\t\telseif cond.type == \"upgrades_bought\" then"
            .. "\n\t\t\tmet = (profile.totalUpgradesBought or 0) >= (cond.value or 1)"
            .. clone.Source:sub(blockLineEnd + 1)
        print("upgrades_bought condition branch injected")
    else
        -- Branch exists but uses old field — replace with totalUpgradesBought
        -- Find the 'met =' line inside the upgrades_bought block
        local metLine = clone.Source:find("met%s*=", found, true)
        if metLine then
            local metLineEnd = clone.Source:find("\n", metLine, true)
            clone.Source = clone.Source:sub(1, metLine - 1)
                .. "met = (profile.totalUpgradesBought or 0) >= (cond.value or 1)"
                .. clone.Source:sub(metLineEnd)
            print("upgrades_bought branch updated to use totalUpgradesBought")
        else
            print("⚠️  upgrades_bought found but met= line not located — manual check needed")
        end
    end

    as.Name = "AchievementService_OLD_NX"
    as.Parent = nil
    clone.Name = "AchievementService"
    clone.Parent = SSS
    print("✅ AchievementService: upgrades_bought condition reads totalUpgradesBought")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("totalUpgradesBought", 1, true) and "✅" or "❌") .. " DataService: totalUpgradesBought in default profile")

local us = SSS:FindFirstChild("UpgradeService")
table.insert(checks, (us and us.Source:find("totalUpgradesBought", 1, true) and "✅" or "❌") .. " UpgradeService: increments totalUpgradesBought")
table.insert(checks, (us and us.Source:find("CheckAchievements", 1, true) and "✅" or "❌") .. " UpgradeService: calls CheckAchievements after purchase")
table.insert(checks, (us and us.Source:find("AchievementService", 1, true) and "✅" or "❌") .. " UpgradeService: AchievementService required")

local hs = SSS:FindFirstChild("HiveStatsService")
table.insert(checks, (hs and hs.Source:find("totalUpgrades", 1, true) and "✅" or "❌") .. " HiveStatsService: totalUpgrades in broadcast payload")

local as = SSS:FindFirstChild("AchievementService")
table.insert(checks, (as and as.Source:find("totalUpgradesBought", 1, true) and "✅" or "❌") .. " AchievementService: reads totalUpgradesBought for upgrades_bought condition")

print("=== DISPATCH 93 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 93 complete" or "❌ SOME CHECKS FAILED")

-- Show expected achievement unlock thresholds
print("\nUpgrade count achievements:")
print("  upgrades_5  → 5 total upgrades purchased  (reward: 100 honey)")
print("  upgrades_20 → 20 total upgrades purchased (reward: 500 honey)")
print("  upgrades_all → ALL upgrades purchased     (reward: 2000 honey)")
print("\nTotal upgrades in game (Cycles 1-13):")
print("  ~5 honey upgrades + 4 speed + 3 bee count = 12 honey-cost")
print("  5 pollen upgrades = 5 pollen-cost")
print("  5 propolis upgrades = 5 propolis-cost")
print("  Total: ~22 upgrades → upgrades_all.value should be 22")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patches only (no BaseParts) | 0 new parts |
| **Dispatch 93 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The `totalUpgradesBought` field is initialised to 0 in the default profile (STEP A). Existing players who already have `profile.upgrades` populated will have `totalUpgradesBought = nil` until they purchase another upgrade; the `(profile.totalUpgradesBought or 0) + 1` expression in STEP B handles the nil case gracefully, incrementing from 0 on their next purchase. For a strict count of already-owned upgrades, a migration pass could count keys in `profile.upgrades` on first login — deferred since most active players are in early–mid game.
- `task.spawn` wrapping `CheckAchievements` in STEP B prevents any achievement processing delay from blocking the upgrade purchase response. The 22ms achievement check runs concurrently with DataService.SaveProfile.
- STEP D is defensive: if the `upgrades_bought` condition branch already exists and already uses `totalUpgradesBought`, it prints a skip message and makes no changes.
- The `upgrades_all` achievement's `value` in Config.ACHIEVEMENTS (dispatch 77) should equal the total upgrade count. After Cycles 11-13, there are ~22 upgrades. If Config.ACHIEVEMENTS has a different value (e.g. 15 from when it was first written), update it: `{id="upgrades_all", condition={type="upgrades_bought", value=22}, reward={honey=2000}}`. Add this as a Config patch in STEP A if needed.
- `HiveStatsService.BroadcastStats` payload now includes `totalUpgrades` — the HiveStatsController client can display this in a "Upgrades: X" stat line on the HUD if desired. No client changes required now; data is available for future UI dispatch.
