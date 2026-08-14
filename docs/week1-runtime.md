# Week 1 Playable Runtime Runbook

Status on this workstation: `PARTIAL`. The repo can be prepared here, but playable FXServer/Qbox testing requires a Windows or Linux runtime host with MariaDB 10.9.0 or newer.

## Current Source Of Truth

- Qbox docs: https://docs.qbox.re/installation
- Qbox txAdmin recipe: https://github.com/Qbox-project/txAdminRecipe
- Qbox stable recipe: https://github.com/Qbox-project/txAdminRecipe/blob/main/qbox-stable.yaml
- FiveM server setup: https://docs.fivem.net/docs/getting-started/setup-fivem-server/
- Vanilla FXServer setup: https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/
- Windows artifacts: https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/
- Linux artifacts: https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/

## Runtime Requirements

- Windows or Linux host for FXServer.
- MariaDB 10.9.0 or newer. Qbox recommends MariaDB 12.3 LTS for new servers.
- Cfx.re account and development license key.
- FiveM client installed on a separate game-capable machine.
- Git, `curl`, an archive extractor, and a MariaDB client.

Do not use XAMPP for Qbox runtime testing.

## Database

Create the project database and application user on the supported runtime host:

```bash
git clone https://github.com/sanjaykumar2338/randy-2.git
cd randy-2
cp .env.example .env
scripts/setup-dev-db.sh
```

If the MariaDB admin account needs credentials:

```bash
MYSQL_ADMIN_USER=root MYSQL_ADMIN_PASSWORD='ADMIN_PASSWORD' scripts/setup-dev-db.sh
```

Keep `.env` local and ignored. Use the existing project database values:

```text
Database: tarrant_rp_dev
User: tarrant_rp
Host: 127.0.0.1
```

## FXServer And txAdmin

Download the latest recommended artifact directly from the official artifact list for the runtime OS. Keep the extracted `server` folder outside Git.

Suggested Linux layout:

```text
~/FXServer/server/      # extracted artifact
~/FXServer/server-data/ # this repository clone
```

Linux startup:

```bash
cd ~/FXServer/server-data
bash ~/FXServer/server/run.sh
```

Suggested Windows layout:

```text
C:\FXServer\server\      # extracted artifact
C:\FXServer\server-data\ # this repository clone
```

Windows startup:

```powershell
cd C:\FXServer\server-data
C:\FXServer\server\FXServer.exe
```

Open txAdmin at `http://localhost:40120` and complete first-run setup. Do not commit txAdmin credentials or generated local config files.

## Qbox Recipe

In txAdmin, deploy the official Qbox recipe:

1. Choose `Popular Recipes`.
2. Select `QBox Framework` or the official `Qbox Stable` recipe if txAdmin offers both.
3. Use the `tarrant_rp_dev` database with the `tarrant_rp` application user.
4. Use `Tarrant County RP - Development` as the temporary server name.
5. Keep license keys and DB passwords in txAdmin/local ignored config only.

The current stable recipe imports base Qbox SQL, downloads released `qbx_core`, `qbx_spawn`, `qbx_vehicles`, Overextended resources including `ox_lib`, `oxmysql`, `ox_inventory`, and configures `inventory:framework "qbx"`.

After deployment, review generated startup order. `ox_lib` and `qbx_core` must start before Qbox resources, and `ox_inventory` must be configured for `qbx`.

## Readiness Check

After recipe deployment, run:

```bash
scripts/check-qbox-readiness.sh
```

This checks the host OS, MariaDB version, project DB connectivity, ignored secret handling, and expected Qbox/ox resource directories.

## Week 1 Acceptance Test

Run the acceptance checks in `docs/week1-test-plan.md`. Do not mark Week 1 complete until FXServer, txAdmin, Qbox, database persistence, client connection, character creation, spawn, inventory, money, reconnect, and server-restart persistence are all actually tested.
