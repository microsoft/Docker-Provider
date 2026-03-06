# Azure Monitor for Containers Agent

Azure Monitor for containers is a Kubernetes monitoring agent that collects container logs, performance metrics, inventory data, and Kubernetes events from AKS and Arc-enabled Kubernetes clusters. It runs as a DaemonSet (per-node) and ReplicaSet (single instance) inside clusters, shipping data to Azure Log Analytics, Azure Data Explorer, and Geneva Metrics.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log pipeline | Fluent Bit (cloudnative build) |
| Output plugin | Go 1.25.7 (C-shared library) |
| Input/Filter plugins | Ruby 3.3.x (Fluentd) |
| Container OS | Azure Linux (CBL-Mariner) |
| Build system | Make, Docker |
| CI/CD | Azure Pipelines, GitHub Actions |
| Unit testing | go test, Ruby test driver, Bash test framework, Pester (PowerShell) |
| E2E testing | Ginkgo (Go), pytest (Python) |
| Telemetry | Application Insights (Go SDK + custom Ruby wrapper) |
| Container orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Infrastructure | Helm charts, Bicep, Terraform (onboarding scripts) |
| Security scanning | CodeQL, DevSkim, Trivy |

## Architecture Overview

The agent deploys as two workloads:
1. **DaemonSet** — runs on every node, collects container logs via Fluent Bit, processes them through the Go output plugin (`out_oms.so`), and forwards to Azure Monitor backends (MDSD/AMA).
2. **ReplicaSet** — single instance per cluster, collects cluster-level inventory (pods, nodes, events, services) via Ruby Fluentd plugins and forwards to Azure Monitor.

Both workloads use Application Insights for agent health telemetry.

## Functional Requirements
### 1) Collect container stdout/stderr logs and forward to Azure Log Analytics or ADX
### 2) Collect Kubernetes inventory (pods, nodes, events, services, deployments, PVs)
### 3) Collect performance metrics (CPU, memory, disk) via cAdvisor
### 4) Support Prometheus metrics scraping and MDM (Geneva) metrics export
### 5) Support Windows and Linux nodes with platform-specific builds
### 6) Support network flow logs (Retina integration)

## Non-Functional Requirements

- Must run on Azure Linux (CBL-Mariner) base images
- Must support multi-architecture builds (amd64, arm64)
- Must pass Trivy vulnerability scans (CRITICAL and HIGH severity)
- Must emit agent health telemetry to Application Insights
- Must support configurable log collection via Kubernetes ConfigMaps

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugin source |
| `source/plugins/go/input/` | Go Fluent Bit input plugins (container inventory, perf) |
| `source/plugins/ruby/` | Ruby Fluentd input/filter/output plugins |
| `build/linux/Makefile` | Linux agent build |
| `kubernetes/linux/Dockerfile.multiarch` | Multiarch Linux container image |
| `kubernetes/windows/Dockerfile` | Windows container image |
| `charts/` | Helm charts for deployment |
| `test/unit-tests/` | Unit test suites (Bash, Go, Ruby, PowerShell) |
| `test/ginkgo-e2e/` | Ginkgo E2E tests |
| `test/e2e/` | Python E2E tests |
| `.pipelines/` | Azure Pipelines CI/CD |
| `.github/workflows/` | GitHub Actions (CodeQL, DevSkim, unit tests) |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key |
| `APPLICATIONINSIGHTS_ENDPOINT` | Application Insights endpoint URL |
| `AKS_RESOURCE_ID` | Azure resource ID of the AKS cluster |
| `ACS_RESOURCE_NAME` | Resource name for non-AKS clusters |
| `CONTROLLER_TYPE` | Deployment type: `DaemonSet` or `ReplicaSet` |
| `CONTAINER_RUNTIME` | Container runtime name |
| `OS_TYPE` | Operating system type (`linux` or `windows`) |
| `AZMON_CLUSTER_COLLECT_STDOUT_LOGS` | Enable/disable stdout log collection |
| `AZMON_CLUSTER_COLLECT_STDERR_LOGS` | Enable/disable stderr log collection |
| `AZMON_MULTILINE_ENABLED` | Enable multiline log processing |
| `AZMON_KUBERNETES_METADATA_ENABLED` | Enable Kubernetes metadata enrichment |
| `AZMON_RETINA_FLOW_LOGS_ENABLED` | Enable network flow log collection |

## Acceptance Criteria

- All unit tests pass (Bash, Go, Ruby, PowerShell)
- Trivy scan shows no new CRITICAL/HIGH vulnerabilities
- CodeQL and DevSkim scans pass
- Container image builds successfully for both linux/amd64 and linux/arm64
- Helm chart lints without errors
