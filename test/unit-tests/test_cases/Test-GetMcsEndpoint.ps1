# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function dependencies
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-ClusterCloudEnvironment.ps1")
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-McsEndpoint.ps1")

function Test-ValidEnvironmentVariables {
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
        $env:CLUSTER_CLOUD_ENVIRONMENT = $testCase.cloud
        $result = Get-McsEndpoint
        Assert-Equals $testCase.expected $result "(with CLUSTER_CLOUD_ENVIRONMENT=$($testCase.cloud))"
        Teardown
    }
}

function Test-DomainBasedEnvironment {
    $testCases = @(
        @{
            domain = "opinsights.azure.com"
            expected = "https://monitor.azure.com/"
        },
        @{
            domain = "opinsights.azure.cn"
            expected = "https://monitor.azure.cn/"
        },
        @{
            domain = "opinsights.azure.us"
            expected = "https://monitor.azure.us/"
        },
        @{
            domain = "opinsights.azure.eaglex.ic.gov"
            expected = "https://monitor.azure.eaglex.ic.gov/"
        },
        @{
            domain = "opinsights.azure.microsoft.scloud"
            expected = "https://monitor.azure.microsoft.scloud/"
        },
        @{
            domain = "opinsights.sovcloud-api.fr"
            expected = "https://monitor.sovcloud-api.fr/"
        }
    )

    foreach ($testCase in $testCases) {
        Setup
        Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
        Mock-File "etc/ama-logs-secret/DOMAIN" $testCase.domain
        $result = Get-McsEndpoint
        Assert-Equals $testCase.expected $result "(with domain $($testCase.domain))"
        Teardown
    }
}

function Test-DefaultEndpoint {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    $result = Get-McsEndpoint
    Assert-Equals "https://monitor.azure.com/" $result "(with no environment or domain set)"
    Teardown
}

function Test-InvalidDomain {
    Setup
    Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT -ErrorAction SilentlyContinue
    Mock-File "etc/ama-logs-secret/DOMAIN" "invalid.domain.com"
    $result = Get-McsEndpoint
    Assert-Equals "https://monitor.azure.com/" $result "(with invalid domain)"
    Teardown
}

function Test-EnvPrecedenceOverDomain {
    Setup
    $env:CLUSTER_CLOUD_ENVIRONMENT = "azurechinacloud"
    Mock-File "etc/ama-logs-secret/DOMAIN" "opinsights.azure.us"
    $result = Get-McsEndpoint
    Assert-Equals "https://monitor.azure.cn/" $result "(environment should take precedence over domain)"
    Teardown
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Get-McsEndpoint..."
    Write-Host "======================================"

    Test-ValidEnvironmentVariables
    Test-DomainBasedEnvironment
    Test-DefaultEndpoint
    Test-InvalidDomain
    Test-EnvPrecedenceOverDomain

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
