# A Bee's World: Map Expansion for the Honey Obby (addendum)

**Task type:** C-SPATIAL. Spec only. No Studio writes were made.
**Companion to:** architecture_hub_redo_addendum.md section 13 (Honey Obby). This addendum replaces section 13.1 and the section 13.2 footprint. The course design (13.3 to 13.9) is kept.
**Measured:** 2026-10-03, Studio place 123313915411717, Edit DataModel, read-only.

---

## 1. Current extents (measured)

| Item | Measured | What sits at the edge |
|---|---|---|
| Meadow soil (`Map.Meadow.Ground.MeadowSoil`) | 800 x 2 x 170 at (0, -1, -181). X -400..400, Z -266..-96, top Y 0 | East edge X 400: `Outer Walls` Part (403.1, 50.5, -101.6), 4 x 110 x 341, Z -272..69. Corner fillers 3 and 2 at X 402. |
| Meadow props bounds | X -400..400, Z -278.8..70, Y -26.9..60 | Patch15/16 Moonflower at the hub mouth (Z to -279). FireflyJar (54, 1.2, -264). |
| Plot row decks | Plot centres X -325, -195, -65, 65, 195, 325; 110 x 110 decks at Z -55..55 | Plot6 deck X 270..380. Plot6 edge Part at X 270.8. East of Plot6 is open meadow up to the east wall at X 400. |
| Petal Path | `LaneBed_Main` at Z -96..-80; spur X -8..8 from Z -286 to -88 | The path runs east-west across the whole meadow at Z -88. It is a gameplay route and does not move. |
| Hub | Z -406..-266; walkable X -66..70 today (addendum section 3 sets X +-264 later) | South edge invisible wall at Z -402. Hub mouth X -64..67 at Z -266. |
| Outer Walls (other) | Hub west X -262 (Z -335), hub east X 262 (Z -335), south Z -402 (X -264..264 after redo), meadow walls at Z -269 for X -409..-260 and X 260..400, CornerFillers 4/5/6/7/8 near (+-262, -268..-403) | Playable box today: X -400..400, Z -406..+70. |
| Treeline | Extents X -537..530, Z -462..250, Y -32..167. Band at Z 105 (900 wide) plus PerimeterRing pines | Treeline is outside the walls. Pines at Z -386 (ring) are behind the shed. |
| Streaming | `Workspace.StreamingEnabled = true` | The `StreamingTargetRadius` read failed ("not a valid member of Workspace"). The 512 value in architecture.md could not be confirmed live. See owner decision 5. |
| Workspace BaseParts | 1935 (addendum section 1, measured 2026-10-03) | This session's descendant count (3148) includes non-part instances, so it is not used. Re-measure in preflight. |

**Why the planned footprint is blocked (measured, old box X 118..152, Z -262..-2):**
- A 34 x 260 box crosses the Petal Path at Z -88 and the plot row at Z -55..-2. It is not a clearance problem, it is a route conflict.
- A box-part scan found 43 parts. These include Plot4 DeckSlab and DeckRimEast/FrontR, Plot5 DeckSlab, DeckRimWest/FrontL, DeckPlinth, the Plot5 PlotSign (post, board, brace, crest), the Plot5 WardrobePedestal, `PetalPath.LaneBed_Main`, `PathStone18/19`, `PathApronGround`, `Meadow.Ground.PlotRowApron`, the Puddle (surface and rim), `WornTrack2/7`, `FallenPetal10`, and about 30 tufts and blades (decor, movable).
- Ground rays: 25 of 25 hit something, but 11 of 25 are outside Y -0.2..0.2. The old footprint is not a valid obby site in any case.
- The check in 13.2 (check 2) fails. Per 13.2 step 3 the build stops and the owner is asked. This addendum is that ask.

---

## 2. Expansion options

The course needs 260 studs of Z length (Z -262..-2) and 34 studs of width. The only free strip of that length is the meadow east of Plot6 or west of Plot1. The meadow band between the hub and the Petal Path is only 170 deep, so the course cannot be laid along Z there without crossing the path.

### Option A: East extension (RECOMMENDED)
- **Direction and new extents:** east edge moves from X 400 to X 520. The new strip is X 400..520, Z -266..-2 (120 x 264). Playable box becomes X -400..520 at the south-east corner.
- **Perimeter changes (moves only, same Z):**
  - `Outer Walls` Part (403.1, 50.5, -101.6): X -> 520.1. Still 4 x 110 x 341.
  - `Outer Walls` TreelineExtEast (403.1, 50.5, 156): X -> 520.1. Z unchanged.
  - CornerFiller_3 (401.9, 52.5, -269.8): X -> 520.
  - CornerFiller_2 (402.2, 52.5, 242): X -> 520.
  - New south wall Part (460, 52.5, -269), 120 x 110 x 4, Transparency 1, CanCollide true, Anchored. It closes the strip on the south side (the hub's south void is outside the playable box).
- **New ground:** one Part, `Meadow.Ground.MeadowSoilEast`, 120 x 2 x 264 at (460, -1, -134). Top Y 0. Colour and material copied from `MeadowSoil`.
- **What does not move:** all six plots, the hub, the spawn, the PetalPath start and spur, the teleport pads, every gameplay tag, and the Petal Path itself.
- **Obby:** the course is translated +312 studs in X (see section 3). Footprint X 430..464, Z -262..-2.
- **Budget:** +2 parts for the ground and south wall. Moved walls are net 0. Optional +10 meadow tufts (meadow species) and +2 sign parts at the mouth (section 6, decision 3).
- **Streaming:** the obby and the new ground are about 110 studs from Plot6 and about 280 from Plot5, inside the 512 radius if that value is confirmed. Obby models are `ModelStreamingMode = Persistent` (addendum 13.1). The new ground is Default.
- **Risks:**
  - The Petal Path east end is not measured. Preflight E0 must confirm it ends at or before X 400. If it runs past 400, the obby moves to X 470..504 and the east wall moves to 540.
  - The walk from the hub mouth to the obby is about 420 studs (section 4). Players may skip it. Mitigation: a mouth sign (decision 3).
  - Moving the east wall must not open a gap in the existing meadow walls. Preflight E3 sweeps for that.

### Option B: West extension (mirror of A)
- New strip X -520..-400, Z -266..-2. Walls move from X -403 to X -520. Plot1 deck edge is at X -380, so the strip sits behind Plot1.
- Same budget and streaming as A.
- Rejected as the first choice because the hub's west side is the Den, the lookout ruler and the spur sightline sit toward the west half of the meadow. The west walk crosses more hub sightline and the Den's lookout view. It stays the backup if Option A's Petal Path check fails the other way.

### Option C: South beyond the hub (REJECTED)
- Extends the playable box to Z -520 behind the shed.
- Would need the south `Outer Walls` (Z -402) and the PerimeterRing (Z -440 in the redo) removed or moved, and the course would sit behind the shed with no route except through the hub. It touches the Den and shed systems the hub redo is building.

**Recommendation: Option A (East extension).** It moves no plot, hub object, spawn, path start or gameplay tag. It needs 2 new parts and 4 wall moves.

---

## 3. Obby placement in the new land

**Translation:** all 13 platform centres, the checkpoints, respawns, the start and finish anchors, the sign and arch are shifted by **dX = +312, dY = 0, dZ = 0**. Platform sizes, tops and gaps are unchanged.

**Footprint:** X 430..464, Z -262..-2 (34 x 260). Parent folder unchanged (`Workspace.Map.Meadow.HoneyObby`), Persistent.

### 3.1 Platform table (translated, X +312)
| Idx | Old centre | New centre | Top Y | New footprint X |
|---|---|---|---|---|
| 0 start | (135, -250) | (447, -250) | 1.0 | 439..455 |
| 1 J1 | (131, -229) | (443, -229) | 2.5 | 436..450 |
| 2 J2 | (139, -210) | (451, -210) | 4.0 | 445..457 |
| 3 J3 | (131, -191) | (443, -191) | 5.5 | 436..450 |
| 4 J4 C1 | (139, -172) | (451, -172) | 7.0 | 445..457 |
| 5 J5 | (131, -153) | (443, -153) | 8.5 | 436..450 |
| 6 J6 | (139, -134) | (451, -134) | 10.0 | 445..457 |
| 7 J7 | (131, -115) | (443, -115) | 11.5 | 436..450 |
| 8 J8 C2 | (139, -96) | (451, -96) | 13.0 | 445..457 |
| 9 J9 | (131, -77) | (443, -77) | 14.5 | 436..450 |
| 10 J10 | (139, -58) | (451, -58) | 16.0 | 445..457 |
| 11 J11 | (131, -39) | (443, -39) | 17.5 | 436..450 |
| 12 finish | (135, -17) | (447, -17) | 19.0 | 438..456 |

Checkpoints: C1 (451, 7.25, -172), C2 (451, 13.25, -96). Respawns: start (447, 4, -250), C1 (451, 10, -172), C2 (451, 16, -96). Start light (447, 5, -250), finish light (447, 25, -17). Start sign at (447, -250 area, west face). Finish arch centred (447, -17).

### 3.2 Clearance table (new footprint X 430..464, Z -262..-2)
| Object | Clearance | OK? |
|---|---|---|
| Plot6 deck east edge (X 380) | 50 studs in X | Yes |
| Plot6 ramp and deck front (Z -55..55) | Obby at X 430+ does not overlap the plot row X range (ends 380) | Yes |
| Petal Path (Z -96..-80) | Path east end not measured. Must end at or before X 400 (preflight E0) | Pending E0 |
| East meadow wall Part (330, -269), X 260..400 | Obby starts X 430, 30 studs east of the wall end | Yes |
| New south wall (Z -269) | Obby Z min -262 is 7 studs north of the wall | Yes |
| East wall (X 520) | Obby max X 464 is 56 studs inside | Yes |
| FireflyJar (54, -264) and Moonflower patches (X -45..55) | more than 370 studs west | Yes |
| Hub east structures (fence at X 258..260, hive X 194..255) | 170+ studs | Yes |
| Spur (X -8..8) and sightline (X 0) | 420+ studs east | Yes |
| Treeline pines (Z 105 band, ring at Z -386) | 100+ studs | Yes |

### 3.3 Walking route: hub mouth to obby entrance
Start: hub mouth at (30, -266). The Fireweed patch is at (60, -242) and the spur is at X -8..8.
1. (30, -266) north-east to (60, -228). Passes 14 studs north-west of the Fireweed patch at (60, -242). Clear of the spur.
2. East along Z -228 from X 60 to X 420. Crosses the open meadow north of the east meadow wall (Z -269) and south of the plot row (Z -55 and beyond). No Petal Path crossing (Z -88 is 140 studs north of this line).
3. Turn to (440, -240) and step onto the start platform at (447, -250). Walk distance about 420 studs (about 390 for leg 2 plus the diagonal in leg 1).

---

## 4. Part budget

| Group | Parts |
|---|---|
| Current (live, addendum section 1) | 1935 |
| Hub redo net (addendum section 8: 351 planned - 153 now) | +198 |
| Expansion: MeadowSoilEast + south wall | +2 |
| Expansion optional: meadow tufts and mouth sign (decision 3) | +12 |
| Honey Obby (13.7) | +97 |
| **Total, mandatory** | **2232 / 5000 (45%)** |
| **Total, with optional** | **2244 / 5000 (45%)** |

- Moved walls and corner fillers are net 0.
- Lights added: 0 for the expansion. Obby adds 2 (13.7). Emitters: obby adds 1 (13.6). Sounds: 0.
- Streaming cost: the expansion is one 120 x 264 soil slab (Default streaming) and 97 Persistent obby parts. A player at Plot6 is about 110 studs from the obby. Mobile cost is small. If StreamingTargetRadius is 512 (unconfirmed), the obby loads whenever a player is at Plots 4 to 6 or the east meadow. Players at the hub with the obby out of radius see no pop-in because the obby is far from the hub.

---

## 5. Build order and checks

Each step stops on failure. Numbers are Edit-mode checks unless stated.

**E0. Preflight (read-only).**
- Measure `PetalPath` max X. *Check:* max X <= 400. If not, use the alternative X shift 470..504 and east wall X 540 (report, owner decides).
- Measure `StreamingTargetRadius` via the Properties panel (not Luau). *Check:* value recorded.
- Ground: 25 downward rays on the new footprint X 430..464, Z -262..-2, 5x5 grid. *Check:* 25/25 hit MeadowSoil or the new slab with Y in -0.2..+0.2 (the new slab is not built yet, so expect hits on MeadowSoil only at X <= 400: report misses at X > 400 as expected).
- Block scan on the new footprint: `GetPartBoundsInBox` over X 430..464, Z -262..-2. *Check:* 0 BaseParts except new-site decor (zero expected).
- Record `BasePart` count of Workspace. *Check:* 1935 +/- 0 (or the new number, recorded).

**E1. Backup.** Clone `Workspace["Outer Walls"]` and `Meadow.Ground.MeadowSoil` into `ServerStorage.ExpansionBackup_v1`. *Check:* same part count as source (18 Outer Walls parts; 1 MeadowSoil).

**E2. world-builder: east extension.**
- Create `Meadow.Ground.MeadowSoilEast` (120 x 2 x 264 at (460, -1, -134), Y top 0).
- Create the south wall Part (460, 52.5, -269), 120 x 110 x 4, Transparency 1, CanCollide true, Anchored.
- Move the four walls to X 520 (section 2, Option A).
- *Check:* walls at X 520.1 (x2) and CornerFiller_2/3 at X 520 within 0.1; new soil and wall present; `MeadowSoilEast` top Y 0.0 +/- 0.05.

**E3. Perimeter sweep.**
- From (440, 3, -134) cast 64 horizontal rays of 300 studs, evenly spaced around 360 degrees. *Check:* every ray with a direction east (|dirX| > 0.5) hits a `Outer Walls` part or Treeline within 90 studs (east wall at 518..520 is 78..80 studs away). Rays north or south with no wall hit must be within the box Z -266..70, not beyond the treeline.
- Downward ray grid over X 400..520 and Z -266..-2 (41 samples): *Check:* 41/41 hit a ground part at Y -0.05..+0.05 (void seams = fail).

**E4. Obby, translated.** Run 13.8 O1 to O4 with every X value shifted +312 (section 3.1). *Check:* O1: 13 `ObbyPlatform` parts, indices 0..12 once each, tops within 0.05, gaps 6.0 +/- 0.1 along Z. O2: decor count 97 +/- 3, every decor CanCollide false and Anchored. O3: 13 of 13 raycasts correct. O4 is play-mode (see play checks).

**E5. Hash and tag guard (run before and after E2 and E4).**
- Hash every `Workspace.Map.Plots` descendant (name, class, CFrame, Size) and every `Workspace.Map.Hub` descendant. *Check:* hashes identical before and after E2 and E4 (proves no plot or hub move).
- Count BaseParts per tag: `TeleportPad`, `LeaderboardBoard`, `HoneyFountain` (if built), `ObbyPlatform`, `ObbyCheckpoint`, `NightVigilJar`, `PlotRoot`. *Check:* every pre-existing tag count unchanged; `TeleportPad` = 6 with PlotIndex 1..6.
- Count `PatchRoot` or the Patch model count and `PetalPath` stone count (PathStone1..19 plus SpurStone1..10). *Check:* unchanged.

**E6. set-dresser (east strip decor only).** Meadow tufts and two mouth-sign parts, if approved. *Check:* nothing within 3 studs of any platform footprint in XZ; no tuft on the route in section 3.3 (within 5 studs of its centre line).

**E7. Lighting and art review.** Only the obby light anchors and the new ground. *Check:* ClockTime 22 screenshot: all 13 platform tops lit; no PointLight within 3 studs of a mesh.

## 6. Play checks (separate list, Play mode, after E5 passes)
1. Walk the route in section 3.3 from the hub mouth to the start platform. Time it. *Check:* arrival within 45 s at bee walk speed.
2. Clean run: all 12 jumps to the finish. *Check:* progress reaches 12, finish toast, `ObbyBestTime` attribute set.
3. Fall at J6: *Check:* reset to C1 (top 7.0, progress 4).
4. Fall at J9: *Check:* reset to C2 (progress 8).
5. Pads and plots unchanged: step onto one `TeleportPad` (PlotIndex 1). *Check:* teleport fires within 3 s.
6. Walk the new east wall: *Check:* no fall-through at X 518..520, no void at Z -266..-2.

---

## 7. Owner decisions (recommended default in bold)

1. **Expansion direction:** **East extension to X 520 (Option A)**, or West (Option B). Recommended: A.
2. **Wall moves:** move the east walls and corner fillers from X 403 to X 520 and add the south wall at Z -269: **yes**.
3. **Mouth sign and tufts:** a small "HONEY OBBY" sign at the hub mouth and 12 meadow tufts along the route (+12 parts): **yes**. The obby is about 420 studs from the hub, so the sign is the only guide.
4. **Achievement** `obbyFinisher` (addendum 13.6): **yes**.
5. **Streaming radius:** confirm the Workspace `StreamingTargetRadius` value in Studio's Properties panel (not readable by Luau here). Default if unconfirmed: keep the obby Persistent, which is already the plan.
6. **Obby location deviation** (addendum 13.1): the owner confirms that the obby is an east meadow satellite of the hub, reached by a 420-stud walk. This replaces the in-hub option, which the hub redo does not have room for.

---

READY FOR REVIEW
