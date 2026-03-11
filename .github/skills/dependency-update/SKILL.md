# Skill: Dependency Update

## Overview
Update dependencies across the Docker-Provider stack: Go modules, Docker base images, Helm chart versions, and OS-level packages. Changes must pass build, test, and security scanning.

## Scope
- **Go modules**: `source/plugins/go/src/go.mod`, `source/plugins/go/input/go.mod`, `test/ginkgo-e2e/*/go.mod`
- **Docker base images**: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- **Helm charts**: `charts/azuremonitor-containers/values.yaml`, `charts/azuremonitor-containers-geneva/values.yaml`, `charts/azuremonitor-containerinsights-for-prod-clusters/values.yaml`
- **K8s manifests**: `kubernetes/ama-logs.yaml` (image tags)
- **OS packages**: `tdnf install` directives in Dockerfiles, `build/linux/setup.sh`

## Procedures

### Go Module Updates
```bash
cd source/plugins/go/src
go get <module>@<version>
go mod tidy
```
Repeat for each `go.mod` in the repo. Ensure `go.sum` is committed alongside `go.mod`.

### Docker Base Image Updates
Edit the `FROM` line in `kubernetes/linux/Dockerfile.multiarch` or `kubernetes/windows/Dockerfile`. When updating base images, also review `tdnf install` / `apt-get install` package lists for compatibility.

### Helm Chart Version Bumps
Update `image.tag` or dependency chart versions in `values.yaml`. Bump the chart `version` field in `Chart.yaml` when modifying chart content.

### OS-Level Package Updates
Update pinned package versions in `Dockerfile.multiarch` (`tdnf install`) or `build/linux/setup.sh`. Prefer explicit version pins for reproducibility.

## Validation Checklist
1. **Build**: `cd build/linux && make` — must succeed
2. **Go unit tests**: `./test/unit-tests/run_go_tests.sh`
3. **Ruby unit tests**: `ruby test/unit-tests/test_driver.rb`
4. **Bash unit tests**: `./test/unit-tests/test_main.sh`
5. **Security scan**: Run Trivy against the built image; check `.trivyignore` for accepted CVEs
6. **CI**: Ensure `run_unit_tests.yml` and `pr-checker.yml` pass

## Commit Convention
Freeform message describing what was updated and why. Reference PR number (e.g., `(#1234)`). Example:
```
Update fluent-bit base image to 3.1.2 for CVE-2024-XXXX (#1234)
```

## Pitfalls
- Updating one `go.mod` but not others can cause build drift — check all module files.
- Base image updates may change available system libraries; rebuild and test thoroughly.
- Trivy scan failures may require adding entries to `.trivyignore` with justification.
