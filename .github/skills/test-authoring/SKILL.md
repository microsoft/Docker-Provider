# Test Authoring

## Description

Create tests for Docker-Provider across the multi-framework test infrastructure.

USE FOR: add test, write test, test coverage, add unit test, add integration test, add E2E test
DO NOT USE FOR: fixing flaky tests, refactoring test infrastructure, test pipeline changes

## Instructions

### When to Apply

When adding new functionality, fixing bugs (regression tests), or improving coverage.

### Step-by-Step Procedure

1. **Choose the right test framework:**
   - Pure Go logic → Go `*_test.go` with `testing` + `testify/assert`
   - Bash script logic → Shell test in `test/unit-tests/test_cases/`
   - Ruby plugin logic → Ruby test via `test/unit-tests/run_ruby_tests.sh`
   - PowerShell logic → Pester test in `test/unit-tests/test_main.ps1`
   - End-to-end Kubernetes → Go Ginkgo in `test/ginkgo-e2e/` or Python pytest in `test/e2e/`

2. **Follow naming conventions:**
   - Go: `<name>_test.go` alongside source file
   - Bash: `test_<name>.sh` in `test/unit-tests/test_cases/`
   - Ginkgo: `<name>_suite_test.go` + `<name>_test.go`

3. **Write the test:** Follow TDD — write failing test first, then implement.

4. **Run tests:**
   - Go: `./test/unit-tests/run_go_tests.sh`
   - Bash: `./test/unit-tests/test_main.sh`
   - Ruby: `./test/unit-tests/run_ruby_tests.sh`
   - PowerShell: `./test/unit-tests/test_main.ps1`

### Files Typically Involved

- `source/plugins/go/src/*_test.go`
- `test/unit-tests/test_cases/*.sh`
- `test/ginkgo-e2e/*`
- `test/e2e/src/core/`

### Validation

- New test passes, existing tests still pass, CI green.

## Examples from This Repo

- `f32e2eec4` — Testkube workflow migration (#1589)
- `ba381243c` — Test Automation Framework improvements (#1449)
- `660ab8547` — fix conformance test (#1350)
