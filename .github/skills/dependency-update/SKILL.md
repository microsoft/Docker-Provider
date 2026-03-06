# Dependency Update

## Description
Guides the agent through safely updating Go modules, Ruby gems, and other dependencies in the container agent, including rebuilding and testing.

USE FOR: update dependency, bump package, upgrade library, update go.mod, update gem, renovate, dependabot
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major version migration

## Instructions

### When to Apply
When updating package versions in any of the project's dependency files, typically to fix vulnerabilities or stay current.

### Step-by-Step Procedure
1. Identify the dependency file(s) to update:
   - Go modules: `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
   - Ruby: gem versions in `kubernetes/linux/setup.sh` (installed during container build)
   - Container base image: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
2. Update the dependency version in the appropriate file.
3. For Go modules: run `go mod tidy` in each affected module directory.
4. For Go modules: verify transitive dependencies with `go mod graph | grep <package>`.
5. Build the Go plugins: `cd source/plugins/go/src && make`.
6. Run unit tests: `./test/unit-tests/run_go_tests.sh` and `./test/unit-tests/run_ruby_tests.sh`.
7. Run Trivy scan if updating for vulnerability fixes: `trivy fs --severity CRITICAL,HIGH --scanners vuln .`
8. Update `.trivyignore` if needed (add justification comments for unfixable CVEs).

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- `kubernetes/linux/setup.sh` (Ruby gem installs)
- `.trivyignore`

### Validation
- `go build` succeeds in all affected modules
- All unit tests pass
- Trivy scan shows no new CRITICAL/HIGH CVEs

## Examples from This Repo
- `Longw/3.1.35 address vulnerabilties (#1605)` — Go module updates for CVE fixes
- `3.1.32 CVE fixes (#1596)` — dependency version bumps
- `3.1.31 CVEs fixes (#1572)` — multiple Go module updates

## References
- `source/plugins/go/src/go.mod` — primary Go dependency file
- `.trivyignore` — suppressed CVEs with justifications
