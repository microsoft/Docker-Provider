# Agent Resource Usage

## Symptom
ama-logs pods consuming excessive memory or CPU, but not necessarily OOMKilled.

## Diagnostic Steps

### 1. Check resource metrics
Run `tsg_workload` — provides memory and CPU for all component types:
- Linux daemonset (main + prometheus sidecar)
- Linux replicaset
- Windows daemonset

### 2. Identify contributing factors
- **High memory** on daemonset → usually log volume related
  - Check "Container Logs Generated Per Sec" and "Container Log Size Per Sec"
- **High memory** on replicaset → cluster scale related
  - Check "Pod Count", "Controller Counts" in `tsg_triage`
- **High CPU** → typically processing backlog or high event rate

### 3. Check configuration
Run `tsg_config` → check if high log scale mode is enabled (recommended for high-volume clusters).

## Resource Limit Guidelines

| Component | Default Memory | Default CPU | Scale Indicator |
|-----------|---------------|-------------|-----------------|
| ama-logs (DS) | 750Mi | 150m | Container logs/sec |
| ama-logs-rs | 1750Mi | 1000m | Pod/node/event count |
| ama-logs-windows | 600Mi | 200m | Windows container logs |

## Escalation
- **Resource limit increase guidance**: Container Insights / AzureManagedPrometheusAgent
