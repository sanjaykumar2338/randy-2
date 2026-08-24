#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param([int]$GamePort = 30120, [int]$TxAdminPort = 40120, [string]$TxAdminRemoteAddress, [switch]$Remove)
$ErrorActionPreference = 'Stop'
$group = 'Tarrant RP Staging'
Get-NetFirewallRule -Group $group -ErrorAction SilentlyContinue | Remove-NetFirewallRule
if ($Remove) { Write-Host "[ok] Removed firewall rules in group: $group"; exit 0 }
New-NetFirewallRule -DisplayName 'Tarrant RP FiveM TCP' -Group $group -Direction Inbound -Action Allow -Protocol TCP -LocalPort $GamePort -Profile Any | Out-Null
New-NetFirewallRule -DisplayName 'Tarrant RP FiveM UDP' -Group $group -Direction Inbound -Action Allow -Protocol UDP -LocalPort $GamePort -Profile Any | Out-Null
New-NetFirewallRule -DisplayName 'Tarrant RP MariaDB public deny' -Group $group -Direction Inbound -Action Block -Protocol TCP -LocalPort 3306 -RemoteAddress Internet -Profile Any | Out-Null
if ($TxAdminRemoteAddress) {
    New-NetFirewallRule -DisplayName 'Tarrant RP txAdmin restricted' -Group $group -Direction Inbound -Action Allow -Protocol TCP -LocalPort $TxAdminPort -RemoteAddress $TxAdminRemoteAddress -Profile Any | Out-Null
    Write-Host "[ok] txAdmin is allowed only from $TxAdminRemoteAddress; configure a matching private bind/VPN."
}
else { Write-Host '[ok] No public txAdmin rule was created; keep TXADMIN_BIND_ADDRESS on loopback.' }
Write-Host "[ok] Staging FiveM firewall rules installed for TCP/UDP $GamePort."
