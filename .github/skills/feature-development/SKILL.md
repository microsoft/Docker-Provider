# Feature Development

## Description
Guides the agent through adding new features to the container monitoring agent, including plugin development, configuration, and testing.

USE FOR: add feature, implement, new plugin, new data type, new stream, create, new endpoint
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding new monitoring capabilities, new data streams, new plugin functionality, or new configuration options.

### Step-by-Step Procedure
1. Determine the feature scope and which component(s) to modify:
   - New data collection → Ruby input plugin (`source/plugins/ruby/in_*.rb`)
   - New data transformation → Ruby filter plugin (`source/plugins/ruby/filter_*.rb`)
   - New output destination → Go output plugin (`source/plugins/go/src/`)
   - New configuration option → ConfigMap parser (`build/common/installer/scripts/`)
2. Follow existing plugin patterns:
   - Ruby: extend `Fluent::Input`/`Fluent::Filter`/`Fluent::Output`, register with `Fluent::Plugin.register_*`
   - Go: add data type constants, implement flush logic following `oms.go` patterns
3. Add telemetry for the new feature:
   - Ruby: use `ApplicationInsightsUtility.sendCustomEvent` / `sendMetricTelemetry`
   - Go: use `SendEvent` with appropriate dimensions
4. Add configuration via environment variables (follow `AZMON_*` naming convention).
5. Update Helm chart `values.yaml` if new configuration parameters are needed.
6. Write unit tests for the new functionality.
7. Update `kubernetes/linux/Dockerfile.multiarch` and/or `kubernetes/windows/Dockerfile` if new build dependencies are required.

### Files Typically Involved
- `source/plugins/ruby/in_*.rb` — new input plugins
- `source/plugins/go/src/oms.go` — output plugin modifications
- `source/plugins/go/src/telemetry.go` — telemetry additions
- `build/common/installer/scripts/` — ConfigMap parsing
- `charts/azuremonitor-containers/values.yaml` — Helm chart configuration
- `kubernetes/linux/main.sh` — startup script updates

### Validation
- All unit tests pass including new tests
- Feature works with both DaemonSet and ReplicaSet controllers where applicable
- Telemetry emits correctly for new feature paths
- Helm chart values are documented

## Examples from This Repo
- `Adding change for networkflow logs new stream (#1551)` — new data stream
- `Added FIC auth support (#1539)` — new authentication feature
- `OTLP optimize telemetry (#1545)` — telemetry feature optimization
- `Gangams/workload identity geneva (#1543)` — workload identity support

## References
- `source/plugins/ruby/` — existing Ruby plugin patterns
- `source/plugins/go/src/oms.go` — Go output plugin pattern
