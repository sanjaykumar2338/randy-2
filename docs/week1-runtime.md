# Week 1 Playable Runtime Runbook

Status: **PASS — Week 1 playable foundation completed. Two-player voice communication remains a separate multiplayer acceptance test requiring a second player.**

The Windows 11 AMD64 workstation has a supported database, an Enhanced FXServer, a configured txAdmin profile, and a minimum Qbox-derived resource set running on local-only endpoints. Evidence covers installation, manifests, configuration, dependency order, SQL import, oxmysql connectivity, required resource startup, HTTP endpoints, in-game single-client gameplay, normal reconnect persistence, and controlled txAdmin restarts. The 2026-08-22 restart rerun reloaded character `ER26B064`; its inventory retained `water` x2, cash remained 500, and the pre-restart bank balance of 5050 persisted. The earlier 5040 expectation was stale because the configured civilian paycheck adds 10 to bank every 10 minutes while the character is online. The separate two-player voice acceptance test remains.

Repository root: `C:\xampp\htdocs\randy-2`.

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
| FXServer | Enhanced build `b127` in ignored `server-binaries/` | Gameplay server, TCP/UDP `127.0.0.1:30120`, and txAdmin restart verified |
| txAdmin | Configured profile bound to `127.0.0.1:40120` | HTTP reachability and controlled restart verified |
| Qbox data | Minimum pinned stack in ignored `runtime/qbox-server-data/` | All required resources and oxmysql runtime connection verified |
| GTA/FiveM gameplay | GTA V Enhanced and FiveM Enhanced | Character creation/load, spawn, HUD, movement, camera, jump, chat, and inventory tested in game |

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

The staged tree also includes the required Cfx default resources and reserves `[tarrant]` for future project resources. The namespace currently contains documentation only, so it is intentionally not started as a resource category. Official upstream `AvarianKnight/pma-voice` version 7.0.1 (commit `6c9d96ed7a02e30912f1a0ce92629bf9afbbca8c`) is installed in the ignored runtime with a Qbox-compatible `voice.cfg`. `runtime-manifest.json` records the pinned core sources and archive hashes.

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

## Week 1 Acceptance Results

| Check | Result | Evidence boundary |
| --- | --- | --- |
| Core gameplay path | PASS | Tested in game: character creation/appearance save, selection/load, spawn, HUD, movement, camera, jump, chat, and inventory |
| Voice resource installed/configured | PASS | Official `pma-voice` upstream source and Qbox-compatible configuration |
| Voice resource runtime | PASS | Server starts the resource cleanly; one client initialized its Realtek microphone without repeating voice errors |
| Two-player voice | REQUIRES SECOND PLAYER | Not claimed from a single-client session |
| Inventory item persistence | PASS | Existing `water` item, quantity 2, verified in ox_inventory in game and retained after normal reconnect; matching database inventory state confirmed |
| Normal reconnect persistence | PASS | Same character returned through the character screen and retained the tested inventory state |
| Money and character state | PASS | Cash 500 and the pre-restart bank balance 5050 persisted; the subsequent 5060 value matched one configured $10 civilian paycheck after reconnect |
| Controlled FXServer restart | PASS | txAdmin recorded `RESTART SERVER` at 2026-08-22 21:42:43; the FXServer PID changed, oxmysql reconnected, ox_inventory loaded 301 items, and pma-voice started |
| Post-restart character load | PASS | Qbox logged character `ER26B064` successfully loaded at 2026-08-22 21:56:00 |
| Post-restart persistence assertion | PASS | MariaDB retained `water` x2, cash 500, character state and position, and the authoritative pre-restart bank balance of 5050 |

The post-restart client session completed and loaded the expected character. The bank investigation found no restart or reconnect duplication: 5050 was last persisted at 2026-08-21 23:55:18, before the 2026-08-22 restart. Qbox then made the expected server-wide paycheck transition to 5060 at 2026-08-22 22:02:53. The character is an on-duty unemployed `Freelancer` with payment 10; `qbx_core` runs the paycheck loop every 10 minutes and deposits it into bank.

## Error Review

- No critical Qbox, oxmysql, ox_inventory, or pma-voice startup errors were found after the controlled restart.
- `SetTextChatEnabled is not implemented yet` is an upstream Enhanced Early Access warning; chat continued to function in game.
- Public server-list/heartbeat requests can fail in the intentional local-only configuration. They do not affect localhost gameplay and are nonblocking.
- Enhanced native deprecation and available-server-build notices are nonblocking Week 1 warnings.

## Separate Multiplayer Acceptance Test

1. Connect a second player and verify actual proximity/radio voice communication. This is a multiplayer acceptance test and must not be inferred from one client.

## Backup And Restore

Run `scripts\backup-dev.ps1` to create a timestamped backup under ignored `artifacts\backups`. It includes redacted operational configuration, `[tarrant]` resources, and a private SQL dump while excluding `.env`, environment-specific `*.private.cfg`, license keys, passwords, and txAdmin credentials. Stop FXServer and take a fresh backup before restoring; then review/copy configuration and resources and import the SQL using ignored local `.env` credentials. Each backup includes `RESTORE.txt`.

The Week 1 playable foundation is complete. Post-restart character loading and persistence passed. Two-player voice communication remains explicitly untested and is tracked separately because it requires a second player.

## Secondary Unix Helpers

The original Bash paths remain available for a separate supported Linux host:

```bash
scripts/setup-dev-db.sh
scripts/check-env.sh
scripts/check-qbox-readiness.sh
```

Download the then-current Linux FXServer artifact rather than copying the Windows binary tree.
