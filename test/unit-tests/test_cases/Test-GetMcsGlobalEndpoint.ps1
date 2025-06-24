# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function dependencies
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-McsGlobalEndpoint.ps1")

function Test-CanaryRegions {
    $testCases = @(
        "eastus2euap",
        "centraluseuap"
    )

    foreach ($region in $testCases) {
        Setup
        $env:AKS_REGION = $region
        $result = Get-McsGlobalEndpoint -cloud_environment "azurepubliccloud"
        Assert-Equals "https://global.handler.canary.control.monitor.azure.com" $result "(for canary region $region)"
        Teardown
    }
}

function Test-CloudEnvironments {
    $testCases = @(
        @{
            cloud = "azurepubliccloud"
            expected = "https://global.handler.control.monitor.azure.com"
        },
        @{
            cloud = "azurechinacloud"
            expected = "https://global.handler.control.monitor.azure.cn"
        },
        @{
            cloud = "azureusgovernmentcloud"
            expected = "https://global.handler.control.monitor.azure.us"
        },
        @{
            cloud = "usnat"
            expected = "https://global.handler.control.monitor.azure.eaglex.ic.gov"
        },
        @{
            cloud = "ussec"
            expected = "https://global.handler.control.monitor.azure.microsoft.scloud"
        },
        @{
            cloud = "bleu"
            expected = "https://global.handler.control.monitor.sovcloud-api.fr"
        }
    )

    foreach ($testCase in $testCases) {
        Setup
        $env:AKS_REGION = "westus2" # Non-canary region
        $result = Get-McsGlobalEndpoint -cloud_environment $testCase.cloud
        Assert-Equals $testCase.expected $result "(for cloud environment $($testCase.cloud))"
        Teardown
    }
}

function Test-CanaryPrecedenceOverCloud {
    Setup
    $env:AKS_REGION = "eastus2euap"
    $result = Get-McsGlobalEndpoint -cloud_environment "azurechinacloud"
    Assert-Equals "https://global.handler.canary.control.monitor.azure.com" $result "(canary region should take precedence over cloud environment)"
    Teardown
}

function Test-DefaultEndpoint {
    Setup
    Remove-Item Env:\AKS_REGION -ErrorAction SilentlyContinue
    $result = Get-McsGlobalEndpoint -cloud_environment $null
    Assert-Equals "https://global.handler.control.monitor.azure.com" $result "(should default to public cloud endpoint)"
    Teardown
}

function Test-CaseSensitiveRegions {
    $testCases = @(
        "EASTUS2EUAP",
        "EastUs2Euap",
        "CENTRALUSEUAP",
        "CentralUsEuap"
    )

    foreach ($region in $testCases) {
        Setup
        $env:AKS_REGION = $region
        $result = Get-McsGlobalEndpoint -cloud_environment "azurepubliccloud"
        Assert-Equals "https://global.handler.canary.control.monitor.azure.com" $result "(case-insensitive check for $region)"
        Teardown
    }
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Get-McsGlobalEndpoint..."
    Write-Host "========================================="

    Test-CanaryRegions
    Test-CloudEnvironments
    Test-CanaryPrecedenceOverCloud
    Test-DefaultEndpoint
    Test-CaseSensitiveRegions

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
