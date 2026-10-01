# Dispatch 89 — Propolis Upgrade Tree
## Cycle 13 · A Bee's World

**Feature:** Adds a dedicated propolis upgrade tree to `Config.UPGRADES` and `UpgradeService.GetPropolisMultiplier`. Players spend propolis to increase propolis yield per foraging trip. Five upgrade levels add +20% each (mirror of the pollen tree from dispatch 88). Completes the upgrade symmetry: all three resources now have self-reinforcing upgrade trees.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 88 (Pollen Upgrade Tree)

---

## DESIGN

### New upgrades

| ID | Name | Cost | Effect |
|----|------|------|--------|
| `propolis_yield_1` | Resin Collector I | 40 propolis | +20% propolis/trip |
| `propolis_yield_2` | Resin Collector II | 100 propolis | +20% propolis/trip |
| `propolis_yield_3` | Resin Collector III | 220 propolis | +20% propolis/trip |
| `propolis_yield_4` | Resin Collector IV | 400 propolis | +20% propolis/trip |
| `propolis_yield_5` | Resin Collector V | 700 propolis | +20% propolis/trip |

Total investment: 1,460 propolis for +100% propolis yield. Costs slightly more than the pollen tree because propolis is also used for prestige conditions and expansion plot purchases — the tree is tuned to be completable within 3–4 prestige cycles.

### UpgradeService addition

```lua
function UpgradeService.GetPropolisMultiplier(player: Player): number
    -- mirrors GetPollenMultiplier, but checks "propolis_yield" effect type
end
```

### ForagingService patch

```lua
local propolisMult = UpgradeService.GetPropolisMultiplier(player)
propolisYield = math.floor(propolisYield * propolisMult)
```

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add 5 propolis upgrade entries to `UPGRADES` table |
| `UpgradeService` | Add `GetPropolisMultiplier` function |
| `ForagingService` | Apply `GetPropolisMultiplier` to `propolisYield` |

---

## STEP A — Config: add propolis upgrade tree

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("propolis_yield_1", 1, true) then
    print("⏭️  Config already has propolis upgrades — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Find last upgrade entry (last maxLevel line) and inject after it
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
	{id = "propolis_yield_1", name = "Resin Collector I",   desc = "+20% propolis/trip", cost = {propolis = 40},  effect = {type = "propolis_yield", value = 0.20}, maxLevel = 1},
	{id = "propolis_yield_2", name = "Resin Collector II",  desc = "+20% propolis/trip", cost = {propolis = 100}, effect = {type = "propolis_yield", value = 0.20}, maxLevel = 1},
	{id = "propolis_yield_3", name = "Resin Collector III", desc = "+20% propolis/trip", cost = {propolis = 220}, effect = {type = "propolis_yield", value = 0.20}, maxLevel = 1},
	{id = "propolis_yield_4", name = "Resin Collector IV",  desc = "+20% propolis/trip", cost = {propolis = 400}, effect = {type = "propolis_yield", value = 0.20}, maxLevel = 1},
	{id = "propolis_yield_5", name = "Resin Collector V",   desc = "+20% propolis/trip", cost = {propolis = 700}, effect = {type = "propolis_yield", value = 0.20}, maxLevel = 1},
]]

    clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config: 5 propolis upgrades added")
end
```

---

## STEP B — UpgradeService: add GetPropolisMultiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local us = SSS:FindFirstChild("UpgradeService")
assert(us, "UpgradeService not found")

if us.Source:find("GetPropolisMultiplier", 1, true) then
    print("⏭️  UpgradeService already has GetPropolisMultiplier — skip")
else
    local clone = us:Clone()
    clone.Name = "UpgradeService_WORKING"

    -- Inject GetPropolisMultiplier right after GetPollenMultiplier
    local anchor = 'GetPollenMultiplier'
    local found = clone.Source:find(anchor, 1, true)
    if found then
        -- Find the closing 'end' of GetPollenMultiplier function
        local funcEnd = clone.Source:find("\nend\n", found, true)
        if not funcEnd then funcEnd = clone.Source:find("\nend$", found, true) end
        assert(funcEnd, "Cannot find end of GetPollenMultiplier")
        local newFn = [[

function UpgradeService.GetPropolisMultiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1.0 end
	local mult = 1.0
	for _, upg in Config.UPGRADES do
		if upg.effect and upg.effect.type == "propolis_yield" then
			if profile.upgrades and profile.upgrades[upg.id] then
				mult = mult + upg.effect.value
			end
		end
	end
	return mult
end
]]
        clone.Source = clone.Source:sub(1, funcEnd + 3) .. newFn .. clone.Source:sub(funcEnd + 4)
        print("GetPropolisMultiplier injected after GetPollenMultiplier")
    else
        -- Fallback: inject before 'return UpgradeService'
        local returnAnchor = 'return UpgradeService'
        local lastReturn = 1
        local searchFrom2 = 1
        while true do
            local next = clone.Source:find(returnAnchor, searchFrom2, true)
            if not next then break end
            lastReturn = next
            searchFrom2 = next + 1
        end
        local newFn2 = [[

function UpgradeService.GetPropolisMultiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1.0 end
	local mult = 1.0
	for _, upg in Config.UPGRADES do
		if upg.effect and upg.effect.type == "propolis_yield" then
			if profile.upgrades and profile.upgrades[upg.id] then
				mult = mult + upg.effect.value
			end
		end
	end
	return mult
end

]]
        clone.Source = clone.Source:sub(1, lastReturn - 1) .. newFn2 .. clone.Source:sub(lastReturn)
        print("GetPropolisMultiplier injected via fallback before return UpgradeService")
    end

    us.Name = "UpgradeService_OLD_NX"
    us.Parent = nil
    clone.Name = "UpgradeService"
    clone.Parent = SSS
    print("✅ UpgradeService.GetPropolisMultiplier added")
end
```

---

## STEP C — ForagingService: apply propolis multiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("GetPropolisMultiplier", 1, true) then
    print("⏭️  ForagingService already applies GetPropolisMultiplier — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Find propolisYield assignment and inject multiplier after it
    local assignLine = clone.Source:find("propolisYield%s*=", 1, true)
    assert(assignLine, "propolisYield = assignment not found in ForagingService")

    -- Inject after the GetPollenMultiplier line if it exists, else after propolisYield assignment
    local pollenMult = clone.Source:find("GetPollenMultiplier", 1, true)
    local insertAfter = pollenMult or assignLine
    local lineEnd = clone.Source:find("\n", insertAfter, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\n\tpropolisYield = math.floor(propolisYield * UpgradeService.GetPropolisMultiplier(player))"
        .. clone.Source:sub(lineEnd + 1)

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService propolis multiplier applied")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
local proCount = 0
if cfg then
    for _ in cfg.Source:gmatch('propolis_yield_%d') do proCount = proCount + 1 end
end
table.insert(checks, (proCount >= 5 and "✅" or "❌") .. " Config: " .. proCount .. " / 5 propolis upgrades")

local us = SSS:FindFirstChild("UpgradeService")
table.insert(checks, (us and us.Source:find("GetPropolisMultiplier") and "✅" or "❌") .. " UpgradeService: GetPropolisMultiplier")
table.insert(checks, (us and us.Source:find("GetPollenMultiplier") and "✅" or "❌") .. " UpgradeService: GetPollenMultiplier still present")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetPropolisMultiplier") and "✅" or "❌") .. " ForagingService: applies GetPropolisMultiplier")
table.insert(checks, (fs and fs.Source:find("GetPollenMultiplier") and "✅" or "❌") .. " ForagingService: GetPollenMultiplier still present")

print("=== DISPATCH 89 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 89 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config + source patches only | 0 new parts |
| **Dispatch 89 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- "Resin Collector" names reference the bee behavior of collecting plant resins to make propolis. This fits the bee tycoon theme and differentiates the upgrade flavor from "Pollen Sacks" (dispatch 88) and the existing honey upgrades (earlier cycles).
- The propolis tree costs slightly more than the pollen tree (1,460 vs 1,240) because propolis has multiple sinks: prestige condition, expansion plot 7–8 purchases, and now this upgrade tree. The extra investment reflects the resource's broader utility.
- `GetPropolisMultiplier` is architecturally identical to `GetPollenMultiplier` — same pattern, different effect type string. A future refactor could merge them into `GetYieldMultiplier(player, effectType)`, but deferred: the current duplication is explicit and readable.
- After dispatch 88 + 89, `ForagingService` applies three independent multipliers to yields: honey × prestige (dispatch 79), pollen × pollen upgrades (dispatch 88), propolis × propolis upgrades (this dispatch). All three are `math.floor` at the end to keep yields as integers.
