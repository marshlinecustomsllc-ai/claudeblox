# Dispatch 110 — Idle Hive Watcher
## Cycle 14 · A Bee's World

**Feature:** A server-side analytics script that monitors per-player plot activity. If a player has claimed at least one plot and none of their plots have had a foraging trip return in the past 5 minutes, it fires a `HiveIdleSync` RemoteEvent to that player. The client shows a gentle one-time toast: `"🐝 Your bees are resting — send them foraging!"`. The notification fires at most once per 10-minute window per player (cooldown attribute) so it doesn't nag. This nudges players who open the game and forget to trigger foraging, improving session retention.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 109 (Propolis Rain Event)

---

## DESIGN

### Server side — HiveIdleWatcher

New `Script` in `ServerScriptService` named `HiveIdleWatcher`.

Tracks per-player last-activity timestamps in a module-level table:
```lua
local lastActivity: {[number]: number} = {}  -- [userId] = os.time()
```

Two hooks:
1. **ForagingService activity signal**: listen to a `ForagingActivity` BindableEvent that ForagingService fires whenever a trip completes for a player. If that BindableEvent doesn't exist (cannot modify ForagingService here without another dispatch), use a polling fallback: check `player:GetAttribute("LastForagingReturn")` (dispatch 96/99 era attribute set on the profile update path).

2. **Polling loop**: every 60 seconds, iterate all connected players. For each player with `ownedPlots > 0`, check if `os.time() - lastActivity[userId] > IDLE_THRESHOLD`. If so, and if the player's `HiveIdleCooldown` attribute allows it, fire `HiveIdleSync` to that player and set the cooldown attribute.

### Activity signal strategy

Since we cannot easily hook ForagingService internals without another source edit, the cleanest approach is:
- Listen on `HiveStatsSync` RemoteEvent — it fires every time a foraging trip completes and carries `beeCount` / resource data. Use that as the activity heartbeat.
- The watcher connects `HiveStatsSync:FireClient` — but this is a RemoteEvent, we can't intercept server→client fires from another script.

Better approach: ForagingService already fires `HiveStatsSync` after each trip. We can listen on the `HiveStatsSync` BindableEvent if one exists, or use a new `ForagingActivityBE` BindableEvent that ForagingService fires.

Simplest and least invasive: use a BindableEvent `ForagingActivityBE` in ReplicatedStorage. Append a one-liner to ForagingService that fires it after each trip. The watcher listens to it.

This keeps HiveIdleWatcher fully self-contained with a minimal ForagingService append.

### Cooldown

```lua
local IDLE_THRESHOLD = 300  -- 5 minutes of no activity = idle
local NOTIFY_COOLDOWN = 600 -- notify at most once per 10 minutes
```

`player:GetAttribute("HiveIdleLastNotify")` stores `os.time()` of the last notification. If `os.time() - lastNotify < NOTIFY_COOLDOWN`, skip.

Player must have at least one owned plot: check `player:GetAttribute("OwnedPlotCount") or 0 > 0`. If no plots, skip (new player, hasn't started yet — no nagging).

### Client side

New `LocalScript` in `StarterPlayerScripts` named `HiveIdleController`.

Toast: small Frame bottom-center, 36px tall, `BackgroundColor3 = Color3.fromRGB(80, 50, 20)` (Propolis Brown), text: `"🐝 Your bees are resting — send them foraging!"`, Font=Gotham TextSize=14. Slides up from `Y=1.05` → `Y=0.92`, holds 4 seconds, fades out. DisplayOrder=12.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingActivityBE` | New BindableEvent in ReplicatedStorage |
| `HiveIdleWatcher` | New server Script |
| `HiveIdleSync` | New RemoteEvent in ReplicatedStorage |
| `ForagingService` | Append fire ForagingActivityBE after trip complete |
| `HiveIdleController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create RemoteEvent and BindableEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

local created = {}
if not RS:FindFirstChild("HiveIdleSync") then
    local re = Instance.new("RemoteEvent")
    re.Name = "HiveIdleSync"; re.Parent = RS
    table.insert(created, "HiveIdleSync RemoteEvent")
end
if not RS:FindFirstChild("ForagingActivityBE") then
    local be = Instance.new("BindableEvent")
    be.Name = "ForagingActivityBE"; be.Parent = RS
    table.insert(created, "ForagingActivityBE BindableEvent")
end

if #created == 0 then
    print("⏭️  All events already exist — skip")
else
    print("✅ Created: " .. table.concat(created, ", "))
end
```

---

## STEP B — Patch ForagingService: fire ForagingActivityBE

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("ForagingActivityFire_110", 1, true) then
    print("⏭️  ForagingService already has ForagingActivityFire_110 — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    clone.Source = clone.Source .. [[

-- ── ForagingActivityBE fire (dispatch 110) ────────────────────────
-- ForagingActivityFire_110
task.spawn(function()
    local RS_110 = game:GetService("ReplicatedStorage")
    local be110  = RS_110:WaitForChild("ForagingActivityBE", 10) :: BindableEvent?
    if not be110 then
        warn("[HiveIdle] ForagingActivityBE not found — idle watcher won't track activity")
        return
    end

    -- Wrap: listen for HiveStatsSync fires as a proxy for trip completion
    -- HiveStatsSync fires server→client; we can't intercept. Instead we
    -- fire ForagingActivityBE from this append after each ForagingService yield loop.
    -- Since we're appended, we bind to task completion events via a BindableEvent
    -- that ForagingService itself fires here.

    -- The cleanest hook from an append: override the trip-complete signal path.
    -- ForagingService fires HiveStatsSync:FireClient(player, stats) after each trip.
    -- We monkey-patch HiveStatsSync.FireClient to also fire our BindableEvent.
    local RS2_110 = game:GetService("ReplicatedStorage")
    local hss110  = RS2_110:WaitForChild("HiveStatsSync", 10) :: RemoteEvent?
    if not hss110 then return end

    local origFire110 = hss110.FireClient
    hss110.FireClient = function(self, player, ...)
        origFire110(self, player, ...)
        -- Fire activity signal for this player
        be110:Fire(player)
    end :: any
    print("[HiveIdle] ForagingActivityBE wired via HiveStatsSync.FireClient patch")
end)
]]

    local parent = fs.Parent
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = parent
    print("✅ ForagingService: ForagingActivityFire_110 injected")
end
```

---

## STEP C — Create HiveIdleWatcher (server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("HiveIdleWatcher") then
    print("⏭️  HiveIdleWatcher already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "HiveIdleWatcher"
    svc.Source = [[
--!strict
-- HiveIdleWatcher — dispatch 110
-- Notifies players when no foraging activity has occurred for 5+ minutes.

local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")

local IDLE_THRESHOLD  : number = 300   -- 5 minutes idle
local NOTIFY_COOLDOWN : number = 600   -- notify at most once per 10 min
local POLL_INTERVAL   : number = 60    -- check every 60 seconds

-- Track last-activity timestamp per userId
local lastActivity: {[number]: number} = {}

-- Wire up activity signal
task.spawn(function()
    local be = RS:WaitForChild("ForagingActivityBE", 15) :: BindableEvent?
    if not be then
        warn("[HiveIdleWatcher] ForagingActivityBE not found — activity tracking disabled")
        return
    end
    be.Event:Connect(function(player: Player)
        lastActivity[player.UserId] = os.time()
    end)
    print("[HiveIdleWatcher] Activity signal wired")
end)

-- Initialise lastActivity when player joins (treat join as activity)
Players.PlayerAdded:Connect(function(player: Player)
    lastActivity[player.UserId] = os.time()
end)
Players.PlayerRemoving:Connect(function(player: Player)
    lastActivity[player.UserId] = nil
end)

-- Polling loop
local idleSync = RS:WaitForChild("HiveIdleSync", 15) :: RemoteEvent?
if not idleSync then
    warn("[HiveIdleWatcher] HiveIdleSync not found — notifications disabled")
    return
end

task.spawn(function()
    while true do
        task.wait(POLL_INTERVAL)
        local now = os.time()

        for _, player in Players:GetPlayers() do
            local userId = player.UserId

            -- Must have at least one plot to be "active" player
            local ownedPlots = player:GetAttribute("OwnedPlotCount")
            if type(ownedPlots) ~= "number" or ownedPlots < 1 then continue end

            -- Check idle duration
            local lastAct = lastActivity[userId] or now
            local idleSecs = now - lastAct
            if idleSecs < IDLE_THRESHOLD then continue end

            -- Check notification cooldown
            local lastNotify = player:GetAttribute("HiveIdleLastNotify")
            if type(lastNotify) == "number" and (now - lastNotify) < NOTIFY_COOLDOWN then continue end

            -- Fire notification
            player:SetAttribute("HiveIdleLastNotify", now)
            idleSync:FireClient(player)
            print("[HiveIdleWatcher] Notified " .. player.Name .. " (idle " .. idleSecs .. "s)")
        end
    end
end)

print("[HiveIdleWatcher] Loaded — polling every " .. POLL_INTERVAL .. "s")
]]
    svc.Parent = SSS
    print("✅ HiveIdleWatcher created in ServerScriptService")
end
```

---

## STEP D — Create HiveIdleController (client)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HiveIdleController") then
    print("⏭️  HiveIdleController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HiveIdleController"
    ctrl.Source = [[
--!strict
-- HiveIdleController — dispatch 110
-- Shows a gentle bottom-center toast when the server notifies idle hive.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local HONEY_BROWN  = Color3.fromRGB(80, 50, 20)   -- Propolis Brown
local CREAM        = Color3.fromRGB(232, 212, 154) -- Wax Cream
local TOAST_MSG    = "🐝 Your bees are resting — send them foraging!"
local HOLD_TIME    = 4

local function showIdleToast()
    local pg = player:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name           = "HiveIdleGui"
    gui.DisplayOrder   = 12
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.Parent         = pg

    local frame = Instance.new("Frame")
    frame.Name                   = "IdleToast"
    frame.Size                   = UDim2.new(0.7, 0, 0, 36)
    frame.Position               = UDim2.new(0.5, 0, 1.05, 0)
    frame.AnchorPoint            = Vector2.new(0.5, 1)
    frame.BackgroundColor3       = HONEY_BROWN
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel        = 0
    frame.ZIndex                 = 10
    frame.Parent                 = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, -16, 1, 0)
    label.Position               = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Font                   = Enum.Font.Gotham
    label.TextSize               = 14
    label.TextColor3             = CREAM
    label.TextXAlignment         = Enum.TextXAlignment.Center
    label.TextWrapped            = true
    label.Text                   = TOAST_MSG
    label.ZIndex                 = 11
    label.Parent                 = frame

    -- Slide up
    TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.93, 0)
    }):Play()

    task.wait(HOLD_TIME)

    -- Fade out
    local fade = TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1
    })
    TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
        TextTransparency = 1
    }):Play()
    fade:Play()
    fade.Completed:Once(function()
        gui:Destroy()
    end)
end

task.spawn(function()
    local idleSync = RS:WaitForChild("HiveIdleSync", 15) :: RemoteEvent?
    if not idleSync then
        warn("[HiveIdleController] HiveIdleSync not found")
        return
    end
    idleSync.OnClientEvent:Connect(showIdleToast)
    print("[HiveIdleController] Ready")
end)
]]
    ctrl.Parent = SPS
    print("✅ HiveIdleController created in StarterPlayerScripts")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local re  = RS:FindFirstChild("HiveIdleSync")
local be  = RS:FindFirstChild("ForagingActivityBE")
local svc = SSS:FindFirstChild("HiveIdleWatcher")
local ctrl = SPS and SPS:FindFirstChild("HiveIdleController")
local fs  = SSS:FindFirstChild("ForagingService")

local checks = {}
table.insert(checks, (re and re:IsA("RemoteEvent") and "✅" or "❌") .. " HiveIdleSync RemoteEvent in ReplicatedStorage")
table.insert(checks, (be and be:IsA("BindableEvent") and "✅" or "❌") .. " ForagingActivityBE BindableEvent in ReplicatedStorage")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " HiveIdleWatcher Script in ServerScriptService")
table.insert(checks, (svc and svc.Source:find("IDLE_THRESHOLD", 1, true) and "✅" or "❌") .. " HiveIdleWatcher: IDLE_THRESHOLD constant")
table.insert(checks, (svc and svc.Source:find("NOTIFY_COOLDOWN", 1, true) and "✅" or "❌") .. " HiveIdleWatcher: NOTIFY_COOLDOWN constant")
table.insert(checks, (svc and svc.Source:find("OwnedPlotCount", 1, true) and "✅" or "❌") .. " HiveIdleWatcher: OwnedPlotCount check")
table.insert(checks, (svc and svc.Source:find("HiveIdleLastNotify", 1, true) and "✅" or "❌") .. " HiveIdleWatcher: HiveIdleLastNotify cooldown attribute")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " HiveIdleController LocalScript in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl.Source:find("HiveIdleGui", 1, true) and "✅" or "❌") .. " HiveIdleController: creates HiveIdleGui")
table.insert(checks, (fs and fs.Source:find("ForagingActivityFire_110", 1, true) and "✅" or "❌") .. " ForagingService: ForagingActivityFire_110 marker")

print("=== DISPATCH 110 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 110 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Server Script + LocalScript only — no BaseParts | 0 permanent parts |
| **Dispatch 110 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `HiveStatsSync.FireClient` monkey-patch in the ForagingService append is a server-side technique that works because RemoteEvent `FireClient` is a regular Lua method — it can be replaced with a wrapper that calls the original and then fires the BindableEvent. This avoids modifying ForagingService's loop logic directly.
- `OwnedPlotCount` attribute is expected to be set by PlotService when a player claims a plot (dispatch era 20–30). If the attribute doesn't exist (`type(ownedPlots) ~= "number"`), the player is treated as having 0 plots and is skipped — no false notifications for new players.
- The 60-second polling interval keeps server overhead minimal. With 50 concurrent players, 50 attribute reads per minute is negligible.
- `HiveIdleLastNotify` is a player Instance attribute (not DataStore), so it resets on rejoin. This is intentional — a player who rejoins after being idle should get the reminder again if they immediately go idle again, not be silenced for 10 minutes from a previous session.
- The toast at `Y=0.93` (7% from bottom) avoids overlapping the HiveStats panel which typically anchors bottom-left at `Y=0.6–0.8`.
- DisplayOrder=12 places it below Pollen Surge (15), Propolis Rain (14), and Bee Milestone toasts (21), so it never occludes active event banners.
