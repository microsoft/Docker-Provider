# Infrastructure

## Description
Guides changes to container images, Kubernetes manifests, Helm charts, and deployment configurations.

USE FOR: update Dockerfile, modify Helm chart, change Kubernetes manifest, update deployment config, modify container image
DO NOT USE FOR: application logic changes, test changes, documentation-only changes

## Instructions

### When to Apply
When modifying container build, Kubernetes deployment, or Helm chart configurations.

### Step-by-Step Procedure
1. Identify the infrastructure component:
   - Container images: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
   - Kubernetes manifests: `kubernetes/ama-logs.yaml`
   - Helm charts: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`
   - Deployment configs: `deployment/`
   - Onboarding (Bicep/Terraform): `scripts/onboarding/aks/`
2. For Dockerfile changes:
   - Update package versions in `setup.sh` (not directly in Dockerfile where possible)
   - Ensure multi-arch compatibility (amd64 + arm64)
   - Run Trivy scan: `trivy image --severity CRITICAL,HIGH <image>`
3. For Helm chart changes:
   - Update `Chart.yaml` version
   - Update `values.yaml` with new/changed parameters
   - Keep `charts/azuremonitor-containers/` and `charts/azuremonitor-containers-geneva/` in sync where applicable
4. For Kubernetes manifest changes:
   - Update `kubernetes/ama-logs.yaml` (combined DaemonSet + ReplicaSet manifest)
5. Build and scan the container image to verify.

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch` — Linux container image
- `kubernetes/windows/Dockerfile` — Windows container image
- `kubernetes/linux/setup.sh` — Linux container setup script
- `kubernetes/ama-logs.yaml` — Kubernetes deployment manifest
- `charts/azuremonitor-containers/Chart.yaml` — Helm chart metadata
- `charts/azuremonitor-containers/values.yaml` — Helm chart values
- `deployment/` — deployment configurations

### Validation
- Container image builds successfully
- Trivy scan passes
- Helm chart lints without errors: `helm lint charts/azuremonitor-containers/`
- Kubernetes manifest is valid YAML

## Examples from This Repo
- `Fluent bit 4.0.14 (#1601)` — Fluent Bit version upgrade
- `Upgrade Fluent Bit to 4.0.9 (cloudnative build) (#1535)` — infrastructure update
- `deploy new image to prod clusters using helm chart` — deployment change
- `Longw/3.1.35 address vulnerabilties (#1605)` — container image CVE fixes

## References
- `kubernetes/linux/Dockerfile.multiarch` — Linux image definition
- `charts/` — Helm chart directory
