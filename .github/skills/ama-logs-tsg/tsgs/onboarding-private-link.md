# Onboarding / Private Link

## Symptom
Container Insights not working after onboarding, or data not flowing on private clusters.

## Diagnostic Steps

### 1. Check if cluster is private
Run `tsg_triage` → check "Private Cluster Check" (from ManagedClusterSnapshot).

### 2. For private clusters — verify AMPLS
Private clusters require Azure Monitor Private Link Scope (AMPLS):
- The Log Analytics workspace must be linked to an AMPLS
- Public Network Access for both query and ingestion must be configured
- DCE (Data Collection Endpoint) must be set up for private ingestion

### 3. Check agent pod status
Run `tsg_pods` → verify ama-logs pods are running.
- If pods aren't created, check addon enablement
- If pods are CrashLooping, check `tsg_errors` for root cause

### 4. Check for OMS Homing errors
Run `tsg_errors` → check "OMS Homing Errors" — legacy clusters may have certificate registration issues.

### 5. Check for configuration errors
Run `tsg_logs` → look for configuration download failures or DCR errors.

## Common Fixes

| Scenario | Fix |
|----------|-----|
| Private cluster, no AMPLS | Set up AMPLS and link workspace |
| Private cluster, public ingestion blocked | Enable Public Network Access for ingestion |
| Missing DCE for private cluster | Create DCE in same region as cluster |
| Legacy image reference | Update to `mcr.microsoft.com/azuremonitor/containerinsights/ciprod` |
| Agent pods not created | Re-enable Container Insights addon |
| OMS Homing failures | Check network connectivity to `*.oms.opinsights.azure.com` |

## Escalation
- **DCR/DCE/AMPLS**: Azure Monitor Control Service (AMCS) / Triage
- **Portal experience**: Azure Portal IaaS Experiences / Triage
