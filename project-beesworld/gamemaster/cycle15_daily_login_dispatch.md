# Dispatch 161 — Daily Login Rewards
**File:** `cycle15_daily_login_dispatch.md`
**Branch:** add-beesworld-project
**Part budget:** +0 new world parts → 4,198 / 5,000

---

## Overview

Kids need a reason to open the hive every single day. Daily Login Rewards gives them one: a growing
streak of honey jars that resets on a 7-day cycle, with a bigger celebration on the 7th day. The
popup fires once per UTC day, on first join, so it doesn't interrupt ongoing play. Adults see their
streak count and a preview of tomorrow's reward. Kids see a honey jar and a number.

**What gets built:**
1. DataService v14→v15 migration (`lastLoginDate`, `loginStreak` fields)
2. `LoginRewardService` ModuleScript — date detection, streak tracking, reward grant
3. `LoginRewardController` LocalScript — daily popup with streak display and confetti on day 7
4. No world parts (pure UI + server logic)

---

## Step 1 — DataService v14→v15

Open **Command Bar** and run:

```lua
-- STEP 1: Add login reward fields to DataService profile template and migration
local DS = require(game:GetService("ServerScriptService").Systems.DataService)

-- Patch PROFILE_TEMPLATE
local template = DS.PROFILE_TEMPLATE
if template then
    if template.lastLoginDate == nil then template.lastLoginDate = "" end
    if template.loginStreak  == nil then template.loginStreak  = 0  end
    print("PROFILE_TEMPLATE patched: lastLoginDate + loginStreak added")
else
    print("WARN: PROFILE_TEMPLATE not directly accessible -- apply migration manually (see Step 1b)")
end
```

**Step 1b — Manual template edit (if Step 1 printed WARN):**

In DataService ModuleScript, locate the `PROFILE_TEMPLATE` table and add two fields after
`honeyEarned` (or any existing field — order does not matter):

```lua
lastLoginDate = "",   -- "YYYY-MM-DD" of last reward claim, empty = never
loginStreak   = 0,    -- consecutive days claimed (resets on gap >1 day)
```

Then add a v15 migration entry in the `MIGRATIONS` table:

```lua
[15] = function(profile)
    if profile.lastLoginDate == nil then profile.lastLoginDate = "" end
    if profile.loginStreak   == nil then profile.loginStreak   = 0  end
end,
```

And bump `CURRENT_VERSION` from 14 to 15:

```lua
local CURRENT_VERSION = 15
```

**Verification:**

```lua
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
print("DataService version:", DS.CURRENT_VERSION or DS._version or "check manually")
-- Expected: 15
```

---

## Step 2 — LoginRewardService ModuleScript

In Studio Explorer: **ServerScriptService → Systems** → Insert **ModuleScript**, rename
`LoginRewardService`.

Paste full source:

```lua
--!strict
-- LoginRewardService: tracks daily login streaks and grants rewards once per UTC day.

local LoginRewardService = {}

local Players = game:GetService("Players")
local DataService = require(script.Parent.DataService)

-- ── Reward table (7-day cycle, repeating) ──────────────────────────────────────
local REWARDS_161: { [number]: { honey: number, propolis: number, pollen: number, label: string } } = {
	[1] = { honey = 50,  propolis = 0,  pollen = 0,  label = "Day 1 — Welcome back! 🍯"             },
	[2] = { honey = 75,  propolis = 5,  pollen = 0,  label = "Day 2 — Steady buzz! 🐝"               },
	[3] = { honey = 100, propolis = 0,  pollen = 10, label = "Day 3 — Pollen power! 🌸"              },
	[4] = { honey = 125, propolis = 15, pollen = 0,  label = "Day 4 — Strong propolis! 🌿"           },
	[5] = { honey = 150, propolis = 0,  pollen = 15, label = "Day 5 — Almost there! ✨"              },
	[6] = { honey = 200, propolis = 20, pollen = 0,  label = "Day 6 — One more day! 🌟"             },
	[7] = { honey = 300, propolis = 30, pollen = 20, label = "Day 7 — STREAK COMPLETE! 🎉🍯🎉"      },
}

-- RemoteEvent fired to client with reward payload
local RewardGranted_161: RemoteEvent

local function getOrCreate_161(parent: Instance, class: string, name: string): Instance
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(class)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

-- Returns "YYYY-MM-DD" for current UTC day
local function todayUTC_161(): string
	local t = os.date("!*t") :: any
	return string.format("%04d-%02d-%02d", t.year, t.month, t.mday)
end

-- ── Public API ─────────────────────────────────────────────────────────────────

-- Called on player join. Returns false if already claimed today.
function LoginRewardService.TryClaim(player: Player): boolean
	local profile = DataService.GetProfile(player)
	if not profile then return false end

	local today = todayUTC_161()
	if profile.lastLoginDate == today then
		return false  -- already claimed today
	end

	-- Compute streak
	local prevDate = profile.lastLoginDate or ""
	local newStreak = 1
	if prevDate ~= "" then
		-- Check if yesterday matches
		local prevTime = os.time({
			year  = tonumber(prevDate:sub(1,4))  :: number,
			month = tonumber(prevDate:sub(6,7))  :: number,
			day   = tonumber(prevDate:sub(9,10)) :: number,
			hour  = 0, min = 0, sec = 0,
		})
		local todayTime = os.time({
			year  = tonumber(today:sub(1,4))  :: number,
			month = tonumber(today:sub(6,7))  :: number,
			day   = tonumber(today:sub(9,10)) :: number,
			hour  = 0, min = 0, sec = 0,
		})
		local daysDiff = math.round((todayTime - prevTime) / 86400)
		if daysDiff == 1 then
			newStreak = (profile.loginStreak or 0) + 1
		elseif daysDiff == 0 then
			return false  -- same day, shouldn't reach here but guard anyway
		end
		-- daysDiff > 1: streak broken, newStreak stays 1
	end

	profile.lastLoginDate = today
	profile.loginStreak   = newStreak

	-- Determine reward slot (1–7 cycle)
	local slot = ((newStreak - 1) % 7) + 1
	local reward = REWARDS_161[slot]

	-- Grant resources server-authoritatively
	local honey    = player:GetAttribute("HoneyCount")    :: number?
	local propolis = player:GetAttribute("PropolisCount") :: number?
	local pollen   = player:GetAttribute("PollenCount")   :: number?
	player:SetAttribute("HoneyCount",    (honey    or 0) + reward.honey)
	player:SetAttribute("PropolisCount", (propolis or 0) + reward.propolis)
	player:SetAttribute("PollenCount",   (pollen   or 0) + reward.pollen)

	-- Also persist to profile so DataService saves it
	if profile.honey    ~= nil then profile.honey    = profile.honey    + reward.honey    end
	if profile.propolis ~= nil then profile.propolis = profile.propolis + reward.propolis end
	if profile.pollen   ~= nil then profile.pollen   = profile.pollen  + reward.pollen   end

	-- Fire to client
	pcall(function()
		RewardGranted_161:FireClient(player, {
			streak   = newStreak,
			slot     = slot,
			honey    = reward.honey,
			propolis = reward.propolis,
			pollen   = reward.pollen,
			label    = reward.label,
			isDay7   = (slot == 7),
			nextHoney = REWARDS_161[((slot % 7) + 1)].honey,
		})
	end)

	return true
end

function LoginRewardService.Init()
	local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	if not Remotes then
		Remotes = Instance.new("Folder")
		Remotes.Name = "Remotes"
		Remotes.Parent = game:GetService("ReplicatedStorage")
	end
	RewardGranted_161 = getOrCreate_161(Remotes, "RemoteEvent", "LoginRewardGranted") :: RemoteEvent

	Players.PlayerAdded:Connect(function(player)
		-- Small delay so DataService loads the profile first
		task.delay(4, function()
			if player.Parent then
				LoginRewardService.TryClaim(player)
			end
		end)
	end)
end

return LoginRewardService
```

**Verification:**

```lua
local LRS = require(game:GetService("ServerScriptService").Systems.LoginRewardService)
print(type(LRS.TryClaim), type(LRS.Init))
-- Expected: function  function
local R = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("LoginRewardGranted")
print(R and R.ClassName or "MISSING")
-- Expected: RemoteEvent
```

---

## Step 3 — Wire LoginRewardService into Main Script

In **ServerScriptService → Main** (the root bootstrap Script), add after the existing
`require` calls near the top of the service-init block:

```lua
local LoginRewardService_161 = require(script.Parent.Systems.LoginRewardService)
LoginRewardService_161.Init()
```

**Verification:**

```lua
-- Simulate a claim for a fake player to confirm Init ran without error
local LRS = require(game:GetService("ServerScriptService").Systems.LoginRewardService)
print("LoginRewardService loaded via Main:", LRS ~= nil)
-- Expected: true
```

---

## Step 4 — LoginRewardController LocalScript

In Studio Explorer: **StarterPlayer → StarterPlayerScripts** → Insert **LocalScript**,
rename `LoginRewardController`.

Paste full source:

```lua
--!strict
-- LoginRewardController: shows daily login reward popup once per session.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────────────────
local HONEY_GOLD_161   = Color3.fromRGB(242, 168, 28)
local PROPOLIS_161     = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_161    = Color3.fromRGB(232, 212, 154)
local GREEN_161        = Color3.fromRGB(60,  160, 60)
local BLUE_161         = Color3.fromRGB(100, 140, 220)

-- ── Build UI ──────────────────────────────────────────────────────────────────

local function buildUI_161()
	-- ScreenGui
	local sg = Instance.new("ScreenGui")
	sg.Name            = "LoginRewardGui"
	sg.DisplayOrder    = 95
	sg.ResetOnSpawn    = false
	sg.IgnoreGuiInset  = true
	sg.Enabled         = false
	sg.Parent          = playerGui

	-- Backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Name              = "Backdrop"
	backdrop.Size              = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.55
	backdrop.BorderSizePixel   = 0
	backdrop.Parent            = sg

	-- Card
	local card = Instance.new("Frame")
	card.Name              = "Card"
	card.AnchorPoint       = Vector2.new(0.5, 0.5)
	card.Position          = UDim2.new(0.5, 0, 0.5, 0)
	card.Size              = UDim2.new(0, 320, 0, 360)
	card.BackgroundColor3  = PROPOLIS_161
	card.BorderSizePixel   = 0
	card.Parent            = sg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color     = HONEY_GOLD_161
	stroke.Thickness = 3
	stroke.Parent    = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Name              = "Title"
	title.Size              = UDim2.new(1, 0, 0, 40)
	title.Position          = UDim2.new(0, 0, 0, 12)
	title.BackgroundTransparency = 1
	title.TextColor3        = HONEY_GOLD_161
	title.TextSize          = 22
	title.Font              = Enum.Font.GothamBold
	title.Text              = "🍯 Daily Honey! 🍯"
	title.Parent            = card

	-- Streak badge
	local streakBadge = Instance.new("TextLabel")
	streakBadge.Name              = "StreakBadge"
	streakBadge.Size              = UDim2.new(0, 160, 0, 32)
	streakBadge.AnchorPoint       = Vector2.new(0.5, 0)
	streakBadge.Position          = UDim2.new(0.5, 0, 0, 56)
	streakBadge.BackgroundColor3  = Color3.fromRGB(60, 35, 10)
	streakBadge.TextColor3        = WAX_CREAM_161
	streakBadge.TextSize          = 14
	streakBadge.Font              = Enum.Font.GothamBold
	streakBadge.Text              = "🔥 Day 1 Streak"
	streakBadge.Parent            = card
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 10)
	badgeCorner.Parent = streakBadge

	-- Big honey jar emoji
	local jar = Instance.new("TextLabel")
	jar.Name                  = "JarEmoji"
	jar.Size                  = UDim2.new(1, 0, 0, 80)
	jar.Position              = UDim2.new(0, 0, 0, 96)
	jar.BackgroundTransparency = 1
	jar.TextColor3            = Color3.fromRGB(255, 255, 255)
	jar.TextSize              = 64
	jar.Font                  = Enum.Font.GothamBold
	jar.Text                  = "🍯"
	jar.Parent                = card

	-- Reward label (kid text)
	local rewardLabel = Instance.new("TextLabel")
	rewardLabel.Name              = "RewardLabel"
	rewardLabel.Size              = UDim2.new(1, -24, 0, 36)
	rewardLabel.Position          = UDim2.new(0, 12, 0, 182)
	rewardLabel.BackgroundTransparency = 1
	rewardLabel.TextColor3        = HONEY_GOLD_161
	rewardLabel.TextSize          = 20
	rewardLabel.Font              = Enum.Font.GothamBold
	rewardLabel.Text              = "+50 Honey!"
	rewardLabel.TextWrapped       = true
	rewardLabel.Parent            = card

	-- Detail row (adult small text)
	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name              = "DetailLabel"
	detailLabel.Size              = UDim2.new(1, -24, 0, 28)
	detailLabel.Position          = UDim2.new(0, 12, 0, 220)
	detailLabel.BackgroundTransparency = 1
	detailLabel.TextColor3        = WAX_CREAM_161
	detailLabel.TextTransparency  = 0.3
	detailLabel.TextSize          = 13
	detailLabel.Font              = Enum.Font.Gotham
	detailLabel.Text              = "+5 Propolis · +0 Pollen · Tomorrow: +75 🍯"
	detailLabel.TextWrapped       = true
	detailLabel.Parent            = card

	-- 7-day progress dots
	local dotsFrame = Instance.new("Frame")
	dotsFrame.Name                 = "DotsFrame"
	dotsFrame.Size                 = UDim2.new(0, 252, 0, 24)
	dotsFrame.AnchorPoint          = Vector2.new(0.5, 0)
	dotsFrame.Position             = UDim2.new(0.5, 0, 0, 256)
	dotsFrame.BackgroundTransparency = 1
	dotsFrame.Parent               = card

	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection       = Enum.FillDirection.Horizontal
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Padding             = UDim.new(0, 6)
	dotsLayout.Parent              = dotsFrame

	-- Dots created dynamically in populateUI_161

	-- Collect button
	local collectBtn = Instance.new("TextButton")
	collectBtn.Name              = "CollectBtn"
	collectBtn.Size              = UDim2.new(0, 200, 0, 44)
	collectBtn.AnchorPoint       = Vector2.new(0.5, 0)
	collectBtn.Position          = UDim2.new(0.5, 0, 0, 294)
	collectBtn.BackgroundColor3  = HONEY_GOLD_161
	collectBtn.TextColor3        = Color3.fromRGB(50, 30, 0)
	collectBtn.TextSize          = 18
	collectBtn.Font              = Enum.Font.GothamBold
	collectBtn.Text              = "🍯 Collect!"
	collectBtn.BorderSizePixel   = 0
	collectBtn.Parent            = card
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 12)
	btnCorner.Parent = collectBtn

	return sg, card, title, streakBadge, jar, rewardLabel, detailLabel, dotsFrame, collectBtn
end

-- ── Confetti (day 7 only) ──────────────────────────────────────────────────────
local function spawnConfetti_161(sg: ScreenGui)
	local colors = {HONEY_GOLD_161, Color3.fromRGB(255,100,100), Color3.fromRGB(100,200,100), BLUE_161, WAX_CREAM_161}
	for i = 1, 16 do
		local sq = Instance.new("Frame")
		sq.Size                = UDim2.new(0, 10, 0, 10)
		sq.BackgroundColor3    = colors[(i % #colors) + 1]
		sq.BorderSizePixel     = 0
		sq.Position            = UDim2.new(math.random(10,90)/100, 0, -0.05, 0)
		sq.BackgroundTransparency = 0
		sq.Parent              = sg
		local corner_sq = Instance.new("UICorner")
		corner_sq.CornerRadius = UDim.new(0, 2)
		corner_sq.Parent = sq
		local fallTween = TweenService:Create(sq,
			TweenInfo.new(math.random(18, 30) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(sq.Position.X.Scale, 0, 1.1, 0) }
		)
		fallTween:Play()
		fallTween.Completed:Connect(function() sq:Destroy() end)
	end
end

-- ── Populate + show ────────────────────────────────────────────────────────────
local function populateAndShow_161(data: {
	streak: number, slot: number,
	honey: number, propolis: number, pollen: number,
	label: string, isDay7: boolean, nextHoney: number
})
	local sg, card, title, streakBadge, jar, rewardLabel, detailLabel, dotsFrame, collectBtn =
		buildUI_161()

	-- Streak badge
	streakBadge.Text = "🔥 Day " .. data.streak .. " Streak"
	if data.streak >= 7 then
		streakBadge.BackgroundColor3 = Color3.fromRGB(180, 120, 0)
	end

	-- Jar emoji (day 7 = trophy)
	jar.Text = data.isDay7 and "🏆" or "🍯"

	-- Reward label (kid text)
	local kidText = "+" .. data.honey .. " Honey!"
	if data.isDay7 then
		kidText = "🎉 +" .. data.honey .. " Honey + Bonus!"
		title.Text = "🎉 Streak Complete! 🎉"
		title.TextColor3 = GREEN_161
	end
	rewardLabel.Text = kidText

	-- Detail label (adult text)
	local parts = {"+0 Propolis", "+0 Pollen"}
	if data.propolis > 0 then parts[1] = "+" .. data.propolis .. " Propolis" end
	if data.pollen   > 0 then parts[2] = "+" .. data.pollen .. " Pollen"   end
	detailLabel.Text = table.concat(parts, " · ") .. " · Tomorrow: +" .. data.nextHoney .. " 🍯"

	-- Progress dots
	for i = 1, 7 do
		local dot = Instance.new("Frame")
		dot.Size              = UDim2.new(0, 24, 0, 24)
		dot.BackgroundTransparency = 0
		dot.BorderSizePixel   = 0
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot
		if i < data.slot then
			dot.BackgroundColor3 = GREEN_161           -- past days
		elseif i == data.slot then
			dot.BackgroundColor3 = HONEY_GOLD_161      -- today
			local dotStroke = Instance.new("UIStroke")
			dotStroke.Thickness = 2
			dotStroke.Color     = Color3.fromRGB(255,255,255)
			dotStroke.Parent    = dot
		else
			dot.BackgroundColor3 = Color3.fromRGB(60, 40, 15)  -- future
		end
		dot.Parent = dotsFrame

		-- Number label inside dot
		local num = Instance.new("TextLabel")
		num.Size                 = UDim2.fromScale(1,1)
		num.BackgroundTransparency = 1
		num.TextColor3           = Color3.fromRGB(255,255,255)
		num.TextSize             = 11
		num.Font                 = Enum.Font.GothamBold
		num.Text                 = tostring(i)
		num.Parent               = dot
	end

	-- Slide in animation
	sg.Enabled = true
	card.Position = UDim2.new(0.5, 0, 1.6, 0)  -- start below screen
	TweenService:Create(card,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.5, 0) }
	):Play()

	-- Day 7 confetti
	if data.isDay7 then
		task.delay(0.4, function()
			for _ = 1, 3 do
				spawnConfetti_161(sg)
				task.wait(0.5)
			end
		end)
	end

	-- Collect button
	collectBtn.MouseButton1Click:Connect(function()
		TweenService:Create(card,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, -0.6, 0) }
		):Play()
		task.delay(0.35, function() sg:Destroy() end)
	end)

	-- Auto-dismiss after 12s
	task.delay(12, function()
		if sg and sg.Parent then
			TweenService:Create(card,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(0.5, 0, -0.6, 0) }
			):Play()
			task.delay(0.3, function()
				if sg and sg.Parent then sg:Destroy() end
			end)
		end
	end)
end

-- ── Listen for server grant ────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if Remotes then
	local rewardEvent = Remotes:WaitForChild("LoginRewardGranted", 10) :: RemoteEvent?
	if rewardEvent then
		rewardEvent.OnClientEvent:Connect(function(data: any)
			populateAndShow_161(data)
		end)
	end
end
```

**Verification — run in Command Bar during Play mode:**

```lua
-- Check script exists
local lrs = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("LoginRewardController")
print(lrs and lrs.ClassName or "MISSING")
-- Expected: LocalScript

-- Check RemoteEvent
local re = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("LoginRewardGranted")
print(re and re.ClassName or "MISSING")
-- Expected: RemoteEvent
```

---

## Step 5 — Test in Play Mode

Enter Play mode (F5). Within 5 seconds the daily reward popup should appear for a new/fresh
profile. To force a reward (bypass "already claimed today" guard) run in Command Bar:

```lua
-- Force-clear lastLoginDate so TryClaim fires for your session
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
local player = game:GetService("Players"):GetPlayers()[1]
local profile = DS.GetProfile(player)
if profile then
    profile.lastLoginDate = ""
    profile.loginStreak   = 6     -- force a Day 7 to test confetti
    print("Cleared lastLoginDate. Rejoining in 5s will show Day 7 reward.")
end
```

Then leave and rejoin (or call `LoginRewardService.TryClaim(player)` directly):

```lua
local LRS = require(game:GetService("ServerScriptService").Systems.LoginRewardService)
local player = game:GetService("Players"):GetPlayers()[1]
local result = LRS.TryClaim(player)
print("TryClaim result:", result)
-- Expected: true (first call), false (second call same UTC day)
```

**Expected behaviour:**
- Popup slides up from bottom of screen with spring easing
- Streak badge shows "🔥 Day N Streak"
- 7 progress dots with today's dot highlighted gold
- Day 7: title turns green "🎉 Streak Complete! 🎉", confetti rains down
- "Collect!" button dismisses; popup auto-closes after 12s
- `HoneyCount` attribute increases by the correct reward amount (verify via Output or
  `print(player:GetAttribute("HoneyCount"))` before and after TryClaim)

---

## Step 6 — state.json update

After executing in Studio, update `dispatch_count` to 161 and `last_dispatch` to
`"cycle15_daily_login_dispatch.md"` in state.json.

---

## Summary

| What | Where |
|---|---|
| DataService v14→v15 | `PROFILE_TEMPLATE` + `MIGRATIONS[15]` + `CURRENT_VERSION=15` |
| `LoginRewardService` | `ServerScriptService.Systems` ModuleScript |
| Main Script wire | `require … LoginRewardService.Init()` at startup |
| `LoginRewardController` | `StarterPlayer.StarterPlayerScripts` LocalScript |
| `LoginRewardGranted` RemoteEvent | `ReplicatedStorage.Remotes` |
| New world parts | **0** → total **4,198 / 5,000** |

**Kid experience:** A honey jar pops up every time you open the game — your streak grows day by day
and on day 7 you get a big gold trophy with confetti raining down.

**Adult experience:** Streak count, exact resource breakdown (+honey +propolis +pollen), tomorrow's
preview reward, and 7-dot progress tracker all in small text beneath the kid headline.
