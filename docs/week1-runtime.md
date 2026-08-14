# Week 1 Playable Runtime Runbook

Status: `PARTIAL — SERVER RUNTIME HEALTHY, GAMEPLAY TESTS PENDING`.

The Windows 11 AMD64 workstation has a supported database, current server binaries, a configured txAdmin profile, and a minimum Qbox-derived resource set running on local-only endpoints. Evidence covers installation, manifests, configuration, dependency order, SQL import, oxmysql connectivity, required resource startup, HTTP endpoints, and a controlled clean restart. FiveM gameplay and persistence remain untested.

Repository root: `C:\xampp\htdocs\myworkplace\randy-2`.

## Official Sources

- [Qbox installation requirements](https://docs.qbox.re/installation)
- [Official Qbox txAdmin recipe repository](https://github.com/Qbox-project/txAdminRecipe)
- [FiveM server setup](https://docs.fivem.net/docs/getting-started/setup-fivem-server/)
- [Vanilla FXServer setup](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/)
- [txAdmin](https://docs.fivem.net/docs/resources/txAdmin/)
- [Windows artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/)
- [Linux artifacts](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)

## Installed State

| Area | Current local state | Verification boundary |
| --- | --- | --- |
| Database | Standalone MariaDB 12.3.2, service `TarrantMariaDB`, automatic start, loopback `127.0.0.1:3306` | Service/version/app-user connection and SQL import verified |
| Legacy XAMPP | MariaDB 10.4 retained but stopped | Unsupported by Qbox; must not share port 3306 |
| FXServer | Windows recommended build `25770` in ignored `fxserver/` | Gameplay server and TCP/UDP `127.0.0.1:30120` verified |
| txAdmin | Configured profile bound to `127.0.0.1:40120` | HTTP reachability and controlled restart verified |
| Qbox data | Minimum pinned stack in ignored `runtime/qbox-server-data/` | All required resources and oxmysql runtime connection verified |
| FiveM/gameplay | Client not yet available for this acceptance run | Connection, character, spawn, inventory, money, reconnect, and restart persistence untested |

## Database

The supported runtime uses:

```text
Service:  TarrantMariaDB
Server:   MariaDB 12.3.2
Address:  127.0.0.1:3306
Database: tarrant_rp_dev
User:     tarrant_rp
```

The dedicated application user has project-database privileges rather than global administrative access. Its password and the separate local admin password are generated/stored in ignored `.env`; never place either value in a tracked config or command transcript.

Check the service and connection without exposing secrets:

```powershell
Get-Service TarrantMariaDB
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
```

XAMPP remains installed for unrelated projects. Leave its MySQL/MariaDB module stopped while `TarrantMariaDB` owns port 3306. Qbox does not support the XAMPP database distribution even if its port is changed.

## Runtime-Verified Minimum Qbox Stack

The runtime installer derives a deliberately small Week 1 subset from official Qbox recipe inputs and pins released artifacts:

| Resource | Version |
| --- | --- |
| `qbx_core` | 1.23.0 |
| `qbx_vehicles` | 1.4.2 |
| `qbx_spawn` | 0.1.1 |
| `qbx_hud` | 0.1.0 |
| `ox_lib` | 3.39.0 |
| `oxmysql` | 2.14.1 |
| `ox_target` | 1.18.1 |
| `ox_inventory` | 2.47.9 |
| `illenium-appearance` | 5.7.0 |

The staged tree also includes the required Cfx default resources and reserves `[tarrant]` for future project resources. The namespace currently contains documentation only, so it is intentionally not started as a resource category. Voice is intentionally deferred. `runtime-manifest.json` records the pinned sources and archive hashes.

The runtime startup order is explicit: Cfx defaults, `ox_lib`, `oxmysql`, `qbx_core`, `qbx_vehicles`, `ox_target`, `ox_inventory`, `qbx_spawn`, `illenium-appearance`, then `qbx_hud`. Add `ensure [tarrant]` only after the namespace contains at least one valid resource with an `fxmanifest.lua`; otherwise FXServer reports a missing resource category. `qbx_vehicles` is required by the current Qbox bridge in `ox_inventory`. OneSync is enabled and both game endpoints are loopback-only for local Week 1 testing.

The minimum profile also applies the required temporary development identity, disables Qbox's optional apartment-first spawn and Discord rich presence, removes starter ID-card callbacks whose optional resources are not installed, limits character cleanup to installed schemas, and normalizes a few official-recipe inventory names to items that are actually present. These narrow overrides avoid half-completed character creation while keeping the standard Qbox character, spawn, inventory, and money paths.

Base Qbox and `qbx_core` SQL were already imported. Do not point txAdmin's official Qbox recipe at this same database/server-data tree; recipe SQL includes seed operations that can fail or collide when repeated. `install-qbox-runtime.ps1` is likewise intended for a new empty destination and refuses to overwrite the staged runtime.

## Validation Commands

Run from the repository root. The explicit bypass affects only the launched Windows PowerShell process:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-qbox-readiness.ps1
```

After adding the Cfx.re key to ignored `.env`, regenerate only the ignored local runtime configuration:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-qbox-runtime.ps1 -ConfigureOnly
```

## Remaining Manual Actions

1. Install/launch FiveM with a licensed, updated GTA V copy on this workstation.
2. Connect locally to `127.0.0.1:30120` and execute `docs/week1-test-plan.md`.

Week 1 becomes complete only after character creation, spawn, inventory, money, reconnect, and full server-restart persistence checks all pass.

## Secondary Unix Helpers

The original Bash paths remain available for a separate supported Linux host:

```bash
scripts/setup-dev-db.sh
scripts/check-env.sh
scripts/check-qbox-readiness.sh
```

Download the then-current Linux FXServer artifact rather than copying the Windows binary tree.
