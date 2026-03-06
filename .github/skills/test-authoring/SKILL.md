# Test Authoring

## Description
Guides adding new tests to the container agent, covering unit tests (Go, Ruby, Bash, PowerShell) and E2E tests (Ginkgo, pytest).

USE FOR: add test, write test, test coverage, add unit test, add integration test, add e2e test
DO NOT USE FOR: fixing flaky tests, refactoring test infrastructure, test tooling changes

## Instructions

### When to Apply
When adding tests for new or existing functionality across any of the supported test frameworks.

### Step-by-Step Procedure
1. Choose the right test framework:
   - Go code → `go test` in `source/plugins/go/src/*_test.go`
   - Ruby code → Ruby test file alongside source or via `test/unit-tests/test_driver.rb`
   - Bash scripts → Shell test in `test/unit-tests/test_cases/*.sh` using the custom framework
   - PowerShell → Pester test in `test/unit-tests/Test-*.ps1`
   - Cluster-level E2E → Ginkgo in `test/ginkgo-e2e/<suite>/`
   - Workflow E2E → pytest in `test/e2e/src/tests/`
2. Follow the naming convention for the chosen framework.
3. Place the test file in the correct location:
   - Go: same directory as source (`*_test.go`)
   - Ruby: `source/plugins/ruby/*_test.rb` or `test/unit-tests/test_driver.rb`
   - Bash: `test/unit-tests/test_cases/`
   - PowerShell: `test/unit-tests/Test-*.ps1` with matching function in `test/unit-tests/test_functions/`
4. Write tests following existing patterns in the same directory.
5. Run the test suite to verify: see `AGENTS.md` Testing Instructions for exact commands.

### Files Typically Involved
- `source/plugins/go/src/*_test.go` — Go unit tests
- `source/plugins/ruby/*_test.rb` — Ruby unit tests
- `test/unit-tests/test_cases/*.sh` — Bash test cases
- `test/unit-tests/Test-*.ps1` — PowerShell test cases
- `test/ginkgo-e2e/*/` — Ginkgo E2E tests
- `test/e2e/src/tests/test_*.py` — Python E2E tests

### Validation
- New test passes when run in isolation
- All existing tests still pass
- CI test workflow runs successfully

## Examples from This Repo
- `Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)` — Ginkgo test improvements
- `Fix testkube mongodb issue (#1584)` — test infrastructure fix
- `Testkube workflow migration (#1589)` — test framework migration

## References
- `test/unit-tests/README.md` — unit test documentation
- `.github/workflows/run_unit_tests.yml` — CI test configuration
