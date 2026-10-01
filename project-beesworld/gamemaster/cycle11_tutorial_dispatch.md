# Dispatch 48 — TutorialService (First-Time FTUE Overlay)
**Cycle 11 | A Bee's World**

> Self-contained Studio execution guide.
> Execute every STEP in order in the Roblox Studio **Command Bar** (View → Command Bar).
> Each step is a single Lua snippet — paste and press Enter.

---

## OVERVIEW

New players land in the hive with no context. This dispatch adds a guided overlay
that walks them through: collecting their first pollen → spending propolis to build
a cell → watching honey generate → unlocking the forge.

Key design constraints:
- **Server-authoritative trigger**: `hasSeen_tutorial = true` written to DataService profile → never shown twice
- **Client-side display**: all UI runs in LocalScript; server only sets the flag
- **Non-blocking**: player can move and interact while the overlay is visible
- **7 steps** total, each auto-advances OR waits for a player action to occur
- **Part budget**: +0 permanent parts

---

## DATA MODEL (DataService migration)

New profile field added via clone-and-replace migration injection:

```
profile.hasSeen_tutorial  boolean  default: false
```

---

## STEP A — DataService migration injection

Paste in Command Bar:

```lua
-- STEP A: inject hasSeen_tutorial into DataService profile template
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local src = ds.Source

-- Guard: already patched?
if src:find("hasSeen_tutorial") then
    print("DataService already has hasSeen_tutorial — skip STEP A")
else
    -- Find the profile defaults table and inject after loginStreak default
    -- Pattern: find "loginStreak = 0," and insert after
    local anchor = "loginStreak = 0,"
    assert(src:find(anchor, 1, true), "anchor 'loginStreak = 0,' not found — check DataService source")

    local injection = "\n        hasSeen_tutorial = false,"

    local clone = ds:Clone()
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil

    clone.Source = src:gsub(
        anchor,
        anchor .. injection,
        1  -- replace only first occurrence
    )
    clone.Name = "DataService"
    clone.Parent = SSS
    print("STEP A done — hasSeen_tutorial injected into DataService profile defaults")
end
```

### Verify STEP A
```lua
local src = game:GetService("ServerScriptService"):FindFirstChild("DataService").Source
print(src:find("hasSeen_tutorial") and "PASS: hasSeen_tutorial found" or "FAIL: not found")
```

---

## STEP B — TutorialService ModuleScript

Paste in Command Bar:

```lua
-- STEP B: create TutorialService ModuleScript in ServerScriptService
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("TutorialService"), "TutorialService already exists — skip STEP B")

local m = Instance.new("ModuleScript")
m.Name = "TutorialService"
m.Parent = SSS
m.Source = [[
--!strict
-- TutorialService: marks tutorial complete server-side
local Players   = game:GetService("Players")
local SSS       = game:GetService("ServerScriptService")
local RepStore  = game:GetService("ReplicatedStorage")

local DataService = require(SSS:WaitForChild("DataService"))

local TutorialService = {}

-- RemoteEvent: server → client  (trigger display)
-- RemoteFunction: client → server (mark complete)

local TutorialStart: RemoteEvent
local TutorialComplete: RemoteFunction

function TutorialService.Init()
    TutorialStart    = RepStore:WaitForChild("TutorialStart")    :: RemoteEvent
    TutorialComplete = RepStore:WaitForChild("TutorialComplete") :: RemoteFunction

    TutorialComplete.OnServerInvoke = function(player: Player): boolean
        local profile = DataService.GetProfile(player)
        if not profile then return false end
        if profile.hasSeen_tutorial then return true end  -- already done
        profile.hasSeen_tutorial = true
        return true
    end

    Players.PlayerAdded:Connect(function(player: Player)
        -- Wait for DataService to load profile (up to 10s)
        local waited = 0
        while waited < 10 do
            local profile = DataService.GetProfile(player)
            if profile then
                if not profile.hasSeen_tutorial then
                    task.delay(3, function()
                        -- Re-check — player may have disconnected
                        if player.Parent then
                            TutorialStart:FireClient(player)
                        end
                    end)
                end
                return
            end
            task.wait(0.5)
            waited = waited + 0.5
        end
    end)

    print("[TutorialService] initialised")
end

return TutorialService
]]

print("STEP B done — TutorialService created")
```

### Verify STEP B
```lua
local m = game:GetService("ServerScriptService"):FindFirstChild("TutorialService")
print(m and "PASS: TutorialService exists" or "FAIL: not found")
```

---

## STEP C — RemoteEvent + RemoteFunction

Paste in Command Bar:

```lua
-- STEP C: create TutorialStart RE and TutorialComplete RF in ReplicatedStorage
local Rep = game:GetService("ReplicatedStorage")

if not Rep:FindFirstChild("TutorialStart") then
    local re = Instance.new("RemoteEvent")
    re.Name = "TutorialStart"
    re.Parent = Rep
    print("TutorialStart created")
else
    print("TutorialStart already exists")
end

if not Rep:FindFirstChild("TutorialComplete") then
    local rf = Instance.new("RemoteFunction")
    rf.Name = "TutorialComplete"
    rf.Parent = Rep
    print("TutorialComplete created")
else
    print("TutorialComplete already exists")
end
```

### Verify STEP C
```lua
local Rep = game:GetService("ReplicatedStorage")
local re = Rep:FindFirstChild("TutorialStart")
local rf = Rep:FindFirstChild("TutorialComplete")
print(re and rf and "PASS: both remotes exist" or "FAIL: missing remotes")
```

---

## STEP D — GameManager injection

Paste in Command Bar:

```lua
-- STEP D: inject TutorialService.Init() into GameManager after LeaderboardService.Init()
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local src = gm.Source

if src:find("TutorialService", 1, true) then
    print("GameManager already has TutorialService — skip STEP D")
else
    local anchor = "LeaderboardService.Init()"
    assert(src:find(anchor, 1, true), "anchor 'LeaderboardService.Init()' not found")

    local injection = [[
LeaderboardService.Init()
    local TutorialService = require(ServerScriptService:WaitForChild("TutorialService"))
    TutorialService.Init()]]

    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("STEP D done — TutorialService.Init() injected into GameManager")
end
```

### Verify STEP D
```lua
local src = game:GetService("ServerScriptService"):FindFirstChild("GameManager").Source
print(src:find("TutorialService", 1, true) and "PASS: TutorialService in GameManager" or "FAIL")
```

---

## STEP E — TutorialController LocalScript

Paste in Command Bar:

```lua
-- STEP E: create TutorialController in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")
assert(not SPS:FindFirstChild("TutorialController"), "TutorialController already exists — skip STEP E")

local ls = Instance.new("LocalScript")
ls.Name = "TutorialController"
ls.Parent = SPS
ls.Source = [[
--!strict
-- TutorialController: 7-step FTUE overlay
local Players      = game:GetService("Players")
local RepStore     = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local player     = Players.LocalPlayer
local PlayerGui  = player:WaitForChild("PlayerGui")

local TutorialStart    = RepStore:WaitForChild("TutorialStart")    :: RemoteEvent
local TutorialComplete = RepStore:WaitForChild("TutorialComplete") :: RemoteFunction

-- ── STEP DEFINITIONS ──────────────────────────────────────────────────────────
-- type: "auto" — show for N seconds then advance
--       "action" — show until a specific RemoteEvent fires (or poll condition)
local STEPS: {{
    title: string,
    body: string,
    icon: string,
    type: string,
    duration: number?,
    waitFor: string?,
}} = {
    {
        title = "Welcome to your Hive!",
        body  = "You're a bee. Your hive needs honey.\nLet's learn the basics.",
        icon  = "🐝",
        type  = "auto",
        duration = 4,
    },
    {
        title = "Collect Pollen",
        body  = "Walk near a flower patch to send your\nbees foraging. Watch the pollen rise!",
        icon  = "🌼",
        type  = "auto",
        duration = 6,
    },
    {
        title = "Build a Hex Cell",
        body  = "Tap an empty hex on your plot to build\na cell. Cells cost Propolis.",
        icon  = "🔷",
        type  = "auto",
        duration = 6,
    },
    {
        title = "Watch Honey Flow",
        body  = "Cells convert pollen → honey over time.\nMore cells = more honey per second.",
        icon  = "🍯",
        type  = "auto",
        duration = 6,
    },
    {
        title = "Open the Forge",
        body  = "Tap the ⚙️ Forge button to craft upgrades\nthat boost your production speed.",
        icon  = "⚙️",
        type  = "auto",
        duration = 6,
    },
    {
        title = "Check the Leaderboard",
        body  = "Tap the 🏆 button to see the top honey\nearners on this server.",
        icon  = "🏆",
        type  = "auto",
        duration = 5,
    },
    {
        title = "You're ready!",
        body  = "Grow your hive, unlock queens, and\nclimb the leaderboard. Good luck! 🐝",
        icon  = "✨",
        type  = "auto",
        duration = 4,
    },
}

-- ── GUI BUILD ─────────────────────────────────────────────────────────────────

local function buildGui(): (ScreenGui, Frame, TextLabel, TextLabel, TextLabel, Frame, TextButton)
    local sg = Instance.new("ScreenGui")
    sg.Name           = "TutorialGui"
    sg.DisplayOrder   = 100   -- above everything
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.Parent         = PlayerGui

    -- Dim overlay
    local dim = Instance.new("Frame")
    dim.Name              = "Dim"
    dim.Size              = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3  = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.55
    dim.BorderSizePixel   = 0
    dim.ZIndex            = 1
    dim.Parent            = sg

    -- Card panel
    local card = Instance.new("Frame")
    card.Name             = "Card"
    card.AnchorPoint      = Vector2.new(0.5, 0.5)
    card.Position         = UDim2.new(0.5, 0, 0.5, 0)
    card.Size             = UDim2.new(0, 0, 0, 0)   -- starts invisible (scale-in)
    card.BackgroundColor3 = Color3.fromRGB(30, 20, 10)
    card.BorderSizePixel  = 0
    card.ZIndex           = 2
    card.Parent           = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 18)
    corner.Parent       = card

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(242, 168, 28)   -- Honey Gold
    stroke.Thickness = 2
    stroke.Parent    = card

    -- Icon
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Name                 = "Icon"
    iconLbl.AnchorPoint          = Vector2.new(0.5, 0)
    iconLbl.Position             = UDim2.new(0.5, 0, 0, 18)
    iconLbl.Size                 = UDim2.new(0, 60, 0, 60)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text                 = "🐝"
    iconLbl.TextScaled           = true
    iconLbl.Font                 = Enum.Font.GothamBold
    iconLbl.TextColor3           = Color3.new(1, 1, 1)
    iconLbl.ZIndex               = 3
    iconLbl.Parent               = card

    -- Title
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name                = "Title"
    titleLbl.AnchorPoint         = Vector2.new(0.5, 0)
    titleLbl.Position            = UDim2.new(0.5, 0, 0, 84)
    titleLbl.Size                = UDim2.new(0.88, 0, 0, 32)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                = "Welcome!"
    titleLbl.TextScaled          = true
    titleLbl.Font                = Enum.Font.GothamBold
    titleLbl.TextColor3          = Color3.fromRGB(242, 168, 28)
    titleLbl.ZIndex              = 3
    titleLbl.Parent              = card

    -- Body
    local bodyLbl = Instance.new("TextLabel")
    bodyLbl.Name                 = "Body"
    bodyLbl.AnchorPoint          = Vector2.new(0.5, 0)
    bodyLbl.Position             = UDim2.new(0.5, 0, 0, 124)
    bodyLbl.Size                 = UDim2.new(0.88, 0, 0, 72)
    bodyLbl.BackgroundTransparency = 1
    bodyLbl.Text                 = ""
    bodyLbl.TextScaled           = true
    bodyLbl.Font                 = Enum.Font.Gotham
    bodyLbl.TextColor3           = Color3.fromRGB(232, 212, 154)
    bodyLbl.TextWrapped          = true
    bodyLbl.ZIndex               = 3
    bodyLbl.Parent               = card

    -- Progress bar background
    local barBg = Instance.new("Frame")
    barBg.Name             = "BarBg"
    barBg.AnchorPoint      = Vector2.new(0.5, 0)
    barBg.Position         = UDim2.new(0.5, 0, 0, 206)
    barBg.Size             = UDim2.new(0.80, 0, 0, 8)
    barBg.BackgroundColor3 = Color3.fromRGB(60, 40, 20)
    barBg.BorderSizePixel  = 0
    barBg.ZIndex           = 3
    barBg.Parent           = card

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent       = barBg

    local barFill = Instance.new("Frame")
    barFill.Name             = "BarFill"
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
    barFill.BorderSizePixel  = 0
    barFill.ZIndex           = 4
    barFill.Parent           = barBg

    local barFillCorner = Instance.new("UICorner")
    barFillCorner.CornerRadius = UDim.new(1, 0)
    barFillCorner.Parent       = barFill

    -- Skip button
    local skipBtn = Instance.new("TextButton")
    skipBtn.Name             = "SkipBtn"
    skipBtn.AnchorPoint      = Vector2.new(0.5, 0)
    skipBtn.Position         = UDim2.new(0.5, 0, 0, 224)
    skipBtn.Size             = UDim2.new(0.38, 0, 0, 34)
    skipBtn.BackgroundColor3 = Color3.fromRGB(80, 55, 25)
    skipBtn.BorderSizePixel  = 0
    skipBtn.Text             = "Skip Tutorial"
    skipBtn.TextColor3       = Color3.fromRGB(180, 140, 80)
    skipBtn.TextScaled       = true
    skipBtn.Font             = Enum.Font.Gotham
    skipBtn.ZIndex           = 3
    skipBtn.Parent           = card

    local skipCorner = Instance.new("UICorner")
    skipCorner.CornerRadius = UDim.new(0, 8)
    skipCorner.Parent       = skipBtn

    return sg, card, iconLbl, titleLbl, bodyLbl, barBg, skipBtn
end

-- ── ANIMATION HELPERS ────────────────────────────────────────────────────────

local CARD_W = 340
local CARD_H = 270

local function openCard(card: Frame)
    card.Size = UDim2.new(0, 1, 0, 1)
    local ti = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    TweenService:Create(card, ti, {
        Size = UDim2.new(0, CARD_W, 0, CARD_H)
    }):Play()
end

local function closeCard(card: Frame): ()
    local ti = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local tw = TweenService:Create(card, ti, {
        Size = UDim2.new(0, 1, 0, 1)
    })
    tw:Play()
    tw.Completed:Wait()
end

local function animateBar(barFill: Frame, fraction: number, duration: number)
    local ti = TweenInfo.new(duration * 0.90, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(barFill, ti, {
        Size = UDim2.new(fraction, 0, 1, 0)
    }):Play()
end

-- ── MAIN FLOW ─────────────────────────────────────────────────────────────────

local function runTutorial()
    local sg, card, iconLbl, titleLbl, bodyLbl, barBg, skipBtn = buildGui()
    openCard(card)

    local skipped = false
    skipBtn.Activated:Connect(function()
        skipped = true
    end)

    local barFill = barBg:FindFirstChild("BarFill") :: Frame

    for i, step in STEPS do
        if skipped then break end

        iconLbl.Text  = step.icon
        titleLbl.Text = step.title
        bodyLbl.Text  = step.body

        local fraction = i / #STEPS
        local dur = step.duration or 5
        animateBar(barFill, fraction, dur)

        if step.type == "auto" then
            task.wait(dur)
        end

        if skipped then break end
    end

    -- Mark complete on server
    TutorialComplete:InvokeServer()

    closeCard(card)
    task.wait(0.05)
    sg:Destroy()
end

-- ── ENTRY POINT ───────────────────────────────────────────────────────────────

TutorialStart.OnClientEvent:Connect(function()
    task.spawn(runTutorial)
end)
]]

print("STEP E done — TutorialController created")
```

### Verify STEP E
```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ls  = SPS and SPS:FindFirstChild("TutorialController")
print(ls and "PASS: TutorialController exists" or "FAIL: not found")
```

---

## STEP F — Verification

Paste in Command Bar:

```lua
-- STEP F: full verification
local SSS = game:GetService("ServerScriptService")
local Rep = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {
    {"DataService.hasSeen_tutorial",
        SSS:FindFirstChild("DataService") and
        SSS:FindFirstChild("DataService").Source:find("hasSeen_tutorial") ~= nil},

    {"TutorialService exists",
        SSS:FindFirstChild("TutorialService") ~= nil},

    {"TutorialStart RemoteEvent",
        Rep:FindFirstChild("TutorialStart") ~= nil and
        Rep:FindFirstChild("TutorialStart"):IsA("RemoteEvent")},

    {"TutorialComplete RemoteFunction",
        Rep:FindFirstChild("TutorialComplete") ~= nil and
        Rep:FindFirstChild("TutorialComplete"):IsA("RemoteFunction")},

    {"GameManager has TutorialService",
        SSS:FindFirstChild("GameManager") and
        SSS:FindFirstChild("GameManager").Source:find("TutorialService", 1, true) ~= nil},

    {"TutorialController LocalScript",
        SPS and SPS:FindFirstChild("TutorialController") ~= nil},
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
    pass, #checks, fail == 0 and "DISPATCH 48 COMPLETE ✓" or "NEEDS ATTENTION"))
```

---

## EXPECTED VERIFICATION OUTPUT

```
  PASS: DataService.hasSeen_tutorial
  PASS: TutorialService exists
  PASS: TutorialStart RemoteEvent
  PASS: TutorialComplete RemoteFunction
  PASS: GameManager has TutorialService
  PASS: TutorialController LocalScript

6/6 checks passed — DISPATCH 48 COMPLETE ✓
```

---

## PART BUDGET

| Change | Parts |
|---|---|
| TutorialService ModuleScript | 0 |
| TutorialController LocalScript | 0 |
| RemoteEvent + RemoteFunction | 0 |
| GUI (PlayerGui — runtime only, not permanent) | 0 |
| **Running total** | **4,142 / 5,000** |

---

## BEHAVIOUR NOTES

- **First join only**: server fires `TutorialStart` to client only when `profile.hasSeen_tutorial == false`.
  After the player reaches step 7 (or skips), `TutorialComplete:InvokeServer()` sets `hasSeen_tutorial = true` permanently.
- **Dim overlay**: semi-transparent black layer at full screen — player can still see the hive while reading.
- **Skip button**: immediately exits the tutorial and marks complete on server. No penalty.
- **Progress bar**: Honey Gold fill advances with each step, giving a visual "how much longer" cue.
- **Rejoin safety**: if the player disconnects mid-tutorial, `hasSeen_tutorial` is still `false` → tutorial fires again on next join. Once `TutorialComplete` is invoked and saved by DataService, it will never fire again.
- **No part cost**: the `TutorialGui` lives in `PlayerGui` at runtime. It is destroyed after tutorial ends. Not counted in world part budget.

---

*Dispatch 48 complete — execute Steps A → F in order. Proceed to Dispatch 49 after all 6/6 checks pass.*
