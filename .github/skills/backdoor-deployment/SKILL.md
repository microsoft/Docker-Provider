---
name: backdoor-deployment
description: "Validate a container image change via backdoor deployment. Use when: deploying test image to a cluster, comparing data volume between deployments, comparing resource consumption, backdoor deploy, validate container image, image regression testing, build and deploy branch. Requires kusto-mcp MCP server."
argument-hint: "Provide branch name, Log Analytics workspace resource ID, cluster resource ID, current production image, and YAML file path"
---

# Backdoor Deployment Automation

Validates a container image change by checking for (or triggering) a build on a branch, deploying the current production image while waiting, collecting baseline data, then deploying the new image and comparing data volume and resource consumption.

## Required Inputs

The user provides these values. Ask for any that are missing before starting.

| Input | Description | Example |
|-------|-------------|---------|
| **Branch name** | Git branch to build | `suyadav/aiautomation` |
| **Cluster resource ID** | Full ARM resource ID of the AKS cluster | `/subscriptions/6e377996-dbe0-4f90-aeee-e1592d1d7c0d/resourceGroups/otel-test/providers/Microsoft.ContainerService/managedClusters/trivytest` |
| **Log Analytics workspace resource ID** | Full ARM resource ID | `/subscriptions/6e377996-dbe0-4f90-aeee-e1592d1d7c0d/resourcegroups/otel-test/providers/microsoft.operationalinsights/workspaces/otel-law` |
| **Current production image** | Image tag currently in production | `ciprod:3.1.35` |
| **YAML file path** | Path to the backdoor deployment YAML | `"./../azuremonitor-containerinsights-for-prod-clusters/values.yaml"` |

## Derived Values

Parse these automatically from the inputs — do not ask the user.

- **Subscription ID**: parsed from workspace resource ID
- **Resource Group**: parsed from workspace resource ID
- **Log Analytics Workspace Name**: parsed from workspace resource ID
- **Cluster Name**: parsed from cluster resource ID (last segment) — used for `kubectl config use-context`
- **Kusto Service URL**: *(optional — only needed if kusto-mcp requires it)*

## Build Pipeline

| Field | Value |
|-------|-------|
| Organization | github-private |
| Project | microsoft |
| Build Definition ID | 444 |

## General Rules

- Save the output of **each step** to `BackdoorDeploymentOutput.md` in the workspace. Always append new results at the end in ascending order. Beautify for readability. Don't clear until explicitly asked.
- If asked **"what's the next step"**, read `BackdoorDeploymentOutput.md` and suggest the next step.
- Before executing any step, verify previous step data exists in `BackdoorDeploymentOutput.md`. If missing, confirm with the user before proceeding.
- If the build must be retriggered, **keep the existing production baseline data** — do not re-deploy the production image or re-collect baseline data.

## Procedures

### How to Update the YAML File for a Given Image

1. Just update the image version in the YAML file. Do NOT change any other part of the file or it may cause unintended consequences.
2. The tags that need to be updated are `imageTagLinux` and `imageTagWindows`.
3. Windows image naming: if the imageversion is `cidev:3.1.27-2-123a1c9436-20250520184627`, the windows version is `cidev:win-3.1.27-2-123a1c9436-20250520184627`. Similarly, `ciprod:3.1.27` → `ciprod:win-3.1.27`.

### How to Collect Table Data

Collect aggregated row counts in 1-minute intervals from **(deployment time + 5 min)** to **(deployment time + 10 min)** for these tables:
- `ContainerInventory`
- `KubeNodeInventory`
- `KubePodInventory`
- `InsightsMetrics`
- `Perf`
- `ContainerLogV2`

Apply filter `_ResourceId =~ <Cluster ResourceId>` before aggregating.

Save results in a table: `Table Name, Deployment (prod/test), Time, Count`.

### How to Compare Data Volume

1. For each table, compare the production vs test aggregated counts side by side.
2. For `ContainerInventory`, `KubeNodeInventory`, `KubePodInventory`, `InsightsMetrics`, `Perf`: if the count differs **even by 1** (excluding first/last minute edge windows), investigate the discrepancy.
3. For `ContainerLogV2`: exact count match not required, but check for upward/downward trends indicating regression.

### How to Get PodUid

Query `KubePodInventory` for each pod in both deployments. Run in the production deployment window for production pods, test deployment window for test pods:
```kusto
KubePodInventory
| where TimeGenerated > ago(24h)
| where _ResourceId =~ <clusterResourceId>
| where Name in (<podlist>)
| distinct PodUid, Name
```
Save results in a table: `Deployment (prod/test), PodName, PodUid`.

### How to Compare Resource Consumption

1. Query per-minute resource consumption for each PodUid (no join operation):
```kusto
Perf
| where TimeGenerated > ago(24h)
| where _ResourceId =~ <clusterResourceId>
| where CounterName =~ <counterName>
| where InstanceName contains <podUid>
| summarize max(CounterValue/1000/1000/1000) by bin(TimeGenerated, 1m)
| render timechart
```
2. Compare for regression between deployments.
3. Save in 2 tables (one per deployment): `Time, Pod name, Value`. Sort by pod name.

### How to Get Current UTC Time

Run: `date -u '+%Y-%m-%d %H:%M:%SZ'`

### How to Extract Image Version from Build Logs

1. Download the build logs zip file into the workspace.
2. Read the zip → go to the `build_linux` folder → read "ORAS Push Artifacts" → extract the image version. Example full path:
   `containerinsightsprod.azurecr.io/public/azuremonitor/containerinsights/cidev:3.1.27-2-123a1c9436-20250520184627`
   The image version is: `cidev:3.1.27-2-123a1c9436-20250520184627`
3. Delete the downloaded zip and extracted folder after extraction.

## Steps

The workflow has two parallel tracks that converge after the build completes.

### Phase 1: Obtain Build + Deploy Production Image (parallel)

1. Parse the **Log Analytics workspace resource ID** to derive subscription ID, resource group, and workspace name. Parse the **cluster resource ID** to derive the cluster name. Save all derived values to the output file.
2. Set kubectl context: `kubectl config use-context <cluster name>`.
3. **Check for an existing completed build** on the given branch for the **latest commit** using build definition ID 444 (organization: `github-private`, project: `microsoft`). Use any available method (ADO API, `az pipelines` CLI, or MCP).
   - If a completed build exists on the latest commit → use it. Save the build ID and note it was reused.
   - If no completed build exists → **trigger a new build** on the branch. Save the build ID.
4. **If the build is already complete**, skip to Phase 2 after finishing the production baseline steps. **If the build is still running**, proceed with steps 5–10 in parallel. Periodically check build status during wait times.
5. Update the YAML file with the **current production image** (see "How to Update the YAML File").
6. Deploy: `helm upgrade ama-logs ./../azuremonitor-containerinsights-for-prod-clusters/ -n kube-system`.
7. Note current UTC time → this is the **production deployment time**. Save to output file.
8. Wait/sleep 15 minutes to allow all pods to start.
9. Verify pods: `kubectl get pods -A | grep ama-logs`. Confirm all are Running. Save pod names to output file.
10. Wait until deployment time + 10 minutes has passed, then **collect baseline data** for all tables (see "How to Collect Table Data"). Save results to output file. This is the **production baseline**.

### Phase 2: Deploy Test Image + Compare (after build completes)

11. Confirm the build completed successfully. If it failed, report the failure and ask the user whether to retrigger (the production baseline data is preserved for reuse).
12. Extract the new image version from the build logs (see "How to Extract Image Version from Build Logs"). Save to output file.
13. Update the YAML file with the **new test image version**.
14. Deploy: `helm upgrade ama-logs ./../azuremonitor-containerinsights-for-prod-clusters/ -n kube-system`.
15. Note current UTC time → this is the **test deployment time**. Save to output file.
16. Wait/sleep 15 minutes to allow all pods to start.
17. List ama-logs pods. Verify all are Running. If any restarted, get reason via `kubectl describe`. Save to output file.
18. Wait until test deployment time + 10 minutes has passed, then **collect test data** for all tables (see "How to Collect Table Data"). Save to output file.

### Phase 3: Compare Results

19. Compare data volume between production and test deployments for all tables (see "How to Compare Data Volume").
20. Get PodUid for all pods in both deployments (see "How to Get PodUid").
21. Compare resource consumption for `memoryWorkingSetBytes` (see "How to Compare Resource Consumption").
22. Compare resource consumption for `cpuUsageNanoCores` (see "How to Compare Resource Consumption").
23. Write a **summary** to the output file: pass/fail for each table comparison and resource consumption check. Flag any regressions.
