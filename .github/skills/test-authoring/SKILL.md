# Test Authoring Skill

## Name
test-authoring

## Description
Create unit tests, integration tests, or E2E tests following the Docker-Provider testing patterns.

## Triggers
- "write tests", "add test coverage", "create unit test", "add integration test"

## Workflow

### 1. Determine Test Type

| Question | Answer → Test Type |
|----------|-------------------|
| Pure logic with no external dependencies? | Unit test |
| Needs to mock K8s API, HTTP, or file system? | Unit test with mocks |
| Tests container startup/liveness? | Ginkgo integration test |
| Tests end-to-end data flow? | E2E test (Python/pytest) |

### 2. Test Patterns by Language

**Go Unit Tests:**
- Location: same directory as source (e.g., `source/plugins/go/src/oms_test.go`)
- Framework: `testing` + `testify/assert` + `golang/mock`
- Naming: `func Test<Description>(t *testing.T)`
- Example structure:
```go
func TestNetworkFlowRecordProcessing(t *testing.T) {
    // Arrange
    records := []map[interface{}]interface{}{...}
    
    // Act
    result := PostNetworkFlowRecords(records)
    
    // Assert
    assert.Equal(t, output.FLB_OK, result)
}
```

**Bash Unit Tests:**
- Location: `test/unit-tests/test_cases/test_*.sh`
- Functions: `test/unit-tests/test_functions/`
- Framework: Custom (`test_framework.sh` with assert functions)
- Register test in `test/unit-tests/test_main.sh`

**PowerShell Unit Tests (Pester 5.3):**
- Location: `test/unit-tests/test_cases/Test-<FunctionName>.ps1`
- Functions under test: `test/unit-tests/test_functions/<FunctionName>.ps1`
- Pattern:
```powershell
Describe "Get-McsEndpoint" {
    Context "When given valid input" {
        It "Should return correct endpoint" {
            $result = Get-McsEndpoint -Region "eastus"
            $result | Should -Be "expected-value"
        }
    }
}
```

**Ruby Unit Tests:**
- Location: alongside source in `source/plugins/ruby/*_test.rb`
- Run with: `./test/unit-tests/run_ruby_tests.sh`

**Ginkgo Integration Tests:**
- Location: `test/ginkgo-e2e/<suite>/`
- Each suite has own `go.mod`
- Tests: liveness probe, query logs, container status

**Python E2E Tests (pytest):**
- Location: `test/e2e/src/tests/test_*_workflows.py`
- Utilities: `test/e2e/src/common/` (K8s clients, Helm, ARM REST)

### 3. Validate
```bash
# Run all tests
./test/unit-tests/test_main.sh
./test/unit-tests/run_go_tests.sh
./test/unit-tests/run_ruby_tests.sh
# PowerShell (Windows)
./test/unit-tests/test_main.ps1
```

### 4. CI Integration
New tests are automatically picked up by:
- `test_main.sh` — scans `test/unit-tests/test_cases/` for `*.sh` files
- `run_go_tests.sh` — runs `go test` in Go source directories
- `run_ruby_tests.sh` — runs Ruby test files
- `test_main.ps1` — discovers Pester test files

## Supporting Commits (12 months)
- Testkube workflow migration (#1589)
- Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)
- Fix testkube mongodb issue (#1584)
- Update conformnace test (#1452)
- Test Automation Framework improvements (#1449)
- Remove custom metrics tests from conformance tests (#1528)
- Updated Conf test image (#1540)
- Longw/networkflow testkube (#1499)
- TAF: Check errors in process files (#1460)
