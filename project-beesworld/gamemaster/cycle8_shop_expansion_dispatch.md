# Cycle 8 — Shop Expansion Dispatch

**Agents:** luau-scripter + ui-designer  
**Target:** Expand ShopGui from 2 items to a full multi-tab economy hub  
**Part delta:** +0 (pure script/UI, no world parts)  
**DataService version:** v8 → v9 (adds consumables inventory, plot flags)  
**Prerequisites:** All cycle 1–7 dispatches executed; DataService v8 live.

---

## Overview

The shop currently exposes only PropMolis exchange and Structure tier upgrades. This dispatch adds:

1. **Consumables tab** — 5 purchasable boosts with real gameplay impact  
   - Royal Jelly Flask (Developer Product) — instant +200 Royal Jelly  
   - Honey Booster x2 (Developer Product) — doubles harvest yields for 5 min  
   - Foraging Zeal (Developer Product) — foraging trip time −30% for 10 min  
   - Smoker Refill (Honey purchase) — refills Smoker with 3 charges  
   - Pollen Packet (Honey purchase) — spawns +12 pollen on your plot instantly  

2. **Plot Flags tab** — personalisation; 6 flag skins purchasable with Honey; one equipped per plot, visible to all players via a SurfaceGui billboard  

3. **Gamepass Perks tab** — read-only display of the 4 gamepasses (VIP / DoubleHoney / AutoHarvest / ExtraRouteSlot) with owned/unowned state and Roblox purchase prompt  

4. **UI overhaul** — ShopGui gets tab bar (Consumables / Flags / Upgrades / Perks), scrolling content frames, quantity badges on Developer Products

---

## Step 1 — DataService v8 → v9

Run in Studio Command Bar:

```lua
-- Step 1: extend PROFILE_TEMPLATE and bump version
local SSS = game:GetService("ServerScriptService")
local DS = SSS.Systems:FindFirstChild("DataService")
assert(DS, "DataService not found")

-- Clone-replace to bust require() cache
local clone = DS:Clone()
clone.Name = "DataService_new"
DS.Parent = nil

-- Read source and patch
local src = clone.Source

-- 1a. Bump version constant
src = src:gsub(
    'local CURRENT_VERSION = 8',
    'local CURRENT_VERSION = 9'
)

-- 1b. Add v9 fields to PROFILE_TEMPLATE (after achievementsUnlocked line)
src = src:gsub(
    '(achievementsUnlocked%s*=%s*%{%})',
    '%1,\n\t\tconsumables = {\n\t\t\thoneyBoosterExpiry = 0,\n\t\t\tforagingZealExpiry = 0,\n\t\t\tsmokerCharges = 0,\n\t\t},\n\t\tequippedFlag = "flag_default",'
)

-- 1c. Add migration block for v8→v9 (after the v7→v8 block)
local migration_v8v9 = [[
        [9] = function(profile)
            if not profile.data.consumables then
                profile.data.consumables = {
                    honeyBoosterExpiry = 0,
                    foragingZealExpiry = 0,
                    smokerCharges = 0,
                }
            end
            if not profile.data.equippedFlag then
                profile.data.equippedFlag = "flag_default"
            end
        end,]]

-- Insert before the closing bracket of the MIGRATIONS table
src = src:gsub(
    '(MIGRATIONS%s*=%s*%{.-)(%s*%}%s*%-%-?%s*end migrations)',
    function(a, b)
        -- find last migration entry and insert after
        return a .. "\n" .. migration_v8v9 .. b
    end
)

clone.Source = src
clone.Name = "DataService"
clone.Parent = SSS.Systems

print("DataService v9 installed — consumables + equippedFlag added")
```

**Verify:**
```lua
local DS = game:GetService("ServerScriptService").Systems.DataService
print("Version line:", DS.Source:match("CURRENT_VERSION = (%d+)"))
print("consumables in template:", DS.Source:find("smokerCharges") and "YES" or "NO")
print("equippedFlag in template:", DS.Source:find("equippedFlag") and "YES" or "NO")
```
Expected: `Version line: 9`, both YES.

---

## Step 2 — Config additions

Run in Studio Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local Config = RS.Modules:FindFirstChild("Config")
assert(Config, "Config not found")

local clone = Config:Clone()
clone.Name = "Config_new"
Config.Parent = nil

local src = clone.Source

-- 2a. Add CONSUMABLES catalogue (after MONETIZATION block or before final return)
local consumables_block = [[

-- ============================================================
-- CONSUMABLES
-- ============================================================
Config.CONSUMABLES = {
    -- Developer Product consumables (purchased with Robux)
    {
        id              = "royal_jelly_flask",
        name            = "Royal Jelly Flask",
        description     = "Instantly grants +200 Royal Jelly.",
        icon            = "⚗️",
        devProductId    = Config.MONETIZATION.products.HoneyPackSmall, -- reuse until creator sets real IDs
        currency        = "robux",
        effect          = "instant_royal_jelly",
        amount          = 200,
    },
    {
        id              = "honey_booster",
        name            = "Honey Booster ×2",
        description     = "All harvests yield double honey for 5 minutes.",
        icon            = "🍯",
        devProductId    = Config.MONETIZATION.products.HoneyPackSmall,
        currency        = "robux",
        effect          = "honey_booster",
        duration        = 300, -- seconds
    },
    {
        id              = "foraging_zeal",
        name            = "Foraging Zeal",
        description     = "Bees return 30% faster for 10 minutes.",
        icon            = "💨",
        devProductId    = Config.MONETIZATION.products.RoyalJellyPackSmall,
        currency        = "robux",
        effect          = "foraging_zeal",
        duration        = 600,
    },
    -- Honey-currency consumables
    {
        id              = "smoker_refill",
        name            = "Smoker Refill",
        description     = "Restores 3 Smoker charges to repel bear attacks.",
        icon            = "💨",
        currency        = "honey",
        cost            = 500,
        effect          = "smoker_charges",
        amount          = 3,
    },
    {
        id              = "pollen_packet",
        name            = "Pollen Packet",
        description     = "Instantly adds 12 pollen to your plot's reserve.",
        icon            = "🌼",
        currency        = "honey",
        cost            = 350,
        effect          = "instant_pollen",
        amount          = 12,
    },
}

-- ============================================================
-- PLOT FLAGS
-- ============================================================
Config.PLOT_FLAGS = {
    {
        id          = "flag_default",
        name        = "Honeycomb Banner",
        description = "The classic yellow-and-brown hive flag.",
        cost        = 0, -- free
        color1      = Color3.fromRGB(242, 168, 28),  -- Honey Gold
        color2      = Color3.fromRGB(122, 74,  34),  -- Propolis Brown
        pattern     = "honeycomb",
    },
    {
        id          = "flag_royal",
        name        = "Royal Crest",
        description = "Golden crown on deep violet — for the discerning apiarist.",
        cost        = 2000,
        color1      = Color3.fromRGB(242, 168, 28),
        color2      = Color3.fromRGB(80,  0,  120),
        pattern     = "crown",
    },
    {
        id          = "flag_night",
        name        = "Midnight Bloom",
        description = "Pale blossoms on indigo — unlocks with Night Bee skin.",
        cost        = 1500,
        color1      = Color3.fromRGB(200, 220, 255),
        color2      = Color3.fromRGB(20,  20,  80),
        pattern     = "bloom",
    },
    {
        id          = "flag_crystal",
        name        = "Crystal Spire",
        description = "Icy blue and silver — for those who built the third floor.",
        cost        = 3000,
        color1      = Color3.fromRGB(180, 230, 255),
        color2      = Color3.fromRGB(90,  140, 200),
        pattern     = "spire",
    },
    {
        id          = "flag_ember",
        name        = "Ember March",
        description = "Warm autumn orange and charcoal.",
        cost        = 1200,
        color1      = Color3.fromRGB(220, 100, 30),
        color2      = Color3.fromRGB(50,  50,  50),
        pattern     = "ember",
    },
    {
        id          = "flag_molasses",
        name        = "Bear's Truce",
        description = "Earned only by ending the bear's reign. Rare.",
        cost        = 0,  -- free but gated: requires molassesEnd achievement
        requiresAchievement = "molasses_end",
        color1      = Color3.fromRGB(100, 60,  20),
        color2      = Color3.fromRGB(200, 180, 140),
        pattern     = "pawprint",
    },
}
]]

-- Insert before final `return Config`
src = src:gsub('(return Config%s*$)', consumables_block .. '\n%1')

clone.Source = src
clone.Name = "Config"
clone.Parent = RS.Modules

print("Config updated — CONSUMABLES and PLOT_FLAGS added")
```

**Verify:**
```lua
local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
print("Consumables:", #Config.CONSUMABLES)
print("Flags:", #Config.PLOT_FLAGS)
```
Expected: `Consumables: 5`, `Flags: 6`.

---

## Step 3 — ConsumableService (ServerScriptService.Systems)

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local MS = Instance.new("ModuleScript")
MS.Name = "ConsumableService"
MS.Parent = SSS.Systems
MS.Source = [[
--!strict
-- ConsumableService — handles consumable purchases and active-effect tracking
local ConsumableService = {}

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local Config       = require(RS.Modules.Config)
local DataService  -- lazy to avoid circular require

local Remotes      = RS.Remotes
local PurchaseConsumable = Remotes:WaitForChild("PurchaseConsumable")  -- client→server
local ConsumableSync     = Remotes:WaitForChild("ConsumableSync")      -- server→client

-- Active booster timers: [userId] = {honeyBoostEnd, zealEnd}
local _activeBoosts: {[number]: {honeyBoostEnd: number, zealEnd: number}} = {}

local function getBoosts(userId: number)
    if not _activeBoosts[userId] then
        _activeBoosts[userId] = {honeyBoostEnd = 0, zealEnd = 0}
    end
    return _activeBoosts[userId]
end

-- ── Public query methods (called by other services) ──────────────────────────

function ConsumableService.HoneyMultiplier(player: Player): number
    local b = getBoosts(player.UserId)
    return (b.honeyBoostEnd > os.time()) and 2 or 1
end

function ConsumableService.ForagingSpeedMult(player: Player): number
    local b = getBoosts(player.UserId)
    return (b.zealEnd > os.time()) and 0.7 or 1.0
end

function ConsumableService.SmokerCharges(player: Player): number
    local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
    DataService = DS
    local profile = DS.GetProfile(player)
    if not profile then return 0 end
    return (profile.data.consumables and profile.data.consumables.smokerCharges) or 0
end

function ConsumableService.SpendSmokerCharge(player: Player): boolean
    local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
    DataService = DS
    local profile = DS.GetProfile(player)
    if not profile then return false end
    local c = profile.data.consumables
    if not c or c.smokerCharges < 1 then return false end
    c.smokerCharges -= 1
    DS.Save(player)
    return true
end

-- ── Internal effect application ──────────────────────────────────────────────

local function applyEffect(player: Player, consumable: any)
    local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
    DataService = DS
    local profile = DS.GetProfile(player)
    if not profile then return end
    local profile_data = profile.data
    local c = profile_data.consumables
    if not c then
        c = {honeyBoosterExpiry=0, foragingZealExpiry=0, smokerCharges=0}
        profile_data.consumables = c
    end

    local effect = consumable.effect
    local now    = os.time()

    if effect == "instant_royal_jelly" then
        profile_data.royalJelly = (profile_data.royalJelly or 0) + (consumable.amount or 200)

    elseif effect == "honey_booster" then
        local expiry = math.max(now, c.honeyBoosterExpiry) + (consumable.duration or 300)
        c.honeyBoosterExpiry = expiry
        getBoosts(player.UserId).honeyBoostEnd = expiry

    elseif effect == "foraging_zeal" then
        local expiry = math.max(now, c.foragingZealExpiry) + (consumable.duration or 600)
        c.foragingZealExpiry = expiry
        getBoosts(player.UserId).zealEnd = expiry

    elseif effect == "smoker_charges" then
        c.smokerCharges = math.min((c.smokerCharges or 0) + (consumable.amount or 3), 10)

    elseif effect == "instant_pollen" then
        profile_data.pollen = (profile_data.pollen or 0) + (consumable.amount or 12)
    end

    DS.Save(player)

    -- Sync active boost state to client
    local boosts = getBoosts(player.UserId)
    ConsumableSync:FireClient(player, {
        honeyBoostEnd = boosts.honeyBoostEnd,
        zealEnd       = boosts.zealEnd,
        smokerCharges = c.smokerCharges,
        royalJelly    = profile_data.royalJelly,
        pollen        = profile_data.pollen,
    })

    -- QuestService metric hook
    local ok, QS = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("QuestService"))
    if ok and QS then
        if effect == "smoker_charges" or effect == "honey_booster" or effect == "foraging_zeal" then
            QS.IncrementMetric(player, "consumablesBought", 1)
        end
    end
end

-- ── Honey-currency purchase handler ──────────────────────────────────────────

local function handleHoneyPurchase(player: Player, consumableId: string)
    local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
    DataService = DS
    local profile = DS.GetProfile(player)
    if not profile then return end

    local consumable
    for _, c in Config.CONSUMABLES do
        if c.id == consumableId and c.currency == "honey" then
            consumable = c
            break
        end
    end
    if not consumable then return end

    local honey = profile.data.honey or 0
    if honey < consumable.cost then
        -- Notify client: not enough honey
        local Notify = RS.Remotes:FindFirstChild("Notify")
        if Notify then
            Notify:FireClient(player, {
                message = "Not enough Honey! Need " .. consumable.cost,
                color   = Color3.fromRGB(220, 80, 80),
            })
        end
        return
    end

    profile.data.honey -= consumable.cost
    applyEffect(player, consumable)

    local Notify = RS.Remotes:FindFirstChild("Notify")
    if Notify then
        Notify:FireClient(player, {
            message = consumable.name .. " used!",
            color   = Color3.fromRGB(100, 210, 100),
        })
    end
end

-- ── Developer Product grant (called from ProcessReceipt) ─────────────────────

function ConsumableService.GrantDevProduct(player: Player, productId: number)
    for _, c in Config.CONSUMABLES do
        if c.currency == "robux" and c.devProductId == productId then
            applyEffect(player, c)
            return true
        end
    end
    return false
end

-- ── Remote listener ──────────────────────────────────────────────────────────

function ConsumableService.Start()
    PurchaseConsumable.OnServerEvent:Connect(function(player: Player, consumableId: string)
        if typeof(consumableId) ~= "string" then return end
        -- Only honey purchases come through this remote (Robux go through MarketplaceService)
        handleHoneyPurchase(player, consumableId)
    end)

    -- Restore active boosts on rejoin
    Players.PlayerAdded:Connect(function(player: Player)
        local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
        DataService = DS
        local profile = DS.GetProfile(player)
        if not profile then return end
        local c = profile.data.consumables
        if not c then return end
        local b = getBoosts(player.UserId)
        b.honeyBoostEnd = c.honeyBoosterExpiry or 0
        b.zealEnd       = c.foragingZealExpiry or 0
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        _activeBoosts[player.UserId] = nil
    end)
end

return ConsumableService
]]
print("ConsumableService created")
```

**Verify:**
```lua
local CS = game:GetService("ServerScriptService").Systems:FindFirstChild("ConsumableService")
print("ConsumableService:", CS and CS.ClassName or "MISSING")
local lines = select(2, CS.Source:gsub("\n","")) + 1
print("Lines:", lines)
```
Expected: ModuleScript, 130+ lines.

---

## Step 4 — FlagService (ServerScriptService.Systems)

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local MS = Instance.new("ModuleScript")
MS.Name = "FlagService"
MS.Parent = SSS.Systems
MS.Source = [[
--!strict
-- FlagService — manages per-plot decorative flag selection
local FlagService = {}

local RS         = game:GetService("ReplicatedStorage")
local Config     = require(RS.Modules.Config)
local Remotes    = RS.Remotes

local PurchaseFlag = Remotes:WaitForChild("PurchaseFlag")   -- client→server
local FlagSync     = Remotes:WaitForChild("FlagSync")       -- server→client (all players)

local DataService  -- lazy

local PATTERN_COLORS: {[string]: {Color3}} = {
    honeycomb = {Color3.fromRGB(242,168,28), Color3.fromRGB(122,74,34)},
    crown     = {Color3.fromRGB(242,168,28), Color3.fromRGB(80,0,120)},
    bloom     = {Color3.fromRGB(200,220,255), Color3.fromRGB(20,20,80)},
    spire     = {Color3.fromRGB(180,230,255), Color3.fromRGB(90,140,200)},
    ember     = {Color3.fromRGB(220,100,30), Color3.fromRGB(50,50,50)},
    pawprint  = {Color3.fromRGB(100,60,20), Color3.fromRGB(200,180,140)},
}

-- ── Update plot flag visuals via CollectionService ────────────────────────────

local function updatePlotFlag(plotIndex: number, flagId: string)
    local CS_svc = game:GetService("CollectionService")
    for _, obj in CS_svc:GetTagged("PlotFlag") do
        if obj:GetAttribute("PlotIndex") == plotIndex then
            -- PlotFlag parts are BillboardGui anchor parts on each plot
            -- Their children contain FlagPanel (a Part) and a BillboardGui
            local flagCfg
            for _, f in Config.PLOT_FLAGS do
                if f.id == flagId then flagCfg = f break end
            end
            if not flagCfg then return end
            local colors = PATTERN_COLORS[flagCfg.pattern] or PATTERN_COLORS.honeycomb
            local panel = obj:FindFirstChild("FlagPanel")
            if panel and panel:IsA("BasePart") then
                panel.Color = colors[1]
            end
            local pole = obj:FindFirstChild("FlagPole")
            if pole and pole:IsA("BasePart") then
                pole.Color = colors[2]
            end
            -- Update BillboardGui label
            local bg = obj:FindFirstChildOfClass("BillboardGui")
            if bg then
                local lbl = bg:FindFirstChildOfClass("TextLabel")
                if lbl then lbl.Text = flagCfg.name end
            end
            return
        end
    end
end

-- ── Server purchase / equip ───────────────────────────────────────────────────

local function handleEquip(player: Player, flagId: string)
    local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
    DataService = DS
    local profile = DS.GetProfile(player)
    if not profile then return end

    -- Find flag config
    local flagCfg
    for _, f in Config.PLOT_FLAGS do
        if f.id == flagId then flagCfg = f break end
    end
    if not flagCfg then return end

    -- Achievement gate
    if flagCfg.requiresAchievement then
        local unlocked = profile.data.achievementsUnlocked or {}
        local has = false
        for _, v in unlocked do if v == flagCfg.requiresAchievement then has = true break end end
        if not has then
            local Notify = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
            if Notify then
                Notify:FireClient(player, {message = "Unlock the '" .. flagCfg.requiresAchievement .. "' achievement first!", color=Color3.fromRGB(220,80,80)})
            end
            return
        end
    end

    -- Honey cost
    if flagCfg.cost and flagCfg.cost > 0 then
        -- Check if already purchased (stored in flagsOwned array)
        local owned = profile.data.flagsOwned or {}
        local alreadyOwned = false
        for _, v in owned do if v == flagId then alreadyOwned = true break end end
        if not alreadyOwned then
            if (profile.data.honey or 0) < flagCfg.cost then
                local Notify = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
                if Notify then
                    Notify:FireClient(player, {message = "Need " .. flagCfg.cost .. " Honey for this flag!", color=Color3.fromRGB(220,80,80)})
                end
                return
            end
            profile.data.honey -= flagCfg.cost
            table.insert(owned, flagId)
            profile.data.flagsOwned = owned
        end
    end

    profile.data.equippedFlag = flagId
    DS.Save(player)

    -- Update visuals for this player's plot
    local PlotService = require(game:GetService("ServerScriptService").Systems:FindFirstChild("PlotService"))
    local plotIndex = PlotService.GetPlotIndex(player)
    if plotIndex then
        updatePlotFlag(plotIndex, flagId)
        -- Sync to all clients
        FlagSync:FireAllClients(plotIndex, flagId)
    end

    local Notify = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
    if Notify then
        Notify:FireClient(player, {message = flagCfg.name .. " flag equipped!", color=Color3.fromRGB(100,210,100)})
    end
end

-- ── Restore flags on server start ────────────────────────────────────────────

function FlagService.RestorePlotFlags()
    local PlotService = require(game:GetService("ServerScriptService").Systems:FindFirstChild("PlotService"))
    for _, player in game:GetService("Players"):GetPlayers() do
        local DS = DataService or require(game:GetService("ServerScriptService").Systems.DataService)
        DataService = DS
        local profile = DS.GetProfile(player)
        if profile then
            local flagId = profile.data.equippedFlag or "flag_default"
            local plotIndex = PlotService.GetPlotIndex(player)
            if plotIndex then
                updatePlotFlag(plotIndex, flagId)
            end
        end
    end
end

function FlagService.Start()
    PurchaseFlag.OnServerEvent:Connect(function(player: Player, flagId: string)
        if typeof(flagId) ~= "string" then return end
        handleEquip(player, flagId)
    end)
end

return FlagService
]]
print("FlagService created")
```

---

## Step 5 — RemoteEvents for new systems

Run in Studio Command Bar:

```lua
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
assert(Remotes, "Remotes folder not found")

local toCreate = {
    "PurchaseConsumable",   -- client→server: buy honey-currency consumable
    "ConsumableSync",       -- server→client: active boosts state
    "PurchaseFlag",         -- client→server: buy/equip plot flag
    "FlagSync",             -- server→client (all): plotIndex, flagId
}

for _, name in toCreate do
    if not Remotes:FindFirstChild(name) then
        local re = Instance.new("RemoteEvent")
        re.Name = name
        re.Parent = Remotes
        print("Created: " .. name)
    else
        print("Already exists: " .. name)
    end
end
```

---

## Step 6 — PlotFlag world objects (flag poles on each plot)

Run in Studio Command Bar:

```lua
-- Build flag pole + panel for each of the 6 plots
-- Positioned at the back-right corner of each plot deck
-- Plot X positions: -250, -150, -50, +50, +150, +250
-- Flag pole base at (plotX + 30, 9.5, -170) — behind the deck rear fence

local CS  = game:GetService("CollectionService")
local WS  = game:GetService("Workspace")

local PLOT_X = {-250, -150, -50, 50, 150, 250}

for i, px in PLOT_X do
    local flagRoot = Instance.new("Model")
    flagRoot.Name = "PlotFlag_" .. i
    flagRoot.Parent = WS

    -- Pole
    local pole = Instance.new("Part")
    pole.Name       = "FlagPole"
    pole.Size       = Vector3.new(0.3, 8, 0.3)
    pole.Position   = Vector3.new(px + 30, 10.5, -170)
    pole.Anchored   = true
    pole.CanCollide = true
    pole.Material   = Enum.Material.Metal
    pole.Color      = Color3.fromRGB(150, 120, 80)
    pole.Parent     = flagRoot

    -- Flag panel
    local panel = Instance.new("Part")
    panel.Name       = "FlagPanel"
    panel.Size       = Vector3.new(2.4, 1.6, 0.15)
    panel.Position   = Vector3.new(px + 31.2, 14, -170)
    panel.Anchored   = true
    panel.CanCollide = false
    panel.Material   = Enum.Material.SmoothPlastic
    panel.Color      = Color3.fromRGB(242, 168, 28)  -- default: Honey Gold
    panel.Parent     = flagRoot

    -- BillboardGui (shows flag name above pole)
    local bg = Instance.new("BillboardGui")
    bg.Name          = "FlagLabel"
    bg.Size          = UDim2.new(0, 120, 0, 28)
    bg.StudsOffset   = Vector3.new(0, 5, 0)
    bg.AlwaysOnTop   = false
    bg.Adornee       = pole
    bg.Parent        = flagRoot

    local lbl = Instance.new("TextLabel")
    lbl.Size            = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text            = "Honeycomb Banner"
    lbl.TextColor3      = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.5
    lbl.Font            = Enum.Font.FredokaOne
    lbl.TextScaled      = true
    lbl.Parent          = bg

    -- Tag and attribute
    CS:AddTag(flagRoot, "PlotFlag")
    flagRoot:SetAttribute("PlotIndex", i)

    flagRoot.PrimaryPart = pole
end

print("6 plot flags created")
```

**Verify:**
```lua
local CS = game:GetService("CollectionService")
local flags = CS:GetTagged("PlotFlag")
print("PlotFlag count:", #flags)
for _, f in flags do
    print(f.Name, "PlotIndex=", f:GetAttribute("PlotIndex"))
end
```
Expected: 6 flags, PlotIndex 1–6.

---

## Step 7 — Expanded ShopGui (StarterGui)

Run in Studio Command Bar:

```lua
-- Rebuild ShopGui with tab bar: Consumables | Flags | Upgrades | Perks
local SG = game:GetService("StarterGui")

-- Remove old ShopGui if exists
local oldShop = SG:FindFirstChild("ShopGui")
if oldShop then oldShop:Destroy() end

local ShopGui = Instance.new("ScreenGui")
ShopGui.Name          = "ShopGui"
ShopGui.DisplayOrder  = 10
ShopGui.ResetOnSpawn  = false
ShopGui.Parent        = SG

-- ── Main panel ────────────────────────────────────────────────────────────────
local Main = Instance.new("Frame")
Main.Name               = "Main"
Main.Size               = UDim2.new(0, 520, 0, 480)
Main.Position           = UDim2.new(0.5, -260, 0.5, -240)
Main.BackgroundColor3   = Color3.fromRGB(50, 32, 14)
Main.BorderSizePixel    = 0
Main.Visible            = false
Main.Parent             = ShopGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = Main

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(242, 168, 28)
stroke.Thickness = 2
stroke.Parent    = Main

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = Main

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name             = "TitleLabel"
TitleLabel.Size             = UDim2.new(0.8, 0, 1, 0)
TitleLabel.Position         = UDim2.new(0.1, 0, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text             = "🐝  Hive Market"
TitleLabel.TextColor3       = Color3.fromRGB(232, 212, 154)
TitleLabel.Font             = Enum.Font.FredokaOne
TitleLabel.TextSize         = 22
TitleLabel.TextXAlignment   = Enum.TextXAlignment.Left
TitleLabel.Parent           = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name             = "CloseBtn"
CloseBtn.Size             = UDim2.new(0, 36, 0, 36)
CloseBtn.Position         = UDim2.new(1, -40, 0.5, -18)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 40)
CloseBtn.Text             = "✕"
CloseBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
CloseBtn.Font             = Enum.Font.GothamBold
CloseBtn.TextSize         = 16
CloseBtn.Parent           = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Name             = "TabBar"
TabBar.Size             = UDim2.new(1, 0, 0, 38)
TabBar.Position         = UDim2.new(0, 0, 0, 44)
TabBar.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
TabBar.BorderSizePixel  = 0
TabBar.Parent           = Main

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection  = Enum.FillDirection.Horizontal
tabLayout.SortOrder      = Enum.SortOrder.LayoutOrder
tabLayout.Padding        = UDim.new(0, 2)
tabLayout.Parent         = TabBar

local TAB_NAMES = {"Consumables", "Flags", "Upgrades", "Perks"}
local TAB_ICONS = {"⚗️", "🚩", "🏗️", "⭐"}
local tabButtons = {}

for i, name in TAB_NAMES do
    local btn = Instance.new("TextButton")
    btn.Name             = "Tab_" .. name
    btn.Size             = UDim2.new(0.25, -2, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(60, 40, 18)
    btn.Text             = TAB_ICONS[i] .. " " .. name
    btn.TextColor3       = Color3.fromRGB(180, 150, 100)
    btn.Font             = Enum.Font.FredokaOne
    btn.TextSize         = 13
    btn.LayoutOrder      = i
    btn.Parent           = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabButtons[name] = btn
end

-- Content area (scrolling frames per tab)
local ContentArea = Instance.new("Frame")
ContentArea.Name             = "ContentArea"
ContentArea.Size             = UDim2.new(1, -16, 1, -98)
ContentArea.Position         = UDim2.new(0, 8, 0, 90)
ContentArea.BackgroundTransparency = 1
ContentArea.ClipsDescendants = true
ContentArea.Parent           = Main

-- Helper: create scrolling frame for a tab
local function makeScrollFrame(tabName: string)
    local sf = Instance.new("ScrollingFrame")
    sf.Name                  = tabName .. "Frame"
    sf.Size                  = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency= 1
    sf.ScrollBarThickness    = 4
    sf.ScrollBarImageColor3  = Color3.fromRGB(242, 168, 28)
    sf.CanvasSize            = UDim2.new(0, 0, 0, 0)
    sf.Visible               = false
    sf.Parent                = ContentArea
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding    = UDim.new(0, 6)
    listLayout.SortOrder  = Enum.SortOrder.LayoutOrder
    listLayout.Parent     = sf
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
    end)
    return sf
end

local consumablesFrame = makeScrollFrame("Consumables")
local flagsFrame       = makeScrollFrame("Flags")
local upgradesFrame    = makeScrollFrame("Upgrades")
local perksFrame       = makeScrollFrame("Perks")

-- Show first tab by default
consumablesFrame.Visible = true

print("ShopGui rebuilt with tab bar")
```

---

## Step 8 — ShopController LocalScript

Run in Studio Command Bar:

```lua
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

-- Remove old ShopController
local old = SPS:FindFirstChild("ShopController")
if old then old:Destroy() end

local SC = Instance.new("LocalScript")
SC.Name   = "ShopController"
SC.Parent = SPS
SC.Source = [[
--!strict
-- ShopController — drives the expanded ShopGui

local Players         = game:GetService("Players")
local RS              = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService    = game:GetService("TweenService")
local Config          = require(RS.Modules.Config)

local player          = Players.LocalPlayer
local PlayerGui       = player:WaitForChild("PlayerGui")
local ShopGui         = PlayerGui:WaitForChild("ShopGui")
local Main            = ShopGui:WaitForChild("Main")
local TabBar          = Main:WaitForChild("TabBar")
local ContentArea     = Main:WaitForChild("ContentArea")

local Remotes         = RS:WaitForChild("Remotes")
local OpenShop        = Remotes:WaitForChild("OpenShop")
local PurchaseConsumable = Remotes:WaitForChild("PurchaseConsumable")
local PurchaseFlag       = Remotes:WaitForChild("PurchaseFlag")
local ConsumableSync     = Remotes:WaitForChild("ConsumableSync")
local FlagSync           = Remotes:WaitForChild("FlagSync")
local HudDataSync        = Remotes:WaitForChild("HudDataSync")

-- ── State ─────────────────────────────────────────────────────────────────────
local currentTab      = "Consumables"
local playerHoney     = 0
local activeBoostEnd  = {honey = 0, zeal = 0}
local smokerCharges   = 0

-- ── Tab switching ─────────────────────────────────────────────────────────────
local TAB_NAMES = {"Consumables", "Flags", "Upgrades", "Perks"}

local function switchTab(tabName: string)
    currentTab = tabName
    for _, name in TAB_NAMES do
        local frame = ContentArea:FindFirstChild(name .. "Frame")
        if frame then frame.Visible = (name == tabName) end
        local btn = TabBar:FindFirstChild("Tab_" .. name)
        if btn then
            btn.BackgroundColor3 = (name == tabName)
                and Color3.fromRGB(122, 74, 34)
                or  Color3.fromRGB(60, 40, 18)
            btn.TextColor3 = (name == tabName)
                and Color3.fromRGB(232, 212, 154)
                or  Color3.fromRGB(180, 150, 100)
        end
    end
end

for _, name in TAB_NAMES do
    local btn = TabBar:FindFirstChild("Tab_" .. name)
    if btn then
        btn.MouseButton1Click:Connect(function() switchTab(name) end)
    end
end

-- ── Close button ─────────────────────────────────────────────────────────────
Main.TitleBar.CloseBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

-- ── Open shop ─────────────────────────────────────────────────────────────────
OpenShop.OnClientEvent:Connect(function(tabName: string?)
    Main.Visible = true
    switchTab(tabName or "Consumables")
    refreshConsumablesTab()
    refreshFlagsTab()
    refreshUpgradesTab()
    refreshPerksTab()
end)

-- ── Helper: create item card ──────────────────────────────────────────────────
local function makeCard(parent: Instance, data: {
    icon: string,
    name: string,
    description: string,
    costText: string,
    canAfford: boolean,
    onBuy: () -> (),
    layoutOrder: number,
}): Frame
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, -8, 0, 72)
    card.BackgroundColor3 = Color3.fromRGB(70, 45, 18)
    card.BorderSizePixel  = 0
    card.LayoutOrder      = data.layoutOrder
    card.Parent           = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size              = UDim2.new(0, 52, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text              = data.icon
    iconLbl.TextSize          = 28
    iconLbl.Font              = Enum.Font.GothamBold
    iconLbl.Parent            = card

    local infoFrame = Instance.new("Frame")
    infoFrame.Size            = UDim2.new(1, -130, 1, -8)
    infoFrame.Position        = UDim2.new(0, 56, 0, 4)
    infoFrame.BackgroundTransparency = 1
    infoFrame.Parent          = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size              = UDim2.new(1, 0, 0, 26)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text              = data.name
    nameLbl.TextColor3        = Color3.fromRGB(232, 212, 154)
    nameLbl.Font              = Enum.Font.FredokaOne
    nameLbl.TextSize          = 16
    nameLbl.TextXAlignment    = Enum.TextXAlignment.Left
    nameLbl.Parent            = infoFrame

    local descLbl = Instance.new("TextLabel")
    descLbl.Size              = UDim2.new(1, 0, 0, 30)
    descLbl.Position          = UDim2.new(0, 0, 0, 28)
    descLbl.BackgroundTransparency = 1
    descLbl.Text              = data.description
    descLbl.TextColor3        = Color3.fromRGB(160, 130, 90)
    descLbl.Font              = Enum.Font.Gotham
    descLbl.TextSize          = 12
    descLbl.TextWrapped       = true
    descLbl.TextXAlignment    = Enum.TextXAlignment.Left
    descLbl.Parent            = infoFrame

    local buyBtn = Instance.new("TextButton")
    buyBtn.Size             = UDim2.new(0, 100, 0, 38)
    buyBtn.Position         = UDim2.new(1, -108, 0.5, -19)
    buyBtn.BackgroundColor3 = data.canAfford
        and Color3.fromRGB(180, 120, 30)
        or  Color3.fromRGB(80, 60, 40)
    buyBtn.TextColor3       = data.canAfford
        and Color3.fromRGB(232, 212, 154)
        or  Color3.fromRGB(120, 100, 70)
    buyBtn.Text             = data.costText
    buyBtn.Font             = Enum.Font.FredokaOne
    buyBtn.TextSize         = 14
    buyBtn.Parent           = card
    Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 6)

    if data.canAfford then
        buyBtn.MouseButton1Click:Connect(data.onBuy)
    end

    return card
end

-- ── Consumables tab ───────────────────────────────────────────────────────────
function refreshConsumablesTab()
    local frame = ContentArea:FindFirstChild("ConsumablesFrame")
    if not frame then return end
    for _, child in frame:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Active boosts status bar
    local now = os.time()
    if activeBoostEnd.honey > now or activeBoostEnd.zeal > now then
        local statusCard = Instance.new("Frame")
        statusCard.Size             = UDim2.new(1, -8, 0, 44)
        statusCard.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
        statusCard.LayoutOrder      = 0
        statusCard.Parent           = frame
        Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 8)
        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size = UDim2.new(1, -8, 1, 0)
        statusLbl.Position = UDim2.new(0, 8, 0, 0)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Text = "⚡ Active: " ..
            (activeBoostEnd.honey > now and ("Honey ×2 (" .. math.ceil(activeBoostEnd.honey - now) .. "s) ") or "") ..
            (activeBoostEnd.zeal > now and ("Foraging Zeal (" .. math.ceil(activeBoostEnd.zeal - now) .. "s)") or "")
        statusLbl.TextColor3 = Color3.fromRGB(100, 230, 100)
        statusLbl.Font = Enum.Font.Gotham
        statusLbl.TextSize = 12
        statusLbl.TextXAlignment = Enum.TextXAlignment.Left
        statusLbl.Parent = statusCard
    end

    for i, c in Config.CONSUMABLES do
        local isRobux   = c.currency == "robux"
        local canAfford = isRobux or (playerHoney >= (c.cost or 0))
        local costText  = isRobux and "R$ Buy" or ("🍯 " .. (c.cost or 0))

        makeCard(frame, {
            icon        = c.icon or "📦",
            name        = c.name,
            description = c.description,
            costText    = costText,
            canAfford   = canAfford,
            layoutOrder = i,
            onBuy       = function()
                if isRobux then
                    MarketplaceService:PromptProductPurchase(player, c.devProductId)
                else
                    PurchaseConsumable:FireServer(c.id)
                end
            end,
        })
    end
end

-- ── Flags tab ─────────────────────────────────────────────────────────────────
function refreshFlagsTab()
    local frame = ContentArea:FindFirstChild("FlagsFrame")
    if not frame then return end
    for _, child in frame:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    for i, f in Config.PLOT_FLAGS do
        local isFree    = f.cost == 0 and not f.requiresAchievement
        local costText  = isFree and "Free" or (f.requiresAchievement and "🏆 Achievement" or ("🍯 " .. f.cost))
        local canAfford = isFree or (not f.requiresAchievement and playerHoney >= f.cost)

        makeCard(frame, {
            icon        = "🚩",
            name        = f.name,
            description = f.description .. (f.requiresAchievement and " (requires " .. f.requiresAchievement .. ")" or ""),
            costText    = costText,
            canAfford   = canAfford,
            layoutOrder = i,
            onBuy       = function()
                PurchaseFlag:FireServer(f.id)
            end,
        })
    end
end

-- ── Upgrades tab (carries over existing structure upgrade UI) ─────────────────
function refreshUpgradesTab()
    local frame = ContentArea:FindFirstChild("UpgradesFrame")
    if not frame then return end
    for _, child in frame:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    -- Existing structure tiers from Config.STRUCTURES
    local i = 1
    for structName, tiers in Config.STRUCTURES do
        if typeof(tiers) == "table" and tiers[1] then
            for tierIdx, tier in tiers do
                if tier.cost then
                    makeCard(frame, {
                        icon        = "🏗️",
                        name        = structName .. " Tier " .. tierIdx,
                        description = (tier.description or "Structure upgrade"),
                        costText    = "🍯 " .. tier.cost,
                        canAfford   = playerHoney >= tier.cost,
                        layoutOrder = i,
                        onBuy       = function()
                            local BudBtn = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("PurchaseStructure")
                            if BudBtn then
                                BudBtn:FireServer(structName, tierIdx)
                            end
                        end,
                    })
                    i += 1
                end
            end
        end
    end

    if i == 1 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, -8, 0, 40)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "No structure upgrades available yet."
        emptyLbl.TextColor3 = Color3.fromRGB(160, 130, 90)
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.TextSize = 14
        emptyLbl.Parent = frame
    end
end

-- ── Perks tab (gamepass display) ─────────────────────────────────────────────
function refreshPerksTab()
    local frame = ContentArea:FindFirstChild("PerksFrame")
    if not frame then return end
    for _, child in frame:GetChildren() do
        if child:IsA("Frame") then child:Destroy() end
    end

    local PERKS = {
        {name = "VIP Hive",        desc = "+10% all earnings, exclusive bee skin, gold plot border.",          id = Config.MONETIZATION.gamepasses.VIP,           icon = "⭐"},
        {name = "Double Honey",    desc = "All honey harvests permanently yield double.",                      id = Config.MONETIZATION.gamepasses.DoubleHoney,   icon = "🍯"},
        {name = "Auto-Harvest",    desc = "Landing Boards harvest automatically every 120 seconds.",           id = Config.MONETIZATION.gamepasses.AutoHarvest,   icon = "🤖"},
        {name = "Extra Route Slot",desc = "Unlock a 4th foraging route slot (default is 3).",                  id = Config.MONETIZATION.gamepasses.ExtraRouteSlot,icon = "🗺️"},
        {name = "Moon Bee Skin",   desc = "Unlocks the mysterious Moon Bee cosmetic.",                         id = Config.MONETIZATION.gamepasses.MoonBee,       icon = "🌙"},
        {name = "Arctic Bee Skin", desc = "Unlocks the rare Arctic Bee cosmetic.",                             id = Config.MONETIZATION.gamepasses.ArcticBee,     icon = "❄️"},
    }

    for i, perk in PERKS do
        local owned = false
        if perk.id and perk.id ~= 0 then
            local ok, result = pcall(function()
                return game:GetService("MarketplaceService"):UserOwnsGamePassAsync(player.UserId, perk.id)
            end)
            if ok then owned = result end
        end

        makeCard(frame, {
            icon        = perk.icon,
            name        = perk.name .. (owned and " ✓" or ""),
            description = perk.desc,
            costText    = owned and "Owned" or "R$ Buy",
            canAfford   = true,
            layoutOrder = i,
            onBuy       = function()
                if not owned and perk.id and perk.id ~= 0 then
                    MarketplaceService:PromptGamePassPurchase(player, perk.id)
                end
            end,
        })
    end
end

-- ── HUD data sync — track honey for affordability ────────────────────────────
HudDataSync.OnClientEvent:Connect(function(data: any)
    if data and data.honey then
        playerHoney = data.honey
        -- Refresh visible tab if shop is open
        if Main.Visible then
            if currentTab == "Consumables" then refreshConsumablesTab()
            elseif currentTab == "Flags" then refreshFlagsTab()
            elseif currentTab == "Upgrades" then refreshUpgradesTab()
            end
        end
    end
end)

-- ── Consumable sync (boost timers) ───────────────────────────────────────────
ConsumableSync.OnClientEvent:Connect(function(data: any)
    if data then
        activeBoostEnd.honey = data.honeyBoostEnd or 0
        activeBoostEnd.zeal  = data.zealEnd or 0
        smokerCharges        = data.smokerCharges or 0
        if Main.Visible and currentTab == "Consumables" then
            refreshConsumablesTab()
        end
    end
end)

-- ── Flag sync ─────────────────────────────────────────────────────────────────
FlagSync.OnClientEvent:Connect(function(plotIndex: number, flagId: string)
    -- Update local flag visuals (handled by FlagController below)
end)

-- Initial tab state
switchTab("Consumables")
]]
print("ShopController installed")
```

---

## Step 9 — Hook ConsumableService and FlagService into game startup

Run in Studio Command Bar:

```lua
-- Find the main game server Script (GameService or GameManager) and add
-- ConsumableService.Start() + FlagService.Start() calls

local SSS = game:GetService("ServerScriptService")

-- Look for the main startup script
local startupScript
for _, child in SSS:GetChildren() do
    if child:IsA("Script") and (child.Name == "GameService" or child.Name == "GameManager" or child.Name == "Main") then
        startupScript = child
        break
    end
end

if not startupScript then
    -- Create a minimal startup connector if none found
    local connector = Instance.new("Script")
    connector.Name   = "ShopSystemsStart"
    connector.Parent = SSS
    connector.Source = [[
--!strict
-- Start new shop services
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")

local ConsumableService = require(Systems:WaitForChild("ConsumableService"))
local FlagService       = require(Systems:WaitForChild("FlagService"))

ConsumableService.Start()
FlagService.Start()

-- Restore flags after a brief delay for plots to load
task.delay(3, function()
    FlagService.RestorePlotFlags()
end)

print("[ShopSystems] ConsumableService + FlagService started")
]]
    print("Created ShopSystemsStart Script")
else
    -- Patch existing startup script
    local src = startupScript.Source
    if not src:find("ConsumableService") then
        src = src .. [[

-- Shop systems (cycle 8 expansion)
do
    local ConsumableService = require(script.Parent.Systems:FindFirstChild("ConsumableService"))
    local FlagService       = require(script.Parent.Systems:FindFirstChild("FlagService"))
    ConsumableService.Start()
    FlagService.Start()
    task.delay(3, FlagService.RestorePlotFlags)
end
]]
        startupScript.Source = src
        print("Patched " .. startupScript.Name .. " with shop service starts")
    else
        print("Startup already has ConsumableService — no change needed")
    end
end
```

---

## Step 10 — Hook ConsumableService multipliers into ResourceService and ForagingService

Run in Studio Command Bar:

```lua
-- Patch ResourceService: multiply harvest yield by ConsumableService.HoneyMultiplier
local SSS = game:GetService("ServerScriptService")
local RS_mod = SSS.Systems:FindFirstChild("ResourceService")
assert(RS_mod, "ResourceService not found")

local clone = RS_mod:Clone()
clone.Name = "ResourceService_new"
RS_mod.Parent = nil

local src = clone.Source

-- After 'local ResourceService = {}' or near top, add lazy require
if not src:find("ConsumableService") then
    src = src:gsub(
        '(local ResourceService%s*=%s*%{%})',
        '%1\nlocal _ConsumableService -- lazy'
    )
    src = src:gsub(
        '(local function getCS%(%))\n',
        ''  -- remove any existing, will add new one
    )
    -- Add helper before first function definition
    src = src:gsub(
        '(local ResourceService%s*=%s*%{%}\nlocal _ConsumableService %-%- lazy)',
        '%1\nlocal function getCS()\n    if not _ConsumableService then\n        local ok, s = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("ConsumableService"))\n        if ok then _ConsumableService = s end\n    end\n    return _ConsumableService\nend'
    )

    -- Find the honey credit line (profile.data.honey += amount or similar)
    -- Multiply by HoneyMultiplier
    src = src:gsub(
        '(profile%.data%.honey%s*[%+%-]=%s*)([%w%.%(%)]+)',
        function(op, amount)
            return op .. "(" .. amount .. " * (getCS() and getCS().HoneyMultiplier(player) or 1))"
        end
    )
end

clone.Source = src
clone.Name = "ResourceService"
clone.Parent = SSS.Systems
print("ResourceService patched with HoneyMultiplier")
```

```lua
-- Patch ForagingService: multiply trip time by ConsumableService.ForagingSpeedMult
local SSS = game:GetService("ServerScriptService")
local FS  = SSS.Systems:FindFirstChild("ForagingService") or SSS.Systems:FindFirstChild("DanceService")
if not FS then print("ForagingService/DanceService not found — skip") return end

local clone = FS:Clone()
clone.Name = FS.Name .. "_new"
FS.Parent  = nil

local src = clone.Source

if not src:find("ConsumableService") then
    src = src:gsub(
        '(local%s+%a+Service%s*=%s*%{%})',
        '%1\nlocal _ConsumableService\nlocal function getCS()\n    if not _ConsumableService then\n        local ok, s = pcall(require, game:GetService("ServerScriptService").Systems:FindFirstChild("ConsumableService"))\n        if ok then _ConsumableService = s end\n    end\n    return _ConsumableService\nend',
        1  -- only first occurrence
    )
    -- Multiply trip time
    src = src:gsub(
        '(tripTime%s*=%s*)([%w%.%(%)]+)',
        function(a, b)
            return a .. "(" .. b .. " * (getCS() and getCS().ForagingSpeedMult(player) or 1))"
        end,
        1
    )
end

clone.Source = src
clone.Name   = FS.Name
clone.Parent = SSS.Systems
print("ForagingService patched with ForagingSpeedMult")
```

---

## Step 11 — Verification

Run in Studio Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SG  = game:GetService("StarterGui")
local CS_svc = game:GetService("CollectionService")

local results = {}
local issues  = {}

-- Services
for _, name in {"ConsumableService", "FlagService"} do
    local m = SSS.Systems:FindFirstChild(name)
    if m and m:IsA("ModuleScript") then
        table.insert(results, name .. " ✓ (" .. select(2, m.Source:gsub("\n","")) .. " lines)")
    else
        table.insert(issues, "MISSING: " .. name)
    end
end

-- DataService version
local DS = SSS.Systems:FindFirstChild("DataService")
if DS then
    local v = DS.Source:match("CURRENT_VERSION = (%d+)")
    table.insert(results, "DataService v" .. (v or "?"))
    if v ~= "9" then table.insert(issues, "DataService version should be 9") end
else
    table.insert(issues, "MISSING: DataService")
end

-- RemoteEvents
for _, name in {"PurchaseConsumable", "ConsumableSync", "PurchaseFlag", "FlagSync"} do
    local remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
    local re = remotes and remotes:FindFirstChild(name)
    if re then
        table.insert(results, "RemoteEvent:" .. name .. " ✓")
    else
        table.insert(issues, "MISSING RemoteEvent: " .. name)
    end
end

-- ShopGui
local sg = SG:FindFirstChild("ShopGui")
if sg then
    local tabBar = sg:FindFirstChild("Main") and sg.Main:FindFirstChild("TabBar")
    table.insert(results, "ShopGui ✓, tabs: " .. (tabBar and #tabBar:GetChildren() - 1 or 0))
else
    table.insert(issues, "MISSING: ShopGui")
end

-- Plot flags
local flags = CS_svc:GetTagged("PlotFlag")
table.insert(results, "PlotFlag parts: " .. #flags)
if #flags ~= 6 then table.insert(issues, "Expected 6 PlotFlag objects, found " .. #flags) end

-- Config
local cfg = require(RS.Modules.Config)
table.insert(results, "Config.CONSUMABLES: " .. #cfg.CONSUMABLES)
table.insert(results, "Config.PLOT_FLAGS: " .. #cfg.PLOT_FLAGS)
if #cfg.CONSUMABLES ~= 5 then table.insert(issues, "Expected 5 consumables") end
if #cfg.PLOT_FLAGS ~= 6 then table.insert(issues, "Expected 6 flags") end

print("=== SHOP EXPANSION VERIFICATION ===")
for _, r in results do print("✓ " .. r) end
if #issues > 0 then
    print("ISSUES:")
    for _, iss in issues do print("✗ " .. iss) end
else
    print("ALL CLEAR — shop expansion complete")
end
```

**Expected output:**
```
✓ ConsumableService ✓ (130+ lines)
✓ FlagService ✓ (100+ lines)
✓ DataService v9
✓ RemoteEvent:PurchaseConsumable ✓
✓ RemoteEvent:ConsumableSync ✓
✓ RemoteEvent:PurchaseFlag ✓
✓ RemoteEvent:FlagSync ✓
✓ ShopGui ✓, tabs: 4
✓ PlotFlag parts: 6
✓ Config.CONSUMABLES: 5
✓ Config.PLOT_FLAGS: 6
ALL CLEAR — shop expansion complete
```

---

## Summary

| Item | Detail |
|------|--------|
| Services added | ConsumableService, FlagService |
| Config additions | CONSUMABLES (5 items), PLOT_FLAGS (6 flags) |
| DataService bump | v8 → v9; adds `consumables{}` + `equippedFlag` |
| RemoteEvents | PurchaseConsumable, ConsumableSync, PurchaseFlag, FlagSync |
| ShopGui tabs | Consumables / Flags / Upgrades / Perks (4 tabs) |
| Plot flags | 6 flag poles placed at each plot (+12 world parts) |
| Gameplay hooks | HoneyMultiplier() + ForagingSpeedMult() multipliers wired into ResourceService + ForagingService |
| Part delta | +12 (flag poles/panels) → ~3,865/5,000 |
| QuestService hook | consumablesBought metric incremented on each purchase |

**Gameplay value added:**
- 3 Robux consumables (real revenue items once product IDs are set in Config.MONETIZATION)  
- 2 Honey consumables giving players meaningful late-game Honey sinks  
- 6 plot flags for personalisation and player expression  
- 6 gamepass perks displayed with purchase prompts  
- Active boost timer display so players know what's running  
- HoneyMultiplier + ForagingSpeedMult wired into the real economy for genuine gameplay impact
