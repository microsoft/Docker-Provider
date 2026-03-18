# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Testing a Bash function (Linux)?** → Add to `test/unit-tests/test_functions/` + `test/unit-tests/test_cases/test_*.sh`
2. **Testing a PowerShell function (Windows)?** → Add to `test/unit-tests/test_functions/` + `test/unit-tests/test_cases/Test-*.ps1`
3. **Testing Go Fluent Bit plugin logic?** → Add `*_test.go` alongside source in `source/plugins/go/src/`
4. **Testing Ruby Fluentd plugin logic?** → Add `*_test.rb` alongside source in `source/plugins/ruby/`
5. **Testing E2E cluster-level behavior?** → Add Ginkgo test in `test/ginkgo-e2e/` or pytest in `test/e2e/`

## Test Patterns in This Repo

### Go Unit Tests
- **Framework:** `go test` with `github.com/stretchr/testify/assert`
- **Location:** `source/plugins/go/src/*_test.go`
- **Runner:** `./test/unit-tests/run_go_tests.sh`
- **Environment:** `GOUNITTEST=true ISTEST=true`
- **Naming:** `TestFunctionName(t *testing.T)`
- **Mocking:** `github.com/golang/mock`

### Ruby Unit Tests
- **Framework:** Minitest with Fluentd Test Driver
- **Location:** `source/plugins/ruby/*_test.rb`
- **Runner:** `./test/unit-tests/run_ruby_tests.sh`
- **Prerequisites:** `fluentd` gem v1.14.2, `ipaddress` gem
- **Pattern:** Constructor dependency injection with mock objects
- **Driver:** `Fluent::Test::Driver::Input` for testing input plugins

### Bash Unit Tests
- **Framework:** Custom `test_framework.sh`
- **Location:** Functions in `test/unit-tests/test_functions/*.sh`, cases in `test/unit-tests/test_cases/test_*.sh`
- **Runner:** `./test/unit-tests/test_main.sh`
- **Pattern:** Source the function, call with test inputs, assert output

### PowerShell Unit Tests
- **Framework:** Pester 5.3.3
- **Location:** Functions in `test/unit-tests/test_functions/*.ps1`, cases in `test/unit-tests/test_cases/Test-*.ps1`
- **Runner:** `./test/unit-tests/test_main.ps1`
- **Pattern:** `Describe`/`It` blocks with `Should -Be` assertions

### Ginkgo E2E Tests
- **Framework:** Ginkgo (Go)
- **Location:** `test/ginkgo-e2e/*/`
- **Tests:** Query logs, container status, liveness probe
- **Shared utils:** `test/ginkgo-e2e/utils/`

### Python E2E Tests
- **Framework:** pytest
- **Location:** `test/e2e/src/`
- **Tests:** DS workflows, RS workflows, E2E workflows
- **Shared utils:** `test/e2e/src/common/`

## Common Test Utilities
- `test/unit-tests/canned-api-responses/` — Pre-recorded Kubernetes API responses for Ruby tests
- `test/ginkgo-e2e/utils/` — Shared Go utilities for E2E tests (K8s API, query logs, setup)
- `test/e2e/src/common/` — Shared Python utilities for E2E tests (Helm, K8s, ARM)

## Test Data
- Canned Kubernetes API responses: `test/unit-tests/canned-api-responses/`
- Scenario YAML manifests: `test/scenario/` (test pods, multiline log generators)
- Prometheus reference apps: `test/prometheus-scraping/`
- Scale test generators: `test/containerlog-scale-tests/`
