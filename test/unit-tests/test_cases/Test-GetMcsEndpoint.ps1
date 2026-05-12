# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function dependencies
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-McsEndpoint.ps1")

function Test-CloudEnvironments {
    $testCases = @(
        @{
            cloud = "azurepubliccloud"
            expected = "monitor.azure.com"
        },
        @{
            cloud = "azurechinacloud"
            expected = "monitor.azure.cn"
        },
        @{
            cloud = "azureusgovernmentcloud"
            expected = "monitor.azure.us"
        },
        @{
            cloud = "usnat"
            expected = "monitor.azure.eaglex.ic.gov"
        },
        @{
            cloud = "ussec"
            expected = "monitor.azure.microsoft.scloud"
        },
        @{
            cloud = "azurebleucloud"
            expected = "monitor.sovcloud-api.fr"
        },
        @{
            cloud = "azuredeloscloud"
            expected = "monitor.sovcloud-api.de"
        }
    )

    foreach ($testCase in $testCases) {
        Setup
        $result = Get-McsEndpoint -cloud_environment $testCase.cloud
        Assert-Equals $testCase.expected $result "(with cloud_environment=$($testCase.cloud))"
        Teardown
    }
}

function Test-DefaultEndpoint {
    Setup
    $result = Get-McsEndpoint -cloud_environment $null
    Assert-Equals "monitor.azure.com" $result "(with null cloud environment)"

    $result = Get-McsEndpoint -cloud_environment ""
    Assert-Equals "monitor.azure.com" $result "(with empty cloud environment)"

    $result = Get-McsEndpoint -cloud_environment "invalid"
    Assert-Equals "monitor.azure.com" $result "(with invalid cloud environment)"
    Teardown
}

function Test-CaseSensitivity {
    $testCases = @(
        "AZUREPUBLICCLOUD",
        "AzurePublicCloud",
        "azurePUBLICcloud"
    )

    foreach ($cloud in $testCases) {
        Setup
        $result = Get-McsEndpoint -cloud_environment $cloud
        Assert-Equals "monitor.azure.com" $result "(case sensitivity check for $cloud)"
        Teardown
    }
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Get-McsEndpoint..."
    Write-Host "======================================"

    Test-CloudEnvironments
    Test-DefaultEndpoint
    Test-CaseSensitivity

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
