#Requires -Version 5.1

[CmdletBinding()]
param([int]$GamePort = 30120, [int]$TxAdminPort = 40120)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$failures = 0
function Pass([string]$Message) { Write-Host "[ok] $Message" }
function Fail([string]$Message) { $script:failures++; Write-Host "[fail] $Message" }

$service = Get-Service TarrantMariaDB -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') { Pass 'TarrantMariaDB is running.' } else { Fail 'TarrantMariaDB is not running.' }

foreach ($port in @($GamePort, $TxAdminPort, 3306)) {
    $listener = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listener -and $listener.LocalAddress -in @('127.0.0.1', '::1')) { Pass "Loopback listener is healthy on port $port." }
    else { Fail "Expected loopback listener is missing on port $port." }
}

try {
    $info = Invoke-RestMethod -Uri "http://127.0.0.1:$GamePort/info.json" -TimeoutSec 5
    $required = @('oxmysql', 'qbx_core', 'ox_inventory', 'pma-voice', 'tarrant_ops')
    foreach ($resource in $required) {
        if ($info.resources -contains $resource) { Pass "FXServer reports resource: $resource." } else { Fail "FXServer does not report resource: $resource." }
    }
}
catch { Fail "FXServer info endpoint failed: $($_.Exception.Message)" }

try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$TxAdminPort/" -TimeoutSec 5
    if ($response.StatusCode -eq 200) { Pass 'txAdmin HTTP endpoint is healthy.' } else { Fail "txAdmin returned HTTP $($response.StatusCode)." }
}
catch { Fail "txAdmin endpoint failed: $($_.Exception.Message)" }

$log = Join-Path $repositoryRoot 'txData\default\logs\fxserver.log'
if (Test-Path -LiteralPath $log -PathType Leaf) {
    $recent = Get-Content -LiteralPath $log -Tail 400
    if ($recent -match '\[tarrant_ops\].*health.startup.*Startup readiness passed') { Pass 'tarrant_ops startup health log is present.' }
    else { Fail 'tarrant_ops startup health log is missing.' }
}

if ($failures) { throw "Week 2 health check failed with $failures issue(s)." }
Pass 'Week 2 health/readiness checks passed.'
