---
applyTo: "**/*.ps1,**/*.psm1"
description: Code style and best practices for PowerShell scripts in the Docker-Provider Windows agent.
---

# PowerShell Conventions — Docker-Provider

- Use `PascalCase` for function names and `$camelCase` for local variables.
- Scripts in `build/windows/installer/scripts/` serve as the Windows counterpart to Linux Bash scripts.
- `kubernetes/windows/main.ps1` is the Windows container entry point — follow its logging and startup patterns.
- Use `$env:VAR_NAME` for environment variable access.
- Error handling: Use `try/catch` blocks; log errors before re-throwing.
- When modifying Windows agent behavior, check if a matching Linux script exists and keep parity.
- Test scripts follow the pattern in `test/unit-tests/test_framework.ps1` and `test/unit-tests/test_main.ps1`.
