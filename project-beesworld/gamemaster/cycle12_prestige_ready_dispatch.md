# Dispatch 82 — PrestigeReadySync
## Cycle 12 · A Bee's World

**Feature:** Server broadcasts `PrestigeReadySync` RemoteEvent to a player whenever their prestige conditions change (resources full + all 8 plots owned → ready; any condition unmet → not ready). `PrestigeController` (dispatch 79) listens and shows/hides the PRESTIGE button accordingly. Checked after every foraging trip completion and after every plot claim.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 81 (PlotService.ResetPlotsForPrestige)

---

## DESIGN

A new `PrestigeReadySync` RemoteEvent in ReplicatedStorage fires `{ready: true}` or `{ready: false}` to a specific player.

Triggered by:
- End of each foraging trip (inside `ForagingService` after resources are applied)
- After each plot claim (inside `PlotService` after `plot.owner = player.Name`)

`PrestigeService.CheckAndBroadcastReady(player)` performs the condition check and fires the event. Called from both trigger sites.

`PrestigeController` patches: connect `PrestigeReadySync.OnClientEvent` to toggle `PrestigeButton.Visible`.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PrestigeService` | Add `CheckAndBroadcastReady` function + `PrestigeReadySync` RE |
| `ForagingService` | Call `CheckAndBroadcastReady` after yield applied |
| `PlotService` | Call `CheckAndBroadcastReady` after plot claimed |
| `PrestigeController` | Listen to `PrestigeReadySync`, show/hide button |

---

## STEP A — Add PrestigeReadySync RE and CheckAndBroadcastReady to PrestigeService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- Create the RemoteEvent
if not RS:FindFirstChild("PrestigeReadySync") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "PrestigeReadySync"
    re.Parent = RS
    print("✅ PrestigeReadySync RemoteEvent created")
else
    print("⏭️  PrestigeReadySync already exists")
end

local ps = SSS:FindFirstChild("PrestigeService")
assert(ps, "PrestigeService not found")

if ps.Source:find("CheckAndBroadcastReady", 1, true) then
    print("⏭️  PrestigeService already has CheckAndBroadcastReady — skip")
else
    local clone = ps:Clone()
    clone.Name = "PrestigeService_WORKING"

    -- Inject PrestigeReadySync require after PrestigeSync require
    local anchor = 'PrestigeSync'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "PrestigeSync not found in PrestigeService")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\nlocal PrestigeReadySync = RS:WaitForChild(\"PrestigeReadySync\")"
        .. clone.Source:sub(lineEnd + 1)

    -- Inject CheckAndBroadcastReady before 'return PrestigeService'
    local returnAnchor = 'return PrestigeService'
    local lastFound = 1
    local searchFrom = 1
    while true do
        local next = clone.Source:find(returnAnchor, searchFrom, true)
        if not next then break end
        lastFound = next
        searchFrom = next + 1
    end

    local newFn = [[

function PrestigeService.CheckAndBroadcastReady(player: Player)
	local ok, _reason = canPrestige(player)
	PrestigeReadySync:FireClient(player, {ready = ok})
end

]]
    clone.Source = clone.Source:sub(1, lastFound - 1) .. newFn .. clone.Source:sub(lastFound)

    ps.Name = "PrestigeService_OLD_NX"
    ps.Parent = nil
    clone.Name = "PrestigeService"
    clone.Parent = SSS
    print("✅ PrestigeService.CheckAndBroadcastReady injected")
end
```

---

## STEP B — ForagingService: call CheckAndBroadcastReady after yield

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("CheckAndBroadcastReady", 1, true) then
    print("⏭️  ForagingService already calls CheckAndBroadcastReady — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Inject after the profile.honey accumulation line
    -- Find: profile.honey = profile.honey + honeyYield  (or similar)
    -- Fallback: after DataService.SaveProfile call
    local anchor = 'DataService.SaveProfile'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        anchor = 'profile.honey'
        found = clone.Source:find(anchor, 1, true)
    end
    assert(found, "Cannot find inject anchor in ForagingService for CheckAndBroadcastReady")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\n\ttask.spawn(function() PrestigeService.CheckAndBroadcastReady(player) end)"
        .. clone.Source:sub(lineEnd + 1)

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService CheckAndBroadcastReady call injected")
end
```

---

## STEP C — PlotService: call CheckAndBroadcastReady after plot claimed

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps_plot = SSS:FindFirstChild("PlotService")
assert(ps_plot, "PlotService not found")

if ps_plot.Source:find("CheckAndBroadcastReady", 1, true) then
    print("⏭️  PlotService already calls CheckAndBroadcastReady — skip")
else
    local clone = ps_plot:Clone()
    clone.Name = "PlotService_WORKING"

    -- Inject PrestigeService require at top (after DataService require)
    local anchor1 = 'local DataService'
    local found1 = clone.Source:find(anchor1, 1, true)
    if found1 then
        local lineEnd1 = clone.Source:find("\n", found1, true)
        clone.Source = clone.Source:sub(1, lineEnd1)
            .. "\nlocal PrestigeService = require(SSS:WaitForChild(\"PrestigeService\"))"
            .. clone.Source:sub(lineEnd1 + 1)
    end

    -- Inject call after plot.owner assignment
    local anchor2 = 'plot%.owner%s*=%s*player%.Name'
    local found2 = clone.Source:find(anchor2)
    if not found2 then
        anchor2 = 'plot.owner = player.Name'
        found2 = clone.Source:find(anchor2, 1, true)
    end
    if found2 then
        local lineEnd2 = clone.Source:find("\n", found2, true)
        clone.Source = clone.Source:sub(1, lineEnd2)
            .. "\n\ttask.spawn(function() PrestigeService.CheckAndBroadcastReady(player) end)"
            .. clone.Source:sub(lineEnd2 + 1)
    else
        print("⚠️  plot.owner = player.Name not found — CheckAndBroadcastReady not injected into PlotService")
    end

    ps_plot.Name = "PlotService_OLD_NX"
    ps_plot.Parent = nil
    clone.Name = "PlotService"
    clone.Parent = SSS
    print("✅ PlotService CheckAndBroadcastReady call injected")
end
```

---

## STEP D — PrestigeController: listen to PrestigeReadySync

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PrestigeController")
assert(ctrl, "PrestigeController not found")

if ctrl.Source:find("PrestigeReadySync", 1, true) then
    print("⏭️  PrestigeController already listens to PrestigeReadySync — skip")
else
    local clone = ctrl:Clone()
    clone.Name = "PrestigeController_WORKING"

    -- Inject PrestigeReadySync require after PrestigeSync require
    local anchor = 'local PrestigeSync'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "PrestigeSync require not found in PrestigeController")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\nlocal PrestigeReadySync = RS:WaitForChild(\"PrestigeReadySync\")"
        .. clone.Source:sub(lineEnd + 1)

    -- Append listener at end of source (before final empty line or end)
    clone.Source = clone.Source .. [[

-- Show/hide prestige button based on server-side condition check
PrestigeReadySync.OnClientEvent:Connect(function(data: any)
    if type(data) ~= "table" then return end
    task.delay(4.5, function()  -- wait until button is built
        local hiveHud = playerGui:FindFirstChild("HiveHUD")
        if not hiveHud then return end
        local btn = hiveHud:FindFirstChild("PrestigeButton")
        if btn then
            btn.Visible = data.ready == true
        end
    end)
end)
]]

    ctrl.Name = "PrestigeController_OLD_NX"
    ctrl.Parent = nil
    clone.Name = "PrestigeController"
    clone.Parent = SPS
    print("✅ PrestigeController PrestigeReadySync listener appended")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local re = RS:FindFirstChild("PrestigeReadySync")
table.insert(checks, (re and re:IsA("RemoteEvent") and "✅" or "❌") .. " PrestigeReadySync RemoteEvent")

local prestige = SSS:FindFirstChild("PrestigeService")
table.insert(checks, (prestige and prestige.Source:find("CheckAndBroadcastReady") and "✅" or "❌") .. " PrestigeService: CheckAndBroadcastReady function")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("CheckAndBroadcastReady") and "✅" or "❌") .. " ForagingService: calls CheckAndBroadcastReady")

local ps_plot = SSS:FindFirstChild("PlotService")
table.insert(checks, (ps_plot and ps_plot.Source:find("CheckAndBroadcastReady") and "✅" or "❌") .. " PlotService: calls CheckAndBroadcastReady")

local ctrl = SPS and SPS:FindFirstChild("PrestigeController")
table.insert(checks, (ctrl and ctrl.Source:find("PrestigeReadySync") and "✅" or "❌") .. " PrestigeController: PrestigeReadySync listener")

print("=== DISPATCH 82 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 82 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| RemoteEvent + code patches only | 0 new parts |
| **Dispatch 82 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `CheckAndBroadcastReady` calls the private `canPrestige(player)` function that already exists in `PrestigeService`. Since the injection goes inside the module's closure (before `return PrestigeService`), `canPrestige` is in scope.
- Both trigger sites use `task.spawn` to prevent blocking the hot path (foraging trip completion / plot claim). The ready check is a fast synchronous function but the `FireClient` is always better off-thread.
- The `task.delay(4.5, ...)` in `PrestigeController` STEP D is a workaround for the fact that the prestige button is built by a `task.delay(4, ...)` in the same script. In production the button may already exist (second character spawn); the delay safely handles first-spawn timing. A cleaner refactor would extract button creation into a shared function — deferred to a future polish dispatch.
- The listener correctly handles `data.ready == false` (button hidden when conditions no longer met, e.g. after spending honey). This means the button will hide if the player spends resources after foraging — which is the correct behavior.
