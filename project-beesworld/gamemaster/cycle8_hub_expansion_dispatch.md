# CYCLE 8 — HUB EXPANSION DISPATCH
## Apiary Hub v3 — Community Space + Weather Notice Board

**Agent:** world-builder  
**Prerequisites:** WeatherService live (cycle5_weather_dispatch executed), LeaderboardService live (cycle6_leaderboard_dispatch executed)  
**Part budget impact:** ~95 parts → ~3,881 / 5,000 total  
**Goal:** Transform the hub from a functional clearinghouse into a warm, story-rich community space — benches, flower beds, a honey-drip fountain, and a working notice board that shows live weather state.

---

## OVERVIEW

The Apiary Hub (Workspace.Hub) currently has the cork board (cycle6_leaderboard) and core structures. This expansion adds:

1. **Bee Benches** — 3 wooden bench clusters around the hub perimeter for players to gather near
2. **Flower Beds** — 6 flower-bed strips along the inner hub walls, using existing Flora mesh templates
3. **Honey Drip Fountain** — centrepiece sculpture, part of the hub's visual identity
4. **Weather Notice Board** — small chalkboard-style SurfaceGui near the hub entrance that shows the current weather state (updated live by a client-side script reading from WeatherService via a new `WeatherSync` RemoteEvent)
5. **Improved path edges** — low stone kerb strips along the Petal Path sides

All parts go into `Workspace.Hub` in logical sub-folders. No scripts attached to parts — the WeatherNoticeController is a new LocalScript in StarterPlayerScripts.

---

## WORLD-BUILDER TASK

### Sub-folder structure inside Workspace.Hub

```
Workspace.Hub
├── LeaderboardBoard   (existing from cycle6)
├── HubBenches         (new)
├── FlowerBeds         (new)
├── HoneyFountain      (new)
├── WeatherBoard       (new)
└── PathKerbs          (new)
```

---

### 1. Bee Benches (Workspace.Hub.HubBenches)

3 bench clusters placed symmetrically around the hub. Each bench = seat plank + 2 legs + optional back rail.

**Bench A** — left side of hub, facing inward (+X):

| Part | Size | Position | Color/Material |
|------|------|----------|----------------|
| Seat_A | (12, 0.6, 3) | (−55, 7.3, −310) | BurlyWood/Wood |
| Leg_A1 | (1.5, 3, 1.5) | (−60, 5.8, −311) | SaddleBrown/Wood |
| Leg_A2 | (1.5, 3, 1.5) | (−50, 5.8, −311) | SaddleBrown/Wood |
| Leg_A3 | (1.5, 3, 1.5) | (−60, 5.8, −309) | SaddleBrown/Wood |
| Leg_A4 | (1.5, 3, 1.5) | (−50, 5.8, −309) | SaddleBrown/Wood |
| Back_A | (12, 3, 0.6) | (−55, 9.5, −311.5) | BurlyWood/Wood |

**Bench B** — right side of hub, facing inward (−X), mirror of A:

| Part | Size | Position | Color/Material |
|------|------|----------|----------------|
| Seat_B | (12, 0.6, 3) | (+55, 7.3, −310) | BurlyWood/Wood |
| Leg_B1 | (1.5, 3, 1.5) | (+60, 5.8, −311) | SaddleBrown/Wood |
| Leg_B2 | (1.5, 3, 1.5) | (+50, 5.8, −311) | SaddleBrown/Wood |
| Leg_B3 | (1.5, 3, 1.5) | (+60, 5.8, −309) | SaddleBrown/Wood |
| Leg_B4 | (1.5, 3, 1.5) | (+50, 5.8, −309) | SaddleBrown/Wood |
| Back_B | (12, 3, 0.6) | (+55, 9.5, −311.5) | BurlyWood/Wood |

**Bench C** — facing the leaderboard board (front-centre, facing −Z):

| Part | Size | Position | Color/Material |
|------|------|----------|----------------|
| Seat_C | (14, 0.6, 3) | (0, 7.3, −240) | BurlyWood/Wood |
| Leg_C1 | (1.5, 3, 1.5) | (−6, 5.8, −241.5) | SaddleBrown/Wood |
| Leg_C2 | (1.5, 3, 1.5) | (+6, 5.8, −241.5) | SaddleBrown/Wood |
| Leg_C3 | (1.5, 3, 1.5) | (−6, 5.8, −238.5) | SaddleBrown/Wood |
| Leg_C4 | (1.5, 3, 1.5) | (+6, 5.8, −238.5) | SaddleBrown/Wood |

All bench parts: **Anchored=true, CanCollide=true, CastShadow=true**.

---

### 2. Flower Beds (Workspace.Hub.FlowerBeds)

6 flower-bed strips, 3 per side wall, alternating colours. Each strip: a soil trough (SmoothPlastic #4A2F0A) with clover/flower MeshPart props on top.

**Left wall strips** (X ≈ −68, facing +X):

| Name | Position | Size |
|------|----------|------|
| Bed_L1 | (−68, 6.5, −280) | (4, 3, 16) |
| Bed_L2 | (−68, 6.5, −310) | (4, 3, 16) |
| Bed_L3 | (−68, 6.5, −340) | (4, 3, 16) |

**Right wall strips** (X ≈ +68, mirror):

| Name | Position | Size |
|------|----------|------|
| Bed_R1 | (+68, 6.5, −280) | (4, 3, 16) |
| Bed_R2 | (+68, 6.5, −310) | (4, 3, 16) |
| Bed_R3 | (+68, 6.5, −340) | (4, 3, 16) |

All trough parts: Color=Color3.fromHex("#4A2F0A"), Material=SmoothPlastic, Anchored=true, CanCollide=true.

**Flower top layer** — for each bed, place 4 small cylinders (Neon, radius ≈ 1 stud) as flower blobs on top of the trough. Alternate colours from the existing Flora palette:

```
Flower colours (cycling): #F2A81C (Honey Gold), #E8D49A (Wax Cream), #FF8C69 (Salmon), #C8E6A0 (Pale Sage)
Flower part: Size=(2, 2, 2), Shape=Cylinder (axis Y), Material=Neon, Transparency=0.1
Spacing: 3 studs apart along Z-axis inside the trough, Y = trough top + 1
```

Each bed gets 4 flower blobs = 4 parts × 6 beds = 24 flower parts + 6 troughs = **30 parts**.

---

### 3. Honey Drip Fountain (Workspace.Hub.HoneyFountain)

A centrepiece sculpture at hub centre (0, 6, −310). Purely decorative — a honeycomb-pattern pedestal with a top bowl and amber-glowing fluid suggestion.

| Part | ClassName | Size | Position | Color/Material | Notes |
|------|-----------|------|----------|----------------|-------|
| Base | Part | (10, 1.5, 10) | (0, 6.75, −310) | SaddleBrown/Wood | Octagon approximated — use CylinderMesh |
| Pedestal | Part | (4, 8, 4) | (0, 11, −310) | Color=#7A4A22/SmoothPlastic | Hexagonal: use SpecialMesh Cylinder |
| Bowl | Part | (10, 2, 10) | (0, 15.5, −310) | Color=#C8860A/SmoothPlastic | CylinderMesh |
| HoneyPool | Part | (8, 0.5, 8) | (0, 16, −310) | Color=#F2A81C/Neon, Transparency=0.2 | CylinderMesh, glowing honey surface |
| PointLight | — | — | (0, 16.5, −310) | — | Color=#F2A81C, Brightness=3, Range=20, parent to HoneyPool |
| Drip_1 | Part | (0.8, 4, 0.8) | (−2, 13, −310) | Color=#E8A020/Neon, Transparency=0.4 | Thin rod, simulates drip |
| Drip_2 | Part | (0.8, 3, 0.8) | (+2, 13.5, −310) | Color=#E8A020/Neon, Transparency=0.4 | |
| Drip_3 | Part | (0.8, 3.5, 0.8) | (0, 13, −312) | Color=#E8A020/Neon, Transparency=0.4 | |

All parts: Anchored=true. Base/Pedestal/Bowl: CanCollide=true. HoneyPool/Drips: CanCollide=false, CastShadow=false.

**Total fountain:** 8 parts + 1 PointLight.

---

### 4. Weather Notice Board (Workspace.Hub.WeatherBoard)

A chalkboard near the hub entrance, right side (X=+30, Z=−268, facing +Z direction so players walking in can read it).

| Part | Size | Position | Color/Material | Notes |
|------|------|----------|----------------|-------|
| BoardPost_L | (1, 8, 1) | (+27, 8.5, −268) | SaddleBrown/Wood | Left post |
| BoardPost_R | (1, 8, 1) | (+33, 8.5, −268) | SaddleBrown/Wood | Right post |
| BoardFrame | (9, 7, 0.8) | (+30, 11, −268) | SaddleBrown/Wood | Frame |
| BoardSurface | (8, 6, 0.4) | (+30, 11, −267.8) | Color=#1A2A1A/SmoothPlastic | Chalkboard, CanCollide=false |

**Tags:** Add CollectionService tag `WeatherBoard` to `BoardSurface`.

**SurfaceGui on BoardSurface:**

```
BoardSurface
└── WeatherGui (SurfaceGui)
    ├── Face = Enum.NormalId.Front
    ├── SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    ├── PixelsPerStud = 50
    └── Frame "BoardContent"
        ├── Size = UDim2.new(1,0,1,0)
        ├── BackgroundTransparency = 1
        ├── TextLabel "WeatherTitle"
        │   ├── Size = UDim2.new(1,0,0.25,0)
        │   ├── Text = "TODAY'S WEATHER"
        │   ├── Font = Enum.Font.GothamBold
        │   ├── TextScaled = true
        │   ├── TextColor3 = Color3.fromRGB(200,230,200)
        │   └── BackgroundTransparency = 1
        ├── TextLabel "WeatherState"
        │   ├── Size = UDim2.new(1,0,0.35,0)
        │   ├── Position = UDim2.new(0,0,0.25,0)
        │   ├── Text = "☀️  Clear"
        │   ├── Font = Enum.Font.GothamBold
        │   ├── TextScaled = true
        │   ├── TextColor3 = Color3.fromRGB(242,168,28)
        │   └── BackgroundTransparency = 1
        └── TextLabel "WeatherEffect"
            ├── Size = UDim2.new(1,0,0.32,0)
            ├── Position = UDim2.new(0,0,0.65,0)
            ├── Text = "Bees foraging normally"
            ├── Font = Enum.Font.Gotham
            ├── TextScaled = true
            ├── TextColor3 = Color3.fromRGB(180,210,180)
            └── BackgroundTransparency = 1
```

**Part total:** 4 parts + SurfaceGui.

---

### 5. Path Kerbs (Workspace.Hub.PathKerbs)

Low stone strips along each side of the Petal Path (the path connecting the hub to the plot area runs roughly Z=−200 to Z=−266). Two rows of kerb stones.

**Left kerb row** (X=−12):

| Name | Size | Position | Color/Material |
|------|------|----------|----------------|
| Kerb_L1 | (2, 1, 16) | (−12, 5.5, −210) | Cobblestone/SmoothPlastic Color=#8A8A7A |
| Kerb_L2 | (2, 1, 16) | (−12, 5.5, −228) | same |
| Kerb_L3 | (2, 1, 16) | (−12, 5.5, −246) | same |
| Kerb_L4 | (2, 1, 16) | (−12, 5.5, −264) | same |

**Right kerb row** (X=+12, mirror):

| Name | Size | Position | Color/Material |
|------|------|----------|----------------|
| Kerb_R1 | (2, 1, 16) | (+12, 5.5, −210) | same |
| Kerb_R2 | (2, 1, 16) | (+12, 5.5, −228) | same |
| Kerb_R3 | (2, 1, 16) | (+12, 5.5, −246) | same |
| Kerb_R4 | (2, 1, 16) | (+12, 5.5, −264) | same |

All kerbs: Anchored=true, CanCollide=true, CastShadow=false.

**Total kerbs:** 8 parts.

---

## PART BUDGET SUMMARY

| Area | Parts |
|------|-------|
| Benches (A+B+C) | 17 |
| Flower beds (6 troughs + 24 blossoms) | 30 |
| Honey fountain | 8 |
| Weather board | 4 |
| Path kerbs | 8 |
| **Sub-total** | **67** |

Previous total: ~3,786. New total: **~3,853 / 5,000**.

---

## LUAU-SCRIPTER TASK — WeatherNoticeController

A small LocalScript that keeps the WeatherBoard SurfaceGui updated in real time.

**Location:** `StarterPlayerScripts.WeatherNoticeController`  
**Type:** LocalScript  
**Strict:** `--!strict`

```lua
--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local WeatherSync: RemoteEvent = Remotes:WaitForChild("WeatherSync")

-- State display config
local STATE_DISPLAY: {[string]: {icon:string, color:Color3, effectText:string}} = {
	Clear     = {icon="☀️  Clear",     color=Color3.fromRGB(242,168,28),  effectText="Bees foraging normally"},
	Breezy    = {icon="💨  Breezy",    color=Color3.fromRGB(180,220,255), effectText="Foragers flying fast! +15% speed"},
	Overcast  = {icon="☁️  Overcast",   color=Color3.fromRGB(180,180,180), effectText="Wasp raids slightly more likely"},
	Rain      = {icon="🌧️  Raining",    color=Color3.fromRGB(100,140,200), effectText="⚠️ Foraging suspended"},
	BloomRush = {icon="🌸  BLOOM RUSH", color=Color3.fromRGB(255,180,220), effectText="✨ All honey yield +30%!"},
}

local function updateBoards(stateName: string): ()
	local cfg = STATE_DISPLAY[stateName] or STATE_DISPLAY.Clear
	for _, part in CollectionService:GetTagged("WeatherBoard") do
		local sg = part:FindFirstChild("WeatherGui")
		if sg and sg:IsA("SurfaceGui") then
			local content = sg:FindFirstChild("BoardContent")
			if content then
				local stateLabel  = content:FindFirstChild("WeatherState")  :: TextLabel?
				local effectLabel = content:FindFirstChild("WeatherEffect") :: TextLabel?
				if stateLabel  then stateLabel.Text  = cfg.icon;       stateLabel.TextColor3  = cfg.color end
				if effectLabel then effectLabel.Text = cfg.effectText; effectLabel.TextColor3 = Color3.fromRGB(180,210,180) end
			end
		end
	end
end

-- WeatherSync fires {stateName: string} from WeatherService to all clients
WeatherSync.OnClientEvent:Connect(function(data: {stateName: string})
	updateBoards(data.stateName)
end)

-- Initial state (boards show default until first sync)
updateBoards("Clear")
```

**WeatherService hook** — in `ServerScriptService.Systems.WeatherService`, add a `WeatherSync` RemoteEvent fire inside `applyState()`:

```lua
-- Add at top of WeatherService: 
local WeatherSync: RemoteEvent = Remotes:WaitForChild("WeatherSync")

-- Inside applyState(stateName):
WeatherSync:FireAllClients({stateName = stateName})
```

**New RemoteEvent:** Add `WeatherSync` (RemoteEvent) to `ReplicatedStorage.Remotes`.

---

## VERIFICATION SCRIPT

```lua
local CS  = game:GetService("CollectionService")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS  = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- Part counts per folder
local folders = {
	HubBenches   = {min=17, path="Workspace.Hub.HubBenches"},
	FlowerBeds   = {min=28, path="Workspace.Hub.FlowerBeds"},
	HoneyFountain= {min=7,  path="Workspace.Hub.HoneyFountain"},
	WeatherBoard = {min=3,  path="Workspace.Hub.WeatherBoard"},
	PathKerbs    = {min=7,  path="Workspace.Hub.PathKerbs"},
}
local hub = workspace:FindFirstChild("Hub")
if not hub then
	table.insert(issues, "FAIL: Workspace.Hub not found")
else
	for folderName, spec in folders do
		local folder = hub:FindFirstChild(folderName)
		if not folder then
			table.insert(issues, "FAIL: Workspace.Hub." .. folderName .. " folder missing")
		else
			local count = 0
			for _, p in folder:GetDescendants() do if p:IsA("BasePart") then count += 1 end end
			if count >= spec.min then
				table.insert(results, "PASS: " .. folderName .. " has " .. count .. " parts")
			else
				table.insert(issues, "FAIL: " .. folderName .. " only " .. count .. " parts (expected ≥" .. spec.min .. ")")
			end
		end
	end
end

-- WeatherBoard tag + SurfaceGui
local boards = CS:GetTagged("WeatherBoard")
if #boards >= 1 then
	local sg = boards[1]:FindFirstChild("WeatherGui")
	if sg and sg:IsA("SurfaceGui") then
		local content = sg:FindFirstChild("BoardContent")
		table.insert(results, "PASS: WeatherBoard has WeatherGui + BoardContent")
		if not (content and content:FindFirstChild("WeatherState")) then
			table.insert(issues, "FAIL: WeatherBoard missing WeatherState label")
		end
	else
		table.insert(issues, "FAIL: WeatherBoard part lacks WeatherGui SurfaceGui")
	end
else
	table.insert(issues, "FAIL: No part tagged WeatherBoard")
end

-- WeatherSync remote
local wsync = RS.Remotes:FindFirstChild("WeatherSync")
if wsync and wsync:IsA("RemoteEvent") then
	table.insert(results, "PASS: WeatherSync RemoteEvent exists")
else
	table.insert(issues, "FAIL: WeatherSync RemoteEvent missing")
end

-- WeatherNoticeController LocalScript
local ctrl = SPS and SPS:FindFirstChild("WeatherNoticeController")
if ctrl and ctrl:IsA("LocalScript") then
	table.insert(results, "PASS: WeatherNoticeController LocalScript exists")
else
	table.insert(issues, "FAIL: WeatherNoticeController missing from StarterPlayerScripts")
end

-- WeatherService fires WeatherSync
local wsMod = SSS.Systems:FindFirstChild("WeatherService")
if wsMod and wsMod:IsA("ModuleScript") then
	if wsMod.Source:find("WeatherSync") then
		table.insert(results, "PASS: WeatherService fires WeatherSync")
	else
		table.insert(issues, "WARN: WeatherService may not fire WeatherSync -- check applyState()")
	end
end

-- Summary
print("=== HUB EXPANSION VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
	print("\n--- ISSUES ---")
	for _, iss in issues do print(iss) end
	print("\nSTATUS: NEEDS FIXES (" .. #issues .. ")")
else
	print("\nSTATUS: ALL PASS — hub expansion complete")
end
```
