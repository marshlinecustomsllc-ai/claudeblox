# THE QUEEN WALKS -- Feature Architecture (addendum to architecture.md)

**Task type:** TYPE C-HYBRID. Mostly systemic, with one visual entity that exists only on the client (0 server parts).
**Implements:**
- Build Order step 12 (`QueenService` + Queen models)
- Signature Moment 4, "The Queen Walks"
- The `RequestQueenUpgrade` row of the RemoteEvents table
- The HiveGui QUEEN tab

**Source of truth:** `architecture.md`, specifically:
- the Queen tiers table
- the QueenService script detail
- Signature Moment 4
- the Lighting brief entry "Queen Q4/Q5"
- the Comb Deck LIFE line "the Queen physically walks the comb"

Every deviation from architecture.md is called out and justified where it happens.

**Investigated live:** 2026-09-27, Edit datamodel, place "A Bee's World" (placeId 123313915411717), `RunService:IsRunning() == false`.

---

## Overview

Today the Queen is only a number. `profile.queenTier` already boosts hive output and hatch speed, and it already gates Nurses. But no player can change it, and no player can see her.

This feature makes her a visible character and makes her tier something you earn:
1. You build Royal Cells on the rim of the comb, touching Brood Cells. They drip Royal Jelly into your wallet.
2. When you have enough jelly, a gold "!" appears on the HIVE button. It leads to the QUEEN tab, which has one big UPGRADE button.
3. When you press it, the panel closes and the camera swings to your comb. The comb lights dip and she grows in a burst of gold.
4. After that she is bigger, slower and grander. She walks your brood cells for the rest of the session and leaves amber footprints on every cell she crosses.
5. At Matriarch, two attendant bees circle her and she glows. As Sun Queen she wears a halo and the comb ripples gold behind her.
6. Your neighbours see all of it.

The whole tier ladder already exists in data. Most of this job is four things:
- one missing income source
- one purchase entry point
- one client renderer
- one UI page

---

## 1. Verified current state: what is already wired and what is missing

Every row was checked with `script_grep` plus a full read of the function that consumes it. Nothing here is assumed.

### 1a. `Config.QUEEN_TIERS` fields

| Field | Status | Evidence | What this task does |
|---|---|---|---|
| `outputMult` | **ALREADY LIVE** | `ResourceService._tickPlayer` computes `queenMult = (Config.QUEEN_TIERS[queenTier] or Config.QUEEN_TIERS[1]).outputMult` and multiplies it into `effective`. | **Nothing.** Do not touch or duplicate it. |
| `layInterval` | **ALREADY LIVE** | `PopulationService.HatchInterval(profile)` uses `Config.QUEEN_TIERS[queenTier].layInterval` as the base hatch interval. `HatchTick` recomputes it on every call. | **Nothing.** An upgrade takes effect on the next 0.5s tick. |
| `rj` | **UNCONSUMED** (only used in `HiveController` placeholder display text) | No server code reads it. | QueenService reads it as the **per-step** cost to move INTO that tier from the tier below. This matches architecture.md's Queen tiers table (Q1 "start", Q2 5, Q3 20, Q4 75, Q5 250). Cumulative cost to Sun Queen is 350. |
| `name` | Display only (`HiveController.queenName`) | -- | Used by the new UI and by the Notify toast text. |

### 1b. Unlock flags

**`unlocksNurse` (Q3): effectively live through a parallel constant.**
- The flag itself is never read.
- But `Config.CASTES.nurse.requiresQueenTier = 3` is enforced in four places: `PopulationService.SetCastes` (server), `HiveController.nurseLocked` (client), `DataService.MIGRATIONS[1]`, and the PROFILE_TEMPLATE comment.
- The value 3 is the same tier the flag sits on.
- Evidence: grep for `requiresQueenTier`.
- **Decision:** no new gating logic. Nurses unlock automatically when `queenTier` reaches 3. QueenService.Init adds a boot-time consistency `warn` in case the two ever disagree (see 4.3).

**`unlocksGoldenComb` (Q4): inert, because the feature it gates does not exist.**
- `Config.CELL_TIERS[4].gate = "QueenQ4"` has no reader.
- `CombService.Upgrade` is not implemented at all. CombService's own TODO block defers it "until QueenService exists", so no cell can go past tier 1.
- The `GoldenCell` template exists, but nothing clones it.
- Evidence: the TODO block at the bottom of CombService's source.
- **Decision:** out of scope. The flag stays as inert stored state. QueenService exposes `HasUnlock(profile, "unlocksGoldenComb")`, so a future CombService.Upgrade has one real function to call for its T4 gate.

**`unlocksSwarm` (Q4): inert, because SwarmService does not exist.**
- `Config.SWARM`, `Formulas.SwarmThreshold` and `Formulas.SwarmRoyalJellyGrant` all exist, but nothing calls them.
- There is no `RequestSwarm` remote.
- Evidence: Systems folder listing and grep.
- **Decision:** out of scope. A future `SwarmService.CanSwarm` calls `QueenService.HasUnlock(profile, "unlocksSwarm")`.

**`unlocksFloor3` (Q5): inert, because comb floors 2 and 3 do not exist.**
- `Plots/PlotN/Comb/Floor2` and `Floor3` are empty folders with no DimCellPlates.
- `CombService.CanBuild` rejects any `floor ~= 1`.
- `RequestUnlockFloor` does not exist.
- `profile.floorsUnlocked` is only read by `PlotService.PushPublicStats`.
- Evidence: live tree read and grep.
- **Decision:** out of scope. A future `CombService.UnlockFloor(profile, 3)` calls `QueenService.HasUnlock(profile, "unlocksFloor3")`.

**Scope-down result:**
- None of the four flags needs new gating logic in this task.
- Two of the stat fields are already fully consumed.
- So the roadmap line "QueenService + Queen models" is smaller than it sounds in one way. It is bigger in another way, explained in 1c.

### 1c. Missing dependency that the roadmap does not mention: Royal Jelly has no real income source

| Royal Jelly source | Status |
|---|---|
| Royal Cell production (`Config.CELLS.Royal.royalJellyRatePerAdjacentBrood = 0.004`) | **NOT IMPLEMENTED.** ResourceService's header lists it as out of scope. BuildController's own comment confirms it: "Royal Cell's royal jelly production confirmed NOT yet implemented anywhere". Royal Cells are buildable today (2,500 honey + 60 propolis, rim only) and do nothing. |
| RetentionService day-7 login reward | +2 RJ per week |
| MonetizationService `RoyalJellyPackSmall` | +5 RJ, but `id = 0` (not configured), so it cannot currently be bought |
| Swarm grant | SwarmService does not exist |

Without Royal Cell production:
- the Laying Queen (5 RJ) takes about 2.5 weeks of daily logins
- the Matriarch takes most of a year

A purchase button that can never be pressed is a fake feature. **So Royal Cell Royal Jelly production is a required part of this task (section 4.2).** It is small, it is exactly what architecture.md specifies, and it gives the Royal Cell (currently a 2,500-honey decoration) a purpose.

### 1d. Other verified facts this spec builds on

**The `Moment` remote already exists.**
- DanceService creates it. Payload shape: `{id:string, plotIndex:number, payload:table}`.
- Its only client listener is `DanceController.onMoment`, which ignores every id except `"FirstWaggle"`. A new id is therefore safe.

**`PlotRoot.QueenTier` is already replicated to every client.**
- `PlotService.PushPublicStats` runs `root:SetAttribute("QueenTier", profile.queenTier)` on every ResourceService tick.
- `PlotService.ReleasePlot` resets it to `1` through `DEFAULT_PLOT_ATTRIBUTES`.
- So every client already knows every plot's queen tier for free.

**`RatesUpdate` already carries `queenTier`** as an additive field. HiveController uses it to gate the Nurse stepper today.

**`HiveGui` (DisplayOrder 11) structure:**
- Tabs: `Panel.Tabs.{CastesTab, QueenTab, PerksTab, VipTab}`.
- Pages: `Panel.Pages.{CastesPage, QueenPage, PerksPage, VipPage}`.
- `QueenPage.Card` currently holds only `Header` ("QUEEN - COMING SOON") and `Body` ("Queen upgrades are not in the game yet."), both FredokaOne.
- `Card` has UICorner, UIStroke and UIGradient.

**`SoundController` already plays `SFX_Purchase`** on `Notify{kind="purchase"}`, so the upgrade gets audio feedback for free.

**`HexGrid.ToWorld(q, r, origin, y)` does NOT add the lattice's +6 Z offset.**
- Live plates are at `plotCenter + (13.856*(q + r/2), 7.2, 12*r + 6)`.
- Checked: `DimCellPlate_-1_0` on Plot1 is at (-338.9, 7.2, 6.0).
- Any client code that places things on cells must pass `origin = plotCenter + Vector3.new(0, 0, 6)`.

**Cell geometry heights on Floor 1:**
- Cell wall tops are at plate-centre Y + 3.3, which is about 10.5 in world space.
- Full honey domes reach about Y 12.9.

**`Shared.FormatNumber` rounds to the nearest integer below 1,000** (4.6 shows as "5"). This is why Royal Jelly must stay an integer in `profile.royalJelly` (see 4.1).

**There are no Queen models yet.** `ReplicatedStorage.Templates` holds only `Cells`, `CellContent`, `Structures` and `Flora`.

### 1e. Pre-existing issues found during investigation

These were not caused by this feature, but they must be known before it ships.

**1. HIGH: there are two `ServerScriptService.Systems.DataService` modules.** [RESOLVED by GameMaster immediately after this report landed -- confirmed byte-identical, confirmed the non-canonical one was unreferenced (FindFirstChild/WaitForChild always resolved to the first), destroyed it, re-verified count==1, swept every other major container (Systems/ServerScriptService/Controllers/Modules/Remotes/StarterGui) for the same class of leftover-clone duplicate and found none.]
- Both are ModuleScripts with that exact name and byte-identical Source (16,128 characters).
- `Systems:FindFirstChild("DataService")` and `WaitForChild("DataService")` return the first one, so every current `require` probably resolves to the same instance.
- The danger: two DataService module instances means two separate `sessions` tables if anything ever resolves the second one. That would split player profiles and could lose data.
- Likely cause: leftover from the "clone the ModuleScript to bust the require() cache" technique, where the old instance was never destroyed.

**2. Tooling caveat: `script_grep` line numbers are stale for some scripts.**
- For Config and HudController, grep hits are about 6 to 18 lines off from what `script_read` shows.
- Implementers must find code **by function name plus a fresh `script_read`**, never by grep line numbers.

**3. Concurrency caveat: other agents are editing this place.**
- `script_read` each of HiveController, ResourceService, Main, ClientMain and DataService **immediately before** editing it.
- Build only in Edit mode with `RunService:IsRunning() == false`. This is the lesson from the NotifyGui data loss.

---

## 2. Feature scope

- **Flavor:** HYBRID.
  - Server: Config, DataService migration, Royal Jelly production in ResourceService, new QueenService, Main wiring.
  - Client: new QueenController, HiveGui QUEEN page, HiveController changes, two text fixes.
  - Templates: 5 Queen models, cloned only on the client.
- **Subagents:**
  - luau-scripter: sections 3, 4, 5, 6, 8 and 9
  - world-builder: section 7 (the Queen templates)
  - ui-designer: polish pass on section 8 after code review
  - luau-reviewer and roblox-playtester
- **World changes:** none. **Server part cost: 0.** Queens are cloned on each client into `Workspace.ClientFX` and never exist on the server.

**IN scope:**
1. Royal Cell Royal Jelly production (the income source).
2. `QueenService`, with a server-authoritative `RequestQueenUpgrade` remote.
3. `QueenService.HasUnlock`, as the single future reader of the `unlocks*` flags.
4. The Queen as a visible walking character on every owned plot (client-rendered), with 5 tier looks.
5. The `QueenGrowth` moment (the upgrade beat of Signature Moment 4).
6. The HiveGui QUEEN tab replacement, plus a discovery badge.
7. Profile migration v3 to v4.
8. Stale-text fixes (BuildController Royal tooltip, HelpGui Section7).

**OUT of scope.** The flags stay inert and the UI says "coming soon" honestly for:
- Golden Comb and all cell tier upgrades (`CombService.Upgrade`).
- SwarmService and prestige.
- Comb Floors 2 and 3.
- PerkService and the PERKS tab. The placeholder text stays as it is. Note for later: 3 of the 8 perks (`warmBrood`, `strongWings`, `deepCrop`) are already read by PopulationService and ForagingService. A first PerkService limited to those 3, plus `RequestSpendJelly`, would be small.
- The "capped Royal Cell" state (only SwarmService needs it).
- The Second Queen (Gen 5).

---

## 3. Data architecture

### 3.1 Exact changes to `ReplicatedStorage.Modules.Config`

**(a) QUEEN_TIERS.** Add `genGate = 1` to tier 5 only, and add the doc comment below. Leave every existing value untouched.

```lua
-- ============================================================
-- QUEEN_TIERS
-- ============================================================
-- rj = Royal Jelly cost to upgrade INTO this tier from the tier directly
-- below it (per-step, NOT cumulative; tier 1's 0 = the starting queen).
-- Total to reach Sun Queen = 5 + 20 + 75 + 250 = 350.
-- layInterval -> read by PopulationService.HatchInterval (live).
-- outputMult  -> read by ResourceService._tickPlayer (live).
-- unlocks*    -> read ONLY through QueenService.HasUnlock (cumulative:
--               a flag granted at tier N stays granted at every tier > N).
--               unlocksNurse is mirrored by Config.CASTES.nurse.requiresQueenTier
--               (the real, enforced gate) -- QueenService.Init warns if the two disagree.
-- genGate     -> minimum profile.generation required to upgrade INTO this
--               tier (architecture.md RemoteEvents row: "generation gate for Q5").
--               NOTE: SwarmService does not exist yet, so generation is 0 for
--               everyone and Sun Queen is currently unreachable BY DESIGN. To open it
--               before swarming ships, change genGate to 0 -- a one-line decision
--               for Game Master, not a code change.
Config.QUEEN_TIERS = {
	{ rj = 0, layInterval = 12.0, outputMult = 1.00, name = "Virgin Queen" },
	{ rj = 5, layInterval = 8.0, outputMult = 1.15, name = "Laying Queen" },
	{ rj = 20, layInterval = 5.0, outputMult = 1.35, name = "Crowned Queen", unlocksNurse = true },
	{ rj = 75, layInterval = 3.0, outputMult = 1.60, name = "Matriarch", unlocksGoldenComb = true, unlocksSwarm = true },
	{ rj = 250, layInterval = 1.8, outputMult = 2.00, name = "Sun Queen", unlocksFloor3 = true, genGate = 1 },
}
```

**(b) New `Config.QUEEN` block.** Insert it directly after `Config.QUEEN_TIERS`.

```lua
-- ============================================================
-- QUEEN (QueenService server + QueenController client -- Signature Moment 4)
-- ============================================================
Config.QUEEN = {
	-- Server
	upgradeRatePerSecond = 1,        -- RequestQueenUpgrade Validator.RateLimit (architecture.md: "rate 1/s")
	royalJellyNurseMinCount = 1,     -- population.nurse >= this -> Royal Cells x(1 + Config.CASTES.nurse.royalCellBonus)

	-- Client placement (QueenController)
	walkFloor = 1,                   -- she walks the Brood Comb (Floor 1) only
	latticeZOffset = 6,              -- architecture.md: cell local Z = 12*r + 6 (HexGrid.ToWorld does NOT add it)
	walkHeightAboveFloorY = 4.1,     -- pivot Y = Config.FLOOR_Y[walkFloor] + 4.1 = 10.6 (just above the ~10.5 wall tops)
	flashHeightAboveFloorY = 1.1,    -- amber footprint disc Y = FLOOR_Y + 1.1 (just above plate top 7.5)
	renderRadiusStuds = 250,         -- other plots' queens rendered only within this distance (matches bee LOD)
	lodCheckSeconds = 1.0,
	cellFlashSeconds = 0.6,          -- architecture.md: "Cells flash amber for 0.6s as she passes"
	cellFlashStartTransparency = 0.45,
	rippleDelaySeconds = 0.3,        -- Sun Queen: ring-1 ripple starts this long after she leaves a cell
	rippleStaggerSeconds = 0.08,
	layDipStuds = 0.4,               -- abdomen-dip "laying" gesture on each Brood cell
	layDipSeconds = 0.3,

	-- QueenGrowth moment (architecture.md Signature Moment 4)
	growth = {
		dimSeconds = 0.5,            -- "the comb dims for 0.5s"
		dimTo = 0.3,                 -- plot PointLights -> 30% of their captured brightness
		growSeconds = 1.2,           -- "she grows over 1.2s"
		burstCount = 40,             -- GrowthBurst:Emit(40) at the end of the grow
		relightPeak = 1.15,          -- "the comb re-lights brighter": 115% ...
		relightSeconds = 0.4,
		settleSeconds = 1.5,         -- ... then settles back to 100%
		holdSeconds = 1.0,           -- pause after the burst before she walks again
	},
	camera = {                       -- owner-only, mirrors DanceController.playFirstWaggleCamera
		maxDistanceStuds = 150,      -- only if the owner's character is this close to their queen
		backStuds = 26,
		upStuds = 14,
		inSeconds = 0.6,
		outSeconds = 0.6,
	},

	-- Per-tier look + gait. bodyLength is the AUTHORING CONTRACT for the
	-- ReplicatedStorage.Templates.Queens.Queen_T<n> models (nose-to-tail, studs)
	-- and the growth animation's start ratio (oldLength / newLength).
	VISUALS = {
		{ template = "Queen_T1", bodyLength = 5.0, walkSpeed = 6.0, pauseSeconds = 1.0, attendants = 0, orbitRadius = 0, ripple = false },
		{ template = "Queen_T2", bodyLength = 5.5, walkSpeed = 5.0, pauseSeconds = 1.5, attendants = 0, orbitRadius = 0, ripple = false },
		{ template = "Queen_T3", bodyLength = 6.0, walkSpeed = 3.5, pauseSeconds = 2.0, attendants = 0, orbitRadius = 0, ripple = false },
		{ template = "Queen_T4", bodyLength = 9.0, walkSpeed = 3.0, pauseSeconds = 2.0, attendants = 2, orbitRadius = 4.5, ripple = false },
		{ template = "Queen_T5", bodyLength = 12.5, walkSpeed = 2.5, pauseSeconds = 2.5, attendants = 2, orbitRadius = 7.0, ripple = true },
	},
	attendantOrbitRadPerSec = 2.4,
	attendantHeight = 2.5,           -- above the queen's pivot
}
```

The `bodyLength` values for Q4 (9.0) and Q5 (12.5) are architecture.md's "1.8x size" and "2.5x size", measured against the 5.0-stud Virgin Queen. Q1 to Q3 grow only a little (a longer abdomen), which matches the Visual column of the tier table.

**(c) PROFILE_TEMPLATE.**
- Bump `version = 3` to `version = 4`.
- Extend the version doc comment with one line for MIGRATIONS[3].
- Add one field next to `royalJelly`:

```lua
	royalJelly = 0,
	-- Fractional Royal Jelly accumulator, always in [0, 1). ResourceService adds
	-- royalJellyRate*dt here each tick and moves every whole unit into
	-- royalJelly, so royalJelly itself is ALWAYS an integer. That keeps every
	-- existing display (HudController JellyChip via Shared.FormatNumber, which
	-- rounds) and every existing integer grant (RetentionService,
	-- MonetizationService) correct with zero changes. Added via
	-- DataService.MIGRATIONS[3] for pre-existing profiles.
	royalJellyProgress = 0,
```

### 3.2 `DataService.MIGRATIONS[3]` (v3 to v4)

Insert this directly after `MIGRATIONS[2]`, using the same doc-comment style:

```lua
-- v3 -> v4 (Queen system -- see architecture_queen_addendum.md):
-- 1. royalJellyProgress: new fractional Royal Jelly accumulator field.
-- 2. Defensive queenTier normalization: QueenService is the first code that
--    WRITES queenTier, and it indexes Config.QUEEN_TIERS[queenTier + 1] -- a
--    legacy non-integer / out-of-range value would break that lookup, so
--    clamp it to a valid tier once here.
MIGRATIONS[3] = function(profile)
	profile.royalJellyProgress = profile.royalJellyProgress or 0
	local tier = math.floor(tonumber(profile.queenTier) or 1)
	profile.queenTier = math.clamp(tier, 1, #Config.QUEEN_TIERS)
	profile.royalJelly = math.floor(tonumber(profile.royalJelly) or 0)
	profile.version = 4
end
```

Live players already have saved data (for example the real user's `hive_2354572334`). So this change must go through the migration chain, not the "safe additive field, no live players yet" shortcut.

### 3.3 Runtime state and single sources of truth

| Data | Stored in | Written by | Read by |
|---|---|---|---|
| `profile.queenTier` (int 1..5) | profile (persisted) | **QueenService.Upgrade only**, plus the MIGRATIONS[3] clamp | ResourceService (outputMult), PopulationService (layInterval, nurse gate), PlotService (attribute), QueenService |
| `profile.royalJelly` (int) | profile | ResourceService (production), RetentionService and MonetizationService (grants), QueenService (spend) | ResourceService WalletUpdate, QueenService |
| `profile.royalJellyProgress` (float, 0 to under 1) | profile | ResourceService only | ResourceService, RatesUpdate (for display) |
| `PlotRoot.QueenTier` attribute | replicated to all clients | PlotService.PushPublicStats (existing) | QueenController on every client |
| Rendered queens and walk state | client memory | QueenController | QueenController |

A queen upgrade cannot leave mid-generation state inconsistent. Every consumer reads `profile.queenTier` fresh on each call, and none of them caches it.

---

## 4. Server

### 4.1 Pacing (so the numbers are a decision, not an accident)

Rate per Royal Cell = `0.004/s x (adjacent Brood cells on the same floor) x CellOutputMult(lvl)`.
- `CellOutputMult` is x1 today, because no cell can leave tier 1 yet.
- The total is multiplied by 1.40 when `population.nurse >= 1`. Nurses only exist from Queen tier 3 onward.

| Setup | RJ per minute | Time to Laying Queen (5 RJ) | Then to Crowned Queen (+20 RJ) | Then to Matriarch (+75 RJ) |
|---|---|---|---|---|
| 1 Royal, 1 Brood neighbour | 0.24 | 21 min | 83 min | -- |
| 1 Royal, 2 Brood | 0.48 | 10 min | 42 min | 2.6 h (1.9 h with nurses) |
| 2 Royal x 2 Brood | 0.96 | 5 min | 21 min | 55 min with nurses |
| 3 Royal x 3 Brood, plus nurses | 3.02 | 1.7 min | 7 min | 25 min |

**How players afford a Royal Cell.**
- It costs 60 propolis, and there is no kiln yet.
- Propolis comes from daily login rewards (day 2 onward gives 50 to 500) and daily quests (30 each).
- So a first-session player who finishes 2 quests can afford one.
- This link is deliberate: quests give propolis, propolis buys a Royal Cell, the cell makes jelly, and jelly upgrades the Queen.

**How many Brood neighbours a Royal Cell can have.**
- A rim corner cell has 3 in-lattice neighbours.
- A rim edge cell has 4.
- So there is a real placement puzzle: put Royal Cells on rim edges, backed by Brood.

### 4.2 `ResourceService`: Royal Jelly production (MODIFY)

**Location:** `ServerScriptService.Systems.ResourceService`

**Step 1. Add a require.** Put `local HexGrid = require(Modules:WaitForChild("HexGrid"))` next to the Config and Formulas requires. HexGrid only requires Config, so there is no cycle.

**Step 2. Add a local function above `_tickPlayer`,** and expose it for MCP testing:

```lua
-- ============================================================
-- ROYAL JELLY RATE (architecture.md Cells table: "Royal Cell -- produces
-- Royal Jelly = 0.004/s x adjacent Brood Cells"; Castes table: Nurse
-- "+40% Royal Cell output")
-- ============================================================
local function computeRoyalJellyPerSecond(profile: any): number
	local rate = 0
	local perBrood = Config.CELLS.Royal.royalJellyRatePerAdjacentBrood
	for floor = 1, 3 do
		local floorComb = profile.comb[floor]
		if floorComb then
			for key, cellData in floorComb do
				if cellData.t == "Royal" then
					local q, r = HexGrid.FromKey(key)
					local brood = 0
					for _, n in HexGrid.Neighbours(q, r) do
						local nData = floorComb[HexGrid.Key(n.q, n.r)]
						if nData and nData.t == "Brood" then
							brood += 1
						end
					end
					rate += perBrood * brood * Formulas.CellOutputMult(cellData.lvl or 1)
				end
			end
		end
	end
	local nurses = (profile.population and profile.population.nurse) or 0
	if rate > 0 and nurses >= Config.QUEEN.royalJellyNurseMinCount then
		rate *= (1 + Config.CASTES.nurse.royalCellBonus)
	end
	return rate
end
ResourceService._computeRoyalJellyPerSecond = computeRoyalJellyPerSecond -- exposed for direct MCP testing only
```

These multipliers are deliberately **not** applied to Royal Jelly:
- `queenMult`
- the generation multiplier
- propolis seams
- MonetizationService's VIP/DoubleHoney multiplier

Reasons:
- Royal Jelly is the prestige currency. Compounding the output multipliers into it would make the Queen tiers speed themselves up.
- VIP and DoubleHoney are sold as honey boosts, not jelly boosts.

**No existing behaviour changes.**

**Step 3. Add a new step inside `_tickPlayer`.**
- Put it **after step 4** (`PopulationService.HatchTick(...)`), so the nurse count is current.
- Put it **before step 5** (public stats). That also puts it before the WalletUpdate in step 6.

```lua
	-- --------------------------------------------------------
	-- 4b. Royal Jelly (Royal Cells -> integer wallet via fractional accumulator)
	-- --------------------------------------------------------
	local royalJellyRate = computeRoyalJellyPerSecond(profile)
	if royalJellyRate > 0 then
		local progress = (profile.royalJellyProgress or 0) + royalJellyRate * dt
		local whole = math.floor(progress)
		if whole > 0 then
			profile.royalJelly = (profile.royalJelly or 0) + whole
			progress -= whole
		end
		profile.royalJellyProgress = progress
	end
```

**Step 4. Add display-only fields to RatesUpdate.** Append them to the existing payload table, after `queenTier`. Old listeners ignore extra keys, which is the established pattern.

```lua
				royalJellyPerMin = royalJellyRate * 60,
				royalJellyProgress = profile.royalJellyProgress or 0,
				generation = profile.generation or 0,
```

**Step 5. Update the header doc comment.**
- Remove "Royal Cell royal-jelly production" from the bullet that lists it as "OUT of this task's explicit scope ... Not implemented here".
- Add one sentence saying it now lives in step 4b.

The WalletUpdate payload does not change. `royalJelly` is already in it, and whole units show up within 0.5s.

### 4.3 `QueenService` (NEW ModuleScript)

**Location:** `ServerScriptService.Systems.QueenService`

**Header:** `--!strict`, plus a doc comment in the codebase's usual style covering:
- the purpose of the module
- the remote contract
- "the server never moves the queen, see QueenController"

**Requires:**
- `Config`, `DataService`, `PlotService`, `Validator`.
- All are direct requires via `script.Parent:WaitForChild(...)` or `Modules:WaitForChild(...)`. None of these cause a cycle.
- It must **not** require ResourceService, PopulationService or CombService. Those read `profile.queenTier` themselves.

**Remotes:**
- Use a local copy of the `getOrCreateRemotesFolder` / `getOrCreateRemote` idiom, copied verbatim from PopulationService or StructureService.
- Expose it as `QueenService._getRemote`.

**Public API:**

```lua
QueenService.GetTier(profile: any): number
-- math.clamp(math.floor(profile.queenTier or 1), 1, #Config.QUEEN_TIERS)

QueenService.HasUnlock(profile: any, flag: string): boolean
-- true iff any Config.QUEEN_TIERS[i] with i <= GetTier(profile) has row[flag] == true.
-- THE single reader of unlocksNurse/unlocksGoldenComb/unlocksSwarm/unlocksFloor3
-- for every FUTURE consumer (CombService.Upgrade T4 gate, SwarmService.CanSwarm,
-- CombService.UnlockFloor(3)). Unknown flag -> false.

QueenService.GetNextTier(profile: any): (number?, any?)
-- (nextTierIndex, Config.QUEEN_TIERS[nextTierIndex]) or (nil, nil) at max.

QueenService.CanUpgrade(player: Player): (boolean, string?, number?)
-- (ok, reasonIfNot, rjCostIfOk)

QueenService.Upgrade(player: Player): (boolean, string?)
-- Re-validates via CanUpgrade (never trusts a prior check), then applies.

QueenService.Init()
```

**`CanUpgrade` runs these checks in this exact order.** NotifyController toasts the reason strings, so they are written to be readable by kids.

| # | Check | Reason string on failure |
|---|---|---|
| 1 | `DataService.Get(player)` is not nil | `"Your hive is still loading"` |
| 2 | `QUEEN_TIERS[GetTier + 1]` exists | `"Your queen is already the Sun Queen!"` (take the name from `Config.QUEEN_TIERS[#Config.QUEEN_TIERS].name`) |
| 3 | `row.genGate == nil or (profile.generation or 0) >= row.genGate` | `string.format("The %s needs Generation %d -- that comes from Swarming", row.name, row.genGate)` |
| 4 | `(profile.royalJelly or 0) >= row.rj` | `string.format("Not enough Royal Jelly (%d needed, you have %d)", row.rj, math.floor(profile.royalJelly or 0))` |

If every check passes, it returns `true, nil, row.rj`.

**`Upgrade` applies its effects in this exact order:**

```lua
local ok, reason, cost = QueenService.CanUpgrade(player)
if not ok then return false, reason end
local profile = DataService.Get(player) :: any
local fromTier = QueenService.GetTier(profile)
local toTier = fromTier + 1
local row = Config.QUEEN_TIERS[toTier]

profile.royalJelly = (profile.royalJelly or 0) - (cost :: number)
profile.queenTier = toTier

-- Public attribute NOW (don't wait up to 0.5s for ResourceService's tick).
local plotRoot = PlotService.GetPlotForPlayer(player)
local plotIndex = plotRoot and plotRoot:GetAttribute("PlotIndex")
if typeof(plotIndex) == "number" then
	PlotService.PushPublicStats(plotIndex)
end

-- Owner toast (kind "purchase" -> SoundController's SFX_Purchase fires for free).
pcall(function()
	getOrCreateRemote("Notify"):FireClient(player, { kind = "purchase", text = string.format("Your queen is now the %s!", row.name) })
end)
-- Second toast ONLY for unlocks that are actually implemented today.
if row.unlocksNurse then
	pcall(function()
		getOrCreateRemote("Notify"):FireClient(player, { kind = "info", text = "Nurse bees unlocked! Open HIVE > CASTES to add nurses." })
	end)
end

-- Signature Moment 4 -- the WHOLE server watches her grow (public spectacle,
-- same philosophy as the ripeness glow). Tier is already public via the
-- QueenTier attribute, so nothing sensitive is leaked.
if typeof(plotIndex) == "number" then
	pcall(function()
		getOrCreateRemote("Moment"):FireAllClients({
			id = "QueenGrowth",
			plotIndex = plotIndex,
			payload = { fromTier = fromTier, toTier = toTier, ownerUserId = player.UserId },
		})
	end)
end

-- Royal Jelly is the scarcest currency in the game; protect the spend.
-- Save() yields (DataStore) and has its own `saving` overlap guard.
task.spawn(function()
	DataService.Save(player)
end)
return true, nil
```

**Remote handler:**

```lua
local function onRequestQueenUpgrade(player: Player, _payload: any)
	-- architecture.md: RequestQueenUpgrade {} C->S, rate 1/s. The payload is
	-- intentionally IGNORED -- the client sends intent only; tier, cost and
	-- gates are all read server-side from profile + Config.
	if not Validator.RateLimit(player, "RequestQueenUpgrade", Config.QUEEN.upgradeRatePerSecond) then
		return
	end
	local ok, reason = QueenService.Upgrade(player)
	if not ok then
		pcall(function()
			getOrCreateRemote("Notify"):FireClient(player, { kind = "error", text = reason or "Could not upgrade your queen" })
		end)
	end
end
```

**`Init()`:**
1. Use an idempotent `initialized` guard, the same as every other service.
2. Create the `RequestQueenUpgrade`, `Notify` and `Moment` remotes first. Then connect the handler.
3. Run a consistency check. It only warns and never errors:

```lua
for i, row in Config.QUEEN_TIERS do
	if row.unlocksNurse and i ~= (Config.CASTES.nurse.requiresQueenTier or 3) then
		warn(("[QueenService] Config drift: QUEEN_TIERS[%d].unlocksNurse but CASTES.nurse.requiresQueenTier=%s"):format(i, tostring(Config.CASTES.nurse.requiresQueenTier)))
	end
end
```

**Deliberate deviation: the queen is rendered on the client, not by QueenService.**

architecture.md's QueenService paragraph says QueenService "Spawns a Queen model on the comb; a TweenService/CFrame walk cycle". This spec moves all rendering to the client (section 6) instead, for three reasons:
1. The same document's performance contract says "The server **never** moves a bee" and puts all bee motion on pooled client models.
2. Its own QueenService paragraph says the walk is "cosmetic; laying is handled by PopulationService math".
3. A server-tweened model would have two problems:
   - It would replicate a CFrame to every client every frame, for six plots.
   - It would need `ModelStreamingMode = Persistent`, to avoid the stream-out bug that has already hit this project three times (flower patches, comb cells, plot signs).

Client-local clones have neither problem. Every client already knows each plot's tier from the `QueenTier` attribute, and each plot's brood cells from `CombCell` tags.

### 4.4 `Main` (MODIFY): `ServerScriptService.Main`

- Add `local QueenService = require(Systems:WaitForChild("QueenService"))` **directly after** the `ResourceService` require and **before** `StructureService`.
  - This is its true slot in architecture.md's order.
  - Main's own doc comment already predicts it: "When QueenService is built, it should be inserted between ResourceService and StructureService".
- Add `QueenService.Init()` directly after `ResourceService.Init()`.
- Update the doc comment so it no longer describes QueenService as unbuilt.
- No PlayerAdded hook is needed. `PlotService.PushPublicStats` already writes QueenTier after the profile loads.

### 4.5 Hooks this task deliberately does NOT add

- **TutorialService:** the tutorial ends at the first harvest. The Queen is later depth that players discover through the badge (section 8.1). No `TUTORIAL HOOK`.
- **RetentionService:** no queen quest in this version. The day-7 +2 RJ reward becomes meaningful by itself.
- **PopulationService / CombService / PlotService / MonetizationService:** no code changes (see section 10).

---

## 5. RemoteEvents

| Event | Direction | Payload | Server validation | Status |
|---|---|---|---|---|
| `RequestQueenUpgrade` | Client to Server | `{}`. **The contents are ignored.** | `Validator.RateLimit(player, "RequestQueenUpgrade", 1)`; profile is loaded; `queenTier < 5`; `genGate` is met; `royalJelly >= QUEEN_TIERS[tier+1].rj`. Tier, cost and gates all come from server state and Config. | **NEW** (created in QueenService.Init) |
| `Moment` | Server to Client (**FireAllClients** for this id) | `{id = "QueenGrowth", plotIndex:number, payload = {fromTier:number, toTier:number, ownerUserId:number}}` | n/a | existing remote, new id |
| `Notify` | Server to Client | `{kind = "purchase"}` on success, `{kind = "info"}` for the nurse unlock, `{kind = "error"}` on rejection | n/a | existing |
| `RatesUpdate` | Server to Client | adds `royalJellyPerMin:number`, `royalJellyProgress:number (0..1)`, `generation:number` | n/a | existing, additive |
| `WalletUpdate` | Server to Client | unchanged (`royalJelly` is already there and now actually changes) | n/a | existing |

No new Server-to-Client remote is added. The owner's UI confirms success the same way the Castes tab does: it waits for `RatesUpdate.queenTier` to rise, and uses the `QueenGrowth` moment as a faster signal.

---

## 6. Client: `QueenController` (NEW ModuleScript)

**Location:** `StarterPlayer.StarterPlayerScripts.Controllers.QueenController`.
- It must be a **ModuleScript**, not a LocalScript. See the PlotIndicatorController incident.
- `--!strict`, and it ends with `return QueenController`.

**Wiring in ClientMain:**
- Add `local QueenController = require(Controllers:WaitForChild("QueenController"))` and `QueenController.Init()`.
- **Append them after the last existing controller.** Today that is `RetentionController.Init()`, but re-read ClientMain first.
- `Init` must not yield. Do all `WaitForChild` work inside `task.spawn`, as HiveController does.

**Requires:**
- Config and HexGrid (ReplicatedStorage.Modules).
- BuildController, the sibling controller, for `IsOn()`. BuildController does not require QueenController, so there is no cycle.
- TweenService, CollectionService, RunService, Players, Workspace.

### 6.1 Inputs

All of these are already replicated. No new server data is needed.

**Plots:**
- Use `CollectionService:GetTagged("PlotRoot")`, plus `GetInstanceAddedSignal("PlotRoot")` and `GetInstanceRemovedSignal("PlotRoot")`. This is PlotIndicatorController's streaming-resilience pattern. It is needed because PlotRoot is a plain Part and can stream out.
- For each root, read the `PlotIndex`, `OwnerUserId` and `QueenTier` attributes.
- Watch `OwnerUserId` and `QueenTier` with `GetAttributeChangedSignal`.

**Brood nodes:**
- Use `CollectionService:GetTagged("CombCell")`, plus the added and removed signals.
- A model is a Brood node when `PlotIndex == idx`, `Floor == Config.QUEEN.walkFloor` and `CellType == "Brood"`. Its cell comes from the `Q` and `R` attributes.
- Built cells are Persistent, so these reach every client.
- The Dance Floor cell `(0,0)` is always added as an extra "home" node.

**Moment:**
- Listen to `Remotes.Moment.OnClientEvent`.
- Handle only `id == "QueenGrowth"`.

### 6.2 Geometry

Use this exact formula. Do not re-derive it.

```lua
local function latticeOrigin(plotRoot: BasePart): Vector3
	return Vector3.new(plotRoot.Position.X, 0, plotRoot.Position.Z + Config.QUEEN.latticeZOffset)
end
local function cellPivot(plotRoot: BasePart, q: number, r: number): Vector3
	return HexGrid.ToWorld(q, r, latticeOrigin(plotRoot), Config.FLOOR_Y[Config.QUEEN.walkFloor] + Config.QUEEN.walkHeightAboveFloorY)
end
```

For Plot1 and cell (0,0), this gives (-325, 10.6, 6). The verification list in section 12 checks the 6-stud offset against `DanceFloorCentrePlate`.

### 6.3 Which queens are rendered (LOD)

**A plot's queen is rendered only when both of these are true:**
- `OwnerUserId ~= 0`
- AND either it is the local player's own plot, or the local character's HumanoidRootPart is within `renderRadiusStuds` of the PlotRoot.

Re-check this every `lodCheckSeconds`, using an accumulator inside the Heartbeat from 6.4. Do not start a separate loop.

**Spawn:**
- Clone `ReplicatedStorage.Templates.Queens[VISUALS[tier].template]`.
- Parent it to `Workspace.ClientFX.Queens`. Create `Workspace.ClientFX` and `Queens` on the client if they are missing. architecture.md names `Workspace/ClientFX` as the runtime client-only folder.
- Start her at `cellPivot(0,0)`, facing -Z.

**Despawn** when the owner changes, when the PlotRoot streams out, or when the plot leaves LOD:
- destroy the model
- clear its state
- **restore any lights that a running growth has dimmed** (see 6.6)

**When the tier attribute changes without a moment:**
- If `growthState[plotIndex]` is active, ignore the change. The moment handles the model swap.
- Otherwise, `task.delay(0.3)`, re-check, then **snap-swap**: spawn the new template at the old model's pivot and keep the walk state.
- This covers three cases:
  - joins, where the tier jumps from 1 to N on load
  - leaves, where it resets to 1
  - upgrades that happened while the plot was outside LOD

### 6.4 Walk: one Heartbeat, one state machine per queen

QueenController owns **exactly one** `RunService.Heartbeat` connection.
- It connects when the first queen is rendered.
- It disconnects when no queens are rendered.
- This follows ResourceService's precedent: one single connection, never a `while true` loop.

Each queen is in one of three states:

```
Walking { fromPos, toPos, fromCell, toCell, t, duration }
  -> on arrival: flash(toCell); if toCell is the target Brood node -> Laying
Laying  { untilClock }   -- pauseSeconds, with a dip of layDipStuds down and back over layDipSeconds each way
  -> pick next target -> Walking
Growing                  -- frozen; 6.6 drives the model
```

**Choosing the next target:**
- Pick a random Brood node that is not the one she is on.
- If the plot has no other Brood node, she paces between `(0,0)` and a random ring-1 neighbour that is inside the lattice.

**Path: she moves cell to cell, so she visibly crosses the comb.**
1. From the current cell, step to the neighbour (from `HexGrid.Neighbours`) that is closest to the target.
   - Measure hex distance between two cells as `HexGrid.HexDistance(q1 - q2, r1 - r2)`. Axial distance does not change when you shift both cells, so this works.
   - Only step to cells where `HexGrid.InLattice(q, r, Config.FLOOR_RADIUS[walkFloor])` is true.
2. Each step is one Walking segment, with `duration = (toPos - fromPos).Magnitude / VISUALS[tier].walkSpeed`.
3. Face with `CFrame.lookAt(fromPos, toPos)`, lerp the position, and apply it with `model:PivotTo(...)`.

**Attendants (tier 4 and 5):**
- Each frame, set `attendant:PivotTo(queenPivot * CFrame.Angles(0, clock * attendantOrbitRadPerSec + phase, 0) * CFrame.new(orbitRadius, attendantHeight, 0))`.
- Use phase 0 for one attendant and pi for the other.

**Collision:**
- The queen and all her parts have `CanCollide`, `CanQuery` and `CanTouch` set to false.
- She wades through full honey domes (up to Y 12.9). This is intended; it reads as walking through honey.

### 6.5 Amber footprints

architecture.md says: "Cells flash amber for 0.6s as she passes".

**Pool:** client parts under `Workspace.ClientFX.QueenFX`. Keep 3 per rendered queen, or 10 for a Sun Queen.

**Disc spec:**
- Part with `Shape = Cylinder` and `Size = (0.2, 12, 12)`.
- `CFrame = CFrame.new(cellCentre) * CFrame.Angles(0, 0, math.rad(90))`, so it lies flat.
- `Material = Neon`, `Color = #F2A81C`.
- Anchored; `CanCollide`, `CanQuery` and `CanTouch` all false; `CastShadow = false`.
- Centre Y is `Config.FLOOR_Y[walkFloor] + flashHeightAboveFloorY`. X and Z use the formula from 6.2.

**Flash:** tween Transparency from `cellFlashStartTransparency` (0.45) to 1 over `cellFlashSeconds` (TweenService, Quad Out). Then return the disc to the pool.

**Sun Queen ripple:** `rippleDelaySeconds` after she arrives on a new cell, flash each ring-1 neighbour (inside the lattice) of the cell she just left. Stagger them by `rippleStaggerSeconds`. This is architecture.md's "the comb ripples gold in a 2-cell radius behind her".

### 6.6 `QueenGrowth` moment choreography (architecture.md Signature Moment 4)

**Before starting:**
- Validate the payload: `plotIndex`, `payload.fromTier`, `payload.toTier` and `payload.ownerUserId` must all be numbers, and `toTier` must be in 1..#VISUALS.
- If that plot's queen is not rendered, do nothing. The attribute path will snap her to the new tier if she comes into range later.
- If a growth is already running on that plot, store `queuedToTier` and run it when the current growth finishes.

**Timeline:**

| Time (s) | What happens |
|---|---|
| 0.0 | Set state to Growing, so she stops. Capture every `PointLight` under the plot's `Comb` folder (`plotRoot.Parent:FindFirstChild("Comb")`, all descendants) and store `{light, originalBrightness}`. Tween each light to `original * dimTo` over `dimSeconds / 2`. |
| 0.5 | Spawn the new tier template at the old pivot and destroy the old model. Call `newModel:ScaleTo(oldBodyLength / newBodyLength)`. Then tween a NumberValue from that ratio to 1 over `growSeconds` (Back, Out), with its `Changed` event calling `newModel:ScaleTo(v)`. |
| 1.7 | Call `QueenRoot.GrowthBurst:Emit(burstCount)`. Tween the lights to `original * relightPeak` over `relightSeconds`, then back to `original` over `settleSeconds`. |
| 1.7 + holdSeconds | Return to Walking and pick a new target. If a tier was queued, start the next growth instead. |

**Cancel safety:**
- If the queen despawns or streams out mid-growth, immediately set every captured light back to its exact `originalBrightness` and clear the growth state.
- The lights are server-owned instances. The client only overrides its own local view of them.
- CombService writes their Brightness only at build and render time, so restoring the captured value is correct.

**Owner camera.** It runs only if all three are true:
- `payload.ownerUserId == Players.LocalPlayer.UserId`
- `not BuildController.IsOn()`
- the character is within `camera.maxDistanceStuds` of the queen

It mirrors `DanceController.playFirstWaggleCamera` exactly:
1. Save `camera.CFrame` and set `CameraType = Scriptable`.
2. Tween over `inSeconds` to `CFrame.lookAt(queenPos + Vector3.new(0, upStuds, -backStuds), queenPos)`. -Z is the front of the plot, where the ramp is and where players approach from.
3. Hold until the growth ends plus `holdSeconds`.
4. Tween back over `outSeconds`. Then set `CameraType = Custom`, but only if it is still Scriptable.

No other client's camera moves.

---

## 7. Queen templates (world-builder): `ReplicatedStorage.Templates.Queens`

Create a new Folder `Queens` holding 5 Models, `Queen_T1` through `Queen_T5`.
- **They live only in ReplicatedStorage and are never placed in Workspace**, so they cost 0 server parts.
- Client worst case: at most 13 parts per queen, plus the pooled flash discs, and only for plots within 250 studs.

### Rules for every template

**Root and pivot:**
- `PrimaryPart = QueenRoot`: a 1x1x1 Part with `Transparency = 1`.
- It sits at the pivot point: where the body touches the floor, under the thorax.
- Its `LookVector` is the forward direction. The head points toward -Z of the root.

**Every BasePart:**
- `Anchored = true`
- `CanCollide = false`, `CanQuery = false`, `CanTouch = false`
- `Massless = true`
- Wings also get `CastShadow = false`.

**No scripts inside the templates.**

**Growth burst emitter.** `QueenRoot` contains a `ParticleEmitter` named **`GrowthBurst`** with:
- `Enabled = false`, `Rate = 0` (so it costs 0 particles per second at rest)
- Color `#F2A81C` to `#FFE9A8`, `LightEmission = 0.3`
- Size keypoints 0.6 to 0
- `Lifetime = 0.8..1.2`, `Speed = 8..14`, `SpreadAngle = (180, 180)`
- Transparency keypoints 0 to 1

**Queen light (tiers 4 and 5 only).** A `PointLight` named **`QueenLight`** inside `Thorax`:
- Color `#FFE9A8`, `Range = 22`
- `Brightness = 0.9` for T4, `1.6` for T5
- `Shadows = false`. The shadow budget is 24 lights per plot, and those belong to the cells.
- This is architecture.md's Lighting brief entry "Queen Q4/Q5".

**Ellipsoid abdomen.** Build it as a Part with a `SpecialMesh` (`MeshType = Sphere`, `Scale = (1, 1, 1)`). The mesh fills the part's box. This is a built-in primitive, not an imported asset.

**Length contract.** Nose-to-tail length must equal `Config.QUEEN.VISUALS[n].bodyLength` within +/-0.3 studs. QueenController's growth ratio depends on it.

**Palette** (the art-direction rule is: no colours outside the palette):

| Use | Colour | Material and notes |
|---|---|---|
| Head and thorax | Propolis Brown `#7A4A22` | SmoothPlastic |
| Fertile abdomen | Honey Gold `#F2A81C` | SmoothPlastic (Glass for T4/T5) |
| Virgin abdomen and the **wax** crown | Wax Cream `#E8D49A` | SmoothPlastic. "SmoothPlastic cream = wax, the player built this." |
| Wings | Pollen Haze `#FCEFC6` | Glass, `Transparency = 0.45` |
| Sun Queen halo only | Pollen Haze `#FCEFC6` | **Neon.** "Neon = value at maximum." |

### Part lists per tier

Offsets are relative to the QueenRoot pivot, written as (X, Y, Z). -Z is forward. Sizes are in studs.

**Queen_T1 "Virgin Queen"** (length 5.0; "small, pale, walks fast"). 6 parts:

| Part | Shape | Size | Offset | Material and colour |
|---|---|---|---|---|
| QueenRoot | Block | 1, 1, 1 | 0, 0, 0 | invisible |
| Head | Ball | 1.3 | 0, 1.2, -1.85 | SmoothPlastic #7A4A22 |
| Thorax | Ball | 1.6 | 0, 1.3, -0.7 | SmoothPlastic #7A4A22 |
| Abdomen | Block + SpecialMesh Sphere | 1.5, 1.4, 2.6 | 0, 1.2, 1.15 | SmoothPlastic #E8D49A |
| WingL and WingR | Block | 1.8, 0.1, 2.4 | +/-0.95, 2.05, 0.1, rotated Z +/-15 deg | Glass #FCEFC6, Transparency 0.45 |

**Queen_T2 "Laying Queen"** (length 5.5; "longer abdomen, gold banding"). 7 parts. Start from T1, then:
- **Abdomen:** size `1.6, 1.5, 3.1` at `0, 1.25, 1.4`, Honey Gold #F2A81C.
- **Add AbdomenBand:** a Cylinder with its axis along Z (rotated Y 90 deg), size `0.5, 1.7, 1.7`, at `0, 1.25, 1.2`, SmoothPlastic #7A4A22.

**Queen_T3 "Crowned Queen"** (length 6.0; "wax crown, slower regal walk"). 8 parts. Start from T2, then:
- **Abdomen:** size `1.7, 1.6, 3.5` at `0, 1.3, 1.6`.
- **AbdomenBand:** move to `0, 1.3, 1.35` with size `0.5, 1.8, 1.8`.
- **Add Crown:** a Cylinder with a vertical axis (rotated Z 90 deg), size `0.5, 1.2, 1.2`, at `0, 2.05, -1.9`, SmoothPlastic #E8D49A.

**Queen_T4 "Matriarch"** (length 9.0; "1.8x size, amber glow, attendant bees orbit her"). 12 parts:
- Start from T3 and scale every size and offset by 1.5.
- Change the Abdomen to **Glass #F2A81C with Transparency 0.15**. Glass means honey, so this is the amber glow.
- Add `QueenLight` (Brightness 0.9) inside Thorax.
- Add two sub-Models, **`AttendantA`** and **`AttendantB`**. Each has 2 parts:
  - `Body`: Ball 1.0, SmoothPlastic #F2A81C.
  - `Wings`: Block 1.2 x 0.1 x 0.6, Glass #FCEFC6 with Transparency 0.45, placed 0.45 studs above Body.
  - Each sub-Model has `PrimaryPart = Body`.
  - Author them at `(+/-4.5, 2.5, 0)`. QueenController repositions them every frame.

**Queen_T5 "Sun Queen"** (length 12.5; "2.5x size, sun halo, comb ripples gold behind her"). 13 parts:
- Start from T3 and scale everything by 12.5 / 6.0 (about 2.083). Use the Glass amber abdomen, as in T4.
- Add `QueenLight` (Brightness 1.6).
- Add `AttendantA` and `AttendantB` as in T4, authored at `(+/-7, 2.5, 0)`.
- **Add Halo:** a Cylinder with its axis along Z, so it is a vertical disc facing forward.
  - Size `0.2, 5.5, 5.5`.
  - Centred 1.6 studs above and 0.6 studs behind the head centre.
  - Neon #FCEFC6, Transparency 0.5, `CastShadow = false`.

### Primitives first

Build these from primitives. The parts are small and must be precise, and this project has already rejected generated meshes for small precise geometry (GoldenCell, cell rims).

If world-builder wants to try a mesh for the Abdomen, it must:
- keep the part names exactly
- keep the pivot contract exactly
- keep `bodyLength` exactly
- fall back to the primitive if there is any doubt

---

## 8. HiveGui QUEEN tab

luau-scripter builds the working UI. ui-designer polishes it afterward.

### 8.1 Hierarchy

**What to edit:** `StarterGui.HiveGui.Panel.Pages.QueenPage.Card`, in Edit mode.
- **Keep:** `Card` itself, its `UICorner`, `UIStroke` and `UIGradient`, and the `Header` TextLabel. The controller sets Header's text to "YOUR QUEEN".
- **Delete:** `Body`.
- **Add:** the elements in the tree below.

**Rules for every new element:**
- Size with Scale only, zero Offset. The project-wide audit found 0 Offset sizes across 240 GUI elements; keep it that way.
- Every TextLabel and TextButton gets:
  - `Font = FredokaOne`, `TextScaled = true`, `TextWrapped = true`
  - a `UITextSizeConstraint` with `MinTextSize = 14` and `MaxTextSize = 28`

```
QueenPage (Frame, existing)
  Card (Frame, existing)
    Header (TextLabel, existing)            Size(0.9,0,0.12,0)  Pos(0.5,0,0.03,0)  Anchor(0.5,0)
    PortraitFrame (Frame)                   Size(0.34,0,0.48,0) Pos(0.04,0,0.17,0) Anchor(0,0)   BG #FCEFC6, UICorner(0.08,0)
      QueenViewport (ViewportFrame)         Size(1,0,1,0)       BackgroundTransparency 1, Ambient #8A7A5A, LightColor #FFE9A8, LightDirection (-1,-1,-1)
      TierBadge (TextLabel)                 Size(0.9,0,0.16,0)  Pos(0.5,0,0.97,0)  Anchor(0.5,1)  "TIER 1 / 5"
    InfoFrame (Frame)                       Size(0.56,0,0.48,0) Pos(0.40,0,0.17,0) Anchor(0,0)   BackgroundTransparency 1
      UIListLayout                          FillDirection Vertical, SortOrder LayoutOrder, Padding UDim(0.015,0)
      NameLabel (TextLabel)    LayoutOrder 1 Size(1,0,0.20,0)  "Virgin Queen"
      NextLabel (TextLabel)    LayoutOrder 2 Size(1,0,0.14,0)  "NEXT: Laying Queen"
      LayLabel (TextLabel)     LayoutOrder 3 Size(1,0,0.19,0)  "New bee every 12.0s -> 8.0s"
      OutputLabel (TextLabel)  LayoutOrder 4 Size(1,0,0.19,0)  "Honey x1.00 -> x1.15"
      UnlockLabel (TextLabel)  LayoutOrder 5 Size(1,0,0.19,0)  "Lays eggs faster!"
    JellyFrame (Frame)                      Size(0.92,0,0.10,0) Pos(0.5,0,0.67,0)  Anchor(0.5,0)  BackgroundTransparency 1
      JellyLabel (TextLabel)                Size(0.60,0,1,0)    Pos(0,0,0,0)       "Royal Jelly: 3 / 5"
      JellyBar (Frame)                      Size(0.38,0,0.5,0)  Pos(1,0,0.5,0)     Anchor(1,0.5)  BG #8E8A7A, UICorner(0.5,0)
        JellyFill (Frame)                   Size(0,0,1,0)       BG #F2A81C, UICorner(0.5,0)
    HintLabel (TextLabel)                   Size(0.92,0,0.06,0) Pos(0.5,0,0.775,0) Anchor(0.5,0) TextColor #7A4A22
    UpgradeButton (TextButton)              Size(0.5,0,0.13,0)  Pos(0.5,0,0.84,0)  Anchor(0.5,0)  "UPGRADE QUEEN", UICorner, UIStroke #7A4A22
```

**Vertical layout of Card** (from 0 at the top to 1 at the bottom):

| Element | From | To |
|---|---|---|
| Header | 0.03 | 0.15 |
| Portrait and Info | 0.17 | 0.65 |
| Jelly | 0.67 | 0.77 |
| Hint | 0.775 | 0.835 |
| Button | 0.84 | 0.97 |

Nothing overlaps.

**Button size on a phone:**
- Pages is 0.765 of the Panel, and the Panel is 0.94 of screen height, so the Card is about 0.72 of screen height.
- The button (0.13 of the Card) is therefore about 0.094 of screen height, roughly 70 px on a 750 px phone.
- That clears the 44 px minimum.

**Discovery badges.** Kids do not open tabs unprompted, so these badges are how players find the feature:

```
HiveGui.HiveButton
  QueenBadge (Frame)   Size(0.3,0,0.3,0) Pos(0.95,0,0.08,0) Anchor(0.5,0.5), UIAspectRatioConstraint(1), UICorner(1,0), BG #F2A81C, UIStroke #7A4A22, Visible=false, ZIndex above button
    BadgeText (TextLabel) Size(1,0,1,0) "!" TextColor #7A4A22, BackgroundTransparency 1
HiveGui.Panel.Tabs.QueenTab
  QueenTabBadge (Frame) same spec, Size(0.22,0,0.22,0) relative to the tab, Pos(0.92,0,0.12,0), Visible=false
    BadgeText (TextLabel) "!"
```

**When the badges show:** both are visible **only when** the upgrade is affordable right now. That means all of these are true:
- not at max tier
- not blocked by `genGate`
- `royalJelly >= cost`
- no upgrade is pending

They are Honey Gold because they mean reward, not danger. Alarm Red is reserved for threats.

### 8.2 States (HiveController `renderQueen()`)

Definitions used below: `tier = queenTier`, `nextRow = QUEEN_TIERS[tier + 1]`, `cur = QUEEN_TIERS[tier]`.

**Header, TierBadge and NameLabel** are the same in every state:
- Header: "YOUR QUEEN"
- TierBadge: `"TIER %d / %d"`
- NameLabel: `cur.name`

**The other labels, when there is a next tier:**

| Element | What it shows |
|---|---|
| NextLabel | `"NEXT: " .. nextRow.name` |
| LayLabel | `string.format("New bee every %.1fs -> %.1fs", cur.layInterval, nextRow.layInterval)` |
| OutputLabel | `string.format("Honey x%.2f -> x%.2f", cur.outputMult, nextRow.outputMult)` |
| UnlockLabel | Depends on the next row (see below). |
| JellyLabel | `string.format("Royal Jelly: %d / %d", rj, nextRow.rj)` |
| JellyFill.Size | `UDim2.new(math.clamp(rj / nextRow.rj, 0, 1), 0, 1, 0)` |
| HintLabel | Depends on the jelly rate (see below). |

**The other labels, at max tier (5):**

| Element | What it shows |
|---|---|
| NextLabel | "The greatest queen in the garden!" |
| LayLabel | `string.format("New bee every %.1fs", cur.layInterval)` |
| OutputLabel | `string.format("Honey x%.2f", cur.outputMult)` |
| UnlockLabel | "" (empty) |
| JellyLabel | `string.format("Royal Jelly: %d", rj)` |
| JellyFill.Size | full bar |
| HintLabel | "Save your Royal Jelly -- perks are coming soon!" |

**UnlockLabel text**, based on the flags of the next row:

| Next row has | Text |
|---|---|
| `unlocksNurse` | "NEW: Nurse bees!" |
| `unlocksGoldenComb` or `unlocksSwarm` | "NEW: Golden Comb + Swarming (coming soon)" |
| `unlocksFloor3` | "NEW: Crown Comb floor (coming soon)" |
| no unlock flag | "Lays eggs faster!" |

If `nextRow.genGate` is not met, **override** all of these with `"Needs Generation %d (Swarming - coming soon)"`.

**HintLabel text:**
- If `royalJellyPerMin <= 0`: "Build a ROYAL cell on the edge, touching BROOD cells, to make Royal Jelly!"
- Otherwise: `string.format("Your Royal Cells make %s jelly per minute", perMin >= 0.1 and string.format("%.1f", perMin) or string.format("%.2f", perMin))`
- After a failed or timed-out submit: "Not upgraded - try again", in Alarm Red #D8452B.

**UpgradeButton.** Use the first row that matches:

| Condition | Text | Background |
|---|---|---|
| no RatesUpdate received yet | "..." | Dormant Grey #8E8A7A |
| an upgrade is pending | "CROWNING..." | Dormant Grey |
| max tier | "MAX QUEEN" | Dormant Grey |
| `genGate` not met | `"NEEDS GEN %d"` | Dormant Grey |
| `rj < cost` | `"NEED %d MORE JELLY"` (cost - rj) | Dormant Grey |
| otherwise | "UPGRADE QUEEN" | Honey Gold #F2A81C, text Propolis Brown #7A4A22 (the proven 5.06:1 contrast pair) |

**Portrait.** Rebuild it only when the tier changes, not on every render:
1. Clear the viewport's children.
2. Clone `Templates.Queens[VISUALS[tier].template]` into `QueenViewport` and call `PivotTo(CFrame.new())`.
3. Create or reuse a `Camera` child and set it as `QueenViewport.CurrentCamera`.
4. Set `FieldOfView = 40` and `CFrame = CFrame.lookAt(Vector3.new(L*0.9, L*0.6, -L*1.1), Vector3.new(0, L*0.2, 0))`, where `L = VISUALS[tier].bodyLength`.

The portrait is static. A turntable is optional polish for ui-designer, and it must not use a per-frame loop.

### 8.3 UI flow

1. The player sees a gold "!" on the HIVE button. The badge shows whenever the upgrade is affordable.
2. They tap HIVE. The panel opens on CASTES, and there is a gold "!" on the QUEEN tab.
3. They tap QUEEN. They see her portrait, what she will become, a full jelly bar, and a gold "UPGRADE QUEEN" button.
4. They tap UPGRADE QUEEN.
   - `RequestQueenUpgrade:FireServer({})` fires.
   - A 1.1s client cooldown starts.
   - The button shows "CROWNING...".
5. **On success**, meaning either the `QueenGrowth` moment arrives with `payload.ownerUserId == LocalPlayer.UserId`, or `RatesUpdate.queenTier > tierAtSubmit` (whichever comes first):
   - The pending state clears.
   - **HiveController closes the panel** (`setOpen(false)`), so the player actually sees her grow.
   - The purchase toast and sound play. NotifyController and SoundController already handle these.
   - QueenController plays the growth and the camera move.
6. **On failure:**
   - `Notify{kind="error"}` arrives, and NotifyController shows it as a toast.
   - The pending state clears and the Alarm Red hint appears.
   - If there is no confirmation within 3.5s, the same "Not upgraded - try again" hint appears.

### 8.4 `HiveController` (MODIFY)

**Location:** `StarterPlayer.StarterPlayerScripts.Controllers.HiveController`

These are surgical changes. Castes behaviour must not change.

**1. Doc comment.**
- Replace the bullet "QUEEN / PERKS tabs -- honest 'coming soon' pages..." with a description of the QUEEN tab and the `RequestQueenUpgrade` contract: the client fires `{}`, the server validates everything, success is signalled by the QueenGrowth moment or a RatesUpdate.queenTier rise, and failure by a Notify error.
- The PERKS bullet stays "coming soon".

**2. New module state:**
- `royalJelly: number? = nil`, `royalJellyPerMin = 0`, `generation = 0`
- `queenPending = false`, `queenPendingTier = 0`, `queenPendingStamp = 0`
- `lastQueenSubmitAt = -math.huge`, `queenNotUpgradedNotice = false`, `portraitTier = 0`
- UI references for every element in 8.1
- `requestQueenUpgrade: RemoteEvent? = nil`
- `setOpenRef: ((boolean) -> ())? = nil`. Hoist `setOpen` into this so the moment listener can call it.

**3. `onRatesUpdate`:**
- Also read `royalJellyPerMin` and `generation` when `typeof == "number"`.
- If `queenPending` and `payload.queenTier > queenPendingTier`: clear pending and call `setOpenRef(false)`.

**4. New `onWalletUpdate(payload)`:** set `royalJelly = payload.royalJelly` if it is a number, then call `render()`.

**5. New `onMoment(payload)`:** if `payload.id == "QueenGrowth"` and `payload.payload.ownerUserId == Players.LocalPlayer.UserId`, then clear pending, clear the notice, and call `setOpenRef(false)`.

**6. `onNotify`:**
- Keep the existing castes logic.
- **Also:** if `queenPending` and `os.clock() - queenPendingStamp < 3.5`, clear pending and set `queenNotUpgradedNotice = true`.

**7. `render()`:**
- Delete the whole `if queenBody then ... end` block, including its "Queen upgrades are not in the game yet." string.
- Call the new `renderQueen()` instead. It implements the tables in 8.2, the portrait swap, and badge visibility.

**8. New `submitQueenUpgrade()`:**
- Guard conditions, all required:
  - `requestQueenUpgrade` is present
  - the upgrade is affordable (the same check the badge uses)
  - no upgrade is pending
  - `os.clock() - lastQueenSubmitAt >= 1.1`
- Then:
  1. Set pending, set `queenPendingTier = queenTier`, and record the timestamp.
  2. Fire `{}` and call `render()`.
  3. Arm `task.delay(3.5, ...)` for the timeout, and `task.delay(1.15, render)`.

**9. `Init()`:**
- Resolve the references to the new QueenPage elements.
  - **If any is missing, `warn` and disable only the queen section.** The castes panel must keep working. Today a missing child disables the whole panel; do not extend that behaviour to this new section.
- Connect `UpgradeButton.MouseButton1Click` to `submitQueenUpgrade`.
- In the existing `task.spawn` block, add `WaitForChild` for:
  - `"RequestQueenUpgrade"` (QueenService.Init creates it when the server boots)
  - `"WalletUpdate"`, and connect `onWalletUpdate`
  - `"Moment"`, and connect `onMoment`

**10. Remove** the now-unused `queenBody` variable.

### 8.5 Style notes for ui-designer (visual properties only)

- **House style:** use the Warm Wax style HiveGui already has.
  - Cream Card, Propolis Brown text and strokes, FredokaOne.
  - Buttons with thick outlines, hard shadows and a bouncy feel, using the existing UIAnimations pattern.
  - Animate only UIScale and UIStroke, **never BackgroundColor3**, because HiveController owns the button colours.
- **Fix this contrast bug:** the existing `QueenPage.Card.Header` uses Honey Gold `#F2A81C` text on a cream card. That is about 1.5:1 contrast, the same bug fixed earlier in BuildGui. Either make the Header Propolis Brown, or keep it gold with a thick Propolis stroke.
- **Portrait frame:** it should read as "her chamber". Use a Pollen Haze fill with a warm inner glow gradient.
- **Overall tone:** the QUEEN tab must feel regal, not like a settings menu. It is the only page in the game about a *character*.

---

## 9. Text fixes (luau-scripter)

**1. `BuildController`, `CELL_DESCRIPTIONS.Royal`.**
- Replace it with:
  `"A Queen's cell for the outer edge of your comb. It makes Royal Jelly for every Brood Cell touching it -- spend jelly in HIVE > QUEEN to upgrade your queen!"`
- Also update the doc comment above `CELL_DESCRIPTIONS`. It says Royal Cell production is "confirmed NOT yet implemented anywhere"; point it at ResourceService step 4b instead.

**2. `StarterGui.HelpGui.HelpPanel.ContentScroll.Section7.Body`.** Set its Text to:
`"The Shop and Hive buttons are ready -- look on the left side of your screen! Build Royal cells touching Brood cells to make Royal Jelly, then upgrade your Queen in HIVE > QUEEN. Still coming soon: perks, taller comb floors, swarming, and dangers in the treeline. Stay tuned!"`

**3. `PerksPage`:** no change. Its text is still accurate.

---

## 10. How this interacts with existing systems

| System | Changed? | Details and edge cases |
|---|---|---|
| **ResourceService** | YES, modified (4.2) | `queenMult` code is unchanged and picks up the new tier on the next tick. Royal Jelly production is added. Demolishing a Royal or Brood cell lowers the rate on the next tick. Pollen, honey and ripeness logic are untouched. |
| **PopulationService** | read only, NO code change | `HatchInterval` reads the new `layInterval` on the next `HatchTick`. The hatch accumulator is not reset, so the first bee after an upgrade may arrive early; this is harmless and feels good. The Nurse gate opens automatically at tier 3. `population.nurse` feeds the Royal Jelly nurse bonus once nurses hatch. |
| **PlotService** | called, NOT modified | `Upgrade` calls `PushPublicStats` so the attribute updates immediately. `ReleasePlot` resets `QueenTier = 1` and `OwnerUserId = 0`, and QueenController despawns the queen when the owner changes. |
| **CombService** | NO change | Royal build rules (rim only, 2,500 honey + 60 propolis, rim test via `HexGrid.IsRim`) are unchanged. `RenderPlot` restores Royal and Brood cells on join; these are both the Royal Jelly inputs and the queen's walk nodes. `Harvest` does not touch Royal Jelly. |
| **DataService** | YES (MIGRATIONS[3], 3.2) | Template version becomes 4. `Save` is called asynchronously after an upgrade. A `dataFailed` profile still upgrades in memory and `Save` does nothing, which is the same as every other purchase. |
| **MonetizationService** | NO change | `RoyalJellyPackSmall` grants a whole number of RJ, so it stays consistent with the accumulator. It becomes meaningful once a real product id is configured. |
| **RetentionService** | NO change | The day-7 +2 RJ reward now has a use. |
| **TutorialService** | NO change | Deliberately none (4.5). |
| **DanceService / DanceController** | NO change | They share the `Moment` remote. DanceController's `onMoment` only handles `"FirstWaggle"` (verified). |
| **HudController** | NO change | JellyChip shows the integer `royalJelly` through FormatNumber. It stays correct because the accumulator keeps `royalJelly` a whole number. |
| **SoundController** | NO change | `Notify kind "purchase"` already plays `SFX_Purchase` (verified). |
| **NotifyController** | NO change | It already toasts `purchase`, `info` and `error`. |
| **BuildController** | text only (section 9) | QueenController reads `IsOn()` to skip the camera move during Build Mode, because Build Mode owns a Scriptable camera. |
| **ShopController, MonetizationController, PlotIndicatorController, TutorialController, RetentionController** | NO change | HiveGui's VipTab and VipPage are untouched. HiveController's tab switcher already includes QueenTab and QueenPage. |
| **Streaming** (StreamingEnabled = true) | handled | Queens and flash discs are client-local and never stream. PlotRoot streaming out and back in is handled with tag signals. CombCell models are Persistent. |
| **Threats, Swarm, extra Floors, Golden Comb** | none of these exist | The `unlocks*` flags stay inert. `QueenService.HasUnlock` is the hook for later. The UI says "coming soon". |
| **Team Create / live user** | process rule | Build in Edit mode only. Re-read every script before editing it. Never touch Plot 1's owner or data during tests. |

**Edge cases that happen mid-flow:**
- **Two upgrades within about 3 seconds** (the player has enough RJ for two steps):
  - The server rate limit allows one per second.
  - On the client, the second moment waits in the queue until the first growth finishes, then plays.
- **Upgrade while the owner is far away or in Build Mode:**
  - The growth plays for anyone who is rendering that plot.
  - The owner gets no camera move, but still gets the toast.
- **Owner leaves mid-growth:** QueenController despawns the queen and restores the captured light brightness.
- **Upgrade from somewhere other than the button (for example a keyboard shortcut):** not possible. The button is the only caller.
- **Garbage payload from the client:** it is ignored entirely.

---

## 11. Build order

**Step 0. Pre-flight (Game Master).** [DONE -- see 1e.1: duplicate DataService resolved before dispatch.]
- Confirm `RunService:IsRunning() == false`.
- Resolve the duplicate `Systems.DataService` (see 1e.1).
- Tell any other in-flight agents not to edit Config, DataService, ResourceService, Main, ClientMain or HiveController at the same time.

**Step 1. Config (3.1) and DataService MIGRATIONS[3] (3.2).**
- Everything downstream reads these, so they go first.
- Watch out for require-cache staleness: in a long Studio session, a fresh `require` of Config can return the pre-edit table.
  - Verify by `loadstring`-ing `Config.Source`, or use the established clone-and-replace trick.
  - If you clone and replace, **destroy the replaced instance** so you do not create another duplicate like 1e.1.

**Step 2. ResourceService Royal Jelly production and RatesUpdate fields (4.2).** This is the income source and the functional core.

**Step 3. QueenService and Main wiring (4.3, 4.4).** This is the purchase entry point.

**Step 4. Queen templates, by world-builder (7).** This can run **in parallel with steps 2 and 3**, because they touch no shared files.

**Step 5. QueenController and ClientMain wiring (6).** Depends on steps 1 and 4.

**Step 6. HiveGui QueenPage hierarchy, badges, and HiveController changes (8).** Depends on steps 1, 3 and 4 (the portrait uses the templates).

**Step 7. Text fixes (9).**

**Step 8. Review and test, in this order:**
1. luau-reviewer
2. ui-designer polish (8.5)
3. roblox-playtester
4. a live play-test using the scenario in section 12

---

## 12. Verification checklist (Game Master, through MCP)

### Static checks (Edit mode)

- [ ] **Config** (use a fresh `loadstring` of Source):
  - `Config.QUEEN_TIERS[5].genGate == 1`
  - `Config.QUEEN.VISUALS` has 5 rows
  - `PROFILE_TEMPLATE.version == 4` and `royalJellyProgress == 0`
- [ ] **DataService:** `MIGRATIONS[3]` exists and sets the version to 4. There is **exactly one** `Systems.DataService`.
- [ ] **ResourceService** source contains:
  - `computeRoyalJellyPerSecond`
  - the `4b. Royal Jelly` step, after `HatchTick` and before the WalletUpdate fire
  - the RatesUpdate fields `royalJellyPerMin`, `royalJellyProgress` and `generation`
- [ ] **QueenService:**
  - `Systems.QueenService` is a ModuleScript and compiles.
  - It exposes `GetTier`, `HasUnlock`, `GetNextTier`, `CanUpgrade`, `Upgrade`, `Init` and `_getRemote`.
  - `Main` requires it between ResourceService and StructureService and calls `Init()`.
- [ ] **QueenController:** `Controllers.QueenController` is a **ModuleScript** and compiles. ClientMain requires it and calls `Init()`.
- [ ] **Templates:**
  - `Templates.Queens` has 5 Models.
  - Each has `PrimaryPart == QueenRoot` and `QueenRoot.GrowthBurst` with `Enabled = false` and `Rate = 0`.
  - All parts are Anchored, with CanCollide, CanQuery and CanTouch set to false.
  - T4 and T5 have `Thorax.QueenLight` and `AttendantA` / `AttendantB`. T5 has `Halo`.
  - The measured Z length matches `bodyLength` within +/-0.3.
  - Part counts are 6, 7, 8, 12 and 13.
- [ ] **QueenPage:**
  - `QueenPage.Card` contains every element from 8.1, and no `Body`.
  - It has 0 Offset sizes.
  - Every TextLabel and TextButton has a UITextSizeConstraint with a minimum of 14.
  - `HiveButton.QueenBadge` and `QueenTab.QueenTabBadge` exist with `Visible = false`.
- [ ] **Text:**
  - The Royal text in `BuildController` and the Section7 text in `HelpGui` are updated.
  - No string anywhere in the game still says "Queen upgrades are not in the game yet", or lists "the Queen, Royal Jelly" as coming soon.
- [ ] **Offset check:** Plot1's `DanceFloorCentrePlate` X and Z equal the X and Z of `HexGrid.ToWorld(0, 0, PlotRoot.Position.X/Z + (0,0,6))`, within 0.05.

### Logic checks

Monkey-patch `DataService.Get` for a fake test key, using the established patch-and-revert technique. Never touch the real user's plot or profile.

- [ ] **Royal Jelly rate** (`_computeRoyalJellyPerSecond`):

  | Setup | Expected rate |
  |---|---|
  | Royal at `(1,1)`, Brood at `(0,1)` (the template's Brood cell) | 0.004 |
  | ...plus Brood at `(1,0)` | 0.008 |
  | ...plus `population.nurse = 1` | 0.0112 |
  | Royal with no Brood neighbour | 0 |

- [ ] **Accumulator:** at rate 0.008 with `dt = 0.5`, 250 ticks raise `royalJelly` by exactly 1 and leave `royalJellyProgress` at about 0 (within 1e-9). `royalJelly` is always a whole number.
- [ ] **`CanUpgrade`:**

  | Situation | Expected result |
  |---|---|
  | Tier 1, RJ 4 | Rejected with "Not enough Royal Jelly (5 needed, you have 4)" |
  | Tier 1, RJ 5 | Upgrades to tier 2, RJ becomes 0 |
  | Tier 4, RJ 999, generation 0 | Rejected with the generation string |
  | Tier 5 | Rejected with "already the Sun Queen" |

- [ ] **`HasUnlock`** (unlocks are cumulative):

  | Call | Expected |
  |---|---|
  | `(tier 3, "unlocksNurse")` | true |
  | `(tier 2, "unlocksNurse")` | false |
  | `(tier 5, "unlocksGoldenComb")` | true |
  | `(tier 5, "bogus")` | false |

- [ ] **Migration:** a v3 profile `{queenTier = 2.7, royalJelly = 3.6}` becomes `queenTier = 2`, `royalJelly = 3`, `royalJellyProgress = 0`, `version = 4`.

### Live play-test scenario

Play mode, observation only.

1. Get 60 propolis and 3,000 honey. Either play normally, or grant them to the test profile with a patch that you revert afterwards.
2. Build a Royal Cell on rim cell `(1,1)`, next to Brood `(0,1)`.
3. Watch the jelly counter (JellyChip) tick up by 1 about every 4 minutes. Check that the QUEEN tab's hint text shows the rate.
4. At 5 RJ, confirm that the "!" appears on the HIVE button.
5. Upgrade, then confirm all of the following:
   - the panel closes
   - the camera swings to the comb
   - the comb dims
   - she grows and bursts
   - the toast and sound play
   - `PlotRoot.QueenTier == 2`
   - the Castes tab still works
6. Confirm that she walks between brood cells leaving amber discs, and that a second client within 250 studs also sees her.

---

## 13. Risk areas

| Risk | Mitigation |
|---|---|
| Royal Jelly unreachable, making this a fake feature | Royal Cell production is in scope (1c, 4.2), and the pacing table in 4.1 was reviewed. |
| `FormatNumber` rounding shows jelly the player does not actually have | `royalJelly` stays a whole number, via `royalJellyProgress`. |
| The growth light-dim leaks, leaving a comb stuck at 30% | Capture exact light values and restore them when the growth completes **and** on every cancel path (despawn, stream-out, owner change). |
| Camera conflict with Build Mode or with the FirstWaggle moment | Guard with `BuildController.IsOn()`, and only restore CameraType if it is still Scriptable. This is the same proven pattern DanceController uses. |
| Misusing HexGrid's Z offset puts the queen 6 studs off the comb | The exact formula is in 6.2, and section 12 has a check for it. |
| Duplicate DataService (pre-existing) | RESOLVED in Build Order step 0 (see 1e.1). |
| Concurrent agents overwriting each other's edits | Do a fresh `script_read` before every edit, and have Game Master serialize edits to the shared files. |
| Sun Queen permanently locked | This is intended until SwarmService ships. Game Master can open it with the one-line `genGate = 0` switch documented in 3.1. |
| Performance with 6 fully upgraded queens nearby | LOD at 250 studs, a single Heartbeat, idle particle emitters, lights without shadows, and pooled footprint discs. |

---

## 14. Signature moment: "She Grows"

You have been staring at a jelly bar for ten minutes, watching one small gold number tick from 4 to 5. A gold "!" pops onto your HIVE button. You tap it, then tap QUEEN, and there she is in a little portrait: a small, pale Virgin Queen. The button says UPGRADE QUEEN in fat gold letters.

You press it and the panel slams shut. The camera swings down behind your comb. Every honey light on your hive dips almost to darkness for half a second. In that darkness your queen stops, swells, and stretches into a longer body with gold bands, in a burst of sparks. The comb flares brighter than before, then settles. A chime plays: "Your queen is now the Laying Queen!"

She turns and walks off across your brood. Every cell she steps on lights up amber under her feet. Across the path, your neighbour just watched your comb go dark and then gold.

At the Matriarch tier, two small bees start circling her and she glows like a lantern. When players finally see a Sun Queen, with a halo and gold ripples behind her, they walk over to look. That is the social read this game runs on.

---

## 15. Follow-ups

These are not part of this task. `QueenService.HasUnlock` now unblocks them.

- **`CombService.Upgrade` with a `RequestUpgradeCell` remote** (cell tiers 2 to 4).
  - Tier 4 gate: `QueenService.HasUnlock(profile, "unlocksGoldenComb")`.
  - Tier 3 gate: `profile.kilnTier >= 2`.
  - This also makes `Formulas.CellOutputMult` in the Royal Jelly rate actually matter.
- **`SwarmService.CanSwarm`.** Requires all of:
  - `HasUnlock(profile, "unlocksSwarm")`
  - at least 25 drones
  - a capped Royal Cell
  - `genHoney >=` the swarm threshold
- **Comb Floor 2 and 3 lattices, plus `CombService.UnlockFloor`.** Floor 3 needs `HasUnlock(profile, "unlocksFloor3")` and generation 1 or higher.
- **`PerkService` and a real PERKS tab.** 3 of the 8 perk effects are already used by server code.
- **Optional polish:**
  - a queen-specific growth chime (sound-designer)
  - a turntable for the portrait (ui-designer)
