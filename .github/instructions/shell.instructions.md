---
applyTo: "**/*.sh"
description: "Shell script conventions for this repository."
---

# Shell Conventions

- Use `#!/bin/bash` shebang for all scripts.
- Source shared environment: `source /opt/env_vars` in container entrypoint scripts.
- Quote all variable expansions: `"$VAR"` not `$VAR`.
- Use `set -e` in scripts that must fail on error.
- Check `CONTROLLER_TYPE` (`DaemonSet`/`ReplicaSet`) and `CONTAINER_TYPE` env vars for conditional logic.
- Log to files under `/var/opt/microsoft/docker-cimprov/log/` — follow the existing log path conventions.
- Use `if [ condition ]; then` style (POSIX-compatible) rather than `[[ ]]` when possible.
- Container scripts in `kubernetes/linux/` are the main entrypoints — changes affect all deployed agents.
- Installer scripts in `build/linux/installer/` follow the installbuilder pattern — do not restructure.
