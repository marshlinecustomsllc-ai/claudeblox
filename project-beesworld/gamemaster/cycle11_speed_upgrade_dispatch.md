# Dispatch 51 — SpeedUpgradeService (Foraging Speed Upgrades)
**Cycle 11 | A Bee's World**

> Self-contained Studio execution guide.
> Execute every STEP in order in the Roblox Studio **Command Bar** (View → Command Bar).

---

## OVERVIEW

Players can spend honey to permanently reduce their foraging cycle time (how long it takes
bees to complete one foraging run). This creates a direct honey-sink progression ladder.

**5 upgrade tiers** — each tier reduces cycle time by 15% and costs escalating honey:

| Tier | Cost | Cycle Time Reduction | Cumulative Speed |
|---|---|---|---|
| 0 (base) | — | — | 1.00× |
| 1 | 500 | −15% | 1.18× |
| 2 | 2,000 | −15% | 1.38× |
| 3 | 8,000 | −15% | 1.63× |
| 4 | 25,000 | −15% | 1.92× |
| 5 | 75,000 | −15% (max) | 2.27× |

Key design constraints:
- **Server-authoritative**: cost deducted and tier incremented server-side
- **Persistent**: stored in `profile.forageSpeedTier`
- **Applied in ForagingService**: base cycle time is divided by the speed multiplier
- **Part budget**: +0 permanent parts

---

## DATA MODEL

New profile field:

```
profile.forageSpeedTier  number  default: 0
```

---

## STEP A — Config injection

Paste in Command Bar:

```lua
-- STEP A: inject SPEED_UPGRADES table into Config
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local src = cfg.Source

if src:find("SPEED_UPGRADES", 1, true) then
    print("Config already has SPEED_UPGRADES — skip STEP A")
else
    local anchor = "return Config"
    assert(src:find(anchor, 1, true), "anchor 'return Config' not found")

    local injection = [[
Config.SPEED_UPGRADES = {
    -- index = tier level (1..5), cost = honey to upgrade to this tier
    { tier = 1, cost =  500,   mult = 1.18 },
    { tier = 2, cost =  2000,  mult = 1.38 },
    { tier = 3, cost =  8000,  mult = 1.63 },
    { tier = 4, cost =  25000, mult = 1.92 },
    { tier = 5, cost =  75000, mult = 2.27 },
}
Config.SPEED_UPGRADE_MAX_TIER = 5

return Config]]

    local clone = cfg:Clone()
    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "Config"
    clone.Parent = SSS
    print("STEP A done — Config.SPEED_UPGRADES injected")
end
```

---

## STEP B — DataService migration

Paste in Command Bar:

```lua
-- STEP B: inject forageSpeedTier into DataService profile defaults
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local src = ds.Source

if src:find("forageSpeedTier", 1, true) then
    print("DataService already has forageSpeedTier — skip STEP B")
else
    local anchor = "seenAllSeasons = 0,"
    assert(src:find(anchor, 1, true), "anchor 'seenAllSeasons = 0,' not found")

    local injection = anchor .. "\n        forageSpeedTier = 0,"

    local clone = ds:Clone()
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "DataService"
    clone.Parent = SSS
    print("STEP B done — forageSpeedTier injected into DataService")
end
```

---

## STEP C — SpeedUpgradeService ModuleScript

Paste in Command Bar:

```lua
-- STEP C: create SpeedUpgradeService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("SpeedUpgradeService"), "SpeedUpgradeService exists — skip STEP C")

local m = Instance.new("ModuleScript")
m.Name   = "SpeedUpgradeService"
m.Parent = SSS
m.Source = [[
--!strict
local Players  = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local SSS      = game:GetService("ServerScriptService")

local DataService = require(SSS:WaitForChild("DataService"))
local Config      = require(SSS:WaitForChild("Config"))

local SpeedUpgradeService = {}

local SpeedSync:    RemoteEvent
local BuySpeedTier: RemoteFunction

-- Return the speed multiplier for a given tier (1.0 at tier 0)
function SpeedUpgradeService.GetMult(tier: number): number
    if tier <= 0 then return 1.0 end
    for _, u in Config.SPEED_UPGRADES do
        if u.tier == tier then return u.mult end
    end
    return 1.0
end

local function syncClient(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local tier = profile.forageSpeedTier or 0
    local nextCost = nil
    for _, u in Config.SPEED_UPGRADES do
        if u.tier == tier + 1 then nextCost = u.cost break end
    end
    SpeedSync:FireClient(player, {
        tier     = tier,
        maxTier  = Config.SPEED_UPGRADE_MAX_TIER,
        mult     = SpeedUpgradeService.GetMult(tier),
        nextCost = nextCost,
    })
end

function SpeedUpgradeService.Init()
    SpeedSync    = RepStore:WaitForChild("SpeedSync")    :: RemoteEvent
    BuySpeedTier = RepStore:WaitForChild("BuySpeedTier") :: RemoteFunction

    BuySpeedTier.OnServerInvoke = function(player: Player): (boolean, string)
        local profile = DataService.GetProfile(player)
        if not profile then return false, "profile unavailable" end

        local currentTier = profile.forageSpeedTier or 0
        if currentTier >= Config.SPEED_UPGRADE_MAX_TIER then
            return false, "already max tier"
        end

        local nextTier = currentTier + 1
        local cost = 0
        for _, u in Config.SPEED_UPGRADES do
            if u.tier == nextTier then cost = u.cost break end
        end

        if (profile.honey or 0) < cost then
            return false, "not enough honey"
        end

        profile.honey = (profile.honey or 0) - cost
        profile.forageSpeedTier = nextTier

        syncClient(player)
        return true, "upgraded to tier " .. nextTier
    end

    Players.PlayerAdded:Connect(function(player: Player)
        task.delay(4, function()
            if player.Parent then syncClient(player) end
        end)
    end)

    print("[SpeedUpgradeService] initialised")
end

return SpeedUpgradeService
]]

print("STEP C done — SpeedUpgradeService created")
```

---

## STEP D — RemoteEvent + RemoteFunction

Paste in Command Bar:

```lua
-- STEP D: create SpeedSync RE and BuySpeedTier RF in ReplicatedStorage
local Rep = game:GetService("ReplicatedStorage")

if not Rep:FindFirstChild("SpeedSync") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "SpeedSync"
    re.Parent = Rep
    print("SpeedSync created")
else print("SpeedSync exists") end

if not Rep:FindFirstChild("BuySpeedTier") then
    local rf = Instance.new("RemoteFunction")
    rf.Name   = "BuySpeedTier"
    rf.Parent = Rep
    print("BuySpeedTier created")
else print("BuySpeedTier exists") end
```

---

## STEP E — ForagingService injection (apply speed multiplier)

Paste in Command Bar:

```lua
-- STEP E: inject forageSpeedTier multiplier into ForagingService cycle time
local SSS = game:GetService("ServerScriptService")
local fs  = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local src = fs.Source

if src:find("SpeedUpgradeService", 1, true) then
    print("ForagingService already has SpeedUpgradeService — skip STEP E")
else
    -- Add require at top
    local reqAnchor = 'local DataService = require(SSS:WaitForChild("DataService"))'
    assert(src:find(reqAnchor, 1, true), "require anchor not found in ForagingService")

    local reqInjection = reqAnchor .. '\nlocal SpeedUpgradeService = require(SSS:WaitForChild("SpeedUpgradeService"))'

    -- Find cycle time / wait line — ForagingService uses task.wait(Config.FORAGE_CYCLE_TIME) or similar
    -- We need to divide it by the player's speed multiplier
    -- Pattern: task.wait(Config.FORAGE_CYCLE_TIME)  or  task.wait(cycleTime)
    -- Try both patterns
    local waitAnchor = "task.wait(Config.FORAGE_CYCLE_TIME)"
    if not src:find(waitAnchor, 1, true) then
        waitAnchor = "task.wait(cycleTime)"
    end
    if not src:find(waitAnchor, 1, true) then
        waitAnchor = "task.wait(forageTime)"
    end
    assert(src:find(waitAnchor, 1, true),
        "cycle time wait anchor not found in ForagingService — search for task.wait with cycle time variable")

    -- Replace with speed-scaled version
    local speedInjection = [[
do
            local tier = (DataService.GetProfile(player) and DataService.GetProfile(player).forageSpeedTier) or 0
            local speedMult = SpeedUpgradeService.GetMult(tier)
            local baseTime = Config.FORAGE_CYCLE_TIME
            task.wait(baseTime / speedMult)
        end]]

    local clone = fs:Clone()
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil

    local newSrc = src:gsub(reqAnchor, reqInjection, 1)
    newSrc = newSrc:gsub(waitAnchor, speedInjection, 1)
    clone.Source = newSrc
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("STEP E done — speed multiplier applied to ForagingService cycle time")
end
```

---

## STEP F — GameManager injection

Paste in Command Bar:

```lua
-- STEP F: inject SpeedUpgradeService.Init() into GameManager
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local src = gm.Source

if src:find("SpeedUpgradeService", 1, true) then
    print("GameManager already has SpeedUpgradeService — skip STEP F")
else
    local anchor = "AchievementService.Init()"
    assert(src:find(anchor, 1, true), "anchor 'AchievementService.Init()' not found")

    local injection = [[
AchievementService.Init()
    local SpeedUpgradeService = require(ServerScriptService:WaitForChild("SpeedUpgradeService"))
    SpeedUpgradeService.Init()]]

    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("STEP F done — SpeedUpgradeService.Init() injected into GameManager")
end
```

---

## STEP G — SpeedUpgradeController LocalScript

Paste in Command Bar:

```lua
-- STEP G: create SpeedUpgradeController in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")
assert(not SPS:FindFirstChild("SpeedUpgradeController"), "SpeedUpgradeController exists — skip STEP G")

local ls = Instance.new("LocalScript")
ls.Name   = "SpeedUpgradeController"
ls.Parent = SPS
ls.Source = [[
--!strict
-- SpeedUpgradeController: speed upgrade UI inside MainFrame
local Players      = game:GetService("Players")
local RepStore     = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local SpeedSync    = RepStore:WaitForChild("SpeedSync")    :: RemoteEvent
local BuySpeedTier = RepStore:WaitForChild("BuySpeedTier") :: RemoteFunction

local MainGui   = PlayerGui:WaitForChild("MainGui",   15)
local MainFrame = MainGui and MainGui:WaitForChild("MainFrame", 10)
assert(MainFrame, "MainFrame not found")

local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local DARK_BG    = Color3.fromRGB(30, 20, 10)
local MAX_TIERS  = 5

-- ── BUILD SPEED TAB BUTTON ───────────────────────────────────────────────────
local speedTabBtn = Instance.new("TextButton")
speedTabBtn.Name             = "SpeedTabBtn"
speedTabBtn.AnchorPoint      = Vector2.new(0, 0)
speedTabBtn.Position         = UDim2.new(0.01, 0, 0.60, 0)
speedTabBtn.Size             = UDim2.new(0.10, 0, 0.08, 0)
speedTabBtn.BackgroundColor3 = DARK_BG
speedTabBtn.BorderSizePixel  = 0
speedTabBtn.Text             = "⚡"
speedTabBtn.TextScaled       = true
speedTabBtn.Font             = Enum.Font.GothamBold
speedTabBtn.TextColor3       = HONEY_GOLD
speedTabBtn.ZIndex           = 10
speedTabBtn.Parent           = MainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent       = speedTabBtn

-- ── BUILD SPEED PANEL ────────────────────────────────────────────────────────
local speedPanel = Instance.new("Frame")
speedPanel.Name             = "SpeedPanel"
speedPanel.AnchorPoint      = Vector2.new(1, 0.5)
speedPanel.Position         = UDim2.new(1.01, 0, 0.60, 0)
speedPanel.Size             = UDim2.new(0.30, 0, 0.45, 0)
speedPanel.BackgroundColor3 = DARK_BG
speedPanel.BorderSizePixel  = 0
speedPanel.ZIndex           = 15
speedPanel.Visible          = true
speedPanel.Parent           = MainFrame

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent       = speedPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD
panelStroke.Thickness = 2
panelStroke.Parent    = speedPanel

-- Title
local titleLbl = Instance.new("TextLabel")
titleLbl.Name                 = "Title"
titleLbl.AnchorPoint          = Vector2.new(0.5, 0)
titleLbl.Position             = UDim2.new(0.5, 0, 0, 10)
titleLbl.Size                 = UDim2.new(0.90, 0, 0, 26)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                 = "⚡ Forage Speed"
titleLbl.TextScaled           = true
titleLbl.Font                 = Enum.Font.GothamBold
titleLbl.TextColor3           = HONEY_GOLD
titleLbl.ZIndex               = 16
titleLbl.Parent               = speedPanel

-- Current speed label
local speedLbl = Instance.new("TextLabel")
speedLbl.Name                 = "SpeedLbl"
speedLbl.AnchorPoint          = Vector2.new(0.5, 0)
speedLbl.Position             = UDim2.new(0.5, 0, 0, 42)
speedLbl.Size                 = UDim2.new(0.90, 0, 0, 22)
speedLbl.BackgroundTransparency = 1
speedLbl.Text                 = "Speed: 1.00×  (Tier 0/5)"
speedLbl.TextScaled           = true
speedLbl.Font                 = Enum.Font.Gotham
speedLbl.TextColor3           = Color3.fromRGB(200, 180, 120)
speedLbl.ZIndex               = 16
speedLbl.Parent               = speedPanel

-- Progress bar showing tier progress
local barBg = Instance.new("Frame")
barBg.Name             = "BarBg"
barBg.AnchorPoint      = Vector2.new(0.5, 0)
barBg.Position         = UDim2.new(0.5, 0, 0, 70)
barBg.Size             = UDim2.new(0.85, 0, 0, 10)
barBg.BackgroundColor3 = Color3.fromRGB(50, 35, 15)
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 16
barBg.Parent           = speedPanel

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent       = barBg

local barFill = Instance.new("Frame")
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = HONEY_GOLD
barFill.BorderSizePixel  = 0
barFill.ZIndex           = 17
barFill.Parent           = barBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent       = barFill

-- Buy button
local buyBtn = Instance.new("TextButton")
buyBtn.Name             = "BuyBtn"
buyBtn.AnchorPoint      = Vector2.new(0.5, 0)
buyBtn.Position         = UDim2.new(0.5, 0, 0, 90)
buyBtn.Size             = UDim2.new(0.80, 0, 0, 40)
buyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 20)
buyBtn.BorderSizePixel  = 0
buyBtn.Text             = "Upgrade — 500 🍯"
buyBtn.TextScaled       = true
buyBtn.Font             = Enum.Font.GothamBold
buyBtn.TextColor3       = Color3.new(1, 1, 1)
buyBtn.ZIndex           = 16
buyBtn.Parent           = speedPanel

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent       = buyBtn

-- ── STATE ─────────────────────────────────────────────────────────────────────
local panelOpen = false

local function fmtNum(n: number): string
    if n >= 1000000 then return string.format("%.1fM", n/1000000) end
    if n >= 1000    then return string.format("%.1fK", n/1000)    end
    return tostring(n)
end

local function updateUI(data: {tier:number, maxTier:number, mult:number, nextCost:number?})
    speedLbl.Text = string.format("Speed: %.2f×  (Tier %d/%d)", data.mult, data.tier, data.maxTier)

    local fraction = data.tier / data.maxTier
    TweenService:Create(barFill,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(fraction, 0, 1, 0) }
    ):Play()

    if data.tier >= data.maxTier then
        buyBtn.Text   = "⚡ MAX SPEED"
        buyBtn.Active = false
        buyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    elseif data.nextCost then
        buyBtn.Text   = "Upgrade — " .. fmtNum(data.nextCost) .. " 🍯"
        buyBtn.Active = true
        buyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 20)
    end
end

SpeedSync.OnClientEvent:Connect(function(data: {tier:number, maxTier:number, mult:number, nextCost:number?})
    updateUI(data)
end)

buyBtn.Activated:Connect(function()
    if not buyBtn.Active then return end
    buyBtn.Text   = "..."
    buyBtn.Active = false
    local ok, msg = BuySpeedTier:InvokeServer()
    if not ok then
        buyBtn.Text = msg or "Failed"
        task.delay(2, function() buyBtn.Active = true end)
    end
    -- SpeedSync will fire from server to update UI on success
end)

-- ── PANEL ANIMATION ───────────────────────────────────────────────────────────
local function openPanel()
    panelOpen = true
    TweenService:Create(speedPanel,
        TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.69, 0, 0.60, 0) }
    ):Play()
end

local function closePanel()
    panelOpen = false
    TweenService:Create(speedPanel,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(1.01, 0, 0.60, 0) }
    ):Play()
end

speedTabBtn.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)
]]

print("STEP G done — SpeedUpgradeController created")
```

---

## STEP H — Full verification

Paste in Command Bar:

```lua
-- STEP H: full verification
local SSS = game:GetService("ServerScriptService")
local Rep = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {
    {"Config.SPEED_UPGRADES",
        SSS:FindFirstChild("Config") and
        SSS:FindFirstChild("Config").Source:find("SPEED_UPGRADES", 1, true) ~= nil},
    {"DataService.forageSpeedTier",
        SSS:FindFirstChild("DataService") and
        SSS:FindFirstChild("DataService").Source:find("forageSpeedTier", 1, true) ~= nil},
    {"SpeedUpgradeService",
        SSS:FindFirstChild("SpeedUpgradeService") ~= nil},
    {"SpeedSync RemoteEvent",
        Rep:FindFirstChild("SpeedSync") ~= nil},
    {"BuySpeedTier RemoteFunction",
        Rep:FindFirstChild("BuySpeedTier") ~= nil},
    {"ForagingService has SpeedUpgradeService",
        SSS:FindFirstChild("ForagingService") and
        SSS:FindFirstChild("ForagingService").Source:find("SpeedUpgradeService", 1, true) ~= nil},
    {"GameManager has SpeedUpgradeService",
        SSS:FindFirstChild("GameManager") and
        SSS:FindFirstChild("GameManager").Source:find("SpeedUpgradeService", 1, true) ~= nil},
    {"SpeedUpgradeController LocalScript",
        SPS and SPS:FindFirstChild("SpeedUpgradeController") ~= nil},
}

local pass, fail = 0, 0
for _, c in checks do
    local label, result = c[1], c[2]
    if result then print("  PASS: " .. label) pass = pass + 1
    else           warn("  FAIL: " .. label)  fail = fail + 1 end
end
print(string.format("\n%d/%d checks passed — %s",
    pass, #checks, fail == 0 and "DISPATCH 51 COMPLETE ✓" or "NEEDS ATTENTION"))
```

---

## EXPECTED OUTPUT

```
  PASS: Config.SPEED_UPGRADES
  PASS: DataService.forageSpeedTier
  PASS: SpeedUpgradeService
  PASS: SpeedSync RemoteEvent
  PASS: BuySpeedTier RemoteFunction
  PASS: ForagingService has SpeedUpgradeService
  PASS: GameManager has SpeedUpgradeService
  PASS: SpeedUpgradeController LocalScript

8/8 checks passed — DISPATCH 51 COMPLETE ✓
```

---

## PART BUDGET

| Change | Parts |
|---|---|
| SpeedUpgradeService + remotes | 0 |
| SpeedUpgradeController (UI panels, PlayerGui) | 0 |
| **Running total** | **4,146 / 5,000** |

---

## BEHAVIOUR NOTES

- **Speed formula**: `actualCycleTime = Config.FORAGE_CYCLE_TIME / speedMult`. At tier 5 (2.27×), the cycle runs ~56% faster than base.
- **Honey sink design**: costs escalate steeply (500 → 2K → 8K → 25K → 75K). Total spend to max is 110,500 honey — achievable only by dedicated players who've also unlocked expansion plots.
- **BuySpeedTier no-arg RF**: the server already knows the player's current tier — client just says "buy next tier". No tier argument needed, preventing spoofing.
- **ForagingService cycle time anchor**: Step E searches for three patterns (`Config.FORAGE_CYCLE_TIME`, `cycleTime`, `forageTime`). If none match, the verification in STEP H will still fail (`ForagingService has SpeedUpgradeService` = FAIL). In that case: read ForagingService source, find the `task.wait(...)` line that controls forage loop timing, and manually replace it with the speed-scaled version from Step E.
- **AchievementService interaction**: SpeedUpgradeService does not need to call CheckAll — no achievement currently tracks speed tier. Future dispatch can add a `speed_max` achievement.

---

*Dispatch 51 complete — execute Steps A → H in order. Proceed to Dispatch 52 after 8/8 checks pass.*
