# Repository Instructions

## Summary
Docker-Provider (aka Container Insights) is a Microsoft open-source project that collects container logs, metrics, and inventory data from Kubernetes clusters (AKS, ARC, on-prem) and sends them to Azure Monitor (Log Analytics, Metrics, MDSD/Geneva). Primary languages: Ruby (~25%), Go (~11%), Shell (~14%), Python (~7%), PowerShell (~8%), with YAML/JSON configs (~35%). Runs as DaemonSet + ReplicaSet inside the `kube-system` namespace. Uses Fluent Bit (C), Fluentd (Ruby plugins), Telegraf (Go), and custom Go Fluent Bit output plugins for data collection.

## General Guidelines

1. Follow existing code style per language — Ruby uses `snake_case` with `frozen_string_literal`, Go uses standard `gofmt`, Shell scripts use `set -e`.
2. All telemetry must use the existing `ApplicationInsightsUtility` (Ruby) or `TelemetryClient` (Go) patterns — never introduce new telemetry SDKs.
3. Environment variables are the source of truth for configuration at runtime — never hardcode secrets, endpoints, or keys.
4. If newer commits make prior changes unnecessary, revert them.
5. Check `AGENTS.md` for setup commands, code style, and testing instructions.

## Prompting Best Practices

1. Break complex tasks into smaller prompts — one plugin, one test file, one config change at a time.
2. Be specific: reference actual file paths like `source/plugins/ruby/in_kube_nodes.rb` or `source/plugins/go/src/oms.go`.
3. Open relevant source files before prompting — Copilot uses open files as context.
4. Start new chat sessions for unrelated tasks to avoid context pollution.
5. Use the explore → plan → code → commit workflow for multi-file changes (see `AGENTS.md`).
6. Always validate AI-generated code: run tests, check linters, and verify against CI checks.

## Build Instructions

**Prerequisites:** Go 1.25+, Ruby, `make`, Docker, Helm.

**Build (Linux):**
```bash
cd build/linux && make
```

**Docker image:**
```bash
cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t <tag>
```

**Run unit tests:**
```bash
# Bash tests
./test/unit-tests/test_main.sh
# Go tests
./test/unit-tests/run_go_tests.sh
# Ruby tests (requires fluentd gem)
./test/unit-tests/run_ruby_tests.sh
```

**Trivy scan:**
```bash
trivy image --severity CRITICAL,HIGH <image-tag>
```

## Known Patterns & Gotchas

- The build system has separate Linux and Windows paths (`build/linux/`, `kubernetes/windows/`).
- Local computer builds may be broken — see README note. CI builds are the reliable path.
- Go plugins live under `source/plugins/go/src/` (output plugins) and `source/plugins/go/input/` (input plugins).
- Ruby plugins under `source/plugins/ruby/` are Fluentd input/output/filter plugins.
- Multiple `go.mod` files exist: `source/plugins/go/src/`, `source/plugins/go/input/`, and test dirs under `test/ginkgo-e2e/`.
- Helm charts in `charts/` — `azuremonitor-containers` is the primary chart.
- ARM/Bicep/Terraform templates are in `deployment/` — do NOT edit manually if helper scripts exist.
- The `.trivyignore` file tracks temporarily suppressed CVEs — always include justification.
- Default branch is `ci_prod`, not `main`.
