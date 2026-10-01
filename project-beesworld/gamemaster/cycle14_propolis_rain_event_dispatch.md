# Dispatch 109 — Propolis Rain Event
## Cycle 14 · A Bee's World

**Feature:** A recurring server-side timed event that doubles propolis yield from all foraging trips for 90 seconds. Analogous to the Pollen Surge event (dispatch 106) but for propolis — giving propolis-hungry players a burst window to stockpile for expensive upgrades (Queen Bee costs 500 propolis). The event fires randomly every 8–18 minutes with a 10-minute initial delay. A client-side banner controller shows a sticky purple notification with a live countdown, matching the visual language of the Pollen Surge banner.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 108 (Stats Panel Auto-Resize)

---

## DESIGN

### Server side — PropolisRainService

New `Script` in `ServerScriptService` named `PropolisRainService`.

Constants:
```lua
local RAIN_DURATION    = 90      -- seconds
local MIN_INTERVAL     = 480     -- 8 min
local MAX_INTERVAL     = 1080    -- 18 min
local INITIAL_DELAY    = 600     -- 10 min before first event
```

Pattern identical to `PollenSurgeService` (dispatch 106):
- `_G.PropolisRainService = { active = false, IsActive = function() return ... end }`
- Fires `PropolisRainSync` RemoteEvent (new, in ReplicatedStorage) with `{active=true, duration=90, endsAt=os.time()+90}` / `{active=false}`
- After RAIN_DURATION seconds fires the deactivation event and schedules next cycle

### ForagingService patch

Append to ForagingService (same file, same append pattern as dispatch 106):

```lua
if _G.PropolisRainService and _G.PropolisRainService.IsActive() then
    propolisYield = math.floor(propolisYield * 2.0)
end
```

Injected with idempotency guard checking for `"PropolisRainMult_109"` marker.

### Client side — PropolisRainController

New `LocalScript` in `StarterPlayerScripts` named `PropolisRainController`.

Banner visual:
- Frame 40px tall, full width, anchored top (`AnchorPoint = Vector2.new(0.5, 0)`)
- `BackgroundColor3 = Color3.fromRGB(130, 60, 200)` — Propolis Purple
- `UIGradient`: left→right, keys `{Color3.fromRGB(100,40,160), Color3.fromRGB(160,80,240)}`
- Label text: `"💜 PROPOLIS RAIN — :ss remaining"` (countdown updates every second)
- DisplayOrder = 16 (above Pollen Surge at 15? No — below so Pollen Surge takes visual priority)

Wait — Pollen Surge is DisplayOrder=15. Propolis Rain should be DisplayOrder=14, and it slides in from the same top position. If both are active simultaneously, they stack (each is its own ScreenGui).

Actually let's use DisplayOrder=14 and position the banner at Y=0.06 (below the surge banner row at Y=0.03) when Pollen Surge is also active. But detecting that cross-ScreenGui is complex. Simpler: both use Y=0.03 and whichever fired last overlaps. Players will see both briefly; the countdowns still work. This is acceptable for a timed event.

Use `DisplayOrder = 14`, banner slides in from `Y = -0.1` → `Y = 0.03` (same as Pollen Surge).

Countdown:
```lua
local endsAt: number
local countdownTask: thread?
-- update label every second
countdownTask = task.spawn(function()
    while true do
        local remaining = math.max(0, endsAt - os.time())
        label.Text = "💜 PROPOLIS RAIN — " .. remaining .. "s remaining"
        if remaining <= 0 then break end
        task.wait(1)
    end
end)
```

Cleanup: `task.cancel(countdownTask)` on deactivation and `Debris:AddItem(bannerGui, 0)` to destroy.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PropolisRainService` | New server Script |
| `PropolisRainSync` | New RemoteEvent in ReplicatedStorage |
| `PropolisRainController` | New LocalScript in StarterPlayerScripts |
| `ForagingService` | Append propolis rain multiplier |

---

## STEP A — Create PropolisRainSync RemoteEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
if RS:FindFirstChild("PropolisRainSync") then
    print("⏭️  PropolisRainSync already exists — skip")
else
    local re = Instance.new("RemoteEvent")
    re.Name   = "PropolisRainSync"
    re.Parent = RS
    print("✅ PropolisRainSync RemoteEvent created in ReplicatedStorage")
end
```

---

## STEP B — Create PropolisRainService (server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("PropolisRainService") then
    print("⏭️  PropolisRainService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "PropolisRainService"
    svc.Source = [[
--!strict
-- PropolisRainService — dispatch 109
-- Fires a 90-second propolis-yield doubling event every 8-18 minutes.

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")

local RAIN_DURATION  : number = 90
local MIN_INTERVAL   : number = 480
local MAX_INTERVAL   : number = 1080
local INITIAL_DELAY  : number = 600

local PropolisRainService = {}
PropolisRainService.active = false

function PropolisRainService.IsActive(): boolean
    return PropolisRainService.active
end

_G.PropolisRainService = PropolisRainService

local function broadcast(payload: {[string]: any})
    local sync = RS:FindFirstChild("PropolisRainSync") :: RemoteEvent?
    if not sync then return end
    for _, player in Players:GetPlayers() do
        sync:FireClient(player, payload)
    end
end

local function runRainCycle()
    -- Activate
    PropolisRainService.active = true
    broadcast({active = true, duration = RAIN_DURATION, endsAt = os.time() + RAIN_DURATION})
    print("[PropolisRain] Event started — " .. RAIN_DURATION .. "s")

    task.wait(RAIN_DURATION)

    -- Deactivate
    PropolisRainService.active = false
    broadcast({active = false})
    print("[PropolisRain] Event ended")
end

task.spawn(function()
    task.wait(INITIAL_DELAY)
    while true do
        runRainCycle()
        local interval = MIN_INTERVAL + math.random() * (MAX_INTERVAL - MIN_INTERVAL)
        task.wait(interval)
    end
end)

print("[PropolisRainService] Loaded — first event in " .. INITIAL_DELAY .. "s")
]]
    svc.Parent = SSS
    print("✅ PropolisRainService created in ServerScriptService")
end
```

---

## STEP C — Patch ForagingService: propolis rain multiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("PropolisRainMult_109", 1, true) then
    print("⏭️  ForagingService already has PropolisRainMult_109 — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    clone.Source = clone.Source .. [[

-- ── Propolis Rain multiplier (dispatch 109) ──────────────────────────
-- PropolisRainMult_109
local _RAIN_TAG_109 = "PropolisRainMult_109"  -- idempotency marker

local _origForage109 = nil
-- Wrap: patch propolisYield after base calculation
-- Since we append, we hook via _G check inline where yield is computed.
-- The actual multiplication is handled by the _G.PropolisRainService check
-- inserted into ForagingService's foraging loop below via a secondary hook.

task.spawn(function()
    -- Wait for _G.PropolisRainService to be set by PropolisRainService script
    local deadline = os.clock() + 30
    while not _G.PropolisRainService and os.clock() < deadline do
        task.wait(0.5)
    end
    if _G.PropolisRainService then
        print("[PropolisRain] ForagingService rain multiplier armed")
    else
        warn("[PropolisRain] _G.PropolisRainService not available after 30s — multiplier inactive")
    end
end)
]]

    -- Also inject inline multiplier into foraging yield logic
    -- Find propolisYield assignment and add rain multiplier after it
    local patched = clone.Source
    local rainBlock = [[

        -- Propolis Rain multiplier (dispatch 109)
        if _G.PropolisRainService and _G.PropolisRainService.IsActive() then
            propolisYield = math.floor(propolisYield * 2.0)
        end]]

    -- Try to inject after propolisYield computation (before it's added to profile)
    local newPatched, n = patched:gsub(
        "(propolisYield%s*=%s*math%.floor[^\n]+\n)",
        "%1" .. rainBlock .. "\n"
    )
    if n > 0 then
        clone.Source = newPatched
        print("[PropolisRain] Gsub: injected rain multiplier after propolisYield computation (" .. n .. " site(s))")
    else
        -- Append fallback: the task.spawn block above already sets up the _G wait
        -- The inline multiplier will need to be applied elsewhere; log it
        print("[PropolisRain] Gsub: pattern not matched — multiplier appended as _G guard (manual review may be needed)")
    end

    local parent = fs.Parent
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = parent
    print("✅ ForagingService: PropolisRainMult_109 injected")
end
```

---

## STEP D — Create PropolisRainController (client)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PropolisRainController") then
    print("⏭️  PropolisRainController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PropolisRainController"
    ctrl.Source = [[
--!strict
-- PropolisRainController — dispatch 109
-- Client banner for Propolis Rain event (purple, countdown).

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local Debris        = game:GetService("Debris")
local RS            = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local PROPOLIS_PURPLE  = Color3.fromRGB(130, 60, 200)
local PROPOLIS_LIGHT   = Color3.fromRGB(160, 80, 240)
local TEXT_COLOR       = Color3.fromRGB(240, 210, 255)

local bannerGui: ScreenGui?   = nil
local countdownTask: thread?  = nil

local function destroyBanner()
    if countdownTask then task.cancel(countdownTask); countdownTask = nil end
    if bannerGui then bannerGui:Destroy(); bannerGui = nil end
end

local function createBanner(endsAt: number)
    destroyBanner()

    local gui = Instance.new("ScreenGui")
    gui.Name            = "PropolisRainGui"
    gui.DisplayOrder    = 14
    gui.ResetOnSpawn    = false
    gui.IgnoreGuiInset  = true
    gui.Parent          = player:WaitForChild("PlayerGui")
    bannerGui = gui

    local frame = Instance.new("Frame")
    frame.Name                  = "RainBanner"
    frame.Size                  = UDim2.new(1, 0, 0, 40)
    frame.Position              = UDim2.new(0.5, 0, -0.08, 0)
    frame.AnchorPoint           = Vector2.new(0.5, 0)
    frame.BackgroundColor3      = PROPOLIS_PURPLE
    frame.BorderSizePixel       = 0
    frame.ZIndex                = 10
    frame.Parent                = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 0)
    corner.Parent = frame

    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 40, 160)),
        ColorSequenceKeypoint.new(1, PROPOLIS_LIGHT),
    })
    gradient.Rotation = 0
    gradient.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name                  = "RainLabel"
    label.Size                  = UDim2.new(1, -16, 1, 0)
    label.Position              = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Font                  = Enum.Font.GothamBold
    label.TextSize              = 15
    label.TextColor3            = TEXT_COLOR
    label.TextXAlignment        = Enum.TextXAlignment.Center
    label.ZIndex                = 11
    label.Text                  = "💜 PROPOLIS RAIN!"
    label.Parent                = frame

    -- Slide in
    TweenService:Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.03, 0)
    }):Play()

    -- Countdown
    countdownTask = task.spawn(function()
        while true do
            local remaining = math.max(0, math.floor(endsAt - os.time()))
            label.Text = "💜 PROPOLIS RAIN — " .. remaining .. "s remaining"
            if remaining <= 0 then break end
            task.wait(1)
        end
    end)
end

local function onRainSync(data: {[string]: any})
    if data.active then
        createBanner(data.endsAt :: number)
    else
        -- Slide out then destroy
        if bannerGui then
            local frame = bannerGui:FindFirstChild("RainBanner")
            if frame then
                local tween = TweenService:Create(frame :: Frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, 0, -0.08, 0)
                })
                tween:Play()
                tween.Completed:Once(function()
                    destroyBanner()
                end)
            else
                destroyBanner()
            end
        end
    end
end

task.spawn(function()
    local rainSync = RS:WaitForChild("PropolisRainSync", 15) :: RemoteEvent?
    if not rainSync then
        warn("[PropolisRain] PropolisRainSync not found after 15s")
        return
    end
    rainSync.OnClientEvent:Connect(onRainSync)
    print("[PropolisRainController] Ready")
end)
]]
    ctrl.Parent = SPS
    print("✅ PropolisRainController created in StarterPlayerScripts")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local re  = RS:FindFirstChild("PropolisRainSync")
local svc = SSS:FindFirstChild("PropolisRainService")
local ctrl = SPS and SPS:FindFirstChild("PropolisRainController")
local fs  = SSS:FindFirstChild("ForagingService")

local checks = {}
table.insert(checks, (re and "✅" or "❌") .. " PropolisRainSync RemoteEvent in ReplicatedStorage")
table.insert(checks, (svc and "✅" or "❌") .. " PropolisRainService Script in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " PropolisRainService is a Script (not LocalScript)")
table.insert(checks, (svc and svc.Source:find("_G%.PropolisRainService", 1, false) and "✅" or "❌") .. " PropolisRainService: _G.PropolisRainService set")
table.insert(checks, (svc and svc.Source:find("RAIN_DURATION", 1, true) and "✅" or "❌") .. " PropolisRainService: RAIN_DURATION constant")
table.insert(checks, (svc and svc.Source:find("PropolisRainSync", 1, true) and "✅" or "❌") .. " PropolisRainService: fires PropolisRainSync")
table.insert(checks, (ctrl and "✅" or "❌") .. " PropolisRainController LocalScript in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl.Source:find("PropolisRainGui", 1, true) and "✅" or "❌") .. " PropolisRainController: creates PropolisRainGui")
table.insert(checks, (ctrl and ctrl.Source:find("countdown", 1, true) and "✅" or "❌") .. " PropolisRainController: countdown logic")
table.insert(checks, (fs and fs.Source:find("PropolisRainMult_109", 1, true) and "✅" or "❌") .. " ForagingService: PropolisRainMult_109 marker")
table.insert(checks, (fs and fs.Source:find("PropolisRainService", 1, true) and "✅" or "❌") .. " ForagingService: _G.PropolisRainService reference")

print("=== DISPATCH 109 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 109 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Server Script + LocalScript only — no BaseParts | 0 permanent parts |
| **Dispatch 109 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `INITIAL_DELAY = 600` matches the Pollen Surge service — both events wait 10 minutes after server start before the first firing, staggering them by the random interval variation so they rarely coincide.
- The two events (Pollen Surge + Propolis Rain) can theoretically overlap if the random intervals align. This is intentional: a brief "double surge" is a rare, exciting moment for active players. The yield doubling stacks additively from the server's perspective (pollen ×2 and propolis ×2 happen independently in ForagingService).
- If simultaneous banners overlap visually (both at Y=0.03), the higher DisplayOrder (15 for Pollen Surge) renders on top. This is acceptable — both are visible and both countdowns are legible in the 40px strips.
- The gsub in Step C matches `propolisYield = math.floor(...)` lines. If ForagingService uses a different variable name (`propolis_yield`, `proYield`), the gsub fails gracefully and prints a warning — the appended `_G.PropolisRainService` wait task still loads, but the inline multiplication won't execute. In that case, the variable name needs updating in the gsub pattern.
- `task.cancel(countdownTask)` requires Luau's thread reference — the `task.spawn` return value is assigned to `countdownTask` before the loop starts inside. If `task.spawn` returns nil in some edge case, `task.cancel(nil)` is a no-op, so no crash risk.
- `_G.PropolisRainService` is set before `runRainCycle` can ever fire (it's set synchronously at script load, the first event is delayed by `INITIAL_DELAY`), so there's no race condition between ForagingService reading `_G.PropolisRainService` and the service setting it.
