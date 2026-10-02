# Dispatch 232 — Wasp Alert Sound Controller
**File:** `cycle24_wasp_alert_sound_dispatch.md`
**Cycle:** 24
**Date:** 2026-10-02
**Part budget before:** 4,218 / 5,000
**Part budget after:** 4,218 / 5,000 (+0)

---

## Overview

When wasps enter the Apiary Yard the server sets the `WaspAlert` player attribute (via Dispatch 221 — ThreatService). The existing `WaspAlertController` shows a HUD warning, but there is no audio cue — players looking away from the screen may miss the alert. This dispatch adds a **WaspAlertSoundController**: a client-side LocalScript that plays a sharp buzzing sting when `WaspAlert` flips `true`, and a softer "all-clear" tone when it flips `false`. Both sounds are brief, non-looping, and use Roblox free audio assets.

For kids: the distinct "BZZZT!" sound means "danger, look at the hive!" — impossible to miss even while chatting. For adults: the all-clear chime confirms the wasp threat has passed without needing to check the HUD.

---

## Step 1 — WaspAlertSoundController (StarterPlayerScripts)

Open **StarterPlayerScripts** and create a new **LocalScript** named `WaspAlertSoundController`.

Paste exactly:

```lua
--!strict
-- WaspAlertSoundController: plays audio sting when WaspAlert attribute fires.
-- Reads WaspAlert (boolean) player attribute written by ThreatService (D221).
-- Entirely client-side — zero server writes, zero new parts.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────────
-- Roblox free audio assets (no copyright)
local ALERT_SOUND_ID_232   = "rbxassetid://9118438269"   -- sharp insect buzz sting
local ALLCLEAR_SOUND_ID_232 = "rbxassetid://5982793440"  -- soft chime / relief tone

local ALERT_VOLUME_232   = 0.65
local ALLCLEAR_VOLUME_232 = 0.35
local ALERT_PITCH_232    = 1.15   -- slightly higher pitch = urgency
local ALLCLEAR_PITCH_232 = 0.92   -- slightly lower pitch = resolution

-- Cooldown prevents alert spam if WaspAlert flips rapidly
local ALERT_COOLDOWN_232   = 4.0   -- seconds
local ALLCLEAR_COOLDOWN_232 = 2.0

-- ── State ─────────────────────────────────────────────────────────────────────
local alertSound_232: Sound? = nil
local clearSound_232: Sound? = nil
local lastAlertTime_232  = -999
local lastClearTime_232  = -999

-- ── Build sounds ──────────────────────────────────────────────────────────────
local function buildSounds_232()
	-- Parent to PlayerGui so they follow the player cleanly
	local gui = player:WaitForChild("PlayerGui")

	local alert = Instance.new("Sound")
	alert.Name          = "WaspAlertSting_232"
	alert.SoundId       = ALERT_SOUND_ID_232
	alert.Volume        = ALERT_VOLUME_232
	alert.PlaybackSpeed = ALERT_PITCH_232
	alert.Looped        = false
	alert.RollOffMode   = Enum.RollOffMode.InverseTapered
	alert.Parent        = gui
	alertSound_232 = alert

	local clear = Instance.new("Sound")
	clear.Name          = "WaspAllClear_232"
	clear.SoundId       = ALLCLEAR_SOUND_ID_232
	clear.Volume        = ALLCLEAR_VOLUME_232
	clear.PlaybackSpeed = ALLCLEAR_PITCH_232
	clear.Looped        = false
	clear.RollOffMode   = Enum.RollOffMode.InverseTapered
	clear.Parent        = gui
	clearSound_232 = clear
end

-- ── Play helpers ──────────────────────────────────────────────────────────────
local function playAlert_232()
	local now = os.clock()
	if now - lastAlertTime_232 < ALERT_COOLDOWN_232 then return end
	lastAlertTime_232 = now
	if alertSound_232 then
		alertSound_232:Stop()
		alertSound_232:Play()
	end
end

local function playAllClear_232()
	local now = os.clock()
	if now - lastClearTime_232 < ALLCLEAR_COOLDOWN_232 then return end
	lastClearTime_232 = now
	if clearSound_232 then
		clearSound_232:Stop()
		clearSound_232:Play()
	end
end

-- ── Attribute handler ─────────────────────────────────────────────────────────
local function onWaspAlertChanged_232()
	local active = (player:GetAttribute("WaspAlert") :: boolean?) == true
	if active then
		playAlert_232()
	else
		playAllClear_232()
	end
end

-- ── Init ─────────────────────────────────────────────────────────────────────
task.delay(3, function()
	buildSounds_232()

	-- Wire signal AFTER sounds exist
	player:GetAttributeChangedSignal("WaspAlert"):Connect(onWaspAlertChanged_232)

	-- Apply current state in case alert is already active on join
	local active = (player:GetAttribute("WaspAlert") :: boolean?) == true
	if active then playAlert_232() end
end)
```

---

## Step 2 — Wire into ClientMain

Open **StarterPlayerScripts → ClientMain** and add:

```lua
require(script.Parent:WaitForChild("WaspAlertSoundController"))
```

---

## Step 3 — Audio asset notes

The two SoundIds above reference free Roblox audio assets. If either fails to load (white "!" icon in Properties), replace with alternatives from the Toolbox:

| Slot | Search term | Characteristic |
|---|---|---|
| Alert sting | "wasp buzz", "bee attack", "insect sting" | Short (< 2s), sharp onset, high frequency |
| All-clear | "chime", "ding", "soft bell", "relief" | Short (< 2s), pleasant resolution tone |

You can also use any SoundId from the existing D118 audio setup if there is a suitable sharp or resolution sound already loaded in the game.

---

## Step 4 — Verification sweep

Run in **Studio Command Bar** (in Play mode):

```lua
local SPS = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local c = SPS and SPS:FindFirstChild("WaspAlertSoundController")
print("WaspAlertSoundController:", c and c.ClassName or "MISSING")

-- Check sounds were created in PlayerGui
local lp = game:GetService("Players").LocalPlayer
local pg = lp:WaitForChild("PlayerGui")
print("WaspAlertSting_232:", pg:FindFirstChild("WaspAlertSting_232") ~= nil)
print("WaspAllClear_232:", pg:FindFirstChild("WaspAllClear_232") ~= nil)

-- Simulate wasp alert trigger
lp:SetAttribute("WaspAlert", true)
task.wait(1)
print("Alert should have played")
lp:SetAttribute("WaspAlert", false)
task.wait(1)
print("All-clear should have played")

local count = 0
for _, p in game:GetService("Workspace"):GetDescendants() do
	if p:IsA("BasePart") then count += 1 end
end
print("Total parts:", count, "(expect 4218)")
```

---

## Behaviour summary

| WaspAlert change | Sound played | Cooldown |
|---|---|---|
| false → true | Alert sting (sharp buzz, pitch 1.15) | 4s — prevents spam |
| true → false | All-clear chime (soft, pitch 0.92) | 2s |
| Join during active alert | Alert sting plays immediately | — |
| Rapid toggle within cooldown | Suppressed | — |

- Volume 0.65 for alert (audible but below voice / core SFX ceiling 0.7 from quality criteria)
- Volume 0.35 for all-clear (softer — relief should not startle)
- Sounds parented to PlayerGui, not workspace, so no spatial rolloff — heard at full volume regardless of player position
- Cooldown uses `os.clock()` monotonic — unaffected by task.wait drift
- Works alongside WaspAlertController HUD panel (D221 / existing) — both fire from the same attribute signal

**Part budget: +0 server-side permanent → 4,218 / 5,000**
*(Sound objects in PlayerGui — no BaseParts)*
