#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$installerPath = Join-Path $repositoryRoot 'scripts\install-qbox-runtime.ps1'
$linuxInstallerPath = Join-Path $repositoryRoot 'scripts\install-pma-voice.sh'
$serverConfigPath = Join-Path $repositoryRoot 'config\server.example.cfg'
$installer = [System.IO.File]::ReadAllText($installerPath)
$linuxInstaller = [System.IO.File]::ReadAllText($linuxInstallerPath)
$serverConfig = [System.IO.File]::ReadAllText($serverConfigPath)
$expectedCommit = '6c9d96ed7a02e30912f1a0ce92629bf9afbbca8c'

$checks = @(
    @{ Name = 'server configuration starts pma-voice'; Passed = $serverConfig -match '(?m)^ensure pma-voice\s*$' },
    @{ Name = 'runtime installer pins pma-voice 7.0.1'; Passed = $installer -match "Name='pma-voice'; Version='7\.0\.1'" },
    @{ Name = 'runtime installer pins the accepted pma-voice commit'; Passed = $installer -match [regex]::Escape("`$pmaVoiceCommit = '$expectedCommit'") },
    @{ Name = 'Linux installer pins the accepted pma-voice commit'; Passed = $linuxInstaller -match [regex]::Escape("PMA_VOICE_COMMIT='$expectedCommit'") },
    @{ Name = 'Linux installer refuses to overwrite an existing resource'; Passed = $linuxInstaller -match 'Refusing to overwrite existing pma-voice resource' },
    @{ Name = 'runtime manifest no longer defers voice'; Passed = $installer -notmatch "voice\s*=\s*'deferred'" },
    @{ Name = 'runtime installer validates each downloaded resource manifest'; Passed = $installer -match 'Join-Path \$resourcePath ''fxmanifest\.lua''' }
)

$failed = @($checks | Where-Object { -not $_.Passed })
foreach ($check in $checks) {
    $status = if ($check.Passed) { 'PASS' } else { 'FAIL' }
    Write-Host "[$status] $($check.Name)"
}

if ($failed.Count -gt 0) {
    throw "$($failed.Count) runtime dependency check(s) failed."
}

Write-Host 'Runtime dependency checks: PASS'
