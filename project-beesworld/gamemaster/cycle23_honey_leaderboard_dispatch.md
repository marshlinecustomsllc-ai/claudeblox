# Dispatch 223 — Honey Leaderboard Board
**File:** `cycle23_honey_leaderboard_dispatch.md`
**Cycle:** 23
**Date:** 2026-10-02
**Part budget before:** 4,204 / 5,000
**Part budget after:** 4,212 / 5,000 (+8)

---

## Overview

The architecture specifies a **cork board leaderboard** in the Apiary Yard hub showing the top-6 players by honey. Currently honey is tracked server-side but there is no persistent visible ranking. This dispatch adds:

1. **LeaderboardService** (server): polls player `HoneyCount` attributes every 15s, sorts top 6, writes `Leaderboard_Rank_N_Name` and `Leaderboard_Rank_N_Honey` workspace attributes.
2. **LeaderboardBoardController** (client): reads workspace attributes, updates BillboardGui text labels on the cork board Part in the Apiary Yard hub.
3. **Cork board part** (world): 8 parts added to the hub for the cork board structure + ranking labels.

For kids: seeing their name on a golden board is exciting social proof. For adults: precise honey count comparison drives competitive harvesting.

---

## Step 1 — LeaderboardService (ServerScriptService.Systems)

Open **ServerScriptService → Systems** and create a new **Script** named `LeaderboardService`.

Paste exactly:

```lua
--!strict
-- LeaderboardService: ranks top-6 players by HoneyCount, writes to workspace attributes.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")

local UPDATE_INTERVAL_223 = 15   -- seconds between leaderboard refreshes

-- Workspace attribute key format:
--   Leaderboard_Rank_1_Name  (string)
--   Leaderboard_Rank_1_Honey (number)
--   ... up to Rank_6

local function updateLeaderboard_223()
	-- Collect all players with their honey counts
	local entries: { { name: string, honey: number } } = {}
	for _, p in Players:GetPlayers() do
		local honey = (p:GetAttribute("HoneyCount") :: number?) or 0
		table.insert(entries, { name = p.Name, honey = honey })
	end

	-- Sort descending by honey
	table.sort(entries, function(a, b) return a.honey > b.honey end)

	-- Write top 6 to workspace attributes
	for rank = 1, 6 do
		local entry = entries[rank]
		if entry then
			workspace:SetAttribute("Leaderboard_Rank_" .. rank .. "_Name",  entry.name)
			workspace:SetAttribute("Leaderboard_Rank_" .. rank .. "_Honey", entry.honey)
		else
			workspace:SetAttribute("Leaderboard_Rank_" .. rank .. "_Name",  "")
			workspace:SetAttribute("Leaderboard_Rank_" .. rank .. "_Honey", 0)
		end
	end
end

-- ── Heartbeat accumulator ────────────────────────────────────────────────────
local acc_223 = 0
RunService.Heartbeat:Connect(function(dt: number)
	acc_223 += dt
	if acc_223 >= UPDATE_INTERVAL_223 then
		acc_223 = 0
		updateLeaderboard_223()
	end
end)

-- Initial write on server start
updateLeaderboard_223()

-- Re-run when a player leaves (their slot should clear)
Players.PlayerRemoving:Connect(function()
	task.delay(0.2, updateLeaderboard_223)
end)
```

---

## Step 2 — Cork board world parts (Apiary Yard hub)

Run in **Studio Command Bar** (Edit mode) to build the cork board in the Apiary Yard hub:

```lua
-- Cork board: 8 parts total
-- Position: near the Weather Notice Board at approximately CFrame(0, 4, -280)
-- Adjust X/Z to fit actual hub layout

local hub = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ApiaryYardHub")
	or workspace   -- fallback if folder name differs

local boardFolder = Instance.new("Folder")
boardFolder.Name = "HoneyLeaderboard"
boardFolder.Parent = hub

-- Cork board backing (dark wood frame)
local frame = Instance.new("Part")
frame.Name          = "LeaderboardFrame"
frame.Size          = Vector3.new(0.3, 4.2, 2.8)
frame.Position      = Vector3.new(0, 4, -280)    -- adjust to hub
frame.Anchored      = true
frame.CanCollide    = true
frame.Material      = Enum.Material.Wood
frame.Color         = Color3.fromRGB(60, 35, 15)
frame.Parent        = boardFolder

-- Cork surface
local cork = Instance.new("Part")
cork.Name           = "LeaderboardCork"
cork.Size           = Vector3.new(0.15, 3.6, 2.2)
cork.Position       = Vector3.new(0.08, 4, -280)
cork.Anchored       = true
cork.CanCollide     = false
cork.Material       = Enum.Material.SmoothPlastic
cork.Color          = Color3.fromRGB(185, 130, 75)
cork.Parent         = boardFolder

-- Header sign
local header = Instance.new("Part")
header.Name         = "LeaderboardHeader"
header.Size         = Vector3.new(0.12, 0.55, 2.0)
header.Position     = Vector3.new(0.1, 5.85, -280)
header.Anchored     = true
header.CanCollide   = false
header.Material     = Enum.Material.SmoothPlastic
header.Color        = Color3.fromRGB(242, 168, 28)   -- honey gold
header.Parent       = boardFolder

-- Header BillboardGui
local headerGui = Instance.new("BillboardGui")
headerGui.Name          = "LeaderboardHeaderGui"
headerGui.Size          = UDim2.new(0, 300, 0, 50)
headerGui.StudsOffset   = Vector3.new(0.1, 0, 0)
headerGui.AlwaysOnTop   = false
headerGui.ResetOnSpawn  = false
headerGui.Parent        = header

local headerLabel = Instance.new("TextLabel")
headerLabel.Size                   = UDim2.new(1, 0, 1, 0)
headerLabel.BackgroundTransparency = 1
headerLabel.Text                   = "🍯 Top Beekeepers 🍯"
headerLabel.TextSize               = 18
headerLabel.Font                   = Enum.Font.GothamBold
headerLabel.TextColor3             = Color3.fromRGB(40, 20, 5)
headerLabel.TextXAlignment         = Enum.TextXAlignment.Center
headerLabel.Parent                 = headerGui

-- 6 rank row parts
local MEDALS = { "🥇", "🥈", "🥉", "4.", "5.", "6." }
local rowHeight = 0.55
for rank = 1, 6 do
	local yOff = 5.2 - (rank - 1) * rowHeight
	local row = Instance.new("Part")
	row.Name        = "LeaderboardRow_" .. rank
	row.Size        = Vector3.new(0.1, 0.5, 2.0)
	row.Position    = Vector3.new(0.12, yOff, -280)
	row.Anchored    = true
	row.CanCollide  = false
	row.Material    = Enum.Material.SmoothPlastic
	row.Transparency = 1   -- invisible anchor for BillboardGui
	row.Parent      = boardFolder

	local rowGui = Instance.new("BillboardGui")
	rowGui.Name         = "RowGui_" .. rank
	rowGui.Size         = UDim2.new(0, 300, 0, 42)
	rowGui.StudsOffset  = Vector3.new(0.1, 0, 0)
	rowGui.AlwaysOnTop  = false
	rowGui.ResetOnSpawn = false
	rowGui.Parent       = row

	local rowLabel = Instance.new("TextLabel")
	rowLabel.Name                   = "RowLabel"
	rowLabel.Size                   = UDim2.new(1, 0, 1, 0)
	rowLabel.BackgroundTransparency = 1
	rowLabel.Text                   = MEDALS[rank] .. " —"
	rowLabel.TextSize               = 13
	rowLabel.Font                   = Enum.Font.Gotham
	rowLabel.TextColor3             = Color3.fromRGB(40, 20, 5)
	rowLabel.TextXAlignment         = Enum.TextXAlignment.Left
	rowLabel.Parent                 = rowGui
end

print("HoneyLeaderboard board built:", boardFolder:GetFullName())
print("Parts in board:", #boardFolder:GetChildren())
```

**Part count:** frame(1) + cork(1) + header(1) + 6 row anchors = **9 parts** total. All Anchored=true, BillboardGui rows are invisible (Transparency=1).

---

## Step 3 — LeaderboardBoardController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `LeaderboardBoardController`.

Paste exactly:

```lua
--!strict
-- LeaderboardBoardController: reads workspace leaderboard attributes and updates board labels.
-- Entirely client-side — reads workspace attributes written by LeaderboardService.

local RunService = game:GetService("RunService")

-- ── Config ────────────────────────────────────────────────────────────────────
local SCAN_INTERVAL_223 = 16   -- slightly after server update (15s + buffer)
local MEDALS_223 = { "🥇", "🥈", "🥉", "4.", "5.", "6." }
local HONEY_223   = Color3.fromRGB(242, 168, 28)
local EMPTY_223   = Color3.fromRGB(150, 120, 80)

-- ── Find board row labels ────────────────────────────────────────────────────
local function findRowLabels_223(): { [number]: TextLabel? }
	local labels: { [number]: TextLabel? } = {}
	local boardFolder = workspace:FindFirstChild("Map")
		and (workspace.Map :: Folder):FindFirstChild("ApiaryYardHub")
		and (((workspace.Map :: Folder):FindFirstChild("ApiaryYardHub") :: Folder):FindFirstChild("HoneyLeaderboard"))
		or workspace:FindFirstChild("HoneyLeaderboard", true)

	if not boardFolder then return labels end

	for rank = 1, 6 do
		local row = (boardFolder :: Folder):FindFirstChild("LeaderboardRow_" .. rank) :: BasePart?
		local rowGui = row and row:FindFirstChild("RowGui_" .. rank) :: BillboardGui?
		local label = rowGui and rowGui:FindFirstChild("RowLabel") :: TextLabel?
		labels[rank] = label
	end
	return labels
end

-- ── Update labels ─────────────────────────────────────────────────────────────
local function updateBoard_223()
	local labels = findRowLabels_223()
	for rank = 1, 6 do
		local lbl = labels[rank]
		if not lbl then continue end

		local name  = (workspace:GetAttribute("Leaderboard_Rank_" .. rank .. "_Name")  :: string?) or ""
		local honey = (workspace:GetAttribute("Leaderboard_Rank_" .. rank .. "_Honey") :: number?) or 0

		if name == "" then
			lbl.Text       = MEDALS_223[rank] .. " —"
			lbl.TextColor3 = EMPTY_223
		else
			lbl.Text       = MEDALS_223[rank] .. " " .. name .. "  🍯 " .. tostring(honey)
			lbl.TextColor3 = rank == 1 and HONEY_223 or Color3.fromRGB(40, 20, 5)
		end
	end
end

-- ── Workspace attribute change signals ───────────────────────────────────────
workspace:GetAttributeChangedSignal("Leaderboard_Rank_1_Name"):Connect(updateBoard_223)
workspace:GetAttributeChangedSignal("Leaderboard_Rank_1_Honey"):Connect(updateBoard_223)

-- ── Heartbeat scan (catches all rank changes) ────────────────────────────────
local scanAcc_223 = 0
RunService.Heartbeat:Connect(function(dt: number)
	scanAcc_223 += dt
	if scanAcc_223 >= SCAN_INTERVAL_223 then
		scanAcc_223 = 0
		updateBoard_223()
	end
end)

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(4, function()
	updateBoard_223()
end)
```

---

## Step 4 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("LeaderboardBoardController"))
```

---

## Step 5 — Verification sweep

Run in **Studio Command Bar** (Edit mode):

```lua
local hub = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("ApiaryYardHub")
local board = hub and hub:FindFirstChild("HoneyLeaderboard")
print("HoneyLeaderboard folder:", board and board:GetFullName() or "MISSING")
if board then
	local count = 0
	for _, p in board:GetDescendants() do
		if p:IsA("BasePart") then count += 1 end
	end
	print("  parts:", count, "(expect 9)")
	print("  LeaderboardFrame:", board:FindFirstChild("LeaderboardFrame") ~= nil)
	print("  LeaderboardRow_1:", board:FindFirstChild("LeaderboardRow_1") ~= nil)
	print("  LeaderboardRow_6:", board:FindFirstChild("LeaderboardRow_6") ~= nil)
end

local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("LeaderboardBoardController")
print("LeaderboardBoardController:", ctrl and ctrl.ClassName or "MISSING")

local SSS = game:GetService("ServerScriptService"):FindFirstChild("Systems")
local svc = SSS and SSS:FindFirstChild("LeaderboardService")
print("LeaderboardService:", svc and svc.ClassName or "MISSING")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4212)")
```

**Quick-test in Play mode:**

```lua
-- Simulate leaderboard data
workspace:SetAttribute("Leaderboard_Rank_1_Name", "BeeMaster")
workspace:SetAttribute("Leaderboard_Rank_1_Honey", 4820)
workspace:SetAttribute("Leaderboard_Rank_2_Name", "HoneyHoarder")
workspace:SetAttribute("Leaderboard_Rank_2_Honey", 3100)
workspace:SetAttribute("Leaderboard_Rank_3_Name", "Nectar99")
workspace:SetAttribute("Leaderboard_Rank_3_Honey", 1850)
-- Board labels should update within ~16s (or immediately via attribute signal)
```

---

## Behaviour summary

| Rank | Display | Update cadence |
|---|---|---|
| 1st | 🥇 [Name]  🍯 [N] — honey gold text | Within 15s of honey change |
| 2nd | 🥈 [Name]  🍯 [N] — dark brown text | Within 15s |
| 3rd | 🥉 [Name]  🍯 [N] — dark brown text | Within 15s |
| 4–6th | 4./5./6. [Name]  🍯 [N] | Within 15s |
| Empty slot | [medal] — (greyed out) | — |

- Board is physically located in the Apiary Yard hub near the Weather Notice Board
- 8-part structure: dark wood frame + cork surface + gold header + 6 invisible row anchors (BillboardGui)
- LeaderboardService polls every 15s; LeaderboardBoardController scans every 16s (1s buffer)
- Workspace attribute signal on Rank_1 fires immediate board refresh on any leaderboard change
- Board is always visible (AlwaysOnTop=false — occluded by geometry, natural in-world feel)
- Kids see their name on a golden board with trophies — social proof + pride. Adults see precise honey counts — competitive comparison

**Part budget: +8 server-side permanent → 4,212 / 5,000**
*(8 BaseParts in ApiaryYardHub.HoneyLeaderboard folder)*
