# Telemetry Authoring

## Description
Add Application Insights telemetry following the existing patterns in the Container Insights agent codebase.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add logging, add Application Insights
DO NOT USE FOR: fixing broken telemetry pipelines, configuring Fluent Bit/Fluentd infrastructure, dashboard creation, alert rule authoring

## Instructions

### When to Apply
When adding new code paths, error handlers, external calls, or entry points that need observability instrumentation.

### Step-by-Step Procedure

1. **Identify the telemetry SDK** for the language:
   - **Go**: `github.com/microsoft/ApplicationInsights-Go/appinsights` — singleton `TelemetryClient` in `source/plugins/go/src/telemetry.go`
   - **Ruby**: Custom `ApplicationInsightsUtility` module in `source/plugins/ruby/ApplicationInsightsUtility.rb`

2. **Sample existing telemetry** in neighboring code. In Go, look at `telemetry.go`:
   - `TelemetryClient.Track(...)` for metrics
   - `TelemetryClient.TrackException(...)` for errors
   - `CommonProperties` map for standard dimensions

3. **Add telemetry** following these priorities:
   a. **Error paths** — Every `if err != nil` that represents an unexpected failure:
      ```go
      TelemetryClient.TrackException(appinsights.NewExceptionTelemetry(err))
      ```
   b. **Entry points** — New plugin callbacks, HTTP handlers:
      - Track operation name, duration, success/failure
   c. **External calls** — Kubernetes API calls, Azure endpoint calls:
      - Track target, duration, response status
   d. **Business logic** — State transitions, processing milestones:
      - Use custom events with relevant properties

4. **Follow naming conventions**:
   - Metrics: Descriptive PascalCase (e.g., `FlushedRecordsCount`, `NetworkFlowLogsFlushedSize`)
   - Standard dimensions always include: `computer`/hostname, `controller_type`, cluster info from `CommonProperties`

5. **Anti-patterns to avoid**:
   - Do NOT use `fmt.Println` or `puts` for production telemetry
   - Do NOT create new `TelemetryClient` instances — reuse the singleton
   - Do NOT emit telemetry in tight loops
   - Do NOT log sensitive data (keys, tokens, PII) in telemetry properties
   - Do NOT emit telemetry in test code paths — respect `GOUNITTEST`/`ISTEST` guards

### Files Typically Involved
- `source/plugins/go/src/telemetry.go` — Telemetry initialization, TelemetryClient, CommonProperties
- `source/plugins/go/src/oms.go` — Main output plugin telemetry
- `source/plugins/go/src/network_flow_logs.go` — Network flow telemetry
- `source/plugins/ruby/ApplicationInsightsUtility.rb` — Ruby telemetry utility

### Validation
- Verify import matches existing files: `"github.com/microsoft/ApplicationInsights-Go/appinsights"`
- Verify metric/event names follow PascalCase convention
- Verify `CommonProperties` are included in telemetry items
- Run `GOUNITTEST=true ISTEST=true go test .` to ensure telemetry doesn't break tests
- Check that telemetry is gated for unit test environments

## Examples from This Repo
- `telemetry.go`: `FlushedRecordsCount`, `FlushedRecordsSize`, `FlushedRecordsTimeTaken` metrics
- `network_flow_logs.go`: `NetworkFlowLogsFlushedCount`, `NetworkFlowLogsFlushedSize` metrics
- Ruby: `ApplicationInsightsUtility.rb` utility methods for tracking events
