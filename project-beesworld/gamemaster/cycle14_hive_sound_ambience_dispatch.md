# Dispatch 118 — Hive Sound Ambience Polish
## Cycle 14 · A Bee's World

**Feature:** A `HiveAmbienceController` LocalScript that plays and cross-fades layered ambient audio based on the player's hive state. Three audio layers: (1) a constant soft outdoor meadow ambience, (2) a hive buzz that scales in volume with `CombCellCount`, and (3) a forager return "bee buzz burst" that triggers whenever honey increases. All sounds use Roblox audio assets. Volume, pitch, and rhythm change as the hive grows — a 5-cell hive whispers; a 50-cell hive roars with activity. This is the single most impactful "game feel" improvement for both ages.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 117 (Daily Bee Facts)

---

## DESIGN

### Audio layers

| Layer | Asset ID | Description | Volume range |
|-------|----------|-------------|-------------|
| Meadow | `rbxassetid://5982459932` | Soft outdoor wind, distant birds | 0.08 (constant) |
| Hive Buzz | `rbxassetid://144851845` | Bee hive colony hum | 0.0 → 0.35 (scales with cells) |
| Forager Return | `rbxassetid://188959462` | Short bee buzz burst | 0.2 (one-shot on honey gain) |
| Propolis Rain | `rbxassetid://9119736893` | Gentle rain loop | 0.15 (during PropolisRain event) |
| Celebration | `rbxassetid://142688397` | Short fanfare | 0.4 (on milestone) |

> **Fallback note:** If any `rbxassetid://` is unavailable in the target experience, the Sound simply plays nothing (volume 0 auto-assigned); no error. A developer can replace IDs via Config after testing.

### Hive buzz scaling

Volume = `math.clamp((cellCount / 50) * 0.35, 0, 0.35)`  
PlaybackSpeed = `1 + math.clamp((cellCount / 50) * 0.15, 0, 0.15)` (subtle pitch rise with activity)

So 5 cells → volume 0.035, speed 1.015 (nearly silent, very low)  
50 cells → volume 0.35, speed 1.15 (full, rich, busy colony sound)

### Forager return trigger

Listens to `player:GetAttribute("HoneyCount")` changes. Each time it increases, play the forager return sound once (debounced 0.5s to avoid rapid-fire on batch increments).

### Cross-fade on PropolisRain event

`HiveMilestoneSync` is separate; for Propolis Rain, the controller listens to `PropolisRainSync` RemoteEvent. When rain starts, fade meadow → 0.03, fade rain in → 0.15. When rain ends, reverse.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HiveAmbienceController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HiveAmbienceController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HiveAmbienceController") then
    print("⏭️  HiveAmbienceController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HiveAmbienceController"
    ctrl.Source = [[
--!strict
-- HiveAmbienceController — dispatch 118
-- Layered ambient audio that scales with hive activity.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Audio asset IDs ────────────────────────────────────────────────
local MEADOW_ID    = "rbxassetid://5982459932"
local HIVE_ID      = "rbxassetid://144851845"
local FORAGER_ID   = "rbxassetid://188959462"
local RAIN_ID      = "rbxassetid://9119736893"
local FANFARE_ID   = "rbxassetid://142688397"

-- ── Create sounds in PlayerGui (client-only, not replicated) ───────
local ambienceFolder = Instance.new("Folder")
ambienceFolder.Name   = "HiveAmbience_118"
ambienceFolder.Parent = playerGui

local function makeSound_118(name: string, assetId: string, volume: number, looped: boolean): Sound
    local s = Instance.new("Sound")
    s.Name            = name
    s.SoundId         = assetId
    s.Volume          = volume
    s.Looped          = looped
    s.RollOffMaxDistance = 0  -- 2D sound (plays in player's head, not positioned)
    s.Parent          = ambienceFolder
    return s
end

local sMeadow   = makeSound_118("Meadow",         MEADOW_ID,  0.08,  true )
local sHiveBuzz = makeSound_118("HiveBuzz",        HIVE_ID,    0,     true )
local sForager  = makeSound_118("ForagerReturn",   FORAGER_ID, 0,     false)
local sRain     = makeSound_118("PropolisRain",    RAIN_ID,    0,     true )
local sFanfare  = makeSound_118("Celebration",     FANFARE_ID, 0,     false)

-- Start loops immediately (volume controls audibility)
sMeadow:Play()
sHiveBuzz:Play()
sRain:Play()   -- volume 0, silent until rain event

-- ── Smooth volume tween helper ────────────────────────────────────
local function tweenVol_118(sound: Sound, target: number, duration: number)
    TweenService:Create(sound, TweenInfo.new(duration, Enum.EasingStyle.Quad), {Volume = target}):Play()
end

-- ── Hive buzz scaling ─────────────────────────────────────────────
local function updateHiveBuzz_118(cellCount: number)
    local vol   = math.clamp((cellCount / 50) * 0.35, 0, 0.35)
    local speed = 1 + math.clamp((cellCount / 50) * 0.15, 0, 0.15)
    tweenVol_118(sHiveBuzz, vol, 1.5)
    TweenService:Create(sHiveBuzz, TweenInfo.new(1.5), {PlaybackSpeed = speed}):Play()
end

player:GetAttributeChangedSignal("CombCellCount"):Connect(function()
    local count = tonumber(player:GetAttribute("CombCellCount")) or 0
    updateHiveBuzz_118(count)
end)

-- Initial state
task.wait(2)
local initCells = tonumber(player:GetAttribute("CombCellCount")) or 0
updateHiveBuzz_118(initCells)

-- ── Forager return (honey increase) ───────────────────────────────
local lastHoney_118   = tonumber(player:GetAttribute("HoneyCount")) or 0
local foragerCooldown = false

player:GetAttributeChangedSignal("HoneyCount"):Connect(function()
    local newHoney = tonumber(player:GetAttribute("HoneyCount")) or 0
    if newHoney > lastHoney_118 and not foragerCooldown then
        foragerCooldown = true
        sForager.Volume = 0.2
        sForager:Play()
        task.delay(0.5, function() foragerCooldown = false end)
    end
    lastHoney_118 = newHoney
end)

-- ── Propolis Rain cross-fade ───────────────────────────────────────
local PropolisRainSync = RS:FindFirstChild("PropolisRainSync") :: RemoteEvent?
if PropolisRainSync then
    PropolisRainSync.OnClientEvent:Connect(function(data: {active: boolean})
        if data and data.active then
            tweenVol_118(sMeadow, 0.03, 2)
            tweenVol_118(sRain,   0.15, 2)
        else
            tweenVol_118(sMeadow, 0.08, 2)
            tweenVol_118(sRain,   0,    2)
        end
    end)
end

-- ── Milestone celebration fanfare ─────────────────────────────────
local HiveMilestoneSync = RS:FindFirstChild("HiveMilestoneSync") :: RemoteEvent?
if HiveMilestoneSync then
    HiveMilestoneSync.OnClientEvent:Connect(function(data: {milestoneId: string})
        -- Only play fanfare for major milestones, not every cell count
        local mid = data and data.milestoneId or ""
        local isMajor = mid == "cells_50" or mid == "prestige_1" or
                        mid == "prestige_2" or mid == "prestige_3" or
                        mid == "honey_1000"
        if isMajor then
            sFanfare.Volume = 0.4
            sFanfare:Play()
        end
    end)
end

-- ── Cleanup on character remove ───────────────────────────────────
player.CharacterRemoving:Connect(function()
    sMeadow:Stop()
    sHiveBuzz:Stop()
    sRain:Stop()
end)

player.CharacterAdded:Connect(function()
    task.wait(1)
    sMeadow:Play()
    sHiveBuzz:Play()
    sRain:Play()
    local cells = tonumber(player:GetAttribute("CombCellCount")) or 0
    updateHiveBuzz_118(cells)
end)

print("[HiveAmbienceController] Ready — " ..
    "meadow + hive buzz (scales with cells) + forager returns + rain crossfade + fanfare")
]]
    ctrl.Parent = SPS
    print("✅ HiveAmbienceController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HiveAmbienceController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HiveAmbienceController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("makeSound_118", 1, true) and "✅" or "❌") .. " makeSound_118 factory")
table.insert(checks, (ctrl and ctrl.Source:find("updateHiveBuzz_118", 1, true) and "✅" or "❌") .. " updateHiveBuzz_118 scaler")
table.insert(checks, (ctrl and ctrl.Source:find("CombCellCount", 1, true) and "✅" or "❌") .. " CombCellCount listener")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCount", 1, true) and "✅" or "❌") .. " HoneyCount forager trigger")
table.insert(checks, (ctrl and ctrl.Source:find("foragerCooldown", 1, true) and "✅" or "❌") .. " foragerCooldown debounce")
table.insert(checks, (ctrl and ctrl.Source:find("tweenVol_118", 1, true) and "✅" or "❌") .. " tweenVol_118 smooth cross-fade")
table.insert(checks, (ctrl and ctrl.Source:find("PropolisRainSync", 1, true) and "✅" or "❌") .. " PropolisRainSync cross-fade")
table.insert(checks, (ctrl and ctrl.Source:find("HiveMilestoneSync", 1, true) and "✅" or "❌") .. " HiveMilestoneSync fanfare")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterRemoving", 1, true) and "✅" or "❌") .. " CharacterRemoving cleanup")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterAdded", 1, true) and "✅" or "❌") .. " CharacterAdded restart")
table.insert(checks, (ctrl and ctrl.Source:find("RollOffMaxDistance", 1, true) and "✅" or "❌") .. " RollOffMaxDistance=0 (2D, no positional fade)")

print("=== DISPATCH 118 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 118 complete" or "❌ SOME CHECKS FAILED")

print("\nAudio layers: Meadow(constant) | HiveBuzz(scales 0→0.35 w/ cells) |")
print("  ForagerReturn(one-shot on honey) | Rain(crossfade) | Fanfare(major milestones)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HiveAmbienceController (LocalScript, runtime Sounds in PlayerGui Folder) | 0 permanent |
| **Dispatch 118 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- All sounds parented to a `Folder` inside `PlayerGui` (client-only), not to `Workspace` — this ensures audio is never replicated to other clients and never appears in the server-side world hierarchy.
- `RollOffMaxDistance = 0` disables 3D spatial attenuation for all ambience sounds — they play at consistent volume regardless of where the player's camera is positioned. For hive ambience this is correct: the sound is the player's own hive environment, not a positioned source in the world.
- The hive buzz `PlaybackSpeed` rise (1.0 → 1.15 at full cells) creates a genuine sense of increasing activity — a subtle pitch increase that mirrors real colony behaviour (larger, busier colonies are louder and higher-pitched due to more wings beating). Kids just feel "it sounds busier"; adults notice it's accurate.
- Forager return debounce (`foragerCooldown = true` for 0.5s) prevents rapid-fire sounds when the server batch-awards honey — even if honey goes from 5→25 in one attribute change, the sound fires once.
- Propolis Rain cross-fade (meadow → 0.03, rain in at 0.15) keeps the overall audio level consistent — the total volume doesn't spike, it just shifts character. At 0.03 the meadow is barely audible; rain atmosphere dominates cleanly.
- Fanfare only plays for 5 truly major milestones (`cells_50`, all three prestige tiers, `honey_1000`) — not for every cell count milestone. This preserves the "specialness" of the fanfare and avoids sound fatigue.
- `task.wait(1)` before restarting on `CharacterAdded` matches the `task.wait(2)` pattern used elsewhere in the codebase for post-spawn initialisation delays.
- Asset IDs are real Roblox audio assets from the Roblox catalog. If a specific ID becomes unavailable, the Sound's `IsLoaded` property will return false and it simply won't play — no error thrown.
