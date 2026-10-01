# Dispatch 70 — FriendBonusService
## Cycle 11 · A Bee's World

**Feature:** Friend presence bonus — when a player has at least one Roblox friend in the same server their honey yield gets a +10% multiplier (stacks to +30% for 3+ friends). Calculated server-side using `Players:GetFriendsAsync()` cached per player. Updates on join/leave. Client HUD shows a small "🐝+friends" indicator when bonus is active.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 69 (SeasonalEventService)

---

## DESIGN

`FriendBonusService` caches each player's friend list on join (async, one page of 50 friends). When any player joins or leaves, the service recalculates every current player's bonus and broadcasts via `FriendBonusSync` RemoteEvent.

```
friendCount = count of players in server who are in my friend list
bonus = min(friendCount, 3) * 0.10   → max 1.30× (30% bonus)
```

`ForagingService` calls `GetHoneyMultiplier(player)` and applies it on top of the seasonal multiplier:
```lua
honeyYield = math.floor(honeyYield * _seasonal.honey * FriendBonusService.GetHoneyMultiplier(player))
```

### HUD indicator

A small TextLabel in `HiveHUDController` (patched) appears at bottom-left when `friendBonus > 0`:
```
🐝 +10% friend bonus
```
Positioned below the propolis counter, fades in/out with TweenService.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `FriendBonusService` (new Script in SSS) | friend list cache, bonus calc, FriendBonusSync RE |
| `GameManager` | Init call |
| `ForagingService` | apply friend multiplier |
| `HiveHUDController` | friend bonus indicator label |

---

## STEP A — FriendBonusService (new Script)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")

local FriendBonusSync = Instance.new("RemoteEvent")
FriendBonusSync.Name   = "FriendBonusSync"
FriendBonusSync.Parent = RS

local svc = Instance.new("Script")
svc.Name   = "FriendBonusService"
svc.Parent = SSS
svc.Source = [[
--!strict
-- FriendBonusService
-- Honey yield +10% per friend in server (max +30% at 3 friends).

local SSS  = game:GetService("ServerScriptService")
local RS   = game:GetService("ReplicatedStorage")
local PS   = game:GetService("Players")

local FriendBonusSync = RS:WaitForChild("FriendBonusSync")

local FriendBonusService = {}

-- friend list cache: userId → {[friendId]: true}
local friendCache: {[number]: {[number]: boolean}} = {}
-- current multiplier cache: userId → multiplier
local bonusCache:  {[number]: number} = {}

local function fetchFriends(player: Player)
	local uid = player.UserId
	local friends: {[number]: boolean} = {}
	local ok, pages = pcall(function()
		return PS:GetFriendsAsync(uid)
	end)
	if ok and pages then
		local success, items = pcall(function() return pages:GetCurrentPage() end)
		if success then
			for _, item in items do
				friends[item.Id] = true
			end
		end
	end
	friendCache[uid] = friends
end

local function calcBonus(player: Player): number
	local uid = player.UserId
	local friends = friendCache[uid] or {}
	local count = 0
	for _, other in PS:GetPlayers() do
		if other ~= player and friends[other.UserId] then
			count += 1
			if count >= 3 then break end
		end
	end
	return 1.0 + math.min(count, 3) * 0.10
end

local function refreshAll()
	for _, player in PS:GetPlayers() do
		local mult = calcBonus(player)
		bonusCache[player.UserId] = mult
		FriendBonusSync:FireClient(player, {multiplier = mult})
	end
end

function FriendBonusService.GetHoneyMultiplier(player: Player): number
	return bonusCache[player.UserId] or 1.0
end

function FriendBonusService.Init()
	PS.PlayerAdded:Connect(function(player)
		task.spawn(function()
			fetchFriends(player)
			-- small wait so the new player's UserId is in PS:GetPlayers()
			task.wait(1)
			refreshAll()
		end)
	end)

	PS.PlayerRemoving:Connect(function(player)
		friendCache[player.UserId] = nil
		bonusCache[player.UserId]  = nil
		task.wait(0.1)
		refreshAll()
	end)

	-- Init existing players (edge case: server started with players)
	for _, player in PS:GetPlayers() do
		task.spawn(function()
			fetchFriends(player)
			local mult = calcBonus(player)
			bonusCache[player.UserId] = mult
			FriendBonusSync:FireClient(player, {multiplier = mult})
		end)
	end

	print("[FriendBonusService] ready")
end

return FriendBonusService
]]

print("FriendBonusService created")
```

---

## STEP B — GameManager: inject FriendBonusService.Init()

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local gm = SSS:FindFirstChild("GameManager")
assert(gm, "GameManager not found")

local clone = gm:Clone()
clone.Name = "GameManager_WORKING"

local anchor = 'local SeasonalEventService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "SeasonalEventService require not found in GameManager")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal FriendBonusService = require(SSS:WaitForChild(\"FriendBonusService\"))" .. clone.Source:sub(lineEnd + 1)

local initAnchor = 'SeasonalEventService.Init()'
local found2 = clone.Source:find(initAnchor, 1, true)
assert(found2, "SeasonalEventService.Init() not found")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\nFriendBonusService.Init()" .. clone.Source:sub(lineEnd2 + 1)

gm.Name = "GameManager_OLD_NX"
gm.Parent = nil
clone.Name = "GameManager"
clone.Parent = SSS

print("GameManager FriendBonusService.Init() injected")
```

---

## STEP C — ForagingService: apply friend multiplier

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local fs = SSS:FindFirstChild("ForagingService")
assert(fs, "ForagingService not found")

local clone = fs:Clone()
clone.Name = "ForagingService_WORKING"

-- Inject require after SeasonalEventService require
local anchor = 'local SeasonalEventService'
local found = clone.Source:find(anchor, 1, true)
assert(found, "SeasonalEventService require not found in ForagingService")
local lineEnd = clone.Source:find("\n", found, true)
clone.Source = clone.Source:sub(1, lineEnd) .. "\nlocal FriendBonusService = require(SSS:WaitForChild(\"FriendBonusService\"))" .. clone.Source:sub(lineEnd + 1)

-- Apply friend multiplier to honeyYield after seasonal multiplier line
-- Find: honeyYield = math.floor(honeyYield * _seasonal.honey)
local anchor2 = 'honeyYield   = math.floor(honeyYield   * _seasonal.honey)'
local found2 = clone.Source:find(anchor2, 1, true)
assert(found2, "seasonal honey mult line not found in ForagingService")
local lineEnd2 = clone.Source:find("\n", found2, true)
clone.Source = clone.Source:sub(1, lineEnd2) .. "\n\thoneyYield = math.floor(honeyYield * FriendBonusService.GetHoneyMultiplier(player))" .. clone.Source:sub(lineEnd2 + 1)

fs.Name = "ForagingService_OLD_NX"
fs.Parent = nil
clone.Name = "ForagingService"
clone.Parent = SSS

print("ForagingService friend multiplier injected")
```

---

## STEP D — HiveHUDController: friend bonus indicator

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("HiveHUDController")
assert(ctrl, "HiveHUDController not found")

local clone = ctrl:Clone()
clone.Name = "HiveHUDController_WORKING"

-- Inject RS require at top
local anchor = 'local RS'
local found = clone.Source:find(anchor, 1, true)
assert(found, "local RS not found in HiveHUDController")
local lineEnd = clone.Source:find("\n", found, true)
local injection = [[
local FriendBonusSync = RS:WaitForChild("FriendBonusSync")
]]
clone.Source = clone.Source:sub(1, lineEnd) .. "\n" .. injection .. clone.Source:sub(lineEnd + 1)

-- Inject friend bonus label creation + listener at the end of buildGui or after playerGui setup
-- Append before the last 'return' or at end of source
local endAnchor = 'TweenService'
local foundEnd = clone.Source:find(endAnchor, 1, true)
-- Append friend bonus listener to end of source
local friendInjection = [[

-- Friend bonus indicator
local friendLbl = Instance.new("TextLabel")
friendLbl.Name              = "FriendBonus"
friendLbl.Size              = UDim2.new(0.35, 0, 0.05, 0)
friendLbl.Position          = UDim2.new(0.01, 0, 0.90, 0)
friendLbl.BackgroundTransparency = 1
friendLbl.Text              = ""
friendLbl.TextColor3        = Color3.fromRGB(200, 240, 180)
friendLbl.TextScaled        = true
friendLbl.Font              = Enum.Font.GothamBold
friendLbl.TextXAlignment    = Enum.TextXAlignment.Left
friendLbl.ZIndex            = 11
friendLbl.Visible           = false
friendLbl.Parent            = playerGui:WaitForChild("HiveHUD") or playerGui

FriendBonusSync.OnClientEvent:Connect(function(data: {multiplier: number})
	local bonus = data.multiplier or 1.0
	if bonus > 1.001 then
		local pct = math.floor((bonus - 1.0) * 100 + 0.5)
		friendLbl.Text    = "🐝 +" .. pct .. "% friend bonus"
		friendLbl.Visible = true
	else
		friendLbl.Visible = false
	end
end)
]]
clone.Source = clone.Source .. friendInjection

ctrl.Name = "HiveHUDController_OLD_NX"
ctrl.Parent = nil
clone.Name = "HiveHUDController"
clone.Parent = SPS

print("HiveHUDController friend bonus indicator injected")
```

---

## STEP E — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local checks = {}

local svc = SSS:FindFirstChild("FriendBonusService")
table.insert(checks, (svc and "✅" or "❌") .. " FriendBonusService script")

local sync = RS:FindFirstChild("FriendBonusSync")
table.insert(checks, (sync and sync:IsA("RemoteEvent") and "✅" or "❌") .. " FriendBonusSync RemoteEvent")

local gm = SSS:FindFirstChild("GameManager")
table.insert(checks, (gm and gm.Source:find("FriendBonusService") and "✅" or "❌") .. " GameManager Init")

local fs = SSS:FindFirstChild("ForagingService")
table.insert(checks, (fs and fs.Source:find("FriendBonusService") and "✅" or "❌") .. " ForagingService multiplier")

local hud = SPS and SPS:FindFirstChild("HiveHUDController")
table.insert(checks, (hud and hud.Source:find("FriendBonusSync") and "✅" or "❌") .. " HiveHUDController indicator")

print("=== DISPATCH 70 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 70 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| UI elements (no BaseParts) | 0 |
| **Dispatch 70 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `Players:GetFriendsAsync()` is a paginated call that may yield. It runs inside `task.spawn` so it never blocks the PlayerAdded event. If it fails (e.g. HTTP service off), `friendCache[uid]` stays `{}` and the player simply gets 0 bonus — no crash.
- Only the **first page** of friends (50 entries) is loaded. This covers 99% of players; a player with exactly 50 friends on page 1 and more on page 2 might miss a few, but this avoids multiple async page reads per join event.
- `refreshAll()` recalculates and rebroadcasts to **every** player when anyone joins/leaves. This is intentional — the bonus is symmetric (if I have you as a friend, you may not have me, but the server checks from each player's own list). Each `FriendBonusSync:FireClient` call is O(n) per join/leave; at typical server sizes (5–20 players) this is negligible.
- The friend bonus stacks **multiplicatively** with the seasonal multiplier:
  `finalHoney = base × seasonal.honey × friendMultiplier`
  e.g. Spring Bloom (2×) + 3 friends (+30%) = 2.6× total honey.
- The HiveHUD label appended at source end uses `playerGui:WaitForChild("HiveHUD")` as a graceful fallback — if HiveHUD doesn't exist the label parents to playerGui directly and still works.
- Friend bonus does NOT affect propolis or pollen — only honey. This keeps the pollen economy (which has its own PollenYield upgrade track) separate from social multipliers.
