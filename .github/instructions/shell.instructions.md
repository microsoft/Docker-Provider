---
applyTo: "**/*.sh"
description: Code style and best practices for Shell/Bash scripts in the Docker-Provider agent.
---

# Shell/Bash Conventions — Docker-Provider

- Start every script with `#!/bin/bash`.
- Use `set -e` and `set -o pipefail` for fail-fast behavior in build/deployment scripts.
- Quote all variable expansions: `"$VAR"` not `$VAR` to prevent word splitting.
- Use `snake_case` for variable names, `camelCase` for function names (matches existing convention).
- Environment variable checks: Use `[ -n "$VAR" ]` or `[ -z "$VAR" ]` before accessing.
- Use `echo` for user output; prefer `>&2` for error/warning messages.
- File existence: Use `[ -f "$path" ]` or `[ -e "$path" ]` before reading files.
- For installer scripts in `build/linux/installer/scripts/`, follow the existing pattern of sourcing shared functions.
- Container entry points (`kubernetes/linux/main.sh`): Log startup timestamps and use structured logging patterns.
- Test scripts in `test/unit-tests/` follow the custom test framework in `test_framework.sh` — use `assert_equals`, `assert_contains`.
