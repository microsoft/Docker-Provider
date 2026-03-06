# Documentation

## Description
Update documentation, release notes, and READMEs for the Container Insights agent.

USE FOR: update docs, release notes, README, changelog, deprecation notice
DO NOT USE FOR: code changes, test changes, infrastructure changes

## Instructions

### When to Apply
When updating project documentation, writing release notes, or updating onboarding guides.

### Step-by-Step Procedure

1. **Identify the documentation type**:
   - Release notes: `ReleaseNotes.md`
   - Main README: `README.md`
   - Feature docs: `Documentation/`
   - Chart docs: `charts/*/README.md`
   - Script docs: `scripts/*/README.md`

2. **Release notes format** (follow existing pattern):
   ```markdown
   ## Release <version>
   - Change description (#PR_NUMBER)
   - Another change (#PR_NUMBER)
   ```

3. **Update Helm chart version** (for releases):
   - Bump `version` in `charts/azuremonitor-containers/Chart.yaml`
   - Bump `version` in `charts/azuremonitor-containers-geneva/Chart.yaml`

4. **Documentation conventions**:
   - Use ATX headings (`#`, `##`, `###`)
   - Code blocks with language annotations
   - Inline links `[text](url)`
   - Reference actual file paths from repo root

### Files Typically Involved
- `ReleaseNotes.md` — Release history
- `README.md` — Project overview
- `Documentation/` — Feature guides
- `charts/azuremonitor-containers/Chart.yaml` — Chart version

### Validation
- All referenced file paths exist
- All links are valid
- PR numbers reference real PRs
- Chart versions are semver-compliant

## Examples from This Repo
- `release notes for 3.1.35 (#1608)` — Release notes update
- `3.1.34 release notes and chart update (#1603)` — Release + chart version bump
- `add deprecation note for helm chart (#1546)` — Deprecation documentation
- `container insights 3.1.31 release notes and chart version upgrade (#1558)`
