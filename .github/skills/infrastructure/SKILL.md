# Infrastructure

## Description
Guide for modifying infrastructure-as-code, deployment templates, and Kubernetes configurations.

USE FOR: infrastructure change, Terraform update, Bicep template, Helm chart, ARM template, deployment config, Kubernetes manifest
DO NOT USE FOR: source code changes, CI/CD pipeline modifications, dependency updates

## Instructions

### When to Apply
When modifying deployment templates (Terraform, Bicep, ARM), Helm charts, Kubernetes manifests, or onboarding scripts.

### Step-by-Step Procedure
1. Identify the deployment target: AKS, ARC, multi-tenant, high-scale, network flow.
2. Locate the relevant template directory:
   - Helm charts: `charts/azuremonitor-containers/`
   - Terraform: `deployment/` (look for `.tf` files)
   - Bicep: `deployment/` (look for `.bicep` files)
   - ARM JSON: `deployment/`, `alerts/`
   - Kubernetes YAML: `kubernetes/`
3. Make changes following existing template patterns.
4. If helper scripts exist for config management, use them instead of editing templates directly.
5. Validate template syntax before committing.
6. Update Helm chart version in `Chart.yaml` if modifying chart templates.

### Files Typically Involved
- `charts/azuremonitor-containers/` — Helm chart templates and values
- `deployment/` — ARM, Bicep, Terraform templates
- `kubernetes/linux/` — Linux DaemonSet/ReplicaSet configs
- `kubernetes/windows/` — Windows configs
- `alerts/` — Alert rule definitions
- `scripts/` — Onboarding and migration scripts

### Validation
- Template syntax validates (Helm lint, Terraform validate, Bicep build)
- No hardcoded secrets in templates
- Parameters have appropriate defaults

## Examples from This Repo
- `1669d2526` — Longw/high scale and networkflow logs Bicep templates (#1470)
- `4cb3207d3` — Longw/multi tenant templates with Terraform (#1505)
- `ed515567a` — Update ARM template parameter check (#1421)
- `14fa37367` — Longw/retina networkflow logs (#1372)
