# Feature Development

## Description
Add new features to the monitoring agent — new data collection, new cloud support, new authentication methods, or new log streams.

USE FOR: add feature, implement, new endpoint, new plugin, enable support, new stream, add auth method
DO NOT USE FOR: bug fixes, refactoring, documentation-only changes

## Instructions

### When to Apply
When adding a new data collection capability, supporting a new cloud environment, implementing a new authentication method, or adding a new log/metric stream.

### Step-by-Step Procedure
1. Determine which component needs changes:
   - New Kubernetes data collection → Ruby Fluentd plugin in `source/plugins/ruby/`
   - New Fluent Bit output/processing → Go plugin in `source/plugins/go/src/`
   - New cloud environment support → `kubernetes/linux/main.sh`, `kubernetes/windows/main.ps1`, and unit test functions
   - New configuration options → `build/common/installer/scripts/tomlparser*.rb`
2. Implement the feature following existing patterns in the codebase.
3. Add unit tests:
   - Ruby: `*_test.rb` co-located with the plugin
   - Go: `*_test.go` in the same package
   - Bash/PowerShell: test cases in `test/unit-tests/test_cases/`
4. Update liveness probe if the feature affects agent health: `build/linux/installer/scripts/livenessprobe.sh`
5. Update Helm chart templates if new configuration options are added: `charts/azuremonitor-containers/templates/`
6. Update onboarding templates if applicable: `scripts/onboarding/`
7. Run all unit test suites before submitting PR.

### Files Typically Involved
- `source/plugins/ruby/in_kube_*.rb` — Fluentd input plugins
- `source/plugins/go/src/*.go` — Fluent Bit Go plugin
- `kubernetes/linux/main.sh` — Container startup logic
- `kubernetes/windows/main.ps1` — Windows container startup
- `charts/azuremonitor-containers/templates/ama-logs.yaml` — Helm template
- `test/unit-tests/test_cases/` — Unit test cases
- `test/unit-tests/test_functions/` — Functions under test

### Validation
- All unit test suites pass
- Docker image builds successfully
- Helm chart renders correctly: `helm template charts/azuremonitor-containers/`
- CI checks pass on PR

## Examples from This Repo
- `fb8011ca5` — Enabled OTel logs and traces support (#1527)
- `089b05960` — Added FIC auth support (#1539)
- `c02975eec` — Adding change for networkflow logs new stream (#1551)

## References
- `source/plugins/ruby/` — Ruby plugin patterns
- `source/plugins/go/src/` — Go plugin patterns
- `charts/azuremonitor-containers/` — Helm chart
