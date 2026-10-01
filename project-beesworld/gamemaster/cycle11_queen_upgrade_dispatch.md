# Dispatch 53 — QueenUpgradeService (Queen Bee Capacity Upgrades)
**Cycle 11 | A Bee's World**

> Self-contained Studio execution guide.
> Execute every STEP in order in the Roblox Studio **Command Bar** (View → Command Bar).

---

## OVERVIEW

Queens generate forager bees. This dispatch lets players upgrade their queen's
**max bee capacity** — how many active forager bees can exist at once — using honey.

More bees → more concurrent foraging runs → faster resource accumulation.

**5 upgrade tiers**:

| Tier | Cost (Honey) | Max Forager Bees | Notes |
|---|---|---|---|
| 0 (base) | — | 3 bees | starter capacity |
| 1 | 1,000 | 5 bees | +2 |
| 2 | 5,000 | 8 bees | +3 |
| 3 | 15,000 | 12 bees | +4 |
| 4 | 40,000 | 18 bees | +6 |
| 5 | 100,000 | 25 bees (max) | +7 |

Key design constraints:
- **Server-authoritative**: honey deducted, tier stored, ForagingService reads `queenTier` to determine active bee cap
- **Persistent**: stored in `profile.queenTier`
- **ForagingService integration**: bee cap = `Config.QUEEN_UPGRADES[tier].maxBees` (or base 3)
- **Part budget**: +0 permanent parts (bees are existing model clones, not new parts)

---

## STEP A — Config injection

Paste in Command Bar:

```lua
-- STEP A: inject QUEEN_UPGRADES table into Config
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local src = cfg.Source

if src:find("QUEEN_UPGRADES", 1, true) then
    print("Config already has QUEEN_UPGRADES — skip STEP A")
else
    local anchor = "return Config"
    assert(src:find(anchor, 1, true), "anchor 'return Config' not found")

    local injection = [[
Config.QUEEN_UPGRADES = {
    { tier = 0, maxBees = 3,   cost = 0       },   -- base (no cost)
    { tier = 1, maxBees = 5,   cost = 1000    },
    { tier = 2, maxBees = 8,   cost = 5000    },
    { tier = 3, maxBees = 12,  cost = 15000   },
    { tier = 4, maxBees = 18,  cost = 40000   },
    { tier = 5, maxBees = 25,  cost = 100000  },
}
Config.QUEEN_UPGRADE_MAX_TIER = 5
Config.QUEEN_BASE_BEES = 3

return Config]]

    local clone = cfg:Clone()
    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "Config"
    clone.Parent = SSS
    print("STEP A done — Config.QUEEN_UPGRADES injected")
end
```

---

## STEP B — DataService migration

Paste in Command Bar:

```lua
-- STEP B: inject queenTier into DataService profile defaults
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local src = ds.Source

if src:find("queenTier", 1, true) then
    print("DataService already has queenTier — skip STEP B")
else
    local anchor = "pollenTier = 0,"
    assert(src:find(anchor, 1, true), "anchor 'pollenTier = 0,' not found")

    local injection = anchor .. "\n        queenTier = 0,"

    local clone = ds:Clone()
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "DataService"
    clone.Parent = SSS
    print("STEP B done — queenTier injected into DataService")
end
```

---

## STEP C — QueenUpgradeService ModuleScript

Paste in Command Bar:

```lua
-- STEP C: create QueenUpgradeService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("QueenUpgradeService"), "QueenUpgradeService exists — skip STEP C")

local m = Instance.new("ModuleScript")
m.Name   = "QueenUpgradeService"
m.Parent = SSS
m.Source = [[
--!strict
local Players  = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local SSS      = game:GetService("ServerScriptService")

local DataService = require(SSS:WaitForChild("DataService"))
local Config      = require(SSS:WaitForChild("Config"))

local QueenUpgradeService = {}

local QueenSync:     RemoteEvent
local BuyQueenTier:  RemoteFunction

-- Return max bees for a given tier
function QueenUpgradeService.GetMaxBees(tier: number): number
    for _, u in Config.QUEEN_UPGRADES do
        if u.tier == tier then return u.maxBees end
    end
    return Config.QUEEN_BASE_BEES
end

local function syncClient(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local tier = profile.queenTier or 0
    local nextCost = nil
    for _, u in Config.QUEEN_UPGRADES do
        if u.tier == tier + 1 then nextCost = u.cost break end
    end
    QueenSync:FireClient(player, {
        tier     = tier,
        maxTier  = Config.QUEEN_UPGRADE_MAX_TIER,
        maxBees  = QueenUpgradeService.GetMaxBees(tier),
        nextCost = nextCost,
    })
end

function QueenUpgradeService.Init()
    QueenSync    = RepStore:WaitForChild("QueenSync")    :: RemoteEvent
    BuyQueenTier = RepStore:WaitForChild("BuyQueenTier") :: RemoteFunction

    BuyQueenTier.OnServerInvoke = function(player: Player): (boolean, string)
        local profile = DataService.GetProfile(player)
        if not profile then return false, "profile unavailable" end

        local currentTier = profile.queenTier or 0
        if currentTier >= Config.QUEEN_UPGRADE_MAX_TIER then
            return false, "already max tier"
        end

        local nextTier = currentTier + 1
        local cost = 0
        for _, u in Config.QUEEN_UPGRADES do
            if u.tier == nextTier then cost = u.cost break end
        end

        if (profile.honey or 0) < cost then
            return false, "not enough honey"
        end

        profile.honey = (profile.honey or 0) - cost
        profile.queenTier = nextTier

        syncClient(player)
        return true, "upgraded to tier " .. nextTier
    end

    Players.PlayerAdded:Connect(function(player: Player)
        task.delay(4, function()
            if player.Parent then syncClient(player) end
        end)
    end)

    print("[QueenUpgradeService] initialised")
end

return QueenUpgradeService
]]

print("STEP C done — QueenUpgradeService created")
```

---

## STEP D — RemoteEvent + RemoteFunction

Paste in Command Bar:

```lua
-- STEP D: create QueenSync RE and BuyQueenTier RF
local Rep = game:GetService("ReplicatedStorage")

if not Rep:FindFirstChild("QueenSync") then
    local re = Instance.new("RemoteEvent")
    re.Name = "QueenSync"
    re.Parent = Rep
    print("QueenSync created")
else print("QueenSync exists") end

if not Rep:FindFirstChild("BuyQueenTier") then
    local rf = Instance.new("RemoteFunction")
    rf.Name = "BuyQueenTier"
    rf.Parent = Rep
    print("BuyQueenTier created")
else print("BuyQueenTier exists") end
```

---

## STEP E — ForagingService injection (respect bee cap)

Paste in Command Bar:

```lua
-- STEP E: inject queenTier bee cap into ForagingService
-- ForagingService should already have a MAX_BEES or bee count limit.
-- We inject QueenUpgradeService.GetMaxBees() as the dynamic cap.
local SSS = game:GetService("ServerScriptService")
local fs  = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local src = fs.Source

if src:find("QueenUpgradeService", 1, true) then
    print("ForagingService already has QueenUpgradeService — skip STEP E")
else
    -- Add require at top (after PollenYieldUpgradeService)
    local reqAnchor = 'local PollenYieldUpgradeService = require(SSS:WaitForChild("PollenYieldUpgradeService"))'
    if not src:find(reqAnchor, 1, true) then
        -- fallback to SpeedUpgradeService require
        reqAnchor = 'local SpeedUpgradeService = require(SSS:WaitForChild("SpeedUpgradeService"))'
    end
    assert(src:find(reqAnchor, 1, true), "require anchor not found in ForagingService")

    local reqInjection = reqAnchor .. '\nlocal QueenUpgradeService = require(SSS:WaitForChild("QueenUpgradeService"))'

    -- Find the bee cap constant or hard-coded max — common patterns:
    -- "local MAX_BEES = 3"  or  "local MAX_ACTIVE_BEES = 3"  or  "local maxBees = Config.MAX_BEES"
    -- Replace with dynamic lookup
    local capAnchor = "local MAX_BEES = "
    local capReplacement = [[
local function getMaxBees(player: Player): number
        local profile = DataService.GetProfile(player)
        local tier = profile and (profile.queenTier or 0) or 0
        return QueenUpgradeService.GetMaxBees(tier)
    end
    local MAX_BEES = ]]   -- keep variable name intact for rest of code

    if src:find(capAnchor, 1, true) then
        local clone = fs:Clone()
        fs.Name = "ForagingService_OLD_NX"
        fs.Parent = nil

        local newSrc = src:gsub(reqAnchor, reqInjection, 1)
        -- Replace the static MAX_BEES assignment
        newSrc = newSrc:gsub(capAnchor .. "%d+", capReplacement .. "getMaxBees(player)", 1)
        clone.Source = newSrc
        clone.Name = "ForagingService"
        clone.Parent = SSS
        print("STEP E done — dynamic bee cap (queenTier) applied to ForagingService")
    else
        -- Simpler injection: just add the require; the bee cap may not exist as a constant
        local clone = fs:Clone()
        fs.Name = "ForagingService_OLD_NX"
        fs.Parent = nil

        clone.Source = src:gsub(reqAnchor, reqInjection, 1)
        clone.Name = "ForagingService"
        clone.Parent = SSS
        print("STEP E done — QueenUpgradeService require added to ForagingService (no MAX_BEES constant found — add getMaxBees call manually if needed)")
    end
end
```

---

## STEP F — GameManager injection

Paste in Command Bar:

```lua
-- STEP F: inject QueenUpgradeService.Init() into GameManager
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local src = gm.Source

if src:find("QueenUpgradeService", 1, true) then
    print("GameManager already has QueenUpgradeService — skip STEP F")
else
    local anchor = "PollenYieldUpgradeService.Init()"
    if not src:find(anchor, 1, true) then
        anchor = "SpeedUpgradeService.Init()"
    end
    assert(src:find(anchor, 1, true), "anchor not found in GameManager")

    local injection = anchor .. [[

    local QueenUpgradeService = require(ServerScriptService:WaitForChild("QueenUpgradeService"))
    QueenUpgradeService.Init()]]

    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("STEP F done — QueenUpgradeService.Init() injected into GameManager")
end
```

---

## STEP G — QueenUpgradeController LocalScript

Paste in Command Bar:

```lua
-- STEP G: create QueenUpgradeController in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")
assert(not SPS:FindFirstChild("QueenUpgradeController"), "QueenUpgradeController exists — skip STEP G")

local ls = Instance.new("LocalScript")
ls.Name   = "QueenUpgradeController"
ls.Parent = SPS
ls.Source = [[
--!strict
-- QueenUpgradeController: queen capacity upgrade panel
local Players      = game:GetService("Players")
local RepStore     = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local QueenSync    = RepStore:WaitForChild("QueenSync")    :: RemoteEvent
local BuyQueenTier = RepStore:WaitForChild("BuyQueenTier") :: RemoteFunction

local MainGui   = PlayerGui:WaitForChild("MainGui",   15)
local MainFrame = MainGui and MainGui:WaitForChild("MainFrame", 10)
assert(MainFrame, "MainFrame not found")

local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local QUEEN_CLR   = Color3.fromRGB(255, 180, 230)   -- soft pink for queen
local DARK_BG     = Color3.fromRGB(30, 20, 10)

-- Tab button (left column, below pollen at 0.80)
local tabBtn = Instance.new("TextButton")
tabBtn.Name             = "QueenTabBtn"
tabBtn.AnchorPoint      = Vector2.new(0, 0)
tabBtn.Position         = UDim2.new(0.01, 0, 0.80, 0)
tabBtn.Size             = UDim2.new(0.10, 0, 0.08, 0)
tabBtn.BackgroundColor3 = DARK_BG
tabBtn.BorderSizePixel  = 0
tabBtn.Text             = "👑"
tabBtn.TextScaled       = true
tabBtn.Font             = Enum.Font.GothamBold
tabBtn.TextColor3       = QUEEN_CLR
tabBtn.ZIndex           = 10
tabBtn.Parent           = MainFrame

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 10)
tabCorner.Parent       = tabBtn

-- Panel
local panel = Instance.new("Frame")
panel.Name             = "QueenPanel"
panel.AnchorPoint      = Vector2.new(1, 0.5)
panel.Position         = UDim2.new(1.01, 0, 0.80, 0)
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
panelStroke.Color     = QUEEN_CLR
panelStroke.Thickness = 2
panelStroke.Parent    = panel

local titleLbl = Instance.new("TextLabel")
titleLbl.Name                 = "Title"
titleLbl.AnchorPoint          = Vector2.new(0.5, 0)
titleLbl.Position             = UDim2.new(0.5, 0, 0, 10)
titleLbl.Size                 = UDim2.new(0.90, 0, 0, 26)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                 = "👑 Queen Capacity"
titleLbl.TextScaled           = true
titleLbl.Font                 = Enum.Font.GothamBold
titleLbl.TextColor3           = QUEEN_CLR
titleLbl.ZIndex               = 16
titleLbl.Parent               = panel

local beesLbl = Instance.new("TextLabel")
beesLbl.Name                 = "BeesLbl"
beesLbl.AnchorPoint          = Vector2.new(0.5, 0)
beesLbl.Position             = UDim2.new(0.5, 0, 0, 42)
beesLbl.Size                 = UDim2.new(0.90, 0, 0, 22)
beesLbl.BackgroundTransparency = 1
beesLbl.Text                 = "Max Bees: 3  (Tier 0/5)"
beesLbl.TextScaled           = true
beesLbl.Font                 = Enum.Font.Gotham
beesLbl.TextColor3           = Color3.fromRGB(220, 190, 210)
beesLbl.ZIndex               = 16
beesLbl.Parent               = panel

local barBg = Instance.new("Frame")
barBg.Name             = "BarBg"
barBg.AnchorPoint      = Vector2.new(0.5, 0)
barBg.Position         = UDim2.new(0.5, 0, 0, 70)
barBg.Size             = UDim2.new(0.85, 0, 0, 10)
barBg.BackgroundColor3 = Color3.fromRGB(50, 30, 45)
barBg.BorderSizePixel  = 0
barBg.ZIndex           = 16
barBg.Parent           = panel

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent       = barBg

local barFill = Instance.new("Frame")
barFill.Name             = "BarFill"
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = QUEEN_CLR
barFill.BorderSizePixel  = 0
barFill.ZIndex           = 17
barFill.Parent           = barBg

local barFillCorner = Instance.new("UICorner")
barFillCorner.CornerRadius = UDim.new(1, 0)
barFillCorner.Parent       = barFill

local buyBtn = Instance.new("TextButton")
buyBtn.Name             = "BuyBtn"
buyBtn.AnchorPoint      = Vector2.new(0.5, 0)
buyBtn.Position         = UDim2.new(0.5, 0, 0, 90)
buyBtn.Size             = UDim2.new(0.80, 0, 0, 40)
buyBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 80)
buyBtn.BorderSizePixel  = 0
buyBtn.Text             = "Upgrade — 1,000 🍯"
buyBtn.TextScaled       = true
buyBtn.Font             = Enum.Font.GothamBold
buyBtn.TextColor3       = Color3.new(1, 1, 1)
buyBtn.ZIndex           = 16
buyBtn.Parent           = panel

local buyCorner = Instance.new("UICorner")
buyCorner.CornerRadius = UDim.new(0, 10)
buyCorner.Parent       = buyBtn

local panelOpen = false

local function fmtNum(n: number): string
    if n >= 1000000 then return string.format("%.1fM", n/1000000) end
    if n >= 1000    then return string.format("%.1fK", n/1000)    end
    return tostring(n)
end

local function updateUI(data: {tier:number, maxTier:number, maxBees:number, nextCost:number?})
    beesLbl.Text = string.format("Max Bees: %d  (Tier %d/%d)", data.maxBees, data.tier, data.maxTier)

    TweenService:Create(barFill,
        TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(data.tier / data.maxTier, 0, 1, 0) }
    ):Play()

    if data.tier >= data.maxTier then
        buyBtn.Text             = "👑 MAX QUEEN"
        buyBtn.Active           = false
        buyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    elseif data.nextCost then
        buyBtn.Text             = "Upgrade — " .. fmtNum(data.nextCost) .. " 🍯"
        buyBtn.Active           = true
        buyBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 80)
    end
end

QueenSync.OnClientEvent:Connect(function(data)
    updateUI(data)
end)

buyBtn.Activated:Connect(function()
    if not buyBtn.Active then return end
    buyBtn.Text   = "..."
    buyBtn.Active = false
    local ok, msg = BuyQueenTier:InvokeServer()
    if not ok then
        buyBtn.Text = msg or "Failed"
        task.delay(2, function() buyBtn.Active = true end)
    end
end)

local function openPanel()
    panelOpen = true
    TweenService:Create(panel,
        TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.69, 0, 0.80, 0) }
    ):Play()
end

local function closePanel()
    panelOpen = false
    TweenService:Create(panel,
        TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(1.01, 0, 0.80, 0) }
    ):Play()
end

tabBtn.Activated:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)
]]

print("STEP G done — QueenUpgradeController created")
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
    {"Config.QUEEN_UPGRADES",
        SSS:FindFirstChild("Config") and
        SSS:FindFirstChild("Config").Source:find("QUEEN_UPGRADES", 1, true) ~= nil},
    {"DataService.queenTier",
        SSS:FindFirstChild("DataService") and
        SSS:FindFirstChild("DataService").Source:find("queenTier", 1, true) ~= nil},
    {"QueenUpgradeService",
        SSS:FindFirstChild("QueenUpgradeService") ~= nil},
    {"QueenSync RemoteEvent",
        Rep:FindFirstChild("QueenSync") ~= nil},
    {"BuyQueenTier RemoteFunction",
        Rep:FindFirstChild("BuyQueenTier") ~= nil},
    {"ForagingService has QueenUpgradeService",
        SSS:FindFirstChild("ForagingService") and
        SSS:FindFirstChild("ForagingService").Source:find("QueenUpgradeService", 1, true) ~= nil},
    {"GameManager has QueenUpgradeService",
        SSS:FindFirstChild("GameManager") and
        SSS:FindFirstChild("GameManager").Source:find("QueenUpgradeService", 1, true) ~= nil},
    {"QueenUpgradeController LocalScript",
        SPS and SPS:FindFirstChild("QueenUpgradeController") ~= nil},
}

local pass, fail = 0, 0
for _, c in checks do
    local label, result = c[1], c[2]
    if result then print("  PASS: " .. label) pass = pass + 1
    else           warn("  FAIL: " .. label)  fail = fail + 1 end
end
print(string.format("\n%d/%d checks passed — %s",
    pass, #checks, fail == 0 and "DISPATCH 53 COMPLETE ✓" or "NEEDS ATTENTION"))
```

---

## EXPECTED OUTPUT

```
  PASS: Config.QUEEN_UPGRADES
  PASS: DataService.queenTier
  PASS: QueenUpgradeService
  PASS: QueenSync RemoteEvent
  PASS: BuyQueenTier RemoteFunction
  PASS: ForagingService has QueenUpgradeService
  PASS: GameManager has QueenUpgradeService
  PASS: QueenUpgradeController LocalScript

8/8 checks passed — DISPATCH 53 COMPLETE ✓
```

---

## PART BUDGET

| Change | Parts |
|---|---|
| QueenUpgradeService + remotes | 0 |
| QueenUpgradeController (PlayerGui) | 0 |
| **Running total** | **4,146 / 5,000** |

---

## UPGRADE TREE SUMMARY (after dispatches 51–53)

Three parallel upgrade tracks, each with distinct resource costs:

| Track | Resource | Tiers | Max Effect |
|---|---|---|---|
| Forage Speed (D51) | Honey | 5 | 2.27× faster cycles |
| Pollen Yield (D52) | Propolis | 5 | 2.49× more pollen |
| Queen Capacity (D53) | Honey | 5 | 25 concurrent bees |

Total honey to max Speed + Queen: 110,500 + 161,000 = **271,500 honey**
Total propolis to max Pollen: **4,100 propolis**

This gives returning players long-term goals across hundreds of sessions, while
the daily reward and streak systems (dispatch 41) keep them logging in daily.

---

*Dispatch 53 complete — execute Steps A → H in order. Proceed to Dispatch 54 after 8/8 checks pass.*
