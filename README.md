# Tarrant RP

Commercial FiveM lifestyle/economy RP server foundation built on Qbox.

Phase 1 is complete on Windows 11 AMD64. The accepted foundation includes the playable Qbox runtime, supported database, Enhanced FXServer, txAdmin operations, inventory and money persistence, voice resource, staff/whitelist architecture, structured logging, security separation, health checks, performance baseline, and validated backup/recovery workflow. Phase 2 economy development may begin without rebuilding this base.

## Current Windows Runtime

- Repository root: `C:\xampp\htdocs\randy-2`
- MariaDB 12.3.2 runs as the automatic Windows service `TarrantMariaDB`, bound to `127.0.0.1:3306`.
- Database `tarrant_rp_dev` and dedicated application user `tarrant_rp` are configured; credentials remain only in the ignored local `.env`.
- The Enhanced FXServer build used for acceptance testing is stored under ignored `server-binaries/`.
- Bundled txAdmin is configured and reachable only on `127.0.0.1:40120`.
- A minimum official-release Qbox stack runs under ignored `runtime/qbox-server-data/`; its required resources, oxmysql connection, and base/core/vehicle schemas are verified.
- XAMPP is retained for unrelated local work, but its MariaDB 10.4 instance is stopped and unsupported by Qbox. Do not start XAMPP MySQL while `TarrantMariaDB` is using port 3306.

Runtime verification covers downloads, manifests, configuration, dependency order, database connectivity, required resource startup, loopback endpoints, a controlled txAdmin restart, and the Week 1 in-game character/spawn/HUD/movement/chat/inventory path. The same character and `water` x2 were verified through normal reconnect; the database retained character, money, metadata, position, and inventory state across the controlled FXServer restart. Two-player voice communication remains a multiplayer acceptance test.

## Repository Layout

```text
config/              Tracked, secret-free FXServer configuration examples
database/            Database documentation and SQL template
docs/                Windows runtime notes and Week 1 acceptance material
resources/[tarrant]/ Project-owned resources copied into the staged runtime
scripts/             PowerShell automation plus secondary Unix helpers
fxserver/            Ignored downloaded FXServer binaries
runtime/             Ignored recipes, server-data, manifests, and logs
txData/              Ignored txAdmin state
```

## Prerequisites

- Windows 11 AMD64, Git, and Windows PowerShell 5.1 or newer
- Standalone MariaDB 10.9 or newer; MariaDB 12.3 LTS is the current Qbox recommendation
- A Cfx.re account and development server license key
- A licensed GTA V installation and a matching FiveM client/server generation for gameplay testing
- Node.js/npm only when rebuilding resource web assets; the staged releases are prebuilt

Qbox explicitly does not support XAMPP as its runtime database.

## Windows Commands

The workstation execution policy is restricted, so invoke tracked scripts with an explicit per-process bypass from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-qbox-readiness.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-week2-health.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-phase1-baseline.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-txadmin.ps1
```

On a fresh Windows host, the repeatable setup entry points are:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-mariadb.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-dev-db.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-qbox-runtime.ps1
```

`install-mariadb.ps1` requests Administrator approval to install/configure the Windows service. `install-qbox-runtime.ps1` is for a fresh, empty runtime destination and imports the base schemas; it deliberately refuses to overwrite the current staged tree. Do not run an official Qbox txAdmin recipe against the already-staged database because its seed SQL is not guaranteed to be idempotent.

The Bash helpers remain available as secondary cross-platform database/readiness tools:

```bash
scripts/setup-dev-db.sh
scripts/check-env.sh
scripts/check-qbox-readiness.sh
```

## Backup And Restore

Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup-dev.ps1` to create a timestamped backup under ignored `artifacts/backups/`. Validate it without mutation with `scripts\restore-dev.ps1 -BackupPath <path>`. Applying a database restore requires both `-Apply` and an explicit safe target database; runtime config/resources are never overwritten automatically.

## Deployment Portability

Tracked scripts derive the repository root from their own location; the Windows development path documented above is acceptance evidence, not a runtime requirement. On each environment, create a fresh ignored `.env` from `.env.example`. Server identity, game bind address/port, txAdmin interface/port, database settings, runtime paths, and credentials are environment configuration and must not be copied from the development machine.

Loopback remains the safe default for local development. A staging operator must deliberately set `FIVEM_BIND_ADDRESS`, firewall rules, and the public/private access model. MariaDB and txAdmin should remain loopback-only when they run on the same host unless a separately reviewed private-network or reverse-proxy design requires otherwise.

## Phase Boundary

Phase 2 may add the planned economy systems while retaining the Phase 1 regression suite. Dealerships, financing, expanded jobs, businesses, housing, government systems, monetization, and Texas map/world work were deliberately not implemented during foundation work. Two-player voice and production Discord authorization remain separate deployment/multiplayer tests.

See `docs/fxserver.md`, `docs/week1-runtime.md`, `docs/week1-test-plan.md`, `docs/week2-runtime.md`, and `docs/week3-phase1-completion.md` for runtime and acceptance evidence.

## Security

Never commit Cfx.re keys, database/admin passwords, Discord credentials, Tebex secrets, private database exports, downloaded binaries, txAdmin state, or generated runtime data. Tracked `*.example.*` files contain placeholders only; real values belong in ignored `.env`, `development.cfg`, or txAdmin files.
