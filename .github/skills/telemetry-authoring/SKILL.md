# Telemetry Authoring

## Description

Add telemetry instrumentation to Docker-Provider code following existing Application Insights patterns in Go and Ruby.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add logging, add Application Insights, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply

When adding new code paths, error handlers, entry points, or external calls that need observability.

### Step-by-Step Procedure

1. **Identify the telemetry SDK for the language:**
   - **Go:** `github.com/microsoft/ApplicationInsights-Go` via `telemetry.go` helpers (`SendException`, `SendEvent`, `SendMetric`)
   - **Ruby:** `ApplicationInsightsUtility` class in `source/plugins/ruby/ApplicationInsightsUtility.rb`

2. **Sample 3-5 existing files with telemetry in the same module** to learn the exact pattern:
   - Go: `source/plugins/go/src/oms.go`, `source/plugins/go/src/telemetry.go`
   - Ruby: `source/plugins/ruby/in_kube_podinventory.rb`, `source/plugins/ruby/KubernetesApiClient.rb`

3. **Add telemetry to these code areas (by priority):**

   a. **Error paths** (highest priority)
   - Go: `if err != nil { SendException(err.Error()) }`
   - Ruby: `rescue => e; ApplicationInsightsUtility.sendExceptionTelemetry(e)`

   b. **Entry points and API boundaries**
   - Track operation name, duration, success/failure
   - Go: Use `SendMetric` with operation timing
   - Ruby: Use `ApplicationInsightsUtility.sendMetricTelemetry`

   c. **External calls** (Kubernetes API, HTTP, Azure services)
   - Track target service, operation, duration, response status
   - Wrap call with timing and error tracking

   d. **Critical business logic** (data collection, parsing, forwarding)
   - Track custom events with relevant dimensions
   - Ruby: `ApplicationInsightsUtility.sendCustomEvent(eventName, properties)`

4. **Follow naming conventions:**
   - Metric names: `<component>.<operation>.<measurement>` (e.g., `container_log.flush.duration`)
   - Event names: `<ComponentAction>` (e.g., `KubeInventoryCollected`, `FlushFailed`)
   - Standard dimensions: `computer`/hostname, `controller_type` (DaemonSet/ReplicaSet), `os_type`

5. **Anti-patterns to avoid:**
   - Do NOT log sensitive data (credentials, tokens, workspace keys)
   - Do NOT add telemetry inside tight loops
   - Do NOT use `fmt.Println` or `puts` for production telemetry
   - Do NOT create new TelemetryClient instances — reuse existing singletons
   - Do NOT emit telemetry in unit test code paths
   - Do NOT hardcode instrumentation keys — use env vars (`APPLICATIONINSIGHTS_AUTH`)

### Files Typically Involved

- `source/plugins/go/src/telemetry.go` — Go telemetry helpers
- `source/plugins/ruby/ApplicationInsightsUtility.rb` — Ruby telemetry utility
- Target source files receiving instrumentation

### Validation

- Verify telemetry import/require matches existing files
- Verify metric/event names follow the repo naming convention
- Run unit tests to ensure telemetry additions don't break test isolation
- Check that telemetry is gated for unit test environments
