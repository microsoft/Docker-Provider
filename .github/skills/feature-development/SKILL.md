# Feature Development

## Description
Guide for adding new features to the Docker-Provider container insights agent.

USE FOR: add feature, implement, new endpoint, new component, new module, create, add support, enable
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes, CVE fixes

## Instructions

### When to Apply
When adding new data collection capabilities, new log streams, new metric sources, new authentication methods, or new deployment modes.

### Step-by-Step Procedure
1. Understand the feature scope — which components are affected (Go plugins, Ruby plugins, config, deployment).
2. Plan the implementation: identify all files to create/modify.
3. For new Go plugins: create under `source/plugins/go/src/` or `source/plugins/go/input/`.
4. For new Ruby plugins: create under `source/plugins/ruby/`.
5. Update configuration files if needed (Fluent Bit conf, environment variables).
6. Add telemetry for the new feature using `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go).
7. Add unit tests for the new code.
8. Update deployment templates if the feature requires new configuration (Helm values, ARM parameters).
9. Build and test: `cd build/linux && make`, then run all unit tests.

### Files Typically Involved
- `source/plugins/go/src/*.go` — New Go plugins
- `source/plugins/ruby/*.rb` — New Ruby plugins
- `source/plugins/ruby/lib/` — Ruby utility libraries
- `kubernetes/linux/Dockerfile.multiarch` — If new build dependencies needed
- `charts/azuremonitor-containers/` — Helm chart values
- `deployment/` — ARM/Bicep/Terraform templates

### Validation
- Build succeeds
- New unit tests pass
- Existing tests still pass
- Docker image builds
- Telemetry added for new code paths

## Examples from This Repo
- `fb8011ca5` — Enabled OTel logs and traces support (#1527)
- `089b05960` — Added FIC auth support (#1539)
- `c02975eec` — Adding change for networkflow logs new stream (#1551)
- `c9f5dfa83` — Add private link support for high log scale (#1512)
