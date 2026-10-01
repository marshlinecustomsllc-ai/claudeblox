# Dispatch 146 — Hive Temperature Mechanic
## Cycle 14 · A Bee's World

**Feature:** Hive Temperature — a passive environmental modifier. When the Roblox server clock is "night" (ClockTime < 6 or > 20), honey production is reduced by 20% unless the player has at least one `propolis_kiln` adjacent to a `brood` cell, which provides warmth and cancels the penalty. `HiveTemperature` player attribute drives a client-side temperature indicator (warm amber flame vs cool blue snowflake). Part budget: +1 permanent (one server Script; temperature controller is LocalScript = +0 permanent).
**Part budget impact:** +1 permanent → **4,153 / 5,000**
**Execution order:** After dispatch 145 (Daily Login Rewards)

---

## DESIGN

### Why temperature?

Tycoon games with a single monotonic growth rate get boring fast. Environmental modifiers that require player response — without being punishing — add strategic depth. Temperature is:
- **Visual** (kids see the warm/cold icon and immediately understand)
- **Strategic** (adults optimise propolis kiln placement around brood cells for permanent immunity)
- **Gentle** (20% penalty is noticeable but not catastrophic; and it only applies at night)

### Temperature rules

| ClockTime | State | Production modifier |
|-----------|-------|---------------------|
| 6–20 | Warm (day) | ×1.0 |
| < 6 or > 20 | Cold (night) | ×0.80 unless warmed |

**Warmth condition:** Player has at least one `propolis_kiln` slot that is adjacent to at least one `brood` slot in their `CombState`. This is the same adjacency map as dispatch 138.

### HiveTemperature attribute

A server-written player attribute:
- `"warm"` → day or player has warmth coverage
- `"cold"` → night and no warmth coverage (production ×0.80)

`HiveTemperatureService` polls ClockTime every 30 seconds and updates all player attributes.

### CombService integration

`CombService` honey production loop reads `HiveTemperature` and applies the multiplier:

```lua
local tempMulti_146 = (player:GetAttribute("HiveTemperature") == "cold") and 0.80 or 1.0
local produced = math.floor(broodRate * elapsed * nurseMulti * tempMulti_146)
```

### Client temperature indicator

A tiny pill at top-center of screen (below the wallet bar) shows:
- 🔥 warm state: amber text, no penalty
- ❄️ cold state: light blue text, "−20%" penalty hint

Auto-shows during night, auto-hides during day.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HiveTemperatureService` | New Script in ServerScriptService |
| `HiveTemperatureController` | New LocalScript in StarterPlayerScripts |
| `CombService` | +3 lines: temperature multiplier |

---

## STEP A — Create HiveTemperatureService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("HiveTemperatureService") then
    print("⏭️  HiveTemperatureService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "HiveTemperatureService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- HiveTemperatureService — dispatch 146
-- Sets HiveTemperature attribute ("warm"/"cold") per player every 30s.
-- Cold = night (ClockTime < 6 or > 20) with no propolis_kiln adjacent to brood.

local Players   = game:GetService("Players")
local Lighting  = game:GetService("Lighting")

local POLL_146   = 30  -- seconds between temperature checks
local NIGHT_MIN  = 6
local NIGHT_MAX  = 20

-- Adjacency map for 9-slot hex grid (1-indexed, row-major)
-- slot 4 = center; adjacency from dispatch 138 HEX_ADJ_138
local ADJ_146: {{number}} = {
    {2, 4},        -- slot 1
    {1, 3, 5},     -- slot 2
    {2, 6},        -- slot 3
    {1, 5, 7},     -- slot 4
    {2, 4, 6, 8},  -- slot 5
    {3, 5, 9},     -- slot 6
    {4, 8},        -- slot 7
    {5, 7, 9},     -- slot 8
    {6, 8},        -- slot 9
}

local function isNight_146(): boolean
    local t = Lighting.ClockTime
    return t < NIGHT_MIN or t > NIGHT_MAX
end

local function hasWarmth_146(player: Player): boolean
    local raw = tostring(player:GetAttribute("CombState") or "")
    -- Parse comma-separated 9-slot string
    local slots: {string} = {}
    for slot in (raw .. ","):gmatch("([^,]*),") do
        table.insert(slots, slot)
    end
    -- Find all kiln and brood positions
    local kilnSlots: {[number]: boolean} = {}
    local broodSlots: {[number]: boolean} = {}
    for i = 1, 9 do
        local v = slots[i] or ""
        if v == "propolis_kiln" then kilnSlots[i] = true end
        if v == "brood"         then broodSlots[i] = true end
    end
    -- Kiln is adjacent to brood?
    for kilnIdx in kilnSlots do
        for _, neighbour in ADJ_146[kilnIdx] do
            if broodSlots[neighbour] then return true end
        end
    end
    return false
end

local function updateAll_146()
    local night = isNight_146()
    for _, player in Players:GetPlayers() do
        local cold = night and not hasWarmth_146(player)
        player:SetAttribute("HiveTemperature", cold and "cold" or "warm")
    end
end

-- Polling loop
task.spawn(function()
    while true do
        updateAll_146()
        task.wait(POLL_146)
    end
end)

-- Also update on player join (after DS replication)
Players.PlayerAdded:Connect(function(player)
    task.wait(2)
    if player.Parent then updateAll_146() end
end)

print("[HiveTemperatureService] Ready — hive temperature tracking active")
]]
    svc.Parent = SSS
    print("✅ HiveTemperatureService created")
end
```

---

## STEP B — Create HiveTemperatureController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("HiveTemperatureController") then
    print("⏭️  HiveTemperatureController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "HiveTemperatureController"
    ctrl.Source = [[
--!strict
-- HiveTemperatureController — dispatch 146
-- Shows a small temperature pill at top-center during cold nights.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_146 = Color3.fromRGB(242, 168,  28)
local COLD_146  = Color3.fromRGB(140, 200, 255)
local DARK_146  = Color3.fromRGB(30,  20,   8)

local sg_146: ScreenGui? = nil
local pill_146: Frame?   = nil
local label_146: TextLabel? = nil

local function ensureGui_146()
    if sg_146 and sg_146.Parent then return end
    sg_146 = Instance.new("ScreenGui")
    sg_146.Name         = "HiveTempGui"
    sg_146.ResetOnSpawn = false
    sg_146.DisplayOrder = 12
    sg_146.Parent       = playerGui

    local pill = Instance.new("Frame")
    pill.Name                   = "TempPill"
    pill.Size                   = UDim2.new(0, 140, 0, 24)
    pill.Position               = UDim2.new(0.5, -70, 0, 8)
    pill.AnchorPoint            = Vector2.new(0, 0)
    pill.BackgroundColor3       = DARK_146
    pill.BackgroundTransparency = 0.1
    pill.BorderSizePixel        = 0
    pill.Visible                = false
    pill.Parent                 = sg_146 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = pill

    local lbl = Instance.new("TextLabel")
    lbl.Size                   = UDim2.new(1, -8, 1, 0)
    lbl.Position               = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 11
    lbl.TextColor3             = AMBER_146
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Text                   = "🔥 Hive warm"
    lbl.Parent                 = pill

    pill_146  = pill
    label_146 = lbl
end

local function onTempChanged_146()
    ensureGui_146()
    local temp = tostring(player:GetAttribute("HiveTemperature") or "warm")
    local cold = temp == "cold"
    local pill  = pill_146  :: Frame
    local lbl   = label_146 :: TextLabel

    if cold then
        pill.Visible    = true
        lbl.Text        = "❄️ Cold night  −20% honey"
        lbl.TextColor3  = COLD_146
    else
        -- Hide during day / warm
        pill.Visible = false
        lbl.TextColor3  = AMBER_146
        lbl.Text        = "🔥 Hive warm"
    end
end

ensureGui_146()
onTempChanged_146()
player:GetAttributeChangedSignal("HiveTemperature"):Connect(onTempChanged_146)

print("[HiveTemperatureController] Ready")
]]
    ctrl.Parent = SPS
    print("✅ HiveTemperatureController created")
end
```

---

## STEP C — Patch CombService (temperature multiplier)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))
assert(comb, "CombService not found")

-- Look for the nurse multiplier line added in dispatch 143
local old = [[local produced = math.floor(broodRate * elapsed * nurseMulti_143)]]
local new = [[
            local tempMulti_146 = (player:GetAttribute("HiveTemperature") == "cold") and 0.80 or 1.0
            local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146)]]

if comb.Source:find(old, 1, true) then
    comb.Source = comb.Source:gsub(old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), new:gsub("%%","%%%%"), 1)
    print("✅ CombService patched — temperature multiplier active (cold night = ×0.80)")
elseif comb.Source:find("tempMulti_146", 1, true) then
    print("⏭️  CombService already has temperature patch — skip")
else
    print("⚠️  nurseMulti_143 line not found. If dispatch 143 was not applied, search for:")
    print("    local produced = math.floor(broodRate * elapsed)")
    print("    and append: * ((player:GetAttribute('HiveTemperature') == 'cold') and 0.80 or 1.0)")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local svc  = SSS:FindFirstChild("HiveTemperatureService")
local ctrl = SPS and SPS:FindFirstChild("HiveTemperatureController")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " HiveTemperatureService in ServerScriptService")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("ADJ_146", 1, true) and "✅" or "❌") .. " ADJ_146 adjacency map")
table.insert(checks, (svc and svc.Source:find("hasWarmth_146", 1, true) and "✅" or "❌") .. " hasWarmth_146 check")
table.insert(checks, (svc and svc.Source:find("HiveTemperature", 1, true) and "✅" or "❌") .. " HiveTemperature attribute write")
table.insert(checks, (svc and svc.Source:find("task.wait(30)", 1, true) and "✅" or "❌") .. " 30s polling loop")
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveTemperatureController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("HiveTemperature", 1, true) and "✅" or "❌") .. " HiveTemperature attribute read")
table.insert(checks, (ctrl and ctrl.Source:find("TempPill", 1, true) and "✅" or "❌") .. " TempPill UI element")
table.insert(checks, (comb and comb.Source:find("tempMulti_146", 1, true) and "✅" or "❌") .. " CombService has tempMulti_146")

print("=== DISPATCH 146 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 146 complete" or "❌ SOME CHECKS FAILED")

print("\nHive temperature: warm (day 6-20) = ×1.0 | cold (night) = ×0.80 unless propolis_kiln adj to brood")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HiveTemperatureService (Script in ServerScriptService) | +1 |
| HiveTemperatureController (LocalScript — no permanent count) | 0 |
| CombService patch (edit — no new instances) | 0 |
| **Dispatch 146 total** | **+1** |
| **Running total** | **4,153 / 5,000** |

---

## NOTES

- The 30-second polling interval is intentional. ClockTime in a default Roblox place cycles in real-time (no accelerated day/night unless a server script drives it). A 30s poll is accurate enough without hammering attribute writes every frame. If your game has a server-driven day/night cycle, fire an event instead of polling — but the polling version is safe as a baseline.
- Warmth coverage only requires one kiln adjacent to one brood cell, not universal coverage. This is achievable mid-game without requiring a fully optimised board. Advanced players who fill all 9 slots with the optimal kiln-brood adjacency pattern get full immunity, but casual players with a single brood + adjacent kiln also get it. Low floor, high ceiling — both audiences are served.
- `CombState` parsing reuses the `(raw .. ","):gmatch("([^,]*),")` trailing-comma trick from dispatch 138. Empty slots become empty strings, which don't match any cell type.
- `DisplayOrder=12` places the temperature pill between the foraging timer pill (DisplayOrder=11) and the hive health bar (DisplayOrder=13). Both pills sit in the top area of the screen, so they don't conflict with the right-side column buttons.
