# Skill: Fix Critical Vulnerabilities

## Overview
Triage and remediate critical and high-severity vulnerabilities in the Docker-Provider monitoring agent. This covers Go module CVEs, container base image vulnerabilities, OS package issues, and Ruby gem vulnerabilities. Every fix must pass build, test, and re-scan validation.

## Scanning Tools

### Trivy (Primary Scanner)
- **Container scan**: `trivy image <image:tag>` — scans the built container image
- **Filesystem scan**: `trivy fs --severity CRITICAL,HIGH --scanners vuln .` — scans source code dependencies
- **Exception file**: `.trivyignore` at repo root for accepted/deferred CVEs
- **Usage**: Run locally before pushing; also integrated in CI pipelines

### CodeQL (Static Analysis)
- **Config**: `.github/workflows/codeql-analysis.yml`
- **Languages**: Go, Python, Ruby
- **Trigger**: Push/PR to `ci_prod` branch, weekly schedule (Sunday 00:39 UTC)
- **Output**: SARIF results uploaded to GitHub Security tab
- **Focus**: Code-level vulnerabilities (injection, unsafe deserialization, path traversal)

### DevSkim (Pattern Matching)
- **Config**: `.github/workflows/devskim.yml`
- **Trigger**: Push/PR to `ci_prod` branch, weekly schedule
- **Output**: SARIF results uploaded to GitHub Security tab
- **Focus**: Hardcoded credentials, insecure crypto, dangerous functions

## Remediation Procedures

### Go Module Vulnerabilities
Multiple `go.mod` files exist in the repo. Update all affected modules:

```bash
# Primary output plugin
cd source/plugins/go/src
go get <vulnerable-package>@<fixed-version>
go mod tidy

# Input plugins
cd ../input
go get <vulnerable-package>@<fixed-version>
go mod tidy

# Test modules (if affected)
cd ../../../../test/ginkgo-e2e/livenessprobe
go get <vulnerable-package>@<fixed-version>
go mod tidy
```

**All `go.mod` locations:**
- `source/plugins/go/src/go.mod` — output plugins (oms.go, telemetry.go)
- `source/plugins/go/input/go.mod` — input plugins (container inventory, perf)
- `test/ginkgo-e2e/livenessprobe/go.mod`
- `test/ginkgo-e2e/utils/go.mod`
- `test/ginkgo-e2e/containerstatus/go.mod`
- `test/ginkgo-e2e/querylogs/go.mod`

Always commit both `go.mod` and `go.sum`. Verify with `go build ./...` in each module directory.

### Container Base Image Vulnerabilities
The Linux image uses Azure Linux 3.0:
```dockerfile
# Builder stage
FROM mcr.microsoft.com/azurelinux/base/core:3.0

# Runtime stage (distroless)
FROM mcr.microsoft.com/azurelinux/distroless/base:3.0
```

**Update procedure:**
1. Check for updated base image tags on MCR
2. Update `FROM` lines in `kubernetes/linux/Dockerfile.multiarch`
3. For Windows: update `mcr.microsoft.com/windows/servercore` tag in `kubernetes/windows/Dockerfile`
4. Rebuild and verify all package installs still work
5. Re-scan the built image with `trivy image`

### OS Package Updates (tdnf)
Vulnerable OS packages installed via `tdnf` in `kubernetes/linux/Dockerfile.multiarch`:
```dockerfile
RUN tdnf install -y \
    build-essential wget curl sudo net-tools cronie rsyslog \
    dmidecode gnupg make logrotate busybox gawk tar \
    ca-certificates postgresql-libs
```

**Update procedure:**
1. Identify the vulnerable package from Trivy output
2. Pin to a fixed version: `tdnf install -y package-name-<version>`
3. Or update the base image if the fix is in the base layer
4. Additional packages in `kubernetes/linux/setup.sh` (ca-certificates-microsoft, Ruby build dependencies)

### Ruby Gem Vulnerabilities
Ruby gems are managed in Dockerfiles and `setup.sh`:
```bash
# Example: Remove vulnerable gem version
gem uninstall rexml -v 3.2.5 --force
gem uninstall net-imap --force
```
For the Windows Dockerfile, gems are managed via `gem install`/`gem uninstall` in the Dockerfile directly.

### .trivyignore Management
When a CVE cannot be immediately fixed:
```
# CVE-2026-24051 - Pending upstream fix in azurelinux/base image
# Tracked: https://github.com/microsoft/Docker-Provider/issues/XXXX
# Added: 2025-01-15, Review by: 2025-02-15
CVE-2026-24051
```

**Rules for .trivyignore entries:**
1. One CVE per line
2. Comment above with: CVE description, justification, tracking issue, date added, review date
3. Review and prune monthly — remove entries when patches become available
4. Never ignore a CVE without a tracking issue

## Build Verification
After applying fixes, verify the full build pipeline:

```bash
# 1. Go build (both plugin directories)
cd source/plugins/go/src && go build ./...
cd ../input && go build ./...

# 2. Full build
cd build/linux && make

# 3. Docker build (if base image or package changes)
docker build -f kubernetes/linux/Dockerfile.multiarch .
```

## Test Verification
Run all five test suites to ensure fixes don't introduce regressions:

```bash
# Go unit tests
./test/unit-tests/run_go_tests.sh

# Ruby unit tests
ruby test/unit-tests/test_driver.rb

# Bash unit tests
./test/unit-tests/test_main.sh

# Python E2E tests (requires live cluster)
pytest test/e2e/src/tests/

# Ginkgo E2E tests (requires live cluster)
cd test/ginkgo-e2e/<suite> && ginkgo run
```

At minimum, Go, Ruby, and Bash unit tests must pass. E2E tests should be run for base image or significant dependency changes.

## Re-Scan Verification
After fixing, confirm the vulnerability is resolved:

```bash
# Filesystem scan for dependency CVEs
trivy fs --severity CRITICAL,HIGH --scanners vuln .

# Image scan for container-level CVEs (after docker build)
trivy image --severity CRITICAL,HIGH <image:tag>

# Verify .trivyignore doesn't mask the fixed CVE
grep -v "^#" .trivyignore  # Review remaining exceptions
```

## Commit Convention
Reference the CVE and affected component. Example:
```
Fix CVE-2024-34156 in golang.org/x/text across all Go modules (#1234)
```
```
Update azurelinux base image to 3.0-20250115 for CVE-2025-XXXXX (#1235)
```
```
Remove vulnerable rexml 3.2.5 gem from Windows Dockerfile (#1236)
```

## Triage Priority
| Severity | SLA | Action |
|----------|-----|--------|
| Critical (CVSS ≥ 9.0) | Immediate | Fix and release ASAP |
| High (CVSS 7.0–8.9) | 1 sprint | Fix in next release cycle |
| Medium (CVSS 4.0–6.9) | 2 sprints | Schedule for upcoming release |
| Low (CVSS < 4.0) | Best effort | Add to backlog |

If a critical fix cannot be applied immediately, add to `.trivyignore` with justification and a tracking issue, then schedule the fix.

## Pitfalls
- Updating one `go.mod` but not others creates inconsistent builds — always check all six module files.
- Base image updates may remove packages or change library versions — always rebuild and test.
- Trivy filesystem scan and image scan may report different CVEs — run both.
- `.trivyignore` entries without review dates become permanent tech debt.
- Windows and Linux containers have different package managers (Chocolatey vs tdnf) and different Ruby versions — fixes rarely apply identically to both.
- CodeQL and DevSkim only run on `ci_prod` branch — test security scanning results locally before assuming CI will catch everything.
