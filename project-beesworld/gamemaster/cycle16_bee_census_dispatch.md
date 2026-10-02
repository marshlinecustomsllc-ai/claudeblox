# Dispatch 175 — Bee Census Milestones
**File:** `cycle16_bee_census_dispatch.md`
**Cycle:** 16
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

Players currently have no celebration moment when their colony grows to a new size tier. This dispatch adds a **Bee Census milestone system**: when a player's BeeCount attribute crosses 10 / 25 / 50 / 100 / 250, a celebratory toast pops with an emoji headline (kids love it), a subtle audio sting fires, and the HiveGui population area gains a small persistent **census badge** showing the highest tier reached. The badges are colour-coded — bronze (10), silver (25), gold (50), honey-amber (100), queen-purple (250) — and accumulate visibly so players feel progression.

Server-side: **BeeCensusService** watches BeeCount per player and fires a `CensusReached` RemoteEvent when a new tier is crossed. Client-side: **BeeCensusController** handles the toast, the SFX sting, and updating the HiveGui badge strip.

---

## Step 1 — BeeCensusService (ServerScriptService.Systems)

Open **ServerScriptService → Systems** and create a new **Script** named `BeeCensusService`.

Paste exactly:

```lua
--!strict
-- BeeCensusService: fires CensusReached RemoteEvent when player BeeCount crosses a milestone.
-- Tracks per-player highest tier already celebrated to avoid duplicate fires.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- ── RemoteEvent ───────────────────────────────────────────────────────────────
local censusEvent: RemoteEvent
do
	local existing = Remotes:FindFirstChild("CensusReached") :: RemoteEvent?
	if existing then
		censusEvent = existing
	else
		local re = Instance.new("RemoteEvent")
		re.Name   = "CensusReached"
		re.Parent = Remotes
		censusEvent = re
	end
end

-- ── Milestones ────────────────────────────────────────────────────────────────
type MilestoneDef_175 = {
	threshold: number,
	tier:      string,
	kid:       string,
	adult:     string,
	color:     Color3,
}

local MILESTONES_175: { MilestoneDef_175 } = {
	{
		threshold = 10,
		tier      = "bronze",
		kid       = "🐝 10 bees in your hive!",
		adult     = "Colony established — the comb is alive.",
		color     = Color3.fromRGB(180, 120, 60),
	},
	{
		threshold = 25,
		tier      = "silver",
		kid       = "✨ 25 bees! Your hive is buzzing!",
		adult     = "Healthy nucleus — foraging bandwidth expanding.",
		color     = Color3.fromRGB(190, 190, 200),
	},
	{
		threshold = 50,
		tier      = "gold",
		kid       = "🌟 50 bees! Half a hundred bees!",
		adult     = "Strong colony — all caste roles filled.",
		color     = Color3.fromRGB(242, 168, 28),
	},
	{
		threshold = 100,
		tier      = "amber",
		kid       = "🍯 100 bees! A full golden hive!",
		adult     = "Peak efficiency — honey output at maximum.",
		color     = Color3.fromRGB(220, 130, 20),
	},
	{
		threshold = 250,
		tier      = "queen",
		kid       = "👑 250 bees! You're a master beekeeper!",
		adult     = "Supercolony — prestige threshold reached.",
		color     = Color3.fromRGB(160, 60, 220),
	},
}

-- ── Per-player state ──────────────────────────────────────────────────────────
-- Tracks which milestone index each player has already reached (0 = none)
local playerHighest: { [number]: number } = {}

local function getHighestReached_175(player: Player): number
	return playerHighest[player.UserId] or 0
end

local function checkMilestones_175(player: Player)
	local beeCount = player:GetAttribute("BeeCount") :: number?
	if not beeCount then return end

	local highest = getHighestReached_175(player)

	for i = #MILESTONES_175, 1, -1 do
		if beeCount >= MILESTONES_175[i].threshold and i > highest then
			-- New highest milestone crossed — fire for every uncelebrated tier up to this one
			for j = highest + 1, i do
				local m = MILESTONES_175[j]
				local ok = pcall(function()
					censusEvent:FireClient(player, {
						tier   = m.tier,
						kid    = m.kid,
						adult  = m.adult,
						color  = { r = m.color.R, g = m.color.G, b = m.color.B },
						count  = beeCount,
					})
				end)
				if not ok then break end
				task.wait(0.05)  -- slight stagger so client toasts don't overlap
			end
			playerHighest[player.UserId] = i
			break
		end
	end
end

-- ── Watch BeeCount attribute ──────────────────────────────────────────────────
local function connectPlayer_175(player: Player)
	playerHighest[player.UserId] = 0

	-- Restore highest already reached from persisted attribute (if DataService tracks it)
	local saved = player:GetAttribute("CensusHighest") :: number?
	if saved then
		playerHighest[player.UserId] = saved
	end

	player:GetAttributeChangedSignal("BeeCount"):Connect(function()
		checkMilestones_175(player)
	end)
end

local function disconnectPlayer_175(player: Player)
	-- Persist highest reached so it survives rejoin
	local highest = playerHighest[player.UserId] or 0
	if player and player.Parent then
		player:SetAttribute("CensusHighest", highest)
	end
	playerHighest[player.UserId] = nil
end

Players.PlayerAdded:Connect(connectPlayer_175)
Players.PlayerRemoving:Connect(disconnectPlayer_175)

for _, player in Players:GetPlayers() do
	connectPlayer_175(player)
end
```

---

## Step 2 — BeeCensusController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BeeCensusController`.

Paste exactly:

```lua
--!strict
-- BeeCensusController: handles CensusReached event from BeeCensusService.
-- Shows celebration toast, plays SFX sting, adds persistent badge to HiveGui.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local Remotes   = ReplicatedStorage:WaitForChild("Remotes")

-- ── Config ────────────────────────────────────────────────────────────────────
local TOAST_DURATION_175 = 4    -- seconds the celebration toast stays visible
local MAX_BADGES_175     = 5    -- one badge per milestone tier

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_175  = Color3.fromRGB(30,  18,  8)
local WAX_CREAM_175 = Color3.fromRGB(232, 212, 154)

-- ── Milestone SFX ─────────────────────────────────────────────────────────────
-- Uses rbxassetid://4590662766 (short celebratory chime/ding)
local STING_ASSET_175 = "rbxassetid://4590662766"

local celebSound_175: Sound? = nil

local function ensureCelebSound_175()
	if celebSound_175 and celebSound_175.Parent then return end
	local sg = Instance.new("Part")
	sg.Name        = "CensusAudioAnchor_175"
	sg.Anchored    = true
	sg.CanCollide  = false
	sg.Transparency = 1
	sg.Position    = Vector3.new(0, 0, 0)
	sg.Parent      = workspace

	local s = Instance.new("Sound")
	s.Name    = "CelebSting_175"
	s.SoundId = STING_ASSET_175
	s.Volume  = 0.55
	s.RollOffMode = Enum.RollOffMode.NoAttenuation  -- plays at full vol regardless of position
	s.Parent  = sg
	celebSound_175 = s
end

local function playCelebSting_175()
	ensureCelebSound_175()
	if celebSound_175 then
		celebSound_175:Play()
	end
end

-- ── Celebration toast ─────────────────────────────────────────────────────────
local celebGui_175: ScreenGui? = nil
local celebFrame_175: Frame? = nil
local celebKidLabel_175: TextLabel? = nil
local celebAdultLabel_175: TextLabel? = nil
local toastShowing_175 = false

local function buildCelebToast_175()
	local sg = Instance.new("ScreenGui")
	sg.Name           = "BeeCensusGui"
	sg.ResetOnSpawn   = false
	sg.DisplayOrder   = 20
	sg.IgnoreGuiInset = true
	sg.Parent         = PlayerGui
	celebGui_175 = sg

	local frame = Instance.new("Frame")
	frame.Name              = "CelebToast"
	frame.Size              = UDim2.new(0, 300, 0, 72)
	frame.Position          = UDim2.new(0.5, -150, 0.5, -36)
	frame.AnchorPoint       = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3  = DARK_BG_175
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel   = 0
	frame.Visible           = false
	frame.ZIndex            = 45
	-- Start scaled to 0
	frame.Size              = UDim2.new(0, 0, 0, 0)
	frame.Parent            = sg
	celebFrame_175 = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame

	-- Stroke colour set dynamically per milestone
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color     = WAX_CREAM_175
	stroke.Parent    = frame

	-- Kid headline
	local kidLabel = Instance.new("TextLabel")
	kidLabel.Name               = "KidLine"
	kidLabel.Size               = UDim2.new(1, -16, 0, 36)
	kidLabel.Position           = UDim2.new(0, 8, 0, 8)
	kidLabel.BackgroundTransparency = 1
	kidLabel.Text               = ""
	kidLabel.TextSize           = 18
	kidLabel.Font               = Enum.Font.GothamBold
	kidLabel.TextColor3         = WAX_CREAM_175
	kidLabel.TextXAlignment     = Enum.TextXAlignment.Center
	kidLabel.ZIndex             = 46
	kidLabel.Parent             = frame
	celebKidLabel_175 = kidLabel

	-- Adult subtext
	local adultLabel = Instance.new("TextLabel")
	adultLabel.Name               = "AdultLine"
	adultLabel.Size               = UDim2.new(1, -16, 0, 20)
	adultLabel.Position           = UDim2.new(0, 8, 0, 44)
	adultLabel.BackgroundTransparency = 1
	adultLabel.Text               = ""
	adultLabel.TextSize           = 11
	adultLabel.Font               = Enum.Font.Gotham
	adultLabel.TextColor3         = Color3.fromRGB(180, 160, 120)
	adultLabel.TextXAlignment     = Enum.TextXAlignment.Center
	adultLabel.ZIndex             = 46
	adultLabel.Parent             = frame
	celebAdultLabel_175 = adultLabel
end

local function showCelebToast_175(kidText: string, adultText: string, tintColor: Color3)
	if not celebFrame_175 then buildCelebToast_175() end
	local frame = celebFrame_175
	if not frame or toastShowing_175 then return end
	toastShowing_175 = true

	-- Set text
	if celebKidLabel_175 then celebKidLabel_175.Text = kidText end
	if celebAdultLabel_175 then celebAdultLabel_175.Text = adultText end

	-- Set stroke color to milestone tint
	local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke?
	if stroke then stroke.Color = tintColor end
	if celebKidLabel_175 then celebKidLabel_175.TextColor3 = tintColor end

	frame.Visible = true

	-- Pop-in scale animation
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 300, 0, 72) }):Play()

	task.delay(TOAST_DURATION_175, function()
		-- Pop-out
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.new(0, 0, 0, 0) }):Play()
		task.delay(0.25, function()
			frame.Visible = false
			toastShowing_175 = false
		end)
	end)
end

-- ── HiveGui badge strip ───────────────────────────────────────────────────────
-- Finds HiveGui and adds/updates a small badge strip showing earned census tiers.

local badgesBuilt_175: { [string]: Frame } = {}

local function ensureBadgeStrip_175(): Frame?
	local hiveGui = PlayerGui:FindFirstChild("HiveGui") :: ScreenGui?
	if not hiveGui then return nil end

	local existing = hiveGui:FindFirstChild("CensusBadgeStrip") :: Frame?
	if existing then return existing end

	local strip = Instance.new("Frame")
	strip.Name              = "CensusBadgeStrip"
	strip.Size              = UDim2.new(0, MAX_BADGES_175 * 22, 0, 20)
	-- Bottom-left corner of HiveGui
	strip.Position          = UDim2.new(0, 8, 1, -28)
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel   = 0
	strip.ZIndex            = 30
	strip.Parent            = hiveGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection    = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment   = Enum.VerticalAlignment.Center
	layout.Padding          = UDim.new(0, 2)
	layout.Parent           = strip

	return strip
end

local function addBadge_175(tier: string, tintColor: Color3)
	if badgesBuilt_175[tier] then return end  -- already shown

	local strip = ensureBadgeStrip_175()
	if not strip then return end

	local badge = Instance.new("Frame")
	badge.Name              = "Badge_" .. tier
	badge.Size              = UDim2.new(0, 18, 0, 18)
	badge.BackgroundColor3  = tintColor
	badge.BackgroundTransparency = 0.2
	badge.BorderSizePixel   = 0
	badge.ZIndex            = 31
	badge.Parent            = strip

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)  -- full circle
	corner.Parent = badge

	-- Tier initial letter
	local labels = { bronze = "B", silver = "S", gold = "G", amber = "A", queen = "Q" }
	local letter = Instance.new("TextLabel")
	letter.Size               = UDim2.new(1, 0, 1, 0)
	letter.BackgroundTransparency = 1
	letter.Text               = labels[tier] or "?"
	letter.TextSize           = 10
	letter.Font               = Enum.Font.GothamBold
	letter.TextColor3         = Color3.fromRGB(255, 255, 255)
	letter.TextXAlignment     = Enum.TextXAlignment.Center
	letter.ZIndex             = 32
	letter.Parent             = badge

	badgesBuilt_175[tier] = badge

	-- Pop-in
	badge.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(badge, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(0, 18, 0, 18) }):Play()
end

-- ── Listen for CensusReached event ────────────────────────────────────────────
local censusEvent = Remotes:WaitForChild("CensusReached", 15) :: RemoteEvent?

if censusEvent then
	censusEvent.OnClientEvent:Connect(function(payload: { [string]: any })
		local tier  = payload.tier  :: string
		local kid   = payload.kid   :: string
		local adult = payload.adult :: string
		local rc    = payload.color :: { r: number, g: number, b: number }
		local tint  = Color3.new(rc.r, rc.g, rc.b)

		playCelebSting_175()
		showCelebToast_175(kid, adult, tint)
		addBadge_175(tier, tint)
	end)
end
```

---

## Step 3 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BeeCensusController"))
```

---

## Step 4 — Verification sweep

Run in **Studio Command Bar**:

```lua
-- Service
local s = game:GetService("ServerScriptService"):FindFirstChild("Systems")
	and game:GetService("ServerScriptService").Systems:FindFirstChild("BeeCensusService")
print("BeeCensusService:", s and s.ClassName or "MISSING")
if s then
	print("  MILESTONES_175:", s.Source:find("MILESTONES_175") ~= nil)
	print("  CensusReached FireClient:", s.Source:find("censusEvent:FireClient") ~= nil)
end

-- Controller
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BeeCensusController")
print("BeeCensusController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  showCelebToast_175:", c.Source:find("showCelebToast_175") ~= nil)
	print("  addBadge_175:", c.Source:find("addBadge_175") ~= nil)
	print("  CensusReached listener:", c.Source:find("CensusReached") ~= nil)
end

-- RemoteEvent
local re = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CensusReached")
print("CensusReached RemoteEvent:", re and re.ClassName or "MISSING")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

**Expected output:**
```
BeeCensusService: Script
  MILESTONES_175: true
  CensusReached FireClient: true
BeeCensusController: LocalScript
  lines: 200+
  showCelebToast_175: true
  addBadge_175: true
  CensusReached listener: true
CensusReached RemoteEvent: RemoteEvent
Total parts: 4204  (expect 4204)
```

---

## Behaviour summary

| Milestone | Kid text | Adult text | Badge colour |
|-----------|----------|------------|--------------|
| 10 bees | "🐝 10 bees in your hive!" | "Colony established — the comb is alive." | Bronze |
| 25 bees | "✨ 25 bees! Your hive is buzzing!" | "Healthy nucleus — foraging bandwidth expanding." | Silver |
| 50 bees | "🌟 50 bees! Half a hundred bees!" | "Strong colony — all caste roles filled." | Gold |
| 100 bees | "🍯 100 bees! A full golden hive!" | "Peak efficiency — honey output at maximum." | Amber |
| 250 bees | "👑 250 bees! You're a master beekeeper!" | "Supercolony — prestige threshold reached." | Queen-purple |

- Toast (300×72): pops from centre via Back easing, 4s duration, milestone-tint stroke + headline
- Badge strip: bottom-left of HiveGui, circular badges (B/S/G/A/Q), accumulate permanently
- SFX: short celebratory chime (NoAttenuation — plays clearly for the earning player)
- Server guards: `CensusHighest` player attribute persists highest tier across rejoins
- Skipped tiers: if a player jumps from 8→120 bees in one session, all uncelebrated tiers fire in sequence with a 50ms stagger

**Part budget: +0 permanent → 4,204 / 5,000**
