# Release Management Skill

## Name
release-management

## Description
Prepare a new release of the Docker-Provider agent including version bumps, release notes, and chart updates.

## Triggers
- "prepare release", "update version", "release notes", "bump chart version"

## Workflow

### 1. Determine Version
- Current versioning: `3.1.x` (check latest in `ReleaseNotes.md`)
- Increment patch version for bug fixes and minor updates
- Release cadence: every 2-4 weeks

### 2. Update Release Notes
Edit `ReleaseNotes.md` following the established format:
```markdown
## Release <date> - Version 3.1.XX
### What's new
- Feature description (PR #number)

### Bug fixes
- Fix description (PR #number)

### CVE fixes
- CVE-YYYY-NNNNN: Description (PR #number)
```

### 3. Update Helm Chart Versions
- `charts/azuremonitor-containers/Chart.yaml` — bump `version` and `appVersion`
- `charts/azuremonitor-containerinsights-for-prod-clusters/Chart.yaml` — same
- `charts/azuremonitor-containers-geneva/Chart.yaml` — same (if applicable)

### 4. Update Image Tags
- `kubernetes/linux/Dockerfile.multiarch` — verify base image versions
- Agent telemetry tag references across configs

### 5. Validate
- Build Linux and Windows images
- Run full test suite
- Trivy scan passes
- Helm lint passes

### 6. Commit Pattern
Typical commit: `3.1.XX release notes and chart update (#PR_NUMBER)`

## Supporting Commits (12 months)
- release notes for 3.1.35 (#1608)
- 3.1.34 release notes and chart update (#1603)
- 3.1.32 release note and chart update (#1583)
- container insights 3.1.31 release notes and chart version upgrade (#1558)
- 3.1.30 Release notes and chart changes (#1537)
- 3.1.29 release notes and version updates (#1524)
- 3.1.28 Release notes and chart updates (#1504)
- 3.1.27 release charts and Release Note update (#1435)
