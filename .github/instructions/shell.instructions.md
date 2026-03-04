---
applyTo: "**/*.sh"
---

- Use `#!/bin/bash` (or `#!/bin/sh` for POSIX-only scripts) as the shebang line.
- Set `set -e` at the top of scripts to fail on first error.
- Use `snake_case` for function and variable names.
- Source shared environment variables from `/opt/env_vars` in container runtime scripts.
- Use `$SCRIPTPATH` pattern for reliable relative path resolution: `SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"`.
- Quote all variable expansions: `"${VAR}"` instead of `$VAR`.
- Use `echo` for user-facing output; redirect diagnostic output to stderr or log files.
- Check for required environment variables (`CONTROLLER_TYPE`, `CONTAINER_TYPE`) before conditional logic.
- Use `chmod +x` on test scripts before execution (CI does this explicitly).
