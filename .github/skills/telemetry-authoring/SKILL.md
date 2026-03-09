# Telemetry Authoring Skill

## Name
telemetry-authoring

## Description
Add or modify telemetry instrumentation (metrics, events, traces, error reporting) in the Docker-Provider agent.

## Triggers
- "add telemetry", "add metrics", "instrument code", "add monitoring", "track event"

## Workflow

### 1. Identify Telemetry SDK

**Go plugins** (`source/plugins/go/src/`):
- SDK: `github.com/microsoft/ApplicationInsights-Go`
- Helper: `telemetry.go` — centralized telemetry functions
- Pattern: `SendCustomEvent()`, `SendMetricTelemetry()`, `SendExceptionTelemetry()`
- Connection: Uses `TELEMETRY_APPLICATIONINSIGHTS_KEY` environment variable

**Ruby plugins** (`source/plugins/ruby/`):
- Helper: `ApplicationInsightsUtility.rb`
- Pattern: `ApplicationInsightsUtility.sendMetricTelemetry(name, value, props)`
- Pattern: `ApplicationInsightsUtility.sendExceptionTelemetry(exception, props)`
- Pattern: `ApplicationInsightsUtility.sendCustomEvent(name, props)`

### 2. Naming Conventions
- **Metrics:** PascalCase descriptive name (e.g., `NetworkFlowLogsMDSDClientCreateErrors`)
- **Events:** PascalCase with action verb (e.g., `ContainerLogSent`, `IngestionTokenRefreshed`)
- **Custom dimensions:** Include `Cluster`, `Node`, `ControllerType`, `Region` where applicable

### 3. Standard Dimensions
All telemetry should include these dimensions where available:
| Dimension | Source | Description |
|-----------|--------|-------------|
| `Computer` | `HOSTNAME` env var | Node hostname |
| `ClusterName` | `CLUSTER` env var | Cluster identifier |
| `ControllerType` | `CONTROLLER_TYPE` env var | DaemonSet or ReplicaSet |
| `Region` | `AKSREGION` env var | Azure region |

### 4. Telemetry Gating
- Check `ISTEST` environment variable — skip telemetry in test mode
- Use `DISABLE_TELEMETRY` flag if available
- Rate-limit high-frequency metrics to avoid cost impact

### 5. Error Telemetry
- All error paths should report to telemetry with:
  - Exception type and message
  - Stack trace (if available)
  - Operation context (what was being attempted)
  - Relevant identifiers (cluster, node, container)

### 6. Validate
- Verify telemetry code compiles: `cd source/plugins/go/src && go build ./...`
- Run unit tests to ensure telemetry calls don't break existing behavior
- Check that telemetry properties don't contain PII or secrets

## Existing Telemetry Inventory
| Component | Has Telemetry | Type | Helper |
|-----------|--------------|------|--------|
| `out_oms.go` | Yes | Events, Errors | `telemetry.go` |
| `network_flow_logs.go` | Yes | Metrics, Errors | Direct counters |
| `ingestion_token_utils.go` | Yes | Events, Errors | `telemetry.go` |
| `in_kube_nodes.rb` | Yes | Metrics | `ApplicationInsightsUtility` |
| `in_kube_events.rb` | Yes | Metrics | `ApplicationInsightsUtility` |
| `in_kube_podinventory.rb` | Yes | Metrics | `ApplicationInsightsUtility` |
| `filter_cadvisor2mdm.rb` | Yes | Metrics | `ApplicationInsightsUtility` |
| `in_containerinventory.rb` | Yes | Metrics | `ApplicationInsightsUtility` |
