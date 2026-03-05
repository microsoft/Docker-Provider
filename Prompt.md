# Docker-Provider (Azure Monitor Container Insights Agent)

A Kubernetes monitoring agent that collects container logs, metrics, inventory, and events from AKS, Azure Arc-enabled, and on-premises Kubernetes clusters. Data is sent to Azure Monitor / Log Analytics for analysis and alerting.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log Collection | Fluent Bit with custom Go output plugins |
| Metrics Collection | Telegraf |
| Inventory & Events | Ruby Fluentd plugins |
| Container Runtime | Azure Linux (Mariner 3.0) distroless |
| Orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Telemetry | Application Insights (Go + Ruby SDKs) |
| Build System | Make (Linux), PowerShell (Windows) |
| Packaging | Helm charts, Docker multi-arch images |
| IaC Templates | Bicep, Terraform, ARM JSON |
| CI/CD | GitHub Actions + Azure Pipelines |
| Testing | Go test, Ruby minitest, Bash test framework, Pester, Ginkgo (E2E) |
| Security Scanning | Trivy, CodeQL, DevSkim |

## Architecture Overview

The agent deploys as two Kubernetes workloads:
- **DaemonSet** — runs on every node, collects container logs via Fluent Bit and node-level metrics via Telegraf
- **ReplicaSet** — single instance per cluster, collects cluster-wide inventory (pods, nodes, deployments, HPAs) and Kubernetes events via Ruby Fluentd plugins

Key modules:
- `source/plugins/go/src/` — Go Fluent Bit output plugin (`out_oms`) that sends logs to Azure Monitor
- `source/plugins/go/input/` — Go Fluent Bit input plugins (container inventory, perf)
- `source/plugins/ruby/` — Ruby Fluentd plugins for Kubernetes API inventory and telemetry
- `build/linux/` — Linux build system and installer
- `build/windows/` — Windows build system
- `kubernetes/linux/` — Linux Docker image definition and startup scripts
- `kubernetes/windows/` — Windows Docker image and scripts
- `charts/` — Helm charts for deployment
- `scripts/onboarding/` — Customer onboarding templates (Bicep, Terraform, ARM, Azure Policy)

## Functional Requirements

### 1) Container Log Collection
Collect stdout/stderr logs from all containers, enrich with Kubernetes metadata, and forward to Azure Monitor using ContainerLogV2 schema.

### 2) Kubernetes Inventory Collection
Periodically query the Kubernetes API for pod, node, container, deployment, HPA, and event inventory. Emit structured records to Log Analytics.

### 3) Performance Metrics
Collect CPU, memory, disk, and network metrics from cAdvisor and Telegraf. Support custom Prometheus scraping.

### 4) Multi-Cloud & Multi-Tenant Support
Support AKS, Azure Arc-enabled Kubernetes, AKS-Engine, OpenShift, and on-premises clusters. Support multi-tenant logging configurations.

### 5) Network Flow Logs
Collect and forward Retina network flow logs from cluster nodes.

## Non-Functional Requirements

- **Security**: Trivy vulnerability scanning on every PR (CRITICAL/HIGH fail the build), CodeQL SAST for Go/Python/Ruby, DevSkim pattern scanning
- **Observability**: Self-telemetry via Application Insights (heartbeats, flush metrics, error tracking)
- **Performance**: Handle high-scale clusters (large node counts, high log volumes) with OTLP optimization
- **Deployment**: Helm chart-based deployment, Azure Arc extension release via EV2 pipelines
- **Compatibility**: Support Azure Linux (Mariner) 3.0, Windows Server 2019/2022

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugin |
| `source/plugins/go/input/` | Go Fluent Bit input plugins |
| `source/plugins/ruby/` | Ruby Fluentd inventory plugins |
| `build/linux/Makefile` | Linux build system |
| `build/windows/Makefile.ps1` | Windows build system |
| `kubernetes/linux/Dockerfile.multiarch` | Linux container image |
| `kubernetes/windows/Dockerfile` | Windows container image |
| `charts/azuremonitor-containers/` | Public Helm chart |
| `charts/azuremonitor-containers-geneva/` | Internal (Geneva) Helm chart |
| `scripts/onboarding/` | Customer onboarding templates |
| `test/unit-tests/` | Unit test suites (Bash, Go, Ruby, PowerShell) |
| `test/ginkgo-e2e/` | Ginkgo E2E test suites |
| `.github/workflows/` | CI/CD workflows |
| `.pipelines/` | Azure Pipelines definitions |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AKS_RESOURCE_ID` | Azure resource ID of the AKS cluster |
| `ACS_RESOURCE_NAME` | Resource name for non-AKS clusters |
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key |
| `APPLICATIONINSIGHTS_ENDPOINT` | App Insights ingestion endpoint |
| `CONTROLLER_TYPE` | Agent controller type: `DaemonSet` or `ReplicaSet` |
| `CONTAINER_RUNTIME` | Container runtime name |
| `OS_TYPE` | Operating system type (`linux` or `windows`) |
| `AKS_REGION` | AKS cluster region |
| `AGENT_VERSION` | Agent version string |
| `AAD_MSI_AUTH_MODE` | AAD Managed Identity auth mode flag |
| `GOUNITTEST` | Set to `true` to disable telemetry in Go tests |
| `ISTEST` | Set to `true` for test mode |

## Acceptance Criteria

- All four unit test suites pass (Bash, Go, Ruby, PowerShell)
- Trivy scan finds no new CRITICAL or HIGH vulnerabilities
- CodeQL analysis passes for Go, Python, Ruby
- DevSkim scan reports no security issues
- Docker image builds successfully for linux/amd64 and linux/arm64
- Helm chart templates render without errors
