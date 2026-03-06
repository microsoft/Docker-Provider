# Security Review

## Description
Performs a STRIDE-based security review of code changes, including credential leak detection and weak security pattern scanning.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit, hardening review
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to every PR that modifies authentication/authorization logic, network-facing code, data handling, infrastructure (Dockerfiles, Helm charts, scripts), or dependency changes.

### Step-by-Step Procedure

#### 1. STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Are authentication checks present at all entry points?
- Are tokens/credentials validated before use?
- Are service-to-service calls authenticated (mTLS, managed identity)?

**Tampering (Data Integrity)**
- Is input validated and sanitized at trust boundaries?
- Are file permissions restrictive (no world-writable files)?
- Is data integrity maintained in transit (TLS)?

**Repudiation (Auditability)**
- Are security-relevant actions logged with context?
- Do logs avoid leaking sensitive data?

**Information Disclosure (Confidentiality)**
- No hardcoded secrets, API keys, tokens, or connection strings in code.
- No secrets in log output, error messages, or telemetry properties.
- Env vars used for secrets (`APPLICATIONINSIGHTS_AUTH`, not config files).
- Debug endpoints disabled in production configs.

**Denial of Service (Availability)**
- Resource limits set (timeouts, max payload sizes, container CPU/memory limits).
- No unbounded loops or goroutine leaks.
- Container resource limits set in Kubernetes manifests and Helm values.

**Elevation of Privilege (Authorization)**
- Containers running as non-root where possible.
- RBAC roles follow least-privilege principle.
- Security contexts set in Kubernetes manifests.

#### 2. Credential & Secret Leak Detection
- Scan all changed files for hardcoded secrets: API keys, tokens, passwords, private keys, connection strings.
- Check that `.gitignore` excludes secret files (`*.pem`, `*.key`, `.env`).
- Verify test fixtures don't contain real credentials.

#### 3. Weak Security Patterns

**Go:**
- No `#nosec` annotations without justification comments.
- No unchecked `err` returns from security-sensitive functions.
- No `fmt.Sprintf` for SQL/command construction with user input.
- No `exec.Command` with unsanitized input.

**Ruby:**
- No `eval`, `send` with user-controlled input.
- No `system()` or backtick execution with unsanitized input.
- No `YAML.load` (use `YAML.safe_load`).

**Shell/Bash:**
- No unquoted variables in commands.
- No `chmod 777` or overly permissive permissions.
- No secrets passed as command-line arguments.
- `set -e` present in security-critical scripts.

**Infrastructure (Dockerfiles, k8s, Helm):**
- No running as root without justification.
- No `latest` tags (non-reproducible builds).
- No secrets in ENV (use mounted secrets).
- No privileged containers without justification.
- Security contexts set (readOnlyRootFilesystem, runAsNonRoot).

#### 4. CI Security Integration
- CodeQL running in CI (`.github/workflows/codeql-analysis.yml`)
- DevSkim running in CI (`.github/workflows/devskim.yml`)
- Trivy scanning in PR checker (`.github/workflows/pr-checker.yml`)
- Verify `.trivyignore` entries have valid justification

### Validation
- Run CodeQL and DevSkim scans
- Verify `.gitignore` excludes secret file patterns
- Confirm `SECURITY.md` exists and describes responsible disclosure
