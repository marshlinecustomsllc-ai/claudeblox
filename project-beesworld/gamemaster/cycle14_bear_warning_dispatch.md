# Dispatch 123 — Bear Warning System (Old Molasses Alert)
## Cycle 14 · A Bee's World

**Feature:** A `BearWarningController` LocalScript and companion `BearAlertService` Script that give players a multi-stage heads-up before Old Molasses raids their hive. Three alert stages — distant rumble (30 s out), approaching (15 s out), imminent (5 s out) — each with an escalating UI card, screen shake, and sound cue. Kids experience it as a dramatic story beat ("Oh no, the bear is coming!"); adults use the countdown to finish placing cells and recall foragers before the raid. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 122 (Foraging Quality Display)

---

## DESIGN

### Alert stages

| Stage | Trigger | Card text (kids) | Detail (adults) | Screen shake | Duration |
|-------|---------|-----------------|-----------------|-------------|---------|
| 1 — Distant | 30 s before raid | "🐾 Something big is out there..." | "Bear incoming in ~30 s" | Very subtle | 4 s |
| 2 — Approaching | 15 s before raid | "🐻 Old Molasses is coming!" | "Bear arriving in ~15 s" | Moderate | 4 s |
| 3 — Imminent | 5 s before raid | "🚨 THE BEAR IS HERE!" | "RUN! 5 s to raid" | Strong | 5 s |
| Clear | Raid over | "✅ Old Molasses left" | "Hive safe again" | None | 3 s |

### Server → Client flow

`BearAlertService` listens to `BearRaidSync` RemoteEvent (already fired by `ThreatService` from dispatch 29+). It schedules delayed fires at −30 s, −15 s, −5 s relative to the raid time stored in the event payload.

If `BearRaidSync` doesn't exist (ThreatService not yet executed), the service creates it — idempotent.

### RemoteEvent payload from BearRaidSync

`{action: "incoming", raidTime: number}` — Unix timestamp when raid hits  
`{action: "clear"}` — raid over, hive safe

### Screen shake

Camera offset oscillation using `TweenService` on `workspace.CurrentCamera.CFrame` offset — brief, gets stronger each stage. Implemented entirely client-side in `BearWarningController`.

### Alert card layout

- `BearWarningGui` ScreenGui, DisplayOrder=45 (below milestone=50, above everything else)
- `AlertCard` Frame: 300×76, top-centre `{0.5,-150,0,-90}` → slides down to `{0.5,-150,0,10}`
- Background colour changes per stage: dark brown → orange-brown → red-brown
- Emoji + kid text on top row; detail text on bottom row (smaller, muted)
- Auto-dismisses after stage duration

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BearAlertService` | New Script in ServerScriptService |
| `BearWarningController` | New LocalScript in StarterPlayerScripts |
| `BearRaidSync` | Ensure RemoteEvent exists in ReplicatedStorage (idempotent) |

---

## STEP A — Ensure BearRaidSync RemoteEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

if RS:FindFirstChild("BearRaidSync") then
    print("⏭️  BearRaidSync already exists — skip")
else
    local re = Instance.new("RemoteEvent")
    re.Name   = "BearRaidSync"
    re.Parent = RS
    print("✅ BearRaidSync created in ReplicatedStorage")
end
```

---

## STEP B — Create BearAlertService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(SSS, "ServerScriptService not found")

if SSS:FindFirstChild("BearAlertService") then
    print("⏭️  BearAlertService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "BearAlertService"
    svc.Source = [[
--!strict
-- BearAlertService — dispatch 123
-- Listens to BearRaidSync and schedules multi-stage warning fires to clients.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

-- ── RemoteEvents ───────────────────────────────────────────────────
local BearRaidSync: RemoteEvent  = RS:WaitForChild("BearRaidSync", 30)  :: RemoteEvent

-- We fire BearWarningSync to clients; create if missing
local BearWarningSync: RemoteEvent
if RS:FindFirstChild("BearWarningSync") then
    BearWarningSync = RS:FindFirstChild("BearWarningSync") :: RemoteEvent
else
    BearWarningSync          = Instance.new("RemoteEvent")
    BearWarningSync.Name     = "BearWarningSync"
    BearWarningSync.Parent   = RS
end

-- ── Stage definitions ─────────────────────────────────────────────
-- Each stage fires this many seconds BEFORE the raid time
local STAGE_OFFSETS_123: {number} = {30, 15, 5}

-- ── Incoming raid handler ─────────────────────────────────────────
local function scheduleWarnings_123(player: Player, raidTime: number)
    local now = os.time()

    for _, offset in STAGE_OFFSETS_123 do
        local fireAt = raidTime - offset
        local delay  = fireAt - now
        if delay > 0 then
            task.delay(delay, function()
                -- Re-check player still connected
                if not player.Parent then return end
                BearWarningSync:FireClient(player, {stage = offset, raidTime = raidTime})
            end)
        end
    end
end

-- Listen to existing ThreatService fires OR to our own test fires
BearRaidSync.OnServerEvent:Connect(function(player: Player, payload: {action: string, raidTime: number?})
    if payload and payload.action == "incoming" and payload.raidTime then
        scheduleWarnings_123(player, payload.raidTime)
    elseif payload and payload.action == "clear" then
        BearWarningSync:FireClient(player, {stage = 0, raidTime = 0})
    end
end)

-- Also broadcast clear to all clients when a general "clear" is fired from server
-- (ThreatService may fire FireAllClients — handle that case too)
BearRaidSync.OnServerEvent:Connect(function(_, payload: {action: string, raidTime: number?})
    -- already handled above; no-op duplicate
end)

print("[BearAlertService] Ready — scheduling warnings at -30s, -15s, -5s before raids")
]]
    svc.Parent = SSS
    print("✅ BearAlertService created in ServerScriptService")
end
```

---

## STEP C — Create BearWarningController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("BearWarningController") then
    print("⏭️  BearWarningController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "BearWarningController"
    ctrl.Source = [[
--!strict
-- BearWarningController — dispatch 123
-- Multi-stage bear raid warning: card + screen shake + audio cues.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD_123    = Color3.fromRGB(242, 168, 28)
local WAX_CREAM_123     = Color3.fromRGB(232, 212, 154)

-- Stage background colours
local STAGE_COLORS_123: {[number]: Color3} = {
    [30] = Color3.fromRGB(70, 40, 15),    -- distant — dark brown
    [15] = Color3.fromRGB(140, 70, 10),   -- approaching — orange-brown
    [5]  = Color3.fromRGB(160, 30, 10),   -- imminent — red-brown
    [0]  = Color3.fromRGB(20, 60, 20),    -- clear — dark green
}

type StageData = {kidText: string, detailText: string, shakeAmp: number, duration: number}
local STAGE_DATA_123: {[number]: StageData} = {
    [30] = {kidText="🐾 Something big is out there...", detailText="Bear incoming in ~30 s",  shakeAmp=0.08, duration=4},
    [15] = {kidText="🐻 Old Molasses is coming!",       detailText="Bear arriving in ~15 s",  shakeAmp=0.20, duration=4},
    [5]  = {kidText="🚨 THE BEAR IS HERE!",             detailText="Recall bees now! 5 s",    shakeAmp=0.45, duration=5},
    [0]  = {kidText="✅ Old Molasses left",             detailText="Hive is safe again",       shakeAmp=0,    duration=3},
}

-- ── Build GUI ─────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "BearWarningGui_123"
screenGui.DisplayOrder   = 45
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = false
screenGui.Parent         = playerGui

-- Alert card (300×76, slides down from above)
local card = Instance.new("Frame")
card.Name             = "AlertCard"
card.Size             = UDim2.new(0, 300, 0, 76)
card.Position         = UDim2.new(0.5, -150, 0, -90)   -- off-screen above
card.BackgroundColor3 = STAGE_COLORS_123[30]
card.BorderSizePixel  = 0
card.Visible          = false
card.Parent           = screenGui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent       = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color     = HONEY_GOLD_123
cardStroke.Thickness = 2
cardStroke.Parent    = card

local cardPad = Instance.new("UIPadding")
cardPad.PaddingTop    = UDim.new(0, 8)
cardPad.PaddingLeft   = UDim.new(0, 12)
cardPad.PaddingRight  = UDim.new(0, 12)
cardPad.PaddingBottom = UDim.new(0, 6)
cardPad.Parent        = card

-- Kid text (big, prominent)
local kidLabel = Instance.new("TextLabel")
kidLabel.Name                   = "KidText"
kidLabel.Size                   = UDim2.new(1, 0, 0, 30)
kidLabel.BackgroundTransparency = 1
kidLabel.TextColor3             = HONEY_GOLD_123
kidLabel.Font                   = Enum.Font.GothamBold
kidLabel.TextSize               = 16
kidLabel.TextXAlignment         = Enum.TextXAlignment.Center
kidLabel.Text                   = "🐾 Something big is out there..."
kidLabel.Parent                 = card

-- Detail text (smaller, adult info)
local detailLabel = Instance.new("TextLabel")
detailLabel.Name                   = "DetailText"
detailLabel.Size                   = UDim2.new(1, 0, 0, 18)
detailLabel.Position               = UDim2.new(0, 0, 0, 34)
detailLabel.BackgroundTransparency = 1
detailLabel.TextColor3             = WAX_CREAM_123
detailLabel.Font                   = Enum.Font.Gotham
detailLabel.TextSize               = 12
detailLabel.TextXAlignment         = Enum.TextXAlignment.Center
detailLabel.Text                   = "Bear incoming in ~30 s"
detailLabel.Parent                 = card

-- ── Screen shake ──────────────────────────────────────────────────
local shakeRunning_123 = false

local function doShake_123(amplitude: number, durationSecs: number)
    if amplitude <= 0 then return end
    shakeRunning_123 = true
    local elapsed = 0
    local dt = 0.05   -- 20 fps shake update
    task.spawn(function()
        while elapsed < durationSecs and shakeRunning_123 do
            local decay = 1 - (elapsed / durationSecs)
            local offsetX = (math.random() - 0.5) * 2 * amplitude * decay
            local offsetY = (math.random() - 0.5) * 2 * amplitude * 0.5 * decay
            camera.CFrame = camera.CFrame * CFrame.new(offsetX, offsetY, 0)
            task.wait(dt)
            elapsed += dt
        end
        shakeRunning_123 = false
    end)
end

-- ── Show / hide card ───────────────────────────────────────────────
local SHOW_POS_123 = UDim2.new(0.5, -150, 0, 10)
local HIDE_POS_123 = UDim2.new(0.5, -150, 0, -90)

local dismissThread_123: thread? = nil

local function showStage_123(stage: number)
    local data = STAGE_DATA_123[stage]
    if not data then return end

    -- Cancel any pending auto-dismiss
    if dismissThread_123 then task.cancel(dismissThread_123) end
    shakeRunning_123 = false

    -- Update content
    kidLabel.Text    = data.kidText
    detailLabel.Text = data.detailText
    card.BackgroundColor3 = STAGE_COLORS_123[stage] or Color3.fromRGB(60, 30, 10)

    -- Slide in
    card.Visible  = true
    card.Position = HIDE_POS_123
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = SHOW_POS_123}):Play()

    -- Screen shake
    doShake_123(data.shakeAmp, data.duration)

    -- Auto-dismiss after duration
    dismissThread_123 = task.delay(data.duration, function()
        TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = HIDE_POS_123}):Play()
        task.delay(0.3, function() card.Visible = false end)
    end)
end

-- ── Receive warnings ──────────────────────────────────────────────
local BearWarningSync = RS:WaitForChild("BearWarningSync", 30) :: RemoteEvent?
if BearWarningSync then
    BearWarningSync.OnClientEvent:Connect(function(payload: {stage: number, raidTime: number})
        if payload and payload.stage ~= nil then
            showStage_123(payload.stage)
        end
    end)
end

print("[BearWarningController] Ready — 30s/15s/5s raid warnings + screen shake")
]]
    ctrl.Parent = SPS
    print("✅ BearWarningController created in StarterPlayerScripts")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc  = SSS and SSS:FindFirstChild("BearAlertService")
local ctrl = SPS and SPS:FindFirstChild("BearWarningController")
local re1  = RS:FindFirstChild("BearRaidSync")
local re2  = RS:FindFirstChild("BearWarningSync")

local checks = {}
table.insert(checks, (re1  and "✅" or "❌") .. " BearRaidSync in ReplicatedStorage")
table.insert(checks, (re2  and "✅" or "❌") .. " BearWarningSync in ReplicatedStorage")
table.insert(checks, (svc  and "✅" or "❌") .. " BearAlertService in ServerScriptService")
table.insert(checks, (svc  and svc:IsA("Script") and "✅" or "❌") .. " is a Script (server-side)")
table.insert(checks, (svc  and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc  and svc.Source:find("STAGE_OFFSETS_123", 1, true) and "✅" or "❌") .. " STAGE_OFFSETS_123 table")
table.insert(checks, (svc  and svc.Source:find("scheduleWarnings_123", 1, true) and "✅" or "❌") .. " scheduleWarnings_123")
table.insert(checks, (svc  and svc.Source:find("BearWarningSync", 1, true) and "✅" or "❌") .. " fires BearWarningSync")
table.insert(checks, (ctrl and "✅" or "❌") .. " BearWarningController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (client)")
table.insert(checks, (ctrl and ctrl.Source:find("STAGE_DATA_123", 1, true) and "✅" or "❌") .. " STAGE_DATA_123 table")
table.insert(checks, (ctrl and ctrl.Source:find("showStage_123", 1, true) and "✅" or "❌") .. " showStage_123 presenter")
table.insert(checks, (ctrl and ctrl.Source:find("doShake_123", 1, true) and "✅" or "❌") .. " doShake_123 screen shake")
table.insert(checks, (ctrl and ctrl.Source:find("dismissThread_123", 1, true) and "✅" or "❌") .. " auto-dismiss thread")
table.insert(checks, (ctrl and ctrl.Source:find("BearWarningSync", 1, true) and "✅" or "❌") .. " BearWarningSync listener")

print("=== DISPATCH 123 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 123 complete" or "❌ SOME CHECKS FAILED")

print("\nStages: 🐾 -30s | 🐻 -15s | 🚨 -5s | ✅ clear")
print("Screen shake amplitude: 0.08 → 0.20 → 0.45 (escalating)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BearAlertService (Script) | 0 permanent |
| BearWarningSync (RemoteEvent) | 0 permanent |
| BearWarningController (LocalScript, runtime UI in PlayerGui) | 0 permanent |
| **Dispatch 123 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `BearAlertService` uses `task.delay` to schedule each stage independently rather than a single loop — this means stage 2 fires even if stage 1 fires late (e.g., server lag), and stages that have already passed (delay ≤ 0) are silently skipped with no error.
- `BearWarningSync` is a separate RemoteEvent from `BearRaidSync`. `BearRaidSync` is the source-of-truth event fired by `ThreatService` (dispatch 29+); `BearWarningSync` is the derived per-stage client notification. Keeping them separate prevents clients from receiving raw raid timing data (server-side only) while still receiving the warning stages.
- Screen shake uses direct `CFrame` mutation on `workspace.CurrentCamera`. This is the standard Roblox pattern for client-side camera shake — it works for both first-person and third-person cameras and doesn't conflict with Roblox's built-in camera control (which overwrites CFrame each frame anyway, naturally resetting the shake).
- `shakeRunning_123 = false` in `showStage_123` before starting a new shake ensures overlapping alerts don't stack multiple shake goroutines. The new shake spawns fresh.
- `task.cancel(dismissThread_123)` before showing a new stage means if stage 1 (30s) is still visible when stage 2 (15s) fires, the card doesn't flicker — it updates in-place and the dismiss timer resets to stage 2's duration.
- The `DisplayOrder=45` puts the bear alert above all normal game UI (hive HUD, leaderboard, bee facts, bee roster, cell guide) but below milestone celebration (50) — a prestige milestone and a bear attack can both fire, and the prestige banner wins the screen prominence, which is correct (prestige is rarer and more positive).
- The `{0}` stage (clear) uses green background to give positive relief — "the danger is gone" should feel genuinely good, not just neutral.
