# Dependency Update

## Description
Guide for updating dependencies in Docker-Provider (Go modules, Ruby gems, Fluent Bit, Telegraf, MDSD, Mariner base image).

USE FOR: update dependency, bump package, upgrade library, update go modules, upgrade fluent-bit, upgrade telegraf, upgrade mdsd, mariner upgrade
DO NOT USE FOR: adding a brand new dependency, CVE-driven updates (use fix-critical-vulnerabilities), major architecture changes

## Instructions

### When to Apply
When upgrading component versions (Fluent Bit, Telegraf, MDSD, Mariner base) or Go/Ruby dependencies.

### Step-by-Step Procedure
1. Identify which dependency to update and the target version.
2. For Go modules: run `go get <package>@<version>` in the correct `go.mod` directory, then `go mod tidy`.
3. For Ruby gems: update the gem version in the relevant install scripts or Dockerfile.
4. For Fluent Bit/Telegraf/MDSD: update version references in build scripts and Dockerfiles.
5. For Mariner base image: update the `FROM` line in `kubernetes/linux/Dockerfile.multiarch`.
6. Build: `cd build/linux && make`.
7. Run unit tests to verify nothing broke.
8. Run `trivy fs --severity CRITICAL,HIGH --scanners vuln .` to check for new vulnerabilities.

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod` — E2E test modules
- `kubernetes/linux/Dockerfile.multiarch`
- `build/linux/Makefile`

### Validation
- Build succeeds
- All unit tests pass
- Trivy scan clean
- Docker image builds

## Examples from This Repo
- `a71f549e0` — Fluent bit 4.0.14 (#1601)
- `df85af818` — Upgrade Telegraf 1.34.3 (#1434)
- `8ac2038cc` — Mariner 3 upgrade (#1439)
- `388f83c97` — mdsd version upgrade 1.35.7 (#1492)
