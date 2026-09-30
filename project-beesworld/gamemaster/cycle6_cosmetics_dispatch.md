# A Bee's World — Cycle 6 Dispatch: CosmeticService

## Overview

This dispatch implements the cosmetics system: **6 bee body skins** that players equip via the WardrobePad on their plot. Equipped skins are visible to all players in the shared Wild Meadow — a golden bee flying someone else's route is a social status signal and a soft advertisement for long-term play.

**The 6 skins:**
| ID | Display Name | Unlock Condition |
|----|-------------|-----------------|
| `bee_default` | Honey Bee | Free — all players |
| `bee_golden` | Golden Bee | 50,000 lifetime honey earned |
| `bee_night` | Night Bee | Survive 3 Molasses raids (repel, not feed) |
| `bee_crystal` | Crystal Bee | Reach Floor 3 (Crown Comb built) |
| `bee_autumn` | Autumn Bee | Generation 2+ (swarm at least once) |
| `bee_moon` | Moon Bee | Gamepass: MoonBee (premium cosmetic) |
| `bee_arctic` | Arctic Bee | Gamepass: ArcticBee (premium cosmetic) |

Two of the six are Gamepass-gated — they require the user to create those Gamepasses in Creator Dashboard and paste IDs into Config.MONETIZATION.

**Build order:**
1. luau-scripter — Config.COSMETICS, CosmeticService, CosmeticController, WardrobePad ProximityPrompt wiring, HiveGui Cosmetics tab
2. world-builder — WardrobePad placement at all 6 plots
3. Verification

---

## Prerequisites

- fix_bug9_duplicate_dataservice.lua run
- All prior cycle dispatches executed (especially cycle6_swarm for `generation` profile field)
- WardrobePedestal mesh template exists in `ReplicatedStorage.Templates` (confirmed in cycle 2 mesh pass)
- `ReplicatedStorage.Remotes` folder exists
- `Config.MONETIZATION` exists with Gamepass ID fields (currently 0 placeholders)

---

## Part Budget Impact

| Item | Parts |
|------|-------|
| WardrobePad × 6 (template mesh, est. 3 parts each) | ~18 |
| **Total new** | **~18** |
| Cumulative worst-case | ~3,744 / 5,000 |

---

## Cosmetic skin design

Each skin is a **color + material override** applied to the player's bee model (the client-side character). The bee model is a small sphere (the character's HumanoidRootPart scaled down, per architecture). CosmeticController applies a surface appearance override on the client when a skin is equipped.

| Skin | Primary Color | Material | Special |
|------|--------------|----------|---------|
| Honey Bee | #F2A81C (Honey Gold) | SmoothPlastic | — |
| Golden Bee | #FFD700 (gold) | Neon | LightEmission 0.3 |
| Night Bee | #1A1A2E (deep navy) | SmoothPlastic | stripes #9B59B6 |
| Crystal Bee | #A8D8EA (ice blue) | Glass | Reflectance 0.6 |
| Autumn Bee | #C0392B (deep red) | SmoothPlastic | stripes #E67E22 |
| Moon Bee | #E8E8FF (pale silver) | Neon | LightEmission 0.5 |
| Arctic Bee | #FFFFFF (white) | SmoothPlastic | Reflectance 0.4 |

---

## TASK 1 — luau-scripter

---

### 1A — Config.COSMETICS and MONETIZATION additions

**Edit Config module** using clone-and-replace.

Add after existing Config blocks, before `return Config`:

```lua
Config.COSMETICS = {
    bee_default = {
        displayName   = "Honey Bee",
        description   = "The classic. Sun-warm gold.",
        unlockType    = "free",
        unlockValue   = nil,
        color1        = Color3.fromRGB(242, 168, 28),   -- Honey Gold
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
        color2        = Color3.fromRGB(155, 89, 182),   -- stripe accent
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
        color2        = Color3.fromRGB(230, 126, 34),   -- stripe accent
        material      = Enum.Material.SmoothPlastic,
        lightEmission = 0,
        reflectance   = 0,
        sortOrder     = 5,
    },
    bee_moon = {
        displayName   = "Moon Bee",
        description   = "A pale light in the dark hive.",
        unlockType    = "gamepass",
        unlockValue   = "MoonBee",   -- key into Config.MONETIZATION
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
        unlockValue   = "ArcticBee", -- key into Config.MONETIZATION
        color1        = Color3.fromRGB(255, 255, 255),
        color2        = nil,
        material      = Enum.Material.SmoothPlastic,
        lightEmission = 0,
        reflectance   = 0.4,
        sortOrder     = 7,
    },
}

-- Sort order for wardrobe display (UI reads this)
Config.COSMETIC_ORDER = {
    "bee_default", "bee_golden", "bee_night",
    "bee_crystal", "bee_autumn", "bee_moon", "bee_arctic",
}
```

**Also add to Config.MONETIZATION** (two new Gamepass keys — IDs will be 0 until user creates them in Creator Dashboard):

```lua
-- Add these entries to the existing Config.MONETIZATION table:
Config.MONETIZATION.MoonBee   = 0   -- Gamepass ID for Moon Bee skin
Config.MONETIZATION.ArcticBee = 0   -- Gamepass ID for Arctic Bee skin
```

**Verification:**

```lua
local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
local count = 0
for _ in Config.COSMETICS do count += 1 end
local orderLen = #(Config.COSMETIC_ORDER or {})
local hasMoon  = Config.MONETIZATION and Config.MONETIZATION.MoonBee ~= nil
local hasArctic = Config.MONETIZATION and Config.MONETIZATION.ArcticBee ~= nil
return "COSMETICS=" .. count .. " ORDER=" .. orderLen .. " MoonBee=" .. tostring(hasMoon) .. " ArcticBee=" .. tostring(hasArctic)
-- Expected: COSMETICS=7 ORDER=7 MoonBee=true ArcticBee=true
```

---

### 1B — DataService: cosmeticsUnlocked + equippedSkin fields

**Edit DataService** using clone-and-replace.

**In PROFILE_TEMPLATE**, add after `generation`:
```lua
cosmeticsUnlocked = {"bee_default"},   -- array of unlocked skin IDs
equippedSkin      = "bee_default",     -- currently equipped skin ID
lifetimeHoney     = 0,                 -- running total for Golden Bee unlock
molassesRepels    = 0,                 -- count for Night Bee unlock
```

**In MIGRATIONS**, add migration [5] (v5→v6):
```lua
[5] = function(profile)
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

Increment: `local CURRENT_VERSION = 6`

**Also update ResourceService** to track `lifetimeHoney`: wherever honey is credited to a profile, also increment `profile.lifetimeHoney` by the same amount.

**Also update ThreatService** to track `molassesRepels`: wherever a successful Molasses repel is recorded, increment `profile.molassesRepels`.

---

### 1C — CosmeticService ModuleScript

**Location:** `ServerScriptService.Systems.CosmeticService` (new ModuleScript)

```lua
--!strict
-- CosmeticService: server authority for cosmetic unlocks and equipped skin.
-- Validates unlock prerequisites, writes to profile, fires EquippedSkinChanged
-- so CosmeticController can update the bee's visual appearance.

local CosmeticService = {}

local Players           = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local Notify      = Remotes:WaitForChild("Notify")               :: RemoteEvent
local RequestEquip     = Remotes:WaitForChild("RequestEquip")    :: RemoteEvent
local EquippedSkinChanged = Remotes:WaitForChild("EquippedSkinChanged") :: RemoteEvent
local WardrobeDataSync    = Remotes:WaitForChild("WardrobeDataSync")    :: RemoteEvent

-- Check if a player owns a gamepass (cached per session)
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

-- Determine if a player has met the unlock condition for a skin
local function isUnlocked(player: Player, skinId: string): boolean
    local cfg = Config.COSMETICS[skinId]
    if not cfg then return false end

    local profile = DataService.GetProfile(player)
    if not profile then return false end

    -- Check if already in unlocked list
    for _, id in (profile.cosmeticsUnlocked :: {string}) do
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
        -- Check CombFloors attribute on their plot
        local PlotService = require(script.Parent:WaitForChild("PlotService"))
        local plotIndex   = PlotService.GetPlotIndex(player)
        if not plotIndex then return false end
        local plotRoot    = PlotService.GetPlotRoot(plotIndex)
        return plotRoot and (plotRoot:GetAttribute("CombFloors") or 1) >= 3 or false

    elseif unlockType == "generation" then
        return ((profile.generation :: number?) or 0) >= (unlockValue :: number)

    elseif unlockType == "gamepass" then
        return ownsGamepass(player, unlockValue :: string)
    end

    return false
end

-- Called when a player's progress changes (honey, repels, etc.) to grant newly earned skins
function CosmeticService.CheckAndGrantUnlocks(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end

    local unlocked = profile.cosmeticsUnlocked :: {string}
    local granted: {string} = {}

    for skinId, cfg in Config.COSMETICS do
        if cfg.unlockType ~= "gamepass" then  -- Gamepasses are checked on equip, not auto-granted
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
            local displayName = Config.COSMETICS[skinId].displayName :: string
            Notify:FireClient(player, "Unlocked: " .. displayName .. " bee skin!")
        end
        -- Sync wardrobe UI
        WardrobeDataSync:FireClient(player, unlocked, profile.equippedSkin :: string)
    end
end

-- Equip a skin — validates unlock, writes to profile, fires EquippedSkinChanged
local function handleEquip(player: Player, skinId: string)
    if type(skinId) ~= "string" then return end
    if not Config.COSMETICS[skinId] then return end

    if not isUnlocked(player, skinId) then
        Notify:FireClient(player, "You haven't unlocked " .. Config.COSMETICS[skinId].displayName .. " yet.")
        return
    end

    local profile = DataService.GetProfile(player)
    if not profile then return end

    profile.equippedSkin = skinId
    pcall(DataService.Save, player)

    -- Fire to all clients so other players see the skin change
    EquippedSkinChanged:FireAllClients(player.UserId, skinId)
    Notify:FireClient(player, "Equipped: " .. Config.COSMETICS[skinId].displayName)
end

RequestEquip.OnServerEvent:Connect(function(player: Player, skinId: unknown)
    handleEquip(player, skinId :: string)
end)

-- On player join: fire their current skin to all clients
Players.PlayerAdded:Connect(function(player: Player)
    task.delay(3, function()  -- Wait for profile to load
        local profile = DataService.GetProfile(player)
        if not profile then return end
        local skin = (profile.equippedSkin :: string?) or "bee_default"
        EquippedSkinChanged:FireAllClients(player.UserId, skin)
        -- Send full wardrobe state to this player
        WardrobeDataSync:FireClient(player, profile.cosmeticsUnlocked, skin)
    end)
end)

-- Public API
function CosmeticService.GetEquippedSkin(player: Player): string
    local profile = DataService.GetProfile(player)
    if not profile then return "bee_default" end
    return (profile.equippedSkin :: string?) or "bee_default"
end

return CosmeticService
```

---

### 1D — CosmeticsRunner Script

**Location:** `ServerScriptService.CosmeticsRunner` (new Script)

```lua
--!strict
local Systems = game:GetService("ServerScriptService"):WaitForChild("Systems")
require(Systems:WaitForChild("CosmeticService"))
```

---

### 1E — New RemoteEvents

Create in `ReplicatedStorage.Remotes`:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
for _, name in {"RequestEquip", "EquippedSkinChanged", "WardrobeDataSync"} do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name   = name
        re.Parent = Remotes
        print("Created: " .. name)
    end
end
```

---

### 1F — CosmeticController LocalScript

**Location:** `StarterPlayer.StarterPlayerScripts.CosmeticController` (new LocalScript)

Applies skin colors/materials to bee character models when EquippedSkinChanged fires. Because the bee model is client-side (architecture: "server never moves a bee"), this is safe as a pure client operation.

```lua
--!strict
-- CosmeticController: applies bee skin visual overrides to character models.
-- Listens for EquippedSkinChanged to update any player's bee on all clients.
-- Also opens/closes the WardrobeGui from WardrobePad proximity prompt.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config            = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local EquippedSkinChanged = Remotes:WaitForChild("EquippedSkinChanged") :: RemoteEvent
local WardrobeDataSync    = Remotes:WaitForChild("WardrobeDataSync")    :: RemoteEvent
local RequestEquip        = Remotes:WaitForChild("RequestEquip")        :: RemoteEvent

local localPlayer = Players.LocalPlayer

-- Map UserId → skinId for all players (so new joiners get skins applied)
local _activeSkins: {[number]: string} = {}

-- Apply a skin to a character's bee parts
-- The bee is represented by parts tagged "BeePart" or by the character's primary parts
local function applySkin(character: Model, skinId: string)
    local cfg = Config.COSMETICS[skinId]
    if not cfg then return end

    local color1    = cfg.color1    :: Color3
    local color2    = cfg.color2    :: Color3?
    local mat       = cfg.material  :: Enum.Material
    local emission  = cfg.lightEmission :: number
    local reflect   = cfg.reflectance  :: number

    -- Apply to all BaseParts in the character that are tagged "BeePart"
    -- or fall back to HumanoidRootPart + visible parts
    local CS = game:GetService("CollectionService")
    local beeParts = CS:GetTagged("BeePart")
    local applied  = 0

    for _, part in beeParts do
        if part:IsAncestorOf(character) or part.Parent == character then
            if part:IsA("BasePart") then
                part.Color        = color1
                part.Material     = mat
                part.Reflectance  = reflect
                -- Apply stripe color to alternating parts if color2 exists
                if color2 and applied % 2 == 1 then
                    part.Color = color2
                end
                applied += 1
            end
        end
    end

    -- If no BeePart tags found, apply to whole character (fallback)
    if applied == 0 then
        for _, part in character:GetDescendants() do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Color       = color1
                part.Material    = mat
                part.Reflectance = reflect
            end
        end
    end

    -- Handle LightEmission (apply/remove PointLight on HumanoidRootPart)
    local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if hrp then
        local existingLight = hrp:FindFirstChildOfClass("PointLight")
        if emission > 0 then
            local light = existingLight or Instance.new("PointLight")
            light.Brightness = emission * 2
            light.Range      = 8
            light.Color      = color1
            if not existingLight then light.Parent = hrp end
        else
            if existingLight then existingLight:Destroy() end
        end
    end
end

-- Listen for skin changes (fires for all players on all clients)
EquippedSkinChanged.OnClientEvent:Connect(function(userId: number, skinId: string)
    _activeSkins[userId] = skinId
    -- Find the player with this userId
    for _, player in Players:GetPlayers() do
        if player.UserId == userId then
            local character = player.Character
            if character then
                applySkin(character, skinId)
            end
            -- Also apply when their character respawns
            player.CharacterAdded:Connect(function(char: Model)
                task.wait(0.1)  -- Let character fully load
                applySkin(char, _activeSkins[userId] or "bee_default")
            end)
            break
        end
    end
end)

-- When any player's character spawns, check if we have a stored skin for them
Players.PlayerAdded:Connect(function(player: Player)
    player.CharacterAdded:Connect(function(character: Model)
        task.wait(0.1)
        local skin = _activeSkins[player.UserId] or "bee_default"
        applySkin(character, skin)
    end)
end)

-- Apply stored skins to characters that already exist (on script init)
for _, player in Players:GetPlayers() do
    if player.Character and _activeSkins[player.UserId] then
        applySkin(player.Character, _activeSkins[player.UserId])
    end
end

-- ============================================================
-- WARDROBE GUI
-- ============================================================
-- Build the wardrobe panel on first open (lazy instantiation)
local _wardrobeGui: ScreenGui? = nil
local _ownedSkins:  {string}   = {"bee_default"}
local _currentSkin: string     = "bee_default"

-- Receive wardrobe data from server
WardrobeDataSync.OnClientEvent:Connect(function(ownedSkins: {string}, equippedSkin: string)
    _ownedSkins  = ownedSkins
    _currentSkin = equippedSkin
    -- Refresh GUI if open
    if _wardrobeGui and _wardrobeGui.Enabled then
        -- Rebuild the skin grid (see buildWardrobeGui below)
    end
end)

local function buildWardrobeGui(): ScreenGui
    local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

    local sg = Instance.new("ScreenGui")
    sg.Name           = "WardrobeGui"
    sg.DisplayOrder   = 12
    sg.ResetOnSpawn   = false
    sg.Enabled        = false
    sg.Parent         = playerGui

    local panel = Instance.new("Frame")
    panel.Name               = "WardrobePanel"
    panel.Size               = UDim2.fromScale(0.5, 0.7)
    panel.Position           = UDim2.fromScale(0.25, 0.15)
    panel.BackgroundColor3   = Color3.fromRGB(58, 36, 14)  -- Warm Amber
    panel.BorderSizePixel    = 0
    panel.Parent             = sg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent       = panel

    local title = Instance.new("TextLabel")
    title.Name               = "Title"
    title.Size               = UDim2.fromScale(1, 0.10)
    title.Position           = UDim2.fromScale(0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3         = Color3.fromRGB(242, 168, 28)  -- Honey Gold
    title.Font               = Enum.Font.GothamBold
    title.TextScaled         = true
    title.Text               = "Wardrobe"
    title.Parent             = panel

    local closeBtn = Instance.new("TextButton")
    closeBtn.Name            = "CloseBtn"
    closeBtn.Size            = UDim2.fromScale(0.10, 0.10)
    closeBtn.Position        = UDim2.fromScale(0.88, 0.01)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.TextColor3      = Color3.new(1, 1, 1)
    closeBtn.Font            = Enum.Font.GothamBold
    closeBtn.TextScaled      = true
    closeBtn.Text            = "X"
    closeBtn.Parent          = panel
    Instance.new("UICorner").Parent = closeBtn
    closeBtn.Activated:Connect(function()
        sg.Enabled = false
    end)

    -- Skin grid (7 slots, 4 across)
    local grid = Instance.new("Frame")
    grid.Name            = "SkinGrid"
    grid.Size            = UDim2.fromScale(0.95, 0.82)
    grid.Position        = UDim2.fromScale(0.025, 0.12)
    grid.BackgroundTransparency = 1
    grid.Parent          = panel

    local layout = Instance.new("UIGridLayout")
    layout.CellSize    = UDim2.fromScale(0.22, 0.30)
    layout.CellPadding = UDim2.fromScale(0.02, 0.02)
    layout.Parent      = grid

    local function rebuildGrid()
        for _, child in grid:GetChildren() do
            if child:IsA("GuiObject") and child.Name ~= "UIGridLayout" then
                child:Destroy()
            end
        end

        for _, skinId in Config.COSMETIC_ORDER do
            local cfg = Config.COSMETICS[skinId]
            if not cfg then continue end

            local owned     = false
            for _, id in _ownedSkins do
                if id == skinId then owned = true; break end
            end
            -- Gamepass skins are always shown (player can click to purchase)
            local isGP      = cfg.unlockType == "gamepass"
            local equipped  = skinId == _currentSkin

            local btn = Instance.new("TextButton")
            btn.Name             = skinId
            btn.BackgroundColor3 = equipped and Color3.fromRGB(242, 168, 28)
                                             or (owned and Color3.fromRGB(90, 60, 20)
                                                        or Color3.fromRGB(40, 30, 20))
            btn.TextColor3       = owned and Color3.new(1,1,1) or Color3.fromRGB(120, 100, 80)
            btn.Font             = Enum.Font.Gotham
            btn.TextScaled       = true
            btn.Text             = cfg.displayName .. (equipped and "\n✓" or (isGP and not owned and "\n🔒 Gamepass" or ""))
            btn.Parent           = grid
            Instance.new("UICorner").Parent = btn

            -- Color swatch in background
            btn.BackgroundColor3 = cfg.color1 :: Color3

            -- Darken if not owned
            if not owned then
                local overlay = Instance.new("Frame")
                overlay.Size                 = UDim2.fromScale(1, 1)
                overlay.BackgroundColor3     = Color3.new(0, 0, 0)
                overlay.BackgroundTransparency = 0.55
                overlay.ZIndex               = btn.ZIndex + 1
                overlay.BorderSizePixel      = 0
                overlay.Parent               = btn
                Instance.new("UICorner").Parent = overlay
            end

            if owned then
                btn.Activated:Connect(function()
                    RequestEquip:FireServer(skinId)
                    _currentSkin = skinId
                    rebuildGrid()
                end)
            elseif isGP then
                local gpId = (Config.MONETIZATION :: {[string]: number})[cfg.unlockValue :: string] or 0
                if gpId > 0 then
                    btn.Activated:Connect(function()
                        game:GetService("MarketplaceService"):PromptGamePassPurchase(localPlayer, gpId)
                    end)
                end
            end
        end
    end

    rebuildGrid()

    -- Store rebuild for WardrobeDataSync updates
    sg:GetAttributeChangedSignal("_rebuild"):Connect(rebuildGrid)

    return sg
end

-- Open wardrobe (called from WardrobePad ProximityPrompt on client)
local OpenWardrobe = Remotes:FindFirstChild("OpenWardrobe") :: RemoteEvent?
if not OpenWardrobe then
    OpenWardrobe = Instance.new("RemoteEvent")
    OpenWardrobe.Name   = "OpenWardrobe"
    OpenWardrobe.Parent = Remotes
end

(OpenWardrobe :: RemoteEvent).OnClientEvent:Connect(function()
    if not _wardrobeGui then
        _wardrobeGui = buildWardrobeGui()
    end
    _wardrobeGui.Enabled = not _wardrobeGui.Enabled
end)
```

---

### 1G — WardrobePad ProximityPrompt wiring (server Script)

**Location:** `ServerScriptService.WardrobeWirer` (new Script)

```lua
--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OpenWardrobe = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenWardrobe") :: RemoteEvent

local function wireWardrobePad(pad: Instance)
    local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then
        prompt = Instance.new("ProximityPrompt")
        prompt.ActionText            = "Wardrobe"
        prompt.ObjectText            = "Wardrobe Pedestal"
        prompt.HoldDuration          = 0
        prompt.MaxActivationDistance = 8
        prompt.Parent                = pad
    end
    prompt.Triggered:Connect(function(player: Player)
        OpenWardrobe:FireClient(player)
    end)
end

for _, pad in CollectionService:GetTagged("WardrobePad") do
    wireWardrobePad(pad)
end
CollectionService:GetInstanceAddedSignal("WardrobePad"):Connect(wireWardrobePad)
```

---

### 1H — OpenWardrobe RemoteEvent

Add to the RemoteEvent creation block (step 1E) or create separately:

```lua
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not Remotes:FindFirstChild("OpenWardrobe") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "OpenWardrobe"
    re.Parent = Remotes
end
```

---

### Luau verification

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local results = {}
local issues  = {}

-- Remotes
for _, name in {"RequestEquip", "EquippedSkinChanged", "WardrobeDataSync", "OpenWardrobe"} do
    local r = RS.Remotes:FindFirstChild(name)
    if r then table.insert(results, "Remote: " .. name)
    else  table.insert(issues, "MISSING Remote: " .. name) end
end

-- CosmeticService
local cs = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CosmeticService")
if cs and cs:IsA("ModuleScript") then
    local src  = cs.Source
    local lines = select(2, src:gsub("\n","")) + 1
    local ok = src:find("--!strict") and src:find("CheckAndGrantUnlocks") and src:find("isUnlocked") and src:find("RequestEquip")
    if ok then table.insert(results, "CosmeticService " .. lines .. " lines")
    else   table.insert(issues,  "CosmeticService missing symbols") end
else
    table.insert(issues, "MISSING CosmeticService ModuleScript")
end

-- CosmeticsRunner
local cr = SSS:FindFirstChild("CosmeticsRunner")
if cr and cr:IsA("Script") then table.insert(results, "CosmeticsRunner Script")
else table.insert(issues, "MISSING CosmeticsRunner") end

-- WardrobeWirer
local ww = SSS:FindFirstChild("WardrobeWirer")
if ww and ww:IsA("Script") then table.insert(results, "WardrobeWirer Script")
else table.insert(issues, "MISSING WardrobeWirer") end

-- CosmeticController
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local cc  = SPS and SPS:FindFirstChild("CosmeticController")
if cc and cc:IsA("LocalScript") then
    local hasSkin = cc.Source:find("applySkin") ~= nil
    local hasGui  = cc.Source:find("WardrobeGui") ~= nil
    if hasSkin and hasGui then table.insert(results, "CosmeticController LocalScript")
    else table.insert(issues, "CosmeticController missing applySkin or WardrobeGui") end
else
    table.insert(issues, "MISSING CosmeticController LocalScript")
end

-- Config
local ok2, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
if ok2 and Config then
    local n = 0
    for _ in (Config.COSMETICS or {}) do n += 1 end
    if n == 7 then table.insert(results, "Config.COSMETICS 7 entries")
    else table.insert(issues, "Config.COSMETICS count=" .. n .. " (expected 7)") end
else
    table.insert(issues, "Config not loadable")
end

-- DataService
local ds = SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("DataService")
if ds then
    local src = ds.Source
    local hasCosm = src:find("cosmeticsUnlocked") ~= nil
    local hasSkin = src:find("equippedSkin") ~= nil
    local hasMig5 = src:find("%[5%]") ~= nil
    if hasCosm and hasSkin and hasMig5 then table.insert(results, "DataService: cosmeticsUnlocked + equippedSkin + migration[5]")
    else table.insert(issues, "DataService missing: cosm=" .. tostring(hasCosm) .. " skin=" .. tostring(hasSkin) .. " mig5=" .. tostring(hasMig5)) end
end

local out = "=== COSMETICS LUAU VERIFICATION ===\n"
out = out .. "PASSED: " .. #results .. " ISSUES: " .. #issues .. "\n\n"
out = out .. table.concat(results, "\n")
if #issues > 0 then out = out .. "\n\nISSUES:\n" .. table.concat(issues, "\n") end
return out
```

---

## TASK 2 — world-builder

Deploy WardrobePad at all 6 plots.

---

### 2A — Confirm template

```lua
local t = game:GetService("ReplicatedStorage"):FindFirstChild("Templates")
local wp = t and t:FindFirstChild("WardrobePedestal")
return wp and ("WardrobePedestal template: " .. wp.ClassName .. " children=" .. #wp:GetChildren()) or "MISSING — build primitive pedestal"
```

If the template is missing, build a simple pedestal:
- Base cylinder: Size (1, 4, 4), Material=SmoothPlastic, Color=#7A4A22 (Propolis Brown)
- Mirror disc: Size (0.3, 5, 5), Material=SmoothPlastic, Color=#1A1A1A with Reflectance=0.6
- Honey Gold rim ring: Size (0.5, 5.5, 5.5), Material=Neon, Color=#F2A81C, Transparency=0.4
- Model all three as `WardrobePedestal` with PrimaryPart = Base cylinder

---

### 2B — WardrobePad placement

**Position:** local offset **(−30, 5, −45)** from plot centre — beside the front-left corner of the hex lattice, near the Landing Board area. This places it where players naturally walk when arriving at their plot.

| Plot | PlotIndex | Absolute Position |
|------|-----------|-------------------|
| 1 | 1 | (−280, 11.5, −45) |
| 2 | 2 | (−180, 11.5, −45) |
| 3 | 3 | ( −80, 11.5, −45) |
| 4 | 4 | ( +20, 11.5, −45) |
| 5 | 5 | (+120, 11.5, −45) |
| 6 | 6 | (+220, 11.5, −45) |

*X = plotX + (−30), Y = 11.5, Z = −45*

```lua
local CS        = game:GetService("CollectionService")
local templates = game:GetService("ReplicatedStorage").Templates
local wpTemplate = templates:FindFirstChild("WardrobePedestal")
if not wpTemplate then error("WardrobePedestal template missing") end

local PLOT_X = {-250, -150, -50, 50, 150, 250}
local LOCAL_X_OFFSET = -30
local BASE_Y = 11.5
local BASE_Z = -45

for i, xPos in PLOT_X do
    local exists = false
    for _, tagged in CS:GetTagged("WardrobePad") do
        if tagged:GetAttribute("PlotIndex") == i then exists = true; break end
    end
    if not exists then
        local clone = wpTemplate:Clone()
        clone.Name  = "WardrobePad_Plot" .. i
        local absX  = xPos + LOCAL_X_OFFSET
        if clone:IsA("Model") and clone.PrimaryPart then
            clone:SetPrimaryPartCFrame(CFrame.new(absX, BASE_Y, BASE_Z))
        elseif clone:IsA("BasePart") then
            clone.Position = Vector3.new(absX, BASE_Y, BASE_Z)
        end
        CS:AddTag(clone, "WardrobePad")
        clone:SetAttribute("PlotIndex", i)
        clone.Parent = workspace
        print("Placed WardrobePad PlotIndex=" .. i)
    end
end
return "WardrobePad placement done"
```

---

### 2C — World-builder verification

```lua
local CS = game:GetService("CollectionService")
local pads = CS:GetTagged("WardrobePad")
local issues = {}
if #pads ~= 6 then
    table.insert(issues, "FAIL: Expected 6 WardrobePad, found " .. #pads)
end
local seen: {[number]: boolean} = {}
for _, p in pads do
    local idx = p:GetAttribute("PlotIndex") :: number?
    if idx then
        if seen[idx] then table.insert(issues, "DUPLICATE PlotIndex=" .. idx)
        else seen[idx] = true end
    else
        table.insert(issues, "MISSING PlotIndex on " .. p.Name)
    end
end
for i = 1, 6 do
    if not seen[i] then table.insert(issues, "MISSING WardrobePad for plot " .. i) end
end
if #issues == 0 then
    return "PASS: 6 WardrobePad correctly tagged and indexed"
end
return "ISSUES:\n" .. table.concat(issues, "\n")
```

---

## Unlock tracking hooks summary

These edits are REQUIRED for unlock conditions to advance. Add them after the main dispatch is in place:

| Profile Field | Where Incremented | Unlocks |
|--------------|-------------------|---------|
| `lifetimeHoney` | ResourceService — when honey credited | bee_golden at 50,000 |
| `molassesRepels` | ThreatService — on successful Molasses repel | bee_night at 3 |
| `generation` | SwarmService.performSwarm — already done in cycle6_swarm | bee_autumn at 2 |
| `floor3_built` | Checked live via PlotRoot attribute — no counter needed | bee_crystal |
| Gamepass | MarketplaceService.UserOwnsGamePassAsync — checked on equip | bee_moon, bee_arctic |

After each `lifetimeHoney` or `molassesRepels` increment, call:
```lua
CosmeticService.CheckAndGrantUnlocks(player)
```
This is fire-and-forget via `task.spawn` to avoid blocking the calling service.

---

## Executor notes

1. **`bee_moon` and `bee_arctic` Gamepass IDs are 0** until the user creates them in Creator Dashboard. The WardrobeGui shows them greyed with "🔒 Gamepass" text and calls `PromptGamePassPurchase` when clicked. With ID=0 the prompt is skipped (gpId > 0 check in CosmeticController). They become live the moment real IDs are pasted into Config.MONETIZATION.

2. **BeePart tagging**: The bee character model used for forager bees should have its visible parts tagged "BeePart" via CollectionService. If the bee visual is built purely from the player character parts, adjust `applySkin` to target the character's HumanoidRootPart and its children instead.

3. **CosmeticService.CheckAndGrantUnlocks** is cheap (one profile read + loop over 7 skins). Call it after any honey credit or Molasses repel. It no-ops if nothing new was earned.

4. **Generation field dependency**: `bee_autumn` requires `profile.generation >= 2`. This field comes from cycle6_swarm_dispatch. Execute that dispatch before this one.
