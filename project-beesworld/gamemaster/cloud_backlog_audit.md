# Cloud backlog audit: A Bee's World (dispatches 20-239)

Branch: add-beesworld-project. Place 123313915411717. Audit date 2026-10-03.

## Read this first

- Studio status: `list_roblox_studios` returned no open instances, so no live check (script_grep, execute_luau) was possible. No item is confirmed BUILT-IN-GAME. Items the docs say were verified live are shown as BUILT-DOCS-LIVE and still need a recheck in Studio.
- Play-mode behaviour is NOT verified for any BUILT item. Every BUILT row is doc evidence only.
- Git history: the 'dispatch NNN' commits add spec briefs (`cycleNN_*_dispatch.md`) and state/changelog updates. No game source (.lua/.luau) is in git on this branch, so source could not be checked from git either.
- All 220 numbers 20 to 239 appear in commit subjects. There are no gaps (the earlier estimate of about 193 was off).
- state.json says the cloud dispatches were briefs, not executions. Only the visual subset 200-239 plus the server attribute passes 214, 221, 222, 231 were implemented. Items 20-199 are mostly matched by docs to native systems or left UNKNOWN.
- Category BUILT-DOCS-LIVE means the docs say live-verified. BUILT-NOT-PLAY-VERIFIED means built or wired per docs, not play-tested. Conflicting doc entries are noted in the evidence column.

## Summary counts

| Category | Count |
|---|---|
| BUILT-DOCS-LIVE | 18 |
| BUILT-NOT-PLAY-VERIFIED | 25 |
| REJECTED-DUPLICATE | 20 |
| REJECTED-DESIGN | 4 |
| BLOCKED | 11 |
| NOT-STARTED | 3 |
| UNKNOWN | 139 |
| **Total** | **220** |

## Full table

| # | Name | Category | Evidence | Next step |
|---|---|---|---|---|
| 20 | Threat animation pass | UNKNOWN | No doc entry under this name. Old Molasses 6-stage arc is recorded as built (roadmap Phase 4). | Studio: script_grep for Molasses threat animation code. |
| 21 | Swarm prestige (SwarmService) | BUILT-DOCS-LIVE | buglist #70 records it as a new system, verified; roadmap Phase 2 Rebirth/prestige. | Recheck live. |
| 22 | Bee cosmetics (CosmeticService, 7 skins, WardrobeGui) | BUILT-DOCS-LIVE | buglist #71 records CosmeticService verified; roadmap Phase 3. | Recheck live. |
| 23 | Daily quests (cloud dispatch) | REJECTED-DUPLICATE | Roadmap overlap decision: KEEP RetentionService quest pool; cloud quest service rejected. | None. |
| 24 | Leaderboard (cloud dispatch) | REJECTED-DUPLICATE | Roadmap overlap decision: KEEP LeaderboardService; cloud board is skin only. | None. |
| 25 | Achievements (AchievementService) | BUILT-DOCS-LIVE | Roadmap Phase 4: 14 achievements, all wired (KEEP decision). | Recheck live. |
| 26 | Narrative engine and zone triggers | UNKNOWN | Only one doc mention of NarrativeEngine; not in roadmap. | Studio: script_grep NarrativeEngine in StarterPlayerScripts; count NarrativeTrigger tags. |
| 27 | Offline progress service | UNKNOWN | No doc mention of OfflineProgressService. | Studio: script_grep OfflineProgress. |
| 28 | Floors tab (FloorProgressGui) | BUILT-DOCS-LIVE | Roadmap Phase 4: Floor 2/3 with real client UI (HiveGui FLOORS tab). | Recheck live. |
| 29 | Monetization gamepass wiring | BUILT-NOT-PLAY-VERIFIED | Docs: MONETIZATION FRAMEWORK BUILT; 4 gamepasses and 2 products need real IDs from Creator Dashboard. | Owner: create passes/products and paste IDs into Config.MONETIZATION. |
| 30 | Seasonal event (Harvest Festival framework) | UNKNOWN | No SeasonalEventService in docs. Roadmap lists seasons layer as future. | Studio: script_grep SeasonalEvent. |
| 31 | Wasp difficulty scaling by generation | UNKNOWN | Wasp raids recorded as built; generation scaling not documented. | Studio: script_grep WaspService for generation scaling. |
| 32 | Bee Inspector ReadyCheck overlay | UNKNOWN | No doc mention of BeeInspector. | Studio: script_grep BeeInspector. |
| 33 | PrestigeRewardService (generation reset rewards) | UNKNOWN | Prestige system is live (#70); reward service not named in docs. | Studio: script_grep PrestigeReward. |
| 34 | LeaderboardService OrderedDataStore and TopBar | BUILT-DOCS-LIVE | Roadmap Phase 4: leaderboards with OrderedDataStore top-10. | Recheck live. |
| 35 | TutorialService 4-step tooltip overlay | BUILT-DOCS-LIVE | Roadmap overlap decision: KEEP existing 4-step real-action tutorial. | Recheck live. |
| 36 | Queen upgrade VFX burst and sound | UNKNOWN | Queen system is live; this VFX pass is not named in docs. | Studio: script_grep QueenUpgrade VFX. |
| 37 | Dance floor periodic event (DanceFloorService) | UNKNOWN | Dance Floor tiers recorded; periodic dance event not documented. | Studio: script_grep DanceFloor event code. |
| 38 | Achievement trophy pedestals | UNKNOWN | Achievement service is live; pedestal props not named in docs. | Studio: search workspace for trophy pedestal models. |
| 39 | Notification Center toast history panel | UNKNOWN | No doc mention of NotificationCenter. | Studio: script_grep NotificationCenter. |
| 40 | Bee colour customizer (12 presets, Randomise) | UNKNOWN | No doc mention of BeeColour. | Studio: script_grep BeeColour. |
| 41 | 7-day login streak calendar (DailyRewardService) | BUILT-DOCS-LIVE | RetentionService 7-day calendar built and verified (roadmap KEEP decision). | Recheck live. |
| 42 | Hive stats dashboard panel | UNKNOWN | No doc mention of HiveStatsDashboard. | Studio: script_grep HiveStats. |
| 43 | Thunderstorm weather event | UNKNOWN | TimeService states listed as Clear/Breezy/Overcast/Rain/BloomRush; Thunderstorm not listed. | Studio: script_grep TimeService states for Thunderstorm. |
| 44 | MiniMapGui hex-grid radar | UNKNOWN | No doc mention of MiniMap. | Studio: script_grep MiniMap. |
| 45 | Queen bee custom naming (BeeNaming) | UNKNOWN | No doc mention of BeeNaming. | Studio: script_grep BeeNaming. |
| 46 | SeasonService (Spring/Summer/Autumn/Winter) | NOT-STARTED | Roadmap: seasons layer is a future optional feature; no SeasonService in docs. | Owner decision: build seasons inside TimeService (roadmap plan), after architect addendum. |
| 47 | LeaderboardGui top-10 (cloud) | REJECTED-DUPLICATE | Native LeaderboardService and physical board kept (roadmap KEEP). | None. |
| 48 | TutorialService FTUE overlay (cloud) | REJECTED-DUPLICATE | Native 4-step tutorial kept; cloud 10-step rejected as too long (roadmap). | None. |
| 49 | HiveExpansionService extra plot slots | UNKNOWN | Plot expansion slots exist (cost notes in dispatches 86-87); service not named in docs. | Studio: script_grep HiveExpansion. |
| 50 | Achievement service 12 badges (cloud) | REJECTED-DUPLICATE | Roadmap: cloud 12-badge set rejected; native AchievementService kept. | None. |
| 51 | Foraging speed upgrade (5-tier) | UNKNOWN | Upgrades exist; this tier ladder not named in docs. | Studio: script_grep SpeedUpgrade. |
| 52 | Pollen yield upgrade (5-tier) | UNKNOWN | Not named in docs. | Studio: script_grep PollenYieldUpgrade. |
| 53 | Queen bee capacity upgrade (5-tier) | UNKNOWN | Queen system live; capacity ladder not named in docs. | Studio: script_grep QueenUpgrade. |
| 54 | Propolis yield upgrade (5-tier) | UNKNOWN | Not named in docs. | Studio: script_grep PropolisYieldUpgrade. |
| 55 | 7-day login streak rewards (DailyRewardService) | REJECTED-DUPLICATE | Native RetentionService 7-day calendar kept (roadmap KEEP). | None. |
| 56 | Hive skins (HiveSkinService) | UNKNOWN | No doc mention of HiveSkin. | Studio: script_grep HiveSkin. |
| 57 | Bee visuals and plot owner id patch | UNKNOWN | Plot owner attribute is inconsistent in docs (roadmap Plot1 OwnerUserId nil in Edit). | Studio: script_grep BeeVisualService and check plot OwnerUserId attribute in Play. |
| 58 | Prestige rebirth system (PrestigeService) | BUILT-DOCS-LIVE | Live as SwarmService prestige (buglist #70 verified). | Recheck live. |
| 59 | Notification badge red dots | UNKNOWN | No doc mention of NotificationBadge. | Studio: script_grep NotificationBadge. |
| 60 | Honey storage upgrade service | UNKNOWN | HoneyStored/HoneyCapacity attributes recorded in plumbing batch; service not named. | Studio: script_grep HoneyStorage. |
| 61 | Propolis storage upgrade service | UNKNOWN | Not named in docs. | Studio: script_grep PropolisStorage. |
| 62 | AchievementService (cloud) | REJECTED-DUPLICATE | Native AchievementService kept (roadmap). | None. |
| 63 | LeaderboardService (cloud) | REJECTED-DUPLICATE | Native LeaderboardService kept (roadmap). | None. |
| 64 | Tab layout reflow | UNKNOWN | No doc mention. | Studio: check HUD tab layout in StarterGui. |
| 65 | TutorialService (cloud) | REJECTED-DUPLICATE | Native TutorialService kept (roadmap). | None. |
| 66 | Pollen storage 3-tier cap | UNKNOWN | Not named in docs. | Studio: script_grep PollenStorage. |
| 67 | Settings controller (BGM, SFX, quality, tutorial reset) | UNKNOWN | SettingsController mentioned once in docs; features not confirmed. | Studio: script_grep SettingsController. |
| 68 | Music controller ambient playlist with crossfade | UNKNOWN | No doc mention of MusicController. | Studio: script_grep MusicController. |
| 69 | Seasonal event time-limited multipliers | UNKNOWN | Same gap as 30; no service named in docs. | Studio: script_grep SeasonalEvent. |
| 70 | Friend bonus +10% honey per friend | UNKNOWN | No doc mention of FriendBonus. | Studio: script_grep FriendBonus. |
| 71 | Queen bee naming with chat filter (BeeNameService) | UNKNOWN | Not named in docs (buglist #71 is an unrelated bug number). | Studio: script_grep BeeNameService. |
| 72 | Persistent hive stats panel (HiveStatsService) | UNKNOWN | No doc mention. | Studio: script_grep HiveStatsService. |
| 73 | Upgrade count stats patch | UNKNOWN | No doc mention of totalUpgradesBought. | Studio: script_grep totalUpgradesBought. |
| 74 | Honeycomb visual controller (hex cell states) | UNKNOWN | Hex cells and tags recorded; this controller not named. | Studio: script_grep HoneycombVisual. |
| 75 | Bee particle controller (flight particles) | UNKNOWN | VFX layer recorded (VfxController); this controller not named. | Studio: script_grep BeeParticleController. |
| 76 | AntiCheatService foraging exploit prevention | UNKNOWN | No doc mention of AntiCheat in live docs. | Studio: script_grep AntiCheat. |
| 77 | 13 new achievements (AchievementsExpansion) | UNKNOWN | Achievement count is 14 in docs; cannot tell which were added here. | Studio: list achievement IDs and compare to brief. |
| 78 | Notification badge controller (HUD tabs) | UNKNOWN | No doc mention. | Studio: script_grep NotificationBadgeController. |
| 79 | Prestige rebirth mechanic (Cycle 12) | BUILT-DOCS-LIVE | Live as SwarmService prestige (buglist #70). | Recheck live. |
| 80 | Global ODS leaderboard | REJECTED-DUPLICATE | Native OrderedDataStore top-10 kept (roadmap). | None. |
| 81 | PlotService.ResetPlotsForPrestige | UNKNOWN | Prestige reset is live (#70); this exact function not named. | Studio: script_grep ResetPlotsForPrestige. |
| 82 | PrestigeReadySync condition broadcast | UNKNOWN | Not named in docs. | Studio: script_grep PrestigeReadySync. |
| 83 | Tutorial expansion for prestige and seasonal steps | REJECTED-DESIGN | Cloud tutorial expansion rejected: roadmap keeps 4-step tutorial, 10-step FTUE rejected as too long. | None. |
| 84 | AntiCheat dynamic prestige cap | UNKNOWN | No doc mention. | Studio: script_grep AntiCheat prestige cap. |
| 85 | Prestige achievements (levels 1, 3, 5, 10) | UNKNOWN | Achievements live (14); these entries not confirmed. | Studio: check achievement list for prestige entries. |
| 86 | Expansion plots 7-8 cost propolis | UNKNOWN | Not named in docs. | Studio: check plot 7-8 cost attributes. |
| 87 | Plot cost label shows propolis for slots 7-8 | UNKNOWN | Not named in docs. | Studio: check plot cost label text. |
| 88 | Pollen upgrade tree | UNKNOWN | Not named in docs. | Studio: script_grep Pollen upgrade. |
| 89 | Propolis upgrade tree (Resin Collectors I-V) | UNKNOWN | Resin to propolis harvesting recorded as built; tree not named. | Studio: script_grep Resin Collectors. |
| 90 | Foraging speed tree (Wing Strength I-IV) | UNKNOWN | Not named in docs. | Studio: script_grep Wing Strength. |
| 91 | Bee count tree (Larger Colony I-III) | UNKNOWN | Not named in docs. | Studio: script_grep Larger Colony. |
| 92 | Upgrades panel category tabs | UNKNOWN | Not named in docs. | Studio: check upgrades panel tabs in StarterGui. |
| 93 | HiveStats upgrade count integration | UNKNOWN | Not named in docs. | Studio: script_grep upgrade count. |
| 94 | Prestige leaderboard stars | UNKNOWN | Not named in docs. | Studio: script_grep stars. |
| 95 | Daily reward expansion | REJECTED-DUPLICATE | Native RetentionService daily rewards kept (roadmap KEEP). | None. |
| 96 | Sound effects (upgrade purchase, prestige) | UNKNOWN | Sound set recorded (24 sounds); these specific cues not named. | Studio: script_grep upgrade purchase sound. |
| 97 | Seasonal bonus event system | UNKNOWN | Same gap as 30 and 69. | Studio: script_grep SeasonalEvent. |
| 98 | Plot unlock notification toast | UNKNOWN | Not named in docs. | Studio: script_grep PlotUnlock toast. |
| 99 | Foraging return animation (yield pop) | UNKNOWN | Not named in docs. | Studio: script_grep yield pop. |
| 100 | Progressive resource caps | UNKNOWN | Not named in docs. | Studio: script_grep ResourceCap. |
| 101 | Bee count milestone notifications | UNKNOWN | Not named in docs. | Studio: script_grep milestone notification. |
| 102 | Hive efficiency rating display | UNKNOWN | Not named in docs. | Studio: script_grep efficiency rating. |
| 103 | Honeycomb grid visual overlay | UNKNOWN | Not named in docs. | Studio: script_grep grid overlay. |
| 104 | Foraging trip duration upgrade (Swift Wings) | UNKNOWN | Not named in docs. | Studio: script_grep Swift Wings. |
| 105 | Queen bee capstone propolis upgrade | UNKNOWN | Queen tiers live; capstone not named. | Studio: script_grep capstone. |
| 106 | Pollen surge event (x2 pollen, 2 min) | UNKNOWN | Not named in docs. | Studio: script_grep Pollen Surge. |
| 107 | Upgrade tree visualization | UNKNOWN | Not named in docs. | Studio: check upgrade tree UI. |
| 108 | HiveStats panel auto-resize | UNKNOWN | Not named in docs. | Studio: check HiveStats UI. |
| 109 | Propolis rain event | UNKNOWN | Not named in docs. | Studio: script_grep Propolis Rain. |
| 110 | Idle hive watcher | UNKNOWN | Not named in docs. | Studio: script_grep IdleHive. |
| 111 | Full hive multiplier | UNKNOWN | Not named in docs. | Studio: script_grep FullHive. |
| 112 | Seasonal streak achievement | NOT-STARTED | Depends on seasons layer, which is future per roadmap. | Build after seasons layer exists. |
| 113 | Prestige hive aura | UNKNOWN | Prestige live; aura visual not named. | Studio: search for prestige aura effect. |
| 114 | Comb cell guide (kid-friendly buildable explanations) | BUILT-DOCS-LIVE | buglist #40 FIXED: build palette now explains each cell type. | Confirm it is the same UI in Play. |
| 115 | Comb placement bonus preview tooltip | UNKNOWN | Not named in docs. | Studio: script_grep placement bonus preview. |
| 116 | Hive progress celebration milestone overlay | UNKNOWN | Not named in docs. | Studio: script_grep celebration overlay. |
| 117 | Daily bee facts rotating card | UNKNOWN | Not named in docs. | Studio: script_grep BeeFact. |
| 118 | Hive sound ambience (layered audio) | UNKNOWN | Sound set (24 sounds, SoundGroups) recorded; layered ambience not named. | Studio: count Sound objects and SoundGroups. |
| 119 | Bee roster panel | UNKNOWN | Not named in docs. | Studio: script_grep BeeRoster. |
| 120 | Hive leaderboard | REJECTED-DUPLICATE | Native LeaderboardService and physical board kept (roadmap). | None. |
| 121 | Honey ripeness indicator | UNKNOWN | Ripeness system recorded as built; indicator UI not named. | Studio: script_grep ripeness indicator. |
| 122 | Foraging route quality display | UNKNOWN | Route quality decay is in roadmap; display not named. | Studio: script_grep route quality. |
| 123 | Bear warning system | UNKNOWN | Old Molasses 45-second server-wide warning is recorded in architecture; this UI not named. | Studio: script_grep bear warning. |
| 124 | Seasonal achievements | NOT-STARTED | Depends on seasons layer (future per roadmap). | Build after seasons layer exists. |
| 125 | Stat tracking wires | UNKNOWN | Not named in docs. | Studio: script_grep stat tracking. |
| 126 | Pollen trail VFX | UNKNOWN | Not named in docs. | Studio: script_grep PollenTrail. |
| 127 | Hive health display | UNKNOWN | Not named in docs. | Studio: script_grep HiveHealth. |
| 128 | Comb slot unlock animation | UNKNOWN | Not named in docs. | Studio: script_grep unlock animation. |
| 129 | Honey collection tap feedback | UNKNOWN | Not named in docs. | Studio: script_grep tap feedback. |
| 130 | Daily hive tip | UNKNOWN | Not named in docs. | Studio: script_grep HiveTip. |
| 131 | Milestone celebration | UNKNOWN | Not named in docs. | Studio: script_grep Milestone. |
| 132 | Propolis upgrade shop | UNKNOWN | Propolis upgrades recorded; shop not named. | Studio: script_grep PropolisShop. |
| 133 | Bee speed boost | UNKNOWN | Not named in docs. | Studio: script_grep speed boost. |
| 134 | Royal cell aura | UNKNOWN | Queen aura controller (205) is built; this aura not named. | Studio: script_grep RoyalCell aura. |
| 135 | Honey overflow warning | UNKNOWN | Not named in docs. | Studio: script_grep overflow warning. |
| 136 | Propolis collection VFX | UNKNOWN | Not named in docs. | Studio: script_grep Propolis VFX. |
| 137 | Foraging return countdown timer | UNKNOWN | Not named in docs. | Studio: script_grep countdown. |
| 138 | Adjacency bonus visualizer | UNKNOWN | Adjacency rules in architecture; visualizer not named. | Studio: script_grep Adjacency. |
| 139 | Bear attack warning system (cloud) | UNKNOWN | Same gap as 123. | Studio: script_grep bear warning. |
| 140 | Hive prestige system | BUILT-DOCS-LIVE | Live as SwarmService prestige (buglist #70). | Recheck live. |
| 141 | Bee roster expansion | UNKNOWN | Not named in docs. | Studio: script_grep roster. |
| 142 | Guard bee drain stacking and honey leaderboard | UNKNOWN | Guard perches live; drain stacking not named. | Studio: script_grep GuardBee drain. |
| 143 | Scout and nurse bee service integration | UNKNOWN | Not named in docs. | Studio: script_grep Scout. |
| 144 | HoneyEarned lifetime tracking | UNKNOWN | Lifetime profile field totalHoneyHarvested recorded (Lane A); service name not confirmed. | Studio: script_grep HoneyEarned. |
| 145 | Daily login reward system (cloud) | REJECTED-DUPLICATE | Native RetentionService kept (roadmap). | None. |
| 146 | Hive temperature mechanic | UNKNOWN | Not named in docs. | Studio: script_grep Temperature. |
| 147 | Honey milestone toasts (10 tiers) | UNKNOWN | Milestone visual 233 is blocked on a Honey attribute; toast system not named. | Studio: script_grep milestone toast. |
| 148 | Foraging weather events | BUILT-DOCS-LIVE | Roadmap: weather multipliers wired into ForagingService via TimeService. | Recheck live. |
| 149 | Comb cell upgrade system (Tier 2) | BUILT-DOCS-LIVE | buglist #97 CombService.Upgrade cell-tier system landed and verified. | Recheck live. |
| 150 | Hive population display | UNKNOWN | Not named in docs. | Studio: script_grep population display. |
| 151 | Friend bonus (+10% per friend, cap 3) | UNKNOWN | Not named in docs. | Studio: script_grep FriendBonus. |
| 152 | Hive stats dashboard (queen badge and rate) | UNKNOWN | Not named in docs. | Studio: script_grep HiveStats. |
| 153 | Community hub rework | BUILT-NOT-PLAY-VERIFIED | Hub redo steps 0-6 done (321 parts). Steps 7-8 open. Owner deferred the epic redesign. | Finish hub redo steps 7-8; owner go-ahead for the rest. |
| 154 | Holiday core system | UNKNOWN | Not named in docs. | Studio: script_grep Holiday. |
| 155 | Holiday world transforms | UNKNOWN | Not named in docs. | Studio: check holiday world changes. |
| 156 | Festival meter (shared server goal) | UNKNOWN | Bloom Festival species bonus is recorded; festival meter not named. | Studio: script_grep Festival. |
| 157 | Holiday specialist bees and midnight mechanic | UNKNOWN | Not named in docs. | Studio: script_grep Midnight. |
| 158 | LeaderboardGui top-10 (cloud) | REJECTED-DUPLICATE | Native leaderboard kept (roadmap). | None. |
| 159 | FTUE welcome overlay and tutorial spotlight | REJECTED-DESIGN | Cloud 10-step FTUE rejected as too long (roadmap). | None. |
| 160 | Hive expansion ring-3 unlock for prestige players | UNKNOWN | Not named in docs. | Studio: script_grep ring-3 unlock. |
| 161 | Daily login rewards (cloud) | REJECTED-DUPLICATE | Native RetentionService kept (roadmap). | None. |
| 162 | Honey ripeness showcase and bear warning toast | UNKNOWN | Not named in docs. | Studio: script_grep showcase. |
| 163 | Queen naming ceremony popup | UNKNOWN | Not named in docs. | Studio: script_grep naming ceremony. |
| 164 | Comb cell ghost preview (hover card) | UNKNOWN | Not named in docs. | Studio: script_grep ghost preview. |
| 165 | Weather announce service and HUD | UNKNOWN | Weather is in TimeService; announce service not named. | Studio: script_grep WeatherAnnounce. |
| 166 | Colony health meter | UNKNOWN | Not named in docs. | Studio: script_grep ColonyHealth. |
| 167 | Forager return trail VFX | UNKNOWN | Not named in docs. | Studio: script_grep return trail. |
| 168 | Dynamic hive ambience | UNKNOWN | Not named in docs. | Studio: script_grep ambience. |
| 169 | Population growth sparkline | UNKNOWN | Not named in docs. | Studio: script_grep sparkline. |
| 170 | Plot visitor toast | UNKNOWN | Visitor counter (215) partially built; toast not named. | Studio: script_grep VisitorToast. |
| 171 | Pollen packet VFX burst | UNKNOWN | Not named in docs. | Studio: script_grep PollenPacket. |
| 172 | HoneyBoosterController glow pulse | UNKNOWN | Honey glow controller (204) is a different item; this one not named. | Studio: script_grep HoneyBooster. |
| 173 | Consumable VFX: royal_jelly_flask | UNKNOWN | Not named in docs. | Studio: script_grep royal_jelly_flask. |
| 174 | Consumable VFX: smoker_refill | UNKNOWN | Not named in docs. | Studio: script_grep smoker_refill. |
| 175 | Bee census milestones | UNKNOWN | Not named in docs. | Studio: script_grep census. |
| 176 | Nectar flow rate display | UNKNOWN | Nectar-in-transit state does not exist (roadmap blocked item 208). | Studio: script_grep NectarFlow. |
| 177 | Comb stagnation warning | UNKNOWN | Not named in docs. | Studio: script_grep stagnation. |
| 178 | Foraging zone visualiser | UNKNOWN | Not named in docs. | Studio: script_grep ZoneVisual. |
| 179 | Queen growth progress bar | UNKNOWN | Not named in docs. | Studio: script_grep QueenGrowth. |
| 180 | Cell damage feedback | UNKNOWN | Cell repair mechanic not named in docs. | Studio: script_grep CellDamage. |
| 181 | Prestige echo trail and dance replay ghost | BLOCKED | Dance replay half needs DanceResult to carry bearing and distance (roadmap 202, owner decision). Echo trail not named in docs. | Owner decision on the DanceResult contract change. |
| 182 | Prestige echo trail and dance replay ghost (second half) | BLOCKED | Same as 181. | Same as 181. |
| 183 | Hive temperature gauge | UNKNOWN | Not named in docs. | Studio: script_grep TemperatureGauge. |
| 184 | Wasp directional ping | UNKNOWN | Wasp system live; ping not named. | Studio: script_grep WaspPing. |
| 185 | BearAltarController altar glow and whisper | BLOCKED | No BearAltar-tagged geometry in place (roadmap 227 gap). | Owner or world-builder: add BearAltar tagged parts. |
| 186 | PollenTrailController | UNKNOWN | Not named in docs. | Studio: script_grep PollenTrail. |
| 187 | HoneyRipenessController | UNKNOWN | Ripeness system live; this controller not named. | Studio: script_grep HoneyRipeness. |
| 188 | HubTickerController and WeatherService (cloud) | REJECTED-DUPLICATE | WeatherService rejected (roadmap 216 closed). HubTickerController not named in docs. | Studio: script_grep HubTicker for the ticker half. |
| 189 | HubTickerController and WeatherService (second half) | REJECTED-DUPLICATE | Same as 188. | Same as 188. |
| 190 | Cell repair overlay (hex rim glow, repair cost) | UNKNOWN | Not named in docs. | Studio: script_grep CellRepair. |
| 191 | Queen coronation ceremony | UNKNOWN | Queen tier advance is live; ceremony not named. | Studio: script_grep Coronation. |
| 192 | Weather integration (yield and hatch multipliers) | BUILT-DOCS-LIVE | Yield multiplier wired into ForagingService (roadmap). Hatch multiplier not documented. | Recheck yield live; check hatch multiplier. |
| 193 | Propolis seal Beam ring | UNKNOWN | Propolis seal mechanic live; Beam ring visual not named. | Studio: script_grep PropolisSeal. |
| 194 | Moonflower bloom ceremony (Signature Moment 7) | UNKNOWN | Moonflower Vigil secret is recorded (buglist #96); this server clock ceremony is not named. | Studio: script_grep Moonflower. |
| 195 | Hive warmup ripple and welcome toast | UNKNOWN | Not named in docs. | Studio: script_grep HiveWarmup. |
| 196 | Bee population census (server snapshot) | UNKNOWN | Not named in docs. | Studio: script_grep Census. |
| 197 | Route efficiency star badge | UNKNOWN | Not named in docs. | Studio: script_grep RouteEfficiency. |
| 198 | Route limit pill and cap toasts | UNKNOWN | ExtraRouteSlot gamepass is recorded; pill not named. | Studio: script_grep RouteLimit. |
| 199 | Honey crown on top leader's plot | UNKNOWN | Not named in docs. | Studio: script_grep HoneyCrown. |
| 200 | Hive birthday overlay (sessions 1, 7, 30, 100) | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane A: built; totalHoneyHarvested field added; needs a Play check. | Play-test session milestone. |
| 201 | Pollen sparkle shimmer | BUILT-NOT-PLAY-VERIFIED | Roadmap: built and wired; PollenLevel written at 1 Hz. | Play-test. |
| 202 | Dance replay ghost button | BLOCKED | Needs DanceResult to carry bearing and distance: remote-contract change, owner decision (roadmap). | Owner decision. |
| 203 | Bear patrol ring | BUILT-NOT-PLAY-VERIFIED | State: chunk 1 compiled and wired in ClientMain. | Play-test. |
| 204 | Honey glow (ripeness Neon glow) | BUILT-NOT-PLAY-VERIFIED | State: chunk 1 compiled and wired in ClientMain. | Play-test. |
| 205 | Queen aura crown ring | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane B: built; QueenCell tag added; ClientMain wiring listed as pending (conflicts with state chunk note). | Confirm ClientMain wiring; play-test with a Royal cell. |
| 206 | Brood timer | BLOCKED | No BroodCell tag; hatching is a per-player accumulator, not per cell (roadmap). | Owner decision on per-cell hatch model. |
| 207 | Cell hover tooltip | BUILT-NOT-PLAY-VERIFIED | State: chunk 1 compiled and wired; Model-cell fix in buglist #101. | Play-test hover. |
| 208 | Nectar flow beam scroll | BLOCKED | No nectar-in-transit state in ForagingService (roadmap). | Gameplay decision and state. |
| 209 | Propolis seam pulse | BUILT-NOT-PLAY-VERIFIED | State: chunk 1 compiled and wired. | Play-test. |
| 210 | Harvest beacon above Landing Board | BUILT-NOT-PLAY-VERIFIED | State: chunk 1 compiled and wired. | Play-test. |
| 211 | Population cap warning pill | BUILT-NOT-PLAY-VERIFIED | State: built and wired (CurrentBees/MaxBees exist). | Play-test. |
| 212 | Caste split HUD badge | BUILT-NOT-PLAY-VERIFIED | State: chunk 2 wired; roadmap later says the bee-count bar was removed from ClientMain boot. | Confirm whether it is still wired; decide with owner. |
| 213 | Weather and season HUD badge | REJECTED-DUPLICATE | WeatherService and badge closed as duplicate; existing HUD chip covers it (roadmap). | None. |
| 214 | ResourceService attribute writes | BUILT-DOCS-LIVE | State: attribute-integration pass verified live. | Recheck live. |
| 215 | Plot visitor counter | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane A: built; server counting needs Play; ClientMain wiring pending. | Play-test; wire VisitorCountController. |
| 216 | WeatherService (seasonal cycle) | REJECTED-DUPLICATE | Closed: TimeService already owns weather (roadmap). Seasons remain a future layer inside TimeService. | None for this item. |
| 217 | Daily streak service and streak badge | REJECTED-DUPLICATE | DailyStreakService rejected; RetentionService kept. StreakBadgeController is built but ClientMain wiring pending (roadmap). | Wire StreakBadgeController into ClientMain. |
| 218 | Honey ripeness 2.2x harvest bonus | REJECTED-DESIGN | Doubles existing ripeness bonus; rejected (roadmap). | None. |
| 219 | Bee name tag above heads | REJECTED-DESIGN | Removed from ClientMain boot; roadmap records overhead name and honey tag removed (owner direction). | None unless owner reverses it. |
| 220 | Bear warning vignette and camera rumble | BUILT-NOT-PLAY-VERIFIED | State: chunk 1 compiled and wired. | Play-test. |
| 221 | Threat service attribute broadcast | BUILT-DOCS-LIVE | State: integration pass verified live. | Recheck live. |
| 222 | Population service attribute broadcast | BUILT-DOCS-LIVE | State: integration pass verified live. | Recheck live. |
| 223 | Honey leaderboard cork-board skin | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane A: built, Edit-tested on a fake SurfaceGui only; ClientMain wiring pending. | Wire HoneyLeaderboardBoardSkin; check the real board. |
| 224 | Plot name plaques (owner and tier badge) | BUILT-NOT-PLAY-VERIFIED | Roadmap: tier badge added to existing OwnershipTag (hybrid decision, no separate plaque system). | Play-test visual. |
| 225 | Forager bee trail VFX | BLOCKED | No forager carry state or NectarLoad attribute (roadmap). | Gameplay decision and forager carry attribute. |
| 226 | Honey drip fountain animation | BLOCKED | Fountain model placed in hub (hub steps); HubHoneyFlow attribute not written (roadmap). | Write HubHoneyFlow attribute from the honey system. |
| 227 | Bear altar glow controller | BLOCKED | No BearAltar-tagged geometry (roadmap). | Add BearAltar tagged parts. |
| 228 | Comb cell shimmer | BUILT-NOT-PLAY-VERIFIED | State: built with 237 and 239 and verified compile; roadmap batch 2 lists it as skipped. Conflict. | Confirm tags exist at runtime in Play. |
| 229 | Hive sound pulse | BUILT-NOT-PLAY-VERIFIED | State: chunk 2 built and wired. | Play-test. |
| 230 | Flower bloom controller | BUILT-NOT-PLAY-VERIFIED | State: chunk 2 built and wired. | Play-test. |
| 231 | Patch service attribute writes | BUILT-DOCS-LIVE | State: attribute-integration pass verified live. | Recheck live. |
| 232 | Wasp alert sound sting | BUILT-NOT-PLAY-VERIFIED | State: chunk 2 built and wired. | Play-test. |
| 233 | Honey milestone pop | BLOCKED | Needs a player Honey attribute; wallet vs harvest count is an owner decision (roadmap). | Owner decision. |
| 234 | Plot flag wind animation | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane B: built; ClientMain wiring pending. | Wire PlotFlagWindController; play-test. |
| 235 | Landing board pulse | BUILT-NOT-PLAY-VERIFIED | State: chunk 2 built and wired. | Play-test. |
| 236 | Quest HUD badge | BUILT-NOT-PLAY-VERIFIED | Roadmap: built, moved to top-left column, compiles, not play-verified. | Play-test. |
| 237 | Harvest glow burst | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane B: already existed and wired; uses LastHarvestTime. Roadmap batch 2 lists it as skipped. Conflict. | Play-test harvest. |
| 238 | Bear ritual atmosphere shift | BLOCKED | Needs BearAltar-tagged parts (same gap as 227). | Add BearAltar tagged parts. |
| 239 | Honey cell drip | BUILT-NOT-PLAY-VERIFIED | Roadmap Lane B: already existed and wired; tags set at runtime. Batch 2 lists it as skipped. Conflict. | Play-test near-full honey cells. |

## NOT-STARTED (3)

No evidence it exists.

- 46: SeasonService (Spring/Summer/Autumn/Winter). Roadmap: seasons layer is a future optional feature; no SeasonService in docs.
- 112: Seasonal streak achievement. Depends on seasons layer, which is future per roadmap.
- 124: Seasonal achievements. Depends on seasons layer (future per roadmap).

## BLOCKED (11)

Needs gameplay state or an owner decision.

- 181: Prestige echo trail and dance replay ghost. Dance replay half needs DanceResult to carry bearing and distance (roadmap 202, owner decision). Echo trail not named in docs.
- 182: Prestige echo trail and dance replay ghost (second half). Same as 181.
- 185: BearAltarController altar glow and whisper. No BearAltar-tagged geometry in place (roadmap 227 gap).
- 202: Dance replay ghost button. Needs DanceResult to carry bearing and distance: remote-contract change, owner decision (roadmap).
- 206: Brood timer. No BroodCell tag; hatching is a per-player accumulator, not per cell (roadmap).
- 208: Nectar flow beam scroll. No nectar-in-transit state in ForagingService (roadmap).
- 225: Forager bee trail VFX. No forager carry state or NectarLoad attribute (roadmap).
- 226: Honey drip fountain animation. Fountain model placed in hub (hub steps); HubHoneyFlow attribute not written (roadmap).
- 227: Bear altar glow controller. No BearAltar-tagged geometry (roadmap).
- 233: Honey milestone pop. Needs a player Honey attribute; wallet vs harvest count is an owner decision (roadmap).
- 238: Bear ritual atmosphere shift. Needs BearAltar-tagged parts (same gap as 227).

## UNKNOWN (139)

No doc entry under this name and no live check this run. Settle each with the Studio script_grep in the next step column.

- 20: Threat animation pass. No doc entry under this name. Old Molasses 6-stage arc is recorded as built (roadmap Phase 4).
- 26: Narrative engine and zone triggers. Only one doc mention of NarrativeEngine; not in roadmap.
- 27: Offline progress service. No doc mention of OfflineProgressService.
- 30: Seasonal event (Harvest Festival framework). No SeasonalEventService in docs. Roadmap lists seasons layer as future.
- 31: Wasp difficulty scaling by generation. Wasp raids recorded as built; generation scaling not documented.
- 32: Bee Inspector ReadyCheck overlay. No doc mention of BeeInspector.
- 33: PrestigeRewardService (generation reset rewards). Prestige system is live (#70); reward service not named in docs.
- 36: Queen upgrade VFX burst and sound. Queen system is live; this VFX pass is not named in docs.
- 37: Dance floor periodic event (DanceFloorService). Dance Floor tiers recorded; periodic dance event not documented.
- 38: Achievement trophy pedestals. Achievement service is live; pedestal props not named in docs.
- 39: Notification Center toast history panel. No doc mention of NotificationCenter.
- 40: Bee colour customizer (12 presets, Randomise). No doc mention of BeeColour.
- 42: Hive stats dashboard panel. No doc mention of HiveStatsDashboard.
- 43: Thunderstorm weather event. TimeService states listed as Clear/Breezy/Overcast/Rain/BloomRush; Thunderstorm not listed.
- 44: MiniMapGui hex-grid radar. No doc mention of MiniMap.
- 45: Queen bee custom naming (BeeNaming). No doc mention of BeeNaming.
- 49: HiveExpansionService extra plot slots. Plot expansion slots exist (cost notes in dispatches 86-87); service not named in docs.
- 51: Foraging speed upgrade (5-tier). Upgrades exist; this tier ladder not named in docs.
- 52: Pollen yield upgrade (5-tier). Not named in docs.
- 53: Queen bee capacity upgrade (5-tier). Queen system live; capacity ladder not named in docs.
- 54: Propolis yield upgrade (5-tier). Not named in docs.
- 56: Hive skins (HiveSkinService). No doc mention of HiveSkin.
- 57: Bee visuals and plot owner id patch. Plot owner attribute is inconsistent in docs (roadmap Plot1 OwnerUserId nil in Edit).
- 59: Notification badge red dots. No doc mention of NotificationBadge.
- 60: Honey storage upgrade service. HoneyStored/HoneyCapacity attributes recorded in plumbing batch; service not named.
- 61: Propolis storage upgrade service. Not named in docs.
- 64: Tab layout reflow. No doc mention.
- 66: Pollen storage 3-tier cap. Not named in docs.
- 67: Settings controller (BGM, SFX, quality, tutorial reset). SettingsController mentioned once in docs; features not confirmed.
- 68: Music controller ambient playlist with crossfade. No doc mention of MusicController.
- 69: Seasonal event time-limited multipliers. Same gap as 30; no service named in docs.
- 70: Friend bonus +10% honey per friend. No doc mention of FriendBonus.
- 71: Queen bee naming with chat filter (BeeNameService). Not named in docs (buglist #71 is an unrelated bug number).
- 72: Persistent hive stats panel (HiveStatsService). No doc mention.
- 73: Upgrade count stats patch. No doc mention of totalUpgradesBought.
- 74: Honeycomb visual controller (hex cell states). Hex cells and tags recorded; this controller not named.
- 75: Bee particle controller (flight particles). VFX layer recorded (VfxController); this controller not named.
- 76: AntiCheatService foraging exploit prevention. No doc mention of AntiCheat in live docs.
- 77: 13 new achievements (AchievementsExpansion). Achievement count is 14 in docs; cannot tell which were added here.
- 78: Notification badge controller (HUD tabs). No doc mention.
- 81: PlotService.ResetPlotsForPrestige. Prestige reset is live (#70); this exact function not named.
- 82: PrestigeReadySync condition broadcast. Not named in docs.
- 84: AntiCheat dynamic prestige cap. No doc mention.
- 85: Prestige achievements (levels 1, 3, 5, 10). Achievements live (14); these entries not confirmed.
- 86: Expansion plots 7-8 cost propolis. Not named in docs.
- 87: Plot cost label shows propolis for slots 7-8. Not named in docs.
- 88: Pollen upgrade tree. Not named in docs.
- 89: Propolis upgrade tree (Resin Collectors I-V). Resin to propolis harvesting recorded as built; tree not named.
- 90: Foraging speed tree (Wing Strength I-IV). Not named in docs.
- 91: Bee count tree (Larger Colony I-III). Not named in docs.
- 92: Upgrades panel category tabs. Not named in docs.
- 93: HiveStats upgrade count integration. Not named in docs.
- 94: Prestige leaderboard stars. Not named in docs.
- 96: Sound effects (upgrade purchase, prestige). Sound set recorded (24 sounds); these specific cues not named.
- 97: Seasonal bonus event system. Same gap as 30 and 69.
- 98: Plot unlock notification toast. Not named in docs.
- 99: Foraging return animation (yield pop). Not named in docs.
- 100: Progressive resource caps. Not named in docs.
- 101: Bee count milestone notifications. Not named in docs.
- 102: Hive efficiency rating display. Not named in docs.
- 103: Honeycomb grid visual overlay. Not named in docs.
- 104: Foraging trip duration upgrade (Swift Wings). Not named in docs.
- 105: Queen bee capstone propolis upgrade. Queen tiers live; capstone not named.
- 106: Pollen surge event (x2 pollen, 2 min). Not named in docs.
- 107: Upgrade tree visualization. Not named in docs.
- 108: HiveStats panel auto-resize. Not named in docs.
- 109: Propolis rain event. Not named in docs.
- 110: Idle hive watcher. Not named in docs.
- 111: Full hive multiplier. Not named in docs.
- 113: Prestige hive aura. Prestige live; aura visual not named.
- 115: Comb placement bonus preview tooltip. Not named in docs.
- 116: Hive progress celebration milestone overlay. Not named in docs.
- 117: Daily bee facts rotating card. Not named in docs.
- 118: Hive sound ambience (layered audio). Sound set (24 sounds, SoundGroups) recorded; layered ambience not named.
- 119: Bee roster panel. Not named in docs.
- 121: Honey ripeness indicator. Ripeness system recorded as built; indicator UI not named.
- 122: Foraging route quality display. Route quality decay is in roadmap; display not named.
- 123: Bear warning system. Old Molasses 45-second server-wide warning is recorded in architecture; this UI not named.
- 125: Stat tracking wires. Not named in docs.
- 126: Pollen trail VFX. Not named in docs.
- 127: Hive health display. Not named in docs.
- 128: Comb slot unlock animation. Not named in docs.
- 129: Honey collection tap feedback. Not named in docs.
- 130: Daily hive tip. Not named in docs.
- 131: Milestone celebration. Not named in docs.
- 132: Propolis upgrade shop. Propolis upgrades recorded; shop not named.
- 133: Bee speed boost. Not named in docs.
- 134: Royal cell aura. Queen aura controller (205) is built; this aura not named.
- 135: Honey overflow warning. Not named in docs.
- 136: Propolis collection VFX. Not named in docs.
- 137: Foraging return countdown timer. Not named in docs.
- 138: Adjacency bonus visualizer. Adjacency rules in architecture; visualizer not named.
- 139: Bear attack warning system (cloud). Same gap as 123.
- 141: Bee roster expansion. Not named in docs.
- 142: Guard bee drain stacking and honey leaderboard. Guard perches live; drain stacking not named.
- 143: Scout and nurse bee service integration. Not named in docs.
- 144: HoneyEarned lifetime tracking. Lifetime profile field totalHoneyHarvested recorded (Lane A); service name not confirmed.
- 146: Hive temperature mechanic. Not named in docs.
- 147: Honey milestone toasts (10 tiers). Milestone visual 233 is blocked on a Honey attribute; toast system not named.
- 150: Hive population display. Not named in docs.
- 151: Friend bonus (+10% per friend, cap 3). Not named in docs.
- 152: Hive stats dashboard (queen badge and rate). Not named in docs.
- 154: Holiday core system. Not named in docs.
- 155: Holiday world transforms. Not named in docs.
- 156: Festival meter (shared server goal). Bloom Festival species bonus is recorded; festival meter not named.
- 157: Holiday specialist bees and midnight mechanic. Not named in docs.
- 160: Hive expansion ring-3 unlock for prestige players. Not named in docs.
- 162: Honey ripeness showcase and bear warning toast. Not named in docs.
- 163: Queen naming ceremony popup. Not named in docs.
- 164: Comb cell ghost preview (hover card). Not named in docs.
- 165: Weather announce service and HUD. Weather is in TimeService; announce service not named.
- 166: Colony health meter. Not named in docs.
- 167: Forager return trail VFX. Not named in docs.
- 168: Dynamic hive ambience. Not named in docs.
- 169: Population growth sparkline. Not named in docs.
- 170: Plot visitor toast. Visitor counter (215) partially built; toast not named.
- 171: Pollen packet VFX burst. Not named in docs.
- 172: HoneyBoosterController glow pulse. Honey glow controller (204) is a different item; this one not named.
- 173: Consumable VFX: royal_jelly_flask. Not named in docs.
- 174: Consumable VFX: smoker_refill. Not named in docs.
- 175: Bee census milestones. Not named in docs.
- 176: Nectar flow rate display. Nectar-in-transit state does not exist (roadmap blocked item 208).
- 177: Comb stagnation warning. Not named in docs.
- 178: Foraging zone visualiser. Not named in docs.
- 179: Queen growth progress bar. Not named in docs.
- 180: Cell damage feedback. Cell repair mechanic not named in docs.
- 183: Hive temperature gauge. Not named in docs.
- 184: Wasp directional ping. Wasp system live; ping not named.
- 186: PollenTrailController. Not named in docs.
- 187: HoneyRipenessController. Ripeness system live; this controller not named.
- 190: Cell repair overlay (hex rim glow, repair cost). Not named in docs.
- 191: Queen coronation ceremony. Queen tier advance is live; ceremony not named.
- 193: Propolis seal Beam ring. Propolis seal mechanic live; Beam ring visual not named.
- 194: Moonflower bloom ceremony (Signature Moment 7). Moonflower Vigil secret is recorded (buglist #96); this server clock ceremony is not named.
- 195: Hive warmup ripple and welcome toast. Not named in docs.
- 196: Bee population census (server snapshot). Not named in docs.
- 197: Route efficiency star badge. Not named in docs.
- 198: Route limit pill and cap toasts. ExtraRouteSlot gamepass is recorded; pill not named.
- 199: Honey crown on top leader's plot. Not named in docs.

