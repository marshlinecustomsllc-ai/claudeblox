# Dispatch 112 — Seasonal Streak Achievement
## Cycle 14 · A Bee's World

**Feature:** Four achievements — one per in-game season (Spring, Summer, Autumn, Winter) — that reward players for purchasing any upgrade during that season. The in-game season rotates every 20 real-time minutes (a full day/night cycle in a Roblox session), simulated by `math.floor(os.time() / 1200) % 4` mapping to seasons 0–3. When a player buys an upgrade, the server records which season it was purchased in. The four achievements unlock when a player has purchased upgrades in all four seasons across their lifetime (tracked in DataStore profile). This creates a long-term engagement hook — players have reason to return across multiple sessions.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 111 (Full Hive Multiplier)

---

## DESIGN

### Season system

```lua
local SEASONS = {"Spring", "Summer", "Autumn", "Winter"}
local SEASON_DURATION = 1200  -- 20 real minutes per season

local function getCurrentSeason(): string
    return SEASONS[(math.floor(os.time() / SEASON_DURATION) % 4) + 1]
end
```

This is deterministic and clock-based — no server state needed. All players experience the same season simultaneously.

### Season tracking in profile

`profile.seasonUpgrades`: a table mapping season names to `true` if the player has purchased any upgrade during that season.

```lua
{
  Spring = true,
  Summer = true,
  Autumn = false,
  Winter = false,
}
```

This is persisted in DataStore via the existing profile save system.

### Server-side hook

In UpgradeService (the server script that processes upgrade purchases), after a successful purchase, record the season:

```lua
local season = getCurrentSeason_112()
profile.seasonUpgrades = profile.seasonUpgrades or {}
profile.seasonUpgrades[season] = true
```

If UpgradeService exposes `_G.UpgradeService.onUpgradePurchased`, hook it. Otherwise append to UpgradeService directly.

### Achievements (Config + AchievementService)

Four achievements in Config:
```lua
spring_buyer  = { id="spring_buyer",  name="Spring Blossom",   desc="Buy an upgrade in Spring",  icon="🌸", condition={type="season_upgrade", season="Spring"} }
summer_buyer  = { id="summer_buyer",  name="Summer Swarm",     desc="Buy an upgrade in Summer",  icon="☀️", condition={type="season_upgrade", season="Summer"} }
autumn_buyer  = { id="autumn_buyer",  name="Autumn Harvest",   desc="Buy an upgrade in Autumn",  icon="🍂", condition={type="season_upgrade", season="Autumn"} }
winter_buyer  = { id="winter_buyer",  name="Winter Reserve",   desc="Buy an upgrade in Winter",  icon="❄️", condition={type="season_upgrade", season="Winter"} }
all_seasons   = { id="all_seasons",   name="All-Season Keeper",desc="Buy upgrades in all 4 seasons",icon="🌍",condition={type="all_seasons"} }
```

`season_upgrade` condition: `met = profile.seasonUpgrades ~= nil and profile.seasonUpgrades[condition.season] == true`
`all_seasons` condition: `met = profile.seasonUpgrades ~= nil and profile.seasonUpgrades.Spring and profile.seasonUpgrades.Summer and profile.seasonUpgrades.Autumn and profile.seasonUpgrades.Winter`

### Client season display

A minimal season indicator — a 1-line TextLabel in the HiveStats panel showing `"🌸 Spring"` / `"☀️ Summer"` / `"🍂 Autumn"` / `"❄️ Winter"` — updated every 30 seconds via a client loop. Placed below the Full Hive badge (dispatch 111) or below the Hive Efficiency label if the badge doesn't exist. FontSize=11, dim colour, purely informational.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `UpgradeService` | Append season recording on purchase + `getCurrentSeason_112` function |
| `Config` | Append 5 season achievements |
| `AchievementService` | Append `season_upgrade` + `all_seasons` condition types |
| `HiveStatsController` | Append season indicator label updater |

---

## STEP A — Patch UpgradeService: record season on purchase

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local us  = SSS:FindFirstChild("UpgradeService") or SSS:FindFirstChild("UpgradesService")
assert(us, "UpgradeService / UpgradesService not found in ServerScriptService")

if us.Source:find("SeasonRecord_112", 1, true) then
    print("⏭️  UpgradeService already has SeasonRecord_112 — skip")
else
    local clone = us:Clone()
    clone.Name = "UpgradeService_WORKING"

    clone.Source = clone.Source .. [[

-- ── Seasonal Upgrade Tracking (dispatch 112) ────────────────────────
-- SeasonRecord_112
local SEASONS_112      = {"Spring", "Summer", "Autumn", "Winter"}
local SEASON_DURATION_112 : number = 1200  -- 20 real minutes

local function getCurrentSeason_112(): string
    return SEASONS_112[(math.floor(os.time() / SEASON_DURATION_112) % 4) + 1]
end

-- Hook: if UpgradeService exposes _G.UpgradeService.onPurchase, wrap it.
-- Otherwise, hook HiveStatsSync (same pattern as dispatch 110) as proxy.
task.spawn(function()
    task.wait(1)
    local svc112 = _G.UpgradeService or _G.UpgradesService
    if svc112 and type(svc112.onPurchase) == "function" then
        local orig112 = svc112.onPurchase
        svc112.onPurchase = function(player: Player, upgradeId: string, profile: {[string]: any})
            -- Record season before calling original
            local season112 = getCurrentSeason_112()
            profile.seasonUpgrades = profile.seasonUpgrades or {}
            profile.seasonUpgrades[season112] = true
            print("[SeasonRecord] " .. player.Name .. " bought upgrade in " .. season112)
            return orig112(player, upgradeId, profile)
        end :: any
        print("[SeasonRecord_112] Patched UpgradeService.onPurchase")
    else
        -- Fallback: listen for UpgradeSync RemoteEvent fires from server
        -- UpgradeSync fires server→client after purchase; we can intercept
        -- by wrapping RemoteEvent.FireClient on the server side.
        local RS2_112 = game:GetService("ReplicatedStorage")
        local upgradeSync112 = RS2_112:WaitForChild("UpgradeSync", 10) :: RemoteEvent?
        if upgradeSync112 then
            local origFire112 = upgradeSync112.FireClient
            upgradeSync112.FireClient = function(self, player: Player, data: {[string]: any})
                origFire112(self, player, data)
                -- After purchase fires, read the profile from DataService and record season
                -- (DataService access pattern from dispatch 10 era)
                local ds112 = _G.DataService or _G.ProfileService
                if ds112 and type(ds112.getProfile) == "function" then
                    local profile112 = ds112.getProfile(player)
                    if profile112 then
                        local season112 = getCurrentSeason_112()
                        profile112.seasonUpgrades = profile112.seasonUpgrades or {}
                        profile112.seasonUpgrades[season112] = true
                        print("[SeasonRecord] " .. player.Name .. " upgrade in " .. season112)
                    end
                end
            end :: any
            print("[SeasonRecord_112] Wired via UpgradeSync.FireClient fallback")
        else
            warn("[SeasonRecord_112] Could not hook upgrade purchase — season tracking inactive")
        end
    end
end)
]]

    local parent = us.Parent
    us.Name = "UpgradeService_OLD_NX"
    us.Parent = nil
    clone.Name = us.Name:gsub("_WORKING",""):gsub("_OLD_NX","")
    clone.Parent = parent
    print("✅ UpgradeService: SeasonRecord_112 injected")
end
```

---

## STEP B — Append season achievements to Config

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")
local cfg = RS:FindFirstChild("Config")
assert(cfg, "Config not found")

if cfg.Source:find("spring_buyer", 1, true) then
    print("⏭️  Config already has spring_buyer — skip")
else
    local clone = cfg:Clone()
    clone.Name = "Config_WORKING"

    local block = [[

    -- Seasonal achievements (dispatch 112)
    spring_buyer = { id="spring_buyer", name="Spring Blossom",    desc="Buy an upgrade in Spring",          icon="🌸", condition={type="season_upgrade", season="Spring"} },
    summer_buyer = { id="summer_buyer", name="Summer Swarm",      desc="Buy an upgrade in Summer",          icon="☀️", condition={type="season_upgrade", season="Summer"} },
    autumn_buyer = { id="autumn_buyer", name="Autumn Harvest",    desc="Buy an upgrade in Autumn",          icon="🍂", condition={type="season_upgrade", season="Autumn"} },
    winter_buyer = { id="winter_buyer", name="Winter Reserve",    desc="Buy an upgrade in Winter",          icon="❄️", condition={type="season_upgrade", season="Winter"} },
    all_seasons  = { id="all_seasons",  name="All-Season Keeper", desc="Buy upgrades in all four seasons",  icon="🌍", condition={type="all_seasons"} },]]

    local newSource, n = clone.Source:gsub(
        "(ACHIEVEMENTS%s*=%s*%{[^}]*)(%}%s*,?%s*\n)",
        function(body, closing) return body .. block .. "\n" .. closing end
    )
    if n > 0 then
        clone.Source = newSource
    else
        clone.Source = clone.Source .. "\n-- Season achievements (dispatch 112 fallback — add to Config.ACHIEVEMENTS manually):\n--" .. block:gsub("\n", "\n--")
        print("[Config] Could not inject — fallback comment appended. Add manually.")
    end

    local parent = cfg.Parent
    cfg.Name = "Config_OLD_NX"; cfg.Parent = nil
    clone.Name = "Config"; clone.Parent = parent
    print("✅ Config: season achievements appended")
end
```

---

## STEP C — Patch AchievementService: season condition types

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local as  = SSS:FindFirstChild("AchievementService")
assert(as, "AchievementService not found")

if as.Source:find("SeasonCond_112", 1, true) then
    print("⏭️  AchievementService already has SeasonCond_112 — skip")
else
    local clone = as:Clone()
    clone.Name = "AchievementService_WORKING"

    clone.Source = clone.Source .. [[

-- ── season_upgrade + all_seasons condition types (dispatch 112) ─────
-- SeasonCond_112
task.spawn(function()
    task.wait(1)
    local svc112 = _G.AchievementService
    if svc112 and type(svc112.checkCondition) == "function" then
        local orig112b = svc112.checkCondition
        svc112.checkCondition = function(profile: {[string]: any}, condition: {[string]: any}): boolean
            if condition.type == "season_upgrade" then
                local su = profile.seasonUpgrades
                return su ~= nil and su[condition.season :: string] == true
            elseif condition.type == "all_seasons" then
                local su = profile.seasonUpgrades
                return su ~= nil and su.Spring and su.Summer and su.Autumn and su.Winter
            end
            return orig112b(profile, condition)
        end
        print("[SeasonCond_112] Patched AchievementService.checkCondition")
    else
        warn("[SeasonCond_112] _G.AchievementService.checkCondition not found — add season_upgrade and all_seasons cases manually")
    end
end)
]]

    local parent = as.Parent
    as.Name = "AchievementService_OLD_NX"; as.Parent = nil
    clone.Name = "AchievementService"; clone.Parent = parent
    print("✅ AchievementService: SeasonCond_112 injected")
end
```

---

## STEP D — HiveStatsController: season indicator label

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local hsc = SPS and SPS:FindFirstChild("HiveStatsController")
if not hsc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "HiveStatsController" then
            hsc = obj; break
        end
    end
end
assert(hsc, "HiveStatsController not found")

if hsc.Source:find("SeasonLabel_112", 1, true) then
    print("⏭️  HiveStatsController already has SeasonLabel_112 — skip")
else
    local clone = hsc:Clone()
    clone.Name = "HiveStatsController_WORKING"

    clone.Source = clone.Source .. [[

-- ── Season Indicator Label (dispatch 112) ────────────────────────────
-- SeasonLabel_112
local Players_112    = game:GetService("Players")
local SEASONS_112c   = {"Spring", "Summer", "Autumn", "Winter"}
local SEASON_ICONS_112 = {Spring="🌸", Summer="☀️", Autumn="🍂", Winter="❄️"}
local SEASON_DUR_112 : number = 1200

local function getCurrentSeason_112c(): string
    return SEASONS_112c[(math.floor(os.time() / SEASON_DUR_112) % 4) + 1]
end

local function getOrCreateSeasonLabel_112(): TextLabel?
    local pg = Players_112.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, obj in pg:GetDescendants() do
        if obj:IsA("TextLabel") and (obj.Name == "HiveEfficiencyLabel" or obj.Name == "FullHiveBadge") then
            local existing = obj.Parent:FindFirstChild("SeasonLabel") :: TextLabel?
            if existing then return existing end
            local lbl = Instance.new("TextLabel")
            lbl.Name                   = "SeasonLabel"
            lbl.Size                   = UDim2.new(1, 0, 0, 14)
            lbl.Position               = UDim2.new(0, 0, 1, 2)
            lbl.BackgroundTransparency = 1
            lbl.Font                   = Enum.Font.Gotham
            lbl.TextSize               = 11
            lbl.TextColor3             = Color3.fromRGB(180, 165, 120)  -- dim wax cream
            lbl.TextTransparency       = 0.3
            lbl.TextXAlignment         = Enum.TextXAlignment.Left
            lbl.Text                   = ""
            lbl.ZIndex                 = (obj.ZIndex or 1) + 1
            lbl.Parent                 = obj.Parent
            return lbl
        end
    end
    return nil
end

task.spawn(function()
    while true do
        local season = getCurrentSeason_112c()
        local icon   = SEASON_ICONS_112[season] or ""
        local lbl    = getOrCreateSeasonLabel_112()
        if lbl then lbl.Text = icon .. " " .. season end
        task.wait(30)
    end
end)

print("[SeasonLabel_112] Season indicator active")
]]

    local parent = hsc.Parent
    hsc.Name = "HiveStatsController_OLD_NX"; hsc.Parent = nil
    clone.Name = "HiveStatsController"; clone.Parent = parent
    print("✅ HiveStatsController: SeasonLabel_112 injected")
end
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local us  = SSS:FindFirstChild("UpgradeService") or SSS:FindFirstChild("UpgradesService")
local cfg = RS:FindFirstChild("Config")
local as  = SSS:FindFirstChild("AchievementService")
local hsc = SPS and SPS:FindFirstChild("HiveStatsController")
if not hsc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "HiveStatsController" then hsc = obj; break end
    end
end

local checks = {}
table.insert(checks, (us and us.Source:find("SeasonRecord_112", 1, true) and "✅" or "❌") .. " UpgradeService: SeasonRecord_112 marker")
table.insert(checks, (us and us.Source:find("getCurrentSeason_112", 1, true) and "✅" or "❌") .. " UpgradeService: getCurrentSeason_112 function")
table.insert(checks, (us and us.Source:find("seasonUpgrades", 1, true) and "✅" or "❌") .. " UpgradeService: seasonUpgrades profile field")
table.insert(checks, (cfg and cfg.Source:find("spring_buyer", 1, true) and "✅" or "❌") .. " Config: spring_buyer achievement")
table.insert(checks, (cfg and cfg.Source:find("all_seasons", 1, true) and "✅" or "❌") .. " Config: all_seasons achievement")
table.insert(checks, (as and as.Source:find("SeasonCond_112", 1, true) and "✅" or "❌") .. " AchievementService: SeasonCond_112 marker")
table.insert(checks, (as and as.Source:find("season_upgrade", 1, true) and "✅" or "❌") .. " AchievementService: season_upgrade condition")
table.insert(checks, (as and as.Source:find("all_seasons", 1, true) and "✅" or "❌") .. " AchievementService: all_seasons condition")
table.insert(checks, (hsc and hsc.Source:find("SeasonLabel_112", 1, true) and "✅" or "❌") .. " HiveStatsController: SeasonLabel_112 marker")
table.insert(checks, (hsc and hsc.Source:find("SEASON_ICONS_112", 1, true) and "✅" or "❌") .. " HiveStatsController: SEASON_ICONS_112 table")

print("=== DISPATCH 112 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 112 complete" or "❌ SOME CHECKS FAILED")

-- Print current season
local SEASONS_TEST = {"Spring", "Summer", "Autumn", "Winter"}
local season = SEASONS_TEST[(math.floor(os.time() / 1200) % 4) + 1]
print("\nCurrent in-game season: " .. season)
print("Season changes every 20 real minutes")
print("All 4 seasons cycle over 80 minutes of play")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Code-only changes — no BaseParts | 0 permanent parts |
| **Dispatch 112 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `math.floor(os.time() / 1200) % 4` is a global clock based on Unix timestamp. All players on all servers see the same season at the same real-world time, making the season system feel like a shared world event — "it's currently Winter everywhere". This also means the `seasonUpgrades` record is meaningful across sessions: if a player logs in during Summer and buys an upgrade, their profile permanently records Summer, even if they don't play again for a week.
- 20 real minutes per season (80-minute full cycle) is calibrated so an active session of ~30–40 minutes crosses at least 1–2 season transitions, giving engaged players progress toward `all_seasons` within a single session.
- The `all_seasons` achievement requires purchases in all 4 seasons across the player's entire lifetime — this is the long-term engagement hook. Short-session players will collect seasons gradually.
- `seasonUpgrades` in the profile is a small table (4 boolean fields max) — negligible DataStore overhead.
- The season indicator label's 30-second update interval means it can lag up to 30 seconds behind the actual season change. This is acceptable for a cosmetic display.
- The `SeasonLabel` label anchors below `HiveEfficiencyLabel` (dispatch 102) or `FullHiveBadge` (dispatch 111). If neither exists, `getOrCreateSeasonLabel_112` returns nil and the label simply isn't shown — no crash, no visual glitch.
- If UpgradeService uses a different `_G` name than `UpgradeService` or `UpgradesService`, the `UpgradeSync.FireClient` fallback hooks into the RemoteEvent instead. Both paths record `seasonUpgrades` on the profile.
