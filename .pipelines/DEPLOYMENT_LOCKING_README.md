# Deployment Locking - Complete Guide

## Overview

This deployment pipeline prevents multiple deployments from running on the same cluster simultaneously, eliminating race conditions and test interference.

## How It Works

### The Lock

When you specify this in the pipeline:
```yaml
environment: 
  name: ${{ parameters.environmentName }}
  resourceName: ${{ parameters.clusterName }}
```

Azure DevOps creates an exclusive lock per cluster. Only one deployment can access each cluster at a time.

### Simple Example

```
Pipeline Run #101 → Deploy to "zane-test" → [RUNNING]
Pipeline Run #102 → Deploy to "zane-test" → [QUEUED - waits for #101]
Pipeline Run #103 → Deploy to "zane-test2" → [RUNNING - different cluster, runs in parallel]
```

**Key Point:** Works for multiple runs of the same pipeline OR different pipelines targeting the same cluster.

## What Changed in the Code

### 1. Environment Resource Specification
**Before:**
```yaml
environment: ${{ parameters.environmentName }}
```

**After:**
```yaml
environment: 
  name: ${{ parameters.environmentName }}
  resourceName: ${{ parameters.clusterName }}  # Creates the lock
```

### 2. Lock Logging Steps
Added two bash steps:
- **At start**: Logs when lock is acquired
- **At end**: Logs when lock is released (runs `condition: always()`)

**Note:** These steps only log information. The actual locking is done by Azure DevOps.

## Lock Behavior

### When Lock is Available
```
Pipeline requests deployment → Azure DevOps grants lock immediately → Deployment starts
```
**Time:** Instant

### When Lock is Held by Another Deployment
```
Pipeline requests deployment → Azure DevOps places in queue → Waits for lock release → Deployment starts
```
**What you'll see:** Status "Waiting for resources"

### When Deployment Ends (Any Reason)
```
Job completes/fails/cancelled → Azure DevOps releases lock immediately → Next queued deployment starts
```

## Lock Release Times

| Scenario | Release Time |
|----------|--------------|
| Success | Instant |
| Failure | Instant |
| Cancelled | Instant |
| Timeout | Instant |
| Agent crash/network failure | ~60 seconds |

**Important:** Lock is ALWAYS released automatically. No manual intervention needed.

## Benefits

✅ **Prevents Conflicts** - One deployment per cluster at a time  
✅ **Automatic Queueing** - Azure DevOps handles everything  
✅ **Works Everywhere** - Same/different pipelines, any trigger type  
✅ **Always Releases** - Even if deployment crashes  
✅ **Parallel Clusters** - Different clusters deploy simultaneously  
✅ **Zero Setup** - No configuration needed  

## Viewing the Queue

**In Azure DevOps:**
1. Go to **Pipelines → Environments**
2. Select your environment (e.g., `CI-Agent-Dev`)
3. See:
   - Active deployments (currently running)
   - Queued deployments (waiting for lock)

## Common Questions

### Q: Will this slow down deployments?
**A:** Only if multiple deployments target the same cluster. Different clusters run in parallel.

### Q: What if deployment fails?
**A:** Lock is released immediately (< 1 second).

### Q: What if agent crashes?
**A:** Azure DevOps detects this and releases lock within ~60 seconds.

### Q: How long will deployment wait?
**A:** Until the current deployment completes. No timeout by default (can cancel manually).

### Q: Can I cancel a queued deployment?
**A:** Yes, cancel it like any pipeline run.

## Troubleshooting

### Pipeline Stuck on "Waiting for resources"
**Cause:** Another deployment is using the cluster.

**Solution:**
1. Check **Pipelines → Environments → [Your Environment]** to see which deployment is running
2. Wait for it to complete, or cancel it if needed

### Multiple Deployments Queued
**Cause:** This is normal if you trigger multiple deployments to the same cluster.

**Solution:** They will run sequentially in order. No action needed.

## Technical Details

### Where is the Lock?
- Stored in Azure DevOps cloud service (not a file or variable)
- Managed entirely by Azure DevOps platform
- Your code only logs status

### How Lock is Acquired
- **Automatic** by Azure DevOps before your steps run
- Based on `resourceName` in environment specification
- Jobs are queued (FIFO) if resource is busy

### How Lock is Released
- **Automatic** by Azure DevOps when job completes
- Works for success, failure, cancellation, or crash
- Next queued job gets lock immediately

### Why This Approach?
- ✅ Native platform feature (built into Azure DevOps)
- ✅ Zero configuration or external dependencies
- ✅ Guaranteed cleanup (no stuck locks)
- ✅ Works across pipelines and agents
- ✅ UI integration for visibility

## Example Timeline

```
16:00 - Run #101 starts → Acquires lock for "zane-test"
16:05 - Run #102 starts → Tries to acquire lock → QUEUED
16:10 - Run #103 starts → Tries to acquire lock → QUEUED
16:25 - Run #101 completes → Lock released
16:25 - Run #102 starts automatically → Acquires lock
16:45 - Run #102 completes → Lock released
16:45 - Run #103 starts automatically → Acquires lock
```

## Summary

**The Lock:**
- Azure DevOps environment resource
- One lock per cluster
- Managed by Azure DevOps (not your code)

**Acquisition:**
- Automatic when deployment starts
- Queued if cluster is busy
- FIFO order (first-come, first-served)

**Release:**
- Automatic when deployment ends
- Works for all scenarios (success/failure/crash)
- Fast (<1 second in most cases, ~60 seconds worst case)

**Your Code:**
- Just logs lock status for visibility
- No actual lock management needed

---

**Need Help?**
- Check environment status in Azure DevOps
- Review pipeline logs for lock messages
- Contact CI/CD team for assistance
