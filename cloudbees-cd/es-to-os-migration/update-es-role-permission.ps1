<#
.SYNOPSIS
This script must change roles permissions for user of ElasticSearch installed
by CloudBees Software Delivery Automation Analytics.
Script require Admin permissions.

.DESCRIPTION
CloudBees Software Delivery Automation Analytics moved from ElasticSearch to OpenSearch in a release 2024.06
To migrate from ElasticSearch to OpenSearch starting 2023.12 and later no need any changes. If any issues
with older release in time of migration - current script can help with role permissions issues.
Aplay this script before migrate from 2023.8 or older to the 2024.06 or younger.
Script will try automatically find all needed values and if any issues to do it  - will report you about issues.

.PARAMETER Port
Specify CloudBees Software Delivery Automation Analytics transport port if you know it. Script will try to read port namber from config file.


.PARAMETER Data
Specify path to the Data folder if it is not installed by default or script was not able figureout location of that folder.
By default it will be installed as C:\ProgramData\CloudBees\Software Delivery Automation\ .

.PARAMETER Install
Specify path to the installation directory.
By default it will be installed as C:\Program Files\CloudBees\Software Delivery Automation\ .

.PARAMETER Temp
Path to the temporary folder with write permissions. If parameter will not be specifyed script will use directory $env:TEMP

.PARAMETER JavaHome
Path to the Java Home directory. By default will be used java from install directory.

.PARAMETER Help
Script will print usage and quit.


.EXAMPLE
# if application installed to the  "C:\Program Files\DOIS\" and config installed to the  "C:\ProgramData\DOIS\" and transport port is 9301
PS> update-role-permissions.ps1 -Install "C:\Program Files\DOIS\CloudBees\Software Delivery Automation" -Data "C:\ProgramData\DOIS\CloudBees\Software Delivery Automation" -Port 9301

.EXAMPLE
# if port 9301
PS> update-role-permissions.ps1 -Port 9301
# or
PS> update-role-permissions.ps1 -p 9301

.EXAMPLE
# to see usage
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
# Apllication name to look for information about it at the Windows registry
$programName = "CloudBees Software Delivery Automation Analytics"
$logFile = "$env:TEMP\rolepermission.log"  # file to store logs
$LOG_TO_FILE = $true  # false if you dont need to log to file
$DEBUG = $false  # $true - to write debug messages, $false - debug messages will not appear in a log file

function Show-Usage {
    $usage = @"
Usage: update-role-permissions.ps1 [-Help] [-Port <number>] [-Data <path>] [-Install <path>] [-Temp <path>] [-JavaHome <path>]

Parameters:
    -Help          Show usage.
    -Port          Specify trasport prot for CloudBees Software Delivery Automation Analytics.
    -Data          Data directory, contains config and yaml files
    -Install       Path to the installation folder
    -Temp          Temporary directory with write permissions, will be used for temporary config files
    -JavaHome      Path to the JAVA HOME you like to use

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

# ES_DATA - data directory, contains config and yaml files
# ES_INSTALL - installation  direrctory for DOIS with ElasticSearch
# ES_JAVA_HOME - Home for java
# ES_PORT - the transport port used for communication between nodes, specify new port if it was not configured by default as 9300
# CONFIG_DIR_TMP - temporary folder with write permissions

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
    Write-Log -level "info" -message "Passed installation directory from from command line as: $Install"
    $ES_INSTALL = $Install
}

if ($Temp) {
    Write-Log -level "info" -message "Passed path to temporary directory with write permissions from command line as: $Temp"
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


Write-Log -level "debug" -message "Goign to execute next command: & $javaBin $args"

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