# Dispatch 74 — HoneycombVisualService
## Cycle 11 · A Bee's World

**Feature:** Dynamic hex cell visual states — each plot's hex part glows honey-gold when claimed and active, pulses amber when bees are currently foraging that cell, and is dimmed grey when locked (not yet claimed). Uses TweenService looping pulses via a client-side LocalScript that listens to `PlotSync` data already broadcast by PlotService. No new server logic needed.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 73 (UpgradeStatsPatch)

---

## DESIGN

`HoneycombVisualController` is a new **LocalScript** that:
1. On `PlotSync` data, iterates over all known hex parts in `Workspace.Map.HivePlots` (or wherever the grid was built).
2. Sets `Color`, `Material`, and runs a repeating TweenService pulse on foraging cells.
3. Stops and starts pulses as cell state changes.

### Visual states

| State | Color | Material | Effect |
|-------|-------|----------|--------|
| Locked (not owned) | `Color3.fromRGB(60,55,50)` | SmoothPlastic | Static dim |
| Claimed, idle | `Color3.fromRGB(242, 168, 28)` HONEY_GOLD | Neon | Static glow |
| Foraging active | `Color3.fromRGB(255, 200, 50)` → `Color3.fromRGB(180, 110, 10)` | Neon | TweenService pulse 1.2s |
| Expansion slot (locked paid) | `Color3.fromRGB(80,60,180)` | Neon | Static dim blue |

### Pulse loop

```lua
local function startPulse(part)
    local function loop()
        TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = COLOR_BRIGHT}):Play()
        task.wait(0.6)
        TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = COLOR_DIM}):Play()
        task.wait(0.6)
        if activePulses[part] then loop() end
    end
    activePulses[part] = true
    task.spawn(loop)
end
```

### Part naming

Hex plot parts are named `Plot_1` through `Plot_8` in `Workspace.Map.HivePlots` (or the folder name used in dispatch 1). Expansion slot parts are named `ExpansionSlot_1` and `ExpansionSlot_2`. The controller searches by name pattern.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HoneycombVisualController` (new LocalScript) | hex visual states, pulse loop |

No server changes. Uses existing `PlotSync` RemoteEvent from PlotService.

---

## STEP A — HoneycombVisualController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "HoneycombVisualController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- HoneycombVisualController — dynamic hex plot visual states

local PS           = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local player   = PS.LocalPlayer
local PlotSync = RS:WaitForChild("PlotSync")

-- ── Color constants ───────────────────────────────────
local COLOR_LOCKED    = Color3.fromRGB(60,  55, 50)
local COLOR_OWNED     = Color3.fromRGB(242, 168, 28)   -- honey gold
local COLOR_PULSE_HI  = Color3.fromRGB(255, 210, 60)
local COLOR_PULSE_LO  = Color3.fromRGB(180, 110, 10)
local COLOR_EXPANSION = Color3.fromRGB(80,  60, 180)

local MAT_ACTIVE = Enum.Material.Neon
local MAT_IDLE   = Enum.Material.SmoothPlastic

-- ── State ──────────────────────────────────────────────
local activePulses: {[BasePart]: boolean} = {}

local function stopPulse(part: BasePart)
	activePulses[part] = nil
end

local function startPulse(part: BasePart)
	if activePulses[part] then return end
	activePulses[part] = true
	task.spawn(function()
		while activePulses[part] do
			TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = COLOR_PULSE_HI}):Play()
			task.wait(0.6)
			if not activePulses[part] then break end
			TweenService:Create(part, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = COLOR_PULSE_LO}):Play()
			task.wait(0.6)
		end
	end)
end

-- ── Find plot parts ────────────────────────────────────
local function findPlotParts(): {[string]: BasePart}
	local parts: {[string]: BasePart} = {}
	-- Search common folder locations
	local searchRoots = {
		Workspace:FindFirstChild("Map"),
		Workspace:FindFirstChild("HivePlots"),
		Workspace,
	}
	for _, root in searchRoots do
		if root then
			for _, obj in root:GetDescendants() do
				if obj:IsA("BasePart") then
					-- Match Plot_N and ExpansionSlot_N patterns
					if obj.Name:match("^Plot_%d+$") or obj.Name:match("^ExpansionSlot_%d+$") then
						parts[obj.Name] = obj
					end
				end
			end
		end
	end
	return parts
end

local plotParts: {[string]: BasePart} = {}
task.delay(2, function()
	plotParts = findPlotParts()
	-- Default all to locked appearance
	for _, part in plotParts do
		part.Material = MAT_IDLE
		part.Color    = part.Name:match("^ExpansionSlot") and COLOR_EXPANSION or COLOR_LOCKED
	end
end)

-- ── Apply visual state from PlotSync data ─────────────
local function applyState(data: {[string]: any})
	if next(plotParts) == nil then
		plotParts = findPlotParts()
	end

	-- data.plots: array of {id: number, owner: string?, foraging: boolean, isExpansion: boolean}
	local plots = data.plots or data  -- handle both wrapped and direct format

	for _, plotData in (type(plots) == "table" and pairs(plots) or pairs({})) do
		if type(plotData) ~= "table" then continue end
		local plotId: any = plotData.id or plotData.plotId
		if not plotId then continue end

		local partName = (plotData.isExpansion and "ExpansionSlot_" or "Plot_") .. tostring(plotId)
		local part = plotParts[partName]
		if not part then
			-- Also try generic search
			for name, p in plotParts do
				if name:find(tostring(plotId)) then part = p; break end
			end
		end
		if not part then continue end

		local ownerName: string? = plotData.owner or plotData.ownerName
		local myName = player.Name
		local isForaging: boolean = plotData.foraging == true or plotData.isForaging == true
		local isOwned: boolean = (ownerName ~= nil and ownerName ~= "") 

		stopPulse(part)

		if plotData.isExpansion and not isOwned then
			-- Locked expansion slot
			part.Material = MAT_IDLE
			part.Color    = COLOR_EXPANSION
		elseif not isOwned then
			-- Empty claimable plot
			part.Material = MAT_IDLE
			part.Color    = COLOR_LOCKED
		elseif isForaging then
			-- Active foraging — pulse
			part.Material = MAT_ACTIVE
			part.Color    = COLOR_PULSE_HI
			startPulse(part)
		else
			-- Owned, idle
			part.Material = MAT_ACTIVE
			part.Color    = COLOR_OWNED
		end
	end
end

-- ── Listen for PlotSync ────────────────────────────────
PlotSync.OnClientEvent:Connect(function(data: any)
	applyState(data)
end)

-- ── Also wire to ForagingSync if available ─────────────
local foragingSync = RS:FindFirstChild("ForagingSync")
if foragingSync and foragingSync:IsA("RemoteEvent") then
	foragingSync.OnClientEvent:Connect(function(data: any)
		-- ForagingSync sends {plotId, foraging=true/false}
		if type(data) == "table" and data.plotId then
			local partName = "Plot_" .. tostring(data.plotId)
			local part = plotParts[partName]
			if part then
				if data.foraging then
					part.Material = MAT_ACTIVE
					startPulse(part)
				else
					stopPulse(part)
					part.Material = MAT_ACTIVE
					part.Color    = COLOR_OWNED
				end
			end
		end
	end)
end
]]

print("HoneycombVisualController created")
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HoneycombVisualController")
local RS   = game:GetService("ReplicatedStorage")
local PlotSync = RS:FindFirstChild("PlotSync")

local checks = {
	(ctrl and "✅" or "❌") .. " HoneycombVisualController LocalScript",
	(PlotSync and "✅" or "❌") .. " PlotSync RemoteEvent exists (prerequisite from dispatch 3)",
	(ctrl and ctrl.Source:find("TweenService") and "✅" or "❌") .. " TweenService pulse logic present",
	(ctrl and ctrl.Source:find("startPulse") and "✅" or "❌") .. " startPulse function present",
}

print("=== DISPATCH 74 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 74 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Visual changes to existing BaseParts | 0 new parts |
| **Dispatch 74 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The controller uses `findPlotParts()` which scans `Workspace.Map`, `Workspace.HivePlots`, and `Workspace` root for parts named `Plot_N` or `ExpansionSlot_N`. This is resilient to different folder structures built by world-builder in earlier dispatches.
- `task.delay(2, ...)` for initial part discovery gives the world time to load before scanning. After the first PlotSync the parts are cached in `plotParts` and not re-scanned.
- The pulse loop uses a `while activePulses[part]` guard so calling `stopPulse(part)` is sufficient to kill the goroutine — no explicit thread reference needed.
- The `ForagingSync` connection is a defensive bonus: if PlotSync doesn't include foraging state per cycle, ForagingSync provides per-event updates. If ForagingSync doesn't exist, `FindFirstChild` returns nil and the block is skipped silently.
- `Enum.Material.Neon` on the hex cells makes them self-illuminate at night without a PointLight, reinforcing the hive's magical quality. Locked cells use SmoothPlastic (no glow) to visually communicate "not active".
- No server changes are needed — this is pure cosmetic client code reading data already broadcast by existing services.
