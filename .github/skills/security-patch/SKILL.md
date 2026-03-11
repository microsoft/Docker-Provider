# Skill: Security Patch

## Overview
Remediate security vulnerabilities discovered by Trivy, CodeQL, or DevSkim scans. Patches target Go module CVEs, container base image vulnerabilities, and OS-level package issues.

## Scope
- **Go modules**: `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
- **Container base images**: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- **OS packages**: `tdnf install` in Dockerfiles, `kubernetes/linux/setup.sh`
- **Trivy exceptions**: `.trivyignore` at repo root
- **Security workflows**: `.github/workflows/codeql-analysis.yml`, `.github/workflows/devskim.yml`

## Procedures

### Go Module CVE Remediation
```bash
cd source/plugins/go/src
go get <vulnerable-module>@<fixed-version>
go mod tidy

cd ../input
go get <vulnerable-module>@<fixed-version>
go mod tidy
```
Check all `go.mod` files in the repo — test modules under `test/ginkgo-e2e/` may share the same vulnerable dependency. Commit both `go.mod` and `go.sum`.

### Container Base Image Updates
Edit the `FROM` line in `kubernetes/linux/Dockerfile.multiarch`:
```dockerfile
FROM mcr.microsoft.com/azurelinux/base/core:3.0  # builder stage
FROM mcr.microsoft.com/azurelinux/distroless/base:3.0  # runtime stage
```
For version-pinned base images, update to the patched tag. Rebuild and verify all `tdnf install` packages remain available.

### OS Package Patches (tdnf)
Update pinned versions in Dockerfile `tdnf install` directives or `kubernetes/linux/setup.sh`. For Windows, update Chocolatey package versions in `kubernetes/windows/Dockerfile`. Example for removing a vulnerable Ruby gem:
```dockerfile
RUN gem uninstall rexml -v 3.2.5 --force
```

### .trivyignore Management
When a CVE cannot be immediately fixed (e.g., upstream hasn't released a patch), add it to `.trivyignore`:
```
# CVE-2026-24051 - pending upstream fix, tracked in issue #XXXX
CVE-2026-24051
```
Each entry must include a comment with justification and a tracking reference. Review `.trivyignore` regularly and remove entries once patches are available.

### Security Scanning Validation
- **Trivy** (container + filesystem): `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
- **CodeQL**: Runs on push/PR to `ci_prod`; scans Go, Python, Ruby (`.github/workflows/codeql-analysis.yml`)
- **DevSkim**: Static analysis for security anti-patterns (`.github/workflows/devskim.yml`)

All three tools report to the GitHub Security tab via SARIF uploads.

## Validation Checklist
1. **Build**: `cd build/linux && make`
2. **Go unit tests**: `./test/unit-tests/run_go_tests.sh`
3. **Ruby unit tests**: `ruby test/unit-tests/test_driver.rb`
4. **Trivy re-scan**: `trivy fs --severity CRITICAL,HIGH --scanners vuln .` — confirm CVE is resolved
5. **Docker build**: Rebuild image and run `trivy image <image:tag>`
6. **CI**: All checks in `run_unit_tests.yml` and `pr-checker.yml` must pass

## Commit Convention
Reference the CVE ID and affected component. Example:
```
Fix CVE-2024-34156 by updating golang.org/x/text to v0.19.0 (#1234)
```

## Pitfalls
- Updating a Go module in one `go.mod` but not others causes build inconsistencies.
- Base image updates can remove packages needed at runtime — always test the built container.
- Adding CVEs to `.trivyignore` without justification or tracking makes them permanent tech debt.
- Windows Dockerfile uses Chocolatey, not tdnf — different patching workflow.
- CodeQL and DevSkim run on `ci_prod` branch; test locally before pushing.
