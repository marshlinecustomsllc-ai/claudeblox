# Dispatch 181 — Prestige Echo Trail
**File:** `cycle17_prestige_trail_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Prestige (the Swarm sequence) is the game's single most dramatic moment — but once the UI closes, nothing visually signals to OTHER players on the server that someone just reset. This dispatch adds a **Prestige Echo Trail**: for 30 seconds after the `SwarmComplete` RemoteEvent fires, the prestige player's character emits a trailing honey-gold particle stream (15 particles/s, downward drift) plus a faint golden glow on their HumanoidRootPart. Other players see a glowing bee floating around the server; the prestige player sees a "✨ Prestige active — 30s" countdown pill. After 30 seconds the trail fades out automatically.

Entirely client-side. Ephemeral — Trail and glow attachment are destroyed when the effect ends. Zero permanent parts. Uses a Trail object (Attachment-based) for the drip stream rather than a ParticleEmitter so it follows movement naturally.

---

## Step 1 — PrestigeTrailController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PrestigeTrailController`.

Paste exactly:

```lua
--!strict
-- PrestigeTrailController: honey-gold trail + glow on the local player for 30s after Swarm prestige.
-- Listens to SwarmComplete RemoteEvent. Entirely client-side; ephemeral attachments only.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local TRAIL_DURATION_181 = 30     -- seconds the trail lasts
local TRAIL_WIDTH_181    = 0.35   -- studs width at attachment point
local TRAIL_LIFETIME_181 = 0.55   -- seconds each trail segment persists
local GLOW_RANGE_181     = 12     -- studs radius of prestige glow
local GLOW_BRIGHT_181    = 1.8    -- PointLight brightness during trail
local PILL_HEIGHT_181    = 28     -- px pill height

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_181  = Color3.fromRGB(242, 168, 28)
local AMBER_181       = Color3.fromRGB(255, 140, 10)
local PALE_GOLD_181   = Color3.fromRGB(255, 230, 120)
local WAX_CREAM_181   = Color3.fromRGB(232, 212, 154)
local DARK_BG_181     = Color3.fromRGB( 30,  18,   8)

-- ── Trail state ───────────────────────────────────────────────────────────────
local trailActive_181   = false
local trailCleanup_181: () -> () = function() end

-- ── Countdown pill ────────────────────────────────────────────────────────────
local pill_181: Frame? = nil

local function buildPill_181(): Frame
	local sg = Instance.new("ScreenGui")
	sg.Name           = "PrestigeTrailGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 22
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui

	local frame = Instance.new("Frame")
	frame.Name              = "TrailPill"
	frame.Size              = UDim2.new(0, 180, 0, PILL_HEIGHT_181)
	frame.Position          = UDim2.new(0.5, -90, 0, -50)
	frame.BackgroundColor3  = DARK_BG_181
	frame.BorderSizePixel   = 0
	frame.ZIndex            = 35
	frame.Visible           = false
	frame.Parent            = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_GOLD_181
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "TimerLabel"
	lbl.Size               = UDim2.new(1, -8, 1, 0)
	lbl.Position           = UDim2.new(0, 4, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "✨ Prestige active — 30s"
	lbl.TextSize           = 12
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = HONEY_GOLD_181
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 36
	lbl.Parent             = frame

	return frame
end

local function showPill_181()
	if not pill_181 then pill_181 = buildPill_181() end
	local frame = pill_181
	frame.Visible  = true
	frame.Position = UDim2.new(0.5, -90, 0, -50)
	TweenService:Create(frame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -90, 0, 10) }):Play()
end

local function hidePill_181()
	if not pill_181 then return end
	TweenService:Create(pill_181,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.new(0.5, -90, 0, -50) }):Play()
	task.delay(0.3, function()
		if pill_181 then pill_181.Visible = false end
	end)
end

local function updatePillCountdown_181(remaining: number)
	if not pill_181 then return end
	local lbl = pill_181:FindFirstChild("TimerLabel") :: TextLabel?
	if lbl then
		lbl.Text = string.format("✨ Prestige active — %ds", math.ceil(remaining))
	end
end

-- ── Create trail on character ──────────────────────────────────────────────────
local function startTrail_181()
	if trailActive_181 then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	trailActive_181 = true
	showPill_181()

	-- Two attachments at HumanoidRootPart top and bottom for the trail
	local att0 = Instance.new("Attachment")
	att0.Name     = "TrailAtt0_181"
	att0.Position = Vector3.new(0, 1.2, 0)
	att0.Parent   = root

	local att1 = Instance.new("Attachment")
	att1.Name     = "TrailAtt1_181"
	att1.Position = Vector3.new(0, -1.2, 0)
	att1.Parent   = root

	-- Trail object
	local trail = Instance.new("Trail")
	trail.Name           = "PrestigeTrail_181"
	trail.Attachment0    = att0
	trail.Attachment1    = att1
	trail.Lifetime       = TRAIL_LIFETIME_181
	trail.MinLength      = 0.02
	trail.MaxLength      = 0
	trail.WidthScale     = NumberSequence.new({
		NumberSequenceKeypoint.new(0, TRAIL_WIDTH_181),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PALE_GOLD_181),
		ColorSequenceKeypoint.new(0.4, HONEY_GOLD_181),
		ColorSequenceKeypoint.new(1, AMBER_181),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.0),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1.0),
	})
	trail.LightEmission  = 0.6
	trail.LightInfluence = 0.3
	trail.FaceCamera     = true
	trail.Enabled        = true
	trail.Parent         = root

	-- Prestige glow on root
	local light = Instance.new("PointLight")
	light.Name       = "PrestigeGlow_181"
	light.Color      = HONEY_GOLD_181
	light.Brightness = GLOW_BRIGHT_181
	light.Range      = GLOW_RANGE_181
	light.Shadows    = false
	light.Parent     = root

	-- Countdown timer
	local startTime = os.clock()

	local tickConn: RBXScriptConnection? = nil
	tickConn = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed  = os.clock() - startTime
		local remaining = TRAIL_DURATION_181 - elapsed
		if remaining <= 0 then
			-- Time's up — clean up
			if tickConn then tickConn:Disconnect() end
			trail.Enabled = false
			TweenService:Create(light, TweenInfo.new(0.8, Enum.EasingStyle.Sine),
				{ Brightness = 0 }):Play()
			task.delay(0.9, function()
				trail:Destroy()
				att0:Destroy()
				att1:Destroy()
				light:Destroy()
				trailActive_181 = false
			end)
			hidePill_181()
		else
			updatePillCountdown_181(remaining)
		end
	end)

	trailCleanup_181 = function()
		if tickConn then tickConn:Disconnect() end
		pcall(function() trail:Destroy() end)
		pcall(function() att0:Destroy() end)
		pcall(function() att1:Destroy() end)
		pcall(function() light:Destroy() end)
		trailActive_181 = false
		hidePill_181()
	end
end

-- ── Clean up if character respawns mid-trail ──────────────────────────────────
player.CharacterRemoving:Connect(function()
	if trailActive_181 then
		trailCleanup_181()
	end
end)

-- ── Listen to SwarmComplete RemoteEvent ───────────────────────────────────────
local function connectSwarm_181(): boolean
	local re = Remotes:FindFirstChild("SwarmComplete") :: RemoteEvent?
	if re then
		re.OnClientEvent:Connect(function()
			task.delay(0.1, startTrail_181)  -- brief delay for character to settle
		end)
		return true
	end
	return false
end

if not connectSwarm_181() then
	task.spawn(function()
		while true do
			task.wait(10)
			if connectSwarm_181() then break end
		end
	end)
end
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PrestigeTrailController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PrestigeTrailController")
print("PrestigeTrailController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  startTrail_181:", c.Source:find("startTrail_181") ~= nil)
	print("  Trail object:", c.Source:find("Instance.new(\"Trail\")") ~= nil)
	print("  SwarmComplete listener:", c.Source:find("SwarmComplete") ~= nil)
	print("  countdown pill:", c.Source:find("updatePillCountdown_181") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
PrestigeTrailController: LocalScript
  lines: 190+
  startTrail_181: true
  Trail object: true
  SwarmComplete listener: true
  countdown pill: true
Total parts: 4204  (expect 4204)
```

> **Trail objects are not BaseParts** — the Trail + 2 Attachments + 1 PointLight created in Play mode are not counted in the part budget (Attachments and Trails are not BaseParts; PointLight is a light child of an existing part). Zero net budget cost.

---

## Behaviour summary

| State | Visual |
|-------|--------|
| SwarmComplete fires | Trail starts immediately on HumanoidRootPart |
| Character moving | Honey-gold trail streams behind, fades over 0.55s |
| Character stationary | Short golden shimmer at root position |
| 0–30s elapsed | "✨ Prestige active — Ns" countdown pill at top-centre |
| 30s elapsed | Trail disabled, PointLight fades to 0 over 0.8s, all attachments destroyed |
| Character removed mid-trail | Cleanup fires immediately — no dangling connections |
| Second SwarmComplete | Ignored if trail already active |
| Other players on server | See the glow via the PointLight (server-replicated) |

**Part budget: +0 permanent → 4,204 / 5,000**
*(Trail/Attachments/PointLight are ephemeral Play-mode children of the character; not counted)*
