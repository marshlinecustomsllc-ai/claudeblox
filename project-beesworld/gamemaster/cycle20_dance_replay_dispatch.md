# Dispatch 202 — Waggle Dance Replay Button
**File:** `cycle20_dance_replay_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

After a waggle dance completes, the `DanceResult` RemoteEvent fires with the submitted bearing and quality. New players often want to know *what the ideal path looked like* — and existing players like to see their own route. This dispatch adds a **Replay Button**: a small 2D "↩ Replay" pill that appears in the HiveGui (or a standalone ScreenGui) for 8 seconds after each `DanceResult`. Pressing it runs a **ghost replay** — a 1.5-second client-side animation that draws a Beam from the Dance Floor centre in the submitted bearing direction to the approximate target distance, then fades it. The button auto-hides after 8 seconds if not pressed. Entirely client-side — zero server writes.

---

## Step 1 — DanceReplayController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `DanceReplayController`.

Paste exactly:

```lua
--!strict
-- DanceReplayController: "↩ Replay" ghost-path button after each waggle dance.
-- Listens to DanceResult RemoteEvent; shows a replay button for 8 seconds.
-- Ghost replay: Beam from Dance Floor centre along submitted bearing, 1.5s fade.
-- Entirely client-side — zero server writes, zero permanent parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local BUTTON_TTL_202    = 8.0     -- seconds the replay button stays visible
local REPLAY_DURATION_202 = 1.6  -- seconds the ghost beam animates
local BEAM_STUDS_202    = 60     -- how many studs the ghost beam extends
local BEAM_WIDTH_202    = 0.25   -- studs wide

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_202    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_202  = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD_202 = Color3.fromRGB(242, 168,  28)
local AMBER_202      = Color3.fromRGB(220, 130,  20)
local GHOST_202      = Color3.fromRGB(180, 220, 255)   -- soft blue ghost trail

-- ── State ─────────────────────────────────────────────────────────────────────
local lastResult_202: { bearing: number, quality: number, distance: number }? = nil
local buttonGui_202: ScreenGui?   = nil
local replayActive_202 = false

-- ── Find the Dance Floor centre part for this player's plot ───────────────────
local function getDanceFloor_202(): BasePart?
	local myPlot = player:GetAttribute("PlotIndex") or 1
	for _, obj in CollectionService:GetTagged("DanceFloorCell") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			return obj
		end
	end
	return nil
end

-- ── Ghost beam replay ────────────────────────────────────────────────────────
local function runReplay_202(bearing: number, distanceRatio: number)
	if replayActive_202 then return end
	replayActive_202 = true

	local floor = getDanceFloor_202()
	if not floor then replayActive_202 = false return end

	-- Convert bearing (degrees, 0=north/+Z) to world direction
	local radians = math.rad(bearing)
	local dir = Vector3.new(math.sin(radians), 0, math.cos(radians))
	local beamLength = BEAM_STUDS_202 * math.clamp(distanceRatio, 0.3, 1.0)

	local origin    = floor.Position + Vector3.new(0, 1.5, 0)
	local endpoint  = origin + dir * beamLength

	-- Create two anchor parts (invisible) + Beam
	local a0Part = Instance.new("Part")
	a0Part.Size             = Vector3.new(0.1, 0.1, 0.1)
	a0Part.Anchored         = true
	a0Part.CanCollide        = false
	a0Part.Transparency     = 1
	a0Part.CFrame           = CFrame.new(origin)
	a0Part.Parent           = workspace

	local a1Part = Instance.new("Part")
	a1Part.Size             = Vector3.new(0.1, 0.1, 0.1)
	a1Part.Anchored         = true
	a1Part.CanCollide        = false
	a1Part.Transparency     = 1
	a1Part.CFrame           = CFrame.new(origin)   -- starts at origin, will move
	a1Part.Parent           = workspace

	local att0 = Instance.new("Attachment")
	att0.Parent = a0Part
	local att1 = Instance.new("Attachment")
	att1.Parent = a1Part

	local beam = Instance.new("Beam")
	beam.Attachment0    = att0
	beam.Attachment1    = att1
	beam.Color          = ColorSequence.new(GHOST_202)
	beam.Width0         = BEAM_WIDTH_202
	beam.Width1         = BEAM_WIDTH_202
	beam.FaceCamera     = true
	beam.LightEmission  = 0.6
	beam.Transparency   = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	beam.Parent         = a0Part

	-- Animate endpoint moving outward
	local elapsed = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local pct = math.clamp(elapsed / (REPLAY_DURATION_202 * 0.6), 0, 1)
		-- Endpoint travels from origin to endpoint over 60% of duration
		local currentEnd = origin:Lerp(endpoint, pct)
		a1Part.CFrame = CFrame.new(currentEnd)

		-- Fade beam in the last 40%
		local fadePct = math.clamp((elapsed - REPLAY_DURATION_202 * 0.6) / (REPLAY_DURATION_202 * 0.4), 0, 1)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2 + fadePct * 0.8),
			NumberSequenceKeypoint.new(1, 0.8 + fadePct * 0.2),
		})

		if elapsed >= REPLAY_DURATION_202 then
			conn:Disconnect()
			a0Part:Destroy()   -- destroys att0, beam, a1Part is separate
			a1Part:Destroy()
			replayActive_202 = false
		end
	end)
end

-- ── Dismiss the replay button ─────────────────────────────────────────────────
local function dismissButton_202()
	if buttonGui_202 and buttonGui_202.Parent then
		local frame = buttonGui_202:FindFirstChildOfClass("Frame")
		if frame then
			TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {
				BackgroundTransparency = 1,
			}):Play()
		end
		task.delay(0.4, function()
			if buttonGui_202 and buttonGui_202.Parent then
				buttonGui_202:Destroy()
			end
			buttonGui_202 = nil
		end)
	end
end

-- ── Show replay button ────────────────────────────────────────────────────────
local function showButton_202(result: { bearing: number, quality: number, distance: number })
	-- Clear any existing button
	if buttonGui_202 and buttonGui_202.Parent then
		buttonGui_202:Destroy()
	end

	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "DanceReplayBtn_202"
	sg.DisplayOrder   = 32
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg
	buttonGui_202     = sg

	local frame = Instance.new("Frame")
	frame.Name                   = "ReplayFrame"
	frame.Size                   = UDim2.new(0, 110, 0, 28)
	frame.AnchorPoint            = Vector2.new(0.5, 0)
	frame.Position               = UDim2.new(0.5, 70, 0.62, 0)
	frame.BackgroundColor3       = DARK_BG_202
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = GHOST_202
	stroke.Thickness = 1
	stroke.Parent    = frame

	local btn = Instance.new("TextButton")
	btn.Name               = "ReplayBtn"
	btn.Size               = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text               = "↩  Replay route"
	btn.TextSize           = 12
	btn.Font               = Enum.Font.GothamBold
	btn.TextColor3         = GHOST_202
	btn.ZIndex             = 2
	btn.Parent             = frame

	-- Auto-dismiss timer
	local ttl = BUTTON_TTL_202
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		ttl -= dt
		-- Pulse alpha as time runs out (last 3 seconds)
		if ttl < 3 then
			local alpha = math.clamp(ttl / 3, 0, 1)
			frame.BackgroundTransparency = 0.1 + (1 - alpha) * 0.7
			btn.TextColor3 = GHOST_202:Lerp(DARK_BG_202, 1 - alpha)
		end
		if ttl <= 0 then
			conn:Disconnect()
			dismissButton_202()
		end
	end)

	-- Button click
	btn.Activated:Connect(function()
		conn:Disconnect()
		dismissButton_202()
		-- distanceRatio: normalise stored distance against max (Config.MAX_PATCH_DISTANCE ~674)
		local distanceRatio = math.clamp(result.distance / 674, 0, 1)
		runReplay_202(result.bearing, distanceRatio)
	end)
end

-- ── Listen for DanceResult ────────────────────────────────────────────────────
local function connectDanceResult_202()
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:WaitForChild("Remotes", 15) :: Folder?
	if not remotes then return end
	local ev = remotes:WaitForChild("DanceResult", 15) :: RemoteEvent?
	if not ev then return end

	ev.OnClientEvent:Connect(function(payload)
		-- payload from DanceService: { bearing, distance, quality, routeId }
		if typeof(payload) ~= "table" then return end
		local bearing  = (payload.bearing  :: number?) or 0
		local distance = (payload.distance :: number?) or 100
		local quality  = (payload.quality  :: number?) or 0

		lastResult_202 = { bearing = bearing, quality = quality, distance = distance }
		showButton_202(lastResult_202)
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(2, connectDanceResult_202)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("DanceReplayController"))
```

---

## Step 3 — DanceResult payload check (DanceService)

`DanceReplayController` reads `bearing` and `distance` fields from the `DanceResult` payload. Confirm `DanceService` includes these in its `FireClient` call:

```lua
-- In DanceService, when firing DanceResult to the client:
DanceResult:FireClient(player, {
    bearing  = trueBearing,      -- degrees, 0-360
    distance = trueDistance,     -- studs
    quality  = qualityScore,     -- 0..1.5
    routeId  = routeId,          -- optional
})
```

If `bearing` and `distance` are already in the payload (they are specified in the architecture), no DanceService changes are needed.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("DanceReplayController")
print("DanceReplayController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  runReplay_202:", c.Source:find("runReplay_202") ~= nil)
	print("  showButton_202:", c.Source:find("showButton_202") ~= nil)
	print("  getDanceFloor_202:", c.Source:find("getDanceFloor_202") ~= nil)
	print("  BUTTON_TTL_202:", c.Source:find("BUTTON_TTL_202") ~= nil)
	print("  DanceResult:", c.Source:find("DanceResult") ~= nil)
end

local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
local dr = remotes and remotes:FindFirstChild("DanceResult")
print("DanceResult RemoteEvent:", dr and dr.ClassName or "MISSING")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
DanceReplayController: LocalScript
  lines: 160+
  runReplay_202: true
  showButton_202: true
  getDanceFloor_202: true
  BUTTON_TTL_202: true
  DanceResult: true
DanceResult RemoteEvent: RemoteEvent
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Event | Effect |
|---|---|
| `DanceResult` fires | "↩ Replay route" button appears near DanceGui for 8 seconds |
| Button clicked | Button dismisses; ghost Beam animates from Dance Floor in submitted bearing direction for 1.6s |
| Button not clicked | Fades and destroys after 8s (pulsing in last 3s as countdown hint) |
| Replay already active | Second click ignored (`replayActive_202` guard) |

- Ghost beam: soft blue (`GHOST_202` = 180,220,255) — visually distinct from the honey-gold route beam so there's no confusion with live routes
- Endpoint travels outward over first 60% of duration; beam fades over remaining 40%
- Beam length scaled to submitted distance / 674 max studs (so short routes get a short ghost)
- Anchor parts and Beam are created in `workspace` as client-only instances; destroyed at animation end
- Button sits to the right of the DanceGui (offset +70px on X) so it doesn't overlap the result score

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(Two anchor Parts + Beam created at replay time, destroyed immediately after; not counted against permanent budget)*
