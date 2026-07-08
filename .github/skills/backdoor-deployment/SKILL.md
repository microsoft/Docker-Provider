---
name: backdoor-deployment
description: "Validate a container image change via backdoor deployment. Use when: deploying test image to a cluster, comparing data volume between deployments, comparing resource consumption, backdoor deploy, validate container image, image regression testing, build and deploy branch."
argument-hint: "Provide branch name, current production image, and YAML file path"
---

# Backdoor Deployment Automation

Validates a container image change by deploying the current production image, collecting baseline data, then deploying the test image (from a CI build) and comparing data volume and resource consumption. No regressions = pass.

## Required Inputs

Check with the user if they want to use the default values or provide new ones.

| Input | Description | Default |
|-------|-------------|---------|
| **Branch name** | Git branch to build | `suyadav/aiautomation` |
| **Current production image** | Production image tag (e.g. `ciprod:X.Y.Z`) | `ciprod:3.1.35` |
| **YAML file path** | Helm values file for backdoor deployment | `./../azuremonitor-containerinsights/values.yaml` |

## Derived Values

Parse these automatically from the YAML file — do not ask the user.

| Value | Source |
|-------|--------|
| **Cluster Resource ID** | `OmsAgent.aksResourceID` |
| **Log Analytics Workspace ID** | `OmsAgent.workspaceID` (a GUID used with `az monitor log-analytics query -w`) |
| **Cluster Name** | Last segment of the cluster resource ID (for `kubectl config use-context`) |
| **Subscription ID** | Extracted from the cluster resource ID (`/subscriptions/<this>/...`) |
| **Resource Group** | Extracted from the cluster resource ID (`/resourceGroups/<this>/...`) |

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
- After the workflow completes, **restore the YAML file** to its original production image values.

## Procedures

### Update YAML Image Tags

1. Only update the image version — do NOT change any other part of the file.
2. Update exactly two fields: `imageTagLinux` and `imageTagWindows`.
3. **Windows naming convention**: prefix `win-` after the image type. Examples:
   - `cidev:3.1.27-2-abc123-20250520184627` → `cidev:win-3.1.27-2-abc123-20250520184627`
   - `ciprod:3.1.27` → `ciprod:win-3.1.27`

### Deploy with Helm

Always use `--install` to handle both fresh installs and upgrades:
```bash
helm upgrade --install ama-logs <chart-path> -n kube-system
```
where `<chart-path>` is the directory containing the YAML (e.g. `./../azuremonitor-containerinsights/`).

### Collect Table Data

Run Kusto queries via `az monitor log-analytics query -w <workspaceId>` (or the `kusto-mcp` MCP server if available).

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
   Use `grep -o 'cidev:[^ ]*'` or similar to extract the tag.

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

1. **Parse derived values** from the YAML file (see Derived Values table). Save all values to the output file.
2. **Set kubectl context**: `kubectl config use-context <cluster name>`.
3. **Check for an existing build** on the branch for the **latest commit** (definition ID 444, org: `github-private`, project: `microsoft`).
   - If a completed build exists on the latest commit → use it (even if it failed due to Trivy — see "Check Build Failure Reason").
   - **IMPORTANT: A build that failed ONLY due to Trivy is still usable.** Do NOT fall back to a previous build. The images are already built and pushed before Trivy runs. Always extract the image tag from the failed build's logs (see "Extract Image Version from Build Logs").
   - If no usable build exists → **trigger a new build**. Save the build ID.
4. **If the build is already complete**, skip to Phase 2 after finishing production baseline steps. **If the build is still running**, proceed with steps 5–9 in parallel; periodically check build status during wait times.
5. **Update YAML** with the current production image and **deploy** (see "Update YAML Image Tags" and "Deploy with Helm"). Record the **production deployment time** (UTC).
6. **Wait 15 minutes**, then verify pods: `kubectl get pods -n kube-system | grep ama-logs`. Confirm all are Running with 0 restarts. Save pod names to the output file.
7. **Collect production baseline data** for all 6 tables (see "Collect Table Data"). Save results to the output file.

### Phase 2: Deploy Test Image (after build completes)

8. **Confirm the build** completed. Check failure reason if needed (see "Check Build Failure Reason"). If it failed for a non-Trivy reason, ask the user whether to retrigger. **If it failed only due to Trivy, treat it as a successful build — the images are valid. Do NOT fall back to a previous build.**
9. **Extract the test image version** from the build logs (see "Extract Image Version from Build Logs"). Save to the output file.
10. **Update YAML** with the test image and **deploy**. Record the **test deployment time** (UTC).
11. **Wait 15 minutes**, then verify pods are Running. If any pod restarted, get the reason via `kubectl describe pod <name> -n kube-system`. Save pod names to the output file.
12. **Collect test data** for all 6 tables (see "Collect Table Data"). Save results to the output file.

### Phase 3: Compare Results

13. **Compare data volume** between production and test for all tables (see "Compare Data Volume"). If any table shows a difference, **investigate** before reporting (see "Investigate Data Volume Regression").
14. **Get PodUid** for all pods in both deployments (see "Get PodUid").
15. **Compare resource consumption** for `memoryWorkingSetBytes` and `cpuUsageNanoCores` (see "Compare Resource Consumption"). If any metric shows a sustained increase, **investigate** before reporting (see "Investigate Resource Consumption Regression").
16. **Restore YAML** to its original production image values.
17. **Write summary** to the output file: pass/fail for each table and resource check. Include investigation findings for any anomalies — clearly distinguish between code regressions and cluster workload differences.
