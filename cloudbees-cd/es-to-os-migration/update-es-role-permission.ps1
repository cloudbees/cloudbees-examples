<#
.SYNOPSIS
This script updates ElasticSearch user permissions for CloudBees Analytics in v2023.10.0 or earlier. If you are using v2023.12.0 or later, this update is not required.

IMPORTANT:  This script requires Administrator permissions to run.

.DESCRIPTION
CloudBees Analytics migrated from ElasticSearch to OpenSearch in release v2024.06.0. This script updates required user permissons when upgrading from v2023.10 or earlier as part of the migration when upgrading to v2024.06.0 or later. You must run this script prior to upgrading.
This script attempts to automatically find all required values silently. However, if an issue is encountered, it reports the issue as an error messages.

.PARAMETER Port
Specify the CloudBees Analytics transport port. The script tries to read port number automatically from the config file.


.PARAMETER Data
Specify path to the Data directory, if it is not installed in the default location, or script was not able to discover the data directory.
By default, the Data directory is C:\ProgramData\CloudBees\Software Delivery Automation\ .

.PARAMETER Install
Specify path to the installation directory.
By default, the Install directory is C:\Program Files\CloudBees\Software Delivery Automation\ .

.PARAMETER Temp
Path to a temporary directory with write permissions required as part of the migration. If the Temp parameter is not specified, the script uses $env:TEMP.

.PARAMETER JavaHome
Path to the Java Home directory. By default, the Java included in the CloudBees Analytics install directory is used.

.PARAMETER Help
Prints usage and quits.


.EXAMPLE
# The CloudBees Analytics installation directory is "C:\Program Files\DOIS\", the data directory is "C:\ProgramData\DOIS\", and the transport port is 9301:
PS> update-role-permissions.ps1 -Install "C:\Program Files\DOIS\CloudBees\Software Delivery Automation" -Data "C:\ProgramData\DOIS\CloudBees\Software Delivery Automation" -Port 9301

.EXAMPLE
# The transport port is 9301:
PS> update-role-permissions.ps1 -Port 9301
# or
PS> update-role-permissions.ps1 -p 9301

.EXAMPLE
# To view the script usage:
PS> update-role-permissions.ps1 -Help
# or
PS> update-role-permissions.ps1 -h
#>

param (
    [Switch]$Help,
    [string]$Port,
    [string]$Data,
    [string]$Install,
    [string]$Temp,
    [string]$JavaHome
)


# Setup values to manage script
# Application name used to look for information in the the Windows registry:
$programName = "CloudBees Software Delivery Automation Analytics"
$logFile = "$env:TEMP\rolepermission.log"  # file to store logs
$LOG_TO_FILE = $true  # false if you dont need to log to file
$DEBUG = $false  # $true - to write debug messages, $false - debug messages will not appear in a log file

function Show-Usage {
    $usage = @"
Usage: update-role-permissions.ps1 [-Help] [-Port <number>] [-Data <path>] [-Install <path>] [-Temp <path>] [-JavaHome <path>]

Parameters:
    -Help          Show usage.
    -Port          Specify the trasport port for CloudBees Analytics.
    -Data          Specify the Data directory that contains the CloudBees Analytics config and YAML files.
    -Install        Specify the Path to the CloudBees Analytics installation folder.
    -Temp          Temporary directory with write permissions used for temporary config files while updating. 
    -JavaHome      Path to the JAVA HOME to use. 

Examples:
    update-role-permissions.ps1 -Port 9355
    update-role-permissions.ps1 -Help
    update-role-permissions.ps1 -p 9304 -t "C:\Users\<username>\AppData\Local\Temp"

Note:
    Script require Admin permissions.
    Use get-help at PowerShell to see more information:
    get-help .\updete-role-permissions.ps1
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


### functions ###

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

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

    $fileExistStatus = $false
    # Check file exists
    try {
        if (Test-Path -Path $path -PathType Leaf) {
            $fileExistStatus = $true
        }
    } catch {
        $fileExistStatus = $false
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

### End functions ###

if ($Help) {
    Show-Usage
    exit
}

# Prompt to run from Administrator.
if (-not (Test-Administrator) -and (-not $Analyze) ) {
    Write-Host "Please run the script with Administrator permissions. Quit." -ForegroundColor Yellow
    exit
}

# ES_DATA - Data directory, contains config and YAML files
# ES_INSTALL - Installation  direrctory for DOIS with ElasticSearch
# ES_JAVA_HOME - Java Home path
# ES_PORT - The transport port used for communication between nodes, specify a new port if it was not configured to the default 9300
# CONFIG_DIR_TMP - Temporary folder with write permissions used during migration

$ES_INSTALL = $env:ES_INSTALL
$ES_JAVA_HOME = $env:ES_JAVA_HOME
$ES_DATA = $env:ES_DATA
$ES_PORT = $env:ES_PORT
$CONFIG_DIR_TMP = $env:CONFIG_DIR_TMP


# Handling commandline parameters
if ($Port) {
    Write-Log -level "info" -message "Passed Port from command line as: $Port"
    $ES_PORT = $Port
}

if ($Data) {
    Write-Log -level "info" -message "Passed path to Data folder from command line as: $Data"
    $ES_DATA = $Data
}
if ($Install) {
    Write-Log -level "info" -message "Passed Install directory from from command line as: $Install"
    $ES_INSTALL = $Install
}

if ($Temp) {
    Write-Log -level "info" -message "Passed path to Temp directory with write permissions from command line as: $Temp"
    $CONFIG_DIR_TMP = $Temp
}

if ($JavaHome) {
    Write-Log -level "info" -message "Passed path to JAVA_HOME: $JavaHome"
    $ES_JAVA_HOME = $JavaHome
}

$null = Remove-Item -Path $logFile -Recurse -Force

if ($LOG_TO_FILE) {
    Write-Log -level "info" -message "Log file can be found at: $logFile"
}

# read data from registry
$installation = Get-Program32InstallPath -programName $programName
$installLocation = $installation.InstallLocation
$dataDirectory = $installation.dataDirectory

if ($ES_INSTALL) {
    $installLocation = $ES_INSTALL
}

if ($ES_DATA) {
    $dataDirectory = $ES_DATA
}

if ($ES_JAVA_HOME) {
    $env:JAVA_HOME = $ES_JAVA_HOME
    $javaBin = "$env:JAVA_HOME\bin\java.exe"
} else {
    $env:JAVA_HOME= "$installLocation\reporting\jre"
    $javaBin = "$installLocation\reporting\jre\bin\java.exe"
}

$tempFile = [System.IO.Path]::Combine($path, [System.IO.Path]::GetRandomFileName())

if ($CONFIG_DIR_TMP) {
    $temporaryConfigDirectory = "$CONFIG_DIR_TMP\$tempFile"
} else {
    $temporaryConfigDirectory = "$env:TEMP\$tempFile"
}

Write-Log -level "debug" -message "Looking for search-guard plugin archive"
$patternSearchGuardArchive = "search-guard*plugin-7*.zip"
$zipFilesByPattern = Get-ChildItem -Path "$installLocation\reporting" -Filter $patternSearchGuardArchive

$zipPluginPath = ""
if ($zipFilesByPattern.Count -eq 0) {
    Write-Log -level "debug" -message "There is no archive for serach-guard at $installLocation. Perhaps there is already installed plugin and it is not needed install it."
} else {
    # prepare path to the zip archive which must be extracted
    $zipPluginPath = "$installLocation\reporting\$zipFilesByPattern"
}

# path to the directory to extract archive with plugin
$searchGuard7Lib = "$installLocation\reporting\elasticsearch\plugins\search-guard-7"
Write-Log -level "debug" -message "See searchGuard7Lib: $searchGuard7Lib"

# check if directory with search-guard plugin does not exists
if (-not (Test-DirectoryExists -path $searchGuard7Lib)) {
    Write-Log -level "info" -message "There is no plugin installed at $searchGuard7Lib"
    if ($zipPluginPath) {
        Write-Log -level "info" -message "Found archive $zipPluginPath, goign to extract it to the $searchGuard7Lib"
        Expand-Archive -Path $zipPluginPath -DestinationPath $searchGuard7Lib
    } else {
        Write-Log -lever "error" -message "There is no archive with search-guard plugin. Nothing to extract."
    }
}


$elasticSearchLib = "$installLocation\reporting\elasticsearch\lib"
$elasticSearchConfig = "$dataDirectory\conf\reporting\elasticsearch"


Write-Log -level "debug" -message "Install location: $installLocation"
Write-Log -level "debug" -message "Install data directory: $dataDirectory"
Write-Log -level "debug" -message "Install SG7 plugin lib directory: $searchGuard7Lib"
Write-Log -level "debug" -message "Install ES lib directory: $elasticSearchLib"
Write-Log -level "debug" -message "Java bin: $javaBin"
Write-Log -level "debug" -message "Config file for elasticsearch: $elasticsearchYml"

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
Set-Content -Path "$temporaryConfigDirectory\sg_roles.yml" -Value $SG_ROLES


$adminkeystore = "$temporaryConfigDirectory\admin-keystore.jks"
$truststore = "$temporaryConfigDirectory\truststore.jks"
$elasticsearchYml = "$temporaryConfigDirectory\elasticsearch.yml"
$sgRoles =  "$temporaryConfigDirectory\sg_roles.yml"
$sgRolesMapping = "$temporaryConfigDirectory\sg_roles_mapping.yml"

$valuableDirectories = ("installLocation", "dataDirectory",
"searchGuard7Lib", "elasticSearchLib", "temporaryConfigDirectory")

$valuableFiles = ("javaBin", "adminkeystore", "truststore", "elasticsearchYml", "sgRoles", "sgRolesMapping")

$allDirectoriesExists = $true

Write-Log  -level "debug" -message "Checking that directories are available."

# Check for directories
foreach ($variableName in $valuableDirectories) {
    $value = Get-Variable -Name $variableName -ValueOnly
    Write-Log  -level "debug" -message "$variableName : $value"

    if ( -not (Test-DirectoryExists -path $value)) {
        Write-Log -level "error" -message "Directory from $variableName with value: $value, not exists or not available"
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
    Write-Log -level "error" -message "Please check files availability. Quit."
}
if ( -not $allFilesOK ) {
    Write-Log -level "error"  "Please check all directories available. Quit."
}
if ( -not ($allDirectoriesExists -and $allFilesOK) ) {
    exit(-1)
}


if (-not $ES_PORT) {
    # Looking for a transport port-number
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
                Write-Log -level "debug" -message "Port-number is : $portNumber"
            }

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
}


$args =  "-cp", "$searchGuard7Lib\*;$elasticSearchLib\*",  `
  "com.floragunn.searchguard.tools.SearchGuardAdmin", `
  "-cd", "$temporaryConfigDirectory", `
  "-ks", "$adminkeystore", "-kspass", "abcdef", `
  "-ts", "$truststore", "-tspass", "abcdef", `
  "-h", "localhost", "-p", $portNumber, "-nhnv", "-icl"


Write-Log -level "debug" -message "Executing next command: & $javaBin $args"

# apply permissions
& "$javaBin"  $args
if ($LASTEXITCODE -eq 0) {
    Write-Log -message "Process successfully finished"
} else {
    Write-Log  -message  "Process finished with Error $($process.ExitCode)"
}

Write-Log -level "debug" -message "tempDir: $temporaryConfigDirectory. Cleaning it."

# Comment next line if you want to keep files in temp dir
Remove-Item -Path $temporaryConfigDirectory -Recurse -Force
if ($LOG_TO_FILE) {
    Write-Log -message "See log file: $logFile"
}