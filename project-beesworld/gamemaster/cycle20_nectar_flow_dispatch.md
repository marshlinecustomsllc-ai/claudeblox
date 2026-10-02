# Dispatch 208 — Nectar Flow Indicator
**File:** `cycle20_nectar_flow_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

After a waggle dance completes, a golden RouteBeam stretches from the Dance Floor to the target flower patch. Currently it sits static — there's no visual confirmation that foragers are actually flying the route and bringing nectar home. This dispatch adds a **Nectar Flow Indicator**: a secondary, faster-moving `Beam` layered on top of each RouteBeam, with a scrolling `TextureOffset` that makes the beam appear to flow from patch toward hive. The scroll speed is proportional to the route's `NectarLevel` attribute — slow trickle at low richness, brisk flow at peak. Entirely client-side, reads the `NectarLevel` RouteBeam attribute, adds zero permanent parts.

For kids: the beam "flows" like honey pouring — you can see nectar moving home. For adults: scroll speed maps to richness so experienced players can compare routes at a glance.

---

## Step 1 — NectarFlowController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `NectarFlowController`.

Paste exactly:

```lua
--!strict
-- NectarFlowController: scrolling Beam overlay on RouteBeam parts to show active nectar flow.
-- Reads NectarLevel attribute (0..1) from RouteBeam-tagged BaseParts.
-- Entirely client-side — zero server writes, zero permanent parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_208   = 4.0    -- seconds between full re-scans
local MIN_SCROLL_208      = 0.05   -- TextureOffset units/sec at NectarLevel=0 (idle drift)
local MAX_SCROLL_208      = 0.55   -- TextureOffset units/sec at NectarLevel=1 (peak flow)
local BEAM_WIDTH_208      = 0.12   -- studs wide (thinner overlay on top of route beam)

-- ── Palette ───────────────────────────────────────────────────────────────────
local FLOW_A_208 = Color3.fromRGB(255, 210,  60)   -- bright peak honey
local FLOW_B_208 = Color3.fromRGB(242, 168,  28)   -- standard honey gold

-- ── State ─────────────────────────────────────────────────────────────────────
type RouteEntry = {
	beam:       Beam,
	att0:       Attachment,
	att1:       Attachment,
	anchor:     Part,        -- invisible Part holding att0+att1
	offset:     number,      -- current TextureOffset.X accumulator
}

local routes_208: { [BasePart]: RouteEntry } = {}

-- ── Find the Route Beam's endpoints from the host Part ────────────────────────
-- RouteBeam parts have two Attachment children: RouteStart, RouteEnd
local function getEndpoints_208(host: BasePart): (Attachment?, Attachment?)
	local a0 = host:FindFirstChild("RouteStart") :: Attachment?
	local a1 = host:FindFirstChild("RouteEnd") :: Attachment?
	return a0, a1
end

-- ── Build a flow Beam overlaid on a RouteBeam ─────────────────────────────────
local function buildFlow_208(host: BasePart): RouteEntry?
	local a0, a1 = getEndpoints_208(host)
	if not a0 or not a1 then return nil end

	-- Invisible anchor part to hold our own attachments (so we don't pollute host)
	local anchor = Instance.new("Part")
	anchor.Name         = "NectarFlowAnchor_208"
	anchor.Size         = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored     = true
	anchor.CanCollide   = false
	anchor.Transparency = 1
	anchor.CastShadow   = false
	anchor.CFrame       = host.CFrame
	anchor.Parent       = workspace

	local myA0 = Instance.new("Attachment")
	myA0.WorldPosition = a0.WorldPosition
	myA0.Parent = anchor

	local myA1 = Instance.new("Attachment")
	myA1.WorldPosition = a1.WorldPosition
	myA1.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Name           = "NectarFlow_208"
	beam.Attachment0    = myA0
	beam.Attachment1    = myA1
	beam.Color          = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   FLOW_A_208),
		ColorSequenceKeypoint.new(0.4, FLOW_B_208),
		ColorSequenceKeypoint.new(0.7, FLOW_A_208),
		ColorSequenceKeypoint.new(1,   FLOW_B_208),
	})
	beam.Width0         = BEAM_WIDTH_208
	beam.Width1         = BEAM_WIDTH_208
	beam.FaceCamera     = true
	beam.LightEmission  = 0.4
	beam.Transparency   = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.5),
		NumberSequenceKeypoint.new(0.3, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1,   0.5),
	})
	beam.TextureMode    = Enum.TextureMode.Stretch
	beam.Texture        = "rbxassetid://6772077219"   -- horizontal stripe texture
	beam.TextureLength  = 2
	beam.Parent         = anchor

	return {
		beam   = beam,
		att0   = myA0,
		att1   = myA1,
		anchor = anchor,
		offset = 0,
	}
end

-- ── Remove flow for a route ───────────────────────────────────────────────────
local function removeFlow_208(host: BasePart)
	local entry = routes_208[host]
	if not entry then return end
	if entry.anchor and entry.anchor.Parent then
		entry.anchor:Destroy()
	end
	routes_208[host] = nil
end

-- ── Scroll speed from NectarLevel ────────────────────────────────────────────
local function scrollSpeed_208(level: number): number
	return MIN_SCROLL_208 + (MAX_SCROLL_208 - MIN_SCROLL_208) * math.clamp(level, 0, 1)
end

-- ── Sync anchor attachment world positions with live RouteBeam endpoints ──────
local function syncPositions_208(host: BasePart, entry: RouteEntry)
	local a0, a1 = getEndpoints_208(host)
	if a0 then entry.att0.WorldPosition = a0.WorldPosition end
	if a1 then entry.att1.WorldPosition = a1.WorldPosition end
end

-- ── Full scan ─────────────────────────────────────────────────────────────────
local function scan_208()
	-- Clean stale
	for host, _ in routes_208 do
		if not host.Parent then
			removeFlow_208(host)
		end
	end
	-- Register new RouteBeam parts
	for _, obj in CollectionService:GetTagged("RouteBeam") do
		if obj:IsA("BasePart") and not routes_208[obj] then
			local entry = buildFlow_208(obj)
			if entry then
				routes_208[obj] = entry
			end
		end
	end
end

-- ── Heartbeat: scroll all active flow beams ────────────────────────────────────
local scanAcc_208  = 0
local syncAcc_208  = 0

RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_208 += dt
	syncAcc_208 += dt

	if scanAcc_208 >= SCAN_INTERVAL_208 then
		scanAcc_208 = 0
		scan_208()
	end

	-- Sync positions every 0.5s (RouteBeam anchor could theoretically move with plot)
	local doSync = syncAcc_208 >= 0.5
	if doSync then syncAcc_208 = 0 end

	for host, entry in routes_208 do
		if not host.Parent or not entry.anchor.Parent then
			removeFlow_208(host)
			continue
		end

		if doSync then
			syncPositions_208(host, entry)
		end

		local level  = (host:GetAttribute("NectarLevel") :: number?) or 0
		local speed  = scrollSpeed_208(level)

		-- Scroll TextureOffset from patch (Attachment1) toward hive (Attachment0)
		-- Negative X scrolls in the -X direction of the beam (toward A0)
		entry.offset -= speed * dt
		if entry.offset < -1 then entry.offset += 1 end
		entry.beam.TextureOffset = Vector2.new(entry.offset, 0)

		-- Adjust opacity: more transparent when NectarLevel is very low
		local alpha = math.clamp(level * 3, 0, 1)   -- fully opaque above ~0.33
		entry.beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,   0.5 + (1 - alpha) * 0.4),
			NumberSequenceKeypoint.new(0.3, 0.2 + (1 - alpha) * 0.3),
			NumberSequenceKeypoint.new(0.7, 0.2 + (1 - alpha) * 0.3),
			NumberSequenceKeypoint.new(1,   0.5 + (1 - alpha) * 0.4),
		})
	end
end)

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("RouteBeam"):Connect(function(obj)
	if obj:IsA("BasePart") then
		task.wait(0.5)   -- give RouteController time to attach its RouteStart/RouteEnd
		if not routes_208[obj] then
			local entry = buildFlow_208(obj)
			if entry then routes_208[obj] = entry end
		end
	end
end)

CollectionService:GetInstanceRemovedSignal("RouteBeam"):Connect(function(obj)
	if obj:IsA("BasePart") then
		removeFlow_208(obj)
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	scan_208()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("NectarFlowController"))
```

---

## Step 3 — Attribute source (ForagingService / DanceController)

`NectarFlowController` reads one attribute from `RouteBeam` BaseParts:

| Attribute | Type | Set by | Notes |
|---|---|---|---|
| `NectarLevel` | number | ForagingService | 0–1 normalised richness; 0 = route idle/exhausted, 1 = peak richness patch |

`RouteBeam` parts must also have two Attachment children named `RouteStart` and `RouteEnd` for the flow beam's endpoints. These should already be placed by DanceController or ForagingService when a route beam is built. If the attachments use different names, update `getEndpoints_208` accordingly:

```lua
-- In NectarFlowController, getEndpoints_208 — adjust names to match your route beam:
local a0 = host:FindFirstChild("RouteStart") :: Attachment?
local a1 = host:FindFirstChild("RouteEnd") :: Attachment?
```

To write `NectarLevel` from ForagingService after each forager return:

```lua
-- In ForagingService, after computing normalised richness for a route:
local routePart = -- (the RouteBeam BasePart for this route)
if routePart then
    routePart:SetAttribute("NectarLevel", math.clamp(normalisedRichness, 0, 1))
end
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("NectarFlowController")
print("NectarFlowController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildFlow_208:", c.Source:find("buildFlow_208") ~= nil)
	print("  scrollSpeed_208:", c.Source:find("scrollSpeed_208") ~= nil)
	print("  NectarLevel attr:", c.Source:find("NectarLevel") ~= nil)
	print("  RouteBeam tag:", c.Source:find("RouteBeam") ~= nil)
	print("  TextureOffset:", c.Source:find("TextureOffset") ~= nil)
end

local CS = game:GetService("CollectionService")
local routes = CS:GetTagged("RouteBeam")
print("RouteBeam tagged parts:", #routes, "(0 in Edit mode — created after first dance)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

After completing a waggle dance (so a RouteBeam exists):

```lua
local CS = game:GetService("CollectionService")
local beams = CS:GetTagged("RouteBeam")
if beams[1] then
	-- Low richness — slow trickle
	beams[1]:SetAttribute("NectarLevel", 0.2)
	task.wait(2)
	-- Peak richness — fast flow
	beams[1]:SetAttribute("NectarLevel", 1.0)
	task.wait(2)
	print("NectarFlow overlays active on", beams[1]:GetFullName())
end
```

**Expected output:**
```
NectarFlowController: LocalScript
  lines: 170+
  buildFlow_208: true
  scrollSpeed_208: true
  NectarLevel attr: true
  RouteBeam tag: true
  TextureOffset: true
RouteBeam tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| NectarLevel | Scroll speed | Opacity | Feel |
|---|---|---|---|
| 0.0 (idle) | 0.05 units/sec | Near-invisible | Faint shimmer only |
| 0.3 (low) | ~0.2 units/sec | Partial | Gentle trickle visible |
| 0.7 (good) | ~0.4 units/sec | ~Full | Satisfying steady flow |
| 1.0 (peak) | 0.55 units/sec | Full | Brisk, honey rushing home |

- Flow scrolls from flower patch toward hive (A1 → A0 direction) — nectar visually travels the right way
- Texture is a horizontal stripe pattern (asset 6772077219 — a standard Roblox stripe) scrolling along the beam
- Colour alternates FLOW_A (bright) and FLOW_B (standard gold) — creates the stripe contrast needed for visible motion
- Width 0.12 studs (vs standard RouteBeam which is ~0.3 studs) — overlay appears as an inner highlight, not a second beam
- LightEmission=0.4 makes it glow slightly, adding to the honey-gold richness feel
- At very low NectarLevel the beam is nearly invisible — the contrast between idle and active routes is intentional (idle routes should look "off")

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(NectarFlowAnchor_208 Parts and their Beams are client-only; created at scan time, destroyed when the RouteBeam is removed)*
