# Dispatch 36 — QueenUpgradeVFX: Particle Burst + Sound on Queen Tier Upgrade
**File:** `cycle11_queen_vfx_dispatch.md`
**Cycle:** 11
**Part budget:** +1 → ~4,099/5,000 (1 invisible VFX anchor part per plot, but shared — one per plot = 6 parts max, placed lazily on first upgrade)
**DataService migration:** None
**Depends on:** Dispatch 6 (QueenService upgrade logic), Dispatch 3 (plot layout, 6 plots at X=-250/-150/-50/+50/+150/+250)
**Supersedes:** Nothing

---

## Purpose

Make queen tier upgrades feel **rewarding** with a 2-second particle burst at the queen's
position and a short audio sting. Currently upgrading the queen is silent and invisible —
the tier number increments but nothing else happens.

After this dispatch: upgrading fires a `QueenUpgradeVFX` RemoteEvent to the client, which
plays a golden particle burst + ascending tone sound at the queen's world position.

---

## STEP A — QueenUpgradeVFX RemoteEvent

```lua
-- STEP A: Create QueenUpgradeVFX RemoteEvent in Remotes folder
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
assert(remotes, "Remotes folder not found in ReplicatedStorage")

if not remotes:FindFirstChild("QueenUpgradeVFX") then
    local ev = Instance.new("RemoteEvent")
    ev.Name   = "QueenUpgradeVFX"
    ev.Parent = remotes
    print("✅ STEP A: QueenUpgradeVFX RemoteEvent created")
else
    print("✅ STEP A: QueenUpgradeVFX already exists")
end
```

---

## STEP B — Wire QueenUpgradeVFX fire into QueenService

QueenService handles tier upgrades. Find where it increments the queen tier and add
a `QueenUpgradeVFX:FireClient` call immediately after the upgrade succeeds.

```lua
-- STEP B: Inject QueenUpgradeVFX fire into QueenService
local SSS = game:GetService("ServerScriptService")
local queenSvc = SSS:FindFirstChild("QueenService")
assert(queenSvc, "QueenService not found in ServerScriptService")

local src = queenSvc.Source
if src:find("QueenUpgradeVFX") then
    print("✅ STEP B: QueenService already references QueenUpgradeVFX — no change needed")
else
    local clone = queenSvc:Clone()
    local oldName = queenSvc.Name
    queenSvc.Name = oldName .. "_OLD_36B"
    queenSvc.Parent = nil

    local newSrc = clone.Source

    -- Inject require for QueenUpgradeVFX (after other remotes setup or at top)
    -- Strategy: find where other RemoteEvents are referenced and add after
    local remoteRef = "\nlocal QueenUpgradeVFX = remotes and remotes:FindFirstChild(\"QueenUpgradeVFX\")\n"
    -- Insert after first 'remotes:FindFirstChild' line
    newSrc = newSrc:gsub(
        "(remotes%s*and%s*remotes:FindFirstChild%b())",
        "%1" .. remoteRef,
        1
    )
    if newSrc == clone.Source then
        -- Fallback: look for 'local remotes' line
        newSrc = newSrc:gsub(
            "(local%s+remotes%s*=.-%n)",
            "%1" .. remoteRef,
            1
        )
    end
    if newSrc == clone.Source then
        -- Last resort: prepend at top
        newSrc = remoteRef .. clone.Source
    end

    -- Inject VFX fire after queen tier increment
    -- Match: profile.queenTier = profile.queenTier + 1
    local fireLine = "\n\t\t-- Dispatch 36: VFX burst on upgrade\n\t\tif QueenUpgradeVFX and player then\n\t\t\t-- Find queen's world position from plot structure\n\t\t\tlocal plotX = require(game:GetService(\"ServerScriptService\"):FindFirstChild(\"Config\") or game:GetService(\"ReplicatedStorage\"):FindFirstChild(\"Config\")).PLOT_X_POSITIONS\n\t\t\tlocal plotIndex = player:GetAttribute(\"PlotIndex\") or 1\n\t\t\tlocal queenPos = Vector3.new(plotX and plotX[plotIndex] or 0, 8, 0)\n\t\t\tQueenUpgradeVFX:FireClient(player, { tier = profile.queenTier, position = queenPos })\n\t\tend\n"
    newSrc = newSrc:gsub(
        "(profile%.queenTier%s*=%s*profile%.queenTier%s*%+%s*1)",
        "%1" .. fireLine
    )

    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS

    if clone.Source:find("QueenUpgradeVFX") then
        print("✅ STEP B: QueenUpgradeVFX fire injected into QueenService")
    else
        warn("⚠ STEP B: Could not auto-inject into QueenService — manual wiring needed:")
        warn("   After 'profile.queenTier = profile.queenTier + 1', add:")
        warn("   if QueenUpgradeVFX then QueenUpgradeVFX:FireClient(player, { tier=profile.queenTier, position=Vector3.new(plotX, 8, 0) }) end")
    end
end
```

---

## STEP C — QueenUpgradeVFX LocalScript (particle burst + sound)

```lua
-- STEP C: QueenUpgradeVFXController LocalScript in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("QueenUpgradeVFXController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "QueenUpgradeVFXController"
ctrl.Source = [[
--!strict
-- QueenUpgradeVFXController — particle burst + sound on queen tier upgrade (dispatch 36)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

local remotes          = ReplicatedStorage:WaitForChild("Remotes", 10)
local QueenUpgradeVFX  = remotes:WaitForChild("QueenUpgradeVFX", 10)

-- ---------------------------------------------------------------
-- Particle burst: creates a temporary Part with ParticleEmitter at world position
-- ---------------------------------------------------------------
local function spawnBurst(position: Vector3, tier: number): ()
    -- Anchor part (invisible, will be destroyed after burst)
    local anchor = Instance.new("Part")
    anchor.Name             = "QueenVFXAnchor"
    anchor.Size             = Vector3.new(0.2, 0.2, 0.2)
    anchor.Position         = position
    anchor.Anchored         = true
    anchor.CanCollide       = false
    anchor.CastShadow       = false
    anchor.Transparency     = 1
    anchor.Parent           = workspace

    -- Gold particle burst
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name            = "QueenBurst"
    emitter.Color           = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(242, 168, 28)),  -- Honey Gold
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 212, 154)), -- Wax Cream fade
    })
    emitter.Transparency    = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Size            = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3 + tier * 0.05),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.LightEmission   = 0.8
    emitter.LightInfluence  = 0.2
    emitter.Speed           = NumberRange.new(8, 14)
    emitter.Rate            = 0    -- burst mode: use Emit
    emitter.Lifetime        = NumberRange.new(0.8, 1.6)
    emitter.SpreadAngle     = Vector2.new(180, 180)
    emitter.RotSpeed        = NumberRange.new(-360, 360)
    emitter.Rotation        = NumberRange.new(0, 360)
    emitter.LockedToPart    = false
    emitter.Parent          = anchor

    -- Ring/crown particles (smaller, white)
    local crownEmitter = Instance.new("ParticleEmitter")
    crownEmitter.Name       = "QueenCrown"
    crownEmitter.Color      = ColorSequence.new(Color3.fromRGB(255, 255, 200))
    crownEmitter.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(1, 1),
    })
    crownEmitter.Size       = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.12),
        NumberSequenceKeypoint.new(1, 0),
    })
    crownEmitter.LightEmission = 1.0
    crownEmitter.Speed      = NumberRange.new(5, 10)
    crownEmitter.Rate       = 0
    crownEmitter.Lifetime   = NumberRange.new(0.5, 1.2)
    crownEmitter.SpreadAngle = Vector2.new(90, 90)
    crownEmitter.Parent     = anchor

    -- Fire burst: 20 gold + 12 crown particles
    local burstCount = 15 + tier * 5  -- more particles at higher tiers
    emitter:Emit(math.clamp(burstCount, 20, 60))
    crownEmitter:Emit(12)

    -- Destroy anchor after longest particle lifetime + buffer
    Debris:AddItem(anchor, 2.5)
end

-- ---------------------------------------------------------------
-- Sound: ascending tone for queen upgrade
-- ---------------------------------------------------------------
local function playSound(position: Vector3, tier: number): ()
    local soundPart = Instance.new("Part")
    soundPart.Size          = Vector3.new(0.1, 0.1, 0.1)
    soundPart.Position      = position
    soundPart.Anchored      = true
    soundPart.CanCollide    = false
    soundPart.Transparency  = 1
    soundPart.Parent        = workspace

    local sound = Instance.new("Sound")
    -- Roblox asset: "rbxassetid://0" is a placeholder
    -- Use a built-in Roblox magic sound or a royalty-free upgrade chime
    -- "rbxassetid://9119713993" = Roblox "Level Up" chime (replace with actual ID when available)
    sound.SoundId    = "rbxassetid://9119713993"
    sound.Volume     = 0.6
    sound.RollOffMaxDistance = 80
    sound.PlaybackSpeed = 0.8 + tier * 0.05  -- higher pitch at higher tiers
    sound.Parent     = soundPart
    sound:Play()

    Debris:AddItem(soundPart, 4)
end

-- ---------------------------------------------------------------
-- Screen flash: brief amber center flash
-- ---------------------------------------------------------------
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local flashGui = Instance.new("ScreenGui")
flashGui.Name           = "QueenUpgradeFlash"
flashGui.IgnoreGuiInset = true
flashGui.DisplayOrder   = 55
flashGui.ResetOnSpawn   = false
flashGui.Parent         = playerGui

local flashFrame = Instance.new("Frame")
flashFrame.Name              = "Flash"
flashFrame.Size              = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3  = Color3.fromRGB(242, 168, 28)  -- Honey Gold
flashFrame.BackgroundTransparency = 1  -- hidden
flashFrame.BorderSizePixel   = 0
flashFrame.ZIndex            = 1
flashFrame.Parent            = flashGui

local FLASH_IN  = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLASH_OUT = TweenInfo.new(0.5,  Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function screenFlash(tier: number): ()
    local opacity = math.clamp(0.65 + tier * 0.02, 0.65, 0.80)
    TweenService:Create(flashFrame, FLASH_IN, { BackgroundTransparency = opacity }):Play()
    task.delay(0.12, function(): ()
        TweenService:Create(flashFrame, FLASH_OUT, { BackgroundTransparency = 1 }):Play()
    end)
end

-- ---------------------------------------------------------------
-- Main handler
-- ---------------------------------------------------------------
QueenUpgradeVFX.OnClientEvent:Connect(function(data: { tier: number, position: Vector3 }): ()
    local tier     = data.tier or 1
    local position = data.position or Vector3.new(0, 8, 0)

    spawnBurst(position, tier)
    playSound(position, tier)
    screenFlash(tier)
end)
]]
ctrl.Parent = SPS

print("✅ STEP C: QueenUpgradeVFXController LocalScript created")
```

**Verify Step C:**

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("QueenUpgradeVFXController")
assert(ctrl and ctrl:IsA("LocalScript"), "QueenUpgradeVFXController missing")
local src = ctrl.Source
assert(src:find("QueenUpgradeVFX"), "QueenUpgradeVFX not referenced")
assert(src:find("ParticleEmitter"), "ParticleEmitter not used")
assert(src:find("Debris"), "Debris not used")
assert(src:find("spawnBurst"), "spawnBurst missing")
assert(src:find("screenFlash"), "screenFlash missing")
assert(src:find("--!strict"), "--!strict missing")
print("✅ STEP C verified: QueenUpgradeVFXController correct")
```

---

## STEP D — Tier label toast on upgrade (HiveGui QUEEN tab badge update)

When the VFX fires, also show a quick "Tier N unlocked!" toast using the existing Notify remote,
so players see the feedback even if they're looking away from the queen's world position.

Add this to the QueenUpgradeVFX handler in the server-side QueenService (after Step B):

```lua
-- Inject Notify toast into QueenService alongside VFX fire
-- (run this only if Notify is already referenced in QueenService — most likely is)
local SSS = game:GetService("ServerScriptService")
local queenSvc = SSS:FindFirstChild("QueenService")
assert(queenSvc, "QueenService not found")

local src = queenSvc.Source
if src:find("QueenUpgradeTier") or src:find("Notify.*queenTier") or src:find("queenTier.*Notify") then
    print("✅ STEP D: Notify toast already present in QueenService")
else
    local clone = queenSvc:Clone()
    local oldName = queenSvc.Name
    queenSvc.Name = oldName .. "_OLD_36D"
    queenSvc.Parent = nil

    -- Inject Notify toast after QueenUpgradeVFX fire block
    local toastLine = "\n\t\t-- Notify toast (dispatch 36)\n\t\tlocal notifyRemote = remotes and remotes:FindFirstChild(\"Notify\")\n\t\tif notifyRemote and player then\n\t\t\tnotifyRemote:FireClient(player, { message = \"👑 Queen upgraded to Tier \" .. profile.queenTier .. \"!\", kind = \"success\" })\n\t\tend\n"
    local newSrc = clone.Source:gsub(
        "(QueenUpgradeVFX:FireClient%b())",
        "%1" .. toastLine
    )
    if newSrc == clone.Source then
        -- Fallback: inject after the tier increment block
        newSrc = clone.Source:gsub(
            "(profile%.queenTier%s*=%s*profile%.queenTier%s*%+%s*1.-\n)",
            "%1" .. toastLine,
            1
        )
    end
    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS

    if clone.Source:find("Queen upgraded to Tier") then
        print("✅ STEP D: Notify toast injected into QueenService")
    else
        warn("⚠ STEP D: Could not auto-inject toast — add manually after QueenUpgradeVFX:FireClient block")
    end
end
```

---

## STEP E — Full verification

```lua
-- STEP E: Full dispatch 36 verification
local SSS     = game:GetService("ServerScriptService")
local RS      = game:GetService("ReplicatedStorage")
local SP      = game:GetService("StarterPlayer")
local SPS     = SP:FindFirstChild("StarterPlayerScripts")
local remotes = RS:FindFirstChild("Remotes")
local results = {}
local issues  = {}

-- 1. QueenUpgradeVFX RemoteEvent
if remotes and remotes:FindFirstChild("QueenUpgradeVFX") then
    table.insert(results, "✅ QueenUpgradeVFX RemoteEvent exists")
else
    table.insert(issues, "❌ QueenUpgradeVFX RemoteEvent missing")
end

-- 2. QueenService wired
local queenSvc = SSS:FindFirstChild("QueenService")
if queenSvc and queenSvc.Source:find("QueenUpgradeVFX") then
    table.insert(results, "✅ QueenService references QueenUpgradeVFX")
else
    table.insert(issues, "⚠ QueenService does not reference QueenUpgradeVFX — manual wiring needed")
end

-- 3. QueenUpgradeVFXController LocalScript
local ctrl = SPS and SPS:FindFirstChild("QueenUpgradeVFXController")
if ctrl and ctrl:IsA("LocalScript") then
    local src = ctrl.Source
    if src:find("spawnBurst") and src:find("screenFlash") and src:find("ParticleEmitter") then
        table.insert(results, "✅ QueenUpgradeVFXController: spawnBurst + screenFlash + ParticleEmitter present")
    else
        table.insert(issues, "❌ QueenUpgradeVFXController missing key functions")
    end
else
    table.insert(issues, "❌ QueenUpgradeVFXController missing from StarterPlayerScripts")
end

-- 4. No stale OLD copies
local stale = {}
for _, c in SSS:GetChildren() do
    if c.Name:find("_OLD_36") then table.insert(stale, c.Name) end
end
if #stale == 0 then
    table.insert(results, "✅ No stale _OLD_36x copies in SSS")
else
    table.insert(issues, "⚠ Stale: " .. table.concat(stale, ", ") .. " — destroy them")
end

print("\n=== DISPATCH 36 VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\nISSUES:")
    for _, i in issues do print(i) end
else
    print("\n🎉 All checks passed — dispatch 36 complete!")
    print("   Queen upgrades now fire Honey Gold particle burst + ascending tone + screen flash")
end
```

---

## Execution order checklist

1. ☐ **STEP A** — Create QueenUpgradeVFX RemoteEvent  
2. ☐ **STEP B** — Inject VFX fire into QueenService  
3. ☐ **STEP C** — Create QueenUpgradeVFXController LocalScript  
4. ☐ **STEP D** — Inject Notify toast into QueenService  
5. ☐ **STEP E** — Full verification  

---

## Testing notes

- **Trigger in Command Bar during play-test:**
  ```lua
  local RS = game:GetService("ReplicatedStorage")
  local ev = RS.Remotes:FindFirstChild("QueenUpgradeVFX")
  ev:FireAllClients({ tier = 3, position = Vector3.new(-50, 8, 0) })
  ```
  Should see: Honey Gold particle burst at (-50,8,0), brief amber screen flash, ascending tone.

- **Sound ID:** `rbxassetid://9119713993` is a placeholder. If it fails to load silently,
  replace with any Roblox "chime" or "level up" free audio asset ID from the Toolbox.

- **Part cleanup:** `Debris:AddItem(anchor, 2.5)` ensures VFX anchors are destroyed after 2.5s,
  keeping part budget clean even after many upgrades.

---

## Part budget

| Step | Parts added | Running total |
|------|-------------|---------------|
| A-E  | 0 permanent (Debris-managed temporary anchors) | 4,098 |
| **Total** | **0** | **~4,098 / 5,000** |

*VFX anchor parts are created at runtime and destroyed by Debris after 2.5s — they do not
count toward the permanent part budget.*
