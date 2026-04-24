function Get-McsEndpoint {
    param (
        [string]$cloud_environment
    )
    $mcs_endpoint = "monitor.azure.com"
    if (![string]::IsNullOrEmpty($cloud_environment)) {
        switch ($cloud_environment.ToLower()) {
            "azurepubliccloud"        { $mcs_endpoint = "monitor.azure.com" }
            "azurechinacloud"         { $mcs_endpoint = "monitor.azure.cn" }
            "azureusgovernmentcloud"  { $mcs_endpoint = "monitor.azure.us" }
            "usnat"                   { $mcs_endpoint = "monitor.azure.eaglex.ic.gov" }
            "ussec"                   { $mcs_endpoint = "monitor.azure.microsoft.scloud" }
            "azurebleucloud"          { $mcs_endpoint = "monitor.sovcloud-api.fr" }
            "azuredeloscloud"         { $mcs_endpoint = "monitor.sovcloud-api.de" }
        }
    }
    return $mcs_endpoint
}