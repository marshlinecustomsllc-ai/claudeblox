# Dispatch 35 — TutorialService: First-Play Guided Tooltip Overlay
**File:** `cycle11_tutorial_dispatch.md`
**Cycle:** 11
**Part budget:** 0 → ~4,098/5,000 (UI only, no world parts)
**DataService migration:** None (uses `profile.tutorialComplete` boolean, defaulting false if absent)
**Depends on:** Dispatch 8 (DataService profile), Dispatch 28 (FloorProgressGui — step 4 references floor gate)
**Supersedes:** Nothing

---

## Purpose

Guide **first-time players** through the core loop with a 4-step arrow tooltip sequence that
appears at session start and disappears permanently once completed (stored in profile).

Steps:
1. **Place your first cell** → arrow points at BUILD tab
2. **Harvest honey** → arrow points at the harvest button / auto-harvest counter
3. **Explore the Wardrobe** → arrow points at WARDROBE tab
4. **Check the Floor Gate** → arrow points at FLOORS tab, text "Build 12 cells to unlock Floor 2!"

Before this dispatch: new players land in an empty hive with no guidance.
After this dispatch: first-time players get a non-intrusive 4-step overlay; returning players see nothing.

---

## STEP A — Config: TUTORIAL_STEPS table

```lua
-- STEP A: Add TUTORIAL_STEPS to Config
local config = game:GetService("ServerScriptService"):FindFirstChild("Config")
    or game:GetService("ReplicatedStorage"):FindFirstChild("Config")
assert(config, "Config not found")

local clone = config:Clone()
local oldName = config.Name
config.Name = oldName .. "_OLD_35A"
config.Parent = nil

local src = clone.Source

local injection = [[

-- Tutorial step definitions (server holds authoritative step order)
Config.TUTORIAL_STEPS = {
    {
        id       = "place_cell",
        title    = "Build Your First Cell 🍯",
        desc     = "Tap BUILD to place a Honeycomb Cell on your plot and start producing honey!",
        arrow    = "TabBuild",     -- name of GuiObject the arrow points at
        autoNext = false,          -- player must complete an action to advance
    },
    {
        id       = "harvest_honey",
        title    = "Harvest Honey 🐝",
        desc     = "Wait for cells to fill, then tap HARVEST to collect your honey.",
        arrow    = "HarvestButton",
        autoNext = false,
    },
    {
        id       = "open_wardrobe",
        title    = "Dress Your Bee ✨",
        desc     = "Visit the WARDROBE tab to change your bee's appearance!",
        arrow    = "TabWardrobe",
        autoNext = false,
    },
    {
        id       = "check_floors",
        title    = "Unlock Floor 2 🏠",
        desc     = "Build 12 cells and spend 5,000 honey to unlock the next floor!",
        arrow    = "TabFloors",
        autoNext = false,
    },
}
]]

local newSrc = src:gsub("(\n*return Config%s*$)", injection .. "%1")
if newSrc == src then newSrc = src .. injection end
clone.Source = newSrc
clone.Name = oldName
clone.Parent = game:GetService("ServerScriptService")

print("✅ STEP A: Config.TUTORIAL_STEPS added (4 steps)")
```

**Verify Step A:**

```lua
local ok, config = pcall(require, game:GetService("ServerScriptService"):FindFirstChild("Config")
    or game:GetService("ReplicatedStorage"):FindFirstChild("Config"))
assert(ok and config, "Config require failed")
assert(config.TUTORIAL_STEPS, "TUTORIAL_STEPS missing")
assert(#config.TUTORIAL_STEPS == 4, "Expected 4 steps, got " .. #config.TUTORIAL_STEPS)
print("✅ STEP A verified: TUTORIAL_STEPS[1..4] present")
for i, s in config.TUTORIAL_STEPS do print(i, s.id, s.arrow) end
```

---

## STEP B — TutorialService ModuleScript (server-side flag management)

```lua
-- STEP B: Create TutorialService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
local old = SSS:FindFirstChild("TutorialService")
if old then old:Destroy() end

local svc = Instance.new("ModuleScript")
svc.Name   = "TutorialService"
svc.Source = [[
--!strict
-- TutorialService — first-play tutorial flag management (dispatch 35)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config      = require(game:GetService("ServerScriptService"):FindFirstChild("Config")
                       or ReplicatedStorage:FindFirstChild("Config"))
local DataService = require(game:GetService("ServerScriptService"):FindFirstChild("DataService"))

local remotes      = ReplicatedStorage:FindFirstChild("Remotes")
local TutorialSync = remotes and remotes:FindFirstChild("TutorialSync")

-- ---------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------
local TutorialService = {}

-- Called on PlayerAdded (after profile load delay): sends tutorial data to client
function TutorialService.OnPlayerAdded(player: Player): ()
    task.wait(4)  -- wait for profile load
    local profile = DataService.GetProfile(player)
    if not profile then return end

    -- Default tutorialComplete to false if absent (new field)
    if profile.tutorialComplete == nil then
        profile.tutorialComplete = false
    end
    -- Default completedSteps to empty table if absent
    if not profile.completedSteps then
        profile.completedSteps = {}
    end

    if profile.tutorialComplete then return end  -- skip for returning players

    -- Send steps to client
    if TutorialSync then
        TutorialSync:FireClient(player, {
            steps           = Config.TUTORIAL_STEPS,
            completedSteps  = profile.completedSteps,
            tutorialComplete = profile.tutorialComplete,
        })
    end
end

-- Called by client RemoteFunction (TutorialStepComplete) when player advances a step
function TutorialService.MarkStepComplete(player: Player, stepId: string): ()
    local profile = DataService.GetProfile(player)
    if not profile then return end
    if not profile.completedSteps then profile.completedSteps = {} end

    -- Idempotent: only insert if not already present
    for _, id in profile.completedSteps do
        if id == stepId then return end
    end
    table.insert(profile.completedSteps, stepId)

    -- Check if all steps done
    local allSteps = Config.TUTORIAL_STEPS or {}
    if #profile.completedSteps >= #allSteps then
        profile.tutorialComplete = true
        DataService.SaveProfile(player)

        -- Notify client to hide overlay permanently
        if TutorialSync then
            TutorialSync:FireClient(player, { tutorialComplete = true, steps = {} })
        end
    else
        DataService.SaveProfile(player)
        -- Re-sync updated completedSteps
        if TutorialSync then
            TutorialSync:FireClient(player, {
                steps           = Config.TUTORIAL_STEPS,
                completedSteps  = profile.completedSteps,
                tutorialComplete = profile.tutorialComplete,
            })
        end
    end
end

function TutorialService.Init(): ()
    -- Wire RemoteFunction for step completion
    local remFunc = remotes and remotes:FindFirstChild("TutorialStepComplete")
    if remFunc and remFunc:IsA("RemoteFunction") then
        remFunc.OnServerInvoke = function(player: Player, stepId: string): boolean
            TutorialService.MarkStepComplete(player, stepId)
            return true
        end
    end

    Players.PlayerAdded:Connect(TutorialService.OnPlayerAdded)

    -- Handle existing players (Studio play-test)
    for _, p in Players:GetPlayers() do
        TutorialService.OnPlayerAdded(p)
    end
end

return TutorialService
]]
svc.Parent = SSS

print("✅ STEP B: TutorialService created")
```

**Verify Step B:**

```lua
local SSS = game:GetService("ServerScriptService")
local svc = SSS:FindFirstChild("TutorialService")
assert(svc and svc:IsA("ModuleScript"), "TutorialService missing")
local src = svc.Source
assert(src:find("OnPlayerAdded"), "OnPlayerAdded missing")
assert(src:find("MarkStepComplete"), "MarkStepComplete missing")
assert(src:find("TutorialSync"), "TutorialSync not referenced")
assert(src:find("--!strict"), "--!strict missing")
print("✅ STEP B verified: TutorialService correct")
```

---

## STEP C — RemoteEvent + RemoteFunction

```lua
-- STEP C: Create TutorialSync RemoteEvent + TutorialStepComplete RemoteFunction
local RS = game:GetService("ReplicatedStorage")
local remotes = RS:FindFirstChild("Remotes")
assert(remotes, "Remotes folder not found")

if not remotes:FindFirstChild("TutorialSync") then
    local ev = Instance.new("RemoteEvent")
    ev.Name   = "TutorialSync"
    ev.Parent = remotes
    print("TutorialSync RemoteEvent created")
else
    print("TutorialSync already exists")
end

if not remotes:FindFirstChild("TutorialStepComplete") then
    local rf = Instance.new("RemoteFunction")
    rf.Name   = "TutorialStepComplete"
    rf.Parent = remotes
    print("TutorialStepComplete RemoteFunction created")
else
    print("TutorialStepComplete already exists")
end

print("✅ STEP C: Tutorial remotes present")
```

---

## STEP D — TutorialGui ScreenGui (static arrow structure)

```lua
-- STEP D: Build TutorialGui in StarterGui
local SG = game:GetService("StarterGui")

local old = SG:FindFirstChild("TutorialGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name           = "TutorialGui"
gui.IgnoreGuiInset = true
gui.DisplayOrder   = 60   -- above everything
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = SG

-- Dimmer (semi-transparent overlay behind tooltip)
local dimmer = Instance.new("Frame")
dimmer.Name              = "Dimmer"
dimmer.Size              = UDim2.fromScale(1, 1)
dimmer.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
dimmer.BackgroundTransparency = 0.55
dimmer.BorderSizePixel   = 0
dimmer.ZIndex            = 1
dimmer.Visible           = false
dimmer.Parent            = gui

-- Tooltip panel (bottom-centre)
local tooltip = Instance.new("Frame")
tooltip.Name                = "Tooltip"
tooltip.Size                = UDim2.new(0.60, 0, 0.16, 0)
tooltip.Position            = UDim2.new(0.20, 0, 0.80, 0)
tooltip.AnchorPoint         = Vector2.new(0, 0)
tooltip.BackgroundColor3    = Color3.fromRGB(25, 14, 4)
tooltip.BackgroundTransparency = 0.08
tooltip.BorderSizePixel     = 0
tooltip.ZIndex              = 2
tooltip.Visible             = false
tooltip.Parent              = gui

local ttCorner = Instance.new("UICorner")
ttCorner.CornerRadius = UDim.new(0, 12)
ttCorner.Parent = tooltip

local ttStroke = Instance.new("UIStroke")
ttStroke.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold
ttStroke.Thickness = 2
ttStroke.Parent    = tooltip

-- Step indicator (e.g. "Step 1 of 4")
local stepLabel = Instance.new("TextLabel")
stepLabel.Name             = "StepLabel"
stepLabel.Size             = UDim2.new(0.3, 0, 0.28, 0)
stepLabel.Position         = UDim2.new(0.02, 0, 0.04, 0)
stepLabel.BackgroundTransparency = 1
stepLabel.TextColor3       = Color3.fromRGB(180, 150, 60)
stepLabel.Font             = Enum.Font.FredokaOne
stepLabel.TextScaled       = true
stepLabel.Text             = "Step 1 of 4"
stepLabel.TextXAlignment   = Enum.TextXAlignment.Left
stepLabel.ZIndex           = 3
stepLabel.Parent           = tooltip

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name             = "Title"
titleLabel.Size             = UDim2.new(0.96, 0, 0.32, 0)
titleLabel.Position         = UDim2.new(0.02, 0, 0.30, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3       = Color3.fromRGB(242, 168, 28)  -- Honey Gold
titleLabel.Font             = Enum.Font.FredokaOne
titleLabel.TextScaled       = true
titleLabel.Text             = "Build Your First Cell 🍯"
titleLabel.TextXAlignment   = Enum.TextXAlignment.Left
titleLabel.ZIndex           = 3
titleLabel.Parent           = tooltip

-- Description
local descLabel = Instance.new("TextLabel")
descLabel.Name              = "Desc"
descLabel.Size              = UDim2.new(0.75, 0, 0.35, 0)
descLabel.Position          = UDim2.new(0.02, 0, 0.60, 0)
descLabel.BackgroundTransparency = 1
descLabel.TextColor3        = Color3.fromRGB(232, 212, 154)  -- Wax Cream
descLabel.Font              = Enum.Font.FredokaOne
descLabel.TextScaled        = true
descLabel.TextWrapped       = true
descLabel.Text              = "Tap BUILD to place a cell."
descLabel.TextXAlignment    = Enum.TextXAlignment.Left
descLabel.ZIndex            = 3
descLabel.Parent            = tooltip

-- Skip button
local skipBtn = Instance.new("TextButton")
skipBtn.Name                = "SkipBtn"
skipBtn.Size                = UDim2.new(0.20, 0, 0.45, 0)
skipBtn.Position            = UDim2.new(0.78, 0, 0.28, 0)
skipBtn.BackgroundColor3    = Color3.fromRGB(60, 35, 10)
skipBtn.TextColor3          = Color3.fromRGB(180, 150, 80)
skipBtn.Font                = Enum.Font.FredokaOne
skipBtn.TextScaled          = true
skipBtn.Text                = "Skip"
skipBtn.ZIndex              = 3
skipBtn.Parent              = tooltip

local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 6)
skipCorner.Parent = skipBtn

-- Arrow indicator (points at the target UI element)
local arrow = Instance.new("TextLabel")
arrow.Name                = "Arrow"
arrow.Size                = UDim2.new(0.08, 0, 0.10, 0)
arrow.Position            = UDim2.new(0.10, 0, 0.70, 0)  -- positioned by controller
arrow.BackgroundTransparency = 1
arrow.TextColor3          = Color3.fromRGB(242, 168, 28)
arrow.Font                = Enum.Font.FredokaOne
arrow.TextScaled          = true
arrow.Text                = "⬆"   -- rotated/repositioned by controller
arrow.ZIndex              = 3
arrow.Parent              = gui   -- sibling of Tooltip so it can float freely

print("✅ STEP D: TutorialGui created (Dimmer, Tooltip panel, Arrow)")
```

**Verify Step D:**

```lua
local SG  = game:GetService("StarterGui")
local gui = SG:FindFirstChild("TutorialGui")
assert(gui, "TutorialGui missing")
assert(gui:FindFirstChild("Dimmer"), "Dimmer missing")
local tt = gui:FindFirstChild("Tooltip")
assert(tt, "Tooltip missing")
assert(tt:FindFirstChild("Title"), "Title missing")
assert(tt:FindFirstChild("Desc"), "Desc missing")
assert(tt:FindFirstChild("SkipBtn"), "SkipBtn missing")
assert(gui:FindFirstChild("Arrow"), "Arrow missing")
print("✅ STEP D verified: TutorialGui structure correct")
```

---

## STEP E — TutorialController LocalScript

```lua
-- STEP E: TutorialController LocalScript in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("TutorialController")
if old then old:Destroy() end

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "TutorialController"
ctrl.Source = [[
--!strict
-- TutorialController — drives TutorialGui from TutorialSync events (dispatch 35)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
local gui       = playerGui:WaitForChild("TutorialGui", 10)
local dimmer    = gui:WaitForChild("Dimmer", 10)        :: Frame
local tooltip   = gui:WaitForChild("Tooltip", 10)       :: Frame
local arrow     = gui:WaitForChild("Arrow", 10)         :: TextLabel
local stepLabel = tooltip:WaitForChild("StepLabel", 10) :: TextLabel
local titleLbl  = tooltip:WaitForChild("Title", 10)     :: TextLabel
local descLbl   = tooltip:WaitForChild("Desc", 10)      :: TextLabel
local skipBtn   = tooltip:WaitForChild("SkipBtn", 10)   :: TextButton

local remotes              = ReplicatedStorage:WaitForChild("Remotes", 10)
local TutorialSync         = remotes:WaitForChild("TutorialSync", 10)
local TutorialStepComplete = remotes:WaitForChild("TutorialStepComplete", 10)

-- ---------------------------------------------------------------
-- State
-- ---------------------------------------------------------------
type StepDef = { id: string, title: string, desc: string, arrow: string, autoNext: boolean }

local _steps:          { StepDef } = {}
local _completedSteps: { string }  = {}
local _currentIndex: number        = 1
local _active: boolean             = false

local FADE_IN  = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- ---------------------------------------------------------------
-- Arrow positioning: finds the target GuiObject by name in PlayerGui
-- ---------------------------------------------------------------
local function findTarget(targetName: string): GuiObject?
    for _, sg in playerGui:GetChildren() do
        if sg:IsA("ScreenGui") then
            local found = sg:FindFirstChild(targetName, true)
            if found and found:IsA("GuiObject") then
                return found :: GuiObject
            end
        end
    end
    return nil
end

local function positionArrow(targetName: string): ()
    local target = findTarget(targetName)
    if not target then
        arrow.Visible = false
        return
    end
    -- Approximate position: centre of target, one row above
    local ap = target.AbsolutePosition
    local as = target.AbsoluteSize
    local cx = ap.X + as.X / 2
    local cy = ap.Y - 40
    -- Convert to scale
    local sw = playerGui.AbsoluteSize.X
    local sh = playerGui.AbsoluteSize.Y
    arrow.Position    = UDim2.new(cx / sw - 0.04, 0, cy / sh - 0.05, 0)
    arrow.Text        = "⬇"   -- pointing down at the target
    arrow.Visible     = true
end

-- ---------------------------------------------------------------
-- Show / hide helpers
-- ---------------------------------------------------------------
local function showStep(step: StepDef, index: number, total: number): ()
    stepLabel.Text = "Step " .. index .. " of " .. total
    titleLbl.Text  = step.title
    descLbl.Text   = step.desc

    positionArrow(step.arrow)

    dimmer.Visible  = true
    tooltip.Visible = true
    TweenService:Create(dimmer, FADE_IN, { BackgroundTransparency = 0.55 }):Play()
    _active = true
end

local function hideAll(): ()
    TweenService:Create(dimmer, FADE_OUT, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(tooltip, FADE_OUT, {}):Play()
    task.delay(0.25, function(): ()
        dimmer.Visible  = false
        tooltip.Visible = false
        arrow.Visible   = false
    end)
    _active = false
end

-- ---------------------------------------------------------------
-- Advance to next incomplete step
-- ---------------------------------------------------------------
local function nextStep(): ()
    for i, step in _steps do
        local completed = false
        for _, id in _completedSteps do
            if id == step.id then completed = true break end
        end
        if not completed then
            _currentIndex = i
            showStep(step, i, #_steps)
            return
        end
    end
    -- All done
    hideAll()
end

local function markCurrentComplete(): ()
    local step = _steps[_currentIndex]
    if not step then return end

    -- Idempotent local update
    local alreadyDone = false
    for _, id in _completedSteps do
        if id == step.id then alreadyDone = true break end
    end
    if not alreadyDone then
        table.insert(_completedSteps, step.id)
    end

    -- Notify server
    task.spawn(function(): ()
        pcall(function(): ()
            TutorialStepComplete:InvokeServer(step.id)
        end)
    end)

    nextStep()
end

-- ---------------------------------------------------------------
-- Skip: mark all steps complete
-- ---------------------------------------------------------------
local function skipAll(): ()
    for _, step in _steps do
        pcall(function(): ()
            TutorialStepComplete:InvokeServer(step.id)
        end)
    end
    hideAll()
end

skipBtn.Activated:Connect(skipAll)

-- ---------------------------------------------------------------
-- Tab button detection: tapping a target advances the step
-- ---------------------------------------------------------------
local function wireTabButtons(): ()
    for _, sg in playerGui:GetChildren() do
        if sg:IsA("ScreenGui") then
            for _, obj in sg:GetDescendants() do
                if obj:IsA("GuiButton") then
                    obj.Activated:Connect(function(): ()
                        if not _active then return end
                        local step = _steps[_currentIndex]
                        if step and obj.Name == step.arrow then
                            markCurrentComplete()
                        end
                    end)
                end
            end
        end
    end
end

-- Run wiring after a brief delay so all GUIs have loaded
task.delay(2, wireTabButtons)

-- ---------------------------------------------------------------
-- TutorialSync handler
-- ---------------------------------------------------------------
TutorialSync.OnClientEvent:Connect(function(data: {
    steps: { StepDef }?,
    completedSteps: { string }?,
    tutorialComplete: boolean?,
}): ()
    if data.tutorialComplete then
        hideAll()
        return
    end

    _steps          = data.steps or {}
    _completedSteps = data.completedSteps or {}

    if #_steps == 0 then
        hideAll()
        return
    end

    nextStep()
end)
]]
ctrl.Parent = SPS

print("✅ STEP E: TutorialController LocalScript created")
```

**Verify Step E:**

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("TutorialController")
assert(ctrl and ctrl:IsA("LocalScript"), "TutorialController missing")
local src = ctrl.Source
assert(src:find("TutorialSync"), "TutorialSync not referenced")
assert(src:find("TutorialStepComplete"), "TutorialStepComplete not referenced")
assert(src:find("skipAll"), "skipAll missing")
assert(src:find("positionArrow"), "positionArrow missing")
assert(src:find("--!strict"), "--!strict missing")
print("✅ STEP E verified: TutorialController correct")
```

---

## STEP F — Wire TutorialService.Init() into Main Script

```lua
-- STEP F: Wire TutorialService into Main Script
local SSS = game:GetService("ServerScriptService")
local mainScript = SSS:FindFirstChild("Main") or SSS:FindFirstChild("GameManager")
assert(mainScript, "Main/GameManager not found")

if mainScript.Source:find("TutorialService") then
    print("✅ STEP F: TutorialService already in Main Script — no change needed")
else
    local clone = mainScript:Clone()
    local oldName = mainScript.Name
    mainScript.Name = oldName .. "_OLD_35F"
    mainScript.Parent = nil

    local reqLine = "\nlocal TutorialService = require(game:GetService(\"ServerScriptService\"):FindFirstChild(\"TutorialService\"))\nTutorialService.Init()\n"
    local newSrc = mainScript.Source
    newSrc = newSrc:gsub("(Players%.PlayerAdded)", reqLine .. "%1", 1)
    if newSrc == mainScript.Source then newSrc = mainScript.Source .. reqLine end
    clone.Source = newSrc
    clone.Name = oldName
    clone.Parent = SSS
    print("✅ STEP F: TutorialService.Init() injected into Main Script")
end
```

---

## STEP G — Full verification

```lua
-- STEP G: Full dispatch 35 verification
local SSS     = game:GetService("ServerScriptService")
local RS      = game:GetService("ReplicatedStorage")
local SG      = game:GetService("StarterGui")
local SP      = game:GetService("StarterPlayer")
local SPS     = SP:FindFirstChild("StarterPlayerScripts")
local remotes = RS:FindFirstChild("Remotes")
local results = {}
local issues  = {}

-- 1. Config.TUTORIAL_STEPS
local ok, config = pcall(require, SSS:FindFirstChild("Config") or RS:FindFirstChild("Config"))
if ok and config and config.TUTORIAL_STEPS and #config.TUTORIAL_STEPS == 4 then
    table.insert(results, "✅ Config.TUTORIAL_STEPS: 4 steps")
else
    table.insert(issues, "❌ Config.TUTORIAL_STEPS missing or wrong count")
end

-- 2. TutorialService
local svc = SSS:FindFirstChild("TutorialService")
if svc and svc:IsA("ModuleScript") and svc.Source:find("MarkStepComplete") then
    table.insert(results, "✅ TutorialService present")
else
    table.insert(issues, "❌ TutorialService missing")
end

-- 3. Remotes
local hasTSync = remotes and remotes:FindFirstChild("TutorialSync") ~= nil
local hasTSC   = remotes and remotes:FindFirstChild("TutorialStepComplete") ~= nil
if hasTSync and hasTSC then
    table.insert(results, "✅ TutorialSync + TutorialStepComplete remotes present")
else
    table.insert(issues, "❌ Tutorial remotes missing (TutorialSync=" .. tostring(hasTSync) .. " TutorialStepComplete=" .. tostring(hasTSC) .. ")")
end

-- 4. TutorialGui
local gui = SG:FindFirstChild("TutorialGui")
if gui and gui:FindFirstChild("Tooltip") and gui:FindFirstChild("Dimmer") and gui:FindFirstChild("Arrow") then
    table.insert(results, "✅ TutorialGui: Tooltip + Dimmer + Arrow present")
else
    table.insert(issues, "❌ TutorialGui missing or incomplete")
end

-- 5. TutorialController
local ctrl = SPS and SPS:FindFirstChild("TutorialController")
if ctrl and ctrl:IsA("LocalScript") then
    table.insert(results, "✅ TutorialController LocalScript present")
else
    table.insert(issues, "❌ TutorialController missing")
end

-- 6. Main Script wiring
local main = SSS:FindFirstChild("Main") or SSS:FindFirstChild("GameManager")
if main and main.Source:find("TutorialService") then
    table.insert(results, "✅ Main Script references TutorialService")
else
    table.insert(issues, "⚠ Main Script does not reference TutorialService")
end

print("\n=== DISPATCH 35 VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\nISSUES:")
    for _, i in issues do print(i) end
else
    print("\n🎉 All checks passed — dispatch 35 complete!")
    print("   First-time players will see 4-step guided tooltip on first join")
    print("   Returning players (tutorialComplete=true) see nothing")
end
```

---

## Execution order checklist

1. ☐ **STEP A** — Add Config.TUTORIAL_STEPS  
2. ☐ **STEP B** — Create TutorialService ModuleScript  
3. ☐ **STEP C** — Create TutorialSync + TutorialStepComplete remotes  
4. ☐ **STEP D** — Create TutorialGui ScreenGui  
5. ☐ **STEP E** — Create TutorialController LocalScript  
6. ☐ **STEP F** — Wire TutorialService.Init() into Main Script  
7. ☐ **STEP G** — Full verification  

---

## Testing notes

- **Reset tutorial flag in Command Bar** (while in play-test, to re-trigger):
  ```lua
  local SSS = game:GetService("ServerScriptService")
  local DS  = require(SSS:FindFirstChild("DataService"))
  local p   = game:GetService("Players"):GetPlayers()[1]
  local prof = DS.GetProfile(p)
  prof.tutorialComplete = false
  prof.completedSteps   = {}
  DS.SaveProfile(p)
  print("Tutorial reset — rejoin to see it again")
  ```

- **Step advancement:** In play-test, clicking any GuiButton whose Name matches the step's
  `arrow` field advances the tutorial. Clicking "TabBuild" advances step 1, etc.

- **Skip button:** Always visible — allows experienced players or testers to dismiss immediately.

---

## Part budget

| Step | Parts added | Running total |
|------|-------------|---------------|
| All  | 0 (UI frames only) | 4,098 |
| **Total** | **0** | **~4,098 / 5,000** |
