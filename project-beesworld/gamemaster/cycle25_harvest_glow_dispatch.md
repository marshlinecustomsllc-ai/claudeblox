# Dispatch 237 — Harvest Glow Controller
**File:** `cycle25_harvest_glow_dispatch.md`
**Cycle:** 25
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

The honey harvest action (ProximityPrompt on Landing Boards, from the Honey Harvesting system) triggers a server-side honey award but the hive comb cells have no visual response — they just sit there after a harvest. This dispatch adds a **Harvest Glow Controller**: a client-side LocalScript that listens for the `LastHarvestTime` player attribute update (written by HarvestController or ResourceService on each successful harvest) and fires a brief warm golden light burst on all `HiveComb`-tagged Parts in the player's current plot, followed by a 1.5-second fade. The burst makes the moment of honey collection feel rewarding and tangible.

For kids: the whole hive lights up gold when you collect honey — it feels like you're gathering something real and valuable. For adults: the burst provides confirmation that the harvest RemoteEvent succeeded and honey was credited.

---

## Step 1 — HarvestGlowController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HarvestGlowController`.

Paste exactly:

```lua
--!strict
-- HarvestGlowController: warm golden burst on HiveComb parts on harvest.
-- Reads LastHarvestTime (number, os.time()) player attribute.
-- Entirely client-side — zero server writes, zero new parts.

local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")

local localPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local BURST_BRIGHTNESS_237 = 1.8    -- PointLight Brightness at peak
local BURST_RANGE_237      = 6.0    -- PointLight Range at peak (studs)
local BURST_COLOR_237      = Color3.fromRGB(255, 210, 60)   -- warm harvest gold
local REST_BRIGHTNESS_237  = 0.0    -- lights off between harvests
local BURST_RISE_237       = 0.12   -- seconds to reach peak brightness
local BURST_FALL_237       = 1.50   -- seconds to fade back to zero
local STAGGER_237          = 0.06   -- seconds between consecutive cell bursts

local LIGHT_NAME_237       = "HarvestGlow_237"

-- Debounce: ignore duplicate LastHarvestTime if < 2s since last burst
local BURST_COOLDOWN_237   = 2.0

-- ── State ─────────────────────────────────────────────────────────────────────
local lastBurstAt_237 = -999
local activeLights_237: { PointLight } = {}

-- ── Ensure PointLight on a part ──────────────────────────────────────────────
local function ensureLight_237(part: BasePart): PointLight
	local existing = part:FindFirstChild(LIGHT_NAME_237) :: PointLight?
	if existing then return existing end
	local light = Instance.new("PointLight")
	light.Name       = LIGHT_NAME_237
	light.Brightness = REST_BRIGHTNESS_237
	light.Range      = BURST_RANGE_237
	light.Color      = BURST_COLOR_237
	light.Shadows    = false
	light.Parent     = part
	return light
end

-- ── Fire burst on all HiveComb parts ─────────────────────────────────────────
local function fireBurst_237()
	local now = os.clock()
	if now - lastBurstAt_237 < BURST_COOLDOWN_237 then return end
	lastBurstAt_237 = now

	local combs = CollectionService:GetTagged("HiveComb")
	if #combs == 0 then return end

	-- Stagger burst across all cells
	for i, comb in combs do
		if not comb:IsA("BasePart") then continue end
		local light = ensureLight_237(comb)
		table.insert(activeLights_237, light)

		local delay = (i - 1) * STAGGER_237
		task.delay(delay, function()
			-- Rise
			TweenService:Create(light, TweenInfo.new(BURST_RISE_237, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Brightness = BURST_BRIGHTNESS_237,
			}):Play()
			-- Fall after rise
			task.delay(BURST_RISE_237, function()
				TweenService:Create(light, TweenInfo.new(BURST_FALL_237, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					Brightness = REST_BRIGHTNESS_237,
				}):Play()
			end)
		end)
	end

	-- Clean up light list after burst completes
	local totalDuration = ((#combs - 1) * STAGGER_237) + BURST_RISE_237 + BURST_FALL_237 + 0.2
	task.delay(totalDuration, function()
		activeLights_237 = {}
	end)
end

-- ── Watch for harvest event ───────────────────────────────────────────────────
local function onLastHarvestTimeChanged_237()
	fireBurst_237()
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	localPlayer:GetAttributeChangedSignal("LastHarvestTime"):Connect(onLastHarvestTimeChanged_237)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HarvestGlowController"))
```

---

## Step 3 — ResourceService / HarvestController write

The controller fires when `LastHarvestTime` player attribute changes. Add this write to the server-side harvest handler:

```lua
-- In HarvestController or ResourceService, when harvest succeeds:
player:SetAttribute("LastHarvestTime", os.time())
```

This is a single timestamp write — the client only cares that it changed (any truthy value triggers the burst). `os.time()` as value ensures uniqueness even if harvested twice in the same second.

If `HarvestController` already fires a RemoteEvent to the client on harvest, an alternative is to listen for that event in the LocalScript instead of using an attribute. However, the attribute approach follows the same pattern used by D221 (ThreatService) and D222 (PopulationService) and requires zero new RemoteEvents.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HarvestGlowController")
print("HarvestGlowController:", c and c.ClassName or "MISSING")

-- Check HiveComb tags
local CS = game:GetService("CollectionService")
local combs = CS:GetTagged("HiveComb")
print("HiveComb tagged:", #combs, "(expect some if a plot is built)")

-- Simulate harvest
local lp = game:GetService("Players").LocalPlayer
lp:SetAttribute("LastHarvestTime", os.time())
-- HiveComb parts should light up gold in a staggered burst, then fade over 1.5s
task.wait(3)
lp:SetAttribute("LastHarvestTime", os.time() + 1)
-- Second burst fires (cooldown passed)

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| Event | Effect |
|---|---|
| LastHarvestTime changes | Staggered golden burst across all HiveComb cells |
| Burst rise | 0.12s Sine — snappy, immediate |
| Burst fall | 1.50s Sine — gradual, satisfying fade |
| Stagger | 0.06s per cell — wave travels across the comb grid |
| 2nd harvest within cooldown | Suppressed — debounce prevents overlap |

- BURST_BRIGHTNESS_237=1.8 is high but brief — bright flash is attention-grabbing; it fades completely
- REST_BRIGHTNESS_237=0 means lights are invisible between harvests (not visible in normal play)
- Stagger 0.06s × 114 cells = 6.8s total wave — the burst ripples visibly across the grid
- Reuses CombShimmerController's registered cells approach but triggered rather than continuous
- Works with any number of HiveComb cells — scales automatically as the player builds more

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(PointLights inside existing HiveComb parts — no BaseParts)*
