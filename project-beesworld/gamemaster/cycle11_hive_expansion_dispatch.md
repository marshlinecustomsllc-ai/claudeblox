# Dispatch 49 — HiveExpansionService (Unlock Additional Plot Slots)
**Cycle 11 | A Bee's World**

> Self-contained Studio execution guide.
> Execute every STEP in order in the Roblox Studio **Command Bar** (View → Command Bar).

---

## OVERVIEW

The base game places 6 plots at X = −250/−150/−50/+50/+150/+250.  
This dispatch adds a **7th and 8th plot slot** that players unlock by spending honey,
and a UI button inside the main panel that shows unlock status + cost.

Design constraints:
- New plots are identical in structure to existing ones (same hex grid, same services)
- Unlock is **permanent** — stored in DataService profile
- Server-authoritative: cost deducted server-side before plot is activated
- Part budget: +2 plots × ~12 parts each = **+24 permanent parts** (new total: **4,166/5,000**)
- Plots are physically present in the world from game start — they just have an invisible
  "locked overlay" part covering them. Unlock removes the overlay Part.

---

## DATA MODEL

New profile fields:

```
profile.unlockedPlots  {[number]: boolean}  default: {[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true}
```

Plots 1–6 are always unlocked. Plots 7 and 8 require honey spend.

---

## EXPANSION CONFIG

```lua
Config.EXPANSION = {
    plots = {
        -- existing 6 slots defined in Config.PLOTS already
        { id = 7, x = 350,  unlockCost = 25000 },
        { id = 8, x = -350, unlockCost = 50000 },
    },
    lockOverlayColor = Color3.fromRGB(50, 35, 15),
    lockOverlayTransparency = 0.35,
}
```

---

## STEP A — Config injection

Paste in Command Bar:

```lua
-- STEP A: inject EXPANSION table into Config
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local src = cfg.Source

if src:find("EXPANSION", 1, true) then
    print("Config already has EXPANSION — skip STEP A")
else
    -- Inject before the closing `return Config`
    local anchor = "return Config"
    assert(src:find(anchor, 1, true), "anchor 'return Config' not found")

    local injection = [[
Config.EXPANSION = {
    plots = {
        { id = 7, x =  350, unlockCost = 25000 },
        { id = 8, x = -350, unlockCost = 50000 },
    },
    lockOverlayColor        = Color3.fromRGB(50, 35, 15),
    lockOverlayTransparency = 0.35,
}

return Config]]

    local clone = cfg:Clone()
    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "Config"
    clone.Parent = SSS
    print("STEP A done — Config.EXPANSION injected")
end
```

### Verify STEP A
```lua
local src = game:GetService("ServerScriptService"):FindFirstChild("Config").Source
print(src:find("EXPANSION", 1, true) and "PASS" or "FAIL")
```

---

## STEP B — DataService migration

Paste in Command Bar:

```lua
-- STEP B: inject unlockedPlots into DataService profile defaults
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local src = ds.Source

if src:find("unlockedPlots", 1, true) then
    print("DataService already has unlockedPlots — skip STEP B")
else
    local anchor = "hasSeen_tutorial = false,"
    assert(src:find(anchor, 1, true), "anchor not found — check DataService source")

    local injection = [[
hasSeen_tutorial = false,
        unlockedPlots = {[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true},]]

    local clone = ds:Clone()
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "DataService"
    clone.Parent = SSS
    print("STEP B done — unlockedPlots injected into DataService")
end
```

### Verify STEP B
```lua
local src = game:GetService("ServerScriptService"):FindFirstChild("DataService").Source
print(src:find("unlockedPlots", 1, true) and "PASS" or "FAIL")
```

---

## STEP C — Build expansion plots in Workspace

Paste in Command Bar:

```lua
-- STEP C: place plot 7 (x=350) and plot 8 (x=-350) in Workspace.Map
-- Each plot: a floor Part + a LockOverlay Part + a Folder for hex cells
local Workspace = game:GetService("Workspace")
local map = Workspace:FindFirstChild("Map")
assert(map, "Workspace.Map not found — world-builder must run first")

-- Reference existing plot for sizing
local refPlot = map:FindFirstChild("Plot1") or map:FindFirstChild("Plot_1")
local FLOOR_SIZE = refPlot and (refPlot:FindFirstChildWhichIsA("BasePart") and
    refPlot:FindFirstChildWhichIsA("BasePart").Size) or Vector3.new(200, 2, 120)
local FLOOR_Y    = refPlot and (refPlot:FindFirstChildWhichIsA("BasePart") and
    refPlot:FindFirstChildWhichIsA("BasePart").Position.Y) or 1

local expansionData = {
    { id = 7, x =  350 },
    { id = 8, x = -350 },
}

for _, data in expansionData do
    local folderName = "Plot" .. data.id
    if map:FindFirstChild(folderName) then
        print("Plot " .. data.id .. " already exists — skip")
        continue
    end

    local folder = Instance.new("Folder")
    folder.Name   = folderName
    folder.Parent = map

    -- Floor part
    local floor = Instance.new("Part")
    floor.Name             = "Floor"
    floor.Size             = FLOOR_SIZE
    floor.Position         = Vector3.new(data.x, FLOOR_Y, 0)
    floor.Anchored         = true
    floor.BrickColor       = BrickColor.new("Sand yellow")
    floor.Material         = Enum.Material.SmoothPlastic
    floor.TopSurface       = Enum.SurfaceType.Smooth
    floor.BottomSurface    = Enum.SurfaceType.Smooth
    floor.CastShadow       = true
    floor.Parent           = folder

    -- Lock overlay (covers entire plot surface — removed on unlock)
    local overlay = Instance.new("Part")
    overlay.Name             = "LockOverlay"
    overlay.Size             = Vector3.new(FLOOR_SIZE.X, 0.5, FLOOR_SIZE.Z)
    overlay.Position         = Vector3.new(data.x, FLOOR_Y + FLOOR_SIZE.Y / 2 + 0.3, 0)
    overlay.Anchored         = true
    overlay.CanCollide       = false
    overlay.Color            = Color3.fromRGB(50, 35, 15)
    overlay.Transparency     = 0.35
    overlay.Material         = Enum.Material.Neon
    overlay.CastShadow       = false
    overlay.Parent           = folder

    -- Tag the overlay so HiveExpansionService can find it
    local tag = Instance.new("StringValue")
    tag.Name   = "PlotId"
    tag.Value  = tostring(data.id)
    tag.Parent = overlay

    -- BillboardGui "🔒 Locked" label floating above overlay
    local bb = Instance.new("BillboardGui")
    bb.Name           = "LockBadge"
    bb.Size           = UDim2.new(0, 180, 0, 50)
    bb.StudsOffset    = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop    = false
    bb.Adornee        = overlay
    bb.Parent         = overlay

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = "🔒 Locked"
    lbl.TextColor3           = Color3.fromRGB(242, 168, 28)
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextScaled           = true
    lbl.Parent               = bb

    -- HexCells folder placeholder
    local hexFolder = Instance.new("Folder")
    hexFolder.Name   = "HexCells"
    hexFolder.Parent = folder

    print("Created Plot " .. data.id .. " at X=" .. data.x)
end
```

### Verify STEP C
```lua
local map = game:GetService("Workspace"):FindFirstChild("Map")
for _, id in {7, 8} do
    local plot = map and map:FindFirstChild("Plot" .. id)
    local floor   = plot and plot:FindFirstChild("Floor")
    local overlay = plot and plot:FindFirstChild("LockOverlay")
    print(string.format("Plot%d: folder=%s floor=%s overlay=%s",
        id,
        tostring(plot ~= nil),
        tostring(floor ~= nil),
        tostring(overlay ~= nil)
    ))
end
```

---

## STEP D — HiveExpansionService ModuleScript

Paste in Command Bar:

```lua
-- STEP D: create HiveExpansionService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("HiveExpansionService"), "HiveExpansionService already exists — skip STEP D")

local m = Instance.new("ModuleScript")
m.Name   = "HiveExpansionService"
m.Parent = SSS
m.Source = [[
--!strict
local Players   = game:GetService("Players")
local RepStore  = game:GetService("ReplicatedStorage")
local SSS       = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local DataService = require(SSS:WaitForChild("DataService"))
local Config      = require(SSS:WaitForChild("Config"))

local HiveExpansionService = {}

local ExpansionSync:  RemoteEvent
local UnlockPlotRF:   RemoteFunction

-- Remove the LockOverlay from a plot folder
local function removeLockOverlay(plotId: number)
    local map = Workspace:FindFirstChild("Map")
    if not map then return end
    local folder = map:FindFirstChild("Plot" .. plotId)
    if not folder then return end
    local overlay = folder:FindFirstChild("LockOverlay")
    if overlay then overlay:Destroy() end
end

-- Send current unlock state to a single client
local function syncClient(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local slots = {}
    for _, ep in Config.EXPANSION.plots do
        slots[ep.id] = {
            unlocked = profile.unlockedPlots and profile.unlockedPlots[ep.id] == true,
            cost     = ep.unlockCost,
        }
    end
    ExpansionSync:FireClient(player, slots)
end

function HiveExpansionService.Init()
    ExpansionSync = RepStore:WaitForChild("ExpansionSync") :: RemoteEvent
    UnlockPlotRF  = RepStore:WaitForChild("UnlockPlotRF")  :: RemoteFunction

    -- On server start: remove overlays for already-unlocked expansion plots
    -- (handles server restart with data already saved)
    Players.PlayerAdded:Connect(function(player: Player)
        task.delay(4, function()
            if not player.Parent then return end
            local profile = DataService.GetProfile(player)
            if not profile then return end
            if profile.unlockedPlots then
                for _, ep in Config.EXPANSION.plots do
                    if profile.unlockedPlots[ep.id] then
                        removeLockOverlay(ep.id)
                    end
                end
            end
            syncClient(player)
        end)
    end)

    UnlockPlotRF.OnServerInvoke = function(player: Player, plotId: number): (boolean, string)
        if typeof(plotId) ~= "number" then return false, "invalid" end

        -- Find expansion config for this plot
        local epConfig = nil
        for _, ep in Config.EXPANSION.plots do
            if ep.id == plotId then epConfig = ep break end
        end
        if not epConfig then return false, "unknown plot" end

        local profile = DataService.GetProfile(player)
        if not profile then return false, "profile unavailable" end

        -- Already unlocked?
        if profile.unlockedPlots and profile.unlockedPlots[plotId] then
            return true, "already unlocked"
        end

        -- Sufficient honey?
        local current = profile.honey or 0
        if current < epConfig.unlockCost then
            return false, "not enough honey"
        end

        -- Deduct and unlock
        profile.honey = current - epConfig.unlockCost
        if not profile.unlockedPlots then
            profile.unlockedPlots = {[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true}
        end
        profile.unlockedPlots[plotId] = true

        -- Remove overlay from world
        removeLockOverlay(plotId)

        -- Broadcast updated state to all clients (so other players see the overlay gone)
        for _, p in Players:GetPlayers() do
            syncClient(p)
        end

        return true, "unlocked"
    end

    print("[HiveExpansionService] initialised")
end

return HiveExpansionService
]]

print("STEP D done — HiveExpansionService created")
```

### Verify STEP D
```lua
local m = game:GetService("ServerScriptService"):FindFirstChild("HiveExpansionService")
print(m and "PASS" or "FAIL")
```

---

## STEP E — RemoteEvent + RemoteFunction

Paste in Command Bar:

```lua
-- STEP E: create ExpansionSync RE and UnlockPlotRF RF in ReplicatedStorage
local Rep = game:GetService("ReplicatedStorage")

if not Rep:FindFirstChild("ExpansionSync") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "ExpansionSync"
    re.Parent = Rep
    print("ExpansionSync created")
else print("ExpansionSync exists") end

if not Rep:FindFirstChild("UnlockPlotRF") then
    local rf = Instance.new("RemoteFunction")
    rf.Name   = "UnlockPlotRF"
    rf.Parent = Rep
    print("UnlockPlotRF created")
else print("UnlockPlotRF exists") end
```

---

## STEP F — GameManager injection

Paste in Command Bar:

```lua
-- STEP F: inject HiveExpansionService.Init() into GameManager after TutorialService.Init()
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local src = gm.Source

if src:find("HiveExpansionService", 1, true) then
    print("GameManager already has HiveExpansionService — skip STEP F")
else
    local anchor = "TutorialService.Init()"
    assert(src:find(anchor, 1, true), "anchor 'TutorialService.Init()' not found")

    local injection = [[
TutorialService.Init()
    local HiveExpansionService = require(ServerScriptService:WaitForChild("HiveExpansionService"))
    HiveExpansionService.Init()]]

    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("STEP F done — HiveExpansionService.Init() injected")
end
```

---

## STEP G — ExpansionController LocalScript

Paste in Command Bar:

```lua
-- STEP G: create ExpansionController in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")
assert(not SPS:FindFirstChild("ExpansionController"), "ExpansionController exists — skip STEP G")

local ls = Instance.new("LocalScript")
ls.Name   = "ExpansionController"
ls.Parent = SPS
ls.Source = [[
--!strict
-- ExpansionController: unlock UI for expansion plot slots
local Players      = game:GetService("Players")
local RepStore     = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local ExpansionSync = RepStore:WaitForChild("ExpansionSync") :: RemoteEvent
local UnlockPlotRF  = RepStore:WaitForChild("UnlockPlotRF")  :: RemoteFunction

-- ── CONFIG ────────────────────────────────────────────────────────────────────
local EXPANSION_PLOTS = {
    { id = 7, label = "Plot 7",  cost = 25000 },
    { id = 8, label = "Plot 8",  cost = 50000 },
}

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local DARK_BG     = Color3.fromRGB(30, 20, 10)
local LOCKED_CLR  = Color3.fromRGB(100, 70, 30)
local UNLOCKED_CLR = Color3.fromRGB(40, 80, 40)

-- ── FIND MAIN GUI ─────────────────────────────────────────────────────────────
-- Expansion panel sits inside MainGui → MainFrame (same parent as StatsTabBtn)
local MainGui   = PlayerGui:WaitForChild("MainGui",   15)
local MainFrame = MainGui and MainGui:WaitForChild("MainFrame", 10)
assert(MainFrame, "MainFrame not found")

-- ── BUILD EXPAND PANEL BUTTON ─────────────────────────────────────────────────
local expandTabBtn = Instance.new("TextButton")
expandTabBtn.Name             = "ExpandTabBtn"
expandTabBtn.AnchorPoint      = Vector2.new(0, 0)
expandTabBtn.Position         = UDim2.new(0.01, 0, 0.50, 0)   -- left side, below other tabs
expandTabBtn.Size             = UDim2.new(0.10, 0, 0.08, 0)
expandTabBtn.BackgroundColor3 = DARK_BG
expandTabBtn.BorderSizePixel  = 0
expandTabBtn.Text             = "🗺️"
expandTabBtn.TextScaled       = true
expandTabBtn.Font             = Enum.Font.GothamBold
expandTabBtn.TextColor3       = HONEY_GOLD
expandTabBtn.ZIndex           = 10
expandTabBtn.Parent           = MainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent       = expandTabBtn

-- ── BUILD EXPAND PANEL ────────────────────────────────────────────────────────
local expandPanel = Instance.new("Frame")
expandPanel.Name             = "ExpandPanel"
expandPanel.AnchorPoint      = Vector2.new(1, 0.5)
expandPanel.Position         = UDim2.new(1.01, 0, 0.50, 0)   -- starts off-screen right
expandPanel.Size             = UDim2.new(0.30, 0, 0.50, 0)
expandPanel.BackgroundColor3 = DARK_BG
expandPanel.BorderSizePixel  = 0
expandPanel.ZIndex           = 15
expandPanel.Visible          = true
expandPanel.Parent           = MainFrame

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent       = expandPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD
panelStroke.Thickness = 2
panelStroke.Parent    = expandPanel

-- Panel title
local panelTitle = Instance.new("TextLabel")
panelTitle.Name                 = "Title"
panelTitle.AnchorPoint          = Vector2.new(0.5, 0)
panelTitle.Position             = UDim2.new(0.5, 0, 0, 10)
panelTitle.Size                 = UDim2.new(0.90, 0, 0, 28)
panelTitle.BackgroundTransparency = 1
panelTitle.Text                 = "Expand Hive"
panelTitle.TextScaled           = true
panelTitle.Font                 = Enum.Font.GothamBold
panelTitle.TextColor3           = HONEY_GOLD
panelTitle.ZIndex               = 16
panelTitle.Parent               = expandPanel

-- Build slot rows
local slotFrames: {[number]: {frame: Frame, statusLbl: TextLabel, btn: TextButton}} = {}
for i, ep in EXPANSION_PLOTS do
    local yOffset = 50 + (i - 1) * 90

    local slotFrame = Instance.new("Frame")
    slotFrame.Name             = "Slot_" .. ep.id
    slotFrame.AnchorPoint      = Vector2.new(0.5, 0)
    slotFrame.Position         = UDim2.new(0.5, 0, 0, yOffset)
    slotFrame.Size             = UDim2.new(0.88, 0, 0, 80)
    slotFrame.BackgroundColor3 = Color3.fromRGB(45, 30, 15)
    slotFrame.BorderSizePixel  = 0
    slotFrame.ZIndex           = 16
    slotFrame.Parent           = expandPanel

    local slotCorner = Instance.new("UICorner")
    slotCorner.CornerRadius = UDim.new(0, 10)
    slotCorner.Parent       = slotFrame

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Name                 = "Name"
    nameLbl.Position             = UDim2.new(0.05, 0, 0.05, 0)
    nameLbl.Size                 = UDim2.new(0.90, 0, 0.35, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                 = ep.label
    nameLbl.TextScaled           = true
    nameLbl.Font                 = Enum.Font.GothamBold
    nameLbl.TextColor3           = Color3.fromRGB(232, 212, 154)
    nameLbl.TextXAlignment       = Enum.TextXAlignment.Left
    nameLbl.ZIndex               = 17
    nameLbl.Parent               = slotFrame

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Name               = "Status"
    statusLbl.Position           = UDim2.new(0.05, 0, 0.40, 0)
    statusLbl.Size               = UDim2.new(0.90, 0, 0.28, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text               = "🔒 25,000 🍯"
    statusLbl.TextScaled         = true
    statusLbl.Font               = Enum.Font.Gotham
    statusLbl.TextColor3         = Color3.fromRGB(200, 150, 60)
    statusLbl.TextXAlignment     = Enum.TextXAlignment.Left
    statusLbl.ZIndex             = 17
    statusLbl.Parent             = slotFrame

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Name             = "UnlockBtn"
    unlockBtn.AnchorPoint      = Vector2.new(1, 1)
    unlockBtn.Position         = UDim2.new(0.97, 0, 0.95, 0)
    unlockBtn.Size             = UDim2.new(0.42, 0, 0.30, 0)
    unlockBtn.BackgroundColor3 = LOCKED_CLR
    unlockBtn.BorderSizePixel  = 0
    unlockBtn.Text             = "Unlock"
    unlockBtn.TextScaled       = true
    unlockBtn.Font             = Enum.Font.GothamBold
    unlockBtn.TextColor3       = Color3.new(1, 1, 1)
    unlockBtn.ZIndex           = 17
    unlockBtn.Parent           = slotFrame

    local btnCorner2 = Instance.new("UICorner")
    btnCorner2.CornerRadius = UDim.new(0, 8)
    btnCorner2.Parent       = unlockBtn

    slotFrames[ep.id] = { frame = slotFrame, statusLbl = statusLbl, btn = unlockBtn }

    -- Wire unlock button
    local capturedId = ep.id
    local capturedCost = ep.cost
    unlockBtn.Activated:Connect(function()
        unlockBtn.Text = "..."
        unlockBtn.Active = false
        local ok, msg = UnlockPlotRF:InvokeServer(capturedId)
        if ok then
            unlockBtn.Text             = "✓ Owned"
            unlockBtn.BackgroundColor3 = UNLOCKED_CLR
            statusLbl.Text             = "✓ Unlocked"
            statusLbl.TextColor3       = Color3.fromRGB(100, 220, 100)
        else
            unlockBtn.Text   = msg or "Failed"
            task.delay(2, function()
                unlockBtn.Text   = "Unlock"
                unlockBtn.Active = true
            end)
        end
    end)
end

-- ── ANIMATION HELPERS ─────────────────────────────────────────────────────────
local panelOpen = false

local function openPanel()
    panelOpen = true
    local ti = TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(expandPanel, ti, {
        Position = UDim2.new(0.69, 0, 0.50, 0)
    }):Play()
end

local function closePanel()
    panelOpen = false
    local ti = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    TweenService:Create(expandPanel, ti, {
        Position = UDim2.new(1.01, 0, 0.50, 0)
    }):Play()
end

expandTabBtn.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)

-- ── SYNC HANDLER ─────────────────────────────────────────────────────────────
local function fmtNum(n: number): string
    if n >= 1000000 then return string.format("%.1fM", n/1000000) end
    if n >= 1000 then return string.format("%.1fK", n/1000) end
    return tostring(n)
end

ExpansionSync.OnClientEvent:Connect(function(slots: {[number]: {unlocked: boolean, cost: number}})
    for _, ep in EXPANSION_PLOTS do
        local sf = slotFrames[ep.id]
        if not sf then continue end
        local data = slots[ep.id]
        if not data then continue end

        if data.unlocked then
            sf.statusLbl.Text      = "✓ Unlocked"
            sf.statusLbl.TextColor3 = Color3.fromRGB(100, 220, 100)
            sf.btn.Text            = "✓ Owned"
            sf.btn.BackgroundColor3 = UNLOCKED_CLR
            sf.btn.Active          = false
        else
            sf.statusLbl.Text      = "🔒 " .. fmtNum(data.cost) .. " 🍯"
            sf.statusLbl.TextColor3 = Color3.fromRGB(200, 150, 60)
            sf.btn.Text            = "Unlock"
            sf.btn.BackgroundColor3 = LOCKED_CLR
            sf.btn.Active          = true
        end
    end
end)
]]

print("STEP G done — ExpansionController created")
```

### Verify STEP G
```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ls  = SPS and SPS:FindFirstChild("ExpansionController")
print(ls and "PASS" or "FAIL")
```

---

## STEP H — Full verification

Paste in Command Bar:

```lua
-- STEP H: full verification
local SSS = game:GetService("ServerScriptService")
local Rep = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local map = game:GetService("Workspace"):FindFirstChild("Map")

local checks = {
    {"Config.EXPANSION",
        SSS:FindFirstChild("Config") and
        SSS:FindFirstChild("Config").Source:find("EXPANSION", 1, true) ~= nil},
    {"DataService.unlockedPlots",
        SSS:FindFirstChild("DataService") and
        SSS:FindFirstChild("DataService").Source:find("unlockedPlots", 1, true) ~= nil},
    {"Plot7 in Workspace.Map",
        map and map:FindFirstChild("Plot7") ~= nil},
    {"Plot8 in Workspace.Map",
        map and map:FindFirstChild("Plot8") ~= nil},
    {"Plot7 LockOverlay",
        map and map:FindFirstChild("Plot7") and
        map:FindFirstChild("Plot7"):FindFirstChild("LockOverlay") ~= nil},
    {"Plot8 LockOverlay",
        map and map:FindFirstChild("Plot8") and
        map:FindFirstChild("Plot8"):FindFirstChild("LockOverlay") ~= nil},
    {"HiveExpansionService",
        SSS:FindFirstChild("HiveExpansionService") ~= nil},
    {"ExpansionSync RemoteEvent",
        Rep:FindFirstChild("ExpansionSync") ~= nil},
    {"UnlockPlotRF RemoteFunction",
        Rep:FindFirstChild("UnlockPlotRF") ~= nil},
    {"GameManager has HiveExpansionService",
        SSS:FindFirstChild("GameManager") and
        SSS:FindFirstChild("GameManager").Source:find("HiveExpansionService", 1, true) ~= nil},
    {"ExpansionController LocalScript",
        SPS and SPS:FindFirstChild("ExpansionController") ~= nil},
}

local pass, fail = 0, 0
for _, c in checks do
    local label, result = c[1], c[2]
    if result then
        print("  PASS: " .. label)
        pass = pass + 1
    else
        warn("  FAIL: " .. label)
        fail = fail + 1
    end
end
print(string.format("\n%d/%d checks passed — %s",
    pass, #checks, fail == 0 and "DISPATCH 49 COMPLETE ✓" or "NEEDS ATTENTION"))
```

---

## EXPECTED OUTPUT

```
  PASS: Config.EXPANSION
  PASS: DataService.unlockedPlots
  PASS: Plot7 in Workspace.Map
  PASS: Plot8 in Workspace.Map
  PASS: Plot7 LockOverlay
  PASS: Plot8 LockOverlay
  PASS: HiveExpansionService
  PASS: ExpansionSync RemoteEvent
  PASS: UnlockPlotRF RemoteFunction
  PASS: GameManager has HiveExpansionService
  PASS: ExpansionController LocalScript

11/11 checks passed — DISPATCH 49 COMPLETE ✓
```

---

## PART BUDGET

| Change | Parts |
|---|---|
| Plot 7 (Floor + LockOverlay) | +2 |
| Plot 8 (Floor + LockOverlay) | +2 |
| BillboardGui frames (runtime GUI, not BasePart) | 0 |
| **New total** | **4,146 / 5,000** |

*(BillboardGui objects are not BaseParts — they do not count against the workspace part budget.)*

---

## BEHAVIOUR NOTES

- **LockOverlay visibility**: Neon material with 35% transparency — players can see through it to the floor below, but a soft amber glow makes it obvious the plot is locked.
- **Unlock is permanent**: once the RemoteFunction returns `true`, `profile.unlockedPlots[plotId] = true` is saved by DataService automatically on next autosave cycle.
- **Overlay removal on server restart**: `HiveExpansionService.Init()` checks all expansion plots on `PlayerAdded` — if a player already unlocked Plot 7, `removeLockOverlay(7)` fires again and gracefully no-ops if the overlay is already gone (FindFirstChild returns nil, Destroy is not called).
- **Other players see unlock instantly**: `UnlockPlotRF.OnServerInvoke` calls `syncClient` for every connected player — all clients update their panel and the world overlay is gone for everyone simultaneously.
- **PlotService compatibility**: plots 7 and 8 use the same `HexCells` folder structure as plots 1–6. PlotService can reference them by `Plot7`/`Plot8` name in `map:GetChildren()` iteration — no additional PlotService changes needed.

---

*Dispatch 49 complete — execute Steps A → H in order. Proceed to Dispatch 50 after 11/11 checks pass.*
