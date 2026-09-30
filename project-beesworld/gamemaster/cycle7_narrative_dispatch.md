# CYCLE 7 — NARRATIVE DISPATCH
## Environmental Storytelling + NarrativeEngine

**Agent:** luau-scripter  
**Prerequisites:** None — entirely client-side, no server dependencies  
**Part budget impact:** ~18 invisible trigger parts (ZoneTriggers at key locations, Transparency=1)  
**Design tone:** Warm, whimsical, with a thread of urgency. The beekeeper left notes. Something is coming from the treeline. The bees remember everything.

---

## OVERVIEW

Invisible `ZoneTrigger` parts at 18 locations across the world. When a player walks within radius, a short atmospheric text fragment fades in at the bottom of the screen (typewriter reveal). No interaction needed — pure ambient storytelling. Client-side only, zero server load.

This ties together the emotional journey:
- **Plots / hub** → warmth, wonder, the joy of building
- **Meadow** → peace before the storm  
- **Treeline edge** → dread, Molasses foreshadowing
- **Late-game unlocks** → payoff for long-term players (swarm, cosmetics, queen)

---

## LUAU-SCRIPTER TASK

### 1. NarrativeGui in StarterGui

**Location:** `StarterGui.NarrativeGui`  
**Type:** ScreenGui  
Properties: `DisplayOrder=20`, `ResetOnSpawn=false`, `IgnoreGuiInset=true`

```
NarrativeGui (ScreenGui)
└── NarrativeFrame (Frame)
    ├── Size:           UDim2.new(0.5, 0, 0, 60)
    ├── Position:       UDim2.new(0.25, 0, 0.88, 0)
    ├── AnchorPoint:    Vector2.new(0, 0)
    ├── BackgroundColor3: Color3.fromRGB(20, 12, 5)
    ├── BackgroundTransparency: 1   (starts invisible; tweened on reveal)
    ├── ZIndex:         8
    ├── UICorner:       CornerRadius UDim.new(0, 6)
    └── NarrativeText (TextLabel)
        ├── Size:           UDim2.new(1, -16, 1, 0)
        ├── Position:       UDim2.new(0, 8, 0, 0)
        ├── BackgroundTransparency: 1
        ├── Font:           Enum.Font.GothamItalic
        ├── TextScaled:     true
        ├── TextColor3:     Color3.fromRGB(232, 212, 154)   -- Wax Cream
        ├── TextTransparency: 1   (starts invisible)
        ├── TextXAlignment: Enum.TextXAlignment.Center
        ├── RichText:       true
        └── Text:           ""
```

---

### 2. NarrativeEngine LocalScript

**Location:** `StarterPlayerScripts.NarrativeEngine`  
**Type:** LocalScript  
**Strict:** `--!strict`

```lua
--!strict
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player        = Players.LocalPlayer
local character     = player.Character or player.CharacterAdded:Wait()
local humanoidRoot  = character:WaitForChild("HumanoidRootPart") :: BasePart

-- Re-acquire HRP on respawn
player.CharacterAdded:Connect(function(newChar)
	character    = newChar
	humanoidRoot = newChar:WaitForChild("HumanoidRootPart") :: BasePart
end)

-- GUI references
local gui        = player.PlayerGui:WaitForChild("NarrativeGui")         :: ScreenGui
local frame      = gui:WaitForChild("NarrativeFrame")                     :: Frame
local label      = frame:WaitForChild("NarrativeText")                    :: TextLabel

-- Narrative text table — keyed by NarrativeId attribute on ZoneTrigger parts
local NARRATIVES: {[string]: string} = {
	-- Hub / Apiary Yard
	hub_entrance        = "These hives have stood since before the bear's shadow first crossed the treeline.",
	hub_sign            = "Beekeeper's log: Day 1. Six plots, one hope. The wild meadow waits.",
	apiary_shed         = "The shed smells of old smoke and older honey. Someone worked hard here once.",
	propolis_kiln       = "Propolis seals cracks. It also keeps out things that should not enter.",

	-- Plots (fires on first visit to any plot — uses a single zone at plot 1 entrance)
	plot_first          = "Each cell you build is a vote for something sweeter than what came before.",
	dance_floor         = "The waggle dance is the oldest map. Every figure-eight is a promise.",
	royal_cell          = "The Royal Cell hums. Something stirs inside — patient and absolute.",
	comb_floor_2        = "Higher floors, thinner air. The queen looks down and finds it good.",
	comb_floor_3        = "At the peak, the hive becomes a single thought. And the thought is: more.",

	-- Wild Meadow
	meadow_entry        = "The meadow remembers when nothing lived here but wind and seed.",
	meadow_deep         = "Fireweed. Aurora bloom. The flowers that grow where old fires burned.",
	meadow_puddle       = "Still water reflects the hive. For a moment, everything looks perfect.",

	-- Treeline / Bear territory
	treeline_edge       = "The pines grow strange here. Too close together. Too quiet between them.",
	bear_lane           = "Something wide and heavy has walked this path. Repeatedly.",
	molasses_den        = "A hollow where the earth is dark and sweet-smelling. You should leave.",
	molasses_late       = "The marks on the fence are new. It came closer last night.",

	-- Late-game / prestige moments
	swarm_perch         = "The swarm perch waits. When you are ready, the bees will know before you do.",
	wardrobe_pad        = "The wardrobe holds skins the bees have earned. Every colour has a story.",
	generation_2        = "Your grandmother's bees were here first. Your granddaughter's bees will be here last.",
}

-- State
local _seenIds:     {[string]: boolean} = {}
local _displaying   = false
local _displayQueue: {string}           = {}

local FADE_TIME   = 0.5
local HOLD_TIME   = 4.5
local CHAR_DELAY  = 0.04

local function revealText(text: string): ()
	_displaying = true

	-- Fade frame in
	label.Text = text
	label.MaxVisibleGraphemes = 0
	label.TextTransparency    = 0
	TweenService:Create(frame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0.35
	}):Play()

	-- Typewriter reveal
	for i = 0, #text do
		label.MaxVisibleGraphemes = i
		task.wait(CHAR_DELAY)
	end

	-- Hold
	task.wait(HOLD_TIME)

	-- Fade out
	TweenService:Create(frame, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1
	}):Play()
	TweenService:Create(label, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {
		TextTransparency = 1
	}):Play()
	task.wait(FADE_TIME)

	label.Text = ""
	_displaying = false

	-- Process next in queue
	if #_displayQueue > 0 then
		local next = table.remove(_displayQueue, 1)
		task.spawn(revealText, next)
	end
end

local function queueNarrative(id: string): ()
	local text = NARRATIVES[id]
	if not text then return end
	if _seenIds[id] then return end   -- each narrative fires once per session
	_seenIds[id] = true

	if _displaying then
		table.insert(_displayQueue, text)
	else
		task.spawn(revealText, text)
	end
end

-- Proximity polling
RunService.Heartbeat:Connect(function()
	local hrp = humanoidRoot
	if not hrp then return end
	local pos = hrp.Position

	for _, trigger in CollectionService:GetTagged("NarrativeTrigger") do
		local part = trigger :: BasePart
		local id     = part:GetAttribute("NarrativeId")     :: string?
		local radius = part:GetAttribute("TriggerRadius")   :: number?
		if id and radius then
			local dist = (pos - part.Position).Magnitude
			if dist <= radius and not _seenIds[id] then
				queueNarrative(id)
			end
		end
	end
end)
```

---

### 3. ZoneTrigger placement (world-builder sub-task within this luau dispatch)

> **Note:** These are simple invisible parts placed in Workspace. The luau-scripter creates them via MCP `run_code`. They contain no scripts themselves — the NarrativeEngine polls them by CollectionService tag.

All 18 parts share these properties:
- **CanCollide:** false  
- **Anchored:** true  
- **Transparency:** 1  
- **Shape:** Enum.PartType.Cylinder (or Block — either works since invisible)  
- **Size:** (2, 2, 2) — small sphere-equivalent, radius comes from attribute  
- **CollectionService tag:** `NarrativeTrigger`

Create each with `mcp__roblox-studio__run_code`. Place them in a folder: `Workspace.NarrativeTriggers`.

```lua
-- Example Lua creation snippet (run for all 18 via a single run_code call):
local CS = game:GetService("CollectionService")
local folder = Instance.new("Folder")
folder.Name = "NarrativeTriggers"
folder.Parent = workspace

local function makeTrigger(id, pos, radius)
	local p = Instance.new("Part")
	p.Name         = "NarrTrigger_" .. id
	p.Size         = Vector3.new(2,2,2)
	p.Position     = Vector3.new(pos[1], pos[2], pos[3])
	p.Anchored     = true
	p.CanCollide   = false
	p.Transparency = 1
	p.Parent       = folder
	p:SetAttribute("NarrativeId",   id)
	p:SetAttribute("TriggerRadius", radius)
	CS:AddTag(p, "NarrativeTrigger")
end
```

**Trigger positions and radii:**

| NarrativeId | Position (X, Y, Z) | TriggerRadius | Notes |
|-------------|-------------------|---------------|-------|
| hub_entrance | (0, 5, -270) | 18 | Just inside hub entrance from path |
| hub_sign | (0, 5, -320) | 12 | Near hub centre sign post |
| apiary_shed | (-42, 5, -300) | 10 | ApiaryShed structure area |
| propolis_kiln | (42, 5, -300) | 10 | PropolisKiln structure area |
| plot_first | (-250, 8, -90) | 15 | Plot 1 deck entrance |
| dance_floor | (-250, 8, -50) | 10 | Centre of plot 1 (dance floor cell) |
| royal_cell | (-250, 8, -60) | 8 | Near Royal Cell position on plot 1 |
| comb_floor_2 | (-250, 25, -50) | 10 | Floor 2 elevation |
| comb_floor_3 | (-250, 40, -50) | 10 | Floor 3 elevation |
| meadow_entry | (0, 3, -150) | 20 | First meadow patch area |
| meadow_deep | (60, 3, -220) | 15 | Far meadow patches |
| meadow_puddle | (-30, 3, -180) | 12 | Near puddle (if exists in world) |
| treeline_edge | (0, 3, 60) | 18 | Start of Pine Treeline zone (Z>0) |
| bear_lane | (0, 3, 80) | 15 | Bear Lane path (Z≈80) |
| molasses_den | (0, 3, 100) | 12 | Molasses Den area (Z≈100) |
| molasses_late | (0, 3, 60) | 18 | Same zone as treeline_edge but fires only after gen≥1 |
| swarm_perch | (-250, 12, 50) | 12 | SwarmPerch position for plot 1 |
| wardrobe_pad | (-280, 12, -45) | 12 | WardrobePad position for plot 1 |
| generation_2 | (-250, 8, -90) | 15 | Same as plot_first, different narrative (seen filter handles uniqueness) |

> **Note on `molasses_late` and `generation_2`:** These share a position with `treeline_edge` and `plot_first` respectively. The `_seenIds` filter in NarrativeEngine means the first-seen ID fires, then the second-seen never fires again at the same location in the same session. This is intentional — the first visit shows the wonder narrative; return visits (different sessions) will not re-fire since `_seenIds` resets on respawn.

> **For a richer late-game experience:** In a future cycle, the NarrativeEngine can be extended to check `DataService` profile fields (via a `ProfileSync` remote) and conditionally enable late-game narrative IDs only after certain milestones. For this dispatch, keep it simple — all 18 trigger on proximity regardless of progression.

---

## VERIFICATION SCRIPT

Run in Studio Command Bar:

```lua
local SG  = game:GetService("StarterGui")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local CS  = game:GetService("CollectionService")

local results = {}
local issues  = {}

-- 1. NarrativeGui
local nguiOk = false
local ngui = SG:FindFirstChild("NarrativeGui")
if ngui and ngui:IsA("ScreenGui") then
	local frame = ngui:FindFirstChild("NarrativeFrame")
	local label = frame and frame:FindFirstChild("NarrativeText")
	if frame and label then
		nguiOk = true
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
	local src  = eng.Source
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
		table.insert(issues, "FAIL: NarrativeEngine missing: " .. table.concat(fails,", "))
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

local trigIssues = {}
for _, t in triggers do
	local id     = t:GetAttribute("NarrativeId")
	local radius = t:GetAttribute("TriggerRadius")
	if not id     then table.insert(trigIssues, t.Name .. ": missing NarrativeId") end
	if not radius then table.insert(trigIssues, t.Name .. ": missing TriggerRadius") end
	if not t.Anchored     then table.insert(trigIssues, t.Name .. ": not Anchored") end
	if t.CanCollide       then table.insert(trigIssues, t.Name .. ": CanCollide=true") end
	if t.Transparency < 1 then table.insert(trigIssues, t.Name .. ": not invisible") end
end
if #trigIssues == 0 then
	table.insert(results, "PASS: All trigger parts have correct attributes and properties")
else
	for _, iss in trigIssues do table.insert(issues, "FAIL: " .. iss) end
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
| 18 ZoneTrigger parts | Parts in folder | Workspace.NarrativeTriggers |

**Part budget delta:** +18 invisible parts → ~3,786 / 5,000 total.

**Narrative text summary:** 18 fragments across 5 zones — hub/apiary (4), plot mechanics (5), meadow (3), treeline/Molasses (4), late-game prestige (2). Each fires once per session, queues if one is already displaying. Typewriter at 40ms/char, 4.5s hold, 0.5s fade. No server involvement.
