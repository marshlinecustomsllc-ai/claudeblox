# Dispatch 125 — Stat Tracking Wires (TotalForages & BearSurviveCount)
## Cycle 14 · A Bee's World

**Feature:** Appends two small stat increments to existing server scripts: (1) `ForagingService` increments `TotalForages` player attribute on each completed foraging return, and (2) `ThreatService` increments `BearSurviveCount` when a bear raid ends without the player losing honey. These attributes are referenced by `SeasonalAchievementService` (dispatch 124). Uses the append-injection pattern — no existing logic is touched.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 124 (Seasonal Achievements)

---

## DESIGN

### TotalForages

Written to `ForagingService` (ServerScriptService). After the existing honey reward logic on foraging completion, append an attribute increment:

```lua
player:SetAttribute("TotalForages", (tonumber(player:GetAttribute("TotalForages")) or 0) + 1)
```

### BearSurviveCount

Written to `ThreatService` (ServerScriptService). After the existing bear raid resolution (when the raid ends and the player was present but did NOT lose honey — i.e., the raid was a "survive" outcome), append:

```lua
player:SetAttribute("BearSurviveCount", (tonumber(player:GetAttribute("BearSurviveCount")) or 0) + 1)
```

### Idempotency guard

Both appends use a sentinel comment `-- dispatch125_inject` to prevent double-injection.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingService` | Append TotalForages increment (idempotency-guarded) |
| `ThreatService` | Append BearSurviveCount increment (idempotency-guarded) |

---

## STEP A — Inject TotalForages into ForagingService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("ForagingService")

if not svc then
    print("⚠️  ForagingService not found — skipping TotalForages inject (run ForagingService dispatch first)")
else
    if svc.Source:find("dispatch125_inject_forages", 1, true) then
        print("⏭️  TotalForages inject already present — skip")
    else
        svc.Source = svc.Source .. [[

-- dispatch125_inject_forages
-- Increment TotalForages on each completed foraging return.
-- Injected by dispatch 125 — do not remove this sentinel comment.
do
    local _orig125_onForageReturn = onForageReturn or nil
    -- Patch: listen for ForagingActive false transitions to count completions
    game:GetService("Players").PlayerAdded:Connect(function(plr125: Player)
        plr125:GetAttributeChangedSignal("ForagingActive"):Connect(function()
            if plr125:GetAttribute("ForagingActive") == false then
                local prev = plr125:GetAttribute("_d125_wasForaging")
                if prev == true then
                    plr125:SetAttribute("TotalForages",
                        (tonumber(plr125:GetAttribute("TotalForages")) or 0) + 1)
                end
            end
            plr125:SetAttribute("_d125_wasForaging", plr125:GetAttribute("ForagingActive") == true)
        end)
    end)
    for _, plr125 in game:GetService("Players"):GetPlayers() do
        plr125:GetAttributeChangedSignal("ForagingActive"):Connect(function()
            if plr125:GetAttribute("ForagingActive") == false then
                local prev = plr125:GetAttribute("_d125_wasForaging")
                if prev == true then
                    plr125:SetAttribute("TotalForages",
                        (tonumber(plr125:GetAttribute("TotalForages")) or 0) + 1)
                end
            end
            plr125:SetAttribute("_d125_wasForaging", plr125:GetAttribute("ForagingActive") == true)
        end)
    end
end
]]
        print("✅ TotalForages inject added to ForagingService")
    end
end
```

---

## STEP B — Inject BearSurviveCount into ThreatService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("ThreatService")

if not svc then
    print("⚠️  ThreatService not found — skipping BearSurviveCount inject (run ThreatService dispatch first)")
else
    if svc.Source:find("dispatch125_inject_bear", 1, true) then
        print("⏭️  BearSurviveCount inject already present — skip")
    else
        svc.Source = svc.Source .. [[

-- dispatch125_inject_bear
-- Increment BearSurviveCount for each player who was online during a bear raid
-- but did NOT lose honey (their HoneyCount didn't decrease this raid).
-- Injected by dispatch 125 — do not remove this sentinel comment.
do
    local Players125 = game:GetService("Players")
    local RS125      = game:GetService("ReplicatedStorage")
    local BearRaidSync125 = RS125:FindFirstChild("BearRaidSync") :: RemoteEvent?

    if BearRaidSync125 then
        -- Track honey snapshots at raid start
        local honeySnap125: {[number]: number} = {}

        BearRaidSync125.OnServerEvent:Connect(function(_, payload125: {action: string, raidTime: number?})
            if payload125 and payload125.action == "incoming" then
                -- Snapshot current honey for all connected players
                for _, plr in Players125:GetPlayers() do
                    honeySnap125[plr.UserId] = tonumber(plr:GetAttribute("HoneyCount")) or 0
                end

            elseif payload125 and payload125.action == "clear" then
                -- Compare honey after raid
                for _, plr in Players125:GetPlayers() do
                    local snapHoney = honeySnap125[plr.UserId] or 0
                    local nowHoney  = tonumber(plr:GetAttribute("HoneyCount")) or 0
                    if nowHoney >= snapHoney then
                        -- Survived without loss
                        plr:SetAttribute("BearSurviveCount",
                            (tonumber(plr:GetAttribute("BearSurviveCount")) or 0) + 1)
                    end
                end
                table.clear(honeySnap125)
            end
        end)
    end
end
]]
        print("✅ BearSurviveCount inject added to ThreatService")
    end
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local fsvc = SSS:FindFirstChild("ForagingService")
local tsvc = SSS:FindFirstChild("ThreatService")

local checks = {}

-- ForagingService
table.insert(checks, (fsvc and "✅" or "⚠️") .. " ForagingService found (⚠️ = dispatch not yet executed, skip OK)")
if fsvc then
    table.insert(checks, (fsvc.Source:find("dispatch125_inject_forages", 1, true) and "✅" or "❌")
        .. " TotalForages sentinel in ForagingService")
    table.insert(checks, (fsvc.Source:find("TotalForages", 1, true) and "✅" or "❌")
        .. " TotalForages attribute written")
end

-- ThreatService
table.insert(checks, (tsvc and "✅" or "⚠️") .. " ThreatService found (⚠️ = dispatch not yet executed, skip OK)")
if tsvc then
    table.insert(checks, (tsvc.Source:find("dispatch125_inject_bear", 1, true) and "✅" or "❌")
        .. " BearSurviveCount sentinel in ThreatService")
    table.insert(checks, (tsvc.Source:find("BearSurviveCount", 1, true) and "✅" or "❌")
        .. " BearSurviveCount attribute written")
    table.insert(checks, (tsvc.Source:find("honeySnap125", 1, true) and "✅" or "❌")
        .. " honey snapshot table for survive detection")
end

print("=== DISPATCH 125 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 125 complete" or
      (not fsvc or not tsvc) and "⚠️  One or both services not yet in Studio — re-run after their dispatches" or
      "❌ SOME CHECKS FAILED")

print("\nTotalForages: ForagingActive true→false transition counter")
print("BearSurviveCount: raid clear w/ HoneyCount unchanged or higher")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Inject to ForagingService (source append, no parts) | 0 |
| Inject to ThreatService (source append, no parts) | 0 |
| **Dispatch 125 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- Both STEP A and STEP B print `⚠️ not found — skip` if the target service hasn't been executed yet. This dispatch is designed to be re-run after any pending service dispatches are executed — the idempotency sentinel (`dispatch125_inject_forages` / `dispatch125_inject_bear`) ensures double-injection never happens.
- `TotalForages` is incremented by detecting `ForagingActive` attribute transitions from `true → false`. This reuses the same attribute already listened to by `BeeRosterController` (dispatch 119) and `ForagingQualityController` (dispatch 122) — no new attribute needed, no new RemoteEvent.
- The `_d125_wasForaging` helper attribute persists the previous `ForagingActive` state server-side per player, enabling reliable edge-state detection without storing module-level variables that could be GC'd if the script reloads.
- `BearSurviveCount` uses a honey snapshot at raid start vs. post-raid comparison. A player who loses 50 honey during the raid (honey drops) doesn't get the survive credit; a player who keeps their honey (wasn't targeted, dodged, or the bear found nothing) does. This makes `Bear Dodger` achievement meaningful — you earn it by having a hive that's hard to raid, not just by being online.
- Both injections use `PlayerAdded` + loop-over-existing-players pattern so they work correctly whether players are already in-game when the script runs (Roblox Studio test) or join after the script loads (live game).
