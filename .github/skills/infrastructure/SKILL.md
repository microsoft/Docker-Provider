# Infrastructure Skill

## Name
infrastructure

## Description
Modify Helm charts, Kubernetes manifests, Bicep/Terraform templates, or deployment configurations.

## Triggers
- "update helm chart", "modify deployment", "change kubernetes manifest", "update terraform", "modify bicep"

## DO NOT USE FOR
- CI/CD pipeline changes — use `ci-cd-pipeline` skill
- Application code changes — use appropriate language-specific approach

## Workflow

### 1. Identify Scope
- **Helm charts** (`charts/`):
  - `azuremonitor-containers/` — Standard AKS deployment
  - `azuremonitor-containerinsights-for-prod-clusters/` — Production clusters
  - `azuremonitor-containers-geneva/` — Geneva integration
- **Kubernetes manifests** (`kubernetes/`):
  - `ama-logs.yaml` — DaemonSet/ReplicaSet manifest
  - Linux and Windows Dockerfiles
- **Terraform** (`scripts/onboarding/aks/onboarding-msi-terraform/`): AKS onboarding
- **Bicep** (`scripts/onboarding/aks/onboarding-msi-bicep/`): AKS onboarding
- **Deployment** (`deployment/`):
  - `arc-k8s-extension-release-v2/` — Arc extension release
  - `mergebranch-multiarch-agent-deployment/` — Multi-arch deployment
- **ARM templates** (`alerts/recommended_alerts_ARM/`): Alert definitions

### 2. Make Changes
- Ensure backward compatibility with existing deployments
- Update `values.yaml` defaults when adding new chart parameters
- Validate Helm templates render correctly: `helm template <chart-path>`
- For Terraform: run `terraform validate` and `terraform plan`
- For Bicep: run `az bicep build` to validate

### 3. Test
- Helm lint: `helm lint <chart-path>`
- Template rendering: `helm template <chart-path> --debug`
- Check chart version is bumped if user-facing changes

### 4. Cross-References
- Chart version updates should align with release notes in `ReleaseNotes.md`
- Deployment ServiceGroup parameters must match environment-specific configs

## Supporting Commits (12 months)
- Longw/high scale and networkflow logs Bicep templates (#1470)
- Longw/high scale terraform (#1488)
- Longw/multi tenant templates (#1502)
- Longw/multi tenant templates with Terraform (#1505)
- Add high logs scale support for ARC (#1491)
- Add private link support for high log scale (#1512)
- Longw/high scale policy (#1497)
- Multi-tenant support for ARC (#1506)
- deploy new image to prod clusters using helm chart
- add deprecation note for helm chart (#1546)
- update api versions (#1419)
- Longw/retina networkflow logs: Update ARM template parameter check (#1421)
- Longw/arc openshift (#1511)
