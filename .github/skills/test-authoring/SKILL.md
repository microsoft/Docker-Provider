# Test Authoring

## Description
Add unit tests, integration tests, or E2E tests for the Docker-Provider agent.

USE FOR: add test, write test, test coverage, add unit test, add integration test, add E2E test, add Ginkgo test
DO NOT USE FOR: fixing flaky tests, refactoring test infrastructure, test framework changes

## Instructions

### When to Apply
When adding tests for new features, bug fixes (regression tests), or improving coverage for existing code.

### Step-by-Step Procedure
1. **Choose the test type:**
   - **Go unit test**: For Go plugin logic → `source/plugins/go/src/*_test.go`
   - **Ruby unit test**: For Ruby plugin logic → `source/plugins/ruby/*_test.rb`
   - **Bash unit test**: For shell script logic → `test/unit-tests/test_cases/test_<name>.sh`
   - **Ginkgo E2E**: For end-to-end validation against a live cluster → `test/ginkgo-e2e/<suite>/`
   - **pytest E2E**: For workflow validation → `test/e2e/src/tests/test_<name>.py`

2. **Follow naming conventions:**
   - Go: `*_test.go` in same package, functions named `Test<Name>(t *testing.T)` or Ginkgo `Describe`/`It`
   - Ruby: `*_test.rb` alongside the plugin file, using `Minitest::Test`
   - Bash: `test_<functionName>.sh` in `test/unit-tests/test_cases/`, using `assert_equals`/`assert_contains`
   - Ginkgo E2E: `*_test.go` with `_suite_test.go` for setup, using `Describe`/`DescribeTable`/`Entry`

3. **Write the test:**
   - Test both success and error paths
   - For Ruby: Set `$in_unit_test = true` in test setup (handled by `test_driver.rb`)
   - For Go: Use `github.com/stretchr/testify` for assertions in unit tests, `gomega` for Ginkgo
   - For Ginkgo E2E: Use `utils` package from `test/ginkgo-e2e/utils/` for cluster setup

4. **Run the test:**
   - Go: `cd source/plugins/go/src && go test -race -v ./...`
   - Ruby: `ruby test/unit-tests/test_driver.rb`
   - Bash: `./test/unit-tests/test_main.sh`
   - Ginkgo: `cd test/ginkgo-e2e/<suite> && go test -v ./...`

### Files Typically Involved
- `source/plugins/go/src/*_test.go` — Go unit tests
- `source/plugins/ruby/*_test.rb` — Ruby unit tests
- `test/unit-tests/test_cases/*.sh` — Bash unit tests
- `test/unit-tests/test_functions/*.sh` — Bash test helper functions
- `test/ginkgo-e2e/*/` — Ginkgo E2E test suites
- `test/e2e/src/tests/` — pytest E2E tests

### Validation
- New test passes when run in isolation
- All existing tests continue to pass
- Go tests pass with `-race` flag
- CI workflow `.github/workflows/run_unit_tests.yml` passes

## Examples from This Repo
- `f32e2eec4` — Testkube workflow migration
- `137873158` — Remove custom metrics tests from conformance tests
- `3268cb2f1` — Update conformance test
