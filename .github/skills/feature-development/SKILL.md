# Feature Development

## Description
Add new features to the Docker-Provider agent following established patterns.

USE FOR: add feature, implement, new plugin, new data stream, enable support, add integration
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding new data collection capabilities, new cloud support, new authentication methods, or new agent functionality.

### Step-by-Step Procedure
1. **Plan the feature scope:**
   - Determine if it affects DaemonSet (per-node), ReplicaSet (per-cluster), or both
   - Determine if it needs Linux only, Windows only, or both platforms
   - Identify which plugin layer: Ruby input/filter, Go output, Telegraf, or Fluent Bit config

2. **Implement following existing patterns:**
   - **New Ruby plugin**: Follow `source/plugins/ruby/in_kube_*.rb` pattern — register with Fluent Bit, implement `configure`/`start`/`shutdown`
   - **New Go functionality**: Add to `source/plugins/go/src/` — follow `out_oms.go` patterns for output, update `Makefile`
   - **New configuration**: Add ConfigMap parsing in `build/common/installer/scripts/` — Ruby for parsing, shell for environment setup
   - **New environment variable**: Document in `kubernetes/linux/main.sh` and `kubernetes/windows/main.ps1`

3. **Add telemetry:**
   - Use `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go)
   - Track: feature enablement, success/failure counts, error details
   - Gate with `$in_unit_test` (Ruby) for test isolation

4. **Add tests:**
   - Unit tests alongside the feature code
   - Update E2E tests in `test/ginkgo-e2e/` if the feature produces new Log Analytics tables

5. **Update configuration:**
   - Update `build/linux/installer/conf/` for Fluent Bit config changes
   - Update Helm chart values if the feature is user-configurable

### Files Typically Involved
- `source/plugins/ruby/` — New Ruby plugins
- `source/plugins/go/src/` — Go plugin changes
- `build/common/installer/scripts/` — ConfigMap parsing
- `build/linux/installer/conf/` — Fluent Bit configuration
- `kubernetes/linux/main.sh` — Entry point updates
- `charts/azuremonitor-containers/` — Helm chart updates
- `test/` — Test additions

### Validation
- Unit tests pass for new code
- Docker image builds and starts successfully
- Feature can be enabled/disabled via ConfigMap or environment variable
- Telemetry emits for feature operations

## Examples from This Repo
- `fb8011ca5` — Enabled OTel logs and traces support
- `c02975eec` — Adding change for networkflow logs new stream
- `089b05960` — Added FIC auth support
