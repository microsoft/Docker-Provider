# Security Review Skill

## Name
security-review

## Description
Review code for security issues using STRIDE methodology, credential detection, and dependency vulnerability analysis.

## Triggers
- "security check", "security review", "STRIDE analysis", "check for vulnerabilities"

## Workflow

### 1. STRIDE Checklist

**Spoofing:**
- [ ] Auth tokens validated before use (IMDS, MSI, FIC)
- [ ] TLS certificate verification enabled for all outbound connections
- [ ] Kubernetes ServiceAccount tokens scoped minimally

**Tampering:**
- [ ] Configuration files loaded from trusted paths only
- [ ] Helm values validated/sanitized before template rendering
- [ ] No user-controlled input in shell command construction

**Repudiation:**
- [ ] Security-relevant operations logged with correlation IDs
- [ ] Agent startup/shutdown events captured in telemetry

**Information Disclosure:**
- [ ] No secrets, tokens, or connection strings in source code or logs
- [ ] Error messages don't expose internal Azure endpoints
- [ ] Kubernetes API responses filtered before logging

**Denial of Service:**
- [ ] HTTP request timeouts on all outbound calls
- [ ] Rate limiting on Kubernetes API calls (KubernetesApiClient)
- [ ] Memory-bounded buffers for data processing
- [ ] Liveness probes configured to detect hung processes

**Elevation of Privilege:**
- [ ] Container runs as non-root where possible
- [ ] Kubernetes RBAC uses minimal required permissions
- [ ] No `privileged: true` in security context
- [ ] Host volume mounts are read-only where possible

### 2. Credential Detection Rules
Scan for these patterns:
- `InstrumentationKey=` followed by GUID
- `Bearer ` followed by token string
- `access_token` in JSON responses logged to stdout
- Base64-encoded Kubernetes secrets in YAML
- PEM certificate blocks in source files
- Hardcoded values matching `*_KEY`, `*_SECRET`, `*_TOKEN`, `*_PASSWORD`

### 3. Weak Pattern Catalog

**Go:**
- `http.Get()` without timeout context → use `http.Client{Timeout: ...}`
- `ioutil.ReadAll()` without size limit → use `io.LimitReader()`
- `tls.Config{InsecureSkipVerify: true}` → never skip TLS verification
- Ignored error returns → always check `err != nil`

**Ruby:**
- `open()` with user input → command injection risk
- `eval()` or `instance_eval()` → code injection risk
- Unvalidated URI construction → SSRF risk
- `Net::HTTP` without TLS verification → MitM risk

**Shell:**
- Unquoted `$variable` expansions → word splitting/injection
- `eval` usage → command injection
- `curl` without `--fail` → silent HTTP errors
- World-readable file permissions on sensitive configs

**PowerShell:**
- `Invoke-Expression` with dynamic input → code injection
- Credentials in plain text variables → use SecureString
- `-SkipCertificateCheck` → TLS bypass

### 4. Security Tool Integration
- **CodeQL:** `.github/workflows/codeql-analysis.yml` — runs on push to `ci_prod` and PRs
- **DevSkim:** `.github/workflows/devskim.yml` — security pattern matching
- **Trivy:** Used in `pr-checker.yml` for container image scanning
- **`.trivyignore`:** CVE exceptions — verify each has justification comment
