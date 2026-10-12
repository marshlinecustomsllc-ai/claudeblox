# Cloud backlog live recheck: A Bee's World

Place 123313915411717. Studio instance af40365e-f70f-439a-b6ef-c779b9b793bf (A Bee's World), Edit mode. Read-only: only execute_luau reads and script_grep-style source scans. No play mode, no edits.

Scope: BUILT-DOCS-LIVE (18), BUILT-NOT-PLAY-VERIFIED (25), UNKNOWN (139), and the six conflicts (205, 212, 219, 228, 237, 239).

Method: one source scan over every LuaSourceContainer (ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui, Workspace, ServerStorage) for the audit's key terms, one named-module scan, a tag and attribute scan, and a ClientMain require and Init scan. "CONFIRMED-LIVE" means the module or controller exists and is required and initialised by ClientMain, or is referenced by a server script. It does not mean play-tested. Edit mode cannot show runtime-only tags or attributes, which are marked where they matter.

## Counts (of 182 rows)

| Result | Count |
|---|---|
| CONFIRMED-LIVE | 0 |
| MISSING | 0 |
| NOT-WIRED | 0 |
| FOUND-LIVE | 0 |
| NOT-FOUND | 0 |
| AMBIGUOUS | 0 |

Counts are filled in below after the table.

## Conflicts resolved

- **205 Queen aura crown ring**: resolved as WIRED. QueenAuraController exists and ClientMain requires it and calls Init. The roadmap note "ClientMain wiring pending" is stale. QueenCell tags: 0 in Edit (runtime-only).
- **212 Caste split HUD badge**: resolved as NOT-WIRED. CasteBadgeController exists in Controllers, but ClientMain does not require or boot it. The bee-count bar removal is a separate fact.
- **219 Bee name tag above heads**: resolved as NOT-WIRED, consistent with REJECTED-DESIGN. BeeNameTagController exists, and a ClientMain comment says it is intentionally not booted.
- **228 Comb cell shimmer**: resolved as WIRED. CombShimmerController is required and Init'd. HoneyCell and BroodCell tags: 0 in Edit, so the shimmer depends on runtime tagging.
- **237 Harvest glow burst**: resolved as WIRED. HarvestGlowController is required and Init'd.
- **239 Honey cell drip**: resolved as WIRED. HoneyCellDripController is required and Init'd. HoneyCell tags: 0 in Edit (runtime-only).

## Other findings the owner should know

- SeasonController exists and is booted by ClientMain. It shows a season label and tints GrassTuft parts. TimeService writes a Season attribute to Lighting. So a seasons visual layer is live, while SeasonService (item 46) is still not present. Item 46 stays NOT-STARTED as a service, but the docs' "no seasons layer" statement is not accurate.
- StreakBadgeController (217), VisitorCountController (215), PlotFlagWindController (234), HoneyLeaderboardBoardSkin (223), and FinishLightController are all Init'd in ClientMain. The roadmap's "wiring pending" notes for these are stale.
- Config.ACHIEVEMENTS has 15 entries. The docs say 14.
- Thunderstorm does not exist. TimeService weather states are Clear, Breezy, Overcast, Rain, BloomRush.
- DanceReplayController exists but is not required by ClientMain (items 181, 202 are BLOCKED anyway).
- Plots: only Plot1 to Plot6 exist in Workspace.Map.Plots. Plots 7 and 8 do not exist.
- Tags: NarrativeTrigger 0, QueenCell 0, BroodCell 0, HoneyCell 0, BearAltar 0, VFXAnchor 0. Enemy 2, CombCell 6.
- Workspace: 62 lights, 15 sounds, 1 ParticleEmitter, 2 SoundGroups. The Workspace holds only the one emitter, so the VFX layer is not in place in this Edit scene.

## Table

| # | Name | Prior category | Result | Evidence |
|---|---|---|---|---|
| 21 | Swarm prestige (SwarmService) | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.SwarmService |
| 22 | Bee cosmetics (CosmeticService) | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.CosmeticService (WardrobeGui not checked) |
| 25 | Achievements (AchievementService) | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.AchievementService; Config.ACHIEVEMENTS = 15 entries (docs say 14) |
| 28 | Floors tab (FloorProgressGui) | BUILT-DOCS-LIVE | AMBIGUOUS | FloorProgressGui not searched by name |
| 34 | Leaderboard OrderedDataStore | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.LeaderboardService (OrderedDataStore use not grepped) |
| 35 | TutorialService 4-step | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.TutorialService; StarterPlayerScripts.Controllers.TutorialController required and Init'd |
| 41 | 7-day login calendar | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.RetentionService (calendar logic not grepped) |
| 58 | Prestige rebirth | BUILT-DOCS-LIVE | CONFIRMED-LIVE | Prestige lives in ServerScriptService.Systems.SwarmService; no separate PrestigeService |
| 79 | Prestige rebirth (Cycle 12) | BUILT-DOCS-LIVE | CONFIRMED-LIVE | Same as 58 |
| 114 | Comb cell guide | BUILT-DOCS-LIVE | AMBIGUOUS | Build palette UI not located by name |
| 140 | Hive prestige | BUILT-DOCS-LIVE | CONFIRMED-LIVE | Same as 58 |
| 148 | Foraging weather events | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.ForagingService references Weather; TimeService holds the weather states |
| 149 | Comb cell upgrade (Tier 2) | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.CombService (Upgrade function not grepped) |
| 192 | Weather yield and hatch multipliers | BUILT-DOCS-LIVE | AMBIGUOUS | ForagingService references Weather (yield plausible); hatch multiplier not found |
| 214 | ResourceService attribute writes | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.ResourceService |
| 221 | Threat attribute broadcast | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.ThreatService |
| 222 | Population attribute broadcast | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.PopulationService |
| 231 | Patch attribute writes | BUILT-DOCS-LIVE | CONFIRMED-LIVE | ServerScriptService.Systems.PatchService |
| 29 | Monetization gamepass wiring | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | ServerScriptService.Systems.MonetizationService and StarterPlayerScripts.Controllers.MonetizationController exist (real pass IDs not checked) |
| 153 | Community hub rework | BUILT-NOT-PLAY-VERIFIED | AMBIGUOUS | Workspace.Hub exists; redo steps 7-8 not checked |
| 200 | Hive birthday overlay | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | StarterPlayerScripts.Controllers.HiveBirthdayController required and Init'd in ClientMain |
| 201 | Pollen sparkle shimmer | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.PollenSparkleController Init'd; PollenLevel attribute not on any instance in Edit (runtime) |
| 203 | Bear patrol ring | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.BearPatrolRingController Init'd |
| 204 | Honey glow | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.HoneyGlowController Init'd |
| 205 | Queen aura crown ring | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.QueenAuraController required and Init'd; QueenCell tag 0 in Edit (see conflicts) |
| 207 | Cell hover tooltip | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.CellHoverController Init'd |
| 209 | Propolis seam pulse | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.PropolisPulseController Init'd |
| 210 | Harvest beacon | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.HarvestBeaconController Init'd |
| 211 | Population cap pill | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.PopCapController Init'd; CurrentBees and MaxBees attributes not on instances in Edit |
| 212 | Caste split HUD badge | BUILT-NOT-PLAY-VERIFIED | NOT-WIRED | Controllers.CasteBadgeController exists; not required or booted by ClientMain |
| 215 | Plot visitor counter | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.VisitorCountController Init'd; ServerScriptService.Systems.PlotVisitorService exists |
| 220 | Bear warning vignette | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.BearWarningController Init'd |
| 223 | Honey leaderboard cork skin | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.HoneyLeaderboardBoardSkin Init'd |
| 224 | Plot name plaques | BUILT-NOT-PLAY-VERIFIED | AMBIGUOUS | PlotRoot OwnerUserId attributes present on Plot1 and Plot2; tier badge code not located |
| 228 | Comb cell shimmer | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.CombShimmerController required and Init'd; HoneyCell and BroodCell tags 0 in Edit (see conflicts) |
| 229 | Hive sound pulse | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.HiveSoundPulseController Init'd |
| 230 | Flower bloom | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.FlowerBloomController Init'd |
| 232 | Wasp alert sting | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.WaspAlertSoundController Init'd |
| 234 | Plot flag wind | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.PlotFlagWindController Init'd (roadmap "pending" is stale) |
| 235 | Landing board pulse | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.LandingBoardPulseController Init'd |
| 236 | Quest HUD badge | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.QuestHudBadge Init'd |
| 237 | Harvest glow burst | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.HarvestGlowController Init'd (see conflicts) |
| 239 | Honey cell drip | BUILT-NOT-PLAY-VERIFIED | CONFIRMED-LIVE | Controllers.HoneyCellDripController Init'd; HoneyCell tags 0 in Edit (see conflicts) |
| 20 | Threat animation pass | UNKNOWN | AMBIGUOUS | ServerScriptService.Systems.MolassesAI and ThreatService exist; animation code not searched |
| 26 | Narrative engine and zone triggers | UNKNOWN | NOT-FOUND | No NarrativeEngine in any script; NarrativeTrigger tag count 0 |
| 27 | Offline progress service | UNKNOWN | NOT-FOUND | No OfflineProgress in any script |
| 30 | Seasonal event (Harvest Festival) | UNKNOWN | AMBIGUOUS | SeasonController is live (label and GrassTuft tint); TimeService Season attribute; no SeasonalEvent service or festival multiplier found |
| 31 | Wasp generation scaling | UNKNOWN | AMBIGUOUS | Wasp code in 7 scripts; no WaspService module; generation scaling not searched |
| 32 | Bee Inspector ReadyCheck | UNKNOWN | NOT-FOUND | No BeeInspector in any script |
| 33 | PrestigeRewardService | UNKNOWN | NOT-FOUND | No PrestigeReward in any script |
| 36 | Queen upgrade VFX burst | UNKNOWN | AMBIGUOUS | QueenUpgrade term in 4 scripts; VFX not checked |
| 37 | Dance floor periodic event | UNKNOWN | AMBIGUOUS | DanceService exists; periodic event not searched |
| 38 | Achievement trophy pedestals | UNKNOWN | NOT-FOUND | Only WardrobePedestal and LandingBoard models in Workspace; no trophy models |
| 39 | Notification Center | UNKNOWN | NOT-FOUND | No NotificationCenter in any script |
| 40 | Bee colour customizer | UNKNOWN | NOT-FOUND | No BeeColour in any script |
| 42 | Hive stats dashboard panel | UNKNOWN | NOT-FOUND | No HiveStatsDashboard in any script |
| 43 | Thunderstorm weather | UNKNOWN | NOT-FOUND | 0 hits; TimeService states are Clear, Breezy, Overcast, Rain, BloomRush |
| 44 | MiniMap radar | UNKNOWN | NOT-FOUND | No MiniMap in any script |
| 45 | Queen bee naming (BeeNaming) | UNKNOWN | NOT-FOUND | No BeeNaming in any script |
| 49 | HiveExpansionService | UNKNOWN | NOT-FOUND | No HiveExpansion in any script |
| 51 | Foraging speed upgrade tiers | UNKNOWN | NOT-FOUND | No SpeedUpgrade in any script |
| 52 | Pollen yield upgrade tiers | UNKNOWN | NOT-FOUND | No PollenYield in any script |
| 53 | Queen capacity upgrade tiers | UNKNOWN | AMBIGUOUS | QueenUpgrade in 4 scripts; capacity ladder not checked |
| 54 | Propolis yield upgrade tiers | UNKNOWN | NOT-FOUND | No PropolisYield in any script |
| 56 | Hive skins (HiveSkinService) | UNKNOWN | NOT-FOUND | No HiveSkin in any script |
| 57 | Bee visuals and plot owner id | UNKNOWN | AMBIGUOUS | OwnerUserId attribute on Plot1 and Plot2 PlotRoot; BeeVisualService not found |
| 59 | Notification red dots | UNKNOWN | NOT-FOUND | No NotificationBadge in any script |
| 60 | Honey storage upgrade | UNKNOWN | NOT-FOUND | No HoneyStorage; HoneyStored and HoneyCapacity attributes absent in Edit |
| 61 | Propolis storage upgrade | UNKNOWN | NOT-FOUND | No PropolisStorage in any script |
| 64 | Tab layout reflow | UNKNOWN | AMBIGUOUS | StarterGui layout not inspected |
| 66 | Pollen storage 3-tier cap | UNKNOWN | NOT-FOUND | No PollenStorage in any script |
| 67 | Settings controller | UNKNOWN | NOT-FOUND | No SettingsController module in any script |
| 68 | Music controller playlist | UNKNOWN | NOT-FOUND | No MusicController module in any script |
| 69 | Seasonal time-limited multipliers | UNKNOWN | AMBIGUOUS | Same as 30 |
| 70 | Friend bonus +10% | UNKNOWN | NOT-FOUND | No FriendBonus in any script |
| 71 | BeeNameService chat filter | UNKNOWN | NOT-FOUND | No BeeNameService module |
| 72 | HiveStatsService panel | UNKNOWN | NOT-FOUND | No HiveStatsService module |
| 73 | totalUpgradesBought stat | UNKNOWN | NOT-FOUND | No totalUpgradesBought in any script |
| 74 | Honeycomb visual controller | UNKNOWN | NOT-FOUND | No HoneycombVisual module |
| 75 | BeeParticleController | UNKNOWN | NOT-FOUND | No BeeParticleController module |
| 76 | AntiCheatService | UNKNOWN | NOT-FOUND | No AntiCheat in any script |
| 77 | 13 new achievements | UNKNOWN | AMBIGUOUS | Config.ACHIEVEMENTS has 15 entries; cannot tell which came from this brief |
| 78 | Notification badge controller | UNKNOWN | NOT-FOUND | No NotificationBadgeController module |
| 81 | PlotService.ResetPlotsForPrestige | UNKNOWN | NOT-FOUND | No ResetPlotsForPrestige in any script |
| 82 | PrestigeReadySync broadcast | UNKNOWN | NOT-FOUND | No PrestigeReadySync in any script |
| 84 | AntiCheat prestige cap | UNKNOWN | NOT-FOUND | No AntiCheat in any script |
| 85 | Prestige achievements (1, 3, 5, 10) | UNKNOWN | AMBIGUOUS | Config.ACHIEVEMENTS has 15 entries; names not checked |
| 86 | Plots 7-8 propolis cost | UNKNOWN | NOT-FOUND | Only Plot1 to Plot6 exist in Workspace.Map.Plots |
| 87 | Slots 7-8 cost label | UNKNOWN | NOT-FOUND | Only Plot1 to Plot6 exist |
| 88 | Pollen upgrade tree | UNKNOWN | NOT-FOUND | No Pollen upgrade tree term in any script |
| 89 | Resin Collectors tree | UNKNOWN | NOT-FOUND | "Resin Collectors" 0 hits |
| 90 | Wing Strength tree | UNKNOWN | NOT-FOUND | "Wing Strength" 0 hits |
| 91 | Larger Colony tree | UNKNOWN | NOT-FOUND | "Larger Colony" 0 hits |
| 92 | Upgrades panel category tabs | UNKNOWN | AMBIGUOUS | Not searched |
| 93 | HiveStats upgrade count | UNKNOWN | NOT-FOUND | totalUpgradesBought 0 hits; no HiveStats module |
| 94 | Prestige leaderboard stars | UNKNOWN | NOT-FOUND | "stars" 0 hits |
| 96 | Upgrade and prestige sound cues | UNKNOWN | AMBIGUOUS | 15 Sound objects and 2 SoundGroups in Workspace; cues not named |
| 97 | Seasonal bonus event system | UNKNOWN | AMBIGUOUS | Same as 30 |
| 98 | Plot unlock toast | UNKNOWN | AMBIGUOUS | Not searched |
| 99 | Yield pop | UNKNOWN | AMBIGUOUS | Not searched |
| 100 | Progressive resource caps | UNKNOWN | AMBIGUOUS | Not searched |
| 101 | Bee count milestone notifications | UNKNOWN | AMBIGUOUS | "milestone" generic hits only |
| 102 | Efficiency rating display | UNKNOWN | AMBIGUOUS | "rating" generic hits only |
| 103 | Honeycomb grid overlay | UNKNOWN | AMBIGUOUS | Not searched |
| 104 | Swift Wings trip duration | UNKNOWN | NOT-FOUND | "Swift" 0 hits |
| 105 | Queen capstone | UNKNOWN | AMBIGUOUS | "capstone" 1 hit, unverified |
| 106 | Pollen Surge event | UNKNOWN | NOT-FOUND | "Pollen Surge" 0 hits |
| 107 | Upgrade tree visualization | UNKNOWN | AMBIGUOUS | Not searched |
| 108 | HiveStats auto-resize | UNKNOWN | NOT-FOUND | No HiveStats module |
| 109 | Propolis rain event | UNKNOWN | NOT-FOUND | 0 hits |
| 110 | Idle hive watcher | UNKNOWN | NOT-FOUND | IdleHive 0 hits |
| 111 | Full hive multiplier | UNKNOWN | NOT-FOUND | FullHive 0 hits |
| 113 | Prestige hive aura | UNKNOWN | AMBIGUOUS | "aura" 1 hit, unverified |
| 115 | Placement bonus preview | UNKNOWN | AMBIGUOUS | Not searched |
| 116 | Celebration overlay | UNKNOWN | AMBIGUOUS | "celebrat" 2 hits, unverified |
| 117 | Daily bee facts card | UNKNOWN | AMBIGUOUS | "BeeFact" not searched |
| 118 | Hive ambience layers | UNKNOWN | AMBIGUOUS | "Ambience" 1 hit, unverified |
| 119 | Bee roster panel | UNKNOWN | NOT-FOUND | "Roster" 0 hits |
| 121 | Honey ripeness indicator | UNKNOWN | AMBIGUOUS | Ripeness generic hits; indicator not named |
| 122 | Route quality display | UNKNOWN | AMBIGUOUS | Not searched |
| 123 | Bear warning system | UNKNOWN | FOUND-LIVE | Controllers.BearWarningController Init'd; ThreatService references BearWarning |
| 125 | Stat tracking wires | UNKNOWN | AMBIGUOUS | "stat" generic hits only |
| 126 | Pollen trail VFX | UNKNOWN | NOT-FOUND | PollenTrail 0 hits |
| 127 | Hive health display | UNKNOWN | NOT-FOUND | HiveHealth 0 hits |
| 128 | Comb slot unlock animation | UNKNOWN | AMBIGUOUS | Not searched |
| 129 | Honey tap feedback | UNKNOWN | AMBIGUOUS | Not searched |
| 130 | Daily hive tip | UNKNOWN | NOT-FOUND | HiveTip 0 hits (generic "tip" only) |
| 131 | Milestone celebration | UNKNOWN | AMBIGUOUS | HoneyMilestoneController Init'd; celebration not confirmed |
| 132 | Propolis upgrade shop | UNKNOWN | NOT-FOUND | PropolisShop 0 hits |
| 133 | Bee speed boost | UNKNOWN | AMBIGUOUS | Not searched |
| 134 | Royal cell aura | UNKNOWN | AMBIGUOUS | Probably QueenAuraController (see 205); not confirmed |
| 135 | Honey overflow warning | UNKNOWN | AMBIGUOUS | "overflow" 1 hit, unverified |
| 136 | Propolis collection VFX | UNKNOWN | AMBIGUOUS | Not searched |
| 137 | Return countdown timer | UNKNOWN | AMBIGUOUS | "countdown" 2 hits, unverified |
| 138 | Adjacency bonus visualizer | UNKNOWN | AMBIGUOUS | Adjacency logic present; visualizer not named |
| 139 | Bear attack warning (cloud) | UNKNOWN | FOUND-LIVE | Same system as 123 |
| 141 | Bee roster expansion | UNKNOWN | NOT-FOUND | Roster 0 hits |
| 142 | Guard bee drain stacking | UNKNOWN | AMBIGUOUS | GuardBee referenced in VfxController; drain not searched |
| 143 | Scout and nurse services | UNKNOWN | AMBIGUOUS | Not searched |
| 144 | HoneyEarned lifetime tracking | UNKNOWN | NOT-FOUND | HoneyEarned 0 hits |
| 146 | Hive temperature mechanic | UNKNOWN | NOT-FOUND | Temperature 0 hits |
| 147 | Honey milestone toasts | UNKNOWN | AMBIGUOUS | HoneyMilestoneController Init'd; 10-tier toasts not confirmed |
| 150 | Hive population display | UNKNOWN | AMBIGUOUS | Not searched |
| 151 | Friend bonus (cap 3) | UNKNOWN | NOT-FOUND | FriendBonus 0 hits |
| 152 | Hive stats dashboard (queen badge) | UNKNOWN | NOT-FOUND | No HiveStats module |
| 154 | Holiday core system | UNKNOWN | NOT-FOUND | Holiday 0 hits |
| 155 | Holiday world transforms | UNKNOWN | NOT-FOUND | Holiday 0 hits |
| 156 | Festival meter | UNKNOWN | AMBIGUOUS | "Festival" in Config, ForagingService, RetentionService; meter not searched |
| 157 | Midnight mechanic | UNKNOWN | AMBIGUOUS | "Midnight" 0 hits; lowercase "midnight" 3 hits, unverified |
| 160 | Ring-3 unlock for prestige | UNKNOWN | AMBIGUOUS | Not searched |
| 162 | Showcase and bear warning toast | UNKNOWN | AMBIGUOUS | Not searched |
| 163 | Queen naming ceremony | UNKNOWN | NOT-FOUND | "Ceremony" 0 hits |
| 164 | Comb ghost preview | UNKNOWN | AMBIGUOUS | "ghost" 1 hit, unverified |
| 165 | Weather announce service | UNKNOWN | AMBIGUOUS | Weather in HudController and HubBellController; no WeatherAnnounce module |
| 166 | Colony health meter | UNKNOWN | AMBIGUOUS | Not searched |
| 167 | Forager return trail VFX | UNKNOWN | AMBIGUOUS | Not searched |
| 168 | Dynamic hive ambience | UNKNOWN | AMBIGUOUS | Same as 118 |
| 169 | Population sparkline | UNKNOWN | NOT-FOUND | Sparkline 0 hits |
| 170 | Plot visitor toast | UNKNOWN | AMBIGUOUS | VisitorCountController Init'd; toast not named |
| 171 | Pollen packet VFX burst | UNKNOWN | NOT-FOUND | PollenPacket 0 hits |
| 172 | HoneyBoosterController | UNKNOWN | NOT-FOUND | No HoneyBooster module |
| 173 | royal_jelly_flask VFX | UNKNOWN | NOT-FOUND | royal_jelly 0 hits |
| 174 | smoker_refill VFX | UNKNOWN | NOT-FOUND | smoker_refill 0 hits |
| 175 | Bee census milestones | UNKNOWN | NOT-FOUND | Census 0 hits |
| 176 | Nectar flow rate | UNKNOWN | NOT-FOUND | NectarFlow 0 hits; NectarLoad attribute absent |
| 177 | Comb stagnation warning | UNKNOWN | NOT-FOUND | stagnation 0 hits |
| 178 | Foraging zone visualiser | UNKNOWN | NOT-FOUND | ZoneVisual 0 hits |
| 179 | Queen growth progress bar | UNKNOWN | AMBIGUOUS | QueenGrowth referenced in QueenService, QueenController, ClientMain; bar not confirmed |
| 180 | Cell damage feedback | UNKNOWN | NOT-FOUND | CellDamage 0 hits |
| 183 | Hive temperature gauge | UNKNOWN | NOT-FOUND | TemperatureGauge not present (Temperature 0 hits) |
| 184 | Wasp directional ping | UNKNOWN | NOT-FOUND | WaspPing 0 hits |
| 186 | PollenTrailController | UNKNOWN | NOT-FOUND | No PollenTrailController module |
| 187 | HoneyRipenessController | UNKNOWN | NOT-FOUND | No module by that name; ripeness glow is HoneyGlowController (204) |
| 190 | Cell repair overlay | UNKNOWN | NOT-FOUND | CellRepair 0 hits |
| 191 | Queen coronation | UNKNOWN | NOT-FOUND | Coronation 0 hits |
| 193 | Propolis seal Beam ring | UNKNOWN | NOT-FOUND | PropolisSeal 0 hits |
| 194 | Moonflower bloom ceremony | UNKNOWN | AMBIGUOUS | Moonflower in 6 scripts; ceremony 0 hits |
| 195 | Hive warmup ripple | UNKNOWN | NOT-FOUND | HiveWarmup and Warmup 0 hits |
| 196 | Bee population census | UNKNOWN | NOT-FOUND | Census 0 hits |
| 197 | Route efficiency star | UNKNOWN | NOT-FOUND | RouteEfficiency 0 hits; "stars" 0 |
| 198 | Route limit pill | UNKNOWN | NOT-FOUND | RouteLimit 0 hits |
| 199 | Honey crown on leader plot | UNKNOWN | NOT-FOUND | HoneyCrown 0 hits |

## Result counts

Filled from the table above. Totals: 182 rows (18 + 25 + 139).

| Result | Count |
|---|---|
| CONFIRMED-LIVE | 37 |
| NOT-WIRED | 1 |
| MISSING | 0 |
| FOUND-LIVE | 2 |
| NOT-FOUND | 60 |
| AMBIGUOUS | 82 |

Built categories:
- BUILT-DOCS-LIVE (18): CONFIRMED-LIVE 15, AMBIGUOUS 3.
- BUILT-NOT-PLAY-VERIFIED (25): CONFIRMED-LIVE 22, NOT-WIRED 1 (212), AMBIGUOUS 2 (153, 224).
- UNKNOWN (139): FOUND-LIVE 2 (123, 139), NOT-FOUND 60, AMBIGUOUS 77.

Note on AMBIGUOUS: many are items whose key term was generic or not searched in this pass. They are not evidence of absence. A targeted second search per item would settle them.

## NOT-FOUND items: most likely reason

Most are features the docs never named, so no code was written for them. The ones that look planned but missing:
- Narrative engine (26), Thunderstorm (43), Bee Inspector (32), PrestigeReward (33), HiveStatsDashboard (42), MiniMap (44), BeeNaming (45), Settings and Music controllers (67, 68), FriendBonus (70, 151), AntiCheat (76, 84), NotificationCenter and badges (39, 59, 78), Holiday (154, 155), Pollen Surge and Propolis Rain (106, 109).
- Upgrade trees and tiers (51, 52, 54, 88 to 91, 104): no tier names or upgrade keys match.
- Plots 7 and 8 (86, 87): only six plots exist.
- Reasons are most likely scope cuts in the cloud dispatch or features still in the roadmap's future list.
