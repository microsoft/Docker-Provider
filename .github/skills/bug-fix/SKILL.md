# Bug Fix

## Description
Structured workflow for fixing bugs in the Container Insights agent codebase.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix
DO NOT USE FOR: feature development, refactoring, performance optimization

## Instructions

### When to Apply
When fixing a reported bug, resolving an issue, or patching incorrect behavior in any component.

### Step-by-Step Procedure

1. **Reproduce the issue** — Understand the bug:
   - Check which component is affected (Go output plugin, Ruby Fluentd plugin, shell scripts, Helm charts)
   - Identify the code path and triggering condition
   - Check existing tests for coverage gaps

2. **Locate the source**:
   - Go plugins: `source/plugins/go/src/` or `source/plugins/go/input/`
   - Ruby plugins: `source/plugins/ruby/`
   - Shell scripts: `build/*/installer/scripts/`, `kubernetes/linux/main.sh`
   - Helm charts: `charts/azuremonitor-containers/`

3. **Implement the fix**:
   - Make the minimal change needed to fix the issue
   - Follow existing code conventions for the language
   - Add error handling if the bug was caused by missing error checks

4. **Add a regression test**:
   - Go: Add test case in `source/plugins/go/src/*_test.go`
   - Bash: Add test in `test/unit-tests/test_cases/test_*.sh`
   - Ruby: Add test in `test/unit-tests/test_driver.rb`

5. **Run tests**:
   ```bash
   # Go tests
   cd source/plugins/go/src && go generate && GOUNITTEST=true ISTEST=true go test . && cd ../../../..
   # Bash tests
   ./test/unit-tests/test_main.sh
   # Ruby tests
   ruby test/unit-tests/test_driver.rb
   ```

6. **Build verification**:
   ```bash
   cd build/linux && make && cd ../..
   ```

### Files Typically Involved
- `source/plugins/go/src/` — Go plugin bug fixes
- `source/plugins/ruby/` — Ruby plugin bug fixes
- `build/*/installer/scripts/` — Script bug fixes
- `kubernetes/linux/main.sh` — Startup script fixes
- `charts/azuremonitor-containers/` — Helm chart fixes

### Validation
- Regression test added and passing
- All existing unit tests still pass
- Build succeeds
- No new Trivy findings introduced

## Examples from This Repo
- `bug fix (#1593)` — General bug fix
- `fix bug (#1577)` — Bug fix with PR reference
- `fix amaca liveness probe issue in high scale mode (#1530)` — Targeted component fix
- `Fix FIC Auth support issues (#1547)` — Auth-related bug fix
- `AMCS bug fix for Geneva (#1503)` — Service-specific bug fix
