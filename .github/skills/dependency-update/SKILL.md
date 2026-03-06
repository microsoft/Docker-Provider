# Dependency Update

## Description
Update Go modules, Ruby gems, or system packages to fix vulnerabilities or stay current.

USE FOR: update dependency, bump package, upgrade library, update go.mod, update gems, CVE dependency fix
DO NOT USE FOR: adding a brand new dependency, major version migration, removing a dependency

## Instructions

### When to Apply
When a dependency needs updating for security (CVE fix), compatibility, or currency reasons. This is the most common PR type in this repo.

### Step-by-Step Procedure
1. **Identify the dependency file(s)** to update:
   - Go: `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
   - Ruby: gems installed in `kubernetes/linux/setup.sh`
   - System packages: `kubernetes/linux/Dockerfile.multiarch` (tdnf), `kubernetes/windows/Dockerfile`

2. **Update Go dependencies:**
   ```bash
   cd source/plugins/go/src && go get <package>@<version> && go mod tidy
   cd source/plugins/go/input && go get <package>@<version> && go mod tidy
   ```

3. **Update test Go dependencies (if affected):**
   ```bash
   cd test/ginkgo-e2e/utils && go get <package>@<version> && go mod tidy
   ```

4. **Run unit tests:**
   ```bash
   cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .
   ./test/unit-tests/run_ruby_tests.sh
   ```

5. **Build and scan:**
   ```bash
   cd build/linux && make
   # Then build Docker image and run Trivy
   ```

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/linux/setup.sh`

### Validation
- `go mod tidy` runs without errors for all Go modules
- Unit tests pass: `GOUNITTEST=true ISTEST=true go test .`
- Docker image builds successfully
- Trivy scan shows no new CRITICAL/HIGH vulnerabilities

## Examples from This Repo
- `3.1.32 CVE fixes (#1596)` — Go module and system package updates
- `3.1.31 CVEs fixes (#1572)` — Multi-module dependency updates
- `Longw/Fix CVEs though updating go packages and ruby gem (#1414)` — Cross-language dependency update
