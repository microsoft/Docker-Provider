# PowerShell function for testing Get-LogAnalyticsWorkspaceDomain
# Original source: kubernetes/windows/main.ps1

function Get-LogAnalyticsWorkspaceDomain() {
    $domain = "opinsights.azure.com"
    $domainFile = Join-Path $script:TEST_DIR "etc/ama-logs-secret/DOMAIN"
    if (Test-Path $domainFile) {
        $domain = Get-Content $domainFile
        if (![string]::IsNullOrEmpty($domain)) {
            switch ($domain) {
                "opinsights.azure.cn"                 { $domain = "opinsights.azure.cn" }
                "opinsights.azure.us"                 { $domain = "opinsights.azure.us" }
                "opinsights.azure.eaglex.ic.gov"      { $domain = "opinsights.azure.eaglex.ic.gov" }
                "opinsights.azure.microsoft.scloud"   { $domain = "opinsights.azure.microsoft.scloud" }
                "opinsights.sovcloud-api.fr"          { $domain = "opinsights.sovcloud-api.fr" }
                default                               { Write-Host "Unknown domain '$domain'. Defaulting to opinsights.azure.com."; $domain = "opinsights.azure.com" }
            }
        }
        else {
            Write-Host "Domain name either null or empty. Defaulting to opinsights.azure.com."
        }
    }
    return $domain
}
