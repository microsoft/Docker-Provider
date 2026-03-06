# Infrastructure

## Description
Modify container images, Kubernetes manifests, Helm charts, or deployment configurations for the Docker-Provider agent.

USE FOR: update Dockerfile, modify Helm chart, change k8s manifest, update deployment config, base image upgrade, Mariner upgrade, RBAC change
DO NOT USE FOR: application logic changes, CI/CD pipeline changes, documentation

## Instructions

### When to Apply
When modifying container build process, Kubernetes deployment manifests, Helm chart values, or Ev2 deployment configurations.

### Step-by-Step Procedure
1. **Identify the infrastructure layer:**
   - **Dockerfiles**: `kubernetes/linux/Dockerfile.multiarch` (Linux), `kubernetes/windows/Dockerfile` (Windows)
   - **Helm charts**: `charts/azuremonitor-containers/` (public), `charts/azuremonitor-containers-geneva/` (Geneva)
   - **K8s manifests**: `kubernetes/ama-logs.yaml`, `kubernetes/container-azm-ms-agentconfig.yaml`
   - **Deployment**: `deployment/` — Ev2 service group definitions for Arc extension releases
   - **Onboarding scripts**: `scripts/onboarding/` — Terraform, Bicep, ARM templates

2. **Follow security best practices:**
   - Containers must run as non-root where possible
   - Set security contexts in Kubernetes manifests
   - Pin base image versions (no `:latest` tags)
   - Minimize installed packages in Dockerfiles

3. **Update version and chart metadata:**
   - Update `build/version` for agent version changes
   - Update Helm chart `Chart.yaml` version and `appVersion`
   - Update `values.yaml` defaults if configuration changes

4. **Consider multi-architecture:**
   - Linux image builds for amd64 and arm64 (`Dockerfile.multiarch`)
   - Ensure build dependencies are available for both architectures

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch` — Linux container image
- `kubernetes/windows/Dockerfile` — Windows container image
- `kubernetes/linux/setup.sh` — Linux image setup (package installation)
- `kubernetes/ama-logs.yaml` — Kubernetes deployment manifest
- `charts/azuremonitor-containers/` — Helm chart
- `deployment/` — Ev2 deployment configs
- `build/version` — Version numbers

### Validation
- Docker image builds for both amd64 and arm64
- Trivy scan passes with no new critical/high CVEs
- Helm chart lints successfully: `helm lint charts/azuremonitor-containers/`
- Kubernetes manifest is valid YAML

## Examples from This Repo
- `8ac2038cc` — Mariner 3 upgrade
- `090c1dd49` — Upgrade Fluent Bit to 4.0.9, add missing dependencies
- `a71f549e0` — Fluent bit 4.0.14
