# A Bee's World: Seasons Layer Addendum (visual-only)

Status: SPEC, not built. Read-only Studio inspection done (place 123313915411717). No yields, weather states, quests or Studio writes change in this pass.

Source facts verified from live code:
- Owner module: `ServerScriptService.Systems.TimeService` (single `RunService.Heartbeat`, 1s accumulator, `Tick(1)`).
- `Tick` calls `applyLightingForHour`, which cancels and rebuilds ALL active tweens every second (Brightness, Ambient, OutdoorAmbient on Lighting; Saturation and TintColor on `ColorCorrection`; Intensity on `SunRays`). Any season tween outside this list would be cancelled or would fight it. So the season layer must feed the SAME target computation, not a second tween loop.
- TimeService does NOT touch `Atmosphere`, `BloomEffect`, `DepthOfField`, `ExposureCompensation` or `GlobalShadows`. Season adds only Atmosphere.Color and BloomEffect.Intensity, and both go through the same `activeTweens` list.
- Weather is session-random (`math.random` shuffle, state not persisted). Seasons must NOT depend on it.
- Lighting limits (architecture.md Lighting Design Brief + lighting-director rules): Atmosphere Density <= 0.28 in play (hard cap 0.4), Bloom Intensity < 0.5, Bloom Threshold >= 0.5 (stays 0.82).

---

## 1. Season model

- Four seasons in fixed order: Spring (1), Summer (2), Autumn (3), Winter (4).
- Season length: `SEASON_SECONDS = 3600` real seconds (60 real minutes). A year is 4 real hours.
  - Why: a child's play session is roughly 20 to 40 minutes, so a 60-minute season is usually seen as a change across one or two sessions (the owner can reduce this to 1800 if kids need it sooner). An adult sees all four seasons in one day of play, so the adult goal is not "wait for summer" but a visible seasonal cycle to return to. The adult long-term goal beyond visuals is an owner decision (section 7).
- Derivation (stateless, no DataStore, no Heartbeat state needed):
  ```
  local SEASON_SECONDS = 3600
  local SEASON_BLEND_SECONDS = 60
  local function seasonAt(epochSeconds: number): (number, number)  -- (index 1..4, blend 0..1 from previous season)
      local slot = math.floor(epochSeconds / SEASON_SECONDS)
      local index = (slot % 4) + 1            -- epoch 0 = Spring start (arbitrary, documented)
      local into = epochSeconds - slot * SEASON_SECONDS
      local blend = math.clamp(into / SEASON_BLEND_SECONDS, 0, 1)  -- 1 = fully new season
      return index, blend
  end
  ```
  - Blend is the first 60s of each season lerping from the previous season's look. Blend = 1 after 60s, so the look is the season's own look for the rest of its length. This makes season flips a 60s crossfade rather than a snap.
  - Uses `os.time()` (UTC). Same value for every player and server; survives restart because it is pure time.
- `CurrentSeason` lives inside TimeService as a local, recomputed each `Tick` (no new state). `TimeService.GetSeason(): (index, name)` public accessor.
- Season names: `{"Spring", "Summer", "Autumn", "Winter"}`.

## 2. Visual per season

Season look is a set of MULTIPLIERS/OVERRIDES blended by `blend` and by day factor. Night keeps its values; season tint applies at full strength by day and at 50% at night (so winter nights are not bluer than the night baseline already is).

| Season | Label | Foliage (grass tufts) | CC TintColor (multiplied onto the time tint) | CC Saturation delta | Outdoor ambient tint (multiplied) | Atmosphere.Color | Bloom Intensity |
|---|---|---|---|---|---|---|---|
| Spring | Spring | `#8FD36A` | `#F3FFEA` | +0.06 | `#EEF7E4` | `#F2F8DA` | 0.46 |
| Summer | Summer | `#5FAE2E` | `#FFFFFF` (none) | +0.10 | `#FFFFFF` (none) | `#FCEFC6` (base, unchanged) | 0.48 |
| Autumn | Autumn | `#C98A2E` | `#FFE7C2` | +0.02 | `#F5E3C4` | `#F7DDB0` | 0.44 |
| Winter | Winter | `#B9C9B0` | `#E6F0FF` | -0.08 | `#DCE6F5` | `#E4EEFA` | 0.40 |

Rules:
- Bloom Threshold stays 0.82 in all seasons. Only Intensity moves, and every value is < 0.5.
- Atmosphere Density is NOT changed by seasons. It stays at the lighting-director value (0.16). Only Color moves.
- Saturation result stays within [-0.10, +0.20] at all times. Day Saturation 0.16 + delta is at most 0.26; this is above the cap, so the season delta is clamped: final Saturation = `math.clamp(base + delta, -0.1, 0.2)`. Summer's +0.10 is clamped to 0.20 at day.
- TintColor = `timeTint:Lerp(timeTint * seasonTint, strength)` per channel, where `strength` = 1 by day, 0.5 by night. Clamp each channel to [0,1]. Using multiply keeps honey amber dominant; no season tint is allowed to push honey out of the brightest slot.
- Foliage: applied client-side to parts tagged `GrassTuft` (existing tufts; expected 3 to 6 per the architecture note on "a few tufts"). Only the grass is recoloured. Flower heads are NEVER recoloured (palette rule: flower colours are the only hues other than the palette). Confirm the tag exists in Studio; if not, world-builder adds the tag to existing parts (0 new parts). Store each part's original colour in an attribute `BaseColor` on first apply.
- Label: a plain-words TextLabel in the existing HUD column (top-left, under the quest badge), text `Spring` / `Summer` / `Autumn` / `Winter`. Hidden if the owner declines the label (section 7).

## 3. Gameplay: NONE in this pass

- Foraging yields, `GetWeatherMultipliers`, nectar and flight multipliers: UNCHANGED.
- Quests (RetentionService pool): UNCHANGED.
- Species bloom windows: UNCHANGED. Seasons do not gate species.
- Weather state machine (Clear/Breezy/Overcast/Rain/BloomRush): UNCHANGED. Seasons do not change weather odds or durations.
- Optional later yield multiplier: see section 7 (owner decision). Recommended default if approved: 1.00 for all seasons at launch, then at most +/-10% per season, applied only through the existing species/weather multiplier path, never as a new formula.

## 4. Integration

- Code location: inside `TimeService` only.
  - Add the season table and `seasonAt` near the DAY/NIGHT tables.
  - In `applyLightingForHour(hour, tweenDuration)`, after computing the existing targets, compute `seasonLook` for the current season and blend, then add to the same tween list:
    - Lighting: no change (Brightness/Ambient/OutdoorAmbient targets get the outdoor tint multiplied in).
    - ColorCorrection: Saturation (clamped) and TintColor (multiplied) targets.
    - Atmosphere: Color target (new `TweenService:Create` into `activeTweens`, so the existing cancel logic covers it).
    - BloomEffect: Intensity target (new Create into `activeTweens`).
  - No new Heartbeat, no new timer. `onHeartbeat` and `Tick` are unchanged except that `Tick` also re-derives the season index and, if it changed, sets the attributes below once.
- Attributes on `Lighting` (replicate automatically, no remote):
  - `Season` (string: "Spring" etc.)
  - `SeasonIndex` (number 1..4)
  - `SeasonBlend` (number 0..1, updated only when it changes by more than 0.05, to avoid attribute churn)
  - `SeasonNextAt` (number, os.time() when the current season ends)
  - Reason for attributes over a remote: the value is pure time, so every client can derive it; attributes survive a late join with zero extra traffic. No new RemoteEvent.
- Client controller: `StarterPlayerScripts` (or the existing ClientMain boot), `SeasonController`:
  - Reads `Lighting:GetAttribute("Season")` on boot and connects `GetAttributeChangedSignal` for the three season attributes.
  - Applies foliage colour to `GrassTuft` parts (tween 60s to match the blend, or set directly; direct set is fine since the blend is 60s).
  - Updates the season label text.
  - Never writes Lighting or post-processing (server owns those, so no client/server fight).
- Join behaviour: `TimeService.Init` sets the four attributes BEFORE the first `applyLightingForHour`, so a joining player receives the current season in the initial replication. The client controller runs once on boot and applies the current look instantly (0 s tween). No "Spring" flash on join: the label is set from the attribute, not a default.
- Test hooks (match the module's `_name` convention): `TimeService._SeasonAt(epoch)` returns `(index, blend)`, and `TimeService._SeasonLook(index, blend, dayFactor)` returns the computed targets, so Edit-mode checks can run without waiting for real time.

## 5. Budgets

- New parts: 0.
- New lights (PointLight/SpotLight/SurfaceLight): 0.
- New sounds: 0.
- New ParticleEmitters or Beams: 0.
- New RemoteEvents: 0 (attributes only).
- New tweens: 2 per applied tick (Atmosphere.Color, BloomEffect.Intensity), added to the existing 1 Heartbeat tween set. Tween cost is already paid by TimeService each second.
- Client work: 1 label, up to 6 `GrassTuft` colour sets per season change.

## 6. Build order and checks

Build order:
1. Add `seasonAt` and the season table to TimeService (Edit-mode test hooks only). No Lighting changes yet.
2. Add the four `Lighting` attributes in `Init` and in `Tick` (on change only).
3. Extend `applyLightingForHour` with season targets (Atmosphere.Color, BloomEffect.Intensity, clamped CC Saturation and multiplied TintColor).
4. Tag check: confirm `GrassTuft` tag on meadow tufts (world-builder if missing; tags only).
5. Client `SeasonController`: label + foliage.
6. Run Edit-mode checks, then Play checks.

Edit-mode numeric checks (run via `execute_luau`, datamodel Edit, after `Init`):
- Derived season for test epochs (3600 s seasons, epoch 0 = Spring):
  - `0` -> index 1 (Spring), blend 0
  - `3599` -> index 1, blend 1 (into = 3599 is past the 60s blend, so clamped to 1)
  - `3600` -> index 2 (Summer), blend 0
  - `3630` -> index 2, blend 0.5
  - `10800` -> index 4 (Winter), blend 0
  - `14400` -> index 1 (Spring, wrap), blend 0
  - `1700000000` -> index 3 (Autumn), blend 0 (472222 mod 4 = 2, +1 = 3; into = 0)
- Lighting values after Init, for each season index with dayFactor = 1 (noon):
  - Bloom.Intensity in [0.40, 0.49] for all seasons
  - Bloom.Threshold == 0.82
  - Atmosphere.Density == 0.16 (unchanged) and <= 0.28
  - ColorCorrection.Saturation in [-0.10, 0.20]
  - ColorCorrection.TintColor channels all in [0, 1]
- Night check (dayFactor = 0): season tint strength 0.5, so TintColor is closer to the night base `#E2EAFF` than to the season's own tint (distance check < distance to the day tint).
- Yield check: `ForagingService` outputs for a fixed patch/route are identical before and after the change (run the QA runner harness once in each season). Must be byte-identical.
- Weather check: `TimeService.GetWeatherMultipliers()` unchanged across a season boundary.

Play checks (separate list, real time):
- P1. Join during Spring: label reads "Spring", grass is the Spring green, no flash.
- P2. Stay through a season boundary (or use a test value of `SEASON_SECONDS = 60` in a test build): look tweens over about 60s, no snap, no white-out at noon, honey stays the brightest thing in frame.
- P3. Rejoin after a restart: label matches the epoch derivation, not a reset to Spring.
- P4. Two clients on different machines show the same season label at the same moment.
- P5. Frame time unchanged (no added Heartbeat work beyond two tween targets).
- P6. Weather still cycles (Clear -> Breezy -> Overcast -> Rain -> BloomRush) and Rain still halts flight.

## 7. Owner decisions (with recommended defaults)

1. Season length. Default: 3600 real seconds (60 min; year = 4 h). Alternative: 1800 s for faster kid feedback. Do not go longer than 3600 s before there is a long-term adult goal, or kids will not see the change in a session.
2. HUD season label. Default: YES, plain word, small, in the existing HUD column. Alternative: no label, visuals only (kids still see the change; adults get less signposting).
3. Yield multiplier later. Default: NO for launch. Recommended if approved later: 1.00 at launch, then at most +/-10% per season through the existing species/weather multiplier path, only after two weeks of play data. Needs explicit owner approval before any code touches ForagingService.

Adult long-term goal (not in this pass, for the owner to pick if wanted): a seasonal collectible or a per-season plot badge. Recommended default: none yet. Build the visual layer first.

READY FOR REVIEW
