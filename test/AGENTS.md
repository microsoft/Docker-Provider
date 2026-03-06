# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Pure Go logic with no external dependencies?** → Go unit test (`go test`) in `source/plugins/go/src/*_test.go`
2. **Ruby plugin behavior?** → Ruby test in `source/plugins/ruby/*_test.rb` via `test/unit-tests/test_driver.rb`
3. **Bash script logic?** → Shell test in `test/unit-tests/test_cases/*.sh` using the custom test framework
4. **PowerShell function behavior?** → Pester test in `test/unit-tests/Test-*.ps1`
5. **End-to-end cluster behavior (logs, status)?** → Ginkgo test in `test/ginkgo-e2e/<suite>/`
6. **End-to-end workflow validation?** → pytest test in `test/e2e/src/tests/test_*.py`

## Test Patterns in This Repo

### Go Unit Tests
- Framework: `go test` with `github.com/stretchr/testify` assertions and `github.com/golang/mock` mocking
- Location: `source/plugins/go/src/*_test.go` (same package)
- Naming: `func Test<FunctionName>(t *testing.T)`
- Run: `cd source/plugins/go/src && go test -cover -race`
- CI command: `./test/unit-tests/run_go_tests.sh`

### Ruby Unit Tests
- Framework: custom test driver (`test/unit-tests/test_driver.rb`) with Fluentd test helpers
- Location: `source/plugins/ruby/*_test.rb`
- Naming: `<plugin_name>_test.rb` alongside source
- Run: `./test/unit-tests/run_ruby_tests.sh`
- Requires: `fluentd` gem (v1.14.2), `ipaddress` gem

### Bash Unit Tests
- Framework: custom shell test framework (`test/unit-tests/test_framework.sh`)
- Location: `test/unit-tests/test_cases/*.sh`
- Helper functions: `test/unit-tests/test_functions/*.sh`
- Run: `./test/unit-tests/test_main.sh`

### PowerShell Unit Tests
- Framework: Pester 5.3.3
- Location: `test/unit-tests/Test-*.ps1`
- Helper functions: `test/unit-tests/test_functions/*.ps1`
- Run: `./test/unit-tests/test_main.ps1`

### Ginkgo E2E Tests
- Framework: Ginkgo/Gomega (Go BDD)
- Location: `test/ginkgo-e2e/` with suites: `querylogs`, `containerstatus`, `livenessprobe`
- Shared utilities: `test/ginkgo-e2e/utils/`
- Run: `cd test/ginkgo-e2e/<suite> && go test -v ./...`
- Requires: running Kubernetes cluster with agent deployed

### Python E2E Tests
- Framework: pytest
- Location: `test/e2e/src/tests/test_*.py`
- Naming: `test_<workflow>_workflows.py`
- Requires: running cluster, AAD token, Log Analytics workspace access

## Common Test Utilities
- `test/unit-tests/canned-api-responses/` — mock Kubernetes API responses for unit tests
- `test/ginkgo-e2e/utils/kubernetes_api_utils.go` — Kubernetes client helpers for E2E
- `test/ginkgo-e2e/utils/query_logs_api_utils.go` — Log Analytics query helpers
- `test/ginkgo-e2e/utils/setup_utils.go` — E2E test setup/teardown
- `test/ginkgo-e2e/utils/constants.go` — shared test constants
