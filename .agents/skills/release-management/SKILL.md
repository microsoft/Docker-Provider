# Release Management

## Description
Prepare and publish new releases of the monitoring agent — update version numbers, release notes, chart versions, and container image tags.

USE FOR: release, version bump, release notes, chart update, image tag update, publish new version
DO NOT USE FOR: feature development, bug fixes, CI/CD pipeline changes

## Instructions

### When to Apply
When preparing a new release of Azure Monitor Container Insights agent (e.g., 3.1.x releases).

### Step-by-Step Procedure
1. Update `build/version` with new `CONTAINER_BUILDVERSION_*` values.
2. Add release notes section to `ReleaseNotes.md` with:
   - Version number and date
   - List of changes (features, bug fixes, CVE fixes)
   - Image tag information
3. Update Helm chart version in `charts/azuremonitor-containers/Chart.yaml`.
4. Update image tags in:
   - `charts/azuremonitor-containers/values.yaml`
   - `charts/azuremonitor-containers-geneva/values.yaml`
   - `kubernetes/ama-logs.yaml`
   - `kubernetes/linux/Dockerfile.multiarch` (if base image changes)
   - `kubernetes/windows/Dockerfile` (if base image changes)
5. Verify Helm chart renders: `helm template charts/azuremonitor-containers/`
6. Submit PR to `ci_prod` branch.

### Files Typically Involved
- `ReleaseNotes.md`
- `build/version`
- `charts/azuremonitor-containers/Chart.yaml`
- `charts/azuremonitor-containers/values.yaml`
- `charts/azuremonitor-containers-geneva/values.yaml`
- `kubernetes/ama-logs.yaml`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`

### Validation
- `helm template charts/azuremonitor-containers/` renders without errors
- Image tags in values files match across all chart variants
- Release notes are well-formatted and accurate
- Version numbers are consistent across all files

## Examples from This Repo
- `7410ab3a9` — release notes for 3.1.35 (#1608)
- `d30c2c4ad` — 3.1.34 release notes and chart update (#1603)
- `c6cbc783b` — 3.1.32 release note and chart update (#1583)
- `4c51dfef5` — 3.1.30 Release notes and chart changes (#1537)
- `a8670cfb7` — 3.1.29 release notes and version updates (#1524)

## References
- `build/version` — Version numbers
- `ReleaseNotes.md` — Release history
- `charts/` — Helm charts
