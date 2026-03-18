# Infrastructure

## Description
Guides changes to Dockerfiles, Helm charts, deployment configurations, and infrastructure templates.

USE FOR: update Dockerfile, modify Helm chart, update deployment, add Bicep template, modify Terraform, update EV2 config
DO NOT USE FOR: source code logic changes, CI/CD pipeline changes (use ci-cd-pipeline skill)

## Instructions

### When to Apply
When modifying container images, Helm charts, EV2 deployment configs, or onboarding templates (Bicep/Terraform).

### Step-by-Step Procedure
1. **Identify the infrastructure component**:
   - Linux container: `kubernetes/linux/Dockerfile.multiarch`, `kubernetes/linux/setup.sh`
   - Windows container: `kubernetes/windows/Dockerfile`
   - Helm charts: `charts/azuremonitor-containers/`, `charts/azuremonitor-containers-geneva/`
   - EV2 deployment: `deployment/*/ServiceGroupRoot/`
   - Onboarding Bicep: `scripts/onboarding/aks/*-bicep/`
   - Onboarding Terraform: `scripts/onboarding/aks/*-terraform/`
2. **Make changes** following existing patterns:
   - Dockerfile: multi-stage build with golang-builder → builder → distroless stages
   - Helm: update `values.yaml` and templates in `templates/`
   - EV2: update service models, rollout specs, or parameters
3. **Verify multi-arch support** — changes must work for both amd64 and arm64.
4. **Test container build** locally if possible.
5. **Update Helm chart version** in `Chart.yaml` if chart contents changed.

### Files Typically Involved
- `kubernetes/linux/Dockerfile.multiarch`
- `kubernetes/windows/Dockerfile`
- `charts/azuremonitor-containers/`
- `deployment/*/ServiceGroupRoot/`
- `scripts/onboarding/aks/`

### Validation
- Container builds for both amd64 and arm64
- Helm template renders correctly (`helm template`)
- No hardcoded secrets in deployment configs
- Trivy scan passes on built images

## Examples from This Repo
- `090c1dd49` — Upgrade Fluent Bit to 4.0.9 (cloudnative build) (#1535)
- `1669d2526` — High scale and networkflow logs Bicep templates (#1470)
- `4cb3207d3` — Multi tenant templates with Terraform (#1505)
