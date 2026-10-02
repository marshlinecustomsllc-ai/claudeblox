# Dispatch 191 — Queen Tier Coronation Ceremony
**File:** `cycle18_queen_coronation_dispatch.md`
**Cycle:** 18
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

When a player's queen advances to a new tier (T1→T2 through T4→T5) the existing `QueenController` fires a `QueenGrowth` RemoteEvent but the client only shows a brief toast. This dispatch adds a **Queen Tier Coronation Ceremony**: a 3-second fullscreen overlay that fades in with a gold crown burst, shows a large tier badge with kid-friendly headline and adult stat-delta line, then fades out. Animated "star" dots (Frame-based, no ParticleEmitter) rotate outward from the centre during the reveal. Entirely client-side — zero server writes, zero permanent parts.

---

## Step 1 — QueenCoronationController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `QueenCoronationController`.

Paste exactly:

```lua
--!strict
-- QueenCoronationController: fullscreen coronation ceremony on queen tier-up.
-- Listens to QueenGrowth RemoteEvent payload {tier: number, oldTier: number}.
-- Pure client-side UI — zero server writes, zero permanent parts.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local player  = Players.LocalPlayer
local gui191: PlayerGui = player:WaitForChild("PlayerGui") :: PlayerGui

-- ── Config ────────────────────────────────────────────────────────────────────
local CEREMONY_DURATION_191 = 3.2    -- total ceremony seconds
local FADE_IN_TIME_191      = 0.45   -- overlay fade in
local HOLD_TIME_191         = 1.8    -- hold at full opacity
local FADE_OUT_TIME_191     = 0.75   -- overlay fade out
local STAR_COUNT_191        = 14     -- animated star dots
local STAR_MAX_RADIUS_191   = 220    -- max udim pixels from centre
local STAR_SPIN_RATE_191    = 1.4    -- radians / second rotation

-- ── Tier data ─────────────────────────────────────────────────────────────────
type TierInfo = { name: string, icon: string, bg: Color3, accent: Color3, headline: string, adultLine: string }

local TIER_DATA_191: { [number]: TierInfo } = {
	[2] = {
		name      = "Apprentice Queen",
		icon      = "👑",
		bg        = Color3.fromRGB( 60,  35,  10),
		accent    = Color3.fromRGB(242, 168,  28),
		headline  = "Your queen is growing stronger!",
		adultLine = "Production: +20%  |  Brood warmth: +5%",
	},
	[3] = {
		name      = "Journeyman Queen",
		icon      = "✨👑",
		bg        = Color3.fromRGB( 40,  20,  70),
		accent    = Color3.fromRGB(180, 120, 255),
		headline  = "Your queen glows with royal power!",
		adultLine = "Production: +45%  |  Pop. cap: +30%",
	},
	[4] = {
		name      = "Master Queen",
		icon      = "🔥👑",
		bg        = Color3.fromRGB( 70,  15,   5),
		accent    = Color3.fromRGB(255, 100,  30),
		headline  = "The hive thrums with her majesty!",
		adultLine = "Production: +80%  |  Temp range: ×1.5",
	},
	[5] = {
		name      = "Sun Queen",
		icon      = "☀️👑",
		bg        = Color3.fromRGB( 80,  70,   0),
		accent    = Color3.fromRGB(255, 240,  60),
		headline  = "The legendary Sun Queen has awakened!",
		adultLine = "Max bonuses unlocked  |  Special lore revealed",
	},
}

-- ── Palette ───────────────────────────────────────────────────────────────────
local WAX_CREAM_191 = Color3.fromRGB(232, 212, 154)
local DARK_191      = Color3.fromRGB( 10,   5,   0)

-- ── Build ceremony overlay ────────────────────────────────────────────────────
local function buildOverlay_191(tier: number): ScreenGui?
	local info = TIER_DATA_191[tier]
	if not info then return nil end

	local sg = Instance.new("ScreenGui")
	sg.Name            = "QueenCeremony_191"
	sg.DisplayOrder    = 50          -- above HiveGui (30) and wasp ping (22)
	sg.ResetOnSpawn    = false
	sg.IgnoreGuiInset  = true
	sg.Parent          = gui191

	-- ── Dark fullscreen backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name                   = "Backdrop"
	backdrop.Size                   = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3       = info.bg
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel        = 0
	backdrop.ZIndex                 = 1
	backdrop.Parent                 = sg

	-- Radial gradient vignette overlay (dark edges)
	local vigGrad = Instance.new("UIGradient")
	vigGrad.Color    = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   info.bg),
		ColorSequenceKeypoint.new(0.6, info.bg),
		ColorSequenceKeypoint.new(1,   DARK_191),
	})
	vigGrad.Rotation = 90
	vigGrad.Parent   = backdrop

	-- ── Centre card
	local card = Instance.new("Frame")
	card.Name                   = "Card"
	card.Size                   = UDim2.new(0, 360, 0, 160)
	card.AnchorPoint            = Vector2.new(0.5, 0.5)
	card.Position               = UDim2.new(0.5, 0, 0.5, 0)
	card.BackgroundColor3       = DARK_191
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel        = 0
	card.ZIndex                 = 3
	card.Parent                 = backdrop

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 16)
	cardCorner.Parent       = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color     = info.accent
	cardStroke.Thickness = 2.5
	cardStroke.Parent    = card

	-- Tier icon (large)
	local iconLbl = Instance.new("TextLabel")
	iconLbl.Name               = "TierIcon"
	iconLbl.Size               = UDim2.new(1, 0, 0, 52)
	iconLbl.Position           = UDim2.new(0, 0, 0, 10)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text               = info.icon
	iconLbl.TextSize           = 38
	iconLbl.Font               = Enum.Font.GothamBold
	iconLbl.TextColor3         = info.accent
	iconLbl.TextXAlignment     = Enum.TextXAlignment.Center
	iconLbl.ZIndex             = 4
	iconLbl.Parent             = card

	-- Tier name
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name               = "TierName"
	nameLbl.Size               = UDim2.new(1, -20, 0, 26)
	nameLbl.Position           = UDim2.new(0, 10, 0, 62)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text               = info.name
	nameLbl.TextSize           = 18
	nameLbl.Font               = Enum.Font.GothamBold
	nameLbl.TextColor3         = info.accent
	nameLbl.TextXAlignment     = Enum.TextXAlignment.Center
	nameLbl.ZIndex             = 4
	nameLbl.Parent             = card

	-- Headline (kid-friendly)
	local headLbl = Instance.new("TextLabel")
	headLbl.Name               = "Headline"
	headLbl.Size               = UDim2.new(1, -20, 0, 30)
	headLbl.Position           = UDim2.new(0, 10, 0, 90)
	headLbl.BackgroundTransparency = 1
	headLbl.Text               = info.headline
	headLbl.TextSize           = 14
	headLbl.Font               = Enum.Font.Gotham
	headLbl.TextColor3         = WAX_CREAM_191
	headLbl.TextWrapped        = true
	headLbl.TextXAlignment     = Enum.TextXAlignment.Center
	headLbl.ZIndex             = 4
	headLbl.Parent             = card

	-- Adult detail line
	local adultLbl = Instance.new("TextLabel")
	adultLbl.Name               = "AdultDetail"
	adultLbl.Size               = UDim2.new(1, -20, 0, 20)
	adultLbl.Position           = UDim2.new(0, 10, 0, 132)
	adultLbl.BackgroundTransparency = 1
	adultLbl.Text               = info.adultLine
	adultLbl.TextSize           = 11
	adultLbl.Font               = Enum.Font.Gotham
	adultLbl.TextColor3         = Color3.fromRGB(180, 160, 100)
	adultLbl.TextXAlignment     = Enum.TextXAlignment.Center
	adultLbl.ZIndex             = 4
	adultLbl.Parent             = card

	-- ── Animated star dots (pure Frame, no ParticleEmitter)
	local starsFolder = Instance.new("Folder")
	starsFolder.Name   = "Stars"
	starsFolder.Parent = backdrop

	local starFrames: { Frame } = {}
	for i = 1, STAR_COUNT_191 do
		local sf = Instance.new("Frame")
		sf.Name                   = "Star_" .. i
		sf.Size                   = UDim2.new(0, 8, 0, 8)
		sf.AnchorPoint            = Vector2.new(0.5, 0.5)
		sf.Position               = UDim2.new(0.5, 0, 0.5, 0)  -- start at centre
		sf.BackgroundColor3       = info.accent
		sf.BackgroundTransparency = 0.3
		sf.BorderSizePixel        = 0
		sf.ZIndex                 = 2
		sf.Parent                 = backdrop

		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(1, 0)
		sc.Parent       = sf

		table.insert(starFrames, sf)
	end

	return sg
end

-- ── Run ceremony ──────────────────────────────────────────────────────────────
local ceremonyActive_191 = false

local function runCeremony_191(tier: number)
	if ceremonyActive_191 then return end
	ceremonyActive_191 = true

	local sg = buildOverlay_191(tier)
	if not sg then ceremonyActive_191 = false; return end

	local backdrop = sg:FindFirstChild("Backdrop") :: Frame
	local card     = backdrop:FindFirstChild("Card") :: Frame
	local starFrames: { Frame } = {}
	for _, sf in backdrop:GetChildren() do
		if sf:IsA("Frame") and sf.Name:sub(1, 5) == "Star_" then
			table.insert(starFrames, sf :: Frame)
		end
	end

	-- Animate stars outward from centre with staggered offsets
	local startAngles: { number } = {}
	for i, _ in starFrames do
		startAngles[i] = (i / STAR_COUNT_191) * math.pi * 2
	end

	-- Fade in backdrop
	TweenService:Create(backdrop, TweenInfo.new(FADE_IN_TIME_191, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 0.08,
	}):Play()

	-- Scale-bounce card in
	card.Size         = UDim2.new(0, 200, 0, 90)
	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(FADE_IN_TIME_191, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size                    = UDim2.new(0, 360, 0, 160),
		BackgroundTransparency  = 0.15,
	}):Play()

	-- Expand and spin stars during ceremony
	local elapsed = 0
	local spinConn: RBXScriptConnection
	spinConn = RunService.Heartbeat:Connect(function(dt)
		elapsed = elapsed + dt
		local progress = math.min(elapsed / CEREMONY_DURATION_191, 1)
		-- Stars expand then contract following sine arc
		local radiusScale = math.sin(progress * math.pi)   -- 0→1→0 arc
		local radius = radiusScale * STAR_MAX_RADIUS_191

		for i, sf in starFrames do
			local angle = startAngles[i] + elapsed * STAR_SPIN_RATE_191
			local ox = math.cos(angle) * radius
			local oy = math.sin(angle) * radius
			sf.Position           = UDim2.new(0.5, math.round(ox), 0.5, math.round(oy))
			sf.BackgroundTransparency = 0.1 + (1 - radiusScale) * 0.85
		end

		if progress >= 1 then
			spinConn:Disconnect()
		end
	end)

	-- Hold then fade out
	task.wait(FADE_IN_TIME_191 + HOLD_TIME_191)

	TweenService:Create(backdrop, TweenInfo.new(FADE_OUT_TIME_191, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(card, TweenInfo.new(FADE_OUT_TIME_191, Enum.EasingStyle.Sine), {
		BackgroundTransparency = 1,
		Size                   = UDim2.new(0, 320, 0, 100),
	}):Play()

	task.wait(FADE_OUT_TIME_191)
	spinConn:Disconnect()
	sg:Destroy()
	ceremonyActive_191 = false
end

-- ── Listen for QueenGrowth RemoteEvent ───────────────────────────────────────
local function waitForRemote_191()
	local RS = game:GetService("ReplicatedStorage")
	local remotes = RS:WaitForChild("Remotes", 15)
	if not remotes then return end
	local ev = remotes:WaitForChild("QueenGrowth", 15) :: RemoteEvent?
	if not ev then return end

	ev.OnClientEvent:Connect(function(payload: { tier: number, oldTier: number }?)
		if typeof(payload) == "table" and type(payload.tier) == "number" then
			task.spawn(runCeremony_191, payload.tier)
		end
	end)
end

-- 2-second init delay to let PlayerGui and Remotes load
task.delay(2, waitForRemote_191)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("QueenCoronationController"))
```

---

## Step 3 — QueenController emit (if not already present)

Open **StarterPlayerScripts → QueenController** and find where it handles a queen tier-up. Confirm it fires `QueenGrowth` with a table payload:

```lua
-- Inside QueenController, after detecting a tier advance:
local ev = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("QueenGrowth")
if ev then
	ev:FireServer()   -- server fires back to client — or use the existing pattern
end
```

If the existing `QueenGrowth` event is already fired **by the server** (in QueenService) on tier advance, no change is needed here — `QueenCoronationController` listens on `.OnClientEvent` which is the server-to-client direction.

If `QueenGrowth` currently carries only a tier number (not a table), update the server-side FireClient call to:

```lua
QueenGrowth:FireClient(player, { tier = newTier, oldTier = oldTier })
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("QueenCoronationController")
print("QueenCoronationController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  runCeremony_191:", c.Source:find("runCeremony_191") ~= nil)
	print("  buildOverlay_191:", c.Source:find("buildOverlay_191") ~= nil)
	print("  TIER_DATA_191:", c.Source:find("TIER_DATA_191") ~= nil)
	print("  star spin:", c.Source:find("STAR_SPIN_RATE_191") ~= nil)
end

-- Check QueenGrowth RemoteEvent exists
local ev = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
ev = ev and ev:FindFirstChild("QueenGrowth")
print("QueenGrowth RemoteEvent:", ev and ev.ClassName or "MISSING (add if absent)")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
QueenCoronationController: LocalScript
  lines: 200+
  runCeremony_191: true
  buildOverlay_191: true
  TIER_DATA_191: true
  star spin: true
QueenGrowth RemoteEvent: RemoteEvent
Total parts: 4204  (expect 4204)
```

### Manual smoke-test

In Play mode, run in the Command Bar to simulate a tier-up event:

```lua
local ev = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("QueenGrowth")
if ev then
	ev:FireAllClients({ tier = 3, oldTier = 2 })
	print("Fired tier-3 coronation")
else
	print("QueenGrowth remote not found")
end
```

You should see a ~3-second fullscreen ceremony: dark backdrop fades in, centre card scales in with the "✨👑 Journeyman Queen" header, 14 star dots arc outward and rotate, then everything fades out cleanly. Test tier 5 for the gold Sun Queen ceremony.

---

## Behaviour summary

| Tier advance | Background | Accent | Crown icon | Kid headline | Adult line |
|---|---|---|---|---|---|
| T1→T2 | Dark amber | Honey Gold | 👑 | "Your queen is growing stronger!" | Production +20%, Brood warmth +5% |
| T2→T3 | Deep purple | Lavender | ✨👑 | "Your queen glows with royal power!" | Production +45%, Pop. cap +30% |
| T3→T4 | Dark ember | Ember Orange | 🔥👑 | "The hive thrums with her majesty!" | Production +80%, Temp range ×1.5 |
| T4→T5 | Deep gold | Bright Gold | ☀️👑 | "The legendary Sun Queen has awakened!" | Max bonuses unlocked |

- Ceremony duration: 3.2 s (0.45 fade-in + 1.8 hold + 0.75 fade-out)
- 14 star dots arc from centre to 220 px radius and return, rotating at 1.4 rad/s
- `ceremonyActive_191` flag prevents stacking if two rapid tier-ups arrive
- Card scale-bounces in (EasingStyle.Back) for a satisfying pop
- All frames destroyed after ceremony — no lingering Instances
- `DisplayOrder = 50` — appears over all other game UI

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(All overlay Frames are GuiObjects inside PlayerGui — not BaseParts, zero part budget impact)*
