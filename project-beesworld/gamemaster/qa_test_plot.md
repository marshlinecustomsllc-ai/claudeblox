# A Bee's World: QA test harness (Studio only)

Status: harness built and gated. Checklist run in Play. 6 of 8 functional steps PASS on real service code. Dance steps FAIL on an unexplained contradiction. See "Checklist results".

## Safety model
- Harness is active only when BOTH: `RunService:IsStudio()` is true AND `ServerScriptService.QATestMode` (BoolValue) has `Value = true`.
- Default: `QATestMode.Value = false`. In normal play nothing changes except boolean checks.
- While active:
  - `DataService.Load` returns a memory-only seeded profile for every player. No `UpdateAsync` runs, so no DataStore key is read, including the owner's `hive_2354572334`.
  - `DataService.Save` refuses every write (autosave, release-on-leave, BindToClose flush).
  - `LeaderboardService.RecordLifetimeHoney` refuses its `SetAsync` writes (honey and names stores).
  - Each refused write increments `QAGuard.BlockedWriteCount()` and prints `[QAGuard] blocked DataStore write #N: ...`.
- The seeded profile carries `qaTestUserId = -9001` as a label. The tester's Studio UserId cannot be changed, so the session is keyed to the tester's Player object. In the runs the tester's UserId was 2354572334 (the owner's account), but its profile came only from the memory seed, never from the store.

## Enable / run / disable
1. Edit mode: `ServerScriptService.QATestMode.Value = true`
2. Press Play. Console: `[QAGuard] Harness active: memory-only profile for <name>`, then `[QA-CHECK] ...` lines from QATestRunner.
3. Stop play, then set `QATestMode.Value = false` again. Leave it false before saving the place.

## Files (Studio session only, unsaved until the place is saved)
- NEW `ServerScriptService.Systems.QAGuard` (ModuleScript): `IsActive`, `ApplySeed`, `NoteBlockedWrite`, `BlockedWriteCount`.
- NEW `ServerScriptService.QATestMode` (BoolValue, Value=false).
- NEW `ServerScriptService.QATestRunner` (Script): returns at once unless QAGuard.IsActive(). Runs the checklist in the game's own server VM.
- EDIT `Systems.DataService`: require QAGuard; QA branch at top of `Load`; QA refusal at top of `Save`.
- EDIT `Systems.LeaderboardService`: require QAGuard; QA refusal at top of `RecordLifetimeHoney`.
- EDIT `Systems.PlotService` (owner-approved QA hook): see the diff below.

### PlotService diff (QA-only hook)
```
+ local QAGuard = require(script.Parent:WaitForChild("QAGuard"))
+ -- returns first plot 2..count with OwnerUserId nil or 0 and no assignment; never Plot1
+ function PlotService.FindQATestPlotIndex(): number?  (loop idx = 2, Config.PLOTS.count)
  function PlotService.AssignPlot(player: Player): number?
- 	local idx = PlotService.FindFirstUnownedPlotIndex()
+ 	local idx
+ 	if QAGuard.IsActive() then
+ 		idx = PlotService.FindQATestPlotIndex()
+ 	else
+ 		idx = PlotService.FindFirstUnownedPlotIndex()
+ 	end
 	if not idx then
```
The normal path (guard inactive) calls the same `FindFirstUnownedPlotIndex` as before.

## Fake profile (seed in QAGuard.ApplySeed)
- Memory-only, from `Config.PROFILE_TEMPLATE` (deep-copied), then seeded. Schema and migrations are the real ones.
- honey 2000, propolis 150, pollen 120, royalJelly 20 (Queen cost), queenTier 2, floorsUnlocked 2, tutorialStep 5.
- Comb: DanceFloor (0,0) from template; Pollen (-1,0); Honey lvl2 with 30 stored (1,-1); Honey lvl1 with 5 stored (-1,1).
- Daily quests: today's date, harvestCount 2, danceCount 1.
- Weekly quests: current epoch-week; progress harvest 23/25, upgrade 9/10, dance 14/15, resin 4/5, redance 7/8, build 9/10 (each just under Config.WEEKLY_POOL target).

## Plot
- Plot ownership is stored on each `PlotRoot` part's `OwnerUserId` attribute, not on the `Plot` folder. An earlier check read the folder and reported nil; that was a measurement error.
- Unowned sentinel is `OwnerUserId = 0`. In Play, the QA hook assigned the tester Plot2 (PlotRoot OwnerUserId = tester UserId). Plot1 stayed 0 throughout and was never taken.
- Pre-existing, not changed: Plot1..Plot6 Structures each contain duplicate GuardPerch / SwarmPerch models.

## Checklist results (Play, observed values)
Run in the game's server VM via QATestRunner. Two runs; final run shown.

| # | Step | Observed | Status |
|---|------|----------|--------|
| 0 | Plot assignment | tester assigned Plot2 by QA hook; Plot1 untouched | PASS |
| 1 | Harvest | returned 68.83; honey 2500 -> 2868.83; propolis 150 -> 180; daily harvestCount 2 -> 3 | PASS |
| 2 | Build (0,-1) Honey | cell count 6 -> 7; daily buildCount 0 -> 1; weekly buildCount 9 -> 10. Honey went +940, not the expected -60. A daily quest reward (likely) explains the difference; not isolated | PASS (cell placed, counters up). Honey delta unexplained |
| 3 | Upgrade (1,0) | CanUpgrade true; Upgrade ok; honey -180; weekly upgradeCount 9 -> 10. Cell tier not read | PASS (counter and cost); tier not read |
| 4 | Mark patch 1 | result true; daily markCount 0 -> 1; markedPatches = {"1": true} | PASS |
| 5a | Dance start patch 1 | "You have not marked that patch", even though markedPatches contains "1" and IsMarkedByPlayer(p,1) returned true one line earlier | FAIL (unexplained contradiction; see below) |
| 5b | Dance submit | "No dance is open" (follows from 5a) | NOT RUN (blocked by 5a) |
| 6 | Redance patch 1 | "You have not marked that patch"; weekly redanceCount unchanged 7 | FAIL (same contradiction as 5a) |
| 7 | Resin node | ResinService.Harvest ok; returned amt 3; propolis 280 -> 383; weekly resinCount 4 -> 5 | PASS (counter up); propolis +103 vs returned 3 is unexplained, not isolated |
| 8 | Queen upgrade | CanUpgrade true with rj 20; Upgrade ok; queenTier 2 -> 3; rj 20 -> 0 | PASS |
| 9 | Weekly seed | weekly progress present and increments on steps 1, 2, 3, 7 as above | PASS |
| 10 | DataStore guard | console: `blocked DataStore write #1` (during Queen Upgrade's save) and `#2` on stop-play. No real write | PASS |

Patch 20 (Aurora) was tried first and returned "Needs Generation", so Aurora is gated on Generation. Patch 1 is used for the mark and dance steps.

### Unexplained contradiction (steps 5a, 6)
`IsMarkedByPlayer(p, 1)` returns true in the same run as `RequestDanceStart(p, 1)` returns "You have not marked that patch". The gate is at DanceService line 751 and calls the same function. The cause is not isolated. Needs a developer to read DanceService around line 731-760 with the live state.

## Verified at the end of the run
- QATestMode reset to `false`.
- All six PlotRoots read `OwnerUserId = 0` after release.
- One `QAGuard`, one `QATestMode`, one `QATestRunner` (no duplicates).

## Not verified
- Dance submit (5b) and the dance grade / dancesTotal.
- Visual lanes (queen aura, honey drips, comb shimmer, harvest glow, forager trail, plot flags, visitor counter, plot tier badge, pollen sparkle, hive birthday, quest HUD chip, streak chip). Need a live client.
- The daily quest reward amount (suspected source of the Build honey delta).
- Cell tier after Upgrade.
- Weekly 3-of-6 pick logic.
- Edits exist only in the open Studio session until the place is saved.
