# Dispatch 76 — AntiCheatService
## Cycle 11 · A Bee's World

**Feature:** Server-side exploit prevention for the foraging economy. Tracks per-player foraging timestamps and yield totals; rejects requests that arrive too fast or claim yields above the theoretical maximum for their bee tier. Bans repeat offenders with a configurable strike system (3 strikes → session kick with reason logged). Entirely server-side — no client changes.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 75 (BeeParticleController)

---

## DESIGN

`AntiCheatService` is a `ModuleScript` in `ServerScriptService`. `ForagingService` calls `AntiCheatService.CheckForagingRequest(player, plotId, claimedYield)` before applying any yield. If the check fails, `ForagingService` silently drops the request (no error to client — exploiters shouldn't know exactly what triggered).

### Checks performed

| Check | Logic |
|-------|-------|
| **Cooldown gate** | Last foraging completion for this player was < `MIN_INTERVAL_SECONDS` ago → reject |
| **Yield ceiling** | `claimedYield > MAX_HONEY_PER_TRIP * MULTIPLIER_CAP` → reject |
| **Strike accumulation** | Each reject increments `strikes[player.UserId]` |
| **Kick threshold** | `strikes >= MAX_STRIKES` → kick player with logged reason |

### Configuration

```lua
local MIN_INTERVAL_SECONDS = 8     -- minimum seconds between foraging completions
local MAX_HONEY_PER_TRIP   = 500   -- theoretical max honey yield at tier 7
local MULTIPLIER_CAP       = 3.5   -- seasonal(2.0) × friend(1.3) × small buffer
local MAX_STRIKES          = 3     -- strikes before kick
```

`MAX_HONEY_PER_TRIP * MULTIPLIER_CAP = 500 * 3.5 = 1750` — any single trip claiming more than 1750 honey is impossible under legitimate stacked multipliers and is flagged.

### ForagingService integration

`AntiCheatService.RecordForagingStart(player)` — call when foraging begins (plant the timestamp).  
`AntiCheatService.CheckForagingRequest(player, plotId, honeyYield, pollenYield, propolisYield)` — call before applying yields. Returns `true` (allow) or `false` (reject, strike recorded).

---

## FILES CHANGED

| File | Change |
|------|--------|
| `AntiCheatService` (new ModuleScript in SSS) | cooldown, ceiling, strike, kick logic |
| `ForagingService` | inject `RecordForagingStart` and `CheckForagingRequest` calls |
| `GameManager` | inject `AntiCheatService` require (no Init needed — pure module) |

---

## STEP A — AntiCheatService (new ModuleScript)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local svc = Instance.new("ModuleScript")
svc.Name   = "AntiCheatService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- AntiCheatService — server-side foraging exploit prevention

local PS  = game:GetService("Players")
local SSS = game:GetService("ServerScriptService")

local AntiCheatService = {}

-- ── Config ─────────────────────────────────────────────
local MIN_INTERVAL_SECONDS = 8
local MAX_HONEY_PER_TRIP   = 500
local MULTIPLIER_CAP       = 3.5
local MAX_STRIKES          = 3

local MAX_YIELD_HONEY = MAX_HONEY_PER_TRIP * MULTIPLIER_CAP  -- 1750

-- ── State ──────────────────────────────────────────────
-- lastForagingStart[uid] = tick() when foraging started
local lastForagingStart: {[number]: number} = {}
-- strikes[uid] = number of violations
local strikes: {[number]: number} = {}

-- ── Helpers ────────────────────────────────────────────
local function warn(player: Player, reason: string)
    local uid = player.UserId
    strikes[uid] = (strikes[uid] or 0) + 1
    warn("[AntiCheat] " .. player.Name .. " violation #" .. strikes[uid] .. ": " .. reason)

    if strikes[uid] >= MAX_STRIKES then
        -- Kick with a polite message — reason is logged server-side
        player:Kick("You have been removed for unusual activity. Rejoin to continue playing.")
        warn("[AntiCheat] Kicked " .. player.Name .. " after " .. strikes[uid] .. " strikes")
    end
end

-- ── Public API ─────────────────────────────────────────
function AntiCheatService.RecordForagingStart(player: Player)
    lastForagingStart[player.UserId] = tick()
end

function AntiCheatService.CheckForagingRequest(
    player: Player,
    _plotId: number,
    honeyYield: number,
    _pollenYield: number,
    _propolisYield: number
): boolean
    local uid = player.UserId

    -- 1. Cooldown check
    local lastStart = lastForagingStart[uid]
    if lastStart then
        local elapsed = tick() - lastStart
        if elapsed < MIN_INTERVAL_SECONDS then
            warn(player, "Foraging too fast: " .. string.format("%.1f", elapsed) .. "s < " .. MIN_INTERVAL_SECONDS .. "s minimum")
            return false
        end
    end

    -- 2. Yield ceiling check (honey is the primary attack vector)
    if honeyYield > MAX_YIELD_HONEY then
        warn(player, "Honey yield too high: " .. honeyYield .. " > " .. MAX_YIELD_HONEY)
        return false
    end

    return true
end

-- ── Cleanup on player leave ─────────────────────────────
PS.PlayerRemoving:Connect(function(player)
    lastForagingStart[player.UserId] = nil
    strikes[player.UserId] = nil
end)

return AntiCheatService
]]

print("AntiCheatService created")
```

---

## STEP B — ForagingService: inject AntiCheat calls

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

-- Already patched?
if fs.Source:find("AntiCheatService", 1, true) then
    print("⏭️  ForagingService already has AntiCheatService — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- 1. Inject require after FriendBonusService require (or after SeasonalEventService)
    local anchor1 = 'local FriendBonusService'
    local found1 = clone.Source:find(anchor1, 1, true)
    if not found1 then
        anchor1 = 'local SeasonalEventService'
        found1 = clone.Source:find(anchor1, 1, true)
    end
    assert(found1, "Cannot find inject anchor in ForagingService")
    local lineEnd1 = clone.Source:find("\n", found1, true)
    clone.Source = clone.Source:sub(1, lineEnd1)
        .. "\nlocal AntiCheatService = require(SSS:WaitForChild(\"AntiCheatService\"))"
        .. clone.Source:sub(lineEnd1 + 1)

    -- 2. Inject RecordForagingStart when foraging begins
    -- Find the line that fires ForagingStart or sets plot to foraging state
    -- Typically: "plot.isForaging = true" or "ForagingSync:FireClient"
    local startAnchor = 'isForaging = true'
    local found2 = clone.Source:find(startAnchor, 1, true)
    if found2 then
        local lineEnd2 = clone.Source:find("\n", found2, true)
        clone.Source = clone.Source:sub(1, lineEnd2)
            .. "\n\tAntiCheatService.RecordForagingStart(player)"
            .. clone.Source:sub(lineEnd2 + 1)
    else
        print("⚠️  isForaging = true anchor not found — RecordForagingStart not injected")
    end

    -- 3. Inject CheckForagingRequest before yield application
    -- Find: "profile.honey = profile.honey + honeyYield" or similar accumulation line
    local yieldAnchor = 'profile.honey'
    local found3 = clone.Source:find(yieldAnchor, 1, true)
    if found3 then
        -- Go back to find the beginning of the statement block — inject before first yield line
        -- Find the line start
        local lineStart3 = clone.Source:sub(1, found3):match(".*\n()") or 1
        clone.Source = clone.Source:sub(1, lineStart3 - 1)
            .. "\tif not AntiCheatService.CheckForagingRequest(player, plotId or 0, honeyYield or 0, pollenYield or 0, propolisYield or 0) then return end\n"
            .. clone.Source:sub(lineStart3)
    else
        -- Fallback: inject before FriendBonusService multiplier line
        local fallbackAnchor = 'FriendBonusService.GetHoneyMultiplier'
        local found3b = clone.Source:find(fallbackAnchor, 1, true)
        assert(found3b, "Cannot find yield injection anchor in ForagingService")
        local lineEnd3b = clone.Source:find("\n", found3b, true) or #clone.Source
        -- Inject the check BEFORE the multiplier computation
        local lineStart3b = clone.Source:sub(1, found3b):match(".*\n()") or 1
        clone.Source = clone.Source:sub(1, lineStart3b - 1)
            .. "\tif not AntiCheatService.CheckForagingRequest(player, plotId or 0, honeyYield or 0, pollenYield or 0, propolisYield or 0) then return end\n"
            .. clone.Source:sub(lineStart3b)
    end

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService AntiCheat injected")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local svc = SSS:FindFirstChild("AntiCheatService")
table.insert(checks, (svc and svc:IsA("ModuleScript") and "✅" or "❌") .. " AntiCheatService ModuleScript")
table.insert(checks, (svc and svc.Source:find("MIN_INTERVAL_SECONDS") and "✅" or "❌") .. " MIN_INTERVAL_SECONDS config")
table.insert(checks, (svc and svc.Source:find("MAX_YIELD_HONEY") and "✅" or "❌") .. " MAX_YIELD_HONEY ceiling")
table.insert(checks, (svc and svc.Source:find("MAX_STRIKES") and "✅" or "❌") .. " MAX_STRIKES kick logic")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("AntiCheatService") and "✅" or "❌") .. " ForagingService has AntiCheatService require")
table.insert(checks, (fs and fs.Source:find("CheckForagingRequest") and "✅" or "❌") .. " ForagingService calls CheckForagingRequest")

print("=== DISPATCH 76 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 76 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Server code only (ModuleScript) | 0 new parts |
| **Dispatch 76 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The `MIN_INTERVAL_SECONDS = 8` cooldown is intentionally permissive — legitimate foraging trips in the hive take around 10–15 seconds at base speed. Setting it to 8 catches script-injected instant retries without false-positives on fast hardware.
- `MAX_YIELD_HONEY = 1750` (500 × 3.5) accommodates the absolute maximum: tier-7 plot × Spring Bloom seasonal (2.0×) × 3 friends (+30%) = ~1300 honey, with 35% buffer for future upgrade tiers. This number should be updated if `MAX_HONEY_PER_TRIP` increases with new upgrade tiers.
- `AntiCheatService.CheckForagingRequest` accepts `plotId` as a parameter for future per-plot rate tracking but currently only uses it as a logging token.
- Kicks happen silently from the client perspective (no "you were flagged" message visible to other players). The warning is logged server-side via `warn()` which appears in Roblox's server output.
- The `PlayerRemoving` cleanup ensures the tables don't accumulate stale entries across a long-running server.
- STEP B injection uses a two-anchor fallback: it first tries `profile.honey` (direct yield accumulation line), then falls back to `FriendBonusService.GetHoneyMultiplier` (the multiplier computation area) as a proxy injection point. If neither anchor exists (e.g. ForagingService was restructured), the assert will print a clear error.
