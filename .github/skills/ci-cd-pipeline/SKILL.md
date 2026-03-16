# CI/CD Pipeline

## Description
Guide for modifying CI/CD pipelines and build configurations.

USE FOR: pipeline change, CI fix, build pipeline, release pipeline, governed release, pipeline migration, Azure Pipelines update
DO NOT USE FOR: source code changes, dependency updates, feature development

## Instructions

### When to Apply
When modifying GitHub Actions workflows, Azure Pipelines configurations, build scripts, or release processes.

### Step-by-Step Procedure
1. Identify which pipeline to modify: GitHub Actions (`.github/workflows/`) or Azure Pipelines.
2. For GitHub Actions: edit the relevant `.yml` file — `pr-checker.yml` (build + scan), `run_unit_tests.yml` (tests), `codeql-analysis.yml`, `devskim.yml`.
3. For Azure Pipelines: configurations are referenced in commit history but managed externally.
4. Test workflow changes by creating a PR — CI runs automatically on PRs to `ci_dev`/`ci_prod`.
5. Verify all checks pass in the PR.

### Files Typically Involved
- `.github/workflows/pr-checker.yml` — PR build and Trivy scan
- `.github/workflows/run_unit_tests.yml` — Unit tests (Bash, Go, Ruby, PowerShell)
- `.github/workflows/codeql-analysis.yml` — CodeQL SAST
- `.github/workflows/devskim.yml` — DevSkim security patterns
- `build/linux/Makefile` — Build targets

### Validation
- Workflow YAML is valid
- CI checks pass on test PR

## Examples from This Repo
- `0d5ca4aeb` — Governed release yamls migration (#1448)
- `58a1c9436` — Migrate all release pipelines to governed release yaml (#1443)
- `05c46f5f7` — Migrate merged build pipeline to governed pipeline template (#1442)
- `1e4f08b56` — migrate esrp signing (#1438)
