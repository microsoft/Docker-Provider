# Telemetry Authoring

## Description
Guide for adding telemetry instrumentation following existing Application Insights patterns.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add logging, add Application Insights
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply
When adding telemetry to new or existing code paths in Go plugins, Ruby plugins, or scripts.

### Step-by-Step Procedure

#### 1. Telemetry Pattern Discovery
Before adding ANY telemetry:
- **Go plugins:** Use `TelemetryClient` from `source/plugins/go/src/telemetry.go`. Initialize via `appinsights.NewTelemetryClient()` with `APPLICATIONINSIGHTS_AUTH` env var.
- **Ruby plugins:** Use `ApplicationInsightsUtility` from `source/plugins/ruby/ApplicationInsightsUtility.rb`. Call `sendExceptionTelemetry(e)` for errors, `sendMetricTelemetry()` for metrics.
- NEVER introduce a new telemetry SDK — always follow the existing pattern.

#### 2. What to Instrument

**a. Error paths (highest priority)**
- Go: `if err != nil` blocks → `SendException(err)` with context
- Ruby: `rescue => e` blocks → `ApplicationInsightsUtility.sendExceptionTelemetry(e)`
- Include: error type, message, operation context

**b. Entry points and API boundaries**
- Track operation name, duration, success/failure
- Go: create metric tracking at function start/end
- Ruby: use `sendMetricTelemetry()` with timing

**c. External calls**
- HTTP calls, Kubernetes API calls, MDSD writes
- Track: target, duration, response status

**d. Critical business logic**
- Data collection milestones, flush events, configuration changes
- Use custom events with properties

#### 3. Telemetry Conventions
- **Go metric naming:** descriptive variable names (e.g., `FlushedRecordsCount`, `TelegrafMetricsSentCount`)
- **Ruby event naming:** `@@HeartBeat = "HeartBeatEvent"`, `@@Exception = "ExceptionEvent"`
- **Standard dimensions (Go):** `CommonProperties` map with computer, controller type, AKS resource ID, region
- **Standard dimensions (Ruby):** `@@CustomProperties` with ID, Region, WSID, AgentVersion, ControllerType

#### 4. Anti-Patterns to Avoid
- Do NOT log sensitive data (credentials, tokens, PII)
- Do NOT add telemetry inside tight loops
- Do NOT use `puts`/`fmt.Println` for production telemetry
- Do NOT create new TelemetryClient instances — reuse `TelemetryClient` (Go) or `@@Tc` (Ruby)
- Do NOT hardcode instrumentation keys — use `APPLICATIONINSIGHTS_AUTH` env var

#### 5. Validation
- Verify the telemetry import matches existing files
- Verify metric/event names follow repo conventions
- Run unit tests to ensure telemetry doesn't break test isolation
- Check that telemetry is gated for test environments
