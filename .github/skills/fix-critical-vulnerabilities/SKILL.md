# Fix Critical Vulnerabilities

## Description
Identifies and fixes critical and high severity vulnerabilities using the repo's own scanning tools (Trivy, CodeQL, DevSkim).

USE FOR: fix critical vulnerability, fix high vulnerability, CVE fix, trivy fix, security vulnerability remediation, patch CVE, fix security scan failure, resolve critical CVE, dependency vulnerability fix, container image vulnerability
DO NOT USE FOR: general dependency updates without security motivation, adding new security scanning tools, security architecture review, threat modeling, low/medium severity vulnerabilities unless explicitly requested

## Instructions

### When to Apply
When the CI pipeline or manual scan reports critical or high severity vulnerabilities that need remediation.

### Step-by-Step Procedure

#### 1. Vulnerability Discovery
This repo uses the following scanning tools:
- **Trivy** — container image and filesystem vulnerability scanning (`.github/workflows/pr-checker.yml`)
- **CodeQL** — static analysis / SAST (`.github/workflows/codeql-analysis.yml`)
- **DevSkim** — security pattern matching (`.github/workflows/devskim.yml`)

Run scans locally:
```bash
# Filesystem scan for Go/Ruby dependencies
trivy fs --severity CRITICAL,HIGH --scanners vuln .

# Specific Go module scan
trivy fs --severity CRITICAL,HIGH --scanners vuln source/plugins/go/src/go.mod
```

#### 2. Vulnerability Triage
Categorize each finding:
- **Direct Go dependency** — listed in `require` block of `go.mod` → directly fixable
- **Transitive Go dependency** — `// indirect` in `go.mod` → bump parent dependency
- **Container base image** — update base image in Dockerfiles
- **OS package** — update in `kubernetes/linux/setup.sh` or Dockerfile
- **Ruby gem** — update or remove in `setup.sh`
- **Already ignored** — check `.trivyignore` for existing suppression with justification

#### 3. Fix Implementation

**Go module vulnerabilities:**
```bash
# Update all go.mod files (6 locations)
cd source/plugins/go/src && go get <package>@<fixed-version> && go mod tidy && cd -
cd source/plugins/go/input && go get <package>@<fixed-version> && go mod tidy && cd -
cd test/ginkgo-e2e/querylogs && go get <package>@<fixed-version> && go mod tidy && cd -
cd test/ginkgo-e2e/containerstatus && go get <package>@<fixed-version> && go mod tidy && cd -
cd test/ginkgo-e2e/livenessprobe && go get <package>@<fixed-version> && go mod tidy && cd -
cd test/ginkgo-e2e/utils && go get <package>@<fixed-version> && go mod tidy && cd -
```

**Ruby gem vulnerabilities:**
- Update version in `kubernetes/linux/setup.sh`
- Or remove unused gems: `gem uninstall <gem> --force` (see existing patterns in `setup.sh`)

**Container base image vulnerabilities:**
- Update `FROM` line in `kubernetes/linux/Dockerfile.multiarch` and/or `kubernetes/windows/Dockerfile`

**Unfixable vulnerabilities:**
- Add to `.trivyignore` with CVE ID, date, and justification comment

#### 4. Build and Test
```bash
# Build Go plugins
cd source/plugins/go/src && make

# Run all unit tests
./test/unit-tests/run_go_tests.sh
./test/unit-tests/run_ruby_tests.sh
./test/unit-tests/test_main.sh

# Re-run vulnerability scan
trivy fs --severity CRITICAL,HIGH --scanners vuln .
```

#### 5. Commit
Follow the repo's commit message format:
- Single CVE: `fix CVE-YYYY-NNNNN in <package> (#PR)`
- Multiple: `address vulnerabilities (#PR)` or `CVE fixes (#PR)`

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- `kubernetes/linux/setup.sh`
- `.trivyignore`

### Validation
- Build succeeds for all affected components
- All existing tests pass
- Re-scan shows targeted CVEs resolved
- No new critical/high vulnerabilities introduced
- `.trivyignore` entries have proper justification
