# FXServer Development Notes

The original local Phase 1 gameplay acceptance used Enhanced FXServer `b127`. Legacy artifact `25770` is a different, non-Enhanced line and is not the deployment target. Because Cfx no longer exposes b127 through its official resolver, the tracked artifact manifest pins official Enhanced `b129`, which passed the full server-side Phase 1 readiness suite on 2026-08-24. Archives and extracted binaries remain ignored.

Official references:

- [Setting up a FiveM server](https://docs.fivem.net/docs/getting-started/setup-fivem-server/)
- [Setting up a vanilla FXServer](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/)
- [txAdmin documentation](https://docs.fivem.net/docs/resources/txAdmin/)
- [Windows artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/)
- [Linux artifacts](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)

## Local Windows Layout

All generated/downloaded paths are ignored by Git:

```text
randy-2/
  fxserver/                  # build 25770, including FXServer.exe
  runtime/qbox-server-data/ # staged existing server-data
  runtime/*.log             # local setup/startup evidence
  txData/                   # txAdmin profiles and credentials
```

The repository root on the staged workstation is `C:\xampp\htdocs\randy-2`.

txAdmin is bundled with FXServer; no separate txAdmin download is required. It was smoke-tested with its interface restricted to loopback and returned HTTP 200 at `http://127.0.0.1:40120`.

Start the txAdmin host from the repository root with the Windows helper:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-txadmin.ps1
```

The helper sets current `TXHOST_*` values for loopback-only txAdmin/game ports, uses ignored `txData/`, protects local txAdmin/log ACLs, and waits for HTTP readiness. This starts txAdmin, not a verified Qbox gameplay session. Do not bind txAdmin publicly for local development.

## First-Run Onboarding

Retrieve the current one-time PIN locally without copying it into chat:

```powershell
Select-String -LiteralPath .\runtime\fxserver.stdout.log -Pattern 'Use this PIN' | Select-Object -Last 1
```

Open `http://127.0.0.1:40120`, enter the locally displayed PIN, link the intended Cfx.re account, set the local backup password, and use the existing ignored development license configuration. Account linking and browser confirmation cannot be automated safely. Treat the PIN, backup password, and license key as secrets.

The Qbox files and database schema are already staged. In txAdmin's deployer, choose the existing-server-data workflow, use `C:\xampp\htdocs\randy-2\runtime\qbox-server-data` as the data directory, and select `server.cfg`. Do not deploy the official Qbox recipe into `tarrant_rp_dev`: a second recipe import can collide with previously seeded rows.

Before starting the server profile, refresh ignored configuration after placing the key in `.env`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-qbox-runtime.ps1 -ConfigureOnly
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-qbox-readiness.ps1
```

The generated development runtime `server.cfg` binds the game endpoint to `127.0.0.1:30120`, enables OneSync, loads secrets from ignored `development.private.cfg`, and starts the minimum resources in explicit dependency order. Staging and production use their matching ignored private configuration names.

## Cross-Platform Reference

For a separate Linux host, download the current recommended Linux artifact and keep its binaries/runtime data outside Git. A direct vanilla startup looks like:

```bash
cd /path/to/server-data
/path/to/fxserver/run.sh +exec server.cfg
```

Upstream resources remain outside Git. After staging the Qbox server-data tree on Linux, install the Phase 1 pinned pma-voice dependency with:

```bash
bash scripts/install-pma-voice.sh
bash scripts/configure-runtime-identity.sh
```

The resource helper installs official pma-voice 7.0.1 commit `6c9d96ed7a02e30912f1a0ce92629bf9afbbca8c` under the ignored runtime tree. The identity helper reads only `APP_ENV`, `SERVER_NAME`, `SERVER_DESCRIPTION`, and `SERVER_TAGS` from the ignored `.env` and applies them to runtime `server.cfg`; it does not read or rewrite credentials. Pass the server-data path as the first argument when it is not `runtime/qbox-server-data`.

Use the current official artifact list rather than assuming Windows build `25770` is still recommended for a future rebuild.
