# Fix Critical Vulnerabilities

## Description
Identify and fix critical/high CVEs in the Docker-Provider agent using the repo's scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, CVE fix, trivy fix, patch CVE, address vulnerabilities, security bump
DO NOT USE FOR: general code refactoring, feature development, non-security dependency updates

## Instructions

### When to Apply
When Trivy scan reports critical or high CVEs in the container image, or when security scanning identifies vulnerabilities in dependencies.

### Step-by-Step Procedure
1. **Identify vulnerabilities**:
   - Run Trivy locally: `trivy image <image-tag>` or check PR checker workflow output.
   - Note CVE IDs, affected packages, and fixed versions.
   - Check `.trivyignore` for any temporarily suppressed CVEs.
2. **Determine fix approach**:
   - **Go dependency CVE**: Update version in `source/plugins/go/src/go.mod` and `source/plugins/go/input/go.mod`, run `go mod tidy`.
   - **OS package CVE**: Update package version in `kubernetes/linux/Dockerfile.multiarch` or `kubernetes/windows/Dockerfile`.
   - **Ruby gem CVE**: Update or remove affected gem — check if it's used by Fluentd plugins.
   - **Base image CVE**: Update base image tag in Dockerfile.
3. **Apply fixes**:
   - Update the dependency/package to the patched version.
   - If no fix is available, add to `.trivyignore` with a comment explaining the CVE and expected fix timeline.
4. **Test**:
   - Run `./test/unit-tests/run_go_tests.sh` (for Go changes).
   - Build Docker image: `cd build/linux && make`
   - Run Trivy scan to verify the CVE is resolved.
5. **Update release notes** in `ReleaseNotes.md` with CVE fix details.

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `.trivyignore` — for temporary suppression
- `ReleaseNotes.md` — document fixes

### Validation
- Trivy scan shows no critical/high unfixed CVEs
- All unit test suites pass
- Docker image builds successfully
- PR checker workflow passes

## Examples from This Repo
- `31c5bc4` — Longw/3.1.35 address vulnerabilities (#1605)
- `6f4c31f` — 3.1.32 CVE fixes (#1596)
- `733532d` — 3.1.31 CVEs fixes (#1572)
- `15e97f5` — Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)
- `9dcd86c` — CVEs Fix (#1526)

## References
- `.github/workflows/pr-checker.yml` — Trivy scan configuration
- `.trivyignore` — Suppressed CVEs with justifications
- `ReleaseNotes.md` — Release documentation
