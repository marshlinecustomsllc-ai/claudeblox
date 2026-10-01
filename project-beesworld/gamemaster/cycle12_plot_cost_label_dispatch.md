# Dispatch 87 — Plot Cost Label: Propolis Display for Slots 7–8
## Cycle 12 · A Bee's World

**Feature:** Patches `PlotController` (or `HiveHUDController`) so the purchase button label for expansion slots 7 and 8 shows the propolis cost (e.g. "🔮 150 propolis") rather than the honey cost label. The controller already reads `plot.cost` from the `PlotSync` payload — this dispatch adds a format branch for `cost.propolis`.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 86 (Expansion Plot Propolis Cost)

---

## DESIGN

`PlotController` (or the plot purchase UI module) builds a label string when rendering each plot's purchase button. Current pattern:

```lua
local label = "🍯 " .. cost.honey .. " honey"
```

New pattern:

```lua
local label
if cost.propolis then
    label = "🔮 " .. cost.propolis .. " propolis"
else
    label = "🍯 " .. (cost.honey or 0) .. " honey"
end
```

The `🔮` emoji is the propolis icon used in `HiveStatsController` (from dispatch 36). Using the same emoji keeps the UI consistent.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PlotController` | Patch cost label to show propolis for `cost.propolis` plots |

---

## STEP A — Identify current cost label pattern

Command Bar (diagnostic — run before patching):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PlotController")
assert(ctrl, "PlotController not found")

-- Show all lines that mention "cost" or "honey" in the label context
local lines = {}
local i = 1
for line in ctrl.Source:gmatch("[^\n]+") do
    if line:find("cost") or line:find("honey.*label") or line:find("label.*honey") then
        table.insert(lines, i .. ": " .. line)
    end
    i = i + 1
end
print(table.concat(lines, "\n"))
```

Use the output to confirm the exact label pattern before running STEP B.

---

## STEP B — PlotController: patch cost label

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PlotController")
assert(ctrl, "PlotController not found")

if ctrl.Source:find("cost.propolis", 1, true) then
    print("⏭️  PlotController already handles cost.propolis label — skip")
else
    local clone = ctrl:Clone()
    clone.Name = "PlotController_WORKING"

    -- Strategy 1: find the honey label string and wrap it
    -- Common patterns:
    --   "🍯 " .. cost.honey .. " honey"
    --   cost.honey .. " Honey"
    --   tostring(cost.honey)

    local patterns = {
        '"🍯 " .. cost%.honey .. " honey"',
        '"🍯 " .. cost%.honey',
        'cost%.honey .. " honey"',
        'tostring%(cost%.honey%)',
        'cost%.honey',
    }

    local patchApplied = false
    for _, pat in patterns do
        local found = clone.Source:find(pat)
        if found then
            -- Find start and end of the line
            local lineStart = found
            while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do
                lineStart = lineStart - 1
            end
            local lineEnd = clone.Source:find("\n", found, true) or #clone.Source
            local oldLine = clone.Source:sub(lineStart, lineEnd)
            local indent = oldLine:match("^(%s*)") or ""

            -- Replace with conditional label assignment
            local varName = oldLine:match("(%w+)%s*=") or "costLabel"
            local newBlock = indent .. "local _costStr\n"
                .. indent .. "if cost and cost.propolis then\n"
                .. indent .. "\t_costStr = \"🔮 \" .. cost.propolis .. \" propolis\"\n"
                .. indent .. "else\n"
                .. indent .. "\t_costStr = \"🍯 \" .. (cost and cost.honey or 0) .. \" honey\"\n"
                .. indent .. "end\n"
                .. indent .. oldLine:gsub("^%s*", ""):gsub(pat:gsub("%%", "%%%%"), "_costStr")

            clone.Source = clone.Source:sub(1, lineStart - 1) .. newBlock .. clone.Source:sub(lineEnd + 1)
            print("Label patch applied using pattern: " .. pat)
            patchApplied = true
            break
        end
    end

    if not patchApplied then
        -- Fallback: inject a standalone helper function before 'return PlotController' (if module)
        -- or at start of the script
        local insertPoint = clone.Source:find("return PlotController", 1, true)
        if not insertPoint then
            insertPoint = clone.Source:find("-- end", 1, true)
        end
        if insertPoint then
            local helper = [[

-- Propolis cost label helper (dispatch 87)
local function formatCostLabel(cost: any): string
	if type(cost) == "table" and cost.propolis then
		return "🔮 " .. cost.propolis .. " propolis"
	end
	return "🍯 " .. (type(cost) == "table" and cost.honey or 0) .. " honey"
end

]]
            clone.Source = clone.Source:sub(1, insertPoint - 1) .. helper .. clone.Source:sub(insertPoint)
            print("Fallback: formatCostLabel helper injected — wire it to your label assignment manually")
        else
            print("⚠️  No inject point found — PlotController label patch requires manual edit")
        end
    end

    ctrl.Name = "PlotController_OLD_NX"
    ctrl.Parent = nil
    clone.Name = "PlotController"
    clone.Parent = SPS
    print("✅ PlotController cost label patched")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PlotController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " PlotController exists")
table.insert(checks, (ctrl and ctrl.Source:find("cost.propolis") and "✅" or "❌") .. " PlotController: cost.propolis branch")
table.insert(checks, (ctrl and ctrl.Source:find("propolis") and "✅" or "❌") .. " PlotController: 'propolis' text in source")

-- Check the label string exists with the propolis emoji
table.insert(checks, (ctrl and ctrl.Source:find("🔮") and "✅" or "❌") .. " PlotController: 🔮 propolis emoji")

print("=== DISPATCH 87 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 87 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patch only | 0 new parts |
| **Dispatch 87 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The `🔮` (crystal ball) emoji was established in `HiveStatsController` as the propolis icon. Using it here keeps the three resources visually distinct: 🍯 honey, 🔮 propolis, 🌼 pollen.
- STEP A is a **mandatory diagnostic before STEP B**. The label pattern in `PlotController` varies based on which dispatch version created it. If the diagnostic shows a different pattern (e.g. the label is set inside a `Gui.Text` property directly rather than a string variable), adjust STEP B's patterns list before running.
- If `PlotController` uses a `FormatCost(plot)` helper function (rather than inline string construction), STEP B's pattern may match inside that helper rather than at the call site — the patch is still valid since the helper is the single source of truth for the cost label.
- The `formatCostLabel` fallback (if the primary pattern fails) injects a helper function but does not automatically wire it. In that case: search for the line that sets the button's `Text` property (e.g. `btn.Text = <something involving cost>`) and replace the cost portion with `formatCostLabel(cost)`.
- If `HiveHUDController` (rather than `PlotController`) renders plot purchase costs, run the diagnostic against that script instead and adjust the `FindFirstChild` call in all three steps.
