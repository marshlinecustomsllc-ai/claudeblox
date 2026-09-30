# CYCLE 5 — BudButton Full Coverage + ShopGui Dispatch

> **Source of truth:** `architecture.md` — Tags table (BudButton, 8/plot), StructureService
> spec (line ~282), RemoteEvents table (RequestPurchase, line ~300), Structure tiers tables
> (Dance Floor line ~645, Propolis Kiln line ~657, Apiary Shed line ~665).
>
> **Prerequisite:** Cycles 3 and 4 complete in Studio. Bug #9 fixed. Hub v2 built.
>
> **What this dispatch covers:**
> 1. **world-builder** — place 8 BudButton meshes per plot (all 6 plots = 48 total buttons)
> 2. **luau-scripter** — extend StructureService for DanceFloor tier upgrades + propolis
>    exchange; create ShopGui ScreenGui with propolis purchase panel
> 3. **ui-designer** — apply Warm Wax polish to ShopGui after code review
>
> **What this dispatch intentionally skips:**
> - WardrobePad + Cosmetics (blocked on CosmeticService — cycle 8+)
> - SwarmPerch wiring (blocked on SwarmService — cycle 7)
> - Floor 2/3 BudButton wiring (using ProximityPrompts from cycle4_floor23 dispatch)

---

## CURRENT STATE

**What StructureService already handles** (from architecture build, confirmed via state.json):
- `apiaryShed_T2` and `apiaryShed_T3` purchase + model swap
- `proPolisKiln_T2` and `proPolisKiln_T3` purchase + model swap
- Wires `RequestPurchase` OnServerEvent

**What is missing:**
- `danceFloor_T2` through `danceFloor_T5` — NOT wired in StructureService
- Physical BudButton meshes may not be placed (architecture lists 8/plot as required)
- ShopGui for propolis exchange — does not exist
- `Config.STRUCTURES` likely only has Shed/Kiln entries

**Verify before building:**
```lua
-- Check what Config.STRUCTURES currently contains
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local ids = {}
if cfg.STRUCTURES then
    for id, _ in cfg.STRUCTURES do table.insert(ids, id) end
    table.sort(ids)
end
return "STRUCTURES keys: " .. table.concat(ids, ", ")
```

```lua
-- Check BudButton count in world
local CS = game:GetService("CollectionService")
local buttons = CS:GetTagged("BudButton")
return "BudButton count: " .. #buttons .. " (expect 48 = 8 × 6 plots)"
```

---

## STRUCTURE ITEM IDs AND COSTS

The complete `Config.STRUCTURES` table. This is the canonical server whitelist — nothing
not in this table can be purchased via `RequestPurchase`.

```lua
Config.STRUCTURES = {
    -- ═══ DANCE FLOOR UPGRADES ═══
    -- Tier 1 (Bare Comb) is the starting state, no purchase needed
    danceFloor_T2 = {
        name        = "Polished Floor",
        honeyCost   = 900,
        propolisCost= 0,
        requires    = { danceFloorTier = 1 },
        effect      = { danceFloorTier = 2 },
        routeSlots  = 3,
        goldenZone  = 24,
    },
    danceFloor_T3 = {
        name        = "Scented Floor",
        honeyCost   = 7500,
        propolisCost= 0,
        requires    = { danceFloorTier = 2 },
        effect      = { danceFloorTier = 3 },
        routeSlots  = 4,
        goldenZone  = 30,
        decayMult   = 0.70,  -- routes decay 30% slower
    },
    danceFloor_T4 = {
        name        = "Resonant Floor",
        honeyCost   = 60000,
        propolisCost= 0,
        requires    = { danceFloorTier = 3 },
        effect      = { danceFloorTier = 4 },
        routeSlots  = 6,
        goldenZone  = 38,
        qualityBonus= 0.10,  -- +10% all route quality
    },
    danceFloor_T5 = {
        name        = "Grand Dance Floor",
        honeyCost   = 400000,
        propolisCost= 0,
        requires    = { danceFloorTier = 4 },
        effect      = { danceFloorTier = 5 },
        routeSlots  = 8,
        goldenZone  = 46,
        neverLost   = true,  -- Lost routes floor at Poor instead
    },

    -- ═══ APIARY SHED UPGRADES ═══
    apiaryShed_T2 = {
        name        = "Workshop",
        honeyCost   = 15000,
        propolisCost= 0,
        requires    = { apiaryShedTier = 1 },
        effect      = { apiaryShedTier = 2 },
        propolisRate= 180,   -- propolis exchange cost drops to 180 honey each
        unlocks     = "perkRespec",
    },
    apiaryShed_T3 = {
        name        = "Apothecary",
        honeyCost   = 150000,
        propolisCost= 0,
        requires    = { apiaryShedTier = 2 },
        effect      = { apiaryShedTier = 3 },
        propolisRate= 90,    -- propolis exchange drops to 90 honey each
        achievementBonus = 1,
    },

    -- ═══ PROPOLIS KILN UPGRADES ═══
    proPolisKiln_T2 = {
        name        = "Stone Kiln",
        honeyCost   = 6000,
        propolisCost= 0,
        requires    = { proPolisKilnTier = 1 },
        effect      = { proPolisKilnTier = 2 },
        conversionRate = 3,  -- 3 resin -> 1 propolis (was 4)
        rateCap     = 1.5,   -- propolis/s
    },
    proPolisKiln_T3 = {
        name        = "Wax-Sealed Kiln",
        honeyCost   = 90000,
        propolisCost= 0,
        requires    = { proPolisKilnTier = 2 },
        effect      = { proPolisKilnTier = 3 },
        conversionRate = 2,  -- 2 resin -> 1 propolis
        rateCap     = 6.0,
    },
}

-- Propolis exchange costs by Apiary Shed tier (NOT in STRUCTURES whitelist — handled
-- separately by ShopGui's RequestPurchase handler):
Config.PROPOLIS_EXCHANGE = {
    [1] = 400,   -- Lean-To: deliberately terrible
    [2] = 180,   -- Workshop
    [3] = 90,    -- Apothecary
}
```

---

## PROFILE FIELDS USED

Verify these fields exist in `Config.PROFILE_TEMPLATE` (or add them if missing):

```lua
-- These should already exist from original build; add any that are missing:
danceFloorTier   = 1,    -- 1..5
apiaryShedTier   = 1,    -- 1..3
proPolisKilnTier = 1,    -- 1..3
propolis         = 0,    -- propolis resource
resin            = 0,    -- resin resource (mined from Pine Treeline)
```

No DataService migration needed — these default to 1 or 0 correctly for existing profiles.

---

## TASK A: WORLD-BUILDER — BudButton Placement

> Place 8 BudButton meshes per plot (48 total). Each button is a physical in-world object
> tagged "BudButton" with ItemId/Cost/Requires/PlotIndex attributes.
> The BudButton template exists in ReplicatedStorage.Templates.Structures.BudButton.

### Step 0 — MCP survey

```lua
-- Find the BudButton template
local tmpl = game:GetService("ReplicatedStorage").Templates.Structures:FindFirstChild("BudButton")
return tmpl and "BudButton template: " .. tmpl.ClassName or "BudButton template NOT FOUND"
```

```lua
-- Find existing Apiary Shed and Propolis Kiln positions (need their X/Z for button placement)
local CS = game:GetService("CollectionService")
local results = {}
for _, obj in game:GetService("Workspace"):GetDescendants() do
    if obj.Name == "ApiaryShed" or obj.Name == "PropolisKiln" or
       obj.Name == "ApiaryShed_T1" or obj.Name == "PropolisKiln_T1" then
        table.insert(results, obj.Name .. ": " .. tostring(obj.Position))
    end
end
return #results > 0 and table.concat(results, "\n") or "Shed/Kiln not found by name — search broader"
```

### Step 1 — BudButton positions per plot

For each plot (X offsets: −250, −150, −50, +50, +150, +250 absolute):

**Dance Floor buttons** (4 buttons, stacked south of Dance Floor cell at local 0,0):
Dance Floor is at local (0, +6, Z). Buttons go south of it, descending tier:

| ItemId | Plot-local X | Plot-local Z | Y | Tier shown |
|--------|-------------|--------------|---|------------|
| danceFloor_T2 | 0 | −14 | 8 | T2: 900h |
| danceFloor_T3 | 0 | −19 | 8 | T3: 7.5k h |
| danceFloor_T4 | 0 | −24 | 8 | T4: 60k h |
| danceFloor_T5 | 0 | −29 | 8 | T5: 400k h |

(These are on the south edge of the comb deck, accessible from ground level)

**Apiary Shed buttons** (2 buttons, at local (−42, −30) ± a few studs):

| ItemId | Plot-local X | Plot-local Z | Y |
|--------|-------------|--------------|---|
| apiaryShed_T2 | −42 | −42 | 6 |
| apiaryShed_T3 | −42 | −48 | 6 |

**Propolis Kiln buttons** (2 buttons, at local (+42, −30) ± a few studs):

| ItemId | Plot-local X | Plot-local Z | Y |
|--------|-------------|--------------|---|
| proPolisKiln_T2 | +42 | −42 | 6 |
| proPolisKiln_T3 | +42 | −48 | 6 |

### Step 2 — Create each BudButton

For each of the 8 positions × 6 plots:

If BudButton template exists:
1. Clone `ReplicatedStorage.Templates.Structures.BudButton`
2. Set `CFrame` to world position (`plotAbsX + localX, Y, plotZ + localZ`)
3. Set attributes:
   - `PlotIndex` = plot number (1–6)
   - `ItemId` = itemId string from table above
   - `Cost` = honeyCost from Config.STRUCTURES (for display on SurfaceGui)
   - `Requires` = prerequisite string (e.g., `"danceFloorTier=1"`)
4. Tag with `"BudButton"` via CollectionService
5. Set `Anchored = true`
6. Parent to `Workspace.Plots.Plot[N].Structures` folder (create if needed)

If template does NOT exist, build from primitives:
- Main body: Part, Size (6,6,6), SmoothPlastic, Color `#F2A81C` (Honey Gold)
- Label: SurfaceGui on top face, TextLabel showing abbreviated cost
- UICorner radius 0.3 on the SurfaceGui frame
- Same attributes and tag as above

**The button displays the next tier name and cost.** Show only ONE tier at a time (T2 button
shows if shed is T1, T3 button shows if shed is T2, etc.) — this is handled by StructureService
hiding already-purchased buttons on profile load, not by the world-builder. Just place all 8.

### Step 3 — Verify

```lua
local CS = game:GetService("CollectionService")
local buttons = CS:GetTagged("BudButton")
local byItemId = {}
local issues = {}

for _, btn in buttons do
    local itemId = btn:GetAttribute("ItemId") or "NO_ID"
    byItemId[itemId] = (byItemId[itemId] or 0) + 1
    if not btn.Anchored then table.insert(issues, "NOT ANCHORED: " .. btn:GetFullName()) end
    if not btn:GetAttribute("PlotIndex") then table.insert(issues, "NO PlotIndex: " .. btn:GetFullName()) end
end

local out = "Total BudButtons: " .. #buttons .. " (expect 48)\n"
for id, count in byItemId do
    out = out .. "  " .. id .. ": " .. count .. " (expect 6)\n"
end
if #issues > 0 then out = out .. "ISSUES:\n" .. table.concat(issues, "\n") end
return out
```

**PASS criteria:**
- Total buttons: 48 (8 types × 6 plots)
- Each ItemId appears exactly 6 times
- All Anchored=true
- All have PlotIndex attribute

**WORLD BUILT:** 48 BudButton parts placed. All 6 plots have complete button set.

---

## TASK B: LUAU-SCRIPTER

### Step 1 — Update Config.STRUCTURES

**Read current Config first:**
```lua
local s = game:GetService("ReplicatedStorage").Modules:FindFirstChild("Config")
return s and s.Source:sub(1, 500) or "NOT FOUND"
```

Using the clone-and-replace pattern to bust require() cache:

Add the full `Config.STRUCTURES` table from the spec above (replace the existing partial
table if it exists, or add it if missing). Also add `Config.PROPOLIS_EXCHANGE`.

Add any missing `PROFILE_TEMPLATE` fields (`danceFloorTier`, `apiaryShedTier`,
`proPolisKilnTier`, `propolis`, `resin`).

### Step 2 — Extend StructureService for DanceFloor upgrades

**Read current StructureService source:**
```lua
local ss = game:GetService("ServerScriptService").Systems
local svc = ss:FindFirstChild("StructureService")
return svc and ("len=" .. #svc.Source .. "\nfirst300=" .. svc.Source:sub(1,300)) or "NOT FOUND"
```

StructureService currently handles ApiaryShed/PropolisKiln. Extend the `RequestPurchase`
handler to also handle DanceFloor upgrades:

```lua
-- In StructureService, extend the purchase handler:

local DANCE_FLOOR_TIER_SEQUENCE = {"danceFloor_T2", "danceFloor_T3", "danceFloor_T4", "danceFloor_T5"}
local DANCE_FLOOR_TEMPLATE_NAMES = {
    [2] = "DanceFloor_T2", [3] = "DanceFloor_T3", [4] = "DanceFloor_T4", [5] = "DanceFloor_T5"
}

-- Inside the RequestPurchase handler, after existing Shed/Kiln checks, add:
if itemId:find("^danceFloor_T") then
    local cfg = Config.STRUCTURES[itemId]
    if not cfg then return false, "unknown item" end

    -- Prerequisite: profile must be at the required tier
    local currentTier = profile.danceFloorTier or 1
    if currentTier ~= cfg.requires.danceFloorTier then
        return false, "wrong tier (have " .. currentTier .. ", need " .. cfg.requires.danceFloorTier .. ")"
    end

    -- Cost check
    if profile.honey < cfg.honeyCost then
        return false, "not enough honey"
    end

    -- Deduct cost + apply effect
    profile.honey -= cfg.honeyCost
    profile.danceFloorTier = cfg.effect.danceFloorTier

    -- Swap Dance Floor model on the plot
    local plotFolder = PlotService.GetPlotFolder(plotIndex)
    if plotFolder then
        -- Find existing DanceFloor cell model (cell 0,0 on Floor 1)
        -- It will be named DanceFloor_T[N] or have CombCell tag with Q=0,R=0,Floor=1
        for _, cell in plotFolder:GetDescendants() do
            if cell:GetAttribute("Q") == 0 and cell:GetAttribute("R") == 0
               and cell:GetAttribute("Floor") == 1
               and cell:GetAttribute("CellType") == "DanceFloor" then
                -- Swap for new tier template
                local newTmplName = DANCE_FLOOR_TEMPLATE_NAMES[profile.danceFloorTier]
                if newTmplName then
                    local tmpl = game:GetService("ReplicatedStorage").Templates.Cells:FindFirstChild(newTmplName)
                    if tmpl then
                        local clone = tmpl:Clone()
                        clone.CFrame = cell.CFrame
                        clone.Parent = cell.Parent
                        -- Copy CollectionService tags
                        for _, tag in game:GetService("CollectionService"):GetTags(cell) do
                            game:GetService("CollectionService"):AddTag(clone, tag)
                        end
                        -- Copy attributes
                        for k, v in cell:GetAttributes() do clone:SetAttribute(k, v) end
                        clone:SetAttribute("Tier", profile.danceFloorTier)
                        cell:Destroy()
                    end
                end
                break
            end
        end

        -- Update DanceFloor tag RouteSlots attribute
        for _, tagged in game:GetService("CollectionService"):GetTagged("DanceFloor") do
            if tagged:GetAttribute("PlotIndex") == plotIndex then
                tagged:SetAttribute("Tier", profile.danceFloorTier)
                tagged:SetAttribute("RouteSlots", cfg.routeSlots)
                break
            end
        end

        -- Hide buttons that are now invalid (lower tiers already purchased)
        for _, btn in game:GetService("CollectionService"):GetTagged("BudButton") do
            if btn:GetAttribute("PlotIndex") == plotIndex then
                local btnItemId = btn:GetAttribute("ItemId") or ""
                if btnItemId:find("^danceFloor_T") then
                    local btnCfg = Config.STRUCTURES[btnItemId]
                    if btnCfg and btnCfg.requires.danceFloorTier < profile.danceFloorTier then
                        -- This button is for a tier the player already passed — hide it
                        btn.Transparency = 1
                        btn.CanCollide   = false
                        btn.CanTouch     = false
                    end
                end
            end
        end
    end

    -- Notify
    local Notify = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
    if Notify then
        Notify:FireClient(player, {
            title = cfg.name .. " Upgraded!",
            body  = cfg.routeSlots .. " route slots. Golden zone " .. cfg.goldenZone .. "°.",
            icon  = "music",
        })
    end

    -- Also fire RatesUpdate so HUD reflects new route slots immediately
    local RatesUpdate = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("RatesUpdate")
    if RatesUpdate then
        RatesUpdate:FireClient(player, {
            danceFloorTier = profile.danceFloorTier,
            routeSlots     = cfg.routeSlots,
        })
    end

    task.spawn(function() DataService.Save(player) end)
    return true, "ok"
end
```

**Also add DanceService integration:** DanceService uses the Dance Floor tier's golden zone
width for grading. Update DanceService to read `profile.danceFloorTier` from the profile
instead of hardcoding tier 1:

```lua
-- In DanceService, in the SubmitDance grade computation:
-- Replace any hardcoded goldenZone = 18 with:
local danceFloorTier = profile.danceFloorTier or 1
local tierCfg = nil
for _, v in Config.STRUCTURES do
    if type(v) == "table" and v.effect and v.effect.danceFloorTier == danceFloorTier then
        tierCfg = v
        break
    end
end
local goldenZone = tierCfg and tierCfg.goldenZone or 18  -- T1 default
-- Use goldenZone for grade computation (was previously hardcoded)
```

Similarly, update ForagingService's route decay computation to use `decayMult` from tier 3+:
```lua
-- In ForagingService route tick:
local dFTier = profile.danceFloorTier or 1
local decayMult = 1.0
if dFTier >= 3 then decayMult = Config.STRUCTURES.danceFloor_T3.decayMult end
-- Apply to route quality decay interval: 240s * decayMult
```

### Step 3 — Propolis exchange via RequestPurchase

Add to StructureService's RequestPurchase handler (these bypass Config.STRUCTURES and
use Config.PROPOLIS_EXCHANGE for tier-adjusted pricing):

```lua
-- In RequestPurchase handler, add before "unknown item" fallthrough:
local PROPOLIS_PACKS = {
    propolis_1  = 1,
    propolis_5  = 5,
    propolis_10 = 10,
}
local packSize = PROPOLIS_PACKS[itemId]
if packSize then
    local shedTier  = profile.apiaryShedTier or 1
    local costEach  = Config.PROPOLIS_EXCHANGE[shedTier] or 400
    local totalCost = costEach * packSize

    if profile.honey < totalCost then
        return false, "not enough honey (need " .. totalCost .. ")"
    end
    profile.honey    -= totalCost
    profile.propolis  = (profile.propolis or 0) + packSize

    local Notify = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("Notify")
    if Notify then
        Notify:FireClient(player, {
            title = "+" .. packSize .. " Propolis",
            body  = "Spent " .. totalCost .. " honey at the " ..
                    ({"Lean-To","Workshop","Apothecary"})[shedTier] .. ".",
            icon  = "bottle",
        })
    end
    task.spawn(function() DataService.Save(player) end)
    return true, "ok"
end
```

### Step 4 — BudButton Touched wiring in StructureService

Architecture spec: "BudButton Touched connection with 0.6s per-player debounce, routes
to RequestPurchase server-side."

**Check if Touched wiring already exists:**
```lua
local svc = game:GetService("ServerScriptService").Systems.StructureService
local hasTouched = svc.Source:find("Touched") ~= nil
local hasBudButton = svc.Source:find("BudButton") ~= nil
return "Touched: " .. tostring(hasTouched) .. " | BudButton: " .. tostring(hasBudButton)
```

If wiring doesn't exist, add it:

```lua
-- In StructureService init, after all handlers are wired:
local CS = game:GetService("CollectionService")

-- Wire existing buttons
local function wireBudButton(btn: BasePart)
    local debounce: {[number]: number} = {}  -- userId -> last trigger time
    btn.Touched:Connect(function(hit: BasePart)
        local character = hit.Parent
        if not character then return end
        local player = game:GetService("Players"):GetPlayerFromCharacter(character)
        if not player then return end

        local now = tick()
        if (debounce[player.UserId] or 0) + 0.6 > now then return end
        debounce[player.UserId] = now

        local itemId = btn:GetAttribute("ItemId")
        if not itemId then return end

        local profile = DataService.GetProfile(player)
        if not profile then return end
        local plotIndex = PlotService.GetPlayerPlotIndex(player)
        if not plotIndex then return end

        -- Only the owner can use their own plot's BudButtons
        if btn:GetAttribute("PlotIndex") ~= plotIndex then return end

        StructureService.HandlePurchase(player, profile, plotIndex, itemId)
    end)
end

CS:GetInstanceAddedSignal("BudButton"):Connect(function(btn)
    if btn:IsA("BasePart") then wireBudButton(btn) end
end)
for _, btn in CS:GetTagged("BudButton") do
    if btn:IsA("BasePart") then wireBudButton(btn) end
end
```

### Step 5 — Create ShopGui

**ShopGui** opens when a player uses the ProximityPrompt on their Apiary Shed.
For cycle 5, it shows only the propolis exchange panel. Cosmetics tab is a stub.

Create `StarterGui.ShopGui` (ScreenGui):

```lua
-- ShopGui structure:
-- ScreenGui "ShopGui" (DisplayOrder=11, ResetOnSpawn=false, Enabled=false)
--   Frame "ShopPanel"  (AnchorPoint 0.5,0.5, Position 0.5,0,0.5,0, Size 0.45,0,0.5,0)
--     UICorner           (CornerRadius 0.04)
--     UIStroke           (Color #7A4A22, Thickness 2)
--     UIGradient         (vertical, top #E8D49A -> bottom #C4A86E)
--     TextLabel "Title"  ("The Lean-To" / "Workshop" / "Apothecary" -- updated by controller)
--     TextButton "CloseBtn" ("✕", top-right corner)
--     Frame "PropolisTab"
--       TextLabel "Heading" ("Propolis Exchange")
--       TextLabel "RateLabel" ("1 Propolis = [X] Honey")
--       Frame "Buttons"
--         TextButton "Buy1"  ("Buy 1 — [X]h")
--         TextButton "Buy5"  ("Buy 5 — [X]h")
--         TextButton "Buy10" ("Buy 10 — [X]h")
--     Frame "CosmeticsTab" (stub, Visible=false for now)
--       TextLabel "Stub"   ("Coming in a future update.")
```

Create `StarterPlayerScripts.ShopController` (LocalScript):

```lua
--!strict
-- ShopController — opens ShopGui from ApiaryShed ProximityPrompt,
-- fires RequestPurchase for propolis packs.

local Players       = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")

local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")
local Remotes       = ReplicatedStorage:WaitForChild("Remotes")

local RequestPurchase = Remotes:WaitForChild("RequestPurchase")
local RatesUpdate     = Remotes:WaitForChild("RatesUpdate")

-- Find ShopGui (may need to wait for it)
local ShopGui    = PlayerGui:WaitForChild("ShopGui")
local ShopPanel  = ShopGui:WaitForChild("ShopPanel")
local CloseBtn   = ShopPanel:WaitForChild("CloseBtn")
local RateLabel  = ShopPanel.PropolisTab:WaitForChild("RateLabel")
local Buy1Btn    = ShopPanel.PropolisTab.Buttons:WaitForChild("Buy1")
local Buy5Btn    = ShopPanel.PropolisTab.Buttons:WaitForChild("Buy5")
local Buy10Btn   = ShopPanel.PropolisTab.Buttons:WaitForChild("Buy10")

-- Track current propolis rate (updated when shed is upgraded)
local currentRate = 400  -- default T1 rate

local function updateRateDisplay(rate: number)
    currentRate = rate
    RateLabel.Text = "1 Propolis = " .. rate .. " Honey"
    Buy1Btn.Text   = "Buy 1 — " .. rate .. "h"
    Buy5Btn.Text   = "Buy 5 — " .. (rate * 5) .. "h"
    Buy10Btn.Text  = "Buy 10 — " .. (rate * 10) .. "h"
end

local function openShop(shedTier: number)
    local tierNames = {"Lean-To", "Workshop", "Apothecary"}
    local tierRates = {400, 180, 90}
    ShopPanel.Title.Text = tierNames[shedTier] or "Lean-To"
    updateRateDisplay(tierRates[shedTier] or 400)
    ShopGui.Enabled = true
    TweenService:Create(ShopPanel, TweenInfo.new(0.2), {
        Size = UDim2.fromScale(0.45, 0.5)
    }):Play()
end

local function closeShop()
    TweenService:Create(ShopPanel, TweenInfo.new(0.15), {
        Size = UDim2.fromScale(0.01, 0.01)
    }):Play()
    task.delay(0.15, function()
        ShopGui.Enabled = false
        ShopPanel.Size = UDim2.fromScale(0.45, 0.5)  -- reset for next open
    end)
end

CloseBtn.Activated:Connect(closeShop)

Buy1Btn.Activated:Connect(function()
    RequestPurchase:FireServer("propolis_1")
end)
Buy5Btn.Activated:Connect(function()
    RequestPurchase:FireServer("propolis_5")
end)
Buy10Btn.Activated:Connect(function()
    RequestPurchase:FireServer("propolis_10")
end)

-- Listen for rate updates (after shed upgrade)
RatesUpdate.OnClientEvent:Connect(function(data: {apiaryShedTier: number?})
    if data.apiaryShedTier then
        local tierRates = {400, 180, 90}
        updateRateDisplay(tierRates[data.apiaryShedTier] or 400)
    end
end)

-- Wire ProximityPrompts on Apiary Shed buildings
local function wireApiaryShed(shed: Instance)
    local pp = shed:FindFirstChildOfClass("ProximityPrompt")
    if not pp then
        pp = Instance.new("ProximityPrompt")
        pp.ActionText = "Shop"
        pp.ObjectText = "Apiary"
        pp.MaxActivationDistance = 10
        pp.HoldDuration = 0
        pp.Parent = shed
    end
    pp.Triggered:Connect(function(player: Player)
        if player ~= LocalPlayer then return end
        -- Read shed tier from the shed's attribute or parent plot
        local shedTier = shed:GetAttribute("Tier") or 1
        openShop(shedTier)
    end)
end

-- Wire all existing and future Apiary Shed buildings
for _, obj in game:GetService("Workspace"):GetDescendants() do
    if obj.Name:find("ApiaryShed") or obj.Name:find("Apiary_Shed") then
        wireApiaryShed(obj)
    end
end
game:GetService("Workspace").DescendantAdded:Connect(function(obj)
    if obj.Name:find("ApiaryShed") then wireApiaryShed(obj) end
end)

-- Also fire RatesUpdate on Notify to refresh display after purchase
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(data: {title: string?})
    -- If we got a shed upgrade notification, the server also fires RatesUpdate,
    -- so this is just a fallback; no action needed here.
end)
```

**Also add RatesUpdate fields for shed tier** in StructureService (the server fires
RatesUpdate after shed upgrade with `{apiaryShedTier = N}` so ShopController can update
its displayed prices without a reload).

Add to StructureService's Shed purchase handler (existing code):
```lua
-- After apiaryShed upgrade succeeds:
local RatesUpdate = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("RatesUpdate")
if RatesUpdate then
    RatesUpdate:FireClient(player, {
        apiaryShedTier = profile.apiaryShedTier,
        propolisRate   = Config.PROPOLIS_EXCHANGE[profile.apiaryShedTier],
    })
end
```

### Verification after luau-scripter

```lua
-- Check Config
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local structureIds = {}
for id, _ in (cfg.STRUCTURES or {}) do table.insert(structureIds, id) end
table.sort(structureIds)

-- Check RemoteEvents
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local hasRP   = remotes and remotes:FindFirstChild("RequestPurchase") ~= nil

-- Check scripts
local SPS     = game:GetService("StarterPlayer").StarterPlayerScripts
local hasShopCtrl = SPS:FindFirstChild("ShopController") ~= nil
local hasShopGui  = game:GetService("StarterGui"):FindFirstChild("ShopGui") ~= nil

-- Check StructureService for DanceFloor handling
local svc = game:GetService("ServerScriptService").Systems:FindFirstChild("StructureService")
local hasDanceFloor = svc and svc.Source:find("danceFloor") ~= nil
local hasPropExch   = svc and svc.Source:find("propolis_") ~= nil
local hasBudButton  = svc and svc.Source:find("BudButton") ~= nil

return string.format(
    "Config.STRUCTURES keys: %s\n" ..
    "Config.PROPOLIS_EXCHANGE: %s\n" ..
    "RequestPurchase remote: %s\n" ..
    "ShopController script: %s\n" ..
    "ShopGui: %s\n" ..
    "StructureService.danceFloor: %s\n" ..
    "StructureService.propolis_: %s\n" ..
    "StructureService.BudButton: %s",
    table.concat(structureIds, ", "),
    tostring(cfg.PROPOLIS_EXCHANGE ~= nil),
    tostring(hasRP),
    tostring(hasShopCtrl),
    tostring(hasShopGui),
    tostring(hasDanceFloor),
    tostring(hasPropExch),
    tostring(hasBudButton)
)
```

**PASS criteria:**
- Config.STRUCTURES has all 8 keys (danceFloor_T2..T5, apiaryShed_T2..T3, proPolisKiln_T2..T3)
- Config.PROPOLIS_EXCHANGE: true
- RequestPurchase remote exists
- ShopController script exists
- ShopGui exists
- All three StructureService checks: true

---

## TASK C: UI-DESIGNER (after code review passes)

> Apply Warm Wax polish to ShopGui. Same style guide as BuildGui and HiveGui:
> Propolis Brown headers (#7A4A22), Honey Gold accents (#F2A81C), Wax Cream background
> (#E8D49A), Warm Amber text (#5A3510).

- ShopPanel frame: UIGradient top #E8D49A → bottom #C4A86E, UICorner 0.04, UIStroke #7A4A22 thickness 2
- Title TextLabel: TextColor #7A4A22, Font GothamBold size 20, UIStroke #F2A81C thickness 1
- RateLabel: Font GothamMedium, TextColor #5A3510, size 14
- Buy buttons: BackgroundColor #F2A81C, TextColor #5A3510, UICorner 0.3, UIStroke #7A4A22 thickness 1
  - Touch target: minimum 44px height (Size YOffset≥44)
- CloseBtn: BackgroundColor #C4A86E, TextColor #7A4A22, UICorner 0.4
- Stub label: TextColor #B09A70 (muted, clearly not actionable)
- UIAnimations LocalScript: scale-pulse on Buy button press (0.95→1.0 over 0.1s)
- All sizes: UDim2 Scale-based (no Offset on major frames)
- Mobile safety: ShopPanel max width = 0.55 scale on narrow screens

---

## FINAL VERIFICATION

```lua
local CS = game:GetService("CollectionService")
local WS = game:GetService("Workspace")

-- Geometry
local buttons = CS:GetTagged("BudButton")
local totalParts = 0
for _, obj in WS:GetDescendants() do
    if obj:IsA("BasePart") then totalParts += 1 end
end

-- Config
local cfg = require(game:GetService("ReplicatedStorage").Modules.Config)
local structureCount = 0
for _ in (cfg.STRUCTURES or {}) do structureCount += 1 end

-- UI
local ShopGui = game:GetService("StarterGui"):FindFirstChild("ShopGui")
local shopScreenGui = ShopGui and ShopGui:IsA("ScreenGui")

-- StructureService
local svc = game:GetService("ServerScriptService").Systems.StructureService
local src = svc and svc.Source or ""

return string.format(
    "=== SHOPGUI + BUDBUTTON VERIFICATION ===\n" ..
    "BudButtons in world: %d (expect 48)\n" ..
    "Config.STRUCTURES entries: %d (expect 8)\n" ..
    "Config.PROPOLIS_EXCHANGE: %s\n" ..
    "ShopGui ScreenGui: %s\n" ..
    "StructureService danceFloor wiring: %s\n" ..
    "StructureService propolis exchange: %s\n" ..
    "Total workspace parts: %d (budget 5000)",
    #buttons,
    structureCount,
    tostring(cfg.PROPOLIS_EXCHANGE ~= nil),
    tostring(shopScreenGui),
    tostring(src:find("danceFloor") ~= nil),
    tostring(src:find("propolis_") ~= nil),
    totalParts
)
```

**PASS criteria:**
- BudButtons: 48
- Config.STRUCTURES: 8 entries
- Config.PROPOLIS_EXCHANGE: true
- ShopGui ScreenGui: true
- StructureService danceFloor: true
- StructureService propolis: true
- Total parts ≤ 5,000

---

## GAMEPLAY IMPACT

After this dispatch executes:

- **Dance Floor upgrade path is live.** Players can walk up to the buttons south of their
  comb and press T2 (900h), T3 (7.5kh), T4 (60kh), T5 (400kh) at any time. Each upgrade
  immediately expands route capacity and improves grade thresholds — the economy now has
  a meaningful mid-game investment sink.
- **Propolis exchange is live.** Players who didn't build resin routes can emergency-buy
  propolis from their Apiary Shed. Intentionally expensive at T1 (400/each) to encourage
  the kiln instead.
- **All 8 upgrade paths are purchasable.** The game no longer has orphaned BudButton meshes
  with no wiring. Every button players touch does something.
- **ShopGui** exists as an established pattern for the cosmetics tab when CosmeticService
  ships in a future cycle.
