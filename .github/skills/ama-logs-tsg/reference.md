# Reference Guide — ama-logs-tsg MCP Server

## Data Sources

| Name | Type | Description |
|------|------|-------------|
| `ContainerInsightsAppInsights` | App Insights | Agent telemetry: customMetrics, customEvents, traces, exceptions |
| `AKS` | Kusto | AKS cluster state, pod alerts, node status (`akshuba.centralus`) |
| `AKS CCP` | Kusto | AKS control plane logs, kube events, audit logs (`akshuba.centralus`) |
| `AKS SwedenCentral` | Kusto | AKS RP alternate region for westeurope clusters (`altaksrpam.swedencentral`) — use for AgentPoolSnapshot, ManagedClusterSnapshot when AKS returns empty |
| `Azcore` | Kusto | Azure VM health metrics: CPU, memory pressure per VM (`azcore.centralus`) |
| `AzcrpBI` | Kusto | Azure CRP BI: VMSS instance → VM ID mapping (`azcrpbifollower`) |
| `Azcrp` | Kusto | Azure CRP: VM API QoS events, VMSS operations (`azcrp`) |
| `AKS GuestAgent` | Kusto | AKS node guest agent telemetry: PSI pressure, cgroup memory (`aksguestagent.centralus`) |

### AKS Region Routing

⚠️ **Not all AKS clusters are in `akshuba.centralus`.** Westeurope clusters are served by `altaksrpam.swedencentral.kusto.windows.net`. If AKS queries (AgentPoolSnapshot, ManagedClusterSnapshot) return empty, try `AKS SwedenCentral` datasource. CCP data (KubeSystemEvents, KubeAudit) remains in `akshuba.centralus` regardless of region.

### App Insights Resource
- **Name:** ContainerInsightsAgent-Prod
- **Subscription:** 13d371f9-5a39-46d5-8e1b-60158c49db84
- **Resource Group:** ContainerInsightsAgent-Prod

### App Insights Tables

| Table | Key Fields | Use |
|-------|-----------|-----|
| `customMetrics` | `name`, `value`, `customDimensions.ID` (cluster ARM ID), `customDimensions.Pod`, `customDimensions.AKS_RESOURCE_ID` | Agent resource usage, log volume metrics, cluster scale |
| `customEvents` | `name`, `customDimensions.ID`, `customDimensions.*` | Agent heartbeats, configuration state |
| `traces` | `message`, `customDimensions.ID`, `cloud_RoleInstance` | Agent logs, error messages |
| `exceptions` | `type`, `outerMessage`, `customDimensions.ID` | Agent exceptions |

### Cluster ID Filtering

Queries filter by cluster using the ARM resource ID in two patterns:
- `customDimensions.ID` — used in customEvents and traces
- `customDimensions.AKS_RESOURCE_ID` — used in some customMetrics

### Pod Name Patterns

| Pattern | Component |
|---------|-----------|
| `ama-logs-*` (not rs, not windows) | Linux daemonset |
| `ama-logs-rs-*` | Linux replicaset |
| `ama-logs-windows-*` | Windows daemonset |

Legacy pod names (pre-AMA migration):
- `omsagent-*` → Linux daemonset
- `omsagent-rs-*` → Linux replicaset
- `omsagent-win-*` → Windows daemonset

## Using tsg_query for Ad-Hoc Investigation

The `tsg_query` tool runs arbitrary KQL against any configured data source.

### Parameters
- `datasource` — One of: `ContainerInsightsAppInsights`, `AKS`, `AKS CCP`, `Azcore`, `AzcrpBI`, `Azcrp`, `AKS SwedenCentral`, `AKS GuestAgent`
- `kql` — The KQL query string
- `cluster` — Optional ARM resource ID (replaces `_cluster` in KQL)
- `timeRange` — Optional time range (default: "24h")
- `maxRows` — Max inline rows (default: 100)
- `outputFile` — Write full results to file (JSON or CSV)
- `outputFormat` — `csv` or `json` (default: csv)

### Common Query Patterns

**Check specific metric values:**
```kql
customMetrics
| where timestamp > ago(24h)
| where name == "memoryRssBytes"
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| extend Pod = tostring(customDimensions.Pod)
| extend UsageInMB = value/1024/1024
| summarize max_MB = max(UsageInMB), avg_MB = avg(UsageInMB) by Pod
| order by max_MB desc
```

**Search for specific error messages:**
```kql
traces
| where timestamp > ago(24h)
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| where message contains "error" or message contains "fail"
| summarize count() by message = substring(message, 0, 200)
| order by count_ desc
| take 20
```

**Check exception types:**
```kql
exceptions
| where timestamp > ago(24h)
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize count() by type, outerMessage
| order by count_ desc
```

**Check agent heartbeat frequency:**
```kql
customEvents
| where timestamp > ago(24h)
| extend ID = tostring(customDimensions.ID)
| where ID =~ _cluster
| summarize count() by name, bin(timestamp, 1h)
| order by timestamp desc
```

### AKS CCP Table Schemas

**IMPORTANT:** AKS CCP tables use different column names than you might expect:

| Table | Pod column | Message column | Cluster filter | Time column |
|-------|-----------|---------------|---------------|-------------|
| `KubeSystemEvents` | `name` (not `pod`) | `message` (not `msg`) | `resourceId =~ _cluster` | `TIMESTAMP` |
| `AKSKubeEvents` | `name` | `message` | `cluster_id` (CCP internal ID, not ARM ID) | `TIMESTAMP` |
| `KubeAudit` | N/A (in `objectRef`) | N/A (in `requestObject`/`responseObject`) | `cluster_id` (CCP internal ID) | `TIMESTAMP` |
| `ControlPlaneEvents` | `pod` | `MESSAGE` (uppercase) | `cluster_id` | `TIMESTAMP` |
| `FrontEndContextActivity` | N/A | `msg` | `subscriptionID` + `resourceName` | `TIMESTAMP` |
| `ManagedClusterSnapshot` | N/A | N/A | `name` (cluster short name) | `TIMESTAMP` |

**Getting the CCP internal cluster_id:** AKSKubeEvents and KubeAudit use an internal CCP cluster ID (e.g. `62012898d990cc00016b2cef`), not the ARM resource ID. To find it, use a subquery:
```kql
let ccpId = toscalar(KubeSystemEvents | where TIMESTAMP > ago(1d) | where resourceId =~ _cluster | take 1 | project cluster_id);
AKSKubeEvents | where cluster_id == ccpId | ...
```

**Extracting container termination status from kube-audit:**
```kql
KubeAudit
| where objectRef has "ama-logs" and verb == "patch"
| where requestObject has "terminated"
| extend ro = parse_json(requestObject)
| extend statuses = ro.status.containerStatuses
| mvexpand statuses
| where tostring(statuses.lastState) has "terminated"
| extend terminated = parse_json(tostring(statuses.lastState.terminated))
| project TIMESTAMP, container=tostring(statuses.name), reason=tostring(terminated.reason), exitCode=toint(terminated.exitCode)
```

**Checking addon enable/disable history:**
```kql
ManagedClusterSnapshot
| where name == 'cluster-short-name'
| extend omsEnabled = tostring(parse_json(tostring(addonProfiles.omsagent)).enabled)
| project TIMESTAMP, omsEnabled, provisioningState, latestOperationID
| order by TIMESTAMP asc
```

**Checking AKS RP operations for addon changes:**
```kql
FrontEndContextActivity
| where subscriptionID == 'subscription-id'
| where resourceName == 'cluster-short-name'
| where httpMethod in ('PUT', 'PATCH')
| where msg has 'omsagent' or msg has 'containerInsights' or msg has 'monitor'
| project TIMESTAMP, msg=substring(msg, 0, 400), operationID
```

## Agent Architecture

### Linux Daemonset (ama-logs)
- Runs on every Linux node
- Collects: container logs (stdout/stderr), container inventory
- Components: fluent-bit (log collection), MDSD (data upload)
- Config: agent-settings configmap for buffer tuning, namespace exclusion

### Linux Replicaset (ama-logs-rs)
- Single replica per cluster
- Collects: KubePodInventory, KubeNodeInventory, KubeEvents, KubeServices, cluster metrics
- Controlled by PODS_CHUNK_SIZE for large clusters

### Windows Daemonset (ama-logs-windows)
- Runs on every Windows node
- Collects: Windows container logs
- Uses: fluent-bit + MDSD (same pipeline as Linux)

### Key Configuration Options
- **High Log Scale Mode** — Optimizes for clusters with >50K records/sec log volume
- **PODS_CHUNK_SIZE** — Controls batch size for KubePodInventory (default: 1000, reduce for large clusters)
- **Excluded Namespaces** — Namespaces to skip for log collection
- **ContainerLogV2** — New table format (vs legacy ContainerLog)

## Telemetry Sources for Manual Investigation

| Source | URL | Use |
|--------|-----|-----|
| Container Agent Telemetry | Azure Portal → App Insights → ContainerInsightsAgent-Prod | customMetrics, customEvents, exceptions, traces |
| AIMC | http://aka.ms/aimc | Workspace info, billing tier, ingest limits |
| Jarvis | https://jarvis-west.dc.ad.msft.net | ODS ingestion logs, quota, latency |
| Azure Service Insights | https://azureserviceinsights.trafficmanager.net | Cluster info, pods, nodes |

### ⚠️ dmesg / Kernel Logs Are NOT in AKS Telemetry

There are **no syslog, dmesg, or kernel log tables** in any AKS Kusto database (CCP, prod, or Azcore). The following tables were checked and confirmed absent: `Syslog`, `LinuxDiagnostics`, `NodeDiagnostics`, `KernelLog`, `Dmesg`.

**To check for kernel OOM kills without SSH/dmesg, use node-problem-detector (NPD) events:**

AKS runs NPD on every node. NPD monitors `/dev/kmsg` and emits Kubernetes events for kernel OOM kills. These appear in `AKSKubeEvents` with reason `OOMKilling`:

```kql
-- datasource: AKS CCP
AKSKubeEvents
| where PreciseTimeStamp > ago(7d)
| where cluster_id == '<ccp-id>'
| where reason has_any ("OOMKilling", "OOMKilled", "SystemOOM")
   or reportingController has_any ("node-problem-detector", "kernel-monitor")
| project PreciseTimeStamp, kind, name, reason, message, reportingController
```

**Zero rows = kernel OOM killer did NOT fire.** This is the telemetry-only equivalent of `dmesg | grep oom`.

Other useful NPD event reasons: `KernelOops`, `TaskHung`, `DockerHung`, `MemoryPressure`.

If the customer has **Container Insights syslog collection** enabled, kernel OOM messages flow to the `Syslog` table in their Log Analytics workspace — but this is customer-side config, not AKS infrastructure telemetry.

## Node-Level VM Health Investigation

When exit 137 crashes don't appear to be OOM (agent memory is low), investigate VM-level health to rule out host memory pressure.

### Step 1: Map Node Names → VM IDs (AzcrpBI)

Node names use base-36 encoded VMSS instance IDs. Use AzcrpBI to get the mapping:

```kql
-- datasource: AzcrpBI
VMScaleSetVMInstance
| where PreciseTimeStamp > ago(7d)
| where SubscriptionId =~ '<subscription-id>'
| where ResourceGroupName =~ 'MC_<rg>_<cluster>_<region>'
| where VMScaleSetName has '<nodepool-name>'
| extend instance = tolower(strcat(VMScaleSetName, '_', InstanceIdString))
| summarize arg_max(PreciseTimeStamp, VMScaleSetVMInstanceId) by instance
| project instance, vm_id = VMScaleSetVMInstanceId
```

### Step 2: Query VM CPU/Memory Pressure (Azcore)

Use the VM IDs to query host-level metrics. First resolve ContainerIds, then query counters:

```kql
-- datasource: Azcore
let vmids = dynamic(["vm-id-1", "vm-id-2"]);
let containerids = materialize (
    cluster("azcore.centralus.kusto.windows.net").database("Fa").VmHealthRawStateEtwTable
    | where PreciseTimeStamp > ago(3d)
    | where VirtualMachineUniqueId in (vmids)
    | distinct ContainerId, VirtualMachineUniqueId
);
cluster("azcore.centralus").database("Fa").VmCounterFiveMinuteRoleInstanceCentralBondTable
| where PreciseTimeStamp > ago(3d)
| where VmId in ((containerids | project ContainerId))
| where CounterName endswith "Pressure" or CounterName == "Percentage CPU"
| where CounterName !has "Physical Memory" and CounterName !has 'Guest Available Memory'
| join kind=inner (containerids) on $left.VmId == $right.ContainerId
| extend CounterLabel = case(
    CounterName == "Percentage CPU", "CPU_Max%",
    CounterName endswith "Current Pressure", "Mem_Current%",
    CounterName endswith "Maximum Pressure", "Mem_Max%",
    ""
)
| where isnotempty(CounterLabel)
| summarize Avg=round(avg(MaxCounterValue),1), Max=round(max(MaxCounterValue),1),
    P95=round(percentile(MaxCounterValue, 95),1) by VirtualMachineUniqueId, CounterLabel
```

### Interpreting VM Health Results

- If **crashing nodes have higher memory pressure** than healthy nodes → host OOM killer may be killing the ama-logs cgroup
- If **crashing nodes have lower or equal memory pressure** → VM-level resources are NOT the cause; investigate deployment spec, addon reconciliation, or node-specific state corruption
- Memory pressure >100% is possible (over-committed VMs) — compare relative values between healthy and crashing nodes

### KubeSystemEvents Schema

**⚠️ `KubeSystemEvents` does NOT have a `sourceHost` column.** Available columns:

| Column | Description |
|--------|-------------|
| `name` | Pod name (e.g. `ama-logs-flclm`) |
| `reason` | Event reason (Started, Created, Pulled, Killing, BackOff, Unhealthy) |
| `message` | Event message text |
| `hostMachine` | Host machine identifier (NOT the node name) |
| `container` | Container name |
| `containerID` | Container ID |
| `pod` | Pod identifier |
| `cluster_id` | CCP internal cluster ID |
| `resourceId` | ARM resource ID |

To correlate pods to nodes, use KubeAudit `objectRef.name` for node operations, or App Insights `customDimensions.Node` for agent telemetry.

## Node PSI Pressure & CGroup Memory (GuestAgentGenericLogs)

**Datasource:** `AKS GuestAgent` (`aksguestagent.centralus.kusto.windows.net` / `aksguestagent`)

⚠️ **This datasource may need the cluster URI or database name adjusted.** The `GuestAgentGenericLogs` table contains AKS node guest agent telemetry including PSI pressure metrics and cgroup memory usage.

### PSI Pressure Metrics

PSI (Pressure Stall Information) is a Linux kernel feature that measures resource contention at the cgroup level. Source: `cgroup-pressure-telemetry.sh` in the AgentBaker repo.

**Key metric:** `some_avg60` — percentage of the last 60 seconds that **some** tasks were stalled waiting for a resource.

**Severity scale:**
| some_avg60 | Severity | Impact |
|-----------|----------|--------|
| < 5% | Normal | No impact on workloads |
| 5–10% | Light | Workloads may notice slight delays |
| 10–25% | Moderate | Workloads slowing down |
| 25–50% | Significant | Critical services affected |
| 50–90% | Severe | Node degrading |
| > 90% | Critical | Node at risk of going NotReady |

**Cgroup slices monitored:**
| Slice | Contains |
|-------|----------|
| `cgroup_pressure` | Whole node (root cgroup) |
| `system_slice_pressure` | System services (kubelet, containerd, systemd) |
| `kubepods_slice_pressure` | All Kubernetes pods |
| `kubelet_service_pressure` | Kubelet process |
| `containerd_service_pressure` | Container runtime |
| `azure_slice_pressure` | Azure platform services |

**When both CPU and Memory PSI are > 90%:** Vicious cycle — memory pressure causes swapping → consumes CPU → CPU delays memory management → worsens memory pressure. Node often can't self-recover; reboot may be needed.

**Query: PSI Pressure by Cgroup Slice**
```kql
-- datasource: AKS GuestAgent
GuestAgentGenericLogs
| where PreciseTimeStamp >= ago(24h)
| where resourceId =~ _cluster
| where Level == "AKS.Runtime.pressure_telemetry_cgroupv2"
| extend ExtLog = parse_json(Message)
| extend P = ExtLog.Pressure
| project theDate = PreciseTimeStamp, node = tostring(NodeName),
    cgroup_cpu = todouble(P.cgroup_pressure.CPUPressure.some_avg60),
    cgroup_mem = todouble(P.cgroup_pressure.MemoryPressure.some_avg60),
    kubepods_cpu = todouble(P.kubepods_slice_pressure.CPUPressure.some_avg60),
    kubepods_mem = todouble(P.kubepods_slice_pressure.MemoryPressure.some_avg60),
    kubelet_cpu = todouble(P.kubelet_service_pressure.CPUPressure.some_avg60),
    containerd_cpu = todouble(P.containerd_service_pressure.CPUPressure.some_avg60),
    containerd_io = todouble(P.containerd_service_pressure.IOPressure.some_avg60)
| order by theDate asc
```

### CGroup Memory Usage

Shows actual memory consumption per cgroup slice in GB. Useful for:
- Identifying which slice is consuming the most memory
- Detecting memory spikes correlated with crashes
- Seeing the impact of node reboots (all values drop to zero)

**Query: CGroup Memory Usage by Slice (GB)**
```kql
-- datasource: AKS GuestAgent
GuestAgentGenericLogs
| where PreciseTimeStamp >= ago(24h)
| where resourceId =~ _cluster
| where Level == "AKS.Runtime.cgroup_memory_telemetry"
| extend ExtLog = parse_json(Message)
| project theDate = PreciseTimeStamp, node = tostring(NodeName),
    CgroupCapacity = todouble(ExtLog.CgroupCapacity) / 1073741824,
    CgroupMemory = todouble(ExtLog.CgroupMemory) / 1073741824,
    KubePodsSlice = todouble(ExtLog.KubePodsSlice) / 1073741824,
    KubePodsMax = todouble(ExtLog.KubePodsMax) / 1073741824,
    SystemSlice = todouble(ExtLog.SystemSlice) / 1073741824,
    ContainerdService = todouble(ExtLog.ContainerdService) / 1073741824,
    KubeletService = todouble(ExtLog.KubeletService) / 1073741824,
    AzureSlice = todouble(ExtLog.AzureSlice) / 1073741824,
    UserSlice = todouble(ExtLog.UserSlice) / 1073741824
| order by theDate asc
```

### Interpreting CGroup Memory + PSI Together

| Pattern | Meaning |
|---------|---------|
| High kubepods memory + high PSI CPU | Workload memory pressure causing CPU stalls (page reclaim) |
| CgroupMemory near CgroupCapacity | Node approaching total memory limit — OOM killer likely |
| Memory drops to zero briefly | Node reboot — expect IO pressure spike on recovery |
| ContainerdService memory spike | Container runtime memory leak or high container churn |
| All PSI zero + crash | Crash is NOT resource-related — check liveness probes, auth, MDSD init |
