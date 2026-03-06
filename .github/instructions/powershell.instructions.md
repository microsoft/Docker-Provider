---
applyTo: "**/*.ps1,**/*.psm1"
description: "PowerShell coding conventions for this repository."
---

# PowerShell Conventions

- Use `param()` blocks at the top of scripts for parameter declarations.
- The Windows agent entrypoint is `kubernetes/windows/main.ps1` — changes affect all Windows deployments.
- Helper functions live in `kubernetes/windows/functions/` — use dot-sourcing to import them.
- Use Pester 5.x for unit tests — test files follow `*.Tests.ps1` naming convention.
- Environment variables: access via `$env:VAR_NAME` — never hardcode secrets or connection strings.
- Use `Write-Host` for user-facing output, structured logging for production telemetry.
- Windows Docker image is built from `kubernetes/windows/Dockerfile`.
