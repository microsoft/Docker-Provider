# CI/CD Pipeline

## Description
Modify CI/CD workflows, Azure Pipelines, or build infrastructure for the monitoring agent.

USE FOR: update pipeline, modify CI workflow, fix build, update Azure Pipelines, deploy configuration, Testkube changes
DO NOT USE FOR: application code changes, dependency updates, documentation-only changes

## Instructions

### When to Apply
When modifying GitHub Actions workflows, Azure Pipelines definitions, build scripts, Testkube configurations, or deployment pipeline settings.

### Step-by-Step Procedure
1. Identify the target pipeline:
   - GitHub Actions: `.github/workflows/*.yml` (PR validation only)
   - Azure Pipelines: `.pipelines/*.yaml` (production CI/CD)
   - Testkube: `test/testkube/` (E2E test execution)
2. Make the pipeline change.
3. For GitHub Actions, validate YAML syntax.
4. For Azure Pipelines, check variable references and stage dependencies.
5. For Testkube, verify workflow CRDs and helm values are consistent.
6. Test by opening a PR to `ci_dev` or `ci_prod` to trigger the pipeline.

### Files Typically Involved
- `.github/workflows/run_unit_tests.yml` — Unit test CI
- `.github/workflows/pr-checker.yml` — PR build and scan
- `.pipelines/azure_pipeline_mergedbranches.yaml` — Main Azure Pipeline
- `.pipelines/ci-aks-prod-release.yaml` — AKS production release
- `.pipelines/ci-arc-k8s-extension-prod-release.yaml` — Arc extension release
- `test/testkube/install-and-execute-testkube-tests.sh` — Testkube runner
- `test/testkube/testkube-test-crs.yaml` — Testkube test CRDs
- `test/testkube/helm-testkube-values.yaml` — Testkube Helm values

### Validation
- Pipeline YAML is valid (no syntax errors)
- PR triggers the expected workflow runs
- All CI checks pass on the PR

## Examples from This Repo
- `f32e2eec4` — Testkube workflow migration (#1589)
- `b4e69bb95` — Fix arc prod pipeline timeout issue (#1564)
- `1739bcb10` — Update ci-aks-prod-release.yaml for Azure Pipelines (#1599)

## References
- `.github/workflows/` — GitHub Actions definitions
- `.pipelines/` — Azure Pipelines definitions
- `test/testkube/` — Testkube configuration
