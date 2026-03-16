# Bug Fix

## Description
Guide for fixing bugs in the Docker-Provider container insights agent.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix, bug fix
DO NOT USE FOR: feature development, refactoring, performance optimization, CVE fixes (use fix-critical-vulnerabilities)

## Instructions

### When to Apply
When fixing a reported bug or unexpected behavior in container log collection, metric emission, inventory gathering, or agent startup/liveness.

### Step-by-Step Procedure
1. Reproduce or understand the issue — check error logs, telemetry, and symptoms.
2. Identify the affected component: Go plugins (`source/plugins/go/`), Ruby plugins (`source/plugins/ruby/`), Shell scripts (`scripts/`), or configuration.
3. Locate the relevant source file(s) using the symptom (log message, error string, metric name).
4. Implement the fix following existing code patterns and error handling conventions.
5. Add a regression test in the appropriate test directory.
6. Run unit tests: `./test/unit-tests/test_main.sh`, `./test/unit-tests/run_go_tests.sh`, `./test/unit-tests/run_ruby_tests.sh`.
7. Build: `cd build/linux && make`.

### Files Typically Involved
- `source/plugins/go/src/*.go` — Go output plugins
- `source/plugins/go/input/**/*.go` — Go input plugins
- `source/plugins/ruby/*.rb` — Ruby Fluentd plugins
- `scripts/*.sh` — Shell scripts
- `test/unit-tests/` — Unit test files

### Validation
- All unit tests pass
- Build succeeds: `cd build/linux && make`
- No new Trivy findings

## Examples from This Repo
- `5c0bca0bb` — bug fix (#1593)
- `fbcc3de37` — fix bug (#1577)
- `41e880633` — fix amaca liveness probe issue in high scale mode (#1530)
