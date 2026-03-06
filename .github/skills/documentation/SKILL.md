# Documentation

## Description
Guides updating documentation including release notes, README files, and onboarding guides.

USE FOR: update docs, update readme, add release notes, update changelog, document feature
DO NOT USE FOR: code changes, test changes, infrastructure changes

## Instructions

### When to Apply
When updating project documentation, release notes, or developer guides.

### Step-by-Step Procedure
1. Identify the documentation type:
   - Release notes → `ReleaseNotes.md`
   - Developer guide → `README.md`, `Dev Guide.md`
   - Feature documentation → `Documentation/` directory
   - Onboarding guides → `scripts/onboarding/`
   - Helm chart docs → `charts/*/Chart.yaml` (description, appVersion)
2. Follow existing formatting conventions (ATX headings, inline code blocks).
3. Update version numbers consistently across all references.
4. Verify all file paths and commands referenced in docs actually exist.

### Files Typically Involved
- `ReleaseNotes.md` — release notes for each version
- `README.md` — project overview and developer guide
- `Dev Guide.md` — development guide
- `Documentation/` — feature-specific documentation
- `charts/*/Chart.yaml` — Helm chart metadata

### Validation
- All file paths referenced in documentation exist
- All commands listed in documentation work
- Markdown renders correctly

## Examples from This Repo
- `release notes for 3.1.35 (#1608)` — version release notes
- `3.1.34 release notes and chart update (#1603)` — release docs with chart update
- `add deprecation note for helm chart (#1546)` — deprecation notice

## References
- `ReleaseNotes.md` — existing release notes format
- `Documentation/` — existing documentation structure
