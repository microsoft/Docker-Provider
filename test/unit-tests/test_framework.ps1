# Test framework utilities for PowerShell unit testing

# Initialize test counters
$script:TESTS_RUN = 0
$script:TESTS_PASSED = 0
$script:TESTS_FAILED = 0

# Colors for output
$script:GREEN = "`e[32m"
$script:RED = "`e[31m"
$script:NC = "`e[0m" # No Color

# Test environment setup
function global:Setup-TestEnv {
    # Create temporary directory for test artifacts
    $script:TEST_DIR = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path $script:TEST_DIR -Force | Out-Null
    return $script:TEST_DIR
}

# Test environment cleanup
function global:Cleanup-TestEnv {
    # Remove temporary test directory
    if (Test-Path $script:TEST_DIR) {
        Remove-Item -Path $script:TEST_DIR -Recurse -Force
    }
}

# Mock file creation helper
function global:Mock-File {
    param(
        [string]$FilePath,
        [string]$Content
    )
    $fullPath = Join-Path $script:TEST_DIR $FilePath
    New-Item -Path (Split-Path $fullPath) -ItemType Directory -Force | Out-Null
    Set-Content -Path $fullPath -Value $Content
}

# Assertion helpers
function global:Assert-Equals {
    param(
        [string]$Expected,
        [string]$Actual,
        [string]$Message = ""
    )

    $script:TESTS_RUN++

    if ($Expected -eq $Actual) {
        Write-Host "$script:GREEN✓ Test passed$script:NC`: Expected '$Expected', got '$Actual' $Message"
        $script:TESTS_PASSED++
        return $true
    }
    else {
        Write-Host "$script:RED✗ Test failed$script:NC`: Expected '$Expected', but got '$Actual' $Message"
        $script:TESTS_FAILED++
        return $false
    }
}

# Print test summary
function global:Print-TestSummary {
    Write-Host "`nTest Summary:"
    Write-Host "============"
    Write-Host "Total tests: $script:TESTS_RUN"
    Write-Host "$script:GREEN`Tests passed: $script:TESTS_PASSED$script:NC"
    Write-Host "$script:RED`Tests failed: $script:TESTS_FAILED$script:NC"

    if ($script:TESTS_FAILED -eq 0) {
        Write-Host "`n$script:GREEN`All tests passed!$script:NC"
        return $true
    }
    else {
        Write-Host "`n$script:RED`Some tests failed.$script:NC"
        return $false
    }
}

# Run before each test
function global:Setup {
    # Create a fresh test environment
    Setup-TestEnv

    # Create mock directories that tests might need
    New-Item -Path "$script:TEST_DIR/etc/ama-logs-secret" -ItemType Directory -Force | Out-Null
}

# Run after each test
function global:Teardown {
    # Clean up test artifacts
    Cleanup-TestEnv

    # Clear any environment variables set during tests
    if (Test-Path Env:\CLUSTER_CLOUD_ENVIRONMENT) {
        Remove-Item Env:\CLUSTER_CLOUD_ENVIRONMENT
    }
}
