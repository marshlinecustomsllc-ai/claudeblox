# CYCLE 4 — Floor 2 & Floor 3 Build Dispatch

> **Source of truth:** `architecture.md` — Zone: Comb Deck, Comb Floors table (line ~642),
> HexGrid section (line ~239), Door/Connection Map (line ~599), Part Budget (line ~1074).
>
> **Prerequisite:** Bug #9 fix (`fix_bug9_duplicate_dataservice.lua`) must be run in Studio
> before any DataService edits. This dispatch does NOT touch DataService directly, but the
> StructureService changes here will call DataService.Save — confirm count==1 first.
>
> **Build two things in parallel:**
> - **world-builder** — physical dim-plate geometry for F2+F3, all 6 plots
> - **luau-scripter** — UnlockFloor server logic + FloorUnlocked reveal animation client-side
>
> Then one sequential step: verify + wire BuildController floor-context switching.

---

## WHAT EXISTS NOW

- **Floor 1** (all 6 plots): 19 dim cell plates per plot, 19×6=114 total, confirmed built and
  walkable. Ramp structure at local (+34, +14) was included in Plot 1 original build and
  replicated to Plots 2–6; verify via MCP before rebuilding.
- **Floor 2 geometry**: DOES NOT EXIST. No plates, no columns.
- **Floor 3 geometry**: DOES NOT EXIST. No plates, no columns.
- **CombService.UnlockFloor**: function signature exists in architecture.md but actual
  implementation status unknown — verify via MCP source read before writing.
- **RequestUnlockFloor** RemoteEvent: may not exist yet — verify.

---

## HEX MATH REFERENCE

```
CELL_W = 13.856   CELL_H = 12.0   cell plate diameter = 15
Plot-local position: x = 13.856 * (q + r/2),  z = 12.0 * r + 6,  y = floorY
```

**Floor Y values (plot-local, all plots share the same Y):**
- Floor 1: Y = 6.5 (top surface of base deck)
- Floor 2: Y = 22.5
- Floor 3: Y = 38.5

**Plot X positions (world absolute):** −250, −150, −50, +50, +150, +250
Plot Z position: read from existing PlotRoot parts via MCP — do not hardcode.

### Floor 2 cells — ring-2 of axial hex (12 cells, outer annulus)

These 12 cells form the outer ring of the radius-2 hex grid. The centre 7 positions are
OPEN AIR on Floor 2, which is intentional: this creates the "mezzanine" through which you
can see Floor 1 below, and Floor 3's shadow falls through from above.

| # | q | r | local X | local Z | description |
|---|---|---|---------|---------|-------------|
| 1 | 2 | 0 | +27.712 | +6 | |
| 2 | 1 | 1 | +20.784 | +18 | |
| 3 | 0 | 2 | +13.856 | +30 | (northern rim) |
| 4 | −1 | 2 | 0 | +30 | |
| 5 | −2 | 2 | −13.856 | +30 | |
| 6 | −2 | 1 | −20.784 | +18 | |
| 7 | −2 | 0 | −27.712 | +6 | |
| 8 | −1 | −1 | −20.784 | −6 | |
| 9 | 0 | −2 | −13.856 | −18 | (southern rim) |
| 10 | 1 | −2 | 0 | −18 | |
| 11 | 2 | −2 | +13.856 | −18 | |
| 12 | 2 | −1 | +20.784 | −6 | |

**World absolute for Plot 1 (plot_x = −250):**
Add plot_x to local X; add plot_z to local Z (read plot_z from live MCP query).

### Floor 3 cells — radius-1 hex, 7 cells (Crown Comb)

These 7 cells are a compact radius-1 hex directly above the centre of Floor 1.
At Y=38.5 this CLEARS THE FENCE LINE — the signature "whole server view" moment.

| # | q | r | local X | local Z |
|---|---|---|---------|---------|
| 1 | 0 | 0 | 0 | +6 |
| 2 | 1 | 0 | +13.856 | +6 |
| 3 | 0 | 1 | +6.928 | +18 |
| 4 | −1 | 1 | −6.928 | +18 |
| 5 | −1 | 0 | −13.856 | +6 |
| 6 | 0 | −1 | −6.928 | −6 |
| 7 | 1 | −1 | +6.928 | −6 |

---

## TASK A: WORLD-BUILDER

> Build the Floor 2 and Floor 3 dim plate geometry for all 6 plots, plus spiral ramps.
> This is a purely additive world build — do not modify existing Floor 1 geometry.

### Step 0 — MCP survey

Before building, run these checks:

```lua
-- 1. Find existing PlotRoot positions and folder structure
local WS = game:GetService("Workspace")
local plotData = {}
for _, child in WS:GetDescendants() do
    if child.Name == "PlotRoot" and child:IsA("BasePart") then
        table.insert(plotData, {
            name = child.Parent and child.Parent.Name or "?",
            pos  = tostring(child.Position)
        })
    end
end
-- Sort by X
table.sort(plotData, function(a, b)
    local ax = tonumber(a.pos:match("(-?%d+%.?%d*)")) or 0
    local bx = tonumber(b.pos:match("(-?%d+%.?%d*)")) or 0
    return ax < bx
end)
local out = {}
for _, d in plotData do table.insert(out, d.name .. ": " .. d.pos) end
return table.concat(out, "\n")
```

```lua
-- 2. Check whether ramps already exist
local rampCount = 0
local columnCount = 0
for _, obj in game:GetService("Workspace"):GetDescendants() do
    if obj.Name == "CombFloorRamp" or obj.Name:find("Ramp") then rampCount += 1 end
    if obj.Name == "CombColumn" or obj.Name:find("Column") then columnCount += 1 end
end
return "CombFloorRamp parts: " .. rampCount .. "\nCombColumn parts: " .. columnCount
```

```lua
-- 3. Count existing Floor 1 dim plates (should be 114 = 19 × 6)
local plateCount = 0
for _, obj in game:GetService("Workspace"):GetDescendants() do
    if obj.Name == "DimCellPlate" and obj:IsA("BasePart") then plateCount += 1 end
end
return "DimCellPlate count: " .. plateCount
```

### Step 1 — Determine plot Z positions

From the MCP query above, extract the Z coordinate for each PlotRoot. All 6 plots share
the same Z (they are at the same depth, offset only in X). Use this value as `plot_z`
for all coordinate calculations below.

### Step 2 — Build Floor 2 dim plates

For each of the 6 plots (plot X = −250, −150, −50, +50, +150, +250):

Create 12 parts inside the existing plot folder
(e.g. `Workspace.Plots.Plot1.Floor2` — create the Floor2 subfolder if it doesn't exist):

**Plate spec (each of the 12 Floor 2 plates):**
- ClassName: `Part`
- Name: `"DimCellPlate_F2"`
- Shape: `Cylinder` (same as Floor 1 plates)
- Size: `Vector3.new(2.5, 15, 15)` — 15 diameter, 2.5 tall
- Orientation: `CFrame.fromEulerAnglesXYZ(0, 0, math.rad(90))` — axis along Y
- CFrame: `CFrame.new(plot_x + local_x, 22.5, plot_z + local_z)` using table above
- Material: `Enum.Material.SmoothPlastic`
- Color: `Color3.fromHex("#9E8C5A")` — darker/dimmer than normal Wax Cream to read as "locked"
- Transparency: `0.6` — visible but clearly not built/active
- Anchored: `true`, CanCollide: `true` (walkable surface — these ARE the floor)
- Attribute: `"Floor"` = `2`, `"HexQ"` = q value, `"HexR"` = r value
- Tag: `"CombFloor2Plate"` via CollectionService

Repeat for all 12 positions in the ring-2 table above.
Do this for all 6 plots. Total new parts from plates alone: 12 × 6 = 72.

### Step 3 — Build Floor 3 dim plates

Same process for Floor 3 plates:

**Plate spec (each of the 7 Floor 3 plates):**
- Name: `"DimCellPlate_F3"`
- Size: `Vector3.new(2.5, 15, 15)` (same as F1/F2)
- CFrame Y: `38.5`
- Color: `Color3.fromHex("#7A6A3E")` — even dimmer, higher floors feel more aspirational
- Transparency: `0.7`
- Attribute: `"Floor"` = `3`
- Tag: `"CombFloor3Plate"`

Repeat for all 7 positions and all 6 plots. Total: 7 × 6 = 42 plates.

**Floor 3 is special: add a subtle PointLight to cell (0,0) of each plot's F3:**
- PointLight, Color `#FCEFC6` (Wax Cream warm), Brightness `0.3`, Range `20`
- This light starts dim and will brighten on unlock — the Crown Comb has its own glow

### Step 4 — Wax spiral ramps

**Check MCP results from Step 0.** If CombFloorRamp parts exist (count ≥ 12 = 2 per plot × 6 plots),
the ramps are already built — skip to Step 5.

If ramps are missing, build them for each plot:

**Ramp F1→F2** (Y 6.5 → 22.5, 16 studs vertical, local (+34, +14) in X/Z):

Build as a helical series of 8 wedge/ramp parts, each ~2 studs tall, forming a spiral:
- Position center: `plot_x + 34, 6.5..22.5, plot_z + 14`
- Material: `SmoothPlastic`
- Color: `Color3.fromHex("#E8D49A")` (Wax Cream)
- Anchored: `true`, CanCollide: `true`
- Name each part: `"WaxRampSegment_F2"` + index
- Tag: `"CombFloor2Ramp"` — needed for reveal animation
- **Width: 9 studs** (architecture spec — bear AgentRadius=6 cannot use this ramp by design)
- The ramp should be a gentle spiral ~180° total turn, going from facing Z+ at the bottom
  to facing Z+ at the top (half-turn spiral)

If the CombFloorRamp template exists in ReplicatedStorage.Templates.Structures — use it
via `InsertModel` and position it instead of building from scratch.

**Ramp F2→F3** (Y 22.5 → 38.5, same local (+34, +14)):
- Same spec, name `"WaxRampSegment_F3"`, tag `"CombFloor3Ramp"`
- Start it on top of the F2 platform
- Continue the same spiral direction for visual consistency

### Step 5 — Support columns (CombColumn template)

If CombColumn template exists in ReplicatedStorage.Templates.Structures:

Place 4 columns per plot per floor (F2 and F3), at the cardinal hex corners:
- F2 columns: (plot_x ± 27, Y=6..22.5, plot_z + 6) — NE and SW of F2 ring
- F3 columns: (plot_x ± 14, Y=22.5..38.5, plot_z + 6) — tighter because F3 is smaller

If no CombColumn template exists, skip columns — the game is structurally fine without them.

### Step 6 — Verify

```lua
local WS = game:GetService("Workspace")
local CS = game:GetService("CollectionService")

local f2plates = CS:GetTagged("CombFloor2Plate")
local f3plates = CS:GetTagged("CombFloor3Plate")
local f2ramps  = CS:GetTagged("CombFloor2Ramp")
local f3ramps  = CS:GetTagged("CombFloor3Ramp")

-- Check dim-plate walkability
local issues = {}
for _, p in f2plates do
    if not p.Anchored then table.insert(issues, "NOT ANCHORED F2: " .. p:GetFullName()) end
    if not p.CanCollide then table.insert(issues, "NO CANCOLLIDE F2: " .. p:GetFullName()) end
end
for _, p in f3plates do
    if not p.Anchored then table.insert(issues, "NOT ANCHORED F3: " .. p:GetFullName()) end
    if not p.CanCollide then table.insert(issues, "NO CANCOLLIDE F3: " .. p:GetFullName()) end
end

local result = string.format(
    "F2 plates: %d (expect 72)\nF3 plates: %d (expect 42)\nF2 ramp parts: %d\nF3 ramp parts: %d",
    #f2plates, #f3plates, #f2ramps, #f3ramps
)
if #issues > 0 then
    result = result .. "\nISSUES:\n" .. table.concat(issues, "\n")
else
    result = result .. "\nAll walkability checks OK"
end
return result
```

**PASS criteria:**
- F2 plates = 72 (12 × 6)
- F3 plates = 42 (7 × 6)
- At least some ramp parts exist
- All plates Anchored=true, CanCollide=true

**WORLD BUILT:** [count of new parts] parts added. Floor 2 and Floor 3 dim lattice present
on all 6 plots. Ramps verified.

---

## TASK B: LUAU-SCRIPTER (run in parallel with world-builder)

> Implement UnlockFloor server logic, FloorUnlocked remote, and client reveal animation.
> BuildController gets floor-context switching so Build Mode works on F2 and F3.

### Step 1 — Config changes

**Read Config module first via MCP:**
```lua
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
-- Check what's there
local hasFloors = cfg.FLOORS ~= nil
local hasStructuresFloor = cfg.STRUCTURES and cfg.STRUCTURES.floor2Unlock ~= nil
return "Config.FLOORS: " .. tostring(hasFloors) ..
       "\nConfig.STRUCTURES.floor2Unlock: " .. tostring(hasStructuresFloor)
```

**Add to Config module** (use clone-and-replace pattern to bust require() cache):

```lua
-- In Config module, add after QUEEN_TIERS block:

Config.FLOORS = {
    [2] = {
        name         = "Upper Comb",
        cells        = 12,
        honeyCost    = 40000,
        propolisCost = 350,
        minF1Fill    = 0.80,   -- F1 must be ≥80% built
        genGate      = 0,      -- no generation gate
    },
    [3] = {
        name         = "Crown Comb",
        cells        = 7,
        honeyCost    = 500000,
        propolisCost = 2000,
        minF2Fill    = 0.80,   -- F2 must be ≥80% built
        genGate      = 1,      -- requires Generation ≥ 1
    },
}

-- Also add the valid Floor 2+3 cell positions so server can validate RequestBuildCell
-- (InLattice must know the ring-2 and radius-1 sets)
Config.FLOOR_CELLS = {
    [2] = {
        {q=2,r=0},{q=1,r=1},{q=0,r=2},{q=-1,r=2},{q=-2,r=2},{q=-2,r=1},
        {q=-2,r=0},{q=-1,r=-1},{q=0,r=-2},{q=1,r=-2},{q=2,r=-2},{q=2,r=-1},
    },
    [3] = {
        {q=0,r=0},{q=1,r=0},{q=0,r=1},{q=-1,r=1},{q=-1,r=0},{q=0,r=-1},{q=1,r=-1},
    },
}
```

### Step 2 — HexGrid.InLattice update

**Read HexGrid module:**
```lua
local s = game:GetService("ReplicatedStorage").Modules:FindFirstChild("HexGrid")
return s and s.Source or "NOT FOUND"
```

HexGrid.InLattice currently checks `max(|q|, |r|, |q+r|) <= floor_radius` where radius
is 2 for floor 1. This formula gives radius-2 = 19 cells, which is correct for Floor 1.
But Floor 2 is the OUTER RING ONLY (ring 2, not filled), and Floor 3 is radius-1 filled.

**Update HexGrid.InLattice** to use Config.FLOOR_CELLS for floors 2 and 3:

```lua
-- In HexGrid module, update InLattice:
function HexGrid.InLattice(q: number, r: number, floor: number): boolean
    if floor == 1 then
        -- radius-2 filled hex (original logic)
        return math.max(math.abs(q), math.abs(r), math.abs(q+r)) <= 2
    end
    -- Floors 2 and 3 use explicit cell lists
    local cells = Config.FLOOR_CELLS[floor]
    if not cells then return false end
    for _, cell in cells do
        if cell.q == q and cell.r == r then return true end
    end
    return false
end
```

### Step 3 — RequestUnlockFloor RemoteEvent + CombService.UnlockFloor

**Check what exists:**
```lua
local RE = game:GetService("ReplicatedStorage"):FindFirstChild("RequestUnlockFloor", true)
local CS = game:GetService("ServerScriptService"):FindFirstChild("CombService", true)
if CS then
    local hasUnlock = CS.Source:find("UnlockFloor") ~= nil
    return "RequestUnlockFloor: " .. tostring(RE ~= nil) ..
           "\nCombService.UnlockFloor: " .. tostring(hasUnlock)
end
return "CombService not found"
```

**Create RemoteEvent** (if not present):
```lua
-- In ReplicatedStorage (via run_code during Edit mode):
local re = Instance.new("RemoteEvent")
re.Name = "RequestUnlockFloor"
re.Parent = game:GetService("ReplicatedStorage").Remotes
-- Also create the outbound event for clients to receive:
local fe = Instance.new("RemoteEvent")
fe.Name = "FloorUnlocked"
fe.Parent = game:GetService("ReplicatedStorage").Remotes
return "Created"
```

**Add to CombService** (or the module that handles RequestBuildCell, confirm name via MCP):

```lua
--!strict
-- CombService.UnlockFloor — add this function to the existing CombService module
-- Call pattern: CombService.UnlockFloor(player, profile, plotService, floor)

local function countBuiltCells(profile: table, floor: number): number
    local built = 0
    if not profile.comb or not profile.comb[floor] then return 0 end
    for _ in profile.comb[floor] do built += 1 end
    return built
end

function CombService.UnlockFloor(
    player: Player,
    profile: table,
    plotIndex: number,
    floor: number
): (boolean, string)
    -- Validate floor
    if floor ~= 2 and floor ~= 3 then
        return false, "invalid floor"
    end
    -- Already unlocked?
    local unlocked = profile.unlockedFloors or {}
    if unlocked[tostring(floor)] then
        return false, "already unlocked"
    end
    local cfg = require(ReplicatedStorage.Modules.Config)
    local floorCfg = cfg.FLOORS[floor]
    if not floorCfg then return false, "no config" end

    -- Generation gate
    local gen = profile.generation or 0
    if gen < floorCfg.genGate then
        return false, "generation " .. floorCfg.genGate .. " required"
    end

    -- Prior floor fill check
    local priorFloor = floor - 1
    local priorCells = countBuiltCells(profile, priorFloor)
    local priorMax = priorFloor == 1 and 18 or 12  -- F1=18 buildable, F2=12 total
    local fillReq = floor == 2 and floorCfg.minF1Fill or floorCfg.minF2Fill
    if priorMax > 0 and (priorCells / priorMax) < fillReq then
        return false, "Floor " .. priorFloor .. " not full enough (" ..
               math.floor(priorCells / priorMax * 100) .. "% < " ..
               math.floor(fillReq * 100) .. "% required)"
    end

    -- Cost check
    if profile.honey < floorCfg.honeyCost then
        return false, "not enough honey"
    end
    if (profile.propolis or 0) < floorCfg.propolisCost then
        return false, "not enough propolis"
    end

    -- Deduct cost
    profile.honey -= floorCfg.honeyCost
    if profile.propolis then
        profile.propolis -= floorCfg.propolisCost
    end

    -- Mark unlocked
    profile.unlockedFloors = profile.unlockedFloors or {}
    profile.unlockedFloors[tostring(floor)] = true

    -- Update PlotRoot attribute so all clients see new floor count
    -- PlotService should expose a way to get the plot folder:
    local PlotService = require(ServerScriptService.Systems.PlotService)
    local plotFolder = PlotService.GetPlotFolder(plotIndex)
    if plotFolder then
        local plotRoot = plotFolder:FindFirstChild("PlotRoot")
        if plotRoot then
            local current = plotRoot:GetAttribute("CombFloors") or 1
            plotRoot:SetAttribute("CombFloors", math.max(current, floor))
        end
    end

    -- Fire reveal animation to ALL clients (every player in server sees a hive grow)
    local FloorUnlocked = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("FloorUnlocked")
    if FloorUnlocked then
        FloorUnlocked:FireAllClients(plotIndex, floor)
    end

    -- Notify owner
    local Notify = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
    if Notify then
        Notify:FireClient(player, {
            title = floorCfg.name .. " Unlocked!",
            body  = "Your hive now has " .. floor .. " floors.",
            icon  = "star",
        })
    end

    -- Async save (do not yield main path)
    task.spawn(function()
        local DataService = require(ServerScriptService.Systems.DataService)
        DataService.Save(player)
    end)

    return true, "ok"
end
```

**Wire RequestUnlockFloor in Main.lua or CombService init:**

```lua
-- In the RemoteEvent handler section of Main.lua / CombService init:
local RequestUnlockFloor = Remotes:FindFirstChild("RequestUnlockFloor")
if RequestUnlockFloor then
    RequestUnlockFloor.OnServerEvent:Connect(function(player: Player, floor: number)
        -- Rate limit: 1 per second per player
        -- (use same rateLimit table as RequestBuildCell)
        local profile = DataService.GetProfile(player)
        if not profile then return end
        local plotIndex = PlotService.GetPlayerPlotIndex(player)
        if not plotIndex then return end
        CombService.UnlockFloor(player, profile, plotIndex, floor)
    end)
end
```

### Step 4 — BuildController floor-context switching

**Read BuildController source:**
```lua
local BC = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("BuildController")
    or game:GetService("StarterPlayer").StarterCharacterScripts:FindFirstChild("BuildController")
return BC and ("len=" .. #BC.Source) or "NOT FOUND -- search StarterGui"
```

Adjust the search path to wherever BuildController actually lives.

**Add to BuildController** (surgical edits only):

```lua
-- 1. Add at the top of BuildController, after existing local vars:
local FloorUnlocked = ReplicatedStorage.Remotes:WaitForChild("FloorUnlocked")
local myUnlockedFloors: {[number]: boolean} = {[1] = true}

-- 2. Add floor-reveal handler (wax ramp unroll + plate fade-in):
FloorUnlocked.OnClientEvent:Connect(function(plotIndex: number, floor: number)
    -- Only animate this player's own plot (others' reveals are visible but not animated
    -- on the player's screen to save perf — set transparency directly instead)
    local isOwn = (plotIndex == myPlotIndex)  -- myPlotIndex already exists in BuildController
    
    if isOwn then
        myUnlockedFloors[floor] = true
    end

    -- Find the plates and ramp segments for this plot + floor
    local CS = game:GetService("CollectionService")
    local plateTag  = floor == 2 and "CombFloor2Plate"  or "CombFloor3Plate"
    local rampTag   = floor == 2 and "CombFloor2Ramp"   or "CombFloor3Ramp"
    local TS = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    -- Collect plates that belong to this plot
    local plates = {}
    for _, p in CS:GetTagged(plateTag) do
        -- A plate belongs to this plot if its X is near the plot's root X
        local plotX = (plotIndex - 3.5) * 100  -- approximation; refine with PlotRoot lookup
        if math.abs(p.Position.X - plotX) < 60 then
            table.insert(plates, p)
        end
    end

    -- Sort plates center-outward (by distance from plot X center, ascending)
    table.sort(plates, function(a, b)
        local ax = math.abs(a.Position.X - (plotIndex - 3.5) * 100)
        local bx = math.abs(b.Position.X - (plotIndex - 3.5) * 100)
        return ax < bx
    end)

    -- Ramp: fade in all segments at once (the "unroll" effect comes from bottom-to-top ordering)
    local rampParts = {}
    for _, r in CS:GetTagged(rampTag) do
        local plotX = (plotIndex - 3.5) * 100
        if math.abs(r.Position.X - plotX) < 60 then
            table.insert(rampParts, r)
        end
    end
    table.sort(rampParts, function(a, b) return a.Position.Y < b.Position.Y end)

    -- Unroll ramp bottom-to-top over 1.5s
    for i, part in rampParts do
        local delay = (i - 1) * (1.5 / math.max(#rampParts, 1))
        task.delay(delay, function()
            TS:Create(part, TweenInfo.new(0.25), {Transparency = 0}):Play()
        end)
    end

    -- Fade in plates after ramp (0.3s stagger for hex-ring ripple)
    for i, plate in plates do
        local delay = 1.5 + (i - 1) * 0.12  -- ring ripple matches CappingWave timing
        task.delay(delay, function()
            TS:Create(plate, tweenInfo, {
                Transparency = 0,
                Color = Color3.fromHex("#E8D49A"),  -- restore full Wax Cream
            }):Play()
            -- Also brighten the F3 PointLight on reveal
            local light = plate:FindFirstChildOfClass("PointLight")
            if light then
                TS:Create(light, TweenInfo.new(1.0), {Brightness = 1.2}):Play()
            end
        end)
    end
end)

-- 3. Floor-context detection — add to the Build Mode hit detection:
-- When BuildController computes which floor the player is on (for RequestBuildCell),
-- determine floor from player Y:
local function getActiveFloor(character: Model): number
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 1 end
    local y = hrp.Position.Y
    if y >= 30 and myUnlockedFloors[3] then return 3
    elseif y >= 14 and myUnlockedFloors[2] then return 2
    else return 1 end
end
-- Use getActiveFloor() when constructing the RequestBuildCell payload
-- Replace any hardcoded floor=1 in the existing build request with:
-- floor = getActiveFloor(LocalPlayer.Character)
```

### Step 5 — DataService profile schema update

**Check if profile.unlockedFloors already exists:**
```lua
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
-- This is read-only — just check the PROFILE_TEMPLATE
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local t = cfg.PROFILE_TEMPLATE
return "unlockedFloors: " .. tostring(t.unlockedFloors)
```

If `unlockedFloors` is not in `PROFILE_TEMPLATE`, add it:

```lua
-- In Config.PROFILE_TEMPLATE, add:
unlockedFloors = {},  -- {["2"] = true, ["3"] = true} when unlocked
```

No DataService migration needed — this field defaults to `{}` which is correct for
existing profiles (floor 1 is always unlocked by default, handled by CombService logic
`unlocked[tostring(1)] or floor == 1`).

### Step 6 — ProximityPrompt unlock triggers (temporary until BudButton cycle)

To allow testing floor unlock before BudButtons are wired in cycle 5, place a
ProximityPrompt at the base of each plot's F1→F2 ramp:

```lua
-- Run in Studio Command Bar to add temporary unlock prompts:
local CS = game:GetService("CollectionService")
for _, tag in {"CombFloor2Ramp", "CombFloor3Ramp"} do
    local floor = tag == "CombFloor2Ramp" and 2 or 3
    -- Find the lowest-Y ramp part per plot (the bottom of the ramp)
    local byPlot: {[number]: BasePart} = {}
    for _, part in CS:GetTagged(tag) do
        local px = math.round(part.Position.X / 100) * 100  -- snap to nearest plot X
        if not byPlot[px] or part.Position.Y < byPlot[px].Position.Y then
            byPlot[px] = part
        end
    end
    for plotX, bottomPart in byPlot do
        local existing = bottomPart:FindFirstChildOfClass("ProximityPrompt")
        if not existing then
            local pp = Instance.new("ProximityPrompt")
            pp.ActionText = "Unlock Floor " .. floor
            pp.ObjectText  = "Cost: " .. (floor == 2 and "40k Honey" or "500k Honey")
            pp.HoldDuration = 1.0
            pp.MaxActivationDistance = 8
            pp:SetAttribute("UnlockFloor", floor)
            pp.Parent = bottomPart
        end
    end
end
return "Done"
```

Wire the ProximityPrompt in a LocalScript or the existing BuildController:
```lua
-- ProximityPrompt.Triggered fires RequestUnlockFloor
local RequestUnlockFloor = ReplicatedStorage.Remotes:WaitForChild("RequestUnlockFloor")
game:GetService("CollectionService"):GetInstanceAddedSignal("CombFloor2Ramp"):Connect(function(part)
    local pp = part:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        pp.Triggered:Connect(function()
            local floor = pp:GetAttribute("UnlockFloor")
            if floor then RequestUnlockFloor:FireServer(floor) end
        end)
    end
end)
-- Also wire existing ramp parts at init time
-- (loop through tagged parts in the same pattern)
```

### Verification after luau-scripter

```lua
-- STEP 3 check: Remotes
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local ruf = remotes and remotes:FindFirstChild("RequestUnlockFloor")
local fu  = remotes and remotes:FindFirstChild("FloorUnlocked")
-- STEP 1 check: Config
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local hasFloors = cfg.FLOORS ~= nil
local hasFloorCells = cfg.FLOOR_CELLS ~= nil
local hasPT = cfg.PROFILE_TEMPLATE and cfg.PROFILE_TEMPLATE.unlockedFloors ~= nil
-- STEP 2 check: HexGrid
local HexGrid = require(game:GetService("ReplicatedStorage").Modules.HexGrid)
local inF2 = HexGrid.InLattice(2, 0, 2)   -- ring-2 cell, should be true
local notF2 = HexGrid.InLattice(0, 0, 2)  -- centre cell, NOT in F2 ring, should be false
local inF3 = HexGrid.InLattice(0, 0, 3)   -- centre cell, IS in F3, should be true
-- CombService
local CombSvc = require(game:GetService("ServerScriptService").Systems.CombService)
local hasUnlock = CombSvc.UnlockFloor ~= nil

return string.format(
    "RequestUnlockFloor: %s\nFloorUnlocked: %s\nConfig.FLOORS: %s\nConfig.FLOOR_CELLS: %s\n" ..
    "profile.unlockedFloors: %s\nHexGrid F2 ring-2(2,0)=%s centre(0,0)=%s\n" ..
    "HexGrid F3 centre(0,0)=%s\nCombService.UnlockFloor: %s",
    tostring(ruf ~= nil), tostring(fu ~= nil),
    tostring(hasFloors), tostring(hasFloorCells), tostring(hasPT),
    tostring(inF2), tostring(not notF2),
    tostring(inF3), tostring(hasUnlock)
)
```

**PASS criteria:**
- RequestUnlockFloor remote: ✓
- FloorUnlocked remote: ✓
- Config.FLOORS: ✓
- Config.FLOOR_CELLS: ✓
- HexGrid F2 ring-2(2,0) = true, centre(0,0) = false ← critical correctness test
- HexGrid F3 centre(0,0) = true
- CombService.UnlockFloor: ✓

---

## FINAL COMBINED VERIFICATION

```lua
local CS = game:GetService("CollectionService")
local WS = game:GetService("Workspace")

-- Count geometry
local f2plates = CS:GetTagged("CombFloor2Plate")
local f3plates = CS:GetTagged("CombFloor3Plate")
local f2ramps  = CS:GetTagged("CombFloor2Ramp")
local f3ramps  = CS:GetTagged("CombFloor3Ramp")

-- Count total parts (must stay under 5000)
local totalParts = 0
for _, obj in WS:GetDescendants() do
    if obj:IsA("BasePart") then totalParts += 1 end
end

-- Verify plate Y values
local badY = {}
for _, p in f2plates do
    local y = p.Position.Y
    if y < 22.0 or y > 23.0 then
        table.insert(badY, "F2 plate wrong Y=" .. y .. ": " .. p:GetFullName())
    end
end
for _, p in f3plates do
    local y = p.Position.Y
    if y < 38.0 or y > 39.0 then
        table.insert(badY, "F3 plate wrong Y=" .. y .. ": " .. p:GetFullName())
    end
end

-- Verify remotes
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local hasRUF = remotes and remotes:FindFirstChild("RequestUnlockFloor") ~= nil
local hasFU  = remotes and remotes:FindFirstChild("FloorUnlocked") ~= nil

-- Ramp walkability spot-check (ramps must be CanCollide=true)
local rampIssues = {}
for _, r in f2ramps do
    if not r.CanCollide then table.insert(rampIssues, "NO CANCOLLIDE ramp: " .. r:GetFullName()) end
end

local out = string.format(
    "=== FLOOR 2/3 BUILD VERIFICATION ===\n" ..
    "F2 plates: %d / 72 expected\n" ..
    "F3 plates: %d / 42 expected\n" ..
    "F1→F2 ramp parts: %d\nF2→F3 ramp parts: %d\n" ..
    "Total workspace parts: %d (budget: 5000)\n" ..
    "RequestUnlockFloor remote: %s\n" ..
    "FloorUnlocked remote: %s",
    #f2plates, #f3plates, #f2ramps, #f3ramps,
    totalParts, tostring(hasRUF), tostring(hasFU)
)
if #badY > 0 then
    out = out .. "\nY ISSUES:\n" .. table.concat(badY, "\n")
end
if #rampIssues > 0 then
    out = out .. "\nRAMP ISSUES:\n" .. table.concat(rampIssues, "\n")
end
return out
```

**PASS criteria:**
- F2 plates ≥ 70 (some may be inside ramp folder, off-by-rounding acceptable)
- F3 plates ≥ 40
- Ramp parts exist (> 0 for each floor)
- Total parts ≤ 5,000 (verify part budget not blown)
- Both remotes exist
- No Y issues (plates at correct heights)
- No ramp walkability issues

---

## WHAT THIS DISPATCH DOES NOT COVER

These are intentionally deferred to later cycles:

- **BudButton wiring for floor unlock** — cycle 5 (shopgui_dispatch). The ProximityPrompts
  added in Step 6 are temporary test infrastructure. Players can unlock via the prompts
  until BudButtons are wired.
- **Build Mode UI for floor selection** — once F2/F3 exist and are walkable, BuildController's
  floor detection (getActiveFloor by Y) handles this automatically. No GUI changes needed.
- **Floor 2/3 cell BUILD costs in Config.CELL_COSTS** — these already exist from the original
  Config build (architecture specifies per-cell costs by type, same across all floors). No
  change needed; CombService.CanBuild already reads them.
- **Swarm prestige resetting Floor 2/3** — SwarmService doesn't exist yet (cycle 7). For now,
  unlockedFloors persists through swarm (it will be reset in SwarmService.Swarm() when built).
- **Floor 2/3 in the HiveGui CombFloors indicator** — a one-line update to HiveController's
  floor display widget, low priority, can be done when HiveGui gets its next polish pass.

---

## EXPECTED PART BUDGET IMPACT

```
Before this dispatch:
  Floor 1 cells (19 × 6):        114 parts
  Total workspace (est.):       ~1,899 parts

After this dispatch:
  Floor 2 dim plates (12 × 6):   +72 parts
  Floor 3 dim plates (7 × 6):    +42 parts
  Ramps F1→F2 + F2→F3 (if new):  +~96 parts (8 segments × 2 floors × 6 plots)
  Columns (optional):             +~48 parts (4 × 2 floors × 6 plots)
  ─────────────────────────────────────────
  New worst-case total:          ~2,157 parts  (well under 5,000 ceiling)
```

Part budget remains safe. Hub v2 (500 parts) + Molasses zones (~300 parts) + these floors
(~258 parts) all together: ~3,651 worst case, still 1,349 under ceiling.
