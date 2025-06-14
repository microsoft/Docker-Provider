# PowerShell function for testing Get-McsEndpoint
# Original source: kubernetes/windows/main.ps1

function Get-McsEndpoint() {
    $mcs_endpoint = "https://monitor.azure.com/"
    $cloud_environment = Get-ClusterCloudEnvironment
    switch ($cloud_environment) {
        "azurepubliccloud"        { $mcs_endpoint = "https://monitor.azure.com/" }
        "azurechinacloud"         { $mcs_endpoint = "https://monitor.azure.cn/" }
        "azureusgovernmentcloud"  { $mcs_endpoint = "https://monitor.azure.us/" }
        "usnat"                   { $mcs_endpoint = "https://monitor.azure.eaglex.ic.gov/" }
        "ussec"                   { $mcs_endpoint = "https://monitor.azure.microsoft.scloud/" }
        "bleu"                    { $mcs_endpoint = "https://monitor.sovcloud-api.fr/" }
    }
    return $mcs_endpoint
}
