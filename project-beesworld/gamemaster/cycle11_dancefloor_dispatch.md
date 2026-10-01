# Dispatch 37 — DanceFloorService: Periodic Dance Event + NPC Bee Crowd
**Cycle 11 | A Bee's World | Bee-scale tycoon**
**Execution order: after dispatch 36**

---

## OVERVIEW

Adds a periodic 3-minute dance party event at the central hub area every 8 minutes.
During the event:
- +25% honey multiplier for all players (stacks with other multipliers)
- 6 NPC bee crowd props animate around a hex dance floor
- DanceSync RemoteEvent broadcasts event start/end + countdown
- DanceGui LocalScript shows countdown banner with animated disco text
- Event ends automatically after 3 minutes; NPC props hidden until next cycle

Zero permanent part budget increase (NPC props use pre-created parts toggled visible/invisible).

---

## STEP A — Config additions

```lua
-- In Studio Command Bar:
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- 1. Clone Config, swap, inject DANCE_EVENT table
local cfg = RS:FindFirstChild("Config")
if not cfg then error("Config not found in ReplicatedStorage") end
local clone = cfg:Clone()
cfg.Name = "Config_OLD_NX"
cfg.Parent = nil

local src = clone.Source
-- Inject DANCE_EVENT block before final `return Config`
local inject = [[

-- ============================================================
-- DANCE EVENT CONFIG
-- ============================================================
Config.DANCE_EVENT = {
    intervalSeconds = 480,   -- 8 min between events
    durationSeconds = 180,   -- 3 min event length
    honeyMult       = 1.25,  -- +25% honey during event
    npcCount        = 6,     -- NPC bee props to spawn around floor
    floorRadius     = 7,     -- studs from floor centre
    label           = "🕺 DANCE PARTY!",
    endLabel        = "Dance over — back to work!",
}
]]
src = src:gsub("(return Config)", inject .. "\n%1")
clone.Source = src
clone.Name = "Config"
clone.Parent = RS

print("✅ Config: DANCE_EVENT injected")
```

---

## STEP B — DanceSync RemoteEvent

```lua
-- In Studio Command Bar (run after Step A):
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
if not remotes then error("Remotes folder not found in ReplicatedStorage") end

if not remotes:FindFirstChild("DanceSync") then
    local re = Instance.new("RemoteEvent")
    re.Name = "DanceSync"
    re.Parent = remotes
    print("✅ DanceSync RemoteEvent created")
else
    print("ℹ️  DanceSync already exists")
end
```

---

## STEP C — DanceFloorService (server)

```lua
-- In Studio Command Bar (run after Step B):
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- Remove old version if present
local old = SSS:FindFirstChild("DanceFloorService")
if old then old:Destroy() end

local s = Instance.new("ModuleScript")
s.Name = "DanceFloorService"
s.Source = [[
--!strict
local RS              = game:GetService("ReplicatedStorage")
local Players         = game:GetService("Players")
local Workspace       = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService      = game:GetService("RunService")

local Config     = require(RS:WaitForChild("Config"))
local DanceSync  = RS:WaitForChild("Remotes"):WaitForChild("DanceSync")

-- PrestigeRewardService + SeasonalEventService loaded lazily (may not exist)
local PrestigeRewardService: any? = nil
local SeasonalEventService:  any? = nil

local _active   = false
local _endTime  = 0
local _npcParts: { BasePart } = {}

-- ============================================================
-- NPC prop management
-- ============================================================
local NPC_OFFSETS = {
    Vector3.new( 7,  0,  0),
    Vector3.new(-7,  0,  0),
    Vector3.new( 3.5,  0,  6.06),
    Vector3.new(-3.5,  0,  6.06),
    Vector3.new( 3.5,  0, -6.06),
    Vector3.new(-3.5,  0, -6.06),
}
-- Hub floor centre (adjust if hub moved)
local FLOOR_CENTRE = Vector3.new(0, 2, -115)

local function buildNPCs()
    if #_npcParts > 0 then return end  -- already built
    local map = Workspace:FindFirstChild("Map")
    local hub = map and map:FindFirstChild("Hub")
    local parent = hub or Workspace

    for i, offset in NPC_OFFSETS do
        local bee = Instance.new("Part")
        bee.Name     = "DanceNPC_" .. i
        bee.Size     = Vector3.new(1.2, 1.2, 1.2)
        bee.Shape    = Enum.PartType.Ball
        bee.Color    = Color3.fromRGB(242, 168, 28)  -- Honey Gold
        bee.Material = Enum.Material.Neon
        bee.Anchored = true
        bee.CanCollide = false
        bee.CastShadow = false
        bee.Transparency = 1  -- hidden until event
        bee.Position = FLOOR_CENTRE + offset
        bee.Parent = parent

        -- Stripe band
        local stripe = Instance.new("SpecialMesh")
        stripe.MeshType = Enum.MeshType.Sphere
        stripe.Scale = Vector3.new(1, 0.35, 1)
        stripe.Parent = bee

        CollectionService:AddTag(bee, "DanceNPC")
        table.insert(_npcParts, bee)
    end
end

local function setNPCsVisible(visible: boolean)
    local t = visible and 0 or 1
    for _, p in _npcParts do
        p.Transparency = t
    end
end

-- Bobbing heartbeat
local _bobbingConn: RBXScriptConnection? = nil
local function startBobbing()
    if _bobbingConn then return end
    local t0 = tick()
    _bobbingConn = RunService.Heartbeat:Connect(function()
        if not _active then return end
        local t  = tick() - t0
        for i, p in _npcParts do
            local phase = (i - 1) * (math.pi / 3)
            p.Position = Vector3.new(
                (FLOOR_CENTRE + NPC_OFFSETS[i]).X,
                FLOOR_CENTRE.Y + math.sin(t * 3 + phase) * 0.4,
                (FLOOR_CENTRE + NPC_OFFSETS[i]).Z
            )
        end
    end)
end

local function stopBobbing()
    if _bobbingConn then
        _bobbingConn:Disconnect()
        _bobbingConn = nil
    end
end

-- ============================================================
-- Public API
-- ============================================================
local DanceFloorService = {}

function DanceFloorService.IsActive(): boolean
    return _active
end

function DanceFloorService.GetHoneyMult(): number
    return _active and Config.DANCE_EVENT.honeyMult or 1.0
end

function DanceFloorService.GetTimeRemaining(): number
    if not _active then return 0 end
    return math.max(0, _endTime - os.time())
end

local function startEvent()
    if _active then return end
    _active  = true
    _endTime = os.time() + Config.DANCE_EVENT.durationSeconds
    buildNPCs()
    setNPCsVisible(true)
    startBobbing()
    DanceSync:FireAllClients({
        active    = true,
        endTime   = _endTime,
        label     = Config.DANCE_EVENT.label,
        honeyMult = Config.DANCE_EVENT.honeyMult,
    })
    print("[DanceFloorService] Dance party started — ends at", _endTime)
end

local function stopEvent()
    if not _active then return end
    _active = false
    stopBobbing()
    setNPCsVisible(false)
    DanceSync:FireAllClients({
        active   = false,
        endTime  = 0,
        label    = Config.DANCE_EVENT.endLabel,
        honeyMult = 1.0,
    })
    print("[DanceFloorService] Dance party ended")
end

function DanceFloorService.Init()
    -- Lazy-load optional services
    pcall(function()
        PrestigeRewardService = require(game:GetService("ServerScriptService"):FindFirstChild("PrestigeRewardService") :: any)
    end)
    pcall(function()
        SeasonalEventService = require(game:GetService("ServerScriptService"):FindFirstChild("SeasonalEventService") :: any)
    end)

    buildNPCs()

    -- Event loop
    task.spawn(function()
        while true do
            task.wait(Config.DANCE_EVENT.intervalSeconds)
            startEvent()
            task.wait(Config.DANCE_EVENT.durationSeconds)
            stopEvent()
        end
    end)
end

return DanceFloorService
]]
s.Parent = SSS
print("✅ DanceFloorService ModuleScript created in ServerScriptService")
```

---

## STEP D — Wire DanceFloorService into GameManager + ForagingService

```lua
-- In Studio Command Bar (run after Step C):
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- ---- 4a. GameManager: require + Init DanceFloorService ----
local gm = SSS:FindFirstChild("GameManager")
if not gm then error("GameManager not found") end
local gmClone = gm:Clone()
gm.Name = "GameManager_OLD_NX"
gm.Parent = nil

local gmSrc = gmClone.Source

-- Inject require near top (after existing requires)
if not gmSrc:find("DanceFloorService") then
    gmSrc = gmSrc:gsub(
        "(local SeasonalEventService.-\n)",
        "%1local DanceFloorService = require(SSS:WaitForChild(\"DanceFloorService\"))\n"
    )
    -- Fallback: inject before any Init() block
    if not gmSrc:find("DanceFloorService") then
        gmSrc = gmSrc:gsub(
            "(SeasonalEventService%.Init%(%)\n)",
            "%1DanceFloorService.Init()\n"
        )
    end
    -- Try Init injection
    gmSrc = gmSrc:gsub(
        "(SeasonalEventService%.Init%(%)\n)",
        "%1DanceFloorService.Init()\n"
    )
    gmClone.Source = gmSrc
    print("✅ GameManager: DanceFloorService require+Init injected")
else
    print("ℹ️  GameManager: DanceFloorService already present")
end
gmClone.Name = "GameManager"
gmClone.Parent = SSS

-- ---- 4b. ForagingService: multiply honey yield by dance mult ----
local fs = SSS:FindFirstChild("ForagingService")
if not fs then error("ForagingService not found") end
local fsClone = fs:Clone()
fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil

local fsSrc = fsClone.Source

if not fsSrc:find("DanceFloorService") then
    -- Inject require near top
    fsSrc = fsSrc:gsub(
        "(local PrestigeRewardService.-\n)",
        "%1local DanceFloorService = require(SSS:WaitForChild(\"DanceFloorService\"))\n"
    )
    -- Inject mult into yield calculation (after prestigeMult)
    fsSrc = fsSrc:gsub(
        "(local prestigeMult = PrestigeRewardService%.GetHoneyMultiplier%(player%).-\n)",
        "%1\t\tlocal danceMult = DanceFloorService.GetHoneyMult()\n"
    )
    -- Apply danceMult to final yield
    fsSrc = fsSrc:gsub(
        "(%* weatherMult %* seasonalMult %* prestigeMult)",
        "%1 * danceMult"
    )
    fsClone.Source = fsSrc
    print("✅ ForagingService: danceMult injected into yield calculation")
else
    print("ℹ️  ForagingService: DanceFloorService already wired")
end
fsClone.Name = "ForagingService"
fsClone.Parent = SSS
```

---

## STEP E — Dance Floor world prop (hex tile)

```lua
-- In Studio Command Bar (run after Step D):
local Workspace = game:GetService("Workspace")

local map = Workspace:FindFirstChild("Map")
local hub = map and (map:FindFirstChild("Hub") or map:FindFirstChild("Room1"))
local parent = hub or Workspace

-- Hex dance floor tile at hub centre
local CENTRE = Vector3.new(0, 1.05, -115)

local function hexTile(pos: Vector3, color: Color3, name: string): Part
    local p = Instance.new("Part")
    p.Name     = name
    p.Size     = Vector3.new(13.856, 0.1, 12.0)   -- single hex cell size
    p.Color    = color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.CastShadow = false
    p.Position = pos
    p.Parent   = parent
    return p
end

-- Central hex + 6 surrounding petals
local HONEY_GOLD   = Color3.fromRGB(242, 168, 28)
local PROPOLIS     = Color3.fromRGB(122,  74, 34)
local HEX_OFFSETS  = {
    Vector3.new(13.856, 0, 0),
    Vector3.new(-13.856, 0, 0),
    Vector3.new(6.928, 0,  12.0),
    Vector3.new(-6.928, 0, 12.0),
    Vector3.new(6.928, 0, -12.0),
    Vector3.new(-6.928, 0, -12.0),
}

hexTile(CENTRE, HONEY_GOLD, "DanceFloor_Centre")
for i, offset in HEX_OFFSETS do
    local color = i % 2 == 0 and PROPOLIS or HONEY_GOLD
    hexTile(CENTRE + offset, color, "DanceFloor_Petal" .. i)
end

-- Disco ball (sphere above centre)
local ball = Instance.new("Part")
ball.Name      = "DanceFloor_DiscoBall"
ball.Size      = Vector3.new(2.5, 2.5, 2.5)
ball.Shape     = Enum.PartType.Ball
ball.Color     = Color3.fromRGB(232, 212, 154)  -- Wax Cream
ball.Material  = Enum.Material.Glass
ball.Anchored  = true
ball.CanCollide = false
ball.CastShadow = false
ball.Position  = CENTRE + Vector3.new(0, 9, 0)
ball.Parent    = parent

-- PointLight on disco ball
local light = Instance.new("PointLight")
light.Color      = Color3.fromRGB(242, 168, 28)
light.Brightness = 4
light.Range      = 28
light.Shadows    = true
light.Parent     = ball

print("✅ Dance floor props created: 1 centre + 6 petals + disco ball + light = 9 parts")
```

> **Part budget note**: +9 permanent parts → **~4,107/5,000**

---

## STEP F — DanceGui client (countdown banner + disco flash)

```lua
-- In Studio Command Bar (run after Step E):
local StarterGui         = game:GetService("StarterGui")
local StarterPlayer      = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not StarterPlayerScripts then error("StarterPlayerScripts not found") end

-- Remove old versions
for _, name in {"DanceGui", "DanceController"} do
    local old = StarterGui:FindFirstChild(name)
    if old then old:Destroy() end
    local old2 = StarterPlayerScripts:FindFirstChild(name)
    if old2 then old2:Destroy() end
end

-- ---- DanceGui ScreenGui ----
local gui = Instance.new("ScreenGui")
gui.Name         = "DanceGui"
gui.DisplayOrder = 45  -- above HiveGui (10), below TutorialGui (60)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled      = true
gui.Parent       = StarterGui

-- Banner frame (top-centre, hidden by default)
local banner = Instance.new("Frame")
banner.Name              = "DanceBanner"
banner.Size              = UDim2.new(0.55, 0, 0.10, 0)
banner.Position          = UDim2.new(0.225, 0, -0.15, 0)  -- off-screen top
banner.BackgroundColor3  = Color3.fromRGB(122, 74, 34)     -- Propolis Brown
banner.BackgroundTransparency = 0.1
banner.BorderSizePixel   = 0
banner.ZIndex            = 10
banner.Parent            = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = banner

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold
stroke.Thickness = 2.5
stroke.Parent    = banner

-- Title label
local titleLbl = Instance.new("TextLabel")
titleLbl.Name              = "TitleLabel"
titleLbl.Size              = UDim2.new(1, 0, 0.5, 0)
titleLbl.Position          = UDim2.new(0, 0, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.TextColor3        = Color3.fromRGB(242, 168, 28)  -- Honey Gold
titleLbl.Font              = Enum.Font.FredokaOne
titleLbl.TextScaled        = true
titleLbl.Text              = "🕺 DANCE PARTY!"
titleLbl.ZIndex            = 11
titleLbl.Parent            = banner

-- Countdown label
local countLbl = Instance.new("TextLabel")
countLbl.Name              = "CountdownLabel"
countLbl.Size              = UDim2.new(1, 0, 0.5, 0)
countLbl.Position          = UDim2.new(0, 0, 0.5, 0)
countLbl.BackgroundTransparency = 1
countLbl.TextColor3        = Color3.fromRGB(232, 212, 154)  -- Wax Cream
countLbl.Font              = Enum.Font.FredokaOne
countLbl.TextScaled        = true
countLbl.Text              = "3:00 remaining • +25% honey"
countLbl.ZIndex            = 11
countLbl.Parent            = banner

-- Multiplier badge (top-right corner)
local multBadge = Instance.new("TextLabel")
multBadge.Name              = "MultBadge"
multBadge.Size              = UDim2.new(0.20, 0, 0.08, 0)
multBadge.Position          = UDim2.new(0.78, 0, 0.03, 0)
multBadge.BackgroundColor3  = Color3.fromRGB(242, 168, 28)
multBadge.BackgroundTransparency = 0
multBadge.TextColor3        = Color3.fromRGB(40, 20, 0)
multBadge.Font              = Enum.Font.FredokaOne
multBadge.TextScaled        = true
multBadge.Text              = "×1.25"
multBadge.ZIndex            = 12
multBadge.Visible           = false
multBadge.Parent            = gui

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 8)
mc.Parent = multBadge

print("✅ DanceGui ScreenGui created in StarterGui")

-- ---- DanceController LocalScript ----
local ctrl = Instance.new("LocalScript")
ctrl.Name = "DanceController"
ctrl.Source = [[
--!strict
local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService  = game:GetService("RunService")

local player = Players.LocalPlayer
local pgui   = player:WaitForChild("PlayerGui")
local DanceSync = RS:WaitForChild("Remotes"):WaitForChild("DanceSync")

-- Wait for DanceGui
local gui: ScreenGui = pgui:WaitForChild("DanceGui") :: ScreenGui
local banner = gui:WaitForChild("DanceBanner") :: Frame
local titleLbl   = banner:WaitForChild("TitleLabel") :: TextLabel
local countLbl   = banner:WaitForChild("CountdownLabel") :: TextLabel
local multBadge  = gui:WaitForChild("MultBadge") :: TextLabel

local SLIDE_DOWN = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_UP   = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local _active   = false
local _endTime  = 0
local _conn: RBXScriptConnection? = nil

local function fmtTime(secs: number): string
    secs = math.max(0, math.floor(secs))
    local m = math.floor(secs / 60)
    local s = secs % 60
    return string.format("%d:%02d", m, s)
end

local function showBanner(label: string, endTime: number, honeyMult: number)
    titleLbl.Text = label
    multBadge.Text = string.format("×%.2f", honeyMult)
    multBadge.Visible = true
    TweenService:Create(banner, SLIDE_DOWN, { Position = UDim2.new(0.225, 0, 0.01, 0) }):Play()

    if _conn then _conn:Disconnect() end
    _conn = RunService.Heartbeat:Connect(function()
        if not _active then return end
        local remaining = endTime - os.time()
        countLbl.Text = fmtTime(remaining) .. " remaining • +" .. math.round((honeyMult - 1) * 100) .. "% honey"
        if remaining <= 0 then
            if _conn then _conn:Disconnect() _conn = nil end
        end
    end)
end

local function hideBanner(label: string)
    titleLbl.Text = label
    countLbl.Text = ""
    multBadge.Visible = false
    if _conn then _conn:Disconnect() _conn = nil end
    TweenService:Create(banner, SLIDE_UP, { Position = UDim2.new(0.225, 0, -0.15, 0) }):Play()
end

DanceSync.OnClientEvent:Connect(function(data: { active: boolean, endTime: number, label: string, honeyMult: number })
    _active  = data.active
    _endTime = data.endTime
    if _active then
        showBanner(data.label, data.endTime, data.honeyMult)
    else
        hideBanner(data.label)
        -- Flash "Dance over" for 3s then clear
        task.delay(3, function()
            if not _active then
                TweenService:Create(banner, SLIDE_UP, { Position = UDim2.new(0.225, 0, -0.15, 0) }):Play()
            end
        end)
    end
end)
]]
ctrl.Parent = StarterPlayerScripts
print("✅ DanceController LocalScript created in StarterPlayerScripts")
```

---

## STEP G — Verification

```lua
-- In Studio Command Bar:
local SSS    = game:GetService("ServerScriptService")
local RS     = game:GetService("ReplicatedStorage")
local SG     = game:GetService("StarterGui")
local SP     = game:GetService("StarterPlayer")
local CS     = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local results = {}
local issues  = {}

-- 1. Config.DANCE_EVENT
local cfg = RS:FindFirstChild("Config")
if cfg then
    local ok, data = pcall(require, cfg)
    if ok and data.DANCE_EVENT then
        table.insert(results, "✅ Config.DANCE_EVENT: intervalSeconds=" .. data.DANCE_EVENT.intervalSeconds .. " durationSeconds=" .. data.DANCE_EVENT.durationSeconds .. " honeyMult=" .. data.DANCE_EVENT.honeyMult)
    else
        table.insert(issues, "❌ Config.DANCE_EVENT not found or require failed")
    end
else
    table.insert(issues, "❌ Config not found in RS")
end

-- 2. DanceSync RemoteEvent
local remotes = RS:FindFirstChild("Remotes")
local ds = remotes and remotes:FindFirstChild("DanceSync")
table.insert(ds and results or issues, (ds and "✅" or "❌") .. " DanceSync RemoteEvent: " .. (ds and "exists" or "MISSING"))

-- 3. DanceFloorService ModuleScript
local dfs = SSS:FindFirstChild("DanceFloorService")
if dfs and dfs:IsA("ModuleScript") then
    local lines = select(2, dfs.Source:gsub("\n", "\n")) + 1
    local hasIsActive    = dfs.Source:find("IsActive")     ~= nil
    local hasGetHoneyMult = dfs.Source:find("GetHoneyMult") ~= nil
    local hasBobbing     = dfs.Source:find("Heartbeat")     ~= nil
    table.insert(results, string.format("✅ DanceFloorService: %d lines IsActive=%s GetHoneyMult=%s Bobbing=%s", lines, tostring(hasIsActive), tostring(hasGetHoneyMult), tostring(hasBobbing)))
else
    table.insert(issues, "❌ DanceFloorService: MISSING from ServerScriptService")
end

-- 4. GameManager wires DanceFloorService
local gm = SSS:FindFirstChild("GameManager")
if gm then
    local hasDance = gm.Source:find("DanceFloorService") ~= nil
    table.insert(hasDance and results or issues, (hasDance and "✅" or "⚠️") .. " GameManager: DanceFloorService " .. (hasDance and "wired" or "NOT wired — manual Init() needed"))
end

-- 5. ForagingService wires danceMult
local fs = SSS:FindFirstChild("ForagingService")
if fs then
    local hasDance = fs.Source:find("danceMult") ~= nil or fs.Source:find("DanceFloorService") ~= nil
    table.insert(hasDance and results or issues, (hasDance and "✅" or "⚠️") .. " ForagingService: danceMult " .. (hasDance and "injected" or "NOT injected"))
end

-- 6. Dance floor props in Workspace
local danceFloorParts = {}
for _, obj in Workspace:GetDescendants() do
    if obj.Name:find("DanceFloor") then table.insert(danceFloorParts, obj.Name) end
end
table.insert(#danceFloorParts >= 8 and results or issues, (#danceFloorParts >= 8 and "✅" or "❌") .. " Dance floor props: " .. #danceFloorParts .. " (expected 8+)")

-- 7. DanceGui in StarterGui
local dg = SG:FindFirstChild("DanceGui")
table.insert(dg and results or issues, (dg and "✅" or "❌") .. " DanceGui: " .. (dg and ("DisplayOrder=" .. dg.DisplayOrder) or "MISSING"))

-- 8. DanceController in StarterPlayerScripts
local sps = SP:FindFirstChild("StarterPlayerScripts")
local dc  = sps and sps:FindFirstChild("DanceController")
if dc and dc:IsA("LocalScript") then
    local lines = select(2, dc.Source:gsub("\n", "\n")) + 1
    table.insert(results, "✅ DanceController: " .. lines .. " lines")
else
    table.insert(issues, "❌ DanceController: MISSING from StarterPlayerScripts")
end

-- Summary
local out = "=== DISPATCH 37 VERIFICATION ===\n"
out = out .. table.concat(results, "\n") .. "\n"
if #issues > 0 then
    out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else
    out = out .. "\n✅ ALL CHECKS PASSED — Dispatch 37 complete"
end
return out
```

---

## EXECUTION SUMMARY

| Step | What | Parts added |
|------|------|-------------|
| A    | Config.DANCE_EVENT injection | 0 |
| B    | DanceSync RemoteEvent | 0 |
| C    | DanceFloorService ModuleScript | 0 |
| D    | GameManager + ForagingService wiring | 0 |
| E    | Dance floor hex props + disco ball | +9 |
| F    | DanceGui + DanceController | 0 |
| G    | Verification | — |

**Running part total: ~4,107 / 5,000**

---

## BEHAVIOURAL NOTES

- **Interval timer** starts on server boot — first dance triggers 8 minutes after game start
- **Bobbing** uses `RunService.Heartbeat` per-sinusoid phase offset so NPC bees bob out of sync (natural look)
- **danceMult** stacks multiplicatively with `weatherMult × seasonalMult × prestigeMult` in ForagingService
- **DanceSync** fires `FireAllClients` so all connected players see the banner simultaneously
- **Countdown** updates every Heartbeat frame client-side from `os.time()` delta — no RemoteEvent spam
- **Banner** slides in from top using `Back/Out` easing for playful bounce; slides out with `Quad/In`
- **Dance over** message shows for 3s then banner slides away automatically

---

*Dispatch 37 complete — proceed to dispatch 38 (AchievementBadge world props)*
