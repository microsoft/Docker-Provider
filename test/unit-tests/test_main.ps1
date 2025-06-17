# Main test runner for all PowerShell unit tests

# Colors for output
$script:BLUE = "`e[34m"
$script:RED = "`e[31m"
$script:GREEN = "`e[32m"
$script:NC = "`e[0m" # No Color

Write-Host "$script:BLUE`Running all PowerShell unit tests...$script:NC"
Write-Host "========================="

# Get all test files
$TEST_CASES_DIR = Join-Path $PSScriptRoot "test_cases"
$allTestsFailed = $false
$testCount = 0
$passedCount = 0
$failedCount = 0

# List of test files in the order we want to run them
$testFiles = @(
    "Test-GetClusterCloudEnvironment.ps1",
    "Test-IsSupportedCloudEnvironment.ps1",
    "Test-GetLogAnalyticsWorkspaceDomain.ps1",
    "Test-GetMcsEndpoint.ps1",
    "Test-GetMcsGlobalEndpoint.ps1",
    "Test-IsCanaryRegion.ps1"
)

foreach ($testFile in $testFiles) {
    $testPath = Join-Path $TEST_CASES_DIR $testFile
    if (Test-Path $testPath) {
        Write-Host "`n$script:BLUE`Running tests from: $testFile$script:NC"
        Write-Host "----------------------------------------"

        try {
            $testCount++
            # Run the test file
            $result = & $testPath

            # Only check $LASTEXITCODE since $? might be false even when tests pass
            if ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq 0) {
                Write-Host "$script:GREEN`Tests passed in: $testFile$script:NC"
                $passedCount++
            }
            else {
                Write-Host "$script:RED`Tests failed in: $testFile$script:NC"
                $failedCount++
                $allTestsFailed = $true
            }
        }
        catch {
            Write-Host "$script:RED`Error running tests in: $testFile$script:NC"
            Write-Host $_.Exception.Message
            $failedCount++
            $allTestsFailed = $true
        }
    }
    else {
        Write-Host "$script:RED`Test file not found: $testFile$script:NC"
    }
}

Write-Host "`n$script:BLUE`All test suites completed.$script:NC"
Write-Host "========================="
Write-Host "Test Suites Summary:"
Write-Host "Total test suites: $testCount"
Write-Host "$script:GREEN`Passed test suites: $passedCount$script:NC"
Write-Host "$script:RED`Failed test suites: $failedCount$script:NC"

if ($allTestsFailed) {
    Write-Host "`n$script:RED`Some test suites failed.$script:NC"
    exit 1
}
else {
    Write-Host "`n$script:GREEN`All test suites passed!$script:NC"
    exit 0
}
