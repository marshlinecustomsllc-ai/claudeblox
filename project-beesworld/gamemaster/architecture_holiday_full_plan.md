# A Bee's World: Holiday Full Server System, Staged Build Plan

Status: PLAN ONLY. Nothing in this document has been built. Read-only inspection of Studio (place 123313915411717) was done; no writes, no play mode.
Sources: cycle14_holiday_core_dispatch.md (154), cycle14_holiday_world_dispatch.md (155), cycle14_holiday_bees_dispatch.md (157) from git (commits 882ae13, 51af5d7); live `ReplicatedStorage.Modules.Config` (lines 1184-1206) and `StarterPlayerScripts.Controllers.HolidayDecorController`.

---

## 1. Briefs vs. what is live

### Live now
- **Harvest Lanterns decor** (client-only). `Config.HOLIDAY` is a single table: UTC window Oct 18 to Oct 31, 6 lanterns (post plus glow ball) and 2 bunting strings. `HolidayDecorController` builds them into `Workspace.ClientFX.Holiday`, rechecks every 60s, and destroys the folder outside the window. No lights, emitters, sounds, or remotes.
- Today (2026-10-04) the window is **not** active, so the decor is not visible.
- **Not live:** `HolidayService`, `HolidayWorldService`, `HolidayController`, `HolidayCombSkins`, `ActiveHoliday` attribute, `CommunityRework_153` hub folder (searched via script_grep, no matches for HolidayService or ActiveHoliday). The 155 brief's hub target was not verified and must be checked before Stage 2.

### Briefs
| Brief | Ask (one line) | Economy impact |
|---|---|---|
| 154 Core | Server `HolidayService` reads a 5-holiday calendar, writes `ActiveHoliday`, `HolidayDaysLeft`, `HolidayHoneyMult` to players; client countdown pill and welcome toast; patches CombService with `holidayMult_154`. | **Yes.** `HolidayHoneyMult` (1.10 to 1.25) multiplies honey production. |
| 155 World | Server `HolidayWorldService` creates or destroys seasonal parts in `Hub.CommunityRework_153.SeasonalParts`, recolours existing lanterns and fountain emitters, and a client `HolidayCombSkins` adds emoji prefixes to comb labels. | No direct economy change. Mutates shared world on the server (replicates to all players). |
| 157 Bees | DataService v12 to v13 (`specialistBees` table), `SpecialistBeeService` ModuleScript, four holiday bees with 150-honey unlock costs, a 13-honey midnight unlock, and stat buffs (+8% foraging, +20% bloom, doubled sunny bonus, cold-penalty removal). | **Yes.** Costs spend honey; buffs change earnings; schema change. |

---

## 2. Stages

### Stage 1: HolidayService (server), data and attributes only
- **Scope:** Read the holiday calendar. Expose the active holiday as a server-side attribute on each player (`ActiveHoliday`, `HolidayDaysLeft`). No honey multiplier. No remote.
- **Files:**
  - NEW `ServerScriptService.HolidayService` (Script, `--!strict`, pure date logic; wrap logic in a ModuleScript if a test hook is needed).
  - EDIT `ReplicatedStorage.Modules.Config`: replace the single `Config.HOLIDAY` table with `Config.HOLIDAYS` (ordered list). Keep the Harvest Lanterns entry as the first item, with its current window and decor data unchanged.
  - EDIT `HolidayDecorController`: iterate `Config.HOLIDAYS` (or keep reading the Harvest entry) in the same change as the Config edit, so the decor never breaks.
- **Player-visible change:** None. No pill, no toast, no bonus yet (the 154 pill and toast are deferred to Stage 2 as visual).
- **Saved data or earnings:** Neither. No profile field. No version bump.
- **Brief 154 items removed from this stage:** `HolidayHoneyMult`, the CombService patch, and the `HOLIDAYS_154` calendar that conflicts with the live window (see Owner decision 1).
- **Risk:** Low. Main risk is a Config shape change breaking `HolidayDecorController`. Mitigation: edit both files together and verify the decor folder count matches before and after.
- **Numeric checks:**
  - Pure function: for each of the 5 holiday windows, check day before, first day, last day, and day after (expect 0 and 1 at the edges). Check the winter wrap (Dec 20 to Jan 2) separately.
  - Harvest decor: `Workspace.ClientFX.Holiday` child count equals 6 lanterns x 2 parts + 2 bunting x (1 string + 3 flags) = 28 parts when forced active.
  - Attribute present on every player; `ActiveHoliday` is `""` on a date with no holiday.
- **Parts:** +1 permanent (Script). Client parts: 0 (decor unchanged).
- **Lights / emitters / sounds:** 0 / 0 / 0.

### Stage 2: Holiday world transforms (visual only, client-side)
- **Scope:** Generalise the existing `HolidayDecorController` pattern to all holidays, switched by the `ActiveHoliday` attribute. Add the 154 countdown pill and welcome toast as client UI (visual only). Add the 155 comb-label emoji skins as client-only cosmetic text.
- **Files:**
  - EDIT `HolidayDecorController` (per-holiday decor lists, rebuild on attribute change).
  - NEW `StarterPlayerScripts.Controllers.HolidayHudController` (pill and toast, from 154 Step B).
  - NEW `StarterPlayerScripts.Controllers.HolidayCombSkins` (from 155, client-only).
  - EDIT `Config.HOLIDAYS` (decor lists per holiday).
  - Server-side hub transforms from 155 are **not** built as written (see Owner decision 3). If approved, they become a client decor layer in `Workspace.ClientFX.Holiday`.
- **Player-visible change:** Decor, countdown pill, welcome toast, and comb emoji during each window. No earnings change.
- **Saved data or earnings:** Neither.
- **Risk:** Low to medium. Client-only code that rebuilds decor. Watch for duplicate folders on attribute flip and for the welcome toast firing every session (guard once per session).
- **Numeric checks:**
  - Each holiday's decor at most 30 client parts; the total across all holidays at most 60 when a single holiday is active.
  - Rebuild check: switching attribute twice leaves exactly one `Holiday` folder.
  - Comb skins: when no holiday is active, zero labels carry an injected prefix.
- **Parts:** 0 permanent. Temporary client parts per active holiday: at most 30.
- **Lights:** At most 4 PointLights total, client-side, inside `ClientFX.Holiday` only. The 155 brief's "blue-tinted point lights on string lights" is capped to this number. Confirm the lighting budget with the owner (Owner decision 5).
- **Emitters:** 0 new. The fountain colour change (155) only if the fountain emitter already exists; no new emitter.
- **Sounds:** 0 new.

### Stage 3: Specialist holiday bees, visual skins only
- **Scope:** During the window, the bee models in the swarm use a holiday skin (colour, hat or accessory parts). Client-side appearance only. **No new bee stats, no unlocks, no costs.**
- **Files:**
  - EDIT the bee appearance code (client `BeeController`/pool code; exact file to be confirmed by reading before build).
  - NEW `ClientFX` skin helper, if needed.
- **Player-visible change:** Holiday-coloured bees while the holiday is active.
- **Saved data or earnings:** Neither.
- **Risk:** Low. Main risk is pool cost (cloning models) and skin parts pushing the bee part count up. Keep skins to recolour plus at most 2 parts per bee.
- **Numeric checks:** Bee part count per bee at most base + 2. Bee pool still capped at the existing limit; no increase.
- **Parts:** 0 permanent. Per bee at most +2 temporary client parts.
- **Lights / emitters / sounds:** 0 / 0 / 0.

### Stage 4: Holiday earnings, prices, rewards (OWNER APPROVAL REQUIRED, NOT PLANNED AS BUILT)
Everything below changes the economy and needs a separate owner approval and a full test pass (play-test with computer-player, a balance sheet of honey per hour with and without the bonus, and a check that no stacking exceeds the cap). Nothing in this stage is approved.
- Honey multiplier by holiday (154 table: 1.10 to 1.25) and its CombService patch.
- Specialist bee unlock costs (150 honey each) and the 13-honey Halloween midnight discount.
- Specialist bee stat buffs (foraging +8%, bloom +20%, sunny bonus doubled, cold penalty removed).
- Any holiday-only reward or achievement that pays honey.

### Stage 5: DataService migration (only when Stage 4 is approved and needs a saved field)
- **Scope:** Add `specialistBees = {ghost, frost, blossom, solar}` (booleans) and, if chosen, `holidayHistory` (list of holiday id plus year). Additive and nil-safe.
- **Files:** EDIT `ServerScriptService.Systems.DataService` (PROFILE_TEMPLATE plus a migration entry). The 157 brief patches the template from the Command Bar; do not repeat that. Put the change in the module and let reconcile fill defaults.
- **Version:** Read the live `DataService` version before building. The 157 brief assumes v12 to v13; this has not been verified. Architecture.md states the migration chain rule (each new field needs a migration that fills a default).
- **Reconcile risk:** A session that loaded the old template could save a profile without the new field. Fix: fill defaults on load (not only in the migration) and test a profile saved by the old version.
- **Player-visible change:** None by itself.
- **Saved data:** Yes (this stage is the saved-data stage).
- **Numeric checks:** Loading a v-old profile yields `specialistBees` with 4 false values; saving and reloading keeps them; no profile loses fields (count keys before and after).
- **Parts:** 0. Lights / emitters / sounds: 0 / 0 / 0.

---

## 3. Out of scope, and why
- **Honey multiplier and CombService patch (154):** Changes earnings. Deferred to Stage 4 pending approval.
- **Specialist bee costs, midnight 13-honey unlock, and stat buffs (157):** Spend honey and change earnings. Stage 4. The midnight discount is also a clear exploit route (players can time it) and is not recommended at all.
- **Server-side hub mutation (155):** The brief recolours shared hub lanterns and fountain emitters on the server, which replicates to every player and is harder to roll back. Replaced by client decor (Stage 2) unless the owner insists.
- **FestivalMeterService (156) and any reward it pays:** Not in these three briefs; not planned here.
- **New sounds:** The briefs add none. No sound assets are in scope.
- **Any new asset (models, textures, meshes):** We do not have them. Holiday models use primitives only.
- **Leap-year handling and a remote for reading the holiday:** The attribute already replicates to the player, so a separate remote is not needed (see Owner decision 6).

---

## 4. Owner decisions (each with a recommended default)

1. **Calendar and overlap.** The live Harvest Lanterns window is Oct 18 to 31; the 154 Halloween window is Oct 25 to 31, so they overlap. **Default:** keep the live entry; set Halloween to Oct 18 to 31 as the window; one holiday active at a time; the first matching entry in `Config.HOLIDAYS` wins. Confirm the date ranges with the owner.
2. **Clock.** Live decor uses UTC; the 154 brief uses local `os.date`. **Default:** UTC everywhere, so decor and attribute always agree.
3. **Hub world transforms (155).** **Default:** client-side decor in `ClientFX.Holiday` (Stage 2), not server-side edits to shared hub parts.
4. **Earnings bonus on holiday days (Stage 4).** **Default:** none in the first release. If approved later, a small bonus only (for example +5% honey on holiday days), capped so it never stacks above x1.10 with other multipliers. Needs a balance pass.
5. **Light and emitter budget.** Brief 155 wants several point lights. **Default:** at most 4 client PointLights total, inside `ClientFX.Holiday` only, and no new server emitters.
6. **Read-only remote.** Brief 154 asks for one. **Default:** no remote; the replicated attribute is enough.
7. **Specialist bees (Stage 4).** **Default:** do not build the 150-honey costs. Prefer a cosmetic or achievement unlock (free) during the window, with buffs deferred until the economy review. Remove the 13-honey midnight discount.
8. **Schema change (Stage 5).** **Default:** add no `holidayHistory` field unless a stage needs it; add `specialistBees` only when Stage 4 is approved.

---

## 5. Budgets per stage

| Stage | Permanent parts | Temporary client parts (per active holiday) | Server parts | PointLights | Emitters (new) | Sound objects (new) |
|---|---|---|---|---|---|---|
| Live baseline | not re-counted here (briefs cite 4,194 / 5,000; verify with a live count before Stage 1) | Harvest: 28 | 0 | 0 | 0 | 0 |
| 1 HolidayService | +1 (Script) | 0 change | 0 | 0 | 0 | 0 |
| 2 World and HUD | 0 | at most 30 per holiday | 0 | at most 4 | 0 | 0 |
| 3 Bee skins | 0 | at most +2 per bee | 0 | 0 | 0 | 0 |
| 4 Earnings (approval) | at most +2 (157 Unlock panel and anchor only if approved) | 0 | 0 | 0 | 0 | 0 |
| 5 DataService | 0 | 0 | 0 | 0 | 0 | 0 |

Global ceiling: keep the total permanent part count under 5,000 (verify the live number first). Holiday-related sound objects: 0 across all stages. No new emitters in Stages 1 to 3.

---

## Next step
Owner approves Stage 1 and answers decisions 1, 2, and 6. Stages 2 and 3 are approved separately after Stage 1 is verified. Stage 4 needs its own approval and a test pass.

READY FOR REVIEW
