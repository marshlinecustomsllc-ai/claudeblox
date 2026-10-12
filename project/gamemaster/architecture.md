# Color Lock -- Architecture Document

**Task type:** TYPE A (new game, blank baseplate). Place: "Color Lock", placeId 107537014698253. Workspace currently contains only Terrain/Baseplate/Camera.

## Core Concept
You wake up sealed inside a derelict color-research vault where every door reads your solution in light -- solve the color puzzles standing between you and the exit, but the corridors are haunted by translucent color-echoes of real people who tried before you, and the final chamber shows you exactly why.

## The Hook
**ECHOES.** Every player's path and outcome through this game is quietly recorded. As you play, you glimpse translucent, color-tinted silhouettes of REAL previous players replaying their attempts behind frosted glass and around corridor corners -- some solving correctly (a free hint, if you're paying attention), some clearly failing (a warning, or a red herring). When you finally solve the last room, your own signature color is added permanently to the Wall of Echoes -- a vault wall covered in the handprints of every player who ever escaped before you -- and your recorded path joins the pool that future players will see. You are never told this is happening. You just start noticing you're not alone, and by the end you realize you never were. This is not decoration bolted onto a color-matching game -- it is a lightweight asynchronous-multiplayer system (DataStore-backed ghost recordings) that makes a solo/co-op puzzle game feel like it has hundreds of people trapped in it with you.

## Genre: Puzzle / Escape-Room
Escape-room works because each solved door is a complete, visible unit of progress -- the player always knows exactly how close they are to done. The unexplored angle here: escape-rooms are almost always presented as a solitary, self-contained trial. Color Lock breaks that by making the room's history visible -- every puzzle chamber is haunted by proof that this trial has happened many times before, to many people, and your solve becomes part of that permanent record. The color-lock theme also lets every puzzle mechanic be genuinely different (mixing, memory, routing, physical sorting, timed pressure) while staying legible in ten seconds, because color relationships (red+green=yellow, "this glows the wrong color, try again") need zero reading to understand.

---

## Emotional Journey
Curiosity (waking up marked with your own color) -> quiet confidence (Mixing Chamber teaches the rules gently) -> mild unease (first Echo sighting in Corridor A -- you're not the first) -> focused mastery (Echo Room memory challenge, and the dawning creepiness of a ghost solving it for you) -> awe (Prism Hall's cathedral of colored light) -> relief (Pressure Garden -- a deliberate warm breather) -> mounting dread (Static Vault's alarms and rising time pressure) -> peak tension released into awe (The Convergence, all four skills combining at once) -> catharsis (Wall of Echoes -- you see you were always one of many) -> freedom (exit light).

---

## Spatial Narrative
The player's physical path is a single spine running north along the Z-axis, room by room, each room a little larger and a little stranger than the last, until the vault opens up entirely for the finale. Tension tracks room proportions and light color: rooms start bright, boxy, and forgiving; by the Static Vault they are tight, alarm-lit, and industrial; the Master Lock Room breaks the pattern entirely by becoming vast and vertical, which is what sells the "convergence" feeling.

Room-by-room tension curve:
1. Intake Chamber (spawn) -- tension: low, spatial feeling: contained/clinical, why: bright sterile geometry, gentle hum, the calm before you notice anything is wrong.
2. Corridor A -- tension: low-rising, spatial feeling: narrow/transitional, why: first Echo flicker glimpsed through a frosted window -- the first "wait, was that--?" moment.
3. Mixing Chamber (Room 1) -- tension: low, spatial feeling: open/symmetrical, why: generous space, forgiving mechanic, this room exists to teach without scaring.
4. Echo Room (Room 2) -- tension: medium, spatial feeling: enclosed amphitheater, why: memory pressure plus the first ghost that visibly solves the puzzle in front of you.
5. Prism Hall (Room 3) -- tension: medium but awe-forward, spatial feeling: tall/vertical, why: the beauty of colored light outweighs the difficulty -- a spectacle room.
6. Pressure Garden (Room 4) -- tension: low (deliberate dip), spatial feeling: open/warm/organic, why: a breather before the escalation into the vault's decaying half.
7. Static Vault (Room 5) -- tension: high, spatial feeling: cramped/industrial, why: real time pressure, alarms, the first room that feels uncaring rather than curious.
8. Master Lock Room (finale) -- tension: peaks then resolves into awe, spatial feeling: vast/vertical/radiant, why: four mechanics at once (peak difficulty) resolving into The Convergence and the Wall of Echoes (emotional payoff).

---

## Core Loop
```
ENTER ROOM -> read the room's puzzle silhouette (no text, pure visual read)
   -> EXPERIMENT (tap-based, mobile-friendly, no penalty for wrong tries)
      -> partial feedback ("getting warmer" chime / glow) every ~15-20s
   -> SOLVE -> color visibly drains through a pipe/beam into the door
      -> door blooms full color, unlocks, slides open (payoff, ~every 60-120s)
   -> WALK CORRIDOR -> glimpse an Echo (previous player ghost) through glass
      -> unease / hint / lore beat
   -> NEXT ROOM (harder, new mechanic)
      ... repeats through 5 rooms ...
   -> MASTER LOCK ROOM -> solve 4 compressed mini-mechanics at 4 stations
      -> THE CONVERGENCE (all 4 beams combine, ceiling opens)
      -> WALL OF ECHOES (place your handprint, permanently, in your color)
      -> EXIT (light floods in)
```
What keeps it engaging: every room changes HOW you solve color puzzles (never the same mechanic twice), the game never punishes failure with death or restart, and the Echoes system means the game's world visibly remembers every player who passed through -- which is precisely the thing a player tells their friend: "there are literal ghosts of real people in this game, and you leave one behind too."

---

## Service Architecture

```
ServerScriptService/
  Main (Script) -- init on server start, assigns each player a deterministic
    SignatureColor (hashed from UserId, so a player always gets the same
    color across sessions), spawns players at Intake Chamber
  DataManager (Script) -- owns two DataStores:
    "ColorLock_WallOfEchoes" (OrderedDataStore, capped at latest 200 entries,
      each entry: {userId, color, timestamp})
    "ColorLock_EchoRecordings" (DataStore, capped pool of ~50 recordings per
      room, each entry: compressed position-sample array + color + outcome)
    all writes wrapped in pcall with retry/backoff; writes are QUEUED and
    flushed on a 30s loop, never on every sample, to respect DataStore limits
  PuzzleManager (Script) -- single authority for ALL puzzle state (per-room
    state table keyed by roomId, shared across all players on the server --
    this is a CO-OP game, puzzles are solved once for the whole server, not
    per-player). Validates SetLeverValue, SubmitSequenceInput,
    RequestRotatePrism, RequestToggleGate. Contains sub-modules:
      - MixingSolver (Room 1 + Master Station A)
      - SequenceSolver (Room 2 + Master Station B)
      - PrismSolver (Room 3 + Master Station C) -- discrete-state beam graph,
        NOT real raycasting (see Risk Areas)
      - PlateController (Room 4 + Master Station D) -- watches .Touched on
        pressure plates, no RemoteEvent needed, purely physics-driven
      - VaultSolver (Room 5) -- conveyor/timer/quota logic
  DoorController (Script) -- listens for internal DoorUnlocked signal fired
    by PuzzleManager, tweens the matching door part open via TweenService,
    marks door state "Unlocked" for the remaining server session (doors do
    not re-lock)
  EchoController (Script) -- caches EchoRecordings pool in memory at server
    start; at scripted trigger points (Corridor windows on a timer, Room 2
    after 2 failed sequence attempts), spawns a temporary translucent R6
    ghost NPC (Anchored=false, CanCollide=false, no player interaction),
    tints it the recorded player's SignatureColor, and plays back its stored
    position samples via Heartbeat-driven CFrame lerp, then despawns it.
    Also buffers RecordEchoSample data per player per room in memory, and
    only hands a completed room's sample array to DataManager for
    persistent storage if the player actually solves that room (failed/
    idle wandering is never persisted, keeping the ghost pool meaningful)
  SecurityValidator (Script) -- debounces every RemoteEvent per player
    (0.3s), validates every roomId/leverId/prismId/gateId against the
    Config whitelist, rejects any interaction where the firing player is
    not within interact range (8 studs) of the relevant object

ReplicatedStorage/
  Modules/
    Config (ModuleScript) -- ROOM_DEFINITIONS (per-room target colors,
      correct sequences, prism solution graphs, plate patterns, vault
      quota/time), PALETTE (the 5-color art palette below),
      SIGNATURE_COLOR_POOL (12 hues players can be hashed into)
    Shared (ModuleScript) -- ColorDistance(c1, c2), Lerp helpers, used by
      both PuzzleManager (server) and UIController (client) so "how close
      is this mix" logic is identical on both sides
  RemoteEvents/
    SetLeverValue          (client -> server)
    SubmitSequenceInput    (client -> server)
    WatchSequence          (client -> server)
    RequestRotatePrism     (client -> server)
    RequestToggleGate      (client -> server)
    RequestPlaceHandprint  (client -> server)
    RecordEchoSample       (client -> server, throttled)
    DoorUnlocked           (server -> client)
    BeamStateUpdate        (server -> client)
    SequenceProgress       (server -> client)
    PlatePatternUpdate     (server -> client)
    SortResult             (server -> client)
    VaultOverload          (server -> client)
    FinalHandprintPlaced   (server -> client)
    PuzzleStateSync        (server -> client, fired on PlayerAdded so late
                            joiners see current shared puzzle state)

StarterGui/
  GameUI (ScreenGui)
    HUD (Frame) -- small SignatureColor swatch (top-left corner), 4
      progress pips for the Master Lock Room stations, no other text

StarterPlayer/
  StarterPlayerScripts/
    SignatureColorController (LocalScript) -- receives assigned color on
      spawn, applies a subtle particle "aura" to the character
    UIController (LocalScript) -- listens to DoorUnlocked / SortResult /
      PlatePatternUpdate / PuzzleStateSync, updates HUD swatch + pips,
      also runs the client-side "getting warmer" ColorDistance feedback
      for Room 1 / Master Station A using Shared module

Workspace/
  Map/
    IntakeChamber/
    CorridorA/ .. CorridorF/
    MixingChamber/
    EchoRoom/
    PrismHall/
    PressureGarden/
    StaticVault/
    MasterLockRoom/
```

Note: there is no CameraController script -- default third-person Roblox camera is used throughout (see Technical Decisions). There is no client-side Echo renderer -- Echo ghosts are ordinary server-spawned, server-replicated NPC models, visible to everyone natively.

---

## RemoteEvents

| Event | Direction | Payload | Server Validation |
|-------|-----------|---------|-------------------|
| SetLeverValue | C->S | `{roomId:string, leverId:string, value:number}` | value must be one of {0,25,50,75,100,125->wraps to 0}; roomId/leverId must exist in Config.ROOM_DEFINITIONS; player within 8 studs of lever |
| SubmitSequenceInput | C->S | `{roomId:string, buttonId:string}` | buttonId must be a valid panel for that room; debounced 0.3s; appended server-side to a per-room progress array, compared incrementally to the stored correct sequence |
| WatchSequence | C->S | `{roomId:string}` | player within 10 studs of the "Watch" plate; replays server-stored sequence to all clients in room via SequenceProgress |
| RequestRotatePrism | C->S | `{roomId:string, prismId:string, direction:1 or -1}` | player within 8 studs; facing recomputed server-side as (currentFacing + 90*direction) mod 360; triggers server beam re-trace |
| RequestToggleGate | C->S | `{roomId:string, gateId:string}` | player within 8 studs; debounced 0.3s; toggles gate state used by server-side conveyor simulation |
| RequestPlaceHandprint | C->S | `{}` (roomId implied server-side by player's actual position) | player must be physically within the Master Lock Room AND all 4 stations already solved server-side; rejected silently otherwise (no error spam, just no-op) |
| RecordEchoSample | C->S | `{roomId:string, position:Vector3}` | throttled to 1 per 2s per player; server discards samples for rooms the player has not yet entered; buffered in memory only, never trusted as authoritative for anything gameplay-affecting |
| DoorUnlocked | S->C | `{roomId:string}` | -- |
| BeamStateUpdate | S->C | `{roomId:string, path:{string}, receiverColor:Color3}` | -- |
| SequenceProgress | S->C | `{roomId:string, progress:number, total:number, replay:boolean}` | -- |
| PlatePatternUpdate | S->C | `{roomId:string, filledPlates:{string}}` | -- |
| SortResult | S->C | `{roomId:string, orbColor:Color3, success:boolean, quotaProgress:number}` | -- |
| VaultOverload | S->C | `{roomId:string}` | -- |
| FinalHandprintPlaced | S->C | `{color:Color3, index:number}` | -- |
| PuzzleStateSync | S->C | `{rooms: {[roomId]: currentStateTable}}` | -- |

All gameplay-affecting logic (mixing check, sequence check, prism check, plate check, vault quota, handprint eligibility) is computed and decided SERVER-SIDE only. Clients never send a result, only an intent ("I set this lever to this value", "I rotated this prism") -- the server always independently recomputes whether that intent produces a solved puzzle.

---

## World Layout

General rule applied at every connection below: floor slabs extend 3 studs past their nominal wall boundary into the adjoining corridor/room, guaranteeing zero-gap floor continuity at every doorway. All rooms and corridors share Y 0-14 (floor at Y=0, ceiling at Y=14, center Y=7) EXCEPT the Master Lock Room, which is taller (Y 0-22, center Y=11) to sell its "the vault gets bigger for the finale" moment. The whole spine runs along +Z, centered on X=0.

### Intake Chamber (spawn)
- **Position:** Vector3(0, 7, 12)
- **Dimensions:** 24W x 14H x 24D studs (X -12..12, Z 0..24)
- **Floor:** SmoothPlastic, #E8ECEF
- **Walls:** Concrete, #C9CFD3
- **Accents:** Neon strip trim, #58C4DC (cool blue -- "unsolved/neutral")
- **Lighting:** 2x ceiling SpotLights at (-6,13,8) and (6,13,8), Range 30, Brightness 2, Color #DCEBFF; 1x SurfaceLight on the scan pad itself, Color shifts to the player's SignatureColor once assigned
- **Part count:** ~80
- **Connections:** north wall doorway at Z=24, X=0, width 8, leads to Corridor A (this door is NOT locked -- it's the only open doorway in the game, everything past it is sealed)
- **Key objects:** circular "Scan Pad" at (0,0.5,6) (8 parts) that assigns SignatureColor and spawns the aura the moment the player steps on it; a small non-interactive "practice wall" at (10,7,4) showing two overlapping colored lights blending into a third (8 parts) -- pure silent foreshadowing of the Mixing Chamber, zero text
- **CHARACTER:** a sterile intake/processing room -- the calm clinical hush of a place that used to run tests on people. Bright, clean, symmetrical. Nothing here says danger yet; everything says "you are being catalogued."
- **LIFE:** ambient -- overhead lights flicker very faintly every ~12s (barely noticeable, a seed of doubt); scanning-equipment hum loop. Triggered -- stepping on the Scan Pad triggers a soft rising chime and the player's personal aura ignites (a one-time, unforgettable "this vault knows who I am" beat).

### Corridor A
- **Position:** Vector3(0, 7, 32)
- **Dimensions:** 8W x 14H x 16D (Z 24..40)
- **Floor:** Concrete, #B7BEC2 | **Walls:** Concrete, #B7BEC2 | **Accents:** dim neon trim, #58C4DC
- **Lighting:** 1x ceiling PointLight at (0,13,32), Range 20, Brightness 1.2, Color #CFE3FF
- **Part count:** ~35
- **Connections:** south to Intake Chamber (Z=24), north to Mixing Chamber (Z=40), both doorways X=0 width 8
- **Key objects:** one frosted-glass window in the west wall at (-4,7,34) (4 parts) looking into a black void beyond the wall (not a real room -- just a shadowbox for the Echo sighting)
- **CHARACTER:** the first breath of the vault's real age -- narrower, dimmer, quieter than Intake. The first place that feels like it belongs to someone else.
- **LIFE:** triggered -- roughly 20% of the time a player walks past the frosted window, EchoController spawns a translucent color-tinted silhouette behind the glass for ~3 seconds, doing something wordless and unexplained, then gone. First occurrence of this is the "Echo Through Glass" signature moment.

### Mixing Chamber (Room 1)
- **Position:** Vector3(0, 7, 55)
- **Dimensions:** 28W x 14H x 30D (X -14..14, Z 40..70)
- **Floor:** SmoothPlastic, #F2F2F2 | **Walls:** Concrete, #DADFE2 | **Accents:** ClearGlass panels + neon trim in R/G/B
- **Lighting:** 3x SpotLights above each lever at (-8,13,48)/(0,13,48)/(8,13,48), Range 24, Brightness 1.5; 1x SurfaceLight inside the Reveal Orb that shifts live with the current mix
- **Part count:** ~150
- **Connections:** south to Corridor A (Z=40), north doorway at Z=70 X=0 width 8 to Corridor B (LOCKED until solved)
- **Key objects:** 3 lever housings at (-8,3,48)/(0,3,48)/(8,3,48) (~15 parts each, 45 total) -- each a stepped dial, one ProximityPrompt per lever that cycles its value +25 per tap (0->25->50->75->100->0); a "Reveal Orb" pedestal at (0,6,58) (10 parts) whose SurfaceLight color = additive mix of the 3 lever values; a frosted "Target Pedestal" at (0,6,64) (8 parts) showing the goal color, permanently visible (not hidden -- this is a teaching room, not a memory test); door mechanism + color-feed pipe at (0,7,69) (10 parts) that visibly carries the winning color from the orb to the door on solve
- **CHARACTER:** a chemistry-class-meets-cathedral hush. The first real puzzle room, and deliberately the most forgiving and spacious -- this room exists to teach red+green=yellow, red+blue=magenta, green+blue=cyan, all three=white, without a single word of text.
- **LIFE:** ambient -- the Reveal Orb gently pulses its current (even if wrong) color every ~10s, so the room never feels static; lever housings clunk audibly and satisfyingly on every tap. Triggered -- a correct PARTIAL match (within one "step" of target on any channel) plays a soft rising chime, teaching the "getting warmer" feedback used again in the Master Lock Room. One-time -- the first full correct match triggers "First Color Bleed": the orb's color visibly flows down the pipe into the door, the door blooms bright and slides open (signature moment).

### Corridor B
- **Position:** Vector3(0, 7, 78) | **Dimensions:** 8W x 14H x 16D (Z 70..86)
- **Floor/Walls:** Concrete #B7BEC2 | **Accents:** neon trim #58C4DC
- **Lighting:** 1x PointLight at (0,13,78), Range 20, Brightness 1.2
- **Part count:** ~35
- **Connections:** south to Mixing Chamber (Z=70), north to Echo Room (Z=86)
- **CHARACTER:** identical bones to Corridor A, slightly dimmer -- the vault is settling deeper into itself.
- **LIFE:** ambient flicker every ~14s; occasional (10%) Echo sighting reused from the Corridor A system but a different recorded ghost, keeping sightings from feeling scripted/repetitive.

### Echo Room (Room 2)
- **Position:** Vector3(0, 7, 100) | **Dimensions:** 26W x 14H x 28D (X -13..13, Z 86..114)
- **Floor:** SmoothPlastic, #ECECEC | **Walls:** Concrete, #D6D6D6 | **Accents:** 4 large wall panels in Red/Green/Blue/Yellow neon
- **Lighting:** 4x SurfaceLights, one per panel, color-matched to that panel, Brightness pulses with sequence playback; ambient ceiling PointLight, Brightness 1.2, Color #E8E8FF
- **Part count:** ~130
- **Connections:** south to Corridor B (Z=86), north doorway Z=114 X=0 width 8 to Corridor C (LOCKED until solved)
- **Key objects:** 4 wall panels at (-9,7,88)/(-3,7,88)/(3,7,88)/(9,7,88) each with a matching floor button in front (~10 parts each, 40 total); a "Watch" pressure plate at (0,0.5,110) near the entrance (4 parts) that replays the sequence for anyone who missed it or joined late; door mechanism (10 parts); a broken "record player" prop referencing the vault's obsession with recording everything (10 parts, pure lore dressing)
- **CHARACTER:** an amphitheater of memory. The room hums like it's recording every step you take. Panels flicker in stored patterns like a broken television replaying a message that isn't quite for you.
- **LIFE:** ambient -- each panel idle-pulses a dim version of its color on its own independent 6-9s cycle, so the room looks alive even when no sequence is playing. Triggered -- stepping on the Watch plate re-plays the target sequence (accessibility valve, no penalty for needing it twice); a wrong button buzzes and resets progress (never resets the whole game, just this room's attempt). One-time -- after 2 failed full attempts, an Echo ghost fades into the room and visibly solves the exact correct sequence once before vanishing -- a built-in visual hint disguised entirely as lore, so no player ever gets hard-stuck without a single word of tutorial text.

### Corridor C
- **Position:** Vector3(0, 7, 122) | **Dimensions:** 8W x 14H x 16D (Z 114..130)
- **Floor/Walls:** Concrete #A9B0B4 (slightly darker than A/B, gradual material drift toward Prism Hall's grandeur)
- **Lighting:** 1x PointLight at (0,13,122), Range 22, Brightness 1.4, Color #D8E8FF
- **Part count:** ~35
- **Connections:** south to Echo Room (Z=114), north to Prism Hall (Z=130)
- **CHARACTER:** the corridor widens in feeling even though it doesn't widen in studs -- the light gets a little more theatrical, foreshadowing Prism Hall.
- **LIFE:** ambient dust-mote particle drift begins here (carried over visually into Prism Hall); no Echo sighting in this corridor (deliberate -- not every corridor needs one, keeps the sightings feeling organic rather than metronomic).

### Prism Hall (Room 3)
- **Position:** Vector3(0, 11, 148) | **Dimensions:** 34W x 20H x 36D (X -17..17, Z 130..166) -- note taller ceiling (20 studs, center Y=11) to sell the "cathedral" character; this is an intentional exception to the standard 14-stud height, sized down slightly from the Master Lock Room's 22 so the finale still reads as the tallest space
- **Floor:** Marble-look SmoothPlastic, #1B1F26 (dark, so beams read clearly) | **Walls:** Concrete, #2B2F36 | **Accents:** ClearGlass + frosted glass panels
- **Lighting:** 1x emitter SpotLight (white) at (0,4,133), Range 40; colored Beam instances (scripted, not static lights) tracing the current beam path; ambient PointLights kept deliberately dim (Brightness 0.6) so the colored beams are the dominant light source in the room
- **Part count:** ~200
- **Connections:** south to Corridor C (Z=130), north doorway Z=166 X=0 width 8 to Corridor D (LOCKED until solved)
- **Key objects:** emitter housing at (0,4,133) (8 parts); 3 rotator prism/mirror blocks at (-8,4,144)/(0,4,150)/(8,4,156) (~12 parts each, 36 total, ProximityPrompt "Rotate" cycles facing 0/90/180/270); receiver housing + target-color display at (0,4,163) (10 parts); door mechanism (10 parts)
- **CHARACTER:** a cathedral of light and glass -- tall, echoing, colored beams cutting through haze like stained glass come alive. The most beautiful room in the vault, and the first to feel like something bigger than a test chamber is watching.
- **LIFE:** ambient -- the beam hums and flickers subtly while unsolved; dust motes drift visibly through the light shafts via a low-density Atmosphere haze. Triggered -- rotating a prism gives a satisfying mechanical *thunk* and a brief flash-preview of the resulting beam color. One-time -- the first correct beam-to-receiver lock makes the receiver ring like a bell and pulses light outward across the entire room (signature-adjacent beat, sets up the visual language reused at full scale in The Convergence).

### Corridor D
- **Position:** Vector3(0, 7, 174) | **Dimensions:** 8W x 14H x 16D (Z 166..182)
- **Floor/Walls:** Concrete #A9B0B4 | **Lighting:** 1x PointLight (0,13,174), Range 20, Brightness 1.2
- **Part count:** ~35
- **Connections:** south to Prism Hall (Z=166), north to Pressure Garden (Z=182)
- **CHARACTER:** a brief cool-down after Prism Hall's spectacle, deliberately unremarkable -- the calm before the warm dip of the Garden.
- **LIFE:** ambient flicker every ~10s; ~15% chance of an Echo sighting through a small floor-level grate window (a new sighting angle, variety over Corridor A/B's wall window).

### Pressure Garden (Room 4)
- **Position:** Vector3(0, 7, 197) | **Dimensions:** 30W x 14H x 30D (X -15..15, Z 182..212)
- **Floor:** Grass-textured SmoothPlastic, #7BAE6F | **Walls:** Wood-look, #B08B5C | **Accents:** planter boxes in R/G/B/Y
- **Lighting:** warmer palette here -- 4x SpotLights at room corners, Brightness 1.8, Color #FFE9C7 (deliberately warm/safe, contrasting the cool corridors)
- **Part count:** ~170
- **Connections:** south to Corridor D (Z=182), north doorway Z=212 X=0 width 8 to Corridor E (LOCKED until solved)
- **Key objects:** a wall-mounted "garden map" pattern display at (0,8,184) (8 parts) showing which plates need covering; 6 pressure plates arranged in a plus-shape at room center (~6 parts each, 36 total, colors R/G/B/Y + 2 decoy neutral plates NOT part of the solution); 6 pushable color cubes scattered nearby (Unanchored=true, CanCollide=true, low friction, 2 parts each, 12 total) -- 4 needed, 2 decoys, so the player must actually read the pattern rather than shove everything everywhere; fake foliage/planters (~30 parts, decorative); door mechanism (10 parts)
- **CHARACTER:** an indoor garden gone artificial -- fake foliage in primary colors, like a greenhouse designed by committee. Warmer and more open than every room before it: a deliberate breather before the vault's tone curdles in Static Vault.
- **LIFE:** ambient -- a soft misting/watering hiss over the fake garden every ~12s. Triggered -- each correctly-filled plate lights up and chimes individually the moment a cube settles on it, building an audible countdown as the player nears completion. One-time -- on full pattern completion, every correct plate blooms bright simultaneously and fires a burst of colored particle "petals" upward.
- **Note on mechanic:** this is intentionally the ONE room with no player-fired RemoteEvent at all -- PlateController watches `.Touched`/`.TouchEnded` on the plates server-side and reacts purely to physics. Worth calling out explicitly: not every puzzle needs a request/response round-trip, and this variety (a physical, tactile room among several UI-adjacent ones) is deliberate pacing, not an oversight.

### Corridor E
- **Position:** Vector3(0, 7, 220) | **Dimensions:** 8W x 14H x 16D (Z 212..228)
- **Floor/Walls:** Concrete, shifting from #A9B0B4 toward #6B6F73 (material tone getting darker/industrial as the vault ages further)
- **Lighting:** 1x PointLight (0,13,220), Range 18, Brightness 1.0, Color #C9C9B0 (slightly sickly, less blue than earlier corridors)
- **Part count:** ~35
- **Connections:** south to Pressure Garden (Z=212), north to Static Vault (Z=228)
- **CHARACTER:** the last calm breath before the vault stops being a puzzle box and starts feeling like a trap.
- **LIFE:** ambient flicker rate increases to every ~7s (subtle escalation cue); a faint distant klaxon test-beep is audible once here, foreshadowing Static Vault before the player even arrives.

### Static Vault (Room 5)
- **Position:** Vector3(0, 7, 244) | **Dimensions:** 28W x 14H x 32D (X -14..14, Z 228..260)
- **Floor:** CorrodedMetal, #4A4E52 | **Walls:** CorrodedMetal, #3A3D40 | **Accents:** warning amber neon + red alarm strobes
- **Lighting:** 6x amber PointLights slow-pulsing at Brightness 0.8-1.4, positions along both walls every ~10 studs; 2x red strobe lights that activate ONLY during Vault Overload
- **Part count:** ~180
- **Connections:** south to Corridor E (Z=228), north doorway Z=260 X=0 width 8 to Corridor F (LOCKED until solved)
- **Key objects:** a conveyor/track running the room's length at (0,3,232)-(0,3,256) (20 parts) carrying small scripted colored orbs (Unanchored, CanCollide false, moved via TweenService, no real physics needed); a chute at the south end spawning orbs at random from Config's required colors; 4 color bins at the north end (4 parts each, 16 total); 3 gate levers along the track at (-6,3,240)/(0,3,246)/(6,3,252) (~8 parts each, 24 total, ProximityPrompt "Toggle") that redirect the next orb passing them into the matching bin if flipped correctly, or let it fall into a "waste" chute (hazard-flavored, not actually punishing) if left unflipped/wrong; door mechanism (10 parts)
- **CHARACTER:** the vault's machinery finally shows its age -- rust bleeding through paint, alarms half-working. The first room that feels genuinely industrial and uncaring rather than curious, like the "teaching" phase of the vault is over.
- **LIFE:** ambient -- conveyor clatter loop, amber lights slow-pulsing every ~8s. Triggered -- each correctly sorted orb dings positively and adds to a visible quota counter; each miss buzzes and the waste chute hisses steam. One-time (signature) -- "Vault Overload": if the sort quota (8 correct sorts) is not met before the timer (90s) expires, the klaxon blares and all lights flash red for 4 seconds -- then, rather than failing the player, the timer quietly resets with MORE time on the second attempt, but the conveyor speed permanently increases 50% from that point on (a real, felt difficulty escalation, never a punishing game-over).

### Corridor F
- **Position:** Vector3(0, 7, 268) | **Dimensions:** 8W x 14H x 16D (Z 260..276)
- **Floor/Walls:** CorrodedMetal, #3A3D40, transitioning back toward brighter tones as the Master Lock Room's glow becomes visible ahead through the north doorway
- **Lighting:** 1x PointLight (0,13,268), Range 20, Brightness 1.4, Color #E0E0FF (the vault's light is "healing" as you approach the finale)
- **Part count:** ~35
- **Connections:** south to Static Vault (Z=260), north to Master Lock Room (Z=276)
- **CHARACTER:** the last corridor -- the alarm-red of the Vault fades back toward something closer to Intake Chamber's original clean blue-white, a subconscious "you're near the end" cue delivered entirely through color, no text.
- **LIFE:** ambient -- no flicker here at all (deliberate contrast/relief after Static Vault's chaos); a strong Echo sighting (100% chance, not random) plays once here -- a ghost calmly walking the same direction you are, into the Master Lock Room, then vanishing at the doorway -- the clearest "you are not the first, and you won't be the last" beat in the whole game before the finale confirms it outright.

### Master Lock Room (finale)
- **Position:** Vector3(0, 11, 304) | **Dimensions:** 44W x 22H x 56D (X -22..22, Z 276..332) -- the tallest, largest room in the game, deliberately breaking the established 14-stud ceiling rule to sell "the vault opens up for this"
- **Floor:** Marble-look SmoothPlastic, #14161C | **Walls:** Concrete, #202430 | **Accents:** all 5 palette colors present simultaneously (this is the one room allowed to be "loud")
- **Lighting:** central dais SpotLight (white, dim until charged) at (0,2,304); 4x station SurfaceLights color-matched to each station's mechanic; ceiling retract mechanism reveals a bright skylight-like void on completion; low ambient PointLights kept dim (Brightness 0.5) so the 4 converging beams dominate visually
- **Part count:** ~350
- **Connections:** south to Corridor F (Z=276); north wall (Z=332) is the EXIT -- a wide light-filled opening (not a puzzle door) that only opens after The Convergence completes
- **Key objects:**
  - Station A (Mini Mixing) at (-16,3,285): 2 stepped levers instead of 3, same ProximityPrompt-tap interaction as Room 1 (~40 parts)
  - Station B (Mini Sequence) at (16,3,285): 3-panel version of Echo Room's mechanic (~40 parts)
  - Station C (Mini Prism) at (-16,3,323): single rotator aligning a fixed emitter to a fixed receiver (~40 parts)
  - Station D (Mini Plate) at (16,3,323): one pressure plate + one pushable cube (~40 parts)
  - Central dais/pillar at (0,2,304) (20 parts) -- receives one beam from each solved station, visually combining into a bright white/rainbow core once all 4 are charged
  - Ceiling retract mechanism (10 parts, scripted CFrame slide on completion)
  - Wall of Echoes at the north wall, (0,11,330) -- a large wall mostly built from decals/textures (not individual parts) showing up to 200 small handprint marks in the colors of every player who ever finished the game, plus ONE interactive ProximityPrompt slot at (0,6,330) where the current player presses their own hand (~30 parts total, kept low because most of the visual density is decal-driven, not part-driven)
  - Exit light box beyond the north wall (20 parts) -- a simple bright void dressed with a soft skybox suggesting the outside world
- **CHARACTER:** the heart of the vault -- part cathedral, part reactor core. Every color mechanic the player has learned converges here. It must feel like the culmination of a story, not just "four puzzles stapled together."
- **LIFE:** ambient -- a low reactor-hum loop; all 4 unlit station pillars pulse very faintly, waiting. Triggered -- each station solved sends a visible beam-pulse traveling along the floor toward the central dais, and the dais gets visibly brighter with each of the 4 (clear, wordless progress feedback -- reinforced by the 4 HUD pips). One-time (signature) -- "The Convergence": the moment all 4 stations are solved, the dais fully charges, the ceiling panels grind open, light floods the room -- immediately followed by "Wall of Echoes": the exit stays sealed until the player walks up and presses the ProximityPrompt at the handprint slot, which fires RequestPlaceHandprint, permanently adds their SignatureColor to the wall for every future player to see, and only THEN opens the exit.

---

## Door Connections
```
IntakeChamber <-> CorridorA:      doorway at (0, 7, 24),  width 8  [UNLOCKED, only open door]
CorridorA     <-> MixingChamber:  doorway at (0, 7, 40),  width 8  [locks Room 1]
MixingChamber <-> CorridorB:      doorway at (0, 7, 70),  width 8  [unlocks on Room 1 solve]
CorridorB     <-> EchoRoom:       doorway at (0, 7, 86),  width 8  [locks Room 2]
EchoRoom      <-> CorridorC:      doorway at (0, 7, 114), width 8  [unlocks on Room 2 solve]
CorridorC     <-> PrismHall:      doorway at (0, 7, 130), width 8  [locks Room 3]
PrismHall     <-> CorridorD:      doorway at (0, 7, 166), width 8  [unlocks on Room 3 solve]
CorridorD     <-> PressureGarden: doorway at (0, 7, 182), width 8  [locks Room 4]
PressureGarden<-> CorridorE:      doorway at (0, 7, 212), width 8  [unlocks on Room 4 solve]
CorridorE     <-> StaticVault:    doorway at (0, 7, 228), width 8  [locks Room 5]
StaticVault   <-> CorridorF:      doorway at (0, 7, 260), width 8  [unlocks on Room 5 solve]
CorridorF     <-> MasterLockRoom: doorway at (0, 7, 276), width 8  [locks Master Room]
MasterLockRoom<-> Exit:           opening at (0, 11, 332), width 20 [opens only after handprint placed]
```
6 locked "PuzzleDoor" instances total (one per puzzle room + the master room), plus the always-open Intake/CorridorA doorway and the finale Exit opening. All doorway widths are 8 studs, well above the 7-stud pathfinding minimum (not that this game has enemies/pathfinding NPCs, but Echo ghosts still traverse these spaces and the margin keeps their scripted movement clean).

---

## Tags

| Tag | Count | Attributes | Purpose |
|-----|-------|------------|---------|
| PuzzleDoor | 6 | RoomId, State (Locked/Unlocked) | door parts DoorController tweens open on solve |
| Lever | 5 (3 Room1 + 2 Station A) | RoomId, LeverId, Value | stepped mixing levers |
| SequenceButton | 7 (4 Room2 + 3 Station B) | RoomId, ButtonId, ColorIndex | memory-sequence inputs |
| PrismRotator | 4 (3 Room3 + 1 Station C) | RoomId, PrismId, Facing | rotatable beam-routing blocks |
| PressurePlate | 7 (6 Room4 + 1 Station D) | RoomId, PlateId, RequiredColor | physics-touch puzzle plates |
| PushableCube | 7 (6 Room4 + 1 Station D) | Color | unanchored colored cubes |
| SortGate | 3 (Room5 only) | RoomId, GateId, State | conveyor orb-routing toggles |
| EchoSpawnPoint | 6 (corridors A/B/D/F + Room2 x2) | RoomId, RecordingSlot | where EchoController may spawn a ghost |
| HandprintSlot | 1 (Master Lock Room) | -- | the single interactive finale ProximityPrompt trigger |

---

## Lighting Design Brief

**Global mood:** a sterile color-research vault gone quiet -- clinical white-blue corridors giving way to increasingly saturated, jewel-toned puzzle chambers, culminating in a room that breaks every rule established before it.

**Color temperature map:** corridors stay cool blue-white throughout (institutional, "unsolved/neutral") except Corridor F, which warms slightly as a wordless "you're near the end" cue. Puzzle rooms start near-neutral and gain saturation as the game progresses (Mixing Chamber is bright-neutral; Static Vault is aggressively warm-amber/alarm-red; Master Lock Room is the only room allowed the full 5-color palette at once). Pressure Garden is the one deliberate warm outlier mid-sequence, functioning as a tonal rest stop.

**Post-processing stack:**
- ColorCorrectionEffect: Saturation +0.05, Contrast +0.1, TintColor (255,255,255) baseline -- kept nearly neutral so puzzle-object colors (the actual gameplay signal) are never distorted by a heavy global tint
- BloomEffect: Intensity 0.4, Size 20, Threshold 0.9 -- enough to make lit puzzle elements and beams glow appealingly without washing out mobile screens
- DepthOfFieldEffect: not used (this game is about reading colors clearly at a distance -- DoF would work against legibility)
- Atmosphere: Density 0.08, Color (200,210,230), Offset 0.2, Haze 0.3 -- deliberately kept well under the 0.3 mobile-visibility caution threshold; used mainly for the dust-mote effect in Prism Hall/Corridor C

**Key dramatic lights (per zone):** see each zone's Lighting entry above. The through-line: PointLights in corridors are always a cool, slightly desaturated blue-white; puzzle-room lighting is driven primarily by the puzzle mechanics themselves (lever glow, panel glow, beam color, alarm strobes) rather than by decorative fixtures, so the room's light IS the puzzle state at a glance.

**Light scripting notes:** Mixing Chamber orb SurfaceLight color updates live with lever state; Echo Room panels pulse independently on idle and flash in unison during sequence playback; Prism Hall beams are Beam instances recolored per server beam-trace; Static Vault lights flip from amber-pulse to red-strobe during Vault Overload; Master Lock Room's 4 station lights individually brighten as each is solved, and the central dais SpotLight brightens in 4 discrete steps then blooms fully on Convergence.

---

## Art Direction Guide

**Color palette (5 colors with roles):**

| Role | Color | Hex | Where used |
|------|-------|-----|------------|
| Primary (dominant surfaces) | Institutional Grey | #C9CFD3 | corridor/room walls, floors, shells |
| Secondary (accents/framing) | Cool Vault Blue | #58C4DC | neon trim, unsolved-door glow, corridor lighting |
| Danger/Alert | Warning Amber-Red | #E0742A / #D93B3B | Static Vault lighting, alarm strobes, waste-chute hazard cues |
| Safe/Interactive | dynamic RGB+Y | #E23B3B / #3BC94A / #3B6FE2 / #E2D23B | every puzzle mechanic's functional color-coding (levers, panels, plates, cubes, beams) -- this "palette" is intentionally NOT fixed, it IS the gameplay language |
| Atmosphere/Finale | Warm Gold-White | #F5E7C8 | Wall of Echoes, exit light box, the Convergence's combined-beam glow |

**Material language:**
- Concrete = institutional shell, neglected but not yet decayed (corridors, most room walls)
- CorrodedMetal = decay/danger nearby (Static Vault exclusively -- the ONE room that uses this material, so its appearance alone signals "this room is different")
- ClearGlass/frosted glass = puzzle windows, Echo sighting points, target-color pedestals (transparency = "something is being shown to you")
- Neon-lit trim/SurfaceLight = active puzzle state, always literally the color it represents (never decorative-only)

**Scale reference:** doorways 10 studs high (within 14-stud rooms, generous headroom), levers/panels/plates sit at 3-4 stud interaction height (comfortable for both walking-up interaction and camera sightlines), ceiling 14 studs standard / 20 studs (Prism Hall) / 22 studs (Master Lock Room) -- rising ceiling height across the game is itself a felt signal of escalating stakes and grandeur.

**Prop density targets:**
- Puzzle rooms (player spends time solving): medium density, focal-point arrangement -- every prop either supports the puzzle or supports the room's CHARACTER, nothing purely decorative competes for attention with the puzzle elements
- Corridors: sparse -- a window, a light, maybe a pipe; corridors are transitions, not content
- Master Lock Room: dense at the 4 stations, sparse everywhere else, so the room's vastness itself reads as awe rather than emptiness

---

## Signature Moments (implementation-ready)

### Moment 1: First Color Bleed
- **Trigger:** player achieves the exact target mix on the Mixing Chamber's 3 levers and the puzzle is solved for the first time this server session
- **What happens:** visual -- the Reveal Orb's color visibly flows down the connecting pipe toward the door in a 1.5s Beam/particle stream; the door itself blooms from dim grey to full bright target-color; audio -- a rising chime resolving into a satisfying mechanical clunk; gameplay -- door slides open
- **Duration:** ~3 seconds total sequence
- **Aftermath:** door stays open/unlocked permanently for the rest of the server session
- **Which agents implement:** luau-scripter (PuzzleManager solve detection + DoorController tween + pipe-flow particle trigger), world-builder (pipe geometry, door part), VFX-designer (color-flow particle stream), sound-designer (chime + clunk)

### Moment 2: The Echo Through Glass
- **Trigger:** player walks within 12 studs of the frosted window in Corridor A (or B), rolled ~20% chance per pass to avoid feeling scripted
- **What happens:** visual -- a translucent, color-tinted R6 silhouette appears behind the glass for ~3 seconds performing a brief wordless action (a recorded EchoRecordings sample, or a simple canned idle if the pool is still empty early in the game's life), then fades; audio -- a faint indistinct murmur/static sting, nothing legible
- **Duration:** ~3 seconds
- **Aftermath:** none mechanical -- pure atmosphere/lore, first seed of the Echoes hook
- **Which agents implement:** luau-scripter (EchoController spawn/despawn + playback), world-builder (frosted glass window geometry), VFX-designer (transparency/tint on the ghost model), sound-designer (murmur/static audio)

### Moment 3: Vault Overload
- **Trigger:** Static Vault's 90-second sort-quota timer expires without the quota (8 correct sorts) being met, first time only per server session
- **What happens:** visual -- all amber lights flash to red strobe for 4 seconds, warning icons pulse; audio -- klaxon blares; gameplay -- timer resets with additional time, but conveyor speed permanently increases 50% from this point forward
- **Duration:** 4 seconds of strobe/klaxon, then gameplay continues at the new speed
- **Aftermath:** Static Vault is permanently harder for the remainder of the room (never resets back down)
- **Which agents implement:** luau-scripter (VaultSolver timer/quota logic + speed escalation), world-builder (strobe light fixtures), VFX-designer (red strobe pulse), sound-designer (klaxon)

### Moment 4: The Convergence
- **Trigger:** all 4 Master Lock Room stations solved (server-tracked, order-independent)
- **What happens:** visual -- the 4 stations' beams travel along the floor to the central dais, which charges fully and blooms bright white/rainbow; the ceiling panels grind open on a scripted CFrame slide, flooding the room with light; audio -- a rising harmonic chord building through each of the 4 station-solves, resolving into a deep mechanical grind + bright chime at full charge; gameplay -- Wall of Echoes finale becomes accessible
- **Duration:** ~6 seconds for the ceiling to fully retract
- **Aftermath:** exit remains sealed until the handprint is placed (Moment 5); room lighting permanently shifts to its "solved" bright state
- **Which agents implement:** luau-scripter (PuzzleManager cross-station completion check + ceiling CFrame tween), world-builder (dais, ceiling retract mechanism), lighting-director (dais SpotLight ramp), VFX-designer (beam-convergence particles), sound-designer (harmonic build + grind + chime)

### Moment 5: Wall of Echoes
- **Trigger:** player interacts with the HandprintSlot ProximityPrompt after The Convergence has completed
- **What happens:** visual -- the player's hand/SignatureColor is added as a new glowing handprint decal among up to 200 existing ones on the wall; a brief personal light-pulse washes over the player; gameplay -- the north Exit opening unseals; audio -- a warm, resolving chime distinct from every prior chime in the game (this one specifically says "you're done, and you're now part of this place")
- **Duration:** ~2 seconds for the handprint placement + immediate exit unseal
- **Aftermath:** the player's SignatureColor + timestamp is permanently written to the WallOfEchoes DataStore (visible to all future players); their recorded room-completion path samples become eligible for future EchoRecordings playback
- **Which agents implement:** luau-scripter (RequestPlaceHandprint validation + DataManager write + FinalHandprintPlaced broadcast + exit unseal), world-builder (wall geometry/exit opening), VFX-designer (handprint decal placement, personal light-pulse), sound-designer (final chime)

---

## Environmental Events (global and per-room)

**Ambient events (periodic, create sense of living world):**
- Intake Chamber overhead flicker: every ~12s, room: Intake Chamber, implemented by: scripter + VFX
- Mixing Chamber Reveal Orb idle pulse: every ~10s, room: Mixing Chamber, implemented by: scripter
- Echo Room panel idle-pulse (independent per panel): every 6-9s, room: Echo Room, implemented by: scripter
- Prism Hall beam hum + dust-mote drift: continuous while unsolved, room: Prism Hall, implemented by: scripter + VFX
- Pressure Garden misting hiss: every ~12s, room: Pressure Garden, implemented by: sound-designer
- Static Vault conveyor clatter + amber pulse: continuous / every ~8s, room: Static Vault, implemented by: scripter + sound-designer
- Master Lock Room reactor hum + station idle-pulse: continuous, room: Master Lock Room, implemented by: scripter + sound-designer
- Corridor A/B/D/F flicker (increasing frequency deeper into the vault, 14s -> 7s): all corridors, implemented by: scripter

**Triggered events (player proximity or action):**
- Lever clunk + partial-match chime: trigger: lever tap in Mixing Chamber/Station A, room: Mixing Chamber + Master Lock Room, cooldown: none (per tap)
- Sequence wrong-buzz + reset: trigger: incorrect button in Echo Room/Station B, effect: progress resets, chime buzzes, room: Echo Room + Master Lock Room
- Prism rotate thunk + beam preview flash: trigger: ProximityPrompt rotate, room: Prism Hall + Master Lock Room
- Plate fill chime: trigger: correct cube settles on plate, room: Pressure Garden + Master Lock Room
- Orb sort ding/buzz: trigger: orb reaches a bin (correct or wrong), room: Static Vault
- Master station beam-pulse-to-dais: trigger: any of the 4 stations solved, room: Master Lock Room

**Scripted sequences (one-time or key-progression moments):**
- First Color Bleed: see Signature Moment 1
- Vault Overload: see Signature Moment 3
- The Convergence: see Signature Moment 4
- Wall of Echoes: see Signature Moment 5

---

## Technical Decisions

**Physics:** everything Anchored=true by default, with three explicit exceptions: PushableCube instances in Pressure Garden and Master Station D (Unanchored, CanCollide=true, low friction, so they can be shoved onto plates); Static Vault conveyor orbs (Unanchored, CanCollide=false, moved via TweenService along a fixed path rather than real physics, to keep server simulation simple and deterministic); Echo ghost NPCs (technically Unanchored per standard R6 rig requirements, but CanCollide=false and never touched by physics -- position is entirely script-driven via CFrame lerp).

**Collision groups:** Echo ghost NPCs are set CanCollide=false specifically so they can never be mistaken for a real obstacle or accidentally block a puzzle interaction -- they are lore/atmosphere only, never gameplay. PushableCubes use default collision (they are meant to be pushed by and block against the player).

**Lighting preset:** a custom Color Lock preset rather than a stock horror/cheerful template -- see Lighting Design Brief above. Baseline is closer to "bright/cheerful" (ClockTime irrelevant indoors, Brightness ~1.2-2 depending on room) but with room-by-room color-temperature drift doing the emotional work that a horror game would otherwise get from darkness.

**Camera:** default Roblox third-person camera for the entire game. Explicitly chosen over a custom first-person rig: it is mobile-friendlier (no need to fight touch-drag camera precision while also tapping ProximityPrompts), requires zero custom CameraController script (keeps scope tight for a single build cycle), and third-person lets players see their own SignatureColor aura, which matters for the Echoes hook to land visually.

**Input mapping:** every interactive puzzle element (levers, sequence buttons, prism rotators, sort gates, the handprint slot) uses a native Roblox ProximityPrompt -- this gives keyboard (E), mobile (tap), and gamepad support automatically with zero custom input code, which is the single biggest scope-saver in this design. PushableCubes need no explicit input at all (they respond to being walked into, per standard Roblox physics). Levers specifically: a single ProximityPrompt per lever, each tap cycles the value up by 25 and wraps 125 back to 0 -- deliberately avoiding any fine-motor drag-slider interaction, which would be painful on a small touchscreen.

**Multiplayer:** shared server instance, co-op-friendly up to standard Roblox server sizes. ALL puzzle state is server-global per room (not per-player) -- friends solve puzzles together on one shared attempt, and any door that has been unlocked stays unlocked for the rest of that server session. There is no PvP, no player-vs-player interaction of any kind. Late joiners receive full current state via PuzzleStateSync on PlayerAdded.

---

## Build Order
1. **Foundation (Config + RemoteEvents + Lighting preset)** -- nothing else can be tested without the shared data structures and the base lighting mood existing first.
2. **Intake Chamber** -- gives an immediately testable spawn point and validates the SignatureColor-assignment system early.
3. **Corridors A-F (skeleton spine)** -- builds full spatial connectivity of the whole game before any puzzle room is detailed, so every subsequent room is being placed into a world that already coheres.
4. **Master Lock Room shell + lighting rig** -- built early specifically because it is the biggest single visual-impact space in the game; getting it standing (even undressed) early gives the whole project a "this is going to be worth it" centerpiece to build toward, per the priority that stream-worthy visual impact should come early.
5. **Mixing Chamber (Room 1)** -- simplest mechanic, validates the lever/ProximityPrompt/SetLeverValue pattern that Station A in the finale will directly reuse.
6. **Prism Hall (Room 3)** -- built next (out of strict room-order) because it is the second-most visually striking space and validates the discrete-state beam-trace logic, which is the riskiest piece of PuzzleManager (see Risk Areas) -- better to prove it works early.
7. **Echo Room (Room 2)** -- validates the sequence-memory pattern and the EchoController hint-ghost system.
8. **Pressure Garden (Room 4)** -- validates the physics-touch PlateController pattern (the one room needing no RemoteEvent).
9. **Static Vault (Room 5)** -- built later deliberately: it depends on the conveyor/timer pattern being the most complex individual system, and benefits from PuzzleManager patterns already being proven in rooms 1-4.
10. **Master Lock Room stations + Convergence logic** -- now wired into the already-standing shell from step 4, reusing every mechanic pattern validated in steps 5-9.
11. **Echoes persistence (DataManager DataStore wiring + Wall of Echoes decal system)** -- the hook's payoff, built once every mechanic it depends on (room-completion detection, SignatureColor) already exists and is proven.
12. **Polish pass** -- set-dressing (garden foliage, vault rust dressing, corridor props), VFX pass (dust motes, particle bursts, beam glow tuning), audio pass, mobile touch-target/legibility verification.

---

## Part Budget
Target max: 2000 (comfortable single-build-cycle scope; hard limit 3000)

**Estimated current design (per-zone, from World Layout above):**
Intake Chamber ~80, Corridors A-F ~35 x 6 = ~210, Mixing Chamber ~150, Echo Room ~130, Prism Hall ~200, Pressure Garden ~170, Static Vault ~180, Master Lock Room ~350. **Subtotal: ~1470 parts.** This leaves roughly 530 parts of headroom under the 2000 target for the detail/set-dressing polish pass (step 12 of Build Order) without needing to cut any room's core mechanic geometry.

**Per-agent allocation:**
| Agent | Budget | % | Notes |
|-------|--------|---|-------|
| world-builder (base geometry) | 1000 | ~50% | walls, floors, ceilings, corridors, doors, room shells |
| detail-architect (architectural trim) | 300 | ~15% | pipes carrying color to doors, panel/lever housings, prism/gate mechanical frames |
| set-dresser (props) | 280 | ~14% | garden foliage/planters, vault rust dressing, record-player lore prop, corridor windows |
| lighting fixtures | 80 | ~4% | physical light housings, station light fixtures |
| VFX anchors | 60 | ~3% | invisible anchor parts for beam/particle emitters, dust-mote emitters |
| Echo NPC rigs | 80 | ~4% | reused standard R6 dummy rig, cloned per concurrent ghost spawn (never more than 1-2 active at once) |
| reserve | 200 | ~10% | buffer for iteration and finale polish (Wall of Echoes decal density, handprint VFX) |

---

## Risk Areas
- **Prism Hall's beam-routing logic is the single riskiest system in the game.** Mitigation: implement it as a small finite graph of discrete rotator facings (0/90/180/270) with a precomputed lookup of resulting paths, NOT real-time raycasting/reflection math -- PuzzleManager recomputes the trace only when a rotator changes state, not every frame.
- **Co-op puzzle-state desync for late-joining players.** Mitigation: PuzzleStateSync fires the complete current state of every room's puzzle on PlayerAdded, before the player can interact with anything.
- **DataStore throttling on the Echoes system at scale.** Mitigation: RecordEchoSample is buffered in memory only and is NEVER written per-sample; DataManager writes only on room completion, in batches, on a 30s flush loop, wrapped in pcall with retry/backoff, and both DataStores are hard-capped (200 handprints, ~50 recordings/room) so they never grow unbounded.
- **Kids getting hard-stuck with zero tutorial text.** Mitigation: every room has a built-in wordless fallback -- Mixing Chamber's "getting warmer" chime, Echo Room's Watch-plate replay + guaranteed hint-ghost after 2 fails, Static Vault's no-fail timer reset. No room can permanently block a player who keeps trying.
- **PushableCube network ownership/lag on mobile.** Mitigation: keep cubes small and lightweight (2 parts each), rely on Roblox's default network ownership handoff rather than custom ownership scripting -- adding custom NetworkOwnership logic would be scope the game doesn't need.
- **Master Lock Room part-count creep from 4 duplicated mechanic stations.** Mitigation: build one lever/panel/rotator/plate "prefab" each and Clone() it per station rather than bespoke-building all 4 stations from scratch -- keeps both build time and part variance down.

---

## Mobile Checklist
- [ ] All puzzle interactions use ProximityPrompt (native keyboard/touch/gamepad support, no custom input code)
- [ ] No fine-motor drag-slider interactions anywhere -- levers are stepped tap-to-cycle, not analog drag
- [ ] HUD is minimal, Scale-based, and limited to a color swatch + 4 progress pips (no dense text UI)
- [ ] Part count (~1470 estimated, 2000 target) comfortably under budget with headroom for polish
- [ ] Atmosphere density kept at 0.08, well under the 0.3 mobile-visibility caution threshold
- [ ] No first-person requirement -- default third-person camera works identically well on touch and desktop
- [ ] Every room solvable without reading a single word of text

---

# Lobby & Welcome (Feature Addition)

**Task type:** TYPE B -- surgical feature addition to the completed core vault. Nothing in the existing document above is redesigned. No existing puzzle room, RemoteEvent, tag, solver, or the Echoes system is altered. This section adds a pre-game space *south* of the existing spine.

**Logical placement:** this section extends the World Layout, Service Architecture, RemoteEvents, Tags, and Part Budget sections above. It slots into the existing **Build Order between step 2 (Intake Chamber) and step 3 (Corridors A-F)** -- see "Build Order Insertion" at the end of this section. The existing Build Order and Part Budget sections are cross-referenced, not rewritten.

## Overview

Color Lock is co-op -- every puzzle is solved once for the whole server (see Technical Decisions > Multiplayer). But players currently materialize alone in the Intake Chamber with no way to notice each other, wait for each other, or start together. This adds a **Lobby**: a warm, ordinary staff antechamber south of the vault where players gather, physically stand on a Ready Pad that ignites in their own SignatureColor, and are pulled through the Vault Gate together when everyone is standing. Plus a **welcome screen** that names the game and its premise in one line and dismisses in one tap.

The design goal beyond function: make the *temperature drop* into the Intake Chamber land. The Lobby is the warmest-lit room in the entire game. When the gate opens and the vault takes you, the cold blue-white of Intake Chamber reads as a physical loss -- an emotional beat the existing Intake Chamber gets for free, without a single change to it.

## Feature Scope

- **Type:** new pre-game room + readiness mechanic + intro UI
- **Flavor:** HYBRID (spatial: one room; systemic: one server script, one client script, two S->C RemoteEvents, one Config table)
- **Subagents needed:** world-builder (room + gate + pads), luau-scripter (LobbyController, LobbyUIController, Main modification, Config), ui-designer (WelcomeFrame / LobbyFrame polish), sound-designer (readiness chord, gate grind), lighting-director (warm lobby palette, gate light-wash). set-dresser optional -- the room is deliberately sparse.
- **New parts:** ~85 (budget cap 100)
- **New scripts:** 2 new, 1 modified, 1 GUI property change. Seven existing scripts explicitly need **no** change -- listed below so nobody guesses.
- **World changes to existing geometry:** exactly one -- an 8x10 stud doorway cut into the Intake Chamber's south wall at Z=0 (that wall is currently solid).

---

## Design: the Ready Pad ring

**Why pads and not a button or a menu.** Readiness is *physical*: you stand on a lit ring on the floor. This is the cheapest possible co-op ritual -- everybody understands "all of us stand on the circles" in under two seconds, with zero text, on any device, with zero taps. It also means **the lobby needs no client->server RemoteEvent at all** -- readiness is read from `.Touched`/`.TouchEnded` server-side, exactly the pattern already proven by PlateController in the Pressure Garden. There is nothing for a client to lie about. This is a deliberate security property, not an accident.

**The rule:** the countdown starts when **every non-idle player currently in the server is standing on a Ready Pad.** Solo players are fully supported -- one player, one pad, 4-second countdown. A group of six must physically gather, and the countdown is 8 seconds. Stepping off cancels it.

**AFK valve (the one edge case worth designing):** a player who has been in the Lobby for 90 seconds and has *never* stepped on a pad is flagged `idle = true` and excluded from the "everyone is ready" requirement, so one AFK player cannot hold a whole server hostage. Stepping on a pad clears `idle` permanently for that session. Idle players are still teleported in with the group.

**The readiness chord.** Each pad that ignites plays a chime one scale-step above the previous one, so a lobby filling up builds an audible ascending chord and a full lobby resolves it. Stepping off plays the descending tone. This is the entire "we're doing this together" feeling, delivered with no UI and no words. (sound-designer owns this; LobbyController fires the index so the pitch is deterministic.)

## Signature Moment 6: The Intake

- **Trigger:** the lobby countdown reaches 0.
- **What happens:** the Central Beacon blooms with every ready player's SignatureColor at once (a brief, literal picture of the group); the Vault Gate grinds open on a 1.5s TweenService slide and cold blue-white vault light floods into the warm lobby; 1.5s later every player in the server is CFrame'd through it to a staggered entry point inside the Intake Chamber, with a 0.3s white client-side flash; 3s after that, the gate re-seals behind them with a heavy mechanical thud.
- **Duration:** ~5 seconds end to end.
- **Aftermath:** RunState becomes `"Running"` permanently for the server session. All later joiners spawn directly inside the Intake Chamber. The player walks forward onto the existing Scan Pad and the existing "your aura ignites" beat plays exactly as already designed -- unchanged.
- **Which agents implement:** luau-scripter (countdown, gate tween, teleport, state transition), world-builder (gate assembly, entry points), lighting-director (the cold-light wash through the open gate), VFX-designer (beacon bloom, client flash), sound-designer (grind, thud, resolving chord).

**Note on the two color beats -- do not collapse them.** The Lobby pad is the *first sighting* of your SignatureColor: quiet, small, a claim on a floor tile. The Intake Chamber Scan Pad is the *ignition*: the vault takes your color and wraps your body in it. Two beats, escalating. The Scan Pad's logic, aura, and chime are untouched by this feature.

---

## World Layout: Lobby

The spine's Z-numbering above is unchanged. The Lobby occupies negative Z, south of the Intake Chamber, abutting it at Z=0.

### Lobby
- **Position:** Vector3(0, 7, -15) -- center
- **Dimensions:** 28W x 14H x 30D studs (X -14..14, Y 0..14, Z -30..0)
- **Floor:** SmoothPlastic, #D8D2C6 (warm off-white, visibly scuffed -- the only warm floor before the Pressure Garden)
- **Walls:** Concrete, #C9CFD3 (the established Primary/Institutional Grey -- this room belongs to the same building, just a kinder part of it)
- **Accents:** Cool Vault Blue #58C4DC on the Vault Gate seam ONLY (the gate is the one thing in the room that reads as vault, not as staff room); everything else warm-neutral
- **Lighting:** 4x ceiling PointLights at (-7,13,-8), (7,13,-8), (-7,13,-22), (7,13,-22), Range 26, Brightness 1.6, Color **#E8E4DC** -- deliberately the warmest ambient light in the game. Plus 1x SpotLight above the Central Beacon at (0,13,-14), Range 18, Brightness 1.0, Color #F5E7C8, whose Brightness ramps 1.0 -> 3.0 across the readiness fill.
- **Part count:** ~85 (breakdown below)
- **Connections:** north wall at Z=0 -- the **Vault Gate**, doorway at (0, 5, 0), width 8, height 10, sealed by default. This is the room's only exit. Floor slab extends 3 studs north past Z=0 into the Intake Chamber per the global zero-gap floor rule stated at the top of World Layout.
- **CHARACTER:** a decommissioned staff antechamber -- the last room in this building that was ever ordinary. Someone used to hang a coat here. The floor has a faded painted ring where staff lined up for intake, the benches are worn smooth, and the light is warm because it was built for people who got to go home at the end of the day. Everything is soft and dated and slightly too quiet. The gate at the north end is the only object in the room that looks maintained, and it is enormous.
- **LIFE:** *ambient* -- the Central Beacon breathes a slow 4s pulse; a low HVAC hum; the Vault Gate's seam-glow ripples faintly every ~9s like something on the other side is cycling. *Triggered* -- stepping onto a pad ignites it in your SignatureColor with the ascending chord chime; stepping off dims it with a descending tone; the Beacon brightens one discrete step per ready player. *One-time* -- Signature Moment 6, The Intake.

### Key objects and exact positions

| Object | Position | Parts | Notes |
|--------|----------|-------|-------|
| Room shell (floor, ceiling, E/W walls, S wall, N wall as 2 flanks + lintel) | -- | 8 | N wall flanks span X -14..-4 and X 4..14 at Z=0; lintel spans X -4..4 above Y=10 |
| Faded floor-marking ring (thin cylinders, decorative) | centered (0, 0.05, -14), radius 9 | 4 | the painted ring staff used to line up on |
| **Ready Pads x8** (3 parts each: base ring, inner disc, glow rim) | ring of radius 7 centered on (0, 0.25, -14) -- list below | 24 | 5-stud diameter cylinders, 0.5 thick |
| Central Beacon (obelisk + 4 stacked light bands + cap) | (0, 4, -14) | 10 | height 8, footprint 3x3; SurfaceLights per band |
| Vault Gate assembly (slab, 2 jambs, lintel plate, 4 seam-glow strips, hazard stripes, track) | (0, 5, 0) | 12 | slab slides +Y 10 studs on open |
| Ceiling light housings x4 | matching the 4 PointLight positions | 8 | |
| Wall mural (west wall, wordless: 3 overlapping colored discs blending) | (-13.5, 7, -14) | 6 | echoes the existing Intake Chamber "practice wall" -- silent foreshadowing, zero text |
| Benches x2 | (-11, 1, -24) and (11, 1, -24) | 6 | worn, near spawn |
| Floor arrow markers pointing north toward the gate | (0, 0.05, -26), (-4, 0.05, -26), (4, 0.05, -26), (0, 0.05, -20) | 4 | wordless wayfinding |
| VFX anchors (gate light-wash, beacon bloom) | (0, 5, -1), (0, 8, -14) | 2 | invisible, Transparency=1, CanCollide=false |
| **LobbySpawn** (SpawnLocation) | (0, 1, -25) | 1 | Neutral=true, Enabled=true, faces +Z so players spawn looking north at the pads with the gate beyond |
| **Total** | | **~85** | 15 parts of headroom under the 100 cap |

**Ready Pad positions** (radius 7 around (0, 0.25, -14), 45-degree increments; PadId in parentheses):

```
Pad1  ( 0.00, 0.25,  -7.00)
Pad2  ( 4.95, 0.25,  -9.05)
Pad3  ( 7.00, 0.25, -14.00)
Pad4  ( 4.95, 0.25, -18.95)
Pad5  ( 0.00, 0.25, -21.00)
Pad6  (-4.95, 0.25, -18.95)
Pad7  (-7.00, 0.25, -14.00)
Pad8  (-4.95, 0.25,  -9.05)
```

Eight pads covers a comfortable co-op group. On servers with more than 8 players, the 9th+ player is auto-flagged `idle` on join if all pads are occupied, so they never block the countdown (specified in LobbyController below).

### Existing geometry change (world-builder -- the only one)

**Intake Chamber south wall.** Currently solid at Z=0 (the Intake Chamber spans Z 0..24; its only listed doorway is the north one at Z=24). Cut an **8-stud-wide, 10-stud-high doorway at (0, 5, 0)**, centered on X=0, matching every other doorway's dimensions in the game. The Vault Gate slab seals it. Nothing else in the Intake Chamber changes -- the Scan Pad at (0,0.5,6), the practice wall at (10,7,4), the lighting, and the north doorway at Z=24 are all untouched.

### Intake entry points (teleport destinations)

Four staggered CFrames inside the Intake Chamber, south of and facing the existing Scan Pad, so players are never stacked and always walk forward onto the Scan Pad naturally:

```
(-3, 4, 2)   (3, 4, 2)   (-3, 4, 4)   (3, 4, 4)     -- all facing +Z (toward the Scan Pad)
```
Players beyond 4 cycle through the same list with a +1 stud Y offset per wrap to avoid intersection.

### IntakeSpawn (SpawnLocation)

A second SpawnLocation, **IntakeSpawn**, at **(0, 1, 3)** inside the Intake Chamber. Neutral=true, Enabled=true. This is where players who join *after* the run has started respawn. It is deliberately south of the Scan Pad so late joiners still get the Scan Pad beat.

---

## System Design

### RunState

A server-global, session-lifetime state with exactly two values, owned solely by LobbyController:

| State | Meaning | Set by |
|-------|---------|--------|
| `"Lobby"` | pre-run; players spawn in the Lobby; ready pads live | LobbyController on server start |
| `"Running"` | the vault run has begun; players spawn in the Intake Chamber; pads inert | LobbyController when the countdown hits 0 |

**RunState never returns to `"Lobby"`** for the life of the server session, including when every player leaves. This deliberately matches the existing rule that unlocked doors never re-lock (see DoorController, Service Architecture) -- a server that has been "opened" stays open, and this consistency is what keeps late-joiner handling simple everywhere.

**Single writer, many readers.** LobbyController is the only writer. It mirrors the value to `ReplicatedStorage:SetAttribute("RunState", <string>)` so Main (and clients, for free, via attribute replication) can read it without a new RemoteEvent or a circular script dependency.

### Config additions

**Config (ModuleScript) -- ReplicatedStorage/Modules/Config**

Existing pattern: Config holds `ROOM_DEFINITIONS`, `PALETTE`, `SIGNATURE_COLOR_POOL` as flat top-level tables. Follow it -- add one new sibling table. **Do NOT add "Lobby" to `ROOM_DEFINITIONS`.** The Lobby is not a puzzle room, and keeping it out of `ROOM_DEFINITIONS` means SecurityValidator's existing roomId whitelist check and EchoController's "discard samples for rooms the player has not entered" check both reject any lobby-scoped roomId automatically, with zero code changes to either script.

```lua
Config.LOBBY = {
    MIN_PLAYERS            = 1,      -- number: solo play is fully supported; never gate on 2+
    COUNTDOWN_SECONDS      = 8,      -- number: used when 2 or more non-idle players are present
    SOLO_COUNTDOWN_SECONDS = 4,      -- number: used when exactly 1 non-idle player is present
    IDLE_TIMEOUT           = 90,     -- number (seconds): never touched a pad in this long -> flagged idle
    PAD_COUNT              = 8,      -- number: must match the ReadyPad-tagged part count in Workspace
    PAD_RADIUS             = 7,      -- number (studs): used by world-builder + structural verification
    SYNC_THROTTLE          = 0.25,   -- number (seconds): min interval between LobbyStateSync fires
    GATE_OPEN_SECONDS      = 1.5,    -- number: gate slide-open tween duration
    TELEPORT_DELAY         = 1.5,    -- number: seconds between gate opening and the teleport firing
    GATE_RESEAL_DELAY      = 3.0,    -- number: seconds after teleport before the gate re-seals
    SAFETY_SWEEP_INTERVAL  = 5,      -- number: seconds between "anyone stranded south of Z=0?" sweeps
    LOBBY_BOUNDARY_Z       = 0,      -- number: any player with Position.Z < this while Running is stranded
    WELCOME_AUTO_DISMISS   = 6,      -- number: seconds before the welcome screen self-dismisses
    INTAKE_ENTRY_POINTS = {          -- {CFrame}: teleport destinations, cycled per player
        CFrame.new(-3, 4, 2), CFrame.new(3, 4, 2),
        CFrame.new(-3, 4, 4), CFrame.new(3, 4, 4),
    },
}
```

Read by: LobbyController (all fields, server), LobbyUIController (`WELCOME_AUTO_DISMISS` only, client). Written by: nobody at runtime.

### Runtime state (LobbyController, server memory only)

```lua
-- RunState           : "Lobby" | "Running"
-- padOccupancy       : {[padId: string]: number}   -- userId, or 0 for empty
-- playerState        : {[userId: number]: {ready: boolean, idle: boolean, joinedAt: number, everReady: boolean}}
-- countdownRemaining : number?                     -- nil when not counting
-- countdownToken     : number                      -- incremented on every start/cancel
```

None of this persists. There is **no DataStore involvement in this feature at all** -- DataManager needs no change.

### New RemoteEvents

Both are server -> client only. **There are zero new client -> server RemoteEvents**, because readiness is physical (`.Touched`) and welcome-screen dismissal is purely local. SecurityValidator therefore needs no change.

| Event | Direction | Payload | Server Validation |
|-------|-----------|---------|-------------------|
| `LobbyStateSync` | S->C | `{runState: string, countdown: number?, entries: {{userId: number, color: Color3, ready: boolean, idle: boolean}}}` | -- |
| `VaultRunStarted` | S->C | `{}` | -- |

**`LobbyStateSync` fires on:** PlayerAdded (fired to that player immediately, so a joiner sees the current lobby before they can move), PlayerRemoving, any pad enter/exit, countdown start, each countdown tick (1/s), countdown cancel, and the run start. Coalesced to at most one fire per `SYNC_THROTTLE` (0.25s) so a player jittering on a pad edge cannot spam the network. `countdown` is `nil` unless a countdown is active. `entries` is ordered by userId for stable pip ordering on the client.

**`VaultRunStarted` fires once**, broadcast to all clients, at the moment the countdown hits 0 -- it is the client's cue for the white flash and the HUD reveal. It carries no payload; everything the client needs is already in the last `LobbyStateSync`.

This mirrors the existing `PuzzleStateSync` pattern exactly: one rich state-snapshot event for sync and late joiners, plus discrete one-shot broadcasts for moments.

### UI architecture

The existing `StarterGui.GameUI` ScreenGui is reused -- no new ScreenGui. Both new frames are siblings of the existing `HUD` frame.

```
StarterGui/
  GameUI (ScreenGui)                              [EXISTING]
    HUD (Frame)                                   [EXISTING -- one property change: Visible = false]
    WelcomeFrame (Frame)                          [NEW]  ZIndex 50, Visible=true, BackgroundTransparency=1
      Backdrop (Frame)                            Size (1,0,1,0), Pos (0,0,0,0), BackgroundColor3 black,
                                                  BackgroundTransparency 0.45, ZIndex 50
      TitleLabel (TextLabel)                      Size (0.8,0,0.14,0), AnchorPoint (0.5,0.5),
                                                  Pos (0.5,0,0.38,0), TextScaled=true, ZIndex 51
                                                  Text: "COLOR LOCK"
      PremiseLabel (TextLabel)                    Size (0.7,0,0.06,0), AnchorPoint (0.5,0.5),
                                                  Pos (0.5,0,0.50,0), TextScaled=true, ZIndex 51
                                                  Text: "Every door in this vault reads your answer in light."
      DismissHint (TextLabel)                     Size (0.4,0,0.04,0), AnchorPoint (0.5,0.5),
                                                  Pos (0.5,0,0.72,0), TextScaled=true, ZIndex 51
                                                  Text: "tap to begin"
      DismissButton (TextButton)                  Size (1,0,1,0), Pos (0,0,0,0), BackgroundTransparency=1,
                                                  Text="", ZIndex 52  -- full-screen tap target
    LobbyFrame (Frame)                            [NEW]  ZIndex 20, Visible=false, BackgroundTransparency=1
                                                  Size (0.5,0,0.18,0), AnchorPoint (0.5,1),
                                                  Pos (0.5,0,0.94,0)
      ReadyPips (Frame)                           Size (1,0,0.4,0), AnchorPoint (0.5,0.5),
                                                  Pos (0.5,0,0.30,0), BackgroundTransparency=1
                                                  + UIListLayout (FillDirection Horizontal,
                                                    HorizontalAlignment Center, Padding UDim(0.01,0))
        Pip_<userId> (Frame)                      Size (1,0,1,0) + UIAspectRatioConstraint
                                                  (AspectRatio=1, DominantAxis=Height)
                                                  -- created/destroyed per player by LobbyUIController
      CountdownLabel (TextLabel)                  Size (0.3,0,0.45,0), AnchorPoint (0.5,0.5),
                                                  Pos (0.5,0,0.72,0), TextScaled=true, Visible=false
      HintLabel (TextLabel)                       Size (0.6,0,0.30,0), AnchorPoint (0.5,0.5),
                                                  Pos (0.5,0,0.72,0), TextScaled=true, Visible=true
                                                  Text: "STAND ON A PAD"
```

`CountdownLabel` and `HintLabel` occupy the same slot and are mutually exclusive -- `HintLabel` shows until any pad is occupied for the first time, then `CountdownLabel` takes over during a countdown.

**Pip rendering rule:** one pip per player in `entries`. `ready == true` -> pip filled with that player's SignatureColor, BackgroundTransparency 0. `ready == false` -> hollow: BackgroundTransparency 0.7 plus a UIStroke in that player's SignatureColor. `idle == true` -> same as not-ready but with UIStroke Transparency 0.6 (visibly "not counted"). The local player's own pip is rendered at a slightly larger scale so they can find themselves at a glance. This is the whole lobby UI -- no names, no text list, no scoreboard.

**UI flow:**
1. Player joins -> spawns at LobbySpawn -> `WelcomeFrame` is visible immediately (semi-transparent, so the lobby is legible behind it -- deliberately not a black title card).
2. Player taps anywhere / presses E / 6 seconds elapse -> `WelcomeFrame` fades out over 0.4s (TweenService on Backdrop.BackgroundTransparency and all TextTransparency) and is then set `Visible=false`. Shown **once per session** -- a module-scope boolean in LobbyUIController prevents it re-appearing on respawn or death.
3. If `runState == "Lobby"`: `LobbyFrame.Visible = true`, `HUD.Visible = false`.
4. Pips update on every `LobbyStateSync`. Countdown ticks show in `CountdownLabel`.
5. `VaultRunStarted` -> 0.3s white full-screen flash (a temporary Frame created in code, then destroyed), `LobbyFrame` fades out and `Visible=false`, `HUD.Visible = true`.
6. If a player joins when `runState == "Running"`: `WelcomeFrame` still shows (it's their first time), `LobbyFrame` never appears, `HUD.Visible = true` immediately.

**Scripter vs ui-designer boundary:** luau-scripter creates the full hierarchy above, wires `DismissButton.Activated` / the ContextActionService E-binding / the auto-dismiss timer, drives Visible/Text/BackgroundColor3 on pips, and owns all TweenService fades. **ui-designer touches visual properties only** -- Font, TextColor3, TextStrokeTransparency, UICorner, UIStroke, UIGradient, UIPadding, and the Backdrop's color. ui-designer must not change `Text` content, `Visible`, `Size`, `Position`, `AnchorPoint`, or any instance name (LobbyUIController looks all of these up by name).

**Style notes for ui-designer:** genre is puzzle/escape-room, not horror -- the welcome screen should feel *institutional and clean*, not spooky. Think a facility signage plate: a heavy geometric font for the title, generous letter-spacing, near-white on the dark backdrop, with the title's letters ideally picking up the game's Safe/Interactive RGB+Y palette (see Art Direction Guide) so the word "COLOR" is literally in color. `DismissHint` should be small and low-contrast. Pips are simple circles (UICorner CornerRadius UDim(0.5,0)) -- no icons, no labels.

---

## Script Modifications

### NEW: `ServerScriptService.LobbyController` (Script)

- **Purpose:** owns RunState, ready-pad occupancy, the countdown, the idle valve, the gate tweens, the teleport, and the stranded-player safety sweep. The single authority for everything pre-run.
- **Depends on:** `Config.LOBBY`, CollectionService (`ReadyPad`, `VaultGate` tags), TweenService, the `SignatureColor` player attribute set by Main, and the `LobbyStateSync` / `VaultRunStarted` RemoteEvents.
- **Key functions:**
  - `init()` -- sets `RunState = "Lobby"`, mirrors it to `ReplicatedStorage:SetAttribute("RunState", "Lobby")`, collects the 8 `ReadyPad`-tagged parts, binds `.Touched` / `.TouchEnded` on each, starts the safety-sweep loop.
  - `onPadTouched(pad, hit)` / `onPadTouchEnded(pad, hit)` -- resolves `hit` to a Player via its character's Humanoid; ignores non-player touches and all touches while `RunState == "Running"`. Sets `padOccupancy[padId]`, sets `playerState[userId].ready`, sets `everReady = true`, clears `idle`, recolors the pad's glow rim to that player's SignatureColor (or back to neutral #9AA0A4 on exit), fires the pad's chime index, and calls `evaluate()`.
  - `evaluate()` -- recomputes whether every non-idle player is ready. Starts the countdown if so (`SOLO_COUNTDOWN_SECONDS` if exactly 1 non-idle player, else `COUNTDOWN_SECONDS`); cancels a running countdown if not.
  - `tick()` -- a single `task.spawn`ed loop on `task.wait(1)` that decrements `countdownRemaining`, fires `LobbyStateSync`, and calls `startRun()` at 0. Guarded by `countdownToken`, incremented on every start/cancel: a stale coroutine sees a changed token and returns immediately, so rapid pad on/off can never stack countdowns.
  - `startRun()` -- sets `RunState = "Running"` and mirrors the attribute; fires `VaultRunStarted` to all; blooms the Beacon; tweens the gate slab open over `GATE_OPEN_SECONDS`; after `TELEPORT_DELAY`, CFrames every player's HumanoidRootPart to a cycled `INTAKE_ENTRY_POINTS` entry and sets every player's `RespawnLocation = IntakeSpawn`; after `GATE_RESEAL_DELAY`, tweens the gate closed and sets its `State` attribute to `"Sealed"`.
  - `safetySweep()` -- every `SAFETY_SWEEP_INTERVAL` seconds while `RunState == "Running"`, any player whose HumanoidRootPart Z is less than `LOBBY_BOUNDARY_Z` is CFrame'd to an entry point. This exists because the gate re-seals: a player whose teleport failed (dead at that instant, character still loading, network hiccup) would otherwise be permanently trapped. **This sweep is not optional.**
  - `syncAll()` -- builds the `entries` array and fires `LobbyStateSync`, coalesced to `SYNC_THROTTLE`.
  - `onPlayerAdded(player)` -- records `joinedAt`, starts the idle timer, fires `LobbyStateSync` to that player immediately. If `RunState == "Running"` OR all pads are already occupied, flags `idle = true` on join so they can never block a countdown.
  - `onPlayerRemoving(player)` -- clears their pad and state, then calls `evaluate()` (a countdown continues if the remaining players are all still ready; it cancels if nobody is left).
- **Edge cases it must handle explicitly:**
  - A player joining *during* an active countdown does **not** cancel it -- they are flagged idle-on-join per above and are teleported in with the group. (Cancelling on every join would let a busy server loop forever.)
  - A player dying in the Lobby respawns at LobbySpawn, off their pad. `.TouchEnded` may or may not fire on a destroyed character, so `evaluate()` must independently verify that each claimed occupant still has a living character before counting them ready. **Treat pad occupancy as a claim to be verified, never as truth.**
  - Two players on one pad: last-toucher wins; the displaced player is marked not-ready. The other 7 pads are free.
  - `RunState == "Running"`: pads are inert -- `.Touched` returns immediately, no chimes, no recolor.
  - Connection cleanup: pad connections live for the server's lifetime (the pads are never destroyed), but the countdown coroutine and the idle timers must be cancelled on PlayerRemoving to avoid leaked references to departed players.

### NEW: `StarterPlayer.StarterPlayerScripts.LobbyUIController` (LocalScript)

- **Purpose:** owns `WelcomeFrame`, `LobbyFrame`, and the `HUD.Visible` toggle. Deliberately a *separate* script from the existing UIController so that UIController's already-reviewed code is never reopened.
- **Depends on:** `Config.LOBBY.WELCOME_AUTO_DISMISS`, `LobbyStateSync`, `VaultRunStarted`, TweenService, ContextActionService (E-key dismiss binding).
- **Key functions:** `showWelcome()`, `dismissWelcome()` (idempotent, guarded by a `welcomeShown` boolean so it never re-fires on respawn), `renderPips(entries)` (creates/updates/destroys `Pip_<userId>` frames), `renderCountdown(n)`, `onRunStarted()` (white flash, hide LobbyFrame, show HUD).
- Client-only. Sends nothing to the server. Reads nothing authoritative.

### MODIFY: `ServerScriptService.Main`

- **CURRENTLY:** on `PlayerAdded`, computes a deterministic SignatureColor hashed from UserId, and spawns the player at the Intake Chamber.
- **CHANGE 1 -- expose the color.** After computing the SignatureColor, also call `player:SetAttribute("SignatureColor", color)`. LobbyController and LobbyUIController both need the color and neither should re-derive the hash. This is the minimal integration point -- no new RemoteEvent, and attribute replication delivers it to clients for free.
- **CHANGE 2 -- spawn location.** Replace the "spawn at Intake Chamber" logic with:
  ```lua
  if ReplicatedStorage:GetAttribute("RunState") == "Running" then
      player.RespawnLocation = IntakeSpawn
  else
      player.RespawnLocation = LobbySpawn
  end
  ```
  **Always set `RespawnLocation` explicitly for every player, every time.** Never rely on Roblox's automatic SpawnLocation selection -- with two enabled SpawnLocations in the place, automatic selection is non-deterministic and will scatter players between the lobby and the vault at random. Both SpawnLocations stay `Enabled = true` and `Neutral = true`; the per-player `RespawnLocation` is what decides.
- **CHANGE 3 -- delete, do not supplement.** If Main currently CFrames the character to the Intake Chamber inside a `CharacterAdded` handler, that line must be **removed**, not left in alongside the new RespawnLocation logic. Leaving it in is the single most likely bug in this feature: the player would spawn correctly in the Lobby and then be yanked into the vault a frame later. `RespawnLocation` alone is sufficient.
- **CHANGE 4 -- ordering.** The SignatureColor must be computed and the attribute set *before* `RespawnLocation` is assigned and before the character loads, so LobbyController never sees a player with a nil color. If Main currently assigns the color on `CharacterAdded`, move that *computation* to `PlayerAdded`. (The Intake Chamber Scan Pad's *aura ignition* stays exactly where it is -- only the color's computation moves earlier.)

### MODIFY: `StarterGui.GameUI` -> `HUD` (Frame)

- Single property change: `Visible = false` as the StarterGui default. LobbyUIController turns it on -- on `VaultRunStarted`, or immediately for a player who joins while `runState == "Running"`. No other HUD property, child, or behavior changes.

### Scripts that need NO change (stated explicitly so nobody guesses)

| Script | Why no change is needed |
|--------|------------------------|
| `PuzzleManager` | the Lobby is not a puzzle; no solver, no room state, no entry in `ROOM_DEFINITIONS` |
| `DoorController` | the Vault Gate is **deliberately not routed through it**. DoorController's contract is that doors never re-lock; the Vault Gate re-seals. LobbyController owns the gate's open and close tweens directly via TweenService. Do not tag the gate `PuzzleDoor`. |
| `SecurityValidator` | this feature adds **zero** client -> server RemoteEvents. There is no new input to debounce, whitelist, or range-check. |
| `EchoController` | the Lobby is not in `ROOM_DEFINITIONS`, so a `RecordEchoSample` with a lobby roomId is already discarded by the existing whitelist check. No Echo ghosts spawn in the Lobby -- and that is the point: the Lobby is the one room in the game where you are alone with the living. |
| `DataManager` | no persistence in this feature. Nothing is saved, nothing is read. |
| `UIController` | LobbyUIController is a separate script precisely so this one is not reopened. |
| `SignatureColorController` | the aura still ignites on the Intake Chamber Scan Pad, unchanged. |

---

## Tags (additions)

| Tag | Count | Attributes | Purpose |
|-----|-------|------------|---------|
| `ReadyPad` | 8 | `PadId` (string, "Pad1".."Pad8"), `Occupant` (number, 0 = empty) | lobby readiness plates; LobbyController binds `.Touched`/`.TouchEnded` |
| `VaultGate` | 1 | `State` (string, "Sealed"/"Open") | the Lobby -> Intake Chamber gate slab; LobbyController tweens it directly |

No existing tag's count or attribute set changes. The `PuzzleDoor` count stays at 6.

---

## Existing System Interactions

| System | Interaction | Detail |
|--------|-------------|--------|
| SignatureColor assignment | **yes** | color computation moves from CharacterAdded to PlayerAdded and is exposed as a player attribute. The Scan Pad aura ignition is unchanged. |
| Intake Chamber geometry | **yes** | one 8x10 doorway cut in the previously-solid south wall at Z=0. Nothing else. |
| Intake Chamber Scan Pad | **no** | every player still reaches it and still triggers the aura beat -- including post-start joiners, whose IntakeSpawn is deliberately placed south of it. |
| PuzzleStateSync / late joiners | **no conflict** | a post-start joiner receives PuzzleStateSync (existing) *and* a `LobbyStateSync` with `runState = "Running"` (new). Independent channels, no ordering dependency between them. |
| Doors / DoorController | **no** | see above -- the gate is intentionally outside DoorController's contract. |
| Echoes system | **no** | Lobby is excluded from `ROOM_DEFINITIONS`, which is the existing whitelist. No new code path. |
| Wall of Echoes / handprint | **no** | unreachable from the Lobby; RequestPlaceHandprint's existing position check already rejects a player outside the Master Lock Room. |
| Static Vault timer / Vault Overload | **no** | those timers begin on room entry, long after the Lobby is behind the player. |
| Part budget | **yes** | +85. See below. |

---

## Part Budget Impact

Cross-references the existing **Part Budget** section above -- that section's per-agent allocation table is unchanged.

- Existing estimate: **~1470 parts**
- This feature adds: **~85** (58 base geometry including shell / gate / pads / beacon, 8 lighting fixtures, 16 dressing, 1 SpawnLocation, 2 VFX anchors)
- New estimated total: **~1555 parts**
- Against the 2000 target: **~445 parts of headroom remain** for the polish pass (existing Build Order step 12). The existing reserve allocation is untouched -- this feature fits inside the previously-stated 530-part headroom without borrowing from any agent's budget.

## Build Order Insertion

Slots into the existing Build Order as **step 2.5**, between "Intake Chamber" (step 2) and "Corridors A-F skeleton spine" (step 3). Reason: the Lobby must exist before the spine is walked end-to-end in testing, and it validates the RespawnLocation split early -- a spawn bug found at step 2.5 costs minutes; the same bug found after step 10 costs a full re-test of every room. Existing steps 3-12 are unrenumbered and unchanged.

Internal order for step 2.5:
1. Lobby shell + LobbySpawn + IntakeSpawn + the Intake south-wall doorway cut (world-builder) -- proves the spawn split before anything else is wired.
2. `Config.LOBBY` + the `Main` modification (luau-scripter) -- verify players actually appear in the Lobby and not the vault.
3. Ready Pads + Central Beacon + Vault Gate geometry (world-builder).
4. `LobbyController` (luau-scripter) -- pads, countdown, gate, teleport, safety sweep.
5. `GameUI` frames + `LobbyUIController` (luau-scripter) -- functional UI only.
6. ui-designer visual pass on WelcomeFrame / LobbyFrame; lighting-director warm-palette pass; sound-designer readiness chord + gate grind.

## Risk Areas

- **Two enabled SpawnLocations scattering players at random.** Mitigation: `RespawnLocation` is set explicitly per player on every join and at the run-start transition; automatic selection is never relied on. This is the single highest-probability bug in the feature.
- **A player stranded in the Lobby behind a re-sealed gate.** Mitigation: `safetySweep()` every 5s teleports anyone south of Z=0 into the Intake Chamber while RunState is "Running". Non-optional.
- **An AFK player blocking the countdown forever.** Mitigation: the 90-second idle valve, plus auto-idle for anyone who joins when all 8 pads are already claimed.
- **`.TouchEnded` not firing when a character dies or is destroyed on a pad, leaving a phantom "ready" claim.** Mitigation: `evaluate()` verifies every claimed occupant still has a living character before counting them.
- **Stacked countdown coroutines from rapid pad on/off.** Mitigation: the monotonically incremented `countdownToken`; any coroutine whose token is stale returns immediately. Combined with the 0.25s `SYNC_THROTTLE` on network fires.
- **Welcome screen re-appearing on respawn.** Mitigation: a module-scope `welcomeShown` boolean in LobbyUIController -- LocalScripts in StarterPlayerScripts persist across character respawns, so this is sufficient and needs no attribute.
- **Scope creep into a party/matchmaking system.** Explicitly out of scope: no invites, no friend filtering, no private servers, no lobby chat, no player list with names. Roblox's native "Play with friends" and server browser already cover grouping across servers; this is only an in-server waiting room for whoever is already here.

## Mobile Checklist (additions)

- [ ] Readying requires **zero taps** -- walking onto a pad is the entire interaction, which is the most touch-friendly input possible
- [ ] Welcome screen dismiss target is the full screen (`DismissButton` at Size (1,0,1,0)) -- far above the 44px minimum
- [ ] `LobbyFrame` is display-only: no touch targets, so no touch-target sizing risk at all
- [ ] All new UI sizing is Scale-based; pips use `UIAspectRatioConstraint` with `DominantAxis = Height` so they stay circular on any aspect ratio
- [ ] All new text uses `TextScaled = true`; the longest string is the one-line premise, which must remain legible at 375px width -- ui-designer to verify
- [ ] +85 parts keeps the total at ~1555, well under the 2000 target
- [ ] The Lobby has no particles, no beams, and 5 light sources -- it is the cheapest room in the game to render, which matters because it is the first thing a phone loads

## Emotional Journey (amendment)

The existing Emotional Journey line above now opens one beat earlier:

> **anticipation** (waking somewhere warm and ordinary, watching your color claim a floor tile, waiting for the others) -> **the drop** (the gate opens, the vault takes you, and the light goes cold) -> *curiosity (waking up marked with your own color)* -> ...and the existing journey continues unchanged from there.


---

# The Afterimage -- Hint System (Feature Addition)

**Task type:** TYPE B -- surgical feature addition to the completed core vault. Nothing above is redesigned. No existing puzzle mechanic, solver algorithm, room geometry, RemoteEvent payload, tag, door, or the Echoes system is altered. Four existing scripts get surgical additions; one new server script, one new client script, one new Config table, one new RemoteEvent.

**Logical placement:** extends Service Architecture, RemoteEvents, Tags (no additions -- see below), Signature Moments, and Part Budget. Slots into Build Order as **step 13**, after the existing polish pass.

---

## Overview

Color Lock's Risk Areas section already names the danger: *"Kids getting hard-stuck with zero tutorial text."* The existing mitigations are per-room and passive -- the Mixing Chamber's warmer-chime, the Echo Room's Watch plate and its guaranteed hint-ghost after 2 failures, the Static Vault's no-fail timer reset. What the game lacks is a **player-initiated** valve. A stuck eight-year-old in the Prism Hall has no way to say "help me" other than leaving.

This adds one. And it adds it **without a single word of text**, because the moment a hint reads as instructions, this game stops being the game it is.

### The unifying idea

Every hint in this game is the same thing: **an Afterimage** -- a translucent, color-tinted ghost of exactly ONE puzzle element in its *correct* state, held for 2.5 seconds, then gone.

That is not a UI feature bolted onto the fiction. It **is** the fiction. The player has already seen translucent color-tinted figures behind frosted glass in Corridor A, has already watched an Echo ghost solve the Echo Room sequence in front of them (existing LIFE spec, Echo Room). When they press the hint control and a translucent state materialises over a lever, they do not read it as "the game is helping me." They read it as **someone who was here before me is showing me their move.** The hint system and the game's central hook are the same system wearing the same clothes.

This also solves the generalisation problem cleanly. Five mechanic kinds plus four mini-stations do not need nine bespoke hint languages -- they need **four rendering primitives** and one rule: *show one move, never the solution.*

### The four primitives

| Primitive | What it does | Used by |
|-----------|--------------|---------|
| `GHOST` | clones one puzzle object, strips it inert, tints it, sets it to its correct state, superimposes it 0.02 studs off the real object, fades in/out | Mixing, Prism, Station A, Station C |
| `PULSE` | blooms one existing object's light to full in a meaningful colour, N times | Sequence, Station B |
| `PAIR` | blooms two objects in *perfect sync* in the same colour, teaching "these belong together" | Plate, Station D |
| `BEAM` | draws a short stub of coloured light leaving an object in the correct direction | Prism (with GHOST), Vault |

### Colour discipline -- the rule that keeps it legible

An Afterimage carries two colours and they must never be confused:

- **Shell tint** (the ghost's translucent body) = a *previous solver's* SignatureColor, pulled from EchoController's already-cached in-memory recording pool. This is the "someone was here" signal. Falls back to `NEUTRAL_ECHO_TINT` (#C8DCEB) when the pool is empty on a fresh place.
- **Signal colour** (a glow rim, a dial notch's lamp, a pulse, a beam) = the *true puzzle colour*, always, with zero deviation.

If those were merged, a plate hinting in a random stranger's purple would poison the game's entire colour language. They stay separate. **The shell says who; the signal says what.**

---

## Feature Scope

- **Type:** UX / accessibility system
- **Flavor:** HYBRID, weighted heavily SYSTEMIC -- 0 authored parts, 1 new HUD control, 1 new server script, 1 new client script
- **Subagents needed:** luau-scripter (all logic + functional UI), ui-designer (button visuals only), sound-designer (one afterimage sting), VFX-designer (optional dissolve particle on ghost despawn). **world-builder: no work at all** -- every Afterimage is a runtime clone of geometry that already exists.
- **New authored parts:** **0.** Transient runtime clones capped at 20 parts, lifetime <= 3.3s, one active Afterimage per scope.
- **Scripts:** 2 new, 4 modified.

---

## Design: what "one hint" costs and what it buys

### Nine hint scopes

The unit of hinting is a **scope**, not a room -- because the Master Lock Room contains four independent mechanics.

```
MixingChamber | EchoRoom | PrismHall | PressureGarden | StaticVault
MasterLockRoom:StationA | :StationB | :StationC | :StationD
```

In the Master Lock Room the player must be within `MASTER_STATION_RADIUS` (14 studs) of a specific station for the control to appear. Standing in the middle of the room offers nothing. That is deliberate and wordless: **go stand at the thing you're stuck on.**

### Three gates before the control even appears

1. **Dwell.** The player must have been inside the scope for `MIN_ROOM_DWELL` (20s). The control fading in *is itself the hint* -- the vault noticing you've been here a while. A player who breezes through never sees it and never knows it existed.
2. **Unsolved.** The scope's puzzle must not already be solved (read from PuzzleManager's live per-room state).
3. **Cooldown elapsed.** Per-scope, server-global.

### Cooldown is per-scope and SHARED across all players

This is the single most important balance decision in the feature. Color Lock is co-op with server-global puzzle state (Technical Decisions > Multiplayer). A per-player cooldown would let six friends chain-press and extract an entire solution in eight seconds. **The cooldown belongs to the room, exactly as the puzzle state does.** Six players in the Prism Hall share one hint budget, and when someone spends it, everyone's control greys out together -- which is its own wordless co-op signal: *somebody just asked for help.*

### The cooldown gets SHORTER, never longer

```
cooldown = max(COOLDOWN_MIN, COOLDOWN_SECONDS - COOLDOWN_DECAY * hintsGivenInScope)
        =  45s -> 35s -> 25s -> 15s (floor)
```

There is **no hard cap on total hints in a scope.** That is a deliberate refusal, and it matches the philosophy already established by Vault Overload: *when the player struggles, this game gets more generous, never more punishing.* A hard cap could permanently wall a child out of the game, which would violate the existing Risk Areas mitigation that "no room can permanently block a player who keeps trying." Instead the vault becomes progressively more forthcoming, and a genuinely stuck player is eventually walked through one move at a time -- slowly enough that it never feels like being handed the answer.

### One move. Never the solution.

Every scope's `GetHint` returns exactly one element, chosen **deterministically as the earliest-indexed element that is currently wrong.** Determinism matters twice over: repeated hints walk the solution in a stable, predictable order rather than flickering randomly, and QA can reproduce any hint exactly.

### A nil hint costs nothing

If a scope has no valid hint at this instant (already solved, or the Static Vault has no orb in flight), the solver returns `nil`, the server returns silently, **and the cooldown is not consumed.** A player must never be charged for a hint they did not receive.

---

## Per-mechanic hint specification

### Mixing Chamber (Room 1) -- `GHOST`

- **Selection:** the earliest lever (by `LeverId`) whose `Value` is not its target value in `Config.ROOM_DEFINITIONS[roomId]`.
- **What appears:** a translucent clone of that one lever housing, superimposed on the real one, its stepped dial rotated to the **correct notch**, its glow rim lit in that channel's true colour (red / green / blue).
- **Second beat (0.6s in):** the real Reveal Orb's SurfaceLight briefly shifts -- for 1.2s -- to the colour the mix *would* be **if only that one lever were corrected**, then eases back to the actual current mix. This is the crucial restraint: it shows *the next step's result*, not the target. The frosted Target Pedestal is already permanently visible in this room, so the player can compare the two themselves. The vault closes half the gap; the player closes the other half.
- **Why it works wordlessly:** the player sees a ghost dial sitting at a notch their real dial isn't at. There is nothing to interpret.

### Echo Room (Room 2) -- `PULSE`

- **Selection:** the panel at index `currentProgress + 1` in the room's stored correct sequence.
- **What appears:** that single wall panel blooms its SurfaceLight to full brightness, `PULSE_COUNT` (3) times over 2.5s, at roughly double the amplitude of its existing idle-pulse so it cannot be mistaken for ambient LIFE.
- **Relationship to the existing auto-hint:** the existing Echo Room mechanic -- an Echo ghost fading in and solving the **entire** sequence after 2 failed attempts -- is **completely untouched**. It is triggered by failure count; this is triggered by the button. It shows the whole sequence; this shows one step. They do **not** share a cooldown and do not suppress each other. The manual hint is deliberately the *weaker* of the two, so the room's authored lore beat remains the bigger moment.

### Prism Hall (Room 3) -- `GHOST` + `BEAM`

- **Selection:** the earliest prism (by `PrismId`, ordered along the beam path south-to-north) whose `Facing` is not its solution facing in the room's prism solution graph.
- **What appears:** a translucent clone of that rotator block, rotated to its **correct facing** (0/90/180/270), superimposed on the real block -- plus a `BEAM_STUB_LENGTH` (6-stud) Beam leaving the ghost in the direction light would travel, coloured the colour that beam segment would actually carry.
- **Why one prism:** three prisms in sequence means fixing the first is meaningless until you *see* what it does. Fix one, watch the real beam move, press again in 45s if still stuck. This is exactly how the room already teaches itself -- the hint just nudges the first domino.

### Pressure Garden (Room 4) -- `PAIR`

- **Selection:** the earliest unfilled non-decoy plate (by `PlateId`), and the nearest unplaced cube whose `Color` matches that plate's `RequiredColor`.
- **What appears:** the plate and the cube pulse **in perfect synchrony**, three times, both in the plate's `RequiredColor`. No arrow, no path, no ghost -- synchrony alone communicates "these two are a pair," which is the exact cognitive operation this puzzle asks for.
- **Decoys stay decoys:** the two neutral decoy plates and two decoy cubes are never selected and never pulse. The hint teaches the *pairing rule* without ever revealing which items are decoys -- the player must still figure out that some things don't belong.

### Static Vault (Room 5) -- `BEAM`

- **Selection:** the orb currently furthest along the conveyor that has not yet passed its decision gate; the gate that must be flipped to route it correctly.
- **What appears:** that gate's lever lamp glows in **the incoming orb's colour** (the match the player must make), and a short light-arrow Beam runs from the gate toward the correct bin.
- **The timer does not pause.** In the Static Vault, and *only* in the Static Vault, asking for help costs you seconds on the sort quota. This is the one room whose CHARACTER is "the vault stopped being curious about you," and it is right that the vault is less generous here. It still never fails the player -- Vault Overload's existing "reset with more time" behaviour is unchanged.
- **Deferred arming:** if no orb is in flight when the hint is requested, the directive is **armed** rather than spent -- HintController listens for the next orb spawn within `VAULT_HINT_ARM_WINDOW` (10s) and fires the beam then. If no orb spawns in that window, the hint is refunded (cooldown reset to ready).

### Master Station A (Mini Mixing) -- `GHOST`

Identical to the Mixing Chamber, over 2 levers instead of 3. There is no Reveal Orb at this station, so the `secondary` beat targets the station's own SurfaceLight instead, performing the equivalent brief shift.

### Master Station B (Mini Sequence) -- `PULSE`

Identical to the Echo Room, over 3 panels. **No Echo ghost auto-hint exists at this station** and none is added -- the finale is allowed to be harder, and the button-hint is the only assistance here.

### Master Station C (Mini Prism) -- `GHOST`

A single rotator between a fixed emitter and a fixed receiver. The ghost of the correct facing is shown. **No `BEAM` stub** -- with the emitter and receiver both fixed and visible in one glance, the beam stub would be redundant clutter, and this station is meant to read instantly once the correct facing is seen.

### Master Station D (Mini Plate) -- `PAIR`

One plate, one cube. They pulse together in the plate's `RequiredColor`. Trivial by design -- this station's difficulty is finding time for it while managing the other three, not solving it.

---

## System Design

### Config additions

**Config (ModuleScript) -- ReplicatedStorage/Modules/Config**

Existing pattern: `ROOM_DEFINITIONS`, `PALETTE`, `SIGNATURE_COLOR_POOL`, `LOBBY` as flat top-level sibling tables. Follow it -- add one new sibling. **Do not modify `ROOM_DEFINITIONS`**; the hint system *reads* it and never extends it. The solution data the hints reveal is the exact same data the solvers already validate against -- there is deliberately no second copy of any solution anywhere in this feature.

```lua
Config.HINTS = {
    ENABLED               = true,    -- boolean: master kill-switch (HintController, server)
    MIN_ROOM_DWELL        = 20,      -- number (s): time in scope before the control fades in
    COOLDOWN_SECONDS      = 45,      -- number (s): base per-scope cooldown
    COOLDOWN_DECAY        = 10,      -- number (s): subtracted per hint already given in that scope
    COOLDOWN_MIN          = 15,      -- number (s): cooldown floor
    AFTERIMAGE_DURATION   = 2.5,     -- number (s): hold time at full opacity
    AFTERIMAGE_FADE       = 0.4,     -- number (s): fade-in and fade-out each
    GHOST_TRANSPARENCY    = 0.75,    -- number: clone body transparency at full opacity
    PULSE_COUNT           = 3,       -- number: bloom repetitions for PULSE and PAIR
    PRESENCE_SWEEP        = 0.5,     -- number (s): interval of the server player-position sweep
    MAX_GHOST_PARTS       = 20,      -- number: hard cap on transient clone parts per Afterimage
    TINT_FROM_ECHO_POOL   = true,    -- boolean: shell tint sourced from EchoController's cache
    NEUTRAL_ECHO_TINT     = Color3.fromRGB(200, 220, 235), -- fallback when the pool is empty
    VAULT_HINT_ARM_WINDOW = 10,      -- number (s): Static Vault deferred-arm window
    BEAM_STUB_LENGTH      = 6,       -- number (studs): BEAM primitive length
    MASTER_STATION_RADIUS = 14,      -- number (studs): proximity required to scope to a station

    -- Scope bounds. These MIRROR the World Layout section above exactly; they are a
    -- lookup convenience, never a second source of truth. If a room moves, this moves.
    ROOM_BOUNDS = {
        MixingChamber  = {min = Vector3.new(-14, 0, 40),  max = Vector3.new(14, 14, 70)},
        EchoRoom       = {min = Vector3.new(-13, 0, 86),  max = Vector3.new(13, 14, 114)},
        PrismHall      = {min = Vector3.new(-17, 0, 130), max = Vector3.new(17, 20, 166)},
        PressureGarden = {min = Vector3.new(-15, 0, 182), max = Vector3.new(15, 14, 212)},
        StaticVault    = {min = Vector3.new(-14, 0, 228), max = Vector3.new(14, 14, 260)},
        MasterLockRoom = {min = Vector3.new(-22, 0, 276), max = Vector3.new(22, 22, 332)},
    },
    MASTER_STATIONS = {   -- sub-scopes inside MasterLockRoom, matching World Layout positions
        StationA = Vector3.new(-16, 3, 285),
        StationB = Vector3.new( 16, 3, 285),
        StationC = Vector3.new(-16, 3, 323),
        StationD = Vector3.new( 16, 3, 323),
    },
}
```

Read by: HintController (all fields, server), PuzzleManager solvers (`PULSE_COUNT`, `BEAM_STUB_LENGTH`), HintUIController (`MIN_ROOM_DWELL` for the fade-in curve only, client). Written by: nobody at runtime.

### The HintDirective contract

Every solver's `GetHint` returns either `nil` or exactly this shape. This is the entire interface between PuzzleManager and the renderer, and it is the thing luau-scripter should implement first.

```lua
export type HintDirective = {
    primitive   : "GHOST" | "PULSE" | "PAIR" | "BEAM",
    parts       : {BasePart},   -- 1 for GHOST/PULSE/BEAM, exactly 2 for PAIR
    signalColor : Color3,       -- the TRUE puzzle colour -- never the shell tint
    ghostCFrame : CFrame?,      -- GHOST only: world CFrame of the corrected state
    beamVector  : Vector3?,     -- BEAM only: unit direction the stub travels
    secondary   : {part: BasePart, color: Color3, delay: number, hold: number}?,
                                -- optional second beat (Mixing Chamber's Reveal Orb shift)
    duration    : number,       -- defaults to Config.HINTS.AFTERIMAGE_DURATION
}
```

`parts` are **server-side Instances**, resolved server-side by CollectionService tag + attribute lookup. They are never sent anywhere.

### Runtime state (HintController, server memory only)

```lua
-- scopeState : {[scope: string]: {readyAt: number, hintsGiven: number, active: boolean}}
-- dwell      : {[userId: number]: {scope: string, since: number}}
-- armedVault : {directiveBuilder: () -> HintDirective?, expiresAt: number}?
```

None of this persists. **No DataStore involvement in this feature at all -- DataManager needs no change.**

### RemoteEvents

**Exactly one new RemoteEvent, client -> server, with an empty payload.**

| Event | Direction | Payload | Server Validation |
|-------|-----------|---------|-------------------|
| `RequestHint` | C->S | `{}` -- scope is implied server-side by the player's actual position | player's HumanoidRootPart must resolve to a valid scope via `Config.HINTS.ROOM_BOUNDS` / `MASTER_STATIONS`; that scope's puzzle must be unsolved per PuzzleManager's live state; `dwell[userId].since` must be at least `MIN_ROOM_DWELL` old and in the same scope; `scopeState[scope].readyAt` must have elapsed. Rejected **silently** on any failure -- no error, no reply, no cooldown consumed. Debounced 0.3s per player by SecurityValidator. |

This payload shape deliberately copies `RequestPlaceHandprint` ("roomId implied server-side by player's actual position ... rejected silently otherwise"). The client cannot name a room, so it cannot probe rooms it is not standing in, and there is no field to forge.

**There is no server -> client hint RemoteEvent, and that is the security design.** The Afterimage is built by the server as ordinary replicated Instances in `Workspace.HintFX` -- the exact pattern the architecture already uses for Echo ghosts ("Echo ghosts are ordinary server-spawned, server-replicated NPC models, visible to everyone natively"). **Solution data never leaves the server in any form.** A client that dumps every RemoteEvent it receives learns nothing; a client that inspects `Workspace.HintFX` sees only the same 2.5 seconds of geometry every other player sees.

### Control state without RemoteEvents

Two per-player attributes, set by HintController's `PRESENCE_SWEEP` (0.5s) loop, replicate for free -- no polling event, no extra network chatter:

| Attribute | Type | Meaning |
|-----------|------|---------|
| `player:SetAttribute("HintScope", ...)` | string | current scope, or `""` when the control must be hidden (outside any scope, scope solved, dwell not met, or hints disabled) |
| `player:SetAttribute("HintReadyAt", ...)` | number | `workspace:GetServerTimeNow()` value at which the control becomes pressable |

The client compares `HintReadyAt` against its own `workspace:GetServerTimeNow()` -- the same clock on both sides -- and needs no countdown packets. This mirrors the `ReplicatedStorage:SetAttribute("RunState", ...)` mirroring pattern already established by LobbyController.

---

## UI architecture

The existing `StarterGui.GameUI` ScreenGui and its `HUD` frame are reused. **No new ScreenGui.** One new child of `HUD`.

```
StarterGui/
  GameUI (ScreenGui)                          [EXISTING]
    HUD (Frame)                               [EXISTING -- no property change]
      <SignatureColor swatch>                 [EXISTING, untouched]
      <4 Master Lock progress pips>           [EXISTING, untouched]
      HintButton (TextButton)                 [NEW] Text="", BackgroundTransparency=1,
                                              ZIndex 30, Visible=false, AutoButtonColor=false
                                              Size UDim2.new(0.085,0,0.085,0)
                                              AnchorPoint (1,0.5), Pos UDim2.new(0.97,0,0.60,0)
                                              + UIAspectRatioConstraint (AspectRatio=1,
                                                DominantAxis=Height)
                                              + UISizeConstraint MinSize(56,56) MaxSize(96,96)
        Ring (Frame)      Size(1,0,1,0), BackgroundTransparency 0.55, ZIndex 30
                          + UICorner CornerRadius UDim(0.5,0) + UIStroke
        DiscR (Frame)     Size(0.46,0,0.46,0), AnchorPoint(0.5,0.5), Pos(0.38,0,0.38,0),
                          BackgroundColor3 #E23B3B, ZIndex 31 + UICorner UDim(0.5,0)
        DiscG (Frame)     Size(0.46,0,0.46,0), AnchorPoint(0.5,0.5), Pos(0.62,0,0.38,0),
                          BackgroundColor3 #3BC94A, ZIndex 31 + UICorner UDim(0.5,0)
        DiscB (Frame)     Size(0.46,0,0.46,0), AnchorPoint(0.5,0.5), Pos(0.50,0,0.62,0),
                          BackgroundColor3 #3B6FE2, ZIndex 31 + UICorner UDim(0.5,0)
```

### The icon is the game's own logo

Three overlapping translucent R/G/B discs -- the exact motif already standing in the world twice: the Intake Chamber's "practice wall" (two overlapping colored lights blending into a third) and the Lobby's west-wall mural (three overlapping colored discs blending). A player has walked past this shape twice before they ever see the button. **It needs no legend because the world already taught it.** No "?" glyph, no lightbulb, no text -- nothing that reads as a menu affordance in a game that has no menus.

### Cooldown is shown by relighting, in thirds

| State | Rendering |
|-------|-----------|
| Ready | all three discs at their true hue, `BackgroundTransparency` 0.35; Ring stroke at the local player's SignatureColor |
| Cooling, 0-33% | all three grey (#5A5F63, transparency 0.75) |
| Cooling, 33-66% | DiscR at hue; G and B grey |
| Cooling, 66-100% | DiscR and DiscG at hue; B grey |
| Hidden | `HintButton.Visible = false` |

Colour returning to the discs, in the game's own additive-mixing order. Zero text, zero numerals, zero images, and it re-teaches the mixing rule every time it recharges.

### Appear / disappear

- **Fade in** over 0.8s (TweenService on `Ring.BackgroundTransparency` + the three disc transparencies) the moment `HintScope` becomes non-empty. Never snaps in.
- **Fade out** over 0.4s when `HintScope` becomes `""` -- leaving the room, or the puzzle being solved. Solving a puzzle making the control quietly evaporate is its own small reward.
- **Press:** immediate local scale-punch (1.0 -> 0.88 -> 1.0 over 0.18s) and optimistic grey-out, corrected by the next attribute sweep 0.5s later. If the request was silently rejected, the discs simply relight -- no error state, no message, consistent with every other silent rejection in this game.

### Scripter vs ui-designer boundary

luau-scripter creates the full hierarchy above, wires `HintButton.Activated`, fires `RequestHint`, drives all `Visible` / `BackgroundTransparency` / `BackgroundColor3` transitions and every TweenService animation.

**ui-designer touches visual properties only:** `Ring.BackgroundColor3`, the `UIStroke` (Color, Thickness, Transparency), `UICorner` radii, an optional `UIGradient` on Ring. **ui-designer must not change:** any instance `Name` (HintUIController looks all of them up by name), `Size`, `Position`, `AnchorPoint`, `Visible`, the `UIAspectRatioConstraint` or `UISizeConstraint` values (both are mobile-safety guarantees), or **the three discs' `BackgroundColor3` hues** -- those are the gameplay colour language, not decoration, and must remain the Art Direction Guide's Safe/Interactive R/G/B values exactly.

**Style notes for ui-designer:** the control should read as a piece of *vault instrumentation*, not a game HUD widget -- a recessed indicator lamp on a wall panel. Ring dark and slightly translucent so the room shows through; stroke thin and cool (the Cool Vault Blue #58C4DC when idle, easing to the player's SignatureColor when ready). Nothing bouncy, nothing cartoon-glossy. This game's UI is quiet.

---

## Script Modifications

### NEW: `ServerScriptService.HintController` (Script)

- **Purpose:** the single authority for hint eligibility, scoping, cooldowns, and Afterimage rendering. Owns nothing about puzzle solutions -- it *asks* PuzzleManager and *renders* the answer.
- **Depends on:** `Config.HINTS`, PuzzleManager (`GetHint`, `IsScopeSolved`), EchoController (read-only access to its cached recording pool for the shell tint), CollectionService, TweenService, the `RequestHint` RemoteEvent.
- **Key functions:**
  - `init()` -- creates `Workspace.HintFX` (a Folder, `Archivable = false`), builds the empty `scopeState` table for all 9 scopes, starts the presence sweep, connects `RequestHint.OnServerEvent`.
  - `resolveScope(player) -> string?` -- reads the player's HumanoidRootPart position, tests it against `ROOM_BOUNDS`; if the result is `MasterLockRoom`, tests distance against each `MASTER_STATIONS` entry and returns `"MasterLockRoom:StationX"` for the nearest within `MASTER_STATION_RADIUS`, or `nil` if the player is mid-room. Returns `nil` if the character or root part is missing.
  - `presenceSweep()` -- every `PRESENCE_SWEEP` seconds, for every player: resolve scope; reset `dwell` if the scope changed; compute the effective ready time as `max(scopeState[scope].readyAt, dwell.since + MIN_ROOM_DWELL)`; set `HintScope` and `HintReadyAt` attributes. Sets `HintScope = ""` if scope is nil, `Config.HINTS.ENABLED` is false, or `PuzzleManager.IsScopeSolved(scope)` is true.
  - `onRequestHint(player)` -- re-resolves the scope from scratch (**never trusts the sweep's cached value, and never trusts the client for anything**), re-checks solved / dwell / cooldown, calls `PuzzleManager.GetHint(scope)`. On `nil`, returns immediately with no state change. On a directive, calls `Afterimage.Play(directive)`, then sets `scopeState[scope].readyAt` and increments `hintsGiven`.
  - `armVaultHint(builder)` -- the Static Vault deferred path: stores a directive-builder, waits for the next orb spawn within `VAULT_HINT_ARM_WINDOW`, then plays it. On expiry, refunds the cooldown (`readyAt = 0`, `hintsGiven -= 1`).
  - `echoTint() -> Color3` -- returns a random SignatureColor from EchoController's in-memory pool, or `NEUTRAL_ECHO_TINT` when the pool is empty.
- **Edge cases it must handle explicitly:**
  - **A player leaving mid-Afterimage.** The Afterimage belongs to the *scope*, not the requester. It plays out fully.
  - **Two players requesting within the same frame.** `scopeState[scope].active` is set synchronously before any yield; the second request finds it true and returns silently without consuming a cooldown.
  - **The puzzle being solved during an Afterimage.** The Afterimage completes and self-destructs normally; nothing is cancelled mid-flight, because a half-erased ghost looks like a bug.
  - **A player teleported / falling / no character.** `resolveScope` returns `nil`, `HintScope` becomes `""`, control hides. No error.
  - Connection cleanup on `PlayerRemoving`: clear the player's `dwell` entry so departed userIds are not retained.

### NEW: `ServerScriptService.HintController.Afterimage` (ModuleScript, child of HintController)

- **Purpose:** the entire renderer. Four functions, one per primitive, plus lifecycle.
- **`Play(directive)`** dispatches on `directive.primitive`, then schedules teardown at `AFTERIMAGE_FADE + duration + AFTERIMAGE_FADE`.
- **`makeGhost(part, cframe, shellTint) -> BasePart?`** -- this function carries the feature's single biggest risk and must be written exactly:
  1. `part:Clone()`
  2. **`CollectionService:RemoveTag()` every tag on the clone and every descendant.** A cloned lever that keeps its `Lever` tag would be picked up by PuzzleManager's tag scan and could corrupt live puzzle state. **This is the #1 way this feature can break the game.**
  3. **Destroy every `ProximityPrompt`, `Script`, `LocalScript`, `ClickDetector`, and `Sound`** in the clone. A ghost lever must never be interactable.
  4. Set on the clone and all descendant BaseParts: `Anchored = true`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless = true`, `Transparency = 1` (faded up to `GHOST_TRANSPARENCY` by the tween), `Color = shellTint`, `Material = Enum.Material.ForceField` (or `Neon` for glow-rim children carrying the signal colour).
  5. `Archivable = false`, `Name = "Ghost_" .. part.Name`, parent to `Workspace.HintFX`.
  6. Abort and return `nil` if the clone's descendant BasePart count would push the active total past `MAX_GHOST_PARTS`.
- **`pulse(part, color, count)`** -- tweens the part's existing PointLight/SurfaceLight Brightness and the part's `Color` between base and signal, `count` times. **Restores the original values on completion, always, including on error** -- wrap in `pcall` and restore in the failure branch too. A hint that permanently recolours a puzzle object is a game-breaking bug.
- **`pair(partA, partB, color, count)`** -- `pulse` on both, driven by a single Tween so synchrony is exact. Two separate tweens would drift, and drift destroys the entire "these belong together" read.
- **`beam(originPart, direction, color)`** -- creates two Attachments and one Beam in `Workspace.HintFX`, `BEAM_STUB_LENGTH` studs apart, `Color` set to a ColorSequence of the signal colour, `Transparency` a NumberSequence fading to 1 at the far end. Destroyed with the rest of the Afterimage.
- **Teardown** -- `Workspace.HintFX:ClearAllChildren()` is safe to call at any time and is called defensively on `init()` in case a previous edit session left residue.

### MODIFY: `ServerScriptService.PuzzleManager`

- **CURRENTLY:** owns per-room shared puzzle state keyed by roomId and dispatches validation to five sub-modules (MixingSolver, SequenceSolver, PrismSolver, PlateController, VaultSolver).
- **CHANGE 1 -- add `PuzzleManager.IsScopeSolved(scope) -> boolean`.** Maps the 9 hint scopes onto the existing per-room state table (the 4 `MasterLockRoom:StationX` scopes map onto the 4 station sub-states PuzzleManager already tracks for the Convergence check). Pure read, no new state.
- **CHANGE 2 -- add `PuzzleManager.GetHint(scope) -> HintDirective?`.** A dispatcher only: resolves scope to `{subModule, roomId}` and calls `subModule.GetHint(roomId, state)`. Contains **zero** hint logic of its own.
- **CHANGE 3 -- each of the five sub-modules gains one new function, `GetHint(roomId, state) -> HintDirective?`:**

  | Sub-module | Reads | Returns |
  |------------|-------|---------|
  | `MixingSolver` | `state.leverValues`, the room's target lever values in `Config.ROOM_DEFINITIONS` | `GHOST` on the earliest lever whose value is wrong, `ghostCFrame` = the real lever's CFrame with the dial child rotated to the target notch, `signalColor` = that channel's hue, `secondary` = the Reveal Orb with the one-lever-corrected mix colour, delay 0.6, hold 1.2 |
  | `SequenceSolver` | `state.progress`, the room's stored correct sequence | `PULSE` on the panel at index `progress + 1`, `signalColor` = that panel's colour. `nil` if the sequence is mid-replay (never fight the Watch-plate playback for the player's attention). |
  | `PrismSolver` | `state.facings`, the room's prism solution graph | `GHOST` + `beamVector` on the earliest prism whose facing is wrong; `signalColor` = the colour that beam segment carries at that point in the trace |
  | `PlateController` | `state.filledPlates`, plate `RequiredColor` attributes, cube positions | `PAIR` -- earliest unfilled non-decoy plate plus the nearest unplaced colour-matching cube; `signalColor` = the plate's `RequiredColor`. `nil` if no matching cube is free. |
  | `VaultSolver` | live orb queue, gate states, `Config` bin mapping | `BEAM` on the decision gate for the furthest-along undecided orb, `signalColor` = that orb's colour, `beamVector` toward the correct bin. If no orb is in flight, returns a **builder closure** instead so HintController can arm it. |

- **The rule every sub-module follows:** `GetHint` is **strictly read-only**. It never mutates puzzle state, never fires a RemoteEvent, never touches an Instance. It reads the same `Config.ROOM_DEFINITIONS` data the solver already validates against -- **there is no second copy of any solution introduced by this feature** -- and returns a table. All rendering is HintController's job, and all mutation remains where it already lives.

### MODIFY: `ServerScriptService.SecurityValidator`

- **CURRENTLY:** debounces every RemoteEvent per player at 0.3s and validates every `roomId`/`leverId`/`prismId`/`gateId` against the Config whitelist.
- **CHANGE -- one line.** Add `RequestHint` to the per-player debounce table. There is **no roomId to whitelist and no range check to add**, because `RequestHint` has an empty payload and HintController resolves the scope from the server's own view of the player's position. The existing 8-stud range checks are irrelevant here -- the scope bounds check *is* the range check, and it lives in HintController by design (it is scope logic, not input validation).

### MODIFY: `ReplicatedStorage.Modules.Config`

Add the `Config.HINTS` table exactly as specified above. **`ROOM_DEFINITIONS` is not modified.**

### NEW: `StarterPlayer.StarterPlayerScripts.HintUIController` (LocalScript)

- **Purpose:** owns `HintButton` and nothing else. A **separate** script from both UIController and LobbyUIController, following the precedent LobbyUIController set -- already-reviewed client code is never reopened for a new feature.
- **Depends on:** `Config.HINTS`, the `RequestHint` RemoteEvent, TweenService, `workspace:GetServerTimeNow()`, and the two player attributes.
- **Key functions:** `onScopeChanged(scope)` (fade in / fade out), `renderCooldown()` (a `RunService.Heartbeat` connection, throttled to 10Hz, that relights the discs in thirds), `onPressed()` (scale-punch, optimistic grey-out, fire `RequestHint`), `bindKey()` (ContextActionService binding on **H**, so desktop players have a key -- **H is not bound to anything in this game**; ProximityPrompts use E and must not be shadowed).
- Sends exactly one thing to the server: an empty `RequestHint`. Reads nothing authoritative. Contains **no solution data of any kind**, which is checkable by inspection -- a reviewer can confirm the client half of this feature is inert by reading roughly 120 lines.

### Scripts that need NO change (stated explicitly so nobody guesses)

| Script | Why no change is needed |
|--------|------------------------|
| `Main` | hints are unrelated to SignatureColor assignment or spawning |
| `DoorController` | hints never unlock anything; a hinted puzzle still has to be solved by the player |
| `EchoController` | **read-only** access to its already-cached recording pool for the shell tint. HintController reads; EchoController is not modified. Hints spawn no ghost NPCs and record no samples. |
| `DataManager` | no persistence in this feature. Nothing saved, nothing read. |
| `UIController` | HintUIController is a separate script precisely so this one is not reopened |
| `LobbyController` / `LobbyUIController` | there are no puzzles in the Lobby; `resolveScope` returns `nil` for any position with Z < 0 |
| `SignatureColorController` | the aura is untouched |
| `HUD` (Frame) | **no property change.** `HintButton` is added as a new child; `HUD.Visible` remains under LobbyUIController's sole control, exactly as the Lobby feature specified. |

---

## Tags

**No new tags.** Every object an Afterimage acts on is already reachable through the existing `Lever` / `SequenceButton` / `PrismRotator` / `PressurePlate` / `PushableCube` / `SortGate` tags and their existing attributes. And critically -- **cloned ghosts carry no tags at all** (stripped in `makeGhost` step 2). The existing tag counts in the Tags table above are unchanged and must stay unchanged; a playtester finding 6 `Lever`-tagged parts instead of 5 has found this feature's worst bug.

---

## Signature Moment 7: The Vault Answers

- **Trigger:** the first time any player on the server presses the hint control, in any scope.
- **What happens:** visual -- the three discs dim; a beat of nothing (0.35s of deliberate silence, so the player wonders whether it worked); then a translucent, colour-tinted form fades up out of the air over the puzzle and holds, unmistakably the same substance as the figure they glimpsed behind the frosted glass in Corridor A. It shows one move. It dissolves. Audio -- not a UI chime: the same faint indistinct murmur/static sting used for the Echo Through Glass (Signature Moment 2), pitched down and shorter. **The hint must never sound like a button.**
- **Duration:** ~3.3s (0.4 fade in, 2.5 hold, 0.4 fade out).
- **Aftermath:** none mechanical. But the player has now connected two things the game never explained: the ghosts in the corridors and the help they just received are the same phenomenon. From here on, every Echo sighting reads slightly differently -- they were never just atmosphere.
- **Which agents implement:** luau-scripter (HintController + Afterimage + solver `GetHint`s), ui-designer (the control's visual), sound-designer (the pitched-down murmur -- **reuse the existing Echo sting asset, do not author a new UI sound**), VFX-designer (an optional low-rate dissolve particle on ghost despawn, <= 1 emitter, must fit inside the existing 20-emitter global budget).

---

## Existing System Interactions

| System | Interaction | Detail |
|--------|-------------|--------|
| `ROOM_DEFINITIONS` solution data | **read-only** | solvers' `GetHint` read the same fields the validators read. No second copy of any solution exists anywhere in this feature. |
| Echo Room's auto-hint ghost (after 2 fails) | **coexists, untouched** | different trigger (failure count vs button), different strength (full sequence vs one step), separate cooldowns, neither suppresses the other |
| Echoes system / EchoController | **read-only** | shell tint sampled from the in-memory recording pool. No new ghost spawns, no new recordings, no DataStore traffic. |
| PuzzleManager shared state | **read-only** | `GetHint` never mutates. A hint changes nothing about the puzzle -- the player still has to make the move. |
| Co-op / server-global state | **yes -- by design** | cooldown is per-scope and shared, matching the existing rule that puzzle state is server-global, not per-player. Prevents six players chain-hinting a solution out of the vault. |
| Static Vault timer / Vault Overload | **yes** | the quota timer does **not** pause during a hint. Vault Overload's existing behaviour is unchanged; a hint may cost you the overload, which is a real wordless cost in the one room whose character justifies it. |
| Pressure Garden decoys | **preserved** | decoy plates and decoy cubes are never selected by `GetHint`. The hint teaches pairing without revealing which items don't belong. |
| DoorController / door unlocking | **no** | a hint never unlocks a door. |
| Lobby / RunState | **no** | `resolveScope` returns `nil` south of Z=0; the control never appears in the Lobby. |
| Wall of Echoes / `RequestPlaceHandprint` | **no** | the finale has no puzzle to hint. |
| SecurityValidator | **yes -- one line** | `RequestHint` added to the existing debounce table. |
| VFX global emitter budget | **<= 1 emitter** | the optional dissolve particle must fit inside the existing under-20 global cap. |
| Part budget | **+0 authored** | see below. |

---

## Part Budget Impact

Cross-references the existing **Part Budget** section -- its per-agent allocation table is unchanged and **no agent's budget is drawn against.**

- Existing estimate after the Lobby feature: **~1555 parts**
- This feature adds: **0 authored parts** -- every Afterimage is a runtime `:Clone()` of geometry that already exists in the world, and every Beam/Attachment is created and destroyed in the same 3.3 seconds.
- Transient runtime cost: at most `MAX_GHOST_PARTS` (20) parts, in at most one Afterimage per scope, all parented to `Workspace.HintFX` with `Archivable = false` so they never enter a saved place file.
- **New estimated total: ~1555 parts.** Unchanged. ~445 parts of headroom remain against the 2000 target.

**Note for roblox-playtester:** `Workspace.HintFX` will be empty during any structural scan. If a part-count test ever catches an Afterimage mid-flight, the reading is transient and correct -- the folder self-empties within 3.3s.

---

## Build Order Insertion

Slots into the existing Build Order as **step 13**, after the polish pass. Reason: the hint system reads live solver state from all five mechanics plus the four finale stations, so every one of them must be finished and reviewed before `GetHint` can be written against them. Existing steps 1-12 are unchanged.

Internal order for step 13:
1. `Config.HINTS` + the `HintDirective` type + `PuzzleManager.IsScopeSolved` (luau-scripter) -- the contract, before any consumer of it exists.
2. `HintController` skeleton + `resolveScope` + the presence sweep + the two attributes (luau-scripter) -- verify the scope attribute flips correctly by walking the whole spine, before any hint exists to render.
3. `Afterimage` ModuleScript, `GHOST` primitive only, driven by a hardcoded test directive (luau-scripter) -- **prove the tag-stripping and interaction-stripping work before anything else is built on top.** This is the step where the feature either stays safe or quietly corrupts puzzle state.
4. `MixingSolver.GetHint` + `RequestHint` + SecurityValidator's one line -- first end-to-end hint, in the game's simplest room.
5. Remaining primitives (`PULSE`, `PAIR`, `BEAM`) and the remaining four solvers' `GetHint`, including the Static Vault deferred-arm path.
6. `HintButton` hierarchy + `HintUIController` (luau-scripter) -- functional UI only.
7. ui-designer visual pass on `HintButton`; sound-designer's pitched-down Echo sting; VFX-designer's optional dissolve particle.

---

## Risk Areas

- **A cloned ghost keeping its CollectionService tags and corrupting live puzzle state.** This is the single most dangerous failure mode in the feature -- a ghost lever tagged `Lever` would be scanned by PuzzleManager and could make a solved puzzle unsolvable. Mitigation: `makeGhost` strips every tag from the clone and all descendants as step 2, before parenting; step 3 of Build Order proves this in isolation before anything else is built. Verification: the Tags table's counts must be identical before, during, and after an Afterimage.
- **A cloned ghost carrying a live ProximityPrompt, letting a player interact with a hallucination.** Mitigation: `makeGhost` destroys every ProximityPrompt, ClickDetector, Script, LocalScript, and Sound in the clone; every BasePart is set `CanQuery = false` and `CanTouch = false`.
- **`pulse` failing mid-tween and leaving a puzzle object permanently the wrong colour** -- which in this game means permanently lying to the player about the puzzle state. Mitigation: original Color/Brightness values captured before the tween and restored in both the success and failure branches of a `pcall`.
- **Six co-op players chain-pressing to extract a full solution.** Mitigation: the cooldown is per-scope and server-global, not per-player -- six players share one budget.
- **Hints trivialising the puzzles.** Mitigation: one move per hint, never the solution; a 20s dwell gate before the control even appears; a 45s starting cooldown; and the deliberate choice to show the *next step's result* rather than the target in the Mixing Chamber.
- **A stuck child being permanently walled out** -- the failure mode this feature exists to prevent. Mitigation: **no hard cap on hint count**, and a cooldown that decays 45 -> 35 -> 25 -> 15s. The vault gets more generous the longer you struggle, exactly as Vault Overload already does.
- **Solution data leaking to the client.** Mitigation: the client's only outbound message is an empty `RequestHint`; there is no inbound hint RemoteEvent at all; the Afterimage is server-built replicated geometry. HintUIController can be verified inert by reading it.
- **The control reading as a menu / breaking the wordless promise.** Mitigation: the icon is the game's own three-disc mixing motif, already taught twice in the world; there is no text anywhere in the control; the cooldown is shown as colour returning, not as a number; and the sound is the Echo sting, not a UI chime.
- **`resolveScope` disagreeing with the built world if a room is ever moved.** Mitigation: `ROOM_BOUNDS` mirrors the World Layout section exactly and is documented as a mirror, never a second source of truth. A structural test should assert every room's bounds contain that room's key objects.

---

## Mobile Checklist (additions)

- [ ] `HintButton` uses `UISizeConstraint MinSize (56, 56)` -- comfortably above the 44px touch-target minimum on the smallest phone, while `MaxSize (96, 96)` stops it dominating a tablet
- [ ] Positioned at `(0.97, 0.60)` with `AnchorPoint (1, 0.5)` -- the right edge at 60% height, deliberately clear of both Roblox's mobile jump button (bottom-right) and the movement thumbstick (bottom-left)
- [ ] `UIAspectRatioConstraint (1, DominantAxis = Height)` keeps the control circular on every aspect ratio
- [ ] Zero text anywhere in the control -- nothing to shrink below legibility, in any language
- [ ] Cooldown is communicated by three discs relighting, not by a numeral -- readable at a glance at arm's length
- [ ] One tap is the entire interaction; no drag, no long-press, no double-tap
- [ ] +0 authored parts; <= 20 transient parts for <= 3.3s; <= 1 additional ParticleEmitter against the existing under-20 global cap
- [ ] The cooldown render loop is throttled to 10Hz, not per-frame
- [ ] Every hint remains solvable-by-looking -- **no room, and no hint, requires reading a single word of text**
