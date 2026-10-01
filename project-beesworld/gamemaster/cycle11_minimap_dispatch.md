# Dispatch 44 — MiniMapGui Hex-Grid Radar Overlay (Cycle 11)

**Feature:** A small hex-grid radar in the corner of the screen showing the player's
active plot — filled cells (honey colour), empty cells (dark), queen position (crown icon),
and forager bee dots. Updates every 2 seconds.

**Execution order:** After dispatch 43 (ThunderService).  
**Part budget impact:** 0 (pure UI — no world parts).  
**Running total:** ~4,142 / 5,000.

---

## STEP A — MiniMapGui ScreenGui

```lua
local StarterGui = game:GetService("StarterGui")

-- ── Root ScreenGui ──────────────────────────────────────────────
local mmGui                  = Instance.new("ScreenGui")
mmGui.Name                   = "MiniMapGui"
mmGui.DisplayOrder           = 12       -- above HiveGui (10), below notifications (30+)
mmGui.IgnoreGuiInset         = false
mmGui.ResetOnSpawn           = false
mmGui.Parent                 = StarterGui

-- ── Outer panel (bottom-right corner) ──────────────────────────
local panel                  = Instance.new("Frame")
panel.Name                   = "MiniMapPanel"
panel.Parent                 = mmGui
panel.Size                   = UDim2.new(0.18, 0, 0.22, 0)
panel.Position               = UDim2.new(0.81, 0, 0.77, 0)
panel.BackgroundColor3       = Color3.fromRGB(18, 10, 4)
panel.BackgroundTransparency = 0.10
panel.BorderSizePixel        = 0
panel.ZIndex                 = 10
local panelCorner            = Instance.new("UICorner")
panelCorner.CornerRadius     = UDim.new(0.06, 0)
panelCorner.Parent           = panel
local panelStroke            = Instance.new("UIStroke")
panelStroke.Color            = Color3.fromRGB(242, 168, 28)   -- Honey Gold
panelStroke.Thickness        = 2
panelStroke.Parent           = panel

-- ── Header label ────────────────────────────────────────────────
local header                 = Instance.new("TextLabel")
header.Name                  = "Header"
header.Parent                = panel
header.Size                  = UDim2.new(1, 0, 0.14, 0)
header.Position              = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency= 1
header.Text                  = "🗺  My Hive"
header.TextColor3            = Color3.fromRGB(242, 168, 28)
header.Font                  = Enum.Font.FredokaOne
header.TextScaled            = true
header.ZIndex                = 11

-- ── Cell count label ────────────────────────────────────────────
local cellCount              = Instance.new("TextLabel")
cellCount.Name               = "CellCount"
cellCount.Parent             = panel
cellCount.Size               = UDim2.new(1, 0, 0.10, 0)
cellCount.Position           = UDim2.new(0, 0, 0.88, 0)
cellCount.BackgroundTransparency = 1
cellCount.Text               = "0 cells"
cellCount.TextColor3         = Color3.fromRGB(232, 212, 154)  -- Wax Cream
cellCount.Font               = Enum.Font.FredokaOne
cellCount.TextScaled         = true
cellCount.ZIndex             = 11

-- ── Hex grid canvas ─────────────────────────────────────────────
local canvas                 = Instance.new("Frame")
canvas.Name                  = "HexCanvas"
canvas.Parent                = panel
canvas.Size                  = UDim2.new(0.92, 0, 0.72, 0)
canvas.Position              = UDim2.new(0.04, 0, 0.14, 0)
canvas.BackgroundTransparency= 1
canvas.ClipsDescendants      = true
canvas.ZIndex                = 11

print("MiniMapGui panel built — canvas ready for hex cells")
```

---

## STEP B — MiniMapController LocalScript

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "MiniMapController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- MiniMapController — renders the player's hex plot as a miniature grid overlay.
-- Polls the server every 2 seconds via GetPlotState RemoteFunction.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local localPlayer       = Players.LocalPlayer
local PlayerGui         = localPlayer:WaitForChild("PlayerGui")

-- Wait for UI
local MiniMapGui        = PlayerGui:WaitForChild("MiniMapGui", 15)
if not MiniMapGui then return end
local panel             = MiniMapGui:WaitForChild("MiniMapPanel", 5)
local canvas            = panel:WaitForChild("HexCanvas", 5)
local cellCountLabel    = panel:WaitForChild("CellCount", 5)

-- ── Remotes ──────────────────────────────────────────────────────
local Remotes           = ReplicatedStorage:WaitForChild("Remotes", 10)
local GetPlotState: RemoteFunction? = Remotes and Remotes:FindFirstChild("GetPlotState") :: RemoteFunction?

-- ── Hex grid constants (must match PlotService) ──────────────────
-- A Bee's World uses pointy-top hex grid
-- CELL_W = 13.856 studs, CELL_H = 12.0 studs (from architecture)
-- We scale these down to fit the canvas pixel space

-- Canvas is ~0.92×0.72 of the panel, which is ~0.18×0.22 of screen.
-- We render a 13-column × 11-row hex grid (same grid dims as max plot).
-- Each hex on the minimap is rendered as a small rotated square (diamond).

local GRID_COLS         = 13
local GRID_ROWS         = 11
local CELL_PX           = 0.07     -- fraction of canvas width per hex cell
local HEX_RATIO         = 0.866    -- width:height ratio for pointy hex (√3/2)

-- Colours
local COLOR_FILLED      = Color3.fromRGB(242, 168,  28)   -- Honey Gold — occupied
local COLOR_EMPTY       = Color3.fromRGB( 40,  25,  10)   -- dark — empty slot
local COLOR_QUEEN       = Color3.fromRGB(255, 215,   0)   -- bright gold — queen cell
local COLOR_FORAGER     = Color3.fromRGB(200, 240, 180)   -- pale green — forager bee
local COLOR_STROKE      = Color3.fromRGB( 80,  50,  20)   -- border between cells

-- ── Cell pool (reuse Frame objects) ─────────────────────────────
type CellData = {frame: Frame, icon: TextLabel}
local cellPool: {CellData} = {}
local _poolSize = 0

local function getCellFrame(): CellData
    _poolSize = _poolSize + 1
    if cellPool[_poolSize] then
        local c = cellPool[_poolSize]
        c.frame.Visible = true
        return c
    end
    local f             = Instance.new("Frame")
    f.Name              = "Cell_" .. _poolSize
    f.Parent            = canvas
    f.BackgroundColor3  = COLOR_EMPTY
    f.BorderSizePixel   = 0
    f.ZIndex            = 12
    local fc            = Instance.new("UICorner")
    fc.CornerRadius     = UDim.new(0.15, 0)
    fc.Parent           = f
    local fStroke       = Instance.new("UIStroke")
    fStroke.Color       = COLOR_STROKE
    fStroke.Thickness   = 1
    fStroke.Parent      = f

    local ico           = Instance.new("TextLabel")
    ico.Name            = "Icon"
    ico.Parent          = f
    ico.Size            = UDim2.new(1, 0, 1, 0)
    ico.BackgroundTransparency = 1
    ico.Text            = ""
    ico.TextScaled      = true
    ico.Font            = Enum.Font.FredokaOne
    ico.TextColor3      = Color3.fromRGB(255, 255, 255)
    ico.ZIndex          = 13

    local data: CellData = {frame = f, icon = ico}
    cellPool[_poolSize] = data
    return data
end

local function hideAllCells()
    for i = 1, #cellPool do
        cellPool[i].frame.Visible = false
        cellPool[i].icon.Text     = ""
    end
    _poolSize = 0
end

-- ── Hex offset → canvas UDim2 position ──────────────────────────
-- Pointy-top offset coordinates:
--   x pixel = col * cellW + (row % 2 == 1 and cellW/2 or 0)
--   y pixel = row * cellH * 0.75
local function hexToUDim2(col: number, row: number): (UDim2, UDim2)
    local cellW  = CELL_PX
    local cellH  = CELL_PX / HEX_RATIO
    local px     = (col - 1) * cellW + (row % 2 == 1 and cellW * 0.5 or 0)
    local py     = (row - 1) * cellH * 0.75
    return UDim2.new(px, 0, py, 0),
           UDim2.new(cellW * 0.90, 0, cellH * 0.90, 0)
end

-- ── Render ───────────────────────────────────────────────────────
local function render(plotData: {
    cells:     {{col: number, row: number, filled: boolean, isQueen: boolean}},
    foragers:  {{col: number, row: number}},
    cellCount: number,
})
    hideAllCells()

    -- Draw base grid (empty cells)
    for row = 1, GRID_ROWS do
        for col = 1, GRID_COLS do
            local pos, sz = hexToUDim2(col, row)
            local cell    = getCellFrame()
            cell.frame.Position        = pos
            cell.frame.Size            = sz
            cell.frame.BackgroundColor3 = COLOR_EMPTY
            cell.icon.Text             = ""
        end
    end

    -- Overlay filled cells
    for _, c in plotData.cells do
        if c.col >= 1 and c.col <= GRID_COLS and c.row >= 1 and c.row <= GRID_ROWS then
            -- Find the frame for this cell (by position match)
            local pos, _ = hexToUDim2(c.col, c.row)
            -- Locate from pool by position
            for i = 1, #cellPool do
                local f = cellPool[i].frame
                if f.Visible and math.abs(f.Position.X.Scale - pos.X.Scale) < 0.001
                            and math.abs(f.Position.Y.Scale - pos.Y.Scale) < 0.001 then
                    f.BackgroundColor3 = c.isQueen and COLOR_QUEEN or COLOR_FILLED
                    cellPool[i].icon.Text = c.isQueen and "👑" or ""
                    break
                end
            end
        end
    end

    -- Overlay forager bee dots
    for _, b in plotData.foragers do
        if b.col >= 1 and b.col <= GRID_COLS and b.row >= 1 and b.row <= GRID_ROWS then
            local pos, _ = hexToUDim2(b.col, b.row)
            for i = 1, #cellPool do
                local f = cellPool[i].frame
                if f.Visible and math.abs(f.Position.X.Scale - pos.X.Scale) < 0.001
                            and math.abs(f.Position.Y.Scale - pos.Y.Scale) < 0.001 then
                    cellPool[i].icon.Text = "🐝"
                    break
                end
            end
        end
    end

    -- Update cell count label
    if cellCountLabel then
        cellCountLabel.Text = plotData.cellCount .. " cell" .. (plotData.cellCount == 1 and "" or "s")
    end
end

-- ── Poll loop ────────────────────────────────────────────────────
local POLL_INTERVAL = 2   -- seconds between refreshes

task.spawn(function()
    while true do
        if GetPlotState then
            local ok, result = pcall(function()
                return GetPlotState:InvokeServer()
            end)
            if ok and result then
                render(result)
            end
        end
        task.wait(POLL_INTERVAL)
    end
end)
]]

print("MiniMapController LocalScript created")
```

---

## STEP C — GetPlotState RemoteFunction + PlotService handler

```lua
local SSS = game:GetService("ServerScriptService")
local RE  = game:GetService("ReplicatedStorage")

-- ── Ensure RemoteFunction exists ────────────────────────────────
local Remotes = RE:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = RE
end

local gps = Remotes:FindFirstChild("GetPlotState")
if not gps then
    gps = Instance.new("RemoteFunction")
    gps.Name = "GetPlotState"
    gps.Parent = Remotes
end
print("GetPlotState RemoteFunction ready")

-- ── Inject handler into PlotService ─────────────────────────────
local ps = SSS:FindFirstChild("PlotService")
assert(ps, "PlotService not found in SSS")
local clone = ps:Clone()
ps.Name = "PlotService_OLD_44C"
ps.Parent = nil

local src = clone.Source

-- Inject GetPlotState require near module top
src = src:gsub(
    "(local PlotService = %{%})",
    [[%1
local _GetPlotState: RemoteFunction?]]
)

-- Inject RF setup inside PlotService.Init()
-- Find the Init function closing area and inject before it returns
src = src:gsub(
    "(PlotService%.Init%s*=%s*function%(%s*%).-)(end%s*\n)",
    function(body, closing)
        local inject = [[
    -- GetPlotState handler (dispatch 44 — MiniMap)
    local _rem = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if _rem then
        _GetPlotState = _rem:FindFirstChild("GetPlotState") :: RemoteFunction?
        if _GetPlotState then
            _GetPlotState.OnServerInvoke = function(player: Player)
                return PlotService.GetMiniMapData(player)
            end
        end
    end
]] .. closing
        return body .. inject
    end
)

-- Inject GetMiniMapData function before return PlotService
src = src:gsub(
    "(return PlotService)",
    [[
-- ── MiniMap data builder (dispatch 44) ────────────────────────
function PlotService.GetMiniMapData(player: Player)
    local profile = require(script.Parent.DataService).GetProfile(player)
    if not profile then
        return { cells = {}, foragers = {}, cellCount = 0 }
    end

    local cells   : {{col: number, row: number, filled: boolean, isQueen: boolean}} = {}
    local foragers: {{col: number, row: number}} = {}
    local filled  = 0

    -- profile.hexCells is a list of {col, row} for placed cells
    -- profile.queenCell is {col, row} for the queen's home cell
    local queenKey = ""
    if profile.queenCell then
        queenKey = tostring(profile.queenCell.col) .. "," .. tostring(profile.queenCell.row)
    end

    if profile.hexCells then
        for _, cell in profile.hexCells do
            local isQ = (tostring(cell.col) .. "," .. tostring(cell.row)) == queenKey
            table.insert(cells, {
                col     = cell.col,
                row     = cell.row,
                filled  = true,
                isQueen = isQ,
            })
            filled = filled + 1
        end
    end

    -- Forager positions: look for ForagerBee models tagged to this player
    local CS = game:GetService("CollectionService")
    for _, bee in CS:GetTagged("ForagerBee") do
        if bee:GetAttribute("OwnerId") == player.UserId then
            local root = bee:FindFirstChild("HumanoidRootPart")
            if root then
                -- Convert world position to rough grid col/row
                -- Plot X offset: 6 plots at X = -250,-150,-50,+50,+150,+250
                -- CELL_W=13.856, CELL_H=12.0 (pointy-top)
                local Config = require(script.Parent.Config)
                local plotX = profile.plotX or 0
                local localX = root.Position.X - plotX
                local localZ = root.Position.Z
                local col = math.round(localX / Config.CELL_W) + 7   -- 7 = grid centre col
                local row = math.round(localZ / (Config.CELL_H * 0.75)) + 6
                table.insert(foragers, { col = col, row = row })
            end
        end
    end

    return { cells = cells, foragers = foragers, cellCount = filled }
end

%1]]
)

clone.Source = src
clone.Name = "PlotService"
clone.Parent = SSS
print("PlotService injected with GetMiniMapData")
```

---

## STEP D — Verification

```lua
local SSS    = game:GetService("ServerScriptService")
local SP     = game:GetService("StarterPlayer")
local SG     = game:GetService("StarterGui")
local RE     = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. MiniMapGui
local mm = SG:FindFirstChild("MiniMapGui")
if mm and mm:IsA("ScreenGui") then
    local panel = mm:FindFirstChild("MiniMapPanel")
    local canvas = panel and panel:FindFirstChild("HexCanvas")
    table.insert(results, "✅ MiniMapGui exists (DisplayOrder=" .. mm.DisplayOrder .. ")")
    if not panel  then table.insert(issues, "MISSING MiniMapPanel") end
    if not canvas then table.insert(issues, "MISSING HexCanvas in MiniMapPanel") end
else
    table.insert(issues, "❌ MiniMapGui NOT FOUND in StarterGui")
end

-- 2. MiniMapController LocalScript
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("MiniMapController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ MiniMapController: " .. lines .. " lines")
    if not ctrl.Source:find("--!strict")   then table.insert(issues, "MISSING --!strict") end
    if not ctrl.Source:find("GetPlotState") then table.insert(issues, "MISSING GetPlotState invoke") end
    if not ctrl.Source:find("render")       then table.insert(issues, "MISSING render function") end
else
    table.insert(issues, "❌ MiniMapController NOT FOUND in StarterPlayerScripts")
end

-- 3. GetPlotState RemoteFunction
local Remotes = RE:FindFirstChild("Remotes")
local gps = Remotes and Remotes:FindFirstChild("GetPlotState")
if gps and gps:IsA("RemoteFunction") then
    table.insert(results, "✅ GetPlotState RemoteFunction exists")
else
    table.insert(issues, "❌ GetPlotState RemoteFunction NOT FOUND in Remotes")
end

-- 4. PlotService has GetMiniMapData
local ps = SSS:FindFirstChild("PlotService")
if ps and ps.Source:find("GetMiniMapData") then
    table.insert(results, "✅ PlotService has GetMiniMapData")
else
    table.insert(issues, "⚠️ PlotService missing GetMiniMapData injection")
end

-- Summary
local out = "=== DISPATCH 44 VERIFICATION ===\n" .. table.concat(results, "\n") .. "\n"
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — dispatch 44 complete" end
print(out)
return out
```

---

## Summary

| Item | Created/Modified |
|---|---|
| MiniMapGui ScreenGui | DisplayOrder=12, bottom-right corner |
| MiniMapPanel | 18%×22%, dark bg, Honey Gold border, HexCanvas + Header + CellCount |
| MiniMapController | 2s poll, pooled Frame hex cells, pointy-top hex math, queen 👑 + forager 🐝 icons |
| GetPlotState RemoteFunction | client→server plot state query |
| PlotService injection | GetMiniMapData (hexCells→grid coords, ForagerBee world→grid conversion) |

**Part budget:** 0 → **~4,142 / 5,000**
