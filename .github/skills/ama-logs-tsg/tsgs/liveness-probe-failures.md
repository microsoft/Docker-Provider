# Liveness Probe Failures

## Symptom
ama-logs pods fail liveness probes and get restarted by kubelet, with events showing "Liveness probe failed".

## Diagnostic Steps

### 1. Check which component is failing
Run `tsg_pods` → identify which pods have restart alerts.
Run `tsg_errors` → check "Exceptions" for probe-related errors.

### 2. Check for DCR/AMPLS issues
Run `tsg_triage` → check "Private Cluster Check".
- Private clusters need AMPLS (Azure Monitor Private Link Scope) configured
- Missing AMPLS causes configuration download failures → probe failures

### 3. Check for process termination
Run `tsg_logs` (component: daemonset) → look for:
- MDSD process crashes or termination
- Fluent-bit process crashes
- Configuration load failures

### 4. Check firewall endpoint access
If the agent can't reach required endpoints, it fails to initialize:
- `*.ods.opinsights.azure.com` — data ingestion
- `*.oms.opinsights.azure.com` — OMS homing
- `*.monitoring.azure.com` — AMCS (DCR/DCE)

## Common Causes

| Cause | Indicator | Fix |
|-------|-----------|-----|
| MDSD crash | MDSD process not running in probe check | Check MDSD logs, fix DCR config |
| Fluent-bit crash | Fluent-bit not running | Check for buffer overflow, reduce log volume |
| DCR not configured | Configuration download fails | Set up DCR/DCE properly |
| Private link missing | Private cluster without AMPLS | Configure AMPLS for the workspace |
| Firewall blocking | Network errors in traces | Add required endpoints to firewall |

## Escalation
- **DCR/DCE/AMPLS**: Azure Monitor Control Service (AMCS) / Triage
- **MDSD failures**: Azure Monitor Data Collection / AMA Linux
