# Plot Layout Redo v2 -- Live-Corrected Spec

**Supersedes:** architecture_plot_layout_redo.md (its coordinates for the board, smoker, perches, sign, shed, kiln and swarm perch came from docs and are wrong).
**Basis:** builder's Edit-mode findings (plot-local studs, centre X 0 = plot centre, Z 0 = plot centre) plus plot_redo_baseline.txt (lattice and gate CFrames, all six plots). Studio was not re-read in this pass. Studio stays Edit-only during the build.
**Screenshot match:** 25.png shows a wooden "HOW TO BUILD A YOUR COMB" sign with a cream round pedestal beside it, two flat cream tiles and two brown discs at the front, grass tufts in the foreground, and the owner tag. I matched by object type, not by position. The sign and pedestal fit the Plot1 PlotSign and WardrobePedestal. The discs and tufts have no match in Plot1/Props (empty). No shed or kiln is visible, which agrees with the live finding that neither is built in plots.

---

## 0. What changed from v1

| Item | v1 said | Live says | Consequence |
|---|---|---|---|
| Landing board | (0,-24), 22x10 | (0,-32.5), 37.9 x 15.0, footprint Z -40..-25 | Overlaps lattice by 0.5 at X 0. Must move. |
| Smoker | (+8,-24), 3x5 | (0,-44), 12.3 x 3.5 x 7.5 | Sits in the walk lane. Must move. |
| Guard perches | (+/-20,-26), 6x6 | (+/-46,-32), 3.5 x 5.2 | **Already clear of everything. No move needed.** v1 was wrong. |
| Plot sign | (-52,-46), 14x10 | (-52,-46), 20.4 x 23.7 x 3.9 | Footprint X -62.2..-41.8 hangs 7.2 studs off the deck edge (X -55). Must move. |
| Wardrobe pedestal | (-46,-48), 4x4 | (-46,-48), size not reported | Overlaps the sign. Must move. |
| Shed and Kiln | (-42,-30), (+42,-30) | **No instance in plots** | Remove from the layout. No placement needed. |
| Swarm perch | (0,44), 10x6 | (0,44), 11.6 x 23 x 6.1 | Clears the rear plate by 3.45 (fails C1). Move to Z 45. |
| TeleportPad tag | 12 | **6** (baseline: PlotGateway1..6, one per plot) | Spec error. Use 6. |
| Lattice extent | X +/-35.2, Z -25.5..+37.5 | Same (checked from baseline plate positions and radius 7.5) | v1 was right here. |

v1 overstated the front-band overlap of the perches and the shed/kiln. The real crowding is the board, the smoker, the sign and the wardrobe.

---

## 1. Live numbers table

Footprint = axis-aligned box in plan (X x Z). Where the builder gave three sizes, I used the first two as X and Z. Where only two were given (guard perch), I used the larger value on both axes (conservative).

| Object | Count / plot | Live centre (X, Z) | Live size | Footprint used | Source |
|---|---|---|---|---|---|
| LandingBoard | 1 | (0, -32.5) | 37.9 x 15.0 (height not reported) | X +/-18.95, Z -40..-25 | builder Edit read |
| Smoker | 1 | (0, -44) | 12.3 x 3.5 x 7.5 | X +/-6.15, Z -47.75..-40.25 | builder Edit read. Rotation not reported. |
| GuardPerch | 2 | (-46, -32), (+46, -32) | 3.5 x 5.2 | 5.2 x 5.2: X +/-2.6 around centre, Z +/-2.6 | builder Edit read |
| PlotSign | 1 | (-52, -46) | 20.4 x 23.7 x 3.9 | 20.4 x 3.9 (assumes face normal along Z): X -62.2..-41.8, Z -47.95..-44.05 | builder Edit read. Rotation not reported. |
| WardrobePad (tag; "WardrobePedestal" tag = 0) | 1 | (-46, -48) | not reported | 4 x 4 (v1 figure, unverified) | builder centre; size from v1 |
| SwarmPerch | 1 | (0, 44) | 11.6 x 23 x 6.1 | 11.6 x 6.1: X +/-5.8, Z +/-3.05 | builder Edit read |
| Shed, Kiln | 0 | none | none | none | builder: no instance in plots |
| Bud buttons (BudButton tag = 0) | unknown | not found | not found | not placed | not verified (see section 7) |
| Lattice, Floor 1 | 19 discs, Y 7.2 | see baseline | disc diameter 15 (radius 7.5) | front row Z -18 at X 0, +/-13.856 -> front edge Z -25.5; X extremes +/-35.2; rear row Z 30 -> rear edge Z 37.5 | plot_redo_baseline.txt, Plot1 and all six plots |
| Lattice, Floor 2 | 12 discs, Y 23.2 | subset of Floor 1 XZ | radius 7.5 | same bounds | baseline |
| Lattice, Floor 3 | 7 discs, Y 39.2 | subset of Floor 1 XZ | radius 7.5 | same bounds | baseline |
| CombFloorGate | 2 per plot (Floor 2 and 3), 12 total | (-276.414 etc. Plot1 world), local ~(+49, 25.5) | 14.8 x 10 x 0.6, rotated | not moved | baseline |
| TeleportPad | 1 per plot, 6 total | Hub Gateways, Z -290 | 14 x 1 x 14 | not moved | baseline |
| Deck | 1 | centre (0, 0), top Y 6.5 | 110 x 110 | X +/-55, Z -55..+55 | v1 / builder (deck present) |
| Ramp | 1 | top at (0, -55) | 14 wide, Z -80..-55 | walk lane X +/-7, Z -55..-25.5 | v1 (not re-measured) |
| Fence bay | 1 | Z +52 | not measured | Z 52 assumed | v1, unverified |
| DimCellPlate tag total | 38 per plot | - | - | 228 total (matches baseline) | baseline |

---

## 2. Revised target positions and clearance math

Rules (carried from v1, unchanged):
- **C1:** prop footprint to any plate circle (centre +/-7.5) >= 4.0 studs. Measured as (distance from box to plate centre) - 7.5.
- **C2:** prop to prop >= 3.0 studs.
- **C3:** prop inside deck with >= 3.0 studs to the edge (X +/-55, Z -55..+55).
- **C4:** walk lane X -7..+7, Z -55..-25.5 has no non-walkable collidable prop.
- **C5:** front-band height limit (soft; see D9).
- **C6:** lattice and gate CFrames unchanged.

| Object | New centre (X, Z) | New footprint | Clearance math | Result |
|---|---|---|---|---|
| LandingBoard | **(0, -37.5)** | X +/-18.95, Z -45..-30 | Nearest plates (0,-18) and (+/-13.856,-18). Box edge Z -30. Gap = (30 - 18) - 7.5 = 4.5. Harvest from ramp top (0,-55) = 17.5 (NearPosition 18). Clear of deck edge: -45 - (-55) = 10. | C1 pass (4.5). Harvest pass (0.5 margin). |
| GuardPerch L | (-46, -32) (no move) | X -48.6..-43.4, Z -34.6..-29.4 | Nearest plate (-13.856,-18) at dx 29.5. Gap to nearest plate ~24. Gap to board X edge: -43.4 - (-18.95) = 24.45 (flanks, no overlap). Deck edge: -48.6 - (-55) = 6.4. | pass |
| GuardPerch R | (+46, -32) (no move) | X 43.4..48.6, Z -34.6..-29.4 | Mirror of L. Gap to board 24.45, deck edge 6.4. | pass |
| Smoker | **(+33, -37.5)** | X 26.85..39.15, Z -41.25..-33.75 | Gap to board: 26.85 - 18.95 = 7.9 (C2 pass). Gap to R perch: 43.4 - 39.15 = 4.25 (C2 pass). Nearest plate (13.856,-18): dx 13.0, dz 15.25 -> 20.0 - 7.5 = 12.5 (C1 pass). Bear entry (30,-50): dx 3, dz 12.5 -> distance 12.9 (<= 30 pass). Deck edge: 55 - 39.15 = 15.85. | pass |
| PlotSign | **(-40, -49)** | X -50.2..-29.8, Z -50.95..-47.05 | Deck edge X: -50.2 - (-55) = 4.8 (C3 pass). Deck edge Z: -50.95 - (-55) = 4.05 (C3 pass). Gap to board: X 10.85 (C2 pass). Gap to L perch Z: -34.6 - (-47.05) = 12.45 (pass). Nearest plate (-13.856,-18) to nearest box corner (-29.8,-47.05): 33.1 - 7.5 = 25.6 (pass). Rotation must be 0 (long axis along X). At 90 degrees the footprint is Z -59.2..-38.8 (off deck). | pass if rotation 0 |
| WardrobePad | **(-46, +10)** | X -48..-44, Z 8..12 (4 x 4, unverified) | Deck edge X: -48 - (-55) = 7 (C3 pass). Nearest plate (-27.712, 6): dx 16.3, dz 2 -> 16.4 - 7.5 = 8.9 (C1 pass). Outside front band. | pass (size unverified) |
| SwarmPerch | **(0, +45)** | X +/-5.8, Z 41.95..48.05 | Nearest plate (0,30): 41.95 - 30 = 11.95 - 7.5 = 4.45 (C1 pass; v1 position 44 gave 3.45). Plate (+/-13.856,30): dx 8.06, dz 11.95 -> 14.4 - 7.5 = 6.9. Fence Z 52 (unverified): gap 3.95 (C3 pass). Deck edge Z 55: 6.95. | pass |
| Bud buttons | not placed | - | Unknown live positions. Rule: keep out of the walk lane and clear C1/C2 (see section 7). | open |
| Shed, Kiln | not placed | - | Not built. | n/a |

**Front-band census after the move:** 5 objects (board, smoker, two perches, sign). v1 counted 8 with overlaps. Footprint area is about the same (board 568.5, smoker 92, perches 54, sign 80 = ~795 studs^2, about 24% of the 3,245 studs^2 band). The gain is clearance, not less area.

**Walk lane (C4):** the board is the only object in X +/-7, Z -55..-25.5. It is a walkable wedge (open question, D10). Smoker, perches and sign are all outside X +/-7.

**Harvest reach:** a player on the ramp top is at 17.5 from the board centre (inside NearPosition 18, 0.5 margin). A player two studs onto the deck (Z -53) is at 15.5. Playtest this. If the script measures from another point, redo this line.

---

## 3. Decisions (each with a default)

| # | Decision | Default |
|---|---|---|
| D1 | Move LandingBoard to (0, -37.5). | **Yes.** Only position that clears C1 by >= 4 with the 15-stud depth. |
| D2 | Guard perches. | **Do not move.** Live positions already clear everything. Moving them inward would add front-band crowding. |
| D3 | Smoker to (+33, -37.5), right side beside the board. | **Yes.** Left side would be 27 studs from bear entry (30,-50) and blocks the sign corner. |
| D4 | Plot sign to (-40, -49), one line: "Tap a glowing cell to build!" (unowned only; owned keeps owner name). | **Yes.** Full help stays in the ? help screen. |
| D5 | Wardrobe to (-46, +10), left strip. | **Yes.** Keeps the flow, away from the front. |
| D6 | Swarm perch to (0, +45). | **Yes.** |
| D7 | Grass tufts and brown discs. | **Remove if found** in plot-owned non-gameplay folders (Deck, Structures, Signs, Props). Props is empty, so default is a no-op for Plot1 unless a search finds them elsewhere. |
| D8 | Paw prints and wax drips. | **No change.** Not found as separate parts (section 6). Do not claim a trim. |
| D9 | Height limit C5 (12 studs in front band). | **Soft.** Sign (23.7) overlaps the lattice X range at Z -47 and the swarm perch (23) is rear. Default: accept, verify in Build Mode camera. If the sign hides front-left plates, drop the sign height to 12 (owner decision). |
| D10 | Board walkable. | **Yes.** Check slope in Edit. If not walkable, C4 fails and the board goes back to a non-blocking part. |
| D11 | "Glue Pot" rename. | **Defer.** No plot instance. Text-only, separate pass. |
| D12 | Tag names. | **Do not rename.** Use WardrobePad (6). BudButton and DanceFloor tags read 0. Confirm script names before any tag work. |

---

## 4. Stale items resolved

- **TeleportPad:** 6, not 12. Baseline lists PlotGateway1..6, one per plot. Update section 5 and build check 8.
- **Shed and Kiln:** removed from the layout. Old "shop" and "glue" text placements no longer apply to plots.
- **Board, smoker, perches, sign, wardrobe, swarm perch:** replaced with live values (section 1).
- **Lattice extent:** v1 was right (plate-inclusive X +/-35.2, Z -25.5..+37.5). Update architecture.md when built.
- **Royal cell:** not re-flipped. RoyalCapsule untouched (buglist #81, #90). Not in the front band.

---

## 5. Build order (Edit mode only)

Stop if Studio is in Play mode. Do not start or stop play mode.

**Step 0. Mode check.** Edit mode confirmed. Abort otherwise.

**Step 1. Baseline capture.**
- For every plot: CFrame, size and rotation of each DimCellPlate, CombFloorGate and WaxSpiralRamp. Compare to plot_redo_baseline.txt (DimCellPlate lines 2..229, gate lines 230..241). Record any difference.
- BasePart descendant count per plot. Record as the "before" number.
- Tag counts: DimCellPlate 228, CombFloorGate 12, TeleportPad 6. Also record LandingBoard, Smoker, GuardPerch, PlotSign, SwarmPerch, WardrobePad, BudButton, DanceFloor (no baseline; record now).

**Step 2. Search for clutter.** Search all plot descendants by name and material for: grass, tuft, disc, paw, drip, wax. Record names, counts, folders. Do not remove anything not in the search results. Never touch LatticePad or DanceFloorInnerRing.

**Step 3. Moves (PivotTo, keep Y and rotation).**
- LandingBoard -> (0, -37.5)
- Smoker -> (33, -37.5)
- PlotSign -> (-40, -49); confirm rotation 0 first.
- WardrobePad -> (-46, 10)
- SwarmPerch -> (0, 45)
- GuardPerch x2: no move.
- Do not rebuild instances.

**Step 4. Removals.** Only what Step 2 found and D7 covers. Otherwise no-op.

**Step 5. Text.** Sign text per D4. Text fields only. No script source, attributes or tags changed.

**Step 6. Checks (all must pass, numeric):**
1. **Count:** per plot, BasePart count after = before minus removals from Step 4. No move changes count. Max-tier plot must be <= 340 (architecture.md budget; not re-verified here).
2. **C1:** for every prop footprint, (distance from box to each of the 38 plate centres in that plot) - 7.5 >= 4.0. Zero violations. Expected minimum: board 4.5, sign 25.6, smoker 12.5, perches ~24, wardrobe 8.9, swarm 4.45.
3. **C2:** prop pairs >= 3.0. Expected minimum: smoker-perch R 4.25, board-perch 24.45, swarm-other 0 (only one swarm perch).
4. **C3:** every prop inside X +/-55, Z -55..+55 with >= 3.0 to edge. Expected minimum: sign Z 4.05, sign X 4.8, swarm to fence 3.95.
5. **C4:** lane X -7..+7, Z -55..-25.5 has no non-walkable collidable prop (board walkable per D10).
6. **C5:** soft; record heights and Build Mode view (D9).
7. **C6:** DimCellPlate, CombFloorGate and WaxSpiralRamp CFrames and sizes equal to baseline (Step 1). Royal cell Y 7.2..21.2 on Plot1 rim plate unchanged.
8. **Tags:** counts equal to Step 1 (DimCellPlate 228, CombFloorGate 12, TeleportPad 6, others as recorded).
9. **Anchoring:** every moved prop keeps its existing Anchored and CanCollide values.
10. **Harvest:** distance from (0, -55) to board centre (0, -37.5) = 17.5 <= 18. Re-check if the script measures from elsewhere.
11. **Bear:** distance from smoker (33, -37.5) to (30, -50) = 12.9 <= 30.
12. **Text:** no plot label contains lattice, propolis, kiln, prestige, cost or outer rim. Sign text matches D4 exactly.
13. **One sign:** one PlotSign text board visible while unowned, per plot.

**Step 7. Report.** Table of checks with PASS/FAIL. Any FAIL goes back to the step that owns it.

**Step 8 (later, not in this spec).** Play-test after hub build. Computer-player run.

---

## 6. What I could not verify

- **Paw-print and wax-drip counts (v1: 5 and 26).** The builder could not find them as separate parts. D8 is a no-op until Step 2 finds them. The v1 budget numbers (340 to 324) are unverified and dropped.
- **Grass tufts and brown discs.** Not in Plot1/Props (empty). Other folders not confirmed by name. Shown in the screenshot, so they exist somewhere. Step 2 must find them before claiming removal.
- **Wardrobe size.** Only its centre is live. Footprint 4 x 4 is the v1 figure.
- **Board, perch and sign heights.** Only the board's X and Z were reported. Matters for C5 and the camera.
- **Rotations** of the smoker and the sign. Footprints assume axis-aligned.
- **Bud buttons.** Live positions not found (BudButton tag = 0). Not placed.
- **Fence Z 52.** Not measured.
- **Build Mode FOV** and whether the sign hides plates in the top-down view (D9).
- **Harvest and bear distance source.** Assumes NearPosition is measured from the board centre and the bear distance uses plot-local coordinates. Confirm in the script.
- **Live part counts per plot.** The builder gave only the centres and sizes above, not BasePart totals.
- **Tag counts** for LandingBoard, Smoker, GuardPerch, PlotSign, SwarmPerch, WardrobePad: carried from v1, not re-counted in this pass. Re-count in Step 1.
- **Studio state:** this pass did not re-read Studio; figures come from the builder's Edit-mode findings and the baseline file.

---

## 7. Open questions (owner or builder)

1. Are the brown discs and grass tufts in the screenshot inside Plot1 at all? Which folder?
2. Board walkable as a wedge? Slope and Y height?
3. Smoker and sign rotations (footprint assumption)?
4. Bud button names, positions and tags?
5. Build Mode camera FOV, for C5 and D9.
6. Does NearPosition 18 measure from the board centre?

READY FOR REVIEW
