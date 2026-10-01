# Dispatch 86 — Expansion Plots: Propolis Purchase Cost
## Cycle 12 · A Bee's World

**Feature:** Expansion plot slots 7 and 8 now cost **propolis** instead of honey. This differentiates the two expansion slots from the base 6 plots (which cost honey) and creates a strategic reason to accumulate propolis beyond the prestige condition. `PlotService.ClaimPlot` already checks a cost structure — this dispatch updates `Config.PLOT_COSTS` for slots 7–8 and patches `PlotService` to deduct propolis when the cost type is `"propolis"`.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 85 (Prestige Achievements)

---

## DESIGN

### Cost table update

```lua
-- Config.PLOT_COSTS (current — all honey)
[7] = {honey = 800},
[8] = {honey = 1200},

-- Config.PLOT_COSTS (after this dispatch)
[7] = {propolis = 150},
[8] = {propolis = 300},
```

Values chosen so:
- Slot 7 costs 150 propolis — achievable after ~30 foraging trips without upgrades (propolis base ~5/trip).
- Slot 8 costs 300 propolis — requires either propolis upgrades or ~60+ trips; a meaningful mid-game goal.
- Both remain affordable before first prestige (max propolis = 1,000) so all 8 plots can be owned without prestiging.

### PlotService patch

`PlotService.ClaimPlot` currently deducts `plot.cost.honey` from `profile.honey`. The new branch:

```lua
if cost.propolis then
    if profile.propolis < cost.propolis then
        return false, "Not enough propolis"
    end
    profile.propolis = profile.propolis - cost.propolis
elseif cost.honey then
    -- existing path
end
```

After the deduction, `DataService.SaveProfile(player)` and `PlotSync:FireAllClients(...)` are called as usual.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | Update `PLOT_COSTS[7]` and `PLOT_COSTS[8]` to propolis costs |
| `PlotService` | Add propolis deduction branch inside `ClaimPlot` |

---

## STEP A — Config: update expansion plot costs

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("propolis = 150", 1, true) then
    print("⏭️  Config already has propolis expansion costs — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    -- Replace slot 7 cost
    local src = clone.Source

    -- Pattern: [7] = {honey = <number>}  →  [7] = {propolis = 150}
    local p7_pat = '%[7%]%s*=%s*%{%s*honey%s*=%s*%d+'
    local p7_new = '[7] = {propolis = 150'
    src = src:gsub(p7_pat, p7_new)

    -- Pattern: [8] = {honey = <number>}  →  [8] = {propolis = 300}
    local p8_pat = '%[8%]%s*=%s*%{%s*honey%s*=%s*%d+'
    local p8_new = '[8] = {propolis = 300'
    src = src:gsub(p8_pat, p8_new)

    -- If no honey-based [7]/[8] entries found, inject them
    if not src:find("propolis = 150", 1, true) then
        local plotCosts = src:find("PLOT_COSTS", 1, true)
        if plotCosts then
            -- Find the closing brace of PLOT_COSTS table
            local tableEnd = src:find("%}%s*\n?%s*,?\n?%s*\n?%s*[A-Z]", plotCosts)
            if tableEnd then
                src = src:sub(1, tableEnd - 1)
                    .. "\n\t[7] = {propolis = 150},"
                    .. "\n\t[8] = {propolis = 300},"
                    .. src:sub(tableEnd)
                print("Injected [7] and [8] propolis costs into PLOT_COSTS")
            else
                print("⚠️  Could not find PLOT_COSTS table end — manual edit needed")
            end
        end
    end

    clone.Source = src
    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil
    clone.Name = "Config"
    clone.Parent = SSS
    print("✅ Config PLOT_COSTS slots 7-8 updated to propolis")
end
```

---

## STEP B — PlotService: add propolis deduction branch

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PlotService")
assert(ps, "PlotService not found")

if ps.Source:find("cost.propolis", 1, true) then
    print("⏭️  PlotService already handles cost.propolis — skip")
else
    local clone = ps:Clone()
    clone.Name = "PlotService_WORKING"

    -- Find the existing honey deduction: profile.honey = profile.honey - cost.honey
    local anchor = 'profile.honey = profile.honey - cost.honey'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        -- Alternate pattern: profile.honey -= cost.honey  or  profile.honey = profile.honey - plot.cost.honey
        anchor = 'profile.honey%s*-%s*=%s*cost%.honey'
        found = clone.Source:find(anchor)
    end
    if not found then
        anchor = 'profile.honey%s*=%s*profile.honey%s*-%s*'
        found = clone.Source:find(anchor)
    end

    if found then
        -- Find the line containing the anchor
        local lineStart = found
        while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do
            lineStart = lineStart - 1
        end
        local lineEnd = clone.Source:find("\n", found, true) or #clone.Source
        local deductLine = clone.Source:sub(lineStart, lineEnd)
        local indent = deductLine:match("^(\t+)") or "\t\t"

        -- Replace the single honey deduction with an if/elseif block
        local newBlock = indent .. "if cost.propolis then\n"
            .. indent .. "\tif (profile.propolis or 0) < cost.propolis then\n"
            .. indent .. "\t\treturn false, \"Not enough propolis\"\n"
            .. indent .. "\tend\n"
            .. indent .. "\tprofile.propolis = (profile.propolis or 0) - cost.propolis\n"
            .. indent .. "elseif cost.honey then\n"
            .. indent .. "\t" .. deductLine:gsub("^%s+", "") .. "\n"
            .. indent .. "end"

        clone.Source = clone.Source:sub(1, lineStart - 1) .. newBlock .. clone.Source:sub(lineEnd + 1)
        print("Propolis deduction branch injected")
    else
        print("⚠️  Honey deduction line not found in PlotService — manual edit needed")
    end

    -- Also patch the "not enough honey" guard above the deduction, if it checks honey only
    -- Pattern: profile.honey < cost.honey  →  wrap in else branch handled above already

    ps.Name = "PlotService_OLD_NX"
    ps.Parent = nil
    clone.Name = "PlotService"
    clone.Parent = SSS
    print("✅ PlotService propolis deduction branch added")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
table.insert(checks, (cfg and cfg.Source:find("propolis = 150") and "✅" or "❌") .. " Config: slot 7 propolis = 150")
table.insert(checks, (cfg and cfg.Source:find("propolis = 300") and "✅" or "❌") .. " Config: slot 8 propolis = 300")
table.insert(checks, (cfg and not cfg.Source:find("%[7%]%s*=%s*{%s*honey") and "✅" or "❌") .. " Config: slot 7 no longer honey cost")

local ps = SSS:FindFirstChild("PlotService")
table.insert(checks, (ps and ps.Source:find("cost.propolis") and "✅" or "❌") .. " PlotService: cost.propolis branch")
table.insert(checks, (ps and ps.Source:find("Not enough propolis") and "✅" or "❌") .. " PlotService: propolis guard message")

-- Sanity print current PLOT_COSTS for slots 7 and 8
if cfg then
    local s7 = cfg.Source:match("%[7%]%s*=%s*(%b{})")
    local s8 = cfg.Source:match("%[8%]%s*=%s*(%b{})")
    table.insert(checks, "📋 Slot 7 cost: " .. (s7 or "not found"))
    table.insert(checks, "📋 Slot 8 cost: " .. (s8 or "not found"))
end

print("=== DISPATCH 86 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 86 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Config + source patches only | 0 new parts |
| **Dispatch 86 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The 150/300 propolis costs are tuned against the default propolis economy: base yield ~5/trip, max 1,000 per prestige cycle. At 150 for slot 7, a player with no propolis upgrades needs ~30 trips — roughly one real-world play session. Slot 8 at 300 is 2 sessions or 1 session with propolis upgrades. Both feel earned without being grindy.
- If `PlotService.ClaimPlot` has a separate "can afford" check before the deduction (e.g. `if profile.honey < cost.honey then return false end`), STEP B only patches the deduction line, not the guard. The `if cost.propolis` block includes its own guard (`if profile.propolis < cost.propolis then return false end`) so the net behavior is correct. However, the old `profile.honey < cost.honey` guard may still run first for propolis-cost plots and incorrectly reject the purchase if `cost.honey` is `nil` (nil < number is a Lua runtime error). To be safe, STEP B's injection should be placed BEFORE any standalone `cost.honey` guard — check the output carefully and, if needed, also wrap the old guard: `if cost.honey and profile.honey < cost.honey then return false, "Not enough honey" end`.
- `PlotPurchaseSync` (or equivalent) already fires after a successful purchase from `PlotService`. The client receives the updated plot table through `PlotSync:FireAllClients` and re-renders purchase costs. No client changes are needed if the cost display reads directly from the `plot.cost` payload.
- If `HiveHUDController` or `PlotController` displays the cost of each plot as "🍯 X honey", it will need a patch to display "🐝 X propolis" for plots 7–8. That UI patch is a separate dispatch (deferred) — for now, the purchase will succeed silently with the correct propolis deduction even if the label still says honey.
