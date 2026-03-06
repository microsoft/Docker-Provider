# Documentation

## Description
Update documentation, release notes, and README files.

USE FOR: update docs, write README, release notes, changelog, add documentation, chart documentation
DO NOT USE FOR: code comments only, inline code documentation, API spec generation

## Instructions

### When to Apply
When creating or updating project documentation, release notes, or onboarding guides.

### Step-by-Step Procedure
1. **Identify documentation type:**
   - Release notes: `ReleaseNotes.md`
   - Project overview: `README.md`
   - Operational guides: `Documentation/`
   - Helm chart docs: `charts/azuremonitor-containers/`
   - Test documentation: `test/README.md`, `test/unit-tests/README.md`

2. **Follow existing formatting conventions:**
   - ATX-style headings, fenced code blocks with language annotations
   - Tables for structured data
   - PR number references in parentheses: `(#1234)`

3. **For release notes:**
   - Add new entry at the top of `ReleaseNotes.md`
   - Include version number, date, and change list with PR references
   - Update `charts/azuremonitor-containers/Chart.yaml` version if applicable

### Files Typically Involved
- `ReleaseNotes.md`
- `README.md`
- `Documentation/` subdirectories
- `charts/azuremonitor-containers/Chart.yaml`

### Validation
- All referenced file paths exist
- All PR number links are valid
- Markdown renders correctly

## Examples from This Repo
- `release notes for 3.1.35 (#1608)`
- `3.1.34 release notes and chart update (#1603)`
- `add deprecation note for helm chart (#1546)`
