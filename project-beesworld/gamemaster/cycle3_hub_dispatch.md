# CYCLE 3 — Hub v2 Rebuild Dispatch

## WORLD-BUILDER TASK: Apiary Yard v2 (Expanded Hub)

**Priority:** HIGH — current hub is 140×140 (too cramped). Replace entirely with 400×280 v2.

---

### STEP 0 — CRITICAL PREREQUISITE

Before building anything, run this in Studio to destroy the old hub:

```lua
local workspace = game:GetService("Workspace")
local map = workspace:FindFirstChild("Map")
if map then
    local hub = map:FindFirstChild("ApiarYard") or map:FindFirstChild("ApiaryYard") or map:FindFirstChild("Hub")
    if hub then
        hub:Destroy()
        print("Old hub destroyed — ready to build v2")
    else
        print("No hub folder found — listing Map children:")
        for _, c in map:GetChildren() do print(c.Name) end
    end
else
    print("No Map folder found")
end
```

If the hub folder has a different name, destroy whichever folder represents it.

---

### ZONE SPECIFICATION

**Container:** `Workspace.Map.ApiaryYard` (Folder)
**Position reference:** All coordinates are absolute world position (X, Y, Z).
**Ground Y = 0** everywhere in this zone.
**Zone bounds:** X −200..+200, Z −266..−546

Materials to use:
- Floor: `Cobblestone` material, color `#9A9384`
- Main shed wall: `WoodPlanks` material, color `#8B6E4E`
- Structural posts/beams: `Wood` material, color `#7A5A3A`
- Metal elements: `Metal` material, color `#B0A890`
- Glass/water: `Glass` material, color `#B8E4FF`
- Stone accents: `Slate` material, color `#6A6A72`

---

### 1. BASE FLOOR

Create the cobblestone yard floor as a single large part:
- Position: (0, −1, −406)
- Size: (400, 2, 280)
- Material: Cobblestone, Color `#9A9384`
- Anchored: true, CanCollide: true
- Name: "YardFloor"

Add 3 large Slate stepping-slab accents (thinner, raised slightly):
- Slab1: Position (0, 0.2, −280), Size (40, 0.5, 20), Slate `#6A6A72`
- Slab2: Position (0, 0.2, −350), Size (50, 0.5, 20), Slate `#6A6A72`
- Slab3: Position (0, 0.2, −420), Size (40, 0.5, 20), Slate `#6A6A72`

---

### 2. ZONE 1 — GATEWAY ROW (Z −266..−330)

**Six Plot Gateways** (one per plot, spaced 100 studs apart at X = −250, −150, −50, +50, +150, +250):

For each gateway at X positions [−250, −150, −50, 50, 150, 250]:
- Lower box: Position (X, 4, −290), Size (8, 8, 6), WoodPlanks, Color `#F5F0E8` (white painted)
- Upper box: Position (X, 12, −290), Size (8, 8, 6), WoodPlanks, Color `#F5F0E8`
- Pennant stick: Position (X, 18, −290), Size (0.5, 8, 0.5), Wood, Color `#7A5A3A`
- Pennant flag (flat wedge): Position (X + 2, 21, −290), Size (4, 3, 0.5), SmoothPlastic

Pennant colors per plot index [1→6]: `#FFD700` (gold), `#FF6B35` (orange), `#9B59B6` (purple), `#2ECC71` (green), `#3498DB` (blue), `#E74C3C` (red)

Tag each gateway set with CollectionService tag "TeleportPad" and add Integer Attribute "PlotIndex" = [1..6].

**Hub Bell** at (0, 12, −298):
- Lower bell body: Position (0, 14, −298), Size (8, 8, 8), Shape: Cylinder or tapered box, Metal `#B0A890`
- Upper cap: Position (0, 19, −298), Size (6, 4, 6), Metal `#8A8070`
- Crossbeam: Position (0, 22, −298), Size (24, 2, 2), Wood `#7A5A3A`
- Post Left: Position (−12, 11, −298), Size (2, 22, 2), Wood `#7A5A3A`
- Post Right: Position (12, 11, −298), Size (2, 22, 2), Wood `#7A5A3A`
Tag the bell part: CollectionService tag "HubBell"

**SpawnLocation** at (0, 1.5, −300): Insert a SpawnLocation with TeamColor = BrickColor.new("White"), Size (6, 1, 6), Anchored true. Required by Roblox engine.

---

### 3. ZONE 2 — SOCIAL GARDEN (Z −330..−440)

**Birdbath** at (−80, 0, −385):
- Pedestal base: Position (−80, 3, −385), Size (6, 6, 6), Cobblestone `#9A9384`
- Pedestal column: Position (−80, 9, −385), Size (3, 6, 3), Slate `#6A6A72`
- Bowl: Position (−80, 13, −385), Size (25, 4, 25), Shape: Cylinder (use a short fat cylinder), Cobblestone `#9A9384`, hollow approximated by scale
- Water surface: Position (−80, 15.5, −385), Size (22, 0.5, 22), Shape: Cylinder, Glass `#B8E4FF`, Transparency 0.3, Material: Glass
- PointLight inside water part: Color `#B8D8FF`, Range 20, Brightness 0.5
- Small ripple ParticleEmitter on water part: Rate 3, LightEmission 0.1, color Light Blue

**Garden Table** at (90, 0, −390):
- Table top: Position (90, 8, −390), Size (30, 2, 20), WoodPlanks `#8B6E4E`
- Leg1: Position (78, 4, −382), Size (2, 8, 2), Wood `#7A5A3A`
- Leg2: Position (102, 4, −382), Size (2, 8, 2), Wood `#7A5A3A`
- Leg3: Position (78, 4, −398), Size (2, 8, 2), Wood `#7A5A3A`
- Leg4: Position (102, 4, −398), Size (2, 8, 2), Wood `#7A5A3A`
- Seat Left (log slice): Position (70, 5, −390), Size (8, 10, 8), Wood `#8B6E4E`, Shape: Cylinder
- Seat Right (log slice): Position (110, 5, −390), Size (8, 10, 8), Wood `#8B6E4E`, Shape: Cylinder
- Tea mug: Position (88, 10, −388), Size (6, 12, 6), Shape: Cylinder, SmoothPlastic `#F0EDE8`
- Mug handle: Position (95, 11, −388), Size (1.5, 5, 4), SmoothPlastic `#F0EDE8`
- Newspaper: Position (94, 9.5, −392), Size (14, 0.5, 10), SmoothPlastic `#F0E8D0`, slight rotation (5 degrees)
- Candle under table (PointLight source): Position (90, 3, −390), Size (1, 1, 1), Transparency 1, Anchored true
  Add PointLight to this part: Color `#FFCE8A`, Range 20, Brightness 0.6

**Leaderboard Cork Board** at (−140, 0, −395):
- Cork backing: Position (−140, 22, −395), Size (60, 40, 3), SmoothPlastic `#C4935A` (cork tan)
- Post Left: Position (−170, 11, −395), Size (3, 22, 3), Wood `#7A5A3A`
- Post Right: Position (−110, 11, −395), Size (3, 22, 3), Wood `#7A5A3A`
Tag the cork board: CollectionService tag "LeaderboardBoard"
Add a SurfaceGui to the cork board front face (Face = Front) with a TextLabel for leaderboard display.

**Scattered props (Social Garden):**
- Seed packet 1: Position (−60, 0.5, −360), Size (5, 7, 0.5), SmoothPlastic `#E8D870`, leaning angle 10°
- Seed packet 2: Position (−55, 0.5, −362), Size (5, 7, 0.5), SmoothPlastic `#D4E870`, leaning angle −15°
- Garden gloves (flat wedge shape): Position (110, 0.5, −370), Size (12, 1, 7), SmoothPlastic `#6BA86A`
- Glass marble: Position (−70, 2, −375), Size (4, 4, 4), Shape: Sphere, Glass `#A8D8FF`, Reflectance 0.8

---

### 4. ZONE 3 — FLOWERPOT DEN (Z −440..−490)

**Giant Terracotta Pot** (the social landmark):
- Pot body: Position (30, 20, −465), Size (50, 40, 50), Shape: Cylinder, SmoothPlastic `#B5572A`
  (Tilt 15° using CFrame rotation — the pot is tipped over, mouth facing somewhat toward the player)
- Pot rim (torus-like ring): Position (30, 36, −465), Size (55, 5, 55), Shape: Cylinder, SmoothPlastic `#9A4520`
- Pot interior PointLight: Position (30, 15, −455) inside the pot opening, Size (1,1,1) Transparency=1
  PointLight: Color `#FF9A4A`, Range 30, Brightness 0.7
- Soil spill (dark mound in front of mouth): Position (5, 1, −448), Size (20, 3, 15), SmoothPlastic `#4A3520`, slightly irregular rotation
- Crack on south face (decorative wedge): Position (30, 15, −490), Size (3, 12, 1), SmoothPlastic `#9A4520`
- 3 pansy sprouts inside the pot:
  - Sprout1: stem Position (20, 32, −462), Size (2, 14, 2), SmoothPlastic `#3A7A3A`; head Position (20, 40, −462), Size (8, 4, 8), SmoothPlastic `#9B4DC0`
  - Sprout2: stem Position (32, 30, −460), Size (2, 12, 2), SmoothPlastic `#3A7A3A`; head Position (32, 37, −460), Size (7, 3, 7), SmoothPlastic `#E84898`
  - Sprout3: stem Position (26, 28, −468), Size (2, 10, 2), SmoothPlastic `#3A7A3A`; head Position (26, 34, −468), Size (6, 3, 6), SmoothPlastic `#F0C040`

**Watering Can** at (−110, 0, −455):
- Can body: Position (−110, 10, −455), Size (25, 20, 18), SmoothPlastic `#5A8A5A` (green)
- Can spout (long cylinder angled down): Position (−88, 8, −455), Size (30, 4, 4), Shape: Cylinder, SmoothPlastic `#5A8A5A`, rotated 20° down
- Can handle (curved arch, 2 parts): 
  - Handle1: Position (−120, 15, −455), Size (4, 10, 3), SmoothPlastic `#5A8A5A`
  - Handle2: Position (−126, 10, −455), Size (4, 8, 3), SmoothPlastic `#5A8A5A`
- Drip emitter (at spout tip): Position (−72, 4, −455), Size (1,1,1), Transparency=1, Anchored=true
  ParticleEmitter: Rate 8, Color=`#B8D8FF`, LightEmission 0, small droplet shape
- Puddle under spout: Position (−72, 0.3, −455), Size (16, 0.4, 12), Glass `#9ABCDC`, Transparency 0.5

---

### 5. ZONE 4 — SHED WALL (Z −490..−546)

**Main Shed Wall:**
- Wall slab: Position (0, 65, −526), Size (200, 130, 4), WoodPlanks `#8B6E4E`
- Wall base trim (darker plank row): Position (0, 4, −526), Size (200, 8, 5), Wood `#6A4E30`

**Window** at (50, 45, −526):
- Window frame: Position (50, 45, −524), Size (30, 25, 2), Wood `#7A5A3A` — hollow frame approximated as 4 thin strips:
  - Frame top: Position (50, 58, −524), Size (32, 2, 2), Wood `#7A5A3A`
  - Frame bottom: Position (50, 33, −524), Size (32, 2, 2), Wood `#7A5A3A`
  - Frame left: Position (34, 45, −524), Size (2, 28, 2), Wood `#7A5A3A`
  - Frame right: Position (66, 45, −524), Size (2, 28, 2), Wood `#7A5A3A`
- Window glass: Position (50, 45, −525), Size (28, 22, 0.5), Glass `#FFF8DC`, Transparency 0.5
- Interior light (behind glass): Position (50, 45, −528), Size (1,1,1), Transparency=1
  PointLight: Color `#FFF4DC`, Range 55, Brightness 0.9

**Shed Eave Lights** (2 PointLights, always-on warm safety lights):
- Eave Left: Position (−90, 75, −526), Size (1,1,1), Transparency=1 — PointLight Color `#FFCE8A`, Range 45, Brightness 1.4
- Eave Right: Position (90, 75, −526), Size (1,1,1), Transparency=1 — PointLight Color `#FFCE8A`, Range 45, Brightness 1.4

**Leaning tools:**
- Shovel handle: Position (−60, 30, −522), Size (3, 60, 3), Wood `#8B6E4E`, slight lean (5° rotation)
- Shovel head: Position (−60, 62, −522), Size (12, 8, 2), Metal `#888880`
- Rake handle: Position (−45, 28, −522), Size (2.5, 56, 2.5), Wood `#8B6E4E`
- Rake head: Position (−38, 58, −522), Size (18, 3, 3), Wood `#8B6E4E`

**Stacked hive boxes** at (120, 0, −520) — 4 boxes, each 20×15×14 studs:
- Box1: Position (120, 7, −520), Size (20, 14, 15), WoodPlanks `#F0EAD6`
- Box2: Position (120, 21, −520), Size (20, 14, 15), WoodPlanks `#E8DFC8`
- Box3: Position (120, 35, −520), Size (20, 14, 15), WoodPlanks `#F0EAD6`
- Box4: Position (120, 49, −520), Size (20, 14, 15), WoodPlanks `#E8DFC8`

**Old boot** at (−150, 0, −500):
- Boot body: Position (−150, 8, −500), Size (16, 16, 24), SmoothPlastic `#3A3028` (dark rubber)
- Boot toe: Position (−150, 5, −488), Size (14, 10, 8), SmoothPlastic `#3A3028`
- Boot heel block: Position (−150, 3, −510), Size (10, 6, 6), SmoothPlastic `#2A2020`
- Moss on boot: Position (−150, 16, −500), Size (8, 2, 8), SmoothPlastic `#4A6A3A`, Transparency 0.4

---

### VERIFY AFTER BUILDING

Run these checks:

```lua
-- Count hub parts
local hub = workspace.Map:FindFirstChild("ApiaryYard")
if not hub then print("HUB FOLDER NOT FOUND") return end
local count = 0
for _, p in hub:GetDescendants() do
    if p:IsA("BasePart") then count = count + 1 end
end
print("Hub parts: " .. count .. " / budget 500")

-- Check SpawnLocation
local spawns = 0
for _, p in hub:GetDescendants() do
    if p:IsA("SpawnLocation") then spawns = spawns + 1 end
end
print("SpawnLocations: " .. spawns .. " (need >= 1)")

-- Check TeleportPad tags
local CS = game:GetService("CollectionService")
local pads = CS:GetTagged("TeleportPad")
print("TeleportPad tagged: " .. #pads .. " (need 6)")

-- Check HubBell
local bell = CS:GetTagged("HubBell")
print("HubBell tagged: " .. #bell .. " (need 1)")

-- Check lights
local lights = 0
for _, p in hub:GetDescendants() do
    if p:IsA("PointLight") then lights = lights + 1 end
end
print("PointLights: " .. lights .. " (need >= 5)")
```

Expected results:
- Hub parts: 180–500 (target ~500 with props)
- SpawnLocations: 1
- TeleportPad tagged: 6
- HubBell tagged: 1
- PointLights: 5+

---

### CHARACTER NOTE (pass to world-builder)

> The hub asks a question without ever stating it. The kitchen light is still on. The boot never moved. The newspaper on the table is dated. The watering can tipped — recently? years ago? The beekeeper's absence is the story. The question "what happened to the human?" should arrive unbidden and never be answered.
> 
> Zone 3 (the Flowerpot Den) is the campfire equivalent — the place players will naturally gather and take screenshots. The warm orange light from inside the tipped pot, the pansy sprouts, the soil spill: it is playful and slightly melancholy at the same time, which is the exact tonal register of the entire game.
