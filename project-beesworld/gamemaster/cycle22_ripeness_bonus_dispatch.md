# Dispatch 218 — Honey Ripeness Bonus
**File:** `cycle22_ripeness_bonus_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The architecture specifies a **2.2× ripeness multiplier** as the core risk/reward tension: players can harvest early at base value, or wait while honey ripens (and Old Molasses grows more dangerous) to earn up to 2.2× the honey value. Currently the ripeness mechanic exists visually (HoneyGlowController glows brighter as `RipenessLevel` rises) but the server does not yet ramp `RipenessLevel` over time or apply the harvest multiplier. This dispatch implements the full ripeness loop:

1. **ResourceService ripeness tick**: `RipenessLevel` on each HoneyBlob rises from 0 to 1 over `RIPENESS_TIME` seconds while honey is stored.
2. **Harvest multiplier**: When `CombService.Harvest` is called, the honey value is multiplied by `1.0 + (RipenessLevel × 1.2)` — a minimum of 1.0× (fresh) up to 2.2× (fully ripe).
3. **Visual feedback**: `RipenessLevel` is already read by HoneyGlowController (D204) — the glow brightens automatically as ripeness rises.

Zero new parts — ResourceService and CombService edits only.

---

## Step 1 — ResourceService ripeness tick

Open **ServerScriptService → Systems → ResourceService** and add the ripeness tick loop.

Find the production loop (the section that runs every few seconds to process honey accumulation). Add a ripeness update after honey is stored:

```lua
-- ── Ripeness constants (add near top of ResourceService) ──────────────────────
local RIPENESS_FULL_TIME_218 = 120   -- seconds to reach RipenessLevel = 1.0 when honey stored
local RIPENESS_TICK_218      = 5.0   -- seconds between ripeness updates

-- ── Ripeness state: honeyBlobPart → elapsed storing seconds ───────────────────
local ripenessAccumulators_218: { [BasePart]: number } = {}

-- ── Ripeness tick (add inside the production loop, gated on RIPENESS_TICK_218) ─
-- Call this section every RIPENESS_TICK_218 seconds:
local function tickRipeness_218()
	local CS = game:GetService("CollectionService")
	for _, blob in CS:GetTagged("HoneyBlob") do
		if not blob:IsA("BasePart") then continue end
		local stored = (blob:GetAttribute("StoredHoney") :: number?) or 0
		local capacity = math.max((blob:GetAttribute("Capacity") :: number?) or 1, 1)

		if stored <= 0 then
			-- No honey — reset ripeness
			ripenessAccumulators_218[blob] = 0
			blob:SetAttribute("RipenessLevel", 0)
		else
			-- Accumulate time
			ripenessAccumulators_218[blob] = (ripenessAccumulators_218[blob] or 0) + RIPENESS_TICK_218
			local level = math.clamp(ripenessAccumulators_218[blob] / RIPENESS_FULL_TIME_218, 0, 1)
			blob:SetAttribute("RipenessLevel", level)
		end
	end
end
```

Wire the tick into the existing production Heartbeat accumulator:

```lua
-- In ResourceService, inside the Heartbeat:Connect loop (or wherever the production tick runs):
ripenessAcc_218 = (ripenessAcc_218 or 0) + dt
if ripenessAcc_218 >= RIPENESS_TICK_218 then
	ripenessAcc_218 = 0
	tickRipeness_218()
end
```

When honey is harvested (HarvestController triggers `CombService.Harvest`), reset ripeness for those cells:

```lua
-- After harvest is complete for a cell, reset its blob:
blob:SetAttribute("RipenessLevel", 0)
ripenessAccumulators_218[blob] = 0
```

---

## Step 2 — CombService harvest multiplier

Open **ServerScriptService → Systems → CombService** and find the `Harvest` function (or wherever harvested honey is tallied). Apply the ripeness multiplier:

```lua
-- ── Ripeness multiplier ────────────────────────────────────────────────────────
local MAX_RIPENESS_MULT_218 = 1.2    -- at RipenessLevel = 1.0, multiply by 1.0 + 1.2 = 2.2

local function getRipenessMultiplier_218(cell: Model): number
	-- Find the HoneyBlob-tagged child of this cell model
	for _, child in cell:GetDescendants() do
		if child:IsA("BasePart") and game:GetService("CollectionService"):HasTag(child, "HoneyBlob") then
			local level = (child:GetAttribute("RipenessLevel") :: number?) or 0
			return 1.0 + (level * MAX_RIPENESS_MULT_218)
		end
	end
	return 1.0   -- no blob found — base rate
end

-- In the Harvest function, when computing honey to award:
local basHoney   = storedHoney   -- raw stored honey count
local ripeMult   = getRipenessMultiplier_218(cellModel)
local finalHoney = math.floor(basHoney * ripeMult)
-- Award finalHoney to player instead of basHoney
```

---

## Step 3 — Harvest feedback: show ripeness multiplier in HarvestController

Open **StarterPlayerScripts → HarvestController** (the LocalScript that handles the ProximityPrompt for harvesting). Add a brief multiplier toast so players see their reward:

```lua
-- After the server confirms harvest (via RemoteFunction or RemoteEvent response):
-- Add this to the harvest confirmation handler:
local function showRipenessFeedback_218(finalHoney: number, multiplier: number)
	-- Only show if multiplier is meaningfully above base
	if multiplier < 1.10 then return end

	local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then return end

	-- Reuse or create a simple floating label
	local existing = pg:FindFirstChild("RipenessFeedback_218")
	if existing then existing:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name = "RipenessFeedback_218"
	sg.DisplayOrder = 25
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.Parent = pg

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 200, 0, 32)
	lbl.Position = UDim2.new(0.5, -100, 0.45, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.format("🍯 ×%.1f ripe!", multiplier)
	lbl.TextSize = 18
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.fromRGB(242, 200, 60)
	lbl.TextStrokeTransparency = 0.4
	lbl.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
	lbl.Parent = sg

	-- Float up and fade out
	game:GetService("TweenService"):Create(lbl, TweenInfo.new(1.6, Enum.EasingStyle.Sine), {
		Position = UDim2.new(0.5, -100, 0.35, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	game:GetService("Debris"):AddItem(sg, 2)
end
```

Wire this into the harvest response handler (where the server returns the honey count):

```lua
-- In HarvestController, where RemoteEvent/RemoteFunction response is handled:
-- Assumes server returns { honey = N, multiplier = M } or similar:
showRipenessFeedback_218(response.honey, response.multiplier or 1.0)
```

If the server currently returns a plain number rather than a table, pass the multiplier as a separate RemoteEvent fire or add it to the return value in CombService.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode after storing some honey):

```lua
local CS = game:GetService("CollectionService")
local blobs = CS:GetTagged("HoneyBlob")
print("HoneyBlob parts:", #blobs)
for i, blob in blobs do
	if i > 4 then print("  ...") break end
	local stored = blob:GetAttribute("StoredHoney") or 0
	local level  = blob:GetAttribute("RipenessLevel") or 0
	print(string.format("  %s  stored=%.0f  ripeness=%.2f  mult=×%.2f",
		blob.Name, stored, level, 1 + level * 1.2))
end
```

**Expected output (after 30+ seconds with honey stored):**
```
HoneyBlob parts: 6
  HoneyBlob_Plot1  stored=12  ripeness=0.25  mult=×1.30
  HoneyBlob_Plot2  stored=0   ripeness=0.00  mult=×1.00
  ...
```

**Full ripeness test:**
```lua
-- Force a HoneyBlob to full ripeness to verify 2.2× multiplier display
local CS = game:GetService("CollectionService")
local blobs = CS:GetTagged("HoneyBlob")
if blobs[1] then
	blobs[1]:SetAttribute("StoredHoney", 50)
	blobs[1]:SetAttribute("Capacity", 50)
	blobs[1]:SetAttribute("RipenessLevel", 1.0)
	-- HoneyGlowController should now show full golden glow
	print("RipenessLevel forced to 1.0 — glow should be max gold")
end
```

---

## Behaviour summary

| RipenessLevel | Harvest multiplier | Visual (HoneyGlowController) | Threat context |
|---|---|---|---|
| 0.0 (fresh) | ×1.0 | Dim / no glow | OldMolasses low threat |
| 0.25 | ×1.30 | Faint amber glow | Growing threat |
| 0.50 | ×1.60 | Medium gold glow | Moderate threat |
| 0.75 | ×1.90 | Strong warm glow | High threat |
| 1.0 (fully ripe) | ×2.20 | Bright golden glow | Max threat — act now! |

- Ripeness accumulates over 120 real seconds of stored honey (2 minutes)
- Harvest resets ripeness to 0 immediately
- The 2.2× cap is the architecture's specified maximum
- The floating "🍯 ×2.2 ripe!" toast appears only at ≥ 1.10× — no toast for base harvests
- Together with HoneyGlowController (D204) and HarvestBeaconController (D210), this completes the full harvest readiness signal chain: glow → beacon → multiplier toast

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(ResourceService + CombService + HarvestController edits — no new parts)*
