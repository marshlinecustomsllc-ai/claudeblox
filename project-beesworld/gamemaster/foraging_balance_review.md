# Foraging Balance Review: Trip Time vs Real Patch Distances (pending_fixes #4)

**Type:** C-SYSTEMIC review (read-only investigation). Place 123313915411717. Everything below was read live from Studio on 2026-09-29.

## Verdict

1. **No Config value needs to change.** None of the 9 species' `nectarMult`, and none of `Config.FORAGING` (`baseCarry 8`, `baseFlightSpeed 18`, `tripTimeFixedOverhead 3`), is a broken outlier against the real distances.
   - The 7 base species form a clean, monotonic ladder on every plot. No species is dead and none dominates.
   - A global constant change such as flight speed would be a sweeping rebalance. It would also quietly delete the WINGS lever, dance quality and Route Fading. Rejected (section 6).
2. **There is one real problem: Fireweed (Gen 1) and Aurora Bloom (Gen 3).** It is spatial, not numeric. Each is a single patch in opposite far corners of the meadow, so its value depends on plot assignment:
   - Fireweed is worth 3.0x more on Plot 1 than on Plot 6.
   - Aurora Bloom is worth 3.0x more on Plot 6 than on Plot 1.
   - On 4 of 6 plots the Gen 1 unlock adds **0-2%** income.
   - On Plot 1 the Gen 3 unlock adds **3%**.
   
   That is a punishment for reaching them, not a reward. **Fix:** mirror each species into a pair of patches at fair positions. This means 2 patches moved and 2 added (+~7 parts), with **no Config edits**. Section 5.
3. **A prerequisite bug makes the problem latent today: Fireweed and Aurora Bloom cannot be marked by anyone.**
   - Their `Blooming` attribute is statically `false`, because `PatchService.recomputeBlooming` early-returns for `genGate` species.
   - `PatchController` disables the MARK prompt whenever `Blooming == false`.
   - `genGate` is enforced nowhere on the patch/dance path.
   
   Swarm/Generation shipped this session, so the "Gen 1 -> Fireweed / Gen 3 -> Aurora Bloom" rewards promised in architecture.md line 716 are currently unreachable content. The spatial fix and the gating fix must ship together (section 5.2). If the gating fix ships alone, the plot lottery goes live.
4. **Route Fading does not compound with distance.** The premise that you must walk out to far patches to re-dance is false: re-dancing happens at the player's **own Dance Floor** (`DanceService.RequestDanceStart` checks `startProximityStuds = 12` to the plate, and nothing near the patch). The refresh cost is identical for every route, and decay is a uniform percentage on quality. No change is needed. Section 4.

---

## 1. The live formula (confirmed)

`ForagingService.computeRouteRates` (lines 130-219) with `Formulas.TripTime` and `Formulas.YieldPerTrip`:

```
distance     = flat XZ |patch.PrimaryPart.Position - own DanceFloorCentrePlate.Position|   (computed LIVE per plot)
flightSpeed  = 18 * (1 + 0.08*strongWings) * weather.flightSpeedMult
carry        = 8 + 1*deepCrop
tripTime     = 2*distance/flightSpeed + 3
yieldPerTrip = carry * nectarMult * festivalMult * richness * EffectiveRouteQuality * weather.nectarMult
ratePerBee   = yieldPerTrip / tripTime        (0 during Rain)
SUPPLY = sum(ratePerBee * 10);  WINGS = greedy best-first, 10 foragers/route;  honey = min(SUPPLY, WINGS, COMB) * queen * gen * seams / 3
```

Facts that matter:
- **Distance is never read from data.** `Config.SPECIES[x].distance` (45/72/112/138/178/180/200/200/258) and the patch models' `Distance` attribute (the same stale values) have **zero consumers**. Grep: the only read of the `Distance` attribute is PatchService caching it into `patch.distance`, which nothing reads. Both are the original design numbers and are dead documentation.
- `richness` is **1.0 on all 18 patches** and never mutates (PatchService TODO), so it is currently a no-op.
- Route slots: Dance Floor T1 = **2** (+1 with the gamepass). Dance Floor tiers are not purchasable. So what matters per player is the **top-2 `ratePerBee`** among the patches they have marked.
- **Plot assignment:** `PlotService.FindFirstUnownedPlotIndex` gives each session the first free plot **in order**. A solo player is always on Plot 1. The same player can land on a different plot next session, while their saved routes (stored by `patchId`) keep pointing at the same patches.
- The distances in the task brief and in `state.json` ("72-674") are wrong. The real range across all 108 plot x patch pairs is **139-722 studs**. 72 was Dandelion's old Config value.

## 2. Real ratePerBee, all 9 species

Baseline: Good dance (quality 1.0), no perks, Clear weather, richness 1.0. Perfect = x1.25 and Poor/fully faded = x0.70, applied uniformly. `yieldPerTrip = 8 x nectarMult`. For each plot the **nearest** patch of that species is shown as distance studs / tripTime s / **ratePerBee** nectar/s.

| Species (patches) | mult | yield/trip | Plot 1 (x=-325) | Plot 2 (-195) | Plot 3 (-65) | Plot 4 (65) | Plot 5 (195) | Plot 6 (325) |
|---|---|---|---|---|---|---|---|---|
| White Clover (#1-4) | 1.0 | 8.0 | 139 / 18.5 / **0.433** | 171 / 22.0 / **0.364** | 146 / 19.2 / **0.416** | 144 / 19.0 / **0.420** | 169 / 21.8 / **0.367** | 139 / 18.5 / **0.433** |
| Dandelion (#5-7) | 1.3 | 10.4 | 187 / 23.8 / **0.437** | 173 / 22.2 / **0.468** | 175 / 22.4 / **0.464** | 175 / 22.4 / **0.464** | 173 / 22.2 / **0.468** | 187 / 23.8 / **0.437** |
| Lavender (#8-10) | 1.7 | 13.6 | 249 / 30.6 / **0.444** | 203 / 25.5 / **0.533** | 220 / 27.5 / **0.495** | 214 / 26.8 / **0.508** | 200 / 25.2 / **0.539** | 244 / 30.1 / **0.451** |
| Sunflower (#11-12) | 2.4 | 19.2 | 327 / 39.3 / **0.489** | 250 / 30.8 / **0.624** | 228 / 28.4 / **0.677** | 231 / 28.7 / **0.669** | 253 / 31.1 / **0.618** | 329 / 39.5 / **0.486** |
| Linden Blossom (#13-14) | 3.1 | 24.8 | 253 / 31.1 / **0.796** | 273 / 33.3 / **0.744** | 345 / 41.3 / **0.601** | 345 / 41.3 / **0.601** | 273 / 33.3 / **0.744** | 253 / 31.1 / **0.796** |
| Moonflower (#15-16) | 4.2 | 33.6 | 398 / 47.2 / **0.712** | 314 / 37.9 / **0.887** | 269 / 32.9 / **1.021** | 271 / 33.1 / **1.014** | 311 / 37.6 / **0.894** | 393 / 46.6 / **0.721** |
| Fireweed (#17 only, Gen 1) | 5.5 | 44.0 | 219 / 27.4 / **1.607** | 274 / 33.5 / **1.314** | 369 / 44.0 / **1.000** | 480 / 56.4 / **0.781** | 599 / 69.6 / **0.632** | 722 / 83.2 / **0.529** |
| Aurora Bloom (#18 only, Gen 3) | 9.0 | 72.0 | 721 / 83.1 / **0.866** | 599 / 69.5 / **1.036** | 480 / 56.4 / **1.277** | 370 / 44.1 / **1.632** | 277 / 33.8 / **2.130** | 225 / 28.0 / **2.572** |
| Pine Resin | -- | -- | n/a: tagged `ResinNode`, not `FlowerPatch`, so it can never be a route. No `nectarMult`; `propolisPerSec` is hard 0 | | | | | |

## 3. Question 3: dead content, dominance, end-game

**Is any patch dead (never rational over a nearer option)?** No.
- Moving up the base ladder never loses nectar on any plot: Clover 0.36-0.43 -> Linden/Moonflower 0.60-1.02.
- The only places where a higher tier is not strictly better are small and harmless:
  - On Plots 1 and 6, Clover, Dandelion and Lavender sit within 3% of each other (0.433 / 0.437 / 0.444), and Moonflower (0.71) sits just under Linden (0.80). The central patches are far from the edge plots.
  - Dandelion and Sunflower still have a clear job as the pollen species (pollenRatio 0.9 / 1.2 against Lavender's 0.3).
  - This part of the ladder is covered anyway. In the opening, after the first few minutes, the WINGS bar is fed by brood hatching (12 s lay interval, popCap 6 per Brood cell), not by which early flower you picked. Bottlenecks rotate before small rate gaps can be felt.
  - A per-species `nectarMult` nudge cannot fix an edge-plot-only flatness without breaking the centre plots. For example, Lavender 1.7 -> 2.0 would make Lavender beat Sunflower on Plots 1 and 6. **Accepted as is.**
- The base-game end state (best 2 of the 7 base species) spreads **1.51 (Plots 1/6) to 1.99 (Plots 3/4)**: edge plots earn 24% less while route-bound. This is moderate. The Linden pair at the corners already partly offsets the central Moonflowers, so it is **accepted**. Logged for awareness only.

**Does any patch dominate so hard all others are pointless?** Only the Gen-gated species, which is their job. That dominance is fine. Where it lands is the problem:

| Best 2 routes (Good) | Plot 1 | Plot 2 | Plot 3 | Plot 4 | Plot 5 | Plot 6 |
|---|---|---|---|---|---|---|
| Base game (7 species) | 1.51 | 1.67 | 1.98 | 1.99 | 1.70 | 1.52 |
| + Fireweed (Gen 1), **current** | 2.40 (**+59%**) | 2.20 (+32%) | 2.02 (**+2%**) | 1.99 (**+0%**) | 1.70 (**+0%**) | 1.52 (**+0%**) |
| + Aurora Bloom (Gen 3), **current** | 2.47 (**+3%**) | 2.35 (+7%) | 2.30 (+14%) | 2.65 (+33%) | 3.02 (+78%) | 3.37 (**+122%**) |

**Do Fireweed and Aurora Bloom make sense as end-game rewards?** Their `nectarMult` values (5.5, 9.0) do. **Their placement does not.**
- A Plot 6 player who swarms to Gen 1 unlocks a flower that is worse than their own Linden and Moonflower (0.53 vs 0.80 / 0.72).
- A Plot 1 player who grinds to Gen 3 unlocks a flower worth less than their Fireweed (0.87 vs 1.61).
- Because plots are handed out by join order, the same saved Aurora route earns 0.87 or 2.57 depending on who joined the server first. A kid cannot understand that and cannot fix it.
- The farthest pairs also reach dial 0.86 (722 studs over the 840 range), right at the edge the kid-friendly addendum had to guard against wrap-around. The best reward was also the hardest to dance.

Root cause: they are the only species with a **single** patch, and the two patches sit at opposite extremes (#17 at x=-364, #18 at x=361). Linden has a mirrored pair and Moonflower a central pair, so every other species gives each plot a nearby option.

## 4. Question 4: Route Fading x distance

**The premise is false in the live code:**
- Re-dancing (which refreshes fading) needs the player within 12 studs of **their own Dance Floor plate** (`RequestDanceStart`) and 14 studs at submit. The patch position is never checked after marking.
- A far route is refreshed exactly like a near one: stand on your Dance Floor, pick it from the menu, 2 taps, about 7 s.
- The only distance-linked walking is **marking**: 25 studs from the patch, **once per generation** (`SwarmService` wipes `markedPatches`). That is not tied to decay.

**Decay is distance-neutral:**
- `EffectiveRouteQuality` scales a route's quality by the same factor regardless of distance, so every route loses the same percentage.
- A far-rich route stays ahead of a near-poor one even when fully faded. Current Plot 6 Aurora at the 0.70 floor = 1.80, still above a fresh Perfect Linden (0.995).
- WINGS' best-first sort, eviction by oldest `lastDanced`, and the grace/fade clocks never read distance.
- Dance grading uses absolute-stud distance tolerances (Perfect 42 / Good 83), so a far patch is not harder to grade well, apart from the dial wrap-around near 1.0 noted above.

**Verdict: no interaction to fix.** Decay is an equal maintenance cost on every route, and far routes are not penalised twice. A Formulas-level change would have nothing to correct. The proposed layout also cuts the per-generation re-mark walk for the Gen species from up to 722 studs (45 s at WalkSpeed 16) to at most 318 studs (20 s).

---

## 5. Recommended change (the only one)

### 5.1 Spatial: mirror each Gen species into a fair pair (world-builder)

No Config edits. `PatchService.scanPatches` reads any number of `FlowerPatch` models, and ForagingService, DanceService and VfxController compute distance live, so no code needs to know about the new patches.

| Patch | Action | From | To (PrimaryPart X, Y, Z) |
|---|---|---|---|
| `Patch17_Fireweed` (PatchId 17) | **move** | (-364, 2, -210) | **(-130, 2, -245)** |
| `Patch19_Fireweed` (PatchId 19) | **new**, clone of #17 | -- | **(130, 2, -245)** |
| `Patch18_AuroraBloom` (PatchId 18) | **move** | (361, 2, -216) | **(200, 2, -245)** |
| `Patch20_AuroraBloom` (PatchId 20) | **new**, clone of #18 | -- | **(-200, 2, -245)** |

- **Attributes on the new patches:** copy from the source model (`Species`, `Richness = 1`, `Blooming`, `Distance`), set `PatchId` 19 / 20, tag `FlowerPatch`, and keep `PrimaryPart` set. The `Distance` attribute is unused (section 1). Copy it as is, or set 260 (Fireweed) / 280 (Aurora) for tidiness only.
- **Clearance (verified live):**
  - All four targets sit on `MeadowSoil` (X -400..400, Z -266..-96).
  - No PetalPath, Meadow Props, Hub or PerimeterRing part lies within the patch footprint + 4 studs (Fireweed footprint ~31 studs, Aurora ~49).
  - Nearest existing patch centres: Fireweed-W to Sunflower #11 is 47 studs; Aurora-W to Lavender #8 is 53; Fireweed to Aurora on the same side is 70.
  - An Aurora footprint centred at Z -245 overhangs the soil edge by about 3 studs (Moonflower #16 already does the same). World-builder may nudge Z to -242; that moves every number below by less than 1%.
- **Why these positions:**
  - The plots sit at x = +/-65, +/-195, +/-325. A pair at x = +/-200 is almost exactly on the Plot 2/5 line and equally far (130 studs in x) from Plots 1/3/4/6, which is the fairest pair the geometry allows.
  - Fireweed at x = +/-130 sits between Plots 2 and 3, so it stays below Aurora on every plot while still beating Moonflower everywhere.
  - Each west/east pair forms a small "rare grove" flanking the central Moonflowers: two Gen-reward landmarks a kid can see from the Petal Path.
- **Saved data:** no migration. No route to #17 or #18 can exist, because both have been unmarkable (5.2).
- **Part budget:** +~7 parts (patch models are 3-4 parts each).

**Result (same baseline as section 2):**

| | Plot 1 | Plot 2 | Plot 3 | Plot 4 | Plot 5 | Plot 6 |
|---|---|---|---|---|---|---|
| Fireweed nearest (d / rate) | 318 / 1.148 | 259 / 1.383 | 259 / 1.383 | 259 / 1.383 | 259 / 1.383 | 318 / 1.148 |
| Aurora Bloom nearest (d / rate) | 280 / 2.108 | 251 / 2.331 | 285 / 2.077 | 285 / 2.077 | 251 / 2.331 | 280 / 2.108 |
| Best 2, Gen 1 | 1.94 (+29%) | 2.29 (+37%) | 2.53 (+28%) | 2.53 (+27%) | 2.29 (+35%) | 1.94 (+28%) |
| Best 2, Gen 3 | 3.26 (+67%) | 3.71 (+62%) | 3.73 (+47%) | 3.73 (+47%) | 3.71 (+62%) | 3.26 (+67%) |

- Every plot now gets a felt upgrade at Gen 1 (+27-37%) and a capstone at Gen 3 (+47-67%).
- The spread across plots shrinks from 3.0x to 1.20x (Fireweed) and 1.12x (Aurora). The worst Gen 3 plot rises from 2.47 to 3.26 (Plot 1). The endgame ceiling moves only from 3.37 (Plot 6 today) to 3.73 (Plots 3/4), and Plot 6 itself dips 3% (3.37 -> 3.26). The overall endgame size is essentially unchanged, so no `nectarMult` retune is needed.
- The pair also gives a choice: a player who marks both patches of a species can re-dance whichever is closer to whatever plot they landed on this session.
- The furthest Gen-species dance target drops to dial 0.38, which removes the wrap-around risk for these flowers.

### 5.2 Prerequisite code fix: make Gen-gated flowers reachable (luau-scripter)

Ship in the same task as 5.1:
1. **`PatchService.recomputeBlooming`**: delete the `if species.genGate then return end` early return.
   - `Blooming` is a world-level "is the flower open" flag. Fireweed (08-18) and Aurora (21-04) should open and close on their windows like every other species.
   - Gating is per-player and belongs at mark time. Also update the module and function doc comments; the "no Generation-tracking system exists" claim is now false.
2. **`PatchService.MarkPatch`**: after the unknown-patch check, look up `Config.SPECIES[patch.speciesConfigKey]`. If it has a `genGate` and `(profile.generation or 0) < genGate`, return `false, "Needs Generation"`.
   - In `onRequestMarkPatch`, map that reason to `{ kind = "info", text = string.format("This rare flower needs Generation %d. Swarm your hive to reach it!", genGate) }`.
3. **`DanceService.RequestDanceStart`**: add the same defensive `genGate` check after `IsMarkedByPlayer`, for admin-granted or hand-edited marks. Return the same text via the existing Notify path.
4. **`PatchController`**: in both `prompt.Enabled` expressions, and in the `onPatchUpdate` one, also require the local player's generation to meet the species' `genGate`.
   - Read the generation from the player's own PlotRoot `Generation` attribute (written by PlotService line 238): find the PlotRoot whose `OwnerUserId == LocalPlayer.UserId`.
   - Re-evaluate on that attribute's change signal.
   - Do **not** set `markedLocally` optimistically for a gated species. Today a server rejection would leave the prompt disabled for the rest of the session.
   - Verify that SwarmService refreshes the `Generation` attribute after a swarm. If it does not, the server Notify from step 2 still keeps the behaviour correct.
5. **Verify:**
   - Edit mode: `PatchService._recomputeBlooming` flips #17/#19 inside 08-18 and #18/#20 inside 21-04.
   - Play mode, test profile at generation 0: marking #17 is rejected with the Gen 1 text.
   - Generation 1: #17 marks, dances, and `ForagingService._computeRouteRates` prices it at the table value for that plot.
   - Generation 1 player: marking #18 is rejected with the Gen 3 text.

---

## 6. Checked and deliberately NOT changed

| Candidate | Why not |
|---|---|
| Raise `baseFlightSpeed` (for example 18 -> 40) to restore the original design trip times (the 45-stud clover in architecture.md's worked example) | It is a global ~2x on every route. Almost every player would become COMB-bound, which quietly deletes the WINGS lever, dance quality and Route Fading, since those only matter when routes bind. The decay addendum's real-save measurement shows the current numbers keep all three bars in play: comb-bound on Plots 3/4, route-bound on the edge plots. Everything tuned since (kid-friendly retune, costs, Swarm threshold, decay) was sized against today's rates. |
| Opening pace | With the starter comb (1 Honey cell, COMB 1.2), 3 foragers on the nearest clover give WINGS 1.09-1.30 (Good). That is the same ~0.4 honey/s the design intended. After the 2nd Honey cell the bar flips to "NEED BEES!" instead of "NEED COMB!". Brood hatching (12 s, popCap 6) clears it within about 40 s. This is the three-lever rotation working, not a stall. |
| `nectarMult` tweaks for Lavender, Sunflower or Moonflower | The small non-monotonic spots are edge-plot geometry. Any per-species nudge trades one plot's flatness for another's inversion. |
| `tripTimeFixedOverhead` | At 3 s it is already negligible next to 18-83 s trips. Raising it enough to flatten distance would cut every route's rate. |
| `nectarMult` 5.5 / 9.0 | Correct once placement is fair (5.1 table). |

## 7. Observations logged (no action in this task)

- **Bloom windows do not gate yield.** `computeRouteRates` never reads `patch.blooming`, so a Moonflower route (20-05) forages all day. Bloom windows only gate *marking*. architecture.md never says yields stop outside the window. Changing this would cut night species hard with 12-minute days, and it needs a design decision, not a tuning pass.
- **`richness` is a no-op** (all 1.0, never drains). Depletion and regrowth are still an open PatchService TODO.
- **Dead data:** `Config.SPECIES[x].distance` and the patch `Distance` attributes hold the pre-fix design values and nothing reads them. Either delete them or add a Config comment that distance is computed live from world positions, so no future agent "tunes" them expecting an effect.
- **`state.json` pending_fixes #4** quotes "72-674 studs". The real range is 139-722. Close #4 with a pointer to this review. The follow-up is the 5.1 + 5.2 task.

## Dispatch summary

- **Config:** no changes.
- **One combined task, priority MEDIUM** (currently-unreachable Gen rewards plus a plot-lottery economy the moment they become reachable):
  - **world-builder:**
    - move #17 to (-130, 2, -245) and #18 to (200, 2, -245);
    - add #19 Fireweed at (130, 2, -245) and #20 AuroraBloom at (-200, 2, -245) as clones with PatchId 19 / 20;
    - +~7 parts.
  - **luau-scripter**, the 5.2 gating fix:
    - PatchService bloom tick and MarkPatch genGate;
    - DanceService defensive genGate;
    - PatchController prompt gating.
- **Route Fading:** no change. Refresh happens at home and decay is distance-neutral.
