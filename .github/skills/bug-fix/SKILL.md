# Bug Fix

## Description
Structured workflow for fixing bugs in the Container Insights agent with proper regression testing.

USE FOR: fix bug, resolve issue, hotfix, patch, debug, error fix
DO NOT USE FOR: feature development, refactoring, performance optimization, CVE remediation

## Instructions

### When to Apply
When fixing incorrect behavior in Ruby Fluentd plugins, Go Fluent Bit plugins, shell scripts, or PowerShell scripts.

### Step-by-Step Procedure
1. **Reproduce** — Identify the bug's root cause. Check logs, telemetry, and error paths.
2. **Locate** — Find the affected file(s):
   - Ruby plugins: `source/plugins/ruby/`
   - Go plugins: `source/plugins/go/src/`
   - Linux scripts: `kubernetes/linux/`
   - Windows scripts: `kubernetes/windows/`
3. **Fix** — Apply the minimal change to fix the bug. Follow existing error handling patterns:
   - Ruby: `begin/rescue` with `ApplicationInsightsUtility.sendExceptionTelemetry`
   - Go: `if err != nil` with proper logging
   - Shell: check return codes with `set -e`
4. **Add regression test** — Create or update tests to cover the bug scenario:
   - Go: add test case in `source/plugins/go/src/*_test.go`
   - Ruby: add test case in `source/plugins/ruby/*_test.rb`
   - Bash: add test case in `test/unit-tests/test_cases/`
   - PowerShell: add test case in `test/unit-tests/test_cases/`
5. **Run all tests** — Ensure no regressions across all test suites.
6. **Verify telemetry** — Ensure error paths emit proper telemetry.

### Files Typically Involved
- `source/plugins/ruby/*.rb` — Ruby plugin fixes
- `source/plugins/go/src/*.go` — Go plugin fixes
- `kubernetes/linux/*.sh` — Linux script fixes
- `kubernetes/windows/*.ps1` — Windows script fixes

### Validation
- All four unit test suites pass
- New regression test covers the fixed bug
- No telemetry regressions (error paths still emit events)

## Examples from This Repo
- `5c0bca0bb` — bug fix (#1593)
- `fbcc3de37` — fix bug (#1577)
- `41e880633` — fix amaca liveness probe issue in high scale mode (#1530)
