-- BUG #9 FIX: Duplicate DataService ModuleScript
-- Run this in Roblox Studio (Plugin Script or Command Bar) while in EDIT MODE.
-- It identifies which DataService instance Systems:FindFirstChild resolves to,
-- destroys the OTHER one, then verifies count == 1.

local systems = game:GetService("ServerScriptService"):FindFirstChild("Systems")
if not systems then
    print("FAIL: ServerScriptService.Systems folder not found")
    return
end

-- Find ALL DataService instances in Systems (direct children only -- that's
-- where FindFirstChild resolves on first-match order)
local allDS = {}
for _, child in systems:GetChildren() do
    if child.Name == "DataService" then
        table.insert(allDS, child)
    end
end

print(string.format("Found %d DataService instance(s) in Systems", #allDS))

if #allDS == 0 then
    print("FAIL: No DataService found at all -- something else is wrong")
    return
elseif #allDS == 1 then
    print("OK: Only 1 DataService exists -- no duplicate, bug already resolved")
    print("Instance: " .. allDS[1]:GetFullName())
    return
end

-- More than 1: FindFirstChild returns the FIRST one in child order
-- (index 1 in GetChildren() ordering -- no guaranteed ChildOrder for
-- Folder/ModuleScript, but FindFirstChild is documented as "first added")
-- We will: identify the primary (the one FindFirstChild returns),
-- verify they are truly byte-identical, then destroy the secondary.

local primary = systems:FindFirstChild("DataService")
print("Primary (FindFirstChild resolves to): " .. primary:GetFullName())
print("Primary Source length: " .. #primary.Source)

local secondary = nil
for _, ds in allDS do
    if ds ~= primary then
        secondary = ds
        break
    end
end

if not secondary then
    print("Could not identify secondary -- aborting to be safe")
    return
end

print("Secondary (to be destroyed): " .. secondary:GetFullName())
print("Secondary Source length: " .. #secondary.Source)

-- Safety check: are they byte-identical?
if primary.Source ~= secondary.Source then
    print("WARNING: Sources differ! Lengths: primary=" .. #primary.Source .. " secondary=" .. #secondary.Source)
    print("Aborting -- inspect manually before deleting")
    print("State: primary first line = " .. primary.Source:sub(1, 80))
    print("State: secondary first line = " .. secondary.Source:sub(1, 80))
    return
end

print("Sources are byte-identical (confirmed safe to delete secondary)")

-- Destroy the secondary
secondary:Destroy()
print("Secondary destroyed.")

-- Verify
local count = 0
local remaining = nil
for _, child in systems:GetChildren() do
    if child.Name == "DataService" then
        count = count + 1
        remaining = child
    end
end

if count == 1 then
    print("PASS: count == 1. Remaining instance: " .. remaining:GetFullName())
    print("BUG #9 RESOLVED. Save the place file now (Ctrl+S in Studio).")
else
    print("FAIL: count == " .. count .. " after deletion -- unexpected state, do not save")
end
