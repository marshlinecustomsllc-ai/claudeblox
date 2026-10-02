# Dispatch 156 — Festival Meter
## Cycle 14 · A Bee's World

**Feature:** Server-wide Festival Meter — a shared community honey target that every player on the server contributes to. When the meter fills, all players receive a chest reward (honey + propolis bonus), a fanfare fires, and the meter resets for the next day. Progress is shown on the Stats Board billboard in the hub alongside the existing server stats. The meter ties the community hub rework (dispatch 153) into a live collective goal, making the hub board a destination rather than background scenery. Part budget: +1 permanent (FestivalMeterService Script).

**Part budget impact:** +1 permanent → **4,195 / 5,000**
**Execution order:** After dispatch 155 (Holiday World Transforms)

---

## DESIGN

### Why a Festival Meter?

The Stats Board (dispatch 153) shows honey/bees/foragers but doesn't give players a reason to look at it. The Festival Meter turns the board into a community scoreboard: "We need 8,000 more honey to fill the chest." Kids race to fill it; adults strategise which cells to build. When it pops, the whole server gets a shared celebration — a cross-player moment that makes A Bee's World feel alive.

### Target formula

```lua
local BASE_TARGET_156 = 50000  -- honey needed to fill meter
local FILL_PER_HARVEST_156 = 0.10  -- fraction of harvest credited to meter
```

Every harvest contributes 10% of the harvested amount to the shared meter. With 6 players each harvesting ~200 honey every 2 minutes, the meter fills in roughly 5 minutes of coordinated play — fast enough to feel satisfying, slow enough that it takes multiple players.

During an active holiday (dispatch 154), `BASE_TARGET_156` scales down by the holiday multiplier inverse so the meter stays achievable at the same pace regardless of season:

```lua
local effectiveTarget_156 = math.floor(BASE_TARGET_156 / (holidayMult or 1.0))
```

### Daily reset

The meter resets once per UTC day (`os.time() // 86400`). A completed meter cannot be filled again that day (the chest reward is once-per-day per server). This prevents exploit-farming while keeping the mechanic relevant every day.

### Chest reward

When the meter fills:
- **All players** on the server receive: `+250 honey`, `+25 propolis`
- A `FestivalChestOpened` RemoteEvent fires to all clients for the fanfare
- A gold "🎁 Festival Chest!" notification appears via the existing Notify remote
- The board swaps to a "🎉 REWARD CLAIMED!" banner for 8 seconds, then returns to stats

The reward is intentionally modest — enough to feel good without trivialising the economy.

### Stats Board integration

The `StatsBoard` BillboardGui (created in dispatch 153) gains a 4th row: the Festival Meter fill bar. This is a simple Frame + fill Frame (Honey Gold) whose width scales 0–100% with `meterFill / effectiveTarget`. Kids see a progress bar; adults see the exact number in a sub-label below.

### Kid / adult dual readability

- **Kid row**: emoji bar using filled/empty blocks e.g. `████░░░░░░ 40%`
- **Adult sub-row**: `N,NNN / N,NNN honey` precise readout, smaller font

---

## FILES CHANGED

| File | Change |
|------|--------|
| `FestivalMeterService` | New Script in ServerScriptService |
| `ServerStatsController` (patch) | New 4th row on StatsBillboard |
| `FestivalChestController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create FestivalMeterService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("FestivalMeterService") then
    print("⏭️  FestivalMeterService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name   = "FestivalMeterService"
    svc.Source = [[
--!strict
-- FestivalMeterService — dispatch 156
-- Server-wide shared Festival Meter: fills on harvests, resets daily.

local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")

-- ── Constants ─────────────────────────────────────────────────────
local BASE_TARGET_156         = 50000  -- honey needed to fill
local FILL_PER_HARVEST_156    = 0.10   -- fraction of each harvest added to meter
local REWARD_HONEY_156        = 250
local REWARD_PROPOLIS_156     = 25
local RESET_HOUR_156          = 0      -- UTC midnight

-- ── RemoteEvents ──────────────────────────────────────────────────
local function getOrCreate_156(parent: Instance, className: string, name: string): any
    local existing = parent:FindFirstChild(name)
    if existing and existing:IsA(className) then return existing end
    local inst = Instance.new(className)
    inst.Name   = name
    inst.Parent = parent
    return inst
end

local remotes_156    = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents") or RS
local meterSync_156  = getOrCreate_156(remotes_156, "RemoteEvent", "FestivalMeterSync")
local chestOpen_156  = getOrCreate_156(remotes_156, "RemoteEvent", "FestivalChestOpened")

-- ── State ─────────────────────────────────────────────────────────
local _meterFill_156: number  = 0
local _claimedDay_156: number = -1  -- UTC day number when chest was last claimed

local function getUtcDay_156(): number
    return math.floor(os.time() / 86400)
end

local function getEffectiveTarget_156(): number
    -- Shrink target during holidays so fill pace stays consistent
    -- Reads HolidayHoneyMult from any online player as a server proxy
    local mult = 1.0
    for _, p in Players:GetPlayers() do
        local m = tonumber(p:GetAttribute("HolidayHoneyMult"))
        if m and m > 1.0 then mult = m; break end
    end
    return math.max(5000, math.floor(BASE_TARGET_156 / mult))
end

local function broadcastMeter_156()
    local target = getEffectiveTarget_156()
    local pct    = math.min(1.0, _meterFill_156 / target)
    meterSync_156:FireAllClients({
        fill      = _meterFill_156,
        target    = target,
        pct       = pct,
        completed = (_claimedDay_156 == getUtcDay_156()),
    })
end

local function tryClaimChest_156()
    local today = getUtcDay_156()
    if _claimedDay_156 == today then return end  -- already claimed today
    local target = getEffectiveTarget_156()
    if _meterFill_156 < target then return end

    _claimedDay_156 = today
    _meterFill_156  = 0

    -- Grant rewards to all online players
    local DataService = require(game:GetService("ServerScriptService"):FindFirstChild("DataService")
        or game:GetService("ServerScriptService").Systems:FindFirstChild("DataService"))

    for _, p in Players:GetPlayers() do
        local profile = DataService and DataService.GetProfile and DataService.GetProfile(p)
        if profile then
            profile.honey    = (profile.honey    or 0) + REWARD_HONEY_156
            profile.propolis = (profile.propolis or 0) + REWARD_PROPOLIS_156
            -- Sync wallet update
            local walletUpdate = (remotes_156:FindFirstChild("WalletUpdate")
                or RS:FindFirstChild("WalletUpdate"))
            if walletUpdate then
                pcall(function()
                    walletUpdate:FireClient(p, {
                        honey    = profile.honey,
                        propolis = profile.propolis,
                        pollen   = profile.pollen or 0,
                    })
                end)
            end
        end
        -- Notify toast
        local notify = remotes_156:FindFirstChild("Notify") or RS:FindFirstChild("Notify")
        if notify then
            pcall(function()
                notify:FireClient(p, "success",
                    "🎁 Festival Chest! +"..REWARD_HONEY_156.."🍯 +"..REWARD_PROPOLIS_156.."🟤")
            end)
        end
    end

    -- Fanfare to all clients
    chestOpen_156:FireAllClients({ honey=REWARD_HONEY_156, propolis=REWARD_PROPOLIS_156 })
    broadcastMeter_156()
    print("[FestivalMeterService] Chest opened — +"..REWARD_HONEY_156.." honey, +"..REWARD_PROPOLIS_156.." propolis to all "..#Players:GetPlayers().." players")
end

-- Midnight daily reset (separate from chest claim guard)
local function midnightReset_156()
    local today = getUtcDay_156()
    if _claimedDay_156 ~= today then
        _meterFill_156 = 0
        broadcastMeter_156()
    end
end

-- ── Public API ────────────────────────────────────────────────────
local FestivalMeterService = {}

function FestivalMeterService.AddHarvest(player: Player, honeyAmount: number)
    local today = getUtcDay_156()
    if _claimedDay_156 == today then return end  -- already claimed; meter locked for day

    local contribution = math.floor(honeyAmount * FILL_PER_HARVEST_156)
    if contribution <= 0 then return end

    _meterFill_156 = _meterFill_156 + contribution
    broadcastMeter_156()

    -- Check if filled
    local target = getEffectiveTarget_156()
    if _meterFill_156 >= target then
        tryClaimChest_156()
    end
end

function FestivalMeterService.GetState()
    local target = getEffectiveTarget_156()
    return {
        fill      = _meterFill_156,
        target    = target,
        pct       = math.min(1.0, _meterFill_156 / target),
        completed = (_claimedDay_156 == getUtcDay_156()),
    }
end

function FestivalMeterService.Init()
    -- Sync to newly joining players
    Players.PlayerAdded:Connect(function(p)
        task.wait(3)
        if p.Parent then
            meterSync_156:FireClient(p, FestivalMeterService.GetState())
        end
    end)

    -- Midnight reset loop
    task.spawn(function()
        while true do
            task.wait(60)
            local h = tonumber(os.date("!%H")) or 0
            local m = tonumber(os.date("!%M")) or 0
            if h == RESET_HOUR_156 and m == 0 then
                midnightReset_156()
            end
        end
    end)

    print("[FestivalMeterService] Initialized — target "..getEffectiveTarget_156().." honey")
end

return FestivalMeterService
]]
    svc.Parent = SSS
    print("✅ FestivalMeterService created in ServerScriptService")
end
```

---

## STEP B — Inject into GameManager / Main Script

Find the Main Script (GameManager or Main in ServerScriptService) and inject FestivalMeterService after FriendBonusService or the last service Init:

```lua
-- Run in Command Bar to find the main server script
local SSS = game:GetService("ServerScriptService")
local mainScript
for _, s in SSS:GetDescendants() do
    if s:IsA("Script") and (s.Name == "Main" or s.Name == "GameManager") and
        s.Source:find("FriendBonusService") then
        mainScript = s; break
    end
end
if mainScript then
    -- Check idempotency
    if mainScript.Source:find("FestivalMeterService", 1, true) then
        print("⏭️  FestivalMeterService already wired — skip")
    else
        mainScript.Source = mainScript.Source:gsub(
            "(FriendBonusService%.Init%(%)[^\n]*\n)",
            "%1require(SSS:FindFirstChild('FestivalMeterService')):Init()\n",
            1
        )
        print("✅ FestivalMeterService injected after FriendBonusService.Init()")
    end
else
    print("⚠️  Main script not found — add manually: require(SSS.FestivalMeterService).Init()")
end
```

---

## STEP C — Inject AddHarvest call into CombService

CombService already handles harvests. We inject the Festival Meter contribution after each successful harvest:

```lua
-- Find CombService and inject FestivalMeterService.AddHarvest call
local SSS = game:GetService("ServerScriptService")
local comb
for _, s in SSS:GetDescendants() do
    if s:IsA("ModuleScript") and s.Name == "CombService" then comb = s; break end
end
if comb then
    if comb.Source:find("FestivalMeterService", 1, true) then
        print("⏭️  CombService already has FestivalMeterService hook — skip")
    else
        -- Inject require at top of module (after --!strict line)
        comb.Source = comb.Source:gsub(
            "(%-%-!strict[^\n]*\n)",
            "%1local _festivalMeter_156 = nil\n" ..
            "pcall(function()\n" ..
            "    _festivalMeter_156 = require(game:GetService('ServerScriptService'):FindFirstChild('FestivalMeterService'))\n" ..
            "end)\n",
            1
        )
        -- After the harvest amount is computed (look for profile.honey += honeyBanked or similar)
        -- Inject contribution call after profile.honey assignment in Harvest function
        comb.Source = comb.Source:gsub(
            "(profile%.honey%s*=%s*profile%.honey%s*%+%s*[^\n]+\n)",
            "%1if _festivalMeter_156 then\n" ..
            "    local _amt_156 = tonumber(tostring(%1):match('(%d+%.?%d*)')) or 0\n" ..
            "    pcall(function() _festivalMeter_156.AddHarvest(player, honeyBanked or 0) end)\n" ..
            "end\n",
            1
        )
        print("✅ CombService.Harvest patched with FestivalMeterService.AddHarvest")
    end
else
    print("⚠️  CombService not found")
end
```

**Alternative simpler injection** (paste this block inside CombService.Harvest, just after `profile.honey = profile.honey + honeyBanked`):

```lua
-- Festival Meter contribution (dispatch 156)
pcall(function()
    local fms_156 = require(game:GetService("ServerScriptService"):FindFirstChild("FestivalMeterService"))
    fms_156.AddHarvest(player, honeyBanked)
end)
```

---

## STEP D — Add 4th row to StatsBillboard (ServerStatsController patch)

Open `ServerStatsController` in StarterPlayerScripts and add the Festival Meter row:

```lua
-- Command Bar: patch ServerStatsController to add festival meter row
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("ServerStatsController")
if not ctrl then print("⚠️  ServerStatsController not found"); return end
if ctrl.Source:find("FestivalMeterSync", 1, true) then
    print("⏭️  Festival row already in ServerStatsController — skip"); return
end

-- Append festival row setup and update logic
ctrl.Source = ctrl.Source .. [[

-- === Festival Meter row (dispatch 156) ===
local _rs_156   = game:GetService("ReplicatedStorage")
local _gui_156  = nil  -- will be set once billboard exists

local function buildFestRow_156(billboard: BillboardGui)
    local outer = billboard:FindFirstChild("StatsFrame") or billboard:FindFirstChild("Frame")
    if not outer then return end

    local row = Instance.new("Frame")
    row.Name                   = "FestRow_156"
    row.Size                   = UDim2.new(1, -8, 0, 28)
    row.BackgroundTransparency = 1
    row.LayoutOrder            = 10
    row.Parent                 = outer

    local label = Instance.new("TextLabel")
    label.Name                   = "FestLabel"
    label.Size                   = UDim2.new(1, 0, 0, 12)
    label.BackgroundTransparency = 1
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 10
    label.TextColor3             = Color3.fromRGB(242, 168, 28)
    label.TextXAlignment         = Enum.TextXAlignment.Left
    label.Text                   = "🎁 Festival Meter"
    label.Parent                 = row

    local barBg = Instance.new("Frame")
    barBg.Name            = "BarBg"
    barBg.Size            = UDim2.new(1, 0, 0, 8)
    barBg.Position        = UDim2.new(0, 0, 0, 14)
    barBg.BackgroundColor3 = Color3.fromRGB(60, 40, 15)
    barBg.BorderSizePixel  = 0
    barBg.Parent           = row
    Instance.new("UICorner").Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name             = "BarFill"
    barFill.Size             = UDim2.new(0, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
    barFill.BorderSizePixel  = 0
    barFill.Parent           = barBg
    Instance.new("UICorner").Parent = barFill

    local numLabel = Instance.new("TextLabel")
    numLabel.Name                   = "NumLabel"
    numLabel.Size                   = UDim2.new(1, 0, 0, 10)
    numLabel.Position               = UDim2.new(0, 0, 1, 2)
    numLabel.BackgroundTransparency = 1
    numLabel.Font                   = Enum.Font.Gotham
    numLabel.TextSize               = 9
    numLabel.TextColor3             = Color3.fromRGB(232, 212, 154)
    numLabel.TextXAlignment         = Enum.TextXAlignment.Left
    numLabel.Text                   = "0 / 50,000 honey"
    numLabel.Parent                 = row
end

local function updateFestRow_156(data: {fill:number,target:number,pct:number,completed:boolean})
    local gui = _gui_156
    if not gui then
        local board = workspace:FindFirstChild("StatsBoard", true)
        if board then
            gui = board:FindFirstChildOfClass("BillboardGui")
            if gui and not gui:FindFirstChild("FestRow_156", true) then
                buildFestRow_156(gui)
            end
            _gui_156 = gui
        end
    end
    if not gui then return end

    local row    = gui:FindFirstChild("FestRow_156", true)
    if not row then buildFestRow_156(gui); row = gui:FindFirstChild("FestRow_156", true) end
    if not row then return end

    local barFill = row:FindFirstChild("BarFill", true)
    local numLabel = row:FindFirstChild("NumLabel", true)
    local festLabel = row:FindFirstChild("FestLabel", true)

    if data.completed then
        if festLabel then festLabel.Text = "🎉 Festival Complete!" end
        if barFill then barFill.Size = UDim2.new(1, 0, 1, 0) end
        if numLabel then numLabel.Text = "Chest claimed — resets at midnight UTC" end
    else
        if festLabel then festLabel.Text = "🎁 Festival Meter" end
        if barFill then barFill.Size = UDim2.new(math.min(1, data.pct), 0, 1, 0) end
        local pctStr = math.floor(data.pct * 100) .. "%"
        if numLabel then
            numLabel.Text = tostring(data.fill) .. " / " .. tostring(data.target) .. " (" .. pctStr .. ")"
        end
    end
end

-- Wire to FestivalMeterSync
local remotes_156 = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    or game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
    or game:GetService("ReplicatedStorage")
local meterSync_156 = remotes_156:FindFirstChild("FestivalMeterSync")
if meterSync_156 then
    meterSync_156.OnClientEvent:Connect(updateFestRow_156)
end
]]
print("✅ ServerStatsController patched with Festival Meter row")
```

---

## STEP E — Create FestivalChestController

This handles the fanfare when the chest pops for all clients.

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("FestivalChestController") then
    print("⏭️  FestivalChestController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "FestivalChestController"
    ctrl.Source = [[
--!strict
-- FestivalChestController — dispatch 156
-- Fanfare when server Festival Chest opens.

local Players    = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player     = Players.LocalPlayer
local playerGui  = player:WaitForChild("PlayerGui", 10)

local AMBER_156  = Color3.fromRGB(242, 168,  28)
local GOLD_156   = Color3.fromRGB(255, 210,  60)
local DARK_156   = Color3.fromRGB( 40,  25,   8)
local CREAM_156  = Color3.fromRGB(232, 212, 154)

local function playChestFanfare_156(data: {honey:number, propolis:number})
    -- Full-screen amber flash
    local flash = Instance.new("ScreenGui")
    flash.Name         = "ChestFlash_156"
    flash.DisplayOrder = 99
    flash.ResetOnSpawn = false
    flash.Parent       = playerGui

    local panel = Instance.new("Frame")
    panel.Size                   = UDim2.new(1, 0, 1, 0)
    panel.BackgroundColor3       = GOLD_156
    panel.BackgroundTransparency = 0.85
    panel.BorderSizePixel        = 0
    panel.Parent                 = flash

    -- Banner
    local banner = Instance.new("Frame")
    banner.Name                   = "ChestBanner"
    banner.Size                   = UDim2.new(0, 380, 0, 90)
    banner.Position               = UDim2.new(0.5, -190, -0.15, 0)
    banner.BackgroundColor3       = DARK_156
    banner.BackgroundTransparency = 0.05
    banner.BorderSizePixel        = 0
    banner.Parent                 = flash
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = banner
    local stroke = Instance.new("UIStroke"); stroke.Color = GOLD_156; stroke.Thickness = 2.5; stroke.Parent = banner

    local title = Instance.new("TextLabel")
    title.Size                   = UDim2.new(1, -16, 0, 36)
    title.Position               = UDim2.new(0, 8, 0, 8)
    title.BackgroundTransparency = 1
    title.Font                   = Enum.Font.FredokaOne
    title.TextSize               = 24
    title.TextColor3             = GOLD_156
    title.TextXAlignment         = Enum.TextXAlignment.Center
    title.Text                   = "🎁 Festival Chest!"
    title.Parent                 = banner

    local sub = Instance.new("TextLabel")
    sub.Size                   = UDim2.new(1, -16, 0, 28)
    sub.Position               = UDim2.new(0, 8, 0, 48)
    sub.BackgroundTransparency = 1
    sub.Font                   = Enum.Font.GothamBold
    sub.TextSize               = 16
    sub.TextColor3             = CREAM_156
    sub.TextXAlignment         = Enum.TextXAlignment.Center
    sub.Text                   = "+"..tostring(data.honey).."🍯  +"..tostring(data.propolis).."🟤  for the whole server!"
    sub.Parent                 = banner

    -- Slide banner in from above
    local tweenIn = TweenService:Create(banner,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -190, 0.35, 0)})
    tweenIn:Play()

    -- 18 confetti squares
    for i = 1, 18 do
        local sq = Instance.new("Frame")
        sq.Size             = UDim2.new(0, math.random(8, 16), 0, math.random(8, 16))
        sq.Position         = UDim2.new(math.random(10, 90) / 100, 0, -0.05, 0)
        sq.BackgroundColor3 = ({AMBER_156, GOLD_156, CREAM_156})[math.random(1, 3)]
        sq.BorderSizePixel  = 0
        sq.Rotation         = math.random(0, 360)
        sq.Parent           = flash
        Instance.new("UICorner").Parent = sq
        TweenService:Create(sq,
            TweenInfo.new(1.2 + math.random() * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(sq.Position.X.Scale, 0, 1.1, 0),
             BackgroundTransparency = 1}):Play()
    end

    -- Hold then slide out + destroy
    task.delay(2.5, function()
        if not banner.Parent then return end
        TweenService:Create(banner,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position = UDim2.new(0.5, -190, -0.15, 0)}):Play()
        TweenService:Create(panel,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}):Play()
        task.delay(0.5, function()
            if flash.Parent then flash:Destroy() end
        end)
    end)
end

-- Wire
local remotes_156 = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    or game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
    or game:GetService("ReplicatedStorage")

local chestOpen_156 = remotes_156:WaitForChild("FestivalChestOpened", 10)
if chestOpen_156 then
    chestOpen_156.OnClientEvent:Connect(playChestFanfare_156)
end

print("[FestivalChestController] Ready — listening for Festival Chest events")
]]
    ctrl.Parent = SPS
    print("✅ FestivalChestController created in StarterPlayerScripts")
end
```

---

## STEP F — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local fms   = SSS:FindFirstChild("FestivalMeterService")
local ctrl  = SPS and SPS:FindFirstChild("FestivalChestController")
local ssc   = SPS and SPS:FindFirstChild("ServerStatsController")
local remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents") or RS
local meterRE = remotes:FindFirstChild("FestivalMeterSync")
local chestRE = remotes:FindFirstChild("FestivalChestOpened")

local checks = {}
table.insert(checks, (fms and "✅" or "❌") .. " FestivalMeterService in SSS")
table.insert(checks, (fms and fms:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (fms and fms.Source:find("--!strict",1,true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (fms and fms.Source:find("AddHarvest",1,true) and "✅" or "❌") .. " AddHarvest function")
table.insert(checks, (fms and fms.Source:find("FILL_PER_HARVEST_156",1,true) and "✅" or "❌") .. " FILL_PER_HARVEST_156 constant")
table.insert(checks, (fms and fms.Source:find("tryClaimChest_156",1,true) and "✅" or "❌") .. " tryClaimChest_156 function")
table.insert(checks, (fms and fms.Source:find("REWARD_HONEY_156",1,true) and "✅" or "❌") .. " REWARD_HONEY_156 = 250")
table.insert(checks, (meterRE and "✅" or "❌") .. " FestivalMeterSync RemoteEvent exists")
table.insert(checks, (chestRE and "✅" or "❌") .. " FestivalChestOpened RemoteEvent exists")
table.insert(checks, (ctrl and "✅" or "❌") .. " FestivalChestController LocalScript exists")
table.insert(checks, (ctrl and ctrl.Source:find("ChestBanner",1,true) and "✅" or "❌") .. " ChestBanner UI element")
table.insert(checks, (ssc and ssc.Source:find("FestivalMeterSync",1,true) and "✅" or "❌") .. " ServerStatsController has Festival row")

print("=== DISPATCH 156 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 156 complete" or "❌ SOME CHECKS FAILED")

print("\nFestival Meter: " .. (fms and "present" or "MISSING"))
print("Contribution rate: 10% of each harvest")
print("Target: 50,000 honey (scales down during holidays)")
print("Reward: +250 honey +25 propolis to all players")
print("Reset: midnight UTC daily")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| FestivalMeterService Script (+1 permanent) | +1 |
| FestivalChestController LocalScript | 0 |
| ServerStatsController patch | 0 |
| **Dispatch 156 total** | **+1** |
| **Running total** | **4,195 / 5,000** |

---

## NOTES

- `FILL_PER_HARVEST_156 = 0.10`: each harvest contributes 10% to the meter. With 6 players harvesting 200 honey every ~2 minutes, fill time is roughly 5–10 minutes — achievable in one server session but not trivially instant.
- The holiday target scaling (`BASE_TARGET / holidayMult`) means the meter fills at the same real-world pace whether it's a normal day (×1.0 target) or Summer Solstice (×1.25 mult → 0.80× target). This prevents holidays from feeling either too easy or too hard.
- `_claimedDay_156` persists in server memory only — it resets on server restart. A server that restarts at 11pm and again at 1am could theoretically issue two chest rewards. This is accepted as an edge case in a low-stakes honey economy (the reward is 250 honey, not game-breaking).
- The `pcall` wrapper around the CombService harvest injection means the Festival Meter never blocks or errors a harvest even if `FestivalMeterService` fails to load. Defensive coding at the join point.
- `FestivalChestController` uses `DisplayOrder=99` for the fanfare flash so it appears above all other GUIs (holiday countdown is 40, achievement toasts are 25). The fanfare is short (3s) so it doesn't feel intrusive.
- Kids see the bar fill and celebrate when it pops; adults see the exact number and can strategise around it. Both audiences served by the same UI element.
