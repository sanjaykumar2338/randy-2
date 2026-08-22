#Requires -Version 5.1

[CmdletBinding()]
param([string]$DestinationRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not $DestinationRoot) { $DestinationRoot = Join-Path $repositoryRoot 'artifacts\backups' }
$backupRoot = Join-Path ([System.IO.Path]::GetFullPath($DestinationRoot)) (Get-Date -Format 'yyyyMMdd-HHmmss')
$configBackup = Join-Path $backupRoot 'config'
$resourceBackup = Join-Path $backupRoot 'resources\[tarrant]'
$databaseBackup = Join-Path $backupRoot 'database'
foreach ($path in @($configBackup, $resourceBackup, $databaseBackup)) { [System.IO.Directory]::CreateDirectory($path) | Out-Null }

$runtimeConfig = Join-Path $repositoryRoot 'runtime\qbox-server-data'
foreach ($name in @('server.cfg', 'base.cfg', 'security.cfg', 'discord.cfg', 'staff.cfg', 'ox.cfg', 'voice.cfg', 'permissions.cfg', 'misc.cfg')) {
    $source = Join-Path $runtimeConfig $name
    if (Test-Path -LiteralPath $source -PathType Leaf) {
        $content = [System.IO.File]::ReadAllText($source)
        $content = [regex]::Replace($content, '(?im)^\s*(?:set\s+)?(?:sv_licenseKey|mysql_connection_string|steam_webApiKey|sv_tebexSecret)\b.*$', '# Redacted from development backup')
        [System.IO.File]::WriteAllText((Join-Path $configBackup $name), $content, [System.Text.UTF8Encoding]::new($false))
    }
}
$customResources = Join-Path $runtimeConfig 'resources\[tarrant]'
if (Test-Path -LiteralPath $customResources -PathType Container) {
    Copy-Item -Path (Join-Path $customResources '*') -Destination $resourceBackup -Recurse -Force -ErrorAction SilentlyContinue
}

$settings = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $repositoryRoot '.env'))) {
    if ($line -match '^\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') { $settings[$matches.name] = $matches.value.Trim().Trim('"').Trim("'") }
}
foreach ($required in @('DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD')) {
    if (-not $settings.ContainsKey($required) -or [string]::IsNullOrWhiteSpace($settings[$required])) { throw "$required is required in the ignored local .env file." }
}
$dumpTool = Get-ChildItem -Path "$env:ProgramFiles\MariaDB *\bin\mariadb-dump.exe", "$env:ProgramFiles\MariaDB *\bin\mysqldump.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $dumpTool) { throw 'A standalone MariaDB dump client was not found.' }
$dumpPath = Join-Path $databaseBackup ($settings.DB_NAME + '.sql')
$hadPassword = Test-Path Env:\MYSQL_PWD
$oldPassword = $env:MYSQL_PWD
try {
    $env:MYSQL_PWD = $settings.DB_PASSWORD
    & $dumpTool.FullName --host=$($settings.DB_HOST) --port=$($settings.DB_PORT) --user=$($settings.DB_USER) --single-transaction --routines --events --result-file=$dumpPath $settings.DB_NAME
    if ($LASTEXITCODE -ne 0) { throw "MariaDB dump failed with exit code $LASTEXITCODE." }
}
finally {
    if ($hadPassword) { $env:MYSQL_PWD = $oldPassword } else { Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue }
}
[System.IO.File]::WriteAllText((Join-Path $backupRoot 'RESTORE.txt'), "This backup excludes .env, development.cfg, txAdmin state, license keys, and passwords.`r`nStop FXServer and make a fresh backup before restoring. Review and copy config/resources, then import the SQL dump using ignored local .env credentials.`r`n", [System.Text.UTF8Encoding]::new($false))
$manifest = foreach ($file in Get-ChildItem -LiteralPath $backupRoot -Recurse -File | Where-Object Name -ne 'MANIFEST.sha256') {
    $relative = $file.FullName.Substring($backupRoot.Length + 1).Replace('\', '/')
    '{0}  {1}' -f (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
}
[System.IO.File]::WriteAllLines((Join-Path $backupRoot 'MANIFEST.sha256'), $manifest, [System.Text.UTF8Encoding]::new($false))
Write-Host "[ok] Development backup created: $backupRoot"
Write-Host '[ok] Secrets and txAdmin credentials were excluded; the private database dump remains under ignored artifacts/'
