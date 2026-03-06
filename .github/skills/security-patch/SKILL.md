# Security Patch

## Purpose
Addresses security vulnerabilities in the Container Insights agent, including CVE remediation in dependencies, fixing insecure code patterns, hardening container security contexts, and resolving findings from CodeQL, DevSkim, and Trivy scanners.

USE FOR: "security fix", "CVE", "vulnerability", "Trivy finding", "CodeQL alert", "DevSkim alert", "harden", "credential exposure", "RBAC", "security context", "secret management"
DO NOT USE FOR: Routine dependency bumps without a CVE (use dependency-update), general bug fixes without security implications (use bug-fix), CI pipeline changes to scanners (use ci-cd-pipeline)

## When to Use
- Trivy scan in pr-checker.yml reports a HIGH or CRITICAL vulnerability
- CodeQL analysis (`codeql-analysis.yml`) flags a security issue in Go or Ruby code
- DevSkim (`devskim.yml`) identifies an insecure code pattern
- A CVE is published affecting a direct or transitive dependency
- Security review identifies hardcoded credentials, insecure defaults, or excessive RBAC permissions
- Container image needs security context hardening (non-root, read-only filesystem, capabilities)

## Inputs
- CVE identifier or scanner alert details
- Affected component and file path(s)
- Severity level (CRITICAL, HIGH, MEDIUM, LOW)
- Whether a fix is available upstream (patched dependency version) or requires code change

## Outputs
- Patched code or updated dependencies addressing the vulnerability
- Updated `.trivyignore` if the finding is a false positive (with documented justification)
- Clean scanner results on the PR
- Updated `ReleaseNotes.md` noting the security fix

## Steps
1. Triage the vulnerability:
   - Determine if the vulnerable code path is reachable in the Container Insights agent
   - Assess severity in context (a CVE in an unused transitive dependency may be low risk)
   - Check if an upstream fix is available (newer package version)
2. For dependency CVEs:
   - Identify all affected `go.mod` files:
     - `source/plugins/go/src/go.mod`
     - `source/plugins/go/input/go.mod`
     - `test/ginkgo-e2e/livenessprobe/go.mod`
     - `test/ginkgo-e2e/utils/go.mod`
     - `test/ginkgo-e2e/containerstatus/go.mod`
     - `test/ginkgo-e2e/querylogs/go.mod`
   - Update to the patched version: `go get <package>@<patched-version>` then `go mod tidy`
   - For Ruby gems: update version constraints and run dependency resolution
3. For code-level vulnerabilities (CodeQL/DevSkim findings):
   - Fix the insecure pattern in the flagged source file
   - Common fixes: input validation, proper credential handling, secure defaults, SQL injection prevention
4. For container hardening:
   - Update `kubernetes/linux/Dockerfile.multiarch` and/or `kubernetes/windows/Dockerfile`
   - Update Helm chart security contexts in `charts/*/templates/`
   - Ensure pods run as non-root where possible
5. For base image CVEs:
   - Update the base image version in Dockerfiles
   - Rebuild and re-scan with Trivy
6. Run all validation:
   - Unit tests: `run_go_tests.sh`, `run_ruby_tests.sh`, `test_main.sh`, `test_main.ps1`
   - Build: `make` in `build/linux/Makefile`
   - Trivy scan on the rebuilt image
   - CodeQL/DevSkim re-analysis
7. If a Trivy finding is a false positive:
   - Add the CVE to `.trivyignore` with a comment explaining why it is safe to ignore
   - Include the date and a reference to the analysis
8. Update `ReleaseNotes.md` with the security fix details

## Validation
- The specific CVE/alert is resolved in scanner output
- Trivy scan shows no new HIGH/CRITICAL findings (or false positives are documented in `.trivyignore`)
- CodeQL analysis passes with no new alerts
- DevSkim scan passes with no new findings
- All unit tests pass
- Container image builds successfully
- PR CI checks pass: pr-checker.yml, codeql-analysis.yml, devskim.yml

## Risks and Guardrails
- **Urgency vs. thoroughness**: Security patches may be urgent, but still require tests and review; do not skip CI
- **False positive documentation**: Every `.trivyignore` entry must include the CVE ID and a clear justification comment
- **Transitive dependency chains**: Updating one package to fix a CVE may pull in other breaking changes; test thoroughly
- **RBAC changes**: Modifying ClusterRole/ClusterRoleBinding in Helm charts affects all clusters; minimize permissions
- **Secret handling**: Never log secrets, tokens, or connection strings; audit any changes to logging code
- **Base image provenance**: Only use base images from trusted registries (MCR, official Docker Hub images)
- **Coordinated disclosure**: If the vulnerability is in the agent's own code, coordinate with the security team before public disclosure
- **Windows parity**: Security fixes in Linux Dockerfiles may need equivalent changes in Windows Dockerfiles

## Examples from This Repo
- Trivy findings are tracked and resolved through `.trivyignore` entries with CVE-specific comments
- pr-checker.yml runs Trivy as a required PR check, blocking merges with unaddressed HIGH/CRITICAL findings
- CodeQL analysis covers Go code in `source/plugins/go/` for common vulnerability patterns
- Base image updates for CVE remediation are recorded in `ReleaseNotes.md` with specific version changes
- Security patches are relatively infrequent (7 commits in 12 months) but high priority when they occur
