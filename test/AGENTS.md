# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Go plugin logic with no external dependencies?** → Go unit test (`go test`)
2. **Shell script logic or config parsing?** → Bash unit test (custom framework in `test/unit-tests/`)
3. **Ruby plugin logic?** → Ruby unit test (`test/unit-tests/test_driver.rb`)
4. **PowerShell/Windows script logic?** → Pester test (`test/unit-tests/test_main.ps1`)
5. **Cluster-level behavior (log queries, container status)?** → Ginkgo E2E test (`test/ginkgo-e2e/`)
6. **Full deployment validation?** → Python E2E test (`test/e2e/`)

## Test Patterns in This Repo

### Bash Unit Tests
- **Framework**: Custom bash test framework (`test/unit-tests/test_framework.sh`)
- **Location**: `test/unit-tests/test_cases/test_*.sh`
- **Helpers**: `test/unit-tests/test_functions/*.sh`
- **Runner**: `./test/unit-tests/test_main.sh`
- **CI**: Runs in `run_unit_tests.yml` → `Linux-Bash-Tests` job

### Go Unit Tests
- **Framework**: Go standard `testing` package with `testify` assertions
- **Location**: `source/plugins/go/src/*_test.go` (same directory as source)
- **Mocking**: `github.com/golang/mock`
- **Environment**: Must set `GOUNITTEST=true ISTEST=true`
- **Prerequisites**: Run `go generate` before `go test`
- **Runner**: `cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .`
- **CI**: Runs in `run_unit_tests.yml` → `Golang-Tests` job (Go 1.23.8)

### Ruby Unit Tests
- **Framework**: Custom test driver (`test/unit-tests/test_driver.rb`)
- **Location**: `test/unit-tests/test_driver.rb`
- **Mock data**: `test/unit-tests/canned-api-responses/`
- **Prerequisites**: `gem install fluentd -v "1.14.2"`, `gem install ipaddress`
- **Runner**: `ruby test/unit-tests/test_driver.rb`
- **CI**: Runs in `run_unit_tests.yml` → `Ruby-Tests` job

### PowerShell Unit Tests
- **Framework**: Pester 5.3.3
- **Location**: `test/unit-tests/test_main.ps1`
- **Runner**: `./test/unit-tests/test_main.ps1` (Windows only)
- **CI**: Runs in `run_unit_tests.yml` → `Windows-PowerShell-Tests` job

### Ginkgo E2E Tests
- **Framework**: Ginkgo + Gomega
- **Location**: `test/ginkgo-e2e/` with suites: `querylogs/`, `containerstatus/`, `livenessprobe/`
- **Utilities**: `test/ginkgo-e2e/utils/` (Kubernetes API helpers)
- **Prerequisites**: Running Kubernetes cluster with agent deployed
- **Runner**: `cd test/ginkgo-e2e/<suite> && go test -v ./...`

### Python E2E Tests
- **Framework**: pytest
- **Location**: `test/e2e/src/`
- **Utilities**: `test/e2e/src/common/` (Kubernetes, Helm, ARM helpers)
- **Prerequisites**: Running Kubernetes cluster, Azure credentials

## Common Test Utilities

| Utility | Path | Purpose |
|---------|------|---------|
| Bash test framework | `test/unit-tests/test_framework.sh` | Assert functions for bash tests |
| Bash test functions | `test/unit-tests/test_functions/*.sh` | Reusable test helper functions |
| Canned API responses | `test/unit-tests/canned-api-responses/` | Mock Kubernetes API responses |
| Ginkgo K8s utils | `test/ginkgo-e2e/utils/kubernetes_api_utils.go` | Kubernetes API test helpers |
| Python K8s utils | `test/e2e/src/common/*.py` | Python Kubernetes test utilities |
