# Dispatch 198 — Foraging Route Limit Warning
**File:** `cycle19_route_limit_dispatch.md`
**Cycle:** 19
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Players build foraging routes through the waggle-dance minigame, but there's no visible indication of how many routes they have active or when they're about to hit the cap. `Config.MAX_ROUTES` limits the count server-side; the client only learns they've hit it when a dance is silently rejected. This dispatch adds a **Route Limit HUD pill** — a small persistent counter ("🛣️ 2 / 3 routes") anchored to the bottom-left corner — plus a **soft-limit toast** at one route remaining ("One route slot left — dance wisely!") and a **cap toast** when fully blocked ("Route cap reached — retire a route to add a new one"). Reads the existing `RouteBeam` CollectionService tag client-side. Entirely client-side — zero server writes, zero DataService changes.

---

## Step 1 — RouteLimitController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `RouteLimitController`.

Paste exactly:

```lua
--!strict
-- RouteLimitController: live route-count pill + soft-limit and cap toasts.
-- Reads RouteBeam CollectionService tag client-side. Zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local MAX_ROUTES_198      = 3        -- must match Config.MAX_ROUTES on server
local SCAN_INTERVAL_198   = 2.5      -- seconds between tag scans
local TOAST_HOLD_198      = 3.5      -- seconds the warning toast stays visible
local SOFT_LIMIT_198      = MAX_ROUTES_198 - 1   -- warn at this count

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_198    = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_198  = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD_198 = Color3.fromRGB(242, 168,  28)
local AMBER_198      = Color3.fromRGB(220, 130,  20)
local RED_198        = Color3.fromRGB(210,  60,  40)
local GREEN_198      = Color3.fromRGB( 90, 190,  80)

-- ── State ─────────────────────────────────────────────────────────────────────
local lastCount_198   = -1
local toastActive_198 = false
local pillFrame_198: Frame?    = nil
local pillLabel_198: TextLabel? = nil

-- ── Count RouteBeam parts for this player's plot ──────────────────────────────
local function countRoutes_198(): number
	local myPlot = player:GetAttribute("PlotIndex") or 1
	local count = 0
	for _, obj in CollectionService:GetTagged("RouteBeam") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == myPlot then
			count += 1
		end
	end
	return count
end

-- ── Build persistent pill ─────────────────────────────────────────────────────
local function buildPill_198(): (Frame, TextLabel)
	local pg = player:WaitForChild("PlayerGui", 10) :: PlayerGui?
	if not pg then
		-- Fallback: no PlayerGui yet — create minimal objects to avoid nil refs
		local f = Instance.new("Frame")
		local l = Instance.new("TextLabel")
		return f, l
	end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "RouteLimitHud_198"
	sg.DisplayOrder   = 18
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Name                   = "RoutePill"
	frame.Size                   = UDim2.new(0, 100, 0, 24)
	frame.AnchorPoint            = Vector2.new(0, 1)
	frame.Position               = UDim2.new(0, 8, 1, -56)
	frame.BackgroundColor3       = DARK_BG_198
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "PillStroke"
	stroke.Color     = HONEY_GOLD_198
	stroke.Thickness = 1
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "PillText"
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "🛣️ 0 / " .. MAX_ROUTES_198 .. " routes"
	lbl.TextSize           = 11
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_198
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	return frame, lbl
end

-- ── Show warning toast ────────────────────────────────────────────────────────
local function showToast_198(msg: string, col: Color3)
	if toastActive_198 then return end
	toastActive_198 = true

	local pg = player:FindFirstChild("PlayerGui") :: PlayerGui?
	if not pg then toastActive_198 = false return end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "RouteLimitToast_198"
	sg.DisplayOrder   = 38
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = pg

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(0, 290, 0, 40)
	frame.AnchorPoint            = Vector2.new(0.5, 0)
	frame.Position               = UDim2.new(0.5, 0, 0.22, 0)
	frame.BackgroundColor3       = DARK_BG_198
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel        = 0
	frame.Parent                 = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = col
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -10, 1, 0)
	lbl.Position           = UDim2.new(0, 5, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = msg
	lbl.TextSize           = 14
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_198
	lbl.TextWrapped        = true
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	-- Fade in
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 0.1,
	}):Play()

	-- Hold then fade out
	task.delay(TOAST_HOLD_198, function()
		if not frame.Parent then
			toastActive_198 = false
			return
		end
		TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.6, function()
			if sg.Parent then sg:Destroy() end
			toastActive_198 = false
		end)
	end)
end

-- ── Update pill text + stroke colour ─────────────────────────────────────────
local function updatePill_198(count: number)
	local lbl   = pillLabel_198
	local frame = pillFrame_198
	if not lbl or not frame then return end

	lbl.Text = "🛣️ " .. count .. " / " .. MAX_ROUTES_198 .. " routes"

	-- Colour the stroke: green (free) → amber (one left) → red (capped)
	local stroke = frame:FindFirstChild("PillStroke") :: UIStroke?
	if stroke then
		if count >= MAX_ROUTES_198 then
			stroke.Color = RED_198
			lbl.TextColor3 = RED_198
		elseif count >= SOFT_LIMIT_198 then
			stroke.Color = AMBER_198
			lbl.TextColor3 = AMBER_198
		else
			stroke.Color = HONEY_GOLD_198
			lbl.TextColor3 = WAX_CREAM_198
		end
	end
end

-- ── Main scan ────────────────────────────────────────────────────────────────
local function scan_198()
	local count = countRoutes_198()
	if count == lastCount_198 then return end

	updatePill_198(count)

	-- Toast on crossing thresholds (only when count goes UP)
	if count > lastCount_198 then
		if count >= MAX_ROUTES_198 then
			showToast_198("🛣️ Route cap reached — retire a route to add a new one.", RED_198)
		elseif count >= SOFT_LIMIT_198 then
			showToast_198("🛣️ One route slot left — dance wisely!", AMBER_198)
		end
	end

	lastCount_198 = count
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(2, function()
	local f, l = buildPill_198()
	pillFrame_198 = f
	pillLabel_198 = l

	-- Initial scan
	scan_198()

	-- CollectionService hooks for immediate updates
	CollectionService:GetInstanceAddedSignal("RouteBeam"):Connect(function()
		task.wait(0.3)
		scan_198()
	end)
	CollectionService:GetInstanceRemovedSignal("RouteBeam"):Connect(function()
		task.wait(0.1)
		scan_198()
	end)

	-- Periodic re-scan as safety net
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= SCAN_INTERVAL_198 then
			acc = 0
			scan_198()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("RouteLimitController"))
```

---

## Step 3 — Config alignment

`RouteLimitController` hard-codes `MAX_ROUTES_198 = 3` to match `Config.MAX_ROUTES`. If `Config.MAX_ROUTES` is a different value, update the constant to match:

```lua
-- In RouteLimitController, line near top:
local MAX_ROUTES_198 = 3   -- ← change this to match Config.MAX_ROUTES
```

Alternatively, if `Config` is accessible from a LocalScript (it is, since it lives in ReplicatedStorage.Modules):

```lua
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Config"))
local MAX_ROUTES_198 = Config.MAX_ROUTES or 3
```

Either approach works; the hard-coded constant avoids a WaitForChild dependency at the cost of a manual sync if `Config.MAX_ROUTES` changes.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("RouteLimitController")
print("RouteLimitController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  countRoutes_198:", c.Source:find("countRoutes_198") ~= nil)
	print("  buildPill_198:", c.Source:find("buildPill_198") ~= nil)
	print("  showToast_198:", c.Source:find("showToast_198") ~= nil)
	print("  MAX_ROUTES_198:", c.Source:find("MAX_ROUTES_198") ~= nil)
	print("  SOFT_LIMIT_198:", c.Source:find("SOFT_LIMIT_198") ~= nil)
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
RouteLimitController: LocalScript
  lines: 150+
  countRoutes_198: true
  buildPill_198: true
  showToast_198: true
  MAX_ROUTES_198: true
  SOFT_LIMIT_198: true
RouteBeam tagged parts: 0  (0 in Edit mode)
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Route count | Pill stroke / text | Toast |
|---|---|---|
| 0–1 (free slots) | Honey Gold | none |
| 2 (one slot left) | Amber | "🛣️ One route slot left — dance wisely!" |
| 3 / cap (MAX_ROUTES_198) | Red | "🛣️ Route cap reached — retire a route to add a new one." |

- Pill sits bottom-left, 8px from edge, 56px above the screen base (above mobile controls)
- Pill is persistent — visible the whole session once first route is created
- Toast only fires when count **increases** to the threshold — no repeat spam on each scan
- `toastActive_198` flag prevents toast overlap
- CollectionService Added/Removed hooks give near-instant response; Heartbeat 2.5s scan catches any missed updates
- Pill hidden until the first RouteBeam tag appears (size 100×24, negligible)

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(RouteLimitHud_198 ScreenGui + RouteLimitToast_198 are GuiObjects parented to PlayerGui — not BaseParts)*
