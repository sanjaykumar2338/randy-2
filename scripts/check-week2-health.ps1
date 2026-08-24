#Requires -Version 5.1
[CmdletBinding()]
param([string]$Environment, [int]$GamePort, [int]$TxAdminPort)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$settings = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $repositoryRoot '.env'))) {
    if ($line -match '^\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') { $settings[$matches.name] = $matches.value.Trim().Trim('"').Trim("'") }
}
if (-not $Environment) { $Environment = if ($settings.ContainsKey('APP_ENV')) { $settings.APP_ENV } else { 'development' } }
$Environment = $Environment.ToLowerInvariant()
if ($Environment -notin @('development','staging','production')) { throw 'Environment must be development, staging, or production.' }
if (-not $GamePort) { $GamePort = if ($settings.ContainsKey('FIVEM_PORT')) { [int]$settings.FIVEM_PORT } else { 30120 } }
if (-not $TxAdminPort) { $TxAdminPort = if ($settings.ContainsKey('TXADMIN_PORT')) { [int]$settings.TXADMIN_PORT } else { 40120 } }
$dbPort = if ($settings.ContainsKey('DB_PORT')) { [int]$settings.DB_PORT } else { 3306 }
$failures = 0
function Pass([string]$Message) { Write-Host "[ok] $Message" }
function Fail([string]$Message) { $script:failures++; Write-Host "[fail] $Message" }
function Is-Private([string]$Address) { return $Address -in @('127.0.0.1','::1','::ffff:127.0.0.1') -or $Address -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' }
$service = Get-Service TarrantMariaDB -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') { Pass 'TarrantMariaDB is running.' } else { Fail 'TarrantMariaDB is not running.' }
$gameListeners = @(Get-NetTCPConnection -State Listen -LocalPort $GamePort -ErrorAction SilentlyContinue)
if (-not $gameListeners) { Fail "Game TCP listener is missing on port $GamePort." }
elseif ($Environment -eq 'development' -and -not ($gameListeners | Where-Object { Is-Private $_.LocalAddress })) { Fail 'Development game listener is not private.' }
else { Pass "Game listener is valid for $Environment on port $GamePort." }
foreach ($spec in @(@{Name='MariaDB';Port=$dbPort},@{Name='txAdmin';Port=$TxAdminPort})) {
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $spec.Port -ErrorAction SilentlyContinue)
    if (-not $listeners -or ($listeners | Where-Object { -not (Is-Private $_.LocalAddress) })) { Fail "$($spec.Name) listener must remain private on port $($spec.Port)." }
    else { Pass "$($spec.Name) listener is private on port $($spec.Port)." }
}
try {
    $info = Invoke-RestMethod -Uri "http://127.0.0.1:$GamePort/info.json" -TimeoutSec 5
    foreach ($resource in @('oxmysql','qbx_core','ox_inventory','pma-voice','tarrant_ops')) {
        if ($info.resources -contains $resource) { Pass "FXServer reports resource: $resource." } else { Fail "FXServer does not report resource: $resource." }
    }
} catch { Fail "FXServer info endpoint failed: $($_.Exception.Message)" }
try { if ((Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$TxAdminPort/" -TimeoutSec 5).StatusCode -eq 200) { Pass 'txAdmin HTTP endpoint is healthy.' } } catch { Fail "txAdmin endpoint failed: $($_.Exception.Message)" }
$log = Join-Path $repositoryRoot 'txData\default\logs\fxserver.log'
if ((Test-Path $log) -and ((Get-Content $log -Tail 400) -match '\[tarrant_ops\].*health.startup.*Startup readiness passed')) { Pass 'tarrant_ops startup health log is present.' } else { Fail 'tarrant_ops startup health log is missing.' }
if ($failures) { throw "Week 2 health check failed with $failures issue(s)." }
Pass "Week 2 health/readiness checks passed for $Environment."
