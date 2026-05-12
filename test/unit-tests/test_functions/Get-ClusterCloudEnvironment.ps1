function Is-SupportedCloudEnvironment {
    param (
        [string]$cloudEnvironment
    )
    $supportedCloudEnvironments = @("azurepubliccloud", "azurechinacloud", "azureusgovernmentcloud", "usnat", "ussec", "azurebleucloud", "azuredeloscloud")
    if ($supportedCloudEnvironments -contains $cloudEnvironment) {
        return $true
    }
    return $false
}

function Get-ClusterCloudEnvironment{
    param (
        [string]$logAnalyticsWorkspaceDomain
    )
    $cloud_environment = "azurepubliccloud"
    $clusterCloudEnvironment = [System.Environment]::GetEnvironmentVariable("CLUSTER_CLOUD_ENVIRONMENT", "process")
    if (![string]::IsNullOrEmpty($clusterCloudEnvironment) -and (Is-SupportedCloudEnvironment $clusterCloudEnvironment)) {
        $cloud_environment = $clusterCloudEnvironment
    } else {
        Write-Host "CLUSTER_CLOUD_ENVIRONMENT environment variable is not set. Falling back to determine the cloud environment based on the Log Analytics Workspace DOMAIN"
        if (![string]::IsNullOrEmpty($logAnalyticsWorkspaceDomain)) {
            switch ($logAnalyticsWorkspaceDomain.ToLower()) {
                "opinsights.azure.com"                { $cloud_environment = "azurepubliccloud" }
                "opinsights.azure.cn"                 { $cloud_environment = "azurechinacloud" }
                "opinsights.azure.us"                 { $cloud_environment = "azureusgovernmentcloud" }
                "opinsights.azure.eaglex.ic.gov"      { $cloud_environment = "usnat" }
                "opinsights.azure.microsoft.scloud"   { $cloud_environment = "ussec" }
                "opinsights.sovcloud-api.fr"          { $cloud_environment = "azurebleucloud" }
                "opinsights.sovcloud-api.de"          { $cloud_environment = "azuredeloscloud" }
            }
        } else {
            Write-Host "Domain name either null or empty. Defaulting to azurepubliccloud."
            $cloud_environment = "azurepubliccloud"
        }
    }
    return $cloud_environment
}
