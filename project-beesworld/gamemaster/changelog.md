# CHANGELOG — A Bee's World

## Cycle 1
- Project initialized. User specified concept: a bee tycoon style game, titled "A Bee's World".
- Studio connected to a fresh Baseplate-template place (studio_id 64d62e3f-b5e1-4e1f-9d51-56b0eb1835c5).
- gamemaster tracking files initialized (state.json, buglist.md, changelog.md).
- Git branch add-beesworld-project created off main.
- Kicking off architecture design (roblox-architect).
- User pushed back mid-design: "I don't want it to be a boring regular tycoon so be creative" -- sent a follow-up amplification to the already-running architect agent (real bee biology as mechanical inspiration: waggle dances, hexagonal comb, castes, propolis, queen/swarm behavior; explicit instruction to avoid a straight dropper/conveyor/cash-register reskin).
- ARCHITECTURE COMPLETE: "A Bee's World" -- a bee-scale tycoon whose three load-bearing mechanics are genuinely non-generic: (1) foraging is a two-tap waggle-dance minigame (bearing then distance, server-graded, never trusts the client) that draws a golden route line to a shared wild-meadow flower patch, not a conveyor belt; (2) the build surface is a real axial hex-grid honeycomb with biologically-grounded adjacency rules (brood needs neighboring honey for warmth, pollen must touch brood, royal cells are rim-only, propolis seals the outer ring); (3) banked honey ripens in place up to 2.2x value the longer it's left uncashed, glows brighter as it ripens, and that glow is visible from every other plot in the shared server -- creating a public, visible risk/reward tension, since a 6-stage escalating bear antagonist (Old Molasses) always targets the ripest comb and is announced 45s ahead to the whole server. Molasses's arc ends in a one-time, permanent, mutually-exclusive choice (feed him a jar -> permanent passive ally + unique cosmetic; refuse -> permanent harder raids but per-repel Royal Jelly income + a different unique cosmetic) that persists across prestige resets -- the architecture explicitly calls this out as "the thing players tell their friends about." Full spec: 19 Systems modules, 27 RemoteEvents (all server-authoritative, zero client-trusted amounts), a complete DataStore schema with session-lock anti-duplication and migration chain, 5 fully-dimensioned zones (Apiary Yard hub, Petal Path, 6 Comb Deck plots, Wild Meadow with 18 flower patches across 9 species with real bloom-window scheduling, Pine Treeline for the propolis resource chain), a 5-tier building/upgrade ladder per structure type, a 5-tier Queen progression, an 8-perk permanent prestige tree, and 7 fully implementation-ready Signature Moments (First Waggle, Capping Night, the Molasses Fork, the Swarm prestige sequence, Queen growth, Moonflower Bloom, Rain-to-BloomRush). Part budget: 3,193 worst-case / 5,000 ceiling. Verified against all 6 completeness criteria before accepting.
- Starting Phase 1 (foundation): Config/GameEnums/HexGrid/Formulas shared modules, and world geometry for the Meadow/Apiary Yard/Petal Path/Plot 1, in parallel.
- SHARED MODULES BUILT and independently re-verified: Config (359 lines, every tunable number in the game -- cell costs/tiers, floor gates, dance floor/kiln/shed/queen tiers, all 9 flower species, castes, all 8 perks, swarm/threat/weather math, plot layout), GameEnums (66 lines), HexGrid (126 lines, shared client+server axial hex math), Formulas (154 lines, pure cost/output/ripeness/foraging math), Shared (96 lines, utilities). Correctly resolved an under-specified detail in the brief: Floor 2's "12 cells" requirement (vs a full radius-2 disk's 19) is met by using the radius-2 RING only (not the disk), recorded machine-readably as Config.FLOOR_LATTICE_MODE so downstream cell-placement code doesn't have to guess. Independently re-verified myself (not just trusting the report): all 5 modules require() cleanly, HexGrid.Ring(1)/Ring(2) return exactly 6/12 cells, HexDistance/ToWorld math checks out, Formulas.CellCost("Honey",4) returns exactly 7200/0 matching the architecture's worked example, CellOutputMult(4) combined with base intake yields 17.74 nectar/s matching the spec's 17.7. Most importantly, independently re-ran the DeepCopy aliasing test myself: cloned PROFILE_TEMPLATE twice, mutated one clone's nested comb/castes tables, confirmed the original template AND the second independent clone were both completely unaffected -- this is the single most important correctness property in the whole data layer (a shallow copy here would have made every new player's profile alias the same nested tables, a catastrophic multi-player data corruption bug), and it's confirmed genuinely correct.
- FIRST WORLD SLICE BUILT (Meadow, Apiary Yard, Petal Path, Plot 1) -- 809 parts total, independently re-verified: exactly 19 DimCellPlate-tagged cells forming a correct radius-2 hex lattice (histogram 1/6/12, zero gaps/duplicates, every position matching the hex math within 0.05 studs), 18 FlowerPatch models with correct PatchId/Species/Distance attributes, all other tags (PlotRoot/LandingBoard/PlotSign/TeleportPad x6/LeaderboardBoard/HubBell) present and correct, Baseplate deleted, zero SpecialMesh Pyramid/Prism, zero unanchored parts, walkability confirmed via collidable-only raycasts from hub through to Plot 1's deck.
  - The agent found and pragmatically field-fixed a genuine SPATIAL BUG in the architecture itself: plot decks are built exactly per spec (110x110 slabs spanning world Z -55..+55), but the Petal Path (Z=-30), the ramp connecting it to the deck (Z -55..-30), and the 4 White Clover patches (Z -45..-50) were ALL specified at world-Z coordinates that fall inside that same deck footprint -- confirmed by direct measurement (Plot 1's DeckSlab at (-325,6,0) size 110x1x110 physically contains Clover patch 1's built position (-300,2,-45)). The agent's field-fix (relocating just Plot 1's ramp to open ground south of the deck) makes Plot 1 itself walkable and correct, but doesn't fix the underlying spec, which would repeat the identical conflict 5 more times once Plots 2-6 are built, and leaves 4 flower patches still genuinely misplaced. Dispatched a scoped, precise architecture-correction task (not a full redesign) to recompute a consistent, non-overlapping set of Z-coordinates for the ramp/path/meadow bounds/all 18 patches/hub position, preserving every zone's own stated dimensions and the patches' near-to-far species ordering -- deliberately chose to have this done by careful, shown-work recalculation rather than hand-patching more Z-values myself, since a second arithmetic mistake here would compound instead of fix the problem.
  - Three place settings could not be set via the sandboxed MCP execute_luau this session and need a manual Studio change: `Lighting.Technology = Future` (capability-gated -- the architecture calls this mandatory, since ShadowMap/Voxel would break the "ripeness glow = bank balance" mechanic), `Workspace.StreamingTargetRadius = 512` (property not exposed to this session), `Players.MaxPlayers = 6` (read-only from this context). `RespawnTime=3`, `StreamingEnabled=true`, and `FallenPartsDestroyHeight=-50` were all applied successfully.
  - Deliberately scoped down and flagged as follow-ups, not regressions: resin nodes and the full Pine Treeline zone (belongs to a later build step per the architecture's own build order), Fireweed/Aurora Bloom flora built only as placeholder marker spheres (both are Generation-gated content, fine to flesh out later).
- ARCHITECTURE SPATIAL FIX COMPLETE and independently verified against the live document: the roblox-architect correctly determined a single uniform Z-shift could NOT fix the conflict, since the original Petal Path (Z=-30) was actually NORTH of the original meadow's near edge (Z=-10) -- an inversion that would survive any single uniform shift. Derived two mathematically-forced numbers instead: the corridor is a pinned chain (deck edge fixed at -55, +25-stud ramp, +16-stud path = -96 as the meadow's northernmost legal edge), giving the ramp a -58 shift and the meadow+hub+all 18 patches a uniform -86 shift, verified programmatically as zero pairwise overlaps across deck/ramp/path/meadow/hub. Recalculated and applied directly to architecture.md: ramp Z-range, Petal Path center, meadow near/far edges, all 18 patch positions (X unchanged, table with old/new Z for every one), hub center/span, hub spur, SpawnLocation, leaderboard, gateway signposts, shed corner, fallen log, puddle, and the Door/Connection Map -- confirmed via direct grep against the live file that the new coordinates actually landed (not just claimed). Correctly left the Pine Treeline's main +105 band untouched (confirmed genuinely unaffected, opposite side of the decks) while judgment-calling a shift to its separate southern perimeter ring (which would otherwise have run straight through the relocated deep meadow). Added a new load-bearing Grass ground slab spec (Z -96..-55) that wasn't in the original design -- without it, deleting the Baseplate plus the meadow's new, more-distant near edge would leave a physical void under every ramp foot and the entire Petal Path.
  - Flagged two real follow-ups rather than silently absorbing them: trip-time/richness balance is now tuned against distances that grew by 86 studs across the board (a balance pass, not a bug); Patch 17 (Fireweed, X=0) now sits exactly on the hub spur's centerline and the gateway signpost line simultaneously -- worth a specific look when Fireweed gets built out beyond its current placeholder-marker state.
  - Dispatched a follow-up world-builder correction pass to physically reposition everything already built in Studio (Plot 1's ramp, the Petal Path zone + new ground slab, all 18 flower patches, the meadow slab/log/puddle, and the entire Apiary Yard hub) to match the corrected coordinates -- a reposition-in-place task, not a rebuild, to preserve all existing tags/attributes/names.
- SPATIAL CORRECTION APPLIED and independently re-verified (809->810 parts, +1 for a new ground slab): all 5 zone bands now confirmed at their exact corrected Z-ranges with zero pairwise overlaps -- Deck -55..+55, Ramp -80..-55, Petal Path -96..-80, Meadow -266..-96, Hub -406..-266 -- read directly from live built geometry, not trusted from the report. One of my own verification attempts produced a false alarm worth noting: a naive Position+/-Size/2 check on the ramp (a rotated, sloped part) showed a spurious ~0.3-stud overlap into the deck; recomputing the ramp's TRUE world-space AABB from all 8 rotated corners confirmed it lands at exactly -80.000..-55.000 as claimed, with zero actual overlap -- a good reminder that a rotated Part's Size dimensions don't align with world axes. All 18 flower patches independently spot-checked at their exact new positions (patch 1 at (-300,2,-131), patch 17 at (0,2,-286), patch 18 at (0,2,-341), all matching the corrected table exactly). Walkability re-verified via a corridor sweep and flood-fill (since PathfindingService's navmesh isn't available in Edit mode) rather than the pathfinding API. New load-bearing ground slab (PathApronGround, covering the Z -96..-55 gap the meadow's shift opened up) confirmed present. One correction-of-a-correction the agent made on its own initiative and flagged clearly: 44 grass tufts forming the path's sight-blocking corridor walls got caught in the meadow's -86 sweep by mistake (they belong to the path's -58 shift instead) -- caught and fixed within the same pass.
  - Flagged, correctly NOT improvised on: patches 17 (Fireweed) and 18 (Aurora Bloom) now land inside the Apiary Yard hub's own 140x140 footprint per the corrected table (patch 17 sits exactly on the hub's TeleportPad signpost row), and patches 15/16 (Moonflower) graze the hub's north edge. Both Gen-gated species are still placeholder-only builds, so this isn't urgent, but it's a real remaining spatial question for the architect, not something a builder should guess at.
- PLOTS 2-6 BUILT as pure X-axis translations of the now-validated Plot 1, and independently re-verified: DimCellPlate count 19->114 (19x6) confirmed live, PlotRoot indices confirmed as exactly {1,2,3,4,5,6} with zero duplicates/gaps, all 5 inter-deck gaps confirmed at exactly 20.0 studs, total part count confirmed at exactly 1080 (was 810, +270 = 5x Plot 1's own 54 parts, exactly as expected for 5 new plots). The agent's own verification was unusually rigorous -- a full per-descendant integrity diff (size, full rotation matrix, material, color, transparency, anchored, collide, tags, classname, relative path) across all 66 descendants confirmed Plots 2-6 are byte-identical to Plot 1 except position, and it caught an easy-to-miss detail on its own: RampTopSpawn carries a PlotIndex attribute despite having no CollectionService tag, and needed updating on every clone just like the tagged objects. Noted for the next scripter pass: cell plates keep Plot 1's naming scheme (individual DimCellPlate_<q>_<r> names, with (0,0) specifically named DanceFloorCentrePlate) -- any lookup code must go through the DimCellPlate tag + Q/R/PlotIndex attributes, never by part name.
- DATASERVICE + PLOTSERVICE BUILT and independently re-verified: all 3 scripts (DataService, PlotService, Main bootstrap) compile clean, all 6 plots confirmed genuinely clean of test pollution after the agent's own live testing. This is the first agent this session to actually EXECUTE end-to-end scenarios rather than just reading code back -- using duck-typed fake Player tables (valid at runtime since --!strict annotations are compile-time-only), it ran a real load/save round trip against Studio's DataStore emulation (mutated honey to 4242, saved, reloaded from a fresh session, confirmed the value persisted via a raw GetAsync read, not just "no error"), and directly exercised the session-lock's two real branches: a fresh lock (<300s old) correctly refused the load and kicked the fake player without touching the DataStore record, and a stale lock (400s old) was correctly stolen. Also ran PlotService's full lifecycle live (AssignPlot -> OnCharacterAdded teleport-to-RampTopSpawn -> PushPublicStats -> ReleasePlot-back-to-unowned) and confirmed FindFirstUnownedPlotIndex correctly skips an owned plot, restoring test state cleanly afterward -- independently re-confirmed by me, zero pollution found. Honestly flagged what Edit-mode genuinely can't test: true concurrent-session lock contention (only one Luau VM exists here) and forcing a real DataStore outage to exercise the dataFailed fallback path -- both correctly reasoned through via code review rather than falsely claimed as tested.
- TEMPLATES LIBRARY BUILT (39 Models, 389 parts, entirely in ReplicatedStorage so zero cost to the Workspace part budget) and independently re-verified: Cells (9: WaxCell/ReinforcedCell/PropolisCell/GoldenCell + 5-tier DanceFloorCell), CellContent (6: HoneyBlob/BroodLarva/BroodCap/PollenMound/RoyalCell/PropolisSeam), Structures (14: 3-tier Shed/Kiln, SwarmPerch, GuardPerch, Smoker, WardrobePedestal, BudButton, CombFloorRamp, CombColumn, PawPrint), Flora (10: 8 species patches + GrassTuft + a new ResinNode) -- all confirmed present at the right paths, all genuinely Models with a real PrimaryPart set (spot-checked 4 across different subfolders). Palette discipline held: GoldenCell independently confirmed to actually use Neon material (not just claimed), and the agent's own reported Neon audit (29 total Neon parts, all thin accent lines or explicitly max-value objects, zero Neon surfaces) is a real design-discipline result worth noting given the architecture's explicit "Neon means act now, used sparingly" rule. Cell shells were built as genuinely closed hex rings sized to drop precisely onto the existing DimCellPlate geometry (same CellFloor disc size/shape/rotation), so a future scripter can SetPrimaryPartCFrame straight onto a plate for an exact swap. Correctly resolved an architecture ambiguity (DanceFloorCell is listed in both Cells and Structures) by building it once, in Cells only, with clear reasoning (it IS hex cell (0,0), sharing the cell footprint/pivot convention, not a separate structure) -- documented so a scripter looking in Structures for it knows to check Cells instead. Flora templates confirmed genuinely clean of stale per-instance attributes/tags (independently confirmed FlowerPatch tag count is still exactly 18, meaning the flora templates in ReplicatedStorage do NOT carry the tag -- if they had, CollectionService would have returned more than 18, silently corrupting any future tag-based patch lookup). Actors/ and Effects/ correctly skipped per scope (enemy-designer and VFX-pool work for later phases). Two content gaps flagged honestly rather than faked: Fireweed and Aurora Bloom don't have real built patches in the Meadow yet (only 2-part placeholder stubs from the original build), so their templates were built fresh from the architecture's documented colors rather than cloned from something real -- these still need the actual Meadow stubs replaced in a later world pass.
  - Caught and cleaned up real test debris the templates agent noticed but correctly didn't touch itself (out of its own scope): a leftover TestCharacter Model (a HumanoidRootPart-only stub) left in Workspace root by the concurrent DataService/PlotService agent's own OnCharacterAdded teleport test, which that agent's cleanup pass missed. Removed directly; total Workspace part count confirmed back to the exact expected 1080.
- FIRST PLAYABLE MILESTONE: CombService + StructureService (server) and BuildController + BuildGui (client) built together in one task specifically to guarantee the RemoteEvent contract actually connects end-to-end -- a player can now genuinely build a comb cell. Independently re-verified: all 5 touched/created scripts compile clean, all 4 RemoteEvents (RequestBuildCell, RequestPurchase, CombUpdate, Notify) confirmed to exist as real Instances in ReplicatedStorage.Remotes, and the world is genuinely clean after the agent's own live testing -- 0 CombCell tagged instances, 0 polluted plots, 0 DimCellPlates left marked Built, exactly 114 DimCellPlate cells and exactly 1080 Workspace parts, all matching the pre-test baseline exactly. The agent ran a real, non-trivial live test using the established duck-typed-fake-Player technique: built a real Honey cell on Plot 1 (confirmed exact CFrame match, correct tags/attributes, honey correctly deducted, the DimCellPlate correctly hidden), confirmed double-build correctly rejected, confirmed Royal Cell's rim-only placement rule enforced correctly (rejected off-rim, accepted on-rim), confirmed Floor 2 correctly rejected as not-yet-buildable, and ran StructureService's Apiary Shed tier purchase end to end (tier 1->2, correct cost deduction, correctly blocked once unaffordable) -- then fully cleaned up every trace of the test. Found and fixed a real bug during its own testing: FireClient calls in both new services were unguarded against a disconnect race (a player leaving between validation and the notify-back), which could have turned an already-successful mutation into a thrown server error -- wrapped in pcall. Correctly scoped: RequestPurchase has a real, tested server handler but no client caller yet (no ShopGui exists yet to fire it from -- explicitly disclosed, not hidden), and CombService.Upgrade/UnlockFloor/Harvest are left as documented TODOs since they depend on ResourceService, which doesn't exist yet.
- WAGGLE-DANCE FORAGING SYSTEM BUILT -- SIGNATURE MOMENT 2 (The First Waggle) IS NOW REAL -- and independently re-verified. Server: a new shared Validator module (RateLimit/NearPosition, finally centralizing logic two prior tasks had each built inline), PatchService (caches the 18 flower patches once at Init, handles marking with proximity+rate validation), DanceService (the actual server-authoritative grading: generates a secret true bearing/distance on RequestDanceStart, never sends it to the client, then on SubmitDance independently reconstructs what the client's dial WOULD have shown at the exact elapsed time and grades against that -- the classic "stopped clock" anti-cheat pattern applied correctly). Client: DanceGui (dial + distance bar), PatchController (ProximityPrompt marking), DanceController (patch selection menu, two-tap Space input reading the identical deterministic sweep formula the server independently computes, camera pull-back on the first successful dance). All 6 new RemoteEvents (RequestMarkPatch/PatchUpdate/RequestDanceStart/SubmitDance/DanceResult/Moment) independently confirmed as real Instances with exactly one real FireServer/FireClient and exactly one real OnServerEvent/OnClientEvent each -- 10 remotes total now exist game-wide.
  - Correctly discovered and resolved a real gap: cell (0,0) on every plot -- the architecture's "permanent centre cell" -- had never actually been built by anything, since CombService's buildable whitelist explicitly excludes DanceFloor (there's no way to purchase your own starting Dance Floor). Fixed with a one-time idempotent initializer that builds DanceFloorCell_T1 onto all 6 plots' (0,0), independently re-confirmed via DanceFloorCell tag count = exactly 6.
  - This task's live testing ran in REAL PLAY MODE (not just Edit-mode duck-typed simulation like prior tasks) -- a genuine escalation in rigor. Computed a real secret (trueBearing=217.47 degrees, trueDistance=172.61 studs) via an actual RequestDanceStart call, fed the exact true values back through SubmitDance and got quality=1.25 (Perfect) with dancesPerfect incrementing to 1, then deliberately fed wrong values and got quality=0.7 (Poor) -- proving the grading math is genuinely self-consistent, not just "didn't error." Found and fixed a real geometry bug during this test: the route Beam's start-point offset came out sideways instead of upward because the Dance Floor plate is a 90-degree-rotated cylinder and a naive local-space offset got rotated along with it -- fixed via CFrame:PointToObjectSpace, re-verified exact. Independently re-confirmed after the fact: 0 polluted plots, 0 leftover Beams, exactly the expected +12 parts (2-part DanceFloorCell_T1 x6 plots) with nothing else disturbed. (Mid-task, the user observed a transient "6/6 plots owned by MCP_TestBee7 / server full" warning in the live Studio console -- checked live at the time and confirmed it was exactly the expected edge-case test activity PlotService was designed to log, not a stuck/broken state; the world was already clean by the time it was checked, consistent with this being a snapshot of in-progress multi-player-scenario testing.)
- THE ECONOMY IS LIVE: ForagingService + ResourceService + PopulationService built and independently re-verified against the real running server (the user was actively playtesting throughout -- confirmed their real Plot 1, eXemptAttempt/UserId 2354572334, was never touched, and confirmed zero pollution left on Plots 2-6 which were used briefly for testing). Nectar now genuinely flows from danced routes into Honey cells (capacity-respecting), ripeness advances and dilutes correctly on deposit, Pollen cells feed real bee hatches with weighted-random caste assignment, and the three-bottleneck SUPPLY/WINGS/COMB math (with a "COMB"/"WINGS"/"SUPPLY" bottleneck label) is live and tested against an engineered scenario. Documented every real interpretation call made against ambiguous architecture prose: the hatch-interval's "adjacent honey cells" term uses the single best Brood cell (not an average), caste assignment is a weighted random roll per hatch (not ratio-tracking), and critically, SUPPLY's per-route throughput needed an invented-but-documented constant (ROUTE_FORAGER_SLOTS=10) since no formula existed for it in the architecture text -- verified this reproduces the architecture's own worked example exactly (WINGS=3.75, COMB=2.4, bottleneck=COMB) before accepting the constant.
  - IMPORTANT GAP SURFACED, not a bug: the agent correctly flagged that profile.honey (the actual SPENDABLE wallet) is never written by ResourceService -- only genHoney/lifetimeHoney tracking counters. This is because ripened honey is only converted to spendable currency by CombService.Harvest, which was explicitly deferred as a TODO in the CombService task (it depends on ResourceService, which didn't exist yet at the time). This means right now, a player can watch their comb fill and glow but has no way to actually bank/spend that honey -- closing this is the immediate next priority given the user is actively testing.
  - Also flagged, correctly not fixed (pre-existing, out of this task's scope): a startup race in Main.lua's Players.PlayerAdded handler for an already-connected Play Solo player (the join event can fire before the handler connects).
- MARKING CONFIRMATION + HOW-TO-PLAY GUIDE BUILT, directly in response to live user playtest feedback, and independently re-verified. NotifyGui + NotifyController (a real toast queue, stacking cleanly, success/error/info styled per the palette) now shows a clear confirmation on every patch mark, plus specific error text for the two failure cases a real confused player would actually hit (too far / already marked). HelpGui + HelpController: an always-visible "?" toggle plus an auto-open-once-per-session instructions panel, with content the agent verified against the actual live ServerScriptService.Systems contents rather than the aspirational architecture -- correctly describes the real current game loop (mark flowers, waggle-dance, build cells) and honestly lists what's NOT yet functional (wallet display, Harvest, Hive/Shop UI, Queen, upper floors, threats, swarm) rather than documenting vaporware. All 5 client controllers (Build/Patch/Dance/Notify/Help) confirmed present and Init()'d in ClientMain via a live read of its actual source (exactly 5 .Init() calls found). Notably, this entire task ran while the real user was STILL connected and playing -- the agent detected Play mode was active, adapted to do all its work via Server-datamodel execute_luau instead of Edit mode, and specifically avoided reloading ClientMain so as not to disrupt the connected player's live session. Plot 1 independently reconfirmed untouched throughout.
- HONEY HARVESTING IMPLEMENTED (closes the gap the economy build surfaced -- ripened honey can now actually be banked into spendable currency) and independently re-verified. CombService.Harvest walks every built Honey cell, banks amt*rip (the ripeness multiplier directly rewards letting honey sit -- the core risk/reward mechanic), resets harvested cells to empty, updates the plot's public stats and fires WalletUpdate immediately rather than waiting for the next tick. RequestHarvest (new RemoteEvent) is rate-limited to 1/s and requires real proximity to the player's own LandingBoard -- payload is empty, the server computes everything from its own state, nothing is client-trusted. A new HarvestController adds a real ProximityPrompt ("Harvest") to all 6 plots' LandingBoards, sharing the E key cleanly with PatchController's flower-marking prompts (Roblox's ProximityPrompt system only shows/fires whichever prompt is actually in range, so no conflict). Live-tested with careful, fully-reverted monkey-patching of DataService/PlotService lookups for a fake test key only: seeded a cell at amt=20/rip=1.5, harvested for exactly 30, confirmed the cell reset and an untouched neighbor cell was correctly left alone (no over-mutation), confirmed a second harvest on an empty comb returns 0 with no error, confirmed Plot 1 and the real connected player were never touched. Independently re-verified: all 3 touched/created scripts compile, both RequestHarvest and WalletUpdate exist as real remotes, Plot 1's owner unchanged. One important operational note the agent correctly flagged: like every other server-side change this session, this requires a Play-mode restart to actually take effect for a live player, since Roblox's require() cache doesn't hot-reload already-running server code.
- FULL UI POLISH PASS ("Warm Wax" house style) COMPLETE on BuildGui + DanceGui and independently re-verified. Research-informed (Bee Swarm Simulator cited as "a masterclass in idle/tycoon game loop design" -- the closest real genre precedent; the broader house style researched: thick dark outlines, generous rounded corners, saturated colors, hard-offset shadows, bouncy tactile buttons). The agent caught and corrected two real assumptions in its own brief before proceeding: NotifyGui/HelpGui did not actually exist yet (contrary to what a prior task claimed -- see the data-loss note below, this makes sense in hindsight) and a literal "golden-zone arc" on the dance dial would have leaked the server's secret true bearing to the client, breaking the anti-cheat design -- built a compass graduation ring instead and correctly identified that a real contrast bug existed (Honey Gold text on Wax Cream measured 1.52:1, unreadable) fixing it to Propolis Brown on cream (5.06:1, passes AA). Independently re-verified: exactly 2 StarterGui children (unchanged, no duplicates), 0 GuiObjects with nonzero Size Offset (full mobile-safety audit), a new UIAnimations script (hover/press feedback, all via UIScale/UIStroke.Transparency, deliberately never BackgroundColor3 since the controllers own that) confirmed present and compiling. Flagged 3 real remaining issues that need a scripter, not a designer, correctly left alone as out of pure-visual scope: BuildController hardcodes name+cost into one TextScaled string (can't have different sizes without a code change), DanceGui's patch-select list has no scrolling (only ~4 of up to 18 marked patches fit), and BuildController's world-space build-mode Highlight colors are off-palette.
- **DATA LOSS INCIDENT, diagnosed and corrected:** the earlier "Notify/Help UI" task (NotifyGui, HelpGui, their controllers, and PatchService's improved mark-confirmation messages) reported success and was independently verified by me at the time -- but that verification itself was compromised, because the entire task ran via the Server datamodel during an active real-user Play session (to avoid disrupting the live player, per my own instruction to that agent). Server-datamodel changes made during a live Play session exist only in that session's ephemeral runtime copy and are discarded when Play mode stops -- confirmed via direct fresh inspection once the session ended: StarterGui contained only BuildGui/DanceGui, PatchService still had only its original generic error message, all of that work was genuinely gone. Cross-checked the rest of the session's work for the same failure mode: ForagingService/ResourceService/PopulationService and CombService.Harvest were CONFIRMED INTACT (their remotes use a lazy getOrCreateRemote() pattern that only materializes on first Init() call, which is why RatesUpdate/RequestSetCastes appeared briefly missing from ReplicatedStorage.Remotes -- the underlying code was never lost, it just hadn't run yet in the fresh Edit-mode session). Dispatched a full, correct rebuild of the lost NotifyGui/HelpGui/controllers/PatchService messaging, this time with an explicit, repeated instruction to use genuine Edit-mode calls throughout and to verify with fresh reads rather than trusting in-task state. Lesson applied going forward: live Play-mode testing must remain read-only/ephemeral-test-only; any actual BUILD step (new GUIs, new scripts, persistent edits) must happen via Edit-mode calls even if that means asking the user to briefly stop their test first.
- FLOWER + ROYAL CELL MESH UPGRADES COMPLETE and independently re-verified, directly fulfilling the user's "update models from blocks to meshes" request. All 8 flower species (Clover, Dandelion, Lavender, Sunflower, Linden, Moonflower, Fireweed, Aurora) now have real AI-generated meshes, both as ReplicatedStorage templates and re-applied to all 18 live patch instances in the Meadow -- Sunflower was correctly re-rolled once after a bad first generation came back head-dominated instead of matching the architecture's "26 diameter on a 48-stud stem" landmark scale. Patches 17 (Fireweed) and 18 (Aurora Bloom), previously 2-part placeholder stubs since the original world build, now have real geometry for the first time. RoyalCell (the queen cell) also upgraded, 5 parts down to 3, independently confirmed via a side-profile probe to have the genuine peanut-shaped silhouette real queen cells have. Two rejections handled correctly rather than shipped badly: GoldenCell's generated hex came back 9.2 studs instead of 15.4 and rounded instead of a true hexagon -- since cells must tile edge-to-edge on the comb lattice, this would have broken tiling game-wide, so the agent correctly kept the geometrically-exact primitive version instead; SwarmPerch hit Roblox's content moderation filter twice and was correctly left as-is rather than forced. Independently re-verified: all 18 patches confirmed with real MeshParts, zero duplicate PatchIds, zero attribute/position drift (each swap replaced only visual children, keeping the same PatchRoot Model and its tag/attributes untouched), RoyalCell confirmed at exactly 3 parts, WaxCell's PrimaryPart confirmed still exactly matching the DimCellPlate disc contract (0.6x15x15) that CombService.Build depends on, total Workspace parts confirmed at exactly 860 (down from 1092 -- mesh objects are consistently cheaper than the primitives they replaced), Plot 1 confirmed untouched throughout.
- NOTIFYGUI/HELPGUI REBUILT FOR REAL, this time genuinely persisted, and independently re-verified with extra scrutiny given the prior incident. The agent correctly diagnosed the earlier ambiguity itself (a lingering `eXemptAttempt` Player entry in Edit mode's Players list) as Team Create presence residue rather than an active session, confirmed via `RunService:IsRunning()=false`/`IsRunMode()=false` before doing any work, and did all its own verification via fresh reads rather than in-task memory. I independently re-verified again after the fact, from a clean slate: StarterGui now genuinely contains BuildGui/DanceGui/NotifyGui/HelpGui (4, not 2), all 6 client controllers present, all 4 touched/created scripts (PatchService/ClientMain/NotifyController/HelpController) compile clean, and PatchService's source genuinely contains all 3 new message strings ("Patch marked!" success, "Too far from that flower" error, "already marked this patch" info) via a direct source-text search, not just trusting the report. The how-to-play content was re-verified against actually-built systems before being written, and correctly includes the newly-real Harvest mechanic while still listing unbuilt features (Queen, Hive/Shop UI, upper floors, threats) as "Coming Soon" rather than describing them as working.
- MAINGUI + HUDCONTROLLER BUILT (wallet display + the three-bottleneck SUPPLY/WINGS/COMB bars) and independently re-verified. Read the real WalletUpdate/RatesUpdate payload shapes directly from ResourceService's source rather than trusting the architecture doc alone (confirmed they agree). The bottleneck treatment is genuinely well thought through: bars normalize against the largest of the three so the smallest is visually obvious even before reading the red highlight, and the flagged bar/label/hint-text all pulse together via one shared TweenInfo rather than a polling loop. Did real multi-viewport overlap testing (6 screen sizes, not just a single check) against all 4 existing GUIs' actual measured positions, honestly disclosing a real, unavoidable tradeoff: full non-overlap isn't geometrically possible at the smallest phone sizes given the existing GUIs' own fixed minimum sizes (DanceGui's dial panel alone is 300x300px), but overlap with the one always-persistent element (HelpGui's "?" button) is confirmed zero at every tested size. Caught and corrected its own false positive during verification (an initial regex-based Init() count came back 9, investigated and found 2 were inside comment text, verified 7 real calls via a full verbatim read) -- exactly the kind of self-skepticism this session now expects after the earlier data-loss incident. Independently re-verified: MainGui exists at DisplayOrder=10, HudController compiles and has real WalletUpdate/RatesUpdate listeners, zero Offset sizing, part count unchanged (860, confirming zero Workspace impact), Plot 1 untouched.
- REACTIVE + AMBIENT VFX COMPLETE (part of the "go all out, addicting gameplay" push) and independently re-verified. A prior interrupted attempt had actually already finished the real work (889-line VfxController, 9 emitters covering cell-build sparkle, 3-tier dance-grade feedback, and harvest shimmer, plus ambient pollen/dust/kiln-steam) -- my own follow-up briefing wrongly assumed 0 ParticleEmitters in the Edit datamodel meant incomplete work, when that's actually the CORRECT state for a client-side runtime-only VFX system (nothing should be baked into the saved place). The agent caught this false premise itself and, rather than rebuilding working code, spent its effort on the verification the brief actually needed: cross-checked every RemoteEvent payload field the controller reads against what the real server code actually fires (all matched), and verified every hardcoded world-geometry box (Meadow/Hub bounding boxes, eave lamp positions) against the real built geometry (all matched exactly). Confirmed a subtle, correct design choice: Dance grade feedback deliberately never uses Alarm Red even for "Poor" results, so a weak dance reads as "used up" rather than as punishment -- exactly the non-punishing feedback design the original brief asked for. All effects sit at Rate=0/Enabled=false at rest and fire via one-shot Emit() calls, giving genuinely zero steady-state particle cost (9 emitters total, 0 p/sec resting, 10 p/sec absolute worst case against an 80 cap). Independently re-confirmed: compiles clean, real listeners for all 3 remotes, zero Alarm Red in the source, wired into ClientMain, Plot 1 untouched. One honest, correctly-disclosed limitation: the remote-to-particle path is verified by source/data-shape matching, not by observing a live burst, since Edit mode can't fire a real OnClientEvent -- that last-mile confirmation needs one real Play session.
- REACTIVE + AMBIENT SOUND COMPLETE (the sound half of the "addicting gameplay" push) and independently re-verified. Like the VFX task, a prior interrupted attempt had actually finished nearly all the real work (199-line SoundController, 7 reactive SFX + 13 ambient sounds, real SoundGroups). The follow-up agent's own audit found a genuine gap rather than just confirming completeness: server code fires FOUR distinct Notify `kind` values (success/error/info/purchase), but the controller only handled three -- meaning StructureService's Apiary Shed/Propolis Kiln tier purchases, which produce no WalletUpdate of their own, were completely silent. In the agent's own words, "the biggest payoff in a tycoon loop" had zero audio feedback. Fixed with a new SFX_Purchase sound and the missing branch. Verified every one of the 8 reactive SoundIds via MarketplaceService:GetProductInfo -- all resolve to genuine, named Pro Sound Effects library uploads (AssetTypeId=3) with real, loadable audio, not invented IDs. Made a good, disclosed judgment call rather than fabricating something: an asset search for a Petal Path-specific foliage rustle sound came back with nothing suitable (only long music beds), so it was correctly left unbuilt rather than misusing an unrelated asset -- flagged as the one thing worth revisiting with a supplied asset ID. Also correctly identified profile.honey is incremented in exactly one place game-wide (CombService's harvest), making the "honey increased = play a coin sound" detection genuinely unambiguous, not a heuristic. Independently re-verified: compiles clean, the purchase branch and SFX_Purchase both genuinely exist, total sound count 21 (up from 20), max volume 0.6999 -- deliberately tuned just under the project's 0.7 ceiling rather than at a round number that would have failed the check. Plot 1 untouched.
- BROAD MESH-UPGRADE PASS COMPLETE (the "every structure and object is mesh" push) and independently re-verified. The continuation agent's audit found the interrupted attempt had done far more than its own notes suggested -- all 9 Flora templates, RoyalCell, 7 of the Structures (including a successful SwarmPerch retry after 2 earlier content-moderation failures), and most Meadow grass/stones were already genuinely mesh-upgraded before this session even started. Precisely resolved the part-count mystery the interrupted attempt was chasing: the 860->830 drop is legitimate mesh consolidation, with the residual +/-1 discrepancies fully explained (a HumanWorldAmbientAnchor Part living as a direct Map child outside any sub-folder that descendant-only sweeps miss, and Terrain itself counting as a BasePart subclass). Found a real bug no part-count audit could ever have caught since it wasn't a part-count problem: a MoonflowerNightLight PointLight had been duplicated into both live Moonflower patches during an earlier re-clone, which would have doubled their night brightness -- confirmed unreferenced by any script and removed, both patches now correctly hold exactly 1 light each. Added 8 more mesh upgrades this session (PollenMound, BroodLarva, BroodCap, GuardPerch, BudButton, CombColumn, WardrobePedestal, PawPrint), deliberately preserving exact part names on several of them since gameplay scripts target those names directly (e.g. BroodCap's Capping Night wave logic). Rejected 4 things for real architectural reasons rather than forcing them: all Cell hex-wall rims (same hex-tiling-precision problem as the earlier correctly-rejected GoldenCell), the Cell PrimaryPart discs specifically (a hard, non-negotiable ceiling -- MeshPart cannot have Shape=Cylinder, and CombService.Build depends on that exact shape), HoneyBlob (a generated mesh bakes the rim geometry into the body, which would break the documented fill-animation contract that scales only the body), and CombFloorRamp (walkable collision stairs -- too risky to trust to generated collision geometry). Cleaned up real leftover debris from the interrupted attempt's own testing: 37 RBXAssistantChannel_MeshGen folders that had accumulated under Workspace.Camera. Independently re-verified: all 4 spot-checked new templates genuinely contain MeshParts, both Moonflower patches confirmed back to exactly 1 light each, Workspace.Camera confirmed empty, part count exactly 830, Plot 1 untouched. Honestly disclosed: the 8 new meshes were verified structurally (non-empty MeshId, correct size/anchoring/contract) but not visually eyeballed in-viewport, to avoid re-introducing the exact kind of staging debris that had just been cleaned up.
- SHOPGUI + HIVEGUI BUILT, closing the last two disclosed client-caller gaps (RequestPurchase, RequestSetCastes) from earlier this session, and independently re-verified. Both remotes' payload shapes were confirmed to genuinely match on both ends via a comments-stripped grep of the real server handlers, not assumed. A sensible additive schema change was made to close a real data gap: RatesUpdate had no tier data at all, so the client couldn't know the player's current Shop/Kiln/Queen tier -- fixed by adding shedTier/kilnTier/queenTier as new trailing fields (a safe pattern already used elsewhere this session, since Lua ignores extra trailing args old listeners don't destructure). The castes UI has real, sensible guardrails: a confirm button that only enables at exactly 100%, a 2.2s client-side cooldown matching the server's real 2s rate limit, and unsaved edits that survive the once-a-second RatesUpdate refresh rather than getting silently overwritten mid-edit. Queen/Perks tabs are honest "Coming Soon" placeholders since QueenService/PerkService don't exist server-side yet -- no fake remotes invented. Independently re-verified: both GUIs and controllers exist, both compile, ResourceService's new tier fields confirmed present and compiling, ClientMain confirmed wired (11 controllers total), Plot 1 untouched, part count unchanged at 830.
  - Two honest follow-ups flagged by the agent, not fixed in this task (correctly out of scope): HelpGui's "Coming Soon" list is now stale text since Shop/Hive are real; and a real, minor gap in PopulationService's own gate -- SetCastes rejects assigning Nurses before Queen tier 3, but the profile's default starting castes (70/15/10/5) already include a Nurse allocation, meaning nurses can hatch before the Crowned Queen unlock is ever reached. Logged as a small backlog item, not blocking.
- MONETIZATION FRAMEWORK BUILT (4 gamepasses: VIP/DoubleHoney/AutoHarvest/ExtraRouteSlot, 2 developer products: Honey/Royal Jelly packs) and independently re-verified. All 6 IDs are deliberately 0 placeholders -- real Gamepass/Product creation requires the user's own Creator Dashboard action (a real-money billing setup, correctly not something an agent should set up autonomously), and every ownership check gracefully short-circuits to "not owned" without ever calling the real Marketplace API when an ID is 0 (verified live -- would otherwise throw on a fake UserId). ProcessReceipt's idempotency was tested with REAL grant math, not just a trivial no-op check: a temporarily-faked product ID granted exactly 5000 honey once, then a duplicate call with the same PurchaseId left the balance completely unchanged -- genuine double-grant protection confirmed, and the temporary test ID was restored to 0 before finishing. AutoHarvest deliberately calls the exact same CombService.Harvest function a manual harvest uses (one real code path, not a reimplementation), and is intentionally simpler/stronger than the existing free Hive Steward perk so paying feels like a genuine upgrade rather than a redundant option. The VIP purchase panel was added as a 4th tab inside the existing HiveGui rather than a new standalone panel, reasoned as "permanent account progression" grouping consistent with Castes/Queen/Perks. Independently re-verified: Config.MONETIZATION exists with all IDs at the 0 sentinel, MonetizationService compiles, both ResourceService/DanceService hooks confirmed present, HiveGui's VipTab/VipPage confirmed present, MonetizationController confirmed present, Plot 1 untouched, part count unchanged.
  - THE 6 EXACT NAMES TO CREATE IN THE ROBLOX CREATOR DASHBOARD (then drop the real IDs into Config.MONETIZATION): Gamepasses -- VIP, DoubleHoney, AutoHarvest, ExtraRouteSlot. Developer Products -- HoneyPackSmall, RoyalJellyPackSmall.
- RETENTION SYSTEM BUILT (7-day login calendar, 3 rotating daily quests, weekly Bloom Festival species bonus) and independently re-verified. Every non-punishing guarantee the user explicitly asked for ("fomo but not too crazy") was tested with real numbers, not just claimed: a profile stuck on streak day 4 that missed 10 real days still correctly received day 4's exact reward (not reset to day 1), and a day-7 profile that missed 50 days still got the capstone Royal Jelly reward before wrapping back to day 1 -- streakDay is only ever advanced, never computed from days-missed. The Bloom Festival's species rotation deliberately deviated from my own suggested pool for a good reason: Pine Resin has no nectarMult in Config.SPECIES (it produces resin, not nectar), so picking it as a festival species most weeks would have silently done nothing -- excluded in favor of the 6 species that can actually benefit. Verified the festival multiplier composes correctly with the just-added monetization multiplier rather than double-counting or conflicting (applied upstream, to speciesMult before Formulas.YieldPerTrip, while MonetizationService's multiplier applies downstream to the whole per-tick total in a different file) -- confirmed via the real yield formula that a festival species gets exactly 1.5x and every other species (including the deliberately-excluded ones) gets exactly 1.0x.
  - Caught and fixed a real, subtle problem independently: a stale cached Config Instance from an earlier require() call in this long Studio session meant fresh reads of the newly-added PROFILE_TEMPLATE fields were failing. Fixed cleanly by swapping the live Config Instance for a fresh clone of itself (identical Source/Name/Parent) -- functionally identical to what a real server restart does for free, and confirmed no stale duplicate was left behind afterward (exactly one Config in the Modules folder). Independently re-confirmed this fix actually holds: fresh require() now correctly shows dailyReward/dailyQuests fields and the full Config.RETENTION table.
  - Honestly disclosed, not hidden: day/week boundaries use UTC midnight (os.time()//86400), not each player's own local midnight -- an accepted first-version simplification, not a bug, and the design leaves room to add a client-reported UTC offset later without reshaping anything. No dedicated daily-rewards/quests corner-widget UI was built this pass (toasts reuse the existing Notify remote) -- flagged as a reasonable future polish item, matching the task's own "don't over-build" guidance. Independently re-verified: all new Config fields present, RetentionService compiles, all 4 action-hook edits (Harvest/Build/SubmitDance/MarkPatch) and the ForagingService yield hook all genuinely present, Plot 1 untouched.
- BUTTONED UP two known backlog items myself, directly via MCP: fixed HelpGui's stale "Coming Soon" text (it still described Shop/Hive/Castes as unbuilt; corrected to reflect that Shop and Hive are real now, leaving only Queen/perks/floors/treeline as genuinely upcoming) and fixed the default starting castes (was forager=70/nurse=15/guard=10/drone=5, meaning a fresh profile could hatch Nurses despite Nurse requiring Queen tier 3, which every fresh profile starts below -- redistributed the 15% to Forager, new default 85/0/10/5, sum still exactly 100). Hit the exact same require()-cache staleness bug the retention agent found earlier in this session (a normal require() call kept returning the pre-edit castes even after the source was genuinely changed) -- applied the same proven fix (swap the Config Instance for a fresh clone of itself), confirmed require() now sees the correct data, and confirmed no duplicate/orphaned Config instance was left behind and all dependent modules (Formulas, HexGrid) still resolve cleanly.
- FULL STRUCTURAL QA PASS (the rest of "button everything up") completed via roblox-playtester, run in Edit mode, Plot 1 confirmed untouched. VERDICT: NEEDS FIXES. Game structure, script substance, all 14 live RemoteEvent contracts (both ends, matching payloads), world content, tags, and performance all passed. The caste fix was independently reconfirmed to have stuck. Found 2 genuine, previously-unknown bugs, both logged to buglist.md as HIGH: (1) saved comb cells/dance routes are never re-rendered into the world on join or cleared on leave -- a returning player's build progress is invisible and blocks re-building over itself, confirmed against the real user's own saved profile; (2) profile.markedPatches uses number keys that DataStore JSON round-trips into strings, risking silent data loss on save, also confirmed live against the real user's saved record. Plus 5 MEDIUM and 2 LOW findings (Plot 1 missing 2 ambient sounds, caste fix has no migration path for existing profiles, 19 Offset-based UI sizes left in Notify/HelpGui, HelpButton overlap/chat-window collision, harvest FX over-firing on non-harvest honey gains, stale comments). One finding (plot signs never reading OwnerName/tag) was a timing artifact -- it was true at the instant the QA pass read the world, but resolved moments later by the plot-indicator task below running concurrently; verified fixed by a fresh read immediately after, not left as an open bug.
- PLOT OWNERSHIP INDICATOR BUILT, directly from live playtest feedback ("There needs to be a indicator for which pad belongs to the player"). Added an `OwnershipTag` BillboardGui to each of the 6 plots' PlotSign, driven by a new `PlotIndicatorController` LocalScript that reads PlotRoot's already-replicated OwnerUserId/OwnerName attributes via GetAttributeChangedSignal (no polling). Three states: unowned ("Empty Plot"), owned by someone else ("{Name}'s Hive"), and the local player's own plot -- unmistakably distinct, a pulsing Honey Gold "YOUR HIVE" tag (UIScale tween, TweenService-Completed-chained, matching this project's no-BackgroundColor3-tweening house style). Independently re-verified live: all 6 billboards present and correctly parented, controller genuinely event-driven (no while-loop), wired as ClientMain's 12th controller in the same require+Init() pattern as the other 11, and correctly displaying "Empty Plot" on all 6 right now since no plot is currently owned.
- USER-REPORTED BUG, investigated: mesh-upgraded structures lost collision (walkable-through) and interaction capability. Root cause narrowed via direct MCP inspection: flower patches are fine (PrimaryPart intact on all 18, ProximityPrompts attach correctly), but at least one server-side interaction (StructureService.RegisterBudButton) depends on a specific named child part (BudTouchPad) inside the BudButton template for Touched-event detection -- exactly the kind of thing a single-unified-MeshPart swap can silently drop without anyone noticing, since BudButton has 0 live instances in the world yet. CanCollide was also found off (false) on 202 of 253 world MeshParts, though the majority of those are correctly-non-collidable decorative dressing (grass tufts, flower blooms) by original design -- the bug is specifically about SOLID structures losing collision, not blanket "all MeshParts must collide." Dispatched a full audit+fix to world-builder: check every Structures/CellContent template's PrimaryPart and named-child dependencies against every system that reads them by name (StructureService, CombService, DanceService), and restore CanCollide=true wherever a mesh replaced a previously-solid, walk-blocking primitive. Result pending as of this entry.
- Dispatched fixes for the QA pass's 2 HIGH bugs (comb/route persistence, markedPatches key normalization) to a general-purpose agent (no dedicated luau-scripter agent type is available in this environment despite CLAUDE.md's roster -- noted as a standing environment gap). Also dispatched the mobile-support pass the user requested (folds in buglist #6/#7/#11: remaining Offset->Scale conversions in Notify/HelpGui, HelpButton repositioning, a general touch-target/safe-area audit) to ui-designer. Both results pending as of this entry.
- MESH COLLISION/INTERACTION FIX COMPLETE (world-builder) and independently re-verified. Root cause of "can't interact" was not a missing part at all: all 18 FlowerPatch models had ModelStreamingMode=Default, so under this game's StreamingEnabled setting, distant patches' PrimaryPart genuinely hadn't streamed onto the client yet when PatchController.Init ran on join -- confirmed via a real Play test, 0/18 flowers got a Mark prompt before the fix, 18/18 after, once ModelStreamingMode was set to Persistent on all 18 world instances plus the 8 Flora templates. Separately found and fixed 5 mesh templates lying sideways/half-buried (BroodCap.CapDome, GuardPerch.PerchBody, WardrobePedestal.PedestalColumn, BudButton.BudBody, CombColumn.ColumnShaft) -- each had inherited a 90-degree rotation from the primitive Cylinder PrimaryPart it replaced, verified upright via a temporary render-and-delete check. Restored CanCollide=true on those same 4 structures (the actual "walk through" bug), widening BudButton's and WardrobePedestal's touch pads so their now-solid bodies don't bury their own interaction zone. Ran a full named-child-dependency grep across every script in the game against every current template -- confirmed nothing else was silently broken by the mesh-upgrade pass, and the Cell PrimaryPart disc contract (0.6x15x15 Cylinder, non-negotiable for CombService.Build) is untouched. Correctly left ApiaryShed/PropolisKiln/SwarmPerch/Smoker alone (already solid/upright) and correctly left flower blooms, PawPrint, and grass tufts non-collidable (original design, not a bug) -- explicitly flagged the flower-STEM walk-through question as a judgment call for me rather than guessing; decided to skip adding invisible stem colliders for now (marginal benefit, real risk of re-narrowing Mark range the way Patch05's stray CanCollide=true just did) since the actual interaction complaint is now confirmed fixed.
- Also found by the same agent and independently re-confirmed by me: PlotIndicatorController (built earlier this session) was created as a LocalScript instead of a ModuleScript, while its own code is written module-style (`return PlotIndicatorController`) and ClientMain calls `require()` on it exactly like the other 11 controllers -- meaning every single player join threw "Attempted to call require with invalid argument(s)" the instant ClientMain reached it. This slipped past the original build task's own loadstring-compiles-clean verification, since a ClassName mismatch doesn't affect Luau syntax validity. Fixed directly via MCP: created a genuine ModuleScript with identical Source, destroyed the stray LocalScript, confirmed exactly one instance remains and it now compiles AND executes correctly as a real module with a callable .Init().
- DISPATCH-WRITING PHASE (Cycles 8-9): 17 dispatch documents written and committed while Studio MCP is unavailable from the cloud container. All dispatches are complete Studio execution guides with full Luau code + verification scripts. Dispatch execution order is CRITICAL -- DataService migrations are sequential (v8->v9->v10->v11). Dispatches 1-17: (1) cycle3_hub_dispatch -- Hub v3 Bee Benches/Flower Beds/Fountain/Weather Notice Board (+67 parts); (2) cycle3_molasses_dispatch -- Old Molasses bear antagonist world zone placeholder (superseded by cycle9); (3) cycle4_queen_dispatch -- Queen upgrade prerequisites (scaffold); (4) cycle4_floor23_dispatch -- Floor 2 (12-cell ring) + Floor 3 (18-cell ring) gate unlock; (5) cycle5_shopgui_dispatch -- DataService v8->v9, ConsumableService (5 items: honey_booster/foraging_zeal/smoker_refill/pollen_packet/royal_jelly_flask), FlagService (6 plot flag skins), 4-tab ShopGui; (6) cycle5_weather_dispatch -- SUPERSEDED by dispatch 19 (cycle10_weather); (7) cycle6_swarm_dispatch -- SwarmService prestige mechanic scaffold; (8) cycle6_cosmetics_dispatch -- CosmeticService + WardrobePad scaffold; (9) cycle6_leaderboard_dispatch -- LeaderboardService + live board UI; (10) cycle6_dailyquests_dispatch -- DailyQuestService 3-quest rotating system; (11) cycle7_narrative_dispatch -- NarrativeService + trigger zones (Signature Moments text reveals); (12) cycle7_achievements_dispatch -- AchievementService + toast reveals; (13) cycle8_hub_expansion_dispatch -- Hub v3 world parts implementation, WeatherNoticeBoard (WeatherSync remote), hub VFX; (14) cycle8_shop_expansion_dispatch -- DataService v8->v9 migration, ConsumableService, FlagService, 4-tab ShopGui full build; (15) cycle8_tutorial_dispatch -- DataService v9->v10, TutorialService 10-step, TutorialController HudCard, 10 TutorialArrow world parts; (16) cycle8_mobile_controls_dispatch -- MobileController PC-gated (TouchEnabled guard), 4 action buttons, InteractBtn proximity scanner; (17) cycle9_threats_dispatch -- DataService v10->v11, ThreatService 6-stage patience progression + smoker repel + permanent BearOffering fork (appease/banish), WaspService scout loop + guard intercept + swat mechanic, ~145 world parts (ThreatZone: Treeline/BearLane/MolassesDen/BearAltar/WaspSpawn/GuardPerch ~4,020/5,000 total), MolassesController + WaspAlertController, 5 RemoteEvents. Total parts ~4,020/5,000.
- DISPATCH 18 WRITTEN (Cycle 10): cycle10_queen_dispatch.md -- Full QueenService build, the highest-priority unbuilt system (pending_fix #8). DataService v11->v12: royalJellyProgress float field (fractional RJ accumulator), queenTier normalisation. Config.QUEEN_TIERS: T1 Virgin Queen → T5 Sun Queen (genGate=1, locked until SwarmService ships). Config.QUEEN block with all visual/timing constants. ResourceService: computeRoyalJellyPerSecond (0.004/s × adjacent Brood cells × CellOutputMult × 1.4 if nurses -- closes the critical gap where Laying Queen had no income source, ~2.5-week acquisition time without it). QueenService ModuleScript: GetTier/HasUnlock/GetNextTier/CanUpgrade/Upgrade/Init with 4-check validation chain. Main.luau: QueenService wiring after ResourceService. 5 Queen templates in ReplicatedStorage.Templates.Queens (T1 6-part Virgin → T5 13-part Sun Queen with Neon Halo disc and Attendants). HiveGui QUEEN tab full rebuild: ViewportFrame portrait, TierBadge, InfoFrame UIListLayout, JellyBar progress fill, UpgradeButton with 3.5s timeout debounce. HiveController: renderQueen state machine (8 states covering all progress/lock/genGate/maxTier combinations), onMoment(QueenGrowth) closes panel on growth. QueenController: LOD system (250-stud radius for non-owner plots), walk/laying/growing state machine, amber footprint pool (flat Neon Cylinder discs tweened 0.45→1 Transparency), QueenGrowth choreography (dim lights → scale tween Back Out → GrowthBurst:Emit → relight → owner camera). ClientMain: QueenController wiring. 0 server parts added (queens render client-only in Workspace.ClientFX.Queens). Step L verification script checks all 8 subsystems.
- DISPATCH 19 WRITTEN (Cycle 10): cycle10_weather_dispatch.md -- Full WeatherService build, supersedes cycle5_weather_dispatch.md (which used 'WeatherChange' while cycle8_hub_expansion used 'WeatherSync'; this dispatch fires both remotes for compatibility). 5-state cycle: Clear (3-5min) → Breezy (1.5-2.5min, +15% foraging speed) → Overcast (1-2min, Molasses 10% faster) → Rain (1-1.5min, bees shelter + Molasses 50% faster) → BloomRush (rare 45-60s, +30% yield, Molasses 50% slower). Config.WEATHER + Config.WEATHER_TRANSITIONS with weighted random transitions. WeatherService fires WeatherChange (string) AND WeatherSync ({stateName}) for backward compatibility with WeatherController and WeatherNoticeController. WeatherRunner Script (thin server launcher). WeatherController LocalScript (client Atmosphere density/spread + Lighting ambient/brightness TweenService transitions). 3 ForagingService hooks: Rain blocks new trips (speedMult=0), Breezy shortens tripTime (÷1.15), BloomRush multiplies nectar yield (×1.3). ThreatService hook: molassesRaidPref scales patience ratchet interval (raidPref>1 = Molasses ratchets faster). 3 hub emitter anchor parts (WindEmitterPart/RainEmitterPart/BloomEmitterPart, Transparency=1, CanCollide=false, Enabled=false at startup). BloomRush expected frequency ~1× per 15-20 min server uptime (intentionally rare shared-server moment). Step J combined verification script.
- DISPATCH 20 WRITTEN (Cycle 11): cycle11_threats_animation_dispatch.md -- GuardBeeController + Smoker in-world interact. GuardBeeController LocalScript: `makeBee()` factory creates 4-part bee model at runtime (Cylinder body Honey Gold, Ball head, 2 Glass wing Parts), `initPerch()` spawns 2 bees per GuardPerch-tagged BasePart, circular orbit + vertical bob animation via RunService.Heartbeat (ORBIT_RADIUS=1.8, BOB_AMPLITUDE=0.35, 180° phase offset between bees), WaspAlert.OnClientEvent → ALERT mode (red-orange ALERT_COLORS, 2.2 rad/s orbit vs idle 0.6, body size 1.1×0.55×0.55 vs 0.9×0.45×0.45), 35s alert duration, CharacterRemoving cleanup, task.delay(5) streaming-safe defer. Zero server cost — client-only runtime-created models. Smoker interact: UseSmoker RemoteEvent, SmokerObject 5-part world prop (SmokerBase Cylinder + SmokerLid + SmokerSpout + SmokerBellows + SmokerHandle) tagged "Smoker" with ProximityPrompt (holdDuration=0.5s, ObjectText="Bee Smoker"), default position Vector3.new(30,4.5,-320) near MolassesDen adjustable. SmokerHandler Script: rate-limited (1 use/5s per player), ConsumableService.SpendSmokerCharge(player) → ThreatService.RepelBear(player), fires Notify with feedback string, PlayerRemoving cleanup for lastUse table. SmokerInteractController LocalScript: CollectionService "Smoker" tag binding, fires UseSmoker:FireServer() on ProximityPrompt.Triggered. Step F: ClientMain wiring notes. Step G: 6-check combined verification script + 3 live smoke tests. Part budget: +5 → ~4,028/5,000.
- DISPATCH 21 WRITTEN (Cycle 11): cycle11_swarm_dispatch.md -- SUPERSEDES cycle6_swarm_dispatch.md (which patched DataService v4→v5; by execution time DS is at v12). DataService v12→v13: generation field + swarmPerks table, migration[8]. Config.SWARM_PERKS: 3-tier perk tree (foragingBoost gen1 = +15% foraging speed, extraRouteSlot gen2 = +1 simultaneous waggle-dance route, bearCalm gen3 = Old Molasses +25% patience). Config.SWARM_REQ constants (queenTier=3, minCells=15, minHoney=5000). SwarmService ModuleScript: canSwarm() prerequisite check, buildPerks() generates cumulative perk table per generation count, performSwarm() resets profile with 20% honey carry-over + increments generation + awards perks + fires server-wide Notify, GetPerks() public API for perk reads from ForagingService/ThreatService. CombService.WipeAllCells addition (destroy HexCell-tagged parts by PlotIndex, reset CombFloors attribute, fire FloorUnlocked). SwarmRunner Script. SwarmPerchWirer Script (CollectionService-driven, HoldDuration=2.0s intentional). SwarmController LocalScript: departure beam (Beam from LandingBoard to skyAnchor at Y=200, gold-purple ColorSequence), pollen-burst ParticleEmitter, camera wide-shot TweenService pull, silence beat (fade-to-black, "..." reveal), SwarmComplete handler with generation reveal + perk list from PERK_LABELS lookup. Perk hooks in ForagingService (foragingBoost tripTime reduction, extraRouteSlot maxRoutes bump) and ThreatService (bearCalm patience multiplier). SwarmPerch world placement x6: 2-part pedestal (Cylinder base Propolis Brown + TopDisc Neon Honey Gold), one per plot at Z=+50, Y=11.5. Sun Queen T5 genGate=1 already set in cycle10_queen — no QUEEN_TIERS change needed; first swarm to generation=1 automatically unlocks T5. Step K combined verification (12 checks). Smoke test injection script. Part budget: +12 → ~4,040/5,000.

## Cycle 11 — Dispatch 22: CosmeticService + WardrobeGui + WardrobePad

**File:** `cycle11_cosmetics_dispatch.md`  
**Supersedes:** `cycle6_cosmetics_dispatch.md` (targeted stale DS v5→v6)

### What it adds
- **DataService v13→v14** — 4 new profile fields: `cosmeticsUnlocked` (array), `equippedSkin` (string), `lifetimeHoney` (number), `molassesRepels` (number); migration[9]
- **3 new RemoteEvents:** RequestEquip (client→server), EquippedSkinChanged (server→all), WardrobeDataSync (server→client)
- **Config.COSMETICS** — 7 skins with full property tables: Honeybee (free), Bumble Bee (50k lifetimeHoney), Night Bee (3 repels, Neon), Autumn Bee (Floor 3), Golden Bee (gen≥2), Moon Bee (gamepass), Arctic Bee (gamepass)
- **Config.COSMETIC_ORDER** — ordered skin list; Config.MONETIZATION.MoonBee=0, ArcticBee=0 (pending real IDs)
- **CosmeticService ModuleScript** — gamepass cache, isUnlocked, CheckAndGrantUnlocks, handleEquip; broadcasts EquippedSkinChanged + WardrobeDataSync
- **CosmeticsRunner Script** — thin require launcher
- **CosmeticController LocalScript** — BeePart tag detection, color2 stripe alternation by part index modulo 2, PointLight children for Neon skins
- **WardrobeGui** — 5th tab ("WARDROBE") in existing HiveGui; SkinCard_Template with Name/Desc/EquipButton/LockLabel
- **WardrobeController LocalScript** — refreshCards() clones SkinCard_Template per skin, handles locked/equipped/equip states; tab switching wired
- **WardrobePad x6** — BASE_Z=35, 2-part pedestal fallback (Propolis Brown Block + Wax Cream Cylinder), ProximityPrompt holdDuration=0, CollectionService tag "WardrobePad"
- **ResourceService hook** — increments lifetimeHoney in parallel with honey credits
- **ThreatService hook** — increments molassesRepels on successful smoker repel, calls CheckAndGrantUnlocks

**Part budget:** +12 → ~4,052/5,000

---

## Cycle 11 — Dispatch 23: Daily Quests

**File:** `cycle11_dailyquests_dispatch.md`  
**Supersedes:** `cycle6_dailyquests_dispatch.md` (targeted stale DS v6→v7, migration[7])

### What it adds
- **DataService v14→v15** — 4 new profile fields: `questSeed`, `questProgress`, `questsLastReset`, `questMetrics`; migration[10]; CURRENT_VERSION = 15
- **Config.QUEST_CATALOGUE** — 20 quest templates across 6 categories (Foraging/Building/Economy/Defense/Population/Prestige+Cosmetics); date-seeded LCG Fisher-Yates rotation gives all players identical 3 quests per day
- **Config.DAILY_QUEST** — NUM_QUESTS=3, RESET_HOUR=0 (midnight UTC)
- **2 new RemoteEvents:** QuestSync (server→client payload), ClaimQuest (client→server slot number)
- **QuestService ModuleScript** — dateSeed(), pickDailyQuests(), IncrementMetric() with lazy daily reset, handleClaim() server-authoritative, PlayerAdded hook
- **QuestRunner Script** — thin require launcher
- **QuestController LocalScript** — bottom-right corner ScreenGui (QuestGui, DisplayOrder=5), toggle button, slide-up panel with 3 quest rows, progress bars with TweenService animation, Claim/Done state buttons; Warm Wax palette throughout
- **14 metric hooks** across 8 services: DanceService (danceTrips), ResourceService (honeyHarvested/honeySpent/propolisEarned/pollenGathered), CombService (cellsBuilt/cellsUpgraded), StructureService (structuresBought), ThreatService (waspsRepelled/smokerUses), PopulationService (beesHatched), SwarmService (swarmsPerformed), CosmeticService (skinsEquipped), WeatherService (bloomRushSeen — all players)

**Part budget:** 0 new world parts — UI only. Total unchanged at ~4,052/5,000

## Cycle 11 — Dispatch 24: LeaderboardService + Cork Board + Plot Plaques

**File:** `cycle11_leaderboard_dispatch.md`  
**Supersedes:** `cycle6_leaderboard_dispatch.md` (had duplicate lifetimeHoney ResourceService hook — dispatch 22 already adds it; stale prerequisite note referencing v5→v6)

### What it adds
- **No DataService migration** — `profile.lifetimeHoney` and `profile.generation` already exist from dispatches 22 and 21 respectively
- **Config.LEADERBOARD** — STORE_NAME="GlobalHoney_v1", UPDATE_INTERVAL=60, TOP_N=10
- **1 new RemoteEvent:** LeaderboardUpdate (server→all clients, top-10 entries array)
- **HudDataSync RemoteEvent** — created if missing; payload extended with `generation` and `lifetimeHoney` fields
- **LeaderboardService ModuleScript** — OrderedDataStore writes (pcall-wrapped), GetSortedAsync top-10 refresh, FireAllClients broadcast every 60s
- **ResourceService hook** — adds `LeaderboardService.RecordHoney(player, profile.lifetimeHoney)` call after existing lifetimeHoney increment (dispatch 22 already adds the increment; this dispatch only adds the RecordHoney call)
- **LeaderboardRunner Script** — thin require launcher
- **LeaderboardController LocalScript** — receives LeaderboardUpdate, dynamically creates Row1–Row10 TextLabels in BoardSurface SurfaceGui, gold/silver/bronze Honey Gold coloring for top 3, "You" highlight row at bottom
- **PlotPlaqueController LocalScript** — receives HudDataSync, finds PlotPlaque-tagged parts by PlotIndex attribute, updates PlaqueText with "Gen N / Xk lifetime"
- **World — Global Cork Board** (6 parts in Workspace.Hub.LeaderboardBoard): BoardBacking (80×22×1 Wood) + 4 frame parts + BoardSurface (SurfaceGui host) with LeaderboardBoard tag + LeaderboardGui SurfaceGui
- **World — Plot Plaques x6** (3 parts × 6 = 18 parts in Workspace.Plot[N].PlotDecor): PlaqueBacking + PlaqueFrame + PlaqueSurface (PlotPlaque tag, PlotIndex attribute, PlaqueGui SurfaceGui)

**Part budget:** +24 → ~4,076/5,000

## Cycle 11 — Dispatch 25: AchievementService + DS v15→v16 (supersedes cycle7_achievements)

**File:** `cycle11_achievements_dispatch.md`  
**Supersedes:** `cycle7_achievements_dispatch.md` (targeted stale DS v7→v8 with migration[8] already taken by dispatch 21)

### What it adds
- **DataService v15→v16** — migration[11]: `profile.achievementsUnlocked = {}` only (questMetrics redundancy removed — already added in migration[10]); CURRENT_VERSION=16
- **Config.ACHIEVEMENTS** — 20 entries across 5 categories: first steps (5), progress milestones (6), system unlocks (5), prestige/late game (3), daily quest milestone (1); each entry has id/label/desc/icon/condition function
- **2 new RemoteEvents:** AchievementUnlocked (server→one client, {id,label,desc,icon}), AchievementSync (server→one client, unlockedIds array)
- **AchievementService ModuleScript** — CheckAll iterates Config.ACHIEVEMENTS vs profile.questMetrics, grants newly-earned achievements, fires AchievementUnlocked per new achievement; SyncClient sends full unlockedIds array on join; PlayerAdded: task.wait(4) → SyncClient
- **AchievementsRunner Script** — thin require launcher
- **QuestService patches** — SetMetric function (for non-cumulative metrics: overwrites instead of adding, lazy-requires AchievementService.CheckAll); AchievementService.CheckAll lazy-require hook added at end of IncrementMetric; avoids circular dependency via function-body lazy require
- **6 additional metric hooks** — CombService: floorsUnlocked via SetMetric; QueenService: queenTierReached via SetMetric; SwarmService: generationReached via SetMetric; ThreatService: molassesEnded via IncrementMetric; CosmeticService: skinsOwned via IncrementMetric; QuestService.handleClaim: questsCompleted +1 direct table update
- **AchievementController LocalScript** — top-right corner toast ScreenGui (DisplayOrder=25); slide-in from right via Back easing, 4s hold, slide-out; toast queue for rapid unlocks; _unlockedIds set to suppress re-showing on sync

**Part budget:** 0 new world parts, total unchanged ~4,076/5,000

## Cycle 11 — Dispatch 26: NarrativeEngine + ZoneTriggers (supersedes cycle7_narrative)

**File:** `cycle11_narrative_dispatch.md`  
**Supersedes:** `cycle7_narrative_dispatch.md` (stale trigger positions; wardrobe_pad and several plot triggers used coordinates that didn't match actual built geometry)

### What it adds
- **NarrativeGui** — ScreenGui in StarterGui (DisplayOrder=20, ResetOnSpawn=false), NarrativeFrame + NarrativeText (GothamItalic, Wax Cream color, starts invisible)
- **NarrativeEngine LocalScript** — in StarterPlayerScripts; Heartbeat proximity polling vs NarrativeTrigger-tagged parts; typewriter reveal (MaxVisibleGraphemes, 40ms/char); 4.5s hold; TweenService fade in/out; once-per-session _seenIds filter; toast queue for simultaneous triggers; entirely client-side, no RemoteEvents
- **18 ZoneTrigger parts** — in Workspace.NarrativeTriggers folder; all Transparency=1, CanCollide=false, Anchored=true; NarrativeId + TriggerRadius attributes; NarrativeTrigger CollectionService tag
- **18 narrative fragments** across 5 zones: hub/apiary (4), plot mechanics (5), meadow (3), treeline/Molasses (4), late-game prestige (2)

### Key trigger position corrections vs cycle7
- `wardrobe_pad`: (-280, 12, -45) → (-250, 8, 35) — matches WardrobePad BASE_Z=35 from dispatch 22
- `plot_first`: (-250, 8, -90) → (-250, 8, -50) — Z=-90 is outside deck footprint (deck Z -55..+55)
- `dance_floor`: Z=-50 → Z=0 — cell (0,0) is at deck centre Z=0, not Z=-50
- `royal_cell`: Z=-60 → Z=-10 — rim cells are ~8 studs from centre, not 60

**Part budget:** +18 invisible parts → ~4,094/5,000

## Cycle 11 — Dispatch 27: OfflineProgressService + DS v16→v17

**File:** `cycle11_offline_progress_dispatch.md`

### What it adds
- **DataService v16→v17** — `profile.lastOnlineTime` (stamped with `os.time()` on every `SaveProfile`); migration[12]: `profile.lastOnlineTime = profile.lastOnlineTime or 0`; CURRENT_VERSION=17
- **OfflineProgressService ModuleScript** — `ApplyOfflineProgress(player, profile)`: reads `lastOnlineTime`, computes elapsed, applies `math.floor(effectiveSeconds * rate)` to `profile.honey`; 120s minimum (no trivial reconnect spam), 14,400s maximum (4h cap, prevents abuse); reads `profile.lastRates.honeyPerSecond` if stored by ForagingService, falls back to 0.833/s (~50/min for a basic hive); rate capped at 50/s regardless
- **DataService load path hook** — calls `ApplyOfflineProgress` immediately after profile load; if honey > 0, fires existing Notify remote with "Welcome back! Your bees collected X honey." success toast
- **Optional Step D** — ForagingService `profile.lastRates` storage (so offline calc uses the player's actual production rate rather than the fallback default)

**Part budget:** 0 new world parts → ~4,094/5,000 (unchanged)

## Cycle 11 — Dispatch 28: FloorProgressGui — FLOORS tab in HiveGui — FLOORS tab in HiveGui

**File:** `cycle11_floor_progress_dispatch.md`

### What it adds
- **Config.FLOOR_REQUIREMENTS** — floor gate table added to Config ModuleScript: Floor 2 (12 cells on floor 1, 5,000 totalHoneySpent, queenTierMin=2); Floor 3 (6 cells on floor 2, 25,000 totalHoneySpent, queenTierMin=4)
- **HudDataSync payload extension** — server now sends 3 additional fields: `floorUnlocked` (current highest floor), `cellsBuilt` (total CombCell-tagged parts), `honeySpent` (profile.honeySpent running total); existing listeners are unaffected (trailing fields)
- **FloorsPage UI** — 5th tab in HiveGui MainFrame PageContainer: `TabFloors` button in TabBar (Warm Wax palette), `FloorsPage` frame; `FloorCard_2` and `FloorCard_3` each containing Title, `RowCells` / `RowHoney` / `RowQueen` frames (each with a Bar fill + Label), and `UnlockedBadge` (hidden until unlocked)
- **FloorProgressController LocalScript** — `--!strict`; listens on HudDataSync; `updateFloorCard(floorNum, req, floorUnlocked, cellsBuilt, honeySpent, queenTier)` animates bar widths via TweenService (Quad/Out, 0.4s), turns bar green (Color3.fromRGB(60,120,40)) when fraction ≥ 1; shows/hides UnlockedBadge; all sizing Scale-based (mobile-safe); 5th tab switching wired in same pattern as tabs 1–4

**Part budget:** 0 new world parts → ~4,094/5,000 (unchanged)

## Cycle 11 — Dispatch 29: MonetizationService Gamepass Purchase Wiring

**File:** `cycle11_monetization_gamepass_dispatch.md`

### What it adds
- **MonetizationService update** — `grantGamepassSkin(player, configKey)` idempotent helper: checks `profile.cosmeticsUnlocked`, inserts skin id, fires `WardrobeDataSync` + Notify toast; `PromptGamePassPurchaseFinished` listener fires immediately on confirmed purchase; `Players.PlayerAdded` join-time `UserOwnsGamePassAsync` check (after 5s profile-load delay) ensures ownership granted even without re-purchase
- **Config.COSMETICS changes** — `gamepassKey = "MoonBee"` added to moon_bee entry; `gamepassKey = "ArcticBee"` added to arctic_bee entry (lookup key used by `grantGamepassSkin`)
- **WardrobeDataSync RemoteEvent** — created if missing (guard for cases where dispatch 22 hasn't been executed yet)
- **WardrobeController (optional Step D)** — locked gamepass skin click now prompts `MarketplaceService:PromptGamePassPurchase` instead of only showing lock label
- **User action reminder** — full table of 6 gamepasses + 2 developer products to create in Creator Dashboard; IDs remain `0` (safe no-op) until pasted in

**Part budget:** 0 new world parts → ~4,094/5,000 (unchanged)

## Cycle 11 — Dispatch 30: SeasonalEventService — Harvest Festival Framework

**File:** `cycle11_seasonal_events_dispatch.md`

### What it adds
- **Config.SEASONAL_EVENTS** — `HarvestFestival` entry: `month=10` (October), `dayStart=1`, `dayEnd=31`, `yieldMult=1.25` (+25% foraging), `bannerMsg`, and `questOverride` table (id=`harvest_festival`, metric=`honeyHarvested`, target=2000, reward 1,500 honey + 50 propolis)
- **SeasonalEventService ModuleScript** — `--!strict`; `Init()` calls `checkDate()` via `os.date("*t")` and sets `_activeEvent`; `IsActive()`, `GetActiveEvent()`, `GetYieldMult()` (1.25 or 1.0), `GetQuestOverride()` (table or nil); `AnnounceToPlayer(player)` fires Notify banner once per player per server lifetime via `_announcedPlayers` guard; `OnPlayerRemoving(player)` cleanup; `updateStallVisibility()` hides/shows HarvestStall BaseParts (Transparency/CanCollide)
- **Main Script wiring** — `require(SeasonalEventService)`, `SeasonalEventService.Init()` at startup; `PlayerAdded` calls `AnnounceToPlayer`; `PlayerRemoving` calls `OnPlayerRemoving`
- **ForagingService yield hook** — `local seasonalMult = SeasonalEventService.GetYieldMult()` inserted after existing `weatherMult`; multiplied into yield formula: `* weatherMult * seasonalMult`
- **QuestService slot 3 override** — before `return quests` in `pickDailyQuests()`, checks `SeasonalEventService.GetQuestOverride()`; if non-nil, sets `quests[3] = questOverride` (festival quest replaces 3rd daily during October)
- **HarvestStall world prop** — 4 parts in `Workspace.SeasonalProps` folder at (-10,4,-115) near Hub: `StallBase` (8×1×3 Wood/SandyYellow), `StallCanopy` (9×0.3×4 harvest red-orange Neon), `StallBanner` (6×1.5×0.2 Honey Gold SmoothPlastic + SurfaceGui TextLabel "🍯 Harvest Festival" FredokaOne), `HoneyJar` (Cylinder r=0.4 h=0.7 Neon Honey Gold); all Anchored=true; Tagged `HarvestStall`

**Part budget:** +4 → ~4,098/5,000

## Cycle 11 — Dispatch 31: WaspService Difficulty Scaling

**File:** `cycle11_wasp_difficulty_dispatch.md`

### What it adds
- **Config.WASP_DIFFICULTY** — 9-tier table keyed by generation (0–8): `raidCooldown` shrinks from 360s (gen 0) to 90s (gen 8+), `swarmSize` grows from 1 to 5 wasps, `honeyStealRisk` scales from 4% to 12% per raid; `Config.GetWaspDifficulty(generation)` clamped helper returns the correct tier struct
- **WaspService full replacement** — `--!strict`; per-player `Heartbeat` loops (10s tick interval); `attemptRaid()` looks up `Config.GetWaspDifficulty(profile.generation)`, checks per-player `_lastRaid` cooldown, applies steal server-authoritatively, fires Notify + WaspRaidSync; `WaspService.ReportDefence(player)` API resets cooldown after successful defence (for BeeguardBeehive scripts); `WaspService.GetPlayerDifficulty(player)` debug helper
- **WaspRaidSync RemoteEvent** — created in `ReplicatedStorage/Remotes` if missing; carries `swarmSize`, `stolenHoney`, `generation` to client for visual feedback
- **WaspRaidClientFX LocalScript** — in StarterPlayerScripts; amber vignette overlay + "⚠ WASP RAID!" FredokaOne/Honey Gold label; TweenService fade-in (0.15s) / hold (1.2s) / fade-out (0.6s); opacity scales mildly with generation (gen 0 = 55% → gen 8 = 75% opaque)
- **WaspTierController LocalScript** *(optional Step F)* — updates `WaspTierLabel` in HiveGui corner from `HudDataSync.generation` field; label shows "🐝⚡ Wasp: Gen N" so players understand escalation

**Part budget:** 0 new world parts → ~4,098/5,000 (unchanged)

## Cycle 11 — Dispatch 32: BeeInspectorGui Inline ReadyCheck Overlay

**File:** `cycle11_beeinspector_dispatch.md`

### What it adds
- **ReadyCheckFrame** — floating overlay child of `HiveGui.MainFrame`; ZIndex=20 (above tab pages); `UDim2.new(0.45,0,0.38,0)` panel; starts off-screen right, slides in/out via TweenService (0.25s Quad/Out); deep Propolis Brown background with border stroke; `Title` TextLabel (FredokaOne, Wax Cream) shows "Floor N Requirements"
- **3 bar rows** (RowCells, RowHoney, RowQueen) each with: icon emoji label, animated `Fill` frame (Propolis Brown → Honey Gold when met), `Value` TextLabel ("0/0" format), `Check` TextLabel (empty → "✓" when condition met)
- **Footer label** — "Keep building!" / "🎉 Ready to unlock!" in Honey Gold / green depending on all-conditions-met state
- **ReadyCheckController LocalScript** — `--!strict`; listens on `HudDataSync`; `FLOOR_REQ` table mirrors server Config (hardcoded, no client require); `updateRow()` animates bar widths + colors via BAR_TWEEN (0.35s Quad/Out); `slideIn()`/`slideOut()` slide the panel; `scheduleAutoHide()` hides after 4 seconds; wired to TabBuild + TabQueen `Activated` events so panel shows on tab click
- **Hides permanently** when `floorUnlocked ≥ 3` (all floors unlocked — no future gate to show)

**Part budget:** 0 new world parts → ~4,098/5,000 (unchanged)

## Cycle 11 — Dispatch 33: PrestigeRewardService — Generation Reset Rewards

**File:** `cycle11_prestige_reward_dispatch.md`

### What it adds
- **Config.PRESTIGE_REWARDS** — `rushDuration=300` (5-min +50% honey window), `skins` table mapping gen 1-5 to skin keys (golden_bee, obsidian_bee, crystal_bee, prism_bee, void_bee), `maxSkinGen=5` (gen 5+ always grants void_bee), `rushLabel`/`rushDesc` for toast
- **Config.PRESTIGE_COSMETICS** — 5 prestige-gated cosmetic entries each with `name`, `color`, `bodyColor`, `genRequired`; separate from Config.COSMETICS (not purchase-locked, prestige-gated)
- **PrestigeRewardService ModuleScript** — `--!strict`; `OnPrestige(player)` called immediately after generation reset: grants generation-appropriate skin (idempotent check vs `profile.cosmeticsUnlocked`) + starts rush window; `GetHoneyMultiplier(player)` returns 1.5 during rush, 1.0 otherwise; `GetRushTimeRemaining(player)` returns countdown seconds; `startRush()` fires Notify toast + auto-expires after `rushDuration`; `OnPlayerRemoving` cleanup; `Init()` wires removing handler
- **PrestigeService wiring** — `PrestigeRewardService.OnPrestige(player)` injected immediately after `profile.generation` increment
- **ForagingService wiring** — `local prestigeMult = PrestigeRewardService.GetHoneyMultiplier(player)` injected alongside existing `weatherMult * seasonalMult`; yield formula now `baseRate × weatherMult × seasonalMult × prestigeMult`
- **PrestigeRushSync RemoteEvent** — created in `ReplicatedStorage/Remotes`; carries `{ active, endTime }` to client
- **PrestigeRushGui LocalScript** — in StarterPlayerScripts; Heartbeat-driven countdown banner ("🏆 Rush: M:SS") centered top of screen; TweenService fade-in/fade-out; Honey Gold border + FredokaOne font; hides cleanly when rush expires

**Part budget:** 0 new world parts → ~4,098/5,000 (unchanged)

## Cycle 11 — Dispatch 34: LeaderboardService — OrderedDataStore + TopBar ScreenGui

**File:** `cycle11_leaderboard_dispatch.md`

### What it adds
- **LeaderboardService ModuleScript** — `--!strict`; `OrderedDataStore` key `BeesWorldLeaderboard_v1`; score formula `generation × 1,000,000 + honey` (prestige players rank above same-honey non-prestige); `fetchTop(5)` reads sorted page + resolves display names (online players first, then `GetNameFromUserIdAsync`); 90-second server-side refresh loop writes all online scores + broadcasts; `RecordScore(player)` for on-demand updates; `PlayerRemoving` writes final score on leave
- **LeaderSync RemoteEvent** — in `ReplicatedStorage/Remotes`; carries `{ entries: top5, updatedAt: timestamp }` to all clients
- **LeaderboardGui ScreenGui** — top-right panel (`22%×36%`); Propolis Brown background + border; FredokaOne/Honey Gold header "🏆 Top Beekeepers"; 5 `RowN` frames each with `Rank` badge, `PlayerName` (Wax Cream), `Score` (right-aligned); "Updates every 90s" footer
- **LeaderboardController LocalScript** — `--!strict`; `onLeaderSync` drives all 5 rows; `fmtScore` formats to "1.23M" / "45.1K" / raw; local player's row highlighted Honey Gold with `BackgroundColor3` tween; footer shows "Just updated" / "Updated Ns ago"
- **Main Script wiring** — `LeaderboardService.Init()` injected (also handles `PlayerRemoving` score writes)

**Part budget:** 0 new world parts → ~4,098/5,000 (unchanged)

## Cycle 11 — Dispatch 35: TutorialService — First-Play Guided Tooltip Overlay

**File:** `cycle11_tutorial_dispatch.md`

### What it adds
- **Config.TUTORIAL_STEPS** — 4-step sequence: `place_cell` (→TabBuild), `harvest_honey` (→HarvestButton), `open_wardrobe` (→TabWardrobe), `check_floors` (→TabFloors); each step has `id`, `title`, `desc`, `arrow` (target GuiObject name), `autoNext` flag
- **TutorialService ModuleScript** — `--!strict`; `OnPlayerAdded` waits 4s for profile load, sends steps to client via `TutorialSync` if `profile.tutorialComplete == false`; `MarkStepComplete(player, stepId)` idempotent — inserts to `profile.completedSteps`, sets `tutorialComplete=true` when all done + saves profile; `Init()` wires `TutorialStepComplete` RemoteFunction server handler
- **TutorialSync RemoteEvent** + **TutorialStepComplete RemoteFunction** in `ReplicatedStorage/Remotes`
- **TutorialGui ScreenGui** — `DisplayOrder=60` (above all other GUIs); `Dimmer` Frame (semi-transparent black overlay); `Tooltip` panel (60%×16%, bottom-centre): `StepLabel` + `Title` (Honey Gold, FredokaOne) + `Desc` (Wax Cream, TextWrapped) + `SkipBtn`; `Arrow` TextLabel (floating sibling, "⬇" pointing at target)
- **TutorialController LocalScript** — `--!strict`; `positionArrow(targetName)` resolves AbsolutePosition of target GuiObject in PlayerGui; `nextStep()` finds first incomplete step; `markCurrentComplete()` updates local state + fires `TutorialStepComplete:InvokeServer`; `skipAll()` fires all steps; `Activated` wiring on tab buttons detects when player taps the target; `TweenService` fade in/out (0.3s)
- **Returns players skip automatically**: `tutorialComplete=true` players receive `TutorialSync` with `tutorialComplete=true` → overlay never shows

**Part budget:** 0 new world parts → ~4,098/5,000 (unchanged)

## Dispatch 36 — QueenUpgradeVFX (cycle 11)
- **QueenUpgradeVFX RemoteEvent** in `ReplicatedStorage/Remotes`
- **QueenService injection**: `QueenUpgradeVFX:FireClient(player, {tier, position})` after `profile.queenTier` increment; Notify toast "👑 Queen upgraded to Tier N!"
- **QueenUpgradeVFXController** LocalScript in StarterPlayerScripts:
  - `spawnBurst(position, tier)`: invisible anchor Part → Honey Gold+Wax Cream ParticleEmitter "QueenBurst" (LightEmission=0.8, Speed=8–14, Emit 15+tier×5 particles) + white "QueenCrown" emitter (Emit 12); `Debris:AddItem(anchor, 2.5)`
  - `playSound(position, tier)`: SoundId "rbxassetid://9119713993", PlaybackSpeed=0.8+tier×0.05; `Debris:AddItem(soundPart, 4)`
  - `screenFlash(tier)`: amber full-screen frame, opacity 0.65+tier×0.02, TweenService FLASH_IN 0.08s / hold 0.12s / FLASH_OUT 0.5s
- **Part budget**: 0 permanent (Debris-managed) → **~4,098/5,000**

## Dispatch 37 — DanceFloorService (cycle 11)
- **Config.DANCE_EVENT**: intervalSeconds=480, durationSeconds=180, honeyMult=1.25, npcCount=6, label="🕺 DANCE PARTY!"
- **DanceSync RemoteEvent** in `ReplicatedStorage/Remotes` (fires `{active, endTime, label, honeyMult}`)
- **DanceFloorService** ModuleScript: `startEvent`/`stopEvent` loop, 6 NPC bee props at hex offsets around FLOOR_CENTRE(0,2,−115), Heartbeat sinusoid bobbing with phase offsets, `GetHoneyMult()` API, lazy-loads optional PrestigeRewardService/SeasonalEventService
- **GameManager wiring**: require + `DanceFloorService.Init()` after SeasonalEventService
- **ForagingService wiring**: `danceMult = DanceFloorService.GetHoneyMult()` multiplied into yield
- **Dance floor props**: 1 central hex tile (Honey Gold) + 6 petal tiles (alternating colours) + disco ball Part (Glass Wax Cream) + PointLight (Honey Gold, Range=28) = **+9 parts**
- **DanceGui**: DisplayOrder=45; DanceBanner (Propolis Brown, Honey Gold UIStroke, UICorner); TitleLabel (FredokaOne Honey Gold); CountdownLabel (FredokaOne Wax Cream); MultBadge "×1.25" (Honey Gold)
- **DanceController** LocalScript: `TweenInfo Back/Out` slide-in / `Quad/In` slide-out; Heartbeat countdown `fmtTime()`; "Dance over" 3s linger then auto-hide
- **Part budget**: +9 permanent → **~4,107/5,000**

## Dispatch 38 — AchievementBadge World Props (cycle 11)
- **Config.ACHIEVEMENTS**: 5 milestone defs — first_harvest (500h), queen_tier_3 (2000h), generation_5 (5000h), honey_100k (10000h), floor_3 (8000h)
- **DataService migration**: `achievements = {} :: {string}` + `lifetimeHoney = 0` added to DEFAULT_PROFILE
- **AchievementSync RemoteEvent** in `ReplicatedStorage/Remotes` (fires `{id, allUnlocked[]}`)
- **AchievementService** ModuleScript: `Grant(player, id)` idempotent via `hasAchievement()`, 5 checker APIs (CheckFirstHarvest/CheckQueenTier/CheckGeneration/AddLifetimeHoney/CheckFloor), `SyncOnJoin` restores on reconnect, honey reward added + Notify toast on unlock
- **Service wiring**: GameManager (require+Init), ForagingService (AddLifetimeHoney+CheckFirstHarvest), QueenService (CheckQueenTier), PrestigeService (CheckGeneration), FloorService (CheckFloor)
- **5 trophy pedestal models** at Z=−130 row (X=−20 to +20, 10-stud spacing): base+column+platform+stem+cup(sphere)+numBadge+BillboardGui = 7 parts each = **+35 parts**
- **BillboardGui** on each cup: AchievementTitle + LockStatus labels, starts grey "🔒 Locked" → Honey Gold "✅ Unlocked!" via TweenService
- **AchievementController** LocalScript: `unlockPedestal` twines all model parts to Honey Gold, adds PointLight, updates BillboardGui; `allUnlocked[]` in payload restores full state from single event
- **Part budget**: +35 permanent → **~4,142/5,000**

## Dispatch 39 — NotificationCenterGui (cycle 11)
- **BellButton** (🔔): TextButton in HiveGui.MainFrame top-right (10%×8%), Propolis Brown bg, Honey Gold UIStroke, UICorner
- **UnreadBadge**: red circle TextLabel on BellButton corner, shows count or "99+", hides when count=0
- **NotificationPanel**: Frame slides in from right (Back/Out 0.30s TweenService); deep dark brown bg, Honey Gold UIStroke border, Propolis Brown header bar with "Clear" TextButton
- **ScrollingFrame**: UIListLayout (VerticalFill, 4px padding), AutomaticCanvasSize=Y, Honey Gold scrollbar, UIPadding 6px all sides; empty state "No notifications yet." label
- **Entry frames** (56px): Title (Honey Gold FredokaOne left-aligned), Message (Wax Cream TextWrapped), Timestamp (relative: "just now"/"Nm ago"/"Nh ago")
- **NotificationCenterController** LocalScript: MAX_ENTRIES=20 (oldest trimmed), newest-first rebuild, unread resets on open, Clear wipes entries+badge, tab-button auto-close, `Notify.OnClientEvent` hooks into all pre-existing service notifications
- **Part budget**: 0 permanent → **~4,142/5,000** (no change)

## Dispatch 40 — BeeColourCustomizer (cycle 11)
- **Config.BEE_COLOURS**: 12 named presets (Honey Gold → Lavender); `Config.BEE_DEFAULT_COLOUR = 1`
- **DataService migration**: `beeBodyColor = 1` added to DEFAULT_PROFILE
- **BeeColorSync RemoteEvent** + **SetBeeColor RemoteFunction** in `ReplicatedStorage/Remotes`
- **BeeColorService** ModuleScript: `GetColor(player)`, `OnServerInvoke` validates index 1–12, applies colour to character body parts, `FireAllClients` broadcasts to all clients; `CharacterAdded` re-applies stored colour on respawn
- **GameManager wiring**: require + `BeeColorService.Init()`
- **WardrobePanel UI**: 12 `Swatch_N` TextButtons in 4×3 grid (Size 20%×16%), each with `SelectionRing` UIStroke (hidden until selected), tooltip TextLabel (hover-reveal), `ColorIndex`+`ColorName` attributes; `RandomiseBtn` (🎲, Propolis Brown); `SelectedColourLabel` preview "Selected: Honey Gold"
- **BeeColourController** LocalScript: `pulseSwatch` (Back/Out scale → Quad/In return), `setSelectedVisual` (ring toggle + preview update), hover tooltip show/hide, `SetBeeColor:InvokeServer`, `BeeColorSync` recolours other players' visible characters client-side
- **Part budget**: 0 permanent → **~4,142/5,000** (no change)

## Dispatch 41 — DailyRewardService (Cycle 11)
- Config.DAILY_REWARDS: 7-day ladder — Day1: 500h/5p → Day7: 5000h/50p + streak_champion skin
- DataService migration: loginStreak, lastLoginDay, dailyClaimedToday added to DEFAULT_PROFILE
- DailyRewardSync RemoteEvent + ClaimDailyReward RemoteFunction in Remotes
- DailyRewardService: utcDayNumber() (os.time()/86400), getNextStreak() consecutive/reset logic
- Idempotent claim: lastLoginDay==today guard prevents double-claim across server restarts
- Skin grant on Day 7 via PrestigeRewardService.GrantSkin, Notify toast on claim
- GameManager wiring: require DailyRewardService + DailyRewardService.Init()
- DailyRewardGui (DisplayOrder=55): dim overlay + CalendarPanel centre-screen (0.68×0.65)
- 7 DayCard_N frames: day icons ☀️🌿🍀🌸⭐🏆👑, honey/propolis labels, ClaimBtn (Honey Gold)
- DailyRewardController: scale-from-centre open (Back/Out), highlightDayCard (past=green✓/today=gold border/future=dimmed)
- Dimmer backdrop tap closes panel (mobile-friendly)
- Part budget: 0 permanent → cumulative ~4,142/5,000

## Dispatch 42 — HiveStatsDashboard (Cycle 11)
- Config.STATS_DISPLAY: sessionTrackingEnabled flag
- DataService migration: lifetimePlaySeconds, totalCellsBuilt, totalGenerations, sessionStartTime
- HiveStatsService: Init (PlayerAdded/Removing hooks, 60s periodic sync), FlushSessionTime, AddCellBuilt, SetGenerations, SyncStats
- StatsSync RemoteEvent in Remotes folder
- GameManager wiring: require + HiveStatsService.Init()
- PrestigeService wiring: SetGenerations called after generation increment
- PlotService wiring: AddCellBuilt called after successful hex cell placement
- StatsTabBtn (📊) added to MainFrame top-right (10%×8%, Propolis Brown, Honey Gold stroke)
- StatsPanel (38%×62%, slide-from-right): Header, CloseBtn, 7 RowList stat frames
- 7 stat rows: Honey Earned / Cells Built / Generations / Play Time / Login Streak / Honey Now / Propolis Now
- HiveStatsController: fmtNumber (K/M abbreviation), fmtTime (h/m), Back/Out open animation, tab-button glow pulse on data update
- Part budget: 0 permanent → cumulative ~4,142/5,000

## Dispatch 43 — WeatherService Thunderstorm (Cycle 11)
- Config.WEATHER_TYPES.thunderstorm: 210s duration, honeyMult=0.70, pollenMult=0.50, lightningInterval=18s±12
- ThunderService: Init, StartStrikes (random-interval loop), StopStrikes, LightningSync:FireAllClients
- LightningSync RemoteEvent in Remotes folder
- LightningController LocalScript: double-flash screen overlay (TweenService), PointLight sky burst, delayed thunder sound
- WeatherController: ambient rain loop (rbxassetid://2676178274) play/stop on thunderstorm active/inactive
- WeatherService injection: ThunderService.StartStrikes/StopStrikes hooks on event start/stop
- ForagingService injection: stormPollenMult applied to pollen yield during thunderstorm
- GameManager wiring: ThunderService.Init()
- Part budget: +0 permanent → cumulative ~4,142/5,000

## Dispatch 44 — MiniMapGui Hex-Grid Radar (Cycle 11)
- MiniMapGui ScreenGui: DisplayOrder=12, bottom-right corner (0.81/0.77 position, 0.18×0.22 size)
- MiniMapPanel: dark bg, Honey Gold UIStroke border, HexCanvas (0.92×0.72 of panel), CellCount label
- MiniMapController LocalScript: 2s poll interval, pooled Frame hex cells (reused across renders)
- Pointy-top hex math: col*cellW + (row%2==1 and cellW/2), row*cellH*0.75
- Queen cell shown with 👑 icon (COLOR_QUEEN bright gold), forager bees shown with 🐝 icon
- GetPlotState RemoteFunction in Remotes folder
- PlotService injection: GetMiniMapData converts profile.hexCells + ForagerBee world positions to grid coords
- Part budget: 0 permanent → cumulative ~4,142/5,000

## Dispatch 45 — BeeNaming (Cycle 11)
- Config.BEE_NAME: maxLength=24, minLength=1, default="Queen Bee", renameCost=500 honey, profanity list
- DataService migration: queenName="Queen Bee", hasNamedOnce=false
- BeeNameSync RemoteEvent + SetQueenName RemoteFunction in Remotes folder
- BeeNameService: sanitise (whitespace trim, length check, profanity filter), first rename free (hasNamedOnce guard), 500 honey cost thereafter
- BeeNameSync:FireAllClients broadcasts userId+name so all players update nearby billboards
- PlayerAdded hook fires current name to joining players
- GameManager wiring: BeeNameService.Init()
- BeeNameController: BillboardGui above queen HumanoidRootPart (StudsOffset Y=3.5, 120×32px, FredokaOne, Honey Gold)
- QueenNameLabel (top-left of MainFrame) + ✏️ RenameBtn
- RenameDialog: scale-from-centre animation, TextBox, confirm/cancel, status label (first-free info/error/success)
- Part budget: 0 permanent → cumulative ~4,142/5,000

## Dispatch 46 — SeasonService Spring/Summer/Autumn/Winter (Cycle 11)
- Config.SEASONS: 4 entries (index 0–3), each with name/emoji/label, honeyMult, pollenMult, propMult, lighting preset
- SeasonService: getSeasonIndex (os.time()/86400%4), applyLighting (8s Quad/Out TweenService transition)
- GetHoneyMult/GetPollenMult/GetPropMult/GetCurrentSeason public API
- 5-minute poll loop: detects day change, re-applies lighting, fires SeasonSync:FireAllClients
- PlayerAdded fires current season to joining player after 2s delay
- SeasonSync RemoteEvent in Remotes folder
- GameManager wiring: SeasonService.Init()
- ForagingService injection: seasonHoneyMult, seasonPollenMult, seasonPropMult applied to all yield calculations
- SeasonController LocalScript: SeasonBadge TextLabel in MainFrame (0.16×0.07), colour tween per season
- Season schedule: UTC day mod 4 → 0=Spring 🌸, 1=Summer ☀️, 2=Autumn 🍂, 3=Winter ❄️
- Part budget: 0 permanent → cumulative ~4,142/5,000

## Dispatch 47 — LeaderboardGui (cycle 11)
- LeaderboardService ModuleScript: buildSnapshot() collects lifetimeHoney from all players, sorts descending, trims top-10, 15s periodic FireAllClients + PlayerAdded 4s delayed sync
- LeaderboardSync RemoteEvent in ReplicatedStorage
- GameManager injection: require LeaderboardService + LeaderboardService.Init() after SeasonService.Init()
- LeaderboardGui ScreenGui (DisplayOrder=11): 🏆 ToggleBtn 5.5%×7.5% right edge (0.945/0.30), LeaderboardPanel 22%×55% starts off-screen Position(1.01,0,0.23,0)
- 10 pre-built Row frames: ranks 1/2/3 gold/silver/bronze background tints, 🥇🥈🥉 Rank labels, PlayerName + HoneyAmt labels
- LeaderboardController LocalScript: fmtHoney K/M abbreviation, local player ► prefix + bright Honey Gold text, slide-from-right Back/Out open animation, glow pulse on ToggleBtn per broadcast
- Part budget: +0 permanent → 4,142/5,000

## Dispatch 48 — TutorialService FTUE (cycle 11)
- DataService migration: hasSeen_tutorial boolean default false
- TutorialService ModuleScript: fires TutorialStart RE 3s after PlayerAdded (hasSeen_tutorial=false only), TutorialComplete RF marks profile permanently
- TutorialStart RemoteEvent + TutorialComplete RemoteFunction in ReplicatedStorage
- GameManager injection: TutorialService.Init() after LeaderboardService.Init()
- TutorialController LocalScript: 7-step card overlay (Welcome→Pollen→Build Cell→Honey→Forge→Leaderboard→Ready!), Honey Gold progress bar, Skip button, Back/Out scale-in + Quad/In close, card destroyed after completion
- Part budget: +0 permanent → 4,142/5,000

## Dispatch 49 — HiveExpansionService (cycle 11)
- Config.EXPANSION: Plot7 (X=350, 25K honey) + Plot8 (X=-350, 50K honey)
- DataService migration: unlockedPlots {[1..6]=true} default
- Workspace: Plot7 + Plot8 folders — Floor Part + LockOverlay Neon Part (amber glow, 35% transparent) + HexCells folder + BillboardGui "🔒 Locked" badge; +4 permanent parts
- HiveExpansionService: server-authoritative unlock, deducts honey, destroys overlay, broadcasts ExpansionSync to all clients; cleans up overlays on server restart via PlayerAdded
- ExpansionSync RemoteEvent + UnlockPlotRF RemoteFunction in ReplicatedStorage
- GameManager injection: HiveExpansionService.Init() after TutorialService.Init()
- ExpansionController: 🗺️ tab button in MainFrame, slide-from-right expand panel, 2 slot rows with cost + Unlock button, ✓ Owned state after unlock
- Part budget: +4 permanent → 4,146/5,000

## Dispatch 50 — AchievementService (cycle 11)
- Config.ACHIEVEMENTS: 12 achievements (honey milestones 1/1K/10K/100K, build 1/10/50 cells, prestige 1/5, streak 7, all seasons, expand plot)
- DataService migration: earnedAchievements {} + seenAllSeasons bitmask 0→15
- AchievementService: Check (idempotent), CheckAll bulk scan, RecordSeason bitmask; awards honey + lifetimeHoney, fires AchievementUnlocked RemoteEvent
- AchievementUnlocked RemoteEvent in ReplicatedStorage
- GameManager injection: after HiveExpansionService.Init()
- ForagingService injection: CheckAll after honey credited
- PlotService injection: CheckAll after hex cell placed
- SeasonService injection: RecordSeason on season change broadcast
- AchievementToast LocalScript: slide-from-top (Back/Out), 3s hold, Quad/In slide-out, queue prevents overlap
- Part budget: +0 permanent → 4,146/5,000

## Dispatch 51 — SpeedUpgradeService (cycle 11)
- Config.SPEED_UPGRADES: 5 tiers, costs 500/2K/8K/25K/75K honey, mult 1.18/1.38/1.63/1.92/2.27×
- DataService migration: forageSpeedTier default 0
- SpeedUpgradeService: server-authoritative BuySpeedTier RF, SpeedSync RE broadcasts tier/mult/nextCost; 5-tier max
- SpeedSync RemoteEvent + BuySpeedTier RemoteFunction in ReplicatedStorage
- ForagingService injection: actualCycleTime = Config.FORAGE_CYCLE_TIME / speedMult
- GameManager injection: SpeedUpgradeService.Init() after AchievementService.Init()
- SpeedUpgradeController: ⚡ tab button, slide-from-right panel, Honey Gold progress bar, Buy/MAX SPEED button states
- Part budget: +0 permanent → 4,146/5,000

## Dispatch 52 — PollenYieldUpgradeService (cycle 11)
- Config.POLLEN_UPGRADES: 5 tiers, propolis costs 50/150/400/1K/2.5K, mult 1.20/1.44/1.73/2.07/2.49×
- DataService migration: pollenTier default 0
- PollenYieldUpgradeService: BuyPollenTier RF (propolis deducted), PollenSync RE broadcasts tier/mult/nextCost
- PollenSync RemoteEvent + BuyPollenTier RemoteFunction in ReplicatedStorage
- ForagingService injection: pollen yield *= GetMult(pollenTier), stacks with storm×season chain
- GameManager injection: after SpeedUpgradeService.Init()
- PollenUpgradeController: 🌼 tab at left-0.70, yellow-green panel, progress bar, propolis cost display
- Part budget: +0 permanent → 4,146/5,000

## Dispatch 53 — QueenUpgradeService (cycle11_queen_upgrade_dispatch.md)
- Config.QUEEN_UPGRADES: tier 0-5, maxBees 3/5/8/12/18/25, honey costs 0/1K/5K/15K/40K/100K
- DataService migration: queenTier = 0 (after pollenTier)
- QueenUpgradeService: GetMaxBees(tier), BuyQueenTier RF deducts honey, QueenSync RE
- ForagingService: dynamic getMaxBees(player) replaces static MAX_BEES constant
- GameManager: QueenUpgradeService.Init() after PollenYieldUpgradeService.Init()
- QueenUpgradeController: 👑 tab at Y=0.80, soft pink panel, MAX QUEEN state at tier 5
- Part budget: +0 permanent → 4,146 / 5,000

## Dispatch 54 — PropolisYieldUpgradeService (cycle11_propolis_upgrade_dispatch.md)
- Config.PROPOLIS_UPGRADES: tier 1-5, mult 1.22→2.73, honey costs 800/3K/9K/25K/65K
- DataService migration: propolisTier = 0 (after queenTier)
- PropolisYieldUpgradeService: GetMult(tier), BuyPropTier RF, PropolisSync RE
- ForagingService: propolisYield *= GetMult(propolisTier) stacked multiplier
- GameManager: PropolisYieldUpgradeService.Init() after QueenUpgradeService.Init()
- PropolisUpgradeController: 🧪 tab at Y=0.775, amber panel, MAX PROPOLIS state
- Completes 4-track upgrade economy: speed/queen/propolis sink honey; pollen sinks propolis
- Part budget: +0 permanent → 4,146 / 5,000

## Dispatch 55 — DailyRewardService (cycle11_daily_reward_dispatch.md)
- Config.DAILY_REWARDS: 7-day rotating, honey 150→1000 + propolis bonuses on days 3/5/7
- DataService migration: lastDailyDay = 0, dailyStreak = 0 (after propolisTier)
- DailyRewardService: utcDayNumber(), streak reset on miss, ClaimDaily RF, DailySync RE
- GameManager: DailyRewardService.Init() after PropolisYieldUpgradeService.Init()
- DailyRewardController: 📅 tab at Y=0.865, 7-pip streak tracker, claim toast slide-from-top
- Auto-opens panel 5s after login when reward available; tab pulses gold when unclaimed
- Part budget: +0 permanent → 4,146 / 5,000

## Dispatch 56 — HiveSkinService (cycle11_hive_skin_dispatch.md)
- Config.HIVE_SKINS: 4 skins — free default, 5K amber, 20K obsidian, 50K royal gold
- DataService migration: activeSkin="default", unlockedSkins={} (after dailyStreak)
- HiveSkinService: OwnerId-tag cell lookup, BuySkin + ApplySkin RF, SkinSync RE
- Server-side apply: changes Material + Color on all player HexCell parts in world
- GameManager: HiveSkinService.Init() after DailyRewardService.Init()
- HiveSkinController: 🎨 right-side tab, scrollable card list, color swatch, equip/buy
- Part budget: +0 permanent → 4,146 / 5,000

## Dispatch 57 — BeeVisualService + PlotService OwnerId Patch (cycle11_bee_visual_dispatch.md)
- PlotService: OwnerId IntValue on HexCell parts + backfill helper
- BindableEvents: BeeCountChanged + SkinChanged BindableEvent in SSS
- ForagingService: BeeCountChanged:Fire() on bee start/return
- HiveSkinService: SkinChanged:Fire() on ApplySkin
- BeeVisualService: Heartbeat orbit spheres (radius 3.2, bob amp 0.6),
  count matches active bees, color matches active skin, cleanup on PlayerRemoving
- GameManager: BeeVisualService.Init() after HiveSkinService.Init()
- Part budget: +0 permanent (spheres transient) → 4,146 / 5,000

## Dispatch 58 — PrestigeService (cycle11_prestige_dispatch.md)
- Config: PRESTIGE_MULT_PER_TIER=1.15, PRESTIGE_MAX_TIER=10, PRESTIGE_COST_BASE=100K
- DataService migration: prestigeTier = 0 (after unlockedSkins)
- PrestigeService: DoPrestige RF resets honey, keeps all upgrades/plots/skins,
  +15% honey mult per tier (max tier 10 = ×4.05), integrates achievement checks
- ForagingService: honey yield × PrestigeService.GetMult(prestigeTier)
- GameManager: PrestigeService.Init() after BeeVisualService.Init()
- PrestigeController: ⭐ right-side tab, lifetime honey progress bar, ×mult display
- Completes end-game loop: upgrades → cosmetics → prestige ladder (×10 tiers)
- Part budget: +0 permanent → 4,146 / 5,000

## Dispatch 59 — NotificationBadge (cycle 11)
- Patch dispatch: red dot notification badges injected into three existing LocalScript Controllers
- DailyRewardController: dailyBadge Frame (red circle, ZIndex=26) added to tabBtn; Visible=data.canClaim==true in DailySync handler
- PrestigeController: prestigeBadge Frame added to tabBtn; Visible=data.canPrestige==true in refreshUI
- ExpansionController: expansionBadge Frame + currentHoney tracker + HoneySync listener; Visible=true when any locked slot affordable
- Badge anatomy: 0.28×0.28 Frame at Position(0.72,-0.06), Color3.fromRGB(220,50,50), UICorner radius 0.5 (circular), ZIndex=26
- Zero new services, zero new RemoteEvents, zero server load — pure client-side patch
- Part budget: +0 permanent → 4,146/5,000

## Dispatch 60 — HoneyStorageUpgradeService (cycle 11)
- 5-tier honey storage capacity upgrades: 2,000 → 5,000 → 12,000 → 25,000 → 50,000 → 100,000
- Config: STORAGE_UPGRADES table, STORAGE_BASE_MAX=2000, STORAGE_MAX_TIER=5
- DataService: storageTier=0 migration after prestigeTier
- HoneyStorageUpgradeService: GetMaxHoney(player), BuyStorageTier RF, StorageSync RE
- ForagingService: honey capped at GetMaxHoney() before crediting yield
- GameManager: HoneyStorageUpgradeService.Init() after PrestigeService.Init()
- HoneyStorageController: 🏺 tab left col Y=0.70, sky-blue STORE_CLR panel, toast on upgrade
- Total honey sinks to max all tracks: ~722,000 honey across full game arc
- Part budget: +0 → 4,146/5,000

## Dispatch 61 — PropolisStorageUpgradeService (cycle 11)
- 4-tier propolis storage: 500 → 1,200 → 3,000 → 7,000 → 15,000 propolis max
- Config: PROPOLIS_STORAGE_UPGRADES, PROPOLIS_STORAGE_BASE_MAX=500, MAX_TIER=4
- DataService: propolisStorageTier=0 migration
- PropolisStorageUpgradeService: GetMaxPropolis(), BuyPropolisStorage RF (honey cost), PropolisStorageSync RE
- ForagingService: propolis cap enforcement via GetMaxPropolis() before credit
- GameManager: PropolisStorageUpgradeService.Init() after HoneyStorageUpgradeService.Init()
- PropolisStorageController: 🧫 tab right col Y=0.50, RESIN_CLR=RGB(160,90,200) purple panel, "Costs Honey" note
- Combined new honey sinks (storage both tracks): 128,000 honey total
- Part budget: +0 → 4,146/5,000

## Dispatch 62 — AchievementService (cycle 11)
- 12 milestone achievements with honey/propolis rewards (total pool: 18,650 honey + 280 propolis)
- Config: ACHIEVEMENTS table with id/name/desc/honeyReward/propolisReward per entry
- DataService: unlockedAchievements=[] + lifetimeHoney=0 migration fields
- AchievementService: Check(player,id) one-shot grant, CheckHoneyMilestones(), Init()
- AchievementUnlocked RemoteEvent for client notification
- ForagingService: lifetimeHoney accumulation + CheckHoneyMilestones() after yield cap
- DailyRewardService: daily_streak_3 + daily_streak_7 after streak increment
- HiveSkinService: first_skin after purchase
- QueenUpgradeService: first_upgrade + max_bees after tier increment
- SpeedUpgradeService: first_upgrade belt-and-suspenders
- PlotService: all_plots when unlockedPlots >= 8
- GameManager: AchievementService.Init() early before other services
- AchievementController: queued gold-border toast (ZIndex=30), slides from top, 3s display, Back/Out in + Quad/In out
- Part budget: +0 → 4,146/5,000

## Dispatch 63 — LeaderboardService (cycle 11)
- Global top-10 leaderboard by lifetime honey (OrderedDataStore "LifetimeHoney_v1")
- LeaderboardService: GetSortedAsync top-10, fetchAndBroadcast() every 60s + on join
- Submit() debounced 10s per player (max ~6 writes/min at 10 players)
- ForagingService: Submit() after CheckHoneyMilestones
- GameManager: LeaderboardService.Init() after AchievementService.Init()
- LeaderboardController: 🏆 tab right col Y=0.60, 10 rank rows gold/silver/bronze
- "Your rank" footer with personal lifetime honey score
- Right column layout complete: skin(0.30) prestige(0.40) propolis-storage(0.50) leaderboard(0.60)
- Part budget: +0 → 4,146/5,000

## Dispatch 64 — Tab Layout Reflow (cycle 11)
- Pure UI position patch: reorganizes both tab columns with even spacing
- Left column (X=0.01, step 0.09): expansion(0.18) speed(0.27) storage(0.36) pollen(0.45) queen(0.54) propolis(0.63) daily(0.72)
- Right column (X=0.925, step 0.10): skin(0.28) prestige(0.38) propolis-storage(0.48) leaderboard(0.58)
- Fixes overlap: queen(0.80) and propolis(0.775) had only 2.5% gap
- No logic changes, no new scripts, no new parts
- Part budget: +0 → 4,146/5,000

## Dispatch 65 — TutorialService (cycle 11)
- First-session 6-step guided tutorial, dismissed by DataStore flag tutorialSeen
- DataService: tutorialSeen=false migration
- TutorialService: TutorialSync RE + TutorialComplete RF (records seen=true)
- GameManager: TutorialService.Init() after LeaderboardService.Init()
- TutorialController: ScreenGui DisplayOrder=50, semi-transparent overlay, pop-in bubble
- Steps point at reflowed tab positions from dispatch 64
- Part budget: +0 → 4,146/5,000

## Dispatch 66 — PollenStorageUpgradeService
- Config: POLLEN_STORAGE_UPGRADES 3 tiers (300→800→2000→5000 pollen cap, costs 50/200/600 propolis)
- DataService: pollenStorageTier = 0 migration after tutorialSeen
- PollenStorageUpgradeService: GetMaxPollen(), BuyPollenStorage RF (costs propolis), PollenStorageSync RE, fires PropolisSync after purchase
- ForagingService: require PollenStorageUpgradeService; pollen cap enforcement
- GameManager: PollenStorageUpgradeService.Init() after TutorialService.Init()
- PollenStorageController: 🌼 tab X=0.085 Y=0.45, POLLEN_CLR yellow-green, panel slides LEFT (PANEL_OPEN_X=0.10), "Costs Propolis 🍬" note
- Part budget: +0 → 4,146/5,000

## Dispatch 67 — SettingsController
- TutorialService: TutorialReset RemoteFunction injected — clears tutorialSeen + fires TutorialSync {seen=false}
- SettingsController LocalScript: ScreenGui DisplayOrder=28, tab ⚙️ at X=0.935 Y=0.01
- BGM on/off toggle (applies to CS:GetTagged("BGM") Sound objects)
- SFX volume slider tap-to-cycle 0/25/50/75/100% (applies to CS:GetTagged("SFX"))
- Graphics quality 3-button row Low/Med/High → QualityLevel3/5/7
- Replay Tutorial button → TutorialReset:InvokeServer()
- Prefs stored as LocalPlayer attributes (session-persistent)
- Part budget: +0 → 4,146/5,000

## Dispatch 68 — MusicController
- MusicController LocalScript: 3-track shuffled playlist, 1.5s crossfade, tagged BGM
- MusicDuck/MusicRestore BindableFunctions in RS
- DailyRewardController patched: duck on open, restore on close
- Part budget: +0 → 4,146/5,000

## Dispatch 69 — SeasonalEventService
- Config: SEASONAL_EVENTS (spring/summer/autumn/winter multiplier tables)
- SeasonalEventService: UTC month detection, GetMultipliers(), hourly refresh, SeasonalSync RE
- GameManager: SeasonalEventService.Init() injected
- ForagingService: seasonal honey/pollen multipliers applied
- SeasonalController: top-center banner, auto-hide 8s, dismiss button
- Part budget: +0 → 4,146/5,000

## Dispatch 70 — FriendBonusService
- FriendBonusService: GetFriendsAsync() cache, +10% honey/friend capped at +30%
- FriendBonusSync RE: broadcasts multiplier to each player on join/leave
- GameManager: FriendBonusService.Init() injected
- ForagingService: friend multiplier stacks with seasonal
- HiveHUDController: "🐝 +X% friend bonus" indicator label
- Part budget: +0 → 4,146/5,000

## Dispatch 71 — BeeNameService
- DataService: queenName = "Queen Bee" migration
- BeeNameService: SetQueenName RF (TextService filter), QueenNameSync RE
- GameManager: BeeNameService.Init() injected
- HiveHUDController: queen name row + ✏️ rename button + dialog overlay
- Part budget: +0 → 4,146/5,000

## Dispatch 72 — HiveStatsService
- DataService: totalHoneyEarned/totalForagingTrips/totalUpgradesBought/daysPlayed/lastLoginDay
- HiveStatsService: daily login tracking, StatsSync RE, BroadcastStats
- GameManager: HiveStatsService.Init() injected
- ForagingService: trip + honey stat increments
- SpeedUpgradeService: upgradesBought increment
- HiveStatsController: 📊 tab X=0.925 Y=0.68, stats panel + active bonuses section
- Part budget: +0 → 4,146/5,000

## Dispatch 73 — UpgradeStatsPatch
- Patches Queen/Propolis/PollenYield/HoneyStorage/PropolisStorage/PollenStorage services
- Each now increments totalUpgradesBought on purchase
- All 7 upgrade paths feed HiveStatsService counter
- Part budget: +0 → 4,146/5,000

## Dispatch 74 — HoneycombVisualController (Cycle 11)
- New LocalScript `HoneycombVisualController` in StarterPlayerScripts
- Listens to existing `PlotSync` RemoteEvent (no new server code)
- Sets Material + Color on `Plot_N` / `ExpansionSlot_N` BaseParts per state:
  - Locked: SmoothPlastic, RGB(60,55,50) grey
  - Owned idle: Neon, RGB(242,168,28) honey gold
  - Foraging active: Neon, pulsing RGB(255,210,60)↔RGB(180,110,10) at 0.6s TweenService Sine
  - Expansion slot locked: Neon, RGB(80,60,180) dim blue
- `activePulses[part]` flag table used as goroutine kill switch — no thread refs needed
- `findPlotParts()` scans Workspace.Map, Workspace.HivePlots, and Workspace root for resilience
- Optional `ForagingSync` connection for per-event foraging state updates
- Part budget: +0 → 4,146 / 5,000

## Dispatch 75 — BeeParticleController (Cycle 11)
- New LocalScript `BeeParticleController` in StarterPlayerScripts
- Creates invisible client-local anchor parts (Transparency=1, CanCollide=false) at each
  plot center (Y+2 above surface) and at the hive centroid
- Each anchor carries a golden ParticleEmitter with fade in/out transparency, random spread,
  LightEmission=0.6 for night glow
- Rate control driven by PlotSync data: RATE_OFF(0) locked, RATE_IDLE(2) owned, RATE_BUSY(12) foraging
- Hive center always emits at RATE_IDLE — hive always visually alive
- Optional ForagingSync per-event rate bump mirrors HoneycombVisualController pattern
- Client-side only — no server replication, +0 server part budget
- Running total: 4,146 / 5,000

## Dispatch 76 — AntiCheatService (Cycle 11)
- New ModuleScript `AntiCheatService` in ServerScriptService
- Cooldown gate: rejects foraging requests < MIN_INTERVAL_SECONDS(8) since last start
- Yield ceiling: rejects honeyYield > MAX_YIELD_HONEY (500 * 3.5 = 1750)
- Strike system: 3 violations → player:Kick() with logged reason
- ForagingService patched: RecordForagingStart() on trip start, CheckForagingRequest()
  before yield application
- PlayerRemoving cleanup prevents stale table accumulation
- Part budget: +0 → 4,146 / 5,000

## Dispatch 77 — AchievementsExpansion (Cycle 11)
- 13 new achievement entries appended to Config.ACHIEVEMENTS:
  - Upgrades Bought: Tinkerer(5), Engineer(20), Master Builder(42)
  - Days Played: Returning Bee(3), Dedicated Keeper(7), Hive Elder(30)
  - Social: Bee Friends(1 friend session), Queen's Court(3+ friends)
  - Seasonal: Spring/Summer/Autumn/Winter Harvest (forage during each event)
  - Mega: Millionaire Bee (1M total honey, reward 5000)
- HiveStatsService patched: calls AchievementService.CheckAchievements after every BroadcastStats
- DataService: 3 new tracking fields (seasonalSeen, friendBonusSessions, maxFriendBonusReached)
- ForagingService: records seasonal event flags and friend bonus trip counts
- All 4 steps have idempotency guards for safe re-execution
- Part budget: +0 → 4,146 / 5,000

## Dispatch 78 — NotificationBadgeController (Cycle 11)
- New LocalScript `NotificationBadgeController` in StarterPlayerScripts
- Injects 14×14 red circle badge (UICorner radius 1) onto HUD tabs after 4s load delay
- AchievementsTab: badge shows when AchievementSync reports new unlocks (count increase)
- DailyRewardTab: badge shows when DailyRewardSync fires available=true, hides on claimed=true
- HiveStatsTab: badge shows on exact milestone values (upgrades 5/20/42, days 3/7/30, honey 1M)
- Back/Out easing pop animation on show, Quad/In shrink on hide
- GetPropertyChangedSignal("Enabled") clears badge when panel opens
- No server changes. +0 parts → 4,146 / 5,000

## Dispatch 79 — PrestigeService (Cycle 12)
- New ModuleScript `PrestigeService` in ServerScriptService
- Prestige conditions: honey full + propolis full + all 8 plots owned
- Prestige effects: reset honey/propolis/pollen, unown plots 2-8, prestigeLevel += 1
- GetPrestigeMultiplier: 1.0 + prestigeLevel * 0.05 (permanent +5% honey/trip per level)
- ForagingService patched with prestige multiplier (stacks after friend bonus)
- PrestigeSync RemoteEvent + RequestPrestige RemoteFunction in RS
- New LocalScript PrestigeController: ⭐ PRESTIGE button at HUD bottom center
- BillboardGui nametag badge "⭐ N" in honey gold FredokaOne above each prestiged player's head
- DataService: prestigeLevel + totalPrestigeCount fields added
- GameManager: PrestigeService.Init() injected
- Part budget: +0 → 4,146 / 5,000

## Dispatch 80 — LeaderboardService (Cycle 12)
- New ModuleScript `LeaderboardService` using OrderedDataStore
- Two ODS keys: LeaderboardHoney_v1 (totalHoneyEarned), LeaderboardPrestige_v1 (prestigeLevel)
- Top-10 broadcast via LeaderboardSync RE every 60 seconds + initial 10s delay
- Updated on PlayerAdded (3s delay for profile load) and PlayerRemoving (final score)
- New LocalScript `LeaderboardController`: LeaderboardGui ScreenGui DisplayOrder=18
- 🏆 tab button at X=0.945 Y=0.55 on HiveHUD, panel slides from right
- Two tabs: 🍯 Honey and ⭐ Prestige, each with 10 rows (rank emoji/number, name, score)
- Top-3 ranks get 🥇🥈🥉, remainder get row number
- GameManager: LeaderboardService.Init() injected after PrestigeService
- Part budget: +0 → 4,146 / 5,000

## Dispatch 81 — PlotService: ResetPlotsForPrestige (Cycle 12)
- PlotService patched: inject ResetPlotsForPrestige(player, {keepPlotIds}) before return
- Clears owner/isForaging/beeCount for all of player's plots except kept ones (default: keep plot 1)
- Calls PlotService.BroadcastPlots() after reset so all clients see cleared state immediately
- Fulfills soft guard in dispatch 79 (PrestigeService)
- STEP B diagnostic reads PlotService function list to confirm broadcast function name
- Part budget: +0 → 4,146 / 5,000

## Dispatch 82 — PrestigeReadySync (Cycle 12)
- Added `PrestigeReadySync` RemoteEvent in ReplicatedStorage
- Added `PrestigeService.CheckAndBroadcastReady(player)` — calls private `canPrestige()`, fires `{ready=true/false}` to client
- ForagingService patched: calls CheckAndBroadcastReady after yield applied (task.spawn)
- PlotService patched: calls CheckAndBroadcastReady after plot.owner assigned (task.spawn); injects PrestigeService require
- PrestigeController patched: `PrestigeReadySync.OnClientEvent` listener shows/hides PRESTIGE button (task.delay(4.5) for button build timing)
- All 4 injection steps have idempotency guards
- Part budget: +0 → 4,146 / 5,000

## Dispatch 83 — Tutorial Expansion (Cycle 12)
- Added `tutorialSeen = {}` field to DataService profile schema
- Added generic `ShowStep(player, stepId, text)` helper to TutorialService
- Added `CheckPrestigeIntro` — fires when honey+propolis >= 90% cap (before prestige)
- Added `ShowPrestigeDone` — fires once after first prestige completes
- Added `ShowSeasonalIntro` — fires once after first seasonal event seen
- ForagingService: calls CheckPrestigeIntro after each yield (task.spawn)
- PrestigeService: calls ShowPrestigeDone after prestigeLevel increment (task.spawn)
- HiveStatsService: calls ShowSeasonalIntro after first seasonalSeen entry (task.spawn)
- All 5 patches have idempotency guards
- Part budget: +0 → 4,146 / 5,000

## Dispatch 84 — AntiCheat Dynamic Prestige Cap (Cycle 12)
- Renamed `MAX_YIELD_HONEY` → `MAX_BASE_HONEY` (500-unit base constant)
- Injected `PrestigeService` require into AntiCheatService
- `CheckForagingRequest` now computes per-player `dynamicHoneyCap = MAX_BASE_HONEY * MULTIPLIER_CAP * prestigeMultiplier * 1.10`
- Prestige 0 cap: 1,925 (was 1,750); Prestige 5: ~2,406; Prestige 10: ~2,887
- Eliminates false-positive kicks for high-prestige players
- Part budget: +0 → 4,146 / 5,000

## Dispatch 85 — Prestige Achievements (Cycle 12)
- Added 4 new Config.ACHIEVEMENTS entries: prestige_1, prestige_3, prestige_5, prestige_10
- Rewards: 500 / 1,500 / 3,000 / 8,000 honey respectively
- AchievementService: new `prestige_level` condition branch (`prestigeLevel >= value`)
- PrestigeService: calls `AchievementService.CheckAchievements` after prestige completes (task.spawn)
- All 3 patches have idempotency guards
- Part budget: +0 → 4,146 / 5,000

## Dispatch 86 — Expansion Plot Propolis Cost (Cycle 12)
- Config.PLOT_COSTS[7] changed from {honey=800} → {propolis=150}
- Config.PLOT_COSTS[8] changed from {honey=1200} → {propolis=300}
- PlotService.ClaimPlot: added propolis deduction branch (`if cost.propolis`) with guard
- Creates meaningful propolis sink independent of prestige condition
- UI label update (showing "propolis" in HUD) deferred to future dispatch
- Part budget: +0 → 4,146 / 5,000

## Dispatch 87 — Plot Cost Label Propolis Display (Cycle 12)
- PlotController: cost label now shows "🔮 X propolis" for cost.propolis plots
- Includes diagnostic STEP A to identify current label pattern before patching
- formatCostLabel fallback helper injected if primary pattern-match fails
- Completes Cycle 12 expansion plot propolis economy
- Part budget: +0 → 4,146 / 5,000

## Dispatch 88 — Pollen Upgrade Tree (Cycle 13)
- CYCLE 13 BEGINS
- Added 5 pollen upgrades to Config.UPGRADES: pollen_yield_1 through pollen_yield_5
- Costs: 30 / 80 / 180 / 350 / 600 pollen (total 1,240); each adds +20% pollen/trip
- UpgradeService: new `cost.pollen` deduction branch + `GetPollenMultiplier(player)` function
- ForagingService: applies `GetPollenMultiplier` multiplier to `pollenYield` per trip
- At max (5/5): 2× base pollen yield per trip
- Part budget: +0 → 4,146 / 5,000

## Dispatch 89 — Propolis Upgrade Tree (Cycle 13)
- Added 5 propolis upgrades: propolis_yield_1 through propolis_yield_5
- Costs: 40 / 100 / 220 / 400 / 700 propolis (total 1,460); each adds +20% propolis/trip
- UpgradeService: GetPropolisMultiplier(player) function added
- ForagingService: propolisYield multiplied by GetPropolisMultiplier per trip
- All three resources now have self-reinforcing upgrade trees
- Part budget: +0 → 4,146 / 5,000

## Dispatch 90 — Foraging Speed Upgrade Tree (Cycle 13)
- Added 4 speed upgrades: foraging_speed_1 through foraging_speed_4
- Costs: 200 / 600 / 1,400 / 3,000 honey; each reduces foraging time by 10%
- At max (4/4): 0.6× base trip duration (36s from 60s base), floor enforced
- UpgradeService: GetForagingSpeedMultiplier(player) with 0.6 minimum clamp
- ForagingService: duration multiplied by GetForagingSpeedMultiplier per trip
- FORAGING_DURATION = 60 ensured in Config
- Part budget: +0 → 4,146 / 5,000

## Dispatch 91 — Bee Count Upgrade Tree (Cycle 13)
- Added 3 bee count upgrades: bee_count_1 through bee_count_3
- Costs: 400 / 1,000 / 2,500 honey; each adds +1 effective bee per plot
- At max (3/3): 4 bees/plot = 4× base yield before other multipliers
- UpgradeService: GetBeeCountBonus(player) returns total bee bonus (0-3)
- ForagingService: effectiveBeeCount = plot.beeCount + beeBonus (computed at trip time, not stored)
- Survives prestige resets cleanly — bonus re-applies each trip
- Part budget: +0 → 4,146 / 5,000

## Dispatch 92 — Upgrades Panel Category Tabs (Cycle 13)
- UpgradesController: appended category tab row (🍯 Honey / 🔮 Propolis / 🌼 Pollen)
- TabRow Frame with UIListLayout horizontal, sized 1/3 each, Honey Gold active / Propolis Brown inactive
- applyTabFilter() shows/hides UpgradeList rows by CostType attribute
- CostType auto-detection heuristic: scans cost label for 🔮/🌼 emojis
- Tab selection persisted to PlayerGui attribute within session
- task.wait(5) ensures UpgradeList is built before TabRow injection
- Part budget: +0 → 4,146 / 5,000

## Dispatch 93 — HiveStats Upgrade Count Integration (Cycle 13)
- DataService: added totalUpgradesBought = 0 to default profile schema
- UpgradeService: increments profile.totalUpgradesBought after each purchase
- UpgradeService: task.spawn → AchievementService.CheckAchievements after purchase
- HiveStatsService: added totalUpgrades field to BroadcastStats payload
- AchievementService: upgrades_bought condition reads totalUpgradesBought
- Enables upgrades_5 / upgrades_20 / upgrades_all achievements to fire correctly
- Part budget: +0 → 4,146 / 5,000

## Dispatch 94 — Prestige Leaderboard Stars (Cycle 13)
- LeaderboardController: injected prestigeBadge() helper (⭐×N for 1-9, 👑 for 10)
- LeaderboardController: _prestigeMap cache built from PrestigeLeaderboardSync data
- LeaderboardController: DescendantAdded watcher applies badges to name labels
- Non-invasive post-processing — does not modify existing row-building logic
- Re-scan triggered on prestige sync arrival to handle render/data race
- Part budget: +0 → 4,146 / 5,000

## Dispatch 95 — Daily Reward Expansion (Cycle 13)
- DailyRewardService: replaced fixed honey grant with 7-day DAILY_REWARDS table
- DailyRewardService: grants honey + propolis + pollen based on streakDay
- DailyRewardService: FireClient payload updated to include all three resources
- DailyRewardController: notification shows 🍯/🔮/🌼 icons for non-zero grants
- Day 7 streak bonus: 300 honey + 60 propolis + 60 pollen
- Part budget: +0 → 4,146 / 5,000

## Dispatch 96 — Sound Effects: Upgrade Purchase & Prestige (Cycle 13)
- New SoundController LocalScript in StarterPlayerScripts
- Plays chime (rbxassetid://9119816100) on successful upgrade purchase
- Plays thud (rbxassetid://9120264459) on denied purchase
- Plays fanfare (rbxassetid://4612394677) on PrestigeSync fire (0.3s delay)
- SFX SoundGroup created in SoundService (volume 0.5)
- Fully client-side — binds to UpgradeSync + PrestigeSync RemoteEvents
- Part budget: +0 → 4,146 / 5,000

## Dispatch 97 — Seasonal Bonus Event System (Cycle 14 opener)
- New SeasonalService (ServerScript): detects UTC month → active season
- 4 seasons: Spring Bloom / Summer Buzz / Autumn Harvest / Winter Rest
- Broadcasts SeasonalSync to all clients on join + every 5 min
- ForagingService: seasonal bonus multipliers applied after all other multipliers
- New SeasonalController (LocalScript): SeasonalHUD frame in top-right
- HUD shows season name + per-resource bonus percentages, fades in/out
- Part budget: +0 → 4,146 / 5,000
- Cycle 14 started

## Dispatch 98 — Plot Unlock Notification (Cycle 14)
- PlotController: injected showPlotToast() function
- Toast shows "🏡 Plot N unlocked! 🍯/🔮 −X resource" for 2.5s
- Slides in from bottom, holds, then fades out — auto-destroys
- Binds to PlotSync OnClientEvent for local player claimed events
- Shows propolis cost text for slots 7-8 (🔮)
- Part budget: +0 → 4,146 / 5,000

## Dispatch 99 — Foraging Return Animation
**File:** cycle14_foraging_return_anim_dispatch.md
**Cycle:** 14
**Change:** Appends spawnYieldPop() to ForagingController via append injection. When ForagingSync fires with yields, floating BillboardGui labels pop up from the plot (+N 🍯/🔮/🌼) for each non-zero yield. Labels rise 4 studs and fade over 1.5s, auto-destroyed by Debris. Multiple yields stack vertically (stackIndex × 1.6 offset). findPlotPart() handles Plot1/plot_1/Plot 1 naming conventions. All injected locals use _99 suffix.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 100 — Progressive Resource Caps
**File:** cycle14_progressive_resource_caps_dispatch.md
**Cycle:** 14
**Change:** ForagingService yield clamps scale with prestige level. effectiveMaxHoney = MAX_HONEY + (prestigeLevel × 500), effectiveMaxPropolis = MAX_PROPOLIS + (prestigeLevel × 100), effectiveMaxPollen = MAX_POLLEN + (prestigeLevel × 60). At prestige 10: honey 10,000 / propolis 1,500 / pollen 900. Gsub substitution on math.min clamp patterns with append fallback.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 101 — Bee Count Milestone Notifications
**File:** cycle14_bee_milestones_dispatch.md
**Cycle:** 14
**Change:** Appends bee milestone checker to HiveStatsController via second OnClientEvent bind on HiveStatsSync. Toasts fire when total bee count crosses 10/25/50/100/250/500/1000. Tracked via LocalPlayer BeeMilestoneReached attribute (session-scoped). Back easing slide-in at Y=0.78, DisplayOrder=21. beeCount field fallback chain handles multiple naming conventions.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 102 — Hive Efficiency Rating
**File:** cycle14_hive_efficiency_rating_dispatch.md
**Cycle:** 14
**Change:** Appends computeHER_102() and HiveEfficiencyLabel to HiveStatsController. Formula: activePlots×0.5 + assignedBees×0.3 + upgrades×0.2. Label lazily injected into existing stats frame with color coding (green ≥90%, gold ≥70%, amber ≥50%, red <50%). Unknown payload fields default to 1.0 contribution. Third OnClientEvent bind on HiveStatsSync.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 103 — Honeycomb Grid Visual Overlay
**File:** cycle14_honeycomb_grid_overlay_dispatch.md
**Cycle:** 14
**Change:** New HoneycombOverlayController LocalScript. Draws Honey Gold Beam lines between adjacent hex plots (within 22 studs). H key toggle or BeehiveOverlayEnabled player attribute. Beams parented to Workspace.HoneycombOverlay folder; destroyed on toggle-off. PlotSync listener rebuilds overlay when new plot is claimed. Width=0.08, Trans=0.6, LightEmission=0.3.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 104 — Foraging Trip Duration Upgrade (Swift Wings)
**File:** cycle14_foraging_duration_upgrade_dispatch.md
**Cycle:** 14
**Change:** Adds swift_wings_1/2/3 upgrades to Config (honey cost 300/750/1600, prereq chain, tripDurationMult 0.90/0.80/0.65). Injects getEffectiveDuration_104() into ForagingService with 5s minimum floor. task.wait(Config.FORAGING_DURATION) replaced with profile-aware call.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 105 — Queen Bee Upgrade
**File:** cycle14_queen_bee_upgrade_dispatch.md
**Cycle:** 14
**Change:** Adds queen_bee upgrade (500 propolis, prereq swift_wings_3, +5 effective bees) and queen_blessing achievement (upgrade_owned condition type) to Config. Patches ForagingService effectiveBeeCount, AchievementService upgrade_owned condition handler, HiveStatsController 👑 crown icon on queen_bee purchase. upgrade_owned is a new achievement condition type.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 106 — Pollen Surge Event
**File:** cycle14_pollen_surge_event_dispatch.md
**Cycle:** 14
**Change:** New PollenSurgeService Script fires ×2 pollen surges every 10-20 min (after 10 min initial delay), 2-min duration. PollenSurgeSync RemoteEvent. ForagingService reads _G.PollenSurgeService.IsActive(). New PollenSurgeController LocalScript shows slide-down banner with os.time() countdown. DisplayOrder=15.
**Part budget:** +0 permanent → 4,146/5,000

## Dispatch 107 — Upgrade Tree Visualization
- Appended `applyTreeIndicators_107()` to UpgradesController
- Reads `UpgradeId` attribute from each UpgradeList row to identify upgrades
- Looks up `Config.UPGRADES[upgradeId].prereq` for chain data
- Adds `PrereqHint` TextLabel: `"→ Requires: [name]"` when locked, `"✅ [name]"` when unlocked
- Adds `LockOverlay` semi-transparent Frame (BackgroundTransparency=0.55) when prereq unmet
- Sets `BuyButton.Active = false` when locked, restores on unlock
- Second `OnClientEvent` bind on `UpgradeSync` triggers re-scan on upgrade purchase
- `task.wait(3)` fallback tries `OwnedUpgrades` player attribute on initial load
- All injected locals use `_107` suffix — no collision with `_92` tab system injection
- +0 permanent parts → 4,146/5,000

## Dispatch 108 — HiveStats Panel Auto-Resize
- Converts `UpgradeList` Frame → `ScrollingFrame` in StarterGui (Step B live surgery)
- `AutomaticCanvasSize = Enum.AutomaticSize.Y` — canvas grows with row count
- `ScrollBarThickness = 4`, `ScrollBarImageColor3 = Honey Gold (242,168,28)`
- `ElasticBehavior = WhenScrollable` — no rubber-band when list fits in panel
- Appends `refreshCanvasSize_108()` + `CanvasResize_108` marker to UpgradesController
- `RenderStepped` one-shot recalculates `CanvasSize` after layout settles each sync
- Fires on `UpgradeSync` (after 0.1s row-update wait) and once at 2s initial load
- Handles `PrereqHint` row height growth from dispatch 107 transparently
- All injected locals use `_108` suffix
- +0 permanent parts → 4,146/5,000

## Dispatch 109 — Propolis Rain Event
- New `PropolisRainService` Script (ServerScriptService): 90s propolis ×2 event every 8–18 min, 10-min initial delay
- `_G.PropolisRainService = { active, IsActive() }` — same pattern as PollenSurgeService (dispatch 106)
- New `PropolisRainSync` RemoteEvent in ReplicatedStorage: payload `{active, duration, endsAt}` / `{active=false}`
- ForagingService append: gsub injects `_G.PropolisRainService.IsActive()` check after propolisYield computation; idempotency marker `PropolisRainMult_109`
- New `PropolisRainController` LocalScript (StarterPlayerScripts): Propolis Purple (130,60,200) banner, DisplayOrder=14, slides from Y=-0.08→Y=0.03, live second countdown
- Simultaneous Pollen Surge + Propolis Rain stacks both doublers independently
- +0 permanent parts → 4,146/5,000

## Dispatch 110 — Idle Hive Watcher
- New `ForagingActivityBE` BindableEvent in ReplicatedStorage
- New `HiveIdleSync` RemoteEvent in ReplicatedStorage
- New `HiveIdleWatcher` Script (ServerScriptService): polls every 60s, fires idle notification if player has ≥1 plot + no activity for 5+ minutes
- Cooldown: `HiveIdleLastNotify` player attribute, 10-min window prevents nag-spam
- ForagingService append: wires `ForagingActivityBE` via `HiveStatsSync.FireClient` monkey-patch; idempotency marker `ForagingActivityFire_110`
- New `HiveIdleController` LocalScript (StarterPlayerScripts): Propolis Brown toast, slides up to Y=0.93, holds 4s, fades out; DisplayOrder=12
- Player join resets activity timer; new players (0 plots) are never notified
- +0 permanent parts → 4,146/5,000
