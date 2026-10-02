# Dispatch 162 — Honey Ripeness Showcase
**File:** `cycle15_ripeness_showcase_dispatch.md`
**Branch:** add-beesworld-project
**Part budget:** +0 new world parts → 4,198 / 5,000

---

## Overview

The architecture's single most atmospheric social mechanic: banked honey ripens in place,
glows brighter as it ages, and that glow is VISIBLE FROM EVERY OTHER PLOT IN THE SHARED
SERVER — creating public, visible risk/reward tension. Old Molasses always targets the
ripest comb. This dispatch wires the existing ripeness math into a live neon-glow effect
on comb cells, broadcasts a server-wide "richest hive" label, and adds a small UI pill
showing each player their own ripeness progress.

The mechanics are already partially built (CombService has ripeness math from dispatch 3-era
work). This dispatch adds the VISIBLE layer: neon intensity on HoneyBlob CombCells,
a server-wide broadcast of who has the ripest hive, and a local ripeness gauge in the HUD.

**What gets built:**
1. `RipenessVisualService` Script — polls CombCell ripeness per plot, adjusts HoneyBlob neon
   brightness, fires `RipenessSync` RemoteEvent for each player + server-wide richest broadcast
2. `RipenessController` LocalScript — local ripeness pill HUD element + glowing cell visual
   response + server "ripest hive" notification toast
3. No DataService migration needed (ripeness lives in CombService already)
4. +0 world parts

---

## Step 1 — RipenessVisualService Script

In Studio Explorer: **ServerScriptService** → Insert **Script**, rename
`RipenessVisualService`.

Paste full source:

```lua
--!strict
-- RipenessVisualService: syncs honey ripeness to neon brightness on comb cells.
-- Broadcasts server-wide "richest hive" info so all players can see who's most at risk.

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ── Config ─────────────────────────────────────────────────────────────────────
local POLL_INTERVAL_162  = 5        -- seconds between ripeness sweeps
local MAX_RIPENESS_162   = 2.2      -- matches Config.RIPENESS_MAX (default 2.2x)
local MIN_NEON_162       = 0.5      -- PointLight Range at ripeness 1.0 (just banked)
local MAX_NEON_162       = 4.0      -- PointLight Range at ripeness 2.2 (fully ripe)
local MAX_BRIGHT_162     = 1.5      -- PointLight Brightness max

-- ── Remotes ────────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name   = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local function getOrCreateRemote_162(name: string): RemoteEvent
	local existing = Remotes:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then return existing :: RemoteEvent end
	local re = Instance.new("RemoteEvent")
	re.Name   = name
	re.Parent = Remotes
	return re
end

local RipenessSync_162    = getOrCreateRemote_162("RipenessSync")     -- per-player ripeness data
local RipestHiveSync_162  = getOrCreateRemote_162("RipestHiveSync")   -- server-wide richest alert

-- ── Helpers ────────────────────────────────────────────────────────────────────

-- Map ripeness (1.0 – 2.2) to a 0–1 fraction
local function ripenessFrac_162(ripeness: number): number
	return math.clamp((ripeness - 1.0) / (MAX_RIPENESS_162 - 1.0), 0, 1)
end

-- Find or create a PointLight inside a CombCell part
local function ensureLight_162(part: BasePart): PointLight
	local light = part:FindFirstChildOfClass("PointLight")
	if not light then
		light = Instance.new("PointLight")
		light.Color      = Color3.fromRGB(255, 200, 60)   -- warm honey amber
		light.Range      = MIN_NEON_162
		light.Brightness = 0.5
		light.Shadows    = false
		light.Parent     = part
	end
	return light :: PointLight
end

-- Return the total average ripeness across all HoneyBlob-tagged cells for a plotIndex
-- Ripeness is stored as a "Ripeness" attribute on each HoneyBlob part by CombService.
local function plotRipeness_162(plotIndex: number): (number, number)
	local total   = 0
	local count   = 0
	local maxRipe = 0
	for _, part in CollectionService:GetTagged("HoneyBlob") do
		if part:GetAttribute("PlotIndex") == plotIndex then
			local r = (part:GetAttribute("Ripeness") :: number?) or 1.0
			total = total + r
			count = count + 1
			if r > maxRipe then maxRipe = r end
		end
	end
	local avg = count > 0 and (total / count) or 1.0
	return avg, maxRipe
end

-- ── Main poll loop ─────────────────────────────────────────────────────────────
local function runLoop_162()
	while true do
		task.wait(POLL_INTERVAL_162)

		local richestPlayer: string = ""
		local richestMax: number   = 0

		for _, player in Players:GetPlayers() do
			local plotIndex = player:GetAttribute("PlotIndex") :: number?
			if not plotIndex then continue end

			local avgRipe, maxRipe = plotRipeness_162(plotIndex)
			local frac = ripenessFrac_162(maxRipe)

			-- Update PointLights on this plot's HoneyBlob cells
			for _, part in CollectionService:GetTagged("HoneyBlob") do
				if part:GetAttribute("PlotIndex") == plotIndex and part:IsA("BasePart") then
					local cellRipe = (part:GetAttribute("Ripeness") :: number?) or 1.0
					local cellFrac = ripenessFrac_162(cellRipe)
					local light    = ensureLight_162(part)
					light.Range      = MIN_NEON_162 + cellFrac * (MAX_NEON_162 - MIN_NEON_162)
					light.Brightness = 0.3 + cellFrac * (MAX_BRIGHT_162 - 0.3)
					-- Also shift neon color toward deep gold at full ripeness
					local r = 255
					local g = math.round(200 - cellFrac * 60)   -- 200→140 (more orange)
					local b = math.round(60  - cellFrac * 50)   -- 60→10
					light.Color = Color3.fromRGB(r, g, b)
				end
			end

			-- Send per-player ripeness summary to their client
			pcall(function()
				RipenessSync_162:FireClient(player, {
					avgRipeness = avgRipe,
					maxRipeness = maxRipe,
					frac        = frac,
				})
			end)

			-- Track server-wide richest
			if maxRipe > richestMax then
				richestMax    = maxRipe
				richestPlayer = player.DisplayName or player.Name
			end
		end

		-- Broadcast richest hive info to everyone (if someone is meaningfully ripe)
		if richestMax >= 1.5 then
			pcall(function()
				RipestHiveSync_162:FireAllClients({
					playerName  = richestPlayer,
					maxRipeness = richestMax,
					frac        = ripenessFrac_162(richestMax),
				})
			end)
		end
	end
end

-- Startup
task.spawn(runLoop_162)
print("[RipenessVisualService] started — polling every", POLL_INTERVAL_162, "seconds")
```

**Verification:**

```lua
-- Check script created
local s = game:GetService("ServerScriptService"):FindFirstChild("RipenessVisualService")
print(s and s.ClassName or "MISSING")
-- Expected: Script

-- Check RemoteEvents
local R = game:GetService("ReplicatedStorage").Remotes
print(R:FindFirstChild("RipenessSync") and "OK" or "MISSING", R:FindFirstChild("RipestHiveSync") and "OK" or "MISSING")
-- Expected: OK  OK
```

---

## Step 2 — RipenessController LocalScript

In Studio Explorer: **StarterPlayer → StarterPlayerScripts** → Insert **LocalScript**,
rename `RipenessController`.

Paste full source:

```lua
--!strict
-- RipenessController: local ripeness gauge HUD pill + richest-hive toast alert.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────────────────
local HONEY_GOLD_162  = Color3.fromRGB(242, 168, 28)
local PROPOLIS_162    = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_162   = Color3.fromRGB(232, 212, 154)
local AMBER_162       = Color3.fromRGB(220, 120, 0)
local RED_RIPE_162    = Color3.fromRGB(220, 60, 20)

-- ── Build ripeness pill ────────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "RipenessGui"
sg.DisplayOrder   = 12
sg.ResetOnSpawn   = false
sg.IgnoreGuiInset = true
sg.Parent         = playerGui

-- Pill frame (bottom-left, above BeePopPill and FriendPill)
local pill = Instance.new("Frame")
pill.Name              = "RipenessPill"
pill.AnchorPoint       = Vector2.new(0, 1)
pill.Position          = UDim2.new(0, 8, 1, -148)   -- above FriendPill
pill.Size              = UDim2.new(0, 160, 0, 28)
pill.BackgroundColor3  = PROPOLIS_162
pill.BackgroundTransparency = 0.25
pill.BorderSizePixel   = 0
pill.Parent            = sg
local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(0, 10)
pillCorner.Parent = pill

-- Bar fill (tracks ripeness fraction)
local bar = Instance.new("Frame")
bar.Name              = "RipenessBar"
bar.Size              = UDim2.new(0, 0, 1, -4)   -- starts empty, width set dynamically
bar.Position          = UDim2.new(0, 2, 0, 2)
bar.BackgroundColor3  = HONEY_GOLD_162
bar.BorderSizePixel   = 0
bar.Parent            = pill
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 8)
barCorner.Parent = bar

-- Label
local label = Instance.new("TextLabel")
label.Name                  = "RipenessLabel"
label.Size                  = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.TextColor3            = WAX_CREAM_162
label.TextSize              = 13
label.Font                  = Enum.Font.GothamBold
label.Text                  = "🍯 Ripeness: 1.0x"
label.ZIndex                = 2
label.Parent                = pill

-- ── Toast for richest-hive alert ───────────────────────────────────────────────
local toastActive_162 = false

local function showRichestToast_162(data: { playerName: string, maxRipeness: number, frac: number })
	if toastActive_162 then return end
	toastActive_162 = true

	local toast = Instance.new("Frame")
	toast.Name             = "RichestToast"
	toast.AnchorPoint      = Vector2.new(0.5, 0)
	toast.Position         = UDim2.new(0.5, 0, -0.1, 0)
	toast.Size             = UDim2.new(0, 300, 0, 48)
	toast.BackgroundColor3 = Color3.fromRGB(60, 20, 5)
	toast.BorderSizePixel  = 0
	toast.ZIndex           = 20
	toast.Parent           = sg
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 12)
	tc.Parent = toast
	local ts = Instance.new("UIStroke")
	ts.Color     = RED_RIPE_162
	ts.Thickness = 2
	ts.Parent    = toast

	local toastLbl = Instance.new("TextLabel")
	toastLbl.Size               = UDim2.fromScale(1, 1)
	toastLbl.BackgroundTransparency = 1
	toastLbl.TextColor3         = WAX_CREAM_162
	toastLbl.TextSize           = 14
	toastLbl.Font               = Enum.Font.GothamBold
	toastLbl.TextWrapped        = true
	local ripePct = math.round(data.maxRipeness * 100 - 100)
	toastLbl.Text = "🐻 " .. data.playerName .. "'s hive is +" .. ripePct .. "% ripe — Molasses is watching!"
	toastLbl.ZIndex = 21
	toastLbl.Parent = toast

	-- Slide in from top
	TweenService:Create(toast,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 8) }
	):Play()

	task.delay(5, function()
		TweenService:Create(toast,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, -0.1, 0) }
		):Play()
		task.delay(0.35, function()
			toast:Destroy()
			toastActive_162 = false
		end)
	end)
end

-- ── React to ripeness sync ─────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if Remotes then
	local ripenessSync = Remotes:WaitForChild("RipenessSync", 10) :: RemoteEvent?
	if ripenessSync then
		ripenessSync.OnClientEvent:Connect(function(data: any)
			local frac     = data.frac        or 0
			local maxRipe  = data.maxRipeness or 1.0

			-- Update bar width
			local targetWidth = frac * (pill.AbsoluteSize.X - 4)
			TweenService:Create(bar,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = UDim2.new(0, targetWidth, 1, -4) }
			):Play()

			-- Update bar color (gold → amber → red-orange as ripe increases)
			local barColor: Color3
			if frac < 0.5 then
				barColor = HONEY_GOLD_162:Lerp(AMBER_162, frac * 2)
			else
				barColor = AMBER_162:Lerp(RED_RIPE_162, (frac - 0.5) * 2)
			end
			bar.BackgroundColor3 = barColor

			-- Update label
			local ripeStr = string.format("%.2f", maxRipe)
			if frac > 0.7 then
				label.Text       = "🐻 Ripeness: " .. ripeStr .. "x"
				label.TextColor3 = RED_RIPE_162
			elseif frac > 0.3 then
				label.Text       = "🍯 Ripeness: " .. ripeStr .. "x"
				label.TextColor3 = AMBER_162
			else
				label.Text       = "🍯 Ripeness: " .. ripeStr .. "x"
				label.TextColor3 = WAX_CREAM_162
			end
		end)
	end

	local richestSync = Remotes:WaitForChild("RipestHiveSync", 10) :: RemoteEvent?
	if richestSync then
		richestSync.OnClientEvent:Connect(function(data: any)
			-- Only show the bear-warning toast if it's about someone ELSE's hive,
			-- or if it's the local player's own (warn them they're the target!)
			showRichestToast_162(data)
		end)
	end
end
```

**Verification:**

```lua
local lrc = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("RipenessController")
print(lrc and lrc.ClassName or "MISSING")
-- Expected: LocalScript
```

---

## Step 3 — HoneyBlob Ripeness Attribute Backfill

The RipenessVisualService reads `Ripeness` attribute on `HoneyBlob`-tagged parts.
CombService may or may not already set this attribute. Run this backfill to ensure all
existing HoneyBlob cells have the attribute (new cells will have it set by CombService):

```lua
-- STEP 3: Backfill Ripeness=1.0 on any HoneyBlob parts missing the attribute
local CS = game:GetService("CollectionService")
local count = 0
for _, part in CS:GetTagged("HoneyBlob") do
    if part:GetAttribute("Ripeness") == nil then
        part:SetAttribute("Ripeness", 1.0)
        count = count + 1
    end
end
print("Backfilled Ripeness=1.0 on", count, "HoneyBlob parts")
-- Expected: 0 (if CombService already sets it) or N (if it doesn't -- both fine)
```

If CombService does NOT currently set `Ripeness` on HoneyBlob cells when depositing honey,
add this line to CombService's deposit logic after the honey deposit:

```lua
-- In CombService, wherever honey is deposited into a cell:
part:SetAttribute("Ripeness", part:GetAttribute("Ripeness") or 1.0)
```

And wherever ripeness advances over time (the existing ripeness tick loop):

```lua
-- In CombService ripeness tick, after updating the internal ripeness value:
part:SetAttribute("Ripeness", newRipenessValue)
```

This makes the RipenessVisualService's PointLight adjustments reflect real CombService data.

---

## Step 4 — Verification in Play Mode (F5)

```lua
-- 1. Check RipenessVisualService is running
local s = game:GetService("ServerScriptService"):FindFirstChild("RipenessVisualService")
print("Script:", s and s.ClassName or "MISSING", "| Enabled:", s and s.Enabled or false)

-- 2. Manually advance a HoneyBlob cell to max ripeness and confirm light updates
local CS = game:GetService("CollectionService")
local blobs = CS:GetTagged("HoneyBlob")
if #blobs > 0 then
    local part = blobs[1]
    part:SetAttribute("Ripeness", 2.2)
    task.wait(6)  -- wait one poll cycle
    local light = part:FindFirstChildOfClass("PointLight")
    print("Light Range:", light and light.Range or "NO LIGHT")
    -- Expected: ~4.0 (MAX_NEON_162)
    print("Light Color:", light and tostring(light.Color) or "N/A")
    -- Expected: dark amber (R=255, G≈140, B≈10)
end

-- 3. Check RemoteEvents exist
local R = game:GetService("ReplicatedStorage").Remotes
print("RipenessSync:", R:FindFirstChild("RipenessSync") and "OK" or "MISSING")
print("RipestHiveSync:", R:FindFirstChild("RipestHiveSync") and "OK" or "MISSING")
```

**Expected full behaviour in Play mode:**
- Honey cells with higher ripeness glow brighter with warmer amber light
- At max ripeness (2.2x), cells pulse deep orange/amber — visible from neighbouring plots
- Local HUD pill (bottom-left, above FriendPill) shows a fill bar that grows as honey ripens
- Bar color shifts gold → amber → red-orange at high ripeness; label text gains bear emoji 🐻
- When any player's ripeness ≥ 1.5x, all players see a top-of-screen toast:
  "🐻 [PlayerName]'s hive is +50% ripe — Molasses is watching!"

---

## Step 5 — state.json update

After executing in Studio, update `dispatch_count` to 162 and `last_dispatch` to
`"cycle15_ripeness_showcase_dispatch.md"` in state.json.

---

## Summary

| What | Where |
|---|---|
| `RipenessVisualService` | `ServerScriptService` Script |
| `RipenessController` | `StarterPlayer.StarterPlayerScripts` LocalScript |
| `RipenessSync` RemoteEvent | `ReplicatedStorage.Remotes` |
| `RipestHiveSync` RemoteEvent | `ReplicatedStorage.Remotes` |
| HoneyBlob Ripeness attribute backfill | Command Bar step |
| New world parts | **0** → total **4,198 / 5,000** |

**Kid experience:** Honey cells light up brighter the longer you leave them — and when someone's
hive is glowing really bright, a bear warning pops up for everyone. It looks cool AND scary.

**Adult experience:** Precise ripeness multiplier in the HUD pill (e.g., "Ripeness: 1.87x"),
a fill bar that tracks progress toward the 2.2x cap, and a server-wide bear-alert toast
with the exact player name and percentage — so you know when to harvest and when to worry.
