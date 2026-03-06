---
applyTo: "**/*.ps1,**/*.psm1"
description: PowerShell conventions for Windows agent scripts and tests.
---

# PowerShell Conventions

- Use PascalCase for function names, script names, and parameters.
- Use Pester 5.x (`Describe`/`Context`/`It`) for all test files (`Test-*.ps1`).
- Functions under test live in `test/unit-tests/test_functions/` with matching test cases in `test_cases/`.
- Use `$ErrorActionPreference = 'Stop'` for strict error handling in production scripts.
- Use `param()` blocks at the top of scripts for parameter declaration.
- Environment variables accessed via `$env:VARIABLE_NAME`.
- Import modules explicitly: `Import-Module Pester -RequiredVersion 5.3.3`.
- Windows agent entry point: `kubernetes/windows/main.ps1`.
