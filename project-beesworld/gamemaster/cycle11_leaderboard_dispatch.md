# CYCLE 11 — LEADERBOARD DISPATCH (DISPATCH 24)
## LeaderboardService + Global Cork Board + Plot Plaques

> **SUPERSEDES cycle6_leaderboard_dispatch.md** — that dispatch adds a
> `profile.lifetimeHoney` increment hook to ResourceService that was already
> added by dispatch 22 (cycle11_cosmetics_dispatch.md). Executing the old
> dispatch would double-count lifetimeHoney. It also has a stale prerequisite
> note referencing v5→v6 migration.
> Do NOT also execute cycle6_leaderboard_dispatch.md.

**Prerequisites:** Dispatches 1–23 executed in order. DataService at v15.
`profile.lifetimeHoney` already exists AND is already incremented in ResourceService
(both done by dispatch 22, cycle11_cosmetics_dispatch.md).
`profile.generation` exists from dispatch 21 (cycle11_swarm_dispatch.md v12→v13).  
**No DataService migration** — all required fields already exist.  
**Part budget impact:** +24 parts (6 cork board parts + 3 plaque parts × 6 plots) → ~4,076/5,000

---

## OVERVIEW

Two leaderboard surfaces:

1. **Global Top-10 Board** — large cork board on the Apiary Hub back wall. OrderedDataStore,
   top 10 by lifetime honey, updates every 60 seconds. SurfaceGui shows ranked list with
   gold/silver/bronze Honey Gold coloring for top 3.

2. **Plot Personal Bests** — small cork plaque on each plot's fence post (left side of deck
   entrance). Shows the owning player's generation count + lifetime honey. Client-side only,
   read from HudDataSync on spawn.

---

## EXECUTION ORDER

```
STEP A  Config.LEADERBOARD
STEP B  LeaderboardUpdate RemoteEvent
STEP C  LeaderboardService ModuleScript (RecordHoney hook into ResourceService already exists — skip)
STEP D  LeaderboardRunner Script
STEP E  LeaderboardController LocalScript
STEP F  PlotPlaqueController LocalScript + HudDataSync payload extension
STEP G  World: Global Cork Board in Hub (6 parts)
STEP H  World: Plot Plaques x6 (3 parts each = 18 parts)
STEP I  Verification
```

> **IMPORTANT — What is NOT in this dispatch:**
> ResourceService `profile.lifetimeHoney` increment — already added by dispatch 22.
> Do not add it again. LeaderboardService.RecordHoney is called from a new hook
> added to ResourceService in STEP C (not the lifetimeHoney line itself).

---

## STEP A — Config.LEADERBOARD

Add to Config ModuleScript (clone-replace pattern):

```lua
Config.LEADERBOARD = {
    STORE_NAME       = "GlobalHoney_v1",  -- OrderedDataStore key
    UPDATE_INTERVAL  = 60,               -- seconds between refreshes
    TOP_N            = 10,               -- entries to fetch
}
```

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local oldCfg = RS.Modules.Config
local newCfg = oldCfg:Clone()
newCfg.Name = "Config_new"
newCfg.Parent = RS.Modules

local src = oldCfg.Source
local insertPoint = src:find("\nreturn Config")
if insertPoint then
    local addition = [[

Config.LEADERBOARD = {
    STORE_NAME      = "GlobalHoney_v1",
    UPDATE_INTERVAL = 60,
    TOP_N           = 10,
}
]]
    newCfg.Source = src:sub(1, insertPoint - 1) .. addition .. "\nreturn Config"
else
    warn("Config: could not find 'return Config' insertion point")
    newCfg.Source = src
end
newCfg.Name = "Config"
oldCfg.Name = "Config_old"
oldCfg.Parent = nil
print("Config.LEADERBOARD added")
```

Verify: `print(require(game:GetService("ReplicatedStorage").Modules.Config).LEADERBOARD.TOP_N)` → `10`

---

## STEP B — LeaderboardUpdate RemoteEvent

```lua
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not remotes:FindFirstChild("LeaderboardUpdate") then
    local e = Instance.new("RemoteEvent")
    e.Name = "LeaderboardUpdate"
    e.Parent = remotes
    print("LeaderboardUpdate RemoteEvent created")
else
    print("LeaderboardUpdate already exists")
end
```

---

## STEP C — LeaderboardService ModuleScript + ResourceService hook

**Location:** `ServerScriptService.Systems.LeaderboardService`  
**Type:** ModuleScript  
**Strict:** `--!strict`

```lua
--!strict
local DataStoreService    = game:GetService("DataStoreService")
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local Config  = require(ReplicatedStorage.Modules.Config)
local LB_CFG  = Config.LEADERBOARD

local LeaderboardService = {}

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local LeaderboardUpdate: RemoteEvent = Remotes:WaitForChild("LeaderboardUpdate")

local orderedStore: OrderedDataStore? = nil
pcall(function()
    orderedStore = DataStoreService:GetOrderedDataStore(LB_CFG.STORE_NAME)
end)

function LeaderboardService.RecordHoney(player: Player, lifetimeHoney: number): ()
    if not orderedStore then return end
    local userId = player.UserId
    task.spawn(function()
        pcall(function()
            (orderedStore :: OrderedDataStore):SetAsync(tostring(userId), math.floor(lifetimeHoney))
        end)
    end)
end

local function refreshBoard(): ()
    if not orderedStore then return end
    local ok, pages = pcall(function()
        return (orderedStore :: OrderedDataStore):GetSortedAsync(false, LB_CFG.TOP_N)
    end)
    if not ok or not pages then return end
    local ok2, currentPage = pcall(function()
        return (pages :: DataStorePages):GetCurrentPage()
    end)
    if not ok2 or not currentPage then return end

    local entries: {{rank: number, name: string, score: number}} = {}
    for rank, entry in currentPage :: {{key: string, value: number}} do
        local userId    = tonumber(entry.key) :: number
        local dispName  = "Beekeeper"
        pcall(function()
            dispName = Players:GetNameFromUserIdAsync(userId)
        end)
        table.insert(entries, {rank = rank, name = dispName, score = entry.value})
    end
    LeaderboardUpdate:FireAllClients(entries)
end

function LeaderboardService.Start(): ()
    task.spawn(function()
        while true do
            refreshBoard()
            task.wait(LB_CFG.UPDATE_INTERVAL)
        end
    end)
end

return LeaderboardService
```

Create with:

```lua
local SSS = game:GetService("ServerScriptService")
local systems = SSS:FindFirstChild("Systems") or (function()
    local f = Instance.new("Folder"); f.Name = "Systems"; f.Parent = SSS; return f
end)()
local lbMod = Instance.new("ModuleScript")
lbMod.Name = "LeaderboardService"
lbMod.Parent = systems
lbMod.Source = [[ ... paste full source above ... ]]
print("LeaderboardService created at", lbMod:GetFullName())
```

**ResourceService hook (add LeaderboardService.RecordHoney call):**

In `ServerScriptService.Systems.ResourceService`, find the credit-honey function (the one that
increments `profile.honey` AND `profile.lifetimeHoney`). After the `profile.lifetimeHoney`
increment line (already there from dispatch 22), add one line:

```lua
LeaderboardService.RecordHoney(player, profile.lifetimeHoney)
```

Also add at the top of ResourceService (with other requires):

```lua
local LeaderboardService = require(ServerScriptService.Systems.LeaderboardService)
```

Use clone-replace pattern for ResourceService since it is a ModuleScript.

---

## STEP D — LeaderboardRunner Script

```lua
local SSS = game:GetService("ServerScriptService")
local runner = Instance.new("Script")
runner.Name = "LeaderboardRunner"
runner.Parent = SSS
runner.Source = [[--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local LeaderboardService = require(ServerScriptService.Systems.LeaderboardService)
LeaderboardService.Start()
]]
print("LeaderboardRunner created")
```

---

## STEP E — LeaderboardController LocalScript

**Location:** `StarterPlayerScripts.LeaderboardController`  
**Type:** LocalScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local LeaderboardUpdate: RemoteEvent = Remotes:WaitForChild("LeaderboardUpdate")

local COLOR_GOLD    = Color3.fromRGB(242, 168, 28)
local COLOR_SILVER  = Color3.fromRGB(192, 192, 192)
local COLOR_BRONZE  = Color3.fromRGB(205, 127, 50)
local COLOR_DEFAULT = Color3.fromRGB(232, 212, 154)

local function getBoard(): SurfaceGui?
    for _, part in CollectionService:GetTagged("LeaderboardBoard") do
        local sg = part:FindFirstChild("LeaderboardGui")
        if sg and sg:IsA("SurfaceGui") then return sg :: SurfaceGui end
    end
    return nil
end

local function formatScore(n: number): string
    local s = tostring(math.floor(n))
    local result = ""
    local len = #s
    for i = 1, len do
        if i > 1 and (len - i + 1) % 3 == 0 then result = result .. "," end
        result = result .. s:sub(i, i)
    end
    return result
end

LeaderboardUpdate.OnClientEvent:Connect(function(entries: {{rank: number, name: string, score: number}})
    local board = getBoard()
    if not board then return end
    local listFrame = board:FindFirstChild("ListFrame") :: Frame?
    if not listFrame then return end

    for i = 1, 10 do
        local row = listFrame:FindFirstChild("Row" .. i) :: TextLabel?
        if not row then
            local r = Instance.new("TextLabel")
            r.Name                   = "Row" .. i
            r.Size                   = UDim2.new(1, 0, 0.09, 0)
            r.Position               = UDim2.new(0, 0, 0.08 + (i - 1) * 0.09, 0)
            r.BackgroundTransparency = 1
            r.Font                   = Enum.Font.GothamBold
            r.TextScaled             = true
            r.TextXAlignment         = Enum.TextXAlignment.Left
            r.Parent                 = listFrame
            row = r
        end
        local label = row :: TextLabel
        local entry = entries[i]
        if entry then
            local prefix = (i == 1 and "1. " or (i == 2 and "2. " or (i == 3 and "3. " or i .. ". ")))
            label.Text = prefix .. entry.name .. "  " .. formatScore(entry.score) .. " honey"
            if i == 1 then label.TextColor3 = COLOR_GOLD
            elseif i == 2 then label.TextColor3 = COLOR_SILVER
            elseif i == 3 then label.TextColor3 = COLOR_BRONZE
            else label.TextColor3 = COLOR_DEFAULT end
        else
            label.Text       = i .. ".  —"
            label.TextColor3 = Color3.fromRGB(120, 90, 60)
        end
    end

    -- "You" row at the bottom if local player is on the board
    local localPlayer = Players.LocalPlayer
    local myRow = listFrame:FindFirstChild("MyRow") :: TextLabel?
    for _, entry in entries do
        if entry.name == localPlayer.Name then
            if not myRow then
                local mr = Instance.new("TextLabel")
                mr.Name                   = "MyRow"
                mr.Size                   = UDim2.new(1, 0, 0.07, 0)
                mr.Position               = UDim2.new(0, 0, 0.93, 0)
                mr.BackgroundTransparency = 0.4
                mr.BackgroundColor3       = Color3.fromRGB(122, 74, 34)
                mr.Font                   = Enum.Font.GothamBold
                mr.TextScaled             = true
                mr.TextColor3             = COLOR_GOLD
                mr.TextXAlignment         = Enum.TextXAlignment.Center
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 4)
                corner.Parent = mr
                mr.Parent = listFrame
                myRow = mr
            end
            (myRow :: TextLabel).Text = "You: #" .. entry.rank .. "  " .. formatScore(entry.score) .. " honey"
            break
        end
    end
end)
```

Create:

```lua
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local lbc = Instance.new("LocalScript")
lbc.Name = "LeaderboardController"
lbc.Parent = SPS
lbc.Source = [[ ... paste full source above ... ]]
print("LeaderboardController created")
```

---

## STEP F — PlotPlaqueController + HudDataSync payload extension

### PlotPlaqueController LocalScript

**Location:** `StarterPlayerScripts.PlotPlaqueController`  
**Type:** LocalScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
-- HudDataSync fires profile summary to owning client on load + updates
local HudDataSync: RemoteEvent = Remotes:WaitForChild("HudDataSync")

local localPlayer = Players.LocalPlayer

local function updatePlaque(plotIndex: number, generation: number, lifetimeHoney: number): ()
    for _, part in CollectionService:GetTagged("PlotPlaque") do
        if part:GetAttribute("PlotIndex") == plotIndex then
            local sg = part:FindFirstChild("PlaqueGui")
            if sg and sg:IsA("SurfaceGui") then
                local label = sg:FindFirstChild("PlaqueText") :: TextLabel?
                if label then
                    local kHoney = math.floor(lifetimeHoney / 1000)
                    label.Text = "Gen " .. generation .. "\n" .. kHoney .. "k lifetime"
                end
            end
        end
    end
end

HudDataSync.OnClientEvent:Connect(function(data: {plotIndex: number?, generation: number?, lifetimeHoney: number?})
    if data.plotIndex and data.generation and data.lifetimeHoney then
        updatePlaque(data.plotIndex, data.generation, data.lifetimeHoney)
    end
end)
```

Create:

```lua
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local ppc = Instance.new("LocalScript")
ppc.Name = "PlotPlaqueController"
ppc.Parent = SPS
ppc.Source = [[ ... paste full source above ... ]]
print("PlotPlaqueController created")
```

### HudDataSync RemoteEvent + payload extension

Check if HudDataSync already exists; create if not:

```lua
local remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not remotes:FindFirstChild("HudDataSync") then
    local e = Instance.new("RemoteEvent")
    e.Name = "HudDataSync"
    e.Parent = remotes
    print("HudDataSync created")
else
    print("HudDataSync already exists")
end
```

Find where profile data is broadcast to the owning player's client (typically in HivePlotController
or DataService.PlayerAdded, wherever the wallet data is first sent). Extend that payload to include:

```lua
generation    = profile.generation    or 0,
lifetimeHoney = profile.lifetimeHoney or 0,
plotIndex     = plotData.plotIndex,   -- already present in most firing locations
```

If HudDataSync is not fired anywhere, add a fire in the PlayerAdded handler of DataService
(or a separate script) after the 3-second profile load wait:

```lua
task.delay(4, function()
    local profile = DataService.GetProfile(player)
    if profile then
        HudDataSync:FireClient(player, {
            plotIndex     = DataService.GetPlotIndex(player) or 0,
            generation    = profile.generation    or 0,
            lifetimeHoney = profile.lifetimeHoney or 0,
        })
    end
end)
```

---

## STEP G — World: Global Cork Board

Build in `Workspace.Hub.LeaderboardBoard` folder (create if missing).

```lua
local workspace   = game:GetService("Workspace")
local hub         = workspace:FindFirstChild("Hub") or (function()
    local f = Instance.new("Folder"); f.Name = "Hub"; f.Parent = workspace; return f
end)()
local boardFolder = hub:FindFirstChild("LeaderboardBoard") or (function()
    local f = Instance.new("Folder"); f.Name = "LeaderboardBoard"; f.Parent = hub; return f
end)()
local CS = game:GetService("CollectionService")

-- Hub back wall: Z ≈ -260, facing +Z, centered at X=0, Y=12
local parts = {
    {name="BoardBacking",  pos=Vector3.new(0,12,-259),    size=Vector3.new(80,22,1),  color=Color3.fromRGB(139,115,85), mat=Enum.Material.Wood,          cc=true},
    {name="BoardFrame_L",  pos=Vector3.new(-41,12,-259.5),size=Vector3.new(2,24,2),   color=Color3.fromRGB(101,67,33),  mat=Enum.Material.Wood,          cc=true},
    {name="BoardFrame_R",  pos=Vector3.new(41,12,-259.5), size=Vector3.new(2,24,2),   color=Color3.fromRGB(101,67,33),  mat=Enum.Material.Wood,          cc=true},
    {name="BoardFrame_T",  pos=Vector3.new(0,23.5,-259.5),size=Vector3.new(84,2,2),   color=Color3.fromRGB(101,67,33),  mat=Enum.Material.Wood,          cc=true},
    {name="BoardFrame_B",  pos=Vector3.new(0,0.5,-259.5), size=Vector3.new(84,2,2),   color=Color3.fromRGB(101,67,33),  mat=Enum.Material.Wood,          cc=true},
    {name="BoardSurface",  pos=Vector3.new(0,12,-258.5),  size=Vector3.new(78,20,0.2),color=Color3.fromRGB(139,115,85), mat=Enum.Material.SmoothPlastic, cc=false, isBoard=true},
}

for _, pd in parts do
    local p = Instance.new("Part")
    p.Name          = pd.name
    p.Size          = pd.size
    p.Position      = pd.pos
    p.Anchored      = true
    p.CanCollide    = pd.cc
    p.Material      = pd.mat
    p.Color         = pd.color
    p.CastShadow    = false
    p.Parent        = boardFolder

    if pd.isBoard then
        CS:AddTag(p, "LeaderboardBoard")
        local sg = Instance.new("SurfaceGui")
        sg.Name          = "LeaderboardGui"
        sg.Face          = Enum.NormalId.Front
        sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
        sg.PixelsPerStud = 50
        sg.Parent        = p

        local listFrame = Instance.new("Frame")
        listFrame.Name                   = "ListFrame"
        listFrame.Size                   = UDim2.new(1,0,1,0)
        listFrame.BackgroundTransparency = 1
        listFrame.Parent                 = sg

        local header = Instance.new("TextLabel")
        header.Name                   = "Header"
        header.Size                   = UDim2.new(1,0,0.08,0)
        header.Position               = UDim2.new(0,0,0,0)
        header.BackgroundTransparency = 1
        header.Text                   = "TOP BEEKEEPERS"
        header.Font                   = Enum.Font.GothamBold
        header.TextScaled             = true
        header.TextColor3             = Color3.fromRGB(242,168,28)
        header.Parent                 = listFrame
    end
end
print("LeaderboardBoard built: " .. #boardFolder:GetChildren() .. " parts")
```

---

## STEP H — World: Plot Plaques x6

```lua
local workspace = game:GetService("Workspace")
local CS        = game:GetService("CollectionService")

local PLOT_X = {-250, -150, -50, 50, 150, 250}
-- Plaque position: left fence post of each plot's deck entrance
-- Local offset from plot centre: X=-23, Y=9.5, Z=-80 (absolute)
local PLAQUE_Z  = -80
local PLAQUE_Y  = 9.5
local X_OFFSET  = -23   -- left of center

for plotIndex = 1, 6 do
    local plotX  = PLOT_X[plotIndex]
    local absX   = plotX + X_OFFSET

    -- Find or create PlotDecor folder
    local plotFolder = workspace:FindFirstChild("Plot" .. plotIndex)
    if not plotFolder then
        warn("Plot" .. plotIndex .. " folder not found in Workspace -- skipping plaque " .. plotIndex)
        continue
    end
    local decor = plotFolder:FindFirstChild("PlotDecor") or (function()
        local f = Instance.new("Folder")
        f.Name   = "PlotDecor"
        f.Parent = plotFolder
        return f
    end)()

    -- 3-part plaque
    local backing = Instance.new("Part")
    backing.Name     = "PlaqueBacking"
    backing.Size     = Vector3.new(14, 6, 0.8)
    backing.CFrame   = CFrame.new(absX, PLAQUE_Y, PLAQUE_Z)
    backing.Anchored = true
    backing.CanCollide = true
    backing.Material = Enum.Material.Wood
    backing.Color    = Color3.fromRGB(139, 115, 85)
    backing.Parent   = decor

    local frame = Instance.new("Part")
    frame.Name     = "PlaqueFrame"
    frame.Size     = Vector3.new(15, 7, 0.4)
    frame.CFrame   = CFrame.new(absX, PLAQUE_Y, PLAQUE_Z + 0.5)
    frame.Anchored = true
    frame.CanCollide = true
    frame.Material = Enum.Material.Wood
    frame.Color    = Color3.fromRGB(101, 67, 33)
    frame.Parent   = decor

    local surface = Instance.new("Part")
    surface.Name       = "PlaqueSurface" .. plotIndex
    surface.Size       = Vector3.new(13, 5, 0.2)
    surface.CFrame     = CFrame.new(absX, PLAQUE_Y, PLAQUE_Z - 0.3)
    surface.Anchored   = true
    surface.CanCollide = false
    surface.Material   = Enum.Material.SmoothPlastic
    surface.Color      = Color3.fromRGB(139, 115, 85)
    surface.Parent     = decor

    CS:AddTag(surface, "PlotPlaque")
    surface:SetAttribute("PlotIndex", plotIndex)

    local sg = Instance.new("SurfaceGui")
    sg.Name          = "PlaqueGui"
    sg.Face          = Enum.NormalId.Front
    sg.SizingMode    = Enum.SurfaceGuiSizingMode.PixelsPerStud
    sg.PixelsPerStud = 40
    sg.Parent        = surface

    local label = Instance.new("TextLabel")
    label.Name                   = "PlaqueText"
    label.Size                   = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text                   = "Gen 1\n-- lifetime --"
    label.Font                   = Enum.Font.GothamBold
    label.TextScaled             = true
    label.TextColor3             = Color3.fromRGB(242, 168, 28)
    label.Parent                 = sg
end
print("Plot plaques built (6 plots)")
```

---

## STEP I — Verification

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local CS  = game:GetService("CollectionService")
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
local results = {}
local issues  = {}

-- Config
local ok, cfg = pcall(require, RS.Modules.Config)
if ok and cfg.LEADERBOARD then
    table.insert(results, "Config.LEADERBOARD: TOP_N=" .. cfg.LEADERBOARD.TOP_N)
else
    table.insert(issues, "MISSING Config.LEADERBOARD")
end

-- RemoteEvents
local remotes = RS:FindFirstChild("Remotes")
for _, name in {"LeaderboardUpdate", "HudDataSync"} do
    local e = remotes and remotes:FindFirstChild(name)
    table.insert(results, name .. ": " .. (e and e.ClassName or "MISSING"))
    if not e then table.insert(issues, "MISSING RemoteEvent: " .. name) end
end

-- Server scripts
for _, pair in {{"Systems/LeaderboardService","ModuleScript"},{"LeaderboardRunner","Script"}} do
    local path, cls = table.unpack(pair)
    local parts2 = path:split("/")
    local obj = SSS
    for _, p in parts2 do obj = obj:FindFirstChild(p) if not obj then break end end
    table.insert(results, path .. ": " .. (obj and obj.ClassName or "MISSING"))
    if not obj or obj.ClassName ~= cls then table.insert(issues, "WRONG/MISSING: " .. path .. " (need " .. cls .. ")") end
end

-- Client scripts
for _, name in {"LeaderboardController", "PlotPlaqueController"} do
    local s = SPS:FindFirstChild(name)
    table.insert(results, name .. ": " .. (s and s.ClassName or "MISSING"))
    if not s then table.insert(issues, "MISSING LocalScript: " .. name) end
end

-- World: LeaderboardBoard tag
local boardParts = CS:GetTagged("LeaderboardBoard")
table.insert(results, "LeaderboardBoard tagged parts: " .. #boardParts)
if #boardParts == 0 then table.insert(issues, "MISSING: no part tagged LeaderboardBoard") end
if #boardParts > 0 then
    local sg = boardParts[1]:FindFirstChild("LeaderboardGui")
    table.insert(results, "LeaderboardGui SurfaceGui: " .. (sg and "present" or "MISSING"))
    if not sg then table.insert(issues, "MISSING LeaderboardGui on BoardSurface") end
end

-- World: PlotPlaque tags
local plaqueParts = CS:GetTagged("PlotPlaque")
table.insert(results, "PlotPlaque tagged parts: " .. #plaqueParts .. " (expected 6)")
if #plaqueParts ~= 6 then table.insert(issues, "WRONG count: PlotPlaque tagged parts = " .. #plaqueParts .. ", expected 6") end
for _, part in plaqueParts do
    local idx = part:GetAttribute("PlotIndex")
    local sg  = part:FindFirstChild("PlaqueGui")
    if not idx then table.insert(issues, "MISSING PlotIndex attribute on " .. part.Name) end
    if not sg  then table.insert(issues, "MISSING PlaqueGui on " .. part.Name) end
end

-- LeaderboardService source sanity
local lbMod = SSS.Systems and SSS.Systems:FindFirstChild("LeaderboardService")
if lbMod then
    local src = lbMod.Source
    local checks = {
        {"--!strict", "--!strict"},
        {"RecordHoney", "RecordHoney function"},
        {"GetSortedAsync", "GetSortedAsync (OrderedDataStore read)"},
        {"FireAllClients", "FireAllClients"},
    }
    for _, pair in checks do
        if not src:find(pair[1]) then
            table.insert(issues, "MISSING in LeaderboardService: " .. pair[2])
        end
    end
end

local out = table.concat(results, "\n")
if #issues > 0 then
    out = out .. "\n\nISSUES (" .. #issues .. "):\n" .. table.concat(issues, "\n")
else
    out = out .. "\n\nALL CHECKS PASSED"
end
print(out)
```

Expected when all steps complete:

```
Config.LEADERBOARD: TOP_N=10
LeaderboardUpdate: RemoteEvent
HudDataSync: RemoteEvent
Systems/LeaderboardService: ModuleScript
LeaderboardRunner: Script
LeaderboardController: LocalScript
PlotPlaqueController: LocalScript
LeaderboardBoard tagged parts: 1
LeaderboardGui SurfaceGui: present
PlotPlaque tagged parts: 6

ALL CHECKS PASSED
```

---

## PART BUDGET

**+24 parts** (6 cork board + 18 plaque parts across 6 plots) → **~4,076/5,000**

The cork board is placed in Workspace.Hub.LeaderboardBoard. The 6 plaques are distributed
across Workspace.Plot[1-6].PlotDecor — no single folder takes a large hit.
