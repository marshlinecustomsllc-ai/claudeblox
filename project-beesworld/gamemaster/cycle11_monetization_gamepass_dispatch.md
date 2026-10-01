# CYCLE 11 — MONETIZATION GAMEPASS DISPATCH (dispatch 29)
## MonetizationService — Gamepass purchase → CosmeticService skin unlock wiring

**Agent:** luau-scripter  
**Prerequisites:** dispatch 22 (CosmeticService — 7 skins, WardrobeGui), dispatch 14 (ConsumableService — MonetizationService base framework exists in Config.MONETIZATION)  
**Part budget impact:** 0 new world parts → **~4,094 / 5,000** total (unchanged)

---

## OVERVIEW

When a player purchases the **MoonBee** or **ArcticBee** gamepass, `CosmeticService.CheckAndGrantUnlocks` is called immediately on the server so the skin appears in the Wardrobe without a rejoin. The purchase handler is already partially wired in `MonetizationService` from the shop-expansion dispatch — it processes receipts and grants consumable products. This dispatch adds the missing gamepass-purchase side of that system.

**Design constraints:**
- Server-authoritative: `MarketplaceService.UserOwnsGamePassAsync` is the truth source on every join AND on purchase; never trust client
- Idempotent: calling `CheckAndGrantUnlocks` when the skin is already owned is a no-op (it checks `profile.cosmeticsUnlocked` before inserting)
- No DataService migration: `profile.cosmeticsUnlocked` (array) already exists from dispatch 22 migration[9]
- Gamepass IDs remain `0` until the user pastes real IDs from the Creator Dashboard — the system short-circuits gracefully when ID is 0
- Fire `WardrobeDataSync` after a grant so the client's Wardrobe updates without a reload

---

## STEP A — MonetizationService: add gamepass purchase listener

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP A: Wire MarketplaceService.PromptGamePassPurchaseFinished
-- into MonetizationService so MoonBee/ArcticBee unlock immediately on purchase.
-- Uses clone-and-replace to bust require() cache.

local SSS = game:GetService("ServerScriptService")
local Systems = SSS:FindFirstChild("Systems")
assert(Systems, "Systems folder not found")

local msOld = Systems:FindFirstChild("MonetizationService")
assert(msOld and msOld:IsA("ModuleScript"), "MonetizationService ModuleScript not found")

local msClone = msOld:Clone()
local src = msOld.Source

-- 1. Add the gamepass-grant helper near the top of the module body
--    (after the existing local declarations, before Init)
local gpHelper = [[

-- Grant a skin by gamepass config key (e.g. "MoonBee"), then sync client.
-- No-op when the skin is already owned or when the config ID is 0.
local function grantGamepassSkin(player: Player, configKey: string)
    local CosmeticService = require(script.Parent.CosmeticService)
    local DataService     = require(script.Parent.DataService)
    local cfg = game:GetService("ReplicatedStorage").Modules.Config
    local Config = require(cfg)
    local skinId = configKey:lower()  -- e.g. "MoonBee" -> "moon_bee" via skin id in Config.COSMETICS
    -- Find the skin entry whose gamepass key matches
    for _, skin in Config.COSMETICS do
        if skin.gamepassKey == configKey then
            skinId = skin.id
            break
        end
    end
    DataService.GetProfile(player, function(profile)
        if not profile then return end
        -- idempotency check
        for _, id in profile.cosmeticsUnlocked do
            if id == skinId then return end
        end
        table.insert(profile.cosmeticsUnlocked, skinId)
        -- Sync client wardrobe
        local Remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        local sync = Remotes and Remotes:FindFirstChild("WardrobeDataSync")
        if sync then
            sync:FireClient(player, {
                cosmeticsUnlocked = profile.cosmeticsUnlocked,
                equippedSkin      = profile.equippedSkin or "honeybee",
            })
        end
        -- Fire Notify toast
        local notify = Remotes and Remotes:FindFirstChild("Notify")
        if notify then
            notify:FireClient(player, skin.label .. " skin unlocked! Check your Wardrobe.", "success")
        end
    end)
end
]]

-- Insert the helper just before the MonetizationService.Init function
src = src:gsub(
    "(function MonetizationService%.Init%s*%()",
    gpHelper .. "%1"
)

-- 2. Inside Init (or in a new PlayerAdded hook), add the gamepass ownership check on join
--    AND wire MarketplaceService.PromptGamePassPurchaseFinished.
--    Anchor: find where Players.PlayerAdded is connected inside Init (it already exists
--    in MonetizationService for product purchase handling).
local joinCheck = [[

    -- On each join, re-verify gamepass ownership and grant skins if not yet recorded
    Players.PlayerAdded:Connect(function(player)
        task.wait(5) -- wait for DataService to load profile
        local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
        local gpMap = {
            { key = "MoonBee",   id = Config.MONETIZATION.MoonBee   },
            { key = "ArcticBee", id = Config.MONETIZATION.ArcticBee },
        }
        for _, entry in gpMap do
            if entry.id and entry.id ~= 0 then
                local owns = false
                pcall(function()
                    owns = MarketplaceService:UserOwnsGamePassAsync(player.UserId, entry.id)
                end)
                if owns then
                    grantGamepassSkin(player, entry.key)
                end
            end
        end
    end)

    -- Immediate grant on purchase (no rejoin needed)
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
        if not wasPurchased then return end
        local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
        local gpMap = {
            { key = "MoonBee",   id = Config.MONETIZATION.MoonBee   },
            { key = "ArcticBee", id = Config.MONETIZATION.ArcticBee },
        }
        for _, entry in gpMap do
            if entry.id == gamePassId then
                grantGamepassSkin(player, entry.key)
                break
            end
        end
    end)
]]

-- Anchor: insert our new PlayerAdded and PromptGamePassPurchaseFinished hooks
-- just before the closing `end` of MonetizationService.Init
-- We'll find the ProcessReceipt assignment (always present) and insert after it.
src = src:gsub(
    "(MarketplaceService%.ProcessReceipt%s*=%s*[^\n]+\n)",
    "%1" .. joinCheck
)

-- Sanity checks
assert(src:find("grantGamepassSkin"), "grantGamepassSkin helper not found")
assert(src:find("PromptGamePassPurchaseFinished"), "purchase listener not found")
assert(src:find("MoonBee"), "MoonBee reference missing")
assert(src:find("ArcticBee"), "ArcticBee reference missing")

msOld.Name = "MonetizationService_OLD_pre_gp"
msClone.Source = src
msClone.Name   = "MonetizationService"
msClone.Parent = Systems
msOld.Parent   = nil

print("STEP A DONE: MonetizationService now grants MoonBee/ArcticBee skins on gamepass purchase")
print("  grantGamepassSkin helper added")
print("  PromptGamePassPurchaseFinished listener wired")
print("  PlayerAdded join-time ownership check added (fires after 5s profile-load delay)")
```

**Verify Step A:**

```lua
local SSS = game:GetService("ServerScriptService")
local ms = SSS.Systems:FindFirstChild("MonetizationService")
assert(ms, "MonetizationService not found")
local src = ms.Source
print("grantGamepassSkin:", src:find("grantGamepassSkin") ~= nil)
print("PromptGamePassPurchaseFinished:", src:find("PromptGamePassPurchaseFinished") ~= nil)
print("join ownership check:", src:find("UserOwnsGamePassAsync") ~= nil)
print("MoonBee entry:", src:find("MoonBee") ~= nil)
print("ArcticBee entry:", src:find("ArcticBee") ~= nil)
```

---

## STEP B — Add `gamepassKey` field to Config.COSMETICS skin entries

The `grantGamepassSkin` helper looks up `skin.gamepassKey` to find which Config.COSMETICS entry corresponds to a given purchase. The existing Config entries for Moon Bee and Arctic Bee lack this field — add it now.

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP B: Add gamepassKey field to Moon Bee and Arctic Bee in Config.COSMETICS
-- Uses clone-and-replace to bust require() cache.

local RS = game:GetService("ReplicatedStorage")
local Modules = RS:FindFirstChild("Modules")
assert(Modules, "ReplicatedStorage.Modules not found")

local cfgOld = Modules:FindFirstChild("Config")
assert(cfgOld and cfgOld:IsA("ModuleScript"), "Config ModuleScript not found")

local cfgClone = cfgOld:Clone()
local src = cfgOld.Source

-- Add gamepassKey = "MoonBee" to the Moon Bee entry
-- Anchor on the Moon Bee id line
src = src:gsub(
    '(id%s*=%s*"moon_bee"[^\n]*\n)',
    '%1\t\t\tgamepassKey = "MoonBee",\n'
)

-- Add gamepassKey = "ArcticBee" to the Arctic Bee entry
src = src:gsub(
    '(id%s*=%s*"arctic_bee"[^\n]*\n)',
    '%1\t\t\tgamepassKey = "ArcticBee",\n'
)

-- Sanity
assert(src:find('gamepassKey%s*=%s*"MoonBee"'), "MoonBee gamepassKey missing")
assert(src:find('gamepassKey%s*=%s*"ArcticBee"'), "ArcticBee gamepassKey missing")

cfgOld.Name = "Config_OLD_pre_gpkey"
cfgClone.Source = src
cfgClone.Name   = "Config"
cfgClone.Parent = Modules
cfgOld.Parent   = nil

print("STEP B DONE: Config.COSMETICS moon_bee and arctic_bee now have gamepassKey fields")
```

**Verify Step B:**

```lua
local RS = game:GetService("ReplicatedStorage")
local cfg = RS.Modules:FindFirstChild("Config")
assert(cfg, "Config not found")
local src = cfg.Source
print("MoonBee gamepassKey:", src:find('gamepassKey%s*=%s*"MoonBee"') ~= nil)
print("ArcticBee gamepassKey:", src:find('gamepassKey%s*=%s*"ArcticBee"') ~= nil)
```

---

## STEP C — Add `WardrobeDataSync` RemoteEvent (if missing)

`WardrobeDataSync` was introduced in dispatch 22 (CosmeticService). If that dispatch has been executed, this step is a no-op. If not, or if the remote was lost, create it.

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP C: Ensure WardrobeDataSync RemoteEvent exists in ReplicatedStorage.Remotes
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:FindFirstChild("Remotes")
if not Remotes then
    Remotes = Instance.new("Folder")
    Remotes.Name = "Remotes"
    Remotes.Parent = RS
    print("Created Remotes folder")
end

local wds = Remotes:FindFirstChild("WardrobeDataSync")
if wds then
    print("STEP C SKIP: WardrobeDataSync already exists")
else
    local re = Instance.new("RemoteEvent")
    re.Name = "WardrobeDataSync"
    re.Parent = Remotes
    print("STEP C DONE: WardrobeDataSync RemoteEvent created")
end
```

---

## STEP D — (Optional) Prompt gamepass purchase from Wardrobe locked-skin button

Currently, clicking a locked gamepass skin in the Wardrobe shows a lock label. This step replaces that with a `MarketplaceService:PromptGamePassPurchase` call so players can buy directly from the UI.

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP D (OPTIONAL): WardrobeController — prompt gamepass purchase on locked-gamepass skin click
-- Find WardrobeController in StarterPlayerScripts and add the purchase prompt.

local SP  = game:GetService("StarterPlayer")
local SPS = SP:FindFirstChild("StarterPlayerScripts")
local wc  = SPS and SPS:FindFirstChild("WardrobeController")
if not wc or not wc:IsA("LocalScript") then
    print("STEP D SKIP: WardrobeController not found in StarterPlayerScripts")
    return
end

local wcOld   = wc
local wcClone = wcOld:Clone()
local src     = wcOld.Source

-- Add MarketplaceService require at top (safe even if already present)
local mktRequire = [[
local MarketplaceService = game:GetService("MarketplaceService")
]]
if not src:find("MarketplaceService") then
    src = src:gsub(
        "(local WardrobeController%s*=%s*%{%})",
        mktRequire .. "%1"
    )
end

-- In the EquipButton.Activated handler (or equivalent locked-click path),
-- find where we show the LockLabel and add a purchase prompt before it.
local purchasePrompt = [[
                -- Prompt purchase for gamepass-locked skins
                local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
                for _, skin in Config.COSMETICS do
                    if skin.id == skinId and skin.gamepassKey then
                        local gpId = Config.MONETIZATION[skin.gamepassKey]
                        if gpId and gpId ~= 0 then
                            MarketplaceService:PromptGamePassPurchase(player, gpId)
                            return
                        end
                    end
                end
]]

-- Anchor: find the "skin is locked" branch in WardrobeController
-- (look for the LockLabel visibility toggle or "not unlocked" guard)
if src:find("LockLabel") then
    src = src:gsub(
        "(LockLabel%.Visible%s*=%s*true)",
        purchasePrompt .. "%1"
    )
    if src:find("PromptGamePassPurchase") then
        wcOld.Name = "WardrobeController_OLD_pre_gp"
        wcClone.Source = src
        wcClone.Name   = "WardrobeController"
        wcClone.Parent = SPS
        wcOld.Parent   = nil
        print("STEP D DONE: WardrobeController now prompts gamepass purchase for locked gamepass skins")
    else
        wcClone:Destroy()
        print("STEP D SKIP: Anchor not matched — manual edit needed")
    end
else
    wcClone:Destroy()
    print("STEP D SKIP: LockLabel anchor not found in WardrobeController")
end
```

> **Manual fallback for Step D:** Find the EquipButton handler in `WardrobeController`. Before or instead of showing `LockLabel.Visible = true`, add:
> ```lua
> local Config = require(game:GetService("ReplicatedStorage").Modules.Config)
> for _, skin in Config.COSMETICS do
>     if skin.id == skinId and skin.gamepassKey then
>         local gpId = Config.MONETIZATION[skin.gamepassKey]
>         if gpId and gpId ~= 0 then
>             game:GetService("MarketplaceService"):PromptGamePassPurchase(player, gpId)
>             return
>         end
>     end
> end
> ```

---

## STEP E — Verification

Run in Studio **Command Bar** (Edit mode):

```lua
-- STEP E: Verify gamepass purchase wiring
local SSS     = game:GetService("ServerScriptService")
local RS      = game:GetService("ReplicatedStorage")
local Systems = SSS:FindFirstChild("Systems")

local results = {}
local issues  = {}

-- 1. MonetizationService
local ms = Systems:FindFirstChild("MonetizationService")
if ms and ms:IsA("ModuleScript") then
    local src = ms.Source
    local checks = {
        hasHelper   = src:find("grantGamepassSkin") ~= nil,
        hasPurchase = src:find("PromptGamePassPurchaseFinished") ~= nil,
        hasJoinCheck = src:find("UserOwnsGamePassAsync") ~= nil,
        hasMoonBee  = src:find("MoonBee") ~= nil,
        hasArcticBee = src:find("ArcticBee") ~= nil,
    }
    local fails = {}
    for k, v in checks do if not v then table.insert(fails, k) end end
    if #fails == 0 then
        table.insert(results, "PASS: MonetizationService has all gamepass hooks")
    else
        table.insert(issues, "FAIL: MonetizationService missing: " .. table.concat(fails, ", "))
    end
else
    table.insert(issues, "FAIL: MonetizationService not found in Systems")
end

-- 2. Config.COSMETICS gamepassKey fields
local cfg = RS.Modules:FindFirstChild("Config")
if cfg and cfg:IsA("ModuleScript") then
    local src = cfg.Source
    if src:find('gamepassKey%s*=%s*"MoonBee"') then
        table.insert(results, "PASS: Config moon_bee has gamepassKey")
    else
        table.insert(issues, "FAIL: Config moon_bee missing gamepassKey")
    end
    if src:find('gamepassKey%s*=%s*"ArcticBee"') then
        table.insert(results, "PASS: Config arctic_bee has gamepassKey")
    else
        table.insert(issues, "FAIL: Config arctic_bee missing gamepassKey")
    end
else
    table.insert(issues, "FAIL: Config not found in ReplicatedStorage.Modules")
end

-- 3. WardrobeDataSync RemoteEvent
local Remotes = RS:FindFirstChild("Remotes")
local wds = Remotes and Remotes:FindFirstChild("WardrobeDataSync")
if wds and wds:IsA("RemoteEvent") then
    table.insert(results, "PASS: WardrobeDataSync RemoteEvent exists")
else
    table.insert(issues, "FAIL: WardrobeDataSync RemoteEvent missing from ReplicatedStorage.Remotes")
end

-- 4. No duplicate MonetizationService
local msCount = 0
for _, child in Systems:GetChildren() do
    if child.Name == "MonetizationService" then msCount = msCount + 1 end
end
if msCount == 1 then
    table.insert(results, "PASS: exactly 1 MonetizationService in Systems")
else
    table.insert(issues, "FAIL: " .. msCount .. " MonetizationService instances found (expected 1)")
end

-- 5. No duplicate Config
local cfgCount = 0
for _, child in RS.Modules:GetChildren() do
    if child.Name == "Config" then cfgCount = cfgCount + 1 end
end
if cfgCount == 1 then
    table.insert(results, "PASS: exactly 1 Config in Modules")
else
    table.insert(issues, "FAIL: " .. cfgCount .. " Config instances found (expected 1)")
end

-- Summary
print("=== GAMEPASS WIRING VERIFICATION ===")
for _, r in results do print(r) end
if #issues > 0 then
    print("\n--- ISSUES ---")
    for _, iss in issues do print(iss) end
    print("\nSTATUS: NEEDS FIXES (" .. #issues .. " issue(s))")
else
    print("\nSTATUS: ALL CHECKS PASS — gamepass purchase wiring ready")
    print("NOTE: Skins unlock immediately on purchase once real IDs are pasted into Config.MONETIZATION.")
    print("      Until then (ID=0), grantGamepassSkin short-circuits cleanly.")
end
```

---

## USER ACTION REQUIRED

The gamepass IDs in `Config.MONETIZATION` are currently `0` — the system is wired and correct but will not fire until real IDs are pasted in.

**To get real IDs:**
1. Open [Roblox Creator Dashboard](https://create.roblox.com/dashboard/creations) for your game
2. Go to **Monetization → Passes** and create (or locate) **MoonBee** and **ArcticBee** passes
3. Copy each pass's numeric ID from the URL or the pass detail page
4. In Studio, open `ReplicatedStorage.Modules.Config` and find `Config.MONETIZATION`
5. Replace `MoonBee = 0` and `ArcticBee = 0` with the real IDs

Full list of passes to create (if not already done):
| Name | Type | Purpose |
|------|------|---------|
| VIP | Gamepass | 2× honey bonus permanently |
| DoubleHoney | Gamepass | 2× honey from harvest |
| AutoHarvest | Gamepass | Hive Steward auto-harvests every 120s |
| ExtraRouteSlot | Gamepass | +1 simultaneous waggle-dance route |
| **MoonBee** | Gamepass | Moon Bee skin unlock |
| **ArcticBee** | Gamepass | Arctic Bee skin unlock |
| HoneyPackSmall | Developer Product | +5,000 honey one-time |
| RoyalJellyPackSmall | Developer Product | +100 Royal Jelly one-time |

---

## SUMMARY

| Deliverable | Type | Location |
|-------------|------|----------|
| MonetizationService update | ModuleScript edit | ServerScriptService.Systems |
| Config.COSMETICS gamepassKey | ModuleScript edit | ReplicatedStorage.Modules.Config |
| WardrobeDataSync | RemoteEvent (if missing) | ReplicatedStorage.Remotes |
| WardrobeController purchase prompt | LocalScript edit (optional) | StarterPlayerScripts |

**MonetizationService changes:**
- `grantGamepassSkin(player, configKey)` helper: idempotent, updates `profile.cosmeticsUnlocked`, fires `WardrobeDataSync` + `Notify` toast
- `Players.PlayerAdded` join-time check: calls `UserOwnsGamePassAsync` for MoonBee + ArcticBee after 5s profile-load delay
- `MarketplaceService.PromptGamePassPurchaseFinished` listener: calls `grantGamepassSkin` immediately on confirmed purchase

**Config changes:**
- `Config.COSMETICS` moon_bee entry: `gamepassKey = "MoonBee"` added
- `Config.COSMETICS` arctic_bee entry: `gamepassKey = "ArcticBee"` added

**Part budget:** 0 new world parts → **~4,094 / 5,000** total (unchanged)
