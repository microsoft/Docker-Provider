# Testing — AGENTS.md

## Overview
The Docker-Provider test suite spans 4 languages and multiple test types.

## Test Suites

### Bash Unit Tests
- **Location:** `test/unit-tests/test_cases/*.sh`
- **Framework:** Custom framework (`test/unit-tests/test_framework.sh`)
- **Functions under test:** `test/unit-tests/test_functions/*.sh`
- **Run:** `./test/unit-tests/test_main.sh`
- **CI:** `run_unit_tests.yml` → `Linux-Bash-Tests` job

### Go Unit Tests
- **Location:** `source/plugins/go/src/*_test.go`
- **Framework:** `testing` + `testify/assert` + `golang/mock`
- **Run:** `./test/unit-tests/run_go_tests.sh` or `cd source/plugins/go/src && go test ./...`
- **CI:** `run_unit_tests.yml` → `Golang-Tests` job (Go 1.23.8)

### Ruby Unit Tests
- **Location:** `source/plugins/ruby/*_test.rb`
- **Framework:** Fluentd test framework
- **Run:** `./test/unit-tests/run_ruby_tests.sh`
- **CI:** `run_unit_tests.yml` → `Ruby-Tests` job (Fluentd 1.14.2)

### PowerShell Unit Tests
- **Location:** `test/unit-tests/test_cases/Test-*.ps1`
- **Framework:** Pester 5.3 + PSScriptAnalyzer
- **Run:** `./test/unit-tests/test_main.ps1`
- **CI:** `run_unit_tests.yml` → `Windows-PowerShell-Tests` job

### Ginkgo Integration Tests
- **Location:** `test/ginkgo-e2e/`
- **Suites:** `livenessprobe/`, `querylogs/`, `containerstatus/`
- **Run:** `cd test/ginkgo-e2e/<suite> && go test -v ./...`

### Python E2E Tests
- **Location:** `test/e2e/src/tests/`
- **Framework:** pytest
- **Utilities:** `test/e2e/src/common/` (K8s, Helm, ARM REST clients)
- **Run:** `cd test/e2e/src && python -m pytest tests/ -v`

## Adding New Tests
1. Determine the appropriate test type and language
2. Follow naming conventions for that language
3. Ensure CI script discovers the new test file automatically
4. Run the full test suite to verify no regressions

## Test Data
- **Canned API responses:** `test/unit-tests/canned-api-responses/`
- **Scenario configs:** `test/scenario/`
- **Scale test configs:** `test/containerlog-scale-tests/`, `test/networkflow-scale-tests/`
