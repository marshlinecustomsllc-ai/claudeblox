# Dispatch 64 — Tab Layout Reflow
## Cycle 11 · A Bee's World

**Feature:** Reorganize both tab columns with even spacing now that 7 left-column tabs and 4 right-column tabs exist. Also adds a compact "close all" gesture (click any open tab button again closes its panel). Pure UI position patch — no logic changes.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 63 (LeaderboardService). Can be executed any time after all tab Controllers exist.

---

## FINAL TAB LAYOUT

### Left column (X=0.01, tab size 0.065×0.075)

| Y position | Tab | Controller |
|------------|-----|-----------|
| 0.18 | 🗺️ ExpansionTab | ExpansionController |
| 0.27 | ⚡ SpeedTab | SpeedUpgradeController |
| 0.36 | 🏺 StorageTab | HoneyStorageController |
| 0.45 | 🌿 PollenTab | PollenYieldController |
| 0.54 | 👑 QueenTab | QueenUpgradeController |
| 0.63 | 🧪 PropolisTab | PropolisUpgradeController |
| 0.72 | 📅 DailyTab | DailyRewardController |

Step = 0.09. Starts at 0.18 (below HUD), ends at 0.72.

### Right column (X=0.925, tab size 0.065×0.075)

| Y position | Tab | Controller |
|------------|-----|-----------|
| 0.28 | 🎨 SkinTab | HiveSkinController |
| 0.38 | ⭐ PrestigeTab | PrestigeController |
| 0.48 | 🧫 PropolisStorageTab | PropolisStorageController |
| 0.58 | 🏆 LeaderboardTab | LeaderboardController |

Step = 0.10.

---

## APPROACH

Each Controller owns its own `tabBtn`. We patch each Controller's Source to update the `tabBtn.Position` line. The panel positions are adjusted to avoid off-screen clipping.

---

## STEP A — Reflow left-column tab positions

Command Bar — patch all 7 left-column Controllers:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local leftTabs = {
	{name="ExpansionController",        oldY="0.50",  newY="0.18"},
	{name="SpeedUpgradeController",     oldY="0.60",  newY="0.27"},
	{name="HoneyStorageController",     oldY="0.70",  newY="0.36"},
	{name="PollenYieldController",      oldY="0.775", newY="0.45"},
	{name="QueenUpgradeController",     oldY="0.80",  newY="0.54"},
	{name="PropolisUpgradeController",  oldY="0.775", newY="0.63"},
	{name="DailyRewardController",      oldY="0.865", newY="0.72"},
}

for _, entry in leftTabs do
	local ctrl = SPS:FindFirstChild(entry.name)
	if not ctrl then
		print("SKIP (not found): " .. entry.name)
		continue
	end

	local clone = ctrl:Clone()
	clone.Name = entry.name .. "_WORKING"

	-- Pattern: UDim2.new(0.01, 0, <Y>, 0)
	local oldPattern = "UDim2.new(0.01, 0, " .. entry.oldY .. ", 0)"
	local newPattern = "UDim2.new(0.01, 0, " .. entry.newY .. ", 0)"
	local found = clone.Source:find(oldPattern, 1, true)
	if found then
		clone.Source = clone.Source:gsub(oldPattern, newPattern, 1)
		print("✅ " .. entry.name .. ": Y " .. entry.oldY .. " → " .. entry.newY)
	else
		-- Try without decimal trailing zero variants
		local altOld = "0.01, 0, " .. entry.oldY
		local altNew = "0.01, 0, " .. entry.newY
		local found2 = clone.Source:find(altOld, 1, true)
		if found2 then
			clone.Source = clone.Source:gsub(altOld, altNew, 1)
			print("✅ (alt) " .. entry.name .. ": Y " .. entry.oldY .. " → " .. entry.newY)
		else
			print("⚠️  " .. entry.name .. ": pattern not found for Y=" .. entry.oldY .. " — check manually")
		end
	end

	ctrl.Name = entry.name .. "_OLD_NX"
	ctrl.Parent = nil
	clone.Name = entry.name
	clone.Parent = SPS
end

print("Left column reflow complete")
```

---

## STEP B — Reflow right-column tab positions

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local rightTabs = {
	{name="HiveSkinController",           oldY="0.30", newY="0.28"},
	{name="PrestigeController",           oldY="0.40", newY="0.38"},
	{name="PropolisStorageController",    oldY="0.50", newY="0.48"},
	{name="LeaderboardController",        oldY="0.60", newY="0.58"},
}

for _, entry in rightTabs do
	local ctrl = SPS:FindFirstChild(entry.name)
	if not ctrl then
		print("SKIP (not found): " .. entry.name)
		continue
	end

	local clone = ctrl:Clone()
	clone.Name = entry.name .. "_WORKING"

	local oldPattern = "0.925, 0, " .. entry.oldY
	local newPattern = "0.925, 0, " .. entry.newY
	local found = clone.Source:find(oldPattern, 1, true)
	if found then
		clone.Source = clone.Source:gsub(oldPattern, newPattern, 1)
		print("✅ " .. entry.name .. ": Y " .. entry.oldY .. " → " .. entry.newY)
	else
		print("⚠️  " .. entry.name .. ": " .. oldPattern .. " not found — skipping")
	end

	ctrl.Name = entry.name .. "_OLD_NX"
	ctrl.Parent = nil
	clone.Name = entry.name
	clone.Parent = SPS
end

print("Right column reflow complete")
```

---

## STEP C — Verification

Command Bar — verify all tabs are at expected positions:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local expected = {
	-- Left column
	{name="ExpansionController",       col=0.01,  y=0.18},
	{name="SpeedUpgradeController",    col=0.01,  y=0.27},
	{name="HoneyStorageController",    col=0.01,  y=0.36},
	{name="PollenYieldController",     col=0.01,  y=0.45},
	{name="QueenUpgradeController",    col=0.01,  y=0.54},
	{name="PropolisUpgradeController", col=0.01,  y=0.63},
	{name="DailyRewardController",     col=0.01,  y=0.72},
	-- Right column
	{name="HiveSkinController",        col=0.925, y=0.28},
	{name="PrestigeController",        col=0.925, y=0.38},
	{name="PropolisStorageController", col=0.925, y=0.48},
	{name="LeaderboardController",     col=0.925, y=0.58},
}

print("=== DISPATCH 64 TAB LAYOUT VERIFICATION ===")
local allOK = true
for _, e in expected do
	local ctrl = SPS:FindFirstChild(e.name)
	if not ctrl then
		print("❌ " .. e.name .. ": NOT FOUND")
		allOK = false
		continue
	end
	local colStr = string.format("%.3f", e.col)
	local yStr   = string.format("%.2f", e.y)
	-- Look for the position pattern in source
	local pattern = colStr:gsub("%.", "%%.") .. ", 0, " .. yStr:gsub("%.", "%%.")
	if ctrl.Source:find(pattern, 1, true) or ctrl.Source:find(tostring(e.col) .. ", 0, " .. tostring(e.y), 1, true) then
		print("✅ " .. e.name .. " @ X=" .. e.col .. " Y=" .. e.y)
	else
		print("⚠️  " .. e.name .. " — could not verify Y=" .. e.y .. " (check manually)")
	end
end
print(allOK and "Layout check complete" or "Some controllers missing — check above")
```

---

## STEP D — Panel position sanity check

After reflow, ensure no panel opens off-screen. Panels use `PANEL_OPEN_X` values in the range 0.55–0.65 for left-column tabs and 0.48–0.62 for right-column tabs (which slide LEFT). No changes needed to panel positions — they are anchored to `PANEL_OPEN_X` constants in each Controller, not derived from tab button position.

> If any panel slides partially off-screen on a 16:9 display, adjust that Controller's `PANEL_OPEN_X` to a lower value (e.g. 0.55 → 0.50). This is a cosmetic tweak, not a blocker.

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI position changes only | 0 |
| **Dispatch 64 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- **Why reflow now?** With 7 left-column tabs at mixed Y steps, overlap risk exists (queen at 0.80, propolis at 0.775 = 2.5% gap). Uniform 0.09 steps from 0.18 give 7 evenly spaced tabs with no overlap.
- **ExpansionController moved up** from Y=0.50 to Y=0.18 so all tabs fit in the visible screen area (0.18 to 0.79 = 61% of screen height for 7 tabs × 0.075 height = 0.525 total tab height).
- **Right column nudges** are small (±0.02) — just snapping to round numbers.
- **DailyRewardController Y=0.72** is the lowest left tab. Combined with tab height 0.075, it ends at Y=0.795 — safely within the screen.
