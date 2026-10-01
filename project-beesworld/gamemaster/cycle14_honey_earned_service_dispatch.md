# Dispatch 144 — HoneyEarned Tracking Service
## Cycle 14 · A Bee's World

**Feature:** `HoneyEarnedService` — a lightweight server Script that watches every player's `HoneyCount` attribute and accumulates a monotonically increasing `HoneyEarned` counter. `HoneyEarned` is the prestige threshold currency introduced in dispatch 140 (`5000 × 2^prestige`). Without this service the prestige button never enables, because `HoneyEarned` stays at 0 no matter how much honey a player collects. Part budget: +1 permanent (one new Script).
**Part budget impact:** +1 permanent → **4,150 / 5,000**
**Execution order:** After dispatch 143 (Specialist Bee Service Integration)

---

## DESIGN

### Why HoneyEarned is separate from HoneyCount

`HoneyCount` is a spendable balance — it goes up when honey is harvested and down when the player buys upgrades, specialist bees, or propolis conversions. Using it as the prestige threshold would punish spending: a player who bought the Guard Bee (500 honey) would lose prestige progress.

`HoneyEarned` is a lifetime production total. It only goes up, never down. Prestige eligibility is based on how much honey you have **ever produced**, not how much you have right now. This rewards active play without punishing smart spending.

### Attribution logic

`HoneyEarned` increments by `delta` whenever `HoneyCount` increases. When `HoneyCount` decreases (spend), `HoneyEarned` stays the same. This is the only correct attribution: every positive delta is new production; every negative delta is a spend.

### Idempotency across reloads

On player join, `HoneyEarned` is loaded from DataStore (by `DataService`) into the player attribute. `HoneyEarnedService` sets a baseline from the current value after a short wait (to let DataService replicate attributes), then begins tracking deltas. This prevents a false "earn" burst at join from the DataService replication write.

---

## SCRIPT SOURCE — HoneyEarnedService

```lua
--!strict
-- HoneyEarnedService — dispatch 144
-- Tracks HoneyEarned (lifetime honey produced) as a monotonically increasing counter.
-- HoneyEarned is the prestige threshold currency; it never decrements on spend.

local Players = game:GetService("Players")

local WAIT_FOR_DS_144 = 2  -- seconds to wait for DataService attribute replication on join

-- Per-player tracking
local baselines_144: {[Player]: number} = {}
local connections_144: {[Player]: RBXScriptConnection} = {}

local function onHoneyChanged_144(player: Player)
    local current = tonumber(player:GetAttribute("HoneyCount")) or 0
    local baseline = baselines_144[player] or current
    local delta = current - baseline
    baselines_144[player] = current  -- update baseline every tick (not just on increase)

    if delta > 0 then
        local earned = tonumber(player:GetAttribute("HoneyEarned")) or 0
        player:SetAttribute("HoneyEarned", earned + delta)
    end
    -- delta <= 0 (spend/drain) — HoneyEarned unchanged
end

local function onPlayerAdded_144(player: Player)
    task.wait(WAIT_FOR_DS_144)  -- wait for DataService to write saved HoneyCount
    if not player.Parent then return end  -- player left during wait

    -- Set baseline AFTER DataService replication so join-write doesn't count as earned
    baselines_144[player] = tonumber(player:GetAttribute("HoneyCount")) or 0

    connections_144[player] = player:GetAttributeChangedSignal("HoneyCount")
        :Connect(function()
            onHoneyChanged_144(player)
        end)
end

local function onPlayerRemoving_144(player: Player)
    if connections_144[player] then
        connections_144[player]:Disconnect()
        connections_144[player] = nil
    end
    baselines_144[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded_144)
Players.PlayerRemoving:Connect(onPlayerRemoving_144)

-- Handle players already in server (Studio test mode)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded_144, player)
end

print("[HoneyEarnedService] Ready — lifetime honey tracking active")
```

---

## STEP A — Create HoneyEarnedService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

if SSS:FindFirstChild("HoneyEarnedService") then
    print("⏭️  HoneyEarnedService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "HoneyEarnedService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- HoneyEarnedService — dispatch 144
-- Tracks HoneyEarned (lifetime honey produced) as a monotonically increasing counter.
-- HoneyEarned is the prestige threshold currency; it never decrements on spend.

local Players = game:GetService("Players")

local WAIT_FOR_DS_144 = 2

local baselines_144: {[Player]: number} = {}
local connections_144: {[Player]: RBXScriptConnection} = {}

local function onHoneyChanged_144(player: Player)
    local current  = tonumber(player:GetAttribute("HoneyCount")) or 0
    local baseline = baselines_144[player] or current
    local delta    = current - baseline
    baselines_144[player] = current

    if delta > 0 then
        local earned = tonumber(player:GetAttribute("HoneyEarned")) or 0
        player:SetAttribute("HoneyEarned", earned + delta)
    end
end

local function onPlayerAdded_144(player: Player)
    task.wait(WAIT_FOR_DS_144)
    if not player.Parent then return end
    baselines_144[player] = tonumber(player:GetAttribute("HoneyCount")) or 0
    connections_144[player] = player:GetAttributeChangedSignal("HoneyCount")
        :Connect(function() onHoneyChanged_144(player) end)
end

local function onPlayerRemoving_144(player: Player)
    if connections_144[player] then
        connections_144[player]:Disconnect()
        connections_144[player] = nil
    end
    baselines_144[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded_144)
Players.PlayerRemoving:Connect(onPlayerRemoving_144)

for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded_144, player)
end

print("[HoneyEarnedService] Ready — lifetime honey tracking active")
]]
    svc.Parent = SSS
    print("✅ HoneyEarnedService created in ServerScriptService")
end
```

---

## STEP B — DataService save/load wiring (if not already present)

`HoneyEarned` must be persisted so prestige progress survives server shutdown. If your `DataService` already saves all player attributes (generic attribute loop), this step is automatic. Verify:

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local ds   = SSS:FindFirstChild("DataService")
           or (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("DataService"))
assert(ds, "DataService not found")

-- Check if DataService saves HoneyEarned
local savesEarned = ds.Source:find("HoneyEarned", 1, true) ~= nil
print(savesEarned
    and "✅ DataService already references HoneyEarned — no change needed"
    or  "⚠️  DataService does NOT reference HoneyEarned explicitly.")

if not savesEarned then
    print("   If DataService saves a generic attribute table (all player attributes),")
    print("   HoneyEarned is saved automatically and no patch is needed.")
    print("   If DataService saves a specific field list, add 'HoneyEarned' to it.")
    print("   Search DataService for where HoneyCount is saved and add HoneyEarned next to it.")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("HoneyEarnedService")

local checks = {}
table.insert(checks, (svc and "✅" or "❌") .. " HoneyEarnedService exists in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script (not LocalScript)")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (svc and svc.Source:find("HoneyEarned", 1, true) and "✅" or "❌") .. " HoneyEarned attribute write")
table.insert(checks, (svc and svc.Source:find("baselines_144", 1, true) and "✅" or "❌") .. " baselines_144 join-write guard")
table.insert(checks, (svc and svc.Source:find("WAIT_FOR_DS_144", 1, true) and "✅" or "❌") .. " DataService replication wait")
table.insert(checks, (svc and svc.Source:find("PlayerRemoving", 1, true) and "✅" or "❌") .. " PlayerRemoving cleanup")
table.insert(checks, (svc and svc.Source:find(":Disconnect()", 1, true) and "✅" or "❌") .. " connection Disconnect on leave")

print("=== DISPATCH 144 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 144 complete" or "❌ SOME CHECKS FAILED")

print("\nHoneyEarned tracking: +delta on every HoneyCount increase | no decrement on spend/drain")
print("Prestige threshold uses HoneyEarned (dispatch 140): 5000 × 2^prestige")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HoneyEarnedService (Script in ServerScriptService) | +1 |
| **Dispatch 144 total** | **+1** |
| **Running total** | **4,150 / 5,000** |

---

## NOTES

- `WAIT_FOR_DS_144 = 2` seconds is the same delay used throughout the codebase for DataService attribute replication (established in dispatch 136's `prevPropolis_136` pattern). It prevents the join-write from counting as "earned" honey.
- The `if not player.Parent then return end` guard after `task.wait` is critical — without it, a player who joins and immediately leaves during the 2-second wait would cause an error when the connection is established on a `nil` player.
- `baselines_144[player] = current` updates the baseline on **every** attribute change, not just increases. This means if a player's honey drops (bear attack, upgrade purchase), the next increase is measured from the post-drop level — not from the pre-drop level. This is correct: if you have 500 honey, buy a 200-honey upgrade, then earn 100 more honey, HoneyEarned should increase by 100 (not 300).
- The `for _, player in Players:GetPlayers()` block at the bottom handles the Studio Play mode case where the local player is already in the server when the Script initialises. Without it, the service silently skips tracking for test sessions.
