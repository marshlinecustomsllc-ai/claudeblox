# CYCLE 11 — NARRATIVE DISPATCH (dispatch 26)
## Environmental Storytelling + NarrativeEngine

**Agent:** luau-scripter  
**Supersedes:** `cycle7_narrative_dispatch.md` (stale part budget total; wardrobe_pad trigger
position did not exist when cycle 7 was written — WardrobePad BASE_Z=35 per dispatch 22)  
**Prerequisites:** None — entirely client-side, no server dependencies  
**Part budget impact:** +18 invisible ZoneTrigger parts → **~4,094 / 5,000** total  
**Design tone:** Warm, whimsical, with a thread of urgency. The beekeeper left notes. Something
is coming from the treeline. The bees remember everything.

---

## OVERVIEW

Invisible `ZoneTrigger` parts at 18 locations across the world. When a player walks within
radius, a short atmospheric text fragment fades in at the bottom of the screen (typewriter
reveal). No interaction needed — pure ambient storytelling. Entirely client-side, zero server
load, zero DataService dependencies.

Emotional zones:
- **Hub / Apiary Yard** → warmth, wonder, the joy of building
- **Plot mechanics** → wonder and purpose, each system explained through feeling
- **Wild Meadow** → peace before the storm
- **Treeline / Bear territory** → dread, Molasses foreshadowing
- **Late-game / prestige** → payoff for long-term players (swarm perch, wardrobe, generation)

---

## STEP A — NarrativeGui in StarterGui

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP A: Create NarrativeGui
local SG = game:GetService("StarterGui")

-- Remove old version if exists
local old = SG:FindFirstChild("NarrativeGui")
if old then old:Destroy() end

local nguiParent = SG
local ngui = Instance.new("ScreenGui")
ngui.Name           = "NarrativeGui"
ngui.DisplayOrder   = 20
ngui.ResetOnSpawn   = false
ngui.IgnoreGuiInset = true
ngui.Parent         = nguiParent

local frame = Instance.new("Frame")
frame.Name                   = "NarrativeFrame"
frame.Size                   = UDim2.new(0.5, 0, 0, 60)
frame.Position               = UDim2.new(0.25, 0, 0.88, 0)
frame.AnchorPoint            = Vector2.new(0, 0)
frame.BackgroundColor3       = Color3.fromRGB(20, 12, 5)
frame.BackgroundTransparency = 1
frame.ZIndex                 = 8
frame.Parent                 = ngui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 6)
corner.Parent       = frame

local label = Instance.new("TextLabel")
label.Name                  = "NarrativeText"
label.Size                  = UDim2.new(1, -16, 1, 0)
label.Position              = UDim2.new(0, 8, 0, 0)
label.BackgroundTransparency= 1
label.Font                  = Enum.Font.GothamItalic
label.TextScaled            = true
label.TextColor3            = Color3.fromRGB(232, 212, 154)
label.TextTransparency      = 1
label.TextXAlignment        = Enum.TextXAlignment.Center
label.RichText               = true
label.Text                  = ""
label.ZIndex                = 9
label.Parent                = frame

print("STEP A DONE: NarrativeGui created in StarterGui, DisplayOrder=" .. ngui.DisplayOrder)
```

---

## STEP B — NarrativeEngine LocalScript

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP B: Create NarrativeEngine LocalScript
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if not SPS then
    SPS = Instance.new("Folder")
    SPS.Name   = "StarterPlayerScripts"
    SPS.Parent = game:GetService("StarterPlayer")
end

local old = SPS:FindFirstChild("NarrativeEngine")
if old then old:Destroy() end

local eng  = Instance.new("LocalScript")
eng.Name   = "NarrativeEngine"
eng.Parent = SPS

eng.Source = [[
--!strict
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player        = Players.LocalPlayer
local character     = player.Character or player.CharacterAdded:Wait()
local humanoidRoot  = character:WaitForChild("HumanoidRootPart") :: BasePart

player.CharacterAdded:Connect(function(newChar)
    character    = newChar
    humanoidRoot = newChar:WaitForChild("HumanoidRootPart") :: BasePart
end)

local gui   = player.PlayerGui:WaitForChild("NarrativeGui")         :: ScreenGui
local frame = gui:WaitForChild("NarrativeFrame")                     :: Frame
local label = frame:WaitForChild("NarrativeText")                    :: TextLabel

-- Narrative text table — keyed by NarrativeId attribute on ZoneTrigger parts
local NARRATIVES: {[string]: string} = {
    -- Hub / Apiary Yard
    hub_entrance   = "These hives have stood since before the bear's shadow first crossed the treeline.",
    hub_sign       = "Beekeeper's log: Day 1. Six plots, one hope. The wild meadow waits.",
    apiary_shed    = "The shed smells of old smoke and older honey. Someone worked hard here once.",
    propolis_kiln  = "Propolis seals cracks. It also keeps out things that should not enter.",

    -- Plots
    plot_first     = "Each cell you build is a vote for something sweeter than what came before.",
    dance_floor    = "The waggle dance is the oldest map. Every figure-eight is a promise.",
    royal_cell     = "The Royal Cell hums. Something stirs inside — patient and absolute.",
    comb_floor_2   = "Higher floors, thinner air. The queen looks down and finds it good.",
    comb_floor_3   = "At the peak, the hive becomes a single thought. And the thought is: more.",

    -- Wild Meadow
    meadow_entry   = "The meadow remembers when nothing lived here but wind and seed.",
    meadow_deep    = "Fireweed. Aurora bloom. The flowers that grow where old fires burned.",
    meadow_puddle  = "Still water reflects the hive. For a moment, everything looks perfect.",

    -- Treeline / Bear territory
    treeline_edge  = "The pines grow strange here. Too close together. Too quiet between them.",
    bear_lane      = "Something wide and heavy has walked this path. Repeatedly.",
    molasses_den   = "A hollow where the earth is dark and sweet-smelling. You should leave.",
    molasses_late  = "The marks on the fence are new. It came closer last night.",

    -- Late-game / prestige
    swarm_perch    = "The swarm perch waits. When you are ready, the bees will know before you do.",
    wardrobe_pad   = "The wardrobe holds colours the bees have earned. Each one carries a memory.",
}

local _seenIds:     {[string]: boolean} = {}
local _displaying   = false
local _displayQueue: {string}           = {}

local FADE_TIME  = 0.5
local HOLD_TIME  = 4.5
local CHAR_DELAY = 0.04

local function revealText(text: string): ()
    _displaying = true

    label.Text               = text
    label.MaxVisibleGraphemes = 0
    label.TextTransparency   = 0
    TweenService:Create(frame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 0.35
    }):Play()

    for i = 0, #text do
        label.MaxVisibleGraphemes = i
        task.wait(CHAR_DELAY)
    end

    task.wait(HOLD_TIME)

    TweenService:Create(frame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
        BackgroundTransparency = 1
    }):Play()
    TweenService:Create(label, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
        TextTransparency = 1
    }):Play()
    task.wait(FADE_TIME)

    label.Text  = ""
    _displaying = false

    if #_displayQueue > 0 then
        local next = table.remove(_displayQueue, 1)
        task.spawn(revealText, next)
    end
end

local function queueNarrative(id: string): ()
    local text = NARRATIVES[id]
    if not text then return end
    if _seenIds[id] then return end
    _seenIds[id] = true

    if _displaying then
        table.insert(_displayQueue, text)
    else
        task.spawn(revealText, text)
    end
end

RunService.Heartbeat:Connect(function()
    local hrp = humanoidRoot
    if not hrp then return end
    local pos = hrp.Position

    for _, trigger in CollectionService:GetTagged("NarrativeTrigger") do
        local part   = trigger :: BasePart
        local id     = part:GetAttribute("NarrativeId")   :: string?
        local radius = part:GetAttribute("TriggerRadius") :: number?
        if id and radius then
            local dist = (pos - part.Position).Magnitude
            if dist <= radius and not _seenIds[id] then
                queueNarrative(id)
            end
        end
    end
end)
]]

print("STEP B DONE: NarrativeEngine LocalScript created (" ..
      select(2, eng.Source:gsub("\n","\n")) + 1 .. " lines)")
```

---

## STEP C — ZoneTrigger parts in Workspace

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP C: Create 18 ZoneTrigger parts
local CS = game:GetService("CollectionService")

-- Remove old folder if exists
local oldFolder = workspace:FindFirstChild("NarrativeTriggers")
if oldFolder then oldFolder:Destroy() end

local folder = Instance.new("Folder")
folder.Name   = "NarrativeTriggers"
folder.Parent = workspace

local function makeTrigger(id, x, y, z, radius)
    local p = Instance.new("Part")
    p.Name         = "NarrTrigger_" .. id
    p.Size         = Vector3.new(2, 2, 2)
    p.Position     = Vector3.new(x, y, z)
    p.Anchored     = true
    p.CanCollide   = false
    p.Transparency = 1
    p.Parent       = folder
    p:SetAttribute("NarrativeId",   id)
    p:SetAttribute("TriggerRadius", radius)
    CS:AddTag(p, "NarrativeTrigger")
end

-- Hub / Apiary Yard (Z≈-266..-406 per corrected architecture)
makeTrigger("hub_entrance",  0,   5, -270, 18)  -- just inside hub entrance from Petal Path
makeTrigger("hub_sign",      0,   5, -320, 12)  -- near hub centre signpost
makeTrigger("apiary_shed", -42,   5, -300, 10)  -- ApiaryShed structure area
makeTrigger("propolis_kiln", 42,  5, -300, 10)  -- PropolisKiln structure area

-- Plots (deck Z -55..+55, deck Y≈6)
makeTrigger("plot_first",  -250,  8,  -50, 15)  -- Plot 1 deck near LandingBoard entrance
makeTrigger("dance_floor", -250,  8,    0, 10)  -- Centre of Plot 1 (dance floor cell Z=0)
makeTrigger("royal_cell",  -250,  8,  -10,  8)  -- Near Royal Cell rim position on Plot 1
makeTrigger("comb_floor_2",-250, 25,    0, 10)  -- Floor 2 elevation (≈19 studs above deck)
makeTrigger("comb_floor_3",-250, 40,    0, 10)  -- Floor 3 elevation (≈34 studs above deck)

-- Wild Meadow (Z≈-96..-266 per corrected architecture)
makeTrigger("meadow_entry",   0,  3, -131, 20)  -- Patch 1 area, meadow near edge Z≈-131
makeTrigger("meadow_deep",   60,  3, -220, 15)  -- Far meadow, Patch 10/11 area
makeTrigger("meadow_puddle", -30, 3, -180, 12)  -- Near puddle (Z≈-180)

-- Treeline / Bear territory (Z>0 = Pine Treeline side)
makeTrigger("treeline_edge",  0,  3,  60,  18)  -- Start of Pine Treeline zone
makeTrigger("bear_lane",      0,  3,  80,  15)  -- Bear Lane path
makeTrigger("molasses_den",   0,  3, 100,  12)  -- Molasses Den area
makeTrigger("molasses_late",  0,  3,  60,  18)  -- Same zone as treeline_edge (seen filter handles uniqueness)

-- Late-game / prestige (on Plot 1 deck, BASE_Z=35 per dispatch 22 WardrobePad positions)
makeTrigger("swarm_perch",  -250, 8,  50,  12)  -- SwarmPerch pedestal area on Plot 1
makeTrigger("wardrobe_pad", -250, 8,  35,  12)  -- WardrobePad position on Plot 1 (BASE_Z=35)

-- Verify
local triggers = CS:GetTagged("NarrativeTrigger")
print("STEP C DONE: " .. #triggers .. " NarrativeTrigger parts created (expected 18)")
```

---

## STEP D — Verification

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP D: Verify narrative system
local SG  = game:GetService("StarterGui")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local CS  = game:GetService("CollectionService")

local results = {}
local issues  = {}

-- 1. NarrativeGui
local ngui = SG:FindFirstChild("NarrativeGui")
if ngui and ngui:IsA("ScreenGui") then
    local fr = ngui:FindFirstChild("NarrativeFrame")
    local lb = fr and fr:FindFirstChild("NarrativeText")
    if fr and lb then
        table.insert(results, "PASS: NarrativeGui/NarrativeFrame/NarrativeText hierarchy correct")
        if ngui.DisplayOrder ~= 20 then
            table.insert(issues, "WARN: NarrativeGui.DisplayOrder=" .. ngui.DisplayOrder .. " (expected 20)")
        end
    else
        table.insert(issues, "FAIL: NarrativeGui missing NarrativeFrame or NarrativeText")
    end
else
    table.insert(issues, "FAIL: NarrativeGui missing from StarterGui")
end

-- 2. NarrativeEngine
local eng = SPS and SPS:FindFirstChild("NarrativeEngine")
if eng and eng:IsA("LocalScript") then
    local src   = eng.Source
    local lines = select(2, src:gsub("\n","\n")) + 1
    local checks = {
        hasStrict      = src:find("--!strict") ~= nil,
        hasTween       = src:find("TweenService") ~= nil,
        hasMagnitude   = src:find("Magnitude") ~= nil,
        hasMaxVisible  = src:find("MaxVisibleGraphemes") ~= nil,
        hasHeartbeat   = src:find("Heartbeat") ~= nil,
        hasNarratives  = src:find("NARRATIVES") ~= nil,
    }
    local fails = {}
    for k, v in checks do if not v then table.insert(fails, k) end end
    if #fails == 0 then
        table.insert(results, "PASS: NarrativeEngine LocalScript (" .. lines .. " lines, all key features present)")
    else
        table.insert(issues, "FAIL: NarrativeEngine missing: " .. table.concat(fails, ", "))
    end
else
    table.insert(issues, "FAIL: NarrativeEngine LocalScript missing from StarterPlayerScripts")
end

-- 3. ZoneTriggers
local triggers = CS:GetTagged("NarrativeTrigger")
table.insert(results, "INFO: " .. #triggers .. " NarrativeTrigger parts found (expected 18)")
if #triggers < 18 then
    table.insert(issues, "WARN: Only " .. #triggers .. "/18 NarrativeTrigger parts present")
end

for _, t in triggers do
    local id     = t:GetAttribute("NarrativeId")
    local radius = t:GetAttribute("TriggerRadius")
    if not id     then table.insert(issues, "FAIL: " .. t.Name .. " missing NarrativeId") end
    if not radius then table.insert(issues, "FAIL: " .. t.Name .. " missing TriggerRadius") end
    if not t.Anchored     then table.insert(issues, "FAIL: " .. t.Name .. " not Anchored") end
    if t.CanCollide       then table.insert(issues, "FAIL: " .. t.Name .. " CanCollide=true") end
    if t.Transparency < 1 then table.insert(issues, "FAIL: " .. t.Name .. " not invisible") end
end

-- 4. Folder
local folder = workspace:FindFirstChild("NarrativeTriggers")
if folder and folder:IsA("Folder") then
    table.insert(results, "PASS: NarrativeTriggers folder in Workspace")
else
    table.insert(issues, "WARN: NarrativeTriggers folder missing from Workspace")
end

-- Summary
print("=== NARRATIVE VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\n--- ISSUES ---")
    for _, iss in issues do print(iss) end
    print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
    print("\nSTATUS: ALL CHECKS PASS — narrative system ready")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| NarrativeGui | ScreenGui | StarterGui |
| NarrativeEngine | LocalScript | StarterPlayerScripts |
| 18 ZoneTrigger parts | Parts in Folder | Workspace.NarrativeTriggers |

**Part budget delta:** +18 invisible parts → **~4,094 / 5,000** total.

**Trigger zones:**

| NarrativeId | X | Y | Z | Radius | Zone |
|---|---|---|---|---|---|
| hub_entrance | 0 | 5 | -270 | 18 | Hub entrance |
| hub_sign | 0 | 5 | -320 | 12 | Hub centre |
| apiary_shed | -42 | 5 | -300 | 10 | Shed area |
| propolis_kiln | 42 | 5 | -300 | 10 | Kiln area |
| plot_first | -250 | 8 | -50 | 15 | Plot 1 entrance |
| dance_floor | -250 | 8 | 0 | 10 | Plot 1 centre |
| royal_cell | -250 | 8 | -10 | 8 | Plot 1 rim |
| comb_floor_2 | -250 | 25 | 0 | 10 | Floor 2 height |
| comb_floor_3 | -250 | 40 | 0 | 10 | Floor 3 height |
| meadow_entry | 0 | 3 | -131 | 20 | Meadow near edge |
| meadow_deep | 60 | 3 | -220 | 15 | Meadow far |
| meadow_puddle | -30 | 3 | -180 | 12 | Puddle |
| treeline_edge | 0 | 3 | 60 | 18 | Treeline start |
| bear_lane | 0 | 3 | 80 | 15 | Bear Lane |
| molasses_den | 0 | 3 | 100 | 12 | Molasses Den |
| molasses_late | 0 | 3 | 60 | 18 | Treeline (alt text) |
| swarm_perch | -250 | 8 | 50 | 12 | SwarmPerch (Plot 1) |
| wardrobe_pad | -250 | 8 | 35 | 12 | WardrobePad (Plot 1, BASE_Z=35) |

**Key corrections from cycle7_narrative_dispatch.md:**
1. `wardrobe_pad` trigger moved from (-280, 12, -45) → (-250, 8, 35) to match actual WardrobePad build position (dispatch 22: BASE_Z=35 on each plot deck, plot X=-250)
2. `plot_first` trigger moved from (-250, 8, -90) → (-250, 8, -50) — Z=-90 is outside the deck footprint (deck Z -55..+55); corrected to deck entrance at Z=-50
3. `dance_floor` trigger Z corrected from -50 → 0 (cell (0,0) is at deck centre Z=0, not Z=-50)
4. `royal_cell` trigger Z corrected from -60 → -10 (rim cells are at ~8 studs from centre, not 60)
5. Part budget updated: ~3,786 → ~4,094 / 5,000

**Narrative text:** 18 fragments across 5 zones — hub/apiary (4), plot mechanics (5), meadow (3), treeline/Molasses (4), late-game prestige (2). Each fires once per session, queues if one is already displaying. Typewriter at 40ms/char, 4.5s hold, 0.5s fade. No server involvement whatsoever.
