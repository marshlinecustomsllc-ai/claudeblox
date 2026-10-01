# Dispatch 91 — Bee Count Upgrade
## Cycle 13 · A Bee's World

**Feature:** Adds a "Bee Count" upgrade tree (3 tiers) that increases the number of bees per owned plot. More bees → higher base yield multiplier applied before all other yield modifiers. `ForagingService` already tracks `plot.beeCount` (set at 1 initially); this dispatch adds upgrades that permanently raise the starting bee count for new foraging trips. The bee count multiplier stacks multiplicatively with honey/pollen/propolis yield upgrades.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 90 (Foraging Speed Upgrade)

---

## DESIGN

### New upgrades

| ID | Name | Cost | Effect |
|----|------|------|--------|
| `bee_count_1` | Larger Colony I | 400 honey | +1 bee/plot |
| `bee_count_2` | Larger Colony II | 1,000 honey | +1 bee/plot |
| `bee_count_3` | Larger Colony III | 2,500 honey | +1 bee/plot |

Starting bee count: 1 (base). At max upgrades: 4 bees/plot.

Yield per trip: `baseYield × beeCount × otherMultipliers`. So 4 bees/plot gives 4× the base honey before upgrades compound — a powerful late-game multiplier.

### ForagingService mechanism

Currently `ForagingService` computes yield as `baseHoneyPerBee × plot.beeCount`. The `plot.beeCount` is set to 1 when a plot is claimed. This dispatch adds a per-player permanent bee count bonus that applies when a foraging trip begins (or when plots are initialized for a player):

```lua
local beeBonus = UpgradeService.GetBeeCountBonus(player)  -- returns integer 0-3
-- plot.beeCount is set on trip start:
local effectiveBeeCount = (plot.beeCount or 1) + beeBonus
honeyYield = math.floor(baseHoneyPerBee * effectiveBeeCount * honeyMult)
```

`plot.beeCount` itself is NOT permanently modified — the bonus is computed fresh each trip. This ensures the bee count resets correctly after prestige (dispatch 81 clears `plot.beeCount = 0`; the upgrade bonus re-applies on the next trip).

### UpgradeService.GetBeeCountBonus

```lua
function UpgradeService.GetBeeCountBonus(player: Player): number
    local profile = DataService.GetProfile(player)
    if not profile then return 0 end
    local bonus = 0
    for _, upg in Config.UPGRADES do
        if upg.effect and upg.effect.type == "bee_count" then
            if profile.upgrades and profile.upgrades[upg.id] then
                bonus = bonus + 1  -- each tier = +1 bee
            end
        end
    end
    return bonus
end
```

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add 3 bee count upgrade entries to `UPGRADES` table |
| `UpgradeService` | Add `GetBeeCountBonus` function |
| `ForagingService` | Apply bee count bonus to effective bee count per trip |

---

## STEP A — Config: add bee count upgrades

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("bee_count_1", 1, true) then
    print("⏭️  Config already has bee count upgrades — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Find last upgrade entry and inject after it
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
	{id = "bee_count_1", name = "Larger Colony I",   desc = "+1 bee per plot", cost = {honey = 400},  effect = {type = "bee_count", value = 1}, maxLevel = 1},
	{id = "bee_count_2", name = "Larger Colony II",  desc = "+1 bee per plot", cost = {honey = 1000}, effect = {type = "bee_count", value = 1}, maxLevel = 1},
	{id = "bee_count_3", name = "Larger Colony III", desc = "+1 bee per plot", cost = {honey = 2500}, effect = {type = "bee_count", value = 1}, maxLevel = 1},
]]
    clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config: 3 bee count upgrades added")
end
```

---

## STEP B — UpgradeService: add GetBeeCountBonus

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local us = SSS:FindFirstChild("UpgradeService")
assert(us, "UpgradeService not found")

if us.Source:find("GetBeeCountBonus", 1, true) then
    print("⏭️  UpgradeService already has GetBeeCountBonus — skip")
else
    local clone = us:Clone()
    clone.Name = "UpgradeService_WORKING"

    -- Inject before 'return UpgradeService'
    local returnAnchor = 'return UpgradeService'
    local lastReturn = 1
    local searchFrom = 1
    while true do
        local next = clone.Source:find(returnAnchor, searchFrom, true)
        if not next then break end
        lastReturn = next
        searchFrom = next + 1
    end

    local newFn = [[

function UpgradeService.GetBeeCountBonus(player: Player): number
	local profile = DataService.GetProfile(player)
	if not profile then return 0 end
	local bonus = 0
	for _, upg in Config.UPGRADES do
		if upg.effect and upg.effect.type == "bee_count" then
			if profile.upgrades and profile.upgrades[upg.id] then
				bonus = bonus + 1
			end
		end
	end
	return bonus
end

]]
    clone.Source = clone.Source:sub(1, lastReturn - 1) .. newFn .. clone.Source:sub(lastReturn)

    us.Name = "UpgradeService_OLD_NX"
    us.Parent = nil
    clone.Name = "UpgradeService"
    clone.Parent = SSS
    print("✅ UpgradeService.GetBeeCountBonus added")
end
```

---

## STEP C — ForagingService: apply bee count bonus

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("GetBeeCountBonus", 1, true) then
    print("⏭️  ForagingService already applies GetBeeCountBonus — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Find where beeCount is used in yield computation
    -- Pattern: plot.beeCount  or  beeCount
    local anchor = 'plot%.beeCount'
    local found = clone.Source:find(anchor)
    if not found then
        anchor = 'beeCount'
        found = clone.Source:find(anchor, 1, true)
    end
    assert(found, "beeCount not found in ForagingService")

    local lineEnd = clone.Source:find("\n", found, true)
    -- Inject effective bee count before the line that uses beeCount in yield
    local lineStart = found
    while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
    local indent = clone.Source:sub(lineStart, found):match("^(%s*)") or "\t"

    clone.Source = clone.Source:sub(1, lineStart - 1)
        .. indent .. "local _beeBonus = UpgradeService.GetBeeCountBonus(player)\n"
        .. clone.Source:sub(lineStart):gsub("(plot%.beeCount)", "(plot.beeCount or 1) + _beeBonus", 1)

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService bee count bonus applied")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
local beeCount = 0
if cfg then
    for _ in cfg.Source:gmatch('bee_count_%d') do beeCount = beeCount + 1 end
end
table.insert(checks, (beeCount >= 3 and "✅" or "❌") .. " Config: " .. beeCount .. " / 3 bee count upgrades")

local us = SSS:FindFirstChild("UpgradeService")
table.insert(checks, (us and us.Source:find("GetBeeCountBonus") and "✅" or "❌") .. " UpgradeService: GetBeeCountBonus function")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("GetBeeCountBonus") and "✅" or "❌") .. " ForagingService: applies GetBeeCountBonus")
table.insert(checks, (fs and fs.Source:find("_beeBonus") and "✅" or "❌") .. " ForagingService: _beeBonus variable")

print("=== DISPATCH 91 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 91 complete" or "❌ SOME CHECKS FAILED")

print("\nBee count at each upgrade level:")
for i = 0, 3 do
    print("  " .. i .. " upgrades: " .. (1 + i) .. " bees/plot (" .. (1 + i) .. "x base yield)")
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config + source patches only | 0 new parts |
| **Dispatch 91 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The bee count bonus does NOT persist to `plot.beeCount`. This is intentional: prestige resets `plot.beeCount = 0` (dispatch 81), and applying the upgrade bonus only at trip time means the upgrade remains effective through prestige cycles without needing special prestige-reset handling.
- With 3/3 bee count upgrades, 5/5 honey yield upgrades, and prestige 10: base 10 honey/bee × 4 bees × 2.0 yield mult × 1.5 prestige mult = 120 honey/trip per plot. That's a 12× multiplier on the default 10 honey/trip. With 8 plots: 960 honey/trip total — the mid-game ceiling is well within the 5,000 max honey cap.
- The AntiCheat `dynamicHoneyCap` (dispatch 84) is `500 × 3.5 × prestigeMult × 1.10`. At prestige 10 (1.5×): 500 × 3.5 × 1.5 × 1.10 = 2,887. The max legitimate yield with all upgrades and 8 plots (120 × 8 = 960) is well under 2,887 — no anticheat ceiling update needed.
- `BeeParticleController` (dispatch 75) reads `plot.beeCount` from `PlotSync` payload to set particle rate (RATE_BUSY). Since `_beeBonus` is applied only during yield computation and doesn't change `plot.beeCount` in the plot table, the particle rate remains tied to the base `plot.beeCount`. A future dispatch can sync `effectiveBeeCount` to the client via `ForagingSync` if the visual should reflect the upgrade — deferred.
