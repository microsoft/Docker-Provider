# Telemetry Authoring

## Description
Guides adding telemetry instrumentation (metrics, events, traces) following the existing Application Insights patterns in this repository.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add Application Insights, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### Telemetry Pattern Discovery
Before adding ANY telemetry, identify the existing pattern:

**Go (source/plugins/go/src/):**
- SDK: `github.com/microsoft/ApplicationInsights-Go/appinsights`
- Client: global `TelemetryClient appinsights.TelemetryClient` (initialized in `telemetry.go`)
- Metrics: `appinsights.NewMetricTelemetry(name, value)` with `CommonProperties`
- Events: `appinsights.NewEventTelemetry(name)` with custom properties
- Common dimensions: `CommonProperties` map includes cluster info, agent version, controller type
- Telemetry ticker: `ContainerLogTelemetryTicker` sends periodic metrics

**Ruby (source/plugins/ruby/):**
- Helper: `ApplicationInsightsUtility` class (in `ApplicationInsightsUtility.rb`)
- Events: `ApplicationInsightsUtility.sendCustomEvent(eventName, properties)`
- Metrics: `ApplicationInsightsUtility.sendMetricTelemetry(metricName, value, properties)`
- Exceptions: `ApplicationInsightsUtility.sendExceptionTelemetry(exception, properties)`
- Common dimensions: `@@CustomProperties` hash set during `initializeUtility()`

### What to Instrument (priority order)

1. **Error paths** — Every `rescue => e` (Ruby) or `if err != nil` (Go) for unexpected failures
   - Include: error type, message, operation context
   - Ruby: `ApplicationInsightsUtility.sendExceptionTelemetry(e)`
   - Go: Track via event telemetry with error details

2. **Entry points** — HTTP handlers, Fluent Bit plugin callbacks (`FLBPluginFlush`, `FLBPluginInit`)
   - Track: operation name, duration, success/failure

3. **External calls** — Kubernetes API calls, Azure Monitor ingestion
   - Track: target, duration, response status
   - Ruby: `KubernetesApiClient` already tracks some calls

4. **Business logic** — inventory collection cycles, log flush batches
   - Track: record counts, sizes, latencies
   - Pattern: accumulate in period variables, emit via telemetry ticker

### Telemetry Conventions
- Metric naming: `<component>.<operation>.<measurement>` (e.g., `FlushedRecordsCount`, `FlushedRecordsSize`)
- Event naming: `PascalCase` descriptive names (e.g., `HeartBeatEvent`, `ExceptionEvent`)
- Standard dimensions: `computer`/hostname, `controllerType` (DS/RS), `agentVersion`, `clusterType`
- Error telemetry must include: error class/type, message, source context

### Anti-Patterns
- Do NOT log PII, credentials, tokens, or request bodies
- Do NOT add telemetry inside tight loops
- Do NOT use `puts`/`print`/`fmt.Println` for production telemetry
- Do NOT create new TelemetryClient instances — reuse global
- Do NOT emit telemetry in test code paths (respect `$in_unit_test` / `GOUNITTEST`)
- Do NOT hardcode instrumentation keys — use `APPLICATIONINSIGHTS_AUTH` env var

### Validation
- Verify import matches existing files
- Verify metric/event names follow naming convention
- Run unit tests to ensure test isolation is maintained
- Check telemetry is gated for test environments
