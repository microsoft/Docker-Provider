# Telemetry Authoring

## Description
Add Application Insights telemetry to the Docker-Provider agent following existing instrumentation patterns.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add logging, add Application Insights, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply
When adding new code paths, error handlers, or entry points that need observability. Also when existing code lacks telemetry coverage.

### Step-by-Step Procedure

#### 1. Telemetry Pattern Discovery
Before adding ANY telemetry, identify the pattern in use:

**Ruby plugins** (`source/plugins/ruby/`):
- Helper: `ApplicationInsightsUtility` class in `source/plugins/ruby/ApplicationInsightsUtility.rb`
- Error telemetry: `ApplicationInsightsUtility.sendExceptionTelemetry(e)`
- Custom events: `ApplicationInsightsUtility.sendCustomEvent("EventName", properties)`
- Metrics: `ApplicationInsightsUtility.sendMetricTelemetry("metricName", value, properties)`
- Initialization: `ApplicationInsightsUtility.initializeUtility()` called at startup
- Standard properties: `computer`/hostname, `controllerType` (DS/RS), `agentVersion`, `clusterName`

**Go output plugin** (`source/plugins/go/src/`):
- Client: Global `TelemetryClient` from `telemetry.go` (type `appinsights.TelemetryClient`)
- Metrics: `TelemetryClient.TrackMetric("MetricName", value)` with `CommonProperties`
- Events: `TelemetryClient.TrackEvent("EventName")` with properties map
- Errors: `TelemetryClient.TrackException(err)` with properties
- Common properties: `CommonProperties` map set during initialization in `telemetry.go`
- Periodic telemetry: Uses `time.Ticker` for batched metric emission

#### 2. What to Instrument (priority order)

**a. Error paths (highest priority)**
- Every `rescue => e` (Ruby) or `if err != nil` (Go) block for unexpected failures
- Include: error type, message, stack trace (Ruby: `e.backtrace`), operation context
- Pattern: `ApplicationInsightsUtility.sendExceptionTelemetry(e)` or `TelemetryClient.TrackException(err)`

**b. Entry points and boundaries**
- Fluent Bit plugin `start`/`run`/`emit` methods, HTTP endpoints, timer callbacks
- Track: operation name, duration, success/failure, record counts
- Pattern: Capture start time, compute duration, emit metric

**c. External calls**
- Kubernetes API calls, AMCS/Log Analytics HTTP posts, Azure auth token requests
- Track: target endpoint, duration, response status/error
- Pattern: Wrap call with timing; emit success/failure metric

**d. Critical business logic**
- Log flush operations, inventory collection cycles, config reloads
- Track: counts, batch sizes, latency
- Pattern: `TelemetryClient.TrackMetric("flush.count", count)` with dimensions

#### 3. Telemetry Conventions
- Metric naming: `<component>.<operation>.<measurement>` (e.g., `containerlog.flush.count`, `kubeinventory.collect.duration`)
- Event naming: `PascalCase` (e.g., `HeartBeatEvent`, `ExceptionEvent`, `ConfigReloaded`)
- Standard dimensions on all telemetry:
  - `Computer` — hostname of the node
  - `ControllerType` — `DS` or `RS`
  - `AgentVersion` — from `AGENT_VERSION` env var
  - `ClusterName` / `ClusterId` — from `AKS_RESOURCE_ID`

#### 4. Anti-Patterns to Avoid
- Do NOT log sensitive data (credentials, tokens, PII, request bodies)
- Do NOT add telemetry inside tight loops (batch and emit periodically using tickers)
- Do NOT use `puts`/`$stdout`/`fmt.Println` for production telemetry — use the SDK
- Do NOT create new `TelemetryClient` instances — reuse the global singleton
- Do NOT emit telemetry in unit test code paths (respect `$in_unit_test` in Ruby)
- Do NOT hardcode instrumentation keys — use `APPLICATIONINSIGHTS_AUTH` env var

#### 5. Validation
- Verify import/require matches existing files
- Verify metric/event names follow naming convention
- Verify dimensions match the standard set
- Run unit tests to ensure telemetry additions don't break test isolation
- Check that Ruby telemetry is gated with `$in_unit_test`

## References
- `source/plugins/ruby/ApplicationInsightsUtility.rb` — Ruby telemetry helper
- `source/plugins/go/src/telemetry.go` — Go telemetry initialization and helpers
