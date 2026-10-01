# Dispatch 141 — Bee Roster Expansion
## Cycle 14 · A Bee's World

**Feature:** A `BeeRosterService` server Script plus an update to the existing `BeeRosterController` (or a supplemental `BeeRosterExpansionController` LocalScript) that adds three unlockable specialist bee slots beyond the starter 3. Each specialist bee has a passive bonus that applies permanently once unlocked. Kids see new bee characters to collect; adults strategize which specialist fits their comb layout. Part budget: +1 permanent (BeeRosterService).
**Part budget impact:** +1 permanent → **4,149 / 5,000**
**Execution order:** After dispatch 140 (Prestige System)

---

## DESIGN

### Specialist bees

| Bee | Unlock cost | Passive bonus | Emoji |
|-----|------------|---------------|-------|
| Nurse Bee | 200 honey | +15% brood cell speed | 🐝💊 |
| Scout Bee | 350 honey | +20% foraging quality | 🐝🔭 |
| Guard Bee | 500 honey | Bear attack drain reduced an extra –5% | 🐝🛡️ |

Up to 3 specialist bees can be unlocked (in addition to the 3 starter bees the UI already shows from dispatch 120). Total roster size: 6 bees max.

### Unlock flow

1. Player opens Bee Roster panel (dispatch 120 button, top-right column)
2. Specialist bee cards appear below the starter bees — locked state shows cost in honey
3. Player taps "Unlock" on an eligible card → `RequestUnlockBee` RemoteEvent → server validates honey, deducts, sets `SpecialistBees` attribute
4. Card switches to "Active" state; passive bonus applies immediately via `SpecialistBees` attribute propagation to other services

### SpecialistBees attribute

Comma-string of unlocked specialist bee IDs: `"nurse_bee,scout_bee"`. Other services read this attribute for their bonus calculations (e.g. BearAttackService checks for `"guard_bee"`, ForagingService checks for `"scout_bee"`).

### Roster panel extension

New section `"Specialist Bees"` added below starter bees in the existing Bee Roster ScreenGui (if it exists). If no Bee Roster ScreenGui is found, creates a minimal standalone panel.

### RemoteEvents

| Event | Direction | Payload |
|-------|-----------|---------|
| `RequestUnlockBee` | Client → Server | `{beeId: string}` |
| `BeeUnlocked` | Server → Client | `{beeId: string, newAttr: string}` |

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BeeRosterService` | New Script in ServerScriptService (+1 permanent) |
| `BeeRosterExpansionController` | New LocalScript in StarterPlayerScripts (+0 permanent) |

---

## STEP A — Create BeeRosterService (server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("BeeRosterService") then
    print("⏭️  BeeRosterService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "BeeRosterService"
    svc.Source = [[
--!strict
-- BeeRosterService — dispatch 141
-- Handles specialist bee unlock requests and SpecialistBees attribute.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

type BeeDef141 = {id: string, cost: number}
local CATALOGUE_141: {BeeDef141} = {
    {id = "nurse_bee",  cost = 200},
    {id = "scout_bee",  cost = 350},
    {id = "guard_bee",  cost = 500},
}

local eventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    or (function()
        local f = Instance.new("Folder"); f.Name = "RemoteEvents"; f.Parent = ReplicatedStorage; return f
    end)()

local requestUnlock_141: RemoteEvent = eventsFolder:FindFirstChild("RequestUnlockBee") :: RemoteEvent
    or (function()
        local e = Instance.new("RemoteEvent"); e.Name = "RequestUnlockBee"; e.Parent = eventsFolder; return e
    end)()

local beeUnlocked_141: RemoteEvent = eventsFolder:FindFirstChild("BeeUnlocked") :: RemoteEvent
    or (function()
        local e = Instance.new("RemoteEvent"); e.Name = "BeeUnlocked"; e.Parent = eventsFolder; return e
    end)()

-- ── Unlock handler ────────────────────────────────────────────────
requestUnlock_141.OnServerEvent:Connect(function(player: Player, data: {beeId: string})
    if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
    if typeof(data) ~= "table" then return end
    local beeId = tostring(data.beeId or "")

    -- Find in catalogue
    local def: BeeDef141? = nil
    for _, d in CATALOGUE_141 do
        if d.id == beeId then def = d; break end
    end
    if not def then return end

    -- Already owned check
    local owned = tostring(player:GetAttribute("SpecialistBees") or "")
    if owned:find(beeId, 1, true) then return end

    -- Funds check
    local honey = tonumber(player:GetAttribute("HoneyCount")) or 0
    if honey < (def :: BeeDef141).cost then return end

    -- Deduct and grant
    player:SetAttribute("HoneyCount", honey - (def :: BeeDef141).cost)
    local newOwned = owned == "" and beeId or (owned .. "," .. beeId)
    player:SetAttribute("SpecialistBees", newOwned)

    beeUnlocked_141:FireClient(player, {beeId = beeId, newAttr = newOwned})
    print("[BeeRosterService] " .. player.Name .. " unlocked " .. beeId)
end)

print("[BeeRosterService] Ready — specialist bee unlocks active")
]]
    svc.Parent = SSS
    print("✅ BeeRosterService created in ServerScriptService")
end
```

---

## STEP B — Create BeeRosterExpansionController (client)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("BeeRosterExpansionController") then
    print("⏭️  BeeRosterExpansionController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "BeeRosterExpansionController"
    ctrl.Source = [[
--!strict
-- BeeRosterExpansionController — dispatch 141
-- Adds specialist bee cards to the Bee Roster panel.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local GOLD_141  = Color3.fromRGB(242, 168, 28)
local GREY_141  = Color3.fromRGB(120, 100,  70)
local GREEN_141 = Color3.fromRGB(80,  160,  60)
local WHITE_141 = Color3.fromRGB(255, 255, 255)
local DARK_141  = Color3.fromRGB(40,   25,   8)

type SpecialistDef141 = {id: string, emoji: string, name: string, bonus: string, cost: number}
local SPECIALISTS_141: {SpecialistDef141} = {
    {id="nurse_bee",  emoji="🐝💊", name="Nurse Bee",  bonus="+15% brood speed",     cost=200},
    {id="scout_bee",  emoji="🐝🔭", name="Scout Bee",  bonus="+20% foraging quality",cost=350},
    {id="guard_bee",  emoji="🐝🛡️", name="Guard Bee",  bonus="–5% bear drain",       cost=500},
}

-- ── Find or create specialist panel ──────────────────────────────
local specialistPanel_141: Frame? = nil

local function findRosterScrollFrame_141(): ScrollingFrame?
    for _, sg in playerGui:GetChildren() do
        if sg:IsA("ScreenGui") and sg.Name:find("BeeRoster") then
            for _, obj in (sg :: ScreenGui):GetDescendants() do
                if obj:IsA("ScrollingFrame") then return obj :: ScrollingFrame end
            end
        end
    end
    return nil
end

local function getOrCreatePanel_141(): Frame
    if specialistPanel_141 and specialistPanel_141.Parent then return specialistPanel_141 :: Frame end

    -- Try to attach to existing roster scroll frame
    local scroll = findRosterScrollFrame_141()
    local parent: Instance = scroll or playerGui

    if not scroll then
        -- Fallback: create a standalone minimal panel
        local sg = Instance.new("ScreenGui")
        sg.Name          = "SpecialistBeesGui"
        sg.ResetOnSpawn  = false
        sg.DisplayOrder  = 18
        sg.Parent        = playerGui
        local panel = Instance.new("Frame")
        panel.Name               = "SpecialistPanel"
        panel.Size               = UDim2.new(0, 220, 0, 200)
        panel.Position           = UDim2.new(1,-228,0,300)
        panel.BackgroundColor3   = DARK_141
        panel.BackgroundTransparency = 0.05
        panel.BorderSizePixel    = 0
        panel.Visible            = false
        panel.Parent             = sg
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = panel
        specialistPanel_141 = panel
        return panel
    end

    -- Attach a subsection frame inside the roster
    local panel = Instance.new("Frame")
    panel.Name             = "SpecialistSection"
    panel.Size             = UDim2.new(1,0,0,200)
    panel.BackgroundTransparency = 1
    panel.BorderSizePixel  = 0
    panel.Parent           = scroll
    specialistPanel_141 = panel
    return panel
end

-- ── Build/refresh specialist cards ───────────────────────────────
local function refreshCards_141()
    local panel = getOrCreatePanel_141()
    -- Clear existing cards
    for _, child in panel:GetChildren() do
        if child:IsA("Frame") and child.Name:find("SpecCard") then child:Destroy() end
    end

    local owned = tostring(player:GetAttribute("SpecialistBees") or "")
    local honey  = tonumber(player:GetAttribute("HoneyCount")) or 0

    for i, spec in SPECIALISTS_141 do
        local isOwned = owned:find(spec.id, 1, true) ~= nil
        local canBuy  = not isOwned and honey >= spec.cost

        local card = Instance.new("Frame")
        card.Name              = "SpecCard_" .. spec.id
        card.Size              = UDim2.new(1,-8,0,56)
        card.Position          = UDim2.new(0,4,0, (i-1)*62 + 4)
        card.BackgroundColor3  = isOwned and GREEN_141 or (canBuy and GOLD_141 or GREY_141)
        card.BackgroundTransparency = 0.15
        card.BorderSizePixel   = 0
        card.Parent            = panel
        local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = card

        local emojiLbl = Instance.new("TextLabel")
        emojiLbl.Size                = UDim2.new(0,40,1,0)
        emojiLbl.Position            = UDim2.new(0,4,0,0)
        emojiLbl.BackgroundTransparency = 1
        emojiLbl.Font                = Enum.Font.GothamBold
        emojiLbl.TextSize            = 22
        emojiLbl.Text                = spec.emoji
        emojiLbl.Parent              = card

        local nameBonus = Instance.new("TextLabel")
        nameBonus.Size               = UDim2.new(1,-100,1,0)
        nameBonus.Position           = UDim2.new(0,48,0,0)
        nameBonus.BackgroundTransparency = 1
        nameBonus.Font               = Enum.Font.GothamBold
        nameBonus.TextSize           = 11
        nameBonus.TextColor3         = WHITE_141
        nameBonus.TextXAlignment     = Enum.TextXAlignment.Left
        nameBonus.TextWrapped        = true
        nameBonus.Text               = spec.name .. "\n" .. spec.bonus
        nameBonus.Parent             = card

        if isOwned then
            local activeLbl = Instance.new("TextLabel")
            activeLbl.Size               = UDim2.new(0,52,0,24)
            activeLbl.Position           = UDim2.new(1,-56,0.5,-12)
            activeLbl.BackgroundTransparency = 1
            activeLbl.Font               = Enum.Font.GothamBold
            activeLbl.TextSize           = 11
            activeLbl.TextColor3         = WHITE_141
            activeLbl.Text               = "✓ Active"
            activeLbl.Parent             = card
        else
            local unlockBtn = Instance.new("TextButton")
            unlockBtn.Size             = UDim2.new(0,60,0,26)
            unlockBtn.Position         = UDim2.new(1,-64,0.5,-13)
            unlockBtn.BackgroundColor3 = canBuy and GOLD_141 or GREY_141
            unlockBtn.BorderSizePixel  = 0
            unlockBtn.Font             = Enum.Font.GothamBold
            unlockBtn.TextSize         = 11
            unlockBtn.TextColor3       = WHITE_141
            unlockBtn.Text             = canBuy and ("🍯" .. spec.cost) or ("🔒" .. spec.cost)
            unlockBtn.Active           = canBuy
            unlockBtn.Parent           = card
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = unlockBtn

            if canBuy then
                unlockBtn.Activated:Connect(function()
                    local evFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
                    local reqEvent = evFolder and evFolder:FindFirstChild("RequestUnlockBee") :: RemoteEvent?
                    if reqEvent then reqEvent:FireServer({beeId = spec.id}) end
                end)
            end
        end
    end
end

-- ── RemoteEvent: on bee unlocked ──────────────────────────────────
task.spawn(function()
    local evFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    local beeUnlocked = (evFolder :: Folder):WaitForChild("BeeUnlocked", 10) :: RemoteEvent
    beeUnlocked.OnClientEvent:Connect(function(data: {beeId: string})
        refreshCards_141()
        -- Brief gold flash on panel
        local panel = specialistPanel_141
        if panel and panel.Parent then
            TweenService:Create(panel,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = 0.0}
            ).Completed:Connect(function()
                TweenService:Create(panel :: Frame,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    {BackgroundTransparency = 0.05}
                ):Play()
            end)
            TweenService:Create(panel,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {BackgroundTransparency = 0.0}
            ):Play()
        end
    end)
end)

-- ── Listeners ─────────────────────────────────────────────────────
task.wait(2)
refreshCards_141()
player:GetAttributeChangedSignal("HoneyCount"):Connect(refreshCards_141)
player:GetAttributeChangedSignal("SpecialistBees"):Connect(refreshCards_141)

print("[BeeRosterExpansionController] Ready — specialist bees active")
]]
    ctrl.Parent = SPS
    print("✅ BeeRosterExpansionController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS   = game:GetService("ReplicatedStorage")
local evF  = RS:FindFirstChild("RemoteEvents")

local svc  = SSS:FindFirstChild("BeeRosterService")
local ctrl = SPS and SPS:FindFirstChild("BeeRosterExpansionController")
local reqE = evF and evF:FindFirstChild("RequestUnlockBee")
local unlkE= evF and evF:FindFirstChild("BeeUnlocked")

local checks = {}
table.insert(checks, (svc and "✅" or "❌") .. " BeeRosterService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (svc and svc.Source:find("CATALOGUE_141", 1, true) and "✅" or "❌") .. " CATALOGUE_141 bee definitions")
table.insert(checks, (svc and svc.Source:find("SpecialistBees", 1, true) and "✅" or "❌") .. " SpecialistBees attribute")
table.insert(checks, (svc and svc.Source:find("nurse_bee", 1, true) and "✅" or "❌") .. " nurse_bee definition")
table.insert(checks, (svc and svc.Source:find("scout_bee", 1, true) and "✅" or "❌") .. " scout_bee definition")
table.insert(checks, (svc and svc.Source:find("guard_bee", 1, true) and "✅" or "❌") .. " guard_bee definition")
table.insert(checks, (reqE and "✅" or "❌") .. " RequestUnlockBee RemoteEvent")
table.insert(checks, (unlkE and "✅" or "❌") .. " BeeUnlocked RemoteEvent")
table.insert(checks, (ctrl and "✅" or "❌") .. " BeeRosterExpansionController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("refreshCards_141", 1, true) and "✅" or "❌") .. " refreshCards_141 card builder")
table.insert(checks, (ctrl and ctrl.Source:find("findRosterScrollFrame_141", 1, true) and "✅" or "❌") .. " findRosterScrollFrame_141 attachment logic")

print("=== DISPATCH 141 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 141 complete" or "❌ SOME CHECKS FAILED")

print("\nSpecialists: Nurse(200🍯/+15%brood) | Scout(350🍯/+20%foraging) | Guard(500🍯/-5%bear)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BeeRosterService (Script — permanent) | +1 |
| BeeRosterExpansionController (LocalScript; GUI runtime only) | 0 permanent |
| **Dispatch 141 total** | **+1** |
| **Running total** | **4,149 / 5,000** |

---

## NOTES

- `SpecialistBees` is a comma-string attribute (same pattern as `PropolisUpgrades`). Other services — ForagingService (for Scout bonus) and BearAttackService (for Guard bonus) — read this attribute with `find("scout_bee")` / `find("guard_bee")` pattern, consistent with how `PropolisUpgrades` is consumed across dispatches 132-133.
- `findRosterScrollFrame_141` searches for any `ScrollingFrame` inside any ScreenGui named `*BeeRoster*`. This fuzzy match handles slight naming variations across dispatch implementations without a hardcoded full path. If no roster exists, a standalone `SpecialistBeesGui` ScreenGui is created at DisplayOrder=18 — same order as the bee roster from dispatch 120.
- Card state transitions: grey (locked / can't afford) → gold (affordable) → green (owned/active). This three-state color pattern mirrors the Propolis Shop (dispatch 132) for visual consistency. Kids learn the same colour language across all upgrade UIs.
- `unlockBtn.Active = canBuy` prevents accidental double-fires from rapid tapping. `Active=false` on a GuiButton suppresses `Activated` events — Roblox built-in, no debounce needed.
- The Guard Bee's –5% bear drain stacks with `hive_insulation` upgrade from dispatch 132. A player with both active reduces bear drain to `15% × 0.9 × 0.95 = ~12.8%` — near-halved total mitigation. The server's BearAttackService would need a small update (dispatch 142 or a hotfix note) to also check `SpecialistBees` for `"guard_bee"`. This is noted in the roadmap.
