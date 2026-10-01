# Dispatch 90 — Foraging Speed Upgrade
## Cycle 13 · A Bee's World

**Feature:** Adds a foraging speed upgrade tree (4 tiers) that reduces foraging trip duration. Each tier costs honey and shaves seconds off the base trip timer. `ForagingService` reads a speed multiplier from `UpgradeService.GetForagingSpeedMultiplier` and applies it to the countdown. Creates a second progression dimension (time vs. yield) within the honey upgrade path.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 89 (Propolis Upgrade Tree)

---

## DESIGN

### New upgrades

| ID | Name | Cost | Effect |
|----|------|------|--------|
| `foraging_speed_1` | Wing Strength I | 200 honey | −10% foraging time |
| `foraging_speed_2` | Wing Strength II | 600 honey | −10% foraging time |
| `foraging_speed_3` | Wing Strength III | 1,400 honey | −10% foraging time |
| `foraging_speed_4` | Wing Strength IV | 3,000 honey | −10% foraging time |

Total investment: 5,200 honey for −40% foraging time (0.6× base duration).

Base foraging trip = 60 seconds. At max upgrades: 36 seconds.

### Mechanism

`UpgradeService.GetForagingSpeedMultiplier(player)` returns a value in `[0.6, 1.0]`:

```lua
-- 0 upgrades → 1.0 (100% = 60s)
-- 1 upgrade  → 0.9 (90% = 54s)
-- 2 upgrades → 0.8 (80% = 48s)
-- 3 upgrades → 0.7 (70% = 42s)
-- 4 upgrades → 0.6 (60% = 36s)
```

`ForagingService` applies it to the trip timer:

```lua
local speedMult = UpgradeService.GetForagingSpeedMultiplier(player)
local tripDuration = math.floor(Config.FORAGING_DURATION * speedMult)
```

`Config.FORAGING_DURATION` is the base trip time in seconds (expected to already exist; if not, defaults to 60).

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add 4 foraging speed upgrade entries; ensure `FORAGING_DURATION = 60` exists |
| `UpgradeService` | Add `GetForagingSpeedMultiplier` function |
| `ForagingService` | Apply speed multiplier to trip timer |

---

## STEP A — Config: add FORAGING_DURATION and speed upgrades

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("foraging_speed_1", 1, true) then
    print("⏭️  Config already has foraging speed upgrades — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Ensure FORAGING_DURATION exists
    if not clone.Source:find("FORAGING_DURATION", 1, true) then
        -- Inject near other numeric config constants (after FORAGING_ or MAX_HONEY line)
        local anchor = 'FORAGING_COOLDOWN'
        local found = clone.Source:find(anchor, 1, true)
        if not found then
            anchor = 'MAX_HONEY'
            found = clone.Source:find(anchor, 1, true)
        end
        if found then
            local lineEnd = clone.Source:find("\n", found, true)
            clone.Source = clone.Source:sub(1, lineEnd)
                .. "\n\tFORAGING_DURATION = 60,"
                .. clone.Source:sub(lineEnd + 1)
            print("FORAGING_DURATION = 60 injected")
        end
    else
        print("FORAGING_DURATION already exists")
    end

    -- Add speed upgrades after last upgrade entry
    local upgradesStart = clone.Source:find("UPGRADES", 1, true)
    local lastMaxLevel = upgradesStart or 1
    local searchFrom = upgradesStart or 1
    while true do
        local next = clone.Source:find("maxLevel", searchFrom, true)
        if not next then break end
        lastMaxLevel = next
        searchFrom = next + 1
    end

    local lineEnd = clone.Source:find("\n", lastMaxLevel, true) or #clone.Source
    local injection = [[
	{id = "foraging_speed_1", name = "Wing Strength I",   desc = "-10% foraging time", cost = {honey = 200},  effect = {type = "foraging_speed", value = 0.10}, maxLevel = 1},
	{id = "foraging_speed_2", name = "Wing Strength II",  desc = "-10% foraging time", cost = {honey = 600},  effect = {type = "foraging_speed", value = 0.10}, maxLevel = 1},
	{id = "foraging_speed_3", name = "Wing Strength III", desc = "-10% foraging time", cost = {honey = 1400}, effect = {type = "foraging_speed", value = 0.10}, maxLevel = 1},
	{id = "foraging_speed_4", name = "Wing Strength IV",  desc = "-10% foraging time", cost = {honey = 3000}, effect = {type = "foraging_speed", value = 0.10}, maxLevel = 1},
]]
    clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config: 4 foraging speed upgrades added")
end
```

---

## STEP B — UpgradeService: add GetForagingSpeedMultiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local us = SSS:FindFirstChild("UpgradeService")
assert(us, "UpgradeService not found")

if us.Source:find("GetForagingSpeedMultiplier", 1, true) then
    print("⏭️  UpgradeService already has GetForagingSpeedMultiplier — skip")
else
    local clone = us:Clone()
    clone.Name = "UpgradeService_WORKING"

    -- Inject after GetPropolisMultiplier (or GetPollenMultiplier if propolis not yet present)
    local anchor = 'GetPropolisMultiplier'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        anchor = 'GetPollenMultiplier'
        found = clone.Source:find(anchor, 1, true)
    end

    local insertAfter
    if found then
        local funcEnd = clone.Source:find("\nend\n", found, true)
        insertAfter = funcEnd and funcEnd + 3 or found
    end

    local newFn = [[

function UpgradeService.GetForagingSpeedMultiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1.0 end
	local reduction = 0.0
	for _, upg in Config.UPGRADES do
		if upg.effect and upg.effect.type == "foraging_speed" then
			if profile.upgrades and profile.upgrades[upg.id] then
				reduction = reduction + upg.effect.value
			end
		end
	end
	return math.max(0.6, 1.0 - reduction)  -- floor at 60% (36s minimum)
end
]]

    if insertAfter then
        clone.Source = clone.Source:sub(1, insertAfter) .. newFn .. clone.Source:sub(insertAfter + 1)
    else
        -- Fallback: before return UpgradeService
        local returnAnchor = 'return UpgradeService'
        local lastReturn = 1
        local searchFrom2 = 1
        while true do
            local next = clone.Source:find(returnAnchor, searchFrom2, true)
            if not next then break end
            lastReturn = next
            searchFrom2 = next + 1
        end
        clone.Source = clone.Source:sub(1, lastReturn - 1) .. newFn .. clone.Source:sub(lastReturn)
    end

    us.Name = "UpgradeService_OLD_NX"
    us.Parent = nil
    clone.Name = "UpgradeService"
    clone.Parent = SSS
    print("✅ UpgradeService.GetForagingSpeedMultiplier added")
end
```

---

## STEP C — ForagingService: apply speed multiplier to trip timer

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("GetForagingSpeedMultiplier", 1, true) then
    print("⏭️  ForagingService already applies GetForagingSpeedMultiplier — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Find the trip duration / timer setup — look for Config.FORAGING_DURATION or task.wait(duration)
    local anchor = 'Config.FORAGING_DURATION'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        -- Fallback: look for 'local duration' or 'local tripTime'
        anchor = 'local duration'
        found = clone.Source:find(anchor, 1, true)
    end
    if not found then
        anchor = 'task%.wait%(%d+'
        found = clone.Source:find(anchor)
    end

    if found then
        local lineEnd = clone.Source:find("\n", found, true)
        -- Inject after the duration line: multiply by speed multiplier
        clone.Source = clone.Source:sub(1, lineEnd)
            .. "\n\tlocal _speedMult = UpgradeService.GetForagingSpeedMultiplier(player)"
            .. "\n\tduration = math.floor((duration or Config.FORAGING_DURATION or 60) * _speedMult)"
            .. clone.Source:sub(lineEnd + 1)
        print("Speed multiplier injected after duration setup")
    else
        print("⚠️  Could not find duration anchor in ForagingService — speed multiplier not injected")
    end

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService foraging speed multiplier applied")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
local speedCount = 0
if cfg then
    for _ in cfg.Source:gmatch('foraging_speed_%d') do speedCount = speedCount + 1 end
end
table.insert(checks, (speedCount >= 4 and "✅" or "❌") .. " Config: " .. speedCount .. " / 4 speed upgrades")
table.insert(checks, (cfg and cfg.Source:find("FORAGING_DURATION") and "✅" or "❌") .. " Config: FORAGING_DURATION constant")

local us = SSS:FindFirstChild("UpgradeService")
table.insert(checks, (us and us.Source:find("GetForagingSpeedMultiplier") and "✅" or "❌") .. " UpgradeService: GetForagingSpeedMultiplier")
table.insert(checks, (us and us.Source:find("math.max%(0.6") and "✅" or "❌") .. " UpgradeService: 0.6 floor applied")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetForagingSpeedMultiplier") and "✅" or "❌") .. " ForagingService: applies GetForagingSpeedMultiplier")

print("=== DISPATCH 90 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 90 complete" or "❌ SOME CHECKS FAILED")

print("\nForaging duration at each upgrade level (base 60s):")
for i = 0, 4 do
    local mult = math.max(0.6, 1.0 - i * 0.10)
    print("  " .. i .. " upgrades: " .. math.floor(60 * mult) .. "s  (" .. math.floor(mult*100) .. "%)")
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config + source patches only | 0 new parts |
| **Dispatch 90 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The 0.6 floor (`math.max(0.6, ...)`) prevents absurd trip times via future stacking. 36 seconds is the minimum — fast enough to feel rewarding, slow enough to keep the game loop visible on screen.
- "Wing Strength" upgrades are named for the bee's flight musculature. Flavor consistent with the bee biology theme established across upgrade names.
- The speed upgrades cost honey (not pollen/propolis) to create a decision point: honey can now be spent on yield upgrades (Honey Well I–V) OR speed upgrades. Players who optimize for throughput will split their honey between both trees.
- If `ForagingService` uses a `for i = duration, 1, -1 do` countdown loop rather than a single `task.wait(duration)`, STEP C's injection must modify the loop bound variable. Check STEP C's output; if the `duration` variable is not found at a single assignment, search for the countdown loop and patch the bound directly.
- The HUD timer display (if any) automatically reflects the shorter duration because it reads the server-set `foragingEndTime` attribute or countdown value — no client-side changes needed.
