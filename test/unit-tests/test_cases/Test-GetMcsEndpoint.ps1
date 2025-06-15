# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function dependencies
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-McsEndpoint.ps1")

function Test-CloudEnvironments {
    $testCases = @(
        @{
            cloud = "azurepubliccloud"
            expected = "https://monitor.azure.com/"
        },
        @{
            cloud = "azurechinacloud"
            expected = "https://monitor.azure.cn/"
        },
        @{
            cloud = "azureusgovernmentcloud"
            expected = "https://monitor.azure.us/"
        },
        @{
            cloud = "usnat"
            expected = "https://monitor.azure.eaglex.ic.gov/"
        },
        @{
            cloud = "ussec"
            expected = "https://monitor.azure.microsoft.scloud/"
        },
        @{
            cloud = "bleu"
            expected = "https://monitor.sovcloud-api.fr/"
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
    Assert-Equals "https://monitor.azure.com/" $result "(with null cloud environment)"

    $result = Get-McsEndpoint -cloud_environment ""
    Assert-Equals "https://monitor.azure.com/" $result "(with empty cloud environment)"

    $result = Get-McsEndpoint -cloud_environment "invalid"
    Assert-Equals "https://monitor.azure.com/" $result "(with invalid cloud environment)"
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
        Assert-Equals "https://monitor.azure.com/" $result "(case sensitivity check for $cloud)"
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
