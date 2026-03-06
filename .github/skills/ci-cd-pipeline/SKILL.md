# CI/CD Pipeline

## Purpose
Maintains and improves the continuous integration and continuous deployment pipelines for the Container Insights agent. Covers GitHub Actions workflows (PR validation, unit tests, CodeQL, DevSkim), Azure Pipelines (build, release, deployment), and associated build scripts.

USE FOR: "update workflow", "fix CI", "add pipeline step", "update build", "GitHub Actions", "Azure Pipelines", "pr-checker", "unit test workflow", "CodeQL", "DevSkim", "pipeline failure", "build script"
DO NOT USE FOR: Application code changes that happen to be tested by CI (use bug-fix or feature-development), Helm chart changes (use infrastructure), dependency updates (use dependency-update)

## When to Use
- A CI workflow is failing and needs repair
- Adding a new validation step to the PR check pipeline
- Updating GitHub Actions versions or runner images
- Modifying Azure Pipelines build/release definitions in `.pipelines/`
- Changing the build process in `build/linux/Makefile` or `source/plugins/go/src/Makefile`
- Updating Trivy scanning configuration in pr-checker.yml
- Adding or modifying the stale issue bot configuration
- Changing how unit tests are orchestrated in CI

## Inputs
- Description of the CI/CD change needed
- Which pipeline is affected: GitHub Actions (`.github/workflows/`) or Azure Pipelines (`.pipelines/`)
- Target workflow file(s) and the specific job/step to modify
- Any new secrets, environment variables, or service connections required

## Outputs
- Updated workflow YAML files (`.github/workflows/*.yml` or `.pipelines/*.yaml`)
- Updated build scripts if the build process changes
- Passing CI on the PR that introduces the change
- No regressions in existing pipeline behavior

## Steps
1. Identify the target pipeline file(s):
   - **GitHub Actions workflows:**
     - `.github/workflows/pr-checker.yml` — PR validation, Trivy scanning, build verification
     - `.github/workflows/run_unit_tests.yml` — Go, Ruby, Shell, PowerShell unit test execution
     - `.github/workflows/codeql-analysis.yml` — CodeQL static analysis for Go and Ruby
     - `.github/workflows/devskim.yml` — DevSkim security linting
     - `.github/workflows/stale.yml` — Stale issue/PR management
   - **Azure Pipelines:**
     - `.pipelines/` — Build, release, and deployment pipeline definitions
     - `.pipelines/` contains Helm deployment templates and image build steps
2. Make the workflow change:
   - For GitHub Actions: update YAML following the existing workflow structure and naming conventions
   - For Azure Pipelines: follow the existing template patterns in `.pipelines/`
   - For build scripts: update `build/linux/Makefile`, `source/plugins/go/src/Makefile`, or shell scripts in `build/`
3. If modifying test execution:
   - Ensure `test/unit-tests/run_go_tests.sh` is called for Go test changes
   - Ensure `test/unit-tests/run_ruby_tests.sh` is called for Ruby test changes
   - Ensure `test/unit-tests/test_main.sh` and `test/unit-tests/test_main.ps1` are called for shell/PS tests
4. If modifying Trivy scanning:
   - Update scan configuration in pr-checker.yml
   - Update `.trivyignore` only with justified CVE exceptions
5. Validate workflow syntax locally if possible (e.g., `actionlint` for GitHub Actions)
6. Push the change and verify the pipeline runs successfully on the PR

## Validation
- The modified workflow runs successfully on the PR
- Existing parallel workflows continue to pass (no cross-workflow interference)
- Build artifacts are produced correctly (Docker images, Helm packages)
- Unit test results are reported correctly in PR checks
- Trivy scan results appear in PR comments/checks as expected
- No secrets or sensitive values are exposed in workflow logs

## Risks and Guardrails
- **Secret exposure**: Never echo or log secrets; use GitHub Actions secrets or Azure DevOps variable groups exclusively
- **Workflow permissions**: Use minimum required permissions in GitHub Actions (`permissions:` block); avoid `write-all`
- **Runner compatibility**: Verify changes work on the runner OS specified in the workflow (ubuntu-latest, windows-latest)
- **Pipeline dependencies**: Azure Pipelines in `.pipelines/` may reference shared templates; changing one file can affect multiple pipelines
- **Trivy ignore discipline**: Each `.trivyignore` entry must reference a specific CVE with a comment explaining why it is safe to ignore
- **Build cache invalidation**: Changes to Makefiles or Dockerfiles may invalidate build caches; verify build times remain acceptable
- **Branch protection**: PR-checker.yml is a required check; changes must not break the check or it blocks all PRs

## Examples from This Repo
- pr-checker.yml runs Trivy container scanning on the built Docker image as part of PR validation
- run_unit_tests.yml orchestrates separate Go, Ruby, and shell test runners from `test/unit-tests/`
- codeql-analysis.yml runs CodeQL for Go and has custom query configurations
- Azure Pipelines in `.pipelines/` handle the full build-test-release cycle including multi-arch image builds
- Makefile targets in `build/linux/Makefile` produce the agent bundle installed in the container image
