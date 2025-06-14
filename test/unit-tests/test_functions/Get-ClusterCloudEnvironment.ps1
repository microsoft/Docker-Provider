# PowerShell function for testing Get-ClusterCloudEnvironment
# Original source: kubernetes/windows/main.ps1

$script:SUPPORTED_CLOUDS = @(
    "azurepubliccloud",
    "azurechinacloud",
    "azureusgovernmentcloud",
    "usnat",
    "ussec",
    "bleu"
)

function Get-ClusterCloudEnvironment() {
    # Use provided cloud environment variable if it's set and valid
    if ($env:CLUSTER_CLOUD_ENVIRONMENT) {
        foreach ($cloud in $SUPPORTED_CLOUDS) {
            if ($env:CLUSTER_CLOUD_ENVIRONMENT -eq $cloud) {
                return $env:CLUSTER_CLOUD_ENVIRONMENT
            }
        }
    }

    # Fallback to reading from the AMA logs secret if not set or not supported
    # Default domain
    $domain = "opinsights.azure.com"
    $domainPath = Join-Path $script:TEST_DIR "etc/ama-logs-secret/DOMAIN"
    if (Test-Path $domainPath) {
        $domain = Get-Content $domainPath
    }

    # Map domain to cloud environment
    switch ($domain) {
        "opinsights.azure.com"                { return "azurepubliccloud" }
        "opinsights.azure.cn"                 { return "azurechinacloud" }
        "opinsights.azure.us"                 { return "azureusgovernmentcloud" }
        "opinsights.azure.eaglex.ic.gov"      { return "usnat" }
        "opinsights.azure.microsoft.scloud"   { return "ussec" }
        "opinsights.sovcloud-api.fr"          { return "bleu" }
        default                               { return "unknown" }
    }
}
