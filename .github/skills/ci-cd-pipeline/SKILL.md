# CI/CD Pipeline

## Description
Modify GitHub Actions workflows or Azure Pipelines configurations for the Container Insights agent.

USE FOR: update pipeline, fix CI, add workflow step, modify build pipeline, update release pipeline
DO NOT USE FOR: application code changes, test logic changes, documentation

## Instructions

### When to Apply
When modifying CI/CD configurations, adding new pipeline steps, fixing build failures, or updating release processes.

### Step-by-Step Procedure

1. **Identify the pipeline system**:
   - GitHub Actions: `.github/workflows/` — PR validation, unit tests, security scans
   - Azure Pipelines: `.pipelines/` — Production builds, releases, deployments

2. **GitHub Actions workflows**:
   - `pr-checker.yml` — Linux/Windows Docker build + Trivy scan on PRs
   - `run_unit_tests.yml` — Bash, Go, Ruby, PowerShell tests on PRs and pushes
   - `codeql-analysis.yml` — CodeQL SAST scanning
   - `devskim.yml` — DevSkim security pattern scanning
   - `stale.yml` — Stale issue/PR management

3. **Azure Pipelines** (`.pipelines/`):
   - `azure_pipeline_mergedbranches.yaml` — Merged branch builds
   - `ci-aks-prod-release.yaml` — AKS production release
   - `ci-arc-k8s-extension-prod-release.yaml` — Arc extension release
   - `ci-arc-k8s-extension-canary-release.yaml` — Canary release

4. **Common modifications**:
   - Update Go version: Change `go-version` in `run_unit_tests.yml`
   - Update Trivy scan flags: Modify `pr-checker.yml` trivy-action configuration
   - Add new test step: Add to appropriate job in `run_unit_tests.yml`
   - Update release pipeline: Modify `.pipelines/ci-aks-prod-release.yaml`

5. **Validate locally**:
   - For GitHub Actions: Run the equivalent commands locally
   - For Azure Pipelines: Check YAML syntax (`az pipelines validate` if available)

### Files Typically Involved
- `.github/workflows/*.yml` — GitHub Actions
- `.pipelines/*.yaml` — Azure Pipelines
- `.pipelines/helm-deploy-templates/` — Helm deployment templates
- `.pipelines/build-linux.sh`, `.pipelines/build-windows.cmd` — Build scripts

### Validation
- YAML syntax is valid
- Referenced actions/tasks exist and are at correct versions
- Trigger conditions (branches, events) are correct
- Secret references use correct variable names

## Examples from This Repo
- `Update ci-aks-prod-release.yaml for Azure Pipelines (#1599)` — Pipeline update
- `Testkube workflow migration (#1589)` — Test infrastructure migration
- `TAF pipeline fix (#1541)` — Pipeline fix
- `let trivy fail when cves are detected (#1591)` — CI scan enforcement
