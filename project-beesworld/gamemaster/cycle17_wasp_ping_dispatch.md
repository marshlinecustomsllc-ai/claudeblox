# Dispatch 184 — Wasp Scout Directional Ping
**File:** `cycle17_wasp_ping_dispatch.md`
**Cycle:** 17
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When a wasp enters the player's plot radius (the `WaspAlert` RemoteEvent fires), the current WaspAlertController shows a toast but gives no spatial information. Players don't know which direction to face for the swat mechanic. This dispatch adds a **Wasp Scout Directional Ping**: a pulsing orange ⚠️ dot that orbits the edge of the screen on the side the wasp is approaching from, then auto-dismisses after 6 seconds. If the wasp is destroyed before then, a `WaspDefeated` event dismisses it early. Kids see "⚠️ Bug incoming!"; adults read the dot position to orient themselves.

Entirely client-side. Zero new permanent parts. Uses `WorldToScreenPoint` on the wasp's last known position to place the edge dot each frame.

---

## Step 1 — WaspPingController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `WaspPingController`.

Paste exactly:

```lua
--!strict
-- WaspPingController: directional edge-ping when a WaspScout enters the player's plot.
-- Listens to WaspAlert RemoteEvent (payload: waspPart: BasePart? or nil, message: string).
-- Uses WorldToScreenPoint to place the ping dot at the screen edge toward the wasp.
-- Dismissed by WaspDefeated RemoteEvent or 6s timeout.
-- Entirely client-side — zero server code.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local PING_DURATION_184  = 6      -- seconds before auto-dismiss
local PING_MARGIN_184    = 30     -- px inset from screen edge
local PING_SIZE_184      = 32     -- px diameter of ping dot
local PULSE_PERIOD_184   = 0.5    -- seconds per pulse cycle

-- ── Palette ───────────────────────────────────────────────────────────────────
local WASP_ORANGE_184 = Color3.fromRGB(240, 130,  20)
local WASP_YELLOW_184 = Color3.fromRGB(255, 220,  50)
local DARK_BG_184     = Color3.fromRGB( 30,  18,   8)
local WAX_CREAM_184   = Color3.fromRGB(232, 212, 154)

-- ── Build ping dot ────────────────────────────────────────────────────────────
local pingGui_184: ScreenGui? = nil
local pingDot_184: Frame? = nil
local pingLabel_184: TextLabel? = nil
local toastLabel_184: TextLabel? = nil

local function buildPing_184()
	local sg = Instance.new("ScreenGui")
	sg.Name           = "WaspPingGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 33
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui
	pingGui_184 = sg

	-- Edge ping dot
	local dot = Instance.new("Frame")
	dot.Name              = "WaspPingDot"
	dot.Size              = UDim2.new(0, PING_SIZE_184, 0, PING_SIZE_184)
	dot.Position          = UDim2.new(0.5, -PING_SIZE_184/2, 0, PING_MARGIN_184)
	dot.BackgroundColor3  = WASP_ORANGE_184
	dot.BorderSizePixel   = 0
	dot.ZIndex            = 45
	dot.Visible           = false
	dot.Parent            = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dot

	local lbl = Instance.new("TextLabel")
	lbl.Name               = "DotIcon"
	lbl.Size               = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "⚠"
	lbl.TextSize           = 16
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = DARK_BG_184
	lbl.TextXAlignment     = Enum.TextXAlignment.Center
	lbl.TextYAlignment     = Enum.TextYAlignment.Center
	lbl.ZIndex             = 46
	lbl.Parent             = dot
	pingLabel_184 = lbl
	pingDot_184 = dot

	-- Toast line above the dot
	local toast = Instance.new("TextLabel")
	toast.Name               = "WaspToastLine"
	toast.Size               = UDim2.new(0, 200, 0, 18)
	toast.Position           = UDim2.new(0.5, -100, 0, PING_MARGIN_184 + PING_SIZE_184 + 2)
	toast.BackgroundTransparency = 1
	toast.Text               = "⚠️ Bug incoming!"
	toast.TextSize           = 11
	toast.Font               = Enum.Font.GothamBold
	toast.TextColor3         = WASP_YELLOW_184
	toast.TextXAlignment     = Enum.TextXAlignment.Center
	toast.ZIndex             = 46
	toast.Visible            = false
	toast.Parent             = sg
	toastLabel_184 = toast
end

-- ── Project world point to screen edge position ───────────────────────────────
local function screenEdgePos_184(worldPos: Vector3): UDim2
	local camera    = workspace.CurrentCamera
	local vp        = camera.ViewportSize
	local scPos, onScreen = camera:WorldToScreenPoint(worldPos)

	local cx = vp.X * 0.5
	local cy = vp.Y * 0.5
	local dx = scPos.X - cx
	local dy = scPos.Y - cy

	if onScreen then
		-- Wasp is on-screen — clamp to its actual screen position
		local x = math.max(PING_MARGIN_184, math.min(vp.X - PING_MARGIN_184 - PING_SIZE_184, scPos.X - PING_SIZE_184/2))
		local y = math.max(PING_MARGIN_184, math.min(vp.Y - PING_MARGIN_184 - PING_SIZE_184, scPos.Y - PING_SIZE_184/2))
		return UDim2.new(0, x, 0, y)
	else
		-- Off-screen — project to screen edge
		if dx == 0 and dy == 0 then
			return UDim2.new(0.5, -PING_SIZE_184/2, 0, PING_MARGIN_184)
		end
		local scaleTo = math.min(
			(cx - PING_MARGIN_184 - PING_SIZE_184/2) / math.abs(dx),
			(cy - PING_MARGIN_184 - PING_SIZE_184/2) / math.abs(dy)
		)
		local ex = cx + dx * scaleTo - PING_SIZE_184/2
		local ey = cy + dy * scaleTo - PING_SIZE_184/2
		ex = math.max(PING_MARGIN_184, math.min(vp.X - PING_MARGIN_184 - PING_SIZE_184, ex))
		ey = math.max(PING_MARGIN_184, math.min(vp.Y - PING_MARGIN_184 - PING_SIZE_184, ey))
		return UDim2.new(0, ex, 0, ey)
	end
end

-- ── Ping state ────────────────────────────────────────────────────────────────
local pingActive_184   = false
local currentWasp_184: BasePart? = nil
local trackConn_184: RBXScriptConnection? = nil
local pulseConn_184: RBXScriptConnection? = nil
local pulseT_184       = 0

local function dismissPing_184()
	if not pingActive_184 then return end
	pingActive_184 = false
	currentWasp_184 = nil
	if trackConn_184 then trackConn_184:Disconnect(); trackConn_184 = nil end
	if pulseConn_184 then pulseConn_184:Disconnect(); pulseConn_184 = nil end

	local dot   = pingDot_184
	local toast = toastLabel_184
	if dot then
		TweenService:Create(dot, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		task.delay(0.25, function() if dot then dot.Visible = false end end)
	end
	if toast then
		TweenService:Create(toast, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		task.delay(0.25, function() if toast then toast.Visible = false end end)
	end
end

local function showPing_184(waspPart: BasePart?)
	if pingActive_184 then return end
	if not pingDot_184 then buildPing_184() end

	pingActive_184   = true
	currentWasp_184  = waspPart
	pulseT_184       = 0

	local dot   = pingDot_184
	local toast = toastLabel_184
	if not dot or not toast then return end

	dot.BackgroundTransparency = 0
	dot.Visible  = true
	toast.TextTransparency = 0
	toast.Visible = true

	-- If wasp part known, track its position each frame
	if waspPart then
		trackConn_184 = RunService.Heartbeat:Connect(function()
			if not waspPart or not waspPart.Parent then
				dismissPing_184()
				return
			end
			dot.Position = screenEdgePos_184(waspPart.Position)
		end)
	else
		-- No position — just centre-top static placement
		dot.Position = UDim2.new(0.5, -PING_SIZE_184/2, 0, PING_MARGIN_184)
	end

	-- Pulse colour ORANGE↔YELLOW
	pulseConn_184 = RunService.Heartbeat:Connect(function(dt)
		pulseT_184 = pulseT_184 + dt
		local phase = math.sin(pulseT_184 / PULSE_PERIOD_184 * math.pi * 2) * 0.5 + 0.5
		if dot then
			dot.BackgroundColor3 = WASP_ORANGE_184:Lerp(WASP_YELLOW_184, phase)
		end
	end)

	-- Auto-dismiss after PING_DURATION_184
	task.delay(PING_DURATION_184, function()
		dismissPing_184()
	end)
end

-- ── Listen to WaspAlert ───────────────────────────────────────────────────────
local function connectRemotes_184()
	local waspAlert = Remotes:FindFirstChild("WaspAlert") :: RemoteEvent?
	if waspAlert then
		waspAlert.OnClientEvent:Connect(function(waspPart: BasePart?, _msg: string?)
			showPing_184(waspPart)
		end)
	end

	local waspDefeated = Remotes:FindFirstChild("WaspDefeated") :: RemoteEvent?
	if waspDefeated then
		waspDefeated.OnClientEvent:Connect(function()
			dismissPing_184()
		end)
	end
end

task.delay(1, function()
	buildPing_184()
	connectRemotes_184()
end)

-- Retry loop for late-arriving remotes
task.spawn(function()
	task.wait(10)
	connectRemotes_184()
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("WaspPingController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("WaspPingController")
print("WaspPingController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  showPing_184:", c.Source:find("showPing_184") ~= nil)
	print("  screenEdgePos_184:", c.Source:find("screenEdgePos_184") ~= nil)
	print("  WaspAlert listener:", c.Source:find("WaspAlert") ~= nil)
	print("  WaspDefeated listener:", c.Source:find("WaspDefeated") ~= nil)
end

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
WaspPingController: LocalScript
  lines: 190+
  showPing_184: true
  screenEdgePos_184: true
  WaspAlert listener: true
  WaspDefeated listener: true
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| State | Ping dot |
|-------|----------|
| WaspAlert fires with waspPart | Dot tracks wasp at screen edge; pulses ORANGE↔YELLOW |
| WaspAlert fires without waspPart | Dot centres at top of screen; same pulse |
| Wasp on-screen | Dot moves to actual screen position (still within margin) |
| Wasp off-screen | Dot hugs the edge in the direction of the wasp |
| WaspDefeated fires | Dot fades out immediately |
| 6s elapsed | Dot fades out automatically |
| Second WaspAlert while active | Ignored (pingActive lock) |

**Part budget: +0 permanent → 4,204 / 5,000**
