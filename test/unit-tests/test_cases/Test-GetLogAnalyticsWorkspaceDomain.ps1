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
        Mock-File "/etc/ama-logs-secret/DOMAIN" $testCase.domain
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals $testCase.expected $result "(for domain $($testCase.domain))"
        Teardown
    }
}

function Test-DomainsWithWhitespace {
    $testCases = @(
        "  opinsights.azure.cn  ",
        "`topinsights.azure.us`n",
        " opinsights.azure.microsoft.scloud "
    )

    $expectedDomains = @(
        "opinsights.azure.cn",
        "opinsights.azure.us",
        "opinsights.azure.microsoft.scloud"
    )

    for ($i = 0; $i -lt $testCases.Length; $i++) {
        Setup
        Mock-File "/etc/ama-logs-secret/DOMAIN" $testCases[$i]
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals $expectedDomains[$i] $result "(for domain with whitespace: $($testCases[$i]))"
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
        Mock-File "/etc/ama-logs-secret/DOMAIN" $domain
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals "opinsights.azure.com" $result "(unknown domain $domain should default to opinsights.azure.com)"
        Teardown
    }
}

function Test-EmptyDomain {
    Setup
    Mock-File "/etc/ama-logs-secret/DOMAIN" ""
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
        @{input="OPINSIGHTS.AZURE.CN"; expected="opinsights.azure.cn"},
        @{input="Opinsights.Azure.Us"; expected="opinsights.azure.us"},
        @{input="opinsights.AZURE.eaglex.ic.gov"; expected="opinsights.azure.eaglex.ic.gov"},
        @{input="OPINSIGHTS.azure.microsoft.SCLOUD"; expected="opinsights.azure.microsoft.scloud"},
        @{input="OpInsights.SovCloud-Api.Fr"; expected="opinsights.sovcloud-api.fr"}
    )

    foreach ($testCase in $testCases) {
        Setup
        Mock-File "/etc/ama-logs-secret/DOMAIN" $testCase.input
        $result = Get-LogAnalyticsWorkspaceDomain
        Assert-Equals $testCase.expected $result "(case-insensitive check for $($testCase.input))"
        Teardown
    }
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Get-LogAnalyticsWorkspaceDomain..."
    Write-Host "================================================"

    Test-ValidDomains
    Test-DomainsWithWhitespace
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
