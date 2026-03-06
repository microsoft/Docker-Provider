# Repository Instructions

## Summary

This repository contains the Azure Monitor for containers agent (Linux and Windows). It is a Kubernetes monitoring agent that collects container logs, performance metrics, inventory data, and Kubernetes events. The primary languages are Ruby (~18%), Go (~8%), Shell (~10%), PowerShell (~6%), and Python (~5%) for E2E tests. It runs as a DaemonSet and ReplicaSet inside Kubernetes clusters and ships data to Azure Monitor (Log Analytics, Azure Data Explorer, and Geneva). The agent uses Fluent Bit as the log pipeline with custom Go output plugins and Ruby Fluentd input/filter plugins.

## General Guidelines

1. All Go code lives in `source/plugins/go/` and must build with `go build -buildmode=c-shared` producing shared object files.
2. All Ruby Fluentd plugins live in `source/plugins/ruby/` and follow Fluentd plugin naming: `in_*.rb` (input), `filter_*.rb` (filter), `out_*.rb` (output).
3. Shell scripts must work on Azure Linux (CBL-Mariner / Azure Linux 3) — no Debian/Ubuntu-specific tools.
4. Never hardcode secrets or instrumentation keys. Use environment variables (`APPLICATIONINSIGHTS_AUTH`, `APPLICATIONINSIGHTS_ENDPOINT`, etc.).
5. Configuration changes to the agent are parsed at startup from ConfigMaps — see `build/common/installer/scripts/` for parsers.
6. Test all changes with the CI test suites before submitting: Bash (`test/unit-tests/test_main.sh`), Go (`test/unit-tests/run_go_tests.sh`), Ruby (`test/unit-tests/run_ruby_tests.sh`), PowerShell (`test/unit-tests/test_main.ps1`).
7. If newer commits make prior changes unnecessary, revert them rather than leaving dead code.
8. Helm chart changes in `charts/` must keep `values.yaml` and `Chart.yaml` versions in sync.

## Build Instructions

**Prerequisites:** Go 1.25.7+, Ruby 3.3.x, Docker, Azure Linux / Ubuntu

**Build Go plugins:**
```bash
cd source/plugins/go/src && make
```

**Build Linux container image:**
```bash
cd build/linux && make
```

**Run all unit tests (CI-identical):**
```bash
# Bash tests
./test/unit-tests/test_main.sh

# Go tests
./test/unit-tests/run_go_tests.sh

# Ruby tests (requires fluentd gem)
./test/unit-tests/run_ruby_tests.sh

# PowerShell tests (Windows, requires Pester 5.3.3)
./test/unit-tests/test_main.ps1
```

**Run Ginkgo E2E tests:**
```bash
cd test/ginkgo-e2e/<suite> && go test -v ./...
```

## Known Patterns & Gotchas

- The Go output plugin (`out_oms.so`) is a C-shared library loaded by Fluent Bit — do not use `main` package imports that conflict with CGo.
- Ruby plugins use a custom `ApplicationInsightsUtility` singleton for telemetry (not the standard gem) — see `source/plugins/ruby/ApplicationInsightsUtility.rb`.
- The agent builds on Azure Linux (Mariner) using `tdnf` — `apt-get` commands will not work in the container build.
- Trivy scans run in PR CI; check `.trivyignore` for intentionally suppressed CVEs.
- The primary CI/CD pipeline is Azure Pipelines (`.pipelines/`) — GitHub Actions are used for CodeQL, DevSkim, unit tests, and stale issue management.
- The default branch is `ci_prod`, not `main`.
