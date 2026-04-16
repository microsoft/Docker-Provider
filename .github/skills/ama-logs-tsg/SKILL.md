---
name: ama-logs-tsg
description: >
  Troubleshoot Container Insights (ama-logs / Docker-Provider) ICMs
  by running diagnostic KQL queries against App Insights and Kusto.
  USE FOR: ICM investigation, customer escalation, Container Insights TSG,
  ama-logs troubleshooting, container log issues, missing data,
  OOM kills, liveness probe failures, ingestion latency, high log scale,
  network errors, MDSD errors, fluent-bit issues,
  KubePodInventory gaps, large cluster tuning, private link, onboarding.
  DO NOT USE FOR: code changes, build fixes, EV2 artifacts, load testing.
argument-hint: 'Provide the ICM number or cluster ARM resource ID — e.g. "investigate ICM 12345678" or "troubleshoot cluster /subscriptions/.../managedClusters/mycluster"'
---

# Container Insights (ama-logs) Troubleshooting Skill

Investigate ICMs for Container Insights (ama-logs / Docker-Provider) by running diagnostic
KQL queries against the ContainerInsightsAgent-Prod App Insights resource and AKS Kusto clusters.

## Workflow

### Step 1: Gather Context

If an **ICM number** is provided:

#### 1a. Use ICM MCP tools (run in parallel)

| Tool | What it returns | Reliability |
|------|----------------|-------------|
| `icm-get_incident_details_by_id` | Severity, state, owning team, custom fields, howFixed | ✅ Always works |
| `icm-get_ai_summary` | AI-generated summary — may contain the cluster ARM ID | ✅ Usually works |
| `icm-get_incident_context` | AI-generated Description, DiscussionSection, symptoms, causes | ⚠️ ~60% success |
| `icm-get_incident_location` | Region, cluster, datacenter info | ✅ Usually works |
| **`tsg_icm_page`** | **Authored summary** (full problem description, ARM IDs), **discussion entries** | ✅ Requires Edge CDP |

**⚠️ CRITICAL:** The `icm-get_incident_context` fields are AI-generated paraphrases, NOT the original text. Always use the browser scrape for the full authored summary.

#### 1b. Finding the Cluster ARM ID

The cluster ARM resource ID is critical. It looks like:
`/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ContainerService/managedClusters/{name}`

Search order:
1. `icm-get_incident_context` → search Description, DiscussionSection for ARM ID pattern
2. `icm-get_ai_summary` → often quotes the ARM ID
3. `icm-get_incident_details_by_id` → scan customFields, mitigateData, tags
4. `tsg_icm_page` → authored summary (most reliable source)
5. Ask the user (LAST RESORT)

**⚠️ Use the cluster resource group, NOT the node resource group (MC_...).**

#### 1c. Determine the Incident Time Range

Extract from `icm-get_incident_details_by_id`:
- `impactStartTime` / `mitigateTime` / `createdDate`
- Start with shorter `timeRange` (e.g. `"6h"`) and widen if needed
- If incident >30 days old, App Insights data may be expired

### Step 2: Run Triage Queries

**Use the `ama-logs-tsg` MCP server** which provides these tools:

| Tool | Description |
|------|-------------|
| `tsg_triage` | Initial triage: agent version, cluster scale (pod/node counts), high log scale mode, PODS_CHUNK_SIZE, controller counts, private cluster check, AKS alerts firing |
| `tsg_errors` | Scan error categories: exceptions, MDSD send/create errors, network upload failures, OMS Homing errors, AKS alerts for daemonset and replicaset |
| `tsg_workload` | Workload health: memory RSS, CPU usage (daemonset, replicaset, sidecar, Windows), container logs generated/sec, log size/sec, telegraf metrics, container counts |
| `tsg_pods` | Pod restarts and alert status for ama-logs daemonset and replicaset pods |
| `tsg_logs` | Raw trace logs from specific component (daemonset, replicaset, windows) |
| `tsg_config` | Agent configuration: configmap settings, excluded namespaces, container log table format, high log scale mode |
| `tsg_query` | Run arbitrary KQL against any data source (ContainerInsightsAppInsights, AKS, AKS CCP) |
| `tsg_auth_check` | Validate credentials and connectivity to all data sources |

All tools take `cluster` (ARM resource ID), `timeRange`, `interval`, `startTime`, `endTime`, and `outputFile` parameters.

**Key telemetry metrics in App Insights:**

| Metric (customMetrics.name) | Description |
|------------------------------|-------------|
| `memoryRssBytes` | Agent memory RSS per pod |
| `cpuUsageNanoCores` | Agent CPU per pod |
| `ContainerLogsGeneratedPerSec` | Records/sec per node (5min avg) |
| `ContainerLogsSize` | Bytes flushed/sec per node (5min avg) |
| `ContainerLogs2MdsdSendErrorCount` | Data send failures to MDSD |
| `ContainerLogsMdsdClientCreateErrorCount` | MDSD startup failures |
| `TelegrafMetricsSent` | Telegraf metrics volume |
| `PodCount` / `NodeCount` | Cluster scale |
| `EventCount` / `ServiceCount` | Cluster object counts |
| `ControllerCount` | Controller breakdown (RS, DS, SS, Job, CronJob, Deploy) |

**Key events (customEvents.name):**

| Event | Description |
|-------|-------------|
| `ContainerLogDaemonSetHeartbeatEvent` | Daemonset heartbeat with config (high log scale, excluded namespaces) |
| `KubePodInventoryHeartBeatEvent` | Replicaset heartbeat with PODS_CHUNK_SIZE |
| `ContainerInventoryHeartBeatEvent` | Container inventory with controller type counts |

**Key trace patterns (traces.message):**

| Pattern | Meaning |
|---------|---------|
| `"Failed to upload"` | Network errors sending data to backend |
| `"Failed to register certificate with OMS Homing service"` | OMS Homing registration failure |
| `"mem buf overlimit"` | Fluent-bit buffer overflow (high log volume) |

### Step 3: Identify Symptom Category and Follow TSG

Based on triage results, identify the primary symptom category:

| TSG Category | File |
|-------------|------|
| Agent OOM Kills | `tsgs/agent-oom-kills.md` |
| Missing Container Logs | `tsgs/missing-container-logs.md` |
| Missing Kube Data (Large Clusters) | `tsgs/missing-kube-data.md` |
| Liveness Probe Failures | `tsgs/liveness-probe-failures.md` |
| Ingestion Latency | `tsgs/ingestion-latency.md` |
| Onboarding / Private Link | `tsgs/onboarding-private-link.md` |
| Windows Agent Issues | `tsgs/windows-agent.md` |
| Agent Resource Usage | `tsgs/agent-resource-usage.md` |
| Vulnerabilities / CVEs | `tsgs/vulnerabilities.md` |
| Known Issues & FAQ | `tsgs/known-issues-faq.md` |

### Step 4: Summarize Findings

Present findings as:
1. **Cluster Info** — agent version, region, cluster scale
2. **Root Cause** — what the queries revealed, linked to TSG category
3. **Errors Found** — list of error categories with counts
4. **Resource Health** — memory/CPU/log volume status
5. **Configuration Issues** — misconfigurations detected
6. **Recommended Actions** — specific steps from the relevant TSG
7. **Escalation Path** — if issue requires another team
8. **Reference Documentation** — link to the relevant learn.microsoft.com page:
   - [Container Insights overview](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-overview)
   - [Troubleshooting](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-troubleshoot)

### Step 5: Improve the Tooling

After each investigation, if you wrote useful ad-hoc KQL queries via `tsg_query`, add them to the MCP server:
1. Add the query to `tools/ama-logs-tsg-mcp/src/queries.ts`
2. Wire it into the relevant tool in `tools/ama-logs-tsg-mcp/src/index.ts`
3. Rebuild: `cd tools/ama-logs-tsg-mcp && npx tsc`

## Escalation Contacts

| Issue/Area | ICM Service | ICM Team |
|------------|-------------|----------|
| AKS cluster / addon-token-adapter | Azure Kubernetes Service | RP |
| AMA Linux (MDSD, AMACA) | Azure Monitor Data Collection | AMA Linux |
| AMA Windows (MA) | Azure Monitor Data Collection | AMA Windows |
| DCR, DCE, DCR-A, AMPLS | Azure Monitor Control Service (AMCS) | Triage |
| Arc K8s MSI token adapter | Cluster Configuration | Cluster Configuration Triage |
| OMS Homing (legacy auth) | Azure Log Analytics | OMS Homing |
| Log Analytics query issues | Azure Log Analytics | Control Plane CRIs |
| Log Analytics ingestion | Azure Log Analytics | Ingestion |
| Log Analytics billing | Azure Log Analytics | Azure Monitor Billing |
| Azure Portal experience | Azure Portal IaaS Experiences | Triage |

## Quick Reference

| Symptom | MCP Tool | TSG Category |
|---------|----------|--------------|
| Missing container logs | `tsg_triage` + `tsg_errors` + `tsg_config` | Missing Container Logs |
| Agent OOMKilled | `tsg_errors` + `tsg_workload` | Agent OOM Kills |
| High memory / CPU | `tsg_workload` | Agent Resource Usage |
| Pod CrashLoopBackOff | `tsg_errors` + `tsg_pods` | Agent OOM Kills |
| Missing KubePodInventory | `tsg_triage` + `tsg_config` | Missing Kube Data |
| Liveness probe failures | `tsg_errors` + `tsg_logs` | Liveness Probe Failures |
| Data delay / latency | `tsg_triage` + `tsg_workload` | Ingestion Latency |
| Network upload errors | `tsg_errors` | Missing Container Logs / Liveness Probe |
| OMS Homing failures | `tsg_errors` | Known Issues |
| Private cluster issues | `tsg_triage` + `tsg_errors` | Onboarding / Private Link |
| Windows pod issues | `tsg_workload` + `tsg_errors` | Windows Agent |
| High log volume / mem buf overlimit | `tsg_workload` + `tsg_config` | Agent OOM Kills / Missing Logs |
| MDSD send errors | `tsg_errors` | Missing Container Logs |
| CVE reported | N/A | Vulnerabilities |

## Companion Files

| File | Contents |
|------|----------|
| `tsgs/` | 10 individual TSG files — one per symptom category |
| `reference.md` | Data sources, query patterns, telemetry reference |
