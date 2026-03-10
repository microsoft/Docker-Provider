# CI/CD Pipeline

## Description

Modify GitHub Actions workflows and Azure DevOps pipelines for Docker-Provider.

USE FOR: update pipeline, CI change, workflow change, add CI step, fix pipeline, migrate pipeline
DO NOT USE FOR: source code changes, dependency updates, documentation

## Instructions

### When to Apply

When CI/CD workflows need updating, migrating, or fixing.

### Step-by-Step Procedure

1. **Identify the pipeline type:**
   - GitHub Actions: `.github/workflows/*.yml`
   - Azure DevOps: `.pipelines/*.yml`
2. **Make changes following existing patterns** — match YAML structure and naming.
3. **For GitHub Actions:** Validate YAML syntax. Key workflows:
   - `run_unit_tests.yml` — Multi-language unit tests
   - `codeql-analysis.yml` — Security scanning (Go, Python, Ruby)
   - `devskim.yml` — DevSkim security analysis
   - `pr-checker.yml` — PR build and scan
4. **For Azure DevOps:** Follow governed release YAML templates. Pipeline files are in `.pipelines/`.
5. **Test:** Push to a feature branch and verify CI runs correctly.

### Files Typically Involved

- `.github/workflows/*.yml`
- `.pipelines/*.yml`, `.pipelines/*.yaml`

### Validation

- YAML is valid, pipeline runs successfully on feature branch.

## Examples from This Repo

- `0d5ca4aeb` — Governed release yamls migration (#1448)
- `58a1c9436` — Migrate all release pipelines to governed release yaml (#1443)
- `05c46f5f7` — Migrate merged build pipeline to governed pipeline template (#1442)
