# Dependency Update

## Description
Safely update Go modules, Ruby gems, base images, or other dependencies in the Container Insights agent.

USE FOR: update dependency, bump package, upgrade library, update go.mod, update base image
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major version migration with breaking changes

## Instructions

### When to Apply
When updating package versions in Go modules, Ruby gems in Dockerfiles, or container base images.

### Step-by-Step Procedure

1. **Identify what to update** — Check the dependency files:
   - Go: `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`
   - Test Go modules: `test/ginkgo-e2e/*/go.mod` (4 files)
   - Ruby gems: gem install commands in `kubernetes/windows/Dockerfile`
   - Base images: `FROM` lines in `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`

2. **Update Go modules**:
   ```bash
   cd source/plugins/go/src
   go get <package>@<new-version>
   go mod tidy
   cd ../input
   go get <package>@<new-version>  # if affected
   go mod tidy
   ```
   Note: `src/go.mod` and `input/go.mod` use `replace` directives — both may need updating.

3. **Update Ruby gems** (in Dockerfile):
   Edit the `gem install` line in the Dockerfile to specify the new version.

4. **Update base images**:
   Update the `FROM` line with the new tag or digest.

5. **Run tests**:
   ```bash
   cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test . && cd ../../../..
   ./test/unit-tests/test_main.sh
   ruby test/unit-tests/test_driver.rb
   ```

6. **Build and scan**:
   ```bash
   cd build/linux && make && cd ../..
   cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test:latest
   trivy image --severity CRITICAL,HIGH test:latest
   ```

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`

### Validation
- `go mod tidy` succeeds without errors
- All unit tests pass
- Docker image builds successfully
- Trivy scan passes (no new critical/high CVEs)

## Examples from This Repo
- `Fluent bit 4.0.14 (#1601)` — Fluent Bit version upgrade
- `Upgrade Fluent Bit to 4.0.9 (cloudnative build)... (#1535)`
- `mdsd version upgrade 1.35.7 (#1492)` — MDSD dependency upgrade
- `update dotnet8 (#1565)` — .NET SDK update
