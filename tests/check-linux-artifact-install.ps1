#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$manifestPath = Join-Path $root 'config\fxserver-linux-artifact.json'
$installerPath = Join-Path $root 'scripts\install-fxserver-linux.sh'
$stagingEnvironmentPath = Join-Path $root '.env.staging.example'
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$installer = [IO.File]::ReadAllText($installerPath)
$stagingEnvironment = [IO.File]::ReadAllText($stagingEnvironmentPath)

$checks = @(
    @{ Name='Enhanced Linux product'; Pass=$manifest.product -eq 'FiveM for GTAV Enhanced Cfx Server for Linux x64' },
    @{ Name='Enhanced channel'; Pass=$manifest.channel -eq 'enhanced' },
    @{ Name='pinned Enhanced build'; Pass=$manifest.build -eq 139 },
    @{ Name='official Enhanced Linux source'; Pass=$manifest.officialSource -match '^https://downloads\.cfx-services\.net/prod/[0-9a-f-]+/cfx-server_linux_x64\.tar\.xz$' },
    @{ Name='archive checksum'; Pass=$manifest.archiveSha256 -match '^[A-F0-9]{64}$' },
    @{ Name='Linux launcher'; Pass=$manifest.launcher -eq 'run.sh' },
    @{ Name='Enhanced Linux executable'; Pass=$manifest.executable -eq 'alpine/opt/cfx-server/cfx-server' },
    @{ Name='side-by-side destination'; Pass=$installer -match 'server-binaries/enhanced-linux-\$BUILD' },
    @{ Name='refuses overwrite'; Pass=$installer -match 'refusing to overwrite rollback-capable binaries' },
    @{ Name='verifies checksum'; Pass=$installer -match 'sha256sum' -and $installer -match 'checksum mismatch' },
    @{ Name='validates archive paths'; Pass=$installer -match 'archive contains an unsafe path' },
    @{ Name='does not address protected deployment data'; Pass=$installer -notmatch 'runtime/qbox-server-data|ROOT_DIR/txData|staging\.private\.cfg' },
    @{ Name='staging Linux launcher uses stable active path'; Pass=$stagingEnvironment -match '(?m)^FXSERVER_RUN_SH=server-binaries/enhanced-129/run\.sh$' }
)

foreach ($check in $checks) {
    Write-Host "[$(if ($check.Pass) {'PASS'} else {'FAIL'})] $($check.Name)"
}
$failed = @($checks | Where-Object { -not $_.Pass })
if ($failed.Count) { throw "$($failed.Count) Linux artifact installation check(s) failed." }
Write-Host 'Linux artifact installation checks: PASS'
