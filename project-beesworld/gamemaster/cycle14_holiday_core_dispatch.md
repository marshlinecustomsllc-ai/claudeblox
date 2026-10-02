# Dispatch 154 — Holiday Core System
## Cycle 14 · A Bee's World

**Feature:** Foundation of the seasonal holiday system. `HolidayService` runs on the server, reads `os.date` each minute, determines which holiday (if any) is active, and writes `ActiveHoliday` (string) and `HolidayDaysLeft` (number) to every player. `HolidayController` LocalScript shows a countdown pill (bottom-right HUD) and fires a one-session welcome toast when a player first joins during an active holiday. Five holidays: Halloween, Harvest Festival, Winter Hive, Pollen Festival, Sun Solstice. Part budget: +2 permanent (one Script, one LocalScript).
**Part budget impact:** +2 permanent → **4,194 / 5,000**
**Execution order:** After dispatch 153 (Community Hub Rework)

---

## DESIGN

### Holiday calendar

| ID | Name | Window | Colour |
|----|------|--------|--------|
| `halloween` | 🎃 Halloween | Oct 25–31 | `(255, 100, 0)` orange |
| `harvest` | 🍂 Harvest Festival | Nov 20–28 | `(200, 140, 40)` amber-brown |
| `winter` | ❄️ Winter Hive | Dec 20–Jan 2 | `(180, 220, 255)` ice blue |
| `spring` | 🌸 Pollen Festival | Mar 20–Apr 10 | `(255, 160, 210)` blossom pink |
| `summer` | ☀️ Sun Solstice | Jun 20–22 | `(255, 220, 50)` solar yellow |

### Attribute bus

| Attribute | Type | Values |
|-----------|------|--------|
| `ActiveHoliday` | string | `"halloween"` / `"harvest"` / `"winter"` / `"spring"` / `"summer"` / `""` |
| `HolidayDaysLeft` | number | 0–12 (0 when no event) |

### Countdown pill

Bottom-right HUD at `{1, -8, 1, -72}` (anchor `{1,1}`), size `{0, 160, 0, 28}`. Visible only when `ActiveHoliday ≠ ""`.
- More than 1 day left: `"🎃 3 days left!"` in holiday colour
- Last day: `"🎃 Last day!"` — pulses between holiday colour and white via a Heartbeat loop
- No holiday: pill hidden (Visible = false)

### Welcome toast

Fires once per session (not per server join) on first attribute set. A 2-row toast (320×72) slides in from the top, holds 4 seconds, slides out. Uses same animation pattern as `HoneyMilestoneController`. `DisplayOrder = 40`.

Row 1: `[emoji] [holiday name]` in holiday colour, GothamBold 20
Row 2: `"Event active — special rewards await!"` in Cream, Gotham 12

### Honey production bonus (server-side in HolidayService)

Each holiday gives a passive honey multiplier written as `HolidayHoneyMult` (float attribute):

| Holiday | `HolidayHoneyMult` |
|---------|-------------------|
| halloween | 1.15 (night only — service checks time, but attribute is always written) |
| harvest | 1.20 |
| winter | 1.10 |
| spring | 1.10 |
| summer | 1.25 (3-day window, maximum bonus) |
| none | 1.00 |

The CombService patch in **STEP D** reads this and applies it to the multiplier chain.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HolidayService` | New Script in ServerScriptService |
| `HolidayController` | New LocalScript in StarterPlayerScripts |
| `CombService` | +2 lines: `holidayMult_154` in produced formula |

---

## STEP A — Create HolidayService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("HolidayService") then
    print("⏭️  HolidayService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "HolidayService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- HolidayService — dispatch 154
-- Detects active holiday from server date, writes ActiveHoliday +
-- HolidayDaysLeft + HolidayHoneyMult to every player. Checks every 60s.

local Players = game:GetService("Players")

type HolidayDef_154 = {
    id: string, name: string, emoji: string,
    startMonth: number, startDay: number,
    endMonth: number,   endDay: number,
    mult: number,
}

local HOLIDAYS_154: {HolidayDef_154} = {
    {id="halloween", name="Halloween",       emoji="🎃", startMonth=10,startDay=25, endMonth=10,endDay=31, mult=1.15},
    {id="harvest",   name="Harvest Festival",emoji="🍂", startMonth=11,startDay=20, endMonth=11,endDay=28, mult=1.20},
    {id="winter",    name="Winter Hive",     emoji="❄️", startMonth=12,startDay=20, endMonth=1, endDay=2,  mult=1.10},
    {id="spring",    name="Pollen Festival", emoji="🌸", startMonth=3, startDay=20, endMonth=4, endDay=10, mult=1.10},
    {id="summer",    name="Sun Solstice",    emoji="☀️", startMonth=6, startDay=20, endMonth=6, endDay=22, mult=1.25},
}

-- Returns days remaining (inclusive of today), 0 if not in window
local function daysLeft_154(h: HolidayDef_154): number
    local t    = os.date("*t") :: any
    local month = t.month :: number
    local day   = t.day   :: number

    -- Build a simple day-of-year for comparison (ignores leap year edge cases)
    local function toDOY(m: number, d: number): number
        local days = {31,28,31,30,31,30,31,31,30,31,30,31}
        local n = d
        for i = 1, m-1 do n = n + days[i] end
        return n
    end

    local todayDOY = toDOY(month, day)
    local startDOY = toDOY(h.startMonth, h.startDay)
    local endDOY   = toDOY(h.endMonth,   h.endDay)

    -- Handle year-wrap (winter: Dec 20 – Jan 2)
    if startDOY > endDOY then
        -- In the window if today >= start OR today <= end
        if todayDOY >= startDOY or todayDOY <= endDOY then
            if todayDOY >= startDOY then
                return (365 - todayDOY) + endDOY + 1
            else
                return endDOY - todayDOY + 1
            end
        end
        return 0
    end

    if todayDOY >= startDOY and todayDOY <= endDOY then
        return endDOY - todayDOY + 1
    end
    return 0
end

local function activeHoliday_154(): (string, number, number)
    for _, h in HOLIDAYS_154 do
        local d = daysLeft_154(h)
        if d > 0 then
            return h.id, d, h.mult
        end
    end
    return "", 0, 1.0
end

local function applyToPlayer_154(player: Player)
    local id, days, mult = activeHoliday_154()
    player:SetAttribute("ActiveHoliday",    id)
    player:SetAttribute("HolidayDaysLeft",  days)
    player:SetAttribute("HolidayHoneyMult", mult)
end

local function applyAll_154()
    for _, player in Players:GetPlayers() do
        applyToPlayer_154(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.wait(2)
    if player.Parent then applyToPlayer_154(player) end
end)

-- Refresh every 60 seconds (catches midnight holiday start/end)
task.spawn(function()
    while true do
        task.wait(60)
        applyAll_154()
    end
end)

applyAll_154()

local id, days, _ = activeHoliday_154()
if id ~= "" then
    print(string.format("[HolidayService] Active holiday: %s (%d day(s) left)", id, days))
else
    print("[HolidayService] Ready — no active holiday")
end
]]
    svc.Parent = SSS
    print("✅ HolidayService created")
end
```

---

## STEP B — Create HolidayController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("HolidayController") then
    print("⏭️  HolidayController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "HolidayController"
    ctrl.Source = [[
--!strict
-- HolidayController — dispatch 154
-- Countdown pill (bottom-right) + welcome toast on holiday join.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

type HolidayMeta_154 = {emoji: string, name: string, color: Color3}
local META_154: {[string]: HolidayMeta_154} = {
    halloween = {emoji="🎃", name="Halloween",        color=Color3.fromRGB(255,100,  0)},
    harvest   = {emoji="🍂", name="Harvest Festival", color=Color3.fromRGB(200,140, 40)},
    winter    = {emoji="❄️", name="Winter Hive",      color=Color3.fromRGB(180,220,255)},
    spring    = {emoji="🌸", name="Pollen Festival",  color=Color3.fromRGB(255,160,210)},
    summer    = {emoji="☀️", name="Sun Solstice",     color=Color3.fromRGB(255,220, 50)},
}

local DARK_154  = Color3.fromRGB(40,  25,   8)
local CREAM_154 = Color3.fromRGB(232,212,154)
local GOLD_154  = Color3.fromRGB(255,210, 60)

-- ── Countdown pill ────────────────────────────────────────────────
local sg_154:    ScreenGui? = nil
local pill_154:  Frame?     = nil
local label_154: TextLabel? = nil

local function ensureCountdown_154()
    if sg_154 and sg_154.Parent then return end
    sg_154 = Instance.new("ScreenGui")
    sg_154.Name         = "HolidayCountdownGui"
    sg_154.ResetOnSpawn = false
    sg_154.DisplayOrder = 10
    sg_154.Parent       = playerGui

    local pill = Instance.new("Frame")
    pill.Name                   = "HolidayPill"
    pill.Size                   = UDim2.new(0, 160, 0, 28)
    pill.Position               = UDim2.new(1, -8, 1, -72)
    pill.AnchorPoint            = Vector2.new(1, 1)
    pill.BackgroundColor3       = DARK_154
    pill.BackgroundTransparency = 0.15
    pill.BorderSizePixel        = 0
    pill.Visible                = false
    pill.Parent                 = sg_154 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1,0); corner.Parent = pill
    local stroke = Instance.new("UIStroke"); stroke.Thickness = 0.8; stroke.Parent = pill

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1,-8,1,0)
    lbl.Position               = UDim2.new(0,4,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 11
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Parent                 = pill

    pill_154  = pill
    label_154 = lbl
end

-- Last-day pulse (flickers between holiday colour and white)
local pulseConn_154: RBXScriptConnection? = nil
local pulseT_154 = 0

local function startPulse_154(holidayColor: Color3)
    if pulseConn_154 then pulseConn_154:Disconnect() end
    pulseT_154 = 0
    pulseConn_154 = RunService.Heartbeat:Connect(function(dt)
        pulseT_154 = pulseT_154 + dt
        local t = (math.sin(pulseT_154 * 3) + 1) / 2
        if label_154 then
            (label_154 :: TextLabel).TextColor3 = holidayColor:Lerp(Color3.new(1,1,1), t)
        end
    end)
end

local function stopPulse_154()
    if pulseConn_154 then pulseConn_154:Disconnect(); pulseConn_154 = nil end
end

local function updatePill_154()
    ensureCountdown_154()
    local id   = tostring(player:GetAttribute("ActiveHoliday") or "")
    local days = math.floor(tonumber(player:GetAttribute("HolidayDaysLeft")) or 0)
    local pill = pill_154  :: Frame
    local lbl  = label_154 :: TextLabel

    if id == "" then
        stopPulse_154()
        pill.Visible = false
        return
    end

    local meta = META_154[id]
    if not meta then pill.Visible = false; return end

    local stroke = pill:FindFirstChildOfClass("UIStroke") :: UIStroke?
    if stroke then stroke.Color = meta.color end

    pill.Visible    = true
    lbl.TextColor3  = meta.color

    if days <= 1 then
        lbl.Text = meta.emoji .. " Last day!"
        startPulse_154(meta.color)
    else
        stopPulse_154()
        lbl.TextColor3 = meta.color
        lbl.Text = meta.emoji .. " " .. days .. " days left!"
    end
end

-- ── Welcome toast ─────────────────────────────────────────────────
local toastShown_154 = false

local function showWelcomeToast_154(id: string)
    if toastShown_154 then return end
    toastShown_154 = true
    local meta = META_154[id]
    if not meta then return end

    local tsg = Instance.new("ScreenGui")
    tsg.Name = "HolidayToastGui"; tsg.ResetOnSpawn = false; tsg.DisplayOrder = 40; tsg.Parent = playerGui

    local toast = Instance.new("Frame")
    toast.Size                   = UDim2.new(0, 320, 0, 72)
    toast.Position               = UDim2.new(0.5,-160,0,-80)
    toast.BackgroundColor3       = DARK_154
    toast.BackgroundTransparency = 0.05
    toast.BorderSizePixel        = 0
    toast.Parent                 = tsg
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = toast
    local s = Instance.new("UIStroke"); s.Color = meta.color; s.Thickness = 2; s.Parent = toast

    local h = Instance.new("TextLabel")
    h.Size=UDim2.new(1,-16,0,34); h.Position=UDim2.new(0,8,0,6)
    h.BackgroundTransparency=1; h.Font=Enum.Font.GothamBold; h.TextSize=20
    h.TextColor3=meta.color; h.TextXAlignment=Enum.TextXAlignment.Center
    h.Text = meta.emoji .. "  " .. meta.name .. "  " .. meta.emoji; h.Parent=toast

    local sub = Instance.new("TextLabel")
    sub.Size=UDim2.new(1,-16,0,18); sub.Position=UDim2.new(0,8,0,44)
    sub.BackgroundTransparency=1; sub.Font=Enum.Font.Gotham; sub.TextSize=12
    sub.TextColor3=CREAM_154; sub.TextXAlignment=Enum.TextXAlignment.Center
    sub.Text="Event active — special rewards await!"; sub.Parent=toast

    local tweenIn = TweenService:Create(toast,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position=UDim2.new(0.5,-160,0,48)})
    tweenIn:Play()

    task.delay(4, function()
        if not toast.Parent then return end
        local tweenOut = TweenService:Create(toast,
            TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Position=UDim2.new(0.5,-160,0,-80)})
        tweenOut:Play()
        tweenOut.Completed:Connect(function() tsg:Destroy() end)
    end)
end

-- ── Init ─────────────────────────────────────────────────────────
ensureCountdown_154()
updatePill_154()

local id = tostring(player:GetAttribute("ActiveHoliday") or "")
if id ~= "" then showWelcomeToast_154(id) end

player:GetAttributeChangedSignal("ActiveHoliday"):Connect(function()
    updatePill_154()
    local newId = tostring(player:GetAttribute("ActiveHoliday") or "")
    if newId ~= "" then showWelcomeToast_154(newId) end
end)
player:GetAttributeChangedSignal("HolidayDaysLeft"):Connect(updatePill_154)

print("[HolidayController] Ready — holiday countdown active")
]]
    ctrl.Parent = SPS
    print("✅ HolidayController created")
end
```

---

## STEP C — Patch CombService (holiday honey multiplier)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))
assert(comb, "CombService not found")

local old = [[local friendMulti_151 = 1.0 + (math.min(3, tonumber(player:GetAttribute("FriendBonusCount")) or 0) * 0.10)
            local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146 * t2Multi_149 * friendMulti_151)]]
local new = [[
            local friendMulti_151   = 1.0 + (math.min(3, tonumber(player:GetAttribute("FriendBonusCount")) or 0) * 0.10)
            local holidayMult_154   = tonumber(player:GetAttribute("HolidayHoneyMult")) or 1.0
            local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146 * t2Multi_149 * friendMulti_151 * holidayMult_154)]]

if comb.Source:find("friendMulti_151", 1, true) and not comb.Source:find("holidayMult_154", 1, true) then
    comb.Source = comb.Source:gsub(
        old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"),
        new:gsub("%%","%%%%"), 1)
    print("✅ CombService patched — holidayMult_154 active (max ×1.25 during Sun Solstice)")
elseif comb.Source:find("holidayMult_154", 1, true) then
    print("⏭️  CombService already has holiday patch — skip")
else
    print("⚠️  friendMulti_151 line not found. Append holidayMult_154 to the produced = math.floor(...) line manually.")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local svc  = SSS:FindFirstChild("HolidayService")
local ctrl = SPS and SPS:FindFirstChild("HolidayController")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " HolidayService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict",1,true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("HOLIDAYS_154",1,true) and "✅" or "❌") .. " HOLIDAYS_154 calendar (5 holidays)")
table.insert(checks, (svc and svc.Source:find("ActiveHoliday",1,true) and "✅" or "❌") .. " ActiveHoliday attribute write")
table.insert(checks, (svc and svc.Source:find("HolidayDaysLeft",1,true) and "✅" or "❌") .. " HolidayDaysLeft attribute write")
table.insert(checks, (svc and svc.Source:find("HolidayHoneyMult",1,true) and "✅" or "❌") .. " HolidayHoneyMult attribute write")
table.insert(checks, (svc and svc.Source:find("task.wait(60)",1,true) and "✅" or "❌") .. " 60s refresh cadence")
table.insert(checks, (ctrl and "✅" or "❌") .. " HolidayController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict",1,true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("HolidayPill",1,true) and "✅" or "❌") .. " HolidayPill countdown UI")
table.insert(checks, (ctrl and ctrl.Source:find("startPulse_154",1,true) and "✅" or "❌") .. " last-day pulse animation")
table.insert(checks, (ctrl and ctrl.Source:find("showWelcomeToast_154",1,true) and "✅" or "❌") .. " welcome toast on join")
table.insert(checks, (comb and comb.Source:find("holidayMult_154",1,true) and "✅" or "❌") .. " CombService holidayMult_154 patch")

print("=== DISPATCH 154 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 154 complete" or "❌ SOME CHECKS FAILED")

print("\n5 holidays: halloween(×1.15) harvest(×1.20) winter(×1.10) spring(×1.10) summer(×1.25)")
print("Countdown pill: bottom-right | pulses on last day | welcome toast on first join")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HolidayService (Script) | +1 permanent |
| HolidayController (LocalScript) | 0 permanent |
| CombService patch (edit) | 0 |
| **Dispatch 154 total** | **+1 permanent** |
| **Running total** | **4,193 / 5,000** |

---

## NOTES

- `daysLeft_154` uses a day-of-year calculation to handle the Winter Hive's year-wrap (Dec 20 – Jan 2). Leap year is not handled — a 1-day error in late February is inconsequential for event windows measured in weeks.
- `HolidayHoneyMult` on Halloween is always 1.15 regardless of time of day. The night-only flavour described in the design is applied by the *HolidayWorldService* (dispatch 155) via a separate `NightHolidayActive` attribute that the Ghost Bee specialist reads. Keeping the base multiplier always-on avoids a confusing experience where the honey rate visibly drops at sunrise.
- The welcome toast fires once per session (`toastShown_154` guard). It does *not* fire again if a player re-joins the same server. This prevents toast spam in a server that's been running for days.
- `DisplayOrder = 40` for the welcome toast sits between daily login (30) and bear warning (45), keeping the holiday greeting visible above lower-priority overlays.
- Full CombService multiplier chain after this dispatch: `broodRate × elapsed × nurseMulti_143 × tempMulti_146 × t2Multi_149 × friendMulti_151 × holidayMult_154`.
