# Known Issues & FAQ

## Known Issues

### 1. High CPU at Windows pod startup
**Behavior:** Windows ama-logs pods show CPU spikes (sometimes >1 core) immediately after starting.
**Root cause:** Initialization processing, including log history scan.
**Status:** Expected behavior — CPU settles within a few minutes.

### 2. ContainerLog vs ContainerLogV2 confusion
**Behavior:** Customers query `ContainerLog` but data is in `ContainerLogV2` (or vice versa).
**Root cause:** New clusters default to ContainerLogV2; older clusters may use ContainerLog.
**Check:** Run `tsg_config` → "Data Collection Table" to see which table is configured.

### 3. Kube data gaps on large clusters
**Behavior:** KubePodInventory has periodic gaps (missing time ranges).
**Root cause:** Default PODS_CHUNK_SIZE (1000) causes large API payloads that timeout.
**Fix:** Reduce PODS_CHUNK_SIZE to 500 or 250 via configmap.

### 4. OMS Homing registration failures (legacy)
**Behavior:** Traces show "Failed to register certificate with OMS Homing service".
**Root cause:** Legacy authentication mechanism — may indicate network connectivity issues to `*.oms.opinsights.azure.com`.
**Fix:** Ensure endpoint is accessible; consider migration to AMA if using legacy omsagent.

### 5. Prometheus sidecar memory
**Behavior:** The prometheus sidecar container in ama-logs pods uses significant memory.
**Root cause:** Custom prometheus scraping configured via configmap.
**Fix:** Reduce scrape targets or switch to dedicated ama-metrics addon.

## FAQ

### Q: How do I check if Container Insights is enabled?
Check for ama-logs pods in kube-system namespace:
```
kubectl get pods -n kube-system | grep ama-logs
```

### Q: What endpoints does the agent need access to?
- `*.ods.opinsights.azure.com` — ODS data ingestion
- `*.oms.opinsights.azure.com` — OMS homing and onboarding
- `*.monitoring.azure.com` — AMCS for DCR/DCE configuration
- `login.microsoftonline.com` — AAD authentication
- `mcr.microsoft.com` — Container image pull

### Q: How do I switch from ContainerLog to ContainerLogV2?
Configure via DCR or the agent configmap. See [Microsoft docs](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-logging-v2).

### Q: How do I exclude namespaces from log collection?
Set `log_collection_settings.namespace_filtering.namespaces` in the agent configmap. See [Microsoft docs](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-data-collection-filter).
