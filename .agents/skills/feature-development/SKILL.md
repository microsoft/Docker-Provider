# Feature Development

## Description
Guides adding new features to the container monitoring agent — new data streams, plugins, cloud support, or capabilities.

USE FOR: add feature, implement, new plugin, new data stream, add support, enable capability
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding new monitoring capabilities, supporting new cloud environments, adding new data streams, or implementing new Fluent Bit/Fluentd plugins.

### Step-by-Step Procedure
1. Determine the component type:
   - **New Go plugin**: Add to `source/plugins/go/src/` or `source/plugins/go/input/`
   - **New Ruby plugin**: Add to `source/plugins/ruby/` with `in_`/`out_`/`filter_` prefix
   - **New config/data stream**: Update onboarding templates in `scripts/onboarding/`
   - **New cloud environment**: Update environment detection in `main.sh`, `main.ps1`, and Ruby `ApplicationInsightsUtility.rb`
2. Follow existing patterns for the component type (sample 2-3 similar existing files)
3. Add telemetry using `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go)
4. Add unit tests alongside the source code
5. Update Helm chart values/templates if the feature requires config
6. Update Dockerfile if new dependencies are needed
7. Update `ReleaseNotes.md` with feature description

### Files Typically Involved
- `source/plugins/go/src/*.go` or `source/plugins/ruby/*.rb` — plugin source
- `kubernetes/linux/main.sh`, `kubernetes/windows/main.ps1` — startup scripts
- `charts/azuremonitor-containers/values.yaml` — chart configuration
- `scripts/onboarding/aks/` — onboarding templates (Bicep, Terraform, ARM)
- `build/linux/installer/conf/fluent-bit-*.conf` — Fluent Bit configuration

### Validation
- All unit tests pass
- Docker image builds successfully
- Helm chart renders with `helm template`
- Trivy scan passes

## Examples from This Repo
- `fb8011ca5` — Enabled OTel logs and traces support
- `c02975eec` — Adding change for networkflow logs new stream
- `089b05960` — Added FIC auth support

## References
- `source/plugins/go/src/oms.go` — main Go plugin entry point
- `source/plugins/ruby/in_kube_nodes.rb` — example Ruby input plugin
