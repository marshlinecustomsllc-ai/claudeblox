# Cycle 10 — QueenService Build Dispatch
## A Bee's World — Studio Execution Guide

**Priority:** HIGH (pending_fix #8)
**Part delta:** +0 server parts (queens are client-only; templates in ReplicatedStorage cost 0)
**Running total:** ~4,020 / 5,000
**DataService migration:** v11 → v12 (royalJellyProgress field + queenTier normalisation)
**Prerequisites:**
- pending_fix #9 MUST be resolved first: run `fix_bug9_duplicate_dataservice.lua` in the Studio Command Bar
- All cycle 8 and cycle 9 dispatches must be executed first (DataService must be at v11)

**Execution environment:** Edit mode, `RunService:IsRunning() == false`. Re-read every script before editing it.

---

## EXECUTION ORDER

```
STEP A  Config patch               (Command Bar)
STEP B  DataService MIGRATIONS[3]  (Command Bar)
STEP C  ResourceService patch      (Command Bar)
STEP D  QueenService new module    (Command Bar)
STEP E  Main wiring                (Command Bar)
STEP F  Queen templates            (Command Bar)
STEP G  HiveGui QUEEN page         (Command Bar)
STEP H  HiveController patch       (Command Bar)
STEP I  QueenController new module (Command Bar)
STEP J  ClientMain wiring          (Command Bar)
STEP K  Text fixes                 (Command Bar)
STEP L  Verification               (Command Bar)
```

---

## STEP A — Config patch

Patch `ReplicatedStorage.Modules.Config` using the require()-cache-busting clone technique.

```lua
-- STEP A: Config patch — QUEEN_TIERS genGate, Config.QUEEN block, PROFILE_TEMPLATE
local RS = game:GetService("ReplicatedStorage")
local Modules = RS:WaitForChild("Modules")
local orig = Modules:WaitForChild("Config")

-- 1. Clone, swap names, nil parent the original
local clone = orig:Clone()
local backupName = "Config_BACKUP_" .. tick()
orig.Name = backupName
orig.Parent = nil
clone.Name = "Config"
clone.Parent = Modules

-- 2. Read current source
local src = clone.Source

-- 2a. Add genGate to QUEEN_TIERS tier 5 entry.
-- Find the Sun Queen row and add genGate = 1 if not already present.
if not src:find("genGate") then
	src = src:gsub(
		'{ rj = 250, layInterval = 1%.8, outputMult = 2%.00, name = "Sun Queen", unlocksFloor3 = true }',
		'{ rj = 250, layInterval = 1.8, outputMult = 2.00, name = "Sun Queen", unlocksFloor3 = true, genGate = 1 }'
	)
	-- Fallback: try without the trailing space before }
	if not src:find("genGate") then
		src = src:gsub(
			'unlocksFloor3 = true }',
			'unlocksFloor3 = true, genGate = 1 }'
		)
	end
end

-- 2b. Insert Config.QUEEN block after Config.QUEEN_TIERS closing brace.
-- Find the end of the QUEEN_TIERS table and insert the new block after it.
if not src:find("Config%.QUEEN%s*=") then
	local queenBlock = [[

-- ============================================================
-- QUEEN (QueenService server + QueenController client)
-- ============================================================
Config.QUEEN = {
	-- Server
	upgradeRatePerSecond = 1,
	royalJellyNurseMinCount = 1,

	-- Client placement
	walkFloor = 1,
	latticeZOffset = 6,
	walkHeightAboveFloorY = 4.1,
	flashHeightAboveFloorY = 1.1,
	renderRadiusStuds = 250,
	lodCheckSeconds = 1.0,
	cellFlashSeconds = 0.6,
	cellFlashStartTransparency = 0.45,
	rippleDelaySeconds = 0.3,
	rippleStaggerSeconds = 0.08,
	layDipStuds = 0.4,
	layDipSeconds = 0.3,

	-- QueenGrowth moment (Signature Moment 4)
	growth = {
		dimSeconds = 0.5,
		dimTo = 0.3,
		growSeconds = 1.2,
		burstCount = 40,
		relightPeak = 1.15,
		relightSeconds = 0.4,
		settleSeconds = 1.5,
		holdSeconds = 1.0,
	},
	camera = {
		maxDistanceStuds = 150,
		backStuds = 26,
		upStuds = 14,
		inSeconds = 0.6,
		outSeconds = 0.6,
	},

	-- Per-tier look + gait. bodyLength is the authoring contract for
	-- ReplicatedStorage.Templates.Queens.Queen_T<n> models.
	VISUALS = {
		{ template = "Queen_T1", bodyLength = 5.0,  walkSpeed = 6.0, pauseSeconds = 1.0, attendants = 0, orbitRadius = 0,   ripple = false },
		{ template = "Queen_T2", bodyLength = 5.5,  walkSpeed = 5.0, pauseSeconds = 1.5, attendants = 0, orbitRadius = 0,   ripple = false },
		{ template = "Queen_T3", bodyLength = 6.0,  walkSpeed = 3.5, pauseSeconds = 2.0, attendants = 0, orbitRadius = 0,   ripple = false },
		{ template = "Queen_T4", bodyLength = 9.0,  walkSpeed = 3.0, pauseSeconds = 2.0, attendants = 2, orbitRadius = 4.5, ripple = false },
		{ template = "Queen_T5", bodyLength = 12.5, walkSpeed = 2.5, pauseSeconds = 2.5, attendants = 2, orbitRadius = 7.0, ripple = true  },
	},
	attendantOrbitRadPerSec = 2.4,
	attendantHeight = 2.5,
}
]]
	-- Insert after the QUEEN_TIERS closing line
	src = src:gsub("(Config%.QUEEN_TIERS%s*=%s*%{.-\n%})", function(match)
		return match .. queenBlock
	end)
	-- If that pattern didn't match, append before the return at the end
	if not src:find("Config%.QUEEN%s*=") then
		src = src:gsub("(return Config)", queenBlock .. "\nreturn Config")
	end
end

-- 2c. Bump PROFILE_TEMPLATE version from 3 to 4 and add royalJellyProgress
-- (only if we're at v3 — if already bumped, skip)
if src:find("version%s*=%s*3") and not src:find("royalJellyProgress") then
	src = src:gsub("version%s*=%s*3", "version = 4")
	src = src:gsub(
		"(royalJelly%s*=%s*0,)",
		"%1\n\t\troyalJellyProgress = 0, -- fractional RJ accumulator, always in [0,1)"
	)
end

clone.Source = src
print("STEP A complete — Config patched. QUEEN_TIERS genGate:", src:find("genGate") ~= nil, "Config.QUEEN:", src:find("Config%.QUEEN%s*=") ~= nil, "v4:", src:find("version%s*=%s*4") ~= nil, "royalJellyProgress:", src:find("royalJellyProgress") ~= nil)
```

---

## STEP B — DataService MIGRATIONS[3]

```lua
-- STEP B: DataService MIGRATIONS[3] — v11 -> v12 (note: actual migration index = 3
-- counting from DataService's own numbering, which may be 0-based; find the last
-- MIGRATIONS[N] = function entry and insert one with the next index)
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local orig = Systems:WaitForChild("DataService")

local clone = orig:Clone()
local backupName = "DataService_BACKUP_" .. tick()
orig.Name = backupName
orig.Parent = nil
clone.Name = "DataService"
clone.Parent = Systems

local src = clone.Source

-- Find the highest existing MIGRATIONS[N] index
local lastIdx = 0
for n in src:gmatch("MIGRATIONS%[(%d+)%]%s*=") do
	local v = tonumber(n)
	if v and v > lastIdx then lastIdx = v end
end
local newIdx = lastIdx + 1

local migrationCode = string.format([[

-- v%d -> v%d (Queen system -- royalJellyProgress accumulator + queenTier clamp)
MIGRATIONS[%d] = function(profile)
	profile.royalJellyProgress = profile.royalJellyProgress or 0
	local tier = math.floor(tonumber(profile.queenTier) or 1)
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Config"))
	profile.queenTier = math.clamp(tier, 1, #Config.QUEEN_TIERS)
	profile.royalJelly = math.floor(tonumber(profile.royalJelly) or 0)
	profile.version = %d
end
]], newIdx - 1, newIdx, newIdx, newIdx)

-- Insert before the last line (usually "return DataService")
src = src:gsub("(return DataService)", migrationCode .. "\n%1")

-- Also bump CURRENT_VERSION
src = src:gsub("CURRENT_VERSION%s*=%s*(%d+)", function(v)
	return "CURRENT_VERSION = " .. (tonumber(v) + 1)
end)

clone.Source = src
print("STEP B complete — DataService migrations updated. New migration index:", newIdx, "CURRENT_VERSION bumped.")
```

---

## STEP C — ResourceService: Royal Jelly production

```lua
-- STEP C: ResourceService patch — add computeRoyalJellyPerSecond + _tickPlayer step 4b
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local orig = Systems:WaitForChild("ResourceService")

local clone = orig:Clone()
orig.Name = "ResourceService_BACKUP_" .. tick()
orig.Parent = nil
clone.Name = "ResourceService"
clone.Parent = Systems

local src = clone.Source

-- 1. Add HexGrid require (if not already present)
if not src:find("HexGrid") then
	src = src:gsub(
		"(local Config%s*=%s*require%b())",
		"%1\nlocal HexGrid = require(Modules:WaitForChild(\"HexGrid\"))"
	)
	if not src:find("HexGrid") then
		-- Fallback: add after the first require block
		src = src:gsub("(local Formulas%s*=%s*require%b())", "%1\nlocal HexGrid = require(Modules:WaitForChild(\"HexGrid\"))")
	end
end

-- 2. Add computeRoyalJellyPerSecond function before _tickPlayer
local rjFunc = [[

-- ============================================================
-- ROYAL JELLY RATE (0.004/s per adjacent Brood cell, x1.4 with nurses)
-- ============================================================
local function computeRoyalJellyPerSecond(profile: any): number
	local rate = 0
	local perBrood = Config.CELLS.Royal.royalJellyRatePerAdjacentBrood
	if not perBrood or perBrood <= 0 then return 0 end
	for floor = 1, 3 do
		local floorComb = profile.comb and profile.comb[floor]
		if floorComb then
			for key, cellData in floorComb do
				if cellData.t == "Royal" then
					local q, r = HexGrid.FromKey(key)
					local brood = 0
					for _, n in HexGrid.Neighbours(q, r) do
						local nData = floorComb[HexGrid.Key(n.q, n.r)]
						if nData and nData.t == "Brood" then
							brood += 1
						end
					end
					rate += perBrood * brood * (Formulas.CellOutputMult and Formulas.CellOutputMult(cellData.lvl or 1) or 1)
				end
			end
		end
	end
	local nurses = (profile.population and profile.population.nurse) or 0
	if rate > 0 and nurses >= (Config.QUEEN and Config.QUEEN.royalJellyNurseMinCount or 1) then
		local bonus = Config.CASTES and Config.CASTES.nurse and Config.CASTES.nurse.royalCellBonus or 0.4
		rate *= (1 + bonus)
	end
	return rate
end
ResourceService._computeRoyalJellyPerSecond = computeRoyalJellyPerSecond
]]

if not src:find("computeRoyalJellyPerSecond") then
	-- Insert before the _tickPlayer function
	src = src:gsub("(local function _tickPlayer)", rjFunc .. "\n%1")
	if not src:find("computeRoyalJellyPerSecond") then
		-- Fallback: insert before "function ResourceService._tickPlayer"
		src = src:gsub("(function ResourceService%._tickPlayer)", rjFunc .. "\n%1")
	end
end

-- 3. Add step 4b inside _tickPlayer after PopulationService.HatchTick
-- Find a good insertion point: after HatchTick call
local rjStep = [[
		-- 4b. Royal Jelly (fractional accumulator -> integer wallet)
		local royalJellyRate = computeRoyalJellyPerSecond(profile)
		if royalJellyRate > 0 then
			local progress = (profile.royalJellyProgress or 0) + royalJellyRate * dt
			local whole = math.floor(progress)
			if whole > 0 then
				profile.royalJelly = (profile.royalJelly or 0) + whole
				progress -= whole
			end
			profile.royalJellyProgress = progress
		end
]]

if not src:find("royalJellyRate") then
	-- Try to insert after HatchTick line
	local inserted = false
	src = src:gsub("(HatchTick%b().-\n)", function(match)
		if not inserted then
			inserted = true
			return match .. rjStep
		end
		return match
	end)
	if not inserted then
		-- Fallback: insert before "public stats" or PushPublicStats
		src = src:gsub("(PushPublicStats)", rjStep .. "\t\t%1")
	end
end

-- 4. Add royalJellyPerMin and generation to RatesUpdate payload (additive)
if not src:find("royalJellyPerMin") then
	-- Find the RatesUpdate FireClient call and add fields to the payload table
	src = src:gsub(
		"(queenTier%s*=%s*[^\n,}]+)",
		"%1,\n\t\t\t\troyalJellyPerMin = computeRoyalJellyPerSecond(profile) * 60,\n\t\t\t\troyalJellyProgress = profile.royalJellyProgress or 0,\n\t\t\t\tgeneration = profile.generation or 0"
	)
end

clone.Source = src
print("STEP C complete — ResourceService patched. RJ function:", src:find("computeRoyalJellyPerSecond") ~= nil, "Step 4b:", src:find("royalJellyRate") ~= nil, "RatesUpdate fields:", src:find("royalJellyPerMin") ~= nil)
```

---

## STEP D — QueenService (new ModuleScript)

```lua
-- STEP D: Create QueenService in ServerScriptService.Systems
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")

-- Remove any old version
local old = Systems:FindFirstChild("QueenService")
if old then old:Destroy() end

local qs = Instance.new("ModuleScript")
qs.Name = "QueenService"
qs.Parent = Systems
qs.Source = [[
--!strict
-- QueenService: server authority for queen tier upgrades.
-- The server never moves the queen; rendering is done by QueenController (client-only).
-- Remote contract: RequestQueenUpgrade {} C->S, rate 1/s.
-- Success fires Moment "QueenGrowth" FireAllClients.

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Modules = RS:WaitForChild("Modules")
local Systems = SSS:WaitForChild("Systems")

local Config = require(Modules:WaitForChild("Config"))
local DataService = require(Systems:WaitForChild("DataService"))
local PlotService = require(Systems:WaitForChild("PlotService"))
local Validator = require(Modules:WaitForChild("Validator"))

local QueenService = {}
local initialized = false

-- ============================================================
-- Remote helper (same idiom as PopulationService / StructureService)
-- ============================================================
local function getOrCreateRemotesFolder()
	local remotes = RS:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = RS
	end
	return remotes
end

local function getOrCreateRemote(name: string): RemoteEvent
	local folder = getOrCreateRemotesFolder()
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r :: RemoteEvent
end

QueenService._getRemote = getOrCreateRemote

-- ============================================================
-- Public API
-- ============================================================

function QueenService.GetTier(profile: any): number
	return math.clamp(math.floor(tonumber(profile.queenTier) or 1), 1, #Config.QUEEN_TIERS)
end

function QueenService.HasUnlock(profile: any, flag: string): boolean
	local tier = QueenService.GetTier(profile)
	for i = 1, tier do
		local row = Config.QUEEN_TIERS[i]
		if row and (row :: any)[flag] == true then
			return true
		end
	end
	return false
end

function QueenService.GetNextTier(profile: any): (number?, any?)
	local cur = QueenService.GetTier(profile)
	local next = cur + 1
	local row = Config.QUEEN_TIERS[next]
	if row then
		return next, row
	end
	return nil, nil
end

function QueenService.CanUpgrade(player: Player): (boolean, string?, number?)
	local profile = DataService.Get(player)
	if not profile then
		return false, "Your hive is still loading", nil
	end
	local nextIdx, nextRow = QueenService.GetNextTier(profile)
	if not nextIdx or not nextRow then
		local maxName = Config.QUEEN_TIERS[#Config.QUEEN_TIERS].name
		return false, "Your queen is already the " .. maxName .. "!", nil
	end
	local nr = nextRow :: any
	if nr.genGate and (profile.generation or 0) < nr.genGate then
		return false, string.format("The %s needs Generation %d -- that comes from Swarming", nr.name, nr.genGate), nil
	end
	local rj = math.floor(profile.royalJelly or 0)
	if rj < nr.rj then
		return false, string.format("Not enough Royal Jelly (%d needed, you have %d)", nr.rj, rj), nil
	end
	return true, nil, nr.rj
end

function QueenService.Upgrade(player: Player): (boolean, string?)
	local ok, reason, cost = QueenService.CanUpgrade(player)
	if not ok then return false, reason end

	local profile = DataService.Get(player) :: any
	local fromTier = QueenService.GetTier(profile)
	local toTier = fromTier + 1
	local row = Config.QUEEN_TIERS[toTier] :: any

	profile.royalJelly = (profile.royalJelly or 0) - (cost :: number)
	profile.queenTier = toTier

	-- Push public attribute immediately (don't wait for ResourceService tick)
	local plotRoot = PlotService.GetPlotForPlayer and PlotService.GetPlotForPlayer(player)
	local plotIndex = plotRoot and plotRoot:GetAttribute("PlotIndex")
	if typeof(plotIndex) == "number" then
		pcall(PlotService.PushPublicStats, plotIndex)
	end

	-- Owner toast
	pcall(function()
		getOrCreateRemote("Notify"):FireClient(player, {
			kind = "purchase",
			text = string.format("Your queen is now the %s!", row.name)
		})
	end)
	if row.unlocksNurse then
		pcall(function()
			getOrCreateRemote("Notify"):FireClient(player, {
				kind = "info",
				text = "Nurse bees unlocked! Open HIVE > CASTES to add nurses."
			})
		end)
	end

	-- Signature Moment 4 — broadcast to all clients
	if typeof(plotIndex) == "number" then
		pcall(function()
			getOrCreateRemote("Moment"):FireAllClients({
				id = "QueenGrowth",
				plotIndex = plotIndex,
				payload = { fromTier = fromTier, toTier = toTier, ownerUserId = player.UserId },
			})
		end)
	end

	task.spawn(function()
		DataService.Save(player)
	end)

	return true, nil
end

-- ============================================================
-- Remote handler
-- ============================================================
local function onRequestQueenUpgrade(player: Player, _payload: any)
	if not Validator.RateLimit(player, "RequestQueenUpgrade", Config.QUEEN.upgradeRatePerSecond) then
		return
	end
	local ok, reason = QueenService.Upgrade(player)
	if not ok then
		pcall(function()
			getOrCreateRemote("Notify"):FireClient(player, {
				kind = "error",
				text = reason or "Could not upgrade your queen"
			})
		end)
	end
end

-- ============================================================
-- Init
-- ============================================================
function QueenService.Init()
	if initialized then return end
	initialized = true

	getOrCreateRemote("RequestQueenUpgrade").OnServerEvent:Connect(onRequestQueenUpgrade)
	getOrCreateRemote("Notify")
	getOrCreateRemote("Moment")

	-- Config consistency check (warn only, never error)
	for i, row in Config.QUEEN_TIERS do
		local r = row :: any
		if r.unlocksNurse then
			local gated = Config.CASTES and Config.CASTES.nurse and Config.CASTES.nurse.requiresQueenTier
			if gated and gated ~= i then
				warn(("[QueenService] Config drift: QUEEN_TIERS[%d].unlocksNurse but CASTES.nurse.requiresQueenTier=%s"):format(i, tostring(gated)))
			end
		end
	end
end

return QueenService
]]

print("STEP D complete — QueenService created at", qs:GetFullName())
```

---

## STEP E — Main wiring

```lua
-- STEP E: Wire QueenService into ServerScriptService.Main
local SSS = game:GetService("ServerScriptService")
local orig = SSS:WaitForChild("Main")

local clone = orig:Clone()
orig.Name = "Main_BACKUP_" .. tick()
orig.Parent = nil
clone.Name = "Main"
clone.Parent = SSS

local src = clone.Source

-- Add require after ResourceService if not already present
if not src:find("QueenService") then
	src = src:gsub(
		"(local ResourceService%s*=%s*require%b())",
		"%1\nlocal QueenService = require(Systems:WaitForChild(\"QueenService\"))"
	)
	-- Add Init call after ResourceService.Init()
	src = src:gsub(
		"(ResourceService%.Init%b())",
		"%1\n\tQueenService.Init()"
	)
end

clone.Source = src
print("STEP E complete — Main wired. QueenService require:", src:find("QueenService") ~= nil)
```

---

## STEP F — Queen templates in ReplicatedStorage

```lua
-- STEP F: Create Queen templates in ReplicatedStorage.Templates.Queens
local RS = game:GetService("ReplicatedStorage")
local Templates = RS:WaitForChild("Templates")

-- Remove old Queens folder if it exists
local oldQueens = Templates:FindFirstChild("Queens")
if oldQueens then oldQueens:Destroy() end

local queensFolder = Instance.new("Folder")
queensFolder.Name = "Queens"
queensFolder.Parent = Templates

local function makeGrowthBurst(parent)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "GrowthBurst"
	pe.Enabled = false
	pe.Rate = 0
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(242, 168, 28)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 233, 168)),
	})
	pe.LightEmission = 0.3
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.8, 1.2)
	pe.Speed = NumberRange.new(8, 14)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = parent
	return pe
end

local function makeQueenLight(parent, brightness)
	local pl = Instance.new("PointLight")
	pl.Name = "QueenLight"
	pl.Color = Color3.fromRGB(255, 233, 168)
	pl.Range = 22
	pl.Brightness = brightness
	pl.Shadows = false
	pl.Parent = parent
	return pl
end

local function makeAttendant(model, name, offsetX)
	local sub = Instance.new("Model")
	sub.Name = name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1, 1, 1)
	body.Color = Color3.fromRGB(242, 168, 28)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CFrame = CFrame.new(offsetX, 2.5, 0)
	body.Parent = sub
	local wings = Instance.new("Part")
	wings.Name = "Wings"
	wings.Size = Vector3.new(1.2, 0.1, 0.6)
	wings.Color = Color3.fromRGB(252, 239, 198)
	wings.Material = Enum.Material.Glass
	wings.Transparency = 0.45
	wings.Anchored = true
	wings.CanCollide = false
	wings.CanQuery = false
	wings.CanTouch = false
	wings.CastShadow = false
	wings.CFrame = CFrame.new(offsetX, 3.0, 0)
	wings.Parent = sub
	sub.PrimaryPart = body
	sub.Parent = model
end

local function makeWings(model, scaleX, scaleZ)
	for _, side in { { "WingL", 1 }, { "WingR", -1 } } do
		local w = Instance.new("Part")
		w.Name = side[1]
		w.Size = Vector3.new(scaleX * 1.8, 0.1, scaleZ * 2.4)
		w.Color = Color3.fromRGB(252, 239, 198)
		w.Material = Enum.Material.Glass
		w.Transparency = 0.45
		w.CastShadow = false
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.CFrame = CFrame.new(side[2] * scaleX * 0.95, scaleZ * 2.05, scaleZ * 0.1) * CFrame.Angles(0, 0, math.rad(side[2] * -15))
		w.Parent = model
	end
end

-- ============================================================
-- Queen_T1 "Virgin Queen" — 6 parts, length 5.0
-- ============================================================
local t1 = Instance.new("Model")
t1.Name = "Queen_T1"
t1.Parent = queensFolder

local root1 = Instance.new("Part")
root1.Name = "QueenRoot"
root1.Size = Vector3.new(1, 1, 1)
root1.Transparency = 1
root1.Anchored = true
root1.CanCollide = false
root1.CanQuery = false
root1.CanTouch = false
root1.CFrame = CFrame.new(0, 0, 0)
root1.Parent = t1
t1.PrimaryPart = root1
makeGrowthBurst(root1)

local head1 = Instance.new("Part")
head1.Name = "Head"
head1.Shape = Enum.PartType.Ball
head1.Size = Vector3.new(1.3, 1.3, 1.3)
head1.Color = Color3.fromRGB(122, 74, 34)
head1.Material = Enum.Material.SmoothPlastic
head1.Anchored = true
head1.CanCollide = false
head1.CanQuery = false
head1.CanTouch = false
head1.CFrame = CFrame.new(0, 1.2, -1.85)
head1.Parent = t1

local thorax1 = Instance.new("Part")
thorax1.Name = "Thorax"
thorax1.Shape = Enum.PartType.Ball
thorax1.Size = Vector3.new(1.6, 1.6, 1.6)
thorax1.Color = Color3.fromRGB(122, 74, 34)
thorax1.Material = Enum.Material.SmoothPlastic
thorax1.Anchored = true
thorax1.CanCollide = false
thorax1.CanQuery = false
thorax1.CanTouch = false
thorax1.CFrame = CFrame.new(0, 1.3, -0.7)
thorax1.Parent = t1

local abdomen1 = Instance.new("Part")
abdomen1.Name = "Abdomen"
abdomen1.Size = Vector3.new(1.5, 1.4, 2.6)
abdomen1.Color = Color3.fromRGB(232, 212, 154)
abdomen1.Material = Enum.Material.SmoothPlastic
abdomen1.Anchored = true
abdomen1.CanCollide = false
abdomen1.CanQuery = false
abdomen1.CanTouch = false
abdomen1.CFrame = CFrame.new(0, 1.2, 1.15)
local mesh1 = Instance.new("SpecialMesh")
mesh1.MeshType = Enum.MeshType.Sphere
mesh1.Scale = Vector3.new(1, 1, 1)
mesh1.Parent = abdomen1
abdomen1.Parent = t1

makeWings(t1, 1, 1)
print("STEP F — Queen_T1 created:", t1:GetFullName())

-- ============================================================
-- Queen_T2 "Laying Queen" — 7 parts, length 5.5
-- ============================================================
local t2 = t1:Clone()
t2.Name = "Queen_T2"
t2.Parent = queensFolder
-- Modify abdomen to gold, enlarge
local abd2 = t2:FindFirstChild("Abdomen")
if abd2 then
	abd2.Color = Color3.fromRGB(242, 168, 28)
	abd2.Size = Vector3.new(1.6, 1.5, 3.1)
	abd2.CFrame = CFrame.new(0, 1.25, 1.4)
end
-- Add abdomen band
local band2 = Instance.new("Part")
band2.Name = "AbdomenBand"
band2.Shape = Enum.PartType.Cylinder
band2.Size = Vector3.new(0.5, 1.7, 1.7)
band2.Color = Color3.fromRGB(122, 74, 34)
band2.Material = Enum.Material.SmoothPlastic
band2.Anchored = true
band2.CanCollide = false
band2.CanQuery = false
band2.CanTouch = false
band2.CFrame = CFrame.new(0, 1.25, 1.2) * CFrame.Angles(0, math.rad(90), 0)
band2.Parent = t2
print("STEP F — Queen_T2 created:", t2:GetFullName())

-- ============================================================
-- Queen_T3 "Crowned Queen" — 8 parts, length 6.0
-- ============================================================
local t3 = t2:Clone()
t3.Name = "Queen_T3"
t3.Parent = queensFolder
local abd3 = t3:FindFirstChild("Abdomen")
if abd3 then
	abd3.Size = Vector3.new(1.7, 1.6, 3.5)
	abd3.CFrame = CFrame.new(0, 1.3, 1.6)
end
local band3 = t3:FindFirstChild("AbdomenBand")
if band3 then
	band3.CFrame = CFrame.new(0, 1.3, 1.35) * CFrame.Angles(0, math.rad(90), 0)
	band3.Size = Vector3.new(0.5, 1.8, 1.8)
end
-- Add wax crown
local crown3 = Instance.new("Part")
crown3.Name = "Crown"
crown3.Shape = Enum.PartType.Cylinder
crown3.Size = Vector3.new(0.5, 1.2, 1.2)
crown3.Color = Color3.fromRGB(232, 212, 154)
crown3.Material = Enum.Material.SmoothPlastic
crown3.Anchored = true
crown3.CanCollide = false
crown3.CanQuery = false
crown3.CanTouch = false
crown3.CFrame = CFrame.new(0, 2.05, -1.9) * CFrame.Angles(0, 0, math.rad(90))
crown3.Parent = t3
print("STEP F — Queen_T3 created:", t3:GetFullName())

-- ============================================================
-- Queen_T4 "Matriarch" — 12 parts, length 9.0 (~1.8x T3)
-- ============================================================
local t4 = t3:Clone()
t4.Name = "Queen_T4"
t4.Parent = queensFolder
-- Scale by 1.5
local SCALE4 = 1.5
for _, p in t4:GetDescendants() do
	if p:IsA("BasePart") then
		p.Size = p.Size * SCALE4
		p.CFrame = CFrame.new(p.CFrame.Position * SCALE4) * (p.CFrame - p.CFrame.Position)
	end
end
-- Amber glass abdomen
local abd4 = t4:FindFirstChild("Abdomen")
if abd4 then
	abd4.Material = Enum.Material.Glass
	abd4.Transparency = 0.15
	abd4.Color = Color3.fromRGB(242, 168, 28)
end
-- QueenLight
local thorax4 = t4:FindFirstChild("Thorax")
if thorax4 then makeQueenLight(thorax4, 0.9) end
-- Attendants
makeAttendant(t4, "AttendantA", 4.5)
makeAttendant(t4, "AttendantB", -4.5)
print("STEP F — Queen_T4 created:", t4:GetFullName())

-- ============================================================
-- Queen_T5 "Sun Queen" — 13 parts, length 12.5 (~2.5x T3)
-- ============================================================
local t5 = t3:Clone()
t5.Name = "Queen_T5"
t5.Parent = queensFolder
local SCALE5 = 12.5 / 6.0
for _, p in t5:GetDescendants() do
	if p:IsA("BasePart") then
		p.Size = p.Size * SCALE5
		p.CFrame = CFrame.new(p.CFrame.Position * SCALE5) * (p.CFrame - p.CFrame.Position)
	end
end
local abd5 = t5:FindFirstChild("Abdomen")
if abd5 then
	abd5.Material = Enum.Material.Glass
	abd5.Transparency = 0.15
	abd5.Color = Color3.fromRGB(242, 168, 28)
end
local thorax5 = t5:FindFirstChild("Thorax")
if thorax5 then makeQueenLight(thorax5, 1.6) end
makeAttendant(t5, "AttendantA", 7.0)
makeAttendant(t5, "AttendantB", -7.0)
-- Sun halo
local halo5 = Instance.new("Part")
halo5.Name = "Halo"
halo5.Shape = Enum.PartType.Cylinder
halo5.Size = Vector3.new(0.2, 5.5, 5.5)
halo5.Color = Color3.fromRGB(252, 239, 198)
halo5.Material = Enum.Material.Neon
halo5.Transparency = 0.5
halo5.CastShadow = false
halo5.Anchored = true
halo5.CanCollide = false
halo5.CanQuery = false
halo5.CanTouch = false
-- Position above and behind the head (head at ~0, 1.2*SCALE5, -1.85*SCALE5)
local headY = 1.2 * SCALE5
local headZ = -1.85 * SCALE5
halo5.CFrame = CFrame.new(0, headY + 1.6, headZ - 0.6) * CFrame.Angles(0, 0, math.rad(90))
halo5.Parent = t5
print("STEP F — Queen_T5 created:", t5:GetFullName())

print("STEP F COMPLETE — All 5 Queen templates in", queensFolder:GetFullName())
print("Templates:", #queensFolder:GetChildren(), "models")
```

---

## STEP G — HiveGui QUEEN tab rebuild

```lua
-- STEP G: Rebuild HiveGui QueenPage.Card
local StarterGui = game:GetService("StarterGui")
local HiveGui = StarterGui:WaitForChild("HiveGui")
local Panel = HiveGui:WaitForChild("Panel")
local Pages = Panel:WaitForChild("Pages")
local QueenPage = Pages:WaitForChild("QueenPage")
local Card = QueenPage:WaitForChild("Card")

-- Keep UICorner, UIStroke, UIGradient and Header; delete everything else except those
local toKeep = { "UICorner", "UIStroke", "UIGradient" }
for _, child in Card:GetChildren() do
	local keep = false
	for _, k in toKeep do
		if child.ClassName == k then keep = true break end
	end
	if child.Name == "Header" then keep = true end
	if not keep then child:Destroy() end
end

-- Helper
local function newLabel(name, parent, size, pos, anchor, text)
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = size
	lbl.Position = pos
	lbl.AnchorPoint = anchor
	lbl.Text = text
	lbl.BackgroundTransparency = 1
	lbl.TextScaled = true
	lbl.TextWrapped = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = Color3.fromRGB(122, 74, 34)
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 14
	c.MaxTextSize = 28
	c.Parent = lbl
	lbl.Parent = parent
	return lbl
end

local function newButton(name, parent, size, pos, anchor, text)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = size
	btn.Position = pos
	btn.AnchorPoint = anchor
	btn.Text = text
	btn.TextScaled = true
	btn.TextWrapped = true
	btn.Font = Enum.Font.FredokaOne
	btn.TextColor3 = Color3.fromRGB(122, 74, 34)
	btn.BackgroundColor3 = Color3.fromRGB(142, 138, 122)
	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(0.1, 0)
	uc.Parent = btn
	local us = Instance.new("UIStroke")
	us.Color = Color3.fromRGB(122, 74, 34)
	us.Thickness = 2
	us.Parent = btn
	local c = Instance.new("UITextSizeConstraint")
	c.MinTextSize = 14
	c.MaxTextSize = 28
	c.Parent = btn
	btn.Parent = parent
	return btn
end

-- Fix Header
local Header = Card:FindFirstChild("Header")
if Header then
	Header.Text = "YOUR QUEEN"
	Header.Size = UDim2.new(0.9, 0, 0.12, 0)
	Header.Position = UDim2.new(0.5, 0, 0.03, 0)
	Header.AnchorPoint = Vector2.new(0.5, 0)
	Header.TextColor3 = Color3.fromRGB(122, 74, 34)
end

-- PortraitFrame
local pf = Instance.new("Frame")
pf.Name = "PortraitFrame"
pf.Size = UDim2.new(0.34, 0, 0.48, 0)
pf.Position = UDim2.new(0.04, 0, 0.17, 0)
pf.AnchorPoint = Vector2.new(0, 0)
pf.BackgroundColor3 = Color3.fromRGB(252, 239, 198)
local pfCorner = Instance.new("UICorner")
pfCorner.CornerRadius = UDim.new(0.08, 0)
pfCorner.Parent = pf
pf.Parent = Card

-- ViewportFrame inside PortraitFrame
local vf = Instance.new("ViewportFrame")
vf.Name = "QueenViewport"
vf.Size = UDim2.new(1, 0, 1, 0)
vf.BackgroundTransparency = 1
vf.Ambient = Color3.fromRGB(138, 122, 90)
vf.LightColor = Color3.fromRGB(255, 233, 168)
vf.LightDirection = Vector3.new(-1, -1, -1)
vf.Parent = pf

-- TierBadge
local tb = newLabel("TierBadge", pf, UDim2.new(0.9, 0, 0.16, 0), UDim2.new(0.5, 0, 0.97, 0), Vector2.new(0.5, 1), "TIER 1 / 5")
tb.TextColor3 = Color3.fromRGB(122, 74, 34)
tb.BackgroundTransparency = 1

-- InfoFrame
local inf = Instance.new("Frame")
inf.Name = "InfoFrame"
inf.Size = UDim2.new(0.56, 0, 0.48, 0)
inf.Position = UDim2.new(0.40, 0, 0.17, 0)
inf.AnchorPoint = Vector2.new(0, 0)
inf.BackgroundTransparency = 1
inf.Parent = Card

local ll = Instance.new("UIListLayout")
ll.FillDirection = Enum.FillDirection.Vertical
ll.SortOrder = Enum.SortOrder.LayoutOrder
ll.Padding = UDim.new(0.015, 0)
ll.Parent = inf

local nameLabel = newLabel("NameLabel", inf, UDim2.new(1, 0, 0.20, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), "Virgin Queen")
nameLabel.LayoutOrder = 1
local nextLabel = newLabel("NextLabel", inf, UDim2.new(1, 0, 0.14, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), "NEXT: Laying Queen")
nextLabel.LayoutOrder = 2
local layLabel = newLabel("LayLabel", inf, UDim2.new(1, 0, 0.19, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), "New bee every 12.0s -> 8.0s")
layLabel.LayoutOrder = 3
local outputLabel = newLabel("OutputLabel", inf, UDim2.new(1, 0, 0.19, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), "Honey x1.00 -> x1.15")
outputLabel.LayoutOrder = 4
local unlockLabel = newLabel("UnlockLabel", inf, UDim2.new(1, 0, 0.19, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), "Lays eggs faster!")
unlockLabel.LayoutOrder = 5

-- JellyFrame
local jf = Instance.new("Frame")
jf.Name = "JellyFrame"
jf.Size = UDim2.new(0.92, 0, 0.10, 0)
jf.Position = UDim2.new(0.5, 0, 0.67, 0)
jf.AnchorPoint = Vector2.new(0.5, 0)
jf.BackgroundTransparency = 1
jf.Parent = Card

local jellyLabel = newLabel("JellyLabel", jf, UDim2.new(0.60, 0, 1, 0), UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), "Royal Jelly: 0 / 5")
jellyLabel.TextXAlignment = Enum.TextXAlignment.Left

local jellyBar = Instance.new("Frame")
jellyBar.Name = "JellyBar"
jellyBar.Size = UDim2.new(0.38, 0, 0.5, 0)
jellyBar.Position = UDim2.new(1, 0, 0.5, 0)
jellyBar.AnchorPoint = Vector2.new(1, 0.5)
jellyBar.BackgroundColor3 = Color3.fromRGB(142, 138, 122)
local jbCorner = Instance.new("UICorner")
jbCorner.CornerRadius = UDim.new(0.5, 0)
jbCorner.Parent = jellyBar
jellyBar.Parent = jf

local jellyFill = Instance.new("Frame")
jellyFill.Name = "JellyFill"
jellyFill.Size = UDim2.new(0, 0, 1, 0)
jellyFill.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
local jfCorner = Instance.new("UICorner")
jfCorner.CornerRadius = UDim.new(0.5, 0)
jfCorner.Parent = jellyFill
jellyFill.Parent = jellyBar

-- HintLabel
local hintLabel = newLabel("HintLabel", Card, UDim2.new(0.92, 0, 0.06, 0), UDim2.new(0.5, 0, 0.775, 0), Vector2.new(0.5, 0),
	"Build a ROYAL cell on the edge, touching BROOD cells, to make Royal Jelly!")
hintLabel.TextColor3 = Color3.fromRGB(122, 74, 34)

-- UpgradeButton
local upgradeBtn = newButton("UpgradeButton", Card, UDim2.new(0.5, 0, 0.13, 0), UDim2.new(0.5, 0, 0.84, 0), Vector2.new(0.5, 0), "UPGRADE QUEEN")

-- Discovery badges
local HiveButton = HiveGui:FindFirstChild("HiveButton")
if HiveButton then
	local badge = Instance.new("Frame")
	badge.Name = "QueenBadge"
	badge.Size = UDim2.new(0.3, 0, 0.3, 0)
	badge.Position = UDim2.new(0.95, 0, 0.08, 0)
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
	badge.Visible = false
	badge.ZIndex = 10
	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(1, 0)
	bCorner.Parent = badge
	local bStroke = Instance.new("UIStroke")
	bStroke.Color = Color3.fromRGB(122, 74, 34)
	bStroke.Parent = badge
	local bAR = Instance.new("UIAspectRatioConstraint")
	bAR.AspectRatio = 1
	bAR.Parent = badge
	local bText = newLabel("BadgeText", badge, UDim2.new(1, 0, 1, 0), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5), "!")
	bText.TextColor3 = Color3.fromRGB(122, 74, 34)
	badge.Parent = HiveButton
end

local QueenTab = Panel:WaitForChild("Tabs"):FindFirstChild("QueenTab")
if QueenTab then
	local tabBadge = Instance.new("Frame")
	tabBadge.Name = "QueenTabBadge"
	tabBadge.Size = UDim2.new(0.22, 0, 0.22, 0)
	tabBadge.Position = UDim2.new(0.92, 0, 0.12, 0)
	tabBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	tabBadge.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
	tabBadge.Visible = false
	tabBadge.ZIndex = 10
	local tbCorner = Instance.new("UICorner")
	tbCorner.CornerRadius = UDim.new(1, 0)
	tbCorner.Parent = tabBadge
	local tbStroke = Instance.new("UIStroke")
	tbStroke.Color = Color3.fromRGB(122, 74, 34)
	tbStroke.Parent = tabBadge
	local tbAR = Instance.new("UIAspectRatioConstraint")
	tbAR.AspectRatio = 1
	tbAR.Parent = tabBadge
	local tbText = newLabel("BadgeText", tabBadge, UDim2.new(1, 0, 1, 0), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5), "!")
	tbText.TextColor3 = Color3.fromRGB(122, 74, 34)
	tabBadge.Parent = QueenTab
end

print("STEP G complete — HiveGui QueenPage.Card rebuilt")
print("Children:", #Card:GetChildren(), "infants:", #inf:GetChildren())
```

---

## STEP H — HiveController surgical patch

This is the most complex patch. Read HiveController fresh before applying.

```lua
-- STEP H: HiveController patch — add queen rendering + upgrade flow
local SP = game:GetService("StarterPlayer")
local Controllers = SP:WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")
local orig = Controllers:WaitForChild("HiveController")

local clone = orig:Clone()
orig.Name = "HiveController_BACKUP_" .. tick()
orig.Parent = nil
clone.Name = "HiveController"
clone.Parent = Controllers

local src = clone.Source

-- 1. Add new module state variables after the existing state block
-- Find queenTier variable declaration and add after it
if not src:find("royalJellyPerMin") then
	src = src:gsub(
		"(local queenTier%s*=%s*%d+)",
		[[%1
local royalJelly: number? = nil
local royalJellyPerMin = 0
local generation = 0
local queenPending = false
local queenPendingTier = 0
local queenPendingStamp = 0
local lastQueenSubmitAt = -math.huge
local queenNotUpgradedNotice = false
local portraitTier = 0
local requestQueenUpgrade: RemoteEvent? = nil
local setOpenRef: ((boolean) -> ())? = nil]]
	)
end

-- 2. Patch onRatesUpdate to read new fields
if not src:find("royalJellyPerMin") then
	-- Find onRatesUpdate and add royalJelly reads
	src = src:gsub(
		"(queenTier%s*=%s*payload%.queenTier[^\n]*)",
		[[%1
	if typeof(payload.royalJellyPerMin) == "number" then royalJellyPerMin = payload.royalJellyPerMin end
	if typeof(payload.generation) == "number" then generation = payload.generation end
	-- Check if pending upgrade succeeded (queenTier rose)
	if queenPending and queenTier > queenPendingTier then
		queenPending = false
		queenNotUpgradedNotice = false
		if setOpenRef then setOpenRef(false) end
	end]]
	)
end

-- 3. Add onWalletUpdate handler
if not src:find("onWalletUpdate") then
	-- Insert after onRatesUpdate function
	src = src:gsub(
		"(local function onRatesUpdate.-end)",
		[[%1

local function onWalletUpdate(payload: any)
	if typeof(payload) ~= "table" then return end
	if typeof(payload.royalJelly) == "number" then
		royalJelly = payload.royalJelly
		render()
	end
end]]
	)
end

-- 4. Add onMoment handler (check QueenGrowth to close panel)
if not src:find("QueenGrowth") then
	src = src:gsub(
		"(local function onWalletUpdate.-end)",
		[[%1

local function onMoment(payload: any)
	if typeof(payload) ~= "table" then return end
	if payload.id == "QueenGrowth" then
		local Players = game:GetService("Players")
		local p = payload.payload
		if typeof(p) == "table" and p.ownerUserId == Players.LocalPlayer.UserId then
			queenPending = false
			queenNotUpgradedNotice = false
			if setOpenRef then setOpenRef(false) end
		end
	end
end]]
	)
end

-- 5. Add renderQueen function
if not src:find("renderQueen") then
	local renderQueenFn = [[

local function renderQueen()
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Config"))
	local VISUALS = Config.QUEEN and Config.QUEEN.VISUALS or {}
	local tiers = Config.QUEEN_TIERS
	if not tiers then return end
	local cur = tiers[queenTier] or tiers[1]
	local nextIdx = queenTier + 1
	local nextRow = tiers[nextIdx]
	local rj = math.floor(royalJelly or 0)
	local cost = nextRow and nextRow.rj or 0

	-- Resolve UI refs (cached after first render)
	local StarterGui = game:GetService("StarterGui")
	local Card = StarterGui:FindFirstChild("HiveGui", true)
		and StarterGui:FindFirstChild("HiveGui").Panel.Pages.QueenPage.Card
	if not Card then return end

	local header = Card:FindFirstChild("Header")
	local tierBadge = Card:FindFirstChild("PortraitFrame") and Card.PortraitFrame:FindFirstChild("TierBadge")
	local nameLabel = Card:FindFirstChild("InfoFrame") and Card.InfoFrame:FindFirstChild("NameLabel")
	local nextLabel = Card:FindFirstChild("InfoFrame") and Card.InfoFrame:FindFirstChild("NextLabel")
	local layLabel = Card:FindFirstChild("InfoFrame") and Card.InfoFrame:FindFirstChild("LayLabel")
	local outputLabel = Card:FindFirstChild("InfoFrame") and Card.InfoFrame:FindFirstChild("OutputLabel")
	local unlockLabel = Card:FindFirstChild("InfoFrame") and Card.InfoFrame:FindFirstChild("UnlockLabel")
	local jellyLabel = Card:FindFirstChild("JellyFrame") and Card.JellyFrame:FindFirstChild("JellyLabel")
	local jellyFill = Card:FindFirstChild("JellyFrame") and Card.JellyFrame.JellyBar:FindFirstChild("JellyFill")
	local hintLabel = Card:FindFirstChild("HintLabel")
	local upgradeBtn = Card:FindFirstChild("UpgradeButton")

	if header then header.Text = "YOUR QUEEN" end
	if tierBadge then tierBadge.Text = string.format("TIER %d / %d", queenTier, #tiers) end
	if nameLabel then nameLabel.Text = cur.name end

	if nextRow then
		if nextLabel then nextLabel.Text = "NEXT: " .. nextRow.name end
		if layLabel then layLabel.Text = string.format("New bee every %.1fs -> %.1fs", cur.layInterval, nextRow.layInterval) end
		if outputLabel then outputLabel.Text = string.format("Honey x%.2f -> x%.2f", cur.outputMult, nextRow.outputMult) end
		-- UnlockLabel
		local unlockText = "Lays eggs faster!"
		local nr = nextRow :: any
		if nr.genGate and generation < nr.genGate then
			unlockText = string.format("Needs Generation %d (Swarming - coming soon)", nr.genGate)
		elseif nr.unlocksNurse then
			unlockText = "NEW: Nurse bees!"
		elseif nr.unlocksGoldenComb or nr.unlocksSwarm then
			unlockText = "NEW: Golden Comb + Swarming (coming soon)"
		elseif nr.unlocksFloor3 then
			unlockText = "NEW: Crown Comb floor (coming soon)"
		end
		if unlockLabel then unlockLabel.Text = unlockText end
		if jellyLabel then jellyLabel.Text = string.format("Royal Jelly: %d / %d", rj, cost) end
		if jellyFill then
			jellyFill.Size = UDim2.new(math.clamp(cost > 0 and rj / cost or 0, 0, 1), 0, 1, 0)
		end
	else
		-- Max tier
		if nextLabel then nextLabel.Text = "The greatest queen in the garden!" end
		if layLabel then layLabel.Text = string.format("New bee every %.1fs", cur.layInterval) end
		if outputLabel then outputLabel.Text = string.format("Honey x%.2f", cur.outputMult) end
		if unlockLabel then unlockLabel.Text = "" end
		if jellyLabel then jellyLabel.Text = string.format("Royal Jelly: %d", rj) end
		if jellyFill then jellyFill.Size = UDim2.new(1, 0, 1, 0) end
		if hintLabel then hintLabel.Text = "Save your Royal Jelly -- perks are coming soon!" end
	end

	-- Hint label
	if nextRow and hintLabel then
		if queenNotUpgradedNotice then
			hintLabel.Text = "Not upgraded - try again"
			hintLabel.TextColor3 = Color3.fromRGB(216, 69, 43)
		elseif royalJellyPerMin <= 0 then
			hintLabel.Text = "Build a ROYAL cell on the edge, touching BROOD cells, to make Royal Jelly!"
			hintLabel.TextColor3 = Color3.fromRGB(122, 74, 34)
		else
			local perMin = royalJellyPerMin
			local fmtd = perMin >= 0.1 and string.format("%.1f", perMin) or string.format("%.2f", perMin)
			hintLabel.Text = string.format("Your Royal Cells make %s jelly per minute", fmtd)
			hintLabel.TextColor3 = Color3.fromRGB(122, 74, 34)
		end
	end

	-- Upgrade button state
	if upgradeBtn then
		local GREY = Color3.fromRGB(142, 138, 122)
		local GOLD = Color3.fromRGB(242, 168, 28)
		if queenPending then
			upgradeBtn.Text = "CROWNING..."
			upgradeBtn.BackgroundColor3 = GREY
		elseif not nextRow then
			upgradeBtn.Text = "MAX QUEEN"
			upgradeBtn.BackgroundColor3 = GREY
		else
			local nr2 = nextRow :: any
			if nr2.genGate and generation < nr2.genGate then
				upgradeBtn.Text = string.format("NEEDS GEN %d", nr2.genGate)
				upgradeBtn.BackgroundColor3 = GREY
			elseif rj < cost then
				upgradeBtn.Text = string.format("NEED %d MORE JELLY", cost - rj)
				upgradeBtn.BackgroundColor3 = GREY
			else
				upgradeBtn.Text = "UPGRADE QUEEN"
				upgradeBtn.BackgroundColor3 = GOLD
				upgradeBtn.TextColor3 = Color3.fromRGB(122, 74, 34)
			end
		end
	end

	-- Portrait (only rebuild when tier changes)
	local viewport = Card:FindFirstChild("PortraitFrame") and Card.PortraitFrame:FindFirstChild("QueenViewport")
	if viewport and portraitTier ~= queenTier then
		portraitTier = queenTier
		for _, c in viewport:GetChildren() do c:Destroy() end
		local vis = VISUALS[queenTier]
		if vis then
			local Queens = game:GetService("ReplicatedStorage").Templates:FindFirstChild("Queens")
			local template = Queens and Queens:FindFirstChild(vis.template)
			if template then
				local cloned = template:Clone()
				cloned:PivotTo(CFrame.new())
				cloned.Parent = viewport
				local cam = Instance.new("Camera")
				cam.FieldOfView = 40
				local L = vis.bodyLength
				cam.CFrame = CFrame.lookAt(Vector3.new(L*0.9, L*0.6, -L*1.1), Vector3.new(0, L*0.2, 0))
				cam.Parent = viewport
				viewport.CurrentCamera = cam
			end
		end
	end

	-- Discovery badges
	local HiveGui = StarterGui:FindFirstChild("HiveGui")
	local canAfford = nextRow ~= nil and (not (nextRow :: any).genGate or generation >= (nextRow :: any).genGate) and rj >= cost and not queenPending
	local hiveBtn = HiveGui and HiveGui:FindFirstChild("HiveButton")
	local hBadge = hiveBtn and hiveBtn:FindFirstChild("QueenBadge")
	if hBadge then hBadge.Visible = canAfford end
	local queenTab = HiveGui and HiveGui:FindFirstChild("Panel") and HiveGui.Panel.Tabs:FindFirstChild("QueenTab")
	local tBadge = queenTab and queenTab:FindFirstChild("QueenTabBadge")
	if tBadge then tBadge.Visible = canAfford end
end
]]
	-- Insert before the render() function
	src = src:gsub("(local function render%b())", renderQueenFn .. "\n%1")
	-- If render() is defined differently, insert before Init
	if not src:find("renderQueen") then
		src = src:gsub("(function HiveController%.Init%b())", renderQueenFn .. "\n%1")
	end
end

-- 6. Patch render() to call renderQueen()
-- Find the render function body and call renderQueen inside it
if not src:find("renderQueen%(%)") then
	src = src:gsub(
		"(local function render%(%))",
		[[%1
	renderQueen()]]
	)
end

-- 7. Add submitQueenUpgrade function
if not src:find("submitQueenUpgrade") then
	local submitFn = [[

local function submitQueenUpgrade()
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Config"))
	local tiers = Config.QUEEN_TIERS
	if not requestQueenUpgrade then return end
	if queenPending then return end
	if os.clock() - lastQueenSubmitAt < 1.1 then return end
	local nextRow = tiers[queenTier + 1]
	if not nextRow then return end
	local nr = nextRow :: any
	if nr.genGate and generation < nr.genGate then return end
	local rj = math.floor(royalJelly or 0)
	if rj < nr.rj then return end

	queenPending = true
	queenPendingTier = queenTier
	queenPendingStamp = os.clock()
	lastQueenSubmitAt = os.clock()
	requestQueenUpgrade:FireServer({})
	render()

	task.delay(1.15, render)
	task.delay(3.5, function()
		if queenPending and os.clock() - queenPendingStamp >= 3.4 then
			queenPending = false
			queenNotUpgradedNotice = true
			render()
		end
	end)
end
]]
	src = src:gsub("(local function renderQueen%(%))", submitFn .. "\n%1")
end

-- 8. Wire submitQueenUpgrade to UpgradeButton in Init
if not src:find("submitQueenUpgrade") or not src:find("UpgradeButton.*MouseButton1Click") then
	-- Find Init and add wiring after the QueenTab connection
	src = src:gsub(
		"(function HiveController%.Init%(%))",
		[[%1
	-- Wire UpgradeButton
	task.spawn(function()
		local SG = game:GetService("StarterGui")
		local Card = SG:WaitForChild("HiveGui").Panel.Pages.QueenPage.Card
		local btn = Card:WaitForChild("UpgradeButton")
		btn.MouseButton1Click:Connect(submitQueenUpgrade)
		setOpenRef = setOpen

		local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
		requestQueenUpgrade = Remotes:WaitForChild("RequestQueenUpgrade")
		Remotes:WaitForChild("WalletUpdate").OnClientEvent:Connect(onWalletUpdate)
		Remotes:WaitForChild("Moment").OnClientEvent:Connect(onMoment)
	end)]]
	)
end

-- 9. Remove old queenBody block if present
src = src:gsub("if queenBody then.-end\n", "")

clone.Source = src

print("STEP H complete — HiveController patched.")
print("  royalJellyPerMin:", src:find("royalJellyPerMin") ~= nil)
print("  onWalletUpdate:", src:find("onWalletUpdate") ~= nil)
print("  onMoment/QueenGrowth:", src:find("QueenGrowth") ~= nil)
print("  renderQueen:", src:find("renderQueen") ~= nil)
print("  submitQueenUpgrade:", src:find("submitQueenUpgrade") ~= nil)
```

---

## STEP I — QueenController (new ModuleScript)

```lua
-- STEP I: Create QueenController in StarterPlayerScripts.Controllers
local SP = game:GetService("StarterPlayer")
local Controllers = SP:WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")

local old = Controllers:FindFirstChild("QueenController")
if old then old:Destroy() end

local qc = Instance.new("ModuleScript")
qc.Name = "QueenController"
qc.Parent = Controllers
qc.Source = [[
--!strict
-- QueenController: client-only queen rendering.
-- The server never moves the queen. Queens are cloned into Workspace.ClientFX.Queens
-- and despawn when the plot owner changes or leaves LOD.

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Modules = RS:WaitForChild("Modules")
local Config = require(Modules:WaitForChild("Config"))
local HexGrid = require(Modules:WaitForChild("HexGrid"))

local QueenController = {}

-- ============================================================
-- State
-- ============================================================
type QueenState = {
	model: Model?,
	tier: number,
	plotIndex: number,
	ownerUserId: number,
	plotRoot: BasePart,
	broodCells: { { q: number, r: number } },
	currentCell: { q: number, r: number },
	state: string,  -- "Walking" | "Laying" | "Growing"
	walkFrom: Vector3,
	walkTo: Vector3,
	walkT: number,
	walkDuration: number,
	layUntil: number,
	growthQueued: number?,
	flashPool: { BasePart },
	attendantA: Model?,
	attendantB: Model?,
}

local queens: { [number]: QueenState } = {}
local heartbeatConn: RBXScriptConnection? = nil
local clock = 0

local CFX: Folder?
local function getCFXQueens(): Folder
	local cfx = Workspace:FindFirstChild("ClientFX") :: Folder?
	if not cfx then
		cfx = Instance.new("Folder")
		cfx.Name = "ClientFX"
		cfx.Parent = Workspace
	end
	local q = cfx:FindFirstChild("Queens") :: Folder?
	if not q then
		q = Instance.new("Folder")
		q.Name = "Queens"
		q.Parent = cfx
	end
	return q :: Folder
end

-- ============================================================
-- Geometry
-- ============================================================
local function latticeOrigin(root: BasePart): Vector3
	return Vector3.new(root.Position.X, 0, root.Position.Z + Config.QUEEN.latticeZOffset)
end

local function cellPivot(root: BasePart, q: number, r: number): Vector3
	return HexGrid.ToWorld(q, r, latticeOrigin(root),
		(Config.FLOOR_Y and Config.FLOOR_Y[Config.QUEEN.walkFloor] or 6.3) + Config.QUEEN.walkHeightAboveFloorY)
end

-- ============================================================
-- LOD
-- ============================================================
local function shouldRender(root: BasePart, ownerUserId: number): boolean
	if ownerUserId == 0 then return false end
	local lp = Players.LocalPlayer
	if root:GetAttribute("OwnerUserId") == lp.UserId then return true end
	local char = lp.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end
	return (hrp.Position - root.Position).Magnitude <= Config.QUEEN.renderRadiusStuds
end

-- ============================================================
-- Flash disc pool
-- ============================================================
local function getFlashDisc(state: QueenState): BasePart
	if #state.flashPool > 0 then
		return table.remove(state.flashPool) :: BasePart
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, 12, 12)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(242, 168, 28)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = getCFXQueens()
	return p
end

local function flashCell(state: QueenState, q: number, r: number, root: BasePart)
	local disc = getFlashDisc(state)
	local floorY = (Config.FLOOR_Y and Config.FLOOR_Y[Config.QUEEN.walkFloor] or 6.3) + Config.QUEEN.flashHeightAboveFloorY
	disc.CFrame = CFrame.new(
		HexGrid.ToWorld(q, r, latticeOrigin(root), floorY)
	) * CFrame.Angles(0, 0, math.rad(90))
	disc.Transparency = Config.QUEEN.cellFlashStartTransparency
	TweenService:Create(disc, TweenInfo.new(Config.QUEEN.cellFlashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1
	}):Play()
	task.delay(Config.QUEEN.cellFlashSeconds + 0.1, function()
		disc.Transparency = 1
		table.insert(state.flashPool, disc)
	end)
end

-- ============================================================
-- Spawn / despawn
-- ============================================================
local function collectBroodCells(plotIndex: number): { { q: number, r: number } }
	local cells = { { q = 0, r = 0 } }  -- Dance Floor always available
	for _, cc in CS:GetTagged("CombCell") do
		if cc:GetAttribute("PlotIndex") == plotIndex and
		   cc:GetAttribute("Floor") == Config.QUEEN.walkFloor and
		   cc:GetAttribute("CellType") == "Brood" then
			local q = cc:GetAttribute("Q")
			local r = cc:GetAttribute("R")
			if typeof(q) == "number" and typeof(r) == "number" then
				table.insert(cells, { q = q, r = r })
			end
		end
	end
	return cells
end

local function spawnQueen(plotIndex: number, root: BasePart, tier: number, ownerUserId: number)
	local old = queens[plotIndex]
	if old then
		if old.model then old.model:Destroy() end
		if old.attendantA then old.attendantA:Destroy() end
		if old.attendantB then old.attendantB:Destroy() end
	end

	local VISUALS = Config.QUEEN.VISUALS
	local vis = VISUALS[tier] or VISUALS[1]
	local Queens = RS.Templates:FindFirstChild("Queens")
	local template = Queens and Queens:FindFirstChild(vis.template)
	if not template then
		warn("[QueenController] Missing template", vis.template)
		return
	end

	local model = (template :: Model):Clone()
	model.Parent = getCFXQueens()
	model:PivotTo(CFrame.new(cellPivot(root, 0, 0), cellPivot(root, 0, 0) + Vector3.new(0, 0, -1)))

	-- Detach attendants if present
	local attA = model:FindFirstChild("AttendantA") :: Model?
	local attB = model:FindFirstChild("AttendantB") :: Model?
	if attA then attA.Parent = getCFXQueens() end
	if attB then attB.Parent = getCFXQueens() end

	queens[plotIndex] = {
		model = model,
		tier = tier,
		plotIndex = plotIndex,
		ownerUserId = ownerUserId,
		plotRoot = root,
		broodCells = collectBroodCells(plotIndex),
		currentCell = { q = 0, r = 0 },
		state = "Laying",
		walkFrom = cellPivot(root, 0, 0),
		walkTo = cellPivot(root, 0, 0),
		walkT = 0,
		walkDuration = 1,
		layUntil = os.clock() + vis.pauseSeconds,
		growthQueued = nil,
		flashPool = {},
		attendantA = attA,
		attendantB = attB,
	}
end

local function despawnQueen(plotIndex: number)
	local state = queens[plotIndex]
	if not state then return end
	if state.model then state.model:Destroy() end
	if state.attendantA then state.attendantA:Destroy() end
	if state.attendantB then state.attendantB:Destroy() end
	for _, d in state.flashPool do d:Destroy() end
	queens[plotIndex] = nil
end

-- ============================================================
-- Walk logic
-- ============================================================
local function pickNextTarget(state: QueenState): { q: number, r: number }
	local cells = state.broodCells
	if #cells <= 1 then
		-- Pace between home and a ring-1 neighbour
		local neighbours = HexGrid.Neighbours(0, 0)
		local floor = Config.QUEEN.walkFloor
		local radius = Config.FLOOR_RADIUS and Config.FLOOR_RADIUS[floor] or 4
		for _, n in neighbours do
			if HexGrid.InLattice(n.q, n.r, radius) then
				return { q = n.q, r = n.r }
			end
		end
		return { q = 0, r = 0 }
	end
	-- Pick a random brood cell that is not the current one
	local candidates = {}
	for _, c in cells do
		if c.q ~= state.currentCell.q or c.r ~= state.currentCell.r then
			table.insert(candidates, c)
		end
	end
	if #candidates == 0 then return cells[1] end
	return candidates[math.random(1, #candidates)]
end

local function stepTowards(from: { q: number, r: number }, target: { q: number, r: number }, root: BasePart): { q: number, r: number }
	local neighbours = HexGrid.Neighbours(from.q, from.r)
	local floor = Config.QUEEN.walkFloor
	local radius = Config.FLOOR_RADIUS and Config.FLOOR_RADIUS[floor] or 4
	local best: { q: number, r: number }? = nil
	local bestDist = math.huge
	for _, n in neighbours do
		if HexGrid.InLattice(n.q, n.r, radius) then
			local d = math.abs(n.q - target.q) + math.abs(n.r - target.r) + math.abs((n.q + n.r) - (target.q + target.r))
			d = d / 2  -- axial hex distance
			if d < bestDist then
				bestDist = d
				best = { q = n.q, r = n.r }
			end
		end
	end
	return best or from
end

-- ============================================================
-- Heartbeat
-- ============================================================
local function onHeartbeat(dt: number)
	clock += dt
	local anyActive = false

	for plotIndex, state in queens do
		local model = state.model
		if not model then continue end
		anyActive = true

		local VISUALS = Config.QUEEN.VISUALS
		local vis = VISUALS[state.tier] or VISUALS[1]
		local root = state.plotRoot

		if state.state == "Laying" then
			if os.clock() >= state.layUntil then
				-- Pick next walk target
				local target = pickNextTarget(state)
				local nextCell = stepTowards(state.currentCell, target, root)
				local fromPos = cellPivot(root, state.currentCell.q, state.currentCell.r)
				local toPos = cellPivot(root, nextCell.q, nextCell.r)
				state.walkFrom = fromPos
				state.walkTo = toPos
				state.walkT = 0
				state.walkDuration = math.max(0.1, (toPos - fromPos).Magnitude / vis.walkSpeed)
				state.state = "Walking"
				-- Note where we're heading
				state.currentCell = nextCell
			else
				-- Dip gesture
				local t = os.clock() - (state.layUntil - vis.pauseSeconds)
				local halfDip = Config.QUEEN.layDipSeconds
				local dipY = 0
				if t < halfDip then
					dipY = -(t / halfDip) * Config.QUEEN.layDipStuds
				elseif t < halfDip * 2 then
					dipY = -((halfDip * 2 - t) / halfDip) * Config.QUEEN.layDipStuds
				end
				local basePos = cellPivot(root, state.currentCell.q, state.currentCell.r)
				model:PivotTo(CFrame.new(basePos + Vector3.new(0, dipY, 0)))
			end

		elseif state.state == "Walking" then
			state.walkT += dt / state.walkDuration
			if state.walkT >= 1 then
				state.walkT = 1
				-- Arrived
				flashCell(state, state.currentCell.q, state.currentCell.r, root)
				-- Sun Queen ripple
				if vis.ripple then
					local arrivedQ, arrivedR = state.currentCell.q, state.currentCell.r
					task.delay(Config.QUEEN.rippleDelaySeconds, function()
						local floor2 = Config.QUEEN.walkFloor
						local rad2 = Config.FLOOR_RADIUS and Config.FLOOR_RADIUS[floor2] or 4
						local stagger = 0
						for _, n in HexGrid.Neighbours(arrivedQ, arrivedR) do
							if HexGrid.InLattice(n.q, n.r, rad2) then
								local nq, nr = n.q, n.r
								task.delay(stagger, function()
									if queens[plotIndex] then
										flashCell(queens[plotIndex], nq, nr, root)
									end
								end)
								stagger += Config.QUEEN.rippleStaggerSeconds
							end
						end
					end)
				end
				state.state = "Laying"
				state.layUntil = os.clock() + vis.pauseSeconds
			else
				local pos = state.walkFrom:Lerp(state.walkTo, state.walkT)
				local lookDir = (state.walkTo - state.walkFrom).Unit
				if lookDir.Magnitude > 0.01 then
					model:PivotTo(CFrame.lookAt(pos, pos + lookDir))
				else
					model:PivotTo(CFrame.new(pos))
				end
			end

		elseif state.state == "Growing" then
			-- Growth is driven externally (QueenGrowth handler)
		end

		-- Attendants
		if state.attendantA and vis.attendants >= 1 then
			local qpivot = model:GetPivot().Position
			local angle = clock * Config.QUEEN.attendantOrbitRadPerSec
			state.attendantA:PivotTo(CFrame.new(
				qpivot + Vector3.new(
					math.cos(angle) * vis.orbitRadius,
					Config.QUEEN.attendantHeight,
					math.sin(angle) * vis.orbitRadius
				)
			))
		end
		if state.attendantB and vis.attendants >= 2 then
			local qpivot = model:GetPivot().Position
			local angle = clock * Config.QUEEN.attendantOrbitRadPerSec + math.pi
			state.attendantB:PivotTo(CFrame.new(
				qpivot + Vector3.new(
					math.cos(angle) * vis.orbitRadius,
					Config.QUEEN.attendantHeight,
					math.sin(angle) * vis.orbitRadius
				)
			))
		end
	end

	if not anyActive and heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function ensureHeartbeat()
	if not heartbeatConn then
		heartbeatConn = RunService.Heartbeat:Connect(onHeartbeat)
	end
end

-- ============================================================
-- Plot tracking
-- ============================================================
local lodTimers: { [number]: number } = {}
local lastLodCheck = 0

local function onPlotRootAdded(root: Instance)
	if not root:IsA("BasePart") then return end
	local plotIndex = root:GetAttribute("PlotIndex")
	if typeof(plotIndex) ~= "number" then return end

	local function update()
		local tier = root:GetAttribute("QueenTier") or 1
		local owner = root:GetAttribute("OwnerUserId") or 0
		if owner == 0 then
			despawnQueen(plotIndex)
			return
		end
		if shouldRender(root :: BasePart, owner) then
			local existing = queens[plotIndex]
			if not existing or existing.tier ~= tier or existing.ownerUserId ~= owner then
				spawnQueen(plotIndex, root :: BasePart, tier, owner)
				ensureHeartbeat()
			end
		else
			despawnQueen(plotIndex)
		end
	end

	root:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
	root:GetAttributeChangedSignal("QueenTier"):Connect(update)
	update()
end

local function onPlotRootRemoved(root: Instance)
	if not root:IsA("BasePart") then return end
	local plotIndex = root:GetAttribute("PlotIndex")
	if typeof(plotIndex) == "number" then
		despawnQueen(plotIndex)
	end
end

-- ============================================================
-- QueenGrowth moment
-- ============================================================
local function onQueenGrowth(payload: any)
	if typeof(payload) ~= "table" then return end
	local plotIndex = payload.plotIndex
	local p = payload.payload
	if typeof(plotIndex) ~= "number" or typeof(p) ~= "table" then return end
	local toTier = p.toTier
	local fromTier = p.fromTier
	if typeof(toTier) ~= "number" then return end

	local state = queens[plotIndex]
	if not state then return end
	if state.state == "Growing" then
		state.growthQueued = toTier
		return
	end

	state.state = "Growing"
	local VISUALS = Config.QUEEN.VISUALS
	local oldVis = VISUALS[fromTier] or VISUALS[1]
	local newVis = VISUALS[toTier] or VISUALS[1]
	local G = Config.QUEEN.growth
	local root = state.plotRoot

	-- Capture lights
	local combFolder = root.Parent and root.Parent:FindFirstChild("Comb")
	local capturedLights: { { light: PointLight, orig: number } } = {}
	if combFolder then
		for _, l in (combFolder :: Folder):GetDescendants() do
			if l:IsA("PointLight") then
				table.insert(capturedLights, { light = l :: PointLight, orig = (l :: PointLight).Brightness })
			end
		end
	end

	-- Dim lights
	for _, entry in capturedLights do
		TweenService:Create(entry.light, TweenInfo.new(G.dimSeconds / 2), { Brightness = entry.orig * G.dimTo }):Play()
	end

	-- Owner camera
	local isOwner = typeof(p.ownerUserId) == "number" and p.ownerUserId == Players.LocalPlayer.UserId
	local BuildController = require(script.Parent:WaitForChild("BuildController"))
	local camSaved: CFrame? = nil
	if isOwner and not BuildController.IsOn() then
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and state.model then
			local queenPos = state.model:GetPivot().Position
			if (hrp.Position - queenPos).Magnitude <= Config.QUEEN.camera.maxDistanceStuds then
				local cam = Workspace.CurrentCamera
				camSaved = cam.CFrame
				cam.CameraType = Enum.CameraType.Scriptable
				local C = Config.QUEEN.camera
				TweenService:Create(cam, TweenInfo.new(C.inSeconds), {
					CFrame = CFrame.lookAt(queenPos + Vector3.new(0, C.upStuds, -C.backStuds), queenPos)
				}):Play()
			end
		end
	end

	task.delay(G.dimSeconds / 2 + 0.1, function()
		-- Swap model
		if state.model then state.model:Destroy() end
		local Queens = RS.Templates:FindFirstChild("Queens")
		local template = Queens and Queens:FindFirstChild(newVis.template)
		if template then
			local newModel = (template :: Model):Clone()
			newModel.Parent = getCFXQueens()
			-- Scale from old/new ratio and tween to 1
			local ratio = oldVis.bodyLength / newVis.bodyLength
			local sv = Instance.new("NumberValue")
			sv.Value = ratio
			newModel:ScaleTo(ratio)
			newModel:PivotTo(CFrame.new(cellPivot(root, state.currentCell.q, state.currentCell.r)))
			state.model = newModel
			state.tier = toTier

			local tweenI = TweenInfo.new(G.growSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			local t = TweenService:Create(sv, tweenI, { Value = 1 })
			sv.Changed:Connect(function(v)
				if state.model then state.model:ScaleTo(v) end
			end)
			t:Play()

			task.delay(G.growSeconds, function()
				-- Burst
				if state.model then
					local burst = state.model:FindFirstChild("QueenRoot") and (state.model :: Model).QueenRoot:FindFirstChild("GrowthBurst") :: ParticleEmitter?
					if burst then burst:Emit(G.burstCount) end
				end
				-- Relight
				for _, entry in capturedLights do
					TweenService:Create(entry.light, TweenInfo.new(G.relightSeconds), { Brightness = entry.orig * G.relightPeak }):Play()
				end
				task.delay(G.relightSeconds, function()
					for _, entry in capturedLights do
						TweenService:Create(entry.light, TweenInfo.new(G.settleSeconds), { Brightness = entry.orig }):Play()
					end
				end)
				-- Restore camera
				task.delay(G.holdSeconds, function()
					if camSaved then
						local cam = Workspace.CurrentCamera
						if cam.CameraType == Enum.CameraType.Scriptable then
							TweenService:Create(cam, TweenInfo.new(Config.QUEEN.camera.outSeconds), { CFrame = camSaved }):Play()
							task.delay(Config.QUEEN.camera.outSeconds + 0.1, function()
								if Workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable then
									Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
								end
							end)
						end
					end
					-- Return to walk
					state.state = "Laying"
					state.layUntil = os.clock() + Config.QUEEN.growth.holdSeconds
					ensureHeartbeat()
					-- Process queued growth
					if state.growthQueued then
						local qt = state.growthQueued
						state.growthQueued = nil
						task.delay(0.2, function()
							onQueenGrowth({ plotIndex = plotIndex, payload = { fromTier = toTier, toTier = qt, ownerUserId = p.ownerUserId } })
						end)
					end
				end)
			end)
		else
			state.state = "Laying"
			state.layUntil = os.clock() + 1
			ensureHeartbeat()
		end
	end)
end

-- ============================================================
-- Init
-- ============================================================
function QueenController.Init()
	task.spawn(function()
		-- Listen for PlotRoot tags
		for _, root in CS:GetTagged("PlotRoot") do
			onPlotRootAdded(root)
		end
		CS:GetInstanceAddedSignal("PlotRoot"):Connect(onPlotRootAdded)
		CS:GetInstanceRemovedSignal("PlotRoot"):Connect(onPlotRootRemoved)

		-- Listen for CombCell changes (brood cells added/removed)
		CS:GetInstanceAddedSignal("CombCell"):Connect(function(cc)
			local plotIndex = cc:GetAttribute("PlotIndex")
			if typeof(plotIndex) == "number" and queens[plotIndex] then
				queens[plotIndex].broodCells = collectBroodCells(plotIndex)
			end
		end)
		CS:GetInstanceRemovedSignal("CombCell"):Connect(function(cc)
			local plotIndex = cc:GetAttribute("PlotIndex")
			if typeof(plotIndex) == "number" and queens[plotIndex] then
				queens[plotIndex].broodCells = collectBroodCells(plotIndex)
			end
		end)

		-- Listen for Moment remote
		local Remotes = RS:WaitForChild("Remotes")
		Remotes:WaitForChild("Moment").OnClientEvent:Connect(function(payload: any)
			if typeof(payload) == "table" and payload.id == "QueenGrowth" then
				onQueenGrowth(payload)
			end
		end)
	end)
end

return QueenController
]]

print("STEP I complete — QueenController created at", qc:GetFullName())
```

---

## STEP J — ClientMain wiring

```lua
-- STEP J: Wire QueenController into ClientMain
local SP = game:GetService("StarterPlayer")
local SPS = SP:WaitForChild("StarterPlayerScripts")
local orig = SPS:WaitForChild("ClientMain")

local clone = orig:Clone()
orig.Name = "ClientMain_BACKUP_" .. tick()
orig.Parent = nil
clone.Name = "ClientMain"
clone.Parent = SPS

local src = clone.Source

if not src:find("QueenController") then
	-- Find the last controller require+Init block and append after it
	-- Try after RetentionController
	src = src:gsub(
		"(local RetentionController%s*=%s*require%b().-RetentionController%.Init%b())",
		[[%1
	local QueenController = require(Controllers:WaitForChild("QueenController"))
	QueenController.Init()]]
	)
	-- Fallback: append before return or end of file
	if not src:find("QueenController") then
		src = src:gsub(
			"(return ClientMain)",
			[[local QueenController = require(Controllers:WaitForChild("QueenController"))
QueenController.Init()
%1]]
		)
	end
end

clone.Source = src
print("STEP J complete — ClientMain wired. QueenController:", src:find("QueenController") ~= nil)
```

---

## STEP K — Text fixes

```lua
-- STEP K: Text fixes — BuildController Royal tooltip + HelpGui Section7
local SP = game:GetService("StarterPlayer")
local Controllers = SP:WaitForChild("StarterPlayerScripts"):WaitForChild("Controllers")

-- 1. BuildController — Royal cell description
local origBC = Controllers:WaitForChild("BuildController")
local cloneBC = origBC:Clone()
origBC.Name = "BuildController_BACKUP_" .. tick()
origBC.Parent = nil
cloneBC.Name = "BuildController"
cloneBC.Parent = Controllers

local srcBC = cloneBC.Source
srcBC = srcBC:gsub(
	'Royal = ".-"',
	'Royal = "A Queen\'s cell for the outer edge of your comb. It makes Royal Jelly for every Brood Cell touching it -- spend jelly in HIVE > QUEEN to upgrade your queen!"'
)
cloneBC.Source = srcBC
print("STEP K-1 — BuildController Royal desc updated:", srcBC:find("HIVE > QUEEN") ~= nil)

-- 2. HelpGui Section7 body text
local SG = game:GetService("StarterGui")
local HelpGui = SG:FindFirstChild("HelpGui")
if HelpGui then
	local section7 = HelpGui:FindFirstChild("Section7", true)
	if section7 then
		local body = section7:FindFirstChild("Body")
		if body and body:IsA("TextLabel") then
			body.Text = "The Shop and Hive buttons are ready -- look on the left side of your screen! Build Royal cells touching Brood cells to make Royal Jelly, then upgrade your Queen in HIVE > QUEEN. Still coming soon: perks, taller comb floors, swarming, and dangers in the treeline. Stay tuned!"
			print("STEP K-2 — HelpGui Section7 updated")
		else
			warn("STEP K-2 — HelpGui.Section7.Body not found")
		end
	else
		warn("STEP K-2 — Section7 not found in HelpGui")
	end
end

print("STEP K complete — text fixes applied")
```

---

## STEP L — Verification

```lua
-- STEP L: Verify everything landed correctly
local results = {}
local issues = {}

-- 1. Config.QUEEN exists
local RS = game:GetService("ReplicatedStorage")
local ok, Config = pcall(require, RS:WaitForChild("Modules"):WaitForChild("Config"))
if ok and Config then
	local hasQueen = Config.QUEEN ~= nil
	local hasGenGate = Config.QUEEN_TIERS and Config.QUEEN_TIERS[5] and Config.QUEEN_TIERS[5].genGate == 1
	local hasRJProgress = Config.PROFILE_TEMPLATE and Config.PROFILE_TEMPLATE.royalJellyProgress ~= nil
	local v4 = Config.PROFILE_TEMPLATE and Config.PROFILE_TEMPLATE.version == 4
	table.insert(results, "Config: QUEEN=" .. tostring(hasQueen) .. " genGate=" .. tostring(hasGenGate) .. " royalJellyProgress=" .. tostring(hasRJProgress) .. " v4=" .. tostring(v4))
	if not hasQueen then table.insert(issues, "MISSING Config.QUEEN") end
	if not hasGenGate then table.insert(issues, "MISSING genGate on Q5") end
	if not hasRJProgress then table.insert(issues, "MISSING royalJellyProgress in PROFILE_TEMPLATE") end
else
	table.insert(issues, "CANNOT require Config: " .. tostring(Config))
end

-- 2. QueenService exists in Systems
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:WaitForChild("Systems")
local qs = Systems:FindFirstChild("QueenService")
table.insert(results, "QueenService: " .. (qs and "EXISTS" or "MISSING"))
if not qs then table.insert(issues, "MISSING QueenService") end
if qs then
	local lineCount = select(2, qs.Source:gsub("\n", "\n")) + 1
	table.insert(results, "  lines: " .. lineCount .. " (expect 150+)")
	if lineCount < 100 then table.insert(issues, "QueenService too short") end
end

-- 3. ResourceService has computeRoyalJellyPerSecond
local rs2 = Systems:FindFirstChild("ResourceService")
if rs2 then
	local hasRJFunc = rs2.Source:find("computeRoyalJellyPerSecond") ~= nil
	local hasRJRate = rs2.Source:find("royalJellyRate") ~= nil
	table.insert(results, "ResourceService: RJFunc=" .. tostring(hasRJFunc) .. " step4b=" .. tostring(hasRJRate))
	if not hasRJFunc then table.insert(issues, "ResourceService missing computeRoyalJellyPerSecond") end
	if not hasRJRate then table.insert(issues, "ResourceService missing step 4b") end
end

-- 4. Main has QueenService
local main = SSS:FindFirstChild("Main")
if main then
	table.insert(results, "Main QueenService: " .. (main.Source:find("QueenService") ~= nil and "WIRED" or "MISSING"))
	if not main.Source:find("QueenService") then table.insert(issues, "Main missing QueenService") end
end

-- 5. Queen templates
local Queens = RS.Templates:FindFirstChild("Queens")
local templateCount = Queens and #Queens:GetChildren() or 0
table.insert(results, "Templates.Queens: " .. templateCount .. " (expect 5)")
if templateCount < 5 then table.insert(issues, "Missing queen templates (found " .. templateCount .. "/5)") end
if Queens then
	for i = 1, 5 do
		local t = Queens:FindFirstChild("Queen_T" .. i)
		if t then
			local partCount = #t:GetDescendants()
			local hasPrimary = t.PrimaryPart ~= nil
			table.insert(results, "  Queen_T" .. i .. ": " .. partCount .. " descendants, PrimaryPart=" .. tostring(hasPrimary))
			if not hasPrimary then table.insert(issues, "Queen_T" .. i .. " missing PrimaryPart") end
		else
			table.insert(issues, "MISSING Queen_T" .. i)
		end
	end
end

-- 6. QueenController exists in StarterPlayerScripts
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local qc2 = SPS:WaitForChild("Controllers"):FindFirstChild("QueenController")
table.insert(results, "QueenController: " .. (qc2 and "EXISTS" or "MISSING"))
if not qc2 then table.insert(issues, "MISSING QueenController") end

-- 7. HiveGui QueenPage.Card has new elements
local SG = game:GetService("StarterGui")
local Card = SG:FindFirstChild("HiveGui", true) and SG.HiveGui.Panel.Pages.QueenPage.Card
if Card then
	local hasViewport = Card:FindFirstChild("PortraitFrame") and Card.PortraitFrame:FindFirstChild("QueenViewport") ~= nil
	local hasUpgradeBtn = Card:FindFirstChild("UpgradeButton") ~= nil
	local hasJellyFrame = Card:FindFirstChild("JellyFrame") ~= nil
	table.insert(results, "HiveGui QueenPage: viewport=" .. tostring(hasViewport) .. " upgradeBtn=" .. tostring(hasUpgradeBtn) .. " jellyFrame=" .. tostring(hasJellyFrame))
	if not hasViewport then table.insert(issues, "QueenPage missing QueenViewport") end
	if not hasUpgradeBtn then table.insert(issues, "QueenPage missing UpgradeButton") end
else
	table.insert(issues, "Cannot find HiveGui QueenPage.Card")
end

-- 8. RequestQueenUpgrade remote exists
local Remotes = RS:FindFirstChild("Remotes")
local rqr = Remotes and Remotes:FindFirstChild("RequestQueenUpgrade")
table.insert(results, "RequestQueenUpgrade remote: " .. (rqr and "EXISTS" or "MISSING — will be created by QueenService.Init() at runtime"))

-- Summary
local output = "=== CYCLE 10 QUEEN VERIFICATION ===\n" .. table.concat(results, "\n")
if #issues > 0 then
	output = output .. "\n\nISSUES:\n" .. table.concat(issues, "\n")
	print(output)
	print("\nACTION REQUIRED: fix issues above before running the game")
else
	output = output .. "\n\nALL CHECKS PASSED — Queen system ready!"
	print(output)
end
```

---

## POST-EXECUTION CHECKLIST

After all steps run without issues:

1. **Save the place** (Ctrl+S in Studio)
2. **Run a quick smoke test** (hit F5, open the HIVE > QUEEN tab, verify the portrait renders, verify UpgradeButton appears grey with "NEED X MORE JELLY")
3. **Build a Royal Cell on a Brood Cell rim** — the RJ rate should start ticking in the HIVE > QUEEN hint label within 30 seconds
4. **Check the Server Output** for any `[QueenService]` warnings about Config drift

---

## KNOWN LIMITATIONS

- `RequestQueenUpgrade` remote is created by QueenService.Init() at server startup — it won't appear in the Explorer until the game runs. Verification step L-8 will show "MISSING" in Edit mode, which is expected.
- Sun Queen (T5) requires `profile.generation >= 1` (genGate). Since SwarmService doesn't exist yet, generation is always 0. The Sun Queen is deliberately locked until swarming ships. To unlock it for testing, change `genGate = 1` to `genGate = 0` in Config.
- The `ComputeRoyalJellyPerSecond` patches use pattern matching on source. If the source has been significantly reformatted since this dispatch was written, some patterns may fail to find their insertion point. In that case the verification (step L-3) will flag which functions are missing and you can insert them manually.

---

## DISPATCH COMPLETE

**What was built:**
- DataService v11→v12 migration (royalJellyProgress accumulator + queenTier normalisation clamp)
- Config.QUEEN block (all visual/timing constants for client renderer)
- Config.QUEEN_TIERS: genGate=1 on Sun Queen (T5)
- ResourceService: Royal Jelly production (computeRoyalJellyPerSecond, step 4b fractional accumulator)
- QueenService: server authority (CanUpgrade 4-check chain, Upgrade spend+broadcast, HasUnlock API)
- Main: QueenService wired
- Templates.Queens: 5 queen models (T1 Virgin through T5 Sun Queen, all primitives)
- HiveGui QueenPage: rebuilt (portrait viewport, jelly bar, upgrade button, discovery badges)
- HiveController: queen rendering state machine, onWalletUpdate, onMoment, submitQueenUpgrade
- QueenController: client-only queen walker (LOD, walk state machine, amber footprints, attendants, QueenGrowth moment choreography)
- ClientMain: QueenController wired
- Text fixes: BuildController Royal cell description, HelpGui Section7

**Part budget:** 0 server parts added. Client-side only.
**DataService version:** v12
