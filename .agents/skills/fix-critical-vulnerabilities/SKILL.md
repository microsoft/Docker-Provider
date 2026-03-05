# Fix Critical Vulnerabilities

## Description
Identifies and fixes critical/high severity vulnerabilities using the repo's own scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, resolve critical CVE, dependency vulnerability fix, container image vulnerability
DO NOT USE FOR: general dependency updates without security motivation, adding new scanning tools, security architecture review (use security-review), threat modeling

## Instructions

### 1. Vulnerability Discovery

This repo uses these scanning tools (configured in CI):
- **Trivy** — Container image + filesystem vulnerability scanning (`.github/workflows/pr-checker.yml`)
  - Configured: `severity: CRITICAL,HIGH`, `vuln-type: os,library`, `exit-code: 1`, `ignore-unfixed: true`
- **CodeQL** — SAST for Go, Python, Ruby (`.github/workflows/codeql-analysis.yml`)
- **DevSkim** — Security pattern scanning (`.github/workflows/devskim.yml`)

Run locally:
```bash
# Scan filesystem for Go/Ruby dependency vulnerabilities
trivy fs --severity CRITICAL,HIGH --scanners vuln .

# Scan specific Go modules
trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/go.mod

# Run Go vulnerability check
cd source/plugins/go/src && govulncheck ./...
```

### 2. Vulnerability Triage

Categorize findings:
- **Direct Go module deps** — in `go.mod` `require` (not `// indirect`): directly fixable
- **Transitive Go deps** — `// indirect` entries: bump parent dependency
- **OS/base image** — Mariner packages in Dockerfile: check for newer base image or `tdnf` updates
- **Ruby gems** — in `setup.sh` gem installs: update version or uninstall if unused
- **Already ignored** — check `.trivyignore` for existing suppression with justification

### 3. Fix Implementation

**Go module vulnerabilities:**
```bash
# Update ALL go.mod files (there are multiple!)
for dir in source/plugins/go/src source/plugins/go/input test/ginkgo-e2e/querylogs test/ginkgo-e2e/containerstatus test/ginkgo-e2e/livenessprobe test/ginkgo-e2e/utils; do
  cd $dir && go get <package>@<fixed-version> && go mod tidy && cd -
done
```

**Ruby gem vulnerabilities:**
- Update gem version in `kubernetes/linux/setup.sh`
- Or uninstall unused gems (e.g., `a1a39074e` — uninstall net-imap gem for CVE fix)

**Container base image vulnerabilities:**
- Update `MARINER_BASE_IMAGE` or `MARINER_DISTROLESS_IMAGE` in `kubernetes/linux/Dockerfile.multiarch`
- Update package versions in `tdnf install` commands
- For Windows: update `kubernetes/windows/Dockerfile`

**Unfixable vulnerabilities:**
- Add to `.trivyignore` with: CVE ID, date, justification, upstream tracking link

### 4. Build and Test

```bash
# Build
cd build/linux && make

# Run all test suites
./test/unit-tests/test_main.sh
./test/unit-tests/run_go_tests.sh
./test/unit-tests/run_ruby_tests.sh

# Re-scan to verify fix
trivy fs --severity CRITICAL,HIGH --scanners vuln .
```

### 5. Commit and Document
- Message format: `fix: patch CVE-YYYY-NNNNN in <package>` or `fix: remediate critical/high vulnerabilities`
- PR description: table of CVEs fixed, scan command, test results

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/linux/setup.sh`
- `kubernetes/windows/Dockerfile`
- `.trivyignore`

### Validation
- Build succeeds for all affected components
- All unit tests pass
- Trivy re-scan shows targeted CVEs resolved
- No new CRITICAL/HIGH vulnerabilities introduced

## Examples from This Repo
- `31c5bc4fc` — address vulnerabilities across all go.mod files
- `6f4c31f91` — 3.1.32 CVE fixes (Dockerfile + setup.sh)
- `a1a39074e` — CVE 202543857: uninstall net-imap gem
- `9dcd86c76` — CVEs Fix (Go module + code changes)
