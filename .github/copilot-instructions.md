# Repository Instructions

## Summary

Docker-Provider (aka Azure Monitor Container Insights agent, `ama-logs`) is a Kubernetes monitoring agent that collects container logs, metrics, inventory, and events from AKS and Arc-enabled Kubernetes clusters. It ships as a Linux/Windows container image running Fluent Bit (Go output/input plugins) and Fluentd (Ruby input/filter/output plugins), forwarding data to Azure Monitor Log Analytics and Azure Monitor Metrics (MDM). Primary languages: Ruby, Go, Shell, PowerShell. Runtime: Kubernetes DaemonSet + ReplicaSet.

## General Guidelines

1. Follow existing code patterns — sample 3–5 neighboring files before adding new code.
2. Use `frozen_string_literal: true` in all Ruby files.
3. Use `ApplicationInsightsUtility` (Ruby) or `appinsights` SDK (Go) for telemetry — never introduce new telemetry libraries.
4. All secrets must come from environment variables — never hardcode keys, tokens, or connection strings.
5. Test changes with the appropriate unit test suite: `test/unit-tests/test_main.sh` (Bash), `test/unit-tests/run_go_tests.sh` (Go), `test/unit-tests/run_ruby_tests.sh` (Ruby), or `test/unit-tests/test_main.ps1` (PowerShell).
6. Container images are built via `cd build/linux && make` (Linux) and Docker build in `kubernetes/linux/Dockerfile.multiarch`.
7. Helm charts in `charts/` must have `Chart.yaml` version bumped for any chart changes.
8. PR titles typically include a short description and PR number: `description (#1234)`.

## Build Instructions

```bash
# Prerequisites: Go 1.23+, Ruby with fluentd gem, build-essential, Docker
# Linux build
cd build/linux && make

# Docker image build
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag>

# Unit tests
./test/unit-tests/test_main.sh        # Bash tests
./test/unit-tests/run_go_tests.sh     # Go tests
./test/unit-tests/run_ruby_tests.sh   # Ruby tests (requires fluentd gem)
```

## Task-Specific Skills

| Skill | Triggers | Description |
|-------|----------|-------------|
| `#dependency-update` | update dependency, bump package, upgrade library | Safe dependency update workflow |
| `#test-authoring` | add test, write test | Create tests following repo conventions |
| `#bug-fix` | fix bug, resolve issue, hotfix | Structured bug fix with regression test |
| `#feature-development` | add feature, implement, new plugin | New feature scaffolding |
| `#code-refactoring` | refactor, restructure, rename | Behavior-preserving refactoring |
| `#infrastructure` | update Dockerfile, Helm chart, k8s manifest | Infrastructure change workflow |
| `#security-review` | security review, threat model, STRIDE | STRIDE-based security review |
| `#telemetry-authoring` | add telemetry, add metrics, instrument code | Add telemetry following existing patterns |
| `#fix-critical-vulnerabilities` | fix CVE, trivy fix, vulnerability fix | Fix critical/high CVEs |

## Known Patterns & Gotchas

- The Go plugin builds as a shared library (`out_oms.so`) loaded by Fluent Bit — it uses CGo exports.
- Ruby plugins use Fluentd's plugin API (`Fluent::Plugin`) — input, filter, and output types.
- `kubernetes/linux/setup.sh` and `kubernetes/linux/main.sh` are the container entrypoint scripts — changes here affect all deployments.
- The `CONTROLLER_TYPE` env var (`DaemonSet`/`ReplicaSet`) determines which code paths execute.
- Trivy scanning runs in the `pr-checker` workflow and blocks PRs with critical/high CVEs.
- `.trivyignore` can temporarily suppress specific CVEs — always add a comment explaining why.
