---
applyTo: "**/*.ps1,**/*.psm1"
description: PowerShell conventions for Windows agent build and test scripts.
---

# PowerShell Conventions

- Functions use `Verb-Noun` naming convention.
- Use `Set-StrictMode -Version Latest` in production scripts.
- Test with Pester 5.3.3: `Import-Module Pester -RequiredVersion 5.3.3`.
- Run PowerShell tests: `./test/unit-tests/test_main.ps1` (on Windows).
- Use `$env:VAR_NAME` for environment variable access.
- Error handling with `try/catch/finally` blocks.
- Prefer `Write-Output` over `Write-Host` for pipeline-friendly output.
- Windows build entry point: `build/windows/Makefile.ps1`.
