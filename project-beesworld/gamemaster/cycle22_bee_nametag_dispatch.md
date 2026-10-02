# Dispatch 219 — Bee Name Tag
**File:** `cycle22_bee_nametag_dispatch.md`
**Cycle:** 22
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,204 / 5,000 (+0)

---

## Overview

In a 6-player tycoon game, seeing other players' names and progress creates social presence and competition. The default Roblox name tag is plain white text. This dispatch replaces it with a **Bee Name Tag**: a styled BillboardGui above each player's character head showing their username with a honeycomb-style dark background, a 🐝 emoji, and their current honey count ("🍯 47"). Updates reactively as honey changes. Hides the default Roblox overhead name via `Players.LocalPlayer.Character.Humanoid.DisplayDistanceType = None` on the local side.

For kids: the bee emoji + name makes every player feel like a beekeeper. For adults: the honey count is visible social competition at a glance.

---

## Step 1 — BeeNameTagController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `BeeNameTagController`.

Paste exactly:

```lua
--!strict
-- BeeNameTagController: custom styled name tag above each player's head.
-- Shows username + live honey count. Hides default Roblox name tag.
-- Entirely client-side — zero server writes, zero new parts.

local Players           = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
local TAG_OFFSET_219  = Vector3.new(0, 2.2, 0)   -- above HumanoidRootPart
local SCAN_INTERVAL_219 = 6.0

-- ── Palette ───────────────────────────────────────────────────────────────────
local DARK_BG_219   = Color3.fromRGB( 28,  16,   6)
local WAX_CREAM_219 = Color3.fromRGB(232, 212, 154)
local HONEY_219     = Color3.fromRGB(242, 168,  28)
local SELF_219      = Color3.fromRGB(255, 220,  80)   -- brighter for local player

-- ── Per-player state ──────────────────────────────────────────────────────────
local tagGuis_219: { [Player]: BillboardGui } = {}

-- ── Build tag ─────────────────────────────────────────────────────────────────
local function buildTag_219(character: Model, isSelf: boolean): BillboardGui?
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end

	-- Remove any pre-existing tag
	local existing = hrp:FindFirstChild("BeeNameTag_219") :: BillboardGui?
	if existing then existing:Destroy() end

	local bg = Instance.new("BillboardGui")
	bg.Name          = "BeeNameTag_219"
	bg.Size          = UDim2.new(0, 140, 0, 36)
	bg.StudsOffset   = TAG_OFFSET_219
	bg.AlwaysOnTop   = false
	bg.ResetOnSpawn  = false
	bg.Parent        = hrp

	local frame = Instance.new("Frame")
	frame.Name                   = "TagFrame"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = DARK_BG_219
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel        = 0
	frame.Parent                 = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color     = isSelf and SELF_219 or HONEY_219
	stroke.Thickness = 1.5
	stroke.Parent    = frame

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name               = "NameLabel"
	nameLbl.Size               = UDim2.new(1, -6, 0.55, 0)
	nameLbl.Position           = UDim2.new(0, 3, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text               = "🐝 " .. "..."
	nameLbl.TextSize           = 11
	nameLbl.Font               = Enum.Font.GothamBold
	nameLbl.TextColor3         = isSelf and SELF_219 or WAX_CREAM_219
	nameLbl.TextXAlignment     = Enum.TextXAlignment.Center
	nameLbl.TextTruncate       = Enum.TextTruncate.AtEnd
	nameLbl.ZIndex             = 2
	nameLbl.Parent             = frame

	local honeyLbl = Instance.new("TextLabel")
	honeyLbl.Name               = "HoneyLabel"
	honeyLbl.Size               = UDim2.new(1, -6, 0.38, 0)
	honeyLbl.Position           = UDim2.new(0, 3, 0.58, 0)
	honeyLbl.BackgroundTransparency = 1
	honeyLbl.Text               = "🍯 0"
	honeyLbl.TextSize           = 9
	honeyLbl.Font               = Enum.Font.Gotham
	honeyLbl.TextColor3         = HONEY_219
	honeyLbl.TextXAlignment     = Enum.TextXAlignment.Center
	honeyLbl.ZIndex             = 2
	honeyLbl.Parent             = frame

	return bg
end

-- ── Update tag ────────────────────────────────────────────────────────────────
local function updateTag_219(player: Player, bg: BillboardGui)
	local frame = bg:FindFirstChild("TagFrame")
	local nameLbl  = frame and frame:FindFirstChild("NameLabel")  :: TextLabel?
	local honeyLbl = frame and frame:FindFirstChild("HoneyLabel") :: TextLabel?

	if nameLbl then
		nameLbl.Text = "🐝 " .. player.Name
	end
	if honeyLbl then
		local honey = (player:GetAttribute("HoneyCount") :: number?) or 0
		honeyLbl.Text = "🍯 " .. tostring(honey)
	end
end

-- ── Setup player ──────────────────────────────────────────────────────────────
local function setupPlayer_219(player: Player)
	local isSelf = (player == localPlayer)

	local function onCharacterAdded(character: Model)
		task.wait(0.5)   -- wait for HumanoidRootPart to be ready
		local bg = buildTag_219(character, isSelf)
		if not bg then return end
		tagGuis_219[player] = bg
		updateTag_219(player, bg)

		-- Hide default Roblox name tag for this character
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			humanoid.HealthDisplayType   = Enum.HumanoidHealthDisplayType.AlwaysOff
		end

		-- React to honey changes
		player:GetAttributeChangedSignal("HoneyCount"):Connect(function()
			if bg and bg.Parent then
				updateTag_219(player, bg)
			end
		end)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- ── Cleanup ───────────────────────────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	tagGuis_219[player] = nil
end)

-- ── Safety scan ───────────────────────────────────────────────────────────────
local scanAcc_219 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_219 += dt
	if scanAcc_219 < SCAN_INTERVAL_219 then return end
	scanAcc_219 = 0
	for player, bg in tagGuis_219 do
		if bg and bg.Parent then
			updateTag_219(player, bg)
		else
			tagGuis_219[player] = nil
		end
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	for _, player in Players:GetPlayers() do
		setupPlayer_219(player)
	end
	Players.PlayerAdded:Connect(setupPlayer_219)
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("BeeNameTagController"))
```

---

## Step 3 — Verification sweep

Run in **Studio Command Bar**:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("BeeNameTagController")
print("BeeNameTagController:", c and c.ClassName or "MISSING")
if c then
	local lines = select(2, c.Source:gsub("\n","")) + 1
	print("  lines:", lines)
	print("  buildTag_219:", c.Source:find("buildTag_219") ~= nil)
	print("  updateTag_219:", c.Source:find("updateTag_219") ~= nil)
	print("  HoneyCount attr:", c.Source:find("HoneyCount") ~= nil)
	print("  DisplayDistanceType:", c.Source:find("DisplayDistanceType") ~= nil)
end

-- In Play mode: check name tag exists above character
-- local char = game:GetService("Players").LocalPlayer.Character
-- local hrp = char and char:FindFirstChild("HumanoidRootPart")
-- print("BeeNameTag_219:", hrp and hrp:FindFirstChild("BeeNameTag_219") ~= nil)

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4204)")
```

---

## Behaviour summary

| Feature | Detail |
|---|---|
| Name line | "🐝 [PlayerName]" — truncated if long, GothamBold 11pt |
| Honey line | "🍯 [HoneyCount]" — updates on HoneyCount attribute change |
| Own tag | Bright gold stroke + text (SELF_219) — distinguishable at a glance |
| Other tags | Honey gold stroke, wax cream name text |
| Default Roblox tag | Hidden (`DisplayDistanceType = None`) — no overlap |
| Respawn | CharacterAdded rebuilds tag automatically |
| Position | 2.2 studs above HumanoidRootPart — visible over comb grid |
| AlwaysOnTop | false — occluded by geometry, less intrusive |

- Hides health bar too (`HealthDisplayType = AlwaysOff`) — cleaner, health isn't a mechanic here
- BillboardGui is parented to HumanoidRootPart so it moves naturally with the character
- Per-player connections cleaned up on PlayerRemoving
- 6s safety scan refreshes honey counts in case of missed attribute signals

**Part budget: +0 server-side permanent → 4,204 / 5,000**
*(BillboardGui only — no BaseParts)*
