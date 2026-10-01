# Dispatch 140 — Hive Prestige System
## Cycle 14 · A Bee's World

**Feature:** A `PrestigeService` server Script plus a `PrestigeController` LocalScript. When a player reaches Prestige Level 3 (maximum comb slots unlocked, total honey earned ≥ 5,000), they can press a "Prestige Hive" button to reset their hive to 3 starter slots in exchange for a permanent `PrestigeLevel` increment that grants multiplier bonuses in subsequent playthroughs. Kids experience a proud ceremony; adults get a meaningful rebirth loop. Part budget: +1 permanent (PrestigeService Script).
**Part budget impact:** +1 permanent → **4,148 / 5,000**
**Execution order:** After dispatch 139 (Bear Attack Warning System)

---

## DESIGN

### Prestige levels and bonuses

| Prestige | Requirement | Permanent bonus (carries through resets) |
|----------|-------------|------------------------------------------|
| P0 | Starting state | No bonus |
| P1 | Honey earned ≥ 5,000, CombCellCount ≥ 9 | +10% all honey yield |
| P2 | P1 + honey earned ≥ 15,000 | +20% all honey yield, +5% foraging speed |
| P3 | P2 + honey earned ≥ 40,000 | +30% all honey yield, +10% foraging speed, +5% propolis rate |

`HoneyEarned` is a separate running-total attribute (not `HoneyCount`) incremented server-side by ForagingService on each harvest.

### Reset behaviour

On prestige:
1. `CombCellCount` → 3 (back to starter)
2. `HoneyCount` → 0
3. `PropolisCount` → 0
4. `PropolisUpgrades` → `""` (cleared)
5. `CombState` → `"honey,,"` (3-slot starter layout)
6. `PrestigeLevel` → incremented by 1
7. `HoneyEarned` → 0 (counter resets for next prestige threshold)

### Eligibility check

`CombCellCount >= 9 AND HoneyEarned >= 5000 × (2^PrestigeLevel)` — exponential threshold scaling for P2/P3.

### Client UI

- Golden "⬆ Prestige Hive" button: Position `{0,8,0.5,32}` (below Propolis Shop toggle on left side), Size `{0,120,0,36}`, Honey Gold background, visible only when eligible
- On press: confirmation modal (`"Reset your hive for +P bonus?  [Confirm] [Cancel]"`)
- On confirm: fires `RequestPrestige` RemoteEvent; server validates and processes; client receives `PrestigeGranted` event with new level
- Prestige ceremony: golden screen flash (1s) + spiral confetti burst (reuses dispatch 131 confetti pattern) + 3s headline "✨ Prestige [N]! Hive reborn!" in the milestone overlay

### RemoteEvents

| Event | Direction | Payload |
|-------|-----------|---------|
| `RequestPrestige` | Client → Server | `{}` |
| `PrestigeGranted` | Server → Client | `{newLevel: number}` |

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PrestigeService` | New Script in ServerScriptService (+1 permanent) |
| `PrestigeController` | New LocalScript in StarterPlayerScripts (+0 permanent) |

---

## STEP A — Create PrestigeService (server)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("PrestigeService") then
    print("⏭️  PrestigeService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name = "PrestigeService"
    svc.Source = [[
--!strict
-- PrestigeService — dispatch 140
-- Handles prestige validation, reset, and bonus tracking.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local eventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    or (function()
        local f = Instance.new("Folder"); f.Name = "RemoteEvents"; f.Parent = ReplicatedStorage; return f
    end)()

local reqPrestige_140: RemoteEvent = eventsFolder:FindFirstChild("RequestPrestige") :: RemoteEvent
    or (function()
        local e = Instance.new("RemoteEvent"); e.Name = "RequestPrestige"; e.Parent = eventsFolder; return e
    end)()

local prestigeGranted_140: RemoteEvent = eventsFolder:FindFirstChild("PrestigeGranted") :: RemoteEvent
    or (function()
        local e = Instance.new("RemoteEvent"); e.Name = "PrestigeGranted"; e.Parent = eventsFolder; return e
    end)()

-- ── Eligibility ───────────────────────────────────────────────────
local function isEligible_140(player: Player): boolean
    local cells       = tonumber(player:GetAttribute("CombCellCount"))  or 0
    local earned      = tonumber(player:GetAttribute("HoneyEarned"))    or 0
    local prestige    = tonumber(player:GetAttribute("PrestigeLevel"))  or 0
    local threshold   = 5000 * (2 ^ prestige)
    return cells >= 9 and earned >= threshold
end

-- ── Prestige reset ────────────────────────────────────────────────
local function applyPrestige_140(player: Player)
    if not isEligible_140(player) then return end
    local newLevel = (tonumber(player:GetAttribute("PrestigeLevel")) or 0) + 1
    player:SetAttribute("PrestigeLevel",    newLevel)
    player:SetAttribute("CombCellCount",    3)
    player:SetAttribute("HoneyCount",       0)
    player:SetAttribute("PropolisCount",    0)
    player:SetAttribute("PropolisUpgrades", "")
    player:SetAttribute("CombState",        "honey,,")
    player:SetAttribute("HoneyEarned",      0)
    prestigeGranted_140:FireClient(player, {newLevel = newLevel})
    print("[PrestigeService] " .. player.Name .. " prestiged to P" .. newLevel)
end

-- ── RemoteEvent handler ───────────────────────────────────────────
reqPrestige_140.OnServerEvent:Connect(function(player: Player)
    -- Server-side validation: never trust client
    if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
    applyPrestige_140(player)
end)

print("[PrestigeService] Ready — prestige system active")
]]
    svc.Parent = SSS
    print("✅ PrestigeService created in ServerScriptService")
end
```

---

## STEP B — Create PrestigeController (client)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("PrestigeController") then
    print("⏭️  PrestigeController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PrestigeController"
    ctrl.Source = [[
--!strict
-- PrestigeController — dispatch 140
-- Prestige button, confirmation modal, and ceremony visuals.

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local GOLD_140  = Color3.fromRGB(242, 168, 28)
local DARK_140  = Color3.fromRGB(160, 100,  0)
local WHITE_140 = Color3.fromRGB(255, 255, 255)
local RED_140   = Color3.fromRGB(200,  50, 20)

-- ── Eligibility check ─────────────────────────────────────────────
local function isEligible_140(): boolean
    local cells    = tonumber(player:GetAttribute("CombCellCount")) or 0
    local earned   = tonumber(player:GetAttribute("HoneyEarned"))   or 0
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    local threshold = 5000 * (2 ^ prestige)
    return cells >= 9 and earned >= threshold
end

-- ── GUI ──────────────────────────────────────────────────────────
local sg_140: ScreenGui? = nil
local prestigeBtn_140: TextButton? = nil
local modalFrame_140: Frame? = nil
local modalVisible_140 = false

local function ensureGui_140()
    if sg_140 and sg_140.Parent then return end
    sg_140 = Instance.new("ScreenGui")
    sg_140.Name          = "PrestigeGui"
    sg_140.ResetOnSpawn  = false
    sg_140.DisplayOrder  = 20
    sg_140.Parent        = playerGui
end

local function ensurePrestigeBtn_140()
    ensureGui_140()
    if prestigeBtn_140 and prestigeBtn_140.Parent then return end

    local btn = Instance.new("TextButton")
    btn.Name                  = "PrestigeButton"
    btn.Size                  = UDim2.new(0, 120, 0, 36)
    btn.Position              = UDim2.new(0, 8, 0.5, 32)
    btn.BackgroundColor3      = GOLD_140
    btn.BorderSizePixel       = 0
    btn.Font                  = Enum.Font.GothamBold
    btn.TextSize              = 13
    btn.TextColor3            = WHITE_140
    btn.Text                  = "⬆ Prestige Hive"
    btn.Visible               = false
    btn.Parent                = sg_140 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = btn
    local stroke = Instance.new("UIStroke"); stroke.Color = DARK_140; stroke.Thickness = 1.5; stroke.Parent = btn

    btn.Activated:Connect(function() showModal_140() end)
    prestigeBtn_140 = btn
end

-- ── Modal ─────────────────────────────────────────────────────────
local function showModal_140()
    ensureGui_140()
    if modalVisible_140 then return end
    modalVisible_140 = true

    local overlay = Instance.new("Frame")
    overlay.Size                  = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3      = Color3.fromRGB(0,0,0)
    overlay.BackgroundTransparency = 0.5
    overlay.BorderSizePixel       = 0
    overlay.Parent                = sg_140 :: ScreenGui

    local panel = Instance.new("Frame")
    panel.Size                = UDim2.new(0, 300, 0, 130)
    panel.Position            = UDim2.new(0.5, -150, 0.5, -65)
    panel.BackgroundColor3    = Color3.fromRGB(40, 25, 8)
    panel.BorderSizePixel     = 0
    panel.Parent              = overlay
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,10); corner.Parent = panel
    local stroke = Instance.new("UIStroke"); stroke.Color = GOLD_140; stroke.Thickness = 2; stroke.Parent = panel

    local lbl = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1,-16,0,60)
    lbl.Position            = UDim2.new(0,8,0,10)
    lbl.BackgroundTransparency = 1
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextSize            = 13
    lbl.TextColor3          = WHITE_140
    lbl.TextWrapped         = true
    lbl.Text                = "Reset your hive for Prestige bonus?\nHoney, propolis & upgrades will reset."
    lbl.Parent              = panel

    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    local bonusLbl = Instance.new("TextLabel")
    bonusLbl.Size                = UDim2.new(1,-16,0,20)
    bonusLbl.Position            = UDim2.new(0,8,0,68)
    bonusLbl.BackgroundTransparency = 1
    bonusLbl.Font                = Enum.Font.GothamBold
    bonusLbl.TextSize            = 12
    bonusLbl.TextColor3          = GOLD_140
    bonusLbl.Text                = "You will reach Prestige " .. (prestige + 1) .. " — +" .. ((prestige+1)*10) .. "% honey yield"
    bonusLbl.Parent              = panel

    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size             = UDim2.new(0, 110, 0, 32)
    confirmBtn.Position         = UDim2.new(0, 16, 0, 92)
    confirmBtn.BackgroundColor3 = GOLD_140
    confirmBtn.Font             = Enum.Font.GothamBold
    confirmBtn.TextSize         = 13
    confirmBtn.TextColor3       = WHITE_140
    confirmBtn.Text             = "✨ Confirm"
    confirmBtn.Parent           = panel
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,6); cc.Parent = confirmBtn

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size             = UDim2.new(0, 110, 0, 32)
    cancelBtn.Position         = UDim2.new(1,-126,0,92)
    cancelBtn.BackgroundColor3 = RED_140
    cancelBtn.Font             = Enum.Font.GothamBold
    cancelBtn.TextSize         = 13
    cancelBtn.TextColor3       = WHITE_140
    cancelBtn.Text             = "✕ Cancel"
    cancelBtn.Parent           = panel
    local cx = Instance.new("UICorner"); cx.CornerRadius = UDim.new(0,6); cx.Parent = cancelBtn

    local function closeModal()
        overlay:Destroy()
        modalVisible_140 = false
    end

    confirmBtn.Activated:Connect(function()
        closeModal()
        -- Fire server request
        local evFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
        local reqEvent = evFolder and evFolder:FindFirstChild("RequestPrestige") :: RemoteEvent?
        if reqEvent then reqEvent:FireServer() end
    end)
    cancelBtn.Activated:Connect(closeModal)

    modalFrame_140 = panel
end

-- ── Prestige ceremony ─────────────────────────────────────────────
local function playCeremony_140(newLevel: number)
    ensureGui_140()
    local sg = sg_140 :: ScreenGui

    -- Golden screen flash
    local flash = Instance.new("Frame")
    flash.Size                  = UDim2.new(1,0,1,0)
    flash.BackgroundColor3      = GOLD_140
    flash.BackgroundTransparency = 0.2
    flash.BorderSizePixel       = 0
    flash.Parent                = sg
    TweenService:Create(flash,
        TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    ).Completed:Connect(function() flash:Destroy() end)
    TweenService:Create(flash,
        TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    ):Play()

    -- Headline banner
    local banner = Instance.new("Frame")
    banner.Size                  = UDim2.new(0, 320, 0, 56)
    banner.Position              = UDim2.new(0.5, -160, 0.5, -28)
    banner.BackgroundColor3      = Color3.fromRGB(40, 25, 8)
    banner.BackgroundTransparency = 0.1
    banner.BorderSizePixel       = 0
    banner.Parent                = sg
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,12); bc.Parent = banner
    local bs = Instance.new("UIStroke"); bs.Color = GOLD_140; bs.Thickness = 2.5; bs.Parent = banner

    local headline = Instance.new("TextLabel")
    headline.Size                = UDim2.new(1,-12,1,0)
    headline.Position            = UDim2.new(0,6,0,0)
    headline.BackgroundTransparency = 1
    headline.Font                = Enum.Font.GothamBold
    headline.TextSize            = 20
    headline.TextColor3          = GOLD_140
    headline.TextXAlignment      = Enum.TextXAlignment.Center
    headline.Text                = "✨ Prestige " .. newLevel .. "! Hive reborn!"
    headline.Parent              = banner

    task.delay(3, function()
        TweenService:Create(banner,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}
        ):Play()
        TweenService:Create(headline,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ).Completed:Connect(function() banner:Destroy() end)
        TweenService:Create(headline,
            TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {TextTransparency = 1}
        ):Play()
    end)
end

-- ── Eligibility refresh ───────────────────────────────────────────
local function refreshEligibility_140()
    ensurePrestigeBtn_140()
    local eligible = isEligible_140()
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    local btn = prestigeBtn_140 :: TextButton
    btn.Visible = eligible and prestige < 3
    if eligible then
        btn.Text = "⬆ Prestige Hive (P" .. (prestige + 1) .. ")"
    end
end

-- ── RemoteEvent listener ──────────────────────────────────────────
task.spawn(function()
    local evFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
    local grantedEvent = (evFolder :: Folder):WaitForChild("PrestigeGranted", 10) :: RemoteEvent
    grantedEvent.OnClientEvent:Connect(function(data: {newLevel: number})
        local newLevel = data and data.newLevel or 1
        playCeremony_140(newLevel)
        refreshEligibility_140()
    end)
end)

-- ── Listeners ─────────────────────────────────────────────────────
task.wait(2)
refreshEligibility_140()
player:GetAttributeChangedSignal("HoneyEarned"):Connect(refreshEligibility_140)
player:GetAttributeChangedSignal("CombCellCount"):Connect(refreshEligibility_140)
player:GetAttributeChangedSignal("PrestigeLevel"):Connect(refreshEligibility_140)

print("[PrestigeController] Ready — prestige UI active")
]]
    ctrl.Parent = SPS
    print("✅ PrestigeController created in StarterPlayerScripts")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SSS  = game:GetService("ServerScriptService")
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local RS   = game:GetService("ReplicatedStorage")
local evF  = RS:FindFirstChild("RemoteEvents")

local svc  = SSS:FindFirstChild("PrestigeService")
local ctrl = SPS and SPS:FindFirstChild("PrestigeController")
local reqE = evF and evF:FindFirstChild("RequestPrestige")
local grtE = evF and evF:FindFirstChild("PrestigeGranted")

local checks = {}
table.insert(checks, (svc and "✅" or "❌") .. " PrestigeService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (svc and svc.Source:find("isEligible_140", 1, true) and "✅" or "❌") .. " isEligible_140 server validation")
table.insert(checks, (svc and svc.Source:find("applyPrestige_140", 1, true) and "✅" or "❌") .. " applyPrestige_140 reset logic")
table.insert(checks, (svc and svc.Source:find("HoneyEarned", 1, true) and "✅" or "❌") .. " HoneyEarned threshold check")
table.insert(checks, (reqE and "✅" or "❌") .. " RequestPrestige RemoteEvent")
table.insert(checks, (grtE and "✅" or "❌") .. " PrestigeGranted RemoteEvent")
table.insert(checks, (ctrl and "✅" or "❌") .. " PrestigeController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("showModal_140", 1, true) and "✅" or "❌") .. " showModal_140 confirmation")
table.insert(checks, (ctrl and ctrl.Source:find("playCeremony_140", 1, true) and "✅" or "❌") .. " playCeremony_140 golden flash + headline")
table.insert(checks, (ctrl and ctrl.Source:find("refreshEligibility_140", 1, true) and "✅" or "❌") .. " refreshEligibility_140 button show/hide")

print("=== DISPATCH 140 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 140 complete" or "❌ SOME CHECKS FAILED")

print("\nPrestige: P1(5k honey+9cells) | P2(15k) | P3(40k) | each grants +10% honey yield stacking")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PrestigeService (Script — permanent) | +1 |
| PrestigeController (LocalScript; GUI runtime only) | 0 permanent |
| **Dispatch 140 total** | **+1** |
| **Running total** | **4,148 / 5,000** |

---

## NOTES

- `5000 * (2 ^ prestige)` threshold scaling: P1=5k, P2=10k, P3=20k. This exponential curve makes early prestige feel achievable (kids can get P1 in a couple of sessions) while later prestiges require sustained play and strategy.
- `btn.Visible = eligible and prestige < 3` hard-caps prestige at P3. A P3 player can no longer see the button — they've reached the end of the prestige track and the game shifts to pure optimization.
- The confirmation modal shows the specific bonus the player is about to earn (`"+[N*10]% honey yield"`), not generic text. This makes adults feel the trade-off is clearly communicated before they commit to the reset.
- Server-side `isEligible_140` re-validates on `RequestPrestige` receipt. The client check is UX convenience only; the server never trusts it. This prevents a client-side exploit where a player fires the RemoteEvent manually.
- `HoneyEarned` is a separate running total, not `HoneyCount`. This is architecturally important: a player who earned 5,000 honey but then spent it still reaches P1, because the earning threshold rewards *activity*, not *hoarding*. Players who collect frequently (encouraged by dispatch 135's overflow warning) naturally accumulate HoneyEarned faster.
- The prestige ceremony re-uses the same golden color palette as the milestone celebration (dispatch 131) for visual continuity — the player already associates gold flashes with positive achievements.
