# Documentation

## Description
Guide for updating documentation, release notes, and README files.

USE FOR: doc update, readme, release notes, changelog, chart update, documentation
DO NOT USE FOR: code changes, build changes, infrastructure changes

## Instructions

### When to Apply
When writing release notes, updating READMEs, adding deprecation notices, or updating chart documentation.

### Step-by-Step Procedure
1. Identify the documentation type: release notes, README, chart docs, or inline code docs.
2. For release notes: follow the format in `ReleaseNotes.md` — version header, date, bullet list of changes.
3. For README updates: keep the format consistent with existing `README.md` structure.
4. For Helm chart docs: update `charts/azuremonitor-containers/README.md` and `Chart.yaml`.
5. Reference actual PR numbers and commit descriptions.
6. Verify all file paths and links are valid.

### Files Typically Involved
- `ReleaseNotes.md` — Release notes
- `README.md` — Project README
- `charts/azuremonitor-containers/Chart.yaml` — Helm chart metadata
- `Documentation/` — Grafana dashboards, DCR docs
- `MARINER.md`, `Dev Guide.md` — Development docs

### Validation
- All referenced file paths exist
- Links are valid
- Version numbers match release

## Examples from This Repo
- `7410ab3a9` — release notes for 3.1.35 (#1608)
- `d30c2c4ad` — 3.1.34 release notes and chart update (#1603)
- `731a625b6` — add deprecation note for helm chart (#1546)
- `440ecefe2` — Added Readme for test folder (#1399)
