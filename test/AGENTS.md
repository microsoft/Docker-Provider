# Test AGENTS.md — Azure Monitor for Containers (Docker-Provider)

This document guides AI coding agents (and human developers) on how to write,
organize, and run tests in this repository.

---

## Test Decision Tree

Use this flowchart to pick the right test type:

```
Is the logic pure computation (parsing, formatting, config transform)?
  └─ YES → Unit test (Go testify / Ruby Minitest / Bash harness / PowerShell Pester)
Does it call the Kubernetes API, Fluent-Bit, or Application Insights SDK?
  └─ YES → Integration test (mock the external dependency or use a fake)
Does it verify a multi-step user scenario end-to-end (deploy → collect → query)?
  └─ YES → E2E test (Python pytest in test/e2e/ or Ginkgo v2 in test/ginkgo-e2e/)
Does it verify behaviour across config variations (Linux/Windows, proxy/no-proxy)?
  └─ YES → Parameterized / scenario test (test/scenario/)
```

---

## Test Frameworks & Patterns

### 1. Go (testify) — Unit Tests

| Item | Detail |
|------|--------|
| Location | `source/plugins/go/` (test files alongside source) |
| Naming | `*_test.go` next to the file under test |
| Runner | `./test/unit-tests/run_go_tests.sh` |
| Framework | `github.com/stretchr/testify/assert` |

**Pattern:**

```go
package mypkg

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestParseLogLine_ValidInput(t *testing.T) {
    result, err := ParseLogLine(sampleLine)
    assert.NoError(t, err)
    assert.Equal(t, "expected-container-id", result.ContainerID)
}
```

**Adding a new test:**
1. Create `<source_file>_test.go` alongside the source file.
2. Write `func TestXxx(t *testing.T)` functions using `testify/assert`.
3. Run: `./test/unit-tests/run_go_tests.sh`

---

### 2. Ruby (Minitest) — Unit Tests

| Item | Detail |
|------|--------|
| Location | `test/unit-tests/` |
| Naming | `test_*.rb` |
| Runner | `ruby test/unit-tests/test_driver.rb` |
| Framework | `Minitest::Test` |

**Pattern:**

```ruby
require "minitest/autorun"
require_relative "../../source/plugins/ruby/my_plugin"

class TestMyPlugin < Minitest::Test
  def setup
    @plugin = MyPlugin.new
  end

  def test_parse_valid_record
    result = @plugin.parse(sample_record)
    assert_equal "expected_value", result[:key]
  end
end
```

**Adding a new test:**
1. Create `test/unit-tests/test_<feature>.rb`.
2. Subclass `Minitest::Test`; prefix methods with `test_`.
3. Register the file in `test/unit-tests/test_driver.rb` if needed.
4. Run: `ruby test/unit-tests/test_driver.rb`

---

### 3. Bash — Shell Test Harness

| Item | Detail |
|------|--------|
| Location | `test/unit-tests/test_cases/*.sh` |
| Runner | `./test/unit-tests/test_main.sh` |
| Framework | Custom shell harness in `test/unit-tests/` |

**Pattern:**

```bash
#!/bin/bash
# test_cases/test_env_parsing.sh

source "$(dirname "$0")/../test_helpers.sh"

test_env_variable_defaults() {
  unset AZMON_COLLECT_ENV
  source ../../scripts/config_env.sh
  assert_equals "true" "$AZMON_COLLECT_ENV" "default should be true"
}

run_test test_env_variable_defaults
```

**Adding a new test:**
1. Create `test/unit-tests/test_cases/test_<feature>.sh`.
2. Source the test helpers; write functions prefixed with `test_`.
3. Call `run_test <function_name>` at the bottom.
4. Run: `./test/unit-tests/test_main.sh`

---

### 4. Python (pytest) — E2E Tests

| Item | Detail |
|------|--------|
| Location | `test/e2e/src/tests/` |
| Naming | `test_*.py` |
| Runner | `pytest -xvs test/e2e/src/tests/` |
| Framework | pytest with fixtures |

**Pattern:**

```python
import pytest

@pytest.fixture
def aks_cluster(request):
    """Provides a handle to the test AKS cluster."""
    return request.config.getoption("--cluster-name")

def test_container_logs_flowing(aks_cluster):
    """Verify container logs reach the Log Analytics workspace."""
    result = query_log_analytics(aks_cluster, "ContainerLog | take 1")
    assert len(result.tables[0].rows) > 0, "No container logs found"
```

**Adding a new test:**
1. Create `test/e2e/src/tests/test_<scenario>.py`.
2. Use `@pytest.fixture` for shared setup (cluster handles, credentials).
3. Run: `pytest -xvs test/e2e/src/tests/test_<scenario>.py`

---

### 5. PowerShell (Pester 5.3.3) — Unit Tests

| Item | Detail |
|------|--------|
| Location | `test/unit-tests/` |
| Naming | `*.Tests.ps1` |
| Runner | `Invoke-Pester -Path test/unit-tests/ -Output Detailed` |
| Framework | Pester 5.3.3 (`Describe` / `It` blocks) |

**Pattern:**

```powershell
Describe "Get-ContainerMetrics" {
    BeforeAll {
        . "$PSScriptRoot/../../source/plugins/powershell/Get-ContainerMetrics.ps1"
    }

    It "returns CPU metric for a running container" {
        $result = Get-ContainerMetrics -ContainerId "abc123"
        $result.CpuPercent | Should -BeGreaterThan 0
    }

    It "returns null for a stopped container" {
        $result = Get-ContainerMetrics -ContainerId "stopped-container"
        $result | Should -BeNullOrEmpty
    }
}
```

**Adding a new test:**
1. Create `test/unit-tests/<Feature>.Tests.ps1`.
2. Use `Describe` / `Context` / `It` blocks.
3. Run: `Invoke-Pester -Path test/unit-tests/<Feature>.Tests.ps1 -Output Detailed`

---

### 6. Ginkgo v2 — BDD E2E Specs

| Item | Detail |
|------|--------|
| Location | `test/ginkgo-e2e/` (subdirs: `querylogs/`, `livenessprobe/`, `containerstatus/`) |
| Runner | `cd test/ginkgo-e2e/<suite> && ginkgo run -v` |
| Framework | Ginkgo v2 + Gomega matchers |

**Pattern:**

```go
package querylogs_test

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

var _ = Describe("Query Logs", func() {
    Context("when the agent is healthy", func() {
        It("should return container logs from Log Analytics", func() {
            rows, err := queryLogAnalytics("ContainerLog | take 5")
            Expect(err).NotTo(HaveOccurred())
            Expect(rows).NotTo(BeEmpty())
        })
    })
})
```

**Adding a new test:**
1. Create a new directory under `test/ginkgo-e2e/<suite_name>/`.
2. Add `suite_test.go` (bootstrap) and spec files.
3. Run: `cd test/ginkgo-e2e/<suite_name> && ginkgo run -v`

---

## Common Test Utilities

| Utility | Location | Purpose |
|---------|----------|---------|
| Shell helpers | `test/unit-tests/test_helpers.sh` | `assert_equals`, `assert_contains`, `run_test` |
| Ruby test driver | `test/unit-tests/test_driver.rb` | Discovers and runs all Ruby Minitest files |
| Go test runner | `test/unit-tests/run_go_tests.sh` | Runs all Go tests with coverage |
| pytest conftest | `test/e2e/src/conftest.py` | Shared pytest fixtures and CLI options |
| Ginkgo bootstrap | `test/ginkgo-e2e/*/suite_test.go` | Ginkgo suite bootstrap per test group |

---

## Test Data & Fixtures

| Type | Location | Notes |
|------|----------|-------|
| Sample log records | `test/unit-tests/test_data/` | JSON/text log samples for parser tests |
| K8s manifests | `test/e2e/manifests/` | Deployment YAMLs for E2E scenarios |
| Scenario configs | `test/scenario/` | Config variations for parameterized testing |
| Mock responses | Inline in test files | Prefer small inline fixtures over external files for unit tests |

---

## Running All Tests

```bash
# Unit tests (Go)
./test/unit-tests/run_go_tests.sh

# Unit tests (Ruby)
ruby test/unit-tests/test_driver.rb

# Unit tests (Bash)
./test/unit-tests/test_main.sh

# Unit tests (PowerShell)
pwsh -Command "Invoke-Pester -Path test/unit-tests/ -Output Detailed"

# E2E tests (Python)
pytest -xvs test/e2e/src/tests/

# E2E tests (Ginkgo)
cd test/ginkgo-e2e/querylogs && ginkgo run -v
cd test/ginkgo-e2e/livenessprobe && ginkgo run -v
cd test/ginkgo-e2e/containerstatus && ginkgo run -v
```

---

## Agent Instructions

When writing tests for this repository:

1. **Match the framework to the source language.** Go source → Go testify test.
   Ruby plugin → Ruby Minitest. Shell script → Bash harness.
2. **Keep unit tests fast and isolated.** No network calls, no Kubernetes API.
   Mock external dependencies.
3. **Use descriptive test names** that state the scenario and expected outcome:
   `TestParseLogLine_MalformedInput_ReturnsError`.
4. **Follow existing patterns.** Look at neighbouring test files for conventions
   before creating new tests.
5. **Run the relevant test suite** after writing tests to confirm they pass.
6. **Do not modify test harness infrastructure** (runners, helpers) unless
   specifically asked to do so.
