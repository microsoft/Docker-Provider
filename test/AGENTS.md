# Test Framework Guide

## Test Decision Tree
When adding tests, use this decision tree:

1. **Pure Go plugin logic with no external dependencies?** → Go unit test (`go test` with `_test.go`)
2. **Ruby plugin logic with mock Kubernetes API?** → Ruby unit test (minitest via `test_driver.rb`)
3. **Bash script behavior (installer, setup, entrypoint)?** → Bash unit test (`test_framework.sh`)
4. **PowerShell script behavior (Windows agent)?** → Pester test (`*.Tests.ps1`)
5. **Agent behavior on a real cluster?** → Ginkgo E2E test (`test/ginkgo-e2e/`)
6. **Full deployment validation?** → TestKube or conformance test (`test/testkube/`, `test/e2e/`)

## Test Patterns in This Repo

### Go Unit Tests
- Framework: `go test` (stdlib)
- Mocking: `go generate` with `github.com/golang/mock`
- Location: `source/plugins/go/src/*_test.go`
- Environment: Set `GOUNITTEST=true ISTEST=true` to guard test code paths
- Command: `cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .`

### Ruby Unit Tests
- Framework: minitest (via fluentd test infrastructure)
- Location: `source/plugins/ruby/*_test.rb`, invoked via `test/unit-tests/test_driver.rb`
- Pattern: Dependency injection in constructors enables mock objects in tests
- Command: `./test/unit-tests/run_ruby_tests.sh`

### Bash Unit Tests
- Framework: Custom (`test/unit-tests/test_framework.sh`)
- Location: `test/unit-tests/test_cases/test_*.sh`
- Functions: `test/unit-tests/test_functions/*.sh`
- Command: `./test/unit-tests/test_main.sh`

### PowerShell Unit Tests
- Framework: Pester 5.3.3
- Location: `test/unit-tests/test_cases/*.Tests.ps1`
- Command: `./test/unit-tests/test_main.ps1`

### Ginkgo E2E Tests
- Framework: Ginkgo v2 + Gomega
- Suites: `test/ginkgo-e2e/querylogs/`, `containerstatus/`, `livenessprobe/`
- Shared utilities: `test/ginkgo-e2e/utils/`
- Requires: Running Kubernetes cluster with agent deployed

### Conformance / TestKube Tests
- Config: `test/e2e/conformance.yaml`, `test/testkube/`
- Purpose: Validate end-to-end agent deployment and data collection

## Common Test Utilities
- `test/unit-tests/test_framework.sh` — Bash test runner with assertions
- `test/unit-tests/test_driver.rb` — Ruby test runner
- `test/unit-tests/canned-api-responses/` — Mock Kubernetes API responses
- `test/ginkgo-e2e/utils/` — Shared Go E2E utilities (Azure SDK, K8s API helpers)
