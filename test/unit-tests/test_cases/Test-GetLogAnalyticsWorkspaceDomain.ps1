# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function to test
. (Join-Path $PSScriptRoot ".." "test_functions" "Get-LogAnalyticsWorkspaceDomain.ps1")

function Test-ValidDomains {
    $testCases = @(
        @{
            domain = "opinsights.azure.com"
            expected = "opinsights.azure.com"
        },
        @{
            domain = "opinsights.azure.cn"
            expected = "opinsights.azure.cn"
        },
        @{
            domain = "opinsights.azure.us"
            expected = "opinsights.azure.us"
        },
        @{
            domain = "opinsights.azure.eaglex.ic.gov"
            expected = "opinsights.azure.eaglex.ic.gov"
        },
        @{
            domain = "opinsights.azure.microsoft.scloud"
            expected = "opinsights.azure.microsoft.scloud"
        },
        @{
            domain = "opinsights.sovcloud-api.fr"
            expected = "opinsights.sovcloud-api.fr"
        }
    )

    foreach ($testCase in $testCases) {
        Setup
        Mock-File "etc/ama-logs-secret/DOMAIN" $testCase.domain
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals $testCase.expected $result "(for domain $($testCase.domain))"
        Teardown
    }
}

function Test-UnknownDomain {
    $testCases = @(
        "unknown.domain.com",
        "azure.com",
        "opinsights.invalid.com",
        "something.azure.cn",
        "opinsights.azure.invalid"
    )

    foreach ($domain in $testCases) {
        Setup
        Mock-File "etc/ama-logs-secret/DOMAIN" $domain
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals "opinsights.azure.com" $result "(unknown domain $domain should default to opinsights.azure.com)"
        Teardown
    }
}

function Test-EmptyDomain {
    Setup
    Mock-File "etc/ama-logs-secret/DOMAIN" ""
    $result = Get-LogAnalyticsWorkspaceDomain
    Assert-Equals "opinsights.azure.com" $result "(empty domain should default to opinsights.azure.com)"
    Teardown
}

function Test-MissingDomainFile {
    Setup
    # Don't create the domain file
    $result = Get-LogAnalyticsWorkspaceDomain
    Assert-Equals "opinsights.azure.com" $result "(missing domain file should default to opinsights.azure.com)"
    Teardown
}

function Test-CaseSensitivity {
    $testCases = @(
        "OPINSIGHTS.AZURE.COM",
        "Opinsights.Azure.Com",
        "opinsights.AZURE.cn",
        "OPINSIGHTS.azure.us"
    )

    foreach ($domain in $testCases) {
        Setup
        Mock-File "etc/ama-logs-secret/DOMAIN" $domain
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals "opinsights.azure.com" $result "(case-sensitive check for $domain)"
        Teardown
    }
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Get-LogAnalyticsWorkspaceDomain..."
    Write-Host "================================================"

    Test-ValidDomains
    Test-UnknownDomain
    Test-EmptyDomain
    Test-MissingDomainFile
    Test-CaseSensitivity

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
