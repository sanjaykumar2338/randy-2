#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ServerDataPath,
    [switch]$ConfigureOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$runtimeRoot = Join-Path $repositoryRoot 'runtime'
if (-not $ServerDataPath) {
    $ServerDataPath = Join-Path $runtimeRoot 'qbox-server-data'
}
$ServerDataPath = [System.IO.Path]::GetFullPath($ServerDataPath)
$runtimePrefix = [System.IO.Path]::GetFullPath($runtimeRoot).TrimEnd('\') + '\'
$recipeCommit = 'a4be9fc715a2c749819f5a89b2c56c98289472a2'
$cfxDataCommit = 'e265cb251c88260533c847d4a1a2838c7d828a66'
if (-not $ServerDataPath.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "ServerDataPath must remain under the ignored runtime directory: $runtimeRoot"
}

function Write-Status {
    param([string]$Message)
    Write-Host "[ok] $Message"
}

function Read-DotEnv {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Ignored local environment file is missing: $Path"
    }

    $values = @{}
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

function Get-RequiredSetting {
    param([hashtable]$Settings, [string]$Name)
    if (-not $Settings.ContainsKey($Name) -or [string]::IsNullOrWhiteSpace($Settings[$Name]) -or $Settings[$Name] -eq 'CHANGE_ME') {
        throw "$Name is not configured in the ignored local .env file."
    }
    if ($Settings[$Name] -match '[\r\n\"]') {
        throw "$Name contains a character that cannot be written safely to the local FXServer configuration."
    }
    return $Settings[$Name]
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
        $rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        $allow = [System.Security.AccessControl.AccessControlType]::Allow
        $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($identity.User, $rights, $allow))
        foreach ($sidType in @(
            [System.Security.Principal.WellKnownSidType]::LocalSystemSid,
            [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid
        )) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new($sidType, $null)
            $security.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new($sid, $rights, $allow))
        }
        [System.IO.File]::SetAccessControl($Path, $security)
    }
    catch {
        Write-Warning "Could not tighten the ACL on $Path; the file remains under a Git-ignored runtime path."
    }
}

function Invoke-Download {
    param([string]$Uri, [string]$Destination)
    $curl = (Get-Command 'curl.exe' -ErrorAction Stop).Source
    & $curl --fail --location --silent --show-error --output $Destination $Uri
    if ($LASTEXITCODE -ne 0) {
        throw "Download failed: $Uri"
    }
    if ((Get-Item -LiteralPath $Destination).Length -eq 0) {
        throw "Downloaded file is empty: $Uri"
    }
}

function Expand-ZipArchive {
    param([string]$Archive, [string]$Destination)
    [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Archive, $Destination)
}

function Set-ExpectedTextReplacement {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$Replacement,
        [string]$Description,
        [int]$ExpectedCount = 1
    )

    $content = [System.IO.File]::ReadAllText($Path)
    $matches = [regex]::Matches($content, $Pattern)
    if ($matches.Count -ne $ExpectedCount) {
        throw "Could not apply the expected minimum-runtime override ($Description) to $Path."
    }
    $updated = [regex]::Replace($content, $Pattern, $Replacement)
    [System.IO.File]::WriteAllText($Path, $updated, [System.Text.UTF8Encoding]::new($false))
}

function Set-MinimumQboxOverrides {
    param([string]$CorePath)

    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\shared.lua') `
        -Pattern "serverName = 'Server'" `
        -Replacement "serverName = 'Tarrant County RP - Development'" `
        -Description 'apply the required temporary development identity'

    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\client.lua') `
        -Pattern "pauseMapText = 'Powered by Qbox'" `
        -Replacement "pauseMapText = 'Tarrant County RP - Development'" `
        -Description 'apply the required temporary pause-menu identity'

    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\client.lua') `
        -Pattern 'startingApartment = true' `
        -Replacement 'startingApartment = false' `
        -Description 'use qbx_spawn without the optional qbx_apartments resource'

    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\client.lua') `
        -Pattern 'discord = \{\s*enabled = true' `
        -Replacement "discord = {`n        enabled = false" `
        -Description 'defer Discord rich presence beyond Week 1'

    $hasKeys = @'
    hasKeys = function(plate, vehicle)
        if GetResourceState('qbx_vehiclekeys') ~= 'started' then return false end
        return exports.qbx_vehiclekeys:HasKeys(vehicle)
    end,
'@
    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\client.lua') `
        -Pattern "(?ms)^\s{4}hasKeys = function\(plate, vehicle\).*?^\s{4}end," `
        -Replacement $hasKeys.TrimEnd() `
        -Description 'guard the optional qbx_vehiclekeys integration on the client'

    $starterItems = @'
    starterItems = { -- Minimum Week 1 items; ID-card resources are intentionally deferred.
        { name = 'phone', amount = 1 },
    }
'@
    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\shared.lua') `
        -Pattern '(?ms)^\s{4}starterItems = \{.*?^\s{4}\}' `
        -Replacement $starterItems.TrimEnd() `
        -Description 'remove starter metadata callbacks for the absent optional qbx_idcard resource'

    $characterTables = @'
    characterDataTables = {
        {'bank_accounts_new', 'id'},
        {'playerskins', 'citizenid'},
        {'player_mails', 'citizenid'},
        {'player_outfits', 'citizenid'},
        {'player_vehicles', 'citizenid'},
        {'player_groups', 'citizenid'},
        {'players', 'citizenid'},
    }, -- Rows to be deleted when the character is deleted
'@
    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\server.lua') `
        -Pattern '(?ms)^\s{4}characterDataTables = \{.*?^\s{4}\}, -- Rows to be deleted when the character is deleted[ \t]*$' `
        -Replacement $characterTables.TrimEnd() `
        -Description 'limit character cleanup to tables installed in the minimum runtime'

    $giveVehicleKeys = @'
    giveVehicleKeys = function(src, plate, vehicle)
        if GetResourceState('qbx_vehiclekeys') ~= 'started' then return false end
        return exports.qbx_vehiclekeys:GiveKeys(src, vehicle)
    end,
'@
    Set-ExpectedTextReplacement `
        -Path (Join-Path $CorePath 'config\server.lua') `
        -Pattern "(?ms)^\s{4}giveVehicleKeys = function\(src, plate, vehicle\).*?^\s{4}end," `
        -Replacement $giveVehicleKeys.TrimEnd() `
        -Description 'guard the optional qbx_vehiclekeys integration on the server'
}

function Set-MinimumInventoryOverrides {
    param([string]$InventoryPath)

    Set-ExpectedTextReplacement `
        -Path (Join-Path $InventoryPath 'data\shops.lua') `
        -Pattern "name = 'cola'" `
        -Replacement "name = 'sprunk'" `
        -Description 'map shop drinks to the installed Qbox item name' `
        -ExpectedCount 3

    Set-ExpectedTextReplacement `
        -Path (Join-Path $InventoryPath 'data\shops.lua') `
        -Pattern "(?m)^\s*\{ name = 'medikit', price = 26 \},\r?\n" `
        -Replacement '' `
        -Description 'remove the shop entry for an item not supplied by the minimum stack'

    Set-ExpectedTextReplacement `
        -Path (Join-Path $InventoryPath 'data\crafting.lua') `
        -Pattern 'scrapmetal = 5' `
        -Replacement 'metalscrap = 5' `
        -Description 'map crafting material to the installed Qbox item name'

}

function Invoke-SqlFile {
    param(
        [string]$Client,
        [string]$HostName,
        [int]$Port,
        [string]$User,
        [string]$Password,
        [string]$Database,
        [string]$Path
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Client
    $startInfo.Arguments = "--protocol=tcp --host=$HostName --port=$Port --user=$User --database=$Database --default-character-set=utf8mb4"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['MYSQL_PWD'] = $Password

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $process.StandardInput.Write([System.IO.File]::ReadAllText($Path))
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "SQL import failed for $([System.IO.Path]::GetFileName($Path)): $stderr $stdout"
    }
}

function Find-MariaDbClient {
    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $candidate = Get-ChildItem -Path $programFiles -Directory -Filter 'MariaDB *' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'bin\mariadb.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if (-not $candidate -or $candidate -like 'C:\xampp\*') {
        throw 'A supported standalone MariaDB client was not found.'
    }
    return $candidate
}

function Write-LocalConfiguration {
    param([string]$DataPath, [hashtable]$Settings, [string]$RecipeSource)

    $dbHost = Get-RequiredSetting -Settings $Settings -Name 'DB_HOST'
    $dbPort = Get-RequiredSetting -Settings $Settings -Name 'DB_PORT'
    $dbName = Get-RequiredSetting -Settings $Settings -Name 'DB_NAME'
    $dbUser = Get-RequiredSetting -Settings $Settings -Name 'DB_USER'
    $dbPassword = Get-RequiredSetting -Settings $Settings -Name 'DB_PASSWORD'
    if ($dbHost -notin @('127.0.0.1', 'localhost')) {
        throw 'DB_HOST must remain local for this loopback-only development runtime.'
    }
    $parsedDbPort = 0
    if (-not [int]::TryParse($dbPort, [ref]$parsedDbPort) -or $parsedDbPort -lt 1 -or $parsedDbPort -gt 65535) {
        throw 'DB_PORT must be an integer from 1 through 65535.'
    }
    foreach ($sqlName in @($dbName, $dbUser)) {
        if ($sqlName -notmatch '^[A-Za-z0-9_]+$') {
            throw 'Database name/user must contain only letters, numbers, and underscores.'
        }
    }
    if ($dbPassword -notmatch '^[A-Za-z0-9_-]{24,128}$') {
        throw 'DB_PASSWORD must use the safe value generated by setup-dev-db.ps1.'
    }
    $developmentConfig = Join-Path $DataPath 'development.cfg'
    $licenseLine = '# MANUAL ACTION REQUIRED: add sv_licenseKey after placing FIVEM_LICENSE_KEY in .env.'
    if ($Settings.ContainsKey('FIVEM_LICENSE_KEY') -and $Settings.FIVEM_LICENSE_KEY -and $Settings.FIVEM_LICENSE_KEY -ne 'CHANGE_ME') {
        if ($Settings.FIVEM_LICENSE_KEY -notmatch '^cfxk_[A-Za-z0-9_-]+$') {
            throw 'FIVEM_LICENSE_KEY is not a valid Cfx.re server-key value.'
        }
        $licenseLine = 'sv_licenseKey "{0}"' -f $Settings.FIVEM_LICENSE_KEY
    }

    $development = @"
# Local secrets for Tarrant County RP development. This runtime directory is ignored by Git.
set mysql_connection_string "host=$dbHost;port=$dbPort;user=$dbUser;password=$dbPassword;database=$dbName;charset=utf8mb4"
$licenseLine
"@
    [System.IO.File]::WriteAllText($developmentConfig, $development, [System.Text.UTF8Encoding]::new($false))
    Protect-SecretFile -Path $developmentConfig

    $serverConfig = @'
# Minimum Week 1 Qbox runtime derived from the official Qbox lean txAdmin recipe.
endpoint_add_tcp "127.0.0.1:30120"
endpoint_add_udp "127.0.0.1:30120"

sv_maxclients 8
set onesync on
set steam_webApiKey "none"
sets tags "development, qbox"

sv_hostname "Tarrant County RP - Development"
sets sv_projectName "Tarrant County RP - Development"
sets sv_projectDesc "Week 1 Qbox playable-foundation development runtime"
sets locale "en-US"
load_server_icon myLogo.png
set sv_enforceGameBuild 3258
sv_scriptHookAllowed 0

exec development.cfg

set resources_useSystemChat true
set qbx_chat:joinMessage "^2%s joined the server"
set qbx_chat:quitMessage "^1%s left the server (%s)"

setr qb_locale "en"
setr qbx:enableBridge "true"
set qbx:enableQueue "true"
set qbx:bucketLockdownMode "inactive"
set qbx:max_jobs_per_player 1
set qbx:max_gangs_per_player 1
set qbx:setjob_replaces "true"
set qbx:setgang_replaces "true"
set qbx:cleanPlayerGroups "true"
set qbx:allowMethodOverrides "true"
set qbx:disableOverrideWarning "false"
setr qbx:enableVehiclePersistence "false"
set qbx:acknowledge "true"
setr qbx:enableGroupManagement "false"
setr illenium-appearance:locale "en"

exec ox.cfg

ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
stop basic-gamemode
ensure hardcap
ensure baseevents

# Explicit dependency order for the minimum Week 1 stack.
ensure ox_lib
ensure oxmysql
ensure qbx_core
ensure qbx_vehicles
ensure ox_target
ensure ox_inventory
ensure qbx_spawn
ensure illenium-appearance
ensure qbx_hud

exec permissions.cfg
exec misc.cfg
'@
    [System.IO.File]::WriteAllText((Join-Path $DataPath 'server.cfg'), $serverConfig, [System.Text.UTF8Encoding]::new($false))

    foreach ($fileName in @('ox.cfg', 'permissions.cfg', 'misc.cfg', 'myLogo.png')) {
        Copy-Item -LiteralPath (Join-Path $RecipeSource $fileName) -Destination (Join-Path $DataPath $fileName) -Force
    }
    Set-ExpectedTextReplacement `
        -Path (Join-Path $DataPath 'ox.cfg') `
        -Pattern '"cola", 1, 1' `
        -Replacement '"sprunk", 1, 1' `
        -Description 'map generated vehicle loot to the installed Qbox item name'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Directory]::CreateDirectory($runtimeRoot) | Out-Null
& git -C $repositoryRoot check-ignore --quiet -- 'runtime/qbox-server-data'
if ($LASTEXITCODE -ne 0) {
    throw 'The Qbox runtime path is not ignored by Git.'
}

$settings = Read-DotEnv -Path (Join-Path $repositoryRoot '.env')
if ($ConfigureOnly) {
    if (-not (Test-Path -LiteralPath (Join-Path $ServerDataPath 'runtime-manifest.json'))) {
        throw "An installed Qbox runtime was not found at $ServerDataPath"
    }
    $recipeSource = Join-Path $runtimeRoot 'qbox-recipe'
    $localRecipeCommit = if (Test-Path -LiteralPath (Join-Path $recipeSource '.git')) { (& git -C $recipeSource rev-parse HEAD).Trim() } else { '' }
    $configureWorkRoot = $null
    try {
        if ($localRecipeCommit -ne $recipeCommit) {
            $configureWorkRoot = Join-Path $runtimeRoot ('qbox-config-' + [System.IO.Path]::GetRandomFileName())
            $downloads = Join-Path $configureWorkRoot 'downloads'
            [System.IO.Directory]::CreateDirectory($downloads) | Out-Null
            $recipeArchive = Join-Path $downloads 'qbox-recipe.zip'
            Invoke-Download -Uri "https://github.com/Qbox-project/txAdminRecipe/archive/$recipeCommit.zip" -Destination $recipeArchive
            $recipeExtract = Join-Path $configureWorkRoot 'recipe'
            Expand-ZipArchive -Archive $recipeArchive -Destination $recipeExtract
            $recipeSource = (Get-ChildItem -LiteralPath $recipeExtract -Directory | Select-Object -First 1).FullName
        }
        Write-LocalConfiguration -DataPath $ServerDataPath -Settings $settings -RecipeSource $recipeSource
    }
    finally {
        if ($configureWorkRoot) {
            $resolvedConfigureWorkRoot = [System.IO.Path]::GetFullPath($configureWorkRoot)
            if ($resolvedConfigureWorkRoot.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedConfigureWorkRoot)) {
                Remove-Item -LiteralPath $resolvedConfigureWorkRoot -Recurse -Force
            }
        }
    }
    Write-Status "Local runtime configuration refreshed: $ServerDataPath"
    exit 0
}

if (Test-Path -LiteralPath $ServerDataPath) {
    if ((Get-ChildItem -LiteralPath $ServerDataPath -Force | Select-Object -First 1)) {
        throw "Refusing to overwrite existing server data: $ServerDataPath"
    }
}

$workRoot = Join-Path $runtimeRoot ('qbox-install-' + [System.IO.Path]::GetRandomFileName())
$stageRoot = Join-Path $workRoot 'server-data'
$downloads = Join-Path $workRoot 'downloads'
[System.IO.Directory]::CreateDirectory($stageRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($downloads) | Out-Null

try {
    $recipeSource = Join-Path $runtimeRoot 'qbox-recipe'
    $localRecipeCommit = if (Test-Path -LiteralPath (Join-Path $recipeSource '.git')) { (& git -C $recipeSource rev-parse HEAD).Trim() } else { '' }
    if ($localRecipeCommit -ne $recipeCommit) {
        $recipeArchive = Join-Path $downloads 'qbox-recipe.zip'
        Invoke-Download -Uri "https://github.com/Qbox-project/txAdminRecipe/archive/$recipeCommit.zip" -Destination $recipeArchive
        $recipeExtract = Join-Path $workRoot 'recipe'
        Expand-ZipArchive -Archive $recipeArchive -Destination $recipeExtract
        $recipeSource = (Get-ChildItem -LiteralPath $recipeExtract -Directory | Select-Object -First 1).FullName
    }

    $cfxSource = Join-Path $runtimeRoot 'cfx-server-data'
    $localCfxCommit = if (Test-Path -LiteralPath (Join-Path $cfxSource '.git')) { (& git -C $cfxSource rev-parse HEAD).Trim() } else { '' }
    if ($localCfxCommit -ne $cfxDataCommit) {
        $cfxArchive = Join-Path $downloads 'cfx-server-data.zip'
        Invoke-Download -Uri "https://github.com/citizenfx/cfx-server-data/archive/$cfxDataCommit.zip" -Destination $cfxArchive
        $cfxExtract = Join-Path $workRoot 'cfx-server-data'
        Expand-ZipArchive -Archive $cfxArchive -Destination $cfxExtract
        $cfxSource = (Get-ChildItem -LiteralPath $cfxExtract -Directory | Select-Object -First 1).FullName
    }

    $resourcesRoot = Join-Path $stageRoot 'resources'
    $cfxDestination = Join-Path $resourcesRoot '[cfx-default]'
    [System.IO.Directory]::CreateDirectory($cfxDestination) | Out-Null
    Copy-Item -Path (Join-Path $cfxSource 'resources\*') -Destination $cfxDestination -Recurse -Force
    # The official Qbox recipe removes this clone so FXServer's bundled system
    # chat resource is the single resource named "chat".
    $clonedChat = Join-Path $cfxDestination '[gameplay]\chat'
    $resolvedClonedChat = [System.IO.Path]::GetFullPath($clonedChat)
    $resolvedStageRoot = [System.IO.Path]::GetFullPath($stageRoot).TrimEnd('\') + '\'
    if ($resolvedClonedChat.StartsWith($resolvedStageRoot, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedClonedChat)) {
        Remove-Item -LiteralPath $resolvedClonedChat -Recurse -Force
    }

    $packages = @(
        [pscustomobject]@{ Name='qbx_core'; Version='1.23.0'; Group='[qbx]'; Url='https://github.com/Qbox-project/qbx_core/releases/download/v1.23.0/qbx_core.zip' },
        [pscustomobject]@{ Name='qbx_vehicles'; Version='1.4.2'; Group='[qbx]'; Url='https://github.com/Qbox-project/qbx_vehicles/releases/download/v1.4.2/qbx_vehicles.zip' },
        [pscustomobject]@{ Name='qbx_spawn'; Version='0.1.1'; Group='[qbx]'; Url='https://github.com/Qbox-project/qbx_spawn/releases/download/v0.1.1/qbx_spawn.zip' },
        [pscustomobject]@{ Name='qbx_hud'; Version='0.1.0'; Group='[qbx]'; Url='https://github.com/Qbox-project/qbx_hud/releases/download/v0.1.0/qbx_hud.zip' },
        [pscustomobject]@{ Name='ox_lib'; Version='3.39.0'; Group='[ox]'; Url='https://github.com/overextended/ox_lib/releases/download/v3.39.0/ox_lib.zip' },
        [pscustomobject]@{ Name='oxmysql'; Version='2.14.1'; Group='[ox]'; Url='https://github.com/overextended/oxmysql/releases/download/v2.14.1/oxmysql.zip' },
        [pscustomobject]@{ Name='ox_target'; Version='1.18.1'; Group='[ox]'; Url='https://github.com/overextended/ox_target/releases/download/v1.18.1/ox_target.zip' },
        [pscustomobject]@{ Name='ox_inventory'; Version='2.47.9'; Group='[ox]'; Url='https://github.com/overextended/ox_inventory/releases/download/v2.47.9/ox_inventory.zip' },
        [pscustomobject]@{ Name='illenium-appearance'; Version='5.7.0'; Group='[standalone]'; Url='https://github.com/iLLeniumStudios/illenium-appearance/releases/download/v5.7.0/illenium-appearance.zip' }
    )

    $packageEvidence = @()
    foreach ($package in $packages) {
        $archivePath = Join-Path $downloads ($package.Name + '.zip')
        Write-Host "[download] $($package.Name) $($package.Version)"
        Invoke-Download -Uri $package.Url -Destination $archivePath
        $groupPath = Join-Path $resourcesRoot $package.Group
        Expand-ZipArchive -Archive $archivePath -Destination $groupPath
        $resourcePath = Join-Path $groupPath $package.Name
        if (-not (Test-Path -LiteralPath (Join-Path $resourcePath 'fxmanifest.lua'))) {
            throw "The $($package.Name) archive did not contain the expected resource layout."
        }
        $packageEvidence += [pscustomobject]@{
            name = $package.Name
            version = $package.Version
            source = $package.Url
            sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash
        }
    }

    Copy-Item -LiteralPath (Join-Path $recipeSource 'items.lua') -Destination (Join-Path $resourcesRoot '[ox]\ox_inventory\data\items.lua') -Force
    Set-MinimumQboxOverrides -CorePath (Join-Path $resourcesRoot '[qbx]\qbx_core')
    $tarrantDestination = Join-Path $resourcesRoot '[tarrant]'
    [System.IO.Directory]::CreateDirectory($tarrantDestination) | Out-Null
    $tarrantSource = Join-Path $repositoryRoot 'resources\[tarrant]'
    foreach ($item in Get-ChildItem -LiteralPath $tarrantSource -Force -ErrorAction SilentlyContinue) {
        Copy-Item -LiteralPath $item.FullName -Destination $tarrantDestination -Recurse -Force
    }

    Write-LocalConfiguration -DataPath $stageRoot -Settings $settings -RecipeSource $recipeSource
    Set-MinimumInventoryOverrides `
        -InventoryPath (Join-Path $resourcesRoot '[ox]\ox_inventory')

    $dbHost = Get-RequiredSetting -Settings $settings -Name 'DB_HOST'
    $dbPort = [int](Get-RequiredSetting -Settings $settings -Name 'DB_PORT')
    $dbName = Get-RequiredSetting -Settings $settings -Name 'DB_NAME'
    $dbUser = Get-RequiredSetting -Settings $settings -Name 'DB_USER'
    $dbPassword = Get-RequiredSetting -Settings $settings -Name 'DB_PASSWORD'
    foreach ($sqlName in @($dbName, $dbUser)) {
        if ($sqlName -notmatch '^[A-Za-z0-9_]+$') {
            throw 'Database name/user must contain only letters, numbers, and underscores.'
        }
    }
    $client = Find-MariaDbClient
    Invoke-SqlFile -Client $client -HostName $dbHost -Port $dbPort -User $dbUser -Password $dbPassword -Database $dbName -Path (Join-Path $recipeSource 'qbox.sql')
    Invoke-SqlFile -Client $client -HostName $dbHost -Port $dbPort -User $dbUser -Password $dbPassword -Database $dbName -Path (Join-Path $resourcesRoot '[qbx]\qbx_core\qbx_core.sql')
    Invoke-SqlFile -Client $client -HostName $dbHost -Port $dbPort -User $dbUser -Password $dbPassword -Database $dbName -Path (Join-Path $resourcesRoot '[qbx]\qbx_vehicles\vehicles.sql')

    $manifest = [ordered]@{
        installedAt = (Get-Date).ToString('o')
        recipe = [ordered]@{
            name = 'Qbox Lean Pack (minimum Week 1 subset)'
            repository = 'https://github.com/Qbox-project/txAdminRecipe'
            commit = $recipeCommit
        }
        cfxServerData = [ordered]@{
            repository = 'https://github.com/citizenfx/cfx-server-data'
            commit = $cfxDataCommit
        }
        packages = $packageEvidence
        localOverrides = @(
            'qbx_core: temporary Tarrant development identity applied',
            'qbx_core: startingApartment=false (qbx_apartments deferred)',
            'qbx_core: starter ID-card callbacks removed (qbx_idcard deferred)',
            'qbx_core: character cleanup tables limited to installed schemas',
            'qbx_core: optional qbx_vehiclekeys exports guarded when the resource is deferred',
            'qbx_core: Discord rich presence disabled for Week 1',
            'ox_inventory: official item-name mismatches normalized to installed items'
        )
        voice = 'deferred'
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $stageRoot 'runtime-manifest.json'),
        ($manifest | ConvertTo-Json -Depth 6),
        [System.Text.UTF8Encoding]::new($false)
    )

    if (Test-Path -LiteralPath $ServerDataPath) {
        $existing = @(Get-ChildItem -LiteralPath $ServerDataPath -Force)
        if ($existing.Count -gt 0) {
            throw "Refusing to replace non-empty destination: $ServerDataPath"
        }
        Remove-Item -LiteralPath $ServerDataPath -Force
    }
    Move-Item -LiteralPath $stageRoot -Destination $ServerDataPath
    Write-Status "Qbox Week 1 runtime staged: $ServerDataPath"
    Write-Status 'Official base/core/vehicle schemas imported with the application database account'
}
finally {
    $resolvedWorkRoot = [System.IO.Path]::GetFullPath($workRoot)
    if ($resolvedWorkRoot.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedWorkRoot)) {
        Remove-Item -LiteralPath $resolvedWorkRoot -Recurse -Force
    }
}
