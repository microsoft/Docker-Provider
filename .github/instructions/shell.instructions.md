---
applyTo: "**/*.sh"
description: Shell script conventions for build, installer, and runtime scripts.
---

# Shell Script Conventions

- Use `#!/bin/bash` shebang for all scripts.
- Use `set -e` in scripts where silent failures would be dangerous (installer, security-critical).
- Environment variables use `UPPER_SNAKE_CASE`; local variables use `lower_snake_case`.
- Source shared environment: `source /opt/env_vars` where available.
- Quote all variable expansions: `"$VAR"` not `$VAR` to prevent word splitting.
- Use `$(command)` for command substitution, not backticks.
- Log messages include timestamps where appropriate: `echo "message @ $(date +'%Y-%m-%dT%H:%M:%S')"`.
- Check file existence before reading: `[ -e "/path/file" ] && ...`.
- Use `grep -q` for silent pattern matching in conditionals.
- Test shell scripts with `./test/unit-tests/test_main.sh`; add test cases in `test/unit-tests/test_cases/test_*.sh`.
