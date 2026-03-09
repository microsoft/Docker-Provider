# Fix Critical Vulnerabilities Skill

## Name
fix-critical-vulnerabilities

## Description
Patch critical and high severity CVEs in dependencies, base images, or system packages.

## Triggers
- "fix CVE", "patch vulnerability", "trivy failure", "security bump", "critical vulnerability"

## Workflow

### 1. Identify Vulnerabilities
- Check Trivy scan output from CI (`pr-checker.yml`)
- Review `.trivyignore` for temporarily suppressed CVEs
- Check GitHub Security tab for Dependabot/CodeQL alerts

### 2. Determine Fix Strategy

**Go module vulnerabilities:**
```bash
cd source/plugins/go/src
go get <module>@<fixed-version>
go mod tidy
```
Also check and update `source/plugins/go/input/go.mod` and `test/ginkgo-e2e/*/go.mod`.

**Ruby gem vulnerabilities:**
- Update gem version in Dockerfile or setup scripts
- Example: `CVE-202543857: uninstall net-imap gem (#1480)`

**Base image vulnerabilities:**
- Update `MARINER_BASE_IMAGE` or `MARINER_DISTROLESS_IMAGE` in `kubernetes/linux/Dockerfile.multiarch`
- Update Windows base image tag in `kubernetes/windows/Dockerfile`

**System package vulnerabilities:**
- Update package versions in Dockerfile `RUN` commands
- Pin specific versions to avoid regression

### 3. Handle Unfixable CVEs
If no fix is available:
1. Add CVE to `.trivyignore` with justification comment
2. Example: `# to merge trivy scan PR, temporarily ignore CVE-2026-24051 until a fix is available`
3. Create tracking issue for follow-up

### 4. Validate
```bash
# Build image
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test-image

# Run Trivy scan
trivy image --severity CRITICAL,HIGH --vuln-type os,library --exit-code 1 --ignore-unfixed test-image
```

### 5. Test
```bash
# Ensure no regressions
./test/unit-tests/run_go_tests.sh
./test/unit-tests/test_main.sh
cd source/plugins/go/src && go test ./...
```

## Supporting Commits (12 months)
- let trivy fail when cves are detected (#1591)
- Longw/3.1.35 address vulnerabilties (#1605)
- 3.1.32 CVE fixes (#1596)
- 3.1.31 CVEs fixes (#1572)
- Fix CVEs and handle intermittent errors in Ginkgo tests (#1556)
- CVEs Fix (#1526)
- CVE 202543857: uninstall net-imap gem (#1480)
