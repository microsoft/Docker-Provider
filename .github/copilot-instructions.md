# Repository Instructions

## Summary

Docker-Provider (aka Azure Monitor Container Insights agent) is a Kubernetes monitoring agent that collects container logs, metrics, inventory, and events from AKS, Arc-enabled, and on-prem clusters. Primary languages are Ruby (~35%), Go (~15%), Shell/Bash (~20%), PowerShell (~12%), and Python (~10%). The agent runs as a DaemonSet and ReplicaSet inside Kubernetes clusters, using Fluent Bit for log collection and Telegraf for metrics. Built on Azure Linux (Mariner) container images.

## General Guidelines

1. Follow existing code conventions per language — Ruby uses `frozen_string_literal`, snake_case methods, class variables (`@@`); Go uses PascalCase exports, `camelCase` locals, `const` blocks for data types.
2. All telemetry must use `ApplicationInsightsUtility` (Ruby) or `appinsights.TelemetryClient` (Go) — never introduce alternative telemetry SDKs.
3. Environment variables carry secrets and config — reference env var NAMES only, never hardcode values. Key env vars: `APPLICATIONINSIGHTS_AUTH`, `AKS_RESOURCE_ID`, `CONTROLLER_TYPE`, `CONTAINER_RUNTIME`.
4. Guard test code with `$in_unit_test` (Ruby) or `GOUNITTEST=true` (Go) to prevent telemetry emission during tests.
5. If newer commits make prior changes unnecessary, revert them.

## Build Instructions

### Prerequisites
- Go 1.23.8+, Ruby with Fluentd 1.14.2, PowerShell with Pester 5.3.3
- Build-essential, make, Docker for container builds

### Build (Linux)
```bash
cd build/linux && make           # Builds Go Fluent Bit plugins + installer
```

### Build (Windows)
```powershell
cd build/windows && .\Makefile.ps1
```

### Test
```bash
# Bash unit tests
./test/unit-tests/test_main.sh

# Go unit tests
GOUNITTEST=true ISTEST=true go test ./source/plugins/go/src/...

# Ruby unit tests (requires fluentd gem)
./test/unit-tests/run_ruby_tests.sh

# PowerShell unit tests
./test/unit-tests/test_main.ps1

# Ginkgo E2E tests
cd test/ginkgo-e2e/<suite> && go test -v ./...
```

### Docker Image Build
```bash
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag> --build-arg IMAGE_TAG=<telemetry-tag>
```

## Custom Agents

| Agent | Triggers | Description |
|-------|----------|-------------|
| @CodeReviewer | review PR, review code, check changes | Code review following repo conventions, security (STRIDE), telemetry gaps |
| @DocumentWriter | write docs, update README | Documentation authoring following repo doc standards |
| @prd | create PRD, write requirements | PRD generation tailored to this project |

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| #dependency-update | update dependency, bump package, CVE fix in deps | Safe dependency updates for Go modules, Ruby gems |
| #bug-fix | fix bug, resolve issue, hotfix | Structured bug fix with regression test |
| #feature-development | add feature, implement, new plugin | New feature scaffolding |
| #ci-cd-pipeline | update pipeline, fix CI, modify workflow | CI/CD workflow changes |
| #infrastructure | update Dockerfile, Helm chart, Bicep/Terraform | Infrastructure-as-code changes |
| #test-authoring | add test, write test | Create tests following repo conventions |
| #security-review | security review, STRIDE analysis, credential check | STRIDE-based security review |
| #telemetry-authoring | add telemetry, add metrics, instrument code | Add telemetry following existing patterns |
| #fix-critical-vulnerabilities | fix CVE, trivy fix, patch vulnerability | Fix critical/high vulnerabilities using Trivy |

## Known Patterns & Gotchas

1. Multiple `go.mod` files exist: `source/plugins/go/src/`, `source/plugins/go/input/`, and `test/ginkgo-e2e/*/`. CVE fixes must update ALL of them.
2. The Go plugin uses `replace` directives — `source/plugins/go/input` references `../src` locally.
3. Trivy scans run on PR builds with `exit-code: 1` for CRITICAL,HIGH — PRs will fail if new vulnerabilities are introduced.
4. Ruby plugins are Fluentd plugins (`Fluent::Plugin`) — they follow Fluentd's `in_*`, `out_*`, `filter_*` naming convention.
5. Container images are based on Azure Linux (Mariner 3.0) — use `tdnf` for package management, not `apt-get`.
6. The `.trivyignore` file manages temporarily ignored CVEs — always include justification comments.
7. Helm charts exist in three variants: `azuremonitor-containers` (public), `azuremonitor-containers-geneva` (internal), and `azuremonitor-containerinsights-for-prod-clusters` (prod deployment).
