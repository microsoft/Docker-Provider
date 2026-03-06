# Bug Fix

## Description
Structured workflow for fixing bugs in the Docker-Provider agent.

USE FOR: fix bug, resolve issue, hotfix, patch, debug, error fix
DO NOT USE FOR: feature development, refactoring without behavior change, performance optimization

## Instructions

### When to Apply
When a bug is reported in container log collection, inventory, metrics, or agent behavior.

### Step-by-Step Procedure
1. **Reproduce**: Identify the code path — check `CONTROLLER_TYPE` (DaemonSet vs ReplicaSet) and `OS_TYPE` (Linux vs Windows) to narrow scope.
2. **Locate**: Trace the issue through the data flow:
   - Log collection: `source/plugins/go/src/oms.go` → `out_oms.go`
   - Inventory: `source/plugins/ruby/in_kube_*.rb` or `source/plugins/go/input/`
   - Metrics/MDM: `source/plugins/ruby/filter_*2mdm.rb` → `out_mdm.rb`
   - Startup/config: `kubernetes/linux/main.sh` or `kubernetes/linux/setup.sh`
3. **Fix**: Apply the minimal change that addresses the root cause.
4. **Test**: Add a regression test in the appropriate framework.
5. **Verify**: Run the relevant unit test suite.
6. **Telemetry**: Ensure error paths have `ApplicationInsightsUtility.sendExceptionTelemetry` (Ruby) or `appinsights.TrackException` (Go) calls.

### Files Typically Involved
- `source/plugins/go/src/*.go` — Go plugin logic
- `source/plugins/ruby/*.rb` — Ruby plugin logic
- `kubernetes/linux/main.sh`, `kubernetes/linux/setup.sh` — Container entrypoints
- Corresponding test files

### Validation
- Relevant unit test suite passes
- Docker image builds successfully
- No regression in existing test coverage

## Examples from This Repo
- `cfcc530` — fix: bleu cloud name is azurebleucloud (#1598)
- `5c0bca0` — bug fix (#1593)
- `fbcc3de` — fix bug (#1577)

## References
- `source/plugins/ruby/omslog.rb` — Logging utility
- `source/plugins/go/src/telemetry.go` — Go telemetry patterns
