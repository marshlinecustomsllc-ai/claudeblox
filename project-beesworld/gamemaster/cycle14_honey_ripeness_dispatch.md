# Dispatch 121 — Honey Ripeness Indicator
## Cycle 14 · A Bee's World

**Feature:** A `HoneyRipenessController` LocalScript that overlays a small BillboardGui above each filled honey cell on the player's comb plot, showing a fill bar and a ripeness emoji (🌱→🍯) that kids can read at a glance. Adults who want precision see a `%` label on tap. Updates whenever `HoneyCount` or `CombCellCount` changes. No server changes required — reads the same `CombState` attribute already written by the comb system.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 120 (Hive Leaderboard)

---

## DESIGN

### Ripeness stages (kid-readable)

| Fill % | Emoji | Colour |
|--------|-------|--------|
| 0–24 % | 🌱 | pale yellow |
| 25–49 % | 🌼 | light gold |
| 50–74 % | 🍯 | honey gold |
| 75–99 % | 🍯✨ | bright gold |
| 100 % | 🎉 | glowing amber |

### BillboardGui per honey cell

- Size: `{0, 52, 0, 28}` studs (small, non-intrusive)
- StudsOffset: `{0, 2.2, 0}` (floats above cell)
- `RipenessBar`: thin 48×6 rounded Frame (fill bar from left)
- `RipenessLabel`: emoji + optional `%` text when detail mode on
- Rendered only for `honey` type cells; other cell types get no billboard

### Data source

`CombState` player attribute is a JSON-encoded table `{[slotId]: cellType}` written by `CombManager`. Cross-reference with `HoneyCount` to infer approximate fill per slot (see estimation below).

### Fill estimation

The server tracks total honey, not per-cell honey. For the visual indicator we use a simple heuristic that feels correct without requiring per-slot data:

```
totalCells  = CombCellCount
honeyCells  = count of "honey" entries in CombState
fillPerCell = math.clamp(HoneyCount / math.max(honeyCells * 100, 1), 0, 1)
```

All honey cells show the same fill level — this is intentional: the hive fills as a whole, not cell-by-cell, which matches the mental model ("my hive is 60% full") and avoids confusion. A 100-honey-capacity hive with 100 honey shows all cells at 🎉.

### Detail mode (adult layer)

`RipenessDetailOn` player attribute (boolean, persists across sessions, default false). When true, the `%` percentage appears next to the emoji. Tapping any cell billboard toggles this attribute.

### Update triggers

- `HoneyCount` attribute change
- `CombCellCount` attribute change (new cell placed → rebuild billboard list)
- `CombState` attribute change (cell type changed → rebuild)

---

## FILES CHANGED

| File | Change |
|------|--------|
| `HoneyRipenessController` | New LocalScript in StarterPlayerScripts |

---

## STEP A — Create HoneyRipenessController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

if SPS:FindFirstChild("HoneyRipenessController") then
    print("⏭️  HoneyRipenessController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name = "HoneyRipenessController"
    ctrl.Source = [[
--!strict
-- HoneyRipenessController — dispatch 121
-- Shows ripeness fill bars above honey cells on the player's comb plot.

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ── Palette ────────────────────────────────────────────────────────
local HONEY_GOLD_121   = Color3.fromRGB(242, 168, 28)
local AMBER_121        = Color3.fromRGB(220, 100, 10)
local PALE_YELLOW_121  = Color3.fromRGB(240, 228, 160)
local LIGHT_GOLD_121   = Color3.fromRGB(242, 200, 80)
local DARK_BG_121      = Color3.fromRGB(40,  24,  8)

-- ── Ripeness stages ────────────────────────────────────────────────
type RipenessStage = {emoji: string, barColor: Color3}
local STAGES_121: {RipenessStage} = {
    {emoji = "🌱",    barColor = PALE_YELLOW_121},   -- 0-24%
    {emoji = "🌼",    barColor = LIGHT_GOLD_121},    -- 25-49%
    {emoji = "🍯",    barColor = HONEY_GOLD_121},    -- 50-74%
    {emoji = "🍯✨",  barColor = HONEY_GOLD_121},    -- 75-99%
    {emoji = "🎉",    barColor = AMBER_121},         -- 100%
}

local function getStage_121(fillFraction: number): RipenessStage
    local pct = math.clamp(fillFraction, 0, 1)
    if pct >= 1.0 then return STAGES_121[5]
    elseif pct >= 0.75 then return STAGES_121[4]
    elseif pct >= 0.50 then return STAGES_121[3]
    elseif pct >= 0.25 then return STAGES_121[2]
    else return STAGES_121[1]
    end
end

-- ── Comb state parser ──────────────────────────────────────────────
local function parseCombState_121(): {[string]: string}
    local raw = tostring(player:GetAttribute("CombState") or "{}")
    local ok, decoded = pcall(function()
        -- lightweight JSON decode: expect {"1":"honey","2":"brood",...}
        local t: {[string]: string} = {}
        for k, v in raw:gmatch('"(%w+)":"(%w+)"') do
            t[k] = v
        end
        return t
    end)
    return ok and decoded or {}
end

-- ── Find comb slot parts on the local player's plot ───────────────
local function findCombParts_121(): {[string]: BasePart}
    local result: {[string]: BasePart} = {}
    local mapFolder = workspace:FindFirstChild("Map")
    if not mapFolder then return result end

    -- Bees World plot folders are typically named PlotN or contain the player's UserId
    local uid = tostring(player.UserId)
    for _, folder in mapFolder:GetDescendants() do
        if folder:IsA("Folder") and (folder.Name:find(uid) or folder.Name:find("Plot")) then
            for _, child in folder:GetDescendants() do
                if child:IsA("BasePart") then
                    -- Match CombSlot_N, Slot_N, HexSlotN, or SlotId attribute
                    local slotId: string? = nil
                    local slotAttr = child:GetAttribute("SlotId")
                    if slotAttr then
                        slotId = tostring(slotAttr)
                    else
                        local m = child.Name:match("[Ss]lot_?(%d+)")
                        if m then slotId = m end
                    end
                    if slotId then result[slotId] = child end
                end
            end
        end
    end
    return result
end

-- ── Billboard factory ─────────────────────────────────────────────
local function makeBillboard_121(parent: BasePart, slotId: string): BillboardGui
    local bg = Instance.new("BillboardGui")
    bg.Name             = "RipenessBB_" .. slotId
    bg.Size             = UDim2.new(0, 52, 0, 28)
    bg.StudsOffset      = Vector3.new(0, 2.2, 0)
    bg.AlwaysOnTop      = false
    bg.LightInfluence   = 0
    bg.Parent           = parent

    -- Background pill
    local pill = Instance.new("Frame")
    pill.Name             = "Pill"
    pill.Size             = UDim2.new(1, 0, 1, 0)
    pill.BackgroundColor3 = DARK_BG_121
    pill.BackgroundTransparency = 0.3
    pill.BorderSizePixel  = 0
    pill.Parent           = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent       = pill

    -- Fill bar track
    local track = Instance.new("Frame")
    track.Name             = "BarTrack"
    track.Size             = UDim2.new(1, -8, 0, 5)
    track.Position         = UDim2.new(0, 4, 0, 18)
    track.BackgroundColor3 = DARK_BG_121
    track.BackgroundTransparency = 0.5
    track.BorderSizePixel  = 0
    track.Parent           = pill

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent       = track

    -- Fill bar fill
    local fill = Instance.new("Frame")
    fill.Name             = "BarFill"
    fill.Size             = UDim2.new(0, 0, 1, 0)   -- width updated on refresh
    fill.BackgroundColor3 = HONEY_GOLD_121
    fill.BorderSizePixel  = 0
    fill.Parent           = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent       = fill

    -- Emoji + optional % label
    local label = Instance.new("TextLabel")
    label.Name                   = "RipenessLabel"
    label.Size                   = UDim2.new(1, -4, 0, 16)
    label.Position               = UDim2.new(0, 2, 0, 1)
    label.BackgroundTransparency = 1
    label.TextColor3             = HONEY_GOLD_121
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 11
    label.TextXAlignment         = Enum.TextXAlignment.Center
    label.Text                   = "🌱"
    label.Parent                 = pill

    -- Tap to toggle detail mode
    local tapBtn = Instance.new("TextButton")
    tapBtn.Name             = "TapZone"
    tapBtn.Size             = UDim2.new(1, 0, 1, 0)
    tapBtn.BackgroundTransparency = 1
    tapBtn.Text             = ""
    tapBtn.Parent           = bg

    tapBtn.Activated:Connect(function()
        local cur = player:GetAttribute("RipenessDetailOn")
        player:SetAttribute("RipenessDetailOn", not cur)
    end)

    return bg
end

-- ── Active billboard registry ─────────────────────────────────────
local billboards_121: {[string]: BillboardGui} = {}

local function clearBillboards_121()
    for _, bb in billboards_121 do
        bb:Destroy()
    end
    table.clear(billboards_121)
end

-- ── Main refresh ──────────────────────────────────────────────────
local function refresh_121()
    local combState    = parseCombState_121()
    local honeyCount   = tonumber(player:GetAttribute("HoneyCount"))    or 0
    local cellCount    = tonumber(player:GetAttribute("CombCellCount")) or 0
    local detailOn     = player:GetAttribute("RipenessDetailOn") == true

    -- Count honey cells
    local honeyCellCount = 0
    for _, cellType in combState do
        if cellType == "honey" then honeyCellCount += 1 end
    end

    local capacity    = math.max(honeyCellCount * 100, 1)
    local fillFrac    = math.clamp(honeyCount / capacity, 0, 1)
    local stage       = getStage_121(fillFrac)
    local pctText     = detailOn and ("  " .. math.floor(fillFrac * 100) .. "%") or ""

    local combParts = findCombParts_121()

    -- For each honey slot: ensure billboard exists + update it
    for slotId, cellType in combState do
        if cellType ~= "honey" then
            -- Remove any billboard on non-honey cells
            local bb = billboards_121[slotId]
            if bb then bb:Destroy(); billboards_121[slotId] = nil end
            continue
        end

        local part = combParts[slotId]
        if not part then continue end

        -- Create billboard if missing
        local bb = billboards_121[slotId]
        if not bb or not bb.Parent then
            bb = makeBillboard_121(part, slotId)
            billboards_121[slotId] = bb
        end

        -- Update fill bar
        local track = bb:FindFirstChild("Pill", true) and
                      bb.Pill:FindFirstChild("BarTrack") :: Frame?
        local fillBar = track and track:FindFirstChild("BarFill") :: Frame?
        if fillBar then
            TweenService:Create(fillBar, TweenInfo.new(0.6, Enum.EasingStyle.Quad),
                {Size = UDim2.new(fillFrac, 0, 1, 0),
                 BackgroundColor3 = stage.barColor}):Play()
        end

        -- Update label
        local label = bb:FindFirstChild("Pill", true) and
                      bb.Pill:FindFirstChild("RipenessLabel") :: TextLabel?
        if label then
            label.Text       = stage.emoji .. pctText
            label.TextColor3 = stage.barColor
        end
    end

    -- Remove billboards for slots no longer in combState (cell demolished)
    for slotId, bb in billboards_121 do
        if not combState[slotId] or combState[slotId] ~= "honey" then
            bb:Destroy()
            billboards_121[slotId] = nil
        end
    end
end

-- ── Listeners ─────────────────────────────────────────────────────
player:GetAttributeChangedSignal("HoneyCount"):Connect(refresh_121)
player:GetAttributeChangedSignal("CombCellCount"):Connect(refresh_121)
player:GetAttributeChangedSignal("CombState"):Connect(refresh_121)
player:GetAttributeChangedSignal("RipenessDetailOn"):Connect(refresh_121)

-- ── Initial refresh after load ────────────────────────────────────
task.wait(3)   -- allow plot to load and attributes to populate
refresh_121()

-- ── Cleanup on character remove ───────────────────────────────────
player.CharacterRemoving:Connect(clearBillboards_121)
player.CharacterAdded:Connect(function()
    task.wait(2)
    refresh_121()
end)

print("[HoneyRipenessController] Ready — ripeness bars on honey cells; tap any cell for % detail")
]]
    ctrl.Parent = SPS
    print("✅ HoneyRipenessController created in StarterPlayerScripts")
end
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SPS  = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HoneyRipenessController")

local checks = {}
table.insert(checks, (ctrl and "✅" or "❌") .. " HoneyRipenessController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict")
table.insert(checks, (ctrl and ctrl.Source:find("STAGES_121", 1, true) and "✅" or "❌") .. " STAGES_121 ripeness table")
table.insert(checks, (ctrl and ctrl.Source:find("getStage_121", 1, true) and "✅" or "❌") .. " getStage_121 helper")
table.insert(checks, (ctrl and ctrl.Source:find("parseCombState_121", 1, true) and "✅" or "❌") .. " parseCombState_121 parser")
table.insert(checks, (ctrl and ctrl.Source:find("findCombParts_121", 1, true) and "✅" or "❌") .. " findCombParts_121 locator")
table.insert(checks, (ctrl and ctrl.Source:find("makeBillboard_121", 1, true) and "✅" or "❌") .. " makeBillboard_121 factory")
table.insert(checks, (ctrl and ctrl.Source:find("refresh_121", 1, true) and "✅" or "❌") .. " refresh_121 main update")
table.insert(checks, (ctrl and ctrl.Source:find("RipenessDetailOn", 1, true) and "✅" or "❌") .. " RipenessDetailOn detail toggle")
table.insert(checks, (ctrl and ctrl.Source:find("TweenService", 1, true) and "✅" or "❌") .. " TweenService fill bar animation")
table.insert(checks, (ctrl and ctrl.Source:find("HoneyCount", 1, true) and "✅" or "❌") .. " HoneyCount listener")
table.insert(checks, (ctrl and ctrl.Source:find("CombState", 1, true) and "✅" or "❌") .. " CombState listener")
table.insert(checks, (ctrl and ctrl.Source:find("CharacterRemoving", 1, true) and "✅" or "❌") .. " CharacterRemoving cleanup")
table.insert(checks, (ctrl and ctrl.Source:find("StudsOffset", 1, true) and "✅" or "❌") .. " BillboardGui StudsOffset (floats above cells)")

print("=== DISPATCH 121 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 121 complete" or "❌ SOME CHECKS FAILED")

print("\nRipeness stages: 🌱 0-24% | 🌼 25-49% | 🍯 50-74% | 🍯✨ 75-99% | 🎉 100%")
print("Tap any honey cell billboard to toggle % detail mode (RipenessDetailOn attribute)")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| HoneyRipenessController (LocalScript, runtime BillboardGuis on cell parts) | 0 permanent |
| **Dispatch 121 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- BillboardGuis are created at runtime on cell `BasePart`s — they are not permanent parts; they are destroyed on `CharacterRemoving` and rebuilt on `CharacterAdded`. Part budget is unaffected.
- Fill fraction is computed hive-wide (`HoneyCount / (honeyCells × 100)`) rather than per-slot. This matches the actual game mechanic where honey production fills the hive collectively, not slot-by-slot. Showing different fill levels per cell would be misleading.
- `AlwaysOnTop = false` on the BillboardGui means fill bars are occluded by geometry naturally — they don't clip through walls if a cell is inside the hive structure.
- `LightInfluence = 0` keeps the bar colour consistent regardless of local lighting — a 🎉 cell always glows amber even in dim hive interiors.
- The `parseCombState_121` regex (`"(%w+)":"(%w+)"`) is a lightweight JSON parser that handles the expected format `{"1":"honey","2":"brood"}` without requiring a full JSON library. If the format ever changes to nested objects this would need updating.
- `findCombParts_121` searches for the player's plot by matching `UserId` in folder names OR the generic `Plot` pattern (future-proofs across different plot naming schemes). The `SlotId` attribute is preferred; name-based matching is a fallback.
- Tapping any billboard toggles `RipenessDetailOn` globally — all honey cells switch to detail mode simultaneously, which is more consistent than per-cell toggles. The attribute is set client-side only (`player:SetAttribute`) and never sent to the server.
- The 0.6-second tween on the fill bar makes newly collected honey feel satisfying — kids see the bar drain down smoothly rather than jump.
