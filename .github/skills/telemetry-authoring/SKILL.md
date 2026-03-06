# Telemetry Authoring

## Purpose
Guide adding Application Insights telemetry to new or modified code in the Docker-Provider repository, following the existing telemetry patterns established by the Ruby `ApplicationInsightsUtility` class and Go `appinsights` SDK.

USE FOR: add telemetry, add metrics, add tracing, add observability, instrument code, track event, emit metric, add Application Insights, telemetry gap, missing telemetry
DO NOT USE FOR: fixing broken telemetry pipelines, configuring Fluent Bit infrastructure, dashboard creation, alert rule authoring

## When to Use
- When adding new Ruby Fluentd plugins or Go Fluent Bit plugins
- When adding new error handling paths that should report exceptions
- When adding new entry points (HTTP handlers, scheduled tasks, plugin lifecycle methods)
- When code review identifies telemetry gaps

## Inputs
- The file(s) being modified and their language (Ruby or Go)
- The component type (input plugin, output plugin, filter, utility)
- The specific code paths that need telemetry

## Outputs
- Telemetry instrumentation code added to the specified files
- Consistent with existing patterns in neighboring files

## Steps

1. **Identify the telemetry SDK for the language:**
   - **Ruby:** Use `ApplicationInsightsUtility` class from `source/plugins/ruby/ApplicationInsightsUtility.rb`
   - **Go:** Use `appinsights` package from `github.com/microsoft/ApplicationInsights-Go/appinsights`

2. **Sample existing telemetry patterns** — Read 3-5 files in the same directory that already have telemetry:
   - Ruby: Look for `ApplicationInsightsUtility.sendExceptionTelemetry`, `sendCustomEvent`, `sendMetricTelemetry`
   - Go: Look for `TelemetryClient.TrackMetric`, `TelemetryClient.TrackEvent`, `TelemetryClient.TrackException`

3. **Add error path telemetry** (highest priority):
   - Ruby: In every `rescue` block that represents an unexpected failure:
     ```ruby
     ApplicationInsightsUtility.sendExceptionTelemetry(e)
     ```
   - Go: In every `if err != nil` block:
     ```go
     SendException(err)
     ```

4. **Add entry point telemetry:**
   - Ruby: In `configure`/`start`/`emit`/`filter` lifecycle methods, track operation start and duration
   - Go: In plugin `FLBPluginFlush*` functions, track flush counts, sizes, and durations

5. **Add standard dimensions to all telemetry:**
   - Ruby: `Computer` (hostname), `ControllerType` (DaemonSet/ReplicaSet), `AgentVersion`
   - Go: `CommonProperties` map with Computer, ControllerType, AgentVersion, ClusterId

6. **Gate telemetry for test environments:**
   - Ruby: Check `$in_unit_test` before sending telemetry
   - Go: Check `GOUNITTEST` environment variable

7. **Follow naming conventions:**
   - Metric names: `<component>.<operation>.<measurement>` (e.g., `containerlog.flush.count`)
   - Event names: `<ComponentAction>` (e.g., `ContainerLogFlushed`, `InventoryCollected`)
   - Exception events: Use the SDK's exception tracking method, not custom events

## Validation
- Verify telemetry import/require matches existing files in the same directory
- Verify metric/event names follow the naming convention used by neighboring files
- Run unit tests to ensure telemetry additions don't break test isolation
- Verify `$in_unit_test` / `GOUNITTEST` gating is in place

## Risks and Guardrails
- Do NOT log sensitive data (credentials, tokens, PII, request bodies)
- Do NOT add telemetry inside tight loops (will generate excessive volume)
- Do NOT use `puts`/`fmt.Println` for production telemetry — use the structured SDK
- Do NOT create new TelemetryClient instances — reuse the existing singleton
- Do NOT hardcode instrumentation keys — use env vars (`APPLICATIONINSIGHTS_AUTH`)

## References
- `source/plugins/ruby/ApplicationInsightsUtility.rb` — Ruby telemetry helper
- `source/plugins/go/src/telemetry.go` — Go telemetry implementation
- `source/plugins/go/input/lib/applicationinsights.go` — Go input plugin telemetry
