# ROADMAP — A Bee's World

Checkboxes below were never kept in sync with actual progress (found stale during a buglist cleanup pass) -- reconciled against live game state and buglist.md/changelog.md.

## Phase 1: MVP — COMPLETE
- [x] Game architecture (architecture.md, 1122 lines, + Queen/kid-friendly addenda)
- [x] Core scripts (economy, save/load, plot ownership -- DataService/PlotService/ResourceService)
- [x] First plot fully buildable start-to-finish (all 6 plots, 19-cell hex lattice each)
- [x] Basic lighting/atmosphere (day/night cycle, weather, cinematic post-processing stack)
- [x] Basic UI (wallet display, purchase prompts -- MainGui/HudController/ShopGui)
- [x] First play-test (multiple structural + live playtests this session)

## Phase 2: Core Loop — COMPLETE
- [x] Full building/upgrade tier ladder (Shed/Kiln/Queen/Dance Floor tiers)
- [x] The game's signature mechanic: the waggle-dance two-tap foraging minigame + hex-grid comb building + ripening honey glow
- [x] Multiple plots side-by-side in one server (6 plots, independently verified byte-identical geometry)
- [x] Sounds (24 sounds, ambient + reactive SoundGroups)
- [x] Rebirth/prestige system (SwarmService -- generation reset preserving perks/royalJelly/cosmetics/achievements)

## Phase 3: Polish — COMPLETE
- [x] Particle effects (VfxController -- dust, sparks, steam, ambient/route bees, guard-perch bees)
- [x] Advanced lighting (Atmosphere/Bloom/ColorCorrection/DepthOfField, per-zone tuning)
- [x] Cosmetics (CosmeticService -- bee skins: worker/Molasses Fur/Furious)
- [x] Mobile optimization (Scale-only UI, 44px+ touch targets, touch controls, kid-friendly input timing fixes)

## Phase 4: Content — NEARLY COMPLETE
- [x] Additional plot themes / late-game content: Comb Floor 2 (12-cell ring) and Floor 3 "Crown Comb" (7-cell disk) fully built and wired on all 6 plots -- real geometry, real CombService.UnlockFloor gating (80% prior floor + Floor 3 generation>=1 + Config.FLOORS cost), real gate open/re-lock, real client UI (HiveGui FLOORS tab)
- [x] New mechanics: Old Molasses 6-stage threat arc, wasp raids, Queen system, perks, resin->propolis harvesting
- [ ] Secrets / easter eggs -- not started
- [x] Leaderboards (LeaderboardService, OrderedDataStore top-10, physical Hub board)
- [x] Achievements (AchievementService, 12 achievements, all wired to real triggers)

## Queued by explicit user request, deferred until everything else is finished
- [ ] **EPIC HUB REDESIGN**: user feedback (with screenshot) -- "I like the idea of the community hub but it is way to cramped. Lets go epic on this one after everything else is finished." The Apiary Yard hub currently reads as too small/cluttered for what should be the game's central social space. User explicitly wants this deferred, not started now -- likely the last major visual undertaking once the feature list is otherwise complete. When picked up: this is architect + world-builder + set-dresser + lighting-director scale work, not a quick polish pass -- probably warrants a fresh architecture addendum given how much has been added to/around the Hub this session (GlobalLeaderboard, HubBellController, BeekeepersDiary, 6 PlotGateways, ShedCorner, prop clutter) since its original build.

## Known deferred/honest placeholders (not bugs, disclosed in buglist.md)
- hiveSteward perk (auto-harvest) and longMemory perk (route decay) are purchasable but inert -- their prerequisite mechanics (partial per-cell harvesting, route quality decay) don't exist yet
- Fireweed/Aurora Bloom flower species remain behind the not-yet-built Generation-gate content wall
- Floor 2/3 comb expansion (see above)

## Deferred cloud visuals (build when the named system exists in the game)
These cloud dispatches (fork/add-beesworld-project) were skipped because their target system or data is not in the place yet. Each is a visual that becomes buildable once the dependency lands. Pick up each one when its dependency is in place.

- [ ] 200 HiveBirthdayController -- needs TotalSessions and TotalHoneyHarvested player attributes written by a session/stats system.
- [ ] 201 PollenSparkleController -- needs PollenLevel attribute on PollenMound parts (pollen storage/level system).
- [ ] 202 DanceReplayController -- needs DanceResult to carry bearing and distance (a remote-contract change; needs an explicit decision first).
- [ ] 205 QueenAuraController -- needs a QueenCell tag on the queen cell part.
- [ ] 206 BroodTimerController -- needs a BroodCell tag plus HatchIn/HatchMax attributes on brood cells (hatch timer system).
- [ ] 208 NectarFlowController -- needs NectarLevel attribute on RouteBeam (a Beam; needs a nectar-in-transit state in ForagingService).
- [ ] 213 WeatherBadgeController -- needs WeatherService (season/weather state machine).
- [ ] 215 PlotVisitorService + VisitorCountController -- visitor counter system (new service).
- [ ] 216 WeatherService -- seasonal weather cycle with foraging multipliers (new service; the chunk-2 visuals in this list depend on it).
- [x] 236 QuestHudBadge: built, wired, moved off TutorialCard to the top-left column. Compiles. Not yet play-verified.
- [~] 217 StreakBadgeController: built (visual only, reads RetentionService streakDay). Compiles. ClientMain wiring still pending (add after QuestHudBadge.Init in the final wiring pass). Not play-verified. DailyStreakService rejected as duplicate.
- [ ] 217 (original entry, superseded by the line above) DailyStreakService + StreakBadgeController -- daily login streak (overlaps the existing daily login reward; decide first).
- [ ] 218 Honey Ripeness Bonus -- a gameplay change (2.2x harvest multiplier), not a visual; needs a design decision against the existing capping bonus.
- [ ] 223 Honey Leaderboard Board -- in-world cork board (overlaps the existing leaderboard; decide first).
- [ ] 224 Plot Name Plaques -- owner and tier badge above each plot (overlaps PlotIndicatorController; decide first).
- [ ] 236 QuestHudBadge -- daily quest progress widget (depends on the quest system; now in place, can be built).

### Lane A results (client badges and counters, compile-verified, not play-verified)
- [~] 224 plot tier badge ("Gen N") on the existing OwnershipTag: built. Owned plots with generation 1+ only.
- [~] 223 cork-board skin on the existing leaderboard board: built, Edit-tested on a fake SurfaceGui only. Real board skin not verified.
- [~] 215 PlotVisitorService (server Script, 2 s loop, 35-stud radius, session-only) + VisitorCountController: built. Server counting needs a Play check.
- [x] 201 PollenSparkle: already built and wired. PollenLevel is written in the existing 1 Hz pass.
- [~] 200 HiveBirthday: milestone visual at sessions 1, 7, 30, 100 on the owner's own plot. New lifetime profile field totalHoneyHarvested (default 0), written in CombService.Harvest. Needs a Play check.
- ClientMain wiring pending for VisitorCountController and HoneyLeaderboardBoardSkin.
- Open discrepancy: Plot1 OwnerUserId reads nil in Edit by the name I checked. Lane A reported 0. Needs a Play-mode or attribute-name check.

### Lane B results (world tags and attribute visuals, compile-verified, not play-verified)
- [~] 205 QueenAuraController: built. One line added to ResourceService tags Royal cells QueenCell. Aura is a PointLight that scales with QueenTier. Needs a Play check with a Royal cell. ClientMain wiring pending.
- [x] 234 PlotFlagWindController: built client-side (flags under Workspace.ClientFX.PlotFlags, PlotFlag tag, PlotOwner attribute, TweenService wind). ClientMain wiring pending.
- [~] 237 HarvestGlow, 239 HoneyCellDrip, 228 CombShimmer: already existed and wired. Tags are set at runtime by ResourceService, so they can only be checked in Play. HarvestGlow uses the player's LastHarvestTime (no per-cell attribute exists).
- [ ] 225 ForagerTrail: BLOCKED. No per-forager carry state exists. Needs a gameplay decision and a forager carry attribute.
- [ ] 206 BroodTimer: BLOCKED. Hatching is a profile-level accumulator in PopulationService, not per-cell. Needs an owner decision.
- [ ] 208 NectarFlow: BLOCKED. No nectar-in-transit state in ForagingService.
- WaxCell and NurtureCell tags: not built. These are not cell states in GameEnums.

### Batch 2 deferred visuals (dependency missing in the place)
- [ ] 225 ForagerTrailController -- needs ForagerBee tag and a NectarLoad attribute written by the forager system.
- [ ] 226 HoneyDripFountainController -- needs the Apiary Yard hub fountain model and a HubHoneyFlow workspace attribute.
- [ ] 227 BearAltarGlowController -- needs BearAltar tagged parts (bear altar world geometry).
- [ ] 228 CombShimmerController -- needs HoneyCell/WaxCell/NurtureCell/BroodCell tags (the place only has CombCell tags).
- [ ] 233 HoneyMilestoneController -- needs a player Honey attribute (current HoneyCount is the banked harvest count, a different quantity; decide which is meant).
- [ ] 234 PlotFlagWindController -- needs PlotFlag tagged parts and a PlotOwner attribute.
- [ ] 237 HarvestGlowController -- needs HiveComb tagged parts and a LastHarvestTime attribute.
- [ ] 238 BearRitualController -- needs BearAltar tagged parts (same dependency as 227).
- [ ] 239 HoneyCellDripController -- needs HoneyCell tagged parts and HoneyStored/HoneyCapacity attributes.

### Cloud system decisions (judged by GameMaster)
- [x] WeatherService (cloud dispatch 216) -- CLOSED as duplicate. The live place already has weather in TimeService (Clear/Breezy/Overcast/Rain/BloomRush, the only weather Heartbeat, TimeWeather remote, GetWeatherMultipliers wired into ForagingService). Building a second weather owner would duplicate it. Cloud's season layer (Spring/Summer/Autumn/Winter, Sunny/Drizzle/Storm/Fog states) remains a FUTURE feature, not needed by any deferred visual except the weather badge, which the existing HUD chip already covers. Badge (213) closed as duplicate.
- [ ] Seasons layer (future, optional) -- would be a CurrentSeason state added inside TimeService, not a new service. Only worth building if the owner wants seasons.
- [x] PopCapController (211) -- built and wired.

## Overlap decisions: existing system vs cloud version (decided by GameMaster)
- Weather: HYBRID. Keep TimeService as the single owner (it has the tested state machine, the only Heartbeat, and the forage hooks). Add seasons as a layer inside TimeService (CurrentSeason), not a new service. Cloud's Sunny/Drizzle/Storm/Fog state names are rejected for now because they would replace tested gameplay states.
- Seasons (future, BIG): build as a layer inside TimeService. Start with visual-only (sky tint, bloom window shifts). Any yield multiplier needs an explicit approval first. Needs an architect addendum before building.
- Daily login / streak: KEEP existing RetentionService (7-day calendar, streak never resets on a missed day, tested). Cloud 217 DailyStreakService rejected. Only the streak badge visual is added, reading RetentionService.
- Daily quests: KEEP existing RetentionService quest pool (now 7 entries). Quest HUD badge (236) reads it. Cloud quest service rejected.
- Leaderboard board: KEEP existing LeaderboardService and physical board. Cloud 223 cork-board is a visual skin only, applied to the existing board, not a second service.
- Plot plaques (224): HYBRID. Extend the existing PlotIndicatorController OwnershipTag billboard with the tier badge. No separate plaque system.
- Achievements: KEEP existing AchievementService (14 entries, all wired). Cloud 12-badge set rejected as duplicate.
- Honey ripeness bonus 2.2x harvest (218): REJECTED. The existing ripeness system already gives up to 2.2x by design, and the Capping Bonus exists. Adding a second 2.2x would double-count.
- Visitor counter (215): small, no existing equivalent. Optional, low priority.
- Hub redo (BIG): HYBRID. Start from the existing Apiary Yard layout (it has working leaderboard, bell, shed, diary, gateways) and add the cloud's zone ideas (Flowerpot Den, benches, flower beds, honey fountain 226). Needs its own architect addendum before any build. Deferred until the owner says go.

## Decisions re-checked for fun and engagement (kids and adults)
- Weather (TimeService, Rain halts flight, Bloom Rush): KEEP. Real choices (when to fly, when to wait) that both age groups read at a glance.
- Seasons: ADD LATER inside TimeService. Visual first (sky tint, bloom windows), so kids see the year change and adults get a long-term goal. No yield change without approval.
- Daily login and quests (7 quests now incl. upgrade, resin, re-dance): KEEP. Short daily goals that teach the newer systems.
- Leaderboard: KEEP the existing service. Add the cork-board skin for the visual charm, and adult-facing competition stays intact.
- Plot plaques / ownership tier badge: HYBRID onto the existing billboard. Status is fun for adults and easy to read for kids.
- Achievements (14): KEEP. Good kid-friendly goals with adult depth.
- Ripeness 2.2x harvest bonus (cloud 218): REJECTED. Doubles an existing mechanic, which confuses both age groups.
- Hub (big): HYBRID. Kids get the fountain, benches, flower beds and a Flowerpot Den to explore; adults get the leaderboard and the sense of scale. Architect spec in progress before any build.
- Tutorial: KEEP the existing 4-step real-action tutorial (short, and each step is a real action). Copy rewritten in plain words for 7-year-olds: "tap Space twice" for the dance, "sweeter" instead of "ripen", and it ends pointing to cell upgrades. Cloud's 10-step FTUE REJECTED as too long for a short tutorial.

## Hub redo status
- [x] Architect addendum written: architecture_hub_redo_addendum.md (layout, zones, moves, cloud adopt/reject, build order, owner decisions).
- [x] Build steps 0-3 done and checked (backup 153/18/32 parts; envelope rays and ground scans 41/41; pads at X -105..105 Z -290 exact; board front clearance 34 studs after fountain moved to X -60; hub BaseParts 291 of 300). Light-clearance exceptions flagged: window SurfaceLight, HoneyFill in jar, PathLanternJar. Play-mode navigation check not yet run.
- [x] Steps 0-6 done: hub at 321 parts (cap 380). Leaderboard moved to centre with a clear view (34 studs). Fountain moved to X -60. Pads moved to X -200,-170,-140 (plots 1-3) and 50,80,110 (plots 4-6), Z -290. Light clearance exceptions flagged. Play navigation NOT PLAY-VERIFIED.
- [ ] Steps 7-8 still open (not recorded as done in this update).
- [~] Honey Obby spec being written as section 13 of the addendum. The earlier addendum had no obby zone.

## QA test plot
- [~] Harness built (QAGuard, QATestMode flag, DataStore guard on Save/Load and leaderboard writes). Owner approved a QA-only PlotService hook; in progress.

## Honey Obby (requested by owner)
- [x] Built: east extension X 400..520; obby at X 430..464 with 13 platforms tagged ObbyPlatform (tag was missing and is now added), 2 checkpoints, 98 parts, 3 moved pines. Achievement obbyFinisher 'Honey Hopper' (15 total). NOT PLAY-VERIFIED for walking or completing.
- Design direction (for the spec): short course of about 10-12 jumps using honeycomb hex platforms and flower-pad steps, all in the game's warm wax palette. Kid-friendly: wide platforms, soft landings, no instant-death drops (falls send you to the last checkpoint). Adult-friendly: an optional timed run whose best time is shown on the hub board. Finish reward: a small achievement and a finish flourish, not a paid advantage.
- Checkpoints: plain pads that set the respawn point, same attribute pattern as other interactables.

## Quests and weekly tasks (owner request)
- [x] DONE, verified live in Edit (source-level; not yet play-tested): daily pool expanded 7 -> 10 (added build3, refresh2, harvest2). Weekly pool of 6 (w_harvest25, w_upgrade10, w_dance15, w_resin5, w_refresh8, w_build10), 3 picked per epoch week, reward 1000 honey + 100 propolis, progress resets at the week boundary, earned rewards never removed, no new Heartbeat. RetentionGui has a Weekly section.
- Weekly reward: 1000 honey, 100 propolis (verified in source). Still open: whether to keep the 3-entry daily window change flagged earlier.
- Expand daily quest pool (currently 7) with a few more varied goals for both kids and adults.
- Add a WEEKLY task set, same shape as dailies: a pool of bigger goals, 3 picked each week (deterministic per week, like dailies per day), separate weekly progress that resets at the week boundary, and a bigger reward than dailies.
- Non-punishing like dailies: missing a week never removes progress already earned or resets a streak.
- Weekly goals should lean on bigger, longer-term play (for example: upgrade cells, build many cells, many dances, many resin harvests), so they feel like a real goal.

## Session update 2026-10-03 (verified vs NOT PLAY-VERIFIED marked)
- [x] Plot layout v2 applied to all six plots: board (0,-37.5), smoker (33,-37.5), sign (-40,-49) rotation 0 with text 'Tap a glowing cell to build!', wardrobe (-46,10), swarm perch (0,45). Guard perches unchanged. Cells and gates unchanged (baseline hash matched). NOT PLAY-VERIFIED visually.
  - Open: Propolis wording in help panel step 3 (owner decision). Landing board walkability (C4).
- [x] Honey obby: see the Honey Obby section above. Open: StreamingTargetRadius (Properties check), finish light tween not built, mouth sign and tufts skipped.
- [~] Ladybugs: 16 bugs (12 meadow, 4 hub), LadybugService, LadybugController, CompanionController, skin stages at 3/7/12. Runtime count verified in Play (16). Taps and unlock NOT PLAY-VERIFIED. Journal tab SKIPPED.
- [x] Daily quests 10, weekly 6 (verified in source).
- [x] Overhead name and honey tag removed. YOUR HIVE label moved to the plot sign board. Yellow spotlight on the Plot1 crest only (other plots not done).
- [x] Floor 2 build target fix: BuildController offers all unlocked floors; CombFloors listener. Server build verified in Play via QA runner. Client highlight NOT VERIFIABLE in QA (client compares to real UserId).
- [x] Teleport fix: pads moved out of the spawn walk fan; teleport checks by server pass. Far-pad travel NOT PLAY-VERIFIED.
- [x] Bee-count bar (CasteBadgeController) and name tag controller removed from ClientMain boot.
- [ ] Not built: ladybug journal tab, honey obby finish light tween, obby mouth sign, tufts, comb-plate hex clones (cylinders used), seasons layer, brood / nectar / forager visuals (blocked on gameplay state).
- [ ] Owner actions: manual walk test in Play (buglist #103); streaming radius in Properties; look at plot and sign visuals; Propolis wording; set Server Size = 6 before publish (buglist #77); save the place.

## Live recheck (Studio af40365e)
Edit-mode recheck of 182 cloud-backlog rows, read-only (no play mode). Full evidence: cloud_backlog_live_recheck.md. CONFIRMED-LIVE means wired in source, not play-tested.

- CONFIRMED-LIVE: 37
- NOT-WIRED: 1 (item 212, caste split HUD badge; removed from ClientMain boot by owner request)
- FOUND-LIVE: 2 (items 123, 139, bear warning)
- NOT-FOUND: 82 table rows (see groups below). Note: the recheck summary block lists 60 NOT-FOUND and 82 AMBIGUOUS, but its own table has them the other way round. Table counts are used here.
- AMBIGUOUS: 60 (key term not searched or too generic; needs a targeted second search)

Stale "wiring pending" notes now confirmed wired (Init'd in ClientMain): streak badge (217), visitor count (215), plot flag wind (234), leaderboard cork skin (223), finish light.

NOT-FOUND by theme (no matching code in any script):
- Infra and anti-cheat: 26 narrative engine, 27 offline progress, 32 Bee Inspector, 33 PrestigeReward, 76 AntiCheat, 81 ResetPlotsForPrestige, 82 PrestigeReadySync, 84 AntiCheat prestige cap
- Upgrade trees and tiers: 49, 51, 52, 54, 60, 61, 66, 73, 88, 89, 90, 91, 93, 104, 132, 144
- Plots 7-8: 86, 87
- Hive stats and UI panels: 38 trophy pedestals, 42, 72, 108, 152 stats panels, 44 minimap, 119 and 141 roster, 127 hive health, 169 sparkline
- Notifications, settings, audio: 39, 59, 78 notification and badge UI, 67 settings, 68 music, 110 idle watcher, 111 full-hive multiplier, 130 daily tip
- Social and customization: 40 bee colour, 45 and 71 bee naming, 56 hive skins, 70 and 151 friend bonus, 163 naming ceremony, 74 and 75 honeycomb and particle controllers
- Weather, events, holiday: 43 thunderstorm, 106 pollen surge, 109 propolis rain, 154 and 155 holiday, 146 and 183 temperature, 172 honey booster, 191 coronation, 195 warmup ripple
- VFX and feedback: 126, 171, 173, 174, 175, 176, 177, 178, 180, 184, 186, 187, 190, 193, 196, 197, 198, 199

Owner decisions still open:
- Seasons: SeasonService (46) build inside TimeService or not (architect addendum needed)
- Monetization: real gamepass and product IDs into Config.MONETIZATION (29)
- Community hub: redo steps 7-8 and the epic redesign go-ahead (153)
- DanceResult contract change for dance replay ghost (181, 182, 202)
- Nectar-in-transit state (176, blocked item 208)
- Propolis wording in help panel step 3; landing board walkability (C4)
- Honey obby streaming radius in Properties
- Manual walk test in Play (buglist #103); set Server Size = 6 before publish (buglist #77)
