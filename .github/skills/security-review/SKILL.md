# Security Review

## Description
Perform a STRIDE-based security review of code changes in the Docker-Provider agent.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit, hardening review
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to every PR that modifies authentication/authorization logic, network-facing code, data handling, infrastructure (Dockerfiles, Helm charts, scripts), or dependency changes.

### Step-by-Step Procedure

#### 1. STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Authentication checks present at AMCS and Log Analytics endpoints
- MSI tokens and certificates validated before use (not just checked for presence)
- FIC (Federated Identity Credential) tokens properly validated
- Service-to-service calls use managed identity or certificate auth

**Tampering (Data Integrity)**
- Input validated on Kubernetes API responses (pod lists, node lists, events)
- ConfigMap values parsed with error handling (malformed YAML/JSON)
- File permissions on mounted secrets are restrictive (0400/0440)
- TLS used for all Azure service communication

**Repudiation (Auditability)**
- Authentication failures logged via Application Insights telemetry
- Configuration changes tracked (ConfigMap reloads, setting changes)
- Agent startup and shutdown events logged with context

**Information Disclosure (Confidentiality)**
- No hardcoded secrets, API keys, or connection strings in source code
- Instrumentation keys loaded from env vars (`APPLICATIONINSIGHTS_AUTH`) or mounted secrets
- Error messages do not expose internal file paths or configuration details
- Container logs forwarded to Log Analytics are not logged locally in plain text

**Denial of Service (Availability)**
- Resource limits set in Kubernetes manifests (CPU/memory limits)
- Fluent Bit buffer sizes bounded (`Mem_Buf_Limit` configured)
- Retry logic uses exponential backoff (not unbounded retries)
- Kubernetes API client has timeouts configured

**Elevation of Privilege (Authorization)**
- Containers run as non-root (`USER` directive in Dockerfile)
- RBAC ClusterRole uses minimal permissions (only what's needed for inventory collection)
- No `privileged: true`, `hostPID`, or `hostNetwork` without documented justification
- Security contexts set: `readOnlyRootFilesystem` where possible

#### 2. Credential & Secret Leak Detection
- Scan changed files for hardcoded strings matching:
  - Azure connection strings: `Endpoint=...;SharedAccessKey=...`
  - Application Insights keys: 32-character hex strings
  - Bearer tokens, API keys, private keys
  - Passwords in config: `password=`, `secret=`, `key=` followed by literal values
- Check that `.trivyignore` entries have justification comments
- Verify `.gitignore` excludes `*.pem`, `*.key`, `.env`

#### 3. Weak Security Patterns

**Go:**
- `#nosec` annotations without justification comment
- Unchecked `err` from TLS/auth functions
- `exec.Command` with unsanitized input
- HTTP instead of HTTPS in endpoint URLs

**Ruby:**
- `eval`, `send` with user-controlled input
- `system()` or backtick execution with unsanitized input
- `YAML.load` instead of `YAML.safe_load`
- Disabled SSL verification

**Shell/Bash:**
- Unquoted variables in commands
- `chmod 777` or overly permissive permissions
- Secrets passed as command-line arguments
- Missing `set -e` in security-critical scripts
- `curl` without certificate verification

**Infrastructure (Dockerfiles, k8s):**
- Running as root without justification
- Using `:latest` tags (non-reproducible builds)
- Secrets in ENV instead of mounted secrets
- Exposed ports that should be internal-only
- Missing security contexts in Kubernetes manifests

#### 4. CI Security Integration
- CodeQL analysis active: `.github/workflows/codeql-analysis.yml`
- DevSkim active: `.github/workflows/devskim.yml`
- Trivy scanning in PR checker: `.github/workflows/pr-checker.yml`
- `.trivyignore` entries reviewed for validity

### Validation
- Run existing security CI checks (CodeQL, DevSkim, Trivy)
- Verify `.gitignore` excludes secret files
- Confirm `SECURITY.md` exists and describes responsible disclosure
