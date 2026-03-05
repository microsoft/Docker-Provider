# Infrastructure

## Description
Guides changes to Dockerfiles, Helm charts, Bicep/Terraform templates, and Kubernetes manifests.

USE FOR: update Dockerfile, Helm chart, Bicep, Terraform, ARM template, Kubernetes manifest, onboarding template
DO NOT USE FOR: application code changes, CI/CD pipeline changes, test-only changes

## Instructions

### When to Apply
When modifying container images, deployment configurations, onboarding templates, or infrastructure-as-code.

### Step-by-Step Procedure
1. Identify the infrastructure type:
   - **Docker**: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/windows/Dockerfile`
   - **Helm charts**: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`, `charts/azuremonitor-containerinsights-for-prod-clusters/`
   - **Bicep**: `scripts/onboarding/aks/onboarding-msi-bicep/`
   - **Terraform**: `scripts/onboarding/aks/onboarding-msi-terraform/`
   - **ARM JSON**: `scripts/onboarding/aks/onboarding-using-msi-auth/`
   - **Kubernetes manifests**: `kubernetes/ama-logs.yaml`
2. For Dockerfile changes:
   - Use Azure Linux (Mariner) base images with `tdnf` package manager
   - Pin package versions where possible
   - Run as non-root user where feasible
   - Update BOTH linux and windows Dockerfiles if the change is cross-platform
3. For Helm chart changes:
   - Update `Chart.yaml` version
   - Update `values.yaml` defaults
   - Validate templates: `helm template charts/azuremonitor-containers/`
4. For onboarding templates: update all variants (Bicep, Terraform, ARM, Azure Policy) consistently

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch` — Linux container image
- `kubernetes/windows/Dockerfile` — Windows container image
- `charts/*/Chart.yaml`, `charts/*/values.yaml`, `charts/*/templates/` — Helm charts
- `scripts/onboarding/aks/` — onboarding templates
- `kubernetes/ama-logs.yaml` — Kubernetes manifest

### Validation
- Docker build succeeds: `docker build . --file Dockerfile.multiarch -t test`
- Helm template renders: `helm template charts/azuremonitor-containers/`
- Trivy scan passes on built image

## Examples from This Repo
- `090c1dd49` — Upgrade Fluent Bit to 4.0.9, add missing dependencies
- `8ac2038cc` — Mariner 3 upgrade
- `1669d2526` — Longw/high scale and networkflow logs Bicep templates

## References
- `kubernetes/linux/Dockerfile.multiarch` — main Linux Dockerfile
- `charts/azuremonitor-containers/` — public Helm chart
