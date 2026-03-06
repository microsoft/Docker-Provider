# Repository Instructions

## Summary
This repository contains the Azure Monitor for containers (Container Insights) agent for Linux and Windows. It is a Fluent Bit output plugin (Go) and Fluentd input/filter plugins (Ruby) that collect container logs, metrics, inventory, and network flow data from Kubernetes clusters and ship them to Azure Monitor. The agent runs as a DaemonSet and ReplicaSet in Kubernetes, deployed via Helm charts or Azure Arc extensions.

## General Guidelines

1. Follow existing code conventions: Go uses `PascalCase` for exported, `camelCase` for unexported; Ruby uses `PascalCase` classes; Shell scripts use `snake_case`.
2. All Go changes must pass `GOUNITTEST=true ISTEST=true go test .` in `source/plugins/go/src/`.
3. All shell script changes must pass `./test/unit-tests/test_main.sh`.
4. Ruby changes must pass `ruby test/unit-tests/test_driver.rb`.
5. Never hardcode secrets, instrumentation keys, or connection strings — use environment variables.
6. Container images must not run as root without justification.
7. CVE/vulnerability fixes should be verified with Trivy scanning.
8. When modifying Helm charts, update both `charts/azuremonitor-containers/` and `charts/azuremonitor-containers-geneva/` if applicable.

## Custom Agents

| Agent | Triggers | Description |
|-------|----------|-------------|
| @CodeReviewer | review PR, review code | Structured code review following repo conventions |
| @SecurityReviewer | security review, threat model | Deep STRIDE-based security analysis |
| @DocumentWriter | write docs, update README | Documentation following repo conventions |
| @prd | create PRD, write requirements | Generate Product Requirements Documents |

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| `security-review` | security review, STRIDE analysis, credential check | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | add telemetry, add metrics, instrument code | Add Application Insights telemetry following existing patterns |
| `fix-critical-vulnerabilities` | fix CVE, trivy fix, patch vulnerability | Identify and fix critical/high vulnerabilities using Trivy |
| `dependency-update` | update dependency, bump package | Update Go modules, Ruby gems, or base images safely |
| `bug-fix` | fix bug, resolve issue, hotfix | Structured bug fix workflow with regression tests |
| `feature-development` | add feature, implement, new plugin | New feature scaffolding for Go/Ruby plugins |
| `test-authoring` | add test, write test | Create tests following repo test framework conventions |
| `ci-cd-pipeline` | update pipeline, fix CI | Modify GitHub Actions or Azure Pipelines configs |
| `infrastructure` | update Dockerfile, Helm chart, k8s manifest | Infrastructure and deployment changes |
| `documentation` | update docs, release notes | Documentation and release note updates |

## Build Instructions

### Prerequisites
- Go 1.23.8+, Ruby with Fluentd gem, Docker, Helm, `build-essential` (Linux)
- .NET Core SDK (Windows only), GCC for Windows (Windows only)

### Linux Build
```bash
cd build/linux && make
```

### Windows Build
```powershell
cd build/windows && .\Makefile.ps1
```

### Docker Image (Linux multi-arch)
```bash
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag> --build-arg IMAGE_TAG=<telemetry-tag>
```

### Run Tests
```bash
# Bash unit tests
./test/unit-tests/test_main.sh

# Go unit tests
cd source/plugins/go/src && GOUNITTEST=true ISTEST=true go test .

# Ruby unit tests
ruby test/unit-tests/test_driver.rb

# Ginkgo E2E (requires cluster)
cd test/ginkgo-e2e/<suite> && go test -v ./...
```

## Known Patterns & Gotchas

- The Go plugin builds as a shared object (`.so`) loaded by Fluent Bit — ensure CGO is enabled.
- `go generate` must run before `go test` in `source/plugins/go/src/`.
- Environment variable `GOUNITTEST=true` gates test-only code paths in Go.
- Helm charts in `charts/azuremonitor-containers/` are for non-AKS clusters; Geneva variant is in `charts/azuremonitor-containers-geneva/`.
- Azure Pipelines in `.pipelines/` handle production builds and releases; GitHub Actions handle PR validation.
- The `.trivyignore` file tracks temporarily accepted CVEs — always add justification comments.
- Windows and Linux agents share configuration parsing scripts in `build/common/installer/scripts/`.
