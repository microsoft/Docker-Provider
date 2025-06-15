# PowerShell function for testing Get-LogAnalyticsWorkspaceDomain
# Original source: kubernetes/windows/main.ps1

# Mock Test-Path and Get-Content for testing
function Test-Path {
    param([string]$Path)
    if ($Path -eq "/etc/ama-logs-secret/DOMAIN") {
        return Test-Path (Join-Path $script:TEST_DIR "/etc/ama-logs-secret/DOMAIN")
    }
    Microsoft.PowerShell.Management\Test-Path $Path
}

function Get-Content {
    param([string]$Path)
    if ($Path -eq "/etc/ama-logs-secret/DOMAIN") {
        return Microsoft.PowerShell.Management\Get-Content (Join-Path $script:TEST_DIR "/etc/ama-logs-secret/DOMAIN")
    }
    Microsoft.PowerShell.Management\Get-Content $Path
}

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
