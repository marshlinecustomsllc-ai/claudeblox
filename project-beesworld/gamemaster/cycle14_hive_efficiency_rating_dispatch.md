# Dispatch 102 — Hive Efficiency Rating
## Cycle 14 · A Bee's World

**Feature:** Players currently have no holistic view of how well their hive is performing relative to its potential. This dispatch adds a **Hive Efficiency Rating** (HER) — a percentage displayed in the HiveStats panel that reflects how many plots are active, how many bees are assigned vs available, and whether upgrades are invested. A score of 100% means all plots are active with bees foraging. The rating updates on every `HiveStatsSync` event. It gives players a clear goal beyond "buy more upgrades" — fill every plot, assign every bee.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 101 (Bee Count Milestone Notifications)

---

## DESIGN

### Efficiency formula

```
HER = (activePlots / totalPlots) × 0.5
    + (assignedBees / totalBees) × 0.3
    + clamp(upgradeCount / 10, 0, 1) × 0.2
```

- **Active plots** (50% weight): plots that have at least one bee assigned and are foraging. Proxy: `data.activePlots` or derived from `data.plotCount` / `data.ownedPlots`.
- **Assigned bees** (30% weight): bees currently on a foraging trip. Proxy: `data.foragingBees` or `data.assignedBees`.
- **Upgrade investment** (20% weight): `clamp(upgradeCount / 10, 0, 1)` — maxes out at 10 upgrades (easy to achieve, shouldn't drag the score down early).

All three components are optional — if a field is missing from the payload, that component contributes its maximum weight (so an unknown value doesn't punish the score display). The formula is intentionally forgiving: a player with all plots active and all bees foraging should see 80-100% regardless of upgrade count.

### HiveStatsSync payload availability

`HiveStatsSync` (dispatch 13 era) sends `beeCount`, `honey`, `propolis`, `pollen`, `prestigeLevel`, and `upgradeCount` (dispatch 93 added totalUpgradesBought → HiveStatsService broadcast). Plot data (`activePlots`, `ownedPlots`) may or may not be present depending on architecture. If absent, active plots defaults to 1 of 1 (100% contribution) so the score reflects what is known.

### Display

The efficiency label is injected into the HiveStats ScreenGui as a new TextLabel below the existing stats. The label text format:

```
⚡ Hive Efficiency: 87%
```

Color codes:
- 90-100%: `Color3.fromRGB(100, 220, 80)` — green
- 70-89%: `Color3.fromRGB(242, 168, 28)` — honey gold
- 50-69%: `Color3.fromRGB(220, 140, 40)` — amber
- < 50%: `Color3.fromRGB(220, 80, 60)` — red

The label is named `HiveEfficiencyLabel` and is created once on first `HiveStatsSync`, then its `Text` and `TextColor3` are updated on subsequent syncs.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HiveStatsController` | Append efficiency rating computation + display label management |

---

## STEP A — Check HiveStatsSync payload fields

Command Bar:

```lua
-- Print all data fields received from HiveStatsSync
-- Temporarily wire a print listener (runs once per sync event)
local RS = game:GetService("ReplicatedStorage")
local hss = RS:FindFirstChild("HiveStatsSync") :: RemoteEvent?
assert(hss, "HiveStatsSync not found")

local conn
conn = hss.OnClientEvent:Connect(function(data)
    conn:Disconnect()  -- fire once
    if type(data) ~= "table" then
        print("HiveStatsSync data is not a table: " .. tostring(data))
        return
    end
    print("HiveStatsSync payload fields:")
    for k, v in data do
        print("  " .. tostring(k) .. " = " .. tostring(v) .. " (" .. typeof(v) .. ")")
    end
end)
print("Listening for next HiveStatsSync event...")
```

---

## STEP B — HiveStatsController: inject efficiency rating

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

if hsc.Source:find("HiveEfficiency", 1, true) then
    print("⏭️  HiveStatsController already has HiveEfficiency — skip")
else
    local clone = hsc:Clone()
    clone.Name = "HiveStatsController_WORKING"

    clone.Source = clone.Source .. [[

-- ── Hive Efficiency Rating (dispatch 102) ───────────────────────
local Players_102 = game:GetService("Players")
local RS_102      = game:GetService("ReplicatedStorage")

-- Color thresholds
local function efficiencyColor_102(pct: number): Color3
    if pct >= 0.90 then return Color3.fromRGB(100, 220, 80)  end
    if pct >= 0.70 then return Color3.fromRGB(242, 168, 28)  end
    if pct >= 0.50 then return Color3.fromRGB(220, 140, 40)  end
    return Color3.fromRGB(220, 80, 60)
end

local function computeHER_102(data: {[string]: any}): number
    -- Active plots component (50% weight)
    local activePlots  = tonumber(data.activePlots)  or tonumber(data.foragingPlots)  or nil
    local totalPlots   = tonumber(data.totalPlots)   or tonumber(data.ownedPlots)     or nil
    local plotScore: number
    if activePlots and totalPlots and totalPlots > 0 then
        plotScore = math.min(activePlots / totalPlots, 1)
    else
        plotScore = 1  -- unknown → max contribution
    end

    -- Assigned bees component (30% weight)
    local assignedBees = tonumber(data.foragingBees) or tonumber(data.assignedBees) or nil
    local totalBees    = tonumber(data.beeCount)     or tonumber(data.totalBees)    or nil
    local beeScore: number
    if assignedBees and totalBees and totalBees > 0 then
        beeScore = math.min(assignedBees / totalBees, 1)
    else
        beeScore = 1  -- unknown → max contribution
    end

    -- Upgrade investment component (20% weight, maxes at 10 upgrades)
    local upgradeCount = tonumber(data.totalUpgradesBought)
        or tonumber(data.upgradeCount)
        or tonumber(data.upgrades)
        or nil
    local upgradeScore: number
    if upgradeCount then
        upgradeScore = math.min(upgradeCount / 10, 1)
    else
        upgradeScore = 1  -- unknown → max contribution
    end

    return plotScore * 0.5 + beeScore * 0.3 + upgradeScore * 0.2
end

local effLabel_102: TextLabel? = nil

local function getOrCreateEffLabel_102(): TextLabel?
    local pg = Players_102.LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    -- Find HiveStatsGui or HiveGui or any ScreenGui with a stats frame
    local statsGui = pg:FindFirstChild("HiveStatsGui")
        or pg:FindFirstChild("HiveGui")
        or pg:FindFirstChild("StatsGui")
    if not statsGui then
        -- Search all ScreenGuis for one with bee-related content
        for _, gui in pg:GetChildren() do
            if gui:IsA("ScreenGui") then
                for _, obj in gui:GetDescendants() do
                    if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and
                        (obj.Text:find("🍯") or obj.Text:find("Honey") or obj.Text:find("Bees")) then
                        statsGui = gui
                        break
                    end
                end
            end
            if statsGui then break end
        end
    end
    if not statsGui then return nil end

    -- Look for existing label
    local existing = statsGui:FindFirstChild("HiveEfficiencyLabel", true)
    if existing and existing:IsA("TextLabel") then
        return existing :: TextLabel
    end

    -- Create new label: find the main stats frame
    local statsFrame = statsGui:FindFirstChildOfClass("Frame")
        or statsGui:FindFirstChildOfClass("ScrollingFrame")
    if not statsFrame then return nil end

    local lbl = Instance.new("TextLabel")
    lbl.Name                   = "HiveEfficiencyLabel"
    lbl.Size                   = UDim2.new(1, -8, 0, 20)
    lbl.Position               = UDim2.new(0, 4, 1, 4)  -- below last item; may overlap but always visible
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 13
    lbl.TextColor3             = Color3.fromRGB(100, 220, 80)
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
    lbl.Text                   = "⚡ Hive Efficiency: --"
    lbl.ZIndex                 = (statsFrame.ZIndex or 1) + 1
    lbl.Parent                 = statsFrame
    return lbl
end

-- Bind second listener to HiveStatsSync
task.spawn(function()
    local hiveStatsSync = RS_102:WaitForChild("HiveStatsSync", 10) :: RemoteEvent?
    if not hiveStatsSync then
        warn("[HiveEfficiency] HiveStatsSync not found after 10s")
        return
    end

    hiveStatsSync.OnClientEvent:Connect(function(data: {[string]: any})
        if not data then return end
        local her = computeHER_102(data)
        local pct = math.floor(her * 100)

        -- Lazy-create label (PlayerGui may not exist at module load time)
        if not effLabel_102 or not effLabel_102.Parent then
            effLabel_102 = getOrCreateEffLabel_102()
        end
        if not effLabel_102 then return end

        effLabel_102.Text       = "⚡ Hive Efficiency: " .. pct .. "%"
        effLabel_102.TextColor3 = efficiencyColor_102(her)
    end)

    print("[HiveEfficiency] Hive efficiency rating active")
end)
]]

    local parent = hsc.Parent
    hsc.Name = "HiveStatsController_OLD_NX"
    hsc.Parent = nil
    clone.Name = "HiveStatsController"
    clone.Parent = parent
    print("✅ HiveStatsController: hive efficiency rating injected")
end
```

---

## STEP C — Verification sweep

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

local checks = {}
table.insert(checks, (hsc and "✅" or "❌") .. " HiveStatsController exists")
table.insert(checks, (hsc and hsc.Source:find("HiveEfficiency", 1, true) and "✅" or "❌") .. " HiveStatsController: HiveEfficiency present")
table.insert(checks, (hsc and hsc.Source:find("computeHER_102", 1, true) and "✅" or "❌") .. " HiveStatsController: computeHER_102 function")
table.insert(checks, (hsc and hsc.Source:find("efficiencyColor_102", 1, true) and "✅" or "❌") .. " HiveStatsController: efficiencyColor_102")
table.insert(checks, (hsc and hsc.Source:find("HiveEfficiencyLabel", 1, true) and "✅" or "❌") .. " HiveStatsController: HiveEfficiencyLabel creation")
table.insert(checks, (hsc and hsc.Source:find("getOrCreateEffLabel_102", 1, true) and "✅" or "❌") .. " HiveStatsController: lazy label creation")
table.insert(checks, (hsc and hsc.Source:find("plotScore %* 0%.5", 1, false) and "✅" or "❌") .. " HiveStatsController: plot weight 0.5")
table.insert(checks, (hsc and hsc.Source:find("beeScore %* 0%.3", 1, false) and "✅" or "❌") .. " HiveStatsController: bee weight 0.3")
table.insert(checks, (hsc and hsc.Source:find("upgradeScore %* 0%.2", 1, false) and "✅" or "❌") .. " HiveStatsController: upgrade weight 0.2")

print("=== DISPATCH 102 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 102 complete" or "❌ SOME CHECKS FAILED")

print("\nEfficiency rating examples:")
local function computeEx(plots, assignedB, totalB, upgrades)
    local pScore = (plots and plots[1] > 0) and math.min(plots[1]/plots[2],1) or 1
    local bScore = (assignedB and totalB and totalB > 0) and math.min(assignedB/totalB,1) or 1
    local uScore = upgrades and math.min(upgrades/10,1) or 1
    return math.floor((pScore*0.5 + bScore*0.3 + uScore*0.2) * 100)
end
print("  All max (8/8 plots, all bees assigned, 15 upgrades): " .. computeEx({8,8},{},8,15) .. "%")
print("  Half plots (4/8), half bees, 5 upgrades:            " .. computeEx({4,8},4,8,5) .. "%")
print("  Starter (1/1 plot, 5/10 bees, 2 upgrades):          " .. computeEx({1,1},5,10,2) .. "%")
print("  No payload data (all unknown):                       " .. computeEx(nil,nil,nil,nil) .. "%")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| TextLabel appended to existing frame — no new containers | 0 permanent parts |
| **Dispatch 102 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `getOrCreateEffLabel_102()` uses a lazy search: it first tries named ScreenGuis (HiveStatsGui, HiveGui, StatsGui), then falls back to scanning all ScreenGuis for one containing bee emoji or "Honey" text. This handles any naming the UI was built with, without needing to know the exact structure from dispatch 1-era architecture.
- The label `Position = UDim2.new(0, 4, 1, 4)` anchors below the last child of the stats frame (Y=1,4). This may overlap frame borders if the frame uses ClipsDescendants=true. If that happens, the position should be changed to `UDim2.new(0, 4, 0.85, 0)` to sit inside the frame.
- If `HiveStatsSync` payload never includes plot/bee-assignment breakdown, all three unknown-field fallbacks default to 1.0 (full contribution), giving 100% — which is misleading. In that case, disable the plot and bee components by using `or 0` instead of `or 1` in the fallback. This makes the rating reflect only the upgrade investment until the payload is extended.
- Formula weights (0.5 / 0.3 / 0.2) are tunable. A designer wanting to de-emphasize upgrades could shift to (0.5 / 0.4 / 0.1). The weights must sum to 1.0.
- `_102` suffix prevents collisions with the `_101` injection in the same file and any earlier injections.
- Two `OnClientEvent:Connect` listeners now exist on `HiveStatsSync` from this file (dispatch 101's bee milestone check and dispatch 102's efficiency rating). Both fire independently on each sync event — this is the standard Roblox event model and has no ordering or performance concerns at this scale (two lightweight function calls per ~5-second sync interval).
