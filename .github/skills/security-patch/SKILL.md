# Security Patch

## Description
Guides applying security fixes including CVE remediation, vulnerability patching, and security configuration updates.

USE FOR: security fix, CVE patch, vulnerability fix, security update, patch vulnerability
DO NOT USE FOR: general dependency updates without security motivation, security architecture review, threat modeling

## Instructions

### When to Apply
When addressing security vulnerabilities, CVEs, or security-related configuration issues.

### Step-by-Step Procedure
1. Identify the vulnerability source:
   - Go module CVEs → update `go.mod` files
   - Ruby gem CVEs → update gem versions in `kubernetes/linux/setup.sh`
   - Container base image CVEs → update base image in Dockerfiles
   - OS package CVEs → update packages in `setup.sh` or Dockerfile
2. Apply the fix:
   - For Go: `go get <package>@<fixed-version>` then `go mod tidy`
   - For Ruby: update gem version in setup script
   - For base image: update `FROM` line in Dockerfile
   - For OS packages: update `tdnf install` commands
3. Update ALL affected go.mod files (there are 6 in this repo).
4. Rebuild: `cd source/plugins/go/src && make`
5. Run all unit tests.
6. Run Trivy scan to verify fix: `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
7. Update `.trivyignore` for unfixable CVEs (with date and justification).
8. Remove gems with known CVEs that are not used (see `setup.sh` patterns like `gem uninstall net-imap --force`).

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/linux/setup.sh`
- `.trivyignore`

### Validation
- Trivy scan shows targeted CVEs are resolved
- No new CRITICAL/HIGH CVEs introduced
- All unit tests pass
- Container image builds successfully

## Examples from This Repo
- `Longw/3.1.35 address vulnerabilties (#1605)` — multi-CVE fix
- `3.1.32 CVE fixes (#1596)` — CVE remediation
- `3.1.31 CVEs fixes (#1572)` — vulnerability fixes
- `Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)` — CVE + test fixes

## References
- `.trivyignore` — suppressed CVEs
- `.github/workflows/pr-checker.yml` — Trivy CI scan configuration
