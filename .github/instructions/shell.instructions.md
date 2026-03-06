---
applyTo: "**/*.sh"
description: Shell script conventions for build, setup, and operational scripts in this repository.
---

# Shell Conventions

- Use `#!/bin/bash` shebang for all scripts.
- Use `set -e` in critical scripts to fail on errors.
- Quote all variable expansions: `"$VAR"` not `$VAR`.
- Use uppercase for environment variables, lowercase for local variables.
- Scripts must work on both Ubuntu and Azure Linux (Mariner) — avoid distro-specific package managers where possible.
- Use `tdnf` for Azure Linux package management in Dockerfiles, `apt-get` for Ubuntu build machines.
- For path portability, use `$(dirname "$0")` or `$SCRIPTPATH` patterns (see existing test scripts).
- Log output with `echo` — prefix informational messages with `#` for test scripts.
- Exit with explicit codes: `exit 0` for success, `exit 1` for failure.
