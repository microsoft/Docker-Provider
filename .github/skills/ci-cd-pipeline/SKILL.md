# CI/CD Pipeline

## Description
Modify GitHub Actions workflows, Azure Pipelines, or build infrastructure for the Docker-Provider agent.

USE FOR: update pipeline, fix CI, modify workflow, update build, migrate pipeline, fix scan
DO NOT USE FOR: application code changes, documentation updates, dependency bumps (unless CI-specific)

## Instructions

### When to Apply
When CI/CD workflows need updating for new build requirements, scan configurations, pipeline migrations, or build infrastructure changes.

### Step-by-Step Procedure
1. **Identify the pipeline type:**
   - **GitHub Actions**: `.github/workflows/` — unit tests, PR checks, CodeQL, DevSkim
   - **Azure Pipelines**: `.pipelines/` — build, release, E2E tests, production deployment
   - **Build scripts**: `build/linux/Makefile`, `source/plugins/go/src/Makefile`

2. **Make the change following existing patterns:**
   - GitHub Actions: YAML workflow files with standard actions (checkout, setup-go, etc.)
   - Azure Pipelines: YAML templates with stage/job/step structure
   - Makefiles: Standard GNU Make with variables from `build/version`

3. **Test the change:**
   - For GitHub Actions: Push to a feature branch and verify the workflow runs
   - For Makefiles: Run the modified target locally
   - For Docker builds: Build the image locally and verify

4. **Verify security scanning:**
   - CodeQL analysis must remain enabled for Go and Ruby
   - DevSkim must remain enabled
   - Trivy scanning must be present in PR check workflow

### Files Typically Involved
- `.github/workflows/*.yml` — GitHub Actions workflows
- `.pipelines/*.yaml` — Azure Pipelines configurations
- `build/linux/Makefile` — Linux build system
- `source/plugins/go/src/Makefile` — Go plugin build
- `build/version` — Version numbers
- `kubernetes/linux/dockerbuild/` — Docker build scripts

### Validation
- Workflow syntax is valid YAML
- GitHub Actions workflows pass on feature branch
- Docker image builds successfully
- Security scans (CodeQL, DevSkim, Trivy) remain active

## Examples from This Repo
- `0d5ca4aeb` — Governed release yamls migration
- `58a1c9436` — Migrate all release pipelines to governed release yaml
- `f32e2eec4` — Testkube workflow migration
