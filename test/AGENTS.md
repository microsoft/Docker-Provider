# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Go plugin logic (no external dependencies)?** → Go unit test with `testify` in `source/plugins/go/src/*_test.go`
2. **Go input plugin logic?** → Go unit test in `source/plugins/go/input/**/*_test.go`
3. **Ruby Fluentd plugin logic?** → Ruby test in `source/plugins/ruby/*_test.rb`
4. **Shell script behavior?** → Shell test in `test/unit-tests/test_cases/*.sh`
5. **PowerShell script behavior?** → Pester test (v5.3.3)
6. **End-to-end cluster behavior?** → Ginkgo E2E in `test/ginkgo-e2e/<suite>/`
7. **Data pipeline validation?** → Python E2E in `test/e2e/`
8. **Kubernetes scenario testing?** → TestKube workflows in `test/testkube/`

## Test Patterns in This Repo

### Unit Tests

**Go:**
- Framework: `testify` (assert, require)
- Mocking: `golang/mock`
- Location: `source/plugins/go/src/*_test.go`, `source/plugins/go/input/**/*_test.go`
- Naming: `TestFunctionName` in `*_test.go` files
- Runner: `./test/unit-tests/run_go_tests.sh`
- Flags: `-cover -race -coverprofile=coverage.txt`

**Ruby:**
- Location: `source/plugins/ruby/*_test.rb`
- Dependencies: `fluentd` gem v1.14.2
- Runner: `./test/unit-tests/run_ruby_tests.sh`

**Shell:**
- Framework: Custom (`test/unit-tests/test_framework.sh`)
- Test cases: `test/unit-tests/test_cases/*.sh`
- Runner: `./test/unit-tests/test_main.sh`

**PowerShell:**
- Framework: Pester v5.3.3
- Runner: CI runs on `windows-latest`

### E2E Tests

**Ginkgo (Go):**
- Framework: `onsi/ginkgo/v2`, `onsi/gomega`
- Suites: `test/ginkgo-e2e/querylogs/`, `test/ginkgo-e2e/containerstatus/`, `test/ginkgo-e2e/livenessprobe/`
- Each suite has its own `go.mod`
- Naming: `*_test.go` with `Describe`/`It` blocks

**Python:**
- Framework: `pytest`
- Location: `test/e2e/`
- Uses Kubernetes Python client

**TestKube:**
- Location: `test/testkube/`
- Workflow-based test execution

## Common Test Utilities
- `test/ginkgo-e2e/utils/` — Shared Go test utilities (separate `go.mod`)
- `test/unit-tests/test_framework.sh` — Shell test assertion framework
- `test/unit-tests/test_functions/` — Shared Shell test helpers

## Test Data
- Test configuration files in `test/unit-tests/` directories
- Kubernetes scenario manifests in `test/scenario/`
- Conformance test images referenced in CI
