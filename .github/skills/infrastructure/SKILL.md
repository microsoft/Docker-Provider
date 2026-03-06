# Infrastructure

## Description
Modify container images, Kubernetes manifests, Helm charts, or build infrastructure.

USE FOR: update Dockerfile, modify Helm chart, change Kubernetes manifest, upgrade base image, update Fluent Bit, upgrade Telegraf, Mariner upgrade
DO NOT USE FOR: application logic changes, unit test changes, documentation-only updates

## Instructions

### When to Apply
When changing container build infrastructure, base images, system packages, Kubernetes deployment manifests, or Helm charts.

### Step-by-Step Procedure
1. **Identify the infrastructure component:**
   - Dockerfiles: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
   - Helm charts: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`
   - K8s manifests: `kubernetes/ama-logs.yaml`
   - Build system: `build/linux/Makefile`, `build/windows/Makefile.ps1`

2. **For Dockerfile changes:**
   - Maintain Azure Linux 3.0 (Mariner) as base image
   - Use multi-stage builds (golang-builder → builder → distroless)
   - Minimize installed packages — document justification for new packages
   - Ensure final image uses distroless base

3. **For Helm chart changes:**
   - Bump version in `Chart.yaml`
   - Update `values.yaml` if new configuration added
   - Update templates if manifest structure changes

4. **Build and scan:**
   ```bash
   cd build/linux && make
   cd kubernetes/linux && docker build . --file Dockerfile.multiarch -t test:latest
   trivy image --severity CRITICAL,HIGH test:latest
   ```

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch` — Linux container image
- `kubernetes/linux/setup.sh` — Package installation and configuration
- `kubernetes/linux/main.sh` — Container entrypoint
- `charts/azuremonitor-containers/Chart.yaml` — Chart version
- `charts/azuremonitor-containers/values.yaml` — Default values
- `kubernetes/ama-logs.yaml` — Kubernetes deployment manifest

### Validation
- Docker image builds for both amd64 and arm64
- Trivy scan passes with no new CRITICAL/HIGH vulnerabilities
- Helm chart lints: `helm lint charts/azuremonitor-containers/`
- Unit tests still pass after infrastructure changes

## Examples from This Repo
- `Mariner 3 upgrade (#1439)`
- `Upgrade Fluent Bit to 4.0.9 (#1535)`
- `Upgrade Telegraf 1.34.3 (#1434)`
- `Fluent bit 4.0.14 (#1601)`
