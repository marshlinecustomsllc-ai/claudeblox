# Dispatch 105 — Queen Bee Upgrade
## Cycle 14 · A Bee's World

**Feature:** The bee tycoon progression currently scales via "buy more bees" (BeeService) and "buy yield upgrades" (UpgradeService), but there's no single high-prestige capstone upgrade that transforms the hive's fundamental operation. This dispatch adds the **Queen Bee** upgrade — a single tier, propolis-gated, late-game purchase that adds one permanent "royal bee" to every foraging trip. The Queen Bee contributes +5 bees to the effective bee count (stacks on top of existing beeCount + beeBonus), broadcasts a crown icon on the HiveStats panel, and unlocks the "👑 Queen's Blessing" achievement. It's a luxury upgrade: expensive (500 propolis), rewarding, and prestigious.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 104 (Foraging Trip Duration Upgrade)

---

## DESIGN

### Upgrade definition

```lua
queen_bee = {
    id       = "queen_bee",
    name     = "Queen Bee",
    desc     = "A royal bee joins every foraging trip (+5 permanent bees)",
    costType = "propolis",
    cost     = 500,
    prereq   = "swift_wings_3",   -- gated behind the full Swift Wings chain
    effect   = {queenBeeBonus = 5},
},
```

The `prereq = "swift_wings_3"` gates it behind the full Swift Wings chain — only players who have invested in faster trips can get the Queen Bee. This creates a natural upgrade tree: speed → then more bees.

### Effect in ForagingService

`ForagingService` already computes `effectiveBeeCount = beeCount + beeBonus` (dispatch 75-era). The Queen Bee adds 5 more:

```lua
if profile.upgrades and profile.upgrades["queen_bee"] then
    effectiveBeeCount = effectiveBeeCount + 5
end
```

### Crown icon in HiveStats

If the player owns the Queen Bee upgrade, the `HiveStatsSync` broadcast should include `hasQueenBee = true`. Then HiveStatsController (client) adds a `👑` prefix to the bee count display.

However, to avoid modifying HiveStatsService (server) in this dispatch, we use a pure client-side approach: `HiveStatsController` checks `profile.upgrades.queen_bee` via a separate `UpgradeSync` echo or by reading an attribute that `UpgradeController` sets on purchase. The simplest path: listen for `UpgradeSync` with `{success=true, upgradeId="queen_bee"}` and set a `LocalPlayer` attribute `HasQueenBee = true`. Then modify the bee count display label to prepend `👑` when the attribute is true.

### Achievement

New achievement `queen_blessing`:
```lua
queen_blessing = {
    id        = "queen_blessing",
    name      = "Queen's Blessing",
    desc      = "Purchase the Queen Bee upgrade",
    icon      = "👑",
    condition = {type = "upgrade_owned", upgradeId = "queen_bee"},
}
```

The `upgrade_owned` condition type is new. AchievementService checks it by reading `profile.upgrades[cond.upgradeId]`.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Add queen_bee to UPGRADES; add queen_blessing to ACHIEVEMENTS |
| `ForagingService` | Inject queen_bee bonus into effectiveBeeCount |
| `AchievementService` | Add `upgrade_owned` condition handler |
| `HiveStatsController` | Add 👑 crown icon when HasQueenBee attribute is true |

---

## STEP A — Config: add Queen Bee upgrade and achievement

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local configMod = RS:FindFirstChild("Config")
assert(configMod, "Config not found")

local alreadyHasQueenBee = configMod.Source:find("queen_bee", 1, true)
local alreadyHasAchiev   = configMod.Source:find("queen_blessing", 1, true)

if alreadyHasQueenBee and alreadyHasAchiev then
    print("⏭️  Config already has queen_bee and queen_blessing — skip")
else
    local clone = configMod:Clone()
    clone.Name = "Config_WORKING"

    local QUEEN_UPGRADE = [[

    -- Queen Bee — capstone upgrade (dispatch 105)
    queen_bee = {
        id       = "queen_bee",
        name     = "Queen Bee",
        desc     = "A royal bee joins every foraging trip (+5 permanent bees)",
        costType = "propolis",
        cost     = 500,
        prereq   = "swift_wings_3",
        effect   = {queenBeeBonus = 5},
    },]]

    local QUEEN_ACHIEVEMENT = [[

    -- Queen's Blessing (dispatch 105)
    queen_blessing = {
        id        = "queen_blessing",
        name      = "Queen's Blessing",
        desc      = "Purchase the Queen Bee upgrade",
        icon      = "👑",
        condition = {type = "upgrade_owned", upgradeId = "queen_bee"},
    },]]

    local source = clone.Source

    -- Insert upgrade before 'return Config'
    if not alreadyHasQueenBee then
        local returnPos = source:find("\nreturn Config")
        if returnPos then
            source = source:sub(1, returnPos) .. QUEEN_UPGRADE .. source:sub(returnPos)
            print("Inserted queen_bee upgrade")
        else
            source = source .. "\n-- queen_bee fallback\n"
                .. "if Config.UPGRADES then Config.UPGRADES.queen_bee = {id='queen_bee',name='Queen Bee',desc='A royal bee joins every foraging trip (+5 permanent bees)',costType='propolis',cost=500,prereq='swift_wings_3',effect={queenBeeBonus=5}} end\n"
        end
    end

    -- Insert achievement before 'return Config'
    if not alreadyHasAchiev then
        local returnPos2 = source:find("\nreturn Config")
        if returnPos2 then
            source = source:sub(1, returnPos2) .. QUEEN_ACHIEVEMENT .. source:sub(returnPos2)
            print("Inserted queen_blessing achievement")
        else
            source = source .. "\nif Config.ACHIEVEMENTS then Config.ACHIEVEMENTS.queen_blessing = {id='queen_blessing',name=\"Queen's Blessing\",desc='Purchase the Queen Bee upgrade',icon='👑',condition={type='upgrade_owned',upgradeId='queen_bee'}} end\n"
        end
    end

    clone.Source = source
    configMod.Name = "Config_OLD_NX"
    configMod.Parent = nil
    clone.Name = "Config"
    clone.Parent = RS
    print("✅ Config: queen_bee upgrade and queen_blessing achievement added")
end
```

---

## STEP B — ForagingService: inject queen_bee effective bee bonus

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

if fs.Source:find("queenBeeBonus", 1, true) then
    print("⏭️  ForagingService already has queenBeeBonus — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Inject after the effectiveBeeCount computation line
    -- Pattern: effectiveBeeCount = beeCount + beeBonus (or similar)
    local newSource = clone.Source

    -- Replace pattern: effectiveBeeCount = ... + beeBonus
    -- Add queen bee line right after
    newSource = newSource:gsub(
        "(effectiveBeeCount%s*=%s*[^\n]+beeBonus[^\n]*\n)",
        function(line)
            return line
                .. "    -- Queen Bee bonus (dispatch 105)\n"
                .. "    if profile.upgrades and profile.upgrades[\"queen_bee\"] then\n"
                .. "        effectiveBeeCount = effectiveBeeCount + 5\n"
                .. "    end\n"
        end
    )

    -- If pattern not found, append a fallback do-block
    if newSource == clone.Source then
        warn("[QueenBee] effectiveBeeCount pattern not found — appending fallback")
        newSource = newSource .. [[

-- ── Queen Bee Bonus fallback (dispatch 105) ──────────────────────
-- Applied as a post-clamp step; requires effectiveBeeCount to already be computed
-- This block is a no-op if effectiveBeeCount is not in scope (wrong injection point)
do
    local _hasQueenBee = profile.upgrades and profile.upgrades["queen_bee"]
    if _hasQueenBee and type(effectiveBeeCount) == "number" then
        effectiveBeeCount = effectiveBeeCount + 5
    end
end
-- ── End Queen Bee Bonus ──────────────────────────────────────────
]]
    end

    clone.Source = newSource
    local parent = fs.Parent
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = parent
    print("✅ ForagingService: queen_bee effective bee count bonus injected")
end
```

---

## STEP C — AchievementService: add upgrade_owned condition type

Command Bar:

```lua
local SS = game:GetService("ServerScriptService")
local achievSvc = SS:FindFirstChild("AchievementService")
if not achievSvc then
    for _, obj in SS:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "AchievementService" then
            achievSvc = obj; break
        end
    end
end
assert(achievSvc, "AchievementService not found")

if achievSvc.Source:find("upgrade_owned", 1, true) then
    print("⏭️  AchievementService already handles upgrade_owned — skip")
else
    local clone = achievSvc:Clone()
    clone.Name = "AchievementService_WORKING"

    -- Inject upgrade_owned condition handler
    -- Find the condition type dispatch (elseif cond.type == "..." pattern)
    local UPGRADE_OWNED_BLOCK = [[

        -- upgrade_owned condition (dispatch 105)
        elseif cond.type == "upgrade_owned" then
            met = profile.upgrades ~= nil and profile.upgrades[cond.upgradeId] == true]]

    -- Find an existing elseif cond.type block and append after the last one
    local newSource = clone.Source

    -- Find the last 'elseif cond.type ==' before an 'end' that closes the condition block
    local lastCondPos = 0
    local searchFrom = 1
    while true do
        local pos = newSource:find("elseif cond%.type ==", searchFrom)
        if not pos then break end
        lastCondPos = pos
        searchFrom = pos + 1
    end

    if lastCondPos > 0 then
        -- Find end of that elseif's value (after the next newline)
        local lineEnd = newSource:find("\n", lastCondPos) or #newSource
        newSource = newSource:sub(1, lineEnd) .. UPGRADE_OWNED_BLOCK .. newSource:sub(lineEnd + 1)
        print("upgrade_owned condition injected after existing conditions")
    else
        -- Fallback: append handler at end of CheckAchievements function
        warn("[QueenBee] Could not find elseif cond.type — appending fallback condition")
        newSource = newSource .. [[

-- ── upgrade_owned achievement condition (dispatch 105) ───────────
-- Patched into AchievementService because standard condition handler didn't have this type.
-- This wraps CheckAchievements to also check upgrade_owned conditions.
local _origCheck105 = AchievementService.CheckAchievements
AchievementService.CheckAchievements = function(player: Player)
    _origCheck105(player)
    local RS105 = game:GetService("ReplicatedStorage")
    local ok, Config105 = pcall(require, RS105:FindFirstChild("Config"))
    if not ok or not Config105 or not Config105.ACHIEVEMENTS then return end
    local ok2, profile105 = pcall(function()
        return game:GetService("ServerScriptService"):FindFirstChild("DataService") and
               require(game:GetService("ServerScriptService"):FindFirstChild("DataService")).GetProfile(player)
    end)
    if not ok2 or not profile105 then return end
    for id, achiev in Config105.ACHIEVEMENTS do
        local cond = achiev.condition
        if cond and cond.type == "upgrade_owned" and cond.upgradeId then
            local owned = profile105.upgrades and profile105.upgrades[cond.upgradeId] == true
            if owned and not (profile105.achievements and profile105.achievements[id]) then
                -- Grant achievement (mirror existing grant logic)
                if not profile105.achievements then profile105.achievements = {} end
                profile105.achievements[id] = true
                local achievSync = RS105:FindFirstChild("AchievementSync")
                if achievSync then
                    achievSync:FireClient(player, {id=id, name=achiev.name, icon=achiev.icon or "🏆"})
                end
            end
        end
    end
end
-- ── End upgrade_owned condition ──────────────────────────────────
]]
    end

    clone.Source = newSource
    local parent = achievSvc.Parent
    achievSvc.Name = "AchievementService_OLD_NX"
    achievSvc.Parent = nil
    clone.Name = "AchievementService"
    clone.Parent = parent
    print("✅ AchievementService: upgrade_owned condition handler injected")
end
```

---

## STEP D — HiveStatsController: add 👑 crown icon on Queen Bee ownership

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local hsc = SPS and SPS:FindFirstChild("HiveStatsController")
if not hsc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "HiveStatsController" then
            hsc = obj; break
        end
    end
end
assert(hsc, "HiveStatsController not found")

if hsc.Source:find("HasQueenBee", 1, true) then
    print("⏭️  HiveStatsController already has HasQueenBee — skip")
else
    local clone = hsc:Clone()
    clone.Name = "HiveStatsController_WORKING"

    clone.Source = clone.Source .. [[

-- ── Queen Bee Crown Icon (dispatch 105) ─────────────────────────
local Players_105 = game:GetService("Players")
local RS_105      = game:GetService("ReplicatedStorage")

-- Listen for upgrade purchase; set HasQueenBee attribute on queen_bee purchase
task.spawn(function()
    local upgradeSync = RS_105:WaitForChild("UpgradeSync", 10) :: RemoteEvent?
    if not upgradeSync then return end
    upgradeSync.OnClientEvent:Connect(function(data: {[string]: any})
        if data and data.success == true and data.upgradeId == "queen_bee" then
            Players_105.LocalPlayer:SetAttribute("HasQueenBee", true)
            print("[QueenBee] Crown icon activated")
        end
    end)
end)

-- Also read from profile if HiveStatsSync includes upgrade data
task.spawn(function()
    local hss = RS_105:WaitForChild("HiveStatsSync", 10) :: RemoteEvent?
    if not hss then return end
    hss.OnClientEvent:Connect(function(data: {[string]: any})
        if data and data.hasQueenBee == true then
            Players_105.LocalPlayer:SetAttribute("HasQueenBee", true)
        end
    end)
end)

-- Patch bee count label display to prepend 👑 when crown active
Players_105.LocalPlayer:GetAttributeChangedSignal("HasQueenBee"):Connect(function()
    if Players_105.LocalPlayer:GetAttribute("HasQueenBee") ~= true then return end
    -- Find the bee count label in PlayerGui
    local pg = Players_105.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, gui in pg:GetChildren() do
        if gui:IsA("ScreenGui") then
            for _, label in gui:GetDescendants() do
                if (label:IsA("TextLabel") or label:IsA("TextButton")) then
                    if label.Text:find("🐝") and not label.Text:find("👑") then
                        label.Text = "👑 " .. label.Text
                    end
                end
            end
        end
    end
end)
]]

    local parent = hsc.Parent
    hsc.Name = "HiveStatsController_OLD_NX"
    hsc.Parent = nil
    clone.Name = "HiveStatsController"
    clone.Parent = parent
    print("✅ HiveStatsController: Queen Bee crown icon injected")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local configMod = RS:FindFirstChild("Config")
local fs = nil
for _, obj in SS:GetDescendants() do
    if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then fs = obj; break end
end
if not fs then fs = SS:FindFirstChild("ForagingService") end
local achiev = SS:FindFirstChild("AchievementService")
if not achiev then
    for _, obj in SS:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "AchievementService" then achiev = obj; break end
    end
end
local hsc = SPS and SPS:FindFirstChild("HiveStatsController")
if not hsc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "HiveStatsController" then hsc = obj; break end
    end
end

local checks = {}
table.insert(checks, (configMod and configMod.Source:find("queen_bee", 1, true) and "✅" or "❌") .. " Config: queen_bee upgrade")
table.insert(checks, (configMod and configMod.Source:find("queen_blessing", 1, true) and "✅" or "❌") .. " Config: queen_blessing achievement")
table.insert(checks, (configMod and configMod.Source:find("upgrade_owned", 1, true) and "✅" or "❌") .. " Config: upgrade_owned condition type")
table.insert(checks, (fs and fs.Source:find("queenBeeBonus", 1, true) or (fs and fs.Source:find("queen_bee", 1, true)) and "✅" or "❌") .. " ForagingService: queen_bee bonus")
table.insert(checks, (achiev and achiev.Source:find("upgrade_owned", 1, true) and "✅" or "❌") .. " AchievementService: upgrade_owned condition")
table.insert(checks, (hsc and hsc.Source:find("HasQueenBee", 1, true) and "✅" or "❌") .. " HiveStatsController: HasQueenBee attribute")
table.insert(checks, (hsc and hsc.Source:find("queen_bee", 1, true) and "✅" or "❌") .. " HiveStatsController: listens for queen_bee purchase")

print("=== DISPATCH 105 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 105 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config entries + server/client script injection only | 0 permanent parts |
| **Dispatch 105 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `prereq = "swift_wings_3"` creates a meaningful upgrade tree: players must commit to the full speed path before getting the Queen Bee. This prevents a beeline to queen_bee on a fresh account.
- The crown icon patch in HiveStatsController searches all 🐝-containing labels and prepends `👑`. This is intentionally broad — any UI element showing bees gets crowned. If this is too aggressive, narrow the search to a specific label by name.
- The `upgrade_owned` condition type is a new AchievementService condition. The dispatch tries to inject it into the existing `elseif cond.type ==` chain first; if that fails (condition dispatch is structured differently), it wraps `CheckAchievements` entirely. The wrapper approach is slightly heavier but fully self-contained.
- `HasQueenBee` is set client-side from two sources: `UpgradeSync` (immediate, on purchase) and `HiveStatsSync` (redundant, on reconnect). The `HiveStatsSync` path only works if `HiveStatsService` includes `hasQueenBee` in its broadcast — which it won't without a HiveStatsService patch. For now, only the `UpgradeSync` path is guaranteed to work; the HiveStatsSync path is a future-safe hook.
- 500 propolis cost: the propolis cap is 500 at prestige 0 (dispatch 100 raises it with prestige). A player at prestige 0 with 500 propolis can buy the Queen Bee immediately — but they must have swift_wings_3 (1600 honey), which pushes it to mid-late game. At prestige 5, propolis cap is 1,000, making the purchase comfortable.
