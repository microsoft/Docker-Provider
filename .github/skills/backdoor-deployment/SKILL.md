---
name: backdoor-deployment
description: "Validate a container image change via backdoor deployment. Use when: deploying test image to a cluster, comparing data volume between deployments, comparing resource consumption, backdoor deploy, validate container image, image regression testing, build and deploy branch."
argument-hint: "Provide branch name and cluster resource ID (production image, chart path, and workspace are auto-detected)"
---

# Backdoor Deployment Automation

Validates a container image change by deploying the current production image, collecting baseline data, then deploying the test image (from a CI build) and comparing data volume and resource consumption. No regressions = pass.

## Required Inputs

Only these two come from the user. Everything else is derived — do not ask for it.

| Input | Description | Default |
|-------|-------------|---------|
| **Branch name** | Git branch to build | `suyadav/aiautomation` |
| **Cluster resource ID** | Full ARM ID of the target AKS cluster | — ask the user |

## Derived Values

Resolve all of these automatically.

| Value | Source |
|-------|--------|
| **Chart path** | Fixed: `charts/azuremonitor-containerinsights` |
| **Current production image** | `ReleaseNotes.md` — see "Determine the current production image" |
| **Cluster Name** | Last segment of the cluster resource ID (for `kubectl config use-context`) |
| **Subscription ID** | Extracted from the cluster resource ID (`/subscriptions/<this>/...`) |
| **Resource Group** | Extracted from the cluster resource ID (`/resourceGroups/<this>/...`) |
| **Region** | `az aks show -g <rg> -n <name> --query location -o tsv` |
| **Kubernetes version** | `kubectl version -o json \| jq -r '.serverVersion.gitVersion' \| sed 's/^v//'` |
| **DCR ID** | The `ContainerInsightsExtension` DCR association on the cluster — see "Resolve the workspace" |
| **Workspace resource ID** | `destinations.logAnalytics[].workspaceResourceId` of that DCR |
| **Workspace GUID** | `customerId` of that workspace (used for `--set OmsAgent.workspaceID` and `az monitor log-analytics query -w`) |

> **The chart carries no cluster coordinates.** `charts/azuremonitor-containerinsights` is the same
> chart CI/CD deploys, and its `values-template.yaml` ships placeholders (`<your_cluster_id>`,
> `<your_workspace_id>`, …) rather than real values, so nothing can be parsed out of it. The cluster
> resource ID comes from the user and the workspace is resolved from the DCR; both are passed as
> `--set` overrides.

## Build Pipeline

| Field | Value |
|-------|-------|
| Organization | `github-private` |
| Project | `microsoft` |
| Build Definition ID | `444` |

## General Rules

- Save the output of **each step** to `BackdoorDeploymentOutput.md` in the repo root. Always append new results at the end. Beautify for readability. Don't clear until explicitly asked.
- If asked **"what's the next step"**, read `BackdoorDeploymentOutput.md` and suggest the next step.
- Before executing any step, verify previous step data exists in `BackdoorDeploymentOutput.md`. If missing, confirm with the user before proceeding.
- If the build must be retriggered, **keep the existing production baseline data** — do not re-deploy the production image or re-collect baseline data.
- After the workflow completes, **redeploy the production image** so the cluster is left on prod, and
  re-enable the managed addon if you disabled it. The generated `Chart.yaml` / `values.yaml` are
  gitignored and may be left in place or deleted — either way the tree stays clean.

## Procedures

### Resolve the workspace

Never ask the user for the workspace. Derive it from the cluster's `ContainerInsightsExtension` DCR
association, which is the workspace the cluster actually ships data to:

```bash
AKS_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<name>"

DCR_ID=$(az monitor data-collection rule association list --resource "$AKS_RESOURCE_ID" \
  --query "[?name=='ContainerInsightsExtension'].dataCollectionRuleId | [0]" -o tsv)

WS_RESOURCE_ID=$(az monitor data-collection rule show --ids "$DCR_ID" \
  --query "destinations.logAnalytics[0].workspaceResourceId" -o tsv)

WS_GUID=$(az monitor log-analytics workspace show --ids "$WS_RESOURCE_ID" --query customerId -o tsv)
```

- `WS_GUID` → `--set OmsAgent.workspaceID` and `az monitor log-analytics query -w`
- `WS_RESOURCE_ID` → needed later to re-enable the addon
- `DCR_ID` → needed later to recreate the association

Resolving from the DCR (rather than guessing a cluster-named workspace) matters: clusters onboarded
without an explicit workspace land in a **regional default** such as
`DefaultWorkspace-<subscription-id>-<region-code>` in resource group `DefaultResourceGroup-<region-code>`,
which bears no relation to the cluster name.

#### If the DCR does not exist yet

`DCR_ID` is empty when Container Insights was never enabled on the cluster. Bootstrap it by enabling
the addon once — that provisions the DCR, the association, and a default workspace — then capture
the values and disable it again before deploying:

```bash
if [ -z "$DCR_ID" ]; then
  # omit --workspace-resource-id to let AKS create/attach the regional default workspace,
  # or pass one explicitly if the user has a preferred workspace
  az aks enable-addons -a monitoring -g <rg> -n <name>

  DCR_ID=$(az monitor data-collection rule association list --resource "$AKS_RESOURCE_ID" \
    --query "[?name=='ContainerInsightsExtension'].dataCollectionRuleId | [0]" -o tsv)
  WS_RESOURCE_ID=$(az monitor data-collection rule show --ids "$DCR_ID" \
    --query "destinations.logAnalytics[0].workspaceResourceId" -o tsv)
  WS_GUID=$(az monitor log-analytics workspace show --ids "$WS_RESOURCE_ID" --query customerId -o tsv)
fi
```

Then continue into the normal flow (disable the addon, recreate the association, deploy). Record
whether the addon was **originally** enabled: if it was never enabled, leave it disabled at cleanup
rather than enabling something the user never had.

This bootstrap also creates the `aad-msi-auth-token` secret that the agent needs for MSI auth, so it
is required even if you only care about the workspace values.

### Determine the current production image

Do **not** hardcode a production tag — it goes stale. Read it from `ReleaseNotes.md` in the repo
root, whose newest entry under `## Release History` is the current production release:

```bash
PROD_TAG=$(grep -m1 -oP 'ciprod:\K[^ ]+(?= \(linux\))' ReleaseNotes.md)
PROD_TAG_WIN=$(grep -m1 -oP 'ciprod:\K[^ ]+(?= \(windows\))' ReleaseNotes.md)
echo "$PROD_TAG / $PROD_TAG_WIN"
# -> 3.8.0-ci-prod-09-03-2026-fd42f68c / win-3.8.0-ci-prod-09-03-2026-fd42f68c
```

`grep -m1` takes the **first** match, and release notes are newest-first, so this always yields the
latest release. The entries look like:

```
### 09/03/2026 -
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.8.0-ci-prod-09-03-2026-fd42f68c (linux)
##### Version mcr.microsoft.com/azuremonitor/containerinsights/ciprod:win-3.8.0-ci-prod-09-03-2026-fd42f68c (windows)
```

These are already **bare tags** in the form this chart expects, and the Windows tag is read directly
rather than derived — use it as-is.

Confirm your branch is not behind on release notes (`git log -1 --format=%cd -- ReleaseNotes.md`). If
the value disagrees with what the cluster is actually running, prefer the live cluster image and tell
the user:

```bash
kubectl get ds ama-logs -n kube-system \
  -o jsonpath='{range .spec.template.spec.containers[?(@.name=="ama-logs")]}{.image}{"\n"}{end}'
```

### Generate the chart (mandatory first step)

`charts/azuremonitor-containerinsights` is **template-only**. It ships `Chart-template.yaml` and
`values-template.yaml`; `Chart.yaml` and `values.yaml` are generated at build time and are
**gitignored** (`.gitignore:36-37`), so generating them is safe and leaves the tree clean.

Running Helm before generating fails with `Error: Chart.yaml file is missing`.

Generate exactly as CI/CD does (`.pipelines/helm-deploy-templates/ama-logs-helm-deploy.yaml`):

```bash
cd charts/azuremonitor-containerinsights
export HELM_SEMVER="<linux-tag>"          # e.g. 3.1.34-17-g67321cf0d-20260323045331
export IMAGE_TAG="<linux-tag>"
export IMAGE_TAG_WINDOWS="<windows-tag>"  # e.g. win-3.1.34-17-g67321cf0d-20260323045331
envsubst '${HELM_SEMVER} ${IMAGE_TAG} ${IMAGE_TAG_WINDOWS}' < Chart-template.yaml > Chart.yaml
envsubst '${HELM_SEMVER} ${IMAGE_TAG} ${IMAGE_TAG_WINDOWS}' < values-template.yaml > values.yaml
```

`envsubst` only expands `${...}`. The `<your_cluster_id>` / `<your_workspace_id>` style placeholders
are **not** substituted and must be passed as `--set` overrides at deploy time (see below).

### Image tags for this chart

The image is assembled as
`mcr.microsoft.com` + `OmsAgent.imageRepository` + `:` + `OmsAgent.imageTagLinux`.

So the tag is the **bare tag**, and the repo (`ciprod` vs `cidev`) is a **separate** value:

| Image | `OmsAgent.imageRepository` | `OmsAgent.imageTagLinux` | `OmsAgent.imageTagWindows` |
|-------|---------------------------|--------------------------|-----------------------------|
| production | `/azuremonitor/containerinsights/ciprod` | `$PROD_TAG` from `ReleaseNotes.md` | `$PROD_TAG_WIN` from `ReleaseNotes.md` |
| **test build** | `/azuremonitor/containerinsights/cidev` | `3.1.34-17-g67321cf0d-20260323045331` | `win-3.1.34-17-g67321cf0d-20260323045331` |

> ⚠️ **Do not use the `cidev:<tag>` form here.** That was the convention for the older
> `azuremonitor-containerinsights-for-prod-clusters` chart. Passing `cidev:3.1.34` as the tag renders
> `…/ciprod:cidev:3.1.34`, which is an invalid reference.

> 🚨 **Silent-fallback footgun — this can invalidate an entire test run.** If `imageTagLinux` /
> `imageTagWindows` are empty or unset, the chart does **not** fail. It silently falls back to the
> hardcoded defaults in `get.addonImageTag` (`templates/_helpers.tpl`): **`3.1.34`** and
> **`win-3.1.34`**. You would then be comparing production against production and conclude "no
> regression". **Always verify the live image after deploying** (see the verification step below).

**Windows naming convention**: prefix `win-` on the Linux tag — e.g.
`3.8.0-ci-prod-09-03-2026-fd42f68c` → `win-3.8.0-ci-prod-09-03-2026-fd42f68c`. For production tags
read the Windows line from `ReleaseNotes.md` directly instead of deriving it; only derive for CI
build tags, where the build log may list the Linux tag alone.

### Deploy with Helm

Deploy with the same override set CI/CD uses. Always use `--install` so the command handles both
fresh installs and upgrades:

```bash
AKS_RESOURCE_ID="/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<name>"

helm upgrade --install ama-logs charts/azuremonitor-containerinsights -n kube-system \
  --set global.commonGlobals.CloudEnvironment=azurepubliccloud \
  --set global.commonGlobals.Region=<region> \
  --set global.commonGlobals.Versions.Kubernetes=<k8s-version> \
  --set Azure.Cluster.ResourceId="$AKS_RESOURCE_ID" \
  --set OmsAgent.aksResourceID="$AKS_RESOURCE_ID" \
  --set OmsAgent.accessTokenSecretName=aad-msi-auth-token \
  --set OmsAgent.workspaceID="$WS_GUID" \
  --set OmsAgent.imageRepository=/azuremonitor/containerinsights/<ciprod|cidev> \
  --set OmsAgent.imageTagLinux=<linux-tag> \
  --set OmsAgent.imageTagWindows=<windows-tag> \
  --timeout 10m
```

Notes:
- **`accessTokenSecretName=aad-msi-auth-token` is required on MSI-auth clusters.** The chart default
  is `ama-logs-secret` (legacy workspace-key auth); leaving the default breaks token acquisition.
- CI/CD additionally passes `--server-side=true --force-conflicts`. Those are **Helm 4** flags —
  the pipeline pins `helmVersionToInstall: 'latest'`. On Helm 3 they fail with
  `Error: unknown flag: --server-side`, so omit them (check with `helm version --short`).
- The namespace is hardcoded to `kube-system` inside the templates.
- The chart renders a `Secret` named **`ama-logs-secret`**, which is a different object from
  `aad-msi-auth-token` — installing does **not** clobber the MSI token secret.
- The chart only **mounts** `container-azm-ms-agentconfig`; it never creates it, so any scenario
  ConfigMap you apply for testing is safe from being overwritten.

### Verify the deployment before collecting data

Because of the silent-fallback behaviour above, confirm the **live** image is the one you intended:

```bash
kubectl get ds ama-logs -n kube-system \
  -o jsonpath='{range .spec.template.spec.containers[?(@.name=="ama-logs")]}{.image}{"\n"}{end}'
kubectl get ds ama-logs-windows -n kube-system \
  -o jsonpath='{range .spec.template.spec.containers[?(@.name=="ama-logs-windows")]}{.image}{"\n"}{end}'
```

Abort and fix the overrides if either does not match the tag under test.

### Dry-run first (recommended)

Validate rendering without touching the cluster:

```bash
helm lint charts/azuremonitor-containerinsights --set global.commonGlobals.Versions.Kubernetes=<k8s-version>
helm template ama-logs charts/azuremonitor-containerinsights -n kube-system <same --set flags> \
  | grep -E '^\s+image: ' | sort -u
```

A correct render produces 9 objects — ClusterRole, ClusterRoleBinding, 2 ConfigMaps
(`container-azm-ms-aks-k8scluster`, `ama-logs-rs-config`), 2 DaemonSets (Linux + Windows),
1 Deployment (replicaset), Secret, ServiceAccount.

### AKS managed addon conflicts

If the target cluster has the **managed Container Insights addon** enabled, it owns the Helm release
`aks-managed-azure-monitor-logs` and reconciles roughly every 20 minutes, reverting any backdoor
install or `kubectl set image`.

Installing on top of it **fails outright** with an ownership error:

```
Error: Unable to continue with install: ServiceAccount "ama-logs" in namespace "kube-system" exists
and cannot be imported into the current release: invalid ownership metadata; annotation validation
error: key "meta.helm.sh/release-name" must equal "ama-logs": current value is
"aks-managed-azure-monitor-logs"
```

So disabling the addon is **mandatory**, not optional. You must already have `DCR_ID` and
`WS_RESOURCE_ID` from "Resolve the workspace" — capture them **before** disabling, because the
disable deletes the association:

```bash
az aks disable-addons -a monitoring -g <rg> -n <name> --yes   # --yes is required (no TTY prompt)

# recreate the association that the disable removed
az monitor data-collection rule association create --name ContainerInsightsExtension \
  --rule-id "$DCR_ID" --resource "$AKS_RESOURCE_ID"
```

The `aad-msi-auth-token` secret **survives** the disable, so MSI auth keeps working.

To restore afterwards — only if the addon was enabled when you started — uninstall your release
first, then re-enable with the workspace the DCR pointed at:

```bash
helm uninstall ama-logs -n kube-system
az aks enable-addons -a monitoring -g <rg> -n <name> --workspace-resource-id "$WS_RESOURCE_ID"
```

Uninstalling first is required: the addon install hits the same ownership error in reverse if your
release still owns `ama-logs`.

> Check the exit code of `az` directly. Piping it into `tail`/`grep` masks failures behind the
> pipeline's exit status, so a wrong workspace name can look like success. Verify by re-reading
> `addonProfiles.omsagent.enabled` and the pod list rather than trusting the command's output.

### Collect Table Data

Run Kusto queries via `az monitor log-analytics query -w "$WS_GUID"` (or the `kusto-mcp` MCP server if available).

Collect aggregated row counts in **1-minute bins** from **(deployment time + 5 min)** to **(deployment time + 10 min)** for these tables:
- `ContainerInventory`
- `KubeNodeInventory`
- `KubePodInventory`
- `InsightsMetrics`
- `Perf`
- `ContainerLogV2`

**Query template** (run once per table, all 6 can run in parallel):
```kusto
<TableName>
| where TimeGenerated between(datetime('<deployTime+5min>') .. datetime('<deployTime+10min>'))
| where _ResourceId =~ '<clusterResourceId>'
| summarize Count=count() by bin(TimeGenerated, 1m)
| order by TimeGenerated asc
```

> **Timing**: Wait at least **15 minutes** after deployment before running these queries — this accounts for pod startup (~5 min) plus Log Analytics ingestion latency (~5–10 min). The query window (deploy+5 to deploy+10) captures steady-state data only.

### Compare Data Volume

1. Compare production vs test counts **side by side** for each table.
2. For `ContainerInventory`, `KubeNodeInventory`, `KubePodInventory`, `InsightsMetrics`, `Perf`: counts must match **exactly** per minute, excluding first/last minute edge windows. If they differ by even 1, investigate.
3. For `ContainerLogV2`: exact match is not required, but check for sustained upward/downward trends indicating regression.

### Check Build Failure Reason

Query the build timeline to find which task(s) failed:
```bash
az devops invoke --organization "https://dev.azure.com/github-private" \
  --area build --resource timeline \
  --route-parameters project=microsoft buildId=<BUILD_ID> \
  --query "records[?result=='failed'].{name:name, type:type}" -o table
```
- If the **only** failed task name contains "Trivy" (vulnerability scan), the build images are valid — continue using this build. **Do NOT fall back to a previous build. Extract the image tag from this build's logs.**
- If any other task failed, the build is unusable — report the failure to the user.

### Extract Image Version from Build Logs

Use the ADO API to read the build log directly (no need to download zip files):

1. **Find the log ID** for the "Multi-arch Linux build" task:
   ```bash
   az devops invoke --organization "https://dev.azure.com/github-private" \
     --area build --resource timeline \
     --route-parameters project=microsoft buildId=<BUILD_ID> \
     --query "records[?name=='Multi-arch Linux build'].{name:name, logId:log.id}" -o json
   ```

2. **Read the log** and extract the image tag. The log contains a line like:
   ```
   ##[warning]Linux image built with tag: containerinsightsprod.azurecr.io/public/azuremonitor/containerinsights/cidev:3.1.34-17-g67321cf0d-20260323045331
   ```
   Extract the **bare tag only** — everything *after* the `cidev:` — because this chart takes the
   repository and the tag as separate values:
   ```bash
   grep -o 'cidev:[^ ]*' <log> | head -1 | cut -d: -f2
   # -> 3.1.34-17-g67321cf0d-20260323045331
   ```
   The `cidev` part becomes `OmsAgent.imageRepository=/azuremonitor/containerinsights/cidev`.

3. **Derive the Windows tag** from the Linux tag using the naming convention (prefix `win-`).
   Alternatively, find "Docker windows build for multi-arc image" log for a line like:
   ```
   ##[warning]Windows image built with tag: ...cidev:win-3.1.34-17-g67321cf0d-20260323045331
   ```

### Get PodUid

Query `KubePodInventory` scoped to the relevant deployment window:
```kusto
KubePodInventory
| where TimeGenerated between(datetime('<windowStart>') .. datetime('<windowEnd>'))
| where _ResourceId =~ '<clusterResourceId>'
| where Name in ('<pod1>', '<pod2>', ...)
| distinct PodUid, Name
```

### Compare Resource Consumption

Query per-minute resource consumption. You can batch multiple pods in one query using `or`:
```kusto
Perf
| where TimeGenerated between(datetime('<windowStart>') .. datetime('<windowEnd>'))
| where _ResourceId =~ '<clusterResourceId>'
| where CounterName =~ '<counterName>'
| where InstanceName contains '<podUid1>' or InstanceName contains '<podUid2>' or ...
| extend Pod = case(
    InstanceName contains '<podUid1>', '<podName1>',
    InstanceName contains '<podUid2>', '<podName2>',
    'unknown')
| summarize MaxValue=max(CounterValue/1000/1000/1000) by bin(TimeGenerated, 1m), Pod
| order by Pod asc, TimeGenerated asc
```

Compare the two counter names:
- `memoryWorkingSetBytes` — memory in GB
- `cpuUsageNanoCores` — CPU in cores

Flag any regression (sustained increase in the test deployment).

### Investigate Data Volume Regression

When a table's counts differ between production and test (or ContainerLogV2 shows a sustained trend), investigate before marking it as a regression:

1. **Break down by ContainerName** in both windows to identify which container(s) are responsible:
   ```kusto
   <TableName>
   | where TimeGenerated between(datetime('<windowStart>') .. datetime('<windowEnd>'))
   | where _ResourceId =~ '<clusterResourceId>'
   | summarize Count=count() by ContainerName
   | sort by Count desc
   ```

2. **Compare the per-container breakdown** between production and test. Look for:
   - Containers present in one window but not the other (cluster workload change, not a code regression).
   - A specific container with significantly higher counts in the test window.

3. **If a container is only present in one window**, verify it was running independently of the deployment by checking a broader time range (e.g., 30 min before the deployment):
   ```kusto
   <TableName>
   | where TimeGenerated between(datetime('<deployTime-30min>') .. datetime('<deployTime>'))
   | where _ResourceId =~ '<clusterResourceId>'
   | where ContainerName == '<suspectContainer>'
   | summarize Count=count() by bin(TimeGenerated, 1m)
   | order by TimeGenerated asc
   ```

4. **Classify the finding**:
   - If the difference is caused by a container that started/stopped independently of the deployment → **not a regression** (cluster workload difference). Note this in the output file and mark as PASS.
   - If the difference is caused by an ama-logs container or directly relates to the code change → **potential regression**. Flag it and ask the user to review.

### Investigate Resource Consumption Regression

When memory or CPU shows a sustained increase in the test deployment:

1. **Check per-container resource usage** within each pod to isolate which container is consuming more. The ama-logs pods run multiple containers (ama-logs, ama-logs-prometheus, addon-token-adapter). Use:
   ```kusto
   Perf
   | where TimeGenerated between(datetime('<windowStart>') .. datetime('<windowEnd>'))
   | where _ResourceId =~ '<clusterResourceId>'
   | where CounterName =~ '<counterName>'
   | where InstanceName contains '<podUid>'
   | summarize MaxValue=max(CounterValue/1000/1000/1000) by bin(TimeGenerated, 1m), InstanceName
   | order by InstanceName asc, TimeGenerated asc
   ```

2. **Compare the per-container breakdown** between production and test to pinpoint the specific container causing the increase.

3. **Classify the finding**:
   - Increases < 10% within normal variance → **not a regression**. Note in output and mark as PASS.
   - Sustained increases ≥ 10% in an ama-logs container → **potential regression**. Flag and ask user to review.

## Steps

The workflow has two parallel tracks that converge after the build completes.

### Phase 1: Obtain Build + Deploy Production Image (parallel)

1. **Collect inputs and derive values** (see Required Inputs and Derived Values tables). Only the
   branch name and cluster resource ID come from the user. Resolve the production image from
   `ReleaseNotes.md` (see "Determine the current production image") and the workspace from the DCR
   (see "Resolve the workspace", including the bootstrap path if no DCR exists yet). Save all values
   to the output file.
2. **Set kubectl context**: `kubectl config use-context <cluster name>`. Then record whether the AKS
   **managed monitoring addon** is enabled — cleanup must put it back the way you found it:
   ```bash
   az aks show -g <rg> -n <name> --query "addonProfiles.omsagent.enabled" -o tsv
   ```
   If `true`, it will revert your backdoor deployment every ~20 minutes — disable it and recreate the
   DCR association (see "AKS managed addon conflicts").
3. **Check for an existing build** on the branch for the **latest commit** (definition ID 444, org: `github-private`, project: `microsoft`).
   - If a completed build exists on the latest commit → use it (even if it failed due to Trivy — see "Check Build Failure Reason").
   - **IMPORTANT: A build that failed ONLY due to Trivy is still usable.** Do NOT fall back to a previous build. The images are already built and pushed before Trivy runs. Always extract the image tag from the failed build's logs (see "Extract Image Version from Build Logs").
   - If no usable build exists → **trigger a new build**. Save the build ID.
4. **If the build is already complete**, skip to Phase 2 after finishing production baseline steps. **If the build is still running**, proceed with steps 5–9 in parallel; periodically check build status during wait times.
5. **Generate the chart and deploy the current production image** (see "Generate the chart", "Image
   tags for this chart", and "Deploy with Helm") using
   `imageRepository=/azuremonitor/containerinsights/ciprod`. **Verify the live image matches the prod
   tag** before continuing (see "Verify the deployment before collecting data"). Record the
   **production deployment time** (UTC).
6. **Wait 15 minutes**, then verify pods: `kubectl get pods -n kube-system | grep ama-logs`. Confirm all are Running with 0 restarts. Save pod names to the output file.
7. **Collect production baseline data** for all 6 tables (see "Collect Table Data"). Save results to the output file.

### Phase 2: Deploy Test Image (after build completes)

8. **Confirm the build** completed. Check failure reason if needed (see "Check Build Failure Reason"). If it failed for a non-Trivy reason, ask the user whether to retrigger. **If it failed only due to Trivy, treat it as a successful build — the images are valid. Do NOT fall back to a previous build.**
9. **Extract the test image version** from the build logs (see "Extract Image Version from Build Logs"). Save to the output file.
10. **Regenerate the chart with the test tags and deploy** using
    `imageRepository=/azuremonitor/containerinsights/cidev` and the bare tags from step 9.
    **Verify the live image matches the test tag** before continuing — the chart silently falls back
    to `3.1.34` if a tag is empty, which would make the comparison meaningless. Record the **test
    deployment time** (UTC).
11. **Wait 15 minutes**, then verify pods are Running. If any pod restarted, get the reason via `kubectl describe pod <name> -n kube-system`. Save pod names to the output file.
12. **Collect test data** for all 6 tables (see "Collect Table Data"). Save results to the output file.

### Phase 3: Compare Results

13. **Compare data volume** between production and test for all tables (see "Compare Data Volume"). If any table shows a difference, **investigate** before reporting (see "Investigate Data Volume Regression").
14. **Get PodUid** for all pods in both deployments (see "Get PodUid").
15. **Compare resource consumption** for `memoryWorkingSetBytes` and `cpuUsageNanoCores` (see "Compare Resource Consumption"). If any metric shows a sustained increase, **investigate** before reporting (see "Investigate Resource Consumption Regression").
16. **Restore the cluster**: `helm uninstall ama-logs -n kube-system`, then put the addon back the
    way you found it (step 2) — re-enable it with `$WS_RESOURCE_ID` if it was originally enabled, or
    leave it disabled if it never was. Confirm 5/5 `ama-logs` pods are Running on the prod image and
    that both `ContainerInsightsExtension` and `ContainerInsightsMetricsExtension` DCR associations
    exist. Delete any test ConfigMaps you applied.
17. **Write summary** to the output file: pass/fail for each table and resource check. Include the
    exact prod and test images **as read back from the live DaemonSets**, not just the intended tags.
    Include investigation findings for any anomalies — clearly distinguish between code regressions
    and cluster workload differences.
