#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BackupPath,
    [switch]$Apply,
    [string]$TargetDatabase
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$backupRoot = (Resolve-Path -LiteralPath $BackupPath).Path
$manifestPath = Join-Path $backupRoot 'MANIFEST.sha256'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Backup MANIFEST.sha256 is missing.' }

foreach ($line in [System.IO.File]::ReadAllLines($manifestPath)) {
    if ($line -notmatch '^(?<hash>[a-f0-9]{64})  (?<path>.+)$') { throw "Invalid manifest line: $line" }
    $file = Join-Path $backupRoot $matches.path.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Backup file is missing: $($matches.path)" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $matches.hash) { throw "Checksum mismatch: $($matches.path)" }
}

$dump = Get-ChildItem -LiteralPath (Join-Path $backupRoot 'database') -Filter '*.sql' -File | Select-Object -First 1
if (-not $dump) { throw 'Backup database dump is missing.' }
if ([System.IO.File]::ReadAllText($dump.FullName) -notmatch '(?i)CREATE TABLE.*`players`') { throw 'Database dump does not contain the required players table.' }

if (-not $Apply) {
    Write-Host "[ok] Backup checksums and required database schema validated: $backupRoot"
    Write-Host '[info] No files or database data were changed. Use -Apply with a reviewed target database to restore.'
    exit 0
}

if (-not $TargetDatabase -or $TargetDatabase -notmatch '^[A-Za-z0-9_]+$') { throw '-Apply requires a safe -TargetDatabase name.' }
$settings = @{}
foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $repositoryRoot '.env'))) {
    if ($line -match '^\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') { $settings[$matches.name] = $matches.value.Trim().Trim('"').Trim("'") }
}
foreach ($required in @('DB_HOST', 'DB_PORT', 'DB_ADMIN_USER', 'DB_ADMIN_PASSWORD')) {
    if (-not $settings[$required]) { throw "$required is required in ignored .env for restore." }
}
$client = Get-ChildItem -Path "$env:ProgramFiles\MariaDB *\bin\mariadb.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $client) { throw 'Standalone MariaDB client was not found.' }
$hadPassword = Test-Path Env:\MYSQL_PWD
$oldPassword = $env:MYSQL_PWD
try {
    $env:MYSQL_PWD = $settings.DB_ADMIN_PASSWORD
    $sql = "CREATE DATABASE IF NOT EXISTS ``$TargetDatabase`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    $sql | & $client.FullName --host=$($settings.DB_HOST) --port=$($settings.DB_PORT) --user=$($settings.DB_ADMIN_USER)
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create restore target database.' }
    Get-Content -LiteralPath $dump.FullName -Raw | & $client.FullName --host=$($settings.DB_HOST) --port=$($settings.DB_PORT) --user=$($settings.DB_ADMIN_USER) $TargetDatabase
    if ($LASTEXITCODE -ne 0) { throw 'Database restore failed.' }
}
finally {
    if ($hadPassword) { $env:MYSQL_PWD = $oldPassword } else { Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue }
}
Write-Host "[ok] Database restored into reviewed target: $TargetDatabase"
Write-Host '[info] Config/resources remain review-and-copy operations; secrets are intentionally absent.'
