# Feature Development

## Description
Add new features to the container monitoring agent — new data streams, authentication methods, cloud support, or telemetry capabilities.

USE FOR: add feature, implement, new stream, new auth, enable support, add cloud support, networkflow, OTLP
DO NOT USE FOR: bug fixes, refactoring, documentation only, dependency updates

## Instructions

### When to Apply
When implementing new monitoring capabilities, authentication methods, data streams, or cloud support.

### Step-by-Step Procedure
1. **Identify affected layers:**
   - Go plugin changes: `source/plugins/go/src/` or `source/plugins/go/input/`
   - Ruby plugin changes: `source/plugins/ruby/`
   - Configuration: `build/common/installer/conf/`, `kubernetes/linux/defaultpromenvvariables*`
   - Kubernetes manifests: `kubernetes/ama-logs.yaml`
   - Helm charts: `charts/azuremonitor-containers/`

2. **Implement the feature** following existing plugin patterns:
   - Go input plugins: Follow `containerinventory` or `perf` plugin pattern in `source/plugins/go/input/`
   - Go output plugins: Follow `out_oms.go` pattern in `source/plugins/go/src/`
   - Ruby plugins: Follow Fluentd plugin pattern with `Fluent::Plugin.register_*`

3. **Add telemetry** for the new feature using `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go).

4. **Add unit tests** for new code paths.

5. **Update configuration** if new environment variables or ConfigMap settings are needed.

6. **Update Helm chart** if new values or templates are required.

### Files Typically Involved
- `source/plugins/go/src/*.go` or `source/plugins/go/input/*/`
- `source/plugins/ruby/*.rb`
- `kubernetes/ama-logs.yaml`
- `charts/azuremonitor-containers/values.yaml`

### Validation
- Unit tests pass for new and existing code
- Docker image builds successfully
- Trivy scan passes
- Feature works in both DaemonSet and ReplicaSet modes

## Examples from This Repo
- `Added FIC auth support (#1539)`
- `Enabled OTel logs and traces support (#1527)`
- `Adding change for networkflow logs new stream (#1551)`
- `Add high logs scale support for ARC (#1491)`
