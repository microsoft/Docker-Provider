# Security Review

## Description
STRIDE-based security review skill for Docker-Provider code changes.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to PRs modifying: authentication logic, network-facing code, data handling, Dockerfiles, Kubernetes manifests, Helm charts, or dependency changes.

### Step-by-Step Procedure

#### 1. STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Are Azure AD MSI auth checks present at container entry points?
- Are tokens validated (not just checked for presence)?
- Is service-to-service auth using managed identity or certificates?

**Tampering (Data Integrity)**
- Is input validated at trust boundaries (log parsing, API responses)?
- Are container image digests pinned (not `:latest` tags)?
- Are file permissions restrictive in Dockerfiles?

**Repudiation (Auditability)**
- Are security-relevant actions logged via Application Insights?
- Do logs include context (who, what, when) without leaking secrets?

**Information Disclosure (Confidentiality)**
- No hardcoded secrets, API keys, tokens, or connection strings.
- No secrets in log output or error messages.
- Env vars used for: `APPLICATIONINSIGHTS_AUTH`, `WSID`, endpoints.
- TLS certificates excluded from repo (check `.gitignore`).

**Denial of Service (Availability)**
- Resource limits set in Kubernetes manifests (CPU/memory).
- Timeouts on HTTP calls and API requests.
- Bounded concurrent operations (goroutines, threads).
- Container liveness/readiness probes configured.

**Elevation of Privilege (Authorization)**
- Containers running as non-root (check `USER` in Dockerfiles).
- RBAC roles follow least-privilege (check ClusterRole definitions).
- Security contexts set in Kubernetes manifests.
- No privileged containers without justification.

#### 2. Credential & Secret Detection
Scan changed files for:
- API keys: `AKIA[0-9A-Z]{16}`, hex strings > 32 chars
- Connection strings: `Server=...;Password=...`
- Tokens: `Bearer`, `ghp_`, `github_pat_`
- Private keys: `-----BEGIN PRIVATE KEY-----`
- Hardcoded endpoints that should be configurable

#### 3. Weak Security Patterns

**Go:**
- `#nosec` annotations without justification
- Unchecked `err` returns from crypto/auth functions
- `fmt.Sprintf` for SQL queries
- `exec.Command` with unsanitized input

**Ruby:**
- `eval`, `send` with user-controlled input
- `system()` with unsanitized input
- `YAML.load` instead of `YAML.safe_load`

**Shell/Bash:**
- Unquoted variables in commands
- `chmod 777` or overly permissive permissions
- Secrets passed as command-line arguments
- Missing `set -e`

**Infrastructure (Dockerfiles, k8s):**
- Running as root without justification
- Using `:latest` tags
- Secrets in ENV instead of mounted secrets
- Missing security contexts
- Exposed ports that should be internal-only

#### 4. CI Security Integration
- CodeQL runs weekly on Go, Python, Ruby
- DevSkim runs on PRs
- Trivy scans Docker images for CRITICAL/HIGH CVEs
- `.trivyignore` tracks suppressed CVEs (verify justifications)

### Validation
- Run `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
- Verify `.gitignore` excludes `*.pem`, `*.key`, `.env`
- Confirm `SECURITY.md` exists (Microsoft CVD policy)
