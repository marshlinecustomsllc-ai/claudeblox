# Cloud backlog batch proposal: A Bee's World

Place 123313915411717. Prepared 2026-10-03. READ ONLY: no Studio changes, no game changes.
Sources: cloud_backlog_audit.md, cloud_backlog_live_recheck.md, roadmap.md (overlap decisions, cloud system decisions, fun and engagement decisions, live recheck).

## What is in scope

- NOT-FOUND in the live recheck: 82 items (all from the UNKNOWN group).
- NOT-STARTED from the audit: 3 items (46, 112, 124).
- AMBIGUOUS in the live recheck: 55 items. The key term was too generic or was never searched, so they are NOT yet proven absent. They are not batched. See "Pending searches".
- Already built or wired (not in this proposal): 43 BUILT items plus FOUND-LIVE 123 and 139.
- Already rejected or blocked by the audit (removed up front): 20 REJECTED-DUPLICATE, 4 REJECTED-DESIGN, 11 BLOCKED.

## Summary

| Group | Items (merged) | Raw numbers |
|---|---|---|
| Batch 1 (kid-friendly, low risk) | 10 | 11 |
| Batch 2 (kid and family, low-medium risk) | 10 | 12 |
| Batch 3 (adult-facing and larger systems) | 9 | 17 |
| Held (need a spec or a target check first) | 4 | 4 |
| Excluded from the 82 NOT-FOUND | - | 38 |
| Total NOT-FOUND accounted for | - | 82 |

Each batch item may merge duplicate cloud dispatches (listed in the Numbers column), so "items" is a count of distinct features.

## Batch 1 (recommended)

Why Batch 1: every item is small or medium, visible to young players, and sits on a system already live in the place (queen tier, population attributes, prestige, ExtraRouteSlot, propolis seal, leaderboard). None changes the economy, adds a new gameplay state, or needs new assets. The work is mostly visual and UI, so the risk is budget and duplication, not game balance.

Caveat: the recheck was Edit mode only. Each item still needs a Play check before it is called done.

| # | Numbers | Name | What it adds | Main risk | Size |
|---|---|---|---|---|---|
| 1 | 195 | Hive warmup ripple and welcome toast | A ripple and welcome message on first landing in the hive. | Low: tween and UI only. | S |
| 2 | 130 | Daily hive tip | One rotating plain-words tip per day. | Low: text only; match tutorial wording. | S |
| 3 | 175, 196 | Bee census milestones | Toast and sound at population milestones (for example 10, 25, 50 bees). | Low: reads live PopulationService attributes. | S |
| 4 | 191 | Queen coronation ceremony | Short, skippable flourish when the queen advances a tier. | Medium: must not block play. | M |
| 5 | 171 | Pollen packet VFX burst | A gold burst when a pollen packet is collected. | Budget: one burst emitter, within the 80/sec cap. | S |
| 6 | 193 | Propolis seal beam ring | A glowing beam ring when a propolis seal is set. | Budget: Beam needs two Attachments. | S |
| 7 | 198 | Route limit pill and cap toasts | Shows routes in use and a toast at the cap. | Low: ExtraRouteSlot live. HUD space on phones. | S |
| 8 | 94 | Prestige leaderboard stars | Prestige stars beside names on the board. | Duplicate: must read the native LeaderboardService. | S |
| 9 | 199 | Honey crown on top leader's plot | A crown on the current top-ranked plot. | Duplicate and tie rule: reads the native leaderboard. | M |
| 10 | 67 | Settings panel (music, sound, quality, tutorial reset) | Toggles for music and sound, quality, and replay tutorial. | Low risk, high value for parents. Only the tutorial flag touches saved data. | M |

## Batch 2 (kid and family, low-medium risk)

| # | Numbers | Name | What it adds | Main risk | Size |
|---|---|---|---|---|---|
| 11 | 169 | Population growth sparkline | Small line graph of bee count this session. | Low: reads PopulationService. | S |
| 12 | 178 | Foraging zone visualiser | Soft coloured ground zones for foraging areas. | Map clutter; check the hub redo layout. | M |
| 13 | 184 | Wasp directional ping | Gentle arrow pointing toward a wasp raid. | Design: must not scare young players. Make it optional. | S |
| 14 | 38 | Achievement trophy pedestals | Trophy models in the hub for earned achievements. | Budget: hub is at 321 of 380 parts. Hub redo steps 7-8 open. | M |
| 15 | 68 | Music controller (ambient playlist, crossfade) | Crossfading ambient music per area. | Licensed audio IDs needed. Overlaps the 15 world sounds. | M |
| 16 | 126, 186 | Pollen trail VFX | Faint pollen trail behind a flying bee. | Emitter budget. Extend VfxController; do not add a second controller. | M |
| 17 | 40 | Bee colour customizer | 12 colour presets with randomise. | Duplicate: CosmeticService has 7 skins and WardrobeGui. Extend it instead. | M |
| 18 | 119 | Bee roster panel | Panel listing each bee and its role. | UI space. Blocks roster expansion (141), which is held. | M |
| 19 | 59, 78 | Notification badge red dots | Red dot on HUD tabs when something is new. | Check overlap with QuestHudBadge. | S |
| 20 | 177 | Comb stagnation warning | Gentle prompt when a cell sits unused for a long time. | Nagging risk; keep optional. | S |

## Batch 3 (adult-facing and larger systems)

| # | Numbers | Name | What it adds | Main risk | Size |
|---|---|---|---|---|---|
| 21 | 42, 72, 152 | Hive stats dashboard | One panel for honey, population, rate and queen badge. | Stats duplicate the HUD and hub board. Pick one source. | L |
| 22 | 73 | Upgrade count stats | Total upgrades bought, shown on the stats panel. | Needs a new profile field. Feeds item 21. | S |
| 23 | 39 | Notification Center | Toast history panel to re-read recent messages. | Overlaps the existing toast system. | M |
| 24 | 45, 71, 163 | Queen bee naming (with chat filter and ceremony) | Players name their queen; name is filtered before display. | Child-safety: needs TextService filtering and a moderation policy. Owner decision. | L |
| 25 | 154, 155 | Holiday system | Time-limited holiday hub decorations and special bees. | New content; hub overlap; time-limited design decision. | L |
| 26 | 49, 86, 87 | Extra plot slots (plots 7-8) | Two more plots unlockable for propolis. | Only plots 1-6 exist. Conflicts with hub redo. Cost decision needed. | L |
| 27 | 44 | MiniMap radar | Small hex-grid minimap of plots and routes. | Mobile HUD space. May overlap item 12. | L |
| 28 | 26 | Narrative engine and zone triggers | Short story fragments when entering areas. | New client system. Genre fit doubtful for a bee game. | L |
| 29 | 76, 84 | AntiCheat foraging and prestige cap | Server checks against foraging exploits and capped prestige gains. | Large, but important before publish. Changes server economy; needs a test pass. | L |

## Held (need a check before proposing)

- 32 Bee Inspector ReadyCheck: no spec in the audit. Read its brief first.
- 173 royal_jelly_flask VFX and 174 smoker_refill VFX: the consumable items were not found in code. Confirm they exist.
- 197 Route efficiency star badge: depends on a route-quality rule (item 122 is unresolved).

## Excluded from the 82 NOT-FOUND (38 numbers)

Duplicate of an existing or built system (8):
- 56 Hive skins: overlaps CosmeticService.
- 74 Honeycomb visual controller: overlaps built cell visuals (207, 228, 239).
- 75 Bee particle controller: overlaps VfxController and PollenSparkle (201).
- 81 ResetPlotsForPrestige and 82 PrestigeReadySync: prestige reset is already live (21, 58).
- 172 HoneyBoosterController and 187 HoneyRipenessController: overlap HoneyGlowController (204).
- 144 HoneyEarned tracking: totalHoneyHarvested already added (Lane A).

Economy or gameplay decision needed (22):
- 27 Offline progress; 33 Prestige reward service; 43 Thunderstorm (roadmap keeps TimeService weather states as they are).
- Upgrade ladders and trees: 51, 52, 54, 88, 89, 90, 91, 104, 132.
- Storage caps: 60, 61, 66.
- Friend bonus: 70 and 151 (also needs friends-data and privacy review).
- Events and multipliers: 106 Pollen Surge, 109 Propolis rain, 110 Idle hive watcher, 111 Full hive multiplier.
- 127 Hive health (no colony-health definition).

Missing gameplay state (5):
- 146 Hive temperature and 183 temperature gauge (depends on 146).
- 176 Nectar flow rate (blocked on nectar-in-transit state; same as blocked item 208).
- 180 Cell damage feedback and 190 Cell repair overlay (no repair mechanic exists).

Dependent on an excluded or held item (3):
- 93 upgrade count integration and 108 stats auto-resize (depend on 42 and 73; 42 is in Batch 3, so these can be added after it).
- 141 Bee roster expansion (depends on 119, and roster expansion itself is not approved).

Other excluded (not NOT-FOUND, from the audit):
- REJECTED-DUPLICATE (20): 23, 24, 47, 48, 50, 55, 62, 63, 65, 80, 95, 120, 145, 158, 161, 188, 189, 213, 216, 217.
- REJECTED-DESIGN (4): 83, 159, 218, 219.
- BLOCKED (11): 181, 182, 202 (DanceResult contract change); 185, 227, 238 (no BearAltar geometry); 206 (no per-cell brood state); 208 (nectar state); 225 (no forager carry state); 226 (HubHoneyFlow not written); 233 (wallet vs harvest count, owner decision).
- NOT-STARTED (3): 46 Seasons service (owner decision, see below); 112 and 124 (depend on seasons).

## Pending searches (55 AMBIGUOUS, not batched)

These are not proven absent. A targeted second search per item is needed before any of them can be proposed.
20, 30, 31, 36, 37, 53, 57, 64, 69, 77, 85, 92, 96, 97, 98, 99, 100, 101, 102, 103, 105, 107, 113, 115, 116, 117, 118, 121, 122, 125, 128, 129, 131, 133, 134, 135, 136, 137, 138, 142, 143, 147, 150, 156, 157, 160, 162, 164, 165, 166, 167, 168, 170, 179, 194.

## Decisions the owner must make before a batch can be built

1. Batch 1 go-ahead: approve items 1-10 for build (no economy change).
2. Seasons (item 46, and 112, 124): approve a visual-only seasons layer inside TimeService, with no yield change without a separate approval.
3. Queen naming (item 24): allow players to name their queen? If yes, approve the chat-filter approach and the age policy.
4. Extra plot slots (item 26): approve plots 7-8, the propolis cost, and sequencing with hub redo steps 7-8.
5. Holiday system (item 25): approve a time-limited content format and its scope.
6. Economy items (upgrade ladders, storage caps, event multipliers, friend bonus): each needs its own balance decision. None is in a batch until decided.
7. Hub budget (items 14, 21): confirm the hub part budget (cap 380, now 321) and whether trophy pedestals and the stats panel fit.
8. Music (item 15): supply licensed audio IDs.
9. Bee colour (item 17): extend the existing wardrobe, or keep a separate customizer?
10. AntiCheat (item 29): build before publish? It changes the server economy.
11. Blocked items: DanceResult contract (181, 182, 202), BearAltar geometry (185, 227, 238), per-cell brood state (206), nectar and forager carry state (176, 208, 225), HubHoneyFlow write (226), wallet vs harvest count for honey pop (233).
12. Held items: spec for 32; confirm consumables for 173 and 174; route-quality rule for 197.
13. Pending searches: approve a second Studio pass over the 55 AMBIGUOUS numbers before the next proposal.
