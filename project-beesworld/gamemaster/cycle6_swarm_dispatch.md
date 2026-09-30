# A Bee's World — Cycle 6 Dispatch: SwarmService

## Overview

This dispatch implements **Signature Moment 5: The Swarm** — the prestige mechanic at the 45–60 minute mark.

When a player's hive reaches swarm-ready state and they interact with the SwarmPerch:
1. A golden departure beam rises from the Landing Board through the treeline
2. An 8-second silence sequence plays — camera pulls wide, then cuts to black
3. The hive resets with **20% honey carry-over**, structures preserved, generation increments
4. A server-wide Notify fires: "eXemptAttempt's hive has swarmed! Generation 2"
5. A new Royal Cell cracks open — the cycle begins again

From the epic checklist: _"The Swarm — your bees leave. Silence. Then a royal cell cracks open."_
This is the emotional payoff for long-term play and the game's most social moment.

**Build order:**
1. luau-scripter — DataService migration (generation field), SwarmService, SwarmController, RemoteEvents, ProximityPrompt wiring
2. world-builder — SwarmPerch placement at all 6 plots
3. Verification

---

## Prerequisites

- All cycle 3/4/5 dispatches executed (especially cycle4_queen for queenTier profile field)
- fix_bug9_duplicate_dataservice.lua already run
- SwarmPerch mesh template already exists in `ReplicatedStorage.Templates` (confirmed in cycle 2 mesh pass)
- `ReplicatedStorage.Remotes` folder exists
- `ReplicatedStorage.Remotes.Notify` RemoteEvent exists

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| SwarmPerch × 6 (one per plot, template mesh) | ~18 (3/each est.) |
| Sky anchor Part for departure beam × 6 | 6 |
| **Total new** | **~24** |
| Cumulative worst-case | ~3,726 / 5,000 |

---

## Design Constants

```
SWARM_PREREQUISITES = {
    queenTier      = 3,       -- must have a laying queen
    minCells       = 15,      -- 15/19 Floor 1 cells built
    minHoney       = 5000,    -- meaningful honey banked
}

SWARM_CARRY_OVER    = 0.20   -- 20% of current honey

SWARM_SEQUENCE_SECS = 8      -- seconds between SwarmBegin and profile reset

SWARM_PERCH_LOCAL_OFFSET = {x=0, y=5, z=50}   -- plot-local, behind hex lattice back row
```

---

## TASK 1 — luau-scripter

Execute these steps in order. Use clone-and-replace for ALL ModuleScript edits.

---

### 1A — New RemoteEvents

Create in `ReplicatedStorage.Remotes` if they don't exist:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
for _, name in {"SwarmBegin", "SwarmComplete", "RequestSwarm"} do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new(name == "RequestSwarm" and "RemoteEvent" or "RemoteEvent")
        re.Name  = name
        re.Parent = Remotes
        print("Created: " .. name)
    else
        print("Exists: " .. name)
    end
end
-- SwarmBegin:   server → client (starts VFX/camera sequence)
-- SwarmComplete: server → client (rebuild prompt + generation message)
-- RequestSwarm:  client → server (player pressed SwarmPerch ProximityPrompt)
```

---

### 1B — DataService migration: v4 → v5 (generation field)

**Edit `ServerScriptService.Systems.DataService`** using clone-and-replace.

**In PROFILE_TEMPLATE**, add after `queenTier`:
```lua
generation = 0,
```

**In MIGRATIONS table**, add migration index 4 (v4→v5):
```lua
[4] = function(profile)
    if profile.generation == nil then
        profile.generation = 0
    end
    return profile
end,
```

Increment the version check so profiles saved at v4 get migrated:
```lua
-- Find the version constant (something like: local CURRENT_VERSION = 4)
-- Change to:
local CURRENT_VERSION = 5
```

**Verification after DataService edit:**

```lua
-- Force a fresh profile load to trigger the migration path
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
local template = DS.GetProfileTemplate and DS.GetProfileTemplate() or nil
-- If GetProfileTemplate is not exposed, check Source directly:
local src = game:GetService("ServerScriptService").Systems.DataService.Source
local hasGenField   = src:find("generation") ~= nil
local hasMigration4 = src:find("%[4%]") ~= nil
local hasVersion5   = src:find("CURRENT_VERSION%s*=%s*5") ~= nil or src:find("= 5") ~= nil
return "generation field=" .. tostring(hasGenField) .. " migration[4]=" .. tostring(hasMigration4) .. " v5=" .. tostring(hasVersion5)
-- Expected: generation field=true migration[4]=true v5=true
```

---

### 1C — SwarmService ModuleScript

**Location:** `ServerScriptService.Systems.SwarmService` (new ModuleScript)

```lua
--!strict
-- SwarmService: prestige reset mechanic — "The Swarm."
-- Player-triggered from SwarmPerch. Validates prerequisites, runs the
-- 8-second departure sequence, carries over 20% honey, resets plot to
-- generation N+1, fires server-wide notification.

local SwarmService = {}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local Notify      = Remotes:WaitForChild("Notify")       :: RemoteEvent
local SwarmBegin  = Remotes:WaitForChild("SwarmBegin")   :: RemoteEvent
local SwarmComplete = Remotes:WaitForChild("SwarmComplete") :: RemoteEvent
local RequestSwarm  = Remotes:WaitForChild("RequestSwarm")  :: RemoteEvent

local DataService = require(script.Parent:WaitForChild("DataService"))
local PlotService = require(script.Parent:WaitForChild("PlotService"))
local CombService = require(script.Parent:WaitForChild("CombService"))

local CARRY_OVER   = 0.20
local SEQ_DURATION = 8

local MIN_QUEEN_TIER = 3
local MIN_CELLS      = 15
local MIN_HONEY      = 5000

-- Guard against double-trigger on the same plot
local _swarmLocked: {[number]: boolean} = {}

local function canSwarm(profile: {[string]: any}): (boolean, string)
    local queenTier = (profile.queenTier :: number?) or 0
    if queenTier < MIN_QUEEN_TIER then
        return false, "Queen must be tier " .. MIN_QUEEN_TIER .. "+ (yours is tier " .. queenTier .. ")"
    end
    local cellCount = 0
    for _ in (profile.cells :: {[string]: any}?) or {} do
        cellCount += 1
    end
    if cellCount < MIN_CELLS then
        return false, "Build at least " .. MIN_CELLS .. " cells first (" .. cellCount .. "/" .. MIN_CELLS .. " built)"
    end
    local honey = (profile.honey :: number?) or 0
    if honey < MIN_HONEY then
        return false, "Bank at least " .. MIN_HONEY .. " honey first (you have " .. honey .. ")"
    end
    return true, ""
end

local function performSwarm(player: Player, plotIndex: number)
    if _swarmLocked[plotIndex] then return end
    _swarmLocked[plotIndex] = true

    local profile = DataService.GetProfile(player)
    if not profile then
        _swarmLocked[plotIndex] = nil
        return
    end

    local ok, reason = canSwarm(profile)
    if not ok then
        Notify:FireClient(player, "Can't swarm yet: " .. reason)
        _swarmLocked[plotIndex] = nil
        return
    end

    -- Fire client-side sequence (VFX + camera pull)
    SwarmBegin:FireClient(player, plotIndex)

    -- Wait for the departure animation to play out
    task.wait(SEQ_DURATION)

    -- Carry-over math
    local currentHoney = (profile.honey :: number?) or 0
    local carryHoney   = math.floor(currentHoney * CARRY_OVER)
    local generation   = ((profile.generation :: number?) or 0) + 1

    -- Reset profile — structures persist, resources and cells clear
    profile.honey          = carryHoney
    profile.propolis       = 0
    profile.pollen         = 0
    profile.royalJelly     = 0
    profile.cells          = {}
    profile.unlockedFloors = {["1"] = true}
    profile.queenTier      = 1
    profile.castes         = {forager = 85, nurse = 0, guard = 10, drone = 5}
    profile.generation     = generation

    -- Save immediately
    local saveOk = pcall(DataService.Save, player)
    if not saveOk then
        warn("SwarmService: DataService.Save failed for " .. player.Name)
    end

    -- Wipe comb visuals via CombService
    if CombService.WipeAllCells then
        CombService.WipeAllCells(plotIndex)
    end

    -- Server-wide social notification
    Notify:FireAllClients(player.Name .. "'s hive has swarmed! Generation " .. generation .. " begins.")

    -- Notify swarm player with their carry amount
    SwarmComplete:FireClient(player, generation, carryHoney)

    _swarmLocked[plotIndex] = nil
end

-- Validate RequestSwarm from client — owner check only; all gameplay checks in performSwarm
RequestSwarm.OnServerEvent:Connect(function(player: Player)
    local plotIndex = PlotService.GetPlotIndex(player)
    if not plotIndex then return end
    task.spawn(performSwarm, player, plotIndex)
end)

-- Public: used by SwarmPerch ProximityPrompt .Triggered connection
function SwarmService.CanSwarm(player: Player): (boolean, string)
    local profile = DataService.GetProfile(player)
    if not profile then return false, "Profile not loaded" end
    return canSwarm(profile)
end

return SwarmService
```

---

### 1D — CombService.WipeAllCells addition

**Edit `ServerScriptService.Systems.CombService`** using clone-and-replace.

Add this function at the end of CombService, before `return CombService`:

```lua
-- Called by SwarmService on prestige reset. Destroys all physical cell parts
-- for a plot and clears the plot root's cell tracking attributes.
function CombService.WipeAllCells(plotIndex: number)
    local plotRoot = PlotService.GetPlotRoot(plotIndex)
    if not plotRoot then return end

    -- Remove all tagged cell parts under this plot
    local CS = game:GetService("CollectionService")
    local toDestroy: {BasePart} = {}
    for _, part in CS:GetTagged("HexCell") do
        if part:GetAttribute("PlotIndex") == plotIndex then
            table.insert(toDestroy, part)
        end
    end
    for _, part in toDestroy do
        part:Destroy()
    end

    -- Clear the CombFloors attribute back to floor 1
    plotRoot:SetAttribute("CombFloors", 1)

    -- Fire FloorUnlocked clients to rebuild UI state
    local FloorUnlocked = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("FloorUnlocked") :: RemoteEvent?
    if FloorUnlocked then
        FloorUnlocked:FireAllClients(plotIndex, 1)
    end
end
```

**Note:** This assumes HexCell-tagged parts carry a `PlotIndex` attribute. If CombService uses a different pattern to identify which cells belong to which plot (e.g. they are children of a per-plot folder), adjust to match the actual hierarchy. Read the CombService source before editing to confirm the cell ownership pattern.

---

### 1E — SwarmRunner Script

**Location:** `ServerScriptService.SwarmRunner` (new Script)

```lua
--!strict
-- Require SwarmService to register RequestSwarm.OnServerEvent on server start.
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
require(Systems:WaitForChild("SwarmService"))
```

---

### 1F — SwarmController LocalScript

**Location:** `StarterPlayer.StarterPlayerScripts.SwarmController` (new LocalScript)

Handles the client-side departure sequence: departure beam VFX, brief fade-to-black silence beat, generation message.

```lua
--!strict
-- SwarmController: client-side Signature Moment 5 sequence.
-- Runs when server fires SwarmBegin (owns this player's plot swarm) or
-- SwarmComplete (generation results).

local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local SwarmBegin    = Remotes:WaitForChild("SwarmBegin")    :: RemoteEvent
local SwarmComplete = Remotes:WaitForChild("SwarmComplete") :: RemoteEvent
local RequestSwarm  = Remotes:WaitForChild("RequestSwarm")  :: RemoteEvent

local localPlayer   = Players.LocalPlayer
local playerGui     = localPlayer:WaitForChild("PlayerGui")
local camera        = workspace.CurrentCamera

-- Build a reusable full-screen overlay frame for the silence beat
local function buildOverlay(): Frame
    local sg = Instance.new("ScreenGui")
    sg.Name           = "SwarmOverlay"
    sg.DisplayOrder   = 999
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn   = false
    sg.Parent         = playerGui

    local frame = Instance.new("Frame")
    frame.Name              = "Blackout"
    frame.Size              = UDim2.fromScale(1, 1)
    frame.Position          = UDim2.fromScale(0, 0)
    frame.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel   = 0
    frame.ZIndex            = 10
    frame.Parent            = sg

    local label = Instance.new("TextLabel")
    label.Name                  = "SilenceLabel"
    label.Size                  = UDim2.fromScale(1, 0.1)
    label.Position              = UDim2.fromScale(0, 0.45)
    label.BackgroundTransparency = 1
    label.TextColor3            = Color3.fromRGB(255, 220, 100)
    label.TextTransparency      = 1
    label.Font                  = Enum.Font.GothamBold
    label.TextScaled            = true
    label.Text                  = ""
    label.Parent                = frame

    return frame
end

local overlay: Frame? = nil

-- Create a departure beam from the Landing Board straight up through the treeline.
-- Beam lifetime is ~6 seconds (auto-destroyed after sequence).
local function spawnDepartureBeam(plotIndex: number)
    -- Find this plot's Landing Board by PlotIndex attribute and tag
    local CS = game:GetService("CollectionService")
    local board: BasePart? = nil
    for _, obj in CS:GetTagged("LandingBoard") do
        if obj:GetAttribute("PlotIndex") == plotIndex and obj:IsA("BasePart") then
            board = obj
            break
        end
    end
    if not board then return end

    -- Sky anchor at Y=200 directly above the board
    local boardPos = board.Position
    local skyAnchor = Instance.new("Part")
    skyAnchor.Name              = "SwarmSkyAnchor"
    skyAnchor.Anchored          = true
    skyAnchor.CanCollide        = false
    skyAnchor.Transparency      = 1
    skyAnchor.CastShadow        = false
    skyAnchor.Size              = Vector3.new(1, 1, 1)
    skyAnchor.Position          = Vector3.new(boardPos.X, 200, boardPos.Z)
    skyAnchor.Parent            = workspace

    local att0 = Instance.new("Attachment")
    att0.WorldPosition = boardPos
    att0.Parent        = board

    local att1 = Instance.new("Attachment")
    att1.Parent        = skyAnchor

    local beam = Instance.new("Beam")
    beam.Attachment0       = att0
    beam.Attachment1       = att1
    beam.Color             = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 200, 50)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 130)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(200, 160, 255)),
    })
    beam.Transparency      = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0),
        NumberSequenceKeypoint.new(0.6, 0.2),
        NumberSequenceKeypoint.new(1,   1),
    })
    beam.Width0            = 2.5
    beam.Width1            = 0.5
    beam.LightEmission     = 0.8
    beam.LightInfluence    = 0.3
    beam.FaceCamera        = true
    beam.Segments          = 20
    beam.Parent            = board

    -- Pollen-burst ParticleEmitter on the board for departure effect
    local pe = Instance.new("ParticleEmitter")
    pe.Parent         = board
    pe.Color          = ColorSequence.new(Color3.fromRGB(255, 210, 60))
    pe.LightEmission  = 0.6
    pe.Lifetime       = NumberRange.new(1.5, 3)
    pe.Rate           = 40
    pe.Speed          = NumberRange.new(8, 20)
    pe.SpreadAngle    = Vector2.new(25, 25)
    pe.Size           = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1, 0),
    })
    pe.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.8, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })

    -- Tween camera to wide shot
    local originalCFrame = camera.CFrame
    local wideCFrame = CFrame.new(boardPos + Vector3.new(0, 30, -60)) * CFrame.Angles(math.rad(20), 0, 0)
    TweenService:Create(camera, TweenInfo.new(2.5, Enum.EasingStyle.Sine), {CFrame = wideCFrame}):Play()

    -- Auto-cleanup after sequence
    task.delay(7, function()
        pcall(function()
            beam:Destroy()
            pe:Destroy()
            att0:Destroy()
            att1:Destroy()
            skyAnchor:Destroy()
            -- Return camera
            TweenService:Create(camera, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {CFrame = originalCFrame}):Play()
        end)
    end)
end

-- Fade-to-black silence beat (peaks at t=4s, clears by t=7s)
local function playSilenceBeat(frame: Frame)
    local label = frame:FindFirstChild("SilenceLabel") :: TextLabel?

    -- Fade to black over 2.5s
    TweenService:Create(frame, TweenInfo.new(2.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()

    task.delay(3.0, function()
        -- At peak darkness: show "silence" text
        if label then
            label.Text = "..."
            TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
        end
    end)

    task.delay(5.5, function()
        -- Fade out
        if label then
            TweenService:Create(label, TweenInfo.new(1.0, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
        end
        TweenService:Create(frame, TweenInfo.new(2.0, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
    end)
end

-- Handle SwarmBegin (this player's hive is swarming)
SwarmBegin.OnClientEvent:Connect(function(plotIndex: number)
    if not overlay then overlay = buildOverlay() end
    spawnDepartureBeam(plotIndex)
    task.delay(2, function()
        if overlay then playSilenceBeat(overlay) end
    end)
end)

-- Handle SwarmComplete (server has finished the reset; show generation message)
SwarmComplete.OnClientEvent:Connect(function(generation: number, carryHoney: number)
    task.delay(0.5, function()
        -- Show a toast through NotifyGui (reuse existing Notify path)
        -- SwarmService already fired Notify:FireAllClients server-side for the global message.
        -- This is the personal confirmation with carry-over details.
        local notifyRemote = Remotes:FindFirstChild("Notify") :: RemoteEvent?
        if notifyRemote then
            -- This would be a server→client event; client can't fire it to itself.
            -- Instead, display directly in the SwarmOverlay label:
            local sg  = playerGui:FindFirstChild("SwarmOverlay")
            local lbl = sg and sg:FindFirstChild("Blackout") and sg.Blackout:FindFirstChild("SilenceLabel") :: TextLabel?
            if lbl then
                lbl.Text = "Generation " .. generation .. " — " .. carryHoney .. " honey carried forward"
                lbl.TextTransparency = 1
                TweenService:Create(lbl, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 0}):Play()
                task.delay(4, function()
                    TweenService:Create(lbl, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 1}):Play()
                end)
            end
        end
    end)
end)
```

---

### 1G — SwarmPerch ProximityPrompt wiring

This wiring is added to the world-builder task below (the ProximityPrompt fires `RequestSwarm` on Triggered). However, if the SwarmPerch template in ReplicatedStorage.Templates already has a ProximityPrompt child, the luau-scripter must wire it server-side.

**Edit `ServerScriptService.Systems.PlotService`** (or create a new Script `ServerScriptService.SwarmPerchWirer`) to wire all SwarmPerch ProximityPrompts at runtime:

```lua
-- Add to an existing server Script that runs after plots are built,
-- or create SwarmPerchWirer as a new Script:

--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlotService       = require(game:GetService("ServerScriptService").Systems:WaitForChild("PlotService"))

local RequestSwarm = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestSwarm") :: RemoteEvent

local function wirePerch(perch: Instance)
    local prompt = perch:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.ActionText    = "Swarm"
        prompt.ObjectText    = "SwarmPerch"
        prompt.HoldDuration  = 2.0  -- hold 2s to prevent accidental triggers
        prompt.MaxActivationDistance = 8
        prompt.Parent        = perch
    end
    prompt.Triggered:Connect(function(player: Player)
        RequestSwarm:FireServer()
    end)
end

-- Wire all already-placed perches
for _, perch in CollectionService:GetTagged("SwarmPerch") do
    wirePerch(perch)
end

-- Wire any perches placed later (after plot expansion)
CollectionService:GetInstanceAddedSignal("SwarmPerch"):Connect(wirePerch)
```

**Note:** The ProximityPrompt.Triggered fires with the triggering player as the first argument server-side. On the client, `RequestSwarm:FireServer()` carries the player implicitly. The server-side RequestSwarm.OnServerEvent in SwarmService receives the player automatically.

**Verification after all luau tasks:**

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local results = {}
local issues  = {}

-- Remotes
for _, name in {"SwarmBegin", "SwarmComplete", "RequestSwarm"} do
    local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild(name)
    if r then table.insert(results, "PASS: Remotes." .. name)
    else      table.insert(issues,  "FAIL: Remotes." .. name .. " missing") end
end

-- SwarmService
local ws = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("SwarmService")
if ws and ws:IsA("ModuleScript") then
    local src = ws.Source
    local lines = select(2, src:gsub("\n","")) + 1
    local checks = {
        strict     = src:find("--!strict") ~= nil,
        canSwarm   = src:find("canSwarm") ~= nil,
        carryOver  = src:find("CARRY_OVER") ~= nil,
        generation = src:find("generation") ~= nil,
        wipe       = src:find("WipeAllCells") ~= nil,
    }
    local allOk = true
    for k, v in checks do if not v then allOk = false end end
    if allOk then
        table.insert(results, "PASS: SwarmService " .. lines .. " lines, all symbols present")
    else
        local missing = {}
        for k, v in checks do if not v then table.insert(missing, k) end end
        table.insert(issues, "FAIL: SwarmService missing: " .. table.concat(missing, ", "))
    end
else
    table.insert(issues, "FAIL: SwarmService ModuleScript missing from Systems")
end

-- SwarmRunner
local wr = SSS:FindFirstChild("SwarmRunner")
if wr and wr:IsA("Script") then
    table.insert(results, "PASS: SwarmRunner Script exists")
else
    table.insert(issues, "FAIL: SwarmRunner Script missing")
end

-- SwarmController
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local sc  = SPS and SPS:FindFirstChild("SwarmController")
if sc and sc:IsA("LocalScript") then
    local src = sc.Source
    local hasTween   = src:find("TweenService") ~= nil
    local hasBeam    = src:find("Beam") ~= nil
    local hasBegin   = src:find("SwarmBegin") ~= nil
    local hasComplete = src:find("SwarmComplete") ~= nil
    if hasTween and hasBeam and hasBegin and hasComplete then
        table.insert(results, "PASS: SwarmController LocalScript with all required symbols")
    else
        table.insert(issues, "FAIL: SwarmController missing symbols: tween=" .. tostring(hasTween) .. " beam=" .. tostring(hasBeam))
    end
else
    table.insert(issues, "FAIL: SwarmController LocalScript missing from StarterPlayerScripts")
end

-- CombService.WipeAllCells
local cs = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService")
if cs then
    local hasWipe = cs.Source:find("WipeAllCells") ~= nil
    if hasWipe then
        table.insert(results, "PASS: CombService.WipeAllCells present")
    else
        table.insert(issues, "FAIL: CombService.WipeAllCells not added")
    end
else
    table.insert(issues, "FAIL: CombService not found")
end

-- DataService generation field
local ds = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("DataService")
if ds then
    local src = ds.Source
    local hasGen  = src:find("generation") ~= nil
    local hasMig4 = src:find("%[4%]") ~= nil
    if hasGen and hasMig4 then
        table.insert(results, "PASS: DataService has generation field + migration[4]")
    else
        table.insert(issues, "FAIL: DataService generation=" .. tostring(hasGen) .. " migration[4]=" .. tostring(hasMig4))
    end
else
    table.insert(issues, "FAIL: DataService not found")
end

local out = "=== SWARM LUAU VERIFICATION ===\nPASSED: " .. #results .. " ISSUES: " .. #issues .. "\n\n"
out = out .. table.concat(results, "\n") .. "\n"
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n") end
return out
```

---

## TASK 2 — world-builder

Deploy SwarmPerch mesh at all 6 plots plus sky anchor parts for the departure beam.

---

### 2A — Confirm template exists

```lua
local templates = game:GetService("ReplicatedStorage"):FindFirstChild("Templates")
local sp = templates and templates:FindFirstChild("SwarmPerch")
return sp and ("SwarmPerch template: ClassName=" .. sp.ClassName .. " ChildCount=" .. #sp:GetChildren()) or "MISSING: SwarmPerch template"
```

If the template is missing, the world-builder must construct a simple pedestal:
- Base: Cylinder Part, Size (1, 4, 4), Material=SmoothPlastic, Color=#7A4A22 (Propolis Brown)
- Top disc: Cylinder Part, Size (0.5, 6, 6), Material=Neon, Color=#F2A81C (Honey Gold)
- Model the two parts under a SwarmPerch Model with PrimaryPart = Base

---

### 2B — SwarmPerch placement at all 6 plots

Each plot's SwarmPerch sits at local offset **(0, 5, +50)** from the plot center — directly behind the back row of the hex lattice, centered, on a small elevation above the deck.

Plot absolute X positions (confirmed from architecture): −250, −150, −50, +50, +150, +250
Plot center Y (deck surface): 6.5 (matches Floor 1 plate Y)
Plot center Z: 0

So absolute SwarmPerch positions:

| Plot | PlotIndex | Absolute Position |
|------|-----------|-------------------|
| 1 | 1 | (−250, 11.5, 50) |
| 2 | 2 | (−150, 11.5, 50) |
| 3 | 3 | (  −50, 11.5, 50) |
| 4 | 4 | (  +50, 11.5, 50) |
| 5 | 5 | ( +150, 11.5, 50) |
| 6 | 6 | ( +250, 11.5, 50) |

*Y = 6.5 (deck) + 5 (local offset) = 11.5*

For each plot, clone the SwarmPerch template, position it, and tag it:

```lua
local CS        = game:GetService("CollectionService")
local templates = game:GetService("ReplicatedStorage").Templates
local spTemplate = templates:FindFirstChild("SwarmPerch")
if not spTemplate then error("SwarmPerch template missing — build it first") end

local PLOT_X = {-250, -150, -50, 50, 150, 250}
local BASE_Y = 11.5
local BASE_Z = 50

for i, xPos in PLOT_X do
    -- Check if a SwarmPerch for this plot already exists
    local exists = false
    for _, tagged in CS:GetTagged("SwarmPerch") do
        if tagged:GetAttribute("PlotIndex") == i then
            exists = true
            break
        end
    end
    if not exists then
        local clone = spTemplate:Clone()
        clone.Name = "SwarmPerch_Plot" .. i
        if clone:IsA("Model") and clone.PrimaryPart then
            clone:SetPrimaryPartCFrame(CFrame.new(xPos, BASE_Y, BASE_Z))
        elseif clone:IsA("BasePart") then
            clone.Position = Vector3.new(xPos, BASE_Y, BASE_Z)
        end
        CS:AddTag(clone, "SwarmPerch")
        clone:SetAttribute("PlotIndex", i)
        clone.Parent = workspace
        print("Placed SwarmPerch PlotIndex=" .. i .. " at (" .. xPos .. ", " .. BASE_Y .. ", " .. BASE_Z .. ")")
    else
        print("SwarmPerch PlotIndex=" .. i .. " already exists, skipping")
    end
end
return "SwarmPerch placement complete"
```

**Parent to the correct folder:** After placement, parent each SwarmPerch to the plot's world folder (e.g., `workspace.Plots.Plot1` or similar folder used by PlotService). This keeps the workspace organised:

```lua
for _, tagged in CS:GetTagged("SwarmPerch") do
    local idx = tagged:GetAttribute("PlotIndex") :: number?
    if idx then
        local plotFolder = workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild("Plot" .. idx)
        if plotFolder and tagged.Parent ~= plotFolder then
            tagged.Parent = plotFolder
        end
    end
end
return "SwarmPerch parenting complete"
```

---

### 2C — Sky anchor parts (for departure beam Attachment1)

6 invisible parts at Y=200, one above each plot's Landing Board. SwarmController creates these dynamically at runtime (see 1F above), so this world-builder step only places pre-positioned anchors if a static approach is preferred. **This step is OPTIONAL** — SwarmController's `spawnDepartureBeam()` creates temporary sky anchors at runtime, so no static placement is needed. Skip if the dynamic approach in 1F is implemented.

---

### 2D — World-builder verification

```lua
local CS = game:GetService("CollectionService")
local perches = CS:GetTagged("SwarmPerch")
local results = {}
local issues  = {}

if #perches == 6 then
    table.insert(results, "PASS: 6 SwarmPerch parts tagged")
else
    table.insert(issues, "FAIL: Expected 6 SwarmPerch, found " .. #perches)
end

local plotsSeen: {[number]: boolean} = {}
for _, p in perches do
    local idx = p:GetAttribute("PlotIndex") :: number?
    if idx then
        if plotsSeen[idx] then
            table.insert(issues, "DUPLICATE: PlotIndex=" .. idx)
        end
        plotsSeen[idx] = true
    else
        table.insert(issues, "MISSING PlotIndex attribute on " .. p.Name)
    end

    -- Check there's either a ProximityPrompt already or the perch is a Model/BasePart
    local hasPrompt = p:FindFirstChildOfClass("ProximityPrompt") ~= nil
    if not hasPrompt then
        table.insert(results, "NOTE: " .. p.Name .. " has no ProximityPrompt yet (SwarmPerchWirer will add one at runtime)")
    else
        table.insert(results, "PASS: " .. p.Name .. " has ProximityPrompt")
    end
end

for i = 1, 6 do
    if not plotsSeen[i] then
        table.insert(issues, "MISSING: No SwarmPerch for PlotIndex=" .. i)
    end
end

local out = "=== SWARM WORLD VERIFICATION ===\nPASSED: " .. #results .. " ISSUES: " .. #issues .. "\n\n"
out = out .. table.concat(results, "\n")
if #issues > 0 then out = out .. "\n\nISSUES:\n" .. table.concat(issues, "\n") end
return out
```

---

## Combined final verification

Run after both tasks complete:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local CS  = game:GetService("CollectionService")

local checks = {}
local issues = {}

-- Remotes
for _, name in {"SwarmBegin", "SwarmComplete", "RequestSwarm"} do
    local r = RS.Remotes:FindFirstChild(name)
    if r then table.insert(checks, "RemoteEvent " .. name)
    else  table.insert(issues, "MISSING Remote: " .. name) end
end

-- Scripts
local scriptCheck = {
    {"Systems.SwarmService", "ModuleScript"},
    {"SwarmRunner", "Script"},
}
for _, pair in scriptCheck do
    local obj = SSS:FindFirstChild(pair[1], true)
    if obj and obj.ClassName == pair[2] then
        table.insert(checks, pair[2] .. " " .. pair[1])
    else
        table.insert(issues, "MISSING " .. pair[2] .. ": " .. pair[1])
    end
end

local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local sc  = SPS and SPS:FindFirstChild("SwarmController")
if sc then table.insert(checks, "LocalScript SwarmController") else table.insert(issues, "MISSING LocalScript: SwarmController") end

-- SwarmPerch count
local perchCount = #CS:GetTagged("SwarmPerch")
if perchCount == 6 then
    table.insert(checks, "6 SwarmPerch tagged in workspace")
else
    table.insert(issues, "WRONG SwarmPerch count: " .. perchCount .. " (expected 6)")
end

-- generation in DataService
local ds = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("DataService")
if ds and ds.Source:find("generation") then
    table.insert(checks, "DataService has generation field")
else
    table.insert(issues, "DataService missing generation field")
end

-- CombService.WipeAllCells
local combS = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService")
if combS and combS.Source:find("WipeAllCells") then
    table.insert(checks, "CombService.WipeAllCells present")
else
    table.insert(issues, "CombService.WipeAllCells missing")
end

local out = "=== SWARM SYSTEM — FULL VERIFICATION ===\n"
out = out .. "PASSED: " .. #checks .. " / ISSUES: " .. #issues .. "\n\n"
out = out .. table.concat(checks, "\n") .. "\n"
if #issues > 0 then
    out = out .. "\n--- ISSUES ---\n" .. table.concat(issues, "\n") .. "\n"
else
    out = out .. "\nALL CHECKS PASSED.\n"
    out = out .. "Smoke test: enter Play mode, interact with SwarmPerch, observe:\n"
    out = out .. "  - Departure beam column rises from Landing Board\n"
    out = out .. "  - Camera pulls wide\n"
    out = out .. "  - Screen fades black at t=2.5s\n"
    out = out .. "  - '...' appears at t=3s\n"
    out = out .. "  - 'Generation 1 — N honey carried forward' appears at t=8.5s\n"
    out = out .. "  - Server-wide Notify fires\n"
    out = out .. "  - Profile resets: honey=N*0.20, cells={}, queenTier=1, generation=1\n"
end
return out
```

---

## Executor notes

1. **HoldDuration = 2.0** on the SwarmPerch ProximityPrompt is intentional. The swarm is irreversible; a 2-second hold prevents misclicks. Players will learn this is a "major action" button.

2. **Structures persist through swarm** (danceFloorTier, apiaryShedTier, propolisKilnTier). This is the prestige mechanic's reward loop: you keep your improvements but rebuild your comb and queen from scratch — faster on each generation because your infrastructure persists.

3. **CombService.WipeAllCells**: Read the CombService source carefully before editing. The cell ownership pattern may use a per-plot folder hierarchy instead of PlotIndex attributes on HexCell-tagged parts. Match the wipe logic to whatever pattern is actually used.

4. **SwarmComplete client message**: The SwarmController displays the "Generation N — N honey carried forward" message directly in the SwarmOverlay rather than through the Notify remote, because this is a personal message (carry-over amount is per-player) while the server-wide Notify is already handling the social broadcast.

5. **Generation on HiveGui**: The HiveGui QUEEN tab (from cycle4_queen_dispatch) should eventually show generation number as a badge. This is a deferred cosmetic addition — tag it for the ui-designer pass in cycle 7.

6. **Swarm frequency**: With prerequisites (Queen T3, 15 cells, 5000 honey), the average player first swarms around the 45–60 minute mark as intended. Generation 2+ players swarm faster (starting honey carry-over + preserved structures) — typically 25–35 minutes. This accelerating loop is by design.
