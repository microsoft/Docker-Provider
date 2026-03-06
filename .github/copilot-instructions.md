# Repository Instructions

## Summary
This repository contains the Azure Monitor for containers (Container Insights) agent for Linux and Windows. It is a Fluent Bit output plugin (Go) and Fluentd input/filter plugins (Ruby) that collect container logs, metrics, inventory, and network flow data from Kubernetes clusters and ship them to Azure Monitor. The agent runs as a DaemonSet and ReplicaSet in Kubernetes, deployed via Helm charts or Azure Arc extensions.

## General Guidelines

1. Follow existing code conventions: Go uses `PascalCase` for exported, `camelCase` for unexported; Ruby uses `PascalCase` classes; Shell scripts use `snake_case`.
2. All Go changes must pass `GOUNITTEST=true ISTEST=true go test .` in `source/plugins/go/src/`. Run `go generate` first.
3. All shell script changes must pass `./test/unit-tests/test_main.sh`.
4. Ruby changes must pass `ruby test/unit-tests/test_driver.rb`.
5. Never hardcode secrets, instrumentation keys, or connection strings — use environment variables.
6. Container images must not run as root without justification.
7. CVE/vulnerability fixes should be verified with Trivy scanning.
8. When modifying Helm charts, update `azuremonitor-containers` and `azuremonitor-containers-geneva` charts if applicable.
9. If newer commits make prior changes unnecessary, revert them.

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
| `security-review` | security review, STRIDE analysis | STRIDE-based security review with credential scanning |
| `telemetry-authoring` | add telemetry, add metrics | Add Application Insights telemetry following existing patterns |
| `fix-critical-vulnerabilities` | fix CVE, trivy fix | Fix critical/high CVEs using Trivy |
| `dependency-update` | update dependency, bump package | Update Go modules, gems, or base images safely |
| `bug-fix` | fix bug, resolve issue | Bug fix workflow with regression tests |
| `feature-development` | add feature, implement | New feature scaffolding for Go/Ruby plugins |
| `test-authoring` | add test, write test | Create tests following repo conventions |
| `ci-cd-pipeline` | update pipeline, fix CI | Modify GitHub Actions or Azure Pipelines |
| `infrastructure` | update Dockerfile, Helm chart | Infrastructure and deployment changes |
| `documentation` | update docs, release notes | Documentation and release note updates |

## Build Instructions

### Prerequisites
- Go (see `source/plugins/go/src/go.mod` for version), Ruby with Fluentd gem, Docker, Helm, `build-essential` (Linux)

### Key Commands
```bash
cd build/linux && make                                                    # Linux build
cd source/plugins/go/src && go generate && GOUNITTEST=true ISTEST=true go test . # Go tests
./test/unit-tests/test_main.sh                                           # Bash tests
ruby test/unit-tests/test_driver.rb                                      # Ruby tests
```

## Known Patterns & Gotchas

- Go plugin builds as `.so` loaded by Fluent Bit — CGO must be enabled.
- `go generate` must run before `go test` in `source/plugins/go/src/`.
- `GOUNITTEST=true` gates test-only code paths in Go.
- Two `go.mod` files: `source/plugins/go/src/go.mod` and `source/plugins/go/input/go.mod`.
- Azure Pipelines (`.pipelines/`) for production; GitHub Actions for PR validation.
- `.trivyignore` tracks accepted CVEs — always add justification with date.
- Shared config scripts in `build/common/installer/scripts/`.
