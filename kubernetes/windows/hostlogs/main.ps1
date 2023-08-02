function Start-FileSystemWatcher {
    Start-Process powershell -NoNewWindow .\opt\hostlogswindows\scripts\powershell\filesystemwatcher.ps1
}

function Set-EnvironmentVariables {

    $schemaVersionFile = './etc/config/settings/schema-version'
    if (Test-Path $schemaVersionFile) {
        $schemaVersion = Get-Content $schemaVersionFile | ForEach-Object { $_.TrimEnd() }
        if ($schemaVersion.GetType().Name -eq 'String') {
            [System.Environment]::SetEnvironmentVariable("AZMON_AGENT_CFG_SCHEMA_VERSION", $schemaVersion, "Process")
        }
        $env:AZMON_AGENT_CFG_SCHEMA_VERSION
    }

    # run config parser
    $rubypath =  "./ruby31/bin/ruby.exe"

    #Parse the configmap to set the right environment variables for geneva config.
    & $rubypath ./opt/hostlogswindows/scripts/ruby/tomlparser-hostlogs-geneva-config.rb
    .\setagentenv.ps1
}

function Get-GenevaEnvironmentConfiguration {
  $gcsDataDirectory = [System.Environment]::GetEnvironmentVariable("MONITORING_DATA_DIRECTORY", "process")
  $gcsAuthIdType = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_AUTH_ID_TYPE", "process")
  $gcsRegion = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_REGION", "process")
  $gcsEnvironment = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_ENVIRONMENT", "process")
  $gcsAccount = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_ACCOUNT", "process")
  $gcsNamespace = [System.Environment]::GetEnvironmentVariable("MONITORING_GCS_NAMESPACE", "process")
  $gcsConfigVersion = [System.Environment]::GetEnvironmentVariable("MONITORING_CONFIG_VERSION", "process")
  $gcsAuthIdIdentifier = [System.Environment]::GetEnvironmentVariable("MONITORING_MANAGED_ID_IDENTIFIER", "process")
  $gcsAuthIdValue = [System.Environment]::GetEnvironmentVariable("MONITORING_MANAGED_ID_VALUE", "process")

  return (![string]::IsNullOrEmpty($gcsDataDirectory)) -and
    (![string]::IsNullOrEmpty($gcsAuthIdType)) -and
    (![string]::IsNullOrEmpty($gcsRegion)) -and
    (![string]::IsNullOrEmpty($gcsEnvironment)) -and 
    (![string]::IsNullOrEmpty($gcsAccount)) -and 
    (![string]::IsNullOrEmpty($gcsNamespace)) -and
    (![string]::IsNullOrEmpty($gcsConfigVersion)) -and 
    (![string]::IsNullOrEmpty($gcsAuthIdIdentifier))  -and 
    (![string]::IsNullOrEmpty($gcsAuthIdValue)) 
}

Start-Transcript -Path main.txt

Set-EnvironmentVariables
Start-FileSystemWatcher

if(Get-GenevaEnvironmentConfiguration)
{
    Write-Host "Geneva environment is configured. Starting Windows AMA in 1P Mode"

    Start-Job -Name "WindowsHostLogsJob" -ScriptBlock { 
        Start-Process -NoNewWindow -FilePath ".\opt\genevamonitoringagent\genevamonitoringagent\Monitoring\Agent\MonAgentLauncher.exe" -ArgumentList @("-useenv")
    }
} 
else 
{
    Write-Host "Geneva environment not configured. Liveness probe will fail the container."
}

# Execute Notepad.exe to keep container alive since there is nothing in the foreground.
Notepad.exe | Out-Null

Write-Host "Main.ps1 ending"