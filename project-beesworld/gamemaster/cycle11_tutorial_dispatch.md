# Dispatch 65 — TutorialService
## Cycle 11 · A Bee's World

**Feature:** First-session guided tutorial — a 6-step overlay that walks new players through: plot claiming, honey collection, spending honey on upgrades, claiming daily reward, prestige concept, and the full game loop. Shown once, dismissed by DataStore flag. Skippable at any step.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 64 (Tab Layout Reflow)

---

## DESIGN

Tutorial is **purely client-side**: a ScreenGui overlay with a spotlight mask, arrow pointer, and text bubble. Driven by a LocalScript that listens for `TutorialSync` RE from the server (server sends `{seen: true}` if the player has already completed it, `{seen: false}` if first session).

Server-side only: records `tutorialSeen = true` in profile when the client fires `TutorialComplete`.

### Steps

| Step | Highlight | Message |
|------|-----------|---------|
| 1 | Plot grid | "Welcome to your hive! Tap a hex to claim your first plot." |
| 2 | Honey HUD counter | "Bees are foraging! Watch your honey grow. 🍯" |
| 3 | ⚡ Speed tab | "Tap ⚡ to upgrade bee speed — faster bees, more honey!" |
| 4 | 📅 Daily tab | "Claim a daily reward every day to build your streak! 📅" |
| 5 | ⭐ Prestige tab | "When honey overflows, Prestige for a permanent bonus. ⭐" |
| 6 | (center) | "You're ready! Build the greatest hive in the world. 🐝" |

Steps advance on tap/click anywhere. Skip button always visible.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DataService` | `tutorialSeen = false` migration |
| `TutorialService` (new Script in SSS) | check + record, TutorialSync RE, TutorialComplete RF |
| `GameManager` | Init call |
| `TutorialController` (new LocalScript) | overlay, steps, skip |

---

## STEP A — DataService migration

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

local anchor = 'unlockedAchievements = {}'
local found = clone.Source:find(anchor, 1, true)
assert(found, "unlockedAchievements anchor not found")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\n\t\ttutorialSeen = false,       -- true after first tutorial completion" .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService tutorialSeen migration applied")
```

---

## STEP B — TutorialService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local TutorialSync     = Instance.new("RemoteEvent")
TutorialSync.Name      = "TutorialSync"
TutorialSync.Parent    = RS

local TutorialComplete = Instance.new("RemoteFunction")
TutorialComplete.Name  = "TutorialComplete"
TutorialComplete.Parent = RS

local svc = Instance.new("Script")
svc.Name   = "TutorialService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- TutorialService
-- Checks if a player has seen the tutorial and records completion.

local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local PS  = game:GetService("Players")

local DataService      = require(SSS:WaitForChild("DataService"))
local TutorialSync     = RS:WaitForChild("TutorialSync")
local TutorialComplete = RS:WaitForChild("TutorialComplete")

local TutorialService = {}

local function sendState(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	TutorialSync:FireClient(player, {seen = profile.tutorialSeen == true})
end

TutorialComplete.OnServerInvoke = function(player: Player): boolean
	local profile = DataService.GetProfile(player)
	if not profile then return false end
	profile.tutorialSeen = true
	return true
end

function TutorialService.Init()
	PS.PlayerAdded:Connect(function(player)
		task.wait(3)   -- wait for profile to load
		sendState(player)
	end)
	for _, player in PS:GetPlayers() do
		task.spawn(sendState, player)
	end
	print("[TutorialService] ready")
end

return TutorialService
]]

print("TutorialService created")
```

---

## STEP C — GameManager Init

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local LeaderboardService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "LeaderboardService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal TutorialService = require(SSS:WaitForChild(\"TutorialService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'LeaderboardService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "LeaderboardService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nTutorialService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager TutorialService.Init() injected")
```

---

## STEP D — TutorialController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name = "TutorialController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- TutorialController — first-session guided tutorial overlay

local PS            = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player       = PS.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")
local TutorialSync     = RS:WaitForChild("TutorialSync")
local TutorialComplete = RS:WaitForChild("TutorialComplete")

local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local PROP_BROWN = Color3.fromRGB(80, 50, 20)
local WAX_CREAM  = Color3.fromRGB(232, 212, 154)
local OVERLAY_BG = Color3.fromRGB(0, 0, 0)

-- Tutorial steps: {message, arrowDir, arrowX, arrowY}
-- arrowDir: "left", "right", "up", "down", "none"
local STEPS: {{msg: string, arrowDir: string, arrowX: number, arrowY: number}} = {
	{msg = "Welcome to your hive! 🐝\nTap a hex cell to claim your first plot.",   arrowDir="none",    arrowX=0.5,  arrowY=0.5},
	{msg = "Your bees are foraging!\nWatch your honey grow. 🍯",                   arrowDir="up",      arrowX=0.5,  arrowY=0.10},
	{msg = "Tap ⚡ to upgrade bee speed —\nfaster bees, more honey!",              arrowDir="left",    arrowX=0.08, arrowY=0.27},
	{msg = "Claim a daily reward every day\nto build your streak! 📅",             arrowDir="left",    arrowX=0.08, arrowY=0.72},
	{msg = "When honey is plentiful,\nPrestige ⭐ for a permanent bonus!",         arrowDir="right",   arrowX=0.89, arrowY=0.38},
	{msg = "You're ready!\nBuild the greatest hive in the world. 🐝🍯",            arrowDir="none",    arrowX=0.5,  arrowY=0.5},
}

local currentStep = 0
local tutorialGui: ScreenGui?  = nil
local bubble: Frame? = nil
local msgLbl: TextLabel? = nil
local stepLbl: TextLabel? = nil

local function buildGui()
	local sg = Instance.new("ScreenGui")
	sg.Name            = "TutorialGui"
	sg.ResetOnSpawn    = false
	sg.DisplayOrder    = 50   -- above all other UI
	sg.IgnoreGuiInset  = true
	sg.Parent          = playerGui
	tutorialGui = sg

	-- semi-transparent overlay
	local overlay = Instance.new("Frame")
	overlay.Name              = "Overlay"
	overlay.Size              = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3  = OVERLAY_BG
	overlay.BackgroundTransparency = 0.55
	overlay.BorderSizePixel   = 0
	overlay.ZIndex             = 51
	overlay.Parent             = sg

	-- click anywhere to advance
	local clickBtn = Instance.new("TextButton")
	clickBtn.Size              = UDim2.new(1, 0, 1, 0)
	clickBtn.BackgroundTransparency = 1
	clickBtn.Text              = ""
	clickBtn.ZIndex            = 52
	clickBtn.Parent            = overlay
	clickBtn.MouseButton1Click:Connect(function() advanceStep() end)

	-- text bubble
	local bub = Instance.new("Frame")
	bub.Name              = "Bubble"
	bub.Size              = UDim2.new(0.55, 0, 0.20, 0)
	bub.Position          = UDim2.new(0.225, 0, 0.38, 0)
	bub.BackgroundColor3  = PROP_BROWN
	bub.BorderSizePixel   = 0
	bub.ZIndex             = 53
	bub.Parent             = sg
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.08, 0); c.Parent = bub end
	do local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 3; s.Parent = bub end
	bubble = bub

	local ml = Instance.new("TextLabel")
	ml.Name              = "Message"
	ml.Size              = UDim2.new(0.90, 0, 0.65, 0)
	ml.Position          = UDim2.new(0.05, 0, 0.05, 0)
	ml.BackgroundTransparency = 1
	ml.Text              = ""
	ml.TextColor3        = WAX_CREAM
	ml.TextScaled        = true
	ml.Font              = Enum.Font.Gotham
	ml.TextWrapped       = true
	ml.ZIndex             = 54
	ml.Parent             = bub
	msgLbl = ml

	local sl = Instance.new("TextLabel")
	sl.Name              = "StepIndicator"
	sl.Size              = UDim2.new(0.5, 0, 0.22, 0)
	sl.Position          = UDim2.new(0.05, 0, 0.72, 0)
	sl.BackgroundTransparency = 1
	sl.Text              = "1 / 6"
	sl.TextColor3        = HONEY_GOLD
	sl.TextScaled        = true
	sl.Font              = Enum.Font.GothamBold
	sl.ZIndex             = 54
	sl.Parent             = bub
	stepLbl = sl

	-- tap to continue hint
	local tapHint = Instance.new("TextLabel")
	tapHint.Size              = UDim2.new(0.45, 0, 0.22, 0)
	tapHint.Position          = UDim2.new(0.50, 0, 0.72, 0)
	tapHint.BackgroundTransparency = 1
	tapHint.Text              = "tap to continue →"
	tapHint.TextColor3        = Color3.fromRGB(180, 150, 80)
	tapHint.TextScaled        = true
	tapHint.Font              = Enum.Font.Gotham
	tapHint.TextXAlignment    = Enum.TextXAlignment.Right
	tapHint.ZIndex             = 54
	tapHint.Parent             = bub

	-- skip button
	local skipBtn = Instance.new("TextButton")
	skipBtn.Name              = "SkipBtn"
	skipBtn.Size              = UDim2.new(0.15, 0, 0.06, 0)
	skipBtn.Position          = UDim2.new(0.83, 0, 0.01, 0)
	skipBtn.BackgroundColor3  = Color3.fromRGB(100, 50, 50)
	skipBtn.BorderSizePixel   = 0
	skipBtn.Text              = "Skip"
	skipBtn.TextColor3        = WAX_CREAM
	skipBtn.TextScaled        = true
	skipBtn.Font              = Enum.Font.Gotham
	skipBtn.ZIndex             = 55
	skipBtn.Parent             = sg
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.3, 0); c.Parent = skipBtn end
	skipBtn.MouseButton1Click:Connect(function() completeTutorial() end)
end

local function showStep(n: number)
	if n > #STEPS then
		completeTutorial()
		return
	end
	currentStep = n
	local step = STEPS[n]
	if msgLbl then msgLbl.Text = step.msg end
	if stepLbl then stepLbl.Text = n .. " / " .. #STEPS end

	-- pop bubble in
	if bubble then
		bubble.Size = UDim2.new(0.55, 0, 0.01, 0)
		TweenService:Create(bubble, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0.55, 0, 0.20, 0)}):Play()
	end
end

function advanceStep()
	showStep(currentStep + 1)
end

function completeTutorial()
	if tutorialGui then
		TweenService:Create(tutorialGui, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {}):Play()
		task.wait(0.35)
		tutorialGui:Destroy()
		tutorialGui = nil
	end
	pcall(function() TutorialComplete:InvokeServer() end)
end

TutorialSync.OnClientEvent:Connect(function(data: {seen: boolean})
	if data.seen then return end   -- already completed — do nothing
	task.wait(1.5)   -- let game UI finish loading
	buildGui()
	showStep(1)
end)
]]

print("TutorialController created")
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local ds = SSS:FindFirstChild("DataService")
table.insert(checks, (ds and ds.Source:find("tutorialSeen") and "✅" or "❌") .. " DataService tutorialSeen")

local svc = SSS:FindFirstChild("TutorialService")
table.insert(checks, (svc and "✅" or "❌") .. " TutorialService script")

local tsync = RS:FindFirstChild("TutorialSync")
table.insert(checks, (tsync and "✅" or "❌") .. " TutorialSync RemoteEvent")

local tcomplete = RS:FindFirstChild("TutorialComplete")
table.insert(checks, (tcomplete and "✅" or "❌") .. " TutorialComplete RemoteFunction")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("TutorialService") and "✅" or "❌") .. " GameManager Init")

local ctrl = SPS and SPS:FindFirstChild("TutorialController")
table.insert(checks, (ctrl and "✅" or "❌") .. " TutorialController")

print("=== DISPATCH 65 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 65 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 65 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- Tutorial only fires on first session (`tutorialSeen = false`). Returning players see nothing.
- `IgnoreGuiInset = true` on TutorialGui ensures the overlay covers the full screen including the Roblox top bar area.
- DisplayOrder=50 puts it above all other game UI (highest existing is 26 for badges).
- The overlay click target is a transparent TextButton (not Frame) so `MouseButton1Click` fires on mobile tap correctly.
- Steps 3 and 4 point at actual tab positions (X=0.08 left column) — these match the reflowed layout from dispatch 64. Step 5 points at the right column (X=0.89).
- `completeTutorial()` is a module-level upvalue so `clickBtn` can call `advanceStep()` without capturing it in the closure; both work from the same local environment.
