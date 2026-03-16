# Test Authoring

## Description
Guide for adding tests to the Docker-Provider codebase.

USE FOR: add test, write test, test coverage, test for feature, add unit test, add integration test, TDD
DO NOT USE FOR: fixing flaky tests, refactoring tests, test infrastructure changes

## Instructions

### When to Apply
When adding test coverage for new or existing code across any language in the repo.

### Step-by-Step Procedure
1. Identify which language/component needs tests.
2. Choose the correct test framework and location:
   - **Go unit tests:** `source/plugins/go/src/*_test.go` or `source/plugins/go/input/**/*_test.go` — use `testify` assertions.
   - **Ruby unit tests:** `source/plugins/ruby/*_test.rb` — run with `./test/unit-tests/run_ruby_tests.sh`.
   - **Shell unit tests:** `test/unit-tests/test_cases/*.sh` — follow `test_framework.sh` patterns.
   - **Go E2E tests:** `test/ginkgo-e2e/<suite>/` — use Ginkgo/Gomega framework.
   - **PowerShell tests:** use Pester v5.3.3 framework.
3. Write failing tests first (TDD approach), then implement code to pass them.
4. Follow existing naming conventions in the test directory.
5. Run all tests to verify nothing is broken.

### Files Typically Involved
- `source/plugins/go/src/*_test.go` — Go unit tests
- `source/plugins/ruby/*_test.rb` — Ruby unit tests
- `test/unit-tests/test_cases/*.sh` — Shell test cases
- `test/ginkgo-e2e/` — E2E test suites
- `test/unit-tests/test_main.sh` — Test runner

### Validation
- `./test/unit-tests/test_main.sh` passes
- `./test/unit-tests/run_go_tests.sh` passes
- `./test/unit-tests/run_ruby_tests.sh` passes
- Go: `go test -cover -race ./...`

## Examples from This Repo
- `9f16b604b` — Test automation: added tests for LA data flow (#1366)
- `ba381243c` — Test Automation Framework improvements (#1449)
- `f32e2eec4` — Testkube workflow migration (#1589)
- `660ab8547` — Longw/fix conformance test (#1350)
