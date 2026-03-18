# CI/CD Pipeline

## Description
Guides modifications to CI/CD pipelines including GitHub Actions workflows and Azure Pipelines configurations.

USE FOR: update pipeline, fix CI, modify workflow, add CI check, update GitHub Action, fix build pipeline
DO NOT USE FOR: source code changes, dependency updates (use dependency-update skill), Helm chart changes

## Instructions

### When to Apply
When modifying GitHub Actions workflows (`.github/workflows/`), Azure Pipelines (`.pipelines/`), or build/release scripts.

### Step-by-Step Procedure
1. **Identify the pipeline** to modify:
   - GitHub Actions: `.github/workflows/*.yml` — unit tests, CodeQL, DevSkim, stale PRs
   - Azure Pipelines: `.pipelines/*.yaml` — builds, E2E tests, releases, Helm deploys
2. **Understand the pipeline flow**:
   - `run_unit_tests.yml` — runs Bash, Go, Ruby, PowerShell tests on PRs
   - `codeql-analysis.yml` — CodeQL SAST for Go, Python, Ruby
   - `devskim.yml` — DevSkim security pattern scanning
   - `ci-aks-prod-release.yaml` — AKS production release pipeline
   - `ci-arc-k8s-extension-*.yaml` — Arc K8s extension release pipelines
3. **Make changes** following YAML syntax and existing patterns.
4. **Test locally** where possible:
   - GitHub Actions: use `act` for local testing, or create a PR to trigger the workflow.
   - Azure Pipelines: validate YAML syntax; actual testing requires pipeline run.
5. **Verify** no existing pipeline steps are broken.

### Files Typically Involved
- `.github/workflows/run_unit_tests.yml`
- `.github/workflows/codeql-analysis.yml`
- `.github/workflows/devskim.yml`
- `.pipelines/*.yaml` and `.pipelines/*.sh`

### Validation
- YAML syntax is valid
- Pipeline runs successfully on PR

## Examples from This Repo
- `1739bcb10` — Update ci-aks-prod-release.yaml for Azure Pipelines (#1599)
- `f32e2eec4` — Testkube workflow migration (#1589)
- `a3c92dfec` — TAF pipeline fix (#1541)
