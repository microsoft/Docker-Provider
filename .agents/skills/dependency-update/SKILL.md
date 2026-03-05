# Dependency Update

## Description
Guides safe updates of Go modules, Ruby gems, and system packages to fix CVEs or upgrade versions.

USE FOR: update dependency, bump package, upgrade library, fix CVE in deps, update go.mod, update gems, renovate
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major framework migration

## Instructions

### When to Apply
When updating Go module versions, Ruby gem versions, or system packages in Dockerfiles — typically driven by CVE fixes or version upgrades.

### Step-by-Step Procedure
1. Identify which dependency files need updating:
   - Go modules: `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
   - Ruby gems: `kubernetes/linux/setup.sh` (gem install commands), `kubernetes/linux/Dockerfile.multiarch`
   - System packages: `kubernetes/linux/Dockerfile.multiarch` (tdnf install), `kubernetes/windows/Dockerfile`
2. For Go modules: `go get <package>@<version>` then `go mod tidy` in EACH module directory
3. Verify the `replace` directive in `source/plugins/go/input/go.mod` still points to `../src`
4. For Ruby gems: update version in setup scripts and Dockerfile
5. Run all unit tests to verify nothing broke

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/setup.sh`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `.trivyignore`

### Validation
- `go build ./...` succeeds in each Go module directory
- `./test/unit-tests/run_go_tests.sh` passes
- `./test/unit-tests/run_ruby_tests.sh` passes
- Trivy scan shows targeted CVEs resolved: `trivy fs --severity CRITICAL,HIGH --scanners vuln .`

## Examples from This Repo
- `31c5bc4fc` — Longw/3.1.35 address vulnerabilities (updated go.mod across all modules)
- `733532d7f` — 3.1.31 CVEs fixes (Go module + system package updates)
- `9dcd86c76` — CVEs Fix (Go module updates + setup.sh changes)

## References
- `build/linux/Makefile` — build targets
- `.github/workflows/pr-checker.yml` — Trivy scan configuration
