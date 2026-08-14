#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$EnvFile,
    [Alias('MySqlClient')]
    [string]$MariaDbClient,
    [string]$MariaDbServiceName,
    [string]$DatabaseHost,
    [ValidateRange(0, 65535)]
    [int]$DatabasePort = 0,
    [string]$DatabaseName,
    [string]$DatabaseUser,
    [string]$FxServerExe,
    [string]$ResourcesDirectory,
    [string]$ServerConfig,
    [string]$TxDataDirectory,
    [string]$TxAdminUrl,
    [ValidateRange(1, 65535)]
    [int]$GamePort = 30120,
    [ValidateRange(250, 30000)]
    [int]$ConnectTimeoutMilliseconds = 5000,
    [switch]$SkipRuntimeChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script:Failures = 0
$script:Secrets = [System.Collections.Generic.List[string]]::new()
$script:ConfigSequence = 0
$script:ConfigSettings = @{}
$script:ConfigSettingOrder = @{}
$script:ConfigSpecial = @{}
$script:ConfigSpecialOrder = @{}
$script:StartDirectives = [System.Collections.Generic.List[object]]::new()
$script:StopDirectives = [System.Collections.Generic.List[object]]::new()
$script:EndpointDirectives = [System.Collections.Generic.List[object]]::new()
$script:MissingIncludes = [System.Collections.Generic.List[string]]::new()
$script:TemplateTokens = 0
$script:VisitedConfigs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$script:TxAdminManagedOneSync = $false

function Write-Ok {
    param([string]$Message)
    Write-Host "[ok] $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Host "[info] $Message"
}

function Write-WarnStatus {
    param([string]$Message)
    Write-Host "[warn] $Message"
}

function Write-FailStatus {
    param([string]$Message)
    $script:Failures++
    Write-Host "[fail] $Message"
}

function Add-Secret {
    param([AllowEmptyString()][string]$Value)

    if (-not [string]::IsNullOrWhiteSpace($Value) -and $Value -ne 'CHANGE_ME' -and -not $script:Secrets.Contains($Value)) {
        [void]$script:Secrets.Add($Value)
    }
}

function Protect-Text {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        return ''
    }
    $safe = $Text
    foreach ($secret in $script:Secrets) {
        if (-not [string]::IsNullOrEmpty($secret)) {
            $safe = [regex]::Replace($safe, [regex]::Escape($secret), '[redacted]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        }
    }
    $safe = [regex]::Replace($safe, '(?i)(mysql(?:\+\w+)?://[^:\s/]+:)[^@\s/]+(@)', '$1[redacted]$2')
    $safe = [regex]::Replace($safe, '(?i)(password\s*[=:]\s*)[^;\s]+', '$1[redacted]')
    $safe = [regex]::Replace($safe, '(?i)cfxk_[A-Za-z0-9_-]+', '[redacted-license-key]')
    return $safe
}

function Resolve-LocalPath {
    param(
        [string]$Path,
        [string]$BasePath = $script:RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return [System.IO.Path]::GetFullPath($expanded)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $expanded))
}

function Test-PathWithinRepository {
    param([string]$Path)

    $root = [System.IO.Path]::GetFullPath($script:RepositoryRoot).TrimEnd('\')
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    return $full.Equals($root, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith("$root\", [System.StringComparison]::OrdinalIgnoreCase)
}

function Read-DotEnv {
    param([string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $values
    }
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') {
            continue
        }
        if ($line -match '^\s*(?:export\s+)?(?<name>[A-Za-z_][A-Za-z0-9_]*)=(?<value>.*)$') {
            $value = $matches['value'].Trim()
            if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[$value.Length - 1] -eq '"') -or ($value[0] -eq "'" -and $value[$value.Length - 1] -eq "'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $values[$matches['name']] = $value
            if ($matches['name'] -match '(?i)(PASSWORD|TOKEN|SECRET|LICENSE_KEY)$') {
                Add-Secret -Value $value
            }
        }
    }
    return $values
}

function Get-Setting {
    param(
        [string]$Name,
        [hashtable]$Settings,
        [AllowEmptyString()][string]$DefaultValue = ''
    )

    $processValue = [Environment]::GetEnvironmentVariable($Name, [EnvironmentVariableTarget]::Process)
    if (-not [string]::IsNullOrWhiteSpace($processValue)) {
        return $processValue
    }
    if ($Settings.ContainsKey($Name) -and -not [string]::IsNullOrWhiteSpace([string]$Settings[$Name])) {
        return [string]$Settings[$Name]
    }
    return $DefaultValue
}

function Test-XamppPath {
    param([AllowEmptyString()][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    return $Path.Replace('/', '\') -match '(?i)(?:^|\\)xampp(?:\\|$)'
}

function Get-MariaDbVersion {
    param([string]$Text)

    if ($Text -notmatch '(?i)MariaDB') {
        return $null
    }
    $match = [regex]::Match($Text, '(?<major>\d+)\.(?<minor>\d+)(?:\.(?<patch>\d+))?(?:[^\s]*)?-MariaDB', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $match.Success) {
        $match = [regex]::Match($Text, '(?<major>\d+)\.(?<minor>\d+)(?:\.(?<patch>\d+))?', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }
    if (-not $match.Success) {
        return $null
    }
    $patch = 0
    if ($match.Groups['patch'].Success) {
        $patch = [int]$match.Groups['patch'].Value
    }
    return [version]::new([int]$match.Groups['major'].Value, [int]$match.Groups['minor'].Value, $patch)
}

function Get-MariaDbClientPath {
    param([string]$RequestedPath)

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Resolve-LocalPath -Path $RequestedPath
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($commandName in @('mariadb.exe', 'mysql.exe')) {
        foreach ($command in @(Get-Command $commandName -All -ErrorAction SilentlyContinue)) {
            if ($command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
                [void]$paths.Add($command.Source)
            }
        }
    }

    $programRoots = @(
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFiles),
        [Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    foreach ($programRoot in $programRoots) {
        foreach ($directory in @(Get-ChildItem -LiteralPath $programRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'MariaDB *' })) {
            foreach ($fileName in @('mariadb.exe', 'mysql.exe')) {
                $candidate = Join-Path $directory.FullName "bin\$fileName"
                if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                    [void]$paths.Add($candidate)
                }
            }
        }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $supported = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in $paths) {
        if (-not $seen.Add($candidate) -or (Test-XamppPath -Path $candidate) -or -not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            continue
        }
        $versionText = (& $candidate --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            $version = Get-MariaDbVersion -Text $versionText
            if ($version) {
                [void]$supported.Add([pscustomobject]@{ Path = $candidate; Version = $version })
            }
        }
    }
    $selected = $supported | Sort-Object Version -Descending | Select-Object -First 1
    if ($selected) {
        return $selected.Path
    }
    return $null
}

function Get-MariaDbServiceInfo {
    param([string]$RequestedName)

    $services = @(Get-Service -ErrorAction SilentlyContinue)
    $cimServices = @()
    try {
        $cimServices = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)
    }
    catch {
        $cimServices = @()
    }

    if ($RequestedName) {
        $service = $services | Where-Object { $_.Name -eq $RequestedName } | Select-Object -First 1
        if (-not $service) {
            return $null
        }
        $cimService = $cimServices | Where-Object { $_.Name -eq $service.Name } | Select-Object -First 1
    }
    else {
        $candidates = @($services | Where-Object { $_.Name -match '(?i)maria|mysql' -or $_.DisplayName -match '(?i)maria|mysql' })
        $supportedCandidates = @($candidates | Where-Object {
            $candidateName = $_.Name
            $candidateCim = $cimServices | Where-Object { $_.Name -eq $candidateName } | Select-Object -First 1
            -not $candidateCim -or -not (Test-XamppPath -Path ([string]$candidateCim.PathName))
        })
        $service = $supportedCandidates |
            Sort-Object @{ Expression = { if ($_.Status -eq 'Running') { 0 } else { 1 } } }, @{ Expression = { if ($_.Name -eq 'TarrantMariaDB') { 0 } else { 1 } } }, Name |
            Select-Object -First 1
        if (-not $service) {
            return $null
        }
        $cimService = $cimServices | Where-Object { $_.Name -eq $service.Name } | Select-Object -First 1
    }

    $pathName = ''
    if ($cimService) {
        $pathName = [string]$cimService.PathName
    }
    return [pscustomobject]@{
        Name = $service.Name
        Status = [string]$service.Status
        StartType = [string]$service.StartType
        PathName = $pathName
    }
}

function Test-TcpEndpoint {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMilliseconds
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $result = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $result.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }
        $client.EndConnect($result)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Get-LocalTcpListeners {
    param([int]$Port)

    if (-not (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
        return @()
    }
    try {
        return @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

function Get-ProcessExecutablePath {
    param([int]$ProcessId)

    try {
        return [string](Get-Process -Id $ProcessId -ErrorAction Stop).Path
    }
    catch {
        return ''
    }
}

function Invoke-MariaDbScalar {
    param(
        [string]$Client,
        [string]$HostName,
        [int]$Port,
        [string]$User,
        [string]$Password,
        [string]$Database,
        [string]$Sql
    )

    $hadPassword = Test-Path Env:\MYSQL_PWD
    $oldPassword = $env:MYSQL_PWD
    $oldPreference = $ErrorActionPreference
    try {
        $env:MYSQL_PWD = $Password
        $ErrorActionPreference = 'Continue'
        $arguments = @(
            '--protocol=tcp',
            "--host=$HostName",
            "--port=$Port",
            "--user=$User",
            '--batch',
            '--skip-column-names',
            '--raw'
        )
        if ($Database) {
            $arguments += "--database=$Database"
        }
        $arguments += @('--execute', $Sql)
        $output = @(& $Client @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $message = Protect-Text -Text (($output | Out-String).Trim())
            if (-not $message) {
                $message = "MariaDB client exited with code $exitCode."
            }
            throw $message
        }
        $line = $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] -and -not [string]::IsNullOrWhiteSpace($_.ToString()) } | Select-Object -First 1
        if ($null -eq $line) {
            return ''
        }
        return $line.ToString().Trim()
    }
    finally {
        $ErrorActionPreference = $oldPreference
        if ($hadPassword) {
            $env:MYSQL_PWD = $oldPassword
        }
        else {
            Remove-Item Env:\MYSQL_PWD -ErrorAction SilentlyContinue
        }
    }
}

function Test-GitIgnored {
    param([string]$Path)

    if (-not (Test-PathWithinRepository -Path $Path)) {
        return $true
    }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $git) { $git = Get-Command git -ErrorAction SilentlyContinue }
    if (-not $git) { return $false }
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $git.Source -C $script:RepositoryRoot check-ignore --quiet -- $Path *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Test-GitTracked {
    param([string]$Path)

    if (-not (Test-PathWithinRepository -Path $Path)) {
        return $false
    }
    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $git) { $git = Get-Command git -ErrorAction SilentlyContinue }
    if (-not $git) { return $false }
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $git.Source -C $script:RepositoryRoot ls-files --error-unmatch -- $Path *> $null
        return $LASTEXITCODE -eq 0
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

function Get-FxServerPath {
    param(
        [string]$RequestedPath,
        [hashtable]$Settings
    )

    $configured = $RequestedPath
    if (-not $configured) {
        $configured = Get-Setting -Name 'FXSERVER_EXE' -Settings $Settings
    }
    if ($configured -and $configured -notmatch '(?i)^/path/to/|CHANGE_ME') {
        $resolved = Resolve-LocalPath -Path $configured
        if (Test-Path -LiteralPath $resolved -PathType Leaf) {
            return $resolved
        }
    }

    $parent = Split-Path -Parent $script:RepositoryRoot
    foreach ($candidate in @(
        (Join-Path $script:RepositoryRoot 'server\FXServer.exe'),
        (Join-Path $script:RepositoryRoot 'fxserver\FXServer.exe'),
        (Join-Path $parent 'server\FXServer.exe'),
        'C:\FXServer\server\FXServer.exe'
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }
    return $null
}

function Get-ConfigTokenValue {
    param([System.Text.RegularExpressions.Match]$Match)

    foreach ($groupName in @('double', 'single', 'bare')) {
        if ($Match.Groups[$groupName].Success) {
            return $Match.Groups[$groupName].Value
        }
    }
    return ''
}

function Resolve-ConfigInclude {
    param(
        [string]$Include,
        [string]$CurrentConfig
    )

    if ($Include.StartsWith('@')) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($Include)) {
        return [System.IO.Path]::GetFullPath($Include)
    }

    $rootCandidate = [System.IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot $Include))
    if (Test-Path -LiteralPath $rootCandidate -PathType Leaf) {
        return $rootCandidate
    }
    $localCandidate = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $CurrentConfig) $Include))
    if (Test-Path -LiteralPath $localCandidate -PathType Leaf) {
        return $localCandidate
    }
    return $rootCandidate
}

function Read-FxConfig {
    param([string]$Path)

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    if (-not $script:VisitedConfigs.Add($fullPath)) {
        return
    }

    $lineNumber = 0
    foreach ($line in [System.IO.File]::ReadAllLines($fullPath)) {
        $lineNumber++
        $trimmed = $line.Trim()
        if ($trimmed -match '(?i)^#+\s*\[txAdmin CFG validator\]:\s*onesync\s+MUST only be set') {
            $script:TxAdminManagedOneSync = $true
        }
        if (-not $trimmed -or $trimmed.StartsWith('#') -or $trimmed.StartsWith(';')) {
            continue
        }
        $script:ConfigSequence++
        $order = $script:ConfigSequence

        if ($trimmed -match '\{\{[^}]+\}\}') {
            $script:TemplateTokens++
        }

        $match = [regex]::Match($trimmed, '^exec\s+(?:"(?<double>[^"]+)"|''(?<single>[^'']+)''|(?<bare>[^\s#]+))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $include = Get-ConfigTokenValue -Match $match
            $includePath = Resolve-ConfigInclude -Include $include -CurrentConfig $fullPath
            if ($null -eq $includePath) {
                Write-WarnStatus "Resource-relative config include '$include' was not inspected."
            }
            elseif (Test-Path -LiteralPath $includePath -PathType Leaf) {
                Read-FxConfig -Path $includePath
            }
            else {
                [void]$script:MissingIncludes.Add($include)
            }
            continue
        }

        $match = [regex]::Match($trimmed, '^(?:set|setr|sets)\s+(?<name>[A-Za-z0-9:_-]+)\s+(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s#]+))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $name = $match.Groups['name'].Value.ToLowerInvariant()
            $script:ConfigSettings[$name] = Get-ConfigTokenValue -Match $match
            $script:ConfigSettingOrder[$name] = $order
            continue
        }

        $match = [regex]::Match($trimmed, '^(?<name>sv_licenseKey|sv_hostname)\s+(?:"(?<double>[^"]*)"|''(?<single>[^'']*)''|(?<bare>[^\s#]+))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $name = $match.Groups['name'].Value.ToLowerInvariant()
            $script:ConfigSpecial[$name] = Get-ConfigTokenValue -Match $match
            $script:ConfigSpecialOrder[$name] = $order
            continue
        }

        $match = [regex]::Match($trimmed, '^endpoint_add_(?<protocol>tcp|udp)\s+(?:"(?<double>[^"]+)"|''(?<single>[^'']+)''|(?<bare>[^\s#]+))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            [void]$script:EndpointDirectives.Add([pscustomobject]@{
                Order = $order
                Protocol = $match.Groups['protocol'].Value.ToLowerInvariant()
                Value = Get-ConfigTokenValue -Match $match
            })
            continue
        }

        $match = [regex]::Match($trimmed, '^(?<command>ensure|start|stop)\s+(?:"(?<double>[^"]+)"|''(?<single>[^'']+)''|(?<bare>[^\s#]+))', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) {
            $directive = [pscustomobject]@{
                Order = $order
                Command = $match.Groups['command'].Value.ToLowerInvariant()
                Target = Get-ConfigTokenValue -Match $match
                Source = $fullPath
                Line = $lineNumber
            }
            if ($directive.Command -eq 'stop') {
                [void]$script:StopDirectives.Add($directive)
            }
            else {
                [void]$script:StartDirectives.Add($directive)
            }
        }
    }
}

function Test-DirectiveCoversResource {
    param(
        [string]$Target,
        [hashtable]$Resource
    )

    return $Target.Equals($Resource.Name, [System.StringComparison]::OrdinalIgnoreCase) -or $Target.Equals($Resource.Category, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ResourceStartOrder {
    param([hashtable]$Resource)

    $directive = $script:StartDirectives | Where-Object { Test-DirectiveCoversResource -Target $_.Target -Resource $Resource } | Sort-Object Order | Select-Object -First 1
    if ($directive) {
        return [int]$directive.Order
    }
    return $null
}

function ConvertFrom-MySqlConnectionString {
    param([string]$ConnectionString)

    if ([string]::IsNullOrWhiteSpace($ConnectionString)) {
        return $null
    }
    if ($ConnectionString -match '^(?i)mysql://') {
        try {
            $uri = [uri]$ConnectionString
            $userInfo = $uri.UserInfo
            $separator = $userInfo.IndexOf(':')
            if ($separator -lt 1) {
                return $null
            }
            $port = $uri.Port
            if ($port -lt 1) { $port = 3306 }
            return [pscustomobject]@{
                Host = $uri.DnsSafeHost
                Port = $port
                Database = [uri]::UnescapeDataString($uri.AbsolutePath.TrimStart('/'))
                User = [uri]::UnescapeDataString($userInfo.Substring(0, $separator))
                Password = [uri]::UnescapeDataString($userInfo.Substring($separator + 1))
            }
        }
        catch {
            return $null
        }
    }

    $parts = @{}
    foreach ($segment in $ConnectionString.Split(';')) {
        $separator = $segment.IndexOf('=')
        if ($separator -gt 0) {
            $parts[$segment.Substring(0, $separator).Trim().ToLowerInvariant()] = $segment.Substring($separator + 1).Trim()
        }
    }
    $hostName = ''
    foreach ($key in @('server', 'host', 'data source')) { if (-not $hostName -and $parts.ContainsKey($key)) { $hostName = $parts[$key] } }
    $user = ''
    foreach ($key in @('user', 'user id', 'uid', 'username')) { if (-not $user -and $parts.ContainsKey($key)) { $user = $parts[$key] } }
    $password = ''
    foreach ($key in @('password', 'pwd')) { if (-not $password -and $parts.ContainsKey($key)) { $password = $parts[$key] } }
    $database = ''
    foreach ($key in @('database', 'initial catalog')) { if (-not $database -and $parts.ContainsKey($key)) { $database = $parts[$key] } }
    $port = 3306
    if ($parts.ContainsKey('port')) {
        $parsedPort = 0
        if (-not [int]::TryParse($parts['port'], [ref]$parsedPort)) { return $null }
        $port = $parsedPort
    }
    if (-not $hostName -or -not $user -or -not $database) {
        return $null
    }
    return [pscustomobject]@{ Host = $hostName; Port = $port; Database = $database; User = $user; Password = $password }
}

function Test-SameDatabaseHost {
    param([string]$First, [string]$Second)

    $loopbackNames = @('127.0.0.1', 'localhost', '::1')
    if ($First -in $loopbackNames -and $Second -in $loopbackNames) {
        return $true
    }
    return $First.Equals($Second, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-PrivateOrLoopbackHost {
    param([string]$HostName)

    if ($HostName -in @('localhost', '127.0.0.1', '::1', $env:COMPUTERNAME)) {
        return $true
    }
    $address = $null
    if (-not [System.Net.IPAddress]::TryParse($HostName, [ref]$address)) {
        return $false
    }
    if ([System.Net.IPAddress]::IsLoopback($address)) {
        return $true
    }
    $bytes = $address.GetAddressBytes()
    if ($bytes.Length -eq 4) {
        return $bytes[0] -eq 10 -or ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) -or ($bytes[0] -eq 192 -and $bytes[1] -eq 168)
    }
    return ($bytes[0] -band 0xFE) -eq 0xFC
}

function Test-LoopbackAddress {
    param([string]$AddressText)

    if ($AddressText -in @('localhost', '127.0.0.1', '::1')) {
        return $true
    }
    $address = $null
    if (-not [System.Net.IPAddress]::TryParse($AddressText, [ref]$address)) {
        return $false
    }
    if ([System.Net.IPAddress]::IsLoopback($address)) {
        return $true
    }
    return $address.IsIPv4MappedToIPv6 -and [System.Net.IPAddress]::IsLoopback($address.MapToIPv4())
}

function Test-TxAdminOneSyncEnabled {
    param([string]$DataDirectory)

    if (-not $script:TxAdminManagedOneSync) {
        return $false
    }
    if (-not $DataDirectory) {
        $DataDirectory = Join-Path $script:RepositoryRoot 'txData'
    }
    $resolvedDataDirectory = if ([System.IO.Path]::IsPathRooted($DataDirectory)) {
        [System.IO.Path]::GetFullPath($DataDirectory)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $script:RepositoryRoot $DataDirectory))
    }
    $profileConfigPath = Join-Path $resolvedDataDirectory 'default\config.json'
    if (-not (Test-Path -LiteralPath $profileConfigPath -PathType Leaf)) {
        return $false
    }
    try {
        $profileConfig = [System.IO.File]::ReadAllText($profileConfigPath) | ConvertFrom-Json
        $serverProperty = $profileConfig.PSObject.Properties['server']
        if (-not $serverProperty) {
            return $false
        }
        $oneSyncProperty = $serverProperty.Value.PSObject.Properties['onesync']
        return (-not $oneSyncProperty) -or ([string]$oneSyncProperty.Value).Equals('on', [System.StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
}

function Test-HttpEndpoint {
    param(
        [uri]$Uri,
        [int]$TimeoutMilliseconds
    )

    $response = $null
    try {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.Method = 'GET'
        $request.AllowAutoRedirect = $false
        $request.Timeout = $TimeoutMilliseconds
        $request.ReadWriteTimeout = $TimeoutMilliseconds
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        return [pscustomobject]@{ Responded = $true; StatusCode = [int]$response.StatusCode }
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $response = [System.Net.HttpWebResponse]$_.Exception.Response
            return [pscustomobject]@{ Responded = $true; StatusCode = [int]$response.StatusCode }
        }
        return [pscustomobject]@{ Responded = $false; StatusCode = 0 }
    }
    catch {
        return [pscustomobject]@{ Responded = $false; StatusCode = 0 }
    }
    finally {
        if ($response) {
            $response.Close()
        }
    }
}

function Get-FxServerStartedResources {
    param(
        [int]$Port,
        [int]$TimeoutMilliseconds
    )

    $response = $null
    $reader = $null
    try {
        $uri = [uri]"http://127.0.0.1:$Port/info.json"
        $request = [System.Net.HttpWebRequest]::Create($uri)
        $request.Method = 'GET'
        $request.Timeout = $TimeoutMilliseconds
        $request.ReadWriteTimeout = $TimeoutMilliseconds
        $response = [System.Net.HttpWebResponse]$request.GetResponse()
        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        $document = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop
        $resourcesProperty = $document.PSObject.Properties['resources']
        if (-not $resourcesProperty) {
            return $null
        }
        return @($resourcesProperty.Value | ForEach-Object { [string]$_ })
    }
    catch {
        return $null
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($response) { $response.Close() }
    }
}

try {
    Write-Ok "Repository root: $script:RepositoryRoot"
    if ($PSVersionTable.PSVersion -lt [version]'5.1') {
        Write-FailStatus 'PowerShell 5.1 or newer is required.'
    }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        Write-FailStatus 'This script validates the supported Windows FXServer runtime.'
    }

    if (-not $EnvFile) { $EnvFile = Join-Path $script:RepositoryRoot '.env' } else { $EnvFile = Resolve-LocalPath -Path $EnvFile }
    $settings = @{}
    if (Test-Path -LiteralPath $EnvFile -PathType Leaf) {
        try {
            $settings = Read-DotEnv -Path $EnvFile
            Write-Ok '.env is present (values not displayed).'
            if (Test-GitIgnored -Path $EnvFile) {
                Write-Ok '.env is ignored by Git.'
            }
            else {
                Write-FailStatus '.env is inside the repository but is not ignored by Git.'
            }
            if (Test-GitTracked -Path $EnvFile) {
                Write-FailStatus '.env is tracked by Git; remove it from the index without displaying its contents.'
            }
        }
        catch {
            Write-FailStatus "The local environment file could not be read: $(Protect-Text -Text $_.Exception.Message)"
        }
    }
    else {
        Write-WarnStatus '.env is absent; configured process environment variables will be accepted.'
    }

    if (-not $DatabaseHost) { $DatabaseHost = Get-Setting -Name 'DB_HOST' -Settings $settings -DefaultValue '127.0.0.1' }
    if (-not $DatabaseName) { $DatabaseName = Get-Setting -Name 'DB_NAME' -Settings $settings -DefaultValue 'tarrant_rp_dev' }
    if (-not $DatabaseUser) { $DatabaseUser = Get-Setting -Name 'DB_USER' -Settings $settings -DefaultValue 'tarrant_rp' }
    if (-not $MariaDbServiceName) { $MariaDbServiceName = Get-Setting -Name 'MARIADB_SERVICE_NAME' -Settings $settings }
    if (-not $MariaDbClient) { $MariaDbClient = Get-Setting -Name 'MARIADB_CLIENT' -Settings $settings }
    if (-not $MariaDbClient) { $MariaDbClient = Get-Setting -Name 'MYSQL_BIN' -Settings $settings }
    if (-not $ResourcesDirectory) { $ResourcesDirectory = Get-Setting -Name 'QBOX_RESOURCES_DIR' -Settings $settings }
    if (-not $ServerConfig) { $ServerConfig = Get-Setting -Name 'FXSERVER_CONFIG' -Settings $settings }
    if (-not $TxDataDirectory) { $TxDataDirectory = Get-Setting -Name 'TXDATA_DIR' -Settings $settings }
    if (-not $TxAdminUrl) { $TxAdminUrl = Get-Setting -Name 'TXADMIN_URL' -Settings $settings -DefaultValue 'http://localhost:40120' }

    if ($DatabasePort -eq 0) {
        $portText = Get-Setting -Name 'DB_PORT' -Settings $settings -DefaultValue '3306'
        $parsedPort = 0
        if (-not [int]::TryParse($portText, [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535) {
            Write-FailStatus 'DB_PORT must be an integer from 1 through 65535.'
            $DatabasePort = 3306
        }
        else { $DatabasePort = $parsedPort }
    }

    $databasePassword = Get-Setting -Name 'DB_PASSWORD' -Settings $settings
    Add-Secret -Value $databasePassword
    Add-Secret -Value (Get-Setting -Name 'DB_ADMIN_PASSWORD' -Settings $settings)
    $environmentLicense = Get-Setting -Name 'FIVEM_LICENSE_KEY' -Settings $settings
    Add-Secret -Value $environmentLicense

    if (Test-Path -LiteralPath 'C:\xampp' -PathType Container) {
        Write-WarnStatus 'XAMPP is present but is excluded from all supported database discovery and readiness decisions.'
    }

    $clientPath = Get-MariaDbClientPath -RequestedPath $MariaDbClient
    if (-not $clientPath -or -not (Test-Path -LiteralPath $clientPath -PathType Leaf)) {
        Write-FailStatus 'A supported standalone MariaDB client was not found.'
        $clientPath = $null
    }
    elseif (Test-XamppPath -Path $clientPath) {
        Write-FailStatus 'The configured MariaDB client belongs to XAMPP, which Qbox does not support.'
        $clientPath = $null
    }
    else {
        $clientText = (& $clientPath --version 2>&1 | Out-String).Trim()
        $clientVersion = Get-MariaDbVersion -Text $clientText
        if (-not $clientVersion -or $clientVersion -lt [version]'10.9.0') {
            Write-FailStatus 'The standalone client is not MariaDB 10.9.0 or newer.'
        }
        else {
            Write-Ok "Standalone MariaDB client satisfies Qbox: $clientVersion."
        }
    }

    $service = Get-MariaDbServiceInfo -RequestedName $MariaDbServiceName
    if (-not $service) {
        if ($MariaDbServiceName) {
            Write-FailStatus "Configured MariaDB service '$MariaDbServiceName' was not found."
        }
        else {
            Write-WarnStatus 'No MariaDB Windows service was identified; a working supported endpoint can still satisfy readiness.'
        }
    }
    elseif (Test-XamppPath -Path $service.PathName) {
        Write-FailStatus "Database service '$($service.Name)' is backed by XAMPP and is unsupported."
    }
    elseif ($service.Status -ne 'Running') {
        Write-FailStatus "Database service '$($service.Name)' is $($service.Status)."
    }
    else {
        Write-Ok "MariaDB service '$($service.Name)' is Running (start type: $($service.StartType))."
    }

    $databaseReachable = Test-TcpEndpoint -HostName $DatabaseHost -Port $DatabasePort -TimeoutMilliseconds $ConnectTimeoutMilliseconds
    if ($databaseReachable) {
        Write-Ok "MariaDB TCP endpoint is reachable at ${DatabaseHost}:$DatabasePort."
    }
    else {
        Write-FailStatus "MariaDB TCP endpoint is not reachable at ${DatabaseHost}:$DatabasePort."
    }
    if ($DatabaseHost -in @('127.0.0.1', 'localhost', '::1')) {
        foreach ($listener in @(Get-LocalTcpListeners -Port $DatabasePort)) {
            if (Test-XamppPath -Path (Get-ProcessExecutablePath -ProcessId $listener.OwningProcess)) {
                Write-FailStatus "TCP port $DatabasePort is owned by an unsupported XAMPP database process."
            }
            if (-not (Test-LoopbackAddress -AddressText $listener.LocalAddress)) {
                Write-FailStatus "MariaDB port $DatabasePort is listening beyond loopback; the development database must remain local-only."
            }
        }
    }

    if (-not $databasePassword -or $databasePassword -eq 'CHANGE_ME') {
        Write-FailStatus 'DB_PASSWORD is not configured (the value was not displayed).'
    }
    elseif ($DatabaseUser -eq 'root') {
        Write-FailStatus 'The Qbox database account is root; a scoped application account is required.'
    }
    elseif ($clientPath -and $databaseReachable) {
        try {
            $serverVersionText = Invoke-MariaDbScalar -Client $clientPath -HostName $DatabaseHost -Port $DatabasePort -User $DatabaseUser -Password $databasePassword -Database $DatabaseName -Sql 'SELECT VERSION();'
            $serverVersion = Get-MariaDbVersion -Text $serverVersionText
            if (-not $serverVersion) {
                Write-FailStatus 'The configured endpoint is not MariaDB.'
            }
            elseif ($serverVersion -lt [version]'10.9.0') {
                Write-FailStatus "MariaDB server $serverVersion is below the required 10.9.0 minimum."
            }
            else {
                Write-Ok "Database connection verified for $DatabaseUser@${DatabaseHost}:$DatabasePort/$DatabaseName (MariaDB $serverVersion)."
                $requiredSchemaTables = @(
                    'players',
                    'bans',
                    'player_groups',
                    'player_mails',
                    'playerskins',
                    'player_outfits',
                    'management_outfits',
                    'player_outfit_codes',
                    'ox_doorlock',
                    'bank_accounts_new',
                    'player_transactions',
                    'player_vehicles'
                )
                $quotedTableNames = ($requiredSchemaTables | ForEach-Object { "'$_'" }) -join ','
                $schemaTableCount = Invoke-MariaDbScalar -Client $clientPath -HostName $DatabaseHost -Port $DatabasePort -User $DatabaseUser -Password $databasePassword -Database $DatabaseName -Sql "SELECT COUNT(DISTINCT table_name) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name IN ($quotedTableNames);"
                if ($schemaTableCount -eq $requiredSchemaTables.Count.ToString()) {
                    Write-Ok "All $($requiredSchemaTables.Count) required Qbox/OX schema tables are present."
                }
                else {
                    Write-FailStatus "Only $schemaTableCount of $($requiredSchemaTables.Count) required Qbox/OX schema tables are present; import the complete staged schema."
                }
            }
        }
        catch {
            Write-FailStatus "Application-user database verification failed: $(Protect-Text -Text $_.Exception.Message)"
        }
    }

    $resolvedFxServer = Get-FxServerPath -RequestedPath $FxServerExe -Settings $settings
    if (-not $resolvedFxServer) {
        Write-FailStatus 'FXServer.exe was not found; configure -FxServerExe or FXSERVER_EXE.'
    }
    else {
        Write-Ok "FXServer executable found: $resolvedFxServer"
    }

    if (-not $ResourcesDirectory) {
        $resourceCandidates = @(
            (Join-Path $script:RepositoryRoot 'runtime\qbox-server-data\resources'),
            (Join-Path $script:RepositoryRoot 'resources')
        )
        $ResourcesDirectory = $resourceCandidates | Where-Object {
            Test-Path -LiteralPath (Join-Path $_ '[qbx]\qbx_core') -PathType Container
        } | Select-Object -First 1
        if (-not $ResourcesDirectory) {
            $ResourcesDirectory = $resourceCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
        }
        if (-not $ResourcesDirectory) {
            $ResourcesDirectory = $resourceCandidates[0]
        }
    }
    else {
        $ResourcesDirectory = Resolve-LocalPath -Path $ResourcesDirectory
    }
    $resourceSpecs = @(
        @{ Name = 'ox_lib'; Category = '[ox]'; Relative = '[ox]\ox_lib' },
        @{ Name = 'oxmysql'; Category = '[ox]'; Relative = '[ox]\oxmysql' },
        @{ Name = 'ox_target'; Category = '[ox]'; Relative = '[ox]\ox_target' },
        @{ Name = 'ox_inventory'; Category = '[ox]'; Relative = '[ox]\ox_inventory' },
        @{ Name = 'qbx_core'; Category = '[qbx]'; Relative = '[qbx]\qbx_core' },
        @{ Name = 'qbx_vehicles'; Category = '[qbx]'; Relative = '[qbx]\qbx_vehicles' },
        @{ Name = 'qbx_spawn'; Category = '[qbx]'; Relative = '[qbx]\qbx_spawn' },
        @{ Name = 'qbx_hud'; Category = '[qbx]'; Relative = '[qbx]\qbx_hud' },
        @{ Name = 'illenium-appearance'; Category = '[standalone]'; Relative = '[standalone]\illenium-appearance' }
    )
    $resourcePaths = @{}
    if (-not (Test-Path -LiteralPath $ResourcesDirectory -PathType Container)) {
        Write-FailStatus "Resources directory does not exist: $ResourcesDirectory"
    }
    else {
        foreach ($spec in $resourceSpecs) {
            $resourcePath = Join-Path $ResourcesDirectory $spec.Relative
            $resourcePaths[$spec.Name] = $resourcePath
            if (-not (Test-Path -LiteralPath $resourcePath -PathType Container)) {
                Write-FailStatus "Required resource '$($spec.Name)' is missing from its official recipe directory."
                continue
            }
            $manifestPath = Join-Path $resourcePath 'fxmanifest.lua'
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
                Write-FailStatus "Required resource '$($spec.Name)' has no fxmanifest.lua."
            }
            else {
                $manifestContent = [System.IO.File]::ReadAllText($manifestPath)
                $hasGameDirective = $manifestContent -match '(?im)^\s*games?\s+'
                $supportsFxServerGame = $manifestContent -match '(?i)[''"](?:gta5|common)[''"]'
                if ($manifestContent -notmatch '(?im)^\s*fx_version\s+[''"]' -or -not $hasGameDirective -or -not $supportsFxServerGame) {
                    Write-FailStatus "Required resource '$($spec.Name)' has an invalid or incomplete fxmanifest.lua."
                }
                else {
                    Write-Ok "Resource and manifest present: $($spec.Name)."
                    if ($spec.Name -eq 'qbx_vehicles') {
                        $versionMatch = [regex]::Match($manifestContent, '(?im)^\s*version\s+[''"](?<version>\d+\.\d+(?:\.\d+)?)[''"]')
                        if (-not $versionMatch.Success -or [version]$versionMatch.Groups['version'].Value -lt [version]'1.2.0') {
                            Write-FailStatus 'qbx_vehicles 1.2.0 or newer is required by the staged ox_inventory release.'
                        }
                        else {
                            Write-Ok "qbx_vehicles satisfies ox_inventory: $($versionMatch.Groups['version'].Value)."
                        }
                    }
                }
            }
        }
        $customNamespace = Join-Path $ResourcesDirectory '[tarrant]'
        if (Test-Path -LiteralPath $customNamespace -PathType Container) {
            Write-Ok 'Custom [tarrant] resource namespace is present.'
        }
        else {
            Write-WarnStatus 'Custom [tarrant] resource namespace is not present in the selected server-data resources directory.'
        }
    }

    if (-not $ServerConfig) {
        foreach ($candidate in @(
            (Join-Path $script:RepositoryRoot 'runtime\qbox-server-data\server.cfg'),
            (Join-Path $script:RepositoryRoot 'server.cfg'),
            (Join-Path $script:RepositoryRoot 'config\server.cfg')
        )) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $ServerConfig = $candidate
                break
            }
        }
    }
    elseif ($ServerConfig) {
        $ServerConfig = Resolve-LocalPath -Path $ServerConfig
    }

    if (-not $ServerConfig -or -not (Test-Path -LiteralPath $ServerConfig -PathType Leaf)) {
        Write-FailStatus 'Operational server.cfg was not found; example/template configs do not satisfy readiness.'
    }
    else {
        Write-Ok "Startup config found: $ServerConfig"
        if (Test-GitTracked -Path $ServerConfig) {
            Write-FailStatus 'The operational server config is tracked by Git even though it contains local secrets.'
        }
        elseif ((Test-PathWithinRepository -Path $ServerConfig) -and -not (Test-GitIgnored -Path $ServerConfig)) {
            Write-FailStatus 'The operational server config is inside the repository but is not ignored by Git.'
        }
        else {
            Write-Ok 'Operational server config is outside Git tracking.'
        }

        try {
            Read-FxConfig -Path $ServerConfig
        }
        catch {
            Write-FailStatus "Startup config could not be parsed: $(Protect-Text -Text $_.Exception.Message)"
        }

        foreach ($missingInclude in $script:MissingIncludes) {
            Write-FailStatus "Startup config references missing include '$missingInclude'."
        }
        if ($script:TemplateTokens -gt 0) {
            Write-FailStatus 'Startup config still contains undeployed txAdmin template tokens.'
        }

        $unsafeConfigPaths = 0
        foreach ($configPath in $script:VisitedConfigs) {
            if (Test-GitTracked -Path $configPath) {
                $unsafeConfigPaths++
                Write-FailStatus "Operational config is tracked by Git: $configPath"
            }
            elseif ((Test-PathWithinRepository -Path $configPath) -and -not (Test-GitIgnored -Path $configPath)) {
                $unsafeConfigPaths++
                Write-FailStatus "Operational config is not ignored by Git: $configPath"
            }
        }
        if ($unsafeConfigPaths -eq 0 -and $script:VisitedConfigs.Count -gt 0) {
            Write-Ok "All $($script:VisitedConfigs.Count) operational config file(s) inspected are outside Git tracking."
        }

        if ($script:ConfigSpecial.ContainsKey('sv_hostname') -and $script:ConfigSpecial['sv_hostname'] -match '(?i)Tarrant County RP - Development') {
            Write-Ok 'Development server identity is configured.'
        }
        else {
            Write-FailStatus "sv_hostname does not use 'Tarrant County RP - Development'."
        }

        if (-not $script:ConfigSpecial.ContainsKey('sv_licensekey')) {
            Write-FailStatus 'sv_licenseKey is missing from the operational startup config.'
        }
        else {
            $license = [string]$script:ConfigSpecial['sv_licensekey']
            Add-Secret -Value $license
            if (-not $license -or $license -match '(?i)CHANGE_ME|\{\{|^none$') {
                Write-FailStatus 'Cfx server license key is still missing or a placeholder.'
            }
            else {
                Write-Ok 'Cfx server license key is configured (value redacted).'
                if ($environmentLicense -and $environmentLicense -ne 'CHANGE_ME' -and $environmentLicense -ne $license) {
                    Write-WarnStatus 'FIVEM_LICENSE_KEY differs from the operational config; the config value will be used.'
                }
            }
        }

        if (-not $script:ConfigSettings.ContainsKey('mysql_connection_string')) {
            Write-FailStatus 'mysql_connection_string is missing from the startup config; .env alone is not consumed by oxmysql.'
        }
        else {
            $connectionString = [string]$script:ConfigSettings['mysql_connection_string']
            if ($connectionString -match '(?i)CHANGE_ME|\{\{') {
                Write-FailStatus 'mysql_connection_string still contains a placeholder.'
            }
            else {
                $connectionInfo = ConvertFrom-MySqlConnectionString -ConnectionString $connectionString
                if (-not $connectionInfo) {
                    Write-FailStatus 'mysql_connection_string could not be safely parsed.'
                }
                else {
                    Add-Secret -Value $connectionInfo.Password
                    $connectionMatches = (Test-SameDatabaseHost -First $connectionInfo.Host -Second $DatabaseHost) -and
                        $connectionInfo.Port -eq $DatabasePort -and
                        $connectionInfo.Database -eq $DatabaseName -and
                        $connectionInfo.User -eq $DatabaseUser
                    if (-not $connectionMatches) {
                        Write-FailStatus 'mysql_connection_string does not target the configured Qbox host, port, database, and application user.'
                    }
                    elseif (-not $connectionInfo.Password) {
                        Write-FailStatus 'mysql_connection_string has no database password.'
                    }
                    elseif ($databasePassword -and $databasePassword -ne 'CHANGE_ME' -and $connectionInfo.Password -ne $databasePassword) {
                        Write-FailStatus 'mysql_connection_string password does not match DB_PASSWORD (values redacted).'
                    }
                    else {
                        Write-Ok 'oxmysql connection string targets the scoped application database (credentials redacted).'
                    }
                }
            }
        }

        if ($script:ConfigSettings.ContainsKey('inventory:framework') -and $script:ConfigSettings['inventory:framework'] -eq 'qbx') {
            Write-Ok 'ox_inventory framework is configured as qbx.'
        }
        else {
            Write-FailStatus 'Set inventory:framework to qbx before ox_inventory starts.'
        }

        $oneSyncEnabled = $script:ConfigSettings.ContainsKey('onesync') -and $script:ConfigSettings['onesync'] -eq 'on'
        if (-not $oneSyncEnabled) {
            $oneSyncEnabled = Test-TxAdminOneSyncEnabled -DataDirectory $TxDataDirectory
        }
        if ($oneSyncEnabled) {
            Write-Ok 'OneSync is enabled.'
        }
        else {
            Write-FailStatus 'OneSync must be set to on directly or through the active txAdmin profile.'
        }

        $startOrders = @{}
        foreach ($spec in $resourceSpecs) {
            $startOrder = Get-ResourceStartOrder -Resource $spec
            $startOrders[$spec.Name] = $startOrder
            if ($null -eq $startOrder) {
                Write-FailStatus "Startup config does not start '$($spec.Name)' directly or through '$($spec.Category)'."
            }
            else {
                Write-Ok "Startup config covers resource: $($spec.Name)."
                $laterStop = $script:StopDirectives | Where-Object { $_.Order -gt $startOrder -and (Test-DirectiveCoversResource -Target $_.Target -Resource $spec) } | Select-Object -First 1
                if ($laterStop) {
                    Write-FailStatus "Startup config stops required resource '$($spec.Name)' after starting it."
                }
            }
        }

        if ($null -ne $startOrders['ox_lib'] -and $null -ne $startOrders['qbx_core'] -and $startOrders['ox_lib'] -ge $startOrders['qbx_core']) {
            Write-FailStatus 'ox_lib must be ensured before qbx_core.'
        }
        if ($null -ne $startOrders['qbx_core'] -and $null -ne $startOrders['ox_inventory'] -and $startOrders['qbx_core'] -gt $startOrders['ox_inventory']) {
            Write-FailStatus 'qbx_core must be ensured before ox_inventory.'
        }
        if ($null -ne $startOrders['qbx_core'] -and $null -ne $startOrders['qbx_spawn'] -and $startOrders['qbx_core'] -gt $startOrders['qbx_spawn']) {
            Write-FailStatus 'qbx_core must be ensured before qbx_spawn.'
        }
        if ($null -ne $startOrders['qbx_core'] -and $null -ne $startOrders['qbx_vehicles'] -and $startOrders['qbx_core'] -gt $startOrders['qbx_vehicles']) {
            Write-FailStatus 'qbx_core must be ensured before qbx_vehicles.'
        }
        if ($null -ne $startOrders['qbx_vehicles'] -and $null -ne $startOrders['ox_inventory'] -and $startOrders['qbx_vehicles'] -gt $startOrders['ox_inventory']) {
            Write-FailStatus 'qbx_vehicles must be ensured before ox_inventory.'
        }
        if ($null -ne $startOrders['qbx_core'] -and $null -ne $startOrders['ox_target'] -and $startOrders['qbx_core'] -gt $startOrders['ox_target']) {
            Write-FailStatus 'qbx_core must be ensured before ox_target.'
        }
        if ($null -ne $startOrders['qbx_core'] -and $null -ne $startOrders['qbx_hud'] -and $startOrders['qbx_core'] -gt $startOrders['qbx_hud']) {
            Write-FailStatus 'qbx_core must be ensured before qbx_hud.'
        }

        if ($null -ne $startOrders['oxmysql'] -and $null -ne $startOrders['qbx_core'] -and $startOrders['oxmysql'] -gt $startOrders['qbx_core']) {
            $coreManifest = if ($resourcePaths.ContainsKey('qbx_core')) { Join-Path $resourcePaths['qbx_core'] 'fxmanifest.lua' } else { $null }
            if ($coreManifest -and (Test-Path -LiteralPath $coreManifest -PathType Leaf) -and [System.IO.File]::ReadAllText($coreManifest) -match '(?i)oxmysql') {
                Write-Ok 'qbx_core declares oxmysql as a manifest dependency; the official grouped startup order is valid.'
            }
            else {
                Write-FailStatus 'oxmysql is ordered after qbx_core without a detectable manifest dependency.'
            }
        }

        if ($script:ConfigSettings.ContainsKey('inventory:framework') -and $null -ne $startOrders['ox_inventory'] -and $script:ConfigSettingOrder['inventory:framework'] -gt $startOrders['ox_inventory']) {
            Write-FailStatus 'inventory:framework is set after ox_inventory starts.'
        }
        if ($script:ConfigSettings.ContainsKey('mysql_connection_string') -and $null -ne $startOrders['qbx_core'] -and $script:ConfigSettingOrder['mysql_connection_string'] -gt $startOrders['qbx_core']) {
            Write-FailStatus 'mysql_connection_string is set after qbx_core starts.'
        }

        foreach ($protocol in @('tcp', 'udp')) {
            $matchingEndpoint = $script:EndpointDirectives | Where-Object { $_.Protocol -eq $protocol -and $_.Value -match (':{0}$' -f $GamePort) } | Select-Object -First 1
            if (-not $matchingEndpoint) {
                Write-FailStatus "Startup config has no $protocol game endpoint on port $GamePort."
            }
            elseif ($matchingEndpoint.Value -notmatch ('^(?:127\.0\.0\.1|localhost|\[::1\]):{0}$' -f $GamePort)) {
                Write-FailStatus "The $protocol game endpoint must bind to loopback for this local development profile."
            }
            else {
                Write-Ok "The $protocol game endpoint is restricted to loopback port $GamePort."
            }
        }
    }

    if (-not $TxDataDirectory) {
        $TxDataDirectory = Join-Path $script:RepositoryRoot 'txData'
    }
    else {
        $TxDataDirectory = Resolve-LocalPath -Path $TxDataDirectory
    }
    if (-not (Test-Path -LiteralPath $TxDataDirectory -PathType Container)) {
        Write-FailStatus 'txAdmin data directory was not found; initial local profile setup has not been staged.'
    }
    elseif (Test-GitTracked -Path $TxDataDirectory) {
        Write-FailStatus 'txAdmin data is tracked by Git and may contain private authentication data.'
    }
    elseif ((Test-PathWithinRepository -Path $TxDataDirectory) -and -not (Test-GitIgnored -Path $TxDataDirectory)) {
        Write-FailStatus 'txAdmin data directory is inside the repository but is not ignored by Git.'
    }
    else {
        Write-Ok 'txAdmin data directory is present and outside Git tracking.'
    }

    $txUri = $null
    try { $txUri = [uri]$TxAdminUrl } catch { Write-FailStatus 'TXADMIN_URL is not a valid URI.' }
    if ($txUri -and (-not $txUri.IsAbsoluteUri -or $txUri.Scheme -notin @('http', 'https'))) {
        Write-FailStatus 'TXADMIN_URL must be an absolute HTTP or HTTPS URL.'
        $txUri = $null
    }
    if ($txUri -and -not (Test-PrivateOrLoopbackHost -HostName $txUri.DnsSafeHost)) {
        Write-FailStatus 'TXADMIN_URL is public; txAdmin must remain on localhost or a private development address.'
    }

    if ($SkipRuntimeChecks) {
        Write-WarnStatus 'FXServer process, game ports, and txAdmin HTTP checks were skipped explicitly.'
    }
    else {
        $fxProcesses = @(Get-Process -Name 'FXServer' -ErrorAction SilentlyContinue)
        if ($fxProcesses.Count -eq 0) {
            Write-FailStatus 'FXServer is not running.'
        }
        else {
            Write-Ok "FXServer process is running ($($fxProcesses.Count) process instance(s))."
            if ($resolvedFxServer) {
                $knownPaths = @($fxProcesses | ForEach-Object { try { $_.Path } catch { $null } } | Where-Object { $_ })
                if ($knownPaths.Count -gt 0 -and -not ($knownPaths | Where-Object { $_.Equals($resolvedFxServer, [System.StringComparison]::OrdinalIgnoreCase) })) {
                    Write-FailStatus 'The running FXServer process does not use the configured executable.'
                }
            }
        }
        $fxProcessIds = @($fxProcesses | ForEach-Object { $_.Id })

        $gameTcpListeners = @(Get-LocalTcpListeners -Port $GamePort)
        if ($gameTcpListeners.Count -eq 0 -and -not (Test-TcpEndpoint -HostName '127.0.0.1' -Port $GamePort -TimeoutMilliseconds $ConnectTimeoutMilliseconds)) {
            Write-FailStatus "FXServer TCP game port $GamePort is not listening."
        }
        else {
            Write-Ok "FXServer TCP game port $GamePort is listening."
            if ($fxProcessIds.Count -gt 0 -and $gameTcpListeners.Count -gt 0 -and -not ($gameTcpListeners | Where-Object { $_.OwningProcess -in $fxProcessIds })) {
                Write-FailStatus "TCP game port $GamePort is owned by a process other than FXServer."
            }
            if ($gameTcpListeners.Count -gt 0 -and ($gameTcpListeners | Where-Object { -not (Test-LoopbackAddress -AddressText $_.LocalAddress) })) {
                Write-FailStatus "TCP game port $GamePort is listening beyond loopback."
            }
        }

        if (Get-Command Get-NetUDPEndpoint -ErrorAction SilentlyContinue) {
            try {
                $gameUdpListeners = @(Get-NetUDPEndpoint -LocalPort $GamePort -ErrorAction Stop)
                if ($gameUdpListeners.Count -eq 0) {
                    Write-FailStatus "FXServer UDP game port $GamePort is not bound."
                }
                else {
                    Write-Ok "FXServer UDP game port $GamePort is bound."
                    if ($fxProcessIds.Count -gt 0 -and -not ($gameUdpListeners | Where-Object { $_.OwningProcess -in $fxProcessIds })) {
                        Write-FailStatus "UDP game port $GamePort is owned by a process other than FXServer."
                    }
                    if ($gameUdpListeners | Where-Object { -not (Test-LoopbackAddress -AddressText $_.LocalAddress) }) {
                        Write-FailStatus "UDP game port $GamePort is bound beyond loopback."
                    }
                }
            }
            catch {
                Write-WarnStatus 'UDP endpoint ownership could not be inspected; no readiness failure was inferred.'
            }
        }
        else {
            Write-WarnStatus 'Get-NetUDPEndpoint is unavailable; UDP ownership could not be inspected.'
        }

        if ($txUri) {
            $txPort = $txUri.Port
            $txListeners = @(Get-LocalTcpListeners -Port $txPort)
            if (-not (Test-TcpEndpoint -HostName $txUri.DnsSafeHost -Port $txPort -TimeoutMilliseconds $ConnectTimeoutMilliseconds)) {
                Write-FailStatus "txAdmin TCP endpoint is not reachable at $($txUri.Scheme)://$($txUri.Authority)."
            }
            else {
                Write-Ok "txAdmin TCP endpoint is reachable at $($txUri.Scheme)://$($txUri.Authority)."
                if ($fxProcessIds.Count -gt 0 -and $txListeners.Count -gt 0 -and -not ($txListeners | Where-Object { $_.OwningProcess -in $fxProcessIds })) {
                    Write-FailStatus "txAdmin port $txPort is owned by a process other than FXServer."
                }
                if ($txListeners.Count -gt 0 -and ($txListeners | Where-Object { -not (Test-LoopbackAddress -AddressText $_.LocalAddress) })) {
                    Write-FailStatus "txAdmin port $txPort is listening beyond loopback."
                }
                $httpResult = Test-HttpEndpoint -Uri $txUri -TimeoutMilliseconds $ConnectTimeoutMilliseconds
                if (-not $httpResult.Responded -or $httpResult.StatusCode -ge 500) {
                    Write-FailStatus 'txAdmin did not return a healthy local HTTP response.'
                }
                else {
                    Write-Ok "txAdmin HTTP responded locally (status $($httpResult.StatusCode))."
                }
            }
        }

        $startedResources = @(Get-FxServerStartedResources -Port $GamePort -TimeoutMilliseconds $ConnectTimeoutMilliseconds)
        if ($startedResources.Count -eq 0) {
            Write-FailStatus 'FXServer info.json did not provide resource state; Qbox resources are not proven started.'
        }
        else {
            foreach ($spec in $resourceSpecs) {
                if ($spec.Name -in $startedResources) {
                    Write-Ok "Runtime resource started: $($spec.Name)."
                }
                else {
                    Write-FailStatus "Required resource '$($spec.Name)' is installed/configured but not reported started by FXServer."
                }
            }
        }
    }
}
catch {
    Write-FailStatus "Qbox readiness check could not complete: $(Protect-Text -Text $_.Exception.Message)"
}

if ($script:Failures -gt 0) {
    $scope = if ($SkipRuntimeChecks) { 'static readiness' } else { 'operational readiness' }
    Write-Host "Qbox ${scope}: FAIL ($($script:Failures) required issue(s))"
    exit 1
}

if ($SkipRuntimeChecks) {
    Write-Host 'Qbox static readiness: PASS (runtime processes, ports, and started resources were not verified)'
}
else {
    Write-Host 'Qbox operational readiness: PASS (required resources are reported started)'
}
exit 0
