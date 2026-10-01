# Dispatch 50 — AchievementService (Milestone Badges)
**Cycle 11 | A Bee's World**

> Self-contained Studio execution guide.
> Execute every STEP in order in the Roblox Studio **Command Bar** (View → Command Bar).

---

## OVERVIEW

Achievements give players long-term progression goals beyond the core loop.
Each achievement unlocks once and awards a honey bonus on completion.

**12 achievements** across four categories: Honey, Building, Bee Activity, Seasons.

Key design constraints:
- Achievements are **server-side checked** — no client can spoof completion
- **Persistent**: stored in `profile.earnedAchievements` (set of IDs)
- **Toast notification**: client-side overlay pops 3s on unlock, then fades
- **No grind loops**: checks run on natural events (forge complete, hex placed, season change, etc.) — no polling loops
- **Part budget**: +0 permanent parts

---

## ACHIEVEMENT TABLE

| ID | Icon | Name | Description | Condition | Reward |
|---|---|---|---|---|---|
| `first_honey` | 🍯 | First Drop | Earn 1 honey | honey >= 1 | +100 honey |
| `honey_1k` | 🍯 | Sweet Harvest | Earn 1,000 honey (lifetime) | lifetimeHoney >= 1000 | +500 honey |
| `honey_10k` | 🏺 | Golden Hive | Earn 10,000 honey (lifetime) | lifetimeHoney >= 10000 | +2000 honey |
| `honey_100k` | 👑 | Honey Baron | Earn 100,000 honey (lifetime) | lifetimeHoney >= 100000 | +10000 honey |
| `first_cell` | 🔷 | Foundation | Build 1 hex cell | totalCellsBuilt >= 1 | +50 honey |
| `cells_10` | 🔷 | Architect | Build 10 hex cells | totalCellsBuilt >= 10 | +300 honey |
| `cells_50` | 🏗️ | Master Builder | Build 50 hex cells | totalCellsBuilt >= 50 | +2500 honey |
| `first_gen` | ⭐ | New Generation | Complete 1 prestige | totalGenerations >= 1 | +1000 honey |
| `gen_5` | ⭐ | Veteran | Complete 5 prestiges | totalGenerations >= 5 | +5000 honey |
| `streak_7` | 🔥 | Dedicated Bee | Login 7 days in a row | loginStreak >= 7 | +3000 honey |
| `all_seasons` | 🌍 | Worldly Bee | Experience all 4 seasons | allSeasons flag | +2000 honey |
| `plot_unlock` | 🗺️ | Expanding Mind | Unlock an expansion plot | any unlockedPlots[7] or [8] | +500 honey |

---

## DATA MODEL

New profile fields:

```
profile.earnedAchievements  {[string]: boolean}  default: {}
profile.seenAllSeasons      number               default: 0  (bitmask: Spring=1 Summer=2 Autumn=4 Winter=8)
```

---

## STEP A — Config injection

Paste in Command Bar:

```lua
-- STEP A: inject ACHIEVEMENTS table into Config
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local src = cfg.Source

if src:find("ACHIEVEMENTS", 1, true) then
    print("Config already has ACHIEVEMENTS — skip STEP A")
else
    local anchor = "return Config"
    assert(src:find(anchor, 1, true), "anchor 'return Config' not found")

    local injection = [[
Config.ACHIEVEMENTS = {
    { id = "first_honey",  icon = "🍯", name = "First Drop",       desc = "Earn your first honey",        reward = 100   },
    { id = "honey_1k",     icon = "🍯", name = "Sweet Harvest",    desc = "Earn 1,000 honey (lifetime)",  reward = 500   },
    { id = "honey_10k",    icon = "🏺", name = "Golden Hive",      desc = "Earn 10,000 honey (lifetime)", reward = 2000  },
    { id = "honey_100k",   icon = "👑", name = "Honey Baron",      desc = "Earn 100K honey (lifetime)",   reward = 10000 },
    { id = "first_cell",   icon = "🔷", name = "Foundation",       desc = "Build your first hex cell",    reward = 50    },
    { id = "cells_10",     icon = "🔷", name = "Architect",        desc = "Build 10 hex cells",           reward = 300   },
    { id = "cells_50",     icon = "🏗️", name = "Master Builder",  desc = "Build 50 hex cells",           reward = 2500  },
    { id = "first_gen",    icon = "⭐", name = "New Generation",   desc = "Complete 1 prestige",          reward = 1000  },
    { id = "gen_5",        icon = "⭐", name = "Veteran",          desc = "Complete 5 prestiges",         reward = 5000  },
    { id = "streak_7",     icon = "🔥", name = "Dedicated Bee",    desc = "Login 7 days in a row",        reward = 3000  },
    { id = "all_seasons",  icon = "🌍", name = "Worldly Bee",      desc = "Experience all 4 seasons",     reward = 2000  },
    { id = "plot_unlock",  icon = "🗺️", name = "Expanding Mind",  desc = "Unlock an expansion plot",     reward = 500   },
}

return Config]]

    local clone = cfg:Clone()
    cfg.Name = "Config_OLD_NX"
    cfg.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "Config"
    clone.Parent = SSS
    print("STEP A done — Config.ACHIEVEMENTS injected")
end
```

---

## STEP B — DataService migration

Paste in Command Bar:

```lua
-- STEP B: inject earnedAchievements + seenAllSeasons into DataService
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local src = ds.Source

if src:find("earnedAchievements", 1, true) then
    print("DataService already has earnedAchievements — skip STEP B")
else
    local anchor = "unlockedPlots = {[1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true},"
    assert(src:find(anchor, 1, true), "anchor not found — check DataService source")

    local injection = anchor .. [[

        earnedAchievements = {},
        seenAllSeasons = 0,]]

    local clone = ds:Clone()
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "DataService"
    clone.Parent = SSS
    print("STEP B done — earnedAchievements + seenAllSeasons injected")
end
```

---

## STEP C — AchievementService ModuleScript

Paste in Command Bar:

```lua
-- STEP C: create AchievementService in ServerScriptService
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("AchievementService"), "AchievementService already exists — skip STEP C")

local m = Instance.new("ModuleScript")
m.Name   = "AchievementService"
m.Parent = SSS
m.Source = [[
--!strict
local Players  = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local SSS      = game:GetService("ServerScriptService")

local DataService = require(SSS:WaitForChild("DataService"))
local Config      = require(SSS:WaitForChild("Config"))

local AchievementService = {}

local AchievementUnlocked: RemoteEvent

-- Award an achievement (idempotent — silent if already earned)
function AchievementService.Check(player: Player, id: string)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    if not profile.earnedAchievements then profile.earnedAchievements = {} end
    if profile.earnedAchievements[id] then return end  -- already earned

    -- Find config entry
    local entry = nil
    for _, a in Config.ACHIEVEMENTS do
        if a.id == id then entry = a break end
    end
    if not entry then return end

    -- Mark earned
    profile.earnedAchievements[id] = true

    -- Award honey
    profile.honey = (profile.honey or 0) + entry.reward
    profile.lifetimeHoney = (profile.lifetimeHoney or 0) + entry.reward

    -- Notify client
    AchievementUnlocked:FireClient(player, {
        id     = id,
        icon   = entry.icon,
        name   = entry.name,
        reward = entry.reward,
    })

    print(string.format("[AchievementService] %s earned '%s' (+%d honey)", player.Name, entry.name, entry.reward))
end

-- Bulk-check all achievements for a player (called after any stat change)
function AchievementService.CheckAll(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local lh  = profile.lifetimeHoney  or 0
    local cb  = profile.totalCellsBuilt or 0
    local gen = profile.totalGenerations or 0
    local ls  = profile.loginStreak     or 0
    local up  = profile.unlockedPlots   or {}
    local sas = profile.seenAllSeasons  or 0

    -- Honey milestones
    if lh >= 1     then AchievementService.Check(player, "first_honey") end
    if lh >= 1000  then AchievementService.Check(player, "honey_1k")   end
    if lh >= 10000 then AchievementService.Check(player, "honey_10k")  end
    if lh >= 100000 then AchievementService.Check(player, "honey_100k") end

    -- Build milestones
    if cb >= 1  then AchievementService.Check(player, "first_cell") end
    if cb >= 10 then AchievementService.Check(player, "cells_10")   end
    if cb >= 50 then AchievementService.Check(player, "cells_50")   end

    -- Prestige milestones
    if gen >= 1 then AchievementService.Check(player, "first_gen") end
    if gen >= 5 then AchievementService.Check(player, "gen_5")     end

    -- Login streak
    if ls >= 7 then AchievementService.Check(player, "streak_7") end

    -- All 4 seasons seen (bitmask = 1+2+4+8 = 15)
    if sas == 15 then AchievementService.Check(player, "all_seasons") end

    -- Expansion plot unlocked
    if up[7] or up[8] then AchievementService.Check(player, "plot_unlock") end
end

-- Record a season being seen (bitmask: 0=Spring 1=Summer 2=Autumn 3=Winter)
function AchievementService.RecordSeason(player: Player, seasonIndex: number)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local bit = 2 ^ seasonIndex   -- 1, 2, 4, or 8
    local current = profile.seenAllSeasons or 0
    if current == 15 then return end  -- already complete
    local newVal = bit32.bor(current, bit)
    profile.seenAllSeasons = newVal
    if newVal == 15 then
        AchievementService.Check(player, "all_seasons")
    end
end

function AchievementService.Init()
    AchievementUnlocked = RepStore:WaitForChild("AchievementUnlocked") :: RemoteEvent

    -- Check achievements 5 seconds after player loads (catch any already-earned from prior sessions)
    Players.PlayerAdded:Connect(function(player: Player)
        task.delay(5, function()
            if player.Parent then AchievementService.CheckAll(player) end
        end)
    end)

    print("[AchievementService] initialised")
end

return AchievementService
]]

print("STEP C done — AchievementService created")
```

---

## STEP D — AchievementUnlocked RemoteEvent

Paste in Command Bar:

```lua
-- STEP D: create AchievementUnlocked RemoteEvent
local Rep = game:GetService("ReplicatedStorage")
if not Rep:FindFirstChild("AchievementUnlocked") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "AchievementUnlocked"
    re.Parent = Rep
    print("AchievementUnlocked created")
else print("AchievementUnlocked already exists") end
```

---

## STEP E — GameManager injection

Paste in Command Bar:

```lua
-- STEP E: inject AchievementService.Init() into GameManager
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local src = gm.Source

if src:find("AchievementService", 1, true) then
    print("GameManager already has AchievementService — skip STEP E")
else
    local anchor = "HiveExpansionService.Init()"
    assert(src:find(anchor, 1, true), "anchor 'HiveExpansionService.Init()' not found")

    local injection = [[
HiveExpansionService.Init()
    local AchievementService = require(ServerScriptService:WaitForChild("AchievementService"))
    AchievementService.Init()]]

    local clone = gm:Clone()
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil

    clone.Source = src:gsub(anchor, injection, 1)
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("STEP E done — AchievementService.Init() injected")
end
```

---

## STEP F — Injection points into other services

These inject `AchievementService.CheckAll` calls at natural event points.

### F1 — ForagingService (honey earned trigger)

Paste in Command Bar:

```lua
-- STEP F1: inject CheckAll into ForagingService after honey is credited
local SSS = game:GetService("ServerScriptService")
local fs  = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local src = fs.Source

if src:find("AchievementService", 1, true) then
    print("ForagingService already has AchievementService — skip F1")
else
    -- Find the require block at top and add AchievementService
    local reqAnchor = 'local DataService = require(SSS:WaitForChild("DataService"))'
    assert(src:find(reqAnchor, 1, true), "require anchor not found in ForagingService")

    local reqInjection = reqAnchor .. '\nlocal AchievementService = require(SSS:WaitForChild("AchievementService"))'

    -- Find where honey is credited to profile (profile.honey = ...)
    -- Inject CheckAll after the credit line
    local creditAnchor = "profile.lifetimeHoney = (profile.lifetimeHoney or 0) + honeyYield"
    if not src:find(creditAnchor, 1, true) then
        -- Try alternate pattern
        creditAnchor = "profile.honey = profile.honey + "
    end
    assert(src:find(creditAnchor, 1, true), "honey credit anchor not found in ForagingService")

    local creditInjection = creditAnchor .. "\n        AchievementService.CheckAll(player)"

    local clone = fs:Clone()
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil

    local newSrc = src:gsub(reqAnchor, reqInjection, 1)
    newSrc = newSrc:gsub(creditAnchor, creditInjection, 1)
    clone.Source = newSrc
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("STEP F1 done — AchievementService.CheckAll injected into ForagingService")
end
```

### F2 — PlotService (cell built trigger)

Paste in Command Bar:

```lua
-- STEP F2: inject CheckAll into PlotService after hex cell is placed
local SSS = game:GetService("ServerScriptService")
local ps  = SSS:FindFirstChild("PlotService")
assert(ps, "PlotService not found")

local src = ps.Source

if src:find("AchievementService", 1, true) then
    print("PlotService already has AchievementService — skip F2")
else
    local reqAnchor = 'local DataService = require(SSS:WaitForChild("DataService"))'
    assert(src:find(reqAnchor, 1, true), "require anchor not found in PlotService")

    local reqInjection = reqAnchor .. '\nlocal AchievementService = require(SSS:WaitForChild("AchievementService"))'

    -- Inject after totalCellsBuilt increment
    local cellAnchor = 'profile.totalCellsBuilt = (profile.totalCellsBuilt or 0) + 1'
    assert(src:find(cellAnchor, 1, true), "totalCellsBuilt anchor not found in PlotService")

    local cellInjection = cellAnchor .. "\n        AchievementService.CheckAll(player)"

    local clone = ps:Clone()
    ps.Name = "PlotService_OLD_NX"
    ps.Parent = nil

    local newSrc = src:gsub(reqAnchor, reqInjection, 1)
    newSrc = newSrc:gsub(cellAnchor, cellInjection, 1)
    clone.Source = newSrc
    clone.Name = "PlotService"
    clone.Parent = SSS
    print("STEP F2 done — AchievementService.CheckAll injected into PlotService")
end
```

### F3 — SeasonService (season seen trigger)

Paste in Command Bar:

```lua
-- STEP F3: inject RecordSeason into SeasonService when season changes
local SSS = game:GetService("ServerScriptService")
local ss  = SSS:FindFirstChild("SeasonService")
assert(ss, "SeasonService not found")

local src = ss.Source

if src:find("AchievementService", 1, true) then
    print("SeasonService already has AchievementService — skip F3")
else
    local reqAnchor = 'local DataService = require(SSS:WaitForChild("DataService"))'
    assert(src:find(reqAnchor, 1, true), "require anchor not found in SeasonService")

    local reqInjection = reqAnchor .. '\nlocal AchievementService = require(SSS:WaitForChild("AchievementService"))'

    -- Inject RecordSeason call inside syncAll() → for each player
    -- Find the SeasonSync FireAllClients call and inject before it
    local syncAnchor = "SeasonSync:FireAllClients("
    assert(src:find(syncAnchor, 1, true), "SeasonSync:FireAllClients anchor not found in SeasonService")

    local syncInjection = [[
for _, p in Players:GetPlayers() do
        AchievementService.RecordSeason(p, _currentSeason)
    end
    ]] .. syncAnchor

    local clone = ss:Clone()
    ss.Name = "SeasonService_OLD_NX"
    ss.Parent = nil

    local newSrc = src:gsub(reqAnchor, reqInjection, 1)
    newSrc = newSrc:gsub(syncAnchor, syncInjection, 1)
    clone.Source = newSrc
    clone.Name = "SeasonService"
    clone.Parent = SSS
    print("STEP F3 done — AchievementService.RecordSeason injected into SeasonService")
end
```

---

## STEP G — AchievementToast LocalScript

Paste in Command Bar:

```lua
-- STEP G: create AchievementToast LocalScript in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")
assert(not SPS:FindFirstChild("AchievementToast"), "AchievementToast exists — skip STEP G")

local ls = Instance.new("LocalScript")
ls.Name   = "AchievementToast"
ls.Parent = SPS
ls.Source = [[
--!strict
-- AchievementToast: pop-up notification when an achievement is earned
local Players      = game:GetService("Players")
local RepStore     = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local AchievementUnlocked = RepStore:WaitForChild("AchievementUnlocked") :: RemoteEvent

-- Toast queue (prevent overlap)
local queue: {{icon:string, name:string, reward:number}} = {}
local showing = false

local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local DARK_BG    = Color3.fromRGB(25, 15, 5)

local function showToast(data: {icon:string, name:string, reward:number})
    -- Build ScreenGui per-toast (destroyed after animation)
    local sg = Instance.new("ScreenGui")
    sg.Name           = "AchievementToastGui"
    sg.DisplayOrder   = 200
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.Parent         = PlayerGui

    local toast = Instance.new("Frame")
    toast.Name             = "Toast"
    toast.AnchorPoint      = Vector2.new(0.5, 0)
    toast.Position         = UDim2.new(0.5, 0, -0.12, 0)  -- starts above screen
    toast.Size             = UDim2.new(0, 320, 0, 70)
    toast.BackgroundColor3 = DARK_BG
    toast.BorderSizePixel  = 0
    toast.ZIndex           = 5
    toast.Parent           = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent       = toast

    local stroke = Instance.new("UIStroke")
    stroke.Color     = HONEY_GOLD
    stroke.Thickness = 2
    stroke.Parent    = toast

    -- Icon
    local iconLbl = Instance.new("TextLabel")
    iconLbl.Position             = UDim2.new(0, 12, 0.5, 0)
    iconLbl.AnchorPoint          = Vector2.new(0, 0.5)
    iconLbl.Size                 = UDim2.new(0, 44, 0, 44)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text                 = data.icon
    iconLbl.TextScaled           = true
    iconLbl.Font                 = Enum.Font.GothamBold
    iconLbl.ZIndex               = 6
    iconLbl.Parent               = toast

    -- Achievement name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Position             = UDim2.new(0, 64, 0.08, 0)
    nameLbl.Size                 = UDim2.new(0.70, 0, 0.44, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text                 = "🏅 " .. data.name
    nameLbl.TextScaled           = true
    nameLbl.Font                 = Enum.Font.GothamBold
    nameLbl.TextColor3           = HONEY_GOLD
    nameLbl.TextXAlignment       = Enum.TextXAlignment.Left
    nameLbl.ZIndex               = 6
    nameLbl.Parent               = toast

    -- Reward line
    local rewardLbl = Instance.new("TextLabel")
    rewardLbl.Position           = UDim2.new(0, 64, 0.52, 0)
    rewardLbl.Size               = UDim2.new(0.70, 0, 0.38, 0)
    rewardLbl.BackgroundTransparency = 1
    rewardLbl.Text               = "+" .. tostring(data.reward) .. " 🍯 honey bonus"
    rewardLbl.TextScaled         = true
    rewardLbl.Font               = Enum.Font.Gotham
    rewardLbl.TextColor3         = Color3.fromRGB(200, 180, 120)
    rewardLbl.TextXAlignment     = Enum.TextXAlignment.Left
    rewardLbl.ZIndex             = 6
    rewardLbl.Parent             = toast

    -- Slide in
    local slideIn = TweenService:Create(toast,
        TweenInfo.new(0.40, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0.05, 0) }
    )
    slideIn:Play()
    slideIn.Completed:Wait()

    task.wait(3)

    -- Slide out
    local slideOut = TweenService:Create(toast,
        TweenInfo.new(0.30, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.new(0.5, 0, -0.12, 0) }
    )
    slideOut:Play()
    slideOut.Completed:Wait()

    sg:Destroy()
end

local function processQueue()
    if showing then return end
    if #queue == 0 then return end
    showing = true
    local item = table.remove(queue, 1)
    showToast(item)
    showing = false
    -- Process next item
    if #queue > 0 then
        task.delay(0.3, processQueue)
    end
end

AchievementUnlocked.OnClientEvent:Connect(function(data: {id:string, icon:string, name:string, reward:number})
    table.insert(queue, { icon = data.icon, name = data.name, reward = data.reward })
    task.spawn(processQueue)
end)
]]

print("STEP G done — AchievementToast created")
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
    {"Config.ACHIEVEMENTS",
        SSS:FindFirstChild("Config") and
        SSS:FindFirstChild("Config").Source:find("ACHIEVEMENTS", 1, true) ~= nil},
    {"DataService.earnedAchievements",
        SSS:FindFirstChild("DataService") and
        SSS:FindFirstChild("DataService").Source:find("earnedAchievements", 1, true) ~= nil},
    {"AchievementService",
        SSS:FindFirstChild("AchievementService") ~= nil},
    {"AchievementUnlocked RemoteEvent",
        Rep:FindFirstChild("AchievementUnlocked") ~= nil},
    {"GameManager has AchievementService",
        SSS:FindFirstChild("GameManager") and
        SSS:FindFirstChild("GameManager").Source:find("AchievementService", 1, true) ~= nil},
    {"ForagingService has AchievementService",
        SSS:FindFirstChild("ForagingService") and
        SSS:FindFirstChild("ForagingService").Source:find("AchievementService", 1, true) ~= nil},
    {"PlotService has AchievementService",
        SSS:FindFirstChild("PlotService") and
        SSS:FindFirstChild("PlotService").Source:find("AchievementService", 1, true) ~= nil},
    {"SeasonService has AchievementService",
        SSS:FindFirstChild("SeasonService") and
        SSS:FindFirstChild("SeasonService").Source:find("AchievementService", 1, true) ~= nil},
    {"AchievementToast LocalScript",
        SPS and SPS:FindFirstChild("AchievementToast") ~= nil},
}

local pass, fail = 0, 0
for _, c in checks do
    local label, result = c[1], c[2]
    if result then print("  PASS: " .. label) pass = pass + 1
    else           warn("  FAIL: " .. label)  fail = fail + 1 end
end
print(string.format("\n%d/%d checks passed — %s",
    pass, #checks, fail == 0 and "DISPATCH 50 COMPLETE ✓" or "NEEDS ATTENTION"))
```

---

## EXPECTED OUTPUT

```
  PASS: Config.ACHIEVEMENTS
  PASS: DataService.earnedAchievements
  PASS: AchievementService
  PASS: AchievementUnlocked RemoteEvent
  PASS: GameManager has AchievementService
  PASS: ForagingService has AchievementService
  PASS: PlotService has AchievementService
  PASS: SeasonService has AchievementService
  PASS: AchievementToast LocalScript

9/9 checks passed — DISPATCH 50 COMPLETE ✓
```

---

## PART BUDGET

| Change | Parts |
|---|---|
| AchievementService / Toast / Remotes | 0 |
| Config / DataService injection | 0 |
| Toast ScreenGui (PlayerGui runtime, destroyed after 3s) | 0 |
| **Running total** | **4,146 / 5,000** |

---

## BEHAVIOUR NOTES

- **Idempotent checks**: `AchievementService.Check` guards against double-awards with `if profile.earnedAchievements[id] then return end`.
- **CheckAll on login**: 5-second delayed CheckAll on `PlayerAdded` catches any achievements a returning player earned in a previous session that didn't fire the injection points (e.g. they already hit 50 cells before this dispatch was deployed).
- **Season bitmask**: `seenAllSeasons` uses `bit32.bor` to set flags 1/2/4/8 for Spring/Summer/Autumn/Winter. `== 15` means all four seen.
- **Toast queue**: if multiple achievements unlock simultaneously (e.g. at login CheckAll), each toast waits 0.3s after the previous one finishes — no overlapping toasts.
- **Honey reward stacks into lifetimeHoney**: the reward honey is also added to `lifetimeHoney` so it can trigger higher-tier achievements on the same `CheckAll` call.
- **No polling loops**: the only timer is the 5s `PlayerAdded` delay — all other checks fire on natural events (foraging result, hex placed, season changed).

---

*Dispatch 50 complete — execute Steps A → H in order. Proceed to Dispatch 51 after 9/9 checks pass.*
