---
applyTo: "**/*.ps1"
description: PowerShell coding conventions for Windows build scripts, setup, and Pester test cases.
---

# PowerShell Code Guidelines

1. Use Verb-Noun naming for functions: `Get-McsEndpoint`, `Test-IsCanaryRegion`, `Is-SupportedCloudEnvironment`.
2. Use `param()` blocks for function and script parameters.
3. Test with Pester 5.3.3 — use `Describe`, `Context`, `It`, `Should` blocks.
4. Use `$env:VAR_NAME` for environment variable access.
5. String interpolation: use `"text $variable"` or `"text $($expression)"`.
6. Error handling: use `try/catch` blocks; prefer specific exception types.
7. Test files follow `Test-<FunctionName>.ps1` naming in `test/unit-tests/test_cases/`.
8. Function implementations under test go in `test/unit-tests/test_functions/`.
