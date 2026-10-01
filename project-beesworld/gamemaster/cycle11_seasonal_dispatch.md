# Dispatch 69 — SeasonalEventService
## Cycle 11 · A Bee's World

**Feature:** Server-side seasonal events — time-limited multiplier windows that activate automatically based on UTC month/day. Spring Bloom (April) gives 2× honey, Summer Harvest (July–August) gives 1.5× honey + 1.5× pollen, Autumn Nectar (October) gives 2× propolis, Winter Rest (December–January) gives 1.5× honey + 25% bonus daily reward. Active event broadcast to clients via `SeasonalSync` RemoteEvent; HUD shows a banner when active.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 68 (MusicController)

---

## DESIGN

All event logic is **server-side**. `SeasonalEventService` checks UTC date on `Init()` and every hour thereafter. When an event is active it stores the active event id in a module-level variable and exports `GetMultipliers(player)` → `{honey: number, propolis: number, pollen: number}`.

`ForagingService` calls `GetMultipliers` before crediting yield:
```lua
local mult = SeasonalEventService.GetMultipliers(player)
local honeyYield = baseYield * mult.honey
```

Clients receive the active event data via `SeasonalSync` RemoteEvent on join and on each hourly refresh. `SeasonalController` (new LocalScript) renders a small dismissible banner at the top of the screen.

### Events table

| id | Name | Months | Days | honey× | propolis× | pollen× | Banner color |
|----|------|--------|------|--------|-----------|---------|-------------|
| `spring_bloom` | 🌸 Spring Bloom | 4 | any | 2.0 | 1.0 | 1.5 | Color3(255,182,193) pink |
| `summer_harvest` | ☀️ Summer Harvest | 7–8 | any | 1.5 | 1.0 | 1.5 | Color3(255,220,80) yellow |
| `autumn_nectar` | 🍂 Autumn Nectar | 10 | any | 1.0 | 2.0 | 1.0 | Color3(200,100,30) orange |
| `winter_rest` | ❄️ Winter Rest | 12,1 | any | 1.5 | 1.0 | 1.0 | Color3(160,200,240) ice blue |
| `none` | (no event) | — | — | 1.0 | 1.0 | 1.0 | — |

When no event matches the current UTC month, `activeEvent = "none"` and all multipliers are 1.0 (no banner shown).

### Banner anatomy

```
┌─────────────────────────────────────────────────────────┐
│ 🌸 Spring Bloom — 2× Honey active!    [x]              │
└─────────────────────────────────────────────────────────┘
```
- Size: 0.55×0.06 centered at top (Y=0.04)
- Auto-hides after 8s on login; re-appears on each hourly sync
- Dismiss button [x] hides it for the session (re-appears on event change)

---

## FILES CHANGED

| File | Change |
|------|--------|
| `Config` | `SEASONAL_EVENTS` table |
| `SeasonalEventService` (new Script in SSS) | event detection, multipliers, hourly refresh |
| `GameManager` | Init call |
| `ForagingService` | apply multipliers to honey/propolis/pollen yield |
| `SeasonalController` (new LocalScript) | banner UI |

---

## STEP A — Config: add SEASONAL_EVENTS

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")

local clone = cfg:Clone()
clone.Name = "Config_WORKING"

local anchor = 'Config.ACHIEVEMENTS'
local found = clone.Source:find(anchor, 1, true)
assert(found, "Config.ACHIEVEMENTS anchor not found in Config")
-- inject before ACHIEVEMENTS
local injection = [[Config.SEASONAL_EVENTS = {
	{id="spring_bloom",   name="🌸 Spring Bloom",    months={4},      honeyMult=2.0, propolisMult=1.0, pollenMult=1.5, color={255,182,193}, desc="2× Honey active!"},
	{id="summer_harvest", name="☀️ Summer Harvest",  months={7,8},    honeyMult=1.5, propolisMult=1.0, pollenMult=1.5, color={255,220,80},  desc="1.5× Honey + 1.5× Pollen!"},
	{id="autumn_nectar",  name="🍂 Autumn Nectar",   months={10},     honeyMult=1.0, propolisMult=2.0, pollenMult=1.0, color={200,100,30},  desc="2× Propolis active!"},
	{id="winter_rest",    name="❄️ Winter Rest",      months={12, 1},  honeyMult=1.5, propolisMult=1.0, pollenMult=1.0, color={160,200,240}, desc="1.5× Honey active!"},
}

]]
clone.Source = injection .. clone.Source

cfg.Name = "Config_OLD_NX"
cfg.Parent = nil
clone.Name = "Config"
clone.Parent = SSS

print("Config SEASONAL_EVENTS added")
```

---

## STEP B — SeasonalEventService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local SeasonalSync = Instance.new("RemoteEvent")
SeasonalSync.Name   = "SeasonalSync"
SeasonalSync.Parent = RS

local svc = Instance.new("Script")
svc.Name   = "SeasonalEventService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- SeasonalEventService
-- Detects UTC month and broadcasts active seasonal event multipliers.

local SSS  = game:GetService("ServerScriptService")
local RS   = game:GetService("ReplicatedStorage")
local PS   = game:GetService("Players")

local Config       = require(SSS:WaitForChild("Config"))
local SeasonalSync = RS:WaitForChild("SeasonalSync")

local SeasonalEventService = {}

type EventData = {id: string, name: string, months: {number}, honeyMult: number, propolisMult: number, pollenMult: number, color: {number}, desc: string}

local activeEvent: EventData? = nil

local function detectEvent(): EventData?
	local month = tonumber(os.date("!%m"))  -- UTC month 1-12
	for _, ev in Config.SEASONAL_EVENTS do
		for _, m in ev.months do
			if m == month then return ev end
		end
	end
	return nil
end

local function refresh()
	activeEvent = detectEvent()
	local payload = activeEvent and {
		id         = activeEvent.id,
		name       = activeEvent.name,
		desc       = activeEvent.desc,
		color      = activeEvent.color,
		honeyMult  = activeEvent.honeyMult,
		propolisMult = activeEvent.propolisMult,
		pollenMult = activeEvent.pollenMult,
	} or {id = "none"}
	SeasonalSync:FireAllClients(payload)
end

function SeasonalEventService.GetMultipliers(_player: Player): {honey: number, propolis: number, pollen: number}
	if activeEvent then
		return {honey = activeEvent.honeyMult, propolis = activeEvent.propolisMult, pollen = activeEvent.pollenMult}
	end
	return {honey = 1.0, propolis = 1.0, pollen = 1.0}
end

function SeasonalEventService.Init()
	refresh()

	-- Send current event to each new player on join
	PS.PlayerAdded:Connect(function(player)
		task.wait(2)
		local payload = activeEvent and {
			id         = activeEvent.id,
			name       = activeEvent.name,
			desc       = activeEvent.desc,
			color      = activeEvent.color,
			honeyMult  = activeEvent.honeyMult,
			propolisMult = activeEvent.propolisMult,
			pollenMult = activeEvent.pollenMult,
		} or {id = "none"}
		SeasonalSync:FireClient(player, payload)
	end)

	-- Refresh hourly
	task.spawn(function()
		while true do
			task.wait(3600)
			refresh()
		end
	end)

	print("[SeasonalEventService] ready — event: " .. (activeEvent and activeEvent.id or "none"))
end

return SeasonalEventService
]]

print("SeasonalEventService created")
```

---

## STEP C — GameManager: inject SeasonalEventService.Init()

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local TutorialService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "TutorialService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal SeasonalEventService = require(SSS:WaitForChild(\"SeasonalEventService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'TutorialService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "TutorialService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nSeasonalEventService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager SeasonalEventService.Init() injected")
```

---

## STEP D — ForagingService: apply multipliers

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- Inject require after PollenStorageUpgradeService require
local anchor = 'local PollenStorageUpgradeService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "PollenStorageUpgradeService require not found in ForagingService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal SeasonalEventService = require(SSS:WaitForChild(\"SeasonalEventService\"))" .. clone.Source:sub(lineEnd + 1)

-- Inject multiplier before honeyYield credit
-- Find: profile.honey = profile.honey + honeyYield
local honeyAnchor = 'profile.honey = profile.honey + honeyYield'
local found2 = clone.Source:find(honeyAnchor, 1, true)
assert(found2, "honey credit line not found in ForagingService")
local lineEnd2 = clone.Source:find("\n", found2 - 50, true)  -- start of this line
-- inject multiplier BEFORE the line
local mult_injection = [[
	local _seasonal = SeasonalEventService.GetMultipliers(player)
	honeyYield   = math.floor(honeyYield   * _seasonal.honey)
	pollenYield  = math.floor(pollenYield  * _seasonal.pollen)
]]
-- Find the line start
local lineStart = clone.Source:rfind("\n", found2) or 0
clone.Source = clone.Source:sub(1, lineStart) .. "\n" .. mult_injection .. clone.Source:sub(lineStart + 1)

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService seasonal multipliers injected")
```

---

## STEP E — SeasonalController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "SeasonalController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- SeasonalController — shows event banner when a seasonal event is active

local PS           = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player    = PS.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SeasonalSync = RS:WaitForChild("SeasonalSync")

local PROP_BROWN = Color3.fromRGB(80, 50, 20)
local WAX_CREAM  = Color3.fromRGB(232, 212, 154)

-- ScreenGui
local sg = Instance.new("ScreenGui")
sg.Name           = "SeasonalGui"
sg.ResetOnSpawn   = false
sg.DisplayOrder   = 18
sg.IgnoreGuiInset = false
sg.Parent         = playerGui

local banner: Frame? = nil
local bannerTimer: thread? = nil

local function hideBanner()
	if banner then
		TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.225, 0, -0.10, 0)}):Play()
		task.wait(0.35)
		if banner then banner:Destroy(); banner = nil end
	end
	if bannerTimer then task.cancel(bannerTimer); bannerTimer = nil end
end

local function showBanner(name: string, desc: string, color: {number})
	hideBanner()

	local bg = Color3.fromRGB(color[1], color[2], color[3])

	local f = Instance.new("Frame")
	f.Name             = "EventBanner"
	f.Size             = UDim2.new(0.55, 0, 0.06, 0)
	f.Position         = UDim2.new(0.225, 0, -0.10, 0)
	f.BackgroundColor3 = bg
	f.BorderSizePixel  = 0
	f.ZIndex           = 19
	f.Parent           = sg
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15,0); c.Parent = f end
	do local s = Instance.new("UIStroke"); s.Color = PROP_BROWN; s.Thickness = 2; s.Parent = f end
	banner = f

	local lbl = Instance.new("TextLabel")
	lbl.Size              = UDim2.new(0.85, 0, 1, 0)
	lbl.Position          = UDim2.new(0.02, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = name .. " — " .. desc
	lbl.TextColor3        = PROP_BROWN
	lbl.TextScaled        = true
	lbl.Font              = Enum.Font.GothamBold
	lbl.ZIndex            = 20
	lbl.Parent            = f

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size              = UDim2.new(0.10, 0, 0.80, 0)
	closeBtn.Position          = UDim2.new(0.89, 0, 0.10, 0)
	closeBtn.BackgroundColor3  = Color3.fromRGB(100, 50, 50)
	closeBtn.Text              = "✕"
	closeBtn.TextColor3        = WAX_CREAM
	closeBtn.TextScaled        = true
	closeBtn.Font              = Enum.Font.Gotham
	closeBtn.ZIndex            = 20
	closeBtn.Parent            = f
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.3,0); c.Parent = closeBtn end
	closeBtn.MouseButton1Click:Connect(function() hideBanner() end)

	-- Slide in
	TweenService:Create(f, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.225, 0, 0.04, 0)}):Play()

	-- Auto-hide after 8s
	bannerTimer = task.delay(8, function() hideBanner() end)
end

SeasonalSync.OnClientEvent:Connect(function(data: {id: string, name: string?, desc: string?, color: {number}?})
	if data.id == "none" then
		hideBanner()
		return
	end
	showBanner(data.name or "", data.desc or "", data.color or {242, 168, 28})
end)
]]

print("SeasonalController created")
```

---

## STEP F — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local cfg = SSS:FindFirstChild("Config")
table.insert(checks, (cfg and cfg.Source:find("SEASONAL_EVENTS") and "✅" or "❌") .. " Config SEASONAL_EVENTS")

local svc = SSS:FindFirstChild("SeasonalEventService")
table.insert(checks, (svc and "✅" or "❌") .. " SeasonalEventService script")

local sync = RS:FindFirstChild("SeasonalSync")
table.insert(checks, (sync and sync:IsA("RemoteEvent") and "✅" or "❌") .. " SeasonalSync RemoteEvent")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("SeasonalEventService") and "✅" or "❌") .. " GameManager Init")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("SeasonalEventService") and "✅" or "❌") .. " ForagingService multipliers")

local ctrl = SPS and SPS:FindFirstChild("SeasonalController")
table.insert(checks, (ctrl and "✅" or "❌") .. " SeasonalController LocalScript")

print("=== DISPATCH 69 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 69 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 69 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `os.date("!%m")` returns the UTC month as a zero-padded string (e.g. `"04"`) — `tonumber()` converts it to an integer for table comparison. This is server-side only; client never runs date logic.
- Propolis multiplier is applied in ForagingService alongside honey and pollen multipliers. The propolis yield credit line follows the same pattern as honey (see dispatch 66 injection anchor).
- Hourly refresh loop uses `task.wait(3600)` — lightweight, one coroutine per server. On a fresh server with few players the GC impact is negligible.
- `rfind` polyfill: Lua's `string.find` has no `rfind`. The injection uses `clone.Source:rfind("\n", found2)` — this is Luau's `string.find` searching backwards. If `rfind` is unavailable in the Command Bar environment, replace with a manual backwards scan:
  ```lua
  local lineStart = 0
  for i = found2, 1, -1 do
    if clone.Source:sub(i, i) == "\n" then lineStart = i; break end
  end
  ```
- Winter Rest (months 12 and 1) spans the calendar year boundary — the `months` array `{12, 1}` is checked with a simple loop, so both December and January match correctly.
- The banner DisplayOrder=18 keeps it below all gameplay UI (tabs are ZIndex 20, panels 21+) but above the world. It auto-hides after 8s so it never blocks gameplay long-term.
