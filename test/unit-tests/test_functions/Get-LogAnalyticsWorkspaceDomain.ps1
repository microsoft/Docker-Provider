# PowerShell function for testing Get-LogAnalyticsWorkspaceDomain
# Original source: kubernetes/windows/main.ps1

function Get-LogAnalyticsWorkspaceDomain() {
    $defaultDomain = "opinsights.azure.com"
    $domainFile = "/etc/ama-logs-secret/DOMAIN"
    if (Test-Path $domainFile) {
        $domain = (Get-Content $domainFile).Trim()
        if (![string]::IsNullOrEmpty($domain)) {
            switch ($domain.ToLower()) {
                "opinsights.azure.cn"                 { return "opinsights.azure.cn" }
                "opinsights.azure.us"                 { return "opinsights.azure.us" }
                "opinsights.azure.eaglex.ic.gov"      { return "opinsights.azure.eaglex.ic.gov" }
                "opinsights.azure.microsoft.scloud"   { return "opinsights.azure.microsoft.scloud" }
                "opinsights.sovcloud-api.fr"          { return "opinsights.sovcloud-api.fr" }
                "opinsights.azure.com"                { return "opinsights.azure.com" }
                default                              { Write-Host "Unknown domain '$domain'. Defaulting to opinsights.azure.com."; return $defaultDomain }
            }
        } else {
            Write-Host "Domain name either null or empty. Defaulting to opinsights.azure.com."
            return $defaultDomain
        }
    } else {
        Write-Host "Domain file not found. Defaulting to opinsights.azure.com."
        return $defaultDomain
    }
}
