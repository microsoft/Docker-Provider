# Ingestion Latency

## Symptom
Data in Container Insights tables (ContainerLog, KubePodInventory, etc.) is delayed — TimeGenerated is minutes or hours behind real time.

## Diagnostic Steps

### 1. Identify latency source
Latency has two components:
- **Agent latency** — time from event generation to data reaching the ingestion endpoint (`TimeGenerated` → `_TimeReceived`)
- **Ingestion pipeline latency** — time from endpoint receipt to query availability (`_TimeReceived` → `ingestion_time()`)

### 2. Measure agent latency
Use `tsg_query` with this KQL against the customer's Log Analytics workspace (not App Insights):
```kql
union withsource = tt *
| where _ResourceId =~ "<cluster_arm_id>"
| where tt == "KubePodInventory"
| extend AgentLatencySecs = todouble(datetime_diff("Second", _TimeReceived, TimeGenerated))
| summarize p95 = percentiles(AgentLatencySecs, 95) by bin(TimeGenerated, 1m), tt
```

### 3. Measure ingestion pipeline latency
```kql
union withsource = tt *
| where _ResourceId =~ "<cluster_arm_id>"
| where tt == "KubePodInventory"
| extend IngestionLatencySecs = todouble(datetime_diff("Second", ingestion_time(), _TimeReceived))
| summarize p95 = percentiles(IngestionLatencySecs, 95) by bin(TimeGenerated, 1m), tt
```

### 4. Check agent health
Run `tsg_workload` → high memory or CPU may indicate the agent is overwhelmed and buffering data.
Run `tsg_errors` → network upload errors cause data buffering and delayed delivery.

## Common Fixes

| Cause | Fix |
|-------|-----|
| High agent latency (>5min) | Check agent resource usage, network errors, log volume |
| High ingestion latency | Escalate to Log Analytics Ingestion team |
| DCR collection interval | Check DCR for custom collection intervals (default is 1 minute) |
| Log Analytics throttling | Check workspace data cap in AIMC |

## Escalation
- **Ingestion pipeline latency**: Azure Log Analytics / Ingestion
- **Agent latency**: Azure Monitor Data Collection / AMA Linux
