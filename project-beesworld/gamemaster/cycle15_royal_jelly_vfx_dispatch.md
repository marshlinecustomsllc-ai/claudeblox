# Dispatch 173 — Royal Jelly Flask VFX
**File:** `cycle15_royal_jelly_vfx_dispatch.md`
**Cycle:** 15
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When a player uses the `royal_jelly_flask` consumable, nothing currently happens visually beyond a generic notification. This dispatch adds:

1. A **golden shimmer burst** that rises from the player's queen cell (or deck center if no queen cell is built yet) — warm gold particles spiraling upward, lasting ~2 seconds.
2. A **brief glow pulse** on the HiveGui Queen tab button: the tab border flashes gold-white three times, signalling "your queen just got a boost."
3. A small **"👑 +Jelly!" toast** (2s, bottom-center) so the effect reads on mobile where particle effects may be less visible.

Entirely client-side. No new permanent parts — the shimmer anchor is ephemeral. Listens to `ConsumableUsed` RemoteEvent (kind="royal_jelly_flask") with `Notify` fallback.

---

## Step 1 — RoyalJellyController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `RoyalJellyController`.

Paste exactly:

```lua
--!strict
-- RoyalJellyController: VFX + HiveGui Queen tab pulse when royal_jelly_flask is used
-- Shimmer burst rises from queen cell; HiveGui QUEEN tab flashes; toast pops.
-- Listens to ConsumableUsed RemoteEvent (kind="royal_jelly_flask") or Notify fallback.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Palette ───────────────────────────────────────────────────────────────────
local HONEY_GOLD_173  = Color3.fromRGB(242, 168, 28)
local ROYAL_GOLD_173  = Color3.fromRGB(255, 210, 60)
local WHITE_GLOW_173  = Color3.fromRGB(255, 245, 200)
local WAX_CREAM_173   = Color3.fromRGB(232, 212, 154)
local DARK_BG_173     = Color3.fromRGB(30,  18,  8)

-- ── Find queen cell position ──────────────────────────────────────────────────
local function findQueenCellPos_173(): Vector3
	local myPlot = player:GetAttribute("PlotIndex") or 1
	-- RoyalCell tag (preferred)
	for _, part in CollectionService:GetTagged("RoyalCell") do
		if part:IsA("BasePart") and part:GetAttribute("PlotIndex") == myPlot then
			return part.Position + Vector3.new(0, 4, 0)
		end
	end
	-- Fallback: CombCell with CellType="Royal"
	for _, part in CollectionService:GetTagged("CombCell") do
		if part:IsA("BasePart") and part:GetAttribute("PlotIndex") == myPlot
			and part:GetAttribute("CellType") == "Royal" then
			return part.Position + Vector3.new(0, 4, 0)
		end
	end
	-- Fallback: deck center (DanceFloorCentrePlate)
	for _, part in CollectionService:GetTagged("DimCellPlate") do
		if part:IsA("BasePart") and part:GetAttribute("PlotIndex") == myPlot then
			local q = part:GetAttribute("Q") or 0
			local r = part:GetAttribute("R") or 0
			if q == 0 and r == 0 then
				return part.Position + Vector3.new(0, 6, 0)
			end
		end
	end
	-- Last resort: player character root
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and (root.Position + Vector3.new(0, 3, 0)) or Vector3.new(0, 10, 0)
end

-- ── Shimmer burst VFX ─────────────────────────────────────────────────────────
local burstActive_173 = false

local function playShimmerBurst_173()
	if burstActive_173 then return end
	burstActive_173 = true

	local origin = findQueenCellPos_173()

	-- Ephemeral anchor at queen cell position
	local anchor = Instance.new("Part")
	anchor.Name          = "RoyalJellyAnchor_173"
	anchor.Size          = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position      = origin
	anchor.Anchored      = true
	anchor.CanCollide    = false
	anchor.Transparency  = 1
	anchor.CastShadow    = false
	anchor.Parent        = workspace

	-- Rising shimmer emitter (particles spiral upward)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name              = "RoyalShimmer_173"
	emitter.Enabled           = false
	emitter.Rate              = 0
	emitter.Lifetime          = NumberRange.new(1.0, 1.8)
	emitter.Speed             = NumberRange.new(5, 12)
	emitter.SpreadAngle       = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Top  -- rises upward
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.30),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1,   0.0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0.0),
		NumberSequenceKeypoint.new(0.6, 0.2),
		NumberSequenceKeypoint.new(1,   1.0),
	})
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   WHITE_GLOW_173),
		ColorSequenceKeypoint.new(0.4, ROYAL_GOLD_173),
		ColorSequenceKeypoint.new(1,   HONEY_GOLD_173),
	})
	emitter.LightEmission  = 0.6
	emitter.LightInfluence = 0.3
	emitter.RotSpeed       = NumberRange.new(-180, 180)
	emitter.Rotation       = NumberRange.new(0, 360)
	-- Gentle upward drift + outward spiral approximation
	emitter.Acceleration   = Vector3.new(0, 2, 0)
	emitter.Parent         = anchor

	-- Burst: 30 particles in one shot
	emitter:Emit(30)

	-- Small PointLight burst at queen cell
	local light = Instance.new("PointLight")
	light.Brightness = 8
	light.Range      = 14
	light.Color      = ROYAL_GOLD_173
	light.Parent     = anchor

	-- Fade light out
	TweenService:Create(light, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0, Range = 0 }):Play()

	-- Cleanup after particles expire
	task.delay(2.2, function()
		anchor:Destroy()
		burstActive_173 = false
	end)
end

-- ── HiveGui Queen tab flash ───────────────────────────────────────────────────
local function flashQueenTab_173()
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	if not hiveGui then return end

	-- Try common Queen tab button names
	local tabNames = { "QueenTab", "QUEEN", "QueenButton", "TabQueen" }
	local queenTab: GuiObject? = nil
	for _, name in tabNames do
		local found = hiveGui:FindFirstChild(name, true) :: GuiObject?
		if found then queenTab = found; break end
	end
	if not queenTab then return end

	-- Flash the UIStroke or BackgroundColor 3 times
	local stroke = queenTab:FindFirstChildOfClass("UIStroke") :: UIStroke?
	if stroke then
		local origColor = stroke.Color
		local origThick = stroke.Thickness
		for i = 1, 3 do
			task.delay((i - 1) * 0.25, function()
				-- Flash bright
				TweenService:Create(stroke, TweenInfo.new(0.08),
					{ Color = WHITE_GLOW_173, Thickness = 3 }):Play()
				task.delay(0.12, function()
					-- Return to gold
					TweenService:Create(stroke, TweenInfo.new(0.1),
						{ Color = HONEY_GOLD_173, Thickness = 2 }):Play()
				end)
				if i == 3 then
					task.delay(0.25, function()
						-- Restore original
						TweenService:Create(stroke, TweenInfo.new(0.15),
							{ Color = origColor, Thickness = origThick }):Play()
					end)
				end
			end)
		end
	else
		-- No UIStroke: flash BackgroundColor
		local origColor = queenTab.BackgroundColor3
		for i = 1, 3 do
			task.delay((i - 1) * 0.25, function()
				TweenService:Create(queenTab, TweenInfo.new(0.08),
					{ BackgroundColor3 = WHITE_GLOW_173 }):Play()
				task.delay(0.12, function()
					TweenService:Create(queenTab, TweenInfo.new(0.1),
						{ BackgroundColor3 = HONEY_GOLD_173 }):Play()
				end)
				if i == 3 then
					task.delay(0.25, function()
						TweenService:Create(queenTab, TweenInfo.new(0.15),
							{ BackgroundColor3 = origColor }):Play()
					end)
				end
			end)
		end
	end
end

-- ── Toast ─────────────────────────────────────────────────────────────────────
local toastGui_173: ScreenGui? = nil
local toastFrame_173: Frame? = nil

local function ensureToast_173()
	if toastGui_173 and toastGui_173.Parent then return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "RoyalJellyToastGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 18
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui
	toastGui_173 = sg

	local frame = Instance.new("Frame")
	frame.Name              = "RoyalJellyToast"
	frame.Size              = UDim2.new(0, 140, 0, 30)
	frame.Position          = UDim2.new(0.5, -70, 1, 20)  -- starts below screen
	frame.BackgroundColor3  = DARK_BG_173
	frame.BorderSizePixel   = 0
	frame.Visible           = false
	frame.ZIndex            = 40
	frame.Parent            = sg
	toastFrame_173 = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = ROYAL_GOLD_173
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local label = Instance.new("TextLabel")
	label.Size              = UDim2.new(1, -8, 1, 0)
	label.Position          = UDim2.new(0, 4, 0, 0)
	label.BackgroundTransparency = 1
	label.Text              = "👑 +Jelly!"
	label.TextSize          = 13
	label.Font              = Enum.Font.GothamBold
	label.TextColor3        = ROYAL_GOLD_173
	label.TextXAlignment    = Enum.TextXAlignment.Center
	label.ZIndex            = 41
	label.Parent            = frame
end

local toastShowing_173 = false

local function showToast_173()
	ensureToast_173()
	local frame = toastFrame_173
	if not frame or toastShowing_173 then return end
	toastShowing_173 = true
	frame.Visible = true

	-- Slide up from below
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, -70, 1, -48) }):Play()

	task.delay(2.0, function()
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, -70, 1, 20) }):Play()
		task.delay(0.25, function()
			frame.Visible = false
			toastShowing_173 = false
		end)
	end)
end

-- ── Trigger all effects ───────────────────────────────────────────────────────
local function onRoyalJellyUsed_173()
	playShimmerBurst_173()
	flashQueenTab_173()
	showToast_173()
end

-- ── Listen for consumable events ──────────────────────────────────────────────
local consumableUsed = Remotes:FindFirstChild("ConsumableUsed") :: RemoteEvent?
if consumableUsed then
	consumableUsed.OnClientEvent:Connect(function(kind: string)
		if kind == "royal_jelly_flask" then
			onRoyalJellyUsed_173()
		end
	end)
end

-- Notify fallback
local notify = Remotes:FindFirstChild("Notify") :: RemoteEvent?
if notify then
	notify.OnClientEvent:Connect(function(msg: string, kind: string?)
		if kind == "purchase" and msg and msg:lower():find("royal") and msg:lower():find("jell") then
			onRoyalJellyUsed_173()
		end
	end)
end
```

---

## Step 2 — ConsumableService patch (if not already firing ConsumableUsed)

Open **ConsumableService** (ServerScriptService.Systems) and inside the `royal_jelly_flask` use case, after applying the jelly effect, add:

```lua
local ConsumableUsed_173 = Remotes:FindFirstChild("ConsumableUsed")
if ConsumableUsed_173 then
	local ok = pcall(function()
		ConsumableUsed_173:FireClient(player, itemId)  -- itemId = "royal_jelly_flask"
	end)
end
```

If `ConsumableUsed` doesn't exist yet (check with the Step 3 verification), create it first:

```lua
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
if not R:FindFirstChild("ConsumableUsed") then
	local re = Instance.new("RemoteEvent")
	re.Name   = "ConsumableUsed"
	re.Parent = R
	print("ConsumableUsed created")
end
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("RoyalJellyController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("RoyalJellyController")
print("RoyalJellyController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  playShimmerBurst_173:", c.Source:find("playShimmerBurst_173") ~= nil)
	print("  flashQueenTab_173:", c.Source:find("flashQueenTab_173") ~= nil)
	print("  showToast_173:", c.Source:find("showToast_173") ~= nil)
	print("  ConsumableUsed listener:", c.Source:find("ConsumableUsed") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
RoyalJellyController: LocalScript
  lines: 180+
  playShimmerBurst_173: true
  flashQueenTab_173: true
  showToast_173: true
  ConsumableUsed listener: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Trigger | Effect |
|---------|--------|
| royal_jelly_flask consumable used | 30 shimmer particles rise from queen cell (or deck center), WHITE→GOLD→AMBER gradient |
| PointLight burst | 8 brightness, range 14 at queen cell; fades to 0 over 1.2s |
| HiveGui QUEEN tab | UIStroke flashes WHITE→GOLD 3× over 0.75s then restores original |
| Toast | "👑 +Jelly!" slides up from bottom-center (140×30), 2s duration |
| No queen cell built | Particles burst at deck center (Q=0, R=0) instead |
| Burst lock | `burstActive_173` prevents stacking if used twice rapidly |
| Event fallback | `Notify` message containing "royal" + "jell" triggers same effects |

**Part budget: +0 permanent (shimmer anchor is ephemeral) → 4,204 / 5,000**
