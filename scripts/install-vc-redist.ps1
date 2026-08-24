#Requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$installed = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction SilentlyContinue
if ($installed -and $installed.Installed -eq 1) { Write-Host "[ok] Visual C++ x64 runtime is installed ($($installed.Version))."; exit 0 }
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$downloadDirectory = Join-Path $repositoryRoot 'runtime\downloads'
[IO.Directory]::CreateDirectory($downloadDirectory) | Out-Null
$installer = Join-Path $downloadDirectory 'vc_redist.x64.exe'
& curl.exe --fail --location --silent --show-error --output $installer 'https://aka.ms/vc14/vc_redist.x64.exe'
if ($LASTEXITCODE -ne 0) { throw 'Official Microsoft Visual C++ download failed.' }
$signature = Get-AuthenticodeSignature $installer
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft') { throw 'Visual C++ installer signature is not valid Microsoft code.' }
$process = Start-Process $installer -ArgumentList '/install','/quiet','/norestart' -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -notin @(0, 1638, 3010)) { throw "Visual C++ installer failed with exit code $($process.ExitCode)." }
$installed = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64' -ErrorAction Stop
if ($installed.Installed -ne 1) { throw 'Visual C++ x64 runtime verification failed.' }
Write-Host "[ok] Visual C++ x64 runtime is installed ($($installed.Version))."
