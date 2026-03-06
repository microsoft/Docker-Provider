# Security Review

## Purpose
Perform a STRIDE-based security review of code changes in the Docker-Provider repository, checking for credential leaks, weak security patterns, and threat model gaps specific to containerized Kubernetes monitoring agents.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## When to Use
- When reviewing any PR that modifies authentication, network, or data handling code
- When changes touch Dockerfiles, Helm charts, Kubernetes manifests, or RBAC configurations
- When dependency changes introduce new packages
- Before major version releases

## Inputs
- Files changed in the PR or commit range
- Target component (Ruby plugins, Go plugins, infrastructure, scripts)

## Outputs
- STRIDE assessment for each changed component
- Credential leak scan results
- Weak security pattern findings
- Recommended fixes

## Steps

1. **Enumerate changed files** and classify by security impact:
   - High: Dockerfiles, Helm values, RBAC, auth code, secret handling
   - Medium: Plugin code with external calls, configuration files
   - Low: Tests, documentation, internal logic

2. **Apply STRIDE analysis** to high/medium impact files:
   - **Spoofing:** Check MSI/FIC authentication in Azure SDK calls. Verify certificate validation in Go HTTP clients. Check `InsecureSkipVerify` is not set to `true`.
   - **Tampering:** Verify ConfigMap inputs are validated. Check file permissions in Dockerfile (`chmod`/`chown`). Verify Helm chart values are sanitized.
   - **Repudiation:** Ensure security-relevant actions emit Application Insights telemetry. Check that error paths log sufficient context.
   - **Information Disclosure:** Scan for hardcoded `APPLICATIONINSIGHTS_AUTH` values. Check no secrets in `echo`/`Log()` statements. Verify `.gitignore` excludes `*.pem`, `*.key`, `.env`.
   - **Denial of Service:** Check Kubernetes resource limits in manifests. Verify log processing has backpressure. Check for unbounded goroutines in Go code.
   - **Elevation of Privilege:** Verify `USER` directive in Dockerfiles (non-root). Check RBAC roles in Helm chart templates. Verify `securityContext` in pod specs.

3. **Run credential leak scan** on all changed files:
   - Pattern: base64-encoded strings > 32 chars (potential keys)
   - Pattern: `APPLICATIONINSIGHTS_AUTH=` followed by literal values
   - Pattern: connection strings (`Server=...;Password=...`)
   - Pattern: private keys (`-----BEGIN.*PRIVATE KEY-----`)
   - Check `.trivyignore` entries have expiration dates and justification

4. **Check language-specific weak patterns:**
   - Go: `#nosec` annotations, unchecked crypto errors, `exec.Command` with unsanitized input
   - Ruby: `eval`/`send` with user input, `YAML.load` instead of `YAML.safe_load`
   - Shell: Unquoted variables, `curl | bash`, `chmod 777`, secrets in CLI arguments
   - PowerShell: `Invoke-Expression` with user input, disabled execution policies

5. **Verify CI security coverage:**
   - CodeQL running on PR (`.github/workflows/codeql-analysis.yml`)
   - DevSkim running on PR (`.github/workflows/devskim.yml`)
   - Trivy scanning container image (`.github/workflows/pr-checker.yml`)

## Validation
- All findings categorized by STRIDE category and severity
- No false positives for patterns explicitly allowed by the team
- `.trivyignore` entries verified for validity

## Risks and Guardrails
- Do NOT expose actual secret values in review comments
- Do NOT modify code — only report findings
- Flag `.trivyignore` entries older than 90 days for re-evaluation

## References
- `SECURITY.md` — Microsoft responsible disclosure policy
- `.github/workflows/codeql-analysis.yml` — CodeQL configuration
- `.github/workflows/devskim.yml` — DevSkim configuration
- `.github/workflows/pr-checker.yml` — Trivy scan configuration
