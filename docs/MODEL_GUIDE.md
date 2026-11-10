# Model guide – vanilla GTA V props only

This resource uses **existing GTA V / FiveM props**. No custom `.ydr` / `.ytd` / stream assets are required.

## Default model

```lua
Config.Model = `prop_consign_02a`
```

Compact portable roadside stand. LED board is drawn by the script (no vanilla LED trailer exists).

Speed digits and emergency lights are drawn by the script (`DrawText` + `DrawLightWithRange`) using `Config.Offsets`, so the mesh only needs to look like a roadside unit.

---

## How to swap models

1. Open `config.lua`
2. Set `Config.Model` to another prop name
3. Copy matching offsets from `Config.ModelAlternatives` into `Config.Offsets`
4. Restart the resource (`ensure radar_trailer`)

Example – use the large sign:

```lua
Config.Model = `prop_sign_big_01`

Config.Offsets = {
    display   = vector3(0.0, 0.0, 1.60),
    redLight  = vector3(-0.50, 0.0, 0.40),
    blueLight = vector3( 0.50, 0.0, 0.40),
    radar     = vector3(0.0, 0.15, 1.80),
}
```

---

## Built-in alternatives

| Key | Prop | Notes |
|-----|------|--------|
| `consign_02a` | `prop_consign_02a` | **Default** – portable frame sign |
| `consign_01a` | `prop_consign_01a` | Alternate construction sign |
| `sign_big_01` | `prop_sign_big_01` | Larger freestanding sign |
| `callbox` | `prop_sign_road_callbox` | Roadside equipment / callbox style |
| `trafficdiv_01` | `prop_consign_02a` | Traffic diversion board |
| `traffic_01a` | `prop_traffic_01a` | Traffic light (legacy / last resort) |

All of these are base-game props and spawn with `CreateObject` in FiveM.

---

## Finding another prop

Useful places to browse vanilla props:

- https://gtahash.ru (search sign, consign, traffic)
- https://gtax.dev/browser/props
- CodeWalker object list

When you find one you like:

1. Confirm it streams in FiveM (`IsModelInCdimage` / spawn test)
2. Set `Config.Model = \`prop_name_here\``
3. Stand in front of a placed unit and adjust `Config.Offsets` until the speed text sits on the board face and lights sit at the base

---

## What the script does vs the prop

| Responsibility | Owner |
|----------------|--------|
| Mesh appearance | Vanilla prop (`Config.Model`) |
| Spawn / freeze / rotate / delete | Script |
| Live speed numbers | Script (3D text at Offsets.display) |
| Red/blue flash | Script (lights at Offsets.redLight / blueLight) |
| Detection cone | Script (independent of mesh) |

No stream folder, no ytyp, no Blender step is required for normal use.
