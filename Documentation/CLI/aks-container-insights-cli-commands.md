# AKS Container Insights & Azure Monitor — Azure CLI reference

`az aks` (aks-preview extension) commands and arguments to **onboard, offboard, and configure** AKS
monitoring: Container Insights (logs), Managed Prometheus (metrics), Application Monitoring, and
OpenTelemetry (OTLP).

> Layout: capability-first. Each section is self-contained — command surfaces, arguments (with
> where they write + create/update/addon availability), and disable/cleanup behavior.
> Grounded in `aks-preview` source (`_help.py`, `_params.py`, `managed_cluster_decorator.py`,
> `addonconfiguration.py`, `_consts.py`).

**Availability legend:** ✅ supported · — not supported.
"Addon" = `enable-addons` / `disable-addons` / `addon enable` / `addon update` (monitoring only).

---

## 0. Quick decision

| I want to… | Capability | Preferred command |
|---|---|---|
| Collect container **logs** (Container Insights) | Logs | `az aks create/update --enable-azure-monitor-logs` |
| Collect **Prometheus metrics** | Metrics | `az aks create/update --enable-azure-monitor-metrics` |
| Auto-instrument **apps** | App Monitoring | `az aks create/update --enable-azure-monitor-app-monitoring` |
| Send app **OTLP metrics** | OTLP metrics | `… --enable-opentelemetry-metrics` (needs AM metrics) |
| Send app **OTLP logs/traces** | OTLP logs | `… --enable-opentelemetry-logs-traces` (needs AM logs) |

Only **Container Insights** is available as a legacy addon; everything else is create/update-only.
All of App Monitoring + OTLP are **Preview**, gated by subscription feature
`Microsoft.ContainerService/AzureMonitorAppMonitoringPreview` (register once with `az feature register`).

---

## Master argument index — all flags & effects

Every monitoring argument at a glance. **C/U** = available on `create` / `update`. **Writes to**
lists **only the fields the CLI explicitly mutates/sets** on the ManagedCluster object (RP-side mirroring,
e.g. the RP populating `azureMonitorProfile.containerInsights` from `omsagent`, is **excluded**; note a
full-cluster PUT still serializes existing fields unchanged).
`addonProfiles` = legacy addon profile · `azureMonitorProfile` = new unified profile · `side resource`
= out-of-band resource (DCR/DCE/AMW rules/RBAC), not on the cluster object. See capability sections
for command syntax and disable/cleanup.

| Argument | Capability | Effect | C | U | Writes to | Preview |
|---|---|---|:--:|:--:|---|:--:|
| `--enable-azure-monitor-logs` | Logs | Enable Container Insights (`omsagent`) | ✅ | ✅ | `addonProfiles` | |
| `--disable-azure-monitor-logs` | Logs | Disable Container Insights (+ cascades to OTLP logs) | — | ✅ | `addonProfiles` + `azureMonitorProfile` | |
| `--enable-addons monitoring` / `-a` | Logs | Enable Container Insights (addon form) | ✅ | — | `addonProfiles` | |
| `--disable-addons monitoring` | Logs | Disable Container Insights (addon form) — ⚠️ leaves `containerInsights=true`; RP may re-enable, prefer `--disable-azure-monitor-logs` (§1.3) | — | — | `addonProfiles` | |
| `--workspace-resource-id` | Logs | Sets `omsagent.config.logAnalyticsWorkspaceResourceID` | ✅ | ✅ | `addonProfiles` | |
| `--enable-msi-auth-for-monitoring` | Logs | Sets `omsagent.config.useAADAuth` + switches to DCR/AAD path | ✅ | ✅ | `addonProfiles` + `side resource` | ✅ |
| `--enable-syslog` | Logs | Syslog stream in the CI **DCR** (needs MSI auth) | ✅ | ✅ | `side resource` | ✅ |
| `--data-collection-settings` | Logs | Streams/interval/namespaces in the CI **DCR** (needs MSI auth) | ✅ | ✅ | `side resource` | ✅ |
| `--enable-high-log-scale-mode` | Logs | High-scale log streams in the CI **DCR** | ✅ | ✅ | `side resource` | ✅ |
| `--enable-container-network-logs` | Logs | Container network (flow) logs; sets `omsagent.config.enableRetinaNetworkFlags` + auto-enables high-log-scale | ✅ | ✅ | `addonProfiles` + `side resource` | |
| `--disable-container-network-logs` | Logs | Disable container network (flow) logs | ✅ | ✅ | `addonProfiles` + `side resource` | |
| `--ampls-resource-id` | Logs | Private-link (AMPLS): creates config DCE, DCE→cluster association, and links config DCE + workspace + ingestion DCE into the scope (private+MSI only) — see §1.5 | ✅ | ✅ | `side resource` | ✅ |
| `--enable-azure-monitor-metrics` | Metrics | Enable managed Prometheus (`metrics.enabled`) | ✅ | ✅ | `azureMonitorProfile` | |
| `--disable-azure-monitor-metrics` | Metrics | Disable metrics (+ cascades to OTLP metrics) | — | ✅ | `azureMonitorProfile` | |
| `--ksm-metric-labels-allow-list` | Metrics | `metrics.kubeStateMetrics.metricLabelsAllowlist` | ✅ | ✅ | `azureMonitorProfile` | |
| `--ksm-metric-annotations-allow-list` | Metrics | `metrics.kubeStateMetrics.metricAnnotationsAllowList` | ✅ | ✅ | `azureMonitorProfile` | |
| `--enable-control-plane-metrics` / `--enable-cp-metrics` | Metrics | `metrics.controlPlane.enabled` (deferred on create — §2.2) | ✅ | ✅ | `azureMonitorProfile` | |
| `--disable-control-plane-metrics` / `--disable-cp-metrics` | Metrics | `metrics.controlPlane.enabled=false` | — | ✅ | `azureMonitorProfile` | |
| `--azure-monitor-workspace-resource-id` | Metrics | Target AMW for metrics **DCR/DCE** | ✅ | ✅ | `side resource` | |
| `--grafana-resource-id` | Metrics | Links an Azure Managed Grafana workspace (role assignment) | ✅ | ✅ | `side resource` | |
| `--enable-windows-recording-rules` | Metrics | Windows Prometheus **recording rule groups** in the AMW | ✅ | ✅ | `side resource` | |
| `--enable-azure-monitor-app-monitoring` | App Mon | `appMonitoring.autoInstrumentation.enabled=true` | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--disable-azure-monitor-app-monitoring` | App Mon | `appMonitoring.autoInstrumentation.enabled=false` | — | ✅ | `azureMonitorProfile` | ✅ |
| `--enable-opentelemetry-metrics` | OTLP | `appMonitoring.openTelemetryMetrics.enabled=true` (needs AM metrics) | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--disable-opentelemetry-metrics` | OTLP | Disable OTLP metrics + clear ports | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--opentelemetry-metrics-port-http` | OTLP | `openTelemetryMetrics.httpPort` (default `28333`) | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--opentelemetry-metrics-port-grpc` | OTLP | `openTelemetryMetrics.grpcPort` (default `28334`) | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--enable-opentelemetry-logs-traces` | OTLP | `appMonitoring.openTelemetryLogsAndTraces.enabled=true` (needs AM logs) | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--disable-opentelemetry-logs-traces` | OTLP | Disable OTLP logs/traces + clear ports | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--opentelemetry-logs-traces-port-http` | OTLP | `openTelemetryLogsAndTraces.httpPort` (default `28331`) | ✅ | ✅ | `azureMonitorProfile` | ✅ |
| `--opentelemetry-logs-traces-port-grpc` | OTLP | `openTelemetryLogsAndTraces.grpcPort` (default `28332`) | ✅ | ✅ | `azureMonitorProfile` | ✅ |

Deprecated OTLP aliases (`--opentelemetry-metrics-port`, `--opentelemetry-logs-port`,
`--enable/disable-opentelemetry-logs`) still work with a warning — see §4.3.

---

## 1. Container Insights / Azure Monitor logs

### 1.1 Command surfaces (all equivalent — pick one)
| Surface | Command | Use for | Notes |
|---|---|---|---|
| Addon on create | `az aks create --enable-addons monitoring` | New cluster | Legacy addon style |
| Addon standalone | `az aks enable-addons -a monitoring` | Existing cluster | Legacy addon style |
| Addon group | `az aks addon enable -a monitoring` | Existing cluster | Same surface; supports reconfig via `addon update` |
| Unified flag | `az aks create/update --enable-azure-monitor-logs` | Preferred | Do **not** combine with `--enable-addons monitoring` |

### 1.2 Arguments & effects
| Argument | Create | Update | Addon | Type | Writes to / effect | Preview |
|---|:--:|:--:|:--:|---|---|:--:|
| `--enable-azure-monitor-logs` | ✅ | ✅ | — | flag | `addonProfiles.omsagent.enabled=true` (CLI writes `omsagent` only; RP mirrors to `containerInsights`) | |
| `--enable-addons monitoring` / `-a` | ✅ | — | ✅ | enum | same as above | |
| `--workspace-resource-id` | ✅ | ✅ | ✅ | string | `addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID` (else default LA workspace) | |
| `--enable-msi-auth-for-monitoring` | ✅ | ✅ | ✅ | 3-state | `omsagent.config.useAADAuth` **and** switches onboarding to the DCR/DCRA (AAD) path | ✅ |
| `--enable-syslog` | ✅ | ✅ | ✅ | 3-state | Syslog stream in the Container Insights **DCR** (needs MSI auth) | ✅ |
| `--data-collection-settings` | ✅ | ✅ | ✅ | string (path) | Streams/interval/namespaces in the **DCR** (needs MSI auth) | ✅ |
| `--enable-high-log-scale-mode` | ✅ | ✅ | ✅ | 3-state | High-scale log streams in the **DCR**; auto-on with `--enable-container-network-logs` | ✅ |
| `--enable-container-network-logs` / `--disable-container-network-logs` | ✅ | ✅ | — | flag | Container network (flow) logs — see §1.4 | |
| `--ampls-resource-id` | ✅ | ✅ | ✅ | string | Onboards Container Insights behind an Azure Monitor Private Link Scope — see §1.5 (more than a DCE) | ✅ |

3-state flags accept `true`/`false` (e.g. `--enable-syslog false`).

### 1.3 Disable / cleanup
```
az aks disable-addons -g <rg> -n <name> -a monitoring
az aks update -g <rg> -n <name> --disable-azure-monitor-logs
```
- `az aks update --disable-azure-monitor-logs` clears **both** surfaces **when both exist**: sets
  `addonProfiles.omsagent.enabled=false`, `config=None`, **and** (only if the profile is present)
  `azureMonitorProfile.containerInsights.enabled=false`. It does not create a missing `containerInsights`
  profile. The RP treats `containerInsights.enabled` as source of truth, so clearing it is what makes the
  disable stick. **This is the reliable way to disable Container Insights.**
- ⚠️ `az aks disable-addons -a monitoring` (legacy path) sets **only** `addonProfiles.omsagent.enabled=false`
  and clears its config; it does **not** touch `azureMonitorProfile.containerInsights`. Because it leaves
  `containerInsights.enabled=true`, the RP can **re-enable** the addon — so on clusters where the unified
  profile is populated, legacy disable may **not** actually turn monitoring off. Prefer
  `--disable-azure-monitor-logs`. (Verified in recording `test_aks_create_with_monitoring_legacy_auth.yaml:1705-1720`:
  the disable PUT sends `omsagent.enabled=false` while `containerInsights.enabled=true` is left unchanged.)
- If OTLP logs/traces were enabled, they are disabled too (via `--disable-azure-monitor-logs`).
- On the MSI-auth path, the CLI cleans up the DCR/DCRA **before** disabling (only when the addon was
  enabled with `useAADAuth=true`).

### 1.4 Network flow logs (container network logs)
Collect network flow logs (Retina/ACNS) through the Container Insights pipeline.
```
az aks create/update -g <rg> -n <name> --enable-azure-monitor-logs --enable-container-network-logs
az aks update        -g <rg> -n <name> --disable-container-network-logs
```
| Argument | Create | Update | Effect |
|---|:--:|:--:|---|
| `--enable-container-network-logs` | ✅ | ✅ | Sets `addonProfiles.omsagent.config.enableRetinaNetworkFlags="True"`. **Auto-enables** `--enable-high-log-scale-mode` (which provisions the high-scale ingestion DCE). |
| `--disable-container-network-logs` | ✅ | ✅ | Sets `enableRetinaNetworkFlags="False"`. |

- Requires the **monitoring addon** (Container Insights) — it writes to the `omsagent` addon config.
- Explicitly passing `--enable-high-log-scale-mode false` together with `--enable-container-network-logs`
  is an error (network logs require high-log-scale mode).
- **Deprecated aliases** (hidden, still work → redirect):
  `--enable-retina-flow-logs` → `--enable-container-network-logs`,
  `--disable-retina-flow-logs` → `--disable-container-network-logs`.

### 1.5 Private link (`--ampls-resource-id`) — what it actually does
`--ampls-resource-id` is **not** just "add a DCE". When set (private cluster + MSI auth only), the CLI:
1. Validates **private cluster + MSI (AAD) mode** — otherwise errors.
2. Creates a **config DCE** in the cluster region (in addition to the high-log-scale **ingestion DCE**).
3. Creates a **DCE→cluster association** (DCRA) for the config DCE.
4. Links **three** resources into the Azure Monitor Private Link Scope: the **config DCE**, the
   **Log Analytics workspace**, and the **ingestion DCE**.

(All of the above are side resources; none are fields on the ManagedCluster object.)

---

## 2. Managed Prometheus / Azure Monitor metrics

### 2.1 Commands
```
az aks create -g <rg> -n <name> --enable-azure-monitor-metrics
az aks update -g <rg> -n <name> --enable-azure-monitor-metrics
az aks update -g <rg> -n <name> --disable-azure-monitor-metrics
```
Not an addon — create/update only.

### 2.2 Arguments & effects
| Argument | Create | Update | Type | Writes to / effect | Notes |
|---|:--:|:--:|---|---|---|
| `--enable-azure-monitor-metrics` | ✅ | ✅ | flag | `azureMonitorProfile.metrics.enabled=true` | |
| `--disable-azure-monitor-metrics` | — | ✅ | flag | `azureMonitorProfile.metrics.enabled=false` | update only |
| `--ksm-metric-labels-allow-list` | ✅ | ✅ | string | `azureMonitorProfile.metrics.kubeStateMetrics.metricLabelsAllowlist` | |
| `--ksm-metric-annotations-allow-list` | ✅ | ✅ | string | `azureMonitorProfile.metrics.kubeStateMetrics.metricAnnotationsAllowList` | |
| `--enable-control-plane-metrics` / `--enable-cp-metrics` | ✅* | ✅ | flag | `azureMonitorProfile.metrics.controlPlane.enabled` — **see note** | requires AM metrics |
| `--disable-control-plane-metrics` / `--disable-cp-metrics` | — | ✅ | flag | `azureMonitorProfile.metrics.controlPlane.enabled=false` | update only |
| `--azure-monitor-workspace-resource-id` | ✅ | ✅ | string | Target Azure Monitor Workspace for the metrics **DCR/DCE** (not a cluster field) | |
| `--grafana-resource-id` | ✅ | ✅ | string | Links an Azure Managed Grafana workspace (role assignment / data source) | |
| `--enable-windows-recording-rules` | ✅ | ✅ | flag | Creates Windows Prometheus **recording rule groups** in the AMW (not a cluster field) | |

> \* **Control-plane metrics on create:** the value is validated and remembered but **not** set on the
> initial cluster PUT — the CLI flips `controlPlane.enabled` in a postprocessing step *after* the
> DCR/DCRA exists (so the collection pod doesn't start before its association). On **update** it sets
> the field directly (AM metrics must be already enabled or enabled in the same command).

### 2.3 Disable / cleanup
```
az aks update -g <rg> -n <name> --disable-azure-monitor-metrics
```
- Sets `azureMonitorProfile.metrics.enabled=false`; disables OTLP metrics if they were on.
- The CLI runs the Azure Monitor metrics prerequisite/cleanup path (metrics DCRA / linked collection resources).

### 2.4 Deprecated aliases (hidden; still work → redirect)
| Deprecated | Use instead |
|---|---|
| `--enable-azuremonitormetrics` | `--enable-azure-monitor-metrics` |
| `--disable-azuremonitormetrics` | `--disable-azure-monitor-metrics` |

---

## 3. Application Monitoring (auto-instrumentation)  · Preview

```
az aks create -g <rg> -n <name> --enable-azure-monitor-app-monitoring
az aks update -g <rg> -n <name> --enable-azure-monitor-app-monitoring
az aks update -g <rg> -n <name> --disable-azure-monitor-app-monitoring
```
| Argument | Create | Update | Writes to |
|---|:--:|:--:|---|
| `--enable-azure-monitor-app-monitoring` | ✅ | ✅ | `azureMonitorProfile.appMonitoring.autoInstrumentation.enabled=true` |
| `--disable-azure-monitor-app-monitoring` | — | ✅ | `…autoInstrumentation.enabled=false` |

Gated by feature `AzureMonitorAppMonitoringPreview` (same gate as OTLP).

---

## 4. OpenTelemetry (OTLP) metrics & logs/traces  · Preview

Gated by `AzureMonitorAppMonitoringPreview`. OTLP **metrics** require Azure Monitor **metrics**;
OTLP **logs/traces** require Azure Monitor **logs**. All four ports must be **distinct**, 1–65535.

### 4.1 Commands
```
# metrics (needs --enable-azure-monitor-metrics already/together)
az aks create/update … --enable-opentelemetry-metrics \
  [--opentelemetry-metrics-port-http <p>] [--opentelemetry-metrics-port-grpc <p>]
az aks update … --disable-opentelemetry-metrics

# logs/traces (needs --enable-azure-monitor-logs already/together)
az aks create/update … --enable-opentelemetry-logs-traces \
  [--opentelemetry-logs-traces-port-http <p>] [--opentelemetry-logs-traces-port-grpc <p>]
az aks update … --disable-opentelemetry-logs-traces
```

### 4.2 Arguments & effects
| Argument | Create | Update | Default | Writes to |
|---|:--:|:--:|:--:|---|
| `--enable-opentelemetry-metrics` | ✅ | ✅ | — | `…appMonitoring.openTelemetryMetrics.enabled=true` |
| `--disable-opentelemetry-metrics` | ✅ | ✅ | — | `…openTelemetryMetrics.enabled=false` (clears ports) |
| `--opentelemetry-metrics-port-http` | ✅† | ✅‡ | `28333` | `…openTelemetryMetrics.httpPort` |
| `--opentelemetry-metrics-port-grpc` | ✅† | ✅‡ | `28334` | `…openTelemetryMetrics.grpcPort` |
| `--enable-opentelemetry-logs-traces` | ✅ | ✅ | — | `…appMonitoring.openTelemetryLogsAndTraces.enabled=true` |
| `--disable-opentelemetry-logs-traces` | ✅ | ✅ | — | `…openTelemetryLogsAndTraces.enabled=false` (clears ports) |
| `--opentelemetry-logs-traces-port-http` | ✅† | ✅‡ | `28331` | `…openTelemetryLogsAndTraces.httpPort` |
| `--opentelemetry-logs-traces-port-grpc` | ✅† | ✅‡ | `28332` | `…openTelemetryLogsAndTraces.grpcPort` |

> † On **create**, a port requires its matching `--enable-opentelemetry-*` in the same command.
> ‡ On **update**, a port is allowed if the signal is being enabled now **or** already enabled.

### 4.3 Deprecated aliases (still work; emit a deprecation warning)
| Deprecated | Use instead |
|---|---|
| `--opentelemetry-metrics-port` | `--opentelemetry-metrics-port-http` |
| `--opentelemetry-logs-port` | `--opentelemetry-logs-traces-port-http` |
| `--enable-opentelemetry-logs` | `--enable-opentelemetry-logs-traces` |
| `--disable-opentelemetry-logs` | `--disable-opentelemetry-logs-traces` |

### 4.4 Disable / cleanup
- `--disable-opentelemetry-metrics` / `--disable-opentelemetry-logs-traces`: set `enabled=false` and
  clear **both** `httpPort` and `grpcPort`. No DCR/DCE cleanup by themselves.
- Disabling the **parent** (`--disable-azure-monitor-metrics` / `--disable-azure-monitor-logs`)
  **cascades**: it also disables the corresponding OTLP signal and clears its ports.

---

## 4b. Cluster health monitor (separate subsystem · Preview)

> Not Container Insights / Azure Monitor. These write to a **different profile**
> (`healthMonitorProfile`) — included here only because the flag names contain "monitor" and readers
> often conflate them. Both are Preview.

```
az aks create/update -g <rg> -n <name> --enable-continuous-control-plane-and-addon-monitor
az aks create/update -g <rg> -n <name> --enable-on-demand-monitor
az aks update        -g <rg> -n <name> --disable-on-demand-monitor
```
| Argument | Create | Update | Writes to |
|---|:--:|:--:|---|
| `--enable-continuous-control-plane-and-addon-monitor` | ✅ | ✅ | `healthMonitorProfile.enableContinuousControlPlaneAndAddonMonitor` |
| `--disable-continuous-control-plane-and-addon-monitor` | — | ✅ | `healthMonitorProfile.enableContinuousControlPlaneAndAddonMonitor=false` |
| `--enable-on-demand-monitor` | ✅ | ✅ | `healthMonitorProfile.enableOnDemandMonitor` |
| `--disable-on-demand-monitor` | — | ✅ | `healthMonitorProfile.enableOnDemandMonitor=false` |

---

## 5. Cross-capability gotchas
- `--enable-azure-monitor-logs` **==** `az aks enable-addons -a monitoring` — don't use both together.
- **MSI auth vs service principal:** `--enable-msi-auth-for-monitoring` cannot be used on SP clusters.
  `--enable-syslog` / `--data-collection-settings` require MSI auth.
- **Disable cascades:** disabling a parent Azure Monitor capability also disables its OTLP child.
- **Preview registration:** App Monitoring + OTLP need `AzureMonitorAppMonitoringPreview` registered on
  the subscription. (Note: passing it as an `--aks-custom-headers AKSHTTPCustomFeatures=…` header is
  now rejected by the RP — registration is the supported path.)
- **`--no-wait` has no effect** when the monitoring addon is being enabled.

---

## 6. Appendix — object-path & side-resource map

### 6a. Fields on the ManagedCluster object (part of the cluster PUT)
| Argument | Property |
|---|---|
| `--enable-azure-monitor-logs` / `enable-addons monitoring` | `addonProfiles.omsagent.enabled` (CLI writes `omsagent` only; RP mirrors `containerInsights`) |
| `--workspace-resource-id` | `addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID` |
| `--enable-msi-auth-for-monitoring` | `addonProfiles.omsagent.config.useAADAuth` |
| `--enable/disable-container-network-logs` | `addonProfiles.omsagent.config.enableRetinaNetworkFlags` (+ auto high-log-scale side resource) |
| `--enable-azure-monitor-metrics` | `azureMonitorProfile.metrics.enabled` |
| `--ksm-metric-labels-allow-list` | `azureMonitorProfile.metrics.kubeStateMetrics.metricLabelsAllowlist` |
| `--ksm-metric-annotations-allow-list` | `azureMonitorProfile.metrics.kubeStateMetrics.metricAnnotationsAllowList` |
| `--enable/disable-control-plane-metrics` | `azureMonitorProfile.metrics.controlPlane.enabled` (deferred on create — see §2.2) |
| `--enable-azure-monitor-app-monitoring` | `azureMonitorProfile.appMonitoring.autoInstrumentation.enabled` |
| `--enable/disable-opentelemetry-metrics` | `azureMonitorProfile.appMonitoring.openTelemetryMetrics.enabled` |
| `--opentelemetry-metrics-port-http` / `-grpc` | `…openTelemetryMetrics.httpPort` / `.grpcPort` |
| `--enable/disable-opentelemetry-logs-traces` | `azureMonitorProfile.appMonitoring.openTelemetryLogsAndTraces.enabled` |
| `--opentelemetry-logs-traces-port-http` / `-grpc` | `…openTelemetryLogsAndTraces.httpPort` / `.grpcPort` |

### 6b. Side resources (NOT a ManagedCluster field)
| Argument | Creates / configures |
|---|---|
| `--enable-syslog` | Syslog stream in the Container Insights **DCR** (needs MSI auth) |
| `--data-collection-settings` | Streams/interval/namespaces in the Container Insights **DCR** (needs MSI auth) |
| `--enable-high-log-scale-mode` | High-scale log streams in the Container Insights **DCR** (provisions the ingestion **DCE**) |
| `--ampls-resource-id` | Private-link onboarding (private+MSI only): creates a **config DCE**, a **DCE→cluster association**, and links **config DCE + Log Analytics workspace + ingestion DCE** into the Azure Monitor Private Link Scope. Not just a DCE. |
| `--azure-monitor-workspace-resource-id` | Target AMW for the metrics **DCR/DCE** (Prometheus ingestion) |
| `--grafana-resource-id` | Links an Azure Managed Grafana workspace (role assignment / data source) |
| `--enable-windows-recording-rules` | Windows Prometheus **recording rule groups** in the AMW |
