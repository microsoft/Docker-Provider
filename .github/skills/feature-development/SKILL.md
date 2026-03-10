# Feature Development

## Description

Add new features to the Docker-Provider agent (new data streams, cloud support, authentication methods).

USE FOR: add feature, implement, new plugin, new data stream, new cloud support, new auth method
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply

When adding new data collection capabilities, cloud environment support, or agent functionality.

### Step-by-Step Procedure

1. **Plan:** Identify affected components and create implementation plan.
2. **Implement plugin code:**
   - Go output plugin changes: `source/plugins/go/src/`
   - Ruby input/filter plugins: `source/plugins/ruby/`
   - New environment support: Update cloud detection in `kubernetes/linux/main.sh`
3. **Update configuration:**
   - Add new ConfigMap options if needed (`container-azm-ms-agentconfig.yaml`)
   - Update Helm chart values and templates if deploying new resources
4. **Add tests:**
   - Unit tests per language (Go `*_test.go`, Bash test cases, Ruby tests)
   - E2E scenarios if user-facing (Python pytest or Go Ginkgo)
5. **Update documentation:** Release notes, README if architecture changes.
6. **Build and verify:** `cd build/linux && make`, run all test suites.

### Files Typically Involved

- `source/plugins/go/src/*.go` or `source/plugins/ruby/*.rb` — New plugin code
- `kubernetes/linux/main.sh` — Startup orchestration updates
- `charts/azuremonitor-containers/templates/` — Helm template updates
- `build/linux/installer/conf/` — Configuration file updates

### Validation

- Build succeeds for Linux and Windows, all unit tests pass, E2E tests pass.

## Examples from This Repo

- `fb8011ca5` — Enabled OTel logs and traces support (#1527)
- `089b05960` — Added FIC auth support (#1539)
- `c02975eec` — Adding change for networkflow logs new stream (#1551)
