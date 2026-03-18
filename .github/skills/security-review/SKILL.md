# Security Review

## Description
STRIDE-based security review skill for the Container Insights agent codebase.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to every PR that modifies authentication logic, network-facing code, data handling, Dockerfiles, Helm charts, or Kubernetes manifests.

### Step-by-Step Procedure

#### 1. STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Authentication checks at Kubernetes API entry points (`KubernetesApiClient.rb`)
- MSI/AAD token validation (`arc_k8s_cluster_identity.rb`, `extension_utils.rb`)
- Service-to-service calls use in-cluster config (`rest.InClusterConfig()` in Go)

**Tampering (Data Integrity)**
- Input validation on Kubernetes API responses before processing
- ConfigMap values validated before use (`container-azm-ms-agentconfig.yaml`)
- File permissions restrictive in Dockerfiles (no world-writable)

**Repudiation (Auditability)**
- Security-relevant actions logged via `$log` (Ruby) or `log.Printf` (Go)
- Telemetry events for authentication/authorization decisions

**Information Disclosure (Confidentiality)**
- No hardcoded secrets (check `APPLICATIONINSIGHTS_AUTH`, `AKS_RESOURCE_ID` patterns)
- Secrets use env vars, not config files committed to repo
- Debug endpoints disabled in production (`pprof` in Go gated by env var)
- Log output does not contain credentials or tokens

**Denial of Service (Availability)**
- Chunk sizes configured via env vars (`NODES_CHUNK_SIZE`, `EMIT_STREAM_BATCH_SIZE`)
- Kubernetes API pagination prevents unbounded responses
- Container resource limits set in Helm chart values
- Health/liveness probes configured

**Elevation of Privilege (Authorization)**
- Container runs as non-root (verify `USER` directive in Dockerfile)
- RBAC roles follow least-privilege (`kubernetes/*.yaml` ClusterRole definitions)
- Security contexts in Helm chart templates

#### 2. Credential & Secret Leak Detection

Scan changed files for:
- Hardcoded instrumentation keys (should use `APPLICATIONINSIGHTS_AUTH` env var)
- Connection strings or tokens in code
- Secrets in test fixtures or example configs
- Base64-encoded blobs that may contain credentials

#### 3. Weak Security Patterns

**Go:**
- `#nosec` annotations — verify justification
- Unchecked errors from crypto/TLS functions
- `exec.Command` with unsanitized input

**Ruby:**
- `eval`, `send` with user-controlled input
- `YAML.load` vs `YAML.safe_load`
- Shell commands via backticks or `system()` with unsanitized input

**Shell/Bash:**
- Unquoted variables in commands
- Missing `set -e`
- `chmod 777` or overly permissive permissions
- Secrets passed as command-line arguments

**Dockerfiles/k8s:**
- Running as root without justification
- `latest` tags (non-reproducible)
- Secrets in ENV instead of mounted secrets
- Missing security contexts

#### 4. CI Security Tool Coverage

This repo uses:
- **CodeQL** — SAST for Go, Python, Ruby (`.github/workflows/codeql-analysis.yml`)
- **DevSkim** — Security pattern scanning (`.github/workflows/devskim.yml`)
- **Trivy** — Container vulnerability scanning (`.trivyignore` for accepted CVEs)

### Validation
- CodeQL passes with no new findings
- DevSkim scan passes
- Trivy scan shows no unacknowledged critical/high CVEs
- `.gitignore` excludes secret file patterns
