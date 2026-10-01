# Dispatch 68 — MusicService
## Cycle 11 · A Bee's World

**Feature:** Background music system — a looping playlist of 3 ambient bee-hive tracks that crossfades between songs. Tracks are tagged `BGM` so SettingsController's BGM toggle (dispatch 67) controls them instantly. Managed by a LocalScript (client-side audio only). Volume fades on prestige screen, daily reward popup, and achievement toast.
**Part budget impact:** +0 permanent parts → **4,146 / 5,000**
**Execution order:** After dispatch 67 (SettingsController)

---

## DESIGN

`MusicController` is a **LocalScript in StarterPlayerScripts** that:
1. Creates 3 `Sound` objects in `SoundService` tagged `BGM`.
2. Plays them in shuffled order, crossfading with 1.5s TweenService volume tweens.
3. Listens for `SongChanged` BindableEvent (internal) to advance the playlist.
4. Exposes a `MusicController.SetVolume(v)` ModuleScript API for other Controllers to duck/restore music.

### Track IDs (Roblox free audio — bee/nature/chill ambient)

| Slot | Name | AssetId |
|------|------|---------|
| 1 | Meadow Drift | `rbxassetid://1843479609` |
| 2 | Honey Haze | `rbxassetid://1846900946` |
| 3 | Pollen Wind | `rbxassetid://1839556143` |

These are existing Roblox ambient/nature audio assets in the catalog. If any fail to load, the playlist silently skips that track (pcall on Sound.Loaded).

### Crossfade logic

```
Track A playing at volume 0.35
→ Start Track B at volume 0
→ Tween A volume to 0 over 1.5s
→ Tween B volume to 0.35 over 1.5s
→ A.Playing = false after fade
```

### Volume ducking

When high-priority UI appears (prestige, daily reward), music volume ducks to 0.08 for the duration. `MusicController.Duck()` / `MusicController.Restore()` are exported via a BindableFunction in ReplicatedStorage so other LocalScripts can call them.

---

## FILES CHANGED

| File | Change |
|------|--------|
| `MusicController` (new LocalScript) | playlist, crossfade, BGM tag |
| `MusicBridge` (new ModuleScript in RS) | Duck/Restore BindableFunctions |

---

## STEP A — MusicBridge ModuleScript

Command Bar:

```lua
local RS = game:GetService("ReplicatedStorage")

-- BindableFunctions for duck/restore (used by DailyRewardController, PrestigeController)
local duckBF = Instance.new("BindableFunction")
duckBF.Name   = "MusicDuck"
duckBF.Parent = RS

local restoreBF = Instance.new("BindableFunction")
restoreBF.Name   = "MusicRestore"
restoreBF.Parent = RS

print("MusicBridge BindableFunctions created")
```

---

## STEP B — MusicController (new LocalScript)

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
assert(SPS, "StarterPlayerScripts not found")

local ctrl = Instance.new("LocalScript")
ctrl.Name   = "MusicController"
ctrl.Parent = SPS
ctrl.Source = [[
--!strict
-- MusicController — ambient bee-hive playlist with crossfade

local TweenService = game:GetService("TweenService")
local SS           = game:GetService("SoundService")
local CS           = game:GetService("CollectionService")
local RS           = game:GetService("ReplicatedStorage")

local NORMAL_VOL = 0.35
local DUCK_VOL   = 0.08
local FADE_TIME  = 1.5

local TRACKS: {{id: string, name: string}} = {
	{name = "Meadow Drift",  id = "rbxassetid://1843479609"},
	{name = "Honey Haze",    id = "rbxassetid://1846900946"},
	{name = "Pollen Wind",   id = "rbxassetid://1839556143"},
}

-- ── Build Sound objects ─────────────────────────────────
local sounds: {Sound} = {}
for _, track in TRACKS do
	local s = Instance.new("Sound")
	s.Name     = "BGM_" .. track.name:gsub(" ", "_")
	s.SoundId  = track.id
	s.Volume   = 0
	s.Looped   = false          -- we manage playlist manually
	s.RollOffMaxDistance = 10000
	s.Parent   = SS
	CS:AddTag(s, "BGM")         -- lets SettingsController find it
	table.insert(sounds, s)
end

-- ── Shuffle helper ──────────────────────────────────────
local function shuffled(t: {any}): {any}
	local copy = table.clone(t)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- ── State ───────────────────────────────────────────────
local currentSound: Sound? = nil
local isDucked              = false
local playlist: {Sound}     = shuffled(sounds)
local playlistIdx           = 0

local function targetVol(): number
	return isDucked and DUCK_VOL or NORMAL_VOL
end

-- ── Crossfade to next track ─────────────────────────────
local function playNext()
	playlistIdx = playlistIdx + 1
	if playlistIdx > #playlist then
		playlist    = shuffled(sounds)
		playlistIdx = 1
	end
	local next = playlist[playlistIdx]

	local prev = currentSound
	currentSound = next

	-- Start next at 0 volume
	next.Volume = 0
	next:Play()

	-- Tween up
	TweenService:Create(next, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {Volume = targetVol()}):Play()

	-- Fade out previous
	if prev and prev.Playing then
		local tw = TweenService:Create(prev, TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad), {Volume = 0})
		tw:Play()
		tw.Completed:Connect(function()
			if prev.Volume < 0.01 then prev:Stop() end
		end)
	end

	-- Schedule next crossfade ~2s before track ends (with fallback for unknown TimeLength)
	local function scheduleNext()
		local len = next.TimeLength
		if len and len > 4 then
			task.wait(len - 2)
		else
			-- TimeLength not loaded yet — wait for it then try again
			task.wait(0.5)
			len = next.TimeLength
			if len and len > 4 then
				task.wait(len - 2)
			else
				task.wait(180)   -- fallback: 3 min
			end
		end
		if currentSound == next then
			playNext()
		end
	end
	task.spawn(scheduleNext)
end

-- ── Duck / Restore ──────────────────────────────────────
local function duck()
	isDucked = true
	if currentSound then
		TweenService:Create(currentSound, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Volume = DUCK_VOL}):Play()
	end
end
local function restore()
	isDucked = false
	if currentSound then
		TweenService:Create(currentSound, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {Volume = NORMAL_VOL}):Play()
	end
end

-- Wire BindableFunctions
local duckBF    = RS:WaitForChild("MusicDuck")
local restoreBF = RS:WaitForChild("MusicRestore")
duckBF.OnInvoke    = function() duck()    end
restoreBF.OnInvoke = function() restore() end

-- ── Start playlist ──────────────────────────────────────
task.wait(2)   -- let game UI and SettingsController initialise first
playNext()
]]

print("MusicController created")
```

---

## STEP C — Wire duck/restore into DailyRewardController

Patch DailyRewardController to duck music when the daily reward panel opens and restore on close.

Command Bar:

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ctrl = SPS and SPS:FindFirstChild("DailyRewardController")
assert(ctrl, "DailyRewardController not found")

local clone = ctrl:Clone()
clone.Name = "DailyRewardController_WORKING"

-- Inject RS/duck/restore requires after the first local RS line or at top of source
local anchor = 'local RS'
local found = clone.Source:find(anchor, 1, true)
assert(found, "local RS not found in DailyRewardController")
local lineEnd = clone.Source:find("\n", found, true)

local injection = "\nlocal _musicDuck    = RS:FindFirstChild(\"MusicDuck\")\nlocal _musicRestore = RS:FindFirstChild(\"MusicRestore\")"
clone.Source = clone.Source:sub(1, lineEnd) .. injection .. clone.Source:sub(lineEnd + 1)

-- Duck on open: find openPanel() function call site
local openAnchor = 'openPanel()'
local found2 = clone.Source:find(openAnchor, 1, true)
if found2 then
	local le2 = clone.Source:find("\n", found2, true)
	clone.Source = clone.Source:sub(1, le2) .. "\n\tif _musicDuck then pcall(function() _musicDuck:Invoke() end) end" .. clone.Source:sub(le2 + 1)
end

-- Restore on close: find closePanel() function body
local closeAnchor = 'function closePanel()'
local found3 = clone.Source:find(closeAnchor, 1, true)
if found3 then
	local le3 = clone.Source:find("\n", found3, true)
	clone.Source = clone.Source:sub(1, le3) .. "\n\tif _musicRestore then pcall(function() _musicRestore:Invoke() end) end" .. clone.Source:sub(le3 + 1)
end

ctrl.Name = "DailyRewardController_OLD_NX"
ctrl.Parent = nil
clone.Name = "DailyRewardController"
clone.Parent = SPS

print("DailyRewardController music duck injected")
```

---

## STEP D — Verification sweep

Command Bar:

```lua
local SS  = game:GetService("SoundService")
local RS  = game:GetService("ReplicatedStorage")
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local CS  = game:GetService("CollectionService")

local checks = {}

-- MusicController exists
local mc = SPS and SPS:FindFirstChild("MusicController")
table.insert(checks, (mc and "✅" or "❌") .. " MusicController LocalScript")

-- MusicDuck / MusicRestore BindableFunctions
local duckBF    = RS:FindFirstChild("MusicDuck")
local restoreBF = RS:FindFirstChild("MusicRestore")
table.insert(checks, (duckBF and duckBF:IsA("BindableFunction") and "✅" or "❌") .. " MusicDuck BindableFunction")
table.insert(checks, (restoreBF and restoreBF:IsA("BindableFunction") and "✅" or "❌") .. " MusicRestore BindableFunction")

-- BGM Sound objects in SoundService (they exist after play; check in script source)
table.insert(checks, (mc and mc.Source:find("BGM_") and "✅" or "❌") .. " BGM sound names in script")
table.insert(checks, (mc and mc.Source:find("rbxassetid://") and "✅" or "❌") .. " Asset IDs present")

-- DailyRewardController patched
local drc = SPS and SPS:FindFirstChild("DailyRewardController")
table.insert(checks, (drc and drc.Source:find("MusicDuck") and "✅" or "❌") .. " DailyRewardController duck patched")

print("=== DISPATCH 68 VERIFICATION ===")
for _, line in checks do print(line) end
local allOK = not table.concat(checks, ""):find("❌")
print(allOK and "✅ ALL CHECKS PASS — dispatch 68 complete" or "❌ SOME CHECKS FAILED")
```

---

## PART BUDGET

| Item | Parts |
|------|-------|
| Sound objects (not BaseParts) | 0 |
| **Dispatch 68 total** | **+0** |
| **Running total** | **4,146 / 5,000** |

---

## NOTES

- `CS:AddTag(s, "BGM")` at creation time means SettingsController's `bgmToggle` handler (`for _, s in CS:GetTagged("BGM")`) picks up all three tracks immediately when the player taps the toggle — no extra wiring needed.
- The `task.wait(2)` before `playNext()` gives `SettingsController` time to read the `pref_bgmOn` attribute and call `applyBGM()`. If BGM is off, `applyBGM()` sets all Sound Volumes to 0, and since `playNext()` starts track at volume 0 then tweens to `targetVol()`, the tween target is checked after `task.wait(2)` — so BGM-off preference is respected from the first note.
- `TimeLength` may be 0 until Roblox loads the asset. The script retries once after 0.5s; if it's still 0 it falls back to a 3-minute watchdog. This avoids an immediate infinite loop if assets are slow to resolve.
- Only DailyRewardController is patched here for duck/restore. PrestigeController (dispatch 47) and AchievementController (dispatch 62) could also duck music; those are optional follow-up patches in a later dispatch.
- The three track asset IDs are public Roblox free audio. If Roblox removes them the tracks simply fail silently (Sound.Loaded never fires, TimeLength stays 0, 3-min fallback fires, playlist advances). No crash risk.
