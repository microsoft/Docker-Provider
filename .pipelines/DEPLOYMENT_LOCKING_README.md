# Deployment Locking - Complete Guide

## Overview

This deployment pipeline prevents concurrent deployments from running on the same cluster using Azure DevOps's `lockBehavior: sequential` feature.

## How It Works

The deployment template uses `lockBehavior: sequential` which automatically queues multiple deployments to ensure only one runs at a time.

```yaml
jobs:
- deployment: Deploy_zane_test
  lockBehavior: sequential  # This provides the locking
  environment: CI-Agent-Dev
```

### Simple Example

```
Pipeline Run #101 → Deploy to "zane-test" → [RUNNING]
Pipeline Run #102 → Deploy to "zane-test" → [QUEUED - waits for #101]
Pipeline Run #103 → Deploy to "zane-test" → [QUEUED - waits for #102]
```

**Key Point:** Works for multiple runs of the same pipeline. Different clusters deploy in parallel (different deployment jobs).

## What Changed in the Code

### Added `lockBehavior: sequential`

```yaml
jobs:
- deployment: Deploy_${{ replace(parameters.clusterName, '-', '_') }}
  
  # Sequential lock behavior prevents concurrent deployments
  lockBehavior: sequential
  
  environment: ${{ parameters.environmentName }}
```

### Lock Logging Steps

- **At start**: Logs deployment lock status
- **At end**: Logs completion (runs `condition: always()`)

**Note:** These steps only log information. The actual locking is done by Azure DevOps `lockBehavior`.

## Lock Behavior

### When No Other Deployment is Running
```
Pipeline requests deployment → Azure DevOps starts immediately → Deployment runs
```
**Time:** Instant

### When Another Deployment is Running
```
Pipeline requests deployment → Azure DevOps queues the job → Waits for previous to complete → Deployment starts
```
**What you'll see:** Job status shows as queued/waiting

### When Deployment Ends (Any Reason)
```
Job completes/fails/cancelled → Azure DevOps releases lock → Next queued deployment starts immediately
```

## Lock Release Times

| Scenario | Release Time |
|----------|--------------|
| Success | Instant |
| Failure | Instant |
| Cancelled | Instant |
| Timeout | Instant |
| Agent crash | ~60 seconds |

**Important:** Lock is ALWAYS released automatically. No manual intervention needed.

## Benefits

✅ **Prevents Conflicts** - One deployment per cluster at a time  
✅ **Automatic Queueing** - Azure DevOps handles everything  
✅ **Zero Setup** - No resources or configuration needed  
✅ **Always Releases** - Even if deployment crashes  
✅ **Parallel Clusters** - Different clusters deploy simultaneously  

## Limitations

⚠️ **Same Pipeline Only** - The `lockBehavior: sequential` only prevents concurrent runs within the **same deployment job definition**

**What this means:**
- ✅ Multiple commits to same pipeline → Queued properly
- ✅ Manual reruns of same pipeline → Queued properly
- ⚠️ Different pipelines deploying to same cluster → May run concurrently

**Example:**
```
Same Pipeline:
Run #101 → zane-test → [RUNNING]
Run #102 → zane-test → [QUEUED] ✓

Different Pipelines:
Pipeline A → zane-test → [RUNNING]
Pipeline B → zane-test → [RUNNING] ⚠️ (if different pipeline definition)
```

For most use cases (same pipeline, multiple commits), this works perfectly!

## Viewing the Queue

**In Azure DevOps:**
1. Go to your pipeline run
2. You'll see queued jobs with status "Waiting" or "Queued"
3. They will start automatically when the previous deployment completes

## Common Questions

### Q: Will this slow down deployments?
**A:** Only if you trigger multiple runs. They will run sequentially instead of concurrently.

### Q: What if deployment fails?
**A:** Lock is released immediately (< 1 second). Next queued deployment starts.

### Q: What if agent crashes?
**A:** Azure DevOps detects this and releases lock within ~60 seconds.

### Q: How long will deployment wait?
**A:** Until the current deployment completes. No timeout by default (can cancel manually).

### Q: Can I cancel a queued deployment?
**A:** Yes, cancel it like any pipeline run.

## Troubleshooting

### Multiple Deployments Running Simultaneously

**Cause:** Different pipelines (not different runs of same pipeline) may run concurrently.

**Solution:** 
- This is a limitation of `lockBehavior` approach
- Each deployment job has its own lock
- To prevent this, all deployments must come from the same pipeline definition

### Pipeline Waiting for Long Time

**Cause:** Another deployment is running and taking time.

**Solution:**
1. Check other pipeline runs to see which is currently deploying
2. Wait for it to complete, or cancel it if needed
3. Your queued deployment will start automatically

## Technical Details

### How lockBehavior Works

- **Type**: Deployment job-level locking
- **Scope**: Per deployment job definition within a pipeline
- **Managed by**: Azure DevOps platform
- **Storage**: Azure DevOps service (cloud-based)

### Lock Mechanism

```
Pipeline Run Request
    ↓
Azure DevOps checks if this deployment job is already running
    ↓
If running → Queue this run
If not running → Start immediately
    ↓
When deployment completes → Start next queued run
```

### Why This Approach?

- ✅ Native platform feature (built into Azure DevOps)
- ✅ Zero configuration - works immediately
- ✅ No resources or permissions needed
- ✅ Guaranteed cleanup (no stuck locks)
- ✅ Simple to understand and use

## Example Timeline

```
16:00 - Run #101 starts → Acquires lock
16:05 - Run #102 starts → QUEUED (Run #101 still running)
16:10 - Run #103 starts → QUEUED (Runs #101, #102 ahead)
16:25 - Run #101 completes → Lock released
16:25 - Run #102 starts immediately → Acquires lock
16:45 - Run #102 completes → Lock released
16:45 - Run #103 starts immediately → Acquires lock
```

## Summary

**The Lock:**
- Azure DevOps deployment job lock
- One lock per deployment job definition
- Managed by Azure DevOps (not your code)

**Acquisition:**
- Automatic when deployment starts
- Queued if same deployment job is running
- FIFO order (first-come, first-served)

**Release:**
- Automatic when deployment ends
- Works for all scenarios (success/failure/crash)
- Fast (<1 second in most cases, ~60 seconds worst case)

**Your Code:**
- Just logs lock status for visibility
- No actual lock management needed

**Limitation:**
- Only locks within same pipeline definition
- Different pipelines may run concurrently on same cluster

---

**Need Help?**
- Check pipeline runs to see if others are queued/running
- Review pipeline logs for lock status messages
- Cancel stuck or unwanted runs manually
- Contact CI/CD team for assistance
