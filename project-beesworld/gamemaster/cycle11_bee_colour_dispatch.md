# Dispatch 40 — BeeColourCustomizer: 12-Preset Palette + Randomise
**Cycle 11 | A Bee's World | Bee-scale tycoon**
**Execution order: after dispatch 39**

---

## OVERVIEW

Expands the existing WardrobeGui with a dedicated "Colour" sub-tab inside TabWardrobe.
Players choose from 12 preset bee body colours plus a Randomise button.
Selected colour persists in `profile.beeBodyColor` (new DataService field).
`BeeColorSync` RemoteEvent pushes the selection server→all clients so other players see the change.
Colour swatches animate with a TweenService scale pulse on selection.
No new world parts — entirely UI + one new profile field.

**Part budget**: 0 permanent → **~4,142 / 5,000**

---

## COLOUR PALETTE (12 presets)

| # | Name | Color3 RGB |
|---|------|------------|
| 1 | Honey Gold | 242, 168, 28 |
| 2 | Propolis Brown | 122, 74, 34 |
| 3 | Wax Cream | 232, 212, 154 |
| 4 | Royal Purple | 120, 60, 180 |
| 5 | Cobalt Blue | 50, 100, 220 |
| 6 | Emerald Green | 40, 160, 80 |
| 7 | Coral Pink | 240, 100, 110 |
| 8 | Midnight Black | 30, 20, 20 |
| 9 | Arctic White | 240, 240, 250 |
| 10 | Rust Orange | 210, 90, 30 |
| 11 | Slate Grey | 130, 130, 140 |
| 12 | Lavender | 180, 150, 220 |

---

## STEP A — Config.BEE_COLOURS injection + DataService migration

```lua
-- In Studio Command Bar:
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- ---- Config.BEE_COLOURS ----
local cfg = RS:FindFirstChild("Config")
if not cfg then error("Config not found") end
local cfgClone = cfg:Clone()
cfg.Name = "Config_OLD_NX"
cfg.Parent = nil

local cfgSrc = cfgClone.Source
local inject = [[

-- ============================================================
-- BEE COLOUR PALETTE
-- ============================================================
Config.BEE_COLOURS = {
    { name = "Honey Gold",      color = Color3.fromRGB(242, 168,  28) },
    { name = "Propolis Brown",  color = Color3.fromRGB(122,  74,  34) },
    { name = "Wax Cream",       color = Color3.fromRGB(232, 212, 154) },
    { name = "Royal Purple",    color = Color3.fromRGB(120,  60, 180) },
    { name = "Cobalt Blue",     color = Color3.fromRGB( 50, 100, 220) },
    { name = "Emerald Green",   color = Color3.fromRGB( 40, 160,  80) },
    { name = "Coral Pink",      color = Color3.fromRGB(240, 100, 110) },
    { name = "Midnight Black",  color = Color3.fromRGB( 30,  20,  20) },
    { name = "Arctic White",    color = Color3.fromRGB(240, 240, 250) },
    { name = "Rust Orange",     color = Color3.fromRGB(210,  90,  30) },
    { name = "Slate Grey",      color = Color3.fromRGB(130, 130, 140) },
    { name = "Lavender",        color = Color3.fromRGB(180, 150, 220) },
}
Config.BEE_DEFAULT_COLOUR = 1  -- index into BEE_COLOURS (Honey Gold)
]]
cfgSrc = cfgSrc:gsub("(return Config)", inject .. "\n%1")
cfgClone.Source = cfgSrc
cfgClone.Name = "Config"
cfgClone.Parent = RS
print("✅ Config.BEE_COLOURS injected (12 entries)")

-- ---- DataService: add beeBodyColor field ----
local ds = SSS:FindFirstChild("DataService")
if not ds then error("DataService not found") end
local dsClone = ds:Clone()
ds.Name = "DataService_OLD_NX"
ds.Parent = nil

local dsSrc = dsClone.Source
if not dsSrc:find("beeBodyColor") then
    dsSrc = dsSrc:gsub(
        "(achievements.-\n)",
        "%1\t\tbeeBodyColor   = 1,  -- index into Config.BEE_COLOURS\n"
    )
    print("✅ DataService: beeBodyColor field added to DEFAULT_PROFILE")
else
    print("ℹ️  DataService: beeBodyColor already present")
end
dsClone.Source = dsSrc
dsClone.Name = "DataService"
dsClone.Parent = SSS
```

---

## STEP B — BeeColorSync RemoteEvent + BeeColorService (server)

```lua
-- In Studio Command Bar (run after Step A):
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- RemoteEvent
local remotes = RS:FindFirstChild("Remotes")
if not remotes then error("Remotes not found") end
if not remotes:FindFirstChild("BeeColorSync") then
    local re = Instance.new("RemoteEvent")
    re.Name = "BeeColorSync"
    re.Parent = remotes
    print("✅ BeeColorSync RemoteEvent created")
end

-- RemoteFunction for client→server colour change
if not remotes:FindFirstChild("SetBeeColor") then
    local rf = Instance.new("RemoteFunction")
    rf.Name = "SetBeeColor"
    rf.Parent = remotes
    print("✅ SetBeeColor RemoteFunction created")
end

-- BeeColorService ModuleScript
local old = SSS:FindFirstChild("BeeColorService")
if old then old:Destroy() end

local s = Instance.new("ModuleScript")
s.Name = "BeeColorService"
s.Source = [[
--!strict
local RS          = game:GetService("ReplicatedStorage")
local Players     = game:GetService("Players")
local SSS         = game:GetService("ServerScriptService")

local Config      = require(RS:WaitForChild("Config"))
local DataService = require(SSS:WaitForChild("DataService"))
local BeeColorSync = RS:WaitForChild("Remotes"):WaitForChild("BeeColorSync")
local SetBeeColor  = RS:WaitForChild("Remotes"):WaitForChild("SetBeeColor")

type ColourDef = { name: string, color: Color3 }

local BeeColorService = {}

function BeeColorService.GetColor(player: Player): Color3
    local ok, profile = pcall(DataService.GetProfile, player)
    if not ok or not profile then
        return (Config.BEE_COLOURS :: { ColourDef })[1].color
    end
    local idx = math.clamp(profile.beeBodyColor or 1, 1, #(Config.BEE_COLOURS :: { ColourDef }))
    return (Config.BEE_COLOURS :: { ColourDef })[idx].color
end

local function applyColorToCharacter(character: Model, color: Color3)
    -- Apply to all BaseParts in character that are bee body parts
    -- (avoids tools, accessories, etc.)
    local bodyParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
    for _, name in bodyParts do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            part.Color = color
        end
    end
end

function BeeColorService.Init()
    -- Handle SetBeeColor requests from clients
    SetBeeColor.OnServerInvoke = function(player: Player, colorIndex: number): boolean
        if type(colorIndex) ~= "number" then return false end
        local maxIdx = #(Config.BEE_COLOURS :: { ColourDef })
        colorIndex = math.clamp(math.floor(colorIndex), 1, maxIdx)

        local ok, profile = pcall(DataService.GetProfile, player)
        if not ok or not profile then return false end

        profile.beeBodyColor = colorIndex
        local newColor = (Config.BEE_COLOURS :: { ColourDef })[colorIndex].color

        -- Apply to current character immediately
        local char = player.Character
        if char then
            applyColorToCharacter(char, newColor)
        end

        -- Broadcast to all clients so others see the change
        BeeColorSync:FireAllClients({
            userId     = player.UserId,
            colorIndex = colorIndex,
            color      = newColor,
        })

        return true
    end

    -- Apply stored colour when character spawns
    Players.PlayerAdded:Connect(function(player: Player)
        player.CharacterAdded:Connect(function(character: Model)
            task.wait(0.5)  -- let character load
            local ok, profile = pcall(DataService.GetProfile, player)
            if not ok or not profile then return end
            local idx = math.clamp(profile.beeBodyColor or 1, 1, #(Config.BEE_COLOURS :: { ColourDef }))
            applyColorToCharacter(character, (Config.BEE_COLOURS :: { ColourDef })[idx].color)
            -- Sync this player's colour to all clients
            BeeColorSync:FireAllClients({
                userId     = player.UserId,
                colorIndex = idx,
                color      = (Config.BEE_COLOURS :: { ColourDef })[idx].color,
            })
        end)
    end)
end

return BeeColorService
]]
s.Parent = SSS
print("✅ BeeColorService ModuleScript created in ServerScriptService")
```

---

## STEP C — Wire BeeColorService into GameManager

```lua
-- In Studio Command Bar (run after Step B):
local SSS = game:GetService("ServerScriptService")

local gm = SSS:FindFirstChild("GameManager")
if not gm then error("GameManager not found") end
local clone = gm:Clone()
gm.Name = "GameManager_OLD_NX"
gm.Parent = nil

local src = clone.Source
if not src:find("BeeColorService") then
    src = src:gsub(
        "(local AchievementService.-\n)",
        "%1local BeeColorService = require(SSS:WaitForChild(\"BeeColorService\"))\n"
    )
    src = src:gsub(
        "(AchievementService%.Init%(%)\n)",
        "%1BeeColorService.Init()\n"
    )
    print("✅ GameManager: BeeColorService require+Init injected")
else
    print("ℹ️  GameManager: BeeColorService already wired")
end
clone.Source = src
clone.Name = "GameManager"
clone.Parent = SSS
```

---

## STEP D — Colour tab UI inside WardrobeGui

```lua
-- In Studio Command Bar (run after Step C):
local StarterGui = game:GetService("StarterGui")

local hiveGui   = StarterGui:FindFirstChild("HiveGui")
if not hiveGui then error("HiveGui not found") end
local mainFrame = hiveGui:FindFirstChild("MainFrame")
if not mainFrame then error("MainFrame not found") end

-- Find or create WardrobePanel
local wardrobePanel = mainFrame:FindFirstChild("WardrobePanel")
if not wardrobePanel then
    -- Minimal frame if WardrobePanel doesn't exist yet
    wardrobePanel = Instance.new("Frame")
    wardrobePanel.Name = "WardrobePanel"
    wardrobePanel.Size = UDim2.new(0.9, 0, 0.75, 0)
    wardrobePanel.Position = UDim2.new(0.05, 0, 0.12, 0)
    wardrobePanel.BackgroundColor3 = Color3.fromRGB(50, 25, 5)
    wardrobePanel.BackgroundTransparency = 0.05
    wardrobePanel.BorderSizePixel = 0
    wardrobePanel.Visible = false
    wardrobePanel.Parent = mainFrame
    print("ℹ️  WardrobePanel created (did not exist)")
end

-- Remove old colour section if re-running
local oldSection = wardrobePanel:FindFirstChild("ColourSection")
if oldSection then oldSection:Destroy() end

local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local PROPOLIS   = Color3.fromRGB(122,  74, 34)
local WAX_CREAM  = Color3.fromRGB(232, 212, 154)

-- ColourSection header
local colHeader = Instance.new("TextLabel")
colHeader.Name              = "ColourSectionHeader"
colHeader.Size              = UDim2.new(0.90, 0, 0.07, 0)
colHeader.Position          = UDim2.new(0.05, 0, 0.05, 0)
colHeader.BackgroundTransparency = 1
colHeader.Text              = "🎨 Bee Body Colour"
colHeader.Font              = Enum.Font.FredokaOne
colHeader.TextScaled        = true
colHeader.TextColor3        = HONEY_GOLD
colHeader.ZIndex            = 10
colHeader.Parent            = wardrobePanel

-- Colour swatch grid (4×3 grid of buttons)
local COLOURS = {
    { name = "Honey Gold",     r = 242, g = 168, b =  28 },
    { name = "Propolis Brown", r = 122, g =  74, b =  34 },
    { name = "Wax Cream",      r = 232, g = 212, b = 154 },
    { name = "Royal Purple",   r = 120, g =  60, b = 180 },
    { name = "Cobalt Blue",    r =  50, g = 100, b = 220 },
    { name = "Emerald Green",  r =  40, g = 160, b =  80 },
    { name = "Coral Pink",     r = 240, g = 100, b = 110 },
    { name = "Midnight Black", r =  30, g =  20, b =  20 },
    { name = "Arctic White",   r = 240, g = 240, b = 250 },
    { name = "Rust Orange",    r = 210, g =  90, b =  30 },
    { name = "Slate Grey",     r = 130, g = 130, b = 140 },
    { name = "Lavender",       r = 180, g = 150, b = 220 },
}

local COLS = 4
local SWATCH_W = 0.20
local SWATCH_H = 0.16
local GAP_X    = 0.02
local GAP_Y    = 0.02
local START_X  = 0.04
local START_Y  = 0.14

for i, col in COLOURS do
    local row = math.floor((i - 1) / COLS)
    local colIdx = (i - 1) % COLS
    local xPos = START_X + colIdx * (SWATCH_W + GAP_X)
    local yPos = START_Y + row * (SWATCH_H + GAP_Y)

    local btn = Instance.new("TextButton")
    btn.Name              = "Swatch_" .. i
    btn.Size              = UDim2.new(SWATCH_W, 0, SWATCH_H, 0)
    btn.Position          = UDim2.new(xPos, 0, yPos, 0)
    btn.BackgroundColor3  = Color3.fromRGB(col.r, col.g, col.b)
    btn.BackgroundTransparency = 0
    btn.BorderSizePixel   = 0
    btn.Text              = ""
    btn.ZIndex            = 11

    -- Attribute for controller lookup
    btn:SetAttribute("ColorIndex", i)
    btn:SetAttribute("ColorName",  col.name)

    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 6)
    sc.Parent = btn

    -- Selection ring (hidden by default)
    local ring = Instance.new("UIStroke")
    ring.Name      = "SelectionRing"
    ring.Color     = HONEY_GOLD
    ring.Thickness = 3
    ring.Enabled   = false  -- enabled on selection
    ring.Parent    = btn

    -- Tooltip label inside swatch (tiny)
    local tip = Instance.new("TextLabel")
    tip.Size              = UDim2.new(1, 0, 0.35, 0)
    tip.Position          = UDim2.new(0, 0, 0.65, 0)
    tip.BackgroundTransparency = 0.5
    tip.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    tip.Text              = col.name
    tip.Font              = Enum.Font.FredokaOne
    tip.TextScaled        = true
    tip.TextColor3        = Color3.fromRGB(255, 255, 255)
    tip.ZIndex            = 12
    tip.Visible           = false  -- shown on hover via controller
    tip.Parent            = btn

    local tipCorner = Instance.new("UICorner")
    tipCorner.CornerRadius = UDim.new(0, 4)
    tipCorner.Parent = tip

    btn.Parent = wardrobePanel
end

-- Randomise button
local randBtn = Instance.new("TextButton")
randBtn.Name              = "RandomiseBtn"
randBtn.Size              = UDim2.new(0.42, 0, 0.09, 0)
randBtn.Position          = UDim2.new(0.29, 0, 0.86, 0)
randBtn.BackgroundColor3  = PROPOLIS
randBtn.BackgroundTransparency = 0.1
randBtn.BorderSizePixel   = 0
randBtn.Text              = "🎲 Randomise"
randBtn.Font              = Enum.Font.FredokaOne
randBtn.TextScaled        = true
randBtn.TextColor3        = WAX_CREAM
randBtn.ZIndex            = 11
randBtn.Parent            = wardrobePanel

local randCorner = Instance.new("UICorner")
randCorner.CornerRadius = UDim.new(0, 8)
randCorner.Parent = randBtn

local randStroke = Instance.new("UIStroke")
randStroke.Color     = HONEY_GOLD
randStroke.Thickness = 1.5
randStroke.Parent    = randBtn

-- Selected colour preview label
local previewLbl = Instance.new("TextLabel")
previewLbl.Name              = "SelectedColourLabel"
previewLbl.Size              = UDim2.new(0.90, 0, 0.07, 0)
previewLbl.Position          = UDim2.new(0.05, 0, 0.78, 0)
previewLbl.BackgroundTransparency = 1
previewLbl.Text              = "Selected: Honey Gold"
previewLbl.Font              = Enum.Font.FredokaOne
previewLbl.TextScaled        = true
previewLbl.TextColor3        = WAX_CREAM
previewLbl.ZIndex            = 11
previewLbl.Parent            = wardrobePanel

print("✅ ColourSection: 12 swatches + Randomise + preview label added to WardrobePanel")
```

---

## STEP E — BeeColourController LocalScript

```lua
-- In Studio Command Bar (run after Step D):
local StarterPlayer = game:GetService("StarterPlayer")
local SPS = StarterPlayer:FindFirstChild("StarterPlayerScripts")
if not SPS then error("StarterPlayerScripts not found") end

local old = SPS:FindFirstChild("BeeColourController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name = "BeeColourController"
ctrl.Source = [[
--!strict
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")

local player    = Players.LocalPlayer
local pgui      = player:WaitForChild("PlayerGui")

local SetBeeColor  = RS:WaitForChild("Remotes"):WaitForChild("SetBeeColor") :: RemoteFunction
local BeeColorSync = RS:WaitForChild("Remotes"):WaitForChild("BeeColorSync") :: RemoteEvent

-- Wait for UI
local hiveGui      = pgui:WaitForChild("HiveGui") :: ScreenGui
local mainFrame    = hiveGui:WaitForChild("MainFrame") :: Frame
local wardrobePanel = mainFrame:WaitForChild("WardrobePanel") :: Frame
local previewLbl   = wardrobePanel:WaitForChild("SelectedColourLabel") :: TextLabel
local randBtn      = wardrobePanel:WaitForChild("RandomiseBtn") :: TextButton

local HONEY_GOLD   = Color3.fromRGB(242, 168,  28)
local WAX_CREAM    = Color3.fromRGB(232, 212, 154)
local PULSE_IN     = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PULSE_OUT    = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local _selectedIndex: number = 1

local function getSwatches(): { TextButton }
    local swatches: { TextButton } = {}
    for _, child in wardrobePanel:GetChildren() do
        if child:IsA("TextButton") and child.Name:find("^Swatch_") then
            table.insert(swatches, child :: TextButton)
        end
    end
    return swatches
end

local function getColourName(index: number): string
    local swatches = getSwatches()
    for _, swatch in swatches do
        if swatch:GetAttribute("ColorIndex") == index then
            return swatch:GetAttribute("ColorName") or "Colour " .. index
        end
    end
    return "Colour " .. index
end

local function setSelectedVisual(newIndex: number)
    _selectedIndex = newIndex
    local name = getColourName(newIndex)
    previewLbl.Text = "Selected: " .. name

    for _, swatch in getSwatches() do
        local ring = swatch:FindFirstChild("SelectionRing") :: UIStroke?
        local idx  = swatch:GetAttribute("ColorIndex")
        if ring then
            ring.Enabled = (idx == newIndex)
        end
    end
end

local function pulseSwatch(swatch: TextButton)
    TweenService:Create(swatch, PULSE_IN,  { Size = UDim2.new(0.23, 0, 0.19, 0) }):Play()
    task.delay(0.12, function()
        TweenService:Create(swatch, PULSE_OUT, { Size = UDim2.new(0.20, 0, 0.16, 0) }):Play()
    end)
end

local function selectColour(index: number)
    setSelectedVisual(index)
    task.spawn(function()
        local success = SetBeeColor:InvokeServer(index)
        if not success then
            warn("[BeeColourController] Server rejected colour index", index)
        end
    end)
end

-- Wire all swatch buttons
for _, swatch in getSwatches() do
    local idx = swatch:GetAttribute("ColorIndex") :: number
    swatch.Activated:Connect(function()
        pulseSwatch(swatch)
        selectColour(idx)
    end)
    -- Tooltip on hover (desktop)
    swatch.MouseEnter:Connect(function()
        local tip = swatch:FindFirstChildOfClass("TextLabel")
        if tip then tip.Visible = true end
    end)
    swatch.MouseLeave:Connect(function()
        local tip = swatch:FindFirstChildOfClass("TextLabel")
        if tip then tip.Visible = false end
    end)
end

-- Randomise button
randBtn.Activated:Connect(function()
    local rand = math.random(1, 12)
    for _, swatch in getSwatches() do
        if swatch:GetAttribute("ColorIndex") == rand then
            pulseSwatch(swatch)
        end
    end
    selectColour(rand)
end)

-- Apply other players' colour changes to their visible characters
BeeColorSync.OnClientEvent:Connect(function(data: { userId: number, colorIndex: number, color: Color3 })
    if data.userId == player.UserId then
        -- Update our own selection ring
        setSelectedVisual(data.colorIndex)
        return
    end
    -- Find other player's character and recolour
    for _, p in Players:GetPlayers() do
        if p.UserId == data.userId and p.Character then
            local bodyParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}
            for _, name in bodyParts do
                local part = p.Character:FindFirstChild(name)
                if part and part:IsA("BasePart") then
                    part.Color = data.color
                end
            end
            break
        end
    end
end)

print("[BeeColourController] ready")
]]
ctrl.Parent = SPS
print("✅ BeeColourController LocalScript created in StarterPlayerScripts")
```

---

## STEP F — Verification

```lua
-- In Studio Command Bar:
local RS     = game:GetService("ReplicatedStorage")
local SSS    = game:GetService("ServerScriptService")
local SG     = game:GetService("StarterGui")
local SP     = game:GetService("StarterPlayer")

local results = {}
local issues  = {}

-- 1. Config.BEE_COLOURS (12 entries)
local cfg = RS:FindFirstChild("Config")
if cfg then
    local ok, data = pcall(require, cfg)
    if ok and data.BEE_COLOURS and #data.BEE_COLOURS == 12 then
        table.insert(results, "✅ Config.BEE_COLOURS: " .. #data.BEE_COLOURS .. " entries")
    else
        table.insert(issues, "❌ Config.BEE_COLOURS: missing or wrong count (" .. tostring(ok and data.BEE_COLOURS and #data.BEE_COLOURS or "nil") .. ")")
    end
end

-- 2. DataService beeBodyColor
local ds = SSS:FindFirstChild("DataService")
if ds then
    local hasField = ds.Source:find("beeBodyColor") ~= nil
    table.insert(hasField and results or issues, (hasField and "✅" or "❌") .. " DataService: beeBodyColor field " .. (hasField and "present" or "MISSING"))
end

-- 3. BeeColorSync + SetBeeColor
local remotes = RS:FindFirstChild("Remotes")
local bcs = remotes and remotes:FindFirstChild("BeeColorSync")
local sbc = remotes and remotes:FindFirstChild("SetBeeColor")
table.insert(bcs and results or issues, (bcs and "✅" or "❌") .. " BeeColorSync RemoteEvent: " .. (bcs and "exists" or "MISSING"))
table.insert(sbc and results or issues, (sbc and "✅" or "❌") .. " SetBeeColor RemoteFunction: " .. (sbc and "exists" or "MISSING"))

-- 4. BeeColorService
local bcsvc = SSS:FindFirstChild("BeeColorService")
if bcsvc and bcsvc:IsA("ModuleScript") then
    local lines = select(2, bcsvc.Source:gsub("\n", "\n")) + 1
    local hasGetColor   = bcsvc.Source:find("GetColor") ~= nil
    local hasOnInvoke   = bcsvc.Source:find("OnServerInvoke") ~= nil
    local hasCharAdded  = bcsvc.Source:find("CharacterAdded") ~= nil
    table.insert(results, string.format("✅ BeeColorService: %d lines GetColor=%s OnServerInvoke=%s CharAdded=%s", lines, tostring(hasGetColor), tostring(hasOnInvoke), tostring(hasCharAdded)))
else
    table.insert(issues, "❌ BeeColorService: MISSING from ServerScriptService")
end

-- 5. WardrobePanel swatch count
local hiveGui = SG:FindFirstChild("HiveGui")
local mainFrame = hiveGui and hiveGui:FindFirstChild("MainFrame")
local wp = mainFrame and mainFrame:FindFirstChild("WardrobePanel")
if wp then
    local swatchCount = 0
    local hasRand = wp:FindFirstChild("RandomiseBtn") ~= nil
    local hasPreview = wp:FindFirstChild("SelectedColourLabel") ~= nil
    for _, child in wp:GetChildren() do
        if child:IsA("TextButton") and child.Name:find("^Swatch_") then
            swatchCount = swatchCount + 1
        end
    end
    table.insert(swatchCount == 12 and results or issues,
        (swatchCount == 12 and "✅" or "⚠️") .. " WardrobePanel swatches: " .. swatchCount .. " (expected 12)")
    table.insert(hasRand and results or issues, (hasRand and "✅" or "❌") .. " RandomiseBtn: " .. (hasRand and "exists" or "MISSING"))
    table.insert(hasPreview and results or issues, (hasPreview and "✅" or "❌") .. " SelectedColourLabel: " .. (hasPreview and "exists" or "MISSING"))
else
    table.insert(issues, "❌ WardrobePanel not found in HiveGui.MainFrame")
end

-- 6. BeeColourController
local sps = SP:FindFirstChild("StarterPlayerScripts")
local bcc = sps and sps:FindFirstChild("BeeColourController")
if bcc and bcc:IsA("LocalScript") then
    local lines = select(2, bcc.Source:gsub("\n", "\n")) + 1
    table.insert(results, "✅ BeeColourController: " .. lines .. " lines")
else
    table.insert(issues, "❌ BeeColourController: MISSING")
end

local out = "=== DISPATCH 40 VERIFICATION ===\n" .. table.concat(results, "\n")
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — Dispatch 40 complete" end
return out
```

---

## EXECUTION SUMMARY

| Step | What | Parts |
|------|------|-------|
| A | Config.BEE_COLOURS (12 entries) + DataService beeBodyColor | 0 |
| B | BeeColorSync RE + SetBeeColor RF + BeeColorService | 0 |
| C | GameManager wiring | 0 |
| D | 12 colour swatches + Randomise + preview label in WardrobePanel | 0 |
| E | BeeColourController LocalScript | 0 |
| F | Verification | — |

**Running part total: ~4,142 / 5,000** (no change)

---

## BEHAVIOURAL NOTES

- **Server-authoritative**: `SetBeeColor` is a RemoteFunction — server validates index range before applying
- **Persistence**: `profile.beeBodyColor` (int 1–12) saved by DataService on profile save
- **CharacterAdded**: colour re-applied on respawn automatically by BeeColorService
- **Multiplayer**: `BeeColorSync:FireAllClients` broadcasts every colour change so all players see updated bee colours
- **Pulse animation**: swatch scales to 115% on select (`Back/Out`) then back to 100% (`Quad/In`) — satisfying tactile feedback
- **Hover tooltip**: shows colour name on desktop hover (TextLabel inside swatch, hidden by default)
- **Randomise**: picks `math.random(1, 12)`, pulses the winning swatch, then calls `selectColour` as normal
- **SelectionRing**: `UIStroke.Enabled = true` on active swatch, `false` on all others — clear visual indicator

---

*Dispatch 40 complete — proceed to dispatch 41 (DailyRewardService login streak calendar)*
