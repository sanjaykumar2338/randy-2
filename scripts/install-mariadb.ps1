#Requires -Version 5.1

[CmdletBinding()]
param(
    [ValidateSet('Ensure', 'RecoverEmptyInstance')]
    [string]$Mode = 'Ensure',
    [string]$PackageVersion = '12.3.2.0',
    [string]$ServiceName = 'TarrantMariaDB',
    [ValidateRange(1, 65535)]
    [int]$Port = 3306
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtimeDirectory = Join-Path $repositoryRoot 'runtime'
$logPath = Join-Path $runtimeDirectory 'install-mariadb.log'
$officialMsiUrl = 'https://dlm.mariadb.com/4716006/MariaDB/mariadb-12.3.2/winx64-packages/mariadb-12.3.2-winx64.msi'
$officialMsiSha256 = '5A964E4F1C719AA1D4B065236A0A7A343CB7592E6A21D1ACB6FD1D426683B912'
$script:SensitiveValues = [System.Collections.Generic.List[string]]::new()

function Add-SensitiveValue {
    param([AllowEmptyString()][string]$Value)

    if (-not [string]::IsNullOrWhiteSpace($Value) -and -not $script:SensitiveValues.Contains($Value)) {
        [void]$script:SensitiveValues.Add($Value)
    }
}

function Protect-SetupText {
    param([AllowEmptyString()][string]$Text)

    if ($null -eq $Text) {
        return ''
    }
    $safe = $Text
    foreach ($value in $script:SensitiveValues) {
        $safe = [regex]::Replace(
            $safe,
            [regex]::Escape($value),
            '[redacted]',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
    }
    $safe = [regex]::Replace($safe, '(?i)(PASSWORD\s*[=:]\s*)[^\s;]+', '$1[redacted]')
    $safe = [regex]::Replace($safe, '(?i)(IDENTIFIED\s+BY\s+)(?:''[^'']*''|"[^"]*")', '$1[redacted]')
    return $safe
}

function Test-IsAdministrator {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-SetupLog {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ssK'
    $line = "[$timestamp] $(Protect-SetupText -Text $Message)"
    Write-Host $line
    [System.IO.File]::AppendAllText($logPath, "$line`r`n", [System.Text.UTF8Encoding]::new($false))
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

function Invoke-LocalMariaDb {
    param(
        [string]$Client,
        [int]$Port,
        [AllowEmptyString()][string]$Password,
        [string]$Sql,
        [switch]$AllowFailure
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Client
    $startInfo.Arguments = "--protocol=tcp --host=127.0.0.1 --port=$Port --user=root --batch --skip-column-names"
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
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($Sql)
        if (-not $Sql.EndsWith("`n")) {
            $process.StandardInput.WriteLine()
        }
        $process.StandardInput.Close()
        $process.WaitForExit()
        [void]$stdoutTask.Result
        [void]$stderrTask.Result

        if ($process.ExitCode -ne 0) {
            if ($AllowFailure) {
                return $false
            }
            throw "MariaDB command failed with exit code $($process.ExitCode); client output was suppressed to protect credentials."
        }
        return $true
    }
    finally {
        $process.Dispose()
    }
}

if (-not (Test-IsAdministrator)) {
    $argumentList = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $PSCommandPath),
        '-Mode', $Mode,
        '-PackageVersion', $PackageVersion,
        '-ServiceName', $ServiceName,
        '-Port', $Port
    )
    try {
        $elevated = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentList -WindowStyle Hidden -Wait -PassThru
    }
    catch {
        throw "Administrator approval is required to configure the $ServiceName Windows service."
    }
    exit $elevated.ExitCode
}

[System.IO.Directory]::CreateDirectory($runtimeDirectory) | Out-Null
[System.IO.File]::WriteAllText($logPath, '', [System.Text.UTF8Encoding]::new($false))
Write-SetupLog "Running elevated MariaDB setup for service $ServiceName on loopback port $Port."
trap {
    Write-SetupLog "ERROR: $($_.Exception.Message)"
    exit 1
}

$versionParts = $PackageVersion.Split('.')
if ($versionParts.Count -lt 2) {
    throw "Invalid MariaDB package version: $PackageVersion"
}
$installSeries = "$($versionParts[0]).$($versionParts[1])"
$installDirectory = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) "MariaDB $installSeries"
$serverPath = Join-Path $installDirectory 'bin\mysqld.exe'
$clientPath = Join-Path $installDirectory 'bin\mariadb.exe'
$dataDirectory = Join-Path $env:ProgramData "$ServiceName\data"
$configPath = Join-Path $dataDirectory 'my.ini'
$envFile = Join-Path $repositoryRoot '.env'

$dbAdminPassword = New-LocalPassword
$dbAppPassword = New-LocalPassword
Add-SensitiveValue -Value $dbAdminPassword
Add-SensitiveValue -Value $dbAppPassword
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
$recoverCredentials = $false

if (-not $service) {
    $portOwner = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($portOwner) {
        throw "TCP port $Port is already in use by process $($portOwner.OwningProcess); MariaDB was not installed."
    }

    $winget = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
    # Install the fresh instance without placing a generated credential on the
    # winget/MSI command line. Networking remains disabled until the local-only
    # credential bootstrap below has completed.
    $installerOverride = 'SERVICENAME={0} DATADIR="{1}" PORT={2} SKIPNETWORKING=1 /qn /norestart' -f $ServiceName, $dataDirectory, $Port
    Write-SetupLog "Installing official MariaDB package $PackageVersion."
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        if ($winget) {
            & $winget.Source install --id MariaDB.Server --exact --version $PackageVersion --scope machine --silent --accept-source-agreements --accept-package-agreements --override $installerOverride *> $null
            $installerExitCode = $LASTEXITCODE
        }
        else {
            if ($PackageVersion -ne '12.3.2.0') { throw 'The MSI fallback is pinned only for MariaDB 12.3.2.0.' }
            $downloadDirectory = Join-Path $runtimeDirectory 'downloads'
            [IO.Directory]::CreateDirectory($downloadDirectory) | Out-Null
            $msiPath = Join-Path $downloadDirectory 'mariadb-12.3.2-winx64.msi'
            & curl.exe --fail --location --silent --show-error --output $msiPath $officialMsiUrl
            if ($LASTEXITCODE -ne 0) { throw 'Official MariaDB MSI download failed.' }
            if ((Get-FileHash $msiPath -Algorithm SHA256).Hash -ne $officialMsiSha256) { throw 'MariaDB MSI checksum verification failed.' }
            $msi = Start-Process msiexec.exe -ArgumentList @('/i', ('"{0}"' -f $msiPath), $installerOverride, '/qn', '/norestart') -WindowStyle Hidden -Wait -PassThru
            $installerExitCode = $msi.ExitCode
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($installerExitCode -ne 0) {
        throw "MariaDB installer failed with exit code $installerExitCode; raw installer output was suppressed."
    }
    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    $recoverCredentials = $true
}
elseif ($Mode -eq 'RecoverEmptyInstance') {
    $recoverCredentials = $true
}
else {
    if (-not (Test-Path -LiteralPath $envFile)) {
        throw "$ServiceName already exists, but .env is missing. Use -Mode RecoverEmptyInstance only if this new instance is verified empty."
    }
    $configuredAdminPassword = Select-String -LiteralPath $envFile -Pattern '^DB_ADMIN_PASSWORD=(?!CHANGE_ME$)(?<value>[A-Za-z0-9_-]{24,128})$' |
        Select-Object -First 1
    if (-not $configuredAdminPassword) {
        throw "$ServiceName already exists, but its setup credential is unavailable. Use -Mode RecoverEmptyInstance only if this new instance is verified empty."
    }
    $dbAdminPassword = $configuredAdminPassword.Matches[0].Groups['value'].Value
    Add-SensitiveValue -Value $dbAdminPassword
    $configuredAppPassword = Select-String -LiteralPath $envFile -Pattern '^DB_PASSWORD=(?!CHANGE_ME$)(?<value>[A-Za-z0-9_-]{24,128})$' |
        Select-Object -First 1
    if ($configuredAppPassword) {
        $dbAppPassword = $configuredAppPassword.Matches[0].Groups['value'].Value
        Add-SensitiveValue -Value $dbAppPassword
    }
}

if ($recoverCredentials) {
    if (-not (Test-Path -LiteralPath $dataDirectory)) {
        throw "The expected data directory is missing: $dataDirectory"
    }
    # tarrant_rp_dev may exist after a setup pass that created the empty schema
    # but stopped before persisting the generated credentials.
    $allowedDirectories = @('mysql', 'performance_schema', 'sys', 'test', 'tarrant_rp_dev')
    $unexpectedDirectories = @(Get-ChildItem -LiteralPath $dataDirectory -Directory -Force |
        Where-Object { $_.Name -notin $allowedDirectories })
    if ($unexpectedDirectories.Count -gt 0) {
        throw 'Credential recovery was refused because the MariaDB instance is not empty.'
    }

    Write-SetupLog 'Recovering credentials for the verified-empty development instance.'
    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        (Get-Service -Name $ServiceName).WaitForStatus(
            [System.ServiceProcess.ServiceControllerStatus]::Stopped,
            [TimeSpan]::FromSeconds(30)
        )
    }

    foreach ($requiredPath in @($serverPath, $clientPath, $configPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Required MariaDB path is missing: $requiredPath"
        }
    }

    $recoveryStdout = Join-Path $runtimeDirectory 'mariadb-recovery.stdout.log'
    $recoveryStderr = Join-Path $runtimeDirectory 'mariadb-recovery.stderr.log'
    $recoveryProcess = Start-Process -FilePath $serverPath -ArgumentList @(
        "--defaults-file=$configPath",
        '--skip-grant-tables',
        '--skip-networking=0',
        '--bind-address=127.0.0.1',
        "--port=$Port",
        '--console'
    ) -WindowStyle Hidden -RedirectStandardOutput $recoveryStdout -RedirectStandardError $recoveryStderr -PassThru

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $ready = $false
        foreach ($attempt in 1..30) {
            if (Invoke-LocalMariaDb -Client $clientPath -Port $Port -Password '' -Sql 'SELECT 1;' -AllowFailure) {
                $ready = $true
                break
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not $ready) {
            throw "MariaDB recovery mode did not become ready on localhost:$Port."
        }

        $resetSql = "FLUSH PRIVILEGES; ALTER USER 'root'@'localhost' IDENTIFIED BY '$dbAdminPassword';"
        [void](Invoke-LocalMariaDb -Client $clientPath -Port $Port -Password '' -Sql $resetSql)
        [void](Invoke-LocalMariaDb -Client $clientPath -Port $Port -Password $dbAdminPassword -Sql 'SHUTDOWN;')
        [void]$recoveryProcess.WaitForExit(30000)
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if (-not $recoveryProcess.HasExited) {
            Stop-Process -Id $recoveryProcess.Id -Force -ErrorAction SilentlyContinue
        }
    }
}

$iniLines = [System.Collections.Generic.List[string]]::new()
foreach ($line in [System.IO.File]::ReadAllLines($configPath)) {
    if ($line -notmatch '^\s*(bind-address|character-set-server|collation-server|skip-networking|enable-named-pipe)\s*(?:=|$)') {
        [void]$iniLines.Add($line)
    }
}
$mysqldIndex = $iniLines.IndexOf('[mysqld]')
if ($mysqldIndex -lt 0) {
    throw 'MariaDB my.ini has no [mysqld] section.'
}
$iniLines.Insert($mysqldIndex + 1, 'collation-server=utf8mb4_unicode_ci')
$iniLines.Insert($mysqldIndex + 1, 'character-set-server=utf8mb4')
$iniLines.Insert($mysqldIndex + 1, 'bind-address=127.0.0.1')
[System.IO.File]::WriteAllLines($configPath, $iniLines, [System.Text.UTF8Encoding]::new($false))

$service = Get-Service -Name $ServiceName -ErrorAction Stop
if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
    Restart-Service -Name $ServiceName -Force -ErrorAction Stop
}
else {
    Start-Service -Name $ServiceName -ErrorAction Stop
}
(Get-Service -Name $ServiceName).WaitForStatus(
    [System.ServiceProcess.ServiceControllerStatus]::Running,
    [TimeSpan]::FromSeconds(30)
)

$env:DB_ADMIN_USER = 'root'
$env:DB_ADMIN_PASSWORD = $dbAdminPassword
$env:DB_PASSWORD = $dbAppPassword
try {
    Write-SetupLog 'Creating/verifying the scoped development database and application account.'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'setup-dev-db.ps1') 2>&1 |
        ForEach-Object { Write-SetupLog $_.ToString() }
    if ($LASTEXITCODE -ne 0) {
        throw "Database setup failed with exit code $LASTEXITCODE."
    }
}
finally {
    Remove-Item Env:\DB_ADMIN_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:\DB_PASSWORD -ErrorAction SilentlyContinue
}

Write-SetupLog "MariaDB setup completed for $ServiceName (credentials not displayed)."
