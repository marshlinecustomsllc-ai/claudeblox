# A Bee's World — Cycle 10 Dispatch: WeatherService (Full Build)

## Overview

This dispatch **supersedes cycle5_weather_dispatch.md**. Execute this dispatch instead of cycle5.
cycle5_weather_dispatch.md should be **skipped** in the execution queue.

**Why a new dispatch:**
- cycle8_hub_expansion_dispatch.md added `WeatherSync` (not `WeatherChange`) as the remote name for WeatherNoticeController. This dispatch unifies both names — WeatherService fires both remotes so both WeatherController (visual tweens) and WeatherNoticeController (notice board) receive events.
- cycle9_threats_dispatch.md added a 6-stage patience ThreatService with its own scout-loop timing. The old cycle5 ThreatService hook referenced a generic "raid delay" variable that does not exist in cycle9's implementation. This dispatch provides the correct hook site.
- ForagingService hooks are written to be self-contained with explicit find-and-insert guidance.

**What this dispatch builds:**
- Config.WEATHER + Config.WEATHER_TRANSITIONS (5-state cycle)
- ReplicatedStorage.Remotes.WeatherChange + WeatherSync RemoteEvents
- WeatherService ModuleScript (server state machine)
- WeatherRunner Script (thin server launcher)
- WeatherController LocalScript (client visual tween)
- ForagingService: 3 hooks (Rain block / Breezy speed / Bloom Rush yield)
- ThreatService: 1 hook (Molasses stage patience rate adjusted by weather)
- 3 hub emitter anchor parts (Wind / Rain / Bloom)

**No DataService migration required.** Weather state is ephemeral (server memory only) — no per-player persistence needed.

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| WindEmitterPart | 1 |
| RainEmitterPart | 1 |
| BloomEmitterPart | 1 |
| **Total new** | **+3** |
| Running total after this dispatch | ~4,023 / 5,000 |

---

## Prerequisites

- `fix_bug9_duplicate_dataservice.lua` run in Studio Command Bar (CRITICAL)
- All prior cycle dispatches executed through cycle9_threats_dispatch
- ReplicatedStorage.Remotes folder exists
- ReplicatedStorage.Remotes.Notify RemoteEvent exists
- WeatherSync RemoteEvent was created by cycle8_hub_expansion_dispatch — verify:
  ```lua
  local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
  print(Remotes:FindFirstChild("WeatherSync") and "WeatherSync EXISTS" or "WeatherSync MISSING")
  ```
  If it exists, step A below will skip creating it. If missing, step A creates it.

---

## STEP A — RemoteEvents

Run in Studio Command Bar:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local created = {}
for _, name in {"WeatherChange", "WeatherSync"} do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = Remotes
        table.insert(created, name .. " CREATED")
    else
        table.insert(created, name .. " already exists")
    end
end
print(table.concat(created, "\n"))
-- Expected: both lines report exists or created
```

---

## STEP B — Config additions

Using clone-and-replace, add the following two tables to the Config module
(in `ReplicatedStorage.Modules.Config`) immediately before the final `return Config` line.

```lua
-- ─── WEATHER ──────────────────────────────────────────────────────────────
-- foragingSpeedMult: 0 = bees shelter (Rain); >1 = faster trips (Breezy)
-- yieldMult:        nectar multiplier applied at delivery (BloomRush = 1.30)
-- molassesRaidPref: >1 = Molasses ratchets patience faster; <1 = slower
Config.WEATHER = {
    Clear = {
        duration          = {180, 300},
        atmosphereDensity = 0.15,
        atmosphereSpread  = 0.0,
        ambientR = 90,  ambientG = 90,  ambientB = 100,
        brightness        = 2.5,
        foragingSpeedMult = 1.0,
        yieldMult         = 1.0,
        molassesRaidPref  = 1.0,
        windParticles     = false,
        rainParticles     = false,
        bloomParticles    = false,
        toast             = nil,
    },
    Breezy = {
        duration          = {90, 150},
        atmosphereDensity = 0.10,
        atmosphereSpread  = 0.25,
        ambientR = 85,  ambientG = 90,  ambientB = 110,
        brightness        = 2.8,
        foragingSpeedMult = 1.15,
        yieldMult         = 1.0,
        molassesRaidPref  = 1.0,
        windParticles     = true,
        rainParticles     = false,
        bloomParticles    = false,
        toast             = "It's breezy — foragers are flying fast!",
    },
    Overcast = {
        duration          = {60, 120},
        atmosphereDensity = 0.30,
        atmosphereSpread  = 0.10,
        ambientR = 60,  ambientG = 65,  ambientB = 80,
        brightness        = 1.8,
        foragingSpeedMult = 1.0,
        yieldMult         = 1.0,
        molassesRaidPref  = 1.1,
        windParticles     = false,
        rainParticles     = false,
        bloomParticles    = false,
        toast             = "Clouds rolling in...",
    },
    Rain = {
        duration          = {60, 90},
        atmosphereDensity = 0.50,
        atmosphereSpread  = 0.05,
        ambientR = 40,  ambientG = 45,  ambientB = 60,
        brightness        = 1.2,
        foragingSpeedMult = 0.0,     -- 0 = bees shelter; no new foraging trips
        yieldMult         = 1.0,
        molassesRaidPref  = 1.5,     -- Molasses grows impatient 50% faster in rain
        windParticles     = false,
        rainParticles     = true,
        bloomParticles    = false,
        toast             = "Rain! Your bees are sheltering.",
    },
    BloomRush = {
        duration          = {45, 60},
        atmosphereDensity = 0.08,
        atmosphereSpread  = 0.50,
        ambientR = 120, ambientG = 100, ambientB = 60,
        brightness        = 3.5,
        foragingSpeedMult = 1.0,
        yieldMult         = 1.30,    -- +30% nectar yield during bloom
        molassesRaidPref  = 0.5,     -- Molasses distracted; patience ratchets 50% slower
        windParticles     = false,
        rainParticles     = false,
        bloomParticles    = true,
        toast             = "BLOOM RUSH! All honey yield +30%!",
    },
}

-- Weighted transition table — {nextState, weight} pairs.
-- Rain always exits to Clear. BloomRush only reachable from Breezy (rare server event).
Config.WEATHER_TRANSITIONS = {
    Clear     = { {"Breezy",   3}, {"Overcast", 2}, {"Clear",    1} },
    Breezy    = { {"Clear",    4}, {"Overcast", 2}, {"BloomRush",1} },
    Overcast  = { {"Rain",     3}, {"Clear",    2}, {"Breezy",   1} },
    Rain      = { {"Clear",    5}, {"Overcast", 1} },
    BloomRush = { {"Clear",    1} },
}
```

**Verify:**
```lua
local ok, Config = pcall(require, game:GetService("ReplicatedStorage").Modules.Config)
if not ok then print("FAIL: Config not loadable") return end
local sc, tc = 0, 0
for _ in Config.WEATHER or {} do sc = sc + 1 end
for _ in Config.WEATHER_TRANSITIONS or {} do tc = tc + 1 end
print("WEATHER states=" .. sc .. " transitions=" .. tc)
-- Expected: WEATHER states=5 transitions=5
```

---

## STEP C — WeatherService ModuleScript

**Create** `ServerScriptService.Systems.WeatherService` (new ModuleScript).

```lua
--!strict
-- WeatherService: server-authoritative 5-state weather machine.
-- Fires WeatherChange (for WeatherController visual tweens)
-- AND WeatherSync (for WeatherNoticeController notice board).
-- Exposes read-only multipliers consumed by ForagingService and ThreatService.

local WeatherService = {}

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Config             = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
local WeatherChange: RemoteEvent = Remotes:WaitForChild("WeatherChange") :: RemoteEvent
local WeatherSync:   RemoteEvent = Remotes:WaitForChild("WeatherSync")   :: RemoteEvent
local Notify:        RemoteEvent = Remotes:WaitForChild("Notify")        :: RemoteEvent

local _currentState: string = "Clear"
local _yieldMult:   number  = 1.0
local _speedMult:   number  = 1.0
local _raidPref:    number  = 1.0

local function weightedRandom(choices: {{any}}): string
    local total = 0
    for _, pair in choices do total += (pair[2] :: number) end
    local r = math.random() * total
    local acc = 0
    for _, pair in choices do
        acc += (pair[2] :: number)
        if r <= acc then return pair[1] :: string end
    end
    return choices[1][1] :: string
end

local function applyState(state: string)
    local cfg = Config.WEATHER[state]
    if not cfg then
        warn("WeatherService: unknown state " .. tostring(state))
        return
    end
    _currentState = state
    _yieldMult    = cfg.yieldMult  :: number
    _speedMult    = cfg.foragingSpeedMult :: number
    _raidPref     = cfg.molassesRaidPref  :: number

    -- Fire both remotes:
    -- WeatherChange carries state name (string) — consumed by WeatherController
    WeatherChange:FireAllClients(state)
    -- WeatherSync carries {stateName} table — consumed by WeatherNoticeController
    WeatherSync:FireAllClients({stateName = state})

    if cfg.toast then
        Notify:FireAllClients(cfg.toast)
    end
end

local function runLoop()
    while true do
        local cfg  = Config.WEATHER[_currentState]
        local minD = cfg.duration[1] :: number
        local maxD = cfg.duration[2] :: number
        task.wait(minD + math.random() * (maxD - minD))
        local nextState = weightedRandom(Config.WEATHER_TRANSITIONS[_currentState])
        applyState(nextState)
    end
end

function WeatherService.Start()
    applyState("Clear")
    task.spawn(runLoop)
end

-- Read-only accessors consumed by ForagingService and ThreatService.
function WeatherService.GetCurrentState():       string  return _currentState end
function WeatherService.GetYieldMult():          number  return _yieldMult    end
function WeatherService.GetForagingSpeedMult():  number  return _speedMult    end
function WeatherService.GetMolassesRaidPref():   number  return _raidPref     end

return WeatherService
```

---

## STEP D — WeatherRunner Script

**Create** `ServerScriptService.WeatherRunner` (new Script, NOT ModuleScript).

```lua
--!strict
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
local WeatherService = require(Systems:WaitForChild("WeatherService"))
WeatherService.Start()
```

---

## STEP E — WeatherController LocalScript

**Create** `StarterPlayer.StarterPlayerScripts.WeatherController` (new LocalScript).

Handles client-side visual transitions only — tweens Atmosphere and Lighting; toggles hub ParticleEmitters.

```lua
--!strict
-- WeatherController: client-side visual response to weather state changes.
-- Listens on WeatherChange (string state name) from WeatherService.
-- Tweens Atmosphere.Density/Spread and Lighting.Ambient/Brightness.
-- Toggles hub ParticleEmitters by part name.

local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local WeatherChange = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeatherChange") :: RemoteEvent

local TWEEN_INFO = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

-- Wait for Atmosphere (depends on Lighting.Technology being set; gracefully defers).
local atmosphere: Atmosphere? = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
    -- Create one if Technology hasn't been set by pending_fix #2 yet.
    atmosphere = Instance.new("Atmosphere")
    atmosphere.Parent = Lighting
end

-- Emitters found lazily after workspace loads.
local windEmitter:  ParticleEmitter? = nil
local rainEmitter:  ParticleEmitter? = nil
local bloomEmitter: ParticleEmitter? = nil

local function findEmitters()
    for _, obj in workspace:GetDescendants() do
        if obj:IsA("BasePart") then
            local e = obj:FindFirstChildOfClass("ParticleEmitter")
            if e then
                if obj.Name == "WindEmitterPart"  then windEmitter  = e end
                if obj.Name == "RainEmitterPart"  then rainEmitter  = e end
                if obj.Name == "BloomEmitterPart" then bloomEmitter = e end
            end
        end
    end
end

task.delay(5, findEmitters)  -- defer so workspace fully streams in

local function setEmitter(emitter: ParticleEmitter?, enabled: boolean)
    if emitter then emitter.Enabled = enabled end
end

WeatherChange.OnClientEvent:Connect(function(state: string)
    local cfg = Config.WEATHER[state]
    if not cfg then return end

    if atmosphere then
        TweenService:Create(atmosphere, TWEEN_INFO, {
            Density = cfg.atmosphereDensity :: number,
            Spread  = cfg.atmosphereSpread  :: number,
        }):Play()
    end

    TweenService:Create(Lighting, TWEEN_INFO, {
        Ambient    = Color3.fromRGB(
            cfg.ambientR :: number,
            cfg.ambientG :: number,
            cfg.ambientB :: number
        ),
        Brightness = cfg.brightness :: number,
    }):Play()

    setEmitter(windEmitter,  cfg.windParticles  :: boolean)
    setEmitter(rainEmitter,  cfg.rainParticles  :: boolean)
    setEmitter(bloomEmitter, cfg.bloomParticles :: boolean)
end)
```

---

## STEP F — ForagingService patch

Using clone-and-replace, edit `ServerScriptService.Systems.ForagingService`.

**First, read the source to identify exact variable names:**

```lua
local fs = game:GetService("ServerScriptService").Systems.ForagingService
print(fs.Source)
```

Look for:
- Where a new foraging trip is dispatched (likely a `task.spawn` or `task.delay` after route validation)
- Where `tripTime` (or `duration`, `travelTime`, etc.) is computed from route distance
- Where `nectarAmount` (or `rawNectar`, `nectarYield`, etc.) is calculated before crediting the honey cell

**Then add these 3 hooks using clone-and-replace:**

**Hook 0 — require WeatherService (at top, after existing requires):**
```lua
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
```

**Hook 1 — Rain shelter (block new trips when foragingSpeedMult == 0):**

Find the point where a new trip is actually launched (after route validation passes).
Add BEFORE the task.spawn/task.delay:

```lua
-- Rain: bees shelter; no new foraging trips dispatched.
if WeatherService.GetForagingSpeedMult() == 0 then
    return
end
```

**Hook 2 — Breezy speed bonus (shorten tripTime):**

Find where tripTime / travelDuration is computed from distance.
Add AFTER the base calculation:

```lua
-- Weather speed modifier: 1.15 in Breezy, 1.0 normally. Rain blocked above.
local weatherSpeedMult = WeatherService.GetForagingSpeedMult()
if weatherSpeedMult > 0 and weatherSpeedMult ~= 1 then
    tripTime = tripTime / weatherSpeedMult   -- replace 'tripTime' with whatever variable name you found
end
```

**Hook 3 — Bloom Rush yield bonus (multiply final nectar):**

Find where nectar is finalized before crediting the honey cell.
Add BEFORE the credit call:

```lua
-- Bloom Rush: +30% nectar yield. Applied once per delivery.
local weatherYieldMult = WeatherService.GetYieldMult()
if weatherYieldMult ~= 1 then
    nectarAmount = nectarAmount * weatherYieldMult   -- replace 'nectarAmount' with your variable name
end
```

**Verify ForagingService patch:**
```lua
local FS = game:GetService("ServerScriptService").Systems.ForagingService
local WS = game:GetService("ServerScriptService").Systems.WeatherService
local hasWS    = FS.Source:find("WeatherService") ~= nil
local hasYield = FS.Source:find("GetYieldMult") ~= nil
local hasSpeed = FS.Source:find("GetForagingSpeedMult") ~= nil
print("ForagingService hooks: WeatherService=" .. tostring(hasWS) .. " yield=" .. tostring(hasYield) .. " speed=" .. tostring(hasSpeed))
print("Current speedMult=" .. WS.GetForagingSpeedMult() .. " yieldMult=" .. WS.GetYieldMult())
-- Expected all true, speedMult=1, yieldMult=1 at Clear startup
```

---

## STEP G — ThreatService patch

Using clone-and-replace, edit `ServerScriptService.Systems.ThreatService`.

**First, read ThreatService source to find the patience/stage ratchet timing:**

```lua
local ts = game:GetService("ServerScriptService").Systems.ThreatService
print(ts.Source)
```

Look for:
- The patience ratchet timer — the `task.delay` or `task.wait` that advances `molassesStage` over time
- It should be something like `task.wait(STAGE_INTERVAL)` or `task.delay(N, advanceStage)`

**Add these hooks using clone-and-replace:**

**Hook 0 — require WeatherService (at top, after existing requires):**
```lua
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
```

**Hook 1 — Adjust patience ratchet interval by weather raidPref:**

Find the stage advancement timer (the interval at which molassesStage increments).
Add BEFORE the `task.wait` that governs patience advancement:

```lua
-- Rain/Overcast: Molasses grows more impatient (raidPref > 1 = shorter wait interval).
-- BloomRush: Molasses distracted (raidPref < 1 = longer wait interval).
local raidPref = WeatherService.GetMolassesRaidPref()
local adjustedInterval = baseStageInterval / raidPref   -- replace baseStageInterval with your variable
```

If the patience interval is hardcoded inline (not a variable), extract it first:
```lua
-- Before (example):
-- task.wait(420)   -- hardcoded 7-minute patience
-- After:
local BASE_PATIENCE_INTERVAL = 420
local raidPref = WeatherService.GetMolassesRaidPref()
task.wait(BASE_PATIENCE_INTERVAL / raidPref)
```

**Effect:** Rain (raidPref=1.5) makes Molasses advance from stage 1→2 in ~280s instead of ~420s.
BloomRush (raidPref=0.5) slows him to ~840s per stage. This creates the most narratively resonant overlap:
during Rain the player cannot forage AND Molasses is closing in simultaneously.

**Verify ThreatService patch:**
```lua
local TS = game:GetService("ServerScriptService").Systems.ThreatService
local WS = game:GetService("ServerScriptService").Systems.WeatherService
local hasWS   = TS.Source:find("WeatherService") ~= nil
local hasRaid = TS.Source:find("GetMolassesRaidPref") ~= nil
print("ThreatService hooks: WeatherService=" .. tostring(hasWS) .. " raid=" .. tostring(hasRaid))
print("Current raidPref=" .. WS.GetMolassesRaidPref())
-- Expected both true, raidPref=1 at Clear startup
```

---

## STEP H — Hub emitter anchor parts

Three invisible parts hosted in the Apiary Yard hub folder. WeatherController toggles their ParticleEmitters.

**First confirm the hub folder name:**
```lua
local hub = workspace:FindFirstChild("ApiaryYard")
    or workspace:FindFirstChild("ApiarYard")
    or workspace:FindFirstChild("Hub")
    or workspace:FindFirstChild("ApiarYardV2")
print(hub and ("Hub folder: " .. hub.Name) or "NOT FOUND — check workspace top-level folders")
```

Use the returned name as the parent for all 3 parts.

---

### WindEmitterPart

```lua
local hub = workspace:FindFirstChild("ApiaryYard") or workspace:FindFirstChild("ApiarYard") or workspace:FindFirstChild("Hub")
if not hub then error("Hub folder not found") end

local wind = Instance.new("Part")
wind.Name        = "WindEmitterPart"
wind.Size        = Vector3.new(1, 1, 1)
wind.Position    = Vector3.new(0, 20, -200)  -- hub centre XZ, 20 studs above ground
wind.Anchored    = true
wind.CanCollide  = false
wind.Transparency = 1
wind.CastShadow  = false
wind.Parent      = hub

local we = Instance.new("ParticleEmitter")
we.Name          = "WindParticles"
we.Texture       = "rbxasset://textures/particles/smoke_main.dds"
we.Color         = ColorSequence.new(Color3.fromRGB(230, 230, 230))
we.LightEmission = 0
we.LightInfluence = 1
we.Lifetime      = NumberRange.new(2, 4)
we.Rate          = 8
we.Speed         = NumberRange.new(6, 14)
we.SpreadAngle   = Vector2.new(70, 5)
we.RotSpeed      = NumberRange.new(-30, 30)
we.Rotation      = NumberRange.new(0, 360)
we.Size          = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   0.3),
    NumberSequenceKeypoint.new(0.5, 0.8),
    NumberSequenceKeypoint.new(1,   0),
})
we.Transparency  = NumberSequence.new({
    NumberSequenceKeypoint.new(0,   1),
    NumberSequenceKeypoint.new(0.2, 0.6),
    NumberSequenceKeypoint.new(0.8, 0.6),
    NumberSequenceKeypoint.new(1,   1),
})
we.Enabled       = false  -- WeatherController enables only during Breezy
we.Parent        = wind

print("WindEmitterPart created")
```

---

### RainEmitterPart

```lua
local hub = workspace:FindFirstChild("ApiaryYard") or workspace:FindFirstChild("ApiarYard") or workspace:FindFirstChild("Hub")
if not hub then error("Hub folder not found") end

local rain = Instance.new("Part")
rain.Name        = "RainEmitterPart"
rain.Size        = Vector3.new(1, 1, 1)
rain.Position    = Vector3.new(0, 50, -200)  -- higher altitude; rain falls from above
rain.Anchored    = true
rain.CanCollide  = false
rain.Transparency = 1
rain.CastShadow  = false
rain.Parent      = hub

local re = Instance.new("ParticleEmitter")
re.Name          = "RainParticles"
re.Texture       = "rbxassetid://1266170557"  -- thin streak / rain asset
re.Color         = ColorSequence.new(Color3.fromRGB(179, 204, 230))
re.LightEmission = 0
re.LightInfluence = 1
re.Lifetime      = NumberRange.new(0.6, 1.0)
re.Rate          = 18
re.Speed         = NumberRange.new(30, 45)
re.SpreadAngle   = Vector2.new(5, 0)
re.RotSpeed      = NumberRange.new(0, 0)
re.Rotation      = NumberRange.new(90, 90)  -- streak faces downward
re.Size          = NumberSequence.new(0.06) -- thin constant throughout
re.Transparency  = NumberSequence.new(0.6)  -- subtle
re.Enabled       = false
re.Parent        = rain

print("RainEmitterPart created")
```

---

### BloomEmitterPart

```lua
local hub = workspace:FindFirstChild("ApiaryYard") or workspace:FindFirstChild("ApiarYard") or workspace:FindFirstChild("Hub")
if not hub then error("Hub folder not found") end

local bloom = Instance.new("Part")
bloom.Name        = "BloomEmitterPart"
bloom.Size        = Vector3.new(1, 1, 1)
bloom.Position    = Vector3.new(0, 15, -200)  -- mid-air drift height
bloom.Anchored    = true
bloom.CanCollide  = false
bloom.Transparency = 1
bloom.CastShadow  = false
bloom.Parent      = hub

local be = Instance.new("ParticleEmitter")
be.Name          = "BloomParticles"
be.Texture       = "rbxassetid://240227702"  -- petal/sparkle sheet
be.Color         = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 191, 51)),   -- warm amber-gold
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(242, 230, 179)),  -- soft cream
})
be.LightEmission = 0.15   -- slight warm glow; pollen catches sunlight
be.LightInfluence = 0.8
be.Lifetime      = NumberRange.new(3, 6)
be.Rate          = 5      -- sparse; magical feel
be.Speed         = NumberRange.new(1, 4)
be.SpreadAngle   = Vector2.new(60, 60)  -- omnidirectional drift
be.RotSpeed      = NumberRange.new(-10, 10)
be.Rotation      = NumberRange.new(0, 360)
be.Size          = NumberSequence.new({
    NumberSequenceKeypoint.new(0,    0),
    NumberSequenceKeypoint.new(0.1,  0.4),
    NumberSequenceKeypoint.new(0.8,  0.4),
    NumberSequenceKeypoint.new(1,    0),
})
be.Transparency  = NumberSequence.new({
    NumberSequenceKeypoint.new(0,    1),
    NumberSequenceKeypoint.new(0.1,  0.5),
    NumberSequenceKeypoint.new(0.8,  0.5),
    NumberSequenceKeypoint.new(1,    1),
})
be.Enabled       = false
be.Parent        = bloom

print("BloomEmitterPart created")
```

**Verify hub emitters:**
```lua
local names = {"WindEmitterPart", "RainEmitterPart", "BloomEmitterPart"}
for _, name in names do
    local part = workspace:FindFirstChild(name, true)
    if not part then
        print("MISSING: " .. name)
    else
        local emitter = part:FindFirstChildOfClass("ParticleEmitter")
        local ok = part.Anchored and not part.CanCollide and part.Transparency >= 1
                and emitter ~= nil and emitter.Enabled == false
        print((ok and "OK" or "ISSUES") .. ": " .. name)
    end
end
```

---

## STEP I — WeatherNoticeController compatibility check

The cycle8_hub_expansion_dispatch creates `WeatherNoticeController` (LocalScript in StarterPlayerScripts) which listens on `WeatherSync.OnClientEvent` for a table `{stateName: string}`.

This dispatch fires `WeatherSync:FireAllClients({stateName = state})` — **compatible with that expectation**.

**No changes needed to WeatherNoticeController.** However, verify it exists:
```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local wn = SPS and SPS:FindFirstChild("WeatherNoticeController")
print(wn and "WeatherNoticeController EXISTS" or "WeatherNoticeController MISSING — run cycle8_hub_expansion_dispatch first")
```

---

## STEP J — Final verification

Run this complete verification script after all steps:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local results = {}
local issues  = {}

-- 1. RemoteEvents
for _, name in {"WeatherChange", "WeatherSync"} do
    local re = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild(name)
    if re and re:IsA("RemoteEvent") then
        table.insert(results, "PASS: " .. name .. " RemoteEvent exists")
    else
        table.insert(issues, "FAIL: " .. name .. " RemoteEvent missing")
    end
end

-- 2. WeatherService ModuleScript
local ws = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("WeatherService")
if ws and ws:IsA("ModuleScript") then
    local src = ws.Source
    local lines = select(2, src:gsub("\n","")) + 1
    local checks = {
        strict    = src:find("--!strict")          ~= nil,
        start     = src:find("WeatherService%.Start") ~= nil,
        yield     = src:find("GetYieldMult")        ~= nil,
        speed     = src:find("GetForagingSpeedMult") ~= nil,
        raid      = src:find("GetMolassesRaidPref")  ~= nil,
        bothFires = src:find("WeatherChange:FireAllClients") ~= nil
                and src:find("WeatherSync:FireAllClients")   ~= nil,
    }
    local allOk = true
    for k, v in checks do if not v then allOk = false end end
    table.insert(results, string.format(
        "%s: WeatherService %d lines | strict=%s start=%s yield=%s speed=%s raid=%s bothFires=%s",
        allOk and "PASS" or "FAIL",
        lines,
        tostring(checks.strict), tostring(checks.start), tostring(checks.yield),
        tostring(checks.speed),  tostring(checks.raid),  tostring(checks.bothFires)
    ))
    if not allOk then table.insert(issues, "FAIL: WeatherService missing required symbols") end
else
    table.insert(issues, "FAIL: WeatherService ModuleScript missing from Systems")
end

-- 3. WeatherRunner Script
local wr = SSS:FindFirstChild("WeatherRunner")
if wr and wr:IsA("Script") then
    table.insert(results, "PASS: WeatherRunner Script exists")
else
    table.insert(issues, "FAIL: WeatherRunner Script missing from ServerScriptService")
end

-- 4. WeatherController LocalScript
local wctl = SPS and SPS:FindFirstChild("WeatherController")
if wctl and wctl:IsA("LocalScript") then
    local src = wctl.Source
    local ok = src:find("TweenService") ~= nil
            and src:find("WeatherChange") ~= nil
            and src:find("Atmosphere") ~= nil
            and src:find("OnClientEvent") ~= nil
    table.insert(results, (ok and "PASS" or "FAIL") .. ": WeatherController LocalScript")
    if not ok then table.insert(issues, "FAIL: WeatherController missing required symbols") end
else
    table.insert(issues, "FAIL: WeatherController LocalScript missing from StarterPlayerScripts")
end

-- 5. Config.WEATHER
local ok, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
if ok and Config then
    local sc, tc = 0, 0
    for _ in Config.WEATHER or {} do sc = sc + 1 end
    for _ in Config.WEATHER_TRANSITIONS or {} do tc = tc + 1 end
    if sc == 5 and tc == 5 then
        table.insert(results, "PASS: Config.WEATHER 5 states, 5 transition keys")
    else
        table.insert(issues, "FAIL: Config.WEATHER states=" .. sc .. " transitions=" .. tc)
    end
else
    table.insert(issues, "FAIL: Config not loadable")
end

-- 6. ForagingService hooks
local fs = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("ForagingService")
if fs then
    local hasWS    = fs.Source:find("WeatherService")        ~= nil
    local hasYield = fs.Source:find("GetYieldMult")          ~= nil
    local hasSpeed = fs.Source:find("GetForagingSpeedMult")  ~= nil
    if hasWS and hasYield and hasSpeed then
        table.insert(results, "PASS: ForagingService has all 3 WeatherService hooks")
    else
        table.insert(issues, "FAIL: ForagingService missing hooks | WS=" .. tostring(hasWS)
            .. " yield=" .. tostring(hasYield) .. " speed=" .. tostring(hasSpeed))
    end
else
    table.insert(issues, "FAIL: ForagingService not found in Systems")
end

-- 7. ThreatService hook
local ts = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("ThreatService")
if ts then
    local hasWS   = ts.Source:find("WeatherService")       ~= nil
    local hasRaid = ts.Source:find("GetMolassesRaidPref")  ~= nil
    if hasWS and hasRaid then
        table.insert(results, "PASS: ThreatService has WeatherService raid hook")
    else
        table.insert(issues, "FAIL: ThreatService missing hooks | WS=" .. tostring(hasWS)
            .. " raid=" .. tostring(hasRaid))
    end
else
    table.insert(issues, "WARN: ThreatService not found (run cycle9_threats_dispatch first)")
end

-- 8. Hub emitter parts
for _, name in {"WindEmitterPart", "RainEmitterPart", "BloomEmitterPart"} do
    local part = workspace:FindFirstChild(name, true)
    if part then
        local emitter = part:FindFirstChildOfClass("ParticleEmitter")
        local ok2 = part.Anchored and not part.CanCollide
                 and part.Transparency >= 1 and emitter ~= nil and not emitter.Enabled
        table.insert(ok2 and results or issues,
            (ok2 and "PASS" or "FAIL") .. ": " .. name)
    else
        table.insert(issues, "FAIL: " .. name .. " not found in workspace")
    end
end

-- Summary
local out = "=== WEATHER SYSTEM VERIFICATION ===\n"
out = out .. "PASSED: " .. #results .. " | ISSUES: " .. #issues .. "\n\n"
if #results > 0 then out = out .. table.concat(results, "\n") .. "\n\n" end
if #issues > 0 then out = out .. "--- ISSUES ---\n" .. table.concat(issues, "\n") .. "\n" end
if #issues == 0 then
    out = out .. "ALL CLEAR — WeatherService live.\n"
    out = out .. "Wait ~3 min for first state transition, watch Lighting.Ambient tween.\n"
    out = out .. "Toast 'It's breezy...' should appear in NotifyGui on Breezy state.\n"
end
return out
```

---

## State machine rhythm

```
Clear (3–5 min) ──3/6──→ Breezy (1.5–2.5 min) ──4/7──→ Clear
    │                         │                      
    │                         └──1/7──→ BloomRush (45–60s) ──→ Clear (only exit)
    │
    ├──2/6──→ Overcast (1–2 min) ──3/6──→ Rain (1–1.5 min) ──5/6──→ Clear
    │              │
    │              └──1/6──→ Breezy
    │
    └──1/6──→ Clear (stays)
```

**Emotional rhythm:**
- Long Clear stretches = peaceful building
- Breezy = acceleration window (harvest now!)
- Overcast = dread signal (Rain coming, Molasses watching)
- Rain = crisis (bees shelter, Molasses ratchets 50% faster)
- BloomRush = rare shared-server euphoria (~1× per 15–20 min server uptime)

**BloomRush frequency estimate:** From Clear, Breezy chance is 3/6 = 50%. From Breezy, BloomRush chance is 1/7 ≈ 14%. Expected BloomRush roughly every 6–8 state transitions × ~2.5 min avg = every 15–20 minutes. Rare enough to feel special; common enough that each server session has several.

---

## Notes for executor

1. **Do not run cycle5_weather_dispatch.md** — this dispatch supersedes it entirely. The cycle5 dispatch should be marked as superseded in the execution queue.

2. **ForagingService variable names:** Read the ForagingService source before inserting hooks. The exact names `tripTime` / `nectarAmount` are illustrative — use whatever the ForagingService actually calls them. Search for `FORAGING_SPEED` constant or `route.distance` usage to locate the right line.

3. **ThreatService stage interval location:** In cycle9_threats_dispatch.md, the patience ratchet is driven by `Config.MOLASSES_STAGES[stage].patientSeconds` or a similar per-stage wait. The weather hook should scale this wait: `task.wait(Config.MOLASSES_STAGES[stage].patientSeconds / WeatherService.GetMolassesRaidPref())`.

4. **Atmosphere child of Lighting:** WeatherController creates one if missing. However, `Technology=Future` must be set for Atmosphere to render (pending_fix #2 — manual Studio UI change). Visual tweens still fire; they just won't be visible until Future technology is active.

5. **WeatherRunner must be a Script, not ModuleScript:** ModuleScripts do not auto-run. WeatherRunner is the executor that calls `WeatherService.Start()` on server boot. Double-check ClassName after creation.

6. **Hub position constant:** The emitter parts use Position Vector3.new(0, Y, -200). Adjust the X/Z if the hub centre is at a different world position. Check with: `workspace:FindFirstChild("ApiaryYard").PrimaryPart.Position` or inspect the hub folder's child positions.
