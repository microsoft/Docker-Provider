# Security Review

## Description
Perform a STRIDE-based security review of code changes in the Docker-Provider repository.

USE FOR: security review, threat model, STRIDE analysis, credential leak check, secret scan, vulnerability review, security audit, hardening review
DO NOT USE FOR: performance optimization, functional bug fixes, code style issues, feature implementation

## Instructions

### When to Apply
Apply to every PR that modifies authentication/authorization logic, network-facing code, data handling, infrastructure (Dockerfiles, Helm charts, Kubernetes manifests), or dependency changes.

### Step-by-Step Procedure

#### 1. STRIDE Threat Model Checklist

**Spoofing (Identity)**
- Authentication checks present at Kubernetes API access points (service account tokens)
- MSI/FIC tokens validated before use in Azure Monitor communication
- Certificates validated for agent-to-MDSD communication

**Tampering (Data Integrity)**
- Input from Kubernetes API validated before processing
- ConfigMap settings validated before application
- File permissions restrictive in container (check `setup.sh`, Dockerfile `chmod`)

**Repudiation (Auditability)**
- Security-relevant actions logged via Application Insights telemetry
- Agent startup/shutdown events tracked

**Information Disclosure (Confidentiality)**
- No hardcoded secrets (check for `APPLICATIONINSIGHTS_AUTH`, proxy passwords, certificates)
- No secrets in log output or error messages
- Environment variables used for all sensitive configuration
- `.gitignore` excludes `*.so`, `*.pyc`, intermediate build artifacts

**Denial of Service (Availability)**
- Resource limits set in Kubernetes manifests (`ama-logs.yaml`)
- HTTP client timeouts configured for API calls
- Fluent Bit buffer limits configured
- Goroutines bounded (no goroutine leaks in Go plugins)

**Elevation of Privilege (Authorization)**
- Containers run with minimal RBAC (check ClusterRole in `ama-logs.yaml`)
- Dockerfile uses non-root USER where possible
- No privileged containers or hostNetwork unless justified
- Security contexts set (readOnlyRootFilesystem where applicable)

#### 2. Credential & Secret Leak Detection
- Scan for hardcoded strings matching secret patterns (API keys, tokens, connection strings)
- Check for Base64-encoded instrumentation keys
- Verify `.gitignore` excludes secret file patterns
- Check test fixtures for real credentials

#### 3. Weak Security Patterns

**Go:**
- `#nosec` annotations must have justification comments
- No unchecked `err` from crypto/auth/TLS functions
- No `fmt.Sprintf` for SQL queries or command construction
- No `exec.Command` with unsanitized input

**Ruby:**
- No `eval`, `send` with user-controlled input
- No `YAML.load` (use `YAML.safe_load`)
- No `system()` with unsanitized input

**Shell:**
- No unquoted variables in commands
- No `chmod 777`
- No secrets as command-line arguments
- `set -e` in security-critical scripts

**Infrastructure (Dockerfiles, k8s):**
- No `latest` tags in FROM instructions
- No secrets in ENV instructions
- Non-root USER directive
- Missing security contexts flagged

#### 4. CI Security Integration
- **Active**: CodeQL (Go, Python, Ruby), DevSkim, Trivy (container + library scanning)
- **Gap**: No secret scanner (Gitleaks/detect-secrets) — recommend adding

### Validation
- Trivy scan passes: `trivy image --severity CRITICAL,HIGH <image>`
- `.gitignore` excludes sensitive file patterns
- `SECURITY.md` exists with responsible disclosure process
