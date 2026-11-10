# Permissions

## Default (recommended)

```lua
Config.PermissionMode = 'any'
```

Allows:
- Players with a **police job** (see `Config.PoliceJobs`)
- **Admins** (framework admin / superadmin / common ACE)
- Optional ACE `radar.admin` if you still want it

**No server.cfg ACE lines required** for police officers.

## Modes

| Mode   | Who can use                          |
|--------|--------------------------------------|
| `open` | Everyone                             |
| `job`  | Police jobs + admins                 |
| `ace`  | Only ACE `radar.admin`               |
| `any`  | Police job **or** ACE **or** admin   |

## Police jobs

```lua
Config.PoliceJobs = {
    'police', 'lspd', 'bcso', 'sasp', 'sheriff', 'state', 'trooper', 'fib', 'leo',
}
```

Add your server’s job name if it’s different.

Supports **QBCore / Qbox / ESX** automatically when those resources are running.
Standalone servers with no framework: use `Config.PermissionMode = 'open'` or set ACE.

## Admins

Always allowed when:
- ESX group is `admin` / `superadmin` / `god`
- QBCore permission is `admin` / `god`
- Player has ACE `command`, `admin`, `group.admin`, or `radar.admin`

## Debug

```
radarpermcheck <serverId>
```

Server console prints job, framework, admin flag, and allow/deny.

## Optional ACE (not required)

```
add_ace group.admin radar.admin allow
add_principal identifier.license:XXXX group.admin
```
