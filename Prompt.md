# Azure Monitor Container Insights Agent

Azure Monitor for containers (Container Insights) agent for Linux and Windows Kubernetes clusters. Collects container logs, performance metrics, inventory, and network flow data via Fluent Bit/Fluentd plugins and ships to Azure Monitor.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log pipeline (output) | Go — Fluent Bit output plugin (`source/plugins/go/src/`) |
| Log pipeline (input) | Go — Fluent Bit input plugins (`source/plugins/go/input/`) |
| Metric collection | Ruby — Fluentd plugins (`source/plugins/ruby/`) |
| Telemetry | Application Insights (Go SDK + custom Ruby utility) |
| Container runtime | Docker (multi-arch Linux, Windows Server Core) |
| Orchestration | Kubernetes (DaemonSet, ReplicaSet) |
| Package management | Helm 3 (`charts/`) |
| Build (Linux) | GNU Make (`build/linux/Makefile`) |
| Build (Windows) | PowerShell (`build/windows/Makefile.ps1`) |
| CI/CD | GitHub Actions + Azure Pipelines |
| Security scanning | Trivy, CodeQL, DevSkim |
| Testing | Go testing, Ruby test driver, Bash test framework, Pester, Ginkgo, pytest |
| Infrastructure | Terraform, Bicep (onboarding scripts) |
| Deployment | Helm, Azure Arc K8s extensions, EV2 |

## Architecture Overview

The agent runs as containers inside a Kubernetes cluster:
- **DaemonSet**: Runs on every node, collects container logs via Fluent Bit with a Go output plugin that sends data to Azure Monitor ingestion endpoints.
- **ReplicaSet**: Runs a single instance for cluster-level data (inventory, metrics) using Fluentd with Ruby plugins querying the Kubernetes API and cAdvisor.
- **Sidecar mode**: Optional high-scale log collection mode.

Key data flows:
1. Container stdout/stderr → Fluent Bit → Go output plugin (`oms.go`) → Azure Monitor Ingestion API
2. Kubernetes API → Ruby plugins (inventory, metrics) → Fluentd → MDSD → Log Analytics
3. cAdvisor → Ruby `CAdvisorMetricsAPIClient` → Performance metrics → Azure Monitor
4. Network flow logs → Go plugin (`network_flow_logs.go`) → Azure Monitor

## Functional Requirements
### 1) Collect container logs (stdout/stderr) from all pods and ship to Log Analytics
### 2) Collect Kubernetes inventory (pods, nodes, containers, services) periodically
### 3) Collect performance metrics (CPU, memory, disk, network) from cAdvisor and Kubernetes API
### 4) Support multiple authentication modes (MSI, workload identity, FIC, legacy key-based)
### 5) Support AKS, Azure Arc-enabled Kubernetes, and standalone clusters
### 6) Support both Linux and Windows node pools
### 7) Collect network flow logs for network observability
### 8) Support OTLP (OpenTelemetry) log and trace ingestion

## Non-Functional Requirements
- Container images scanned for critical/high CVEs with Trivy (must pass with zero findings)
- Multi-architecture support (amd64/arm64 for Linux)
- Configurable via ConfigMap for log filtering, collection frequency, and resource limits
- Graceful degradation when Kubernetes API is unreachable
- Liveness and readiness probes for Kubernetes health checks

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/go/src/oms.go` | Main Fluent Bit output plugin |
| `source/plugins/go/src/telemetry.go` | Application Insights telemetry |
| `source/plugins/go/input/` | Fluent Bit input plugins (inventory, perf) |
| `source/plugins/ruby/` | Fluentd filter/input plugins |
| `kubernetes/linux/Dockerfile.multiarch` | Linux container image |
| `kubernetes/windows/Dockerfile` | Windows container image |
| `kubernetes/linux/main.sh` | Linux container entry point |
| `charts/azuremonitor-containers/` | Helm chart for non-AKS clusters |
| `build/linux/Makefile` | Linux build system |
| `build/common/installer/scripts/` | Shared configuration parsing scripts |
| `.github/workflows/` | GitHub Actions CI (unit tests, PR build, security scans) |
| `.pipelines/` | Azure Pipelines (production builds, releases) |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `AKS_RESOURCE_ID` | Azure Resource ID for AKS clusters |
| `ACS_RESOURCE_NAME` | Resource name for non-AKS clusters |
| `CONTAINER_RUNTIME` | Container runtime (docker/containerd) |
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key |
| `GOUNITTEST` | Set to `true` to enable test-only code paths in Go |
| `ISTEST` | Set to `true` for test mode |
| `CONTROLLER_TYPE` | DaemonSet or ReplicaSet role |
| `HOSTNAME` | Node/pod hostname for telemetry dimensions |

## Acceptance Criteria
- All unit tests pass (Bash, Go, Ruby, PowerShell)
- Docker image builds successfully for target platforms
- Trivy scan reports zero critical/high CVEs
- CodeQL analysis reports no new security findings
- DevSkim scan reports no new security findings
