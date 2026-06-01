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

#### 1d. Analyze DTM/Support Attachments

If a **DTM link** is provided (e.g. `https://client.dtmnebula.microsoft.com/Home?srNumber=...`):

1. **Navigate** to the DTM page using Playwright browser
2. **Download all diagnostic files** — click each file button to download. Key files to prioritize:
   - `describe_ama-logs-*.txt` — pod descriptions with termination reasons, restart counts, memory limits
   - `logs_ama-logs-*.txt` — startup logs showing how far the agent got before crashing
   - `container-azm-ms-agentconfig*.yaml` — agent configuration
   - `container-azm-ms-aks-k8scluster*.yaml` — cluster ARM resource ID
   - `deployment_ama-logs-rs*.txt` — deployment spec with revision history
   - `node*.txt` / `node-detailed*.json` — node info, VM size, memory, conditions
   - `containerID_ama-logs-*.txt` — container IDs
   - `Tool*.log` — tool execution log
3. **Compare multiple snapshots** — if files appear twice (e.g. `foo.txt` and `foo[1].txt`), they are from different collection times. Compare to track changes over time.
4. **Ignore image files** (`img-*`) — these are typically email signature icons, not diagnostic screenshots

**Key things to extract from attachments:**
- `Reason:` and `Exit Code:` from pod descriptions — `Error` with exit 137 may be OOM (see containerd cgroup v2 bug in `tsgs/agent-oom-kills.md`)
- `Restart Count:` — how long the crash has persisted
- `USING_AAD_MSI_AUTH` from startup logs — determines if DCR is needed
- `*** setting up oneagent in legacy auth mode ***` vs `*** setting up oneagent in aad auth msi mode ***` — auth mode
- `Onboarding success` — means MDSD initialized successfully; crash happens after
- `Image:` line — agent version (e.g. `ciprod:3.1.35`)
- VM size from node-detailed.json — memory capacity
- Node conditions — MemoryPressure, DiskPressure

#### 1e. Check DCR/DCRA via ARM Logs

If the agent is in **AAD MSI auth mode**, verify the DCR exists using the `prom-collector-tsg` MCP server (which has ARM data sources):
```
tsg_query datasource=ARMPRODWEU kql='HttpIncomingRequests | where PreciseTimeStamp > ago(30d) | where subscriptionId == "<sub-id>" | where targetUri has "MSCI" or targetUri has "ContainerInsightsExtension" or targetUri has "dataCollectionRule" | extend fullPath = extract("/subscriptions/[^?]+", 0, targetUri) | project PreciseTimeStamp, httpMethod, httpStatusCode, fullPath | order by PreciseTimeStamp desc'
```

Look for:
- **PUT 200** on `dataCollectionRules/MSCI-{region}-{cluster}` — DCR creation
- **PUT 200** on `dataCollectionRuleAssociations/ContainerInsightsExtension` — DCRA creation
- **GET 200** — ongoing reads (healthy)
- **GET 400/404** — DCR/DCRA missing or broken

⚠️ Search for `MSCI` or `ContainerInsightsExtension` in the URI, NOT `dataCollection` — the resource name appears before the type in the truncated URI.

#### 1f. Check Addon Enable/Disable History

Run `tsg_triage` → "Addon Enable/Disable History" to detect if the customer disabled and re-enabled the addon. This is important because:
- Re-enabling switches from legacy auth to AAD MSI auth (new default)
- DCR/DCE/DCRA must be deployed separately (AKS RP does not create them)
- The agent version upgrades to latest on re-enable

### Step 2: Run Triage Queries

**Use the `ama-logs-tsg` MCP server** which provides these tools:

| Tool | Description |
|------|-------------|
| `tsg_triage` | Initial triage: agent version, cluster scale (pod/node counts), high log scale mode, PODS_CHUNK_SIZE, controller counts, private cluster check, AKS alerts firing, addon enable/disable history, cluster node info |
| `tsg_errors` | Scan error categories: exceptions, MDSD send/create errors, network upload failures, OMS Homing errors, AKS alerts for daemonset and replicaset |
| `tsg_workload` | Workload health: memory RSS, CPU usage (daemonset, replicaset, sidecar, Windows), container logs generated/sec, log size/sec, telegraf metrics, container counts, node PSI pressure (CPU/Memory/IO), node cgroup memory usage |
| `tsg_pods` | Pod restarts, alert status, container termination reasons from kube-audit (distinguishes OOMKilled vs Error), kill reason breakdown, non-routine events from AKSKubeEvents |
| `tsg_logs` | Raw trace logs from specific component (daemonset, replicaset, windows) |
| `tsg_config` | Agent configuration: configmap settings, excluded namespaces, container log table format, high log scale mode |
| `tsg_query` | Run arbitrary KQL against any data source (ContainerInsightsAppInsights, AKS, AKS CCP, Azcore, AzcrpBI, Azcrp, AKS SwedenCentral) |
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

**Agent startup sequence** (`kubernetes/linux/main.sh`):

When analyzing crash timing, the startup sequence is:
```
1. Config processing (env vars, configmap parsing)        ~2s
2. mdsd started in background                              ~3s
3. checkAgentOnboardingStatus (polls mdsd.info for up to 30s)
   - Legacy auth: waits for "Onboarding success"
   - AAD MSI auth: waits for "Loaded data sources"
4. "Onboarding success" printed
5. ruby dcr-config-parser.rb                               ~1s
6. fluentd started in background                           ~2s
7. telegraf test run                                       ~2s
8. fluent-bit started in background                        ~1s
9. telegraf started in background                          ~1s
10. "startup script end" printed
11. sleep inf & wait (blocks forever)
```

If the container crashes **before step 10**, check which step it reached:
- Crash before "Onboarding success" → MDSD can't initialize (auth/connectivity issue)
- Crash right after "Onboarding success" → MDSD memory spike during dcr-config-parser
- Crash after fluentd/fluent-bit start → combined process memory exceeds limit
- `ruby dcr-config-parser.rb` "Killed" in logs → bash reporting SIGKILL on a child process (OOM killed the cgroup)

### Step 2b: Search for Similar ICMs

Use `icm-search_incidents_by_owning_team_id` (requires ICM MCP) to find similar incidents:
- Team ID `98097` = AzureManagedPrometheusAgent
- Search titles for: `OOM`, `crash`, `CrashLoop`, `memory`, `137`, `ama-logs`

If ICM MCP is not available, check fleet-wide crash rates via AKS CCP:
```kql
KubeSystemEvents | where TIMESTAMP > ago(7d) | where name startswith "ama-logs" | where reason == "BackOff"
| summarize BackOffs=count(), Pods=dcount(name) by resourceId
| where BackOffs > 5000
| summarize ClustersAffected=count(), TotalBackOffs=sum(BackOffs)
```

### Step 2c: Investigate Node-Level VM Health

When exit code 137 crashes appear to NOT be cgroup OOM (agent memory is low at crash time), investigate whether the node VM itself is under memory pressure.

**Step 1: Check agent memory at crash time.** Query `memoryRssBytes` from App Insights. If the agent is using <100 MB of a 1536 Mi limit, cgroup OOM is ruled out.

**Step 2: Map node names → VM IDs.** Use `tsg_query` with `AzcrpBI` datasource:
```kql
VMScaleSetVMInstance
| where PreciseTimeStamp > ago(7d)
| where SubscriptionId =~ '<subscription-id>'
| where ResourceGroupName =~ 'MC_<rg>_<cluster>_<region>'
| where VMScaleSetName has '<nodepool-name>'
| extend instance = tolower(strcat(VMScaleSetName, '_', InstanceIdString))
| summarize arg_max(PreciseTimeStamp, VMScaleSetVMInstanceId) by instance
| project instance, vm_id = VMScaleSetVMInstanceId
```

**Step 3: Query VM health metrics.** Use `tsg_query` with `Azcore` datasource to compare CPU/memory pressure between crashing and healthy nodes. See `reference.md` → "Node-Level VM Health Investigation" for full query.

**Step 4: Interpret results.**
- If crashing nodes have **higher** VM memory pressure → host-level OOM killer is the likely cause
- If crashing nodes have **lower or equal** pressure → the crash is NOT caused by VM resources; investigate addon reconciliation, deployment spec changes, or node-specific state corruption

**Step 5: Check for addon reconciliation.** Run `tsg_triage` → "Mutating Operations" to find operations that coincide with the crash start time. Look for PutManagedCluster, ReconcileAddon, or UpgradeNodeImageAgentPoolHandler operations.

⚠️ **AKS region routing:** Westeurope clusters use `AKS SwedenCentral` datasource for AgentPoolSnapshot and ManagedClusterSnapshot. The default `AKS` datasource (`akshuba.centralus`) may return empty results for these tables.

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
| Agent OOMKilled | `tsg_pods` + `tsg_workload` | Agent OOM Kills |
| Exit code 137 / Reason: Error | `tsg_pods` (check "Container Termination Reason") | Agent OOM Kills (containerd cgroup v2 bug) |
| Exit 137 but low memory | `tsg_workload` + `tsg_query` (Azcore/AzcrpBI) | Agent OOM Kills → "Ruling Out OOM" |
| Liveness probe killing container | `tsg_query` (AKS CCP: KubeSystemEvents Killing+Unhealthy) | Agent OOM Kills → "Liveness Probe Killing Container" |
| All pods crash after addon reconciliation | `tsg_triage` (check "Mutating Operations") | Agent OOM Kills → "Addon Reconciliation" |
| High memory / CPU | `tsg_workload` | Agent Resource Usage |
| Pod CrashLoopBackOff | `tsg_pods` + `tsg_errors` | Agent OOM Kills |
| Addon disabled/re-enabled | `tsg_triage` (check "Addon Enable/Disable History") | Agent OOM Kills / Onboarding |
| Missing KubePodInventory | `tsg_triage` + `tsg_config` | Missing Kube Data |
| Liveness probe failures | `tsg_errors` + `tsg_logs` | Liveness Probe Failures |
| Data delay / latency | `tsg_triage` + `tsg_workload` | Ingestion Latency |
| Network upload errors | `tsg_errors` | Missing Container Logs / Liveness Probe |
| OMS Homing failures | `tsg_errors` | Known Issues |
| Private cluster issues | `tsg_triage` + `tsg_errors` | Onboarding / Private Link |
| Windows pod issues | `tsg_workload` + `tsg_errors` | Windows Agent |
| High log volume / mem buf overlimit | `tsg_workload` + `tsg_config` | Agent OOM Kills / Missing Logs |
| MDSD send errors | `tsg_errors` | Missing Container Logs |
| Node resource pressure (PSI) | `tsg_workload` (PSI Pressure query) or `tsg_query` (AKS GuestAgent) | Agent Resource Usage |
| Node cgroup memory usage | `tsg_workload` (CGroup Memory query) or `tsg_query` (AKS GuestAgent) | Agent Resource Usage |
| CVE reported | N/A | Vulnerabilities |

## Companion Files

| File | Contents |
|------|----------|
| `tsgs/` | 10 individual TSG files — one per symptom category |
| `reference.md` | Data sources, query patterns, telemetry reference |
