# Kid-Friendly Mechanics Review -- Feature Architecture (Addendum)

## Overview
Two mechanics were flagged as possibly too hard for 7-9 year olds: the waggle-dance two-tap timing game, and the placement rules for the 5 comb cell types. I read the live source in Studio (place 123313915411717): DanceService, DanceController, Formulas (DANCE section), Config.DANCE, Config.DANCE_FLOOR_TIERS, BuildController, CombService.CanBuild/GetAdjacencyBonus, Config.CELLS and HexGrid.IsRim. I also measured all 108 Dance-Floor-to-patch distances. **The live implementation no longer matches the numbers in the brief or in architecture.md**, and neither mechanic has the problem it was suspected of having.

- **Dance:** the tolerance bands are no longer the real problem. A kid-simplicity pass already widened them. What still hurts young mobile players is **input timing**: the TAP button fires when the finger is lifted, not when it touches the screen. That adds a built-in "late" error about as large as the whole Perfect window. There is also one wrap-around edge case on the far patches. Fix: a small code change plus 4 Config values.
- **Comb:** there is only **one** hard placement rule ("edge only", shared by Royal and PropolisSeam), and it applies to 12 of the 18 buildable cells. The rule is simple. The problem is the **signal**. The highlight tells legal from illegal cells by hue alone (green vs red, blended over gold plates), and the outline, the crispest element, is identical on both. Keep the rules; change the visuals as specified below.

## Feature Scope
- **Type:** tuning + client visual change
- **Flavor:** SYSTEMIC (no world geometry changes)
- **Subagents needed:** luau-scripter only (ui-designer is not required; all values are specified here)
- **World changes:** none
- **Files touched:** `ReplicatedStorage.Modules.Config`, `StarterPlayer.StarterPlayerScripts.Controllers.DanceController`, `StarterPlayer.StarterPlayerScripts.Controllers.BuildController`, `ServerScriptService.Systems.CombService` (one error string)

---

## QUESTION 1 -- Waggle dance two-tap timing

### 1.1 What the live code actually does
| Fact | Live value | Source |
|---|---|---|
| Sweep | one sawtooth 0->1, **3.0 s** per cycle (not 2.4) | `Config.DANCE.sweepPeriodSeconds`, `Formulas.DanceDialValue` |
| Distance range | **760 studs** (not 300) | `Config.DANCE.maxDistanceRange` |
| Distance tolerance | Perfect **38**, Good **75** studs (not 20/50) | `Config.DANCE.distanceToleranceStuds` |
| Angle tolerance (T1) | Perfect <= 18 deg, Good <= 36 deg | `DANCE_FLOOR_TIERS[1].goldenZoneDegrees = 18`, Good = 2x |
| Grade | `min(angleGrade, distGrade)`, so **both** taps must land | `DanceService.SubmitDance` |
| Yield | Perfect 1.25 / Good 1.0 / Poor 0.7; Poor is shown as "Nice Try!" | `QUALITY_BY_GRADE`, `GRADE_DISPLAY_TEXT` |
| Target preview | gold target mark + Good ticks on dial; Good/Perfect bands on bar | `DanceController.drawTargetMarkers` |
| Keyboard tap | `UserInputService.InputBegan` (fires on **press**) | `onInputBegan` |
| Touch tap | `tapButton.MouseButton1Click` (fires on **release**) | `DanceController.Init` |
| Patch distances | 139-722 studs across all 108 plot/patch pairs; 2 pairs sit at dial > 0.9 (e.g. AuroraBloom at 721 studs = dial 0.95) | measured live |

Converted to time (this is the number that matters for a timing game):
- Angle T1: Perfect = +/-150 ms, Good = +/-300 ms (120 deg/s needle).
- Distance: Perfect = 38/760 x 3.0 = +/-150 ms, Good = +/-296 ms.
- So the two axes are consistent, and the windows themselves are reasonable. A +/-150 ms Perfect window is roughly a "hit the note" window in a casual rhythm game.

### 1.2 Finding
**The tolerance bands are not the main problem. The error budget is being eaten before the kid's skill even counts.**

1. **Release-fired touch input (the big one).** `MouseButton1Click` fires when the finger **lifts**. A child's tap lasts about 100-150 ms. On top of that, phone display and input pipelines add about 60-100 ms of lag. The result is a systematic **~+200 ms late bias on mobile**. That is larger than the entire Perfect half-window (150 ms) and two-thirds of the Good half-window (300 ms). Desktop Space-bar players do not have this bias, so the mobile majority is playing a harder game than PC players.
2. **Two taps must both land** (`min` of the two grades), so every per-tap miss rate roughly compounds.
3. **Wrap-around on far patches.** The distance bar is a sawtooth. For a target at dial 0.95 (AuroraBloom, 721 studs), the Good band runs from 0.85 up to the clip at 1.0. A tap only 150 ms late wraps the bar back to 0 and scores about 700 studs of error: an automatic Poor. The late bias from point 1 makes this likely. The best late-game flower is the hardest one to dance, for a purely technical reason.
4. **Two things move at once.** During tap 1 the distance bar also fills, and during tap 2 the needle keeps spinning, because both read the same dial value. A 7-year-old does not know which one to watch. After tap 1 there is also no visual confirmation of where the tap landed.

Rough model: normal timing spread SD ~120-150 ms for a 7-9 year old doing anticipation timing. **These are estimates, not playtest data.**
| Player | Perfect (both taps) | Good or better |
|---|---|---|
| Young kid on phone, **today** (bias +200-250 ms) | ~6-11% | ~40-63% |
| Young kid on phone, **after fixes below** (bias ~+80 ms, windows +/-170/340 ms) | ~40-57% | ~86-97% |
| Adult on PC, after fixes | ~85%+ | ~99% |

Verdict: **yes, the mechanic is too hard for the target player today, but the fix is input latency, not wider bands.** Widening the bands alone would not remove a bias bigger than the window, and it would erase the skill ceiling for older kids.

### 1.3 Recommendation (exact changes)

**D1 -- Fire the touch tap on PRESS, not release** (`DanceController.Init`)
- REMOVE: `tapButton.MouseButton1Click:Connect(registerTap)`
- ADD:
  ```lua
  tapButton.InputBegan:Connect(function(input: InputObject)
      if input.UserInputType == Enum.UserInputType.Touch
          or input.UserInputType == Enum.UserInputType.MouseButton1 then
          registerTap()
      end
  end)
  ```
- Leave the Space-key path unchanged (it already fires on press).

**D2 -- Double-tap guard** (`DanceController.registerTap`)
- Add `local TAP_REARM_SECONDS = 0.25` and `local tap1Clock: number? = nil`.
- On tap 1, set `tap1Clock = os.clock()`.
- On a tap-2 attempt: if `os.clock() - tap1Clock < TAP_REARM_SECONDS`, **return without consuming the tap**. Kids double-tap by reflex; today the second tap locks in a garbage distance.
- Reset `tap1Clock = nil` in `showIdle()` and in the patch-button click handler, next to the existing `tap1Value = nil` lines.

**D3 -- Config.DANCE retune** (`ReplicatedStorage.Modules.Config`). Change only these 4 values and update their inline comments:
| Key | Current | New | Why |
|---|---|---|---|
| `sweepPeriodSeconds` | 3.0 | **3.4** | Widens every window by 13% in *time* uniformly. Angle T1 becomes Perfect +/-170 ms / Good +/-340 ms, and tier and perk ratios are preserved. Worst-case wait for both taps is 6.8 s, still under `maxElapsedSeconds = 12`. |
| `maxDistanceRange` | 760 | **840** | Farthest real patch (722) now sits at dial 0.86, and its Good band tops out at 0.958 < 1.0, so the wrap-to-Poor case is gone. Nearest patch (139, dial 0.165) keeps its Good band above 0. |
| `distanceToleranceStuds.perfect` | 38 | **42** | Keeps distance Perfect = 42/840 x 3.4 = +/-170 ms, the same as angle. |
| `distanceToleranceStuds.good` | 75 | **83** | Keeps distance Good = 83/840 x 3.4 = +/-336 ms, the same as angle. |
- Do **not** change `DANCE_FLOOR_TIERS[*].goldenZoneDegrees` or `PERKS.clearSignal`. The time widening comes from the sweep, so upgrades keep the same relative value.
- No other code change is needed. `Formulas`, `DanceService` (grading plus the `DanceStarted` preview payload) and `DanceController`'s bands all read these Config keys, so client and server stay in sync automatically.

**D4 -- One thing moves at a time** (`DanceController`, visual only)
- **Phase 1 (waiting for tap 1),** in `onDanceStarted`: set `barFill.Visible = false`. The bar stays empty but its gold target bands stay visible, so the kid can already see where the second target is.
- **On tap 1,** in `registerTap`'s tap-1 branch:
  - Clone `needle` as `LockedNeedle` (parent `dial`, same Rotation it has right now, `BackgroundTransparency = 0.2`, ZIndex 6).
  - Set live `needle.Visible = false` and `barFill.Visible = true`.
  - The dial is now frozen at the kid's answer and only the bar moves.
- **Cleanup:**
  - In `showIdle()`: destroy `LockedNeedle`, and set `needle.Visible = true` and `barFill.Visible = true`.
  - In `onDanceStarted`: destroy any stale `LockedNeedle` before drawing markers.
- Keep `LockedNeedle` visible during the "Grading..." and result display.

**D5 -- Keep architecture.md from reverting this.** In architecture.md's DanceService section, replace "submitted <1.2s" with "<0.2s". Add one line: "Timing constants live in Config.DANCE (sweep 3.4s, range 840, tolerance 42/83 studs = +/-170/+/-336 ms); see architecture_kidfriendly_addendum.md". This stops a future agent from "restoring" the stale 2.4 s / 300 / 20 / 50 design numbers.

---

## QUESTION 2 -- Hex comb placement rules

### 2.1 What the live code actually does
| Fact | Live | Source |
|---|---|---|
| Floor 1 lattice | radius 2 disk = 19 cells; (0,0) is the permanent Dance Floor, so **18 buildable** | `Config.FLOOR_RADIUS[1] = 2`, verified 19 plates/plot |
| Royal rule | `HexGrid.IsRim` = `HexDistance == 2`, i.e. the outer ring | `CombService.CanBuild`, `RIM_ONLY_CELL_TYPES` |
| PropolisSeam rule | **the same** `IsRim` check. "Outer rim" and "outermost ring" are one rule, not two | same table |
| Rim share | **12 of 18** buildable cells are rim-legal | measured |
| Pollen "must touch Brood" | **Not a placement rule.** Pollen builds anywhere. With 0 Brood neighbours its output is x0.5 (`CELLS.Pollen.mustTouchBroodOrPenalty`); with 1+ it is x1.0 | `Formulas.AdjacencyBonus("Pollen", n)` |
| Illegal-tap cost | none. The server rejects before charging | `CanBuild` checks the rim before cost |
| Royal price | 2500 H + 60 P, so a mid-game purchase that few kids see early | `Formulas.CellCost` |
| Highlight, legal | Fill `(90,200,90)` @ 0.45, Outline Honey Gold @ 0 | `refreshPlateHighlights` |
| Highlight, illegal | Fill `(200,70,70)` @ 0.45, **Outline Honey Gold @ 0 (identical)** | same |
| Plate under highlight | BrickColor Gold (~239,184,56), SmoothPlastic, opaque | live plate |
| Illegal plate clickable? | **yes**. It fires `RequestBuildCell`, and the server replies "…can only be built on the outer rim of the lattice" | `onPlateClicked`, `CanBuild` |
| Pollen highlight | every free plate is green; the x0.5 penalty is invisible | `isLegalPlacement` returns true for non-rim types |
| Motion / icon / text cue | none, apart from a one-time description toast when a type is selected | -- |

### 2.2 Finding
**The rules are fine. The signal is weak.** Answer: **(b) stronger visual cues. Do not simplify the rules.**

Why the rules should stay:
- There is really only one hard rule ("Royal and Propolis go on the edge"). It is spatially trivial on a 19-hex flower shape: the outside ring is obvious at a glance. It covers two-thirds of the comb, so it rarely blocks anything, and a mistake costs nothing.
- The Pollen/Brood relationship is already a soft bonus, which is the right shape for kids: it can't be "wrong", only "less good".
- Simplifying further would remove the one spatial decision the comb has.

Why the signal is not enough on its own:
1. **Hue-only distinction.** Green or red at 45% over opaque gold blends to about `(157,193,75)` yellow-green vs about `(218,121,64)` orange. These two are close in brightness. For red-green colour-blind players (about 1 in 12 boys, a core part of this audience) they read as nearly the same tan.
2. **The strongest element carries no information.** `OutlineTransparency = 0` in Honey Gold on both legal and illegal plates, so the sharpest edge on screen says "all of these are selectable".
3. **Illegal plates behave like buttons.** A kid taps one, and a server round-trip returns a sentence containing "lattice". The kid learns "the game is broken", not "use the edge".
4. **Pollen's real rule is invisible.** Every plate is equally green, so the 50% penalty can only be learned by reading a toast.
5. **Nothing draws the eye.** Static tints at the same brightness do not pull a child's attention to the right place.

### 2.3 Recommendation (exact changes), all in `BuildController` unless noted

**B1 -- Three highlight states, told apart by brightness + outline + motion (not hue).** Add to the palette tokens:
```lua
local LEGAL_FILL   = Color3.fromRGB(150, 255, 170) -- bright mint, reads as "light" not just "green"
local LEGAL_LINE   = Color3.fromRGB(255, 255, 255)
local BLOCKED_FILL = Color3.fromRGB(35, 25, 20)    -- near-black brown: darkens the plate
```
In `refreshPlateHighlights`'s `elseif selectedCellType then` branch, replace the green/red lines with:

| State | When | FillColor | FillTransparency | OutlineColor | OutlineTransparency | Pulse |
|---|---|---|---|---|---|---|
| **BEST** | legal, and (type is not Pollen, or Pollen with >=1 adjacent built Brood) | `LEGAL_FILL` | tween 0.15 <-> 0.45 | `LEGAL_LINE` | 0 | **yes** |
| **OK** | legal Pollen with 0 adjacent Brood | `WAX_CREAM` | 0.6 | `HONEY_GOLD` | 0.5 | no |
| **BLOCKED** | `isLegalPlacement == false` | `BLOCKED_FILL` | 0.35 | `BLOCKED_FILL` | 1 (no outline) | no |

- **Pulse:** `TweenService:Create(highlight, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.45 })`, after first setting `FillTransparency = 0.15`. Keep the tween in a `pulseTweens: { [BasePart]: Tween }` table. In `clearPlateHighlights()`, call `:Cancel()` on each and clear the table (the existing Highlight `:Destroy()` stays).
- **Unchanged:** the "no type selected" state (Wax Cream 0.65) and Demolish Mode (Alarm Red).
- **Result:** legal cells glow, are outlined in white and breathe. Illegal cells go dark with no outline. This reads without colour vision and without text.

**B2 -- A BLOCKED tap never reaches the server; it teaches instead** (`onPlateClicked`, build branch, before `FireServer`):
```lua
if not isLegalPlacement(plate, selectedCellType) then
    local now = os.clock()
    if now - lastBlockedToast > 1.5 then
        lastBlockedToast = now
        NotifyController.ShowLocal("info", EDGE_ONLY_HINT[selectedCellType] or "Tap a glowing cell!")
    end
    return
end
```
```lua
local lastBlockedToast = 0
local EDGE_ONLY_HINT = {
    Royal = "Royal Cells only fit on the outside edge! Tap a glowing cell.",
    PropolisSeam = "Propolis Seams only fit on the outside edge! Tap a glowing cell.",
}
```

**B3 -- Pollen "best spot" detection** (new local function, used by B1):
```lua
local function touchesBuiltBrood(plate: BasePart): boolean
    local q, r = plate:GetAttribute("Q"), plate:GetAttribute("R")
    local plotIndex, floor = plate:GetAttribute("PlotIndex"), plate:GetAttribute("Floor")
    if typeof(q) ~= "number" or typeof(r) ~= "number" then return false end
    for _, n in HexGrid.Neighbours(q, r) do
        for _, cell in CollectionService:GetTagged("CombCell") do
            if cell:GetAttribute("PlotIndex") == plotIndex and cell:GetAttribute("Floor") == floor
                and cell:GetAttribute("Q") == n.q and cell:GetAttribute("R") == n.r
                and cell:GetAttribute("CellType") == "Brood" then
                return true
            end
        end
    end
    return false
end
```
- Only Pollen uses the BEST/OK split.
- Honey and Brood keep every free plate as BEST: their adjacency is a small pure bonus (+6% / +8%), and marking most plates "OK" would weaken the "glow = go" signal.
- Pollen stays buildable anywhere. **Do not** make it a hard rule.
- Cost is at most 18 plates x 6 neighbours x ~20 tagged cells, which is trivial and runs only when highlights refresh.

**B4 -- No free edge left:** in the palette button handler, when `selectedCellType` becomes Royal or PropolisSeam and no plate in `getOwnFloor1Plates()` passes `isLegalPlacement`, call `NotifyController.ShowLocal("info", "No free spots on the outside edge! Demolish an edge cell to make room.")` **instead of** the description toast.

**B5 -- Server string** (`CombService.CanBuild`, rim check; the logic is unchanged):
- Current: `cellType .. " can only be built on the outer rim of the lattice"`
- New: `(cellType == "PropolisSeam" and "Propolis Seams" or cellType .. " Cells") .. " only fit on the outside edge!"`
- After B2 this is only reachable by exploit or a race, but it must never say "lattice" to a child.

---

## Existing System Interactions
- **Tutorial (step 2 = first dance):** still advances on any grade. D1-D4 only make that first dance feel better.
- **Route beam / FirstWaggle moment / RetentionService dance quest:** unaffected. They are grade-agnostic.
- **clearSignal perk / DANCE_FLOOR_TIERS upgrades:** they still widen the angle zone by the same ratios. In ms: T5 Perfect goes from +/-383 to +/-434.
- **Dance security:** unchanged. The server still grades from its own secret `trueBearing/trueDistance`. The client still reports only 0..1 dial readings, clamped server-side.
- **Existing routes in save data:** store `quality` only, so no migration is needed.
- **Demolish Mode:** untouched (B1 edits only the `selectedCellType` branch).
- **Highlight instance cap (31 rendered per client):** still 18 max per player, and BuildController is the only script creating Highlights (verified by grep). Any future feature adding Highlights must stay within 13.

## Build Order
1. **Config.DANCE** (D3). One-file change that takes effect immediately on both sides.
2. **DanceController** D1, D2, D4.
3. **BuildController** B1, B3, B2, B4.
4. **CombService** B5 string.
5. **architecture.md** D5 note.
6. **Verify:**
   - Play-test one dance on the phone emulator and one on keyboard. Confirm the tap registers on touch-down.
   - Confirm AuroraBloom (dial ~0.86) can grade Good.
   - In Build Mode with Royal selected: 12 plates pulse white-outlined and 6 inner plates are dark with no outline. Tapping an inner plate shows the edge toast and fires no remote.
   - With Pollen selected: only plates touching a built Brood pulse.

## Risk Areas
- **Tween leak on rapid palette switching.** Mitigation: `clearPlateHighlights` cancels every tween in `pulseTweens` before destroying the highlights.
- **`GuiObject.InputBegan` on the TAP button when a touch starts on the button but the finger slides off.** Harmless: the tap is registered at touch-down, which is the intent.
- **Adults find Perfect easier.** Accepted. The target audience is 7-9, Perfect only adds +25% yield, and higher Dance Floor tiers are mainly bought for route slots.

## Mobile Considerations
- D1 is primarily a mobile fix. It removes the input-lag penalty that PC players never had.
- B1's brightness, outline and motion cues survive small screens, glare and colour blindness better than a hue tint.
- No new UI elements and no performance impact (one looping tween per legal plate, 18 max).

## Signature Moments
- **"I got a Perfect!"** A kid on a phone, on their second or third dance, lands both taps and sees "Perfect!" plus the golden line. Today that happens roughly 1 time in 10 for them; after this change, about 1 in 2.
- **"Glow means go."** The kid picks Royal Cell, and the outer ring lights up, breathing white, while the middle goes dark. The kid taps the ring without reading anything.

---

## DISPATCH SUMMARY
**Both mechanics need a change dispatched. Neither needs a rules or design change.**
- **Dance: YES.** A code + config change for luau-scripter:
  - DanceController: D1 touch-on-press, D2 double-tap guard, D4 one-thing-moves.
  - Config.DANCE: D3 = `sweepPeriodSeconds 3.4`, `maxDistanceRange 840`, `distanceToleranceStuds = { perfect = 42, good = 83 }`.
  - Priority **HIGH**: the mobile majority currently lands Good-or-better only about half the time.
- **Comb: YES, visual only, rules unchanged.** For luau-scripter:
  - BuildController B1-B4: three-state brightness/outline/pulse highlight, no remote on blocked taps, Pollen best-spot pulse, no-free-edge toast.
  - CombService B5: one error string.
  - Priority **MEDIUM**: mistakes are free and Royal is a mid-game purchase, but blocked taps currently look like bugs.
