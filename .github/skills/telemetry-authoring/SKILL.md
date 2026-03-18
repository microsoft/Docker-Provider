# Telemetry Authoring

## Description
Guides adding telemetry instrumentation following existing Application Insights patterns in the Container Insights agent.

USE FOR: add telemetry, add metrics, add tracing, instrument code, track event, emit metric, add logging, telemetry gap
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation

## Instructions

### When to Apply
When adding telemetry to new or existing code paths in Ruby plugins, Go plugins, or scripts.

### Step-by-Step Procedure

#### 1. Telemetry Pattern Discovery

Before adding ANY telemetry, identify the correct pattern:

**Ruby plugins** (`source/plugins/ruby/`):
- Import: `require_relative "ApplicationInsightsUtility"`
- Initialize: `ApplicationInsightsUtility.initializeUtility()` (called once at startup)
- Track exceptions: `ApplicationInsightsUtility.sendExceptionTelemetry(exception)`
- Track events: `ApplicationInsightsUtility.sendCustomEvent("EventName", properties_hash)`
- Track metrics: `ApplicationInsightsUtility.sendMetricTelemetry("MetricName", value, properties_hash)`
- Heartbeat: `ApplicationInsightsUtility.sendHeartBeatEvent(properties_hash)`
- Standard properties: `computer`, `ControllerType` (DS/RS), `AgentVersion`

**Go plugins** (`source/plugins/go/src/`):
- Import: `"github.com/microsoft/ApplicationInsights-Go/appinsights"`
- Client: `TelemetryClient` (global singleton in `telemetry.go`)
- Track metrics: `TelemetryClient.TrackMetric("MetricName", value)`
- Track events: `TelemetryClient.TrackEvent("EventName")`
- Common properties: set via `CommonProperties` map (cluster ID, region, agent version)
- Telemetry ticker: metrics aggregated and sent periodically via `ContainerLogTelemetryTicker`

#### 2. What to Instrument

a. **Error paths** (highest priority)
   - Ruby: every `rescue` block should call `ApplicationInsightsUtility.sendExceptionTelemetry`
   - Go: log errors and increment error counters (e.g., `ContainerLogsSendErrorsToMDSDFromFluent`)

b. **Entry points and API boundaries**
   - Ruby: `start` and `run` methods in input plugins — track collection duration
   - Go: `FLBPluginFlushCtx` — track flush duration and record count

c. **External calls**
   - Kubernetes API calls — track latency (e.g., `@nodesAPIE2ELatencyMs`)
   - MDSD writes — track send errors and success counts

d. **Business logic milestones**
   - Inventory collection completions
   - Config reload events
   - Cache refresh operations

#### 3. Naming Conventions

- Metric names: descriptive, module-scoped (e.g., `FlushedRecordsCount`, `AgentLogProcessingMaxLatencyMs`)
- Event names: PascalCase (e.g., `HeartBeatEvent`, `ExceptionEvent`)
- Standard dimensions: `computer`, `ControllerType`, `AgentVersion`, `ClusterId`, `Region`

#### 4. Anti-Patterns to Avoid

- Do NOT log sensitive data (credentials, tokens, PII)
- Do NOT add telemetry inside tight loops
- Do NOT use `puts`/`print`/`fmt.Println` for production telemetry — use ApplicationInsights SDK
- Do NOT create new TelemetryClient instances — use the shared singleton
- Do NOT emit telemetry in unit test code paths (respect `GOUNITTEST`/`ISTEST` guards)
- Do NOT hardcode instrumentation keys — use `APPLICATIONINSIGHTS_AUTH` env var

### Validation
- Telemetry import matches existing files in the same module
- Metric/event names follow the repo's naming convention
- Dimensions match the standard set
- Unit tests pass (telemetry gated for test environments)
