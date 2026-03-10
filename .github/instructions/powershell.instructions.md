---
applyTo: "**/*.ps1,**/*.psm1"
description: "PowerShell conventions for Windows build, deployment, and test scripts."
---

# PowerShell Conventions — Docker-Provider

1. Functions use `PascalCase-WithHyphens` (e.g., `Confirm-WindowsServiceExists`).
2. Variables use `$PascalCase` or `$camelCase`; parameters use `-PascalCase`.
3. Use typed parameters: `[int]`, `[string]`, `[bool]` for function inputs.
4. Error handling: use `-ErrorAction SilentlyContinue` for optional checks; `try/catch` for critical paths.
5. Logging: use `Write-Host` for console output in scripts.
6. Windows container setup installs Ruby 3.1.1.1 + Fluentd 1.16.3 — match these versions.
7. Unit tests use Pester v5.3.3 — follow existing test patterns in `test/unit-tests/test_main.ps1`.
8. PSScriptAnalyzer runs in CI — ensure scripts pass static analysis.
