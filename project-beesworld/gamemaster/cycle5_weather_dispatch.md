# A Bee's World — Cycle 5 Dispatch: WeatherService

## Overview

This dispatch implements the **5-state weather system**: Clear, Breezy, Overcast, Rain, and Bloom Rush.
Weather is one of the three "living world" features that transform "build a hive" into "defend and adapt."

- **Breezy** gives foragers a 15% speed boost — short window to bank extra honey fast
- **Rain** forces bees to shelter — strategic crisis: is your honey ripe enough to harvest now?
- **Bloom Rush** is a shared-server event (+30% yield) that creates spontaneous social moments ("IS THAT BLOOM RUSH?!")
- **Overcast** signals incoming Rain and slightly emboldens Molasses (his stage 3+ raid preference rises)
- **Rain** at Molasses stage 3+ is his preferred raid window — tense overlap of two threats at once

**Build order for this dispatch:**
1. luau-scripter — Config.WEATHER + WeatherService + WeatherRunner + WeatherController + ForagingService hook + ThreatService hook
2. world-builder — 3 emitter anchor parts at hub (wind / rain / bloom)
3. Verification

---

## Prerequisites

- `fix_bug9_duplicate_dataservice.lua` run in Studio Command Bar (CRITICAL — must be done before any Systems work)
- All prior cycle dispatches executed (cycle3_hub, cycle3_molasses, cycle4_queen, cycle4_floor23, cycle5_shopgui)
- ReplicatedStorage.Remotes folder exists (created by earlier dispatches)
- ReplicatedStorage.Remotes.Notify RemoteEvent exists (used for weather toast messages)
- WeatherChange RemoteEvent does NOT yet exist — this dispatch creates it

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| WindEmitterPart (hub) | 1 |
| RainEmitterPart (hub, high-altitude) | 1 |
| BloomEmitterPart (hub) | 1 |
| **Total new** | **+3** |
| Cumulative worst-case after this dispatch | ~3,702 / 5,000 |

---

## TASK 1 — luau-scripter

Execute these 7 steps in order. Use clone-and-replace (cache busting) for ALL ModuleScript edits.

---

### 1A — ReplicatedStorage.Remotes.WeatherChange RemoteEvent

Create if it does not exist:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not Remotes:FindFirstChild("WeatherChange") then
    local re = Instance.new("RemoteEvent")
    re.Name = "WeatherChange"
    re.Parent = Remotes
    print("WeatherChange created")
else
    print("WeatherChange already exists")
end
```

---

### 1B — Config module additions

Add the following two tables to the Config module using clone-and-replace. Insert them before the final `return Config` line.

**Config.WEATHER** — per-state visual, gameplay, and faction values:

```lua
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
        foragingSpeedMult = 0.0,     -- bees shelter; no new trips dispatched
        yieldMult         = 1.0,
        molassesRaidPref  = 1.5,     -- Molasses prefers raiding in rain
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
        yieldMult         = 1.30,    -- 30% bonus on all nectar delivered
        molassesRaidPref  = 0.5,     -- Molasses distracted by bloom
        windParticles     = false,
        rainParticles     = false,
        bloomParticles    = true,
        toast             = "BLOOM RUSH! All honey yield +30%!",
    },
}

-- Weighted transition table — {nextState, weight} pairs per current state.
-- Rain always returns to Clear. BloomRush only reachable from Breezy (rare).
Config.WEATHER_TRANSITIONS = {
    Clear     = { {"Breezy",   3}, {"Overcast", 2}, {"Clear",    1} },
    Breezy    = { {"Clear",    4}, {"Overcast", 2}, {"BloomRush",1} },
    Overcast  = { {"Rain",     3}, {"Clear",    2}, {"Breezy",   1} },
    Rain      = { {"Clear",    5}, {"Overcast", 1} },
    BloomRush = { {"Clear",    1} },
}
```

**Verification after Config edit:**

```lua
local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
local stateCount = 0
for _ in Config.WEATHER do stateCount = stateCount + 1 end
local transCount = 0
for _ in Config.WEATHER_TRANSITIONS do transCount = transCount + 1 end
return "WEATHER states=" .. stateCount .. " TRANSITIONS keys=" .. transCount
-- Expected: WEATHER states=5 TRANSITIONS keys=5
```

---

### 1C — WeatherService ModuleScript

**Location:** `ServerScriptService.Systems.WeatherService` (new ModuleScript)

```lua
--!strict
-- WeatherService: server-authoritative 5-state weather machine.
-- Exposes read-only multipliers consumed by ForagingService and ThreatService.
-- FiresAllClients via WeatherChange so WeatherController can tween visuals.

local WeatherService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local WeatherChange = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeatherChange") :: RemoteEvent
local Notify        = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notify")        :: RemoteEvent

local _currentState: string = "Clear"
local _yieldMult:   number  = 1.0
local _speedMult:   number  = 1.0
local _raidPref:    number  = 1.0

-- Weighted random selection from {{state, weight}} pairs.
local function weightedRandom(choices: {{any}}): string
    local total = 0
    for _, pair in choices do
        total += (pair[2] :: number)
    end
    local r = math.random() * total
    local acc = 0
    for _, pair in choices do
        acc += (pair[2] :: number)
        if r <= acc then
            return pair[1] :: string
        end
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
    _yieldMult    = cfg.yieldMult
    _speedMult    = cfg.foragingSpeedMult
    _raidPref     = cfg.molassesRaidPref

    -- Notify all clients: visual tween + toast
    WeatherChange:FireAllClients(state)
    if cfg.toast then
        Notify:FireAllClients(cfg.toast)
    end
end

local function runLoop()
    while true do
        local cfg    = Config.WEATHER[_currentState]
        local minD   = cfg.duration[1] :: number
        local maxD   = cfg.duration[2] :: number
        local dur    = minD + math.random() * (maxD - minD)
        task.wait(dur)
        local transitions = Config.WEATHER_TRANSITIONS[_currentState]
        local nextState   = weightedRandom(transitions)
        applyState(nextState)
    end
end

-- Called once from WeatherRunner Script on server startup.
function WeatherService.Start()
    applyState("Clear")
    task.spawn(runLoop)
end

-- Read-only accessors consumed by other services.
function WeatherService.GetCurrentState(): string  return _currentState end
function WeatherService.GetYieldMult():   number   return _yieldMult    end
function WeatherService.GetForagingSpeedMult(): number return _speedMult end
function WeatherService.GetMolassesRaidPref():  number return _raidPref  end

return WeatherService
```

---

### 1D — WeatherRunner Script

**Location:** `ServerScriptService.WeatherRunner` (new Script — NOT a ModuleScript)

This is a thin launcher; the state machine lives in the ModuleScript.

```lua
--!strict
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
local WeatherService = require(Systems:WaitForChild("WeatherService"))
WeatherService.Start()
```

---

### 1E — WeatherController LocalScript

**Location:** `StarterPlayer.StarterPlayerScripts.WeatherController` (new LocalScript)

Handles client-side visual transitions only. Reads Config for target values; tweens Atmosphere and Lighting; toggles hub ParticleEmitters.

```lua
--!strict
-- WeatherController: client-side visual response to weather state changes.
-- Tweens Atmosphere.Density/Spread and Lighting.Ambient/Brightness.
-- Toggles hub ParticleEmitters by name (WindEmitterPart, RainEmitterPart, BloomEmitterPart).

local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config        = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local WeatherChange = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeatherChange") :: RemoteEvent

local TWEEN_INFO = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

local atmosphere: Atmosphere = Lighting:WaitForChild("Atmosphere") :: Atmosphere

-- Emitters are found lazily so this script survives before Hub v2 is built.
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

-- Defer emitter search 5s to let workspace finish loading.
task.delay(5, findEmitters)

local function setEmitter(emitter: ParticleEmitter?, enabled: boolean)
    if emitter then
        emitter.Enabled = enabled
    end
end

WeatherChange.OnClientEvent:Connect(function(state: string)
    local cfg = Config.WEATHER[state]
    if not cfg then return end

    -- Tween atmosphere density and light spread
    TweenService:Create(atmosphere, TWEEN_INFO, {
        Density = cfg.atmosphereDensity :: number,
        Spread  = cfg.atmosphereSpread  :: number,
    }):Play()

    -- Tween global lighting ambient and brightness
    TweenService:Create(Lighting, TWEEN_INFO, {
        Ambient    = Color3.fromRGB(cfg.ambientR :: number, cfg.ambientG :: number, cfg.ambientB :: number),
        Brightness = cfg.brightness :: number,
    }):Play()

    -- Toggle hub particle emitters
    setEmitter(windEmitter,  cfg.windParticles  :: boolean)
    setEmitter(rainEmitter,  cfg.rainParticles  :: boolean)
    setEmitter(bloomEmitter, cfg.bloomParticles :: boolean)
end)
```

---

### 1F — ForagingService hook

**Edit the existing ForagingService ModuleScript** (in `ServerScriptService.Systems.ForagingService`) using clone-and-replace.

Add at the top of the module, after other `require()` calls:

```lua
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
```

**Hook 1 — Block new trips during Rain.**

Find the section where a new forager trip is dispatched (where the trip task.spawn / task.delay occurs). Wrap the dispatch with:

```lua
-- Rain check: foragingSpeedMult == 0 means bees shelter; no new trips.
if WeatherService.GetForagingSpeedMult() == 0 then
    return
end
```

**Hook 2 — Breezy speed bonus.**

In the trip duration calculation (wherever `tripTime` or equivalent is computed from route distance), multiply:

```lua
local weatherSpeed = WeatherService.GetForagingSpeedMult()
-- weatherSpeed is 1.0 normally, 1.15 in Breezy, 0.0 in Rain (blocked above)
local adjustedTripTime = baseTripTime / weatherSpeed
```

**Hook 3 — Bloom Rush yield bonus.**

In the nectar delivery section (wherever `nectarAmount` is finalized before being credited to the honey cell), multiply:

```lua
local yieldMult   = WeatherService.GetYieldMult()
local finalNectar = rawNectar * yieldMult
```

**Verification after ForagingService edit:**

```lua
local FS = require(game:GetService("ServerScriptService").Systems.ForagingService)
local WS = require(game:GetService("ServerScriptService").Systems.WeatherService)
return "ForagingService loaded | WeatherService speedMult=" .. WS.GetForagingSpeedMult()
-- Expected: ...speedMult=1 (starts in Clear state)
```

---

### 1G — ThreatService hook

**Edit the existing ThreatService ModuleScript** (in `ServerScriptService.Systems.ThreatService`) using clone-and-replace.

Add at the top, after other `require()` calls:

```lua
local WeatherService = require(script.Parent:WaitForChild("WeatherService"))
```

**Hook — Rain raid preference modifier.**

In ThreatService, wherever the Molasses raid timer delay is computed (the 4–7 minute scout timer or equivalent), multiply the base delay by the inverse of raidPref:

```lua
local raidPref     = WeatherService.GetMolassesRaidPref()
-- raidPref > 1 = Molasses raids sooner (Rain=1.5, Overcast=1.1)
-- raidPref < 1 = Molasses delays (BloomRush=0.5)
local adjustedDelay = baseRaidDelay / raidPref
```

This means in Rain, the next Molasses raid arrives up to 33% sooner. In Bloom Rush, it arrives up to 50% later (he's distracted by the flowers). This creates the most narratively resonant overlap: foraging is blocked by Rain just as Molasses closes in.

**Verification after ThreatService edit:**

```lua
local TS = require(game:GetService("ServerScriptService").Systems.ThreatService)
local WS = require(game:GetService("ServerScriptService").Systems.WeatherService)
return "ThreatService loaded | WeatherService raidPref=" .. WS.GetMolassesRaidPref()
-- Expected: ...raidPref=1 (starts in Clear state)
```

---

## TASK 2 — world-builder

Place 3 invisible anchor parts at the hub. These parts are never visible; they only host ParticleEmitters that WeatherController toggles. All three parts must be:
- Anchored = true
- CanCollide = false
- Transparency = 1
- CastShadow = false
- Part (not MeshPart — no geometry needed)
- Parent: wherever the hub folder lives after Hub v2 (check `Workspace.ApiarYard` or `Workspace.Hub`)

Confirm hub folder name first:
```lua
local hub = workspace:FindFirstChild("ApiarYard") or workspace:FindFirstChild("Hub") or workspace:FindFirstChild("ApiarYardV2")
return hub and hub.Name or "NOT FOUND"
```

Then build the three parts inside that folder:

---

### WindEmitterPart

- Name: `WindEmitterPart`
- Position: hub centre + (0, 20, 0) — above the meadow canopy, below treeline
- Size: Vector3.new(1, 1, 1)
- ParticleEmitter settings:
  - Name: WindParticles
  - Texture: `rbxasset://textures/particles/smoke_main.dds` (built-in Roblox smoke sheet, gives wispy debris feel)
  - Color: ColorSequence — white (0.9, 0.9, 0.9) throughout
  - LightEmission: 0
  - LightInfluence: 1
  - Lifetime: NumberRange.new(2, 4)
  - Rate: 8
  - Speed: NumberRange.new(6, 14) — horizontal wind feel
  - SpreadAngle: Vector2.new(70, 5) — wide horizontal, minimal vertical
  - RotSpeed: NumberRange.new(-30, 30)
  - Rotation: NumberRange.new(0, 360)
  - Size: NumberSequence — starts 0.3, grows to 0.8 by t=0.5, fades to 0 at t=1
  - Transparency: NumberSequence — 1 at t=0, ramps to 0.6 at t=0.2, stays 0.6 until t=0.8, back to 1 at t=1
  - **Enabled: false** (WeatherController enables this only during Breezy state)

---

### RainEmitterPart

- Name: `RainEmitterPart`
- Position: hub centre + (0, 50, 0) — high altitude, rain falls from above
- Size: Vector3.new(1, 1, 1)
- ParticleEmitter settings:
  - Name: RainParticles
  - Texture: `rbxassetid://1266170557` (thin streak particle — widely used Roblox rain asset)
  - Color: ColorSequence — pale blue-white (0.7, 0.8, 0.9)
  - LightEmission: 0
  - LightInfluence: 1
  - Lifetime: NumberRange.new(0.6, 1.0)
  - Rate: 18
  - Speed: NumberRange.new(30, 45) — fast falling rain
  - SpreadAngle: Vector2.new(5, 0) — nearly vertical, slight spread
  - RotSpeed: NumberRange.new(0, 0)
  - Rotation: NumberRange.new(90, 90) — streak faces downward
  - Size: NumberSequence — thin constant 0.06 throughout lifetime
  - Transparency: NumberSequence — 0.6 throughout (subtle, not intrusive)
  - **Enabled: false**

---

### BloomEmitterPart

- Name: `BloomEmitterPart`
- Position: hub centre + (0, 15, 0) — mid-air, drifting pollen
- Size: Vector3.new(1, 1, 1)
- ParticleEmitter settings:
  - Name: BloomParticles
  - Texture: `rbxassetid://240227702` (petal/sparkle sheet, warm organic feel)
  - Color: ColorSequence — warm amber-gold (1.0, 0.75, 0.2) at t=0, soft cream (0.95, 0.9, 0.7) at t=1
  - LightEmission: 0.15 (slight warm glow, pollen catches sunlight)
  - LightInfluence: 0.8
  - Lifetime: NumberRange.new(3, 6)
  - Rate: 5 — sparse, magical feel (not a blizzard)
  - Speed: NumberRange.new(1, 4) — slow drift
  - SpreadAngle: Vector2.new(60, 60) — omnidirectional drift
  - RotSpeed: NumberRange.new(-10, 10)
  - Rotation: NumberRange.new(0, 360)
  - Size: NumberSequence — starts 0, peaks at 0.4 by t=0.1, holds, fades to 0 at t=1
  - Transparency: NumberSequence — 1 at t=0, 0.5 at t=0.1, 0.5 until t=0.8, 1 at t=1
  - **Enabled: false**

---

### World-builder verification after all 3 parts placed

```lua
local partNames = {"WindEmitterPart", "RainEmitterPart", "BloomEmitterPart"}
local results = {}
for _, name in partNames do
    local part = workspace:FindFirstChild(name, true)
    if not part then
        table.insert(results, "MISSING: " .. name)
    else
        local emitter = part:FindFirstChildOfClass("ParticleEmitter")
        local issues = {}
        if not part.Anchored  then table.insert(issues, "not anchored")  end
        if part.CanCollide    then table.insert(issues, "has CanCollide") end
        if part.Transparency  < 1 then table.insert(issues, "visible: T=" .. part.Transparency) end
        if not emitter        then table.insert(issues, "no ParticleEmitter") end
        if emitter and emitter.Enabled then table.insert(issues, "emitter is ON at start (should be OFF)") end
        if #issues == 0 then
            table.insert(results, "OK: " .. name .. " emitter=" .. (emitter and emitter.Name or "nil"))
        else
            table.insert(results, "ISSUES [" .. name .. "]: " .. table.concat(issues, "; "))
        end
    end
end
return table.concat(results, "\n")
-- Expected: 3x "OK: ..." lines
```

---

## TASK 3 — Final combined verification

Run in Studio Command Bar after all tasks complete. Tests the entire WeatherService stack end-to-end.

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local results = {}
local issues  = {}

-- 1. WeatherChange remote exists
local wc = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild("WeatherChange")
if wc then
    table.insert(results, "PASS: WeatherChange RemoteEvent exists")
else
    table.insert(issues, "FAIL: WeatherChange RemoteEvent missing")
end

-- 2. WeatherService ModuleScript exists
local ws = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("WeatherService")
if ws and ws:IsA("ModuleScript") then
    local lines = select(2, ws.Source:gsub("\n","")) + 1
    local hasStrict   = ws.Source:find("--!strict") ~= nil
    local hasStart    = ws.Source:find("WeatherService%.Start") ~= nil
    local hasGetYield = ws.Source:find("GetYieldMult") ~= nil
    local hasGetSpeed = ws.Source:find("GetForagingSpeedMult") ~= nil
    local hasGetRaid  = ws.Source:find("GetMolassesRaidPref") ~= nil
    table.insert(results, string.format(
        "PASS: WeatherService %d lines | strict=%s start=%s yield=%s speed=%s raid=%s",
        lines, tostring(hasStrict), tostring(hasStart), tostring(hasGetYield), tostring(hasGetSpeed), tostring(hasGetRaid)
    ))
    if not (hasStrict and hasStart and hasGetYield and hasGetSpeed and hasGetRaid) then
        table.insert(issues, "FAIL: WeatherService missing required symbols")
    end
else
    table.insert(issues, "FAIL: WeatherService ModuleScript missing from Systems")
end

-- 3. WeatherRunner Script exists
local wr = SSS:FindFirstChild("WeatherRunner")
if wr and wr:IsA("Script") then
    table.insert(results, "PASS: WeatherRunner Script exists (" .. select(2, wr.Source:gsub("\n","")) + 1 .. " lines)")
else
    table.insert(issues, "FAIL: WeatherRunner Script missing from ServerScriptService")
end

-- 4. WeatherController LocalScript exists
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local wctl = SPS and SPS:FindFirstChild("WeatherController")
if wctl and wctl:IsA("LocalScript") then
    local hasTween     = wctl.Source:find("TweenService")    ~= nil
    local hasOnClient  = wctl.Source:find("OnClientEvent")   ~= nil
    local hasAtmos     = wctl.Source:find("Atmosphere")      ~= nil
    table.insert(results, string.format(
        "PASS: WeatherController LocalScript | tween=%s event=%s atmos=%s",
        tostring(hasTween), tostring(hasOnClient), tostring(hasAtmos)
    ))
else
    table.insert(issues, "FAIL: WeatherController LocalScript missing from StarterPlayerScripts")
end

-- 5. Config.WEATHER block
local ok, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
if ok and Config then
    local stateCount = 0
    for _ in Config.WEATHER or {} do stateCount = stateCount + 1 end
    local transCount = 0
    for _ in Config.WEATHER_TRANSITIONS or {} do transCount = transCount + 1 end
    if stateCount == 5 and transCount == 5 then
        table.insert(results, "PASS: Config.WEATHER has 5 states + 5 transition keys")
    else
        table.insert(issues, "FAIL: Config.WEATHER states=" .. stateCount .. " transitions=" .. transCount .. " (expected 5/5)")
    end
else
    table.insert(issues, "FAIL: Config module not loadable")
end

-- 6. ForagingService has WeatherService require
local fs = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("ForagingService")
if fs then
    local hasWeather = fs.Source:find("WeatherService") ~= nil
    local hasYield   = fs.Source:find("GetYieldMult")   ~= nil
    local hasSpeed   = fs.Source:find("GetForagingSpeedMult") ~= nil
    if hasWeather and hasYield and hasSpeed then
        table.insert(results, "PASS: ForagingService has all 3 WeatherService hooks")
    else
        table.insert(issues, "FAIL: ForagingService missing hooks: weather=" .. tostring(hasWeather) .. " yield=" .. tostring(hasYield) .. " speed=" .. tostring(hasSpeed))
    end
else
    table.insert(issues, "FAIL: ForagingService not found in Systems")
end

-- 7. ThreatService has WeatherService require
local ts = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("ThreatService")
if ts then
    local hasWeather = ts.Source:find("WeatherService") ~= nil
    local hasRaid    = ts.Source:find("GetMolassesRaidPref") ~= nil
    if hasWeather and hasRaid then
        table.insert(results, "PASS: ThreatService has WeatherService raid hook")
    else
        table.insert(issues, "FAIL: ThreatService missing hooks: weather=" .. tostring(hasWeather) .. " raid=" .. tostring(hasRaid))
    end
else
    table.insert(issues, "WARN: ThreatService not found — dispatch cycle3_molasses first")
end

-- 8. Hub emitter parts
local emitterNames = {"WindEmitterPart", "RainEmitterPart", "BloomEmitterPart"}
for _, name in emitterNames do
    local part = workspace:FindFirstChild(name, true)
    if part then
        local emitter = part:FindFirstChildOfClass("ParticleEmitter")
        if part.Anchored and not part.CanCollide and part.Transparency >= 1 and emitter and not emitter.Enabled then
            table.insert(results, "PASS: " .. name .. " correctly configured (enabled=false)")
        else
            table.insert(issues, "FAIL: " .. name .. " misconfigured | anchored=" .. tostring(part.Anchored) .. " emitter=" .. tostring(emitter ~= nil) .. " enabled=" .. tostring(emitter and emitter.Enabled))
        end
    else
        table.insert(issues, "FAIL: " .. name .. " not found in workspace")
    end
end

-- Summary
local out = "=== WEATHER SYSTEM VERIFICATION ===\n"
out = out .. "PASSED: " .. #results .. "\n"
out = out .. "ISSUES: " .. #issues .. "\n\n"
if #results > 0 then
    out = out .. table.concat(results, "\n") .. "\n\n"
end
if #issues > 0 then
    out = out .. "--- ISSUES ---\n" .. table.concat(issues, "\n") .. "\n"
end
if #issues == 0 then
    out = out .. "ALL CHECKS PASSED — WeatherService is live.\n"
    out = out .. "Wait ~10s for WeatherRunner to start, then watch Lighting.Ambient change.\n"
end
return out
```

---

## Live smoke test

After running the verification above with 0 issues, run this to force an immediate state transition and confirm visual changes fire:

```lua
-- Force a state change to BloomRush to test the full chain.
local WS = require(game:GetService("ServerScriptService").Systems.WeatherService)
-- Can't call internal applyState directly (it's local), but we can read current state:
print("Current weather: " .. WS.GetCurrentState())
print("Yield mult: "       .. WS.GetYieldMult())
print("Speed mult: "       .. WS.GetForagingSpeedMult())
print("Raid pref: "        .. WS.GetMolassesRaidPref())
-- Expected: Clear / 1 / 1 / 1 at startup
```

Then enter Play mode and watch the Atmosphere + Lighting tween when the first state transition fires (Clear → Breezy typically within 3–5 minutes of start). The `WeatherChange` toast "It's breezy — foragers are flying fast!" should appear in NotifyGui.

---

## Notes for executor

1. **ThreatService may not exist yet** if cycle3_molasses_dispatch has not been run. The verification script emits a `WARN` rather than `FAIL` for this case — it is not a blocker for WeatherService itself.

2. **ForagingService hooks need care**: The exact variable names (`baseTripTime`, `rawNectar`, etc.) depend on whatever ForagingService was named during its build. Read the ForagingService source first to identify the correct insertion points before editing.

3. **Atmosphere child of Lighting**: If `Lighting:FindFirstChildOfClass("Atmosphere")` returns nil, the Atmosphere object may not have been created yet (depends on Lighting.Technology=Future being set per pending_fix #2). Create it first: `local atm = Instance.new("Atmosphere"); atm.Parent = game:GetService("Lighting")`.

4. **WeatherRunner is a Script, not ModuleScript**: This is intentional. ModuleScripts don't auto-run; WeatherRunner is the executor that calls `WeatherService.Start()` on server boot.

5. **Bloom Rush rarity**: With the transition weights as specified, Bloom Rush can only be reached from Breezy (weight 1 vs total 7 from Breezy). Expected frequency: Breezy occurs roughly 3/6 of the time from Clear, and Bloom Rush is a 1-in-7 chance from Breezy, so roughly 1 Bloom Rush per 6–8 state transitions. At average state durations (~2.5 min each), a Bloom Rush occurs roughly every 15–20 minutes of server uptime. This is intentionally rare to make it a genuine shared-server moment.

---

## State machine visual summary

```
Clear (3-5 min) ──→ Breezy (1.5-2.5 min) ──→ Clear (most likely)
    │                    │                         │
    │                    └──→ BloomRush (rare, 45-60s) ──→ Clear
    │
    └──→ Overcast (1-2 min) ──→ Rain (1-1.5 min) ──→ Clear (almost always)
              │
              └──→ Breezy (sometimes)
```

The game's emotional rhythm around weather:
- Long stretches of Clear (peaceful building)
- Breezy = acceleration (harvest NOW before it ends)
- Overcast = dread (Rain is coming, Molasses is watching)
- Rain = crisis (bees shelter, Molasses could raid any second)
- BloomRush = euphoria (shared server celebration, everyone scrambling)
