# Dispatch 67 — SettingsController
## Cycle 11 · A Bee's World

**Feature:** In-game settings panel — BGM on/off toggle, SFX volume slider (0–100%), graphics quality toggle (Low / Medium / High), and a "Reset Tutorial" button that clears `tutorialSeen` via server so the guide replays. Shown via ⚙️ button top-right corner. Client-side only except the tutorial reset RemoteFunction.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 66 (PollenStorageUpgradeService)

---

## DESIGN

Settings panel is a **LocalScript in StarterPlayerScripts** that manages a ScreenGui overlay. Preferences are saved to `LocalPlayer.Data` attributes so they persist across respawns (no server call needed for volume/quality — they are purely client-side).

BGM and SFX are controlled by finding tagged Sound objects:
- BGM sounds carry the `BGM` CollectionService tag.
- SFX sounds carry the `SFX` CollectionService tag.

Graphics quality is controlled by `settings():SetSaveComputerSettings(false)` and then `UserGameSettings.SavedQualityLevel`.

The **Reset Tutorial** button fires `TutorialReset` RemoteFunction (new, added in this dispatch). Server clears `profile.tutorialSeen = false` and fires `TutorialSync` with `{seen=false}` so the tutorial overlay appears immediately on the same session.

### Panel anatomy

```
⚙️ SettingsBtn  (top-right, X=0.935 Y=0.01, 0.055×0.055)
│
└── SettingsPanel (slides in from right)
    ├── Title: "Settings ⚙️"
    ├── ── BGM ──
    │   ├── Label "Background Music"
    │   └── Toggle button  [ON] / [OFF]
    ├── ── SFX ──
    │   ├── Label "Sound Effects"
    │   ├── Slider track (TextButton grid 0–10 → maps to 0.0–1.0)
    │   └── Volume % label
    ├── ── Graphics ──
    │   ├── Label "Quality"
    │   └── 3-button row: [Low] [Med] [High]
    ├── ── Tutorial ──
    │   └── [Replay Tutorial] button
    └── [Close] button (bottom)
```

Tab button: white ⚙️ on Propolis Brown background, same style as other tabs.

Panel: slides from right edge (X=1.05 → X=0.58), 0.40×0.68 size, same Propolis Brown + Honey Gold stroke as other panels.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DataService` | No change needed (settings are client-side) |
| `TutorialService` | Add `TutorialReset` RF handler |
| `SettingsController` (new LocalScript) | ⚙️ tab, panel, BGM/SFX/quality controls, tutorial reset |

---

## STEP A — TutorialService: add TutorialReset RF

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

-- Create TutorialReset RemoteFunction
local rf = Instance.new("RemoteFunction")
rf.Name   = "TutorialReset"
rf.Parent = RS

-- Patch TutorialService to handle it
local svc = SSS:FindFirstChild("TutorialService")
assert(svc, "TutorialService not found")

local clone = svc:Clone()
clone.Name = "TutorialService_WORKING"

-- Inject TutorialReset handler after TutorialComplete.OnServerInvoke block
local anchor = 'return TutorialService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "return TutorialService not found")
local injection = [[

local TutorialReset = RS:WaitForChild("TutorialReset")
TutorialReset.OnServerInvoke = function(player: Player): boolean
	local profile = DataService.GetProfile(player)
	if not profile then return false end
	profile.tutorialSeen = false
	TutorialSync:FireClient(player, {seen = false})
	return true
end

]]
clone.Source = clone.Source:sub(1, found - 1) .. injection .. clone.Source:sub(found)

svc.Name = "TutorialService_OLD_NX"
svc.Parent = nil
clone.Name = "TutorialService"
clone.Parent = SSS

print("TutorialService TutorialReset RF injected")
```

---

## STEP B — SettingsController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "SettingsController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- SettingsController — in-game settings panel (BGM, SFX, quality, tutorial reset)

local PS             = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local TweenService   = game:GetService("TweenService")
local CS             = game:GetService("CollectionService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TutorialReset = RS:WaitForChild("TutorialReset")

local PROP_BROWN  = Color3.fromRGB(80,  50, 20)
local HONEY_GOLD  = Color3.fromRGB(242, 168, 28)
local WAX_CREAM   = Color3.fromRGB(232, 212, 154)
local BTN_ACTIVE  = Color3.fromRGB(200, 140, 20)
local BTN_IDLE    = Color3.fromRGB(60,  38, 15)
local PANEL_OPEN  = UDim2.new(0.58, 0, 0.10, 0)
local PANEL_CLOSE = UDim2.new(1.05, 0, 0.10, 0)
local TWEEN_OPEN  = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.In)

-- ── Persistent prefs ──────────────────────────────────────────────
local function getPref(key: string, default: any): any
	local ok, v = pcall(function() return player:GetAttribute("pref_" .. key) end)
	if ok and v ~= nil then return v end
	return default
end
local function setPref(key: string, value: any)
	pcall(function() player:SetAttribute("pref_" .. key, value) end)
end

local bgmOn:    boolean = getPref("bgmOn",    true)
local sfxVol:   number  = getPref("sfxVol",   0.6)
local quality:  number  = getPref("quality",  2)   -- 1=Low 2=Med 3=High

-- ── Apply audio to tagged sounds ─────────────────────────────────
local function applyBGM()
	for _, s in CS:GetTagged("BGM") do
		if s:IsA("Sound") then s.Volume = bgmOn and 0.35 or 0 end
	end
end
local function applySFX()
	for _, s in CS:GetTagged("SFX") do
		if s:IsA("Sound") then s.Volume = sfxVol end
	end
end
local function applyQuality()
	-- 1=Auto(3) 2=Auto(5) 3=Auto(7) mapped from 1-3 setting
	local levels = {3, 5, 7}
	pcall(function()
		UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting["QualityLevel" .. levels[quality]]
	end)
end

applyBGM(); applySFX(); applyQuality()

-- ── Build GUI ────────────────────────────────────────────────────
local sg = Instance.new("ScreenGui")
sg.Name           = "SettingsGui"
sg.ResetOnSpawn   = false
sg.DisplayOrder   = 28
sg.IgnoreGuiInset = false
sg.Parent         = playerGui

-- Tab button (⚙️)
local tabBtn = Instance.new("TextButton")
tabBtn.Name              = "SettingsTab"
tabBtn.Size              = UDim2.new(0.055, 0, 0.055, 0)
tabBtn.Position          = UDim2.new(0.935, 0, 0.01, 0)
tabBtn.BackgroundColor3  = PROP_BROWN
tabBtn.BorderSizePixel   = 0
tabBtn.Text              = "⚙️"
tabBtn.TextScaled        = true
tabBtn.Font              = Enum.Font.Gotham
tabBtn.TextColor3        = WAX_CREAM
tabBtn.ZIndex            = 20
tabBtn.Parent            = sg
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15,0); c.Parent = tabBtn end
do local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 2; s.Parent = tabBtn end

-- Panel
local panel = Instance.new("Frame")
panel.Name             = "SettingsPanel"
panel.Size             = UDim2.new(0.40, 0, 0.68, 0)
panel.Position         = PANEL_CLOSE
panel.BackgroundColor3 = PROP_BROWN
panel.BorderSizePixel  = 0
panel.ZIndex           = 21
panel.Visible          = false
panel.Parent           = sg
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.03,0); c.Parent = panel end
do local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 3; s.Parent = panel end

local panelOpen = false
local function openPanel()
	panel.Visible = true
	TweenService:Create(panel, TWEEN_OPEN, {Position = PANEL_OPEN}):Play()
	panelOpen = true
end
local function closePanel()
	local tw = TweenService:Create(panel, TWEEN_CLOSE, {Position = PANEL_CLOSE})
	tw:Play()
	tw.Completed:Connect(function() panel.Visible = false end)
	panelOpen = false
end

tabBtn.MouseButton1Click:Connect(function()
	if panelOpen then closePanel() else openPanel() end
end)

-- ── Panel contents ───────────────────────────────────────────────
local yOffset = 0.04

local function makeLabel(text: string, yPos: number, size: number?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size              = UDim2.new(0.90, 0, size or 0.08, 0)
	lbl.Position          = UDim2.new(0.05, 0, yPos, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = text
	lbl.TextColor3        = WAX_CREAM
	lbl.TextScaled        = true
	lbl.Font              = Enum.Font.GothamBold
	lbl.TextXAlignment    = Enum.TextXAlignment.Left
	lbl.ZIndex            = 22
	lbl.Parent            = panel
	return lbl
end

local function makeSectionDivider(yPos: number)
	local f = Instance.new("Frame")
	f.Size              = UDim2.new(0.90, 0, 0.005, 0)
	f.Position          = UDim2.new(0.05, 0, yPos, 0)
	f.BackgroundColor3  = HONEY_GOLD
	f.BackgroundTransparency = 0.5
	f.BorderSizePixel   = 0
	f.ZIndex            = 22
	f.Parent            = panel
end

-- Title
local title = Instance.new("TextLabel")
title.Size              = UDim2.new(0.90, 0, 0.09, 0)
title.Position          = UDim2.new(0.05, 0, 0.02, 0)
title.BackgroundTransparency = 1
title.Text              = "Settings ⚙️"
title.TextColor3        = HONEY_GOLD
title.TextScaled        = true
title.Font              = Enum.Font.FredokaOne
title.ZIndex            = 22
title.Parent            = panel

-- ── BGM toggle ───────────────────────────────────────────
makeSectionDivider(0.12)
makeLabel("Background Music", 0.14)

local bgmToggle = Instance.new("TextButton")
bgmToggle.Size             = UDim2.new(0.40, 0, 0.08, 0)
bgmToggle.Position         = UDim2.new(0.55, 0, 0.13, 0)
bgmToggle.BackgroundColor3 = bgmOn and BTN_ACTIVE or BTN_IDLE
bgmToggle.Text             = bgmOn and "ON 🔊" or "OFF 🔇"
bgmToggle.TextColor3       = WAX_CREAM
bgmToggle.TextScaled       = true
bgmToggle.Font             = Enum.Font.GothamBold
bgmToggle.ZIndex           = 22
bgmToggle.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.25,0); c.Parent = bgmToggle end

bgmToggle.MouseButton1Click:Connect(function()
	bgmOn = not bgmOn
	setPref("bgmOn", bgmOn)
	bgmToggle.BackgroundColor3 = bgmOn and BTN_ACTIVE or BTN_IDLE
	bgmToggle.Text = bgmOn and "ON 🔊" or "OFF 🔇"
	applyBGM()
end)

-- ── SFX volume slider ────────────────────────────────────
makeSectionDivider(0.24)
makeLabel("Sound Effects", 0.26)

local sfxPct = math.floor(sfxVol * 100)
local sfxValLbl = Instance.new("TextLabel")
sfxValLbl.Size             = UDim2.new(0.20, 0, 0.07, 0)
sfxValLbl.Position         = UDim2.new(0.75, 0, 0.35, 0)
sfxValLbl.BackgroundTransparency = 1
sfxValLbl.Text             = sfxPct .. "%"
sfxValLbl.TextColor3       = HONEY_GOLD
sfxValLbl.TextScaled       = true
sfxValLbl.Font             = Enum.Font.GothamBold
sfxValLbl.ZIndex           = 22
sfxValLbl.Parent           = panel

-- Slider: 5 segments (0, 25, 50, 75, 100)
local sliderTrack = Instance.new("Frame")
sliderTrack.Size             = UDim2.new(0.68, 0, 0.07, 0)
sliderTrack.Position         = UDim2.new(0.05, 0, 0.35, 0)
sliderTrack.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
sliderTrack.BorderSizePixel  = 0
sliderTrack.ZIndex           = 22
sliderTrack.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5,0); c.Parent = sliderTrack end

local sliderFill = Instance.new("Frame")
sliderFill.Name             = "Fill"
sliderFill.Size             = UDim2.new(sfxVol, 0, 1, 0)
sliderFill.Position         = UDim2.new(0, 0, 0, 0)
sliderFill.BackgroundColor3 = HONEY_GOLD
sliderFill.BorderSizePixel  = 0
sliderFill.ZIndex           = 23
sliderFill.Parent           = sliderTrack
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5,0); c.Parent = sliderFill end

-- Click on track to set volume in 5 steps
local sfxBtn = Instance.new("TextButton")
sfxBtn.Size              = UDim2.new(1, 0, 1, 0)
sfxBtn.BackgroundTransparency = 1
sfxBtn.Text              = ""
sfxBtn.ZIndex            = 24
sfxBtn.Parent            = sliderTrack

sfxBtn.MouseButton1Click:Connect(function()
	-- cycle through 0, 25, 50, 75, 100
	local steps = {0, 0.25, 0.50, 0.75, 1.0}
	local nextIdx = 1
	for i, v in steps do
		if sfxVol < v then nextIdx = i; break end
		if i == #steps then nextIdx = 1 end
	end
	sfxVol = steps[nextIdx]
	setPref("sfxVol", sfxVol)
	sliderFill.Size = UDim2.new(sfxVol, 0, 1, 0)
	sfxValLbl.Text = math.floor(sfxVol * 100) .. "%"
	applySFX()
end)

-- ── Quality toggle ───────────────────────────────────────
makeSectionDivider(0.45)
makeLabel("Graphics Quality", 0.47)

local qualityLabels = {"Low", "Med", "High"}
local qualityBtns: {TextButton} = {}
for i, lbl in qualityLabels do
	local qb = Instance.new("TextButton")
	qb.Size             = UDim2.new(0.28, 0, 0.08, 0)
	qb.Position         = UDim2.new(0.03 + (i-1)*0.31, 0, 0.57, 0)
	qb.BackgroundColor3 = (quality == i) and BTN_ACTIVE or BTN_IDLE
	qb.Text             = lbl
	qb.TextColor3       = WAX_CREAM
	qb.TextScaled       = true
	qb.Font             = Enum.Font.GothamBold
	qb.ZIndex           = 22
	qb.Parent           = panel
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2,0); c.Parent = qb end
	qualityBtns[i] = qb
end

for i, qb in qualityBtns do
	qb.MouseButton1Click:Connect(function()
		quality = i
		setPref("quality", quality)
		for j, b in qualityBtns do
			b.BackgroundColor3 = (j == quality) and BTN_ACTIVE or BTN_IDLE
		end
		applyQuality()
	end)
end

-- ── Replay Tutorial ──────────────────────────────────────
makeSectionDivider(0.68)

local replayBtn = Instance.new("TextButton")
replayBtn.Size             = UDim2.new(0.88, 0, 0.09, 0)
replayBtn.Position         = UDim2.new(0.06, 0, 0.71, 0)
replayBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
replayBtn.Text             = "Replay Tutorial 🐝"
replayBtn.TextColor3       = WAX_CREAM
replayBtn.TextScaled       = true
replayBtn.Font             = Enum.Font.GothamBold
replayBtn.ZIndex           = 22
replayBtn.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15,0); c.Parent = replayBtn end
do local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(100,200,100); s.Thickness = 2; s.Parent = replayBtn end

replayBtn.MouseButton1Click:Connect(function()
	replayBtn.Text = "Starting..."
	replayBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
	local ok = pcall(function() TutorialReset:InvokeServer() end)
	task.wait(1)
	replayBtn.Text = ok and "Replay Tutorial 🐝" or "Error — try again"
	replayBtn.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
	closePanel()
end)

-- ── Close button ─────────────────────────────────────────
local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0.88, 0, 0.08, 0)
closeBtn.Position         = UDim2.new(0.06, 0, 0.89, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
closeBtn.Text             = "Close ✕"
closeBtn.TextColor3       = WAX_CREAM
closeBtn.TextScaled       = true
closeBtn.Font             = Enum.Font.Gotham
closeBtn.ZIndex           = 22
closeBtn.Parent           = panel
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2,0); c.Parent = closeBtn end

closeBtn.MouseButton1Click:Connect(function() closePanel() end)
]]

print("SettingsController created")
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local svc = SSS:FindFirstChild("TutorialService")
table.insert(checks, (svc and svc.Source:find("TutorialReset") and "✅" or "❌") .. " TutorialService TutorialReset handler")

local rf = RS:FindFirstChild("TutorialReset")
table.insert(checks, (rf and rf:IsA("RemoteFunction") and "✅" or "❌") .. " TutorialReset RemoteFunction in RS")

local ctrl = SPS and SPS:FindFirstChild("SettingsController")
table.insert(checks, (ctrl and "✅" or "❌") .. " SettingsController LocalScript")

print("=== DISPATCH 67 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 67 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 67 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- Settings are stored as `LocalPlayer` attributes (`pref_bgmOn`, `pref_sfxVol`, `pref_quality`) — persists across respawns within the same session. Across sessions players re-choose; this is intentional (no DataStore call needed for cosmetic prefs).
- BGM sounds must be tagged `BGM` via CollectionService (done by MusicService when added). SFX sounds must be tagged `SFX`. Until then, applyBGM/applySFX iterate over empty sets gracefully.
- The SFX slider uses a tap-to-cycle pattern (0→25→50→75→100→0) rather than a draggable slider to avoid mobile drag events which are unreliable in Roblox ScreenGuis without additional InputChanged handling.
- `TutorialReset` RF clears `tutorialSeen` server-side and immediately fires `TutorialSync {seen=false}` so the tutorial overlay appears in the same session without rejoin.
- Quality mapping: Low→QualityLevel3, Med→QualityLevel5, High→QualityLevel7 (Roblox enum values for common mid-range presets; doesn't affect server).
- Panel position `X=0.58` keeps it left of the right-column tabs (X=0.925) and avoids covering leaderboard/prestige panels (which open to the left from X=0.925).
- SettingsTab sits at X=0.935 Y=0.01 — above the top right-column tab (Y=0.28) so no overlap.
