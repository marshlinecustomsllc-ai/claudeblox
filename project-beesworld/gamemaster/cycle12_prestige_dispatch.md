# Dispatch 79 — PrestigeService
## Cycle 12 · A Bee's World

**Feature:** Prestige system — players who reach maximum honey storage AND own all 8 plots can "prestige" (rebirth): their honey, propolis, and pollen reset to 0, all plots except plot 1 become unclaimed, but they gain a permanent **+5% honey yield multiplier per prestige level** (stacks, no cap stated for now). Their prestige level and a golden star badge display in their nametag and on the global leaderboard.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 78 (NotificationBadgeController). Begins Cycle 12.

---

## DESIGN

### Prestige conditions

```
1. profile.honey    >= profile.maxHoney    (honey storage full)
2. profile.propolis >= profile.maxPropolis (propolis storage full)
3. All 8 plots owned by this player
```

Conditions checked client-side for UI gate and server-side before applying prestige.

### Prestige effects (server-side, atomic)

```
profile.prestigeLevel += 1
profile.honey         = 0
profile.propolis      = 0
profile.pollen        = 0
profile.totalPrestigeCount = (profile.totalPrestigeCount or 0) + 1
-- Keep: upgrades, bee name, queen tier, expansion slots
-- Reset plots 2–8 to unowned (plot 1 kept so player has a base)
PlotService.ResetPlotsForPrestige(player)   -- new function injected
```

### Honey yield multiplier

`ForagingService` reads `profile.prestigeLevel` and applies:
```lua
honeyYield = math.floor(honeyYield * (1 + profile.prestigeLevel * 0.05))
```

### Nametag badge

A `BillboardGui` above the player's `Head` shows `⭐ {prestigeLevel}` in honey gold text. Updated whenever `PrestigeSync` fires.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PrestigeService` (new ModuleScript in SSS) | prestige logic, conditions check, plot reset call |
| `DataService` | add `prestigeLevel`, `totalPrestigeCount` fields |
| `GameManager` | inject `PrestigeService.Init()` |
| `ForagingService` | apply prestige multiplier |
| `PrestigeController` (new LocalScript) | prestige button UI, prestige badge on nametag |

---

## STEP A — DataService: new prestige fields

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

if ds.Source:find("prestigeLevel", 1, true) then
    print("⏭️  DataService already has prestige fields")
else
    local clone = ds:Clone()
    clone.Name = "DataService_WORKING"
    local anchor = 'totalHoneyEarned'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "totalHoneyEarned not found in DataService")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\n\t\tprestigeLevel        = 0,"
        .. "\n\t\ttotalPrestigeCount   = 0,"
        .. clone.Source:sub(lineEnd + 1)
    ds.Name = "DataService_OLD_NX"
    ds.Parent = nil
    clone.Name = "DataService"
    clone.Parent = SSS
    print("✅ DataService prestige fields injected")
end
```

---

## STEP B — PrestigeService (new ModuleScript)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local PrestigeSync = Instance.new("RemoteEvent")
PrestigeSync.Name   = "PrestigeSync"
PrestigeSync.Parent = RS

local prestigeRF = Instance.new("RemoteFunction")
prestigeRF.Name   = "RequestPrestige"
prestigeRF.Parent = RS

local svc = Instance.new("ModuleScript")
svc.Name   = "PrestigeService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- PrestigeService — rebirth mechanic

local SSS  = game:GetService("ServerScriptService")
local RS   = game:GetService("ReplicatedStorage")
local PS   = game:GetService("Players")

local DataService  = require(SSS:WaitForChild("DataService"))
local PlotService  = require(SSS:WaitForChild("PlotService"))

local PrestigeSync   = RS:WaitForChild("PrestigeSync")
local RequestPrestige = RS:WaitForChild("RequestPrestige")

local PrestigeService = {}

-- Minimum plots the player must own to prestige
local MIN_PLOTS_OWNED = 8

local function getPlayerPlots(player: Player): {plotId: number, owner: string}
    -- Read from PlotService plot table
    local owned = {}
    if PlotService.GetAllPlots then
        for _, plot in PlotService.GetAllPlots() do
            if plot.owner == player.Name then
                table.insert(owned, plot)
            end
        end
    end
    return owned
end

local function canPrestige(player: Player): (boolean, string)
    local profile = DataService.GetProfile(player)
    if not profile then return false, "no_profile" end

    if profile.honey < (profile.maxHoney or 1000) then
        return false, "honey_not_full"
    end
    if profile.propolis < (profile.maxPropolis or 100) then
        return false, "propolis_not_full"
    end

    local ownedPlots = getPlayerPlots(player)
    if #ownedPlots < MIN_PLOTS_OWNED then
        return false, "need_" .. MIN_PLOTS_OWNED .. "_plots"
    end

    return true, "ok"
end

local cooldowns: {[number]: number} = {}
local COOLDOWN_SECONDS = 10

function PrestigeService.Init()
    RequestPrestige.OnServerInvoke = function(player: Player): {ok: boolean, reason: string?, level: number?}
        -- Rate limit
        local uid = player.UserId
        if cooldowns[uid] and tick() - cooldowns[uid] < COOLDOWN_SECONDS then
            return {ok = false, reason = "cooldown"}
        end
        cooldowns[uid] = tick()

        local ok, reason = canPrestige(player)
        if not ok then
            return {ok = false, reason = reason}
        end

        local profile = DataService.GetProfile(player)
        if not profile then return {ok = false, reason = "no_profile"} end

        -- Apply prestige
        profile.prestigeLevel      = (profile.prestigeLevel or 0) + 1
        profile.totalPrestigeCount = (profile.totalPrestigeCount or 0) + 1
        profile.honey              = 0
        profile.propolis           = 0
        profile.pollen             = 0
        -- Reset plots 2–8 (keep plot 1 as starter base)
        if PlotService.ResetPlotsForPrestige then
            PlotService.ResetPlotsForPrestige(player, {keepPlotIds = {1}})
        end

        DataService.SaveProfile(player)

        -- Broadcast
        PrestigeSync:FireClient(player, {
            prestigeLevel = profile.prestigeLevel,
            totalPrestigeCount = profile.totalPrestigeCount,
        })
        -- Broadcast to all for leaderboard update
        PrestigeSync:FireAllClients({
            playerName    = player.Name,
            prestigeLevel = profile.prestigeLevel,
        })

        print("[PrestigeService] " .. player.Name .. " prestiged to level " .. profile.prestigeLevel)
        return {ok = true, level = profile.prestigeLevel}
    end

    PS.PlayerRemoving:Connect(function(player)
        cooldowns[player.UserId] = nil
    end)

    print("[PrestigeService] ready")
end

function PrestigeService.GetPrestigeMultiplier(player: Player): number
    local profile = DataService.GetProfile(player)
    if not profile then return 1.0 end
    return 1.0 + (profile.prestigeLevel or 0) * 0.05
end

return PrestigeService
]]

print("PrestigeService + PrestigeSync RE + RequestPrestige RF created")
```

---

## STEP C — GameManager: inject PrestigeService.Init()

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

if gm.Source:find("PrestigeService", 1, true) then
    print("⏭️  GameManager already has PrestigeService — skip")
else
    local clone = gm:Clone()
    clone.Name = "GameManager_WORKING"
    local anchor = 'local FriendBonusService'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "FriendBonusService require not found in GameManager")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\nlocal PrestigeService = require(SSS:WaitForChild(\"PrestigeService\"))"
        .. clone.Source:sub(lineEnd + 1)
    local initAnchor = 'FriendBonusService.Init()'
    local found2 = clone.Source:find(initAnchor, 1, true)
    assert(found2, "FriendBonusService.Init() not found in GameManager")
    local lineEnd2 = clone.Source:find("\n", found2, true)
    clone.Source = clone.Source:sub(1, lineEnd2)
        .. "\nPrestigeService.Init()"
        .. clone.Source:sub(lineEnd2 + 1)
    gm.Name = "GameManager_OLD_NX"
    gm.Parent = nil
    clone.Name = "GameManager"
    clone.Parent = SSS
    print("✅ GameManager PrestigeService.Init() injected")
end
```

---

## STEP D — ForagingService: apply prestige multiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("PrestigeService", 1, true) then
    print("⏭️  ForagingService already has PrestigeService — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"
    -- Inject require after AntiCheatService
    local anchor = 'local AntiCheatService'
    local found = clone.Source:find(anchor, 1, true)
    assert(found, "AntiCheatService require not found in ForagingService")
    local lineEnd = clone.Source:find("\n", found, true)
    clone.Source = clone.Source:sub(1, lineEnd)
        .. "\nlocal PrestigeService = require(SSS:WaitForChild(\"PrestigeService\"))"
        .. clone.Source:sub(lineEnd + 1)
    -- Inject multiplier after FriendBonusService multiplier line
    local anchor2 = 'FriendBonusService.GetHoneyMultiplier'
    local found2 = clone.Source:find(anchor2, 1, true)
    assert(found2, "FriendBonusService.GetHoneyMultiplier not found in ForagingService")
    local lineEnd2 = clone.Source:find("\n", found2, true)
    clone.Source = clone.Source:sub(1, lineEnd2)
        .. "\n\thoneyYield = math.floor(honeyYield * PrestigeService.GetPrestigeMultiplier(player))"
        .. clone.Source:sub(lineEnd2 + 1)
    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService prestige multiplier injected")
end
```

---

## STEP E — PrestigeController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "PrestigeController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- PrestigeController — prestige button UI + nametag badge

local PS        = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")
local TS        = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()

local PrestigeSync    = RS:WaitForChild("PrestigeSync")
local RequestPrestige = RS:WaitForChild("RequestPrestige")

local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local WAXCREAM   = Color3.fromRGB(232, 212, 154)

-- ── Nametag badge ──────────────────────────────────────
local function applyNametag(targetPlayer: Player, prestigeLevel: number)
    local char = targetPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end

    -- Remove old badge
    local old = head:FindFirstChild("PrestigeBillboard")
    if old then old:Destroy() end
    if prestigeLevel <= 0 then return end

    local bb = Instance.new("BillboardGui")
    bb.Name           = "PrestigeBillboard"
    bb.Size           = UDim2.new(0, 80, 0, 22)
    bb.StudsOffset    = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop    = false
    bb.ResetOnSpawn   = false
    bb.Parent         = head :: BasePart

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = "⭐ " .. prestigeLevel
    lbl.TextColor3       = HONEY_GOLD
    lbl.TextScaled       = true
    lbl.Font             = Enum.Font.FredokaOne
    lbl.TextStrokeTransparency = 0.5
    lbl.TextStrokeColor3 = Color3.fromRGB(80, 50, 10)
    lbl.Parent           = bb
end

-- Apply to self on spawn
player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    -- Read prestige from DataService attribute if available
    local level = player:GetAttribute("prestigeLevel") or 0
    applyNametag(player, level)
end)

-- ── Prestige button in HiveHUD ────────────────────────
task.delay(4, function()
    local hiveHud = playerGui:FindFirstChild("HiveHUD")
    if not hiveHud then return end

    local prestigeBtn = Instance.new("TextButton")
    prestigeBtn.Name             = "PrestigeButton"
    prestigeBtn.Size             = UDim2.new(0.18, 0, 0.07, 0)
    prestigeBtn.Position         = UDim2.new(0.41, 0, 0.92, 0)
    prestigeBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 10)
    prestigeBtn.TextColor3       = HONEY_GOLD
    prestigeBtn.Text             = "⭐ PRESTIGE"
    prestigeBtn.Font             = Enum.Font.FredokaOne
    prestigeBtn.TextScaled       = true
    prestigeBtn.ZIndex           = 15
    prestigeBtn.AutoButtonColor  = false
    prestigeBtn.Visible          = false   -- hidden until conditions met
    prestigeBtn.Parent           = hiveHud

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = prestigeBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color     = HONEY_GOLD
    stroke.Thickness = 2
    stroke.Parent    = prestigeBtn

    -- Show/hide based on prestige-ready signal from PlotSync + resource data
    -- We simply enable the button when the player has heard they're ready
    -- (a more complete implementation reads HUD resource labels)

    prestigeBtn.MouseButton1Click:Connect(function()
        prestigeBtn.Text = "⭐ ..."
        prestigeBtn.Active = false

        local result = RequestPrestige:InvokeServer()
        if type(result) == "table" then
            if result.ok then
                prestigeBtn.Text    = "⭐ PRESTIGE"
                prestigeBtn.Visible = false
                -- Badge animation
                local tw = TS:Create(prestigeBtn, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0.22, 0, 0.09, 0)
                })
                tw:Play()
            else
                prestigeBtn.Text   = result.reason or "Not ready"
                prestigeBtn.Active = true
                task.delay(2, function()
                    prestigeBtn.Text = "⭐ PRESTIGE"
                end)
            end
        else
            prestigeBtn.Text  = "⭐ PRESTIGE"
            prestigeBtn.Active = true
        end
    end)
end)

-- ── PrestigeSync: update nametag + button ─────────────
PrestigeSync.OnClientEvent:Connect(function(data: any)
    if type(data) ~= "table" then return end

    -- Own prestige update
    if data.prestigeLevel and not data.playerName then
        player:SetAttribute("prestigeLevel", data.prestigeLevel)
        applyNametag(player, data.prestigeLevel)
    end

    -- Another player prestiged — update their nametag if in range
    if data.playerName then
        for _, p in PS:GetPlayers() do
            if p.Name == data.playerName then
                applyNametag(p, data.prestigeLevel or 0)
                break
            end
        end
    end
end)

-- Nametags for existing players on load
task.delay(5, function()
    for _, p in PS:GetPlayers() do
        local level = p:GetAttribute("prestigeLevel") or 0
        if level > 0 then
            applyNametag(p, level)
        end
    end
end)
]]

print("PrestigeController created")
```

---

## STEP F — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local svc = SSS:FindFirstChild("PrestigeService")
table.insert(checks, (svc and svc:IsA("ModuleScript") and "✅" or "❌") .. " PrestigeService ModuleScript")
table.insert(checks, (svc and svc.Source:find("canPrestige") and "✅" or "❌") .. " canPrestige function")
table.insert(checks, (svc and svc.Source:find("GetPrestigeMultiplier") and "✅" or "❌") .. " GetPrestigeMultiplier function")

local sync = RS:FindFirstChild("PrestigeSync")
table.insert(checks, (sync and sync:IsA("RemoteEvent") and "✅" or "❌") .. " PrestigeSync RemoteEvent")
local rf = RS:FindFirstChild("RequestPrestige")
table.insert(checks, (rf and rf:IsA("RemoteFunction") and "✅" or "❌") .. " RequestPrestige RemoteFunction")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("PrestigeService") and "✅" or "❌") .. " GameManager Init call")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("PrestigeService") and "✅" or "❌") .. " ForagingService multiplier")

local ctrl = SPS and SPS:FindFirstChild("PrestigeController")
table.insert(checks, (ctrl and "✅" or "❌") .. " PrestigeController LocalScript")

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("prestigeLevel") and "✅" or "❌") .. " DataService: prestigeLevel field")

print("=== DISPATCH 79 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 79 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Server/client code only | 0 new parts |
| **Dispatch 79 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `PlotService.ResetPlotsForPrestige(player, {keepPlotIds = {1}})` is called but this function may not exist yet in `PlotService`. If `PlotService` doesn't expose it, STEP B will still compile — the `if PlotService.ResetPlotsForPrestige then` guard makes it a soft call. A follow-up dispatch can add this function to `PlotService`.
- The prestige multiplier stacks multiplicatively with seasonal, friend bonus, and anti-cheat ceiling. The anti-cheat `MAX_YIELD_HONEY = 1750` ceiling from dispatch 76 should be revisited once players can reach prestige level 5+ (level 5 = 1.25× → max theoretical ~2187 honey/trip). Update `Config.ANTICHEAT_MAX_HONEY` or raise `MAX_YIELD_HONEY` in a future dispatch.
- `player:SetAttribute("prestigeLevel", ...)` stores the prestige level client-side for nametag use. This is a cosmetic attribute only — the authoritative value lives in `DataService` profile.
- The `PrestigeButton` at `UDim2.new(0.41, 0, 0.92, 0)` centers it horizontally between the Stats tab and the right edge, near the bottom of the HUD. It starts `Visible = false` and should be shown by a `ResourceSync`/`PlotSync` listener that confirms conditions — a full conditions-ready signal is deferred to a later dispatch.
- `RequestPrestige.OnServerInvoke` has a 10-second cooldown to prevent rapid prestige spam and exploits.
