# Dispatch 194 — Moonflower Bloom Signature Moment
**File:** `cycle18_moonflower_bloom_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture lists **Signature Moment 7: Moonflower Bloom** — a rare server-wide event where Moonflower and Aurora Bloom patches (species 7 & 8, generation-gated) enter a bloom window late at night. This dispatch implements the complete moment: a `MoonflowerService` server ModuleScript that detects the bloom window based on server clock and fires a `MoonflowerBloom` RemoteEvent to all clients, plus a `MoonflowerController` LocalScript that shows the client-side celebration — a blue-silver BillboardGui glow on every active Moonflower/AuroraBloom patch, a sky tint shift to deep indigo, and a 5-second shared server-wide announcement toast. The bloom triggers once per night cycle (when ClockTime passes 22.0) and lasts 90 seconds real-time.

Zero new permanent parts. Zero DataService changes (no persistent state needed — bloom is a transient server event, not persisted to profile).

---

## Step 1 — MoonflowerService (ServerScriptService → Systems)

Open **ServerScriptService → Systems** and create a new **ModuleScript** named `MoonflowerService`.

Paste exactly:

```lua
--!strict
-- MoonflowerService: detects Moonflower/AuroraBloom bloom window and broadcasts
-- the MoonflowerBloom RemoteEvent to all clients. Pure server logic.

local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

-- ── Config ────────────────────────────────────────────────────────────────────
local BLOOM_CLOCK_START_194 = 22.0   -- ClockTime to start bloom
local BLOOM_CLOCK_END_194   = 24.0   -- ClockTime to end (wraps at 24)
local BLOOM_DURATION_194    = 90     -- seconds the bloom event stays active
local BLOOM_COOLDOWN_194    = 600    -- seconds before bloom can trigger again (10 min)
local BLOOM_SPECIES_194     = { "Moonflower", "AuroraBloom" }  -- tag or Species attr values

-- ── State ─────────────────────────────────────────────────────────────────────
local bloomActive_194  = false
local lastBloomEnd_194 = 0
local bloomTimer_194   = 0

local MoonflowerService = {}

-- ── Broadcast to all clients ──────────────────────────────────────────────────
local function broadcast_194(eventType: string, data: { [string]: any })
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	local ev = remotes:FindFirstChild("MoonflowerBloom") :: RemoteEvent?
	if not ev then return end
	ev:FireAllClients({ eventType = eventType, data = data })
end

-- ── Gather active bloom patches ───────────────────────────────────────────────
local function getBloomPatches_194(): { BasePart }
	local results: { BasePart } = {}
	for _, obj in CollectionService:GetTagged("FlowerPatch") do
		if not obj:IsA("BasePart") then continue end
		local species = obj:GetAttribute("Species") :: string?
		if not species then continue end
		for _, bloomSpecies in BLOOM_SPECIES_194 do
			if species == bloomSpecies then
				table.insert(results, obj)
				break
			end
		end
	end
	return results
end

-- ── Start bloom ───────────────────────────────────────────────────────────────
local function startBloom_194()
	bloomActive_194 = true
	bloomTimer_194  = BLOOM_DURATION_194

	local patches = getBloomPatches_194()
	local patchData: { { plotIdx: number, posX: number, posZ: number } } = {}
	for _, p in patches do
		table.insert(patchData, {
			plotIdx = p:GetAttribute("PlotIndex") or 0,
			posX    = math.round(p.Position.X),
			posZ    = math.round(p.Position.Z),
		})
	end

	broadcast_194("BloomStart", {
		duration    = BLOOM_DURATION_194,
		patchCount  = #patches,
		patchData   = patchData,
	})
end

-- ── End bloom ─────────────────────────────────────────────────────────────────
local function endBloom_194()
	bloomActive_194  = false
	lastBloomEnd_194 = os.clock()
	bloomTimer_194   = 0
	broadcast_194("BloomEnd", {})
end

-- ── Main tick ─────────────────────────────────────────────────────────────────
local lastClock_194   = 0
local bloomCheckAcc_194 = 0
local BLOOM_CHECK_INTERVAL = 1.0   -- check once per second

function MoonflowerService.Start()
	RunService.Heartbeat:Connect(function(dt)
		bloomCheckAcc_194 = bloomCheckAcc_194 + dt

		if bloomCheckAcc_194 < BLOOM_CHECK_INTERVAL then return end
		bloomCheckAcc_194 = 0

		local clockTime = Lighting.ClockTime
		local inWindow  = clockTime >= BLOOM_CLOCK_START_194 or clockTime < 2.0
		-- (wraps: midnight 0..2 also counts)

		if bloomActive_194 then
			bloomTimer_194 = bloomTimer_194 - BLOOM_CHECK_INTERVAL
			if bloomTimer_194 <= 0 then
				endBloom_194()
			end
		else
			-- Only trigger if enough time passed since last bloom AND in window
			local sinceLastBloom = os.clock() - lastBloomEnd_194
			if inWindow and sinceLastBloom >= BLOOM_COOLDOWN_194 then
				-- Detect the moment we crossed BLOOM_CLOCK_START_194
				local crossed = lastClock_194 < BLOOM_CLOCK_START_194 and clockTime >= BLOOM_CLOCK_START_194
				if crossed then
					startBloom_194()
				end
			end
		end

		lastClock_194 = clockTime
	end)
end

function MoonflowerService.IsActive(): boolean
	return bloomActive_194
end

return MoonflowerService
```

---

## Step 2 — MoonflowerBloom RemoteEvent

If `MoonflowerBloom` does not already exist in `ReplicatedStorage.Remotes`, add it:

```lua
-- Studio Command Bar (Edit mode):
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if remotes and not remotes:FindFirstChild("MoonflowerBloom") then
	local ev = Instance.new("RemoteEvent")
	ev.Name   = "MoonflowerBloom"
	ev.Parent = remotes
	print("Created MoonflowerBloom RemoteEvent")
else
	print("MoonflowerBloom already exists")
end
```

---

## Step 3 — Wire MoonflowerService into Main bootstrap

Open **ServerScriptService → Main** and add:

```lua
local MoonflowerService = require(Systems.MoonflowerService)
-- ... (after other service requires)
MoonflowerService.Start()
```

---

## Step 4 — MoonflowerController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `MoonflowerController`.

Paste exactly:

```lua
--!strict
-- MoonflowerController: client-side Moonflower Bloom ceremony.
-- Listens to MoonflowerBloom RemoteEvent, shows sky tint + patch glows + shared toast.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local Lighting          = game:GetService("Lighting")

local player = Players.LocalPlayer

-- ── Palette ───────────────────────────────────────────────────────────────────
local MOON_BLUE_194   = Color3.fromRGB( 60,  80, 180)
local AURORA_TEAL_194 = Color3.fromRGB( 40, 160, 140)
local SILVER_194      = Color3.fromRGB(200, 210, 240)
local DARK_NIGHT_194  = Color3.fromRGB(  8,   5,  22)
local WAX_CREAM_194   = Color3.fromRGB(232, 212, 154)

-- ── Sky tint overlay ──────────────────────────────────────────────────────────
local skyGui_194: ScreenGui?
local skyFrame_194: Frame?
local toastLbl_194: TextLabel?

local function ensureSkyGui_194()
	if skyGui_194 and skyGui_194.Parent then return end
	local pg = player:WaitForChild("PlayerGui", 5) :: PlayerGui?
	if not pg then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "MoonflowerSkyGui_194"
	sg.DisplayOrder   = 8    -- behind HiveGui but above world
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local sky = Instance.new("Frame")
	sky.Name                   = "SkyTint"
	sky.Size                   = UDim2.new(1, 0, 1, 0)
	sky.BackgroundColor3       = MOON_BLUE_194
	sky.BackgroundTransparency = 1
	sky.BorderSizePixel        = 0
	sky.ZIndex                 = 1
	sky.Parent                 = sg

	-- Toast banner centred 35% from top
	local toast = Instance.new("TextLabel")
	toast.Name               = "BloomToast"
	toast.Size               = UDim2.new(0, 320, 0, 48)
	toast.AnchorPoint        = Vector2.new(0.5, 0.5)
	toast.Position           = UDim2.new(0.5, 0, 0.35, 0)
	toast.BackgroundColor3   = DARK_NIGHT_194
	toast.BackgroundTransparency = 1   -- starts invisible
	toast.BorderSizePixel    = 0
	toast.Text               = "🌙 Moonflower bloom!\nForage now for rare nectar ✨"
	toast.TextSize           = 16
	toast.Font               = Enum.Font.GothamBold
	toast.TextColor3         = SILVER_194
	toast.TextWrapped        = true
	toast.TextXAlignment     = Enum.TextXAlignment.Center
	toast.RichText           = false
	toast.ZIndex             = 2
	toast.Parent             = sg

	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 10)
	tc.Parent       = toast

	skyGui_194   = sg
	skyFrame_194 = sky
	toastLbl_194 = toast
end

-- ── Patch glow BillboardGuis ──────────────────────────────────────────────────
local patchGlows_194: { BillboardGui } = {}

local function addPatchGlow_194(patch: BasePart)
	local bg = Instance.new("BillboardGui")
	bg.Name                      = "MoonGlow_194"
	bg.Size                      = UDim2.new(0, 70, 0, 22)
	bg.StudsOffset               = Vector3.new(0, 3, 0)
	bg.AlwaysOnTop               = false
	bg.ResetOnSpawn              = false
	bg.Parent                    = patch

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_NIGHT_194
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = MOON_BLUE_194
	stroke.Thickness = 1.2
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "🌙 Rare nectar!"
	lbl.TextSize           = 11
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = SILVER_194
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	table.insert(patchGlows_194, bg)
end

local function clearPatchGlows_194()
	for _, bg in patchGlows_194 do
		if bg.Parent then bg:Destroy() end
	end
	patchGlows_194 = {}
end

-- ── Show bloom ────────────────────────────────────────────────────────────────
local function showBloom_194(duration: number)
	ensureSkyGui_194()

	-- Sky tint fade in
	if skyFrame_194 then
		TweenService:Create(skyFrame_194, TweenInfo.new(2.5, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 0.85,
		}):Play()
	end

	-- Toast fade in then out after 5 seconds
	if toastLbl_194 then
		TweenService:Create(toastLbl_194, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 0.12,
			TextTransparency       = 0,
		}):Play()
		task.delay(5, function()
			if not toastLbl_194 or not toastLbl_194.Parent then return end
			TweenService:Create(toastLbl_194, TweenInfo.new(0.8, Enum.EasingStyle.Sine), {
				BackgroundTransparency = 1,
				TextTransparency       = 1,
			}):Play()
		end)
	end

	-- Add glow BillboardGuis to Moonflower/AuroraBloom patches
	for _, obj in CollectionService:GetTagged("FlowerPatch") do
		if not obj:IsA("BasePart") then continue end
		local species = obj:GetAttribute("Species") :: string?
		if species == "Moonflower" or species == "AuroraBloom" then
			addPatchGlow_194(obj)
		end
	end

	-- After duration, hide everything
	task.delay(duration, function()
		hideBloom_194()
	end)
end

-- ── Hide bloom ────────────────────────────────────────────────────────────────
function hideBloom_194()
	if skyFrame_194 and skyFrame_194.Parent then
		TweenService:Create(skyFrame_194, TweenInfo.new(3.0, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 1,
		}):Play()
	end
	task.delay(3.0, clearPatchGlows_194)
end

-- ── Listen for server event ───────────────────────────────────────────────────
local function waitForRemote_194()
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:WaitForChild("Remotes", 15)
	if not remotes then return end
	local ev = remotes:WaitForChild("MoonflowerBloom", 15) :: RemoteEvent?
	if not ev then return end

	ev.OnClientEvent:Connect(function(payload: { eventType: string, data: { [string]: any } }?)
		if typeof(payload) ~= "table" then return end
		if payload.eventType == "BloomStart" then
			local dur = (payload.data and payload.data.duration) or 90
			task.spawn(showBloom_194, dur)
		elseif payload.eventType == "BloomEnd" then
			task.spawn(hideBloom_194)
		end
	end)
end

task.delay(2, waitForRemote_194)
```

---

## Step 5 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("MoonflowerController"))
```

---

## Step 6 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Check scripts
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("MoonflowerController")
print("MoonflowerController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  showBloom_194:", c.Source:find("showBloom_194") ~= nil)
	print("  clearPatchGlows:", c.Source:find("clearPatchGlows_194") ~= nil)
end

local Systems = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local ms = Systems and Systems:FindFirstChild("MoonflowerService")
print("MoonflowerService:", ms and ms.ClassName or "MISSING")

-- Check MoonflowerBloom remote
local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local ev = remotes and remotes:FindFirstChild("MoonflowerBloom")
print("MoonflowerBloom RemoteEvent:", ev and ev.ClassName or "MISSING")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
MoonflowerController: LocalScript
  lines: 180+
  showBloom_194: true
  clearPatchGlows: true
MoonflowerService: ModuleScript
MoonflowerBloom RemoteEvent: RemoteEvent
Total parts: 4204  (expect 4204)
```

### Manual smoke-test (Play mode)

```lua
-- Force a bloom event to all clients immediately:
local remotes = game:GetService("ReplicatedStorage").Remotes
local ev = remotes:FindFirstChild("MoonflowerBloom")
if ev then
	ev:FireAllClients({ eventType = "BloomStart", data = { duration = 30 } })
	print("Bloom fired — watch for sky tint + 🌙 toast + patch glows")
end
```

---

## Behaviour summary

| State | Sky | Toast | Patch badge | Duration |
|---|---|---|---|---|
| BloomStart | Indigo tint fades in (Transparency 0.85) | "🌙 Moonflower bloom! Forage now…" shows 5s then fades | "🌙 Rare nectar!" BillboardGui on Moonflower/AuroraBloom patches | 90s real-time |
| BloomEnd / timeout | Sky tint fades out (3s) | (already gone) | Glows destroyed | — |

- Triggers when `Lighting.ClockTime` crosses 22.0 (after-dark) — works with the existing day/night cycle
- 10-minute cooldown prevents multiple blooms per session
- Aurora Bloom patches (species 8) show the same glow as Moonflower (species 7) — both are rare night species
- All clients see the bloom simultaneously (server fires to all)
- No DataService changes — bloom state is not persisted (it's a transient server event)

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BillboardGui + Frame GuiObjects on FlowerPatch BaseParts — GuiObjects are not BaseParts, zero part budget impact)*
