# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Testing shell script functions?** → Bash unit test in `test/unit-tests/test_cases/` using the custom framework (`test_framework.sh`)
2. **Testing Go plugin logic?** → Go test file (`*_test.go`) in the same package directory, run with `go test`
3. **Testing Ruby Fluentd plugin?** → Ruby test file (`*_test.rb`) in `source/plugins/ruby/`, run via `test/unit-tests/test_driver.rb`
4. **Testing PowerShell functions?** → Pester test (`Test-*.ps1`) in `test/unit-tests/test_cases/`, run with `test_main.ps1`
5. **Testing end-to-end log collection?** → Ginkgo test in `test/ginkgo-e2e/`, uses Azure SDK for Log Analytics queries
6. **Testing container deployment?** → Ginkgo test in `test/ginkgo-e2e/containerstatus/` for pod scheduling validation

## Test Patterns in This Repo

### Bash Unit Tests
- Framework: Custom bash test framework (`test/unit-tests/test_framework.sh`)
- Location: Test functions in `test/unit-tests/test_functions/`, test cases in `test/unit-tests/test_cases/`
- Naming: Functions named `test_*` or descriptive names like `getClusterCloudEnvironment.sh`
- Entry point: `test/unit-tests/test_main.sh`
- CI: Runs in `run_unit_tests.yml` GitHub Actions workflow

### Go Unit Tests
- Framework: Standard `go test` with `-cover -race` flags
- Location: Test files alongside source in `source/plugins/go/`
- Naming: `*_test.go` (standard Go convention)
- Entry point: `test/unit-tests/run_go_tests.sh`
- CI: Runs with Go 1.23.8 in `run_unit_tests.yml`

### Ruby Unit Tests
- Framework: Minitest (via `test_driver.rb`)
- Location: `source/plugins/ruby/*_test.rb` alongside source files
- Naming: `*_test.rb` matching the source file name
- Entry point: `ruby test/unit-tests/test_driver.rb`
- Prerequisites: `gem install fluentd -v "1.14.2"` and `gem install ipaddress`
- Important: Set `$in_unit_test = true` to gate telemetry during tests
- CI: Runs in `run_unit_tests.yml` after installing Fluentd gem

### PowerShell Unit Tests
- Framework: Pester 5.3.3
- Location: Test functions in `test/unit-tests/test_functions/`, test cases in `test/unit-tests/test_cases/`
- Naming: `Test-*.ps1` for test cases, function names matching test functions
- Entry point: `test/unit-tests/test_main.ps1`
- CI: Runs on `windows-latest` in `run_unit_tests.yml`

### Ginkgo E2E Tests
- Framework: Ginkgo v2 + Gomega
- Location: `test/ginkgo-e2e/` with suites: `querylogs/`, `containerstatus/`, `livenessprobe/`
- Dependencies: Azure SDK (`azquery`), Kubernetes client (`client-go`)
- Pattern: `DescribeTable` with `Entry` for data-driven tests
- Requires: Running AKS cluster with agent deployed, `AKS_RESOURCE_ID` env var

## Common Test Utilities

| Utility | Location | Purpose |
|---------|----------|---------|
| `utils` package | `test/ginkgo-e2e/utils/` | Kubernetes client setup, Log Analytics queries, pod validation |
| `test_framework.sh` | `test/unit-tests/test_framework.sh` | Bash test assertion functions |
| `test_framework.ps1` | `test/unit-tests/test_framework.ps1` | PowerShell test helpers |
| Canned API responses | `test/unit-tests/canned-api-responses/` | Mock Kubernetes API responses for unit tests |

## Test Data

- Canned Kubernetes API responses: `test/unit-tests/canned-api-responses/`
- Scenario test manifests: `test/scenario/yamls/` (pod definitions for testing)
- Multiline log test data: `test/scenario/multiline/` (language-specific log patterns)
- TestKube workflows: `test/testkube/` (Kubernetes-native test execution)
