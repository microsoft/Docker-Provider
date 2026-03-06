# Test Authoring

## Purpose
Creates and maintains unit tests, integration tests, and end-to-end (e2e) tests for the Container Insights agent. Covers Go tests for Fluent Bit plugins, Ruby tests for Fluentd plugins, Shell script tests for Linux agent components, PowerShell tests for Windows agent components, and Ginkgo-based e2e tests.

USE FOR: "add test", "write unit test", "increase coverage", "test for bug", "regression test", "e2e test", "Ginkgo test", "Ruby test", "Go test", "shell test", "PowerShell test"
DO NOT USE FOR: Fixing the test infrastructure itself (use ci-cd-pipeline), running tests as part of a bug fix (tests are a step in bug-fix skill, not standalone)

## When to Use
- New code is added without corresponding tests
- A bug fix needs a regression test
- Test coverage needs improvement for a specific plugin or module
- A new e2e test scenario is needed for Ginkgo test suites
- Existing tests need to be updated due to code changes
- Adding test cases for edge conditions (nil responses, API timeouts, malformed data)

## Inputs
- Source file(s) or feature to be tested
- Test type: unit (Go, Ruby, Shell, PowerShell) or e2e (Ginkgo)
- Expected behavior and edge cases to cover
- Any mock data or fixtures needed

## Outputs
- New or updated test files in the appropriate test directory
- All existing and new tests passing
- Test runner scripts updated if new test files need to be included

## Steps
1. Determine the test type and framework based on the source code being tested:
   - **Go unit tests**: Place alongside source code or run via `test/unit-tests/run_go_tests.sh`
     - Tests for `source/plugins/go/src/` (output plugins)
     - Tests for `source/plugins/go/input/` (input plugins)
   - **Ruby unit tests**: Place in `test/unit-tests/` and run via `test/unit-tests/run_ruby_tests.sh`
     - Uses `test_driver.rb` as the test harness for Fluentd plugins
   - **Shell tests**: Add to `test/unit-tests/test_main.sh`
     - Tests for bash scripts in `scripts/`, `build/`, `kubernetes/linux/`
   - **PowerShell tests**: Add to `test/unit-tests/test_main.ps1`
     - Tests for PowerShell scripts in `kubernetes/windows/`
   - **Ginkgo e2e tests**: Add to the appropriate suite under `test/ginkgo-e2e/`
     - `test/ginkgo-e2e/livenessprobe/` — liveness probe verification
     - `test/ginkgo-e2e/containerstatus/` — container status checks
     - `test/ginkgo-e2e/querylogs/` — log query validation
     - `test/ginkgo-e2e/utils/` — shared e2e test utilities
2. Write the test following existing patterns in the codebase:
   - Go: standard `testing` package with table-driven tests
   - Ruby: follow patterns in `test_driver.rb` and existing test files
   - Shell: follow assertion patterns in `test_main.sh`
   - PowerShell: follow Pester-style patterns in `test_main.ps1`
   - Ginkgo: use `Describe`/`Context`/`It` blocks with Gomega matchers
3. Add test data fixtures if needed:
   - Mock Kubernetes API responses for Ruby plugin tests
   - Sample log lines for Go input plugin tests
   - Sample ConfigMap values for configuration parsing tests
4. Run the specific test suite to verify:
   - `bash test/unit-tests/run_go_tests.sh`
   - `bash test/unit-tests/run_ruby_tests.sh`
   - `bash test/unit-tests/test_main.sh`
   - `pwsh test/unit-tests/test_main.ps1`
5. Run all test suites to check for regressions
6. Verify tests are picked up by CI: `run_unit_tests.yml` must execute the new tests

## Validation
- New tests fail when the feature/fix under test is reverted (tests are meaningful)
- All test suites pass: `run_go_tests.sh`, `run_ruby_tests.sh`, `test_main.sh`, `test_main.ps1`
- CI workflow `run_unit_tests.yml` picks up and runs the new tests
- No flaky behavior: tests pass consistently across multiple runs
- Test names clearly describe what is being tested
- Edge cases are covered: nil/empty inputs, API errors, timeout scenarios

## Risks and Guardrails
- **Test isolation**: Each test must be independent; avoid shared mutable state between test cases
- **Mock fidelity**: Kubernetes API mocks must reflect real API response structures; outdated mocks cause false positives
- **Flaky tests**: Avoid time-dependent assertions or network calls in unit tests; use mocks for external dependencies
- **Test runner registration**: New test files must be discoverable by the respective runner script; verify inclusion
- **Ginkgo module independence**: Each `test/ginkgo-e2e/*/` directory is its own Go module; manage `go.mod` independently
- **Windows test compatibility**: PowerShell tests in `test_main.ps1` must work on the Windows runner specified in CI
- **Large test data**: Avoid committing large fixture files; generate test data programmatically when possible

## Examples from This Repo
- Go tests use table-driven test patterns with descriptive subtests
- Ruby tests in `test/unit-tests/` use `test_driver.rb` to simulate Fluentd plugin lifecycle
- Shell tests in `test_main.sh` validate configuration parsing and environment variable handling
- Ginkgo e2e tests query Log Analytics workspaces to verify end-to-end data flow
- Test runner scripts (`run_go_tests.sh`, `run_ruby_tests.sh`) aggregate results and return proper exit codes for CI
