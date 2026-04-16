# Windows Agent Issues

## Symptom
ama-logs-windows pods have high CPU at startup, OOM kills, or missing Windows container logs.

## Diagnostic Steps

### 1. Check Windows pod health
Run `tsg_workload` → check:
- "CPU - Windows Daemonset" — Windows pods are known for high startup CPU
- "Memory RSS - Windows Daemonset" (uses `memoryWorkingSetBytes`)

### 2. Check for errors
Run `tsg_errors` → check "AKS Alerts - Daemonset" filtered to Windows pods.
Run `tsg_logs` (component: windows) → review trace messages.

### 3. Known behavior
- Windows ama-logs pods have a **high CPU spike at startup** — this is expected and typically settles within a few minutes
- Windows uses `memoryWorkingSetBytes` (not RSS) for memory tracking

## Common Fixes

| Cause | Fix |
|-------|-----|
| High startup CPU | Expected behavior — wait for stabilization |
| OOM kills | Increase Windows daemonset memory limits |
| Missing logs | Same troubleshooting as Linux — check MDSD, network, DCR |

## Escalation
- **Windows agent issues**: Azure Monitor Data Collection / AMA Windows
