# Docker-Provider (Azure Monitor for Containers)

Azure Monitor for Containers agent — collects container logs, metrics, inventory, and events from Kubernetes clusters (AKS, Arc-enabled, hybrid) and forwards them to Azure Monitor / Log Analytics.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log pipeline | Fluent Bit (output/input Go plugins) + Fluentd (Ruby plugins) |
| Telemetry SDK | Application Insights (Go + Ruby) |
| Agent framework | Azure Monitor Agent (MDSD) |
| Container runtime | Azure Linux 3.0 (Mariner) distroless base |
| Build system | Make (Linux), PowerShell (Windows) |
| CI/CD | GitHub Actions (PR checks), Azure Pipelines (releases) |
| Package format | RPM + DEB (Linux), Docker images (multi-arch) |
| Deployment | Helm charts, Kubernetes DaemonSet/ReplicaSet, Azure Arc extensions |
| E2E testing | Ginkgo (Go), TestKube, conformance YAML |
| Unit testing | Go test, Ruby minitest, Bash test framework, Pester (PowerShell) |
| Languages | Ruby, Go, Shell, PowerShell, Python, YAML |

## Architecture Overview

The agent runs as a DaemonSet (per-node) and ReplicaSet (cluster-level) in Kubernetes. Fluent Bit collects container logs and metrics via Go input/output plugins. Ruby Fluentd plugins handle Kubernetes API inventory (nodes, pods, events) and MDM metric filtering. Data flows through MDSD (Azure Monitor Agent) to Azure Monitor / Log Analytics workspaces.

## Functional Requirements
### 1) Container log collection via Fluent Bit with configurable schemas (ContainerLogV2)
### 2) Kubernetes inventory collection (nodes, pods, containers, events) via API server
### 3) Performance metrics (CPU, memory, network) via cAdvisor and Telegraf
### 4) MDM/Azure Monitor Metrics forwarding for alerting
### 5) Multi-arch support (amd64 + arm64) for Linux and Windows
### 6) Azure Arc extension support for non-AKS clusters

## Non-Functional Requirements
- Trivy vulnerability scanning on every PR (CRITICAL/HIGH must pass)
- CodeQL SAST for Go, Python, Ruby
- DevSkim security pattern scanning
- Container runs as non-root where possible
- Secrets via environment variables only (APPLICATIONINSIGHTS_AUTH, etc.)

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/go/src/` | Go Fluent Bit output plugin (out_oms) |
| `source/plugins/go/input/` | Go Fluent Bit input plugins (containerinventory, perf) |
| `source/plugins/ruby/` | Ruby Fluentd plugins (inventory, metrics, filters) |
| `build/linux/Makefile` | Linux build system |
| `build/windows/Makefile.ps1` | Windows build system |
| `kubernetes/linux/Dockerfile.multiarch` | Linux container image |
| `kubernetes/windows/Dockerfile` | Windows container image |
| `charts/azuremonitor-containers/` | Public Helm chart |
| `test/unit-tests/` | Unit tests (Bash, Go, Ruby, PowerShell) |
| `test/ginkgo-e2e/` | Ginkgo E2E test suites |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key (base64) |
| `APPLICATIONINSIGHTS_ENDPOINT` | AI ingestion endpoint |
| `AKS_RESOURCE_ID` | AKS cluster resource ID |
| `ACS_RESOURCE_NAME` | Non-AKS resource name |
| `CONTROLLER_TYPE` | DaemonSet or ReplicaSet |
| `CONTAINER_RUNTIME` | Container runtime (docker/containerd) |
| `OS_TYPE` | Operating system (linux/windows) |
| `AAD_MSI_AUTH_MODE` | AAD MSI authentication mode |

## Acceptance Criteria
- Linux and Windows Docker images build successfully
- Trivy scan passes with no CRITICAL/HIGH vulnerabilities (unfixed excluded)
- All unit tests pass (Bash, Go, Ruby, PowerShell)
- CodeQL and DevSkim scans produce no new findings
- Helm chart version bumped for releases
