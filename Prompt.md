# Docker-Provider (Azure Monitor Container Insights Agent)

Azure Monitor agent for Kubernetes that collects container logs, metrics, inventory, and performance data from AKS and Arc-enabled Kubernetes clusters. Runs as Fluent Bit/Fluentd plugins inside containerized DaemonSet and ReplicaSet pods on Linux and Windows nodes.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log Collection Plugins | Ruby (Fluentd), Go (Fluent Bit) |
| Build System | Make, Docker, Azure Pipelines |
| Container Runtime | Docker (multi-arch: amd64 + arm64) |
| Orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Package Management | Helm Charts |
| Telemetry | Application Insights (Ruby + Go SDKs) |
| CI/CD | GitHub Actions (PR checks), Azure Pipelines (builds + releases) |
| Security Scanning | CodeQL, DevSkim, Trivy |
| Testing | Bash framework, Go test, Ruby Minitest, PowerShell Pester, Ginkgo E2E |
| Infrastructure | Terraform, Bicep (onboarding scripts) |
| Cloud Targets | AKS, Arc-enabled K8s, ARO |

## Architecture Overview

The agent is deployed as two workloads: a DaemonSet (`ama-logs`) on every node for log collection, and a ReplicaSet (`ama-logs-rs`) for cluster-level inventory. Both use Fluent Bit as the log pipeline with Go output plugins (`out_oms.so`) for sending data and Ruby Fluentd plugins for metrics, inventory, and MDM integration. Data flows to Log Analytics workspaces and Azure Monitor Metrics.

## Functional Requirements
### 1) Collect container logs from all pods and forward to Log Analytics
### 2) Collect Kubernetes inventory (pods, nodes, containers, PVs) and send to Log Analytics
### 3) Collect performance metrics (CPU, memory, disk) via CAdvisor and send to Azure Monitor Metrics
### 4) Support multi-arch builds (amd64 + arm64) for Linux and Windows nodes
### 5) Support multiple cloud environments (Azure Public, Azure China, Azure Government, Azure Bleu)

## Non-Functional Requirements

- **Security:** Trivy container scanning, CodeQL SAST, DevSkim analysis on every PR
- **Observability:** Agent self-telemetry via Application Insights (heartbeat, exceptions, performance metrics)
- **Reliability:** Liveness probes, graceful shutdown, retry logic for data transmission
- **Performance:** Efficient log parsing with Fluent Bit, configurable flush intervals

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/ruby/` | Ruby Fluentd plugins (inventory, metrics, MDM filters) |
| `source/plugins/go/src/` | Go Fluent Bit output plugin (container logs) |
| `source/plugins/go/input/` | Go Fluent Bit input plugins (container inventory, perf) |
| `kubernetes/linux/` | Linux Dockerfile, main.sh entry point, setup scripts |
| `kubernetes/windows/` | Windows Dockerfile, main.ps1 entry point |
| `charts/` | Helm charts for deployment |
| `build/linux/` | Linux build system (Makefile, installer) |
| `scripts/` | Onboarding, troubleshooting, and build scripts |
| `test/` | Unit tests, E2E tests, scenario tests |
| `.pipelines/` | Azure Pipelines for builds and releases |
| `.github/workflows/` | GitHub Actions for PR checks |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `APPLICATIONINSIGHTS_AUTH` | Base64-encoded Application Insights instrumentation key |
| `APPLICATIONINSIGHTS_ENDPOINT` | Application Insights ingestion endpoint URL |
| `AKS_RESOURCE_ID` | Azure resource ID of the AKS cluster |
| `AKS_REGION` | Azure region of the cluster |
| `OS_TYPE` | Operating system type (linux/windows) |
| `CONTROLLER_TYPE` | Kubernetes controller type (DaemonSet/ReplicaSet) |
| `AGENT_VERSION` | Current agent version string |
| `CONTAINER_RUNTIME` | Container runtime in use |

## Acceptance Criteria

- All unit tests pass: Bash, Go, Ruby, and PowerShell
- CodeQL analysis reports no new vulnerabilities
- DevSkim scan reports no new security issues
- Trivy container scan shows no new critical/high vulnerabilities
- Docker image builds successfully for both amd64 and arm64
- Helm chart lints successfully
