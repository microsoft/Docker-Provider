# Unit Tests for Azure Monitor Container Insights

This directory contains unit tests for various components of the Azure Monitor Container Insights agent.

## Test Structure

```
test/unit-tests/
├── test_framework.sh           # Common test utilities and helper functions (Bash)
├── test_framework.ps1         # Common test utilities and helper functions (PowerShell)
├── test_main.sh               # Main test runner for Bash tests
├── test_main.ps1             # Main test runner for PowerShell tests
├── test_functions/            # Isolated functions for testing
│   ├── getClusterCloudEnvironment.sh      # Linux/Bash version
│   ├── Get-ClusterCloudEnvironment.ps1    # Windows/PowerShell version
│   ├── Get-McsEndpoint.ps1
│   ├── Get-McsGlobalEndpoint.ps1
│   ├── Is-SupportedCloudEnvironment.ps1
│   └── Get-LogAnalyticsWorkspaceDomain.ps1
└── test_cases/               # Individual test case files
    ├── test_getClusterCloudEnvironment.sh
    ├── Test-GetClusterCloudEnvironment.ps1
    ├── Test-GetMcsEndpoint.ps1
    ├── Test-GetMcsGlobalEndpoint.ps1
    ├── Test-IsSupportedCloudEnvironment.ps1
    └── Test-GetLogAnalyticsWorkspaceDomain.ps1
```

## Running the Tests

### Linux/Bash Tests
To run all Bash unit tests:
```bash
chmod +x test/unit-tests/test_main.sh
./test/unit-tests/test_main.sh
```

To run a specific Bash test file:
```bash
chmod +x test/unit-tests/test_cases/test_getClusterCloudEnvironment.sh
./test/unit-tests/test_cases/test_getClusterCloudEnvironment.sh
```

### Windows/PowerShell Tests
To run all PowerShell unit tests:
```powershell
./test/unit-tests/test_main.ps1
```

To run a specific PowerShell test file:
```powershell
./test/unit-tests/test_cases/Test-GetClusterCloudEnvironment.ps1
```

## Available Tests

### Cloud Environment Detection (Linux & Windows)
Tests the cloud environment detection logic which determines the Azure cloud environment from either:
- Environment variable (CLUSTER_CLOUD_ENVIRONMENT)
- Domain file (/etc/ama-logs-secret/DOMAIN)

#### Functionality Tested
- Valid environment variable values
- Invalid environment variable values
- Domain file fallback with valid values
- Invalid domain values
- Empty domain file
- Missing domain file
- Environment variable precedence over domain file

### MCS Endpoint Tests
Tests the MCS endpoint determination based on cloud environment:
- Public cloud endpoints
- China cloud endpoints
- US Government cloud endpoints
- Other sovereign cloud endpoints
- Defaults and fallbacks

### MCS Global Endpoint Tests
Tests global endpoint determination including:
- Canary region detection
- Cloud environment-specific endpoints
- Default endpoints
- Environment variable handling

### Log Analytics Workspace Domain Tests
Tests workspace domain determination:
- Valid domain mappings
- Invalid domains
- Default domain handling
- Empty/missing configurations

## Adding New Tests

### For Linux/Bash Tests
1. Create a new function file in `test_functions/` containing only the function to be tested
2. Create a new test file in `test_cases/` (prefix with `test_`)
3. Import the test framework and function file in your test file
4. Add your test cases following the existing patterns
5. Make the files executable:
```bash
chmod +x test/unit-tests/test_functions/your_function.sh
chmod +x test/unit-tests/test_cases/test_your_function.sh
```

### For Windows/PowerShell Tests
1. Create a new function file in `test_functions/` (use PascalCase naming)
2. Create a new test file in `test_cases/` (prefix with `Test-`)
3. Import the test framework and function file in your test file
4. Add your test cases following the existing patterns

## Test Framework Features

Common features for both Bash and PowerShell frameworks:
- Setup/teardown for each test
- Mock file creation support
- Assertion helpers
- Test result reporting
- Temporary test directory management

## Test Output

Tests will produce output in the following format:
```
Running tests for [TestName]...
==============================================
✓ Test passed: Expected 'value', got 'value' (test description)
✗ Test failed: Expected 'value', but got 'value' (test description)

Test Summary:
============
Total tests: X
Tests passed: Y
Tests failed: Z
```

## Debugging Failed Tests

When tests fail, you can:
1. Run individual test files for more focused debugging
2. Check the test temporary directory during test execution
3. Add debug echo statements in the test functions
4. Review the assertions in the failing test cases

## Contributing

When adding new test cases:
1. Follow the existing patterns in test_cases/
2. Isolate function dependencies in test_functions/
3. Add proper test descriptions in assertions
4. Update this README.md with details of new test cases
5. Follow the appropriate naming conventions for your platform
   - Linux/Bash: lowercase with underscores
   - Windows/PowerShell: PascalCase
