# Missing Container Logs

## Symptom
Container logs (ContainerLog or ContainerLogV2) are not appearing in the Log Analytics workspace.

## Diagnostic Steps

### 1. Verify table format
Run `tsg_config` → check "Data Collection Table" to see if the cluster uses `ContainerLog` or `ContainerLogV2`.
- If querying the wrong table, data appears missing but is in the other table
- ContainerLogV2 is the default for new clusters

### 2. Check excluded namespaces
Run `tsg_config` → check "Agent ConfigMap Settings" for `excludedNamespaces`.
- The target namespace may be excluded from collection

### 3. Check for MDSD errors
Run `tsg_errors` → review:
- **MDSD Send Errors** — data send failures to backend
- **MDSD Client Create Errors** — MDSD startup failures (oneagent not initializing)

### 4. Check log volume and buffer overflow
Run `tsg_workload` → check:
- **Container Logs Generated Per Sec** — if >50K records/sec, may need high log scale mode
- **Container Log Size Per Sec** — bytes per second throughput

Look for `"mem buf overlimit"` in `tsg_logs` → daemonset traces. This indicates fluent-bit buffer overflow.

### 5. Check network connectivity
Run `tsg_errors` → check "Network Upload Errors (Daemonset)".
- If present, the agent cannot upload to the backend
- Check firewall rules for required endpoints

### 6. Check agent pod health
Run `tsg_pods` → verify ama-logs pods are running and not CrashLooping.
Run `tsg_triage` → check "AKS Alerts Firing" for any active alerts.

## Common Fixes

| Cause | Fix |
|-------|-----|
| Wrong table queried | Query `ContainerLogV2` instead of `ContainerLog` (or vice versa) |
| Namespace excluded | Remove namespace from exclusion list in configmap |
| Buffer overflow | Enable high log scale mode |
| Network blocked | Add required endpoints to firewall allowlist |
| MDSD not starting | Check DCR/DCE configuration, verify AMPLS for private clusters |
| Agent pods not running | Check pod status, review events for scheduling failures |

## Escalation
- **MDSD issues**: Azure Monitor Data Collection / AMA Linux
- **Log Analytics ingestion**: Azure Log Analytics / Ingestion
