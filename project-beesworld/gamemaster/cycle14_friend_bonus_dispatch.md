# Dispatch 151 — Friend Bonus
## Cycle 14 · A Bee's World

**Feature:** Friend Bonus — +10% honey production for every Roblox friend on the same server, capped at 3 friends (+30% max). `FriendBonusService` checks friends asynchronously via `Players:GetFriendsAsync()` on each player join/leave and writes `FriendBonusCount` (0–3) per player. `CombService` applies the multiplier. A small client pill shows the active bonus so players know the mechanic exists. Part budget: +1 permanent (one server Script; friend display is LocalScript = +0 permanent).
**Part budget impact:** +1 permanent → **4,158 / 5,000**
**Execution order:** After dispatch 150 (Bee Population Display)

---

## DESIGN

### Friend detection

Roblox `Players:GetFriendsAsync(userId)` returns a `FriendPages` object listing all friends of a given player. For each player on the server, the service fetches their friend list once per session (async, wrapped in `pcall`) and compares it against the UserId set of all other current players.

**Rate-limit safety:** `GetFriendsAsync` is throttled. For a server of ≤6 players, one call per joining player is well within limits. The bonus applies lazily — no penalty during the async check, bonus kicks in once resolved.

### FriendBonusCount attribute

- Written by server: integer 0–3 (capped — more friends beyond 3 are great but don't add more bonus)
- Re-evaluated on every player join and leave
- Counts only mutual friends (both players must be friends — `GetFriendsAsync` on player A and checking for player B's UserId covers this: Roblox friendships are mutual)

### CombService integration

Multiplier: `1.0 + FriendBonusCount × 0.10`

| Friends | Multiplier |
|---------|------------|
| 0 | ×1.0 |
| 1 | ×1.1 |
| 2 | ×1.2 |
| 3 | ×1.3 |

### Client indicator

Bottom-left pill at `{0, 8, 1, -108}` (40px above the bee population pill):
- 0 friends: `"👥 Invite friends: +10% each"` (dim, grey text — educates the mechanic)
- 1–3 friends: `"👥 +N friend" / "+N friends"` (amber, bright — celebrates the bonus)

---

## FILES CHANGED

| File | Change |
|------|--------|
| `FriendBonusService` | New Script in ServerScriptService |
| `FriendBonusController` | New LocalScript in StarterPlayerScripts |
| `CombService` | +3 lines: friend bonus multiplier |

---

## STEP A — Create FriendBonusService

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
if SSS:FindFirstChild("FriendBonusService") then
    print("⏭️  FriendBonusService already exists — skip")
else
    local svc = Instance.new("Script")
    svc.Name    = "FriendBonusService"
    svc.Enabled = true
    svc.Source  = [[
--!strict
-- FriendBonusService — dispatch 151
-- +10% honey production per Roblox friend on same server, capped at 3.
-- FriendBonusCount attribute (0-3) per player, updated on join/leave.

local Players = game:GetService("Players")

local MAX_FRIENDS_151 = 3

-- Cache: player → set of friend UserIds (populated async on join)
local friendSets_151: {[Player]: {[number]: boolean}} = {}

-- Build friend set for a player (async, pcall-guarded)
local function buildFriendSet_151(player: Player)
    local set: {[number]: boolean} = {}
    local ok, result = pcall(function()
        return Players:GetFriendsAsync(player.UserId)
    end)
    if not ok then
        friendSets_151[player] = set
        return
    end
    local pages = result :: FriendPages
    local success = true
    while success do
        local ok2, items = pcall(function() return pages:GetCurrentPage() end)
        if not ok2 then break end
        for _, item in items do
            set[item.Id] = true
        end
        if pages.IsFinished then break end
        local ok3 = pcall(function() pages:AdvanceToNextPageAsync() end)
        if not ok3 then break end
    end
    friendSets_151[player] = set
end

-- Count how many current players are friends with this player
local function countFriends_151(player: Player): number
    local mySet = friendSets_151[player]
    if not mySet then return 0 end
    local count = 0
    for _, other in Players:GetPlayers() do
        if other ~= player then
            -- Check if other is in my friend set (mutual — Roblox friendships are always mutual)
            if mySet[other.UserId] then
                count = count + 1
                if count >= MAX_FRIENDS_151 then return count end
            end
        end
    end
    return count
end

-- Recount and apply for all current players
local function refreshAll_151()
    for _, player in Players:GetPlayers() do
        local count = countFriends_151(player)
        player:SetAttribute("FriendBonusCount", count)
    end
end

local function onPlayerAdded_151(player: Player)
    task.wait(2)  -- DataService replication
    if not player.Parent then return end

    -- Start with 0 while friend list loads
    player:SetAttribute("FriendBonusCount", 0)

    -- Async build friend set, then refresh everyone
    task.spawn(function()
        buildFriendSet_151(player)
        refreshAll_151()
        print(string.format("[FriendBonusService] %s: %d friend(s) on server",
            player.Name, countFriends_151(player)))
    end)
end

local function onPlayerRemoving_151(player: Player)
    friendSets_151[player] = nil
    -- Refresh remaining players after a short delay (give Players service time to update)
    task.delay(0.5, refreshAll_151)
end

Players.PlayerAdded:Connect(onPlayerAdded_151)
Players.PlayerRemoving:Connect(onPlayerRemoving_151)
for _, p in Players:GetPlayers() do task.spawn(onPlayerAdded_151, p) end

print("[FriendBonusService] Ready — friend bonus system active (max +" ..
    (MAX_FRIENDS_151 * 10) .. "%)")
]]
    svc.Parent = SSS
    print("✅ FriendBonusService created")
end
```

---

## STEP B — Create FriendBonusController

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if SPS:FindFirstChild("FriendBonusController") then
    print("⏭️  FriendBonusController already exists — skip")
else
    local ctrl = Instance.new("LocalScript")
    ctrl.Name   = "FriendBonusController"
    ctrl.Source = [[
--!strict
-- FriendBonusController — dispatch 151
-- Displays friend bonus count in bottom-left HUD pill.

local Players = game:GetService("Players")
local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)

local AMBER_151 = Color3.fromRGB(242, 168,  28)
local GREY_151  = Color3.fromRGB(120, 100,  70)
local DARK_151  = Color3.fromRGB(40,  25,   8)

local sg_151: ScreenGui? = nil
local label_151: TextLabel? = nil

local function ensureGui_151()
    if sg_151 and sg_151.Parent then return end
    sg_151 = Instance.new("ScreenGui")
    sg_151.Name         = "FriendBonusGui"
    sg_151.ResetOnSpawn = false
    sg_151.DisplayOrder = 10
    sg_151.Parent       = playerGui

    local pill = Instance.new("Frame")
    pill.Name                   = "FriendPill"
    pill.Size                   = UDim2.new(0, 168, 0, 28)
    pill.Position               = UDim2.new(0, 8, 1, -108)
    pill.BackgroundColor3       = DARK_151
    pill.BackgroundTransparency = 0.15
    pill.BorderSizePixel        = 0
    pill.Parent                 = sg_151 :: ScreenGui
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1,0); corner.Parent = pill
    local stroke = Instance.new("UIStroke"); stroke.Color = GREY_151; stroke.Thickness = 0.8; stroke.Parent = pill

    local lbl = Instance.new("TextLabel")
    lbl.Name                   = "FriendLabel"
    lbl.Size                   = UDim2.new(1, -8, 1, 0)
    lbl.Position               = UDim2.new(0, 4, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font                   = Enum.Font.Gotham
    lbl.TextSize               = 11
    lbl.TextColor3             = GREY_151
    lbl.TextXAlignment         = Enum.TextXAlignment.Center
    lbl.Text                   = "👥 Invite friends: +10% each"
    lbl.Parent                 = pill

    label_151 = lbl
end

local stokeRef_151: UIStroke? = nil

local function onFriendChanged_151()
    ensureGui_151()
    local count = math.floor(tonumber(player:GetAttribute("FriendBonusCount")) or 0)
    local lbl   = label_151 :: TextLabel
    local pill  = lbl.Parent :: Frame
    local stroke = pill:FindFirstChildOfClass("UIStroke") :: UIStroke?

    if count == 0 then
        lbl.TextColor3             = GREY_151
        lbl.Font                   = Enum.Font.Gotham
        lbl.Text                   = "👥 Invite friends: +10% each"
        if stroke then stroke.Color = GREY_151 end
    else
        lbl.TextColor3             = AMBER_151
        lbl.Font                   = Enum.Font.GothamBold
        local pct = count * 10
        local label = count == 1 and "friend" or "friends"
        lbl.Text = "👥 +" .. pct .. "% (" .. count .. " " .. label .. ")"
        if stroke then stroke.Color = AMBER_151 end
    end
end

ensureGui_151()
onFriendChanged_151()
player:GetAttributeChangedSignal("FriendBonusCount"):Connect(onFriendChanged_151)

print("[FriendBonusController] Ready")
]]
    ctrl.Parent = SPS
    print("✅ FriendBonusController created")
end
```

---

## STEP C — Patch CombService (friend multiplier)

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))
assert(comb, "CombService not found")

local old = [[local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146 * t2Multi_149)]]
local new = [[
            local friendMulti_151 = 1.0 + (math.min(3, tonumber(player:GetAttribute("FriendBonusCount")) or 0) * 0.10)
            local produced = math.floor(broodRate * elapsed * nurseMulti_143 * tempMulti_146 * t2Multi_149 * friendMulti_151)]]

if comb.Source:find(old, 1, true) then
    comb.Source = comb.Source:gsub(old:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]","%%%0"), new:gsub("%%","%%%%"), 1)
    print("✅ CombService patched — friend bonus multiplier active (max ×1.3 with 3 friends)")
elseif comb.Source:find("friendMulti_151", 1, true) then
    print("⏭️  CombService already has friend bonus patch — skip")
else
    print("⚠️  Previous produced line not found (expected t2Multi_149 from dispatch 149).")
    print("    Locate the final 'produced = math.floor(...)' line and append:")
    print("    × (1.0 + math.min(3, tonumber(player:GetAttribute('FriendBonusCount')) or 0) * 0.10)")
end
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")

local svc  = SSS:FindFirstChild("FriendBonusService")
local ctrl = SPS and SPS:FindFirstChild("FriendBonusController")
local comb = SSS:FindFirstChild("CombService") or
             (SSS:FindFirstChild("Systems") and SSS.Systems:FindFirstChild("CombService"))

local checks = {}
table.insert(checks, (svc and "✅" or "❌")  .. " FriendBonusService in ServerScriptService")
table.insert(checks, (svc and svc:IsA("Script") and "✅" or "❌") .. " is a Script")
table.insert(checks, (svc and svc.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (service)")
table.insert(checks, (svc and svc.Source:find("GetFriendsAsync", 1, true) and "✅" or "❌") .. " GetFriendsAsync friend lookup")
table.insert(checks, (svc and svc.Source:find("pcall", 1, true) and "✅" or "❌") .. " pcall rate-limit guard")
table.insert(checks, (svc and svc.Source:find("FriendBonusCount", 1, true) and "✅" or "❌") .. " FriendBonusCount attribute write")
table.insert(checks, (svc and svc.Source:find("MAX_FRIENDS_151", 1, true) and "✅" or "❌") .. " MAX_FRIENDS_151 cap (3)")
table.insert(checks, (svc and svc.Source:find("PlayerRemoving", 1, true) and "✅" or "❌") .. " PlayerRemoving refresh")
table.insert(checks, (ctrl and "✅" or "❌") .. " FriendBonusController in StarterPlayerScripts")
table.insert(checks, (ctrl and ctrl:IsA("LocalScript") and "✅" or "❌") .. " is a LocalScript")
table.insert(checks, (ctrl and ctrl.Source:find("--!strict", 1, true) and "✅" or "❌") .. " --!strict (controller)")
table.insert(checks, (ctrl and ctrl.Source:find("FriendPill", 1, true) and "✅" or "❌") .. " FriendPill UI element")
table.insert(checks, (comb and comb.Source:find("friendMulti_151", 1, true) and "✅" or "❌") .. " CombService friendMulti_151")

print("=== DISPATCH 151 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 151 complete" or "❌ SOME CHECKS FAILED")

print("\nFriend bonus: +10% per friend on server | cap 3 friends (+30%) | multiplier stacks with nurse/temp/t2")
print("Pill shows dim 'Invite friends' hint at 0 | amber '+X%' when friends present")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| FriendBonusService (Script in ServerScriptService) | +1 |
| FriendBonusController (LocalScript — no permanent count) | 0 |
| CombService patch (edit — no new instances) | 0 |
| **Dispatch 151 total** | **+1** |
| **Running total** | **4,158 / 5,000** |

---

## NOTES

- `buildFriendSet_151` iterates all pages of a player's friends list. For a player with hundreds of friends this could take a few seconds and several API calls. The `task.spawn` wrapper means the server never blocks waiting for it — other game logic continues. The `FriendBonusCount` starts at 0 and updates once the async call resolves, so there's a brief window where a friend's bonus hasn't kicked in yet. This is acceptable: the bonus applies within a few seconds of joining, and the transition from 0% to 10% is visible in the HUD.
- `refreshAll_151()` is called after each new player's friend list resolves. This means if player A and player B are friends and both join within seconds, each triggers a refresh that correctly counts the other. The refresh is cheap (just re-counts against already-loaded sets) so calling it multiple times on a busy join wave is fine.
- `onPlayerRemoving_151` delays 0.5 seconds before refreshing because `Players:GetPlayers()` may still include the departing player briefly. The delay lets the service table reflect the final server population.
- The client pill at `{0, 8, 1, -108}` stacks above the bee population pill at `{0, 8, 1, -72}` with a 36px gap (28px pill + 8px gutter). Both share `DisplayOrder=10` in separate ScreenGuis — no conflict since they occupy the same screen layer but different positions.
- The `MAX_FRIENDS_151 = 3` cap is a design decision, not a technical limit. Three friends covering a full 6-player server (player + 3 friends = 4 seats) feels achievable for a typical kids' friend group. Raising it to 5 is a one-line change if the cap feels too low after playtesting.
- The dim "Invite friends: +10% each" state when friends = 0 is intentional tutorial text. Players who have never heard of the mechanic learn it passively just by looking at the HUD. No pop-up required.
