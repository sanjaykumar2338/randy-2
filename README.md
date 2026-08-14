# Tarrant RP

Commercial FiveM lifestyle/economy RP server foundation built on Qbox.

The Windows 11 AMD64 Week 1 server runtime is operational, but it is not yet gameplay-verified. The supported standalone database, FXServer, txAdmin profile, and minimum pinned Qbox-derived server-data tree are running locally. FiveM client installation and the in-game acceptance tests still require manual account/client interaction.

## Current Windows Runtime

- Repository root: `C:\xampp\htdocs\myworkplace\randy-2`
- MariaDB 12.3.2 runs as the automatic Windows service `TarrantMariaDB`, bound to `127.0.0.1:3306`.
- Database `tarrant_rp_dev` and dedicated application user `tarrant_rp` are configured; credentials remain only in the ignored local `.env`.
- FXServer recommended build `25770` is extracted under ignored `fxserver/`.
- Bundled txAdmin is configured and reachable only on `127.0.0.1:40120`.
- A minimum official-release Qbox stack runs under ignored `runtime/qbox-server-data/`; its required resources, oxmysql connection, and base/core/vehicle schemas are verified.
- XAMPP is retained for unrelated local work, but its MariaDB 10.4 instance is stopped and unsupported by Qbox. Do not start XAMPP MySQL while `TarrantMariaDB` is using port 3306.

Runtime verification covers downloads, manifests, configuration, dependency order, database connectivity, required resource startup, loopback endpoints, and a controlled server restart. Character, inventory, money, reconnect, and persistence flows still require a FiveM client test.

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
- A licensed GTA V installation and FiveM client for gameplay testing
- Node.js/npm only when rebuilding resource web assets; the staged releases are prebuilt

Qbox explicitly does not support XAMPP as its runtime database.

## Windows Commands

The workstation execution policy is restricted, so invoke tracked scripts with an explicit per-process bypass from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-qbox-readiness.ps1
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

## Next Manual Gate

Install FiveM with a licensed, updated GTA V copy on this same workstation, connect to `127.0.0.1:30120`, and complete the Week 1 gameplay/persistence test plan. The game endpoints intentionally remain loopback-only.

See `docs/fxserver.md`, `docs/week1-runtime.md`, and `docs/week1-test-plan.md` for the runtime flow and acceptance criteria.

## Security

Never commit Cfx.re keys, database/admin passwords, Discord credentials, Tebex secrets, private database exports, downloaded binaries, txAdmin state, or generated runtime data. Tracked `*.example.*` files contain placeholders only; real values belong in ignored `.env`, `development.cfg`, or txAdmin files.
