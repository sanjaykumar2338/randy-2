#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$ProjectRoot, [string]$TaskName = 'TarrantRP-FXServer-Staging')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $ProjectRoot) { $ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
$ProjectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$runner = Join-Path $ProjectRoot 'scripts\run-fxserver-startup.ps1'
if (-not (Test-Path $runner -PathType Leaf)) { throw "Startup runner missing: $runner" }
$arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -ProjectRoot "{1}"' -f $runner, $ProjectRoot
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments -WorkingDirectory $ProjectRoot
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Starts Tarrant RP txAdmin/FXServer after MariaDB at boot.' -Force | Out-Null
Write-Host "[ok] Installed startup task: $TaskName"
