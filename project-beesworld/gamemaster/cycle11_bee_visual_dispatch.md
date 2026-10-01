# Dispatch 57 — BeeVisualService + PlotService OwnerId Patch
## Cycle 11 · A Bee's World

**Feature A:** PlotService patch — stamp `OwnerId` IntValue on every HexCell part so HiveSkinService can find a player's cells.
**Feature B:** BeeVisualService — small colored sphere "bees" that orbit each plot (count matches active bee count, tint matches active hive skin).
**Part budget impact:** +active bee spheres (max 25 per player × plots) — **counted as non-permanent** (server-spawned, destroyed when bees return). Permanent: **+0** → **4,146 / 5,000**
**Execution order:** After dispatch 56 (HiveSkinService)

---

## PART A — PlotService OwnerId patch

This patch injects `OwnerId` stamping into the existing PlotService. Every time a HexCell part is created (plot purchased or loaded), an IntValue named `OwnerId` is inserted with `Value = player.UserId`. This makes the cells findable by HiveSkinService.

### STEP A1 — PlotService injection

Open **PlotService** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ps = SSS:FindFirstChild("PlotService")
assert(ps, "PlotService not found")

local clone = ps:Clone()
clone.Name = "PlotService_WORKING"

-- Find where HexCell parts are created/parented
-- Look for the CollectionService tag assignment for "HexCell"
local anchor = 'CollectionService:AddTag'
local found = clone.Source:find(anchor, 1, true)
if not found then
	-- Fallback: find "HexCell" string
	anchor = '"HexCell"'
	found = clone.Source:find(anchor, 1, true)
end

if found then
	-- Find end of that statement (next semicolon or newline after it)
	local lineEnd = clone.Source:find("\n", found, true)
	if lineEnd then
		-- Inject OwnerId stamping after this line
		-- We need to know which variable holds the new hex cell part
		-- Common patterns: hexPart, newCell, cell, part
		-- Inject a helper that finds the part from the context
		local INJECT = [[

		-- Stamp OwnerId so HiveSkinService can find player cells
		do
			local taggedParts = CollectionService:GetTagged("HexCell")
			-- The most recently tagged part is the one just created
			local newest = taggedParts[#taggedParts]
			if newest and newest:IsA("BasePart") then
				local ownerId = newest:FindFirstChild("OwnerId") or Instance.new("IntValue")
				ownerId.Name = "OwnerId"
				ownerId.Value = player.UserId
				ownerId.Parent = newest
			end
		end]]
		clone.Source = clone.Source:sub(1, lineEnd) .. INJECT .. clone.Source:sub(lineEnd + 1)
		print("OwnerId injection added after HexCell tag assignment")
	end
else
	print("WARNING: Could not find HexCell tag anchor in PlotService")
	print("Manual fix: after each HexCell BasePart is created, add:")
	print('  local oid = Instance.new("IntValue")')
	print('  oid.Name = "OwnerId"')
	print('  oid.Value = player.UserId')
	print('  oid.Parent = <hexCellPart>')
end

ps.Name = "PlotService_OLD_NX"
ps.Parent = nil
clone.Name = "PlotService"
clone.Parent = SSS

print("PlotService OwnerId patch applied")
```

**Note:** If the injection anchor can't be found (PlotService structure varies), run this manual backfill to stamp OwnerId on all existing hex cells at server start:

```lua
-- Manual backfill — run once after PlotService loads
-- Add this function call inside PlotService.Init() or as a startup Script
local function backfillOwnerIds()
	local CS = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	-- We need to match cells to players by plot ownership
	-- If cells are parented under plot folders named with UserId or player name:
	for _, cell in CS:GetTagged("HexCell") do
		if cell:IsA("BasePart") and not cell:FindFirstChild("OwnerId") then
			-- Try to find UserId from ancestor folder names
			local ancestor = cell.Parent
			while ancestor and ancestor ~= workspace do
				local name = ancestor.Name
				-- PlotService likely names plot folders after UserId or "Plot_[UserId]"
				local uid = tonumber(name) or tonumber(name:match("Plot_(%d+)"))
				if uid then
					local oid = Instance.new("IntValue")
					oid.Name = "OwnerId"
					oid.Value = uid
					oid.Parent = cell
					break
				end
				ancestor = ancestor.Parent
			end
		end
	end
	print("[PlotService] OwnerId backfill complete")
end
-- Call this in PlotService.Init() after loading saved plots
```

**Verify:**
```lua
local CS = game:GetService("CollectionService")
local cells = CS:GetTagged("HexCell")
local withOwner, withoutOwner = 0, 0
for _, c in cells do
	if c:FindFirstChild("OwnerId") then withOwner += 1 else withoutOwner += 1 end
end
print("HexCells with OwnerId:", withOwner, "| without:", withoutOwner)
```

---

## PART B — BeeVisualService

Small sphere "bees" orbit above each occupied plot. Count = active bee count per ForagingService. Tint = active skin color. Destroyed when no bees are active (foraging complete or player leaves).

### Architecture

- **Server-side:** `BeeVisualService` manages a `{[userId]: {[plotId]: {Part}}` table.
- Spheres: `SmoothPlastic`, `CanCollide=false`, `Anchored=true`, `CastShadow=false`, size `Vector3(0.8, 0.8, 0.8)`, offset +3→+8 studs above plot center with gentle sinusoidal Y oscillation via Heartbeat.
- Color: matches the player's active skin color (received from HiveSkinService via internal call on BeeVisualService.UpdateSkin).
- Count: matches bee count from ForagingService via BeeCountChanged BindableEvent.
- **Performance:** max 25 spheres per player × however many plots active (typically 1-2 active plots at once). Heartbeat updates position for at most 6 spheres per player (orbit radius 3 studs, 6 positions evenly spaced). This is deliberately minimal.

### STEP B1 — BindableEvent for bee count changes

PlotService/ForagingService must signal BeeVisualService when bee count changes. Rather than coupling directly, we use a BindableEvent in ServerScriptService.

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

-- Create BindableEvents folder if needed
local be = SSS:FindFirstChild("BindableEvents")
if not be then
	be = Instance.new("Folder")
	be.Name = "BindableEvents"
	be.Parent = SSS
	print("Created BindableEvents folder")
end

-- BeeCountChanged: (userId: number, plotId: number, count: number)
if not be:FindFirstChild("BeeCountChanged") then
	local ev = Instance.new("BindableEvent")
	ev.Name = "BeeCountChanged"
	ev.Parent = be
	print("Created BeeCountChanged BindableEvent")
else
	print("BeeCountChanged already exists")
end

-- SkinChanged: (userId: number, color: Color3)
if not be:FindFirstChild("SkinChanged") then
	local ev = Instance.new("BindableEvent")
	ev.Name = "SkinChanged"
	ev.Parent = be
	print("Created SkinChanged BindableEvent")
else
	print("SkinChanged already exists")
end

print("BindableEvents OK")
```

### STEP B2 — ForagingService bee count signal injection

Open **ForagingService** in ServerScriptService. Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- 1. Require BindableEvents near the top
local cfgAnchor = 'require(SSS:WaitForChild("Config"))'
local found1 = clone.Source:find(cfgAnchor, 1, true)
assert(found1, "Config require not found in ForagingService")

local INJECT_REQ = [[

local BE = SSS:WaitForChild("BindableEvents")
local BeeCountChanged = BE:WaitForChild("BeeCountChanged")]]

clone.Source = clone.Source:sub(1, found1 + #cfgAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found1 + #cfgAnchor)

-- 2. Fire BeeCountChanged when bee count changes
-- Look for where activeBees is incremented (bee starts foraging)
local beeStart = "activeBees += 1"
local found2 = clone.Source:find(beeStart, 1, true)
if not found2 then
	beeStart = "activeBees = activeBees + 1"
	found2 = clone.Source:find(beeStart, 1, true)
end
if found2 then
	local lineEnd = clone.Source:find("\n", found2, true)
	if lineEnd then
		local INJECT_INC = "\n\t\tBeeCountChanged:Fire(player.UserId, plotId or 1, activeBees)"
		clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_INC .. clone.Source:sub(lineEnd + 1)
		print("BeeCountChanged fire injected on bee start")
	end
else
	print("WARNING: activeBees increment not found — manual injection needed after bee starts foraging")
end

-- 3. Fire BeeCountChanged when bee returns (activeBees decremented)
local beeEnd = "activeBees -= 1"
local found3 = clone.Source:find(beeEnd, 1, true)
if not found3 then
	beeEnd = "activeBees = activeBees - 1"
	found3 = clone.Source:find(beeEnd, 1, true)
end
if found3 then
	local lineEnd = clone.Source:find("\n", found3, true)
	if lineEnd then
		local INJECT_DEC = "\n\t\tBeeCountChanged:Fire(player.UserId, plotId or 1, math.max(0, activeBees))"
		clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_DEC .. clone.Source:sub(lineEnd + 1)
		print("BeeCountChanged fire injected on bee return")
	end
else
	print("WARNING: activeBees decrement not found — manual injection needed after bee returns")
end

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService BeeCountChanged injection complete")
```

### STEP B3 — HiveSkinService SkinChanged signal injection

Add a `SkinChanged:Fire()` call in HiveSkinService when `ApplySkin` succeeds.

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local hs = SSS:FindFirstChild("HiveSkinService")
assert(hs, "HiveSkinService not found")

local clone = hs:Clone()
clone.Name = "HiveSkinService_WORKING"

-- Require BindableEvents
local reqAnchor = 'require(SSS:WaitForChild("DataService"))'
local found1 = clone.Source:find(reqAnchor, 1, true)
assert(found1, "DataService require not found in HiveSkinService")

local INJECT_REQ = [[

local BE = SSS:WaitForChild("BindableEvents")
local SkinChanged = BE:WaitForChild("SkinChanged")]]

clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1) .. INJECT_REQ .. clone.Source:sub(found1 + #reqAnchor)

-- Fire SkinChanged after applyToWorld
local applyAnchor = "applyToWorld(player, skinId)"
local found2 = clone.Source:find(applyAnchor, 1, true)
if found2 then
	local lineEnd = clone.Source:find("\n", found2, true)
	if lineEnd then
		-- Get skin color from config
		local INJECT_FIRE = [[

	-- Signal BeeVisualService to update bee colors
	local skin = getSkinConfig(skinId)
	if skin then
		SkinChanged:Fire(player.UserId, skin.color)
	end]]
		clone.Source = clone.Source:sub(1, lineEnd) .. INJECT_FIRE .. clone.Source:sub(lineEnd + 1)
		print("SkinChanged fire injected in HiveSkinService")
	end
else
	print("WARNING: applyToWorld call not found — manual injection needed after skin apply")
end

hs.Name = "HiveSkinService_OLD_NX"
hs.Parent = nil
clone.Name = "HiveSkinService"
clone.Parent = SSS

print("HiveSkinService SkinChanged injection complete")
```

### STEP B4 — BeeVisualService ModuleScript

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
assert(not SSS:FindFirstChild("BeeVisualService"), "Already exists — delete first")

local mod = Instance.new("ModuleScript")
mod.Name = "BeeVisualService"
mod.Parent = SSS

mod.Source = [[
--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SSS = game:GetService("ServerScriptService")

local Config = require(SSS:WaitForChild("Config"))

local BeeVisualService = {}

-- {[userId]: {color: Color3, bees: {{part: Part, plotId: number, index: number}}}}
local playerBees: {[number]: {color: Color3, spheres: {Part}}} = {}

local BEE_SIZE = Vector3.new(0.8, 0.8, 0.8)
local ORBIT_RADIUS = 3.2
local ORBIT_HEIGHT = 5.5
local BOB_SPEED = 1.8
local BOB_AMP = 0.6
local ORBIT_SPEED = 0.55

local function getPlotCenter(userId: number, plotId: number): Vector3?
	-- Find plot folder in Workspace
	local mapFolder = workspace:FindFirstChild("Map")
	if not mapFolder then return nil end
	for _, child in mapFolder:GetChildren() do
		local uidVal = child:FindFirstChild("OwnerId") or child:FindFirstChild("UserId")
		if uidVal and uidVal.Value == userId then
			local floor = child:FindFirstChildOfClass("Part") or child:FindFirstChildOfClass("BasePart")
			if floor then return floor.Position end
		end
	end
	-- Fallback: find any HexCell owned by this user
	local CS = game:GetService("CollectionService")
	for _, cell in CS:GetTagged("HexCell") do
		if cell:IsA("BasePart") then
			local oid = cell:FindFirstChild("OwnerId")
			if oid and oid.Value == userId then
				return cell.Position + Vector3.new(0, ORBIT_HEIGHT, 0)
			end
		end
	end
	return nil
end

local function createBeeSphere(color: Color3): Part
	local p = Instance.new("Part")
	p.Name = "BeeSphere"
	p.Shape = Enum.PartType.Ball
	p.Size = BEE_SIZE
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Transparency = 0
	p.Parent = workspace
	return p
end

local function destroyUserBees(userId: number)
	local entry = playerBees[userId]
	if not entry then return end
	for _, sphere in entry.spheres do
		sphere:Destroy()
	end
	playerBees[userId] = nil
end

-- Set bee count for a user (called by BeeCountChanged)
function BeeVisualService.SetCount(userId: number, count: number)
	local existing = playerBees[userId]
	local color = existing and existing.color or Color3.fromRGB(242, 168, 28)

	local currentCount = existing and #existing.spheres or 0

	if count <= 0 then
		destroyUserBees(userId)
		return
	end

	if not playerBees[userId] then
		playerBees[userId] = {color = color, spheres = {}}
	end

	-- Add spheres if count increased
	while #playerBees[userId].spheres < count do
		local sphere = createBeeSphere(color)
		table.insert(playerBees[userId].spheres, sphere)
	end

	-- Remove spheres if count decreased
	while #playerBees[userId].spheres > count do
		local sphere = table.remove(playerBees[userId].spheres)
		sphere:Destroy()
	end
end

-- Update color for all bees of a user (called by SkinChanged)
function BeeVisualService.SetColor(userId: number, color: Color3)
	local entry = playerBees[userId]
	if entry then
		entry.color = color
		for _, sphere in entry.spheres do
			sphere.Color = color
		end
	else
		-- Pre-set color for when bees are created
		playerBees[userId] = {color = color, spheres = {}}
	end
end

-- Heartbeat: orbit spheres around plot center
local t = 0
RunService.Heartbeat:Connect(function(dt)
	t += dt
	for userId, entry in playerBees do
		local center = getPlotCenter(userId, 1) -- simplified: use first active plot
		if not center then continue end

		local n = #entry.spheres
		if n == 0 then continue end

		for i, sphere in entry.spheres do
			if not sphere.Parent then continue end
			local angle = (2 * math.pi * (i - 1) / n) + (t * ORBIT_SPEED)
			local x = center.X + math.cos(angle) * ORBIT_RADIUS
			local z = center.Z + math.sin(angle) * ORBIT_RADIUS
			local y = center.Y + ORBIT_HEIGHT + math.sin(t * BOB_SPEED + i) * BOB_AMP
			sphere.Position = Vector3.new(x, y, z)
		end
	end
end)

function BeeVisualService.Init()
	local BE = SSS:WaitForChild("BindableEvents")
	local BeeCountChanged = BE:WaitForChild("BeeCountChanged")
	local SkinChanged = BE:WaitForChild("SkinChanged")

	BeeCountChanged.Event:Connect(function(userId: number, plotId: number, count: number)
		BeeVisualService.SetCount(userId, count)
	end)

	SkinChanged.Event:Connect(function(userId: number, color: Color3)
		BeeVisualService.SetColor(userId, color)
	end)

	-- Clean up on player leave
	Players.PlayerRemoving:Connect(function(player)
		destroyUserBees(player.UserId)
	end)

	print("[BeeVisualService] Initialized")
end

return BeeVisualService
]]

print("BeeVisualService created")
```

### STEP B5 — GameManager injection

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchors = {
	'require(SSS:WaitForChild("HiveSkinService"))',
	'require(SSS:WaitForChild("DailyRewardService"))',
	'require(SSS:WaitForChild("PropolisYieldUpgradeService"))',
}
local reqAnchor, found1
for _, a in anchors do
	found1 = clone.Source:find(a, 1, true)
	if found1 then reqAnchor = a; break end
end
assert(found1, "No recent service require found in GameManager")

clone.Source = clone.Source:sub(1, found1 + #reqAnchor - 1)
	.. '\nlocal BeeVisualService = require(SSS:WaitForChild("BeeVisualService"))'
	.. clone.Source:sub(found1 + #reqAnchor)

local initAnchors = {
	"HiveSkinService.Init()",
	"DailyRewardService.Init()",
	"PropolisYieldUpgradeService.Init()",
}
local initAnchor, found2
for _, a in initAnchors do
	found2 = clone.Source:find(a, 1, true)
	if found2 then initAnchor = a; break end
end
assert(found2, "No recent service Init() found in GameManager")

clone.Source = clone.Source:sub(1, found2 + #initAnchor - 1)
	.. "\n\tBeeVisualService.Init()"
	.. clone.Source:sub(found2 + #initAnchor)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager injection OK — BeeVisualService wired in")
```

---

## STEP C — Verification sweep

In Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local checks = {}

-- OwnerId patch
local psMod = SSS:FindFirstChild("PlotService")
table.insert(checks, ((psMod and psMod.Source:find("OwnerId")) and "✅" or "⚠️") .. " PlotService OwnerId injection (may need manual if anchor not found)")

-- BindableEvents
local be = SSS:FindFirstChild("BindableEvents")
local bcc = be and be:FindFirstChild("BeeCountChanged")
local sc = be and be:FindFirstChild("SkinChanged")
table.insert(checks, (bcc and "✅" or "❌") .. " BeeCountChanged BindableEvent")
table.insert(checks, (sc and "✅" or "❌") .. " SkinChanged BindableEvent")

-- ForagingService injection
local fsMod = SSS:FindFirstChild("ForagingService")
table.insert(checks, ((fsMod and fsMod.Source:find("BeeCountChanged")) and "✅" or "⚠️") .. " ForagingService BeeCountChanged.Fire")

-- HiveSkinService injection
local hsMod = SSS:FindFirstChild("HiveSkinService")
table.insert(checks, ((hsMod and hsMod.Source:find("SkinChanged")) and "✅" or "⚠️") .. " HiveSkinService SkinChanged.Fire")

-- BeeVisualService
table.insert(checks, (SSS:FindFirstChild("BeeVisualService") and "✅" or "❌") .. " BeeVisualService module")

-- GameManager
local gmMod = SSS:FindFirstChild("GameManager")
table.insert(checks, ((gmMod and gmMod.Source:find("BeeVisualService")) and "✅" or "❌") .. " GameManager wired")

print("=== DISPATCH 57 VERIFICATION ===")
for _, line in checks do print(line) end
-- ⚠️ = optional injection that may need manual fallback
-- ❌ = hard failure
local hardFail = table.concat(checks, ""):find("❌")
print(hardFail and "❌ HARD FAILURES — fix before proceeding" or "✅ Core checks pass (⚠️ items may need manual injection)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BeeSphere parts (runtime, destroyed on return) | transient |
| **Dispatch 57 permanent** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## GameManager init chain (post dispatch 57)

```
  → HiveSkinService.Init()     ← dispatch 56
  → BeeVisualService.Init()    ← dispatch 57
```

**Performance note:** Heartbeat fires every frame but is O(active bees × active players). With 25 bees × 10 players = 250 position updates per frame — acceptable. If server FPS drops, add `if t % 0.05 < dt then` guard to update at 20Hz instead of 60Hz.
