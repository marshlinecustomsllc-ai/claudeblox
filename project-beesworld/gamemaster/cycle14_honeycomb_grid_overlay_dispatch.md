# Dispatch 103 — Honeycomb Grid Visual Overlay
## Cycle 14 · A Bee's World

**Feature:** The hex plot grid (established in dispatch 1 architecture) is defined by server-side plot data, but the player sees flat colour-coded plots with no visual connection between them. This dispatch adds a **Honeycomb Grid Overlay** — a LocalScript that draws thin `Beam` lines between adjacent plots when the player opens the map view or presses a shortcut, giving the hex grid a literal honeycomb wireframe appearance. Beams are drawn in Honey Gold with slight transparency, creating a subtle "hive structure" visual that reinforces the bee-scale theme. The overlay is toggled on/off with a persistent `BeehiveOverlayEnabled` attribute on the player.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 102 (Hive Efficiency Rating)

---

## DESIGN

### Beam approach

Each beam connects two adjacent plot `FloorPart` centres. Adjacency is defined as: two plots whose centre positions are within `MAX_ADJ_DIST = 22` studs (based on a 16-stud hex cell with ~4-stud gap between cells). The script computes distances between all plot pairs and draws a beam for pairs within `MAX_ADJ_DIST`.

Beams:
- `Color = ColorSequence.new(Color3.fromRGB(242, 168, 28))` — Honey Gold
- `Transparency = NumberSequence.new(0.6)` — subtle, not overwhelming
- `Width0 = Width1 = 0.08` — very thin wireframe line
- `FaceCamera = false` — world-space beam
- Parent: a folder `Workspace.HoneycombOverlay` (created fresh each toggle-on, destroyed on toggle-off)

### Attachment strategy

For each beam, two `Attachment` objects are created on the respective `FloorPart`s (or placed in workspace if FloorPart not available). Attachments are named `HCOverlay_A0` and `HCOverlay_A1` and are destroyed with the `HoneycombOverlay` folder.

### Toggle logic

```lua
local function toggleOverlay(enabled: boolean)
    -- Destroy existing overlay
    local existing = workspace:FindFirstChild("HoneycombOverlay")
    if existing then existing:Destroy() end
    if not enabled then return end
    -- Build overlay
    buildHoneycombOverlay()
end
```

Wired to:
1. A proximity prompt or GUI button (if a map-toggle button exists)
2. `UserInputService.InputBegan` for keyboard shortcut key `H` (for Hive)
3. Initial state: disabled (overlay off until player activates)

The enabled state persists via `player:SetAttribute("BeehiveOverlayEnabled", enabled)`.

### Plot discovery

Plots are found via `Workspace.Map` folder — same pattern as `findPlotPart()` in dispatch 99's foraging animation:
- Check `Map:GetChildren()` for folders named `Plot1`…`Plot8`, `plot_1`…`plot_8`, or containing "Plot" in their name
- For each plot folder, find its FloorPart (or any anchored BasePart)

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HoneycombOverlayController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HoneycombOverlayController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HoneycombOverlayController") then
    print("⏭️  HoneycombOverlayController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HoneycombOverlayController"
    ctrl.Source = [[
--!strict
-- HoneycombOverlayController — dispatch 103
-- Draws Honey Gold beam lines between adjacent hex plot cells on demand.
-- Toggle with H key or via BeehiveOverlayEnabled player attribute.

local Players       = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")

local player = Players.LocalPlayer

local MAX_ADJ_DIST  = 22   -- studs; two hex plots within this range are adjacent
local BEAM_COLOR    = Color3.fromRGB(242, 168, 28)  -- Honey Gold
local BEAM_TRANS    = 0.6
local BEAM_WIDTH    = 0.08

-- ── Plot discovery ────────────────────────────────────────────────
local function findAllPlotParts(): {BasePart}
    local parts: {BasePart} = {}
    local map = workspace:FindFirstChild("Map")
    if not map then return parts end
    for _, child in map:GetChildren() do
        if child:IsA("Folder") or child:IsA("Model") then
            -- FloorPart first
            for _, obj in child:GetDescendants() do
                if obj:IsA("BasePart") and (
                    obj.Name == "FloorPart" or obj.Name == "Floor" or
                    obj.Name == "Base" or obj.Name == "PlotBase"
                ) then
                    table.insert(parts, obj)
                    break
                end
            end
            -- Fallback: first anchored BasePart
            if #parts == 0 or parts[#parts].Parent.Parent ~= map then
                -- Check if we actually got a part for this child
                local found = false
                for _, p in parts do
                    if p:IsAncestorOf(child) or p.Parent == child or p.Parent.Parent == child then
                        found = true; break
                    end
                end
                if not found then
                    for _, obj in child:GetDescendants() do
                        if obj:IsA("BasePart") and obj.Anchored then
                            table.insert(parts, obj)
                            break
                        end
                    end
                end
            end
        end
    end
    return parts
end

-- ── Overlay build / destroy ───────────────────────────────────────
local overlayFolder: Folder? = nil

local function buildOverlay()
    if overlayFolder then overlayFolder:Destroy() end
    overlayFolder = Instance.new("Folder")
    overlayFolder.Name = "HoneycombOverlay"
    overlayFolder.Parent = workspace

    local plotParts = findAllPlotParts()
    local beamCount = 0

    for i = 1, #plotParts do
        for j = i + 1, #plotParts do
            local pa = plotParts[i]
            local pb = plotParts[j]
            local dist = (pa.Position - pb.Position).Magnitude
            if dist <= MAX_ADJ_DIST then
                -- Create attachments
                local a0 = Instance.new("Attachment")
                a0.Name = "HCOverlay_A0"
                a0.WorldPosition = pa.Position + Vector3.new(0, 0.2, 0)
                a0.Parent = overlayFolder

                local a1 = Instance.new("Attachment")
                a1.Name = "HCOverlay_A1"
                a1.WorldPosition = pb.Position + Vector3.new(0, 0.2, 0)
                a1.Parent = overlayFolder

                local beam = Instance.new("Beam")
                beam.Name          = "HCBeam"
                beam.Attachment0   = a0
                beam.Attachment1   = a1
                beam.Color         = ColorSequence.new(BEAM_COLOR)
                beam.Transparency  = NumberSequence.new(BEAM_TRANS)
                beam.Width0        = BEAM_WIDTH
                beam.Width1        = BEAM_WIDTH
                beam.FaceCamera    = false
                beam.Segments      = 2
                beam.LightEmission = 0.3
                beam.Parent        = overlayFolder
                beamCount = beamCount + 1
            end
        end
    end

    print("[HoneycombOverlay] " .. beamCount .. " beams drawn across " .. #plotParts .. " plots")
end

local function destroyOverlay()
    if overlayFolder then
        overlayFolder:Destroy()
        overlayFolder = nil
    end
end

local function setOverlay(enabled: boolean)
    player:SetAttribute("BeehiveOverlayEnabled", enabled)
    if enabled then
        buildOverlay()
    else
        destroyOverlay()
    end
end

local function toggleOverlay()
    local current = player:GetAttribute("BeehiveOverlayEnabled") == true
    setOverlay(not current)
end

-- ── Input binding (H key) ─────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H then
        toggleOverlay()
    end
end)

-- ── PlotSync listener — rebuild overlay when plot ownership changes ─
task.spawn(function()
    local RS = game:GetService("ReplicatedStorage")
    local plotSync = RS:WaitForChild("PlotSync", 10) :: RemoteEvent?
    if plotSync then
        plotSync.OnClientEvent:Connect(function(_data: {[string]: any})
            -- If overlay is active, rebuild to include new plot
            if player:GetAttribute("BeehiveOverlayEnabled") == true then
                task.wait(0.5)  -- brief wait for plot to finish spawning
                buildOverlay()
            end
        end)
    end
end)

-- ── Attribute change listener — for external toggle support ────────
player:GetAttributeChangedSignal("BeehiveOverlayEnabled"):Connect(function()
    local enabled = player:GetAttribute("BeehiveOverlayEnabled") == true
    if enabled and not overlayFolder then
        buildOverlay()
    elseif not enabled and overlayFolder then
        destroyOverlay()
    end
end)

print("[HoneycombOverlay] Ready — press H to toggle honeycomb grid overlay")
]]

    ctrl.Parent = SPS
    print("✅ HoneycombOverlayController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HoneycombOverlayController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HoneycombOverlayController exists")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("buildOverlay", 1, true) and "✅" or "❌") .. " buildOverlay function")
table.insert(checks, (ctrl and ctrl.Source:find("destroyOverlay", 1, true) and "✅" or "❌") .. " destroyOverlay function")
table.insert(checks, (ctrl and ctrl.Source:find("HoneycombOverlay", 1, true) and "✅" or "❌") .. " HoneycombOverlay folder")
table.insert(checks, (ctrl and ctrl.Source:find("MAX_ADJ_DIST", 1, true) and "✅" or "❌") .. " MAX_ADJ_DIST adjacency constant")
table.insert(checks, (ctrl and ctrl.Source:find("Enum%.KeyCode%.H", 1, false) and "✅" or "❌") .. " H key binding")
table.insert(checks, (ctrl and ctrl.Source:find("BeehiveOverlayEnabled", 1, true) and "✅" or "❌") .. " BeehiveOverlayEnabled attribute")
table.insert(checks, (ctrl and ctrl.Source:find("Instance%.new%(\"Beam\"", 1, true) and "✅" or "❌") .. " Beam creation")
table.insert(checks, (ctrl and ctrl.Source:find("Attachment", 1, true) and "✅" or "❌") .. " Attachment creation")
table.insert(checks, (ctrl and ctrl.Source:find("PlotSync", 1, true) and "✅" or "❌") .. " PlotSync listener for rebuild")

print("=== DISPATCH 103 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 103 complete" or "❌ SOME CHECKS FAILED")

print("\nHoneycomb overlay parameters:")
print("  MAX_ADJ_DIST: 22 studs")
print("  BEAM_COLOR:   Honey Gold (242,168,28)")
print("  BEAM_TRANS:   0.6 (subtle)")
print("  BEAM_WIDTH:   0.08 studs (wireframe thin)")
print("  Toggle:       H key or BeehiveOverlayEnabled player attribute")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| LocalScript only — Attachments and Beams are transient (destroyed on toggle-off) | 0 permanent parts |
| **Dispatch 103 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- Beams and Attachments created during overlay-on are parented to `Workspace.HoneycombOverlay` folder. Destroying the folder destroys all beams and attachments atomically — no memory leak.
- `MAX_ADJ_DIST = 22` studs is calibrated for a 16-stud hex cell (radius ~9 studs) with ~4-stud gaps. If the actual plot grid uses different spacing, increase to `30` for sparser grids or decrease to `18` for tighter ones. Run the verification sweep and watch the beam count — 7 beams for 8 plots is the maximum for a hex ring.
- `LightEmission = 0.3` gives beams a subtle glow, making them visible even in low-light areas of the hive map without being blinding.
- `Segments = 2` is the minimum for a straight beam. Higher segment counts curve the beam unnecessarily for short connections.
- The `GetAttributeChangedSignal("BeehiveOverlayEnabled")` listener allows other systems (a future map UI button) to toggle the overlay by setting the attribute rather than calling a function directly. This decouples the toggle source from the controller.
- The PlotSync rebuild handler waits 0.5s before rebuilding — this gives the plot folder time to finish spawning its parts before `findAllPlotParts()` scans for them.
- If `Workspace.Map` does not exist (map not yet loaded), `findAllPlotParts()` returns an empty table and `buildOverlay()` creates a folder with 0 beams — a no-op, not an error. The overlay can be re-toggled once the map loads.
- The `found` check in `findAllPlotParts()` is defensive — in practice each plot folder contains exactly one FloorPart-type part, so the break after finding it prevents duplicates.
