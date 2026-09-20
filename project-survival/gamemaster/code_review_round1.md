# WICKWOOD — Full Code Review, Round 1 (luau-reviewer)

VERDICT at time of review: NEEDS FIXES
Scope: all 22 scripts (~6,300 lines) -- ServerScriptService.Main, all 12 Systems ModuleScripts, all 4 ReplicatedStorage.Modules, all 4 StarterPlayerScripts. Plus live audits of RemoteEvent coverage (31 remotes), CollectionService tag coverage (30 tags), node attribute integrity (150 HarvestNodes), Prefabs, StarterGui hierarchy, the Wick rig, and cross-module call-site reachability for 90 exported symbols.

Counts: 3 Critical, 21 Serious, 14 Moderate, 9 Low.

Headline: the "partially wired mechanic" pattern (found twice already via human playtesting -- Ready Pads, Hearth day-burn) is the dominant failure mode. 8 of 13 client->server remotes have no complete input->handler->effect path. Three whole subsystems (harvesting, fortification, revive/elimination) are built on both ends with no connection in the middle.

## CRITICAL

- **C1**: `RequestHarvest` is never fired by any client script. InputController binds E exclusively to hearth-feeding. 150 valid HarvestNodes + a correct server handler exist, but the entire economy (crafting, hearth-feeding, hearth upgrades, Stone Axe, Placed Lanterns) has been unreachable by a real player this whole session. All earlier "verified" harvesting was via direct script injection, not real input.
- **C2**: Downed is a terminal, unrevivable, non-punishing state. No RequestRevive handler exists (remote defined, never wired). SurvivalStats.Snuff is never called (elimination unreachable). Damage on a Downed player does nothing further. applyWalkSpeed has no Downed branch, so a Downed player moves at full speed. CycleManager.EndRun is only ever called from the Night-5-survived path -- there is no wipe condition. Getting grappled is currently a buff, not a threat.
- **C3**: Gloom death drain (`AddGloom` -> `M.Damage(player, Config.GLOOM.deathDrainHp)`) is not dt-scaled, but is called from a 10Hz tick -- 30 HP/sec instead of the intended 3/sec. Combined with C2, crossing 100 Gloom = permanently unrevivable in ~3 seconds.

## SERIOUS (21 total, full detail + fix code in agent transcript / commit history)
S4 RequestInteract has no server handler at all (client fires it, nothing listens) -- blocks shutter install, lantern post relight, Cellar/Watchtower-adjacent interactions.
S5 Fortification system is dead code -- InstallShutter/BreakSlot/GetSlotState have zero call sites; crafting a ReinforcedShutter just drops an inert unregistered prop.
S6 InventoryUpdated fires at ~60Hz per player while a lantern is on (unthrottled reliable remote spam).
S7 LightManager never unregisters destroyed lights -- ghost illumination + leak (destroyed PlacedLanterns/Brands keep lighting their old position forever).
S8 Hearth light radius is pinned to Tier 1 config regardless of actual tier -- upgrades widen the safe zone but not the lit radius, making the safe zone bigger than the lit radius at T3.
S9 HearthManager.tickBurn has no phase awareness -- burns during the Lobby wait (root cause of the "instant blackout" bug already partially fixed).
S10 Burn rate is never reset at run end -- Night 5's rate persists into the next Lobby wait.
S11 RequestHearthUpgrade spends resources BEFORE validating the tier is sequential -- a wrong tier destroys the cost for nothing. Also no proximity/phase gate.
S12 RequestHearthUpgrade and RequestMarkWick have no client fire site at all (unreachable content).
S13 RequestMarkWick broadcasts the MARKING PLAYER's position, not Wick's -- defeats the entire point of the mechanic.
S14 WickAI's presence-stream loop is a `while ... task.wait()` poll that never stops, running forever even when Wick is despawned -- violates the project's own no-poll-loop rule.
S15 CraftingManager's per-run gates (onePerRun/onePerPlayer/coCraftSessions/soloCraftChannels) never reset between runs -- WatchtowerBeacon/StoneAxe become once-per-server-lifetime.
S16 CoCraft silently reassigns the payer to player #2 if the initiator disconnects mid-session, charging them at the departed player's stale position.
S17 Player inventories/lanternFuel/tools never reset between runs -- a player can carry a full inventory + Stone Axe into a fresh run.
S18 Lantern mode is mirrored in 3 places (InputController, LanternController, WickAI) with 3 different reset rules -- desyncs after fuel-exhaustion-forced-off or respawn, in the worst case showing a lit lantern the server considers dark (or vice versa).
S19 Watchtower/Cellar occupancy use per-limb Touched/TouchEnded with no debounce on the TouchEnded side -- occupancy flickers constantly for a standing-still player (same bug class as the already-fixed Ready Pads, but only half-fixed here).
S20 No game:BindToClose anywhere -- DataStore writes can be lost on server shutdown.
S21 The 4 Lantern Posts can never be relit once snuffed -- LightManager.Relight has zero call sites, no interact path exists.
S22 RequestReady has no rate limit -- exploitable FireAllClients amplification.
S23 Gloom never drains outside Night phase (only the fill was meant to be Night-gated, but the whole tick returns early) -- Gloom accumulated during Night 2 persists at full value through all of Day/Dusk and into Night 3.
S24 The Melting *state* (as opposed to the working Melt visual overlay) is unreachable dead code -- SetWaxPercent has zero callers.

## MODERATE (14 total) and LOW (9 total)
See full agent transcript for M1-M14 and L1-L9 -- DataManager schema validation, ShoutPing timestamp using the wrong clock, SignalFlare/WatchtowerBeacon crafted-but-inert, silent resource loss on placePrefab failure, 60Hz WaxLevel attribute replication, Focused Beam aiming from root LookVector instead of camera, a lost-wakeup race in HUDController's toast queue, 11 server->client remotes with no client listener, unbounded NoiseManager ping growth outside Wick's active states, dead node-respawn timer (Dawn always respawns everything regardless of respawnSeconds), free/instant/spammable harvesting (no stamina cost despite Config.STAMINA.chopCost existing), no phase-gating on most gameplay remotes, decision-timer accumulator drift (~4% per tick), various dead Config keys/Shared+Validator helpers/world tags/getters, a wrong-tag doc comment, duplicated Day/Dawn branch in WickAI, an all-zero DawnReport payload.

## VERIFIED CORRECT (worth not re-auditing)
Node data integrity (150 HarvestNodes, all valid, no name collisions); channel-completion atomicity across all 3 channel systems (Hearth feed, Iron harvest, Crafting); SpendResources atomicity; per-player table cleanup on PlayerRemoving (checked 8 tables, no leaks); grapple teardown idempotency (checked 6 call sites); Heartbeat discipline (one connection per manager, guarded against double-connect); pathfinding safety (pcall + token invalidation); Recoil freeze duration is a true absolute deadline, not extendable; WickAI's state machine transition table has no illegal reachable edges; Wick rig integrity (7 parts, 6 joints, 0 anchored); Arrival points (6, correct Index sort); GUI hierarchy resolves correctly; Ready Pads are genuinely fixed; zero deprecated API usage anywhere; no client-authoritative state (one exception: beam direction, M6, which is server-read but from the wrong source).

## RECOMMENDED FIX ORDER (per reviewer)
1. C1 (harvest wiring) -- unblocks all downstream testing.
2. S4 (RequestInteract handler) -- prereq for S5/C2-revive-input/S21.
3. C2 + C3 together (Downed/revive/wipe + gloom dt) -- C3 alone makes death 10x faster into a state C2 makes permanent.
4. S17 + S15 (per-run resets) -- before any multi-run testing.
5. S9 + S10 (Hearth phase/rate gating), same file.
6. S6 + S7 + S8 (LightManager), one file three fixes.
7. S18 (lantern desync) -- after S6, touches the same AddLanternFuel path.
8. S14 (WickAI poll loop) -- mind the ~195/200 register budget; the given fix is register-negative.
9. Remaining Serious, then Moderate.

Nothing was modified by the review agent -- review only. Fixes tracked separately in buglist.md / changelog.md as they land.
