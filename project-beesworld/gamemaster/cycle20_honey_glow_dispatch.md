# Dispatch 204 — Honey Ripeness Glow
**File:** `cycle20_honey_glow_dispatch.md`
**Cycle:** 20
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture's core risk/reward mechanic: banked honey ripens in place to 2.2× value the longer it's left uncashed, and **the glow is visible from every other plot in the shared server**. This is explicitly described as why players know when to attack and when to harvest. Currently HoneyBlob CellContent parts sit as static `SmoothPlastic` gold spheres. This dispatch implements the **Honey Ripeness Glow** — a client-side Heartbeat controller that reads each `HoneyBlob` part's `RipenessLevel` attribute (0–1) and:

- Below 0.3: SmoothPlastic, muted amber colour
- 0.3–0.7: SmoothPlastic, brightening toward gold
- 0.7–1.0: Material transitions toward Neon, peak honey gold
- At 1.0: Full Neon, brightest gold — visible across the Apiary Yard

Because Material changes are `Enum.Material` (not animatable by TweenService), the controller uses frame-by-frame threshold switching. Colour is directly written each Heartbeat for smooth interpolation. Entirely client-side — reads attributes already set by ResourceService.

---

## Step 1 — HoneyGlowController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HoneyGlowController`.

Paste exactly:

```lua
--!strict
-- HoneyGlowController: ripeness-driven colour and material glow on HoneyBlob parts.
-- Reads RipenessLevel attribute (0..1) from HoneyBlob-tagged BaseParts.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local NEON_THRESHOLD_204   = 0.70   -- ripeness above this = Neon material
local SCAN_INTERVAL_204    = 6.0    -- seconds between full re-scans
local NEARBY_RADIUS_204    = 250    -- studs — include blobs on other plots up to this range

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_FRESH_204  = Color3.fromRGB(200, 140,  30)   -- muted amber (0.0)
local HONEY_MID_204    = Color3.fromRGB(230, 160,  25)   -- warm gold (0.5)
local HONEY_RIPE_204   = Color3.fromRGB(242, 168,  28)   -- honey gold (0.7)
local HONEY_PEAK_204   = Color3.fromRGB(255, 200,  60)   -- bright peak (1.0)

-- ── Ripeness → colour ─────────────────────────────────────────────────────────
local function ripenessColor_204(level: number): Color3
	if level <= 0.5 then
		return HONEY_FRESH_204:Lerp(HONEY_MID_204, level / 0.5)
	elseif level <= 0.7 then
		return HONEY_MID_204:Lerp(HONEY_RIPE_204, (level - 0.5) / 0.2)
	else
		return HONEY_RIPE_204:Lerp(HONEY_PEAK_204, (level - 0.7) / 0.3)
	end
end

-- ── Ripeness → material ───────────────────────────────────────────────────────
local function ripenessMaterial_204(level: number): Enum.Material
	if level >= NEON_THRESHOLD_204 then
		return Enum.Material.Neon
	end
	return Enum.Material.SmoothPlastic
end

-- ── Registry: all HoneyBlob parts currently being managed ────────────────────
-- Maps part → last known ripeness level (to avoid redundant Material sets)
local blobs_204: { [BasePart]: number } = {}

-- ── Apply ripeness visuals to a single blob ───────────────────────────────────
local function applyBlob_204(part: BasePart, level: number)
	part.Color    = ripenessColor_204(level)
	local mat     = ripenessMaterial_204(level)
	if part.Material ~= mat then
		part.Material = mat
	end
end

-- ── Scan and update all tracked blobs ────────────────────────────────────────
local function scan_204()
	-- Clean up stale refs
	for part, _ in pairs(blobs_204) do
		if not part.Parent then
			blobs_204[part] = nil
		end
	end

	-- Register all accessible HoneyBlob parts
	for _, obj in CollectionService:GetTagged("HoneyBlob") do
		if not obj:IsA("BasePart") then continue end
		blobs_204[obj] = (obj:GetAttribute("RipenessLevel") :: number?) or 0
	end
end

-- ── Heartbeat update ─────────────────────────────────────────────────────────
local scanAcc_204 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_204 += dt
	if scanAcc_204 >= SCAN_INTERVAL_204 then
		scanAcc_204 = 0
		scan_204()
	end

	for part, _ in pairs(blobs_204) do
		if not part.Parent then
			blobs_204[part] = nil
			continue
		end
		local level = (part:GetAttribute("RipenessLevel") :: number?) or 0
		blobs_204[part] = level
		applyBlob_204(part, level)
	end
end)

-- ── CollectionService hooks ───────────────────────────────────────────────────
CollectionService:GetInstanceAddedSignal("HoneyBlob"):Connect(function(obj)
	if obj:IsA("BasePart") then
		task.wait(0.3)
		local level = (obj:GetAttribute("RipenessLevel") :: number?) or 0
		blobs_204[obj] = level
		applyBlob_204(obj, level)
	end
end)

CollectionService:GetInstanceRemovedSignal("HoneyBlob"):Connect(function(obj)
	if obj:IsA("BasePart") then
		blobs_204[obj] = nil
	end
end)

-- ── Attribute-change watch per blob ──────────────────────────────────────────
local function watchBlob_204(part: BasePart)
	part:GetAttributeChangedSignal("RipenessLevel"):Connect(function()
		if part.Parent then
			local level = (part:GetAttribute("RipenessLevel") :: number?) or 0
			blobs_204[part] = level
			applyBlob_204(part, level)
		end
	end)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	scan_204()
	-- Watch all existing blobs
	for _, obj in CollectionService:GetTagged("HoneyBlob") do
		if obj:IsA("BasePart") then
			watchBlob_204(obj)
		end
	end
	-- Watch future blobs
	CollectionService:GetInstanceAddedSignal("HoneyBlob"):Connect(function(obj)
		if obj:IsA("BasePart") then
			task.wait(0.3)
			watchBlob_204(obj)
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HoneyGlowController"))
```

---

## Step 3 — Attribute source (ResourceService)

`HoneyGlowController` reads one attribute from `HoneyBlob` BaseParts:

| Attribute | Set by | When |
|---|---|---|
| `RipenessLevel` | ResourceService | After each ripeness tick (every `Config.RIPEN_INTERVAL` seconds); value 0–1 |

If ResourceService doesn't yet write `RipenessLevel` to the HoneyBlob BasePart, add it after each ripeness update:

```lua
-- In ResourceService ripeness tick, after updating cell.ripeness:
local blobPart = -- (the HoneyBlob BasePart inside this cell)
if blobPart then
    blobPart:SetAttribute("RipenessLevel", math.clamp(cell.ripeness, 0, 1))
end
```

The architecture specifies `ripeness` starts at 0 and reaches 1.0 (= 2.2× multiplier) over `Config.RIPEN_TIME` seconds. `RipenessLevel` is the normalised form (divide current ripeness by 1.0 max = pass directly).

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HoneyGlowController")
print("HoneyGlowController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  ripenessColor_204:", c.Source:find("ripenessColor_204") ~= nil)
	print("  ripenessMaterial_204:", c.Source:find("ripenessMaterial_204") ~= nil)
	print("  applyBlob_204:", c.Source:find("applyBlob_204") ~= nil)
	print("  NEON_THRESHOLD_204:", c.Source:find("NEON_THRESHOLD_204") ~= nil)
	print("  RipenessLevel attr:", c.Source:find("RipenessLevel") ~= nil)
end

local CS = game:GetService("CollectionService")
local blobs = CS:GetTagged("HoneyBlob")
print("HoneyBlob tagged parts:", #blobs, "(0 in Edit mode — built during Play)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Quick-test in Play mode:**

```lua
-- Find a HoneyBlob and set its ripeness to full
local CS = game:GetService("CollectionService")
local blobs = CS:GetTagged("HoneyBlob")
if blobs[1] then
    blobs[1]:SetAttribute("RipenessLevel", 1.0)
    print("Set RipenessLevel=1 on", blobs[1]:GetFullName())
    print("Material:", blobs[1].Material.Name)  -- should become Neon
end
```

**Expected output:**
```
HoneyGlowController: LocalScript
  lines: 120+
  ripenessColor_204: true
  ripenessMaterial_204: true
  applyBlob_204: true
  NEON_THRESHOLD_204: true
  RipenessLevel attr: true
HoneyBlob tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| RipenessLevel | Material | Colour | Visible cross-plot? |
|---|---|---|---|
| 0.0 (fresh deposit) | SmoothPlastic | Muted amber `(200,140,30)` | No |
| 0.5 (half-ripe) | SmoothPlastic | Warm gold `(230,160,25)` | Slight glow |
| 0.70 (threshold) | **Neon** | Honey gold `(242,168,28)` | Yes — other plots can see |
| 1.0 (fully ripe, 2.2×) | **Neon** | Bright peak `(255,200,60)` | Bright — visible from Petal Path |

- Material switch from SmoothPlastic → Neon at 0.70 is the architecture's "act now" signal
- `GetAttributeChangedSignal("RipenessLevel")` gives instant response on every ResourceService tick
- Applies to ALL HoneyBlob parts in the scene — not just the player's own plot — so opponents' ripe honey glows from across the yard, creating the public risk/reward tension the architecture describes
- 6-second scan safety net for any missed signals

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(No new parts — direct Color and Material property writes on existing HoneyBlob CellContent BaseParts)*
