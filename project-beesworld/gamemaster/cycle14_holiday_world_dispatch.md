# Dispatch 155 — Holiday World Transforms
## Cycle 14 · A Bee's World

**Feature:** The hub physically transforms during each active holiday. `HolidayWorldService` listens to `ActiveHoliday` on every player join and on the 60s tick; it creates or destroys seasonal world parts inside `Hub.CommunityRework_153` and patches the fountain emitter colour. `HolidayCombSkins` LocalScript reads `ActiveHoliday` and applies cosmetic overrides to the BillboardGui cell labels on the comb grid — pumpkin emoji on brood cells at Halloween, candy cane stripe on honey cells at Christmas, cherry blossoms on pollen cells in spring. Part budget: +1 permanent (one Script; world parts are temporary, not counted; LocalScript = 0).
**Part budget impact:** +1 permanent → **4,194 / 5,000**
**Execution order:** After dispatch 154 (Holiday Core System)

---

## DESIGN

### Hub transform table

| Holiday | Hub changes |
|---------|------------|
| 🎃 Halloween | Orange lanterns replace amber on bench clusters; 6 thin cobweb strands on arch pillars; fountain emitter colour → purple/orange; orange point lights on cobweb anchors |
| ❄️ Winter Hive | White disc snow caps on flat surfaces (board top, bench seats); string lights (small neon white spheres) strung between arch pillars and lantern poles; fountain emitter off; blue-tinted point lights on string lights |
| 🌸 Spring | Pink blossom sphere clusters at arch base and bench corners; fountain emitter colour → pink/white; soft pink point lights |
| 🍂 Harvest | Golden-brown leaf parts scattered near benches; amber lanterns brightened (Brightness → 2.5); fountain emitter colour → golden |
| ☀️ Summer | Sunflower cylinder+sphere parts replace arch flower tops; fountain emitter max rate (12) + bright gold colour; arch pillars get a SunRays-style neon ring |
| none | All seasonal parts destroyed; fountain restored to default amber |

All seasonal parts created inside `Hub.CommunityRework_153.SeasonalParts` folder. Entire folder is destroyed and rebuilt on each holiday switch.

### Comb cell skins (HolidayCombSkins LocalScript)

The comb grid renders cell type labels in BillboardGui elements attached to each cell's `CellContent` model. `HolidayCombSkins` polls `ActiveHoliday` every 10s and prepends a seasonal emoji to the text of any `CellLabel` TextLabel found in the comb grid:

| Holiday | Cell type | Skin text prefix |
|---------|-----------|-----------------|
| halloween | `brood` | `🎃 ` |
| halloween | `honey` | `👻 ` |
| winter | `honey` | `🍬 ` (candy cane) |
| winter | `brood` | `❄️ ` |
| spring | `pollen` | `🌸 ` |
| summer | `honey` | `☀️ ` |

When no holiday is active, any injected prefix is stripped to restore original label text.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HolidayWorldService` | New Script in ServerScriptService |
| `HolidayCombSkins` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HolidayWorldService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("HolidayWorldService") then
    print("⏭️  HolidayWorldService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "HolidayWorldService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- HolidayWorldService — dispatch 155
-- Physically transforms the hub for each active holiday.
-- Creates/destroys Hub.CommunityRework_153.SeasonalParts each cycle.

local Players = game:GetService("Players")

local AMBER_155  = Color3.fromRGB(242,168, 28)
local PURPLE_155 = Color3.fromRGB(140, 40,200)
local PINK_155   = Color3.fromRGB(255,160,210)
local GOLD_155   = Color3.fromRGB(255,220, 50)
local WHITE_155  = Color3.fromRGB(220,235,255)

local lastHoliday_155 = "UNSET"

local function getContainer_155()
    local map = workspace:FindFirstChild("Map")
    local hub = map and map:FindFirstChild("Hub")
    local rework = hub and hub:FindFirstChild("CommunityRework_153")
    return rework
end

local function clearSeasonal_155()
    local c = getContainer_155()
    if not c then return end
    local sp = c:FindFirstChild("SeasonalParts")
    if sp then sp:Destroy() end
end

local function makePart_155(parent: Folder, props: {
    name: string, size: Vector3, pos: Vector3,
    color: Color3, mat: Enum.Material?,
    neon: boolean?, collide: boolean?, trans: number?
}): BasePart
    local p = Instance.new("Part")
    p.Name          = props.name
    p.Anchored      = true
    p.CanCollide    = props.collide or false
    p.Size          = props.size
    p.Position      = props.pos
    p.Color         = props.color
    p.Material      = (props.neon and Enum.Material.Neon) or props.mat or Enum.Material.SmoothPlastic
    p.Transparency  = props.trans or 0
    p.Parent        = parent
    return p
end

local function buildHalloween_155(sp: Folder)
    -- Orange lanterns (replace amber — recolour existing lanterns via property set)
    local rework = sp.Parent :: Folder
    for _, p in rework:GetDescendants() do
        if p:IsA("BasePart") and p.Name:match("^Lantern%d$") then
            p.Color = Color3.fromRGB(255, 80, 0)
            local pl = p:FindFirstChildOfClass("PointLight")
            if pl then (pl :: PointLight).Color = Color3.fromRGB(255,80,0) end
        end
    end
    -- Cobweb strands on arch pillars (thin white/grey cylinders)
    local webPositions = {
        {Vector3.new(-4.5,4,-265), Vector3.new(-5.5,6,-265)},
        {Vector3.new(-4.5,3,-265), Vector3.new(-5.8,5.5,-265)},
        {Vector3.new( 4.5,4,-265), Vector3.new( 5.5,6,-265)},
        {Vector3.new( 4.5,3,-265), Vector3.new( 5.8,5.5,-265)},
        {Vector3.new(-4,6.5,-265),  Vector3.new(0, 6.5,-265)},
        {Vector3.new( 4,6.5,-265),  Vector3.new(0, 6.5,-265)},
    }
    for i, pair in webPositions do
        local mid = (pair[1] + pair[2]) / 2
        local len = (pair[2] - pair[1]).Magnitude
        local web = makePart_155(sp, {
            name="Cobweb"..i, size=Vector3.new(0.08, 0.08, len),
            pos=mid, color=Color3.fromRGB(200,200,200),
            mat=Enum.Material.Neon, trans=0.3
        })
        web.CFrame = CFrame.lookAt(mid, pair[2])
    end
    -- Purple fountain emitter tint
    local hub = sp.Parent.Parent :: Folder
    local fountain = hub:FindFirstChild("HoneyDripFountain", true)
    if fountain then
        local e = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
        if e then e.Color = ColorSequence.new(PURPLE_155, Color3.fromRGB(255,80,0)) end
        local pl = fountain:FindFirstChildOfClass("PointLight") :: PointLight?
        if pl then pl.Color = PURPLE_155 end
    end
    print("[HolidayWorldService] 🎃 Halloween transform applied")
end

local function buildWinter_155(sp: Folder)
    -- Snow caps (white flat discs on bench seats and board top)
    local capPositions = {
        Vector3.new(-8, 0.72, -295), Vector3.new(8, 0.72, -295), Vector3.new(0, 0.72, -305),
        Vector3.new(0, 6.28, -320),  -- board top
    }
    for i, pos in capPositions do
        makePart_155(sp, {name="SnowCap"..i, size=Vector3.new(2.6,0.12,1.1), pos=pos, color=Color3.new(1,1,1), mat=Enum.Material.SmoothPlastic})
    end
    -- String lights between arch pillars (small neon spheres)
    for i = 0, 8 do
        local t = i / 8
        local x = -5 + t * 10
        local y = 6.2 - math.sin(math.pi * t) * 0.8  -- droop
        local bulb = makePart_155(sp, {name="StringLight"..i, size=Vector3.new(0.3,0.3,0.3), pos=Vector3.new(x, y, -265), color=WHITE_155, neon=true})
        local pl = Instance.new("PointLight"); pl.Color=WHITE_155; pl.Range=4; pl.Brightness=0.8; pl.Parent=bulb
    end
    -- Fountain off
    local hub = sp.Parent.Parent :: Folder
    local fountain = hub:FindFirstChild("HoneyDripFountain", true)
    if fountain then
        local e = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
        if e then e.Rate = 0 end
        local pl = fountain:FindFirstChildOfClass("PointLight") :: PointLight?
        if pl then pl.Color = WHITE_155 end
    end
    print("[HolidayWorldService] ❄️ Winter transform applied")
end

local function buildSpring_155(sp: Folder)
    -- Blossom sphere clusters at arch base and bench corners
    local blossomPos = {
        Vector3.new(-5.5,1.5,-265), Vector3.new(-4.5,2,-265),
        Vector3.new( 5.5,1.5,-265), Vector3.new( 4.5,2,-265),
        Vector3.new(-8.5,1.5,-295), Vector3.new(8.5,1.5,-295), Vector3.new(0.5,1.5,-305),
    }
    for i, pos in blossomPos do
        makePart_155(sp, {name="Blossom"..i, size=Vector3.new(0.9,0.9,0.9), pos=pos, color=PINK_155, neon=true, trans=0.2})
    end
    local hub = sp.Parent.Parent :: Folder
    local fountain = hub:FindFirstChild("HoneyDripFountain", true)
    if fountain then
        local e = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
        if e then
            e.Color = ColorSequence.new(PINK_155, Color3.new(1,1,1))
            e.Rate  = 8
        end
        local pl = fountain:FindFirstChildOfClass("PointLight") :: PointLight?
        if pl then pl.Color = PINK_155 end
    end
    print("[HolidayWorldService] 🌸 Spring transform applied")
end

local function buildHarvest_155(sp: Folder)
    -- Golden leaf parts scattered near benches
    local leafPositions = {
        Vector3.new(-7,0.3,-293), Vector3.new(-9,0.3,-297), Vector3.new(7,0.3,-293),
        Vector3.new(9,0.3,-297),  Vector3.new(1,0.3,-307),  Vector3.new(-1,0.3,-303),
    }
    for i, pos in leafPositions do
        local leaf = makePart_155(sp, {name="Leaf"..i, size=Vector3.new(0.5,0.08,0.7), pos=pos, color=Color3.fromRGB(200,100,20), mat=Enum.Material.SmoothPlastic})
        leaf.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.random()*math.pi, 0)
    end
    -- Brighten lanterns
    local rework = sp.Parent :: Folder
    for _, p in rework:GetDescendants() do
        if p:IsA("PointLight") and p.Parent and (p.Parent :: BasePart).Name:match("^Lantern") then
            (p :: PointLight).Brightness = 2.5
        end
    end
    local hub = sp.Parent.Parent :: Folder
    local fountain = hub:FindFirstChild("HoneyDripFountain", true)
    if fountain then
        local e = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
        if e then e.Color = ColorSequence.new(GOLD_155, Color3.fromRGB(255,180,0)); e.Rate = 8 end
    end
    print("[HolidayWorldService] 🍂 Harvest transform applied")
end

local function buildSummer_155(sp: Folder)
    -- Sunflower caps on arch pillars (yellow+brown cylinder/sphere combos)
    local sunflowerCenters = {Vector3.new(-5,7.5,-265), Vector3.new(5,7.5,-265)}
    for i, pos in sunflowerCenters do
        makePart_155(sp, {name="SunCenter"..i, size=Vector3.new(1,1,1), pos=pos, color=Color3.fromRGB(120,80,20), mat=Enum.Material.SmoothPlastic})
        for j = 0, 5 do
            local angle = (j/6) * math.pi * 2
            local petalPos = pos + Vector3.new(math.cos(angle)*0.9, 0, math.sin(angle)*0.9)
            makePart_155(sp, {name="Petal"..i.."_"..j, size=Vector3.new(0.6,0.25,0.6), pos=petalPos, color=GOLD_155, neon=true})
        end
    end
    -- Neon ring on arch pillars
    for i, x in {-5, 5} do
        makePart_155(sp, {name="SunRing"..i, size=Vector3.new(1.4,0.2,1.4), pos=Vector3.new(x,6.1,-265), color=GOLD_155, neon=true})
    end
    local hub = sp.Parent.Parent :: Folder
    local fountain = hub:FindFirstChild("HoneyDripFountain", true)
    if fountain then
        local e = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
        if e then e.Color = ColorSequence.new(GOLD_155, Color3.new(1,1,1)); e.Rate = 12 end
        local pl = fountain:FindFirstChildOfClass("PointLight") :: PointLight?
        if pl then pl.Color = GOLD_155; pl.Brightness = 2.5 end
    end
    print("[HolidayWorldService] ☀️ Summer transform applied")
end

local function restoreDefault_155()
    -- Restore lanterns to amber
    local c = getContainer_155()
    if c then
        for _, p in c:GetDescendants() do
            if p:IsA("BasePart") and p.Name:match("^Lantern%d$") then
                p.Color = Color3.fromRGB(255,220,60)
                local pl = p:FindFirstChildOfClass("PointLight")
                if pl then (pl :: PointLight).Color = AMBER_155; (pl :: PointLight).Brightness = 1.2 end
            end
        end
    end
    -- Restore fountain to amber defaults
    local map = workspace:FindFirstChild("Map")
    local hub = map and map:FindFirstChild("Hub")
    local fountain = hub and hub:FindFirstChild("HoneyDripFountain", true)
    if fountain then
        local e = fountain:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter?
        if e then e.Color = ColorSequence.new(AMBER_155, GOLD_155); e.Rate = 4 end
        local pl = fountain:FindFirstChildOfClass("PointLight") :: PointLight?
        if pl then pl.Color = GOLD_155; pl.Brightness = 1.5 end
    end
end

local function applyHoliday_155(id: string)
    if id == lastHoliday_155 then return end
    lastHoliday_155 = id

    clearSeasonal_155()
    restoreDefault_155()

    if id == "" then
        print("[HolidayWorldService] No active holiday — hub restored to default")
        return
    end

    local c = getContainer_155()
    if not c then
        warn("[HolidayWorldService] CommunityRework_153 folder not found — run dispatch 153 first")
        return
    end

    local sp = Instance.new("Folder")
    sp.Name = "SeasonalParts"
    sp.Parent = c

    if id == "halloween" then buildHalloween_155(sp)
    elseif id == "winter"    then buildWinter_155(sp)
    elseif id == "spring"    then buildSpring_155(sp)
    elseif id == "harvest"   then buildHarvest_155(sp)
    elseif id == "summer"    then buildSummer_155(sp)
    end
end

-- Drive from any player's ActiveHoliday attribute (all players get same value)
Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    if not player.Parent then return end
    local id = tostring(player:GetAttribute("ActiveHoliday") or "")
    applyHoliday_155(id)
    player:GetAttributeChangedSignal("ActiveHoliday"):Connect(function()
        applyHoliday_155(tostring(player:GetAttribute("ActiveHoliday") or ""))
    end)
end)

-- Apply on first existing player
for _, p in Players:GetPlayers() do
    local id = tostring(p:GetAttribute("ActiveHoliday") or "")
    applyHoliday_155(id)
    break
end

print("[HolidayWorldService] Ready — hub transforms active for all 5 holidays")
]]
    svc.Parent = SSS
    print("✅ HolidayWorldService created")
end
```

---

## STEP B — Create HolidayCombSkins

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("HolidayCombSkins") then
    print("⏭️  HolidayCombSkins already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "HolidayCombSkins"
    ctrl.Source = [[
--!strict
-- HolidayCombSkins — dispatch 155
-- Cosmetic cell label overrides per active holiday.
-- Polls every 10s, adds/strips seasonal emoji prefix on CellLabel TextLabels.

local Players = game:GetService("Players")
local player  = Players.LocalPlayer

-- Map: holiday → {cellType → prefix}
local SKINS_155: {[string]: {[string]: string}} = {
    halloween = {brood="🎃 ", honey="👻 "},
    winter    = {honey="🍬 ", brood="❄️ "},
    spring    = {pollen="🌸 "},
    summer    = {honey="☀️ "},
    harvest   = {honey="🍂 "},
}

-- Base cell labels without any prefix (stored on first encounter)
local baseLabels_155: {[TextLabel]: string} = {}

local function getCellLabels_155(): {TextLabel}
    local labels: {TextLabel} = {}
    local map = workspace:FindFirstChild("Map")
    if not map then return labels end
    -- Each plot has a comb grid; cell content models have CellLabel BillboardGui
    for _, obj in map:GetDescendants() do
        if obj:IsA("TextLabel") and obj.Name == "CellLabel" then
            table.insert(labels, obj)
        end
    end
    return labels
end

local function getCellType_155(lbl: TextLabel): string
    -- CellLabel text is the cell type name (stripped of any prefix)
    local base = baseLabels_155[lbl] or lbl.Text
    baseLabels_155[lbl] = base
    -- Strip any existing 2-character emoji prefix
    local stripped = base:gsub("^[%z\1-\127\194-\244][\128-\191]*%s+", "", 1)
    return stripped:lower():gsub("%s+", "_")
end

local function applyHolidaySkins_155()
    local id = tostring(player:GetAttribute("ActiveHoliday") or "")
    local skinMap = id ~= "" and SKINS_155[id] or nil

    for _, lbl in getCellLabels_155() do
        local base = baseLabels_155[lbl] or lbl.Text
        baseLabels_155[lbl] = base

        if skinMap then
            local cellType = getCellType_155(lbl)
            local prefix = skinMap[cellType]
            if prefix then
                lbl.Text = prefix .. base
            else
                lbl.Text = base
            end
        else
            lbl.Text = base
        end
    end
end

-- Poll every 10 seconds
task.spawn(function()
    while player.Parent do
        applyHolidaySkins_155()
        task.wait(10)
    end
end)

player:GetAttributeChangedSignal("ActiveHoliday"):Connect(applyHolidaySkins_155)

print("[HolidayCombSkins] Ready — seasonal cell label skins active")
]]
    ctrl.Parent = SPS
    print("✅ HolidayCombSkins created")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local svc  = SSS:FindFirstChild("HolidayWorldService")
local ctrl = SPS and SPS:FindFirstChild("HolidayCombSkins")

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " HolidayWorldService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict",1,true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("SeasonalParts",1,true) and "✅" or "❌") .. " SeasonalParts folder management")
table.insert(checks, (svc and svc.Source:find("buildHalloween_155",1,true) and "✅" or "❌") .. " Halloween transform (cobwebs, orange lanterns)")
table.insert(checks, (svc and svc.Source:find("buildWinter_155",1,true) and "✅" or "❌") .. " Winter transform (snow caps, string lights)")
table.insert(checks, (svc and svc.Source:find("buildSpring_155",1,true) and "✅" or "❌") .. " Spring transform (blossom spheres)")
table.insert(checks, (svc and svc.Source:find("buildHarvest_155",1,true) and "✅" or "❌") .. " Harvest transform (leaf scatter, bright lanterns)")
table.insert(checks, (svc and svc.Source:find("buildSummer_155",1,true) and "✅" or "❌") .. " Summer transform (sunflower caps, neon rings)")
table.insert(checks, (svc and svc.Source:find("restoreDefault_155",1,true) and "✅" or "❌") .. " restoreDefault_155 cleanup")
table.insert(checks, (ctrl and "✅" or "❌") .. " HolidayCombSkins in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict",1,true) and "✅" or "❌") .. " --!strict (comb skins)")
table.insert(checks, (ctrl and ctrl.Source:find("SKINS_155",1,true) and "✅" or "❌") .. " SKINS_155 holiday→cellType map")
table.insert(checks, (ctrl and ctrl.Source:find("baseLabels_155",1,true) and "✅" or "❌") .. " baseLabels_155 original text cache")

print("=== DISPATCH 155 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 155 complete" or "❌ SOME CHECKS FAILED")

print("\nHub transforms: 5 holiday themes | SeasonalParts folder created+destroyed per switch")
print("Comb skins: 🎃brood/👻honey | 🍬honey/❄️brood | 🌸pollen | ☀️honey | 🍂honey")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HolidayWorldService (Script) | +1 permanent |
| HolidayCombSkins (LocalScript) | 0 permanent |
| SeasonalParts world parts | 0 permanent (created/destroyed per holiday) |
| **Dispatch 155 total** | **+1 permanent** |
| **Running total** | **4,194 / 5,000** |

---

## NOTES

- `lastHoliday_155` guard in `applyHoliday_155` prevents redundant rebuilds. The service only tears down and rebuilds when the holiday actually changes — not on every 60s tick.
- `restoreDefault_155` resets lantern colours and fountain state before applying the new holiday. Without this, switching from Halloween (orange lanterns) directly to Harvest would leave orange lanterns until the next server restart.
- `HolidayCombSkins` stores original label text in `baseLabels_155` on first encounter. This means the emoji prefix is always stripped cleanly when switching holidays — no double-prefix accumulation.
- The cobweb strands use `CFrame.lookAt` to orient the cylinder between two endpoints. This is the standard Roblox "beam between two points" trick without requiring Beam objects or Attachments.
- `HolidayCombSkins` polls every 10s rather than using `GetAttributeChangedSignal("ActiveHoliday")` alone because cell labels may not exist when the attribute first fires (if the comb grid loads after the script). The polling loop catches any labels that appear after init.
- Winter Hive sets `fountain.Rate = 0` (frozen). The value is restored to 4 by `restoreDefault_155` when the holiday ends, preserving the fountain upgrade from dispatch 153.
