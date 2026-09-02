# Windows Staging Deployment

This runbook deploys Phase 1 to a fresh Windows Server under `C:\FiveM\TarrantRP`. It does not copy local runtime, txData, credentials, or backups.

## A. Prepare Windows

Run Windows PowerShell as Administrator:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        winget install --id Git.Git --exact --scope machine --silent --accept-source-agreements --accept-package-agreements
    } else {
        $release = Invoke-RestMethod https://api.github.com/repos/git-for-windows/git/releases/latest
        $asset = $release.assets | Where-Object name -Match '^Git-.*-64-bit\.exe$' | Select-Object -First 1
        Invoke-WebRequest $asset.browser_download_url -OutFile "$env:TEMP\git-installer.exe"
        if ((Get-AuthenticodeSignature "$env:TEMP\git-installer.exe").Status -ne 'Valid') { throw 'Git installer signature invalid.' }
        Start-Process "$env:TEMP\git-installer.exe" -ArgumentList '/VERYSILENT','/NORESTART' -Wait
    }
}
git --version
```

## B. Clone And Verify

```powershell
New-Item -ItemType Directory -Force C:\FiveM | Out-Null
git clone <REPOSITORY_URL> C:\FiveM\TarrantRP
Set-Location C:\FiveM\TarrantRP
git switch main
git pull --ff-only origin main
git status
git log -1 --oneline
```

Do not embed credentials in `<REPOSITORY_URL>`.

## C. Configure Staging

```powershell
Copy-Item .env.staging.example .env
notepad .env
```

Replace every `CHANGE_ME`. Set the approved name, description, tags and capacity. Keep `DB_HOST=127.0.0.1`, `TXADMIN_BIND_ADDRESS=127.0.0.1`, and `TXADMIN_URL=http://127.0.0.1:40120` for a single-host VPS. `FIVEM_BIND_ADDRESS=0.0.0.0` permits remote testers. Supply a fresh staging Cfx key only in ignored `.env`.

On Linux, after the server-data tree exists, refresh its public identity from the ignored staging `.env` without reading or modifying credentials:

```bash
bash scripts/configure-runtime-identity.sh
```

## D. Install Dependencies And Database

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-vc-redist.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-mariadb.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-dev-db.ps1
Get-Service TarrantMariaDB
```

The MariaDB installer uses winget when present and otherwise downloads the pinned official 12.3.2 x64 MSI and verifies its SHA-256. The setup scripts generate/store passwords in ignored `.env` without printing them and bind MariaDB to loopback.

## E. Install FXServer And Runtime

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-fxserver.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-qbox-runtime.ps1
```

The Windows FXServer installer downloads only the pinned official Enhanced b129 archive and verifies the archive and executable hashes. Linux hosts use the separate `scripts/install-fxserver-linux.sh` installer, which installs the pinned official Enhanced `cfx-server_linux_x64.tar.xz` build 139 side-by-side and refuses to overwrite rollback binaries. Do not substitute the legacy Linux master `fx.tar.xz` build 35245: it is a different product line. The runtime installer fetches the pinned Qbox/OX releases, official pma-voice 7.0.1 source, and project `tarrant_ops`, generates ignored configuration, and imports required schemas. Upstream resources remain untracked; `runtime-manifest.json` records their source versions, commits, URLs, and downloaded archive hashes.

The generated `server.cfg` executes an environment-specific ignored credential file: `development.private.cfg`, `staging.private.cfg`, or `production.private.cfg`. These files contain the scoped database connection and Cfx license directive and must never be tracked or displayed. Shared `base.cfg` is environment-neutral; `server.cfg` is the single source of the `tarrant_environment` marker.

For a runtime created before environment-specific private files were introduced, run `bash scripts/migrate-runtime-environment.sh staging runtime/qbox-server-data` once before restarting. It copies only the existing database and license directives into ignored `staging.private.cfg`, removes stale shared environment markers, and leaves the legacy credential file retained but unloaded.

## F. Firewall

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-staging-firewall.ps1
```

This opens both TCP 30120 and UDP 30120 publicly, blocks public MariaDB, and creates no public txAdmin rule. Both protocols must be reachable from the Internet for normal FiveM connectivity and public listing. For VPN/private admin access only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-staging-firewall.ps1 -TxAdminRemoteAddress <APPROVED_IP_OR_CIDR>
```

## G. Start And Configure Automatic Startup

```powershell
Start-Service TarrantMariaDB
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-txadmin.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-fxserver-startup.ps1 -ProjectRoot C:\FiveM\TarrantRP
```

On first start, open txAdmin locally through an RDP session or an SSH/VPN port-forward to `127.0.0.1:40120`, link the approved Cfx account, create the staging administrator, and select the existing `runtime\qbox-server-data` profile. Never copy development txData.

## H. Health Checks

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-qbox-readiness.ps1 -Environment staging
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-week2-health.ps1 -Environment staging
Get-NetTCPConnection -State Listen -LocalPort 30120,40120,3306
Get-NetUDPEndpoint -LocalPort 30120
Invoke-RestMethod http://127.0.0.1:30120/info.json
Invoke-RestMethod http://127.0.0.1:30120/players.json
```

For a publicly listed staging or production server, no loaded configuration file may contain an active `sv_master1 ""` directive. Commented examples are harmless, but an active directive disables Cfx server-list advertising. After correcting the loaded configuration and restarting FXServer, allow several minutes for the server to appear in the public list.

## I. Remote Acceptance

From a FiveM Enhanced client:

```text
connect <STAGING_PUBLIC_IP>:30120
```

Validate character selection, spawn, HUD, inventory, money, voice foundation, clean disconnect/reconnect persistence, an authenticated txAdmin restart, and final reconnect persistence. Two-player voice still requires a second tester.

## J. Backup

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\backup-dev.ps1 -DestinationRoot D:\TarrantRP-Backups
```

Use a dedicated restricted volume or approved backup path, then copy encrypted backups off-host or take provider snapshots. Never seed staging with local development backups.

## K. Rollback

Before deployment changes, record the current commit and take a backup. Roll back by checking out a reviewed earlier commit in a new branch or using `git revert`; never force-push or rewrite history. Validate a backup first, restore only to the reviewed staging database, then restart through txAdmin or the startup task and rerun all health checks.

```powershell
git log --oneline -10
git revert <BAD_DEPLOYMENT_COMMIT>
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\restore-dev.ps1 -BackupPath <BACKUP_PATH>
Restart-ScheduledTask -TaskName TarrantRP-FXServer-Staging
```

## Removal

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\remove-fxserver-startup.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure-staging-firewall.ps1 -Remove
```

## Required Inputs

DevOps supplies the Windows Server version, vCPU/RAM/storage, public IP, Administrator access, provider firewall access, optional DNS, approved admin CIDR/VPN, and off-host backup capability. The project owner supplies the staging Cfx registration/key, approved identity/capacity, tester access policy, and Discord credentials only if staging Discord integration is deliberately enabled.
