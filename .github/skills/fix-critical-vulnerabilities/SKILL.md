# Fix Critical Vulnerabilities

## Purpose
Identify and fix critical and high severity vulnerabilities in the Docker-Provider container images and dependencies using the repository's own scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, dependency vulnerability fix, container image vulnerability
DO NOT USE FOR: general dependency updates without security motivation, adding new security scanning tools, security architecture review (use security-review), low/medium severity unless explicitly requested

## When to Use
- When Trivy scan in `pr-checker.yml` reports critical/high CVEs
- When Dependabot or manual review identifies vulnerable dependencies
- When container base image has known vulnerabilities
- When Go modules or Ruby gems have published CVEs

## Inputs
- CVE ID(s) or vulnerability scan report
- Affected component (Go modules, container base image, OS packages)

## Outputs
- Updated dependency files (`go.mod`, `go.sum`, Dockerfile base images)
- Updated `.trivyignore` if CVEs cannot be fixed immediately
- Passing Trivy scan on rebuilt container image

## Steps

1. **Run vulnerability scan** using the repo's configured tools:
   ```bash
   # Scan Go modules
   cd source/plugins/go/src && go list -m -json all | head -50
   cd test/ginkgo-e2e/utils && go list -m -json all | head -50

   # Scan container image (if built locally)
   trivy image --severity CRITICAL,HIGH <image-tag>

   # Scan filesystem for dependency vulnerabilities
   trivy fs --severity CRITICAL,HIGH --scanners vuln .
   ```

2. **Triage vulnerabilities** by type:
   - **Go module vulnerabilities:** Check if package is direct or indirect in `go.mod`
   - **Container base image:** Check `kubernetes/linux/Dockerfile.multiarch` and `kubernetes/windows/Dockerfile` for base image tags
   - **OS packages:** Check `kubernetes/linux/setup.sh` for `tdnf install` packages
   - **Already ignored:** Check `.trivyignore` for existing entries with justification

3. **Fix Go module vulnerabilities:**
   ```bash
   # Update specific package
   cd source/plugins/go/src && go get <package>@<fixed-version> && go mod tidy

   # Update ALL Go modules in the repo
   for dir in source/plugins/go/src source/plugins/go/input test/ginkgo-e2e/utils test/ginkgo-e2e/querylogs test/ginkgo-e2e/containerstatus test/ginkgo-e2e/livenessprobe; do
     cd $dir && go get -u ./... && go mod tidy && cd -
   done
   ```

4. **Fix container base image vulnerabilities:**
   - Update base image tag in `kubernetes/linux/Dockerfile.multiarch`
   - Update base image tag in `kubernetes/windows/Dockerfile`
   - Check `kubernetes/linux/setup.sh` for package versions that need updating

5. **Fix OS package vulnerabilities:**
   - Update package versions in `kubernetes/linux/setup.sh` (`tdnf install`)
   - For Ruby: Update Ruby version in setup.sh if Ruby has CVEs

6. **Handle unfixable vulnerabilities:**
   - Add to `.trivyignore` with justification:
     ```
     # CVE-YYYY-NNNNN: No fix available upstream as of YYYY-MM-DD
     # Tracked at: <upstream issue URL>
     CVE-YYYY-NNNNN
     ```

7. **Build and test:**
   ```bash
   # Build Go plugins
   cd source/plugins/go/src && make fbplugin

   # Run unit tests
   ./test/unit-tests/run_go_tests.sh
   ./test/unit-tests/test_main.sh

   # Re-scan to verify fixes
   trivy fs --severity CRITICAL,HIGH --scanners vuln .
   ```

## Validation
- Build succeeds for all affected components
- All unit tests pass (Go, Bash, Ruby, PowerShell)
- Re-scan shows targeted CVEs resolved
- No new critical/high vulnerabilities introduced
- `.trivyignore` entries have proper justification

## Risks and Guardrails
- Major version bumps may introduce breaking API changes — check changelogs
- Go module updates may require updating multiple `go.mod` files across the repo
- Container base image updates may change available OS packages
- Always re-run Trivy after fixes to confirm resolution

## Examples from This Repo
- `3.1.32 CVE fixes (#1596)` — Batch CVE remediation
- `3.1.31 CVEs fixes (#1572)` — Dependency updates for security
- `Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)` — Combined CVE fix with test improvements
- `CVEs Fix (#1526)` — Go module security updates

## References
- `.trivyignore` — Current CVE ignore list
- `.github/workflows/pr-checker.yml` — Trivy scan configuration
- `kubernetes/linux/setup.sh` — OS package installation
- `kubernetes/linux/Dockerfile.multiarch` — Linux container build
