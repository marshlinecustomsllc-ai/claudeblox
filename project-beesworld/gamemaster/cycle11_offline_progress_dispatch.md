# CYCLE 11 — OFFLINE PROGRESS DISPATCH (dispatch 27)
## OfflineProgressService — Honey accumulation while offline

**Agent:** luau-scripter  
**Prerequisites:** dispatch 25 (AchievementService — DS v15→v16 baseline), dispatch 14 (ForagingService routes exist in profile)  
**Part budget impact:** 0 new world parts → **~4,094 / 5,000** total (unchanged)

---

## OVERVIEW

When a player rejoins after being offline ≥2 minutes, they receive a portion of the honey their bees would have produced while away — capped at 4 hours of production. This is shown as a small toast notification ("Welcome back! Your bees collected X honey while you were away."). Entirely server-side except for the Notify remote already wired to the client.

**Design constraints:**
- Cap at 4 hours (14,400 seconds) — prevents abuse if someone leaves forever
- Minimum offline 2 minutes (120 seconds) before granting anything — avoids trivial reconnect spam
- Rate calculation: use the player's most recent `lastRates` data (stored in profile), or fall back to a conservative default (50 honey/minute for a basic hive)
- Do NOT retroactively give resources for routes that may have been blocked by weather, wasp alerts, etc. — flat rate calculation only
- Fire the Notify remote immediately after DataService.Load, before CharacterAdded

---

## STEP A — DataService v16→v17

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP A: DataService v16->v17 (lastOnlineTime field + migration[12])
-- Uses the clone-and-replace pattern to bust Luau require() cache

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
assert(Systems, "Systems folder not found")

local dsOld = Systems:FindFirstChild("DataService")
assert(dsOld and dsOld:IsA("ModuleScript"), "DataService ModuleScript not found")

-- Step 1: clone, replace
local dsClone = dsOld:Clone()
local src = dsOld.Source

-- Step 2: Update CURRENT_VERSION 16 -> 17
src = src:gsub("CURRENT_VERSION%s*=%s*16", "CURRENT_VERSION = 17")

-- Step 3: Add lastOnlineTime to PROFILE_TEMPLATE (after achievementsUnlocked line)
src = src:gsub(
    "(achievementsUnlocked%s*=%s*{}[^,\n]*,?%s*\n)",
    "%1\t\tlastOnlineTime = 0,\n"
)

-- Step 4: Add migration[12] (after migration[11] block)
-- Find the migration[11] closing brace and append migration[12] after it
local migration12 = [[
    [12] = function(profile)
        profile.lastOnlineTime = profile.lastOnlineTime or 0
    end,
]]
-- Insert after the last migration entry line (find migration[11] end)
src = src:gsub(
    "(%[11%]%s*=%s*function%(profile%).-end,%s*\n)",
    "%1" .. migration12
)

-- Step 5: Add lastOnlineTime save hook in PlayerRemoving/SaveProfile
-- (record current time when player leaves)
-- Find the SaveProfile function or PlayerRemoving and add the timestamp
src = src:gsub(
    "(function SaveProfile%(player%s*,?%s*profile%))",
    "%1\n\tprofile.lastOnlineTime = os.time()"
)

-- Sanity checks
assert(src:find("CURRENT_VERSION = 17"), "Version bump failed")
assert(src:find("lastOnlineTime"), "lastOnlineTime field missing")
assert(src:find("%[12%]"), "migration[12] missing")

-- Step 6: apply
dsOld.Name = "DataService_OLD_v16"
dsClone.Source = src
dsClone.Name = "DataService"
dsClone.Parent = Systems

-- Clean up
dsOld.Parent = nil

print("STEP A DONE: DataService v16->v17 applied")
print("  CURRENT_VERSION=17, lastOnlineTime field, migration[12]")
print("  SaveProfile now stamps profile.lastOnlineTime = os.time() on each save")
```

**Verify Step A:**

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS.Systems:FindFirstChild("DataService")
assert(ds, "DataService not found")
local src = ds.Source
print("Version 17:", src:find("CURRENT_VERSION = 17") ~= nil)
print("lastOnlineTime:", src:find("lastOnlineTime") ~= nil)
print("migration[12]:", src:find("%[12%]") ~= nil)
print("SaveProfile stamp:", src:find("os%.time%(%)") ~= nil)
```

---

## STEP B — OfflineProgressService ModuleScript

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP B: Create OfflineProgressService ModuleScript
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
assert(Systems, "Systems folder not found")

local old = Systems:FindFirstChild("OfflineProgressService")
if old then old:Destroy() end

local mod = Instance.new("ModuleScript")
mod.Name   = "OfflineProgressService"
mod.Parent = Systems

mod.Source = [[
--!strict
--[[
    OfflineProgressService
    Calculates honey accumulated while a player was offline and applies it on rejoin.
    Called by DataService immediately after profile is loaded (before CharacterAdded).
--]]

local OfflineProgressService = {}

local OFFLINE_MIN_SECONDS = 120      -- must be offline at least 2 min to receive anything
local OFFLINE_MAX_SECONDS = 14400    -- cap at 4 hours (14,400 seconds)
local DEFAULT_HONEY_PER_SECOND = 0.833 -- ~50 honey/min fallback for a basic hive

-- Estimate honey/second from stored profile rates (if available)
-- ForagingService stores lastRates = { honeyPerSecond = N } in profile
local function estimateHoneyRate(profile: {[string]: any}): number
    local stored = profile.lastRates
    if stored and type(stored) == "table" then
        local hps = stored.honeyPerSecond
        if type(hps) == "number" and hps > 0 then
            return math.min(hps, 50) -- cap at 50/s to prevent exploited rates
        end
    end
    return DEFAULT_HONEY_PER_SECOND
end

-- Main entry point — call from DataService after profile loaded
function OfflineProgressService.ApplyOfflineProgress(
    player: Player,
    profile: {[string]: any}
): number
    local lastOnline = profile.lastOnlineTime
    if type(lastOnline) ~= "number" or lastOnline <= 0 then
        return 0
    end

    local now     = os.time()
    local elapsed = now - lastOnline

    if elapsed < OFFLINE_MIN_SECONDS then
        return 0
    end

    local effectiveSeconds = math.min(elapsed, OFFLINE_MAX_SECONDS)
    local rate             = estimateHoneyRate(profile)
    local offlineHoney     = math.floor(effectiveSeconds * rate)

    if offlineHoney <= 0 then
        return 0
    end

    profile.honey = (profile.honey or 0) + offlineHoney

    return offlineHoney
end

return OfflineProgressService
]]

print("STEP B DONE: OfflineProgressService ModuleScript created in Systems")
```

---

## STEP C — Wire OfflineProgressService into DataService load path

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP C: Add OfflineProgressService call in DataService's PlayerAdded/load handler
-- and fire Notify remote with welcome-back message

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
local ds = Systems:FindFirstChild("DataService")
assert(ds and ds:IsA("ModuleScript"), "DataService not found")

-- Clone-and-replace to bust require() cache
local dsOld = ds
local dsClone = dsOld:Clone()
local src = dsOld.Source

-- Add require at top of module (after existing requires)
-- Find the last local X = require(...) line at the top and insert after it
local offlineRequire = [[
local OfflineProgressService = require(script.Parent.OfflineProgressService)
]]

-- Insert after the block of requires at the top (find a good anchor)
-- Anchor on "local DataService = {}" which is always present
src = src:gsub(
    "(local DataService%s*=%s*%{%})",
    offlineRequire .. "%1"
)

-- In the PlayerAdded or profile-load success path, after profile is loaded:
-- Find the pattern where we fire the initial WalletUpdate/HudDataSync to client
-- and insert the offline progress call just before that fire
local offlineCall = [[
        -- Offline progress
        local offlineHoney = OfflineProgressService.ApplyOfflineProgress(player, profile)
        if offlineHoney > 0 then
            local notifyRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
            notifyRemote = notifyRemote and notifyRemote:FindFirstChild("Notify")
            if notifyRemote then
                local minutes = math.floor(offlineHoney / 60)
                local label = minutes >= 1
                    and ("Welcome back! Your bees collected " .. offlineHoney .. " honey while you were away (" .. minutes .. "m).")
                    or  ("Welcome back! Your bees collected " .. offlineHoney .. " honey while you were away.")
                notifyRemote:FireClient(player, label, "success")
            end
        end
]]

-- Anchor: find the SaveProfile call inside load success and insert before initial wallet fire
-- We'll insert just before the first FireClient call in the load handler
-- This is a conservative anchor: find "profile.honey" assignment in load and add after it
src = src:gsub(
    "(profile%.honey%s*=%s*profile%.honey%s*or%s*0.-\n)",
    "%1" .. offlineCall
)

-- Sanity
assert(src:find("OfflineProgressService"), "OfflineProgressService require missing")
assert(src:find("ApplyOfflineProgress"), "ApplyOfflineProgress call missing")
assert(src:find("Welcome back"), "Welcome back message missing")

dsOld.Name = "DataService_OLD_v17_pre_offline"
dsClone.Source = src
dsClone.Name   = "DataService"
dsClone.Parent = Systems
dsOld.Parent   = nil

print("STEP C DONE: DataService now calls OfflineProgressService on player load")
print("  Offline honey fires Notify remote with 'Welcome back!' message")
```

> **Note:** Steps B and C use regex anchors that assume standard DataService formatting from this dispatch series. If the regex substitutions fail (check that the printed "DONE" messages appear and the asserts pass), apply the changes manually:
> 1. Add `local OfflineProgressService = require(script.Parent.OfflineProgressService)` near the top of DataService
> 2. After the profile is loaded (in the PlayerAdded success path), add:
>    ```lua
>    local offlineHoney = OfflineProgressService.ApplyOfflineProgress(player, profile)
>    if offlineHoney > 0 then
>        local notifyR = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
>        if notifyR then
>            notifyR:FireClient(player, "Welcome back! Your bees collected " .. offlineHoney .. " honey.", "success")
>        end
>    end
>    ```

---

## STEP D — (Optional) Wire lastRates storage in ForagingService

If ForagingService tracks per-tick honey production rates in a local variable (e.g. `lastRates`), add a profile update so the offline calculator uses the player's actual rate rather than the default 50/min.

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP D (OPTIONAL): Store current foraging rate in profile.lastRates
-- Find ForagingService and add a profile update when rates change

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
local fs = Systems:FindFirstChild("ForagingService")
if not fs or not fs:IsA("ModuleScript") then
    print("STEP D SKIP: ForagingService not found (rates will use default 50/min)")
    return
end

local src = fs.Source

-- If ForagingService calculates honeyPerSecond anywhere, add a profile update
-- This is optional — the fallback default is reasonable for a basic hive
if not src:find("honeyPerSecond") then
    print("STEP D SKIP: ForagingService has no honeyPerSecond variable (default rate used)")
    return
end

-- Add profile.lastRates update where honeyPerSecond is computed
local ratesUpdate = [[
            -- Store current rate for offline progress calculation
            DataService.GetProfile(player, function(profile)
                if profile then
                    profile.lastRates = { honeyPerSecond = honeyPerSecond }
                end
            end)
]]

-- This anchor will only match if ForagingService has the variable
local fsOld = fs
local fsClone = fsOld:Clone()
src = src:gsub(
    "(local honeyPerSecond%s*=%s*[^\n]+\n)",
    "%1" .. ratesUpdate
)

if src:find("profile%.lastRates") then
    fsOld.Name   = "ForagingService_OLD_pre_lastRates"
    fsClone.Source = src
    fsClone.Name   = "ForagingService"
    fsClone.Parent = Systems
    fsOld.Parent   = nil
    print("STEP D DONE: ForagingService now updates profile.lastRates on each rate recalculation")
else
    fsClone:Destroy()
    print("STEP D SKIP: Anchor not matched — manual edit needed or use default rate")
end
```

---

## STEP E — Verification

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP E: Verify OfflineProgressService
local SSS     = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")

local results = {}
local issues  = {}

-- 1. DataService version
local ds = Systems:FindFirstChild("DataService")
if ds and ds:IsA("ModuleScript") then
    local src = ds.Source
    if src:find("CURRENT_VERSION = 17") then
        table.insert(results, "PASS: DataService CURRENT_VERSION=17")
    else
        table.insert(issues, "FAIL: DataService version not 17")
    end
    if src:find("lastOnlineTime") then
        table.insert(results, "PASS: lastOnlineTime field present in DataService")
    else
        table.insert(issues, "FAIL: lastOnlineTime missing from DataService")
    end
    if src:find("%[12%]") then
        table.insert(results, "PASS: migration[12] present")
    else
        table.insert(issues, "FAIL: migration[12] missing")
    end
    if src:find("OfflineProgressService") then
        table.insert(results, "PASS: OfflineProgressService wired into DataService")
    else
        table.insert(issues, "FAIL: OfflineProgressService not wired into DataService")
    end
else
    table.insert(issues, "FAIL: DataService ModuleScript not found")
end

-- 2. OfflineProgressService
local ops = Systems:FindFirstChild("OfflineProgressService")
if ops and ops:IsA("ModuleScript") then
    local src   = ops.Source
    local lines = select(2, src:gsub("\n","\n")) + 1
    local checks = {
        hasStrict     = src:find("--!strict") ~= nil,
        hasApply      = src:find("ApplyOfflineProgress") ~= nil,
        hasCap        = src:find("OFFLINE_MAX_SECONDS") ~= nil,
        hasMinimum    = src:find("OFFLINE_MIN_SECONDS") ~= nil,
        hasReturn     = src:find("return OfflineProgressService") ~= nil,
    }
    local fails = {}
    for k, v in checks do if not v then table.insert(fails, k) end end
    if #fails == 0 then
        table.insert(results, "PASS: OfflineProgressService ModuleScript (" .. lines .. " lines, all features present)")
    else
        table.insert(issues, "FAIL: OfflineProgressService missing: " .. table.concat(fails, ", "))
    end
else
    table.insert(issues, "FAIL: OfflineProgressService ModuleScript not found in Systems")
end

-- 3. No duplicate DataService
local dsCount = 0
for _, child in Systems:GetChildren() do
    if child.Name == "DataService" then dsCount = dsCount + 1 end
end
if dsCount == 1 then
    table.insert(results, "PASS: exactly 1 DataService in Systems")
else
    table.insert(issues, "FAIL: " .. dsCount .. " DataService instances found in Systems (expected 1)")
end

-- Summary
print("=== OFFLINE PROGRESS VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\n--- ISSUES ---")
    for _, iss in issues do print(iss) end
    print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
    print("\nSTATUS: ALL CHECKS PASS — offline progress system ready")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| DataService v16→v17 | ModuleScript update | ServerScriptService.Systems |
| OfflineProgressService | ModuleScript | ServerScriptService.Systems |
| DataService load hook | Source edit | DataService (inline) |

**DataService changes:**
- `profile.lastOnlineTime` (number) — stamped with `os.time()` on every `SaveProfile` call
- migration[12]: `profile.lastOnlineTime = profile.lastOnlineTime or 0`
- CURRENT_VERSION: 16 → 17
- Load path: calls `OfflineProgressService.ApplyOfflineProgress` after profile load, fires Notify "Welcome back!" toast if honey granted

**OfflineProgressService logic:**
- Minimum offline: 120 seconds (2 minutes) — ignores trivial reconnects
- Maximum offline: 14,400 seconds (4 hours) — caps farming exploit
- Rate: reads `profile.lastRates.honeyPerSecond` if stored; falls back to 0.833 honey/second (~50/min for a basic hive)
- Rate cap: 50 honey/second maximum (prevents exploited rate values from granting infinite honey)
- Result: `math.floor(effectiveSeconds * rate)` added directly to `profile.honey`

**Part budget:** 0 new world parts → **~4,094 / 5,000** total (unchanged)
