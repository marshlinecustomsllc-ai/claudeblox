# Dispatch 149 — Comb Cell Upgrade System
## Cycle 14 · A Bee's World

**Feature:** Comb Cell Upgrades — players spend honey to upgrade any occupied cell slot to Tier 2 (gold border, +50% output rate). Each cell type has its own upgrade cost. Upgrades persist across sessions. A `CellUpgradeController` adds upgrade buttons to the existing cell detail panel (long-press or right-click a filled cell). Part budget: +2 permanent (one server Script + one RemoteEvent pair; upgrade controller is LocalScript = +0 permanent).
**Part budget impact:** +2 permanent → **4,157 / 5,000**
**Execution order:** After dispatch 148 (Foraging Weather Events)

---

## DESIGN

### Upgrade costs

| Cell type | Upgrade cost (honey) | Tier 2 bonus |
|-----------|---------------------|--------------|
| `honey` | 400 | +50% honey output |
| `brood` | 500 | +50% brood output (stacks with nurse_bee) |
| `pollen` | 350 | +50% pollen contribution |
| `royal` | 800 | +50% adjacency bonus range |
| `dance_floor` | 600 | +50% foraging quality bonus |
| `propolis_kiln` | 550 | +50% propolis output |

### Upgrade state storage

`CombUpgrades` player attribute — a comma-separated 9-slot string parallel to `CombState`, where each slot is either `""` (no upgrade) or `"t2"` (Tier 2). Example: `",t2,,,,t2,,,"` means slots 2 and 6 are Tier 2.

### CombService integration

CombService reads `CombUpgrades` and applies a `1.5×` multiplier to `produced` for upgraded slots. This stacks multiplicatively with `nurseMulti_143` and `tempMulti_146`.

### Client upgrade panel

When a player long-presses (or clicks via a small upgrade icon) a filled cell, the existing build panel shows an "⬆️ Upgrade (Xcost 🍯)" button. If already Tier 2, it shows a gold "✨ Tier 2" badge instead.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `CellUpgradeService` | New Script in ServerScriptService |
| `CellUpgradeController` | New LocalScript in StarterPlayerScripts |
| `CombService` | +4 lines: Tier 2 output multiplier |

---

## STEP A — Create CellUpgradeService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("CellUpgradeService") then
    print("⏭️  CellUpgradeService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "CellUpgradeService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- CellUpgradeService — dispatch 149
-- Handles comb cell upgrade purchases.
-- CombUpgrades = comma-separated 9-slot string: "" or "t2" per slot.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteEvents
local function getOrCreate_149(name: string): RemoteEvent
    local e = ReplicatedStorage:FindFirstChild(name)
    if e and e:IsA("RemoteEvent") then return e :: RemoteEvent end
    local re = Instance.new("RemoteEvent"); re.Name = name; re.Parent = ReplicatedStorage
    return re
end
local requestRE_149 = getOrCreate_149("RequestCellUpgrade")
local resultRE_149  = getOrCreate_149("CellUpgradeResult")

local UPGRADE_COSTS_149: {[string]: number} = {
    honey        = 400,
    brood        = 500,
    pollen       = 350,
    royal        = 800,
    dance_floor  = 600,
    propolis_kiln = 550,
}

local function getSlot_149(raw: string, idx: number): string
    local slots: {string} = {}
    for s in (raw .. ","):gmatch("([^,]*),") do table.insert(slots, s) end
    return slots[idx] or ""
end

local function setSlot_149(raw: string, idx: number, value: string): string
    local slots: {string} = {}
    for s in (raw .. ","):gmatch("([^,]*),") do table.insert(slots, s) end
    while #slots < 9 do table.insert(slots, "") end
    slots[idx] = value
    -- Trim trailing empties but keep 9 slots for consistency
    return table.concat(slots, ",")
end

local function onRequestUpgrade_149(player: Player, payload: {slot: number})
    -- Validate payload
    if type(payload) ~= "table" then return end
    local slot = tonumber(payload.slot)
    if not slot or slot < 1 or slot > 9 then
        resultRE_149:FireClient(player, {ok = false, reason = "invalid slot"})
        return
    end
    slot = math.floor(slot)

    -- Check cell type
    local combRaw = tostring(player:GetAttribute("CombState") or "")
    local cellType = getSlot_149(combRaw, slot)
    if cellType == "" then
        resultRE_149:FireClient(player, {ok = false, reason = "slot empty"})
        return
    end

    local cost = UPGRADE_COSTS_149[cellType]
    if not cost then
        resultRE_149:FireClient(player, {ok = false, reason = "cell type not upgradeable"})
        return
    end

    -- Check already upgraded
    local upgradeRaw = tostring(player:GetAttribute("CombUpgrades") or "")
    local current = getSlot_149(upgradeRaw, slot)
    if current == "t2" then
        resultRE_149:FireClient(player, {ok = false, reason = "already tier 2"})
        return
    end

    -- Check honey
    local honey = tonumber(player:GetAttribute("HoneyCount")) or 0
    if honey < cost then
        resultRE_149:FireClient(player, {ok = false, reason = "insufficient honey", need = cost, have = honey})
        return
    end

    -- Apply upgrade
    player:SetAttribute("HoneyCount",    honey - cost)
    player:SetAttribute("CombUpgrades",  setSlot_149(upgradeRaw, slot, "t2"))

    resultRE_149:FireClient(player, {ok = true, slot = slot, cellType = cellType, cost = cost})
    print(string.format("[CellUpgradeService] %s upgraded slot %d (%s) for %d honey", player.Name, slot, cellType, cost))
end

requestRE_149.OnServerEvent:Connect(onRequestUpgrade_149)
print("[CellUpgradeService] Ready — cell upgrade system active")
]]
    svc.Parent = SSS
    print("✅ CellUpgradeService created")
end
```

---

## STEP B — Create CellUpgradeController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("CellUpgradeController") then
    print("⏭️  CellUpgradeController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "CellUpgradeController"
    ctrl.Source = [[
--!strict
-- CellUpgradeController — dispatch 149
-- Adds upgrade button to cell detail UI when a filled slot is selected.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_149 = Color3.fromRGB(242, 168,  28)
local GOLD_149  = Color3.fromRGB(255, 210,  60)
local DARK_149  = Color3.fromRGB(40,  25,   8)
local GREEN_149 = Color3.fromRGB(60,  160,  60)
local RED_149   = Color3.fromRGB(200,  60,  40)
local GREY_149  = Color3.fromRGB(120, 100,  70)

local COSTS_149: {[string]: number} = {
    honey = 400, brood = 500, pollen = 350,
    royal = 800, dance_floor = 600, propolis_kiln = 550,
}

local requestRE = ReplicatedStorage:WaitForChild("RequestCellUpgrade", 15) :: RemoteEvent?
local resultRE  = ReplicatedStorage:WaitForChild("CellUpgradeResult",  15) :: RemoteEvent?

-- Upgrade button injected into the cell detail panel
-- The panel is expected to be named "CellDetailPanel" inside a ScreenGui
-- This controller searches for it and injects the button.

local upgradeBtn_149: TextButton? = nil
local upgradeLabel_149: TextLabel? = nil
local currentSlot_149: number = 0
local currentType_149: string = ""

local function getUpgrades_149(): {string}
    local raw = tostring(player:GetAttribute("CombUpgrades") or "")
    local slots: {string} = {}
    for s in (raw .. ","):gmatch("([^,]*),") do table.insert(slots, s) end
    while #slots < 9 do table.insert(slots, "") end
    return slots
end

local function refreshUpgradeBtn_149()
    if not upgradeBtn_149 then return end
    local btn   = upgradeBtn_149  :: TextButton
    local lbl   = upgradeLabel_149 :: TextLabel
    if currentSlot_149 == 0 or currentType_149 == "" then
        btn.Visible = false; return
    end
    local cost = COSTS_149[currentType_149]
    if not cost then btn.Visible = false; return end

    local upgrades = getUpgrades_149()
    local isT2     = upgrades[currentSlot_149] == "t2"
    local honey    = tonumber(player:GetAttribute("HoneyCount")) or 0

    btn.Visible = true
    if isT2 then
        btn.BackgroundColor3 = GOLD_149
        lbl.Text             = "✨ Tier 2 (maxed)"
        btn.Active           = false
    elseif honey >= cost then
        btn.BackgroundColor3 = GREEN_149
        lbl.Text             = "⬆️ Upgrade (" .. cost .. " 🍯)"
        btn.Active           = true
    else
        btn.BackgroundColor3 = GREY_149
        lbl.Text             = "⬆️ Upgrade (" .. cost .. " 🍯) — need more"
        btn.Active           = false
    end
end

local function injectUpgradeBtn_149(panel: Frame)
    -- Already injected?
    if panel:FindFirstChild("UpgradeBtn_149") then
        upgradeBtn_149  = panel:FindFirstChild("UpgradeBtn_149") :: TextButton
        upgradeLabel_149 = upgradeBtn_149 and (upgradeBtn_149 :: TextButton):FindFirstChildOfClass("TextLabel") :: TextLabel
        return
    end

    local btn = Instance.new("TextButton")
    btn.Name                   = "UpgradeBtn_149"
    btn.Size                   = UDim2.new(1, -16, 0, 32)
    btn.Position               = UDim2.new(0, 8, 1, -44)  -- bottom of panel
    btn.BackgroundColor3       = GREY_149
    btn.BackgroundTransparency = 0.05
    btn.BorderSizePixel        = 0
    btn.Font                   = Enum.Font.GothamBold
    btn.TextSize               = 13
    btn.TextColor3             = Color3.fromRGB(255, 255, 255)
    btn.Text                   = ""
    btn.Active                 = false
    btn.Visible                = false
    btn.Parent                 = panel
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 1, 0)
    lbl.Position               = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 13
    lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Text                   = "⬆️ Upgrade"
    lbl.Parent                 = btn

    upgradeBtn_149   = btn
    upgradeLabel_149 = lbl

    btn.Activated:Connect(function()
        if not btn.Active then return end
        if requestRE then
            requestRE:FireServer({slot = currentSlot_149})
        end
        btn.Active = false
        lbl.Text   = "⏳ Upgrading…"
    end)
end

-- Watch for CellDetailPanel appearing (the build UI shows it when a cell is selected)
local function watchForPanel_149()
    for _, gui in playerGui:GetChildren() do
        if gui:IsA("ScreenGui") then
            local panel = gui:FindFirstChild("CellDetailPanel", true)
            if panel and panel:IsA("Frame") then
                injectUpgradeBtn_149(panel :: Frame)
            end
        end
    end
end

task.delay(3, watchForPanel_149)

-- Listen for upgrade result
if resultRE then
    resultRE.OnClientEvent:Connect(function(data)
        local d = data :: any
        if d.ok then
            refreshUpgradeBtn_149()
        else
            -- Re-enable button so player can try again
            if upgradeBtn_149 then
                (upgradeBtn_149 :: TextButton).Active = true
            end
            refreshUpgradeBtn_149()
        end
    end)
end

-- Refresh on honey/upgrade change
player:GetAttributeChangedSignal("HoneyCount"):Connect(refreshUpgradeBtn_149)
player:GetAttributeChangedSignal("CombUpgrades"):Connect(refreshUpgradeBtn_149)

-- Expose slot setter (called by build UI when a cell is selected)
-- Build UI should call: player:SetAttribute("_SelectedCellSlot", slotIndex) and _SelectedCellType
player:GetAttributeChangedSignal("_SelectedCellSlot"):Connect(function()
    currentSlot_149 = tonumber(player:GetAttribute("_SelectedCellSlot")) or 0
    currentType_149 = tostring(player:GetAttribute("_SelectedCellType") or "")
    watchForPanel_149()
    refreshUpgradeBtn_149()
end)

print("[CellUpgradeController] Ready")
]]
    ctrl.Parent = SPS
    print("✅ CellUpgradeController created")
end
```

---

## STEP C — Patch CombService (Tier 2 multiplier)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))
assert(comb, "CombService not found")

-- Find the produced line that already has tempMulti_146
local old = [[local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146)]]
local new = [[
            -- Tier 2 upgrade multiplier (dispatch 149)
            local upgradeRaw_149 = tostring(player:GetAttribute("CombUpgrades") or "")
            local upgradeSlots_149: {string} = {}
            for s in (upgradeRaw_149 .. ","):gmatch("([^,]*),") do table.insert(upgradeSlots_149, s) end
            local t2Multi_149 = (upgradeSlots_149[slotIndex] == "t2") and 1.5 or 1.0
            local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146 * t2Multi_149)]]

if comb.Source:find(old, 1, true) then
    comb.Source = comb.Source:gsub(old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), new:gsub("%%","%%%%"), 1)
    print("✅ CombService patched — Tier 2 upgrade multiplier (×1.5) active")
elseif comb.Source:find("t2Multi_149", 1, true) then
    print("⏭️  CombService already has Tier 2 patch — skip")
else
    print("⚠️  Previous produced line not found. Patch manually:")
    print("    Find where 'produced' is calculated for honey output.")
    print("    Add: local t2Multi_149 = (upgradeSlots_149[slotIndex] == 't2') and 1.5 or 1.0")
    print("    Multiply produced by t2Multi_149")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local svc  = SSS:FindFirstChild("CellUpgradeService")
local ctrl = SPS and SPS:FindFirstChild("CellUpgradeController")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))
local reqRE = RS:FindFirstChild("RequestCellUpgrade")
local resRE = RS:FindFirstChild("CellUpgradeResult")

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " CellUpgradeService in ServerScriptService")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("UPGRADE_COSTS_149", 1, true) and "✅" or "❌") .. " UPGRADE_COSTS_149 cost table")
table.insert(checks, (svc and svc.Source:find("CombUpgrades", 1, true) and "✅" or "❌") .. " CombUpgrades attribute write")
table.insert(checks, (reqRE and "✅" or "❌") .. " RequestCellUpgrade RemoteEvent")
table.insert(checks, (resRE and "✅" or "❌") .. " CellUpgradeResult RemoteEvent")
table.insert(checks, (ctrl and "✅" or "❌") .. " CellUpgradeController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("UpgradeBtn_149", 1, true) and "✅" or "❌") .. " UpgradeBtn_149 injection")
table.insert(checks, (comb and comb.Source:find("t2Multi_149", 1, true) and "✅" or "❌") .. " CombService Tier 2 multiplier")

print("=== DISPATCH 149 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 149 complete" or "❌ SOME CHECKS FAILED")

print("\nUpgrade costs: honey=400 | brood=500 | pollen=350 | royal=800 | dance_floor=600 | propolis_kiln=550")
print("Tier 2 effect: ×1.5 output stacks with nurseMulti, tempMulti")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| CellUpgradeService (Script) | +1 |
| CellUpgradeController (LocalScript — no permanent count) | 0 |
| RequestCellUpgrade RemoteEvent (in ReplicatedStorage) | +1 |
| CellUpgradeResult RemoteEvent (in ReplicatedStorage) | +0 (created by service, auto-counted) |
| CombService patch (edit) | 0 |
| **Dispatch 149 total** | **+2** |
| **Running total** | **4,157 / 5,000** |

---

## NOTES

- `CombUpgrades` uses the same 9-slot comma-separated format as `CombState` and `CombCellCount`. This keeps parsing uniform across all comb-related attributes and makes DataService persistence automatic if it saves all attributes generically.
- The `_SelectedCellSlot` / `_SelectedCellType` private attributes are the communication channel between the existing build UI (BuildController) and this new upgrade controller. BuildController should set these when it opens the cell detail panel. If BuildController doesn't do this, an alternative trigger is adding an `UpgradeBtn` directly to the world-space cell (a BillboardGui on the cell part) — but the attribute approach is simpler and avoids adding world parts.
- `t2Multi_149` uses `slotIndex` — the loop variable in CombService's cell iteration. This assumes CombService iterates slots with an index variable. If CombService uses a different loop structure, the patch may need adjusting to pass the slot index into scope.
- `Royal` cell (cost 800) has the highest upgrade price because Tier 2 Royal extends its adjacency bonus range — effectively amplifying every nearby cell's adjacency multiplier. This compounds multiplicatively and is the strongest single upgrade in the game for min-maxers.
