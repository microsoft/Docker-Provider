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
        "azurebleucloud",
        "azuredeloscloud"
    )

    foreach ($cloud in $testCases) {
        Setup
        $env:CLUSTER_CLOUD_ENVIRONMENT = $cloud
        $result = Get-ClusterCloudEnvironment "dummy"  # domain parameter won't be used due to env var
        Assert-Equals $cloud $result "(with CLUSTER_CLOUD_ENVIRONMENT=$cloud)"
        Teardown
    }
}

function Test-InvalidEnvironmentVariable {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "invalidcloud"
    $result = Get-ClusterCloudEnvironment "dummy"
    Assert-Equals "azurepubliccloud" $result "(with invalid CLUSTER_CLOUD_ENVIRONMENT - should default to public cloud)"
    Teardown
}

function Test-DomainFileFallback {
    $testCases = @(
        @{domain="opinsights.azure.com"; expected="azurepubliccloud"},
        @{domain="opinsights.azure.cn"; expected="azurechinacloud"},
        @{domain="opinsights.azure.us"; expected="azureusgovernmentcloud"},
        @{domain="opinsights.azure.eaglex.ic.gov"; expected="usnat"},
        @{domain="opinsights.azure.microsoft.scloud"; expected="ussec"},
        @{domain="opinsights.sovcloud-api.fr"; expected="azurebleucloud"},
        @{domain="opinsights.sovcloud-api.de"; expected="azuredeloscloud"}
    )

    foreach ($testCase in $testCases) {
        Setup
        Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
        $result = Get-ClusterCloudEnvironment $testCase.domain
        Assert-Equals $testCase.expected $result "(with domain=$($testCase.domain))"
        Teardown
    }
}

function Test-InvalidDomain {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    $result = Get-ClusterCloudEnvironment "invalid.domain.com"
    Assert-Equals "azurepubliccloud" $result "(with invalid domain - should default to public cloud)"
    Teardown
}

function Test-EmptyDomain {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    $result = Get-ClusterCloudEnvironment ""
    Assert-Equals "azurepubliccloud" $result "(with empty domain - should default to public cloud)"
    Teardown
}

function Test-NullDomain {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    $result = Get-ClusterCloudEnvironment $null
    Assert-Equals "azurepubliccloud" $result "(with null domain - should default to public cloud)"
    Teardown
}

function Test-EnvPrecedenceOverDomain {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "azurepubliccloud"
    $result = Get-ClusterCloudEnvironment "opinsights.azure.cn"
    Assert-Equals "azurepubliccloud" $result "(env should take precedence over domain)"
    Teardown
}

function Test-SupportedCloudCheck {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "AzurePublicCloud"  # Case sensitive
    $result = Get-ClusterCloudEnvironment "dummy"
    Assert-Equals "azurepubliccloud" $result "(should default to public cloud for unsupported case)"
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
    Test-NullDomain
    Test-EnvPrecedenceOverDomain
    Test-SupportedCloudCheck

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
