# A BEE'S WORLD — Epic Roadmap

> Goal: "Epic and very engaging." This document is the full prioritized build plan from current state to a game that players tell friends about.

Last updated: Cycle 3

---

## CURRENT STATE (end of cycle 3 dispatch)

**LIVE and verified:**
- Full economy (honey/pollen/propolis flow, waggle dance, day/night)
- Hex comb building across 6 plots (Floor 1 with real geometry)
- Wild Meadow (18 patches), Petal Path, Apiary Yard hub (cramped v1)
- DataService + PlotService + CombService + ForagingService + ResourceService + PopulationService + DanceService + StructureService
- All GUI systems (MainHud, BuildGui, DanceGui, HelpGui, NotifyGui)
- Full VFX and SFX pass on all player actions
- Real AI-generated meshes for all flora and most structures

**DISPATCHED this cycle (not yet live — needs Studio):**
- Hub v2 rebuild (400×280, 4 zones, cycle3_hub_dispatch.md)
- Molasses + Wasp threat system (ThreatService + EnemyAI + world zones, cycle3_molasses_dispatch.md)

**CRITICAL fixes needed first:**
- Bug #9: Run fix_bug9_duplicate_dataservice.lua in Studio Command Bar

---

## PRIORITY ORDER (what makes the game epic)

### PHASE 1 — The Three Missing Pillars (cycles 3–5)
*The architecture calls these out by name as "what makes this not a reskinned tycoon." None exist yet.*

#### 1A. Old Molasses + Wasp Threat System ← DISPATCHED (cycle 3)
**Why first:** This is the central tension of the entire game. Without it the game is a peaceful tycoon with no stakes. Molasses is not just a boss fight — he is a 6-stage character arc that gives the game a narrative backbone and two permanent endings. The wasp system teaches players that guards matter. Together they transform "build a hive" into "defend your hive."

Build order: world-builder (Pine Treeline + Bear Lane + Den + SmokerActivate triggers) → luau-scripter (ThreatService + ThreatController) → enemy-designer (OldMolasses + Cub + WaspDrone rigs)

**Signature moments unlocked:**
- "Molasses stage 1" (20-minute mark per emotional journey)
- Wasp swatting, smoker use, guard bees dying to protect you
- Paw print trophies on your deck (one per Molasses repel)
- The permanent fork ending (feed/refuse) after stage 6

---

#### 1B. QueenService + Queen Model ← ARCHITECTURE ADDENDUM READY
**Why second:** The architecture calls the Queen "Signature Moment 4." Without her, the caste system is half-alive: you can change forager/guard/nurse ratios but the Queen that makes it matter doesn't exist. Royal Jelly production, egg-laying cycles, queen tier unlocks (outputMult, layInterval), and the eventual Swarm all depend on this.

Architecture addendum: `architecture_queen_addendum.md`

Build order: luau-scripter (QueenService — server module, Royal Jelly production 0.004/s per adjacent Brood cell) → world-builder (Queen models for each tier, client-rendered) → ui-designer (HiveGui QUEEN tab — currently honest "Coming Soon" placeholder)

**Signature moments unlocked:**
- First Queen tier milestone
- "My Queen laid eggs" — watching caste allocation actually matter
- Royal Jelly resource loop (new strategic trade-off)

---

#### 1C. Hub v2 Rebuild ← DISPATCHED (cycle 3)
**Why third:** The current hub is 140×140 and feels like an afterthought. The hub is the first thing every player sees. It establishes scale, tone, and the game's emotional register. Hub v2 is 6× larger with 4 distinct zones, a social landmark (the Flowerpot Den), and the leaderboard. It makes the game feel like a world, not a lobby.

---

### PHASE 2 — Physical Systems (cycles 5–8)

#### 2A. BudButton Full Coverage + ShopGui
**Current state:** StructureService's own header comment confirms it only wires ApiaryShed/PropolisKiln tier purchases. Dance Floor tier, Comb Floor unlocks, Wardrobe, and SwarmPerch are deferred. 8 BudButton meshes exist (model template ready) but most are not wired.

**Build:** luau-scripter to extend StructureService for the remaining purchase types + ShopGui client caller for RequestPurchase (already server-tested).

---

#### 2B. Smoker Interactive Prop + GuardPerch Visual
**Current state:** SmokerActivate invisible trigger parts specified in cycle3 dispatch. The visible Smoker mesh already exists as a template. GuardPerch mesh template exists. Neither is tagged or functional in the world yet.

**Build:** world-builder places physical Smoker mesh parts (one per plot, at plotX, 3, 30), tags them "Smoker" with ProximityPrompt. GuardPerch mesh parts placed at each plot's two designated perch positions, tagged "GuardPerch" with PlotIndex attribute. Guards then have a visual home.

---

#### 2C. Floor 2 + Floor 3 Comb (per-plot vertical expansion)
**Current state:** Architecture fully specifies Floor 2 (12 cells, +20Y) and Floor 3 (7 cells Crown Comb, +40Y). Templates exist (Comb Floor 2/3 template parts). StructureService has unlock flags. Nothing is built.

**Why this matters for "epic":** Floor 3 is the prestige payoff — elevated above the fence line, you can see the entire server for the first time. It is the visual reward for long-term play. Without it there is no vertical progression.

**Build:** world-builder builds Floor 2 + Floor 3 lattice geometry per-plot (same hex math as Floor 1, offset Y). StructureService floor-unlock logic wired to BudButton Floor Unlock buttons.

---

### PHASE 3 — Weather and Living World (cycles 8–11)

#### 3A. Weather System (Clear/Breezy/Overcast/Rain/Bloom Rush)
**Architecture spec:** 5-state cycle driving visual changes (Atmosphere Density, wind particle rate, Lighting Ambient), gameplay effects (forager speed in Breezy, bee withdrawal in Rain, 30% yield boost in Bloom Rush), and faction reactions (bees shelter in Rain, Molasses preferentially raids in Rain at stage 3+, wasp scouts avoid wind).

**Why epic:** The weather makes the game's 12-minute day feel alive. Bloom Rush is a shared-server event ("IS THAT BLOOM RUSH?") that creates spontaneous social moments. Rain forcing bees home is the most interesting resource management moment in the mid-game.

**Build:** luau-scripter (WeatherService server module, 5-state machine, RemoteEvent WeatherChange) + world-builder (Atmosphere property changes per state, wind particle emitter on central hub) + luau-scripter (Weather hooks into ForagingService speed modifiers, ThreatService raid preference modifier).

---

#### 3B. SwarmService + SwarmPerch
**Architecture spec:** The Swarm is "Signature Moment 5" (the 45–60 minute mark). Every bee leaves with the queen. Silence. A Royal Cell cracks open. New queen, new generation, generation counter increments, plot resets with 20% honey bonus carry-over.

**Why epic:** This is the prestige mechanic but it's *narrative*. It doesn't feel like "reset for a multiplier" — it feels like your hive is alive and went somewhere.

**SwarmPerch mesh template exists. SwarmService does not.**

**Build:** luau-scripter (SwarmService — trigger conditions, bee mass migration VFX sequence, generation tracking, carry-over math) + world-builder (SwarmPerch deployment on each plot, tagged "SwarmPerch") + VFX pass (the departure beam — the bees form a column and rise through the treeline).

---

### PHASE 4 — Social and Long-Term (cycles 11–16)

#### 4A. CosmeticService + WardrobePad + Cosmetics Catalog
**Architecture spec:** Wardrobe Pedestal exists as a mesh template. CosmeticService does not exist. WardrobePad is not tagged. The 6 bee body cosmetics (Golden Bee, Night Bee, Crystal Bee, Autumn Bee, Moon Bee, Arctic Bee) are specified with exact unlock conditions.

**Why this matters:** Cosmetics are the monetization bridge and the status signal. At bee scale, other players' bees are visible in the shared meadow. A golden bee flying your route is social.

**Build:** luau-scripter (CosmeticService — catalog, purchase gateway, equip/unequip, Gamepass validation) + world-builder (WardrobePad tagged parts on each plot) + ui-designer (Wardrobe GUI within HiveGui COSMETICS tab).

---

#### 4B. Leaderboard Full Implementation
**Current state:** Cork board in hub has a SurfaceGui stub. No data pipeline.

**Build:** luau-scripter (LeaderboardService — OrderedDataStore top-10 lifetime honey, update on session end) + server-side update to the SurfaceGui on the cork board.

---

#### 4C. Daily Quests + Retention Widget
**Current state:** DailyRewardService exists server-side (verified). Reuses Notify toast remote. No dedicated GUI widget.

**Build:** ui-designer (corner quest widget — 3 daily objectives, progress bars, claim button) + luau-scripter (QuestController LocalScript driving the widget from QuestUpdate RemoteEvent).

---

#### 4D. Gamepass Wiring
**User action required first:** Create 4 Gamepasses + 2 Developer Products in Creator Dashboard and paste real IDs into Config.MONETIZATION.

Once IDs exist: luau-scripter wires all 6 MONETIZATION entries to their actual effects (VIP 2× honey, DoubleHoney passive, AutoHarvest proximity, ExtraRouteSlot +1 route, HoneyPackSmall/RoyalJellyPackSmall instant grants).

---

### PHASE 5 — Polish and Depth (cycles 16+)

#### 5A. Narrative Overlay (story-teller agent)
Environmental text fragments at zone entrances — who was the beekeeper, why did they leave, what does Old Molasses want. The hub especially should have fragments: a label on the newspaper, something written on the seed packets, a note in the shed window that you can only read from Floor 3. Typewriter reveal, magnitude proximity detection, entirely client-side.

#### 5B. Sound and VFX Deepening
- Old Molasses audio: heavy breathing at a distance (stage 1+), sniffing (30s before raid), satisfied grunt on theft, defeated whimper on repel
- Weather audio: rain on comb cells, wind through the treeline, thunder at stage 3+ raids
- Swarm departure: the specific sound of every bee leaving at once (starts as a hum, crescendos to a roar, then silence)
- Floor 3 reveal: the first time a player reaches Floor 3, a brief ambient shift (the world opens up, a chord resolves)

#### 5C. Tutorial Layer
New players don't know about waggle dance, comb adjacency, or guard mechanics. A first-session tutorial that teaches through prompts rather than blocking text: the first patch glows and pulses until you mark it; the first wasp scout is announced with extra UI context; the first time honey ripens, a tooltip appears near the glowing cell.

#### 5D. Achievement System
20 achievements covering the emotional journey milestones: first dance, first guard death, first Molasses encounter, first Molasses repel, first 100 honey banked, first Floor 2 unlock, first Swarm, Furious Molasses ending, Feed Molasses ending, full Floor 3 build. Each has a corresponding cosmetic badge displayed on the Plot Sign.

#### 5E. Secret Room / Easter Eggs
- The boot in the hub: right-clicking it triggers a faint sound (a bee buzzing inside) and a tiny door opens in the heel — a 3-stud wide passage leading to a tiny secret room with a disproportionately good linden route already dancing
- The newspaper: readable from the table surface if you get close — headlines that obliquely reference the world's lore (Bear Spotted Near Apiary District, Unusual Honey Prices This Season)
- Aurora Bloom patch (Z −341): standing on it at night in Bloom Rush plays a unique chime and briefly turns every player's comb frost-blue

---

## EPIC CHECKLIST — Does this game feel epic?

A game earns "epic" when players experience at least three of these in a session:

- [ ] **Scale moment** — spawn and realize you are tiny. Blade of grass = 18 studs. ✅ LIVE
- [ ] **First dance** — golden route draws itself, bees launch off your board. ✅ LIVE
- [ ] **Greed moment** — honey glows brighter, other players notice, you choose to let it ripen. ✅ LIVE
- [ ] **Fear moment** — Old Molasses announced. 45 seconds. What do you do? ← DISPATCHED
- [ ] **Social moment** — neighbours run over to help you smoke Molasses. ← NEEDS MOLASSES
- [ ] **Pride moment** — you repel Molasses. Paw print trophy on your deck. ← NEEDS MOLASSES
- [ ] **The Question** — standing in the hub, looking at the kitchen light on in the shed: what happened here? ← DISPATCHED (hub v2)
- [ ] **Vertical reveal** — reaching Floor 3 and seeing the whole server for the first time. ← NEEDS FLOOR 2/3
- [ ] **The Swarm** — your bees leave. Silence. Then a royal cell cracks open. ← NEEDS SWARMSERVICE
- [ ] **The Fork** — stage 6 Molasses sits down. You have a choice. Nothing prepares you for it. ← NEEDS MOLASSES + QA

Currently live: 3 of 10. After Phase 1 completes: 7 of 10. Full epic: all 10.

---

## BUILD ORDER (what to dispatch next, right now)

1. **[IMMEDIATE]** User runs `fix_bug9_duplicate_dataservice.lua` in Studio Command Bar — CRITICAL before any DataService work
2. **[CYCLE 3, NOW]** world-builder: Hub v2 rebuild per `cycle3_hub_dispatch.md`
3. **[CYCLE 3, NOW]** world-builder: Pine Treeline + Bear Lane + Molasses Den + SmokerActivate triggers per `cycle3_molasses_dispatch.md`
4. **[CYCLE 3, NOW]** luau-scripter: ThreatService + ThreatController per `cycle3_molasses_dispatch.md`
5. **[CYCLE 3, NOW]** enemy-designer: OldMolasses + Cub + WaspDrone rigs per `cycle3_molasses_dispatch.md`
6. **[CYCLE 4]** luau-scripter: QueenService per `architecture_queen_addendum.md`
7. **[CYCLE 4]** world-builder + ui-designer: Queen models + HiveGui QUEEN tab
8. **[CYCLE 5]** luau-scripter + world-builder: BudButton full coverage + ShopGui
9. **[CYCLE 5]** world-builder: Floor 2 + Floor 3 geometry per-plot
10. **[CYCLE 6]** luau-scripter: WeatherService (5-state cycle)
11. **[CYCLE 7]** luau-scripter + world-builder: SwarmService + SwarmPerch
12. **[CYCLE 8+]** CosmeticService, Leaderboard, Daily Quests, Gamepass wiring, Narrative, Sound deepening, Tutorial, Achievements, Secrets
