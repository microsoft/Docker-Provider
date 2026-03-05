# CI/CD Pipeline

## Description
Guides modifications to CI/CD workflows, build pipelines, and release processes.

USE FOR: update pipeline, fix CI, modify workflow, update build, fix release pipeline, update GitHub Actions
DO NOT USE FOR: application code changes, dependency updates, infrastructure changes

## Instructions

### When to Apply
When modifying GitHub Actions workflows, Azure Pipelines definitions, build scripts, or release processes.

### Step-by-Step Procedure
1. Identify the pipeline type:
   - **GitHub Actions**: `.github/workflows/*.yml` — PR checks, unit tests, security scans
   - **Azure Pipelines**: `.pipelines/*.yaml` — production builds, releases, test frameworks
   - **Build scripts**: `build/linux/Makefile`, `build/windows/Makefile.ps1`
2. For GitHub Actions changes:
   - Validate YAML syntax
   - Check that action versions are pinned (e.g., `actions/checkout@v2`)
   - Ensure secrets use `${{ secrets.NAME }}` syntax
3. For Azure Pipelines:
   - Update `.pipelines/*.yaml` files
   - Check pipeline variable references
   - Validate template references in `helm-deploy-templates/`
4. Test locally where possible (e.g., `make` for build changes)

### Files Typically Involved
- `.github/workflows/run_unit_tests.yml` — unit test pipeline
- `.github/workflows/pr-checker.yml` — PR build + Trivy scan
- `.github/workflows/codeql-analysis.yml` — CodeQL SAST
- `.github/workflows/devskim.yml` — DevSkim scan
- `.pipelines/ci-aks-prod-release.yaml` — AKS prod release
- `.pipelines/ci-arc-k8s-extension-*.yaml` — Arc extension releases
- `.pipelines/azure_pipeline_mergedbranches.yaml` — merged branch build
- `build/linux/Makefile`, `build/windows/Makefile.ps1`

### Validation
- YAML lints cleanly
- Build succeeds locally: `cd build/linux && make`
- Unit tests pass: `./test/unit-tests/test_main.sh`

## Examples from This Repo
- `1739bcb10` — Update ci-aks-prod-release.yaml for Azure Pipelines
- `23d07799d` — let trivy fail when cves are detected
- `58a1c9436` — Migrate all release pipelines to governed release yaml

## References
- `.github/workflows/` — GitHub Actions workflows
- `.pipelines/` — Azure Pipelines definitions
