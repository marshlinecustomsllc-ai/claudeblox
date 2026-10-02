# Dispatch 182 — Waggle Dance Replay Ghost
**File:** `cycle17_dance_replay_ghost_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

A successful waggle dance commits a foraging route, but the route line (Beam) is already in the game. What's missing is a sense of the bee *actually flying out*. This dispatch adds a **Waggle Dance Replay Ghost**: after `DanceResult` fires with a quality ≥ 0.8 (Good or Perfect), a small translucent sphere — the "ghost bee" — travels along the existing route Beam from the Landing Board to the flower patch over 5 seconds, then fades out. If quality is below 0.8 (Poor/Fair) the ghost still spawns but moves slower and wobbles side to side (uncertainty). Kids see their bee flying; adults read quality from the smoothness of the flight path.

Entirely client-side. The ghost is a temporary Part (sphere) parented to Workspace, animated via TweenService/Heartbeat, and destroyed when the animation completes. Zero permanent parts.

---

## Step 1 — DanceReplayController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `DanceReplayController`.

Paste exactly:

```lua
--!strict
-- DanceReplayController: ghost bee travels the foraging route for 5-10s after a successful dance.
-- Listens to DanceResult RemoteEvent (payload: quality, patchId, routeBeam).
-- The ghost is a temporary sphere Part — destroyed on completion. Zero permanent parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local GHOST_TRAVEL_GOOD_182  = 5.0   -- seconds for Good/Perfect quality
local GHOST_TRAVEL_POOR_182  = 8.5   -- seconds for Poor/Fair (slower = uncertainty)
local GHOST_WOBBLE_182       = 1.4   -- studs side wobble magnitude for poor dances
local GHOST_WOBBLE_FREQ_182  = 3.0   -- Hz of wobble oscillation
local GHOST_SIZE_182         = 0.7   -- studs diameter of ghost sphere
local GHOST_FADE_TIME_182    = 0.9   -- seconds to fade out at destination

-- ── Palette ───────────────────────────────────────────────────────────────────
local GOOD_COLOR_182   = Color3.fromRGB(255, 220,  60)   -- golden for good/perfect
local POOR_COLOR_182   = Color3.fromRGB(180, 180, 100)   -- muted yellow for poor/fair
local TRAIL_COLOR_182  = Color3.fromRGB(242, 168,  28)   -- honey-gold trail

-- ── Find board and patch positions ───────────────────────────────────────────
local function findBoardPos_182(): Vector3?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, board in CollectionService:GetTagged("LandingBoard") do
		if board:IsA("BasePart") and board:GetAttribute("PlotIndex") == myPlot then
			return board.Position + Vector3.new(0, 2, 0)  -- slightly above board
		end
	end
	return nil
end

local function findPatchPos_182(patchId: number): Vector3?
	for _, patch in CollectionService:GetTagged("FlowerPatch") do
		if patch:IsA("BasePart") and patch:GetAttribute("PatchId") == patchId then
			return patch.Position + Vector3.new(0, 2, 0)
		end
	end
	return nil
end

-- ── Create ghost bee part ─────────────────────────────────────────────────────
local function createGhost_182(startPos: Vector3, color: Color3): Part
	local ghost = Instance.new("Part")
	ghost.Name         = "GhostBee_182"
	ghost.Shape        = Enum.PartType.Ball
	ghost.Size         = Vector3.new(GHOST_SIZE_182, GHOST_SIZE_182, GHOST_SIZE_182)
	ghost.CFrame       = CFrame.new(startPos)
	ghost.Anchored     = true
	ghost.CanCollide   = false
	ghost.CastShadow   = false
	ghost.Material     = Enum.Material.Neon
	ghost.Color        = color
	ghost.Transparency = 0.45
	ghost.Parent       = workspace

	-- Small trail on the ghost
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, 0.25, 0)
	att0.Parent = ghost
	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -0.25, 0)
	att1.Parent = ghost

	local trail = Instance.new("Trail")
	trail.Attachment0   = att0
	trail.Attachment1   = att1
	trail.Lifetime      = 0.6
	trail.MinLength     = 0.01
	trail.WidthScale    = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, TRAIL_COLOR_182),
		ColorSequenceKeypoint.new(1, color),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 0.5
	trail.FaceCamera    = true
	trail.Parent        = ghost

	return ghost
end

-- ── Animate ghost from board to patch ────────────────────────────────────────
local ghostActive_182 = false

local function playGhost_182(quality: number, patchId: number)
	if ghostActive_182 then return end

	local startPos = findBoardPos_182()
	local endPos   = findPatchPos_182(patchId)
	if not startPos or not endPos then return end

	ghostActive_182 = true

	local isGood    = quality >= 0.8
	local travelT   = if isGood then GHOST_TRAVEL_GOOD_182 else GHOST_TRAVEL_POOR_182
	local color     = if isGood then GOOD_COLOR_182 else POOR_COLOR_182

	local ghost = createGhost_182(startPos, color)

	-- Animate position over time via Heartbeat for wobble support
	local startTime = os.clock()
	local conn: RBXScriptConnection? = nil

	conn = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local t = math.min(elapsed / travelT, 1)

		-- Smooth step for ease-in/out
		local smooth = t * t * (3 - 2 * t)

		-- Base interpolated position
		local basePos = startPos:Lerp(endPos, smooth)

		-- Wobble for poor dances (perpendicular to travel direction)
		local wobbleOffset = Vector3.new(0, 0, 0)
		if not isGood then
			local dir = (endPos - startPos)
			if dir.Magnitude > 0 then
				local right = dir.Unit:Cross(Vector3.new(0, 1, 0))
				local wobble = math.sin(elapsed * GHOST_WOBBLE_FREQ_182 * math.pi * 2)
				wobbleOffset = right * wobble * GHOST_WOBBLE_182 * math.sin(t * math.pi)
			end
		end

		-- Gentle arc (peak at midpoint)
		local arcY = math.sin(t * math.pi) * 3.5

		ghost.CFrame = CFrame.new(basePos + wobbleOffset + Vector3.new(0, arcY, 0))

		if t >= 1 then
			if conn then conn:Disconnect() end
			-- Fade out at destination
			TweenService:Create(ghost, TweenInfo.new(GHOST_FADE_TIME_182, Enum.EasingStyle.Sine),
				{ Transparency = 1 }):Play()
			task.delay(GHOST_FADE_TIME_182 + 0.1, function()
				ghost:Destroy()
				ghostActive_182 = false
			end)
		end
	end)
end

-- ── Listen to DanceResult ─────────────────────────────────────────────────────
-- DanceResult payload: quality (number), patchId (number), optional extras
local function connectDanceResult_182(): boolean
	local re = Remotes:FindFirstChild("DanceResult") :: RemoteEvent?
	if re then
		re.OnClientEvent:Connect(function(quality: number?, patchId: number?)
			if not quality or not patchId then return end
			-- Only play for this player's own dances (server fires to all, or just dancer)
			-- quality > 0 means the dance was accepted; show ghost regardless of quality
			if quality > 0 then
				task.spawn(playGhost_182, quality, patchId)
			end
		end)
		return true
	end
	return false
end

if not connectDanceResult_182() then
	task.spawn(function()
		while true do
			task.wait(8)
			if connectDanceResult_182() then break end
		end
	end)
end
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("DanceReplayController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("DanceReplayController")
print("DanceReplayController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  playGhost_182:", c.Source:find("playGhost_182") ~= nil)
	print("  createGhost_182:", c.Source:find("createGhost_182") ~= nil)
	print("  DanceResult listener:", c.Source:find("DanceResult") ~= nil)
	print("  wobble logic:", c.Source:find("GHOST_WOBBLE_182") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts (Edit mode):", count, "(expect 4204 — ghost only in Play mode)")
```

**Expected output:**
```
DanceReplayController: LocalScript
  lines: 160+
  playGhost_182: true
  createGhost_182: true
  DanceResult listener: true
  wobble logic: true
Total parts (Edit mode): 4204  (expect 4204 — ghost only in Play mode)
```

> **Note on part budget:** The ghost sphere (`GhostBee_182`) is created in Play mode per dance and destroyed ~6–9 seconds later. At most 1 ghost exists per player at any time (ghostActive lock). It is a client-side-only Part and does **not** count against the server-side 5,000-part budget.

---

## Behaviour summary

| Dance quality | Ghost behaviour |
|--------------|----------------|
| Good (≥0.8) or Perfect | Bright golden sphere, 5s travel, smooth arc, no wobble |
| Poor (<0.8) or Fair | Muted yellow sphere, 8.5s travel, side-to-side wobble along route |
| Any quality | Gentle 3.5-stud height arc over the route midpoint |
| At destination | Ghost fades to transparency=1 over 0.9s then Part:Destroy() |
| Second dance while ghost active | Ignored (ghostActive_182 lock) |
| Patch not found | No ghost spawned (safe no-op) |

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Ghost sphere is a temporary client-side Part in Play mode; does not count)*
