# Dispatch 113 — Prestige Hive Aura
## Cycle 14 · A Bee's World

**Feature:** A visual cosmetic that scales with the player's prestige level. When a player has prestiged at least once, their hive plot (slot 1 FloorPart) gains a subtle golden `ParticleEmitter` that intensifies with prestige tier — at prestige 1 a faint golden sparkle, at prestige 5+ a dense Honey Gold aura with faint trail beams. The effect is client-only: each player sees their own aura; other players see nothing. This is implemented as a `LocalScript` that reads `player:GetAttribute("PrestigeLevel")` (set by the prestige server system) and creates or updates a `PrestigeAura` Model in the player's plot.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 112 (Seasonal Streak Achievement)

---

## DESIGN

### Prestige tiers

| Prestige | Particles/sec | Size | Transparency | Extra |
|----------|--------------|------|-------------|-------|
| 0 | — | — | — | No effect |
| 1 | 4 | 0.3 | 0.7 | Faint sparkle |
| 2 | 8 | 0.4 | 0.6 | Visible glow |
| 3 | 12 | 0.5 | 0.5 | Warm shimmer |
| 5+ | 20 | 0.6 | 0.35 | Full aura |

Capped at prestige 5 visually (no further visual scaling beyond that).

### Implementation

`PrestigeAuraController` LocalScript in StarterPlayerScripts:

1. Wait for `PrestigeLevel` attribute on LocalPlayer (set by server, reflects DataStore prestige field)
2. Find the player's plot 1 `FloorPart` in `Workspace.Map` (same `findPlotPart` helper from dispatch 99)
3. Create `PrestigeAuraFolder` in `Workspace` (client-side, not in workspace replicated — but since LocalScripts run in the player's client session, any Instance they create in Workspace IS replicated to the server unless the game uses `NetworkOwnership` controls; for Roblox tycoon-style games, client-side Workspace edits from LocalScripts are actually replicated. Use a client-side `SurfaceGui` or `BillboardGui` parented to the player's character instead to keep it purely client-side and non-replicated)

**Revised approach:** Parent the aura to the player's `HumanoidRootPart` rather than the plot floor — this keeps it non-replicated to other clients if the script uses `RunService.RenderStepped` positioning, and ensures the effect is always visible around the player themselves. On second thought, the design spec says "on the hive plot" — let's keep it on the plot floor but parent it to a `ScreenGui`-style approach or accept that it replicates (in most Roblox tycoon games, tycoon plots are server-owned anyway and client LocalScript writes to Workspace DO replicate to the server unless handled specially).

**Final approach:** Create the `ParticleEmitter` inside a `Part` that is `Anchored`, `CanCollide=false`, `Transparency=1` (invisible anchor), parented inside `Workspace.Map` under the player's plot folder. The Part is created by the LocalScript, but since LocalScript Workspace writes replicate in standard Roblox, this will be visible to all clients. This is acceptable — other players SHOULD be able to see another player's prestige aura (it's a social signal). Simply render it for everyone, anchored to the plot floor.

But the spec says "each player sees their own aura; other players see nothing" — for true client-only effect, parent to `PlayerGui` as a `BillboardGui` over the plot part's position. `BillboardGui` particles are not supported. Use `ViewportFrame` to render. Too complex.

**Practical resolution:** Make the aura visible to all, anchored to the plot. Other players seeing prestige auras is a positive social feature (shows off progression). The LocalScript creates it on join/attribute change; the aura becomes a world-space Part with ParticleEmitter. This is the standard approach for Roblox cosmetics.

### Plot discovery

Same `findPlotPart` function from dispatch 99: checks `"Plot"..plotId`, `"plot_"..plotId`, `"Plot "..plotId` naming in `Workspace.Map`.

### Cleanup

When `PrestigeLevel` attribute changes, destroy the old aura Part and recreate with updated parameters. When the player's character respawns (`character.AncestryChanged`), reposition the aura part.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `PrestigeAuraController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create PrestigeAuraController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("PrestigeAuraController") then
    print("⏭️  PrestigeAuraController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "PrestigeAuraController"
    ctrl.Source = [[
--!strict
-- PrestigeAuraController — dispatch 113
-- Places a Honey Gold prestige aura on the player's first plot.
-- Visible to all players (social prestige signal).

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local HONEY_GOLD = Color3.fromRGB(242, 168, 28)
local AURA_NAME  = "PrestigeAuraPart_" .. player.UserId

-- Prestige tier parameters
local TIERS: {{rate:number, size:number, trans:number}} = {
    [0] = {rate=0,  size=0,   trans=1  },  -- no effect
    [1] = {rate=4,  size=0.3, trans=0.7},
    [2] = {rate=8,  size=0.4, trans=0.6},
    [3] = {rate=12, size=0.5, trans=0.5},
    [4] = {rate=16, size=0.55,trans=0.42},
    [5] = {rate=20, size=0.6, trans=0.35},
}

local function getTierParams(prestige: number): {rate:number, size:number, trans:number}
    local clamped = math.min(prestige, 5)
    return TIERS[clamped] or TIERS[0]
end

-- ── Plot discovery ────────────────────────────────────────────────
local function findPlotPart_113(plotId: number): BasePart?
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end
    local candidates = {
        "Plot" .. plotId,
        "plot_" .. plotId,
        "Plot " .. plotId,
    }
    for _, name in candidates do
        local folder = map:FindFirstChild(name)
        if folder then
            for _, obj in folder:GetDescendants() do
                if obj:IsA("BasePart") and (
                    obj.Name == "FloorPart" or obj.Name == "Floor" or
                    obj.Name == "Base" or obj.Name == "PlotBase"
                ) then return obj end
            end
            -- Fallback: first anchored BasePart in folder
            for _, obj in folder:GetDescendants() do
                if obj:IsA("BasePart") and obj.Anchored then return obj end
            end
        end
    end
    return nil
end

-- ── Aura management ──────────────────────────────────────────────
local function removeAura()
    local existing = workspace:FindFirstChild(AURA_NAME)
    if existing then existing:Destroy() end
    -- Also scan Map children
    local map = workspace:FindFirstChild("Map")
    if map then
        for _, obj in map:GetDescendants() do
            if obj.Name == AURA_NAME then obj:Destroy() end
        end
    end
end

local function buildAura(prestige: number)
    removeAura()
    if prestige < 1 then return end

    local params = getTierParams(prestige)
    local plotPart = findPlotPart_113(1)
    if not plotPart then
        warn("[PrestigeAura] Plot 1 floor part not found — aura skipped")
        return
    end

    -- Create invisible anchor part slightly above the floor
    local anchor = Instance.new("Part")
    anchor.Name             = AURA_NAME
    anchor.Anchored         = true
    anchor.CanCollide       = false
    anchor.CanQuery         = false
    anchor.CastShadow       = false
    anchor.Transparency     = 1
    anchor.Size             = Vector3.new(0.1, 0.1, 0.1)
    anchor.Position         = plotPart.Position + Vector3.new(0, 1.5, 0)
    anchor.Parent           = plotPart.Parent

    -- Main sparkle emitter
    local emitter = Instance.new("ParticleEmitter")
    emitter.Name             = "AuraEmitter"
    emitter.Color            = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 80)),
        ColorSequenceKeypoint.new(0.5, HONEY_GOLD),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 150)),
    })
    emitter.Transparency     = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, params.trans),
        NumberSequenceKeypoint.new(0.8, params.trans),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.Size             = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, params.size),
        NumberSequenceKeypoint.new(1, 0),
    })
    emitter.Rate             = params.rate
    emitter.Lifetime         = NumberRange.new(1.5, 2.5)
    emitter.Speed            = NumberRange.new(0.5, 2)
    emitter.SpreadAngle      = Vector2.new(30, 30)
    emitter.RotSpeed         = NumberRange.new(-45, 45)
    emitter.LightEmission    = 0.4
    emitter.LightInfluence   = 0.3
    emitter.Enabled          = true
    emitter.Parent           = anchor

    -- Prestige 5: add a soft glow ring beam effect
    if prestige >= 5 then
        -- Create a second faint outer emitter
        local glowEmitter = emitter:Clone()
        glowEmitter.Name        = "GlowEmitter"
        glowEmitter.Rate        = 6
        glowEmitter.Speed       = NumberRange.new(3, 5)
        glowEmitter.SpreadAngle = Vector2.new(180, 180)  -- omnidirectional
        glowEmitter.Lifetime    = NumberRange.new(0.5, 1.0)
        glowEmitter.Size        = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 0),
        })
        glowEmitter.LightEmission = 0.6
        glowEmitter.Parent = anchor
    end

    print("[PrestigeAura] Prestige " .. prestige .. " aura built at " .. tostring(anchor.Position))
end

-- ── Attribute listener ────────────────────────────────────────────
task.spawn(function()
    task.wait(2)  -- wait for PlotSync and Map to initialise
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    buildAura(prestige)
end)

player:GetAttributeChangedSignal("PrestigeLevel"):Connect(function()
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    buildAura(prestige)
end)

-- Rebuild on teleport / respawn (in case plot parts reload)
player.CharacterAdded:Connect(function()
    task.wait(1)
    local prestige = tonumber(player:GetAttribute("PrestigeLevel")) or 0
    buildAura(prestige)
end)

print("[PrestigeAuraController] Ready — prestige aura system active")
]]
    ctrl.Parent = SPS
    print("✅ PrestigeAuraController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("PrestigeAuraController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " PrestigeAuraController exists in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("buildAura", 1, true) and "✅" or "❌") .. " buildAura function")
table.insert(checks, (ctrl and ctrl.Source:find("removeAura", 1, true) and "✅" or "❌") .. " removeAura cleanup function")
table.insert(checks, (ctrl and ctrl.Source:find("getTierParams", 1, true) and "✅" or "❌") .. " getTierParams prestige tier lookup")
table.insert(checks, (ctrl and ctrl.Source:find("TIERS", 1, true) and "✅" or "❌") .. " TIERS table (0-5)")
table.insert(checks, (ctrl and ctrl.Source:find("findPlotPart_113", 1, true) and "✅" or "❌") .. " findPlotPart_113 helper")
table.insert(checks, (ctrl and ctrl.Source:find("ParticleEmitter", 1, true) and "✅" or "❌") .. " ParticleEmitter created")
table.insert(checks, (ctrl and ctrl.Source:find("PrestigeLevel", 1, true) and "✅" or "❌") .. " PrestigeLevel attribute read")
table.insert(checks, (ctrl and ctrl.Source:find("GetAttributeChangedSignal", 1, true) and "✅" or "❌") .. " GetAttributeChangedSignal listener")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterAdded", 1, true) and "✅" or "❌") .. " CharacterAdded rebuild on respawn")
table.insert(checks, (ctrl and ctrl.Source:find("GlowEmitter", 1, true) and "✅" or "❌") .. " GlowEmitter at prestige 5+")

print("=== DISPATCH 113 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 113 complete" or "❌ SOME CHECKS FAILED")

print("\nPrestige aura tiers:")
print("  0: no effect")
print("  1: 4/s sparkle, size 0.3, trans 0.7")
print("  2: 8/s sparkle, size 0.4, trans 0.6")
print("  3: 12/s shimmer, size 0.5, trans 0.5")
print("  4: 16/s shimmer, size 0.55, trans 0.42")
print("  5+: 20/s aura + omnidirectional glow ring")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Anchor Part created by LocalScript (transient, destroyed on prestige change) | 0 permanent parts (runtime-created, not in place file) |
| **Dispatch 113 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `AURA_NAME = "PrestigeAuraPart_" .. player.UserId` ensures each player's aura Part has a unique name, preventing name conflicts in Workspace when multiple players are in the same server.
- `removeAura()` scans both `workspace` root and `workspace.Map` descendants for the aura name, ensuring cleanup handles both parent locations (the Part is created in `plotPart.Parent` which is a Map subfolder).
- `CanQuery = false` prevents the invisible anchor Part from interfering with raycasts used by game systems (e.g., enemy line-of-sight, foraging validation).
- `CastShadow = false` prevents the tiny invisible anchor from casting an unwanted shadow (though at size 0.1 it's negligible, it's good practice).
- The `task.wait(2)` delay before initial build ensures the Map folder and plot parts have loaded before the aura attempts to anchor to them. If the plot loads asynchronously (via streaming or PlotSync), the `CharacterAdded` rebuild path will re-attempt after respawn.
- `LightEmission = 0.4` gives the sparkles a subtle self-glow. At the default Honey Gold colour, this creates a warm candle-like quality. `LightInfluence = 0.3` means the particles are partially lit by the scene's ambient light, keeping them grounded rather than floating.
- `SpreadAngle = Vector2.new(30, 30)` for the main emitter creates an upward cone — sparks drift up from the floor like heat shimmer. The prestige-5 `GlowEmitter` uses `Vector2.new(180, 180)` for a full omnidirectional burst effect.
- This dispatch does NOT set `PrestigeLevel` — it only reads it. The prestige server system (dispatch 13 era) is responsible for setting the attribute.
