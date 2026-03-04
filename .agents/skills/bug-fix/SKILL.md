# Bug Fix

## Description
Fix bugs in the monitoring agent — Ruby plugins, Go plugins, shell scripts, or configuration.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix, liveness probe fix
DO NOT USE FOR: feature development, refactoring, performance optimization, CVE fixes

## Instructions

### When to Apply
When a runtime error, data collection failure, incorrect behavior, or crash is reported in the monitoring agent.

### Step-by-Step Procedure
1. Identify the affected component (Ruby plugin, Go plugin, shell script, PowerShell script).
2. Reproduce the issue if possible using unit tests or local container build.
3. Fix the bug in the source file.
4. Add or update unit tests to cover the regression:
   - Ruby: add test in `source/plugins/ruby/*_test.rb`
   - Go: add test in `source/plugins/go/src/*_test.go`
   - Bash: add test in `test/unit-tests/test_cases/`
   - PowerShell: add test in `test/unit-tests/test_cases/`
5. Run the relevant unit test suite to verify the fix.
6. If the fix affects container behavior, test with a Docker image build.

### Files Typically Involved
- `source/plugins/ruby/*.rb` (Ruby plugin fixes)
- `source/plugins/go/src/*.go` (Go plugin fixes)
- `kubernetes/linux/main.sh` (container startup fixes)
- `kubernetes/windows/main.ps1` (Windows container fixes)
- `build/linux/installer/scripts/livenessprobe.sh` (liveness probe fixes)

### Validation
- Relevant unit test suite passes
- `./test/unit-tests/test_main.sh` (Bash tests)
- `./test/unit-tests/run_go_tests.sh` (Go tests)
- `./test/unit-tests/run_ruby_tests.sh` (Ruby tests)
- CI `run_unit_tests.yml` passes

## Examples from This Repo
- `5c0bca0bb` — bug fix (#1593) — Ruby pod inventory fix
- `fbcc3de37` — fix bug (#1577) — Ruby kube events fix
- `41e880633` — fix amaca liveness probe issue in high scale mode (#1530)

## References
- `source/plugins/ruby/` — Ruby plugin source
- `source/plugins/go/src/` — Go plugin source
- `test/unit-tests/` — Unit test suites
