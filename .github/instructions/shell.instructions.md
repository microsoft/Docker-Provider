---
applyTo: "**/*.sh,kubernetes/linux/**,test/unit-tests/**/*.sh"
description: "Shell/Bash scripting conventions for Linux agent scripts and tests."
---

# Shell Script Guidelines

- Start with `#!/bin/bash` and `set -e` for error handling.
- Use `snake_case` for function and variable names.
- Quote all variable expansions: `"$VAR"` not `$VAR`.
- Use `$(command)` for command substitution, not backticks.
- Test functions: place in `test/unit-tests/test_functions/`, test cases in `test/unit-tests/test_cases/`.
- Environment detection: use functions like `getClusterCloudEnvironment` pattern for cloud-specific logic.
- Log messages: use `echo` with descriptive prefixes for troubleshooting.
- Exit codes: return 0 for success, non-zero for failure. Test framework tracks pass/fail counts.
- File permissions: scripts must be executable (`chmod +x`). CI runs `chmod` before test execution.
- Portability: target Bash 4+; avoid bashisms when a POSIX-compatible alternative exists.
