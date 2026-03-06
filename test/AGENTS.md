# Test Framework Guide

## Test Decision Tree

When adding tests, use this decision tree:

1. **Go plugin logic with no external dependencies?** → Go unit test (`testify` in `source/plugins/go/src/*_test.go`)
2. **Go code needing mocks?** → Go unit test with `gomock` (`source/plugins/go/src/`)
3. **Ruby Fluentd plugin behavior?** → Ruby test with Fluentd test driver (`source/plugins/ruby/*_test.rb`)
4. **Bash script logic?** → Bash unit test (`test/unit-tests/test_cases/test_*.sh` using `test_framework.sh`)
5. **PowerShell script logic?** → Pester test (`test/unit-tests/*.Tests.ps1`)
6. **End-to-end Kubernetes behavior?** → Ginkgo test (`test/ginkgo-e2e/`) or pytest (`test/e2e/`)
7. **Container log query validation?** → Ginkgo querylogs (`test/ginkgo-e2e/querylogs/`)
8. **Liveness/readiness behavior?** → Ginkgo livenessprobe (`test/ginkgo-e2e/livenessprobe/`)

## Test Patterns in This Repo

### Unit Tests — Go
- Framework: `go test` with `testify` assertions
- Mocking: `gomock` (`github.com/golang/mock`)
- Location: `source/plugins/go/src/*_test.go`, `source/plugins/go/input/lib/*_test.go`
- Run: `./test/unit-tests/run_go_tests.sh`
- CI: `Golang-Tests` job in `run_unit_tests.yml`

### Unit Tests — Ruby
- Framework: Fluentd test driver
- Location: `source/plugins/ruby/*_test.rb`
- Run: `./test/unit-tests/run_ruby_tests.sh`
- Prerequisites: `gem install fluentd -v "1.14.2"`, `gem install ipaddress`
- CI: `Ruby-Tests` job in `run_unit_tests.yml`

### Unit Tests — Bash
- Framework: Custom shell test framework (`test/unit-tests/test_framework.sh`)
- Location: `test/unit-tests/test_cases/test_*.sh`
- Helper functions: `test/unit-tests/test_functions/`
- Canned API responses: `test/unit-tests/canned-api-responses/`
- Run: `./test/unit-tests/test_main.sh`
- CI: `Linux-Bash-Tests` job in `run_unit_tests.yml`

### Unit Tests — PowerShell
- Framework: Pester 5.3.3
- Location: `test/unit-tests/*.Tests.ps1`
- Run: `./test/unit-tests/test_main.ps1`
- CI: `Windows-PowerShell-Tests` job in `run_unit_tests.yml`

### E2E Tests — Ginkgo
- Framework: Ginkgo (Go BDD test framework)
- Location: `test/ginkgo-e2e/`
- Suites: `querylogs/`, `containerstatus/`, `livenessprobe/`
- Shared utilities: `test/ginkgo-e2e/utils/`

### E2E Tests — Python
- Framework: pytest
- Location: `test/e2e/src/tests/`
- Suites: `test_e2e_workflows.py`, `test_rs_workflows.py`, `test_ds_workflows.py`

## Common Test Utilities
- `test/ginkgo-e2e/utils/kubernetes_api_utils.go` — Kubernetes API helpers for E2E
- `test/unit-tests/test_framework.sh` — Bash test assertion framework
- `test/unit-tests/test_functions/` — Shared bash test helper functions
- `test/unit-tests/canned-api-responses/` — Mock Kubernetes API responses for bash tests

## Test Data
- Canned Kubernetes API responses: `test/unit-tests/canned-api-responses/`
- E2E test manifests: `test/scenario/yamls/`
- Testkube configurations: `test/testkube/`
