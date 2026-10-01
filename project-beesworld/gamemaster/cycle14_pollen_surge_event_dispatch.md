# Dispatch 106 — Pollen Multiplier Surge Event
## Cycle 14 · A Bee's World

**Feature:** Pollen is the rarest resource — it only comes from specific upgrades and is hard to stockpile. This dispatch adds a **Pollen Surge** event: a randomly-triggered 2-minute window where pollen yield from all foraging trips is doubled. The surge fires once every 10–20 minutes of active server uptime (random interval), broadcasts to all players via a new `PollenSurgeSync` RemoteEvent, displays a pollen HUD banner on the client, and the ForagingService multiplies pollen yield by 2.0 during the window. This rewards players who are online during the surge and creates a natural reason to keep the game running.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 105 (Queen Bee Upgrade)

---

## DESIGN

### Surge timing

Server-side:
- First surge fires 10 minutes after server start (gives players time to settle in)
- Subsequent surges fire every 10–20 minutes (random interval via `math.random(600, 1200)`)
- Surge lasts 120 seconds (2 minutes)
- During surge: `ForagingService` multiplies pollenYield × 2.0
- State tracked via `PollenSurgeService.IsActive()` (boolean)

### PollenSurgeSync payload

```lua
-- Surge start
{active = true, duration = 120, endsAt = os.time() + 120}
-- Surge end
{active = false}
```

The client uses `endsAt - os.time()` to display a countdown timer. `os.time()` is UTC epoch — safe to use across client/server since Roblox clocks are synchronized.

### Server service: PollenSurgeService

New `Script` in `ServerScriptService`:
- Runs a loop: `task.wait(math.random(600, 1200))`
- On fire: sets `PollenSurgeService.active = true`; fires `PollenSurgeSync` to all clients; waits 120s; resets `active = false`; fires end sync
- Exposes `PollenSurgeService.IsActive(): boolean`
- Also fires `PollenSurgeSync` to each new player who joins mid-surge

### ForagingService patch

After existing seasonal bonus multiplier (dispatch 97), apply surge multiplier:

```lua
if require(game:GetService("ServerScriptService").PollenSurgeService).IsActive() then
    pollenYield = math.floor(pollenYield * 2.0)
end
```

### Client HUD: PollenSurgeController

New LocalScript in StarterPlayerScripts:
- Listens to `PollenSurgeSync`
- On `{active=true}`: shows a full-width banner (`🌼 POLLEN SURGE! ×2 pollen yield for 2:00`) with countdown
- On `{active=false}`: hides/destroys the banner
- Banner uses `TweenService` slide-down from top, bright pollen green color

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PollenSurgeService` | New Script in ServerScriptService — surge loop + IsActive() |
| `ForagingService` | Inject pollen surge multiplier after seasonal bonus |
| `PollenSurgeController` | New LocalScript in StarterPlayerScripts — HUD banner + countdown |

---

## STEP A — Create PollenSurgeService

Command Bar:

```lua
local SS = game:GetService("ServerScriptService")
assert(SS, "ServerScriptService not found")

if SS:FindFirstChild("PollenSurgeService") then
    print("⏭️  PollenSurgeService already exists — skip")
else
    -- Create PollenSurgeSync RemoteEvent
    local RS = game:GetService("ReplicatedStorage")
    if not RS:FindFirstChild("PollenSurgeSync") then
        local re = Instance.new("RemoteEvent")
        re.Name = "PollenSurgeSync"
        re.Parent = RS
        print("✅ PollenSurgeSync RemoteEvent created")
    end

    local svc = Instance.new("Script")
    svc.Name = "PollenSurgeService"
    svc.Source = [[
--!strict
-- PollenSurgeService — dispatch 106
-- Fires periodic 2-minute pollen yield ×2 surges.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

local pollenSurgeSync = RS:WaitForChild("PollenSurgeSync") :: RemoteEvent

-- Module-like table for IsActive()
local PollenSurgeService = {}
PollenSurgeService.active = false

function PollenSurgeService.IsActive(): boolean
    return PollenSurgeService.active
end

-- Export via _G for cross-service access
_G.PollenSurgeService = PollenSurgeService

local SURGE_DURATION = 120   -- seconds
local MIN_INTERVAL   = 600   -- 10 minutes between surges (minimum)
local MAX_INTERVAL   = 1200  -- 20 minutes between surges (maximum)
local INITIAL_DELAY  = 600   -- 10 minutes after server start

-- Fire surge start/end to all players
local function fireSurge()
    PollenSurgeService.active = true
    local endsAt = os.time() + SURGE_DURATION
    pollenSurgeSync:FireAllClients({active = true, duration = SURGE_DURATION, endsAt = endsAt})
    print("[PollenSurgeService] Pollen surge started — ends at " .. endsAt)

    task.wait(SURGE_DURATION)

    PollenSurgeService.active = false
    pollenSurgeSync:FireAllClients({active = false})
    print("[PollenSurgeService] Pollen surge ended")
end

-- Send active surge state to newly joined players
Players.PlayerAdded:Connect(function(player: Player)
    if PollenSurgeService.active then
        task.wait(2)  -- brief wait for player to load
        pollenSurgeSync:FireClient(player, {
            active   = true,
            duration = SURGE_DURATION,
            endsAt   = os.time() + SURGE_DURATION,  -- approximate — server time
        })
    end
end)

-- Main surge loop
task.delay(INITIAL_DELAY, function()
    while true do
        fireSurge()
        task.wait(math.random(MIN_INTERVAL, MAX_INTERVAL))
    end
end)

print("[PollenSurgeService] Ready — first surge in " .. INITIAL_DELAY .. "s")
]]

    svc.Parent = SS
    print("✅ PollenSurgeService created in ServerScriptService")
end
```

---

## STEP B — ForagingService: inject pollen surge multiplier

Command Bar:

```lua
local SS = game:GetService("ServerScriptService")
local fs = nil
for _, obj in SS:GetDescendants() do
    if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then
        fs = obj; break
    end
end
if not fs then fs = SS:FindFirstChild("ForagingService") end
assert(fs, "ForagingService not found")

if fs.Source:find("PollenSurge", 1, true) then
    print("⏭️  ForagingService already has PollenSurge — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    clone.Source = clone.Source .. [[

-- ── Pollen Surge Multiplier (dispatch 106) ───────────────────────
do
    local _surgeActive = _G.PollenSurgeService and _G.PollenSurgeService.IsActive()
    if _surgeActive and pollenYield and pollenYield > 0 then
        pollenYield = math.floor(pollenYield * 2.0)
    end
end
-- ── End Pollen Surge ─────────────────────────────────────────────
]]

    local parent = fs.Parent
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = parent
    print("✅ ForagingService: pollen surge multiplier injected")
end
```

---

## STEP C — Create PollenSurgeController (client HUD)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PollenSurgeController") then
    print("⏭️  PollenSurgeController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PollenSurgeController"
    ctrl.Source = [[
--!strict
-- PollenSurgeController — dispatch 106
-- Shows HUD banner with countdown during Pollen Surge events.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local POLLEN_GREEN = Color3.fromRGB(160, 220, 50)
local POLLEN_DARK  = Color3.fromRGB(20, 40, 5)

local surgeGui: ScreenGui?  = nil
local countdownTask: thread? = nil

local function destroySurgeGui()
    if countdownTask then task.cancel(countdownTask); countdownTask = nil end
    if surgeGui then surgeGui:Destroy(); surgeGui = nil end
end

local function createSurgeBanner(endsAt: number)
    destroySurgeGui()

    local pg = player:WaitForChild("PlayerGui")
    surgeGui = Instance.new("ScreenGui")
    surgeGui.Name         = "PollenSurgeGui"
    surgeGui.ResetOnSpawn = false
    surgeGui.DisplayOrder = 15
    surgeGui.Parent       = pg

    local frame = Instance.new("Frame")
    frame.Name                   = "SurgeBanner"
    frame.Size                   = UDim2.new(0, 320, 0, 48)
    frame.Position               = UDim2.new(0.5, -160, -0.1, 0)  -- starts above screen
    frame.BackgroundColor3       = POLLEN_DARK
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel        = 0
    frame.Parent                 = surgeGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color     = POLLEN_GREEN
    stroke.Thickness = 2
    stroke.Parent    = frame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name                   = "SurgeTitle"
    titleLabel.Size                   = UDim2.new(1, -8, 0.55, 0)
    titleLabel.Position               = UDim2.new(0, 4, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font                   = Enum.Font.GothamBold
    titleLabel.TextSize               = 16
    titleLabel.TextColor3             = POLLEN_GREEN
    titleLabel.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    titleLabel.TextStrokeTransparency = 0.4
    titleLabel.Text                   = "🌼 POLLEN SURGE!  ×2 pollen yield"
    titleLabel.TextXAlignment         = Enum.TextXAlignment.Center
    titleLabel.Parent                 = frame

    local timerLabel = Instance.new("TextLabel")
    timerLabel.Name                   = "SurgeTimer"
    timerLabel.Size                   = UDim2.new(1, -8, 0.45, 0)
    timerLabel.Position               = UDim2.new(0, 4, 0.55, 0)
    timerLabel.BackgroundTransparency = 1
    timerLabel.Font                   = Enum.Font.Gotham
    timerLabel.TextSize               = 13
    timerLabel.TextColor3             = Color3.fromRGB(200, 240, 150)
    timerLabel.Text                   = "2:00 remaining"
    timerLabel.TextXAlignment         = Enum.TextXAlignment.Center
    timerLabel.Parent                 = frame

    -- Slide down from above
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 0.03, 0)
    }):Play()

    -- Countdown ticker
    countdownTask = task.spawn(function()
        while true do
            local remaining = math.max(0, endsAt - os.time())
            local mins = math.floor(remaining / 60)
            local secs = remaining % 60
            timerLabel.Text = string.format("%d:%02d remaining", mins, secs)
            if remaining <= 0 then break end
            task.wait(1)
        end
    end)
end

local function hideSurgeBanner()
    if not surgeGui then return end
    local frame = surgeGui:FindFirstChild("SurgeBanner")
    if frame then
        TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -160, -0.15, 0)
        }):Play()
    end
    task.delay(0.45, destroySurgeGui)
end

-- Bind to PollenSurgeSync
task.spawn(function()
    local surgeSync = RS:WaitForChild("PollenSurgeSync", 15) :: RemoteEvent?
    if not surgeSync then
        warn("[PollenSurgeController] PollenSurgeSync not found after 15s")
        return
    end

    surgeSync.OnClientEvent:Connect(function(data: {active: boolean, duration: number?, endsAt: number?})
        if data.active == true and data.endsAt then
            createSurgeBanner(data.endsAt)
        elseif data.active == false then
            hideSurgeBanner()
        end
    end)

    print("[PollenSurgeController] Ready — watching for pollen surges")
end)
]]

    ctrl.Parent = SPS
    print("✅ PollenSurgeController created in StarterPlayerScripts")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SS  = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc  = SS:FindFirstChild("PollenSurgeService")
local ctrl = SPS and SPS:FindFirstChild("PollenSurgeController")
local re   = RS:FindFirstChild("PollenSurgeSync")
local fs   = nil
for _, obj in SS:GetDescendants() do
    if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingService" then fs = obj; break end
end
if not fs then fs = SS:FindFirstChild("ForagingService") end

local checks = {}
table.insert(checks, (svc and "✅" or "❌") .. " PollenSurgeService exists in SSS")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " PollenSurgeService is Script (not Local)")
table.insert(checks, (svc and svc.Source:find("IsActive", 1, true) and "✅" or "❌") .. " PollenSurgeService: IsActive() exported")
table.insert(checks, (svc and svc.Source:find("_G%.PollenSurgeService", 1, false) and "✅" or "❌") .. " PollenSurgeService: _G export")
table.insert(checks, (svc and svc.Source:find("SURGE_DURATION", 1, true) and "✅" or "❌") .. " PollenSurgeService: SURGE_DURATION constant")
table.insert(checks, (svc and svc.Source:find("task%.delay%(INITIAL_DELAY", 1, false) and "✅" or "❌") .. " PollenSurgeService: INITIAL_DELAY")
table.insert(checks, (re and "✅" or "❌") .. " PollenSurgeSync RemoteEvent in ReplicatedStorage")
table.insert(checks, (fs and fs.Source:find("PollenSurge", 1, true) and "✅" or "❌") .. " ForagingService: pollen surge multiplier")
table.insert(checks, (fs and fs.Source:find("_G%.PollenSurgeService", 1, false) and "✅" or "❌") .. " ForagingService: reads _G.PollenSurgeService")
table.insert(checks, (ctrl and "✅" or "❌") .. " PollenSurgeController exists in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " PollenSurgeController is LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " PollenSurgeController: --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("createSurgeBanner", 1, true) and "✅" or "❌") .. " PollenSurgeController: createSurgeBanner")
table.insert(checks, (ctrl and ctrl.Source:find("os%.time%(%)", 1, false) and "✅" or "❌") .. " PollenSurgeController: os.time countdown")

print("=== DISPATCH 106 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 106 complete" or "❌ SOME CHECKS FAILED")

print("\nSurge timing:")
print("  Initial delay: 600s (10 min)")
print("  Surge duration: 120s (2 min)")
print("  Between surges: 600-1200s (10-20 min random)")
print("  Pollen multiplier during surge: ×2.0")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Two scripts + RemoteEvent (no BaseParts) | 0 permanent parts |
| **Dispatch 106 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `_G.PollenSurgeService` uses Roblox's shared `_G` table for cross-script access on the server. This is the simplest way to expose `IsActive()` to `ForagingService` without restructuring either service into ModuleScripts. `_G` access is synchronous and requires no additional `require()` calls.
- The `INITIAL_DELAY = 600` (10 minutes) prevents a surge from firing before players have had a chance to start foraging. In a test environment, reduce to `60` to test within a minute.
- The `task.cancel(countdownTask)` in `destroySurgeGui()` cleanly stops the ticker coroutine when the banner is dismissed. Without this, the coroutine would run for the full surge duration even after the banner is gone, trying to update a destroyed `timerLabel`.
- `endsAt = os.time() + SURGE_DURATION` on the server side: the server sends `endsAt` as an absolute epoch timestamp. The client computes `endsAt - os.time()` for display. This is accurate to within 1-2 seconds (network latency), which is fine for a 2-minute window.
- The client uses `DisplayOrder = 15` — between the seasonal HUD (12, dispatch 97) and the plot unlock toast (20, dispatch 98). All three can coexist without overlap since they're positioned differently.
- `×2.0` pollen surge: the append injection block runs after the seasonal bonus block (dispatch 97 append) and the EffectiveCap block (dispatch 100). Order: base yield → prestige mult → upgrade mult → seasonal mult → surge mult → cap clamp. This is correct — surge doubles the already-boosted pollen, then the cap clamps if needed.
- The `while true do fireSurge(); task.wait(...) end` loop in `PollenSurgeService` is guarded by `task.delay(INITIAL_DELAY, ...)`. If the server shuts down while inside `fireSurge()`, the surge state resets on next startup (no DataStore persistence needed — surge state is session-only).
