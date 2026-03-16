# Docker-Provider (Container Insights)

Azure Monitor Container Insights agent that collects container logs, performance metrics, and Kubernetes inventory from AKS, ARC-enabled, and on-premises Kubernetes clusters.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log collection | Fluent Bit (C), Fluentd (Ruby plugins) |
| Metrics collection | Telegraf (Go) |
| Custom output plugins | Go (Fluent Bit output) |
| Inventory & MDM plugins | Ruby (Fluentd input/output/filter) |
| Build system | Make, Docker |
| Container base | CBL-Mariner 3 |
| Orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Deployment | Helm charts, ARM templates, Bicep, Terraform |
| Telemetry | Application Insights (Go SDK + Ruby wrapper) |
| CI/CD | GitHub Actions, Azure Pipelines |
| Testing | Bash unit tests, Go tests, Ruby tests, Ginkgo E2E, PowerShell Pester |

## Architecture Overview

The agent runs as a DaemonSet (per-node data collection) and a ReplicaSet (cluster-level collection) inside `kube-system`. Fluent Bit collects container stdout/stderr logs, Go plugins process and forward them to MDSD/Geneva. Ruby Fluentd plugins collect Kubernetes inventory, performance counters, and MDM metrics. Telegraf collects host and container metrics.

## Functional Requirements
### 1) Container log collection via Fluent Bit and Go output plugins
### 2) Kubernetes inventory collection (pods, nodes, containers, deployments, HPAs)
### 3) Performance metric collection via CAdvisor API and Telegraf
### 4) MDM metric generation for alerting
### 5) Multi-cloud support (AKS, ARC, on-premises)

## Non-Functional Requirements
- High reliability in production Kubernetes clusters
- Low resource footprint (CPU/memory limits enforced)
- Security: non-root containers, Trivy scanning, CodeQL SAST
- Telemetry: Application Insights for agent health monitoring
- Multi-architecture support (amd64, arm64)

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugins |
| `source/plugins/go/input/` | Go Fluent Bit input plugins |
| `source/plugins/ruby/` | Ruby Fluentd plugins |
| `build/linux/` | Linux build system (Makefile) |
| `kubernetes/linux/` | Linux Dockerfile and configs |
| `kubernetes/windows/` | Windows Dockerfile and configs |
| `charts/` | Helm charts |
| `deployment/` | ARM, Bicep, Terraform templates |
| `test/` | Unit tests, E2E tests, test automation |
| `scripts/` | Utility and operational scripts |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `APPLICATIONINSIGHTS_AUTH` | App Insights instrumentation key |
| `APPLICATIONINSIGHTS_ENDPOINT` | App Insights endpoint URL |
| `CONTROLLER_TYPE` | DaemonSet or ReplicaSet |
| `OS_TYPE` | linux or windows |
| `AKS_RESOURCE_ID` | AKS cluster resource ID |
| `AKS_REGION` | AKS cluster region |
| `CONTAINER_RUNTIME` | Container runtime (docker, containerd) |
| `AAD_MSI_AUTH_MODE` | Authentication mode |

## Acceptance Criteria

- `cd build/linux && make` succeeds
- All unit tests pass (Bash, Go, Ruby, PowerShell)
- Trivy scan shows no new CRITICAL/HIGH CVEs
- CodeQL and DevSkim produce no new findings
- Docker image builds successfully
