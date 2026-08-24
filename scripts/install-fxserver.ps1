#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$DestinationPath,
    [string]$ManifestPath,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ManifestPath) { $ManifestPath = Join-Path $repositoryRoot 'config\fxserver-artifact.json' }
if (-not $DestinationPath) { $DestinationPath = Join-Path $repositoryRoot 'server-binaries\enhanced-129' }
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
if ($manifest.officialSource -notmatch '^https://downloads\.cfx-services\.net/') { throw 'Manifest source is not an official Cfx download host.' }
$destination = [IO.Path]::GetFullPath($DestinationPath)
if ($destination -eq [IO.Path]::GetPathRoot($destination) -or $destination -eq $repositoryRoot) { throw 'Unsafe FXServer destination.' }
if ((Test-Path $destination) -and (Get-ChildItem $destination -Force | Select-Object -First 1) -and -not $Force) {
    throw "Destination is not empty: $destination. Review it, then rerun with -Force to replace it."
}
$workRoot = Join-Path $repositoryRoot ('runtime\fxserver-install-' + [IO.Path]::GetRandomFileName())
$archive = Join-Path $workRoot $manifest.archiveName
$stage = Join-Path $workRoot 'stage'
try {
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    & curl.exe --fail --location --silent --show-error --output $archive $manifest.officialSource
    if ($LASTEXITCODE -ne 0) { throw 'Official FXServer download failed.' }
    $archiveHash = (Get-FileHash $archive -Algorithm SHA256).Hash
    if ($archiveHash -ne $manifest.archiveSha256) { throw "FXServer archive checksum mismatch: $archiveHash" }
    Expand-Archive -LiteralPath $archive -DestinationPath $stage
    $executable = Join-Path $stage $manifest.executable
    if (-not (Test-Path $executable -PathType Leaf)) { throw 'FXServer executable is missing from the verified archive.' }
    $exeHash = (Get-FileHash $executable -Algorithm SHA256).Hash
    if ($exeHash -ne $manifest.executableSha256) { throw "FXServer executable checksum mismatch: $exeHash" }
    if (Test-Path $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
    [IO.Directory]::CreateDirectory((Split-Path $destination -Parent)) | Out-Null
    Move-Item -LiteralPath $stage -Destination $destination
    Write-Host "[ok] Installed verified Enhanced FXServer b$($manifest.build): $destination"
}
finally {
    if (Test-Path $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
}
