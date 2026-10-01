# Dispatch 99 — Foraging Return Animation
## Cycle 14 · A Bee's World

**Feature:** When bees return from a foraging trip (ForagingSync fires with yields), there is no visual "pop" to reward the player. This dispatch adds a yield pop animation: each resource yield (honey, propolis, pollen) that is non-zero spawns a floating `+N 🍯` label that rises from the plot position and fades out over 1.5 seconds. Multiple plots returning simultaneously each get their own pop. This is a pure client-side cosmetic layer — no server changes.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 98 (Plot Unlock Notification)

---

## DESIGN

### ForagingSync payload

`ForagingSync` (early dispatch) fires to the client with data containing the yields for a trip. The payload shape is likely `{plotId, honeyYield, propolisYield, pollenYield}` or similar. The `ForagingController` (or `BeeParticleController`) processes this. This dispatch appends a yield pop handler.

### Yield pop mechanics

For each returning trip:
1. Find the plot's world position from `Workspace.Map` or `PlotController`'s plot reference
2. For each non-zero yield, create a `BillboardGui` in `Workspace` (not `PlayerGui`) anchored to the plot centre + a slight Y offset
3. Tween the BillboardGui upward by 4 studs over 1.5 seconds
4. Tween TextLabel TextTransparency from 0 → 1 over 1.5 seconds
5. Destroy on completion

### Billboard placement

`BillboardGui` with `Adornee` set to the plot's `BasePart` (the FloorPart of the plot). `StudsOffset = Vector3.new(0, 3, 0)` lifts the label above the plot. `Size = UDim2.new(0, 120, 0, 28)`.

If multiple yields per trip (honey + propolis + pollen), stack them vertically with `StudsOffset.Y` incremented by 1.5 per label.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `ForagingController` | Append yield pop handler bound to ForagingSync |

---

## STEP A — Diagnose ForagingController / ForagingSync payload

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local fc = nil
for _, obj in SPS:GetDescendants() do
    if obj:IsA("LuaSourceContainer") and obj.Name:find("Foraging") then
        print("Found: " .. obj:GetFullName())
        fc = obj
    end
end
if not fc then
    print("ForagingController not found in StarterPlayerScripts — checking StarterGui")
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name:find("Foraging") then
            print("Found in StarterGui: " .. obj:GetFullName())
        end
    end
end

local RS = game:GetService("ReplicatedStorage")
local fs = RS:FindFirstChild("ForagingSync")
print("ForagingSync: " .. (fs and fs.ClassName or "NOT FOUND"))
```

---

## STEP B — ForagingController: inject yield pop

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local fc = SPS and SPS:FindFirstChild("ForagingController")
if not fc then
    -- Check StarterGui
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingController" then
            fc = obj; break
        end
    end
end
assert(fc, "ForagingController not found")

if fc.Source:find("YieldPop", 1, true) then
    print("⏭️  ForagingController already has YieldPop — skip")
else
    local clone = fc:Clone()
    clone.Name = "ForagingController_WORKING"

    clone.Source = clone.Source .. [[

-- ── Yield Pop Animation (dispatch 99) ───────────────────────────
local TweenService_99 = game:GetService("TweenService")
local Players_99      = game:GetService("Players")
local RS_99           = game:GetService("ReplicatedStorage")

local RESOURCE_FORMAT = {
    honey    = {emoji = "🍯", color = Color3.fromRGB(242, 168, 28)},
    propolis = {emoji = "🔮", color = Color3.fromRGB(180, 120, 220)},
    pollen   = {emoji = "🌼", color = Color3.fromRGB(200, 220, 60)},
}

local function spawnYieldPop(adornee: BasePart, text: string, color: Color3, stackIndex: number)
    local bb = Instance.new("BillboardGui")
    bb.Name        = "YieldPop"
    bb.Adornee     = adornee
    bb.Size        = UDim2.new(0, 130, 0, 28)
    bb.StudsOffset = Vector3.new(0, 3 + stackIndex * 1.6, 0)
    bb.AlwaysOnTop = false
    bb.Parent      = workspace

    local label = Instance.new("TextLabel")
    label.Name                  = "YieldLabel"
    label.Size                  = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font                  = Enum.Font.GothamBold
    label.TextSize              = 15
    label.TextColor3            = color
    label.TextStrokeColor3      = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0.5
    label.Text                  = text
    label.TextXAlignment        = Enum.TextXAlignment.Center
    label.Parent                = bb

    -- Rise and fade
    local duration = 1.5
    local twInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService_99:Create(bb, twInfo, {StudsOffset = Vector3.new(0, 3 + stackIndex * 1.6 + 4, 0)}):Play()
    TweenService_99:Create(label, twInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    game:GetService("Debris"):AddItem(bb, duration + 0.1)
end

local function findPlotPart(plotId: number): BasePart?
    local map = workspace:FindFirstChild("Map")
    if not map then return nil end
    -- Plot folders are named "Plot1", "Plot2", etc.
    local plotFolder = map:FindFirstChild("Plot" .. plotId)
        or map:FindFirstChild("plot_" .. plotId)
        or map:FindFirstChild("Plot " .. plotId)
    if not plotFolder then return nil end
    -- Return the first BasePart (floor or centre part)
    for _, obj in plotFolder:GetDescendants() do
        if obj:IsA("BasePart") and (obj.Name == "FloorPart" or obj.Name == "Floor" or obj.Name == "Base" or obj.Name == "PlotBase") then
            return obj
        end
    end
    -- Fallback: return any anchored BasePart in the folder
    for _, obj in plotFolder:GetDescendants() do
        if obj:IsA("BasePart") and obj.Anchored then return obj end
    end
    return nil
end

-- Bind to ForagingSync
task.spawn(function()
    local foragingSync = RS_99:WaitForChild("ForagingSync", 10) :: RemoteEvent?
    if not foragingSync then
        warn("[YieldPop] ForagingSync not found after 10s")
        return
    end

    foragingSync.OnClientEvent:Connect(function(data: {plotId: number?, honeyYield: number?, propolisYield: number?, pollenYield: number?})
        if not data or not data.plotId then return end

        local adornee = findPlotPart(data.plotId)
        if not adornee then return end

        local stackIdx = 0
        local yields = {
            {key = "honey",    amount = data.honeyYield    or 0},
            {key = "propolis", amount = data.propolisYield or 0},
            {key = "pollen",   amount = data.pollenYield   or 0},
        }
        for _, y in yields do
            if y.amount > 0 then
                local fmt = RESOURCE_FORMAT[y.key]
                local text = "+" .. y.amount .. " " .. fmt.emoji
                spawnYieldPop(adornee, text, fmt.color, stackIdx)
                stackIdx = stackIdx + 1
            end
        end
    end)

    print("[YieldPop] Foraging yield pop animation active")
end)
]]

    local parent = fc.Parent
    fc.Name = "ForagingController_OLD_NX"
    fc.Parent = nil
    clone.Name = "ForagingController"
    clone.Parent = parent
    print("✅ ForagingController: yield pop animation injected")
end
```

---

## STEP C — Verification sweep

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local fc = SPS and SPS:FindFirstChild("ForagingController")
if not fc then
    local SG = game:GetService("StarterGui")
    for _, obj in SG:GetDescendants() do
        if obj:IsA("LuaSourceContainer") and obj.Name == "ForagingController" then
            fc = obj; break
        end
    end
end

local checks = {}
table.insert(checks, (fc and "✅" or "❌") .. " ForagingController exists")
table.insert(checks, (fc and fc.Source:find("YieldPop", 1, true) and "✅" or "❌") .. " ForagingController: YieldPop function")
table.insert(checks, (fc and fc.Source:find("spawnYieldPop", 1, true) and "✅" or "❌") .. " ForagingController: spawnYieldPop")
table.insert(checks, (fc and fc.Source:find("BillboardGui", 1, true) and "✅" or "❌") .. " ForagingController: BillboardGui creation")
table.insert(checks, (fc and fc.Source:find("ForagingSync", 1, true) and "✅" or "❌") .. " ForagingController: ForagingSync bound")
table.insert(checks, (fc and fc.Source:find("findPlotPart", 1, true) and "✅" or "❌") .. " ForagingController: findPlotPart lookup")
table.insert(checks, (fc and fc.Source:find("Debris", 1, true) and "✅" or "❌") .. " ForagingController: Debris cleanup used")

print("=== DISPATCH 99 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 99 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI injection only — BillboardGuis are transient (auto-destroyed by Debris) | 0 permanent parts |
| **Dispatch 99 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `game:GetService("Debris"):AddItem(bb, duration + 0.1)` ensures the BillboardGui is cleaned up even if the tween completes before the task can call `:Destroy()` — this is the safest cleanup pattern for transient world-space UI.
- `AlwaysOnTop = false` lets the billboard pop be occluded by world geometry. This looks more natural (the text appears to rise from the ground, not float through walls). For a game where plots might be behind obstructions, setting `AlwaysOnTop = true` would ensure visibility — designer preference.
- `stackIndex * 1.6` vertical offset between simultaneous yields prevents text overlap when all three resources pop at once (honey at Y=3, propolis at Y=4.6, pollen at Y=6.2).
- `TextStrokeTransparency = 0.5` gives the text a subtle dark outline, making it readable against both light and dark plot backgrounds.
- The `findPlotPart` function tries multiple naming conventions (`Plot1`, `plot_1`, `Plot 1`) and falls back to any anchored BasePart in the folder. If the plot folder naming differs from these patterns, add the actual convention as a new branch.
- ForagingSync payload shape assumed: `{plotId, honeyYield, propolisYield, pollenYield}`. If the actual payload differs (e.g. `{id, yields={honey, propolis, pollen}}`), update the destructuring in the `OnClientEvent` handler.
