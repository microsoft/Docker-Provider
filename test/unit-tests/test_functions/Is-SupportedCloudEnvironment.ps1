# PowerShell function for testing Is-SupportedCloudEnvironment
# Original source: kubernetes/windows/main.ps1

function Is-SupportedCloudEnvironment {
    param (
        [string]$cloudEnvironment
    )
    $supportedCloudEnvironments = @("azurepubliccloud", "azurechinacloud", "azureusgovernmentcloud", "usnat", "ussec", "bleu")
    if ($supportedCloudEnvironments -contains $cloudEnvironment) {
        return $true
    }
    return $false
}
