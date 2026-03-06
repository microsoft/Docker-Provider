# Infrastructure

## Description
Modify Dockerfiles, Helm charts, Kubernetes manifests, or deployment configurations.

USE FOR: update Dockerfile, Helm chart, k8s manifest, deployment config, update base image, change resource limits
DO NOT USE FOR: application logic changes, test changes, documentation

## Instructions

### When to Apply
When modifying container images, Helm charts, Kubernetes deployment manifests, or EV2 deployment configurations.

### Step-by-Step Procedure

1. **Identify the infrastructure component**:
   - Dockerfiles: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
   - Helm charts: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`
   - K8s manifests: `kubernetes/ama-logs.yaml`
   - EV2 deployment: `deployment/arc-k8s-extension*/`
   - Onboarding scripts: `scripts/onboarding/`

2. **Dockerfile changes**:
   - Update base images with specific tags (never use `latest`)
   - Run as non-root where possible
   - Minimize layers; combine related RUN commands
   - Never include secrets in build args or ENV

3. **Helm chart changes**:
   - Update `values.yaml` for new configuration options
   - Update templates in `templates/` directory
   - Bump chart version in `Chart.yaml`
   - Update both `azuremonitor-containers` and `azuremonitor-containers-geneva` if applicable

4. **Kubernetes manifest changes**:
   - Ensure resource limits are set (CPU, memory)
   - Set security contexts (readOnlyRootFilesystem, runAsNonRoot)
   - Verify RBAC roles follow least-privilege

5. **Build and verify**:
   ```bash
   # Build Docker image
   cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test:latest
   # Scan for vulnerabilities
   trivy image --severity CRITICAL,HIGH test:latest
   # Validate Helm chart
   helm lint charts/azuremonitor-containers/
   ```

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch` — Linux multi-arch image
- `kubernetes/windows/Dockerfile` — Windows image
- `kubernetes/ama-logs.yaml` — K8s DaemonSet manifest
- `charts/azuremonitor-containers/` — Helm chart
- `charts/azuremonitor-containers-geneva/` — Geneva Helm chart
- `deployment/` — EV2 deployment configs

### Validation
- Docker image builds successfully
- Trivy scan passes
- Helm lint passes
- Resource limits defined
- Security contexts set
- No secrets in image layers

## Examples from This Repo
- `Fluent bit 4.0.14 (#1601)` — Fluent Bit upgrade in container
- `Upgrade Fluent Bit to 4.0.9 (cloudnative build)... (#1535)` — Major dependency update
- `deploy new image to prod clusters using helm chart` — Helm chart deployment
- `fix amaca liveness probe issue in high scale mode (#1530)` — K8s probe fix
