# Docker-Provider (Azure Monitor Container Insights)

A Kubernetes monitoring agent that collects container logs, performance metrics, node/pod/container inventory, and Kubernetes events from AKS, Arc-enabled, and self-managed Kubernetes clusters. Data is sent to Azure Monitor (Log Analytics) and optionally to Geneva (internal Microsoft monitoring).

## Tech Stack

| Component | Technology |
|-----------|------------|
| Log Pipeline | Fluent Bit (custom Go output plugin) + Fluentd (Ruby input/filter plugins) |
| Go Plugins | Go 1.23.8, `fluent-bit-go`, `k8s.io/client-go`, `ApplicationInsights-Go` |
| Ruby Plugins | Ruby, Fluentd 1.14.2, `KubernetesApiClient`, `ApplicationInsightsUtility` |
| Container Base | Azure Linux 3.0 (Mariner) distroless |
| Build System | Make (Linux), PowerShell (Windows), multi-stage Docker |
| Helm Charts | `azuremonitor-containers`, `azuremonitor-containers-geneva` |
| CI/CD | GitHub Actions (PR validation), Azure Pipelines (production releases) |
| Unit Tests | Go `testing`/`testify`, Ruby test driver, Bash test framework, Pester 5.3.3 |
| E2E Tests | Python pytest, Go Ginkgo, Testkube |
| IaC | Terraform, Bicep (onboarding templates) |
| Security Scanning | Trivy, CodeQL, DevSkim |

## Architecture Overview

The agent runs as a **DaemonSet** (per-node metrics, logs) and **ReplicaSet** (cluster-level inventory, events) inside Kubernetes clusters:

1. **Fluent Bit Go Plugin** (`source/plugins/go/src/`) — Custom output plugin that receives log records from Fluent Bit and forwards them to Azure Monitor ingestion endpoints (OMS, OTLP). Also handles network flow logs and telemetry.
2. **Fluentd Ruby Plugins** (`source/plugins/ruby/`) — Input plugins that query the Kubernetes API and kubelet for node inventory, pod inventory, container inventory, events, persistent volumes, deployments, HPA. Filter plugins transform CAdvisor and Telegraf metrics to MDM format.
3. **Container Setup** (`kubernetes/linux/main.sh`, `kubernetes/linux/setup.sh`) — Bootstrap scripts that configure Fluent Bit, mdsd, and other services inside the container at startup.
4. **Helm Charts** (`charts/`) — Deployment manifests for AKS addon and standalone installations.
5. **Onboarding Scripts** (`scripts/onboarding/`) — ARM templates, Terraform modules, Bicep templates, and Azure Policy definitions for customer cluster onboarding.

## Functional Requirements

### 1) Container Log Collection
Collect stdout/stderr logs from all containers in the cluster via Fluent Bit and forward to Azure Monitor Log Analytics workspace.

### 2) Kubernetes Inventory Collection
Periodically query the Kubernetes API for node, pod, container, deployment, HPA, PV, and event inventory. Emit structured records to Azure Monitor.

### 3) Performance Metrics Collection
Collect CPU, memory, disk, and network metrics from CAdvisor (kubelet) and emit to Azure Monitor and/or MDM (Metrics).

### 4) Multi-Cloud and Arc Support
Support AKS, AKS-Engine, ARO, Arc-enabled Kubernetes, and self-managed clusters across Azure public, Azure Government, Azure China, and Azure Bleu clouds.

### 5) Network Flow Logging
Collect and forward Kubernetes network flow logs to Azure Monitor.

## Non-Functional Requirements

- **Security**: Trivy CVE scanning on every PR build. CodeQL and DevSkim static analysis. No secrets in code — use managed identity or certificate-based auth.
- **Multi-architecture**: Support `amd64` and `arm64` Linux builds via multi-stage Dockerfile.
- **Observability**: Application Insights telemetry for agent health monitoring.
- **Scalability**: Handle large clusters with paginated Kubernetes API calls and configurable collection intervals.
- **Minimal footprint**: Final container uses Azure Linux distroless base image.

## Expected Project Files

| File | Purpose |
|------|---------|
| `source/plugins/go/src/out_oms.go` | Main Go Fluent Bit output plugin |
| `source/plugins/go/src/oms.go` | OMS data processing logic |
| `source/plugins/ruby/KubernetesApiClient.rb` | Kubernetes API client wrapper |
| `source/plugins/ruby/in_kube_podinventory.rb` | Pod inventory Fluentd input plugin |
| `kubernetes/linux/Dockerfile.multiarch` | Multi-arch container image definition |
| `kubernetes/linux/main.sh` | Container entrypoint/bootstrap |
| `charts/azuremonitor-containers/values.yaml` | Helm chart default values |
| `build/linux/Makefile` | Linux build system |
| `build/version` | Build version numbers |
| `.github/workflows/run_unit_tests.yml` | CI unit test workflow |
| `.github/workflows/pr-checker.yml` | CI build and scan workflow |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `CONTROLLER_TYPE` | Pod controller type: `DaemonSet` or `ReplicaSet` |
| `CONTAINER_TYPE` | Container variant (e.g., `PrometheusSidecar`) |
| `LOGS_AND_EVENTS_ONLY` | When set, collect only logs and events (skip metrics/inventory) |
| `GENEVA_LOGS_INTEGRATION` | Enable Geneva logs integration |
| `GOUNITTEST` | Set to `true` to enable Go unit test mode |
| `ISTEST` | Set to `true` in test environments |
| `ACR_REGISTRY` | Azure Container Registry for image builds |
| `ACR_REPOSITORY` | ACR repository path |

## Acceptance Criteria

- All unit tests pass: Bash, Go, Ruby, PowerShell (CI `run_unit_tests.yml`)
- Docker image builds successfully (CI `pr-checker.yml`)
- Trivy security scan passes with no critical CVEs
- CodeQL analysis reports no high-severity findings
- DevSkim scan passes
- Helm chart templates render without errors (`helm template`)
