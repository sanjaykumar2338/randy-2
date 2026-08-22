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
    [string]$TxAdminUrl,
    [ValidateRange(1, 65535)]
    [int]$GamePort = 30120,
    [ValidateRange(250, 30000)]
    [int]$ConnectTimeoutMilliseconds = 1500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$script:Failures = 0
$script:Secrets = [System.Collections.Generic.List[string]]::new()

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

    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($commandName in @('mariadb.exe', 'mysql.exe')) {
        foreach ($command in @(Get-Command $commandName -All -ErrorAction SilentlyContinue)) {
            if ($command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
                [void]$candidatePaths.Add($command.Source)
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
                    [void]$candidatePaths.Add($candidate)
                }
            }
        }
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $supported = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in $candidatePaths) {
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
        if ([string]::IsNullOrWhiteSpace($RequestedName)) {
            $cimServices = @($services | Where-Object { $_.Name -match '(?i)maria|mysql' -or $_.DisplayName -match '(?i)maria|mysql' } | ForEach-Object {
                $serviceRegistry = Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$($_.Name)" -ErrorAction Stop
                [pscustomobject]@{ Name = $_.Name; PathName = [string]$serviceRegistry.ImagePath }
            })
        }
        else {
            $serviceRegistry = Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$RequestedName" -ErrorAction Stop
            $cimServices = @([pscustomobject]@{ Name = $RequestedName; PathName = [string]$serviceRegistry.ImagePath })
        }
    }
    catch {
        $cimServices = @()
    }

    if (-not [string]::IsNullOrWhiteSpace($RequestedName)) {
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
        $service = $supportedCandidates | Sort-Object @{ Expression = { if ($_.Status -eq 'Running') { 0 } else { 1 } } }, @{ Expression = { if ($_.Name -eq 'TarrantMariaDB') { 0 } else { 1 } } }, Name | Select-Object -First 1
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
        DisplayName = $service.DisplayName
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
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }
        $client.EndConnect($asyncResult)
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
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        return [string]$process.Path
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
        if (-not [string]::IsNullOrWhiteSpace($Database)) {
            $arguments += "--database=$Database"
        }
        $arguments += @('--execute', $Sql)
        $output = @(& $Client @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        if ($exitCode -ne 0) {
            $message = Protect-Text -Text (($output | Out-String).Trim())
            if ([string]::IsNullOrWhiteSpace($message)) {
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

function Get-FxServerPath {
    param(
        [string]$RequestedPath,
        [hashtable]$Settings
    )

    $configured = $RequestedPath
    if ([string]::IsNullOrWhiteSpace($configured)) {
        $configured = Get-Setting -Name 'FXSERVER_EXE' -Settings $Settings
    }
    if (-not [string]::IsNullOrWhiteSpace($configured) -and $configured -notmatch '(?i)^/path/to/|CHANGE_ME') {
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

try {
    Write-Ok "Repository root: $script:RepositoryRoot"

    $osCaption = [Environment]::OSVersion.VersionString
    $osVersion = [Environment]::OSVersion.Version.ToString()
    $architecture = $env:PROCESSOR_ARCHITECTURE
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $osCaption = $os.Caption
        $osVersion = $os.Version
        $architecture = $os.OSArchitecture
    }
    catch {
        # The managed API values above are sufficient when CIM is restricted.
    }
    Write-Ok "Windows: $osCaption ($osVersion), $architecture"

    if ($PSVersionTable.PSVersion -ge [version]'5.1') {
        Write-Ok "PowerShell: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    }
    else {
        Write-FailStatus 'PowerShell 5.1 or newer is required.'
    }

    $driveRoot = [System.IO.Path]::GetPathRoot($script:RepositoryRoot)
    try {
        $driveName = $driveRoot.TrimEnd('\').TrimEnd(':')
        $drive = Get-PSDrive -Name $driveName -ErrorAction Stop
        if ($null -eq $drive.Free) {
            throw 'Free-space data is unavailable.'
        }
        Write-Ok ('Repository drive free space: {0:N1} GiB' -f ($drive.Free / 1GB))
    }
    catch {
        Write-WarnStatus 'Could not determine free space for the repository drive.'
    }

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $git) {
        $git = Get-Command git -ErrorAction SilentlyContinue
    }
    if (-not $git) {
        Write-FailStatus 'Git is not installed or is not on PATH.'
    }
    else {
        $gitVersion = (& $git.Source --version 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Git: $gitVersion"
        }
        else {
            Write-FailStatus 'Git was found but could not be executed.'
        }
        & $git.Source -C $script:RepositoryRoot rev-parse --is-inside-work-tree *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'Git repository detected.'
            $statusLines = @(& $git.Source -C $script:RepositoryRoot status --porcelain --untracked-files=all 2>$null)
            if ($LASTEXITCODE -eq 0) {
                $changedCount = @($statusLines | Where-Object { $_ -notmatch '^\?\?' }).Count
                $untrackedCount = @($statusLines | Where-Object { $_ -match '^\?\?' }).Count
                Write-Info "Git worktree: $changedCount changed, $untrackedCount untracked (a dirty worktree is allowed)."
            }
        }
        else {
            Write-FailStatus 'The resolved repository root is not a Git worktree.'
        }
    }

    if (-not $EnvFile) {
        $EnvFile = Join-Path $script:RepositoryRoot '.env'
    }
    else {
        $EnvFile = Resolve-LocalPath -Path $EnvFile
    }

    $settings = @{}
    if (Test-Path -LiteralPath $EnvFile -PathType Leaf) {
        try {
            $settings = Read-DotEnv -Path $EnvFile
            Write-Ok 'Local environment file found (values not displayed).'
        }
        catch {
            Write-FailStatus "Local environment file could not be read: $(Protect-Text -Text $_.Exception.Message)"
        }
    }
    else {
        Write-WarnStatus 'Local .env file is absent; process environment variables may be used instead.'
    }

    if (-not $DatabaseHost) { $DatabaseHost = Get-Setting -Name 'DB_HOST' -Settings $settings -DefaultValue '127.0.0.1' }
    if (-not $DatabaseName) { $DatabaseName = Get-Setting -Name 'DB_NAME' -Settings $settings -DefaultValue 'tarrant_rp_dev' }
    if (-not $DatabaseUser) { $DatabaseUser = Get-Setting -Name 'DB_USER' -Settings $settings -DefaultValue 'tarrant_rp' }
    if (-not $MariaDbServiceName) { $MariaDbServiceName = Get-Setting -Name 'MARIADB_SERVICE_NAME' -Settings $settings }
    if (-not $MariaDbClient) { $MariaDbClient = Get-Setting -Name 'MARIADB_CLIENT' -Settings $settings }
    if (-not $MariaDbClient) { $MariaDbClient = Get-Setting -Name 'MYSQL_BIN' -Settings $settings }
    if (-not $TxAdminUrl) { $TxAdminUrl = Get-Setting -Name 'TXADMIN_URL' -Settings $settings -DefaultValue 'http://localhost:40120' }

    if ($DatabasePort -eq 0) {
        $configuredPort = Get-Setting -Name 'DB_PORT' -Settings $settings -DefaultValue '3306'
        $parsedPort = 0
        if (-not [int]::TryParse($configuredPort, [ref]$parsedPort) -or $parsedPort -lt 1 -or $parsedPort -gt 65535) {
            Write-FailStatus 'DB_PORT must be an integer from 1 through 65535.'
            $DatabasePort = 3306
        }
        else {
            $DatabasePort = $parsedPort
        }
    }

    $databasePassword = Get-Setting -Name 'DB_PASSWORD' -Settings $settings
    Add-Secret -Value $databasePassword
    Add-Secret -Value (Get-Setting -Name 'DB_ADMIN_PASSWORD' -Settings $settings)
    Add-Secret -Value (Get-Setting -Name 'FIVEM_LICENSE_KEY' -Settings $settings)

    if (Test-Path -LiteralPath 'C:\xampp' -PathType Container) {
        Write-WarnStatus 'XAMPP is installed, but its bundled MariaDB/MySQL is excluded from the supported Qbox runtime.'
    }

    $clientPath = Get-MariaDbClientPath -RequestedPath $MariaDbClient
    if (-not $clientPath) {
        Write-FailStatus 'A supported standalone MariaDB client was not found (MariaDB 10.9+ is required; XAMPP is not supported).'
    }
    elseif (Test-XamppPath -Path $clientPath) {
        Write-FailStatus 'The configured database client belongs to XAMPP and cannot be used for Qbox readiness.'
        $clientPath = $null
    }
    elseif (-not (Test-Path -LiteralPath $clientPath -PathType Leaf)) {
        Write-FailStatus 'The configured standalone MariaDB client does not exist.'
        $clientPath = $null
    }
    else {
        $clientVersionText = (& $clientPath --version 2>&1 | Out-String).Trim()
        $clientVersion = Get-MariaDbVersion -Text $clientVersionText
        if ($LASTEXITCODE -ne 0 -or -not $clientVersion) {
            Write-FailStatus 'The selected client is not a supported MariaDB client.'
            $clientPath = $null
        }
        elseif ($clientVersion -lt [version]'10.9.0') {
            Write-FailStatus "MariaDB client $clientVersion is below the Qbox minimum 10.9.0."
        }
        else {
            Write-Ok "Standalone MariaDB client: $clientVersion ($clientPath)"
        }
    }

    $serviceInfo = Get-MariaDbServiceInfo -RequestedName $MariaDbServiceName
    if (-not $serviceInfo) {
        if ($MariaDbServiceName) {
            Write-FailStatus "Configured MariaDB service '$MariaDbServiceName' was not found."
        }
        else {
            Write-WarnStatus 'No MariaDB Windows service was detected; database connectivity will determine readiness.'
        }
    }
    else {
        if (Test-XamppPath -Path $serviceInfo.PathName) {
            Write-FailStatus "MariaDB service '$($serviceInfo.Name)' is backed by XAMPP and is not supported for Qbox."
        }
        elseif ($serviceInfo.Status -ne 'Running') {
            Write-FailStatus "MariaDB service '$($serviceInfo.Name)' is $($serviceInfo.Status)."
        }
        else {
            Write-Ok "MariaDB service: $($serviceInfo.Name) is Running (start type: $($serviceInfo.StartType))."
        }
    }

    $isLocalDatabase = $DatabaseHost -in @('127.0.0.1', 'localhost', '::1')
    $databasePortOpen = Test-TcpEndpoint -HostName $DatabaseHost -Port $DatabasePort -TimeoutMilliseconds $ConnectTimeoutMilliseconds
    if ($databasePortOpen) {
        Write-Ok "Database TCP endpoint is listening at ${DatabaseHost}:$DatabasePort."
    }
    else {
        Write-FailStatus "Database TCP endpoint is not reachable at ${DatabaseHost}:$DatabasePort."
    }

    if ($isLocalDatabase) {
        foreach ($listener in @(Get-LocalTcpListeners -Port $DatabasePort)) {
            $ownerPath = Get-ProcessExecutablePath -ProcessId $listener.OwningProcess
            if (Test-XamppPath -Path $ownerPath) {
                Write-FailStatus "TCP port $DatabasePort is owned by an unsupported XAMPP database process."
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($databasePassword) -or $databasePassword -eq 'CHANGE_ME') {
        Write-FailStatus 'DB_PASSWORD is not configured (the value was not displayed).'
    }
    elseif ($DatabaseUser -eq 'root') {
        Write-FailStatus 'Qbox must use the dedicated application database account, not root.'
    }
    elseif ($clientPath -and $databasePortOpen) {
        try {
            $serverVersionText = Invoke-MariaDbScalar -Client $clientPath -HostName $DatabaseHost -Port $DatabasePort -User $DatabaseUser -Password $databasePassword -Database $DatabaseName -Sql 'SELECT VERSION();'
            $serverVersion = Get-MariaDbVersion -Text $serverVersionText
            if (-not $serverVersion) {
                Write-FailStatus 'The configured database endpoint did not identify itself as MariaDB.'
            }
            elseif ($serverVersion -lt [version]'10.9.0') {
                Write-FailStatus "MariaDB server $serverVersion is below the Qbox minimum 10.9.0."
            }
            else {
                Write-Ok "Application-user database connection verified for $DatabaseUser@${DatabaseHost}:$DatabasePort/$DatabaseName."
                Write-Ok "MariaDB server version satisfies Qbox: $serverVersion."
            }
        }
        catch {
            Write-FailStatus "Application-user database connection failed: $(Protect-Text -Text $_.Exception.Message)"
        }
    }

    foreach ($toolName in @('node.exe', 'npm.cmd')) {
        $tool = Get-Command $toolName -ErrorAction SilentlyContinue
        if ($tool) {
            $toolVersion = (& $tool.Source --version 2>&1 | Out-String).Trim()
            Write-Ok "$($toolName.Replace('.exe', '').Replace('.cmd', '')): $toolVersion"
        }
        else {
            Write-WarnStatus "$toolName was not found; it is optional for a prebuilt Qbox runtime."
        }
    }

    $vcRuntimePath = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::System)) 'vcruntime140.dll'
    if (Test-Path -LiteralPath $vcRuntimePath -PathType Leaf) {
        $vcVersion = (Get-Item -LiteralPath $vcRuntimePath).VersionInfo.FileVersion
        Write-Ok "Microsoft Visual C++ runtime detected ($vcVersion)."
    }
    else {
        Write-WarnStatus 'Microsoft Visual C++ 2015-2022 runtime was not detected; FXServer may require it.'
    }

    $resolvedFxServer = Get-FxServerPath -RequestedPath $FxServerExe -Settings $settings
    if ($resolvedFxServer) {
        Write-Ok "FXServer executable found: $resolvedFxServer"
    }
    else {
        Write-WarnStatus 'FXServer.exe was not found in the configured or repo-relative runtime paths.'
    }

    if (@(Get-LocalTcpListeners -Port $GamePort).Count -gt 0) {
        Write-Ok "FXServer TCP game port $GamePort is listening."
    }
    else {
        Write-WarnStatus "FXServer TCP game port $GamePort is not listening (expected before server startup)."
    }

    $txUri = $null
    try {
        $txUri = [uri]$TxAdminUrl
    }
    catch {
        Write-WarnStatus 'TXADMIN_URL is not a valid URI.'
    }
    if ($txUri -and $txUri.IsAbsoluteUri) {
        $txPort = $txUri.Port
        if (Test-TcpEndpoint -HostName $txUri.DnsSafeHost -Port $txPort -TimeoutMilliseconds $ConnectTimeoutMilliseconds) {
            Write-Ok "txAdmin TCP endpoint is reachable at $($txUri.Scheme)://$($txUri.Authority)."
        }
        else {
            Write-WarnStatus "txAdmin is not reachable at $($txUri.Scheme)://$($txUri.Authority) (expected before FXServer startup)."
        }
    }

    $fiveMPaths = @(
        (Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.exe'),
        (Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.app\FiveM.exe'),
        (Join-Path $env:LOCALAPPDATA 'FiveM for GTAV Enhanced\FiveM.exe'),
        (Join-Path $env:LOCALAPPDATA 'FiveM for GTAV Enhanced\FiveM.app\FiveM.exe')
    )
    $fiveMPath = $fiveMPaths | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if ($fiveMPath) {
        Write-Ok "FiveM client detected: $fiveMPath"
    }
    else {
        Write-WarnStatus 'FiveM client was not detected in the current user profile; gameplay testing may require manual installation or another machine.'
    }
}
catch {
    Write-FailStatus "Environment check could not complete: $(Protect-Text -Text $_.Exception.Message)"
}

if ($script:Failures -gt 0) {
    Write-Host "Environment check: FAIL ($($script:Failures) required issue(s))"
    exit 1
}

Write-Host 'Environment check: PASS'
exit 0
