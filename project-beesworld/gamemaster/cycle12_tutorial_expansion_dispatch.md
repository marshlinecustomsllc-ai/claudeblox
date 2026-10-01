# Dispatch 83 — TutorialService: Prestige & Seasonal Steps
## Cycle 12 · A Bee's World

**Feature:** Expands `TutorialService` with two new tutorial steps covering (1) the prestige/rebirth mechanic introduced in Cycle 12 and (2) seasonal events introduced in Cycle 10. Both steps fire only once per profile and are guarded by the existing `profile.tutorialStep` field. Clients receive the new step text via the existing `TutorialSync` RemoteEvent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 82 (PrestigeReadySync)

---

## DESIGN

`TutorialService` currently checks `profile.tutorialStep` (integer 0–N) and fires a step when conditions are met. New steps are injected at the end of the existing step table (before the final `return TutorialService`).

### New steps

| Step ID | Trigger condition | Text |
|---------|-------------------|------|
| `prestige_intro` | `profile.prestigeLevel == 0` AND player has owned all 8 plots at least once (`profile.totalPrestigeCount >= 0` + honey full + propolis full) OR player has had honey full for 3+ consecutive trips | "Fill ALL resources + own all 8 plots to PRESTIGE! 🌟 You'll restart with a permanent +5% honey bonus each trip." |
| `prestige_done` | `profile.prestigeLevel >= 1` (fires once after first prestige completes) | "You prestiged! ⭐ Your honey bonus is now active. Own plots faster than before and prestige again for more!" |
| `seasonal_intro` | First time `profile.seasonalSeen` has an entry (any seasonal event seen) | "🌸 Seasonal events boost honey yields for all players! Check the HUD for the active season bonus." |

`prestige_intro` fires BEFORE prestige (when the player is close but hasn't done it yet). Its trigger is: `profile.honey >= maxHoney * 0.90` AND `profile.propolis >= maxPropolis * 0.90` AND player owns ≥ 6 plots AND `profile.tutorialStep_prestige_intro` not already seen.

`prestige_done` fires AFTER the first prestige: checked on `ProfileLoaded` and on each `RequestPrestige` success. Uses `profile.tutorialSeen.prestige_done` boolean flag.

`seasonal_intro` fires from `HiveStatsService` after the first seasonal event is recorded. Uses `profile.tutorialSeen.seasonal_intro` boolean flag.

All three booleans stored in `profile.tutorialSeen` table (new DataService field, defaults to `{}`).

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DataService` | Add `tutorialSeen = {}` default to profile schema |
| `TutorialService` | Add `ShowStep(player, stepId, text)` helper + three new trigger checks |
| `ForagingService` | After yield applied, check `prestige_intro` condition |
| `PrestigeService` | After prestige success, fire `prestige_done` step |
| `HiveStatsService` | After seasonal flag recorded, fire `seasonal_intro` step |

---

## STEP A — DataService: add tutorialSeen field

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

if ds.Source:find("tutorialSeen", 1, true) then
    print("⏭️  DataService already has tutorialSeen — skip")
else
    local clone = ds:Clone()
    clone.Name = "DataService_WORKING"

    -- Find default profile table; inject tutorialSeen after tutorialStep or near the end
    local anchor = 'tutorialStep'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        -- Fallback: inject before closing brace of default profile
        anchor = 'totalHoneyEarned'
        found = clone.Source:find(anchor, 1, true)
    end
    if found then
        local lineEnd = clone.Source:find("\n", found, true)
        clone.Source = clone.Source:sub(1, lineEnd)
            .. "\n\t\ttutorialSeen = {},"
            .. clone.Source:sub(lineEnd + 1)
        print("Injected tutorialSeen after anchor: " .. anchor)
    else
        print("⚠️  Could not find anchor — tutorialSeen not injected")
    end

    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil
    clone.Name = "DataService"
    clone.Parent = SSS
    print("✅ DataService.tutorialSeen field added")
end
```

---

## STEP B — TutorialService: add ShowStep helper and trigger checks

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ts = SSS:FindFirstChild("TutorialService")
assert(ts, "TutorialService not found")

if ts.Source:find("tutorialSeen", 1, true) then
    print("⏭️  TutorialService already has tutorialSeen logic — skip")
else
    local clone = ts:Clone()
    clone.Name = "TutorialService_WORKING"

    -- Inject ShowStep helper and CheckPrestigeIntro before 'return TutorialService'
    local returnAnchor = 'return TutorialService'
    local lastFound = 1
    local searchFrom = 1
    while true do
        local next = clone.Source:find(returnAnchor, searchFrom, true)
        if not next then break end
        lastFound = next
        searchFrom = next + 1
    end

    local newFns = [[

-- Generic one-shot tutorial step dispatcher
local function ShowStep(player: Player, stepId: string, text: string)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	if type(profile.tutorialSeen) ~= "table" then profile.tutorialSeen = {} end
	if profile.tutorialSeen[stepId] then return end
	profile.tutorialSeen[stepId] = true
	local re = game:GetService("ReplicatedStorage"):FindFirstChild("TutorialSync")
	if re then re:FireClient(player, {text = text, stepId = stepId}) end
end

function TutorialService.CheckPrestigeIntro(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	if profile.prestigeLevel and profile.prestigeLevel >= 1 then return end  -- already prestiged
	local Config = require(game:GetService("ServerScriptService"):WaitForChild("Config"))
	local maxHoney    = Config.MAX_HONEY    or 5000
	local maxPropolis = Config.MAX_PROPOLIS or 1000
	if (profile.honey or 0) >= maxHoney * 0.9
		and (profile.propolis or 0) >= maxPropolis * 0.9 then
		ShowStep(player, "prestige_intro",
			"Fill ALL resources + own all 8 plots to PRESTIGE! 🌟 You'll get a permanent +5% honey bonus per trip.")
	end
end

function TutorialService.ShowPrestigeDone(player: Player)
	ShowStep(player, "prestige_done",
		"You prestiged! ⭐ Honey bonus is now active. Prestige again to stack bonuses even higher!")
end

function TutorialService.ShowSeasonalIntro(player: Player)
	ShowStep(player, "seasonal_intro",
		"🌸 A seasonal event is active! All players get a honey yield boost. Check HUD for the bonus.")
end

]]
    clone.Source = clone.Source:sub(1, lastFound - 1) .. newFns .. clone.Source:sub(lastFound)

    ts.Name = "TutorialService_OLD_NX"
    ts.Parent = nil
    clone.Name = "TutorialService"
    clone.Parent = SSS
    print("✅ TutorialService helpers injected")
end
```

---

## STEP C — ForagingService: call CheckPrestigeIntro after yield

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("CheckPrestigeIntro", 1, true) then
    print("⏭️  ForagingService already calls CheckPrestigeIntro — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Inject TutorialService require near top (after DataService require)
    if not clone.Source:find("TutorialService", 1, true) then
        local anchor = 'local DataService'
        local found = clone.Source:find(anchor, 1, true)
        if found then
            local lineEnd = clone.Source:find("\n", found, true)
            clone.Source = clone.Source:sub(1, lineEnd)
                .. "\nlocal TutorialService = require(SSS:WaitForChild(\"TutorialService\"))"
                .. clone.Source:sub(lineEnd + 1)
        end
    end

    -- Inject CheckPrestigeIntro call after DataService.SaveProfile or profile.honey update
    local anchor2 = 'CheckAndBroadcastReady'
    local found2 = clone.Source:find(anchor2, 1, true)
    if not found2 then
        anchor2 = 'DataService.SaveProfile'
        found2 = clone.Source:find(anchor2, 1, true)
    end
    if found2 then
        local lineEnd2 = clone.Source:find("\n", found2, true)
        clone.Source = clone.Source:sub(1, lineEnd2)
            .. "\n\ttask.spawn(function() TutorialService.CheckPrestigeIntro(player) end)"
            .. clone.Source:sub(lineEnd2 + 1)
    else
        print("⚠️  Could not find inject anchor in ForagingService for CheckPrestigeIntro")
    end

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService CheckPrestigeIntro call injected")
end
```

---

## STEP D — PrestigeService: call ShowPrestigeDone after success

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PrestigeService")
assert(ps, "PrestigeService not found")

if ps.Source:find("ShowPrestigeDone", 1, true) then
    print("⏭️  PrestigeService already calls ShowPrestigeDone — skip")
else
    local clone = ps:Clone()
    clone.Name = "PrestigeService_WORKING"

    -- Inject TutorialService require after existing requires
    if not clone.Source:find("TutorialService", 1, true) then
        local anchor = 'local PrestigeReadySync'
        local found = clone.Source:find(anchor, 1, true)
        if not found then
            anchor = 'local PrestigeSync'
            found = clone.Source:find(anchor, 1, true)
        end
        if found then
            local lineEnd = clone.Source:find("\n", found, true)
            clone.Source = clone.Source:sub(1, lineEnd)
                .. "\nlocal TutorialService = require(SSS:WaitForChild(\"TutorialService\"))"
                .. clone.Source:sub(lineEnd + 1)
        end
    end

    -- Inject ShowPrestigeDone after the profile.prestigeLevel increment
    local anchor2 = 'profile.prestigeLevel'
    local found2 = clone.Source:find(anchor2, 1, true)
    if found2 then
        local lineEnd2 = clone.Source:find("\n", found2, true)
        clone.Source = clone.Source:sub(1, lineEnd2)
            .. "\n\ttask.spawn(function() TutorialService.ShowPrestigeDone(player) end)"
            .. clone.Source:sub(lineEnd2 + 1)
    else
        print("⚠️  Could not find prestigeLevel anchor in PrestigeService for ShowPrestigeDone")
    end

    ps.Name = "PrestigeService_OLD_NX"
    ps.Parent = nil
    clone.Name = "PrestigeService"
    clone.Parent = SSS
    print("✅ PrestigeService ShowPrestigeDone call injected")
end
```

---

## STEP E — HiveStatsService: call ShowSeasonalIntro after first seasonal event

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local hs = SSS:FindFirstChild("HiveStatsService")
assert(hs, "HiveStatsService not found")

if hs.Source:find("ShowSeasonalIntro", 1, true) then
    print("⏭️  HiveStatsService already calls ShowSeasonalIntro — skip")
else
    local clone = hs:Clone()
    clone.Name = "HiveStatsService_WORKING"

    -- Inject TutorialService require near top
    if not clone.Source:find("TutorialService", 1, true) then
        local anchor = 'local DataService'
        local found = clone.Source:find(anchor, 1, true)
        if found then
            local lineEnd = clone.Source:find("\n", found, true)
            clone.Source = clone.Source:sub(1, lineEnd)
                .. "\nlocal TutorialService = require(SSS:WaitForChild(\"TutorialService\"))"
                .. clone.Source:sub(lineEnd + 1)
        end
    end

    -- Inject ShowSeasonalIntro after seasonalSeen or seasonal event detection
    local anchor2 = 'seasonalSeen'
    local found2 = clone.Source:find(anchor2, 1, true)
    if found2 then
        local lineEnd2 = clone.Source:find("\n", found2, true)
        clone.Source = clone.Source:sub(1, lineEnd2)
            .. "\n\t\ttask.spawn(function() TutorialService.ShowSeasonalIntro(player) end)"
            .. clone.Source:sub(lineEnd2 + 1)
    else
        print("⚠️  seasonalSeen anchor not found in HiveStatsService — ShowSeasonalIntro not injected")
    end

    hs.Name = "HiveStatsService_OLD_NX"
    hs.Parent = nil
    clone.Name = "HiveStatsService"
    clone.Parent = SSS
    print("✅ HiveStatsService ShowSeasonalIntro call injected")
end
```

---

## STEP F — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("tutorialSeen") and "✅" or "❌") .. " DataService: tutorialSeen field")

local ts = SSS:FindFirstChild("TutorialService")
table.insert(checks, (ts and ts.Source:find("ShowStep") and "✅" or "❌") .. " TutorialService: ShowStep helper")
table.insert(checks, (ts and ts.Source:find("CheckPrestigeIntro") and "✅" or "❌") .. " TutorialService: CheckPrestigeIntro")
table.insert(checks, (ts and ts.Source:find("ShowPrestigeDone") and "✅" or "❌") .. " TutorialService: ShowPrestigeDone")
table.insert(checks, (ts and ts.Source:find("ShowSeasonalIntro") and "✅" or "❌") .. " TutorialService: ShowSeasonalIntro")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("CheckPrestigeIntro") and "✅" or "❌") .. " ForagingService: calls CheckPrestigeIntro")

local ps = SSS:FindFirstChild("PrestigeService")
table.insert(checks, (ps and ps.Source:find("ShowPrestigeDone") and "✅" or "❌") .. " PrestigeService: calls ShowPrestigeDone")

local hs = SSS:FindFirstChild("HiveStatsService")
table.insert(checks, (hs and hs.Source:find("ShowSeasonalIntro") and "✅" or "❌") .. " HiveStatsService: calls ShowSeasonalIntro")

print("=== DISPATCH 83 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 83 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patches only | 0 new parts |
| **Dispatch 83 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `tutorialSeen` is a new sub-table inside the player's profile. DataService must serialize it correctly — if DataService uses a flat schema (not nested tables), substitute individual boolean fields: `tutorialSeen_prestige_intro = false`, `tutorialSeen_prestige_done = false`, `tutorialSeen_seasonal_intro = false`. The STEP A injection uses the nested table pattern; adjust if the schema is flat.
- `ShowStep` is deliberately generic — it can serve any future one-shot tutorial hints by calling `TutorialService.ShowStep(player, id, text)` from anywhere. The `stepId` is stored in `profile.tutorialSeen[stepId]` so it survives server restarts.
- `CheckPrestigeIntro` uses a 90% threshold (not 100%) so the tip appears *before* the player hits the ceiling, giving them time to act on the advice rather than seeing it after they've already figured it out.
- The `TutorialSync` RemoteEvent is expected to already exist from earlier TutorialService dispatches. If it does not exist, create it: `local re = Instance.new("RemoteEvent"); re.Name = "TutorialSync"; re.Parent = game:GetService("ReplicatedStorage")`.
- `ShowSeasonalIntro` is injected after the *first* `seasonalSeen` write in HiveStatsService. Because `seasonalSeen` is initialized as `{}`, the first time any seasonal event sets a key it will also fire the tutorial. If HiveStatsService records seasonal events differently (e.g. a `currentSeason` string field), adjust the anchor to match.
- No changes to `TutorialController` (client side) are required — it already handles arbitrary `text` payloads from `TutorialSync` and displays them in the existing tutorial frame.
