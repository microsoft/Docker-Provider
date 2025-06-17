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
