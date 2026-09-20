# WICKWOOD — Architecture Document

**Working title:** WICKWOOD (in-game subtitle: *Five Nights in Wickwood*)
**Task type:** TYPE A — new game, from scratch
**Version:** v1 (first playable level — one map, one monster, five nights)

---

## Core Concept

Three to six survivors must keep one campfire alive for five nights in a forest hunted by a fourteen-foot stag made of candle wax that does not hunt people — it hunts *light*, and every light it snuffs makes it taller.

---

## The Hook

**The monster is the brightest thing in the forest, and it is coming to take your light.**

Wick — the wax stag — is not a chase-you monster. It has an objective: extinguish every light source in Wickwood, finishing with the campfire at your camp. It only hurts players who stand between it and a light, who make noise loud enough to outweigh a lantern, or who are caught out in the dark. This inverts every reflex a horror player has:

- **You can see it coming.** Three lit candles burn in its antlers. Its glow reflects off the lake surface before it clears the treeline. The lookout who spots that reflection and calls it out is the hero of the clip.
- **You can bribe it.** A Placed Lantern on the far side of the map is a four-second delay you bought with three Wood and two Tallow. Every group discovers this on their own and feels clever.
- **It melts.** Wick burns itself down over the course of each night. Full of wax it is tall, slow, and almost elegant. Below 40% it sags — it hunches, its walk drops into a scuttle, it moves thirty percent faster, and its hum drops into a wet gurgle. The monster's own timer is written on its body where you can read it.
- **The danger color is white.** Wax is pale cream. The monster is pale cream. The fungus is pale cream. Warm amber firelight means safety. In Wickwood, white is what kills you and orange is what keeps you alive — a palette inversion nobody forgets.

And the co-op gate that makes it a group game rather than five solo games: **Wick does not kill you, it drinks you.** Being caught puts you in a grapple you physically cannot escape alone. Only a teammate's lantern beam held for two seconds, or a thrown flare, breaks it. Playing alone is not hard — it is arithmetically impossible.

The pitch in one line that makes a 12-year-old say "wait, what?": *a giant candle shaped like a deer is walking toward your campfire to blow it out.*

---

## Genre: Cooperative Survival Horror (survive-N-nights)

Chosen because primitives are a liability for detailed monsters and an asset for atmosphere: a pale, translucent, slightly-wrong silhouette in fog reads as more disturbing than a detailed model, and a forest is the cheapest convincing large space you can build from cylinders and wedges.

**The unique angle for this genre:** survive-N-nights games almost universally make the monster a pursuer and the player a fleer. Wickwood makes the monster a *thief with an agenda* and the players *defenders of a resource*. That single change converts the game from reaction to planning, which is exactly what generates voice-chat coordination instead of screaming.

---

## Emotional Journey

| Beat | When | Feeling |
|------|------|---------|
| Lobby | 0:00 | Anticipation. Six pads, six names, one button. Low hum already audible under the lobby music. |
| First dawn in camp | 0:10 | Relief and curiosity. Warm firelight, birds, a cabin, tools. This looks *nice*. That is the setup. |
| First chop | 0:30 | Competence. Wood flies, the axe thunks, a number goes up. Instant readable progress. |
| Dusk warning | 2:30 | Dread with a countdown. Light goes amber then blue, the hum starts, everyone runs for camp. |
| Night 1, the First Snuff | 3:20 | **"Whoa."** Wick walks past camp entirely, stands over the farthest lantern, and a candle in its antlers brightens as the lantern dies. Then it leaves. It ignored you. That is worse. |
| Night 2, the lake reflection | ~7:00 | **"Look at the water — LOOK AT THE WATER."** First shared discovery moment. |
| Night 3, the Melt | ~12:00 | **"It's changing. It's CHANGING."** The silhouette breaks mid-night. |
| Night 4, first Blackout | ~16:00 | **Panic.** Hearth hits zero. Every light in a 600-stud forest dies at once and the only thing still glowing is the monster. |
| Night 5, the Long Burn | ~21:00 | Grim teamwork. Everyone has a job, everyone is shouting, nobody is exploring. |
| Dawn of Night 5 | ~24:00 | **Triumph.** The Hearth flares, fog burns off in a visible wave, Wick's wax fails, and it walks into the lake. |

Overall arc: **curiosity → competence → being ignored → being noticed → being hunted → holding the line.**

---

## Spatial Narrative

The map is a wheel. Camp is the hub — the only warm place. Every resource you need is on a spoke, and every spoke has a different way of being frightening. The tension curve is not a line the player walks along; it is a set of choices about how afraid they are willing to be for the next twenty seconds.

| # | Zone | Tension | Spatial feeling | Why |
|---|------|---------|-----------------|-----|
| 1 | Camp Clearing | Low (but conditional) | Open, warm, enclosed by canopy | The only place Wick will not enter — while the Hearth is above 25%. Safety with a fuel gauge attached. |
| 2 | Trail Ring | Medium | Linear, 8 studs wide, walls of trunk | You are between two lights. There is nothing to do here but travel, and travel is when things find you. |
| 3 | East Boulder Field | Low-medium | Wide, exposed, bright moonlight | You can see 200 studs. You can also *be seen* for 200 studs. Safety through information, not cover. |
| 4 | North Pinewood | High | Claustrophobic, vertical, sightlines under 25 studs | The best Wood in the map. You will hear Wick long before you see it and you will not know which direction. |
| 5 | West Deadfall | High | Skeletal, grey, hollow | The map *gives* you hiding places here, which tells you something about what happens here. |
| 6 | South Lakeshore | Medium-high | Horizontal, slow, no exit | Wading halves your speed and doubles your noise. But the water shows you Wick's candles before the trees do. |
| 7 | The Waxworks | Peak | Cathedral of pale columns, wrong-warm | Its den. The best Iron in the map is forty studs from where it sleeps. Day-safe — unless you are loud. |

The inverted safety gradient is deliberate: the **open, bright** zone is the safe one and the **dense, sheltered** zone is lethal. Players learn this in one night and it rewires how they read forests.

---

## Core Loop

```
        ┌─────────────────────── LOBBY (ready-up, 3-6 players) ──────────────────────┐
        │                                                                            │
        ▼                                                                            │
   ╔═══════════════════════════════════════════════════════════════════════════╗      │
   ║  NIGHT n  (n = 1..5)                                                      ║      │
   ║                                                                           ║      │
   ║   DAY  150s ──▶ DUSK 15s ──▶ NIGHT 120s (180s on n=5) ──▶ DAWN 12s        ║      │
   ║    │             │             │                            │             ║      │
   ║    │             │             │                            └─ escalate ──╫──┐   │
   ║    ▼             ▼             ▼                                          ║  │   │
   ║  gather       everyone      keep the Hearth lit                           ║  │   │
   ║  craft        runs home     relight what Wick snuffs                      ║  │   │
   ║  reinforce    hum starts    break grapples                                ║  │   │
   ║  place        Wick wakes    survive                                       ║  │   │
   ║  lanterns                                                                 ║  │   │
   ╚═══════════════════════════════════════════════════════════════════════════╝  │   │
        ▲                                                                         │   │
        └───────────────────────────── n < 5 ◀────────────────────────────────────┘   │
                                                                                      │
        n = 5 survived ──▶ WIN: the Hearth flares, Wick melts into the lake ──────────┤
        all players Snuffed during Blackout ──▶ WIPE ────────────────────────────────┘
```

### Step by step

**1. DAY (150s).** Wick is Dormant in the Waxworks. Noise is free. This is the only window in which the forest is safe, and it is the reason the day/night split matters mechanically rather than cosmetically. Players:
- chop trees for **Wood** (Hearth fuel, crafting base)
- mine boulders for **Stone** and **Flint**
- harvest **Wax Caps** on the lakeshore and dead trunks for **Tallow** (lantern fuel, poultices)
- loot four fixed **Wreck** sites for **Iron Scrap** (tier-2 only, scarce, does not respawn until dawn)
- craft at the Workbench, reinforce the Lodge, refill lanterns, place Placed Lanterns as bait/perimeter
- feed the Hearth ahead of the night

**2. DUSK (15s).** Global light tilts amber then blue over 15 seconds. The hum fades in at 10% volume from the Waxworks bearing. HUD shows `WICK IS WAKING`. No new harvesting is blocked — this is a pure warning window, and watching a teammate sprint the last eighty studs with their arms full is half the fun.

**3. NIGHT (120s, 180s on Night 5).** Wick wakes, builds its interest list, and starts walking. Players must:
- keep the Hearth above 0 fuel (it burns 2–3/s depending on night)
- relight Cold Wicks with a Brand taken from the Hearth (Brand lasts 30s — the far lanterns are a two-person relay)
- break grapples with a Focused Beam (2s hold) or a thrown Flare
- avoid **Gloom** (standing unlit fills a meter; at 100 it does 3 HP/s and doubles your detection weight)

**Surviving the night** = the Hearth is still lit at dawn. That is the whole win condition, stated in one sentence, learnable by watching for five seconds.

**Losing the night** = the Hearth reaches 0 fuel. This triggers **BLACKOUT**: every light in the world dies for 1.5 seconds, then only Wick's three candles remain lit in a 600-stud forest. Wick switches to direct player hunting for 45 seconds. Players can still recover — sprint to the Hearth's Cold Wick with Wood and relight it — but if all living players are Downed or Snuffed before the timer ends, the run is over.

**4. DAWN (12s).** Fog burns off in a wave. Dawn Report: Wood gathered, lanterns relit, Wick freezes, revives, nights survived. **Snuffed** players return at the Hearth — but each revival costs the Hearth 20 fuel, so death has a team price without benching anyone. Resource nodes respawn. Escalation table for night n+1 is applied.

### Why it does not feel repetitive

Three reasons, all systemic rather than scripted:

1. **Wick's route is emergent.** It walks to whatever has the highest interest weight right now: a bright lantern, a chopping noise, a Shout, a lit player standing in the open. Move your lanterns and you change its path. Two groups playing Night 3 on the same map never see the same route.
2. **The escalation table changes one rule per night**, not one number. Night 3 adds the Second Pass. Night 4 adds Wax Pools. Night 5 shortens the freeze window. Each is a new thing to learn, not a bigger number to endure.
3. **Wick's own melt timer** means the second half of every night plays differently from the first half, with a visible tell.

---

## The Monster: WICK

### Identity

A stag that stands on two legs, fourteen studs tall, made entirely of pale candle wax. Three lit candles burn among the tines of its antlers. It has no eyes — two shallow sockets brimming with wax. It makes no footstep sound whatsoever. It **hums**: a low, almost pleasant, unmistakably *human* lullaby. The hum volume is your only passive distance cue.

It is strange rather than scary because everything about it is a category error: a deer standing like a man, a predator made of a household object, a monster that glows, a horror that hums a tune to itself while it works.

### Visual specification (for enemy-designer)

R6 rig, 7 required parts + 8 decorative = **15 parts total**.

| Part | Size (studs) | Material | Color | Notes |
|------|--------------|----------|-------|-------|
| HumanoidRootPart | 2 × 2 × 1 | SmoothPlastic | — | Transparency 1, PrimaryPart |
| Torso | 2.6 × 5.2 × 1.4 | SmoothPlastic | Tallow White #EDE6D2 | Transparency 0.15 — light passes through it |
| Head | 1.8 × 2.2 × 2.6 | SmoothPlastic | #EDE6D2 | Elongated stag skull, Transparency 0.1 |
| Left Arm | 0.9 × 6.0 × 0.9 | SmoothPlastic | #EDE6D2 | Absurdly long — reaches below the knee |
| Right Arm | 0.9 × 6.0 × 0.9 | SmoothPlastic | #EDE6D2 | Same |
| Left Leg | 1.1 × 5.4 × 1.1 | SmoothPlastic | #EDE6D2 | |
| Right Leg | 1.1 × 5.4 × 1.1 | SmoothPlastic | #EDE6D2 | |
| Antler tines ×5 | 0.35 × 3.2 × 0.35 cylinders | SmoothPlastic | #EDE6D2 | Welded to Head, splayed asymmetrically — asymmetry is important, symmetry reads as a costume |
| Candle tips ×3 | 0.5 × 0.9 × 0.5 cylinders | **Neon** | Hearthlight Amber #E08A3C | Welded to three tines. **Center candle only** carries a PointLight: Range 16, Brightness 1.3, Color #E08A3C, Shadows true |

Exact R6 part names with spaces (`Left Arm`, not `LeftArm`). All 6 Motor6D joints required: RootJoint, Neck, Left Shoulder, Right Shoulder, Left Hip, Right Hip. Head **must** be joined to Torso by `Neck` or the Humanoid dies on spawn. All body parts `Anchored = false`.

Humanoid: MaxHealth 100 (this is the **Wax** pool, not conventional HP), WalkSpeed set per night from Config, HipHeight 4.2 at full wax, DisplayDistanceType None, AutoRotate true.

**The Melt — implemented without rig surgery.** Do NOT rescale parts at runtime; Motor6D + Size changes are janky. Instead, at each wax threshold:
- lower `Humanoid.HipHeight` (4.2 → 3.2 → 2.1)
- tilt the torso forward via `RootJoint.C0` rotation (0° → 18° → 34°)
- raise Torso/Head Transparency (0.15 → 0.3 → 0.45)
- increase WalkSpeed per the escalation table
- enable the `WaxDrip` ParticleEmitter on the Torso anchor
- lower the hum pitch (`Sound.PlaybackSpeed` 1.0 → 0.86 → 0.72)

Same 15 parts, completely different silhouette and read.

### Behavior: it hunts light, not people

Wick maintains an **Interest List** rebuilt every 0.4s on the server. Each entry is `{position, weight, kind}`:

| Interest source | Base weight | Decay |
|-----------------|-------------|-------|
| The Hearth | `40 + (hearthTier × 15)` — but **gated**: weight is 0 while Hearth fuel > 25% of max and night < 2 | none |
| Placed Lantern (lit) | `30` | none |
| Lantern Post (lit) | `26` | none |
| Player hand lantern ON | `12` | none |
| Player Focused Beam active | `45` (you are shouting with light) | while active |
| NoisePing | `weight` from the noise table | linear to 0 over 10s |
| Shout ping | `70` | over 10s |
| Player with Gloom ≥ 50 | `20` ("the dark marks you") | while Gloom ≥ 50 |
| Player detected by LOS, unlit | `18` | 6s memory |

It walks to the highest-weight entry. Ties break toward the farthest entry from the Hearth on nights 1–2 (so Night 1 teaches the lesson gently by taking an outer lantern) and toward the nearest on nights 3+.

### State machine

| State | Entry condition | Behavior | Exit |
|-------|-----------------|----------|------|
| **Dormant** | DAY phase | Stands in the Waxworks, hum at 5% volume, candles dim (Brightness 0.4). If a NoisePing > 60 lands within 40 studs, one candle brightens and rotates toward it and the hum spikes for 3s — a warning, not an attack. | DUSK begins |
| **Waking** | DUSK begins | 15s. Rises, candles brighten to full, hum to 35%. Does not move. | NIGHT begins |
| **Seeking** | NIGHT, has an interest target | PathfindingService to highest-weight interest. WalkSpeed = night's `walkSpeed`. | target reached → Snuffing; LOS on player → Stalking; higher-weight ping → re-path |
| **Snuffing** | Within 6 studs of a light interest | 4s animation: leans over the light, the light's fuel drains to 0, one antler candle brightens, Wick gains `+12 Wax`. Fires `WickEvent{"Snuffed"}`. Cannot be interrupted except by Recoil. | 4s elapsed |
| **Investigating** | A NoisePing outweighs all lights | Paths to the ping position, then sweeps a 40-stud radius for 6s, rotating. | sweep done → Seeking; LOS → Stalking |
| **Stalking** | Clear LOS on a player, player is lit, distance > 12 | **Does not charge.** Circles the player at 30–40 studs, keeping LOS, hum at 100%. This is the signature creepy behavior — it is *considering* you. Lasts up to 8s. | 8s → returns to Seeking; player becomes unlit OR steps between Wick and its light target → Charging |
| **Charging** | Player is unlit, or player is between Wick and its light target, or Blackout-Hunt | WalkSpeed = night's `chaseSpeed`. Direct pursuit. Will not enter Hearth safe radius while Hearth > 25%. | within 4 studs → Grappling; target lit + distance > 45 → Seeking; 14s elapsed → Seeking |
| **Grappling** | Contact within 4 studs while Charging | Target `Humanoid.PlatformStand = true`, held by AlignPosition + AlignOrientation to Wick's right-hand Attachment (never a Weld — welds cause physics jank with characters). 5s drink timer. Wax pours over the player's screen. On timeout: target → **Downed**, Wick gains +20 Wax, releases, returns to Seeking. | 5s timeout; OR a teammate holds Focused Beam on Wick for 2s; OR a Flare detonates within 18 studs |
| **Recoil** | Focused Beam hits Wick (raycast clear, inside spotlight cone), or Flare within 18 studs | **Frozen — cannot move or act.** But it *drinks the light*: the beaming player's lantern fuel drains 6/s. Duration = night's `freezeDuration` (4s → 2s by Night 5), hard-capped regardless of continued beaming, then 6s immunity so it cannot be stun-locked. Wick gains +8 aggro toward the player who did it. | duration elapsed |
| **Melting** | Wax crosses 70% / 40% threshold downward | 1.5s transition. Applies HipHeight / C0 tilt / transparency / speed / hum-pitch changes. | transition done → previous state |
| **Blackout-Hunt** | Hearth fuel hits 0 | All light interests are gone, so it hunts players directly for 45s at `chaseSpeed × 1.15`. Ignores the Hearth safe radius (there is no Hearth). | 45s, or Hearth relit |
| **Retreating** | DAWN begins | Walks to the Waxworks at walkSpeed, candles guttering. Releases any grapple. | arrives → Dormant |

**Wax as a resource, not health.** Wick starts each night at the table's `startWax` and **burns 1 Wax per 2 seconds** all night. It regains Wax by snuffing lights (+12) and grappling players (+20). Brands thrown at it deal 15 Wax; Flares deal 25. If Wax reaches 0 it enters **Retreating** early — a legitimate but very hard win condition for a night, and a fantastic thing for a group to discover on their own ("we can *starve* it"). Wax is never a kill: Wick cannot die in v1.

### Detection (line-of-sight)

Every 0.3s, server-side, for each player within 90 studs:
- Raycast from Wick's Head `DetectOrigin` Attachment to the player's HumanoidRootPart.
- `RaycastParams.FilterType = Exclude`; filter list = all `Props` folders, all `ArchDetail` folders, all `VFXAnchor` parts, Wick's own model, and all characters other than the target. **Trunks, boulders, the Lodge, and shutters DO block** — that is the whole point of the forest.
- Also require the player within Wick's 120° forward FOV.
- Unlit players are detected at **25 studs regardless of LOS** (it hears your breathing).
- Players inside a **Concealment** volume (Hollow Stump, Cellar Hatch) are added to a blacklist and skipped entirely — but Gloom fills inside them, so concealment is a timer, not a solution.

### AgentParameters (pathfinding)

```
AgentRadius = 3.5      -- Wick is wide; trails are 8 studs, Lodge door is 8 studs
AgentHeight = 14
AgentCanJump = false
AgentCanClimb = false
WaypointSpacing = 6
Costs = { Trail = 0.5, Water = 4, Deadfall = 1.2, WaxPool = 0.3 }
```

`ComputeAsync` **must** be wrapped in `pcall`, with a fallback to direct `Humanoid:MoveTo` on failure. Waypoint following is `MoveToFinished`-event-driven — never a for-loop with waits.

**Layout constraints this imposes (mandatory for world-builder):** trails 8 studs wide minimum; trees at least 10 studs apart center-to-center along any trail; no gap narrower than 8 studs anywhere Wick must path; the Lodge door 8 studs wide (Wick squeezes through, which gives players a beat — intentional); no dead-end pockets narrower than 10 studs.

### Why every encounter feels different

The encounter is a function of four independent variables: **how much lantern fuel the group has** (determines whether a freeze is affordable), **where the lanterns are** (determines Wick's route), **how much Wax it is carrying** (determines its speed and silhouette), and **who is where** (determines whether a grapple is a scare or a death). No scripted scares exist in this game. Every memorable moment is the intersection of those four.

---

## Systemic Tension Mechanics

### 1. LIGHT RADIUS

Every light in the game is a registered entry in `LightManager`'s registry: `{id, kind, position, fuel, maxFuel, burnRate, pointLight, lit}`.

| Light | Light object | Range | Brightness | Fuel | Burn rate | Notes |
|-------|--------------|-------|------------|------|-----------|-------|
| **The Hearth** T1 | PointLight | 60 | 2.4 | 200 | 2/s night, 0.5/s day | Safe zone radius = 40 |
| **The Hearth** T2 | PointLight | 75 | 2.8 | 300 | 2/s | Safe radius 50. Upgrade: 12 Wood + 8 Stone |
| **The Hearth** T3 | PointLight | 95 | 3.2 | 450 | 2/s | Safe radius 62. Upgrade: 20 Wood + 12 Stone + 2 Iron |
| **Hand Lantern** (every player, starting item) | PointLight | 22 | 1.6 | 100 | 1/s when ON | Modes: Off / On / Beam |
| **Hand Lantern — Focused Beam** | SpotLight | 60 | 2.2, Angle 35° | — | 4/s | Freezes Wick. Drains 6/s extra while Wick is in Recoil from it |
| **Placed Lantern** (craftable, cap 6 active) | PointLight | 28 | 1.9 | 120 | 0.5/s | Wick's primary prey. Bait and perimeter. |
| **Lantern Post** ×4 (fixed, in camp, start unlit) | PointLight | 32 | 2.0 | 150 | 0.5/s | Lit with a Brand. The camp's outer ring. |
| **Brand** (craftable) | PointLight | 18 | 1.5 | 30 | 1/s | 30s torch. Relights Cold Wicks. Throwable: 15 Wax damage. |
| **Signal Flare** (craftable) | PointLight | 55 | 3.4 | 12 | 1/s | 12s. Freezes Wick in radius. Breaks a grapple. |

**Illumination solve.** Every 0.25s, server-side, for each player: iterate the light registry, and if `(playerPos - lightPos).Magnitude <= light.range * 0.9` and the light is `lit`, the player is **Lit**. Registry is small (max ~18 entries) so this is trivially cheap.

**Outside the light: the Gloom meter.** 0–100 per player.
- Fills at **8/s** while Unlit during NIGHT (and at 4/s inside a Concealment volume even during DAY — stumps are dark).
- Drains at **25/s** while Lit.
- At Gloom ≥ 50: your Wick interest weight gains +20 ("the dark marks you") and a `GloomVignette` overlay begins closing in, with ColorCorrection Saturation dropping toward -0.6 on the client.
- At Gloom = 100: **3 HP/s**. Not instant death — a readable, escapable 33-second bleed that a 9-year-old understands on their first night.

Gloom is what makes light a *resource* rather than a preference. Fuel is the real currency of Wickwood, and Wood only exists to convert into fuel.

**When Wick snuffs a light** it leaves a **Cold Wick** — the object remains, tagged `ColdWick`, fuel 0, unlit. It can be relit by a player carrying a burning Brand (interact, 1.5s). It can be *refuelled* at the Workbench. Wick will not re-snuff a Cold Wick, so relighting is what puts a target back on its list — a genuinely interesting decision under pressure.

### 2. NOISE LEVEL

Per-player meter, 0–100, **decays 12/s**. Used for one purpose: generating **NoisePings** that compete with lights for Wick's attention.

| Action | Noise | Notes |
|--------|-------|-------|
| Walking | 0 | Walking is free. Always. |
| Sprinting | +18/s | The panic tax |
| Chopping a tree | +35 per swing | −40% with a Stone Axe |
| Mining stone | +40 per swing | |
| Crafting at the Workbench | +25/s while crafting | The crafter is a beacon |
| Opening the Lodge door | +15 | |
| Wading in the lake | +22/s | |
| Stepping in a Wax Pool (Night 4+) | +25 | Plus 40% slow for 3s |
| Falling damage | +30 | |
| Winded (stamina at 0) | +20/s | Breathing hard |
| Throwing a Flare | +80 | |
| **Shout** (deliberate, 20s cooldown) | +70 | Also pings your position on every teammate's HUD for 10s |

**How it reaches Wick.** When a player's noise meter crosses 45, `NoiseManager` creates a `NoisePing{position, weight = meter, expires = now + 10}`. Weight decays linearly to 0 over 10 seconds. `WickAI` reads pings via `NoiseManager.GetPings()` and folds them into the Interest List. A chopping player at night generates weight 35–70, which **outcompetes a Placed Lantern (30)** — so chopping at night literally pulls the monster off its route and onto you. That is the single cleanest expression of the day/night contract in the game.

**The Shout** is the design's most important small idea: it turns the loudest possible action into the group's best coordination tool, so the mechanically correct play and the socially fun play are the same play. Shouting to mark Wick's position is exactly the behavior that produces shareable clips.

### 3. STAMINA

Per-player, 0–100.

| Parameter | Value |
|-----------|-------|
| Sprint drain | 14/s |
| Sprint speed | 24 (walk 16) |
| Regen (idle ≥ 1.2s) | 9/s |
| Regen inside Hearth safe radius | 18/s — *rest at the fire* |
| Chop / mine swing cost | 8 |
| Wade multiplier | ×1.6 drain |
| At 0 | **Winded** 3s: WalkSpeed 10, +20 noise/s, cannot sprint |

**The tradeoffs it forces:**
1. **Speed vs. yield.** A gatherer who sprints between every tree has no stamina left to chop. Walking there and chopping there is strictly more productive — so the game rewards calm and punishes panic, without ever saying so.
2. **The panic spiral.** Sprinting from Wick drains stamina; hitting 0 makes you Winded, which adds 20 noise/s, which raises your interest weight, which brings it closer. Running away makes it worse. Walking away, lit, works better. Players learn this the hard way once and never forget it.
3. **Carry weight.** Every resource unit is 1 weight; cap is 60. Above 60 → sprint drain ×1.8 and max speed −15%. A full load cannot be sprinted home, which is why a dedicated ferry runner is a real job.

### 4. LINE OF SIGHT

All raycasting is **server-side**. The client never decides what it can see.

| Use | Origin → Target | Rate | Behavior it drives |
|-----|-----------------|------|--------------------|
| **Wick detection** | Wick Head `DetectOrigin` → player HumanoidRootPart | 0.3s per player within 90 studs | Populates Wick's interest list; gates Stalking and Charging |
| **Beam freeze** | Player's lantern Attachment → Wick Torso center | 0.2s while Beam is held | If clear and within 35° of the beam's forward vector → Wick enters Recoil, beaming player loses 6 fuel/s |
| **Flare detonation** | Flare position → Wick Torso | once on detonate | If clear and within 18 studs → Recoil + break grapple |
| **Concealment check** | Concealment volume `:GetPartBoundsInBox` | on enter/exit | Player added to Wick's LOS blacklist; noise halved; Gloom fills at 4/s |
| **Placement validity** | Player position → requested placement point, then downward ray | on `RequestPlaceObject` | Prevents placing lanterns inside geometry or through walls |

Shared `RaycastParams` construction lives in `Shared.MakeVisionParams()` so every consumer filters identically — one source of truth prevents the classic bug where the monster can see through a wall that blocks the flashlight.

---

## Co-op Roles — and Why Solo Cannot Work

The three roles are **Hearthkeeper**, **Gatherer**, and **Lookout**, with **Crafter** as a rotating fourth. They are not classes — there is no role selection UI, no perks, no assignment. They emerge because the mechanics make them emerge. That distinction matters: assigned roles feel like homework, emergent roles feel like the group's own idea.

### The six hard gates

**Gate 1 — The Hearth cannot be left alone.** It burns 2/s (3/s on Night 5). Feeding it is 5 Wood → 30 fuel, 4 seconds of channel time. A 120s night needs 240 fuel = 8 feeding trips. Whoever does that job cannot be more than ~20 seconds from the fire at any point. **One player is pinned to base by arithmetic.**

**Gate 2 — The relight relay.** A Cold Wick can only be relit by a burning Brand, and a Brand lasts 30 seconds. The outer Lantern Posts sit 45 studs from the Hearth; Placed Lanterns are commonly 100–140 studs out. A round trip to a far lantern is 25–35 seconds at walk speed — so a solo relight of a far lantern means the Brand dies in your hand. Two players — one holding position at a midpoint with a second Brand — turns an impossible job into a routine one. **Distance × Brand lifetime is a two-person equation.**

**Gate 3 — The grapple is inescapable alone.** There is no struggle minigame, no button-mash, no self-escape. A grappled player is a dead player in 5 seconds unless a *teammate* holds a Focused Beam on Wick for 2 seconds or throws a Flare within 18 studs. **This is the absolute gate.** A solo player who is grappled once has lost that Downed state, and 60 seconds later has lost the character.

**Gate 4 — CoCraft.** The three tier-2 recipes (Reinforced Shutter, Signal Flare, Watchtower Beacon) require `CoCraft`: two players standing within 10 studs of the Workbench simultaneously, both holding the interact, for 6 seconds. The Signal Flare — the item that saves grappled teammates — literally cannot be made alone. And the Workbench generates +25 noise/s, so two players are standing still and loud together. That is a deliberately vulnerable, deliberately social moment.

**Gate 5 — The Lookout's information asymmetry.** Wick's position is **never** broadcast to normal players. It is sent only to:
- whoever is standing on the **Watchtower** (roof of the Lodge, craftable, one per run)
- any **Snuffed** (spectating) player

The Watchtower gives its occupant a HUD marker with Wick's bearing, distance, and Wax percentage. But standing on the Watchtower means you are elevated, lit, at interest weight, and you are not gathering, not feeding, and not crafting. You are contributing *only information*, which is worthless unless you say it out loud. **This is the voice-chat engine of the entire game, and it is one part of the map.**

**Gate 6 — The ghost lookout.** A Snuffed player is not benched. They spectate freely and get one ability: `RequestMarkWick` (8s cooldown) places a 6-second world marker on Wick's position visible to all living players. Dead players become the most valuable information source in the group, they return at the next dawn, and nobody ever sits out a 24-minute run. This is the most important quality-of-life decision in the design for a young audience.

### The arithmetic of failure for one player

Total Hearth fuel required across a full 5-night run:

```
Night 1: 120s × 2.0 = 240      Day burn (5 × 150s × 0.5) = 375
Night 2: 120s × 2.0 = 240      Revival costs (typical)   = 40-80
Night 3: 120s × 2.5 = 300      ────────────────────────────────
Night 4: 120s × 2.5 = 300      TOTAL  ≈ 1,995 fuel
Night 5: 180s × 3.0 = 540      ≈ 333 Wood  ≈ 56 trees (6 Wood each, 12 with Stone Axe)
```

Plus roughly 40 Wood, 30 Stone, 36 Tallow, 12 Flint and 6 Iron in crafting costs across the run. Against **750 seconds of total day time**, one player cannot chop 56 trees *and* harvest Tallow *and* mine Stone *and* loot four wrecks *and* craft *and* place lanterns *and* feed the fire *and* relight *and* be the lookout. Four players can do it comfortably. Three can do it if they talk. The design does not tell players to cooperate — it hands them a spreadsheet that only balances if they do.

---

## Resources and Crafting

### Five resources

| Resource | Source | Nodes on map | Yield | Respawn | Used for |
|----------|--------|--------------|-------|---------|----------|
| **Wood** | Pine and Birch trees (chop) | 62 | 6 per tree (12 with Stone Axe) | at dawn | Hearth fuel, everything |
| **Stone** | Boulders (mine) | 24 | 4 per boulder | at dawn | Reinforcements, Stone Axe, Hearth tiers |
| **Tallow** | Wax Caps — pale fungus clusters on the lakeshore and dead trunks (harvest, no tool) | 34 | 3 per cluster | at dawn | Lantern fuel, poultices |
| **Flint** | Gravel piles on the lakeshore and in the boulder field (harvest) | 14 | 2 per pile | at dawn | Brands, Flares, Stone Axe |
| **Iron Scrap** | 4 fixed Wreck sites (loot, 3s channel) | 4 | 3 per wreck | at dawn | Tier-2 only. Scarce by design. |

Tallow is thematically load-bearing: the forest is full of wax fungus *because* Wick lives here. You are refuelling your lanterns with the monster's own leavings.

### Eight recipes — that is the entire tech tree

**Tier 1 (Workbench, one player, 3s):**

| # | Item | Cost | Effect |
|---|------|------|--------|
| 1 | **Lantern Refill** | 2 Tallow | +60 Hand Lantern fuel |
| 2 | **Placed Lantern** | 3 Wood + 2 Tallow | Static light, Range 28, Fuel 120. Cap 6 active. Wick bait. |
| 3 | **Brand** | 1 Wood + 1 Flint | 30s torch. Relights Cold Wicks. Throwable: 15 Wax damage. |
| 4 | **Tallow Poultice** | 3 Tallow | Instantly revive a Downed teammate, or heal yourself 40 HP |
| 5 | **Stone Axe** | 3 Wood + 4 Stone | Chop yield ×2, chop noise −40%. One per player. |

**Tier 2 (Workbench, CoCraft — two players, 6s):**

| # | Item | Cost | Effect |
|---|------|------|--------|
| 6 | **Reinforced Shutter** | 6 Wood + 4 Stone + 1 Iron | Seals one Lodge window (3 slots). Wick must spend 8s breaking it. |
| 7 | **Signal Flare** | 2 Flint + 1 Iron + 2 Tallow | Throwable. 12s of intense light. Freezes Wick in an 18-stud radius. **Breaks a grapple.** |
| 8 | **Watchtower Beacon** | 8 Wood + 3 Stone + 2 Iron + 4 Tallow | Builds the Lodge-roof lookout post. One per run. Reveals Wick to its occupant. |

Plus two **Hearth upgrades** purchased directly at the Hearth (not the Workbench): T2 for 12 Wood + 8 Stone, T3 for 20 Wood + 12 Stone + 2 Iron.

Five resources, eight recipes, two upgrades. A player can read the entire crafting system in fifteen seconds, which is the correct size for v1.

---

## Base Building

**Scope decision: slot-based, not freeform.** No grid placement, no rotation UI, no building mode. The group has exactly one structure, the **Lodge**, with exactly five upgrade slots, plus the Hearth's three tiers and up to six Placed Lanterns. That is the whole construction game.

| Slot | Location | Upgrade | Effect |
|------|----------|---------|--------|
| WindowSlot_N | Lodge north wall | Reinforced Shutter | Wick needs 8s to break through instead of 0 |
| WindowSlot_E | Lodge east wall | Reinforced Shutter | Same |
| WindowSlot_W | Lodge west wall | Reinforced Shutter | Same |
| DoorSlot | Lodge south face, 8 studs wide | Barred Door (4 Wood + 2 Stone) | Wick needs 10s to break through; players can still open from inside |
| WatchtowerSlot | Lodge roof center | Watchtower Beacon | Enables the Lookout role |

**Why the Lodge matters at all.** It is not a safe room — Wick will break in, and the interior is unlit unless someone brings a light. It is a **time purchase**: three shutters and a barred door buy the group 34 seconds of Wick being busy with carpentry instead of with people. On Night 5 those 34 seconds are the run.

Shutter HP is time, not hit points: `ReinforceSlot` parts carry a `BreakTime` attribute, and `StructureManager` runs the break as a server timer with a visible progress state (wood splinters VFX, escalating crack sounds) so players can hear exactly how long they have.

**The Cellar Hatch** (pre-built, no upgrade) in the Lodge floor is a Concealment volume: 12 × 8 × 7 studs, holds up to 3 players, halves noise, blacklists occupants from Wick's LOS — and fills Gloom at 4/s because it is pitch dark. A place to survive 40 seconds, not a place to win.

---

## Night Escalation

One rule change per night, plus four tuned numbers. All of it lives in `Config.NIGHTS`, so the entire difficulty curve is one table a designer can retune without touching a script.

| | **Night 1** | **Night 2** | **Night 3** | **Night 4** | **Night 5** |
|---|---|---|---|---|---|
| Night duration | 120s | 120s | 120s | 120s | **180s** |
| Wick start Wax | 100 | 120 | 140 | 160 | **200** |
| walkSpeed | 9 | 10 | 11 | 12 | 13 |
| chaseSpeed | 13 | 15 | 17 | 19 | **21** |
| freezeDuration | 4.0s | 4.0s | 4.0s | 3.0s | **2.0s** |
| Hearth burn rate | 2.0/s | 2.0/s | 2.5/s | 2.5/s | **3.0/s** |
| Hearth is a target | never | below 25% fuel | below 40% | below 60% | **always** |
| Atmosphere Density | 0.12 | 0.16 | 0.20 | 0.24 | 0.26 |
| OutdoorAmbient | (10,14,20) | (9,12,18) | (7,10,15) | **(4,6,10)** | (4,6,10) |
| Gloom fill rate | 8/s | 9.6/s | 9.6/s | 11/s | 12/s |
| **NEW RULE** | *(tutorial)* Wick snuffs exactly one outer light, then retreats early. It ignores players entirely unless they beam it. | **Hearth awareness.** Wick will approach the Hearth once it drops below 25%, teaching the group that the fire is a target. | **The Second Pass.** After snuffing every light it can reach, Wick does not retreat — it turns and hunts players directly for the remainder of the night. | **Wax Bloom.** Wick leaves a `WaxPool` part every 8 studs it walks. Stepping in one: 40% slow for 3s and +25 noise. Its route becomes a hazard map that persists all night. | **The Long Burn.** 180-second night, 3/s Hearth burn, the Hearth is always its top target, and the freeze window is halved. Everything the group has learned, all at once. |

Night 1's rule is the most important one in the table: it is a **teaching night disguised as a threat**. Wick takes one lantern and leaves, players watch it happen from safety, and in twelve seconds of silent observation they learn what the monster wants, that it glows, that it hums, and that light is currency. No tutorial text exists in this game.

---

## Multiplayer / Session Structure

### Lobby and ready-up

The lobby is a physical location: a lit ranger station platform at `(0, 500, 1200)`, well outside the map, reached by the default SpawnLocation. 6 **Ready Pads** in an arc, a rules board, and the countdown display.

```
Player joins                → teleport to Lobby, LobbyGui shown
Steps on a Ready Pad        → RequestReady{ready=true}, pad lights amber, name lists as READY
2+ players ready            → 60s soft countdown begins (visible, audible)
3+ players ready            → countdown snaps to 15s
All present players ready   → countdown snaps to 5s
Countdown hits 0            → SessionManager.StartRun()
```

`StartRun()`: sets `RunState = Active`, seeds resource nodes, sets every player's `PlayerState = Alive` with full HP/Stamina/Lantern and 0 Gloom, teleports all Ready players to the Camp arrival ring (6 fixed CFrames around the Hearth), sets the Hearth to T1 with 120 starting fuel, and calls `CycleManager.BeginNight(1)`.

Minimum 1 player (a solo run is technically permitted and will lose — it is a learning experience, not a supported mode). Recommended 3–6. `Players.MaxPlayers = 6`.

### Player death mid-run

Three states, and nobody is ever benched:

| State | Trigger | Can do | Recovery |
|-------|---------|--------|----------|
| **Alive** | default | everything | — |
| **Downed** | HP reaches 0, or a grapple completes its 5s drink | Crawl at WalkSpeed 6, no sprint, no harvest, no craft, lantern forced Off. A 60s `WaxBleed` timer runs. Can still *talk* — and a crawling player screaming directions is excellent. | A teammate interacts for 3s (free), or uses a Tallow Poultice (instant). Revived at 40 HP. Being dragged into the Hearth safe radius pauses the bleed timer. |
| **Snuffed** | WaxBleed timer expires while Downed | Free-fly spectator camera. Sees Wick at all times. `RequestMarkWick` on an 8s cooldown places a 6s world marker visible to all living players. | **Returns automatically at the next DAWN**, at the Hearth, full HP — and the Hearth pays **20 fuel**. |

The design intent is explicit: death should cost the *team a resource*, not cost the *player their evening*. A Snuffed player is immediately promoted to the most informationally powerful position in the game, which is both fun and, on Night 4, genuinely decisive.

### Run end

| Outcome | Condition |
|---------|-----------|
| **SURVIVED** | Dawn of Night 5 arrives with the Hearth lit. Win sequence plays (see Signature Moment 5). |
| **WIPED** | During a Blackout, every player is simultaneously Downed or Snuffed with no Alive player remaining. |

Either way: `RunEnded` broadcast → 14s results panel (nights survived, Wood gathered, lanterns relit, Wick freezes, revives performed, Wax burned off Wick) → all players teleported to the Lobby → all Ready Pads reset → world reset (nodes restored, Placed Lanterns and Cold Wicks destroyed, shutters reset, Hearth back to T1, Wick returned to the Waxworks and set Dormant) → lobby idle.

**Late joiners** during an active run: teleported to the Lobby with a `RUN IN PROGRESS — joining at dawn` panel, given free spectator camera, and inserted at the next DAWN at full HP with **no fuel cost** (the fuel cost applies only to revivals, never to newcomers — punishing someone for joining is bad manners).

### Persistence (deliberately minimal for v1)

`DataManager` stores one small DataStore record per player: `{bestNight, runsPlayed, runsSurvived, totalWoodGathered, totalRevives}`. Displayed on the lobby board only. **No unlocks, no currency, no progression, no meta-game.** Every run starts identical. That is a v1 decision and it is the right one — a progression system would take a full cycle to build and would dilute the tuning of the one map we have.

---

## Service Architecture

```
ServerScriptService/
  Main                    (Script)       -- bootstrap, init order, PlayerAdded/Removing
  SessionManager          (Script)       -- lobby, ready-up, run start/end, teleports, spectators
  CycleManager            (Script)       -- day/dusk/night/dawn state machine, night counter, escalation
  HearthManager           (Script)       -- Hearth fuel, tiers, feeding, safe zone, Blackout
  LightManager            (Script)       -- light registry, fuel ticking, snuffing, per-player illumination solve
  NoiseManager            (Script)       -- noise meters, NoisePing creation/decay, GetPings()
  SurvivalStats           (Script)       -- HP, Stamina, Gloom, CarryWeight, Downed/Snuffed, revives
  ResourceManager         (Script)       -- harvest nodes, yields, dawn respawn, inventory authority
  CraftingManager         (Script)       -- recipe validation, CoCraft, crafted-object placement
  StructureManager        (Script)       -- Lodge slots, shutter break timers, Watchtower, Cellar Hatch
  WickAI                  (Script)       -- monster state machine, interest solver, pathfinding, grapple
  DataManager             (Script)       -- DataStore (pcall-wrapped), lightweight stats
  Validator               (ModuleScript) -- shared server-side payload validation helpers

ReplicatedStorage/
  Modules/
    Config                (ModuleScript) -- every tunable constant in the game
    GameEnums             (ModuleScript) -- Phase, WickState, PlayerState, ResourceId, LightKind
    RecipeBook            (ModuleScript) -- the 8 recipes + 2 Hearth upgrades
    Shared                (ModuleScript) -- MakeVisionParams, distance helpers, formatters, clamps
  RemoteEvents/
    [22 RemoteEvents + 2 UnreliableRemoteEvents -- see table below]
  Prefabs/
    PlacedLantern         (Model)
    Brand                 (Model)
    SignalFlare           (Model)
    ReinforcedShutter     (Model)
    WatchtowerBeacon      (Model)
    WaxPool               (Model)
    ColdWickMarker        (Model)

ServerStorage/
  Wick                    (Model)        -- the R6 rig, spawned by WickAI at run start

StarterPlayer/
  StarterPlayerScripts/
    InputController       (LocalScript)  -- keyboard + gamepad + mobile -> remotes
    HUDController         (LocalScript)  -- bars, inventory, phase timer, teammate list
    LanternController     (LocalScript)  -- lantern visual, beam aim, mode display
    CraftingUIController  (LocalScript)  -- workbench menu, CoCraft prompt
    WickPresenceController(LocalScript)  -- hum volume/pitch, Watchtower + spectator markers
    GloomController       (LocalScript)  -- vignette, desaturation, heartbeat
    SpectatorController   (LocalScript)  -- free camera when Snuffed, MarkWick
    CameraController      (LocalScript)  -- third-person default, beam-aim zoom
    MobileControls        (LocalScript)  -- touch button wiring

StarterGui/
  SurvivalHUD             (ScreenGui, DisplayOrder 10)
  CraftingGui             (ScreenGui, DisplayOrder 12)
  LobbyGui                (ScreenGui, DisplayOrder 15)
  MobileControlsGui       (ScreenGui, DisplayOrder 8)
  OverlayGui              (ScreenGui, DisplayOrder 18)
  [NarrativeGui           (ScreenGui, DisplayOrder 20) -- created by story-teller]

Workspace/
  Map/
    CampClearing/
    NorthPinewood/
    EastBoulderField/
    SouthLakeshore/
    WestDeadfall/
    Waxworks/
    TrailRing/
    Terrain/
    Boundary/
  Lobby/
  Runtime/              -- empty folder; runtime-spawned lights, pools, markers land here
```

### Scripts detail

**Main** (Script) — ServerScriptService
- Purpose: single deterministic init point. Roblox does not guarantee script order; this one does.
- Key functions: `Init()` requires Config/GameEnums/Shared, verifies every RemoteEvent exists (creating any that are missing), then initialises managers in dependency order: `SurvivalStats → ResourceManager → LightManager → NoiseManager → HearthManager → StructureManager → CraftingManager → WickAI → CycleManager → SessionManager`. Handles `PlayerAdded` (profile creation, lobby teleport) and `PlayerRemoving` (cleanup, connection disconnect).
- Depends on: everything. Every manager exposes an `Init()` and is required as a module-like Script via a shared `_G`-free pattern: each manager writes its API table to a `BindableFunction`-free internal registry held by Main. (Simplest correct approach: make the managers ModuleScripts under a `ServerScriptService/Systems` folder and keep `Main` as the only true Script. **Implementation note for luau-scripter: do it that way** — `Main` is the Script, the 11 managers are ModuleScripts in `ServerScriptService/Systems/`, `Validator` sits alongside them. The names above stay identical.)

**SessionManager** — lobby state, ready pads (`LobbyPad` tag), countdown, `StartRun()` / `EndRun(result)`, world reset, spectator assignment, late-joiner handling, results payload assembly.

**CycleManager** — the phase state machine. `BeginNight(n)` applies `Config.NIGHTS[n]` to Lighting, HearthManager burn rate, and WickAI parameters, then runs `DAY → DUSK → NIGHT → DAWN` on a single `task.wait`-free heartbeat driven by `RunService.Heartbeat` with an accumulator (never `while true do wait(1)`). Broadcasts `CycleChanged` on every phase transition and once per second during a phase for timer sync. Owns the DAWN sequence: node respawn, Snuffed revivals (charging the Hearth 20 each), escalation application, Dawn Report.

**HearthManager** — Hearth fuel tick, `FeedHearth(player, resource)` with 4s channel and interruption, tier upgrades, `IsInSafeZone(position)` used by WickAI and SurvivalStats, and the Blackout sequence (kill all lights, 1.5s of absolute dark, notify WickAI, start the 45s timer, allow relight).

**LightManager** — the registry. `Register(entry)` / `Unregister(id)`, per-frame fuel ticking with accumulator, `Snuff(id)` (converts to Cold Wick, fires `LightStateChanged`), `Relight(id, brandOwner)`, `SolveIllumination()` every 0.25s writing `isLit` onto each player's state, `GetLightInterests()` for WickAI. **Single source of truth for every light in the game** — no script anywhere else creates or destroys a PointLight that affects gameplay.

**NoiseManager** — `AddNoise(player, amount)`, decay tick, ping creation above threshold 45, `GetPings()` with weight decay, `Shout(player)` with cooldown.

**SurvivalStats** — per-player `{hp, stamina, gloom, carryWeight, isLit, state, bleedTimer}`. Ticks stamina/gloom/HP at 10Hz. Owns `SetState(player, newState)` for Alive/Downed/Snuffed transitions, `Revive(player, byWhom, instant)`, and authoritative `Humanoid.WalkSpeed` writes (client never sets its own speed). Streams to owner via `PlayerStatsStream` (UnreliableRemoteEvent) at 10Hz.

**ResourceManager** — node registry from CollectionService tags, `Harvest(player, node)` with distance ≤ 12, tool check, stamina check, per-node cooldown, yield roll, carry-weight enforcement, noise emission; dawn respawn; inventory as server-owned tables, synced via `InventoryUpdated`.

**CraftingManager** — `Craft(player, recipeId)` validating proximity to a `Workbench`-tagged part (≤ 10 studs), full inventory cost, active-object caps (6 Placed Lanterns, 1 Watchtower, 1 Stone Axe per player), and CoCraft partner presence. Owns the 6s CoCraft channel with `CoCraftPrompt` progress broadcasts. Clones from `ReplicatedStorage/Prefabs` into `Workspace/Runtime` and registers lights with LightManager.

**StructureManager** — reinforcement slots (`ReinforceSlot` tag with `SlotType` and `BreakTime` attributes), shutter installation, Wick's break timers with audible stages, Watchtower occupancy detection (drives who receives Wick's position), Cellar Hatch concealment volume.

**WickAI** — the state machine above. Spawns the rig from ServerStorage at `StartRun`, runs a 0.4s decision tick and a 0.3s detection tick (separate accumulators, not separate loops), holds the Wax value, and owns the grapple. All connections stored in a table and disconnected on `EndRun`. Broadcasts `WickPresenceStream` (hum intensity to everyone; position only to Watchtower occupants and Snuffed players) and `WickEvent` for discrete moments.

**DataManager** — one `GetAsync`/`SetAsync` pair per player, both `pcall`-wrapped, with a session cache and a `BindToClose` flush. Never blocks gameplay: if the DataStore fails, the run proceeds with default stats.

---

## RemoteEvents

All gameplay-affecting state is server-owned. **No RemoteFunctions anywhere** — they can hang a client indefinitely and there is no request here that needs a return value.

### Client → Server

| Event | Payload | Server validation |
|-------|---------|-------------------|
| `RequestReady` | `{ready: boolean}` | `typeof(ready) == "boolean"`; RunState must be `Lobby`; player must be standing on a `LobbyPad` |
| `RequestHarvest` | `{nodeId: string}` | node exists and is tagged `HarvestNode`; distance ≤ 12; node cooldown expired; player state `Alive`; stamina ≥ 8; carry weight below cap; required tool for node type |
| `RequestCraft` | `{recipeId: string}` | recipeId exists in RecipeBook; distance to a `Workbench` part ≤ 10; every cost line satisfied by server-side inventory; active-object cap not exceeded; if `recipe.coCraft` then a second Alive player within 10 studs also holding interact |
| `RequestFeedHearth` | `{resource: string}` | `resource == "Wood"` or `"Tallow"`; inventory ≥ 5 units; distance to Hearth ≤ 10; not already channelling; Hearth not at max fuel |
| `RequestHearthUpgrade` | `{tier: number}` | `tier == 2 or 3`; `tier == currentTier + 1`; full cost in inventory; distance ≤ 10 |
| `RequestPlaceObject` | `{itemId: string, position: Vector3}` | itemId is a placeable the player owns; `(position - playerPos).Magnitude <= 8`; each Vector3 component is finite and within map bounds; downward raycast finds valid ground within 6 studs; no overlap via `GetPartBoundsInBox`; active cap not exceeded |
| `RequestLanternState` | `{mode: number}` | `mode` ∈ {0,1,2}; player state `Alive`; if mode ≠ 0 then lantern fuel > 0. **Server owns fuel — client cannot set it.** |
| `RequestSprint` | `{sprinting: boolean}` | boolean; server decides whether the sprint is granted based on stamina and Winded state, then writes `Humanoid.WalkSpeed` itself |
| `RequestInteract` | `{targetId: string, action: string}` | target exists, is tagged with an interactable tag, distance ≤ 10; `action` ∈ a server-side whitelist per tag; player state permits the action (a Downed player can do nothing but crawl) |
| `RequestShout` | `{}` | player state `Alive`; 20s cooldown enforced server-side |
| `RequestThrow` | `{itemId: string, direction: Vector3}` | itemId ∈ {`Brand`, `SignalFlare`}; player owns one; `direction.Magnitude` between 0.9 and 1.1 (reject non-unit vectors); every component finite; 1s cooldown |
| `RequestMarkWick` | `{}` | player state is `Snuffed`, **or** player is the current Watchtower occupant; 8s cooldown |
| `RequestRevive` | `{targetUserId: number}` | target is a player in state `Downed`; distance ≤ 8; 3s channel (or instant with a Tallow Poultice in inventory); reviver is `Alive` |

Every handler follows the same shape and Validator provides the primitives: `Validator.Number`, `Validator.Boolean`, `Validator.String`, `Validator.FiniteVector3`, `Validator.UnitVector3`, `Validator.TaggedInstance(id, tag)`, `Validator.WithinRange(player, pos, max)`, `Validator.RateLimit(player, key, seconds)`. **Every remote is rate-limited** — a default of 10 calls/second per player per remote, tighter where specified.

### Server → Client

| Event | Type | Payload | Recipients |
|-------|------|---------|------------|
| `CycleChanged` | RemoteEvent | `{phase: string, night: number, timeRemaining: number, nightRules: {newRule: string, fogDensity: number}}` | all |
| `HearthUpdated` | RemoteEvent | `{fuel, maxFuel, tier, lightRange, safeRadius, lit: boolean}` | all |
| `PlayerStatsStream` | **UnreliableRemoteEvent** | `{hp, stamina, gloom, carryWeight, maxWeight, isLit, state, bleedTimer}` | owner only, 10Hz |
| `InventoryUpdated` | RemoteEvent | `{wood, stone, tallow, flint, iron, lanternFuel, tools: {string}}` | owner only, event-driven |
| `LightStateChanged` | RemoteEvent | `{lightId, kind, position, lit: boolean, fuel, maxFuel}` | all |
| `WickPresenceStream` | **UnreliableRemoteEvent** | `{humIntensity: number, humPitch: number, waxPercent: number, position: Vector3?}` — `position` is `nil` for everyone except Watchtower occupants and Snuffed players | all, 5Hz |
| `WickEvent` | RemoteEvent | `{event: string, position: Vector3, targetUserId: number?}` — event ∈ `Snuffed / Frozen / Grabbed / Released / Melt / Bloom / Breaking / Retreat` | all |
| `PlayerStateChanged` | RemoteEvent | `{userId, state: string, bleedTimer: number?}` | all (teammate list needs it) |
| `NotifyToast` | RemoteEvent | `{kind: string, text: string, duration: number}` | targeted or all |
| `CoCraftPrompt` | RemoteEvent | `{recipeId, progress: number, partnerUserId: number?}` | the two participants |
| `ShoutPing` | RemoteEvent | `{userId, position: Vector3, expires: number}` | all |
| `WickMarkPing` | RemoteEvent | `{position: Vector3, expires: number, fromUserId: number}` | all Alive |
| `StructureUpdated` | RemoteEvent | `{slotId, slotType, installed: boolean, breakProgress: number?}` | all |
| `LobbyUpdated` | RemoteEvent | `{players: {{userId, name, ready}}, countdown: number?}` | all in lobby |
| `RunStarted` | RemoteEvent | `{night: number, playerCount: number}` | all |
| `RunEnded` | RemoteEvent | `{result: string, nightsSurvived: number, stats: {...}}` | all |
| `BlackoutTriggered` | RemoteEvent | `{duration: number}` | all |
| `DawnReport` | RemoteEvent | `{night, woodGathered, lanternsRelit, wickFreezes, revives, waxBurned, revivedPlayers: {number}}` | all |

**22 RemoteEvents + 2 UnreliableRemoteEvents.** The two streams carry all the high-frequency traffic; everything else is event-driven, which keeps replication cost low enough for a 6-player mobile session.

---

## World Layout

**Coordinate system.** Ground plane top at `Y = 0`. Map centre at the origin. Playable area **640 × 640 studs**, ringed by a 40-stud band of dense trees backed by invisible boundary walls at `±340`. Lobby is off-map at `Y = 500`.

---

### CAMP CLEARING

- **Position:** `Vector3(0, 0, 0)` — centre
- **Dimensions:** 140 × 140 studs, canopy opening overhead (no ceiling, but ringed by 34-stud trees so it reads as a room)
- **Floor:** Grass `#3A4436`, with a trodden `LeafyGrass` `#4A4436` ring 24 studs across around the Hearth
- **Walls:** none — the enclosure is the tree ring at radius 70
- **Accents:** WoodPlanks `#7A6A52` (Lodge, Workbench, Lantern Posts), Slate `#6E6A64` (fire ring stones)
- **Lighting:**
  - Hearth PointLight at `(0, 3, 10)` — Range 60/75/95 by tier, Brightness 2.4–3.2, Color `#E08A3C`, Shadows true
  - Lantern Post PointLights at `(-45, 9, -45)`, `(45, 9, -45)`, `(-45, 9, 45)`, `(45, 9, 45)` — Range 32, Brightness 2.0, Color `#E08A3C`, **start unlit**
  - Lodge interior PointLight at `(0, 12, -18)` — Range 20, Brightness 0.8, Color `#E0A860`, **starts unlit** (players must bring light inside)
- **Part count:** ~226
- **Connections:** four 8-stud trails leave at N `(0,0,-70)`, E `(70,0,0)`, S `(0,0,70)`, W `(-70,0,0)`
- **Key objects:**
  - **The Lodge** — 32 × 16 × 24 studs, centre `(0, 8, -18)`. Door (8 wide × 10 high) in the south face at `(0, 5, -6)`. Three windows: N `(0,7,-30)`, E `(16,7,-18)`, W `(-16,7,-18)`, each 6 × 5. Interior ceiling 14. Roof centre `(0, 17, -18)` = WatchtowerSlot. Cellar Hatch in the floor at `(8, 0.4, -24)` leading to a 12 × 8 × 7 concealment volume beneath at `(8, -4, -24)`.
  - **The Hearth** — stone ring radius 8 at `(0, 1, 10)`; central Neon `#E08A3C` flame cluster (4 parts) at `(0, 2.5, 10)`; a scaling ember VFX anchor at `(0, 4, 10)`. Tagged `Hearth`.
  - **The Workbench** — 10 × 5 × 4 at `(16, 2.5, 4)`. Tagged `Workbench`. Two `CoCraftStand` marker parts at `(13,0.2,1)` and `(19,0.2,1)`.
  - **Lantern Posts** ×4 — 1 × 12 × 1 posts with hanging lantern boxes, at the four positions above. Tagged `LanternPost` + `LightSource`.
  - **Arrival ring** — six invisible `ArrivalPoint` parts on a radius-14 circle around the Hearth.
  - **CampSpawn** — a SpawnLocation at `(0, 1, 18)` with `Enabled = false`, used purely as a position reference.
- **CHARACTER:** A ranger station somebody set up in a hurry and then abandoned politely — tools stacked, a kettle still hanging, a bedroll rolled and tied. Nothing is smashed. Nothing suggests violence. Whoever was here *left*, which is more unnerving than a struggle. The clearing is the only place in Wickwood where the light is warm, and in the first thirty seconds of the game it should read as genuinely pleasant. That is the trap the whole game is built on.
- **LIFE:**
  - *Ambient:* Hearth crackle loop (volume and ember VFX rate scale with Hearth tier); a Lantern Post whose fuel drops below 20% flickers on a 0.4–1.1s random interval; laundry line sways on an 11s tween; cabin door bangs once every 25–40s in the wind; crickets during DAY, absolute insect silence during NIGHT (the silence is the cue).
  - *Reactive:* stepping within 10 studs of the Hearth raises the ember rate for 2s and plays a soft flare; opening the Lodge door creaks and emits +15 noise; standing on the Watchtower plays a single low wind tone and lifts the camera FOV by 4.
  - *One-time:* the very first DUSK, every bird in the clearing leaves at once — a 40-bird burst VFX plus wingbeats — three seconds before the hum begins.

---

### NORTH PINEWOOD

- **Position:** `Vector3(0, 0, -190)`
- **Dimensions:** 260 × 200 studs
- **Floor:** Grass `#2E3730`, needle-litter patches in LeafyGrass `#38402E`
- **Walls:** trunk mass — Wood `#3A3228`, 70 conifers
- **Accents:** CorrodedMetal `#5A5048` (the Ranger Truck wreck)
- **Lighting:** no fixed lights. Moonlight only, and the canopy kills most of it. Effective visibility at night: ~22 studs.
- **Part count:** ~342 (70 trees × 4 parts = 280, 40 deadfall logs and rocks, 22 wreck)
- **Connections:** south trail to Camp at `(0,0,-70)`; east trail to Boulder Field at `(130,0,-160)`; west trail to Deadfall at `(-130,0,-150)`; a narrow (8-stud) north trail to the Waxworks at `(120,0,-260)`
- **Key objects:** 70 `TreeNode` conifers, 28–45 studs tall (trunk cylinder + 3 stacked cone/wedge foliage tiers), minimum 10 studs apart along trails. **The Old Mother** at `(-20, 0, -230)` — a 58-stud unchoppable pine, 6 studs thick, that groans on a 9s loop when a player is within 25 studs. **Crashed Ranger Truck** at `(-60, 0, -215)` — Iron wreck site, 22 parts, cab door hanging open.
- **CHARACTER:** The richest zone and the worst place to be. Trunks stand close enough that you navigate by trail rather than by landmark, and every sightline dies at 25 studs. You will hear Wick's hum in here long before you can locate it, and the hum has no directional cue you can trust because the trunks bounce it. This is where players learn to stop chopping and hold their breath.
- **LIFE:**
  - *Ambient:* canopy creak every 8–14s; pine needles drift continuously (VFX, Rate 3); an owl call every 20–30s during DAY that stops entirely at NIGHT.
  - *Reactive:* first entry per run triggers a startled bird burst from the canopy directly overhead; chopping any tree causes 3 nearby trees to shed a needle puff; walking near the Old Mother triggers its groan.
  - *One-time:* on Night 3, the first time a player enters after Wick has entered, a single Wax Pool is already there waiting at the trail junction.

---

### EAST BOULDER FIELD

- **Position:** `Vector3(210, 0, 40)`
- **Dimensions:** 200 × 220 studs
- **Floor:** Slate `#5C5A56`, gravel patches `#6E6A62`
- **Walls:** open — 60 boulders 4–14 studs across provide cover, not enclosure
- **Accents:** Rock `#4E4A46`, flint gravel `#7A7268`
- **Lighting:** the brightest zone at night. No canopy, so full moonlight. Night visibility ~70 studs.
- **Part count:** ~192 (60 boulders × 2, 15 trees × 4, 12 flint piles)
- **Connections:** west trail to Camp at `(70,0,0)`; north trail to Pinewood at `(130,0,-160)`; south trail to Lakeshore at `(150,0,140)`
- **Key objects:** 24 `RockNode` boulders (mineable, Stone), 12 `FlintNode` gravel piles, 36 decorative boulders, 15 scrubby pines. A natural stone shelf at `(260, 6, 20)` with a 60-stud view back toward camp — an unofficial lookout that costs nothing but gives no HUD marker.
- **CHARACTER:** Exposed, cold, and therefore safe. You can see two hundred studs in any direction and Wick's candles are visible across the whole field the moment it enters. The tradeoff is that there is nowhere to break line of sight, so if it decides to come for you the only answer is your lantern fuel. Players who understand the game gather Stone here at night; players who do not, never come here after dark.
- **LIFE:**
  - *Ambient:* thin wind whistle loop (this is the only zone with real wind); a small rockslide settles somewhere in the field every 20–35s with a stone-tumble sound.
  - *Reactive:* mining a boulder sends a dust puff and dislodges two small rocks that slide 3 studs; walking on gravel has a distinctly louder footstep audio zone.
  - *One-time:* from Night 3, one specific boulder at `(238, 4, -30)` is a **Wax Cairn** — it is pale, it is slightly translucent, and it *breathes* on a 4s cycle. Nothing happens if you touch it. It is simply wrong, and every group that finds it talks about it.

---

### SOUTH LAKESHORE

- **Position:** `Vector3(-40, 0, 210)`
- **Dimensions:** 260 × 200 studs (lake surface 200 × 150)
- **Floor:** shore Sand `#6E6454`; lake surface a flat SmoothPlastic plane at `Y = -0.5`, `#2A3A44`, Transparency 0.35, Reflectance 0.45
- **Walls:** reed banks (40 thin parts), low shore rocks
- **Accents:** CorrodedMetal `#5A5048` (rowboat), Tallow White `#EDE6D2` (Wax Cap clusters)
- **Lighting:** no fixed lights. **The lake's Reflectance 0.45 is a gameplay system, not decoration** — it catches Wick's candle light and shows it to the camp before Wick clears the treeline.
- **Part count:** ~196 (lake 6, 20 trees × 4, 40 reeds, 30 shore rocks, 24 Wax Caps, 16 rowboat)
- **Connections:** north trail to Camp at `(0,0,70)`; north-east trail to Boulder Field at `(150,0,140)`; west trail to Deadfall at `(-150,0,140)`
- **Key objects:** 18 `TallowNode` Wax Cap clusters along the waterline (pale translucent fungus domes, 3–5 parts each), 6 `FlintNode` gravel beds, 20 shore pines, **the Rowboat** at `(-110, 0, 220)` — Iron wreck, half-swamped, 16 parts. A `WaterVolume` region from `Y = -6` to `Y = 0.5` that applies the wade modifiers.
- **CHARACTER:** Wide, flat, slow, and completely without cover — a zone that trades your mobility for your visibility. Wading halves your speed and doubles your noise, so the Tallow you need most is guarded by the mechanic you can least afford at night. The rowboat is pulled up the shore and tied, which means someone came *back*. The lake itself never ripples unless a player disturbs it, and its stillness is what makes the reflection trick work.
- **LIFE:**
  - *Ambient:* water lap loop; a distant splash somewhere out on the water every 15–25s with no visible source; the rowboat rocks on a 7s tween; loons during DAY, nothing at NIGHT.
  - *Reactive:* wading produces ripple VFX and a loud splash zone; harvesting a Wax Cap emits a thick white spore puff that lingers 4s and briefly raises your Gloom fill (it is wax dust, and it clings); throwing a Brand into the water snuffs it instantly with a hiss.
  - *One-time / signature:* the first time Wick moves within 120 studs of the lake at night, its candle light lands on the water plane and is visible from Camp as a moving orange smear. See Signature Moment 2.

---

### WEST DEADFALL

- **Position:** `Vector3(-210, 0, -40)`
- **Dimensions:** 200 × 240 studs
- **Floor:** Ground `#3E382E`, ash patches `#4E4A44`
- **Walls:** 55 dead trees — bare Wood `#5A5248`, no foliage, many leaning or fallen
- **Accents:** Tallow White `#EDE6D2` (Wax Caps on trunks), CorrodedMetal (fire tower)
- **Lighting:** no fixed lights. No canopy either, so moonlight reaches the ground in bars between trunks — a striped, disorienting light that is worse than uniform darkness. Night visibility ~35 studs, but unreliable.
- **Part count:** ~235 (55 dead trees × 3, 6 hollow stumps × 4, 18 Wax Caps, 28 fire tower)
- **Connections:** east trail to Camp at `(-70,0,0)`; north-east trail to Pinewood at `(-130,0,-150)`; south-east trail to Lakeshore at `(-150,0,140)`
- **Key objects:** 16 `TallowNode` Wax Cap shelves growing on dead trunks, 6 **Hollow Stumps** — 9 studs across, 8 tall, hollow, tagged `Concealment` with `Capacity = 1` — at `(-180,4,-100)`, `(-240,4,-60)`, `(-200,4,10)`, `(-260,4,-130)`, `(-170,4,-160)`, `(-250,4,40)`. **The Collapsed Fire Tower** at `(-225, 0, -115)` — Iron wreck, 28 parts, its top platform lying on its side across the ground, climbable.
- **CHARACTER:** A forest that already died of something. Every tree is bare, grey, and dry enough to crack underfoot. The wax fungus grows thickest here, which quietly answers the question of what killed it. The zone is the only place that *gives* the player hiding spots, and the fact that a game bothers to put six hiding places in one zone tells you exactly what is expected to happen in it. Inside a stump you are safe and blind, listening to a hum get louder while a meter fills.
- **LIFE:**
  - *Ambient:* dry wood crack every 6–12s from a random direction; a low sustained creak from the leaning trunks; no birds, no insects, ever — this zone has no animal audio at all, which players feel before they notice.
  - *Reactive:* footsteps here use a distinctly crunchy audio zone (+2 effective noise feel, no mechanical change); entering a Hollow Stump emits a spore puff and drops all ambient volume by 60% with a muffled low-pass, so the hum becomes the only thing you can hear.
  - *One-time:* exactly once per run, at a random moment during a NIGHT phase, a dead tree somewhere in the Deadfall **falls** — a 4-second scripted collapse with full audio, visible from anywhere in the zone, harmless, and completely unrelated to Wick. Pure paranoia manufacturing.

---

### THE WAXWORKS (Wick's den)

- **Position:** `Vector3(160, 0, -250)`
- **Dimensions:** 110 × 110 studs
- **Floor:** SmoothPlastic `#D8D0BC`, Transparency 0.1 — a poured wax floor, slightly uneven
- **Walls:** 18 wax columns, 3–6 studs thick, 20–34 studs tall, SmoothPlastic `#EDE6D2` Transparency 0.25 — they look like melted candles fused into a colonnade
- **Accents:** Neon `#E08A3C` (three guttering wall candles), CorrodedMetal (the Ranger's Cache)
- **Lighting:** three small PointLights at `(140,14,-260)`, `(175,16,-240)`, `(160,12,-270)` — Range 14, Brightness 0.5 during DAY, 0 at NIGHT (Wick takes its light with it). Color `#E08A3C`.
- **Part count:** ~58 (18 columns, wax floor 6, cache wreck 18, candles 9, drip anchors 5)
- **Connections:** one 8-stud trail south-west to Pinewood at `(120,0,-260)`. Deliberately a cul-de-sac — there is no second way out.
- **Key objects:** **The Ranger's Cache** at `(172, 0, -268)` — the richest Iron wreck (3 Iron like the others, but also the only node that yields 2 Flint alongside), a metal supply crate half-swallowed by wax, 40 studs from where Wick sleeps. `WickDen` tagged volume covering the whole zone. `WickRestPoint` marker at `(160, 0, -252)`.
- **CHARACTER:** A cathedral built by accident. The columns are not carved; they are the accumulated drip of something that has stood in the same places for a very long time. It is warmer in here than anywhere else in the forest, the wax is soft to the touch, and the light is amber and gentle — every sensory signal says *safe*, and the giant thing asleep in the middle of it says otherwise. During the day this is the single best loot run in the game and the single stupidest place to make a noise. The cul-de-sac layout is not an oversight: if Wick wakes while you are in here, there is one exit and it is behind it.
- **LIFE:**
  - *Ambient:* the hum is *always* faintly audible in this zone, day or night, even while Wick is retreating — the room hums, not just the monster; wax drips continuously from the columns (VFX, Rate 4, plus a soft irregular drip audio); the three wall candles gutter on a 3s cycle.
  - *Reactive:* a NoisePing above 60 within 40 studs while Wick is Dormant makes **one antler candle brighten and rotate toward the source**, spikes the hum for 3s, and fires a `NotifyToast` warning. Wick does not attack — it just now knows. That is far more frightening than an attack.
  - *One-time:* the first time any player enters the Waxworks, every drip in the zone stops for 1.5 seconds, then resumes. No sound, no attack, no explanation.

---

### TRAIL RING

- **Position:** distributed
- **Dimensions:** 8 studs wide, ~1,100 studs of total length
- **Floor:** Ground `#4A4238`, packed dirt
- **Part count:** ~90 (path segments, trail marker posts)
- **Key objects:** 14 `TrailNode` marker posts (1 × 8 × 1, weathered wood, a faded painted band) at every junction. These double as Wick's fallback patrol waypoints when its interest list is empty.
- **CHARACTER:** Somebody maintained these. The markers are painted, the paths are cleared, the junctions are logical. It is the most human thing in the forest and the only place where you are guaranteed to be in the open with nothing to do but walk.
- **LIFE:** *Ambient:* footstep audio zone changes to packed-dirt. *Reactive:* the first time a player passes each `TrailNode` at night, its painted band catches their lantern light with a Reflectance flicker — a tiny, satisfying navigational reward.

---

### BOUNDARY and TERRAIN

- **Position:** perimeter at `±340`
- **Part count:** ~70
- **Key objects:** 6 large ground planes (Grass, tiled to cover 680 × 680 at `Y = 0`, 4 studs thick); a 40-stud band of 40 dense unharvestable trees inside the boundary; 12 invisible walls (Transparency 1, CanCollide true) at `±340` on both axes, 60 studs tall.
- **CHARACTER:** The forest gets denser until it is simply impassable. No fences, no invisible-wall message, no map edge — just trees too close together to walk between. Players never see a boundary, only a forest that says no.

---

### LOBBY

- **Position:** `Vector3(0, 500, 1200)`
- **Dimensions:** 120 × 24 × 80 platform
- **Floor:** WoodPlanks `#7A6A52`
- **Walls:** three walls and a roof — an open-fronted ranger station facing out over a void of fog
- **Lighting:** 4 PointLights, Range 30, Brightness 1.6, Color `#E0A860` — bright, warm, safe. This is the only unambiguously comfortable place in the game.
- **Part count:** ~80
- **Key objects:** **LobbySpawn** — the game's primary `SpawnLocation` at `(0, 502, 1215)`, Enabled true, Neutral true. Six **Ready Pads** (6 × 0.4 × 6, Neon when lit) tagged `LobbyPad` in an arc at `(-30..30, 500.4, 1190)`. A **Rules Board** — 20 × 12 wall panel with the three rules painted on it: *KEEP THE FIRE LIT. STAY IN THE LIGHT. IT ONLY WANTS THE LIGHT.* A countdown display above the board. A stats board reading DataManager values.
- **CHARACTER:** The last warm room. A ranger check-in station with a wood stove, a coffee pot, and a corkboard. The rules board is the game's only tutorial and it is three sentences long, painted by hand, by somebody who wanted the next group to have a better time than they did.
- **LIFE:** *Ambient:* a stove crackle loop; the hum, at 3% volume, audible from the fog beyond the platform — it is in the lobby too, and nobody mentions it. *Reactive:* stepping on a Ready Pad lights it amber with a rising chime; all pads lit triggers a single low horn.

---

## Door and Trail Connections

```
Lodge interior  <-> Camp Clearing   : door, (0, 5, -6), 8 studs wide, 10 high
Lodge interior  <-> Cellar          : hatch, (8, 0.4, -24), 6 studs wide (players only, Wick cannot enter)
Lodge roof      <-> Camp            : ladder on the east face, (17, 8, -18), 4 studs wide (players only)

Camp Clearing   <-> North Pinewood      : trail, (0, 0, -70),    8 studs wide
Camp Clearing   <-> East Boulder Field  : trail, (70, 0, 0),     8 studs wide
Camp Clearing   <-> South Lakeshore     : trail, (0, 0, 70),     8 studs wide
Camp Clearing   <-> West Deadfall       : trail, (-70, 0, 0),    8 studs wide
North Pinewood  <-> East Boulder Field  : trail, (130, 0, -160), 8 studs wide
North Pinewood  <-> West Deadfall       : trail, (-130, 0, -150),8 studs wide
North Pinewood  <-> The Waxworks        : trail, (120, 0, -260), 8 studs wide  [Wick's commute]
East Boulder    <-> South Lakeshore     : trail, (150, 0, 140),  8 studs wide
South Lakeshore <-> West Deadfall       : trail, (-150, 0, 140),  8 studs wide
```

Every zone has at least two exits **except the Waxworks**, which has exactly one. That is the only intentional dead end in the map and it is where the monster sleeps.

Adjacent ground planes overlap by **6 studs** at every seam — the single highest-value anti-bug rule in this document. Void falls at geometry seams are the most common critical failure in a large primitive-built map.

---

## Tags

| Tag | Count | Attributes | Purpose |
|-----|-------|------------|---------|
| `HarvestNode` | 150 | `ResourceId: string`, `NodeId: string` | Parent tag for all gatherables. Yield/tool-requirement/respawn timing are read from `Config.RESOURCES[ResourceId]` by ResourceId, not authored per-instance — kept off the node itself so balance changes are a one-file edit. |
| `TreeNode` | 62 | (inherits HarvestNode attrs) | Wood |
| `RockNode` | 24 | | Stone |
| `TallowNode` | 34 | | Tallow |
| `FlintNode` | 14 | | Flint |
| `IronNode` | 4 | `ChannelTime: number` | Iron wrecks |
| `Hearth` | 1 | `Tier: number`, `Fuel: number`, `MaxFuel: number`, `SafeRadius: number` | The campfire |
| `Workbench` | 1 | `CraftRadius: number` | Crafting station |
| `LanternPost` | 4 | `LightId: string`, `Fuel`, `MaxFuel` | Fixed camp perimeter lights |
| `LightSource` | 4 + runtime | `LightId: string`, `Kind: string`, `Range`, `Fuel`, `MaxFuel`, `BurnRate` | Every gameplay light; runtime-added |
| `PlacedLantern` | 0–6 runtime | as LightSource + `OwnerUserId: number` | Player-placed bait |
| `ColdWick` | runtime | `LightId: string`, `Kind: string` | A snuffed light awaiting a Brand |
| `ReinforceSlot` | 5 | `SlotType: string`, `Installed: boolean`, `BreakTime: number` | Lodge upgrade slots |
| `WatchtowerSlot` | 1 | `Installed: boolean`, `OccupantUserId: number?` | Lookout post |
| `Concealment` | 7 | `Capacity: number`, `NoiseMultiplier: number`, `GloomRate: number` | 6 Hollow Stumps + Cellar |
| `WickWaypoint` | 14 | `Index: number` | Fallback patrol route (the TrailNodes) |
| `WickDen` | 1 | `RestPoint: Vector3`, `AlertRadius: number` | The Waxworks |
| `WaterVolume` | 1 | `SpeedMultiplier: number`, `NoiseRate: number`, `StaminaMultiplier: number` | The lake |
| `WaxPool` | 0–40 runtime | `Expires: number` | Night 4+ hazard trail |
| `LobbyPad` | 6 | `PadIndex: number`, `Ready: boolean` | Ready-up |
| `ArrivalPoint` | 6 | `Index: number` | Run-start teleport targets |
| `TrailNode` | 14 | `JunctionName: string` | Navigation markers + Wick fallback route |
| `Enemy` | 1 runtime | `WaxLevel: number`, `State: string` | Wick (pipeline-standard tag) |
| `NarrativeTrigger` | 10–12 | `NarrativeId: string`, `TriggerRadius: number` | Reserved for story-teller |
| `VFXAnchor` | ~18 | — | Reserved for vfx-designer |

---

## Lighting Design Brief

**Global mood:** *One warm fire in a cold blue forest, and the only other light is walking toward you.* Every warm light in Wickwood is something a human made or something the monster carries. There is no third source of warmth. This is the entire lighting thesis and every decision below serves it.

**Colour temperature map:**
- **Warm (`#E08A3C` amber, ~2000K):** Hearth, all lanterns, Brands, Flares, the Lodge interior, the Lobby, Wick's three candles. Warm = made, owned, contested.
- **Cold (`#4A5C6E` moonshade, ~7000K):** everything else. Moonlight, fog, ambient, the lake, all five outdoor zones.
- **Neutral:** nothing. There is no neutral light in this game. Every light is either a human's or the moon's.

**The critical inversion:** Wick's candles are the *same amber* as the player's lanterns. At 90 studs through fog you cannot tell whether the orange glow ahead is your teammate's lantern or the monster's antlers. That ambiguity is worth more than any jump scare in the genre.

**Technology:** `Future` (shadows from 18+ dynamic point lights are the game's core visual system and ShadowMap will not carry it).

**Per-phase Lighting properties:**

| Property | DAY | DUSK (15s tween) | NIGHT | DAWN (12s tween) |
|----------|-----|------------------|-------|------------------|
| ClockTime | 7.5 | 17.8 → 19.4 | 0 | 4.8 → 7.5 |
| Brightness | 1.4 | 1.4 → 0.6 | 0.18 | 0.18 → 1.4 |
| Ambient | (88,92,96) | → (30,32,40) | (16,20,26) | → (88,92,96) |
| OutdoorAmbient | (120,128,136) | → (24,28,38) | (10,14,20) → (4,6,10) by night | → (120,128,136) |
| ExposureCompensation | 0 | 0 → 0.25 | 0.35 | 0.35 → 0 |
| GeographicLatitude | 41 | 41 | 41 | 41 |

All phase transitions are `TweenService`-driven on the **server**, tweening `Lighting` properties — a hard cut would break the dusk dread entirely. Dusk's tween is the most emotionally important 15 seconds in the game; ease it `Quad/Out`.

**Post-processing stack:**

| Effect | DAY | NIGHT | Purpose |
|--------|-----|-------|---------|
| `ColorCorrectionEffect` | Saturation 0.02, Contrast 0.06, Brightness 0, TintColor (255,250,240) | Saturation **−0.28**, Contrast **0.18**, Brightness −0.02, TintColor **(206,214,226)** | Drains the green out of the forest at night so the amber pops and the wax goes bone-white |
| `BloomEffect` | Intensity 0.22, Size 18, Threshold 0.92 | Intensity **0.42**, Size **20**, Threshold **0.85** | Threshold is high on purpose: *only actual flames bloom.* Nothing else in the world is bright enough to qualify, so bloom becomes a light-source indicator rather than a haze |
| `DepthOfFieldEffect` | FarIntensity 0.10, FocusDistance 40, InFocusRadius 40 | FarIntensity **0.26**, FocusDistance **22**, InFocusRadius **18** | Softens the far treeline, which hides both the part-count limit and the draw distance |
| `SunRaysEffect` | Intensity 0.14, Spread 0.9 | Intensity 0 | Day only. God-rays through pines sell the "this looks nice" trap |
| `Atmosphere` | Density 0.12, Color (150,160,170), Decay (120,130,140), Glare 0.2, Haze 1.2 | Density **0.12 → 0.26 by night**, Color **(52,62,74)**, Decay (24,30,38), Glare 0.15, Haze **2.4** | **Density never exceeds 0.26.** Above ~0.4 the screen whites out and mobile becomes unplayable |

The Gloom overlay is a **client-side ImageLabel vignette plus a local ColorCorrection adjustment** in `OverlayGui`, layered on top of the global stack — never a change to the global effects, which must stay identical for all players.

**Key dramatic lights:**

| Location | Light | Colour | Range | Brightness | Narrative purpose |
|----------|-------|--------|-------|------------|-------------------|
| Hearth `(0,3,10)` | PointLight, Shadows on | `#E08A3C` | 60/75/95 | 2.4–3.2 | The game's sun. Everything is measured in distance from here. |
| Lantern Posts ×4 | PointLight | `#E08A3C` | 32 | 2.0 | The perimeter. Watching one die tells you where Wick is. |
| Lodge interior | PointLight, starts off | `#E0A860` | 20 | 0.8 | The Lodge is dark until someone chooses to light it |
| Wick's centre candle | PointLight, Shadows on | `#E08A3C` | 16 | 1.3 | **The monster casts moving shadows through the trunks.** Sixteen studs of range on a 14-stud creature means its own body shadows the ground around it as it walks |
| Waxworks wall candles ×3 | PointLight | `#E08A3C` | 14 | 0.5 day / 0 night | The den is lit only while its occupant is home |
| Flare (runtime) | PointLight, Shadows on | `#FFB050` | 55 | 3.4 | 12 seconds of daylight in the worst moment of the run |

**Light scripting notes:**
- Any light below 20% fuel **flickers**: Brightness jitters ±35% on a random 0.4–1.1s interval. This is the game's fuel gauge and it is read at a glance from 100 studs away.
- During **Blackout**, every registered light's Brightness tweens to 0 over 0.2s, holds 1.5s, and only Wick's candles remain — and Wick's candles brighten to 2.0 for the duration. It is the best-looking moment in the game and it costs nothing.
- At the **dawn of Night 5**, the Hearth tweens Range to 3× and Brightness to 6 over 4 seconds while `Atmosphere.Density` tweens to 0.04 — the fog visibly burns off in a wave.
- Wick's candles dim to Brightness 0.4 while Dormant and gutter out one at a time during Retreating.

---

## Art Direction Guide

**Colour palette — five colours, strict roles:**

| Role | Name | Hex | Where used |
|------|------|-----|------------|
| Primary (dominant surfaces) | **Pinebark** | `#2E3730` | Ground, trunk mass, the visual bulk of every forest zone |
| Secondary (accents, human structures) | **Ashen Birch** | `#9A9486` | Birch trunks, boulders, cabin boards, trail markers, the Workbench |
| **Danger / Alert** | **Tallow White** | `#EDE6D2` | **Wick's entire body. Wax Caps. Wax Pools. The Waxworks. Nothing else may use this colour.** |
| Safe / Interactive | **Hearthlight Amber** | `#E08A3C` | Every flame, every lantern glass, every interactable prompt, the Lobby — and Wick's candles |
| Atmosphere | **Moonshade Blue** | `#4A5C6E` | Fog, moonlight, ambient, the lake, all cold shadow |

**The rule that makes this palette work, stated for every downstream agent:** *Tallow White is reserved. If it is pale cream, it is wax, and wax is the monster.* A set-dresser who puts a white ceramic mug in the Lodge has broken the game's most important visual contract. Props use Ashen Birch for anything light-coloured. No exceptions.

**Material language:**

| Material | Meaning |
|----------|---------|
| `Wood` / `WoodPlanks` | Human, made, survivable. The Lodge, the Workbench, trail markers, lantern posts. Warmth even without light. |
| `Grass` / `LeafyGrass` | The living forest. Day-safe. Present in Pinewood, Camp, Lakeshore — **absent** from the Deadfall and Waxworks. |
| `Slate` / `Rock` | Indifferent nature. Boulders, the fire ring, the lake bed. Neither friend nor threat. |
| **`SmoothPlastic` at Transparency 0.1–0.3** | **WAX. Wick's touch.** Every wax object in the game shares this exact treatment. Nothing else in the game is translucent. Translucency *is* the monster's signature, so recognising it is instant and needs no explanation. |
| `Neon` | **Active flame only.** Hearth core, lantern glass, brand tips, flare, Wick's three candles. Neon is never decorative and never appears on anything that is not currently on fire. |
| `CorrodedMetal` | The past. The four wrecks, the Iron you scavenge from them. Rust means "someone tried this before you." |

**Scale reference:**

| Element | Size | Why |
|---------|------|-----|
| Player | ~5 studs | Baseline |
| **Wick** | **14 studs** at full wax, **~9** when melted | Nearly triple the player. It has to duck under the Lodge doorway. |
| Conifer | 28–45 studs tall, 3–5 thick | Canopy at ~34 makes a ceiling over the Pinewood — an outdoor space that feels indoors |
| Dead tree | 18–30 studs, 2–3 thick | Shorter and thinner, so the Deadfall feels *stripped*, and moonlight reaches the floor |
| Lodge doorway | 8 × 10 | 8 wide is Wick's exact pathfinding tolerance. Watching it squeeze is a designed beat. |
| Lodge ceiling | 14 | Low relative to the 34-stud canopy outside — the interior is a box, and that's the point |
| Trail | 8 wide | Pathfinding minimum, and it makes the trail read as a narrow line through mass |
| Wax column | 20–34 tall, 3–6 thick | Column-scaled, so the Waxworks reads as architecture rather than terrain |

**Prop density targets:**

| Zone | Density | Rationale |
|------|---------|-----------|
| Camp Clearing + Lodge interior | **Dense (~120 props)** | Players spend 60% of their time here and every second of the day phase. It must reward looking around. |
| The Waxworks | **Sparse but tall (~40)** | Emptiness reads as scale. A cathedral is mostly air. |
| North Pinewood | **Medium-low (~60)** | Trunks already fill the frame. Adding clutter destroys the sightline design. |
| West Deadfall | **Medium (~70)** | Fallen branches, ash, bone-dry brush. Enough to feel treacherous underfoot. |
| East Boulder Field | **Sparse (~45)** | Emptiness is the zone's entire mechanical identity. Do not fill it. |
| South Lakeshore | **Medium (~70)** | Reeds, driftwood, waterline debris. Horizontal clutter, nothing tall. |
| Trail Ring | **Minimal (~15)** | Trails must read as clear paths. Blocking a trail breaks pathfinding. |

**Composition note for art-director:** every zone should have exactly one focal element visible from its entry trail — the Old Mother in the Pinewood, the stone shelf in the Boulder Field, the Rowboat on the shore, the Fire Tower in the Deadfall, the columns in the Waxworks, the Hearth in Camp. One landmark per zone means players navigate by memory instead of by minimap, and there is no minimap in this game.

---

## Signature Moments

### 1. The First Snuff — *Night 1, ~3:20*
- **Trigger:** NIGHT phase of night 1 begins with at least one Placed Lantern or lit Lantern Post existing.
- **What happens:** Wick wakes. On Night 1 the tie-break favours the *farthest* light from the Hearth, and the Hearth's own interest weight is hard-zero, so Wick walks past the camp entirely. It is visible: 14 studs tall, three candles, moving at WalkSpeed 9, humming. It stands over the chosen lantern for four seconds. The lantern's Brightness tweens to 0. One antler candle brightens by 40%. Wick straightens and walks back toward the Waxworks. Then — because Night 1's rule retires it early — it leaves.
- **Duration:** ~35 seconds of pure observation.
- **Aftermath:** the forest is permanently one light darker for the rest of the night. There is a Cold Wick out there. Everyone now knows: it wants light, it glows, it grows, and it did not care about them at all.
- **Agents:** luau-scripter (the Night-1 tie-break rule and early retirement in `WickAI`); enemy-designer (the four-second snuff animation and the candle brighten); sound-designer (the hum, and the absolute absence of footsteps); vfx-designer (the lantern's dying ember puff); lighting-director (the Brightness tween timing — 4 seconds, ease Quad/In, so it feels *drunk* rather than switched off).

### 2. Reflection on the Lake — *first time Wick nears the shore at night*
- **Trigger:** Wick's position comes within 120 studs of the lake plane during NIGHT.
- **What happens:** the lake surface (Reflectance 0.45, a perfectly flat plane, deliberately never rippled by ambient animation) catches Wick's candle light and shows it as a moving orange smear — **visible from the Camp Clearing 200 studs away, before Wick clears the treeline.**
- **Duration:** as long as it is near the water.
- **Aftermath:** none mechanically, and that is the point. This is not a scripted event; it is a physical property of the map that behaves correctly. The group that notices it has *discovered* something, and the lookout who calls it gets the clip.
- **Agents:** world-builder (the flat plane, the Reflectance value, the sightline from camp being genuinely unobstructed); lighting-director (Technology Future so the reflection actually renders); vfx-designer (**must not** add ambient ripple VFX to the lake — ripples only on player wade, or the trick dies).

### 3. The Melt — *Night 3+, when Wax crosses 40%*
- **Trigger:** Wick's Wax value crosses 40% downward (typically 70–90 seconds into a night on Night 3+).
- **What happens:** 1.5-second transition. `HipHeight` drops 3.2 → 2.1. `RootJoint.C0` tilts the torso forward 34°. Torso and Head Transparency rise to 0.45 — you can see *through* it now. WalkSpeed and chaseSpeed both increase 30%. The `WaxDrip` emitter enables. The hum's `PlaybackSpeed` drops to 0.72, turning the lullaby into a wet gurgle.
- **Duration:** permanent for the remainder of that night.
- **Aftermath:** the second half of every late night is a different monster from the first half, with a visible and audible tell. Groups learn to *read its wax* and plan around it: bait it into snuffing early and it melts sooner and moves faster; starve it and it retreats.
- **Agents:** enemy-designer (the whole transition, and specifically doing it via HipHeight/C0/Transparency rather than part rescaling); sound-designer (the pitch drop and the wet layer); vfx-designer (the drip emitter, Rate 6, LightEmission 0.2); luau-scripter (the Wax threshold logic in `WickAI`).

### 4. Blackout — *the moment the Hearth hits 0*
- **Trigger:** `HearthManager` fuel reaches 0 during NIGHT.
- **What happens:** every registered light's Brightness tweens to 0 over 0.2 seconds. **1.5 seconds of near-absolute darkness** (OutdoorAmbient is (4,6,10) by Night 4 — effectively nothing). Then Wick's three candles brighten to 2.0 and they are the **only light in a 640-stud forest.** `BlackoutTriggered` fires, the HUD goes to a red hairline border, and a 45-second timer starts. Wick enters Blackout-Hunt at `chaseSpeed × 1.15`, ignoring the Hearth's safe radius because there is no Hearth.
- **Duration:** 45 seconds, or until someone reaches the Hearth's Cold Wick with 5 Wood and relights it.
- **Aftermath:** survive it and the Hearth restarts at 30 fuel — barely alive, and the rest of the night is a scramble. Fail it — every player Downed or Snuffed with nobody Alive — and the run ends.
- **Agents:** luau-scripter (`HearthManager` trigger, the 45s timer, the relight path, the wipe check); lighting-director (the 0.2s tween, the 1.5s hold, Wick's candle brighten); sound-designer (**every ambient loop cuts to silence for 1.5s** except the hum, which goes to 100% — the audio does the work here, not the visuals); vfx-designer (all ember/dust emitters disabled for the duration).

### 5. Dawn of Night 5 — *the win*
- **Trigger:** the DAWN phase of night 5 begins with the Hearth lit.
- **What happens:** a 14-second sequence. The Hearth's Range tweens to 3× and Brightness to 6. `Atmosphere.Density` tweens 0.26 → 0.04 and the fog **visibly burns off in a wave** across the map. Wick, wherever it is, is force-pathed to the lakeshore. Its three candles gutter out one at a time, two seconds apart. Its HipHeight drops to 1.2 and its Transparency rises to 0.7 — it becomes a pale suggestion. It walks into the lake and keeps walking until it is submerged. Birds return. ClockTime tweens to 7.5. `RunEnded{result = "Survived"}`.
- **Duration:** 14 seconds, uninterruptible, camera stays on the player (no cutscene camera — let players watch it from wherever they happened to be standing, which means every player's win looks different).
- **Aftermath:** results panel, lobby, and one shared memory of the only time the fog ever cleared.
- **Agents:** luau-scripter (`CycleManager` win detection and sequencing); lighting-director (the Hearth flare and the fog tween — this is the single most important lighting cue in the game); enemy-designer (the forced path, the candle gutter, the submerge); sound-designer (the hum fading under returning birdsong — the first birdsong since Night 1's dusk).

---

## Environmental Events

### Ambient (periodic — the world exists without the player)

| Event | What happens | Frequency | Zones | Implemented by |
|-------|--------------|-----------|-------|----------------|
| Hearth crackle + embers | Audio loop + ember emitter, both scaling with Hearth tier | continuous | Camp | sound-designer, vfx-designer |
| Low-fuel flicker | Any light below 20% fuel jitters Brightness ±35% | 0.4–1.1s random | all lit | luau-scripter (`LightManager`) |
| Canopy creak | Deep wood groan, randomised position | 8–14s | Pinewood | sound-designer |
| Dry crack | Sharp wood snap from a random bearing | 6–12s | Deadfall | sound-designer |
| Rockslide settle | Stone tumble audio + 2 small rocks slide 3 studs | 20–35s | Boulder Field | sound-designer, luau-scripter |
| Distant splash | Water impact with no visible source | 15–25s | Lakeshore | sound-designer |
| Wax drip | Drip audio + emitter from the columns | continuous | Waxworks | sound-designer, vfx-designer |
| The Room Hums | The Waxworks hums at 8% even when empty | continuous | Waxworks | sound-designer |
| Cabin door bang | Door swings and slams | 25–40s | Camp | luau-scripter |
| Owl / loons / crickets | Full day ambience — **all of it stops dead at DUSK** | continuous DAY | Pinewood, Lakeshore, Camp | sound-designer |
| Needle drift | Pine needles fall continuously | continuous | Pinewood | vfx-designer |
| Floor fog | Low ground fog, NIGHT only, density scaling with the night | continuous NIGHT | all outdoor | vfx-designer |
| Wax Cairn breath | One boulder in the Boulder Field expands/contracts on a 4s cycle | Night 3+ | Boulder Field | luau-scripter |
| Lodge lantern sway | Hanging lantern gently swings | 11s tween | Camp, Lodge | luau-scripter |

### Triggered (player proximity or action)

| Event | Trigger | Effect | Zone | Cooldown |
|-------|---------|--------|------|----------|
| Bird burst | First entry to the Pinewood per run | 40-bird VFX + wingbeats from directly overhead | Pinewood | one-time |
| Hearth greeting | Player within 10 studs of the Hearth | Ember rate ×2 for 2s + soft flare audio | Camp | 6s |
| Spore puff | Harvesting a Wax Cap | Thick white cloud, 4s lifetime, brief Gloom-fill bump | Lakeshore, Deadfall | per node |
| Stump muffle | Entering a Hollow Stump | All ambient volume −60% with low-pass; the hum becomes the only audible thing | Deadfall | on enter/exit |
| Trail marker catch | First pass of each TrailNode at night | The painted band catches lantern light with a Reflectance flicker | Trail Ring | once per node |
| Wade ripple | Entering the lake | Ripple VFX + loud splash audio zone | Lakeshore | continuous |
| Brand hiss | Throwing a Brand into water | Instant snuff + steam burst + hiss | Lakeshore | per use |
| Old Mother groan | Player within 25 studs | Deep sustained groan on a 9s loop | Pinewood | 9s |
| **Den warning** | NoisePing > 60 within 40 studs of the WickDen while Dormant | **One antler candle brightens and rotates toward the source; hum spikes 3s; NotifyToast warning.** No attack. | Waxworks | 12s |
| Chop shudder | Chopping any tree | 3 nearby trees shed needle puffs | Pinewood | per swing |
| Watchtower wind | Standing on the Watchtower | Single low wind tone, camera FOV +4 | Camp | on enter |
| Ready pad chime | Stepping on a Lobby pad | Pad lights amber, rising chime | Lobby | per press |

### Scripted sequences (the peaks)

| Sequence | Trigger | Choreography | Impact | Agents |
|----------|---------|--------------|--------|--------|
| **The Exodus** | First DUSK of the run, 3s before the hum | Every bird in the Camp Clearing leaves at once — 40-bird burst + wingbeats, then total insect silence | The single best "something is wrong" cue in the game, and it costs 40 particles | vfx, sound, scripter |
| **The Falling Tree** | Once per run, random moment during any NIGHT | A Deadfall tree collapses over 4 seconds with full audio. Harmless. Unrelated to Wick. | Manufactured paranoia. Every group thinks it was the monster. | scripter, sound, vfx |
| **Drip Silence** | First player entry into the Waxworks, ever | Every drip in the zone stops for 1.5s, then resumes. No sound cue, no attack, no explanation. | The best 1.5 seconds in the map | scripter, vfx, sound |
| **The First Snuff** | Signature Moment 1 | see above | Teaches the entire game with zero text | scripter, enemy, sound, lighting, vfx |
| **Blackout** | Hearth reaches 0 | Signature Moment 4 | The run's crisis point | all |
| **The Melt** | Wax < 40% | Signature Moment 3 | Mid-night monster change | enemy, sound, vfx |
| **Dawn of Night 5** | Win condition | Signature Moment 5 | The payoff | all |

**Event density:** 14 ambient + 12 triggered + 7 scripted across 8 zones. Every zone has at least two ambient events and two reactive elements. **No dead zones.**

---

## Technical Decisions

**Physics.** Everything `Anchored = true` except: Wick's 7 body parts (Humanoid requires unanchored), thrown Brands and Flares (2s unanchored flight, then anchored on landing), and player characters. Props `Anchored = true, CanCollide = false`. Trees `CanCollide = true` (they must block both movement and raycasts — the sightline design depends on it). Boulders `CanCollide = true`.

**Collision groups:**

| Group | Collides with | Purpose |
|-------|---------------|---------|
| `Default` | Default, Structure, Enemy | Players and terrain |
| `Props` | nothing | Decorative props never block movement or pathfinding |
| `Enemy` | Default, Structure | Wick collides with players and walls, never with props |
| `Projectile` | Structure only | Thrown Brands/Flares pass through players |
| `Concealment` | nothing | Hiding volumes are detection triggers, not physical boxes |

**Camera.** Third-person default (`CameraMode = Classic`, MaxZoomDistance 14, MinZoomDistance 6) — a co-op game needs players to see their teammates and their teammates' lanterns. Holding Focused Beam smoothly narrows FOV 70 → 58 and pulls the camera in to 8 over 0.3s: aiming feels like leaning in without forcing first-person. No first-person lock anywhere; Wick is 14 studs tall and looking up at it is the whole visual gag.

**Input mapping:**

| Action | Keyboard | Gamepad | Mobile |
|--------|----------|---------|--------|
| Move | WASD | LeftThumbstick | Thumbstick |
| Sprint | LeftShift (hold) | LeftTrigger | SPRINT button, hold |
| Interact / Harvest | E (hold for channels) | ButtonX | Large contextual button, bottom-right |
| Lantern toggle | F | ButtonY | LANTERN button |
| Focused Beam | Right Mouse (hold) | RightTrigger | BEAM button, hold |
| Craft menu | Q (near Workbench) | ButtonB | CRAFT button, appears only near the Workbench |
| Shout | V | DPadUp | SHOUT button |
| Throw | T | RightBumper | THROW button, appears only when holding a throwable |
| Mark Wick (spectator/tower) | G | ButtonA | MARK button |

Every mobile button is **56 × 56 px minimum** (well above the 44 px floor), with the Interact button at 76 × 76 because it is the most-used control in the game. Contextual buttons (Craft, Throw, Mark) are hidden until valid, to keep the screen clear — Wickwood is played mostly with two thumbs and a lot of shouting.

**Multiplayer.** `MaxPlayers = 6`. `PreferredPlayers = 4`. All gameplay state server-owned. Client owns only: camera, HUD rendering, lantern *visual* attachment, and local Gloom overlay. Streaming disabled (`Workspace.StreamingEnabled = false`) — a 640 × 640 map at 2,400 parts fits comfortably in memory and streaming would cause lights to pop in and out, which in this game is literally a gameplay bug.

**Performance.** No `while true do` anywhere. All ticking systems run off a single `RunService.Heartbeat` connection per manager with a time accumulator, at explicit rates: SurvivalStats 10Hz, LightManager illumination 4Hz, WickAI decisions 2.5Hz, WickAI detection 3.3Hz, NoiseManager 5Hz. Total budget: under 30 systemic evaluations per second per player.

---

## Build Order

**Phase 1 — Foundation (nothing is playable, everything depends on it)**
1. `Config`, `GameEnums`, `Shared`, `RecipeBook`, all 24 RemoteEvents. *Every other agent reads these names.*
2. `Main` + the `Systems/` ModuleScript skeletons with real `Init()` signatures.

**Phase 2 — The hero shot (first thing worth looking at)**
3. Camp Clearing: ground, Lodge, Hearth, Workbench, Lantern Posts, arrival ring, CampSpawn.
4. Lobby platform + LobbySpawn + Ready Pads.
5. Night lighting preset + Hearth PointLight. *After this step the project looks like a game, and screenshots become possible.*

**Phase 3 — The loop, playable and losable with almost no content**
6. `CycleManager` + `HearthManager` + `SurvivalStats` + `SurvivalHUD` + `InputController` + `HUDController`.
   *Milestone: a player can stand in the camp, watch day become night, feed the fire, and lose to the Gloom. That is a game already.*

**Phase 4 — Economy**
7. `ResourceManager` + harvest nodes in the Camp ring and the nearest Pinewood edge.
8. `CraftingManager` + `RecipeBook` + `CraftingGui` + `CraftingUIController`.
9. `LightManager` in full: Placed Lanterns, Brands, Cold Wicks, relighting.

**Phase 5 — The map**
10. Trail Ring (first — everything else hangs off it, and pathfinding depends on it).
11. North Pinewood → West Deadfall → East Boulder Field → South Lakeshore → The Waxworks.
12. Boundary band and invisible walls.

**Phase 6 — The monster**
13. Wick rig in ServerStorage (enemy-designer).
14. `WickAI` — Dormant/Seeking/Snuffing first, then Stalking/Charging/Grappling, then Recoil/Melting/Blackout-Hunt.
15. `NoiseManager` and its integration into the interest solver.

**Phase 7 — Structures and session**
16. `StructureManager`: shutters, barred door, Watchtower, Cellar Hatch.
17. `SessionManager`: ready-up, run start/end, spectators, late joiners, world reset.
18. `DataManager`.

**Phase 8 — The curve**
19. `Config.NIGHTS` escalation table wired through CycleManager, HearthManager, and WickAI.
20. The five Signature Moments.

**Phase 9 — Polish passes (the standard pipeline order)**
21. interior-designer (per zone) → detail-architect → set-dresser (per zone) → sound-designer → vfx-designer → lighting-director → art-director → story-teller.

**Phase 10 — Gates**
22. luau-reviewer → ui-designer → roblox-playtester → computer-player.

---

## Part Budget

**Target: 2,400 parts. Hard ceiling: 4,000.** (Reference: a 6-room escape room ran 1,470. This is a 640 × 640 open map, so a ~1.6× multiplier is the right expectation.)

### By zone — structural (world-builder)

| Zone | Parts | Breakdown |
|------|-------|-----------|
| Terrain + Boundary | 70 | 6 ground planes, 40 boundary trees, 12 invisible walls, misc |
| Trail Ring | 90 | path segments + 14 markers |
| Camp Clearing | 226 | Lodge 140, Hearth 14, Workbench 12, Lantern Posts 20, cellar 16, misc 24 |
| North Pinewood | 342 | 70 trees × 4 = 280, 40 logs/rocks, 22 truck wreck |
| East Boulder Field | 192 | 60 boulders × 2 = 120, 15 trees × 4 = 60, 12 flint piles |
| South Lakeshore | 196 | lake 6, 20 trees × 4 = 80, 40 reeds, 30 rocks, 24 wax caps, 16 rowboat |
| West Deadfall | 235 | 55 dead trees × 3 = 165, 6 stumps × 4 = 24, 18 wax caps, 28 fire tower |
| The Waxworks | 58 | 18 columns, floor 6, cache 18, candles 9, drip anchors 5 |
| Lobby | 80 | platform, walls, roof, 6 pads, boards, stove |
| Interaction markers | 40 | arrival points, concealment volumes, CoCraft stands, trigger volumes |
| **Structural subtotal** | **1,529** | |

### Per-agent allocation

| Agent | Budget | % | Notes |
|-------|--------|---|-------|
| world-builder (base geometry) | 1,529 | 62% | The table above |
| detail-architect | 300 | 12% | Lodge trim, door frames, roof beams, shore edging, trail borders, wreck detailing |
| set-dresser (all zones) | 420 | 17% | Per the density table: Camp 120, Waxworks 40, Pinewood 60, Deadfall 70, Boulders 45, Lakeshore 70, Trails 15 |
| lighting fixtures | 40 | 2% | Physical lantern housings, candle holders, the Lobby's lamps |
| VFX anchors | 18 | <1% | Invisible emitter anchors |
| Wick rig | 15 | <1% | 7 R6 + 8 decorative |
| Runtime prefabs (peak concurrent) | 90 | 4% | 6 Placed Lanterns (5 each) + up to 40 Wax Pools (1 each) + Brands/Flares/shutters |
| **Reserve** | ~190 | 8% | Iteration and art-director corrections |
| **Total at peak** | **~2,412** | | vs. 2,400 target, 4,000 ceiling |

**Mobile check:** 2,412 parts, 18 concurrent dynamic lights (Future technology), under 20 ParticleEmitters at a combined rate below 80/sec, under 25 Sound objects, Atmosphere Density capped at 0.26. Comfortable on a mid-range phone.

---

## Risk Areas

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Pathfinding failure in dense forest** | Critical | Trails 8 studs wide; trees minimum 10 studs apart along trails; `AgentRadius 3.5` with a 0.75-stud margin on the tightest gap; `Costs.Trail = 0.5` biases Wick onto the trails where the geometry is guaranteed clean; `pcall` on every `ComputeAsync` with `MoveTo` fallback; 14 `WickWaypoint` fallback nodes if pathfinding fails entirely. |
| **Void falls at ground-plane seams** | Critical | 6-stud overlap on every adjacent ground plane. The single most common critical bug in large primitive maps; mandate it explicitly to world-builder and verify with a seam sweep in playtesting. |
| **Part count blowout from trees** | High | Trees are the dominant cost at 4 parts each. Hard cap: 62 harvestable + 50 decorative + 40 boundary = 152 trees maximum. If the budget slips, drop conifer foliage tiers from 3 to 2 (saves 152 parts instantly with almost no visual cost under fog). |
| **Gloom feels unfair / punishing** | High | Gloom is a *filling meter with a visible bar and a closing vignette*, not instant damage, and 3 HP/s gives a 33-second grace period. Playtest target: no player should ever die to Gloom without having had at least 20 seconds of clear warning. If computer-player reports Gloom deaths without warning, lower the fill rate before touching anything else. |
| **Beam freeze stun-lock exploit** | High | Freeze duration is hard-capped by `Config.NIGHTS[n].freezeDuration` **regardless of continued beaming**, followed by 6 seconds of freeze immunity. Beaming also costs 6 fuel/sec and adds +8 aggro. Three independent brakes. |
| **Nobody uses voice chat → Lookout is dead weight** | High | The `Shout` action and `RequestMarkWick` both put information on every teammate's *screen*, so a silent group still functions, just worse. Voice chat is the optimisation, not the requirement. |
| **Grapple physics jank** | Medium | Use `AlignPosition` + `AlignOrientation` to an Attachment on Wick's right hand, with `Humanoid.PlatformStand = true`. **Never a Weld or WeldConstraint on a character** — it produces the classic flying-player bug. Destroy both constraints on release, then set `PlatformStand = false` on the next frame. |
| **Placed Lantern spam breaks Wick's routing** | Medium | Hard cap of 6 active Placed Lanterns, enforced server-side in `CraftingManager`. Placing a 7th is rejected with a toast, not silently dropped. |
| **Night feels empty if Wick is far away** | Medium | The ambient event table guarantees something is happening in every zone every 6–35 seconds regardless of Wick's position, and the hum is always audible at some volume, everywhere. A quiet night should never be a *silent* night. |
| **Day phase feels like chores** | Medium | 150 seconds is deliberately tight — a well-coordinated group finishes with 15 seconds to spare, not 60. Chopping is fast (6 swings per tree, 12 with an axe), feedback is immediate, and the Waxworks risk/reward run gives confident players something exciting to do during the "safe" phase. If playtesting reports boredom, cut day length before adding tasks. |
| **Fog too dense on mobile** | Medium | `Atmosphere.Density` hard-capped at 0.26 (never near the 0.4 white-out threshold). Verify per-night values against a mobile emulation in playtesting. |
| **Solo players bounce off an unwinnable game** | Low | The Lobby rules board states the player count. The countdown favours waiting for others. A solo run still produces two or three genuinely fun nights before it fails, which is a good demo rather than a bad experience. |

---

## Mobile Checklist

- [x] All UI sizing Scale-based (`UDim2.new(scale, 0, scale, 0)`) — zero Offset on any major element
- [x] Every touch target ≥ 56 × 56 px; primary Interact button 76 × 76
- [x] Contextual buttons (Craft, Throw, Mark) hidden until valid — maximum 6 visible buttons at once
- [x] All HUD text ≥ 16pt, with `TextScaled` plus `UITextSizeConstraint` minimum 14
- [x] Part count 2,412 < 4,000 ceiling
- [x] ≤ 18 concurrent dynamic lights
- [x] ≤ 20 ParticleEmitters, combined rate < 80/sec
- [x] ≤ 25 Sound objects, none above Volume 0.7
- [x] `Atmosphere.Density` ≤ 0.26 always
- [x] No per-frame raycasting — all detection is on 0.2–0.4s accumulator ticks
- [x] Streaming disabled (lights must never pop)
- [x] Third-person camera (no first-person lock — mobile aiming is imprecise, and the Focused Beam uses a 35° cone specifically so it does not require precision)
- [x] Critical information conveyed by audio and colour, not by fine visual detail: hum volume = distance, candle amber = the monster, bar colour = your state

---

## Self-Review Notes (for downstream agents)

**Every room has a Position, Dimensions, materials, lighting, part count, connections, CHARACTER, and LIFE.** No dead zones — 14 ambient + 12 triggered + 7 scripted events across 8 zones.

**Spatial sanity trace:** Camp `(0,0,0)` → north trail exits at `(0,0,-70)` → Pinewood spans Z −90 to −290, X −130 to +130 → its north trail at `(120,0,-260)` enters the Waxworks at X 105–215, Z −295 to −205. No overlaps. Boulder Field (X 110–310) does not intersect Pinewood (X ≤ 130) at Z 40 because Pinewood's southern edge is Z = −90. Lakeshore (Z 110–310) clears Camp's southern edge (Z = 70). Deadfall (X −310 to −110) clears Camp's western edge (X = −70). All eight seams verified, all ground planes overlap by 6 studs.

**The three most important numbers in this document:** trails are **8 studs wide** (below this, pathfinding fails); ground planes overlap by **6 studs** (below this, players fall into the void); `Atmosphere.Density` never exceeds **0.26** (above 0.4, the screen whites out on mobile). Every other number can be tuned. These three are load-bearing.

**The one visual contract that must not be broken:** *Tallow White `#EDE6D2` is reserved for wax.* If it is pale cream and slightly translucent, it is the monster, and the player must be able to trust that at 90 studs through fog.
