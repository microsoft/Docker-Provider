# Test Authoring

## Description
Add tests for new or existing code following the repo's multi-language test patterns.

USE FOR: add test, write test, test coverage, add unit test, add e2e test, add integration test
DO NOT USE FOR: fixing flaky tests, test infrastructure changes, CI pipeline changes

## Instructions

### When to Apply
When new code needs test coverage or existing code lacks sufficient tests.

### Step-by-Step Procedure
1. **Determine test type and framework:**
   - Go unit tests: `go test` with `_test.go` files
   - Ruby unit tests: minitest via `test_driver.rb`
   - Bash unit tests: Custom framework in `test/unit-tests/test_framework.sh`
   - PowerShell unit tests: Pester 5.3.3 with `*.Tests.ps1` files
   - E2E tests: Ginkgo (Go) in `test/ginkgo-e2e/`

2. **Place test files correctly:**
   - Go: `source/plugins/go/src/*_test.go` (alongside source)
   - Ruby: `source/plugins/ruby/*_test.rb` or `test/unit-tests/test_driver.rb`
   - Bash: `test/unit-tests/test_cases/test_*.sh`
   - PowerShell: `test/unit-tests/test_cases/*.Tests.ps1`
   - Ginkgo E2E: `test/ginkgo-e2e/<suite-name>/`

3. **Follow existing test patterns:**
   - Go: Use `GOUNITTEST=true ISTEST=true` environment guards; use `go generate` for mocks
   - Ruby: Dependency injection via constructor for testability
   - Bash: Source `test_framework.sh`, use `assert_*` functions
   - PowerShell: `Describe`/`It`/`Should` Pester blocks

4. **Run tests:**
   ```bash
   # Go
   cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .
   # Ruby
   ./test/unit-tests/run_ruby_tests.sh
   # Bash
   ./test/unit-tests/test_main.sh
   # PowerShell (Windows)
   ./test/unit-tests/test_main.ps1
   ```

### Files Typically Involved
- `source/plugins/go/src/*_test.go`
- `source/plugins/ruby/*_test.rb`
- `test/unit-tests/test_cases/test_*.sh`
- `test/unit-tests/test_cases/*.Tests.ps1`
- `test/ginkgo-e2e/*/`

### Validation
- New tests pass in isolation
- All existing tests continue to pass
- Tests cover the target behavior (happy path + error cases)

## Examples from This Repo
- `Test Automation Framework improvements (#1449)`
- `Update conformnace test (#1452)`
- `Testkube workflow migration (#1589)`
