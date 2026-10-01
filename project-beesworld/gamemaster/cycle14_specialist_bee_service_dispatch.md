# Dispatch 143 — Specialist Bee Service Integration
## Cycle 14 · A Bee's World

**Feature:** Wire Scout Bee (+20% foraging quality) and Nurse Bee (+15% brood speed) into the live service layer. Both bees were purchasable via dispatch 141 but had no mechanical effect. This dispatch patches `ForagingService` and `CombService` to read `SpecialistBees` and apply the bonuses server-side. Part budget: +0 permanent (edits only).
**Part budget impact:** +0 permanent → **4,149 / 5,000**
**Execution order:** After dispatch 142 (Guard Bee Hotfix)

---

## DESIGN

### Scout Bee — ForagingService patch

`ForagingService` already computes `ForagingQuality` (0–100) on each trip return. The Scout Bee should add a flat +20 to the raw quality roll **before** it is clamped to 100.

Current quality line (from the original foraging dispatch):
```lua
local quality = math.random(40, 80)
```

Updated:
```lua
local baseQuality = math.random(40, 80)
local scoutBonus_143 = tostring(player:GetAttribute("SpecialistBees") or ""):find("scout_bee", 1, true) and 20 or 0
local quality = math.min(100, baseQuality + scoutBonus_143)
```

Effect: Scout owners roll 60–100 quality instead of 40–80. The `math.min(100, ...)` cap preserves the ceiling.

### Nurse Bee — CombService brood cell patch

Brood cells have an internal timer that advances honey production rate. `CombService` uses a per-cell tick interval stored as `BROOD_TICK_143`. The Nurse Bee reduces the effective tick interval by 15%.

There is no single "brood speed" constant to patch — the CombService cell loop ticks on a shared interval. The patch injects a per-player multiplier check: for each player who owns `nurse_bee`, brood cells produce an extra 15% output per tick rather than reducing the timer (simpler, same effect, no timer drift risk).

Current brood produce line (approximation — exact line varies by your CombService version):
```lua
local produced = math.floor(broodRate * elapsed)
```

Updated approach — multiply `produced` by the nurse bonus after calculation:
```lua
local nurseMulti_143 = tostring(player:GetAttribute("SpecialistBees") or ""):find("nurse_bee", 1, true) and 1.15 or 1.0
local produced = math.floor(broodRate * elapsed * nurseMulti_143)
```

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingService` | +3 lines: Scout Bee quality bonus |
| `CombService` | +3 lines: Nurse Bee brood multiplier |

---

## STEP A — Patch ForagingService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("ForagingService")
assert(svc, "ForagingService not found — check ServerScriptService")

-- Find and replace the quality calculation line
local old = [[local quality = math.random(40, 80)]]
local new = [[
            local baseQuality_143 = math.random(40, 80)
            local scoutBonus_143  = tostring(player:GetAttribute("SpecialistBees") or ""):find("scout_bee", 1, true) and 20 or 0
            local quality = math.min(100, baseQuality_143 + scoutBonus_143)]]

if svc.Source:find(old, 1, true) then
    svc.Source = svc.Source:gsub(old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), new:gsub("%%","%%%%"), 1)
    print("✅ ForagingService patched — Scout Bee quality bonus active (+20 to raw quality roll, capped at 100)")
elseif svc.Source:find("scoutBonus_143", 1, true) then
    print("⏭️  ForagingService already has Scout Bee patch — skip")
else
    print("⚠️  Quality line not found in ForagingService — patch manually:")
    print("    Find: local quality = math.random(40, 80)")
    print("    Replace with the scout bonus block from dispatch 143 STEP A")
end
```

---

## STEP B — Patch CombService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
-- CombService may be in Systems subfolder
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))
assert(comb, "CombService not found — check ServerScriptService and ServerScriptService.Systems")

-- Find and replace the brood produced line
local old = [[local produced = math.floor(broodRate * elapsed)]]
local new = [[
            local nurseMulti_143 = tostring(player:GetAttribute("SpecialistBees") or ""):find("nurse_bee", 1, true) and 1.15 or 1.0
            local produced = math.floor(broodRate * elapsed * nurseMulti_143)]]

if comb.Source:find(old, 1, true) then
    comb.Source = comb.Source:gsub(old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), new:gsub("%%","%%%%"), 1)
    print("✅ CombService patched — Nurse Bee brood multiplier active (+15% produced per tick)")
elseif comb.Source:find("nurseMulti_143", 1, true) then
    print("⏭️  CombService already has Nurse Bee patch — skip")
else
    print("⚠️  Brood produced line not found — CombService may use different variable name.")
    print("    Search for: math.floor(broodRate")
    print("    Or search for the honey production math in the cell tick loop.")
    print("    Wrap the final produced value: local produced = math.floor(...) * nurseMulti_143")
    -- Fallback: show CombService source for manual inspection
    print("\n--- CombService Source (first 60 lines) ---")
    local lines = {}
    local i = 0
    for line in (comb.Source .. "\n"):gmatch("([^\n]*)\n") do
        i = i + 1
        if i <= 60 then table.insert(lines, i .. ": " .. line) end
    end
    print(table.concat(lines, "\n"))
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local foraging = SSS:FindFirstChild("ForagingService")
local combSvc  = SSS:FindFirstChild("CombService") or
                 (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))

local checks = {}

-- Scout Bee
table.insert(checks, (foraging and foraging.Source:find("scoutBonus_143", 1, true) and "✅" or "❌")
    .. " ForagingService has Scout Bee quality bonus (scoutBonus_143)")
table.insert(checks, (foraging and foraging.Source:find("math.min(100,", 1, true) and "✅" or "❌")
    .. " quality capped at 100 (math.min)")

-- Nurse Bee
table.insert(checks, (combSvc and combSvc.Source:find("nurseMulti_143", 1, true) and "✅" or "❌")
    .. " CombService has Nurse Bee multiplier (nurseMulti_143)")
table.insert(checks, (combSvc and combSvc.Source:find("1.15", 1, true) and "✅" or "❌")
    .. " Nurse Bee 1.15× multiplier constant")

-- Guard Bee (regression check from dispatch 142)
local bearSvc = SSS:FindFirstChild("BearAttackService")
table.insert(checks, (bearSvc and bearSvc.Source:find("hasGuard_142", 1, true) and "✅" or "❌")
    .. " BearAttackService Guard Bee patch (dispatch 142 — regression check)")

print("=== DISPATCH 143 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 143 complete" or "❌ SOME CHECKS FAILED")

print("\nSpecialist Bee effects summary:")
print("  scout_bee  → ForagingQuality +20 (roll 60-100 vs baseline 40-80)")
print("  nurse_bee  → Brood produced ×1.15 per tick (+15% honey from brood cells)")
print("  guard_bee  → Bear drain –5% (dispatch 142, confirmed above)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| ForagingService patch (Script edit — no new instances) | 0 |
| CombService patch (Script edit — no new instances) | 0 |
| **Dispatch 143 total** | **+0** |
| **Running total** | **4,149 / 5,000** |

---

## NOTES

- The `math.min(100, baseQuality_143 + scoutBonus_143)` cap is deliberate. Scout Bee owners still have a ceiling — a 100-quality trip feels earned but possible. Without the cap, rolling 80 base + 20 bonus would silently overflow into undefined behavior if `ForagingQuality` feeds downstream logic expecting 0–100.
- The Nurse Bee multiplier (`× 1.15`) is applied to `produced` (the integer output per tick), not to `broodRate` (the rate constant). This avoids permanently modifying a shared rate and means the bonus turns off the moment `SpecialistBees` no longer contains `nurse_bee` — important for future prestige resets where `SpecialistBees` is intentionally NOT reset (the bee stays owned, the bonus continues). If `SpecialistBees` ever resets on prestige, this requires a design decision, but keeping the bonus persistent-across-prestige is the intended design for v1.
- The fallback diagnostic block in STEP B (source dump) helps if `CombService` was modified since dispatch 139 and the exact line signature changed. In that case, search for the surrounding context (`broodRate`, `elapsed`, the honey write line) and manually wrap the `produced` assignment.
- All three specialist bees are now mechanically complete:
  - `nurse_bee` (dispatch 143) — brood output +15%
  - `scout_bee` (dispatch 143) — foraging quality +20, capped at 100
  - `guard_bee` (dispatch 142) — bear drain –5%, stacks with hive_insulation
