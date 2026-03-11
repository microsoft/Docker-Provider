# Prompt.md — Docker-Provider

## Project Description

**Azure Monitor for Containers** (Container Insights) is a Kubernetes monitoring agent that collects container logs, performance metrics, and cluster inventory data. It runs as a DaemonSet on every node and a Deployment for cluster-wide resources. Data is collected through Fluent-Bit input plugins (Go and Ruby), transformed via filter plugins, and routed through the Go `out_oms` output plugin to Azure Monitor backends (Log Analytics, Azure Data Explorer, Geneva/MDSD).

The agent supports AKS, Arc-enabled Kubernetes, Azure Stack, OpenShift, and on-premises clusters across Linux and Windows nodes with multi-arch (amd64/arm64) container images.

## Tech Stack

| Component | Technology | Version | Purpose |
|---|---|---|---|
| Output Plugin | Go (c-shared) | 1.25.7 | Fluent-Bit output plugin for Log Analytics/ADX/MDSD |
| Input Plugins | Go | 1.25.7 | Container inventory and perf metrics collection |
| Input/Filter/Output Plugins | Ruby | 3.3.x | Kubernetes API inventory, cAdvisor metrics, MDM output |
| Fluent-Bit | C | 4.0.14 | Log pipeline engine |
| Fluentd | Ruby | 1.16.3 (prod) / 1.14.2 (test) | Plugin framework for Ruby plugins |
| Kubernetes Client | client-go | v0.29.3 | Kubernetes API access |
| Telemetry | ApplicationInsights-Go | v0.4.4 | Agent health and diagnostics |
| Serialization | msgpack (tinylib/msgp) | v1.1.9 | MDSD binary protocol |
| System Metrics | Telegraf | 1.37.1 | Host-level metrics collection |
| Monitoring Daemon | MDSD | 1.37.0 | Azure monitoring data sink |
| Container Base | Azure Linux 3.0 distroless | — | Production container image |
| Build System | Make + Docker | — | Multi-arch builds |
| CI | GitHub Actions + Azure DevOps | — | Unit tests, CodeQL, DevSkim |
| E2E Tests | pytest | — | Log Analytics query validation |
| E2E Tests | Ginkgo v2 | — | Kubernetes integration tests |
| Unit Tests (Go) | testify + golang/mock | — | Go plugin unit tests |
| Unit Tests (Ruby) | minitest | — | Ruby plugin unit tests |
| Unit Tests (PS) | Pester | 5.3.3 | PowerShell script tests |
| Security Scanning | CodeQL, DevSkim, Trivy | — | SAST and container scanning |
| Helm | Helm v3 | — | 3 charts for deployment |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
│                                                                 │
│  ┌───────────────────────────────────┐  ┌────────────────────┐  │
│  │  DaemonSet (per node)             │  │ Deployment (1x)    │  │
│  │                                   │  │                    │  │
│  │  Fluent-Bit ──► out_oms (Go)      │  │ Ruby kube plugins  │  │
│  │  Telegraf   ──► filter (Ruby)     │  │ ├─ podinventory    │  │
│  │  Ruby input ──► out_mdm (Ruby)    │  │ ├─ deployments     │  │
│  │                                   │  │ └─ hpa             │  │
│  │  MDSD daemon (msgpack sockets)    │  └────────────────────┘  │
│  └──────────┬────────────────────────┘            │              │
│             │                                     │              │
│             ▼                                     ▼              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Kubernetes API Server                        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────┬───────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┬──────────────┐
              ▼               ▼               ▼              ▼
     ┌──────────────┐ ┌─────────────┐ ┌───────────┐ ┌────────────┐
     │Log Analytics │ │Azure Data   │ │ Geneva /  │ │ Azure      │
     │  (ODS)       │ │Explorer     │ │ MDSD      │ │ Monitor    │
     │  - Logs v1/v2│ │(ADX)        │ │           │ │ Metrics    │
     │  - Perf      │ └─────────────┘ └───────────┘ │ (MDM)      │
     │  - Inventory │                                └────────────┘
     └──────────────┘
```

### Data Flow

1. **Container Logs:** Fluent-Bit `tail` input → Go `out_oms` plugin → Log Analytics (v1/v2), ADX, or Geneva
2. **Performance Metrics:** Ruby `in_cadvisor_perf` / Telegraf → Ruby filters → `out_mdm` (MDM) or `out_oms` (LA)
3. **Kubernetes Inventory:** Ruby `in_kube_*` plugins → Kubernetes API → `out_oms` → MDSD → Log Analytics
4. **Events:** Ruby `in_kube_events` → `out_oms` → Log Analytics KubeEvents table
5. **Telemetry:** Go/Ruby Application Insights SDK → Application Insights for agent health

### Routing Logic (`PostDataHelper` in `oms.go`)

- `AZMON_CONTAINER_LOG_SCHEMA_VERSION=v2` → ContainerLogV2 table
- `AZMON_CONTAINER_LOGS_ROUTE=adx` → Azure Data Explorer direct ingestion
- `GENEVA_LOGS_INTEGRATION=true` → MDSD Unix socket → Geneva
- `AAD_MSI_AUTH_MODE=true` (Windows) → Named pipe to AMA
- Default → Log Analytics ODS HTTP endpoint

## Functional Requirements Template

When specifying a new feature or change, include:

1. **Data Type:** Which data type constant does this affect? (e.g., `CONTAINER_LOG_BLOB`, `INSIGHTS_METRICS_BLOB`, `LINUX_PERF_BLOB`, `CONTAINER_INVENTORY_BLOB`, `KUBE_MON_AGENT_EVENTS_BLOB`, `CONTAINERINSIGHTS_CONTAINERLOGV2`)
2. **Plugin Layer:** Input, Filter, or Output? Go or Ruby?
3. **Deployment Context:** DaemonSet (per-node), Deployment (cluster-level), or both?
4. **Destination:** Log Analytics, ADX, Geneva/MDSD, MDM, or Application Insights?
5. **Schema:** What fields are emitted? What msgpack/JSON structure?
6. **Platform:** Linux only, Windows only, or both? amd64, arm64, or both?
7. **Config:** Any new environment variables or ConfigMap settings?

## Non-Functional Requirements

- **Multi-arch:** All changes must work on both amd64 and arm64. Test `TARGETARCH` branches in Dockerfiles.
- **Memory:** Agent runs in constrained environments. Avoid unbounded caches. Respect `MALLOC_ARENA_MAX=2` and `RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.0`.
- **Backward Compatibility:** Maintain msgpack schema for MDSD protocol. Never break existing Log Analytics table schemas.
- **Security:** No hardcoded secrets. Use environment variables for credentials. All images use distroless base. Pass CodeQL, DevSkim, and Trivy scans.
- **Telemetry:** All new code paths must include Application Insights telemetry (exception tracking and operational metrics).
- **Graceful Degradation:** Handle Kubernetes API timeouts, MDSD socket disconnects, and token refresh failures without crashing.
- **Idempotency:** Fluent-Bit may retry flushes. Output plugins must handle duplicate records safely.
- **Cloud Compatibility:** Support Azure public, China, US Government, USNat, USSec, and Azure Bleu cloud environments.

## Expected Project Files

```
source/plugins/go/src/         # Go output plugin (out_oms) + utilities
source/plugins/go/input/       # Go input plugins (containerinventory, perf)
source/plugins/ruby/            # Ruby Fluent plugins (in_*, out_*, filter_*)
build/linux/                    # Makefile, installer scripts
build/windows/                  # Windows build scripts
kubernetes/linux/               # Dockerfile.multiarch, setup.sh, main.sh
kubernetes/windows/             # Windows Dockerfile
kubernetes/ama-logs.yaml        # DaemonSet manifest
charts/                         # Helm charts (3 variants)
test/unit-tests/                # Unit tests (Bash, Go, Ruby, PowerShell)
test/e2e/                       # Python E2E tests (pytest)
test/ginkgo-e2e/                # Ginkgo E2E tests
scripts/                        # Build, deploy, troubleshoot scripts
.github/workflows/              # GitHub Actions CI
.pipelines/                     # Azure DevOps pipelines
deployment/                     # Release deployment configs
Documentation/                  # Agent settings docs
```

## Environment Variables

The agent is configured through environment variables set in the container image and overridden at runtime:

| Variable | Purpose |
|---|---|
| `APPLICATIONINSIGHTS_AUTH` | Application Insights instrumentation key (base64) |
| `HOST_MOUNT_PREFIX` | Host filesystem mount path (default: `/hostfs`) |
| `HOST_PROC` | Host /proc mount path |
| `HOST_SYS` | Host /sys mount path |
| `HOST_ETC` | Host /etc mount path |
| `HOST_VAR` | Host /var mount path |
| `AZMON_COLLECT_ENV` | Enable container env var collection |
| `CONTROLLER_TYPE` | Pod controller: `daemonset` or `replicaset` |
| `CONTAINER_RUNTIME` | Runtime: `docker`, `containerd` |
| `CONTAINER_TYPE` | Container type identifier |
| `OS_TYPE` | Operating system: `linux` or `windows` |
| `AGENT_VERSION` | Agent release version |
| `WSID` | Log Analytics Workspace ID |
| `DOMAIN` | Log Analytics Workspace domain |
| `HOSTNAME` | Computer/host name |
| `AKS_RESOURCE_ID` | AKS cluster Azure resource ID |
| `ACS_RESOURCE_NAME` | Non-AKS resource name |
| `AKS_REGION` | Cluster Azure region |
| `AAD_MSI_AUTH_MODE` | AAD MSI authentication mode |
| `AZMON_COLLECT_STDOUT_LOGS` | Enable stdout log collection |
| `AZMON_COLLECT_STDERR_LOGS` | Enable stderr log collection |
| `AZMON_CLUSTER_CONTAINER_LOG_ENRICH` | Container log enrichment |
| `AZMON_CONTAINER_LOGS_ROUTE` | Log routing: `default` or `adx` |
| `AZMON_CONTAINER_LOG_SCHEMA_VERSION` | Log schema: `v1` or `v2` |
| `AZMON_MULTI_TENANCY_LOGS_SERVICE_MODE` | Multi-tenancy log mode |
| `GENEVA_LOGS_INTEGRATION` | Enable Geneva logs integration |
| `GENEVA_LOGS_INTEGRATION_SERVICE_MODE` | Geneva service mode |
| `CLUSTER_CLOUD_ENVIRONMENT` | Cloud: `azurepubliccloud`, `azurechinacloud`, `azureusgovernmentcloud`, `usnat`, `ussec`, `azurebleucloud` |
| `IGNORE_PROXY_SETTINGS` | Skip proxy configuration |
| `PROXY` | HTTP/HTTPS proxy endpoint |
| `KUBE_CLIENT_BACKOFF_BASE` | K8s client retry backoff base |
| `KUBE_CLIENT_BACKOFF_DURATION` | K8s client retry backoff duration |
| `MALLOC_ARENA_MAX` | glibc malloc arena limit |
| `RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR` | Ruby GC tuning |
| `DOCKER_CIMPROV_VERSION` | Docker provider package version |
| `GOUNITTEST` | Set `true` during Go unit tests |
| `ISTEST` | Set `true` during test execution |

## Acceptance Criteria

All changes to this repository must satisfy:

1. **Unit Tests Pass:** All 4 test suites (Bash, Go, Ruby, PowerShell) pass with no regressions.
2. **Build Succeeds:** `cd build/linux && make` completes without errors.
3. **Docker Build:** `docker build -f kubernetes/linux/Dockerfile.multiarch` succeeds for target arch.
4. **Security Scans:** No new findings from CodeQL (Go, Python, Ruby), DevSkim, or Trivy.
5. **Multi-Arch:** Changes work on both amd64 and arm64 unless explicitly platform-specific.
6. **Schema Compatibility:** No breaking changes to msgpack record schemas sent to MDSD, Log Analytics table schemas, or Helm chart values without explicit versioning.
7. **Telemetry:** New error paths include `ApplicationInsightsUtility` exception telemetry (Ruby) or `SendExceptionTelemetry` (Go).
8. **Documentation:** Update `ReleaseNotes.md` for user-facing changes. Update `Dev Guide.md` for developer-facing changes.
9. **Environment Variables:** New env vars must be documented in Helm chart `values.yaml` and DaemonSet manifests.
10. **Backward Compatibility:** Existing monitoring data collection must not be interrupted by the change.
