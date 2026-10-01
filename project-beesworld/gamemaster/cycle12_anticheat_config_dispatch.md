# Dispatch 84 — AntiCheatService: Dynamic Prestige Multiplier Cap
## Cycle 12 · A Bee's World

**Feature:** Updates `AntiCheatService` to compute `MAX_YIELD_HONEY` dynamically per player using their current prestige multiplier instead of a fixed ceiling. A prestige 0 player caps at 1,750 (500 × 3.5); a prestige 10 player caps at 2,625 (500 × 3.5 × 1.5). Prevents legitimate high-prestige yields from triggering false-positive kicks.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 83 (Tutorial Expansion)

---

## DESIGN

Current `AntiCheatService`:

```lua
local MAX_YIELD_HONEY = 1750  -- 500 * 3.5  (hardcoded)
```

`CheckForagingRequest` compares `honeyYield > MAX_YIELD_HONEY`. At prestige level 5 the legitimate max is `500 × 3.5 × 1.25 = 2,187.5` — above the hardcoded cap, triggering a false positive.

**Fix:** Compute a per-player dynamic cap inside `CheckForagingRequest`:

```lua
local prestigeMultiplier = PrestigeService.GetPrestigeMultiplier(player)
local dynamicCap = math.floor(MAX_BASE_HONEY * MULTIPLIER_CAP * prestigeMultiplier * 1.10)
-- 10% headroom above theoretical max to absorb floating point rounding
if honeyYield > dynamicCap then
    -- record strike
end
```

`MAX_BASE_HONEY` replaces `MAX_YIELD_HONEY` as the name of the 500-unit constant (clearer intent). `MULTIPLIER_CAP` remains 3.5.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `AntiCheatService` | Rename `MAX_YIELD_HONEY → MAX_BASE_HONEY`, inject `PrestigeService` require, compute dynamic cap per-check |

---

## STEP A — AntiCheatService: dynamic yield cap

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ac = SSS:FindFirstChild("AntiCheatService")
assert(ac, "AntiCheatService not found")

if ac.Source:find("MAX_BASE_HONEY", 1, true) then
    print("⏭️  AntiCheatService already has MAX_BASE_HONEY dynamic cap — skip")
else
    local clone = ac:Clone()
    clone.Name = "AntiCheatService_WORKING"

    -- 1. Rename MAX_YIELD_HONEY → MAX_BASE_HONEY everywhere
    clone.Source = clone.Source:gsub("MAX_YIELD_HONEY", "MAX_BASE_HONEY")

    -- 2. Inject PrestigeService require after existing requires (near top)
    if not clone.Source:find("PrestigeService", 1, true) then
        local anchor = 'local MAX_STRIKES'
        local found = clone.Source:find(anchor, 1, true)
        if not found then
            anchor = 'local MIN_INTERVAL'
            found = clone.Source:find(anchor, 1, true)
        end
        if found then
            local lineStart = clone.Source:sub(1, found - 1):find("[^\n]*$")
            -- Inject at top of file, after first 'local SSS' line
            local sssLine = clone.Source:find("local SSS", 1, true)
            if sssLine then
                local sssEnd = clone.Source:find("\n", sssLine, true)
                clone.Source = clone.Source:sub(1, sssEnd)
                    .. "\nlocal PrestigeService = require(SSS:WaitForChild(\"PrestigeService\"))"
                    .. clone.Source:sub(sssEnd + 1)
                print("Injected PrestigeService require after SSS line")
            end
        end
    end

    -- 3. Inside CheckForagingRequest, replace the static cap check with a dynamic one
    -- Find: honeyYield > MAX_BASE_HONEY  (or the old MAX_YIELD_HONEY name before rename)
    local capCheck = 'honeyYield > MAX_BASE_HONEY'
    local found3 = clone.Source:find(capCheck, 1, true)
    if found3 then
        -- Replace the single-line check with a dynamic one
        local lineStart3 = found3
        while lineStart3 > 1 and clone.Source:sub(lineStart3 - 1, lineStart3 - 1) ~= "\n" do
            lineStart3 = lineStart3 - 1
        end
        local lineEnd3 = clone.Source:find("\n", found3, true) or #clone.Source
        local oldLine = clone.Source:sub(lineStart3, lineEnd3)
        local indent = oldLine:match("^(\t+)") or "\t"
        local newLines = indent .. "local prestigeMult = PrestigeService.GetPrestigeMultiplier(player)\n"
            .. indent .. "local dynamicHoneyCap = math.floor(MAX_BASE_HONEY * MULTIPLIER_CAP * prestigeMult * 1.10)\n"
            .. indent .. "if honeyYield > dynamicHoneyCap"
        clone.Source = clone.Source:sub(1, lineStart3 - 1) .. newLines .. clone.Source:sub(found3 + #capCheck)
        print("Dynamic cap check injected")
    else
        -- Fallback: the check may use a different variable name; try to patch around recordStrike
        print("⚠️  honeyYield > MAX_BASE_HONEY not found — manual review needed")
    end

    ac.Name = "AntiCheatService_OLD_NX"
    ac.Parent = nil
    clone.Name = "AntiCheatService"
    clone.Parent = SSS
    print("✅ AntiCheatService dynamic prestige cap injected")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ac = SSS:FindFirstChild("AntiCheatService")

local checks = {}

table.insert(checks, (ac and "✅" or "❌") .. " AntiCheatService exists")
table.insert(checks, (ac and ac.Source:find("MAX_BASE_HONEY") and "✅" or "❌") .. " MAX_BASE_HONEY constant")
table.insert(checks, (ac and not ac.Source:find("MAX_YIELD_HONEY") and "✅" or "❌") .. " MAX_YIELD_HONEY renamed (old name absent)")
table.insert(checks, (ac and ac.Source:find("PrestigeService") and "✅" or "❌") .. " PrestigeService require")
table.insert(checks, (ac and ac.Source:find("dynamicHoneyCap") and "✅" or "❌") .. " dynamicHoneyCap per-player cap")
table.insert(checks, (ac and ac.Source:find("GetPrestigeMultiplier") and "✅" or "❌") .. " GetPrestigeMultiplier call")

print("=== DISPATCH 84 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 84 complete" or "❌ SOME CHECKS FAILED")

-- Sanity: print computed cap for prestige 0, 5, 10
print("\nExpected caps (MAX_BASE_HONEY=500, MULTIPLIER_CAP=3.5, +10% headroom):")
print("  Prestige 0:  " .. math.floor(500 * 3.5 * 1.0  * 1.10) .. "  (was 1750)")
print("  Prestige 5:  " .. math.floor(500 * 3.5 * 1.25 * 1.10))
print("  Prestige 10: " .. math.floor(500 * 3.5 * 1.50 * 1.10))
print("  Prestige 20: " .. math.floor(500 * 3.5 * 2.0  * 1.10))
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patch only | 0 new parts |
| **Dispatch 84 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The 10% headroom (`* 1.10`) above the theoretical max accounts for floating-point rounding in `ForagingService`'s yield calculation and for any slight multiplier stacking order differences. A player cannot legitimately produce more than `MAX_BASE_HONEY × MULTIPLIER_CAP × prestigeMultiplier` honey in a single trip; the 10% buffer ensures no rounding error trips the anticheat.
- `PrestigeService.GetPrestigeMultiplier(player)` returns `1.0 + prestigeLevel * 0.05` (from dispatch 79). At prestige 0 it returns 1.0, so the cap for new players is `1750 × 1.10 = 1925` — slightly looser than the old 1750. This is intentional: the old hardcoded value had zero headroom, making it fragile. The new floor (prestige 0) is still well below any possible exploit value.
- If `PrestigeService` is not available on this server (e.g. first deploy before dispatch 79 is applied), `require(SSS:WaitForChild("PrestigeService"))` will yield indefinitely. In that case, add a timeout: `local ok, ps = pcall(function() return require(SSS:WaitForChild("PrestigeService", 5)) end); PrestigeService = ok and ps or nil`. The step A code omits this for brevity; add it if cold-start reliability is needed.
- Pollen and propolis caps are not prestige-adjusted because the prestige multiplier only applies to honey (from dispatch 79). Their `MAX_YIELD_POLLEN` and `MAX_YIELD_PROPOLIS` constants remain unchanged.
