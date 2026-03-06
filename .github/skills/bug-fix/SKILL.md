# Bug Fix

## Description
Fix bugs in the container monitoring agent following the repo's patterns for diagnosis, fix, and validation.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix, liveness probe fix
DO NOT USE FOR: feature development, refactoring, performance optimization, CVE dependency updates

## Instructions

### When to Apply
When a bug is reported or discovered in agent behavior — log collection issues, liveness probe failures, telemetry gaps, configuration parsing errors, or container startup failures.

### Step-by-Step Procedure
1. **Reproduce the issue** — Identify the affected component:
   - Go plugins: `source/plugins/go/src/` or `source/plugins/go/input/`
   - Ruby plugins: `source/plugins/ruby/`
   - Container setup: `kubernetes/linux/main.sh`, `kubernetes/linux/setup.sh`
   - Windows agent: `kubernetes/windows/main.ps1`

2. **Implement the fix** following existing patterns in the affected file.

3. **Add or update tests** — Bug fixes should include a regression test:
   - Go: Add test case in `source/plugins/go/src/*_test.go`
   - Ruby: Add test in `source/plugins/ruby/*_test.rb` or `test/unit-tests/test_driver.rb`
   - Bash: Add test in `test/unit-tests/test_cases/`
   - PowerShell: Add test in `test/unit-tests/test_cases/*.Tests.ps1`

4. **Run unit tests:**
   ```bash
   cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .
   ./test/unit-tests/run_ruby_tests.sh
   ./test/unit-tests/test_main.sh
   ```

5. **Build and verify:**
   ```bash
   cd build/linux && make
   ```

### Files Typically Involved
- `source/plugins/go/src/*.go` — Go plugin fixes
- `source/plugins/ruby/*.rb` — Ruby plugin fixes
- `kubernetes/linux/main.sh` — Container entrypoint fixes
- `kubernetes/linux/setup.sh` — Setup/install fixes

### Validation
- All unit tests pass (Go, Ruby, Bash, PowerShell)
- Linux build succeeds: `cd build/linux && make`
- Regression test added covering the bug scenario

## Examples from This Repo
- `fix amaca liveness probe issue in high scale mode (#1530)`
- `bug fix (#1593)`
- `fix bug (#1577)`
- `Fix FIC Auth support issues (#1547)`
