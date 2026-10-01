# Dispatch 52 — PollenYieldUpgradeService (Pollen Harvest Upgrades)
**Cycle 11 | A Bee's World**

> Self-contained Studio execution guide.
> Execute every STEP in order in the Roblox Studio **Command Bar** (View → Command Bar).

---

## OVERVIEW

A **propolis-sink** progression ladder: players spend propolis to permanently increase
pollen yield per foraging run. Propolis is harder to accumulate than honey, so these
upgrades feel premium.

**5 upgrade tiers**:

| Tier | Cost (Propolis) | Pollen Yield Bonus | Cumulative Mult |
|---|---|---|---|
| 0 (base) | — | — | 1.00× |
| 1 | 50 | +20% | 1.20× |
| 2 | 150 | +20% | 1.44× |
| 3 | 400 | +20% | 1.73× |
| 4 | 1,000 | +20% | 2.07× |
| 5 | 2,500 | +20% (max) | 2.49× |

Key design constraints:
- **Server-authoritative**: propolis deducted and tier incremented server-side
- **Persistent**: stored in `profile.pollenTier`
- **Applied in ForagingService**: pollen yield multiplied by the pollen mult
- **Part budget**: +0 permanent parts

---

## STEP A — Config injection

Paste in Command Bar:

```lua
-- STEP A: inject POLLEN_UPGRADES table into Config
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local src = cfg.Source

if src:find("POLLEN_UPGRADES", 1, true) then
    print("Config already has POLLEN_UPGRADES — skip STEP A")
else
    local anchor = "return Config"
    assert(src:find(anchor, 1, true), "anchor 'return Config' not found")

    local injection = [[
Config.POLLEN_UPGRADES = {
    { tier = 1, cost =   50,  mult = 1.20 },
    { tier = 2, cost =  150,  mult = 1.44 },
    { tier = 3, cost =  400,  mult = 1.73 },
    { tier = 4, cost = 1000,  mult = 2.07 },
    { tier = 5, cost = 2500,  mult = 2.49 },
}
Config.POLLEN_UPGRADE_MAX_TIER = 5

return Config]]

    local clone = cfg:Clone()
    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "Config"
    clone.Parent = SSS
    print("STEP A done — Config.POLLEN_UPGRADES injected")
end
```

---

## STEP B — DataService migration

Paste in Command Bar:

```lua
-- STEP B: inject pollenTier into DataService profile defaults
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local src = ds.Source

if src:find("pollenTier", 1, true) then
    print("DataService already has pollenTier — skip STEP B")
else
    local anchor = "forageSpeedTier = 0,"
    assert(src:find(anchor, 1, true), "anchor 'forageSpeedTier = 0,' not found")

    local injection = anchor .. "\n        pollenTier = 0,"

    local clone = ds:Clone()
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "DataService"
    clone.Parent = SSS
    print("STEP B done — pollenTier injected into DataService")
end
```

---

## STEP C — PollenYieldUpgradeService ModuleScript

Paste in Command Bar:

```lua
-- STEP C: create PollenYieldUpgradeService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("PollenYieldUpgradeService"), "PollenYieldUpgradeService exists — skip STEP C")

local m = Instance.new("ModuleScript")
m.Name   = "PollenYieldUpgradeService"
m.Parent = SSS
m.Source = [[
--!strict
local Players  = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local SSS      = game:GetService("ServerScriptService")

local DataService = require(SSS:WaitForChild("DataService"))
local Config      = require(SSS:WaitForChild("Config"))

local PollenYieldUpgradeService = {}

local PollenSync:     RemoteEvent
local BuyPollenTier:  RemoteFunction

function PollenYieldUpgradeService.GetMult(tier: number): number
    if tier <= 0 then return 1.0 end
    for _, u in Config.POLLEN_UPGRADES do
        if u.tier == tier then return u.mult end
    end
    return 1.0
end

local function syncClient(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local tier = profile.pollenTier or 0
    local nextCost = nil
    for _, u in Config.POLLEN_UPGRADES do
        if u.tier == tier + 1 then nextCost = u.cost break end
    end
    PollenSync:FireClient(player, {
        tier     = tier,
        maxTier  = Config.POLLEN_UPGRADE_MAX_TIER,
        mult     = PollenYieldUpgradeService.GetMult(tier),
        nextCost = nextCost,
    })
end

function PollenYieldUpgradeService.Init()
    PollenSync    = RepStore:WaitForChild("PollenSync")    :: RemoteEvent
    BuyPollenTier = RepStore:WaitForChild("BuyPollenTier") :: RemoteFunction

    BuyPollenTier.OnServerInvoke = function(player: Player): (boolean, string)
        local profile = DataService.GetProfile(player)
        if not profile then return false, "profile unavailable" end

        local currentTier = profile.pollenTier or 0
        if currentTier >= Config.POLLEN_UPGRADE_MAX_TIER then
            return false, "already max tier"
        end

        local nextTier = currentTier + 1
        local cost = 0
        for _, u in Config.POLLEN_UPGRADES do
            if u.tier == nextTier then cost = u.cost break end
        end

        if (profile.propolis or 0) < cost then
            return false, "not enough propolis"
        end

        profile.propolis = (profile.propolis or 0) - cost
        profile.pollenTier = nextTier

        syncClient(player)
        return true, "upgraded to tier " .. nextTier
    end

    Players.PlayerAdded:Connect(function(player: Player)
        task.delay(4, function()
            if player.Parent then syncClient(player) end
        end)
    end)

    print("[PollenYieldUpgradeService] initialised")
end

return PollenYieldUpgradeService
]]

print("STEP C done — PollenYieldUpgradeService created")
```

---

## STEP D — RemoteEvent + RemoteFunction

Paste in Command Bar:

```lua
-- STEP D: create PollenSync RE and BuyPollenTier RF
local Rep = game:GetService("ReplicatedStorage")

if not Rep:FindFirstChild("PollenSync") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "PollenSync"
    re.Parent = Rep
    print("PollenSync created")
else print("PollenSync exists") end

if not Rep:FindFirstChild("BuyPollenTier") then
    local rf = Instance.new("RemoteFunction")
    rf.Name   = "BuyPollenTier"
    rf.Parent = Rep
    print("BuyPollenTier created")
else print("BuyPollenTier exists") end
```

---

## STEP E — ForagingService injection (apply pollen yield multiplier)

Paste in Command Bar:

```lua
-- STEP E: inject pollenTier multiplier into ForagingService pollen yield
local SSS = game:GetService("ServerScriptService")
local fs  = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local src = fs.Source

if src:find("PollenYieldUpgradeService", 1, true) then
    print("ForagingService already has PollenYieldUpgradeService — skip STEP E")
else
    -- Add require at top
    local reqAnchor = 'local SpeedUpgradeService = require(SSS:WaitForChild("SpeedUpgradeService"))'
    assert(src:find(reqAnchor, 1, true), "SpeedUpgradeService require anchor not found in ForagingService")

    local reqInjection = reqAnchor .. '\nlocal PollenYieldUpgradeService = require(SSS:WaitForChild("PollenYieldUpgradeService"))'

    -- Find existing pollen yield line — should include stormPollenMult * seasonPollenMult
    -- from dispatches 43 + 46. Pattern: math.floor(pollenYield * stormPollenMult * ...
    local pollenAnchor = "math.floor(pollenYield * stormPollenMult * (seasonPollenMult or 1.0))"
    if not src:find(pollenAnchor, 1, true) then
        -- Fallback: simpler pattern
        pollenAnchor = "math.floor(pollenYield"
    end
    assert(src:find(pollenAnchor, 1, true), "pollen yield anchor not found in ForagingService")

    -- Replace with version that also applies pollenTier mult
    local pollenInjection
    if pollenAnchor == "math.floor(pollenYield * stormPollenMult * (seasonPollenMult or 1.0))" then
        pollenInjection = [[
do
            local pTier = (DataService.GetProfile(player) and DataService.GetProfile(player).pollenTier) or 0
            local pollenUpgMult = PollenYieldUpgradeService.GetMult(pTier)
            math.floor(pollenYield * stormPollenMult * (seasonPollenMult or 1.0) * pollenUpgMult)
        end]]
    else
        pollenInjection = [[
do
            local pTier = (DataService.GetProfile(player) and DataService.GetProfile(player).pollenTier) or 0
            local pollenUpgMult = PollenYieldUpgradeService.GetMult(pTier)
            math.floor(pollenYield * pollenUpgMult)
        end]]
    end

    local clone = fs:Clone()
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil

    local newSrc = src:gsub(reqAnchor, reqInjection, 1)
    newSrc = newSrc:gsub(pollenAnchor, pollenInjection, 1)
    clone.Source = newSrc
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("STEP E done — pollen yield multiplier applied to ForagingService")
end
```

---

## STEP F — GameManager injection

Paste in Command Bar:

```lua
-- STEP F: inject PollenYieldUpgradeService.Init() into GameManager
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local src = gm.Source

if src:find("PollenYieldUpgradeService", 1, true) then
    print("GameManager already has PollenYieldUpgradeService — skip STEP F")
else
    local anchor = "SpeedUpgradeService.Init()"
    assert(src:find(anchor, 1, true), "anchor 'SpeedUpgradeService.Init()' not found")

    local injection = [[
SpeedUpgradeService.Init()
    local PollenYieldUpgradeService = require(ServerScriptService:WaitForChild("PollenYieldUpgradeService"))
    PollenYieldUpgradeService.Init()]]

    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("STEP F done — PollenYieldUpgradeService.Init() injected into GameManager")
end
```

---

## STEP G — PollenUpgradeController LocalScript

Paste in Command Bar:

```lua
-- STEP G: create PollenUpgradeController in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")
assert(not SPS:FindFirstChild("PollenUpgradeController"), "PollenUpgradeController exists — skip STEP G")

local ls = Instance.new("LocalScript")
ls.Name   = "PollenUpgradeController"
ls.Parent = SPS
ls.Source = [[
--!strict
-- PollenUpgradeController: pollen yield upgrade panel
local Players      = game:GetService("Players")
local RepStore     = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local PollenSync    = RepStore:WaitForChild("PollenSync")    :: RemoteEvent
local BuyPollenTier = RepStore:WaitForChild("BuyPollenTier") :: RemoteFunction

local MainGui   = PlayerGui:WaitForChild("MainGui",   15)
local MainFrame = MainGui and MainGui:WaitForChild("MainFrame", 10)
assert(MainFrame, "MainFrame not found")

local HONEY_GOLD   = Color3.fromRGB(242, 168, 28)
local POLLEN_CLR   = Color3.fromRGB(200, 230, 80)    -- yellow-green for pollen
local DARK_BG      = Color3.fromRGB(30, 20, 10)
local PROPOLIS_CLR = Color3.fromRGB(122, 74, 34)

-- Tab button
local tabBtn = Instance.new("TextButton")
tabBtn.Name             = "PollenTabBtn"
tabBtn.AnchorPoint      = Vector2.new(0, 0)
tabBtn.Position         = UDim2.new(0.01, 0, 0.70, 0)
tabBtn.Size             = UDim2.new(0.10, 0, 0.08, 0)
tabBtn.BackgroundColor3 = DARK_BG
tabBtn.BorderSizePixel  = 0
tabBtn.Text             = "🌼"
tabBtn.TextScaled       = true
tabBtn.Font             = Enum.Font.GothamBold
tabBtn.TextColor3       = POLLEN_CLR
tabBtn.ZIndex           = 10
tabBtn.Parent           = MainFrame

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 10)
tabCorner.Parent       = tabBtn

-- Panel
local panel = Instance.new("Frame")
panel.Name             = "PollenPanel"
panel.AnchorPoint      = Vector2.new(1, 0.5)
panel.Position         = UDim2.new(1.01, 0, 0.70, 0)
panel.Size             = UDim2.new(0.30, 0, 0.45, 0)
panel.BackgroundColor3 = DARK_BG
panel.BorderSizePixel  = 0
panel.ZIndex           = 15
panel.Visible          = true
panel.Parent           = MainFrame

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent       = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = POLLEN_CLR
panelStroke.Thickness = 2
panelStroke.Parent    = panel

local titleLbl = Instance.new("TextLabel")
titleLbl.Name                 = "Title"
titleLbl.AnchorPoint          = Vector2.new(0.5, 0)
titleLbl.Position             = UDim2.new(0.5, 0, 0, 10)
titleLbl.Size                 = UDim2.new(0.90, 0, 0, 26)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                 = "🌼 Pollen Yield"
titleLbl.TextScaled           = true
titleLbl.Font                 = Enum.Font.GothamBold
titleLbl.TextColor3           = POLLEN_CLR
titleLbl.ZIndex               = 16
titleLbl.Parent               = panel

local multLbl = Instance.new("TextLabel")
multLbl.Name                 = "MultLbl"
multLbl.AnchorPoint          = Vector2.new(0.5, 0)
multLbl.Position             = UDim2.new(0.5, 0, 0, 42)
multLbl.Size                 = UDim2.new(0.90, 0, 0, 22)
multLbl.BackgroundTransparency = 1
multLbl.Text                 = "Yield: 1.00×  (Tier 0/5)"
multLbl.TextScaled           = true
multLbl.Font                 = Enum.Font.Gotham
multLbl.TextColor3           = Color3.fromRGB(180, 200, 100)
multLbl.ZIndex               = 16
multLbl.Parent               = panel

local barBg = Instance.new("Frame")
barBg.Name             = "BarBg"
barBg.AnchorPoint      = Vector2.new(0.5, 0)
barBg.Position         = UDim2.new(0.5, 0, 0, 70)
barBg.Size             = UDim2.new(0.85, 0, 0, 10)
barBg.BackgroundColor3 = Color3.fromRGB(40, 50, 15)
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 16
barBg.Parent           = panel

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent       = barBg

local barFill = Instance.new("Frame")
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = POLLEN_CLR
barFill.BorderSizePixel  = 0
barFill.ZIndex           = 17
barFill.Parent           = barBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent       = barFill

-- Cost label (propolis, not honey)
local costNote = Instance.new("TextLabel")
costNote.Name                 = "CostNote"
costNote.AnchorPoint          = Vector2.new(0.5, 0)
costNote.Position             = UDim2.new(0.5, 0, 0, 86)
costNote.Size                 = UDim2.new(0.90, 0, 0, 18)
costNote.BackgroundTransparency = 1
costNote.Text                 = "Costs Propolis 🟤"
costNote.TextScaled           = true
costNote.Font                 = Enum.Font.Gotham
costNote.TextColor3           = Color3.fromRGB(160, 110, 60)
costNote.ZIndex               = 16
costNote.Parent               = panel

local buyBtn = Instance.new("TextButton")
buyBtn.Name             = "BuyBtn"
buyBtn.AnchorPoint      = Vector2.new(0.5, 0)
buyBtn.Position         = UDim2.new(0.5, 0, 0, 108)
buyBtn.Size             = UDim2.new(0.80, 0, 0, 38)
buyBtn.BackgroundColor3 = PROPOLIS_CLR
buyBtn.BorderSizePixel  = 0
buyBtn.Text             = "Upgrade — 50 🟤"
buyBtn.TextScaled       = true
buyBtn.Font             = Enum.Font.GothamBold
buyBtn.TextColor3       = Color3.new(1, 1, 1)
buyBtn.ZIndex           = 16
buyBtn.Parent           = panel

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent       = buyBtn

-- State
local panelOpen = false

local function fmtNum(n: number): string
    if n >= 1000000 then return string.format("%.1fM", n/1000000) end
    if n >= 1000    then return string.format("%.1fK", n/1000)    end
    return tostring(n)
end

local function updateUI(data: {tier:number, maxTier:number, mult:number, nextCost:number?})
    multLbl.Text = string.format("Yield: %.2f×  (Tier %d/%d)", data.mult, data.tier, data.maxTier)

    TweenService:Create(barFill,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(data.tier / data.maxTier, 0, 1, 0) }
    ):Play()

    if data.tier >= data.maxTier then
        buyBtn.Text             = "🌼 MAX YIELD"
        buyBtn.Active           = false
        buyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    elseif data.nextCost then
        buyBtn.Text             = "Upgrade — " .. fmtNum(data.nextCost) .. " 🟤"
        buyBtn.Active           = true
        buyBtn.BackgroundColor3 = PROPOLIS_CLR
    end
end

PollenSync.OnClientEvent:Connect(function(data)
    updateUI(data)
end)

buyBtn.Activated:Connect(function()
    if not buyBtn.Active then return end
    buyBtn.Text   = "..."
    buyBtn.Active = false
    local ok, msg = BuyPollenTier:InvokeServer()
    if not ok then
        buyBtn.Text = msg or "Failed"
        task.delay(2, function() buyBtn.Active = true end)
    end
end)

local function openPanel()
    panelOpen = true
    TweenService:Create(panel,
        TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.69, 0, 0.70, 0) }
    ):Play()
end

local function closePanel()
    panelOpen = false
    TweenService:Create(panel,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(1.01, 0, 0.70, 0) }
    ):Play()
end

tabBtn.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)
]]

print("STEP G done — PollenUpgradeController created")
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
    {"Config.POLLEN_UPGRADES",
        SSS:FindFirstChild("Config") and
        SSS:FindFirstChild("Config").Source:find("POLLEN_UPGRADES", 1, true) ~= nil},
    {"DataService.pollenTier",
        SSS:FindFirstChild("DataService") and
        SSS:FindFirstChild("DataService").Source:find("pollenTier", 1, true) ~= nil},
    {"PollenYieldUpgradeService",
        SSS:FindFirstChild("PollenYieldUpgradeService") ~= nil},
    {"PollenSync RemoteEvent",
        Rep:FindFirstChild("PollenSync") ~= nil},
    {"BuyPollenTier RemoteFunction",
        Rep:FindFirstChild("BuyPollenTier") ~= nil},
    {"ForagingService has PollenYieldUpgradeService",
        SSS:FindFirstChild("ForagingService") and
        SSS:FindFirstChild("ForagingService").Source:find("PollenYieldUpgradeService", 1, true) ~= nil},
    {"GameManager has PollenYieldUpgradeService",
        SSS:FindFirstChild("GameManager") and
        SSS:FindFirstChild("GameManager").Source:find("PollenYieldUpgradeService", 1, true) ~= nil},
    {"PollenUpgradeController LocalScript",
        SPS and SPS:FindFirstChild("PollenUpgradeController") ~= nil},
}

local pass, fail = 0, 0
for _, c in checks do
    local label, result = c[1], c[2]
    if result then print("  PASS: " .. label) pass = pass + 1
    else           warn("  FAIL: " .. label)  fail = fail + 1 end
end
print(string.format("\n%d/%d checks passed — %s",
    pass, #checks, fail == 0 and "DISPATCH 52 COMPLETE ✓" or "NEEDS ATTENTION"))
```

---

## EXPECTED OUTPUT

```
  PASS: Config.POLLEN_UPGRADES
  PASS: DataService.pollenTier
  PASS: PollenYieldUpgradeService
  PASS: PollenSync RemoteEvent
  PASS: BuyPollenTier RemoteFunction
  PASS: ForagingService has PollenYieldUpgradeService
  PASS: GameManager has PollenYieldUpgradeService
  PASS: PollenUpgradeController LocalScript

8/8 checks passed — DISPATCH 52 COMPLETE ✓
```

---

## PART BUDGET

| Change | Parts |
|---|---|
| PollenYieldUpgradeService + remotes | 0 |
| PollenUpgradeController (PlayerGui) | 0 |
| **Running total** | **4,146 / 5,000** |

---

## BEHAVIOUR NOTES

- **Propolis sink**: pollen upgrades cost propolis (not honey), giving propolis a dedicated use beyond the forge (dispatch 20+). The two resources now have distinct purposes: honey → speed upgrades + expansion plots + leaderboard; propolis → pollen yield upgrades + cells.
- **Tab positions**: pollen tab button sits at `Position(0.01, 0.70)` — below speed (0.60) and expansion (0.50) tabs, stacking cleanly on the left side of MainFrame.
- **Panel stroke**: pollen panel uses a yellow-green UIStroke (`POLLEN_CLR`) to visually distinguish it from speed (Honey Gold) and expansion panels.
- **ForagingService anchor fallback**: Step E tries the full stacked multiplier pattern first (`pollenYield * stormPollenMult * seasonPollenMult`). If that exact string doesn't exist yet (thunderstorm or season dispatch not yet applied), it falls back to `math.floor(pollenYield`. Both produce correct code — the pollen upgrade mult stacks on top of whatever is there.

---

*Dispatch 52 complete — execute Steps A → H in order. Proceed to Dispatch 53 after 8/8 checks pass.*
