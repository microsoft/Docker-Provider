# Agent OOM Kills

## Symptom
ama-logs pods (daemonset or replicaset) are being OOMKilled, causing CrashLoopBackOff.

## Diagnostic Steps

### 1. Identify which pod type is OOMing
Run `tsg_errors` → check "AKS Alerts - Daemonset" and "AKS Alerts - Replicaset" for OOMKilled status.

### 2. Check memory usage trends
Run `tsg_workload` → review "Memory RSS" queries for the affected component:
- **Daemonset OOM**: Check "Memory RSS - Linux Daemonset" and "Container Logs Generated Per Sec"
- **Replicaset OOM**: Check "Memory RSS - Replicaset" and cluster scale metrics

### 3. Diagnose root cause by component

#### Daemonset OOM
Common causes:
- **High container log volume** — nodes producing >30MB/min of logs
  - Check `ContainerLogsGeneratedPerSec` and `ContainerLogsSize` metrics
  - Look for "mem buf overlimit" in fluent-bit logs
  - **Fix**: Enable high log scale mode via configmap, or exclude noisy namespaces
- **Network errors** — MDSD unable to upload data, causing buffer buildup
  - Check `tsg_errors` → "Network Upload Errors (Daemonset)"
  - Check for firewall blocking required endpoints
  - **Fix**: Ensure required endpoints are accessible (see firewall requirements)
- **Disk I/O throttling** — Ephemeral OS disk saturated
  - Affects nodes with heavy I/O workloads
  - **Fix**: Use managed disks or increase node SKU

#### Replicaset OOM
Common causes:
- **Large cluster scale** — too many pods/services/events for default memory limit
  - Check `PodCount`, `EventCount`, `ServiceCount` in `tsg_triage`
  - Check `PODS_CHUNK_SIZE` — if not set, default is 1000
  - **Fix**: Reduce PODS_CHUNK_SIZE (e.g. to 500 or 250) via configmap
- **Prometheus sidecar load** — excessive prometheus scraping
  - Check "Memory RSS - Linux Daemonset Sidecar" in `tsg_workload`
  - **Fix**: Reduce scrape targets or increase memory limits

### 4. Configuration tuning

**Enable high log scale mode:**
```yaml
# container-azm-ms-agentsettings configmap
[agent_settings.log_collection_settings]
  [agent_settings.log_collection_settings.high_log_scale]
    enabled = true
```

**Tune PODS_CHUNK_SIZE for large clusters:**
```yaml
# container-azm-ms-agentsettings configmap
[agent_settings]
  PODS_CHUNK_SIZE = "500"
```

## Escalation
- **MDSD issues**: Azure Monitor Data Collection / AMA Linux
- **Network issues related to AKS**: Azure Kubernetes Service / RP
