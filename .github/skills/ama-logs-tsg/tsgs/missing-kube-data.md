# Missing Kube Data (Large Clusters)

## Symptom
KubePodInventory, KubeNodeInventory, KubeEvents, or KubeServices tables have gaps or missing data, especially on large clusters (>1000 pods).

## Diagnostic Steps

### 1. Check cluster scale
Run `tsg_triage` → review "Pod Count" and "Node Count".
- Large clusters (>5000 pods) are prone to Kube* data gaps

### 2. Check PODS_CHUNK_SIZE
Run `tsg_triage` → check "PODS_CHUNK_SIZE".
- Default is 1000; large clusters may need a smaller value (500 or 250)
- Smaller chunks reduce API payload size and prevent parsing failures

### 3. Check replicaset health
Run `tsg_workload` → check "Memory RSS - Replicaset".
- If replicaset is OOMing, Kube* data collection stops
- Also check "Controller Counts" for cluster object complexity

### 4. Check for parsing errors
Run `tsg_logs` (component: replicaset) → look for error messages about payload parsing or API failures.

## Common Fixes

| Cause | Fix |
|-------|-----|
| Default PODS_CHUNK_SIZE too large | Set `PODS_CHUNK_SIZE = "500"` or `"250"` in configmap |
| Replicaset OOMing | Increase replicaset memory limits |
| API server throttling | Check AKS API server metrics for 429s |

## Escalation
- **AKS API issues**: Azure Kubernetes Service / RP
