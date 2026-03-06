---
applyTo: "**/*.sh,**/*.bash"
description: Shell script conventions for build, setup, and operational scripts.
---

# Shell Script Conventions

- Start scripts with `#!/bin/bash` and use `set -e` and `set -o pipefail` for safety.
- Quote all variable references to prevent word splitting: `"$VAR"` not `$VAR`.
- Use uppercase with underscores for environment variables (e.g., `IMAGE_TAG_NAME`, `ACR_REGISTRY`).
- Use `parse_args()` function pattern for CLI argument handling in build scripts.
- Log operations with `echo` prefixed by context (e.g., `echo "========================= Building ..."`).
- Check for required tools before use: `which <tool> >/dev/null 2>&1 || { echo "Error: ..."; exit 1; }`.
- Use `chmod +x` on test scripts before execution in CI.
- Do not hardcode secrets — use environment variables or mounted secrets.
- For conditional OS logic, check `$ARCH` or `$OS_TYPE` environment variables.
