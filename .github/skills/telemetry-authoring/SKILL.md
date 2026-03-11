# Skill: Telemetry Authoring

## Overview
Add and modify telemetry instrumentation in the Docker-Provider monitoring agent. Telemetry is sent via Application Insights (Go SDK and Ruby utility) and optionally forwarded to MDSD for Geneva metrics. All telemetry code must be safe for unit testing and follow established naming conventions.

## Telemetry Stack
- **Go**: `github.com/microsoft/ApplicationInsights-Go v0.4.4` — direct SDK usage
- **Ruby**: `ApplicationInsightsUtility` wrapper class (`source/plugins/ruby/ApplicationInsightsUtility.rb`)
- **MDSD/Geneva**: Metrics forwarded via MDSD for Azure Monitor pipeline integration
- **Instrumentation key**: `APPLICATIONINSIGHTS_AUTH` environment variable (base64-encoded)

## Go Telemetry Patterns

### Initialization
The telemetry client is initialized in `source/plugins/go/src/telemetry.go`:
```go
func InitializeTelemetryClient(agentVersion string) (int, error)
```
This decodes `APPLICATIONINSIGHTS_AUTH` and sets up the singleton `TelemetryClient`. Do not create additional clients.

### Sending Metrics
```go
SendMetric("FlushedRecordsCount", float64(count), map[string]string{
    "Computer":       hostname,
    "ControllerType": controllerType,
})
```
Use `SendMetric(metricName, value, dimensions)` for numeric measurements. Always include standard dimensions.

### Sending Events
```go
SendEvent("ContainerLogPluginStarted", map[string]string{
    "AgentVersion":   agentVersion,
    "ControllerType": controllerType,
})
```
Use `SendEvent(eventName, dimensions)` for discrete occurrences.

### Error Reporting
```go
SendException(err)
```
Call `SendException()` for all unrecoverable errors and panics. This calls `TelemetryClient.TrackException()`. Prefer this over silently logging errors.

### Logging
```go
Log("Processing %d records for container %s", count, containerID)
```
`Log()` writes to stderr with a consistent format. Use for operational logging, not telemetry. Do not use `fmt.Printf` or `log.Printf` directly.

### Periodic Telemetry
`SendContainerLogPluginMetrics()` and `SendTracesAsMetrics()` run as goroutines, flushing batched metrics at configurable intervals. When adding new periodic metrics:
1. Define a package-level counter/gauge variable
2. Update it atomically from the hot path
3. Read and reset it in the flush goroutine
4. Use appropriate mutex (e.g., `TracesErrorMetricsMutex`) for thread safety

## Ruby Telemetry Patterns

### Sending Custom Events
```ruby
ApplicationInsightsUtility.sendCustomEvent(
  "KubePerfInventoryHeartbeat",
  {"Computer" => hostname, "ControllerType" => controller_type}
)
```

### Sending Metrics
```ruby
ApplicationInsightsUtility.sendMetricTelemetry(
  "PodCount",
  pod_count,
  {"Computer" => hostname}
)
```

### Sending Exceptions
```ruby
ApplicationInsightsUtility.sendExceptionTelemetry(error.message, {"Source" => "in_kube_perfinventory"})
```

### Structured Logging
```ruby
$log.info "Successfully collected #{count} pod inventory records"
$log.warn "Failed to parse container log: #{error.message}"
$log.error "Kubernetes API returned #{response.code}"
```
Use `$log` (Fluentd logger) for all operational logging. Never use `puts` or `print` — these bypass log routing and formatting.

### Unit Test Guards
Telemetry calls must be gated in test contexts:
```ruby
if !$in_unit_test
  ApplicationInsightsUtility.sendCustomEvent("EventName", properties)
end
```
This prevents test runs from sending real telemetry. Always wrap telemetry calls with this guard in code paths exercised by unit tests.

## Naming Conventions
- **Metric names**: `PascalCase` descriptive names (e.g., `FlushedRecordsCount`, `AgentLogProcessingMaxLatencyMs`, `TelegrafMetricsSentCount`)
- **Event names**: `PascalCase` with component prefix (e.g., `ContainerLogPluginStarted`, `KubePerfInventoryHeartbeat`)
- **Dimension keys**: `PascalCase` (e.g., `Computer`, `ControllerType`, `ContainerType`)

## Standard Dimensions
Include these dimensions on all telemetry for correlation:

| Dimension | Source | Description |
|-----------|--------|-------------|
| `Computer` | Hostname / node name | Identifies the K8s node |
| `ControllerType` | `CONTROLLER_TYPE` env var | `DaemonSet` or `ReplicaSet` |
| `AgentVersion` | `AGENT_VERSION` env var | Agent version string |
| `ContainerType` | Runtime detection | Container runtime type |

Ruby `ApplicationInsightsUtility` automatically attaches: ID, Region, WSID, Version, Controller, Computer, WSCloud, Proxy, Container Runtime.

## MDSD / Geneva Integration
Some metrics are forwarded to MDSD for the Geneva metrics pipeline. The `SendTracesAsMetrics()` function in `telemetry.go` captures traces from:
- addon-token-adapter logs
- MDSD (Geneva) logs
- OTLP collector logs (including EPS metrics)

These are parsed and re-emitted as Application Insights metrics. When adding MDSD-routed metrics, ensure the metric name and dimensions match the Geneva metric definition.

## Anti-Patterns
1. **No `puts`/`print`/`fmt.Printf` for telemetry** — use the SDK wrappers (`SendMetric`, `SendEvent`, `$log`)
2. **Reuse the singleton client** — never call `InitializeTelemetryClient` more than once; use the existing `TelemetryClient`
3. **Gate telemetry in unit tests** — wrap with `$in_unit_test` (Ruby) or mock the client (Go)
4. **Don't log credentials** — never include `APPLICATIONINSIGHTS_AUTH` or connection strings in telemetry dimensions or log messages
5. **Don't send high-cardinality dimensions** — avoid pod IDs or container IDs as dimension values; aggregate at node or controller level
6. **Don't skip error telemetry** — every `rescue`/`recover` block should call `SendException` or `sendExceptionTelemetry`

## Validation Checklist
1. **Build**: `cd build/linux && make`
2. **Go unit tests**: `./test/unit-tests/run_go_tests.sh` — verify telemetry calls are mockable
3. **Ruby unit tests**: `ruby test/unit-tests/test_driver.rb` — verify `$in_unit_test` guards work
4. **Manual verification**: Deploy to test cluster, query Application Insights for new metric/event names
5. **Dimension review**: Confirm standard dimensions are present on all new telemetry
