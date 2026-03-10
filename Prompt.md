# Docker-Provider (Azure Monitor Container Insights Agent)

Azure Monitor Container Insights agent that collects container logs, Kubernetes inventory, performance metrics, and telemetry from Kubernetes clusters (AKS, Arc-enabled, hybrid environments) and forwards data to Azure Monitor / Log Analytics workspaces.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log output plugin | Go 1.23.8 (Fluent Bit CGo plugin) |
| Input/filter plugins | Ruby (Fluentd 1.14.2+) |
| Build system | Make (Linux), PowerShell (Windows) |
| Container base | Azure Linux (Mariner) distroless, Windows Server Core |
| Orchestration | Kubernetes DaemonSet + ReplicaSet |
| Telemetry | Application Insights (Go + Ruby SDKs) |
| Package management | Helm 3 charts |
| CI/CD | GitHub Actions + Azure DevOps Pipelines |
| E2E testing | Python pytest + Go Ginkgo |
| Unit testing | Bash scripts, Go testing, Pester 5.3.3 |
| Security scanning | CodeQL, DevSkim, Trivy |
| IaC | Bicep, Terraform, Helm |

## Architecture Overview

The agent runs as a DaemonSet (per-node) and ReplicaSet (cluster-wide) in Kubernetes. The Go plugin (`source/plugins/go/src/`) handles Fluent Bit output to Log Analytics. Ruby plugins (`source/plugins/ruby/`) collect Kubernetes inventory, pod metrics, and container logs via Fluentd. MDSD handles Geneva telemetry forwarding. Entry points are `kubernetes/linux/main.sh` (Linux) and `kubernetes/windows/main.ps1` (Windows).

## Functional Requirements

### 1) Container Log Collection
Collect stdout/stderr logs from all containers, parse multi-line formats, and forward to Log Analytics in ContainerLogV2 schema.

### 2) Kubernetes Inventory
Collect pod, node, deployment, service inventory from Kubernetes API and emit as structured records.

### 3) Performance Metrics
Collect CPU, memory, disk, and network metrics from cAdvisor and Kubernetes metrics API.

### 4) Multi-Cloud Support
Support Azure Public, China, Government, US Nat, US Sec, and Azure Bleu cloud environments.

## Non-Functional Requirements

- Must handle clusters with 10,000+ pods (high-scale mode)
- Telemetry instrumented via Application Insights for operational monitoring
- Container images scanned for CVEs before release (Trivy)
- Supports both AMD64 and ARM64 architectures
- Windows agent support (Server Core LTSC2019/2022)

## Expected Project Files

| File/Directory | Purpose |
|---------------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugin |
| `source/plugins/ruby/` | Ruby Fluentd input/filter plugins |
| `kubernetes/linux/` | Linux container setup and entrypoint |
| `kubernetes/windows/` | Windows container setup and entrypoint |
| `build/linux/` | Linux Makefile and installer |
| `build/windows/` | Windows build scripts |
| `charts/` | Helm charts for deployment |
| `test/unit-tests/` | Multi-language unit tests |
| `test/e2e/` | Python E2E test framework |
| `test/ginkgo-e2e/` | Go Ginkgo E2E tests |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights auth key (telemetry) |
| `TELEMETRY_APPLICATIONINSIGHTS_KEY` | Telemetry instrumentation key |
| `DOMAIN` | Log Analytics domain (opinsights.azure.com) |
| `WSID` | Log Analytics workspace ID |
| `CLUSTER_CLOUD_ENVIRONMENT` | Target cloud environment |
| `CONTROLLER_TYPE` | DaemonSet or ReplicaSet |
| `OS_TYPE` | linux or windows |

## Acceptance Criteria

- All unit tests pass (Bash, Go, Ruby, PowerShell)
- CodeQL analysis finds no new security issues
- DevSkim scan passes
- Docker image builds successfully for target architecture
- No new critical/high CVEs introduced (Trivy scan)
- Helm chart version bumped for releases
