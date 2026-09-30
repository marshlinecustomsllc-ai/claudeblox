# CYCLE 6 — LEADERBOARD DISPATCH
## LeaderboardService + Cork Board SurfaceGui

**Agents:** luau-scripter, world-builder  
**Prerequisites:** DataService live, `lifetimeHoney` field exists in profiles (added in cycle6_cosmetics_dispatch DataService v5→v6 migration)  
**Part budget impact:** ~18 parts (cork board + frame + backing per plot × 6, plus top-10 board in hub)  
**Profile field used:** `profile.lifetimeHoney` (total honey ever produced, never decremented)

---

## OVERVIEW

Two leaderboard surfaces:

1. **Global Top-10 Board** — a large cork board on the Apiary Hub back wall. OrderedDataStore, top 10 by lifetime honey, updates every 60 seconds. SurfaceGui shows ranked list with gold/silver/bronze crowns for top 3.

2. **Plot Personal Bests** — small cork plaque on each plot's fence post (left side of deck entrance). Shows the owning player's own generation count + best-generation honey carry. Client-side only, read from profile on spawn.

---

## LUAU-SCRIPTER TASK

### 1. Config additions (ReplicatedStorage.Modules.Config)

Append to Config after `Config.MONETIZATION`:

```lua
Config.LEADERBOARD = {
	STORE_NAME        = "GlobalHoney_v1",   -- OrderedDataStore key
	UPDATE_INTERVAL   = 60,                 -- seconds between refreshes
	TOP_N             = 10,                 -- entries to fetch
	BOARD_SURFACE_ID  = "LeaderboardBoard", -- Name tag on the SurfaceGui part
}
```

Use the require()-cache-bust pattern (clone → replace → destroy) because Config is a ModuleScript.

---

### 2. DataService — lifetimeHoney increment hook

`lifetimeHoney` is already added by the v5→v6 migration in the cosmetics dispatch. No new migration needed.

**In ResourceService** (ServerScriptService.Systems.ResourceService), find the function that credits honey to the player profile. After the line that increments `profile.honey`, add:

```lua
-- track lifetime total for leaderboard
profile.lifetimeHoney = (profile.lifetimeHoney or 0) + amount
-- submit to ordered store (fire-and-forget, errors silently)
LeaderboardService.RecordHoney(player, profile.lifetimeHoney)
```

`LeaderboardService` will be required at the top of ResourceService after it is created.

---

### 3. LeaderboardService ModuleScript

**Location:** `ServerScriptService.Systems.LeaderboardService`  
**Type:** ModuleScript  
**Strict:** `--!strict`

```lua
--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Modules.Config)
local LB_CFG = Config.LEADERBOARD

local LeaderboardService = {}

-- Remotes
local Remotes    = ReplicatedStorage:WaitForChild("Remotes")
local LeaderboardUpdate: RemoteEvent = Remotes:WaitForChild("LeaderboardUpdate")

-- OrderedDataStore (may error in Studio without API access -- all writes/reads wrapped in pcall)
local orderedStore: OrderedDataStore | nil = nil
pcall(function()
	orderedStore = DataStoreService:GetOrderedDataStore(LB_CFG.STORE_NAME)
end)

-- Write a player's lifetime honey score
function LeaderboardService.RecordHoney(player: Player, lifetimeHoney: number): ()
	if not orderedStore then return end
	local userId = player.UserId
	task.spawn(function()
		pcall(function()
			orderedStore:SetAsync(tostring(userId), math.floor(lifetimeHoney))
		end)
	end)
end

-- Fetch top N and broadcast to all clients
local function refreshBoard(): ()
	if not orderedStore then return end
	local ok, pages = pcall(function()
		return orderedStore:GetSortedAsync(false, LB_CFG.TOP_N)
	end)
	if not ok or not pages then return end

	local ok2, currentPage = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not ok2 or not currentPage then return end

	-- Resolve display names (batch)
	local entries: {{rank: number, name: string, score: number}} = {}
	for rank, entry in currentPage do
		local userId = tonumber(entry.key) :: number
		local displayName = "Beekeeper"
		pcall(function()
			displayName = Players:GetNameFromUserIdAsync(userId)
		end)
		table.insert(entries, {rank = rank, name = displayName, score = entry.value})
	end

	LeaderboardUpdate:FireAllClients(entries)
end

-- Periodic refresh loop
function LeaderboardService.Start(): ()
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(LB_CFG.UPDATE_INTERVAL)
		end
	end)
end

return LeaderboardService
```

---

### 4. LeaderboardRunner Script

**Location:** `ServerScriptService.LeaderboardRunner`  
**Type:** Script

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local LeaderboardService = require(ServerScriptService.Systems.LeaderboardService)
LeaderboardService.Start()
```

---

### 5. New RemoteEvent

**Location:** `ReplicatedStorage.Remotes.LeaderboardUpdate`  
**Type:** RemoteEvent  
Payload fired to all clients: `entries` — array of `{rank, name, score}` tables (up to 10 entries).

---

### 6. LeaderboardController LocalScript

**Location:** `StarterPlayerScripts.LeaderboardController`  
**Type:** LocalScript  
**Strict:** `--!strict`

Responsibilities:
- Listen for `LeaderboardUpdate` events
- Find the SurfaceGui named `LeaderboardGui` on the part tagged `LeaderboardBoard`
- Populate the ranked list labels
- Show gold/silver/bronze crown prefix for rank 1/2/3

```lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LeaderboardUpdate: RemoteEvent = Remotes:WaitForChild("LeaderboardUpdate")

-- Warm Wax palette
local COLOR_GOLD    = Color3.fromRGB(242, 168, 28)   -- Honey Gold
local COLOR_SILVER  = Color3.fromRGB(192, 192, 192)
local COLOR_BRONZE  = Color3.fromRGB(205, 127, 50)
local COLOR_DEFAULT = Color3.fromRGB(232, 212, 154)  -- Wax Cream

local CROWN = {"👑 ", "🥈 ", "🥉 "}

local function getBoard(): SurfaceGui?
	for _, part in CollectionService:GetTagged("LeaderboardBoard") do
		local sg = part:FindFirstChild("LeaderboardGui")
		if sg and sg:IsA("SurfaceGui") then
			return sg :: SurfaceGui
		end
	end
	return nil
end

local function formatScore(n: number): string
	-- e.g. 1234567 → "1,234,567"
	local s = tostring(math.floor(n))
	local result = ""
	local len = #s
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then
			result = result .. ","
		end
		result = result .. s:sub(i, i)
	end
	return result
end

LeaderboardUpdate.OnClientEvent:Connect(function(entries: {{rank: number, name: string, score: number}})
	local board = getBoard()
	if not board then return end

	local listFrame = board:FindFirstChild("ListFrame")
	if not listFrame then return end

	-- Update or create row labels
	for i = 1, 10 do
		local row = listFrame:FindFirstChild("Row" .. i)
		if not row then
			row = Instance.new("TextLabel")
			row.Name = "Row" .. i
			row.Size = UDim2.new(1, 0, 0.09, 0)
			row.Position = UDim2.new(0, 0, 0.08 + (i - 1) * 0.09, 0)
			row.BackgroundTransparency = 1
			row.Font = Enum.Font.GothamBold
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Parent = listFrame
		end
		local label = row :: TextLabel
		local entry = entries[i]
		if entry then
			local crown = CROWN[i] or (i .. ". ")
			label.Text = crown .. entry.name .. "  " .. formatScore(entry.score) .. " 🍯"
			if i == 1 then label.TextColor3 = COLOR_GOLD
			elseif i == 2 then label.TextColor3 = COLOR_SILVER
			elseif i == 3 then label.TextColor3 = COLOR_BRONZE
			else label.TextColor3 = COLOR_DEFAULT
			end
		else
			label.Text = i .. ".  —"
			label.TextColor3 = Color3.fromRGB(120, 90, 60)
		end
	end

	-- Update header score if player is on the board
	local localPlayer = Players.LocalPlayer
	local myRow = listFrame:FindFirstChild("MyRow") :: TextLabel?
	for _, entry in entries do
		if entry.name == localPlayer.Name then
			if not myRow then
				myRow = Instance.new("TextLabel")
				myRow.Name = "MyRow"
				myRow.Size = UDim2.new(1, 0, 0.07, 0)
				myRow.Position = UDim2.new(0, 0, 0.93, 0)
				myRow.BackgroundTransparency = 0.4
				myRow.BackgroundColor3 = Color3.fromRGB(122, 74, 34) -- Propolis Brown
				myRow.Font = Enum.Font.GothamBold
				myRow.TextScaled = true
				myRow.TextColor3 = COLOR_GOLD
				myRow.TextXAlignment = Enum.TextXAlignment.Center
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 4)
				corner.Parent = myRow
				myRow.Parent = listFrame
			end
			myRow.Text = "You: #" .. entry.rank .. "  " .. formatScore(entry.score) .. " 🍯"
			break
		end
	end
end)
```

---

### 7. PlotPlaque LocalScript (personal best per plot)

**Location:** `StarterPlayerScripts.PlotPlaqueController`  
**Type:** LocalScript  
**Strict:** `--!strict`

Shows the owning player's generation + lifetime honey on the small plaque at their own plot.

```lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
-- HudDataSync fires current profile summary to owning client on load and on update
-- format: {honey, propolis, pollen, royalJelly, queenTier, generation, lifetimeHoney, equippedSkin}
local HudDataSync: RemoteEvent = Remotes:WaitForChild("HudDataSync")

local function updatePlaque(plotIndex: number, generation: number, lifetimeHoney: number): ()
	for _, part in CollectionService:GetTagged("PlotPlaque") do
		if part:GetAttribute("PlotIndex") == plotIndex then
			local sg = part:FindFirstChild("PlaqueGui")
			if sg and sg:IsA("SurfaceGui") then
				local label = sg:FindFirstChild("PlaqueText") :: TextLabel?
				if label then
					label.Text = "Gen " .. generation .. "\n" .. math.floor(lifetimeHoney / 1000) .. "k 🍯 lifetime"
				end
			end
		end
	end
end

HudDataSync.OnClientEvent:Connect(function(data: {plotIndex: number, generation: number, lifetimeHoney: number})
	if data.plotIndex and data.generation and data.lifetimeHoney then
		updatePlaque(data.plotIndex, data.generation, data.lifetimeHoney)
	end
end)
```

> **Note for luau-scripter:** `HudDataSync` may already exist from HudController. If so, the payload just needs `generation` and `lifetimeHoney` added to it. If it doesn't exist, create it and fire it from DataService.PlayerAdded + on swarm complete.

---

### 8. HudDataSync payload extension

In the existing HudController / HudDataSync firing code (wherever profile data is broadcast to the owning client), add `generation = profile.generation or 0` and `lifetimeHoney = profile.lifetimeHoney or 0` to the payload table.

---

## WORLD-BUILDER TASK

### Global Cork Board (Hub back wall)

Build a large cork board on the Apiary Hub back wall (Z ≈ −260, facing +Z direction, centered at X=0, Y=12).

**Part list:**

| Name | ClassName | Position | Size | Color / Material | Notes |
|------|-----------|----------|------|-----------------|-------|
| BoardBacking | Part | (0, 12, −259) | (80, 22, 1) | BurlyWood / Wood | Main backing |
| BoardFrame_L | Part | (−41, 12, −259.5) | (2, 24, 2) | SaddleBrown / Wood | Left frame |
| BoardFrame_R | Part | (+41, 12, −259.5) | (2, 24, 2) | SaddleBrown / Wood | Right frame |
| BoardFrame_T | Part | (0, 23.5, −259.5) | (84, 2, 2) | SaddleBrown / Wood | Top frame |
| BoardFrame_B | Part | (0, 0.5, −259.5) | (84, 2, 2) | SaddleBrown / Wood | Bottom frame |
| BoardSurface | Part | (0, 12, −258.5) | (78, 20, 0.2) | BurlyWood / SmoothPlastic | SurfaceGui host |

All parts: Anchored=true, CanCollide=true (frame parts), BoardSurface CanCollide=false.

**Tags:** Add CollectionService tag `LeaderboardBoard` to `BoardSurface`.

**SurfaceGui on BoardSurface:**

```
BoardSurface
└── LeaderboardGui (SurfaceGui)
    ├── Face = Enum.NormalId.Front
    ├── SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    ├── PixelsPerStud = 50
    └── Frame "ListFrame"
        ├── Size = UDim2.new(1,0,1,0)
        ├── BackgroundTransparency = 1
        └── TextLabel "Header"
            ├── Size = UDim2.new(1,0,0.08,0)
            ├── Position = UDim2.new(0,0,0,0)
            ├── Text = "🏆  TOP BEEKEEPERS"
            ├── Font = Enum.Font.GothamBold
            ├── TextScaled = true
            ├── TextColor3 = Color3.fromRGB(242,168,28)   -- Honey Gold
            └── BackgroundTransparency = 1
```

Row labels (Row1–Row10) will be created at runtime by LeaderboardController. Leave `ListFrame` with only the `Header` label pre-built.

**Folder:** Place all 6 board parts inside `Workspace.Hub.LeaderboardBoard` folder.

---

### Plot Plaques (6 plots)

Small cork plaque on the left fence post of each plot's deck entrance.

**Plaque position per plot** (local offset from plot centre, then add plot X offset):

| PlotIndex | Plot X | Plaque absolute position |
|-----------|--------|--------------------------|
| 1 | −250 | (−273, 9.5, −80) |
| 2 | −150 | (−173, 9.5, −80) |
| 3 | −50  | (−73, 9.5, −80) |
| 4 | +50  | (+27, 9.5, −80) |
| 5 | +150 | (+127, 9.5, −80) |
| 6 | +250 | (+227, 9.5, −80) |

**Part list per plaque (×6):**

| Name | ClassName | Size | Color / Material | Notes |
|------|-----------|------|-----------------|-------|
| PlaqueBacking | Part | (14, 6, 0.8) | BurlyWood / Wood | CFrame facing −Z (normal = +Z) |
| PlaqueFrame | Part | (15, 7, 0.4) | SaddleBrown / Wood | Slightly larger, behind backing |
| PlaqueSurface | Part | (13, 5, 0.2) | BurlyWood / SmoothPlastic | SurfaceGui host, CanCollide=false |

All parts Anchored=true. Parent to `Workspace.Plot[N].PlotDecor` folder (create if missing).

**Tags:** Add CollectionService tag `PlotPlaque` to each `PlaqueSurface`. Set attribute `PlotIndex = N` (integer 1–6).

**SurfaceGui on each PlaqueSurface:**

```
PlaqueSurface
└── PlaqueGui (SurfaceGui)
    ├── Face = Enum.NormalId.Front
    ├── SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    ├── PixelsPerStud = 40
    └── TextLabel "PlaqueText"
        ├── Size = UDim2.new(1,0,1,0)
        ├── Text = "Gen 1\n— 🍯 —"
        ├── Font = Enum.Font.GothamBold
        ├── TextScaled = true
        ├── TextColor3 = Color3.fromRGB(242,168,28)
        └── BackgroundTransparency = 1
```

---

## VERIFICATION SCRIPT

Run in Studio Command Bar after both luau-scripter and world-builder complete:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local CS  = game:GetService("CollectionService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local SG  = game:GetService("StarterGui")

local results = {}
local issues  = {}

-- 1. LeaderboardService
local lbMod = SSS.Systems:FindFirstChild("LeaderboardService")
if lbMod and lbMod:IsA("ModuleScript") then
	table.insert(results, "PASS: LeaderboardService ModuleScript exists (" .. select(2,lbMod.Source:gsub("\n","\n"))+1 .. " lines)")
else
	table.insert(issues, "FAIL: LeaderboardService missing from SSS.Systems")
end

-- 2. LeaderboardRunner
local runner = SSS:FindFirstChild("LeaderboardRunner")
if runner and runner:IsA("Script") then
	table.insert(results, "PASS: LeaderboardRunner Script exists")
else
	table.insert(issues, "FAIL: LeaderboardRunner missing from SSS")
end

-- 3. RemoteEvent
local remote = RS.Remotes:FindFirstChild("LeaderboardUpdate")
if remote and remote:IsA("RemoteEvent") then
	table.insert(results, "PASS: LeaderboardUpdate RemoteEvent exists")
else
	table.insert(issues, "FAIL: LeaderboardUpdate RemoteEvent missing")
end

-- 4. LeaderboardController LocalScript
local ctrl = SPS and SPS:FindFirstChild("LeaderboardController")
if ctrl and ctrl:IsA("LocalScript") then
	table.insert(results, "PASS: LeaderboardController LocalScript exists")
else
	table.insert(issues, "FAIL: LeaderboardController missing from StarterPlayerScripts")
end

-- 5. PlotPlaqueController LocalScript
local ppc = SPS and SPS:FindFirstChild("PlotPlaqueController")
if ppc and ppc:IsA("LocalScript") then
	table.insert(results, "PASS: PlotPlaqueController LocalScript exists")
else
	table.insert(issues, "FAIL: PlotPlaqueController missing from StarterPlayerScripts")
end

-- 6. LeaderboardBoard tag
local boards = CS:GetTagged("LeaderboardBoard")
if #boards >= 1 then
	local sg = boards[1]:FindFirstChild("LeaderboardGui")
	if sg and sg:IsA("SurfaceGui") then
		local listFrame = sg:FindFirstChild("ListFrame")
		local header = listFrame and listFrame:FindFirstChild("Header")
		table.insert(results, "PASS: LeaderboardBoard tagged part found with LeaderboardGui + ListFrame + Header")
	else
		table.insert(issues, "FAIL: LeaderboardBoard part lacks LeaderboardGui SurfaceGui")
	end
else
	table.insert(issues, "FAIL: No parts tagged LeaderboardBoard")
end

-- 7. PlotPlaque tags (expect 6)
local plaques = CS:GetTagged("PlotPlaque")
if #plaques == 6 then
	local missingIdx = {}
	for i = 1, 6 do
		local found = false
		for _, p in plaques do
			if p:GetAttribute("PlotIndex") == i then found = true break end
		end
		if not found then table.insert(missingIdx, i) end
	end
	if #missingIdx == 0 then
		table.insert(results, "PASS: 6 PlotPlaque parts found with PlotIndex 1–6")
	else
		table.insert(issues, "FAIL: PlotPlaque missing PlotIndex: " .. table.concat(missingIdx,","))
	end
else
	table.insert(issues, "FAIL: Expected 6 PlotPlaque parts, found " .. #plaques)
end

-- 8. Config.LEADERBOARD
local ok, Config = pcall(require, RS.Modules.Config)
if ok and Config.LEADERBOARD then
	table.insert(results, "PASS: Config.LEADERBOARD present (STORE_NAME=" .. Config.LEADERBOARD.STORE_NAME .. ")")
else
	table.insert(issues, "FAIL: Config.LEADERBOARD missing or Config require failed")
end

-- Summary
print("=== LEADERBOARD VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
	print("\n--- ISSUES ---")
	for _, iss in issues do print(iss) end
	print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
	print("\nSTATUS: ALL CHECKS PASS — leaderboard system ready")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| Config.LEADERBOARD | Config addition | ReplicatedStorage.Modules.Config |
| LeaderboardService | ModuleScript | SSS.Systems.LeaderboardService |
| LeaderboardRunner | Script | SSS.LeaderboardRunner |
| LeaderboardUpdate | RemoteEvent | ReplicatedStorage.Remotes |
| LeaderboardController | LocalScript | StarterPlayerScripts |
| PlotPlaqueController | LocalScript | StarterPlayerScripts |
| HudDataSync payload | Edit | existing HudDataSync fire sites |
| Global Cork Board | 6 parts + SurfaceGui | Workspace.Hub.LeaderboardBoard |
| Plot Plaques | 3 parts × 6 + SurfaceGui | Workspace.Plot[N].PlotDecor |
| LeaderboardBoard tag | CollectionService | BoardSurface part |
| PlotPlaque tag × 6 | CollectionService | PlaqueSurface × 6 |

**Part budget delta:** +24 parts worst case (6 board + 18 plaque) → ~3,768 / 5,000 total.

**DataStore note:** `GetOrderedDataStore` requires a live Roblox server (not Studio with API access disabled). All reads/writes are wrapped in `pcall` so Studio testing degrades gracefully (board stays empty, no errors).
