# Dispatch 197 — Nectar Route Efficiency Badge
**File:** `cycle19_route_efficiency_dispatch.md`
**Cycle:** 19
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Players build multiple foraging routes via the waggle-dance minigame, but there's no way to tell at a glance which routes are performing best. `ForagingService` already tracks `LastQuality` and the patch's `NectarLevel`; this dispatch surfaces that as a **Route Efficiency Badge**: a small star-rated BillboardGui on each `RouteBeam` part showing "⭐ XX%" where XX is the efficiency score (quality × richness normalised to 0–100). The badge colour shifts from grey (low) through amber to gold (high). Computed client-side from existing attributes — zero server writes, zero DataService changes.

---

## Step 1 — RouteEfficiencyController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `RouteEfficiencyController`.

Paste exactly:

```lua
--!strict
-- RouteEfficiencyController: ⭐ efficiency badge on each RouteBeam part.
-- Reads LastQuality (0..1.5) and NectarLevel (0..1) attributes from RouteBeam parts.
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local POLL_INTERVAL_197  = 3.0    -- seconds between attribute polls
local BADGE_OFFSET_197   = Vector3.new(0, 2.2, 0)   -- studs above beam part

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_197    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_197  = Color3.fromRGB(232, 212, 154)
local GREY_197       = Color3.fromRGB(100,  90,  80)
local AMBER_197      = Color3.fromRGB(220, 130,  20)
local GOLD_197       = Color3.fromRGB(242, 168,  28)
local SILVER_197     = Color3.fromRGB(200, 200, 220)

local function efficiencyColor_197(score: number): Color3
	-- score 0..100
	if score < 40 then return GREY_197:Lerp(AMBER_197, score / 40) end
	return AMBER_197:Lerp(GOLD_197, (score - 40) / 60)
end

local function starRating_197(score: number): string
	if score >= 80 then return "⭐⭐⭐" end
	if score >= 50 then return "⭐⭐" end
	if score >= 20 then return "⭐" end
	return "·"
end

-- ── Badge registry ────────────────────────────────────────────────────────────
local badges_197: { [BasePart]: BillboardGui } = {}

-- ── Build badge ───────────────────────────────────────────────────────────────
local function buildBadge_197(beam: BasePart, score: number): BillboardGui
	local col = efficiencyColor_197(score)

	local bg = Instance.new("BillboardGui")
	bg.Name                      = "EfficiencyBadge_197"
	bg.Size                      = UDim2.new(0, 74, 0, 20)
	bg.StudsOffset               = BADGE_OFFSET_197
	bg.AlwaysOnTop               = false
	bg.ResetOnSpawn              = false
	bg.Parent                    = beam

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_197
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "BadgeStroke"
	stroke.Color     = col
	stroke.Thickness = 1
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "BadgeText"
	lbl.Size               = UDim2.new(1, -4, 1, 0)
	lbl.Position           = UDim2.new(0, 2, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = starRating_197(score) .. "  " .. math.round(score) .. "%"
	lbl.TextSize           = 10
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = col
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	return bg
end

-- ── Update or create badge ────────────────────────────────────────────────────
local function upsertBadge_197(beam: BasePart, score: number)
	local existing = badges_197[beam]
	local col = efficiencyColor_197(score)

	if existing and existing.Parent then
		-- Update in-place
		local frame = existing:FindFirstChildOfClass("Frame")
		if frame then
			local lbl = frame:FindFirstChild("BadgeText") :: TextLabel?
			local st  = frame:FindFirstChild("BadgeStroke") :: UIStroke?
			if lbl then
				lbl.Text       = starRating_197(score) .. "  " .. math.round(score) .. "%"
				lbl.TextColor3 = col
			end
			if st then st.Color = col end
		end
	else
		if existing then existing:Destroy() end
		local bg = buildBadge_197(beam, score)
		badges_197[beam] = bg
	end
end

-- ── Remove badge ──────────────────────────────────────────────────────────────
local function removeBadge_197(beam: BasePart)
	local bg = badges_197[beam]
	if bg and bg.Parent then bg:Destroy() end
	badges_197[beam] = nil
end

-- ── Compute efficiency score from attributes ──────────────────────────────────
local function computeScore_197(beam: BasePart): number?
	local quality = beam:GetAttribute("LastQuality") :: number?
	local nectar  = beam:GetAttribute("NectarLevel") :: number?
	if not quality then return nil end
	nectar = nectar or 0.5   -- default mid richness if unknown
	-- quality 0..1.5, nectar 0..1 → normalise to 0..100
	local raw = (quality / 1.5) * 0.6 + nectar * 0.4
	return math.clamp(raw * 100, 0, 100)
end

-- ── Scan all RouteBeam parts on player's plot ──────────────────────────────────
local function scanBeams_197()
	local myPlot = player:GetAttribute("PlotIndex") or 1

	-- Remove badges for gone beams
	for beam, _ in pairs(badges_197) do
		if not beam.Parent then
			removeBadge_197(beam)
		end
	end

	-- Add/update badges for current beams
	for _, obj in CollectionService:GetTagged("RouteBeam") do
		if not obj:IsA("BasePart") then continue end
		if obj:GetAttribute("PlotIndex") ~= myPlot then continue end
		local score = computeScore_197(obj)
		if score then
			upsertBadge_197(obj, score)
		end
	end
end

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("RouteBeam"):Connect(function(obj)
	if obj:IsA("BasePart") then
		task.wait(0.5)   -- brief delay for attributes to propagate
		scanBeams_197()
	end
end)

CollectionService:GetInstanceRemovedSignal("RouteBeam"):Connect(function(obj)
	if obj:IsA("BasePart") then
		removeBadge_197(obj)
	end
end)

-- ── Periodic update loop ──────────────────────────────────────────────────────
task.delay(3, function()
	scanBeams_197()
	local lastScan = os.clock()
	RunService.Heartbeat:Connect(function()
		if os.clock() - lastScan >= POLL_INTERVAL_197 then
			lastScan = os.clock()
			scanBeams_197()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("RouteEfficiencyController"))
```

---

## Step 3 — Attribute source (ForagingService)

`RouteEfficiencyController` reads two attributes from `RouteBeam` BaseParts:

| Attribute | Set by | When |
|---|---|---|
| `LastQuality` | ForagingService | After each successful dance result (quality score 0–1.5) |
| `NectarLevel` | ForagingService or PatchService | After each foraging trip (current patch richness 0–1) |

If `ForagingService` doesn't already write these to the RouteBeam part, add them after the foraging trip completes:

```lua
-- In ForagingService, after processing a completed trip:
local beamPart = -- (the RouteBeam BasePart for this route)
if beamPart then
    beamPart:SetAttribute("LastQuality", quality)       -- 0..1.5 from DanceService
    beamPart:SetAttribute("NectarLevel", nectarLevel)  -- 0..1 from patch richness
end
```

If the RouteBeam is already tracked and `PollenTrailController` (dispatch 186) already writes `NectarLevel` to it, only `LastQuality` may need adding.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("RouteEfficiencyController")
print("RouteEfficiencyController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  computeScore_197:", c.Source:find("computeScore_197") ~= nil)
	print("  buildBadge_197:", c.Source:find("buildBadge_197") ~= nil)
	print("  starRating_197:", c.Source:find("starRating_197") ~= nil)
	print("  RouteBeam scan:", c.Source:find("RouteBeam") ~= nil)
end

local CS = game:GetService("CollectionService")
local beams = CS:GetTagged("RouteBeam")
print("RouteBeam tagged parts:", #beams, "(0 in Edit mode — beams built during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
RouteEfficiencyController: LocalScript
  lines: 170+
  computeScore_197: true
  buildBadge_197: true
  starRating_197: true
  RouteBeam scan: true
RouteBeam tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Score | Stars | Colour | Meaning |
|---|---|---|---|
| 0–19 | · | Grey | Poor quality + low richness route |
| 20–49 | ⭐ | Amber | Adequate route |
| 50–79 | ⭐⭐ | Amber-gold | Good route |
| 80–100 | ⭐⭐⭐ | Honey Gold | Prime route — maximum yield |

- Score formula: `(quality/1.5) × 60% + nectarLevel × 40%` → 0–100
- Badge sits 2.2 studs above the RouteBeam part
- Updated in-place (no destroy/recreate) every 3s when attributes change
- Badge destroyed immediately when RouteBeam is removed
- `LastQuality` defaults absent if ForagingService hasn't set it yet — badge appears once first trip completes

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BillboardGui + Frame GuiObjects parented to RouteBeam BaseParts — not new BaseParts)*
