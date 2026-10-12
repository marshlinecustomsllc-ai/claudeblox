# Apiary Yard Redo ("The Big Yard") -- Architecture Addendum

**Task type:** C-SPATIAL. Two required constant edits in one client script, plus two optional client-only controllers.
**Decision followed:** HYBRID. The live Apiary Yard and every working system in it stay. The yard gets 3.7x more floor, gets reorganised into five readable zones, and picks up the good cloud ideas, rebuilt to fit this game's scale and palette rules.
**Authority for tone:** architecture.md, Zone: Apiary Yard: "the corner of a human's garden shed and the human has been gone a long while", comedy of scale, "dense and absurd", "the only always-warm place".
**Measured live:** 2026-10-03 in Studio, place 123313915411717, Edit DataModel, read-only. Every "current" number below was measured, not taken from docs.

---

## 1. Current-state inventory (live)

### 1.1 Envelope
| Item | Live value |
|---|---|
| `Workspace.Map.Hub` | 153 BaseParts (game total 1935) |
| `Hub.HubFlagstones` | Cobblestone `#9A9384`, Size (140, 2, 140) at (0, -1, -336), covering X -70..70, Z -406..-266 |
| Invisible walls (`Workspace["Outer Walls"]`, a Model at Workspace root, **not** under Map) | Hub west wall at X -72 and east wall at X +72 (each 4 x 110 x 138, Z -404..-266). South wall at Z -402 (X -71..73). Meadow south walls along Z ≈ -270 for X -409..-68 and X 73..400. Corner fillers 4/5/6/7 at (±70..72, -268) and (±72, -403). |
| Walkable interior | X -66..70 (the shed return boards sit at X -68) by Z -394..-266 (shed front face at -394), which comes to **about 17,900 sq studs** |
| Hub mouth to the meadow | X -64..67 at Z -266 (131 wide), between corner fillers 7 and 4 |
| Petal Path spur | `PetalPath.LaneBed_HubSpur`, X -8..8, Z -286..-88. Ten SpurStones. SpurStone1 at (-2.3, 0.4, -275.6), 14 wide |
| PerimeterRing pines (`Treeline.PerimeterRing`) | Trunk and canopy pairs at Z -386, X = ±135, ±240, ±335, ±430. The ±135 and ±240 pairs fall inside the new yard. |
| Meadow neighbours at the edge | Patch15 Moonflower: X -45..-15, Z down to -275.8. Patch16 Moonflower: X 25..55, Z down to -278.8. **FireflyJar** (VigilService secret, tag `NightVigilJar`) at (54, 1.2, -264). |

### 1.2 Objects and the systems that depend on them
| Object (live path) | Live position | Depends on it | How it is found (must survive the move) |
|---|---|---|---|
| `Hub.SpawnLocation` | (0, 1.5, -336), 12x12, Neutral | Engine default spawn. PlotService then teleports assigned players to their RampTopSpawn | Any SpawnLocation |
| `Hub.Gateways.PlotGateway1..6`, each holding TeleportPad, GatewayPost, GatewaySign and GatewayCrown | Pads at Z -286, X = -58, -34.8, -11.6, 11.6, 34.8, 58 (14x14). Posts, signs and crowns 6 studs south of each pad (Z -292). Each pad has a PadGlow PointLight (R16, B0.8) | `PlotService.setupTeleportPads` (server Touched, 3s cooldown, then `GetRampSpawnPosition`) | Tag `TeleportPad` plus attribute `PlotIndex` (1..6). Position does not matter. |
| `Hub.Structures.GlobalLeaderboard` (8 parts) | Board (-34, 18, -382), 26x20, tilted -6 deg. SurfaceGui on Face **Back** (bug #74) | `LeaderboardService.setupBoardDisplay`, `HoneyLeaderboardBoardSkin` | **Hard path** `Map.Hub.Structures.GlobalLeaderboard.LeaderboardBoard`, plus tag `LeaderboardBoard` |
| `Hub.Structures.HubBell` (5 parts) | ThimbleBell (16, 32, -382), post (30, 21, -382). Holds the `Ambient_ThimbleBell` Sound | `HubBellController` (rings on ThreatEvent and TimeWeather) | **Hard path** `Map.Hub.Structures.HubBell.ThimbleBell`. The rest CFrame is captured at client Init, so moving the bell in Edit mode is safe. |
| `Hub.Structures.ShedCorner` (25 parts) | 12 ShedBoards at Z -396 (X -64..63.6, step 11.6, 90 tall). 5 ShedReturnBoards at X -68. EaveBeam (146 long, Y 89). Overhang (150 long, Y 93). **Lantern A** (housing, bulb, chain) at (-30, 19..90.5, -372). **Lantern B** at (-54, 19..92, -384). EaveLight PointLights #FFCE8A, R45, B1.4, Shadows=true | `VfxController` hardcodes `EAVE_POINTS = {(-54,19,-384), (-30,19,-372)}` | Hardcoded coordinates (see section 6) |
| `Hub.Props.BeekeepersDiary` (4 parts, PrimaryPart DiaryCover, holds DiaryPrompt) | (43, 0.4, -321.5), beside the boot | `DiaryService` (achievement curiousBee and skin Lantern Gold) | Tag `BeekeepersDiary`, PrimaryPart, and `Validator.NearPosition` against the live part position. **ModelStreamingMode = Default** (every other hub model is Persistent; a bug #29 pattern, fixed in this pass) |
| VfxController hub zone box | `HUB_MIN (-70,-40,-406)`, `HUB_MAX (70,140,-266)` | Pollen drift and eave-dust visibility | Hardcoded |
| Props with no script dependency (verified by grepping every script source) | Watering can, hive boxes, boot, seed packet and seeds, matchbox, crate, hose coil, glove, bucket, saucers, pots 1-3, shards, bricks, nails, trowel, moss, weeds | none | Free to move |

`HumanWorldAmbientAnchor` (mower sound) is at (0, 70, 300). It is not in the hub and is unaffected.

**Sound budget is full:** 24 Sound objects in the game against a cap of 25. **This redo adds zero Sound objects.**

---

## 2. Why it reads cramped (measured)

- **Footprint overload.** The real world-space bounding boxes of the hub's contents add up to **about 27,000 sq studs on a walkable floor of about 17,900, which is 151%**. The biggest are the watering can at **105 x 74** (rotated -24 deg, so its box is much bigger than the 70-long mesh), the hive boxes at 60 x 58 x 81 tall, the hose coil at 52 x 52, and the bucket at 41 x 41. Things overlap or poke through the walls: the hive boxes reach X 80.9, past the east wall at 70, and Z -400.2, behind the shed. The hose coil reaches X -82, past the west wall.
- **No room to stand.** A 1-stud raycast grid over the hub finds **30.1% of the floor blocked** by collidable objects lower than 7 studs, and **56.1% covered from above** by some prop. The largest clear circle inside the yard has radius 20.4. Measured clearance: **1.9 studs** where a player would stand to read the leaderboard (-34, -372), **4.5 studs** at the outer gateway pads, **2.9 studs** at the diary, and 11.9 at spawn.
- **Six portals jammed into one row.** The 6 pads sit 23.2 studs apart (only 9 studs between pads) on one row 20 studs inside the mouth.
- **Crowding keeps causing bugs.** Bugs #42 (bricks overlapping a pad and poking through the shed), #46 (the can and boot cut into gateways, with no walkable path from spawn to the pads), #48 (a lantern buried inside the hive mesh), #50 (two meadow patches sitting inside the hub) and #74 (leaderboard facing the shed wall 12 studs away) all come from too much content in a 140 x 140 box.

The fix is more floor plus a few clear lanes, not fewer props. The architecture asks for "dense and absurd".

---

## 3. Proposed layout

### 3.1 Envelope (new)
- **Hub ground:** X **-264..+264**, Z -406..-266 (528 x 140). This is 3.7x the current floor. Walkable interior: X -256..256 by Z -394..-266, which is **65,536 sq studs**.
- **Inside the outer perimeter:** the world box is X ±400. The southernmost line stays at the existing hub south edge (ground Z -406, invisible wall Z -402). Nothing moves south of the current boundary.
- **Why 528 and not 400:** at 400 wide, the den, the watering can (105 wide) and the hive (60 wide) cannot share the shed line, and the den ends up sealed off (I tested this layout). At 528, every hero object gets at least 6 studs of clearance and a walkable lane.
- **North edge:** stays open to the meadow, like today. Giant terracotta garden-edging bricks (5 studs visible, so kids can hop over) run along Z -271 at X -204..-52 and X 64..254. The **central mouth X -52..64 stays open**, framed by the two Moonflower patches and the FireflyJar.
- **West edge:** the shed's side wall (planks, 90 tall). **East edge:** a giant garden fence (60 tall, matching the scale-reference fence board). **South:** the shed's back wall, extended to the full width.

### 3.2 Plan view (north is up; 1 column is about 16 studs; rows not to scale)
```
Z -266 ~~~~~~~~~~~~~~~~~~~~~~~~~~ WILD MEADOW (open edge) ~~~~~~~~~~~~~~~~~~~~~~~~~
       W|  ruler foot    ==edging==========    .MF15. ARCH .MF16.  jar  ==edging===|F
Z -271 W|   |                                  (spur)  /\                ( HOSE  )|F
Z -290 W|   |      Wlamp   [G1]  [G2]  [G3]     |    |    [G4]  [G5]  [G6]  BOOT (coil)|F
Z -308 W|   |                glove    LABEL   SPAWN           brk pkt         |F
       W|  /|\  |                  NWcap      NEcap  pot3        bucket       |F
Z -337 W| [DEN MOUTH]   WATERING CAN     W  (HONEY JAR) E          Elamp  HIVE |F
       W| [  POT  ]     (105 x 74)      SWcap  plinth SEcap                 BOXES|F
Z -372 W| [  DEN  ]  D-lamp   pot1 pot2  A-lamp [BOARD] B-lamp bell  C-lamp crate|F
Z -394 W|SSSSSSSSSSSSSSSSSSSSSSSSSSSSSS[WINDOW]SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS|F
       X -256     -150        -60        0         +60      +150        +256
W = shed side wall (planks)   F = garden fence   S = shed back wall   A/B/C/D = eave lanterns
```
**Sightline axis:** spur, then cane arch, spawn, honey-jar fountain, leaderboard, lit window. One straight line on X = 0.

### 3.3 Zones (exact footprints)

| Zone | Footprint | Contents | CHARACTER | LIFE (all existing or static; no new sound) |
|---|---|---|---|---|
| **Z1 Gateway Terrace** | X -112..112, Z -297..-266 | 6 gateways, cane arch, edging | Porch steps of the human world. Six signposts point home. | Pad glow (existing). A pad lights when stepped on (existing). |
| **Z2 Saucer Square** | X -60..60, Z -300..-370 | Spawn, Honey Jar Fountain on the saucer stack, 6 bottle-cap stools, weather plant-label | The town square. Warm, open, the one place built for standing around. | Honey drip particles (optional controller). Eave dust (existing VfxController). |
| **Z3 Shed Front** | X -60..130, Z -370..-394 | Leaderboard, bell, **lit window**, lanterns A/B/C, matchbox, diary | The human's back door. The light is still on and nobody is home. | Bell sway and chime (existing). Raid: the bell rings 3 times (existing). |
| **Z4 Potting Corner** (west) | X -256..-60, Z -266..-394 | **Flowerpot Den**, yardstick lookout, watering can, pots 1-2, glove, west lantern | A gardener's corner tipped over and abandoned. Terracotta and spilled soil. Cosy. | Den glow. Can spout puddle (existing part). |
| **Z5 Old Hive Row** (east) | X 60..256, Z -266..-394 | Hose coil (climbable), boot, seed packet and seeds, bucket, crate, hive boxes, pot 3 and bricks (stay), east lantern | Where the real bees used to live. Stacked, mossy, absurd. | Existing only |

---

## 4. Existing objects: stay, move, remove

**Method for every move:** `PivotTo(GetPivot() + Δ)` on Models. For loose parts, apply the **same Δ to each listed part** (or first group them into a Model with the name given, ModelStreamingMode = Persistent, then pivot). **Translation only. No rotation changes.** Keep every name and parent folder unchanged; scripts find the leaderboard and bell by path. Positions are world bounding-box centres (XZ) unless marked "pivot".

| # | Object | Current (measured) | Δ (X, Y, Z) | New |
|---|---|---|---|---|
| 1 | PlotGateway1 (model) | pad (-58, -286) | (-47, 0, -4) | pad **(-105, 0.5, -290)** |
| 2 | PlotGateway2 | pad (-34.8, -286) | (-34.2, 0, -4) | pad **(-69, 0.5, -290)** |
| 3 | PlotGateway3 | pad (-11.6, -286) | (-21.4, 0, -4) | pad **(-33, 0.5, -290)** |
| 4 | PlotGateway4 | pad (11.6, -286) | (+21.4, 0, -4) | pad **(33, 0.5, -290)** |
| 5 | PlotGateway5 | pad (34.8, -286) | (+34.2, 0, -4) | pad **(69, 0.5, -290)** |
| 6 | PlotGateway6 | pad (58, -286) | (+47, 0, -4) | pad **(105, 0.5, -290)** |
| 7 | GlobalLeaderboard (model) | board (-34, 18, -382) | (+34, 0, 0) | board **(0, 18, -382)**, still Face Back |
| 8 | HubBell (model) | thimble (16, 32, -382), post (30, 21, -382) | (+34, 0, 0) | thimble **(50, 32, -382)**, post (64, 21, -382) |
| 9 | Lantern A (EaveLampHousing, EaveBulb, EaveLampChain at X -30) | (-30, -372) | none | **stays** |
| 10 | Lantern B (the same 3 parts at X -54) | (-54, -384) | (+84, 0, +12) | **(30, -372)**. Then set the chain to Size (61.8, 0.6, 0.6), Position Y 59.6 (same as A's chain) |
| 11 | ShedReturnBoard x5 | X -68, Z -390..-343.6 | (-190, 0, 0) | X **-258** |
| 12 | ShedBoard x12, ShedEaveBeam, ShedEaveOverhang | X -64..63.6 | none | stay. Beam Size.X 146 -> **516**, Overhang Size.X 150 -> **520** (positions unchanged) |
| 13 | SpawnLocation | (0, 1.5, -336) | (0, 0, +20) | **(0, 1.5, -316)** |
| 14 | HubFlagstones | Size (140, 2, 140) | resize | Size **(528, 2, 140)**, Position (0, -1, -336) |
| 15 | ToppledWateringCan (model, includes SpoutDripPuddle) | box X -69.4..35.5, Z -355.5..-281.7 | (-133.05, 0, -38.4) | box **X -202.45..-97.55, Z -393.9..-320.1**. Puddle -> (-113.05, 0.1, -369.4) |
| 16 | HumanHiveBoxes (model) | box X 20.7..80.9, Z -400.2..-342.2 | (+174.1, 0, +6.1) | box **X 194.8..255.0, Z -394.1..-336.1** |
| 17 | AbandonedBoot (model) | centre (32.2, -315.55) | (+142.8, 0, +15.55) | **(175, -300)**, box X 159..191, Z -320..-280 |
| 18 | BeekeepersDiary (model) | (43, 0.4, -321.5) | (+57, 0, -68.5) | **(100, 0.4, -390)**: tucked between the matchbox and the shed, 12 studs from lantern C. This makes Config's unlock text ("by the shed eave light") literally true. Set **ModelStreamingMode = Persistent**. |
| 19 | SeedPacketProp + SpilledSeed1..8 | packet (-53.85, -297.85) | (+193.85, 0, -20.15) | packet **(140, -318)** |
| 20 | GiantMatchbox (model) | (44.4, -345) | (+73.6, 0, -36.5) | **(118, -381.5)** |
| 21 | Crate group: CrateBase, CrateSideA..D, CrateMoss, CrateSlatLoose (group as Model "OldCrate") | (-6, -378) | (+158, 0, +1) | **(152, -377)** |
| 22 | HoseCoil0..5 (group as "HoseCoil") | (-56, -322) | (+285, 0, +22) | **(229, -300)**, box X 203..255, Z -326..-274 |
| 23 | GlovePalm, GloveFinger0..3 (group as "GardenGlove") | (-34.1, -328) | (-45.9, 0, +10) | **(-80, -318)** |
| 24 | BucketBody, BucketRim, BucketHandle (group as "TippedBucket") | (20, -356) | (+80, 0, +14) | **(100, -342)** |
| 25 | Saucer1..4 (group as "SaucerStack") | (-16, -310), **floats 2 studs off the ground (found live)** | (+16, **-2**, -34) | **(0, -344)**, Saucer1 resting on the ground. Becomes the fountain plinth (top Y 7.5). |
| 26 | Pot1, Pot2, Pot3 groups, PotShard1..5, Brick1..2 | as measured | none | stay |
| 27 | GiantNail1..4, TrowelHandle/Shaft/Blade | in the old centre | n/a | **REMOVE (7 parts).** Low clutter under 2 studs tall. They sat in the new fountain and plaza lanes and do not read in a yard 3.7x bigger. |
| 28 | HubMoss1..6, CrackWeed1..12 | scattered | n/a | **Re-scatter** (set-dresser step). Same parts, new positions along wall bases and flagstone seams. No new zone may be overlapped. |
| 29 | PerimeterRing Trunk+Canopy at X ±135 and ±240 (8 parts) | Z -386 | (0, 0, -54) | Z **-440**, behind the shed (pines now rise over the roofline) |
| 30 | Outer Walls: Part at X -72 / Part at X +72 | X ±72 | move | X **-262 / +262** (size unchanged, Z -404..-266) |
| 31 | Outer Walls: south Part (1, 52.5, -402) | 144 long | resize | Position (0, 52.5, -402), length **528** |
| 32 | Outer Walls: west meadow Part (-238.3, 50.5, -270.9), 341 long | X -408.8..-67.8 | resize | **X -408.8..-260**: length 148.8, centre X -334.4, same Z and yaw |
| 33 | Outer Walls: east meadow Part (236.5, 52.5, -269), 327 long | X 73..400 | resize | **X 260..400**: length 140, centre X 330 |
| 34 | CornerFiller_7 / _4 / _6 / _5 | (-69.9,-268.2) / (72.5,-268.2) / (-71.5,-403) / (72.5,-403) | move | (-262,52.5,-268.2) / (262,52.5,-268.2) / (-262,52.5,-403) / (262,52.5,-403) |

Gateways: pads keep their spacing at 36 (22 studs between pads), and the central lane between G3 and G4 is **52 studs wide** (X -26..26) for the 16-wide spur. All 6 pads are within 105 studs of the spur.

---

## 5. New construction (world-builder)

All new Models: Anchored, ModelStreamingMode = Persistent. New folders under `Workspace.Map.Hub`: `Den`, `Fountain`, `Entrance`, `Signage`, `Lookout`, `Lights`, `Boundary`. Shed extensions and lantern clones go **inside `Structures.ShedCorner`**.

| Element | Spec | Parts |
|---|---|---|
| **Shed back wall extension** | 32 more ShedBoards (clone the existing ones: Size (11.4, 90, 4), WoodPlanks `#8A6236`, Z -396, Y 45, alternating Z-rotation ±0.3). Centres X = -64 - 11.6k and 63.6 + 11.6k for k = 1..16 (X -249.6 .. 249.2) | 32 |
| **Shed side wall** | 6 more ShedReturnBoards at X -258, Z = -332, -320.4, -308.8, -297.2, -285.6, -274 (cloned) | 6 |
| **East garden fence** (`Boundary`) | 11 boards: WoodPlanks `#8A6236`, Size (4, 60, 11), X 258, Y 30, Z = -388.5 + 12k (k = 0..10). 2 rails: Wood `#7A4A22`, Size (3, 4, 124), at (260.5, 15, -330) and (260.5, 45, -330), **outside** the fence so they never touch the hive | 13 |
| **Lit window** ("the light is still on") | On the shed front face, centred (0, 60, -393). Frame (Wood `#7A4A22`, Z -393): top (40, 3, 2) at Y 75.5, bottom (40, 3, 2) at Y 44.5, sides (3, 34, 2) at X ±18.5. Mullions (1.5, 28, 1) and (34, 1.5, 1) at Z -393.2. Glass (34, 28, 0.5), Glass `#FCEFC6`, Transparency 0.35, Z -393.6, CanCollide false, with a **SurfaceLight on Face Back**: `#FFD89B`, Brightness 1.2, Range 40, Angle 75. Dark backing (34, 28, 0.4) WoodPlanks `#3A2A1E` at Z -393.95. Sill (44, 2, 5) at (0, 42.5, -391.5) | 9 |
| **Lanterns C and D** | Clone Lantern A (housing, bulb, chain; identical properties, EaveLight #FFCE8A R45 B1.4 Shadows true) to X **+88** and **-88**, Z -372 | 6 |
| **Flowerpot Den** (`Den`) | A giant terracotta pot lying on its side, mouth facing north. Axis centre **(-232, 22, -364)**, axis along Z, length 50 (Z -389..-339). **12 staves:** Concrete, colour = PotBody1 (`#A86848`), Size (11.8, 2, 50), `CFrame = CFrame.new(-232,22,-364) * CFrame.Angles(0,0,-math.rad(θ)) * CFrame.new(0,21,0)` for θ = 0, 30 .. 330. **12 rim segments:** Size (12.6, 3, 4), same formula with centre Z **-339** and offset 22.5 (rim spans Z -341..-337). **Base disc:** Cylinder (2, 44, 44), Orientation (0, 90, 0), at (-232, 22, -389). **Drain hole:** Cylinder (2.2, 6, 6), `#3A2A20`, same position. **Soil floor:** Ground, colour = PotSoil1, Size (26, 3, 46) at (-232, 1.5, -364), top at Y 3. **Spill ramp:** WedgePart (16, 3, 10) at (-232, 1.5, -332), high edge (Y 3) at Z -337 and low edge (Y 0) at Z -327; verify by raycast. **2 pansies** growing beside the ramp: stem Grass `#6FA84A` (2, 12, 2), head (8, 3, 8), at X -243 (head `#9B7FD4`) and X -221 (head `#E8C020`), Z -330. **Light anchor** (1, 1, 1), Transparency 1, at (-232, 14, -360): PointLight `#FF9A4A`, Range 30, Brightness 0.8, Shadows false. Inside: 12-wide floor and 39 studs of headroom. | 33 |
| **Honey Jar Fountain** (`Fountain`) | Sits on the moved SaucerStack (top Y 7.5) at (0, 0, -344). **Jar:** Cylinder (20, 16, 16), Glass `#FCEFC6`, Transparency 0.6, lying with its axis north-south, open end north and 8 deg low: `CFrame.lookAt(Vector3.new(0,15.5,-344), Vector3.new(0,14.1,-334)) * CFrame.Angles(0, math.rad(90), 0)`. **HoneyFill:** Cylinder (18.5, 11, 11), Glass `#F2A81C`, Transparency 0.1, same CFrame moved 2 down; holds a **PointLight** `#F2A81C`, R22, B0.9, Shadows false. **HoneyPour** (tag `HoneyFountain`): (5, 11, 2), Glass `#F2A81C`, Transparency 0.15, at (0, 6.5, -332.5), CanCollide false. **Splash:** Ball (6, 3, 6) at (0, 1, -331). **Pool:** Cylinder (0.5, 30, 30), Orientation (0, 0, 90), at (0, 0.25, -338), Glass `#F2A81C`, Transparency 0.2, CanCollide false. **Lid:** Cylinder (2, 12, 12) flat at (17, 1, -352), CorrodedMetal `#7A4A22`. **Dipper:** handle Cylinder (24.3, 2, 2), Wood `#8A6236`, from (-9, 0.5, -356) to (-4, 22.5, -347) (`CFrame.lookAt(mid, end) * CFrame.Angles(0, math.rad(90), 0)`), head Cylinder (4, 5, 5) at the low end. No ProximityPrompt; this honey is decoration and cannot be collected. | 8 |
| **Bottle-cap stools** (`Fountain`) | 6 Cylinders (2.5, 10, 10), Orientation (0, 0, 90), CorrodedMetal, alternating `#8E8A7A` / `#7A4A22`, at Y 1.25: (30, -344), (21.2, -365.2), (-21.2, -365.2), (-30, -344), (-21.2, -322.8), (21.2, -322.8) | 6 |
| **Cane Arch** (`Entrance`) | Garden canes over the spur at Z -277. Canes: Wood, colour = GatewayPost (`#7A4A22`), Size (3, 41.8, 3). Left at (-6, 20, -277), Orientation (0, 0, -16.7). Right at (6, 20, -277), Orientation (0, 0, 16.7). Feet at X ±12, tops meet at (0, 40, -277). Knot: Ball (4, 4, 4) at (0, 39, -277). Crossbar (20, 1.5, 1.5) at (0, 24, -277). Sign WoodPlanks `#8A6236` (14, 5, 0.8) at (0, 20.5, -274.6), SurfaceGui on Face Back: "APIARY YARD", FredokaOne, `#FCEFC6`, LightInfluence 0. Clear height under the sign is 18. | 5 |
| **Brick edging** (`Entrance`) | Concrete `#A86848`, Size (19, 9, 4), Y 0.5 (5 visible), Z -271, yaw alternating ±6 deg. West: 8 bricks at X = -194.5 + 19k (k = 0..7). East: 10 bricks at X = 73.5 + 19k (k = 0..9) | 18 |
| **Weather plant-label** (`Signage`) | A wooden stake (3, 18, 1), Wood `#8A6236`, at (-42, 9, -308). Slate tag (14, 10, 1), colour = LeaderboardChalkBand (`#58544C`), at (-42, 22, -308), tag **`WeatherLabel`**, SurfaceGui "WeatherLabelGui" on **Face Back** (faces north toward arrivals), PixelsPerStud 50, LightInfluence 0. TextLabels "Title" ("TODAY"), "State" ("Clear skies"), "Effect" ("Good flying weather"); FredokaOne; Scale sizes 0.28/0.40/0.32; colours `#E8D49A` / `#F2A81C` / `#FCEFC6`. Static text until the optional controller exists. | 2 |
| **Yardstick lookout** (`Lookout`) | One Part "LookoutRuler", Wood `#7A4A22`, Size (7, 1, 73.2), from (-232, 0.5, -282) up to the den rim top (-232, 46.5, -339): `CFrame.lookAt((start+end)/2, end)`. 39 deg slope. It passes 37+ studs above the den mouth. The flat top stave (Y 44, 50 long) is the lookout over the meadow and all 6 combs. | 1 |
| **Yard lanterns** (`Lights`) | Clone `PetalPath.PathLights.PathLantern_05` (3 parts, PathGlow R26 B1) as "YardLantern_W" with its post at (-150, 7.3, -305), and "YardLantern_E" at (176, 7.3, -350) | 6 |
| **Total new** | | **145** |

---

## 6. Code: required and optional

**REQUIRED (luau-scripter, about 4 lines). `StarterPlayer.StarterPlayerScripts.Controllers.VfxController`:**
- `HUB_MIN = Vector3.new(-264, -40, -406)` and `HUB_MAX = Vector3.new(264, 140, -266)` (currently ±70). Without this, pollen drift and the in-zone test ignore both wings.
- `EAVE_POINTS = { Vector3.new(-30, 19, -372), Vector3.new(30, 19, -372) }` (currently (-54, 19, -384) and (-30, 19, -372)). Still 2 dust emitters, so the emitter budget does not change.
- Nothing else changes: PlotService, LeaderboardService, HoneyLeaderboardBoardSkin, HubBellController, DiaryService, VigilService, PatchService and SoundController all find their objects by tag or by an unchanged path.

**OPTIONAL A: `HubBoardController`** (ModuleScript in Controllers; ClientMain gets one additive `require(...).Init()` after HubBellController). It listens to the **existing** `Remotes.TimeWeather` payload `{state, duration}` and writes to the `WeatherLabel` SurfaceGui. Text per `Config.WEATHER` key: Clear = "Clear skies" / "Good flying weather"; Breezy = "Breezy" / "Bees fly a bit slower"; Overcast = "Cloudy" / "Flowers give less nectar"; Rain = "Rain!" / "Bees stay home"; BloomRush = "BLOOM RUSH!" / "Flowers give extra nectar". If the state is unknown, show the Clear text. No new remote and no server change.

**OPTIONAL B: `FountainController`** (ModuleScript in Controllers, same wiring). Every 5 s it sums the **existing** `HoneyPerMin` attribute on the 6 `PlotRoot`-tagged parts, then sets `flow = math.clamp(sum / 600, 0, 1)` (600 = owner-tunable `FOUNTAIN_FULL_HPM`, a local constant). From `flow` it tweens the HoneyFill PointLight Brightness 0.6 -> 1.2 and the HoneyPour width (Size.X) 3 -> 6. It also sets the Rate of one drip ParticleEmitter on HoneyPour to 1 -> 4 (built by vfx-designer; it counts against the 20-emitter budget). Read-only and client-only.

**No new gameplay system.** Nothing here touches currency, data, plots, threats or remotes. The economy cannot be blocked: teleport pads, plots, the Petal Path and the meadow stay exactly as reachable as today. The spur, lane bed and stones are untouched.

---

## 7. Cloud ideas: adopted or rejected

| Cloud idea (source) | Verdict | Why |
|---|---|---|
| Hub v2 rebuild, 400x280, 4 zones (`cycle3_hub_dispatch.md`) | **Adopt the width and zoning, plus the lit kitchen window and The Question. Reject the rest.** | Destroy-and-rebuild would break 5 path- or tag-bound systems. Its depth (to Z -546) goes past the south boundary and the pine ring. It rebuilds the can, boot and hives from boxes when live already has meshes. It moves the leaderboard to a cork board (the live board works). |
| Flowerpot Den (cycle3, zone 3) | **Adopt** as a hollow walk-in pot (section 5) | The best social and screenshot idea in the cloud specs. The cloud version was a solid cylinder you could not enter. |
| Birdbath, garden table with mug (cycle3) | Reject | Blue glass breaks the material rule (Glass = honey). They add parts without a new feeling. |
| Bee benches (`cycle8_hub_expansion_dispatch.md`; gathering clusters in dispatch 153) | **Adopt as bottle-cap stools** | A park bench at bee scale breaks "human-made is about 12x". Bottle caps keep the joke. |
| Flower beds with Neon blobs (cycle8) | **Adopt as wildflower clumps in flagstone cracks plus the den's pansies** | Neon means "act now". The yard being reclaimed by the meadow tells the same story without breaking the palette. |
| Honey drip fountain (cycle8) and its animation (**dispatch 226**, `cycle23_fountain_anim_dispatch.md`) | **Adopt** as the Honey Jar Fountain plus optional FountainController. **Reject** 226's ResourceService `HubHoneyFlow` write. | The visual flow is wanted, but not at the price of editing an economy service. 226 also reads a `CombCell.OutputRate` attribute that does not exist live. `PlotRoot.HoneyPerMin` already exists. |
| Weather notice board (cycle8) | **Adopt** as the plant-label plus optional HubBoardController | Cycle8's `WeatherSync` remote and `WeatherService` do not exist live. TimeService already broadcasts `TimeWeather`. |
| Path kerbs (cycle8) | Reject | They would collide with the spur stones (up to X ±11) and turn a meadow trail into a sidewalk. |
| Flower arch (dispatch 153) | **Adopt as the cane arch** | Same "this is the entrance" job, kept on-scale and on-palette. |
| Server stats board (dispatch 153) | Reject | It needs a new server Script and remote plus attributes (`CombCellCount`, `HoneyEarned`, `ForagingActive`) that do not exist live. |
| Hub ticker (**dispatch 188**, `cycle18_hub_ticker_dispatch.md`) | Reject | It depends on a `PlotStatsUpdate` remote and on `HoneyCount`/`MaxRipeness`/`ThreatStage` attributes that do not exist live. It duplicates the Plot Signs and the leaderboard and uses an Offset-sized BillboardGui. |
| Ring-3 unlock (**dispatch 160**, `cycle15_hive_expansion_dispatch.md`) | Out of scope | It is a comb ring-3 purchase, not a hub expansion. |
| Holiday hub transforms (dispatch 155), harvest stall (dispatch 30) | Park | These belong to the seasons addendum. |
| Hub narrative triggers (cycles 7 and 11) | Park | No NarrativeEngine exists live. |
| Trophy pedestals (dispatch 38), cork leaderboards (cycles 6/15, dispatch 223) | Reject | Achievements and the global leaderboard are already live. |
| Hub weather emitter anchors (cycle10) | Reject | TimeService and VfxController own weather visuals, and the emitter budget is tight. |

---

## 8. Part budget

| | Parts |
|---|---|
| Hub now | 153 |
| Removed (nails, trowel) | -7 |
| New world-builder (section 5) | +145 |
| detail-architect (cap) | +30 |
| set-dresser (6 wildflower clumps = 12, plus extra dressing; cap) | +30 |
| **Planned hub** | **351** (hard cap 380 including a 29-part reserve) |
| **Game total** | 1935 - 153 + 351 = **2133 / 5000 (43%)**. Outer Walls and PerimeterRing are edited only, so their counts do not change. |

New lights: window SurfaceLight, den, fountain, lanterns C and D, 2 yard lanterns = **+7** (hub total 15, of which 4 cast shadows). New Sounds: **0**. New emitters: at most 1 (optional fountain drip).

---

## 9. Build order and checks

0. **GameMaster (backup).** Clone `Map.Hub`, `Workspace["Outer Walls"]` and `Treeline.PerimeterRing` into `ServerStorage.HubBackup_v1`. *Check:* 153 + 18 + 32 BaseParts in the backup.
1. **world-builder: envelope.** Section 4 items 11-14 and 29-34, then section 5 shed extension, side wall, fence and edging. *Check:* (a) From (0, 3, -330), cast 64 horizontal rays of 400 studs: every ray hits an invisible wall, the shed, the fence or the side wall, except rays aimed north (Z+), which must reach the meadow. (b) A downward ray finds ground at 41 sample points along Z -267 and X ±263 (no void seams). (c) Hub ≤ 260 parts at this point.
2. **world-builder: relocate.** Section 4 items 1-10 and 15-27. *Check:* (a) 6 `TeleportPad` tags with PlotIndex 1..6 at the target XZ within 0.1. (b) `Map.Hub.Structures.GlobalLeaderboard.LeaderboardBoard` and `...HubBell.ThimbleBell` resolve by path. (c) Diary PrimaryPart = DiaryCover, DiaryPrompt present, streaming Persistent. (d) A pairwise `GetPartsInPart` overlap scan of all hub groups returns zero hits, except a group with itself and the fountain stack. (e) Clearance (16 rays at Y 3) ≥ 10 at spawn, ≥ 8 at each pad, ≥ 12 at (0, -360) in front of the board.
3. **world-builder: new heroes.** Lit window, den, fountain, stools, arch, label, ruler, lanterns C/D, yard lanterns. *Check:* raycast down at (-232, ·, -336) returns about Y 2.7 (ramp), and at (-232, ·, -360) returns Y 3 (den floor). A `character_navigation` run in Play mode walks spawn -> each pad (teleports fire), spawn -> den interior, and spawn -> ruler -> den top (Y ≥ 44). No light is closer than 3 studs to any mesh (the bug #48 rule). Hub ≤ 300 parts.
4. **luau-scripter.** VfxController constants (required). Optional A and B only if the owner approves. *Check:* `script_grep` shows the new constants. Play mode has no console errors. AdminService weather change updates the label (if A is built).
5. **detail-architect.** `Hub.ArchDetail`, ≤ 30 parts: kick-board along the shed foot, flagstone seam variation, rust stains on the can and bucket, and tick marks on the ruler. Anchored, CanCollide false. *Check:* count ≤ 30, no part inside the den mouth, ramp or pad footprints.
6. **set-dresser.** Re-scatter moss and weeds. Add 6 wildflower clumps (2 parts each, meadow-species colours) in the west lawn (X -256..-203, Z -326..-280), plaza corners and fence base. ≤ 30 new parts, inside `Hub.Props`. *Check:* nothing within 8 studs of a pad centre, 6 of spawn, or on the ramp, ruler or den floor.
7. **lighting-director.** Tune only; no global post-processing changes. *Check:* Play at ClockTime 22 and capture screenshots of the den, plaza, shed front and east row. Every zone has a warm pool. The window is the brightest rectangle on the shed. Bloom never blows out the honey pool.
8. **art-director**, then **roblox-playtester**, then **computer-player** (pads, den, lookout, diary prompt, bell during an admin-forced raid).

---

## 10. Risks
- **Accidental teleport:** G3 and G4 sit inside the open mouth. This is the same exposure as today, now reduced: the central lane is 52 wide and the edging covers G1, G2, G5 and G6.
- **Mesh bounding boxes vs real collision:** clearances in section 4 use world bounding boxes, which overstate the meshes. The step 2 overlap scan is the truth.
- **Path-bound scripts:** renaming or reparenting Structures, GlobalLeaderboard, HubBell, Gateways or Props.BeekeepersDiary silently disables the leaderboard, the bell or the diary. **Translate only.**
- **Bell rest pose:** moving the bell at runtime would desync its swing. Only move it in Edit mode.
- **Streaming:** new models must be Persistent, or players at their plots (300+ studs away) see the hub pop in.
- **Sound cap is full (24/25):** any agent adding a hub Sound fails the audio gate.

## 11. Owner decisions
1. **Width:** **528 (X ±264, recommended)** or 400 (tighter; the den has no access lane).
2. **Leaderboard move** to the centre axis under the lit window: **yes (recommended)** or keep it at (-34, -382).
3. **Diary move** to the eave lantern (makes the Config text true): **yes (recommended)** or keep it beside the boot.
4. Remove the 4 giant nails and the trowel (7 parts): **yes (recommended)**.
5. Build the optional client controllers (weather label text, fountain flow) now or later. The world works statically either way.

## 12. Open questions
- Should the yardstick lookout get a small reward later (a badge or a hidden diary page)? It is pure view for now.
- Is 600 honey/min the right "full flow" level for the fountain?
- Seasonal hub decor: confirm it waits for the seasons addendum.

## 13. Honey Obby zone

**Status:** spec only. Build waits for the hub redo owner decisions (section 11) and runs after hub build steps 0-3.
**Live facts used (Edit mode, 2026-10-03, place 123313915411717):** Workspace BaseParts 1935. Hub 153. Achievements: `Config.ACHIEVEMENTS_ORDER` holds 14 ids (bearWrangler, cappingNight, firstHarvest, goldenHive, combBuilder, masterMason, waggleStarter, perfectDancer, firstSwarm, royalLineage, perkedUp, fullWardrobe, curiousBee, nightOwl). LeaderboardService is `OrderedDataStore("LifetimeHoney_v1")` top 10 on the hub board. Studio switched to Play mode during the last measurement, so the east-meadow clearance scan could not be run. Section 13.2 makes it the first step.

### 13.1 Location: deviation from "inside the hub"

**No clean space exists inside the hub envelope.** Checked against section 3.3 and section 5:
- West lawn (X -256..-203, Z -326..-280), the owner's suggested spot: the yardstick lookout ruler runs through X -235..-229 from Z -282 to -339, the Den ramp sits at (-232, -332), two pansies at Z -330, and set-dresser clumps are planned there. Nothing clean remains.
- East of the hub (X 258+): the garden fence, the hive, and the hose coil (X 203..255) take that edge.
- Plaza and shed front: fully allocated to the fountain, stools, leaderboard, bell, diary.

**Chosen option: the Wild Meadow, just east of the hub mouth, north of the east meadow wall.** The east meadow wall (Outer Walls, X 73..400, Z ≈ -270) is invisible and blocks the hub's south edge. Players reach the course by walking out of the central mouth (X -64..67) and turning east along the meadow. Nothing in the hub moves, and the hub's 351-part plan is untouched. The obby is "a meadow satellite of the Apiary Yard", not a hub zone. This is a deviation from the roadmap wording ("one zone of the hub redo"), so the owner should confirm it.

Footprint (world XZ, all Y as listed): **X 118..152, Z -262..-2** (34 x 260). Parent folder: `Workspace.Map.Meadow.HoneyObby` (a new folder), `ModelStreamingMode = Persistent`.
- Clearance: 7 studs north of the Edging bricks (Z -273..-269), 90+ studs east of the mouth, 60+ studs east of the FireflyJar (54, -264), outside the spur (X -8..8) and the sightline (X = 0). The 7 studs from the edging bricks is the tightest clearance.

### 13.2 Preflight (Edit mode, before any build; STOP if it fails)
1. Ground: 25 downward raycasts over the footprint (5 x 5 grid) all hit `Workspace.Map.Meadow.Ground.MeadowSoil` with Y in -0.2..+0.2. The course assumes ground top Y = 0.
2. No `Patch*`, `PetalPath*`, `Structures*`, `FallenLog*`, `Puddle*` or `PathLantern*` BasePart intersects the footprint (`GetPartBoundsInBox`). `Grass` / `MeadowTuft` / `StrayBlade` parts inside the footprint may be moved, not deleted, by the world-builder (they are decor only).
3. Results go in the step report. If check 2 fails, do not build. Report which part to move, and ask the owner.

### 13.3 Platform table (the spine of the course)

Every platform is a Part (or a clone of one) with `CollisionFidelity` Box, `Anchored = true`, `CanCollide = true`, tag `ObbyPlatform`, attribute `PlatformIndex` (0..12). Top Y is the walking surface. Center Y = top - 1 (2-stud thickness). Gap = edge-to-edge distance along Z. Every jump is a pure Z gap because the X ranges overlap (see the sway note).

Sway note: hex centres alternate X 131, flower centres X 139. Their X footprints overlap by 5 studs, so no jump is a diagonal. Without this, a 20-stud X offset would make each "6-stud" jump 21 studs long.

| Idx | Jump | Type | Center (X, Z) | Top Y | Footprint (X, Z) | Size (X, Y, Z) | Gap from previous |
|---|---|---|---|---|---|---|---|
| 0 | start | Honeycomb wide | (135, -250) | 1.0 | X 127..143, Z -258..-242 | 16 x 2 x 16 | n/a |
| 1 | J1 | Honeycomb hex | (131, -229) | 2.5 | X 124..138, Z -236..-222 | 14 x 2 x 14 | 6 |
| 2 | J2 | Flower pad | (139, -210) | 4.0 | X 133..145, Z -216..-204 | Ø12 x 2 | 6 |
| 3 | J3 | Honeycomb hex | (131, -191) | 5.5 | X 124..138, Z -198..-184 | 14 x 2 x 14 | 6 |
| 4 | J4 | Flower pad, **checkpoint C1** | (139, -172) | 7.0 | X 133..145, Z -178..-166 | Ø12 x 2 | 6 |
| 5 | J5 | Honeycomb hex | (131, -153) | 8.5 | X 124..138, Z -160..-146 | 14 x 2 x 14 | 6 |
| 6 | J6 | Flower pad | (139, -134) | 10.0 | X 133..145, Z -140..-128 | Ø12 x 2 | 6 |
| 7 | J7 | Honeycomb hex | (131, -115) | 11.5 | X 124..138, Z -122..-108 | 14 x 2 x 14 | 6 |
| 8 | J8 | Flower pad, **checkpoint C2** | (139, -96) | 13.0 | X 133..145, Z -102..-90 | Ø12 x 2 | 6 |
| 9 | J9 | Honeycomb hex | (131, -77) | 14.5 | X 124..138, Z -84..-70 | 14 x 2 x 14 | 6 |
| 10 | J10 | Flower pad | (139, -58) | 16.0 | X 133..145, Z -64..-52 | Ø12 x 2 | 6 |
| 11 | J11 | Honeycomb hex | (131, -39) | 17.5 | X 124..138, Z -46..-32 | 14 x 2 x 14 | 6 |
| 12 | finish | Honeycomb hex, finish | (135, -17) | 19.0 | X 126..144, Z -26..-8 | 18 x 2 x 18 | 6 |

- 12 jumps (0 to 1, 1 to 2, ..., 11 to 12). Rise is 1.5 studs per jump, so no jump needs more than a normal hop. Top Y goes 1.0 to 19.0.
- Flower pads are cylinders: Size (2, 12, 12), `Orientation (0, 0, 90)` (axis along Y), `Position` = (X, top - 1, Z).
- Hex platforms: a clone of an existing Floor-1 comb plate if its bounding box can be scaled to 14 x 2 x 14 (world-builder checks in step O1). Fallback: Cylinder Size (2, 14, 14), `Orientation (0, 0, 90)`. Fallback is acceptable and must be reported.
- Raycast check: a straight-down ray from (X, top + 5, Z) at each centre returns the platform at Y = top +/- 0.05.
- The start platform is 16 wide and the finish is 18 wide, so the first and last landings are forgiving.

### 13.4 Checkpoints and falls
- Checkpoint pads (decor, `CanCollide = false`, `Anchored = true`): Cylinder Size (0.4, 6, 6), `Orientation (0, 0, 90)`, colour `#FCEFC6`, tag `ObbyCheckpoint`, attribute `CheckpointIndex` (1 or 2). Position Y = platform top + 0.25. C1 at (139, 7.25, -172). C2 at (139, 13.25, -96).
- Respawn CFrame = platform centre top + (0, 3, 0). Start respawn (135, 4, -250). C1 respawn (139, 10, -172). C2 respawn (139, 16, -96).
- **Fall rule** (server, 0.2 s loop, only for characters inside the footprint):
  - Progress = the highest `PlatformIndex` reached in order. Progress advances only from `k` to `k + 1` (landing by downward raycast, 6 studs, against `ObbyPlatform`). Skipping forward is ignored.
  - Fall = `root.Y < top(progressPlatform) - 3` with no `ObbyPlatform` under the root within 6 studs.
  - On fall: teleport to the last checkpoint CFrame, set progress to that checkpoint's index (0, 4 or 8), set `dirty = true`. The timer keeps running. There is no damage and no death.
- Death (Humanoid dies for any reason) goes to the normal plot respawn. The course does not override it. This is accepted.

### 13.5 Timing and best-time rules
- **Run starts** when progress first reaches 1 (first landing on J1). The server reads `os.clock()` at that moment.
- **Run finishes** when progress reaches 12. Finish is accepted only if the run took at least `MIN_RUN_SECONDS = 12` (anti-skip floor).
- **Run abandons** when progress returns to 0 (back on the start platform). No time is saved. The next leave from the start begins a new run.
- **Clean run** = `dirty == false` (no fall reset in the run). Only clean runs can set a best time. Dirty runs still finish, still grant the achievement and the flourish.
- **Best time** = minimum clean finished time, rounded to 0.01 s. Stored in the profile as `obbyBestTime` (number, 0 = none). Added to `Config.PROFILE_TEMPLATE` and to SwarmService's preserved-fields list. A personal best survives swarm, like achievements.
- **Display (decision, see 13.6):** the server writes the player attribute `ObbyBestTime` (number, 0 = none) on profile load and on each clean PB. A client label "Your best: m:ss.cc" appears only when the local character is within 12 studs of the start platform (centre (135, 1, -250)). No hub board row, no new board.
- Starting and finishing run through the existing Notify remote. A finish toast reads "Honey Hopper! Clean run: m:ss.cc" or "Honey Hopper! Run finished (checkpoints used)".

### 13.6 Decisions

**Best time display: separate sign-style label, not a board row (recommended).** The live LeaderboardService is one OrderedDataStore for lifetime honey, top 10, and the hub board renders that one list. A time board needs a second OrderedDataStore sorted ascending, a second board renderer, and a second board. That is a second leaderboard system, which the brief rules out. A personal-best label that appears on the start platform reuses the attribute pattern, adds no store, and keeps one leaderboard. **Owner decision:** if a shared "fastest course" board is wanted later, it needs its own addendum.

**Achievement: propose `obbyFinisher`, title "Honey Hopper", description "Finish the Honey Obby".** Granted on the first validated finish, clean or dirty. No currency. It is **an owner decision**, because `Config.ACHIEVEMENTS` and `ACHIEVEMENTS_ORDER` would go from 14 to 15 entries, which changes the roadmap count and the achievement UI layout. Recommend yes. Implementation: one entry in `Config.ACHIEVEMENTS` and one at the end of `ACHIEVEMENTS_ORDER`. No other service changes.

**Finish flourish (no paid advantage):** one ParticleEmitter on the finish platform, `Enabled = false`, `Emit(24)` once, colour `#F2A81C`, `LightEmission = 0.3`, plus the finish PointLight tweened Brightness 0.8 -> 2.0 -> 0.8 over 1.5 s. Client-only tween, server-only Emit call. This adds **1** emitter.

### 13.7 Parts and budget

| Group | Count |
|---|---|
| Platforms (`ObbyPlatform`, indices 0..12) | 13 |
| Support stems under platforms J1..J11 and finish (Block 1.2 x h x 1.2, Wood `#8A6236`) | 12 |
| Flower-pad petals (5 pads x 6 Block 4 x 1 x 3, `#E8C020`, CanCollide false) | 30 |
| Honey wax cells on hex platforms (7 hex x 3 Cylinder 1.5 x 3 x 3, `#F2A81C`, CanCollide false) | 21 |
| Checkpoint pads (C1, C2) | 2 |
| Start sign: post (Block 1 x 8 x 1, `#7A4A22`) and board (WoodPlanks `#8A6236`, Size 14 x 5 x 0.8, SurfaceGui "HONEY OBBY" FredokaOne `#FCEFC6`) | 2 |
| Finish arch: 2 posts (Block 1.5 x 22 x 1.5, `#7A4A22`) + bar (Block 26 x 1.5 x 1.5, Wood `#8A6236`, Y 21) | 3 |
| Light anchors: start (135, 5, -250) and finish (135, 25, -17), Transparency 1, CanCollide false | 2 |
| Emitter anchor (finish, Transparency 1) | 1 |
| Ground flower clumps (6 x 2 parts: stem Block 0.4 x 3 x 0.4 `#8A6236`, head Ball 2 x 2 x 2 `#E8C020`) | 12 |
| **Obby total** | **97** |

- Game total: 1935 (live) - 153 (hub now) + 351 (hub planned) + 97 (obby) = **2230 / 5000 (45%)**. The hub stays at 351, under its 380 cap.
- Sound objects added: **0** (sound cap stays 24/25).
- Emitters added: **1** (finish flourish). The hub addendum allowed at most 1 more (optional fountain drip), so the two together make 2 new emitters. Recheck the 20-emitter budget in the vfx-designer gate.
- Lights added: **2** (start and finish anchors), both with the 3-stud rule (start is 4 studs above S top, finish is 6 studs above the finish top).
- Palette (warm wax only): `#F2A81C`, `#FCEFC6`, `#E8D49A`, `#E8C020`, `#8A6236`, `#7A4A22`. No greens, blues or neons.

### 13.8 Build order (runs after hub steps 0-3)

Each step ends with a numeric check. Failure stops the step.

- **O0. Preflight (section 13.2).** *Check:* 25/25 ground rays hit MeadowSoil with Y in -0.2..+0.2; 0 blocking-class parts in the footprint.
- **O1. world-builder: platforms.** Create `Workspace.Map.Meadow.HoneyObby` with sub-folders `Platforms`, `Decor`, `Checkpoints`, `Finish`, `Lights`. Build the 13 platforms from 13.3 with tags and attributes. *Check:* exactly 13 `ObbyPlatform` parts with `PlatformIndex` 0..12 each once; each top Y within 0.05 of the table; 12 consecutive gaps measured along Z within 6.0 +/- 0.1; every platform `Anchored = true`, `CanCollide = true`.
- **O2. world-builder: decor and lights.** Stems, petals, wax cells, checkpoint pads, start sign, finish arch, light anchors, emitter anchor, clumps. *Check:* obby part count = 97 +/- 3; every decor part `CanCollide = false`, `Anchored = true`; the 2 PointLights have no BasePart within 3 studs (script scan of all BaseParts against each light's position); no part higher than Y 25.
- **O3. Raycast verification.** From (X, top + 5, Z) straight down at each platform centre: hit within 0.05 of the top Y, and the hit instance has tag `ObbyPlatform` and the expected `PlatformIndex`. *Check:* 13 of 13 hits correct.
- **O4. Walk test (character_navigation, Play mode).** Walk from the mouth (60, -266) to the start, then across all 12 jumps, then into the finish. *Check:* progress reaches 12; a deliberate fall at J6 resets to C1 (7.0 top, progress 4); a fall at J9 resets to C2 (progress 8). If a jump is not walkable in the test, the gap is too wide: report which index and do not widen the gap without owner approval.
- **O5. luau-scripter: ObbyService + Config.OBBY.** Server Script in `ServerScriptService.Systems`, `--!strict`, implements 13.4 and 13.5. Config keys: `MIN_RUN_SECONDS = 12`, `FALL_MARGIN = 3`, `RESPAWN_LIFT = 3`, `CHECK_INTERVAL = 0.2`, `CHECKPOINT_INDEX = {[4]=1, [8]=2}`. Profile field `obbyBestTime` (default 0). Player attribute `ObbyBestTime`. Notify on finish. Achievement hook only if the owner approves 13.6. Optional client label (13.5) only if approved. *Check:* `script_grep` finds the constants; Play mode prints no errors; profile saves and loads `obbyBestTime`.
- **O6. Achievement (only if approved).** One entry in `Config.ACHIEVEMENTS`, one at the end of `ACHIEVEMENTS_ORDER`. *Check:* `ACHIEVEMENTS_ORDER` length 15; no duplicate ids.
- **O7. set-dresser: clumps only (inside O2 count).** *Check:* no clump within 3 studs of any platform footprint in XZ.
- **O8. roblox-playtester (structural).** *Check:* 13 platforms, 2 checkpoints, 1 finish, `ObbyService` present, obby parts 97 +/- 3, no PointLight within 3 studs of a mesh.
- **O9. computer-player.** Full route, one clean run, one dirty run (deliberate fall). *Check:* clean time recorded in the profile; dirty run gives the finish but no best; achievement granted once only (second finish grants nothing new).
- **O10. Hub step 7 (lighting-director)** includes the obby: warm pool on each platform top, no bloom blowout on the finish flourish. *Check:* screenshot at ClockTime 22 shows all 13 platforms lit.

### 13.9 Risks
- **Meadow contents unknown (east side).** Clearance was not measured live (Studio went to Play mode). Preflight 13.2 is mandatory before O1.
- **Respawn on death** goes to the plot, not the checkpoint. Accepted, and stated to the owner.
- **Hex mesh fallback:** if the cloned comb plate is not used, the platforms are round cylinders. Visual change only, not a rule change.
- **Two new emitters** across the hub and the obby. Recheck the emitter budget.

READY FOR REVIEW
