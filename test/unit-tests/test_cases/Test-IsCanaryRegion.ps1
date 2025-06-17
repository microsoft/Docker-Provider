# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function to test
. (Join-Path $PSScriptRoot ".." "test_functions" "Is-CanaryRegion.ps1")

function Test-ValidCanaryRegions {
    $testCases = @(
        "eastus2euap",
        "centraluseuap"
    )

    foreach ($region in $testCases) {
        Setup
        $result = Is-CanaryRegion -aksRegion $region
        Assert-Equals "True" $result.ToString() "($region should be a canary region)"
        Teardown
    }
}

function Test-NonCanaryRegions {
    $testCases = @(
        "westus2",
        "eastus",
        "centralus",
        "northeurope",
        "westeurope",
        ""
    )

    foreach ($region in $testCases) {
        Setup
        $result = Is-CanaryRegion -aksRegion $region
        Assert-Equals "False" $result.ToString() "($region should not be a canary region)"
        Teardown
    }
}

function Test-CaseSensitivity {
    $testCases = @(
        "EASTUS2EUAP",
        "EastUs2Euap",
        "CENTRALUSEUAP",
        "CentralUsEuap"
    )

    foreach ($region in $testCases) {
        Setup
        $result = Is-CanaryRegion -aksRegion $region
        Assert-Equals "True" $result.ToString() "(case-insensitive check for $region)"
        Teardown
    }
}

function Test-NullInput {
    Setup
    $result = Is-CanaryRegion -aksRegion $null
    Assert-Equals "False" $result.ToString() "(null input should not be a canary region)"
    Teardown
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Is-CanaryRegion..."
    Write-Host "=================================="

    Test-ValidCanaryRegions
    Test-NonCanaryRegions
    Test-CaseSensitivity
    Test-NullInput

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
