# A BEE'S WORLD — Architecture Document

## Core Concept

You are a bee. You build your hive as a **hexagonal honeycomb you physically walk on**, you find flowers in a giant shared meadow, and you **waggle-dance** their location to your sisters — and everything you own is made of the honey you decided *not* to cash in yet.

## The Hook

Three things make this not a reskinned tycoon:

**1. The comb is a hex placement puzzle, not a row of purchase buttons.** Your plot is a real honeycomb lattice (axial hex grid). Cell *type* matters and cell *neighbours* matter, using real comb logic: brood in the warm centre ringed by honey, pollen packed beside the brood as bee bread, royal cells hanging on the rim, propolis sealing the outer edge. Every purchase is also a placement decision. It is a 30-second decision a 9-year-old can make from colour-coded ghost hexes, and it has a correct answer worth 40% output.

**2. There is no conveyor belt. There is a waggle dance.** Flowers are not on your plot — they are in the shared wild meadow between all six hives. You walk out, find a patch, mark it, then stand on your Dance Floor and perform a two-tap waggle dance: **tap one sets the bearing, tap two sets the distance** (which is exactly what a real bee's waggle encodes). Accuracy becomes route quality. A golden line of light draws itself across the world from your hive to that patch, and your foragers fly it. Routes decay — bees forget — so the meadow is a place you keep going back to. Distance vs richness is a real trade: near clover is fast and thin, far linden is slow and fat.

**3. Your honey gets more valuable the longer you leave it sitting — and a bear named Old Molasses can smell it.** Banked honey is spendable. Honey still ripening in your comb is worth up to **2.2×** more, glows brighter and brighter amber as it ripens, and is *visible from every other plot in the server*. Molasses always targets the ripest comb, and he is announced 45 seconds in advance. So the central decision of the game is a public, visible gamble: cash out safe, or let it glow and hope your neighbours run over to help you smoke him off.

And Molasses is not a raid timer — he is a character with a six-stage arc who learns. He comes in daylight the first time. Then at dusk. Then he waits for rain, when your foragers are home and your guards are sheltering. Then he brings his cub. And after you have beaten him five times he shows up one last time, sits down at your gate, and does not attack — and you choose to **feed him a jar** (he becomes a napping neighbour who scares wasps off your hive forever) or **refuse** (he becomes Furious Molasses, raids forever, and every repel pays royal jelly). Two permanent, mutually exclusive endings, two exclusive cosmetics. That is the thing players tell their friends.

## Genre: Tycoon (bee-scale management / light active-play)

A tycoon in bones: escalating buildings, escalating currency, prestige, plots side by side, "always a next thing." But the escalation is spatial (comb grows outward then upward through three floors), the income is earned through active route management rather than passive droppers, and the tension is a *public risk/reward* instead of PvP.

**Why this angle:** generic tycoons are read-only — the player watches numbers. Bees are the single most *legible* animal in games: everything they do is visible motion. So the design rule here is **every stat is a visible object.** Your production rate is not a number, it is the count of bees in the air. Your route quality is not a stat, it is how straight the golden line is. Your bank is not a counter, it is how bright your comb glows. Your prestige is not a badge, it is how tall your hive is and whether it clears the fence line.

---

## Emotional Journey

| Time | Feeling | What causes it |
|---|---|---|
| 0:00–0:15 | *"Wait, I'm tiny."* | Spawn at bee scale. A blade of grass is 18 studs. A garden fence board is 60 studs tall above you. |
| 0:15–0:45 | Curiosity → first agency | One glowing clover patch 40 studs out, one arrow, one prompt: MARK. |
| 0:45–1:30 | **Delight** | First Waggle. The golden route line draws itself. Three bees launch off your landing board and follow it. You *made* that. |
| 1:30–4:00 | Comprehension | Honey arrives. Build your first three cells. Notice the ghost hexes showing adjacency arrows. "Oh — placement matters." |
| 4:00–8:00 | Ownership | Castes unlock. You choose to make nurses instead of foragers and feel the cost. Propolis routes open; you sacrifice income for building material. |
| 8:00–12:00 | First real tension | Wasp scout circles your comb. You swat it. You learn guards die when they sting. |
| 12:00–20:00 | **Greed** | You learn ripeness. You let honey sit. Your comb glows. Someone in chat says "bro your hive is lit up." |
| 20:00–26:00 | **Fear, then pride** | Molasses, stage 1. Neighbours run over. You win. Paw print on your deck as a trophy. |
| 26:00–45:00 | Mastery + rhythm | Day/night cycle: you re-dance at dusk for linden, again at night for moonflower. You are managing a living schedule. |
| 45:00–60:00 | **Bittersweet** | The Swarm. Every bee you own leaves with your queen, over the treeline, gone. Silence. Then a royal cell cracks open. |
| Gen 1+ | Long-term hunger | Floor 2 rises above you. Floor 3 puts you over the fence — the only place you can see the entire server at once. |

---

## Spatial Narrative

The player's physical journey is **down, out, and then up**, and the tension curve tracks it exactly.

1. **Apiary Yard (hub)** — tension: low. Spatial: enclosed, cluttered, *human-made and oversized*. You are in the corner of a beekeeper's yard among a fallen watering can and a boot. Safe, warm, slightly absurd. Establishes scale in one look.
2. **Petal Path** — tension: low, rising curiosity. Spatial: a long linear corridor of stepping stones between 40-stud grass walls. You cannot see the plots yet, only glimpses of glow through the grass. Anticipation.
3. **Your Comb Deck** — tension: neutral-warm, this is *home*. Spatial: open, flat, geometric, bounded. The hard hex geometry reads as order against the chaotic organic meadow. Warm amber pools. This is the only place in the game that feels designed rather than grown.
4. **Wild Meadow** — tension: medium, rising. Spatial: **expansive and disorienting** — the only zone with no straight lines, 20-stud stems above your head, patchy light, other players' bees crossing overhead. You are exposed and small here. Getting deeper into it means better flowers and a longer walk home.
5. **Pine Treeline (resin)** — tension: medium-high. Spatial: dark, vertical, cold-shadowed, *pressing*. The farthest and least rewarding-feeling place, and the only place that feels like it belongs to something bigger than you. Molasses lives beyond it.
6. **Comb Floor 2** — tension: drops to satisfied. Spatial: elevated, roofed by Floor 3's shadow, tighter — a mezzanine. Intimate and industrial.
7. **Comb Floor 3 (Crown Comb)** — tension: awe, zero threat. Spatial: **exposed, airy, above the fence line.** The reveal: six glowing hives in a row, the whole meadow, the treeline, and Molasses's den. The view is the reward for prestige. You cannot get this view any other way.
8. **A raid, anywhere** — tension: spike. Spatial quality inverts: the open deck becomes a place with no cover and one thing to protect.

---

## Core Loop

```
                 ┌──────────────────────────────────────────┐
                 │                                          │
   WALK the meadow → MARK a patch → WAGGLE-DANCE it  ──►  ROUTE (golden line)
                                                              │
                                    foragers fly it ──────────┤
                                                              ▼
                             NECTAR + POLLEN arrive at Landing Board
                                        │              │
                          ┌─────────────┘              └──────────────┐
                          ▼                                           ▼
                   HONEY CELLS                                  POLLEN CELLS
              (nectar → honey, RIPENS 1.0→2.2×)            (feeds brood: 4 pollen/larva)
                          │                                           ▼
                 HARVEST (banks honey)                         BROOD CELLS hatch
                          │                                           ▼
                          ▼                                CASTE SPLIT you control:
                  SPEND on new CELLS ◄───────────────── forager / nurse / guard / drone
                  SPEND on structures                            │        │       │
                          │                                      │        │       └► drones: required
                          │                     ┌────────────────┘        │          for SWARMING
                          │                     ▼                        ▼
                          │              more routes flown         defend wasps / bear
                          │              (transport capacity)      (guards die on sting)
                          │
                          ├──► ROYAL CELLS on the rim → ROYAL JELLY → QUEEN TIERS + permanent PERKS
                          │
                          └──► COMB FLOORS 2 & 3 → more cells → taller hive → the view
                                          │
                                          ▼
                        SWARM (prestige): queen + all bees leave.
                        Comb resets. Perks, jelly and Generation persist.
                        New flower species and cell tiers unlock.
                                          │
                                          └────────► loop, richer
```

**Step by step:**

1. **Find** — walk the shared wild meadow, find a blooming patch, stand on it, press E → *Marked*. (Patches also auto-reveal slowly over time so passive players are never stuck.)
2. **Dance** — stand on your Dance Floor (the permanent centre cell). Pick a marked patch. Two taps: bearing, then distance. Grade = Perfect / Good / Poor → route quality 1.25 / 1.0 / 0.7. A Beam draws the route across the world.
3. **Fly** — foragers automatically fly the route. Server math: `tripTime = 2·dist/flightSpeed + 3s`, `yield = carry · speciesMult · richness · routeQuality`. Far patches pay more per trip but fewer trips. Routes decay one grade per 4 minutes until re-danced.
4. **Convert** — nectar fills Honey Cells (3 nectar → 1 honey). That honey **ripens in place**, 1.0 → 2.2× over 6 minutes, and glows.
5. **Decide** — Harvest now at current ripeness, or let it glow and risk Molasses.
6. **Build** — spend honey (+ propolis for higher tiers) on new cells in Build Mode, placed on the hex lattice with adjacency bonuses.
7. **Grow population** — pollen feeds brood cells; you split each hatch between four castes.
8. **Escalate** — cell tiers → Dance Floor tiers → Kiln → Queen tiers → Comb Floor 2 → Floor 3.
9. **Swarm** — prestige. Reset the comb, keep Royal Jelly perks and Generation multiplier, unlock the next flower species.

**The three-bottleneck spine (the readable skill of the game):**

```
SUPPLY     = Σ route yield/sec        (how good your flowers + dances are)
WINGS      = foragers × carry ÷ trip  (how many bees you have)
COMB       = Σ honey-cell intake/sec  (how much comb you've built)
effective  = min(SUPPLY, WINGS, COMB)
```

The HUD shows three bars and flashes the smallest one with a one-word hint: **"NEED BEES!"** / **"NEED COMB!"** / **"NEED FLOWERS!"** Three levers, one obvious next action, always. A 9-year-old learns the entire economy from one glance at a red bar.

---

## Service Architecture

```
ServerScriptService/
  Main (Script)                        -- bootstrap: requires Systems in dependency order, wires RemoteRouter
  EnemyAI (Script)                     -- built by enemy-designer: Old Molasses + Cub + Wasp behaviour
  Systems/ (Folder)
    DataService (ModuleScript)
    PlotService (ModuleScript)
    CombService (ModuleScript)
    ForagingService (ModuleScript)
    DanceService (ModuleScript)
    PopulationService (ModuleScript)
    ResourceService (ModuleScript)
    QueenService (ModuleScript)
    SwarmService (ModuleScript)
    TimeService (ModuleScript)
    PatchService (ModuleScript)
    ThreatService (ModuleScript)
    StructureService (ModuleScript)
    PerkService (ModuleScript)
    CosmeticService (ModuleScript)
    AchievementService (ModuleScript)
    LeaderboardService (ModuleScript)
    RemoteRouter (ModuleScript)
    Validator (ModuleScript)

ReplicatedStorage/
  Modules/
    Config (ModuleScript)              -- EVERY number in the game. Single source of truth.
    GameEnums (ModuleScript)
    HexGrid (ModuleScript)             -- axial<->world math, neighbours, ring/rim tests. SHARED client+server.
    Formulas (ModuleScript)            -- cost/rate/ripeness/adjacency formulas. SHARED so UI previews cannot disagree with server.
    Shared (ModuleScript)              -- util: round, format numbers (12.4K / 3.1M), tween helpers, throttle
  Remotes/ (Folder)                    -- one RemoteEvent per entry in the Remotes table below
  Templates/ (Folder)
    Cells/      WaxCell, ReinforcedCell, PropolisCell, GoldenCell, DanceFloorCell, DimCellPlate
    CellContent/ HoneyBlob, BroodLarva, BroodCap, PollenMound, RoyalCell, PropolisSeam
    Structures/ ApiaryShed_T1..T3, PropolisKiln_T1..T3, DanceFloor_T1..T5, SwarmPerch,
                LandingBoard, GuardPerch, Smoker, PlotSign, WardrobePedestal, BudButton,
                CombFloorRamp, CombColumn, PawPrint
    Flora/      CloverPatch, DandelionPatch, LavenderPatch, SunflowerPatch, LindenPatch,
                MoonflowerPatch, FireweedPatch, AuroraPatch, ResinNode, GrassTuft
    Actors/     Bee (2 parts, pooled), NectarMote, WaspDrone
    Effects/    RouteBeamRig, CappingWave, SwarmColumn

StarterPlayer/StarterPlayerScripts/
  ClientMain (LocalScript)             -- boots controllers, owns the single Heartbeat loop
  Controllers/ (Folder of ModuleScripts)
    HudController                      -- wallet, three bars, clock, banners
    BuildController                    -- top-down comb Build Mode, ghost hexes, adjacency arrows
    DanceController                    -- the two-tap waggle minigame (input only; server grades)
    SwarmVisualController              -- pooled bee flight + nectar motes + LOD/culling
    RouteVisualController              -- golden Beam route lines
    PatchController                    -- patch markers, MARK prompt, richness pips
    ThreatController                   -- wasp swat input, smoker prompt, raid HUD
    MomentController                   -- signature-moment choreography playback
    CameraController                   -- default camera + Build Mode top-down + Moment cinematics
    InputController                    -- unified keyboard / touch / gamepad mapping
    SettingsController                 -- low-detail toggle, music/sfx

StarterGui/
  MainGui (ScreenGui, DisplayOrder=10)      -- wallet, three bars, clock, contextual action button
  BuildGui (ScreenGui, DisplayOrder=12)     -- comb build mode panel, cell palette, cost/adjacency preview
  DanceGui (ScreenGui, DisplayOrder=14)     -- bearing dial + distance bar
  HiveGui (ScreenGui, DisplayOrder=11)      -- castes, queen, perks, swarm tabs
  ShopGui (ScreenGui, DisplayOrder=11)      -- cosmetics, propolis exchange
  ThreatGui (ScreenGui, DisplayOrder=16)    -- raid banner, patience bar, SMOKE button, OFFER A JAR
  NotifyGui (ScreenGui, DisplayOrder=18)    -- toasts, achievements, moment titles

Workspace/
  Map/
    Hub/            (Apiary Yard)
    PetalPath/
    Meadow/         Patches/, Grass/, Props/
    Treeline/       Pines/, ResinNodes/
    Fence/          (the giant garden fence run)
    Plots/          Plot1 .. Plot6   (each: Deck/, Comb/Floor1..3/, Structures/, Props/, Signs/)
    BearRealm/      Den/, Waypoints/
  Actors/           (runtime: bears, wasps — server-spawned)
  ClientFX/         (runtime, client-only: bee pool, mote pool, route beams)
```

### Scripts Detail

**Main (Script) — ServerScriptService/Main**
- Purpose: single entry point. Requires Systems in strict dependency order, then starts the master tick.
- Order: `Config` → `DataService` → `TimeService` → `PatchService` → `PlotService` → `CombService` → `PopulationService` → `ForagingService` → `ResourceService` → `QueenService` → `StructureService` → `DanceService` → `PerkService` → `CosmeticService` → `AchievementService` → `SwarmService` → `ThreatService` → `LeaderboardService` → `RemoteRouter.Wire()`.
- Owns the **only** server `RunService.Heartbeat` connection. Accumulates dt and calls `ResourceService.Tick(dt)` at a fixed 0.5s step, `ForagingService.Tick` at 0.5s, `TimeService.Tick` at 1s, `ThreatService.Tick` at 1s, `LeaderboardService.Tick` at 60s. One loop, deterministic order, no competing timers.
- `game:BindToClose` → `DataService.FlushAll()`.
- Sets `Players.MaxPlayers = 6` is a place setting, not script — noted in Technical Decisions.

**DataService — ReplicatedStorage-free, server only**
- Purpose: DataStore load/save with session locking, autosave, migration.
- Key functions: `Load(player)`, `Get(player)` (returns in-memory profile), `Save(player)`, `FlushAll()`, `Migrate(profile)`.
- Session lock: `UpdateAsync` writes `{lockedBy = jobId, lockedAt = os.time()}`; a lock older than 300s is stolen. Refuses load and kicks with a friendly message if locked and fresh (prevents duplicate-hive exploits).
- Autosave every 120s, staggered per player by `userId % 120` so six players never save on the same frame.
- Every DataStore call wrapped in `pcall` with 3 retries at 2/4/8s backoff. On total failure: profile flagged `dataFailed = true`, player gets a red banner, and **saving is disabled for that session** (never overwrite good data with a bad in-memory state).
- Depends on: Config (for `ProfileTemplate`).

**PlotService**
- Purpose: assign / release / reset plots, teleport, public attribute replication.
- `AssignPlot(player)` on `PlayerAdded`: first free plot index 1..6; writes `OwnerUserId` attribute on `PlotRoot`; sets sign; on `CharacterAdded` teleports the character to that plot's ramp-top spawn CFrame. Hub remains walkable via the Petal Path.
- `ReleasePlot(player)` on `PlayerRemoving`: `DataService.Save`, then destroy all built cell content and structures above tier 1 and restore `DimCellPlate` outlines. **This is the part-budget safety valve** — a leaving player's 340 parts drop back to 91.
- `PushPublicStats(plotIndex)`: writes Attributes on `PlotRoot` (see Tags table). Other players' plot signs and the ripeness glow read these — zero RemoteEvent cost.
- Depends on: DataService, CombService, StructureService.

**CombService**
- Purpose: authoritative owner of the hex lattice — which cells exist, their type, tier, stored amount, ripeness.
- Key functions: `CanBuild(profile, floor, q, r, cellType) -> bool, reason`, `Build(...)`, `Upgrade(...)`, `UnlockFloor(profile, floor)`, `GetAdjacencyBonus(profile, floor, q, r)`, `Harvest(profile) -> honeyBanked`.
- Validates: cell inside that floor's lattice radius, cell empty, floor unlocked, `RoyalCell` only on rim (`HexGrid.IsRim`), `PropolisSeam` only on outer ring, `GoldenCell` requires Queen ≥ Q4, cost affordable in **honey and propolis**, and Floor N+1 requires Floor N ≥ 80% built.
- On successful build: clones the template into `Plots/PlotN/Comb/FloorN/`, fires `CombUpdate`, recomputes cached rates, calls `PlotService.PushPublicStats`.
- Adjacency is computed **once on change** and cached per cell, never per tick.
- Depends on: Config, HexGrid, Formulas, ResourceService.

**HexGrid (ModuleScript, ReplicatedStorage — shared)**
- `ToWorld(q, r) -> Vector3` using pointy-top axial: `x = 13.856 * (q + r/2)`, `z = 12.0 * r`, plus the floor's Y.
- `Neighbours(q, r) -> {6 axial pairs}`; `Ring(radius)`; `IsRim(q, r, floorRadius)`; `InLattice(q, r, floor)`; `Key(q,r) -> "q,r"`, `FromKey`.
- Shared so the Build Mode ghost preview and the server agree exactly on geometry. A divergence here would be the single nastiest class of bug in this game; one module prevents it.

**ForagingService**
- Purpose: route bookkeeping and abstract flight economics. Does **not** move any parts.
- `CreateRoute(profile, patchId, quality)`, `DecayTick()`, `ComputeSupply(profile) -> nectar/s, pollen/s, propolis/s`.
- Per route: `yieldPerTrip = carry · speciesNectarMult · richnessFactor · quality · perkDeepCrop`, `tripTime = 2·dist/flightSpeed + 3`, `ratePerBee = yieldPerTrip / tripTime`. Foragers are distributed across active routes proportionally to `ratePerBee` (best route first, capped by patch richness drain).
- Applies patch depletion back into `PatchService` so two players routing the same patch genuinely split it.
- Route decay: quality drops one grade every `240s · (1 - 0.15·longMemory)`; a Poor route that decays becomes Lost and frees its slot (unless Dance Floor T5).

**DanceService**
- Purpose: server-authoritative waggle grading. **The client never sends a grade.**
- On `RequestDanceStart {patchId}`: validates proximity to the player's own Dance Floor cell (≤ 12 studs, server reads `character.PrimaryPart.Position`), validates patch is marked and a route slot is free, generates a **server-side secret**: `trueBearing` (from hive to patch), `trueDistance`, plus `dialPhase` and `dialSpeed` seeds. Returns only the seeds needed to animate — never the answer offsets.
- On `SubmitDance {angleInput, durationInput}` (both normalized 0..1): server reconstructs where the dial and bar actually were, computes `angleError` and `durationError`, grades against the golden-zone width for that Dance Floor tier + `clearSignal` perk. Rejects if no dance is open, if submitted <1.2s or >12s after start, or if the player moved >14 studs from the Dance Floor.
- One open dance per player. Rate limit 1 per 3s.

**PopulationService**
- Purpose: brood, hatching, castes, population cap.
- `popCap = Σ(broodCellCount · 6 · cellTierMult)`. `hatchInterval = queenLayInterval / (1 + 0.03·nurseCount capped 0.9) / (1 + 0.06·warmBroodPerk) / (1 + 0.08·adjacentHoneyCells)`.
- Each hatch consumes 4 pollen; no pollen → no hatch (and a HUD hint "BEES ARE HUNGRY").
- New bee's caste drawn from the player's caste ratio. `SetCastes` affects **future** hatches only — never retroactively converts, so the player's choices have weight.
- Guards that sting **die** (real bee cost): `ThreatService` calls `PopulationService.KillGuards(n)`.

**ResourceService**
- Purpose: the 0.5s economic tick. The single place numbers change.
- Per plot per tick: compute `supply / wings / comb`, take the min, flow nectar into honey cells (respecting per-cell capacity), advance ripeness with weighted-average dilution, flow pollen into pollen cells, flow resin into the Kiln → propolis, run `hiveSteward` auto-harvest if owned, update `genHoney` / `lifetimeHoney`, and fire throttled `WalletUpdate` (4/s) and `RatesUpdate` (1/s).
- Ripeness: `ripeRate = 1.2 / 360` per second, clamp `[1.0, 2.2]`. Adding honey dilutes: `rip = (amt·rip + gain·1.0) / (amt + gain)`.

**QueenService**
- Purpose: the Queen as a visible NPC and a multiplier.
- Spawns a Queen model on the comb; a `TweenService`/CFrame walk cycle carries her between brood cells. Cells she passes flash amber (this is cosmetic; laying is handled by PopulationService math).
- `UpgradeQueen(profile)` validates Royal Jelly cost and prerequisites, swaps the Queen model to the next tier's larger body, fires `Moment{id="QueenGrowth"}`.

**SwarmService** — prestige. `CanSwarm` checks Queen ≥ Q4, drones ≥ 25, ≥1 capped Royal Cell, `genHoney ≥ SWARM_THRESHOLD[generation]`. On swarm: compute Royal Jelly award, increment `generation`, assign `lineageName`, wipe `comb`/`routes`/`population`/`floorsUnlocked` back to defaults (+ `starterComb` perk cells), preserve `perks`/`royalJelly`/`cosmetics`/`achievements`/`bear`/`lifetimeHoney`, fire `Moment{id="SwarmDeparture"}`, force-save.

**TimeService** — 12-real-minute day. Drives `Lighting.ClockTime` by tween, the weather state machine, and `TimeWeather` broadcasts. Weather: `Clear 240s → Breezy 90s → Overcast 90s → Rain 60s → BloomRush 90s` (randomized order after the first cycle, Rain always followed by BloomRush). Rain: flight halted, all bees visibly return home. BloomRush: all patch richness restored +50%, `speciesMult × 1.35`.

**PatchService** — owns the 16 wild patches + 4 resin nodes: species, position, `richness` (0–1, drains under foraging, regrows at `0.012/s`, fully restored by BloomRush), bloom window vs current hour, and per-player `marked` sets. Broadcasts `PatchUpdate` throttled to 1/s and only to players within 400 studs.

**ThreatService** — wasp cycle and the Old Molasses arc state machine. Owns raid scheduling, target selection (`max(honeyAmount · ripeness)` across plots), patience, smoke/guard damage, theft resolution, and stage progression. Delegates all *movement and animation* of bear/cub/wasps to `EnemyAI`, communicating through attributes on the Actor models (`TargetPlot`, `Phase`, `Patience`) so the AI script stays self-contained.

**StructureService** — the non-cell buildings: Dance Floor tier, Apiary Shed, Propolis Kiln, Comb Floor unlocks, Wardrobe, Swarm Perch. Owns the physical **Bud Buttons**: a `Touched` connection per button with a 0.6s per-player debounce, which routes to `RequestPurchase` server-side (buttons are server-driven, so a client cannot fake a touch on someone else's button).

**PerkService / CosmeticService / AchievementService / LeaderboardService** — jelly spending validation; skin ownership + applying wings/colour to the player character and to that plot's rendered swarm; achievement unlock checks fired from hooks in other services; `OrderedDataStore("LifetimeHoney_v1")` top-10 cached 60s, rendered on the hub chalkboard and served via one RemoteFunction.

**RemoteRouter** — the only place RemoteEvents are connected. Wraps every handler in: `Validator.RateLimit(player, eventName)` → `Validator.Sanitize(payload, schema)` → `pcall(handler)`. Any handler error is logged with the player name and swallowed, never propagated. This is the single choke point for anti-exploit work, which means a reviewer has one file to audit rather than fifteen.

**Validator** — `RateLimit(player, key, perSecond)`, `Sanitize(value, schema)` with explicit type/range/whitelist checks, `NearPosition(player, worldPos, maxStuds)` reading the server's copy of the character position with a +6 stud tolerance for latency. Every remote below routes through it.

---

## RemoteEvents

All in `ReplicatedStorage/Remotes/`. `C→S` = client fires, `S→C` = server fires. **No RemoteEvent ever carries a price, a rate, a quality grade, or a resource amount from client to server.** The client sends *intent* only.

| Event | Dir | Payload | Server Validation |
|---|---|---|---|
| `RequestBuildCell` | C→S | `{floor:number, q:number, r:number, cellType:string}` | ints in `[-3,3]`, `floor∈{1,2,3}` and unlocked; `cellType` in whitelist; `HexGrid.InLattice`; cell empty; RoyalCell→rim only; PropolisSeam→outer ring only; cost read **from Config server-side**, honey+propolis sufficient; rate 6/s |
| `RequestUpgradeCell` | C→S | `{floor, q, r}` | cell exists & owned by caller's plot; `tier < 4`; GoldenCell gate Queen≥Q4; cost from Config; rate 6/s |
| `RequestPurchase` | C→S | `{itemId:string}` | `itemId` in `Config.STRUCTURES` whitelist; prerequisite tier chain satisfied; generation gate; cost from Config; rate 4/s |
| `RequestUnlockFloor` | C→S | `{floor:number}` | `floor∈{2,3}`; prior floor ≥80% built; Floor3 requires `generation≥1`; cost from Config; rate 1/s |
| `RequestMarkPatch` | C→S | `{patchId:number}` | patch exists; `Validator.NearPosition(player, patch.Position, 25)`; not already marked; rate 2/s |
| `RequestDanceStart` | C→S | `{patchId:number}` | patch marked by caller; free route slot **or** `replaceSlot` valid; `NearPosition(player, ownDanceFloor, 12)`; no dance already open; rate 1 per 3s |
| `SubmitDance` | C→S | `{angleInput:number, durationInput:number}` — both `0..1` | a dance is open for this player; elapsed in `[1.2s, 12s]`; player still within 14 studs of own Dance Floor; **server computes the grade from its own secret targets**; both inputs clamped `0..1`; rate 1 per 3s |
| `RequestSetCastes` | C→S | `{forager:int, nurse:int, guard:int, drone:int}` | all ints `0..100`, sum exactly 100; nurse requires Queen≥Q3; rate 1 per 2s |
| `RequestHarvest` | C→S | `{}` | `NearPosition(player, ownLandingBoard, 18)`; cooldown 1s; server computes honey from its own cell state |
| `RequestQueenUpgrade` | C→S | `{}` | `queenTier < 5`; royalJelly ≥ cost from Config; generation gate for Q5; rate 1/s |
| `RequestSpendJelly` | C→S | `{perkId:string}` | perkId in whitelist; `level < maxLevel`; jelly ≥ `3·(level+1)`; rate 2/s |
| `RequestSwarm` | C→S | `{}` | `SwarmService.CanSwarm` (Queen≥Q4, drones≥25, capped RoyalCell≥1, genHoney≥threshold); rate 1 per 10s |
| `RequestEquipCosmetic` | C→S | `{skinId:string}` | skinId in `profile.cosmetics.owned`; rate 2/s |
| `SwatWasp` | C→S | `{waspId:number}` | wasp model exists and alive; `NearPosition(player, wasp.Position, 40)`; rate 1 per 0.4s; **server** applies the damage |
| `Smoke` | C→S | `{plotIndex:number}` | `plotIndex∈1..6`; an active bear raid targets that plot; `NearPosition(player, thatPlot.Smoker, 30)` — *any* player may smoke *any* plot (co-op by design); per-player cooldown 2.5s |
| `BearOffering` | C→S | `{choice:string}` | `choice∈{"jar","refuse"}`; caller's `bear.stage == 6` and the Sitting is active on caller's own plot; for `"jar"`: honey ≥ 5000; irreversible, written immediately and force-saved |
| `RequestTeleport` | C→S | `{plotIndex:number}` | `1..6`; destination CFrame chosen **server-side** from the plot's ramp marker; 3s cooldown |
| `Bootstrap` | S→C | `{profile, plotIndex, patches, hour, weather, bearStage, publicPlots}` | fired once on `CharacterAdded` |
| `WalletUpdate` | S→C | `{honey, propolis, pollen, royalJelly, ripeningHoney, ripeness}` | throttled 4/s, only on change |
| `RatesUpdate` | S→C | `{supply, wings, comb, effective, honeyPerMin, bees, castes, popCap, bottleneck:string}` | 1/s |
| `CombUpdate` | S→C | `{floor, q, r, cellType, tier, state}` | on change only |
| `RouteUpdate` | S→C | `{slot, patchId, quality, decayAt, hivePos, patchPos}` | on create/decay/lose |
| `PatchUpdate` | S→C | `{patchId, richness, blooming, species}` | 1/s, only to players within 400 studs |
| `DanceResult` | S→C | `{grade:string, angleError, durationError, quality, slot}` | immediately after `SubmitDance` |
| `TimeWeather` | S→C | `{hour:number, weather:string, endsAt:number}` | on change + every 15s resync |
| `ThreatEvent` | S→C | `{kind, phase, targetPlot, patience, maxPatience, extra}` | broadcast to all — the whole server watches a raid |
| `Notify` | S→C | `{kind:string, text:string}` | toasts, achievements, hints |
| `Moment` | S→C | `{id:string, plotIndex:number, payload:table}` | signature-moment choreography triggers |

**RemoteFunction (exactly one):** `GetLeaderboard() -> {top10}` — cached server-side 60s, rate-limited 1 per 10s per player. Everything else is one-way events (a RemoteFunction invoked by the client can hang a server thread; one cached read-only call is the acceptable exception).

**Attributes instead of remotes for public state.** Every `PlotRoot` carries `OwnerName`, `Generation`, `LineageName`, `HoneyPerMin`, `BeeCount`, `RipeningHoney`, `Ripeness`, `BearStage`, `QueenTier`, `CombFloors`. Roblox replicates these for free to all clients, which is how six plot signs, six ripeness glows and the "whose comb is glowing" social read all work without a single extra RemoteEvent.

---

## Data Model (DataStore Schema)

`DataStoreService:GetDataStore("BeesWorld_v1")`, key `"hive_" .. userId`. Global board: `GetOrderedDataStore("LifetimeHoney_v1")`.

```lua
Config.PROFILE_TEMPLATE = {
    version        = 1,          -- migration chain: Migrate() applies v1->v2->... in order

    -- wallets
    honey          = 120,        -- spendable currency (starting gift = 2 cells' worth)
    propolis       = 0,          -- construction material
    pollen         = 20,         -- brood food (starting gift = 5 larvae)
    royalJelly     = 0,          -- prestige currency, survives swarming

    -- progression
    generation     = 0,          -- swarm/rebirth count
    lineageName    = "First Hive",
    lifetimeHoney  = 0,          -- all generations; global leaderboard metric
    genHoney       = 0,          -- current generation; the swarm gate

    -- the comb: floor -> "q,r" -> cell
    comb = {
        [1] = {
            ["0,0"]  = { t = "DanceFloor", lvl = 1, amt = 0,  rip = 1.0 },
            ["1,0"]  = { t = "Honey",      lvl = 1, amt = 14, rip = 1.31 },
            ["0,1"]  = { t = "Brood",      lvl = 1, amt = 0,  rip = 1.0 },
        },
        [2] = {},
        [3] = {},
    },
    floorsUnlocked = 1,          -- 1..3

    -- structures (tier numbers)
    danceFloorTier = 1,          -- 1..5  -> route slots + golden-zone width
    shedTier       = 1,          -- 1..3  -> shop stock + propolis exchange rate
    kilnTier       = 1,          -- 1..3  -> resin -> propolis conversion
    queenTier      = 1,          -- 1..5

    -- foraging
    routes = {                   -- length <= routeSlots(danceFloorTier, floorsUnlocked)
        { patchId = 4, quality = 1.25, lastDanced = 1758000000 },
    },
    markedPatches = { [4] = true, [11] = true },

    -- population
    castes     = { forager = 70, nurse = 15, guard = 10, drone = 5 },  -- must sum to 100
    population = { forager = 3,  nurse = 0,  guard = 0,  drone = 0 },

    -- permanent perks (survive swarming)
    perks = { clearSignal=0, strongWings=0, deepCrop=0, warmBrood=0,
              thickPropolis=0, hiveSteward=0, starterComb=0, longMemory=0 },

    cosmetics = { owned = { "worker" }, equipped = "worker" },
    achievements = {},            -- id -> true

    -- Old Molasses arc (persists across swarming -- he remembers your bloodline)
    bear = { stage = 0, repels = 0, offering = nil, pawPrints = 0, lastRaid = 0 },

    stats = { waspsSwatted=0, dancesPerfect=0, cappingNights=0,
              bestHoneyPerMin=0, playtimeSeconds=0, patchesFound=0 },

    settings = { music=true, sfx=true, lowDetail=false, autoHarvest=false },

    lastSave = 0,
}
```

**Size:** worst case (57 cells × ~48 bytes + routes + perks) ≈ 4.5 KB serialized — far under the 4 MB per-key limit. No chunking needed.

**Migration:** `version` gates a chain of pure functions `MIGRATIONS[1] = function(p) ... p.version = 2 end`. A profile with no `version` field is treated as a fresh template (there are no live players yet, so v1 is the true floor). Every new field added in later cycles must be introduced through a migration that fills a default, never assumed present.

**Intentional cross-generation persistence:** `royalJelly`, `perks`, `cosmetics`, `achievements`, `lifetimeHoney`, `bear`, `stats`. Everything else resets on swarm. The `bear` block persisting is a deliberate design choice — Molasses remembering you across generations is the single strongest continuity hook in the game.

---

## World Layout

Global frame: `Y = 0` is meadow soil top. Comb decks sit at `Y = 6.5` (top surface). One unit = one stud. **Everything human-made is built at roughly 12× human scale**, because the player is a bee — this single rule is what keeps six independent visual agents producing one coherent world.

### Plot grid

Six plots, one row along X, all identically oriented (no rotation anywhere — world position = `plotCenter + localOffset`, which removes an entire category of placement bug).

| Plot | Center (X, Y, Z) |
|---|---|
| 1 | (-325, 0, 0) |
| 2 | (-195, 0, 0) |
| 3 | (-65, 0, 0) |
| 4 | (65, 0, 0) |
| 5 | (195, 0, 0) |
| 6 | (325, 0, 0) |

Spacing 130 studs center-to-center; each plot deck is 110 × 110, leaving a 20-stud wild gap between decks (deliberately walkable — you can wander onto a neighbour's boundary and see their comb glow up close).

---

### Zone: Comb Deck (× 6)

- **Position:** plot center, deck slab centered at local (0, 6, 0)
- **Dimensions:** 110 × 1 × 110 studs, top surface at Y = 6.5
- **Floor:** `SmoothPlastic` Wax Cream `#E8D49A` for the comb lattice; deck base `Slate` Propolis Brown `#7A4A22`
- **Walls:** none — this is an open-air wild comb. The giant fence boards behind (local Z = +52, 60 studs tall, `WoodPlanks` `#8A6236`) form the only vertical boundary.
- **Accents:** Honey Gold `#F2A81C` `Glass` for filled cells; `Neon` rim on cells at ripeness ≥ 2.0
- **Lighting:** 1 `PointLight` per filled honey cell — Color `#F2A81C`, Range 14, Brightness tied to ripeness (`0.4 + 1.1·(rip-1)/1.2`). This is the single most important lighting decision in the game: **your bank balance is literally how bright your plot is.** Plus 1 warm `SpotLight` over the Landing Board (Color `#FFD89B`, Range 30, Brightness 1.6, Angle 70, pointing down).
- **Part count:** 91 empty → 340 fully maxed
- **Connections:** ramp at local X = 0, 14 studs wide, occupying local/world Z −80..−55 — i.e. *entirely outside* the deck's own 110 × 110 footprint, which spans Z −55..+55. Foot at Z = −80, Y = 0, meeting the Petal Path's north edge; rises **northward** over a 25-stud run to the deck's front edge at local Z = −55, Y = 6.5. (Plot centers are all at world Z = 0, so local Z = world Z here.)
- **Key objects (local coords, all relative to plot center):**

| Object | Local (X, Z) | Size | Notes |
|---|---|---|---|
| Comb Floor 1 lattice | centered (0, +6) | 19 cells, radius-2 hex, extent X ±28 / Z −18..+30 | cell (0,0) is the permanent **Dance Floor**; 18 buildable |
| Comb Floor 2 lattice | (0, +6) at Y = 22.5 | 12 cells | reached by wax ramp at local (+34, +14) |
| Comb Floor 3 "Crown Comb" | (0, +6) at Y = 38.5 | 7 cells | clears the fence line — the only vantage over the whole server |
| Landing Board | (0, −24) | 22 × 10 | bee launch/return point, HARVEST interact, Smoker mounted here |
| Smoker | (+8, −24) | 3 × 5 | glows red during a raid; any player may use it |
| Guard Perch × 2 | (−20, −26), (+20, −26) | 6 × 6 | guards visibly sit here; empty perches read as "undefended" |
| Apiary Shed | (−42, −30) | 18 × 16 | shop / cosmetics / propolis exchange |
| Propolis Kiln | (+42, −30) | 14 × 14 | resin → propolis; visibly steams when running |
| Swarm Perch | (0, +44) | branch stub, 10 × 6 | the rebirth pad; a bare branch until you can use it |
| Wardrobe Pedestal | (−46, −48) | 4 × 4 | bee skin selection |
| Plot Sign | (−52, −46) | 14 × 10 board at Y = 14 | SurfaceGui: OwnerName, LineageName, Honey/min, RipeningHoney, Bees, BearStage |
| Bud Buttons × 8 | in front of each structure, 11 studs toward −Z | 4 × 5 each | closed flower bud; opens and glows **only when affordable** |

**Hex math (Config constants):** `CELL_W = 13.856`, `CELL_H = 12.0`, cell plate diameter 15. Cell local position = `(13.856·(q + r/2) + 0, floorY, 12.0·r + 6)`.

- **CHARACTER:** This is the only place in A Bee's World with straight lines. The meadow is chaos; the human world is oversized and indifferent; the comb is *yours*, mathematically perfect, warm, and it hums. It should feel like a workshop lit by its own product. Early on it is embarrassingly bare — 18 dim grey outlines and three cells — and that bareness is the point: the comb is a progress bar you stand on. At full build, with three floors and every cell capped, it should feel like standing inside a lantern.
- **LIFE:**
  - *Ambient:* honey cells pulse-glow on a slow 4s breathing cycle offset per cell (never synchronized -- a synchronized comb looks like a machine, an offset one looks alive). Kiln steam puff every 6s when running. Wax creak every 12–20s. Bees continuously stream in and out of the Landing Board, and the *rate* of that stream is the player's actual income -- nothing is faked.
  - *Triggered:* stepping onto a cell makes it dip 0.15 studs and spring back. Walking near a filled honey cell brightens its light 25% for 1.5s. Approaching an affordable Bud Button makes it open with a soft pop. Entering Build Mode raises all dim outline plates 0.4 studs and outlines valid placements in green, blocked in red.
  - *Reactive:* the Queen physically walks the comb and cells flash amber as she passes. Guards on perches turn to face any approaching player or threat. During rain, every bee on the map streams home and the Landing Board light brightens.

---

### Zone: Wild Meadow (shared)

- **Position:** centered (0, 0, −181)
- **Dimensions:** 800 (X, −400..+400) × 170 (Z, −266..−96), ground at Y = 0. The near (north) edge at Z = −96 abuts the Petal Path's south edge; the far (south) edge at Z = −266 abuts the Apiary Yard's north edge.
- **Floor:** `Grass` Meadow Green `#6FA84A`, with patches of `Ground` `#7A6A4A` where bees have worn tracks
- **Accents:** flower heads in species colours; Pollen Haze `#FCEFC6` on drifting motes
- **Lighting:** no local lights -- this zone is lit entirely by the sun and therefore changes character completely across the 12-minute day. At in-game 20:00 the far-meadow Moonflower cluster gets 4 cold `PointLight`s, Color `#8FB4FF`, Range 50, Brightness 1.2.
- **Part count:** ~520
- **Key objects:** 16 flower patches (below), grass tufts 14–22 studs tall (~120 parts, used as sight-line blockers so the meadow can't be read in one glance), a fallen log at (−140, 0, −206) you can walk through, a puddle at (95, 0, −156) that reflects the sky, worn stone stepping path.

**Patch table** -- `patchId`, world position, species, distance band from the nearest plot:

| ID | Position | Species | Band |
|---|---|---|---|
| 1–4 | (−300,0,−131), (−100,0,−136), (100,0,−134), (300,0,−131) | White Clover | near (~131) |
| 5–7 | (−240,0,−161), (0,0,−156), (240,0,−161) | Dandelion | near (~158) |
| 8–10 | (−180,0,−196), (10,0,−201), (185,0,−194) | Lavender | mid (~198) |
| 11–12 | (−90,0,−221), (90,0,−224) | Sunflower | mid (~224) |
| 13–14 | (−300,0,−246), (300,0,−246) | Linden Blossom | far (~264) |
| 15–16 | (−30,0,−261), (40,0,−264) | Moonflower | far (~266) |
| 17 | (0,0,−286) | Fireweed (Gen 1+) | far (~286) |
| 18 | (0,0,−341) | Aurora Bloom (Gen 3+) | very far (~344) |

All X coordinates are unchanged. All Z coordinates carry a single uniform shift of **−86 studs** relative to the first draft (see *Ground-level Z stack* under Zone: Petal Path — the decks physically occupy Z −55..+55, so nothing at ground level may sit north of Z = −96); the near-to-far species progression and every patch's relative position within the meadow are preserved exactly. Patches 1–16 sit inside the main meadow slab (Z −96..−266); patches 17–18 sit in the Gen-gated deep-meadow strip south of it, as before.

- **CHARACTER:** A jungle, because you are 5 studs tall. Stems above your head, light coming down in shafts, and *you cannot see where you are going*. The meadow is deliberately harder to navigate than any tycoon plot has a right to be, because getting lost in it and then finding a sunflower the size of a house is the best 20 seconds a new player will have. Every patch you find is a small private discovery before it becomes a number.
- **LIFE:**
  - *Ambient:* grass sways on a 3s offset sine (a few tufts only -- cheap, and motion at the edge of vision is what makes a space feel alive). Pollen motes drift. Other players' bees cross overhead in golden lines, which means the meadow always looks busy even when you're alone in it. Patch flower heads slowly close as their bloom window ends and open when it begins -- the world tells the time without a clock.
  - *Triggered:* walking into a grass tuft parts it and puffs pollen. Stepping onto an unmarked blooming patch raises a `MARK` prompt and the flower head tilts toward you. Stepping onto a *depleted* patch shows grey pips and drooping heads -- the disappointment is informative.
  - *Reactive:* a wasp scout that has targeted someone will visibly fly over the meadow toward that plot -- an early warning available to anyone paying attention.

---

### Zone: Pine Treeline (resin)

- **Position:** centered (0, 0, +105) — unchanged; this band sits *north* of the plot decks (behind the fence at plot local Z = +52) and is unaffected by the ground-level Z stack south of the decks. Also a perimeter ring at X = ±430 and Z = −386 (the southern boundary run, shifted with the Apiary Yard so it stays behind the shed corner)
- **Dimensions:** back band 900 × 70, trunks up to 180 studs tall
- **Floor:** `Ground` `#4A3F2E` needle litter
- **Walls:** trunks `Wood` `#5A3E28`, canopy `Grass` desaturated `#3E5C34`
- **Accents:** resin nodes -- `Glass` amber `#C9821E`, faintly emissive
- **Lighting:** 4 resin-node `PointLight`s, Color `#C9821E`, Range 18, Brightness 0.7. Otherwise this zone is *the darkest place in the game*.
- **Part count:** ~150
- **Key objects:** 18 pines (~7 parts each), 4 resin nodes at (−220,4,+95), (−70,4,+100), (80,4,+100), (230,4,+95)
- **Connections:** Molasses's approach lane runs behind it at Z = +140, 16 studs wide; he enters a plot through the fence gap at that plot's local (+45, +52).
- **CHARACTER:** Cold, tall, quiet, and it does not care about you. This is the one zone that feels older than the game. The resin is the most valuable raw material you can get and it sits in the least pleasant place -- that asymmetry is the whole point of propolis as a resource. Something large lives past these trees.
- **LIFE:**
  - *Ambient:* one slow resin drip every 5–9s per node, with a wet tick sound. Wind through needles. A distant low rumble every 40–70s once `bear.stage ≥ 1` -- Molasses, off-screen, existing.
  - *Triggered:* walking under a canopy drops a needle shower. Standing on a resin node raises the MARK prompt and the node dims as it's tapped.
  - *Reactive:* 45 seconds before a raid, the pines at the target plot's end of the treeline shudder and birds scatter -- a *diegetic* warning that rewards spatial awareness, delivered before the UI banner.

---

### Zone: Apiary Yard (hub) — v2, EXPANDED

- **Position:** centered (0, 0, −406)
- **Dimensions:** 400 × 280 (X −200..+200, Z −546..−266), ground at Y = 0. North edge at Z = −266 abuts the Wild Meadow — unchanged. The hub grew south and wide.
- **Floor:** `Cobblestone` `#9A9384` flagstone base with three large `Slate` stepping-stone slabs leading north toward the gateway row; weeds and moss in the cracks; a faint soil band along the shed base
- **Walls:** giant `WoodPlanks` shed wall at Z = −526, 200 studs wide, 130 studs tall. Window aperture at Y = 45 with a warm soft-white `PointLight` inside (the human is gone but left the kitchen light on). Two shed eave PointLights as before.
- **Part count:** ~500
- **Lighting:** 5 local lights:
  - 2 eave PointLights: `#FFCE8A`, Range 45, Brightness 1.4 — warm, always-on, "safe"
  - 1 shed window PointLight (interior): `#FFF4DC`, Range 55, Brightness 0.9 — casts a warm yellow rectangle onto the cobblestones below at night
  - 1 flowerpot interior PointLight: `#FF9A4A`, Range 30, Brightness 0.7 — makes the pot read as a clubhouse; the bee world's version of a campfire
  - 1 birdbath water PointLight: `#B8D8FF`, Range 20, Brightness 0.5 — a single cold-tinted reflection, contrasting the warm tones everywhere else

**Zone layout (north to south):**

**1. Gateway Row** (Z −266..−330, full 400 wide):
- Six mini hive-box gateways, one per plot, evenly spaced at X = −250..+250 (spacing 100), at Z = −290
  Each gateway: a stack of 2 white-painted WoodPlanks boxes (8×8 each), with a small coloured pennant on a stick above (pennant colour matches each plot's assigned colour). Tagged `TeleportPad` with `PlotIndex` attribute. On touch: teleports to plot ramp, pennant flutters.
- **Hub Bell** at (0, 12, −298): a giant thimble (2 stacked frustum-like cylinders, Metal `#B0A890`, 8 studs tall) hanging from a 20-stud wooden crossbeam supported by two posts. Bell rings on raids and weather shifts. Tagged `HubBell`.
- Path is extra wide here (full 400 studs) — the first thing a newly-spawned player sees: a row of six glowing hive boxes stretching across the garden, each one representing a real player's home. **This is the first social moment.** At a glance they know how many players are on the server and where they are.
- **SpawnLocation** at (0, 1.5, −300) — engine requirement. `PlotService` teleports players to their plot ramp immediately; hub remains reachable on foot.

**2. Social Garden** (Z −330..−440, full 400 wide):
- **Birdbath** at (−80, 0, −385): 25-stud diameter shallow bowl on a fluted pedestal, `Cobblestone` / `Slate` material. Water surface is a flat Glass disc, `#B8E4FF`, faintly Neon. Small ripple ParticleEmitter above it. A place players walk around; slightly blocks line-of-sight to the shed, breaking up the space.
- **Garden Table** at (90, 0, −390): flat WoodPlanks slab (30×20), two log-slice seats flanking it. On the table: a giant ceramic tea mug (12 studs tall, white with a brown smudge where it was held), a folded newspaper, a trowel handle sticking upright. Under the table: a tea-candle PointLight (`#FFCE8A`, Range 20, Brightness 0.6) — the second guaranteed-warm light source.
- **Global Leaderboard** at (−140, 0, −395): a giant cork board on two wooden posts, 60 wide × 40 tall. `SurfaceGui` on the front face, top-10 lifetime honey with player names and generation markers. Hovering nearby makes the top entry's name shimmer (gold Neon tween). Tagged `LeaderboardBoard`.
- Scattered between: 3 seed packets (small flat rectangles leaning against things), a pair of giant garden gloves on the ground (flat fabric-material wedge shapes), a glass marble near the birdbath (Glass, `#A8D8FF`, 4 studs diameter — inexplicably beautiful at bee scale).

**3. The Flowerpot Den** (Z −440..−490, centred at X = 20):
- **The Great Pot**: a giant terracotta flowerpot (WoodPlanks-equivalent brick material `#B5572A`) tipped on its side. Outer diameter 50 studs, inner hollow diameter 36 studs, rim thickness 7 studs. Lying at ~15° angle with its mouth pointing slightly toward the player path. Inside: warm orange PointLight (`#FF9A4A`), small pebble floor, and three tiny pansy sprouts (3-part each, `Grass` material `#9B7FD4` for petals). Soil spills from the mouth in a swept arc of `Ground` material parts.
- This is the **social landmark** of the hub — where players will say "meet me at the pot." Its interior is just big enough to walk into (26 studs internal clearance, players are ~5 studs tall). It does nothing mechanically; it is purely a spatial identity piece. Every hub needs one thing that isn't functional.
- A crack runs up the pot's south face (a thin dark wedge part) — the reason it fell.
- **Watering Can** at (−110, 0, −455): the classic hub prop, now properly huge — 90 studs long, `SmoothPlastic` `#7A9E7E` (garden-green, slightly faded). Tipped on its side, nozzle pointing at a small stone puddle beneath it. Slow drip ParticleEmitter on the nozzle, ripple on the puddle. Mossy and clearly been here a while.

**4. Shed Wall** (Z −490..−546, back wall):
- Main shed wall: WoodPlanks `#7A5C3A`, 200 wide × 130 tall, at Z = −526. Slightly textured — 3 overlapping plank layers at different wood colors for depth.
- **Shed window** at (50, 45, −526): a 30×20 aperture with a cross-frame (4 thin WoodPlanks parts), the warm interior light glowing through it. Visible from anywhere in the hub at night.
- **Garden tools**: a leaning shovel (80-stud cylinder handle, flat ellipse spade head, Metal `#6A7A6A`) at (−60, 0, −522) leaning against the wall; a rake head flat on the ground below the leaning handle.
- **Stack of hive boxes** at (120, 0, −520): 4 stacked old apiary boxes (WoodPlanks, cream-painted `#E8D49A` with age-stain `#C4A87A`), 16 studs each — the same design as the plot gateways but abandoned and unlabelled. The player's active hives are living; these are the discarded ones.
- **A boot** at (−150, 0, −500): exactly as before — 50 studs tall, `WoodPlanks`, `#5A4430`, moss growing inside (3-part tuft `Grass` `#5A8A44` inside the boot opening). The boot is load-bearing for the tone of this zone. Keep it.

- **Connections:** Petal Path spur from (0, 0, −286) north to the main path at Z = −88 — 16 wide, X −8..+8, Z range −286..−88. UNCHANGED — do not move this connection.
- **CHARACTER:** You are in a human's garden that the human has been away from for a season. Everything is at the stage between "tidy" and "reclaimed by the garden." The boot has moss in it. The watering can has a drip. The tea mug on the table is still there. The shed light is still on. Someone left in a hurry, or just got distracted, and the garden — and the bees — carried on without them. This zone should feel warm, slightly melancholy, and full of scale comedy: a marble is a boulder, a flowerpot is a cathedral, a teacup holds a lake. **The question "what happened to the human?" should arrive unbidden and never be answered.**
- **LIFE:**
  - *Ambient:* dust motes drifting through the eave light and the shed window shaft. Slow watering can drip every 4s with puddle ripple. Birdbath water shimmer. Thimble bell sways and chimes faintly every ~25s. Distant lawnmower every ~90s. At night: only the shed window light remains; the birdbath PointLight shifts to a cold blue; the flowerpot's warm interior glow becomes the social campfire of the hub.
  - *Triggered:* stepping onto a Gateway hive box lights the pennant gold and fires a gentle chime. Standing at the leaderboard makes the top entry shimmer. Walking into the flowerpot interior plays a soft enclosed-space ambient (reverb on the ambient loop).
  - *Reactive:* when a raid starts anywhere, the bell rings hard three times and the eave lights flicker. For Stage 2+ Molasses raids (the bear has learned the back path), the shed window light flickers briefly — diegetic foreshadowing that something old and knowing is moving out there.

---

### Zone: Petal Path

- **Position:** a 16-stud-wide lane centered on Z = −88 (spans Z −96..−80), X from −360 to +360
- **Floor:** `Cobblestone` stepping stones `#9A9384` with fallen petals `#F2A81C`
- **Ground:** this zone also owns the ground slab for the whole approach band **Z −96..−55, X −400..+400** (the strip between the meadow's near edge and the decks' front edge). The meadow slab no longer reaches this far north, so without this slab the ramp feet and the path stones would sit over a void. `Grass` `#6FA84A`, top at Y = 0, to read continuously with the meadow.
- **Part count:** ~26 (24 stones + approach ground slab)
- **Ground-level Z stack (the load-bearing constraint for this whole corridor):** each plot deck is a 110 × 110 slab centered at its plot position, so **every deck physically occupies world Z −55..+55**. Nothing at ground level may sit inside that range. The corridor south of the decks is therefore packed with zero slack:

| Band | Z range | Depth |
|---|---|---|
| Plot deck (built, fixed) | −55 .. +55 | 110 |
| Plot ramps (14 wide, per plot X) | −80 .. −55 | 25 |
| Petal Path (16 wide) | −96 .. −80 | 16 |
| Wild Meadow | −266 .. −96 | 170 |
| Apiary Yard (hub) | −406 .. −266 | 140 |

  55 + 25 + 16 = 96, so Z = −96 is the northernmost possible meadow edge. This is why the meadow and hub carry a uniform −86 shift and the path a −58 shift from the first draft.
- **Connections:** every plot ramp — ramp *top* at plot local (0, −55), the deck's real front edge; the ramp runs **south** from there and its foot meets the path's north edge at Z = −80 — plus the hub spur at X 0.
- **CHARACTER:** A corridor with 40-stud grass walls that gives you controlled glimpses of the plots. You walk it constantly -- to the meadow, home, to help a neighbour smoke a bear -- so it must always show you something: whose comb is glowing, whose bees are busy, whose sign says Generation 4. This path is the game's social bandwidth.
- **LIFE:** petals drift across it; a plot's Bud Button pop is audible from here; each plot's glow spills onto the stones so you can read the whole server's wealth by walking 700 studs.

---

## Door / Connection Map

There are no interior doors. Every connection is an open traversal, and the exact widths matter for pathfinding.

```
Apiary Yard (0,−336) --spur, 16 wide, Z −286..−88--> Petal Path (Z = −88)
Petal Path --ramp, 14 wide, at each plotCenter X, Z −80..−55, rises Y 0->6.5 northward
             (foot Z −80 on the path's north edge, top Z −55 at the deck's front edge)--> Comb Deck (× 6)
Comb Deck Floor 1 --wax spiral ramp, 9 wide, local (+34,+14), Y 6.5->22.5--> Comb Floor 2
Comb Deck Floor 2 --wax spiral ramp, 9 wide, local (+34,+14), Y 22.5->38.5--> Comb Floor 3
Petal Path --open, no barrier, Z −88..−96--> Wild Meadow (near edge Z = −96)
Wild Meadow --open, Z −266..−386 (Gen-gated patches only)--> deep meadow
Comb Deck --gap between decks, 20 wide, at plotCenter ±65--> neighbour boundary (walkable)
Plot Deck local (+45,+52) --FENCE GAP, 12 wide, breakable--> Bear Lane (Z = +140)
Bear Lane --16 wide, X −345..+345--> Treeline --> Molasses Den (0,0,+185)
```

**Pathfinding minimums enforced:** bear lane 16 studs, fence gaps 12 studs, ramps 14 studs (9 for the wax spirals, which the bear can never use -- deliberate: **Floor 2 and 3 honey is bear-proof**, a real and legible reward for vertical growth), petal path 16 studs. Bear `AgentRadius = 6`, `AgentHeight = 26`, `AgentCanJump = false`, `WaypointSpacing = 8`. Wasps fly and ignore pathfinding entirely.

---

## Building / Upgrade Tiers

All numbers live in `Config`. Honey is the currency; propolis is the second construction cost; pollen feeds brood; royal jelly buys queens and perks.

### Comb cells (built in Build Mode on the hex lattice)

| Cell type | Honey | Propolis | Function | Adjacency rule (the puzzle) |
|---|---|---|---|---|
| **Honey Cell** | 60 | 0 | stores + ripens nectar->honey. Cap 40 honey, intake 1.2 nectar/s | +6% ripen speed per adjacent Honey Cell (max 6) -> build honey in **blocks** |
| **Brood Cell** | 90 | 0 | +6 population cap, hatches bees | +8% hatch speed per adjacent Honey Cell (warmth, max 6) -> brood belongs in the **middle** |
| **Pollen Cell** | 75 | 0 | stores 60 pollen, feeds brood | **must touch ≥1 Brood Cell** or runs at 50% (bee bread) |
| **Royal Cell** | 2,500 | 60 | produces Royal Jelly = 0.004/s × adjacent Brood Cells | **rim cells only** (real queen cells hang at the comb margin) |
| **Propolis Seam** | 120 | 8 | +1% all output, +6% threat resistance each | **outer ring only**; Molasses breaks one per stage-5 raid |

**Cell tier upgrades** (per individual cell -- placement is permanent, quality is not):

| Tier | Name | Cost multiplier | Output multiplier | Gate |
|---|---|---|---|---|
| 1 | Wax Cell | base | ×1.0 | — |
| 2 | Reinforced Wax | ×4 honey | ×2.2 | — |
| 3 | Propolis-Lined | ×5 honey + ×2 propolis | ×2.4 | Kiln T2 |
| 4 | Golden Comb | ×6 honey | ×2.8 | Queen ≥ Q4 |

So a maxed Honey Cell costs `60 · 4 · 5 · 6 = 7,200` honey cumulative and produces `1.2 · 2.2 · 2.4 · 2.8 = 17.7` nectar/s intake. Cost/output ratio rises from 50 to 407 -- a deliberately worsening return that pushes players toward *more cells and more floors* rather than infinitely deepening one cell.

### Comb floors

| Floor | Name | Cells | Honey | Propolis | Gate | Reveal |
|---|---|---|---|---|---|---|
| 1 | Brood Comb | 19 (18 buildable) | free | — | start | — |
| 2 | Upper Comb | 12 | 40,000 | 350 | F1 ≥ 80% built | wax spiral unrolls; F2's shadow falls across F1 |
| 3 | Crown Comb | 7 | 500,000 | 2,000 | F2 ≥ 80%, Generation ≥ 1 | **rises above the fence line -- the whole-server view** |

### Dance Floor (route capacity + dance accuracy)

| Tier | Name | Honey | Route slots | Golden zone | Extra |
|---|---|---|---|---|---|
| 1 | Bare Comb | start | 2 | 18° | — |
| 2 | Polished Floor | 900 | 3 | 24° | — |
| 3 | Scented Floor | 7,500 | 4 | 30° | routes decay 30% slower |
| 4 | Resonant Floor | 60,000 | 6 | 38° | +10% all route quality |
| 5 | Grand Dance Floor | 400,000 | 8 | 46° | routes never fully Lost (floor at Poor) |

*(+1 route slot per unlocked comb floor, so a maxed player runs 10.)*

### Propolis Kiln (resin -> propolis)

| Tier | Name | Honey | Conversion | Rate cap |
|---|---|---|---|---|
| 1 | Clay Kiln | start | 4 resin -> 1 propolis | 0.4/s |
| 2 | Stone Kiln | 6,000 | 3 -> 1 | 1.5/s |
| 3 | Wax-Sealed Kiln | 90,000 | 2 -> 1 | 6.0/s |

### Apiary Shed (shop + emergency propolis)

| Tier | Name | Honey | Effect |
|---|---|---|---|
| 1 | Lean-To | start | cosmetics; propolis at 400 honey each (deliberately terrible -- resin routes are the real answer) |
| 2 | Workshop | 15,000 | propolis at 180 honey; unlocks perk respec (once per generation) |
| 3 | Apothecary | 150,000 | propolis at 90 honey; +1 achievement reward tier |

### Queen tiers (Royal Jelly)

| Tier | Name | RJ | Lay interval | Global output | Unlocks | Visual |
|---|---|---|---|---|---|---|
| Q1 | Virgin Queen | start | 12.0s | ×1.00 | — | small, pale, walks fast |
| Q2 | Laying Queen | 5 | 8.0s | ×1.15 | — | longer abdomen, gold banding |
| Q3 | Crowned Queen | 20 | 5.0s | ×1.35 | **Nurse caste** | wax crown, slower regal walk |
| Q4 | Matriarch | 75 | 3.0s | ×1.60 | **Golden Comb**, Swarm eligibility | 1.8× size, amber glow, attendant bees orbit her |
| Q5 | Sun Queen | 250 | 1.8s | ×2.00 | **Crown Comb (F3)** | 2.5× size, sun halo, comb ripples gold behind her |

### Flower species (the day/night engine)

| Species | Bloom window (in-game) | Nectar/trip mult | Pollen ratio | Resin | Distance |
|---|---|---|---|---|---|
| White Clover | 06:00–18:00 | 1.0 | 0.5 | — | ~45 |
| Dandelion | 06:00–11:00 | 1.3 | 0.9 | — | ~72 |
| Lavender | 10:00–16:00 | 1.7 | 0.3 | — | ~112 |
| Sunflower | 09:00–17:00 | 2.4 | 1.2 | — | ~138 |
| Linden Blossom | 16:00–21:00 | 3.1 | 0.2 | — | ~178 |
| Moonflower | 20:00–05:00 | 4.2 | 0.1 | — | ~180 |
| Pine Resin | always | — | — | 1.0 | ~200 |
| Fireweed (Gen 1+) | 08:00–18:00 | 5.5 | 0.8 | — | ~200 |
| Aurora Bloom (Gen 3+) | 21:00–04:00 | 9.0 | 0.4 | — | ~258 |

A full in-game day is **12 real minutes**, so every player experiences every window within one session -- the schedule creates rhythm, never lockout.

### Foraging math

```
carry        = 8 + deepCropPerk                  -- nectar units per trip
flightSpeed  = 18 · (1 + 0.08·strongWingsPerk)   -- studs/sec
tripTime     = 2·distance/flightSpeed + 3        -- +3s load/unload
yieldPerTrip = carry · speciesMult · richness · routeQuality · weatherMult
ratePerBee   = yieldPerTrip / tripTime

SUPPLY = Σ over routes (patch richness-limited throughput)
WINGS  = foragerCount · (best available ratePerBee, distributed greedily)
COMB   = Σ honeyCell intake · (1 + 0.06·adjacentHoney) · tierMult
flow   = min(SUPPLY, WINGS, COMB) · queenMult · (1 + 0.22·generation) · (1 + 0.01·propolisSeams)
honey  += flow / 3      -- 3 nectar : 1 honey
```

Worked example -- a fresh player, one Perfect clover route at 45 studs, 3 foragers, 2 honey cells:
`tripTime = 2·45/18 + 3 = 8.0s`; `yieldPerTrip = 8 · 1.0 · 1.0 · 1.25 = 10`; `ratePerBee = 1.25 nectar/s`; `WINGS = 3.75`; `COMB = 2.4`. Bottleneck = **COMB**, HUD says "NEED COMB!", honey flows at `2.4/3 = 0.8/s`. The player's first 60-honey cell pays back in 75 seconds. That is a correct tycoon opening curve.

### Castes

| Caste | Job | Cost / catch |
|---|---|---|
| **Forager** | flies routes -- the WINGS bar | none |
| **Nurse** | +3% hatch speed each (cap +90%), +40% Royal Cell output | doesn't forage (Queen Q3+) |
| **Guard** | −6 bear patience per sting, kills 1 wasp each | **dies when it stings** -- defence permanently costs population |
| **Drone** | produces nothing | **25 required to Swarm** -- a deliberate, felt investment in prestige |

`popCap = Σ(broodCells · 6 · cellTierMult)`. Each hatch eats 4 pollen.

### Royal Jelly perks (permanent across generations, cost = `3 × (level+1)` RJ)

| Perk | Effect / level | Max |
|---|---|---|
| Clear Signal | golden zone +6% | 5 |
| Strong Wings | flight speed +8% | 6 |
| Deep Crop | carry +1 | 8 |
| Warm Brood | hatch speed +6% | 6 |
| Thick Propolis | threat resistance +7% | 6 |
| Hive Steward | auto-harvest at ripeness 1.0 (10% / 25% / 50% of cells per minute) | 3 |
| Starter Comb | begin each generation with 3 / 6 / 10 pre-built cells | 3 |
| Long Memory | route decay −15% | 4 |

### Swarming (prestige)

**Requires:** Queen ≥ Q4 · 25 Drones · ≥1 capped Royal Cell · `genHoney ≥ 2,000,000 × 3^generation`
**Grants:** `royalJelly += 20 + floor(genHoney / 250,000)` (cap 400); `generation += 1`; permanent `×(1 + 0.22·generation)` to all output; a new lineage name.
**Gates opened:** Gen 1 -> Fireweed + Crown Comb eligibility · Gen 2 -> Golden Comb discount −20% · Gen 3 -> Aurora Bloom · Gen 5 -> **Second Queen** (two queens on one comb; lay intervals stack)

### Threats

**Wasps** -- every 4–7 minutes a scout targets the plot with the most exposed honey. 20-second window: guards auto-kill it (needs ≥2 guards) or any player taps it (`SwatWasp`). Unhandled -> 60 seconds later a raid of 4–8 wasps steals 30% of stored pollen and kills `raidSize/2` bees. Frequent, small, and it teaches defence before Molasses ever shows up.

**Old Molasses** -- a six-stage arc, stored per player in `bear.stage`. Targets `max(honeyAmount · ripeness)` across all plots, announced 45s early to the whole server.

| Stage | When / how he arrives | Patience | Theft | Notes |
|---|---|---|---|---|
| 0 | — | — | — | Claw marks appear on your fence at ~10 min. Foreshadowing only. |
| 1 | Front lane, broad daylight, slow and curious | 60 | 40% | Trivially repelled. Teaches the Smoker. |
| 2 | **He remembers.** Dusk, from the treeline, straight to your comb | 110 | 38% | He learned the back way in |
| 3 | **He waits for rain** -- foragers home, guards sheltering (guard damage halved) | 170 | 35% | The first genuinely hard one |
| 4 | **He brings the Cub.** Cub is fast and goes for your Pollen Cells | 240 | 32% | Two targets, one Smoker |
| 5 | **He tests you.** Breaks one Propolis Seam permanently | 320 | 28% | You must rebuild |
| 6 | **The Sitting.** He arrives, sits at your gate, and does not attack | — | — | **You choose.** |

**Defence:** Smoker (−14 patience, 2.5s cooldown, usable by *any* player on *any* plot -- the cooperation is the point); guards (−6 each, then die); Propolis Seams (+6% resistance each, and slow his entry). Patience depleted -> repelled: `bear.repels += 1`, everyone who landed ≥3 smoke hits gets +1 Royal Jelly and the *Bear Wrangler* achievement, and a paw print stays on your deck as a trophy.

**Stage 6 -- the fork (`BearOffering`):**
- **"Offer a Jar"** (5,000 honey) -> he eats it, huffs, and leaves. He becomes **Molasses the Neighbour**: he naps permanently in the wild meadow, passively kills any wasp raid within 200 studs of your plot, and a rare high-richness patch blooms where he sleeps. Unlocks the **Molasses Fur** bee skin.
- **"Refuse"** -> **Furious Molasses**, forever. He raids every 6 minutes at patience 400 and steals 45%, but *every* repel grants 3 Royal Jelly. Unlocks the **Furious** bee skin.

Both are permanent, mutually exclusive, and visible on your plot sign. This single choice is the game's replay engine and its best conversation piece.

### Weather

| State | Duration | Effect |
|---|---|---|
| Clear | 240s | baseline |
| Breezy | 90s | flight speed −12%, grass motion doubles |
| Overcast | 90s | nectar ×0.85 |
| Rain | 60s | **flight halted**, all bees visibly stream home, guard damage halved (Molasses stage 3 window) |
| Bloom Rush | 90s | all patch richness restored +50%, nectar ×1.35, heavier visible motes, rainbow over the meadow |

Rain is always followed by Bloom Rush -- a punishment that is really a setup, so weather feels like rhythm rather than tax.

---

## Tags

| Tag | Count | Attributes | Purpose |
|---|---|---|---|
| `PlotRoot` | 6 | `PlotIndex, OwnerUserId, OwnerName, LineageName, Generation, HoneyPerMin, BeeCount, RipeningHoney, Ripeness, BearStage, QueenTier, CombFloors` | plot identity + free public replication for signs, glow and social read |
| `CombCell` | ≤ 57/plot | `PlotIndex, Floor, Q, R, CellType, Tier, Amount, Ripeness` | cell identity for build, glow, harvest |
| `DimCellPlate` | 19/plot at start | `PlotIndex, Floor, Q, R` | unbuilt outline; Build Mode targets these |
| `DanceFloor` | 1/plot | `PlotIndex, Tier, RouteSlots` | dance proximity check |
| `LandingBoard` | 1/plot | `PlotIndex` | harvest interact, bee spawn/return anchor |
| `Smoker` | 1/plot | `PlotIndex` | bear defence interact (any player) |
| `GuardPerch` | 2/plot | `PlotIndex, Slot` | guard bee visual anchor |
| `BudButton` | 8/plot | `PlotIndex, ItemId, Cost, Requires` | physical structure purchase |
| `SwarmPerch` | 1/plot | `PlotIndex` | prestige interact |
| `WardrobePad` | 1/plot | `PlotIndex` | cosmetics |
| `PlotSign` | 1/plot | `PlotIndex` | SurfaceGui public stats |
| `FlowerPatch` | 18 | `PatchId, Species, Richness, Blooming, Distance` | foraging source |
| `ResinNode` | 4 | `PatchId, Richness` | propolis source |
| `TeleportPad` | 6 | `PlotIndex` | hub gateways |
| `LeaderboardBoard` | 1 | — | global top 10 |
| `HubBell` | 1 | — | raid / weather alert |
| `BearWaypoint` | ~14 | `Index, Lane` | Molasses patrol + approach |
| `FenceGap` | 6 | `PlotIndex, Broken` | bear entry, breakable |
| `Bee` | runtime, client | `Caste, PlotIndex, RouteSlot` | pooled visual |

---

## Lighting Design Brief

**Global mood:** *A warm summer garden at bee scale, where the only thing that glows is what you have not spent yet.*

**Colour temperature map:**
- **Warm (safe, owned, yours):** your comb deck, the Landing Board, the Apiary Yard eave. Amber `#F2A81C` -> cream `#FFD89B`.
- **Neutral (open, exposed):** the Wild Meadow -- sun-driven only, no local lights, so it swings from warm morning to cold night purely from `ClockTime`. Being in the meadow at night should feel meaningfully less safe than being on your comb.
- **Cold (indifferent, old, dangerous):** the Pine Treeline `#8FA6C4`, the Moonflower cluster `#8FB4FF`, and Molasses's den (no light at all).
- **Alarm:** during a raid, every honey cell light on the target plot shifts to `#D8452B` over 0.8s and pulses at 1.4 Hz. The plot visibly turns from gold to red. Every other player can see it from anywhere on the map.

**Studio starting state note for lighting-director:** the place already contains `Sky`, `SunRaysEffect`, `Atmosphere`, `BloomEffect`, `DepthOfFieldEffect` from the Baseplate template. **Reconfigure these in place -- do not create duplicates.** `ColorCorrectionEffect` is absent and must be created. `Technology` must be set to `Future` (this game lives on coloured local lights and soft shadows across a honeycomb; `ShadowMap` flattens the comb's depth and `Voxel` destroys the per-cell glow).

**Global Lighting:** `ClockTime` driven by `TimeService` (12-min day, 05:00 dawn -> 20:00 dusk); `Brightness = 2.6` day / `0.55` night; `Ambient = #4A4438` day / `#181C2A` night; `OutdoorAmbient = #7A7A6A` day / `#20263A` night; `ExposureCompensation = 0.12`; `GlobalShadows = true`.

**Post-processing stack:**
- `ColorCorrectionEffect` -- `Saturation = 0.16`, `Contrast = 0.10`, `TintColor = #FFF6E2`, `Brightness = 0.02`. Slightly oversaturated warm: this is a children's garden, not a documentary. At night, tween `Saturation` to `-0.05` and `TintColor` to `#DDE6FF`.
- `BloomEffect` -- `Intensity = 0.42`, `Size = 22`, `Threshold = 0.82`. High threshold so *only* honey, resin and neon rims bloom. Honey must be the brightest thing in frame at all times; that is how the player's eye finds their own wealth.
- `DepthOfFieldEffect` -- `FocusDistance = 44`, `InFocusRadius = 34`, `NearIntensity = 0.18`, `FarIntensity = 0.62`. This is the single most identity-defining effect in the game: strong far-blur reads as **macro photography**, which makes a 110-stud deck feel like a two-inch honeycomb. Do not reduce `FarIntensity` below 0.5 -- the tiny-scale illusion depends on it.
- `SunRaysEffect` -- `Intensity = 0.14`, `Spread = 0.9`. Shafts through the meadow grass. Fade to 0 at night.
- `Atmosphere` -- `Density = 0.16`, `Color = #FCEFC6`, `Decay = #C9A86A`, `Offset = 0.25`, `Haze = 1.6`, `Glare = 0.35`. Pollen haze. **Never exceed 0.28** -- above that the meadow becomes unreadable on mobile.

**Key dramatic lights:**
- **Comb Deck** -- one `PointLight` per filled Honey Cell, `Color #F2A81C`, `Range 14`, `Brightness = 0.4 + 1.1·(ripeness−1)/1.2`, `Shadows = true`. *Narrative purpose: the player's bank balance is the light level of their home.* Breathing cycle 4s, phase-offset per cell.
- **Landing Board** -- `SpotLight`, `#FFD89B`, `Range 30`, `Brightness 1.6`, `Angle 70`, down. *Guides the eye to the one interact point that matters.*
- **Royal Cell** -- `PointLight`, `#FFF0C0`, `Range 18`, `Brightness 1.1`, slow 6s pulse. *Marks the rarest, most valuable cell type.*
- **Queen Q4/Q5** -- `PointLight` parented to the Queen, `#FFE9A8`, `Range 22`, `Brightness 0.9` (Q4) / `1.6` with visible halo (Q5). *A moving light source on your own plot -- she draws the eye wherever she walks.*
- **Resin Nodes** -- `PointLight`, `#C9821E`, `Range 18`, `Brightness 0.7`. *The only light in the darkest zone; makes the far, unpleasant trip legible.*
- **Moonflower cluster** -- 4 `PointLight`, `#8FB4FF`, `Range 50`, `Brightness 1.2`, active 20:00–05:00 only. *Turns night from dead time into prime time.*
- **Apiary Yard eave** -- 2 `PointLight`, `#FFCE8A`, `Range 45`, `Brightness 1.4`. *The only always-warm place; defines "safe".*

**Light scripting notes:**
- Cell brightness is written by `ResourceService` on wallet change, tweened 0.4s. Never per-frame.
- Raid: all target-plot cell lights tween to `#D8452B` over 0.8s and pulse 1.4 Hz. On repel, tween back to gold over 2s.
- Rain: `Brightness -> 1.1`, `Atmosphere.Density -> 0.26`, `SunRays -> 0`, all tweened over 6s. Bloom Rush: `Brightness -> 3.0`, `Saturation -> 0.26` over 3s, then settle.
- **Capping Night**: every cell light on a floor tweens to `#FFFFF0` at `Brightness 2.4` in a wave from centre outward (0.12s stagger per hex ring), holds 8s, settles.
- Performance ceiling: **max 24 shadow-casting lights per plot.** Beyond 24 filled cells, additional cell lights are created with `Shadows = false`. `lowDetail` setting caps a plot at 8 lit cells.

---

## Art Direction Guide

**Colour palette (5 roles):**

| Role | Name | Hex | Where used |
|---|---|---|---|
| Primary (dominant surfaces) | Meadow Green | `#6FA84A` | meadow ground, grass tufts, canopy |
| Secondary (structure) | Wax Cream | `#E8D49A` | every comb cell, ramps, the built world. Paired with **Propolis Brown `#7A4A22`** for structural seams and deck base. |
| Reward | Honey Gold | `#F2A81C` | honey, resin, ripeness glow, Bud Buttons, all UI currency, bee stripes |
| Danger / Alert | Alarm Red | `#D8452B` | wasps, raid lighting, bottleneck bar, broken seams, the Smoker's glow |
| Atmosphere | Pollen Haze | `#FCEFC6` | fog, pollen motes, sun shafts, light tint |

Flower heads are the *only* place other hues appear (lavender `#9B7FD4`, sunflower `#E8C020`, moonflower `#C7D8FF`, fireweed `#E0518A`, aurora `#7FE8D0`) -- which is exactly why a blooming patch reads instantly across 200 studs of green. **No agent introduces a colour outside this list without a flower attached to it.**

Additional required state colour: **Dormant Grey `#8E8A7A`** for unbuilt cell plates and depleted patch heads -- the visual language of "not yours yet / used up."

**Material language (one meaning per material, enforced game-wide):**
- `Grass` = wild, alive, outside your control
- `SmoothPlastic` (cream) = **wax -- the player built this.** The only material that means "yours."
- `Glass` = honey and resin -- value you can see through
- `Neon` = value at maximum (ripeness ≥ 2.0 rims, Royal Cell, Aurora Bloom). **Used sparingly; Neon means "act now."**
- `WoodPlanks` / `Wood` = the human world -- always oversized, always slightly ominous by scale alone
- `Slate` / `Cobblestone` = permanence, the path, the hub, things that were here before bees
- `Ground` = worn, depleted, trodden
- `Fabric` = Molasses's fur -- the only soft thing in the game

**Scale reference -- the rule that unifies every agent:** the player bee is ~5 studs. Everything organic is **3–4×** human-plausible; everything human-made is **~12×**.
- comb cell: 15 studs across, 3 tall walls
- grass blade: 14–22 studs tall
- clover head: 14 diameter on a 20-stud stem
- sunflower head: 26 diameter on a 48-stud stem
- fence board: 60 tall, 4 thick
- watering can: 70 long
- Old Molasses: 26 studs tall (five times the player -- he should be genuinely frightening at bee scale, and comically small to a human, and that joke is the point)
- comb floor spacing: 16 studs vertical

**Prop density targets:**
- **Comb Deck: medium-low.** The comb is a build grid -- clutter here actively damages the game. Props only at the perimeter (wax drips, spilled pollen, a stray petal). *The cells themselves are the detail.*
- **Wild Meadow: dense.** Grass tufts must block sight lines; the meadow's job is to be hard to read.
- **Apiary Yard: dense and absurd.** Giant human junk, mossy, comfortable.
- **Treeline: sparse and tall.** Verticality and shadow, nothing else. Emptiness here is intentional.
- **Petal Path: medium.** Enough to feel travelled, never enough to obstruct.

---

## Signature Moments (implementation-ready)

### 1. The Molasses Fork -- "I fed the bear and now he's my bodyguard"
- **Trigger:** `bear.repels == 5` -> at the next raid slot, `ThreatService` sets `bear.stage = 6` and fires `ThreatEvent{kind="bear", phase="sitting", targetPlot=n}`.
- **What happens:** No warning rumble -- instead, *silence*. All ambient bee sound on the plot ducks to 20% over 3s. Molasses walks slowly up the **front** lane for the first time since stage 1, stops at the ramp foot, and sits down. The raid HUD does not appear. Instead two large buttons: **OFFER A JAR (5,000 honey)** and **REFUSE**. He waits 90 seconds; ignoring him counts as Refuse.
- **Duration:** 90s decision window; 12s of resolution animation.
- **Aftermath (permanent, irreversible, written and force-saved immediately):** *Jar* -> he takes the jar in both paws, eats it, huffs a cloud of steam, lumbers into the meadow and lies down at (0,0,−150) where he stays for every future session. A rare patch (`richness 1.0`, `nectarMult 3.0`) blooms beside him. Wasp raids within 200 studs of your plot are auto-killed. Bee skin **Molasses Fur** unlocked. Plot sign reads *"Neighbour of Old Molasses."* -- *Refuse* -> he stands, roars, breaks the fence gap, and leaves. From then on: raids every 6 min at patience 400, theft 45%, **+3 Royal Jelly per repel**. Bee skin **Furious** unlocked. Plot sign reads *"Hunted by Old Molasses."*
- **Which agents:** scripter (ThreatService stage machine, the two-button UI flow, permanent state write); enemy-designer (the sit pose, the front-lane walk, the two resolution animations); sound-designer (the duck to silence -- the most important audio cue in the game, plus the huff and the roar); lighting-director (cell lights hold gold, do *not* go red -- he is not attacking, and the absence of red is what makes this moment land); vfx-designer (steam huff, dust on sitting).

### 2. The First Waggle
- **Trigger:** a player's first successful `SubmitDance` (`stats.dancesPerfect + dancesTotal == 1`).
- **What happens:** the dancing bee runs a visible figure-8 on the Dance Floor cell. On grading, a golden `Beam` **draws itself** from the Landing Board out across the meadow to the patch over 1.4s with an easing trail, and the patch's flower heads turn to face the hive. Three foragers launch in sequence off the board and follow the line. Camera pulls back 20 studs for 3s.
- **Duration:** 5s.
- **Aftermath:** the route line stays permanently visible (dimmer). The player now understands the entire foraging system without a word of tutorial.
- **Which agents:** scripter (DanceService grading + Beam rig + camera nudge); vfx-designer (beam trail, launch puff, figure-8 dust); sound-designer (the waggle buzz rising in pitch, then a bright chime on grade).

### 3. Capping Night
- **Trigger:** every Honey Cell on any one comb floor simultaneously at `amt == cap` and `ripeness >= 2.0` (checked in `ResourceService` on wallet change, debounced 30s so it can't spam).
- **What happens:** workers crawl across the comb capping cells with white wax in a wave outward from the centre, 0.12s stagger per hex ring. Cell lights tween to `#FFFFF0` at `Brightness 2.4` in the same wave. The hive hum rises a perfect fifth. The whole floor glows white-gold for 8 seconds -- **visible from every plot and from the hub.** A server-wide `Notify`: *"[Name]'s comb is fully capped."*
- **Duration:** wave 2.5s + 8s hold + 2s settle.
- **Aftermath:** harvesting a fully capped floor pays a **×1.15 Capping Bonus** and grants the *Capping Night* achievement on first occurrence. The bonus means this is a state players deliberately chase, which means the public flex happens on purpose.
- **Which agents:** scripter (detection, wave sequencer, bonus); lighting-director (the wave tween); vfx-designer (wax cap sheen, white shimmer); sound-designer (the rising chord); world-builder (cap geometry on the cell templates).

### 4. The Queen Walks
- **Trigger:** continuous from spawn; escalates at each queen tier upgrade.
- **What happens:** the Queen physically crosses the comb between Brood Cells on a CFrame path. Cells flash amber for 0.6s as she passes. At Q4 two attendant bees orbit her. At Q5 she carries a sun halo and the comb **ripples gold** in a 2-cell radius behind her.
- **Duration:** forever.
- **Aftermath:** she is the only persistent character on your plot. Players name her in chat. At a tier upgrade, `Moment{id="QueenGrowth"}` plays: she pauses, the comb dims for 0.5s, she grows over 1.2s with a gold burst, and the comb re-lights brighter.
- **Which agents:** scripter (QueenService walk + tier swap); enemy-designer or world-builder (five Queen models, 6 parts each); vfx-designer (the ripple, the growth burst); lighting-director (her attached light per tier).

### 5. The Swarm (prestige)
- **Trigger:** `RequestSwarm` validated.
- **What happens:** every bee on the plot pours out of the comb and forms a spiralling column around the Queen above the Swarm Perch over 4s. The column tightens, lifts, and flies out over the treeline until it vanishes at the skybox. **Then 3 full seconds of complete silence and an empty grey comb.** Then one capped Royal Cell on the rim cracks, and the new Daughter Queen climbs out. The plot sign updates to the new lineage name.
- **Duration:** 13s, uninterruptible, camera on rails.
- **Aftermath:** comb reset, Royal Jelly banked, generation + 1, new species unlocked. Those three seconds of silence are the entire emotional payload of the prestige system -- without them it is a reset button.
- **Which agents:** scripter (SwarmService + camera rails + forced save); vfx-designer (spiral column, the crack, the emergence); sound-designer (swelling swarm roar -> hard cut to silence -> a single small chirp); lighting-director (all cell lights die, then one royal cell light blooms).

### 6. Moonflower Bloom
- **Trigger:** `TimeService` hour crosses 20:00.
- **What happens:** the far-meadow moonflowers unfurl with a soft blue pulse over 3s, four cold lights fade up, `ColorCorrection` shifts cool, and any bee whose owner has the Pale Night skin visibly changes. Server-wide `Notify`: *"The moonflowers are open."*
- **Duration:** 3s transition; the window lasts 9 in-game hours (~4.5 real minutes).
- **Aftermath:** night becomes the highest-value foraging window, so every player re-dances at 20:00 -- a synchronized, voluntary activity spike every 12 minutes with no daily-login gimmick attached.
- **Which agents:** scripter (TimeService broadcast, species gating); lighting-director (cool shift + moonflower lights); vfx-designer (unfurl, blue motes); world-builder (moonflower closed/open states).

### 7. Rain Shelter -> Bloom Rush
- **Trigger:** weather state `Rain`, then `BloomRush`.
- **What happens:** first raindrops, then **every bee on the map turns and streams home in six converging golden lines** -- six plots' worth of traffic collapsing inward at once, the most beautiful 6 seconds in the game and completely free because the bees already exist. Landing Boards brighten. 60 seconds of quiet where players build and talk. Then the rain stops, a rainbow arcs over the meadow, every patch refills, and all six swarms pour out simultaneously.
- **Duration:** 6s converge + 60s lull + 4s burst.
- **Aftermath:** richness restored +50%, nectar ×1.35 for 90s.
- **Which agents:** scripter (TimeService weather + SwarmVisualController return-home routing); vfx-designer (rain, rainbow, the burst); sound-designer (rain on wax, the hum going quiet, then the surge); lighting-director (the dim and the recovery).

---

## Environmental Events

**Ambient (periodic -- the world exists without the player):**
| Event | What | Frequency | Where | Built by |
|---|---|---|---|---|
| Cell breathing | honey cell lights pulse, phase-offset per cell | 4s cycle | every filled cell | lighting-director + scripter |
| Bee traffic | continuous stream in/out of Landing Board at the true income rate | continuous | all plots | scripter (SwarmVisualController) |
| Kiln steam | steam puff + hiss | 6s | Propolis Kiln | vfx + sound |
| Wax creak | comb settling sound | 12–20s | comb decks | sound-designer |
| Grass sway | tufts sway on offset sine | 3s cycle | meadow | vfx-designer |
| Resin drip | amber drip + wet tick | 5–9s per node | treeline | vfx + sound |
| Distant lawnmower | the human world continuing | ~90s | global, quiet | sound-designer |
| Thimble bell sway | faint chime | ~25s | hub | sound-designer |
| Bear rumble | low distant growl once `bear.stage ≥ 1` | 40–70s | treeline direction | sound-designer |
| Flower open/close | heads open/close on their bloom window | on hour change | all patches | scripter + world-builder |
| Pollen drift | motes across meadow and hub light shafts | continuous | meadow, hub | vfx-designer |

**Triggered (player proximity or action):**
| Event | Trigger | Effect | Cooldown |
|---|---|---|---|
| Cell dip | step on a comb cell | dips 0.15 studs, springs back | 0.5s per cell |
| Cell warm | within 8 studs of a filled honey cell | light +25% for 1.5s | 2s |
| Bud bloom | approach an affordable Bud Button | bud opens with a pop + glow | on affordability change |
| Grass part | walk into a grass tuft | tuft parts, pollen puff | 1s per tuft |
| Patch tilt | step onto an unmarked blooming patch | heads tilt toward you, MARK prompt | one-time per patch |
| Guard turn | approach a Guard Perch | guards turn to face you | 3s |
| Gateway light | step on a hub teleport pad | pad lights, signpost swings | 2s |
| Build Mode lift | open Build Mode | all dim plates rise 0.4 studs, valid=green / blocked=red | — |
| Needle shower | walk under a pine canopy | needles fall | 4s |
| Treeline shudder | 45s before a raid | pines at the target's end shake, birds scatter | per raid |

**Scripted sequences:** the seven Signature Moments above, plus each bear raid's arrival choreography (different per stage), the wasp scout circle, and the Floor 2 / Floor 3 unlock reveals (wax ramp unrolling upward over 3s while the new lattice's dim plates fade in above).

**Event density:** 11 ambient + 10 triggered + 7 scripted across 5 zones. The player encounters something reactive roughly every **8 seconds** on their own comb and every **12 seconds** in the meadow.

---

## Technical Decisions

**Place settings (must be changed from the current template):** `Players.MaxPlayers = 60 -> 6`. `Players.RespawnTime = 3`. `Workspace.StreamingEnabled = true` with `StreamingTargetRadius = 512` (the map is 900 studs wide at bee scale; streaming is what keeps mobile alive). Delete the template `Baseplate` part -- the meadow slab replaces it. `Workspace.FallenPartsDestroyHeight = -50`.

**Physics:** everything `Anchored = true` except bees, wasps, Molasses and the Cub. Nectar motes are client-only and CFrame-driven (never physics). No unanchored parts exist on the server except the four Actor types.

**Collision groups:**
- `Default` -- players, terrain, comb
- `Props` -- all decorative parts: `CanCollide = false`, non-collidable with everything. Grass tufts, flower heads, wax drips. A player must be able to walk *through* the meadow, not be trapped by it.
- `Actors` -- bees/wasps: collide with nothing (not each other, not players, not geometry)
- `Bears` -- collide with Default only; do not collide with `Props` or `Actors`
- `CellContent` -- honey blobs, larvae: `CanCollide = false` so the player can stand on a cell without fighting its contents

**Camera:** default third-person for traversal. `BuildController` switches to a fixed top-down orthographic-feeling view (45 studs above the active comb floor, 80° pitch) in Build Mode -- mandatory, because a hex grid is unreadable and untappable from third-person on a phone. `MomentController` takes the camera on rails for Signature Moments 2, 4 and 5 only, with a skip on any input.

**Character:** standard R15 avatar plus a `BeeWings` accessory Model welded to the torso (2 parts) and body colours set from the equipped skin. The player is a bee, but built from a standard avatar so it works with every Roblox body type and costs 2 parts.

**Input mapping:**
| Action | Keyboard | Mobile |
|---|---|---|
| Interact (Mark / Harvest / Smoke / Offer) | `E` | large contextual button, bottom-centre, 0.11 screen height |
| Build Mode | `B` | BUILD button, bottom-right |
| Place cell | click | tap the hex |
| Dance tap 1 / tap 2 | `Space` | the same full-width tap zone both times -- **one target, two taps, no aiming** |
| Hive panel (castes/queen/perks/swarm) | `H` | HIVE button |
| Shop | `P` | SHOP button |
| Swat wasp | click the wasp | tap the wasp (40-stud hit radius, generous on purpose) |

**Multiplayer:** shared world, six individual plots, no PvP. Cooperative smoking is the only cross-player interaction with mechanical weight, and it is strictly positive-sum -- you cannot grief another plot, only help it. Patch depletion is the only competitive pressure, and it is soft (richness regrows).

**Performance -- the bee-rendering contract (the single biggest risk in this design):**
- The server **never** moves a bee. It owns counts and rates only.
- `SwarmVisualController` keeps one pooled array of **110 Bee Models (2 parts each = 220 client parts)** and drives them all from the single `ClientMain` Heartbeat loop along precomputed quadratic-bezier paths.
- LOD: own plot up to 60 rendered; each neighbour plot within 250 studs up to 12; beyond 250 studs, 0. Hard global cap 110.
- `lowDetail` setting halves every cap and disables nectar motes.
- Nectar motes: pooled 60, client-only, CFrame-driven.
- Route lines are `Beam` objects on `Attachment`s -- **zero BaseParts** for up to 60 route lines across the server.

---

## Build Order

1. **`Config` + `GameEnums` + `HexGrid` + `Formulas`** -- every number and the hex math first. Nothing else can be built correctly before these exist; every downstream agent reads them.
2. **Meadow slab + Apiary Yard + Petal Path + base lighting + delete Baseplate** -- *maximum visual impact per minute.* Within one step the bee-scale hook is visible: giant grass, a giant watering can, warm light. Anyone watching immediately understands the game's identity.
3. **Plot 1 deck + fence bay + 19 dim cell plates + Landing Board + ramp + Plot Sign** -- one complete plot to validate the hex lattice against the `HexGrid` module before replicating it six times.
4. **Plots 2–6** (pure translation of Plot 1 by the X offsets -- no new geometry decisions).
5. **`DataService` + `PlotService`** -- a player can join, be assigned a plot, spawn on it, and have their profile persist. The game is now technically real.
6. **`Templates/`** -- all cell, content and structure models in `ReplicatedStorage`, built once and cloned forever. Cheap to build, and it unblocks everything.
7. **`CombService` + `StructureService` + Bud Buttons + `BuildController` + `BuildGui`** -- the player can build a cell. **First playable.**
8. **`PatchService` + flower patches in the meadow + `DanceService` + `DanceGui`** -- the player can find, mark and dance a patch. -> **Signature Moment 2 (The First Waggle).**
9. **`ForagingService` + `ResourceService` + `PopulationService`** -- honey actually flows. The three-bottleneck math is live.
10. **`HudController` + `MainGui`** -- the three bars, the wallet, the contextual button. The game is now *understandable*.
11. **`SwarmVisualController` + `RouteVisualController`** -- the bees appear. This is when A Bee's World stops being a spreadsheet and starts being the thing in the pitch.
12. **`QueenService` + Queen models** -- -> Signature Moment 4.
13. **`TimeService` + weather + day/night lighting** -- -> Signature Moments 6 and 7.
14. **Treeline + resin nodes + `Propolis Kiln`** -- the third resource chain.
15. **`ThreatService` + wasps** -- the small, frequent threat first, to prove the defence loop before the bear depends on it.
16. **`EnemyAI`: Old Molasses + Cub + the six-stage arc** -- -> **Signature Moment 1.**
17. **`SwarmService` + Swarm Perch** -- -> Signature Moment 5.
18. **`PerkService` + `CosmeticService` + `AchievementService` + `LeaderboardService`** -- the long tail.
19. **Capping Night detection** -- -> Signature Moment 3.
20. **Set-dressing, audio, VFX, cinematic lighting, composition review** -- the full visual pipeline over the finished, functioning world.

---

## Part Budget

**Target max: 4,200 server BaseParts. Hard ceiling: 5,000.**

| Region | Parts | Notes |
|---|---|---|
| Plot × 6 (max-tier) | 2,040 | 340 each -- see breakdown below |
| Wild Meadow | 520 | 18 patches (~22 each), 120 grass tufts, log, puddle, path |
| Pine Treeline | 150 | 18 pines, 4 resin nodes |
| Giant garden fence run | 60 | boards + posts between and beyond bays |
| Apiary Yard (hub) | 500 | 4 zones: Gateway Row, Social Garden, Flowerpot Den, Shed Wall — 6 gateways, bell, birdbath, garden table, giant pot, shed wall, props |
| Petal Path | 24 | stepping stones |
| Perimeter skirt / barriers | 40 | invisible walls + treeline ring |
| Actors (Molasses 16, Cub 11, wasp pool 8 × 4) | 59 | runtime-spawned |
| **Total, worst case (6 players all maxed)** | **3,393** | **1,607 headroom** |
| **Server at launch (6 empty plots)** | **1,899** | 91 per empty plot |

**Per-plot breakdown (max tier = 340):**

| Element | Parts |
|---|---|
| Deck slab, rim, ramp | 8 |
| Fence bay backdrop (7 boards, 2 posts, rail) | 10 |
| Comb Floor 1 -- 19 cells (plate 1 + ~2.2 shared walls) + content | 88 |
| Comb Floor 2 -- 12 cells + content + columns + spiral ramp | 70 |
| Comb Floor 3 -- 7 cells + content + columns + spiral ramp | 46 |
| Landing Board + bee entrance + Smoker | 12 |
| Guard Perches × 2 | 8 |
| Apiary Shed | 16 |
| Propolis Kiln | 14 |
| Swarm Perch | 7 |
| Plot Sign | 3 |
| Bud Buttons × 8 | 24 |
| Wardrobe Pedestal | 3 |
| Paw prints (max 5) | 5 |
| Wax drips / seam dressing | 26 |

**Per-agent allocation:**

| Agent | Budget | % | Notes |
|---|---|---|---|
| world-builder (base geometry) | 1,850 | 58% | decks, comb lattices, fence, ramps, hub structure, treeline, path |
| detail-architect (architectural trim) | 330 | 10% | wax drips, seam detail, deck rims, cell wall variation, fence wear |
| set-dresser (props) | 520 | 16% | grass tufts, hub junk, meadow dressing, plot perimeter props |
| flora (patches / resin -- world-builder) | 420 | 13% | 18 patches + 4 resin nodes, built as templates |
| lighting fixtures | 0 | 0% | all lights are `PointLight`/`SpotLight` objects inside existing parts -- **zero part cost** |
| VFX anchors | 14 | <1% | invisible emitter anchors (kiln, rainbow, swarm column) |
| Actors (enemy-designer) | 59 | 2% | Molasses, Cub, wasp pool |
| reserve | ~1,800 | — | iteration buffer; do not consume without a Game Master check |

**Client-only, outside the server budget:** 110 Bee Models × 2 parts = 220, nectar mote pool = 60, route `Beam`s = 0 parts. Total client overhead ≈ 280 parts, LOD-culled and halved by `lowDetail`.

---

## Risk Areas

| Risk | Severity | Mitigation |
|---|---|---|
| **Bee rendering melts mobile** | Critical | Server never moves a bee. Pooled 110 client models, one Heartbeat loop, distance LOD (own plot 60 / neighbours 12 each / 0 beyond 250 studs), `lowDetail` halves everything. Verify FPS with 6 maxed plots before shipping any content past Build Order step 11. |
| **Hex math diverges between client preview and server** | Critical | One shared `HexGrid` module in `ReplicatedStorage`. Neither side ever computes a cell position independently. Any hex math written outside `HexGrid` is a review failure. |
| **Dance minigame exploitable** | High | Client sends only two normalized `0..1` stop values. The server holds the true bearing/distance and the dial seeds and grades it alone. Server rejects submissions outside `[1.2s, 12s]` or >14 studs from the Dance Floor. |
| **Part count blows past 5,000** | High | 1,807-part headroom at worst case. `PlotService.ReleasePlot` strips a departing player's plot back to 91 parts. `BuildingService` logs a warning above 4,200 total. |
| **DataStore loss / duplicate-hive exploit** | High | Session locking via `UpdateAsync` with a 300s steal window. All calls `pcall` + 3 retries. On total load failure, saving is disabled for the session rather than overwriting good data. Force-save on Swarm and on the Molasses fork. |
| **Molasses pathfinding fails at bee scale** | Medium | 16-stud lane, 12-stud fence gaps, `AgentRadius 6`, `AgentHeight 26`, `AgentCanJump false`, `WaypointSpacing 8`. `ComputeAsync` wrapped in `pcall` with a fallback straight-line walk to the target plot's Landing Board. He can never use the 9-stud wax spirals -- Floors 2 and 3 are intentionally bear-proof. |
| **Player can't find the meadow / doesn't know to dance** | Medium | Spawn is teleported to their own plot ramp with a single glowing clover patch 45 studs out and one arrow. No text. First Waggle is designed to land inside 90 seconds. |
| **Hex build grid unusable on a phone** | Medium | Build Mode is a mandatory top-down camera with 15-stud cells; at that camera distance each cell is a ~70 px tap target on a 6-inch screen. Never require hex placement from third-person. |
| **Too many systems for a 9-year-old** | Medium | Strict unlock ladder: routes (0:45) -> cells (1:30) -> castes (4:00, gated behind Queen Q3 for nurses) -> propolis (6:00) -> wasps (8:00) -> bear (18:00) -> swarming (45:00). Nothing is visible in the UI before it is unlocked. |
| **Ripeness gamble is invisible / players never engage** | Medium | Ripeness is a light level on a physical object, publicly visible from every plot, plus a "RIPE ×2.2" tag over the comb. The bear's 45-second public warning names the target, which teaches the risk once and permanently. |
| **Day/night lighting tweens cost frames** | Low | `ClockTime` and post-processing tweened once per state change over 3–6s, never per-frame. Cell lights tween on wallet change only. Max 24 shadow-casting lights per plot. |
| **Atmosphere makes the meadow unreadable** | Low | `Density` capped at 0.28 in Config with a comment; grass tufts are the intended sight-line blocker, not fog. |

---

## Mobile Checklist

- [ ] All UI sized in `Scale` (`UDim2.new(sx, 0, sy, 0)`); zero `Offset` on any container or button
- [ ] Contextual action button ≥ 0.11 screen height (≈ 80 px on a 6-inch phone), bottom-centre, thumb-reachable
- [ ] BUILD / HIVE / SHOP buttons ≥ 0.08 screen height, bottom-right cluster, ≥ 12 px apart
- [ ] Dance minigame is **one tap zone, two taps** -- no dragging, no aiming, no precision gesture
- [ ] Hex cells ≥ 60 px tap targets in Build Mode's top-down camera
- [ ] Wasp swat hit radius 40 studs (screen-space forgiving)
- [ ] All text ≥ 16pt, `TextScaled = true` with `UITextSizeConstraint` min 14
- [ ] Three-bars panel readable at a glance with a one-word bottleneck hint -- never requires reading a number
- [ ] Server part count ≤ 4,200; client bee parts ≤ 220 with LOD
- [ ] `lowDetail` setting: halves bee/mote caps, caps lit cells at 8, disables DepthOfField
- [ ] `StreamingEnabled = true`, `StreamingTargetRadius = 512`
- [ ] No sound above `Volume 0.7`; total `Sound` objects < 25
- [ ] Total `ParticleEmitter`s < 20; combined rate < 80 p/s
- [ ] Tested at 6 players, all plots max-tier, during a bear raid in the rain (the worst frame in the game)

---

## Emotional Arc Summary

**Minute 1:** *"I'm a bee and the grass is taller than me."*
**Minute 5:** *"I told my sisters where the flowers are and they went."*
**Minute 15:** *"My hive is glowing and I'm not cashing out yet."*
**Minute 25:** *"A bear came and my neighbours ran over to help me."*
**Minute 50:** *"My queen just left with everyone I had."*
**Generation 3:** *"I built high enough to see the whole garden -- and the bear sleeping in it is mine."*

The arc is **scale -> agency -> greed -> community -> loss -> perspective.** Every mechanic exists to serve one of those six beats, and anything that serves none of them does not belong in this game.
