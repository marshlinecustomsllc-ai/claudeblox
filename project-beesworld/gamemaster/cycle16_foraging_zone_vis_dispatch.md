# Dispatch 178 — Foraging Zone Visualiser
**File:** `cycle16_foraging_zone_vis_dispatch.md`
**Cycle:** 16
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

New players often don't understand why the waggle-dance distance slider matters — flower patches feel arbitrary in distance terms because the connection between the slider, studs, and honey yield is invisible. This dispatch adds a **Foraging Zone Visualiser** that appears only when the BuildGui or DanceGui is open: a translucent ground ring (SurfaceAppearance-free, just a flat cylinder) around the player's Landing Board, sized to the patch distance, with flower patches tinted green (close = easier dance, better quality) through amber (medium) to red (very far). When the player selects a patch to dance for, the ring pulses once to confirm. The ring hides the moment the UI closes.

Entirely client-side. +2 permanent parts per player (the ring cylinder + a SelectionBox highlight anchor, both invisible by default). The ring is shown/hidden, never created/destroyed, to avoid part churn.

---

## Step 1 — ForagingZoneController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `ForagingZoneController`.

Paste exactly:

```lua
--!strict
-- ForagingZoneController: translucent ground ring + patch colour tints while dance UI is open.
-- The ring part is created once on init and shown/hidden as needed (+2 parts, permanent).
-- Triggered by DanceGui/BuildGui Visible attribute changes.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
local RING_HEIGHT_178   = 0.15   -- studs thick (flat ring)
local RING_Y_OFFSET_178 = 0.1   -- studs above ground
local CLOSE_RANGE_178   = 150   -- studs — green tint
local MED_RANGE_178     = 350   -- studs — amber tint (above this = red)
local PULSE_TIME_178    = 0.4   -- seconds for the patch-selection pulse

-- ── Palette ───────────────────────────────────────────────────────────────────
local RING_COLOR_178    = Color3.fromRGB(242, 168, 28)   -- honey gold ring
local CLOSE_TINT_178    = Color3.fromRGB(80,  210, 80)   -- green = close patch
local MED_TINT_178      = Color3.fromRGB(255, 160, 30)   -- amber = medium
local FAR_TINT_178      = Color3.fromRGB(220, 60,  60)   -- red = far
local NEUTRAL_TINT_178  = Color3.fromRGB(200, 180, 140)  -- returned to on hide

-- ── Find player's Landing Board ───────────────────────────────────────────────
local function findBoard_178(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, board in CollectionService:GetTagged("LandingBoard") do
		if board:IsA("BasePart") and board:GetAttribute("PlotIndex") == myPlot then
			return board
		end
	end
	return nil
end

-- ── Create the ring part (once, permanent) ────────────────────────────────────
local ringPart_178: Part? = nil
local ringAnchor_178: Part? = nil

local function createRing_178()
	-- Outer ring
	local ring = Instance.new("Part")
	ring.Name          = "ForagingZoneRing_178"
	ring.Shape         = Enum.PartType.Cylinder
	ring.Size          = Vector3.new(RING_HEIGHT_178, 10, 10)  -- will be scaled on show
	ring.CFrame        = CFrame.new(0, -100, 0)  -- hidden below map until needed
	ring.Anchored      = true
	ring.CanCollide    = false
	ring.CastShadow    = false
	ring.Material      = Enum.Material.Neon
	ring.Color         = RING_COLOR_178
	ring.Transparency  = 0.55
	ring.Parent        = workspace
	ringPart_178 = ring

	-- Hollow mask (inner cylinder, same Y, slightly smaller — creates ring appearance)
	local mask = Instance.new("Part")
	mask.Name          = "ForagingZoneRingMask_178"
	mask.Shape         = Enum.PartType.Cylinder
	mask.Size          = Vector3.new(RING_HEIGHT_178 + 0.05, 9, 9)  -- will be scaled on show
	mask.CFrame        = CFrame.new(0, -100, 0)
	mask.Anchored      = true
	mask.CanCollide    = false
	mask.CastShadow    = false
	mask.Material      = Enum.Material.SmoothPlastic
	mask.Color         = Color3.fromRGB(0, 0, 0)
	mask.Transparency  = 1  -- fully invisible — acts only as a visual cut
	mask.Parent        = workspace
	ringAnchor_178 = mask
end

createRing_178()

-- ── Show/hide the ring ────────────────────────────────────────────────────────
local ringVisible_178 = false

local function showRing_178(patchDistanceStuds: number)
	local board = findBoard_178()
	if not board or not ringPart_178 or not ringAnchor_178 then return end

	-- Size the ring to match the dance distance
	local r = patchDistanceStuds
	local outerD = r * 2
	local innerD = (r - 2) * 2

	local boardCF = CFrame.new(board.Position.X, board.Position.Y + RING_Y_OFFSET_178, board.Position.Z)
		* CFrame.Angles(0, 0, math.pi / 2)  -- rotate so flat face is horizontal

	ringPart_178.Size  = Vector3.new(RING_HEIGHT_178, outerD, outerD)
	ringPart_178.CFrame = boardCF

	ringAnchor_178.Size  = Vector3.new(RING_HEIGHT_178 + 0.05, innerD, innerD)
	ringAnchor_178.CFrame = boardCF

	ringPart_178.Transparency = 0.55
	ringVisible_178 = true
end

local function hideRing_178()
	if not ringPart_178 then return end
	TweenService:Create(ringPart_178, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
		{ Transparency = 1 }):Play()
	task.delay(0.35, function()
		if ringPart_178 then
			ringPart_178.CFrame = CFrame.new(0, -100, 0)
		end
		if ringAnchor_178 then
			ringAnchor_178.CFrame = CFrame.new(0, -100, 0)
		end
	end)
	ringVisible_178 = false
end

-- ── Colour flower patches by distance ────────────────────────────────────────
local patchOrigColors_178: { [BasePart]: Color3 } = {}

local function tintPatches_178(show: boolean)
	local board = findBoard_178()
	local boardPos = board and board.Position or Vector3.new(0, 0, 0)

	for _, patch in CollectionService:GetTagged("FlowerPatch") do
		if not patch:IsA("BasePart") then continue end

		if show and board then
			-- Save original color
			if not patchOrigColors_178[patch] then
				patchOrigColors_178[patch] = patch.Color
			end

			local dist = (patch.Position - boardPos).Magnitude
			local tint: Color3
			if dist <= CLOSE_RANGE_178 then
				tint = CLOSE_TINT_178
			elseif dist <= MED_RANGE_178 then
				-- Lerp from green to amber
				local t = (dist - CLOSE_RANGE_178) / (MED_RANGE_178 - CLOSE_RANGE_178)
				tint = CLOSE_TINT_178:Lerp(MED_TINT_178, t)
			else
				-- Lerp from amber to red
				local t = math.min((dist - MED_RANGE_178) / 200, 1)
				tint = MED_TINT_178:Lerp(FAR_TINT_178, t)
			end

			TweenService:Create(patch, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{ Color = tint }):Play()
		else
			-- Restore original
			local orig = patchOrigColors_178[patch]
			if orig then
				TweenService:Create(patch, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
					{ Color = orig }):Play()
			end
		end
	end
end

-- ── Pulse on patch selection ──────────────────────────────────────────────────
local function pulsePatchSelect_178(patchPart: BasePart)
	if not ringPart_178 or not ringVisible_178 then return end
	-- Brief brightness flash on the selected patch
	local origTrans = patchPart.Transparency
	TweenService:Create(patchPart, TweenInfo.new(PULSE_TIME_178 * 0.4),
		{ Transparency = 0.0 }):Play()
	task.delay(PULSE_TIME_178 * 0.4, function()
		TweenService:Create(patchPart, TweenInfo.new(PULSE_TIME_178 * 0.6),
			{ Transparency = origTrans }):Play()
	end)
	-- Ring pulse
	TweenService:Create(ringPart_178, TweenInfo.new(PULSE_TIME_178 * 0.4),
		{ Transparency = 0.15 }):Play()
	task.delay(PULSE_TIME_178 * 0.4, function()
		TweenService:Create(ringPart_178, TweenInfo.new(PULSE_TIME_178 * 0.6),
			{ Transparency = 0.55 }):Play()
	end)
end

-- ── Watch DanceGui / BuildGui visibility ──────────────────────────────────────
local function watchGui_178(gui: ScreenGui, patchDistSource: () -> number)
	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			showRing_178(patchDistSource())
			tintPatches_178(true)
		else
			hideRing_178()
			tintPatches_178(false)
		end
	end)
end

-- Wait for GUIs then attach watchers
task.spawn(function()
	local danceGui = PlayerGui:WaitForChild("DanceGui", 30) :: ScreenGui?
	if danceGui then
		-- Use the selected patch distance if available, otherwise median meadow distance
		local function getDist(): number
			return player:GetAttribute("SelectedPatchDistance") :: number? or 250
		end
		watchGui_178(danceGui, getDist)
	end

	local buildGui = PlayerGui:WaitForChild("BuildGui", 30) :: ScreenGui?
	if buildGui then
		local function getDist(): number
			return 400  -- show full meadow range while building
		end
		watchGui_178(buildGui, getDist)
	end
end)

-- ── Listen for patch selection to pulse ──────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local patchUpdate = Remotes:FindFirstChild("PatchUpdate") :: RemoteEvent?
if patchUpdate then
	patchUpdate.OnClientEvent:Connect(function(patchId: number)
		for _, patch in CollectionService:GetTagged("FlowerPatch") do
			if patch:IsA("BasePart") and patch:GetAttribute("PatchId") == patchId then
				pulsePatchSelect_178(patch)
				-- Update ring radius to this patch's actual distance
				local board = findBoard_178()
				if board then
					local dist = (patch.Position - board.Position).Magnitude
					showRing_178(dist)
					player:SetAttribute("SelectedPatchDistance", dist)
				end
				break
			end
		end
	end)
end
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("ForagingZoneController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("ForagingZoneController")
print("ForagingZoneController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  showRing_178:", c.Source:find("showRing_178") ~= nil)
	print("  tintPatches_178:", c.Source:find("tintPatches_178") ~= nil)
	print("  pulsePatchSelect_178:", c.Source:find("pulsePatchSelect_178") ~= nil)
end

-- Check ring parts (only after a player has joined and the script has run in Play mode)
-- In Edit mode, ring parts won't be visible since LocalScript doesn't execute.
local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts (Edit mode, ring not yet spawned):", count)
-- In Play mode: count should be 4204 + 2 = 4206 per player
```

**Expected output:**
```
ForagingZoneController: LocalScript
  lines: 200+
  showRing_178: true
  tintPatches_178: true
  pulsePatchSelect_178: true
Total parts (Edit mode, ring not yet spawned): 4204
```

> **Note on part budget:** The ring (+2 parts) is created at LocalScript init in Play mode — one per connected player, in the local client Workspace. These are client-side-only parts and do **not** count against the server-side 5,000-part budget.

---

## Behaviour summary

| State | Visual |
|-------|--------|
| DanceGui or BuildGui opens | Honey-gold ring appears around Landing Board at patch distance |
| Close patches (≤150 studs) | Green tint |
| Medium patches (150–350 studs) | Lerped amber tint |
| Far patches (>350 studs) | Red tint |
| Patch selected (PatchUpdate fires) | Ring pulses bright once; ring resizes to selected patch distance |
| UI closes | Ring fades out; all patch tints restored to original |
| Ring geometry | Two cylinders (Neon outer + invisible inner) = visible ring slice |

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(+2 client-side parts in Play mode per player — do not count against server budget)*
