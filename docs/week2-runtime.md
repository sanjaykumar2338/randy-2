# Week 2 Operations Foundation

Status: **PASS — local operational/server-management foundation completed. Production Discord authorization and multiplayer validation remain deployment tasks.**

Week 2 builds on the accepted Week 1 gameplay runtime without adding economy, dealership, housing, business, or map systems. Project-owned operational code lives in `resources/[tarrant]/tarrant_ops`; upstream Qbox/OX resources were not edited.

## Configuration Organization

The generated runtime loads configuration in this order:

1. ignored `development.cfg` and `voice.cfg` for credentials and local settings;
2. tracked-template-derived `base.cfg` and `security.cfg`;
3. `discord.cfg`, `permissions.cfg`, and ignored `staff.cfg`;
4. upstream-derived `ox.cfg`;
5. explicit resource startup order; and
6. upstream-derived `misc.cfg`.

Only `*.example.cfg` files are tracked. Real identifiers, keys, webhook URLs, and passwords remain ignored. `install-qbox-runtime.ps1 -ConfigureOnly` refreshes public configuration and project resources but preserves an existing local `staff.cfg`.

## Staff And Discord Foundation

`permissions.example.cfg` defines inherited owner, admin, moderator, support, and whitelist ACE groups. The local development operator was granted owner through an ignored license identifier in `staff.cfg`; the identifier is intentionally absent from documentation and backups.

`discord.example.cfg` reserves guild and role identifiers for the same hierarchy. Discord delivery and whitelist enforcement default to disabled, so missing production credentials cannot lock developers out. Enabling role synchronization requires a reviewed Discord application/bot or role bridge in a deployment phase; a webhook alone cannot securely authorize roles.

## Operational Logging

`tarrant_ops` emits single-line structured JSON events to the FXServer log for connections, joins, leaves, character load/unload, job and money changes, project-resource lifecycle, readiness results, whitelist denials, and project administrative commands. Identifiers are reduced to a type and six-character suffix. txAdmin continues to provide its native authenticated audit log for server lifecycle and administrative console activity.

The resource provides:

- `tarrant_health`, usable by the server console or staff with `tarrant.support`;
- `tarrant_admin_note <text>`, an ACE-protected structured audit note; and
- optional Discord webhook forwarding, disabled until a secret webhook is configured locally.

## Security Boundary

Development game, txAdmin, and MariaDB listeners remain loopback-only. Script hooks and development mode are disabled. Networked sound, phone-explosion, and script-entity-state exposure are disabled, and request-control filtering is enabled. JSON health endpoints remain available on loopback for readiness automation. Production must replace loopback binding deliberately and separately review firewall, TLS/reverse-proxy, txAdmin accounts, Discord authorization, and secrets.

## Backup And Restore

Create a backup:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup-dev.ps1
```

Validate it without changing anything:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore-dev.ps1 -BackupPath .\artifacts\backups\<timestamp>
```

After review, restore only into an explicitly named database:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore-dev.ps1 -BackupPath .\artifacts\backups\<timestamp> -Apply -TargetDatabase tarrant_rp_restore_review
```

Backups include redacted operational configuration, project resources, a MariaDB dump, restore instructions, and a SHA-256 manifest. They exclude `.env`, `development.cfg`, txAdmin state, passwords, license keys, and webhook secrets. Config and resources remain review-and-copy operations; the restore script never overwrites the live runtime.

## Health Check

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-week2-health.ps1
```

The check verifies the MariaDB service, loopback listeners, FXServer and txAdmin HTTP endpoints, required resources, and the structured startup readiness event.

## Validation Evidence

On 2026-08-22, controlled txAdmin restarts loaded `oxmysql`, `qbx_core`, `ox_inventory`, `pma-voice`, and `tarrant_ops`. MariaDB connected, inventory loaded 301 items, and the final `health.startup` event reported the database and every required resource healthy. No critical startup errors were introduced; intentional local-only public-list failures and Enhanced deprecation/build notices remain nonblocking.

A backup was checksum-validated and imported into an isolated temporary database. The restored database had 14 tables and retained character `ER26B064`, cash 500, `water` x2, metadata, and position. Its bank balance followed the already-documented $10 civilian paycheck behavior. The temporary verification database was removed after validation; live application data was not changed.

## Week 2 Results

| Area | Result | Evidence boundary |
| --- | --- | --- |
| Staff system and permissions | PASS | Hierarchical ACE model, ignored local owner grant, protected operational commands |
| Discord integration foundation | PASS | Disabled-by-default guild/role/webhook configuration and whitelist preparation; production authorization intentionally deferred |
| Operational/admin logging | PASS | Structured project events plus txAdmin administrative audit trail |
| Development security | PASS | Loopback services and hardened runtime convars; local health access preserved |
| Backup/restore | PASS | Redacted backup, checksums, non-mutating validation, and isolated full database restore tested |
| Configuration separation | PASS | Base/security/Discord/permissions/staff/secrets separated; local staff grants preserved on regeneration |
| Startup/dependency review | PASS | Explicit order validated; upstream resources left untouched; required resources started cleanly |
| Health/readiness | PASS | Service, port, HTTP, resource, database, and structured startup checks |
| Week 1 regression | PASS | Existing character, cash, inventory, metadata/position, and known paycheck behavior retained |
| Documentation | PASS | Installation, configuration, testing, restore, security, and deferred deployment work recorded here |

## Manual Deployment Actions

No manual action blocks the local Week 2 foundation. Before production Discord integration, Randy/Sanjay must create or authorize the Discord application, choose the guild and staff/whitelist roles, place real IDs/secrets only in ignored configuration, and approve enabling role synchronization/whitelist enforcement. A second player is still required only for the separately tracked multiplayer voice test.
