function Is-CanaryRegion {
    param (
        [string]$aksRegion
    )
    $canaryRegions = @("eastus2euap", "centraluseuap")
    if ($canaryRegions -contains $aksRegion.ToLower()) {
        return $true
    }
    return $false
}

function Get-McsGlobalEndpoint {
    param (
        [string]$cloud_environment
    )
    $mcs_globalendpoint = "https://global.handler.control.monitor.azure.com"
    $aksRegion = [System.Environment]::GetEnvironmentVariable("AKS_REGION", "process")
    if (Is-CanaryRegion $aksRegion) {
        $mcs_globalendpoint = "https://global.handler.canary.control.monitor.azure.com"
    } else {
        if (![string]::IsNullOrEmpty($cloud_environment)) {
            switch ($cloud_environment) {
                "azurepubliccloud"        { $mcs_globalendpoint = "https://global.handler.control.monitor.azure.com" }
                "azurechinacloud"         { $mcs_globalendpoint = "https://global.handler.control.monitor.azure.cn" }
                "azureusgovernmentcloud"  { $mcs_globalendpoint = "https://global.handler.control.monitor.azure.us" }
                "usnat"                   { $mcs_globalendpoint = "https://global.handler.control.monitor.azure.eaglex.ic.gov" }
                "ussec"                   { $mcs_globalendpoint = "https://global.handler.control.monitor.azure.microsoft.scloud" }
                "bleu"                    { $mcs_globalendpoint = "https://global.handler.control.sovcloud-api.fr" }
            }
        }
    }
    return $mcs_globalendpoint
}
