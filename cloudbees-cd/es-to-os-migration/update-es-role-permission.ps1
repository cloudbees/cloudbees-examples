<#
.SYNOPSIS
This script must change roles permissions for user of ElasticSearch installed
by CloudBees Software Delivery Automation Analytics


.DESCRIPTION
CloudBees Software Delivery Automation Analytics moved from ElasticSearch to OpenSearch in a release 2024.06
To migrate from ElasticSearch to OpenSearch starting 2023.12 and later no need any changes. If any issues
with older release in time of migration - current script can help with role permissions issues.
Aplay this script before migrate from 2023.8 or older to the 2024.06 or younger.
Script will try automatically find all needed values and if any issues to do it  - will report you about issues.

.PARAMETER Port
Specify CloudBees Software Delivery Automation Analytics transport port.


.EXAMPLE
update-role-permissions.ps1 -Port 9301
#>

param (
    [Switch]$Help,
    [string]$Port
)


# Записуємо змінну в YAML файл
# $yamlContent | Set-Content -Path "C:\path\to\output-file.yml"

# Виведемо вміст файлу для перевірки
# Get-Content -Path "C:\path\to\output-file.yml"

# Looking for next application
$programName = "CloudBees Software Delivery Automation Analytics"
$logFile = "$env:TEMP\\rolepermission.log"
$LOG_TO_FILE = $true
$DEBUG = $true

function Show-Usage {
    $usage = @"
Usage: update-role-permissions.ps1 [-Help] [-Analyze] [-Port <number>]

Parameters:
    -Help          Show usage.
    -Analyze       Check all parameters are ok without applaying permissions.
    -Port          Specify trasport prot for CloudBees Software Delivery Automation Analytics.

Examples:
    update-role-permissions.ps1 -Analyze
    update-role-permissions.ps1 -Port 9355
    update-role-permissions.ps1 -Help
"@
    Write-Host $usage -ForegroundColor Green
}

$SG_ROLES = @"
---
# DLS (Document level security) is NOT FREE FOR COMMERCIAL use, you need to obtain an enterprise license
# https://docs.search-guard.com/latest/document-level-security

# FLS (Field level security) is NOT FREE FOR COMMERCIAL use, you need to obtain an enterprise license
# https://docs.search-guard.com/latest/field-level-security

# Masked fields (field anonymization) is NOT FREE FOR COMMERCIAL use, you need to obtain an compliance license
# https://docs.search-guard.com/latest/field-anonymization

# Kibana multitenancy is NOT FREE FOR COMMERCIAL use, you need to obtain an enterprise license
# https://docs.search-guard.com/latest/kibana-multi-tenancy


_sg_meta:
  type: "roles"
  config_version: 2

# Define your own search guard roles here
# or use the built-in search guard roles
# See https://docs.search-guard.com/latest/roles-permissions

CB_REPORT_USER:
  cluster_permissions:
    - "SGS_CLUSTER_MANAGE_INDEX_TEMPLATES"
    - "SGS_CLUSTER_MONITOR"
    - "SGS_CLUSTER_COMPOSITE_OPS"
    - "SGS_MANAGE_SNAPSHOTS"
  index_permissions:
    - index_patterns:
        - "*"
      allowed_actions:
        - "SGS_SEARCH"
    - index_patterns:
        - "ef-*"
      allowed_actions:
        - "indices:admin/refresh*"
        - "SGS_CRUD"
        - "SGS_CREATE_INDEX"

CB_READALL_USER:
  cluster_permissions:
    - "SGS_CLUSTER_MONITOR"
  index_permissions:
    - index_patterns:
        - "*"
      allowed_actions:
        - "indices:admin/mappings/get"
        - "SGS_SEARCH"
        - "SGS_READ"
        - "SGS_INDICES_MONITOR"
"@

$SG_ROLES_MAPPING = @"
---
# In this file users, backendroles and hosts can be mapped to Search Guard roles.
# Permissions for Search Guard roles are configured in sg_roles.yml

_sg_meta:
  type: "rolesmapping"
  config_version: 2

# Define your roles mapping here
# See https://docs.search-guard.com/latest/mapping-users-roles

CB_REPORT_USER:
  reserved: false
  users:
    - "reportuser"

CB_READALL_USER:
  reserved: false
  users:
    - "kibanauser"

SGS_KIBANA_USER:
  reserved: false
  users:
    - "kibanauser"

SGS_KIBANA_SERVER:
  reserved: true
  users:
    - "kibanaserver"

SGS_ALL_ACCESS:
  reserved: true
  users:
    - "admin"
"@


# functions

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Prompt to run from Administrator.
if (-not (Test-Administrator) -and (-not $Analyze) ) {
    Write-Host "Please run the script with Administrator permissions. Quit." -ForegroundColor Yellow
    exit
}

$null = Remove-Item -Path $logFile -Recurse -Force

# log messages
function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )

    $allowedWords = @("error", "info", "warning", "debug")

    if (-not ($allowedWords.ToLower() -contains $level.ToLower()) ) {
        $level = "INFO"
    }  else {
        $level = $level.ToUpper()
    }
    $formatedLevel = "{0, -10}" -f "[$level]"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp $formatedLevel - $message"
    # skip debug message if $DEBUG if not true
    if ( -not ( $level -eq "DEBUG" -and $DEBUG -eq $false)) {
        if ($LOG_TO_FILE) {  # log to file only if it was allowed
            $logMessage | Out-File -FilePath $logFile -Append
        }
        $colorMessage = "green"

        if ($level -eq "ERROR") {$colorMessage = "red"}
        if ($level -eq "DEBUG") {$colorMessage = "blue"}
        if ($level -eq "WARNING") {$colorMessage = "yellow"}
        # Log to the terminal
        Write-Host $logMessage -ForegroundColor $colorMessage
    }
}

# Read registry to get needed parameters of installation
function Get-ProgramInstallPath { #-> structure of values: DisplayName, InstallLocation , dataDirectory
    param ($registryPath, $programName)
    Get-ItemProperty -Path  "$registryPath\*" |
            Where-Object { $_.DisplayName -like "*$programName*" } |
            Select-Object DisplayName, InstallLocation , dataDirectory
}

# Read uninstall information from registry branch for 32 bit applications
function Get-Program32InstallPath {
    param ($programName)
    $registryPath32 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    Get-ProgramInstallPath -registryPath $registryPath32 -programName $programName
}

# Check file exists
function Test-FileExists {
    param ($path)
    # Check file exists
    try {
        if (Test-Path -Path $path -PathType Leaf) {
            $fileExistStatus = $true
        }
    } catch {

    }
    return $fileExistStatus
}

# Check Directory exists
function Test-DirectoryExists {
    param ($path)

    $dirExistStatus = $false

    # directory exists?
    if (Test-Path -Path $path -PathType Container) {
        $dirExistStatus = $true
    }
    return $dirExistStatus
}

# Check directory on write permissions
function Test-DirectoryWritePermission {
    param ($path)

    # Checking directory
    if (-Not (Test-DirectoryExists $path )) {
        return $false
    }

    # Create a file with a rundom name in a folder
    try {
        $tempFile = [System.IO.Path]::Combine($path, [System.IO.Path]::GetRandomFileName())
        $null = New-Item -Path $tempFile -ItemType File -Force
        Remove-Item -Path $tempFile -Force
        Write-Log -level "debug" -message "Allowed to write directory - $path"
        return $true
    }
    catch {
        Write-Log -level "warning" -message "Can't create files at the '$path'"
        return $false
    }
}
### End functions

if ($Help) {
    Show-Usage
    exit
}

# if ($Port) {
#     Write-Log -level "debug" -message "Passed port as $Port from command line"
# }

$installation = Get-Program32InstallPath -programName $programName
$installLocation = $installation.InstallLocation
$dataDirectory = $installation.dataDirectory

$searchGuard7Lib = "$installLocation\reporting\elasticsearch\plugins\search-guard-7"
$elasticSearchLib = "$installLocation\reporting\elasticsearch\lib"
$javaBin = "$installLocation\reporting\jre\bin\java.exe"
$elasticSearchConfig = "$dataDirectory\conf\reporting\elasticsearch"


Write-Log -level "debug" -message "Install location: $installLocation"
Write-Log -level "debug" -message "Install data directory: $dataDirectory"
Write-Log -level "debug" -message "Install SG7 plugin lib directory: $searchGuard7Lib"
Write-Log -level "debug" -message "Install ES lib directory: $elasticSearchLib"
Write-Log -level "debug" -message "Java bin: $javaBin"
Write-Log -level "debug" -message "Config file for elasticsearch: $elasticsearchYml"

$tempFile = [System.IO.Path]::Combine($path, [System.IO.Path]::GetRandomFileName())
$temporaryConfigDirectory = "$env:TEMP\$tempFile"
$null = New-Item -Path $env:TEMP -Name $tempFile -ItemType "directory" -Force

if (-not (Test-Path -Path $temporaryConfigDirectory)) {
    Write-Log -level "debug" -message "Create $temporaryConfigDirectory"
    New-Item -Path $temporaryConfigDirectory -ItemType Directory
}

Write-Log -level "debug" -message "Copy files to the $temporaryConfigDirectory"
$masks = "*.txt", "*.jks", "*.pem", "*.yml"
foreach ($mask in $masks) {
    Get-ChildItem -Path $elasticSearchConfig -Filter $mask | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $temporaryConfigDirectory -Force
        Write-Log -level "debug" -message "Copy file $($_.Name) to the  $temporaryConfigDirectory"
    }
}
Write-Log -level "debug" -message "Owerwrite file $temporaryConfigDirectory\sg_roles_mapping.yml"
Set-Content -Path "$temporaryConfigDirectory\sg_roles_mapping.yml" -Value $SG_ROLES_MAPPING

Write-Log -level "debug" -message "Owerwrite file $temporaryConfigDirectory\sg_roles.yml"
Set-Content -Path "$temporaryConfigDirectory\g_roles.yml" -Value $SG_ROLES


$adminkeystore = "$temporaryConfigDirectory\admin-keystore.jks"
$truststore = "$temporaryConfigDirectory\truststore.jks"
$elasticsearchYml = "$temporaryConfigDirectory\elasticsearch.yml"

$valuableDirectories = ("installLocation", "dataDirectory",
"searchGuard7Lib", "elasticSearchLib", "temporaryConfigDirectory")

$valuableFiles = ("javaBin", "adminkeystore", "truststore", "elasticsearchYml")

$allDirectoriesExists = $true

Write-Log  -level "debug" -message "Checking that directories are available."

# Check for directories
foreach ($variableName in $valuableDirectories) {
    $value = Get-Variable -Name $variableName -ValueOnly
    Write-Log  -level "debug" -message "$variableName : $value"

    if ( -not (Test-DirectoryExists -path $value)) {
        Write-Log -level "error" -message "$value - directory not exists or not available"
        $allDirectoriesExists = $false
    }
}

Write-Log -level "debug" -message "Checking that files are available."

$allFilesOK = $true
# Check for files
foreach ($variableName in $valuableFiles) {
    $value = Get-Variable -Name $variableName -ValueOnly
    Write-Log  -level "debug" -message "$variableName : $value"
    if ( -not (Test-FileExists -path $value)) {
        $allFilesOK = $false
        Write-Log -level "error" -message "$value - file not exists, or not available."
    }
}


if ( -not $allDirectoriesExists ) {
    Write-Log -level "error" -message "Please check files availability."
}
if ( -not $allFilesOK ) {
    Write-Log -level "error"  "Please check all directories available."
}
if ( -not ($allDirectoriesExists -and $allFilesOK) ) {
    exit(-1)
}

### Looking for a transport port-number

Write-Log -level "debug" -message "Going to read port number from $elasticsearchYml"

$searchWord = "transport.port"
# Read needed line from a configuration file
$knowPortNumber = $false
try {
    $matchedLine = Get-Content -Path $elasticsearchYml | Select-String -Pattern $searchWord

    if ($matchedLine) {
        $portNumber = $matchedLine -replace '.*:\s*', ''
        if ($portNumber) {
            $knowPortNumber = $true
        }
        Write-Log -level "debug" -message "Port-number is : $portNumber"
    } else {
        Write-Log -level "debug" -message "Not found line with : $matchedLine"
    }
} catch {
    $knowPortNumber = $false
}

if ($portNumber) {
    Write-Log -level "info" -message "transport port number : $portNumber"
}

if ( -not $knowPortNumber ) {
    Write-Log -level "error" -message "There is no reason to continue as not all parameters was found. Quit."
    exit(-1)
}



!!!!
Start-Process "$javaBin" -ArgumentList `
"-Dio.netty.tryReflectionSetAccessible=false", `
"-Dio.netty.noUnsafe=true", `
  "-Dorg.apache.logging.log4j.simplelog.StatusLogger.level=OFF", `
  "-cp", "$searchGuard7Lib\*;$elasticSearchLib\*",  `
  "com.floragunn.searchguard.tools.SearchGuardAdmin", `
  "-cd", "$temporaryConfigDirectory", `
  "-ks", "$adminkeystore", "-kspass", "abcdef" `
  "-ts", "$truststore", "-tspass", "abcdef", `
  "-h", "localhost", "-p", $portNumber "-nhnv", "-icl"

try {
    # Запуск PowerShell скрипта з кількома параметрами
    Start-Process "java.exe" -ArgumentList "-NoProfile", "-ExecutionPolicy Bypass", "-File", "$javaBin", `
      "-Dio.netty.tryReflectionSetAccessible=false", `
    "-Dio.netty.noUnsafe=true", `
        "-Dorg.apache.logging.log4j.simplelog.StatusLogger.level=OFF", `
        "-cp", "$searchGuard7Lib\*;$elasticSearchLib\*",  `
        "com.floragunn.searchguard.tools.SearchGuardAdmin", `
        "-cd", "$temporaryConfigDirectory", `
        "-ks", "$adminkeystore", "-kspass", "abcdef" `
        "-ts", "$truststore", "-tspass", "abcdef", `
        "-h", "localhost", "-p", $portNumber "-nhnv", "-icl"

} catch {
    Write-Log -level "error" -message "Failed to apply role permissions"
}


Remove-Item -Path $temporaryConfigDirectory -Recurse -Force