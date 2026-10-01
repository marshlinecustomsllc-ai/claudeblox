# A Bee's World — Cycle 11 Dispatch: GuardBeeController + Smoker Interact

## Overview

This dispatch adds two animated threat-system components that were deferred from cycle 9:

1. **GuardBeeController** — a client-only LocalScript that spawns 2 small guard bee figures at each GuardPerch world post and animates them with idle bobbing + alert state (red/fast when WaspAlert fires). The world parts (GuardPerch posts, 2 of them tagged `GuardPerch`) already exist in `Workspace.ThreatZone` from cycle9_threats_dispatch. No server parts added.

2. **Smoker in-world interact** — a physical Smoker prop placed near the MolassesDen entrance with a ProximityPrompt. Using it consumes one `smoker_refill` charge (from ConsumableService, purchased in Shop) and calls `ThreatService.RepelBear(player)` which resets Molasses by 2 stages. A new `UseSmoker` RemoteEvent carries the request server-authoritatively.

**Why these matter:**
- The GuardPerch posts currently stand empty — players can see the perch but no visible bees, making the "guard bee auto-kills wasps" mechanic invisible and unconvincing
- The smoker_refill consumable has been purchasable in the Shop since cycle8, but it does nothing (no in-world object exists to trigger it)

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| SmokerObject world prop (5 parts) | +5 |
| Guard bee bodies (client-only, runtime) | 0 |
| **Total new server parts** | **+5** |
| Running total after this dispatch | ~4,028 / 5,000 |

---

## Prerequisites

- cycle9_threats_dispatch executed: GuardPerch parts tagged `GuardPerch` exist in `Workspace.ThreatZone`, WaspAlert RemoteEvent exists in `ReplicatedStorage.Remotes`
- cycle8_shop_expansion_dispatch executed: ConsumableService exists with `SpendSmokerCharge(player)`, smoker_refill item purchasable
- `fix_bug9_duplicate_dataservice.lua` run in Studio Command Bar

**Verify GuardPerch parts exist:**
```lua
local CS = game:GetService("CollectionService")
local perches = CS:GetTagged("GuardPerch")
print("GuardPerch parts: " .. #perches)
for _, p in perches do print("  " .. p:GetFullName() .. " @ " .. tostring(p.Position)) end
-- Expected: 2 parts, both in Workspace.ThreatZone or descendants
```

---

## STEP A — UseSmoker RemoteEvent

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not Remotes:FindFirstChild("UseSmoker") then
    local re = Instance.new("RemoteEvent")
    re.Name = "UseSmoker"
    re.Parent = Remotes
    print("UseSmoker RemoteEvent created")
else
    print("UseSmoker already exists")
end
```

---

## STEP B — SmokerObject world prop

Place a physical Smoker prop in `Workspace.ThreatZone`. Position it near the MolassesDen entrance so players can naturally interact with it on their way to appease/repel the bear.

**First, find the ThreatZone folder and MolassesDen approximate position:**
```lua
local tz = workspace:FindFirstChild("ThreatZone")
print(tz and "ThreatZone found" or "ThreatZone MISSING")
-- MolassesDen is roughly at the bear area. Check for existing BearAltar:
for _, obj in tz and tz:GetDescendants() or {} do
    if obj.Name == "BearAltar" or obj.Name == "MolassesDen" then
        print(obj.Name .. " @ " .. tostring(obj:IsA("BasePart") and obj.Position or obj:GetPivot().Position))
    end
end
```

**Build the Smoker prop:**
```lua
local CS = game:GetService("CollectionService")
local tz = workspace:FindFirstChild("ThreatZone")
if not tz then error("ThreatZone not found") end

-- Position: 8 studs west of the BearAltar, at ground level.
-- Adjust SmokerX/Z based on where ThreatZone's bear area actually sits.
-- Default: X=30, Y=4.5, Z=-320 (edit after checking BearAltar position above).
local SMOKER_POS = Vector3.new(30, 4.5, -320)

local smokerModel = Instance.new("Model")
smokerModel.Name = "SmokerObject"
smokerModel.Parent = tz

local function mkPart(name, size, pos, color, mat)
    local p = Instance.new("Part")
    p.Name        = name
    p.Size        = size
    p.Position    = pos
    p.Color       = color
    p.Material    = mat or Enum.Material.SmoothPlastic
    p.Anchored    = true
    p.CanCollide  = true
    p.CastShadow  = true
    p.Parent      = smokerModel
    return p
end

-- Base cylinder (the smoker body)
local base = mkPart("SmokerBase",
    Vector3.new(1.6, 2.6, 1.6),
    SMOKER_POS + Vector3.new(0, 0, 0),
    Color3.fromRGB(64, 64, 64),
    Enum.Material.Metal)
base.Shape = Enum.PartType.Cylinder
base.CFrame = CFrame.new(base.Position) * CFrame.Angles(0, 0, math.rad(90))  -- cylinder upright via rotation

-- Lid (slightly wider disc on top)
local lid = mkPart("SmokerLid",
    Vector3.new(0.4, 1.8, 1.8),
    SMOKER_POS + Vector3.new(0, 1.5, 0),
    Color3.fromRGB(50, 50, 50),
    Enum.Material.Metal)
lid.Shape = Enum.PartType.Cylinder
lid.CFrame = CFrame.new(lid.Position) * CFrame.Angles(0, 0, math.rad(90))

-- Spout (small horizontal tube pointing forward)
local spout = mkPart("SmokerSpout",
    Vector3.new(1.0, 0.5, 0.5),
    SMOKER_POS + Vector3.new(0, 0.9, 0.8),
    Color3.fromRGB(60, 60, 60),
    Enum.Material.Metal)

-- Bellows (the pump, rectangular brown leather block)
local bellows = mkPart("SmokerBellows",
    Vector3.new(0.9, 0.9, 1.4),
    SMOKER_POS + Vector3.new(0, -0.3, -1.1),
    Color3.fromRGB(101, 57, 27),
    Enum.Material.SmoothPlastic)

-- Handle (small cylinder sticking up from bellows)
local handle = mkPart("SmokerHandle",
    Vector3.new(1.2, 0.25, 0.25),
    SMOKER_POS + Vector3.new(0, 0.3, -1.1),
    Color3.fromRGB(80, 45, 20),
    Enum.Material.Wood)
handle.Shape = Enum.PartType.Cylinder
handle.CFrame = CFrame.new(handle.Position) * CFrame.Angles(0, 0, math.rad(90))

-- Set PrimaryPart
smokerModel.PrimaryPart = base

-- ProximityPrompt on the base
local pp = Instance.new("ProximityPrompt")
pp.ActionText   = "Use Smoker"
pp.ObjectText   = "Smoker"
pp.KeyboardKeyCode = Enum.KeyCode.E
pp.MaxActivationDistance = 8
pp.HoldDuration = 0.5  -- brief hold to prevent accidental use
pp.Parent       = base

-- Tag it
CS:AddTag(base, "Smoker")
CS:AddTag(smokerModel, "Smoker")

print("SmokerObject built at " .. tostring(SMOKER_POS) .. " | parts: " .. #smokerModel:GetDescendants())
```

---

## STEP C — SmokerHandler Script (server-side)

**Create** `ServerScriptService.SmokerHandler` (new Script):

```lua
--!strict
-- SmokerHandler: server-authoritative smoker usage.
-- Validates the player has smoker_refill charges, spends one, calls ThreatService.RepelBear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Systems   = ServerScriptService:WaitForChild("Systems")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")
local UseSmoker = Remotes:WaitForChild("UseSmoker")   :: RemoteEvent
local Notify    = Remotes:WaitForChild("Notify")       :: RemoteEvent

local ThreatService    = require(Systems:WaitForChild("ThreatService"))
local ConsumableService = require(Systems:WaitForChild("ConsumableService"))

local _cooldowns: {[number]: number} = {}  -- [UserId] = os.clock() last use

UseSmoker.OnServerEvent:Connect(function(player: Player)
    -- Rate limit: 1 use per 5 seconds
    local now = os.clock()
    if (_cooldowns[player.UserId] or 0) + 5 > now then
        Notify:FireClient(player, "Smoker is still cooling down.")
        return
    end
    _cooldowns[player.UserId] = now

    -- Spend a smoker charge
    local spent = ConsumableService.SpendSmokerCharge(player)
    if not spent then
        Notify:FireClient(player, "No smoker refills — buy them from the Shop!")
        return
    end

    -- Repel Molasses (resets stage by Config.SMOKER_REPEL_STAGES_RESET = 2)
    ThreatService.RepelBear(player)
    Notify:FireClient(player, "Smoker fired! Old Molasses backs off.")
end)

-- Clean up cooldowns on leave
game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
    _cooldowns[player.UserId] = nil
end)
```

---

## STEP D — SmokerInteractController LocalScript

**Create** `StarterPlayer.StarterPlayerScripts.SmokerInteractController` (new LocalScript):

```lua
--!strict
-- SmokerInteractController: fires UseSmoker when the player triggers the Smoker ProximityPrompt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local UseSmoker = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseSmoker") :: RemoteEvent

-- Wire up any Smoker-tagged ProximityPrompts (handles the world part placed by this dispatch).
local function bindSmoker(obj: Instance)
    if not obj:IsA("BasePart") then return end
    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
    if not pp then return end
    pp.Triggered:Connect(function(_player: Player)
        UseSmoker:FireServer()
    end)
end

-- Bind already-streamed Smoker parts
for _, obj in CollectionService:GetTagged("Smoker") do
    bindSmoker(obj)
end

-- Bind any that stream in later
CollectionService:GetInstanceAddedSignal("Smoker"):Connect(bindSmoker)
```

---

## STEP E — GuardBeeController LocalScript

This is the main animation system. Guard bees are client-only — they are created at runtime by this script and never saved to the datamodel.

**Create** `StarterPlayer.StarterPlayerScripts.GuardBeeController` (new LocalScript):

```lua
--!strict
-- GuardBeeController: spawns and animates guard bee figures at GuardPerch world posts.
-- Entirely client-side — bee models are never replicated, never saved, zero server cost.
-- Idle: 2 bees orbit the perch post with a gentle vertical bob.
-- Alert: WaspAlert fires → bees turn red/orange, orbit faster, scale up slightly.
-- Alert duration: 35s (slightly longer than WaspAlertController's 30s countdown so the
--   bees are still active when the swat window closes).

local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WaspAlert = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WaspAlert") :: RemoteEvent

-- ── Bee model factory ──────────────────────────────────────────────────────
-- Creates a 4-part guard bee Model parented to workspace (client-only).
-- Returns the model and its root CFrame attachment.

type BeeModel = {
    model:  Model,
    root:   Part,
    body:   Part,
    wingL:  Part,
    wingR:  Part,
    head:   Part,
}

local function makeBee(index: number): BeeModel
    local model = Instance.new("Model")
    model.Name = "GuardBee_" .. index

    -- Body: slightly elongated cylinder
    local body = Instance.new("Part") :: Part
    body.Name        = "Body"
    body.Size        = Vector3.new(0.9, 0.45, 0.45)
    body.Shape       = Enum.PartType.Cylinder
    body.Material    = Enum.Material.SmoothPlastic
    body.Color       = Color3.fromRGB(242, 168, 28)   -- Honey Gold
    body.Anchored    = true
    body.CanCollide  = false
    body.CanQuery    = false
    body.CanTouch    = false
    body.CastShadow  = false
    body.Massless    = true
    body.CFrame      = CFrame.Angles(0, 0, math.rad(90))   -- cylinder horizontal
    body.Parent      = model

    -- Head
    local head = Instance.new("Part") :: Part
    head.Name        = "Head"
    head.Size        = Vector3.new(0.35, 0.35, 0.35)
    head.Shape       = Enum.PartType.Ball
    head.Material    = Enum.Material.SmoothPlastic
    head.Color       = Color3.fromRGB(30, 20, 10)     -- near-black
    head.Anchored    = true
    head.CanCollide  = false
    head.CanQuery    = false
    head.CanTouch    = false
    head.CastShadow  = false
    head.Massless    = true
    head.Parent      = model

    -- Left wing
    local wingL = Instance.new("Part") :: Part
    wingL.Name        = "WingL"
    wingL.Size        = Vector3.new(0.04, 0.55, 0.7)
    wingL.Material    = Enum.Material.Glass
    wingL.Color       = Color3.fromRGB(210, 240, 255)
    wingL.Transparency = 0.45
    wingL.Anchored    = true
    wingL.CanCollide  = false
    wingL.CanQuery    = false
    wingL.CanTouch    = false
    wingL.CastShadow  = false
    wingL.Massless    = true
    wingL.Parent      = model

    -- Right wing
    local wingR = wingL:Clone()
    wingR.Name   = "WingR"
    wingR.Parent = model

    model.PrimaryPart = body
    model.Parent = workspace

    return {
        model = model,
        root  = body,
        body  = body,
        wingL = wingL,
        wingR = wingR,
        head  = head,
    }
end

-- ── Per-perch state ────────────────────────────────────────────────────────

type PerchState = {
    perchPart: BasePart,
    bees:      {BeeModel},
    isAlert:   boolean,
    alertUntil: number,
}

local perchStates: {PerchState} = {}

local IDLE_COLORS = {
    body = Color3.fromRGB(242, 168, 28),   -- Honey Gold
    head = Color3.fromRGB(30, 20, 10),     -- near-black
}
local ALERT_COLORS = {
    body = Color3.fromRGB(220, 60, 30),    -- red-orange
    head = Color3.fromRGB(80, 10, 5),      -- dark red
}

local IDLE_ORBIT_SPEED  = 0.6   -- radians/sec
local ALERT_ORBIT_SPEED = 2.2
local BOB_AMPLITUDE     = 0.35  -- studs
local BOB_FREQUENCY     = 1.8   -- Hz
local ORBIT_RADIUS      = 1.8   -- studs from perch centre
local BEE_HEIGHT        = 3.0   -- studs above perch surface
local ALERT_DURATION    = 35    -- seconds

-- Create bees for each perch (deferred until after workspace loads)
local function initPerch(perchPart: BasePart)
    local bees: {BeeModel} = {}
    for i = 1, 2 do
        table.insert(bees, makeBee(#perchStates * 2 + i))
    end
    table.insert(perchStates, {
        perchPart  = perchPart,
        bees       = bees,
        isAlert    = false,
        alertUntil = 0,
    })
end

-- ── Alert signal ─────────────────────────────────────────────────────────

WaspAlert.OnClientEvent:Connect(function(_data: any)
    local alertEnd = os.clock() + ALERT_DURATION
    for _, state in perchStates do
        state.isAlert    = true
        state.alertUntil = alertEnd
        -- Tween bee color to alert palette
        for _, bee in state.bees do
            TweenService:Create(bee.body, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
                Color = ALERT_COLORS.body,
                Size  = Vector3.new(1.1, 0.55, 0.55),
            }):Play()
            TweenService:Create(bee.head, TweenInfo.new(0.5), {
                Color = ALERT_COLORS.head,
            }):Play()
        end
    end
end)

-- ── Main animation loop ───────────────────────────────────────────────────

local elapsed = 0

RunService.Heartbeat:Connect(function(dt: number)
    elapsed = elapsed + dt
    local now = os.clock()

    for _, state in perchStates do
        -- Check alert expiry
        if state.isAlert and now > state.alertUntil then
            state.isAlert = false
            for _, bee in state.bees do
                TweenService:Create(bee.body, TweenInfo.new(1, Enum.EasingStyle.Sine), {
                    Color = IDLE_COLORS.body,
                    Size  = Vector3.new(0.9, 0.45, 0.45),
                }):Play()
                TweenService:Create(bee.head, TweenInfo.new(1), {
                    Color = IDLE_COLORS.head,
                }):Play()
            end
        end

        local orbitSpeed = state.isAlert and ALERT_ORBIT_SPEED or IDLE_ORBIT_SPEED
        local perchCF    = state.perchPart.CFrame

        for i, bee in state.bees do
            local phase = elapsed * orbitSpeed + (i - 1) * math.pi  -- 180° apart
            local bobY  = math.sin(elapsed * BOB_FREQUENCY * math.tau / 2 + (i - 1) * math.pi) * BOB_AMPLITUDE

            local orbitX = math.cos(phase) * ORBIT_RADIUS
            local orbitZ = math.sin(phase) * ORBIT_RADIUS

            local worldPos = perchCF.Position
                + Vector3.new(orbitX, BEE_HEIGHT + bobY, orbitZ)

            -- Face direction of travel (tangent to orbit)
            local tangentAngle = phase + math.pi / 2
            local lookDir = Vector3.new(math.cos(tangentAngle), 0, math.sin(tangentAngle))
            local beeVec  = if lookDir.Magnitude > 0 then lookDir.Unit else Vector3.new(1, 0, 0)

            local beeCF = CFrame.lookAt(worldPos, worldPos + beeVec)
                        * CFrame.Angles(0, math.rad(90), 0)  -- body cylinder faces forward

            -- Update parts
            bee.body.CFrame  = beeCF
            bee.head.CFrame  = beeCF * CFrame.new(0.55, 0, 0)  -- slightly forward
            bee.wingL.CFrame = beeCF * CFrame.new(0, 0.3, -0.4)
                             * CFrame.Angles(math.rad(-25), 0, 0)
            bee.wingR.CFrame = beeCF * CFrame.new(0, 0.3,  0.4)
                             * CFrame.Angles(math.rad( 25), 0, 0)
        end
    end
end)

-- ── Init ─────────────────────────────────────────────────────────────────

-- Defer 5s to let ThreatZone parts stream in.
task.delay(5, function()
    for _, perch in CollectionService:GetTagged("GuardPerch") do
        if perch:IsA("BasePart") then
            initPerch(perch)
        end
    end
    -- Handle parts that stream in after the delay.
    CollectionService:GetInstanceAddedSignal("GuardPerch"):Connect(function(obj: Instance)
        if obj:IsA("BasePart") then
            initPerch(obj :: BasePart)
        end
    end)
end)

-- ── Cleanup on character removal ─────────────────────────────────────────
-- Bees are parented to workspace — destroy them so they don't linger between respawns.
game:GetService("Players").LocalPlayer.CharacterRemoving:Connect(function()
    for _, state in perchStates do
        for _, bee in state.bees do
            bee.model:Destroy()
        end
    end
    table.clear(perchStates)
end)
```

---

## STEP F — ClientMain wiring

Using clone-and-replace, patch `StarterPlayerScripts.ClientMain` to add both new controllers:

**Find the last `require(...):Init()` block and insert after it:**
```lua
local GuardBeeController    = require(Controllers:WaitForChild("GuardBeeController"))
local SmokerInteractController = require(Controllers:WaitForChild("SmokerInteractController"))
GuardBeeController.Init()         -- if your script uses .Init() pattern
SmokerInteractController.Init()   -- if your script uses .Init() pattern
```

**Important:** GuardBeeController and SmokerInteractController are LocalScripts in `StarterPlayerScripts`, NOT in a `Controllers` ModuleScript subfolder. If ClientMain uses `require(Controllers:WaitForChild(...))` for Controllers subfolder ModuleScripts, these two work differently — they're standalone LocalScripts that auto-run, no require needed.

**Check how existing controllers are wired:**
```lua
local cm = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("ClientMain")
print(cm and cm.Source:sub(1, 500) or "NOT FOUND")
```

If the existing controllers are `require()`'d ModuleScripts in a `Controllers` folder, move GuardBeeController and SmokerInteractController there as ModuleScripts (not LocalScripts) and add Init() patterns. If they're standalone LocalScripts, no wiring is needed — they auto-run on join.

**For the ModuleScript approach**, wrap each controller in a module:
```lua
-- GuardBeeController as ModuleScript (if ClientMain uses require() pattern)
local GuardBeeController = {}
function GuardBeeController.Init()
    -- [paste the body of the LocalScript here, minus the top-level module wrapper]
end
return GuardBeeController
```

---

## STEP G — Verification

Run in Studio Command Bar after all steps:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local CS  = game:GetService("CollectionService")
local results = {}
local issues  = {}

-- 1. UseSmoker RemoteEvent
local useSmoker = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("UseSmoker")
if useSmoker and useSmoker:IsA("RemoteEvent") then
    table.insert(results, "PASS: UseSmoker RemoteEvent exists")
else
    table.insert(issues, "FAIL: UseSmoker RemoteEvent missing")
end

-- 2. SmokerObject world prop
local smokerParts = CS:GetTagged("Smoker")
local smokerModels = {}
for _, obj in smokerParts do
    if obj:IsA("Model") then table.insert(smokerModels, obj) end
end
if #smokerParts >= 1 then
    -- Check for ProximityPrompt on the base
    local hasPP = false
    for _, obj in smokerParts do
        if obj:IsA("BasePart") and obj:FindFirstChildOfClass("ProximityPrompt") then
            hasPP = true
        end
    end
    table.insert(results, "PASS: SmokerObject exists (" .. #smokerParts .. " tagged parts, PP=" .. tostring(hasPP) .. ")")
    if not hasPP then table.insert(issues, "FAIL: SmokerObject missing ProximityPrompt on a tagged BasePart") end
else
    table.insert(issues, "FAIL: No Smoker-tagged parts found in workspace")
end

-- 3. SmokerHandler Script
local sh = SSS:FindFirstChild("SmokerHandler")
if sh and sh:IsA("Script") then
    local src = sh.Source
    local ok = src:find("UseSmoker") ~= nil
            and src:find("SpendSmokerCharge") ~= nil
            and src:find("RepelBear") ~= nil
            and src:find("--!strict") ~= nil
    table.insert(ok and results or issues,
        (ok and "PASS" or "FAIL") .. ": SmokerHandler Script (strict=" .. tostring(src:find("--!strict") ~= nil) .. " spendCharge=" .. tostring(src:find("SpendSmokerCharge") ~= nil) .. " repel=" .. tostring(src:find("RepelBear") ~= nil) .. ")")
else
    table.insert(issues, "FAIL: SmokerHandler Script missing from ServerScriptService")
end

-- 4. SmokerInteractController
local sic = SPS and SPS:FindFirstChild("SmokerInteractController")
if sic then
    local hasUseSmoker = sic.Source:find("UseSmoker") ~= nil
    local hasTrigger   = sic.Source:find("Triggered") ~= nil
    table.insert(hasUseSmoker and hasTrigger and results or issues,
        (hasUseSmoker and hasTrigger and "PASS" or "FAIL") .. ": SmokerInteractController (useSmoker=" .. tostring(hasUseSmoker) .. " trigger=" .. tostring(hasTrigger) .. ")")
else
    table.insert(issues, "FAIL: SmokerInteractController missing from StarterPlayerScripts")
end

-- 5. GuardBeeController
local gbc = SPS and SPS:FindFirstChild("GuardBeeController")
if gbc then
    local src = gbc.Source
    local ok = src:find("GuardPerch") ~= nil
            and src:find("WaspAlert") ~= nil
            and src:find("RunService") ~= nil
            and src:find("Heartbeat") ~= nil
    table.insert(ok and results or issues,
        (ok and "PASS" or "FAIL") .. ": GuardBeeController (perch=" .. tostring(src:find("GuardPerch") ~= nil) .. " alert=" .. tostring(src:find("WaspAlert") ~= nil) .. " heartbeat=" .. tostring(src:find("Heartbeat") ~= nil) .. ")")
else
    table.insert(issues, "FAIL: GuardBeeController missing from StarterPlayerScripts")
end

-- 6. GuardPerch world parts still exist
local perches = CS:GetTagged("GuardPerch")
if #perches == 2 then
    table.insert(results, "PASS: 2 GuardPerch tagged parts exist in workspace")
elseif #perches > 0 then
    table.insert(results, "PASS (partial): " .. #perches .. " GuardPerch tagged parts (expected 2)")
else
    table.insert(issues, "FAIL: No GuardPerch tagged parts (run cycle9_threats_dispatch first)")
end

-- Summary
local out = "=== GUARD BEES + SMOKER VERIFICATION ===\n"
out = out .. "PASSED: " .. #results .. " | ISSUES: " .. #issues .. "\n\n"
if #results > 0 then out = out .. table.concat(results, "\n") .. "\n\n" end
if #issues > 0 then out = out .. "--- ISSUES ---\n" .. table.concat(issues, "\n") .. "\n" end
if #issues == 0 then
    out = out .. "ALL CLEAR.\n"
    out = out .. "Play mode test: stand near SmokerObject and press E -- should see 'No smoker refills' toast.\n"
    out = out .. "Guard bees will appear at GuardPerch posts ~5s after joining (streaming delay).\n"
    out = out .. "Trigger WaspAlert via debug: game:GetService('ReplicatedStorage').Remotes.WaspAlert:FireAllClients({plotIndex=1,raidId='test'})\n"
end
return out
```

---

## Live smoke tests (Play mode)

**Smoker test (no charges):**
1. Enter Play mode
2. Walk to the SmokerObject near MolassesDen
3. Press E — expect toast "No smoker refills — buy them from the Shop!"

**Guard bee test:**
1. Enter Play mode
2. Walk toward ThreatZone — within ~10 seconds (streaming delay), two small yellow/black bees should appear orbiting each GuardPerch post
3. Open Studio Command Bar, paste:
   ```lua
   game:GetService("ReplicatedStorage").Remotes.WaspAlert:FireAllClients({plotIndex=1, raidId="dbg"})
   ```
4. Bees should turn red-orange and orbit faster for ~35 seconds, then return to Honey Gold

**Smoker test (with charges):**
1. In Play mode, open Command Bar:
   ```lua
   -- Add a test smoker charge directly to profile (bypass shop)
   local DS = require(game:GetService("ServerScriptService").Systems.DataService)
   local profile = DS.GetProfile(game.Players:GetPlayers()[1])
   if profile then
       profile.data.consumables = profile.data.consumables or {}
       profile.data.consumables.smoker_refill = (profile.data.consumables.smoker_refill or 0) + 3
       print("Added 3 smoker charges")
   end
   ```
2. Walk to SmokerObject, press E — expect toast "Smoker fired! Old Molasses backs off."
3. Check Molasses stage dropped by 2 (visible in MolassesSync data or logs)

---

## Notes for executor

1. **SmokerObject position:** The `SMOKER_POS = Vector3.new(30, 4.5, -320)` is a default. Run the position check in Step B first to find where BearAltar actually sits, then adjust X/Z to place the Smoker ~8 studs to the side of the lane entrance. The Y value should be the ground surface Y in ThreatZone (typically 4.5 for the bear lane floor).

2. **Controller architecture choice:** If ClientMain uses a `Controllers` subfolder of ModuleScripts (check the source), both new controllers need to be ModuleScripts with `Init()` functions. If they're standalone LocalScripts in StarterPlayerScripts root, they auto-run — no ClientMain edit needed. Step F documents both paths.

3. **Cylinder CFrame rotation:** Roblox Cylinders extend along their Y-axis by default. To make a cylinder horizontal (bee body, smoker body), apply `CFrame.Angles(0, 0, math.rad(90))` which rotates the Y-axis to align with world X. The Part.Shape = Cylinder property must be set BEFORE the CFrame.

4. **Guard bee cleanup on respawn:** The `CharacterRemoving` cleanup at the bottom of GuardBeeController destroys all bee models on death/respawn, then the `task.delay(5, ...)` init block re-creates them after the 5s streaming window. This prevents ghost bees accumulating across respawns.

5. **ThreatService.RepelBear vs ThreatService.Repel:** cycle9_threats_dispatch.md defines the function as `ThreatService.RepelBear(player: Player)`. Verify the exact name by reading ThreatService source: `print(game:GetService("ServerScriptService").Systems.ThreatService.Source:sub(1, 2000))`. If it's named differently, update SmokerHandler accordingly.
