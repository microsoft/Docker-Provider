# Security Review

## Description
Performs STRIDE-based security review, credential leak detection, and weak security pattern scanning for the container monitoring agent.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit, hardening review
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to every PR that modifies authentication logic, network-facing code, data handling, infrastructure (Dockerfiles, Helm charts, Terraform), or dependency changes.

### STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Are Kubernetes API calls authenticated (service account, managed identity)?
- Is `AAD_MSI_AUTH_MODE` validated before use?
- Are tokens for Application Insights (`APPLICATIONINSIGHTS_AUTH`) loaded from env vars, never hardcoded?

**Tampering (Data Integrity)**
- Is input from Kubernetes API validated before processing?
- Are file permissions restrictive in container setup scripts?
- Is data integrity maintained for log forwarding (checksums, TLS)?

**Repudiation (Auditability)**
- Are security-relevant actions logged via `ApplicationInsightsUtility` or `$log`?
- Do logs include correlation IDs without leaking sensitive data?

**Information Disclosure (Confidentiality)**
- No hardcoded secrets, API keys, tokens, or connection strings in code
- No secrets in log output — check `$log.info`, `Log()`, `fmt.Printf` calls
- Environment variables used for all secrets (`APPLICATIONINSIGHTS_AUTH`, etc.)
- `.trivyignore` entries have justification comments

**Denial of Service (Availability)**
- Are HTTP timeouts set for Kubernetes API calls and telemetry flushes?
- Are retry loops bounded?
- Are container resource limits set in Helm chart values?
- Are Fluent Bit buffer sizes configured to prevent memory exhaustion?

**Elevation of Privilege (Authorization)**
- Are containers running with appropriate security contexts?
- Is RBAC (ClusterRole/ClusterRoleBinding) following least-privilege?
- Check `kubernetes/ama-logs.yaml` and Helm RBAC templates for excessive permissions

### Credential & Secret Detection
Scan all changed files for:
- Hardcoded instrumentation keys matching hex patterns
- Connection strings: `Server=...;Password=...`
- Tokens: `Bearer `, `ghp_`, `github_pat_`
- Private keys: `-----BEGIN PRIVATE KEY-----`
- Passwords in config: `password=`, `secret=`, `api_key=` with non-variable values
- Base64-encoded blobs that could contain credentials

### Weak Security Patterns

**Go:**
- `#nosec` annotations without justification
- Unchecked `err` returns from crypto/auth functions
- `fmt.Sprintf` for building queries (injection risk)
- `InsecureSkipVerify: true` without justification

**Ruby:**
- `eval()`, `send()` with user-controlled input
- `system()` with unsanitized input
- `YAML.load` instead of `YAML.safe_load`

**Shell/Bash:**
- Unquoted variables in commands
- `chmod 777` or overly permissive permissions
- Secrets as command-line arguments
- Missing `set -e`

**Infrastructure (Dockerfiles, Helm, k8s):**
- Running as root without justification
- Using `latest` tags (non-reproducible)
- Secrets in ENV instead of mounted secrets
- Missing security contexts
- Exposed ports that should be internal

### CI Security Tool Coverage
This repo has active security scanning:
- **SAST**: CodeQL (Go, Python, Ruby) — `.github/workflows/codeql-analysis.yml`
- **Pattern Scanning**: DevSkim — `.github/workflows/devskim.yml`
- **Container Scanning**: Trivy (CRITICAL/HIGH, exit-code 1) — `.github/workflows/pr-checker.yml`
- **CVE Tracking**: `.trivyignore` for temporarily ignored vulnerabilities

### Validation
- Trivy scan passes: `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
- `.gitignore` excludes secret files
- `SECURITY.md` exists with Microsoft MSRC disclosure process
