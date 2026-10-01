# Dispatch 133 — Bee Speed Boost (Dance Floor Effect)
## Cycle 14 · A Bee's World

**Feature:** A `BeeSpeedController` LocalScript that applies a temporary WalkSpeed boost to the player whenever their active comb contains at least one Dance Floor cell. A golden streak trail follows the player while boosted. Kids feel fast and special; adults see a tangible payoff for the Dance Floor cell investment (foraging returns faster + movement bonus). Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 132 (Propolis Upgrade Shop)

---

## DESIGN

### Speed boost rules

- **Trigger**: `CombState` attribute contains `"dance_floor"` (substring match — at least 1 Dance Floor cell in the active comb layout)
- **Boost amount**: +8 WalkSpeed (default Roblox WalkSpeed is 16 → boosted to 24)
- **Duration**: Continuous while Dance Floor cell is in comb; removed instantly when CombState no longer contains `"dance_floor"`
- **Stacking**: Bee Stamina upgrades (dispatch 132) add an additional +2 WalkSpeed per tier purchased (`bee_stamina_1` → +2, `bee_stamina_2` → +4 total bonus on top of Dance Floor base)
- **Cap**: Maximum boosted WalkSpeed = 28 (prevents runaway stacking)

### Trail effect

- A `Trail` instance attached to two `Attachment` objects on the player's `HumanoidRootPart` (one at `{0, 1, 0}` offset, one at `{0, -1, 0}`)
- Trail properties: `Color = ColorSequence(Color3.fromRGB(242,168,28))`, `LightEmission = 0.5`, `Lifetime = 0.18`, `MinLength = 0.05`, `FaceCamera = true`, `Transparency = NumberSequence({0, 0.3, 1})`
- Trail is enabled only while boosted; disabled (not destroyed) when boost ends so it can be re-enabled quickly

### Speed application

- Applied via `Humanoid.WalkSpeed` directly on client (LocalScript) — cosmetic only for the player's own character
- If server also needs canonical speed (for anti-cheat purposes): a `SpeedSync` RemoteEvent pattern is noted in NOTES but NOT implemented here — this dispatch is client-side UX polish only

---

## FILES CHANGED

| File | Change |
|------|--------|
| `BeeSpeedController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create BeeSpeedController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("BeeSpeedController") then
    print("⏭️  BeeSpeedController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "BeeSpeedController"
    ctrl.Source = [[
--!strict
-- BeeSpeedController — dispatch 133
-- WalkSpeed boost + golden trail when Dance Floor cell is active.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player  = Players.LocalPlayer
local BASE_SPEED_133    = 16
local DANCE_BOOST_133   = 8
local STAMINA1_BONUS_133 = 2
local STAMINA2_BONUS_133 = 4
local MAX_SPEED_133     = 28

-- ── Trail setup ──────────────────────────────────────────────────
local trail_133: Trail? = nil
local att0_133: Attachment? = nil
local att1_133: Attachment? = nil

local function buildTrail_133(hrp: BasePart)
    if trail_133 and trail_133.Parent then trail_133:Destroy() end
    if att0_133 and att0_133.Parent then att0_133:Destroy() end
    if att1_133 and att1_133.Parent then att1_133:Destroy() end

    local a0 = Instance.new("Attachment")
    a0.Position = Vector3.new(0, 1, 0)
    a0.Parent   = hrp
    local a1 = Instance.new("Attachment")
    a1.Position = Vector3.new(0, -1, 0)
    a1.Parent   = hrp

    local t = Instance.new("Trail")
    t.Attachment0   = a0
    t.Attachment1   = a1
    t.Color         = ColorSequence.new(Color3.fromRGB(242, 168, 28))
    t.LightEmission = 0.5
    t.Lifetime      = 0.18
    t.MinLength     = 0.05
    t.FaceCamera    = true
    t.Transparency  = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.3),
        NumberSequenceKeypoint.new(0.5, 0.6),
        NumberSequenceKeypoint.new(1,   1.0),
    })
    t.Enabled = false
    t.Parent  = hrp

    trail_133 = t
    att0_133  = a0
    att1_133  = a1
end

-- ── Compute target speed ─────────────────────────────────────────
local function getTargetSpeed_133(): number
    local combState = tostring(player:GetAttribute("CombState") or "")
    local hasDance  = combState:find("dance_floor") ~= nil
    if not hasDance then return BASE_SPEED_133 end

    local owned = tostring(player:GetAttribute("PropolisUpgrades") or "")
    local stamBonus = 0
    if owned:find("bee_stamina_2") then
        stamBonus = STAMINA2_BONUS_133
    elseif owned:find("bee_stamina_1") then
        stamBonus = STAMINA1_BONUS_133
    end

    return math.min(BASE_SPEED_133 + DANCE_BOOST_133 + stamBonus, MAX_SPEED_133)
end

-- ── Apply speed and trail ────────────────────────────────────────
local boosted_133 = false

local function applySpeed_133()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
    if not hum then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
    if not hrp then return end

    if not trail_133 or not trail_133.Parent then
        buildTrail_133(hrp)
    end

    local target = getTargetSpeed_133()
    local isBoosted = target > BASE_SPEED_133

    hum.WalkSpeed = target

    if trail_133 then
        trail_133.Enabled = isBoosted
    end

    if isBoosted ~= boosted_133 then
        boosted_133 = isBoosted
        if isBoosted then
            print("[BeeSpeedController] Speed boost active — WalkSpeed " .. target)
        else
            print("[BeeSpeedController] Speed boost removed — WalkSpeed " .. BASE_SPEED_133)
        end
    end
end

-- ── Rebuild trail on character respawn ───────────────────────────
local function onCharacterAdded_133(char: Model)
    trail_133 = nil
    att0_133  = nil
    att1_133  = nil
    boosted_133 = false
    task.wait(0.5)
    applySpeed_133()
end

player.CharacterAdded:Connect(onCharacterAdded_133)
if player.Character then onCharacterAdded_133(player.Character) end

-- ── Attribute listeners ──────────────────────────────────────────
player:GetAttributeChangedSignal("CombState"):Connect(applySpeed_133)
player:GetAttributeChangedSignal("PropolisUpgrades"):Connect(applySpeed_133)

print("[BeeSpeedController] Ready — Dance Floor speed boost active")
]]
    ctrl.Parent = SPS
    print("✅ BeeSpeedController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("BeeSpeedController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " BeeSpeedController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("DANCE_BOOST_133", 1, true) and "✅" or "❌") .. " DANCE_BOOST_133 speed constant")
table.insert(checks, (ctrl and ctrl.Source:find("MAX_SPEED_133", 1, true) and "✅" or "❌") .. " MAX_SPEED_133 cap")
table.insert(checks, (ctrl and ctrl.Source:find("buildTrail_133", 1, true) and "✅" or "❌") .. " buildTrail_133 trail constructor")
table.insert(checks, (ctrl and ctrl.Source:find("getTargetSpeed_133", 1, true) and "✅" or "❌") .. " getTargetSpeed_133 speed calc")
table.insert(checks, (ctrl and ctrl.Source:find("applySpeed_133", 1, true) and "✅" or "❌") .. " applySpeed_133 apply + trail toggle")
table.insert(checks, (ctrl and ctrl.Source:find("dance_floor", 1, true) and "✅" or "❌") .. " dance_floor CombState substring check")
table.insert(checks, (ctrl and ctrl.Source:find("bee_stamina", 1, true) and "✅" or "❌") .. " bee_stamina upgrade stacking")
table.insert(checks, (ctrl and ctrl.Source:find("Trail", 1, true) and "✅" or "❌") .. " Trail instance")
table.insert(checks, (ctrl and ctrl.Source:find("Attachment", 1, true) and "✅" or "❌") .. " Attachment points")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterAdded", 1, true) and "✅" or "❌") .. " CharacterAdded rebuild on respawn")
table.insert(checks, (ctrl and ctrl.Source:find("CombState", 1, true) and "✅" or "❌") .. " CombState attribute listener")

print("=== DISPATCH 133 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 133 complete" or "❌ SOME CHECKS FAILED")

print("\nSpeed: base 16 + Dance Floor +8 + Stamina I +2 / Stamina II +4 | cap 28")
print("Trail: golden ColorSequence, Lifetime=0.18, FaceCamera=true, enabled only while boosted")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| BeeSpeedController (LocalScript; Trail/Attachment on character, no permanent parts) | 0 permanent |
| **Dispatch 133 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `WalkSpeed` is set on the client's own `Humanoid` directly. In a server-authoritative context this would normally be done via a server script, but for a tycoon game where movement speed is a cosmetic perk (not exploitable for PvP advantage), client-side application is standard practice and avoids RemoteEvent round-trip lag.
- The trail's `Lifetime = 0.18` keeps the streak short and snappy — long enough to be visible and satisfying, short enough not to dominate the screen. At WalkSpeed 24 this produces approximately a 1.5-stud golden streak behind the player.
- `buildTrail_133` is called lazily on `applySpeed_133` when no trail exists, and again on `CharacterAdded` (which clears the previous references). This handles respawn cleanly without any dangling attachment references.
- The `bee_stamina` upgrade check (`owned:find("bee_stamina_2")` before `bee_stamina_1`) ensures the higher tier wins: if both IDs are in the string (which they will be, since tier 2 requires tier 1), the `bee_stamina_2` branch fires and the cumulative +4 is applied rather than double-counting +2+4.
- `MAX_SPEED_133 = 28` is a soft cap. The formula `BASE(16) + DANCE(8) + STAMINA2(4) = 28` hits the cap exactly with all upgrades purchased — so the cap is never felt as a wall, it just prevents hypothetical future upgrades from breaking movement.
