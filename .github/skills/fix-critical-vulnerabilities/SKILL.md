# Fix Critical Vulnerabilities

## Description
Identify and fix critical/high vulnerabilities using the repo's Trivy scanning pipeline.

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, dependency vulnerability fix
DO NOT USE FOR: general dependency updates, adding new security tools, security architecture review, threat modeling

## Instructions

### When to Apply
When Trivy scans or CI pipeline flags critical/high CVEs in container images, Go modules, or system packages.

### Step-by-Step Procedure

#### 1. Vulnerability Discovery

This repo uses **Trivy** for vulnerability scanning (integrated into CI pipeline).

- Run Trivy on Go modules: `trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/`
- Run Trivy on container image: `trivy image --severity CRITICAL,HIGH <image-name>`
- Check current `.trivyignore` for already-accepted CVEs.

#### 2. Vulnerability Triage

a. **Go module vulnerabilities** — Direct dependencies in `source/plugins/go/src/go.mod`:
   - Priority: HIGH — directly fixable with `go get`

b. **Transitive Go dependencies** — Indirect entries in `go.mod`:
   - Priority: MEDIUM — may require bumping parent dependency

c. **OS/base image vulnerabilities** — Azure Linux 3.0 packages in Dockerfile:
   - Check `kubernetes/linux/Dockerfile.multiarch` for base image tag
   - Check if newer Azure Linux image is available

d. **Ruby gem vulnerabilities** — Gems installed in `kubernetes/linux/setup.sh`:
   - Update or uninstall vulnerable gems

e. **Already-ignored CVEs** — Check `.trivyignore`:
   - If CVE has justification, skip
   - If no justification, flag for review

#### 3. Fix Implementation

a. **Go module vulnerabilities:**
   - `cd source/plugins/go/src && go get <package>@<fixed-version>`
   - `go mod tidy`
   - Check other `go.mod` files: `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
   - Verify: `go mod graph | grep <vulnerable-package>` — old version should be gone

b. **Ruby gem vulnerabilities:**
   - Update gem version in install scripts or uninstall vulnerable gem
   - Example: `a1a39074e` — CVE 202543857: uninstall net-imap gem (#1480)

c. **Container base image vulnerabilities:**
   - Update `MARINER_BASE_IMAGE` or `MARINER_DISTROLESS_IMAGE` ARGs in Dockerfile
   - Rebuild and re-scan

d. **Unfixable vulnerabilities:**
   - Add to `.trivyignore` with justification:
     ```
     # No fix available as of YYYY-MM-DD. Tracking: <link>
     CVE-YYYY-NNNNN
     ```

#### 4. Build and Test

- Run Go unit tests: `./test/unit-tests/run_go_tests.sh`
- Run Ruby unit tests: `./test/unit-tests/run_ruby_tests.sh`
- Run Bash unit tests: `./test/unit-tests/test_main.sh`
- Build container image and re-run Trivy scan
- Verify targeted CVEs are resolved and no new critical/high CVEs introduced

#### 5. Commit

- Single CVE: `fix: patch CVE-YYYY-NNNNN in <package>`
- Multiple: `fix: remediate critical/high vulnerabilities for <version>`

### Files Typically Involved
- `source/plugins/go/src/go.mod` and `go.sum`
- `source/plugins/go/input/go.mod` and `go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/linux/setup.sh`
- `.trivyignore`

### Validation
- All unit tests pass
- Trivy re-scan shows targeted CVEs resolved
- No new critical/high vulnerabilities introduced
- `.trivyignore` entries have proper justification

## Examples from This Repo
- `31c5bc4fc` — Longw/3.1.35 address vulnerabilities (#1605)
- `6f4c31f91` — 3.1.32 CVE fixes (#1596)
- `15e97f599` — Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)
- `9dcd86c76` — CVEs Fix (#1526)
