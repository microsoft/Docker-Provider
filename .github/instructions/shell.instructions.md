---
applyTo: "**/*.sh"
description: "Bash/Shell script conventions for build, deployment, and testing scripts."
---

# Shell Script Conventions — Docker-Provider

1. Functions use `camelCase` naming; environment variables use `UPPER_CASE`.
2. Always quote variable references: `"$VAR"` not `$VAR` — prevents word splitting.
3. Use `[ -e path ]` or `[ -f file ]` guards before reading files or accessing paths.
4. Check command exit codes — do not assume success for critical operations.
5. Use `echo` with color codes (`\033[0;34m` blue, `\033[0;31m` red, `\033[0m` reset) for test output.
6. Container entry points (`main.sh`) orchestrate service startup — `crond`, `fluentd`, `fluent-bit`, `mdsd`.
7. Cloud environment detection uses domain-based `case` matching (azure.com, azure.cn, etc.).
8. Test scripts in `test/unit-tests/` use a custom framework (`test_framework.sh`) — follow its patterns.
9. Build scripts in `build/linux/installer/scripts/` handle installation — never modify directly.
10. Use `source` or `.` for sourcing utility functions — keep functions reusable.
