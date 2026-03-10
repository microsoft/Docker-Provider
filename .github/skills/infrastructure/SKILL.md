# Infrastructure

## Description

Modify Helm charts, Dockerfiles, Kubernetes manifests, Bicep templates, and Terraform configs for Docker-Provider.

USE FOR: update Helm chart, update Dockerfile, update Bicep, update Terraform, update K8s manifest, change deployment, update ARM template
DO NOT USE FOR: source code logic changes, test code, documentation

## Instructions

### When to Apply

When deployment configuration, container images, or infrastructure-as-code needs changes.

### Step-by-Step Procedure

1. **Identify the infrastructure component:**
   - Helm charts: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`
   - Dockerfiles: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
   - Kubernetes manifests: `kubernetes/*.yaml`
   - Bicep: `deployment/*.bicep` files
   - Terraform: `deployment/*.tf` files
   - ARM templates: `deployment/` JSON files

2. **Make changes following existing patterns.**

3. **For Helm chart changes:** Bump version in `Chart.yaml` and update `values.yaml` if adding new parameters.

4. **For Dockerfile changes:** Ensure multi-arch compatibility (AMD64/ARM64 for Linux), verify base image security.

5. **Build and test:** `docker build` for Dockerfile changes, `helm template` for chart changes.

### Files Typically Involved

- `charts/azuremonitor-containers/Chart.yaml`, `values.yaml`, `templates/`
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `deployment/` (Bicep, Terraform, ARM)

### Validation

- Docker image builds, Helm chart renders correctly, Trivy scan passes.

## Examples from This Repo

- `1669d2526` — high scale and networkflow logs Bicep templates (#1470)
- `4cb3207d3` — multi tenant templates with Terraform (#1505)
- `8ac2038cc` — Mariner 3 upgrade (#1439)
