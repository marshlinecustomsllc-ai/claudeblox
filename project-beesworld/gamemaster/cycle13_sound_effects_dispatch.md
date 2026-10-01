# Dispatch 96 — Sound Effects: Upgrade Purchase & Prestige
## Cycle 13 · A Bee's World

**Feature:** Two high-impact game events — buying an upgrade and prestiging — currently have no audio feedback. This dispatch adds a `SoundController` (client-side LocalScript) that plays short sound effects on `UpgradeSync` and `PrestigeSync` events. Uses free Roblox audio assets: a short chime for upgrades and a longer trumpet/fanfare for prestige. No new server scripts required.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 95 (Daily Reward Expansion)

---

## DESIGN

### Sound assets (free Roblox audio)

| Event | Sound | Asset ID | Notes |
|-------|-------|----------|-------|
| Upgrade purchase | Short positive chime | `rbxassetid://9119816100` | Brief 0.5s ding — Roblox library |
| Prestige | Fanfare / level-up | `rbxassetid://4612394677` | ~2s trumpet swell |
| Upgrade denied (not enough) | Soft thud / error | `rbxassetid://9120264459` | 0.3s click/block |

All three are loaded into `SoundService` under an `SFX` SoundGroup for volume control.

### Architecture

`SoundController` LocalScript in `StarterPlayerScripts`:
1. Creates Sound objects in `SoundService.SFX` (or reuses if already present)
2. Listens to `UpgradeSync` — on `{success=true}` fire: play upgrade chime
3. Listens to `UpgradeSync` — on `{success=false}` fire: play denied thud
4. Listens to `PrestigeSync` — on any fire: play prestige fanfare
5. SFX SoundGroup volume = 0.5 (below ambient, above silence)

### Why client-side only

Upgrade and prestige events already fire `RemoteEvent`s to the client (`UpgradeSync`, `PrestigeSync` from earlier dispatches). The client can play sounds directly from those events without any server changes. This keeps the audio layer fully decoupled from game logic.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `SoundController` | New LocalScript in StarterPlayerScripts — plays SFX on upgrade/prestige events |

---

## STEP A — Create SoundController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("SoundController") then
    print("⏭️  SoundController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "SoundController"
    ctrl.Source = [[
--!strict
-- SoundController — dispatch 96
-- Plays SFX on upgrade purchase and prestige events (client-side only)

local Players    = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local RS         = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ── SFX SoundGroup ───────────────────────────────────────────────
local sfxGroup = SoundService:FindFirstChild("SFX")
if not sfxGroup then
    sfxGroup = Instance.new("SoundGroup")
    sfxGroup.Name   = "SFX"
    sfxGroup.Volume = 0.5
    sfxGroup.Parent = SoundService
end

local SOUNDS: {[string]: {id: string, vol: number}} = {
    upgradeBuy    = {id = "rbxassetid://9119816100", vol = 0.6},
    upgradeDeny   = {id = "rbxassetid://9120264459", vol = 0.4},
    prestige      = {id = "rbxassetid://4612394677", vol = 0.7},
}

local soundObjs: {[string]: Sound} = {}

for name, info in SOUNDS do
    local s = sfxGroup:FindFirstChild(name)
    if not s then
        s = Instance.new("Sound")
        s.Name        = name
        s.SoundId     = info.id
        s.Volume      = info.vol
        s.RollOffMaxDistance = 0   -- 2D (no rolloff — SFX not spatial)
        s.Parent      = sfxGroup
    end
    soundObjs[name] = s :: Sound
end

local function play(name: string)
    local s = soundObjs[name]
    if s then
        s:Stop()
        s:Play()
    end
end

-- ── Event listeners ──────────────────────────────────────────────
task.spawn(function()
    -- UpgradeSync: {success=true/false, upgradeId=string}
    local upgradeSync = RS:WaitForChild("UpgradeSync", 15)
    if upgradeSync then
        (upgradeSync :: RemoteEvent).OnClientEvent:Connect(function(data: {success: boolean})
            if data and data.success == true then
                play("upgradeBuy")
            elseif data and data.success == false then
                play("upgradeDeny")
            end
        end)
        print("[SoundController] UpgradeSync bound")
    else
        warn("[SoundController] UpgradeSync not found after 15s")
    end
end)

task.spawn(function()
    -- PrestigeSync: fires on prestige complete
    local prestigeSync = RS:WaitForChild("PrestigeSync", 15)
    if prestigeSync then
        (prestigeSync :: RemoteEvent).OnClientEvent:Connect(function(_data: {[string]: any})
            -- Small delay so prestige animation has started before the fanfare
            task.wait(0.3)
            play("prestige")
        end)
        print("[SoundController] PrestigeSync bound")
    else
        warn("[SoundController] PrestigeSync not found after 15s")
    end
end)

print("[SoundController] Ready — upgrade chime + prestige fanfare active")
]]

    ctrl.Parent = SPS
    print("✅ SoundController created in StarterPlayerScripts")
end
```

---

## STEP B — Ensure SFX SoundGroup exists in SoundService (server-side pre-create)

This step pre-creates the `SFX` SoundGroup so it's available before any client connects. Optional but prevents a brief race on first load.

Command Bar:

```lua
local SS = game:GetService("SoundService")
if SS:FindFirstChild("SFX") then
    print("⏭️  SFX SoundGroup already exists — skip")
else
    local grp = Instance.new("SoundGroup")
    grp.Name   = "SFX"
    grp.Volume = 0.5
    grp.Parent = SS
    print("✅ SFX SoundGroup created in SoundService")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local SS  = game:GetService("SoundService")

local checks = {}

local sc = SPS and SPS:FindFirstChild("SoundController")
table.insert(checks, (sc and "✅" or "❌") .. " SoundController exists in StarterPlayerScripts")
table.insert(checks, (sc and sc:IsA("LocalScript") and "✅" or "❌") .. " SoundController is a LocalScript")
table.insert(checks, (sc and sc.Source:find("UpgradeSync", 1, true) and "✅" or "❌") .. " SoundController: listens to UpgradeSync")
table.insert(checks, (sc and sc.Source:find("PrestigeSync", 1, true) and "✅" or "❌") .. " SoundController: listens to PrestigeSync")
table.insert(checks, (sc and sc.Source:find("upgradeBuy", 1, true) and "✅" or "❌") .. " SoundController: upgradeBuy sound defined")
table.insert(checks, (sc and sc.Source:find("prestige", 1, true) and "✅" or "❌") .. " SoundController: prestige sound defined")
table.insert(checks, (sc and sc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " SoundController: --!strict")

local sfxGroup = SS:FindFirstChild("SFX")
table.insert(checks, (sfxGroup and "✅" or "❌") .. " SFX SoundGroup in SoundService")
table.insert(checks, (sfxGroup and sfxGroup.Volume <= 0.6 and "✅" or "❌") .. " SFX SoundGroup volume within range")

print("=== DISPATCH 96 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 96 complete" or "❌ SOME CHECKS FAILED")

print("\nSound asset IDs:")
print("  upgradeBuy:  rbxassetid://9119816100")
print("  upgradeDeny: rbxassetid://9120264459")
print("  prestige:    rbxassetid://4612394677")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| LocalScript + SoundGroup (no BaseParts) | 0 new server parts |
| **Dispatch 96 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- Asset IDs `9119816100`, `9120264459`, and `4612394677` are public Roblox audio library assets. If any ID is deprecated by the time this dispatch is executed, substitute with any free short positive chime / error thud / fanfare from the Audio library (search "chime", "error click", "level up fanfare"). The asset ID format `rbxassetid://XXXXXXXXXX` is the correct string format for Sound.SoundId.
- `s:Stop(); s:Play()` — stopping before playing ensures rapid double-triggers (buying two upgrades quickly) restart the sound rather than overlapping.
- `RollOffMaxDistance = 0` disables spatial rolloff on SFX sounds. They play at constant volume regardless of camera position. This is correct for UI-feedback sounds.
- The `task.wait(0.3)` delay before the prestige fanfare allows the prestige particle effect or screen flash (if any exists from earlier dispatches) to begin first, giving the audio a natural "punctuation" feel.
- If `PrestigeSync` fires `{prestigeLevel = N, multiplier = M}` (as designed in dispatch 81), the `_data` parameter is typed as `{[string]: any}` and the handler ignores payload content — it only cares that the event fired. Future dispatches can add prestige-level-specific sounds (louder at higher prestige) by reading `_data.prestigeLevel`.
- Volume hierarchy: SFX SoundGroup at 0.5 × individual sound volumes (0.4–0.7) → effective max SFX level ≈ 0.35, well below the 0.7 environmental audio cap from dispatch 22. UI SFX should be quieter than world ambient.
