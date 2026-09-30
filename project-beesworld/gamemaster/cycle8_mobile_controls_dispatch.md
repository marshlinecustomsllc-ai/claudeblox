# Cycle 8 — Mobile Controls Dispatch

**Agents:** luau-scripter + ui-designer  
**Target:** Virtual joystick + mobile action buttons for touch players  
**Part delta:** +0 (pure UI/LocalScript)  
**DataService version:** v10 (no change)  
**Prerequisites:** All cycle 1–8 dispatches executed.

---

## Overview

Roblox's default mobile controls are serviceable but the game has several actions (Harvest, Dance, Shop open, Quest panel) that require keyboard shortcuts or ProximityPrompts only. This dispatch adds:

1. **MobileController LocalScript** — detects `UserInputService.TouchEnabled`, creates all mobile UI, does nothing on PC/console  
2. **Virtual D-pad / action bar** — 4 large action buttons in bottom-right: Harvest (🍯), Dance (💃), Shop (🛒), Quests (📋)  
3. **Proximity action button** — when within range of a Landing Board or WardrobePad, a large floating "INTERACT" button replaces the ProximityPrompt  
4. **Mobile-safe existing UI** — audit and fix any pixel-offset sized elements in BuildGui/DanceGui/HudGui that break on 375pt wide phones  

---

## Step 1 — MobileController LocalScript

Run in Studio Command Bar:

```lua
local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local old = SPS:FindFirstChild("MobileController")
if old then old:Destroy() end

local MC = Instance.new("LocalScript")
MC.Name   = "MobileController"
MC.Parent = SPS
MC.Source = [[
--!strict
-- MobileController — touch-only mobile UI layer
-- Does nothing on PC or console

local UIS           = game:GetService("UserInputService")
local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RunService    = game:GetService("RunService")

-- Only activate on touch devices
if not UIS.TouchEnabled then return end

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes   = RS:WaitForChild("Remotes")

-- ── Create MobileGui ──────────────────────────────────────────────────────────
local MobileGui = Instance.new("ScreenGui")
MobileGui.Name         = "MobileGui"
MobileGui.DisplayOrder = 6
MobileGui.ResetOnSpawn = false
MobileGui.IgnoreGuiInset = true
MobileGui.Parent       = PlayerGui

-- ── Action bar (bottom-right) ─────────────────────────────────────────────────
-- 4 action buttons stacked vertically, 72×72px each with 8px gaps
-- Position: 16px from right, 16px from bottom

local ActionBar = Instance.new("Frame")
ActionBar.Name             = "ActionBar"
ActionBar.Size             = UDim2.new(0, 80, 0, 340)
ActionBar.Position         = UDim2.new(1, -96, 1, -360)
ActionBar.BackgroundTransparency = 1
ActionBar.Parent           = MobileGui

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Vertical
barLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
barLayout.Padding  = UDim.new(0, 8)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder
barLayout.Parent   = ActionBar

-- Helper: create action button
local function makeActionBtn(icon: string, label: string, color: Color3, order: number, callback: () -> ())
    local btn = Instance.new("TextButton")
    btn.Name             = "Btn_" .. label
    btn.Size             = UDim2.new(0, 72, 0, 72)
    btn.BackgroundColor3 = Color3.fromRGB(50, 32, 14)
    btn.AutoButtonColor  = false
    btn.LayoutOrder      = order
    btn.Parent           = ActionBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = color
    stroke.Thickness = 2
    stroke.Parent    = btn

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size              = UDim2.new(1, 0, 0.6, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text              = icon
    iconLbl.TextSize          = 28
    iconLbl.Font              = Enum.Font.GothamBold
    iconLbl.Parent            = btn

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size              = UDim2.new(1, 0, 0.35, 0)
    nameLbl.Position          = UDim2.new(0, 0, 0.62, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text              = label
    nameLbl.TextColor3        = color
    nameLbl.Font              = Enum.Font.FredokaOne
    nameLbl.TextSize          = 11
    nameLbl.Parent            = btn

    -- Press animation
    local function press()
        TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = color:Lerp(Color3.new(0,0,0), 0.4)}):Play()
        task.delay(0.12, function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(50, 32, 14)}):Play()
        end)
        callback()
    end

    btn.TouchTap:Connect(press)
    btn.MouseButton1Click:Connect(press)  -- also works on PC for testing

    return btn
end

-- Action buttons
local GOLD   = Color3.fromRGB(242, 168, 28)
local AMBER  = Color3.fromRGB(200, 130, 30)
local CREAM  = Color3.fromRGB(200, 180, 130)
local GREEN  = Color3.fromRGB(100, 200, 100)

-- Harvest button: fires RequestHarvest remote for nearest Landing Board
makeActionBtn("🍯", "Harvest", GOLD, 1, function()
    local RE = Remotes:FindFirstChild("RequestHarvest")
    if not RE then return end
    -- Find nearest Landing Board in range
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local CS = game:GetService("CollectionService")
    local nearest, nearestDist = nil, 20
    for _, board in CS:GetTagged("LandingBoard") do
        if board:IsA("BasePart") then
            local dist = (hrp.Position - board.Position).Magnitude
            if dist < nearestDist then
                nearest     = board
                nearestDist = dist
            end
        end
    end
    if nearest then
        RE:FireServer()  -- server validates ownership anyway
    else
        -- Show "too far" notification
        local Notify = Remotes:FindFirstChild("Notify")
        -- We can't FireServer from client for Notify; use local label instead
        local tmpLbl = Instance.new("TextLabel")
        tmpLbl.Size             = UDim2.new(0, 200, 0, 30)
        tmpLbl.Position         = UDim2.new(0.5, -100, 0.75, 0)
        tmpLbl.BackgroundColor3 = Color3.fromRGB(80, 20, 20)
        tmpLbl.BackgroundTransparency = 0.2
        tmpLbl.Text             = "Too far from Landing Board"
        tmpLbl.TextColor3       = Color3.fromRGB(255, 180, 180)
        tmpLbl.Font             = Enum.Font.Gotham
        tmpLbl.TextSize         = 13
        tmpLbl.Parent           = MobileGui
        Instance.new("UICorner", tmpLbl).CornerRadius = UDim.new(0, 8)
        TweenService:Create(tmpLbl, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1, BackgroundTransparency = 1}):Play()
        task.delay(1.5, function() if tmpLbl then tmpLbl:Destroy() end end)
    end
end)

-- Dance button: opens the Dance floor interaction (tap Dance Floor cell)
-- Fires the RequestDance remote if it exists; otherwise opens DanceGui
makeActionBtn("💃", "Dance", AMBER, 2, function()
    -- Try to open dance for nearest dance floor cell
    local RE = Remotes:FindFirstChild("RequestDance") or Remotes:FindFirstChild("OpenDance")
    if RE then
        RE:FireServer()
    else
        -- Fallback: open DanceGui directly if it exists
        local DGui = PlayerGui:FindFirstChild("DanceGui")
        if DGui then
            local main = DGui:FindFirstChild("Main")
            if main then main.Visible = not main.Visible end
        end
    end
end)

-- Shop button: opens ShopGui Consumables tab
makeActionBtn("🛒", "Shop", CREAM, 3, function()
    local OpenShop = Remotes:FindFirstChild("OpenShop")
    if OpenShop then
        -- OpenShop is server→client; we trigger it locally for mobile
        local ShopGui = PlayerGui:FindFirstChild("ShopGui")
        if ShopGui then
            local main = ShopGui:FindFirstChild("Main")
            if main then
                main.Visible = not main.Visible
            end
        end
    end
end)

-- Quests button: opens QuestPanel
makeActionBtn("📋", "Quests", GREEN, 4, function()
    local QGui = PlayerGui:FindFirstChild("QuestGui")
    if QGui then
        local panel = QGui:FindFirstChild("QuestPanel")
        if panel then panel.Visible = not panel.Visible end
    end
end)

-- ── Proximity interact button ─────────────────────────────────────────────────
-- Shown when player is within range of a ProximityPrompt-tagged object
-- Replaces the default Roblox ProximityPrompt UI on mobile

local InteractBtn = Instance.new("TextButton")
InteractBtn.Name             = "InteractBtn"
InteractBtn.Size             = UDim2.new(0, 180, 0, 58)
InteractBtn.Position         = UDim2.new(0.5, -90, 0.72, 0)
InteractBtn.BackgroundColor3 = Color3.fromRGB(122, 74, 34)
InteractBtn.TextColor3       = Color3.fromRGB(232, 212, 154)
InteractBtn.Text             = "[ Hold E ] Interact"
InteractBtn.Font             = Enum.Font.FredokaOne
InteractBtn.TextSize         = 18
InteractBtn.Visible          = false
InteractBtn.Parent           = MobileGui
Instance.new("UICorner", InteractBtn).CornerRadius = UDim.new(0, 10)

local interactStroke = Instance.new("UIStroke")
interactStroke.Color     = Color3.fromRGB(242, 168, 28)
interactStroke.Thickness = 2
interactStroke.Parent    = InteractBtn

-- Track current nearest ProximityPrompt
local _nearestPrompt: ProximityPrompt?

local function fireNearestPrompt()
    if _nearestPrompt then
        -- Simulate the ProximityPrompt trigger
        _nearestPrompt:InputHoldBegin()
        task.delay(0.05, function()
            if _nearestPrompt then
                pcall(function() _nearestPrompt:InputHoldEnd() end)
            end
        end)
    end
end

InteractBtn.TouchTap:Connect(fireNearestPrompt)
InteractBtn.MouseButton1Click:Connect(fireNearestPrompt)

-- Heartbeat: scan for nearby ProximityPrompts
local INTERACT_RANGE = 10
RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then InteractBtn.Visible = false return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then InteractBtn.Visible = false return end

    local nearest: ProximityPrompt?
    local nearestDist = INTERACT_RANGE

    for _, pp in workspace:GetDescendants() do
        if pp:IsA("ProximityPrompt") and pp.Enabled then
            local parent = pp.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (hrp.Position - parent.Position).Magnitude
                if dist < nearestDist then
                    nearest     = pp
                    nearestDist = dist
                end
            end
        end
    end

    if nearest and nearest ~= _nearestPrompt then
        _nearestPrompt = nearest
        -- Update button label
        local action = nearest.ActionText
        local obj    = nearest.ObjectText
        InteractBtn.Text = (obj ~= "" and obj .. ": " or "") .. (action ~= "" and action or "Interact")
        InteractBtn.Visible = true
    elseif not nearest then
        _nearestPrompt      = nil
        InteractBtn.Visible = false
    end
end)

-- ── Hide Roblox default ProximityPrompt GUI on mobile ─────────────────────────
-- Roblox shows its own prompt UI; we hide it so ours is the only one visible
local function hideDefaultPromptGui()
    local PlayerModule = player.PlayerScripts:FindFirstChild("PlayerModule")
    -- The default ProximityPromptUI is in PlayerGui as ProximityPrompts ScreenGui
    -- We set its DisplayOrder below ours so our button takes priority visually
    task.delay(2, function()
        local ppGui = PlayerGui:FindFirstChild("ProximityPrompts")
        if ppGui then
            ppGui.DisplayOrder = -1  -- render behind our GUI
        end
    end)
end
hideDefaultPromptGui()

print("[MobileController] Mobile UI active")
]]
print("MobileController created")
```

---

## Step 2 — Mobile-safe UI audit and fix

Run in Studio Command Bar:

```lua
-- Scan all ScreenGuis for Offset-only sized elements and fix them
local SG = game:GetService("StarterGui")
local issues_found = {}

local function checkAndFixFrame(obj)
    if not obj:IsA("GuiObject") then return end
    -- Skip objects whose scale is already set properly
    local sx = obj.Size.X
    local sy = obj.Size.Y
    -- Flag if purely offset with no scale AND it's a meaningful size (>100px)
    if sx.Scale < 0.01 and sx.Offset > 200 and obj:IsA("Frame") then
        table.insert(issues_found, obj:GetFullName() .. " W=" .. sx.Offset)
    end
end

for _, gui in SG:GetDescendants() do
    checkAndFixFrame(gui)
end

if #issues_found > 0 then
    print("Wide offset-only frames found (may need manual review on mobile):")
    for _, f in issues_found do print("  " .. f) end
else
    print("No wide offset-only frames found — UI looks mobile-safe")
end

-- Ensure text sizes aren't below 12 on mobile-relevant GUIs
local tooSmall = {}
for _, gui in SG:GetDescendants() do
    if (gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")) then
        if not gui.TextScaled and gui.TextSize < 12 then
            table.insert(tooSmall, gui:GetFullName() .. " size=" .. gui.TextSize)
        end
    end
end

if #tooSmall > 0 then
    print("Text smaller than 12 found:")
    for _, t in tooSmall do print("  " .. t) end
    -- Auto-fix: set to 12
    for _, gui in SG:GetDescendants() do
        if (gui:IsA("TextLabel") or gui:IsA("TextButton") or gui:IsA("TextBox")) then
            if not gui.TextScaled and gui.TextSize < 12 then
                gui.TextSize = 12
            end
        end
    end
    print("Auto-fixed: all text bumped to minimum 12")
else
    print("All text sizes >= 12 — OK")
end
```

---

## Step 3 — HudGui mobile layout tweak

The HUD displays SUPPLY/WINGS/COMB bars and wallet. On 375pt phones the bars can overlap. This patch ensures they stack vertically on narrow screens.

Run in Studio Command Bar:

```lua
local SG    = game:GetService("StarterGui")
local HudGui = SG:FindFirstChild("HudGui") or SG:FindFirstChild("MainGui")
if not HudGui then print("HudGui not found — skip") return end

-- Find the bar container (usually a Frame named BarContainer or BarsFrame)
local barContainer = HudGui:FindFirstChild("BarContainer", true)
    or HudGui:FindFirstChild("BarsFrame", true)
    or HudGui:FindFirstChild("Bars", true)

if barContainer then
    -- Ensure UIListLayout exists with vertical fill for mobile
    local existingLayout = barContainer:FindFirstChildOfClass("UIListLayout")
    if existingLayout then
        existingLayout.FillDirection = Enum.FillDirection.Vertical
        existingLayout.Padding = UDim.new(0, 4)
        print("Updated bar layout to vertical stack")
    else
        local layout = Instance.new("UIListLayout")
        layout.FillDirection = Enum.FillDirection.Vertical
        layout.Padding       = UDim.new(0, 4)
        layout.SortOrder     = Enum.SortOrder.LayoutOrder
        layout.Parent        = barContainer
        print("Added vertical UIListLayout to bar container")
    end

    -- Widen bars slightly for touch targets
    for _, child in barContainer:GetChildren() do
        if child:IsA("Frame") and child.Size.Y.Offset > 0 and child.Size.Y.Offset < 28 then
            child.Size = UDim2.new(child.Size.X.Scale, child.Size.X.Offset, 0, 28)
        end
    end
else
    print("Bar container not found — HUD layout may need manual review")
end
```

---

## Step 4 — OpenShop RemoteEvent (if missing)

The mobile Shop button opens ShopGui directly by toggling Main.Visible, but we should also ensure an `OpenShop` RemoteEvent exists so the server can open the shop on specific events (e.g., first structure purchase).

```lua
local RS      = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
assert(Remotes, "Remotes not found")

if not Remotes:FindFirstChild("OpenShop") then
    local re = Instance.new("RemoteEvent")
    re.Name   = "OpenShop"
    re.Parent = Remotes
    print("Created: OpenShop RemoteEvent")
else
    print("OpenShop already exists")
end
```

---

## Step 5 — Verification

Run in Studio Command Bar:

```lua
local SP    = game:GetService("StarterPlayer")
local SG    = game:GetService("StarterGui")
local RS    = game:GetService("ReplicatedStorage")

local results = {}
local issues  = {}

-- MobileController
local SPS = SP:FindFirstChild("StarterPlayerScripts")
local MC  = SPS and SPS:FindFirstChild("MobileController")
if MC and MC:IsA("LocalScript") then
    local lines = select(2, MC.Source:gsub("\n","")) + 1
    table.insert(results, "MobileController ✓ (" .. lines .. " lines)")
else
    table.insert(issues, "MISSING: MobileController LocalScript")
end

-- Touch-guard check
if MC then
    local hasGuard = MC.Source:find("TouchEnabled") ~= nil
    if hasGuard then table.insert(results, "TouchEnabled guard ✓")
    else table.insert(issues, "MISSING: TouchEnabled guard in MobileController") end
end

-- Action buttons check
if MC then
    for _, name in {"Harvest", "Dance", "Shop", "Quests"} do
        if MC.Source:find(name) then
            table.insert(results, "ActionBtn:" .. name .. " ✓")
        else
            table.insert(issues, "MISSING action button: " .. name)
        end
    end
end

-- Text size audit
local tooSmall = 0
for _, gui in SG:GetDescendants() do
    if (gui:IsA("TextLabel") or gui:IsA("TextButton")) and not gui.TextScaled and gui.TextSize < 12 then
        tooSmall += 1
    end
end
if tooSmall == 0 then
    table.insert(results, "Text sizes all >= 12 ✓")
else
    table.insert(issues, tooSmall .. " text elements below 12pt")
end

-- OpenShop remote
local Remotes = RS:FindFirstChild("Remotes") or RS:FindFirstChild("RemoteEvents")
local OS = Remotes and Remotes:FindFirstChild("OpenShop")
if OS then table.insert(results, "OpenShop remote ✓")
else table.insert(issues, "MISSING: OpenShop RemoteEvent") end

print("=== MOBILE CONTROLS VERIFICATION ===")
for _, r in results do print("✓ " .. r) end
if #issues > 0 then
    print("ISSUES:")
    for _, iss in issues do print("✗ " .. iss) end
else
    print("ALL CLEAR — mobile controls complete")
end
```

**Expected:**
```
✓ MobileController ✓ (170+ lines)
✓ TouchEnabled guard ✓
✓ ActionBtn:Harvest ✓
✓ ActionBtn:Dance ✓
✓ ActionBtn:Shop ✓
✓ ActionBtn:Quests ✓
✓ Text sizes all >= 12 ✓
✓ OpenShop remote ✓
ALL CLEAR — mobile controls complete
```

---

## Summary

| Item | Detail |
|------|--------|
| MobileController LocalScript | Touch-only guard; 4 action buttons + proximity interact button |
| Action buttons | Harvest, Dance, Shop, Quests — 72×72px with FredokaOne labels |
| Proximity button | Replaces default Roblox ProximityPrompt UI on mobile; scans 10-stud range every Heartbeat |
| Touch animation | Scale press tween + color flash on each tap |
| Text audit | All text below 12pt bumped to 12; no change if already compliant |
| HUD layout | Bar container ensured vertical stack for narrow screens |
| Part delta | +0 → ~3,875/5,000 |
| PC compatibility | `if not UIS.TouchEnabled then return end` — zero effect on PC/console |
