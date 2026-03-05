# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Go plugin logic (parsing, formatting, network flow)?** → Go unit test with `testify/assert` in `source/plugins/go/src/*_test.go`
2. **Ruby plugin logic (inventory, telemetry, API client)?** → Ruby unit test in `source/plugins/ruby/*_test.rb`
3. **Shell function behavior (cloud env detection, endpoints)?** → Bash test case in `test/unit-tests/test_cases/*.sh`
4. **PowerShell function behavior (cloud env, endpoints)?** → Pester test in `test/unit-tests/test_cases/Test-*.ps1`
5. **End-to-end cluster validation (log queries, container status)?** → Ginkgo E2E in `test/ginkgo-e2e/<suite>/`
6. **Full deployment workflow testing?** → E2E framework in `test/e2e/` (Python + pytest)

## Test Patterns in This Repo

### Go Unit Tests
- Framework: `testing` + `github.com/stretchr/testify/assert`
- Location: alongside source in `source/plugins/go/src/` (e.g., `oms_test.go`, `utils_test.go`, `network_flow_logs_test.go`)
- Naming: `func Test<FunctionName>(t *testing.T)`
- Env guard: `GOUNITTEST=true ISTEST=true`
- Runner: `./test/unit-tests/run_go_tests.sh`
- Mocking: `github.com/golang/mock`

### Ruby Unit Tests
- Framework: minitest (via Fluentd test infrastructure)
- Location: alongside source in `source/plugins/ruby/` (e.g., `in_kube_nodes_test.rb`)
- Also in: `build/linux/installer/scripts/*_test.rb`
- Naming: `*_test.rb` files
- Test guard: `$in_unit_test = true` (set by `test/unit-tests/test_driver.rb`)
- Runner: `./test/unit-tests/run_ruby_tests.sh`
- Pattern: constructor injection for test doubles

### Bash Unit Tests
- Framework: custom (`test/unit-tests/test_framework.sh`)
- Functions under test: `test/unit-tests/test_functions/*.sh`
- Test cases: `test/unit-tests/test_cases/*.sh`
- Naming: `test_<functionName>.sh`
- Runner: `./test/unit-tests/test_main.sh`

### PowerShell Unit Tests
- Framework: Pester 5.3.3
- Functions under test: `test/unit-tests/test_functions/*.ps1`
- Test cases: `test/unit-tests/test_cases/Test-*.ps1`
- Naming: `Test-<FunctionName>.ps1`
- Runner: `./test/unit-tests/test_main.ps1`

### Ginkgo E2E Tests
- Framework: Ginkgo + Gomega
- Suites: `test/ginkgo-e2e/querylogs/`, `test/ginkgo-e2e/containerstatus/`, `test/ginkgo-e2e/livenessprobe/`
- Shared utilities: `test/ginkgo-e2e/utils/`
- Run: `cd test/ginkgo-e2e/<suite> && go test -v ./...`

### Python E2E Tests
- Framework: pytest
- Location: `test/e2e/src/tests/`
- Common utilities: `test/e2e/src/common/`
- Configuration: `test/e2e/src/core/conftest.py`

## Common Test Utilities
- `test/ginkgo-e2e/utils/constants.go` — shared constants for E2E tests
- `test/ginkgo-e2e/utils/kubernetes_api_utils.go` — Kubernetes API helpers
- `test/ginkgo-e2e/utils/query_logs_api_utils.go` — Log Analytics query helpers
- `test/e2e/src/common/` — Python utilities for Kubernetes operations, ARM REST, Helm

## Test Data
- Canned API responses: `test/unit-tests/canned-api-responses/` (e.g., `kube-nodes.txt`)
- Scenario YAMLs: `test/scenario/yamls/` (pod definitions for testing)
- E2E conformance config: `test/e2e/conformance.yaml`, `test/e2e/e2e-tests.yaml`
