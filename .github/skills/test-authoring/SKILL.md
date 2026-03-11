# Skill: Test Authoring

## Overview
Write and maintain tests across the five test suites in Docker-Provider. Follow TDD when possible: write a failing test first, then implement the change.

## Test Suites

### 1. Go Unit Tests
- **Location**: `*_test.go` files alongside source in `source/plugins/go/src/` and `source/plugins/go/input/`
- **Framework**: Go `testing` package with `testify` assertions
- **Run**: `./test/unit-tests/run_go_tests.sh`
- **Pattern**:
```go
func TestParseLogEntry_EmptyInput(t *testing.T) {
    result, err := ParseLogEntry("")
    assert.Error(t, err)
    assert.Nil(t, result)
}
```
- **Conventions**: Table-driven tests preferred for multiple cases. Use `t.Helper()` in shared functions.

### 2. Ruby Unit Tests
- **Location**: `test/unit-tests/` (e.g., `test_driver.rb` and related test files)
- **Framework**: Minitest
- **Run**: `ruby test/unit-tests/test_driver.rb`
- **Pattern**:
```ruby
class TestContainerLogParser < Minitest::Test
  def test_parse_valid_log_line
    result = ContainerLogParser.parse("2024-01-01T00:00:00Z stdout F hello")
    assert_equal "hello", result[:message]
  end
end
```
- **Conventions**: Class name must start with `Test` and extend `Minitest::Test`.

### 3. Bash Unit Tests
- **Location**: `test/unit-tests/test_cases/*.sh`
- **Harness**: `test/unit-tests/test_main.sh` drives all test cases
- **Run**: `./test/unit-tests/test_main.sh`
- **Pattern**:
```bash
test_env_variable_defaults() {
    unset AZMON_CLUSTER_REGION
    source kubernetes/linux/main.sh --dry-run
    assertEquals "default" "$CLUSTER_REGION"
}
```
- **Conventions**: Each test is a shell function. Use assertion helpers from the test harness.

### 4. Python E2E Tests
- **Location**: `test/e2e/src/tests/`
- **Framework**: pytest with fixtures
- **Run**: `pytest test/e2e/src/tests/`
- **Pattern**:
```python
def test_container_logs_ingested(aks_cluster):
    results = query_log_analytics(aks_cluster, "ContainerLog | take 1")
    assert len(results) > 0
```
- **Conventions**: Use pytest fixtures for cluster setup. These tests require a live AKS cluster.

### 5. Ginkgo E2E Tests
- **Location**: `test/ginkgo-e2e/` (each subdirectory has its own `go.mod`)
- **Framework**: Ginkgo BDD with Gomega matchers
- **Run**: `cd test/ginkgo-e2e/<suite> && ginkgo run`
- **Pattern**:
```go
var _ = Describe("Container Insights", func() {
    It("should collect CPU metrics", func() {
        metrics := getMetrics(clusterCtx)
        Expect(metrics).NotTo(BeEmpty())
    })
})
```
- **Conventions**: Describe/Context/It hierarchy. Separate `go.mod` per suite.

## TDD Workflow
1. Write a failing test that captures the expected behavior.
2. Run the test — confirm it fails for the right reason.
3. Implement the minimal code to make the test pass.
4. Refactor while keeping tests green.
5. Run the full relevant suite before committing.

## CI Integration
Tests run automatically via `.github/workflows/run_unit_tests.yml`. All Go, Ruby, and Bash unit tests must pass before merge. E2E tests run in separate pipeline stages against live clusters.
