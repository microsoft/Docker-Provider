# Repository Instructions

## Summary

Docker-Provider (microsoft/Docker-Provider) is the Azure Monitor for Containers agent. It collects container logs, metrics, and inventory from Kubernetes clusters (AKS, Arc-enabled, hybrid) and forwards them to Azure Monitor / Log Analytics. Primary languages: Ruby (~35%), Go (~15%), Shell/Bash (~20%), YAML/JSON (~25%), with minor PowerShell, Python, Terraform, and Bicep. Runs as a DaemonSet (`ama-logs`) and ReplicaSet (`ama-logs-rs`) inside Kubernetes, built on Fluent Bit with custom Ruby and Go plugins.

## General Guidelines

1. Follow existing code conventions per language — Ruby uses `snake_case` with `frozen_string_literal` pragma; Go uses standard `gofmt` conventions; Shell scripts use `set -e` and `set -o pipefail`.
2. All telemetry must use the existing `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go) helpers — never introduce a new telemetry SDK.
3. Environment variables are the source of truth for configuration — never hardcode secrets, connection strings, or instrumentation keys.
4. When modifying Fluent Bit plugin code, update both the Linux (Ruby/Go) and Windows (PowerShell) paths if applicable.
5. Refer to `AGENTS.md` for setup, code style, and testing instructions.

## Custom Agents

| Agent | Triggers | Description |
|-------|----------|-------------|
| @CodeReviewer | review PR, review code, check changes | Reviews code for correctness, security, telemetry, and style |
| @SecurityReviewer | security review, threat model, STRIDE | Deep security analysis beyond routine review |
| @ThreatModelAnalyst | threat model, STRIDE diagram | Full threat model with Mermaid diagrams under `threat-model/` |
| @DocumentWriter | write docs, update README | Documentation authoring following repo conventions |
| @prd | create PRD, requirements doc | Generates Product Requirements Documents |

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| dependency-update | bump package, update dependency, upgrade library | Update Go modules, Ruby gems, or base images |
| bug-fix | fix bug, patch, hotfix, resolve issue | Fix bugs with regression tests |
| feature-development | add feature, implement, new plugin | Add new features following repo patterns |
| ci-cd-pipeline | update pipeline, fix CI, modify workflow | Modify GitHub Actions or Azure Pipelines |
| infrastructure | update Dockerfile, Helm chart, k8s manifest | Modify container/deployment infrastructure |
| test-authoring | add test, write test, increase coverage | Add unit, integration, or E2E tests |
| documentation | update docs, write README, release notes | Update documentation and release notes |
| security-review | security review, STRIDE, credential check | STRIDE-based security review |
| telemetry-authoring | add telemetry, add metrics, instrument code | Add Application Insights telemetry |
| fix-critical-vulnerabilities | fix CVE, patch vulnerability, trivy fix | Fix critical/high vulnerabilities |

## Build Instructions

```bash
# Prerequisites: Go 1.23+, Ruby 3.3+, Docker, Make

# Build Go Fluent Bit output plugin
cd source/plugins/go/src && make fbplugin

# Run Go unit tests
cd source/plugins/go/src && make test

# Run all unit tests (Bash + Go + Ruby)
./test/unit-tests/test_main.sh

# Build Linux Docker image (requires Docker)
cd kubernetes/linux/dockerbuild && ./build-and-publish-docker-image.sh --image <name>

# Run Ginkgo E2E tests (requires running cluster)
cd test/ginkgo-e2e/<suite> && go test -v ./...
```

## Known Patterns & Gotchas

- The `$in_unit_test` Ruby global variable gates telemetry in tests — always respect it.
- Go plugins build as C-shared libraries (`.so`) via `buildmode=c-shared` — CGO is required.
- Windows and Linux agents have separate entry points (`main.sh` / `main.ps1`) and Dockerfiles.
- Helm charts in `charts/` are for non-AKS clusters; AKS uses the extension deployment path in `deployment/`.
- The `.trivyignore` file tracks temporarily suppressed CVEs — entries need justification and follow-up dates.
- CI runs on `ci_dev` and `ci_prod` branches; PRs target these branches.
