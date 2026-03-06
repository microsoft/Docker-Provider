# Feature Development

## Description
Guide for adding new features to the Docker-Provider agent (new data streams, plugins, or capabilities).

USE FOR: add feature, implement, new plugin, new data stream, new endpoint, new module
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding new data collection capabilities, new output destinations, or new operational features.

### Step-by-Step Procedure
1. **Design**: Determine the feature scope:
   - New Fluent Bit plugin? → Go code in `source/plugins/go/`
   - New Fluentd plugin? → Ruby code in `source/plugins/ruby/`
   - New container entrypoint logic? → Shell in `kubernetes/linux/` or PowerShell in `kubernetes/windows/`
2. **Create source files**:
   - Go plugins: add to `source/plugins/go/src/` or `source/plugins/go/input/`
   - Ruby plugins: add to `source/plugins/ruby/`, register with `Fluent::Plugin.register_*`
3. **Add configuration**: Update Fluent Bit/Fluentd config files in `kubernetes/linux/` as needed.
4. **Add telemetry**: Use `ApplicationInsightsUtility` (Ruby) or `appinsights` (Go) for tracking the new feature's operation.
5. **Add tests**: Create unit tests in the appropriate framework.
6. **Update Dockerfile** if new dependencies are needed.
7. **Update Helm chart values** if new configuration options are exposed.

### Files Typically Involved
- `source/plugins/go/src/` or `source/plugins/ruby/` — New plugin code
- `kubernetes/linux/setup.sh` or `kubernetes/linux/main.sh` — Entrypoint changes
- `charts/azuremonitor-containers/values.yaml` — Helm configuration
- `build/linux/Makefile` — Build system updates for new Go plugins

### Validation
- All unit test suites pass
- Docker image builds successfully
- New feature is gated by env var or config flag for safe rollout

## Examples from This Repo
- `c02975e` — Adding change for networkflow logs new stream (#1551)
- `089b095` — Added FIC auth support (#1539)
- `c9f5dfa` — Add private link support for high log scale (#1512)

## References
- `source/plugins/go/src/out_oms.go` — Go output plugin pattern
- `source/plugins/ruby/in_kube_perfinventory.rb` — Ruby input plugin pattern
