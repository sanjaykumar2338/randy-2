#Requires -Version 5.1

[CmdletBinding()]
param([int]$GamePort = 30120, [int]$SampleSeconds = 3, [string]$OutputPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function Measure-Http([string]$Uri) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $response = Invoke-RestMethod -Uri $Uri -TimeoutSec 5
    $timer.Stop()
    [pscustomobject]@{ Milliseconds = [math]::Round($timer.Elapsed.TotalMilliseconds, 1); Response = $response }
}

$infoResult = Measure-Http "http://127.0.0.1:$GamePort/info.json"
$playersResult = Measure-Http "http://127.0.0.1:$GamePort/players.json"
$before = @(Get-Process -Name 'cfx-server' -ErrorAction Stop | Select-Object Id, CPU)
Start-Sleep -Seconds $SampleSeconds
$after = @(Get-Process -Name 'cfx-server' -ErrorAction Stop)
$cpuBefore = ($before | Measure-Object CPU -Sum).Sum
$cpuAfter = ($after | Measure-Object CPU -Sum).Sum
$logicalProcessors = [Environment]::ProcessorCount
$cpuPercent = (($cpuAfter - $cpuBefore) / $SampleSeconds / $logicalProcessors) * 100

$settings = @{}
foreach ($line in [IO.File]::ReadAllLines((Join-Path $repositoryRoot '.env'))) {
    if ($line -match '^\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') {
        $settings[$matches.name] = $matches.value.Trim().Trim('"').Trim("'")
    }
}
$client = Get-ChildItem -Path "$env:ProgramFiles\MariaDB *\bin\mariadb.exe" -ErrorAction Stop | Sort-Object FullName -Descending | Select-Object -First 1
$oldPassword = $env:MYSQL_PWD
try {
    $env:MYSQL_PWD = $settings.DB_PASSWORD
    $databaseStatus = & $client.FullName "--host=$($settings.DB_HOST)" "--port=$($settings.DB_PORT)" "--user=$($settings.DB_USER)" --batch --skip-column-names $settings.DB_NAME -e "SHOW SESSION STATUS WHERE Variable_name IN ('Threads_connected','Threads_running','Uptime');"
    if ($LASTEXITCODE -ne 0) { throw 'MariaDB status query failed.' }
}
finally {
    if ($null -eq $oldPassword) { Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue } else { $env:MYSQL_PWD = $oldPassword }
}
$database = @{}
foreach ($line in $databaseStatus) {
    $parts = $line -split "`t", 2
    if ($parts.Count -eq 2) { $database[$parts[0]] = [long]$parts[1] }
}
$databasePid = (Get-NetTCPConnection -State Listen -LocalPort ([int]$settings.DB_PORT) -ErrorAction Stop | Select-Object -First 1).OwningProcess
$databaseProcess = Get-Process -Id $databasePid -ErrorAction Stop

$baseline = [ordered]@{
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    sampleSeconds = $SampleSeconds
    fxserver = [ordered]@{
        processCount = $after.Count
        cpuPercentOfHost = [math]::Round($cpuPercent, 2)
        workingSetMiB = [math]::Round((($after | Measure-Object WorkingSet64 -Sum).Sum / 1MB), 1)
        resourceCount = @($infoResult.Response.resources).Count
        playerCount = @($playersResult.Response).Count
        infoResponseMs = $infoResult.Milliseconds
        playersResponseMs = $playersResult.Milliseconds
    }
    mariadb = [ordered]@{
        service = (Get-Service TarrantMariaDB).Status.ToString()
        threadsConnected = $database.Threads_connected
        threadsRunning = $database.Threads_running
        sessionUptimeSeconds = $database.Uptime
        workingSetMiB = [math]::Round(($databaseProcess.WorkingSet64 / 1MB), 1)
    }
}
$json = $baseline | ConvertTo-Json -Depth 5
if ($OutputPath) {
    $resolvedOutput = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputPath))
    if (-not $resolvedOutput.StartsWith((Join-Path $repositoryRoot 'artifacts'), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Baseline output must remain under ignored artifacts/.'
    }
    [IO.Directory]::CreateDirectory((Split-Path $resolvedOutput -Parent)) | Out-Null
    [IO.File]::WriteAllText($resolvedOutput, $json, [Text.UTF8Encoding]::new($false))
}
$json
