# Test Authoring

## Description
Guide for adding tests following the repo's multi-language test conventions.

USE FOR: add test, write test, test coverage, add unit test, add integration test, test for feature
DO NOT USE FOR: fixing flaky tests, refactoring test infrastructure, E2E test environment setup

## Instructions

### When to Apply
When adding new functionality or fixing bugs that require regression tests.

### Step-by-Step Procedure
1. Determine the language of the code under test:
   - **Go** → Create `*_test.go` file alongside the source in `source/plugins/go/src/` or `source/plugins/go/input/`.
   - **Ruby** → Create `*_test.rb` file alongside the source in `source/plugins/ruby/`.
   - **Bash** → Create `test/unit-tests/test_cases/test_<name>.sh` following the test framework.
   - **PowerShell** → Create `test/unit-tests/*.Tests.ps1` using Pester 5.x.
2. Follow existing test patterns:
   - Go: Use `testify` assertions (`assert.Equal`, `assert.NoError`), `gomock` for mocking.
   - Ruby: Use Fluentd test driver (`Fluent::Test::Driver::Input/Filter/Output`).
   - Bash: Use the custom test framework (`test/unit-tests/test_framework.sh`).
   - PowerShell: Use Pester `Describe`/`It`/`Should` blocks.
3. Run the appropriate test suite to verify.
4. Ensure tests are deterministic — no dependency on live Kubernetes API or network access.

### Files Typically Involved
- `source/plugins/go/src/*_test.go`
- `source/plugins/ruby/*_test.rb`
- `test/unit-tests/test_cases/test_*.sh`
- `test/unit-tests/*.Tests.ps1`

### Validation
- Run the specific test suite for the language
- CI workflow `run_unit_tests.yml` passes all four suites

## Examples from This Repo
- `source/plugins/go/src/oms_test.go` — Go unit tests for the OMS output plugin
- `source/plugins/ruby/in_kube_nodes_test.rb` — Ruby test for Kubernetes node inventory
- `test/unit-tests/test_cases/test_getClusterCloudEnvironment.sh` — Bash unit test

## References
- `test/unit-tests/test_framework.sh` — Bash test framework documentation
- `.github/workflows/run_unit_tests.yml` — CI test configuration
