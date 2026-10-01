# A Bee's World — Cycle 11 Dispatch: CosmeticService

> **Dispatch 22 — supersedes cycle6_cosmetics_dispatch.md**
>
> cycle6_cosmetics_dispatch.md was written when DataService was at v5. By execution
> time it will be at v13 (after dispatch 21 — cycle11_swarm). This dispatch carries
> the identical CosmeticService / CosmeticController / WardrobePad code from cycle6,
> but patches **DataService v13→v14** (cosmeticsUnlocked, equippedSkin, lifetimeHoney,
> molassesRepels) with migration index 9. **Do NOT also execute cycle6_cosmetics_dispatch.md.**

---

## Overview

**7 bee body skins** that players equip via the WardrobePad on their plot. Equipped skins
are visible to all players in the shared Wild Meadow — a glowing Night Bee flying someone
else's route is a social status signal and a soft advertisement for long-term play.

| ID | Display Name | Unlock Condition |
|----|-------------|-----------------|
| `bee_default` | Honey Bee | Free — all players |
| `bee_golden` | Golden Bee | 50,000 lifetime honey earned |
| `bee_night` | Night Bee | Survive 3 Molasses raids (smoker repel, not bear feeding) |
| `bee_crystal` | Crystal Bee | Reach Floor 3 (Crown Comb tier built) |
| `bee_autumn` | Autumn Bee | Generation 2+ (swarm at least twice) |
| `bee_moon` | Moon Bee | Gamepass: MoonBee (premium) |
| `bee_arctic` | Arctic Bee | Gamepass: ArcticBee (premium) |

---

## Prerequisites

- All dispatches 1–21 executed in order (especially dispatch 21 — cycle11_swarm, which
  sets DataService v13 with the `generation` field)
- fix_bug9_duplicate_dataservice.lua already run
- WardrobePedestal mesh template exists in `ReplicatedStorage.Templates`
- `ReplicatedStorage.Remotes` folder exists
- `Config.MONETIZATION` exists in Config module

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| WardrobePad × 6 (one per plot, template or simple pad) | 12 (2/each) |
| **Total new** | **12** |
| **Running total** | **~4,052 / 5,000** |

---

## STEP A — New RemoteEvents

Run in Studio Command Bar:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local needed = {"RequestEquip", "EquippedSkinChanged", "WardrobeDataSync"}
for _, name in needed do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name   = name
        re.Parent = Remotes
        print("Created: " .. name)
    else
        print("Exists: " .. name)
    end
end
-- RequestEquip:        client → server (skinId: string)
-- EquippedSkinChanged: server → all clients (userId: number, skinId: string)
-- WardrobeDataSync:    server → client (unlockedList: {string}, equippedSkin: string)
return "Remotes done"
```

---

## STEP B — Config.COSMETICS additions

**Edit `ReplicatedStorage.Modules.Config`** using clone-and-replace.

Add this block before `return Config`:

```lua
Config.COSMETICS = {
    bee_default = {
        displayName   = "Honey Bee",
        description   = "The classic. Sun-warm gold.",
        unlockType    = "free",
        unlockValue   = nil,
        color1        = Color3.fromRGB(242, 168, 28),
        color2        = nil,
        material      = Enum.Material.SmoothPlastic,
        lightEmission = 0,
        reflectance   = 0,
        sortOrder     = 1,
    },
    bee_golden = {
        displayName   = "Golden Bee",
        description   = "Earned through 50,000 honey. It shows.",
        unlockType    = "lifetime_honey",
        unlockValue   = 50000,
        color1        = Color3.fromRGB(255, 215, 0),
        color2        = nil,
        material      = Enum.Material.Neon,
        lightEmission = 0.3,
        reflectance   = 0,
        sortOrder     = 2,
    },
    bee_night = {
        displayName   = "Night Bee",
        description   = "Three raids survived. Old Molasses remembers you.",
        unlockType    = "molasses_repels",
        unlockValue   = 3,
        color1        = Color3.fromRGB(26, 26, 46),
        color2        = Color3.fromRGB(155, 89, 182),
        material      = Enum.Material.SmoothPlastic,
        lightEmission = 0,
        reflectance   = 0,
        sortOrder     = 3,
    },
    bee_crystal = {
        displayName   = "Crystal Bee",
        description   = "Built to the top. The whole server saw you.",
        unlockType    = "floor3_built",
        unlockValue   = true,
        color1        = Color3.fromRGB(168, 216, 234),
        color2        = nil,
        material      = Enum.Material.Glass,
        lightEmission = 0,
        reflectance   = 0.6,
        sortOrder     = 4,
    },
    bee_autumn = {
        displayName   = "Autumn Bee",
        description   = "A new generation. Something carried forward.",
        unlockType    = "generation",
        unlockValue   = 2,
        color1        = Color3.fromRGB(192, 57, 43),
        color2        = Color3.fromRGB(230, 126, 34),
        material      = Enum.Material.SmoothPlastic,
        lightEmission = 0,
        reflectance   = 0,
        sortOrder     = 5,
    },
    bee_moon = {
        displayName   = "Moon Bee",
        description   = "A pale light in the dark hive.",
        unlockType    = "gamepass",
        unlockValue   = "MoonBee",
        color1        = Color3.fromRGB(232, 232, 255),
        color2        = nil,
        material      = Enum.Material.Neon,
        lightEmission = 0.5,
        reflectance   = 0,
        sortOrder     = 6,
    },
    bee_arctic = {
        displayName   = "Arctic Bee",
        description   = "From somewhere colder. Doesn't explain itself.",
        unlockType    = "gamepass",
        unlockValue   = "ArcticBee",
        color1        = Color3.fromRGB(255, 255, 255),
        color2        = nil,
        material      = Enum.Material.SmoothPlastic,
        lightEmission = 0,
        reflectance   = 0.4,
        sortOrder     = 7,
    },
}

Config.COSMETIC_ORDER = {
    "bee_default", "bee_golden", "bee_night",
    "bee_crystal", "bee_autumn", "bee_moon", "bee_arctic",
}
```

Also add Gamepass entries to `Config.MONETIZATION` (IDs start at 0 until user creates them):

```lua
-- Find Config.MONETIZATION table and add:
Config.MONETIZATION.MoonBee   = 0   -- paste real Gamepass ID here after creating in Creator Dashboard
Config.MONETIZATION.ArcticBee = 0   -- paste real Gamepass ID here after creating in Creator Dashboard
```

**Verification:**

```lua
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local count = 0
for _ in cfg.COSMETICS or {} do count += 1 end
local orderLen = #(cfg.COSMETIC_ORDER or {})
local hasMoon   = cfg.MONETIZATION and cfg.MONETIZATION.MoonBee ~= nil
local hasArctic = cfg.MONETIZATION and cfg.MONETIZATION.ArcticBee ~= nil
return "COSMETICS=" .. count .. " ORDER=" .. orderLen .. " MoonBee=" .. tostring(hasMoon) .. " ArcticBee=" .. tostring(hasArctic)
-- Expected: COSMETICS=7 ORDER=7 MoonBee=true ArcticBee=true
```

---

## STEP C — DataService v13→v14

**Edit `ServerScriptService.Systems.DataService`** using clone-and-replace.

### C1 — Profile template additions

In PROFILE_TEMPLATE, add after `swarmPerks` (added in dispatch 21):

```lua
cosmeticsUnlocked = {"bee_default"},   -- unlocked skin IDs
equippedSkin      = "bee_default",     -- currently equipped skin ID
lifetimeHoney     = 0,                 -- running total for Golden Bee unlock
molassesRepels    = 0,                 -- smoker-repel count for Night Bee unlock
```

### C2 — Migration index 9 (v13→v14)

In MIGRATIONS table add:

```lua
[9] = function(profile)
    if profile.cosmeticsUnlocked == nil then
        profile.cosmeticsUnlocked = {"bee_default"}
    end
    if profile.equippedSkin == nil then
        profile.equippedSkin = "bee_default"
    end
    if profile.lifetimeHoney == nil then
        profile.lifetimeHoney = 0
    end
    if profile.molassesRepels == nil then
        profile.molassesRepels = 0
    end
    return profile
end,
```

### C3 — Version bump

Find `CURRENT_VERSION` and change from `13` to `14`:

```lua
local CURRENT_VERSION = 14
```

### C4 — Verification

```lua
local ds = game:GetService("ServerScriptService").Systems:FindFirstChild("DataService")
if not ds then return "NOT FOUND" end
local src = ds.Source
local v14      = src:find("CURRENT_VERSION%s*=%s*14") ~= nil or src:find("=%s*14%s*$") ~= nil
local hasCos   = src:find("cosmeticsUnlocked") ~= nil
local hasEq    = src:find("equippedSkin") ~= nil
local hasLH    = src:find("lifetimeHoney") ~= nil
local hasMR    = src:find("molassesRepels") ~= nil
local hasMig9  = src:find("%[9%]") ~= nil
return "v14=" .. tostring(v14) .. " cosmeticsUnlocked=" .. tostring(hasCos)
    .. " equippedSkin=" .. tostring(hasEq) .. " lifetimeHoney=" .. tostring(hasLH)
    .. " molassesRepels=" .. tostring(hasMR) .. " mig[9]=" .. tostring(hasMig9)
-- Expected: all true
```

---

## STEP D — ResourceService: lifetimeHoney tracking

**Edit `ServerScriptService.Systems.ResourceService`** using clone-and-replace.

Find wherever honey is credited to `profile.honey` (likely on Harvest or deposit events).
Immediately after crediting, also increment `profile.lifetimeHoney`:

```lua
-- After: profile.honey = profile.honey + honeyAmount
-- Add:
profile.lifetimeHoney = ((profile.lifetimeHoney :: number?) or 0) + honeyAmount
```

**Read ResourceService source first** to find the exact variable names and location.

---

## STEP E — ThreatService: molassesRepels tracking

**Edit `ServerScriptService.Systems.ThreatService`** using clone-and-replace.

Find the `RepelBear` function (or equivalent — where a successful smoker repel occurs).
After recording the repel, increment `profile.molassesRepels`:

```lua
-- In ThreatService.RepelBear (or wherever stage is reset):
local profile = DataService.GetProfile(player)
if profile then
    profile.molassesRepels = ((profile.molassesRepels :: number?) or 0) + 1
end
```

**Also call `CosmeticService.CheckAndGrantUnlocks(player)` after the increment** so the
Night Bee unlocks immediately when the third repel lands. Add this after the increment:

```lua
local Systems       = game:GetService("ServerScriptService").Systems
local CosmeticService = require(Systems:WaitForChild("CosmeticService"))
CosmeticService.CheckAndGrantUnlocks(player)
```

**Note:** Use `pcall(require, ...)` if there is a risk of circular dependency at require
time. Read ThreatService source before editing to confirm the exact function name.

---

## STEP F — CosmeticService ModuleScript

**Location:** `ServerScriptService.Systems.CosmeticService` (new ModuleScript)

```lua
--!strict
-- CosmeticService: server authority for cosmetic unlocks and equipped skin.
-- Validates unlock prerequisites, writes to profile, fires EquippedSkinChanged
-- so CosmeticController can update the bee's visual appearance on all clients.

local CosmeticService = {}

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Config      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Systems     = game:GetService("ServerScriptService"):WaitForChild("Systems")
local DataService = require(Systems:WaitForChild("DataService"))

local Remotes              = ReplicatedStorage:WaitForChild("Remotes")
local Notify               = Remotes:WaitForChild("Notify")               :: RemoteEvent
local RequestEquip         = Remotes:WaitForChild("RequestEquip")         :: RemoteEvent
local EquippedSkinChanged  = Remotes:WaitForChild("EquippedSkinChanged")  :: RemoteEvent
local WardrobeDataSync     = Remotes:WaitForChild("WardrobeDataSync")     :: RemoteEvent

-- Gamepass ownership cache (per session, per player)
local _gpCache: {[string]: {[number]: boolean}} = {}

local function ownsGamepass(player: Player, gpKey: string): boolean
    local gpId = (Config.MONETIZATION :: {[string]: number})[gpKey]
    if not gpId or gpId == 0 then return false end

    _gpCache[player.Name] = _gpCache[player.Name] or {}
    if _gpCache[player.Name][gpId] ~= nil then
        return _gpCache[player.Name][gpId]
    end

    local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, gpId)
    local result = ok and owns or false
    _gpCache[player.Name][gpId] = result
    return result
end

local function isUnlocked(player: Player, skinId: string): boolean
    local cfg = (Config.COSMETICS :: {[string]: any})[skinId]
    if not cfg then return false end

    local profile = DataService.GetProfile(player)
    if not profile then return false end

    -- Check existing unlocked list first (avoid re-running conditions)
    for _, id in (profile.cosmeticsUnlocked :: {string}?) or {} do
        if id == skinId then return true end
    end

    local unlockType  = cfg.unlockType  :: string
    local unlockValue = cfg.unlockValue

    if unlockType == "free" then
        return true

    elseif unlockType == "lifetime_honey" then
        return ((profile.lifetimeHoney :: number?) or 0) >= (unlockValue :: number)

    elseif unlockType == "molasses_repels" then
        return ((profile.molassesRepels :: number?) or 0) >= (unlockValue :: number)

    elseif unlockType == "floor3_built" then
        local ok, PlotService = pcall(require, Systems:WaitForChild("PlotService"))
        if not ok then return false end
        local plotIndex = PlotService.GetPlotIndex(player)
        if not plotIndex then return false end
        local plotRoot = PlotService.GetPlotRoot(plotIndex)
        return plotRoot ~= nil and ((plotRoot:GetAttribute("CombFloors") :: number?) or 1) >= 3

    elseif unlockType == "generation" then
        return ((profile.generation :: number?) or 0) >= (unlockValue :: number)

    elseif unlockType == "gamepass" then
        return ownsGamepass(player, unlockValue :: string)
    end

    return false
end

-- Scan for newly earned skins and grant them. Call after any stat change.
function CosmeticService.CheckAndGrantUnlocks(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local unlocked = (profile.cosmeticsUnlocked :: {string}?) or {"bee_default"}
    local granted: {string} = {}

    for skinId, cfg in Config.COSMETICS :: {[string]: any} do
        if cfg.unlockType ~= "gamepass" then
            local alreadyHas = false
            for _, id in unlocked do
                if id == skinId then alreadyHas = true; break end
            end
            if not alreadyHas and isUnlocked(player, skinId) then
                table.insert(unlocked, skinId)
                table.insert(granted, skinId)
            end
        end
    end

    if #granted > 0 then
        for _, skinId in granted do
            local displayName = (Config.COSMETICS :: {[string]: any})[skinId].displayName :: string
            Notify:FireClient(player, "Unlocked: " .. displayName .. " bee skin!")
        end
        WardrobeDataSync:FireClient(player, unlocked, (profile.equippedSkin :: string?) or "bee_default")
    end
end

local function handleEquip(player: Player, skinId: string)
    if type(skinId) ~= "string" then return end
    local skinCfg = (Config.COSMETICS :: {[string]: any})[skinId]
    if not skinCfg then return end

    if not isUnlocked(player, skinId) then
        Notify:FireClient(player, "You haven't unlocked " .. skinCfg.displayName .. " yet.")
        return
    end

    local profile = DataService.GetProfile(player)
    if not profile then return end

    profile.equippedSkin = skinId
    pcall(DataService.Save, player)

    -- Broadcast skin change to all clients (other players update their view)
    EquippedSkinChanged:FireAllClients(player.UserId, skinId)
    Notify:FireClient(player, "Equipped: " .. skinCfg.displayName)
end

RequestEquip.OnServerEvent:Connect(function(player: Player, skinId: unknown)
    handleEquip(player, skinId :: string)
end)

Players.PlayerAdded:Connect(function(player: Player)
    task.delay(3, function()
        local profile = DataService.GetProfile(player)
        if not profile then return end
        local skin = (profile.equippedSkin :: string?) or "bee_default"
        -- Broadcast this player's skin to everyone already in the server
        EquippedSkinChanged:FireAllClients(player.UserId, skin)
        -- Send full wardrobe state to this joining player
        WardrobeDataSync:FireClient(player, (profile.cosmeticsUnlocked :: {string}?) or {"bee_default"}, skin)
    end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    _gpCache[player.Name] = nil
end)

function CosmeticService.GetEquippedSkin(player: Player): string
    local profile = DataService.GetProfile(player)
    if not profile then return "bee_default" end
    return (profile.equippedSkin :: string?) or "bee_default"
end

return CosmeticService
```

---

## STEP G — CosmeticsRunner Script

**Location:** `ServerScriptService.CosmeticsRunner` (new Script)

```lua
--!strict
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
require(Systems:WaitForChild("CosmeticService"))
```

---

## STEP H — CosmeticController LocalScript

**Location:** `StarterPlayer.StarterPlayerScripts.CosmeticController` (new LocalScript)

Applies skin color/material overrides to each player's bee character. Listens on
`EquippedSkinChanged` (fires for any player) and `WardrobeDataSync` (fires for this
player on join / equip).

**Architecture note:** The bee character is a scaled-down HumanoidRootPart sphere per
the game architecture. The controller applies `Color`, `Material`, `Reflectance`, and
`LightEmission` to all BaseParts in the character that are tagged `"BeePart"` or, if no
parts are tagged, to all BaseParts directly under the character Model. `color2` skins
(Night Bee / Autumn Bee) apply stripe stripes via a secondary pass on every other visible
part.

```lua
--!strict
-- CosmeticController: applies bee skin appearance to all players' characters.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local EquippedSkinChanged = Remotes:WaitForChild("EquippedSkinChanged") :: RemoteEvent
local WardrobeDataSync    = Remotes:WaitForChild("WardrobeDataSync")    :: RemoteEvent
local RequestEquip        = Remotes:WaitForChild("RequestEquip")        :: RemoteEvent

local localPlayer = Players.LocalPlayer

-- Map userId → skinId for quick re-apply on respawn
local _playerSkins: {[number]: string} = {}

local function getBeeParts(character: Model): {BasePart}
    local tagged = CollectionService:GetTagged("BeePart")
    local parts: {BasePart} = {}
    for _, p in tagged do
        if p:IsDescendantOf(character) and p:IsA("BasePart") then
            table.insert(parts, p)
        end
    end
    if #parts == 0 then
        for _, p in character:GetChildren() do
            if p:IsA("BasePart") then table.insert(parts, p) end
        end
    end
    return parts
end

local function applySkin(character: Model, skinId: string)
    local cfg = (Config.COSMETICS :: {[string]: any})[skinId]
    if not cfg then cfg = (Config.COSMETICS :: {[string]: any})["bee_default"] end
    if not cfg then return end

    local parts = getBeeParts(character)
    local color1  = cfg.color1     :: Color3
    local color2  = cfg.color2     :: Color3?
    local mat     = cfg.material   :: Enum.Material
    local le      = (cfg.lightEmission :: number?) or 0
    local ref     = (cfg.reflectance   :: number?) or 0

    for i, part in parts do
        part.Material      = mat
        part.Reflectance   = ref
        -- Alternate stripe color for skins with color2
        if color2 and i % 2 == 0 then
            part.Color = color2
        else
            part.Color = color1
        end
        -- Apply LightEmission via a PointLight child (create if needed for Neon skins)
        if le > 0 then
            local pl = part:FindFirstChildOfClass("PointLight")
            if not pl then
                pl = Instance.new("PointLight")
                pl.Brightness = le * 2
                pl.Range      = 6
                pl.Color      = color1
                pl.Parent     = part
            end
        else
            -- Remove any previously added PointLight
            local pl = part:FindFirstChildOfClass("PointLight")
            if pl and pl:GetAttribute("CosmeticLight") then pl:Destroy() end
        end
    end
end

-- Apply skin when we get a character for any player
local function onCharacterAdded(player: Player, character: Model)
    task.delay(0.1, function()  -- Brief delay for character to fully load
        local skinId = _playerSkins[player.UserId] or "bee_default"
        applySkin(character, skinId)
    end)
end

-- Wire up existing characters and future respawns
local function watchPlayer(player: Player)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(player, char)
    end)
end

for _, player in Players:GetPlayers() do watchPlayer(player) end
Players.PlayerAdded:Connect(watchPlayer)

-- Server broadcasts a skin change (any player)
EquippedSkinChanged.OnClientEvent:Connect(function(userId: number, skinId: string)
    _playerSkins[userId] = skinId
    -- Find that player and apply
    for _, player in Players:GetPlayers() do
        if player.UserId == userId and player.Character then
            applySkin(player.Character, skinId)
        end
    end
end)

-- Server sends wardrobe state to this player on join or equip
-- (handled by WardrobeGui — see STEP I; CosmeticController only tracks equippedSkin here)
WardrobeDataSync.OnClientEvent:Connect(function(_unlocked: {string}, equippedSkin: string)
    _playerSkins[localPlayer.UserId] = equippedSkin
    if localPlayer.Character then
        applySkin(localPlayer.Character, equippedSkin)
    end
end)

-- Public: used by WardrobeGui to fire equip request
-- (WardrobeGui calls RequestEquip:FireServer(skinId) directly — no module needed)
```

---

## STEP I — WardrobeGui in HiveGui

The wardrobe is a new **WARDROBE** tab inside the existing HiveGui ScreenGui (created in
earlier cycle dispatches). The HiveGui already has BUILD, SHOP, QUEEN, and INFO tabs.

**Edit `StarterGui.HiveGui`** (find the tab bar Frame and TabContent Frame):

### I1 — Add WARDROBE tab button

Find the tab bar that holds BUILD/SHOP/QUEEN/INFO buttons. Add a 5th button:

```lua
-- In the existing HiveGui tab bar (find by reading HiveGui structure first)
-- Run to discover current tab bar:
local hiveGui = game:GetService("StarterGui"):FindFirstChild("HiveGui")
if hiveGui then
    for _, obj in hiveGui:GetDescendants() do
        if obj:IsA("Frame") and obj.Name:find("Tab") then
            print(obj:GetFullName(), obj.Size, #obj:GetChildren())
        end
    end
end
```

Once you identify the tab bar Frame (likely named "TabBar" or "Tabs"), add a TextButton:

```lua
-- Run AFTER identifying the tab bar path:
local tabBar = game:GetService("StarterGui").HiveGui -- navigate to actual TabBar
-- e.g.: local tabBar = hiveGui.MainFrame.TabBar
-- Adjust the path to match the actual hierarchy

local wardrobeBtn = Instance.new("TextButton")
wardrobeBtn.Name             = "WardrobeTab"
wardrobeBtn.Text             = "WARDROBE"
wardrobeBtn.Font             = Enum.Font.FredokaOne
wardrobeBtn.TextSize         = 14
wardrobeBtn.TextColor3       = Color3.fromRGB(232, 212, 154)   -- Wax Cream
wardrobeBtn.BackgroundColor3 = Color3.fromRGB(122, 74, 34)     -- Propolis Brown
wardrobeBtn.Size             = UDim2.fromScale(0.2, 1)         -- adjust to match other tabs
wardrobeBtn.Parent           = tabBar  -- set to actual tabBar instance
Instance.new("UICorner").Parent = wardrobeBtn
```

### I2 — WardrobeContent Frame

Add a content Frame for the WARDROBE tab alongside the existing BUILD/SHOP/QUEEN/INFO frames:

```lua
-- Find the TabContent container (the Frame that holds BUILD content, SHOP content, etc.)
-- Run to discover it:
local hiveGui = game:GetService("StarterGui"):FindFirstChild("HiveGui")
for _, obj in hiveGui:GetDescendants() do
    if obj:IsA("Frame") and (obj.Name == "BuildContent" or obj.Name == "ShopContent") then
        print("TabContent parent:", obj.Parent:GetFullName())
    end
end
```

Once you have the TabContent container path, add:

```lua
local content = Instance.new("Frame")
content.Name              = "WardrobeContent"
content.Size              = UDim2.fromScale(1, 1)
content.BackgroundColor3  = Color3.fromRGB(30, 20, 10)
content.BackgroundTransparency = 0.15
content.Visible           = false  -- hidden until tab selected
content.Parent            = tabContentContainer  -- adjust to actual path

-- Title
local title = Instance.new("TextLabel")
title.Name            = "Title"
title.Size            = UDim2.new(1, 0, 0, 36)
title.Position        = UDim2.fromScale(0, 0)
title.BackgroundTransparency = 1
title.Text            = "Wardrobe"
title.Font            = Enum.Font.FredokaOne
title.TextSize        = 20
title.TextColor3      = Color3.fromRGB(242, 168, 28)
title.Parent          = content

-- ScrollingFrame for skin cards
local scroll = Instance.new("ScrollingFrame")
scroll.Name             = "SkinScroll"
scroll.Size             = UDim2.new(1, 0, 1, -40)
scroll.Position         = UDim2.new(0, 0, 0, 40)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize       = UDim2.fromScale(0, 0)
scroll.Parent           = content

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection  = Enum.FillDirection.Vertical
listLayout.Padding        = UDim.new(0, 6)
listLayout.SortOrder      = Enum.SortOrder.LayoutOrder
listLayout.Parent         = scroll

-- Template skin card (will be cloned by WardrobeController for each skin)
local cardTemplate = Instance.new("Frame")
cardTemplate.Name             = "SkinCard_Template"
cardTemplate.Size             = UDim2.new(1, -8, 0, 56)
cardTemplate.BackgroundColor3 = Color3.fromRGB(50, 35, 15)
cardTemplate.BackgroundTransparency = 0.3
cardTemplate.Parent           = scroll   -- parented to scroll but hidden by WardrobeController
Instance.new("UICorner").Parent = cardTemplate

local cardName = Instance.new("TextLabel")
cardName.Name            = "SkinName"
cardName.Size            = UDim2.new(0.55, 0, 0.5, 0)
cardName.Position        = UDim2.fromScale(0.05, 0.05)
cardName.BackgroundTransparency = 1
cardName.Text            = "Skin Name"
cardName.Font            = Enum.Font.GothamBold
cardName.TextSize        = 14
cardName.TextXAlignment  = Enum.TextXAlignment.Left
cardName.TextColor3      = Color3.fromRGB(232, 212, 154)
cardName.Parent          = cardTemplate

local cardDesc = Instance.new("TextLabel")
cardDesc.Name            = "SkinDesc"
cardDesc.Size            = UDim2.new(0.55, 0, 0.4, 0)
cardDesc.Position        = UDim2.fromScale(0.05, 0.55)
cardDesc.BackgroundTransparency = 1
cardDesc.Text            = "Description"
cardDesc.Font            = Enum.Font.Gotham
cardDesc.TextSize        = 11
cardDesc.TextXAlignment  = Enum.TextXAlignment.Left
cardDesc.TextColor3      = Color3.fromRGB(180, 160, 120)
cardDesc.TextWrapped     = true
cardDesc.Parent          = cardTemplate

local equipBtn = Instance.new("TextButton")
equipBtn.Name            = "EquipButton"
equipBtn.Size            = UDim2.new(0.3, 0, 0.7, 0)
equipBtn.Position        = UDim2.fromScale(0.67, 0.15)
equipBtn.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
equipBtn.Text            = "Equip"
equipBtn.Font            = Enum.Font.GothamBold
equipBtn.TextSize        = 13
equipBtn.TextColor3      = Color3.fromRGB(242, 168, 28)
equipBtn.Parent          = cardTemplate
Instance.new("UICorner").Parent = equipBtn

-- Lock overlay (shown for locked skins)
local lockLabel = Instance.new("TextLabel")
lockLabel.Name              = "LockLabel"
lockLabel.Size              = UDim2.fromScale(1, 1)
lockLabel.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
lockLabel.BackgroundTransparency = 0.4
lockLabel.Text              = "LOCKED"
lockLabel.Font              = Enum.Font.GothamBold
lockLabel.TextSize          = 14
lockLabel.TextColor3        = Color3.fromRGB(200, 200, 200)
lockLabel.Visible           = false
lockLabel.Parent            = cardTemplate
Instance.new("UICorner").Parent = lockLabel

return "WardrobeContent frame built"
```

---

## STEP J — WardrobeController LocalScript

**Location:** `StarterPlayer.StarterPlayerScripts.WardrobeController` (new LocalScript)

Populates the WardrobeContent Frame with skin cards and wires the EquipButton clicks.

```lua
--!strict
-- WardrobeController: populates the Wardrobe tab in HiveGui and handles equip clicks.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))

local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local RequestEquip    = Remotes:WaitForChild("RequestEquip")     :: RemoteEvent
local WardrobeDataSync = Remotes:WaitForChild("WardrobeDataSync") :: RemoteEvent

local localPlayer = Players.LocalPlayer
local playerGui   = localPlayer:WaitForChild("PlayerGui")

-- State
local _unlockedSkins: {string} = {"bee_default"}
local _equippedSkin = "bee_default"

-- Find the HiveGui WardrobeContent frame
local function getWardrobeContent(): Frame?
    local hiveGui = playerGui:WaitForChild("HiveGui", 10)
    if not hiveGui then return nil end
    return hiveGui:FindFirstChild("WardrobeContent", true) :: Frame?
end

-- Build or refresh all skin cards
local function refreshCards(content: Frame)
    local scroll = content:FindFirstChild("SkinScroll") :: ScrollingFrame?
    if not scroll then return end

    -- Remove existing cards (not the template)
    for _, child in scroll:GetChildren() do
        if child:IsA("Frame") and child.Name ~= "SkinCard_Template" and child.Name:find("SkinCard_") then
            child:Destroy()
        end
    end

    local template = scroll:FindFirstChild("SkinCard_Template") :: Frame?
    if not template then return end

    local order = Config.COSMETIC_ORDER :: {string}
    for i, skinId in order do
        local skinCfg = (Config.COSMETICS :: {[string]: any})[skinId]
        if not skinCfg then continue end

        local card = template:Clone()
        card.Name        = "SkinCard_" .. skinId
        card.LayoutOrder = i
        card.Visible     = true

        local nameLabel = card:FindFirstChild("SkinName") :: TextLabel?
        if nameLabel then nameLabel.Text = skinCfg.displayName :: string end

        local descLabel = card:FindFirstChild("SkinDesc") :: TextLabel?
        if descLabel then descLabel.Text = skinCfg.description :: string end

        -- Check if unlocked
        local unlocked = false
        for _, id in _unlockedSkins do
            if id == skinId then unlocked = true; break end
        end

        local lockOverlay = card:FindFirstChild("LockLabel") :: TextLabel?
        local equipBtn    = card:FindFirstChild("EquipButton") :: TextButton?

        if lockOverlay then lockOverlay.Visible = not unlocked end

        if equipBtn then
            if not unlocked then
                equipBtn.Text = "Locked"
                equipBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 40)
                equipBtn.Active = false
            elseif skinId == _equippedSkin then
                equipBtn.Text = "Equipped"
                equipBtn.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
                equipBtn.TextColor3 = Color3.fromRGB(30, 20, 10)
                equipBtn.Active = false
            else
                equipBtn.Text = "Equip"
                equipBtn.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
                equipBtn.TextColor3 = Color3.fromRGB(242, 168, 28)
                equipBtn.Active = true
                equipBtn.MouseButton1Click:Connect(function()
                    RequestEquip:FireServer(skinId)
                end)
            end
        end

        -- Color swatch on the card background
        card.BackgroundColor3 = (skinCfg.color1 :: Color3):Lerp(Color3.fromRGB(30, 20, 10), 0.7)
        card.Parent = scroll
    end
end

-- Server sends wardrobe state on join / equip
WardrobeDataSync.OnClientEvent:Connect(function(unlocked: {string}, equippedSkin: string)
    _unlockedSkins = unlocked
    _equippedSkin  = equippedSkin

    local content = getWardrobeContent()
    if content then refreshCards(content) end
end)

-- Open wardrobe tab: refresh cards in case state changed
local function openWardrobe()
    local content = getWardrobeContent()
    if content then refreshCards(content) end
end

-- Wire WardrobeTab button click (find in HiveGui tab bar)
task.delay(2, function()
    local hiveGui = playerGui:WaitForChild("HiveGui", 10)
    if not hiveGui then return end
    local wardrobeTab = hiveGui:FindFirstChild("WardrobeTab", true) :: TextButton?
    if wardrobeTab then
        wardrobeTab.MouseButton1Click:Connect(openWardrobe)
    end
end)
```

---

## STEP K — WardrobePad world placement

Run in Studio Command Bar:

```lua
local CS = game:GetService("CollectionService")

-- Check for template
local templates = game:GetService("ReplicatedStorage"):FindFirstChild("Templates")
local wTemplate = templates and templates:FindFirstChild("WardrobePedestal")

local PLOT_X = {-250, -150, -50, 50, 150, 250}
local BASE_Y = 11.5   -- deck Y + 5 elevation
local BASE_Z = 35     -- between hex lattice (Z≈0) and SwarmPerch (Z=50)

local PROPOLIS_BROWN = Color3.fromRGB(122, 74, 34)
local WAX_CREAM      = Color3.fromRGB(232, 212, 154)

local plotsFolder = workspace:FindFirstChild("Plots")
local function getParentFolder(i: number): Instance
    if plotsFolder then
        local pf = plotsFolder:FindFirstChild("Plot" .. i)
        return pf or plotsFolder
    end
    return workspace
end

for i, xPos in PLOT_X do
    -- Skip if already placed
    local exists = false
    for _, tagged in CS:GetTagged("WardrobePad") do
        if tagged:GetAttribute("PlotIndex") == i then exists = true; break end
    end
    if exists then
        print("WardrobePad PlotIndex=" .. i .. " already exists, skipping")
        continue
    end

    local model: Model

    if wTemplate then
        model = wTemplate:Clone() :: Model
        model.Name = "WardrobePad_Plot" .. i
        if model.PrimaryPart then
            model:SetPrimaryPartCFrame(CFrame.new(xPos, BASE_Y, BASE_Z))
        end
    else
        -- Fallback: build a simple 2-part pedestal
        model = Instance.new("Model")
        model.Name = "WardrobePad_Plot" .. i

        local base = Instance.new("Part")
        base.Name          = "Base"
        base.Shape         = Enum.PartType.Block
        base.Size          = Vector3.new(3, 4, 3)
        base.Position      = Vector3.new(xPos, BASE_Y - 2, BASE_Z)
        base.Material      = Enum.Material.SmoothPlastic
        base.Color         = PROPOLIS_BROWN
        base.Anchored      = true
        base.CanCollide    = true
        base.Parent        = model
        model.PrimaryPart  = base

        local top = Instance.new("Part")
        top.Name       = "TopPad"
        top.Shape      = Enum.PartType.Cylinder
        top.Size       = Vector3.new(0.3, 4, 4)
        top.CFrame     = CFrame.new(xPos, BASE_Y, BASE_Z)
        top.Material   = Enum.Material.SmoothPlastic
        top.Color      = WAX_CREAM
        top.Anchored   = true
        top.CanCollide = false
        top.Parent     = model
    end

    CS:AddTag(model, "WardrobePad")
    model:SetAttribute("PlotIndex", i)
    model.Parent = getParentFolder(i)

    -- ProximityPrompt on the base part
    local basePart = model:FindFirstChild("Base") or model.PrimaryPart
    if basePart and basePart:IsA("BasePart") then
        local prompt = Instance.new("ProximityPrompt")
        prompt.ActionText            = "Wardrobe"
        prompt.ObjectText            = "WardrobePad"
        prompt.HoldDuration          = 0
        prompt.MaxActivationDistance = 8
        prompt.Parent                = basePart
    end

    print("Placed WardrobePad PlotIndex=" .. i .. " at (" .. xPos .. ", " .. BASE_Y .. ", " .. BASE_Z .. ")")
end
return "WardrobePad placement done"
```

### WardrobePad ProximityPrompt → HiveGui tab opener

Add to `StarterPlayer.StarterPlayerScripts.WardrobeController` (append at end) or create
a separate `WardrobePadController` LocalScript:

```lua
-- Wire WardrobePad ProximityPrompt to open HiveGui WARDROBE tab
local CollectionService = game:GetService("CollectionService")

local function wirePad(pad: Instance)
    local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return end
    prompt.Triggered:Connect(function()
        -- Open HiveGui and switch to WARDROBE tab
        local hiveGui = localPlayer.PlayerGui:FindFirstChild("HiveGui")
        if not hiveGui then return end

        -- Show HiveGui (if it uses an Enabled flag)
        local mainFrame = hiveGui:FindFirstChild("MainFrame")
        if mainFrame then mainFrame.Visible = true end

        -- Click the WardrobeTab button programmatically
        local wardrobeTab = hiveGui:FindFirstChild("WardrobeTab", true) :: TextButton?
        if wardrobeTab then
            wardrobeTab:Activate()
        end
    end)
end

for _, pad in CollectionService:GetTagged("WardrobePad") do wirePad(pad) end
CollectionService:GetInstanceAddedSignal("WardrobePad"):Connect(wirePad)
```

---

## STEP L — Verification

Run after all steps complete:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local CS  = game:GetService("CollectionService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local SGui = game:GetService("StarterGui")

local checks: {string} = {}
local issues: {string} = {}
local function pass(m) table.insert(checks, "PASS: " .. m) end
local function fail(m) table.insert(issues, "FAIL: " .. m) end

-- A: RemoteEvents
for _, name in {"RequestEquip", "EquippedSkinChanged", "WardrobeDataSync"} do
    local r = RS:FindFirstChild("Remotes") and RS.Remotes:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then pass("Remote " .. name)
    else fail("Remote " .. name .. " missing") end
end

-- B: Config.COSMETICS
local ok, cfg = pcall(require, RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Config"))
if ok and cfg then
    local count = 0; for _ in cfg.COSMETICS or {} do count += 1 end
    if count == 7 then pass("Config.COSMETICS 7 skins")
    else fail("Config.COSMETICS count=" .. count .. " (expected 7)") end
    if #(cfg.COSMETIC_ORDER or {}) == 7 then pass("Config.COSMETIC_ORDER 7 entries")
    else fail("Config.COSMETIC_ORDER wrong length") end
    if cfg.MONETIZATION and cfg.MONETIZATION.MoonBee ~= nil then pass("Config.MONETIZATION.MoonBee")
    else fail("Config.MONETIZATION.MoonBee missing") end
    if cfg.MONETIZATION and cfg.MONETIZATION.ArcticBee ~= nil then pass("Config.MONETIZATION.ArcticBee")
    else fail("Config.MONETIZATION.ArcticBee missing") end
else
    fail("Config require failed: " .. tostring(cfg))
end

-- C: DataService v14
local ds = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("DataService")
if ds then
    local src = ds.Source
    if src:find("cosmeticsUnlocked")then pass("DS cosmeticsUnlocked") else fail("DS cosmeticsUnlocked missing") end
    if src:find("equippedSkin")      then pass("DS equippedSkin")      else fail("DS equippedSkin missing") end
    if src:find("lifetimeHoney")     then pass("DS lifetimeHoney")     else fail("DS lifetimeHoney missing") end
    if src:find("molassesRepels")    then pass("DS molassesRepels")    else fail("DS molassesRepels missing") end
    if src:find("%[9%]")             then pass("DS migration[9]")      else fail("DS migration[9] missing") end
else fail("DataService not found") end

-- F: CosmeticService
local cs = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CosmeticService")
if cs and cs:IsA("ModuleScript") then
    local src = cs.Source
    if src:find("--!strict")              then pass("CosmeticService --!strict")            else fail("CosmeticService missing --!strict") end
    if src:find("CheckAndGrantUnlocks")   then pass("CosmeticService.CheckAndGrantUnlocks") else fail("CosmeticService missing CheckAndGrantUnlocks") end
    if src:find("isUnlocked")             then pass("CosmeticService isUnlocked")           else fail("CosmeticService missing isUnlocked") end
    if src:find("EquippedSkinChanged")    then pass("CosmeticService fires EquippedSkinChanged") else fail("CosmeticService missing EquippedSkinChanged fire") end
else fail("CosmeticService ModuleScript missing") end

-- G: CosmeticsRunner
local cr = SSS:FindFirstChild("CosmeticsRunner")
if cr and cr:IsA("Script") then pass("CosmeticsRunner Script") else fail("CosmeticsRunner missing") end

-- H: CosmeticController
local cc = SPS and SPS:FindFirstChild("CosmeticController")
if cc and cc:IsA("LocalScript") then
    local src = cc.Source
    if src:find("EquippedSkinChanged") and src:find("applySkin") then
        pass("CosmeticController LocalScript (EquippedSkinChanged + applySkin)")
    else fail("CosmeticController missing symbols") end
else fail("CosmeticController LocalScript missing") end

-- J: WardrobeController
local wc = SPS and SPS:FindFirstChild("WardrobeController")
if wc and wc:IsA("LocalScript") then
    local src = wc.Source
    if src:find("WardrobeDataSync") and src:find("RequestEquip") then
        pass("WardrobeController LocalScript (WardrobeDataSync + RequestEquip)")
    else fail("WardrobeController missing symbols") end
else fail("WardrobeController LocalScript missing") end

-- K: WardrobePad world objects
local pads = CS:GetTagged("WardrobePad")
if #pads == 6 then pass("6 WardrobePad tagged")
else fail("WardrobePad count=" .. #pads .. " (expected 6)") end

-- Summary
local out = "=== COSMETICS SYSTEM — FULL VERIFICATION ===\n"
out = out .. "PASSED: " .. #checks .. " / ISSUES: " .. #issues .. "\n\n"
out = out .. table.concat(checks, "\n") .. "\n"
if #issues > 0 then
    out = out .. "\n--- ISSUES ---\n" .. table.concat(issues, "\n") .. "\n"
else
    out = out .. "\nALL CHECKS PASSED.\n"
end
return out
```

---

## Smoke test (Play mode)

```lua
-- Force unlock and equip Golden Bee for smoke test (Play mode, server Command Bar):
local Players = game:GetService("Players")
local SSS     = game:GetService("ServerScriptService")
local DS      = require(SSS.Systems.DataService)
local CosS    = require(SSS.Systems.CosmeticService)

local player  = Players:GetPlayers()[1]
local profile = DS.GetProfile(player)
if not profile then return "No profile" end

profile.lifetimeHoney = 60000   -- triggers bee_golden unlock
CosS.CheckAndGrantUnlocks(player)

return "lifetimeHoney patched to 60000. Check wardrobe — Golden Bee should be unlocked and Notify toast should appear."
```

Expected:
- Notify toast: "Unlocked: Golden Bee bee skin!"
- WardrobeDataSync fires to player → WardrobeController refreshes cards
- Golden Bee card shows "Equip" (not "Locked")
- Pressing Equip → RequestEquip fires → CosmeticService equips → EquippedSkinChanged fires to all clients
- Player's bee turns golden Neon material

---

## Executor notes

1. **HiveGui tab wiring**: The WardrobeTab button and WardrobeContent frame must be wired
   to the HiveGui's existing tab switching logic. If HiveGui uses a Script to toggle tab
   visibility, add WardrobeContent to that script's tab list. If it uses a simple
   "click tab button → show matching content frame" pattern, the WardrobeController's
   `openWardrobe()` already handles visibility directly.

2. **DataService version v13→v14**: cycle6_cosmetics_dispatch.md targeted v5→v6. By
   execution time DS is at v13. Run this dispatch, not cycle6_cosmetics_dispatch.md.

3. **Gamepass IDs remain 0 until Creator Dashboard action**: Moon Bee and Arctic Bee
   are unavailable until the user creates those Gamepasses in Creator Dashboard and
   pastes the real IDs into Config.MONETIZATION. The `ownsGamepass` guard safely
   returns false when the ID is 0, so no runtime errors occur.

4. **lifetimeHoney tracking**: Currently ResourceService credits honey via
   `CombService.Harvest`. Read ResourceService source to find the exact line where
   `profile.honey` is incremented and add the `lifetimeHoney` parallel increment there.

5. **molassesRepels tracking**: `ThreatService.RepelBear` calls `ConsumableService`
   (dispatch 20). The count should increment only on a successful repel (ConsumableService
   returned true and the stage actually decreased). Read ThreatService source before
   editing to confirm the exact success path.
