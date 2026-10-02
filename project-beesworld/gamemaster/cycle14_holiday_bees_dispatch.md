# Dispatch 157 — Holiday Specialist Bees + Midnight Mechanic
**Cycle:** 14  
**Part budget before:** 4,195 / 5,000  
**Parts added:** +2 permanent (UnlockPanel world part + GhostBeeAnchor VFX anchor)  
**Part budget after:** 4,197 / 5,000  
**Prerequisite dispatches:** 154 (HolidayService attributes), 156 (FestivalMeterService)

---

## Overview

Four holiday-gated Specialist Bees unlock permanently once per holiday event — Ghost Bee (Halloween), Frost Bee (Winter Hive), Blossom Bee (Spring Bloom), Solar Bee (Summer Solstice). Each provides a passive buff that stacks on top of the existing multiplier chain. Unlocks are stored in DataService per-profile and survive prestige resets.

**Halloween midnight secret:** On the transition from Oct 31 → Nov 1 (midnight UTC), Ghost Bee can be unlocked for just 13 honey instead of the normal 150 — a hidden mechanic rewarded to players who are online at exactly midnight.

**Kid-friendly framing:** "You found a special bee friend!" — each bee is presented as a personality with a name and a short sentence describing what they do, no numerical jargon in the unlock UI. The adult stat detail is visible on hover/long-press.

---

## Step 1 — DataService v12 → v13 migration

Run in Studio Command Bar (Edit mode, before everything else):

```lua
-- DISPATCH 157 STEP 1: DataService v12->v13 migration
-- Adds specialistBees table to player profiles
local DataService = require(game:GetService("ServerScriptService").Systems.DataService)

-- Patch the PROFILE_TEMPLATE
local template = DataService.PROFILE_TEMPLATE
if template.specialistBees == nil then
    template.specialistBees = {
        ghost   = false,
        frost   = false,
        blossom = false,
        solar   = false,
    }
    print("PROFILE_TEMPLATE patched: specialistBees added")
else
    print("PROFILE_TEMPLATE already has specialistBees -- skipping template patch")
end

-- Add migration v13
local migrations = DataService.MIGRATIONS
local hasMig13 = false
for _, m in migrations do
    if m.version == 13 then hasMig13 = true break end
end
if not hasMig13 then
    table.insert(migrations, {
        version = 13,
        migrate = function(data)
            if data.specialistBees == nil then
                data.specialistBees = {
                    ghost   = false,
                    frost   = false,
                    blossom = false,
                    solar   = false,
                }
            end
        end
    })
    print("Migration v13 registered")
else
    print("Migration v13 already exists -- skipping")
end

print("DataService v12->v13 DONE")
```

**Verify:**
```lua
local DataService = require(game:GetService("ServerScriptService").Systems.DataService)
local hasMig = false
for _, m in DataService.MIGRATIONS do
    if m.version == 13 then hasMig = true end
end
print("v13 migration present:", hasMig)
print("Template has specialistBees:", DataService.PROFILE_TEMPLATE.specialistBees ~= nil)
```

---

## Step 2 — SpecialistBeeService (new Script, ServerScriptService.Systems)

Create `ServerScriptService.Systems.SpecialistBeeService` as a **ModuleScript**:

```lua
--!strict
-- SpecialistBeeService: holiday specialist bee unlocks + midnight mechanic
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)
local HolidayService = require(script.Parent:FindFirstChild("HolidayService") or script.Parent.Parent.HolidayService)

-- ── Config ──────────────────────────────────────────────────────────────────
local BEES_157 = {
    ghost = {
        holiday  = "halloween",
        cost     = 150,
        name     = "Ghost Bee",
        tagline  = "Slips through walls to find hidden nectar!",
        stat     = "Foraging quality +8% during Halloween",
        emoji    = "👻",
        mult     = 1.08,  -- foraging quality multiplier
        stat_key = "ForagingQualMult", -- attribute key applied to player
    },
    frost = {
        holiday  = "winter",
        cost     = 150,
        name     = "Frost Bee",
        tagline  = "Keeps the hive cosy even in the cold!",
        stat     = "Removes cold temperature penalty",
        emoji    = "❄️",
        mult     = 1.0,   -- handled specially: negates cold penalty
        stat_key = "FrostBeeOwned",
    },
    blossom = {
        holiday  = "spring",
        cost     = 150,
        name     = "Blossom Bee",
        tagline  = "Makes every flower bloom a little longer!",
        stat     = "Flower bloom durations +20%",
        emoji    = "🌸",
        mult     = 1.20,
        stat_key = "BloomDurMult",
    },
    solar = {
        holiday  = "summer",
        cost     = 150,
        name     = "Solar Bee",
        tagline  = "Soaks up sunshine to boost the whole hive!",
        stat     = "Sunny weather bonus doubled (+30% instead of +15%)",
        emoji    = "☀️",
        mult     = 2.0,   -- doubles sunny weather quality bonus
        stat_key = "SolarBeeOwned",
    },
}

-- Halloween midnight secret: cost drops to 13 honey on Oct 31 23:55 → Nov 1 00:05 UTC
local MIDNIGHT_WINDOW_START_157 = { month = 10, day = 31, hour = 23, minute = 55 }
local MIDNIGHT_WINDOW_END_157   = { month = 11, day = 1,  hour = 0,  minute = 5  }

-- ── RemoteEvents ─────────────────────────────────────────────────────────────
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

local function getOrCreate_157(name: string, class: string)
    local existing = Remotes:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(class)
    r.Name = name
    r.Parent = Remotes
    return r
end

local RequestUnlockBee_157: RemoteEvent  = getOrCreate_157("RequestUnlockBee",   "RemoteEvent")  :: RemoteEvent
local UnlockBeeResult_157:  RemoteEvent  = getOrCreate_157("UnlockBeeResult",    "RemoteEvent")  :: RemoteEvent
local BeeStatusSync_157:    RemoteEvent  = getOrCreate_157("BeeStatusSync",      "RemoteEvent")  :: RemoteEvent

-- ── Midnight helper ──────────────────────────────────────────────────────────
local function isMidnightWindow_157(): boolean
    local t = os.date("!*t") :: any
    -- Oct 31 23:55–23:59
    if t.month == 10 and t.day == 31 and t.hour == 23 and t.minute >= 55 then
        return true
    end
    -- Nov 1 00:00–00:04
    if t.month == 11 and t.day == 1 and t.hour == 0 and t.minute < 5 then
        return true
    end
    return false
end

-- ── Sync helper ─────────────────────────────────────────────────────────────
local function syncPlayer_157(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local owned = profile.data.specialistBees or {}
    local active = HolidayService and HolidayService.GetActiveHoliday and HolidayService.GetActiveHoliday() or ""
    local midnight = isMidnightWindow_157()
    local payload: { [string]: any } = {
        owned       = owned,
        activeHoliday = active,
        midnight    = midnight,
    }
    BeeStatusSync_157:FireClient(player, payload)
end

-- Apply stat attributes to the player character/object
local function applyStats_157(player: Player)
    local profile = DataService.GetProfile(player)
    if not profile then return end
    local owned = profile.data.specialistBees or {}
    -- Ghost Bee: ForagingQualMult attribute
    local ghostMult = owned.ghost and 1.08 or 1.0
    player:SetAttribute("GhostBeeQualMult", ghostMult)
    -- Frost Bee: FrostBeeOwned boolean
    player:SetAttribute("FrostBeeOwned", owned.frost == true)
    -- Blossom Bee: BloomDurMult
    local blossomMult = owned.blossom and 1.20 or 1.0
    player:SetAttribute("BloomDurMult", blossomMult)
    -- Solar Bee: SolarBeeOwned boolean
    player:SetAttribute("SolarBeeOwned", owned.solar == true)
end

-- ── Unlock handler ────────────────────────────────────────────────────────────
RequestUnlockBee_157.OnServerEvent:Connect(function(player: Player, beeId: string)
    if type(beeId) ~= "string" then return end
    local cfg = BEES_157[beeId]
    if not cfg then
        UnlockBeeResult_157:FireClient(player, {ok=false, msg="Unknown bee."})
        return
    end

    local profile = DataService.GetProfile(player)
    if not profile then
        UnlockBeeResult_157:FireClient(player, {ok=false, msg="Profile not ready."})
        return
    end

    -- Already owned
    if profile.data.specialistBees and profile.data.specialistBees[beeId] then
        UnlockBeeResult_157:FireClient(player, {ok=false, msg="Already unlocked!"})
        return
    end

    -- Must be during correct holiday
    local active = HolidayService and HolidayService.GetActiveHoliday and HolidayService.GetActiveHoliday() or ""
    if active ~= cfg.holiday then
        UnlockBeeResult_157:FireClient(player, {ok=false, msg="Only available during " .. cfg.name .. "'s season!"})
        return
    end

    -- Determine cost (midnight window: Ghost Bee costs 13)
    local cost = cfg.cost
    if beeId == "ghost" and isMidnightWindow_157() then
        cost = 13  -- midnight secret
    end

    -- Check honey
    local honey = player:GetAttribute("HoneyCount") or 0
    if honey < cost then
        UnlockBeeResult_157:FireClient(player, {ok=false, msg="Need " .. cost .. " honey!"})
        return
    end

    -- Deduct & unlock
    DataService.AddResource(player, "honey", -cost)
    if not profile.data.specialistBees then
        profile.data.specialistBees = { ghost=false, frost=false, blossom=false, solar=false }
    end
    profile.data.specialistBees[beeId] = true

    applyStats_157(player)
    syncPlayer_157(player)

    UnlockBeeResult_157:FireClient(player, {
        ok      = true,
        beeId   = beeId,
        name    = cfg.name,
        emoji   = cfg.emoji,
        tagline = cfg.tagline,
        midnight = (beeId == "ghost" and cost == 13),
    })
end)

-- ── PlayerAdded ───────────────────────────────────────────────────────────────
Players.PlayerAdded:Connect(function(player: Player)
    -- Wait for profile load
    task.defer(function()
        local attempts = 0
        while not DataService.GetProfile(player) and attempts < 30 do
            task.wait(1)
            attempts += 1
        end
        applyStats_157(player)
        syncPlayer_157(player)
    end)
end)

-- Sync existing players on module load
for _, player in Players:GetPlayers() do
    task.defer(function()
        applyStats_157(player)
        syncPlayer_157(player)
    end)
end

-- ── Periodic midnight sync (resync during midnight window for cost update) ──
task.spawn(function()
    while true do
        task.wait(60)
        if isMidnightWindow_157() then
            for _, player in Players:GetPlayers() do
                syncPlayer_157(player)
            end
        end
    end
end)

-- ── Public API ────────────────────────────────────────────────────────────────
local SpecialistBeeService = {}

function SpecialistBeeService.GetForagingQualMult(player: Player): number
    return tonumber(player:GetAttribute("GhostBeeQualMult")) or 1.0
end

function SpecialistBeeService.HasFrostBee(player: Player): boolean
    return player:GetAttribute("FrostBeeOwned") == true
end

function SpecialistBeeService.GetBloomDurMult(player: Player): number
    return tonumber(player:GetAttribute("BloomDurMult")) or 1.0
end

function SpecialistBeeService.HasSolarBee(player: Player): boolean
    return player:GetAttribute("SolarBeeOwned") == true
end

return SpecialistBeeService
```

**Verify after creating:**
```lua
local sbs = require(game:GetService("ServerScriptService").Systems.SpecialistBeeService)
print("SpecialistBeeService loaded:", type(sbs.GetForagingQualMult))
local remotes = game:GetService("ReplicatedStorage").Remotes
print("RequestUnlockBee:", remotes:FindFirstChild("RequestUnlockBee") ~= nil)
print("UnlockBeeResult:", remotes:FindFirstChild("UnlockBeeResult") ~= nil)
print("BeeStatusSync:", remotes:FindFirstChild("BeeStatusSync") ~= nil)
```

---

## Step 3 — Patch HolidayService to expose GetActiveHoliday() API

`HolidayService` currently sets player attributes but does not expose a server-side API function. Add a module-level API at the bottom of the existing HolidayService Script source.

Run in Studio Command Bar:

```lua
-- DISPATCH 157 STEP 3: expose GetActiveHoliday() on HolidayService
local hs = game:GetService("ServerScriptService").Systems:FindFirstChild("HolidayService")
if not hs then
    -- Also check direct children of ServerScriptService
    hs = game:GetService("ServerScriptService"):FindFirstChild("HolidayService")
end
if not hs then print("HolidayService not found -- check path") return end

local src = hs.Source
-- Check if already patched
if src:find("GetActiveHoliday") then
    print("HolidayService already has GetActiveHoliday -- no patch needed")
    return
end

-- Append a module return table with the getter
-- We use a global _activeHoliday_154 that HolidayService already maintains
-- (the active holiday id string, or "" when none)
-- We inject a global cache variable and expose it.

-- Find the line where _activeHoliday is set and add a module-level getter.
-- Strategy: append to end of source a shared upvalue pattern.
-- Since HolidayService is a Script (not ModuleScript), we use a BindableFunction bridge.
local bf = Instance.new("BindableFunction")
bf.Name = "GetActiveHolidayBF"
bf.Parent = game:GetService("ServerScriptService").Systems

-- The actual implementation goes into HolidayService via source append.
-- We add a block that responds to the BindableFunction.
local injection = [[

-- DISPATCH 157 INJECT: GetActiveHoliday BindableFunction handler
do
    local _getActiveBF = game:GetService("ServerScriptService").Systems:WaitForChild("GetActiveHolidayBF", 10)
    if _getActiveBF then
        _getActiveBF.OnInvoke = function()
            return _activeHoliday_154 or ""
        end
    end
end
]]

hs.Source = src .. injection
print("HolidayService patched with GetActiveHolidayBF handler")
```

Now update `SpecialistBeeService` to call the BindableFunction instead of the direct require pattern. Run in Command Bar:

```lua
-- DISPATCH 157 STEP 3b: update SpecialistBeeService to use BindableFunction bridge
local sbs = game:GetService("ServerScriptService").Systems:FindFirstChild("SpecialistBeeService")
if not sbs then print("SpecialistBeeService not found") return end

local src = sbs.Source
-- Replace the HolidayService require + GetActiveHoliday() calls with BindableFunction calls
src = src:gsub(
    'local HolidayService = require%(script%.Parent:FindFirstChild%("HolidayService"%) or script%.Parent%.Parent%.HolidayService%)',
    '-- HolidayService accessed via BindableFunction bridge (it is a Script, not ModuleScript)\nlocal _holidayBF_157: BindableFunction? = game:GetService("ServerScriptService").Systems:FindFirstChild("GetActiveHolidayBF") :: BindableFunction?'
)
src = src:gsub(
    'local active = HolidayService and HolidayService%.GetActiveHoliday and HolidayService%.GetActiveHoliday%(%)',
    'local active: string = (_holidayBF_157 and _holidayBF_157:Invoke()) or (player:GetAttribute("ActiveHoliday") :: string?)'
)
-- Also fix the top-level active in syncPlayer_157
src = src:gsub(
    'local active = HolidayService and HolidayService%.GetActiveHoliday and HolidayService%.GetActiveHoliday%(%) or ""',
    'local active: string = (_holidayBF_157 and _holidayBF_157:Invoke()) or (player:GetAttribute("ActiveHoliday") :: string?) or ""'
)
sbs.Source = src
print("SpecialistBeeService updated to use BindableFunction bridge")
```

**Alternative (simpler):** If the above gsub feels risky, simply read `player:GetAttribute("ActiveHoliday")` directly in SpecialistBeeService — it's already set by HolidayService every 60s. The RequestUnlockBee handler can use:
```lua
local active = player:GetAttribute("ActiveHoliday") :: string? or ""
```
This is equally correct since the player always has the attribute if HolidayService is running.

**Recommended approach — use player attribute directly.** Replace the `active` lines in SpecialistBeeService with attribute reads:

```lua
-- DISPATCH 157 STEP 3c: simplify SpecialistBeeService to use player attribute (recommended)
local sbs = game:GetService("ServerScriptService").Systems:FindFirstChild("SpecialistBeeService")
if not sbs then print("SpecialistBeeService not found") return end
local src = sbs.Source
-- Remove HolidayService require line entirely
src = src:gsub('local HolidayService = require%(script%.Parent:FindFirstChild%("HolidayService"%) or script%.Parent%.Parent%.HolidayService%)\n', '')
-- Replace all GetActiveHoliday() calls with player attribute reads
src = src:gsub(
    'local active = HolidayService and HolidayService%.GetActiveHoliday and HolidayService%.GetActiveHoliday%(%) or ""',
    'local active = (player:GetAttribute("ActiveHoliday") :: string?) or ""'
)
src = src:gsub(
    'local active = HolidayService and HolidayService%.GetActiveHoliday and HolidayService%.GetActiveHoliday%(%) or "[^"]*"',
    'local active = (player:GetAttribute("ActiveHoliday") :: string?) or ""'
)
sbs.Source = src
print("SpecialistBeeService simplified: uses player:GetAttribute('ActiveHoliday')")
```

---

## Step 4 — Patch ForagingService: Ghost Bee quality multiplier

Open `ServerScriptService.Systems.ForagingService` source. Find the line that calculates final quality score after `SubmitDance` grading — it looks like:

```lua
local quality = baseQuality * weatherQMod_148
```

Inject Ghost Bee multiplier immediately after:

```lua
-- DISPATCH 157 STEP 4: inject Ghost Bee foraging quality multiplier
local ForagingService = game:GetService("ServerScriptService").Systems:FindFirstChild("ForagingService")
if not ForagingService then print("ForagingService not found") return end
local src = ForagingService.Source

-- Find the quality calculation line and add ghost bee multiplier
-- The pattern is: quality is finalized before being used in the dance result
-- We inject after weatherQMod application
if src:find("ghostBee_157") then
    print("ForagingService already patched for dispatch 157")
    return
end

-- Inject after the last multiplier line before the final quality assignment
-- Strategy: find "local quality = baseQuality" or the weatherQMod line
local injectedLine = [[
        -- DISPATCH 157: Ghost Bee foraging quality bonus
        local ghostBee_157 = tonumber(player:GetAttribute("GhostBeeQualMult")) or 1.0
        quality = quality * ghostBee_157
]]

-- Insert before the line that uses 'quality' as a result (before DanceResult FireClient or RecordDance call)
-- Safe injection: append multiplier right before the danceResult table construction
src = src:gsub(
    '(local danceResult_[%w]* = {)',
    injectedLine .. '%1'
)
-- Fallback: if the above pattern doesn't match, try inserting before a known comment or return
if not src:find("ghostBee_157") then
    -- Try inserting before the DanceResult FireClient call
    src = src:gsub(
        '(DanceResult:FireClient%(player,)',
        injectedLine .. '%1'
    )
end

if src:find("ghostBee_157") then
    ForagingService.Source = src
    print("ForagingService patched: Ghost Bee quality mult injected")
else
    print("WARN: Could not auto-patch ForagingService. Manual injection required.")
    print("Add this block before the DanceResult:FireClient line:")
    print(injectedLine)
end
```

---

## Step 5 — Patch HiveTemperatureService: Frost Bee negates cold penalty

Open `ServerScriptService.Systems.HiveTemperatureService`. Find where `HiveTemperature = "cold"` sets the `tempMulti_146` penalty (×0.80). Add a Frost Bee bypass:

```lua
-- DISPATCH 157 STEP 5: Frost Bee negates cold temperature penalty
local TempService = game:GetService("ServerScriptService").Systems:FindFirstChild("HiveTemperatureService")
if not TempService then print("HiveTemperatureService not found") return end
local src = TempService.Source

if src:find("FrostBeeOwned") then
    print("HiveTemperatureService already patched for dispatch 157")
    return
end

-- Find the cold penalty application. In dispatch 146 the pattern was:
-- if temp == "cold" then tempMulti = 0.80 end
-- Wrap it with a Frost Bee check
src = src:gsub(
    '(if temp == "cold" then\n%s*tempMulti[%w_]* = 0%.80\n%s*end)',
    'if temp == "cold" then\n            -- DISPATCH 157: Frost Bee negates cold penalty\n            local frostBypass_157 = player:GetAttribute("FrostBeeOwned") == true\n            if not frostBypass_157 then\n                tempMulti_146 = 0.80\n            end\n        end'
)

if src:find("FrostBeeOwned") then
    TempService.Source = src
    print("HiveTemperatureService patched: Frost Bee bypass injected")
else
    print("WARN: Could not auto-patch. Manual injection required.")
    print("Find the cold penalty block and wrap with: if not player:GetAttribute('FrostBeeOwned') then ... end")
end
```

---

## Step 6 — Patch WeatherService: Solar Bee doubles sunny bonus

Open `ServerScriptService.Systems.WeatherService`. Find where `sunny` weather applies `WeatherQualityMod` to players — it adds +15 quality. Solar Bee owners get +30 instead:

```lua
-- DISPATCH 157 STEP 6: Solar Bee doubles sunny weather quality bonus
local WeatherService = game:GetService("ServerScriptService").Systems:FindFirstChild("WeatherService")
if not WeatherService then print("WeatherService not found") return end
local src = WeatherService.Source

if src:find("SolarBeeOwned") then
    print("WeatherService already patched for dispatch 157")
    return
end

-- The sunny bonus sets WeatherQualityMod = 15 (from dispatch 148)
-- We want Solar Bee owners to get 30 instead
src = src:gsub(
    '(player:SetAttribute%("WeatherQualityMod", 15%))',
    '-- DISPATCH 157: Solar Bee doubles sunny bonus\n            local solar_157 = player:GetAttribute("SolarBeeOwned") == true\n            player:SetAttribute("WeatherQualityMod", solar_157 and 30 or 15)'
)

if src:find("SolarBeeOwned") then
    WeatherService.Source = src
    print("WeatherService patched: Solar Bee sunny bonus doubling injected")
else
    print("WARN: Could not auto-patch. The WeatherQualityMod=15 pattern may differ.")
    print("Find where sunny weather sets WeatherQualityMod=15 and add Solar Bee check.")
end
```

---

## Step 7 — Patch WeatherService: Blossom Bee extends bloom duration

The `flower_bloom` weather type from dispatch 148 has a duration. Add Blossom Bee extension:

```lua
-- DISPATCH 157 STEP 7: Blossom Bee extends flower_bloom weather duration
local WeatherService = game:GetService("ServerScriptService").Systems:FindFirstChild("WeatherService")
if not WeatherService then print("WeatherService not found") return end
local src = WeatherService.Source

if src:find("BloomDurMult") then
    print("WeatherService already has BloomDurMult patch")
    return
end

-- flower_bloom weather picks a random duration from a range
-- We multiply that duration by the max BloomDurMult across all players
-- (server-side service applies one duration to the whole server's weather)
src = src:gsub(
    '(local weatherDuration_148 = math%.random%(.-%))',
    '%1\n    -- DISPATCH 157: Blossom Bee extends bloom duration for all players\n    if currentWeather_148 == "flower_bloom" then\n        local maxBloom_157 = 1.0\n        for _, p in game:GetService("Players"):GetPlayers() do\n            local bm = tonumber(p:GetAttribute("BloomDurMult")) or 1.0\n            if bm > maxBloom_157 then maxBloom_157 = bm end\n        end\n        weatherDuration_148 = math.floor(weatherDuration_148 * maxBloom_157)\n    end'
)

if src:find("BloomDurMult") then
    WeatherService.Source = src
    print("WeatherService patched: Blossom Bee bloom duration extension injected")
else
    print("WARN: Could not auto-patch. weatherDuration_148 pattern may differ.")
    print("Find the bloom weather duration assignment and multiply by max BloomDurMult across players.")
end
```

---

## Step 8 — SpecialistBeeController (new LocalScript, StarterPlayerScripts)

Create `StarterPlayerScripts.SpecialistBeeController`:

```lua
--!strict
-- SpecialistBeeController: UI for unlocking and displaying holiday specialist bees
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")

local BeeStatusSync_157: RemoteEvent  = Remotes:WaitForChild("BeeStatusSync",   10) :: RemoteEvent
local RequestUnlockBee_157: RemoteEvent = Remotes:WaitForChild("RequestUnlockBee", 10) :: RemoteEvent
local UnlockBeeResult_157: RemoteEvent  = Remotes:WaitForChild("UnlockBeeResult",  10) :: RemoteEvent

-- ── Config ──────────────────────────────────────────────────────────────────
local BEES_157: { [string]: { name:string, tagline:string, stat:string, emoji:string, cost:number, holiday:string } } = {
    ghost   = { name="Ghost Bee",    tagline="Slips through walls to find hidden nectar!", stat="Foraging quality +8% during Halloween", emoji="👻", cost=150, holiday="halloween" },
    frost   = { name="Frost Bee",    tagline="Keeps the hive cosy even in the cold!",      stat="Removes cold temperature penalty",       emoji="❄️", cost=150, holiday="winter"   },
    blossom = { name="Blossom Bee",  tagline="Makes every flower bloom a little longer!",  stat="Flower bloom durations +20%",            emoji="🌸", cost=150, holiday="spring"   },
    solar   = { name="Solar Bee",    tagline="Soaks up sunshine to boost the whole hive!", stat="Sunny weather bonus doubled (+30%)",      emoji="☀️", cost=150, holiday="summer"   },
}
local HOLIDAY_ORDER_157 = { "ghost", "frost", "blossom", "solar" }

-- colours per holiday
local HOLIDAY_COLORS_157 = {
    halloween = Color3.fromRGB(200, 80,  10),
    winter    = Color3.fromRGB(130, 190, 240),
    spring    = Color3.fromRGB(220, 140, 180),
    summer    = Color3.fromRGB(242, 168,  28),
}
local PROPOLIS_BROWN = Color3.fromRGB(80, 50, 20)
local WAX_CREAM      = Color3.fromRGB(232, 212, 154)
local HONEY_GOLD     = Color3.fromRGB(242, 168, 28)

-- ── Build UI ─────────────────────────────────────────────────────────────────
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "SpecialistBeeGui"
screenGui.DisplayOrder    = 25
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.Parent          = playerGui

-- Panel (hidden by default, shown via "Bee Friends" button)
local panel = Instance.new("Frame")
panel.Name              = "BeePanel"
panel.Size              = UDim2.new(0, 300, 0, 0)  -- height auto from content
panel.Position          = UDim2.new(0.5, -150, 0.5, -170)
panel.BackgroundColor3  = PROPOLIS_BROWN
panel.BorderSizePixel   = 0
panel.Visible           = false
panel.Parent            = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color     = HONEY_GOLD
panelStroke.Thickness = 2
panelStroke.Parent    = panel

local panelPadding = Instance.new("UIPadding")
panelPadding.PaddingLeft   = UDim.new(0, 12)
panelPadding.PaddingRight  = UDim.new(0, 12)
panelPadding.PaddingTop    = UDim.new(0, 12)
panelPadding.PaddingBottom = UDim.new(0, 12)
panelPadding.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder   = Enum.SortOrder.LayoutOrder
listLayout.Padding     = UDim.new(0, 8)
listLayout.Parent      = panel

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name              = "Title"
titleLabel.Size              = UDim2.new(1, 0, 0, 28)
titleLabel.BackgroundTransparency = 1
titleLabel.Text              = "🐝 Bee Friends"
titleLabel.TextColor3        = HONEY_GOLD
titleLabel.Font              = Enum.Font.GothamBold
titleLabel.TextSize          = 18
titleLabel.TextXAlignment    = Enum.TextXAlignment.Center
titleLabel.LayoutOrder       = 0
titleLabel.Parent            = panel

-- Bee rows
local beeRows: { [string]: Frame } = {}

for i, beeId in HONEY_GOLD and HOLIDAY_ORDER_157 do
    local cfg = BEES_157[beeId]
    local row = Instance.new("Frame")
    row.Name             = "BeeRow_" .. beeId
    row.Size             = UDim2.new(1, 0, 0, 68)
    row.BackgroundColor3 = Color3.fromRGB(60, 38, 16)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = i
    row.Parent           = panel

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 8)
    rowCorner.Parent = row

    -- Emoji label
    local emojiLabel = Instance.new("TextLabel")
    emojiLabel.Name              = "Emoji"
    emojiLabel.Size              = UDim2.new(0, 44, 1, 0)
    emojiLabel.Position          = UDim2.new(0, 4, 0, 0)
    emojiLabel.BackgroundTransparency = 1
    emojiLabel.Text              = cfg.emoji
    emojiLabel.TextSize          = 28
    emojiLabel.Font              = Enum.Font.GothamBold
    emojiLabel.TextXAlignment    = Enum.TextXAlignment.Center
    emojiLabel.TextColor3        = WAX_CREAM
    emojiLabel.Parent            = row

    -- Name + tagline
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name             = "BeeName"
    nameLabel.Size             = UDim2.new(1, -120, 0, 22)
    nameLabel.Position         = UDim2.new(0, 52, 0, 8)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text             = cfg.name
    nameLabel.TextColor3       = WAX_CREAM
    nameLabel.Font             = Enum.Font.GothamBold
    nameLabel.TextSize         = 14
    nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
    nameLabel.Parent           = row

    local tagLabel = Instance.new("TextLabel")
    tagLabel.Name             = "Tagline"
    tagLabel.Size             = UDim2.new(1, -120, 0, 18)
    tagLabel.Position         = UDim2.new(0, 52, 0, 30)
    tagLabel.BackgroundTransparency = 1
    tagLabel.Text             = cfg.tagline
    tagLabel.TextColor3       = Color3.fromRGB(180, 160, 110)
    tagLabel.Font             = Enum.Font.Gotham
    tagLabel.TextSize         = 11
    tagLabel.TextXAlignment   = Enum.TextXAlignment.Left
    tagLabel.TextWrapped      = true
    tagLabel.Parent           = row

    -- Stat (adult detail, smaller, tertiary)
    local statLabel = Instance.new("TextLabel")
    statLabel.Name             = "Stat"
    statLabel.Size             = UDim2.new(1, -120, 0, 14)
    statLabel.Position         = UDim2.new(0, 52, 0, 50)
    statLabel.BackgroundTransparency = 1
    statLabel.Text             = cfg.stat
    statLabel.TextColor3       = Color3.fromRGB(140, 120, 80)
    statLabel.Font             = Enum.Font.Gotham
    statLabel.TextSize         = 10
    statLabel.TextXAlignment   = Enum.TextXAlignment.Left
    statLabel.Parent           = row

    -- Unlock button
    local unlockBtn = Instance.new("TextButton")
    unlockBtn.Name             = "UnlockBtn"
    unlockBtn.Size             = UDim2.new(0, 60, 0, 30)
    unlockBtn.Position         = UDim2.new(1, -68, 0.5, -15)
    unlockBtn.BackgroundColor3 = HONEY_GOLD
    unlockBtn.BorderSizePixel  = 0
    unlockBtn.Text             = "150 🍯"
    unlockBtn.Font             = Enum.Font.GothamBold
    unlockBtn.TextSize         = 12
    unlockBtn.TextColor3       = PROPOLIS_BROWN
    unlockBtn.Parent           = row

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = unlockBtn

    -- Lock overlay (shown when wrong holiday)
    local lockOverlay = Instance.new("Frame")
    lockOverlay.Name             = "LockOverlay"
    lockOverlay.Size             = UDim2.new(1, 0, 1, 0)
    lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    lockOverlay.BackgroundTransparency = 0.55
    lockOverlay.BorderSizePixel  = 0
    lockOverlay.Parent           = row

    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 8)
    lockCorner.Parent = lockOverlay

    local lockLabel = Instance.new("TextLabel")
    lockLabel.Size             = UDim2.new(1, 0, 1, 0)
    lockLabel.BackgroundTransparency = 1
    lockLabel.Text             = "🔒 Seasonal only"
    lockLabel.TextColor3       = Color3.fromRGB(200, 200, 200)
    lockLabel.Font             = Enum.Font.Gotham
    lockLabel.TextSize         = 12
    lockLabel.TextXAlignment   = Enum.TextXAlignment.Center
    lockLabel.Parent           = lockOverlay

    -- Owned badge (replaces button when owned)
    local ownedBadge = Instance.new("TextLabel")
    ownedBadge.Name             = "OwnedBadge"
    ownedBadge.Size             = UDim2.new(0, 60, 0, 30)
    ownedBadge.Position         = UDim2.new(1, -68, 0.5, -15)
    ownedBadge.BackgroundColor3 = Color3.fromRGB(40, 140, 60)
    ownedBadge.BorderSizePixel  = 0
    ownedBadge.Text             = "✓ Got it!"
    ownedBadge.Font             = Enum.Font.GothamBold
    ownedBadge.TextSize         = 11
    ownedBadge.TextColor3       = Color3.fromRGB(220, 255, 220)
    ownedBadge.Visible          = false
    ownedBadge.Parent           = row

    local ownedCorner = Instance.new("UICorner")
    ownedCorner.CornerRadius = UDim.new(0, 6)
    ownedCorner.Parent = ownedBadge

    unlockBtn.Activated:Connect(function()
        RequestUnlockBee_157:FireServer(beeId)
    end)

    beeRows[beeId] = row
end

-- Auto-size panel height
local function updatePanelHeight_157()
    local contentHeight = listLayout.AbsoluteContentSize.Y
    panel.Size = UDim2.new(0, 300, 0, contentHeight + 24)
    panel.Position = UDim2.new(0.5, -150, 0.5, -(contentHeight + 24) / 2)
end
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updatePanelHeight_157)

-- Open/close toggle button (small pill above other HUD)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name             = "BeeFriendsToggle"
toggleBtn.Size             = UDim2.new(0, 110, 0, 26)
toggleBtn.Position         = UDim2.new(0.5, -55, 0, 8)
toggleBtn.BackgroundColor3 = PROPOLIS_BROWN
toggleBtn.BorderSizePixel  = 0
toggleBtn.Text             = "🐝 Bee Friends"
toggleBtn.Font             = Enum.Font.GothamBold
toggleBtn.TextSize         = 13
toggleBtn.TextColor3       = WAX_CREAM
toggleBtn.Parent           = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color     = HONEY_GOLD
toggleStroke.Thickness = 1
toggleStroke.Parent    = toggleBtn

toggleBtn.Activated:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then
        updatePanelHeight_157()
    end
end)

-- ── Sync handler ─────────────────────────────────────────────────────────────
local function applySync_157(payload: { [string]: any })
    local owned: { [string]: boolean } = payload.owned or {}
    local active: string = payload.activeHoliday or ""
    local midnight: boolean = payload.midnight == true

    for beeId, row in beeRows do
        local cfg = BEES_157[beeId]
        local isOwned    = owned[beeId] == true
        local isActive   = active == cfg.holiday
        local unlockBtn  = row:FindFirstChild("UnlockBtn") :: TextButton
        local ownedBadge = row:FindFirstChild("OwnedBadge") :: TextLabel
        local lockOverlay= row:FindFirstChild("LockOverlay") :: Frame

        if isOwned then
            unlockBtn.Visible   = false
            ownedBadge.Visible  = true
            lockOverlay.Visible = false
        elseif isActive then
            unlockBtn.Visible   = true
            ownedBadge.Visible  = false
            lockOverlay.Visible = false
            -- Midnight secret: show 13 honey cost for Ghost Bee
            if beeId == "ghost" and midnight then
                unlockBtn.Text             = "13 🍯"
                unlockBtn.BackgroundColor3 = Color3.fromRGB(180, 80, 200)
                unlockBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
            else
                unlockBtn.Text             = "150 🍯"
                unlockBtn.BackgroundColor3 = HONEY_GOLD
                unlockBtn.TextColor3       = PROPOLIS_BROWN
            end
        else
            unlockBtn.Visible   = false
            ownedBadge.Visible  = false
            lockOverlay.Visible = true
            local lockLabel = lockOverlay:FindFirstChild("TextLabel") :: TextLabel
            if lockLabel then
                if cfg.holiday == "halloween" then
                    lockLabel.Text = "🎃 Halloween only"
                elseif cfg.holiday == "winter" then
                    lockLabel.Text = "❄️ Winter Hive only"
                elseif cfg.holiday == "spring" then
                    lockLabel.Text = "🌸 Spring Bloom only"
                elseif cfg.holiday == "summer" then
                    lockLabel.Text = "☀️ Summer Solstice only"
                else
                    lockLabel.Text = "🔒 Seasonal only"
                end
            end
        end

        -- Colour-tint row border when active holiday
        local rowStroke = row:FindFirstChildOfClass("UIStroke")
        if not rowStroke then
            rowStroke = Instance.new("UIStroke")
            rowStroke.Parent = row
        end
        if isActive then
            rowStroke.Color     = HOLIDAY_COLORS_157[cfg.holiday] or HONEY_GOLD
            rowStroke.Thickness = 1.5
        else
            rowStroke.Color     = Color3.fromRGB(80, 60, 30)
            rowStroke.Thickness = 0.5
        end
    end
end

BeeStatusSync_157.OnClientEvent:Connect(applySync_157)

-- ── Unlock result toast ───────────────────────────────────────────────────────
UnlockBeeResult_157.OnClientEvent:Connect(function(result: { [string]: any })
    local ok: boolean = result.ok == true

    local toast = Instance.new("Frame")
    toast.Size             = UDim2.new(0, 280, 0, 70)
    toast.Position         = UDim2.new(0.5, -140, 0, -80)
    toast.BackgroundColor3 = ok and Color3.fromRGB(40, 120, 50) or Color3.fromRGB(140, 40, 40)
    toast.BorderSizePixel  = 0
    toast.Parent           = screenGui

    local toastCorner = Instance.new("UICorner")
    toastCorner.CornerRadius = UDim.new(0, 12)
    toastCorner.Parent = toast

    local toastLabel = Instance.new("TextLabel")
    toastLabel.Size             = UDim2.new(1, -16, 1, 0)
    toastLabel.Position         = UDim2.new(0, 8, 0, 0)
    toastLabel.BackgroundTransparency = 1
    toastLabel.Font             = Enum.Font.GothamBold
    toastLabel.TextWrapped      = true
    toastLabel.TextColor3       = Color3.fromRGB(240, 240, 240)
    toastLabel.TextXAlignment   = Enum.TextXAlignment.Center
    toastLabel.Parent           = toast

    if ok then
        local isMidnight = result.midnight == true
        local line1 = (result.emoji or "🐝") .. " " .. (result.name or "Bee") .. " unlocked!"
        local line2 = isMidnight and "🌙 Midnight secret! (13 honey)" or result.tagline or ""
        toastLabel.Text     = line1 .. "\n" .. line2
        toastLabel.TextSize = 14
    else
        toastLabel.Text     = result.msg or "Could not unlock"
        toastLabel.TextSize = 14
    end

    -- Slide in
    TweenService:Create(toast, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -140, 0, 12)
    }):Play()

    task.wait(3)

    TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -140, 0, -80)
    }):Play()
    task.wait(0.3)
    toast:Destroy()
end)

-- ── Initial request ───────────────────────────────────────────────────────────
-- Server will sync on PlayerAdded; request a manual sync in case controller loaded late
task.delay(2, function()
    -- Read current attributes as fallback for immediate display
    local activeHoliday = player:GetAttribute("ActiveHoliday") :: string? or ""
    -- Show toggle button only during a holiday (or always for discoverability)
    -- Always visible so players know it exists; shows lock overlays off-season
    updatePanelHeight_157()
end)
```

**Verify after creating:**
```lua
local sg = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("SpecialistBeeGui")
print("SpecialistBeeGui exists:", sg ~= nil)
if sg then
    print("Panel:", sg:FindFirstChild("BeePanel") ~= nil)
    print("Toggle:", sg:FindFirstChild("BeeFriendsToggle") ~= nil)
    print("Ghost row:", sg.BeePanel:FindFirstChild("BeeRow_ghost") ~= nil)
    print("Frost row:", sg.BeePanel:FindFirstChild("BeeRow_frost") ~= nil)
    print("Blossom row:", sg.BeePanel:FindFirstChild("BeeRow_blossom") ~= nil)
    print("Solar row:", sg.BeePanel:FindFirstChild("BeeRow_solar") ~= nil)
end
```

---

## Step 9 — Ghost Bee VFX anchor (world part, +1 part)

During Halloween, a subtle ghost-glow VFX appears around the player's hive when Ghost Bee is owned. Create the anchor part:

```lua
-- DISPATCH 157 STEP 9: GhostBeeAnchor VFX anchor part
local hub = workspace:FindFirstChild("Hub")
if not hub then print("Hub folder not found") return end

local anchor = Instance.new("Part")
anchor.Name             = "GhostBeeAnchor"
anchor.Size             = Vector3.new(1, 1, 1)
anchor.Position         = Vector3.new(0, 5, -320)  -- above hub center
anchor.Anchored         = true
anchor.CanCollide        = false
anchor.Transparency     = 1
anchor.CastShadow       = false
anchor.Parent           = hub

-- Ghost wisp ParticleEmitter (Halloween ghost bee VFX, very subtle)
local wisp = Instance.new("ParticleEmitter")
wisp.Name              = "GhostWisp"
wisp.Rate              = 0  -- enabled client-side only for Ghost Bee owners
wisp.Lifetime          = NumberRange.new(3, 5)
wisp.Speed             = NumberRange.new(1, 3)
wisp.RotSpeed          = NumberRange.new(-15, 15)
wisp.LightEmission     = 0.3
wisp.LightInfluence    = 0.7
wisp.SpreadAngle       = Vector2.new(60, 60)
wisp.Color             = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 220, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 120, 200)),
})
wisp.Transparency      = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.1, 0.6),
    NumberSequenceKeypoint.new(0.9, 0.6),
    NumberSequenceKeypoint.new(1, 1),
})
wisp.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.2),
    NumberSequenceKeypoint.new(0.5, 0.6),
    NumberSequenceKeypoint.new(1, 0),
})
wisp.Enabled = false  -- stays off; activated by client when Ghost Bee is owned + Halloween active
wisp.Parent = anchor

print("GhostBeeAnchor + GhostWisp emitter created in Hub folder")
```

Add a client-side activator to `SpecialistBeeController` (append to the bottom of the LocalScript):

```lua
-- Ghost Bee VFX activator (appended to SpecialistBeeController)
-- Enables the GhostWisp emitter only for Ghost Bee owners during Halloween
local function updateGhostVFX_157()
    local owned = player:GetAttribute("GhostBeeQualMult") or 1.0
    local holiday = player:GetAttribute("ActiveHoliday") :: string? or ""
    local anchor = workspace:FindFirstChild("Hub") and workspace.Hub:FindFirstChild("GhostBeeAnchor")
    if not anchor then return end
    local emitter = anchor:FindFirstChild("GhostWisp") :: ParticleEmitter?
    if emitter then
        emitter.Enabled = (owned > 1.0 and holiday == "halloween")
        emitter.Rate    = emitter.Enabled and 3 or 0
    end
end

player:GetAttributeChangedSignal("GhostBeeQualMult"):Connect(updateGhostVFX_157)
player:GetAttributeChangedSignal("ActiveHoliday"):Connect(updateGhostVFX_157)
task.delay(3, updateGhostVFX_157)
```

---

## Step 10 — World part: Holiday Bee Notice (UnlockPanel, +1 part)

A small sign near the BeesBench area reminds players about seasonal bee friends:

```lua
-- DISPATCH 157 STEP 10: UnlockPanel world sign
local hub = workspace:FindFirstChild("Hub")
if not hub then print("Hub folder not found") return end

local sign = Instance.new("Part")
sign.Name             = "UnlockPanel"
sign.Size             = Vector3.new(3, 1.5, 0.2)
sign.Position         = Vector3.new(-12, 3.75, -290)
sign.Orientation      = Vector3.new(0, 20, 0)
sign.Anchored         = true
sign.CanCollide        = true
sign.Material          = Enum.Material.SmoothPlastic
sign.Color             = Color3.fromRGB(80, 50, 20)
sign.CastShadow        = false
sign.Parent            = hub

-- SurfaceGui on the Front face
local sg = Instance.new("SurfaceGui")
sg.Face       = Enum.NormalId.Front
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 50
sg.AlwaysOnTop = false
sg.Parent      = sign

local bgFrame = Instance.new("Frame")
bgFrame.Size             = UDim2.new(1, 0, 1, 0)
bgFrame.BackgroundColor3 = Color3.fromRGB(60, 38, 16)
bgFrame.BorderSizePixel  = 0
bgFrame.Parent           = sg

local bgCorner = Instance.new("UICorner")
bgCorner.CornerRadius = UDim.new(0, 8)
bgCorner.Parent = bgFrame

local signLabel = Instance.new("TextLabel")
signLabel.Size             = UDim2.new(1, -8, 1, -4)
signLabel.Position         = UDim2.new(0, 4, 0, 2)
signLabel.BackgroundTransparency = 1
signLabel.Text             = "🐝 Bee Friends\nVisit during holidays\nto unlock special bees!"
signLabel.TextColor3       = Color3.fromRGB(242, 168, 28)
signLabel.Font             = Enum.Font.GothamBold
signLabel.TextSize         = 14
signLabel.TextScaled       = true
signLabel.TextWrapped      = true
signLabel.TextXAlignment   = Enum.TextXAlignment.Center
signLabel.Parent           = bgFrame

print("UnlockPanel sign created in Hub folder")
```

---

## Final verification sweep

Run all at once in Studio Command Bar after all steps complete:

```lua
print("=== DISPATCH 157 VERIFICATION SWEEP ===")

-- 1. DataService migration
local DS = require(game:GetService("ServerScriptService").Systems.DataService)
local hasMig13 = false
for _, m in DS.MIGRATIONS do if m.version == 13 then hasMig13 = true end end
print("v13 migration:", hasMig13 and "PASS" or "FAIL")
print("Template specialistBees:", DS.PROFILE_TEMPLATE.specialistBees ~= nil and "PASS" or "FAIL")

-- 2. SpecialistBeeService
local ok, sbs = pcall(require, game:GetService("ServerScriptService").Systems.SpecialistBeeService)
print("SpecialistBeeService loads:", ok and "PASS" or ("FAIL: " .. tostring(sbs)))

-- 3. RemoteEvents
local R = game:GetService("ReplicatedStorage").Remotes
for _, name in {"RequestUnlockBee","UnlockBeeResult","BeeStatusSync"} do
    print(name .. ":", R:FindFirstChild(name) and "PASS" or "FAIL")
end

-- 4. SpecialistBeeController
local SG = game:GetService("StarterPlayer").StarterPlayerScripts
print("SpecialistBeeController:", SG:FindFirstChild("SpecialistBeeController") and "PASS" or "FAIL")

-- 5. World parts
local hub = workspace:FindFirstChild("Hub")
print("UnlockPanel:", (hub and hub:FindFirstChild("UnlockPanel")) and "PASS" or "FAIL")
print("GhostBeeAnchor:", (hub and hub:FindFirstChild("GhostBeeAnchor")) and "PASS" or "FAIL")

-- 6. ForagingService patch
local FS = game:GetService("ServerScriptService").Systems:FindFirstChild("ForagingService")
print("ForagingService ghostBee patch:", (FS and FS.Source:find("ghostBee_157")) and "PASS" or "FAIL (manual injection may be needed)")

-- 7. Part budget sanity
local total = 0
for _, p in workspace:GetDescendants() do
    if p:IsA("BasePart") then total += 1 end
end
print("Total workspace parts:", total, "(budget 5000)")
print("=== END 157 SWEEP ===")
```

Expected output:
```
=== DISPATCH 157 VERIFICATION SWEEP ===
v13 migration: PASS
Template specialistBees: PASS
SpecialistBeeService loads: PASS
RequestUnlockBee: PASS
UnlockBeeResult: PASS
BeeStatusSync: PASS
SpecialistBeeController: PASS
UnlockPanel: PASS
GhostBeeAnchor: PASS
ForagingService ghostBee patch: PASS
Total workspace parts: 4197 (budget 5000)
=== END 157 SWEEP ===
```

---

## Notes for execution

- **Step 3 simplification:** Use Step 3c (player attribute read) rather than the BindableFunction bridge. It's cleaner and equally correct.
- **ForagingService auto-patch (Step 4):** The gsub pattern assumes the variable is named `danceResult_NNN`. If the actual variable name differs, use the fallback print instructions for manual insertion.
- **Midnight window (Halloween only):** The 10-minute unlock window runs Oct 31 23:55 → Nov 1 00:04 UTC. During that window, `SpecialistBeeController` shows the unlock button in purple with "13 🍯" instead of gold "150 🍯". This is intentionally undocumented in the game — players who discover it organically will talk about it.
- **Kid-friendly framing:** All UI text uses taglines ("Slips through walls to find hidden nectar!") rather than mechanical stat text. The adult stat line ("Foraging quality +8%") appears in smaller grey text below for parents who want the detail.
- **Bee Friends toggle button** sits at the top-center of the screen. Players can hide it by closing the panel; the toggle itself stays visible as a small pill.

---

*Dispatch 157 complete. Holiday system series (154–157) fully written. Part budget: **4,197 / 5,000**.*
