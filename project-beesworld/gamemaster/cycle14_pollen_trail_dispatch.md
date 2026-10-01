# Dispatch 126 — Pollen Trail VFX (Bee Return Effect)
## Cycle 14 · A Bee's World

**Feature:** A `PollenTrailController` LocalScript that spawns a brief golden pollen burst effect at the player's hive comb plot whenever foragers return (ForagingActive → false). A shower of yellow/gold particles rains down for 1.5 seconds, accompanied by the existing forager return sound from `HiveAmbienceController`. Kids see sparkly pollen; adults see a satisfying visual harvest confirmation tied to yield quality (better patch = more particles). Part budget: +0 permanent.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 125 (Stat Tracking Wires)

---

## DESIGN

### Particle burst

- Attachment point: find the player's comb plot `BasePart` in Workspace (same search as `HoneyRipenessController`) or fall back to the player's character `HumanoidRootPart`
- `ParticleEmitter` on a temporary invisible `Part` (Transparency=1, CanCollide=false, Anchored=true, Size 1×1×1) placed at the plot centre
- Burst emits once (`Emit(count)`) rather than looping — no `Enabled=true` lingering
- Part + emitter are destroyed after 2.5 seconds via `Debris` service

### Particle properties

| Property | Low quality (Q 0-39) | Mid quality (Q 40-79) | High quality (Q 80-100) |
|----------|---------------------|----------------------|------------------------|
| Count | 15 | 30 | 55 |
| Color | pale gold | honey gold | bright amber |
| Size | 0.08 | 0.12 | 0.16 |
| Speed | 6 | 9 | 12 |
| Lifetime | 1.2 | 1.5 | 1.8 |

### Fallback

If the comb plot part can't be found, emit from the player's HumanoidRootPart position + `{0, 3, 0}` offset. This always works.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PollenTrailController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create PollenTrailController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PollenTrailController") then
    print("⏭️  PollenTrailController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PollenTrailController"
    ctrl.Source = [[
--!strict
-- PollenTrailController — dispatch 126
-- Pollen burst particle effect when foragers return to the hive.

local Players = game:GetService("Players")
local Debris  = game:GetService("Debris")

local player = Players.LocalPlayer

-- ── Quality tiers for particle count/size ────────────────────────
type BurstTier = {count: number, color: Color3, size: number, speed: number, lifetime: number}
local TIERS_126: {BurstTier} = {
    -- Low 0-39
    {count=15,  color=Color3.fromRGB(240,210,100), size=0.08, speed=6,  lifetime=1.2},
    -- Mid 40-79
    {count=30,  color=Color3.fromRGB(242,168,28),  size=0.12, speed=9,  lifetime=1.5},
    -- High 80-100
    {count=55,  color=Color3.fromRGB(255,200,30),  size=0.16, speed=12, lifetime=1.8},
}

local function getTier_126(quality: number): BurstTier
    if quality >= 80 then return TIERS_126[3]
    elseif quality >= 40 then return TIERS_126[2]
    else return TIERS_126[1]
    end
end

-- ── Find comb plot anchor part ────────────────────────────────────
local function findPlotPart_126(): BasePart?
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return nil end

    local uid = tostring(player.UserId)
    for _, folder in mapFolder:GetDescendants() do
        if folder:IsA("Folder") and (folder.Name:find(uid) or folder.Name:find("Plot")) then
            -- Return first BasePart found in this folder as the anchor
            for _, child in folder:GetDescendants() do
                if child:IsA("BasePart") and child.Anchored then
                    return child :: BasePart
                end
            end
        end
    end
    return nil
end

-- ── Emit burst ────────────────────────────────────────────────────
local function emitPollenBurst_126(quality: number)
    local tier = getTier_126(quality)

    -- Find anchor position
    local anchorPos: Vector3
    local plotPart = findPlotPart_126()
    if plotPart then
        anchorPos = plotPart.Position + Vector3.new(0, 3, 0)
    else
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not hrp then return end
        anchorPos = hrp.Position + Vector3.new(0, 3, 0)
    end

    -- Create invisible anchor part
    local anchor = Instance.new("Part")
    anchor.Size             = Vector3.new(1, 1, 1)
    anchor.Position         = anchorPos
    anchor.Transparency     = 1
    anchor.CanCollide       = false
    anchor.Anchored         = true
    anchor.CastShadow       = false
    anchor.Parent           = workspace

    -- Create emitter
    local emitter = Instance.new("ParticleEmitter")
    emitter.Color           = ColorSequence.new(tier.color)
    emitter.Size            = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    tier.size),
        NumberSequenceKeypoint.new(0.6,  tier.size * 0.7),
        NumberSequenceKeypoint.new(1,    0),
    })
    emitter.Transparency    = NumberSequence.new({
        NumberSequenceKeypoint.new(0,    0.1),
        NumberSequenceKeypoint.new(0.7,  0.4),
        NumberSequenceKeypoint.new(1,    1),
    })
    emitter.LightEmission   = 0.4
    emitter.LightInfluence  = 0.2
    emitter.Speed           = NumberRange.new(tier.speed * 0.6, tier.speed)
    emitter.SpreadAngle     = Vector2.new(180, 180)   -- omnidirectional burst
    emitter.Rotation        = NumberRange.new(0, 360)
    emitter.RotSpeed        = NumberRange.new(-60, 60)
    emitter.Lifetime        = NumberRange.new(tier.lifetime * 0.8, tier.lifetime)
    emitter.Rate            = 0    -- burst only, no continuous emission
    emitter.Parent          = anchor

    -- Fire burst
    emitter:Emit(tier.count)

    -- Cleanup after particles die
    Debris:AddItem(anchor, tier.lifetime + 0.5)
end

-- ── Track ForagingActive transitions ─────────────────────────────
local wasForaging_126 = false

task.wait(2)
wasForaging_126 = player:GetAttribute("ForagingActive") == true

player:GetAttributeChangedSignal("ForagingActive"):Connect(function()
    local nowForaging = player:GetAttribute("ForagingActive") == true
    if wasForaging_126 and not nowForaging then
        -- Bees just returned — emit burst
        local quality = tonumber(player:GetAttribute("ForagingQuality")) or 60
        emitPollenBurst_126(quality)
    end
    wasForaging_126 = nowForaging
end)

print("[PollenTrailController] Ready — pollen burst on forager return")
]]
    ctrl.Parent = SPS
    print("✅ PollenTrailController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PollenTrailController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " PollenTrailController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("TIERS_126", 1, true) and "✅" or "❌") .. " TIERS_126 burst quality table")
table.insert(checks, (ctrl and ctrl.Source:find("getTier_126", 1, true) and "✅" or "❌") .. " getTier_126 helper")
table.insert(checks, (ctrl and ctrl.Source:find("emitPollenBurst_126", 1, true) and "✅" or "❌") .. " emitPollenBurst_126")
table.insert(checks, (ctrl and ctrl.Source:find("findPlotPart_126", 1, true) and "✅" or "❌") .. " findPlotPart_126 locator")
table.insert(checks, (ctrl and ctrl.Source:find("Debris", 1, true) and "✅" or "❌") .. " Debris cleanup (no part leaks)")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingActive", 1, true) and "✅" or "❌") .. " ForagingActive transition listener")
table.insert(checks, (ctrl and ctrl.Source:find("ForagingQuality", 1, true) and "✅" or "❌") .. " ForagingQuality for tier selection")
table.insert(checks, (ctrl and ctrl.Source:find("wasForaging_126", 1, true) and "✅" or "❌") .. " wasForaging_126 state tracking")
table.insert(checks, (ctrl and ctrl.Source:find("Emit(", 1, true) and "✅" or "❌") .. " Emit() burst (not continuous Rate)")
table.insert(checks, (ctrl and ctrl.Source:find("SpreadAngle", 1, true) and "✅" or "❌") .. " 360-degree burst spread")

print("=== DISPATCH 126 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 126 complete" or "❌ SOME CHECKS FAILED")

print("\nBurst tiers: Low Q=15 pale gold | Mid Q=30 honey gold | High Q=55 bright amber")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| PollenTrailController (LocalScript; runtime Parts destroyed by Debris) | 0 permanent |
| **Dispatch 126 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The anchor `Part` exists only while particles are alive — `Debris:AddItem(anchor, lifetime + 0.5)` ensures the part is destroyed after the longest-lived particle fades out. The part is never permanent.
- `emitter.Rate = 0` with `emitter:Emit(count)` is the correct Roblox pattern for a one-shot burst — a continuous emitter (`Rate > 0, Enabled = true`) left in the world would leak particles. This approach is clean and self-contained.
- `SpreadAngle = Vector2.new(180, 180)` creates a true omnidirectional burst — particles fly in all directions around the anchor point, simulating bees arriving from all compass directions simultaneously.
- `LightEmission = 0.4` gives particles a subtle self-glow (realistic for pollen in sunlight without being cartoonish). `LightInfluence = 0.2` means lighting conditions slightly affect particle brightness so they look different in the warm hive interior vs. bright outdoor areas.
- The `wasForaging_126` bool is initialized from the current attribute state with a 2-second delay (matching the `task.wait(2)` pattern used by other dispatch 12x controllers). This prevents a spurious burst on first load if `ForagingActive` is already false at startup.
- Particle count scales with foraging quality (15 → 55) — a poor patch shows a wimpy trickle of pollen; an amazing patch delivers a lush golden shower. This reinforces the foraging quality mechanic viscerally without any text explanation.
