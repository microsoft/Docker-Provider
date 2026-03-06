---
applyTo: "**/*.sh"
description: Shell scripting conventions for the Azure Monitor container agent build and setup scripts.
---

# Shell Conventions

- Use `#!/bin/bash` shebang; prefer `set -e` to fail on errors in build/setup scripts.
- Target Azure Linux (CBL-Mariner / Azure Linux 3) — use `tdnf` instead of `apt-get` for package management in container contexts.
- Environment variables: `UPPER_SNAKE_CASE` (e.g., `AZMON_CLUSTER_LOG_TAIL_PATH`, `CONTROLLER_TYPE`).
- Local variables in functions: `lower_snake_case`.
- Quote all variable expansions: `"$VAR"` to prevent word splitting.
- Use `#!/bin/bash` compatible syntax — avoid Bash 5+ specific features for portability.
- Scripts in `build/common/installer/scripts/` parse ConfigMap settings — changes must handle missing or empty values gracefully.
- Scripts in `kubernetes/linux/` run at container startup — they must be idempotent and handle restarts.
- Do not hardcode secrets, instrumentation keys, or connection strings.
- Log messages should include the script/function name for traceability.
- Use `curl` with appropriate timeouts and error handling for HTTP calls.
