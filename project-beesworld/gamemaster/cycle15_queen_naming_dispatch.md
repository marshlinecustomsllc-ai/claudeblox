# Dispatch 163 — Queen Naming & Renaming Ceremony
**File:** `cycle15_queen_naming_dispatch.md`
**Branch:** add-beesworld-project
**Part budget:** +0 new world parts → 4,198 / 5,000

---

## Overview

Kids name everything. A named queen is *their* queen — not just "Queen Tier 2". Dispatch 163
gives every player a one-time queen naming ceremony when they first place a queen, and a
rename option any time after. The name appears on the plot's HiveGui Queen tab, on the small
hover label above the queen model, and in system notifications ("👑 Queen Beatrice joined
your hive!"). Adults get a character-count display and a Roblox chat-filter safeguard.

**What gets built:**
1. DataService v15→v16: `queenName` field (string, default `""`)
2. `QueenNamingController` LocalScript — naming popup, Roblox text filter via
   `TextService:FilterStringAsync`, rename button in HiveGui Queen tab
3. `QueenNameSync` RemoteEvent — client sends proposed name → server validates + saves →
   fires back confirmed name to all players on the same server (so their hover labels update)
4. Small hover label above QueenBee model in the world (BillboardGui)
5. +0 world parts (the BillboardGui is attached to an existing part, not a new one)

---

## Step 1 — DataService v15→v16

In DataService ModuleScript, add `queenName` to `PROFILE_TEMPLATE`:

```lua
queenName = "",   -- player-chosen queen name; empty = default display "Queen"
```

Add migration entry:

```lua
[16] = function(profile)
    if profile.queenName == nil then profile.queenName = "" end
end,
```

Bump `CURRENT_VERSION` from 15 to 16:

```lua
local CURRENT_VERSION = 16
```

**Verification:**

```lua
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
print("DataService version:", DS.CURRENT_VERSION or DS._version or "check manually")
-- Expected: 16
```

---

## Step 2 — QueenName RemoteEvents

Run in Command Bar:

```lua
local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name   = "Remotes"
    Remotes.Parent = game:GetService("ReplicatedStorage")
end

local function getOrCreate(name, class)
    local e = Remotes:FindFirstChild(name)
    if e then print(name, "already exists") return end
    local obj = Instance.new(class)
    obj.Name   = name
    obj.Parent = Remotes
    print("Created:", name)
end

getOrCreate("RequestQueenName",  "RemoteEvent")  -- client → server: propose name
getOrCreate("QueenNameConfirmed","RemoteEvent")  -- server → client(s): confirmed name + plotIndex
getOrCreate("RequestQueenNameLoad","RemoteEvent")-- client → server: ask for current name on join

print("Done")
```

**Verification:**

```lua
local R = game:GetService("ReplicatedStorage").Remotes
for _, n in {"RequestQueenName","QueenNameConfirmed","RequestQueenNameLoad"} do
    print(n, R:FindFirstChild(n) and "OK" or "MISSING")
end
-- Expected: all OK
```

---

## Step 3 — Server-Side Name Handler (add to Main Script or QueenService)

Add a new **Script** in **ServerScriptService** named `QueenNamingService`, or append to
the existing QueenService if it exists. If appending, add after the last `end` in that
service.

**New Script content:**

```lua
--!strict
-- QueenNamingService: validates and saves player-chosen queen names.

local Players         = game:GetService("Players")
local TextService     = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataService     = require(game:GetService("ServerScriptService").Systems.DataService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local RequestQueenName_163   = Remotes:WaitForChild("RequestQueenName",   10) :: RemoteEvent
local QueenNameConfirmed_163 = Remotes:WaitForChild("QueenNameConfirmed", 10) :: RemoteEvent
local RequestQueenNameLoad_163 = Remotes:WaitForChild("RequestQueenNameLoad", 10) :: RemoteEvent

local MAX_NAME_LEN_163 = 20
local MIN_NAME_LEN_163 = 1

-- ── Name validation ───────────────────────────────────────────────────────────

local function sanitiseLen_163(raw: string): string
	raw = raw:match("^%s*(.-)%s*$") or raw   -- trim whitespace
	if #raw > MAX_NAME_LEN_163 then raw = raw:sub(1, MAX_NAME_LEN_163) end
	return raw
end

-- ── Handlers ─────────────────────────────────────────────────────────────────

RequestQueenName_163.OnServerEvent:Connect(function(player: Player, rawName: unknown)
	if type(rawName) ~= "string" then return end

	local name = sanitiseLen_163(rawName)
	if #name < MIN_NAME_LEN_163 then
		QueenNameConfirmed_163:FireClient(player, {
			success = false,
			reason  = "Name is too short! Try at least 1 character.",
		})
		return
	end

	-- Run through Roblox text filter (protects kids from inappropriate names)
	local filtered: string = name
	local filterOk, filterErr = pcall(function()
		local result = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	if not filterOk then
		-- TextService may fail in Studio — fall back to raw name in dev, block in prod
		if game:GetService("RunService"):IsStudio() then
			filtered = name
		else
			QueenNameConfirmed_163:FireClient(player, {
				success = false,
				reason  = "Could not verify name right now. Try again in a moment.",
			})
			return
		end
	end

	-- Save to profile
	local profile = DataService.GetProfile(player)
	if not profile then
		QueenNameConfirmed_163:FireClient(player, {
			success = false,
			reason  = "Profile not loaded yet. Try again in a moment.",
		})
		return
	end
	profile.queenName = filtered

	-- Write attribute for this session
	player:SetAttribute("QueenName", filtered)

	local plotIndex = player:GetAttribute("PlotIndex") :: number?

	-- Fire back to this player
	QueenNameConfirmed_163:FireClient(player, {
		success    = true,
		name       = filtered,
		plotIndex  = plotIndex,
	})

	-- Broadcast to other players so their hover labels update
	for _, other in Players:GetPlayers() do
		if other ~= player then
			pcall(function()
				QueenNameConfirmed_163:FireClient(other, {
					success   = true,
					name      = filtered,
					plotIndex = plotIndex,
					isRemote  = true,
				})
			end)
		end
	end

	print("[QueenNamingService]", player.Name, "named queen:", filtered)
end)

-- Send stored name to client on join / request
local function sendStoredName_163(player: Player)
	local profile = DataService.GetProfile(player)
	if not profile or not profile.queenName or profile.queenName == "" then return end
	player:SetAttribute("QueenName", profile.queenName)
	local plotIndex = player:GetAttribute("PlotIndex") :: number?
	pcall(function()
		QueenNameConfirmed_163:FireClient(player, {
			success   = true,
			name      = profile.queenName,
			plotIndex = plotIndex,
			isLoad    = true,
		})
	end)
end

RequestQueenNameLoad_163.OnServerEvent:Connect(function(player: Player)
	task.delay(3, function()
		if player.Parent then sendStoredName_163(player) end
	end)
end)

Players.PlayerAdded:Connect(function(player)
	task.delay(6, function()
		if player.Parent then sendStoredName_163(player) end
	end)
end)

print("[QueenNamingService] ready")
```

**Verification:**

```lua
local s = game:GetService("ServerScriptService"):FindFirstChild("QueenNamingService")
print(s and s.ClassName or "MISSING")
-- Expected: Script
```

---

## Step 4 — QueenNamingController LocalScript

In Studio Explorer: **StarterPlayer → StarterPlayerScripts** → Insert **LocalScript**,
rename `QueenNamingController`.

Paste full source:

```lua
--!strict
-- QueenNamingController: queen naming ceremony popup + hover label on queen model.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────────────────
local HONEY_GOLD_163 = Color3.fromRGB(242, 168, 28)
local PROPOLIS_163   = Color3.fromRGB(80,  50,  20)
local WAX_CREAM_163  = Color3.fromRGB(232, 212, 154)
local GREEN_163      = Color3.fromRGB(60,  160, 60)
local RED_163        = Color3.fromRGB(200, 50,  50)

-- ── Build naming popup ─────────────────────────────────────────────────────────
local namingGui: ScreenGui? = nil

local function buildNamingPopup_163(onSubmit: (name: string) -> (), onCancel: () -> ())
	if namingGui then namingGui:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name           = "QueenNamingGui"
	sg.DisplayOrder   = 80
	sg.ResetOnSpawn   = false
	sg.IgnoreGuiInset = true
	sg.Parent         = playerGui
	namingGui         = sg

	-- Backdrop
	local backdrop = Instance.new("Frame")
	backdrop.Size               = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3   = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel    = 0
	backdrop.Parent             = sg

	-- Card
	local card = Instance.new("Frame")
	card.Name              = "Card"
	card.AnchorPoint       = Vector2.new(0.5, 0.5)
	card.Position          = UDim2.new(0.5, 0, 0.5, 0)
	card.Size              = UDim2.new(0, 300, 0, 260)
	card.BackgroundColor3  = PROPOLIS_163
	card.BorderSizePixel   = 0
	card.Parent            = sg
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 16)
	cc.Parent = card
	local cs = Instance.new("UIStroke")
	cs.Color     = HONEY_GOLD_163
	cs.Thickness = 3
	cs.Parent    = card

	-- Crown icon
	local crown = Instance.new("TextLabel")
	crown.Size               = UDim2.new(1, 0, 0, 50)
	crown.Position           = UDim2.new(0, 0, 0, 8)
	crown.BackgroundTransparency = 1
	crown.TextColor3         = HONEY_GOLD_163
	crown.TextSize           = 38
	crown.Font               = Enum.Font.GothamBold
	crown.Text               = "👑"
	crown.Parent             = card

	-- Title
	local title = Instance.new("TextLabel")
	title.Size               = UDim2.new(1, -20, 0, 30)
	title.Position           = UDim2.new(0, 10, 0, 62)
	title.BackgroundTransparency = 1
	title.TextColor3         = HONEY_GOLD_163
	title.TextSize           = 18
	title.Font               = Enum.Font.GothamBold
	title.Text               = "Name Your Queen!"
	title.Parent             = card

	-- Subtitle (adult detail)
	local sub = Instance.new("TextLabel")
	sub.Size               = UDim2.new(1, -20, 0, 24)
	sub.Position           = UDim2.new(0, 10, 0, 94)
	sub.BackgroundTransparency = 1
	sub.TextColor3         = WAX_CREAM_163
	sub.TextTransparency   = 0.3
	sub.TextSize           = 12
	sub.Font               = Enum.Font.Gotham
	sub.Text               = "Her name appears on your hive and above her. Max 20 chars."
	sub.TextWrapped        = true
	sub.Parent             = card

	-- Input box
	local inputBox = Instance.new("TextBox")
	inputBox.Name              = "NameInput"
	inputBox.Size              = UDim2.new(0, 240, 0, 40)
	inputBox.AnchorPoint       = Vector2.new(0.5, 0)
	inputBox.Position          = UDim2.new(0.5, 0, 0, 128)
	inputBox.BackgroundColor3  = Color3.fromRGB(50, 30, 10)
	inputBox.TextColor3        = WAX_CREAM_163
	inputBox.PlaceholderText   = "e.g. Queen Beatrice"
	inputBox.PlaceholderColor3 = Color3.fromRGB(120, 90, 50)
	inputBox.TextSize          = 16
	inputBox.Font              = Enum.Font.Gotham
	inputBox.ClearTextOnFocus  = false
	inputBox.MaxVisibleGraphemes = 20
	inputBox.BorderSizePixel   = 0
	inputBox.Parent            = card
	local ib_corner = Instance.new("UICorner")
	ib_corner.CornerRadius = UDim.new(0, 8)
	ib_corner.Parent = inputBox
	local ib_stroke = Instance.new("UIStroke")
	ib_stroke.Color     = HONEY_GOLD_163
	ib_stroke.Thickness = 1
	ib_stroke.Parent    = inputBox
	local ib_pad = Instance.new("UIPadding")
	ib_pad.PaddingLeft  = UDim.new(0, 8)
	ib_pad.PaddingRight = UDim.new(0, 8)
	ib_pad.Parent       = inputBox

	-- Char counter
	local charCount = Instance.new("TextLabel")
	charCount.Size               = UDim2.new(0, 60, 0, 18)
	charCount.AnchorPoint        = Vector2.new(1, 0)
	charCount.Position           = UDim2.new(0.5, 120, 0, 172)
	charCount.BackgroundTransparency = 1
	charCount.TextColor3         = WAX_CREAM_163
	charCount.TextTransparency   = 0.3
	charCount.TextSize           = 11
	charCount.Font               = Enum.Font.Gotham
	charCount.Text               = "0/20"
	charCount.TextXAlignment     = Enum.TextXAlignment.Right
	charCount.Parent             = card
	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
		local len = math.min(#inputBox.Text, 20)
		charCount.Text = len .. "/20"
	end)

	-- Error label (hidden by default)
	local errLabel = Instance.new("TextLabel")
	errLabel.Name              = "ErrLabel"
	errLabel.Size              = UDim2.new(1, -20, 0, 20)
	errLabel.Position          = UDim2.new(0, 10, 0, 174)
	errLabel.BackgroundTransparency = 1
	errLabel.TextColor3        = RED_163
	errLabel.TextSize          = 11
	errLabel.Font              = Enum.Font.Gotham
	errLabel.Text              = ""
	errLabel.Parent            = card

	-- Confirm button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name              = "ConfirmBtn"
	confirmBtn.Size              = UDim2.new(0, 130, 0, 40)
	confirmBtn.Position          = UDim2.new(0, 20, 0, 202)
	confirmBtn.BackgroundColor3  = HONEY_GOLD_163
	confirmBtn.TextColor3        = Color3.fromRGB(50, 30, 0)
	confirmBtn.TextSize          = 15
	confirmBtn.Font              = Enum.Font.GothamBold
	confirmBtn.Text              = "👑 Name Her!"
	confirmBtn.BorderSizePixel   = 0
	confirmBtn.Parent            = card
	local cb_corner = Instance.new("UICorner")
	cb_corner.CornerRadius = UDim.new(0, 10)
	cb_corner.Parent = confirmBtn

	-- Cancel button
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Name              = "CancelBtn"
	cancelBtn.Size              = UDim2.new(0, 110, 0, 40)
	cancelBtn.Position          = UDim2.new(0, 162, 0, 202)
	cancelBtn.BackgroundColor3  = Color3.fromRGB(50, 30, 10)
	cancelBtn.TextColor3        = WAX_CREAM_163
	cancelBtn.TextSize          = 14
	cancelBtn.Font              = Enum.Font.Gotham
	cancelBtn.Text              = "Not yet"
	cancelBtn.BorderSizePixel   = 0
	cancelBtn.Parent            = card
	local cancel_corner = Instance.new("UICorner")
	cancel_corner.CornerRadius = UDim.new(0, 10)
	cancel_corner.Parent = cancelBtn

	-- Slide in
	card.Position = UDim2.new(0.5, 0, 1.5, 0)
	TweenService:Create(card,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0.5, 0) }
	):Play()

	-- Wire buttons
	confirmBtn.MouseButton1Click:Connect(function()
		local raw = inputBox.Text:match("^%s*(.-)%s*$") or ""
		if #raw < 1 then
			errLabel.Text = "Please type a name first!"
			return
		end
		onSubmit(raw)
	end)
	cancelBtn.MouseButton1Click:Connect(function()
		onCancel()
		sg:Destroy()
		namingGui = nil
	end)
end

-- ── Success toast ──────────────────────────────────────────────────────────────
local function showSuccessToast_163(name: string)
	local sg2 = Instance.new("ScreenGui")
	sg2.Name          = "QueenNameToast"
	sg2.DisplayOrder  = 85
	sg2.ResetOnSpawn  = false
	sg2.IgnoreGuiInset = true
	sg2.Parent        = playerGui

	local toast = Instance.new("Frame")
	toast.AnchorPoint     = Vector2.new(0.5, 0)
	toast.Position        = UDim2.new(0.5, 0, -0.08, 0)
	toast.Size            = UDim2.new(0, 280, 0, 48)
	toast.BackgroundColor3 = PROPOLIS_163
	toast.BorderSizePixel = 0
	toast.Parent          = sg2
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(0, 12)
	tc.Parent = toast
	local ts = Instance.new("UIStroke")
	ts.Color     = HONEY_GOLD_163
	ts.Thickness = 2
	ts.Parent    = toast

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = HONEY_GOLD_163
	lbl.TextSize           = 16
	lbl.Font               = Enum.Font.GothamBold
	lbl.Text               = "👑 Queen " .. name .. " is ready!"
	lbl.Parent             = toast

	TweenService:Create(toast,
		TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 8) }
	):Play()
	task.delay(3.5, function()
		TweenService:Create(toast,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, -0.08, 0) }
		):Play()
		task.delay(0.3, function() sg2:Destroy() end)
	end)
end

-- ── Queen hover label (world BillboardGui) ─────────────────────────────────────
-- Attaches a BillboardGui to the QueenBee part on the local player's plot
local hoverLabels_163: { [number]: BillboardGui } = {}

local function updateQueenLabel_163(plotIndex: number, name: string)
	-- Find QueenBee tagged part on this plot
	for _, part in CollectionService:GetTagged("QueenBee") do
		if part:GetAttribute("PlotIndex") == plotIndex then
			local label: BillboardGui? = hoverLabels_163[plotIndex]
			if not label or not label.Parent then
				-- Build billboard
				local bb = Instance.new("BillboardGui")
				bb.Name           = "QueenNameBB"
				bb.Size           = UDim2.new(0, 120, 0, 30)
				bb.StudsOffset    = Vector3.new(0, 3.5, 0)
				bb.AlwaysOnTop    = false
				bb.MaxDistance    = 30
				bb.Parent         = part
				local lblInst = Instance.new("TextLabel")
				lblInst.Name               = "NameLabel"
				lblInst.Size               = UDim2.fromScale(1, 1)
				lblInst.BackgroundTransparency = 1
				lblInst.TextColor3         = HONEY_GOLD_163
				lblInst.TextSize           = 13
				lblInst.Font               = Enum.Font.GothamBold
				lblInst.Text               = "👑 " .. name
				lblInst.TextStrokeColor3   = Color3.fromRGB(0,0,0)
				lblInst.TextStrokeTransparency = 0.4
				lblInst.Parent             = bb
				hoverLabels_163[plotIndex] = bb
			else
				local lbl2 = label:FindFirstChild("NameLabel") :: TextLabel?
				if lbl2 then lbl2.Text = "👑 " .. name end
			end
			break
		end
	end
end

-- ── Rename button in HiveGui Queen tab (optional patch) ───────────────────────
-- Adds a small "Rename ✏" button below the queen name display in HiveGui.
-- This step is OPTIONAL — skip if HiveGui.MainFrame.QueenPage doesn't exist yet
-- (QueenService from dispatch 8 must have been executed first).
local function patchQueenTab_163()
	local hiveGui = playerGui:WaitForChild("HiveGui", 5) :: ScreenGui?
	if not hiveGui then return end
	local mainFrame = hiveGui:FindFirstChild("MainFrame")
	local queenPage = mainFrame and mainFrame:FindFirstChild("QueenPage")
	if not queenPage then return end   -- Queen tab not built yet — skip

	-- Check if rename button already exists
	if queenPage:FindFirstChild("RenameBtn_163") then return end

	local renameBtn = Instance.new("TextButton")
	renameBtn.Name              = "RenameBtn_163"
	renameBtn.Size              = UDim2.new(0, 120, 0, 30)
	renameBtn.AnchorPoint       = Vector2.new(0.5, 0)
	renameBtn.Position          = UDim2.new(0.5, 0, 0, 8)
	renameBtn.BackgroundColor3  = Color3.fromRGB(60, 35, 10)
	renameBtn.TextColor3        = WAX_CREAM_163
	renameBtn.TextSize          = 13
	renameBtn.Font              = Enum.Font.Gotham
	renameBtn.Text              = "✏ Rename Queen"
	renameBtn.BorderSizePixel   = 0
	renameBtn.Parent            = queenPage
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 8)
	rc.Parent = renameBtn

	renameBtn.MouseButton1Click:Connect(function()
		openNamingPopup_163()
	end)
end

-- ── Core popup open function ───────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local RequestQueenName_163    = Remotes and Remotes:WaitForChild("RequestQueenName",    10) :: RemoteEvent?
local QueenNameConfirmed_163  = Remotes and Remotes:WaitForChild("QueenNameConfirmed",  10) :: RemoteEvent?
local RequestQueenNameLoad_163 = Remotes and Remotes:WaitForChild("RequestQueenNameLoad", 10) :: RemoteEvent?

local pendingSubmit_163 = false

function openNamingPopup_163()
	if pendingSubmit_163 then return end
	buildNamingPopup_163(
		function(name: string)
			if not RequestQueenName_163 then return end
			pendingSubmit_163 = true
			RequestQueenName_163:FireServer(name)
		end,
		function() pendingSubmit_163 = false end
	)
end

-- ── Listen for confirmed name ──────────────────────────────────────────────────
if QueenNameConfirmed_163 then
	QueenNameConfirmed_163.OnClientEvent:Connect(function(data: any)
		pendingSubmit_163 = false

		if not data.success then
			-- Show error in popup if it's still open
			if namingGui then
				local errLbl = namingGui:FindFirstChild("ErrLabel", true) :: TextLabel?
				if errLbl then errLbl.Text = data.reason or "Something went wrong." end
			end
			return
		end

		-- Dismiss popup with fanfare
		if namingGui then
			namingGui:Destroy()
			namingGui = nil
		end

		-- Show toast (only for own confirmation, not remote broadcasts)
		if not data.isRemote and not data.isLoad then
			showSuccessToast_163(data.name)
		end

		-- Update hover label on queen model
		if data.plotIndex then
			updateQueenLabel_163(data.plotIndex, data.name)
		end
	end)
end

-- ── Fire first-time popup when queen is first placed ──────────────────────────
-- Monitor QueenBee tagged parts appearing on the local player's plot
-- and show the naming popup if queenName is still empty.
task.spawn(function()
	-- Wait for plot assignment
	local plotIndex: number? = nil
	while not plotIndex do
		task.wait(1)
		plotIndex = player:GetAttribute("PlotIndex") :: number?
	end

	-- Check if already named
	local existingName = player:GetAttribute("QueenName") :: string?
	if existingName and #existingName > 0 then
		-- Already named — just make sure hover label is current
		updateQueenLabel_163(plotIndex, existingName)
		patchQueenTab_163()
		return
	end

	-- Request load from server
	if RequestQueenNameLoad_163 then
		RequestQueenNameLoad_163:FireServer()
	end

	-- Watch for QueenBee tag to appear on our plot
	CollectionService:GetInstanceAddedSignal("QueenBee"):Connect(function(part: Instance)
		if not part:IsA("BasePart") then return end
		if part:GetAttribute("PlotIndex") ~= plotIndex then return end
		local currentName = player:GetAttribute("QueenName") :: string?
		if not currentName or #currentName == 0 then
			task.wait(1)
			openNamingPopup_163()
		end
	end)

	-- Also check if QueenBee already exists right now
	for _, part in CollectionService:GetTagged("QueenBee") do
		if part:GetAttribute("PlotIndex") == plotIndex then
			local currentName2 = player:GetAttribute("QueenName") :: string?
			if not currentName2 or #currentName2 == 0 then
				task.wait(1)
				openNamingPopup_163()
			end
			break
		end
	end

	patchQueenTab_163()
end)
```

**Verification:**

```lua
local lrc = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("QueenNamingController")
print(lrc and lrc.ClassName or "MISSING")
-- Expected: LocalScript
```

---

## Step 5 — Test in Play Mode

```lua
-- Simulate a name submission
local Remotes = game:GetService("ReplicatedStorage").Remotes
local requestEvent = Remotes:FindFirstChild("RequestQueenName")
print("RequestQueenName:", requestEvent and requestEvent.ClassName or "MISSING")

-- Fire from server side to test QueenNameConfirmed reaches a client
local confirmedEvent = Remotes:FindFirstChild("QueenNameConfirmed")
local player = game:GetService("Players"):GetPlayers()[1]
if confirmedEvent and player then
    confirmedEvent:FireClient(player, {
        success   = true,
        name      = "Queen Honey",
        plotIndex = player:GetAttribute("PlotIndex"),
    })
    print("Fired test QueenNameConfirmed to", player.Name)
end
```

**Expected behaviour:**
- Naming popup slides up with crown emoji, TextBox, character counter, and "Name Her!" button
- Typing fires char counter update (e.g., "12/20")
- On submit: Roblox text filter runs; confirmed name fires back; popup dismisses
- Toast appears top of screen: "👑 Queen [Name] is ready!"
- BillboardGui appears above queen model (within 30 studs): "👑 [Name]"
- All other players in the server see the hover label update on that plot's queen
- "✏ Rename Queen" button appears in HiveGui Queen tab (if Queen tab is built)

---

## Step 6 — state.json update

After executing in Studio, update `dispatch_count` to 163 and `last_dispatch` to
`"cycle15_queen_naming_dispatch.md"` in state.json.

---

## Summary

| What | Where |
|---|---|
| DataService v15→v16 | `PROFILE_TEMPLATE` + `MIGRATIONS[16]` + `CURRENT_VERSION=16` |
| `QueenNamingService` | `ServerScriptService` Script |
| `QueenNamingController` | `StarterPlayer.StarterPlayerScripts` LocalScript |
| `RequestQueenName`, `QueenNameConfirmed`, `RequestQueenNameLoad` | `ReplicatedStorage.Remotes` |
| Queen hover BillboardGui | attached to `QueenBee`-tagged part at runtime (no world part) |
| "✏ Rename Queen" button | optional patch to HiveGui QueenPage |
| New world parts | **0** → total **4,198 / 5,000** |

**Kid experience:** The moment a queen appears in your hive, a popup asks "Name Your Queen!"
with a crown icon. After naming her, her name floats above her head forever. Kids will pick
names like "Queen Sparkle" or "Queen Peanut Butter" — and that's perfect.

**Adult experience:** Roblox text filter runs transparently, character counter shows 0/20,
full rename workflow available any time from the Queen tab in HiveGui.
