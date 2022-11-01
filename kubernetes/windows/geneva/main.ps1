$rootDir = Get-Location

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

    $podName = [System.Environment]::GetEnvironmentVariable("PODNAME", "process")
    if ([string]::IsNullOrEmpty($podName)) {
        Write-Host "Failed to get environment variable PODNAME"
    }

    # Set env vars for geneva monitor
    $envVars = @{
        MONITORING_DATA_DIRECTORY = (Join-Path $rootDir "opt\genevamonitoringagent\datadirectory")
        MONITORING_GCS_AUTH_ID_TYPE = "AuthMSIToken"
        MONITORING_MANAGED_ID_IDENTIFIER = "object_id"
        MONITORING_GCS_REGION = $aksregion
        MA_RoleEnvironment_Location = $aksregion
        MA_RoleEnvironment_ResourceId = $aksResourceId
        MONITORING_TENANT = "CloudAgent"
        MONITORING_ROLE = "Windows-HPC-Geneva"
        MONITORING_ROLE_INSTANCE = "$hostName-$podName"

        MONITORING_MANAGED_ID_VALUE="VALUE_MSI_OBJECT_ID"
        MONITORING_GCS_ACCOUNT = "VALUE_GCS_ACCOUNT"
        MONITORING_GCS_NAMESPACE = "VALUE_GCS_NAMESPACE"              
        MONITORING_GCS_ENVIRONMENT = "VALUE_GCS_ENVIRONMENT}"
        MONITORING_CONFIG_VERSION = "VALUE_GCS_CONFIG_VERSION"
    }

    foreach($key in $envVars.PSBase.Keys) {
        [System.Environment]::SetEnvironmentVariable($key, $envVars[$key], "Process")
        [System.Environment]::SetEnvironmentVariable($key, $envVars[$key], "Machine")
    }
}

Start-Transcript -Path main.txt

Set-EnvironmentVariables

Invoke-Expression ".\opt\genevamonitoringagent\genevamonitoringagent\Monitoring\Agent\MonAgentLauncher.exe -useenv"
