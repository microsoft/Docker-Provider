# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function dependencies
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-ClusterCloudEnvironment.ps1")
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-McsGlobalEndpoint.ps1")

function Test-CanaryRegions {
    $testCases = @(
        "eastus2euap",
        "centraluseuap"
    )

    foreach ($region in $testCases) {
        Setup
        $env:AKS_REGION = $region
        $result = Get-McsGlobalEndpoint
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
            expected = "https://global.handler.control.sovcloud-api.fr"
        }
    )

    foreach ($testCase in $testCases) {
        Setup
        $env:CLUSTER_CLOUD_ENVIRONMENT = $testCase.cloud
        $env:AKS_REGION = "westus2" # Non-canary region
        $result = Get-McsGlobalEndpoint
        Assert-Equals $testCase.expected $result "(for cloud environment $($testCase.cloud))"
        Teardown
    }
}

function Test-DomainBasedEnvironment {
    $testCases = @(
        @{
            domain = "opinsights.azure.com"
            expected = "https://global.handler.control.monitor.azure.com"
        },
        @{
            domain = "opinsights.azure.cn"
            expected = "https://global.handler.control.monitor.azure.cn"
        },
        @{
            domain = "opinsights.azure.us"
            expected = "https://global.handler.control.monitor.azure.us"
        },
        @{
            domain = "opinsights.azure.eaglex.ic.gov"
            expected = "https://global.handler.control.monitor.azure.eaglex.ic.gov"
        },
        @{
            domain = "opinsights.azure.microsoft.scloud"
            expected = "https://global.handler.control.monitor.azure.microsoft.scloud"
        },
        @{
            domain = "opinsights.sovcloud-api.fr"
            expected = "https://global.handler.control.sovcloud-api.fr"
        }
    )

    foreach ($testCase in $testCases) {
        Setup
        Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
        Mock-File "etc/ama-logs-secret/DOMAIN" $testCase.domain
        $env:AKS_REGION = "westus2" # Non-canary region
        $result = Get-McsGlobalEndpoint
        Assert-Equals $testCase.expected $result "(with domain $($testCase.domain))"
        Teardown
    }
}

function Test-CanaryPrecedenceOverCloud {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "azurechinacloud"
    $env:AKS_REGION = "eastus2euap"
    $result = Get-McsGlobalEndpoint
    Assert-Equals "https://global.handler.canary.control.monitor.azure.com" $result "(canary region should take precedence over cloud environment)"
    Teardown
}

function Test-DefaultEndpoint {
    Setup
    # No environment variables set
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    Remove-Item Env:\AKS_REGION -ErrorAction SilentlyContinue
    $result = Get-McsGlobalEndpoint
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
        $result = Get-McsGlobalEndpoint
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
    Test-DomainBasedEnvironment
    Test-CanaryPrecedenceOverCloud
    Test-DefaultEndpoint
    Test-CaseSensitiveRegions

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
