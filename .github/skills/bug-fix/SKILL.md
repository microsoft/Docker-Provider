# Bug Fix

## Description
Guides the agent through fixing bugs in the container agent codebase, including diagnosis, fix implementation, and regression testing.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix
DO NOT USE FOR: feature development, refactoring, performance optimization

## Instructions

### When to Apply
When addressing a reported bug, error condition, or unexpected behavior in the container agent.

### Step-by-Step Procedure
1. Identify the affected component:
   - Go output plugin: `source/plugins/go/src/`
   - Ruby Fluentd plugins: `source/plugins/ruby/`
   - Startup/setup scripts: `kubernetes/linux/`, `kubernetes/windows/`
   - Build infrastructure: `build/`
2. Reproduce the issue if possible using local tests or logs.
3. Implement the fix in the relevant source files.
4. Add or update a regression test covering the fixed behavior.
5. Run the appropriate unit test suite:
   - Go: `./test/unit-tests/run_go_tests.sh`
   - Ruby: `./test/unit-tests/run_ruby_tests.sh`
   - Bash: `./test/unit-tests/test_main.sh`
   - PowerShell: `./test/unit-tests/test_main.ps1`
6. Verify the fix does not introduce regressions in other test suites.
7. If the bug affects telemetry, verify error telemetry is emitted via `ApplicationInsightsUtility.sendExceptionTelemetry` (Ruby) or `SendEvent` (Go).

### Files Typically Involved
- `source/plugins/go/src/*.go` — Go plugin fixes
- `source/plugins/ruby/*.rb` — Ruby plugin fixes
- `kubernetes/linux/main.sh`, `kubernetes/linux/setup.sh` — startup script fixes
- `kubernetes/windows/main.ps1` — Windows agent fixes
- `build/common/installer/scripts/` — ConfigMap parsing fixes

### Validation
- All unit tests pass
- Regression test added for the specific bug
- No new warnings in CI

## Examples from This Repo
- `bug fix (#1593)` — general bug fix
- `fix bug (#1577)` — bug resolution
- `Fix FIC Auth support issues (#1547)` — auth-related fix
- `Fix testkube mongodb issue (#1584)` — test infrastructure fix

## References
- `test/unit-tests/` — unit test suites
- `.github/workflows/run_unit_tests.yml` — CI test configuration
