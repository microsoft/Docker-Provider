# Dependency Update

## Description

Safely update Go modules, Ruby gems, and container base images in Docker-Provider.

USE FOR: update dependency, bump package, upgrade library, update go.mod, update gems, update base image
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major version migration

## Instructions

### When to Apply

When dependencies need updating for security patches, new features, or compatibility.

### Step-by-Step Procedure

1. Identify which dependency files to modify:
   - **Go modules:** `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
   - **Ruby gems:** Version pinned in `kubernetes/linux/Dockerfile.multiarch` and `kubernetes/windows/Dockerfile`
   - **Base images:** `FROM` lines in Dockerfiles
   - **Helm chart deps:** `charts/*/Chart.yaml`

2. Update the specific dependency:
   - Go: `cd <module-dir> && go get <package>@<version> && go mod tidy`
   - Ruby: Update version in Dockerfile `gem install` commands
   - Base image: Update tag/digest in `FROM` line

3. Run tests:
   - `./test/unit-tests/run_go_tests.sh`
   - `./test/unit-tests/run_ruby_tests.sh`
   - `cd build/linux && make`

4. Verify no new vulnerabilities: `trivy fs --severity CRITICAL,HIGH --scanners vuln .`

### Files Typically Involved

- `source/plugins/go/src/go.mod`, `go.sum`
- `source/plugins/go/input/go.mod`, `go.sum`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`

### Validation

- Build succeeds, all unit tests pass, no new CVEs introduced.

## Examples from This Repo

- `a71f549e0` — Fluent bit 4.0.14 (#1601)
- `df85af818` — Upgrade Telegraf 1.34.3 (#1434)
- `388f83c97` — mdsd version upgrade 1.35.7 (#1492)
