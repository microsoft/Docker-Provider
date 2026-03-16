# Fix Critical Vulnerabilities

## Description
Identify and fix critical/high vulnerabilities using the repo's own scanning tools.

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure
DO NOT USE FOR: general dependency updates, adding new security tools, security architecture review, threat modeling

## Instructions

### 1. Vulnerability Discovery

**Scanning tools in this repo:**
- **Trivy** — Container image and filesystem scanning (configured in `.github/workflows/pr-checker.yml`)
- **CodeQL** — SAST for Go, Python, Ruby (`.github/workflows/codeql-analysis.yml`)
- **DevSkim** — Security pattern matching (`.github/workflows/devskim.yml`)

**Run scans locally:**
```bash
# Filesystem scan for Go/Ruby dependencies
trivy fs --severity CRITICAL,HIGH --scanners vuln .

# Specific Go module scan
trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/go.mod

# Container image scan (after building)
trivy image --severity CRITICAL,HIGH <image-tag>
```

### 2. Vulnerability Triage

**a. Direct Go module vulnerabilities**
- Check `source/plugins/go/src/go.mod` and `source/plugins/go/input/go.mod`
- Also check test modules: `test/ginkgo-e2e/*/go.mod`
- Priority: HIGH — directly fixable

**b. Ruby gem vulnerabilities**
- Check gem installations in Dockerfiles
- Priority: HIGH for runtime gems

**c. Container base image vulnerabilities**
- Check `kubernetes/linux/Dockerfile.multiarch` — Azure Linux / Mariner base
- Check `kubernetes/windows/Dockerfile` — Windows base
- Priority: HIGH if base image update available

**d. Already-ignored CVEs**
- Check `.trivyignore` — currently suppresses `CVE-2026-24051`
- If a CVE is already ignored with justification, skip it

### 3. Fix Implementation

**Go module vulnerabilities:**
```bash
cd source/plugins/go/src
go get <package>@<fixed-version>
go mod tidy
# Repeat for source/plugins/go/input/ and test modules if affected
```

**Ruby gem vulnerabilities:**
- Update gem version in Dockerfile install commands
- Or uninstall the gem if not needed (e.g., `gem uninstall net-imap`)

**Container base image:**
- Update the `FROM` line in `kubernetes/linux/Dockerfile.multiarch`
- Update Mariner package versions

**Unfixable CVEs:**
- Add to `.trivyignore` with justification comment and date

### 4. Build and Test

```bash
# Build
cd build/linux && make

# Run tests
./test/unit-tests/test_main.sh
./test/unit-tests/run_go_tests.sh
./test/unit-tests/run_ruby_tests.sh

# Re-scan
trivy fs --severity CRITICAL,HIGH --scanners vuln .
```

### 5. Commit
- Format: `Fix CVEs in <component> (#PR)`
- Include table of CVEs fixed in PR description

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `.trivyignore`

## Examples from This Repo
- `31c5bc4fc` — Longw/3.1.35 address vulnerabilities (#1605)
- `6f4c31f91` — 3.1.32 CVE fixes (#1596)
- `733532d7f` — 3.1.31 CVEs fixes (#1572)
- `15e97f599` — Fix CVEs and handle intermittent errors (#1556)
- `a1a39074e` — CVE 202543857: uninstall net-imap gem (#1480)
