# Test Authoring

## Description
Create tests for new or existing code following the repo's test framework conventions.

USE FOR: add test, write test, test coverage, add unit test, add integration test, add E2E test
DO NOT USE FOR: fixing flaky tests, refactoring test infrastructure, test environment setup

## Instructions

### When to Apply
When adding tests for new features, bug fixes, or increasing coverage of existing code.

### Step-by-Step Procedure

1. **Determine the right test type**:
   - **Go unit test**: Logic in `source/plugins/go/src/` → add `*_test.go` in same directory
   - **Bash unit test**: Shell script logic → add `test/unit-tests/test_cases/test_*.sh`
   - **Ruby unit test**: Ruby plugin logic → add to `test/unit-tests/test_driver.rb`
   - **PowerShell test**: Windows scripts → Pester tests via `test/unit-tests/test_main.ps1`
   - **Ginkgo E2E**: Cluster-level behavior → add to `test/ginkgo-e2e/<suite>/`

2. **Go unit tests**:
   ```go
   func TestMyFunction(t *testing.T) {
       os.Setenv("GOUNITTEST", "true")
       os.Setenv("ISTEST", "true")
       defer os.Unsetenv("GOUNITTEST")
       defer os.Unsetenv("ISTEST")
       // test logic
   }
   ```
   Run: `cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .`

3. **Bash unit tests**:
   - Add test file: `test/unit-tests/test_cases/test_<feature>.sh`
   - Use functions from `test/unit-tests/test_functions/`
   - Use the test framework in `test/unit-tests/test_framework.sh`
   Run: `./test/unit-tests/test_main.sh`

4. **Ruby unit tests**:
   - Add test methods to `test/unit-tests/test_driver.rb`
   - Use canned API responses from `test/unit-tests/canned-api-responses/` for mock data
   Run: `ruby test/unit-tests/test_driver.rb`

5. **Ginkgo E2E tests**:
   - Add specs in `test/ginkgo-e2e/<suite>/`
   - Use utility functions from `test/ginkgo-e2e/utils/`
   Run: `cd test/ginkgo-e2e/<suite> && go test -v ./...`

### Files Typically Involved
- `source/plugins/go/src/*_test.go` — Go tests
- `test/unit-tests/test_cases/test_*.sh` — Bash tests
- `test/unit-tests/test_functions/*.sh` — Bash test helpers
- `test/unit-tests/test_driver.rb` — Ruby tests
- `test/unit-tests/canned-api-responses/` — Mock data
- `test/ginkgo-e2e/` — E2E tests (Ginkgo)

### Validation
- New test passes when run individually
- All existing tests still pass
- CI test suite would pass (`.github/workflows/run_unit_tests.yml`)

## Examples from This Repo
- `test/unit-tests/test_cases/` — Bash test examples
- `source/plugins/go/src/oms_test.go` — Go test examples
- `source/plugins/go/src/network_flow_logs_test.go` — Go test examples
