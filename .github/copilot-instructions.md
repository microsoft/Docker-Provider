# Repository Instructions

## Summary
Azure Monitor for Containers (Docker-Provider) agent for Linux and Windows Kubernetes clusters. Primary languages: Ruby (~28%), YAML (~25%), Shell (~16%), Go (~13%), PowerShell (~9%), Python (~8%). Built as Fluent Bit plugins (Go shared objects + Ruby fluentd plugins) packaged into multi-arch Docker images running on Azure Linux (Mariner). Deployed via Helm charts, Kubernetes DaemonSets/ReplicaSets, and Azure Arc extensions.

## General Guidelines

1. Follow existing code patterns — sample 3-5 neighboring files before writing new code.
2. Never hardcode secrets, instrumentation keys, or connection strings — use environment variables.
3. All Go code must pass `go vet` and `go test` with `GOUNITTEST=true ISTEST=true`.
4. Ruby plugins must follow the existing `frozen_string_literal: true` convention and use `require_relative`.
5. Shell scripts must work on both Ubuntu and Azure Linux (Mariner); avoid distro-specific commands.
6. PowerShell scripts target Windows Server 2019+ and must pass PSScriptAnalyzer.
7. Telemetry must use the existing `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go) — never introduce new telemetry SDKs.
8. Container images use Azure Linux 3.0 (Mariner) as the base — do NOT switch base images without team approval.

## Build Instructions

### Prerequisites
- Go 1.23.8+, Ruby with fluentd 1.14.2, Docker, Helm 3, build-essential, Python 3

### Linux Build
```bash
cd build/linux && make          # Builds Go plugins + installer packages
```

### Windows Build
```powershell
cd build/windows && .\Makefile.ps1
```

### Docker Image (Linux)
```bash
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag> --build-arg IMAGE_TAG=<telemetry-tag>
```

### Tests
```bash
# Bash unit tests
./test/unit-tests/test_main.sh

# Go unit tests
cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .

# Ruby unit tests
./test/unit-tests/run_ruby_tests.sh

# PowerShell unit tests (Windows)
./test/unit-tests/test_main.ps1

# Ginkgo E2E tests (requires cluster)
cd test/ginkgo-e2e/<suite> && go test -v ./...
```

## Known Patterns & Gotchas

- The default branch is `ci_prod`, not `main`.
- PR targets are `ci_dev` (development) or `ci_prod` (production).
- Trivy scans run on every PR with `CRITICAL,HIGH` severity and `exit-code: 1` — fix vulnerabilities before merging.
- Go plugins compile as C shared objects (`.so` files) for Fluent Bit — use `CGO_ENABLED=1`.
- The `build/version` file controls build versioning — update it for releases.
- Ruby plugins live under `source/plugins/ruby/` and Go plugins under `source/plugins/go/`.
- Helm charts in `charts/` must have `Chart.yaml` version bumped for each release.
- Azure Pipelines (`.pipelines/`) handle production CI/CD; GitHub Actions handle PR checks and security scans.
