#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param([string]$TaskName = 'TarrantRP-FXServer-Staging')
$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Write-Host "[ok] Removed startup task: $TaskName" }
else { Write-Host "[ok] Startup task is already absent: $TaskName" }
