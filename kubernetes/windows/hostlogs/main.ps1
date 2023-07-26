$rootDir = Get-Location

function Start-FileSystemWatcher {
    Start-Process powershell -NoNewWindow .\opt\hostlogswindows\scripts\powershell\filesystemwatcher.ps1
}

function Set-EnvironmentVariables {

    $aksRegion = [System.Environment]::GetEnvironmentVariable("AKS_REGION", "process")

    $schemaVersionFile = './etc/config/settings/schema-version'
    if (Test-Path $schemaVersionFile) {
        $schemaVersion = Get-Content $schemaVersionFile | ForEach-Object { $_.TrimEnd() }
        if ($schemaVersion.GetType().Name -eq 'String') {
            [System.Environment]::SetEnvironmentVariable("AZMON_AGENT_CFG_SCHEMA_VERSION", $schemaVersion, "Process")
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
    Write-Host "Starting Windows AMA in 1P Mode"

    Start-Job -Name "WindowsHostLogsJob" -ScriptBlock { 
        Start-Process -NoNewWindow -FilePath ".\opt\genevamonitoringagent\genevamonitoringagent\Monitoring\Agent\MonAgentLauncher.exe" -ArgumentList @("-useenv")
    }


} else {
    Write-Host "Geneva not configured. Watching for config map."

    [System.Environment]::SetEnvironmentVariable("MONITORING_GCS_ENVIRONMENT", "Test" ,"Process")
    [System.Environment]::SetEnvironmentVariable("MONITORING_GCS_ACCOUNT", "PLACEHOLDER", "Process")
    [System.Environment]::SetEnvironmentVariable("MONITORING_GCS_NAMESPACE", "PLACEHOLDER", "Process")
    [System.Environment]::SetEnvironmentVariable("MONITORING_CONFIG_VERSION", "PLACEHOLDER", "Process")
    [System.Environment]::SetEnvironmentVariable("MONITORING_MANAGED_ID_IDENTIFIER", "PLACEHOLDER", "Process")
    [System.Environment]::SetEnvironmentVariable("MONITORING_MANAGED_ID_VALUE", "PLACEHOLDER", "Process")


    Start-Job -Name "WindowsHostLogsJob" -ScriptBlock { 
        Start-Process -NoNewWindow -FilePath ".\opt\genevamonitoringagent\genevamonitoringagent\Monitoring\Agent\MonAgentLauncher.exe" -ArgumentList @("-useenv")
    }
}

# Execute Notepad.exe to keep container alive since there is nothing in the foreground.
Notepad.exe | Out-Null

Write-Host "Main.ps1 ending"