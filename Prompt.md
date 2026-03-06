# Docker-Provider (Azure Monitor for Containers Agent)

Azure Monitor for Containers agent that collects container logs, metrics, and Kubernetes inventory from AKS and Arc-enabled Kubernetes clusters, forwarding telemetry to Azure Monitor / Log Analytics.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log collection plugins | Ruby (Fluent Bit input/filter plugins) |
| Output plugin | Go (Fluent Bit output, C-shared library) |
| Metrics collection | Telegraf |
| Log pipeline | Fluent Bit |
| Container runtime | Docker / containerd |
| Orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Container OS (Linux) | CBL-Mariner 3 |
| Container OS (Windows) | Windows Server Core |
| Build system | Make, Docker |
| CI/CD | GitHub Actions, Azure Pipelines |
| Telemetry | Application Insights (Go + Ruby SDKs) |
| Infrastructure as Code | Helm, Terraform, Bicep, Ev2 |
| Unit testing | Go test, Ruby test/unit, Bash (custom framework) |
| E2E testing | Ginkgo/Gomega (Go), pytest (Python) |

## Architecture Overview

The agent runs as two Kubernetes workloads:
- **ama-logs (DaemonSet)**: Runs on every node, collects container stdout/stderr logs, node-level metrics via Telegraf, and cAdvisor performance data.
- **ama-logs-rs (ReplicaSet)**: Single instance per cluster, collects cluster-level Kubernetes inventory (pods, nodes, deployments, events).

Both workloads embed Fluent Bit with custom Ruby input/filter plugins and a Go output plugin (`out_oms.so`). Data flows through Fluent Bit's pipeline and is forwarded to Azure Monitor Collection Service (AMCS) or directly to Log Analytics.

Key source directories:
- `source/plugins/ruby/` — Fluent Bit Ruby plugins (input, filter, output)
- `source/plugins/go/src/` — Go output plugin (out_oms)
- `source/plugins/go/input/` — Go input plugins (container inventory, perf)
- `build/` — Build scripts, Makefiles, installer configs
- `kubernetes/` — Dockerfiles, entry point scripts, ACR workflows
- `charts/` — Helm charts for non-AKS deployment
- `deployment/` — Ev2 deployment configurations for Arc extension releases

## Functional Requirements

### 1) Container Log Collection
Collect stdout/stderr logs from all containers on each node, parse multiline formats (Java, Python, Go, .NET), and forward to ContainerLog / ContainerLogV2 tables in Log Analytics.

### 2) Kubernetes Inventory Collection
Periodically query Kubernetes API for pod, node, deployment, service, and event inventory. Forward to KubePodInventory, KubeNodeInventory, and related tables.

### 3) Performance Metrics Collection
Collect node and container performance metrics (CPU, memory, disk, network) via cAdvisor and Telegraf. Forward as Perf and InsightsMetrics records.

### 4) Custom Metrics to MDM
Filter and forward specific inventory and performance data as custom metrics to Azure Monitor Metrics (MDM) for alerting.

### 5) Multi-cloud and Multi-tenant Support
Support AKS, Arc-enabled Kubernetes, and hybrid clusters across Azure public, sovereign clouds (China, USGov, USNat, USSec), and Bleu.

## Non-Functional Requirements

- **Scalability**: Handle high-scale clusters (5000+ nodes) with batching, backpressure, and configurable resource limits.
- **Security**: Run as non-root, use managed identity (MSI) or certificate-based auth, scan images with Trivy/CodeQL/DevSkim.
- **Observability**: Agent self-telemetry via Application Insights — heartbeats, error rates, flush metrics.
- **Reliability**: Liveness probes, graceful shutdown, retry with exponential backoff for transient failures.

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/ruby/` | Fluent Bit Ruby plugins (in_kube_*, filter_*, out_*) |
| `source/plugins/go/src/` | Go output plugin and telemetry |
| `build/linux/Makefile` | Linux build orchestration |
| `build/version` | Build version numbers |
| `kubernetes/linux/Dockerfile.multiarch` | Linux container image |
| `kubernetes/linux/main.sh` | Linux container entry point |
| `kubernetes/windows/Dockerfile` | Windows container image |
| `charts/azuremonitor-containers/` | Public Helm chart |
| `test/unit-tests/` | Unit test framework and cases |
| `test/ginkgo-e2e/` | Ginkgo E2E test suites |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key (telemetry) |
| `APPLICATIONINSIGHTS_ENDPOINT` | Application Insights ingestion endpoint |
| `AKS_RESOURCE_ID` | Azure resource ID of the AKS cluster |
| `AKS_REGION` | Azure region of the cluster |
| `CONTROLLER_TYPE` | Agent controller type (DaemonSet/ReplicaSet) |
| `OS_TYPE` | Operating system (linux/windows) |
| `CONTAINER_RUNTIME` | Container runtime (docker/containerd) |
| `CLUSTER_CLOUD_ENVIRONMENT` | Cloud environment (azurepubliccloud, azurechinacloud, etc.) |
| `AGENT_VERSION` | Agent version string |
| `AAD_MSI_AUTH_MODE` | MSI authentication mode |

## Acceptance Criteria

- All unit tests pass (`./test/unit-tests/test_main.sh`)
- Go tests pass with race detection (`go test -race ./...`)
- Docker image builds successfully for linux/amd64 and linux/arm64
- Trivy scan reports no new critical/high CVEs (or they are documented in `.trivyignore`)
- CodeQL and DevSkim scans pass
- Helm chart lints successfully
