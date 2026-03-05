# Bug Fix

## Description
Guides structured bug fixing with proper testing and validation for the container monitoring agent.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix
DO NOT USE FOR: feature development, refactoring, performance optimization

## Instructions

### When to Apply
When fixing incorrect behavior in Ruby Fluentd plugins, Go Fluent Bit plugins, shell scripts, or PowerShell scripts.

### Step-by-Step Procedure
1. Identify the affected component: Ruby plugin (`source/plugins/ruby/`), Go plugin (`source/plugins/go/`), startup script (`kubernetes/linux/main.sh`), or configuration
2. Reproduce the issue — check logs, telemetry events, or Kubernetes API responses
3. Implement the fix following existing code conventions for that language
4. Add or update a regression test:
   - Go: add test case in `*_test.go` alongside the source file
   - Ruby: add test in `*_test.rb` alongside the plugin
   - Bash: add test case in `test/unit-tests/test_cases/`
   - PowerShell: add `Test-*.ps1` in `test/unit-tests/test_cases/`
5. Run the full test suite for the affected language
6. If the fix involves Kubernetes API calls, verify with Ginkgo E2E tests if applicable

### Files Typically Involved
- `source/plugins/ruby/*.rb` — Ruby Fluentd plugins
- `source/plugins/go/src/*.go` — Go Fluent Bit plugin
- `kubernetes/linux/main.sh` — Linux startup script
- `kubernetes/windows/main.ps1` — Windows startup script
- `build/linux/installer/scripts/*.rb` — Installer scripts
- `charts/*/templates/*.yaml` — Helm chart templates

### Validation
- Run applicable unit test suite
- `./test/unit-tests/test_main.sh` for Bash changes
- Trivy scan still passes on PR

## Examples from This Repo
- `5c0bca0bb` — bug fix in `in_kube_podinventory.rb`
- `fbcc3de37` — fix bug in `in_kube_events.rb`
- `41e880633` — fix amaca liveness probe issue in high scale mode

## References
- `test/unit-tests/README.md` — test framework documentation
- `.github/workflows/run_unit_tests.yml` — CI test pipeline
