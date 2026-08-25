#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$healthScript = Join-Path $repositoryRoot 'scripts\check-week2-health.ps1'
$testRoot = Join-Path $repositoryRoot 'runtime\health-log-regression'
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
$resources = [ordered]@{
    ox_lib='started'; oxmysql='started'; qbx_core='started'; qbx_vehicles='started'; ox_target='started'
    ox_inventory='started'; qbx_spawn='started'; 'illenium-appearance'='started'; qbx_hud='started'; 'pma-voice'='started'
}

function Invoke-Fixture([string]$Name, [string]$Json, [bool]$ShouldPass, [string]$ExpectedFailure) {
    $path = Join-Path $testRoot "$Name.log"
    [IO.File]::WriteAllText($path, "[00:00:00] [ info] [tarrant_ops] $Json", [Text.UTF8Encoding]::new($false))
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $healthScript -Environment development -HealthLogPath $path 2>&1)
        $passed = $LASTEXITCODE -eq 0
    }
    finally { $ErrorActionPreference = $previousErrorAction }
    if ($passed -ne $ShouldPass) { throw "Health-log regression fixture failed: $Name" }
    if (-not $ShouldPass -and ($output -join "`n") -notmatch $ExpectedFailure) { throw "Health-log fixture failed for the wrong reason: $Name" }
}

try {
    $fieldsFirst = [ordered]@{fields=[ordered]@{healthy=$true;database=$true;resources=$resources};message='Startup readiness passed';category='health.startup'} | ConvertTo-Json -Compress -Depth 5
    $categoryFirst = [ordered]@{category='health.startup';message='Startup readiness passed';fields=[ordered]@{resources=$resources;database=$true;healthy=$true}} | ConvertTo-Json -Compress -Depth 5
    $failedReadiness = [ordered]@{category='health.startup';message='Startup readiness failed';fields=[ordered]@{resources=$resources;database=$true;healthy=$false}} | ConvertTo-Json -Compress -Depth 5
    $databaseFailed = [ordered]@{category='health.startup';message='Startup readiness passed';fields=[ordered]@{resources=$resources;database=$false;healthy=$true}} | ConvertTo-Json -Compress -Depth 5
    $unhealthyResources = [ordered]@{} + $resources
    $unhealthyResources.oxmysql = 'stopped'
    $resourceFailed = [ordered]@{category='health.startup';message='Startup readiness passed';fields=[ordered]@{resources=$unhealthyResources;database=$true;healthy=$true}} | ConvertTo-Json -Compress -Depth 5
    Invoke-Fixture 'fields-first-success' $fieldsFirst $true ''
    Invoke-Fixture 'category-first-success' $categoryFirst $true ''
    Invoke-Fixture 'readiness-failed' $failedReadiness $false 'did not report readiness success|is not healthy'
    Invoke-Fixture 'database-failed' $databaseFailed $false 'database readiness failure'
    Invoke-Fixture 'resource-failed' $resourceFailed $false 'unhealthy resource: oxmysql'
    Invoke-Fixture 'event-missing' '{"category":"resource.started"}' $false 'health.startup event is missing'
    Write-Host '[ok] Week 2 structured health-log regression tests passed.'
    $global:LASTEXITCODE = 0
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
