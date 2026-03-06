# Documentation

## Description
Update documentation, release notes, README files, and configuration guides for the Docker-Provider agent.

USE FOR: update docs, write README, release notes, changelog, configuration guide, onboarding guide
DO NOT USE FOR: code comments in source files, inline documentation, API doc generation

## Instructions

### When to Apply
When releasing a new version, adding new features that need user documentation, or updating existing guides.

### Step-by-Step Procedure
1. **Identify the documentation type:**
   - **Release notes**: Update `ReleaseNotes.md` with version, date, and changes
   - **README**: Update `README.md` for repo structure or prerequisite changes
   - **Feature docs**: Add/update files in `Documentation/` subdirectories
   - **Onboarding**: Update Terraform/Bicep/ARM templates in `scripts/onboarding/`
   - **Helm chart docs**: Update `charts/azuremonitor-containers/README.md`

2. **Follow existing format:**
   - Release notes: `## Release <version> (<date>)` with bullet-point changes
   - Documentation: ATX headings, fenced code blocks with language tags
   - Use relative links for cross-references within the repo

3. **Update version references:**
   - Ensure version numbers in docs match `build/version`
   - Update Helm chart version references

### Files Typically Involved
- `ReleaseNotes.md` — Version release history
- `README.md` — Project overview
- `Documentation/` — Feature-specific guides
- `charts/azuremonitor-containers/Chart.yaml` — Helm chart version
- `scripts/onboarding/` — Onboarding templates

### Validation
- All file paths referenced in documentation exist
- Version numbers are consistent across files
- Markdown renders correctly (no broken links or formatting)

## Examples from This Repo
- `7410ab3a9` — release notes for 3.1.35
- `d30c2c4ad` — 3.1.34 release notes and chart update
- `731a625b6` — add deprecation note for helm chart
