# Security Review

## Description
Perform a STRIDE-based security review of changes to the Docker-Provider agent.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues

## Instructions

### When to Apply
For any PR that modifies authentication logic, network-facing code, data handling, Dockerfiles, Helm charts, or dependency changes.

### Step-by-Step Procedure

#### 1. STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Verify token/credential validation in `source/plugins/ruby/arc_k8s_cluster_identity.rb` and `source/plugins/go/src/ingestion_token_utils.go`.
- Check that service-to-service calls use managed identity or certificate-based auth.
- Verify AAD MSI auth mode is correctly checked (`AAD_MSI_AUTH_MODE` env var).

**Tampering (Data Integrity)**
- Input validation on Kubernetes API responses before processing.
- TLS verification is enabled for all outbound HTTP calls (no `InsecureSkipVerify`).
- File permissions on config files and certificates are restrictive.

**Repudiation (Auditability)**
- Security-relevant actions logged via `ApplicationInsightsUtility` (Ruby) or `appinsights` (Go).
- Authentication failures are tracked in telemetry.

**Information Disclosure (Confidentiality)**
- No hardcoded secrets: `APPLICATIONINSIGHTS_AUTH`, connection strings, tokens must come from env vars.
- Secrets not logged: check `$log.warn`/`$log.error`/`Log()` calls don't include sensitive values.
- `.trivyignore` entries are justified with comments.

**Denial of Service (Availability)**
- Container resource limits set in Kubernetes manifests and Helm charts.
- Chunk sizes bounded (`PODS_CHUNK_SIZE`, `NODES_CHUNK_SIZE`).
- HTTP timeouts configured on outbound connections.

**Elevation of Privilege (Authorization)**
- Dockerfile `USER` directive — verify non-root where possible.
- Kubernetes RBAC: `kubernetes/ama-logs.yaml` ClusterRole uses least-privilege.
- No `privileged: true` or `hostNetwork: true` without justification.

#### 2. Credential & Secret Leak Detection
- Scan for hardcoded strings matching: API keys, tokens (`ghp_`, `Bearer`), connection strings, private keys.
- Verify `.gitignore` excludes `*.pem`, `*.key`, `.env`.
- Check that `APPLICATIONINSIGHTS_AUTH` and `APPLICATIONINSIGHTS_ENDPOINT` values are never logged.

#### 3. Language-Specific Weak Patterns

**Go:**
- No `#nosec` without justification comment.
- No `fmt.Sprintf` for SQL/command construction with user input.
- `exec.Command` not used with unsanitized input.

**Ruby:**
- No `eval`/`send` with user-controlled input.
- `YAML.safe_load` instead of `YAML.load` for untrusted data.
- No `system()` with unvalidated input.

**Shell:**
- All variables quoted in commands.
- No `chmod 777` or overly permissive permissions.
- `set -e` in security-critical scripts.
- No secrets passed as command-line arguments.

**Dockerfiles/k8s:**
- No `latest` tags for base images.
- Secrets in mounted volumes, not ENV.
- Security contexts set (readOnlyRootFilesystem, runAsNonRoot where possible).

### Validation
- Trivy scan passes
- CodeQL scan passes
- DevSkim scan passes
- No credentials in changed files

## References
- `.github/workflows/codeql-analysis.yml` — CodeQL SAST
- `.github/workflows/devskim.yml` — DevSkim pattern matching
- `.github/workflows/pr-checker.yml` — Trivy container scanning
- `SECURITY.md` — Security policy
