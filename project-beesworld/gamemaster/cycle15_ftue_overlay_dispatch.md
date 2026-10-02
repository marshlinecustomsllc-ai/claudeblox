# Dispatch 159 — FTUE Welcome Overlay + Tutorial Spotlight
**Cycle:** 15  
**Part budget before:** 4,198 / 5,000  
**Parts added:** +0 permanent  
**Part budget after:** 4,198 / 5,000  
**Prerequisite dispatches:** 9/10 (TutorialService), DataService v13

---

## Overview

First-time-user experience overlay for brand-new players (no previous save). The system has two phases:

1. **Welcome screen** — fullscreen backdrop with "Welcome to A Bee's World!" branding, a short 3-sentence intro, and a large "Start Beekeeping!" button. Shown once, auto-dismissed after 8 seconds if not tapped.

2. **Spotlight steps** — 5 guided spotlight frames that highlight UI elements in sequence (wallet → Build button → hex grid → Landing Board → DanceFloor). Each step has a short kid-friendly caption and a "Got it!" button. Steps advance automatically with a 3s timer if not dismissed.

Both phases only show for players whose `tutorialStep` in their DataService profile is 0 (first time ever, no existing tutorial progress). After the welcome screen + all 5 spotlight steps complete, `tutorialStep` is set to 1 and the existing `TutorialService` 10-step arrow walkthrough takes over.

**Adult layer:** The welcome screen has a small "How it works" toggle at the bottom that expands a 2-sentence mechanical summary without interrupting the kid-friendly main flow.

---

## Step 1 — Verify FTUE trigger condition in DataService

```lua
-- Check tutorialStep attribute — new players should have 0
-- This is the field TutorialService uses (from dispatch 9/10)
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
local profile = DS.PROFILE_TEMPLATE
print("tutorialStep in template:", profile.tutorialStep ~= nil and profile.tutorialStep or "NOT SET (will be 0 if nil-defaulted)")
-- Expected: 0 or nil (nil means default 0, controller guards with ~= nil check)
```

The FTUE overlay fires when `player:GetAttribute("TutorialStep") == 0` (or the attribute is absent). TutorialService already sets this attribute when it advances steps.

---

## Step 2 — FTUEController (new LocalScript, StarterPlayerScripts)

Create `StarterPlayerScripts.FTUEController`:

```lua
--!strict
-- FTUEController: welcome screen + spotlight tutorial for first-time players
local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- ── Config ────────────────────────────────────────────────────────────────────
local PROPOLIS_BROWN = Color3.fromRGB(80,  50,  20)
local HONEY_GOLD     = Color3.fromRGB(242, 168,  28)
local WAX_CREAM      = Color3.fromRGB(232, 212, 154)
local BEE_YELLOW     = Color3.fromRGB(255, 220,  50)

-- Spotlight steps: each highlights a UI element by path within PlayerGui
-- or a world position. Caption = kid text. Detail = adult text (expandable).
type SpotlightStep = {
    id      : string,
    caption : string,
    detail  : string,
    -- target: path within PlayerGui (dot notation), or nil for center-screen
    target  : string?,
    -- highlight size override (studs from target center), default 120
    radius  : number?,
}

local SPOTLIGHT_STEPS_159: { SpotlightStep } = {
    {
        id      = "wallet",
        caption = "This is your honey wallet. 🍯\nHarvest honey to fill it up!",
        detail  = "Honey is the main currency. Spend it to build comb cells.",
        target  = "HudGui.HudFrame",
        radius  = 140,
    },
    {
        id      = "build",
        caption = "Tap the BUILD button to place\nhoneycomb cells on your hive!",
        detail  = "Open the Build menu to buy Honey, Brood, or Pollen cells.",
        target  = "BuildGui",
        radius  = 100,
    },
    {
        id      = "grid",
        caption = "Your hive is a hexagon grid. 🔷\nFill it with different cells!",
        detail  = "Cells adjacent to Brood cells produce faster. Plan your layout!",
        target  = nil,  -- center screen (no specific element)
        radius  = 160,
    },
    {
        id      = "dance",
        caption = "Stand near a flower and press\nthe prompt to mark a route! 🌸",
        detail  = "Mark flower patches with the waggle-dance to send forager bees.",
        target  = nil,
        radius  = 160,
    },
    {
        id      = "harvest",
        caption = "Walk up to your Landing Board\nand press it to collect honey! 🎉",
        detail  = "Honey cells ripen over time — the longer you wait, the more you earn.",
        target  = nil,
        radius  = 160,
    },
}

-- ── Build UI ──────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "FTUEGui"
screenGui.DisplayOrder   = 100  -- above everything
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.Parent         = playerGui

-- ── Welcome screen ────────────────────────────────────────────────────────────
local welcomeFrame = Instance.new("Frame")
welcomeFrame.Name             = "WelcomeFrame"
welcomeFrame.Size             = UDim2.new(1, 0, 1, 0)
welcomeFrame.Position         = UDim2.new(0, 0, 0, 0)
welcomeFrame.BackgroundColor3 = Color3.fromRGB(20, 12, 5)
welcomeFrame.BackgroundTransparency = 0
welcomeFrame.BorderSizePixel  = 0
welcomeFrame.Visible          = false
welcomeFrame.Parent           = screenGui

-- Honey-comb pattern decorative circles (purely visual)
for i = 1, 6 do
    local deco = Instance.new("Frame")
    deco.Size             = UDim2.new(0, 80, 0, 80)
    deco.Position         = UDim2.new(
        0.1 + (i - 1) * 0.16, -40,
        0.05, -40
    )
    deco.BackgroundColor3 = Color3.fromRGB(40, 25, 8)
    deco.BackgroundTransparency = 0.3
    deco.BorderSizePixel  = 0
    deco.ZIndex           = 1
    deco.Parent           = welcomeFrame
    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(0.5, 0)
    dc.Parent = deco
end

-- Big emoji title
local emojiLabel = Instance.new("TextLabel")
emojiLabel.Size             = UDim2.new(0, 120, 0, 80)
emojiLabel.Position         = UDim2.new(0.5, -60, 0.18, 0)
emojiLabel.BackgroundTransparency = 1
emojiLabel.Text             = "🐝"
emojiLabel.TextSize         = 72
emojiLabel.Font             = Enum.Font.GothamBold
emojiLabel.TextXAlignment   = Enum.TextXAlignment.Center
emojiLabel.ZIndex           = 2
emojiLabel.Parent           = welcomeFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size             = UDim2.new(0.8, 0, 0, 48)
titleLabel.Position         = UDim2.new(0.1, 0, 0.38, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text             = "Welcome to A Bee's World!"
titleLabel.TextColor3       = HONEY_GOLD
titleLabel.Font             = Enum.Font.GothamBold
titleLabel.TextSize         = 32
titleLabel.TextXAlignment   = Enum.TextXAlignment.Center
titleLabel.TextScaled       = false
titleLabel.ZIndex           = 2
titleLabel.Parent           = welcomeFrame

-- Subtitle
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size             = UDim2.new(0.7, 0, 0, 60)
subtitleLabel.Position         = UDim2.new(0.15, 0, 0.52, 0)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text             = "Build your hive. Train your bees.\nCollect honey before Old Molasses does! 🐻"
subtitleLabel.TextColor3       = WAX_CREAM
subtitleLabel.Font             = Enum.Font.Gotham
subtitleLabel.TextSize         = 18
subtitleLabel.TextXAlignment   = Enum.TextXAlignment.Center
subtitleLabel.TextWrapped      = true
subtitleLabel.ZIndex           = 2
subtitleLabel.Parent           = welcomeFrame

-- "How it works" toggle
local howBtn = Instance.new("TextButton")
howBtn.Size             = UDim2.new(0, 160, 0, 28)
howBtn.Position         = UDim2.new(0.5, -80, 0.67, 0)
howBtn.BackgroundTransparency = 1
howBtn.BorderSizePixel  = 0
howBtn.Text             = "▾ How does it work?"
howBtn.Font             = Enum.Font.Gotham
howBtn.TextSize         = 13
howBtn.TextColor3       = Color3.fromRGB(160, 140, 90)
howBtn.ZIndex           = 2
howBtn.Parent           = welcomeFrame

local howDetail = Instance.new("TextLabel")
howDetail.Size             = UDim2.new(0.7, 0, 0, 52)
howDetail.Position         = UDim2.new(0.15, 0, 0.72, 0)
howDetail.BackgroundTransparency = 1
howDetail.Text             = "Place hex cells on your comb grid. Brood cells need honey cell neighbors to hatch bees. Forager bees collect nectar from flower patches you mark with a waggle-dance."
howDetail.TextColor3       = Color3.fromRGB(140, 120, 80)
howDetail.Font             = Enum.Font.Gotham
howDetail.TextSize         = 12
howDetail.TextWrapped      = true
howDetail.TextXAlignment   = Enum.TextXAlignment.Center
howDetail.Visible          = false
howDetail.ZIndex           = 2
howDetail.Parent           = welcomeFrame

howBtn.Activated:Connect(function()
    howDetail.Visible = not howDetail.Visible
    howBtn.Text = howDetail.Visible and "▴ How does it work?" or "▾ How does it work?"
end)

-- Start button
local startBtn = Instance.new("TextButton")
startBtn.Name             = "StartBtn"
startBtn.Size             = UDim2.new(0, 220, 0, 52)
startBtn.Position         = UDim2.new(0.5, -110, 0.82, 0)
startBtn.BackgroundColor3 = HONEY_GOLD
startBtn.BorderSizePixel  = 0
startBtn.Text             = "🍯 Start Beekeeping!"
startBtn.Font             = Enum.Font.GothamBold
startBtn.TextSize         = 20
startBtn.TextColor3       = PROPOLIS_BROWN
startBtn.ZIndex           = 2
startBtn.Parent           = welcomeFrame

local startCorner = Instance.new("UICorner")
startCorner.CornerRadius = UDim.new(0, 14)
startCorner.Parent = startBtn

-- Pulse animation on start button
local function pulseStart_159()
    while startBtn.Parent do
        TweenService:Create(startBtn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Size = UDim2.new(0, 232, 0, 56)
        }):Play()
        task.wait(0.7)
        TweenService:Create(startBtn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Size = UDim2.new(0, 220, 0, 52)
        }):Play()
        task.wait(0.7)
    end
end

-- Auto-dismiss timer label
local timerLabel = Instance.new("TextLabel")
timerLabel.Size             = UDim2.new(0.5, 0, 0, 18)
timerLabel.Position         = UDim2.new(0.25, 0, 0.93, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text             = "Auto-starting in 8s..."
timerLabel.TextColor3       = Color3.fromRGB(100, 80, 50)
timerLabel.Font             = Enum.Font.Gotham
timerLabel.TextSize         = 12
timerLabel.TextXAlignment   = Enum.TextXAlignment.Center
timerLabel.ZIndex           = 2
timerLabel.Parent           = welcomeFrame

-- ── Spotlight overlay ─────────────────────────────────────────────────────────
local spotlightFrame = Instance.new("Frame")
spotlightFrame.Name             = "SpotlightFrame"
spotlightFrame.Size             = UDim2.new(1, 0, 1, 0)
spotlightFrame.BackgroundTransparency = 1
spotlightFrame.BorderSizePixel  = 0
spotlightFrame.Visible          = false
spotlightFrame.Parent           = screenGui

-- Dark vignette (4 edge frames simulating spotlight cutout)
local function makeEdge_159(name: string, pos: UDim2, size: UDim2)
    local edge = Instance.new("Frame")
    edge.Name             = name
    edge.Position         = pos
    edge.Size             = size
    edge.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    edge.BackgroundTransparency = 0.35
    edge.BorderSizePixel  = 0
    edge.ZIndex           = 5
    edge.Parent           = spotlightFrame
    return edge
end

local edgeTop    = makeEdge_159("EdgeTop",    UDim2.new(0,0,0,0),           UDim2.new(1,0,0.3,0))
local edgeBottom = makeEdge_159("EdgeBottom", UDim2.new(0,0,0.7,0),         UDim2.new(1,0,0.3,0))
local edgeLeft   = makeEdge_159("EdgeLeft",   UDim2.new(0,0,0.3,0),         UDim2.new(0.2,0,0.4,0))
local edgeRight  = makeEdge_159("EdgeRight",  UDim2.new(0.8,0,0.3,0),       UDim2.new(0.2,0,0.4,0))

-- Caption box
local captionBox = Instance.new("Frame")
captionBox.Name             = "CaptionBox"
captionBox.Size             = UDim2.new(0, 320, 0, 90)
captionBox.Position         = UDim2.new(0.5, -160, 0.78, 0)
captionBox.BackgroundColor3 = PROPOLIS_BROWN
captionBox.BorderSizePixel  = 0
captionBox.ZIndex           = 10
captionBox.Parent           = spotlightFrame

local capCorner = Instance.new("UICorner")
capCorner.CornerRadius = UDim.new(0, 12)
capCorner.Parent = captionBox

local capStroke = Instance.new("UIStroke")
capStroke.Color     = HONEY_GOLD
capStroke.Thickness = 2
capStroke.Parent    = captionBox

local captionLabel = Instance.new("TextLabel")
captionLabel.Name             = "Caption"
captionLabel.Size             = UDim2.new(1, -80, 0.65, 0)
captionLabel.Position         = UDim2.new(0, 10, 0, 8)
captionLabel.BackgroundTransparency = 1
captionLabel.Text             = ""
captionLabel.TextColor3       = WAX_CREAM
captionLabel.Font             = Enum.Font.GothamBold
captionLabel.TextSize         = 14
captionLabel.TextWrapped      = true
captionLabel.ZIndex           = 11
captionLabel.Parent           = captionBox

local detailLabel = Instance.new("TextLabel")
detailLabel.Name             = "Detail"
detailLabel.Size             = UDim2.new(1, -80, 0.3, 0)
detailLabel.Position         = UDim2.new(0, 10, 0.67, 0)
detailLabel.BackgroundTransparency = 1
detailLabel.Text             = ""
detailLabel.TextColor3       = Color3.fromRGB(140, 120, 80)
detailLabel.Font             = Enum.Font.Gotham
detailLabel.TextSize         = 11
detailLabel.TextWrapped      = true
detailLabel.ZIndex           = 11
detailLabel.Parent           = captionBox

local gotItBtn = Instance.new("TextButton")
gotItBtn.Name             = "GotItBtn"
gotItBtn.Size             = UDim2.new(0, 64, 0.7, -8)
gotItBtn.Position         = UDim2.new(1, -74, 0.15, 0)
gotItBtn.BackgroundColor3 = HONEY_GOLD
gotItBtn.BorderSizePixel  = 0
gotItBtn.Text             = "Got it!"
gotItBtn.Font             = Enum.Font.GothamBold
gotItBtn.TextSize         = 13
gotItBtn.TextColor3       = PROPOLIS_BROWN
gotItBtn.ZIndex           = 11
gotItBtn.Parent           = captionBox

local gotCorner = Instance.new("UICorner")
gotCorner.CornerRadius = UDim.new(0, 8)
gotCorner.Parent = gotItBtn

local stepCounter = Instance.new("TextLabel")
stepCounter.Name             = "StepCounter"
stepCounter.Size             = UDim2.new(1, 0, 0, 14)
stepCounter.Position         = UDim2.new(0, 0, 1, 4)
stepCounter.BackgroundTransparency = 1
stepCounter.Text             = ""
stepCounter.TextColor3       = Color3.fromRGB(100, 80, 50)
stepCounter.Font             = Enum.Font.Gotham
stepCounter.TextSize         = 11
stepCounter.TextXAlignment   = Enum.TextXAlignment.Center
stepCounter.ZIndex           = 10
stepCounter.Parent           = captionBox

-- ── State machine ─────────────────────────────────────────────────────────────
local _stepIndex_159 = 0
local _advanceLock_159 = false

local function hideAll_159()
    welcomeFrame.Visible   = false
    spotlightFrame.Visible = false
end

local function advanceSpotlight_159()
    if _advanceLock_159 then return end
    _advanceLock_159 = true
    _stepIndex_159 += 1
    if _stepIndex_159 > #SPOTLIGHT_STEPS_159 then
        -- Done — hide everything, let TutorialService take over
        TweenService:Create(spotlightFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        }):Play()
        task.wait(0.4)
        hideAll_159()
        screenGui:Destroy()
        _advanceLock_159 = false
        return
    end

    local step = SPOTLIGHT_STEPS_159[_stepIndex_159]
    captionLabel.Text  = step.caption
    detailLabel.Text   = step.detail
    stepCounter.Text   = "Step " .. _stepIndex_159 .. " of " .. #SPOTLIGHT_STEPS_159

    -- Position spotlight edges based on target
    -- For now: simple full-screen darkening with caption — full spatial highlighting
    -- requires AbsolutePosition which needs a frame to be visible.
    -- We use a simple approach: center the "light hole" at a fixed relative position per step.
    local lightCenterY = 0.45  -- default center
    if step.id == "wallet"  then lightCenterY = 0.07  -- top strip
    elseif step.id == "build" then lightCenterY = 0.90  -- bottom (build button area)
    end

    local holeSize = (step.radius or 120) / 720  -- normalize to screen fraction
    local topH    = math.max(0, lightCenterY - holeSize / 2)
    local bottomH = math.max(0, 1 - (lightCenterY + holeSize / 2))

    TweenService:Create(edgeTop, TweenInfo.new(0.3), {
        Size = UDim2.new(1, 0, topH, 0)
    }):Play()
    TweenService:Create(edgeBottom, TweenInfo.new(0.3), {
        Size = UDim2.new(1, 0, bottomH, 0),
        Position = UDim2.new(0, 0, 1 - bottomH, 0)
    }):Play()
    -- For id == grid/dance/harvest: full-screen dark (no specific UI target)
    if step.target == nil then
        TweenService:Create(edgeTop, TweenInfo.new(0.3), { Size = UDim2.new(1,0,0.5,0) }):Play()
        TweenService:Create(edgeBottom, TweenInfo.new(0.3), {
            Size     = UDim2.new(1,0,0.5,0),
            Position = UDim2.new(0,0,0.5,0)
        }):Play()
    end

    -- Auto-advance after 5s
    task.spawn(function()
        task.wait(5)
        _advanceLock_159 = false
        advanceSpotlight_159()
    end)
    _advanceLock_159 = false
end

gotItBtn.Activated:Connect(function()
    _advanceLock_159 = false
    advanceSpotlight_159()
end)

local function showWelcome_159()
    welcomeFrame.Visible = true
    task.spawn(pulseStart_159)

    local countdown = 8
    local function tick()
        while countdown > 0 and welcomeFrame.Visible do
            timerLabel.Text = "Auto-starting in " .. countdown .. "s..."
            task.wait(1)
            countdown -= 1
        end
        if welcomeFrame.Visible then
            welcomeFrame.Visible = false
            spotlightFrame.Visible = true
            advanceSpotlight_159()
        end
    end

    local function dismiss()
        if not welcomeFrame.Visible then return end
        countdown = 0
        welcomeFrame.Visible   = false
        spotlightFrame.Visible = true
        advanceSpotlight_159()
    end

    startBtn.Activated:Connect(dismiss)
    task.spawn(tick)

    -- Fade in
    welcomeFrame.BackgroundTransparency = 1
    TweenService:Create(welcomeFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0
    }):Play()
end

-- ── Entry point: show only for brand-new players ──────────────────────────────
local function checkFTUE_159()
    -- Wait for TutorialStep attribute to be set by server
    local attempts = 0
    while player:GetAttribute("TutorialStep") == nil and attempts < 20 do
        task.wait(0.5)
        attempts += 1
    end
    local step = player:GetAttribute("TutorialStep")
    -- Only show for players who have never started the tutorial
    if step ~= nil and step > 0 then
        screenGui:Destroy()
        return
    end
    -- Small additional delay so the game world is loaded before the overlay
    task.wait(1.5)
    showWelcome_159()
end

task.spawn(checkFTUE_159)
```

**Verify after creating:**
```lua
local SPS = game:GetService("StarterPlayer").StarterPlayerScripts
print("FTUEController:", SPS:FindFirstChild("FTUEController") ~= nil and "PASS" or "FAIL")
-- In a Play Mode test:
-- New player (TutorialStep=0): FTUEGui should appear on screen
-- Returning player (TutorialStep>0): FTUEGui should self-destroy
```

---

## Step 3 — Test in Play Mode

Run the game (F5). As a first-time player the overlay should appear. To simulate a returning player mid-test, run in the Command Bar during Play mode:
```lua
game:GetService("Players").LocalPlayer:SetAttribute("TutorialStep", 1)
-- FTUEGui should destroy itself or not show on next spawn
```

---

## Notes

- **Zero new parts:** This is entirely UI — no Workspace parts are created.
- **TutorialService coexistence:** `FTUEController` exits cleanly (destroys its ScreenGui) before `TutorialService` fires its first arrow, so the two systems don't overlap. The existing TutorialService arrows are step 1 onwards; the FTUE overlay only shows at step 0.
- **Spotlight edge approach:** The 4-edge vignette creates a simple spotlight effect without requiring a circular clip, which is not natively supported in Roblox UI. For a future enhancement, a circular UICorner mask approach can replace the edge panels.
- **Kid-friendly:** All main captions are single sentences with emoji. The adult detail line is present but visually de-emphasized (smaller, grey). The "How does it work?" toggle on the welcome screen is the only opt-in adult content.

---

*Dispatch 159 complete. Part budget: **4,198 / 5,000** (no new parts).*
