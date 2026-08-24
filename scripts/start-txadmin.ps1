#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$FxServerExecutable,
    [string]$TxDataPath,
    [string]$TxAdminBindAddress,
    [int]$TxAdminPort,
    [int]$FxServerPort
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtimeRoot = Join-Path $repositoryRoot 'runtime'
$settings = @{}
$envPath = Join-Path $repositoryRoot '.env'
if (Test-Path -LiteralPath $envPath -PathType Leaf) {
    foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
        if ($line -match '^\s*(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') {
            $settings[$matches.name] = $matches.value.Trim().Trim('"').Trim("'")
        }
    }
}
if (-not $PSBoundParameters.ContainsKey('TxAdminBindAddress')) {
    $TxAdminBindAddress = if ($settings.ContainsKey('TXADMIN_BIND_ADDRESS') -and $settings.TXADMIN_BIND_ADDRESS) { $settings.TXADMIN_BIND_ADDRESS } else { '127.0.0.1' }
}
if (-not $PSBoundParameters.ContainsKey('TxAdminPort')) {
    $TxAdminPort = if ($settings.ContainsKey('TXADMIN_PORT') -and $settings.TXADMIN_PORT) { [int]$settings.TXADMIN_PORT } else { 40120 }
}
if (-not $PSBoundParameters.ContainsKey('FxServerPort')) {
    $FxServerPort = if ($settings.ContainsKey('FIVEM_PORT') -and $settings.FIVEM_PORT) { [int]$settings.FIVEM_PORT } else { 30120 }
}
foreach ($configuredPort in @($TxAdminPort, $FxServerPort)) {
    if ($configuredPort -lt 1 -or $configuredPort -gt 65535) { throw 'Configured ports must be from 1 through 65535.' }
}
if (-not $FxServerExecutable) {
    $enhancedCandidates = @(
        Get-ChildItem -Path (Join-Path $repositoryRoot 'server-binaries\enhanced-*\cfx-server.exe') `
            -File `
            -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending
    )
    if ($enhancedCandidates.Count -gt 0) {
        $FxServerExecutable = $enhancedCandidates[0].FullName
    }
    else {
        $FxServerExecutable = Join-Path $repositoryRoot 'fxserver\FXServer.exe'
    }
}
if (-not $TxDataPath) {
    $TxDataPath = Join-Path $repositoryRoot 'txData'
}

$FxServerExecutable = [System.IO.Path]::GetFullPath($FxServerExecutable)
$TxDataPath = [System.IO.Path]::GetFullPath($TxDataPath)
if ($TxAdminBindAddress -match '[\s/\\]' -or [string]::IsNullOrWhiteSpace($TxAdminBindAddress)) {
    throw 'TxAdminBindAddress must be a hostname or IP address without whitespace or path characters.'
}
if (-not (Test-Path -LiteralPath $FxServerExecutable -PathType Leaf)) {
    throw "FXServer executable was not found: $FxServerExecutable"
}

[System.IO.Directory]::CreateDirectory($runtimeRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($TxDataPath) | Out-Null

function Protect-LocalFile {
    param([string]$Path)

    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $security = [System.IO.File]::GetAccessControl($Path)
        $security.SetAccessRuleProtection($true, $false)
        foreach ($existingRule in @($security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))) {
            $security.RemoveAccessRuleSpecific($existingRule)
        }
        $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($identity.User, $rights, $allow))
        foreach ($sidType in @(
            [System.Security.Principal.WellKnownSidType]::LocalSystemSid,
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid
        )) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new($sidType, $null)
            $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid, $rights, $allow))
        }
        [System.IO.File]::SetAccessControl($Path, $security)
    }
    catch {
        Write-Warning "Could not tighten the ACL on the ignored local file $Path."
    }
}

function Protect-LocalDirectory {
    param([string]$Path)

    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $security = [System.IO.Directory]::GetAccessControl($Path)
        $security.SetAccessRuleProtection($true, $false)
        foreach ($existingRule in @($security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))) {
            $security.RemoveAccessRuleSpecific($existingRule)
        }
        $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        $propagation = [System.Security.AccessControl.PropagationFlags]::None
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($identity.User, $rights, $inheritance, $propagation, $allow))
        foreach ($sidType in @(
            [System.Security.Principal.WellKnownSidType]::LocalSystemSid,
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid
        )) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new($sidType, $null)
            $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid, $rights, $inheritance, $propagation, $allow))
        }
        [System.IO.Directory]::SetAccessControl($Path, $security)
    }
    catch {
        Write-Warning "Could not tighten the ACL on the ignored local directory ${Path}: $($_.Exception.Message)"
    }
}

Protect-LocalDirectory -Path $TxDataPath

$repositoryPrefix = $repositoryRoot.TrimEnd('\') + '\'
foreach ($candidate in @($runtimeRoot, $TxDataPath)) {
    $fullCandidate = [System.IO.Path]::GetFullPath($candidate)
    if ($fullCandidate.Equals($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'A runtime path cannot be the repository root.'
    }
    if ($fullCandidate.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $fullCandidate.Substring($repositoryPrefix.Length).Replace('\', '/')
        & git -C $repositoryRoot check-ignore --quiet -- $relativePath
        if ($LASTEXITCODE -ne 0) {
            throw "Refusing to use a runtime path inside the repository that is not ignored by Git: $fullCandidate"
        }
    }
}

$stdoutPath = Join-Path $runtimeRoot 'fxserver.stdout.log'
$stderrPath = Join-Path $runtimeRoot 'fxserver.stderr.log'
foreach ($path in @($stdoutPath, $stderrPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        [System.IO.File]::WriteAllText($path, '', [System.Text.UTF8Encoding]::new($false))
    }
    Protect-LocalFile -Path $path
}

$txAdminHealthHost = if ($TxAdminBindAddress -in @('0.0.0.0', '::', '[::]')) { '127.0.0.1' } else { $TxAdminBindAddress.Trim('[', ']') }
$txAdminUri = "http://${txAdminHealthHost}:$TxAdminPort/"
try {
    $existing = Invoke-WebRequest -UseBasicParsing -Uri $txAdminUri -TimeoutSec 2
    if ($existing.StatusCode -eq 200) {
        Write-Host "[ok] txAdmin is already reachable at $txAdminUri"
        exit 0
    }
}
catch {
    # No existing local txAdmin listener; continue with startup.
}

$environmentNames = @('TXHOST_INTERFACE', 'TXHOST_TXA_PORT', 'TXHOST_FXS_PORT', 'TXHOST_DATA_PATH')
$previousEnvironment = @{}
foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    $env:TXHOST_INTERFACE = $TxAdminBindAddress
    $env:TXHOST_TXA_PORT = $TxAdminPort.ToString()
    $env:TXHOST_FXS_PORT = $FxServerPort.ToString()
    $env:TXHOST_DATA_PATH = $TxDataPath

    $process = Start-Process -FilePath $FxServerExecutable `
        -WorkingDirectory ([System.IO.Path]::GetDirectoryName($FxServerExecutable)) `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -PassThru
}
finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }
}

$pidPath = Join-Path $runtimeRoot 'fxserver.pid'
[System.IO.File]::WriteAllText(
    $pidPath,
    $process.Id.ToString(),
    [System.Text.UTF8Encoding]::new($false)
)
Protect-LocalFile -Path $pidPath

$ready = $false
foreach ($attempt in 1..60) {
    if ($process.HasExited) {
        throw "FXServer exited before txAdmin became ready. Review the ignored runtime logs."
    }
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $txAdminUri -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    }
    catch {
        Start-Sleep -Milliseconds 500
    }
}

if (-not $ready) {
    throw "FXServer started, but txAdmin did not become reachable at $txAdminUri within 30 seconds."
}

Write-Host "[ok] FXServer/txAdmin started with process ID $($process.Id)"
Write-Host "[ok] Local txAdmin URL: $txAdminUri"
Write-Host "[ok] txAdmin interface: $TxAdminBindAddress"
