# CI/CD Pipeline

## Description
Guides changes to the CI/CD pipeline configurations including GitHub Actions workflows and Azure Pipelines.

USE FOR: modify CI, update pipeline, change workflow, fix build pipeline, update GitHub Actions, update Azure Pipelines
DO NOT USE FOR: application code changes, documentation-only changes

## Instructions

### When to Apply
When modifying build, test, scan, or deployment pipeline configurations.

### Step-by-Step Procedure
1. Identify the pipeline type:
   - GitHub Actions: `.github/workflows/*.yml` — CodeQL, DevSkim, unit tests, PR checks, stale management
   - Azure Pipelines: `.pipelines/*.yaml` — primary build, release, test framework pipelines
2. Make changes following the existing YAML structure and indentation.
3. For GitHub Actions: test locally with `act` or verify via PR CI checks.
4. For Azure Pipelines: changes to `.pipelines/` are tested via the Azure DevOps pipeline runs.
5. Ensure pipeline changes do not break existing PR checks.

### Files Typically Involved
- `.github/workflows/codeql-analysis.yml` — CodeQL SAST scanning
- `.github/workflows/devskim.yml` — DevSkim security scanning
- `.github/workflows/pr-checker.yml` — PR build and Trivy scan
- `.github/workflows/run_unit_tests.yml` — unit test execution
- `.pipelines/azure_pipeline_mergedbranches.yaml` — merged branch builds
- `.pipelines/ci-aks-prod-release.yaml` — AKS production release
- `.pipelines/ci-arc-k8s-extension-prod-release.yaml` — Arc K8s extension release

### Validation
- Pipeline YAML is valid (no syntax errors)
- Existing CI checks still pass on PRs
- New or modified steps produce expected output

## Examples from This Repo
- `Testkube workflow migration (#1589)` — test pipeline migration
- `Update ci-aks-prod-release.yaml for Azure Pipelines (#1599)` — pipeline update
- `let trivy fail when cves are detected (#1591)` — scan enforcement change

## References
- `.github/workflows/` — GitHub Actions configurations
- `.pipelines/` — Azure Pipelines configurations
