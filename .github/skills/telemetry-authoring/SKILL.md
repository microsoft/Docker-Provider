# Telemetry Authoring

## Description
Add Application Insights telemetry following the existing patterns in this repository.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add logging, add Application Insights, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply
When adding telemetry instrumentation to new or existing code paths in Go plugins or Ruby plugins.

### Step-by-Step Procedure

#### 1. Telemetry Pattern Discovery
Before adding ANY telemetry, identify the existing pattern:

**Go plugins** (`source/plugins/go/src/`):
- SDK: `github.com/microsoft/ApplicationInsights-Go/appinsights`
- Client: `TelemetryClient` (global singleton initialized in `telemetry.go`)
- Init: `appinsights.NewTelemetryClient(ikey)` with proxy support
- Events: `TelemetryClient.TrackEvent(name, properties)` / `TelemetryClient.TrackMetric(name, value)`
- Properties: `CommonProperties` map includes `Computer`, `AgentVersion`, `ControllerType`, `ContainerRuntime`
- Env guards: Check `GOUNITTEST` / `ISTEST` before initializing telemetry

**Ruby plugins** (`source/plugins/ruby/`):
- Utility: `ApplicationInsightsUtility` class in `ApplicationInsightsUtility.rb`
- Methods: `sendExceptionTelemetry(error)`, `sendCustomEvent(eventName, properties)`, `sendMetricTelemetry(name, value, properties)`
- Properties: `@@CustomProperties` includes cluster type, region, agent version, controller type
- Env guards: Telemetry skipped when `APPLICATIONINSIGHTS_AUTH` env var is empty

#### 2. What to Instrument (priority order)

a. **Error paths** — Every `rescue`/`if err != nil` block for unexpected failures:
   - Ruby: `ApplicationInsightsUtility.sendExceptionTelemetry(error)`
   - Go: `TelemetryClient.TrackException(err)` with context properties

b. **Entry points** — HTTP handlers, Fluent Bit plugin callbacks, timer-based collection:
   - Track operation name, duration, success/failure

c. **External calls** — Kubernetes API calls, Azure Monitor ingestion, MDSD communication:
   - Track target, duration, response status/error

d. **Custom events** — State transitions, configuration changes, feature flag activation:
   - Ruby: `ApplicationInsightsUtility.sendCustomEvent("EventName", {"key" => "value"})`
   - Go: `TelemetryClient.TrackEvent("EventName")` with properties

#### 3. Naming Conventions
- Events: PascalCase descriptive names (e.g., `HeartBeatEvent`, `ExceptionEvent`, `ContainerLogFlush`)
- Metrics: Descriptive names with component prefix (e.g., `FlushedRecordsCount`, `FlushedRecordsSize`)
- Properties: PascalCase keys matching `CommonProperties` pattern (`Computer`, `ControllerType`, `ContainerRuntime`)

#### 4. Anti-Patterns to Avoid
- Do NOT log sensitive data (credentials, tokens, PII)
- Do NOT add telemetry inside tight loops
- Do NOT create new `TelemetryClient` instances — use the existing singleton
- Do NOT emit telemetry in unit test code paths (respect `GOUNITTEST`/`ISTEST` guards)
- Do NOT hardcode instrumentation keys — use `APPLICATIONINSIGHTS_AUTH` env var

#### 5. Validation
- Verify import matches existing files (`ApplicationInsightsUtility` for Ruby, `appinsights` for Go)
- Verify event/metric names follow PascalCase convention
- Run unit tests to ensure telemetry additions don't break test isolation
- Check that telemetry is gated for unit test environments

### Files Typically Involved
- `source/plugins/go/src/telemetry.go` — Go telemetry setup and helpers
- `source/plugins/go/input/lib/applicationinsights.go` — Input plugin telemetry
- `source/plugins/ruby/ApplicationInsightsUtility.rb` — Ruby telemetry utility
- Any plugin file that handles data collection or error paths
