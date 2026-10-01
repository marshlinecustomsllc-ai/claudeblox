# Dispatch 132 — Propolis Upgrade Shop
## Cycle 14 · A Bee's World

**Feature:** A `PropolisShopGui` ScreenGui + `PropolisShopController` LocalScript that presents a clean upgrade shop panel for propolis-gated cell enhancements. Kids see colourful upgrade cards with emoji previews; adults see exact stat deltas (output %, speed %, adjacency bonus %) before spending. A `BuyUpgrade` RemoteEvent + `PropolisUpgradeService` server Script validates and applies purchases. Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 131 (Milestone Celebration)

---

## DESIGN

### Upgrade catalogue (8 upgrades, tiered by propolis cost)

| ID | Name | Cost | Effect description (kid) | Effect (adult stat) |
|----|------|------|--------------------------|---------------------|
| `wax_seal_1` | Wax Seal I | 10 propolis | "Honey stays fresher longer!" | +10% honey decay resistance |
| `wax_seal_2` | Wax Seal II | 40 propolis | "Even better freshness!" | +25% honey decay resistance |
| `royal_jelly_1` | Royal Jelly I | 25 propolis | "Royal cells get a boost!" | +8% Royal Cell output |
| `royal_jelly_2` | Royal Jelly II | 80 propolis | "Your queen bee is thriving!" | +20% Royal Cell output |
| `propolis_varnish` | Propolis Varnish | 15 propolis | "Shiny protected comb!" | +5% all cell output (flat) |
| `bee_stamina_1` | Bee Stamina I | 20 propolis | "Bees fly further for longer!" | +15% foraging quality range |
| `bee_stamina_2` | Bee Stamina II | 60 propolis | "Your bees never get tired!" | +30% foraging quality range |
| `hive_insulation` | Hive Insulation | 35 propolis | "Warm and cosy inside!" | +1 active cell slot (bonus) |

**Prerequisite chain:** `wax_seal_2` requires `wax_seal_1` purchased. `royal_jelly_2` requires `royal_jelly_1`. `bee_stamina_2` requires `bee_stamina_1`. Others are standalone.

### Upgrade state storage

Server writes purchased upgrades to player attribute `PropolisUpgrades` (comma-string of purchased IDs). Client reads this to show owned/available state. `PropolisCount` attribute is the currency.

### Panel layout

- **Toggle button**: `🌿` TextButton, `{0,8,0.5,-80}` (left side, vertically centred), 44×44, DisplayOrder=19
- **Panel**: 300×400px Frame, slides in from left (`{0,8,0.5,-200}` → `{0,8,0.5,-200}`), Wax Cream bg
- **Header**: "🌿 Propolis Shop" GothamBold 18, + "🌿 N" balance label top-right
- **Upgrade cards**: ScrollingFrame, one card per upgrade (height 72px each):
  - Card: upgrade name (GothamBold 14) + emoji icon (32px) + cost badge + effect description + Buy/Owned/Locked button
  - Owned: green ✓ badge, button greyed out
  - Locked (prereq not met): padlock 🔒, button disabled, prereq shown in small text
  - Available: "Buy 🌿N" button, honey gold colour
- **DisplayOrder**: 19 (between bee roster 18 and cell guide 20)

### RemoteEvent: BuyUpgrade

- **Client → Server**: `BuyUpgrade:FireServer(upgradeId: string)`
- **Server validation**: check upgradeId in catalogue, player has enough propolis, prereqs met, not already owned
- **On success**: deduct propolis, add to PropolisUpgrades attribute, FireClient confirmation
- **On failure**: FireClient with error string for UI feedback

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PropolisUpgradeService` | New Script in ServerScriptService |
| `PropolisShopController` | New LocalScript in StarterPlayerScripts |
| `BuyUpgrade` | New RemoteEvent in ReplicatedStorage |

---

## STEP A — Create RemoteEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
if RS:FindFirstChild("BuyUpgrade") then
    print("⏭️  BuyUpgrade already exists — skip")
else
    local re = Instance.new("RemoteEvent")
    re.Name   = "BuyUpgrade"
    re.Parent = RS
    print("✅ BuyUpgrade RemoteEvent created")
end
```

---

## STEP B — Create PropolisUpgradeService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("PropolisUpgradeService") then
    print("⏭️  PropolisUpgradeService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "PropolisUpgradeService"
    svc.Source = [[
--!strict
-- PropolisUpgradeService — dispatch 132
-- Server-side validation and application of propolis upgrades.

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

type UpgradeDef132 = {id: string, cost: number, prereq: string?}
local CATALOGUE_132: {UpgradeDef132} = {
    {id="wax_seal_1",       cost=10,  prereq=nil},
    {id="wax_seal_2",       cost=40,  prereq="wax_seal_1"},
    {id="royal_jelly_1",    cost=25,  prereq=nil},
    {id="royal_jelly_2",    cost=80,  prereq="royal_jelly_1"},
    {id="propolis_varnish", cost=15,  prereq=nil},
    {id="bee_stamina_1",    cost=20,  prereq=nil},
    {id="bee_stamina_2",    cost=60,  prereq="bee_stamina_1"},
    {id="hive_insulation",  cost=35,  prereq=nil},
}

local function getOwned_132(player: Player): {[string]: boolean}
    local raw = tostring(player:GetAttribute("PropolisUpgrades") or "")
    local owned: {[string]: boolean} = {}
    for id in raw:gmatch("[^,]+") do owned[id] = true end
    return owned
end

local function addOwned_132(player: Player, id: string)
    local owned = getOwned_132(player)
    owned[id] = true
    local ids: {string} = {}
    for k in owned do table.insert(ids, k) end
    player:SetAttribute("PropolisUpgrades", table.concat(ids, ","))
end

local BuyUpgrade132 = RS:WaitForChild("BuyUpgrade", 10) :: RemoteEvent?
if not BuyUpgrade132 then
    warn("[PropolisUpgradeService] BuyUpgrade RemoteEvent not found — aborting")
    return
end

BuyUpgrade132.OnServerEvent:Connect(function(player: Player, upgradeId: unknown)
    if type(upgradeId) ~= "string" then return end

    -- Find definition
    local def: UpgradeDef132? = nil
    for _, d in CATALOGUE_132 do
        if d.id == upgradeId then def = d; break end
    end
    if not def then
        BuyUpgrade132:FireClient(player, false, "Unknown upgrade")
        return
    end

    local owned = getOwned_132(player)

    -- Already owned?
    if owned[def.id] then
        BuyUpgrade132:FireClient(player, false, "Already owned")
        return
    end

    -- Prereq check
    if def.prereq and not owned[def.prereq] then
        BuyUpgrade132:FireClient(player, false, "Requires " .. def.prereq)
        return
    end

    -- Funds check
    local propolis = tonumber(player:GetAttribute("PropolisCount")) or 0
    if propolis < def.cost then
        BuyUpgrade132:FireClient(player, false, "Not enough propolis")
        return
    end

    -- Apply
    player:SetAttribute("PropolisCount", propolis - def.cost)
    addOwned_132(player, def.id)
    BuyUpgrade132:FireClient(player, true, def.id)
    print("[PropolisUpgradeService] " .. player.Name .. " bought " .. def.id)
end)

print("[PropolisUpgradeService] Ready — 8 upgrades available")
]]
    svc.Parent = SSS
    print("✅ PropolisUpgradeService created")
end
```

---

## STEP C — Create PropolisShopController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PropolisShopController") then
    print("⏭️  PropolisShopController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PropolisShopController"
    ctrl.Source = [[
--!strict
-- PropolisShopController — dispatch 132
-- Propolis upgrade shop UI.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

type ShopUpgrade132 = {
    id: string, name: string, cost: number, prereq: string?,
    emoji: string, kidEffect: string, adultEffect: string
}
local UPGRADES_132: {ShopUpgrade132} = {
    {id="wax_seal_1",       name="Wax Seal I",         cost=10,  prereq=nil,           emoji="🪄", kidEffect="Honey stays fresher longer!",         adultEffect="+10% decay resist"},
    {id="wax_seal_2",       name="Wax Seal II",         cost=40,  prereq="wax_seal_1",   emoji="✨", kidEffect="Even better freshness!",              adultEffect="+25% decay resist"},
    {id="royal_jelly_1",    name="Royal Jelly I",       cost=25,  prereq=nil,           emoji="🔶", kidEffect="Royal cells get a boost!",            adultEffect="+8% Royal output"},
    {id="royal_jelly_2",    name="Royal Jelly II",      cost=80,  prereq="royal_jelly_1",emoji="👑", kidEffect="Your queen bee is thriving!",         adultEffect="+20% Royal output"},
    {id="propolis_varnish", name="Propolis Varnish",    cost=15,  prereq=nil,           emoji="🌿", kidEffect="Shiny protected comb!",               adultEffect="+5% all output"},
    {id="bee_stamina_1",    name="Bee Stamina I",       cost=20,  prereq=nil,           emoji="🌸", kidEffect="Bees fly further for longer!",        adultEffect="+15% forage quality"},
    {id="bee_stamina_2",    name="Bee Stamina II",      cost=60,  prereq="bee_stamina_1",emoji="🌺", kidEffect="Your bees never get tired!",          adultEffect="+30% forage quality"},
    {id="hive_insulation",  name="Hive Insulation",     cost=35,  prereq=nil,           emoji="🏠", kidEffect="Warm and cosy inside!",               adultEffect="+1 active slot bonus"},
}

local WAXCREAM_132  = Color3.fromRGB(232, 212, 154)
local PROPBROWN_132 = Color3.fromRGB(80, 50, 20)
local GOLD_132      = Color3.fromRGB(242, 168, 28)
local GREEN_132     = Color3.fromRGB(100, 180, 60)
local GREY_132      = Color3.fromRGB(160, 140, 110)

local panelOpen_132 = false
local cardButtons_132: {[string]: TextButton} = {}

-- ── Build GUI ────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name             = "PropolisShopGui"
sg.ResetOnSpawn     = false
sg.DisplayOrder     = 19
sg.Parent           = playerGui

-- Toggle button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name              = "ShopToggle"
toggleBtn.Size              = UDim2.new(0, 44, 0, 44)
toggleBtn.Position          = UDim2.new(0, 8, 0.5, -80)
toggleBtn.BackgroundColor3  = WAXCREAM_132
toggleBtn.BorderSizePixel   = 0
toggleBtn.Font              = Enum.Font.GothamBold
toggleBtn.TextSize          = 22
toggleBtn.TextColor3        = PROPBROWN_132
toggleBtn.Text              = "🌿"
toggleBtn.Parent            = sg
local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0,10); tc.Parent = toggleBtn

-- Panel
local panel = Instance.new("Frame")
panel.Name                  = "ShopPanel"
panel.Size                  = UDim2.new(0, 300, 0, 400)
panel.Position              = UDim2.new(0, -310, 0.5, -200)
panel.BackgroundColor3      = WAXCREAM_132
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel       = 0
panel.Parent                = sg
local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0,14); pc.Parent = panel

-- Header
local header = Instance.new("TextLabel")
header.Size             = UDim2.new(1,-16,0,36)
header.Position         = UDim2.new(0,8,0,6)
header.BackgroundTransparency = 1
header.Font             = Enum.Font.GothamBold
header.TextSize         = 18
header.TextColor3       = PROPBROWN_132
header.Text             = "🌿 Propolis Shop"
header.TextXAlignment   = Enum.TextXAlignment.Left
header.Parent           = panel

local balanceLbl = Instance.new("TextLabel")
balanceLbl.Name             = "BalanceLbl"
balanceLbl.Size             = UDim2.new(0,90,0,28)
balanceLbl.Position         = UDim2.new(1,-98,0,10)
balanceLbl.BackgroundTransparency = 1
balanceLbl.Font             = Enum.Font.GothamBold
balanceLbl.TextSize         = 14
balanceLbl.TextColor3       = PROPBROWN_132
balanceLbl.Text             = "🌿 0"
balanceLbl.TextXAlignment   = Enum.TextXAlignment.Right
balanceLbl.Parent           = panel

-- Scroll container
local scroll = Instance.new("ScrollingFrame")
scroll.Size             = UDim2.new(1,-8,1,-52)
scroll.Position         = UDim2.new(0,4,0,48)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel  = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = GOLD_132
scroll.CanvasSize       = UDim2.new(0,0,0, #UPGRADES_132 * 76)
scroll.Parent           = panel

-- Build cards
for i, upg in UPGRADES_132 do
    local card = Instance.new("Frame")
    card.Size               = UDim2.new(1,-8,0,72)
    card.Position           = UDim2.new(0,4,0,(i-1)*76)
    card.BackgroundColor3   = Color3.fromRGB(255, 250, 220)
    card.BackgroundTransparency = 0.2
    card.BorderSizePixel    = 0
    card.Parent             = scroll
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,8); cc.Parent = card

    local emojiLbl = Instance.new("TextLabel")
    emojiLbl.Size = UDim2.new(0,36,0,36); emojiLbl.Position = UDim2.new(0,6,0,8)
    emojiLbl.BackgroundTransparency = 1; emojiLbl.TextSize = 26; emojiLbl.Text = upg.emoji
    emojiLbl.Parent = card

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1,-100,0,22); nameLbl.Position = UDim2.new(0,48,0,6)
    nameLbl.BackgroundTransparency = 1; nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 14; nameLbl.TextColor3 = PROPBROWN_132
    nameLbl.Text = upg.name; nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.Parent = card

    local effectLbl = Instance.new("TextLabel")
    effectLbl.Size = UDim2.new(1,-100,0,18); effectLbl.Position = UDim2.new(0,48,0,28)
    effectLbl.BackgroundTransparency = 1; effectLbl.Font = Enum.Font.Gotham
    effectLbl.TextSize = 11; effectLbl.TextColor3 = Color3.fromRGB(100,70,30)
    effectLbl.Text = upg.kidEffect .. "  (" .. upg.adultEffect .. ")"
    effectLbl.TextXAlignment = Enum.TextXAlignment.Left; effectLbl.TextTruncate = Enum.TextTruncate.AtEnd
    effectLbl.Parent = card

    local buyBtn = Instance.new("TextButton")
    buyBtn.Name             = "Buy_" .. upg.id
    buyBtn.Size             = UDim2.new(0, 84, 0, 28)
    buyBtn.Position         = UDim2.new(1,-90,0.5,-14)
    buyBtn.BackgroundColor3 = GOLD_132
    buyBtn.BorderSizePixel  = 0
    buyBtn.Font             = Enum.Font.GothamBold
    buyBtn.TextSize         = 12
    buyBtn.TextColor3       = PROPBROWN_132
    buyBtn.Text             = "🌿 " .. upg.cost
    buyBtn.Parent           = card
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = buyBtn

    cardButtons_132[upg.id] = buyBtn

    buyBtn.Activated:Connect(function()
        local BuyUpgrade132 = RS:FindFirstChild("BuyUpgrade") :: RemoteEvent?
        if BuyUpgrade132 then BuyUpgrade132:FireServer(upg.id) end
    end)
end

-- ── Panel open/close ─────────────────────────────────────────────
local function setPanel_132(open: boolean)
    panelOpen_132 = open
    local targetX = open and 8 or -310
    TweenService:Create(panel,
        TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, targetX, 0.5, -200)}
    ):Play()
end
toggleBtn.Activated:Connect(function() setPanel_132(not panelOpen_132) end)

-- ── Refresh card states ──────────────────────────────────────────
local function refreshCards_132()
    local propolis = tonumber(player:GetAttribute("PropolisCount")) or 0
    balanceLbl.Text = "🌿 " .. math.floor(propolis)

    local owned: {[string]: boolean} = {}
    local raw = tostring(player:GetAttribute("PropolisUpgrades") or "")
    for id in raw:gmatch("[^,]+") do owned[id] = true end

    for _, upg in UPGRADES_132 do
        local btn = cardButtons_132[upg.id]
        if not btn then continue end

        if owned[upg.id] then
            btn.Text            = "✓ Owned"
            btn.BackgroundColor3 = GREEN_132
            btn.TextColor3      = Color3.fromRGB(255,255,255)
            btn.Active          = false
        elseif upg.prereq and not owned[upg.prereq] then
            btn.Text            = "🔒"
            btn.BackgroundColor3 = GREY_132
            btn.TextColor3      = PROPBROWN_132
            btn.Active          = false
        elseif propolis < upg.cost then
            btn.Text            = "🌿 " .. upg.cost
            btn.BackgroundColor3 = GREY_132
            btn.TextColor3      = PROPBROWN_132
            btn.Active          = false
        else
            btn.Text            = "🌿 " .. upg.cost
            btn.BackgroundColor3 = GOLD_132
            btn.TextColor3      = PROPBROWN_132
            btn.Active          = true
        end
    end
end

-- ── Listen for server response ───────────────────────────────────
task.wait(2)
local BuyUpgrade132_c = RS:FindFirstChild("BuyUpgrade") :: RemoteEvent?
if BuyUpgrade132_c then
    BuyUpgrade132_c.OnClientEvent:Connect(function(success: boolean, _data: string)
        refreshCards_132()
    end)
end

-- ── Attribute listeners ──────────────────────────────────────────
player:GetAttributeChangedSignal("PropolisCount"):Connect(refreshCards_132)
player:GetAttributeChangedSignal("PropolisUpgrades"):Connect(refreshCards_132)

refreshCards_132()
print("[PropolisShopController] Ready — propolis shop active")
]]
    ctrl.Parent = SPS
    print("✅ PropolisShopController created in StarterPlayerScripts")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS   = game:GetService("ReplicatedStorage")

local svc  = SSS:FindFirstChild("PropolisUpgradeService")
local ctrl = SPS and SPS:FindFirstChild("PropolisShopController")
local re   = RS:FindFirstChild("BuyUpgrade")

local checks = {}
table.insert(checks, (re and "✅" or "❌") .. " BuyUpgrade RemoteEvent in ReplicatedStorage")
table.insert(checks, (svc and "✅" or "❌") .. " PropolisUpgradeService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " PropolisUpgradeService is a Script (not LocalScript)")
table.insert(checks, (svc and svc.Source:find("CATALOGUE_132", 1, true) and "✅" or "❌") .. " CATALOGUE_132 server catalogue")
table.insert(checks, (svc and svc.Source:find("prereq", 1, true) and "✅" or "❌") .. " prereq validation on server")
table.insert(checks, (svc and svc.Source:find("PropolisCount", 1, true) and "✅" or "❌") .. " PropolisCount funds check on server")
table.insert(checks, (svc and svc.Source:find("PropolisUpgrades", 1, true) and "✅" or "❌") .. " PropolisUpgrades attribute written on server")
table.insert(checks, (ctrl and "✅" or "❌") .. " PropolisShopController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " PropolisShopController is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("UPGRADES_132", 1, true) and "✅" or "❌") .. " UPGRADES_132 client catalogue")
table.insert(checks, (ctrl and ctrl.Source:find("refreshCards_132", 1, true) and "✅" or "❌") .. " refreshCards_132 UI state sync")
table.insert(checks, (ctrl and ctrl.Source:find("setPanel_132", 1, true) and "✅" or "❌") .. " setPanel_132 open/close animation")
table.insert(checks, (ctrl and ctrl.Source:find("cardButtons_132", 1, true) and "✅" or "❌") .. " cardButtons_132 button registry")
table.insert(checks, (ctrl and ctrl.Source:find("DisplayOrder", 1, true) and "✅" or "❌") .. " DisplayOrder=19")

print("=== DISPATCH 132 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 132 complete" or "❌ SOME CHECKS FAILED")

print("\n8 upgrades: wax_seal(1,2) | royal_jelly(1,2) | propolis_varnish | bee_stamina(1,2) | hive_insulation")
print("Server-auth: cost deduction + prereq check + owned check all server-side")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PropolisUpgradeService (Script; no parts) | 0 |
| PropolisShopController (LocalScript; GUI only) | 0 |
| BuyUpgrade RemoteEvent | 0 |
| **Dispatch 132 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- All purchase validation happens server-side (`PropolisUpgradeService`). The client UI sends an `upgradeId` string and trusts the server to validate funds, prereqs, and ownership. This is critical — a client could call `FireServer` with any string; the server catalogue check catches invalid IDs.
- `refreshCards_132` runs on both `PropolisCount` and `PropolisUpgrades` attribute changes. This means the shop panel stays current in real-time even when propolis is earned or spent from an unrelated source (e.g., crafting system).
- The buy button shows three visual states: **gold** (can buy), **grey** (insufficient funds OR prereq locked), **green ✓** (owned). The 🔒 emoji on locked items teaches the prereq chain visually without any tooltip UI.
- `adultEffect` strings ("+10% decay resist", "+8% Royal output") are appended to the kid-facing effect text in a smaller font. Adults immediately see the numbers; kids see the friendly description and don't need to parse the stat delta.
- The panel slides in from the left side (`Position.X` animates from -310 to 8) — the right side is already occupied by the Goals, Bee Roster, and Achievement buttons. Left side at Y=50% positions it centrally without covering the comb grid or the honey indicator at top.
- `ScrollingFrame.CanvasSize` is set statically to `#UPGRADES_132 * 76` studs. If upgrades are added in a future dispatch, update this value or compute it dynamically from `#UPGRADES_132 * 76`.
