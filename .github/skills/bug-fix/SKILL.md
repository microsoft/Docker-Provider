# Bug Fix

## Description
Fix bugs in the Docker-Provider agent with proper regression testing.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix, resolve crash
DO NOT USE FOR: feature development, refactoring, performance optimization

## Instructions

### When to Apply
When a bug is reported or discovered in the agent's log collection, metric forwarding, Kubernetes inventory, or container startup behavior.

### Step-by-Step Procedure
1. **Reproduce the issue:**
   - Check if the bug is in Ruby plugins (`source/plugins/ruby/`), Go plugin (`source/plugins/go/src/`), or shell scripts (`build/`, `kubernetes/`)
   - For Ruby: Run `ruby test/unit-tests/test_driver.rb` to check existing tests
   - For Go: Run `cd source/plugins/go/src && go test ./...` to check existing tests

2. **Write a regression test FIRST:**
   - Ruby: Add test in the corresponding `*_test.rb` file
   - Go: Add test in the corresponding `*_test.go` file
   - Shell: Add test case in `test/unit-tests/test_cases/`

3. **Implement the fix:**
   - Follow existing error handling patterns
   - Add telemetry for the error path if missing

4. **Verify the fix:**
   - Run unit tests: `./test/unit-tests/test_main.sh`
   - For Go: `cd source/plugins/go/src && go test -race ./...`
   - Build Docker image if infrastructure changes involved

### Files Typically Involved
- `source/plugins/ruby/*.rb` — Ruby plugin fixes
- `source/plugins/go/src/*.go` — Go plugin fixes
- `build/linux/installer/scripts/*.sh` — Installer/startup script fixes
- `kubernetes/linux/main.sh` — Container entry point fixes
- `test/unit-tests/` — Regression tests

### Validation
- Regression test fails without the fix, passes with it
- All existing unit tests pass
- Docker image builds successfully

## Examples from This Repo
- `5c0bca0bb` — bug fix (#1593)
- `fbcc3de37` — fix bug (#1577)
- `41e880633` — fix amaca liveness probe issue in high scale mode
