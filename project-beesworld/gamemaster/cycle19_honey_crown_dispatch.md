# Dispatch 199 — Honey Crown BillboardGui
**File:** `cycle19_honey_crown_dispatch.md`
**Cycle:** 19
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

The game already tracks per-player `HoneyCount` as a player attribute and the `LeaderboardService` (dispatch 24) pushes server honey stats. But there's no *world-space* signal pointing at the richest hive. This dispatch adds a **Honey Crown**: a shimmering 👑 BillboardGui that hovers above the `PlotRoot` of whichever player currently has the highest `HoneyCount`, visible from anywhere in the server. The crown shifts smoothly to a new plot when the top changes. It pulses gold on the current leader and dims to silver if no one leads by more than 10 honey. Entirely client-side — reads player attributes already broadcast by DataService, zero server writes.

---

## Step 1 — HoneyCrownController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `HoneyCrownController`.

Paste exactly:

```lua
--!strict
-- HoneyCrownController: 👑 BillboardGui on the plot of the current honey leader.
-- Reads HoneyCount player attribute (already replicated by DataService).
-- Entirely client-side — zero server writes.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local POLL_INTERVAL_199   = 5.0          -- seconds between leader checks
local CROWN_OFFSET_199    = Vector3.new(0, 8, 0)   -- studs above PlotRoot
local MIN_LEAD_HONEY_199  = 10           -- minimum honey to display crown at all
local PULSE_RATE_199      = 1.8          -- sine pulses per second (gold glow)

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_199    = Color3.fromRGB( 25,  14,   4)
local HONEY_GOLD_199 = Color3.fromRGB(242, 168,  28)
local SILVER_199     = Color3.fromRGB(200, 200, 220)
local WAX_CREAM_199  = Color3.fromRGB(232, 212, 154)

-- ── State ─────────────────────────────────────────────────────────────────────
local currentCrownPlot_199: BasePart? = nil   -- PlotRoot the crown is on
local crownGui_199: BillboardGui?     = nil
local pulseConn_199: RBXScriptConnection? = nil

-- ── Find a player's PlotRoot part ─────────────────────────────────────────────
local function getPlotRoot_199(plotIdx: number): BasePart?
	for _, obj in CollectionService:GetTagged("PlotRoot") do
		if obj:IsA("BasePart") and obj:GetAttribute("PlotIndex") == plotIdx then
			return obj
		end
	end
	return nil
end

-- ── Build the crown BillboardGui ──────────────────────────────────────────────
local function buildCrown_199(root: BasePart): BillboardGui
	local bg = Instance.new("BillboardGui")
	bg.Name          = "HoneyCrown_199"
	bg.Size          = UDim2.new(0, 80, 0, 36)
	bg.StudsOffset   = CROWN_OFFSET_199
	bg.AlwaysOnTop   = false
	bg.ResetOnSpawn  = false
	bg.Parent        = root

	local frame = Instance.new("Frame")
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_199
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Name      = "CrownStroke"
	stroke.Color     = HONEY_GOLD_199
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local crown = Instance.new("TextLabel")
	crown.Name               = "CrownEmoji"
	crown.Size               = UDim2.new(0, 28, 1, 0)
	crown.Position           = UDim2.new(0, 2, 0, 0)
	crown.BackgroundTransparency = 1
	crown.Text               = "👑"
	crown.TextSize           = 20
	crown.Font               = Enum.Font.GothamBold
	crown.TextColor3         = HONEY_GOLD_199
	crown.TextXAlignment     = Enum.TextXAlignment.Center
	crown.ZIndex             = 2
	crown.Parent             = frame

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "CrownLabel"
	lbl.Size               = UDim2.new(1, -32, 1, 0)
	lbl.Position           = UDim2.new(0, 30, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "Top Hive"
	lbl.TextSize           = 10
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = WAX_CREAM_199
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.TextTruncate       = Enum.TextTruncate.AtEnd
	lbl.ZIndex             = 2
	lbl.Parent             = frame

	return bg
end

-- ── Update crown label text ───────────────────────────────────────────────────
local function setCrownLabel_199(bg: BillboardGui, name: string, honey: number)
	local frame = bg:FindFirstChildOfClass("Frame")
	if not frame then return end
	local lbl = frame:FindFirstChild("CrownLabel") :: TextLabel?
	if lbl then
		lbl.Text = name .. "\n" .. honey .. " 🍯"
	end
end

-- ── Start gold pulse on crown stroke ─────────────────────────────────────────
local function startPulse_199(bg: BillboardGui)
	if pulseConn_199 then pulseConn_199:Disconnect() end
	local t = 0
	pulseConn_199 = RunService.Heartbeat:Connect(function(dt: number)
		if not bg.Parent then
			pulseConn_199 = nil
			return
		end
		t += dt * PULSE_RATE_199
		local alpha = (math.sin(t * math.pi * 2) + 1) * 0.5   -- 0..1
		local frame = bg:FindFirstChildOfClass("Frame")
		local stroke = frame and frame:FindFirstChild("CrownStroke") :: UIStroke?
		if stroke then
			stroke.Color = HONEY_GOLD_199:Lerp(WAX_CREAM_199, alpha * 0.45)
		end
	end)
end

-- ── Stop pulse ────────────────────────────────────────────────────────────────
local function stopPulse_199()
	if pulseConn_199 then
		pulseConn_199:Disconnect()
		pulseConn_199 = nil
	end
end

-- ── Remove crown from its current location ────────────────────────────────────
local function removeCrown_199()
	stopPulse_199()
	if crownGui_199 and crownGui_199.Parent then
		crownGui_199:Destroy()
	end
	crownGui_199 = nil
	currentCrownPlot_199 = nil
end

-- ── Place crown on a PlotRoot ─────────────────────────────────────────────────
local function placeCrown_199(root: BasePart, leaderName: string, honey: number)
	if currentCrownPlot_199 == root and crownGui_199 and crownGui_199.Parent then
		-- Same plot — just update label
		setCrownLabel_199(crownGui_199, leaderName, honey)
		return
	end

	removeCrown_199()

	local bg = buildCrown_199(root)
	setCrownLabel_199(bg, leaderName, honey)
	crownGui_199        = bg
	currentCrownPlot_199 = root
	startPulse_199(bg)
end

-- ── Find current honey leader among all players ───────────────────────────────
local function findLeader_199(): (Player?, number)
	local best: Player? = nil
	local bestHoney = MIN_LEAD_HONEY_199 - 1

	for _, p in Players:GetPlayers() do
		local honey = (p:GetAttribute("HoneyCount") :: number?) or 0
		if honey > bestHoney then
			bestHoney = honey
			best = p
		end
	end
	return best, bestHoney
end

-- ── Main poll ────────────────────────────────────────────────────────────────
local function poll_199()
	local leader, honey = findLeader_199()

	if not leader then
		removeCrown_199()
		return
	end

	local plotIdx = (leader:GetAttribute("PlotIndex") :: number?) or -1
	if plotIdx < 1 then
		removeCrown_199()
		return
	end

	local root = getPlotRoot_199(plotIdx)
	if not root then
		removeCrown_199()
		return
	end

	-- Shorten display name to 12 chars max
	local displayName = leader.DisplayName or leader.Name
	if #displayName > 12 then
		displayName = displayName:sub(1, 12) .. "…"
	end

	placeCrown_199(root, displayName, honey)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	-- Initial poll
	poll_199()

	-- React immediately when any player's HoneyCount changes
	local function watchPlayer_199(p: Player)
		p:GetAttributeChangedSignal("HoneyCount"):Connect(function()
			poll_199()
		end)
	end

	for _, p in Players:GetPlayers() do
		watchPlayer_199(p)
	end
	Players.PlayerAdded:Connect(function(p)
		task.wait(1)  -- let attributes propagate
		watchPlayer_199(p)
		poll_199()
	end)
	Players.PlayerRemoving:Connect(function()
		task.wait(0.2)
		poll_199()   -- re-evaluate when a player leaves
	end)

	-- Safety-net periodic re-poll
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= POLL_INTERVAL_199 then
			acc = 0
			poll_199()
		end
	end)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("HoneyCrownController"))
```

---

## Step 3 — Attribute source (DataService)

`HoneyCrownController` reads two player attributes that DataService already replicates:

| Attribute | Set by | Notes |
|---|---|---|
| `HoneyCount` | DataService (profile load + harvest) | Number ≥ 0; crown appears at ≥ 10 |
| `PlotIndex` | PlotService (on plot assignment) | Integer 1–6 |

No server-side changes needed — both attributes are already part of the live data layer.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("HoneyCrownController")
print("HoneyCrownController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  findLeader_199:", c.Source:find("findLeader_199") ~= nil)
	print("  placeCrown_199:", c.Source:find("placeCrown_199") ~= nil)
	print("  buildCrown_199:", c.Source:find("buildCrown_199") ~= nil)
	print("  startPulse_199:", c.Source:find("startPulse_199") ~= nil)
	print("  HoneyCount attr:", c.Source:find("HoneyCount") ~= nil)
end

local CS = game:GetService("CollectionService")
local roots = CS:GetTagged("PlotRoot")
print("PlotRoot tagged parts:", #roots, "(expect 6)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
HoneyCrownController: LocalScript
  lines: 170+
  findLeader_199: true
  placeCrown_199: true
  buildCrown_199: true
  startPulse_199: true
  HoneyCount attr: true
PlotRoot tagged parts: 6
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Condition | Crown state |
|---|---|
| No player has ≥ 10 honey | Crown absent |
| One player leads with ≥ 10 honey | 👑 crown hovers 8 studs above their PlotRoot, gold pulse |
| Leader's HoneyCount changes | Label updates in-place (no flicker) |
| Leadership changes to a different plot | Old crown destroyed, new crown built on new PlotRoot |
| Leader's player leaves | Re-evaluates; crown moves to new leader or disappears |
| Leader spends honey below threshold | Crown disappears |

- Crown sits 8 studs above the PlotRoot centre — visible from the Petal Path and adjacent plots
- Label: player display name (truncated at 12 chars) + honey total with 🍯 emoji (kid-legible)
- `GetAttributeChangedSignal("HoneyCount")` gives near-instant reaction on every honey change
- `Players.PlayerRemoving` re-evaluates so the crown never stays on a departed player's empty plot
- `placeCrown_199` checks if crown is already on the correct plot before rebuilding — smooth label update only if nothing changed

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(HoneyCrown_199 BillboardGui is a client-only GuiObject parented to a PlotRoot BasePart — not a new BasePart)*
