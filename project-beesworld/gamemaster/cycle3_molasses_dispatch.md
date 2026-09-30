# CYCLE 3 — OLD MOLASSES DISPATCH PROMPTS
# Ready to copy into Game Master's Task calls when Roblox Studio MCP is available.
# Order: (1) world-builder, (2) luau-scripter [ThreatService], (3) enemy-designer [EnemyAI]
# All three can run in parallel — world-builder and scripter have no dependency,
# enemy-designer needs the world-builder's Workspace structure and scripter's ThreatService.

---

## FIRST: Bug #9 Fix (CRITICAL — do before any Molasses work)

Before any of the below, run `fix_bug9_duplicate_dataservice.lua` in Studio Command Bar (Edit mode).
The duplicate DataService must be resolved before any further DataService-touching work ships.

---

## STEP A: world-builder prompt (Pine Treeline + Bear Lane + Molasses Den)

```
Build the Pine Treeline zone, Bear Lane corridor, and Molasses Den for A Bee's World.

=== EXISTING MAP STATE ===
The following zones are already built in Workspace.Map:
- WildMeadow (Z −266..−96)
- ApiarySite (hub, Z −406..−266)
- PetalPath (Z −96..−80)
- Plots/Plot1..Plot6 (each 110×110 slab, centers at X = n*120−420, Z 0; decks at Y=6.5)
  Each plot has a Fence (at plot local Z=+52) with a 12-stud gap at local X=+45

WHAT DOES NOT EXIST YET (build these):
1. Pine Treeline band
2. Bear Lane corridor behind the treeline
3. Molasses Den

=== ZONE SPECS ===

### Pine Treeline
- Folder: Workspace.Map.PineTreeline
- Position: main band centered (0, 0, +105), spans approximately X −450..+450, Z +70..+140
- Also a perimeter run at X=±430 (very thin east/west strips connecting the main band)
- Floor: Needle litter layer — Wood material, color #4A3F2E, 900×70 slab, Y=0, Anchored, CanCollide
- Darkness: this is the darkest zone — no global ambient source, only the 4 resin node point lights
- 4 Resin Node point lights: Color #C9821E, Range 18, Brightness 0.7, at positions:
  (-220, 4, +95), (-70, 4, +100), (80, 4, +100), (230, 4, +95)
- 18 Pine Trees, each ~7 parts:
  - Trunk: cylinder, Wood #5A3E28, diameter 3, height varies 100-180 studs, base at Y=0
  - Bark ring details: 1-2 flat cylinder slabs (diameter slightly larger than trunk, 1 stud thick)
  - Canopy: 2-3 nested cone wedges at different heights, Grass (desaturated) #3E5C34
  - Distribute across X range with some clustering, trunks at Z ~85..125
  - Total trees: ~7 parts each = ~126 parts total
- 4 Resin Nodes (at the light positions):
  - Each: a Glass-material amber blob, color #C9821E, faintly emissive (Material = Neon, slightly transparent)
  - 2-3 parts stacked, roughly 3×3×4, sitting at ground level
  - Tag each with CollectionService tag "ResinNode"
  - Set Attribute "PatchId" = 17 for (-220), 18 for (-70), 19 for (80), 20 for (230)
  - Add ProximityPrompt (ActionText="Harvest Resin", ObjectText="Resin Node", MaxActivationDistance=12)
- Total Pine Treeline part count: ~150 parts

### Bear Lane
- Folder: Workspace.Map.BearLane
- A 16-stud-wide ground slab behind the treeline at Z=+140, spanning X −345..+345
- Material: Grass #4A3F2E (dark needle-litter color matching treeline floor)
- One flat slab: 690 × 16 × 1, centered at (0, 0, +140), Y=0, Anchored
- The lane connects the Den to each plot's fence gap
- No walls, no obstructions — pathfinding must be clear for AgentRadius=6

### Molasses Den
- Folder: Workspace.Map.MolassesDen
- Center: (0, 0, +185), a clearing ~30×30 behind the treeline
- Den floor: 3-4 overlapping rough circle/oval slabs, Ground material #3A2E1A (dark earth)
- Den interior props:
  - Rock cluster: 3-4 SmoothRock or smooth cylinder parts wedged together at (0, 1, +185), bulky
  - Log: cylinder, Wood, 14 studs long, 3 diameter, on its side at (-6, 1.5, +188)
  - Honey jar (the tribute jar): 1 cylinder + 1 slightly wider flat disk (lid), Glass material amber #C9821E, placed at (4, 0, +183) — visible "tribute point" for stage 6
  - IMPORTANT: do NOT place any PawPrint or Molasses model — ThreatService and EnemyAI handle those at runtime
- Den atmosphere: scratched bark marks on 2-3 nearby tree trunks (flat dark wedge parts welded to nearest pine trunks, barely visible)
- 4 Waypoint parts for bear pathfinding in Workspace.Map.BearLane (also create these):
  - Name each "BearWaypoint_N" and tag with CollectionService "BearLaneWaypoint"
  - Positions: (-300, 1, +140), (-100, 1, +140), (100, 1, +140), (300, 1, +140)
  - Each: 2×2×2 invisible part, Transparency=1, CanCollide=false, Anchored=true
- 1 Den waypoint: "BearWaypoint_Den", tag "BearLaneWaypoint", at (0, 1, +185)
### SmokerActivate visual indicator (one per plot — billboard so player knows where the Smoker IS)
When creating the SmokerActivate invisible parts above, also add:
- A BillboardGui as child of each SmokerActivate part:
  Name="SmokerBillboard", StudsOffset=Vector3.new(0,3,0), Size=UDim2.fromOffset(140,40), AlwaysOnTop=true
  Contains: TextLabel "USE SMOKER", TextColor3 #FFCC44, Font=GothamBold, TextSize=18, BackgroundTransparency=1
  **Default Enabled=false** — ThreatController enables it only during an active raid
  This makes the Smoker suddenly GLOW with a label when a raid starts — players know exactly where to go

### Smoker ProximityPrompts (one per plot — add to existing plot fences)
Plots 1-6 are already built. Add a Smoker activation trigger to each plot:
- For each plot N (plotX = N*120 - 420):
  - Create an invisible part "SmokerActivate_Plot{N}" at (plotX, 6.5, 30) — plot deck, front area
  - Size: 4×4×4, Transparency=1, CanCollide=false, Anchored=true
  - Tag with CollectionService "SmokerActivate", Attribute "PlotIndex" = N
  - Add ProximityPrompt (ActionText="Smoke", ObjectText="Smoker", MaxActivationDistance=30, HoldDuration=0.2)
  - Note: the visual Smoker structure itself will be built by world-builder later (bug #6 scope)
    For now this is an INVISIBLE trigger only — functional without the prop
- 6 total SmokerActivate parts, one per plot
- These are the targets HandleWaspSmoke validates distance against

- 6 Fence Gap markers (one per plot), in Workspace.Map.BearLane:
  - Compute per plot: plotX = plotIndex * 120 - 420 (Plot1=-300, Plot2=-180, ..., Plot6=+300)
  - Gap position = (plotX + 45, 1, +52)  ← this is the fence gap world position
  - Name each "FenceGap_Plot{N}", tag with "BearFenceGap", Attribute "PlotIndex" = N
  - Each: 4×4×4 invisible part, Transparency=1, CanCollide=false, Anchored=true

=== LIGHTING ===
The Pine Treeline should feel distinctly darker than the meadow. Do NOT add point lights except the 4 resin node ones. The zone's darkness is intentional and creates the tension.

=== VERIFICATION ===
After building, verify:
- PineTreeline folder exists with 18 trees (~126 parts), 4 resin nodes (~12 parts), needle floor
- BearLane folder: lane slab + 4 lane waypoints + 6 fence gap markers + 1 den waypoint
- MolassesDen folder: floor, rock cluster, log, honey jar, bark scratches
- Total parts across all three folders: ~150 (treeline) + ~20 (bear lane) + ~15 (den) = ~185 parts
- All waypoints: Anchored=true, CanCollide=false, Transparency=1
- All resin nodes have ProximityPrompt and "ResinNode" tag
- Report path: C:/claudeblox/project-beesworld/gamemaster/logs/cycle-003/reports/world-builder-treeline.md
```

---

## STEP B: luau-scripter prompt (ThreatService)

```
Implement ThreatService for A Bee's World — the wasp cycle and Old Molasses arc state machine.

=== ARCHITECTURE CONTEXT ===

ThreatService is a ModuleScript in ServerScriptService.Systems.
It is required by Main in the fixed load order, AFTER SwarmService.
Main calls ThreatService.Tick(dt) every 1 second.

ThreatService owns:
1. Wasp cycle (frequent, small raids, every 4-7 minutes)
2. Old Molasses arc (6-stage learning antagonist, one active raid at a time across all plots)
3. Raid scheduling, target selection, patience tracking, theft resolution, stage progression
4. Delegating movement to EnemyAI via attributes on Actor models

=== EXISTING SYSTEMS (read these, do NOT modify) ===
- DataService.Get(player) → profile (has profile.bear.stage, .repels, .offering, .lastRaid)
- ResourceService.StealHoney(profile, pct) → steals pct% of banked honey (implement this function if it doesn't exist, or confirm it exists)
- PopulationService.KillGuards(plotIndex, n) → kills n guard bees
- CombService.BreakPropolisSeam(plotIndex) → breaks one Propolis Seam (stage 5)
- PlotService.GetPlotOwner(plotIndex) → Player or nil
- PlotService.PushPublicStats(plotIndex) → updates PlotRoot BearStage attribute
- ThreatEvent (RemoteEvent in ReplicatedStorage/Remotes) → fires to all clients
- Notify (RemoteEvent) → fires to one or all players
- AchievementService.Unlock(player, "BearWrangler") → called after successful repel if player got ≥3 smoke hits

=== WHAT THREATSERVICE MUST DO ===

### 1. Initialization
ThreatService.Init():
- Store reference to all game systems
- Schedule first wasp check: random 4-7 minutes from server start
- Bear raid: first raid at a random time after 15 minutes play time (cumulative server uptime)

### 2. ThreatService.Tick(dt) — called every 1s from Main
- Advance wasp timer; trigger wasp raid when timer hits 0
- Advance bear raid timer; trigger bear raid when conditions met
- For any active raid: advance patience drain from guards/smoker queues; check Patience==0 → repel
- Handle theft: if bear is on plot and has been raiding for >30s, apply StealHoney
- Bear stage 5: break one PropolisSeam when bear first arrives on deck (not repeatedly)

### 3. Wasp Cycle — Three-Tier Defense System
Players have three ways to defeat a wasp raid. Each teaches a different skill loop.

**Tier 1 — Guard Threshold (passive, always-on):**
- If PopulationService.GetGuardCount(plotIndex) >= Config.WASP_GUARD_THRESHOLD (default: 15 guards)
- Wasps are killed immediately on spawn — no raid window, no stealing
- Fire ThreatEvent{kind="wasp", phase="guardsRepelled", targetPlot=N} for visual feedback
- This teaches: allocate guard bees in the Hive panel as a long-term defense

**Tier 2 — Smoker (active skill-check, 15s window):**
- During the 20s wasp raid window, players can activate the Smoker ProximityPrompt on their plot
- HandleWaspSmoke(player, plotIndex):
  - Validate: active wasp raid on plotIndex, player near Smoker position (within 30 studs)
  - Per-player cooldown: 3s between activations
  - Track smokeHits per raid (server-side count in the active raid table)
  - If smokeHits >= 2 within 15s: all WaspActors targeting that plot → Attribute "Alive"=false
    Fire ThreatEvent{kind="wasp", phase="smokeRepelled", targetPlot=N}
    Award small bonus: Notify player "+10 Propolis — Wasps fled the smoke"
  - Single smoke hit merely slows wasps (reduce raid countdown by 5s) but does NOT repel alone
  - This teaches: build a Smoker structure, activate it fast when ThreatEvent fires

**Tier 3 — SwatWasp (active manual, no time limit):**
- Player clicks a WaspDrone model while it orbits the plot
- Each swat kills one wasp — kills ALL before 20s to foil the raid entirely
- Harder than Smoker but possible solo
- This teaches: situational awareness and fast clicking as a fallback

WaspRaid(targetPlotIndex) — full flow:
- Check Tier 1 immediately: if guardCount >= WASP_GUARD_THRESHOLD → fire guardRepelled event, skip raid
- Otherwise: Fire ThreatEvent{kind="wasp", phase="scout", targetPlot=N}, announce 8s early
- At T+8: Spawn 3 WaspDrone actors in Workspace.Actors, tag "WaspActor"
  Set Attribute "TargetPlot"=N, "Alive"=true, "WaspId"=tostring(uniqueId) on each
- Start 20s raid window; store raidTable{plotIndex, smokeHits=0, startTime=tick()}
- During window: HandleWaspSmoke and HandleSwatWasp modify WaspActor Alive attributes
- At T+20: count alive wasps
  - 0 alive (guards killed, smoked, or swatted all): raid foiled — no theft
  - Any alive: raid fires → StealHoney(profile, 0.30), KillGuards(plotIndex, 1), ThreatEvent{kind="wasp",phase="raid"}
- Clear raidTable entry, clean up stale WaspActors, schedule next wasp check: 4-7 minutes

Config additions required:
- Config.WASP_GUARD_THRESHOLD = 15  (guards needed for auto-repel)
- Config.WASP_SMOKE_HITS_TO_REPEL = 2  (Smoker activations needed in window)
- Config.WASP_PROPOLIS_REWARD = 10  (propolis awarded for Smoker repel)

ThreatService must expose HandleWaspSmoke() in addition to HandleSwatWasp().
RemoteRouter wires: WaspSmoke→HandleWaspSmoke, SwatWasp→HandleSwatWasp.

### 4. Bear Arc
BearRaid(targetPlotIndex):
- Target: max(honeyAmount * ripeness) across plots where OwnerUserId attribute != 0
- Announce 45s early: ThreatEvent{kind="bear", phase="announce", targetPlot=N}, Notify all players
- At T+45s: clone OldMolasses from ServerStorage into Workspace.Actors
  - Tag with "BearActor"
  - Set Attributes: TargetPlot=N, Phase="Approach", Patience=maxPatience (from stage table)
- During raid: ThreatService does NOT move the bear — EnemyAI reads Phase attribute and moves it
- Poll Patience attribute (EnemyAI decrements it in response to Smoke/Guard events)
  Actually: ThreatService owns Patience. HandleSmoke(player, plotIndex) → attr Patience -= 14
  HandleGuardSting(plotIndex) → Patience -= 6, PopulationService.KillGuards(plotIndex, 1)
- When Patience reaches 0 → Repel():
  - Phase="Retreat" (EnemyAI walks bear back)
  - profile.bear.repels += 1
  - Award Royal Jelly to players who smoked ≥3 times
  - Unlock "BearWrangler" if applicable
  - Place PawPrint: clone from ServerStorage.Templates at fence gap position
  - Force-save player data
  - PlotService.PushPublicStats(plotIndex) (updates BearStage attribute)
  - If repels == 5: schedule stage 6 next raid, bear.stage = 6
  - Schedule next raid: depends on stage (stage 1: 10-15min, stage 2: 8-12min, etc.)
- Stage-specific behaviors:
  - Stage 1: Phase="Approach" via front lane (Z −55 to fence gap via main path)
  - Stage 2+: Phase="Approach" via Bear Lane (Z +140)
  - Stage 4: also spawn CubActor, tag "CubActor", target pollen cells
  - Stage 5: set Phase="Stage5Entry" briefly → CombService.BreakPropolisSeam(plotIndex)
  - Stage 6: Phase="Sitting" instead of raid; fire ThreatEvent{phase="sitting"};
    show BearOffering UI via Notify or Moment remote; start 90s decision timer
    If timer expires with no choice → count as "refuse"

### 5. BearOffering handler (from RemoteRouter)
HandleBearOffering(player, {choice}):
- Validate: bear.stage==6, sitting active on player's plot, choice∈{"jar","refuse"}
- "jar": honey≥5000 → StealHoney cost 5000, profile.bear.offering="jar"
  Set permanent nap position on meadow (Workspace.Actors.MolassesNeighbour — EnemyAI handles)
  Unlock "MolassesFur" cosmetic, Notify player
- "refuse": profile.bear.offering="refuse"
  Set future raids: patience=400, theft=0.45, interval=6min
  Unlock "Furious" cosmetic, Notify player
- Force-save, PlotService.PushPublicStats

### 6. SwatWasp handler (from RemoteRouter)
PROBLEM ADDRESSED: clicking a moving WaspDrone model is too hard. Solution: ProximityPrompt on the model, not mouse click.

HandleSwatWasp(player, {waspId}):
- Validate: wasp model exists with WaspId attribute matching waspId, Alive==true
- Validator.NearPosition(player, wasp.PrimaryPart.Position, 55) — generous range, wasps orbit
- Set Alive=false attribute → EnemyAI destroys the model
- Award 0 resources (swatting is its own reward, teaches the defence loop)

WaspDrone template MUST include a ProximityPrompt as a child of Body:
- ProximityPrompt: ActionText="Swat", ObjectText="", MaxActivationDistance=55, HoldDuration=0
- When triggered (server-side Triggered event on the prompt): fires HandleSwatWasp(player, {WaspId=model:GetAttribute("WaspId")})
- This replaces click-detection entirely — player just walks near a wasp and taps Swat
- The ProximityPrompt fires the remote → server validates as usual (Validator.NearPosition still applies)

enemy-designer NOTE: add this ProximityPrompt to the WaspDrone template in ServerStorage (child of Body part).

### 7. WaspSmoke handler (from RemoteRouter) — NEW
HandleWaspSmoke(player, {plotIndex}):
- Validate: plotIndex∈1..6, raidTable[plotIndex] exists (active wasp raid), not expired
- NearPosition(player, smokerPosition, 30) — smokerPosition = Vector3.new(plotX, 6.5, 30) where plotX = plotIndex*120-420
- Per-player cooldown 3s (separate from bear smoke cooldown)
- raidTable[plotIndex].smokeHits += 1
- if smokeHits >= Config.WASP_SMOKE_HITS_TO_REPEL:
    Kill all WaspActors with TargetPlot==plotIndex (set Alive=false)
    Fire ThreatEvent{kind="wasp", phase="smokeRepelled", targetPlot=plotIndex}
    Notify(player, "+10 Propolis — Wasps fled the smoke")
    ResourceService.AddPropolis(player.UserId, Config.WASP_PROPOLIS_REWARD)
- else: extend raid window by 5s (smokeHits==1 buys time)

### 8. BearSmoke handler (from RemoteRouter) — formerly "HandleSmoke"
HandleBearSmoke(player, {plotIndex}):
- Validate: plotIndex∈1..6, active bear raid targeting that plot
- NearPosition(player, smokerPosition, 30) — same smoker position formula as WaspSmoke
- Per-player cooldown 2.5s
- Patience -= 14 on the bear actor, track this player's bear smoke count

NOTE: Both remotes share the same physical Smoker location. RemoteRouter wires:
- "WaspSmoke" → HandleWaspSmoke
- "Smoke" (existing) → HandleBearSmoke
The client decides which to fire based on the active threat (ThreatEvent tells client what's active).

=== THREATCONTROLLER — new LocalScript in StarterPlayerScripts ===
PROBLEM ADDRESSED: players don't know a raid is happening or how to respond. ThreatController is the client-side HUD that announces threats and teaches the defense loop.

ThreatController (LocalScript, StarterPlayerScripts, ~80 lines, --!strict):
- Listens to ThreatEvent (RemoteEvent in ReplicatedStorage/Remotes) via OnClientEvent
- On event kind="wasp", phase="scout": 
    Show toast "🐝 WASP SCOUT — Swat them or Smoke them!" (3 second fade-out)
    Enable the SmokerBillboard BillboardGui on the local player's plot SmokerActivate part (find by PlotIndex attribute matching player's assigned plot)
    Play a warning sound (short buzzing sting) on LocalPlayer character
- On event kind="wasp", phase="raid":
    Show toast "🐝 WASPS STEALING HONEY! 30%" in red (4 second fade-out)
    Disable SmokerBillboard
- On event kind="wasp", phase="smokeRepelled" or "guardsRepelled":
    Show toast "✓ Wasps repelled!" in green (3 second fade-out)
    Disable SmokerBillboard
- On event kind="bear", phase="announce":
    Show toast "🐻 OLD MOLASSES IS COMING... (45s)" with countdown in amber
    Enable SmokerBillboard for bear defense too
- On event kind="bear", phase other phases: update toast text appropriately
- Toast UI: a simple TextLabel in ScreenGui positioned center-top, TweenService fade in/out
  Can reuse the existing Notify/toast framework if one exists (check StarterGui first)

The billboard system (enable/disable per raid) is what makes the Smoker DISCOVERABLE.
A player who has never used it sees a glowing "USE SMOKER" label appear above a part near their hive the moment wasps arrive — they understand immediately.

=== INTEGRATION NOTES ===
- ThreatService must expose Init(), Tick(dt), HandleSwatWasp(), HandleWaspSmoke(), HandleBearSmoke(), HandleBearOffering()
- RemoteRouter.Wire() connects SwatWasp→HandleSwatWasp, WaspSmoke→HandleWaspSmoke, Smoke→HandleBearSmoke, BearOffering→HandleBearOffering
- Config has BEAR_STAGES table with patience and theft values per stage — add if missing
- Use task.delay() for scheduled future events, tracked in a local table for cancellation
- ALL state mutations go through DataService.Get(player) → mutate profile table → DataService marks dirty

=== BEFORE WRITING ===
Read the existing ThreatService (if any) first. Read RemoteRouter to understand the wiring pattern.
Read Main.lua to verify ThreatService.Init() and Tick() are already wired up.

Also build ThreatController (LocalScript in StarterPlayerScripts):
- Listens to ThreatEvent (RemoteEvent) OnClientEvent
- Shows toast/HUD for wasp scout, wasp raid, smoke-repelled, bear announce events
- Enables/disables SmokerBillboard BillboardGui on player's plot SmokerActivate part during raids
- ~80 lines, --!strict

Verify through MCP after creating:
- ThreatService ModuleScript in Systems, 150+ lines, --!strict
- exposes Init, Tick, HandleSwatWasp, HandleWaspSmoke, HandleBearSmoke, HandleBearOffering
- Config has BEAR_STAGES, WASP_GUARD_THRESHOLD, WASP_SMOKE_HITS_TO_REPEL, WASP_PROPOLIS_REWARD
- ThreatController LocalScript in StarterPlayerScripts, 60+ lines, listens to ThreatEvent

Report path: C:/claudeblox/project-beesworld/gamemaster/logs/cycle-003/reports/luau-scripter-threatservice.md
```

---

## STEP C: enemy-designer prompt (EnemyAI movement layer)

```
Build the EnemyAI movement layer for A Bee's World — Old Molasses, the Cub, and WaspDrone actors.

THIS IS A DELEGATED STATE MACHINE. You are building the MOVEMENT layer, not the brain.
ThreatService (already built or being built in parallel) owns raid state.
You build: (1) physical rigs in ServerStorage, (2) EnemyAI Script that reads attributes and moves bodies.

=== ARCHITECTURE ===

ThreatService clones actor models from ServerStorage at raid time:
- "OldMolasses" model → tags clone with "BearActor", sets Attributes: TargetPlot(1..6), Phase(string), Patience(number)
- "MolassesCub" model → tags with "CubActor", same attributes
- "WaspDrone" model → tags with "WaspActor", sets TargetPlot, Alive(bool)

EnemyAI Script watches CollectionService for these tags and drives movement on each actor.

=== WHAT TO BUILD ===

### Model 1: OldMolasses (in ServerStorage)
Visual design: A tired, old, HUNGRY bear. Not scary — just inevitable.
- He is ROUNDED and HEAVY, not sharp. Bulky. Low to the ground.
- Colors: WarmBrown/Brown material, color #7A4E2D (worn honey-stained fur)
- R6 structure (mandatory):
  - HumanoidRootPart: 2×2×1, Transparency=1, CanCollide=false
  - Torso: 5×4×3, BrickColor Brown #7A4E2D, bulky and barrel-shaped
  - Head: 3.5×3×3, slightly rounded, same color — too big for his body (tired old bear)
  - Left/Right Arms: 1.5×3.5×1.5, end wider (paw effect) — CanCollide=false
  - Left/Right Legs: 2×2.5×2 stubby — CanCollide=false
  - PrimaryPart = HumanoidRootPart
  - ALL parts Anchored=false
  - All 6 Motor6D joints with correct C0/C1 for these proportions
  - Humanoid: Health=400, MaxHealth=400, WalkSpeed=10, DisplayDistance=0
- Decorative parts (welded to Torso/Head):
  - 2 Paw mark circles on forehead: flat dark cylinder (diameter 1.5, height 0.2) — "#3A2520"
  - Nose: small dark sphere/cylinder at front of Head
  - Belly patch: flat slightly lighter rectangle on Torso front — "#9A6A3E"
- Sounds (as children of HumanoidRootPart):
  - "AmbientRumble": looped, low bass rumble, SoundId (use rbxassetid://507864443 placeholder), Volume=0.2, RollOffMaxDistance=300
  - "ApproachGrowl": not looped, SoundId placeholder, Volume=0.5, RollOffMaxDistance=200
  - "RaidSnuffle": looped, SoundId placeholder, Volume=0.35, RollOffMaxDistance=150
  - "RetreatingGrunt": not looped, Volume=0.4, RollOffMaxDistance=200
- Tag model with CollectionService "BearTemplate" (not "BearActor" — that's for live instances)

### Model 2: MolassesCub (in ServerStorage)
Same design as OldMolasses, half proportions:
- Torso 2.5×2×1.5, Head 1.8×1.5×1.5, limbs proportionally smaller
- WalkSpeed=14 (faster than bear)
- Humanoid Health=200, MaxHealth=200
- Tag: "CubTemplate"

### Model 3: WaspDrone (in ServerStorage)
NOT an R6 rig. Wasps fly.
3-part simple model:
- Body: elongated cylinder or wedge, 1×1×3, Yellow material #F5C542 with CanCollide=false
- Wings_L, Wings_R: flat thin rectangle 2×0.1×1, SmoothPlastic semi-transparent (Transparency=0.3) #EEEEEE — CanCollide=false
- WeldConstraint wings to body
- PrimaryPart = Body
- BodyVelocity (or LinearVelocity) attached to Body — EnemyAI sets Velocity
- Humanoid NOT needed — destroyed by setting Alive=false
- Tag: "WaspTemplate"

=== EnemyAI SCRIPT (ServerScriptService, Script, ~200 lines) ===

--!strict script that:

1. Watches for new BearActor, CubActor, WaspActor via CollectionService signals + catch-up loop

2. For BearActor: handleBear(model)
   - Wait for PrimaryPart (HumanoidRootPart)
   - Compute target positions from TargetPlot attribute:
     plotX = targetPlot * 120 - 420
     fenceGap = Vector3.new(plotX + 45, 0, 52)  -- world coords
     denPos = Vector3.new(0, 0, 185)
   - Listen to model.AttributeChanged:
     Phase = "Approach": pathfind Den→nearest BearWaypoint→fenceGap (AgentRadius=6, AgentHeight=26, AgentCanJump=false, WaypointSpacing=8)
     Phase = "Raid": wander the plot deck area (fenceGap position ± 20 studs), slow speed
     Phase = "Theft": move toward the highest-ripeness honey cell position (read from CombCell-tagged parts' Position)
     Phase = "Retreat": pathfind back to fenceGap→Bear Lane→Den, then Destroy(model)
     Phase = "Sitting": walk slowly via front lane (Z −55 approach) to ramp foot, stop, face hive
   - Sound management: AmbientRumble plays always, ApproachGrowl on Approach phase start, RaidSnuffle on Raid phase

3. For CubActor: handleCub(model)
   - Same pattern as Bear but faster, targets Pollen Cell positions instead of honey cells
   - Pollen cells: find CombCell-tagged parts with Attribute "CellType"=="Pollen" on the target plot

4. For WaspActor: handleWasp(model)
   - No PathfindingService — direct movement via Humanoid:MoveTo() toward target
   - Target: circle the target plot deck (TargetPlot attribute) at Y=8 (flying height)
   - Every 2s, check if Alive==false → Destroy(model)
   - Fly in a circle pattern: compute orbit position around plot center, radius 20, incrementing angle

5. Cleanup:
   - BearActor destroyed (by Retreat handler): disconnect all connections
   - Players.PlayerRemoving: nil check any character references

=== PATHFINDING NOTE ===
Bear pathfinding goes: Den (0,0,+185) → Bear Lane waypoints → Fence Gap (plotX+45, 0, +52) → Plot Deck
Use WaypointSpacing=8, AgentRadius=6, AgentHeight=26, AgentCanJump=false.
BearWaypoint parts are in Workspace.Map.BearLane, tagged "BearLaneWaypoint".
Path MUST be computed with pcall — bear lane and fence gap are tight but navigable at AgentRadius=6.

=== VERIFY AFTER BUILDING ===
- OldMolasses in ServerStorage: 7 R6 parts + 6 joints + Humanoid + 4 decorative parts
- MolassesCub in ServerStorage: same structure, half size
- WaspDrone in ServerStorage: 3 parts, Body + Wings, PrimaryPart set
- EnemyAI Script in ServerScriptService: 150+ lines, --!strict, handles all 3 actor types
- All templates tagged correctly (BearTemplate, CubTemplate, WaspTemplate)

Report path: C:/claudeblox/project-beesworld/gamemaster/logs/cycle-003/reports/enemy-designer-enemyai.md
```

---

## STEP D: After A+B+C complete — verify integration

Run this in Studio to verify the full Molasses zone exists and is connected:

```lua
-- Verification script for Molasses zone
local WS = game:GetService("Workspace")
local SSS = game:GetService("ServerScriptService")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local results = {}

-- World check
local treeline = WS.Map:FindFirstChild("PineTreeline")
results[#results+1] = "PineTreeline: " .. (treeline and "EXISTS " .. #treeline:GetDescendants() .. " descendants" or "MISSING")

local lane = WS.Map:FindFirstChild("BearLane")
results[#results+1] = "BearLane: " .. (lane and "EXISTS" or "MISSING")

results[#results+1] = "BearLaneWaypoints: " .. #CS:GetTagged("BearLaneWaypoint")
results[#results+1] = "BearFenceGaps: " .. #CS:GetTagged("BearFenceGap")
results[#results+1] = "ResinNodes: " .. #CS:GetTagged("ResinNode")

-- Script check
local threat = SSS.Systems:FindFirstChild("ThreatService")
results[#results+1] = "ThreatService: " .. (threat and (#threat.Source .. " chars") or "MISSING")

local ai = SSS:FindFirstChild("EnemyAI")
results[#results+1] = "EnemyAI: " .. (ai and (#ai.Source .. " chars") or "MISSING")

-- Template check
results[#results+1] = "OldMolasses template: " .. (SS:FindFirstChild("OldMolasses") and "EXISTS" or "MISSING")
results[#results+1] = "MolassesCub template: " .. (SS:FindFirstChild("MolassesCub") and "EXISTS" or "MISSING")
results[#results+1] = "WaspDrone template: " .. (SS:FindFirstChild("WaspDrone") and "EXISTS" or "MISSING")

print(table.concat(results, "\n"))
```

---

## Notes for Game Master

**Dispatch order:**
1. Bug #9 fix first (Command Bar in Studio, 2 minutes)
2. world-builder + luau-scripter in PARALLEL (independent)
3. enemy-designer AFTER both #2 complete (needs world geometry + ThreatService spec)

**After all three verified:**
→ STEP 4: code review (luau-reviewer, ThreatService + EnemyAI)
→ STEP 4b: UI for BearOffering two-button prompt (ui-designer, after review passes)
→ STEP 5: structural test (roblox-playtester)
→ STEP 6: play-test (computer-player, test wasp cycle + stage 1 Molasses encounter)
