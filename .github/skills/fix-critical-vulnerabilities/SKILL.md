# Fix Critical Vulnerabilities

## Description
Identify and fix critical/high severity vulnerabilities in the Container Insights agent using the repo's own scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, dependency vulnerability fix
DO NOT USE FOR: general dependency updates without security motivation, adding new security scanning tools, security architecture review (use security-review skill), low/medium severity vulnerabilities unless explicitly requested

## Instructions

### When to Apply
When Trivy scan fails in CI, when new CVEs are reported against dependencies, or when proactively remediating known vulnerabilities.

### Step-by-Step Procedure

1. **Run vulnerability scans** using the repo's tools:
   ```bash
   # Trivy filesystem scan (Go modules, Ruby gems)
   trivy fs --severity CRITICAL,HIGH --scanners vuln .

   # Trivy on specific Go modules
   trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/go.mod
   trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/input/go.mod

   # Go vulnerability check
   cd source/plugins/go/src && govulncheck ./...
   ```

2. **Triage findings**:
   - Check `.trivyignore` for already-suppressed CVEs with justification
   - Classify: direct dependency vs. transitive vs. base image vulnerability
   - Priority: Direct dependencies → base image → transitive

3. **Fix by vulnerability type**:

   a. **Go module vulnerabilities**:
      ```bash
      cd source/plugins/go/src
      go get <package>@<fixed-version>
      go mod tidy
      cd ../input
      go get <package>@<fixed-version>
      go mod tidy
      ```
      Also update test module go.mod files in `test/ginkgo-e2e/*/go.mod` if affected.

   b. **Ruby gem vulnerabilities** (in Dockerfiles):
      Update gem versions in `kubernetes/windows/Dockerfile` or `kubernetes/linux/Dockerfile.multiarch`.
      Example: `gem install <gem> -v <fixed-version>`

   c. **Base image vulnerabilities**:
      Update `FROM` line in `kubernetes/linux/Dockerfile.multiarch` or `kubernetes/windows/Dockerfile`.
      Verify new base image tag is available.

   d. **OS package vulnerabilities**:
      Update package versions in Dockerfile `tdnf install` or `apt-get install` commands.

   e. **Unfixable vulnerabilities**:
      Add to `.trivyignore` with justification:
      ```
      # No fix available upstream as of YYYY-MM-DD — <link to upstream issue>
      CVE-YYYY-NNNNN
      ```

4. **Build and test**:
   ```bash
   # Linux build
   cd build/linux && make && cd ../..

   # Go unit tests
   cd source/plugins/go/src && go generate && GOUNITTEST=true ISTEST=true go test . && cd ../../../..

   # Bash unit tests
   ./test/unit-tests/test_main.sh

   # Docker image build + Trivy re-scan
   cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test:latest
   trivy image --severity CRITICAL,HIGH test:latest
   ```

5. **Verify fixes**:
   - Re-run Trivy scan — targeted CVEs should be resolved
   - Confirm no NEW critical/high CVEs introduced
   - All existing tests pass

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod` (4 modules)
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `.trivyignore`

### Validation
- Build succeeds (`cd build/linux && make`)
- All unit tests pass (Go, Bash, Ruby)
- Trivy re-scan shows targeted CVEs resolved
- No new critical/high vulnerabilities introduced
- `.trivyignore` entries have justification comments

## Examples from This Repo
- `3.1.32 CVE fixes (#1596)` — Go module and base image CVE remediation
- `3.1.31 CVEs fixes (#1572)` — Batch CVE fix across multiple dependencies
- `CVEs Fix (#1526)` — Dependency version bumps for security
- `CVE 202543857: uninstall net-imap gem (#1480)` — Ruby gem CVE fix in Dockerfile
