# Dispatch 45 — BeeNaming (Name Your Queen Bee) (Cycle 11)

**Feature:** Players can give their queen bee a custom name (up to 24 characters).
The name persists in the player's profile, appears as a BillboardGui above the queen bee
model in the world, and is shown in the HiveGui header.

**Execution order:** After dispatch 44 (MiniMapGui).  
**Part budget impact:** +1 per player (BillboardGui host Part above queen — very small,
negligible vs budget). Dynamically created at runtime per player, not counted in static budget.  
**Running total:** ~4,142 / 5,000.

---

## STEP A — Config additions

```lua
local SSS = game:GetService("ServerScriptService")
local cfg = SSS:FindFirstChild("Config")
assert(cfg, "Config not found")
local clone = cfg:Clone()
cfg.Name = "Config_OLD_45A"
cfg.Parent = nil

local inject = [[

-- ── Bee Naming (dispatch 45) ─────────────────────────────────
Config.BEE_NAME = {
    maxLength  = 24,
    minLength  = 1,
    default    = "Queen Bee",
    profanity  = {},   -- optional: add banned substrings here
    -- Honey cost to rename after first time
    renameCost = 500,
}
]]
clone.Source = clone.Source .. inject
clone.Name = "Config"
clone.Parent = SSS
print("Config.BEE_NAME added")
```

---

## STEP B — DataService migration

```lua
local SSS = game:GetService("ServerScriptService")
local ds  = SSS:FindFirstChild("DataService")
assert(ds, "DataService not found")
local clone = ds:Clone()
ds.Name = "DataService_OLD_45B"
ds.Parent = nil

local src = clone.Source
local injection = [[

    -- Bee naming (dispatch 45)
    queenName     = "Queen Bee",   -- display name above queen model
    hasNamedOnce  = false,         -- first rename is free
]]
src = src:gsub(
    "(totalGenerations%s*=%s*0,)",
    "%1" .. injection
)
clone.Source = src
clone.Name = "DataService"
clone.Parent = SSS
print("DataService migrated for bee naming")
```

---

## STEP C — BeeNameSync RemoteEvent + SetQueenName RemoteFunction

```lua
local RE = game:GetService("ReplicatedStorage")
local Remotes = RE:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = RE
end

-- BeeNameSync: server → nearby clients (update billboard)
local bns = Remotes:FindFirstChild("BeeNameSync")
if not bns then
    bns = Instance.new("RemoteEvent")
    bns.Name = "BeeNameSync"
    bns.Parent = Remotes
end

-- SetQueenName: client → server (rename request)
local sqn = Remotes:FindFirstChild("SetQueenName")
if not sqn then
    sqn = Instance.new("RemoteFunction")
    sqn.Name = "SetQueenName"
    sqn.Parent = Remotes
end

print("BeeNameSync + SetQueenName Remotes created")
```

---

## STEP D — BeeNameService ModuleScript

```lua
local SSS = game:GetService("ServerScriptService")

local svc = Instance.new("ModuleScript")
svc.Name   = "BeeNameService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- BeeNameService — stores and validates queen bee display names
local BeeNameService = {}

local Players        = game:GetService("Players")
local DataService    = require(script.Parent.DataService)
local Config         = require(script.Parent.Config)

local BeeNameSync   : RemoteEvent
local SetQueenName  : RemoteFunction

local function sanitise(raw: string): (boolean, string)
    local s = raw:match("^%s*(.-)%s*$")   -- trim whitespace
    local cfg = Config.BEE_NAME
    if #s < cfg.minLength then return false, "Name too short" end
    if #s > cfg.maxLength  then return false, "Name too long (max " .. cfg.maxLength .. ")" end
    for _, banned in cfg.profanity do
        if s:lower():find(banned:lower(), 1, true) then
            return false, "Name not allowed"
        end
    end
    return true, s
end

function BeeNameService.Init()
    local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    assert(Remotes, "Remotes not found")
    BeeNameSync  = Remotes:FindFirstChild("BeeNameSync")  :: RemoteEvent
    SetQueenName = Remotes:FindFirstChild("SetQueenName") :: RemoteFunction

    -- Handle rename request
    SetQueenName.OnServerInvoke = function(player: Player, rawName: unknown): (boolean, string)
        if type(rawName) ~= "string" then return false, "Invalid input" end
        local ok, nameOrErr = sanitise(rawName :: string)
        if not ok then return false, nameOrErr end

        local profile = DataService.GetProfile(player)
        if not profile then return false, "Profile not loaded" end

        local cleanName: string = nameOrErr

        -- Charge honey for renames after the first
        if profile.hasNamedOnce then
            local cost = Config.BEE_NAME.renameCost
            if profile.honey < cost then
                return false, "Need " .. cost .. " 🍯 to rename"
            end
            profile.honey = profile.honey - cost
        else
            profile.hasNamedOnce = true
        end

        profile.queenName = cleanName
        -- Broadcast to all clients so nearby players see the updated billboard
        BeeNameSync:FireAllClients({ userId = player.UserId, name = cleanName })
        return true, cleanName
    end

    -- Sync name on join
    Players.PlayerAdded:Connect(function(player)
        task.delay(3, function()
            if not (player and player.Parent) then return end
            local profile = DataService.GetProfile(player)
            if not profile then return end
            BeeNameSync:FireAllClients({ userId = player.UserId, name = profile.queenName or "Queen Bee" })
        end)
    end)
end

function BeeNameService.GetQueenName(player: Player): string
    local profile = DataService.GetProfile(player)
    if profile then return profile.queenName or "Queen Bee" end
    return "Queen Bee"
end

return BeeNameService
]]

print("BeeNameService created")
```

---

## STEP E — GameManager wiring

```lua
local SSS = game:GetService("ServerScriptService")
local gm  = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")
local clone = gm:Clone()
gm.Name = "GameManager_OLD_45E"
gm.Parent = nil

local src = clone.Source
src = src:gsub(
    "(local ThunderService = require%(script%.Parent%.ThunderService%))",
    [[%1
local BeeNameService = require(script.Parent.BeeNameService)]]
)
src = src:gsub(
    "(ThunderService%.Init%(%%))",
    [[%1
    BeeNameService.Init()]]
)
clone.Source = src
clone.Name = "GameManager"
clone.Parent = SSS
print("GameManager wired for BeeNameService")
```

---

## STEP F — BeeNameController LocalScript (billboard + rename UI)

```lua
local StarterPlayer = game:GetService("StarterPlayer")
local SPS           = StarterPlayer:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "BeeNameController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- BeeNameController — shows queen name billboard, drives rename dialog in HiveGui

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer       = Players.LocalPlayer
local PlayerGui         = localPlayer:WaitForChild("PlayerGui")
local HiveGui           = PlayerGui:WaitForChild("HiveGui", 15)
local MainFrame         = HiveGui and HiveGui:WaitForChild("MainFrame", 5)

-- ── Remotes ──────────────────────────────────────────────────────
local Remotes       = ReplicatedStorage:WaitForChild("Remotes", 10)
local BeeNameSync   = Remotes and Remotes:WaitForChild("BeeNameSync",  10) :: RemoteEvent?
local SetQueenName  = Remotes and Remotes:WaitForChild("SetQueenName", 10) :: RemoteFunction?

-- ── Name store (userId → name) ───────────────────────────────────
local nameStore: {[number]: string} = {}

-- ── Billboard management ─────────────────────────────────────────
-- Find a player's queen bee model in workspace and attach/update BillboardGui
local function findQueenModel(userId: number): Model?
    local CS = game:GetService("CollectionService")
    for _, m in CS:GetTagged("QueenBee") do
        if m:IsA("Model") and m:GetAttribute("OwnerId") == userId then
            return m
        end
    end
    return nil
end

local function updateBillboard(userId: number, name: string)
    local queen = findQueenModel(userId)
    if not queen then return end

    local root  = queen:FindFirstChild("HumanoidRootPart") or queen.PrimaryPart
    if not root then return end

    local bb = root:FindFirstChild("QueenNameBillboard")
    if not bb then
        -- Create BillboardGui above the queen
        bb              = Instance.new("BillboardGui")
        bb.Name         = "QueenNameBillboard"
        bb.Parent       = root
        bb.Size         = UDim2.new(0, 120, 0, 32)
        bb.StudsOffset  = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop  = false
        bb.Adornee      = root :: Instance

        local bg        = Instance.new("Frame")
        bg.Name         = "BG"
        bg.Parent       = bb
        bg.Size         = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(18, 10, 4)
        bg.BackgroundTransparency = 0.25
        local bgCorner  = Instance.new("UICorner")
        bgCorner.CornerRadius = UDim.new(0.4, 0)
        bgCorner.Parent = bg
        local bgStroke  = Instance.new("UIStroke")
        bgStroke.Color  = Color3.fromRGB(242, 168, 28)
        bgStroke.Thickness = 1.5
        bgStroke.Parent = bg

        local lbl       = Instance.new("TextLabel")
        lbl.Name        = "NameLabel"
        lbl.Parent      = bg
        lbl.Size        = UDim2.new(1, -6, 1, 0)
        lbl.Position    = UDim2.new(0, 3, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font        = Enum.Font.FredokaOne
        lbl.TextColor3  = Color3.fromRGB(242, 168, 28)
        lbl.TextScaled  = true
        lbl.ZIndex      = 5
    end

    local lbl = (bb :: BillboardGui):FindFirstChild("BG") and
                ((bb :: BillboardGui):FindFirstChild("BG") :: Frame):FindFirstChild("NameLabel") :: TextLabel?
    if lbl then
        lbl.Text = "👑 " .. name
    end
end

-- ── Receive BeeNameSync ──────────────────────────────────────────
if BeeNameSync then
    BeeNameSync.OnClientEvent:Connect(function(data: {userId: number, name: string})
        nameStore[data.userId] = data.name
        updateBillboard(data.userId, data.name)

        -- Update HiveGui header if this is our own queen
        if data.userId == localPlayer.UserId and MainFrame then
            local queenLabel = MainFrame:FindFirstChild("QueenNameLabel")
            if queenLabel and queenLabel:IsA("TextLabel") then
                queenLabel.Text = "👑 " .. data.name
            end
        end
    end)
end

-- ── Rename Dialog in HiveGui ─────────────────────────────────────
-- Add a small 📝 rename button near the queen name display in MainFrame
if MainFrame then
    -- QueenNameLabel (shows current name)
    local queenLabel            = MainFrame:FindFirstChild("QueenNameLabel")
    if not queenLabel then
        queenLabel              = Instance.new("TextLabel")
        queenLabel.Name         = "QueenNameLabel"
        queenLabel.Parent       = MainFrame
        queenLabel.Size         = UDim2.new(0.32, 0, 0.08, 0)
        queenLabel.Position     = UDim2.new(0.01, 0, 0.01, 0)
        queenLabel.BackgroundTransparency = 1
        queenLabel.Text         = "👑 Queen Bee"
        queenLabel.TextColor3   = Color3.fromRGB(242, 168, 28)
        queenLabel.Font         = Enum.Font.FredokaOne
        queenLabel.TextScaled   = true
        queenLabel.TextXAlignment = Enum.TextXAlignment.Left
        queenLabel.ZIndex       = 10
    end

    -- ✏️ Rename button
    local renameBtn             = Instance.new("TextButton")
    renameBtn.Name              = "RenameBtn"
    renameBtn.Parent            = MainFrame
    renameBtn.Size              = UDim2.new(0.06, 0, 0.07, 0)
    renameBtn.Position          = UDim2.new(0.34, 0, 0.015, 0)
    renameBtn.BackgroundColor3  = Color3.fromRGB(122, 74, 34)
    renameBtn.Text              = "✏️"
    renameBtn.TextScaled        = true
    renameBtn.Font              = Enum.Font.FredokaOne
    renameBtn.TextColor3        = Color3.fromRGB(232, 212, 154)
    renameBtn.ZIndex            = 10
    local rnCorner              = Instance.new("UICorner")
    rnCorner.CornerRadius       = UDim.new(0.2, 0)
    rnCorner.Parent             = renameBtn

    -- ── Rename dialog panel ──────────────────────────────────────
    local HiveGuiRoot = PlayerGui:FindFirstChild("HiveGui")
    local dialog      = Instance.new("Frame")
    dialog.Name       = "RenameDialog"
    dialog.Parent     = HiveGuiRoot
    dialog.Size       = UDim2.new(0.36, 0, 0.22, 0)
    dialog.Position   = UDim2.new(0.32, 0, 0.39, 0)
    dialog.BackgroundColor3 = Color3.fromRGB(25, 15, 8)
    dialog.BorderSizePixel  = 0
    dialog.Visible          = false
    dialog.ZIndex           = 50
    local dlgCorner         = Instance.new("UICorner")
    dlgCorner.CornerRadius  = UDim.new(0.06, 0)
    dlgCorner.Parent        = dialog
    local dlgStroke         = Instance.new("UIStroke")
    dlgStroke.Color         = Color3.fromRGB(242, 168, 28)
    dlgStroke.Thickness     = 2
    dlgStroke.Parent        = dialog

    local dlgHeader         = Instance.new("TextLabel")
    dlgHeader.Parent        = dialog
    dlgHeader.Size          = UDim2.new(1, 0, 0.24, 0)
    dlgHeader.Position      = UDim2.new(0, 0, 0, 0)
    dlgHeader.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
    dlgHeader.Text          = "✏️  Name Your Queen"
    dlgHeader.TextColor3    = Color3.fromRGB(242, 168, 28)
    dlgHeader.Font          = Enum.Font.FredokaOne
    dlgHeader.TextScaled    = true
    dlgHeader.ZIndex        = 51
    local dhCorner          = Instance.new("UICorner")
    dhCorner.CornerRadius   = UDim.new(0.06, 0)
    dhCorner.Parent         = dlgHeader

    -- TextBox for input
    local inputBox          = Instance.new("TextBox")
    inputBox.Name           = "NameInput"
    inputBox.Parent         = dialog
    inputBox.Size           = UDim2.new(0.88, 0, 0.28, 0)
    inputBox.Position       = UDim2.new(0.06, 0, 0.30, 0)
    inputBox.BackgroundColor3 = Color3.fromRGB(40, 25, 10)
    inputBox.Text           = ""
    inputBox.PlaceholderText = "Enter name (max 24 chars)…"
    inputBox.PlaceholderColor3 = Color3.fromRGB(150, 100, 50)
    inputBox.TextColor3     = Color3.fromRGB(232, 212, 154)
    inputBox.Font           = Enum.Font.FredokaOne
    inputBox.TextScaled     = true
    inputBox.ClearTextOnFocus = false
    inputBox.ZIndex         = 51
    local ibCorner          = Instance.new("UICorner")
    ibCorner.CornerRadius   = UDim.new(0.1, 0)
    ibCorner.Parent         = inputBox
    local ibStroke          = Instance.new("UIStroke")
    ibStroke.Color          = Color3.fromRGB(122, 74, 34)
    ibStroke.Thickness      = 1.5
    ibStroke.Parent         = inputBox

    -- Status label (shows error / success)
    local statusLabel       = Instance.new("TextLabel")
    statusLabel.Name        = "StatusLabel"
    statusLabel.Parent      = dialog
    statusLabel.Size        = UDim2.new(0.88, 0, 0.14, 0)
    statusLabel.Position    = UDim2.new(0.06, 0, 0.60, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text        = "First rename is free! (500 🍯 after)"
    statusLabel.TextColor3  = Color3.fromRGB(180, 140, 80)
    statusLabel.Font        = Enum.Font.FredokaOne
    statusLabel.TextScaled  = true
    statusLabel.ZIndex      = 51

    -- Confirm + Cancel buttons
    local confirmBtn        = Instance.new("TextButton")
    confirmBtn.Name         = "ConfirmBtn"
    confirmBtn.Parent       = dialog
    confirmBtn.Size         = UDim2.new(0.42, 0, 0.20, 0)
    confirmBtn.Position     = UDim2.new(0.06, 0, 0.76, 0)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(242, 168, 28)
    confirmBtn.Text         = "✓  Save"
    confirmBtn.TextColor3   = Color3.fromRGB(20, 10, 4)
    confirmBtn.Font         = Enum.Font.FredokaOne
    confirmBtn.TextScaled   = true
    confirmBtn.ZIndex       = 51
    local cfCorner          = Instance.new("UICorner")
    cfCorner.CornerRadius   = UDim.new(0.2, 0)
    cfCorner.Parent         = confirmBtn

    local cancelBtn         = Instance.new("TextButton")
    cancelBtn.Name          = "CancelBtn"
    cancelBtn.Parent        = dialog
    cancelBtn.Size          = UDim2.new(0.42, 0, 0.20, 0)
    cancelBtn.Position      = UDim2.new(0.52, 0, 0.76, 0)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(90, 50, 25)
    cancelBtn.Text          = "✕  Cancel"
    cancelBtn.TextColor3    = Color3.fromRGB(232, 212, 154)
    cancelBtn.Font          = Enum.Font.FredokaOne
    cancelBtn.TextScaled    = true
    cancelBtn.ZIndex        = 51
    local ccCorner          = Instance.new("UICorner")
    ccCorner.CornerRadius   = UDim.new(0.2, 0)
    ccCorner.Parent         = cancelBtn

    -- ── Dialog logic ─────────────────────────────────────────────
    local SHOW = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local HIDE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

    local function openDialog()
        local currentName = nameStore[localPlayer.UserId] or "Queen Bee"
        inputBox.Text = currentName
        statusLabel.Text = "First rename is free! (500 🍯 after)"
        statusLabel.TextColor3 = Color3.fromRGB(180, 140, 80)
        dialog.Size     = UDim2.new(0.01, 0, 0.01, 0)
        dialog.Position = UDim2.new(0.495, 0, 0.495, 0)
        dialog.Visible  = true
        TweenService:Create(dialog, SHOW, {
            Size     = UDim2.new(0.36, 0, 0.22, 0),
            Position = UDim2.new(0.32, 0, 0.39, 0),
        }):Play()
    end

    local function closeDialog()
        local tw = TweenService:Create(dialog, HIDE, {
            Size     = UDim2.new(0.01, 0, 0.01, 0),
            Position = UDim2.new(0.495, 0, 0.495, 0),
        })
        tw:Play()
        tw.Completed:Connect(function() dialog.Visible = false end)
    end

    renameBtn.Activated:Connect(openDialog)
    cancelBtn.Activated:Connect(closeDialog)

    confirmBtn.Activated:Connect(function()
        local name = inputBox.Text
        if not SetQueenName then
            statusLabel.Text = "Not connected — try again"
            statusLabel.TextColor3 = Color3.fromRGB(220, 80, 80)
            return
        end
        confirmBtn.Active = false
        confirmBtn.Text   = "…"
        local ok, msg = SetQueenName:InvokeServer(name)
        confirmBtn.Active = true
        confirmBtn.Text   = "✓  Save"
        if ok then
            statusLabel.Text = "✓ Named: " .. tostring(msg)
            statusLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
            task.delay(1.2, closeDialog)
        else
            statusLabel.Text = "✗ " .. tostring(msg)
            statusLabel.TextColor3 = Color3.fromRGB(220, 80, 80)
        end
    end)
end
]]

print("BeeNameController LocalScript created")
```

---

## STEP G — Verification

```lua
local SSS    = game:GetService("ServerScriptService")
local SP     = game:GetService("StarterPlayer")
local RE     = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- 1. BeeNameService
local svc = SSS:FindFirstChild("BeeNameService")
if svc and svc:IsA("ModuleScript") then
    local lines = select(2, svc.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ BeeNameService: " .. lines .. " lines")
    if not svc.Source:find("--!strict")   then table.insert(issues, "MISSING --!strict in BeeNameService") end
    if not svc.Source:find("sanitise")    then table.insert(issues, "MISSING sanitise in BeeNameService") end
    if not svc.Source:find("SetQueenName") then table.insert(issues, "MISSING SetQueenName handler") end
else
    table.insert(issues, "❌ BeeNameService NOT FOUND in SSS")
end

-- 2. Remotes
local Remotes = RE:FindFirstChild("Remotes")
local bns = Remotes and Remotes:FindFirstChild("BeeNameSync")
local sqn = Remotes and Remotes:FindFirstChild("SetQueenName")
table.insert(results, bns and "✅ BeeNameSync RemoteEvent" or "❌ BeeNameSync MISSING")
table.insert(results, sqn and "✅ SetQueenName RemoteFunction" or "❌ SetQueenName MISSING")
if not bns then table.insert(issues, "BeeNameSync missing") end
if not sqn then table.insert(issues, "SetQueenName missing") end

-- 3. BeeNameController
local SPS  = SP:FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("BeeNameController")
if ctrl and ctrl:IsA("LocalScript") then
    local lines = select(2, ctrl.Source:gsub("\n","\n")) + 1
    table.insert(results, "✅ BeeNameController: " .. lines .. " lines")
    if not ctrl.Source:find("--!strict")   then table.insert(issues, "MISSING --!strict in BeeNameController") end
    if not ctrl.Source:find("RenameDialog") then table.insert(issues, "MISSING RenameDialog") end
    if not ctrl.Source:find("BillboardGui") then table.insert(issues, "MISSING BillboardGui creation") end
else
    table.insert(issues, "❌ BeeNameController NOT FOUND in StarterPlayerScripts")
end

-- 4. Config
local cfg = SSS:FindFirstChild("Config")
if cfg and cfg.Source:find("BEE_NAME") then
    table.insert(results, "✅ Config.BEE_NAME defined")
else
    table.insert(issues, "⚠️ Config.BEE_NAME missing")
end

-- 5. DataService
local ds = SSS:FindFirstChild("DataService")
if ds and ds.Source:find("queenName") then
    table.insert(results, "✅ DataService has queenName field")
else
    table.insert(issues, "⚠️ DataService missing queenName field")
end

local out = "=== DISPATCH 45 VERIFICATION ===\n" .. table.concat(results, "\n") .. "\n"
if #issues > 0 then out = out .. "\nISSUES:\n" .. table.concat(issues, "\n")
else out = out .. "\n✅ ALL CHECKS PASSED — dispatch 45 complete" end
print(out)
return out
```

---

## Summary

| Item | Created/Modified |
|---|---|
| Config.BEE_NAME | maxLength=24, renameCost=500, profanity list |
| DataService migration | queenName, hasNamedOnce fields |
| BeeNameSync RemoteEvent | server → all clients (billboard update) |
| SetQueenName RemoteFunction | client → server (rename request) |
| BeeNameService | Init, sanitise (trim/length/profanity), idempotent first-rename free, BeeNameSync broadcast, PlayerAdded sync |
| GameManager wiring | BeeNameService.Init() |
| BeeNameController | BillboardGui above queen (FredokaOne, Honey Gold, dark bg), QueenNameLabel + ✏️ RenameBtn in MainFrame, RenameDialog (TextBox, confirm/cancel, error feedback) |

**Execution order:** A → B → C → D → E → F → G (verify)  
**Part budget:** 0 permanent → **~4,142 / 5,000**
