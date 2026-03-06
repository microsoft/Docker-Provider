# Telemetry Authoring

## Description
Guides adding telemetry instrumentation following the existing Application Insights patterns used in the container agent.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add logging, add Application Insights, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply
When adding new telemetry instrumentation to any part of the container agent codebase.

### Step-by-Step Procedure

#### 1. Telemetry Pattern Discovery
Before adding ANY telemetry, identify the existing pattern for the language:

**Go (source/plugins/go/src/):**
- SDK: `github.com/microsoft/ApplicationInsights-Go/appinsights`
- Client: `TelemetryClient` singleton initialized in `telemetry.go`
- Events: `SendEvent(eventName, dimensions)` — see `telemetry.go`
- Metrics: `SendContainerLogPluginMetrics()`, `SendTracesAsMetrics()`
- Common properties: `CommonProperties` map (computer, controller_type, etc.)
- Init: `TelemetryClient = appinsights.NewTelemetryClient(instrumentationKey)`

**Ruby (source/plugins/ruby/):**
- Helper: `ApplicationInsightsUtility` class in `ApplicationInsightsUtility.rb`
- Events: `ApplicationInsightsUtility.sendCustomEvent(eventName, properties)`
- Metrics: `ApplicationInsightsUtility.sendMetricTelemetry(name, value, props)`
- Exceptions: `ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)`
- API tracking: `ApplicationInsightsUtility.sendAPIResponseTelemetry(code, uri, eventName, hash, tracker)`
- Init: `ApplicationInsightsUtility.initializeUtility()` called at startup

#### 2. What to Instrument (priority order)

a. **Error paths** — Every `rescue`/`if err != nil` block representing an unexpected failure:
   - Ruby: `ApplicationInsightsUtility.sendExceptionTelemetry(errorStr)`
   - Go: log the error and send via `SendEvent` with error dimensions

b. **Entry points and API boundaries** — HTTP handlers, plugin callbacks:
   - Track: operation name, duration, success/failure
   - Go pattern: telemetry dimensions map with count/status fields

c. **External calls** — Kubernetes API, cAdvisor API, MDSD:
   - Ruby: `ApplicationInsightsUtility.sendAPIResponseTelemetry(response.code, uri, ...)`
   - Go: track response codes and timing

d. **Critical business logic** — data processing milestones, cache operations:
   - Ruby: `ApplicationInsightsUtility.sendCustomEvent(eventName, properties)`
   - Go: `SendEvent(eventName, telemetryDimensions)`

#### 3. Telemetry Conventions
- Standard dimensions: `Computer` (hostname), `ControllerType` (DS/RS), `ContainerRuntime`
- Metric naming: descriptive names like `LastProcessedContainerInventoryCount`, `FlushedRecordsCount`
- Event naming: PascalCase descriptive names like `HeartBeatEvent`, `KubeMonAgentEventsFlushedEvent`
- Env var for key: `APPLICATIONINSIGHTS_AUTH` (never hardcode)
- Env var for endpoint: `APPLICATIONINSIGHTS_ENDPOINT`

#### 4. Anti-Patterns to Avoid
- Do NOT log sensitive data (credentials, tokens, PII)
- Do NOT add telemetry inside tight loops
- Do NOT use `puts`/`print`/`fmt.Println` for production telemetry
- Do NOT create new TelemetryClient instances — reuse the singleton
- Do NOT hardcode instrumentation keys

### Validation
- Verify telemetry import matches existing files
- Verify event/metric names follow the repo's naming convention
- Run unit tests to ensure telemetry additions don't break test isolation
