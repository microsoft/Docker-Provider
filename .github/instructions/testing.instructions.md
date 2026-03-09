---
applyTo: "test/**/*"
---
# Testing Instructions

## Test Framework Overview
| Framework | Language | Location | Command |
|-----------|----------|----------|---------|
| Bash test framework | Shell | `test/unit-tests/test_cases/*.sh` | `./test/unit-tests/test_main.sh` |
| Go testing + testify | Go | `source/plugins/go/src/*_test.go` | `cd source/plugins/go/src && go test ./...` |
| Ruby test (Fluentd) | Ruby | `source/plugins/ruby/*_test.rb` | `./test/unit-tests/run_ruby_tests.sh` |
| Pester 5.3 | PowerShell | `test/unit-tests/test_cases/*.ps1` | `./test/unit-tests/test_main.ps1` |
| pytest | Python | `test/e2e/src/tests/` | `cd test/e2e/src && python -m pytest tests/` |
| Ginkgo | Go | `test/ginkgo-e2e/` | `cd test/ginkgo-e2e/<suite> && go test ./...` |

## Test Naming Conventions
- **Bash:** `test/unit-tests/test_cases/test_*.sh` with functions from `test/unit-tests/test_functions/`
- **Go:** `*_test.go` in same package, function names `Test<Description>(t *testing.T)`
- **Ruby:** `*_test.rb` alongside source files
- **PowerShell:** `test/unit-tests/test_cases/Test-<FunctionName>.ps1` using `Describe`/`Context`/`It`
- **Python E2E:** `test/e2e/src/tests/test_*_workflows.py`

## Writing New Tests
1. Place test files alongside the source they test (Go, Ruby) or in `test/unit-tests/test_cases/` (Bash, PowerShell)
2. For PowerShell: add test function to `test/unit-tests/test_functions/`, test cases to `test/unit-tests/test_cases/`
3. For Go: use `testify/assert` for assertions, `golang/mock` for mocking external dependencies
4. For Bash: follow existing pattern in `test_framework.sh` with assert functions
5. Ensure CI will pick up new tests — check `test_main.sh` / `run_go_tests.sh` / `run_ruby_tests.sh` include paths

## Ginkgo E2E Tests
- `test/ginkgo-e2e/livenessprobe/` — Agent liveness probe validation
- `test/ginkgo-e2e/querylogs/` — Log query validation
- `test/ginkgo-e2e/containerstatus/` — Container status checks
- Each suite has its own `go.mod` — update dependencies independently
