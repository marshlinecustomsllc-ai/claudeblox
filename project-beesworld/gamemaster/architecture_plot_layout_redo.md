# Plot Layout Redo -- Architecture Addendum

**Task type:** C-SPATIAL (prop relocation, reskin, text) + SYSTEMIC-free. No lattice change, no gameplay logic change.
**Owner ask:** "Redo the layout for the plots. Too crowded. Make sure everything built or made is on theme and makes sense to kids."
**Reference screenshot:** plot close-up showing the gold honeycomb at top, a wooden board reading "HOW TO BUILD A YOUR COMB" at right, a round cream pedestal at right, two round brown discs, grass tufts in the foreground, and the owner name tag ("eXemptAttempt", bee icon, honey "000").
**Measurement basis:** docs (architecture.md World Layout and Part Budget, buglist #19/#20/#27/#81/#85/#90/#92, hub addendum method) plus a partial live Edit-mode read of Plot1. Studio switched to Play mode partway through the reads (Edit reads then failed with "Edit datamodel is not available in Play mode"). Everything marked **[unmeasured]** still needs an Edit-mode read before build.

---

## 0. Headline findings

1. **The front of every plot is already overlapping.** The Landing Board (0,-24, 22x10, footprint Z -29..-19) sits on top of the three front-row lattice plates (their centres at Z -18, radius 7.5, so their edge reaches Z -25.5). Plan-view overlap is about 6.5 studs. The Guard Perches (-20,-26) and Smoker (+8,-24) also touch the front-left and front-right plates. Confirm live (Section 2).
2. **The Plot Sign overlaps the Wardrobe Pedestal and hangs off the deck.** Sign at (-52,-46), 14x10, spans X -59..-45. The deck edge is X -55, and the pedestal at (-46,-48) sits inside the sign's box. [doc coordinates, unmeasured in Edit]
3. **The lattice is wider than the docs say.** Docs quote cell-centre extent X +/-28, Z -18..+30. With the plate radius (7.5) the real footprint is X +/-35.2, Z -25.5..+37.5. Every "clearance" in the old docs was measured from centres and is too small.
4. **Too much text on the plot.** The "HOW TO BUILD" board has a paragraph and a grammar error ("A YOUR COMB"). The bug #19 hint says "Press ? for help", which a 7-year-old cannot act on.
5. **Props in the Props folder are empty; the clutter is in Structures, Signs and the foreground.** Plot1 Props = 0 descendants. The grass tufts and round brown discs in the screenshot are not in Plot1/Props.

---

## 1. Current-state inventory (per plot)

Plot centres X = -325, -195, -65, 65, 195, 325; Z = 0. Deck 110x110, top Y 6.5. Lattice centred local (0,+6). All positions below are plot-local (X, Z) relative to plot centre. Footprints are from the docs unless marked live.

| Object (instance / tag) | Count per plot | Local (X,Z) | Footprint (studs) | Purpose | Live check |
|---|---|---|---|---|---|
| Comb Floor 1 lattice (DimCellPlate, 19 incl. Dance Floor) | 19 | centre (0,+6) | plate d=15; lattice bbox X +/-35.2, Z -25.5..+37.5 | the build grid, the game's core | DimCellPlate tag = 228 total = 6 x 38 (matches) |
| Comb Floor 2 ring | 12 | Y 22.5 | same grid | upper comb | included above |
| Comb Floor 3 disk | 7 | Y 38.5 | same grid | crown comb | included above |
| Landing Board (LandingBoard, WedgeParts) | 1 | (0,-24) | 22x10 | bee launch, HARVEST | tag count 6 (matches) |
| Smoker (Smoker) | 1 | (+8,-24) | 3x5 | bear defence (any player) | tag count 6 (matches) |
| Guard Perch (GuardPerch) | 2 | (-20,-26), (+20,-26) | 6x6 each | guard bee anchors | tag count 12 (matches) |
| Apiary Shed (shop) | 1 | (-42,-30) | 18x16 | shop, cosmetics, glue exchange | **[unmeasured]** |
| Propolis Kiln | 1 | (+42,-30) | 14x14 | resin to glue, steams | **[unmeasured]** |
| Wardrobe Pedestal (WardrobePad tag) | 1 | (-46,-48) | 4x4 | bee skin pick | tag 6 matches; **name tag mismatch**: "WardrobePedestal" tag = 0, "WardrobePad" = 6 |
| Plot Sign (PlotSign) | 1 | (-52,-46) | 14x10 board at Y 14 | owner name, stats, unowned hint | tag count 6 (matches) |
| Bud Button (BudButton) | up to 8 | 11 studs toward -Z from each structure | 4x5 each | buy structure | **BudButton tag = 0**; name not confirmed **[unmeasured]** |
| Swarm Perch (SwarmPerch) | 1 | (0,+44) | 10x6 | prestige, bare branch | tag count 6 (matches) |
| Fence bay / Fence boards | 1 | Z +52 | 60 tall | back boundary | **[unmeasured]** |
| Paw prints | up to 5 | **[unmeasured]** | ~4 each | bear track trail | **[unmeasured]** |
| Wax drips / seam dressing | 26 parts | scattered | small | decoration | **[unmeasured]** |
| Grass tufts (foreground in screenshot) | **[unknown]** | **[unmeasured]** | 14-22 tall | reads as clutter on the deck | Plot1/Props = 0; source not identified |
| Round brown discs (two in screenshot) | **[unknown]** | **[unmeasured]** | ~8 wide | not identified | likely Bud Button or a dish; confirm |
| Round cream pedestal (screenshot) | **[unknown]** | near right side | ~6-8 wide | probably the Wardrobe Pedestal; confirm | see Wardrobe row |
| Owner name tag + honey count (screenshot) | 1 per owned plot | above character, not a plot object | billboard | "who owns this" + honey | leave as is (see Section 3, row N1) |
| Deck slab, rim, ramp | 1 | deck centre (0,0,+6); ramp X 0, Z -80..-55, 14 wide | 110x110 | the ground | Deck folder 10 descendants (live) |
| Comb access (Floor 2/3 columns, WaxSpiralRamp, CombFloorGate) | per floor | spiral (+34,+14) | spiral 9 wide | to upper floors | CombFloorGate tag = 12 (matches) |

**Live Plot1 top-level folders (Edit read, before Play switch):** Deck (10 desc), Structures (70 desc), Signs (90 desc), Props (0 desc), Comb (161 desc). These are descendant counts, not BasePart counts. **[unmeasured]** for per-object sizes inside Structures and Signs.

---

## 2. Crowding measurement

Method follows architecture_hub_redo_addendum.md section 2 (footprint vs floor area, blocked fraction, clearances). Plate radius 7.5 is assumed (plate diameter 15, buglist #26/#27).

### 2.1 Areas (per plot)

| Measure | Value | Basis |
|---|---|---|
| Deck floor | 12,100 sq studs | 110 x 110 |
| Lattice bounding box (incl. plate radius) | ~4,435 sq studs | 70.4 x 63.2; the real hexagon is smaller (~3,000) |
| Front band (Z -55..-25.5, full deck width) | 3,245 sq studs | where the crowding is |
| Props footprint, current (docs) | ~1,190 sq studs | board 220, smoker 15, perches 72, shed 288, kiln 196, wardrobe 16, sign 140, bud buttons ~160, swarm perch 60, paw prints ~20 |
| Props footprint in front band, current | ~1,030 sq studs | 32% of the front band |
| Blocked fraction of whole deck (props + lattice bbox) | ~47% | (4,435 + 1,190) / 12,100; hex-area basis ~35% |
| Walkable open floor outside lattice bbox | ~7,600 sq studs | deck minus lattice bbox |

**Live blocked-fraction raycast grid: [unmeasured]** (Play mode blocked it; run in Edit before build).

### 2.2 Clearances (current, from doc coordinates with plate radius 7.5)

| Pair | Current gap (studs) | Status |
|---|---|---|
| Landing Board front face (Z -29) to front-row plate edge (Z -25.5) | **-6.5 (overlap)** | FAIL |
| Guard Perch (-20,-26) to front-left plate (-13.9,-18) | **overlap at corner** | FAIL |
| Smoker (8,-24) to front-right plate (0,-18) | **touches (~0 gap)** | FAIL |
| Plot Sign (-52,-46) to Wardrobe (-46,-48) | **overlap 3 x 4 studs** | FAIL |
| Plot Sign left edge (X -59) to deck edge (X -55) | **-4 (hangs off deck)** | FAIL |
| Swarm Perch (Z 41) to rear plate edge (Z 37.5) | 3.5 | below 4 |
| Shed (-42,-30) to lattice | ~12 (no overlap) | pass |
| Kiln (42,-30) to lattice | ~6 (no overlap) | pass |

### 2.3 Walk lane and camera

- **Walk lane (ramp to comb):** the ramp top sits at (0,-55). The lane X -7..+7 from Z -55 to the lattice front (Z -25.5) is 14 studs wide. Landing Board, Smoker and two Guard Perches all sit in the lane or beside it, so the approach is cramped. Board is a walkable wedge (verify slope), so the lane stays passable.
- **Harvest reach:** NearPosition 18 from the Landing Board. A player standing on the ramp top (Z -55) is 20 studs from the board centre (-35 after move). They must step 2 studs in. Acceptable; flagged in Section 5.
- **Camera (Build Mode, 45 studs above comb, 80 degrees pitch):** visible half-width depends on FOV **[unmeasured]**. Anything taller than about 12 studs in the front band hides the front row plates in the top-down view.

---

## 3. Kid-theme audit

Rule: every object is bee, honey, wax or meadow themed, and every label is a short plain phrase a 6-8 year old can read. Keep the Warm Wax palette: Propolis Brown #7A4A22, Wax Cream #E8D49A, Pollen Haze, Meadow Green #6FA84A, Alarm Red #D8452B for threats only (the Smoker glow during a raid, nothing else). Honey Gold #F2A81C for honey.

| # | Object | Problem for kids | Action | New version and label |
|---|---|---|---|---|
| A1 | Landing Board | fine, bee-themed | **keep, move** | Landing Pad (no text on the object; prompt says "Collect honey") |
| A2 | Smoker | "smoker" is an adult word | **keep, reskin** | Bee smoker with a small "calm the bear" prompt |
| A3 | Guard Perches | bee-themed | **keep, move** | Guard bee perch, unchanged visually |
| A4 | Apiary Shed | "shop" is not obvious to kids | **keep, reskin** | Honey-yellow shop hut with a SHOP sign (1 word) |
| A5 | Propolis Kiln | "propolis" and "kiln" are unknown words; steam reads as a machine | **reskin + rename** | "Glue pot" with a small pot and a 1-word sign: GLUE. Keep steam puff, the mechanic stays. |
| A6 | Wardrobe Pedestal (round cream pedestal in screenshot) | a generic pedestal with no story | **reskin** | Wax dress-up pedestal with a wax crown on top and a 1-word sign: DRESS UP |
| A7 | Swarm Perch (bare branch) | "swarm" and "prestige" are unknown; a bare branch reads as a dead stick | **keep, reskin label** | "Start a new hive" sign-free; prompt: "Start a new hive" |
| A8 | Plot Sign (wooden "HOW TO BUILD A YOUR COMB") | paragraph of small text, grammar error, too much reading | **reskin + shorten** | One sign only: "Tap a glowing cell to build!" (6 words). Unowned state only. Owned state keeps owner name. |
| A9 | Plot Sign hint line (bug #19: "Press ? for help") | a kid cannot press "?" | **change text** | "Tap a glowing cell to build!" (same as A8, one line) |
| A10 | Bud Buttons (closed buds) | purchase meaning unclear | **keep, reskin** | Bud with a short price tag: "10 honey" (number and honey icon, no word "cost") |
| A11 | Round brown discs (two in screenshot) | unidentified; read as cookies or holes | **identify, then remove or reskin** | If Bud Buttons, reskin as flower buds. If a dish, remove. Default: remove. |
| A12 | Grass tufts on the plot (foreground) | clutter that blocks the comb and reads as "messy" | **remove from deck** | Meadow tufts stay in the Wild Meadow only, never inside a plot deck |
| A13 | Wax drips / seam dressing (26 parts) | fine, but busy | **keep, trim to 10** | Keep only at the deck rim (wax drips), none inside the lattice |
| A14 | Paw prints (up to 5) | bear tracks: on theme, read well | **keep, trim to 3** | Only on the front lane near the ramp |
| A15 | Fence bay boards | very large, not a problem | **keep** | No change |
| A16 | Owner name tag (screenshot: "eXemptAttempt", bee icon, honey "000") | "000" is ambiguous | **reskin number** | Honey pot icon + number, no "000" zero-padding; name stays |
| A17 | Floor 2/3 spiral, columns | on theme | **keep** | No change |
| A18 | Deck base Propolis Brown, lattice Wax Cream | on palette | **keep** | No change |

Plain-words rule for every sign and prompt (applies to all rows): no words "lattice", "propolis", "kiln", "prestige", "bearing", "outer rim", "cost". Use "glowing cell", "glue", "shop", "start a new hive", "honey".

---

## 4. New layout per plot

**Fixed (do not move):** all 19 Floor 1 DimCellPlate positions, all 12 Floor 2 and 7 Floor 3 plate positions, the Royal Cell instances, the WaxSpiralRamp and CombColumn access pieces, the Dance Floor cell (0,0), the deck and ramp, the fence.

**Front band rule:** nothing in Z -55..-25.5 except the Landing Board, Smoker, two Guard Perches, Plot Sign, Shed, Kiln and bud buttons, with the clearances below.

### 4.1 New positions (plot-local)

| Object | Old (X,Z) | New (X,Z) | Footprint | Gap to lattice edge (Z -25.5 / X +/-35.2) | Gap to deck edge | Notes |
|---|---|---|---|---|---|---|
| Landing Board | (0,-24) | **(0,-35)** | 22x10 (Z -40..-30) | 4.5 to front plates | 15 from ramp top | moved, reason: overlap (Section 0.1) |
| Smoker | (+8,-24) | **(+17,-35)** | 3x5 (X 15.5..18.5, Z -37.5..-32.5) | > 4 | fine | 4.5 gap to board edge |
| Guard Perch L | (-20,-26) | **(-26,-35)** | 6x6 (X -29..-23, Z -38..-32) | 6.5 | fine | flanks the board |
| Guard Perch R | (+20,-26) | **(+26,-35)** | 6x6 (X 23..29, Z -38..-32) | 6.5 | fine | symmetric with L |
| Apiary Shed | (-42,-30) | **(-42,-42)** (X -51..-33, Z -50..-34) | 18x16 | 8 | 4 from left edge (X -55) | gap 4 to Guard Perch L |
| Propolis Kiln / Glue Pot | (+42,-30) | **(+42,-42)** (X 35..49, Z -49..-35) | 14x14 | 10 | 6 from right edge | mirror of shed |
| Plot Sign | (-52,-46) | **(+24,-49)** (X 17..31, Z -54..-44) | 14x10 | 16 | 3 from front edge (Z -55 area) | moved to the ramp-side corner, facing the ramp |
| Wardrobe Pedestal | (-46,-48) | **(-46,+10)** (X -48..-44, Z 8..12) | 4x4 | 9 | 7 from left edge | left strip, away from the front, no clutter near the front |
| Swarm Perch | (0,+44) | **(0,+45)** (Z 42..48) | 10x6 | 4.5 to rear plate edge | 2 from fence (fence Z 50) | small move for clearance |
| Bud Buttons (x8) | 11 studs toward -Z from each structure | **8 studs in front of each structure's entrance face** | 4x5 each | >= 4 | >= 3 | each must sit inside the front band or the left/right strips; no bud inside the lattice |
| Paw prints (max 3) | scattered | front lane only, X -6..+6, Z -55..-45 | ~4 each | -- | -- | trim from 5 to 3 |
| Wax drips (max 10) | 26 parts | rim of the deck only | small | -- | -- | none inside lattice |
| Grass tufts | foreground | **none inside deck** | -- | -- | -- | removed |
| Round brown discs | right side (screenshot) | removed (default) or placed as bud (Section 8, D4) | -- | -- | -- | pending identification |

### 4.2 Clearance rules (numeric, checked in Section 9)

- **C1:** any prop footprint to any Floor 1/2/3 plate edge (centre +/-7.5): **>= 4.0 studs**.
- **C2:** prop to prop: **>= 3.0 studs**.
- **C3:** prop to deck edge (X +/-55, Z -55..+55): **>= 3.0 studs**, nothing off the deck.
- **C4:** walk lane X -7..+7, Z -55..-25.5: no non-walkable collidable prop. Landing Board is walkable (verify slope); the lane is clear otherwise.
- **C5:** front-band props (Z -55..-25.5) max height **12 studs** (so the top-down Build Mode view still shows the front plates).
- **C6:** every DimCellPlate, CombColumn, WaxSpiralRamp and gate keeps its CFrame exactly. Check by hash before and after (Section 9).

### 4.3 Resulting composition (focal hierarchy)

- **Focal point 1:** the gold comb (lattice + Floor 2/3). Unchanged.
- **Focal point 2 (single sign):** the Plot Sign at (+24,-49) reads "Tap a glowing cell to build!" when unowned. Only one sign on the plot.
- **Interaction point:** the Landing Board at the front centre, with the honey light (existing SpotLight).
- The front band has 6 objects. Before: 8 objects with overlaps. After: 6 objects, all clear.
- Open floor after: ~7,600 sq studs outside the lattice, with ~650 sq studs of props (down from ~1,190).

---

## 5. Gameplay-critical rules

These do not move unless this spec says so, and the spec gives the reason.

| Item | Rule | Status in this redo |
|---|---|---|
| Floor 2/3 gate parts (CombFloorGate x 12, CombColumn, WaxSpiralRamp) | do not move, do not re-tag | unchanged |
| Teleport / plot-owner tags (TeleportPad x 12, PlotRoot, OwnerUserId attribute) | do not move, do not re-tag | unchanged |
| Royal cell (RoyalCapsule 12.7 studs, RoyalTip, RoyalCollar) | **do not re-flip, do not re-orient**, do not move. Buglist #81 flipped it and #90 reverted. Upright assembly spans Y 7.2..21.2 (live-verified in #90). | unchanged |
| GuardPerch positions | **moved** (reason: overlap with front plates, Section 0.1). Move with PivotTo, keep Y and rotation identical to the template. Keep 2 per plot. | moved to (-26,-35), (+26,-35) |
| Smoker | **moved** (reason: touches front plate). Keep upright (buglist #85). Keep within 30 studs of the bear entry. | moved to (+17,-35) |
| Landing Board / harvest | **moved** (reason: overlap). HARVEST uses NearPosition 18 from the board; the board centre moves 11 studs further out. Player at the front face is 6 studs away; ramp top is 20 studs away and needs 2 studs of walking. Acceptable. | moved to (0,-35) |
| Plot sign "how to build" | the sign is the one place a kid reads how to build. Keep it on the plot, one sign, short text. Full help stays in HelpGui (? key). | moved to (+24,-49), text shortened |
| Plot Sign owner stats (SurfaceGui attributes) | unchanged | unchanged |
| Bud Button prompts (ItemId, Cost, Requires attributes) | unchanged; text prompts only | unchanged |

**Tag-name note (must resolve before build):** DanceFloor tag = 0 and BudButton tag = 0 in the live Edit read, and WardrobePedestal = 0 while WardrobePad = 6. Do not rename tags in this redo; confirm which name the scripts read and set the spec to that name. [unmeasured]

---

## 6. Part budget per plot, before and after

Based on the Part Budget table in architecture.md (max-tier plot = 340).

| Element | Before | After | Change | Reason |
|---|---|---|---|---|
| Deck slab, rim, ramp | 8 | 8 | 0 | |
| Fence bay backdrop | 10 | 10 | 0 | |
| Comb Floor 1 (19 cells + content) | 88 | 88 | 0 | lattice fixed |
| Comb Floor 2 | 70 | 70 | 0 | |
| Comb Floor 3 | 46 | 46 | 0 | |
| Landing Board + entrance + Smoker | 12 | 12 | 0 | moved only |
| Guard Perches x 2 | 8 | 8 | 0 | moved only |
| Apiary Shed (reskin) | 16 | 16 | 0 | reskin only |
| Propolis Kiln / Glue Pot (reskin) | 14 | 14 | 0 | reskin only |
| Swarm Perch | 7 | 7 | 0 | moved only |
| Plot Sign | 3 | 3 | 0 | text changed |
| Bud Buttons x 8 | 24 | 24 | 0 | placement only |
| Wardrobe Pedestal (reskin) | 3 | 3 | 0 | moved + reskinned |
| Paw prints | 5 | 3 | -2 | Section 4.1 |
| Wax drips / seam dressing | 26 | 10 | -16 | Section 4.1 |
| Grass tufts / round brown discs (if identified as clutter) | 0 in doc; unknown live | 0 | **[unknown, confirm]** | removed |
| **Max-tier plot total** | **340** | **324** | **-16** | |
| **Empty plot (launch)** | 91 | 91 | 0 | empty plot has no wax drips |

**Totals:**
- Six plots at max tier: 2,040 before, **1,944 after** (-96).
- Server at launch (six empty plots): 1,699 before, **1,699 after** (unchanged).
- Server worst case (six maxed): 3,193 before, **3,097 after**.
- Live counts for Plot1 were not usable (Structures 70 desc, Signs 90 desc, Comb 161 desc are descendant counts). Re-count in Edit before build (Section 9 check 1).

---

## 7. Plot content, text and labels (plain words)

| Where | Text (kid-level) | Notes |
|---|---|---|
| Plot Sign, unowned | "Tap a glowing cell to build!" | the one hint, 6 words |
| Plot Sign, owned | owner name, honey per minute (existing) | unchanged format |
| Shop hut | SHOP | 1 word |
| Glue pot | GLUE | 1 word; help text says "bee glue" |
| Dress-up pedestal | DRESS UP | 1-2 words |
| Swarm branch prompt | "Start a new hive" | |
| Smoker prompt | "Calm the bear" | |
| Landing Board prompt | "Collect honey" | existing text if already simple; otherwise this |
| Bud price | "10 honey" (icon + number) | not "Cost" |
| Owner tag | honey pot icon + number | no "000" |

No text inside the lattice. No text on the deck except the one sign.

---

## 8. Owner decisions (each with the recommended default)

| # | Decision | Recommended default |
|---|---|---|
| D1 | Move the Landing Board 11 studs toward the front (to Z -35) to clear the comb? | **Yes.** Otherwise the board overlaps the comb and the 4-stud rule fails. |
| D2 | Remove grass tufts from inside the plot decks? (meadow tufts stay outside) | **Yes.** They block the comb and read as clutter. |
| D3 | Shorten the plot sign to one line ("Tap a glowing cell to build!") and delete the paragraph? | **Yes.** Full help stays in the ? help screen. |
| D4 | The two round brown discs: remove, or reskin as flower buds? | **Remove** unless identification shows they are Bud Buttons. If Bud Buttons, reskin as flower buds. |
| D5 | Rename "Propolis Kiln" in-world to "Glue Pot" (keep "Propolis" in the help text)? | **Yes.** Kids know "glue". |
| D6 | Wardrobe Pedestal: keep on the plot (left strip), or move to the hub? | **Keep on the plot**, left strip at (-46,+10). Moving it changes a gameplay flow the owner has not asked to change. |
| D7 | Cut paw prints from 5 to 3, and wax drips from 26 to 10? | **Yes.** Decoration only, no gameplay effect. |
| D8 | Keep the two guard perches flanking the board, or move them to the lattice corners? | **Flank the board** at (+/-26,-35). Keeps the "guards visible at the front" read. |

---

## 9. Build order (Edit mode only, after the QA play run and the hub build finish)

Do not start, stop or switch Play mode during these steps. If Studio goes into Play mode, stop and wait.

1. **Baseline read (Edit, read-only).** Record for Plot1..Plot6:
   - a hash of every DimCellPlate, CombColumn, WaxSpiralRamp, CombFloorGate CFrame and size;
   - each prop's CFrame, size and rotation (Structures and Signs folders), with BasePart counts;
   - the Royal Cell assembly Y range. **Check:** Y 7.2..21.2 on Plot1 rim plate (q=0, r=-2).
   - Tag counts (must match: DimCellPlate 228, LandingBoard 6, Smoker 6, GuardPerch 12, PlotSign 6, SwarmPerch 6, WardrobePad 6, CombFloorGate 12, TeleportPad 12).
2. **Confirm unknowns.** Identify the round brown discs, the cream pedestal, the grass tufts and the Bud Button names. Check the Landing Board slope (walkable). Check the FOV for the Build Mode camera. Record each as a finding.
3. **Move the gameplay-critical props with PivotTo**, preserving each template's rotation and Y: Landing Board to (0,-35); Smoker to (+17,-35); GuardPerch L/R to (-26,-35) and (+26,-35); SwarmPerch to (0,+45). Do not rebuild these instances.
4. **Move the other props** with PivotTo: Shed (-42,-42); Kiln/Glue Pot (+42,-42); Plot Sign (+24,-49); Wardrobe (-46,+10). Adjust Bud Buttons to 8 studs in front of each entrance face.
5. **Remove** grass tufts inside each deck, the round brown discs (unless D4 says reskin), wax drips above 10 and paw prints above 3.
6. **Reskin text only** (SurfaceGui/BillboardGui text fields and ProximityPrompt ActionText). Do not change script source, attributes or tags. Sign text per Section 7.
7. **Numeric checks (all must pass):**
   - **Check 1, counts:** per plot, BasePart count matches the Section 6 "after" column within +/-5. Total six plots max-tier target 1,944 (+/-30).
   - **Check 2, C1:** for every prop footprint, the distance to every plate edge (centre +/-7.5) is >= 4.0 studs. Zero violations.
   - **Check 3, C2:** no prop pair closer than 3.0 studs.
   - **Check 4, C3:** every prop inside the deck (X -55..+55, Z -55..+55) with >= 3.0 studs to the edge.
   - **Check 5, C4:** walk lane X -7..+7, Z -55..-25.5 has no non-walkable collidable prop.
   - **Check 6, C5:** front-band props have Y height <= 12 studs above Y 6.5.
   - **Check 7, C6:** lattice and access CFrames hash-equal to baseline. Royal Cell Y 7.2..21.2 unchanged.
   - **Check 8, tags:** tag counts unchanged from baseline (see step 1).
   - **Check 9, anchoring:** every prop Anchored = true, CanCollide = false, except the Landing Board wedge, Smoker and guard perches as they are now (keep existing values).
   - **Check 10, harvest:** a point 6 studs in front of the board's front face is within NearPosition 18 of the board centre. Ramp top is 20 studs away (accepted; the player walks 2 studs).
   - **Check 11, text:** no sign or label on a plot contains the words lattice, propolis, kiln, prestige, cost or outer rim. Plot sign text matches Section 7 exactly.
   - **Check 12, one sign:** each plot has exactly one PlotSign text board visible while unowned.
8. **Report** the check results as a table with PASS/FAIL. Any FAIL goes back to the step that owns it. Do not move on with a FAIL.
9. **Later (not in this spec):** Play-test after the hub build, and the computer-player run.

---

## 10. Risks

- **Landing Board move changes the harvest approach.** Mitigated by check 10. If playtest shows players cannot reach the board, move the board back to (0,-30) (clearance 0.5, but still clear of the plate by the 4-stud rule only if the front plates are the only overlap; re-check).
- **Plot Sign move may read as "far away" from the ramp.** Sign at (+24,-49) is about 24 studs from the ramp top. Check visibility from (0,-55) in Edit view.
- **Unidentified objects (round brown discs, grass tufts) may belong to another system.** Confirm in step 2 before removing anything.
- **Tag-name mismatch** (WardrobePad vs WardrobePedestal, DanceFloor and BudButton tag = 0) may hide a script dependency. Do not rename anything in this redo.
- **Doc corrections:** architecture.md lattice extent (X +/-28, Z -18..+30) is centre-only. Update it to the plate-inclusive bounds (X +/-35.2, Z -25.5..+37.5) when this is implemented. Do not change any other doc value.

---

## 11. Open questions

1. Are the round brown discs Bud Buttons, dishes or something else? (Section 8 D4)
2. What is the exact name and tag of the Wardrobe Pedestal (WardrobePedestal or WardrobePad)?
3. What is the Landing Board's real slope and Y (is it walkable as a wedge)?
4. Build Mode camera FOV, to finalise the 12-stud front-band height limit.
5. Does any script depend on the Smoker or Landing Board world position beyond the 30-stud bear proximity and 18-stud harvest range?

READY FOR REVIEW
