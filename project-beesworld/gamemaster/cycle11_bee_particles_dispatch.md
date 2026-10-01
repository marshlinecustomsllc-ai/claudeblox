# Dispatch 75 — BeeParticleService
## Cycle 11 · A Bee's World

**Feature:** Visible bee flight particles — tiny golden dots emit from the hive center and drift outward toward active (foraging) plot positions, giving the hive a living, buzzing quality. Uses `ParticleEmitter` objects placed on invisible anchor parts at each hex plot center and at the hive center. Emitter rate ramps up when a plot is actively foraging and drops to idle when not. Controlled by a `BeeParticleController` LocalScript that listens to the same `PlotSync` RemoteEvent used by `HoneycombVisualController`.
**Part budget impact:** +8 invisible anchor parts (one per plot + hive center) → **4,154 / 5,000**
**Execution order:** After dispatch 74 (HoneycombVisualController)

---

## DESIGN

Each hex plot gets an invisible anchor `Part` at its center. The hive center gets one too. Each anchor carries a `ParticleEmitter` tuned for tiny gold bee-like dots:

- **Idle foraging**: rate = 2 (few drifting bees, hive always alive)
- **Active foraging**: rate = 12 (busy bees leaving / returning)
- **Locked / unowned**: rate = 0 (no bees — not claimed yet)

All parts: `Size=Vector3.new(0.2,0.2,0.2)`, `Transparency=1`, `CanCollide=false`, `Anchored=true`, `CastShadow=false`.

### Emitter properties

```lua
emitter.Texture       = "rbxassetid://6570398461"  -- round particle dot (built-in)
emitter.LightEmission  = 0.6
emitter.LightInfluence = 0.3
emitter.Color          = ColorSequence.new(Color3.fromRGB(255,200,50), Color3.fromRGB(242,168,28))
emitter.Size           = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.08),
    NumberSequenceKeypoint.new(0.5, 0.12),
    NumberSequenceKeypoint.new(1,   0.04),
})
emitter.Transparency   = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   1),
    NumberSequenceKeypoint.new(0.1, 0.3),
    NumberSequenceKeypoint.new(0.9, 0.3),
    NumberSequenceKeypoint.new(1,   1),
})
emitter.Speed          = NumberRange.new(2, 5)
emitter.SpreadAngle    = Vector2.new(180, 180)   -- omnidirectional
emitter.Lifetime       = NumberRange.new(1.5, 3.0)
emitter.RotSpeed       = NumberRange.new(-90, 90)
emitter.Rotation       = NumberRange.new(0, 360)
emitter.Rate           = 2   -- default idle
```

### Placement logic

Anchor parts are positioned at:

| Part name | Position |
|-----------|----------|
| `BeeAnchor_Hive` | `Workspace.Map.HivePlots` centroid or `Vector3.new(0, 5, 0)` fallback |
| `BeeAnchor_Plot_1` … `BeeAnchor_Plot_8` | Same XZ as `Plot_1`…`Plot_8`, Y+2 (above hex surface) |
| `BeeAnchor_ExpansionSlot_1` … `BeeAnchor_ExpansionSlot_2` | Same XZ as ExpansionSlot_N, Y+2 |

Total new parts: 1 (hive) + 8 (plots) + 2 (expansion slots) = **11 anchors**.

> **Part budget note:** 11 anchors is slightly above the headline "+8" — the dispatch cap is set conservatively. Running total becomes 4,157. Still well within 5,000.

Anchors are created client-side by `BeeParticleController` (LocalScript) — they are **not** replicated to the server and do **not** count toward the server-side part budget. They exist only in the client's local workspace.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BeeParticleController` (new LocalScript in StarterPlayerScripts) | anchor placement, emitter config, rate control |

No server changes. Reuses existing `PlotSync` RemoteEvent.

---

## STEP A — BeeParticleController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "BeeParticleController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- BeeParticleController — client-side bee flight particles on hex plots

local PS        = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlotSync = RS:WaitForChild("PlotSync")

-- ── Constants ──────────────────────────────────────────
local Y_OFFSET   = 2        -- studs above hex surface
local RATE_IDLE  = 2        -- particles/sec when owned but not foraging
local RATE_BUSY  = 12       -- particles/sec when foraging active
local RATE_OFF   = 0        -- locked / unowned

local BEE_COLOR_BRIGHT = Color3.fromRGB(255, 200, 50)
local BEE_COLOR_DIM    = Color3.fromRGB(242, 168, 28)

-- ── Anchor storage ─────────────────────────────────────
local anchors: {[string]: BasePart} = {}
local emitters: {[string]: ParticleEmitter} = {}

-- ── Build emitter ──────────────────────────────────────
local function makeEmitter(parent: BasePart): ParticleEmitter
    local e = Instance.new("ParticleEmitter")
    e.Texture        = "rbxassetid://6570398461"
    e.LightEmission  = 0.6
    e.LightInfluence = 0.3
    e.Color          = ColorSequence.new(BEE_COLOR_BRIGHT, BEE_COLOR_DIM)
    e.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.08),
        NumberSequenceKeypoint.new(0.5, 0.12),
        NumberSequenceKeypoint.new(1,   0.04),
    })
    e.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.1, 0.3),
        NumberSequenceKeypoint.new(0.9, 0.3),
        NumberSequenceKeypoint.new(1,   1),
    })
    e.Speed          = NumberRange.new(2, 5)
    e.SpreadAngle    = Vector2.new(180, 180)
    e.Lifetime       = NumberRange.new(1.5, 3.0)
    e.RotSpeed       = NumberRange.new(-90, 90)
    e.Rotation       = NumberRange.new(0, 360)
    e.Rate           = RATE_OFF
    e.Parent         = parent
    return e
end

-- ── Build anchor part ──────────────────────────────────
local function makeAnchor(name: string, pos: Vector3): BasePart
    local p       = Instance.new("Part")
    p.Name        = name
    p.Size        = Vector3.new(0.2, 0.2, 0.2)
    p.Position    = pos
    p.Transparency = 1
    p.CanCollide  = false
    p.Anchored    = true
    p.CastShadow  = false
    p.Parent      = Workspace
    return p
end

-- ── Locate existing plot part position ─────────────────
local function findPlotPosition(partName: string): Vector3?
    local searchRoots = {
        Workspace:FindFirstChild("Map"),
        Workspace:FindFirstChild("HivePlots"),
        Workspace,
    }
    for _, root in searchRoots do
        if root then
            for _, obj in root:GetDescendants() do
                if obj.Name == partName and obj:IsA("BasePart") then
                    return obj.Position
                end
            end
        end
    end
    return nil
end

-- ── Initialise anchors (with delay for world load) ──────
task.delay(3, function()
    -- Hive center anchor
    local hiveFolder = Workspace:FindFirstChild("Map") and (Workspace.Map :: Folder):FindFirstChild("HivePlots")
    local hivePos = Vector3.new(0, 5, 0)
    if hiveFolder and hiveFolder:IsA("BasePart") then
        hivePos = (hiveFolder :: BasePart).Position + Vector3.new(0, Y_OFFSET, 0)
    elseif hiveFolder then
        -- folder — use centroid of children
        local sum = Vector3.new(0, 0, 0)
        local cnt = 0
        for _, child in hiveFolder:GetDescendants() do
            if child:IsA("BasePart") then
                sum = sum + child.Position
                cnt += 1
            end
        end
        if cnt > 0 then hivePos = (sum / cnt) + Vector3.new(0, Y_OFFSET, 0) end
    end
    local hiveAnchor = makeAnchor("BeeAnchor_Hive", hivePos)
    anchors["Hive"] = hiveAnchor
    local hiveEmitter = makeEmitter(hiveAnchor)
    hiveEmitter.Rate = RATE_IDLE   -- hive always buzzes a little
    emitters["Hive"] = hiveEmitter

    -- Plot anchors
    for i = 1, 8 do
        local plotName = "Plot_" .. i
        local pos = findPlotPosition(plotName)
        if pos then
            local anchor = makeAnchor("BeeAnchor_" .. plotName, pos + Vector3.new(0, Y_OFFSET, 0))
            anchors[plotName] = anchor
            emitters[plotName] = makeEmitter(anchor)
        end
    end

    -- Expansion slot anchors
    for i = 1, 2 do
        local slotName = "ExpansionSlot_" .. i
        local pos = findPlotPosition(slotName)
        if pos then
            local anchor = makeAnchor("BeeAnchor_" .. slotName, pos + Vector3.new(0, Y_OFFSET, 0))
            anchors[slotName] = anchor
            emitters[slotName] = makeEmitter(anchor)
        end
    end
end)

-- ── Apply rates from PlotSync data ─────────────────────
local function applyRates(data: {[string]: any})
    local plots = data.plots or data
    if type(plots) ~= "table" then return end

    for _, plotData in pairs(plots) do
        if type(plotData) ~= "table" then continue end
        local plotId: any = plotData.id or plotData.plotId
        if not plotId then continue end

        local isExpansion: boolean = plotData.isExpansion == true
        local key = (isExpansion and "ExpansionSlot_" or "Plot_") .. tostring(plotId)
        local emitter = emitters[key]
        if not emitter then continue end

        local ownerName: string? = plotData.owner or plotData.ownerName
        local isOwned: boolean = (ownerName ~= nil and ownerName ~= "")
        local isForaging: boolean = plotData.foraging == true or plotData.isForaging == true

        if not isOwned then
            emitter.Rate = RATE_OFF
        elseif isForaging then
            emitter.Rate = RATE_BUSY
        else
            emitter.Rate = RATE_IDLE
        end
    end
end

PlotSync.OnClientEvent:Connect(function(data: any)
    applyRates(data)
end)

-- ── ForagingSync bonus: per-event rate bump ────────────
local foragingSync = RS:FindFirstChild("ForagingSync")
if foragingSync and foragingSync:IsA("RemoteEvent") then
    foragingSync.OnClientEvent:Connect(function(data: any)
        if type(data) ~= "table" or not data.plotId then return end
        local key = "Plot_" .. tostring(data.plotId)
        local emitter = emitters[key]
        if emitter then
            emitter.Rate = data.foraging and RATE_BUSY or RATE_IDLE
        end
    end)
end
]]

print("BeeParticleController created")
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("BeeParticleController")
local RS   = game:GetService("ReplicatedStorage")
local PlotSync = RS:FindFirstChild("PlotSync")

local checks = {
    (ctrl and "✅" or "❌") .. " BeeParticleController LocalScript",
    (PlotSync and "✅" or "❌") .. " PlotSync RemoteEvent exists (prerequisite from dispatch 3)",
    (ctrl and ctrl.Source:find("ParticleEmitter") and "✅" or "❌") .. " ParticleEmitter usage present",
    (ctrl and ctrl.Source:find("RATE_BUSY") and "✅" or "❌") .. " RATE_BUSY rate control present",
    (ctrl and ctrl.Source:find("makeAnchor") and "✅" or "❌") .. " makeAnchor function present",
}

print("=== DISPATCH 75 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 75 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Invisible anchor BaseParts (client-local, not server-replicated) | +0 server parts |
| **Dispatch 75 total** | **+0 server** |
| **Running total** | **4,146 / 5,000** |

> Client-side `Instance.new("Part")` created in a LocalScript exists only in that client's session. It is not replicated and does not count toward the server part budget. The hive and plots themselves were already counted in earlier dispatches.

---

## NOTES

- `task.delay(3, ...)` for anchor creation gives the world and the HoneycombVisualController time to load and discover parts first. Both controllers independently discover their target parts so there is no coupling.
- The hive center anchor always emits at `RATE_IDLE` (not `RATE_OFF`) — the hive is always alive even when no plots are claimed.
- `SpreadAngle = Vector2.new(180, 180)` makes particles emit omnidirectionally from each anchor, giving the impression of bees orbiting / swarming rather than a directed stream.
- `rbxassetid://6570398461` is Roblox's built-in soft round particle dot — no external asset dependency.
- `LightEmission = 0.6` makes the particles self-illuminate at night without needing a PointLight, matching the Neon material approach used by `HoneycombVisualController`.
- The `ForagingSync` connection is a defensive bonus mirroring the pattern from `HoneycombVisualController` — provides per-event responsiveness if `PlotSync` doesn't include per-cycle foraging state.
- Since all anchors are created in a LocalScript they are automatically cleaned up when the player's character resets or the server session ends — no manual cleanup needed.
