# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function to test
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-ClusterCloudEnvironment.ps1")

function Test-ValidEnvironmentVariables {
    $testCases = @(
        "azurepubliccloud",
        "azurechinacloud",
        "azureusgovernmentcloud",
        "usnat",
        "ussec",
        "bleu"
    )

    foreach ($cloud in $testCases) {
        Setup
        $env:CLUSTER_CLOUD_ENVIRONMENT = $cloud
        $result = Get-ClusterCloudEnvironment
        Assert-Equals $cloud $result "(with CLUSTER_CLOUD_ENVIRONMENT=$cloud)"
        Teardown
    }
}

function Test-InvalidEnvironmentVariable {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "invalidcloud"
    $result = Get-ClusterCloudEnvironment
    Assert-Equals "unknown" $result "(with invalid CLUSTER_CLOUD_ENVIRONMENT)"
    Teardown
}

function Test-DomainFileFallback {
    $testCases = @(
        @{domain="opinsights.azure.com"; expected="azurepubliccloud"},
        @{domain="opinsights.azure.cn"; expected="azurechinacloud"},
        @{domain="opinsights.azure.us"; expected="azureusgovernmentcloud"},
        @{domain="opinsights.azure.eaglex.ic.gov"; expected="usnat"},
        @{domain="opinsights.azure.microsoft.scloud"; expected="ussec"},
        @{domain="opinsights.sovcloud-api.fr"; expected="bleu"}
    )

    foreach ($testCase in $testCases) {
        Setup
        Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
        Mock-File "etc/ama-logs-secret/DOMAIN" $testCase.domain
        $result = Get-ClusterCloudEnvironment
        Assert-Equals $testCase.expected $result "(with domain=$($testCase.domain))"
        Teardown
    }
}

function Test-InvalidDomain {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    Mock-File "etc/ama-logs-secret/DOMAIN" "invalid.domain.com"
    $result = Get-ClusterCloudEnvironment
    Assert-Equals "unknown" $result "(with invalid domain)"
    Teardown
}

function Test-EmptyDomain {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    Mock-File "etc/ama-logs-secret/DOMAIN" ""
    $result = Get-ClusterCloudEnvironment
    Assert-Equals "unknown" $result "(with empty domain)"
    Teardown
}

function Test-MissingDomainFile {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    # Don't create the domain file
    $result = Get-ClusterCloudEnvironment
    Assert-Equals "azurepubliccloud" $result "(with missing domain file - should use default)"
    Teardown
}

function Test-EnvPrecedenceOverDomain {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "azurepubliccloud"
    Mock-File "etc/ama-logs-secret/DOMAIN" "opinsights.azure.cn"
    $result = Get-ClusterCloudEnvironment
    Assert-Equals "azurepubliccloud" $result "(env should take precedence over domain)"
    Teardown
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Get-ClusterCloudEnvironment..."
    Write-Host "=============================================="

    Test-ValidEnvironmentVariables
    Test-InvalidEnvironmentVariable
    Test-DomainFileFallback
    Test-InvalidDomain
    Test-EmptyDomain
    Test-MissingDomainFile
    Test-EnvPrecedenceOverDomain

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
