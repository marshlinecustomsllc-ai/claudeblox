# CYCLE 4 — QueenService Build Dispatch

## PREREQUISITE
Bug #9 (duplicate DataService) must be resolved BEFORE any DataService edit in this cycle.
Run `fix_bug9_duplicate_dataservice.lua` in Studio Command Bar and confirm "PASS: count == 1".

---

## OVERVIEW

Signature Moment 4: The Queen Walks. Full implementation of QueenService server module,
Royal Jelly production income, QueenController client renderer, Queen model templates, and
HiveGui QUEEN tab replacement.

**Architecture spec:** All detail in `/project/gamemaster/architecture_queen_addendum.md`
This dispatch extracts the build order and key contracts. When in doubt, the addendum wins.

---

## LUAU-SCRIPTER TASK

### Prompt for luau-scripter:

```
Implement the full QueenService feature for "A Bee's World". All architectural decisions,
exact code, verification checklists and edge case handling are specified in the architecture
addendum. Read that document first, then execute.

=== ARCHITECTURE ADDENDUM ===
[INSERT FULL TEXT OF architecture_queen_addendum.md HERE]
=== END ===

Build in this exact order. Work in EDIT MODE only (RunService:IsRunning() == false).
Read each script BEFORE editing it -- never rely on cached version.

---

### STEP 1: Config + DataService migration (addendum §3.1 and §3.2)

**Config (ReplicatedStorage.Modules.Config):**
Read the current Config source first, then apply these changes:

1a. Add `genGate = 1` to QUEEN_TIERS[5] (the Sun Queen row). Leave all other values untouched.

1b. After QUEEN_TIERS, add the full Config.QUEEN block (addendum §3.1(b)) -- the complete
    block is in the addendum with exact values.

1c. In PROFILE_TEMPLATE: bump version from 3 to 4, add `royalJellyProgress = 0` field next
    to royalJelly. Add doc comment per addendum §3.1(c).

IMPORTANT: After editing Config, use the clone-and-replace technique to bust require() cache:
  - Clone the Config ModuleScript
  - Replace the original with the clone
  - Destroy the ORIGINAL (the one you cloned from)
  - Verify only 1 Config exists after

**DataService (ServerScriptService.Systems.DataService):**
Read source first. Add MIGRATIONS[3] (addendum §3.2) directly after MIGRATIONS[2].
It must set version = 4, add royalJellyProgress field, and normalize queenTier.

Verify: run this Lua to confirm:
```lua
local ds = game:GetService("ServerScriptService").Systems:FindFirstChild("DataService")
local count = 0
for _, c in game:GetService("ServerScriptService").Systems:GetChildren() do
    if c.Name == "DataService" then count += 1 end
end
print("DataService count: " .. count .. " (must be 1)")
print("Has MIGRATIONS[3]: " .. tostring(ds.Source:find("MIGRATIONS%[3%]") ~= nil))
print("Has royalJellyProgress: " .. tostring(ds.Source:find("royalJellyProgress") ~= nil))
print("Version 4: " .. tostring(ds.Source:find("version = 4") ~= nil))
```

---

### STEP 2: ResourceService Royal Jelly production (addendum §4.2)

Read ResourceService source first.

Add `local HexGrid = require(Modules:WaitForChild("HexGrid"))` to the requires block.

Add the `computeRoyalJellyPerSecond(profile)` function (full code in addendum §4.2).
Expose it: `ResourceService._computeRoyalJellyPerSecond = computeRoyalJellyPerSecond`

In `_tickPlayer`, add step 4b (Royal Jelly accumulator) AFTER PopulationService.HatchTick
and BEFORE public stats. Full code in addendum §4.2, step 3.

Add the three new fields to RatesUpdate payload: `royalJellyPerMin`, `royalJellyProgress`,
`generation`. Full code in addendum §4.2, step 4.

Update the header comment to remove Royal Jelly from "out of scope".

Verify:
```lua
local rs = game:GetService("ServerScriptService").Systems:FindFirstChild("ResourceService")
print("Has computeRoyalJellyPerSecond: " .. tostring(rs.Source:find("computeRoyalJellyPerSecond") ~= nil))
print("Has step 4b: " .. tostring(rs.Source:find("4b. Royal Jelly") ~= nil))
print("Has royalJellyPerMin in RatesUpdate: " .. tostring(rs.Source:find("royalJellyPerMin") ~= nil))
```

---

### STEP 3: QueenService (NEW) + Main wiring (addendum §4.3 and §4.4)

Create ServerScriptService.Systems.QueenService as a new ModuleScript.

It must have --!strict at the top. Full API spec in addendum §4.3:
- GetTier(profile) -> number
- HasUnlock(profile, flag) -> boolean (cumulative: tier N carries all unlocks from tiers 1..N)
- GetNextTier(profile) -> (number?, any?)
- CanUpgrade(player) -> (boolean, string?, number?) -- 4 checks in exact order per addendum
- Upgrade(player) -> (boolean, string?) -- re-validates, deducts RJ, updates tier, fires Moment
- Init() -- creates RequestQueenUpgrade remote, connects handler, runs Config consistency check

CRITICAL: QueenService must NOT require ResourceService, PopulationService, or CombService.
It requires Config, DataService, PlotService, Validator only.

The RequestQueenUpgrade handler ignores the payload entirely -- tier/cost/gates come from
server state only (addendum §4.3 remote handler code).

CanUpgrade checks in order (per addendum): (1) profile loaded, (2) tier < 5,
(3) genGate met, (4) royalJelly >= cost. Return reason strings per addendum table.

Upgrade fires: (1) Notify "purchase" toast to owner, (2) Notify "info" if unlocksNurse,
(3) Moment "QueenGrowth" to FireAllClients (public spectacle), (4) async DataService.Save.

Main (ServerScriptService.Main):
Read source. Add QueenService require between ResourceService and StructureService.
Add QueenService.Init() after ResourceService.Init(). Update the doc comment.

Verify:
```lua
local qs = game:GetService("ServerScriptService").Systems:FindFirstChild("QueenService")
print("QueenService exists: " .. tostring(qs ~= nil))
if qs then
    print("Has --!strict: " .. tostring(qs.Source:find("--!strict") ~= nil))
    print("Has HasUnlock: " .. tostring(qs.Source:find("HasUnlock") ~= nil))
    print("Has CanUpgrade: " .. tostring(qs.Source:find("CanUpgrade") ~= nil))
    print("Has genGate check: " .. tostring(qs.Source:find("genGate") ~= nil))
end
local main = game:GetService("ServerScriptService"):FindFirstChild("Main")
print("Main has QueenService.Init: " .. tostring(main and main.Source:find("QueenService.Init") ~= nil))
```

---

### STEP 4: QueenController (NEW) + ClientMain wiring (addendum §6)

Create StarterPlayer.StarterPlayerScripts.Controllers.QueenController as a ModuleScript
(NOT a LocalScript -- see the PlotIndicatorController incident in the addendum).

--!strict. Returns `QueenController` at the end.

Requires: Config, HexGrid (ReplicatedStorage.Modules), BuildController (sibling), TweenService,
CollectionService, RunService, Players, Workspace.

Init() must not yield. Do WaitForChild work inside task.spawn, as HiveController does.

Key contracts from addendum §6:
- latticeOrigin(plotRoot) = Vector3.new(plotRoot.Position.X, 0, plotRoot.Position.Z + Config.QUEEN.latticeZOffset)
- cellPivot(plotRoot, q, r) = HexGrid.ToWorld(q, r, latticeOrigin(plotRoot), Config.FLOOR_Y[walkFloor] + Config.QUEEN.walkHeightAboveFloorY)
- Use CollectionService PlotRoot tag + attribute change signals (streaming-resilient pattern)
- Use CollectionService CombCell tag for brood walk nodes
- LOD: render only if OwnerUserId ~= 0 AND (own plot OR within Config.QUEEN.renderRadiusStuds)
- ONE RunService.Heartbeat connection, connects on first queen rendered, disconnects when none
- Three walk states: Walking → Laying (with layDip) → Walking; Growing (frozen during upgrade)
- Attendants (T4/T5): orbit formula per addendum §6.4 using clock * attendantOrbitRadPerSec
- All queen parts: CanCollide=false, CanQuery=false, CanTouch=false, Massless=true
- Parent clones to Workspace.ClientFX.Queens (create if missing)
- Amber footprint discs: pool under Workspace.ClientFX.QueenFX, Shape=Cylinder flat, Neon #F2A81C, tween Transparency 0.45 → 1 over cellFlashSeconds
- QueenGrowth moment: dim lights, scale-grow new template over new/old bodyLength ratio, emit GrowthBurst, restore lights; owner camera per addendum §6.6; cancel path restores lights immediately

ClientMain (StarterPlayer.StarterPlayerScripts.ClientMain):
Read source. Append QueenController require and Init() after the last existing controller.

Verify:
```lua
local qc = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
    and game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Controllers")
    and game:GetService("StarterPlayer").StarterPlayerScripts.Controllers:FindFirstChild("QueenController")
print("QueenController exists: " .. tostring(qc ~= nil and qc.ClassName == "ModuleScript"))
if qc then
    print("Has --!strict: " .. tostring(qc.Source:find("--!strict") ~= nil))
    print("Has latticeOrigin: " .. tostring(qc.Source:find("latticeOrigin") ~= nil))
    print("Has QueenGrowth: " .. tostring(qc.Source:find("QueenGrowth") ~= nil))
    print("Has GrowthBurst:Emit: " .. tostring(qc.Source:find("GrowthBurst:Emit") ~= nil))
end
```

---

### STEP 5: HiveGui QUEEN tab + HiveController (addendum §8)

HiveGui.Panel.Pages.QueenPage.Card -- work in Edit mode:
- Keep: Card, UICorner, UIStroke, UIGradient, Header TextLabel
- Delete: Body TextLabel
- Add all elements from addendum §8.1 hierarchy tree (PortraitFrame, InfoFrame, JellyFrame,
  HintLabel, UpgradeButton, all sub-elements with exact sizes and positions)
- All sizes: Scale only, zero Offset
- All text elements: FredokaOne, TextScaled=true, TextWrapped=true, UITextSizeConstraint min=14 max=28

Add discovery badges:
- HiveGui.HiveButton.QueenBadge (addendum §8.1 spec) -- Visible=false initially
- HiveGui.Panel.Tabs.QueenTab.QueenTabBadge (same spec, smaller) -- Visible=false initially

HiveController (StarterPlayer.StarterPlayerScripts.Controllers.HiveController):
Read source FIRST. Make exactly these surgical changes (addendum §8.4):
1. Update doc comment (QUEEN tab description)
2. Add new module state variables (royalJelly, royalJellyPerMin, generation, queenPending, etc.)
3. onRatesUpdate: also read royalJellyPerMin, generation; check pending tier
4. Add onWalletUpdate, onMoment (for QueenGrowth), updated onNotify
5. renderQueen() per addendum §8.2 state tables (replaces the "coming soon" block)
6. submitQueenUpgrade() with guard conditions + 3.5s timeout
7. Update Init(): resolve new element refs, connect button, WaitForChild for RequestQueenUpgrade/WalletUpdate/Moment

CAUTION: Do not change any Castes tab logic. Only add new state and new functions.
         If any QueenPage element is missing, warn() and disable queen section only -- castes must keep working.

Verify:
```lua
local hc = game:GetService("StarterPlayer").StarterPlayerScripts.Controllers:FindFirstChild("HiveController")
print("Has renderQueen: " .. tostring(hc.Source:find("renderQueen") ~= nil))
print("Has submitQueenUpgrade: " .. tostring(hc.Source:find("submitQueenUpgrade") ~= nil))
print("Has QueenGrowth moment: " .. tostring(hc.Source:find("QueenGrowth") ~= nil))
print("No 'coming soon' body: " .. tostring(hc.Source:find("Queen upgrades are not in the game yet") == nil))

local card = game:GetService("StarterGui").HiveGui.Panel.Pages.QueenPage.Card
print("QueenPage.Card.UpgradeButton exists: " .. tostring(card:FindFirstChild("UpgradeButton") ~= nil))
print("No Body TextLabel: " .. tostring(card:FindFirstChild("Body") == nil))
print("JellyFill exists: " .. tostring(card:FindFirstChild("JellyFrame", true) ~= nil))
```

---

### STEP 6: Text fixes (addendum §9)

BuildController (StarterPlayer.StarterPlayerScripts.Controllers.BuildController):
Read source. Find CELL_DESCRIPTIONS.Royal and replace its string with the one in addendum §9.1.
Update the doc comment above CELL_DESCRIPTIONS.

HelpGui Section7 Body:
StarterGui.HelpGui.HelpPanel.ContentScroll.Section7.Body -- set Text to string in addendum §9.2.

Verify:
```lua
local sg = game:GetService("StarterGui")
local s7 = sg.HelpGui.HelpPanel.ContentScroll:FindFirstChild("Section7")
local body = s7 and s7:FindFirstChild("Body")
print("HelpGui Section7 updated: " .. tostring(body and body.Text:find("Royal cells") ~= nil))
local bc = game:GetService("StarterPlayer").StarterPlayerScripts.Controllers:FindFirstChild("BuildController")
print("BuildController Royal text updated: " .. tostring(bc and bc.Source:find("Royal Jelly for every Brood Cell") ~= nil))
```

---

### FINAL VERIFICATION

Run this full check after all steps:

```lua
local results = {}
local SS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer").StarterPlayerScripts
local SG = game:GetService("StarterGui")

-- Config
local ok, cfg = pcall(require, RS.Modules.Config)
if ok then
    results[#results+1] = "Config.QUEEN exists: " .. tostring(cfg.QUEEN ~= nil)
    results[#results+1] = "QUEEN_TIERS[5].genGate == 1: " .. tostring((cfg.QUEEN_TIERS[5] or {}).genGate == 1)
    results[#results+1] = "PROFILE_TEMPLATE.version == 4: " .. tostring((cfg.PROFILE_TEMPLATE or {}).version == 4)
end

-- DataService count
local dsCount = 0
for _, c in SS.Systems:GetChildren() do if c.Name == "DataService" then dsCount += 1 end end
results[#results+1] = "DataService count == 1: " .. tostring(dsCount == 1)

-- Scripts
local qs = SS.Systems:FindFirstChild("QueenService")
results[#results+1] = "QueenService exists: " .. tostring(qs ~= nil)
local qc = SP.Controllers:FindFirstChild("QueenController")
results[#results+1] = "QueenController exists (ModuleScript): " .. tostring(qc ~= nil and qc.ClassName == "ModuleScript")

-- Templates
local queens = RS.Templates:FindFirstChild("Queens")
local qCount = 0
if queens then for _, q in queens:GetChildren() do if q:IsA("Model") then qCount += 1 end end end
results[#results+1] = "Queen templates: " .. qCount .. " / 5"

-- QueenPage
local card = SG.HiveGui.Panel.Pages.QueenPage.Card
results[#results+1] = "UpgradeButton exists: " .. tostring(card:FindFirstChild("UpgradeButton") ~= nil)
results[#results+1] = "QueenBadge on HiveButton: " .. tostring(SG.HiveGui.HiveButton:FindFirstChild("QueenBadge") ~= nil)

print(table.concat(results, "\n"))
```

All lines should show "true" or match expected values.
```

---

## WORLD-BUILDER TASK (parallel with luau-scripter steps 2-3)

### Prompt for world-builder:

```
Build the 5 Queen model templates for "A Bee's World". These live in ReplicatedStorage only
and cost ZERO server parts. Full spec is in architecture_queen_addendum.md §7.

=== ARCHITECTURE ADDENDUM §7 (TEMPLATES) ===
[INSERT THE QUEEN TEMPLATES SECTION FROM architecture_queen_addendum.md §7 HERE]
=== END ===

Create: ReplicatedStorage.Templates.Queens (Folder) containing Queen_T1 through Queen_T5.

Rules for every template:
- PrimaryPart = QueenRoot (1×1×1 Part, Transparency=1)
- Head points toward -Z of root
- All BaseParts: Anchored=true, CanCollide=false, CanQuery=false, CanTouch=false, Massless=true
- Wings: also CastShadow=false
- No scripts inside templates
- QueenRoot contains GrowthBurst ParticleEmitter (Enabled=false, Rate=0, Color #F2A81C→#FFE9A8)
- T4 and T5: Thorax contains QueenLight (PointLight, shadows=false)
- T4 and T5: AttendantA and AttendantB sub-Models (each with Body ball + Wings)
- T5: Halo (Cylinder, axis along Z, Neon #FCEFC6)

Part palette:
- Head/Thorax: SmoothPlastic #7A4A22
- Abdomen T1/T3: SmoothPlastic #E8D49A (wax cream)
- Abdomen T2: SmoothPlastic #F2A81C (honey gold)
- Abdomen T4/T5: Glass #F2A81C, Transparency=0.15
- Wings: Glass #FCEFC6, Transparency=0.45
- Halo: Neon #FCEFC6, Transparency=0.5

bodyLength contract (nose-to-tail, must be within +/-0.3 studs):
- T1: 5.0, T2: 5.5, T3: 6.0, T4: 9.0, T5: 12.5

Part lists and exact offsets per tier (relative to QueenRoot pivot):
[Use addendum §7 part tables -- Queen_T1 through Queen_T5]

Verify after building:
```lua
local queens = game:GetService("ReplicatedStorage").Templates:FindFirstChild("Queens")
if not queens then print("FAIL: Queens folder missing") return end
local tiers = {"Queen_T1","Queen_T2","Queen_T3","Queen_T4","Queen_T5"}
local expected = {6, 7, 8, 12, 13}
for i, name in tiers do
    local q = queens:FindFirstChild(name)
    if not q then print("FAIL: " .. name .. " missing") continue end
    local parts = 0
    for _, p in q:GetDescendants() do if p:IsA("BasePart") then parts += 1 end end
    local burst = q.QueenRoot:FindFirstChild("GrowthBurst")
    local hasPrimary = q.PrimaryPart ~= nil and q.PrimaryPart.Name == "QueenRoot"
    print(name .. ": " .. parts .. " parts (expect " .. expected[i] .. "), PrimaryPart=" .. tostring(hasPrimary) .. ", GrowthBurst=" .. tostring(burst ~= nil))
    if burst then print("  GrowthBurst: Enabled=" .. tostring(burst.Enabled) .. " Rate=" .. tostring(burst.Rate)) end
end
```

Expected: 6, 7, 8, 12, 13 parts. PrimaryPart=true for all. GrowthBurst Enabled=false, Rate=0.
```

---

## UI-DESIGNER TASK (after luau-reviewer passes)

### Prompt for ui-designer:

```
Polish the HiveGui QUEEN tab for "A Bee's World" after code review passes.
The tab is already fully functional -- modify ONLY visual properties.

=== STYLE GUIDELINES (from architecture_queen_addendum.md §8.5) ===
- House style: Warm Wax (same as existing HiveGui)
  Cream Card, Propolis Brown text/strokes, FredokaOne font
  Buttons: thick UIStroke outlines + UIScale bounce on press (UIAnimations pattern)
  NEVER change BackgroundColor3 -- HiveController owns button colors

- Fix contrast bug: Header "YOUR QUEEN" currently uses Honey Gold #F2A81C on cream card.
  That's ~1.5:1 contrast. Fix by making it Propolis Brown, OR add thick Propolis UIStroke.

- PortraitFrame should feel like "her chamber": Pollen Haze fill + warm inner glow gradient.

- Overall tone: regal, not a settings menu. This is the only page about a character.

- Optional: ViewportFrame turntable (ui-designer may add a slow-rotation NumberValue Tween in UIAnimations LocalScript -- NOT a per-frame loop)
=== END STYLE GUIDELINES ===

Discover the current QUEEN tab state through MCP first, then apply polish.
Verify all text is readable (no invisible text). All sizing Scale-based.
```

---

## VERIFICATION SUMMARY (Game Master runs after all tasks complete)

```lua
-- Full cycle 4 Queen verification
local function check(label, condition)
    print((condition and "PASS" or "FAIL") .. ": " .. label)
end

local SS = game:GetService("ServerScriptService")
local RS = game:GetService("ReplicatedStorage")
local SP = game:GetService("StarterPlayer").StarterPlayerScripts
local SG = game:GetService("StarterGui")

-- DataService count
local dsCount = 0
for _, c in SS.Systems:GetChildren() do if c.Name == "DataService" then dsCount += 1 end end
check("DataService count == 1", dsCount == 1)

-- Config
local ok, cfg = pcall(require, RS.Modules.Config)
check("Config loaded", ok)
if ok then
    check("Config.QUEEN exists", cfg.QUEEN ~= nil)
    check("QUEEN_TIERS[5].genGate == 1", (cfg.QUEEN_TIERS[5] or {}).genGate == 1)
    check("PROFILE_TEMPLATE.version == 4", (cfg.PROFILE_TEMPLATE or {}).version == 4)
    check("PROFILE_TEMPLATE.royalJellyProgress", (cfg.PROFILE_TEMPLATE or {}).royalJellyProgress == 0)
end

-- Server scripts
check("QueenService exists", SS.Systems:FindFirstChild("QueenService") ~= nil)
local rs = SS.Systems:FindFirstChild("ResourceService")
check("ResourceService has computeRoyalJellyPerSecond", rs and rs.Source:find("computeRoyalJellyPerSecond") ~= nil)
check("ResourceService has step 4b", rs and rs.Source:find("4b. Royal Jelly") ~= nil)
local main = SS:FindFirstChild("Main")
check("Main requires QueenService", main and main.Source:find("QueenService") ~= nil)

-- Client scripts
local qc = SP.Controllers:FindFirstChild("QueenController")
check("QueenController is ModuleScript", qc ~= nil and qc.ClassName == "ModuleScript")
local cm = SP:FindFirstChild("ClientMain")
check("ClientMain requires QueenController", cm and cm.Source:find("QueenController") ~= nil)

-- Templates
local queens = RS.Templates:FindFirstChild("Queens")
local qCount = 0
if queens then for _, q in queens:GetChildren() do if q:IsA("Model") then qCount += 1 end end end
check("5 Queen templates exist", qCount == 5)

-- HiveGui
local card = SG:FindFirstChild("HiveGui") and SG.HiveGui.Panel.Pages.QueenPage.Card
check("UpgradeButton exists", card and card:FindFirstChild("UpgradeButton") ~= nil)
check("JellyFrame exists", card and card:FindFirstChild("JellyFrame") ~= nil)
check("No old Body label", card and card:FindFirstChild("Body") == nil)
check("QueenBadge on HiveButton", SG.HiveGui.HiveButton:FindFirstChild("QueenBadge") ~= nil)

-- HiveController
local hc = SP.Controllers:FindFirstChild("HiveController")
check("renderQueen in HiveController", hc and hc.Source:find("renderQueen") ~= nil)
check("No 'coming soon' queen text", hc and hc.Source:find("Queen upgrades are not in the game yet") == nil)
```
