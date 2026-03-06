# Telemetry Authoring

## Description
Guide for adding telemetry instrumentation following the existing Application Insights patterns in the Docker-Provider agent.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring telemetry infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply
When adding new code paths, error handling, or features that need observability instrumentation.

### Step-by-Step Procedure

#### 1. Telemetry Pattern Discovery
Before adding telemetry, identify the existing pattern in the relevant language:

**Ruby — uses `ApplicationInsightsUtility` wrapper:**
```ruby
require_relative "ApplicationInsightsUtility"

# Track exceptions
ApplicationInsightsUtility.sendExceptionTelemetry(e)

# Track custom events
ApplicationInsightsUtility.sendCustomEvent("EventName", {"property" => "value"})

# Track metrics
ApplicationInsightsUtility.sendMetricTelemetry("metricName", metricValue, {})
```

**Go — uses `appinsights` SDK directly:**
```go
import "github.com/microsoft/ApplicationInsights-Go/appinsights"

// Track events (see telemetry.go for initialization pattern)
telemetryClient.TrackEvent("EventName")

// Track metrics
telemetryClient.TrackMetric("metricName", value)

// Track exceptions
telemetryClient.TrackException(err)
```

#### 2. What to Instrument (priority order)

a. **Error paths** — every `rescue`/`if err != nil` for unexpected failures:
   - Include: error type, message, operation context
   - Ruby: `ApplicationInsightsUtility.sendExceptionTelemetry(e)`
   - Go: `SendException(err)` or `telemetryClient.TrackException(err)`

b. **Entry points** (new plugins, handlers):
   - Track operation name, duration, success/failure
   - Ruby: Use timer pattern from existing plugins (e.g., `in_kube_perfinventory.rb`)
   - Go: Track in `FLBPluginFlush` pattern (see `oms.go`)

c. **External calls** (Kubernetes API, Azure endpoints):
   - Track target, duration, status code
   - Ruby: Wrap with `begin/rescue` and send telemetry on failure
   - Go: Log and track with `appinsights`

d. **Custom metrics** (counters, gauges):
   - Follow naming: `<component>.<operation>.<measurement>` (e.g., `container_logs.flush.count`)
   - Standard properties: `Computer`, `ControllerType`, `AgentVersion`

#### 3. Standard Dimensions
Always include these properties when available:
- `Computer` / hostname
- `ControllerType` (`DaemonSet`/`ReplicaSet`)
- `AgentVersion` (from `AGENT_VERSION` env var)
- `ClusterId` (from `AKS_RESOURCE_ID` env var)

#### 4. Anti-Patterns to Avoid
- Do NOT log sensitive data (keys, tokens, PII, request bodies)
- Do NOT add telemetry inside tight loops
- Do NOT use `puts`/`print`/`fmt.Println` for production telemetry
- Do NOT create new TelemetryClient instances — reuse existing ones
- Do NOT hardcode instrumentation keys — use `APPLICATIONINSIGHTS_AUTH` env var
- Respect `$in_unit_test` / `GOUNITTEST` guards in test environments

### Validation
- Telemetry import matches existing files
- Metric/event names follow repo naming conventions
- Standard dimensions included
- Unit tests pass (telemetry doesn't break test isolation)

## References
- `source/plugins/ruby/ApplicationInsightsUtility.rb` — Ruby telemetry wrapper
- `source/plugins/go/src/telemetry.go` — Go telemetry initialization and patterns
- `source/plugins/go/input/lib/applicationinsights.go` — Go input plugin telemetry
