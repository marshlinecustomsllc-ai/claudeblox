# Route Fading + Long Memory -- Feature Architecture (Addendum)

## Overview
`Config.PERKS.longMemory` is the last perk in the game with no effect. It is inert because the thing it slows down, route decay, was never built. A route's `quality` is set once, in `DanceService.createRoute`, and stays fixed until the player dances that patch again.

This addendum designs route fading so that:
- it never makes a route worthless,
- it never changes anything during a play session,
- it gives a player who comes back after a few days one clear, fun action: dance your flowers again,
- Long Memory then has a real, felt effect.

I read these live sources in Studio (place 123313915411717): `DanceService` (all of it), `ForagingService` (all), `ResourceService` (all), `Formulas`, `Config` (PROFILE_TEMPLATE, DANCE, DANCE_FLOOR_TIERS, PERKS, FORAGING, SPECIES), `DataService` migrations, `PerkService` header, `HudController` hints, `DanceController.showSelect/onDanceResult`, `StructureService` scope, and the real saved profile `hive_2354572334` (eXemptAttempt) through a read-only `GetAsync`.

**The design in one line:** a route stays fresh for 12 hours. Over the next 72 hours its quality slides in a straight line down to Poor quality (0.70), and it never goes lower. Any re-dance refreshes it and can never make it worse. Long Memory slows the whole clock by 15% per level.

## Feature Scope
- **Type:** new mechanic (economy modifier) + small UI cues
- **Flavor:** SYSTEMIC (no world geometry, no new parts)
- **Subagents needed:** luau-scripter only. The UI cues reuse existing elements (patch button text + AccentBar colour, HUD hint string), so ui-designer is not needed.
- **World changes:** none
- **Schema changes:** none. `lastDanced` already exists on every route (see Q5). No migration, no version bump.
- **Files touched:**
  - `ReplicatedStorage.Modules.Config`
  - `ReplicatedStorage.Modules.Formulas`
  - `ServerScriptService.Systems.ForagingService`
  - `ServerScriptService.Systems.DanceService`
  - `ServerScriptService.Systems.ResourceService`
  - `StarterPlayer.StarterPlayerScripts.Controllers.DanceController`
  - `StarterPlayer.StarterPlayerScripts.Controllers.HudController`
  - comment-only updates: `PerkService`, `HiveController`
  - `architecture.md` doc sync

---

## What the live code actually does (facts the design is built on)

| Fact | Live value | Source |
|---|---|---|
| Quality by grade | Perfect **1.25**, Good **1.0**, Poor **0.70** | `DanceService` local `QUALITY_BY_GRADE` |
| Route shape | `{ patchId, quality, lastDanced = os.time() }` | `DanceService.createRoute`: both the insert path and the re-dance path write `lastDanced` |
| How quality is used | a continuous multiplier: `yieldPerTrip = carry * speciesMult * richness * route.quality * weatherMult`; `ratePerBee = yieldPerTrip / tripTime` | `ForagingService.computeRouteRates` (`route.quality or 1.0`) |
| SUPPLY | `Σ ratePerBee * 10` (`ROUTE_FORAGER_SLOTS = 10`) | `ForagingService.ComputeSupply` |
| WINGS | foragers assigned greedily to routes, best `ratePerBee` first, at most 10 per route | `ForagingService.ComputeWings` |
| Honey flow | `min(SUPPLY, WINGS, COMB) * queen * gen * seams` | `ResourceService._tickPlayer` step 1 |
| Pollen flow | `supplyPollen` flows directly into cells, **not** bottleneck-limited | `ResourceService._tickPlayer` step 2 |
| Eviction at route cap | the route with the oldest `lastDanced` is removed | `DanceService.createRoute` |
| Route beam | server creates a gold Beam per route; the client hides it and flies "route bees" along it instead | `DanceService.createOrUpdateRouteBeam`, `VfxController` ROUTE BEES |
| Existing decay code | **none.** A TODO comment in `createOrUpdateRouteBeam`, a doc line in architecture.md, three unused tier flags | grep `decay` |
| Dance Floor tier flags | T3 `decaySlowerMult = 0.7`, T4 `routeQualityBonus = 0.10`, T5 `neverFullyLost = true`, **all unread** | `Config.DANCE_FLOOR_TIERS` |
| Dance Floor tier purchase | **does not exist.** `danceFloorTier` is written only by SwarmService's reset to 1; StructureService says Dance Floor tiers are "NOT implemented here" | grep `danceFloorTier` |
| Real player (eXemptAttempt) | version 4, `danceFloorTier = 1`, `longMemory = 0`, 24 foragers, 10 Honey cells (COMB intake 13.87/s), **2 routes** (not 13; there are **14 marked patches**, which is probably where "13" came from) | DataStore read |
| Their routes | `{patchId=15 Moonflower, quality=0.7, lastDanced=1790532969}` and `{patchId=16 Moonflower, quality=1.25, lastDanced=1790723274}` | same |

**Critical finding: decay only costs honey when routes are the bottleneck.** Quality scales SUPPLY and WINGS linearly. It does not touch COMB. If comb is the limit, a fading route removes spare capacity first and income only drops once WINGS/SUPPLY falls below COMB. Measured on the real player's own save (their 2 real Moonflower routes, 24 foragers, 13.87 COMB), with route 16 going from fresh Perfect to fully faded:

| Their plot | WINGS fresh -> faded | Honey/s change |
|---|---|---|
| Plot 3 / Plot 4 (near) | 19.1 -> 13.8 / 19.5 -> 13.9 | **0%** (still comb-bound) |
| Plot 2 / Plot 5 (mid) | 16.0 -> 11.7 / 16.8 -> 11.9 | **-16% / -14%** |
| Plot 1 / Plot 6 (far) | 12.8 -> 9.4 / 13.5 -> 9.5 | **-27% / -29%** |

The theoretical worst case is **-44%** (every route Perfect, fully faded, and route-bound). The typical felt loss is 0-30%. That is the gentle size we want. Three more effects come free from existing code:
- WINGS already sorts routes by live `ratePerBee`, so foragers automatically move to fresher routes first.
- Eviction already removes the stalest route, which is now also the most faded one.
- Pollen, which is not bottleneck-limited, scales directly with route quality, so a fully faded Perfect route brings in up to 44% less pollen.

**Two stale-doc bugs found:**
1. architecture.md line 249 says `240s · (1 - 0.15·longMemory)` per grade. That makes the interval *shorter* as the perk levels up, so decay gets **faster** (96 s per grade at L4). The perk would be actively harmful as written.
2. The 240 s/grade pace takes a Perfect route to Poor in 8 minutes and to "Lost" in 12, inside one session. That is roughly 1000x faster than this design, and it contradicts both the kid-friendly retune and the user's rule that a dance is never blocked.

Both are replaced below.

---

## Q1 -- What does "losing accuracy" mean mechanically?

**Confirmed: the effective route quality slides from the stored grade quality toward a floor over real time since `lastDanced`. It is never zero, never Lost, and no slot is freed.** This fits the real code better than any alternative:
- `quality` is already consumed as a continuous multiplier in exactly one place (`computeRouteRates`). Decaying it there is a one-line change and reaches honey (SUPPLY/WINGS) and pollen consistently.
- "Lost routes free their slot" (the old design) is unnecessary. Slots already turn over through oldest-eviction. Losing a route outright would also delete a player's route bees while they are away, which is the kind of loss kids read as "the game broke".
- Other options I rejected:
  - Decay as a "needs re-dance to keep route bees flying" state: that is a binary cliff.
  - Decay of patch richness: PatchService richness is static and shared between players.
  - Decay of the dance golden zone: this punishes the skill game, not staleness.

Two companion rules make the mechanic kid-friendly:
- **R1 -- Re-dancing never makes a route worse.** When an existing route is re-danced, the stored quality becomes `max(new grade quality, current effective quality)` and `lastDanced = now`. A kid who comes back to refresh a fading Perfect route and lands "Nice Try!" keeps what the route had and restarts its clock. They are never punished for doing exactly what the mechanic asks. Getting back to a full 1.25 still needs a Perfect dance, so the skill ceiling stays.
- **R2 -- Poor routes never fade.** The floor equals Poor quality, so a player who only ever dances Poor never sees decay at all. The weakest dancers are never hit twice.

## Q2 -- The decay curve

**Continuous and linear after a grace window.** The multiplier is continuous, so discrete grade steps would only add cliffs. Linear keeps "X% at day Y" easy to read and easy to test.

```
elapsed   = max(0, now - lastDanced)                         -- real seconds, os.time(); includes offline time
clock     = elapsed * rateMult                               -- rateMult from Q4 (1.0 with no perk)
fade      = clamp((clock - 43200) / 259200, 0, 1)            -- 12h grace, then 72h linear fade
effectiveQuality = stored                                    if stored <= floor
                 = stored - (stored - floor) * fade          otherwise
```

- **Grace 12 h:** nothing a kid does in a session or in the same day ever loses value mid-play. Income never ticks down while they watch.
- **Fade 72 h:** a daily player barely notices (-7% on a Perfect route after 24 h). A weekend-away player comes back to clearly faded routes. A week-away player finds every route at Poor level.
- **Offline time counts.** The mechanic exists to stop "set and forget forever". It needs no new schema (it uses the existing `lastDanced`) and no per-tick profile writes. The 12 h grace means same-day play is never affected. Coming back after days is met with a clear hint and a 7-second fun action, not a loss that can't be undone. It also fits the existing daily quest "Complete 2 waggle dances", which now doubles as "refresh your routes".

Base timeline, no perk:

| Time since last dance | Perfect route (1.25) | Good route (1.0) | Poor route (0.70) |
|---|---|---|---|
| 0-12 h | 1.25 (100%) | 1.00 (100%) | 0.70 |
| 24 h | 1.158 (92.7%) | 0.950 (95%) | 0.70 |
| 48 h | 0.975 (78%) | 0.850 (85%) | 0.70 |
| 72 h | 0.792 (63.3%) | 0.750 (75%) | 0.70 |
| 84 h+ (3.5 days) | **0.70 floor (56%)** | **0.70 floor (70%)** | 0.70 |

## Q3 -- The floor

**Floor = 0.70, exactly Poor quality** (`Config.ROUTE_DECAY.floorQuality`, and DanceService's Poor value will read it, so the two cannot drift apart).
- It matches this session's own precedent that "even Poor still yields something": a forgotten route becomes a Poor route, never worse than the worst possible dance.
- In relative terms that is 56% of a fresh Perfect route and 70% of a fresh Good one. The "40% of fresh" example from the brief would be 0.50, below any dance result. A forgotten route would then earn less than a failed dance, which breaks the "never worse than trying" principle.
- Because of the min() bottleneck spine, real honey loss at the floor is 0-29% for the real player (see table above).

## Q4 -- Long Memory

**Rule: `rateMult = 1 - 0.15 * level`.** It multiplies the whole decay clock, grace window included. The current perk text ("15% slower per level") stays literally true.

| Level | rateMult | Stays fresh for | Reaches floor at |
|---|---|---|---|
| 0 | 1.00 | 12.0 h | 84 h (3.5 d) |
| 1 | 0.85 | 14.1 h | 98.8 h (4.1 d) |
| 2 | 0.70 | 17.1 h | 120 h (5.0 d) |
| 3 | 0.55 | 21.8 h | 152.7 h (6.4 d) |
| 4 | 0.40 | 30.0 h | 210 h (8.75 d) |

Perfect-route quality (and % of fresh) by level:

| Since dance | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|
| 24 h | 1.158 (92.7%) | 1.186 (94.9%) | 1.213 (97.1%) | 1.241 (99.3%) | 1.250 (100%) |
| 48 h | 0.975 (78.0%) | 1.030 (82.4%) | 1.085 (86.8%) | 1.140 (91.2%) | 1.195 (95.6%) |
| 72 h | 0.792 (63.3%) | 0.874 (69.9%) | 0.957 (76.5%) | 1.039 (83.1%) | 1.122 (89.7%) |
| 96 h | 0.700 (56.0%) | 0.718 (57.5%) | 0.828 (66.3%) | 0.938 (75.1%) | 1.048 (83.9%) |
| 7 d | 0.700 | 0.700 | 0.700 | 0.700 | 0.828 (66.3%) |
| 10 d | 0.700 | 0.700 | 0.700 | 0.700 | 0.700 |

Good-route quality by level: 48 h 85 / 88 / 91 / 94 / 97%; 72 h 75 / 79.5 / 84 / 88.5 / 93%; 96 h 70 / 71 / 77 / 83 / 89%.

**Felt-difference check:**
- The perk is felt most in the 2-4-day range, which is the realistic "played Friday, back Monday" gap. At 72 h, L4 keeps a Perfect route at 90% where L0 is at 63%.
- A daily player at L4 never sees any decay (grace 30 h > 24 h). That is a real, understandable reward: "my routes don't fade any more if I play every day."
- It is not overpowered. At 7 days an L4 route is still down to 66%, and every level reaches the same floor by about 9 days. The total gain is capped by the 0.70 floor band. The perk costs 3+6+9+12 = 30 Royal Jelly in total.

**Dance Floor tier flags are read by the same function, so they work as soon as Dance Floor tiers become purchasable.** Today every player is tier 1, so this is inert but correct:
- `decaySlowerMult` (T3 and up) multiplies `rateMult`: `rateMult = (1 - 0.15*L) * 0.7`, floored at 0.05.
- `neverFullyLost` (T5) is repurposed, because nothing is ever Lost any more: at T5 the floor becomes **1.0 (Good)** instead of 0.70.
- Both are "cumulative": the flag applies if any tier row `1..danceFloorTier` defines it.
- `routeQualityBonus` (T4, +10%) is a separate inert item and is **out of scope** here (see Risk Areas).

## Q5 -- Does a `lastDanced` timestamp need adding?

**No. It already exists, and no migration is needed.**
- `DanceService.createRoute` writes `lastDanced = os.time()` on both the insert path and the re-dance path, and has done so since routes existed.
- The real saved profile has it on both of its routes (1790532969 and 1790723274, as integer epoch seconds).
- No profile schema change, no `PROFILE_TEMPLATE` change, no `MIGRATIONS[4]`, no version bump.
- **Defensive rule** (it replaces a migration): if `lastDanced` is not a number, the route is treated as **fresh** (no decay), never as "infinitely old". The next re-dance writes a real value. Such a route can only come from a hand-edited profile.
- **Effect on the real player at rollout:** route 15 is Poor and cannot fade, so it is unchanged. Route 16 (Perfect, danced about 3 h before my read) is fresh. It starts fading 12 h after its dance and reaches the floor at 84 h. Shipping this changes nothing for them on day one, so I deliberately added no "rollout epoch" clamp.

## Q6 -- UI: visible, but kept small

**Visible.** Hidden decay is the classic "the game got worse and I don't know why" moment, and the fix (re-dance) has to be discoverable without reading. Three cues, all in existing UI, built by the follow-up task:
1. **Dance menu patch buttons** (where the fix happens):
   - each route's button gets a word tag plus an AccentBar colour,
   - faded routes sort to the top.
2. **HUD bottleneck hint:** when routes are the limiting bar and any route is fading, the hint becomes "ROUTES FADING! Dance them again". Today a fading route would instead show a misleading "NEED BEES!" (WINGS) or "DANCE FLOOR FULL!" (SUPPLY at cap).
3. **Dance result line:** re-dancing an existing route shows "Route refreshed!" in place of the plain quality line.

No new ScreenGuis, no route-bee visual change (route bees are per-plot cosmetic-tinted, so tinting for freshness would clash), and no new remotes. The data travels in the existing 1 Hz `RatesUpdate`.

---

## System Design

### Config additions (`ReplicatedStorage.Modules.Config`)
Add a new section directly after `Config.DANCE`:
```lua
-- ============================================================
-- ROUTE_DECAY (route fading -- see architecture_route_decay_addendum.md)
-- ============================================================
-- A route stays fresh for graceSeconds of (perk-scaled) time since its
-- lastDanced, then its effective quality slides linearly over fadeSeconds
-- down to floorQuality and never below. Computed on read by
-- Formulas.EffectiveRouteQuality; nothing is ticked or stored.
Config.ROUTE_DECAY = {
	graceSeconds = 43200,        -- number: 12h fresh window (x 1/rateMult with Long Memory)
	fadeSeconds = 259200,        -- number: 72h linear fade after grace
	floorQuality = 0.70,         -- number: == Poor dance quality; DanceService QUALITY_BY_GRADE.Poor reads THIS
	neverLostFloorQuality = 1.0, -- number: floor when any Dance Floor tier <= current has neverFullyLost (T5) -- floor at Good
	minRateMult = 0.05,          -- number: safety clamp so a stacked perk/tier multiplier can never stop time entirely
	fadingHintFraction = 0.25,   -- number: fade >= this counts as "Fading" for UI (menu tag + HUD hint)
}
```
Change `Config.PERKS.longMemory.description` to:
`"Your bees remember their dance routes longer -- routes stay fresh longer and fade 15% slower per level."`
(Remove "(Coming soon -- not active yet.)". `effectPerLevel = 0.15` and `max = 4` stay as they are.) Update the HONESTY NOTE comment above `Config.PERKS`: longMemory is now live, and the effect lives in `Formulas.RouteDecayRateMult`.

### Formulas additions (`ReplicatedStorage.Modules.Formulas`, pure, shared by client and server)
Add after `Formulas.YieldPerTrip`:
```lua
-- Route fading (architecture_route_decay_addendum.md). Pure: no profile/workspace access.
-- Multiplier on the decay clock: Long Memory perk x Dance Floor decaySlowerMult (cumulative).
function Formulas.RouteDecayRateMult(longMemoryLevel: number?, danceFloorTier: number?): number
	local perk = Config.PERKS.longMemory
	local level = math.clamp(math.floor(tonumber(longMemoryLevel) or 0), 0, perk.max)
	local mult = 1 - perk.effectPerLevel * level
	local tier = math.clamp(math.floor(tonumber(danceFloorTier) or 1), 1, #Config.DANCE_FLOOR_TIERS)
	for t = 1, tier do
		local m = Config.DANCE_FLOOR_TIERS[t].decaySlowerMult
		if typeof(m) == "number" then
			mult *= m
			break -- apply once (T3 row); later rows inherit it, they do not stack it again
		end
	end
	return math.max(mult, Config.ROUTE_DECAY.minRateMult)
end

function Formulas.RouteFloorQuality(danceFloorTier: number?): number
	local tier = math.clamp(math.floor(tonumber(danceFloorTier) or 1), 1, #Config.DANCE_FLOOR_TIERS)
	for t = 1, tier do
		if Config.DANCE_FLOOR_TIERS[t].neverFullyLost then
			return Config.ROUTE_DECAY.neverLostFloorQuality
		end
	end
	return Config.ROUTE_DECAY.floorQuality
end

-- 0 = fresh, 1 = fully faded. elapsedSeconds is real seconds since lastDanced.
function Formulas.RouteFadeFraction(elapsedSeconds: number, rateMult: number): number
	local clock = math.max(0, elapsedSeconds) * rateMult
	local d = Config.ROUTE_DECAY
	return math.clamp((clock - d.graceSeconds) / d.fadeSeconds, 0, 1)
end

-- The quality ForagingService actually multiplies into yield.
-- Non-number lastDanced => treated as fresh (never "infinitely old").
function Formulas.EffectiveRouteQuality(storedQuality: any, lastDanced: any, now: number, rateMult: number, floorQuality: number): number
	local q = tonumber(storedQuality) or 1.0
	if q <= floorQuality or typeof(lastDanced) ~= "number" then
		return q
	end
	local fade = Formulas.RouteFadeFraction(now - lastDanced, rateMult)
	return q - (q - floorQuality) * fade
end
```
Test values (must hold exactly, to 3 dp):

| Call | Expected |
|---|---|
| `EffectiveRouteQuality(1.25, now-86400, now, 1.0, 0.7)` | 1.158 |
| same, `rateMult = 0.4` | 1.25 |
| `EffectiveRouteQuality(1.25, now-302400, now, 1.0, 0.7)` | 0.70 |
| `EffectiveRouteQuality(0.7, now-10^7, now, 1.0, 0.7)` | 0.70 |
| `EffectiveRouteQuality(1.25, nil, now, 1.0, 0.7)` | 1.25 |
| `EffectiveRouteQuality(1.25, now+3600, now, 1.0, 0.7)` | 1.25 (future timestamp clamps to fresh) |
| `RouteDecayRateMult(4, 1)` | 0.40 |
| `RouteDecayRateMult(4, 3)` | 0.28 |
| `RouteDecayRateMult(9, 1)` | 0.40 (clamped to max 4) |
| `RouteFloorQuality(1)` | 0.70 |
| `RouteFloorQuality(5)` | 1.0 |

### Runtime state
None new. The truth is `profile.routes[i].quality` + `lastDanced` + `profile.perks.longMemory` + `profile.danceFloorTier`, all already persisted. Effective quality is computed on read and **never written back**, except by R1 at re-dance time.

---

## Script Modifications

**1. ForagingService** (`ServerScriptService.Systems.ForagingService`)
- CHANGE: `computeRouteRates` uses effective quality.
- CURRENTLY: inside the route loop, `local routeQuality = route.quality or 1.0`.
- NEW BEHAVIOR:
  - Before the `for _, route in (profile.routes or {})` loop, add:
    ```lua
    local now = os.time()
    local decayRateMult = Formulas.RouteDecayRateMult(profile.perks and profile.perks.longMemory, profile.danceFloorTier)
    local floorQuality = Formulas.RouteFloorQuality(profile.danceFloorTier)
    ```
  - Replace the line with `local routeQuality = Formulas.EffectiveRouteQuality(route.quality, route.lastDanced, now, decayRateMult, floorQuality)`.
- ADD a public function:
  ```lua
  -- Display-only freshness for RatesUpdate (1 Hz). Pure read; never mutates profile.
  function ForagingService.GetRouteFreshness(profile: any): ({ { patchId: number, fade: number, canFade: boolean } }, boolean)
  ```
  For each route:
  - `canFade = (tonumber(route.quality) or 1.0) > floorQuality`
  - `fade = canFade and typeof(route.lastDanced) == "number" and Formulas.RouteFadeFraction(os.time() - route.lastDanced, decayRateMult) or 0`, rounded to 2 dp
  - Second return value `anyFading` = any route with `canFade and fade >= Config.ROUTE_DECAY.fadingHintFraction`.
- Doc comment: add a "ROUTE FADING" paragraph: quality is decayed on read, the module still mutates no profile state, see the addendum.
- EDGE CASES:
  - Rain still forces `ratePerBee = 0` (unchanged).
  - WINGS' existing `table.sort` by `ratePerBee` now sends foragers to fresher routes first automatically. This is intended; do not change it.

**2. DanceService** (`ServerScriptService.Systems.DanceService`)
- CHANGE A, `QUALITY_BY_GRADE`: set the Poor entry to `Config.ROUTE_DECAY.floorQuality` (the value stays 0.70; it now has one source of truth).
- CHANGE B, `createRoute` re-dance branch (rule R1):
  - CURRENTLY: `routes[existingIndex].quality = quality; routes[existingIndex].lastDanced = os.time(); return existingIndex, nil`
  - NEW:
    ```lua
    local route = routes[existingIndex]
    local now = os.time()
    local current = Formulas.EffectiveRouteQuality(route.quality, route.lastDanced, now,
        Formulas.RouteDecayRateMult(profile.perks and profile.perks.longMemory, profile.danceFloorTier),
        Formulas.RouteFloorQuality(profile.danceFloorTier))
    route.quality = math.max(quality, current)
    route.lastDanced = now
    return existingIndex, nil, true, route.quality
    ```
  - The new-route insert path returns `#routes, nil, false, quality`.
  - Update the function's return type to `(number?, string?, boolean?, number?)`.
- CHANGE C, `SubmitDance`:
  - Capture `local slot, reason, refreshed, finalQuality = createRoute(...)`.
  - In the `DanceResult` payload, send `quality = finalQuality or quality` and add `refreshed = refreshed == true`.
  - The `grade` field stays the actual graded result. Stats, achievements, quest and tutorial hooks are unchanged: they count the dance, not the stored quality.
- CHANGE D, comment: replace the `TODO(ForagingService): route decay ("one grade every 240s")...` block in `createOrUpdateRouteBeam` with: "Route fading is computed on read (Formulas.EffectiveRouteQuality). Routes are never Lost, so this beam is correctly permanent until eviction/re-dance. The client hides it behind route bees anyway."

**3. ResourceService** (`ServerScriptService.Systems.ResourceService`)
- CHANGE: `_tickPlayer` step 7 (`if sendRates then`, RatesUpdate).
- NEW:
  - Call `local routeFreshness, anyFading = ForagingService.GetRouteFreshness(profile)` once.
  - Add two trailing additive fields to the payload (same precedent as `perks`/`floorBuild`):
    - `routeFreshness = routeFreshness` (array of up to 10 `{patchId, fade, canFade}`)
    - `routesFading = anyFading and (bottleneck == "SUPPLY" or bottleneck == "WINGS")`
- EDGE CASE: `supplyReason` is computed exactly as today. The client decides which hint wins.

**4. HudController** (`StarterPlayer.StarterPlayerScripts.Controllers.HudController`)
- ADD a hint string: `local ROUTES_FADING_HINT = "ROUTES FADING! Dance them again"`.
- CHANGE `applyBottleneck(bottleneck, supplyReason)` to `applyBottleneck(bottleneck, supplyReason, routesFading: boolean)`. After the existing `SUPPLY_REASON_HINT` override, add: `if routesFading and (bottleneck == "SUPPLY" or bottleneck == "WINGS") then hintText = ROUTES_FADING_HINT end`. Fading wins over `at_cap` and "NEED BEES!", because re-dancing an existing route is the cheapest real fix.
- CHANGE the RatesUpdate handler:
  - read `local routesFading = payload.routesFading == true`,
  - add `currentRoutesFading` to the change-detection condition next to `currentBottleneck`/`currentSupplyReason`, so the hint repaints when only the fading flag flips.
- No layout or colour changes. The existing pulse and red bottleneck bar still apply.

**5. DanceController** (`StarterPlayer.StarterPlayerScripts.Controllers.DanceController`)
- ADD state:
  - `local routeFade: { [number]: { fade: number, canFade: boolean } } = {}`
  - In `Init`, connect `Remotes.RatesUpdate.OnClientEvent`: rebuild `routeFade` from `payload.routeFreshness` (ignore non-table entries; `patchId` must be a number). Several listeners on one RemoteEvent are fine; HudController keeps its own.
- ADD `local function fadeBucket(patchId: number): string?` returning:
  - `nil` if not a route, or if `canFade == false` (Poor-level routes get no tag)
  - `"Fresh"` if `fade < Config.ROUTE_DECAY.fadingHintFraction`
  - `"Fading"` if `fade < 1`
  - `"Faded"` otherwise
- CHANGE `showSelect`:
  - Cache key: `key = table.concat(sortedIds, ",") .. "|" .. <per-id bucket string>`, so a re-dance or crossing a bucket repaints the menu while it is open.
  - Button text:

    | Bucket | Text | AccentBar colour |
    |---|---|---|
    | none | `"%s (#%d)"` (unchanged) | template default Honey Gold, unchanged |
    | Fresh | `"%s (#%d) - Fresh"` | Meadow Green `#6FA84A` |
    | Fading | `"%s (#%d) - Fading"` | Wax Cream `#E8D49A` (paling) |
    | Faded | `"%s (#%d) - Dance again!"` | Propolis Brown `#7A4A22` (dried up) |

    Alarm Red stays reserved for threats.
  - `btn.LayoutOrder = rank * 100 + i`, with rank Faded = 0, Fading = 1, none = 2, Fresh = 3. The route that most needs a dance is on top.
  - Text size is covered by the template's existing UITextSizeConstraint (max 20). The longest possible label is "Linden Blossom (#12) - Dance again!" at 35 characters. It fits the button's Scale width 1.0, with TextScaled auto-shrink on narrow phones, which is accepted. Do not shorten species names.
- CHANGE `onDanceResult`: `if payload.refreshed == true then tapHintLabel.Text = string.format("Route refreshed! Quality x%.2f", tonumber(payload.quality) or 0) else <existing line> end`.

**6. Comment-only updates**
- `PerkService` header: rewrite the `longMemory` bullet to say it is live (effect in `Formulas.RouteDecayRateMult`, consumed by `ForagingService.computeRouteRates` and `DanceService.createRoute`). PerkService still only sells the level, and its purchase logic is unchanged.
- `HiveController` header lines 27-29: only hiveSteward's historical note remains; longMemory is live. The row text comes from Config, so it updates automatically.

**7. architecture.md doc sync** (stops a future agent from "restoring" the 240 s design)
- Line 103: replace "Routes decay one grade per 4 minutes until re-danced." with "Routes stay fresh 12h, then fade linearly over 72h to Poor quality (0.70) -- never lost. Re-dancing refreshes and never lowers a route. See architecture_route_decay_addendum.md."
- Line 246: replace `DecayTick()` with `EffectiveRouteQuality (computed on read -- no tick)`.
- Line 249: replace the whole bullet with the Q2 formula and `rateMult = (1 - 0.15*longMemory) * (T3+ ? 0.7 : 1)`.
- Line 320: the `RouteUpdate` row describes a remote that was never built. Mark it "not built -- route freshness ships in RatesUpdate.routeFreshness".
- Line 623: T5 "Extra" becomes "routes never fade below Good".
- Line 710: Long Memory row becomes "routes fade 15% slower/level (clock x(1-0.15L))".

---

## New RemoteEvents
None. The existing remotes get additive fields:

| Remote | Direction | New fields | Validation |
|---|---|---|---|
| `RatesUpdate` | S->C, 1 Hz | `routeFreshness: {{patchId: number, fade: number 0..1, canFade: boolean}}`, `routesFading: boolean` | server-computed, display-only, nothing trusted back |
| `DanceResult` | S->C | `refreshed: boolean`; `quality` now = final stored quality | display-only |

## Existing System Interactions
- **Security:** everything is server-side. The client only displays server-computed `fade`. No client clock is involved: the client never computes freshness itself, so a phone with a wrong clock cannot mislead the UI.
- **Weather:** unchanged. Rain still zeroes `ratePerBee`. Overcast/Breezy stack multiplicatively with fading, so a faded route is where weather dips start to bite.
- **Three-bottleneck HUD:** bars are unchanged, and the hint gains "ROUTES FADING!" when SUPPLY or WINGS is short.
- **Eviction at route cap:** unchanged code. The oldest `lastDanced` is now also the most faded route, a natural fit. R1 updates `lastDanced` on every re-dance, so refreshed routes are protected from eviction.
- **Pollen:** scales with effective quality (not bottleneck-limited). The worst case is -44% pollen from a fully faded Perfect route, and the floor keeps it above zero.
- **Tutorial / FirstWaggle / daily quest / achievements:** unaffected. They count dances, not quality. The daily "2 dances" quest now doubles as "refresh 2 routes".
- **Swarm:** wipes routes as today. New routes start fresh.
- **Route bees / VfxController:** untouched.
- **clearSignal / golden zone / dance timing:** untouched.
- **Rejoin (`CombService` route-beam restore):** untouched. Freshness is computed from saved `lastDanced`, so offline time counts correctly after a rejoin.
- **Cross-server clock skew:** `lastDanced` a few seconds in the future is clamped to fresh by `max(0, elapsed)`.
- **Performance:** `computeRouteRates` runs twice per 0.5 s tick per player over at most 10 routes, plus one `GetRouteFreshness` at 1 Hz. That is a few multiplications. There are no new connections and no DataStore writes beyond the existing autosave.

## DataStore Impact
- No new fields, no migration, no version bump (Q5). `route.quality` may now hold non-grade values such as 1.103 after an R1 refresh. Nothing maps quality back to a grade (verified by grep: the only consumers are `ForagingService` and the DanceController display), so this is safe.

## Build Order
1. **Config** `ROUTE_DECAY` + longMemory description. There is no behavior yet.
2. **Formulas** four functions. MCP-test all the values in the test table in Edit mode (`require` works there).
3. **ForagingService** effective quality + `GetRouteFreshness`. The economy is now live.
4. **DanceService** A-D (R1 max-refresh, `refreshed` flag, Poor from Config, comment).
5. **ResourceService** RatesUpdate fields.
6. **HudController** hint, then **DanceController** menu tags, sort, and the refreshed line.
7. Comment updates (PerkService, HiveController) + **architecture.md** doc sync.
8. **Verify:**
   - **Economy check:** in a Play session, set a test profile's route to `{quality=1.25, lastDanced=os.time()-302400}` and confirm `ForagingService._computeRouteRates` prices it at 0.70. Set `perks.longMemory = 4` and confirm the same route is priced at 0.828 at `-604800` (7 days).
   - **Re-dance test:** re-dance that route via `DanceService._debug` + `SubmitDance` with a Poor-grade input. Stored quality becomes `max(0.7, current)`, `lastDanced` is about now, and `DanceResult.refreshed == true`.
   - **UI check:**
     - the menu shows "- Dance again!" on the faded route, sorted to the top,
     - the HUD shows "ROUTES FADING! Dance them again" only while SUPPLY or WINGS is the bottleneck,
     - no tag appears on a Poor route.

## Risk Areas
- **A route-bound player loses up to 44% (typically 0-30%) after about 3.5 days away.** Mitigations:
  - the 0.70 floor,
  - a 7-second fun fix, surfaced by two cues,
  - R1 (retrying never hurts),
  - Long Memory.
  I accept this: it is the intended nudge, sized far below the old 12-minute Lost design.
- **Mid-session drop:** impossible within a 12 h window of the dance. A route danced about 11.9 h ago can begin fading during a session, but only by about 0.01%/min (a Perfect route loses 0.55 over 72 h), which cannot be seen.
- **R1 makes Perfect "sticky":** a lazy Poor re-dance holds the current value. Accepted. Restoring a route to full still needs a Perfect, and stats/achievements still count only real Perfects.
- **Dance Floor tier extras are inert because tiers are unpurchasable.** This addendum wires `decaySlowerMult` and `neverFullyLost` into the formula so they work the day tier purchases ship. `routeQualityBonus` (T4, +10%) is **still unread**. It is out of scope here. When Dance Floor purchases are built, apply it in `ForagingService` as `effectiveQuality * (1 + bonus)` after decay, not to the stored value. Also correct the kid-friendly addendum's remark that tiers are "bought for route slots": they cannot be bought yet.
- **Menu text length on small phones:** "- Dance again!" can auto-shrink on the longest species names. The UITextSizeConstraint already handles it, and the AccentBar colour carries the meaning without text.

## Mobile Considerations
- No new touch targets. The cues are a word + a colour strip on existing buttons, plus an existing HUD hint.
- The colour meaning (green / pale / brown) is backed by words and by sort order, so it survives colour blindness.
- No performance impact (see Existing System Interactions).

## Signature Moments
- **"Welcome back, dancer."** A kid returns after a weekend. The HUD reads "ROUTES FADING! Dance them again". At the Dance Floor, their best Moonflower route sits at the top of the menu in brown: "Moonflower (#16) - Dance again!". Two taps later: "Perfect! ... Route refreshed! Quality x1.25", the button turns green ("- Fresh"), and the honey bar climbs back. Returning to the game gets a ritual, not a penalty.
- **"My bees remember."** A kid buys Long Memory to level 4 and notices their routes no longer need a dance every day: every tag stays "- Fresh" across a whole day away. That is a perk you can see.

---

## DISPATCH SUMMARY
**Build route fading. Long Memory becomes live. One luau-scripter task, priority MEDIUM** (economy correctness + the last inert perk; nothing is broken today).
- **Numbers:**
  - grace 12 h (`43200`), then a linear 72 h (`259200`) fade to floor 0.70 (= Poor), never lower, never Lost
  - `rateMult = (1 - 0.15*longMemory) * (T3+: 0.7)`, min 0.05, scales the whole clock
  - L0-L4 reach the floor at 3.5 / 4.1 / 5.0 / 6.4 / 8.75 days
  - T5 floor = 1.0
- **Rules:** R1 re-dance = `max(new, current)` + reset the clock; R2 Poor routes never fade.
- **Schema:** none. `lastDanced` already exists on every real route; a non-number counts as fresh. No migration.
- **Files:**
  - Config `ROUTE_DECAY` + description
  - Formulas: 4 pure functions
  - ForagingService: effective quality + `GetRouteFreshness`
  - DanceService: Poor from Config, R1, `refreshed`, comment
  - ResourceService: RatesUpdate `routeFreshness`/`routesFading`
  - HudController: "ROUTES FADING!" hint
  - DanceController: Fresh / Fading / Dance again! tags, AccentBar colour, faded-first sort, "Route refreshed!"
  - comments: PerkService, HiveController
  - architecture.md: lines 103/246/249/320/623/710
- **Also found (not in scope, logged):**
  1. The old architecture.md formula made Long Memory speed decay *up*.
  2. Dance Floor tiers 2-5 cannot be purchased at all, so `routeQualityBonus` stays inert.
  3. The real player has 2 routes / 14 marked patches, not 13 routes.
