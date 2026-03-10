# Fix Critical Vulnerabilities

## Description

Identify and fix critical/high severity vulnerabilities in Docker-Provider using the repo's own scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, dependency vulnerability fix, container image vulnerability
DO NOT USE FOR: general dependency updates without security motivation, adding new security tools, security architecture review (use security-review skill), low/medium severity unless explicitly requested

## Instructions

### When to Apply

When Trivy scans, CodeQL, or dependency audits report critical/high CVEs, or when `.trivyignore` suppressions need to be reviewed.

### Step-by-Step Procedure

1. **Discover vulnerabilities using repo scanning tools:**
   - Trivy (container + filesystem): `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
   - Trivy on Go modules: `trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/go.mod`
   - Go vulnerability check: `govulncheck ./...` in each Go module directory
   - CodeQL: `.github/workflows/codeql-analysis.yml` (Go, Python, Ruby)
   - DevSkim: `.github/workflows/devskim.yml`

2. **Parse scan results and categorize:**
   - **Direct Go module vulnerabilities:** Package in `go.mod` `require` (not indirect)
   - **Transitive Go dependencies:** Indirect entries — bump the parent dependency
   - **Ruby gem vulnerabilities:** Gems installed in Dockerfile — update version in Dockerfile `RUN gem install` commands
   - **Container base image vulnerabilities:** Update `FROM` line in Dockerfiles
   - **Already-ignored:** Check `.trivyignore` — if CVE is listed with justification, skip

3. **Apply fixes by type:**

   a. **Go module vulnerabilities:**
   - `cd source/plugins/go/src && go get <package>@<fixed-version> && go mod tidy`
   - Check ALL `go.mod` locations: `source/plugins/go/src/`, `source/plugins/go/input/`, `test/ginkgo-e2e/*/`
   - Verify: `go mod graph | grep <vulnerable-package>` — old version should be gone

   b. **Ruby gem vulnerabilities:**
   - Update gem version in `kubernetes/linux/Dockerfile.multiarch` and `kubernetes/windows/Dockerfile`
   - For removal: add `gem uninstall <gem>` step (as done for `net-imap`)

   c. **Container base image vulnerabilities:**
   - Update base image tag/digest in `kubernetes/linux/Dockerfile.multiarch`
   - Rebuild and re-scan

   d. **Unfixable vulnerabilities:**
   - Add to `.trivyignore` with CVE ID, date, reason, and upstream issue link

4. **Build and test:**
   - `cd build/linux && make` — verify build succeeds
   - `./test/unit-tests/run_go_tests.sh` — Go tests pass
   - `./test/unit-tests/run_ruby_tests.sh` — Ruby tests pass
   - Re-run Trivy scan to confirm CVEs resolved
   - Verify no new critical/high CVEs introduced

5. **Commit:** `fix: patch CVE-YYYY-NNNNN in <package>` or `fix: remediate critical/high vulnerabilities`

### Files Typically Involved

- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- `.trivyignore`
- `.github/workflows/codeql-analysis.yml` (reference for scan config)

### Validation

- Build succeeds for all affected components
- All unit tests pass
- Re-scan shows targeted CVEs resolved
- No new critical/high vulnerabilities introduced
- `.trivyignore` entries (if any) have proper justification

## Examples from This Repo

- `6f4c31f91` — 3.1.32 CVE fixes (#1596)
- `733532d7f` — 3.1.31 CVEs fixes (#1572)
- `30c4efb11` — Fix CVEs through updating go packages and ruby gem (#1414)
- `a1a39074e` — CVE 202543857: uninstall net-imap gem (#1480)
