function Test-ActiveEmptySvMaster1Directive {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Line)

    if ($null -eq $Line) {
        return $false
    }

    $trimmed = $Line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
        return $false
    }

    return $trimmed -match '^(?i:sv_master1)\s+(?:""|'''')\s*(?:[#;].*)?$'
}
