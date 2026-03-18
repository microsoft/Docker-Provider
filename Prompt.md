# Docker-Provider (Azure Monitor Container Insights Agent)

An open-source Kubernetes monitoring agent that collects container logs, performance metrics, node/pod/container inventory, and Kubernetes events from AKS, Arc-enabled Kubernetes, and on-premises clusters. Data is sent to Azure Monitor (Log Analytics and Azure Monitor Metrics) via the MDSD/Geneva pipeline.

## Tech Stack

| Component | Technology |
|-----------|------------|
| Container log collection | Fluent Bit (Go output plugin — `source/plugins/go/src/`) |
| Inventory & events | Fluentd (Ruby input/filter/output plugins — `source/plugins/ruby/`) |
| Prometheus metrics | Telegraf |
| Data pipeline | MDSD (Geneva agent) |
| Linux container base | Azure Linux 3.0 (Mariner) distroless |
| Windows container base | Windows Server LTSC |
| Container orchestration | Kubernetes (DaemonSet + ReplicaSet) |
| Infrastructure as code | Helm charts, EV2 (Express V2), Bicep, Terraform |
| CI/CD | GitHub Actions (unit tests, CodeQL, DevSkim), Azure Pipelines (builds, E2E, releases) |
| E2E testing | Ginkgo (Go), pytest (Python), Testkube |
| Unit testing | Go test + testify, Minitest (Ruby), custom Bash framework, Pester (PowerShell) |
| Telemetry | Application Insights (Go + Ruby SDKs) |
| Languages | Ruby (~29%), Go (~13%), Shell (~16%), PowerShell (~9%), Python (~8%), YAML/JSON (~25%) |

## Architecture Overview

The agent runs as a DaemonSet (per-node) and ReplicaSet (cluster-level) in Kubernetes clusters:

- **DaemonSet pod:** Fluent Bit collects container logs → Go output plugin processes and sends to MDSD. Fluentd Ruby plugins collect node inventory, container inventory, and perf metrics. Telegraf scrapes Prometheus metrics.
- **ReplicaSet pod:** Fluentd Ruby plugins collect cluster-level inventory (deployments, HPAs, events, pod inventory).
- **MDSD:** Routes all collected data to Log Analytics workspace or Azure Monitor Metrics via DCR (Data Collection Rules).

## Functional Requirements

### 1) Container Log Collection
Collect stdout/stderr container logs from all pods, parse Kubernetes metadata, support ContainerLogV2 schema, and support multi-line log parsing.

### 2) Kubernetes Inventory Collection
Collect node, pod, container, deployment, HPA, and persistent volume inventory at configurable intervals.

### 3) Performance Metrics Collection
Collect CPU, memory, disk, and network metrics from cAdvisor and kubelet APIs. Support Prometheus metric scraping via Telegraf.

### 4) Multi-cluster Support
Support AKS, Arc-enabled Kubernetes, AKS Engine, ARO, and on-premises Kubernetes clusters with both legacy and MSI authentication.

## Non-Functional Requirements

- Multi-architecture support (amd64 + arm64)
- Distroless container images for minimal attack surface
- Configurable via ConfigMaps (`container-azm-ms-agentconfig.yaml`)
- Support for network flow logging, OTLP, and Geneva integration
- Trivy vulnerability scanning in CI/CD pipeline

## Expected Project Files

| Path | Purpose |
|------|---------|
| `source/plugins/ruby/` | Fluentd input/filter/output plugins (Ruby) |
| `source/plugins/go/src/` | Fluent Bit output plugin (Go) |
| `source/plugins/go/input/` | Fluent Bit input plugins (Go) |
| `kubernetes/linux/` | Linux container Dockerfile, setup scripts, main entrypoint |
| `kubernetes/windows/` | Windows container Dockerfile and scripts |
| `charts/` | Helm charts (standard, prod, Geneva variants) |
| `deployment/` | EV2 deployment configurations |
| `test/unit-tests/` | Unit tests (Bash, Go, Ruby, PowerShell) |
| `test/ginkgo-e2e/` | Ginkgo E2E tests (Go) |
| `test/e2e/` | Python E2E tests |
| `build/linux/` | Linux build system (Makefile, installer) |
| `scripts/onboarding/` | Cluster onboarding scripts and templates |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key |
| `AKS_RESOURCE_ID` | AKS cluster resource ID |
| `ACS_RESOURCE_NAME` | Non-AKS cluster resource name |
| `CONTROLLER_TYPE` | DaemonSet or ReplicaSet |
| `OS_TYPE` | linux or windows |
| `CONTAINER_RUNTIME` | Container runtime name |
| `GOUNITTEST` | Set to `true` for Go unit test mode |
| `ISTEST` | Set to `true` for test mode |

## Acceptance Criteria

- All four unit test suites pass (Bash, Go, Ruby, PowerShell)
- CodeQL analysis passes for Go, Python, Ruby
- DevSkim security scan passes
- No critical/high Trivy CVEs without `.trivyignore` justification
- Container images build successfully for amd64 and arm64
