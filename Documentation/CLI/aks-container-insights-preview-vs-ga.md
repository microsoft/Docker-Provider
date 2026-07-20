# AKS Container Insights — Preview vs GA CLI Surface

Comparison of the `aks-preview` extension (`21.0.0b9`) vs core `az aks` (azure-cli `acs` module, dev branch) for Container Insights and log collection.

## TL;DR

The five container-insights capability flags — `--enable-msi-auth-for-monitoring`, `--enable-syslog`, `--data-collection-settings`, `--enable-high-log-scale-mode`, `--ampls-resource-id` — have **graduated to GA** in core `az aks` (registered with no `is_preview`), but `aks-preview` still labels those same five `is_preview=True` (a stale label, not a capability gap). The exception is the convenience aliases `--enable-azure-monitor-logs` / `--disable-azure-monitor-logs`, which are **not in core `az aks` at all** (extension-only). Note these two aliases are *not* preview-flagged in aks-preview — they are simply absent from core. The DCR/DCRA engine, preset validation, and stream list live once in shared `acs.addonconfiguration`, which both surfaces import.

## Flag matrix

| CLI flag | aks-preview | core az aks | Delta |
|---|---|---|---|
| `--enable-addons monitoring` | supported | supported | Identical entry point |
| `--enable-azure-monitor-logs` / `--disable-azure-monitor-logs` | supported (not preview) | **not present** | Extension-only alias for `--enable-addons monitoring` |
| `--enable-msi-auth-for-monitoring` | `is_preview` | **GA** | Graduated; label stale in ext |
| `--enable-syslog` | `is_preview` | **GA** | Graduated |
| `--data-collection-settings` | `is_preview` | **GA** | Graduated |
| `--enable-high-log-scale-mode` | `is_preview` | **GA** | Graduated |
| `--ampls-resource-id` | `is_preview` | **GA** | Graduated; private cluster + MSI only |
| `--workspace-resource-id` | supported | supported | Identical |
| `--enable-cost-analysis` | store_true | store_true | Identical |
| `--enable-azure-monitor-metrics` | store_true | store_true | Managed Prometheus (metrics, not logs) |

## By focus area

**Enabling monitoring** — Core uses `--enable-addons monitoring` only. aks-preview adds extension-only aliases `--enable-azure-monitor-logs` / `--disable-azure-monitor-logs` (not preview-flagged; guarded by `validate_azure_monitor_logs_and_enable_addons` on create and `validate_azure_monitor_logs_enable_disable` on update). Same downstream behavior.

**DCR / DCRA + MSI** — `--enable-msi-auth-for-monitoring` is GA in core, `is_preview` in ext. Actual DCR/DCRA/DCE creation lives in shared `ensure_container_insights_for_monitoring(create_dcr=True, create_dcra=True)`. DCR API `2022-06-01`; DCR name `MSCI-<region>-<cluster>`. Syslog and data-collection-settings are rejected without MSI auth.

**Log collection settings** — `--enable-high-log-scale-mode` (swaps `Microsoft-ContainerLogV2` → `-HighScale`, creates ingestion DCE; auto-enabled by `--enable-container-network-logs`), `--ampls-resource-id` (private cluster + MSI only, links workspace + DCE to AMPLS), `--data-collection-settings` (parsed + `validate_data_collection_settings()`). GA in core, `is_preview` in ext.

**Cost presets** — Preset JSON via `--data-collection-settings`. Keys: `interval`, `namespaceFilteringMode`, `namespaces`, `enableContainerLogV2`, `streams`. Defaults `enableContainerLogV2=true` when omitted. `--enable-cost-analysis` (namespace/deployment cost views) identical both sides.

**Syslog** — `--enable-syslog` GA in core, `is_preview` in ext. Requires MSI auth. Builds `Microsoft-Syslog` data source (20 facilities × 8 log levels) into the DCR.

## Provisioning flow (shared)

```
--enable-azure-monitor-logs (preview)  ─┐
--enable-addons monitoring (core)      ─┴─> enable monitoring addon
   └─> MSI auth?
        ├─ No  ─> legacy solution route (syslog & DCS rejected)
        └─ Yes ─> ensure_container_insights_for_monitoring (shared acs engine)
                   ├─ --enable-high-log-scale-mode? ─> create ingestion DCE
                   ├─ --data-collection-settings?   ─> parse + validate presets
                   │                                   else default enableContainerLogV2=true
                   ├─ --ampls-resource-id?          ─> config DCE + link to AMPLS (private only)
                   └─> create DCR (api 2022-06-01, +syslog source if --enable-syslog)
                        └─> create DCR Association (DCR ⇄ cluster)
                             └─> logs flowing to Log Analytics workspace
```

## ContainerInsights streams (13, identical both sides)

`Microsoft-ContainerLog`, `Microsoft-ContainerLogV2-HighScale`, `Microsoft-KubeEvents`, `Microsoft-KubePodInventory`, `Microsoft-KubeNodeInventory`, `Microsoft-KubePVInventory`, `Microsoft-KubeServices`, `Microsoft-KubeMonAgentEvents`, `Microsoft-InsightsMetrics`, `Microsoft-ContainerInventory`, `Microsoft-ContainerNodeInventory`, `Microsoft-Perf`, `Microsoft-ContainerNetworkLogs`

## Notes

- **Stale preview labels** — the five graduated flags are still `is_preview=True` in aks-preview.
- **Redundant override** — aks-preview monkey-patches `ContainerInsightsStreams`, but the value is now identical to the acs canonical list (dead override).
- **Scope** — this compares CLI surface only; ARM/REST api-versions (`Microsoft.ContainerService`, `Microsoft.Insights` DCR) are a separate axis. The `azuremonitormetrics/constants.py` API versions belong to the metrics path, not logs.
- **Verify** — GA facts read from azure-cli `dev` branch; confirm against your pinned CLI release before relying on them.

## Sources

- aks-preview: `src/aks-preview/azext_aks_preview/_params.py` (L826–840, L1600–1795, L3026–3130), `addonconfiguration.py`, `azuremonitormetrics/constants.py`, `setup.py` (VERSION `21.0.0b9`)
- Core: `Azure/azure-cli` dev branch `acs/_params.py` (L506–511, L957–972), `acs/addonconfiguration.py`
