# Fix Critical Vulnerabilities

## Description
Identify and fix critical/high vulnerabilities using the repo's own scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, dependency vulnerability fix, container image vulnerability
DO NOT USE FOR: general dependency updates without security motivation, adding new security tools, threat modeling (use security-review), low/medium severity unless explicitly requested

## Instructions

### When to Apply
When Trivy, CodeQL, or DevSkim reports CRITICAL or HIGH severity findings that must be resolved before merging.

### Step-by-Step Procedure

#### 1. Vulnerability Discovery
This repo uses the following scanning tools (from CI):

- **Trivy** (container + library): Runs in `.github/workflows/pr-checker.yml` with `severity: CRITICAL,HIGH`, `exit-code: 1`, `ignore-unfixed: true`
- **CodeQL**: Runs in `.github/workflows/codeql-analysis.yml` for Go, Python, Ruby
- **DevSkim**: Runs in `.github/workflows/devskim.yml` for security pattern matching

Run locally:
```bash
# Build the container image first
cd build/linux && make
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test:latest

# Scan container image
trivy image --severity CRITICAL,HIGH --ignore-unfixed test:latest

# Scan Go dependencies
trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/

# Scan all Go modules
for mod in source/plugins/go/src source/plugins/go/input test/ginkgo-e2e/utils; do
  echo "=== Scanning $mod ==="
  trivy fs --severity CRITICAL,HIGH --scanners vuln "$mod/"
done
```

#### 2. Vulnerability Triage
- **Direct Go dependencies**: Listed in `go.mod` `require` block — directly fixable
- **Transitive Go dependencies**: `// indirect` entries — bump parent dependency
- **OS/base image packages**: Azure Linux 3.0 packages in `setup.sh` / Dockerfile
- **Ruby gems**: Installed in `setup.sh` — check for newer gem versions

#### 3. Fix Implementation

**Go module vulnerabilities:**
```bash
cd source/plugins/go/src && go get <package>@<fixed-version> && go mod tidy
cd source/plugins/go/input && go get <package>@<fixed-version> && go mod tidy
# Update test modules if affected
cd test/ginkgo-e2e/utils && go get <package>@<fixed-version> && go mod tidy
```

**Container base image vulnerabilities:**
- Check for newer Azure Linux base image tags in `Dockerfile.multiarch`
- Update `FROM` line if newer tag available

**OS package vulnerabilities:**
- Update package versions in `kubernetes/linux/setup.sh` (tdnf install)
- For unfixed upstream packages, document and accept risk

**Ruby gem vulnerabilities:**
- Update gem version in `kubernetes/linux/setup.sh` install commands
- Example: `CVE 202543857: uninstall net-imap gem (#1480)`

#### 4. Build and Test
```bash
# Build
cd build/linux && make

# Run unit tests
cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .
./test/unit-tests/run_ruby_tests.sh
./test/unit-tests/test_main.sh

# Rebuild and re-scan
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test:latest
trivy image --severity CRITICAL,HIGH --ignore-unfixed test:latest
```

#### 5. Commit
Follow the repo's commit pattern:
- Single CVE: `fix CVE-YYYY-NNNNN in <package> (#PR)`
- Batch: `CVE fixes (#PR)` or `address vulnerabilities (#PR)`

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/linux/setup.sh`
- `.github/workflows/pr-checker.yml` (to understand scan flags)

### Validation
- Build succeeds for Linux: `cd build/linux && make`
- All unit tests pass
- Re-scan shows targeted CVEs resolved
- No new CRITICAL/HIGH vulnerabilities introduced
