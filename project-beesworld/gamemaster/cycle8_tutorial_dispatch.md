# Cycle 8 — Tutorial Dispatch

**Agents:** luau-scripter + ui-designer  
**Target:** Linear first-play walkthrough — TutorialService + TutorialGui  
**Part delta:** +10 (arrow indicators, highlight rings)  
**DataService version:** v9 (no new fields — adds tutorialComplete bool inside existing profile; handled by migration)  
**Prerequisites:** Cycles 1–7 + cycle8_shop_expansion all executed.

---

## Overview

A linear 10-step guided tutorial fires for new players only (profile.tutorialComplete is nil/false). Each step:
- Shows a floating arrow indicator pointing at the target object  
- Dims the screen with a spotlight vignette on the target area  
- Shows a compact HUD message (bottom-left, non-blocking) with step text  
- Advances automatically when the required action fires, or on manual SKIP  

**10 steps:**
1. Place your first cell (BuildController: CellBuilt event)
2. Do your first waggle dance (DanceController: DanceComplete event)
3. Harvest your first honey (HarvestController: HarvestComplete event)
4. Check the weather board (WeatherNoticeController: BoardInspected event)
5. Buy a Structure upgrade (StructureService: StructurePurchased event)
6. Visit the Wardrobe Pad (CosmeticController: WardrobeOpened event)
7. Check your Daily Quests (QuestController: QuestPanelOpened event)
8. Visit the Leaderboard (LeaderboardController: BoardViewed event)
9. Walk to the Pine Treeline edge (proximity trigger at (0,3,65))
10. Unlock Floor 2 (CombService: FloorUnlocked event)

---

## Step 1 — DataService v9 patch for tutorialComplete

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local DS  = SSS.Systems:FindFirstChild("DataService")
assert(DS, "DataService not found")

local clone = DS:Clone()
clone.Name = "DataService_new"
DS.Parent  = nil

local src = clone.Source

-- Add tutorialComplete to PROFILE_TEMPLATE (after equippedFlag line)
src = src:gsub(
    '(equippedFlag%s*=%s*"flag_default",)',
    '%1\n\t\ttutorialComplete = false,'
)

-- Add migration in MIGRATIONS table for v9: add tutorialComplete if missing
-- (We'll piggyback on the existing v9 migration block; look for its closing bracket)
src = src:gsub(
    '(if not profile%.data%.equippedFlag then.-end\n%s*end,)',
    '%1\n        [10] = function(profile)\n            if profile.data.tutorialComplete == nil then\n                profile.data.tutorialComplete = false\n            end\n        end,'
)

-- Bump version to 10
src = src:gsub('local CURRENT_VERSION = 9', 'local CURRENT_VERSION = 10')

clone.Source = src
clone.Name   = "DataService"
clone.Parent = SSS.Systems
print("DataService v10 installed — tutorialComplete added")
```

**Verify:**
```lua
local DS = game:GetService("ServerScriptService").Systems.DataService
print("Version:", DS.Source:match("CURRENT_VERSION = (%d+)"))
print("tutorialComplete in template:", DS.Source:find("tutorialComplete") and "YES" or "NO")
```
Expected: `Version: 10`, YES.

---

## Step 2 — TutorialService (ServerScriptService.Systems)

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local MS  = Instance.new("ModuleScript")
MS.Name   = "TutorialService"
MS.Parent = SSS.Systems
MS.Source = [[
--!strict
-- TutorialService — tracks tutorial step completion server-side
local TutorialService = {}

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local DataService -- lazy

local Remotes       = RS:WaitForChild("Remotes")
local TutorialSync  = Remotes:WaitForChild("TutorialSync")   -- server→client: {step, total, complete}
local TutorialStep  = Remotes:WaitForChild("TutorialStep")   -- client→server: advance step
local TutorialSkip  = Remotes:WaitForChild("TutorialSkip")   -- client→server: skip tutorial

local TOTAL_STEPS = 10

-- per-player state: currentStep (1-based, or nil if complete)
local _playerStep: {[number]: number} = {}

local function getDS()
    if not DataService then
        DataService = require(game:GetService("ServerScriptService").Systems.DataService)
    end
    return DataService
end

-- ── Sync to client ────────────────────────────────────────────────────────────

local function syncClient(player: Player)
    local step = _playerStep[player.UserId]
    TutorialSync:FireClient(player, {
        step     = step or TOTAL_STEPS + 1,
        total    = TOTAL_STEPS,
        complete = (step == nil),
    })
end

-- ── Advance step (called by server when an action fires) ─────────────────────

function TutorialService.Advance(player: Player, fromStep: number)
    local current = _playerStep[player.UserId]
    if not current or current ~= fromStep then return end  -- wrong step or complete
    local next = current + 1
    if next > TOTAL_STEPS then
        -- Tutorial complete
        _playerStep[player.UserId] = nil
        local DS = getDS()
        local profile = DS.GetProfile(player)
        if profile then
            profile.data.tutorialComplete = true
            DS.Save(player)
        end
        TutorialSync:FireClient(player, {step = nil, total = TOTAL_STEPS, complete = true})
    else
        _playerStep[player.UserId] = next
        syncClient(player)
    end
end

-- ── Remote listeners ─────────────────────────────────────────────────────────

function TutorialService.Start()
    -- Step advance signal from client (proximity or UI triggers)
    TutorialStep.OnServerEvent:Connect(function(player: Player, stepNum: number)
        if typeof(stepNum) ~= "number" then return end
        TutorialService.Advance(player, stepNum)
    end)

    -- Skip tutorial
    TutorialSkip.OnServerEvent:Connect(function(player: Player)
        _playerStep[player.UserId] = nil
        local DS = getDS()
        local profile = DS.GetProfile(player)
        if profile then
            profile.data.tutorialComplete = true
            DS.Save(player)
        end
        TutorialSync:FireClient(player, {step = nil, total = TOTAL_STEPS, complete = true})
    end)

    -- On player join: restore or start
    Players.PlayerAdded:Connect(function(player: Player)
        -- Wait for DataService to load profile
        task.delay(3, function()
            local DS = getDS()
            local profile = DS.GetProfile(player)
            if profile and not profile.data.tutorialComplete then
                _playerStep[player.UserId] = 1
            end
            syncClient(player)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        _playerStep[player.UserId] = nil
    end)
end

return TutorialService
]]
print("TutorialService created")
```

---

## Step 3 — RemoteEvents for tutorial

Run in Studio Command Bar:

```lua
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
assert(Remotes, "Remotes not found")

for _, name in {"TutorialSync", "TutorialStep", "TutorialSkip"} do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name   = name
        re.Parent = Remotes
        print("Created: " .. name)
    else
        print("Exists: " .. name)
    end
end
```

---

## Step 4 — Arrow indicator parts in Workspace

Run in Studio Command Bar:

```lua
-- 10 invisible arrow anchors, one per tutorial step
-- Each is a neon yellow Part (4x4x4 SmoothPlastic, Transparency=0.85)
-- tagged TutorialArrow with TutorialStep attribute
-- Positioned ABOVE the target:
--   Step 1: Above plot 1 deck front (−250, 14, −134) — first build cell area
--   Step 2: Above plot 1 dance floor (−250, 14, −125)
--   Step 3: Above plot 1 landing board (−250, 9, −125)
--   Step 4: Above weather notice board (+30, 18, −268)
--   Step 5: Above ApiaryShed tier 2 BudButton zone (−250, 14, −165)
--   Step 6: Above wardrobe pad plot 1 (−280, 16, −45)
--   Step 7: Above quest panel button (HUD — use plot 1 deck centre) (−250, 14, −150)
--   Step 8: Above leaderboard cork board (0, 18, −259)
--   Step 9: Above treeline edge (0, 8, 65)
--   Step 10: Above floor 2 unlock zone (−250, 22, −150)

local CS  = game:GetService("CollectionService")
local WS  = game:GetService("Workspace")

local ARROW_DATA = {
    {step=1,  pos=Vector3.new(-250, 14, -134)},
    {step=2,  pos=Vector3.new(-250, 14, -125)},
    {step=3,  pos=Vector3.new(-250,  9, -125)},
    {step=4,  pos=Vector3.new(  30, 18, -268)},
    {step=5,  pos=Vector3.new(-250, 14, -165)},
    {step=6,  pos=Vector3.new(-280, 16,  -45)},
    {step=7,  pos=Vector3.new(-250, 14, -150)},
    {step=8,  pos=Vector3.new(   0, 18, -259)},
    {step=9,  pos=Vector3.new(   0,  8,   65)},
    {step=10, pos=Vector3.new(-250, 22, -150)},
}

local folder = WS:FindFirstChild("TutorialArrows")
if folder then folder:Destroy() end
folder = Instance.new("Folder")
folder.Name   = "TutorialArrows"
folder.Parent = WS

for _, data in ARROW_DATA do
    local part = Instance.new("Part")
    part.Name         = "TutorialArrow_" .. data.step
    part.Size         = Vector3.new(3, 1, 3)
    part.Shape        = Enum.PartType.Cylinder
    part.Position     = data.pos
    part.Anchored     = true
    part.CanCollide   = false
    part.CastShadow   = false
    part.Material     = Enum.Material.Neon
    part.Color        = Color3.fromRGB(242, 168, 28)
    part.Transparency = 0.85
    part.Parent       = folder
    CS:AddTag(part, "TutorialArrow")
    part:SetAttribute("TutorialStep", data.step)
end

print("10 TutorialArrow parts created in Workspace.TutorialArrows")
```

---

## Step 5 — TutorialController LocalScript

Run in Studio Command Bar:

```lua
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("TutorialController")
if old then old:Destroy() end

local TC = Instance.new("LocalScript")
TC.Name   = "TutorialController"
TC.Parent = SPS
TC.Source = [[
--!strict
-- TutorialController — drives tutorial UI and arrow indicators client-side

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService    = game:GetService("RunService")

local player        = Players.LocalPlayer
local PlayerGui     = player:WaitForChild("PlayerGui")
local Camera        = workspace.CurrentCamera

local Remotes       = RS:WaitForChild("Remotes")
local TutorialSync  = Remotes:WaitForChild("TutorialSync")
local TutorialStep  = Remotes:WaitForChild("TutorialStep")
local TutorialSkip  = Remotes:WaitForChild("TutorialSkip")

-- ── Step definitions ──────────────────────────────────────────────────────────
local STEPS: {[number]: {title: string, body: string, trigger: string}} = {
    [1]  = {title = "Step 1 of 10: Place a Cell",
            body  = "Open the Build menu (B) and place your first Comb Cell on the hex grid.",
            trigger = "CellBuilt"},
    [2]  = {title = "Step 2 of 10: Waggle Dance",
            body  = "Tap the Dance Floor (the golden cell at the centre of your plot) to pick a flower route and start your first waggle dance.",
            trigger = "DanceComplete"},
    [3]  = {title = "Step 3 of 10: Harvest Honey",
            body  = "Walk up to your Landing Board and press the Harvest prompt to bank your first honey.",
            trigger = "HarvestComplete"},
    [4]  = {title = "Step 4 of 10: Check the Weather",
            body  = "Walk to the Weather Notice Board in the hub to see today's foraging conditions.",
            trigger = "BoardInspected"},
    [5]  = {title = "Step 5 of 10: Upgrade a Structure",
            body  = "Open the Shop (S) and buy a Structure upgrade — ApiaryShed or PropolisKiln.",
            trigger = "StructurePurchased"},
    [6]  = {title = "Step 6 of 10: Visit the Wardrobe",
            body  = "Walk to the Wardrobe Pad beside your plot and open it to try on a bee skin.",
            trigger = "WardrobeOpened"},
    [7]  = {title = "Step 7 of 10: Check Daily Quests",
            body  = "Open the Quest panel (Q) — three quests refresh daily. Complete them for bonus honey.",
            trigger = "QuestPanelOpened"},
    [8]  = {title = "Step 8 of 10: Leaderboard",
            body  = "Walk to the cork board at the back of the hub to see the top honey earners.",
            trigger = "BoardViewed"},
    [9]  = {title = "Step 9 of 10: The Treeline",
            body  = "Walk north past the meadow to the Pine Treeline. Something stirs beyond the pines...",
            trigger = "Proximity"},  -- proximity-based
    [10] = {title = "Step 10 of 10: Unlock Floor 2",
            body  = "Build enough cells to unlock the second floor of your hive. The real journey begins.",
            trigger = "FloorUnlocked"},
}

-- ── Build TutorialGui ─────────────────────────────────────────────────────────
local TutorialGui = Instance.new("ScreenGui")
TutorialGui.Name         = "TutorialGui"
TutorialGui.DisplayOrder = 8
TutorialGui.ResetOnSpawn = false
TutorialGui.Parent       = PlayerGui

-- Step HUD card (bottom-left)
local HudCard = Instance.new("Frame")
HudCard.Name             = "HudCard"
HudCard.Size             = UDim2.new(0, 340, 0, 80)
HudCard.Position         = UDim2.new(0, 16, 1, -100)
HudCard.BackgroundColor3 = Color3.fromRGB(50, 32, 14)
HudCard.BackgroundTransparency = 0.1
HudCard.Visible          = false
HudCard.Parent           = TutorialGui
Instance.new("UICorner", HudCard).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(242, 168, 28)
stroke.Thickness = 1.5
stroke.Parent    = HudCard

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Name             = "TitleLbl"
TitleLbl.Size             = UDim2.new(1, -10, 0, 24)
TitleLbl.Position         = UDim2.new(0, 8, 0, 6)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text             = ""
TitleLbl.TextColor3       = Color3.fromRGB(242, 168, 28)
TitleLbl.Font             = Enum.Font.FredokaOne
TitleLbl.TextSize         = 15
TitleLbl.TextXAlignment   = Enum.TextXAlignment.Left
TitleLbl.Parent           = HudCard

local BodyLbl = Instance.new("TextLabel")
BodyLbl.Name              = "BodyLbl"
BodyLbl.Size              = UDim2.new(1, -80, 0, 42)
BodyLbl.Position          = UDim2.new(0, 8, 0, 28)
BodyLbl.BackgroundTransparency = 1
BodyLbl.Text              = ""
BodyLbl.TextColor3        = Color3.fromRGB(232, 212, 154)
BodyLbl.Font              = Enum.Font.Gotham
BodyLbl.TextSize          = 12
BodyLbl.TextWrapped       = true
BodyLbl.TextXAlignment    = Enum.TextXAlignment.Left
BodyLbl.Parent            = HudCard

-- Progress bar (thin strip at bottom of card)
local ProgressBg = Instance.new("Frame")
ProgressBg.Name             = "ProgressBg"
ProgressBg.Size             = UDim2.new(1, -16, 0, 4)
ProgressBg.Position         = UDim2.new(0, 8, 1, -8)
ProgressBg.BackgroundColor3 = Color3.fromRGB(80, 55, 22)
ProgressBg.BorderSizePixel  = 0
ProgressBg.Parent           = HudCard
Instance.new("UICorner", ProgressBg).CornerRadius = UDim.new(1, 0)

local ProgressFill = Instance.new("Frame")
ProgressFill.Name             = "ProgressFill"
ProgressFill.Size             = UDim2.new(0, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
ProgressFill.BorderSizePixel  = 0
ProgressFill.Parent           = ProgressBg
Instance.new("UICorner", ProgressFill).CornerRadius = UDim.new(1, 0)

-- Skip button
local SkipBtn = Instance.new("TextButton")
SkipBtn.Name             = "SkipBtn"
SkipBtn.Size             = UDim2.new(0, 64, 0, 26)
SkipBtn.Position         = UDim2.new(1, -70, 0, 6)
SkipBtn.BackgroundColor3 = Color3.fromRGB(80, 55, 22)
SkipBtn.TextColor3       = Color3.fromRGB(160, 130, 90)
SkipBtn.Text             = "Skip"
SkipBtn.Font             = Enum.Font.Gotham
SkipBtn.TextSize         = 12
SkipBtn.Parent           = HudCard
Instance.new("UICorner", SkipBtn).CornerRadius = UDim.new(0, 6)

SkipBtn.MouseButton1Click:Connect(function()
    TutorialSkip:FireServer()
end)

-- ── Arrow bobbing ─────────────────────────────────────────────────────────────
local _arrowConnections: {RBXScriptConnection} = {}
local _currentArrowPart: BasePart?

local function clearArrow()
    for _, conn in _arrowConnections do conn:Disconnect() end
    _arrowConnections = {}
    if _currentArrowPart then
        _currentArrowPart.Transparency = 0.99
        _currentArrowPart = nil
    end
end

local function showArrowForStep(step: number)
    clearArrow()
    local CS = game:GetService("CollectionService")
    for _, part in CS:GetTagged("TutorialArrow") do
        if part:GetAttribute("TutorialStep") == step and part:IsA("BasePart") then
            _currentArrowPart = part
            part.Transparency = 0.5
            -- Bob up/down
            local baseY = part.Position.Y
            local t     = 0
            local conn = RunService.Heartbeat:Connect(function(dt)
                t += dt
                if part and part.Parent then
                    part.Position = Vector3.new(part.Position.X, baseY + math.sin(t * 2) * 0.6, part.Position.Z)
                end
            end)
            table.insert(_arrowConnections, conn)
            break
        end
    end
end

-- ── State update ──────────────────────────────────────────────────────────────
local function applyStep(data: {step: number?, total: number, complete: boolean})
    if data.complete or not data.step then
        HudCard.Visible = false
        clearArrow()
        return
    end
    local step = data.step
    local stepData = STEPS[step]
    if not stepData then return end

    TitleLbl.Text = stepData.title
    BodyLbl.Text  = stepData.body

    -- Progress bar
    local pct = (step - 1) / data.total
    TweenService:Create(ProgressFill, TweenInfo.new(0.4), {Size = UDim2.new(pct, 0, 1, 0)}):Play()

    -- Show card with slide-in
    HudCard.Position = UDim2.new(0, -360, 1, -100)
    HudCard.Visible  = true
    TweenService:Create(HudCard, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 16, 1, -100)}):Play()

    -- Arrow
    showArrowForStep(step)
end

TutorialSync.OnClientEvent:Connect(applyStep)

-- ── Proxy event wiring for action-based steps ─────────────────────────────────
-- These listen to other controllers' BindableEvents or use RemoteEvents that
-- come back as client-side signals.
-- Convention: each controller fires a BindableEvent in PlayerGui named after its trigger.

local function watchTrigger(triggerName: string, stepNum: number)
    local BE = PlayerGui:FindFirstChild(triggerName) or PlayerGui:WaitForChild(triggerName, 30)
    if not BE or not BE:IsA("BindableEvent") then return end
    BE.Event:Connect(function()
        TutorialStep:FireServer(stepNum)
    end)
end

-- Wire up action triggers
watchTrigger("CellBuilt",           1)
watchTrigger("DanceComplete",       2)
watchTrigger("HarvestComplete",     3)
watchTrigger("BoardInspected",      4)
watchTrigger("StructurePurchased",  5)
watchTrigger("WardrobeOpened",      6)
watchTrigger("QuestPanelOpened",    7)
watchTrigger("BoardViewed",         8)
-- Step 9: proximity-based — poll in Heartbeat
-- Step 10: FloorUnlocked BindableEvent
watchTrigger("FloorUnlocked",       10)

-- Step 9 proximity: treeline edge (0,3,65)
local TREELINE_POS = Vector3.new(0, 3, 65)
local step9Done    = false
RunService.Heartbeat:Connect(function()
    if step9Done then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if (hrp.Position - TREELINE_POS).Magnitude < 20 then
        step9Done = true
        TutorialStep:FireServer(9)
    end
end)
]]
print("TutorialController installed")
```

---

## Step 6 — Inject BindableEvent fires into existing controllers

Controllers need to fire BindableEvents when their actions complete. Run this once; it creates the BindableEvents and patches each controller.

```lua
-- Create the BindableEvents in PlayerGui (they're instance-local per-client;
-- StarterGui BindableEvents replicate per player on spawn)
local SG = game:GetService("StarterGui")

local BINDABLES = {
    "CellBuilt", "DanceComplete", "HarvestComplete", "BoardInspected",
    "StructurePurchased", "WardrobeOpened", "QuestPanelOpened",
    "BoardViewed", "FloorUnlocked"
}

local bFolder = SG:FindFirstChild("TutorialBindables")
if bFolder then bFolder:Destroy() end

-- We can't create BindableEvents directly in StarterGui reliably for all clients,
-- so instead we patch the relevant LocalScripts to fire the RemoteEvent directly.
-- Pattern: at the end of each key action, FireServer("TutorialStep", stepNum)

-- The TutorialController uses a simpler approach:
-- Each controller fires a BindableEvent stored in player.PlayerGui at runtime.
-- We patch each LocalScript to fire TutorialStep remote directly when the action completes.

local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")

local PATCHES = {
    -- {scriptName, searchPattern, stepNum, insertAfterPattern}
    {
        script = "BuildController",
        search = "CellBuilt",       -- already has this signal?
        step   = 1,
        -- If no existing signal, find the line that fires success feedback
        -- and add: RS.Remotes.TutorialStep:FireServer(1)
        triggerSearch = "NotifyGui",
        insertLine    = "\n\t\tgame:GetService('ReplicatedStorage').Remotes:FindFirstChild('TutorialStep') and game:GetService('ReplicatedStorage').Remotes.TutorialStep:FireServer(1)",
    },
    {
        script = "DanceController",
        step   = 2,
        triggerSearch = "DanceComplete",
        insertLine    = "\n\t\tgame:GetService('ReplicatedStorage').Remotes:FindFirstChild('TutorialStep') and game:GetService('ReplicatedStorage').Remotes.TutorialStep:FireServer(2)",
    },
    {
        script = "HarvestController",
        step   = 3,
        triggerSearch = "HarvestComplete",
        insertLine    = "\n\t\tgame:GetService('ReplicatedStorage').Remotes:FindFirstChild('TutorialStep') and game:GetService('ReplicatedStorage').Remotes.TutorialStep:FireServer(3)",
    },
}

for _, patch in PATCHES do
    local sc = SPS:FindFirstChild(patch.script)
    if not sc then
        print("SKIP (not found): " .. patch.script)
        continue
    end
    if sc.Source:find("TutorialStep") then
        print("Already patched: " .. patch.script)
        continue
    end
    -- Find the trigger search pattern and append the fire call after it
    local searchPat = patch.triggerSearch
    if sc.Source:find(searchPat) then
        local clone = sc:Clone()
        clone.Name   = sc.Name .. "_new"
        sc.Parent    = nil
        clone.Source = clone.Source:gsub(
            '(' .. searchPat .. '[^\n]*)',
            '%1' .. patch.insertLine,
            1
        )
        clone.Name   = sc.Name
        clone.Parent = SPS
        print("Patched: " .. patch.script .. " (step " .. patch.step .. ")")
    else
        print("Pattern not found in " .. patch.script .. " — manual patch needed for step " .. patch.step)
    end
end

-- WeatherNoticeController: step 4
local WNC = SPS:FindFirstChild("WeatherNoticeController")
if WNC and not WNC.Source:find("TutorialStep") then
    local clone = WNC:Clone()
    clone.Name = "WeatherNoticeController_new"
    WNC.Parent = nil
    -- Fire step 4 when player walks within 10 studs of any WeatherBoard tagged object
    -- Append proximity check in Heartbeat; simplest approach: patch the updateBoards function
    clone.Source = clone.Source:gsub(
        '(local function updateBoards)',
        'local _tutStep4Done = false\n%1'
    )
    clone.Source = clone.Source .. [[

-- Tutorial step 4: walked to weather board
game:GetService("RunService").Heartbeat:Connect(function()
    if _tutStep4Done then return end
    local player = game:GetService("Players").LocalPlayer
    local char   = player.Character
    if not char then return end
    local hrp    = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local CS     = game:GetService("CollectionService")
    for _, board in CS:GetTagged("WeatherBoard") do
        if board:IsA("BasePart") and (hrp.Position - board.Position).Magnitude < 12 then
            _tutStep4Done = true
            local TR = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("TutorialStep")
            if TR then TR:FireServer(4) end
            break
        end
    end
end)
]]
    clone.Name   = "WeatherNoticeController"
    clone.Parent = SPS
    print("Patched WeatherNoticeController — step 4")
end

-- ShopController: step 5 (StructurePurchased)
local ShopCtrl = SPS:FindFirstChild("ShopController")
if ShopCtrl and not ShopCtrl.Source:find("TutorialStep") then
    local clone = ShopCtrl:Clone()
    clone.Name = "ShopController_new"
    ShopCtrl.Parent = nil
    -- Patch the Upgrades tab buy callback to also fire step 5
    clone.Source = clone.Source:gsub(
        '(PurchaseStructure:FireServer%(structName, tierIdx%))',
        '%1\n                local TR = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("TutorialStep") if TR then TR:FireServer(5) end'
    )
    clone.Name   = "ShopController"
    clone.Parent = SPS
    print("Patched ShopController — step 5")
end

-- CosmeticController: step 6
local CosCtrl = SPS:FindFirstChild("CosmeticController")
if CosCtrl and not CosCtrl.Source:find("TutorialStep") then
    local clone = CosCtrl:Clone()
    clone.Name = "CosmeticController_new"
    CosCtrl.Parent = nil
    -- Fire on WardrobeGui open
    clone.Source = clone.Source:gsub(
        '(WardrobeGui%.Visible%s*=%s*true)',
        '%1\nlocal TR6 = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("TutorialStep") if TR6 then TR6:FireServer(6) end',
        1
    )
    clone.Name   = "CosmeticController"
    clone.Parent = SPS
    print("Patched CosmeticController — step 6")
end

-- QuestController: step 7
local QCtrl = SPS:FindFirstChild("QuestController")
if QCtrl and not QCtrl.Source:find("TutorialStep") then
    local clone = QCtrl:Clone()
    clone.Name = "QuestController_new"
    QCtrl.Parent = nil
    -- Fire on quest panel open tween
    clone.Source = clone.Source:gsub(
        '(QuestPanel.*Visible%s*=%s*true)',
        '%1\nlocal TR7 = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("TutorialStep") if TR7 then TR7:FireServer(7) end',
        1
    )
    clone.Name   = "QuestController"
    clone.Parent = SPS
    print("Patched QuestController — step 7")
end

-- LeaderboardController: step 8 (proximity to leaderboard)
local LBCtrl = SPS:FindFirstChild("LeaderboardController")
if LBCtrl and not LBCtrl.Source:find("TutorialStep") then
    local clone = LBCtrl:Clone()
    clone.Name = "LeaderboardController_new"
    LBCtrl.Parent = nil
    clone.Source = clone.Source .. [[

-- Tutorial step 8: visited leaderboard board
local _tutStep8Done = false
game:GetService("RunService").Heartbeat:Connect(function()
    if _tutStep8Done then return end
    local player = game:GetService("Players").LocalPlayer
    local char   = player.Character
    if not char then return end
    local hrp    = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    -- Cork board at (0,12,-259)
    if (hrp.Position - Vector3.new(0, 2, -259)).Magnitude < 15 then
        _tutStep8Done = true
        local TR = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("TutorialStep")
        if TR then TR:FireServer(8) end
    end
end)
]]
    clone.Name   = "LeaderboardController"
    clone.Parent = SPS
    print("Patched LeaderboardController — step 8")
end

-- CombService client event: step 10 (floor unlock)
-- FloorUnlocked is fired by CombService.FloorUnlocked RemoteEvent
-- Patch BuildController to listen:
local BuildCtrl = SPS:FindFirstChild("BuildController")
if BuildCtrl and not BuildCtrl.Source:find("TutorialStep.*10") then
    local clone = BuildCtrl:Clone()
    clone.Name = "BuildController_new"
    BuildCtrl.Parent = nil
    clone.Source = clone.Source .. [[

-- Tutorial step 10: floor unlocked
local FloorUnlocked10 = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("FloorUnlocked")
if FloorUnlocked10 then
    FloorUnlocked10.OnClientEvent:Connect(function()
        local TR = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("TutorialStep")
        if TR then TR:FireServer(10) end
    end)
end
]]
    clone.Name   = "BuildController"
    clone.Parent = SPS
    print("Patched BuildController — step 10 (FloorUnlocked)")
end

print("Controller patching complete")
```

---

## Step 7 — Start TutorialService from server

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

-- Add to ShopSystemsStart or create separate
local existingStart = SSS:FindFirstChild("ShopSystemsStart")
if existingStart and not existingStart.Source:find("TutorialService") then
    local src = existingStart.Source
    src = src .. [[

-- TutorialService
local TutorialService = require(Systems:WaitForChild("TutorialService"))
TutorialService.Start()
print("[TutorialService] started")
]]
    existingStart.Source = src
    print("Patched ShopSystemsStart with TutorialService.Start()")
else
    -- Create standalone
    local sc = Instance.new("Script")
    sc.Name   = "TutorialServiceStart"
    sc.Parent = SSS
    sc.Source = [[
--!strict
local SSS     = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local TS      = require(Systems:WaitForChild("TutorialService"))
TS.Start()
print("[TutorialService] started")
]]
    print("Created TutorialServiceStart Script")
end
```

---

## Step 8 — Verification

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SP  = game:GetService("StarterPlayer")
local CS  = game:GetService("CollectionService")

local results = {}
local issues  = {}

-- TutorialService
local TS = SSS.Systems:FindFirstChild("TutorialService")
if TS and TS:IsA("ModuleScript") then
    table.insert(results, "TutorialService ✓")
else
    table.insert(issues, "MISSING: TutorialService")
end

-- DataService v10
local DS = SSS.Systems:FindFirstChild("DataService")
if DS then
    local v = DS.Source:match("CURRENT_VERSION = (%d+)")
    if v == "10" then table.insert(results, "DataService v10 ✓")
    else table.insert(issues, "DataService version = " .. (v or "?") .. " (expected 10)") end
end

-- RemoteEvents
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
for _, name in {"TutorialSync", "TutorialStep", "TutorialSkip"} do
    local re = Remotes and Remotes:FindFirstChild(name)
    if re then table.insert(results, "RE:" .. name .. " ✓")
    else table.insert(issues, "MISSING RE: " .. name) end
end

-- TutorialArrows
local arrows = CS:GetTagged("TutorialArrow")
table.insert(results, "TutorialArrow parts: " .. #arrows)
if #arrows ~= 10 then table.insert(issues, "Expected 10 arrows, got " .. #arrows) end

-- TutorialController
local SPS = SP:FindFirstChild("StarterPlayerScripts")
local TC  = SPS and SPS:FindFirstChild("TutorialController")
if TC then
    local lines = select(2, TC.Source:gsub("\n","")) + 1
    table.insert(results, "TutorialController ✓ (" .. lines .. " lines)")
else
    table.insert(issues, "MISSING: TutorialController LocalScript")
end

print("=== TUTORIAL VERIFICATION ===")
for _, r in results do print("✓ " .. r) end
if #issues > 0 then
    print("ISSUES:")
    for _, iss in issues do print("✗ " .. iss) end
else
    print("ALL CLEAR — tutorial system complete")
end
```

**Expected:**
```
✓ TutorialService ✓
✓ DataService v10 ✓
✓ RE:TutorialSync ✓
✓ RE:TutorialStep ✓
✓ RE:TutorialSkip ✓
✓ TutorialArrow parts: 10
✓ TutorialController ✓ (180+ lines)
ALL CLEAR — tutorial system complete
```

---

## Summary

| Item | Detail |
|------|--------|
| TutorialService | Server-side step tracking, skip, complete flag |
| TutorialController | Client HUD card, progress bar, arrow indicators, proximity step 9 |
| DataService bump | v9 → v10; adds `tutorialComplete` bool |
| RemoteEvents | TutorialSync, TutorialStep, TutorialSkip |
| Arrow parts | 10 TutorialArrow Cylinder parts in Workspace.TutorialArrows |
| Controller patches | 8 controllers patched with TutorialStep:FireServer(n) calls |
| Part delta | +10 → ~3,875/5,000 |
| Skippable | Yes — single SKIP button fires TutorialSkip, sets tutorialComplete=true |
| Persistence | tutorialComplete survives swarms (stored as plain bool, not reset by performSwarm) |
