$rootDir = Get-Location

function Start-FileSystemWatcher {
    Start-Process powershell -NoNewWindow .\opt\hostlogswindows\scripts\powershell\filesystemwatcher.ps1
}

function Set-EnvironmentVariables {

    $aksResourceId = [System.Environment]::GetEnvironmentVariable("AKS_RESOURCE_ID", "process")
    if (![string]::IsNullOrEmpty($aksResourceId)) {
        [System.Environment]::SetEnvironmentVariable("AKS_RESOURCE_ID", $aksResourceId, "machine")
        Write-Host "Successfully set environment variable AKS_RESOURCE_ID - $($aksResourceId) for target 'machine'..."
    }
    else {
        Write-Host "Failed to set environment variable AKS_RESOURCE_ID for target 'machine' since it is either null or empty"
    }

    $aksRegion = [System.Environment]::GetEnvironmentVariable("AKS_REGION", "process")
    if (![string]::IsNullOrEmpty($aksRegion)) {
        [System.Environment]::SetEnvironmentVariable("AKS_REGION", $aksRegion, "machine")
        Write-Host "Successfully set environment variable AKS_REGION - $($aksRegion) for target 'machine'..."
    }
    else {
        Write-Host "Failed to set environment variable AKS_REGION for target 'machine' since it is either null or empty"
    }

    $hostName = [System.Environment]::GetEnvironmentVariable("HOSTNAME", "process")
    if (![string]::IsNullOrEmpty($hostName)) {
        [System.Environment]::SetEnvironmentVariable("HOSTNAME", $hostName, "machine")
        Write-Host "Successfully set environment variable HOSTNAME - $($hostName) for target 'machine'..."
    }
    else {
        Write-Host "Failed to set environment variable HOSTNAME for target 'machine' since it is either null or empty"
    }


    $schemaVersionFile = './etc/config/settings/schema-version'
    if (Test-Path $schemaVersionFile) {
        $schemaVersion = Get-Content $schemaVersionFile | ForEach-Object { $_.TrimEnd() }
        if ($schemaVersion.GetType().Name -eq 'String') {
            [System.Environment]::SetEnvironmentVariable("AZMON_AGENT_CFG_SCHEMA_VERSION", $schemaVersion, "Process")
            [System.Environment]::SetEnvironmentVariable("AZMON_AGENT_CFG_SCHEMA_VERSION", $schemaVersion, "Machine")
        }
        $env:AZMON_AGENT_CFG_SCHEMA_VERSION
    }

    # Set env vars for geneva monitor
    $envVars = @{
        MONITORING_DATA_DIRECTORY = (Join-Path $rootDir "opt\genevamonitoringagent\datadirectory")
        MONITORING_GCS_AUTH_ID_TYPE = "AuthMSIToken"
        MONITORING_GCS_REGION = "$aksregion"    
    }

    foreach($key in $envVars.PSBase.Keys) {
        [System.Environment]::SetEnvironmentVariable($key, $envVars[$key], "Process")
        [System.Environment]::SetEnvironmentVariable($key, $envVars[$key], "Machine")
    }

    # run config parser
    $rubypath =  "./ruby31/bin/ruby.exe"

    #Parse the configmap to set the right environment variables for geneva config.
    & $rubypath ./opt/hostlogswindows/scripts/ruby/tomlparser-hostlogs-geneva-config.rb
    .\setagentenv.ps1
}

function Get-GenevaEnabled {
  $gcsEnvironment = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_ENVIRONMENT", "process")
  $gcsAccount = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_ACCOUNT", "process")
  $gcsNamespace = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_NAMESPACE", "process")
  $gcsConfigVersion = [System.Environment]::GetEnvironmentVariable("MONITORING_CONFIG_VERSION", "process")
  $gcsAuthIdIdentifier = [System.Environment]::GetEnvironmentVariable("MONITORING_MANAGED_ID_IDENTIFIER", "process")
  $gcsAuthIdValue = [System.Environment]::GetEnvironmentVariable("MONITORING_MANAGED_ID_VALUE", "process")

  return (![string]::IsNullOrEmpty($gcsEnvironment)) -and 
    (![string]::IsNullOrEmpty($gcsAccount)) -and 
    (![string]::IsNullOrEmpty($gcsNamespace)) -and 
    (![string]::IsNullOrEmpty($gcsConfigVersion)) -and 
    (![string]::IsNullOrEmpty($gcsAuthIdIdentifier))  -and 
    (![string]::IsNullOrEmpty($gcsAuthIdValue)) 
}

Start-Transcript -Path main.txt

Set-EnvironmentVariables
Start-FileSystemWatcher

if(Get-GenevaEnabled){
    Invoke-Expression ".\opt\genevamonitoringagent\genevamonitoringagent\Monitoring\Agent\MonAgentLauncher.exe -useenv"
} else {
    Write-Host "Geneva not configured. Watching for config map"
    # Infinite loop keeps container alive while waiting for config map
    # Otherwise when the process ends, kubernetes sees this as a crash and the container will enter a crash loop
    while($true){
        Start-Sleep 3600
    }
}

