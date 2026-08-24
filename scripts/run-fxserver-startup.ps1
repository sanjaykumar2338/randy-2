#Requires -Version 5.1
[CmdletBinding()]
param([string]$ProjectRoot, [string]$MariaDbServiceName = 'TarrantMariaDB')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$logDirectory = Join-Path $ProjectRoot 'runtime\startup'
[IO.Directory]::CreateDirectory($logDirectory) | Out-Null
$log = Join-Path $logDirectory 'startup.log'
try {
    $service = Get-Service $MariaDbServiceName -ErrorAction Stop
    if ($service.Status -ne 'Running') { Start-Service $MariaDbServiceName }
    (Get-Service $MariaDbServiceName).WaitForStatus('Running', [TimeSpan]::FromSeconds(60))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot 'scripts\start-txadmin.ps1') *>> $log
    if ($LASTEXITCODE -ne 0) { throw "start-txadmin.ps1 exited with $LASTEXITCODE" }
    $pidFile = Join-Path $ProjectRoot 'runtime\fxserver.pid'
    if (-not (Test-Path -LiteralPath $pidFile -PathType Leaf)) { throw 'FXServer PID file was not created.' }
    $hostPid = 0
    if (-not [int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$hostPid)) { throw 'FXServer PID file is invalid.' }
    $hostProcess = Get-Process -Id $hostPid -ErrorAction Stop
    "[$(Get-Date -Format o)] Monitoring txAdmin/FXServer host PID $hostPid." | Add-Content -LiteralPath $log
    $hostProcess.WaitForExit()
    throw "txAdmin/FXServer host PID $hostPid exited with code $($hostProcess.ExitCode)."
}
catch {
    "[$(Get-Date -Format o)] ERROR: $($_.Exception.Message)" | Add-Content -LiteralPath $log
    throw
}
