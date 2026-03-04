# Dependency Update

## Description
Update Go module dependencies, system packages, or Fluent Bit versions to address CVEs or stay current.

USE FOR: update dependency, bump package, upgrade library, CVE fix, update go.mod, upgrade Fluent Bit, address vulnerabilities
DO NOT USE FOR: adding a brand new dependency, removing a dependency, major framework migration

## Instructions

### When to Apply
When a CVE is reported against a dependency, when Dependabot/Trivy flags a vulnerability, or when upgrading Fluent Bit or system packages in the container image.

### Step-by-Step Procedure
1. Identify the vulnerable dependency from Trivy scan output or CVE report.
2. Update the version in the relevant dependency file:
   - Go plugins: `source/plugins/go/src/go.mod` and `source/plugins/go/input/go.mod` (keep both in sync)
   - Ginkgo E2E tests: `test/ginkgo-e2e/*/go.mod` (containerstatus, livenessprobe, querylogs, utils)
   - Fluent Bit version: `kubernetes/linux/setup.sh`
   - System packages: `kubernetes/linux/Dockerfile.multiarch`
3. Run `go mod tidy` in each affected Go module directory.
4. Run Go unit tests: `./test/unit-tests/run_go_tests.sh`
5. Build the Docker image to verify: `docker build -f kubernetes/linux/Dockerfile.multiarch .`
6. Update `ReleaseNotes.md` with CVE fix details.
7. Update chart versions in `charts/azuremonitor-containers/Chart.yaml` and `charts/azuremonitor-containers/values.yaml`.

### Files Typically Involved
- `source/plugins/go/src/go.mod`, `source/plugins/go/src/go.sum`
- `source/plugins/go/input/go.mod`, `source/plugins/go/input/go.sum`
- `test/ginkgo-e2e/*/go.mod`, `test/ginkgo-e2e/*/go.sum`
- `kubernetes/linux/setup.sh`
- `kubernetes/linux/Dockerfile.multiarch`

### Validation
- `./test/unit-tests/run_go_tests.sh` passes
- Docker image builds successfully
- Trivy scan shows no new critical/high CVEs
- CI `pr-checker.yml` passes

## Examples from This Repo
- `31c5bc4fc` — Longw/3.1.35 address vulnerabilities (#1605)
- `733532d7f` — 3.1.31 CVEs fixes (#1572)
- `9dcd86c76` — CVEs Fix (#1526)

## References
- `build/version` — version numbering
- `.pipelines/azure_pipeline_mergedbranches.yaml` — Trivy scan configuration
