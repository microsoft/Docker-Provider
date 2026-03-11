# Skill: CI/CD Pipeline

## Overview
Maintain and extend the CI/CD pipelines for Docker-Provider, spanning GitHub Actions workflows and Azure DevOps pipelines. Pipeline changes require extra caution — a broken pipeline blocks all contributors.

## Scope

### GitHub Actions (`.github/workflows/`)
| Workflow | Purpose |
|----------|---------|
| `run_unit_tests.yml` | Runs Go, Ruby, and Bash unit tests on PRs and pushes |
| `pr-checker.yml` | PR validation checks (labels, formatting, required fields) |
| `codeql-analysis.yml` | CodeQL static analysis for security vulnerabilities |
| `devskim.yml` | DevSkim security pattern scanning |

### Azure DevOps (`.pipelines/`)
| Pipeline | Purpose |
|----------|---------|
| `*.yaml` | Build, image publishing, E2E test orchestration, release pipelines |

## Workflow Modifications

### Adding a New GitHub Actions Workflow
1. Create the workflow file in `.github/workflows/`.
2. Define triggers (`on: push`, `on: pull_request`, `on: workflow_dispatch`).
3. Use existing patterns from `run_unit_tests.yml` as a template.
4. Pin action versions to full SHA or major version tag.
5. Set appropriate permissions (least privilege).

### Modifying Existing Workflows
- Test changes on a feature branch before merging to main.
- For `run_unit_tests.yml`: ensure all three test suites (Go, Ruby, Bash) are preserved.
- For `codeql-analysis.yml`: do not reduce the set of scanned languages without security review.
- For `pr-checker.yml`: coordinate with team on any new PR requirements.

### Security Scanning
- **CodeQL** (`codeql-analysis.yml`): Scans Go and other supported languages for vulnerabilities.
- **DevSkim** (`devskim.yml`): Pattern-based security scanning for common mistakes.
- **Trivy**: Container image scanning (referenced in build pipelines); uses `.trivyignore` for accepted findings.

## Azure DevOps Pipelines
- Pipeline files live in `.pipelines/`.
- These handle image builds, multi-arch publishing, E2E testing, and release workflows.
- Changes to Azure DevOps pipelines may require corresponding variable group or service connection updates in the Azure DevOps portal.

## Validation
1. Push workflow changes to a feature branch.
2. Open a PR and verify the workflow triggers correctly.
3. Check that existing workflows are not disrupted.
4. For security workflows, confirm scan results appear in the Security tab.

## Commit Convention
```
Add workflow for automated dependency scanning (#1234)
```
```
Fix unit test workflow to include new Go test path (#1235)
```

## Pitfalls
- **Never disable security scanning workflows** without explicit security team approval.
- Workflow syntax errors block all PRs — validate YAML before pushing.
- Azure DevOps pipeline changes may need portal-side configuration that cannot be committed.
- Secrets and service connections must never appear in workflow files — use GitHub Secrets or Azure DevOps variable groups.
- Be cautious with `workflow_dispatch` triggers on public repos — restrict with environment protection rules.
