$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $repositoryRoot 'scripts\public-listing-validation.ps1')

$cases = @(
    @{ Line = 'sv_master1 ""'; Expected = $true },
    @{ Line = "sv_master1 ''"; Expected = $true },
    @{ Line = '  sv_master1 ""  # disables listing'; Expected = $true },
    @{ Line = '# sv_master1 ""'; Expected = $false },
    @{ Line = '  ; sv_master1 ""'; Expected = $false },
    @{ Line = 'sv_master1 "https://servers-ingress-live.fivem.net/ingress"'; Expected = $false },
    @{ Line = 'sets sv_master1 ""'; Expected = $false }
)

foreach ($case in $cases) {
    $actual = Test-ActiveEmptySvMaster1Directive -Line $case.Line
    if ($actual -ne $case.Expected) {
        throw "Public-listing directive classification failed for test input."
    }
}

$sharedSecurity = Join-Path $repositoryRoot 'config\security.example.cfg'
$activeSharedDirective = Get-Content -LiteralPath $sharedSecurity |
    Where-Object { Test-ActiveEmptySvMaster1Directive -Line $_ }
if ($activeSharedDirective) {
    throw 'Shared deployment security config disables public Cfx listing.'
}

$developmentTemplate = Join-Path $repositoryRoot 'config\server.example.cfg'
$activeDevelopmentDirective = Get-Content -LiteralPath $developmentTemplate |
    Where-Object { Test-ActiveEmptySvMaster1Directive -Line $_ }
if (-not $activeDevelopmentDirective) {
    throw 'Loopback development template no longer explicitly suppresses public listing.'
}

Write-Host '[ok] FiveM public-listing configuration regression tests passed.'
