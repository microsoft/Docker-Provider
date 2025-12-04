# CI Agent Auto-Deploy Implementation Plan

## Overview
This document outlines the implementation plan for enabling auto-deployment of CI Agent to a dev cluster on every PR merge to main branch, following the Prom Agent pattern.

**Goal:** Automatically deploy freshly built CI agent images to a dev cluster after each successful build on main branch.

**Pattern:** Based on Prom Agent's `azure-pipeline-build.yml` approach - sequential deployments using `helm upgrade --install`.

---

## Key Findings

### ✅ No Chart Modifications Needed
- **ServiceAccount**: Hardcoded `ama-logs` works fine for sequential deployments
- **Image Tags**: Can be overridden via `--set` flags at deployment time
- **Release Name**: Using same release name (`ama-logs-dev`) for all deployments allows Helm to upgrade in place

### ✅ Prom Agent Pattern
- Uses `helm upgrade --install` with same release name every time
- Deploys to different clusters (not multiple releases per cluster)
- Each cluster has exactly ONE release
- No ServiceAccount conflicts with sequential deployments

---

## Implementation Changes

### 1. Pipeline Modification

**File:** `Docker-Provider/.pipelines/azure_pipeline_mergedbranches.yaml`

**Add Deployment Stage** after existing build stages:

```yaml
- stage: Deploy_Dev_Cluster
  displayName: Deploy to Dev Cluster
  dependsOn: 
    - BuildLinuxImages
    - BuildWindowsImages
  # Only deploy on main branch merges (not PRs)
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  
  jobs:
  - deployment: Deploy_AKS_Chart
    displayName: "Deploy: AKS dev cluster"
    environment: CI-Agent-Dev  # Create this environment in Azure DevOps
    pool:
      name: Azure-Pipelines-CI-Test-EO
    
    variables:
      # Get image tags from build stages
      linuxImageTag: $[ stageDependencies.BuildLinuxImages.Build.outputs['setImageTag.linuxTag'] ]
      windowsImageTag: $[ stageDependencies.BuildWindowsImages.Build.outputs['setImageTag.windowsTag'] ]
    
    strategy:
      runOnce:
        deploy:
          steps:
          - checkout: self
          
          - task: HelmDeploy@0
            displayName: "Deploy to dev cluster"
            inputs:
              connectionType: 'Azure Resource Manager'
              azureSubscription: 'ContainerInsights_Build_Subscription(9b96ebbd-c57a-42d1-bbe9-b69296e4c7fb)'
              azureResourceGroup: 'YOUR-DEV-CLUSTER-RG'
              kubernetesCluster: 'YOUR-DEV-CLUSTER-NAME'
              useClusterAdmin: true
              namespace: 'kube-system'
              command: 'upgrade'
              chartType: 'FilePath'
              chartPath: '$(Build.SourcesDirectory)/charts/azuremonitor-containers/'
              releaseName: 'ama-logs-dev'
              overrideValues: |
                amalogs.image.repo=mcr.microsoft.com/azuremonitor/containerinsights/cidev
                amalogs.image.tag=$(linuxImageTag)
                amalogs.image.tagWindows=$(windowsImageTag)
              arguments: '--install --create-namespace'
```

---

### 2. Ensure Build Stages Export Image Tags

**Verify in BuildLinuxImages stage:**

```yaml
- stage: BuildLinuxImages
  jobs:
  - job: Build
    steps:
    # ... existing build steps ...
    
    # Add this step to export tag
    - script: |
        echo "##vso[task.setvariable variable=linuxTag;isOutput=true]$(IMAGE_TAG)"
      name: setImageTag
      displayName: Export Linux image tag
```

**Verify in BuildWindowsImages stage:**

```yaml
- stage: BuildWindowsImages
  jobs:
  - job: Build
    steps:
    # ... existing build steps ...
    
    # Add this step to export tag
    - script: |
        echo "##vso[task.setvariable variable=windowsTag;isOutput=true]$(IMAGE_TAG)"
      name: setImageTag
      displayName: Export Windows image tag
```

---

### 3. Configuration Updates

**Replace these placeholders with actual values:**

| Placeholder | Description | Example Value |
|-------------|-------------|---------------|
| `YOUR-DEV-CLUSTER-RG` | Resource group containing dev cluster | `ci-dev-aks-rg` |
| `YOUR-DEV-CLUSTER-NAME` | Name of dev AKS cluster | `ci-dev-aks-eus` |

**Optional: Add more overrides for dev-specific configuration:**

```yaml
overrideValues: |
  amalogs.image.repo=mcr.microsoft.com/azuremonitor/containerinsights/cidev
  amalogs.image.tag=$(linuxImageTag)
  amalogs.image.tagWindows=$(windowsImageTag)
  amalogs.secret.wsid=YOUR-DEV-WORKSPACE-ID
  amalogs.secret.key=YOUR-DEV-WORKSPACE-KEY
  amalogs.env.clusterName=ci-dev-cluster
  amalogs.ISTEST=true
```

---

### 4. Azure DevOps Environment Setup

**Create deployment environment:**
1. Navigate to: Azure DevOps → Pipelines → Environments
2. Click "New environment"
3. Name: `CI-Agent-Dev`
4. Resource: None (environment-only)
5. (Optional) Add approval gates if needed

---

## Chart Details - No Modifications Required

### ServiceAccount Handling
- **Current:** Hardcoded as `ama-logs`
- **Works because:** Sequential deployments reuse same ServiceAccount
- **Pattern:** `helm upgrade` updates existing resources, doesn't recreate

### Image Tag Handling
- **Current:** Hardcoded in `values.yaml`
- **Override:** Via `--set` flags at deployment time
- **Files affected:** None (pure runtime override)

### Files with ServiceAccount References (No changes needed)
1. `templates/ama-logs-rbac.yaml` - Creates ServiceAccount `ama-logs`
2. `templates/ama-logs-daemonset.yaml` - References `serviceAccountName: ama-logs`
3. `templates/ama-logs-daemonset-windows.yaml` - References `serviceAccountName: ama-logs`
4. `templates/ama-logs-deployment.yaml` - References `serviceAccountName: ama-logs`

---

## How It Works

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. PR Merged to Main Branch                                │
└─────────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Build Pipeline Triggered                                 │
│    - BuildLinuxImages stage → produces linuxImageTag        │
│    - BuildWindowsImages stage → produces windowsImageTag    │
└─────────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Deploy_Dev_Cluster Stage                                 │
│    - Gets image tags from build stages                      │
│    - Runs: helm upgrade ama-logs-dev --install              │
│    - Overrides: image.tag=$(linuxImageTag)                  │
└─────────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Helm Deployment on Dev Cluster                           │
│    - First run: Creates new release "ama-logs-dev"          │
│    - Subsequent runs: Updates existing release              │
│    - ServiceAccount "ama-logs" reused (no conflicts)        │
└─────────────────────────────────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Dev Cluster Running Latest Build                         │
│    - DaemonSet updated with new image tags                  │
│    - Windows DaemonSet updated with new image tags          │
│    - Deployment (ReplicaSet) updated with new image tags    │
└─────────────────────────────────────────────────────────────┘
```

### Sequential Deployment Example

```bash
# Build 1 - Creates initial deployment
helm upgrade ama-logs-dev ./chart --install \
  --set amalogs.image.tag=3.1.30-20231101 \
  --set amalogs.image.tagWindows=win-3.1.30-20231101
# Result: New release created, ServiceAccount "ama-logs" created

# Build 2 - Updates existing deployment
helm upgrade ama-logs-dev ./chart --install \
  --set amalogs.image.tag=3.1.30-20231102 \
  --set amalogs.image.tagWindows=win-3.1.30-20231102
# Result: Release updated, ServiceAccount "ama-logs" reused ✅

# Build 3 - Updates existing deployment
helm upgrade ama-logs-dev ./chart --install \
  --set amalogs.image.tag=3.1.30-20231103 \
  --set amalogs.image.tagWindows=win-3.1.30-20231103
# Result: Release updated, ServiceAccount "ama-logs" reused ✅
```

---

## Testing Plan

### Pre-Deployment Testing

1. **Validate Chart Templates:**
```bash
cd Docker-Provider/charts/azuremonitor-containers
helm template ama-logs-dev . \
  --set amalogs.image.tag=test-tag \
  --set amalogs.image.tagWindows=test-tag-win \
  --debug
```

2. **Dry Run Deployment:**
```bash
helm upgrade ama-logs-dev . --install \
  --namespace kube-system \
  --set amalogs.image.tag=test-tag \
  --dry-run --debug
```

### Post-Deployment Validation

1. **Check Pipeline Execution:**
   - Verify Deploy_Dev_Cluster stage runs
   - Check image tags are passed correctly
   - Confirm Helm deployment succeeds

2. **Verify Cluster Deployment:**
```bash
# Check pods are running
kubectl get pods -n kube-system | grep ama-logs

# Verify DaemonSet
kubectl describe daemonset ama-logs -n kube-system

# Verify Windows DaemonSet  
kubectl describe daemonset ama-logs-win -n kube-system

# Verify Deployment (ReplicaSet)
kubectl describe deployment ama-logs-rs -n kube-system

# Check image tags match build
kubectl get daemonset ama-logs -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}'
```

3. **Verify ServiceAccount:**
```bash
# Confirm ServiceAccount exists and is used
kubectl get serviceaccount ama-logs -n kube-system
kubectl get pods -n kube-system -l dsName=ama-logs-ds -o jsonpath='{.items[0].spec.serviceAccountName}'
```

---

## Rollback Plan

If deployment fails or causes issues:

### Option 1: Rollback via Helm
```bash
# List releases
helm list -n kube-system

# Rollback to previous version
helm rollback ama-logs-dev -n kube-system
```

### Option 2: Manual Revert
```bash
# Revert to specific image version
helm upgrade ama-logs-dev ./chart --install \
  --set amalogs.image.tag=PREVIOUS-WORKING-TAG \
  --set amalogs.image.tagWindows=PREVIOUS-WORKING-TAG-win
```

### Option 3: Remove Pipeline Stage
- Comment out `Deploy_Dev_Cluster` stage in pipeline
- Commit and push
- Cluster remains at current version

---

## Comparison: CI Agent vs Prom Agent

| Aspect | Prom Agent | CI Agent (This Plan) |
|--------|-----------|---------------------|
| **Chart Changes** | None | None |
| **ServiceAccount** | Hardcoded `ama-metrics-serviceaccount` | Hardcoded `ama-logs` |
| **Deployment Method** | `helm upgrade --install` | `helm upgrade --install` |
| **Release Name** | `ama-metrics` | `ama-logs-dev` |
| **Image Override** | `--set image.tag=...` | `--set amalogs.image.tag=...` |
| **Multiple Versions** | ❌ Not supported | ❌ Not supported (sequential only) |
| **Cluster Strategy** | One release per cluster | One release per cluster |

---

## Estimated Effort

| Task | Effort | Notes |
|------|--------|-------|
| Add deployment stage to pipeline | 30 min | Copy from Prom agent pattern |
| Update cluster name/RG variables | 5 min | Simple config update |
| Create Azure DevOps environment | 5 min | One-time setup |
| Verify build tag exports | 15 min | May already exist |
| Test dry-run deployment | 15 min | Validate before merge |
| Deploy and validate | 30 min | First deployment + verification |
| **Total** | **~2 hours** | Including testing and validation |

---

## Future Enhancements (Optional)

### 1. Add E2E Tests Post-Deployment
Similar to Prom agent's TestKube integration:
```yaml
- job: Run_E2E_Tests
  dependsOn: Deploy_AKS_Chart
  steps:
  - script: kubectl testkube run testsuite ci-agent-e2e-tests
```

### 2. Deploy to Multiple Dev Clusters
Add additional deployment jobs for different regions:
```yaml
- deployment: Deploy_EUS_Cluster
  cluster: ci-dev-aks-eus
  
- deployment: Deploy_WUS_Cluster
  cluster: ci-dev-aks-wus
```

### 3. Slack/Teams Notifications
Notify team of successful deployments:
```yaml
- task: SlackNotification@1
  inputs:
    message: "✅ CI Agent $(linuxImageTag) deployed to dev cluster"
```

---

## References

- **Prom Agent Build Pipeline:** `prometheus-collector/.pipelines/azure-pipeline-build.yml`
- **CI Agent Current Pipeline:** `Docker-Provider/.pipelines/azure_pipeline_mergedbranches.yaml`
- **Helm Chart:** `Docker-Provider/charts/azuremonitor-containers/`
- **Prom Agent Chart:** `prometheus-collector/otelcollector/deploy/addon-chart/azure-monitor-metrics-addon/`

---

## Questions & Answers

### Q: Why not use Release.Name for ServiceAccount?
**A:** Not needed for sequential deployments. Same release name = same ServiceAccount = no conflicts. Only needed for parallel deployments (multiple versions simultaneously).

### Q: Can we deploy multiple versions to same cluster?
**A:** No, with current approach (hardcoded ServiceAccount). Would require chart modifications to use `{{ .Release.Name }}` pattern. Not recommended unless specifically needed.

### Q: What if build fails?
**A:** Deploy stage has `condition: succeeded()` - won't run if build fails. Cluster stays at previous version.

### Q: How to deploy to production?
**A:** This plan is for dev cluster only. Production deployments should continue using existing release pipeline with proper approvals and phased rollouts.

---

## Status

- [x] Research Prom agent pattern
- [x] Document findings
- [x] Create implementation plan
- [ ] Update pipeline with deployment stage
- [ ] Test deployment to dev cluster
- [ ] Validate with team
- [ ] Merge to main branch

---

**Last Updated:** 2025-11-07  
**Author:** Implementation plan based on Prom agent analysis  
**Status:** Ready for implementation
