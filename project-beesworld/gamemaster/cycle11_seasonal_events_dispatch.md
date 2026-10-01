# CYCLE 11 — SEASONAL EVENTS DISPATCH (dispatch 30)
## SeasonalEventService — Harvest Festival framework (date-gated)

**Agent:** luau-scripter  
**Prerequisites:** dispatch 14 (DataService baseline), dispatch 23 (QuestService metric hooks exist)  
**Part budget impact:** +4 new world parts → **~4,098 / 5,000** total (Harvest Stall world prop)

---

## OVERVIEW

A date-gated Harvest Festival that runs every year in October. While the festival is active:
- A **Harvest Stall** prop appears near the hub entrance with a banner
- Foraging yield from **all flower species** is boosted +25% (stacks multiplicatively with BloomRush)
- A **Festival Quest** replaces one of the three daily quests with a special harvest-themed goal
- A **"Harvest Festival Active!"** server-wide banner notification fires once per server on first player join

After the festival window passes, the stall becomes invisible (not destroyed — avoids flickering on recycle), bonuses stop, and the quest slot returns to normal rotation.

**Design constraints:**
- Date check via `os.date("*t")` — month=10 is October; optional day range (default: Oct 1–31 = full month)
- No DataService migration — no profile fields needed; festival state is ephemeral (server-lifetime)
- ForagingService hook: multiply the per-trip yield by `SeasonalEventService.GetYieldMult()` (returns 1.25 during festival, 1.0 otherwise) — same pattern as BloomRush's existing multiplier
- QuestService hook: on each daily reset, if festival is active, force slot 3 to the `harvest_festival` quest template
- One Harvest Stall world prop (4 parts): visible only during festival
- All server-side; no RemoteEvent needed — Notify remote handles the one-time banner

---

## STEP A — Config.SEASONAL_EVENTS

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP A: Add Config.SEASONAL_EVENTS to Config ModuleScript
-- Uses clone-and-replace to bust require() cache.

local RS = game:GetService("ReplicatedStorage")
local Modules = RS:FindFirstChild("Modules")
assert(Modules, "ReplicatedStorage.Modules not found")

local cfgOld = Modules:FindFirstChild("Config")
assert(cfgOld and cfgOld:IsA("ModuleScript"), "Config ModuleScript not found")

local cfgClone = cfgOld:Clone()
local src = cfgOld.Source

local eventsBlock = [[

-- Seasonal Events
Config.SEASONAL_EVENTS = {
    HarvestFestival = {
        name        = "Harvest Festival",
        month       = 10,          -- October
        dayStart    = 1,
        dayEnd      = 31,          -- full month
        yieldMult   = 1.25,        -- +25% foraging yield
        bannerMsg   = "Harvest Festival is here! All bees gather +25% nectar this month.",
        -- Quest override for slot 3 during the festival
        questOverride = {
            id          = "harvest_festival",
            label       = "Festival Harvest",
            desc        = "Harvest 2,000 honey during the Harvest Festival.",
            category    = "Economy",
            metric      = "honeyHarvested",
            target      = 2000,
            reward      = { honey = 1500, propolis = 50 },
        },
    },
}
]]

-- Insert before `return Config` at end of module
src = src:gsub(
    "(return%s+Config%s*$)",
    eventsBlock .. "%1"
)

-- Sanity checks
assert(src:find("SEASONAL_EVENTS"), "SEASONAL_EVENTS block missing")
assert(src:find("HarvestFestival"), "HarvestFestival entry missing")
assert(src:find("yieldMult"), "yieldMult missing")

cfgOld.Name = "Config_OLD_pre_seasonal"
cfgClone.Source = src
cfgClone.Name   = "Config"
cfgClone.Parent = Modules
cfgOld.Parent   = nil

print("STEP A DONE: Config.SEASONAL_EVENTS added with HarvestFestival entry")
```

**Verify Step A:**

```lua
local RS = game:GetService("ReplicatedStorage")
local cfg = RS.Modules:FindFirstChild("Config")
assert(cfg, "Config not found")
local src = cfg.Source
print("SEASONAL_EVENTS:", src:find("SEASONAL_EVENTS") ~= nil)
print("HarvestFestival:", src:find("HarvestFestival") ~= nil)
print("yieldMult=1.25:", src:find("yieldMult%s*=%s*1%.25") ~= nil)
print("questOverride:", src:find("questOverride") ~= nil)
```

---

## STEP B — SeasonalEventService ModuleScript

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP B: Create SeasonalEventService ModuleScript
local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
assert(Systems, "Systems folder not found")

local old = Systems:FindFirstChild("SeasonalEventService")
if old then old:Destroy() end

local mod = Instance.new("ModuleScript")
mod.Name   = "SeasonalEventService"
mod.Parent = Systems

mod.Source = [[
--!strict
--[[
    SeasonalEventService
    Manages date-gated seasonal events. Server lifetime only — no profile data.
    Called once at Init; exposes GetActiveEvent(), GetYieldMult(), IsActive().
--]]

local SeasonalEventService = {}

local Config = require(game:GetService("ReplicatedStorage").Modules.Config)

-- Computed once at startup
local _activeEvent: {[string]: any}? = nil
local _announcedPlayers: {[number]: boolean} = {}

local function checkDate(): {[string]: any}?
    local t = os.date("*t") :: {year: number, month: number, day: number}
    for _, event in Config.SEASONAL_EVENTS do
        if t.month == event.month
            and t.day >= event.dayStart
            and t.day <= event.dayEnd then
            return event
        end
    end
    return nil
end

function SeasonalEventService.Init()
    _activeEvent = checkDate()
    if _activeEvent then
        print("[SeasonalEventService] Active event:", _activeEvent.name)
    else
        print("[SeasonalEventService] No seasonal event active today.")
    end
end

function SeasonalEventService.IsActive(): boolean
    return _activeEvent ~= nil
end

function SeasonalEventService.GetActiveEvent(): {[string]: any}?
    return _activeEvent
end

-- Returns 1.25 during Harvest Festival, 1.0 otherwise
function SeasonalEventService.GetYieldMult(): number
    if _activeEvent then
        return (_activeEvent.yieldMult :: number?) or 1.0
    end
    return 1.0
end

-- Returns quest override for daily slot 3 (or nil if no override)
function SeasonalEventService.GetQuestOverride(): {[string]: any}?
    if _activeEvent then
        return _activeEvent.questOverride
    end
    return nil
end

-- Called once per player on join to send the one-time festival banner
function SeasonalEventService.AnnounceToPlayer(player: Player)
    if not _activeEvent then return end
    if _announcedPlayers[player.UserId] then return end
    _announcedPlayers[player.UserId] = true
    local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    local notify = Remotes and Remotes:FindFirstChild("Notify")
    if notify then
        notify:FireClient(player, _activeEvent.bannerMsg, "success")
    end
end

-- Clean up on player leave to prevent memory leak
function SeasonalEventService.OnPlayerRemoving(player: Player)
    _announcedPlayers[player.UserId] = nil
end

return SeasonalEventService
]]

print("STEP B DONE: SeasonalEventService ModuleScript created in Systems")
```

---

## STEP C — Wire SeasonalEventService into Main server launcher

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP C: Add SeasonalEventService require + Init + PlayerAdded/Removing hooks to Main server Script
-- Find the Main Script in ServerScriptService (not Systems) and patch it.

local SSS = game:GetService("ServerScriptService")
local main = SSS:FindFirstChild("Main")
assert(main and main:IsA("Script"), "Main Script not found in ServerScriptService")

local mainOld   = main
local mainClone = mainOld:Clone()
local src       = mainOld.Source

-- Add require
local seasonalRequire = [[
local SeasonalEventService = require(SSS.Systems.SeasonalEventService)
]]
if not src:find("SeasonalEventService") then
    -- Insert after last require block (anchor on existing pattern)
    src = src:gsub(
        "(local%s+%w+Service%s*=%s*require%(SSS%.Systems%.OfflineProgressService%)[^\n]*\n)",
        "%1" .. seasonalRequire
    )
    -- Fallback anchor: before the final Players.PlayerAdded in Main
    if not src:find("SeasonalEventService") then
        src = src:gsub(
            "(Players%.PlayerAdded:Connect)",
            seasonalRequire .. "%1"
        )
    end
end

-- Add SeasonalEventService.Init() after existing service Inits
local seasonalInit = [[
SeasonalEventService.Init()
]]
if not src:find("SeasonalEventService%.Init") then
    -- Anchor: insert after OfflineProgressService is loaded (or after last .Init())
    src = src:gsub(
        "(OfflineProgressService[^\n]*\n)(.-)(Players%.PlayerAdded)",
        function(pre, mid, anchor)
            return pre .. mid .. seasonalInit .. anchor
        end
    )
    if not src:find("SeasonalEventService%.Init") then
        -- Simple fallback: append before Players.PlayerAdded
        src = src:gsub(
            "(Players%.PlayerAdded:Connect)",
            seasonalInit .. "%1"
        )
    end
end

-- Inside the PlayerAdded handler, call AnnounceToPlayer after profile loads
-- Anchor: find where OfflineProgressService.ApplyOfflineProgress is called
-- (added by dispatch 27) and append the announce call after it.
local announceCall = [[
        SeasonalEventService.AnnounceToPlayer(player)
]]
if not src:find("AnnounceToPlayer") then
    src = src:gsub(
        "(OfflineProgressService%.ApplyOfflineProgress%(player,%s*profile%).-\n)",
        "%1" .. announceCall
    )
    if not src:find("AnnounceToPlayer") then
        -- Fallback: append inside first ProfileLoaded block near WalletUpdate fire
        src = src:gsub(
            "(WalletUpdate:FireClient%(player)",
            announceCall .. "%1"
        )
    end
end

-- PlayerRemoving cleanup
local removingClean = [[
Players.PlayerRemoving:Connect(function(player)
    SeasonalEventService.OnPlayerRemoving(player)
end)
]]
if not src:find("OnPlayerRemoving") then
    src = src .. "\n" .. removingClean
end

-- Sanity
assert(src:find("SeasonalEventService"), "SeasonalEventService require missing")
assert(src:find("SeasonalEventService%.Init"), "SeasonalEventService.Init missing")

mainOld.Name = "Main_OLD_pre_seasonal"
mainClone.Source = src
mainClone.Name   = "Main"
mainClone.Parent = SSS
mainOld.Parent   = nil

print("STEP C DONE: Main now initializes SeasonalEventService and announces to players on join")
```

> **Manual fallback for Step C:** If regex anchors fail (print statement shows "DONE" but SeasonalEventService isn't wired):
> 1. At the top of `Main`, add: `local SeasonalEventService = require(SSS.Systems.SeasonalEventService)`
> 2. Near other service `.Init()` calls, add: `SeasonalEventService.Init()`
> 3. Inside the profile-loaded success path (after `OfflineProgressService.ApplyOfflineProgress`), add: `SeasonalEventService.AnnounceToPlayer(player)`
> 4. Add a `Players.PlayerRemoving` handler that calls `SeasonalEventService.OnPlayerRemoving(player)`

---

## STEP D — ForagingService: apply seasonal yield multiplier

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP D: Hook SeasonalEventService.GetYieldMult() into ForagingService yield calculation
-- ForagingService already applies BloomRush via a weatherMult local variable.
-- We add SeasonalEventService on top of that.

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
local fs = Systems:FindFirstChild("ForagingService")
assert(fs and fs:IsA("ModuleScript"), "ForagingService not found")

local fsOld   = fs
local fsClone = fsOld:Clone()
local src     = fsOld.Source

-- Add require (if not already present)
if not src:find("SeasonalEventService") then
    src = src:gsub(
        "(local ForagingService%s*=%s*%{%})",
        "local SeasonalEventService = require(script.Parent.SeasonalEventService)\n%1"
    )
end

-- Find where yield is computed (look for "yieldPerTrip" or "nectar" assignment)
-- and multiply by SeasonalEventService.GetYieldMult()
-- Anchor: dispatch 19 (WeatherService) added a weatherMult to yield — find that pattern
local seasonalYieldPatch = [[
            local seasonalMult = SeasonalEventService.GetYieldMult()
]]
if not src:find("seasonalMult") then
    -- Insert just before the line that computes total nectar yield
    src = src:gsub(
        "(local%s+weatherMult%s*=[^\n]+\n)",
        "%1" .. seasonalYieldPatch
    )
    -- Multiply into the yield calc: find "* weatherMult" and append "* seasonalMult"
    src = src:gsub(
        "(%*%s*weatherMult)([^%*\n]*\n)",
        "%1 * seasonalMult%2"
    )
end

if src:find("seasonalMult") then
    fsOld.Name = "ForagingService_OLD_pre_seasonal"
    fsClone.Source = src
    fsClone.Name   = "ForagingService"
    fsClone.Parent = Systems
    fsOld.Parent   = nil
    print("STEP D DONE: ForagingService applies seasonal yield multiplier")
else
    fsClone:Destroy()
    print("STEP D SKIP: Anchor not matched — manually add seasonalMult to the yield line in ForagingService")
    print("  Find the line with '* weatherMult' and change it to '* weatherMult * SeasonalEventService.GetYieldMult()'")
end
```

---

## STEP E — QuestService: slot 3 festival override on daily reset

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP E: Patch QuestService to override slot 3 with the festival quest when active
-- QuestService.pickDailyQuests() already exists from dispatch 23.

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
local qs = Systems:FindFirstChild("QuestService")
assert(qs and qs:IsA("ModuleScript"), "QuestService not found")

local qsOld   = qs
local qsClone = qsOld:Clone()
local src     = qsOld.Source

-- Add SeasonalEventService require (if not present)
if not src:find("SeasonalEventService") then
    src = src:gsub(
        "(local QuestService%s*=%s*%{%})",
        "local SeasonalEventService = require(script.Parent.SeasonalEventService)\n%1"
    )
end

-- After pickDailyQuests builds the 3-quest array, override slot 3 if festival active
local festivalOverride = [[
    -- Seasonal festival quest override for slot 3
    local questOverride = SeasonalEventService.GetQuestOverride()
    if questOverride then
        quests[3] = questOverride
    end
]]
-- Anchor: find the `return quests` line inside pickDailyQuests
if not src:find("questOverride") then
    src = src:gsub(
        "(return%s+quests%s*\n)(.-end)",
        festivalOverride .. "%1%2"
    )
    -- Simpler anchor fallback: just before first "return quests"
    if not src:find("questOverride") then
        src = src:gsub(
            "(return%s+quests)",
            festivalOverride .. "%1"
        )
    end
end

if src:find("questOverride") then
    qsOld.Name = "QuestService_OLD_pre_seasonal"
    qsClone.Source = src
    qsClone.Name   = "QuestService"
    qsClone.Parent = Systems
    qsOld.Parent   = nil
    print("STEP E DONE: QuestService overrides slot 3 with harvest_festival quest when active")
else
    qsClone:Destroy()
    print("STEP E SKIP: Anchor not matched — manually add festival override before 'return quests' in pickDailyQuests")
    print("  Add: local questOverride = SeasonalEventService.GetQuestOverride()")
    print("       if questOverride then quests[3] = questOverride end")
end
```

---

## STEP F — Harvest Stall world prop

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP F: Place Harvest Stall prop near hub entrance (4 parts).
-- Visible only during festival (toggled server-side via script).

local Workspace = game:GetService("Workspace")
local Map = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("Hub")
-- Place in Hub folder if it exists, else directly in Map
local parent = Map or Workspace

-- Remove existing stall if re-running
local existing = Workspace:FindFirstChild("HarvestStall", true)
if existing then existing:Destroy() end

local stall = Instance.new("Model")
stall.Name = "HarvestStall"
stall.Parent = parent

-- Stall base (wide wooden counter)
local base = Instance.new("Part")
base.Name      = "StallBase"
base.Size      = Vector3.new(8, 1, 3)
base.CFrame    = CFrame.new(-10, 4, -115)   -- just south of hub entrance, beside the path
base.Material  = Enum.Material.Wood
base.Color     = Color3.fromRGB(140, 90, 40) -- warm oak
base.Anchored  = true
base.CanCollide = true
base.Parent    = stall

-- Stall canopy (flat roof)
local canopy = Instance.new("Part")
canopy.Name      = "StallCanopy"
canopy.Size      = Vector3.new(9, 0.3, 4)
canopy.CFrame    = CFrame.new(-10, 7.5, -115)
canopy.Material  = Enum.Material.SmoothPlastic
canopy.Color     = Color3.fromRGB(200, 60, 30) -- harvest red-orange
canopy.Anchored  = true
canopy.CanCollide = false
canopy.Parent    = stall

-- Stall banner (SurfaceGui host)
local banner = Instance.new("Part")
banner.Name      = "StallBanner"
banner.Size      = Vector3.new(6, 1.5, 0.2)
banner.CFrame    = CFrame.new(-10, 9, -115)
banner.Material  = Enum.Material.SmoothPlastic
banner.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold
banner.Anchored  = true
banner.CanCollide = false
banner.Parent    = stall

local bannerGui = Instance.new("SurfaceGui")
bannerGui.Face   = Enum.NormalId.Front
bannerGui.Parent = banner
local bannerLabel = Instance.new("TextLabel")
bannerLabel.Size = UDim2.new(1, 0, 1, 0)
bannerLabel.BackgroundTransparency = 1
bannerLabel.Text = "🍯 Harvest Festival"
bannerLabel.Font = Enum.Font.FredokaOne
bannerLabel.TextScaled = true
bannerLabel.TextColor3 = Color3.fromRGB(80, 40, 0) -- Propolis Brown
bannerLabel.Parent = bannerGui

-- Honey jar decorative prop
local jar = Instance.new("Part")
jar.Name      = "HoneyJar"
jar.Shape     = Enum.PartType.Cylinder
jar.Size      = Vector3.new(1, 1.5, 1)
jar.CFrame    = CFrame.new(-8, 5, -115)
jar.Material  = Enum.Material.Neon
jar.Color     = Color3.fromRGB(242, 168, 28)  -- Honey Gold Neon
jar.Anchored  = true
jar.CanCollide = false
jar.Parent    = stall

-- Tag the stall for SeasonalEventService visibility toggling
local CS = game:GetService("CollectionService")
CS:AddTag(stall, "HarvestStall")

-- Default: stall visible only if festival is active right now
-- (SeasonalEventService.Init() runs at game start and sets visibility via the tag)
-- For the build step, leave visible so executor can see it placed correctly.
-- Runtime: Main script toggles stall visibility after SeasonalEventService.Init().
print("STEP F DONE: HarvestStall placed at (-10, 4, -115) near hub entrance")
print("  4 parts: StallBase, StallCanopy, StallBanner, HoneyJar")
print("  Tagged HarvestStall for visibility toggling by SeasonalEventService")
```

---

## STEP G — SeasonalEventService: stall visibility toggle

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP G: Add stall visibility toggle to SeasonalEventService
-- After Init() determines active event, hide the stall if no event is active.

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
local ses = Systems:FindFirstChild("SeasonalEventService")
assert(ses and ses:IsA("ModuleScript"), "SeasonalEventService not found")

local sesOld   = ses
local sesClone = sesOld:Clone()
local src      = sesOld.Source

local visibilityFn = [[

-- Toggle HarvestStall visibility based on active event
local function updateStallVisibility()
    local CS = game:GetService("CollectionService")
    local stalls = CS:GetTagged("HarvestStall")
    local active = _activeEvent ~= nil
    for _, stall in stalls do
        for _, part in stall:GetDescendants() do
            if part:IsA("BasePart") then
                part.Transparency = active and 0 or 1
                part.CanCollide   = active and (part.Name == "StallBase") or false
            end
        end
    end
end
]]

-- Insert the helper after _announcedPlayers declaration
src = src:gsub(
    "(local _announcedPlayers[^\n]+\n)",
    "%1" .. visibilityFn
)

-- Call updateStallVisibility() at the end of Init()
src = src:gsub(
    "(print%(%[SeasonalEventService%].-\n)",
    "%1    updateStallVisibility()\n"
)

if src:find("updateStallVisibility") then
    sesOld.Name = "SeasonalEventService_OLD_pre_visibility"
    sesClone.Source = src
    sesClone.Name   = "SeasonalEventService"
    sesClone.Parent = Systems
    sesOld.Parent   = nil
    print("STEP G DONE: SeasonalEventService now hides/shows HarvestStall based on active event")
else
    sesClone:Destroy()
    print("STEP G SKIP: Anchor not matched — manually add updateStallVisibility() call at end of Init()")
end
```

---

## STEP H — Verification

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP H: Verify SeasonalEventService + Harvest Festival setup
local SSS     = game:GetService("ServerScriptService")
local RS      = game:GetService("ReplicatedStorage")
local Systems = SSS:FindFirstChild("Systems")
local CS      = game:GetService("CollectionService")

local results = {}
local issues  = {}

-- 1. Config.SEASONAL_EVENTS
local cfg = RS.Modules:FindFirstChild("Config")
if cfg and cfg:IsA("ModuleScript") then
    local src = cfg.Source
    if src:find("SEASONAL_EVENTS") and src:find("HarvestFestival") then
        results[#results+1] = "PASS: Config.SEASONAL_EVENTS.HarvestFestival defined"
    else
        issues[#issues+1] = "FAIL: Config.SEASONAL_EVENTS or HarvestFestival missing"
    end
else
    issues[#issues+1] = "FAIL: Config not found"
end

-- 2. SeasonalEventService ModuleScript
local ses = Systems:FindFirstChild("SeasonalEventService")
if ses and ses:IsA("ModuleScript") then
    local src = ses.Source
    local checks = {
        hasStrict       = src:find("--!strict") ~= nil,
        hasInit         = src:find("SeasonalEventService%.Init") ~= nil,
        hasGetYieldMult = src:find("GetYieldMult") ~= nil,
        hasQuestOverride = src:find("GetQuestOverride") ~= nil,
        hasAnnounce     = src:find("AnnounceToPlayer") ~= nil,
        hasReturn       = src:find("return SeasonalEventService") ~= nil,
    }
    local fails = {}
    for k, v in checks do if not v then table.insert(fails, k) end end
    if #fails == 0 then
        local lines = select(2, src:gsub("\n", "\n")) + 1
        results[#results+1] = "PASS: SeasonalEventService ModuleScript (" .. lines .. " lines, all features present)"
    else
        issues[#issues+1] = "FAIL: SeasonalEventService missing: " .. table.concat(fails, ", ")
    end
else
    issues[#issues+1] = "FAIL: SeasonalEventService not found in Systems"
end

-- 3. HarvestStall world prop
local stalls = CS:GetTagged("HarvestStall")
if #stalls > 0 then
    local stall = stalls[1]
    local partCount = 0
    for _, p in stall:GetDescendants() do
        if p:IsA("BasePart") then partCount = partCount + 1 end
    end
    results[#results+1] = "PASS: HarvestStall placed (" .. partCount .. " parts)"
else
    issues[#issues+1] = "FAIL: No HarvestStall tagged part found in Workspace"
end

-- 4. ForagingService seasonal hook
local fs = Systems:FindFirstChild("ForagingService")
if fs and fs:IsA("ModuleScript") then
    if fs.Source:find("seasonalMult") or fs.Source:find("SeasonalEventService") then
        results[#results+1] = "PASS: ForagingService has SeasonalEventService hook"
    else
        issues[#issues+1] = "WARN: ForagingService missing SeasonalEventService hook (Step D may have skipped)"
    end
end

-- 5. No duplicate SeasonalEventService
local sesCount = 0
for _, child in Systems:GetChildren() do
    if child.Name == "SeasonalEventService" then sesCount = sesCount + 1 end
end
if sesCount == 1 then
    results[#results+1] = "PASS: exactly 1 SeasonalEventService"
else
    issues[#issues+1] = "FAIL: " .. sesCount .. " SeasonalEventService instances"
end

-- Summary
print("=== SEASONAL EVENTS VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\n--- ISSUES ---")
    for _, iss in issues do print(iss) end
    print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
    print("\nSTATUS: ALL CHECKS PASS — Harvest Festival framework ready")
    print("Festival active: month=10 (October). Check os.date() in Studio to confirm date.")
end
```

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| Config.SEASONAL_EVENTS | ModuleScript edit | ReplicatedStorage.Modules.Config |
| SeasonalEventService | ModuleScript | ServerScriptService.Systems |
| Main server Script | Script edit | ServerScriptService |
| ForagingService yield hook | ModuleScript edit | ServerScriptService.Systems |
| QuestService slot 3 override | ModuleScript edit | ServerScriptService.Systems |
| HarvestStall world prop | 4 Parts + SurfaceGui | Workspace (Hub) |

**SeasonalEventService API:**
- `Init()` — called once at server start; determines active event; hides/shows HarvestStall
- `IsActive()` → boolean — true if today falls in an event window
- `GetActiveEvent()` → table? — full event config or nil
- `GetYieldMult()` → number — 1.25 during Harvest Festival, 1.0 otherwise
- `GetQuestOverride()` → table? — festival quest template for slot 3 override, or nil
- `AnnounceToPlayer(player)` — fires Notify banner once per player per server lifetime
- `OnPlayerRemoving(player)` — cleans up announce-tracking table

**Harvest Festival behavior (October 1–31):**
- All foraging trips yield ×1.25 nectar (stacks with BloomRush's ×1.3 for ×1.625 combined)
- Daily quest slot 3 becomes "Festival Harvest" (harvest 2,000 honey, reward 1,500h + 50 propolis)
- "Harvest Festival Active!" Notify banner on first join
- HarvestStall prop visible at hub entrance

**Part budget:** +4 → **~4,098 / 5,000** total
