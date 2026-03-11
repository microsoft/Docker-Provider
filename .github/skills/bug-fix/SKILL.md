# Skill: Bug Fix

## Overview
Diagnose and fix bugs in the Docker-Provider monitoring agent across Go plugins, Ruby plugins, shell entrypoints, and PowerShell scripts. Every fix must include a regression test.

## Scope
- **Go plugins**: `source/plugins/go/src/*.go` (output plugins, telemetry, utils)
- **Ruby plugins**: `source/plugins/ruby/*.rb` (Fluent-Bit filter/output plugins)
- **Linux entrypoint**: `kubernetes/linux/main.sh`
- **Windows entrypoint**: `kubernetes/windows/main.ps1`
- **Configuration**: `kubernetes/linux/conf/`, `source/plugins/ruby/conf/`

## Workflow

### 1. Reproduce the Issue
- Read the bug report or logs to identify the failing behavior.
- Locate the relevant source file(s) using repo structure conventions:
  - Go source → `source/plugins/go/src/`
  - Ruby source → `source/plugins/ruby/`
  - Shell scripts → `kubernetes/linux/`, `scripts/`
- Write a failing test that demonstrates the bug before changing any production code.

### 2. Implement the Fix
- Make the minimal change that corrects the behavior.
- Follow the existing code style in the file being modified.
- For Go: use standard error handling (`if err != nil`), structured logging via the telemetry utilities.
- For Ruby: follow existing patterns using `@log` for logging, handle nil/empty defensively.
- For Shell: use `set -e` conventions, quote variables, check exit codes.

### 3. Add a Regression Test
| Language | Location | Framework | Run Command |
|----------|----------|-----------|-------------|
| Go | `*_test.go` next to source | `testify` assertions | `./test/unit-tests/run_go_tests.sh` |
| Ruby | `test/unit-tests/` | `Minitest` | `ruby test/unit-tests/test_driver.rb` |
| Bash | `test/unit-tests/test_cases/*.sh` | Shell harness | `./test/unit-tests/test_main.sh` |

### 4. Validate
```bash
# Build
cd build/linux && make

# Run the relevant test suite
./test/unit-tests/run_go_tests.sh      # Go changes
ruby test/unit-tests/test_driver.rb     # Ruby changes
./test/unit-tests/test_main.sh          # Shell changes
```

### 5. Commit
Use a freeform message that describes what was broken and how it was fixed. Reference the PR:
```
Fix nil pointer in container log parsing when metadata is missing (#1234)
```

## Pitfalls
- Changes to `main.sh` or `main.ps1` affect container startup — test in a cluster if possible.
- Ruby plugins run inside Fluent-Bit; unhandled exceptions can crash the pipeline.
- Go plugin changes may require rebuilding the shared object (`out_oms.so` / `input_*.so`).
- Always check if the bug exists on both Linux and Windows code paths.
