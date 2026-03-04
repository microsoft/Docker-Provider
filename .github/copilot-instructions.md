# Repository Instructions

## Summary

Docker-Provider (Azure Monitor Container Insights) is a monitoring agent for Kubernetes clusters. It collects container logs, metrics, and inventory data and sends them to Azure Monitor (Log Analytics). The codebase is primarily Ruby (~17%), Go (~7%), Shell/Bash (~9%), PowerShell (~5%), YAML (~15%), and JSON (~14%), with Python used for E2E tests. It uses Fluent Bit as the log pipeline, with custom Go output plugins and Ruby Fluentd input plugins. The agent runs as a DaemonSet and ReplicaSet on Linux and Windows Kubernetes nodes.

## Build Instructions

### Prerequisites
- Go 1.23.8+ (for Go plugin compilation)
- Ruby with Fluentd gem 1.14.2 (`gem install fluentd -v "1.14.2"`)
- Make, gcc, pkg-config, libssl-dev on Linux
- PowerShell 5+ and Pester 5.3.3 on Windows

### Build (Linux)
```bash
cd build/linux
make              # builds Go fluent-bit plugin and installer
make arch=arm64   # cross-compile for ARM64
```

### Unit Tests
```bash
# Bash unit tests
./test/unit-tests/test_main.sh

# Go unit tests
./test/unit-tests/run_go_tests.sh

# Ruby unit tests (requires fluentd gem)
./test/unit-tests/run_ruby_tests.sh

# PowerShell unit tests (Windows)
./test/unit-tests/test_main.ps1
```

### Docker Image Build
```bash
docker build -f kubernetes/linux/Dockerfile.multiarch .
```

## Project Layout

| Directory | Purpose |
|-----------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugin (OMS, telemetry, network flow) |
| `source/plugins/go/input/` | Go Fluent Bit input plugins (container inventory, perf) |
| `source/plugins/ruby/` | Ruby Fluentd input/filter/output plugins (kube inventory, events, CAdvisor) |
| `build/linux/` | Linux build system (Makefile, installer) |
| `build/windows/` | Windows build system (PowerShell, C# certificate generator) |
| `kubernetes/linux/` | Linux container image (Dockerfile.multiarch, setup.sh, main.sh) |
| `kubernetes/windows/` | Windows container image (Dockerfile, main.ps1) |
| `charts/` | Helm charts (azuremonitor-containers, azuremonitor-containers-geneva) |
| `test/unit-tests/` | Bash, Go, Ruby, and PowerShell unit tests |
| `test/e2e/` | Python-based E2E tests using pytest and Kubernetes API |
| `test/ginkgo-e2e/` | Go Ginkgo-based E2E tests (liveness probe, container status, query logs) |
| `test/testkube/` | Testkube workflow definitions for CI test execution |
| `scripts/onboarding/` | Customer onboarding scripts (AKS, ARO, Arc, hybrid) |
| `deployment/` | Azure service deployment configs (arc-k8s-extension, rollout specs) |
| `.pipelines/` | Azure Pipelines CI/CD definitions |

## Validation Steps

CI runs on pull requests to `ci_dev` and `ci_prod` branches via GitHub Actions:
- **`run_unit_tests.yml`**: Bash, Go, Ruby, and PowerShell unit tests
- **`pr-checker.yml`**: Linux Docker image build and Trivy security scan
- **`codeql-analysis.yml`**: CodeQL static analysis (Go)
- **`devskim.yml`**: DevSkim security scanner

Before pushing, run all unit test suites locally (see Build Instructions above).

## Known Patterns & Gotchas

- The Go plugin at `source/plugins/go/src/` has a `replace` directive in `go.mod` pointing to `../input` — both modules must stay in sync.
- Ruby plugins use `$in_unit_test` global variable to gate test-only behavior.
- The main Dockerfile is a multi-stage build: Go compilation → Azure Linux builder → distroless final image.
- Environment-specific logic keys off `CONTROLLER_TYPE` (DaemonSet/ReplicaSet) and `CONTAINER_TYPE` env vars.
- Helm charts under `charts/` have separate Geneva and standard variants with different values files.
- Azure Pipelines (`.pipelines/`) handle production releases; GitHub Actions handle PR validation only.
- Version info lives in `build/version` — update `CONTAINER_BUILDVERSION_*` variables for releases.
