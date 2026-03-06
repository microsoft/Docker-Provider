# Dependency Update

## Description
Guide for safely updating Go modules, Ruby gems, and other dependencies in the Docker-Provider agent.

USE FOR: update dependency, bump package, upgrade library, update go.mod, update gems, renovate
DO NOT USE FOR: adding a brand-new dependency, removing a dependency, major version migration requiring code changes

## Instructions

### When to Apply
When upgrading package versions in `go.mod`, `go.sum`, or system-level packages in Dockerfiles.

### Step-by-Step Procedure
1. Identify which dependency to update and the target version.
2. For Go modules:
   - Edit `source/plugins/go/src/go.mod` (and/or `source/plugins/go/input/go.mod`) with the new version.
   - Run `cd source/plugins/go/src && go mod tidy` (repeat for `input/` if applicable).
   - Verify `go.sum` is updated consistently.
3. For Dockerfile packages:
   - Update package versions in `kubernetes/linux/Dockerfile.multiarch` or `kubernetes/windows/Dockerfile`.
4. For test dependencies:
   - Update `test/ginkgo-e2e/*/go.mod` files if test modules share the updated dependency.
5. Run unit tests: `./test/unit-tests/run_go_tests.sh`
6. Build the Docker image: `cd build/linux && make`
7. Verify Trivy scan passes (the PR checker runs this automatically).

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `test/ginkgo-e2e/*/go.mod`

### Validation
- `go mod tidy` exits without errors
- `./test/unit-tests/run_go_tests.sh` passes
- Docker image builds successfully
- Trivy scan shows no new critical/high CVEs

## Examples from This Repo
- `30c4efb` — Fix CVEs though updating go packages and ruby gem (#1414)
- `090c1dd` — Upgrade Fluent Bit to 4.0.9, add missing dependencies (#1535)
- `a71f549` — Fluent bit 4.0.14 (#1601)

## References
- [Go Modules Reference](https://go.dev/ref/mod)
- `build/linux/Makefile` — build targets
