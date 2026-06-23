# ama-logs independent AKS extension-based release (WIP)

This document describes the in-progress migration of the Container Insights logs agent
(`ama-logs`) to an **independent, extension-based release on AKS** — owning the Safe
Deployment Process (SDP) to customer clusters ourselves, instead of releasing through the
AKS team. It mirrors prometheus-collector's `aks/extension-charts` work.

> Scope is **AKS only** for now. Arc continues to use the existing rollout
> (`deployment/arc-k8s-extension*`). Modernizing the Arc rollout to the same
> central-artifacts model is a possible later step, out of scope here.

## Why
Today the AKS logs agent ships via **AgentBaker** (image baked into the AKS node VHD) +
a version bump in **aks-rp**, then rolls out on **AKS's** release train. We do not control
the cadence or region waves. The target model delivers `ama-logs` as a **cluster extension
chart published to MCR**; the AKS cluster-extension platform auto-installs/upgrades it, and
**our** pipeline owns the version, cadence and SDP waves — the same model the metrics
(ama-metrics) agent already uses.

See the session migration analysis for the full background (two delivery models:
AgentBaker+RP vs MCR-chart+extension).

## Components added in this repo
| Artifact | Purpose |
|---|---|
| `charts/azuremonitor-containers-extension/` | New parallel Helm chart delivering `ama-logs` as an **AKS managed-cluster extension**. Existing `charts/azuremonitor-containers` is untouched. |
| `.pipelines/azure-pipeline-aks-extension-managed-ev2-sdp.yml` | Central-artifacts Ev2 Managed-SDP rollout of `microsoft.azuremonitor.containers` to **AKS Managed** clusters. |
| `package_extension_chart` job in `azure_pipeline_mergedbranches.yaml` | Packages + pushes the extension chart to MCR. Gated on `BUILD_EXTENSION_CHART=true` during incubation. |

## End-to-end flow (target)
1. Build (`azure_pipeline_mergedbranches.yaml`) builds multi-arch images and, with
   `BUILD_EXTENSION_CHART=true`, packages + pushes the chart to MCR (`ama-logs`).
2. Images are promoted to prod MCR by the existing agent Ev2 release.
3. The AKS extension rollout pipeline registers the new chart version with the
   cluster-extension platform via **central artifacts** (`Ev2RARollout@2` /
   `CentralArtifactsRollout`), starting in canary (`centraluseuap,eastus2euap`).
4. The platform's **central SDP policy** advances the version region by region
   (Canary -> Pilot -> ... -> HighAvailability) with bake times.
5. The in-cluster extension-manager pulls the chart from MCR and installs/upgrades the
   agent automatically — no AgentBaker, no aks-rp version bump, no manual helm install.

## Per-release version handling
The rollout pipeline defaults the extension version to the upstream build `runName`
(`overrideExtensionVersion` to pin a specific validated build, e.g. for rollback). For
incubation off a feature branch you may pin a known-good `ci-prod` image tag, mirroring
prometheus-collector's `update-extension-dev` skill.

## Cross-team dependency (P0 — gates ACTIVATION, not authoring)
The **ClusterConfig / Cluster-Extensions partner team** must:
- register `microsoft.azuremonitor.containers` as an **AKS managed-cluster extension type**
  (with our `ev2-agent-release` MSI in `msiClientIds`),
- create the AKS **`packageConfig`** name,
- confirm the **`serviceGroup`** name for central rollout.

All such values are marked `TODO(P0)` in the rollout pipeline. Note prometheus-collector
has the same open TODO for AKS — coordinate with the same partner-team contacts.

## Remaining repo work
- Complete the chart template rework (token adapter via values, prune base-chart Arc-only
  resources, schedulability). See
  `charts/azuremonitor-containers-extension/EXTENSION-MIGRATION.md`.
- After validation + P0: cut over, drop the AgentBaker PR + aks-rp version bump, and retire
  the legacy CDPX build files (`.pipelines/pipeline.user.*.yml`, `pull-from-cdpx-*.sh`).
