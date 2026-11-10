# Police Radar Speed Trailer (Standalone)

Production-ready standalone FiveM resource for portable roadside police radar / speed display trailers.

**No ESX · No QBCore · No Qbox · No ox_lib · No MySQL**

Version **1.1.0** (post-audit / production polish)

---

## Installation

```
resources/[standalone]/radar_trailer
```

```cfg
ensure radar_trailer
```

### ACE permissions

```cfg
add_ace group.admin radar.admin allow
```

Only players with `radar.admin` can create, edit, delete or reload radars.

---

## Commands

| Command | Description |
|---------|-------------|
| `/radar` | Open management menu |
| `/radarcreate` | Enter placement mode |
| `/radaredit` | Edit nearest radar (≤ 15 m) |
| `/radardelete` | Delete nearest radar |
| `/radarlist` | Request radar list (admin) |
| `/radarreload` | Reload `data/radars.json` from disk |

---

## Placement controls

| Key | Action |
|-----|--------|
| W / A / S / D | Move |
| Q / E | Rotate |
| PageUp / PageDown | Height |
| Shift | Faster move |
| ENTER | Confirm & open config |
| BACKSPACE | Cancel |

Preview object is translucent and is always deleted on confirm/cancel/resource stop.

---

## Detection behaviour

Each radar uses a **directional cone**, not a simple radius:

1. Filter by distance (`range`)
2. Filter by cone (`angle` = full width, half used for math)
3. Filter by lane aim (`direction` offset relative to trailer heading)
4. Optionally require the vehicle to be **approaching** the radar
5. Ignore vehicles below ~4.5 mph (parked / crawling)
6. Rank remaining candidates by distance and lock the best target
7. Keep tracking the same vehicle until it leaves the cone or stops

**State machine** (per radar):

```
IDLE → TARGET_DETECTED → TRACKING → OVERSPEED → PASSED → IDLE
```

Lights and overspeed text follow this machine. When the vehicle leaves the detection/pass zone, lights turn off immediately.

---

## Configuration (`config.lua`)

| Key | Purpose |
|-----|---------|
| `Config.Model` | Vanilla GTA prop hash (default `prop_consign_02a`). |
| `Config.Offsets` | Display / light attachment points relative to the entity. |
| `Config.Display` | Text scale & max draw distance. |
| `Config.Defaults` | Defaults for new radars (limit, range, angle, texts, lights…). |
| `Config.Lights` | RGB colours, range, intensity. |
| `Config.Update` | Adaptive polling intervals (far / near / active). |
| `Config.NearDistance` | Client starts processing radars inside this radius. |
| `Config.MinSpeedToDetect` | m/s threshold to ignore parked vehicles. |
| `Config.SpeedSmoothAlpha` | Display smoothing (0–1). Raw speed is still used for logic. |
| `Config.Limits` | Server-side clamp ranges. |
| `Config.Permission` | ACE string (default `radar.admin`). |
| `Config.Debug` | Draw cones, direction, state labels. |

---

## Light modes

| Mode | Behaviour |
|------|-----------|
| `off` | Never |
| `on_violation` | Only while a tracked vehicle exceeds the limit **and** remains in the cone |
| `always` | Continuously alternating red/blue |

Pattern: RED ↔ BLUE at `flashInterval` ms.

---

## Persistence

All radars are stored in `data/radars.json`.

- Created / updated / deleted → file is rewritten
- Resource start → file is loaded and entities are spawned
- Server restart → same
- Corrupted / missing file → starts empty (no crash)

---

## Model (vanilla props)

Uses base-game props only. Default:

```lua
Config.Model = `prop_consign_02a`
```

Swap via `Config.Model` + `Config.Offsets`. Presets are listed in `Config.ModelAlternatives` and documented in `docs/MODEL_GUIDE.md`.

No stream folder or custom assets required.


## Multiplayer notes

- Server owns configuration and persistence
- Clients near a radar run detection and push state only when values change
- All clients render the same speed / lights / text from the last networked state
- Late joiners receive full sync + live states

---

## Performance

- Adaptive intervals: 2 s far · 400 ms near · 80 ms active
- Only radars within `NearDistance` of the local player are processed
- Vehicle pool is scanned only for those radars
- Network events fire only on meaningful state change

Expected cost for 25–50 radars with a few nearby is modest; most of the time the thread sleeps.

---

## Debug

```lua
Config.Debug = true
```

Shows:

- Detection direction arrow
- Cone edges
- Range samples
- Radar ID, machine state, speed, limit, range, angle

---

## Testing checklist (manual in FiveM)

| Item | Status |
|------|--------|
| Resource starts without errors | NEEDS MANUAL FIVE-M TEST |
| Model loads / fallback works | NEEDS MANUAL FIVE-M TEST |
| Placement preview + confirm/cancel | NEEDS MANUAL FIVE-M TEST |
| Create → configure → save | NEEDS MANUAL FIVE-M TEST |
| Edit existing radar | NEEDS MANUAL FIVE-M TEST |
| Delete radar | NEEDS MANUAL FIVE-M TEST |
| Vehicle inside cone shows speed | NEEDS MANUAL FIVE-M TEST |
| Vehicle outside cone ignored | NEEDS MANUAL FIVE-M TEST |
| Vehicle driving away ignored (when requireApproach) | NEEDS MANUAL FIVE-M TEST |
| Parked vehicle ignored | NEEDS MANUAL FIVE-M TEST |
| Overspeed → lights + text | NEEDS MANUAL FIVE-M TEST |
| Leave cone → lights off | NEEDS MANUAL FIVE-M TEST |
| MPH / KM/H | NEEDS MANUAL FIVE-M TEST |
| Multiple independent radars | NEEDS MANUAL FIVE-M TEST |
| Restart resource → radars restored | NEEDS MANUAL FIVE-M TEST |
| Restart server → radars restored | NEEDS MANUAL FIVE-M TEST |
| Unauthorized player cannot create/edit/delete | NEEDS MANUAL FIVE-M TEST |
| Late joiner sees radars + live state | NEEDS MANUAL FIVE-M TEST |
| Debug cones | NEEDS MANUAL FIVE-M TEST |
| Resource stop → no leftover entities | NEEDS MANUAL FIVE-M TEST |

Static analysis / logic review of the code in this environment: **PASS** for structure, validation, state machine, networking guards, cleanup paths, and NUI data flow.

---

## Known limitations

- Final custom 3D model is not included (placeholder prop used for testing).
- 3D speed text uses `SetDrawOrigin` + DrawText (works with any model; a true screen material on a custom model will look better).
- Lights use `DrawLightWithRange` at configurable offsets. For perfect bone-driven lights on a custom model, extend the light thread.
- Line-of-sight (walls) is not raycasted every tick for performance reasons.

---

## File overview

```
radar_trailer/
├── fxmanifest.lua
├── config.lua
├── client/     main, detection, placement, interaction, debug
├── server/     main, permissions, persistence
├── shared/     utils (cone math, speed, validation)
├── nui/        index.html, style.css, app.js
├── data/       radars.json
```
