# Security Review

## Description
Perform a STRIDE-based security review of code changes in the Container Insights agent repository.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to any PR that modifies authentication logic, network-facing code, Dockerfiles, Helm charts, scripts handling secrets, or dependency updates.

### Step-by-Step Procedure

1. **Identify changed files** and classify by security relevance:
   - High: Auth code, TLS config, secret handling, Dockerfiles, RBAC definitions
   - Medium: API clients, ConfigMap parsing, network code
   - Low: Internal logic, tests, documentation

2. **STRIDE analysis** for high/medium files:
   - **Spoofing**: Are auth checks present? Token validation complete? MSI/workload identity properly configured?
   - **Tampering**: Input validated from ConfigMaps, API responses, environment variables?
   - **Repudiation**: Security actions logged via Application Insights?
   - **Information Disclosure**: No secrets in logs, error messages, or telemetry properties?
   - **Denial of Service**: Resource limits set? Timeouts configured? Backpressure handled?
   - **Elevation of Privilege**: Containers non-root? RBAC least-privilege? Security contexts set?

3. **Credential scan** all changed files for:
   - Hardcoded instrumentation keys, workspace keys, SAS tokens
   - Connection strings with passwords
   - Private keys (`-----BEGIN PRIVATE KEY-----`)
   - Azure AD client secrets or certificates

4. **Weak pattern scan** for language-specific anti-patterns:
   - Go: `InsecureSkipVerify`, unchecked `err` from crypto/TLS functions, `exec.Command` with unsanitized input
   - Ruby: `eval`/`send` with user input, `YAML.load` instead of `YAML.safe_load`
   - Shell: Unquoted variables, `chmod 777`, secrets in command-line arguments, missing `set -e`
   - Dockerfiles: Running as root, `latest` tags, secrets in ENV, privileged containers

5. **Verify CI security coverage**:
   - CodeQL runs on PRs to `ci_prod` (`.github/workflows/codeql-analysis.yml`)
   - DevSkim runs on PRs (`.github/workflows/devskim.yml`)
   - Trivy scans Docker image in `pr-checker.yml` (severity: CRITICAL,HIGH)

### Files Typically Involved
- `source/plugins/go/src/` — Go plugin code
- `source/plugins/ruby/` — Ruby plugin code
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- `charts/azuremonitor-containers/templates/` — Helm RBAC and security contexts
- `build/*/installer/scripts/` — Installer scripts
- `.trivyignore` — Suppressed CVEs

### Validation
- Verify `.gitignore` excludes secret files (*.pem, *.key, .env)
- Confirm SECURITY.md exists (it does — Microsoft MSRC standard)
- Run `go vet ./...` in Go directories for static analysis
