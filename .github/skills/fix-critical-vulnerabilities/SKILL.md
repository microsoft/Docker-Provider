# Fix Critical Vulnerabilities

## Description
Identify and fix critical and high severity vulnerabilities in the Docker-Provider agent using the repo's own scanning tools.

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, dependency vulnerability fix, container image vulnerability, OS vulnerability fix
DO NOT USE FOR: general dependency updates without security motivation, adding new security scanning tools, security architecture review (use security-review), threat modeling

## Instructions

### 1. Vulnerability Discovery

**Scanning tools used in this repo:**
- **Trivy**: Container image and filesystem scanning — configured in `.github/workflows/pr-checker.yml`
- **CodeQL**: Static analysis for Go and Ruby — configured in `.github/workflows/codeql-analysis.yml`
- **DevSkim**: Security pattern matching — configured in `.github/workflows/devskim.yml`

**Run scans locally:**
```bash
# Trivy filesystem scan for Go module vulnerabilities
trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/

# Trivy filesystem scan for all Go modules
find . -name "go.mod" -exec dirname {} \; | xargs -I{} trivy fs --severity CRITICAL,HIGH --scanners vuln {}

# Go vulnerability check
cd source/plugins/go/src && govulncheck ./...

# Trivy container image scan (requires built image)
trivy image --severity CRITICAL,HIGH <image-name>
```

**Parse scan results — extract:**
- CVE ID, severity, affected package, current version, fixed version
- Vulnerability type (Go module, OS package, container base image)
- File path where the vulnerable dependency is declared

### 2. Vulnerability Triage

**a. Direct Go module vulnerabilities:**
- Package is in `go.mod` `require` (not `indirect`)
- Priority: HIGH — directly fixable
- Check all `go.mod` locations: `source/plugins/go/src/`, `source/plugins/go/input/*/`, `test/ginkgo-e2e/*/`

**b. Transitive Go module vulnerabilities:**
- Package is `// indirect` in `go.mod`
- Bump the direct parent dependency that pulls it in

**c. OS/base image vulnerabilities:**
- Check base image in `kubernetes/linux/Dockerfile.multiarch`
- Check if a newer CBL-Mariner image is available with the fix

**d. Already-ignored vulnerabilities:**
- Check `.trivyignore` — if CVE is listed with justification, skip it
- If listed without justification, flag for review

### 3. Fix Implementation

**Go module vulnerabilities:**
```bash
cd source/plugins/go/src
go get <package>@<fixed-version>
go mod tidy

# Also update other go.mod files if they share the dependency
cd source/plugins/go/input/containerinventory && go get <package>@<fixed-version> && go mod tidy
cd source/plugins/go/input/perf && go get <package>@<fixed-version> && go mod tidy
cd test/ginkgo-e2e/utils && go get <package>@<fixed-version> && go mod tidy
```

**Container base image vulnerabilities:**
- Update the `FROM` line in `kubernetes/linux/Dockerfile.multiarch`
- For Ruby gem vulnerabilities, update in `kubernetes/linux/setup.sh`

**Unfixable vulnerabilities:**
- Add to `.trivyignore` with justification:
  ```
  # CVE-YYYY-NNNNN: No fix available upstream as of YYYY-MM-DD
  # Tracked at: <upstream issue URL>
  CVE-YYYY-NNNNN
  ```

### 4. Build and Test

```bash
# Build Go plugin
cd source/plugins/go/src && make fbplugin

# Run Go tests
cd source/plugins/go/src && go test -race ./...

# Run all unit tests
./test/unit-tests/test_main.sh

# Re-run vulnerability scan
trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/
```

### 5. Commit and Document

**Commit message format:**
- Single CVE: `fix: patch CVE-YYYY-NNNNN in <package>`
- Multiple CVEs: `fix: remediate critical/high vulnerabilities (#NNNN)`

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/*/go.mod`, `source/plugins/go/input/*/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/linux/setup.sh`
- `.trivyignore`

### Validation
- Build succeeds for Go plugins
- All unit tests pass
- Re-scan shows targeted CVEs resolved
- No new critical/high vulnerabilities introduced
- `.trivyignore` entries (if any) have proper justification

## Examples from This Repo
- `31c5bc4fc` — Longw/3.1.35 address vulnerabilities
- `6f4c31f91` — 3.1.32 CVE fixes
- `9dcd86c76` — CVEs Fix
- `15e97f599` — Fix CVEs and handle intermittent errors in Ginkgo tests
