# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Pure Go logic with no external dependencies?** → Go unit test (`go test` + `testify`)
2. **Pure Ruby plugin logic with no external dependencies?** → Ruby unit test (`test/unit-tests/test_driver.rb` + `Minitest`)
3. **Shell script function logic?** → Bash unit test (`test/unit-tests/test_cases/` + custom framework)
4. **Tests log table queries against a live cluster?** → Ginkgo E2E test (`test/ginkgo-e2e/querylogs/`)
5. **Tests container/pod status on a live cluster?** → Ginkgo E2E test (`test/ginkgo-e2e/containerstatus/`)
6. **Tests agent liveness on a live cluster?** → Ginkgo E2E test (`test/ginkgo-e2e/livenessprobe/`)
7. **Tests end-to-end workflow scenarios?** → pytest E2E test (`test/e2e/src/tests/`)

## Test Patterns in This Repo

### Go Unit Tests
- **Framework**: `testing` + `github.com/stretchr/testify` for assertions, `github.com/golang/mock` for mocking
- **Location**: Alongside source in `source/plugins/go/src/*_test.go`
- **Run**: `cd source/plugins/go/src && go test -cover -race ./...`
- **Naming**: `Test<FunctionName>` functions in `*_test.go` files

### Ruby Unit Tests
- **Framework**: `Minitest::Test`
- **Location**: `source/plugins/ruby/*_test.rb`
- **Run**: `ruby test/unit-tests/test_driver.rb` (aggregates all `*_test.rb` files)
- **Key pattern**: Tests set `$in_unit_test = true` globally to gate telemetry calls
- **Naming**: `test_<description>` methods in `*_test.rb` files

### Bash Unit Tests
- **Framework**: Custom framework in `test/unit-tests/test_framework.sh`
- **Location**: `test/unit-tests/test_cases/test_<name>.sh`
- **Run**: `./test/unit-tests/test_main.sh`
- **Assertions**: `assert_equals`, `assert_contains`, `assert_not_contains`
- **Helper functions**: `test/unit-tests/test_functions/`
- **Naming**: `test_<functionName>.sh` files

### Ginkgo E2E Tests
- **Framework**: Ginkgo v2 + Gomega
- **Location**: `test/ginkgo-e2e/<suite>/` (querylogs, containerstatus, livenessprobe)
- **Prerequisites**: Running AKS cluster with agent deployed, Azure credentials
- **Run**: `cd test/ginkgo-e2e/<suite> && go test -v ./...`
- **Shared utilities**: `test/ginkgo-e2e/utils/` (Kubernetes client setup, Log Analytics query helpers)
- **Naming**: `Describe`/`DescribeTable` with `Entry` for table-driven tests

### pytest E2E Tests
- **Framework**: pytest
- **Location**: `test/e2e/src/tests/`
- **Config**: `test/e2e/src/core/pytest.ini`, `test/e2e/src/core/conftest.py`
- **Run**: `cd test/e2e/src && pytest`
- **Naming**: `test_<workflow>.py` files with `test_<name>` functions

## Common Test Utilities
- `test/ginkgo-e2e/utils/` — Shared Go utilities for E2E tests (K8s client, Log Analytics queries)
- `test/unit-tests/test_framework.sh` — Bash test assertion functions
- `test/unit-tests/test_functions/` — Shared Bash helper functions for test setup

## Test Data
- `test/scenario/yamls/` — Kubernetes YAML manifests for test pods
- `test/scenario/multiline/` — Multiline log test scenarios (Java, Python, .NET, Go)
- `test/containerlog-scale-tests/` — Scale testing configurations
