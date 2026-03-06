# Documentation

## Purpose
Creates and updates documentation for the Container Insights agent, including release notes, development guides, architecture documentation, Helm chart README files, and operational runbooks. Ensures that contributors, operators, and users have accurate, up-to-date information.

USE FOR: "update docs", "write documentation", "update README", "release notes", "CHANGELOG", "dev guide", "architecture docs", "chart README", "MARINER docs"
DO NOT USE FOR: Code comments within source files (handle as part of the relevant code skill), CI workflow documentation (use ci-cd-pipeline skill for in-workflow comments)

## When to Use
- A new release is being prepared and `ReleaseNotes.md` needs updating
- A new feature or breaking change requires documentation updates
- Helm chart `README.md` needs to reflect new parameters or changed defaults
- `Dev Guide.md` needs updates for new build steps or development workflows
- `MARINER.md` needs updates for base image changes
- Repository-level documentation (`README.md`, `SECURITY.md`, `CODEOWNERS`) needs updates

## Inputs
- Description of what changed (feature, fix, configuration, infrastructure)
- Target document(s) to update
- Version numbers, dates, and component versions for release notes
- Any new Helm chart parameters, environment variables, or configuration options to document

## Outputs
- Updated documentation files with accurate, current content
- Consistent formatting following existing document conventions
- No broken links or outdated references

## Steps
1. Identify the documentation file(s) to update:
   - `ReleaseNotes.md` — Version history with component versions (Golang, Ruby, MDSD, Telegraf, Fluent-bit, Fluentd), Linux/Windows release dates
   - `README.md` — Repository overview and getting started
   - `Dev Guide.md` — Development setup, build instructions, test execution
   - `MARINER.md` — CBL-Mariner base image details and update procedures
   - `SECURITY.md` — Security policy and vulnerability reporting
   - `CODEOWNERS` — Code ownership for PR review routing
   - `charts/azuremonitor-containers/README.md` — Public Helm chart documentation
   - `charts/azuremonitor-containers-geneva/README.md` — Geneva chart documentation
   - `Documentation/` — Additional architecture and operational docs
2. Follow existing formatting conventions:
   - `ReleaseNotes.md`: Use the established version heading format with component version table
   - Helm chart READMEs: Document all `values.yaml` parameters with types and defaults
   - Use Markdown consistently; match heading levels and list styles of existing content
3. For release notes specifically:
   - Add a new version heading at the top of `ReleaseNotes.md`
   - List all component versions (Golang, Ruby, MDSD, Telegraf, Fluent-bit, Fluentd versions)
   - Include Linux and Windows release dates
   - Summarize bug fixes, features, and security patches included in the release
4. For Helm chart documentation:
   - Keep the parameter table in `README.md` synchronized with `values.yaml`
   - Document any new required values or changed defaults
   - Include upgrade notes if breaking changes are introduced
5. Review for accuracy: verify version numbers, file paths, and command examples are correct
6. Check for broken links and outdated references

## Validation
- Documentation renders correctly in GitHub's Markdown viewer
- All referenced file paths exist in the repository
- Version numbers in `ReleaseNotes.md` match actual component versions in Dockerfiles and charts
- Helm chart parameter documentation matches `values.yaml`
- No broken relative links between documents
- Spelling and grammar are correct

## Risks and Guardrails
- **Accuracy**: Documentation must reflect the actual state of the code; outdated docs are worse than no docs
- **Release notes completeness**: Every shipped change should be represented in `ReleaseNotes.md`; cross-reference with merged PRs
- **Sensitive information**: Never include credentials, internal URLs, or customer-specific details in documentation
- **Chart version alignment**: Helm chart README updates should accompany `Chart.yaml` version bumps
- **Link stability**: Use relative links for in-repo references; avoid absolute GitHub URLs that break on forks
- **Multiple chart variants**: Documentation changes may apply to all three chart directories; check for consistency

## Examples from This Repo
- `ReleaseNotes.md` follows a consistent format with version headings, component version tables, and categorized change lists
- `Dev Guide.md` documents the local development setup including Docker, Go, and Ruby prerequisites
- `MARINER.md` specifically documents the CBL-Mariner base image update process
- Documentation commits are the least frequent category (3 commits in 12 months), typically tied to release preparation
- Helm chart `values.yaml` files contain inline comments that serve as parameter documentation
