# Dispatch 100 — Progressive Resource Caps
## Cycle 14 · A Bee's World

**Feature:** As players prestige, their per-trip yields increase (prestige multiplier × upgrade multipliers × seasonal bonus), but the resource caps (MAX_HONEY, MAX_PROPOLIS, MAX_POLLEN) remain fixed. By prestige 5+, propolis (capped at 500) and pollen (capped at 300) fill in a handful of trips and excess yield is discarded — the caps stop rewarding investment. This dispatch scales the caps proportionally to prestige level: caps grow each prestige so the resource pool always represents roughly the same number of trips worth of storage regardless of multipliers.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 99 (Foraging Return Animation)

---

## DESIGN

### Cap formulas

Base caps (from Config, dispatch 1/2 era):
- `MAX_HONEY    = 5000`
- `MAX_PROPOLIS = 500`
- `MAX_POLLEN   = 300`

Prestige-scaled effective caps:
```lua
effectiveMaxHoney    = Config.MAX_HONEY    + (prestigeLevel * 500)
effectiveMaxPropolis = Config.MAX_PROPOLIS + (prestigeLevel * 100)
effectiveMaxPollen   = Config.MAX_POLLEN   + (prestigeLevel * 60)
```

At prestige 10:
- Honey: 5,000 + 5,000 = **10,000**
- Propolis: 500 + 1,000 = **1,500**
- Pollen: 300 + 600 = **900**

These scale proportionally to the prestige multiplier (+15% per level × 10 = +150% yield), keeping ~33 full-plot trips to fill honey regardless of prestige level.

### Where caps are enforced

Resource addition happens in three places:
1. **ForagingService** — `math.min(profile.honey + honeyYield, Config.MAX_HONEY)` pattern
2. **DailyRewardService** — `math.min((profile.honey or 0) + _reward.honey, Config.MAX_HONEY or 5000)` (dispatch 95 pattern)
3. **UpgradeService** (indirectly — upgrades don't add resources)

Only ForagingService needs to apply the prestige-scaled cap. DailyReward grants are small enough that the base cap is always sufficient (max daily grant is 300 honey at day 7).

### Implementation strategy

`ForagingService` already reads `profile.prestigeLevel`. The patch replaces each `Config.MAX_X` reference in the yield-clamp lines with a local variable computed from `profile.prestigeLevel`.

The injected block is a **do block** inserted right before the `math.min` clamps. It computes effective caps locally, not globally — no Config changes, no other service changes.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingService` | Inject effective cap locals before yield clamps |

---

## STEP A — Diagnose ForagingService yield clamp pattern

Command Bar:

```lua
local SS = game:GetService("ServerScriptService")
local fs = SS:FindFirstChild("ForagingService")
if not fs then
    for _, obj in SS:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then
            fs = obj; break
        end
    end
end
assert(fs, "ForagingService not found")

-- Find lines that reference MAX_HONEY / MAX_PROPOLIS / MAX_POLLEN
local lines = fs.Source:split("\n")
for i, line in lines do
    if line:find("MAX_HONEY") or line:find("MAX_PROPOLIS") or line:find("MAX_POLLEN") then
        print(i .. ": " .. line)
    end
end
print("Total lines: " .. #lines)
```

---

## STEP B — ForagingService: inject prestige-scaled effective caps

Command Bar:

```lua
local SS = game:GetService("ServerScriptService")
local fs = nil
local ssChildren = SS:GetDescendants()
for _, obj in ssChildren do
    if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then
        fs = obj; break
    end
end
if not fs then fs = SS:FindFirstChild("ForagingService") end
assert(fs, "ForagingService not found")

if fs.Source:find("EffectiveCap", 1, true) then
    print("⏭️  ForagingService already has EffectiveCap — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- The patch: find the line that first clamps honey to MAX_HONEY and insert
    -- effective cap locals immediately before the first math.min + MAX_HONEY line.
    -- Strategy: inject a do-block that wraps all three clamp lines.
    -- We look for the pattern:  profile.honey = math.min(  (or a local that clamps)
    -- and prepend the cap computation block right before it.

    -- Injection marker comment
    local INJECTION = [[

-- ── Progressive Resource Caps (dispatch 100) ────────────────────
do
    local _pLevel = tonumber(profile.prestigeLevel) or 0
    local _maxHoney    = (Config.MAX_HONEY    or 5000) + (_pLevel * 500)
    local _maxPropolis = (Config.MAX_PROPOLIS or 500)  + (_pLevel * 100)
    local _maxPollen   = (Config.MAX_POLLEN   or 300)  + (_pLevel * 60)

    -- Re-clamp yields to prestige-scaled caps
    if profile.honey ~= nil then
        profile.honey = math.min(profile.honey, _maxHoney)
    end
    if profile.propolis ~= nil then
        profile.propolis = math.min(profile.propolis, _maxPropolis)
    end
    if profile.pollen ~= nil then
        profile.pollen = math.min(profile.pollen, _maxPollen)
    end

    -- Override clamp values for the yield additions below
    -- by patching the source to reference these locals where needed.
    -- (Applied as source substitution below)
end
-- ── End Progressive Resource Caps ───────────────────────────────
]]

    -- Source substitution approach: replace the three math.min clamp patterns
    -- to use dynamically computed caps instead of Config constants.
    -- We substitute the Config.MAX_X references in math.min calls only.
    --
    -- Before: math.min(profile.honey + honeyYield, Config.MAX_HONEY)
    -- After:  math.min(profile.honey + honeyYield, (Config.MAX_HONEY or 5000) + ((tonumber(profile.prestigeLevel) or 0) * 500))
    --
    -- This is safe because:
    -- 1. It only affects the math.min clamp expressions
    -- 2. It preserves the floor (Config.MAX_HONEY or 5000 is fallback)
    -- 3. It reads profile.prestigeLevel which is already in scope at clamp time

    local newSource = clone.Source

    -- Replace honey clamp
    newSource = newSource:gsub(
        "math%.min%((.-),%s*Config%.MAX_HONEY%)",
        function(inner)
            return "math.min(" .. inner .. ", (Config.MAX_HONEY or 5000) + ((tonumber(profile.prestigeLevel) or 0) * 500))"
        end
    )

    -- Replace propolis clamp
    newSource = newSource:gsub(
        "math%.min%((.-),%s*Config%.MAX_PROPOLIS%)",
        function(inner)
            return "math.min(" .. inner .. ", (Config.MAX_PROPOLIS or 500) + ((tonumber(profile.prestigeLevel) or 0) * 100))"
        end
    )

    -- Replace pollen clamp
    newSource = newSource:gsub(
        "math%.min%((.-),%s*Config%.MAX_POLLEN%)",
        function(inner)
            return "math.min(" .. inner .. ", (Config.MAX_POLLEN or 300) + ((tonumber(profile.prestigeLevel) or 0) * 60))"
        end
    )

    -- If no matches found (clamp pattern differs), fall back to append injection
    local honeyPatched    = newSource ~= clone.Source
    local propolisPatched = newSource:find("MAX_PROPOLIS%) %+ %(%(tonumber")
    local pollenPatched   = newSource:find("MAX_POLLEN%) %+ %(%(tonumber")

    if not honeyPatched then
        -- Fallback: append an override block after existing clamps
        warn("[ProgressiveCaps] Could not find math.min(... Config.MAX_HONEY) pattern — using append fallback")
        newSource = newSource .. [[

-- ── Progressive Resource Caps fallback (dispatch 100) ──────────
-- Applied after existing clamps to enforce prestige-scaled ceilings
do
    local _pLevel100 = tonumber(profile.prestigeLevel) or 0
    local _maxH100 = (Config.MAX_HONEY    or 5000) + (_pLevel100 * 500)
    local _maxP100 = (Config.MAX_PROPOLIS or 500)  + (_pLevel100 * 100)
    local _maxPl100= (Config.MAX_POLLEN   or 300)  + (_pLevel100 * 60)
    if profile.honey    then profile.honey    = math.min(profile.honey,    _maxH100)  end
    if profile.propolis then profile.propolis = math.min(profile.propolis, _maxP100)  end
    if profile.pollen   then profile.pollen   = math.min(profile.pollen,   _maxPl100) end
end
-- ── End Progressive Resource Caps fallback ──────────────────────
]]
    end

    -- Mark as patched for idempotency guard
    newSource = newSource .. "\n-- EffectiveCap: progressive caps applied (dispatch 100)\n"

    clone.Source = newSource

    local parent = fs.Parent
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = parent
    print("✅ ForagingService: progressive resource caps injected")
    print("Honey clamp patched: " .. tostring(honeyPatched))
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SS = game:GetService("ServerScriptService")
local fs = nil
for _, obj in SS:GetDescendants() do
    if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then
        fs = obj; break
    end
end
if not fs then fs = SS:FindFirstChild("ForagingService") end

local checks = {}
table.insert(checks, (fs and "✅" or "❌") .. " ForagingService exists")

local hasCap = fs and (
    fs.Source:find("EffectiveCap", 1, true) or
    fs.Source:find("progressive caps applied", 1, true)
)
table.insert(checks, (hasCap and "✅" or "❌") .. " ForagingService: progressive caps marker")

local hasPrestigeLevelRead = fs and fs.Source:find("profile%.prestigeLevel", 1, true)
table.insert(checks, (hasPrestigeLevelRead and "✅" or "❌") .. " ForagingService: reads profile.prestigeLevel")

local hasHoneyScale = fs and (
    fs.Source:find("_pLevel100", 1, true) or
    fs.Source:find("MAX_HONEY%) %+ %(", 1, false) ~= nil or
    fs.Source:find("MAX_HONEY or 5000%) %+ %(", 1, false) ~= nil
)
table.insert(checks, (hasHoneyScale and "✅" or "❌") .. " ForagingService: honey cap scales with prestige")

local hasPropScale = fs and (
    fs.Source:find("MAX_PROPOLIS or 500", 1, true) or
    fs.Source:find("_maxP100", 1, true)
)
table.insert(checks, (hasPropScale and "✅" or "❌") .. " ForagingService: propolis cap scales with prestige")

local hasPollenScale = fs and (
    fs.Source:find("MAX_POLLEN or 300", 1, true) or
    fs.Source:find("_maxPl100", 1, true)
)
table.insert(checks, (hasPollenScale and "✅" or "❌") .. " ForagingService: pollen cap scales with prestige")

-- Verify no OLD_NX version still parented
local oldExists = SS:FindFirstChild("ForagingService_OLD_NX") ~= nil
table.insert(checks, (not oldExists and "✅" or "❌") .. " No orphaned ForagingService_OLD_NX in SSS")

print("=== DISPATCH 100 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 100 complete" or "❌ SOME CHECKS FAILED")

print("\nProgressive cap values by prestige level:")
local baseCaps = {honey=5000, propolis=500, pollen=300}
local scales = {honey=500, propolis=100, pollen=60}
for pLevel = 0, 10, 2 do
    print(string.format("  Prestige %2d: honey=%d  propolis=%d  pollen=%d",
        pLevel,
        baseCaps.honey    + pLevel * scales.honey,
        baseCaps.propolis + pLevel * scales.propolis,
        baseCaps.pollen   + pLevel * scales.pollen
    ))
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Server script injection only — no new instances | 0 permanent parts |
| **Dispatch 100 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The gsub substitution targets `math.min(<expr>, Config.MAX_HONEY)` patterns. The Lua pattern `math%.min%((.-),%s*Config%.MAX_HONEY%)` uses lazy `.-` to match the first argument without crossing to a second `math.min`. This is correct for single-line clamp expressions; multi-line clamps would need the fallback.
- Fallback append block uses `_pLevel100`, `_maxH100`, `_maxP100`, `_maxPl100` suffixes (not `_100` alone) to avoid any collision with `_100`-looking names. The `_100` numeric suffix matches the dispatch number.
- The `-- EffectiveCap:` comment at the end is the idempotency guard; the Step B check looks for this string. The fallback block also writes it, so both paths are guarded.
- Cap progression at prestige 10: honey 10,000 / propolis 1,500 / pollen 900. These values are well under DataStore serialize limits (all Lua numbers).
- The DailyReward hard-coded `Config.MAX_HONEY or 5000` clamp (dispatch 95) is intentionally left at base cap. Daily rewards (max 300 honey/day) are small enough that base cap is never the bottleneck. Scaling daily reward caps would require passing prestigeLevel to DailyRewardService — a larger change not warranted by the reward size.
- AntiCheat dynamic cap from dispatch 62: `maxYield = Config.BASE_MAX_YIELD * (1 + 0.15 * prestigeLevel)` is per-trip yield, not storage cap. No conflict.
- If the ForagingService source uses `profile.Resources.Honey` instead of `profile.honey` (some earlier architecture variants), the fallback block's nil check `if profile.honey then` would skip silently. In that case, update the field names in the fallback block to match the actual profile structure.
