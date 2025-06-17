function Get-McsEndpoint {
    param (
        [string]$cloud_environment
    )
    $mcs_endpoint = "https://monitor.azure.com/"
    if (![string]::IsNullOrEmpty($cloud_environment)) {
        switch ($cloud_environment.ToLower()) {
            "azurepubliccloud"        { $mcs_endpoint = "https://monitor.azure.com/" }
            "azurechinacloud"         { $mcs_endpoint = "https://monitor.azure.cn/" }
            "azureusgovernmentcloud"  { $mcs_endpoint = "https://monitor.azure.us/" }
            "usnat"                   { $mcs_endpoint = "https://monitor.azure.eaglex.ic.gov/" }
            "ussec"                   { $mcs_endpoint = "https://monitor.azure.microsoft.scloud/" }
            "bleu"                    { $mcs_endpoint = "https://monitor.sovcloud-api.fr/" }
        }
    }
    return $mcs_endpoint
}