# Dispatch 97 — Seasonal Bonus Event System
## Cycle 14 · A Bee's World

**Feature:** The seasonal event framework was stubbed in dispatch 68 (`HiveStatsService.CheckSeasonal`) and referenced in the tutorial expansion (dispatch 83). This dispatch fully implements seasonal bonus windows: time-limited events where all yield multipliers receive a flat boost. Two seasons are defined (Summer Bloom and Autumn Harvest). The active season is determined server-side from UTC month and broadcast to all clients via `SeasonalSync`. A `SeasonalHUD` indicator shows the active bonus in the corner.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** Opens Cycle 14 (after dispatch 96)

---

## DESIGN

### Seasonal windows

| Season | Active months (UTC) | Honey boost | Propolis boost | Pollen boost |
|--------|---------------------|-------------|----------------|--------------|
| 🌸 Spring Bloom | March (3), April (4) | +15% | +10% | +20% |
| ☀️ Summer Buzz | June (6), July (7) | +25% | +5% | +10% |
| 🍂 Autumn Harvest | September (9), October (10) | +10% | +20% | +15% |
| ❄️ Winter Rest | December (12), January (1) | +5% | +30% | +0% |
| (off-season) | all other months | +0% | +0% | +0% |

### SeasonalService (new ServerScript)

```lua
-- Checks os.date UTC month → returns current season config
-- Fires SeasonalSync:FireAllClients({season=name, bonuses={honey=0.15,...}}) every 300s
-- and on each new player joining
```

### ForagingService patch

Apply seasonal bonuses after all other multipliers:
```lua
local seasonal = SeasonalService.GetActiveBonuses()
honeyYield    = math.floor(honeyYield    * (1 + seasonal.honey))
propolisYield = math.floor(propolisYield * (1 + seasonal.propolis))
pollenYield   = math.floor(pollenYield   * (1 + seasonal.pollen))
```

### SeasonalHUD (client)

A small frame in the top-right of the screen (below the resource HUD) showing:
```
☀️ Summer Buzz active
🍯 +25%  🔮 +5%  🌼 +10%
```
Hidden when no season is active. Fades in/out on season change.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `SeasonalService` | New Script in ServerScriptService — season detection, bonus table, FireAllClients |
| `ForagingService` | Apply seasonal bonus multipliers to all three yields |
| `SeasonalController` | New LocalScript in StarterPlayerScripts — SeasonalHUD display |
| `ReplicatedStorage` | Add `SeasonalSync` RemoteEvent |

---

## STEP A — Create SeasonalSync RemoteEvent

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
if RS:FindFirstChild("SeasonalSync") then
    print("⏭️  SeasonalSync already exists — skip")
else
    local re = Instance.new("RemoteEvent")
    re.Name   = "SeasonalSync"
    re.Parent = RS
    print("✅ SeasonalSync RemoteEvent created")
end
```

---

## STEP B — Create SeasonalService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("SeasonalService") then
    print("⏭️  SeasonalService already exists — skip")
else
    local s = Instance.new("Script")
    s.Name   = "SeasonalService"
    s.Source = [[
--!strict
-- SeasonalService — dispatch 97
-- Broadcasts active seasonal bonus window to all clients

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local SeasonalSync = RS:WaitForChild("SeasonalSync") :: RemoteEvent

type Bonuses = {honey: number, propolis: number, pollen: number}
type Season  = {name: string, emoji: string, bonuses: Bonuses}

local SEASONS: {[number]: Season} = {
    [3]  = {name = "Spring Bloom",   emoji = "🌸", bonuses = {honey = 0.15, propolis = 0.10, pollen = 0.20}},
    [4]  = {name = "Spring Bloom",   emoji = "🌸", bonuses = {honey = 0.15, propolis = 0.10, pollen = 0.20}},
    [6]  = {name = "Summer Buzz",    emoji = "☀️", bonuses = {honey = 0.25, propolis = 0.05, pollen = 0.10}},
    [7]  = {name = "Summer Buzz",    emoji = "☀️", bonuses = {honey = 0.25, propolis = 0.05, pollen = 0.10}},
    [9]  = {name = "Autumn Harvest", emoji = "🍂", bonuses = {honey = 0.10, propolis = 0.20, pollen = 0.15}},
    [10] = {name = "Autumn Harvest", emoji = "🍂", bonuses = {honey = 0.10, propolis = 0.20, pollen = 0.15}},
    [12] = {name = "Winter Rest",    emoji = "❄️", bonuses = {honey = 0.05, propolis = 0.30, pollen = 0.00}},
    [1]  = {name = "Winter Rest",    emoji = "❄️", bonuses = {honey = 0.05, propolis = 0.30, pollen = 0.00}},
}

local NO_SEASON: Season = {name = "", emoji = "", bonuses = {honey = 0, propolis = 0, pollen = 0}}

local SeasonalService = {}
SeasonalService.__index = SeasonalService

function SeasonalService.GetActiveSeason(): Season
    local month = tonumber(os.date("!%m")) or 0
    return SEASONS[month] or NO_SEASON
end

function SeasonalService.GetActiveBonuses(): Bonuses
    return SeasonalService.GetActiveSeason().bonuses
end

local function broadcast()
    local season = SeasonalService.GetActiveSeason()
    SeasonalSync:FireAllClients({
        name    = season.name,
        emoji   = season.emoji,
        bonuses = season.bonuses,
    })
end

-- Fire to each new player on join
Players.PlayerAdded:Connect(function(player)
    task.wait(3)  -- wait for client to load
    local season = SeasonalService.GetActiveSeason()
    SeasonalSync:FireClient(player, {
        name    = season.name,
        emoji   = season.emoji,
        bonuses = season.bonuses,
    })
end)

-- Rebroadcast every 5 minutes (season changes are rare but clocks drift)
task.spawn(function()
    while true do
        task.wait(300)
        broadcast()
    end
end)

broadcast()
print("[SeasonalService] Ready — season: " .. SeasonalService.GetActiveSeason().name)

return SeasonalService
]]
    s.Parent = SSS
    print("✅ SeasonalService created")
end
```

---

## STEP C — ForagingService: apply seasonal bonuses

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

if fs.Source:find("SeasonalService", 1, true) then
    print("⏭️  ForagingService already applies SeasonalService — skip")
else
    local clone = fs:Clone()
    clone.Name = "ForagingService_WORKING"

    -- Inject SeasonalService require near the top, after other requires
    if not clone.Source:find("SeasonalService", 1, true) then
        local lastRequire = 1
        local searchFrom = 1
        while true do
            local next = clone.Source:find("require(", searchFrom, true)
            if not next then break end
            lastRequire = next
            searchFrom = next + 1
        end
        local reqLineEnd = clone.Source:find("\n", lastRequire, true) or #clone.Source
        clone.Source = clone.Source:sub(1, reqLineEnd)
            .. "\nlocal SeasonalService = require(game:GetService('ServerScriptService'):WaitForChild('SeasonalService'))\n"
            .. clone.Source:sub(reqLineEnd + 1)
        print("SeasonalService require injected")
    end

    -- Find where yields are finalised (after all other multipliers applied)
    -- Best anchor: the DataService.SaveProfile call or the last math.floor on a yield
    local anchor = 'DataService%.SaveProfile'
    local found = clone.Source:find(anchor, 1, true)
    if not found then
        -- Try to find last math.floor that modifies a yield variable
        anchor = 'math%.floor.*Yield'
        found = clone.Source:find(anchor)
    end
    if not found then
        -- Fallback: before the RemoteEvent fire for foraging results
        anchor = 'ForagingSync:FireClient'
        found = clone.Source:find(anchor, 1, true)
    end
    assert(found, "Could not find injection point in ForagingService")

    local lineStart = found
    while lineStart > 1 and clone.Source:sub(lineStart-1,lineStart-1) ~= "\n" do lineStart = lineStart - 1 end
    local indent = clone.Source:sub(lineStart, found):match("^(%s*)") or "\t"

    local seasonalBlock = indent .. "-- Seasonal bonus (dispatch 97)\n"
        .. indent .. "do\n"
        .. indent .. "\tlocal _seasonal = SeasonalService.GetActiveBonuses()\n"
        .. indent .. "\thoneyYield    = math.floor((honeyYield    or 0) * (1 + (_seasonal.honey    or 0)))\n"
        .. indent .. "\tpropolisYield = math.floor((propolisYield or 0) * (1 + (_seasonal.propolis or 0)))\n"
        .. indent .. "\tpollenYield   = math.floor((pollenYield   or 0) * (1 + (_seasonal.pollen   or 0)))\n"
        .. indent .. "end\n"

    clone.Source = clone.Source:sub(1, lineStart - 1) .. seasonalBlock .. clone.Source:sub(lineStart)

    fs.Name = "ForagingService_OLD_NX"
    fs.Parent = nil
    clone.Name = "ForagingService"
    clone.Parent = SSS
    print("✅ ForagingService: seasonal bonus multipliers injected")
end
```

---

## STEP D — Create SeasonalController (client HUD)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("SeasonalController") then
    print("⏭️  SeasonalController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "SeasonalController"
    ctrl.Source = [[
--!strict
-- SeasonalController — dispatch 97
-- Displays seasonal bonus HUD indicator in top-right

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SeasonalSync = RS:WaitForChild("SeasonalSync", 15) :: RemoteEvent?

if not SeasonalSync then
    warn("[SeasonalController] SeasonalSync not found")
    return
end

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Build SeasonalHUD ─────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name            = "SeasonalHUD"
gui.ResetOnSpawn    = false
gui.DisplayOrder    = 12
gui.Parent          = playerGui

local panel = Instance.new("Frame")
panel.Name              = "SeasonalPanel"
panel.Size              = UDim2.new(0, 190, 0, 60)
panel.Position          = UDim2.new(1, -200, 0, 80)  -- top-right below resource HUD
panel.BackgroundColor3  = Color3.fromRGB(30, 20, 10)
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel   = 0
panel.Visible           = false
panel.Parent            = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color     = Color3.fromRGB(242, 168, 28)
stroke.Thickness = 1.5
stroke.Parent    = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name                 = "TitleLabel"
titleLabel.Size                 = UDim2.new(1, -8, 0, 22)
titleLabel.Position             = UDim2.new(0, 4, 0, 2)
titleLabel.BackgroundTransparency = 1
titleLabel.Font                 = Enum.Font.GothamBold
titleLabel.TextSize             = 13
titleLabel.TextColor3           = Color3.fromRGB(242, 168, 28)
titleLabel.TextXAlignment       = Enum.TextXAlignment.Center
titleLabel.Parent               = panel

local bonusLabel = Instance.new("TextLabel")
bonusLabel.Name                 = "BonusLabel"
bonusLabel.Size                 = UDim2.new(1, -8, 0, 20)
bonusLabel.Position             = UDim2.new(0, 4, 0, 26)
bonusLabel.BackgroundTransparency = 1
bonusLabel.Font                 = Enum.Font.Gotham
bonusLabel.TextSize             = 11
bonusLabel.TextColor3           = Color3.fromRGB(232, 212, 154)
bonusLabel.TextXAlignment       = Enum.TextXAlignment.Center
bonusLabel.Parent               = panel

-- ── Update HUD ──────────────────────────────────────────────
local function updateHUD(data: {name: string, emoji: string, bonuses: {honey: number, propolis: number, pollen: number}})
    if not data.name or data.name == "" then
        -- No active season — hide panel
        TweenService:Create(panel, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        task.delay(0.4, function() panel.Visible = false end)
        return
    end

    titleLabel.Text = data.emoji .. " " .. data.name
    local bonusParts = {}
    if (data.bonuses.honey or 0) > 0 then
        table.insert(bonusParts, "🍯 +" .. math.floor((data.bonuses.honey or 0) * 100) .. "%")
    end
    if (data.bonuses.propolis or 0) > 0 then
        table.insert(bonusParts, "🔮 +" .. math.floor((data.bonuses.propolis or 0) * 100) .. "%")
    end
    if (data.bonuses.pollen or 0) > 0 then
        table.insert(bonusParts, "🌼 +" .. math.floor((data.bonuses.pollen or 0) * 100) .. "%")
    end
    bonusLabel.Text = table.concat(bonusParts, "  ")

    panel.BackgroundTransparency = 1
    panel.Visible = true
    TweenService:Create(panel, TweenInfo.new(0.5), {BackgroundTransparency = 0.3}):Play()
end

SeasonalSync.OnClientEvent:Connect(updateHUD)
print("[SeasonalController] Seasonal HUD ready")
]]
    ctrl.Parent = SPS
    print("✅ SeasonalController created in StarterPlayerScripts")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local checks = {}

local ss = SSS:FindFirstChild("SeasonalService")
table.insert(checks, (ss and "✅" or "❌") .. " SeasonalService exists in ServerScriptService")
table.insert(checks, (ss and ss.Source:find("GetActiveBonuses", 1, true) and "✅" or "❌") .. " SeasonalService: GetActiveBonuses function")
table.insert(checks, (ss and ss.Source:find("SEASONS", 1, true) and "✅" or "❌") .. " SeasonalService: SEASONS table")
table.insert(checks, (ss and ss.Source:find("FireAllClients", 1, true) and "✅" or "❌") .. " SeasonalService: broadcasts via FireAllClients")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("SeasonalService", 1, true) and "✅" or "❌") .. " ForagingService: applies SeasonalService.GetActiveBonuses")
table.insert(checks, (fs and fs.Source:find("_seasonal", 1, true) and "✅" or "❌") .. " ForagingService: _seasonal variable")

local sc = SPS and SPS:FindFirstChild("SeasonalController")
table.insert(checks, (sc and "✅" or "❌") .. " SeasonalController exists in StarterPlayerScripts")
table.insert(checks, (sc and sc.Source:find("SeasonalHUD", 1, true) and "✅" or "❌") .. " SeasonalController: SeasonalHUD ScreenGui")

local sync = RS:FindFirstChild("SeasonalSync")
table.insert(checks, (sync and "✅" or "❌") .. " SeasonalSync RemoteEvent in ReplicatedStorage")

print("=== DISPATCH 97 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 97 complete" or "❌ SOME CHECKS FAILED")

-- Show current season
local month = tonumber(os.date("!%m")) or 0
local seasonNames = {
    [3]="Spring Bloom",[4]="Spring Bloom",
    [6]="Summer Buzz",[7]="Summer Buzz",
    [9]="Autumn Harvest",[10]="Autumn Harvest",
    [12]="Winter Rest",[1]="Winter Rest"
}
print("\nCurrent UTC month: " .. month)
print("Active season: " .. (seasonNames[month] or "(off-season, no bonus)"))
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Scripts and RemoteEvent only (no BaseParts) | 0 new parts |
| **Dispatch 97 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The seasonal windows cover 8 of 12 months, leaving 4 months (February, May, August, November) as off-season with no bonus. This gives players a clear on/off cycle and makes the active windows feel special rather than permanent.
- `os.date("!%m")` returns UTC month as a zero-padded string. `tonumber()` converts it to integer for table lookup. UTC is used (rather than server local time) for consistency across all players globally.
- The `do ... end` block wrapping the seasonal yield application in ForagingService creates a clean scope so `_seasonal` doesn't pollute the surrounding yield computation scope.
- The AntiCheat dynamic cap (dispatch 84) does NOT account for seasonal bonuses explicitly. At maximum seasonal bonus (+25% honey, Summer Buzz) with max bee count, max speed, and 8 plots: `960 honey/trip × 1.25 = 1,200 honey/trip`. The dynamic cap at prestige 10 is 2,887 — still comfortably above, so no anticheat update is needed.
- `SeasonalHUD` uses `DisplayOrder = 12` — above the resource HUD (assumed DisplayOrder ≤ 10) but below tutorial overlays and achievement popups (assumed 15+). Adjust if your HUD DisplayOrder differs.
- The 300-second rebroadcast loop in `SeasonalService` exists for robustness — clients that join mid-session get the current season on join via `PlayerAdded`, so the loop is mainly a safety net for clock drift or missed initial fire.
