---
applyTo: "**/*.ps1"
---

- Use `Verb-Noun` naming for functions (e.g., `Get-ClusterCloudEnvironment`, `Is-CanaryRegion`).
- Use `PascalCase` for script file names (e.g., `Get-McsEndpoint.ps1`).
- Test with Pester 5.3.3 framework using `Describe`/`Context`/`It` blocks.
- Name test files with `Test-` prefix matching the function under test (e.g., `Test-GetMcsEndpoint.ps1`).
- Use `param()` blocks for function parameters with type annotations.
- Handle errors with `try/catch` blocks; use `Write-Error` or `throw` for error reporting.
- Store test cases in `test/unit-tests/test_cases/` and functions under test in `test/unit-tests/test_functions/`.
