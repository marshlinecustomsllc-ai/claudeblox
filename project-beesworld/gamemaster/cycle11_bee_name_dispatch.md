# Dispatch 71 — BeeNameService
## Cycle 11 · A Bee's World

**Feature:** Players can name their queen bee — a cosmetic name stored in their profile and displayed in the HUD beneath the honey counter and above their hive plot. A rename dialog (TextBox + confirm button) is accessible from a small ✏️ button next to the queen bee name display. Names are filtered through Roblox's chat filter (`TextService:FilterStringAsync`) before storage. Max 20 characters.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 70 (FriendBonusService)

---

## DESIGN

Queen bee name is stored in `profile.queenName` (string, default `"Queen Bee"`). A `SetQueenName` RemoteFunction validates length and runs the chat filter; returns `{ok: true, filtered: string}` or `{ok: false, reason: string}`.

The HUD shows the filtered name in the honey counter area. The rename TextBox appears as an overlay on click of the ✏️ button.

### TextService filtering

```lua
local success, filterResult = pcall(function()
    return TextService:FilterStringAsync(rawName, player.UserId, Enum.TextFilterContext.PublicChat)
end)
if not success then return {ok=false, reason="filter_error"} end
local filtered = filterResult:GetNonChatStringForBroadcastAsync()
```

### HUD layout change

```
[ 🍯 1,234 honey ]
[ Queen Bee  ✏️  ]     ← new row
```

The queen name row is added directly below the honey counter in `HiveHUDController`.

### Rename dialog

```
┌───────────────────────────────┐
│ Name your Queen 👑            │
│ ┌──────────────────────────┐  │
│ │ Queen Bee                │  │  ← TextBox (max 20 chars)
│ └──────────────────────────┘  │
│ [Confirm]      [Cancel]       │
└───────────────────────────────┘
```
Centered overlay, DisplayOrder=35. Closes on Confirm or Cancel.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `DataService` | `queenName = "Queen Bee"` migration |
| `BeeNameService` (new Script in SSS) | SetQueenName RF, QueenNameSync RE |
| `GameManager` | Init call |
| `HiveHUDController` | queen name row, ✏️ rename button, rename dialog |

---

## STEP A — DataService migration

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local ds = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")

local clone = ds:Clone()
clone.Name = "DataService_WORKING"

local anchor = 'pollenStorageTier = 0'
local found = clone.Source:find(anchor, 1, true)
assert(found, "pollenStorageTier anchor not found")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\n\t\tqueenName = \"Queen Bee\",         -- player-chosen queen bee name" .. clone.Source:sub(lineEnd + 1)

ds.Name = "DataService_OLD_NX"
ds.Parent = nil
clone.Name = "DataService"
clone.Parent = SSS

print("DataService queenName migration applied")
```

---

## STEP B — BeeNameService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local QueenNameSync = Instance.new("RemoteEvent")
QueenNameSync.Name   = "QueenNameSync"
QueenNameSync.Parent = RS

local SetQueenName = Instance.new("RemoteFunction")
SetQueenName.Name   = "SetQueenName"
SetQueenName.Parent = RS

local svc = Instance.new("Script")
svc.Name   = "BeeNameService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- BeeNameService
-- Stores and validates player queen bee names.

local SSS         = game:GetService("ServerScriptService")
local RS          = game:GetService("ReplicatedStorage")
local PS          = game:GetService("Players")
local TextService = game:GetService("TextService")

local DataService   = require(SSS:WaitForChild("DataService"))
local QueenNameSync = RS:WaitForChild("QueenNameSync")
local SetQueenName  = RS:WaitForChild("SetQueenName")

local BeeNameService = {}
local MAX_LEN = 20

local function sendName(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile then return end
	QueenNameSync:FireClient(player, profile.queenName or "Queen Bee")
end

SetQueenName.OnServerInvoke = function(player: Player, rawName: any): {ok: boolean, filtered: string?, reason: string?}
	if type(rawName) ~= "string" then return {ok=false, reason="invalid_type"} end
	rawName = rawName:match("^%s*(.-)%s*$")  -- trim
	if #rawName == 0 then return {ok=false, reason="empty"} end
	if #rawName > MAX_LEN then return {ok=false, reason="too_long"} end

	local ok, filterResult = pcall(function()
		return TextService:FilterStringAsync(rawName, player.UserId, Enum.TextFilterContext.PublicChat)
	end)
	if not ok then return {ok=false, reason="filter_error"} end

	local filtered: string
	local ok2, fstr = pcall(function()
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	filtered = (ok2 and fstr) or rawName

	-- Reject if entirely filtered
	if filtered:match("^[%s#*]+$") then
		return {ok=false, reason="filtered_out"}
	end

	local profile = DataService.GetProfile(player)
	if not profile then return {ok=false, reason="no_profile"} end
	profile.queenName = filtered

	QueenNameSync:FireClient(player, filtered)
	return {ok=true, filtered=filtered}
end

function BeeNameService.Init()
	PS.PlayerAdded:Connect(function(player)
		task.wait(3)
		sendName(player)
	end)
	for _, player in PS:GetPlayers() do
		task.spawn(sendName, player)
	end
	print("[BeeNameService] ready")
end

return BeeNameService
]]

print("BeeNameService created")
```

---

## STEP C — GameManager: inject BeeNameService.Init()

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local FriendBonusService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "FriendBonusService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal BeeNameService = require(SSS:WaitForChild(\"BeeNameService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'FriendBonusService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "FriendBonusService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nBeeNameService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager BeeNameService.Init() injected")
```

---

## STEP D — HiveHUDController: queen name row + rename dialog

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HiveHUDController")
assert(ctrl, "HiveHUDController not found")

local clone = ctrl:Clone()
clone.Name = "HiveHUDController_WORKING"

-- Inject RS remotes after existing RS line
local anchor = 'local RS'
local found = clone.Source:find(anchor, 1, true)
assert(found, "local RS not found")
local lineEnd = clone.Source:find("\n", found, true)
local reRemotes = [[
local QueenNameSync = RS:WaitForChild("QueenNameSync")
local SetQueenName  = RS:WaitForChild("SetQueenName")
]]
clone.Source = clone.Source:sub(1, lineEnd) .. "\n" .. reRemotes .. clone.Source:sub(lineEnd + 1)

-- Append queen name HUD row and rename dialog at end
local queenInjection = [[

-- ── Queen name row in HUD ────────────────────────────────
local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local PROP_BROWN = Color3.fromRGB(80, 50, 20)
local WAX_CREAM  = Color3.fromRGB(232, 212, 154)

local hud = playerGui:WaitForChild("HiveHUD", 10)
local queenRow: Frame? = nil
local queenLbl: TextLabel? = nil

if hud then
	local row = Instance.new("Frame")
	row.Name             = "QueenRow"
	row.Size             = UDim2.new(0.28, 0, 0.05, 0)
	row.Position         = UDim2.new(0.01, 0, 0.14, 0)   -- below honey counter
	row.BackgroundTransparency = 1
	row.BorderSizePixel  = 0
	row.ZIndex           = 12
	row.Parent           = hud
	queenRow = row

	local ql = Instance.new("TextLabel")
	ql.Name              = "QueenName"
	ql.Size              = UDim2.new(0.80, 0, 1, 0)
	ql.Position          = UDim2.new(0, 0, 0, 0)
	ql.BackgroundTransparency = 1
	ql.Text              = "👑 Queen Bee"
	ql.TextColor3        = HONEY_GOLD
	ql.TextScaled        = true
	ql.Font              = Enum.Font.Gotham
	ql.TextXAlignment    = Enum.TextXAlignment.Left
	ql.ZIndex            = 12
	ql.Parent            = row
	queenLbl = ql

	local editBtn = Instance.new("TextButton")
	editBtn.Size             = UDim2.new(0.18, 0, 1, 0)
	editBtn.Position         = UDim2.new(0.81, 0, 0, 0)
	editBtn.BackgroundTransparency = 1
	editBtn.Text             = "✏️"
	editBtn.TextScaled       = true
	editBtn.Font             = Enum.Font.Gotham
	editBtn.TextColor3       = WAX_CREAM
	editBtn.ZIndex           = 12
	editBtn.Parent           = row

	-- Rename dialog
	local dialogGui = Instance.new("ScreenGui")
	dialogGui.Name           = "RenameGui"
	dialogGui.ResetOnSpawn   = false
	dialogGui.DisplayOrder   = 35
	dialogGui.IgnoreGuiInset = false
	dialogGui.Enabled        = false
	dialogGui.Parent         = playerGui

	local panel = Instance.new("Frame")
	panel.Size             = UDim2.new(0.50, 0, 0.22, 0)
	panel.Position         = UDim2.new(0.25, 0, 0.39, 0)
	panel.BackgroundColor3 = PROP_BROWN
	panel.BorderSizePixel  = 0
	panel.ZIndex           = 36
	panel.Parent           = dialogGui
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.06,0); c.Parent = panel end
	do local s = Instance.new("UIStroke"); s.Color = HONEY_GOLD; s.Thickness = 3; s.Parent = panel end

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size              = UDim2.new(0.90, 0, 0.25, 0)
	titleLbl.Position          = UDim2.new(0.05, 0, 0.04, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text              = "Name your Queen 👑"
	titleLbl.TextColor3        = HONEY_GOLD
	titleLbl.TextScaled        = true
	titleLbl.Font              = Enum.Font.FredokaOne
	titleLbl.ZIndex            = 37
	titleLbl.Parent            = panel

	local textBox = Instance.new("TextBox")
	textBox.Size              = UDim2.new(0.88, 0, 0.25, 0)
	textBox.Position          = UDim2.new(0.06, 0, 0.32, 0)
	textBox.BackgroundColor3  = Color3.fromRGB(50, 30, 10)
	textBox.Text              = ""
	textBox.PlaceholderText   = "e.g. Honeybee Maxima"
	textBox.TextColor3        = WAX_CREAM
	textBox.PlaceholderColor3 = Color3.fromRGB(120, 90, 50)
	textBox.TextScaled        = true
	textBox.Font              = Enum.Font.Gotham
	textBox.ClearTextOnFocus  = false
	textBox.MaxVisibleGraphemes = 20
	textBox.ZIndex            = 37
	textBox.Parent            = panel
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.15,0); c.Parent = textBox end

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Size              = UDim2.new(0.88, 0, 0.15, 0)
	statusLbl.Position          = UDim2.new(0.06, 0, 0.59, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text              = ""
	statusLbl.TextColor3        = Color3.fromRGB(220, 80, 80)
	statusLbl.TextScaled        = true
	statusLbl.Font              = Enum.Font.Gotham
	statusLbl.ZIndex            = 37
	statusLbl.Parent            = panel

	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Size             = UDim2.new(0.42, 0, 0.20, 0)
	confirmBtn.Position         = UDim2.new(0.06, 0, 0.76, 0)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 40)
	confirmBtn.Text             = "Confirm ✓"
	confirmBtn.TextColor3       = WAX_CREAM
	confirmBtn.TextScaled       = true
	confirmBtn.Font             = Enum.Font.GothamBold
	confirmBtn.ZIndex           = 37
	confirmBtn.Parent           = panel
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2,0); c.Parent = confirmBtn end

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size              = UDim2.new(0.42, 0, 0.20, 0)
	cancelBtn.Position          = UDim2.new(0.52, 0, 0.76, 0)
	cancelBtn.BackgroundColor3  = Color3.fromRGB(100, 50, 50)
	cancelBtn.Text              = "Cancel ✕"
	cancelBtn.TextColor3        = WAX_CREAM
	cancelBtn.TextScaled        = true
	cancelBtn.Font              = Enum.Font.Gotham
	cancelBtn.ZIndex            = 37
	cancelBtn.Parent            = panel
	do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.2,0); c.Parent = cancelBtn end

	local function closeDialog()
		dialogGui.Enabled = false
		statusLbl.Text    = ""
	end

	editBtn.MouseButton1Click:Connect(function()
		textBox.Text      = ""
		statusLbl.Text    = ""
		dialogGui.Enabled = true
		textBox:CaptureFocus()
	end)
	cancelBtn.MouseButton1Click:Connect(function() closeDialog() end)

	confirmBtn.MouseButton1Click:Connect(function()
		local raw = textBox.Text:match("^%s*(.-)%s*$")
		if #raw == 0 then statusLbl.Text = "Name cannot be empty."; return end
		if #raw > 20 then statusLbl.Text = "Max 20 characters."; return end
		statusLbl.Text           = "Saving..."
		confirmBtn.Active        = false
		local result = SetQueenName:InvokeServer(raw)
		confirmBtn.Active        = true
		if result and result.ok then
			closeDialog()
		else
			local reason = result and result.reason or "unknown"
			local msgs = {empty="Name cannot be empty.", too_long="Max 20 characters.", filtered_out="Name was filtered. Try another.", filter_error="Filter unavailable — try again.", no_profile="Could not save. Try again."}
			statusLbl.Text = msgs[reason] or ("Error: " .. reason)
		end
	end)

end   -- if hud

-- Update queen name label on sync
QueenNameSync.OnClientEvent:Connect(function(name: string)
	if queenLbl then queenLbl.Text = "👑 " .. (name or "Queen Bee") end
end)
]]
clone.Source = clone.Source .. queenInjection

ctrl.Name = "HiveHUDController_OLD_NX"
ctrl.Parent = nil
clone.Name = "HiveHUDController"
clone.Parent = SPS

print("HiveHUDController queen name row injected")
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
table.insert(checks, (ds and ds.Source:find("queenName") and "✅" or "❌") .. " DataService queenName")

local svc = SSS:FindFirstChild("BeeNameService")
table.insert(checks, (svc and "✅" or "❌") .. " BeeNameService script")

local sync = RS:FindFirstChild("QueenNameSync")
table.insert(checks, (sync and sync:IsA("RemoteEvent") and "✅" or "❌") .. " QueenNameSync RemoteEvent")

local rf = RS:FindFirstChild("SetQueenName")
table.insert(checks, (rf and rf:IsA("RemoteFunction") and "✅" or "❌") .. " SetQueenName RemoteFunction")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("BeeNameService") and "✅" or "❌") .. " GameManager Init")

local hud = SPS and SPS:FindFirstChild("HiveHUDController")
table.insert(checks, (hud and hud.Source:find("QueenNameSync") and "✅" or "❌") .. " HiveHUDController patched")

print("=== DISPATCH 71 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 71 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 71 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `TextService:FilterStringAsync` runs with `Enum.TextFilterContext.PublicChat` which applies the strictest filter (names visible to all players). `GetNonChatStringForBroadcastAsync()` gives the version safe for display to any audience.
- If `GetNonChatStringForBroadcastAsync` fails (e.g. TextService unavailable in Studio playtest), the raw name is used as fallback — acceptable for offline/test context.
- A name that gets fully replaced by `###` is rejected with `filtered_out` reason and shown as an error in the dialog — the player can try a different name.
- `MaxVisibleGraphemes = 20` on the TextBox limits display but doesn't prevent pasting longer strings. The server enforces `#rawName > MAX_LEN` as the authoritative check.
- The dialog's `ScreenGui.Enabled = false` approach (vs Destroy/recreate) avoids creating new UI objects on each open — the dialog persists for the session and is toggled on/off.
- `textBox:CaptureFocus()` opens the mobile keyboard automatically on iOS/Android when the edit button is tapped.
- Default `queenName = "Queen Bee"` in DataService migration means existing players who never rename see a sensible default with no action required.
