# Docker-Provider (Azure Monitor Container Insights Agent)

A Kubernetes monitoring agent that collects container logs, metrics, inventory, and events from AKS and Arc-enabled Kubernetes clusters. Ships as Linux/Windows container images running Fluent Bit with Go plugins and Fluentd with Ruby plugins.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log collection (output) | Go — Fluent Bit output plugin (`out_oms.so`) |
| Log collection (input) | Go — Fluent Bit input plugins (`containerinventory.so`, `perf.so`) |
| Inventory & metrics | Ruby — Fluentd input/filter/output plugins |
| Container runtime | Docker (Linux multiarch, Windows) |
| Orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Package management | Helm charts |
| Telemetry | Application Insights (Go SDK + Ruby wrapper) |
| Build system | Make + Go build + Docker build |
| CI/CD | GitHub Actions |
| Security scanning | CodeQL, DevSkim, Trivy |
| IaC | Terraform, Bicep (onboarding scripts) |
| Unit tests | Go test/testify, Fluentd test driver, Bash framework, Pester |
| E2E tests | Ginkgo (Go), pytest (Python) |

## Architecture Overview

The agent deploys two pod types:
1. **DaemonSet** — runs on every node, collects container stdout/stderr logs via Fluent Bit, forwards to Log Analytics or AMA/MDSD pipeline.
2. **ReplicaSet** — single instance per cluster, collects Kubernetes inventory (pods, nodes, events, deployments), performance metrics, and sends to Log Analytics and MDM.

Key data flow: Kubernetes API → Ruby/Go plugins → Fluent Bit/Fluentd → Azure Monitor (Logs + Metrics).

## Functional Requirements
### 1) Collect container stdout/stderr logs from all pods and forward to Azure Monitor Logs
### 2) Collect Kubernetes object inventory (pods, nodes, events, deployments, HPA)
### 3) Collect container performance metrics (CPU, memory) via cAdvisor
### 4) Send custom metrics to Azure Monitor Metrics (MDM) for alerting
### 5) Support Arc-enabled Kubernetes clusters alongside AKS
### 6) Support Windows and Linux nodes
### 7) Support multi-tenancy logging and Prometheus scraping

## Non-Functional Requirements
- Must operate within Kubernetes resource limits (CPU/memory)
- Must handle large clusters (thousands of nodes/pods) via chunked processing
- Must support proxy configurations for restricted networks
- Must not leak secrets or PII in logs/telemetry
- Container images must pass Trivy critical/high CVE scanning

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugin source |
| `source/plugins/go/input/` | Go Fluent Bit input plugin source |
| `source/plugins/ruby/` | Ruby Fluentd plugins |
| `kubernetes/linux/` | Linux container Dockerfile and entrypoint scripts |
| `kubernetes/windows/` | Windows container Dockerfile and entrypoint scripts |
| `build/linux/` | Linux build system (Makefile, installer) |
| `charts/` | Helm charts for deployment |
| `test/unit-tests/` | Unit test suites (Bash, Go, Ruby, PowerShell) |
| `test/ginkgo-e2e/` | Ginkgo E2E tests |
| `test/e2e/` | Python E2E tests |
| `.github/workflows/` | CI/CD workflows |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key |
| `APPLICATIONINSIGHTS_ENDPOINT` | Application Insights ingestion endpoint |
| `AKS_RESOURCE_ID` | Azure resource ID of the AKS cluster |
| `AKS_REGION` | Azure region of the cluster |
| `AGENT_VERSION` | Current agent version string |
| `CONTROLLER_TYPE` | `DaemonSet` or `ReplicaSet` — determines code paths |
| `OS_TYPE` | `linux` or `windows` |
| `CONTAINER_TYPE` | Container type identifier |
| `AZMON_CLUSTER_COLLECT_ENV_VAR` | Cluster collection configuration |
| `AZMON_LOG_TAIL_PATH` | Log tail file path |

## Acceptance Criteria

- All four unit test suites pass (Bash, Go, Ruby, PowerShell) in `run_unit_tests.yml`
- Docker image builds successfully for both Linux and Windows
- Trivy scan reports no unfixed critical/high CVEs
- CodeQL and DevSkim scans pass without new findings
- Helm chart version is bumped if chart files are modified
