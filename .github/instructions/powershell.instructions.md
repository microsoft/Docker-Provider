---
applyTo: "**/*.ps1,**/*.psm1"
description: PowerShell conventions for Windows agent build and test scripts.
---

# PowerShell Conventions

- Use PascalCase for function names and parameters.
- Use Pester 5.3.3 for unit tests — test files use `*.Tests.ps1` suffix.
- Run PSScriptAnalyzer for linting before committing.
- Use `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force` in CI contexts.
- Use `$env:VARIABLE_NAME` for environment variables.
- Error handling: use `try/catch/finally` blocks with appropriate logging.
- Windows container paths use forward slashes or `Join-Path` for portability.
- Scripts target Windows Server 2019+ (LTSC2019 container images).
