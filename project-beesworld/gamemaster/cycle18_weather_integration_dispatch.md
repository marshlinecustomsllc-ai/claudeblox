# Dispatch 192 — Foraging & Population Weather Integration
**File:** `cycle18_weather_integration_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Dispatch 189 built `WeatherService` with a working season clock and `GetYieldMult()` / `GetHatchMult()` public API, but deferred the integration pass. This dispatch wires those multipliers into `ForagingService` (nectar yield per trip) and `PopulationService` (bee hatch interval), completing the seasonal economy. It also documents where `CombService.Harvest` applies temperature compensation so it's clear that the full weather pipeline is connected end-to-end.

All changes are surgical single-line edits to existing ModuleScripts — no new files, no new RemoteEvents, no part budget impact.

---

## Step 1 — Require WeatherService in ForagingService

Open **ServerScriptService → Systems → ForagingService**.

Find the top of the file where other services are required. Add one line:

```lua
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
```

---

## Step 2 — Apply yield multiplier in ForagingService

In `ForagingService`, find the section that computes nectar collected per trip. It will look similar to:

```lua
-- (existing code — exact variable names may vary)
local nectar = Formulas.ForagingYield(quality, species, distance)
```

Replace that line with:

```lua
local nectar = Formulas.ForagingYield(quality, species, distance) * WeatherService.GetYieldMult()
```

That's the entire change to ForagingService. `GetYieldMult()` returns:
- Spring × 1.15
- Summer × 1.30
- Autumn × 0.85
- Winter × 0.55

If `ForagingService` computes yield in multiple places (e.g. a separate harvesting path for honey_booster consumable), apply the multiply to every `Formulas.ForagingYield(...)` call.

---

## Step 3 — Require WeatherService in PopulationService

Open **ServerScriptService → Systems → PopulationService**.

Add at the top of the requires section:

```lua
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
```

---

## Step 4 — Apply hatch multiplier in PopulationService

In `PopulationService`, find the bee hatch interval logic. It will look similar to:

```lua
-- (existing code — exact variable names may vary)
local interval = Config.BASE_HATCH_INTERVAL / (adjacentHoney * Config.HATCH_HONEY_FACTOR)
```

The hatch multiplier should **reduce** the interval (higher mult → faster hatches). Replace or modify:

```lua
local interval = (Config.BASE_HATCH_INTERVAL / (adjacentHoney * Config.HATCH_HONEY_FACTOR))
	/ WeatherService.GetHatchMult()
```

`GetHatchMult()` returns:
- Spring × 1.10
- Summer × 1.25
- Autumn × 0.90
- Winter × 0.65

Dividing the interval by the mult means a Summer mult of 1.25 cuts the interval to 80% of base (faster hatching). Winter 0.65 extends it to ~154% (much slower).

If `PopulationService` uses `task.wait(interval)` directly inside a loop, the change lands there. If it schedules via a `task.delay`, update the delay argument.

---

## Step 5 — Verify WeatherService starts before dependents

Open **ServerScriptService → Main** (or whatever the server bootstrap Script is named). Confirm that `WeatherService` is started before `ForagingService` and `PopulationService` are initialised:

```lua
-- Inside Main server bootstrap (ensure this order):
local WeatherService    = require(Systems.WeatherService)
local ForagingService   = require(Systems.ForagingService)
local PopulationService = require(Systems.PopulationService)
-- ...
WeatherService.Start()   -- must be called before any foraging or hatching runs
ForagingService.Init()
PopulationService.Init()
```

If the bootstrap already calls `WeatherService.Start()` (added in dispatch 189), this step is a no-op confirmation. If it was not yet wired into the bootstrap, add the `WeatherService.Start()` call before the other service inits.

---

## Step 6 — Verification sweep

Run in **Studio Command Bar** (Edit mode reads script Source):

```lua
local Systems = game:GetService("ServerScriptService"):FindFirstChild("Systems")

local function checkScript(name, patterns)
	local s = Systems and Systems:FindFirstChild(name)
	if not s then print(name .. ": MISSING"); return end
	print(name .. ":")
	for _, pat in patterns do
		print("  " .. pat .. ": " .. tostring(s.Source:find(pat) ~= nil))
	end
end

checkScript("ForagingService", {
	"WeatherService",
	"GetYieldMult",
})

checkScript("PopulationService", {
	"WeatherService",
	"GetHatchMult",
})

checkScript("WeatherService", {
	"GetYieldMult",
	"GetHatchMult",
	"Start",
})

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
ForagingService:
  WeatherService: true
  GetYieldMult: true
PopulationService:
  WeatherService: true
  GetHatchMult: true
WeatherService:
  GetYieldMult: true
  GetHatchMult: true
  Start: true
Total parts: 4204  (expect 4204)
```

### Live smoke-test (Play mode)

To confirm the integration is live during Play, run in the Command Bar while the game is running:

```lua
local Systems = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local WS = Systems and require(Systems:FindFirstChild("WeatherService"))
if WS then
	print("Current season:", WS.GetCurrentSeason())
	print("Yield mult:", WS.GetYieldMult())
	print("Hatch mult:", WS.GetHatchMult())
else
	print("WeatherService not found")
end
```

Expected: prints current season name and matching multipliers from the SEASON_DATA_189 table.

---

## Integration summary

| Season | Yield mult (ForagingService) | Hatch mult (PopulationService) | Net effect |
|--------|-----------------------------|---------------------------------|------------|
| 🌸 Spring | ×1.15 | ×1.10 | Mild boost — good starter season |
| ☀️ Summer | ×1.30 | ×1.25 | Peak productivity — push ripeness hard |
| 🍂 Autumn | ×0.85 | ×0.90 | Slight slowdown — consolidate |
| ❄️ Winter | ×0.55 | ×0.65 | Significant slowdown — survival mode |

Weather sub-types (Heatwave, FoggyMorning, etc.) affect HiveTemperature via `tempDrift` (already running via WeatherService Heartbeat from dispatch 189) which then feeds through the existing HiveTempGaugeController display and CombService's temperature compensation formula. The full weather pipeline is now connected end-to-end.

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Two require() lines and two arithmetic edits in existing ModuleScripts — no new Instances)*
