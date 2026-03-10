# Bug Fix

## Description

Structured workflow for fixing bugs in the Docker-Provider agent.

USE FOR: fix bug, resolve issue, patch, hotfix, debug, error fix
DO NOT USE FOR: feature development, refactoring, performance optimization

## Instructions

### When to Apply

When a bug is reported or discovered in container log collection, Kubernetes inventory, metrics, or agent startup.

### Step-by-Step Procedure

1. **Reproduce:** Identify the affected component (Go plugin, Ruby plugin, startup script, Helm config).
2. **Locate:** Find the relevant source file. Use directory mapping:
   - Log collection issues → `source/plugins/go/src/oms.go`
   - Kubernetes inventory → `source/plugins/ruby/in_kube_*.rb`
   - Startup failures → `kubernetes/linux/main.sh` or `kubernetes/windows/main.ps1`
   - Configuration → `charts/*/templates/` or `build/linux/installer/conf/`
3. **Fix:** Apply the minimal change to resolve the issue.
4. **Add regression test:** Write a test that would have caught this bug.
5. **Test:** Run the appropriate test suite for the language.
6. **Commit:** Use descriptive message, e.g., `fix amaca liveness probe issue in high scale mode (#1530)`.

### Files Typically Involved

- `source/plugins/go/src/*.go` — Go plugin bugs
- `source/plugins/ruby/*.rb` — Ruby plugin bugs
- `kubernetes/linux/main.sh` — Linux startup bugs
- `kubernetes/windows/main.ps1` — Windows startup bugs

### Validation

- Unit tests pass, regression test added, build succeeds.

## Examples from This Repo

- `5c0bca0bb` — bug fix (#1593)
- `41e880633` — fix amaca liveness probe issue in high scale mode (#1530)
- `8867998cf` — Fixed containerInventory image issue for digest image format (#1374)
