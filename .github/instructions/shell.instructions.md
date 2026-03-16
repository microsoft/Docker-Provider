---
applyTo: "**/*.sh"
description: "Shell script conventions for Docker-Provider build and utility scripts."
---

# Shell Script Standards

- Use `#!/bin/bash` shebang.
- Use `set -e` to exit on errors in non-interactive scripts.
- Use `snake_case` for variables and function names.
- Quote all variable expansions: `"$variable"` not `$variable`.
- Configuration via environment variables — never hardcode paths or secrets.
- Use `echo` for user-facing output, redirect debug output to stderr.
- For build scripts, follow the pattern in `build/linux/Makefile` targets.
- Test scripts live under `test/unit-tests/` — follow the existing test framework in `test_framework.sh`.
- Windows-equivalent scripts use PowerShell (`.ps1`) under `kubernetes/windows/`.
