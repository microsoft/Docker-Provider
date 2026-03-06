# Infrastructure

## Description
Guide for modifying Dockerfiles, Helm charts, Kubernetes manifests, and deployment configurations.

USE FOR: update Dockerfile, Helm chart, Kubernetes manifest, deployment config, pipeline
DO NOT USE FOR: application logic changes, test-only changes, documentation

## Instructions

### When to Apply
When modifying container images, Helm charts, Kubernetes deployment manifests, or CI/CD pipelines.

### Step-by-Step Procedure
1. **Dockerfiles**:
   - Linux: Edit `kubernetes/linux/Dockerfile.multiarch`
   - Windows: Edit `kubernetes/windows/Dockerfile`
   - Always use pinned base image tags (not `latest`)
   - Ensure `USER` directive runs as non-root where possible
2. **Helm charts**:
   - Charts are in `charts/azuremonitor-containers/` and `charts/azuremonitor-containers-geneva/`
   - Bump version in `Chart.yaml` for any change
   - Update `values.yaml` for new configuration options
   - Verify templates render correctly: `helm template <chart-dir>`
3. **Kubernetes manifests**:
   - Main manifest: `kubernetes/ama-logs.yaml`
   - Contains DaemonSet, ReplicaSet, ConfigMap definitions
4. **Deployment pipelines**:
   - Azure Pipelines configs in `.pipelines/`
   - GitHub Actions in `.github/workflows/`

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
- `charts/azuremonitor-containers/Chart.yaml`, `charts/azuremonitor-containers/values.yaml`
- `charts/azuremonitor-containers/templates/`
- `kubernetes/ama-logs.yaml`
- `.pipelines/*.yaml`

### Validation
- Docker image builds: `cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test`
- Helm lint: `helm lint charts/azuremonitor-containers/`
- Trivy scan passes (run via PR checker)

## Examples from This Repo
- `a71f549` — Fluent bit 4.0.14 (#1601)
- `090c1dd` — Upgrade Fluent Bit to 4.0.9, add missing dependencies (#1535)
- `a9286fd` — deploy new image to prod clusters using helm chart

## References
- `charts/azuremonitor-containers/Chart.yaml` — Helm chart metadata
- `.github/workflows/pr-checker.yml` — Build and scan workflow
