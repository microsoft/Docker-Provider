# Feature Development

## Description
Guides adding new features to the Container Insights agent — new data streams, new plugin capabilities, new monitoring support.

USE FOR: add feature, implement, new plugin, new data stream, new endpoint, new monitoring capability
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding new data collection capabilities, new output destinations, new Kubernetes resource monitoring, or new cloud environment support.

### Step-by-Step Procedure
1. **Plan** — Determine which component(s) need changes:
   - New data stream → Ruby input plugin + Go output plugin support + MDSD config
   - New metric → Ruby/Go plugin + Telegraf config
   - New environment support → Shell/PowerShell scripts + environment detection logic
2. **Implement the plugin** — Follow existing patterns:
   - Ruby input plugin: model after `source/plugins/ruby/in_kube_nodes.rb` pattern
   - Go output support: add data type constant in `source/plugins/go/src/oms.go`
   - Filter plugin: model after `source/plugins/ruby/filter_inventory2mdm.rb`
3. **Add configuration support** — Update ConfigMap handling if the feature is configurable:
   - `kubernetes/container-azm-ms-agentconfig.yaml` for user config
4. **Add telemetry** — Instrument the new code path:
   - Ruby: use `ApplicationInsightsUtility.sendCustomEvent` / `sendMetricTelemetry`
   - Go: use `TelemetryClient.TrackMetric` / `TelemetryClient.TrackEvent`
5. **Add tests** — Write unit tests for the new functionality.
6. **Update Helm charts** if new environment variables or mounts are needed:
   - Charts in `charts/azuremonitor-containers/`
7. **Run all test suites** to verify no regressions.

### Files Typically Involved
- `source/plugins/ruby/in_*.rb` — New input plugins
- `source/plugins/ruby/filter_*.rb` — New filter plugins
- `source/plugins/go/src/oms.go` — Data type constants and output routing
- `source/plugins/ruby/constants.rb` — New constants
- `kubernetes/linux/main.sh` — Startup configuration
- `charts/` — Helm chart values and templates

### Validation
- All unit tests pass
- New feature has dedicated unit tests
- Telemetry instrumentation covers success and error paths
- Container image builds with new feature

## Examples from This Repo
- `c02975eec` — Adding change for networkflow logs new stream (#1551)
- `fb8011ca5` — Enabled OTel logs and traces support (#1527)
- `c9f5dfa83` — Add private link support for high log scale (#1512)
