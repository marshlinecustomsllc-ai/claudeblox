# A Bee's World: HUD Layout v2 (architect proposal)

Place 123313915411717. Studio instance af40365e-f70f-439a-b6ef-c779b9b793bf (confirmed). Read-only pass: no writes to Studio, no play mode.

Source of positions: Edit-mode values from StarterGui (MainGui, HiveGui, BuildGui, ShopGui, HelpGui, AdminGui, RetentionGui, TutorialGui, ThreatGui, NotifyGui) and the controller source for runtime GUIs. Controllers create their own ScreenGuis at runtime, so their positions are the code values, not Studio objects.

Pixel check uses scale x viewport. Fixed offsets (sparkline at -120 px, -8 px) are noted where they apply.

---

## 1. Inventory

| Element | Controller | Current position (anchor) / size (Scale) | Current screen zone | Always needed? |
|---|---|---|---|---|
| HudRoot (MainGui) | HudController | (0.985, 0.26) anchor (1,0); 0.235 x 0.42 | top-right, y 26% to 68% | Yes, but it is a container |
| WalletPanel (4 coin chips) | HudController | inside HudRoot, full width, top 0.375 of HudRoot | top-right | Yes (honey, propolis, pollen, jelly) |
| FlowPanel (HIVE FLOW) | HudController | inside HudRoot, y 0.405 of HudRoot, h 0.595 | top-right, under wallet | Partly. Useful when hive is active; can be a tap-to-open panel |
| RateRow BeeCountLabel | HudController | inside FlowPanel | top-right | Merge into FlowPanel |
| WeatherChip | HudController | (0.985, 0.02) anchor (1,0); 0.235 x 0.055 | top-right, under the bee/retention row | No |
| Bee-count bar (bottom strip) | not located by name in the controllers read | not found | bottom | Redundant with FlowPanel BeeCountLabel. Verify its owner in Studio before removing |
| QuestHudBadge | QuestHudBadge (DisplayOrder 18) | (0.012, 0.10); 0.23 x 0.085 | top-left | Yes, but as a progress row |
| StreakBadge | StreakBadgeController (DisplayOrder 18) | (0.012, 0.015); 0.20 x 0.075 | top-left | Yes, as a progress row |
| RoutePill | RouteLimitController (DisplayOrder 18) | (0.012, 0.195); 0.17 x 0.04 | top-left | Yes, as a progress row (hidden when slots = 0) |
| SeasonLabel (SeasonGui) | SeasonController (DisplayOrder 12) | (0.012, 0.245); 0.13 x 0.035; forced visible by the controller | top-left | No. Move into "What's happening" |
| CensusCard (CensusGui) | CensusController (DisplayOrder 9) | (0.985, 0.185) anchor (1,0); 0.30 x 0.06 | top-right, under HudRoot | No. Owner-facing stat |
| SettingsGear (SettingsGui) | SettingsController (DisplayOrder 12) | (0.985, 0.70) anchor (1,0); 0.07 x 0.11 | right edge, mid-lower | Needed, but small |
| AdminToggle (AdminGui) | AdminController | (0.012, 0.52); 0.07 x 0.07; Visible=false for non-owners | left, overlaps HIVE | Owner only |
| RetentionButton (RetentionGui) | RetentionController | (0.985, 0.015) anchor (1,0); 0.09 x 0.09 | top-right corner, overlaps WeatherChip | Yes, but can be a row item |
| RetentionCard | RetentionController | centre, 0.46 x 0.86, hidden until opened | modal | Yes, only when open |
| ShopButton (ShopGui) | ShopController | (0.012, 0.733); 0.20 x 0.10 | left column | Yes |
| HiveButton (HiveGui) | HiveController | (0.012, 0.496); 0.20 x 0.10 | left | Yes |
| HelpButton (HelpGui) | HelpController | (0.12, 0.496); 0.20 x 0.10 | left, sits beside HIVE and overlaps it | Yes, but can be a small corner button |
| BuildButton (BuildGui) | BuildController | (0.012, 0.97); 0.20 x 0.10 | bottom-left, extends past the bottom edge (0.97 + 0.10 = 1.07) | Yes |
| BuildGui.Panel / DanceGui.Panel | BuildController / DanceController | bottom-centre anchored | bottom-centre | Yes, when in mode. Do not move |
| TutorialCard (TutorialGui) | TutorialController | (0.988, 0.975) anchor (1,1); 0.27 x 0.16; hidden until used | bottom-right | Yes during tutorial only. Do not move |
| DailyTipCard | DailyTipController (DisplayOrder 15) | (0.5, 0.94) anchor (0.5,1); 0.80 x 0.07 | bottom-centre, overlaps BUILD | No. Show once, then move to Help |
| WaspPingPill | WaspPingController (DisplayOrder 12) | (0.5, 0.10); 0.42 x 0.06 | top-centre, overlaps ThreatGui banners | Merge into banner stack |
| ThreatGui BannerStack | ThreatController | (0.5, 0.02) anchor (0.5,0); 0.46 x 0.34 | top-centre | Yes (threat notifications) |
| ThreatGui SittingCard | ThreatController | centre, hidden until used | modal | Yes, when active |
| NotifyGui ToastContainer | NotifyController | (0.5, 0.03) anchor (0.5,0); 0.74 x 1.0 | top-centre, spans full height | Yes, notifications |
| PopulationSparkline | BeePopulationSparklineController (DisplayOrder 9) | anchor (1,1), offset (-8 px, -120 px); 0.22 x 0.09 | bottom-right, above the gear | No. Move into FlowPanel as a footer |
| HelpPanel | HelpController | modal, opened from HelpButton | modal | Yes, becomes the home for hidden items |

---

## 2. Grouping rule: one zone per job

| Zone | Job | Contents |
|---|---|---|
| Top-left | Progress | ONE stacked card: quest, streak, route pill |
| Top-right | Account | ONE column: retention button and weather icon in one row, wallet, census |
| Bottom-left | Actions | ONE column: HIVE, SHOP, BUILD |
| Bottom-right | Status | HIVE FLOW panel with sparkline footer, and a small corner pair: help (?) and settings (gear) |
| Top-centre | Notifications only | toasts, threat banner (wasp ping merged in) |
| Tutorial | Path-bound | TutorialCard stays bottom-right (fixed) |
| Modal | Build mode | BuildGui.Panel and DanceGui.Panel stay bottom-centre (fixed) |

---

## 3. Concrete proposals (Scale only)

### Top-left: progress card (one card)
- `ProgressCard`: position (0.012, 0.02), size (0.22, 0.22). Contains three rows: quest, streak, route.
- Quest row (0.04 to 0.96 wide): size (0.92, 0.09) inside card, position y 0.04.
- Streak row: y 0.37, size (0.92, 0.09).
- Route row: y 0.70, size (0.92, 0.09). Hidden when slots = 0.
- Merge: QuestHudBadge, StreakBadge, RouteLimit pill become children of one card (controllers reparent their frames, or the card is a wrapper frame).
- Hide: SeasonLabel is removed from here (see "What's happening").

### Top-right: account column
- Row 1 `RetentionButton` (0.75 to 0.90 wide, height 0.06) at (0.90, 0.02) anchor (1,0), size (0.15, 0.06).
- `WeatherIcon` (weather chip shrinks to an icon) at (0.985, 0.02) anchor (1,0), size (0.07, 0.06). Tapping opens "What's happening".
- `WalletPanel`: (0.985, 0.09) anchor (1,0), size (0.235, 0.14). Four coins in one 2x2 or single row.
- `CensusCard`: (0.985, 0.24) anchor (1,0), size (0.235, 0.06).
- `HudRoot` keeps this column as its container. Its position moves to y 0.02 and size shrinks to 0.235 x 0.28.

### Bottom-left: actions column
- `HiveButton`: (0.012, 0.58), size (0.16, 0.10).
- `ShopButton`: (0.012, 0.70), size (0.16, 0.10).
- `BuildButton`: (0.012, 0.82), size (0.16, 0.10). Ends at 0.92, so the button stays on screen.
- Help is removed from this column (moved to bottom-right corner).
- `AdminToggle` (owner only): (0.012, 0.25) anchor (0,0), size (0.06, 0.08). Sits under the progress card. Hidden by default for non-owners, as now.

### Bottom-right: status and corner
- `FlowPanel` (HIVE FLOW + BeeCountLabel + sparkline footer): (0.985, 0.58) anchor (1,0), size (0.385, 0.26). Ends at 0.84.
- Sparkline becomes the FlowPanel footer: size (0.36, 0.06) inside the panel. The -120 px offset is removed.
- Corner pair, bottom-right: `HelpButton` at (0.905, 0.88), size (0.04, 0.08); `SettingsGear` at (0.985, 0.88) anchor (1,0), size (0.07, 0.08). Both sit at 0.88 to 0.96.
- `TutorialCard` unchanged (0.988, 0.975) anchor (1,1). While visible, the FlowPanel and corner pair hide (see Risks).

### Top-centre: notifications only
- `ToastContainer`: (0.5, 0.03) anchor (0.5,0), size (0.50, 0.15). Width reduced from 0.74 to 0.50 so it clears the top-left and top-right columns.
- `ThreatBannerStack`: (0.5, 0.02) anchor (0.5,0), size (0.46, 0.16). WaspPingPill is rendered as the first banner row (no separate pill).

### Moved into the Help panel (hidden by default)
- Daily tip: shown once per session as a toast on first load, then lives under Help > "Tips".
- Season and weather: a single "What's happening" section in Help, opened from the weather icon.
- Admin toggle stays owner-only, but may also be exposed as a Help > "Admin" row for owners (see Owner decisions).
- Bee-count bar: removed from the always-on screen; the number is in FlowPanel.

### Removed from the always-on screen
- Tip card, season label, weather chip text, wasp ping pill as a separate pill, standalone sparkline, standalone bee-count bar, standalone HELP beside HIVE.

---

## 4. Phone-size check

Positions are Scale, so each zone is `scale x viewport`. The table gives y in pixels for both sizes. Note: `UISizeConstraint` and `UIAspectRatioConstraint` on buttons may clamp the real size; verify in Play.

Viewport 812 x 375 (landscape phone):

| Zone | x range (px) | y range (px) | Overlap check |
|---|---|---|---|
| Progress card | 10 to 179 | 8 to 83 | Clear of toast (x 203 to 609) |
| Admin toggle | 10 to 49 | 94 to 124 | Clear of progress (y 83) and Hive (y 217) |
| Retention button | 609 to 730 | 8 to 30 | Clear of toast (x up to 609) |
| Weather icon | 730 to 787 | 8 to 30 | Clear |
| Wallet | 609 to 800 | 34 to 86 | Clear |
| Census | 609 to 800 | 90 to 113 | Clear |
| Toast container | 203 to 609 | 11 to 67 | Clear of progress (x up to 179) and right column (x from 609) |
| Banner stack | 219 to 593 | 8 to 68 | Clear of toast only in the sense that the same zone is shared; banners and toasts stack in one column |
| Hive | 10 to 140 | 217 to 254 | Clear of admin (y up to 124) |
| Shop | 10 to 140 | 262 to 300 | Clear |
| Build | 10 to 140 | 307 to 345 | Clear; bottom at 345 leaves 30 px |
| FlowPanel | 487 to 800 | 217 to 314 | Clear of right column (y up to 113) |
| Help | 735 to 772 | 330 to 360 | Clear |
| Gear | 730 to 800 | 330 to 364 | Clear of help (x 735 to 772 overlaps only in x, y separate by 0 px: help ends 360, gear starts 330). Overlap: help and gear share the row, so place help at x 0.85 to 0.90 to avoid overlap |

Viewport 568 x 320 (small phone):

| Zone | x range (px) | y range (px) | Overlap check |
|---|---|---|---|
| Progress card | 7 to 125 | 6 to 70 | Clear |
| Admin toggle | 7 to 34 | 80 to 106 | Clear |
| Retention button | 423 to 511 | 6 to 19 | Clear |
| Weather icon | 511 to 551 | 6 to 19 | Clear |
| Wallet | 426 to 557 | 29 to 74 | Clear |
| Census | 426 to 557 | 77 to 96 | Clear |
| Toast container | 142 to 426 | 10 to 48 | Clear |
| Banner stack | 142 to 426 | 6 to 51 | Shares zone with toasts (intended) |
| Hive | 7 to 98 | 186 to 218 | Clear |
| Shop | 7 to 98 | 224 to 256 | Clear |
| Build | 7 to 98 | 262 to 294 | Clear |
| FlowPanel | 341 to 560 | 186 to 269 | Clear of right column (y up to 96) |
| Help | 483 to 511 | 282 to 307 | Clear. Note: 25 px high; below 44 px touch target |
| Gear | 511 to 560 | 282 to 307 | Clear. Note: 25 px high; below 44 px touch target |

Touch-target flag: at 320 px height, a 0.10 Scale button is 32 px tall, under the 44 px minimum. Fix: add a `UISizeConstraint` with MinSize (0, 44) on Hive, Shop, Build, Help, and Gear.

Result: no overlaps at either size once the changes above are applied. Current layout overlaps (fixed by this plan): HIVE and HELP share x 0.12 to 0.21 at the same y; ADMIN at y 0.52 sits inside HIVE (y 0.496 to 0.596); WEATHER and RETENTION share the top-right corner; the DAILY TIP card (x 0.1 to 0.9) overlaps BUILD; WASP PING overlaps the threat banner stack; BUILD extends past the bottom edge.

---

## 5. Risks, build order, Play check list

### Risks
- Controllers that must change:
  - HudController: HudRoot position and size, WalletPanel and FlowPanel placement, WeatherChip becomes an icon. The HudRoot Y nudge for touch laptops (`hudRootOriginalPosition`) must be re-based on the new y.
  - QuestHudBadge, StreakBadgeController, RouteLimitController: change from ScreenGui-level position to rows inside `ProgressCard`. Their DisplayOrder stays 18.
  - SeasonController: its forced-visible logic (it sets gui.Enabled and every ancestor's Visible) must target the Help panel row, not a top-left label.
  - DailyTipController: show once as a toast, then store the tip in Help. Requires NotifyController.
  - WaspPingController: route through ThreatController banner stack, or keep and move to banner row 0.
  - BeePopulationSparklineController: move from its own ScreenGui into FlowPanel; remove the -120 px offset.
  - SettingsController and HelpController: add the corner pair (help and gear). HelpController gets the new sections (What's happening, Tips, Admin row if approved).
  - NotifyController: toast container width 0.50.
  - AdminController: toggle position only; owner gating unchanged.
  - RetentionController: button moves to the account row; card unchanged.
  - BuildController: BuildButton position to y 0.82 (bottom-left column). Build mode panel unchanged.
- Must not move:
  - TutorialCard (path-bound; bottom-right anchor). Instead, hide FlowPanel and corner pair while the tutorial is visible.
  - BuildGui.Panel and DanceGui.Panel (bottom-centre anchored, BUILD mode UI).
  - ThreatGui SittingCard (modal).
  - Any path-bound elements listed in the tutorial script (Hive, Build, Shop buttons keep their names for tutorial targeting).
- Unknown: the bottom bee-count bar's owner was not located by name. Find it in Studio (search for "bee" text labels under ScreenGuis created at runtime) before removing.

### Numbered build order
1. Verify the unknown: locate the bottom bee-count bar and its controller (read only).
2. Add the touch-target `UISizeConstraint` (MinSize 44 px) to Hive, Shop, Build, Help, Gear. Test first; no layout change yet.
3. Move the BUILD button to y 0.82 and HIVE to 0.58, SHOP to 0.70. Remove the HELP button from the left column.
4. Create the `ProgressCard` wrapper and reparent quest, streak, route into it. Remove the season label from the top-left.
5. Rebuild the top-right account column: retention row, weather icon, wallet, census. Re-base the HudRoot touch nudge.
6. Move FlowPanel to bottom-right (y 0.58) and embed the sparkline as footer. Remove the -120 px offset.
7. Add the corner pair (help and gear) bottom-right. Move the settings gear there.
8. Narrow the toast container to 0.50 width; fold WaspPingPill into the banner stack.
9. Move the tip card to a once-per-session toast and a Help section. Remove the bottom tip card.
10. Hide FlowPanel and corner pair while TutorialCard is visible.

### Play check list (Studio, F5, then 812x375 and 568x320 emulation)
- [ ] No two elements overlap at 812x375 or 568x320 (screenshot each).
- [ ] Progress card shows quest, streak, route; route row hides when slots = 0.
- [ ] Retention, weather icon, wallet, census stack in the top-right without overlap.
- [ ] HIVE, SHOP, BUILD in the bottom-left; BUILD fully on screen.
- [ ] FlowPanel with sparkline footer in the bottom-right; corner pair visible.
- [ ] Toasts and threat banners in top-centre; no toast covers the progress card or account column.
- [ ] Tutorial card appears bottom-right on first join; FlowPanel and corner pair hide during it.
- [ ] Enter BUILD mode: build panel and palette are unchanged and bottom-centre.
- [ ] Admin toggle hidden for a non-owner, visible for the owner, and does not overlap HIVE.
- [ ] Help panel opens, shows the What's happening section and tips.
- [ ] Touch targets are at least 44 px on the 568x320 emulation.

---

## 6. Owner decisions (recommended default in bold)

1. **Daily tip: show once as a toast on the first session, then only in Help.** Alternative: keep it as a dismissible bottom card. Default: once, then Help.
2. **Season and weather: one "What's happening" card in Help, opened from the weather icon.** Alternative: keep the season label on screen. Default: Help.
3. **Sparkline: inside FlowPanel as a footer.** Alternative: keep a separate bottom-right chart. Default: footer.
4. **Bee-count bar: remove. The count lives in FlowPanel.** Alternative: keep the bottom strip. Default: remove, after confirming its owner.
5. **Help button: bottom-right corner, beside the gear.** Alternative: keep beside HIVE. Default: corner.
6. **Admin toggle: stays owner-only, under the progress card at (0.012, 0.25).** Alternative: move into Help as an owner-only row. Default: keep the toggle, smaller.
7. **Wasp ping: merged into the threat banner stack.** Alternative: keep a separate pill. Default: merge.
8. **Tutorial: hides FlowPanel and corner pair while active.** Alternative: keep everything visible. Default: hide.

READY FOR REVIEW
