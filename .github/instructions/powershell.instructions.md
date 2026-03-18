---
applyTo: "**/*.ps1,**/*.psm1,kubernetes/windows/**"
description: "PowerShell scripting conventions for Windows agent scripts and tests."
---

# PowerShell Guidelines

- Use `PascalCase` for function names following Verb-Noun convention (e.g., `Get-McsEndpoint`).
- Test framework: Pester 5.3.3. Test files named `Test-<FunctionName>.ps1` in `test/unit-tests/test_cases/`.
- Test functions (functions under test): placed in `test/unit-tests/test_functions/` (e.g., `Get-McsEndpoint.ps1`).
- Error handling: use `try/catch` blocks for external calls. Prefer `-ErrorAction Stop` for cmdlet calls.
- Environment variables: access via `$env:VAR_NAME`.
- Cloud environment detection: use `Get-ClusterCloudEnvironment` / `Is-SupportedCloudEnvironment` patterns.
- Module imports: use `Import-Module` with `-RequiredVersion` for reproducibility.
- Script execution policy: tests run with `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force`.
