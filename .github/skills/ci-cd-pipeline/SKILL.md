# CI/CD Pipeline

## Description
Modify CI/CD pipeline configurations for build, test, release, or deployment workflows.

USE FOR: update pipeline, fix pipeline, modify CI, update workflow, release pipeline, governed pipeline
DO NOT USE FOR: application code changes, documentation updates, Helm chart changes without pipeline impact

## Instructions

### When to Apply
When modifying GitHub Actions workflows (`.github/workflows/`) or Azure Pipelines (`.pipelines/`).

### Step-by-Step Procedure
1. **Identify the pipeline type:**
   - GitHub Actions: `.github/workflows/` — PR checks (build, scan, unit tests)
   - Azure Pipelines: `.pipelines/` — Production builds, releases, canary/prod deployments

2. **Make changes** following existing pipeline patterns:
   - GitHub Actions use `ubuntu-latest` / `windows-2019` runners
   - Azure Pipelines use governed release YAML templates

3. **Validate YAML syntax** — Ensure valid YAML structure.

4. **Check for security implications:**
   - No secrets in plain text — use `${{ secrets.NAME }}`
   - No `--force` flags in deployment commands
   - Trivy scan settings maintain `CRITICAL,HIGH` severity with `exit-code: 1`

### Files Typically Involved
- `.github/workflows/pr-checker.yml` — PR build and Trivy scan
- `.github/workflows/run_unit_tests.yml` — Unit test execution
- `.github/workflows/codeql-analysis.yml` — CodeQL SAST
- `.pipelines/azure_pipeline_mergedbranches.yaml` — Production build pipeline
- `.pipelines/ci-aks-prod-release.yaml` — AKS production release
- `.pipelines/ci-arc-k8s-extension-prod-release.yaml` — Arc extension release

### Validation
- YAML syntax is valid
- No new secrets exposed in plain text
- Pipeline logic is consistent with existing patterns

## Examples from This Repo
- `Governed release yamls migration (#1448)`
- `Migrate all release pipelines to governed release yaml (#1443)`
- `TAF pipeline fix (#1541)`
- `Longw/fix pipeline nodepool (#1522)`
