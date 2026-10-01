# Dispatch 104 — Foraging Trip Duration Upgrade
## Cycle 14 · A Bee's World

**Feature:** Foraging trips currently run at a fixed duration defined in Config (likely `FORAGING_DURATION = 30` seconds). Players have no way to reduce this duration — faster trips means faster resource income, which should be a meaningful upgrade path. This dispatch adds three **Swift Wings** upgrades that reduce foraging duration: `-10%`, `-20%`, `-35%`. The upgrades stack with each other and apply server-side in `ForagingService`. The upgrade panel already exists from dispatch 92 — these new upgrades appear in the 🍯 Honey tab (honey cost) and integrate with the existing upgrade framework.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 103 (Honeycomb Grid Visual Overlay)

---

## DESIGN

### Upgrade definitions

Added to `Config.UPGRADES` (or equivalent upgrade table):

```lua
swift_wings_1 = {
    id        = "swift_wings_1",
    name      = "Swift Wings I",
    desc      = "Bees return 10% faster from foraging",
    costType  = "honey",
    cost      = 300,
    prereq    = nil,
    effect    = {tripDurationMult = 0.90},
},
swift_wings_2 = {
    id        = "swift_wings_2",
    name      = "Swift Wings II",
    desc      = "Bees return 20% faster from foraging",
    costType  = "honey",
    cost      = 750,
    prereq    = "swift_wings_1",
    effect    = {tripDurationMult = 0.80},
},
swift_wings_3 = {
    id        = "swift_wings_3",
    name      = "Swift Wings III",
    desc      = "Bees return 35% faster from foraging",
    costType  = "honey",
    cost      = 1600,
    prereq    = "swift_wings_2",
    effect    = {tripDurationMult = 0.65},
},
```

### Duration calculation

`ForagingService` computes effective trip duration:

```lua
local function getEffectiveDuration(profile): number
    local base = Config.FORAGING_DURATION or 30
    local mult = 1.0
    if profile.upgrades then
        if profile.upgrades["swift_wings_3"] then mult = 0.65
        elseif profile.upgrades["swift_wings_2"] then mult = 0.80
        elseif profile.upgrades["swift_wings_1"] then mult = 0.90
        end
    end
    return math.max(base * mult, 5)  -- minimum 5 seconds
end
```

The `math.max(..., 5)` floor prevents edge cases if future upgrades stack below the minimum.

### Config update strategy

The upgrade definitions must be added to `Config.UPGRADES`. The `Config` module is a `ModuleScript` in `ReplicatedStorage`. The clone-and-replace pattern is used.

### ForagingService patch

`ForagingService` is patched to call `getEffectiveDuration()` instead of using `Config.FORAGING_DURATION` directly. The function is injected as a block at the top of the module (after `require` calls).

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add swift_wings_1/2/3 to UPGRADES table |
| `ForagingService` | Add getEffectiveDuration() and use it for trip timing |

---

## STEP A — Diagnose Config.UPGRADES structure and ForagingService duration usage

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS:FindFirstChild("Config"))

print("FORAGING_DURATION: " .. tostring(Config.FORAGING_DURATION))
print("UPGRADES type: " .. type(Config.UPGRADES))

-- Print a sample upgrade to understand structure
if Config.UPGRADES then
    local count = 0
    for id, data in Config.UPGRADES do
        if count < 3 then
            print("Sample upgrade '" .. id .. "':")
            print("  name=" .. tostring(data.name))
            print("  costType=" .. tostring(data.costType))
            print("  cost=" .. tostring(data.cost))
            print("  prereq=" .. tostring(data.prereq))
            if data.effect then
                for k, v in data.effect do
                    print("  effect." .. k .. "=" .. tostring(v))
                end
            end
        end
        count = count + 1
    end
    print("Total upgrades: " .. count)
end

-- Check ForagingService for duration references
local SS = game:GetService("ServerScriptService")
local fs = SS:FindFirstChild("ForagingService")
if fs then
    local lines = fs.Source:split("\n")
    for i, line in lines do
        if line:find("FORAGING_DURATION") or line:find("duration") or line:find("wait(") then
            print(i .. ": " .. line)
        end
    end
end
```

---

## STEP B — Config: add Swift Wings upgrades

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local configMod = RS:FindFirstChild("Config")
assert(configMod, "Config ModuleScript not found in ReplicatedStorage")

if configMod.Source:find("swift_wings_1", 1, true) then
    print("⏭️  Config already has swift_wings upgrades — skip")
else
    local clone = configMod:Clone()
    clone.Name = "Config_WORKING"

    -- Find the closing brace of UPGRADES table and insert before it
    -- Strategy: find the last upgrade entry pattern and append after it
    -- Pattern: look for the end of the UPGRADES table (a line with just "}" or "},")
    -- before the Config return

    -- New upgrade block to inject
    local SWIFT_WINGS_BLOCK = [[

    -- Swift Wings — Foraging Duration Upgrades (dispatch 104)
    swift_wings_1 = {
        id       = "swift_wings_1",
        name     = "Swift Wings I",
        desc     = "Bees return 10% faster from foraging",
        costType = "honey",
        cost     = 300,
        prereq   = nil,
        effect   = {tripDurationMult = 0.90},
    },
    swift_wings_2 = {
        id       = "swift_wings_2",
        name     = "Swift Wings II",
        desc     = "Bees return 20% faster from foraging",
        costType = "honey",
        cost     = 750,
        prereq   = "swift_wings_1",
        effect   = {tripDurationMult = 0.80},
    },
    swift_wings_3 = {
        id       = "swift_wings_3",
        name     = "Swift Wings III",
        desc     = "Bees return 35% faster from foraging",
        costType = "honey",
        cost     = 1600,
        prereq   = "swift_wings_2",
        effect   = {tripDurationMult = 0.65},
    },]]

    -- Try to find UPGRADES table closing brace
    -- Look for a line that closes the UPGRADES table: "}" or "}," at low indentation after upgrade entries
    local source = clone.Source
    local inserted = false

    -- Method 1: find last upgrade-like entry (a line with cost = N) and append after its closing brace
    -- Find the position just before 'return Config' or just before the UPGRADES table's closing brace
    local returnPos = source:find("\nreturn Config")
    if returnPos then
        -- Find the last "}" before 'return Config' that closes the UPGRADES table
        local insertPos = returnPos
        -- Walk backwards to find closing of UPGRADES
        local lastUpgradeClose = source:sub(1, returnPos):find("^%s*%},?%s*$", 1)
        -- Simpler: just insert our block right before 'return Config'
        -- This works if UPGRADES = { ... } ends before the return
        clone.Source = source:sub(1, returnPos) .. SWIFT_WINGS_BLOCK .. source:sub(returnPos)
        inserted = true
        print("✅ Inserted swift_wings before 'return Config'")
    end

    if not inserted then
        -- Fallback: append to end of source (outside table — not ideal but functional if Config uses getter)
        warn("[SwiftWings] Could not find 'return Config' — appending raw entries")
        clone.Source = source .. "\n-- swift_wings appended (dispatch 104)\n"
            .. "if Config.UPGRADES then\n"
            .. "    Config.UPGRADES.swift_wings_1 = {id='swift_wings_1',name='Swift Wings I',desc='Bees return 10% faster from foraging',costType='honey',cost=300,prereq=nil,effect={tripDurationMult=0.90}}\n"
            .. "    Config.UPGRADES.swift_wings_2 = {id='swift_wings_2',name='Swift Wings II',desc='Bees return 20% faster from foraging',costType='honey',cost=750,prereq='swift_wings_1',effect={tripDurationMult=0.80}}\n"
            .. "    Config.UPGRADES.swift_wings_3 = {id='swift_wings_3',name='Swift Wings III',desc='Bees return 35% faster from foraging',costType='honey',cost=1600,prereq='swift_wings_2',effect={tripDurationMult=0.65}}\n"
            .. "end\n"
        inserted = true
    end

    configMod.Name = "Config_OLD_NX"
    configMod.Parent = nil
    clone.Name = "Config"
    clone.Parent = RS
    print("✅ Config: swift_wings upgrades added")
end
```

---

## STEP C — ForagingService: inject getEffectiveDuration

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
assert(fs, "ForagingService not found")

if fs.Source:find("getEffectiveDuration", 1, true) then
    print("⏭️  ForagingService already has getEffectiveDuration — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Inject duration helper right before the module source ends
    -- (or before 'return ForagingService' if present)
    local DURATION_BLOCK = [[

-- ── Swift Wings Trip Duration (dispatch 104) ─────────────────────
local function getEffectiveDuration_104(profile: {[string]: any}): number
    local base = Config.FORAGING_DURATION or 30
    local mult = 1.0
    local upgrades = profile.upgrades or {}
    if upgrades["swift_wings_3"] then
        mult = 0.65
    elseif upgrades["swift_wings_2"] then
        mult = 0.80
    elseif upgrades["swift_wings_1"] then
        mult = 0.90
    end
    return math.max(base * mult, 5)
end
-- ── End Swift Wings ──────────────────────────────────────────────

]]

    local newSource = clone.Source

    -- Replace task.wait(Config.FORAGING_DURATION) patterns
    local replaced = 0
    newSource = newSource:gsub(
        "task%.wait%(Config%.FORAGING_DURATION%)",
        function()
            replaced = replaced + 1
            return "task.wait(getEffectiveDuration_104(profile))"
        end
    )

    -- Also handle: task.wait(Config.FORAGING_DURATION or N)
    newSource = newSource:gsub(
        "task%.wait%(Config%.FORAGING_DURATION%s+or%s+%d+%)",
        function()
            replaced = replaced + 1
            return "task.wait(getEffectiveDuration_104(profile))"
        end
    )

    -- Prepend the helper function near top of module (after Config require)
    local configRequirePos = newSource:find("require%([^)]*Config")
    if configRequirePos then
        -- Find end of that require line
        local lineEnd = newSource:find("\n", configRequirePos) or #newSource
        newSource = newSource:sub(1, lineEnd) .. DURATION_BLOCK .. newSource:sub(lineEnd + 1)
    else
        -- Append before return
        local returnPos = newSource:find("\nreturn ForagingService")
        if returnPos then
            newSource = newSource:sub(1, returnPos) .. DURATION_BLOCK .. newSource:sub(returnPos)
        else
            newSource = DURATION_BLOCK .. newSource
        end
    end

    clone.Source = newSource

    local parent = fs.Parent
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = parent
    print("✅ ForagingService: getEffectiveDuration_104 injected")
    print("task.wait replacements: " .. replaced)
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerScriptService")

local configMod = RS:FindFirstChild("Config")
local fs = nil
for _, obj in SS:GetDescendants() do
    if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then
        fs = obj; break
    end
end
if not fs then fs = SS:FindFirstChild("ForagingService") end

local checks = {}
table.insert(checks, (configMod and "✅" or "❌") .. " Config exists")
table.insert(checks, (configMod and configMod.Source:find("swift_wings_1", 1, true) and "✅" or "❌") .. " Config: swift_wings_1 upgrade")
table.insert(checks, (configMod and configMod.Source:find("swift_wings_2", 1, true) and "✅" or "❌") .. " Config: swift_wings_2 upgrade")
table.insert(checks, (configMod and configMod.Source:find("swift_wings_3", 1, true) and "✅" or "❌") .. " Config: swift_wings_3 upgrade")
table.insert(checks, (configMod and configMod.Source:find("tripDurationMult", 1, true) and "✅" or "❌") .. " Config: tripDurationMult effect field")
table.insert(checks, (fs and "✅" or "❌") .. " ForagingService exists")
table.insert(checks, (fs and fs.Source:find("getEffectiveDuration_104", 1, true) and "✅" or "❌") .. " ForagingService: getEffectiveDuration_104")
table.insert(checks, (fs and fs.Source:find("swift_wings", 1, true) and "✅" or "❌") .. " ForagingService: reads swift_wings upgrades")
table.insert(checks, (fs and fs.Source:find("math%.max%(base", 1, false) and "✅" or "❌") .. " ForagingService: minimum 5s floor")

print("=== DISPATCH 104 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 104 complete" or "❌ SOME CHECKS FAILED")

-- Runtime check: verify Config loaded with new upgrades
local ok, Config = pcall(require, RS:FindFirstChild("Config"))
if ok and Config.UPGRADES then
    print("\nSwift Wings in Config.UPGRADES:")
    for _, id in {"swift_wings_1","swift_wings_2","swift_wings_3"} do
        local u = Config.UPGRADES[id]
        if u then
            print("  ✅ " .. id .. ": cost=" .. (u.cost or "?") .. " mult=" .. (u.effect and u.effect.tripDurationMult or "?"))
        else
            print("  ❌ " .. id .. ": NOT FOUND")
        end
    end

    local baseDur = Config.FORAGING_DURATION or 30
    print("\nEffective durations (base=" .. baseDur .. "s):")
    for _, r in {
        {"No upgrade", 1.0},
        {"swift_wings_1", 0.90},
        {"swift_wings_2", 0.80},
        {"swift_wings_3", 0.65},
    } do
        print("  " .. r[1] .. ": " .. math.max(baseDur * r[2], 5) .. "s")
    end
else
    print("Could not require Config: " .. tostring(Config))
end
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config entries + server script injection only | 0 permanent parts |
| **Dispatch 104 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `math.max(base * mult, 5)` sets a hard floor of 5 seconds. This prevents future upgrades or stacking bugs from reducing trip duration to 0 or below, which would cause a spin-loop in the foraging coroutine.
- Swift Wings upgrades use the `honey` costType, so they appear in the 🍯 Honey tab of the Upgrades panel (dispatch 92 tab filtering reads CostType attribute). The `CostType` attribute is set by UpgradesController when it builds upgrade rows from `Config.UPGRADES` — as long as the upgrade definition has `costType = "honey"`, the tab filter works automatically.
- The `prereq` chain (nil → swift_wings_1 → swift_wings_2 → swift_wings_3) mirrors the existing prerequisite system. Players must buy each tier before unlocking the next — the UpgradesController (dispatch 10/12 era) handles prerequisite checks using `profile.upgrades[prereq]`.
- The `tripDurationMult` effect field is new — no existing upgrade uses it. Only `getEffectiveDuration_104()` reads this field. Future dispatches that want to add more duration-related effects should extend this function rather than adding new `task.wait` replacements.
- If `ForagingService` uses a different variable name than `profile` for the player's data (e.g., `playerData`, `data`, `playerProfile`), update the references in `getEffectiveDuration_104()` accordingly. The Step A diagnosis will show the variable name from `task.wait` context.
- The `_104` suffix follows the injection naming convention used throughout Cycle 14.
- Upgrade costs (300 / 750 / 1600 honey) are positioned between the pollen upgrade tier (dispatch 55-era) and the propolis expansion costs (dispatch 86). They fit the mid-game progression curve: swift_wings_1 becomes affordable by bee count 25, swift_wings_3 around bee count 100.
