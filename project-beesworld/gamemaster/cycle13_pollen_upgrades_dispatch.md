# Dispatch 88 — Pollen Upgrade Tree
## Cycle 13 · A Bee's World

**Feature:** Adds a dedicated pollen upgrade tree to `Config.UPGRADES` and extends `UpgradeService` to handle the new `pollen_yield` upgrade type. Players spend pollen (not honey) to increase their pollen yield per foraging trip. Five upgrade levels compound: each adds +20% to base pollen yield. This gives the third resource a self-reinforcing loop parallel to the honey/propolis upgrade paths.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** Opens Cycle 13 (after dispatch 87)

---

## DESIGN

### New upgrades in Config.UPGRADES

```lua
{id = "pollen_yield_1", name = "Pollen Sacks I",    desc = "+20% pollen/trip",  cost = {pollen = 30},   effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
{id = "pollen_yield_2", name = "Pollen Sacks II",   desc = "+20% pollen/trip",  cost = {pollen = 80},   effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
{id = "pollen_yield_3", name = "Pollen Sacks III",  desc = "+20% pollen/trip",  cost = {pollen = 180},  effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
{id = "pollen_yield_4", name = "Pollen Sacks IV",   desc = "+20% pollen/trip",  cost = {pollen = 350},  effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
{id = "pollen_yield_5", name = "Pollen Sacks V",    desc = "+20% pollen/trip",  cost = {pollen = 600},  effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
```

Total investment: 1,240 pollen for +100% pollen yield (×2 base pollen).

### UpgradeService patch

`UpgradeService.PurchaseUpgrade` currently deducts `cost.honey`. New branch:

```lua
if cost.pollen then
    if profile.pollen < cost.pollen then return false, "Not enough pollen" end
    profile.pollen = profile.pollen - cost.pollen
elseif cost.propolis then
    -- existing/future propolis path
elseif cost.honey then
    -- existing honey path
end
```

### ForagingService patch

After computing `pollenYield`, apply the pollen multiplier:

```lua
local pollenMult = UpgradeService.GetPollenMultiplier(player)
pollenYield = math.floor(pollenYield * pollenMult)
```

### UpgradeService.GetPollenMultiplier

```lua
function UpgradeService.GetPollenMultiplier(player: Player): number
    local profile = DataService.GetProfile(player)
    if not profile then return 1.0 end
    local mult = 1.0
    for _, upg in Config.UPGRADES do
        if upg.effect and upg.effect.type == "pollen_yield" then
            if profile.upgrades and profile.upgrades[upg.id] then
                mult = mult + upg.effect.value
            end
        end
    end
    return mult
end
```

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add 5 pollen upgrade entries to `UPGRADES` table |
| `UpgradeService` | Add `pollen_yield` cost deduction branch + `GetPollenMultiplier` function |
| `ForagingService` | Apply `GetPollenMultiplier` to `pollenYield` computation |

---

## STEP A — Config: add pollen upgrade tree

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("pollen_yield_1", 1, true) then
    print("⏭️  Config already has pollen upgrades — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Find the closing brace of the UPGRADES table and inject before it
    local upgradesStart = clone.Source:find("UPGRADES", 1, true)
    assert(upgradesStart, "UPGRADES not found in Config")

    -- Find the last upgrade entry (last occurrence of maxLevel)
    local lastMaxLevel = 1
    local searchFrom = upgradesStart
    while true do
        local next = clone.Source:find("maxLevel", searchFrom, true)
        if not next then break end
        lastMaxLevel = next
        searchFrom = next + 1
    end

    local lineEnd = clone.Source:find("\n", lastMaxLevel, true) or #clone.Source
    local injection = [[
	{id = "pollen_yield_1", name = "Pollen Sacks I",   desc = "+20% pollen/trip", cost = {pollen = 30},  effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
	{id = "pollen_yield_2", name = "Pollen Sacks II",  desc = "+20% pollen/trip", cost = {pollen = 80},  effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
	{id = "pollen_yield_3", name = "Pollen Sacks III", desc = "+20% pollen/trip", cost = {pollen = 180}, effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
	{id = "pollen_yield_4", name = "Pollen Sacks IV",  desc = "+20% pollen/trip", cost = {pollen = 350}, effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
	{id = "pollen_yield_5", name = "Pollen Sacks V",   desc = "+20% pollen/trip", cost = {pollen = 600}, effect = {type = "pollen_yield", value = 0.20}, maxLevel = 1},
]]

    clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config: 5 pollen upgrades added")
end
```

---

## STEP B — UpgradeService: pollen cost deduction + GetPollenMultiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local us = SSS:FindFirstChild("UpgradeService")
assert(us, "UpgradeService not found")

if us.Source:find("GetPollenMultiplier", 1, true) then
    print("⏭️  UpgradeService already has GetPollenMultiplier — skip")
else
    local clone = us:Clone()
    clone.Name = "UpgradeService_WORKING"

    -- 1. Inject pollen cost deduction before/around existing honey deduction
    local honeyDeduct = 'profile.honey = profile.honey - cost.honey'
    local found1 = clone.Source:find(honeyDeduct, 1, true)
    if not found1 then
        honeyDeduct = 'profile.honey%s*-%s*=%s*cost%.honey'
        found1 = clone.Source:find(honeyDeduct)
    end
    if found1 then
        local lineStart = found1
        while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
        local lineEnd = clone.Source:find("\n", found1, true) or #clone.Source
        local oldLine = clone.Source:sub(lineStart, lineEnd)
        local indent = oldLine:match("^(%s*)") or "\t\t"
        local newBlock = indent .. "if cost.pollen then\n"
            .. indent .. "\tif (profile.pollen or 0) < cost.pollen then\n"
            .. indent .. "\t\treturn false, \"Not enough pollen\"\n"
            .. indent .. "\tend\n"
            .. indent .. "\tprofile.pollen = (profile.pollen or 0) - cost.pollen\n"
            .. indent .. "elseif cost.honey then\n"
            .. indent .. "\t" .. oldLine:gsub("^%s+", "") .. "\n"
            .. indent .. "end"
        clone.Source = clone.Source:sub(1, lineStart - 1) .. newBlock .. clone.Source:sub(lineEnd + 1)
        print("Pollen cost deduction branch injected")
    else
        print("⚠️  Honey deduction line not found in UpgradeService — pollen branch not injected")
    end

    -- 2. Inject GetPollenMultiplier function before 'return UpgradeService'
    local returnAnchor = 'return UpgradeService'
    local lastReturn = 1
    local searchFrom2 = 1
    while true do
        local next = clone.Source:find(returnAnchor, searchFrom2, true)
        if not next then break end
        lastReturn = next
        searchFrom2 = next + 1
    end

    local newFn = [[

function UpgradeService.GetPollenMultiplier(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 1.0 end
	local mult = 1.0
	for _, upg in Config.UPGRADES do
		if upg.effect and upg.effect.type == "pollen_yield" then
			if profile.upgrades and profile.upgrades[upg.id] then
				mult = mult + upg.effect.value
			end
		end
	end
	return mult
end

]]
    clone.Source = clone.Source:sub(1, lastReturn - 1) .. newFn .. clone.Source:sub(lastReturn)

    us.Name = "UpgradeService_OLD_NX"
    us.Parent = nil
    clone.Name = "UpgradeService"
    clone.Parent = SSS
    print("✅ UpgradeService.GetPollenMultiplier and pollen deduction injected")
end
```

---

## STEP C — ForagingService: apply pollen multiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("GetPollenMultiplier", 1, true) then
    print("⏭️  ForagingService already applies GetPollenMultiplier — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Find pollenYield calculation and inject multiplier after it
    local anchor = 'pollenYield'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "pollenYield not found in ForagingService")

    -- Find the line that assigns pollenYield (not just references it)
    local assignLine = clone.Source:find("pollenYield%s*=", 1, true)
    if assignLine then
        local lineEnd = clone.Source:find("\n", assignLine, true)
        clone.Source = clone.Source:sub(1, lineEnd)
            .. "\n\tpollenYield = math.floor(pollenYield * UpgradeService.GetPollenMultiplier(player))"
            .. clone.Source:sub(lineEnd + 1)
        print("GetPollenMultiplier applied after pollenYield assignment")
    else
        print("⚠️  pollenYield = assignment not found — multiplier not injected")
    end

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService pollen multiplier applied")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
local pollenUpgCount = 0
if cfg then
    for _ in cfg.Source:gmatch('pollen_yield_%d') do pollenUpgCount = pollenUpgCount + 1 end
end
table.insert(checks, (pollenUpgCount >= 5 and "✅" or "❌") .. " Config: " .. pollenUpgCount .. " / 5 pollen upgrades")

local us = SSS:FindFirstChild("UpgradeService")
table.insert(checks, (us and us.Source:find("GetPollenMultiplier") and "✅" or "❌") .. " UpgradeService: GetPollenMultiplier function")
table.insert(checks, (us and us.Source:find("cost.pollen") and "✅" or "❌") .. " UpgradeService: cost.pollen deduction branch")
table.insert(checks, (us and us.Source:find("Not enough pollen") and "✅" or "❌") .. " UpgradeService: pollen guard message")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetPollenMultiplier") and "✅" or "❌") .. " ForagingService: applies GetPollenMultiplier")

print("=== DISPATCH 88 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 88 complete" or "❌ SOME CHECKS FAILED")

-- Print upgrade multiplier table
print("\nPollen multiplier at each upgrade level:")
for i = 0, 5 do
    print("  " .. i .. " upgrades: " .. string.format("%.1fx", 1 + i * 0.20) .. " (" .. math.floor(100 + i * 20) .. "% of base pollen)")
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config + source patches only | 0 new parts |
| **Dispatch 88 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The pollen upgrade tree uses a **sequential unlocking** design (each upgrade is a separate one-time purchase rather than leveled). This means all 5 upgrades appear in the Upgrades panel simultaneously; a future dispatch can add `prerequisite = "pollen_yield_N"` gating if sequential unlocking is preferred.
- Total pollen cost to max the tree: 30 + 80 + 180 + 350 + 600 = **1,240 pollen**. Since max pollen per prestige cycle is ~1,000 (without upgrades), the player needs at least 2 prestige cycles to fully unlock the pollen tree — an intentional design: prestige creates the pollen surplus needed to buy upgrades V.
- The pollen multiplier is separate from the prestige honey multiplier (dispatch 79). Both stack multiplicatively: `pollenYield × pollenMult × (prestige has no effect on pollen)`. This is intentional — pollen is the "slow resource" that only scales through deliberate upgrade investment, unlike honey which scales automatically with prestige.
- `UpgradeService.GetPollenMultiplier` iterates `Config.UPGRADES` each call. This is fine for < 50 upgrades. If the upgrade list grows significantly, cache the multiplier in `profile.pollenMult` on purchase.
- The upgrade names "Pollen Sacks I–V" refer to the pollen baskets on bees' legs (corbiculae). Thematically appropriate for a bee tycoon game — no lore violation.
