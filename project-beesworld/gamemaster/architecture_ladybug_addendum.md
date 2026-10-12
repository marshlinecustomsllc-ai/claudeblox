# Ladybug Feature -- Architecture Addendum

Status: spec only. No Studio writes were made. All live reads were Edit mode, place 123313915411717, taken during the spec pass.

## Live facts used (Edit mode read, not from memory)
- Workspace BaseParts: **2081** (the "about 2230" in the brief is the planned total after hub redo + obby; this addendum adds 0).
- Sound objects: **15** live (the brief and hub addendum say 24). Ladybugs add **0** either way. Flagged for the audio gate.
- ParticleEmitters in Workspace: **0** live. Lights: 59 live (ladybugs add 0).
- Hub BaseParts: **299** of the hub cap 300. Ladybugs add 0 saved parts (see Budget).
- Meadow.Patches: **20 Model patches** at Y = 2 (the architecture's 16+2 table is stale; use live positions below).
- Meadow children: Patches, Grass, Props, Ground, MeadowAmbientAnchor. `HoneyObby` does not exist yet.
- Config.COSMETICS has 4 skins (worker, Molasses Fur, Furious, Lantern Gold). Config.ACHIEVEMENTS has 15 ids (ends with curiousBee, nightOwl).
- CosmeticService pattern: `ensureCosmetics(profile)` (nil-safe default), `Equip` validates ownership, writes `profile.cosmetics.equipped`, pushes `EquippedSkin` as a PlotRoot attribute; `RequestEquipCosmetic` is rate-limited via `Validator.RateLimit`.
- ClientMain (LocalScript) boots 18+ controllers from `StarterPlayerScripts.Controllers` by `require` + `Init()`. ClientMain itself has **no** Heartbeat. DanceController, VfxController and QueenController each own one Heartbeat.

---

## 1. Design summary

### Part 1 -- Roaming ladybugs (visual only, client-side)
- **For kids:** little red bugs slowly crawl over the flowers. Walk up close and they fly away. They come back later.
- **For adults:** ambient life in the meadow and hub beds. No gameplay meaning. Costs no server work.
- Rules: 16 roaming ladybugs total (12 on meadow patches, 4 in the hub beds). Each one is a small client-only model that crawls inside a 3-stud radius around its anchor on a TweenService loop. Within 9 studs of the local character it flies up and away (tween), then returns to its anchor after 8 s.
- Only ladybugs within 200 studs of the local character are instantiated (pool). Others do not exist on the client.

### Part 2 -- Ladybug journal and collection
- **For kids:** tap a red ladybug in the meadow to add it to your journal. Find all 12 to finish the journal.
- **For adults:** a clear completion target (12 of 12), plus a visible skin-stage ladder (see Part 3).
- The tap is a request. The server checks the ladybug is real, that you are near it, and that you have not collected it. Only then does it write the profile.
- Hub ladybugs are **not** collectible (owner brief: collection is on the meadow). Their taps do nothing.

### Part 3 -- Ladybug companion (visual only, with skin stages)
- **For kids:** after you find 3 ladybugs, a small ladybug starts following your bee. It gets fancier as you find more: 2 spots, then 7 spots, then a gold shell, then a rainbow shell.
- **For adults:** the companion's stage is a visible record of progress. Stage 4 is the full-journal reward.
- Visual only. No collision, no speed or stat change, no bonus of any kind.
- It follows the local character at offset (-2.5, 2.2, -2.5) with a lerp. It is local-only in v1 (owner decision 4).
- **Skin stages** (owner addition, recommended defaults):

| Stage | Found needed (collectible count) | Look | Reachable for a kid? |
|---|---|---|---|
| 1 (default) | 0 | Red shell, 2 black spots | yes, from start |
| 2 | **3** of 12 | Red shell, 7 black spots | yes, one short meadow walk |
| 3 | **7** of 12 | Gold shell (Color3 255,200,60), 7 spots | mid session, a kid's second visit |
| 4 | **12** of 12 (full journal) | Rainbow shell: body colour cycles through 3 colours on a 2.4 s TweenService loop (a loop on the companion only, not a per-frame Heartbeat) | adult/older-kid target |

- Stage 2 is also the companion unlock (3 found). Owner decision 1.
- A stage change plays a one-shot moment on the companion: a 0.5 s bounce (TweenService Position up 1.2 studs and back) plus a **one** transient sparkle (ParticleEmitter, Rate 0, `Emit(10)` once, then destroyed after 1.5 s). No loop, no sound.
- The **server** computes the stage from the count. The client never sends a stage. The stage is stored in profile as a number (`skinStage`) and recomputed on every collect.

---

## 2. Placement

### 2.1 Meadow collectibles (12) -- one per patch, patches 01..12
Anchor rule: `patch.Position + (4, 0, 3)`, Y = 3 (ladybug sits on the flower head; patch pivot Y = 2). Patch positions below are live Edit reads.

| Ladybug id | Patch | Patch position (live) | Anchor (X, Y, Z) |
|---|---|---|---|
| lb01 | Patch01 WhiteClover | (-300, -131) | (-296, 3, -128) |
| lb02 | Patch02 WhiteClover | (-100, -136) | (-96, 3, -133) |
| lb03 | Patch03 WhiteClover | (100, -134) | (104, 3, -131) |
| lb04 | Patch04 WhiteClover | (300, -131) | (304, 3, -128) |
| lb05 | Patch05 Dandelion | (-240, -161) | (-236, 3, -158) |
| lb06 | Patch06 Dandelion | (0, -156) | (4, 3, -153) |
| lb07 | Patch07 Dandelion | (240, -161) | (244, 3, -158) |
| lb08 | Patch08 Lavender | (-180, -196) | (-176, 3, -193) |
| lb09 | Patch09 Lavender | (10, -201) | (14, 3, -198) |
| lb10 | Patch10 Lavender | (185, -194) | (189, 3, -191) |
| lb11 | Patch11 Sunflower | (-90, -221) | (-86, 3, -218) |
| lb12 | Patch12 Sunflower | (90, -224) | (94, 3, -221) |

Ladybug id and patch are fixed in Config. The patch's own species/bloom state does not change ladybug visibility in v1.

### 2.2 Hub decor (4) -- roaming only, not collectible
Positions are chosen at build time from the set-dresser's wildflower clumps (hub redo step 6). Rule, numeric:
- Inside the hub envelope X -264..+264, Z -266..-406.
- Not within 8 studs of any pad centre (pads at Z -290, X -105..105, per hub redo step 2).
- Not within 6 studs of spawn (0, -336).
- Not on the ramp (-232, -332), the yardstick ruler (X -235..-229, Z -282..-339), or the den floor.
- At least 4 studs from each other.
- Suggested set (edit to match the final clumps): (-250, 3, -300), (-205, 3, -305), (-40, 3, -388), (45, 3, -392). Check each with a downward ray: it must hit a hub surface within 0.5 studs of the expected Y.

### 2.3 Exclusion zones (no ladybug, no anchor, no tap target)
- **Honey Obby footprint** X 118..152, Z -262..-2, plus a 3-stud margin: X 115..155, Z -265..0. **No meadow ladybug is inside it.** The 12 meadow anchors all have X <= 104.
- **Petal Path** Z -96..-80 (any X), and the plot decks/ramps Z -80..+55. Meadow anchors are all Z <= -128, so none are in these bands.
- **Hub pads, spawn, ramp, ruler, den**: see the 2.2 rule.
- **Conflict found: live Patch19 (Fireweed) sits at (130, -242), which is inside the obby footprint.** The hub redo section 13.2 preflight (no Patch* intersects the footprint) would **fail** for it. This is not a ladybug problem, but it blocks the obby build. Owner decision 5.

---

## 3. Data, profile and remote contract

### 3.1 Profile fields (additive, nil-safe)
```lua
profile.ladybugs = {
    found     = {},     -- string id ("lb01".."lb12") -> true
    companionOn = false,
    skinStage = 1,      -- 1..4, recomputed on every collect; server-owned
}
```
- `ensureLadybugs(profile)` in LadybugService fills any missing field on every read. Same pattern as CosmeticService's `ensureCosmetics`. This is the default path and is enough, so no version bump is needed.
- Architecture rule (migrations fill defaults) is also satisfied by the ensure-on-read. Recommend (minor) adding a `MIGRATIONS[n]` that fills these defaults once, for consistency with the schema rule. Owner decision 8 is optional here.
- Count is derived: `count = number of keys in found`. Do not store a separate count.
- SwarmService preserved-fields list: **add `ladybugs`** (collection is permanent, like achievements). Otherwise a swarm would wipe the journal.

### 3.2 Remote (one new RemoteEvent, one rate-limited entry)
Name: `RequestLadybug`, C→S. Route through RemoteRouter like every other remote.

| Payload | Server check |
|---|---|
| `{action="collect", id=string}` | `action` is in whitelist. `id` is in `Config.LADYBUGS` with `zone=="meadow"`. Not already in `found`. `Validator.NearPosition(player, anchor, Config.LADYBUG_COLLECT_RADIUS = 14)` (server reads character position; +6 tolerance already in Validator). Rate 4/s via `Validator.RateLimit(player, "RequestLadybug", 4)`. |
| `{action="companion", on=boolean}` | `on` is a boolean. `count >= Config.LADYBUG_COMPANION_UNLOCK` (3) before `on=true`. Rate 4/s (same bucket). |

- On success: server writes `found[id]=true` (or `companionOn`), recomputes `skinStage`, sets attributes (below), and fires the existing `Notify` S→C with a kid-friendly line ("You found a ladybug! 3 of 12."). Stage-up also fires `Notify` ("Your ladybug got spots!").
- On failure: `Notify` kind `error` with a plain reason ("That ladybug is already in your journal." / "Go a little closer to the ladybug!"). No detail about server internals.
- The client never sends a stage, a count, or a found list. Any extra field is dropped by Sanitize.

### 3.3 Server to client state (no new S→C remote)
Player attributes, written by LadybugService, replicated for free:
- `LadybugMask` (int) = sum of 2^(n-1) for each found meadow ladybug n = 1..12. Max 4095. Client decodes bits to show which entries are filled.
- `LadybugCount` (int) = count.
- `LadybugSkinStage` (int, 1..4).
- `LadybugCompanionOn` (bool).

Client stage-up moment: `GetAttributeChangedSignal("LadybugSkinStage")` on the local player. No extra remote.

Bootstrap already carries the profile on CharacterAdded. Attributes are set before that, so the client has the mask on first render.

### 3.4 Config additions (one file, ReplicatedStorage.Modules.Config)
```lua
Config.LADYBUGS = {
    { id="lb01", zone="meadow", patch=1, anchor=Vector3.new(-296,3,-128) },
    -- ... lb02..lb12 ...
    { id="hb01", zone="hub", anchor=Vector3.new(-250,3,-300) },
    -- ... hb02..hb04 ...
}
Config.LADYBUG_COLLECT_RADIUS = 14
Config.LADYBUG_FLY_RADIUS = 9
Config.LADYBUG_COMPANION_UNLOCK = 3
Config.LADYBUG_SKIN_STAGES = {
    { min=0,  name="Plain",    spots=2, shell=Color3.fromRGB(220,40,40) },
    { min=3,  name="Spotted",  spots=7, shell=Color3.fromRGB(220,40,40) },
    { min=7,  name="Gold",     spots=7, shell=Color3.fromRGB(255,200,60) },
    { min=12, name="Rainbow",  spots=7, shell="rainbow" },
}
```
- Stage `min` values must be strictly ascending. The client reads the table only for look; the server reads it for the stage number.
- Seasons later (see section 8): add a `seasonal` sub-table per stage. Do not change the stored number.

---

## 4. Controllers and server service

| Module | Location | Responsibility | Wiring |
|---|---|---|---|
| **LadybugService** (server) | `ServerScriptService.Systems.LadybugService` | Owns profile.ladybugs, `ensureLadybugs`, collect/companion checks, stage calc, attributes, Notify. No physics, no visuals. | Added to `Main` order after `CosmeticService`, before `AchievementService`. Handler registered in `RemoteRouter.Wire()` for `RequestLadybug`. |
| **LadybugController** (client) | `StarterPlayerScripts.Controllers.LadybugController` | Builds the 16 pooled ladybug models (client-only), roaming tween, fly-off on proximity (checked at 5 Hz via a `task.wait` loop, not Heartbeat), tap detection (raycast from camera on the ladybug hit part, sends `RequestLadybug collect`), reads `LadybugMask` for collected visual state (collected ones lose the sparkle; the meadow ladybug is removed from the field once found). | `require` + `Init()` in ClientMain's boot list, after `PatchController` (it reads patch positions only). |
| **CompanionController** (client) | `StarterPlayerScripts.Controllers.CompanionController` | Builds the companion (max 9 parts), follows the local character, applies stage look from `LadybugSkinStage`, plays the stage-up moment, rainbow loop for stage 4, shows the companion only when `LadybugCompanionOn` is true. | `require` + `Init()` in ClientMain boot list, after LadybugController. |
| **JournalPanel** (UI) | Inside existing `HiveGui` (DisplayOrder 11) as a new tab "Ladybugs". | 12-slot grid (filled or grey), count "3 of 12", stage ladder, companion on/off toggle (calls `RequestLadybug companion`). | Owned by LadybugController. Owner decision 7 (tab vs own ScreenGui). |

**Per-frame work: no new Heartbeat.** The companion lerp needs a per-frame update. Use the existing client Heartbeat: VfxController already owns one. Add a one-line hook: VfxController exposes `VfxController.RegisterUpdate(fn)` and calls registered `fn(dt)` inside its loop. CompanionController registers its follow update there. This is the single edit to VfxController. (Alternative with no VfxController edit: TweenService follow loop of 0.25 s steps. Lower quality, same budget. Not recommended.)

Not a second cosmetics system: the companion does not live in Config.COSMETICS, does not use `profile.cosmetics`, and does not write `EquippedSkin`. Equipping the bee body skin is unchanged.

---

## 5. Budget per part and totals

| Part | Studio saved parts | Client-only parts | Lights | Emitters (steady / burst) | Sounds | Remotes |
|---|---|---|---|---|---|---|
| Meadow collectibles (12) | 0 | 12 x 4 = 48 | 0 | 0 / 0 | 0 | 0 |
| Hub decor (4) | 0 | 4 x 4 = 16 | 0 | 0 / 0 | 0 | 0 |
| Companion (max 9) | 0 | 9 | 0 | 0 / 1 transient (stage-up) | 0 | 0 |
| LadybugService + journal UI | 0 | 0 | 0 | 0 | 0 | 1 (`RequestLadybug`) |
| **Totals** | **0** | **73 (pooled, up to 16 roaming instances, 1 companion)** | **0 (cap 2)** | **0 steady / 1 burst (cap 20 total)** | **0 (live 15, cap 25)** | **1** |

- Roaming ladybug parts: body Ball (1), head Ball (1), 2 spot Blocks (2) = 4 each. The 9-part companion is body + head + up to 7 spots.
- Pool: only ladybugs within 200 studs are instantiated. Max simultaneous client parts is 73 (all 16 + companion), which is far under any client budget.
- Studio totals after this feature: parts 2081 (unchanged), hub BaseParts 299 (unchanged, cap 300), game total unchanged. Obby plan (97 parts) and hub plan (351) are separate and not changed here.
- Emitters: 1 transient (burst, destroyed after 1.5 s). Steady ParticleEmitters stay at 0 live, so the cap of 20 is untouched.

---

## 6. Build order and checks

**L0. Preflight (Edit).** Read patches 01..12 positions. Check each anchor = patch + (4, 0, 3) within 0.05 studs. Check no anchor is inside the obby footprint with margin (X 115..155, Z -265..0). **Stop if Patch19 is still at (130,-242)** and the obby is being built in the same pass (owner decision 5 first).

**L1. Config (luau-scripter, one file).** Check: `#Config.LADYBUGS == 16`, collectible count = 12, ids unique, stage `min` ascending (0,3,7,12), `LADYBUG_COMPANION_UNLOCK` = 3, collect radius 14 > fly radius 9.

**L2. LadybugService + profile + RemoteRouter + Main wiring (luau-scripter).** Checks (server, run in Edit via a test key where possible, otherwise by code review):
- Unknown id `"lb99"` -> rejected, no write.
- Hub id `"hb01"` with action collect -> rejected.
- Far player (position > 20 studs from anchor, Validator tolerance included) -> rejected.
- Same id twice -> second rejected, `count` unchanged.
- Collect 3 -> `skinStage == 2`, attribute `LadybugSkinStage == 2`. Collect 7 -> stage 3. Collect 12 -> stage 4.
- Companion on with count 2 -> rejected. Count 3 -> accepted.
- Stage never accepted from client payload (extra field `skinStage` is dropped by Sanitize, verified by sending it and reading back the stored stage).
- Rate: 5 requests in 1 s -> the 5th rejected.
- `ensureLadybugs` on a profile with no `ladybugs` key -> returns defaults, does not error.

**L3. Client controllers (luau-scripter).** Checks: Play-free: LadybugController and CompanionController Source contains no `Heartbeat:Connect` (grep), VfxController has the one `RegisterUpdate` hook. No `Sound` created (grep). Emitter count after a stage-up is 1 transient and 0 after 1.5 s.

**L4. Hub decor placement (world-builder or set-dresser, client-only anchors, no Studio parts).** Check each of the 4 anchors against the 2.2 rule with a downward ray and a distance scan to pads, spawn, ramp, ruler and den. Check Hub BaseParts still 299 (no new parts saved).

**L5. Journal UI tab (ui-designer, optional).** Check: all 12 slots sized Scale-based, text readable, no interaction with HiveGui's existing tabs.

**L6. Play checklist (coordinator to batch).**
1. Walk to a meadow ladybug; it flies off within 9 studs and returns in about 8 s.
2. Walk into 14 studs of lb01; tap it; journal count = 1; ladybug disappears from the field.
3. Tap a hub ladybug; nothing happens; no `RequestLadybug` sent (check remote log).
4. Collect 3; companion appears at 2 spots; stage-up bounce plus one sparkle; no sound.
5. Collect 7; stage 3 gold; collect 12; rainbow loop on the companion.
6. Companion toggle off; companion gone; on again; follows the character at offset.
7. Rejoin the server; journal and stage restored (profile round-trip).
8. Swarm; journal and stage survive (`ladybugs` in preserved list).
9. Frame rate check on a phone emulator: no drop with 16 roaming ladybugs in view.

---

## 7. Achievements and cross-feature checks
- No ladybug achievement is wired in v1 (owner decision 3). Config.ACHIEVEMENTS stays at 15.
- Tutorial, route beams, dance, build and queen systems: unaffected. No shared remote or tick beyond VfxController's update hook.
- Hub redo: the 4 hub decor ladybugs are client-only, so the hub's saved part count stays at 299.
- Honey Obby: the obby footprint stays clear of the meadow ladybugs. The only conflict is Patch19 (owner decision 5).

---

## 8. Skin stages and the seasons layer (later, not built now)
- The stored `skinStage` is a collection number. It is never changed by season. A season only changes the look, through a `seasonal` sub-table per stage in `Config.LADYBUG_SKIN_STAGES` (for example a winter scarf, or a bloom-season colour). The stored number and its thresholds do not change, so saves stay valid.
- Season state comes from the existing TimeService/weather attributes; the companion reads the attribute on the client and swaps the look. No new remote.
- Seasonal ladybugs (extra limited-time bugs) would be new Config entries with `zone="meadow"` and a `season` field. They are not added in this build. The collection total stays 12 until the seasons addendum decides otherwise (that would move the stage 4 threshold).

---

## 9. Owner decisions (each with a recommended default)

1. **Companion unlock and stage 2 threshold: 3 found.** Default 3 (a young child sees the companion in one short walk). Alternative: 6 (later, more hunting).
2. **Stage thresholds and looks: 3 / 7 / 12 with plain red, 7-spot, gold, rainbow.** Default as in section 1. Stage 4 uses all 12, so it is reachable only by a full journal. Alternative: 3 / 6 / 9 with a 9-meadow count (cut 3 ladybugs) so stage 4 is reachable sooner.
3. **Achievement: none.** Default: no ladybug achievement. Option: `ladybugFinder` "Ladybug Friend" for a full journal (Config.ACHIEVEMENTS 15 -> 16, ACHIEVEMENTS_ORDER +1, one-line hook in LadybugService).
4. **Companion visibility: local only in v1.** Default: local. Option: server-replicated companion (about 9 parts per player, up to 54 parts for 6 players; costs the budget and needs a server follow loop, so not recommended now).
5. **Patch19 (Fireweed, live at (130,-242)) inside the obby footprint.** Default: move Patch19 out of the footprint to (60, -242) (checked: 30+ studs from Patch12 at (90,-224), 140 studs from the obby footprint's west edge). Alternative: shift the obby. The obby is blocked until this is decided.
6. **Hit size for tap on phones: 2.5-stud sphere on each ladybug + 14-stud collect radius.** Default as stated. Alternative: 3.5-stud sphere if playtest finds misses.
7. **Journal location: a new "Ladybugs" tab in HiveGui.** Default: tab. Alternative: a separate ScreenGui (adds a new DisplayOrder to the GUI list).
8. **Profile migration for `ladybugs`: ensure-on-read only.** Default: ensure-on-read (satisfies the brief). Option: a `MIGRATIONS[n]` fills defaults once, matching the architecture's stated rule (recommended if the coordinator wants the schema doc to stay strict).
9. **Sound count mismatch (live 15, documented 24).** Not a ladybug decision. Flagged for the audio gate: ladybugs add 0 either way.

---

READY FOR REVIEW
