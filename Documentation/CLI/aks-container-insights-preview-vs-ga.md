# AKS Container Insights — Preview vs GA CLI Surface

Comparison of the `aks-preview` extension (`21.0.0b9`) vs core `az aks` (azure-cli `acs` module, dev branch) for Container Insights and log collection.

## TL;DR

The five container-insights capability flags — `--enable-msi-auth-for-monitoring`, `--enable-syslog`, `--data-collection-settings`, `--enable-high-log-scale-mode`, `--ampls-resource-id` — have **graduated to GA** in core `az aks` (registered with no `is_preview`), but `aks-preview` still labels those same five `is_preview=True` (a stale label, not a capability gap). The exception is the convenience aliases `--enable-azure-monitor-logs` / `--disable-azure-monitor-logs`, which are **not in core `az aks` at all** (extension-only). Note these two aliases are *not* preview-flagged in aks-preview — they are simply absent from core. The DCR/DCRA engine, preset validation, and stream list live once in shared `acs.addonconfiguration`, which both surfaces import.

> **What "GA" means here (scope):** this doc compares **Axis 1 — the CLI surface** (which command package registers a flag as preview). "GA" = the flag is registered *without* `is_preview` in the core `acs` module (Azure/azure-cli); "preview" = `is_preview=True` in this `aks-preview` extension. It does **not** assert **Axis 2 — the REST api-version** is GA. The extension's vendored SDK pins the preview api-version `2026-04-02-preview`; end-to-end GA additionally requires the stable api-version that core `az aks` calls to carry the `azureMonitorProfile.containerInsights` field. Axis 2 is out of scope below. The `aks-preview` extension contains only the preview CLI surface — the GA `az aks` command lives in the separate `Azure/azure-cli` repo, and the extension inherits `--enable-addons` and the monitoring params from it.

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
- **Disable caveat (RP source-of-truth)** — the RP treats `azureMonitorProfile.containerInsights.enabled` as the source of truth. `az aks disable-addons -a monitoring` flips only `addonProfiles.omsagent.enabled=false`, leaving `containerInsights.enabled=true`, so the RP may re-enable the addon. aks-preview's `--disable-azure-monitor-logs` clears both surfaces (`_disable_azure_monitor_logs`, `managed_cluster_decorator.py` L8774–8779) and is the reliable disable — but it's an extension-only alias, so core `az aks` users lack it.
- **Scope — two axes** — this compares **Axis 1 (CLI surface / flag preview status)** only. **Axis 2 (REST api-version)** is separate: this extension's vendored SDK talks only to `2026-04-02-preview`, while GA `az aks` calls a stable api-version — the `containerInsights` field must exist there for the migration to be truly GA end-to-end. ARM/REST api-versions (`Microsoft.ContainerService`, `Microsoft.Insights` DCR) and the `azuremonitormetrics/constants.py` versions (metrics path, not logs) are all Axis 2 and out of scope.
- **Verify** — Axis 1 GA status confirmed against released tag **`azure-cli-2.88.0`**: the five flags are registered without `is_preview` in `acs/_params.py` (L507–511 create, L968–972 update), and `aks create`/`aks update` are GA commands (not preview-registered). Axis 2 (REST api-version carrying `containerInsights`) was **not** independently verified.

## Sources

- aks-preview: `src/aks-preview/azext_aks_preview/_params.py` (L826–840, L1600–1795, L3026–3130), `addonconfiguration.py`, `azuremonitormetrics/constants.py`, `setup.py` (VERSION `21.0.0b9`)
- Core: `Azure/azure-cli` released tag `azure-cli-2.88.0` `acs/_params.py` (L507–511, L968–972), `acs/commands.py` (L116–117), `acs/addonconfiguration.py`
