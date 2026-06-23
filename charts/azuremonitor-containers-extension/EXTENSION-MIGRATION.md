# azuremonitor-containers-extension (ama-logs AKS extension chart)

Parallel, **work-in-progress** Helm chart that delivers the Container Insights logs
agent (`ama-logs`) as an **AKS managed-cluster extension**, via the central-artifacts
Ev2 Managed-SDP rollout (`.pipelines/azure-pipeline-aks-extension-managed-ev2-sdp.yml`).

It is the ama-logs analogue of prometheus-collector's
`otelcollector/deploy/addon-chart/azure-monitor-metrics-addon`.

> Scope is **AKS only** for now. The existing `charts/azuremonitor-containers` chart
> (the live Arc/RP path) is left untouched. This new chart runs in parallel until
> validated and cut over.

## Why a new delivery model
Today the AKS logs agent ships via **AgentBaker** (image baked into the AKS node VHD) +
a version bump in **aks-rp** on AKS's release train. This chart moves it to the
**extension model**: the chart is published to MCR and the AKS cluster-extension platform
auto-installs/upgrades it, with **our** pipeline owning the version, cadence and SDP
region waves. See `Documentation/AgentRelease/extension-release.md` and the session
migration plan.

## What is implemented here (scaffold)
- `Chart-template.yaml` / `values-template.yaml` — envsubst sources; the build stamps
  `${HELM_SEMVER}`, `${IMAGE_TAG}`, `${IMAGE_TAG_WINDOWS}`, `${INCLUDE_DEPENDENT_CHARTS}`.
- `values-template.yaml` additions: `global.commonGlobals`, `Azure.Identity` token-adapter
  placeholders, `IncludeDependentCharts`.

## Remaining work (TODO before activation)
These require the AKS extension values schema (still being finalized on the prometheus
`aks/extension-charts` branch) and confirmation from the ClusterConfig/Extensions partner
team. Use the prom branch chart diff + its `update-extension-dev/SKILL.md` change table as
the spec.

1. **Token adapter via values.** Rework `ama-logs-daemonset.yaml`,
   `ama-logs-daemonset-windows.yaml` and `ama-logs-deployment.yaml` to inject the MSI
   token adapter from `Azure.Identity.AADMsiTokenAdapter{Linux,Windows}Yaml` instead of any
   baked addon-token-adapter.
2. **Prune base-chart Arc-only resources.** This chart was seeded from the Arc-derived
   `azuremonitor-containers` chart. Remove/guard Arc-specific base templates that are not
   needed for AKS (e.g. `ama-logs-arc-k8s-crd.yaml`).
3. **Schedulability.** Re-evaluate `tolerations` / `nodeAffinity` for managed-cluster
   extension constraints (prom removed several `NoExecute`/`PreferNoSchedule` tolerations
   and `nodeSelector` blocks for extension compatibility).
4. **Dependent charts / `global` guards.** If dependent subcharts are added, wrap their
   templates with `{{- if .Values.global }}` guards as prom did for node-exporter.
5. **P0 registration.** Partner team registers `microsoft.azuremonitor.containers` as an
   AKS managed-cluster extension type + AKS `packageConfig` + `serviceGroup`; fill the
   `TODO(P0)` values in `.pipelines/azure-pipeline-aks-extension-managed-ev2-sdp.yml`.

## Local validation
```
wsl bash -c 'cd charts/azuremonitor-containers-extension && \
  IMAGE_TAG=dev IMAGE_TAG_WINDOWS=win-dev HELM_SEMVER=0.0.0-dev INCLUDE_DEPENDENT_CHARTS=false \
  envsubst < Chart-template.yaml > Chart.yaml && \
  envsubst < values-template.yaml > values.yaml && \
  helm lint . && helm template . \
    --set global.commonGlobals.Customer.AzureResourceID=/subscriptions/x/managedClusters/y; \
  rm -f Chart.yaml values.yaml'
```
