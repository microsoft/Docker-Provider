# Skill: Feature Development

## Overview
Add new capabilities to the Docker-Provider monitoring agent: new Fluent-Bit plugins, Kubernetes resource collection, metrics, or configuration options.

## Scope
- **Go input plugins**: `source/plugins/go/input/` — collect data from K8s API or node
- **Go output plugins**: `source/plugins/go/src/` — send data to Azure Monitor / Geneva
- **Ruby filter/output plugins**: `source/plugins/ruby/` — Fluent-Bit Ruby plugins
- **Configuration**: `kubernetes/linux/conf/`, `source/plugins/ruby/conf/`
- **Helm charts**: `charts/azuremonitor-containers*/`
- **K8s manifests**: `kubernetes/ama-logs.yaml`

## Workflow

### 1. Plan the Feature
- Identify which plugin type is needed (input, filter, or output).
- Determine the language: Go for performance-critical or API-heavy work; Ruby for log transformation and filtering.
- Check if an existing plugin can be extended before creating a new one.

### 2. Implement the Plugin

#### Go Plugin
- Place source in `source/plugins/go/src/` (output) or `source/plugins/go/input/` (input).
- Register the plugin in the appropriate `main.go` or plugin registration file.
- Follow existing patterns for structured logging and error handling.
- Use the Application Insights Go SDK for telemetry (`source/plugins/go/src/` telemetry utilities).
- Add dependencies to the correct `go.mod` and run `go mod tidy`.

#### Ruby Plugin
- Place source in `source/plugins/ruby/`.
- Register in the Fluent-Bit configuration (`kubernetes/linux/conf/` or `source/plugins/ruby/conf/`).
- Use `ApplicationInsightsUtility` for telemetry.
- Handle nil/empty values defensively; Fluent-Bit will crash on unhandled exceptions.

### 3. Add Configuration
- Add new environment variables or config map entries as needed.
- Update `kubernetes/linux/main.sh` if the feature requires startup-time setup.
- For Windows support, mirror changes in `kubernetes/windows/main.ps1`.

### 4. Update Helm Charts
- Add new values to `values.yaml` in relevant chart directories.
- Update `templates/` if new K8s resources or config entries are needed.
- Bump chart version in `Chart.yaml`.

### 5. Update K8s Manifests
- If the feature changes the DaemonSet or Deployment spec, update `kubernetes/ama-logs.yaml`.

### 6. Write Tests
| Component | Test Location | Framework |
|-----------|--------------|-----------|
| Go plugin | `*_test.go` next to source | testify |
| Ruby plugin | `test/unit-tests/` | Minitest |
| Shell changes | `test/unit-tests/test_cases/*.sh` | Shell harness |
| E2E validation | `test/ginkgo-e2e/` or `test/e2e/` | Ginkgo / pytest |

### 7. Validate
```bash
cd build/linux && make                    # Full build
./test/unit-tests/run_go_tests.sh         # Go tests
ruby test/unit-tests/test_driver.rb       # Ruby tests
./test/unit-tests/test_main.sh            # Bash tests
```

## Commit Convention
Freeform message describing the feature. Reference the PR:
```
Add node GPU metrics collection via input plugin (#1234)
```

## Pitfalls
- New Go dependencies must be added to all relevant `go.mod` files.
- Fluent-Bit plugin registration order matters — check existing config.
- Features must work on both Linux and Windows unless explicitly scoped.
- Large data collection changes can impact agent memory; profile before merging.
- Telemetry must be instrumented for new data paths (Application Insights).
