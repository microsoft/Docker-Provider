# CI/CD Pipeline Skill

## Name
ci-cd-pipeline

## Description
Modify GitHub Actions workflows, Azure Pipelines, or build scripts for the Docker-Provider CI/CD system.

## Triggers
- "update pipeline", "fix CI", "modify workflow", "update build", "pipeline change"

## Workflow

### 1. Understand CI Architecture
- **GitHub Actions** (`.github/workflows/`):
  - `run_unit_tests.yml` — Unit tests (Bash, Go, Ruby, PowerShell) on PR
  - `pr-checker.yml` — Build + Trivy scan on PR (Linux + Windows)
  - `codeql-analysis.yml` — CodeQL security analysis
  - `devskim.yml` — DevSkim security scanning
  - `stale.yml` — Stale issue management
- **Azure Pipelines** (`.pipelines/`):
  - Production release pipelines
  - Helm deploy templates

### 2. Make Changes
- Validate YAML syntax before committing
- Ensure workflow triggers match intended branches (`ci_dev`, `ci_prod`)
- Use pinned action versions (e.g., `actions/checkout@v2`)
- Keep build matrix consistent across platforms (Linux + Windows)

### 3. Test
- For GitHub Actions: changes are validated on PR
- For build scripts: run locally with `cd build/linux && make`
- Verify Trivy scan configuration matches severity requirements

### 4. Key Files
- `.github/workflows/run_unit_tests.yml` — Test runner configuration
- `.github/workflows/pr-checker.yml` — PR build and scan
- `build/linux/Makefile` — Linux build targets
- `build/windows/Makefile.ps1` — Windows build script
- `kubernetes/linux/Dockerfile.multiarch` — Linux container build
- `kubernetes/windows/Dockerfile` — Windows container build

## Supporting Commits (12 months)
- Testkube workflow migration (#1589)
- TAF pipeline fix (#1541)
- Longw/fix pipeline nodepool (#1522)
- Fix arc prod pipeline timeout issue (#1564)
- Pipeline scanner and drop adjustment (#1453)
- Governed release yamls migration (#1448)
- Migrate all release pipelines to governed release yaml (#1443)
- Migrate merged build pipeline to governed pipeline template (#1442)
- migrate esrp signing (#1438)
- Zane/windows 2019 pipeline fix 3 (#1437)
- Zane/windows 2019 pipeline fix 4 (#1456)
- TAF: Check errors in process files (#1460)
- Longw/update arc pipeline (#1461)
- let trivy fail when cves are detected (#1591)
