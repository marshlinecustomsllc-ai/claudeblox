# Dispatch 153 — Community Hub Rework
## Cycle 14 · A Bee's World

**Feature:** Epic rework of the Apiary Yard hub — the central social space all players pass through. Adds: (1) **Server Stats Board** — a world-space billboard showing live server-wide totals (bees across all players, honey produced this session, active foragers); (2) **Community Fountain Upgrade** — the existing honey drip fountain gains a particle ring and a "flow level" that scales with server honey output; (3) **Flower Arch entrance** — a welcoming arch of stacked flower parts framing the main hub entrance; (4) **Gathering Cluster** — 3 bench groups with ambient candle lanterns creating a "square" feel. The stats board is a real-time server-to-client feed via a new `ServerStats` RemoteEvent. Kids see big glowing numbers; adults see the live economy. Part budget: +3 permanent (1 Script for stats broadcast, 2 LocalScripts — stats board renderer, fountain controller) + ~60 world parts.
**Part budget impact:** +3 permanent + 60 world parts → **4,221 / 5,000**
**Execution order:** After dispatch 152 (Hive Stats Dashboard)

---

## DESIGN

### Server Stats Board

A 6×4-stud neon-edged billboard placed at the Weather Notice Board wall in the hub. Displays three live stats:

| Stat | Label | Source |
|------|-------|--------|
| Total bees on server | "🐝 X bees buzzing" | sum of all `CombCellCount × (10 + PrestigeLevel × 5)` |
| Honey produced this session | "🍯 X honey made" | sum of all `HoneyEarned` |
| Active foragers | "✈️ X foragers out" | count of players with `ForagingActive == true` |

Broadcast cadence: `ServerStatsService` fires `ServerStatsChanged` to all clients every 10 seconds. The `ServerStatsController` LocalScript updates a 3D BillboardGui attached to a world part.

### Community Fountain Upgrade

The existing `HoneyDripFountain` Part (in `Workspace.Map.Hub`) gets:
- A `ParticleEmitter` ring (amber droplets, low rate)
- A `PointLight` with golden colour, range 18, brightness 1.5
- A `BillboardGui` with "🍯 Community Fountain" label (DisplayOrder=5, always visible)

The fountain's `ParticleEmitter.Rate` scales with server honey output:
- < 500 total honey → rate 2 (gentle trickle)
- 500–2000 → rate 6
- 2000+ → rate 12 (flowing)

This is cosmetic only — the fountain level is a fun social signal of collective progress.

### Flower Arch Entrance

At the main entrance to the hub (Z = -265, the border with Wild Meadow), a 5-part arch:
- 2 vertical pillars made of stacked flower-coloured SmoothPlastic cylinders (BrightYellow, 1×6×1 studs each)
- 1 arch lintel (BrightYellow wedge part spanning the top, 8×1×2 studs)
- 2 decorative flower clusters on top of each pillar (0.8×0.8×0.8 sphere, BrightOrange)

Total: 7 parts. All Anchored=true, CanCollide=false except pillars (CanCollide=true).

### Gathering Cluster

Three bench clusters placed in a triangle arrangement in the hub centre:
Each cluster = 2 bench seats (2×1×0.5 SmoothPlastic Tan), 1 bench back (0.2×0.6×1 SmoothPlastic Tan), 1 candle lantern (1×1×1 Neon Yellow sphere atop a 0.3×1.2×0.3 Metal cylinder).
= 4+1 = 5 parts per cluster × 3 clusters = 15 parts.

All CanCollide=false on decorative parts; bench seats CanCollide=true for sitting aesthetics.

### BillboardGui architecture

The stats board uses a `BillboardGui` attached to a part in `Workspace.Map.Hub`:
- `StudsOffset = Vector3.new(0, 3, 0)` (floats above the board part)
- `Size = UDim2.new(0, 280, 0, 90)`
- `AlwaysOnTop = false` (occluded by world geometry — feels grounded)
- Three `TextLabel` children (one per stat)

The `ServerStatsController` LocalScript fires every time `ServerStatsChanged` arrives, updating the TextLabel texts.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ServerStatsService` | New Script in ServerScriptService |
| `ServerStatsController` | New LocalScript in StarterPlayerScripts |
| Hub world parts | +82 parts (board, arch, benches, fountain upgrade) |

---

## STEP A — Create ServerStatsService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("ServerStatsService") then
    print("⏭️  ServerStatsService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "ServerStatsService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- ServerStatsService — dispatch 153
-- Broadcasts server-wide stats (bees, honey, foragers) every 10 seconds.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RE_153: RemoteEvent = (function()
    local e = ReplicatedStorage:FindFirstChild("ServerStatsChanged")
    if e and e:IsA("RemoteEvent") then return e :: RemoteEvent end
    local re = Instance.new("RemoteEvent")
    re.Name   = "ServerStatsChanged"
    re.Parent = ReplicatedStorage
    return re
end)()

local function calcStats_153(): {bees: number, honey: number, foragers: number}
    local totalBees    = 0
    local totalHoney   = 0
    local totalForagers = 0
    for _, player in Players:GetPlayers() do
        local cells    = tonumber(player:GetAttribute("CombCellCount"))  or 0
        local prestige = tonumber(player:GetAttribute("PrestigeLevel"))  or 0
        local honey    = tonumber(player:GetAttribute("HoneyEarned"))    or 0
        local foraging = player:GetAttribute("ForagingActive") == true
        totalBees    = totalBees    + cells * (10 + prestige * 5)
        totalHoney   = totalHoney   + honey
        if foraging then totalForagers = totalForagers + 1 end
    end
    return {bees = totalBees, honey = totalHoney, foragers = totalForagers}
end

local function broadcast_153()
    local stats = calcStats_153()
    RE_153:FireAllClients(stats)
end

-- Broadcast every 10 seconds
task.spawn(function()
    while true do
        task.wait(10)
        broadcast_153()
    end
end)

-- Also broadcast when any player joins or leaves
Players.PlayerAdded:Connect(function()
    task.wait(3)  -- wait for DataService load
    broadcast_153()
end)
Players.PlayerRemoving:Connect(function()
    task.delay(1, broadcast_153)
end)

-- Initial broadcast after server warm-up
task.delay(5, broadcast_153)

print("[ServerStatsService] Ready — broadcasting server stats every 10s")
]]
    svc.Parent = SSS
    print("✅ ServerStatsService created")
end
```

---

## STEP B — Create ServerStatsController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("ServerStatsController") then
    print("⏭️  ServerStatsController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "ServerStatsController"
    ctrl.Source = [[
--!strict
-- ServerStatsController — dispatch 153
-- Updates the hub server-stats BillboardGui and fountain particle rate.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AMBER_153 = Color3.fromRGB(242, 168,  28)
local GOLD_153  = Color3.fromRGB(255, 210,  60)
local DARK_153  = Color3.fromRGB(40,  25,   8)
local WHITE_153 = Color3.fromRGB(255, 255, 255)

-- Wait for board part in hub
local boardPart_153: BasePart? = nil
task.spawn(function()
    local map = workspace:WaitForChild("Map", 15)
    if not map then return end
    local hub = map:WaitForChild("Hub", 10)
    if not hub then return end
    boardPart_153 = hub:WaitForChild("StatsBoard", 10) :: BasePart?
end)

-- Wait for fountain
local fountainEmitter_153: ParticleEmitter? = nil
task.spawn(function()
    local map = workspace:WaitForChild("Map", 15)
    if not map then return end
    local hub = map:WaitForChild("Hub", 10)
    if not hub then return end
    local fountain = hub:FindFirstChild("HoneyDripFountain", true)
    if fountain and fountain:IsA("BasePart") then
        fountainEmitter_153 = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
    end
end)

-- BillboardGui creation (attached to StatsBoard part once found)
local billGui_153: BillboardGui? = nil
local beeLabel_153:   TextLabel? = nil
local honeyLabel_153: TextLabel? = nil
local foragLabel_153: TextLabel? = nil

local function ensureBillboard_153(board: BasePart)
    if billGui_153 and billGui_153.Parent then return end

    local bg = Instance.new("BillboardGui")
    bg.Name          = "StatsBillboard"
    bg.Size          = UDim2.new(0, 280, 0, 90)
    bg.StudsOffset   = Vector3.new(0, 3, 0)
    bg.AlwaysOnTop   = false
    bg.Parent        = board

    local bg2 = Instance.new("Frame")
    bg2.Size                   = UDim2.new(1, 0, 1, 0)
    bg2.BackgroundColor3       = DARK_153
    bg2.BackgroundTransparency = 0.1
    bg2.BorderSizePixel        = 0
    bg2.Parent                 = bg
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = bg2
    local stroke = Instance.new("UIStroke"); stroke.Color = GOLD_153; stroke.Thickness = 1.5; stroke.Parent = bg2

    local function makeRow(yOffset: number, text: string, color: Color3): TextLabel
        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(1, -16, 0, 22)
        lbl.Position               = UDim2.new(0, 8, 0, yOffset)
        lbl.BackgroundTransparency = 1
        lbl.Font                   = Enum.Font.GothamBold
        lbl.TextSize               = 13
        lbl.TextColor3             = color
        lbl.TextXAlignment         = Enum.TextXAlignment.Left
        lbl.Text                   = text
        lbl.Parent                 = bg2
        return lbl
    end

    beeLabel_153   = makeRow(8,  "🐝 … bees buzzing",  GOLD_153)
    honeyLabel_153 = makeRow(34, "🍯 … honey made",    AMBER_153)
    foragLabel_153 = makeRow(60, "✈️ … foragers out",  WHITE_153)

    billGui_153 = bg
end

local function updateDisplay_153(bees: number, honey: number, foragers: number)
    -- Board
    local board = boardPart_153
    if board then
        ensureBillboard_153(board :: BasePart)
        if beeLabel_153   then (beeLabel_153   :: TextLabel).Text = "🐝 " .. bees    .. " bees buzzing" end
        if honeyLabel_153 then (honeyLabel_153 :: TextLabel).Text = "🍯 " .. honey   .. " honey made"  end
        if foragLabel_153 then (foragLabel_153 :: TextLabel).Text = "✈️ " .. foragers .. " forager" .. (foragers == 1 and "" or "s") .. " out" end
    end

    -- Fountain emitter rate
    local emitter = fountainEmitter_153
    if emitter then
        local rate = honey < 500 and 2 or (honey < 2000 and 6 or 12)
        emitter.Rate = rate
    end
end

-- Listen for broadcasts
local RE = ReplicatedStorage:WaitForChild("ServerStatsChanged", 15) :: RemoteEvent?
if RE then
    RE.OnClientEvent:Connect(function(data: any)
        local d = data :: {bees: number, honey: number, foragers: number}
        updateDisplay_153(d.bees, d.honey, d.foragers)
    end)
end

print("[ServerStatsController] Ready — server stats board active")
]]
    ctrl.Parent = SPS
    print("✅ ServerStatsController created")
end
```

---

## STEP C — Build hub world parts (StatsBoard, Arch, Benches, Fountain upgrade)

Command Bar:

```lua
local hub = workspace:WaitForChild("Map"):WaitForChild("Hub")
if hub:FindFirstChild("CommunityRework_153") then
    print("⏭️  Community rework parts already exist — skip")
    return
end

local container = Instance.new("Folder")
container.Name   = "CommunityRework_153"
container.Parent = hub

local AMBER = Color3.fromRGB(242, 168, 28)
local GOLD  = Color3.fromRGB(255, 210, 60)
local DARK  = Color3.fromRGB(40,  25,  8)
local TAN   = Color3.fromRGB(212, 188, 144)
local METAL = Color3.fromRGB(120, 120, 120)

local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored        = props.anchored ~= false
    p.CanCollide      = props.collide  or false
    p.Size            = props.size     or Vector3.new(1,1,1)
    p.Position        = props.pos      or Vector3.new(0,0,0)
    p.BrickColor      = BrickColor.new(props.color or "Medium stone grey")
    p.Material        = props.mat      or Enum.Material.SmoothPlastic
    p.Transparency    = props.trans    or 0
    p.Name            = props.name     or "Part"
    p.Parent          = container
    if props.neon then p.Material = Enum.Material.Neon end
    return p
end

-- ── STATS BOARD ─────────────────────────────────────────────────────
-- Flat board part on the north wall of the hub, ~centred
local board = makePart({name="StatsBoard", size=Vector3.new(6,4,0.4), pos=Vector3.new(0, 4, -320), color="Dark orange", collide=false})
-- Neon border frame (4 thin strips)
makePart({name="BoardTop",    size=Vector3.new(6.4, 0.25, 0.5), pos=Vector3.new(0, 6.12, -320), neon=true, color="Bright yellow"})
makePart({name="BoardBottom", size=Vector3.new(6.4, 0.25, 0.5), pos=Vector3.new(0, 1.88, -320), neon=true, color="Bright yellow"})
makePart({name="BoardLeft",   size=Vector3.new(0.25, 4.5,  0.5), pos=Vector3.new(-3.12, 4, -320), neon=true, color="Bright yellow"})
makePart({name="BoardRight",  size=Vector3.new(0.25, 4.5,  0.5), pos=Vector3.new( 3.12, 4, -320), neon=true, color="Bright yellow"})
-- Title strip above board
local titlePart = makePart({name="BoardTitle", size=Vector3.new(6,1,0.4), pos=Vector3.new(0, 7.5, -320), color="Really black"})
local titleGui = Instance.new("SurfaceGui")
titleGui.Face = Enum.NormalId.Front
titleGui.Parent = titlePart
local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1,0,1,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🌍  HIVE SERVER  🌍"
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 28
titleLbl.TextColor3 = GOLD
titleLbl.TextXAlignment = Enum.TextXAlignment.Center
titleLbl.Parent = titleGui

-- ── FLOWER ARCH ENTRANCE ─────────────────────────────────────────────
-- Placed at hub entrance Z = -265 (border with Wild Meadow)
-- Left pillar
makePart({name="ArchPillarL", size=Vector3.new(1,6,1),     pos=Vector3.new(-5, 3, -265), collide=true, color="Bright yellow", mat=Enum.Material.SmoothPlastic})
-- Right pillar
makePart({name="ArchPillarR", size=Vector3.new(1,6,1),     pos=Vector3.new( 5, 3, -265), collide=true, color="Bright yellow", mat=Enum.Material.SmoothPlastic})
-- Lintel
makePart({name="ArchLintel",  size=Vector3.new(11,1,1.5),  pos=Vector3.new( 0, 6.5, -265), collide=false, color="Bright yellow", mat=Enum.Material.SmoothPlastic})
-- Flower tops
makePart({name="ArchFlowerL", size=Vector3.new(1.4,1.4,1.4), pos=Vector3.new(-5, 7.2, -265), collide=false, color="Bright orange", mat=Enum.Material.SmoothPlastic})
makePart({name="ArchFlowerR", size=Vector3.new(1.4,1.4,1.4), pos=Vector3.new( 5, 7.2, -265), collide=false, color="Bright orange", mat=Enum.Material.SmoothPlastic})
-- Arch sign
local signPart = makePart({name="ArchSign", size=Vector3.new(5,1.2,0.3), pos=Vector3.new(0, 8.2, -265), color="Really black"})
local signGui = Instance.new("SurfaceGui"); signGui.Face = Enum.NormalId.Front; signGui.Parent = signPart
local signLbl = Instance.new("TextLabel"); signLbl.Size = UDim2.new(1,0,1,0); signLbl.BackgroundTransparency = 1
signLbl.Text = "🌸 APIARY YARD 🌸"; signLbl.Font = Enum.Font.GothamBold; signLbl.TextSize = 22
signLbl.TextColor3 = GOLD; signLbl.TextXAlignment = Enum.TextXAlignment.Center; signLbl.Parent = signGui

-- ── GATHERING BENCHES (3 clusters in triangle) ────────────────────────
local benchPositions = {
    Vector3.new(-8, 0.5, -295),   -- west cluster
    Vector3.new( 8, 0.5, -295),   -- east cluster
    Vector3.new( 0, 0.5, -305),   -- south cluster
}
for i, basePos in benchPositions do
    -- Seat
    makePart({name="BenchSeat"..i,  size=Vector3.new(2.5,0.4,1),   pos=basePos + Vector3.new(0,0,0), collide=true,  color="Brick yellow"})
    -- Back
    makePart({name="BenchBack"..i,  size=Vector3.new(2.5,0.7,0.2), pos=basePos + Vector3.new(0,0.55,-0.4), collide=false, color="Brick yellow"})
    -- Leg L
    makePart({name="BenchLegL"..i,  size=Vector3.new(0.2,0.5,0.8), pos=basePos + Vector3.new(-1.1,-0.25,0), collide=false, color="Medium stone grey", mat=Enum.Material.Metal})
    -- Leg R
    makePart({name="BenchLegR"..i,  size=Vector3.new(0.2,0.5,0.8), pos=basePos + Vector3.new( 1.1,-0.25,0), collide=false, color="Medium stone grey", mat=Enum.Material.Metal})
    -- Lantern pole
    makePart({name="LanternPole"..i, size=Vector3.new(0.2,1.5,0.2), pos=basePos + Vector3.new(1.6,0.75,0), collide=false, color="Dark grey", mat=Enum.Material.Metal})
    -- Lantern glow
    local lamp = makePart({name="Lantern"..i, size=Vector3.new(0.7,0.7,0.7), pos=basePos + Vector3.new(1.6,1.85,0), collide=false, neon=true, color="Bright yellow"})
    local light = Instance.new("PointLight")
    light.Brightness = 1.2; light.Color = AMBER; light.Range = 10; light.Parent = lamp
end

-- ── FOUNTAIN UPGRADE ─────────────────────────────────────────────────
local fountain = hub:FindFirstChild("HoneyDripFountain", true)
if fountain and fountain:IsA("BasePart") then
    -- Particle ring
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture    = "rbxassetid://6880375532"  -- amber droplet
    emitter.Color      = ColorSequence.new(AMBER, GOLD)
    emitter.Size       = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Lifetime   = NumberRange.new(1.5, 2.5)
    emitter.Speed      = NumberRange.new(2, 4)
    emitter.Rate       = 4
    emitter.SpreadAngle = Vector2.new(30, 30)
    emitter.LightEmission = 0.3
    emitter.Parent     = fountain

    -- Point light
    local fl = Instance.new("PointLight")
    fl.Color      = GOLD
    fl.Range      = 18
    fl.Brightness = 1.5
    fl.Parent     = fountain

    print("✅ Fountain upgrade applied")
else
    print("⚠️  HoneyDripFountain not found — fountain upgrade skipped")
end

local count = 0
for _, p in container:GetDescendants() do if p:IsA("BasePart") then count = count + 1 end end
print("✅ Community hub rework: " .. count .. " parts created in Hub.CommunityRework_153")
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")
local hub = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Hub")

local svc    = SSS:FindFirstChild("ServerStatsService")
local ctrl   = SPS and SPS:FindFirstChild("ServerStatsController")
local re     = RS:FindFirstChild("ServerStatsChanged")
local rework = hub and hub:FindFirstChild("CommunityRework_153")
local board  = rework and rework:FindFirstChild("StatsBoard")
local fountain = hub and hub:FindFirstChild("HoneyDripFountain", true)

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " ServerStatsService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("FireAllClients", 1, true) and "✅" or "❌") .. " FireAllClients broadcast")
table.insert(checks, (svc and svc.Source:find("task.wait(10)", 1, true) and "✅" or "❌") .. " 10s broadcast cadence")
table.insert(checks, (re and "✅" or "❌") .. " ServerStatsChanged RemoteEvent")
table.insert(checks, (ctrl and "✅" or "❌") .. " ServerStatsController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("StatsBillboard", 1, true) and "✅" or "❌") .. " StatsBillboard BillboardGui")
table.insert(checks, (ctrl and ctrl.Source:find("fountainEmitter_153", 1, true) and "✅" or "❌") .. " fountain rate scaling")
table.insert(checks, (rework and "✅" or "❌") .. " CommunityRework_153 folder in Hub")
table.insert(checks, (board and "✅" or "❌") .. " StatsBoard part exists")

-- Count parts
local partCount = 0
if rework then
    for _, p in rework:GetDescendants() do if p:IsA("BasePart") then partCount = partCount + 1 end end
end
table.insert(checks, (partCount >= 20 and "✅" or "❌") .. " Rework parts: " .. partCount .. " (expect 20+)")

-- Check fountain emitter
local fountainEmitter = fountain and fountain:IsA("BasePart") and fountain:FindFirstChildOfClass("ParticleEmitter")
table.insert(checks, (fountainEmitter and "✅" or "⚠️") .. " Fountain ParticleEmitter" .. (fountainEmitter and "" or " (fountain part not found — check name)"))

-- Check unanchored
local unanchored = {}
if rework then
    for _, p in rework:GetDescendants() do
        if p:IsA("BasePart") and not p.Anchored then table.insert(unanchored, p.Name) end
    end
end
table.insert(checks, (#unanchored == 0 and "✅" or "❌") .. " All parts anchored" .. (#unanchored > 0 and (" — unanchored: " .. table.concat(unanchored, ", ")) or ""))

print("=== DISPATCH 153 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 153 complete" or "❌ SOME CHECKS FAILED")

print("\nServer stats board: bees / honey made / foragers — live 10s broadcast")
print("Flower arch at hub entrance Z=-265 | 3 bench clusters with lanterns | fountain particle upgrade")
print("Part budget: ~60 world parts + 3 permanent scripts → 4,221 / 5,000")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| ServerStatsService (Script) | +1 permanent |
| ServerStatsController (LocalScript) | +0 permanent |
| StatsBoard + neon frame + title | 7 |
| Flower arch (pillars + lintel + flowers + sign) | 8 |
| 3 × bench cluster (seat + back + 2 legs + pole + lantern) | 18 |
| Fountain ParticleEmitter + PointLight | 0 (attached to existing part) |
| Total world parts | 33 |
| **Dispatch 153 total** | **+1 permanent, +33 world parts** |
| **Running total** | **4,192 / 5,000** |

*(Note: previous estimate said ~60+3; actual Lua produces 33 world parts and 1 permanent server Script. LocalScript is permanent=0.)*

---

## NOTES

- `ServerStatsService` broadcasts to ALL clients simultaneously with `FireAllClients`. This is intentional: the stats board is a shared world-space object, so every player's `ServerStatsController` updates the same `BillboardGui` attached to the `StatsBoard` part. In a 6-player server, all 6 clients update the same world-space board independently — this is fine because they all receive the same data and produce the same result.
- The `StatsBoard` part is positioned at `(0, 4, -320)` — the north wall of the hub. If the existing hub geometry differs, the Z value may need adjustment. The verification sweep confirms the part exists; the gamemaster can adjust position via a simple property set if needed.
- `HoneyDripFountain` lookup uses `FindFirstChild("HoneyDripFountain", true)` (recursive) because the part may be in a subfolder. The Step C script prints a warning if it can't find it — the fountain upgrade is cosmetic and its absence doesn't break the dispatch.
- The bench lanterns use Neon material spheres with `PointLight` children. This gives a warm ambient glow without any script — purely decorative. Range=10 is intentionally short to keep the hub from being uniformly bright; each bench cluster creates a small pool of warm light, which is more interesting compositionally.
- `foragLabel_153` uses `foragers == 1 and "" or "s"` for "forager/foragers" pluralisation. This small detail matters for kids — seeing "1 forager out" vs "3 foragers out" reads naturally.
- The flower arch at Z=-265 is a visual waypoint that tells new players "the hub is through here." The BrightYellow and BrightOrange colours match the Warm Wax house style and echo the flower species already in Wild Meadow. The arch sign "🌸 APIARY YARD 🌸" provides place identity.
- `BROOD_RATE_152` constant is 4.0 honey/min. This matches the Config.lua baseline established in the original architecture. If the actual server-side rate in CombService differs, update this constant in a later patch — the stats board displays an estimate, not a guarantee, so a small delta is acceptable.
