# Dependency Update

## Description
Guides safe dependency updates across Go modules, Ruby gems, and system packages in the Container Insights agent.

USE FOR: update dependency, bump package, upgrade library, renovate, update go.mod, update gem, bump fluent-bit
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major framework migration (e.g., Fluent Bit major version)

## Instructions

### When to Apply
When updating package versions in `go.mod`, `go.sum`, Ruby gem versions in setup scripts, system packages in Dockerfiles, or Fluent Bit/Telegraf versions.

### Step-by-Step Procedure
1. Identify the dependency to update and the target version.
2. For **Go modules** (`source/plugins/go/src/go.mod`):
   - Run `go get <package>@<version>` in `source/plugins/go/src/`.
   - Run `go mod tidy` to clean up.
   - Check if other `go.mod` files exist (`source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`) and update if they share the dependency.
3. For **Ruby gems** (in `kubernetes/linux/setup.sh`):
   - Update the version in the gem install commands within setup scripts.
4. For **system packages** (in Dockerfiles):
   - Update package versions in `kubernetes/linux/Dockerfile.multiarch` or `kubernetes/windows/Dockerfile`.
5. For **Fluent Bit / Telegraf**:
   - Update version references across Dockerfiles and build scripts.
6. Run all unit tests: Go, Ruby, Bash, PowerShell.
7. If Trivy scanning is configured, verify no new critical/high CVEs.

### Files Typically Involved
- `source/plugins/go/src/go.mod` and `go.sum`
- `source/plugins/go/input/go.mod` and `go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `kubernetes/linux/setup.sh`
- `.trivyignore`

### Validation
- `./test/unit-tests/run_go_tests.sh` passes
- `./test/unit-tests/run_ruby_tests.sh` passes
- Container image builds successfully
- Trivy scan shows no new critical/high CVEs

## Examples from This Repo
- `31c5bc4fc` — Longw/3.1.35 address vulnerabilities (#1605)
- `6f4c31f91` — 3.1.32 CVE fixes (#1596)
- `733532d7f` — 3.1.31 CVEs fixes (#1572)
