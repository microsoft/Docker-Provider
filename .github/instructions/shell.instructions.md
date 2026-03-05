---
applyTo: "**/*.sh"
description: Shell/Bash scripting conventions for build scripts, setup scripts, and test frameworks.
---

# Shell/Bash Code Guidelines

1. Start scripts with `#!/bin/bash` and include `set -e` to fail on errors.
2. Quote all variable expansions: `"$VAR"`, `"${VARIABLE}"` — prevent word splitting and globbing.
3. Use `$(command)` for command substitution, not backticks.
4. Use `SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"` for reliable script-relative paths.
5. For the custom test framework (`test/unit-tests/test_framework.sh`), define test functions and use `assertEquals`/`assertNotEquals` helpers.
6. Use `chmod +x` on test scripts before execution — CI does this explicitly.
7. Environment variable names use UPPER_SNAKE_CASE (e.g., `AKS_RESOURCE_ID`, `CONTROLLER_TYPE`).
8. For Azure Linux containers, use `tdnf` (not `apt-get` or `yum`) for package management.
9. Do not pass secrets as command-line arguments — use environment variables.
