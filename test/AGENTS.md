# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Pure Go logic with no external dependencies?** → Go unit test (`testing` + `testify/assert`) in `source/plugins/go/src/*_test.go`
2. **Bash script logic or environment detection?** → Shell test in `test/unit-tests/test_cases/*.sh` using `test_framework.sh`
3. **Ruby Fluentd plugin behavior?** → Ruby test via `test/unit-tests/run_ruby_tests.sh` (requires Fluentd 1.14.2)
4. **PowerShell Windows script logic?** → Pester test in `test/unit-tests/test_main.ps1` (Pester 5.3.3)
5. **End-to-end Kubernetes log/metric verification?** → Go Ginkgo in `test/ginkgo-e2e/` or Python pytest in `test/e2e/`
6. **Container log scale/performance?** → Scale test configs in `test/containerlog-scale-tests/`
7. **Scenario-based multiline log parsing?** → Config files in `test/scenario/multiline/`

## Test Patterns in This Repo

### Unit Tests

- **Bash:** `test/unit-tests/test_main.sh` → `test/unit-tests/test_framework.sh` → `test/unit-tests/test_cases/*.sh`
- **Go:** `source/plugins/go/src/*_test.go` using `testing` + `testify/assert`
- **Ruby:** Invoked via `test/unit-tests/run_ruby_tests.sh` (needs `fluentd` gem 1.14.2)
- **PowerShell:** `test/unit-tests/test_main.ps1` using Pester 5.3.3 + PSScriptAnalyzer

### E2E Tests

- **Go Ginkgo:** `test/ginkgo-e2e/querylogs/`, `test/ginkgo-e2e/livenessprobe/`, `test/ginkgo-e2e/containerstatus/`
  - Each suite has its own `go.mod`
  - Uses `test/ginkgo-e2e/utils/` for shared Kubernetes utilities
- **Python pytest:** `test/e2e/src/core/e2e_tests.py` with session-scoped fixtures in `conftest.py`
  - Utilities in `test/e2e/src/common/` (Kubernetes, Helm, ARM helpers)

### Scenario Tests

- `test/scenario/multiline/` — Multiline log parsing test configs
- `test/scenario/yamls/` — Kubernetes deployment templates for test scenarios

## Common Test Utilities

- `test/unit-tests/test_framework.sh` — Bash test framework (assertions, test runner)
- `test/ginkgo-e2e/utils/` — Kubernetes client helpers, setup utilities for Go E2E
- `test/e2e/src/common/kubernetes_pod_utility.py` — Pod CRUD operations
- `test/e2e/src/common/constants.py` — Cloud endpoint constants
