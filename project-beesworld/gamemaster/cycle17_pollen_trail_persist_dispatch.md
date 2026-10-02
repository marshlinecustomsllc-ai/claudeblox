# Dispatch 186 — Pollen Trail Persistence Display
**File:** `cycle17_pollen_trail_persist_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Active foraging routes already draw a `RouteBeam` Part+Beam in Workspace when a dance succeeds, but the beam stays static (same colour, same brightness) whether the patch is freshly blooming or nearly depleted. Players can't see which routes are worth flying. This dispatch adds a **Pollen Trail Persistence Display**: a `RunService.Heartbeat` loop on the client that scans all route beams in the player's plot folder, reads the target patch's `NectarLevel` attribute, and smoothly tints each beam from bright honey-gold (rich) through amber (declining) to grey (exhausted). A small richness badge (percentage) floats at the midpoint of each active beam and updates every 2 seconds. The entire display fades out if the player opens `BuildGui` or `DanceGui` (so it doesn't clutter those flows) and re-appears when they close.

Entirely client-side. Zero new permanent parts. Uses existing `RouteBeam` instances and `FlowerPatch` tags — no new world objects.

---

## Step 1 — PollenTrailController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `PollenTrailController`.

Paste exactly:

```lua
--!strict
-- PollenTrailController: tints active RouteBeam instances by target patch nectar richness.
-- Reads NectarLevel attribute on FlowerPatch parts via CollectionService tag.
-- Fades badges when BuildGui/DanceGui are open. Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- ── Config ────────────────────────────────────────────────────────────────────
local BADGE_UPDATE_SEC_186 = 2.0   -- seconds between richness-badge refreshes
local BEAM_FADE_TIME_186   = 0.4   -- seconds for beam tint transition
local BADGE_FLOAT_Y_186    = 3.5   -- studs above beam midpoint for badge
local BADGE_SIZE_186       = 60    -- px width of richness badge

-- ── Palette ───────────────────────────────────────────────────────────────────
local RICH_COLOR_186    = Color3.fromRGB(255, 210,  40)   -- bright gold (100% nectar)
local AMBER_COLOR_186   = Color3.fromRGB(220, 130,  20)   -- amber (50%)
local TIRED_COLOR_186   = Color3.fromRGB(140,  90,  40)   -- brown (25%)
local EMPTY_COLOR_186   = Color3.fromRGB( 80,  80,  80)   -- grey (0%)
local WAX_CREAM_186     = Color3.fromRGB(232, 212, 154)
local DARK_BG_186       = Color3.fromRGB( 30,  18,   8)

-- ── Nectar level → beam colour ───────────────────────────────────────────────
local function nectarColor_186(level: number): Color3
	-- level: 0..1
	if level >= 0.5 then
		return AMBER_COLOR_186:Lerp(RICH_COLOR_186, (level - 0.5) / 0.5)
	elseif level >= 0.25 then
		return TIRED_COLOR_186:Lerp(AMBER_COLOR_186, (level - 0.25) / 0.25)
	else
		return EMPTY_COLOR_186:Lerp(TIRED_COLOR_186, level / 0.25)
	end
end

-- ── Find beam target patch ────────────────────────────────────────────────────
local function getPatchForBeam_186(beamPart: BasePart): BasePart?
	local patchId = beamPart:GetAttribute("PatchId") :: number?
	if not patchId then return nil end
	for _, patch in CollectionService:GetTagged("FlowerPatch") do
		if patch:IsA("BasePart") and patch:GetAttribute("PatchId") == patchId then
			return patch
		end
	end
	return nil
end

-- ── Badge pool ────────────────────────────────────────────────────────────────
-- Each badge is a BillboardGui parented to the RouteBeam holder part
local badgePool_186: { [BasePart]: BillboardGui } = {}

local function getOrCreateBadge_186(beamPart: BasePart): BillboardGui
	local existing = badgePool_186[beamPart]
	if existing and existing.Parent then return existing end

	local bg = Instance.new("BillboardGui")
	bg.Name           = "RichnessBadge_186"
	bg.Size           = UDim2.new(0, BADGE_SIZE_186, 0, 20)
	bg.StudsOffset    = Vector3.new(0, BADGE_FLOAT_Y_186, 0)
	bg.AlwaysOnTop    = false
	bg.ResetOnSpawn   = false
	bg.Parent         = beamPart

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_186
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent       = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "RichnessText"
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "—"
	lbl.TextSize           = 11
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_186
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.TextYAlignment     = Enum.TextYAlignment.Center
	lbl.ZIndex             = 3
	lbl.Parent             = frame

	badgePool_186[beamPart] = bg
	return bg
end

local function removeBadge_186(beamPart: BasePart)
	local bg = badgePool_186[beamPart]
	if bg then
		bg:Destroy()
		badgePool_186[beamPart] = nil
	end
end

-- ── Scan player's plot for RouteBeam parts ────────────────────────────────────
local function findRouteBeams_186(): { BasePart }
	local myPlot = player:GetAttribute("PlotIndex") or 1
	local beams: { BasePart } = {}
	for _, obj in workspace:GetDescendants() do
		if obj:IsA("BasePart") and obj.Name == "RouteBeam"
			and obj:GetAttribute("PlotIndex") == myPlot then
			table.insert(beams, obj)
		end
	end
	return beams
end

-- ── GUI visibility gate ───────────────────────────────────────────────────────
local function isGuiBusy_186(): boolean
	local buildGui = PlayerGui:FindFirstChild("BuildGui") :: ScreenGui?
	local danceGui = PlayerGui:FindFirstChild("DanceGui") :: ScreenGui?
	if buildGui and buildGui.Enabled then return true end
	if danceGui and danceGui.Enabled then return true end
	return false
end

-- ── Per-beam update ───────────────────────────────────────────────────────────
local lastBadgeTime_186 = 0

local function updateBeam_186(beamPart: BasePart)
	local patch = getPatchForBeam_186(beamPart)
	local level = 0.5  -- default if no patch found
	if patch then
		local raw = patch:GetAttribute("NectarLevel") :: number?
		if raw then level = math.max(0, math.min(1, raw)) end
	end

	-- Tint the Beam instance (child of RouteBeam part)
	local beam = beamPart:FindFirstChildOfClass("Beam")
	if beam then
		local c = nectarColor_186(level)
		TweenService:Create(beam, TweenInfo.new(BEAM_FADE_TIME_186, Enum.EasingStyle.Sine),
			{ Color = ColorSequence.new(c) }):Play()
		beam.LightEmission = 0.3 + level * 0.4   -- richer = more glow
	end

	-- Update badge
	local badge = getOrCreateBadge_186(beamPart)
	local hidden = isGuiBusy_186()
	badge.Enabled = not hidden
	if not hidden then
		local lbl = badge:FindFirstChild("RichnessText", true) :: TextLabel?
		if lbl then
			lbl.Text = string.format("🌸 %d%%", math.floor(level * 100 + 0.5))
			lbl.TextColor3 = nectarColor_186(level)
		end
	end
end

-- ── Cleanup stale badges (beam removed) ──────────────────────────────────────
local function cleanupStaleBadges_186()
	for beamPart, bg in pairs(badgePool_186) do
		if not beamPart.Parent then
			bg:Destroy()
			badgePool_186[beamPart] = nil
		end
	end
end

-- ── Main loop ─────────────────────────────────────────────────────────────────
local loopConn_186: RBXScriptConnection? = nil

local function startLoop_186()
	if loopConn_186 then return end
	loopConn_186 = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastBadgeTime_186 < BADGE_UPDATE_SEC_186 then return end
		lastBadgeTime_186 = now

		cleanupStaleBadges_186()

		local beams = findRouteBeams_186()
		for _, beamPart in beams do
			updateBeam_186(beamPart)
		end

		-- Hide all badges when gui is busy
		local busy = isGuiBusy_186()
		for _, bg in pairs(badgePool_186) do
			if bg.Enabled ~= not busy then
				bg.Enabled = not busy
			end
		end
	end)
end

-- ── PatchUpdate listener keeps NectarLevel attributes fresh ──────────────────
-- PatchUpdate: { patchId: number, nectarLevel: number, ... }
local function connectPatchUpdate_186(): boolean
	local re = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 5)
		:FindFirstChild("PatchUpdate") :: RemoteEvent?
	if re then
		re.OnClientEvent:Connect(function(patchId: number?, nectarLevel: number?)
			if not patchId or not nectarLevel then return end
			-- Update NectarLevel attribute on the local patch part so the loop reads it
			for _, patch in CollectionService:GetTagged("FlowerPatch") do
				if patch:IsA("BasePart") and patch:GetAttribute("PatchId") == patchId then
					patch:SetAttribute("NectarLevel", math.max(0, math.min(1, nectarLevel)))
				end
			end
		end)
		return true
	end
	return false
end

-- ── Init ──────────────────────────────────────────────────────────────────────
task.delay(2, function()
	startLoop_186()
	if not connectPatchUpdate_186() then
		task.spawn(function()
			while true do
				task.wait(10)
				if connectPatchUpdate_186() then break end
			end
		end)
	end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("PollenTrailController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("PollenTrailController")
print("PollenTrailController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  nectarColor_186:", c.Source:find("nectarColor_186") ~= nil)
	print("  updateBeam_186:", c.Source:find("updateBeam_186") ~= nil)
	print("  PatchUpdate listener:", c.Source:find("PatchUpdate") ~= nil)
	print("  getOrCreateBadge_186:", c.Source:find("getOrCreateBadge_186") ~= nil)
end

-- Check how many RouteBeam parts exist (expect > 0 if player has active routes)
local count = 0
for _, obj in game:GetService("Workspace"):GetDescendants() do
	if obj:IsA("BasePart") and obj.Name == "RouteBeam" then count += 1 end
end
print("RouteBeam parts in workspace:", count)

local partCount = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then partCount += 1 end
end
print("Total parts:", partCount, "(expect 4204)")
```

**Expected output:**
```
PollenTrailController: LocalScript
  lines: 180+
  nectarColor_186: true
  updateBeam_186: true
  PatchUpdate listener: true
  getOrCreateBadge_186: true
RouteBeam parts in workspace: 0  (0 in Edit mode — routes exist only during Play)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Beam colour | Badge |
|-------|-------------|-------|
| NectarLevel = 1.0 (full bloom) | Bright honey-gold | "🌸 100%" in gold |
| NectarLevel = 0.5 (mid) | Amber | "🌸 50%" in amber |
| NectarLevel = 0.25 (declining) | Dark amber | "🌸 25%" in brown |
| NectarLevel = 0.0 (exhausted) | Grey | "🌸 0%" in grey |
| BuildGui or DanceGui open | Beam colour unchanged | All badges hidden |
| RouteBeam removed from workspace | Badge destroyed from pool | Cleanup on next tick |
| PatchUpdate RemoteEvent fires | NectarLevel attribute updated locally | Picked up on next 2s badge cycle |

**Part budget: +0 permanent → 4,204 / 5,000**
*(BillboardGui badges are GuiObjects, not BaseParts — zero part budget impact)*
