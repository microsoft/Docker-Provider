# Security Review

## Description

Perform a STRIDE-based security review of code changes in the Docker-Provider repository, with credential leak detection and weak pattern scanning.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit, attack surface review
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply

Apply to every PR that modifies: authentication logic, network-facing code, data handling, Dockerfiles, Helm charts, Kubernetes manifests, dependency changes, or scripts handling secrets.

### STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Auth tokens validated at all entry points (not just presence-checked)
- Service-to-service calls authenticated (managed identity, FIC auth)
- Token refresh logic handles expiry correctly (`ingestion_token_utils.go`)

**Tampering (Data Integrity)**
- Input from Kubernetes API validated before processing
- Config files have restrictive permissions
- Helm values validated (no injection via template rendering)

**Repudiation (Auditability)**
- Security-relevant actions logged via Application Insights
- Logs include context (who/what/when) without sensitive data

**Information Disclosure (Confidentiality)**
- No hardcoded secrets, API keys, tokens, or connection strings
- Secrets loaded from K8s secrets (`/etc/ama-logs-secret/`) or env vars
- Error messages and logs do not contain credentials or workspace keys
- `.gitignore` excludes secret files

**Denial of Service (Availability)**
- Resource limits set in Helm chart DaemonSet/ReplicaSet specs
- Chunk sizes configurable (`PODS_CHUNK_SIZE`, high-scale mode)
- Liveness probes configured for agent health
- No unbounded Kubernetes API list operations

**Elevation of Privilege (Authorization)**
- Containers run as non-root (check `USER` in Dockerfiles)
- RBAC ClusterRole follows least-privilege (check `charts/*/templates/`)
- `nodes/proxy` permission scoped appropriately
- Security contexts set in pod specs

### Credential & Secret Leak Detection

Scan changed files for:
- API keys: `AKIA[0-9A-Z]{16}`, hex strings > 32 chars
- Connection strings: `Server=...;Password=...`
- Tokens: `Bearer <token>`, `ghp_`, `github_pat_`
- Private keys: `-----BEGIN PRIVATE KEY-----`
- Passwords in config: `password=`, `secret=`, `api_key=` followed by non-variable values
- Base64-encoded credential blobs

### Weak Security Patterns

**Go:** `#nosec` annotations (verify justified), unchecked `err` from crypto/auth functions, `fmt.Sprintf` for query building, `exec.Command` with unsanitized input
**Ruby:** `eval`/`send` with user input, `YAML.load` instead of `YAML.safe_load`, broad `rescue Exception`
**Bash:** Unquoted variables, `curl | sh` patterns, `chmod 777`, secrets as command-line args, missing `set -e`
**PowerShell:** `Invoke-Expression` with user input, `-ExecutionPolicy Bypass` without justification
**Dockerfiles:** Running as root, `latest` tags, secrets in ENV, privileged containers, missing security contexts

### Validation

- Run CodeQL analysis for Go/Python/Ruby: check `.github/workflows/codeql-analysis.yml`
- Run DevSkim scan: check `.github/workflows/devskim.yml`
- Verify `.gitignore` excludes `*.pem`, `*.key`, `.env`
- Confirm `SECURITY.md` exists and describes responsible disclosure
