#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$EnvFile,
    [string]$MariaDbClient,
    [string]$AdminUser,
    [string]$AdminPassword,
    [string]$DatabaseName,
    [string]$DatabaseUser,
    [string]$DatabasePassword,
    [string]$DatabaseHost = '127.0.0.1',
    [ValidateRange(1, 65535)]
    [int]$DatabasePort = 3306
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $EnvFile) {
    $EnvFile = Join-Path $script:RepositoryRoot '.env'
}
$EnvFile = [System.IO.Path]::GetFullPath($EnvFile)
$envExample = Join-Path $script:RepositoryRoot '.env.example'

function Write-Status {
    param([string]$Message)
    Write-Host "[ok] $Message"
}

function Read-DotEnv {
    param([string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $values
    }

    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*#' -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $values[$matches[1]] = $matches[2]
        }
    }

    return $values
}

function Set-DotEnvValue {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Value
    )

    if ($Value -match '[\r\n]') {
        throw "Environment value for $Name contains a newline."
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            [void]$lines.Add($line)
        }
    }

    $updated = $false
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match ('^' + [regex]::Escape($Name) + '=')) {
            $lines[$index] = "$Name=$Value"
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        [void]$lines.Add("$Name=$Value")
    }

    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Protect-SecretFile {
    param([string]$Path)

    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $security = [System.IO.File]::GetAccessControl($Path)
        $security.SetAccessRuleProtection($true, $false)
        foreach ($existingRule in @($security.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))) {
            $security.RemoveAccessRuleSpecific($existingRule)
        }

        $fullControl = [System.Security.AccessControl.FileSystemRights]::FullControl
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($identity.User, $fullControl, $allow))

        foreach ($sidType in @(
            [System.Security.Principal.WellKnownSidType]::LocalSystemSid,
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid
        )) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new($sidType, $null)
            $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid, $fullControl, $allow))
        }

        [System.IO.File]::SetAccessControl($Path, $security)
    }
    catch {
        Write-Warning "Could not tighten the ACL on ${Path}: $($_.Exception.Message)"
    }
}

function New-LocalPassword {
    $bytes = [byte[]]::new(32)
    $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $random.GetBytes($bytes)
    }
    finally {
        $random.Dispose()
    }
    return ([System.BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
}

function Find-MariaDbClient {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        $resolved = (Resolve-Path -LiteralPath $RequestedPath -ErrorAction Stop).Path
        if ($resolved -like 'C:\xampp\*') {
            throw 'The XAMPP MariaDB client/runtime is not supported for Qbox.'
        }
        return $resolved
    }

    foreach ($commandName in @('mariadb.exe', 'mysql.exe')) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command -and $command.Source -notlike 'C:\xampp\*') {
            return $command.Source
        }
    }

    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $candidates = @(Get-ChildItem -Path $programFiles -Directory -Filter 'MariaDB *' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
            Join-Path $_.FullName 'bin\mariadb.exe'
            Join-Path $_.FullName 'bin\mysql.exe'
        } |
        Where-Object { Test-Path -LiteralPath $_ })

    if ($candidates.Count -eq 0) {
        throw 'A supported standalone MariaDB client was not found. Install MariaDB 10.9 or newer first.'
    }

    return $candidates[0]
}

function Assert-SafeSqlName {
    param([string]$Label, [string]$Value)
    if ($Value -notmatch '^[A-Za-z0-9_]+$') {
        throw "$Label must contain only letters, numbers, and underscores."
    }
}

function Assert-SafePassword {
    param([string]$Label, [string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value -eq 'CHANGE_ME') {
        throw "$Label is not configured."
    }
    if ($Value -notmatch '^[A-Za-z0-9_-]{24,128}$') {
        throw "$Label must be 24-128 characters using only letters, numbers, underscore, or hyphen."
    }
}

function Invoke-MariaDb {
    param(
        [string]$Client,
        [string]$User,
        [string]$Password,
        [string]$HostName,
        [int]$Port,
        [string]$Sql,
        [string]$DefaultDatabase
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    [void]$arguments.Add('--protocol=tcp')
    [void]$arguments.Add("--host=$HostName")
    [void]$arguments.Add("--port=$Port")
    [void]$arguments.Add("--user=$User")
    [void]$arguments.Add('--batch')
    [void]$arguments.Add('--skip-column-names')
    if ($DefaultDatabase) {
        [void]$arguments.Add("--database=$DefaultDatabase")
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Client
    $startInfo.Arguments = $arguments -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $Password

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw 'MariaDB client could not be started.'
        }

        # SQL can contain generated credentials. Keep it off the process command
        # line and drain both output streams asynchronously to avoid deadlocks.
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($Sql)
        if (-not $Sql.EndsWith("`n")) {
            $process.StandardInput.WriteLine()
        }
        $process.StandardInput.Close()
        $process.WaitForExit()

        $stdout = $stdoutTask.Result
        [void]$stderrTask.Result
        if ($process.ExitCode -ne 0) {
            throw "MariaDB command failed with exit code $($process.ExitCode); client output was suppressed to protect credentials."
        }

        return @($stdout -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    finally {
        $process.Dispose()
    }
}

$repositoryPrefix = $script:RepositoryRoot.TrimEnd('\') + '\'
$envFileInsideRepository = $EnvFile.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)
if ($envFileInsideRepository) {
    $relativeEnvFile = $EnvFile.Substring($repositoryPrefix.Length).Replace('\', '/')
    $trackedEnvFile = @(& git -C $script:RepositoryRoot ls-files -- $relativeEnvFile)
    if ($LASTEXITCODE -ne 0) {
        throw 'Git could not verify the environment-file tracking state.'
    }
    if ($trackedEnvFile.Count -gt 0) {
        throw "Refusing to store database credentials in tracked file: $relativeEnvFile"
    }
    & git -C $script:RepositoryRoot check-ignore --quiet --no-index -- $relativeEnvFile
    if ($LASTEXITCODE -ne 0) {
        throw "Environment file must be ignored by Git before credentials are written: $relativeEnvFile"
    }
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    if (-not (Test-Path -LiteralPath $envExample)) {
        throw ".env.example was not found at $envExample"
    }
    Copy-Item -LiteralPath $envExample -Destination $EnvFile
    Write-Status 'Created ignored local .env from .env.example'
}

$settings = Read-DotEnv -Path $EnvFile

if (-not $AdminUser) { $AdminUser = if ($env:DB_ADMIN_USER) { $env:DB_ADMIN_USER } elseif ($settings.DB_ADMIN_USER) { $settings.DB_ADMIN_USER } else { 'root' } }
if (-not $AdminPassword) { $AdminPassword = if ($env:DB_ADMIN_PASSWORD) { $env:DB_ADMIN_PASSWORD } elseif ($settings.DB_ADMIN_PASSWORD) { $settings.DB_ADMIN_PASSWORD } else { '' } }
if (-not $DatabaseName) { $DatabaseName = if ($env:DB_NAME) { $env:DB_NAME } elseif ($settings.DB_NAME) { $settings.DB_NAME } else { 'tarrant_rp_dev' } }
if (-not $DatabaseUser) { $DatabaseUser = if ($env:DB_USER) { $env:DB_USER } elseif ($settings.DB_USER) { $settings.DB_USER } else { 'tarrant_rp' } }
if (-not $DatabasePassword) { $DatabasePassword = if ($env:DB_PASSWORD -and $env:DB_PASSWORD -ne 'CHANGE_ME') { $env:DB_PASSWORD } elseif ($settings.DB_PASSWORD -and $settings.DB_PASSWORD -ne 'CHANGE_ME') { $settings.DB_PASSWORD } else { New-LocalPassword } }

Assert-SafeSqlName -Label 'Database name' -Value $DatabaseName
Assert-SafeSqlName -Label 'Database user' -Value $DatabaseUser
Assert-SafeSqlName -Label 'Admin user' -Value $AdminUser
Assert-SafePassword -Label 'Database password' -Value $DatabasePassword
Assert-SafePassword -Label 'Database admin password' -Value $AdminPassword

$client = Find-MariaDbClient -RequestedPath $MariaDbClient
$clientVersion = (& $client --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $clientVersion -notmatch 'MariaDB') {
    throw "Unsupported database client: $clientVersion"
}
$clientVersionMatch = [regex]::Match($clientVersion, '(?<major>\d+)\.(?<minor>\d+)(?:\.\d+)?-MariaDB')
if (-not $clientVersionMatch.Success) {
    throw "Could not parse the MariaDB client version: $clientVersion"
}
$clientMajor = [int]$clientVersionMatch.Groups['major'].Value
$clientMinor = [int]$clientVersionMatch.Groups['minor'].Value
if (($clientMajor -lt 10) -or (($clientMajor -eq 10) -and ($clientMinor -lt 9))) {
    throw "Qbox requires MariaDB 10.9.0 or newer; client reports $clientVersion"
}

$serverVersionOutput = Invoke-MariaDb -Client $client -User $AdminUser -Password $AdminPassword -HostName $DatabaseHost -Port $DatabasePort -Sql 'SELECT VERSION();'
$serverVersion = ($serverVersionOutput | Select-Object -First 1).ToString().Trim()
if ($serverVersion -notmatch 'MariaDB') {
    throw "The service on ${DatabaseHost}:$DatabasePort is not a supported MariaDB server: $serverVersion"
}
$serverVersionMatch = [regex]::Match($serverVersion, '^(?<major>\d+)\.(?<minor>\d+)')
if (-not $serverVersionMatch.Success) {
    throw "Could not parse the MariaDB server version: $serverVersion"
}
$serverMajor = [int]$serverVersionMatch.Groups['major'].Value
$serverMinor = [int]$serverVersionMatch.Groups['minor'].Value
if (($serverMajor -lt 10) -or (($serverMajor -eq 10) -and ($serverMinor -lt 9))) {
    throw "Qbox requires MariaDB 10.9.0 or newer; server reports $serverVersion"
}

$sql = @"
CREATE DATABASE IF NOT EXISTS ``$DatabaseName`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DatabaseUser'@'localhost' IDENTIFIED BY '$DatabasePassword';
ALTER USER '$DatabaseUser'@'localhost' IDENTIFIED BY '$DatabasePassword';
CREATE USER IF NOT EXISTS '$DatabaseUser'@'127.0.0.1' IDENTIFIED BY '$DatabasePassword';
ALTER USER '$DatabaseUser'@'127.0.0.1' IDENTIFIED BY '$DatabasePassword';
GRANT ALL PRIVILEGES ON ``$DatabaseName``.* TO '$DatabaseUser'@'localhost';
GRANT ALL PRIVILEGES ON ``$DatabaseName``.* TO '$DatabaseUser'@'127.0.0.1';
FLUSH PRIVILEGES;
"@

[void](Invoke-MariaDb -Client $client -User $AdminUser -Password $AdminPassword -HostName $DatabaseHost -Port $DatabasePort -Sql $sql)

$verification = @(Invoke-MariaDb -Client $client -User $DatabaseUser -Password $DatabasePassword -HostName $DatabaseHost -Port $DatabasePort -DefaultDatabase $DatabaseName -Sql 'SELECT DATABASE(), CURRENT_USER(), VERSION();')
if ($verification.Count -eq 0) {
    throw 'The application-account connectivity check returned no result.'
}

Set-DotEnvValue -Path $EnvFile -Name 'DB_HOST' -Value $DatabaseHost
Set-DotEnvValue -Path $EnvFile -Name 'DB_PORT' -Value $DatabasePort.ToString()
Set-DotEnvValue -Path $EnvFile -Name 'DB_NAME' -Value $DatabaseName
Set-DotEnvValue -Path $EnvFile -Name 'DB_USER' -Value $DatabaseUser
Set-DotEnvValue -Path $EnvFile -Name 'DB_PASSWORD' -Value $DatabasePassword
Set-DotEnvValue -Path $EnvFile -Name 'DB_ADMIN_USER' -Value $AdminUser
Set-DotEnvValue -Path $EnvFile -Name 'DB_ADMIN_PASSWORD' -Value $AdminPassword
Protect-SecretFile -Path $EnvFile

Write-Status "MariaDB server version: $serverVersion"
Write-Status "Database ready: $DatabaseName"
Write-Status "Application account verified: $DatabaseUser@$DatabaseHost"
if ($envFileInsideRepository) {
    Write-Status 'Credentials stored only in an ignored local environment file (values not displayed)'
}
else {
    Write-Status 'Credentials stored in a protected environment file outside this repository (values not displayed)'
}
