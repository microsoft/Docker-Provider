# Import test framework
. (Join-Path $PSScriptRoot ".." "test_framework.ps1")

# Import function to test
. (Join-Path $PSScriptRoot ".." "test_functions" "Is-SupportedCloudEnvironment.ps1")

function Test-ValidCloudEnvironments {
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
        $result = Is-SupportedCloudEnvironment -cloudEnvironment $cloud
        Assert-Equals "True" $result.ToString() "($cloud should be supported)"
        Teardown
    }
}

function Test-InvalidCloudEnvironments {
    $testCases = @(
        "invalidcloud",
        "",
        " ",
        "azure",
        "chinacloud",
        "azurepublic",
        "unknown"
    )

    foreach ($cloud in $testCases) {
        Setup
        $result = Is-SupportedCloudEnvironment -cloudEnvironment $cloud
        Assert-Equals "False" $result.ToString() "($cloud should not be supported)"
        Teardown
    }
}

function Test-CaseSensitivity {
    $testCases = @(
        "AZUREPUBLICCLOUD",
        "AzurePublicCloud",
        "azurePUBLICcloud",
        "USNAT",
        "UsNat",
        "usNAT"
    )

    foreach ($cloud in $testCases) {
        Setup
        $result = Is-SupportedCloudEnvironment -cloudEnvironment $cloud
        Assert-Equals "True" $result.ToString() "(case-sensitive check for $cloud)"
        Teardown
    }
}

function Test-NullInput {
    Setup
    $result = Is-SupportedCloudEnvironment -cloudEnvironment $null
    Assert-Equals "False" $result.ToString() "(null input should not be supported)"
    Teardown
}

# Run all tests
function Run-AllTests {
    Write-Host "Running tests for Is-SupportedCloudEnvironment..."
    Write-Host "=============================================="

    Test-ValidCloudEnvironments
    Test-InvalidCloudEnvironments
    Test-CaseSensitivity
    Test-NullInput

    Print-TestSummary
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Run-AllTests
}
