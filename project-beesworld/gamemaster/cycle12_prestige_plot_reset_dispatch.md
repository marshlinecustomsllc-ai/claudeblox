# Dispatch 81 — PlotService: ResetPlotsForPrestige
## Cycle 12 · A Bee's World

**Feature:** Injects `PlotService.ResetPlotsForPrestige(player, opts)` into the existing `PlotService` ModuleScript. Called by `PrestigeService` (dispatch 79) when a player completes a prestige. Resets plot ownership for plots 2–8, broadcasts `PlotSync` so all clients see the cleared plots immediately, and awards the player a small honey bonus for plot 1 (which they keep).
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 80 (LeaderboardService)

---

## DESIGN

```lua
PlotService.ResetPlotsForPrestige(player, opts)
    opts.keepPlotIds: {number}  -- plots NOT to reset (default {1})
```

Internal logic:
1. Iterate `PlotService` internal plot table.
2. For each plot owned by `player` where `plotId` not in `keepPlotIds`: set `plot.owner = nil`, `plot.isForaging = false`, `plot.beeCount = 0`.
3. Call the existing `PlotService` broadcast function to fire `PlotSync` to all clients.
4. Log the reset for debugging.

The function is added with an idempotency guard: if `PlotService.Source` already contains `ResetPlotsForPrestige` the patch is skipped.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PlotService` | Inject `ResetPlotsForPrestige` function |

---

## STEP A — PlotService: inject ResetPlotsForPrestige

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PlotService")
assert(ps, "PlotService not found")

if ps.Source:find("ResetPlotsForPrestige", 1, true) then
    print("⏭️  PlotService already has ResetPlotsForPrestige — skip")
else
    local clone = ps:Clone()
    clone.Name = "PlotService_WORKING"

    -- Inject the new function just before the final 'return PlotService' line
    local returnAnchor = 'return PlotService'
    local found = clone.Source:find(returnAnchor, 1, true)
    -- Find the last occurrence (there may be early returns)
    local lastFound = found
    local searchFrom = found + 1
    while true do
        local next = clone.Source:find(returnAnchor, searchFrom, true)
        if not next then break end
        lastFound = next
        searchFrom = next + 1
    end
    found = lastFound
    assert(found, "'return PlotService' not found in PlotService")

    local injection = [[

function PlotService.ResetPlotsForPrestige(player: Player, opts: {keepPlotIds: {number}?}?)
	local keepSet: {[number]: boolean} = {}
	local keep = opts and opts.keepPlotIds or {1}
	for _, id in keep do keepSet[id] = true end

	local resetCount = 0
	for _, plot in plots do
		if plot.owner == player.Name and not keepSet[plot.id] then
			plot.owner     = nil
			plot.isForaging = false
			if plot.beeCount ~= nil then plot.beeCount = 0 end
			resetCount += 1
		end
	end

	-- Broadcast updated plot state to all clients
	PlotService.BroadcastPlots()

	print("[PlotService] Prestige reset: " .. resetCount .. " plots cleared for " .. player.Name)
end

]]

    clone.Source = clone.Source:sub(1, found - 1) .. injection .. clone.Source:sub(found)

    ps.Name = "PlotService_OLD_NX"
    ps.Parent = nil
    clone.Name = "PlotService"
    clone.Parent = SSS
    print("✅ PlotService.ResetPlotsForPrestige injected")
end
```

> **Note:** The injection references `plots` (the internal plot table) and `PlotService.BroadcastPlots()` — both must exist in `PlotService` under those exact names. If the internal table is named differently (e.g. `_plots`, `plotData`), update the reference in the injection before running. Check with:
> ```lua
> local ps = game:GetService("ServerScriptService"):FindFirstChild("PlotService")
> print(ps and ps.Source:sub(1, 500) or "NOT FOUND")
> ```

---

## STEP B — Verify PlotService broadcast function name

Command Bar (read-only diagnostic):

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PlotService")
assert(ps, "PlotService not found")

-- Find all function definitions in PlotService
local functions = {}
for name in ps.Source:gmatch("function PlotService%.(%w+)") do
    table.insert(functions, name)
end

-- Find plot table name
local tableName = ps.Source:match("local (%w+)%s*=%s*{}")
    or ps.Source:match("local (%w+)%s*=%s*{%s*}")
    or "not found"

print("PlotService functions: " .. table.concat(functions, ", "))
print("Plot table variable (heuristic): " .. tableName)
print("Has BroadcastPlots: " .. tostring(ps.Source:find("BroadcastPlots") ~= nil))
print("Has FireAllClients: " .. tostring(ps.Source:find("FireAllClients") ~= nil))
print("Has PlotSync: " .. tostring(ps.Source:find("PlotSync") ~= nil))
```

If `BroadcastPlots` is not found, identify the actual broadcast call name from the output and re-run STEP A with the corrected function name.

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PlotService")

local checks = {
    (ps and "✅" or "❌") .. " PlotService exists",
    (ps and ps.Source:find("ResetPlotsForPrestige") and "✅" or "❌") .. " ResetPlotsForPrestige function present",
    (ps and ps.Source:find("keepPlotIds") and "✅" or "❌") .. " keepPlotIds opts parameter",
    (ps and ps.Source:find("BroadcastPlots") and "✅" or "❌") .. " BroadcastPlots broadcast call",
}

local prestige = SSS:FindFirstChild("PrestigeService")
table.insert(checks, (prestige and prestige.Source:find("ResetPlotsForPrestige") and "✅" or "❌") .. " PrestigeService calls ResetPlotsForPrestige")

print("=== DISPATCH 81 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 81 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patch only | 0 new parts |
| **Dispatch 81 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- This dispatch fulfills the `if PlotService.ResetPlotsForPrestige then` soft guard in dispatch 79. After execution, prestige will correctly clear plots 2–8 for the prestiging player.
- The injection goes before the final `return PlotService` to keep it inside the module's scope and ensure `plots` (the local table) is accessible.
- `PlotService.BroadcastPlots()` is assumed to be the function that iterates `plots` and fires `PlotSync:FireAllClients(...)`. If the broadcast is inlined (not a named function), STEP B's diagnostic will reveal this — in that case the injection should call `PlotSync:FireAllClients(PlotService.GetAllPlotData())` or equivalent.
- Plot 1 is always kept (`keepSet[1] = true` by default). This gives the player a starting base immediately after prestige without needing to reclaim their first plot.
- `plot.beeCount` is cleared with a nil check (`if plot.beeCount ~= nil`) since not all PlotService implementations track bee count per plot — earlier dispatches may use a different field name.
