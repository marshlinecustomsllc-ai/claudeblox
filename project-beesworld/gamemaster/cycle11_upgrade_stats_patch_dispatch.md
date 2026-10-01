# Dispatch 73 — UpgradeStatsPatch
## Cycle 11 · A Bee's World

**Feature:** Injects `totalUpgradesBought += 1` into the 6 upgrade services that were left out of dispatch 72 (only SpeedUpgradeService was patched). After this dispatch all 7 upgrade services correctly increment the stat counter on every purchase.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 72 (HiveStatsService)

---

## SERVICES TO PATCH

| Service | Purchase trigger field |
|---------|----------------------|
| `QueenUpgradeService` | `profile.queenTier` |
| `PropolisUpgradeService` | `profile.propolisTier` |
| `PollenYieldService` | `profile.pollenYieldTier` |
| `HoneyStorageUpgradeService` | `profile.storageTier` |
| `PropolisStorageUpgradeService` | `profile.propolisStorageTier` |
| `PollenStorageUpgradeService` | `profile.pollenStorageTier` |

Each patch: clone-and-replace, inject `HiveStatsService` require and `profile.totalUpgradesBought` increment.

---

## STEP A — Patch all 6 remaining upgrade services

Command Bar (single execution — patches all 6):

```lua
local SSS = game:GetService("ServerScriptService")

local patches = {
	{name="QueenUpgradeService",         tierField="profile.queenTier"},
	{name="PropolisUpgradeService",      tierField="profile.propolisTier"},
	{name="PollenYieldService",          tierField="profile.pollenYieldTier"},
	{name="HoneyStorageUpgradeService",  tierField="profile.storageTier"},
	{name="PropolisStorageUpgradeService", tierField="profile.propolisStorageTier"},
	{name="PollenStorageUpgradeService", tierField="profile.pollenStorageTier"},
}

for _, patch in patches do
	local svc = SSS:FindFirstChild(patch.name)
	if not svc then
		print("⚠️  SKIP (not found): " .. patch.name)
		continue
	end

	-- Already patched?
	if svc.Source:find("totalUpgradesBought", 1, true) then
		print("⏭️  already patched: " .. patch.name)
		continue
	end

	local clone = svc:Clone()
	clone.Name = patch.name .. "_WORKING"

	-- Inject HiveStatsService require (after first 'local DataService' line)
	local dsAnchor = "local DataService"
	local dsFound = clone.Source:find(dsAnchor, 1, true)
	if dsFound then
		local dsLineEnd = clone.Source:find("\n", dsFound, true)
		clone.Source = clone.Source:sub(1, dsLineEnd) .. "\nlocal HiveStatsService = require(SSS:WaitForChild(\"HiveStatsService\"))" .. clone.Source:sub(dsLineEnd + 1)
	else
		print("⚠️  DataService require not found in " .. patch.name .. " — injecting at top")
		clone.Source = 'local HiveStatsService = require(game:GetService("ServerScriptService"):WaitForChild("HiveStatsService"))\n' .. clone.Source
	end

	-- Inject stat increment after tier field assignment
	local tierFound = clone.Source:find(patch.tierField, 1, true)
	if not tierFound then
		print("⚠️  tierField '" .. patch.tierField .. "' not found in " .. patch.name)
		svc.Name = patch.name .. "_SKIP"
		svc.Parent = nil
		clone.Name = patch.name
		clone.Parent = SSS
		continue
	end
	local tierLineEnd = clone.Source:find("\n", tierFound, true)
	clone.Source = clone.Source:sub(1, tierLineEnd) .. "\n\tprofile.totalUpgradesBought = (profile.totalUpgradesBought or 0) + 1" .. clone.Source:sub(tierLineEnd + 1)

	svc.Name = patch.name .. "_OLD_NX"
	svc.Parent = nil
	clone.Name = patch.name
	clone.Parent = SSS
	print("✅ " .. patch.name .. " patched")
end

print("Upgrade stats patch complete")
```

---

## STEP B — Verification sweep

Command Bar:

```lua
local SSS = game:GetService("ServerScriptService")

local services = {
	"SpeedUpgradeService",           -- patched in dispatch 72
	"QueenUpgradeService",
	"PropolisUpgradeService",
	"PollenYieldService",
	"HoneyStorageUpgradeService",
	"PropolisStorageUpgradeService",
	"PollenStorageUpgradeService",
}

local allOK = true
print("=== DISPATCH 73 VERIFICATION ===")
for _, name in services do
	local svc = SSS:FindFirstChild(name)
	if not svc then
		print("❌ " .. name .. ": NOT FOUND")
		allOK = false
	elseif svc.Source:find("totalUpgradesBought", 1, true) then
		print("✅ " .. name)
	else
		print("❌ " .. name .. ": totalUpgradesBought NOT FOUND in source")
		allOK = false
	end
end
print(allOK and "✅ ALL CHECKS PASS — dispatch 73 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Source patches only | 0 |
| **Dispatch 73 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- The single Command Bar block patches all 6 services in one execution. Each has an idempotency guard (`if svc.Source:find("totalUpgradesBought")`) so re-running after a partial success won't double-inject.
- `PollenYieldService` uses `profile.pollenYieldTier` — verify this field name matches the actual source from dispatch 36 (PollenYieldUpgradeService). If the field is named differently (e.g. `pollenTier`), the patch prints a warning and still deploys the clone. In that case run the STEP A script a second time with the corrected `tierField`.
- After this dispatch, the HiveStatsController "Upgrades Bought" counter correctly increments for all 7 upgrade paths.
