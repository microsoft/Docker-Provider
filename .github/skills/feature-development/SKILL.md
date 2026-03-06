# Feature Development

## Description
Scaffold and implement new features for the Container Insights agent.

USE FOR: add feature, implement, new plugin, new data source, new endpoint, new component
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding new data collection capabilities, new authentication modes, new deployment targets, or new configuration options.

### Step-by-Step Procedure

1. **Plan the feature**:
   - Determine which component needs changes (Go plugin, Ruby plugin, both, infrastructure)
   - Identify if both Linux and Windows are affected
   - Check if Helm chart values need updating

2. **Implement source code**:
   - **Go plugin changes**: Add/modify files in `source/plugins/go/src/` or `source/plugins/go/input/`
   - **Ruby plugin changes**: Add/modify files in `source/plugins/ruby/`
   - **Configuration parsing**: Update scripts in `build/common/installer/scripts/`
   - Follow existing patterns — look at recent feature PRs for the pattern

3. **Add configuration support** (if needed):
   - ConfigMap parsing in `build/common/installer/scripts/`
   - Helm chart values in `charts/azuremonitor-containers/values.yaml`
   - Environment variables in `kubernetes/linux/main.sh` and/or `kubernetes/windows/main.ps1`

4. **Add telemetry**:
   - New code paths must emit Application Insights telemetry
   - Follow `telemetry-authoring` skill for conventions

5. **Add tests**:
   - Go unit tests: `source/plugins/go/src/*_test.go`
   - Bash unit tests: `test/unit-tests/test_cases/test_*.sh`
   - E2E tests if applicable: `test/ginkgo-e2e/` or `test/e2e/`

6. **Update Dockerfiles** (if new dependencies):
   - `kubernetes/linux/Dockerfile.multiarch`
   - `kubernetes/windows/Dockerfile` (if Windows affected)

7. **Run full test suite**:
   ```bash
   cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test . && cd ../../../..
   ./test/unit-tests/test_main.sh
   ruby test/unit-tests/test_driver.rb
   cd build/linux && make && cd ../..
   ```

### Files Typically Involved
- `source/plugins/go/src/` — Go plugin code
- `source/plugins/go/input/` — Input plugin code
- `source/plugins/ruby/` — Ruby plugin code
- `build/common/installer/scripts/` — Config parsing
- `charts/azuremonitor-containers/` — Helm charts
- `kubernetes/linux/main.sh` — Startup configuration
- `kubernetes/ama-logs.yaml` — Kubernetes manifest

### Validation
- All unit tests pass
- Build succeeds for Linux (and Windows if affected)
- Docker image builds successfully
- Trivy scan passes
- Feature works in a test Kubernetes cluster (manual verification)

## Examples from This Repo
- `Added FIC auth support (#1539)` — New authentication mode
- `Enabled OTel logs and traces support (#1527)` — New data source support
- `Add high logs scale support for ARC (#1491)` — New deployment mode
- `Adding change for networkflow logs new stream (#1551)` — New data stream
- `Multi-tenant support for ARC (#1506)` — New multi-tenant feature
