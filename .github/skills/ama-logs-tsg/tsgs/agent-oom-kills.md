# Agent OOM Kills

## Symptom
ama-logs pods (daemonset or replicaset) are being OOMKilled, causing CrashLoopBackOff.

## Important: containerd cgroup v2 OOM Reporting Bug

On AKS clusters running **containerd 1.7.x** with **Ubuntu 22.04 (cgroup v2)**, the kernel OOM killer may terminate containers but containerd reports `Reason: Error` instead of `Reason: OOMKilled`. See [containerd#9321](https://github.com/containerd/containerd/issues/9321).

**How to identify OOM when it shows as `Reason: Error`:**
- Exit code is **137** (128 + SIGKILL)
- No `Killing` events in KubeSystemEvents for the pod (rules out liveness probe)
- Liveness probe `initialDelaySeconds` (60s) hasn't elapsed yet (container crashes in <60s)
- `kubectl describe pod` shows `Reason: Error, Exit Code: 137` (NOT `Reason: OOMKilled`)
- Run `tsg_pods` → check "Container Termination Reason (Kube-Audit)" which extracts the actual termination status from kube-audit patches
- Run `tsg_pods` → check "Kill Reason Breakdown" — if no `Killing` events but many `BackOff` events, it's likely OOM

**Definitive confirmation** requires `dmesg | grep -i oom` from the node — ask the customer to run:
```bash
# Use azurelinux:3.0 (NOT cbl-mariner). nsenter is NOT available — use chroot instead.
kubectl debug node/<node-name> -it --image=mcr.microsoft.com/azurelinux/base/core:3.0 -- chroot /host bash -c 'dmesg | grep -i oom'
```

⚠️ `systemd-oomd` is NOT installed on AKS nodes — only the kernel cgroup OOM killer operates.

### Ruling Out OOM (Exit 137 + Error ≠ Always OOM)

Exit code 137 means SIGKILL, which can come from:
1. **Cgroup OOM killer** — kernel kills the container for exceeding memory limits
2. **Node-level OOM killer** — kernel kills processes when the node is under memory pressure
3. **Kubelet eviction** — kubelet evicts pods when node resources are low
4. **Liveness probe failure** — kubelet kills container because liveness probe returned non-zero
5. **External SIGKILL** — addon reconciliation, node image upgrade, or other controller kills the pod

**⚠️ Liveness probe kills look identical to OOM kills** — both show `Exit Code: 137, Reason: Error`. Check KubeSystemEvents for `"Container ama-logs failed liveness probe, will be restarted"` Killing events to distinguish them.

**To rule out cgroup OOM, check actual memory usage at crash time:**
```kql
-- datasource: ContainerInsightsAppInsights
customMetrics
| where timestamp > ago(7d)
| where name == "memoryRssBytes"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| extend Pod = tostring(customDimensions.Pod)
| extend UsageMB = round(value / 1024 / 1024, 1)
| summarize MaxMB=max(UsageMB), AvgMB=round(avg(UsageMB),1) by Pod, bin(timestamp, 1h)
| order by timestamp desc
```

If the agent is only using 8-20 MB of a 1536 Mi limit, it is definitively NOT a cgroup OOM. Investigate other causes:
- **Addon reconciliation** — check `tsg_triage` → "Mutating Operations" for addon operations around the crash start time
- **Node image upgrade** — check for `UpgradeNodeImageAgentPoolHandler` operations
- **Node-level memory pressure** — see "Node-Level VM Health Investigation" in `reference.md`

### Addon Reconciliation as Crash Trigger

The AKS addon reconciler periodically redeploys ama-logs pods. If the new deployment spec has an issue (e.g. bad configmap, changed resource limits, incompatible image), ALL pods will crash simultaneously after reconciliation.

**Pattern to look for:**
1. All DS pods killed at the same timestamp (e.g. `Killing` events at 14:33:20-14:33:28)
2. New pods created immediately after, all with BackOff starting at the same time
3. Some pods may recover after a subsequent node image upgrade (which reimages the node and gets fresh state)

**Diagnostic:** Run `tsg_triage` → "Mutating Operations" and look for operations around the crash start time. Key operation names:
- `PutManagedCluster` — full cluster update (may include addon changes)
- `ReconcileAddon` — addon-specific reconciliation
- `UpgradeNodeImageAgentPoolHandler` — node image upgrade (may fix or trigger issues)

**Detecting spec changes:** When the addon reconciler changes the deployment spec, the RS deployment hash changes (e.g. `ama-logs-rs-556cfbbc67` → `ama-logs-rs-555c8f87fd`). Check KubeSystemEvents for `ScalingReplicaSet` events:
```kql
KubeSystemEvents | where cluster_id == '<ccp-id>' | where name has 'ama-logs-rs'
| where reason == 'ScalingReplicaSet' | project PreciseTimeStamp, name, message
```
A hash change means the pod spec changed — commonly the `addon-token-adapter` sidecar image was updated. Check the `Pulling` events to see what new images were pulled.

**Partial recovery after node image upgrade:** If some DS pods recover after a node image upgrade while others don't (on different nodes), and VM health shows no correlation, the issue may be:
- A race condition in pod startup
- Node-specific cached state (stale image layers, corrupted volumes)
- Timing-dependent configmap or secret propagation

### Liveness Probe Killing Container (Exit 137, NOT OOM)

When MDSD fails to complete initialization, the liveness probe (`/opt/livenessprobe.sh`) detects missing processes and kills the container. This produces `Exit Code: 137, Reason: Error` — identical to OOM.

**The liveness probe checks (in order):**
1. `dcr-config-parser.rb` — re-parses DCR config; exits 1 if config changed
2. `inotifyoutput.txt` — exits 1 if configmap was modified (ArgoCD watch out!)
3. `ps -ef | grep mdsd` — exits 1 if MDSD not running
4. `ps -ef | grep fluent-bit` — exits 1 if fluent-bit not running
5. `ps -ef | grep fluentd` — exits 1 if fluentd not running (unless LOGS_AND_EVENTS_ONLY)
6. `ps -ef | grep telegraf` — conditional check

**Diagnosis: Liveness probe kill vs OOM:**

| Evidence | Liveness Probe Kill | Cgroup OOM |
|----------|-------------------|------------|
| KubeSystemEvents `Killing` reason | `"failed liveness probe"` | No `Killing` event |
| Memory at crash time | Low (8-20 MB) | Near container limit |
| `Unhealthy` events before kill | Yes | No |
| Container runs >60s before crash | Yes (probe `initialDelaySeconds: 60`) | Often crashes <30s |
| Termination message | `"mdsd is not running"` or `"Fluentbit is not running"` | None |

**Check for liveness probe kills:**
```kql
-- datasource: AKS CCP
KubeSystemEvents
| where PreciseTimeStamp > ago(3d)
| where resourceId =~ _cluster
| where name startswith "ama-logs"
| where reason in ("Killing", "Unhealthy")
| where message has "liveness probe"
| project PreciseTimeStamp, name, reason, message=substring(message,0,200)
| order by PreciseTimeStamp desc
```

**Root cause: MDSD fails to initialize → liveness probe catches it:**
1. Container starts → main.sh runs → MDSD starts (`"START mdsd"` logged)
2. MDSD tries to authenticate via addon-token-adapter
3. If token not available within 30s → MDSD never reaches "Onboarding success"
4. Without MDSD, fluentd/fluent-bit/telegraf never start
5. Container stays at 8-18 MB (processes never fully initialize)
6. After 60s, liveness probe finds missing processes → exits 1
7. Kubelet sends SIGKILL → exit code 137, Reason: Error

**Why non-deterministic (some pods healthy, some crash on same spec):**
The race between addon-token-adapter readiness and MDSD's auth timeout. The addon-token-adapter sidecar starts concurrently with ama-logs. If the token adapter takes too long to initialize, MDSD times out. This race is timing-dependent — a single pod restart may fix it.

**Recommended actions:**
1. Ask CSS to restart crashing pods one at a time: `kubectl delete pod <pod> -n kube-system`
2. If restart fixes it → confirms race condition. No code fix needed.
3. If restart doesn't fix it → check addon-token-adapter logs: `kubectl logs <pod> -n kube-system -c addon-token-adapter`
4. Check MDSD startup: `kubectl logs <pod> -n kube-system -c ama-logs | head -50`
5. Check termination message: `kubectl get pod <pod> -n kube-system -o jsonpath='{.status.containerStatuses[?(@.name=="ama-logs")].lastState.terminated.message}'`

**Spec change investigation via kube-audit:**
```kql
-- datasource: AKS CCP
KubeAudit
| where PreciseTimeStamp between(<start> .. <end>)
| where cluster_id == '<ccp-id>'
| where objectRef has "ama-logs" and verb == "patch"
| where tostring(objectRef.resource) in ("daemonsets", "deployments")
| project PreciseTimeStamp, verb, resource=tostring(objectRef.resource),
    name=tostring(objectRef.name), requestBody=substring(tostring(requestObject), 0, 2000)
```

## Diagnostic Steps

### 1. Identify which pod type is OOMing
Run `tsg_pods` → check all of:
- "AKS Alerts - Daemonset/Replicaset" for OOMKilled or CrashLoopBackOff status
- "Container Termination Reason (Kube-Audit)" for exit code 137
- "Kill Reason Breakdown" for any `Killing` reason=OOM events
- "AKSKubeEvents - Non-Routine Events" for events beyond normal BackOff/Pulled/Created

### 2. Check memory usage trends
Run `tsg_workload` → review "Memory RSS" queries for the affected component:
- **Daemonset OOM**: Check "Memory RSS - Linux Daemonset" and "Container Logs Generated Per Sec"
- **Replicaset OOM**: Check "Memory RSS - Replicaset" and cluster scale metrics
- **If all workload queries return empty**: The agent is crashing too fast to emit telemetry. This itself is a strong signal — the crash happens during startup, not from gradual memory growth.

### 3. Check if the crash is during MDSD startup

If the agent crashes within seconds of starting (4-12s), MDSD initialization is exceeding the container memory limit.

**Evidence from startup logs** (`tsg_logs`):
- If logs end at "Onboarding success" with no further output → crash occurs right after MDSD finishes loading data sources, before fluentd/fluent-bit/telegraf start
- The `checkAgentOnboardingStatus()` function in `main.sh` waits up to 30s for MDSD to write "Loaded data sources" (AAD MSI) or "Onboarding success" (legacy) to `mdsd.info`
- "Onboarding success" in the startup log means MDSD DID initialize — the OOM happens after, from combined process memory

**MDSD memory budget in a 1Gi container:**
- MDSD backpressure threshold: 512MB (50% of container limit)
- MDSD binary + DCR pipeline init: ~200-300MB
- Ruby runtime (dcr-config-parser.rb): ~50-100MB
- Shell + cron: ~50MB
- Total before fluentd even starts: ~800MB-1GB → OOM

### 4. Check addon enable/disable history

Run `tsg_triage` → check "Addon Enable/Disable History". If the customer disabled and re-enabled the addon:
- The re-enable deploys the latest agent version
- Auth mode switches from legacy (workspace key) to AAD MSI (DCR-based) — this is the new default
- DCR/DCE/DCRA are separate ARM resources that must be deployed independently (the AKS RP does not create them)
- If no DCR exists, MDSD in AAD MSI mode will fail to load data sources

**Check if DCR exists** — ask CSS or check ARM activity logs for `Microsoft.Insights/dataCollectionRules` in the cluster's resource group.

### 5. Diagnose root cause by component

#### Daemonset OOM
Common causes:
- **MDSD startup memory** — MDSD alone can consume 500-800MB on initialization
  - Check container memory limits in `kubectl describe pod`
  - If limit is 1Gi and container crashes in <30s, MDSD startup exceeds the limit
  - **Fix**: Request memory limit increase to 2Gi via AKS RP addon override
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

### 6. Configuration tuning

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
- **MDSD startup memory issues**: Azure Monitor Data Collection / AMA Linux
- **Memory limit increase for addon**: Azure Kubernetes Service / RP
- **Network issues related to AKS**: Azure Kubernetes Service / RP
