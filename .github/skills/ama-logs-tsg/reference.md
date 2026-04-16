# Reference Guide — ama-logs-tsg MCP Server

## Data Sources

| Name | Type | Description |
|------|------|-------------|
| `ContainerInsightsAppInsights` | App Insights | Agent telemetry: customMetrics, customEvents, traces, exceptions |
| `AKS` | Kusto | AKS cluster state, pod alerts, node status |
| `AKS CCP` | Kusto | AKS control plane configuration and snapshots |

### App Insights Resource
- **Name:** ContainerInsightsAgent-Prod
- **Subscription:** 13d371f9-5a39-46d5-8e1b-60158c49db84
- **Resource Group:** ContainerInsightsAgent-Prod

### App Insights Tables

| Table | Key Fields | Use |
|-------|-----------|-----|
| `customMetrics` | `name`, `value`, `customDimensions.ID` (cluster ARM ID), `customDimensions.Pod`, `customDimensions.AKS_RESOURCE_ID` | Agent resource usage, log volume metrics, cluster scale |
| `customEvents` | `name`, `customDimensions.ID`, `customDimensions.*` | Agent heartbeats, configuration state |
| `traces` | `message`, `customDimensions.ID`, `cloud_RoleInstance` | Agent logs, error messages |
| `exceptions` | `type`, `outerMessage`, `customDimensions.ID` | Agent exceptions |

### Cluster ID Filtering

Queries filter by cluster using the ARM resource ID in two patterns:
- `customDimensions.ID` — used in customEvents and traces
- `customDimensions.AKS_RESOURCE_ID` — used in some customMetrics

### Pod Name Patterns

| Pattern | Component |
|---------|-----------|
| `ama-logs-*` (not rs, not windows) | Linux daemonset |
| `ama-logs-rs-*` | Linux replicaset |
| `ama-logs-windows-*` | Windows daemonset |

Legacy pod names (pre-AMA migration):
- `omsagent-*` → Linux daemonset
- `omsagent-rs-*` → Linux replicaset
- `omsagent-win-*` → Windows daemonset

## Using tsg_query for Ad-Hoc Investigation

The `tsg_query` tool runs arbitrary KQL against any configured data source.

### Parameters
- `datasource` — One of: `ContainerInsightsAppInsights`, `AKS`, `AKS CCP`
- `kql` — The KQL query string
- `cluster` — Optional ARM resource ID (replaces `_cluster` in KQL)
- `timeRange` — Optional time range (default: "24h")
- `maxRows` — Max inline rows (default: 100)
- `outputFile` — Write full results to file (JSON or CSV)
- `outputFormat` — `csv` or `json` (default: csv)

### Common Query Patterns

**Check specific metric values:**
```kql
customMetrics
| where timestamp > ago(24h)
| where name == "memoryRssBytes"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| extend Pod = tostring(customDimensions.Pod)
| extend UsageInMB = value/1024/1024
| summarize max_MB = max(UsageInMB), avg_MB = avg(UsageInMB) by Pod
| order by max_MB desc
```

**Search for specific error messages:**
```kql
traces
| where timestamp > ago(24h)
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| where message contains "error" or message contains "fail"
| summarize count() by message = substring(message, 0, 200)
| order by count_ desc
| take 20
```

**Check exception types:**
```kql
exceptions
| where timestamp > ago(24h)
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize count() by type, outerMessage
| order by count_ desc
```

**Check agent heartbeat frequency:**
```kql
customEvents
| where timestamp > ago(24h)
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize count() by name, bin(timestamp, 1h)
| order by timestamp desc
```

## Agent Architecture

### Linux Daemonset (ama-logs)
- Runs on every Linux node
- Collects: container logs (stdout/stderr), container inventory
- Components: fluent-bit (log collection), MDSD (data upload)
- Config: agent-settings configmap for buffer tuning, namespace exclusion

### Linux Replicaset (ama-logs-rs)
- Single replica per cluster
- Collects: KubePodInventory, KubeNodeInventory, KubeEvents, KubeServices, cluster metrics
- Controlled by PODS_CHUNK_SIZE for large clusters

### Windows Daemonset (ama-logs-windows)
- Runs on every Windows node
- Collects: Windows container logs
- Uses: fluent-bit + MDSD (same pipeline as Linux)

### Key Configuration Options
- **High Log Scale Mode** — Optimizes for clusters with >50K records/sec log volume
- **PODS_CHUNK_SIZE** — Controls batch size for KubePodInventory (default: 1000, reduce for large clusters)
- **Excluded Namespaces** — Namespaces to skip for log collection
- **ContainerLogV2** — New table format (vs legacy ContainerLog)

## Telemetry Sources for Manual Investigation

| Source | URL | Use |
|--------|-----|-----|
| Container Agent Telemetry | Azure Portal → App Insights → ContainerInsightsAgent-Prod | customMetrics, customEvents, exceptions, traces |
| AIMC | http://aka.ms/aimc | Workspace info, billing tier, ingest limits |
| Jarvis | https://jarvis-west.dc.ad.msft.net | ODS ingestion logs, quota, latency |
| Azure Service Insights | https://azureserviceinsights.trafficmanager.net | Cluster info, pods, nodes |
